package repository

import (
	"aqura-backend/internal/domain"
	"aqura-backend/internal/service"
	"context"
	"strings"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type employeeRepository struct {
	db *gorm.DB
}

func NewEmployeeRepository(db *gorm.DB) service.EmployeeRepository {
	return &employeeRepository{db: db}
}

func (r *employeeRepository) CreateEmployee(ctx context.Context, employee *domain.Employee) error {
	return r.db.WithContext(ctx).Create(employee).Error
}

func (r *employeeRepository) GetEmployeeByID(ctx context.Context, id uuid.UUID) (*domain.Employee, error) {
	var employee domain.Employee
	err := r.db.WithContext(ctx).
		Preload("Branch").
		Preload("Manager").
		First(&employee, "id = ?", id).Error
	if err != nil {
		return nil, err
	}
	return &employee, nil
}

func (r *employeeRepository) GetEmployeeByEmployeeID(ctx context.Context, employeeID string) (*domain.Employee, error) {
	var employee domain.Employee
	err := r.db.WithContext(ctx).
		Preload("Branch").
		Preload("Manager").
		First(&employee, "employee_id = ?", employeeID).Error
	if err != nil {
		return nil, err
	}
	return &employee, nil
}

func (r *employeeRepository) UpdateEmployee(ctx context.Context, employee *domain.Employee) error {
	return r.db.WithContext(ctx).Save(employee).Error
}

func (r *employeeRepository) DeleteEmployee(ctx context.Context, id uuid.UUID) error {
	return r.db.WithContext(ctx).Delete(&domain.Employee{}, "id = ?", id).Error
}

func (r *employeeRepository) ListEmployees(ctx context.Context, offset, limit int, filters service.EmployeeFilters) ([]*domain.Employee, int, error) {
	var employees []*domain.Employee
	var total int64

	query := r.db.WithContext(ctx).Model(&domain.Employee{})

	// Apply filters
	if filters.Department != nil {
		query = query.Where("department = ?", *filters.Department)
	}
	if filters.Status != nil {
		query = query.Where("status = ?", *filters.Status)
	}
	if filters.BranchID != nil {
		query = query.Where("branch_id = ?", *filters.BranchID)
	}
	if filters.Search != nil {
		search := "%" + strings.ToLower(*filters.Search) + "%"
		query = query.Where(
			"LOWER(first_name) LIKE ? OR LOWER(last_name) LIKE ? OR LOWER(email) LIKE ? OR LOWER(employee_id) LIKE ?",
			search, search, search, search,
		)
	}

	// Count total
	if err := query.Count(&total).Error; err != nil {
		return nil, 0, err
	}

	// Get employees with pagination
	err := query.
		Preload("Branch").
		Preload("Manager").
		Offset(offset).
		Limit(limit).
		Order("created_at DESC").
		Find(&employees).Error

	return employees, int(total), err
}
