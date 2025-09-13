package domain

import (
	"time"
	"github.com/google/uuid"
	"github.com/shopspring/decimal"
)

// User represents a system user
type User struct {
	ID             uuid.UUID  `json:"id" gorm:"type:uuid;primary_key;default:gen_random_uuid()"`
	Email          string     `json:"email" gorm:"uniqueIndex;not null" validate:"required,email"`
	Username       string     `json:"username" gorm:"uniqueIndex;not null" validate:"required,min=3,max=50"`
	FirstName      *string    `json:"firstName" gorm:"size:100"`
	LastName       *string    `json:"lastName" gorm:"size:100"`
	PasswordHash   string     `json:"-" gorm:"not null"`
	Status         UserStatus `json:"status" gorm:"default:'pending'"`
	IsBootstrap    bool       `json:"isBootstrap" gorm:"default:false"`
	MFAEnabled     bool       `json:"mfaEnabled" gorm:"default:false"`
	MFASecret      *string    `json:"-"`
	LastLogin      *time.Time `json:"lastLogin"`
	FailedAttempts int        `json:"failedAttempts" gorm:"default:0"`
	LockedUntil    *time.Time `json:"lockedUntil"`
	RoleID         *uuid.UUID `json:"roleId"`
	Role           *UserRole  `json:"role,omitempty" gorm:"foreignKey:RoleID"`
	CreatedAt      time.Time  `json:"createdAt"`
	UpdatedAt      time.Time  `json:"updatedAt"`
}

type UserStatus string

const (
	UserStatusPending  UserStatus = "pending"
	UserStatusActive   UserStatus = "active"
	UserStatusInactive UserStatus = "inactive"
	UserStatusLocked   UserStatus = "locked"
)

// UserRole represents user roles and permissions
type UserRole struct {
	ID          uuid.UUID    `json:"id" gorm:"type:uuid;primary_key;default:gen_random_uuid()"`
	Name        string       `json:"name" gorm:"uniqueIndex;not null" validate:"required,min=2,max=100"`
	Description *string      `json:"description"`
	Permissions []Permission `json:"permissions" gorm:"foreignKey:RoleID"`
	CreatedAt   time.Time    `json:"createdAt"`
	UpdatedAt   time.Time    `json:"updatedAt"`
}

// Permission represents module permissions
type Permission struct {
	ID       uuid.UUID `json:"id" gorm:"type:uuid;primary_key;default:gen_random_uuid()"`
	RoleID   uuid.UUID `json:"roleId"`
	Module   string    `json:"module" validate:"required"`
	Actions  []string  `json:"actions" gorm:"type:text[]"`
	Scope    *string   `json:"scope"` // JSON string for hierarchy scope
}

// Employee represents HR master data
type Employee struct {
	ID           uuid.UUID      `json:"id" gorm:"type:uuid;primary_key;default:gen_random_uuid()"`
	EmployeeID   string         `json:"employeeId" gorm:"uniqueIndex;not null" validate:"required"`
	FirstName    string         `json:"firstName" gorm:"not null" validate:"required,min=2,max=100"`
	LastName     string         `json:"lastName" gorm:"not null" validate:"required,min=2,max=100"`
	Email        string         `json:"email" gorm:"uniqueIndex;not null" validate:"required,email"`
	Phone        *string        `json:"phone"`
	Department   string         `json:"department" validate:"required"`
	Designation  string         `json:"designation" validate:"required"`
	Status       EmployeeStatus `json:"status" gorm:"default:'active'"`
	BranchID     *uuid.UUID     `json:"branchId"`
	Branch       *Branch        `json:"branch,omitempty" gorm:"foreignKey:BranchID"`
	ManagerID    *uuid.UUID     `json:"managerId"`
	Manager      *Employee      `json:"manager,omitempty" gorm:"foreignKey:ManagerID"`
	JoinDate     time.Time      `json:"joinDate"`
	CreatedAt    time.Time      `json:"createdAt"`
	UpdatedAt    time.Time      `json:"updatedAt"`
}

type EmployeeStatus string

const (
	EmployeeStatusActive   EmployeeStatus = "active"
	EmployeeStatusInactive EmployeeStatus = "inactive"
	EmployeeStatusPending  EmployeeStatus = "pending"
)

// Branch represents branch master data
type Branch struct {
	ID            uuid.UUID    `json:"id" gorm:"type:uuid;primary_key;default:gen_random_uuid()"`
	BranchID      string       `json:"branchId" gorm:"uniqueIndex;not null" validate:"required"`
	Name          string       `json:"name" gorm:"not null" validate:"required,min=2,max=200"`
	Code          string       `json:"code" gorm:"uniqueIndex;not null" validate:"required,min=2,max=10"`
	Region        string       `json:"region" validate:"required"`
	Address       *string      `json:"address"`
	Timezone      string       `json:"timezone" gorm:"default:'UTC'"`
	ContactPerson *string      `json:"contactPerson"`
	ContactEmail  *string      `json:"contactEmail" validate:"omitempty,email"`
	ContactPhone  *string      `json:"contactPhone"`
	Status        BranchStatus `json:"status" gorm:"default:'active'"`
	CreatedAt     time.Time    `json:"createdAt"`
	UpdatedAt     time.Time    `json:"updatedAt"`
}

type BranchStatus string

const (
	BranchStatusActive   BranchStatus = "active"
	BranchStatusInactive BranchStatus = "inactive"
)

// Vendor represents vendor master data
type Vendor struct {
	ID           uuid.UUID    `json:"id" gorm:"type:uuid;primary_key;default:gen_random_uuid()"`
	VendorID     string       `json:"vendorId" gorm:"uniqueIndex;not null" validate:"required"`
	Name         string       `json:"name" gorm:"not null" validate:"required,min=2,max=200"`
	TaxID        *string      `json:"taxId"`
	ContactPerson string      `json:"contactPerson" validate:"required"`
	Email        string       `json:"email" validate:"required,email"`
	Phone        *string      `json:"phone"`
	Address      *string      `json:"address"`
	PaymentTerms *string      `json:"paymentTerms"`
	Category     string       `json:"category" validate:"required"`
	Status       VendorStatus `json:"status" gorm:"default:'active'"`
	CreatedAt    time.Time    `json:"createdAt"`
	UpdatedAt    time.Time    `json:"updatedAt"`
}

type VendorStatus string

const (
	VendorStatusActive   VendorStatus = "active"
	VendorStatusInactive VendorStatus = "inactive"
)

// Invoice represents invoice master data
type Invoice struct {
	ID          uuid.UUID     `json:"id" gorm:"type:uuid;primary_key;default:gen_random_uuid()"`
	InvoiceNo   string        `json:"invoiceNo" gorm:"uniqueIndex;not null" validate:"required"`
	VendorID    uuid.UUID     `json:"vendorId" validate:"required"`
	Vendor      *Vendor       `json:"vendor,omitempty" gorm:"foreignKey:VendorID"`
	BranchID    uuid.UUID     `json:"branchId" validate:"required"`
	Branch      *Branch       `json:"branch,omitempty" gorm:"foreignKey:BranchID"`
	Date        time.Time     `json:"date" validate:"required"`
	DueDate     *time.Time    `json:"dueDate"`
	Currency    string        `json:"currency" gorm:"default:'USD'" validate:"required,len=3"`
	Subtotal    decimal.Decimal `json:"subtotal" gorm:"type:decimal(15,2)" validate:"required,min=0"`
	Tax         decimal.Decimal `json:"tax" gorm:"type:decimal(15,2)" validate:"min=0"`
	Total       decimal.Decimal `json:"total" gorm:"type:decimal(15,2)" validate:"required,min=0"`
	Status      InvoiceStatus `json:"status" gorm:"default:'draft'"`
	Attachments []string      `json:"attachments" gorm:"type:text[]"`
	CreatedAt   time.Time     `json:"createdAt"`
	UpdatedAt   time.Time     `json:"updatedAt"`
}

type InvoiceStatus string

const (
	InvoiceStatusDraft  InvoiceStatus = "draft"
	InvoiceStatusPosted InvoiceStatus = "posted"
	InvoiceStatusPaid   InvoiceStatus = "paid"
)

// ImportJob represents data import jobs
type ImportJob struct {
	ID            uuid.UUID       `json:"id" gorm:"type:uuid;primary_key;default:gen_random_uuid()"`
	UserID        uuid.UUID       `json:"userId"`
	User          *User           `json:"user,omitempty" gorm:"foreignKey:UserID"`
	Module        string          `json:"module" validate:"required"`
	FileName      string          `json:"fileName" validate:"required"`
	FileURL       string          `json:"fileUrl" validate:"required"`
	Status        ImportStatus    `json:"status" gorm:"default:'pending'"`
	TotalRows     int             `json:"totalRows"`
	ValidRows     int             `json:"validRows"`
	InvalidRows   int             `json:"invalidRows"`
	CommittedRows int             `json:"committedRows"`
	Mapping       *string         `json:"mapping"` // JSON string for column mapping
	Errors        []ImportError   `json:"errors" gorm:"foreignKey:ImportJobID"`
	CreatedAt     time.Time       `json:"createdAt"`
	UpdatedAt     time.Time       `json:"updatedAt"`
	CompletedAt   *time.Time      `json:"completedAt"`
}

type ImportStatus string

const (
	ImportStatusPending    ImportStatus = "pending"
	ImportStatusProcessing ImportStatus = "processing"
	ImportStatusValidated  ImportStatus = "validated"
	ImportStatusCommitted  ImportStatus = "committed"
	ImportStatusFailed     ImportStatus = "failed"
	ImportStatusRolledBack ImportStatus = "rolledback"
)

// ImportError represents import validation errors
type ImportError struct {
	ID          uuid.UUID `json:"id" gorm:"type:uuid;primary_key;default:gen_random_uuid()"`
	ImportJobID uuid.UUID `json:"importJobId"`
	RowNumber   int       `json:"rowNumber"`
	Field       string    `json:"field"`
	Value       *string   `json:"value"`
	Error       string    `json:"error"`
	Severity    string    `json:"severity"` // error, warning
	CreatedAt   time.Time `json:"createdAt"`
}

// AuditLog represents system audit trail
type AuditLog struct {
	ID        uuid.UUID `json:"id" gorm:"type:uuid;primary_key;default:gen_random_uuid()"`
	UserID    *uuid.UUID `json:"userId"`
	User      *User     `json:"user,omitempty" gorm:"foreignKey:UserID"`
	Action    string    `json:"action" validate:"required"`
	Module    string    `json:"module" validate:"required"`
	EntityID  *string   `json:"entityId"`
	OldData   *string   `json:"oldData"` // JSON string
	NewData   *string   `json:"newData"` // JSON string
	IPAddress string    `json:"ipAddress"`
	UserAgent *string   `json:"userAgent"`
	CreatedAt time.Time `json:"createdAt"`
}
