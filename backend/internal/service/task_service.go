package service

import (
	"fmt"
	"log"

	"aqura-backend/internal/domain"
	"aqura-backend/internal/repository"
)

type TaskService struct {
	taskRepo *repository.TaskRepository
}

func NewTaskService(taskRepo *repository.TaskRepository) *TaskService {
	return &TaskService{
		taskRepo: taskRepo,
	}
}

// =====================================================
// TASK CRUD OPERATIONS
// =====================================================

// CreateTask creates a new task
func (s *TaskService) CreateTask(req domain.CreateTaskRequest, createdBy, createdByName, createdByRole string) (*domain.Task, error) {
	log.Printf("Creating task: %s by user: %s", req.Title, createdBy)

	// Validate request
	if req.Title == "" {
		return nil, fmt.Errorf("task title is required")
	}

	// Check that at least one completion criteria is specified
	if !req.RequireTaskFinished && !req.RequirePhotoUpload && !req.RequireERPReference {
		return nil, fmt.Errorf("at least one completion criteria must be specified")
	}

	// Set default priority if not provided
	if req.Priority == "" {
		req.Priority = "medium"
	}

	// Validate priority
	validPriorities := map[string]bool{
		"low":    true,
		"medium": true,
		"high":   true,
	}
	if !validPriorities[req.Priority] {
		return nil, fmt.Errorf("invalid priority: %s (must be low, medium, or high)", req.Priority)
	}

	task, err := s.taskRepo.CreateTask(req, createdBy, createdByName, createdByRole)
	if err != nil {
		log.Printf("Failed to create task: %v", err)
		return nil, err
	}

	log.Printf("Successfully created task with ID: %s", task.ID)
	return task, nil
}

// GetAllTasks retrieves all tasks with optional filtering
func (s *TaskService) GetAllTasks(limit, offset int, status, createdBy string) ([]domain.Task, int, error) {
	log.Printf("Retrieving tasks with limit: %d, offset: %d, status: %s, createdBy: %s", 
		limit, offset, status, createdBy)

	// Set default limit if not provided
	if limit <= 0 {
		limit = 50
	}

	// Ensure offset is not negative
	if offset < 0 {
		offset = 0
	}

	// Validate status if provided
	if status != "" {
		validStatuses := map[string]bool{
			"draft":     true,
			"active":    true,
			"paused":    true,
			"completed": true,
			"cancelled": true,
		}
		if !validStatuses[status] {
			return nil, 0, fmt.Errorf("invalid status: %s", status)
		}
	}

	tasks, total, err := s.taskRepo.GetAllTasks(limit, offset, status, createdBy)
	if err != nil {
		log.Printf("Failed to get tasks: %v", err)
		return nil, 0, err
	}

	log.Printf("Successfully retrieved %d tasks (total: %d)", len(tasks), total)
	return tasks, total, nil
}

// GetTaskByID retrieves a task by ID
func (s *TaskService) GetTaskByID(id string) (*domain.Task, error) {
	log.Printf("Retrieving task by ID: %s", id)

	if id == "" {
		return nil, fmt.Errorf("task ID is required")
	}

	task, err := s.taskRepo.GetTaskByID(id)
	if err != nil {
		log.Printf("Failed to get task by ID %s: %v", id, err)
		return nil, err
	}

	log.Printf("Successfully retrieved task: %s", task.Title)
	return task, nil
}

// UpdateTask updates an existing task
func (s *TaskService) UpdateTask(id string, req domain.UpdateTaskRequest, updatedBy string) error {
	log.Printf("Updating task ID: %s by user: %s", id, updatedBy)

	if id == "" {
		return fmt.Errorf("task ID is required")
	}

	// Validate status if provided
	if req.Status != nil {
		validStatuses := map[string]bool{
			"draft":     true,
			"active":    true,
			"paused":    true,
			"completed": true,
			"cancelled": true,
		}
		if !validStatuses[*req.Status] {
			return fmt.Errorf("invalid status: %s", *req.Status)
		}
	}

	// Validate priority if provided
	if req.Priority != nil {
		validPriorities := map[string]bool{
			"low":    true,
			"medium": true,
			"high":   true,
			"urgent": true,
		}
		if !validPriorities[*req.Priority] {
			return fmt.Errorf("invalid priority: %s", *req.Priority)
		}
	}

	err := s.taskRepo.UpdateTask(id, req)
	if err != nil {
		log.Printf("Failed to update task %s: %v", id, err)
		return err
	}

	log.Printf("Successfully updated task with ID: %s", id)
	return nil
}

// DeleteTask soft deletes a task
func (s *TaskService) DeleteTask(id string, deletedBy string) error {
	log.Printf("Deleting task ID: %s by user: %s", id, deletedBy)

	if id == "" {
		return fmt.Errorf("task ID is required")
	}

	err := s.taskRepo.DeleteTask(id)
	if err != nil {
		log.Printf("Failed to delete task %s: %v", id, err)
		return err
	}

	log.Printf("Successfully deleted task with ID: %s", id)
	return nil
}

// SearchTasks performs full-text search on tasks
func (s *TaskService) SearchTasks(query string, userID string, limit, offset int) ([]domain.TaskSearchResult, int, error) {
	log.Printf("Searching tasks with query: '%s' for user: %s", query, userID)

	// Set default limit if not provided
	if limit <= 0 {
		limit = 50
	}

	// Ensure offset is not negative
	if offset < 0 {
		offset = 0
	}

	results, total, err := s.taskRepo.SearchTasks(query, userID, limit, offset)
	if err != nil {
		log.Printf("Failed to search tasks: %v", err)
		return nil, 0, err
	}

	log.Printf("Search found %d results (total: %d)", len(results), total)
	return results, total, nil
}

// =====================================================
// TASK ASSIGNMENT OPERATIONS
// =====================================================

// AssignTasks assigns multiple tasks to users, branches, or all
func (s *TaskService) AssignTasks(req domain.AssignTaskRequest, assignedBy, assignedByName string) error {
	log.Printf("Assigning %d tasks (type: %s) by user: %s", 
		len(req.TaskIDs), req.AssignmentType, assignedBy)

	// Validate request
	if len(req.TaskIDs) == 0 {
		return fmt.Errorf("at least one task ID is required")
	}

	if req.AssignmentType == "" {
		return fmt.Errorf("assignment type is required")
	}

	// Validate assignment type
	validTypes := map[string]bool{
		"user":   true,
		"branch": true,
		"all":    true,
	}
	if !validTypes[req.AssignmentType] {
		return fmt.Errorf("invalid assignment type: %s", req.AssignmentType)
	}

	// Validate assignment target based on type
	switch req.AssignmentType {
	case "user":
		if req.AssignedToUserID == nil || *req.AssignedToUserID == "" {
			return fmt.Errorf("assigned_to_user_id is required for user assignment")
		}
	case "branch":
		if req.AssignedToBranchID == nil || *req.AssignedToBranchID == "" {
			return fmt.Errorf("assigned_to_branch_id is required for branch assignment")
		}
	case "all":
		// No specific target required
		req.AssignedToUserID = nil
		req.AssignedToBranchID = nil
	}

	err := s.taskRepo.CreateTaskAssignments(req, assignedBy, assignedByName)
	if err != nil {
		log.Printf("Failed to assign tasks: %v", err)
		return err
	}

	log.Printf("Successfully assigned %d tasks", len(req.TaskIDs))
	return nil
}

// GetTaskAssignments retrieves all assignments for a task
func (s *TaskService) GetTaskAssignments(taskID string) ([]domain.TaskAssignment, error) {
	log.Printf("Retrieving assignments for task: %s", taskID)

	if taskID == "" {
		return nil, fmt.Errorf("task ID is required")
	}

	assignments, err := s.taskRepo.GetTaskAssignments(taskID)
	if err != nil {
		log.Printf("Failed to get task assignments: %v", err)
		return nil, err
	}

	log.Printf("Successfully retrieved %d assignments for task %s", len(assignments), taskID)
	return assignments, nil
}

// =====================================================
// TASK STATISTICS
// =====================================================

// GetTaskStatistics retrieves task statistics for a user
func (s *TaskService) GetTaskStatistics(userID string) (*domain.TaskStatistics, error) {
	log.Printf("Retrieving task statistics for user: %s", userID)

	stats, err := s.taskRepo.GetTaskStatistics(userID)
	if err != nil {
		log.Printf("Failed to get task statistics: %v", err)
		return nil, err
	}

	log.Printf("Successfully retrieved task statistics for user %s", userID)
	return stats, nil
}

// =====================================================
// TASK IMAGE OPERATIONS
// =====================================================

// AddTaskImage adds an image to a task
func (s *TaskService) AddTaskImage(taskID string, image domain.TaskImage) (*domain.TaskImage, error) {
	log.Printf("Adding image to task: %s (type: %s)", taskID, image.ImageType)

	if taskID == "" {
		return nil, fmt.Errorf("task ID is required")
	}

	if image.FileName == "" {
		return nil, fmt.Errorf("file name is required")
	}

	if image.FileURL == "" {
		return nil, fmt.Errorf("file URL is required")
	}

	if image.ImageType == "" {
		return nil, fmt.Errorf("image type is required")
	}

	// Validate image type
	validImageTypes := map[string]bool{
		"task_creation":   true,
		"task_completion": true,
	}
	if !validImageTypes[image.ImageType] {
		return nil, fmt.Errorf("invalid image type: %s", image.ImageType)
	}

	createdImage, err := s.taskRepo.CreateTaskImage(taskID, image)
	if err != nil {
		log.Printf("Failed to add task image: %v", err)
		return nil, err
	}

	log.Printf("Successfully added image to task %s", taskID)
	return createdImage, nil
}

// GetTaskImages retrieves all images for a task
func (s *TaskService) GetTaskImages(taskID string) ([]domain.TaskImage, error) {
	log.Printf("Retrieving images for task: %s", taskID)

	if taskID == "" {
		return nil, fmt.Errorf("task ID is required")
	}

	images, err := s.taskRepo.GetTaskImages(taskID)
	if err != nil {
		log.Printf("Failed to get task images: %v", err)
		return nil, err
	}

	log.Printf("Successfully retrieved %d images for task %s", len(images), taskID)
	return images, nil
}

// =====================================================
// BUSINESS LOGIC METHODS
// =====================================================

// ActivateTask activates a draft task, making it available for assignment
func (s *TaskService) ActivateTask(taskID string, activatedBy string) error {
	log.Printf("Activating task: %s by user: %s", taskID, activatedBy)

	// Check if task exists and is in draft status
	task, err := s.taskRepo.GetTaskByID(taskID)
	if err != nil {
		return err
	}

	if task.Status != "draft" {
		return fmt.Errorf("task is not in draft status, current status: %s", task.Status)
	}

	// Update status to active
	updateReq := domain.UpdateTaskRequest{
		Status: stringPtr("active"),
	}

	err = s.taskRepo.UpdateTask(taskID, updateReq)
	if err != nil {
		log.Printf("Failed to activate task %s: %v", taskID, err)
		return err
	}

	log.Printf("Successfully activated task: %s", taskID)
	return nil
}

// PauseTask pauses an active task
func (s *TaskService) PauseTask(taskID string, pausedBy string) error {
	log.Printf("Pausing task: %s by user: %s", taskID, pausedBy)

	// Check if task exists and is active
	task, err := s.taskRepo.GetTaskByID(taskID)
	if err != nil {
		return err
	}

	if task.Status != "active" {
		return fmt.Errorf("task is not active, current status: %s", task.Status)
	}

	// Update status to paused
	updateReq := domain.UpdateTaskRequest{
		Status: stringPtr("paused"),
	}

	err = s.taskRepo.UpdateTask(taskID, updateReq)
	if err != nil {
		log.Printf("Failed to pause task %s: %v", taskID, err)
		return err
	}

	log.Printf("Successfully paused task: %s", taskID)
	return nil
}

// ResumeTask resumes a paused task
func (s *TaskService) ResumeTask(taskID string, resumedBy string) error {
	log.Printf("Resuming task: %s by user: %s", taskID, resumedBy)

	// Check if task exists and is paused
	task, err := s.taskRepo.GetTaskByID(taskID)
	if err != nil {
		return err
	}

	if task.Status != "paused" {
		return fmt.Errorf("task is not paused, current status: %s", task.Status)
	}

	// Update status to active
	updateReq := domain.UpdateTaskRequest{
		Status: stringPtr("active"),
	}

	err = s.taskRepo.UpdateTask(taskID, updateReq)
	if err != nil {
		log.Printf("Failed to resume task %s: %v", taskID, err)
		return err
	}

	log.Printf("Successfully resumed task: %s", taskID)
	return nil
}

// CompleteTask marks a task as completed
func (s *TaskService) CompleteTask(taskID string, completedBy string) error {
	log.Printf("Completing task: %s by user: %s", taskID, completedBy)

	// Check if task exists and is active
	task, err := s.taskRepo.GetTaskByID(taskID)
	if err != nil {
		return err
	}

	if task.Status != "active" {
		return fmt.Errorf("task is not active, current status: %s", task.Status)
	}

	// Update status to completed
	updateReq := domain.UpdateTaskRequest{
		Status: stringPtr("completed"),
	}

	err = s.taskRepo.UpdateTask(taskID, updateReq)
	if err != nil {
		log.Printf("Failed to complete task %s: %v", taskID, err)
		return err
	}

	log.Printf("Successfully completed task: %s", taskID)
	return nil
}

// =====================================================
// HELPER FUNCTIONS
// =====================================================

// stringPtr returns a pointer to the provided string
func stringPtr(s string) *string {
	return &s
}