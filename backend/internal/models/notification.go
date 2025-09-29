package models

import (
	"time"
	"database/sql/driver"
)

// NotificationType represents the type of notification
type NotificationType string

const (
	NotificationTypeInfo     NotificationType = "info"
	NotificationTypeSuccess  NotificationType = "success"
	NotificationTypeWarning  NotificationType = "warning"
	NotificationTypeError    NotificationType = "error"
	NotificationTypeMarketing NotificationType = "marketing"
)

func (nt *NotificationType) Scan(value interface{}) error {
	if value != nil {
		*nt = NotificationType(value.(string))
	}
	return nil
}

func (nt NotificationType) Value() (driver.Value, error) {
	return string(nt), nil
}

// NotificationPriority represents the priority of notification
type NotificationPriority string

const (
	NotificationPriorityLow    NotificationPriority = "low"
	NotificationPriorityMedium NotificationPriority = "medium"
	NotificationPriorityHigh   NotificationPriority = "high"
	NotificationPriorityUrgent NotificationPriority = "urgent"
)

func (np *NotificationPriority) Scan(value interface{}) error {
	if value != nil {
		*np = NotificationPriority(value.(string))
	}
	return nil
}

func (np NotificationPriority) Value() (driver.Value, error) {
	return string(np), nil
}

// NotificationStatus represents the status of notification
type NotificationStatus string

const (
	NotificationStatusDraft     NotificationStatus = "draft"
	NotificationStatusScheduled NotificationStatus = "scheduled"
	NotificationStatusSent      NotificationStatus = "sent"
	NotificationStatusFailed    NotificationStatus = "failed"
	NotificationStatusCancelled NotificationStatus = "cancelled"
)

func (ns *NotificationStatus) Scan(value interface{}) error {
	if value != nil {
		*ns = NotificationStatus(value.(string))
	}
	return nil
}

func (ns NotificationStatus) Value() (driver.Value, error) {
	return string(ns), nil
}

// TargetType represents the targeting type for notifications
type TargetType string

const (
	TargetTypeAllUsers    TargetType = "all_users"
	TargetTypeAllAdmins   TargetType = "all_admins"
	TargetTypeSpecificUsers TargetType = "specific_users"
	TargetTypeSpecificRoles TargetType = "specific_roles"
	TargetTypeSpecificBranches TargetType = "specific_branches"
)

func (tt *TargetType) Scan(value interface{}) error {
	if value != nil {
		*tt = TargetType(value.(string))
	}
	return nil
}

func (tt TargetType) Value() (driver.Value, error) {
	return string(tt), nil
}

// Notification represents a notification in the system
type Notification struct {
	ID                string               `json:"id" db:"id"`
	Title             string               `json:"title" db:"title"`
	Message           string               `json:"message" db:"message"`
	Type              NotificationType     `json:"type" db:"type"`
	Priority          NotificationPriority `json:"priority" db:"priority"`
	Status            NotificationStatus   `json:"status" db:"status"`
	CreatedBy         string               `json:"created_by" db:"created_by"`
	CreatedByName     string               `json:"created_by_name" db:"created_by_name"`
	CreatedByRole     string               `json:"created_by_role" db:"created_by_role"`
	TargetType        TargetType           `json:"target_type" db:"target_type"`
	ScheduledFor      *time.Time           `json:"scheduled_for" db:"scheduled_for"`
	SentAt            *time.Time           `json:"sent_at" db:"sent_at"`
	ExpiresAt         *time.Time           `json:"expires_at" db:"expires_at"`
	HasAttachments    bool                 `json:"has_attachments" db:"has_attachments"`
	ReadCount         int                  `json:"read_count" db:"read_count"`
	TotalRecipients   int                  `json:"total_recipients" db:"total_recipients"`
	CreatedAt         time.Time            `json:"created_at" db:"created_at"`
	UpdatedAt         time.Time            `json:"updated_at" db:"updated_at"`
	DeletedAt         *time.Time           `json:"deleted_at" db:"deleted_at"`
}

// NotificationRecipient represents a recipient of a notification
type NotificationRecipient struct {
	ID             string     `json:"id" db:"id"`
	NotificationID string     `json:"notification_id" db:"notification_id"`
	UserID         string     `json:"user_id" db:"user_id"`
	BranchID       *int       `json:"branch_id" db:"branch_id"`
	Role           *string    `json:"role" db:"role"`
	IsRead         bool       `json:"is_read" db:"is_read"`
	ReadAt         *time.Time `json:"read_at" db:"read_at"`
	IsDismissed    bool       `json:"is_dismissed" db:"is_dismissed"`
	DismissedAt    *time.Time `json:"dismissed_at" db:"dismissed_at"`
	CreatedAt      time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt      time.Time  `json:"updated_at" db:"updated_at"`
	
	// Joined fields from notification
	Title        string               `json:"title" db:"title"`
	Message      string               `json:"message" db:"message"`
	Type         NotificationType     `json:"type" db:"type"`
	Priority     NotificationPriority `json:"priority" db:"priority"`
	NotificationCreatedAt time.Time   `json:"notification_created_at" db:"notification_created_at"`
}

// NotificationAttachment represents a file attachment for a notification
type NotificationAttachment struct {
	ID             string    `json:"id" db:"id"`
	NotificationID string    `json:"notification_id" db:"notification_id"`
	FileName       string    `json:"file_name" db:"file_name"`
	FileSize       int64     `json:"file_size" db:"file_size"`
	FileType       string    `json:"file_type" db:"file_type"`
	FilePath       string    `json:"file_path" db:"file_path"`
	UploadedBy     string    `json:"uploaded_by" db:"uploaded_by"`
	CreatedAt      time.Time `json:"created_at" db:"created_at"`
}

// CreateNotificationRequest represents a request to create a notification
type CreateNotificationRequest struct {
	Title          string   `json:"title" validate:"required,min=1,max=255"`
	Message        string   `json:"message" validate:"required,min=1,max=10000"`
	Type           string   `json:"type" validate:"required,oneof=info success warning error marketing"`
	Priority       string   `json:"priority" validate:"required,oneof=low medium high urgent"`
	TargetType     string   `json:"target_type" validate:"required,oneof=all_users all_admins specific_users specific_roles specific_branches"`
	TargetBranches []int    `json:"target_branches"`
	TargetUsers    []string `json:"target_users"`
	TargetRoles    []string `json:"target_roles"`
	ScheduledFor   *time.Time `json:"scheduled_for"`
	ExpiresAt      *time.Time `json:"expires_at"`
}

// UpdateNotificationRequest represents a request to update a notification
type UpdateNotificationRequest struct {
	Title        *string `json:"title" validate:"omitempty,min=1,max=255"`
	Message      *string `json:"message" validate:"omitempty,min=1,max=10000"`
	Priority     *string `json:"priority" validate:"omitempty,oneof=low medium high urgent"`
	Status       *string `json:"status" validate:"omitempty,oneof=draft scheduled sent failed cancelled"`
	ScheduledFor *time.Time `json:"scheduled_for"`
	ExpiresAt    *time.Time `json:"expires_at"`
}