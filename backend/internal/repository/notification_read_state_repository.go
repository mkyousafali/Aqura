package repository

import (
	"database/sql"
	"fmt"
	"log"
	"time"
)

// NotificationReadState represents a user's read state for a notification
type NotificationReadState struct {
	ID             string    `json:"id"`
	NotificationID string    `json:"notification_id"`
	UserID         string    `json:"user_id"`
	ReadAt         time.Time `json:"read_at"`
	CreatedAt      time.Time `json:"created_at"`
}

type NotificationReadStateRepository struct {
	db *sql.DB
}

func NewNotificationReadStateRepository(db *sql.DB) *NotificationReadStateRepository {
	return &NotificationReadStateRepository{db: db}
}

// MarkAsRead marks a notification as read for a specific user
func (r *NotificationReadStateRepository) MarkAsRead(notificationID, userID string) error {
	if r.db == nil {
		return fmt.Errorf("database connection not available")
	}

	log.Printf("Marking notification %s as read for user %s...", notificationID, userID)

	// Use INSERT ... ON CONFLICT to handle the case where user already read this notification
	query := `
		INSERT INTO notification_read_states (notification_id, user_id, read_at, created_at)
		VALUES ($1, $2, $3, $4)
		ON CONFLICT (notification_id, user_id) 
		DO UPDATE SET read_at = $3
	`
	
	now := time.Now()
	_, err := r.db.Exec(query, notificationID, userID, now, now)
	if err != nil {
		log.Printf("Failed to mark notification as read: %v", err)
		return fmt.Errorf("failed to mark notification as read: %v", err)
	}

	log.Printf("Successfully marked notification %s as read for user %s", notificationID, userID)
	return nil
}

// MarkAllAsRead marks all active notifications as read for a specific user
func (r *NotificationReadStateRepository) MarkAllAsRead(userID string) error {
	if r.db == nil {
		return fmt.Errorf("database connection not available")
	}

	log.Printf("Marking all notifications as read for user %s...", userID)

	// Insert read states for all active notifications that the user hasn't read yet
	query := `
		INSERT INTO notification_read_states (notification_id, user_id, read_at, created_at)
		SELECT n.id, $1, $2, $2
		FROM notifications n
		WHERE n.deleted_at IS NULL
		AND NOT EXISTS (
			SELECT 1 FROM notification_read_states nrs
			WHERE nrs.notification_id = n.id AND nrs.user_id = $1
		)
		ON CONFLICT (notification_id, user_id) DO NOTHING
	`
	
	now := time.Now()
	result, err := r.db.Exec(query, userID, now)
	if err != nil {
		log.Printf("Failed to mark all notifications as read: %v", err)
		return fmt.Errorf("failed to mark all notifications as read: %v", err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %v", err)
	}

	log.Printf("Successfully marked %d notifications as read for user %s", rowsAffected, userID)
	return nil
}

// IsReadByUser checks if a notification has been read by a specific user
func (r *NotificationReadStateRepository) IsReadByUser(notificationID, userID string) (bool, error) {
	if r.db == nil {
		return false, fmt.Errorf("database connection not available")
	}

	query := `
		SELECT COUNT(*) FROM notification_read_states
		WHERE notification_id = $1 AND user_id = $2
	`
	
	var count int
	err := r.db.QueryRow(query, notificationID, userID).Scan(&count)
	if err != nil {
		log.Printf("Failed to check read state: %v", err)
		return false, fmt.Errorf("failed to check read state: %v", err)
	}

	return count > 0, nil
}

// GetReadStatesByUser gets all read states for a specific user
func (r *NotificationReadStateRepository) GetReadStatesByUser(userID string) (map[string]bool, error) {
	if r.db == nil {
		return nil, fmt.Errorf("database connection not available")
	}

	query := `
		SELECT notification_id FROM notification_read_states
		WHERE user_id = $1
	`
	
	rows, err := r.db.Query(query, userID)
	if err != nil {
		log.Printf("Failed to get read states: %v", err)
		return nil, fmt.Errorf("failed to get read states: %v", err)
	}
	defer rows.Close()

	readStates := make(map[string]bool)
	for rows.Next() {
		var notificationID string
		if err := rows.Scan(&notificationID); err != nil {
			log.Printf("Failed to scan read state: %v", err)
			continue
		}
		readStates[notificationID] = true
	}

	return readStates, nil
}

// GetReadCount gets the total number of users who have read a notification
func (r *NotificationReadStateRepository) GetReadCount(notificationID string) (int, error) {
	if r.db == nil {
		return 0, fmt.Errorf("database connection not available")
	}

	query := `
		SELECT COUNT(*) FROM notification_read_states
		WHERE notification_id = $1
	`
	
	var count int
	err := r.db.QueryRow(query, notificationID).Scan(&count)
	if err != nil {
		log.Printf("Failed to get read count: %v", err)
		return 0, fmt.Errorf("failed to get read count: %v", err)
	}

	return count, nil
}

// GetAllReadStates gets all read states for admin dashboard (Master Admin only)
func (r *NotificationReadStateRepository) GetAllReadStates() ([]NotificationReadState, error) {
	if r.db == nil {
		return nil, fmt.Errorf("database connection not available")
	}

	query := `
		SELECT id, notification_id, user_id, read_at, created_at
		FROM notification_read_states
		ORDER BY read_at DESC
	`
	
	rows, err := r.db.Query(query)
	if err != nil {
		log.Printf("Failed to get all read states: %v", err)
		return nil, fmt.Errorf("failed to get all read states: %v", err)
	}
	defer rows.Close()

	var readStates []NotificationReadState
	for rows.Next() {
		var rs NotificationReadState
		if err := rows.Scan(&rs.ID, &rs.NotificationID, &rs.UserID, &rs.ReadAt, &rs.CreatedAt); err != nil {
			log.Printf("Failed to scan read state: %v", err)
			continue
		}
		readStates = append(readStates, rs)
	}

	if err := rows.Err(); err != nil {
		log.Printf("Error iterating read states: %v", err)
		return nil, fmt.Errorf("error iterating read states: %v", err)
	}

	log.Printf("Successfully fetched %d read states for admin", len(readStates))
	return readStates, nil
}