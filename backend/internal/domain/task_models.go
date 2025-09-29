package domain

import (
	"time"
)

// Task represents a task in the system
type Task struct {
	ID                   string     `json:"id" db:"id"`
	Title                string     `json:"title" db:"title"`
	Description          *string    `json:"description" db:"description"`
	
	// Multiple completion criteria (separate boolean fields)
	RequireTaskFinished  bool       `json:"require_task_finished" db:"require_task_finished"`
	RequirePhotoUpload   bool       `json:"require_photo_upload" db:"require_photo_upload"`
	RequireERPReference  bool       `json:"require_erp_reference" db:"require_erp_reference"`
	
	CanEscalate          bool       `json:"can_escalate" db:"can_escalate"`
	CanReassign          bool       `json:"can_reassign" db:"can_reassign"`
	CreatedBy            string     `json:"created_by" db:"created_by"`
	CreatedByName        *string    `json:"created_by_name" db:"created_by_name"`
	CreatedByRole        *string    `json:"created_by_role" db:"created_by_role"`
	Status               string     `json:"status" db:"status"`
	Priority             string     `json:"priority" db:"priority"`
	CreatedAt            time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt            time.Time  `json:"updated_at" db:"updated_at"`
	DeletedAt            *time.Time `json:"deleted_at,omitempty" db:"deleted_at"`
	
	// Separate date and time fields
	DueDate              *time.Time `json:"due_date,omitempty" db:"due_date"`    // date field
	DueTime              *time.Time `json:"due_time,omitempty" db:"due_time"`    // time field  
	DueDatetime          *time.Time `json:"due_datetime,omitempty" db:"due_datetime"` // combined
	
	// Relationships
	Images      []TaskImage      `json:"images,omitempty"`
	Assignments []TaskAssignment `json:"assignments,omitempty"`
}

// TaskImage represents an image associated with a task
type TaskImage struct {
	ID               string    `json:"id" db:"id"`
	TaskID           string    `json:"task_id" db:"task_id"`
	FileName         string    `json:"file_name" db:"file_name"`
	FileSize         int64     `json:"file_size" db:"file_size"`
	FileType         string    `json:"file_type" db:"file_type"`
	FileURL          string    `json:"file_url" db:"file_url"`
	ImageType        string    `json:"image_type" db:"image_type"` // 'task_creation', 'task_completion'
	UploadedBy       string    `json:"uploaded_by" db:"uploaded_by"`
	UploadedByName   *string   `json:"uploaded_by_name" db:"uploaded_by_name"`
	CreatedAt        time.Time `json:"created_at" db:"created_at"`
	ImageWidth       *int      `json:"image_width,omitempty" db:"image_width"`
	ImageHeight      *int      `json:"image_height,omitempty" db:"image_height"`
}

// TaskAssignment represents a task assignment
type TaskAssignment struct {
	ID                   string     `json:"id" db:"id"`
	TaskID               string     `json:"task_id" db:"task_id"`
	AssignmentType       string     `json:"assignment_type" db:"assignment_type"` // 'user', 'branch', 'all'
	AssignedToUserID     *string    `json:"assigned_to_user_id,omitempty" db:"assigned_to_user_id"`
	AssignedToBranchID   *string    `json:"assigned_to_branch_id,omitempty" db:"assigned_to_branch_id"`
	AssignedBy           string     `json:"assigned_by" db:"assigned_by"`
	AssignedByName       *string    `json:"assigned_by_name" db:"assigned_by_name"`
	AssignedAt           time.Time  `json:"assigned_at" db:"assigned_at"`
	Status               string     `json:"status" db:"status"` // 'assigned', 'in_progress', 'completed', 'escalated', 'reassigned'
	StartedAt            *time.Time `json:"started_at,omitempty" db:"started_at"`
	CompletedAt          *time.Time `json:"completed_at,omitempty" db:"completed_at"`
	
	// Additional fields for display
	AssignedToUserName   *string    `json:"assigned_to_user_name,omitempty"`
	AssignedToBranchName *string    `json:"assigned_to_branch_name,omitempty"`
}

// TaskCompletion represents a task completion record
type TaskCompletion struct {
	ID                       string     `json:"id" db:"id"`
	TaskID                   string     `json:"task_id" db:"task_id"`
	AssignmentID             string     `json:"assignment_id" db:"assignment_id"`
	CompletedBy              string     `json:"completed_by" db:"completed_by"`
	CompletedByName          *string    `json:"completed_by_name" db:"completed_by_name"`
	CompletedByBranchID      *string    `json:"completed_by_branch_id" db:"completed_by_branch_id"`
	
	// Multiple completion criteria tracking
	TaskFinishedCompleted    bool       `json:"task_finished_completed" db:"task_finished_completed"`
	PhotoUploadedCompleted   bool       `json:"photo_uploaded_completed" db:"photo_uploaded_completed"`
	ERPReferenceCompleted    bool       `json:"erp_reference_completed" db:"erp_reference_completed"`
	ERPReferenceNumber       *string    `json:"erp_reference_number,omitempty" db:"erp_reference_number"`
	
	CompletionNotes          *string    `json:"completion_notes" db:"completion_notes"`
	VerifiedBy               *string    `json:"verified_by,omitempty" db:"verified_by"`
	VerifiedAt               *time.Time `json:"verified_at,omitempty" db:"verified_at"`
	VerificationNotes        *string    `json:"verification_notes,omitempty" db:"verification_notes"`
	CompletedAt              time.Time  `json:"completed_at" db:"completed_at"`
	CreatedAt                time.Time  `json:"created_at" db:"created_at"`
}

// CreateTaskRequest represents a request to create a new task
type CreateTaskRequest struct {
	Title                string     `json:"title" validate:"required"`
	Description          *string    `json:"description"`
	RequireTaskFinished  bool       `json:"require_task_finished"`
	RequirePhotoUpload   bool       `json:"require_photo_upload"`
	RequireERPReference  bool       `json:"require_erp_reference"`
	CanEscalate          bool       `json:"can_escalate"`
	CanReassign          bool       `json:"can_reassign"`
	Priority             string     `json:"priority" validate:"oneof=low medium high"`
	DueDate              *string    `json:"due_date,omitempty"`   // Format: YYYY-MM-DD
	DueTime              *string    `json:"due_time,omitempty"`   // Format: HH:MM:SS (24-hour)
}

// UpdateTaskRequest represents a request to update a task
type UpdateTaskRequest struct {
	Title                *string    `json:"title"`
	Description          *string    `json:"description"`
	RequireTaskFinished  *bool      `json:"require_task_finished"`
	RequirePhotoUpload   *bool      `json:"require_photo_upload"`
	RequireERPReference  *bool      `json:"require_erp_reference"`
	CanEscalate          *bool      `json:"can_escalate"`
	CanReassign          *bool      `json:"can_reassign"`
	Status               *string    `json:"status" validate:"omitempty,oneof=draft active paused completed cancelled"`
	Priority             *string    `json:"priority" validate:"omitempty,oneof=low medium high"`
	DueDate              *string    `json:"due_date"`
	DueTime              *string    `json:"due_time"`
}

// AssignTaskRequest represents a request to assign a task
type AssignTaskRequest struct {
	TaskIDs            []string `json:"task_ids" validate:"required"`
	AssignmentType     string   `json:"assignment_type" validate:"required,oneof=user branch all"`
	AssignedToUserID   *string  `json:"assigned_to_user_id"`
	AssignedToBranchID *string  `json:"assigned_to_branch_id"`
}

// CompleteTaskRequest represents a request to complete a task
type CompleteTaskRequest struct {
	CompletionMethod      string  `json:"completion_method" validate:"required"`
	CompletionNotes       *string `json:"completion_notes"`
	ERPReferenceNumber    *string `json:"erp_reference_number"`
}

// TaskStatistics represents task statistics
type TaskStatistics struct {
	TotalTasks       int64 `json:"total_tasks"`
	ActiveTasks      int64 `json:"active_tasks"`
	CompletedTasks   int64 `json:"completed_tasks"`
	MyAssignedTasks  int64 `json:"my_assigned_tasks"`
	MyCompletedTasks int64 `json:"my_completed_tasks"`
}

// TaskSearchResult represents a search result with ranking
type TaskSearchResult struct {
	Task
	Rank float32 `json:"rank" db:"rank"`
}

// ToJSON converts Task to a JSON-friendly map
func (t *Task) ToJSON() map[string]interface{} {
	return map[string]interface{}{
		"id":                     t.ID,
		"title":                  t.Title,
		"description":            t.Description,
		"require_task_finished":  t.RequireTaskFinished,
		"require_photo_upload":   t.RequirePhotoUpload,
		"require_erp_reference":  t.RequireERPReference,
		"can_escalate":           t.CanEscalate,
		"can_reassign":           t.CanReassign,
		"created_by":             t.CreatedBy,
		"created_by_name":        t.CreatedByName,
		"created_by_role":        t.CreatedByRole,
		"status":                 t.Status,
		"priority":               t.Priority,
		"created_at":             t.CreatedAt,
		"updated_at":             t.UpdatedAt,
		"deleted_at":             t.DeletedAt,
		"due_date":               t.DueDate,
		"due_time":               t.DueTime,
		"images":                 t.Images,
		"assignments":            t.Assignments,
	}
}