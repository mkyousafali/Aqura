package repository

import (
	"database/sql"
	"fmt"
	"log"
	"time"
)

// SimpleNotification matches our Supabase schema exactly
type SimpleNotification struct {
	ID              string    `json:"id"`
	Title           string    `json:"title"`
	Message         string    `json:"message"`
	Type            string    `json:"type"`
	Priority        string    `json:"priority"`
	Status          string    `json:"status"`
	CreatedBy       string    `json:"created_by"`
	CreatedByName   string    `json:"created_by_name"`
	CreatedByRole   string    `json:"created_by_role"`
	TargetType      string    `json:"target_type"`
	HasAttachments  bool      `json:"has_attachments"`
	ReadCount       int       `json:"read_count"`
	TotalRecipients int       `json:"total_recipients"`
	CreatedAt       time.Time `json:"created_at"`
	UpdatedAt       time.Time `json:"updated_at"`
}

type SimpleNotificationRepository struct {
	db *sql.DB
}

func NewSimpleNotificationRepository(db *sql.DB) *SimpleNotificationRepository {
	return &SimpleNotificationRepository{db: db}
}

// GetAllNotifications retrieves all notifications directly from Supabase
func (r *SimpleNotificationRepository) GetAllNotifications(limit, offset int) ([]SimpleNotification, int, error) {
	if r.db == nil {
		log.Println("Database connection is nil, cannot query notifications")
		return nil, 0, fmt.Errorf("database connection not available")
	}

	// Test database connection
	if err := r.db.Ping(); err != nil {
		log.Printf("Database ping failed: %v", err)
		return nil, 0, fmt.Errorf("database connection failed: %v", err)
	}

	log.Println("Database connection successful, querying notifications...")

	// Count total notifications
	var total int
	countQuery := `SELECT COUNT(*) FROM notifications WHERE deleted_at IS NULL`
	
	err := r.db.QueryRow(countQuery).Scan(&total)
	if err != nil {
		log.Printf("Failed to count notifications: %v", err)
		return nil, 0, fmt.Errorf("failed to count notifications: %v", err)
	}

	log.Printf("Found %d total notifications", total)

	// Get notifications
	query := `
		SELECT 
			id, title, message, type, priority, status,
			created_by, created_by_name, created_by_role,
			target_type, has_attachments, read_count, total_recipients,
			created_at, updated_at
		FROM notifications 
		WHERE deleted_at IS NULL
		ORDER BY created_at DESC
		LIMIT $1 OFFSET $2
	`

	rows, err := r.db.Query(query, limit, offset)
	if err != nil {
		log.Printf("Failed to query notifications: %v", err)
		return nil, 0, fmt.Errorf("failed to query notifications: %v", err)
	}
	defer rows.Close()

	var notifications []SimpleNotification
	for rows.Next() {
		var n SimpleNotification
		err := rows.Scan(
			&n.ID, &n.Title, &n.Message, &n.Type, &n.Priority, &n.Status,
			&n.CreatedBy, &n.CreatedByName, &n.CreatedByRole,
			&n.TargetType, &n.HasAttachments, &n.ReadCount, &n.TotalRecipients,
			&n.CreatedAt, &n.UpdatedAt,
		)
		if err != nil {
			log.Printf("Failed to scan notification: %v", err)
			return nil, 0, fmt.Errorf("failed to scan notification: %v", err)
		}
		notifications = append(notifications, n)
	}

	if err := rows.Err(); err != nil {
		log.Printf("Row iteration error: %v", err)
		return nil, 0, fmt.Errorf("row iteration error: %v", err)
	}

	log.Printf("Successfully retrieved %d notifications", len(notifications))
	return notifications, total, nil
}

// CreateNotification creates a new notification
func (r *SimpleNotificationRepository) CreateNotification(title, message, notifType, priority string) (*SimpleNotification, error) {
	if r.db == nil {
		return nil, fmt.Errorf("database connection not available")
	}

	query := `
		INSERT INTO notifications (title, message, type, priority, status, target_type, total_recipients)
		VALUES ($1, $2, $3, $4, 'published', 'all_users', 1)
		RETURNING id, title, message, type, priority, status, created_by, created_by_name, 
		          created_by_role, target_type, has_attachments, read_count, total_recipients,
		          created_at, updated_at
	`

	var n SimpleNotification
	err := r.db.QueryRow(query, title, message, notifType, priority).Scan(
		&n.ID, &n.Title, &n.Message, &n.Type, &n.Priority, &n.Status,
		&n.CreatedBy, &n.CreatedByName, &n.CreatedByRole,
		&n.TargetType, &n.HasAttachments, &n.ReadCount, &n.TotalRecipients,
		&n.CreatedAt, &n.UpdatedAt,
	)

	if err != nil {
		log.Printf("Failed to create notification: %v", err)
		return nil, fmt.Errorf("failed to create notification: %v", err)
	}

	log.Printf("Successfully created notification: %s", n.Title)
	return &n, nil
}

// DeleteNotification deletes a notification from Supabase
func (r *SimpleNotificationRepository) DeleteNotification(id string) error {
	if r.db == nil {
		return fmt.Errorf("database connection not available")
	}

	log.Printf("Deleting notification ID %s from database...", id)

	// Soft delete by setting deleted_at timestamp
	query := `UPDATE notifications SET deleted_at = $1 WHERE id = $2 AND deleted_at IS NULL`
	
	result, err := r.db.Exec(query, time.Now(), id)
	if err != nil {
		log.Printf("Failed to delete notification: %v", err)
		return fmt.Errorf("failed to delete notification: %v", err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %v", err)
	}

	if rowsAffected == 0 {
		log.Printf("Notification not found: %s", id)
		return fmt.Errorf("notification not found")
	}

	log.Printf("Successfully deleted notification ID %s", id)
	return nil
}

// UpdateNotification updates a notification in Supabase
func (r *SimpleNotificationRepository) UpdateNotification(id, title, message, notifType, priority string) (*SimpleNotification, error) {
	if r.db == nil {
		return nil, fmt.Errorf("database connection not available")
	}

	log.Printf("Updating notification ID %s in database...", id)

	// Update query
	query := `
		UPDATE notifications 
		SET title = $1, message = $2, type = $3, priority = $4, updated_at = $5
		WHERE id = $6 AND deleted_at IS NULL
		RETURNING id, title, message, type, priority, status, created_by, created_by_name, 
		          created_by_role, target_type, has_attachments, read_count, total_recipients,
		          created_at, updated_at
	`

	var n SimpleNotification
	err := r.db.QueryRow(query, title, message, notifType, priority, time.Now(), id).Scan(
		&n.ID, &n.Title, &n.Message, &n.Type, &n.Priority, &n.Status,
		&n.CreatedBy, &n.CreatedByName, &n.CreatedByRole,
		&n.TargetType, &n.HasAttachments, &n.ReadCount, &n.TotalRecipients,
		&n.CreatedAt, &n.UpdatedAt,
	)

	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("notification not found")
		}
		log.Printf("Failed to update notification: %v", err)
		return nil, fmt.Errorf("failed to update notification: %v", err)
	}

	log.Printf("Successfully updated notification ID %s", id)
	return &n, nil
}

// GetNotificationByID retrieves a single notification by ID
func (r *SimpleNotificationRepository) GetNotificationByID(id string) (*SimpleNotification, error) {
	if r.db == nil {
		return nil, fmt.Errorf("database connection not available")
	}

	query := `
		SELECT 
			id, title, message, type, priority, status,
			created_by, created_by_name, created_by_role,
			target_type, has_attachments, read_count, total_recipients,
			created_at, updated_at
		FROM notifications 
		WHERE id = $1 AND deleted_at IS NULL
	`

	var n SimpleNotification
	err := r.db.QueryRow(query, id).Scan(
		&n.ID, &n.Title, &n.Message, &n.Type, &n.Priority, &n.Status,
		&n.CreatedBy, &n.CreatedByName, &n.CreatedByRole,
		&n.TargetType, &n.HasAttachments, &n.ReadCount, &n.TotalRecipients,
		&n.CreatedAt, &n.UpdatedAt,
	)

	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("notification not found")
		}
		log.Printf("Failed to get notification: %v", err)
		return nil, fmt.Errorf("failed to get notification: %v", err)
	}

	return &n, nil
}

// MarkAsRead marks a notification as read by incrementing read_count
func (r *SimpleNotificationRepository) MarkAsRead(id string) error {
	if r.db == nil {
		return fmt.Errorf("database connection not available")
	}

	log.Printf("Marking notification ID %s as read in database...", id)

	// Increment read_count and update updated_at
	query := `
		UPDATE notifications 
		SET read_count = read_count + 1, updated_at = $1
		WHERE id = $2 AND deleted_at IS NULL
	`
	
	result, err := r.db.Exec(query, time.Now(), id)
	if err != nil {
		log.Printf("Failed to mark notification as read: %v", err)
		return fmt.Errorf("failed to mark notification as read: %v", err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %v", err)
	}

	if rowsAffected == 0 {
		log.Printf("Notification not found: %s", id)
		return fmt.Errorf("notification not found")
	}

	log.Printf("Successfully marked notification ID %s as read", id)
	return nil
}

// MarkAllAsRead marks all notifications as read by incrementing read_count for all active notifications
func (r *SimpleNotificationRepository) MarkAllAsRead() error {
	if r.db == nil {
		return fmt.Errorf("database connection not available")
	}

	log.Println("Marking all notifications as read in database...")

	// Increment read_count and update updated_at for all active notifications
	query := `
		UPDATE notifications 
		SET read_count = read_count + 1, updated_at = $1
		WHERE deleted_at IS NULL
	`
	
	result, err := r.db.Exec(query, time.Now())
	if err != nil {
		log.Printf("Failed to mark all notifications as read: %v", err)
		return fmt.Errorf("failed to mark all notifications as read: %v", err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %v", err)
	}

	log.Printf("Successfully marked %d notifications as read", rowsAffected)
	return nil
}

// ToJSON converts SimpleNotification to JSON for API response
func (n *SimpleNotification) ToJSON() map[string]interface{} {
	return map[string]interface{}{
		"id":               n.ID,
		"title":            n.Title,
		"message":          n.Message,
		"type":             n.Type,
		"priority":         n.Priority,
		"status":           n.Status,
		"created_by":       n.CreatedBy,
		"created_by_name":  n.CreatedByName,
		"created_by_role":  n.CreatedByRole,
		"target_type":      n.TargetType,
		"has_attachments":  n.HasAttachments,
		"read_count":       n.ReadCount,
		"total_recipients": n.TotalRecipients,
		"created_at":       n.CreatedAt,
		"updated_at":       n.UpdatedAt,
	}
}

// GetAllNotificationsWithUserReadStates retrieves all notifications with per-user read states
func (r *SimpleNotificationRepository) GetAllNotificationsWithUserReadStates(limit, offset int, userID string) ([]map[string]interface{}, int, error) {
	if r.db == nil {
		log.Println("Database connection is nil, cannot query notifications")
		return nil, 0, fmt.Errorf("database connection not available")
	}

	// Test database connection
	if err := r.db.Ping(); err != nil {
		log.Printf("Database ping failed: %v", err)
		return nil, 0, fmt.Errorf("database connection failed: %v", err)
	}

	log.Printf("Database connection successful, querying notifications with read states for user: %s", userID)

	// Modified query to include per-user read state and exclude deleted notifications
	query := `
		SELECT 
			n.id,
			n.title,
			n.message,
			n.type,
			n.priority,
			n.status,
			n.created_by,
			n.created_by_name,
			n.created_by_role,
			n.target_type,
			n.has_attachments,
			n.read_count,
			n.total_recipients,
			n.created_at,
			n.updated_at,
			CASE WHEN nrs.user_id IS NOT NULL THEN true ELSE false END as is_read_by_user,
			nrs.read_at
		FROM notifications n
		LEFT JOIN notification_read_states nrs ON n.id = nrs.notification_id AND nrs.user_id = $1
		WHERE n.deleted_at IS NULL
		ORDER BY n.created_at DESC 
		LIMIT $2 OFFSET $3
	`

	rows, err := r.db.Query(query, userID, limit, offset)
	if err != nil {
		log.Printf("Query execution failed: %v", err)
		return nil, 0, fmt.Errorf("failed to execute query: %v", err)
	}
	defer rows.Close()

	var notifications []map[string]interface{}
	for rows.Next() {
		var notification map[string]interface{} = make(map[string]interface{})
		var id, title, message, nType, priority, status, createdBy, createdByName, createdByRole, targetType string
		var hasAttachments, isReadByUser bool
		var readCount, totalRecipients int
		var createdAt, updatedAt time.Time
		var readAt *time.Time

		err := rows.Scan(
			&id, &title, &message, &nType, &priority, &status,
			&createdBy, &createdByName, &createdByRole, &targetType, 
			&hasAttachments, &readCount, &totalRecipients,
			&createdAt, &updatedAt,
			&isReadByUser, &readAt,
		)
		if err != nil {
			log.Printf("Row scanning failed: %v", err)
			return nil, 0, fmt.Errorf("failed to scan row: %v", err)
		}

		notification["id"] = id
		notification["title"] = title
		notification["message"] = message
		notification["type"] = nType
		notification["priority"] = priority
		notification["status"] = status
		notification["created_by"] = createdBy
		notification["created_by_name"] = createdByName
		notification["created_by_role"] = createdByRole
		notification["target_type"] = targetType
		notification["has_attachments"] = hasAttachments
		notification["read_count"] = readCount
		notification["total_recipients"] = totalRecipients
		notification["created_at"] = createdAt
		notification["updated_at"] = updatedAt
		notification["is_read_by_user"] = isReadByUser
		notification["read_at"] = readAt

		notifications = append(notifications, notification)
	}

	if err = rows.Err(); err != nil {
		log.Printf("Row iteration error: %v", err)
		return nil, 0, fmt.Errorf("error iterating rows: %v", err)
	}

	// Get total count (same query without LIMIT/OFFSET) excluding deleted notifications
	countQuery := `
		SELECT COUNT(*) 
		FROM notifications n
		WHERE n.deleted_at IS NULL
	`
	
	var total int
	err = r.db.QueryRow(countQuery).Scan(&total)
	if err != nil {
		log.Printf("Count query failed: %v", err)
		return nil, 0, fmt.Errorf("failed to get total count: %v", err)
	}

	log.Printf("Successfully retrieved %d notifications with user read states (Total: %d)", len(notifications), total)
	return notifications, total, nil
}