package service

import (
	"aqura-backend/internal/domain"
	"context"
	"errors"

	"github.com/google/uuid"
)

// BranchService handles branch management
type BranchService struct {
	repo BranchRepository
}

type BranchRepository interface {
	CreateBranch(ctx context.Context, branch *domain.Branch) error
	GetBranchByID(ctx context.Context, id uuid.UUID) (*domain.Branch, error)
	GetBranchByCode(ctx context.Context, code string) (*domain.Branch, error)
	UpdateBranch(ctx context.Context, branch *domain.Branch) error
	DeleteBranch(ctx context.Context, id uuid.UUID) error
	ListBranches(ctx context.Context, offset, limit int, filters BranchFilters) ([]*domain.Branch, int, error)
	GetActiveBranches(ctx context.Context) ([]*domain.Branch, error)
}

type BranchFilters struct {
	Region *string
	Status *domain.BranchStatus
	Search *string
}

func NewBranchService(repo BranchRepository) *BranchService {
	return &BranchService{repo: repo}
}

func (s *BranchService) CreateBranch(ctx context.Context, req CreateBranchRequest) (*domain.Branch, error) {
	// Check if branch code already exists
	if existing, _ := s.repo.GetBranchByCode(ctx, req.Code); existing != nil {
		return nil, errors.New("branch with this code already exists")
	}

	branch := &domain.Branch{
		BranchID:      req.BranchID,
		Name:          req.Name,
		Code:          req.Code,
		Region:        req.Region,
		Address:       req.Address,
		Timezone:      req.Timezone,
		ContactPerson: req.ContactPerson,
		ContactEmail:  req.ContactEmail,
		ContactPhone:  req.ContactPhone,
		Status:        domain.BranchStatusActive,
	}

	if err := s.repo.CreateBranch(ctx, branch); err != nil {
		return nil, err
	}

	return branch, nil
}

func (s *BranchService) GetBranch(ctx context.Context, id uuid.UUID) (*domain.Branch, error) {
	return s.repo.GetBranchByID(ctx, id)
}

func (s *BranchService) UpdateBranch(ctx context.Context, id uuid.UUID, req UpdateBranchRequest) (*domain.Branch, error) {
	branch, err := s.repo.GetBranchByID(ctx, id)
	if err != nil {
		return nil, err
	}

	if req.Name != nil {
		branch.Name = *req.Name
	}
	if req.Region != nil {
		branch.Region = *req.Region
	}
	if req.Address != nil {
		branch.Address = req.Address
	}
	if req.Timezone != nil {
		branch.Timezone = *req.Timezone
	}
	if req.ContactPerson != nil {
		branch.ContactPerson = req.ContactPerson
	}
	if req.ContactEmail != nil {
		branch.ContactEmail = req.ContactEmail
	}
	if req.ContactPhone != nil {
		branch.ContactPhone = req.ContactPhone
	}
	if req.Status != nil {
		branch.Status = *req.Status
	}

	if err := s.repo.UpdateBranch(ctx, branch); err != nil {
		return nil, err
	}

	return branch, nil
}

func (s *BranchService) ListBranches(ctx context.Context, offset, limit int, filters BranchFilters) ([]*domain.Branch, int, error) {
	return s.repo.ListBranches(ctx, offset, limit, filters)
}

func (s *BranchService) DeleteBranch(ctx context.Context, id uuid.UUID) error {
	return s.repo.DeleteBranch(ctx, id)
}

// Request/Response types
type CreateBranchRequest struct {
	BranchID      string  `json:"branchId" validate:"required"`
	Name          string  `json:"name" validate:"required,min=2,max=200"`
	Code          string  `json:"code" validate:"required,min=2,max=10"`
	Region        string  `json:"region" validate:"required"`
	Address       *string `json:"address"`
	Timezone      string  `json:"timezone"`
	ContactPerson *string `json:"contactPerson"`
	ContactEmail  *string `json:"contactEmail" validate:"omitempty,email"`
	ContactPhone  *string `json:"contactPhone"`
}

type UpdateBranchRequest struct {
	Name          *string              `json:"name" validate:"omitempty,min=2,max=200"`
	Region        *string              `json:"region"`
	Address       *string              `json:"address"`
	Timezone      *string              `json:"timezone"`
	ContactPerson *string              `json:"contactPerson"`
	ContactEmail  *string              `json:"contactEmail" validate:"omitempty,email"`
	ContactPhone  *string              `json:"contactPhone"`
	Status        *domain.BranchStatus `json:"status"`
}
