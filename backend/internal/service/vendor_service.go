package service

import (
	"aqura-backend/internal/domain"
	"context"
	"errors"

	"github.com/google/uuid"
)

// VendorService handles vendor management
type VendorService struct {
	repo VendorRepository
}

type VendorRepository interface {
	CreateVendor(ctx context.Context, vendor *domain.Vendor) error
	GetVendorByID(ctx context.Context, id uuid.UUID) (*domain.Vendor, error)
	GetVendorByCode(ctx context.Context, code string) (*domain.Vendor, error)
	UpdateVendor(ctx context.Context, vendor *domain.Vendor) error
	DeleteVendor(ctx context.Context, id uuid.UUID) error
	ListVendors(ctx context.Context, offset, limit int, filters VendorFilters) ([]*domain.Vendor, int, error)
	GetActiveVendors(ctx context.Context) ([]*domain.Vendor, error)
}

type VendorFilters struct {
	Category *string
	Status   *domain.VendorStatus
	Search   *string
}

func NewVendorService(repo VendorRepository) *VendorService {
	return &VendorService{repo: repo}
}

func (s *VendorService) CreateVendor(ctx context.Context, req CreateVendorRequest) (*domain.Vendor, error) {
	// Check if vendor code already exists
	if existing, _ := s.repo.GetVendorByCode(ctx, req.VendorID); existing != nil {
		return nil, errors.New("vendor with this ID already exists")
	}

	vendor := &domain.Vendor{
		VendorID:      req.VendorID,
		Name:          req.Name,
		TaxID:         req.TaxID,
		ContactPerson: req.ContactPerson,
		Email:         req.Email,
		Phone:         req.Phone,
		Address:       req.Address,
		PaymentTerms:  req.PaymentTerms,
		Category:      req.Category,
		Status:        domain.VendorStatusActive,
	}

	if err := s.repo.CreateVendor(ctx, vendor); err != nil {
		return nil, err
	}

	return vendor, nil
}

func (s *VendorService) GetVendorByID(ctx context.Context, id uuid.UUID) (*domain.Vendor, error) {
	return s.repo.GetVendorByID(ctx, id)
}

func (s *VendorService) UpdateVendor(ctx context.Context, id uuid.UUID, req UpdateVendorRequest) (*domain.Vendor, error) {
	vendor, err := s.repo.GetVendorByID(ctx, id)
	if err != nil {
		return nil, err
	}

	// Update fields
	if req.Name != nil {
		vendor.Name = *req.Name
	}
	if req.Category != nil {
		vendor.Category = *req.Category
	}
	if req.ContactPerson != nil {
		vendor.ContactPerson = *req.ContactPerson
	}
	if req.Email != nil {
		vendor.Email = *req.Email
	}
	if req.Phone != nil {
		vendor.Phone = req.Phone
	}
	if req.Address != nil {
		vendor.Address = req.Address
	}
	if req.Status != nil {
		vendor.Status = *req.Status
	}

	if err := s.repo.UpdateVendor(ctx, vendor); err != nil {
		return nil, err
	}

	return vendor, nil
}

func (s *VendorService) DeleteVendor(ctx context.Context, id uuid.UUID) error {
	return s.repo.DeleteVendor(ctx, id)
}

func (s *VendorService) ListVendors(ctx context.Context, req ListVendorsRequest) (*ListVendorsResponse, error) {
	filters := VendorFilters{
		Category: req.Category,
		Status:   req.Status,
		Search:   req.Search,
	}

	vendors, total, err := s.repo.ListVendors(ctx, req.Offset, req.Limit, filters)
	if err != nil {
		return nil, err
	}

	return &ListVendorsResponse{
		Vendors: vendors,
		Total:   total,
		Offset:  req.Offset,
		Limit:   req.Limit,
	}, nil
}

// DTOs
type CreateVendorRequest struct {
	VendorID      string  `json:"vendorId" validate:"required"`
	Name          string  `json:"name" validate:"required"`
	TaxID         *string `json:"taxId"`
	ContactPerson string  `json:"contactPerson" validate:"required"`
	Email         string  `json:"email" validate:"required,email"`
	Phone         *string `json:"phone"`
	Address       *string `json:"address"`
	PaymentTerms  *string `json:"paymentTerms"`
	Category      string  `json:"category" validate:"required"`
}

type UpdateVendorRequest struct {
	Name          *string               `json:"name"`
	Category      *string               `json:"category"`
	ContactPerson *string               `json:"contactPerson"`
	Email         *string               `json:"email" validate:"omitempty,email"`
	Phone         *string               `json:"phone"`
	Address       *string               `json:"address"`
	Status        *domain.VendorStatus  `json:"status"`
}

type ListVendorsRequest struct {
	Offset   int                   `json:"offset"`
	Limit    int                   `json:"limit"`
	Category *string               `json:"category"`
	Status   *domain.VendorStatus  `json:"status"`
	Search   *string               `json:"search"`
}

type ListVendorsResponse struct {
	Vendors []*domain.Vendor `json:"vendors"`
	Total   int              `json:"total"`
	Offset  int              `json:"offset"`
	Limit   int              `json:"limit"`
}
