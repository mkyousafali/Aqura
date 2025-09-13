package repository

import (
	"aqura-backend/internal/domain"
	"aqura-backend/internal/service"
	"context"
	"strings"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type vendorRepository struct {
	db *gorm.DB
}

func NewVendorRepository(db *gorm.DB) service.VendorRepository {
	return &vendorRepository{db: db}
}

func (r *vendorRepository) CreateVendor(ctx context.Context, vendor *domain.Vendor) error {
	return r.db.WithContext(ctx).Create(vendor).Error
}

func (r *vendorRepository) GetVendorByID(ctx context.Context, id uuid.UUID) (*domain.Vendor, error) {
	var vendor domain.Vendor
	err := r.db.WithContext(ctx).First(&vendor, "id = ?", id).Error
	if err != nil {
		return nil, err
	}
	return &vendor, nil
}

func (r *vendorRepository) GetVendorByCode(ctx context.Context, code string) (*domain.Vendor, error) {
	var vendor domain.Vendor
	err := r.db.WithContext(ctx).First(&vendor, "vendor_id = ?", code).Error
	if err != nil {
		return nil, err
	}
	return &vendor, nil
}

func (r *vendorRepository) UpdateVendor(ctx context.Context, vendor *domain.Vendor) error {
	return r.db.WithContext(ctx).Save(vendor).Error
}

func (r *vendorRepository) DeleteVendor(ctx context.Context, id uuid.UUID) error {
	return r.db.WithContext(ctx).Delete(&domain.Vendor{}, "id = ?", id).Error
}

func (r *vendorRepository) ListVendors(ctx context.Context, offset, limit int, filters service.VendorFilters) ([]*domain.Vendor, int, error) {
	var vendors []*domain.Vendor
	var total int64

	query := r.db.WithContext(ctx).Model(&domain.Vendor{})

	// Apply filters
	if filters.Status != nil {
		query = query.Where("status = ?", *filters.Status)
	}
	if filters.Category != nil {
		query = query.Where("category = ?", *filters.Category)
	}
	if filters.Search != nil {
		search := "%" + strings.ToLower(*filters.Search) + "%"
		query = query.Where(
			"LOWER(name) LIKE ? OR LOWER(vendor_id) LIKE ? OR LOWER(email) LIKE ?",
			search, search, search,
		)
	}

	// Count total
	if err := query.Count(&total).Error; err != nil {
		return nil, 0, err
	}

	// Get vendors with pagination
	err := query.
		Offset(offset).
		Limit(limit).
		Order("created_at DESC").
		Find(&vendors).Error

	return vendors, int(total), err
}

func (r *vendorRepository) GetActiveVendors(ctx context.Context) ([]*domain.Vendor, error) {
	var vendors []*domain.Vendor
	err := r.db.WithContext(ctx).
		Where("status = ?", "active").
		Order("name ASC").
		Find(&vendors).Error
	return vendors, err
}
