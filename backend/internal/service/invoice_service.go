package service

import (
	"aqura-backend/internal/domain"
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/shopspring/decimal"
)

// InvoiceService handles invoice management
type InvoiceService struct {
	repo InvoiceRepository
}

type InvoiceRepository interface {
	CreateInvoice(ctx context.Context, invoice *domain.Invoice) error
	GetInvoiceByID(ctx context.Context, id uuid.UUID) (*domain.Invoice, error)
	GetInvoiceByNumber(ctx context.Context, invoiceNo string) (*domain.Invoice, error)
	UpdateInvoice(ctx context.Context, invoice *domain.Invoice) error
	DeleteInvoice(ctx context.Context, id uuid.UUID) error
	ListInvoices(ctx context.Context, offset, limit int, filters InvoiceFilters) ([]*domain.Invoice, int, error)
}

type InvoiceFilters struct {
	VendorID *uuid.UUID
	BranchID *uuid.UUID
	Status   *domain.InvoiceStatus
	FromDate *time.Time
	ToDate   *time.Time
	Search   *string
}

func NewInvoiceService(repo InvoiceRepository) *InvoiceService {
	return &InvoiceService{repo: repo}
}

func (s *InvoiceService) CreateInvoice(ctx context.Context, req CreateInvoiceRequest) (*domain.Invoice, error) {
	// Check if invoice number already exists
	if existing, _ := s.repo.GetInvoiceByNumber(ctx, req.InvoiceNo); existing != nil {
		return nil, errors.New("invoice with this number already exists")
	}

	// Calculate total
	total := req.Subtotal.Add(req.Tax)

	invoice := &domain.Invoice{
		InvoiceNo:   req.InvoiceNo,
		VendorID:    req.VendorID,
		BranchID:    req.BranchID,
		Date:        req.Date,
		DueDate:     req.DueDate,
		Currency:    req.Currency,
		Subtotal:    req.Subtotal,
		Tax:         req.Tax,
		Total:       total,
		Status:      domain.InvoiceStatusDraft,
		Attachments: req.Attachments,
	}

	if err := s.repo.CreateInvoice(ctx, invoice); err != nil {
		return nil, err
	}

	return invoice, nil
}

func (s *InvoiceService) GetInvoice(ctx context.Context, id uuid.UUID) (*domain.Invoice, error) {
	return s.repo.GetInvoiceByID(ctx, id)
}

func (s *InvoiceService) UpdateInvoice(ctx context.Context, id uuid.UUID, req UpdateInvoiceRequest) (*domain.Invoice, error) {
	invoice, err := s.repo.GetInvoiceByID(ctx, id)
	if err != nil {
		return nil, err
	}

	if req.VendorID != nil {
		invoice.VendorID = *req.VendorID
	}
	if req.BranchID != nil {
		invoice.BranchID = *req.BranchID
	}
	if req.Date != nil {
		invoice.Date = *req.Date
	}
	if req.DueDate != nil {
		invoice.DueDate = req.DueDate
	}
	if req.Currency != nil {
		invoice.Currency = *req.Currency
	}
	if req.Subtotal != nil {
		invoice.Subtotal = *req.Subtotal
	}
	if req.Tax != nil {
		invoice.Tax = *req.Tax
	}
	if req.Status != nil {
		invoice.Status = *req.Status
	}
	if req.Attachments != nil {
		invoice.Attachments = req.Attachments
	}

	// Recalculate total
	invoice.Total = invoice.Subtotal.Add(invoice.Tax)

	if err := s.repo.UpdateInvoice(ctx, invoice); err != nil {
		return nil, err
	}

	return invoice, nil
}

func (s *InvoiceService) ListInvoices(ctx context.Context, offset, limit int, filters InvoiceFilters) ([]*domain.Invoice, int, error) {
	return s.repo.ListInvoices(ctx, offset, limit, filters)
}

func (s *InvoiceService) DeleteInvoice(ctx context.Context, id uuid.UUID) error {
	return s.repo.DeleteInvoice(ctx, id)
}

func (s *InvoiceService) PostInvoice(ctx context.Context, id uuid.UUID) error {
	invoice, err := s.repo.GetInvoiceByID(ctx, id)
	if err != nil {
		return err
	}

	if invoice.Status != domain.InvoiceStatusDraft {
		return errors.New("only draft invoices can be posted")
	}

	invoice.Status = domain.InvoiceStatusPosted
	return s.repo.UpdateInvoice(ctx, invoice)
}

func (s *InvoiceService) MarkAsPaid(ctx context.Context, id uuid.UUID) error {
	invoice, err := s.repo.GetInvoiceByID(ctx, id)
	if err != nil {
		return err
	}

	if invoice.Status != domain.InvoiceStatusPosted {
		return errors.New("only posted invoices can be marked as paid")
	}

	invoice.Status = domain.InvoiceStatusPaid
	return s.repo.UpdateInvoice(ctx, invoice)
}

// Request/Response types
type CreateInvoiceRequest struct {
	InvoiceNo   string          `json:"invoiceNo" validate:"required"`
	VendorID    uuid.UUID       `json:"vendorId" validate:"required"`
	BranchID    uuid.UUID       `json:"branchId" validate:"required"`
	Date        time.Time       `json:"date" validate:"required"`
	DueDate     *time.Time      `json:"dueDate"`
	Currency    string          `json:"currency" validate:"required,len=3"`
	Subtotal    decimal.Decimal `json:"subtotal" validate:"required,min=0"`
	Tax         decimal.Decimal `json:"tax" validate:"min=0"`
	Attachments []string        `json:"attachments"`
}

type UpdateInvoiceRequest struct {
	VendorID    *uuid.UUID       `json:"vendorId"`
	BranchID    *uuid.UUID       `json:"branchId"`
	Date        *time.Time       `json:"date"`
	DueDate     *time.Time       `json:"dueDate"`
	Currency    *string          `json:"currency" validate:"omitempty,len=3"`
	Subtotal    *decimal.Decimal `json:"subtotal" validate:"omitempty,min=0"`
	Tax         *decimal.Decimal `json:"tax" validate:"omitempty,min=0"`
	Status      *domain.InvoiceStatus `json:"status"`
	Attachments []string         `json:"attachments"`
}
