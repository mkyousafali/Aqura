package repository

import (
	"aqura-backend/internal/domain"
	"aqura-backend/internal/service"
	"context"
	"strings"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type branchRepository struct {
	db *gorm.DB
}

func NewBranchRepository(db *gorm.DB) service.BranchRepository {
	return &branchRepository{db: db}
}

func (r *branchRepository) CreateBranch(ctx context.Context, branch *domain.Branch) error {
	return r.db.WithContext(ctx).Create(branch).Error
}

func (r *branchRepository) GetBranchByID(ctx context.Context, id uuid.UUID) (*domain.Branch, error) {
	var branch domain.Branch
	err := r.db.WithContext(ctx).
		Preload("Manager").
		First(&branch, "id = ?", id).Error
	if err != nil {
		return nil, err
	}
	return &branch, nil
}

func (r *branchRepository) GetBranchByCode(ctx context.Context, code string) (*domain.Branch, error) {
	var branch domain.Branch
	err := r.db.WithContext(ctx).
		Preload("Manager").
		First(&branch, "code = ?", code).Error
	if err != nil {
		return nil, err
	}
	return &branch, nil
}

func (r *branchRepository) UpdateBranch(ctx context.Context, branch *domain.Branch) error {
	return r.db.WithContext(ctx).Save(branch).Error
}

func (r *branchRepository) DeleteBranch(ctx context.Context, id uuid.UUID) error {
	return r.db.WithContext(ctx).Delete(&domain.Branch{}, "id = ?", id).Error
}

func (r *branchRepository) ListBranches(ctx context.Context, offset, limit int, filters service.BranchFilters) ([]*domain.Branch, int, error) {
	var branches []*domain.Branch
	var total int64

	query := r.db.WithContext(ctx).Model(&domain.Branch{})

	// Apply filters
	if filters.Status != nil {
		query = query.Where("status = ?", *filters.Status)
	}
	if filters.Region != nil {
		query = query.Where("region = ?", *filters.Region)
	}
	if filters.Search != nil {
		search := "%" + strings.ToLower(*filters.Search) + "%"
		query = query.Where(
			"LOWER(name) LIKE ? OR LOWER(code) LIKE ? OR LOWER(address) LIKE ?",
			search, search, search,
		)
	}

	// Count total
	if err := query.Count(&total).Error; err != nil {
		return nil, 0, err
	}

	// Get branches with pagination
	err := query.
		Preload("Manager").
		Offset(offset).
		Limit(limit).
		Order("created_at DESC").
		Find(&branches).Error

	return branches, int(total), err
}

func (r *branchRepository) GetActiveBranches(ctx context.Context) ([]*domain.Branch, error) {
	var branches []*domain.Branch
	err := r.db.WithContext(ctx).
		Preload("Manager").
		Where("status = ?", "active").
		Order("name ASC").
		Find(&branches).Error
	return branches, err
}
