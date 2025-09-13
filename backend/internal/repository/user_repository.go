package repository

import (
	"aqura-backend/internal/domain"
	"aqura-backend/internal/service"
	"context"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type userRepository struct {
	db *gorm.DB
}

func NewUserRepository(db *gorm.DB) service.UserRepository {
	return &userRepository{db: db}
}

func (r *userRepository) CreateUser(ctx context.Context, user *domain.User) error {
	return r.db.WithContext(ctx).Create(user).Error
}

func (r *userRepository) GetUserByID(ctx context.Context, id uuid.UUID) (*domain.User, error) {
	var user domain.User
	err := r.db.WithContext(ctx).
		Preload("Role").
		First(&user, "id = ?", id).Error
	if err != nil {
		return nil, err
	}
	return &user, nil
}

func (r *userRepository) GetUserByEmail(ctx context.Context, email string) (*domain.User, error) {
	var user domain.User
	err := r.db.WithContext(ctx).
		Preload("Role").
		First(&user, "email = ?", email).Error
	if err != nil {
		return nil, err
	}
	return &user, nil
}

func (r *userRepository) GetUserByUsername(ctx context.Context, username string) (*domain.User, error) {
	var user domain.User
	err := r.db.WithContext(ctx).
		Preload("Role").
		First(&user, "username = ?", username).Error
	if err != nil {
		return nil, err
	}
	return &user, nil
}

func (r *userRepository) UpdateUser(ctx context.Context, user *domain.User) error {
	return r.db.WithContext(ctx).Save(user).Error
}

func (r *userRepository) DeleteUser(ctx context.Context, id uuid.UUID) error {
	return r.db.WithContext(ctx).Delete(&domain.User{}, "id = ?", id).Error
}

func (r *userRepository) ListUsers(ctx context.Context, offset, limit int) ([]*domain.User, int, error) {
	var users []*domain.User
	var total int64

	// Count total
	if err := r.db.WithContext(ctx).Model(&domain.User{}).Count(&total).Error; err != nil {
		return nil, 0, err
	}

	// Get users with pagination
	err := r.db.WithContext(ctx).
		Preload("Role").
		Offset(offset).
		Limit(limit).
		Order("created_at DESC").
		Find(&users).Error

	return users, int(total), err
}

func (r *userRepository) UpdateLoginAttempts(ctx context.Context, userID uuid.UUID, attempts int, lockedUntil *time.Time) error {
	return r.db.WithContext(ctx).
		Model(&domain.User{}).
		Where("id = ?", userID).
		Updates(map[string]interface{}{
			"failed_attempts": attempts,
			"locked_until":    lockedUntil,
		}).Error
}
