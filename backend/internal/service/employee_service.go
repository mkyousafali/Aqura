package service

import (
	"aqura-backend/internal/domain"
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
)

// EmployeeService handles employee management
type EmployeeService struct {
	repo EmployeeRepository
}

type EmployeeRepository interface {
	CreateEmployee(ctx context.Context, employee *domain.Employee) error
	GetEmployeeByID(ctx context.Context, id uuid.UUID) (*domain.Employee, error)
	GetEmployeeByEmployeeID(ctx context.Context, employeeID string) (*domain.Employee, error)
	UpdateEmployee(ctx context.Context, employee *domain.Employee) error
	DeleteEmployee(ctx context.Context, id uuid.UUID) error
	ListEmployees(ctx context.Context, offset, limit int, filters EmployeeFilters) ([]*domain.Employee, int, error)
}

type EmployeeFilters struct {
	Department  *string
	Status      *domain.EmployeeStatus
	BranchID    *uuid.UUID
	Search      *string
}

func NewEmployeeService(repo EmployeeRepository) *EmployeeService {
	return &EmployeeService{repo: repo}
}

func (s *EmployeeService) CreateEmployee(ctx context.Context, req CreateEmployeeRequest) (*domain.Employee, error) {
	// Check if employee ID already exists
	if existing, _ := s.repo.GetEmployeeByEmployeeID(ctx, req.EmployeeID); existing != nil {
		return nil, errors.New("employee with this ID already exists")
	}

	employee := &domain.Employee{
		EmployeeID:  req.EmployeeID,
		FirstName:   req.FirstName,
		LastName:    req.LastName,
		Email:       req.Email,
		Phone:       req.Phone,
		Department:  req.Department,
		Designation: req.Designation,
		Status:      domain.EmployeeStatusActive,
		BranchID:    req.BranchID,
		ManagerID:   req.ManagerID,
		JoinDate:    req.JoinDate,
	}

	if err := s.repo.CreateEmployee(ctx, employee); err != nil {
		return nil, err
	}

	return employee, nil
}

func (s *EmployeeService) GetEmployee(ctx context.Context, id uuid.UUID) (*domain.Employee, error) {
	return s.repo.GetEmployeeByID(ctx, id)
}

func (s *EmployeeService) UpdateEmployee(ctx context.Context, id uuid.UUID, req UpdateEmployeeRequest) (*domain.Employee, error) {
	employee, err := s.repo.GetEmployeeByID(ctx, id)
	if err != nil {
		return nil, err
	}

	if req.FirstName != nil {
		employee.FirstName = *req.FirstName
	}
	if req.LastName != nil {
		employee.LastName = *req.LastName
	}
	if req.Email != nil {
		employee.Email = *req.Email
	}
	if req.Phone != nil {
		employee.Phone = req.Phone
	}
	if req.Department != nil {
		employee.Department = *req.Department
	}
	if req.Designation != nil {
		employee.Designation = *req.Designation
	}
	if req.Status != nil {
		employee.Status = *req.Status
	}
	if req.BranchID != nil {
		employee.BranchID = req.BranchID
	}
	if req.ManagerID != nil {
		employee.ManagerID = req.ManagerID
	}

	if err := s.repo.UpdateEmployee(ctx, employee); err != nil {
		return nil, err
	}

	return employee, nil
}

func (s *EmployeeService) ListEmployees(ctx context.Context, offset, limit int, filters EmployeeFilters) ([]*domain.Employee, int, error) {
	return s.repo.ListEmployees(ctx, offset, limit, filters)
}

func (s *EmployeeService) DeleteEmployee(ctx context.Context, id uuid.UUID) error {
	return s.repo.DeleteEmployee(ctx, id)
}

// Request/Response types
type CreateEmployeeRequest struct {
	EmployeeID  string     `json:"employeeId" validate:"required"`
	FirstName   string     `json:"firstName" validate:"required,min=2,max=100"`
	LastName    string     `json:"lastName" validate:"required,min=2,max=100"`
	Email       string     `json:"email" validate:"required,email"`
	Phone       *string    `json:"phone"`
	Department  string     `json:"department" validate:"required"`
	Designation string     `json:"designation" validate:"required"`
	BranchID    *uuid.UUID `json:"branchId"`
	ManagerID   *uuid.UUID `json:"managerId"`
	JoinDate    time.Time  `json:"joinDate" validate:"required"`
}

type UpdateEmployeeRequest struct {
	FirstName   *string                `json:"firstName" validate:"omitempty,min=2,max=100"`
	LastName    *string                `json:"lastName" validate:"omitempty,min=2,max=100"`
	Email       *string                `json:"email" validate:"omitempty,email"`
	Phone       *string                `json:"phone"`
	Department  *string                `json:"department"`
	Designation *string                `json:"designation"`
	Status      *domain.EmployeeStatus `json:"status"`
	BranchID    *uuid.UUID             `json:"branchId"`
	ManagerID   *uuid.UUID             `json:"managerId"`
}
