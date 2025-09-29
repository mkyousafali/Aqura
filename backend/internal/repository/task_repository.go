package repository

import (
	"database/sql"
	"fmt"
	"log"
	"strings"
	"time"

	"aqura-backend/internal/domain"
)

type TaskRepository struct {
	db *sql.DB
}

func NewTaskRepository(db *sql.DB) *TaskRepository {
	return &TaskRepository{db: db}
}

// =====================================================
// TASK CRUD OPERATIONS
// =====================================================

// CreateTask creates a new task
func (r *TaskRepository) CreateTask(req domain.CreateTaskRequest, createdBy, createdByName, createdByRole string) (*domain.Task, error) {
	if r.db == nil {
		return nil, fmt.Errorf("database connection not available")
	}

	query := `
		INSERT INTO tasks (
			title, description, require_task_finished, require_photo_upload, require_erp_reference,
			can_escalate, can_reassign, created_by, created_by_name, created_by_role, 
			priority, due_date, due_time, status
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, 'draft')
		RETURNING id, created_at, updated_at
	`

	var task domain.Task
	var createdAt, updatedAt time.Time

	err := r.db.QueryRow(query,
		req.Title, req.Description, req.RequireTaskFinished, req.RequirePhotoUpload, req.RequireERPReference,
		req.CanEscalate, req.CanReassign,
		createdBy, createdByName, createdByRole,
		req.Priority, req.DueDate, req.DueTime,
	).Scan(&task.ID, &createdAt, &updatedAt)

	if err != nil {
		log.Printf("Error creating task: %v", err)
		return nil, fmt.Errorf("failed to create task: %v", err)
	}

	// Build the full task object
	task.Title = req.Title
	task.Description = req.Description
	task.RequireTaskFinished = req.RequireTaskFinished
	task.RequirePhotoUpload = req.RequirePhotoUpload
	task.RequireERPReference = req.RequireERPReference
	task.CanEscalate = req.CanEscalate
	task.CanReassign = req.CanReassign
	task.CreatedBy = createdBy
	task.CreatedByName = &createdByName
	task.CreatedByRole = &createdByRole
	task.Priority = req.Priority
	
	// Parse date and time strings to time.Time
	if req.DueDate != nil {
		if dateTime, err := time.Parse("2006-01-02", *req.DueDate); err == nil {
			task.DueDate = &dateTime
		}
	}
	if req.DueTime != nil {
		if timeTime, err := time.Parse("15:04", *req.DueTime); err == nil {
			task.DueTime = &timeTime
		}
	}
	
	task.Status = "draft"
	task.CreatedAt = createdAt
	task.UpdatedAt = updatedAt

	log.Printf("Successfully created task with ID: %s", task.ID)
	return &task, nil
}

// GetAllTasks retrieves all tasks with optional filtering
func (r *TaskRepository) GetAllTasks(limit, offset int, status, createdBy string) ([]domain.Task, int, error) {
	if r.db == nil {
		return nil, 0, fmt.Errorf("database connection not available")
	}

	// Build WHERE conditions
	var conditions []string
	var args []interface{}
	argIndex := 1

	conditions = append(conditions, "deleted_at IS NULL")

	if status != "" {
		conditions = append(conditions, fmt.Sprintf("status = $%d", argIndex))
		args = append(args, status)
		argIndex++
	}

	if createdBy != "" {
		conditions = append(conditions, fmt.Sprintf("created_by = $%d", argIndex))
		args = append(args, createdBy)
		argIndex++
	}

	whereClause := "WHERE " + strings.Join(conditions, " AND ")

	// Count total
	countQuery := fmt.Sprintf("SELECT COUNT(*) FROM tasks %s", whereClause)
	var total int
	err := r.db.QueryRow(countQuery, args...).Scan(&total)
	if err != nil {
		return nil, 0, fmt.Errorf("failed to count tasks: %v", err)
	}

	// Get tasks
	query := fmt.Sprintf(`
		SELECT 
			id, title, description, require_task_finished, require_photo_upload, require_erp_reference,
			can_escalate, can_reassign, created_by, created_by_name, created_by_role, 
			status, priority, created_at, updated_at, deleted_at, due_date, due_time
		FROM tasks 
		%s
		ORDER BY created_at DESC
		LIMIT $%d OFFSET $%d
	`, whereClause, argIndex, argIndex+1)

	args = append(args, limit, offset)

	rows, err := r.db.Query(query, args...)
	if err != nil {
		return nil, 0, fmt.Errorf("failed to query tasks: %v", err)
	}
	defer rows.Close()

	var tasks []domain.Task
	for rows.Next() {
		var task domain.Task
		err := rows.Scan(
			&task.ID, &task.Title, &task.Description, &task.RequireTaskFinished, &task.RequirePhotoUpload, &task.RequireERPReference,
			&task.CanEscalate, &task.CanReassign, &task.CreatedBy, &task.CreatedByName,
			&task.CreatedByRole, &task.Status, &task.Priority, &task.CreatedAt,
			&task.UpdatedAt, &task.DeletedAt, &task.DueDate, &task.DueTime,
		)
		if err != nil {
			return nil, 0, fmt.Errorf("failed to scan task: %v", err)
		}
		tasks = append(tasks, task)
	}

	log.Printf("Successfully retrieved %d tasks (total: %d)", len(tasks), total)
	return tasks, total, nil
}

// GetTaskByID retrieves a task by ID with relationships
func (r *TaskRepository) GetTaskByID(id string) (*domain.Task, error) {
	if r.db == nil {
		return nil, fmt.Errorf("database connection not available")
	}

	query := `
		SELECT 
			id, title, description, require_task_finished, require_photo_upload, require_erp_reference,
			can_escalate, can_reassign, created_by, created_by_name, created_by_role, 
			status, priority, created_at, updated_at, deleted_at, due_date, due_time
		FROM tasks 
		WHERE id = $1 AND deleted_at IS NULL
	`

	var task domain.Task
	err := r.db.QueryRow(query, id).Scan(
		&task.ID, &task.Title, &task.Description, &task.RequireTaskFinished, &task.RequirePhotoUpload, &task.RequireERPReference,
		&task.CanEscalate, &task.CanReassign, &task.CreatedBy, &task.CreatedByName,
		&task.CreatedByRole, &task.Status, &task.Priority, &task.CreatedAt,
		&task.UpdatedAt, &task.DeletedAt, &task.DueDate, &task.DueTime,
	)

	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("task not found")
		}
		return nil, fmt.Errorf("failed to get task: %v", err)
	}

	// Load images
	images, err := r.GetTaskImages(id)
	if err != nil {
		log.Printf("Warning: failed to load task images: %v", err)
	} else {
		task.Images = images
	}

	// Load assignments
	assignments, err := r.GetTaskAssignments(id)
	if err != nil {
		log.Printf("Warning: failed to load task assignments: %v", err)
	} else {
		task.Assignments = assignments
	}

	return &task, nil
}

// UpdateTask updates an existing task
func (r *TaskRepository) UpdateTask(id string, req domain.UpdateTaskRequest) error {
	if r.db == nil {
		return fmt.Errorf("database connection not available")
	}

	// Build dynamic update query
	var setParts []string
	var args []interface{}
	argIndex := 1

	if req.Title != nil {
		setParts = append(setParts, fmt.Sprintf("title = $%d", argIndex))
		args = append(args, *req.Title)
		argIndex++
	}

	if req.Description != nil {
		setParts = append(setParts, fmt.Sprintf("description = $%d", argIndex))
		args = append(args, *req.Description)
		argIndex++
	}

	if req.RequireTaskFinished != nil {
		setParts = append(setParts, fmt.Sprintf("require_task_finished = $%d", argIndex))
		args = append(args, *req.RequireTaskFinished)
		argIndex++
	}

	if req.RequirePhotoUpload != nil {
		setParts = append(setParts, fmt.Sprintf("require_photo_upload = $%d", argIndex))
		args = append(args, *req.RequirePhotoUpload)
		argIndex++
	}

	if req.RequireERPReference != nil {
		setParts = append(setParts, fmt.Sprintf("require_erp_reference = $%d", argIndex))
		args = append(args, *req.RequireERPReference)
		argIndex++
	}

	if req.CanEscalate != nil {
		setParts = append(setParts, fmt.Sprintf("can_escalate = $%d", argIndex))
		args = append(args, *req.CanEscalate)
		argIndex++
	}

	if req.CanReassign != nil {
		setParts = append(setParts, fmt.Sprintf("can_reassign = $%d", argIndex))
		args = append(args, *req.CanReassign)
		argIndex++
	}

	if req.Status != nil {
		setParts = append(setParts, fmt.Sprintf("status = $%d", argIndex))
		args = append(args, *req.Status)
		argIndex++
	}

	if req.Priority != nil {
		setParts = append(setParts, fmt.Sprintf("priority = $%d", argIndex))
		args = append(args, *req.Priority)
		argIndex++
	}

	if req.DueDate != nil {
		setParts = append(setParts, fmt.Sprintf("due_date = $%d", argIndex))
		args = append(args, *req.DueDate)
		argIndex++
	}

	if req.DueTime != nil {
		setParts = append(setParts, fmt.Sprintf("due_time = $%d", argIndex))
		args = append(args, *req.DueTime)
		argIndex++
	}

	if len(setParts) == 0 {
		return fmt.Errorf("no fields to update")
	}

	// Always update the updated_at timestamp
	setParts = append(setParts, "updated_at = NOW()")

	// Add ID parameter
	args = append(args, id)

	query := fmt.Sprintf(`
		UPDATE tasks 
		SET %s
		WHERE id = $%d AND deleted_at IS NULL
	`, strings.Join(setParts, ", "), argIndex)

	result, err := r.db.Exec(query, args...)
	if err != nil {
		return fmt.Errorf("failed to update task: %v", err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %v", err)
	}

	if rowsAffected == 0 {
		return fmt.Errorf("task not found or already deleted")
	}

	log.Printf("Successfully updated task with ID: %s", id)
	return nil
}

// DeleteTask soft deletes a task
func (r *TaskRepository) DeleteTask(id string) error {
	if r.db == nil {
		return fmt.Errorf("database connection not available")
	}

	query := `
		UPDATE tasks 
		SET deleted_at = NOW(), updated_at = NOW()
		WHERE id = $1 AND deleted_at IS NULL
	`

	result, err := r.db.Exec(query, id)
	if err != nil {
		return fmt.Errorf("failed to delete task: %v", err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %v", err)
	}

	if rowsAffected == 0 {
		return fmt.Errorf("task not found or already deleted")
	}

	log.Printf("Successfully deleted task with ID: %s", id)
	return nil
}

// SearchTasks performs full-text search on tasks
func (r *TaskRepository) SearchTasks(query string, userID string, limit, offset int) ([]domain.TaskSearchResult, int, error) {
	if r.db == nil {
		return nil, 0, fmt.Errorf("database connection not available")
	}

	// Get search results using the helper function
	searchQuery := `
		SELECT id, title, description, require_task_finished, require_photo_upload, require_erp_reference,
			   can_escalate, can_reassign, created_by, created_by_name, status, priority, 
			   created_at, updated_at, due_date, due_time, rank
		FROM search_tasks($1, $2, $3, $4)
	`

	rows, err := r.db.Query(searchQuery, query, userID, limit, offset)
	if err != nil {
		return nil, 0, fmt.Errorf("failed to search tasks: %v", err)
	}
	defer rows.Close()

	var results []domain.TaskSearchResult
	for rows.Next() {
		var result domain.TaskSearchResult
		err := rows.Scan(
			&result.ID, &result.Title, &result.Description, &result.RequireTaskFinished, &result.RequirePhotoUpload, &result.RequireERPReference,
			&result.CanEscalate, &result.CanReassign, &result.CreatedBy, &result.CreatedByName,
			&result.Status, &result.Priority, &result.CreatedAt, &result.UpdatedAt,
			&result.DueDate, &result.DueTime, &result.Rank,
		)
		if err != nil {
			return nil, 0, fmt.Errorf("failed to scan search result: %v", err)
		}
		results = append(results, result)
	}

	// For count, we need to execute a simpler count query
	countQuery := `
		SELECT COUNT(*) FROM tasks t
		WHERE t.deleted_at IS NULL
		AND (
			$1 IS NULL OR $1 = '' 
			OR t.search_vector @@ plainto_tsquery('english', $1)
			OR t.title ILIKE '%' || $1 || '%'
			OR t.description ILIKE '%' || $1 || '%'
		)
	`
	
	var total int
	err = r.db.QueryRow(countQuery, query).Scan(&total)
	if err != nil {
		return nil, 0, fmt.Errorf("failed to count search results: %v", err)
	}

	log.Printf("Search found %d results (total: %d) for query: %s", len(results), total, query)
	return results, total, nil
}

// =====================================================
// TASK IMAGE OPERATIONS
// =====================================================

// CreateTaskImage creates a new task image
func (r *TaskRepository) CreateTaskImage(taskID string, image domain.TaskImage) (*domain.TaskImage, error) {
	if r.db == nil {
		return nil, fmt.Errorf("database connection not available")
	}

	query := `
		INSERT INTO task_images (
			task_id, file_name, file_size, file_type, file_url, image_type,
			uploaded_by, uploaded_by_name, image_width, image_height
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
		RETURNING id, created_at
	`

	var createdAt time.Time
	err := r.db.QueryRow(query,
		taskID, image.FileName, image.FileSize, image.FileType, image.FileURL,
		image.ImageType, image.UploadedBy, image.UploadedByName,
		image.ImageWidth, image.ImageHeight,
	).Scan(&image.ID, &createdAt)

	if err != nil {
		return nil, fmt.Errorf("failed to create task image: %v", err)
	}

	image.TaskID = taskID
	image.CreatedAt = createdAt

	return &image, nil
}

// GetTaskImages retrieves all images for a task
func (r *TaskRepository) GetTaskImages(taskID string) ([]domain.TaskImage, error) {
	if r.db == nil {
		return nil, fmt.Errorf("database connection not available")
	}

	query := `
		SELECT id, task_id, file_name, file_size, file_type, file_url, image_type,
			   uploaded_by, uploaded_by_name, created_at, image_width, image_height
		FROM task_images 
		WHERE task_id = $1
		ORDER BY created_at ASC
	`

	rows, err := r.db.Query(query, taskID)
	if err != nil {
		return nil, fmt.Errorf("failed to query task images: %v", err)
	}
	defer rows.Close()

	var images []domain.TaskImage
	for rows.Next() {
		var image domain.TaskImage
		err := rows.Scan(
			&image.ID, &image.TaskID, &image.FileName, &image.FileSize,
			&image.FileType, &image.FileURL, &image.ImageType, &image.UploadedBy,
			&image.UploadedByName, &image.CreatedAt, &image.ImageWidth, &image.ImageHeight,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan task image: %v", err)
		}
		images = append(images, image)
	}

	return images, nil
}

// =====================================================
// TASK ASSIGNMENT OPERATIONS  
// =====================================================

// CreateTaskAssignments creates multiple task assignments
func (r *TaskRepository) CreateTaskAssignments(req domain.AssignTaskRequest, assignedBy, assignedByName string) error {
	if r.db == nil {
		return fmt.Errorf("database connection not available")
	}

	tx, err := r.db.Begin()
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %v", err)
	}
	defer tx.Rollback()

	query := `
		INSERT INTO task_assignments (
			task_id, assignment_type, assigned_to_user_id, assigned_to_branch_id,
			assigned_by, assigned_by_name
		) VALUES ($1, $2, $3, $4, $5, $6)
		ON CONFLICT (task_id, assignment_type, assigned_to_user_id, assigned_to_branch_id) 
		DO NOTHING
	`

	for _, taskID := range req.TaskIDs {
		_, err := tx.Exec(query,
			taskID, req.AssignmentType, req.AssignedToUserID, req.AssignedToBranchID,
			assignedBy, assignedByName,
		)
		if err != nil {
			return fmt.Errorf("failed to create task assignment for task %s: %v", taskID, err)
		}
	}

	err = tx.Commit()
	if err != nil {
		return fmt.Errorf("failed to commit transaction: %v", err)
	}

	log.Printf("Successfully created %d task assignments", len(req.TaskIDs))
	return nil
}

// GetTaskAssignments retrieves all assignments for a task
func (r *TaskRepository) GetTaskAssignments(taskID string) ([]domain.TaskAssignment, error) {
	if r.db == nil {
		return nil, fmt.Errorf("database connection not available")
	}

	query := `
		SELECT 
			ta.id, ta.task_id, ta.assignment_type, ta.assigned_to_user_id, ta.assigned_to_branch_id,
			ta.assigned_by, ta.assigned_by_name, ta.assigned_at, ta.status,
			ta.started_at, ta.completed_at,
			COALESCE(u.username, he.name, ta.assigned_to_user_id) as assigned_to_user_name,
			b.name_en as assigned_to_branch_name
		FROM task_assignments ta
		LEFT JOIN users u ON ta.assigned_to_user_id = u.id
		LEFT JOIN hr_employees he ON ta.assigned_to_user_id = he.id
		LEFT JOIN branches b ON ta.assigned_to_branch_id = b.id
		WHERE ta.task_id = $1
		ORDER BY ta.assigned_at DESC
	`

	rows, err := r.db.Query(query, taskID)
	if err != nil {
		return nil, fmt.Errorf("failed to query task assignments: %v", err)
	}
	defer rows.Close()

	var assignments []domain.TaskAssignment
	for rows.Next() {
		var assignment domain.TaskAssignment
		err := rows.Scan(
			&assignment.ID, &assignment.TaskID, &assignment.AssignmentType,
			&assignment.AssignedToUserID, &assignment.AssignedToBranchID,
			&assignment.AssignedBy, &assignment.AssignedByName, &assignment.AssignedAt,
			&assignment.Status, &assignment.StartedAt, &assignment.CompletedAt,
			&assignment.AssignedToUserName, &assignment.AssignedToBranchName,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan task assignment: %v", err)
		}
		assignments = append(assignments, assignment)
	}

	return assignments, nil
}

// =====================================================
// TASK STATISTICS
// =====================================================

// GetTaskStatistics retrieves task statistics using the database function
func (r *TaskRepository) GetTaskStatistics(userID string) (*domain.TaskStatistics, error) {
	if r.db == nil {
		return nil, fmt.Errorf("database connection not available")
	}

	query := `SELECT * FROM get_task_statistics($1)`

	var stats domain.TaskStatistics
	err := r.db.QueryRow(query, userID).Scan(
		&stats.TotalTasks, &stats.ActiveTasks, &stats.CompletedTasks,
		&stats.MyAssignedTasks, &stats.MyCompletedTasks,
	)

	if err != nil {
		return nil, fmt.Errorf("failed to get task statistics: %v", err)
	}

	return &stats, nil
}