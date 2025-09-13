package service

import (
	"aqura-backend/internal/domain"
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"
)

// UserService handles user management
type UserService struct {
	repo UserRepository
}

type UserRepository interface {
	CreateUser(ctx context.Context, user *domain.User) error
	GetUserByID(ctx context.Context, id uuid.UUID) (*domain.User, error)
	GetUserByEmail(ctx context.Context, email string) (*domain.User, error)
	GetUserByUsername(ctx context.Context, username string) (*domain.User, error)
	UpdateUser(ctx context.Context, user *domain.User) error
	DeleteUser(ctx context.Context, id uuid.UUID) error
	ListUsers(ctx context.Context, offset, limit int) ([]*domain.User, int, error)
	UpdateLoginAttempts(ctx context.Context, userID uuid.UUID, attempts int, lockedUntil *time.Time) error
}

func NewUserService(repo UserRepository) *UserService {
	return &UserService{repo: repo}
}

func (s *UserService) CreateUser(ctx context.Context, req CreateUserRequest) (*domain.User, error) {
	// Check if user already exists
	if existing, _ := s.repo.GetUserByEmail(ctx, req.Email); existing != nil {
		return nil, errors.New("user with this email already exists")
	}
	if existing, _ := s.repo.GetUserByUsername(ctx, req.Username); existing != nil {
		return nil, errors.New("user with this username already exists")
	}

	// Hash password
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		return nil, err
	}

	user := &domain.User{
		Email:        req.Email,
		Username:     req.Username,
		FirstName:    req.FirstName,
		LastName:     req.LastName,
		PasswordHash: string(hashedPassword),
		Status:       domain.UserStatusPending,
		RoleID:       req.RoleID,
	}

	if err := s.repo.CreateUser(ctx, user); err != nil {
		return nil, err
	}

	return user, nil
}

func (s *UserService) GetUser(ctx context.Context, id uuid.UUID) (*domain.User, error) {
	return s.repo.GetUserByID(ctx, id)
}

func (s *UserService) UpdateUser(ctx context.Context, id uuid.UUID, req UpdateUserRequest) (*domain.User, error) {
	user, err := s.repo.GetUserByID(ctx, id)
	if err != nil {
		return nil, err
	}

	if req.FirstName != nil {
		user.FirstName = req.FirstName
	}
	if req.LastName != nil {
		user.LastName = req.LastName
	}
	if req.Status != nil {
		user.Status = *req.Status
	}
	if req.RoleID != nil {
		user.RoleID = req.RoleID
	}

	if err := s.repo.UpdateUser(ctx, user); err != nil {
		return nil, err
	}

	return user, nil
}

func (s *UserService) ListUsers(ctx context.Context, offset, limit int) ([]*domain.User, int, error) {
	return s.repo.ListUsers(ctx, offset, limit)
}

func (s *UserService) DeleteUser(ctx context.Context, id uuid.UUID) error {
	return s.repo.DeleteUser(ctx, id)
}

func (s *UserService) ValidatePassword(ctx context.Context, email, password string) (*domain.User, error) {
	user, err := s.repo.GetUserByEmail(ctx, email)
	if err != nil {
		return nil, errors.New("invalid credentials")
	}

	if user.Status != domain.UserStatusActive {
		return nil, errors.New("account is not active")
	}

	if user.LockedUntil != nil && time.Now().Before(*user.LockedUntil) {
		return nil, errors.New("account is locked")
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(password)); err != nil {
		// Increment failed attempts
		attempts := user.FailedAttempts + 1
		var lockedUntil *time.Time
		if attempts >= 5 {
			lockTime := time.Now().Add(30 * time.Minute)
			lockedUntil = &lockTime
		}
		s.repo.UpdateLoginAttempts(ctx, user.ID, attempts, lockedUntil)
		return nil, errors.New("invalid credentials")
	}

	// Reset failed attempts on successful login
	if user.FailedAttempts > 0 {
		s.repo.UpdateLoginAttempts(ctx, user.ID, 0, nil)
	}

	return user, nil
}

// Request/Response types
type CreateUserRequest struct {
	Email     string     `json:"email" validate:"required,email"`
	Username  string     `json:"username" validate:"required,min=3,max=50"`
	Password  string     `json:"password" validate:"required,min=8"`
	FirstName *string    `json:"firstName"`
	LastName  *string    `json:"lastName"`
	RoleID    *uuid.UUID `json:"roleId"`
}

type UpdateUserRequest struct {
	FirstName *string              `json:"firstName"`
	LastName  *string              `json:"lastName"`
	Status    *domain.UserStatus   `json:"status"`
	RoleID    *uuid.UUID           `json:"roleId"`
}
