package domain

import (
	"time"
)

// NotificationType represents the type of notification
type NotificationType string

const (
	NotificationTypeInfo      NotificationType = "info"
	NotificationTypeWarning   NotificationType = "warning"
	NotificationTypeError     NotificationType = "error"
	NotificationTypeSuccess   NotificationType = "success"
	NotificationTypeUpdate    NotificationType = "update"
)

// NotificationPriority represents the priority of a notification
type NotificationPriority string

const (
	NotificationPriorityLow    NotificationPriority = "low"
	NotificationPriorityNormal NotificationPriority = "normal"
	NotificationPriorityHigh   NotificationPriority = "high"
	NotificationPriorityUrgent NotificationPriority = "urgent"
)

// NotificationStatus represents the status of a notification
type NotificationStatus string

const (
	NotificationStatusDraft     NotificationStatus = "draft"
	NotificationStatusScheduled NotificationStatus = "scheduled"
	NotificationStatusSent      NotificationStatus = "sent"
	NotificationStatusFailed    NotificationStatus = "failed"
	NotificationStatusCancelled NotificationStatus = "cancelled"
)

// TargetType represents who should receive the notification
type TargetType string

const (
	TargetTypeAllUsers        TargetType = "all_users"
	TargetTypeAllAdmins       TargetType = "all_admins"
	TargetTypeSpecificUsers   TargetType = "specific_users"
	TargetTypeSpecificRoles   TargetType = "specific_roles"
	TargetTypeSpecificBranches TargetType = "specific_branches"
)

// Notification represents a notification in the system
type Notification struct {
	ID               string                 `json:"id" db:"id"`
	Title            string                 `json:"title" db:"title"`
	Message          string                 `json:"message" db:"message"`
	Type             NotificationType       `json:"type" db:"type"`
	Priority         NotificationPriority   `json:"priority" db:"priority"`
	Status           NotificationStatus     `json:"status" db:"status"`
	CreatedBy        string                 `json:"created_by" db:"created_by"`
	CreatedByName    string                 `json:"created_by_name" db:"created_by_name"`
	CreatedByRole    string                 `json:"created_by_role" db:"created_by_role"`
	TargetType       TargetType             `json:"target_type" db:"target_type"`
	ScheduledFor     *time.Time             `json:"scheduled_for" db:"scheduled_for"`
	SentAt           *time.Time             `json:"sent_at" db:"sent_at"`
	ExpiresAt        *time.Time             `json:"expires_at" db:"expires_at"`
	HasAttachments   bool                   `json:"has_attachments" db:"has_attachments"`
	ReadCount        int                    `json:"read_count" db:"read_count"`
	TotalRecipients  int                    `json:"total_recipients" db:"total_recipients"`
	CreatedAt        time.Time              `json:"created_at" db:"created_at"`
	UpdatedAt        time.Time              `json:"updated_at" db:"updated_at"`
	DeletedAt        *time.Time             `json:"deleted_at,omitempty" db:"deleted_at"`
}

// NotificationRecipient represents a notification recipient
type NotificationRecipient struct {
	ID                      string                 `json:"id" db:"id"`
	NotificationID          string                 `json:"notification_id" db:"notification_id"`
	UserID                  string                 `json:"user_id" db:"user_id"`
	BranchID                *string                `json:"branch_id" db:"branch_id"`
	Role                    *string                `json:"role" db:"role"`
	IsRead                  bool                   `json:"is_read" db:"is_read"`
	ReadAt                  *time.Time             `json:"read_at" db:"read_at"`
	IsDismissed             bool                   `json:"is_dismissed" db:"is_dismissed"`
	DismissedAt             *time.Time             `json:"dismissed_at" db:"dismissed_at"`
	CreatedAt               time.Time              `json:"created_at" db:"created_at"`
	UpdatedAt               time.Time              `json:"updated_at" db:"updated_at"`
	
	// Joined fields from notification
	Title                   string                 `json:"title"`
	Message                 string                 `json:"message"`
	Type                    NotificationType       `json:"type"`
	Priority                NotificationPriority   `json:"priority"`
	NotificationCreatedAt   time.Time              `json:"notification_created_at"`
}

// NotificationAttachment represents a file attachment to a notification
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
	Title           string                 `json:"title" binding:"required"`
	Message         string                 `json:"message" binding:"required"`
	Type            NotificationType       `json:"type" binding:"required"`
	Priority        NotificationPriority   `json:"priority" binding:"required"`
	TargetType      TargetType             `json:"target_type" binding:"required"`
	TargetUsers     []string               `json:"target_users,omitempty"`
	TargetRoles     []string               `json:"target_roles,omitempty"`
	TargetBranches  []string               `json:"target_branches,omitempty"`
	ScheduledFor    *time.Time             `json:"scheduled_for,omitempty"`
	ExpiresAt       *time.Time             `json:"expires_at,omitempty"`
}

// UpdateNotificationRequest represents a request to update a notification
type UpdateNotificationRequest struct {
	Title        *string                 `json:"title,omitempty"`
	Message      *string                 `json:"message,omitempty"`
	Priority     *NotificationPriority   `json:"priority,omitempty"`
	Status       *NotificationStatus     `json:"status,omitempty"`
	ScheduledFor *time.Time              `json:"scheduled_for,omitempty"`
	ExpiresAt    *time.Time              `json:"expires_at,omitempty"`
}

// NotificationListResponse represents a paginated list of notifications
type NotificationListResponse struct {
	Data        []Notification `json:"data"`
	Total       int            `json:"total"`
	Page        int            `json:"page"`
	Limit       int            `json:"limit"`
	TotalPages  int            `json:"total_pages"`
}

// UserNotificationListResponse represents a paginated list of user notifications
type UserNotificationListResponse struct {
	Data        []NotificationRecipient `json:"data"`
	Total       int                     `json:"total"`
	Page        int                     `json:"page"`
	Limit       int                     `json:"limit"`
	TotalPages  int                     `json:"total_pages"`
}
