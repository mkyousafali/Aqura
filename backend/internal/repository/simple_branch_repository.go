package repository

import (
	"database/sql"
	"fmt"
	"log"
	"time"
)

// SimpleBranch matches our Supabase branches schema
type SimpleBranch struct {
	ID         int       `json:"id"`
	NameEn     string    `json:"name_en"`
	NameAr     string    `json:"name_ar"`
	LocationEn string    `json:"location_en"`
	LocationAr string    `json:"location_ar"`
	IsActive   bool      `json:"is_active"`
	CreatedAt  time.Time `json:"created_at"`
	UpdatedAt  time.Time `json:"updated_at"`
}

type SimpleBranchRepository struct {
	db *sql.DB
}

func NewSimpleBranchRepository(db *sql.DB) *SimpleBranchRepository {
	return &SimpleBranchRepository{db: db}
}

// GetAllBranches retrieves all branches directly from Supabase
func (r *SimpleBranchRepository) GetAllBranches() ([]SimpleBranch, error) {
	if r.db == nil {
		log.Println("Database connection is nil, cannot query branches")
		return nil, fmt.Errorf("database connection not available")
	}

	// Test database connection
	if err := r.db.Ping(); err != nil {
		log.Printf("Database ping failed: %v", err)
		return nil, fmt.Errorf("database connection failed: %v", err)
	}

	log.Println("Database connection successful, querying branches...")

	// Get branches
	query := `
		SELECT 
			id, name_en, name_ar, location_en, location_ar,
			created_at, updated_at
		FROM branches 
		ORDER BY created_at DESC
	`

	rows, err := r.db.Query(query)
	if err != nil {
		log.Printf("Failed to query branches: %v", err)
		return nil, fmt.Errorf("failed to query branches: %v", err)
	}
	defer rows.Close()

	var branches []SimpleBranch
	for rows.Next() {
		var b SimpleBranch
		err := rows.Scan(
			&b.ID, &b.NameEn, &b.NameAr, &b.LocationEn, &b.LocationAr,
			&b.CreatedAt, &b.UpdatedAt,
		)
		if err != nil {
			log.Printf("Failed to scan branch: %v", err)
			return nil, fmt.Errorf("failed to scan branch: %v", err)
		}
		// Set default active status
		b.IsActive = true
		branches = append(branches, b)
	}

	if err := rows.Err(); err != nil {
		log.Printf("Row iteration error: %v", err)
		return nil, fmt.Errorf("row iteration error: %v", err)
	}

	log.Printf("Successfully retrieved %d branches from Supabase", len(branches))
	return branches, nil
}

// UpdateBranch updates a branch in Supabase
func (r *SimpleBranchRepository) UpdateBranch(id string, nameEn, nameAr, locationEn, locationAr string, isActive bool) (*SimpleBranch, error) {
	if r.db == nil {
		return nil, fmt.Errorf("database connection not available")
	}

	log.Printf("Updating branch ID %s in database...", id)

	// Update query
	query := `
		UPDATE branches 
		SET name_en = $1, name_ar = $2, location_en = $3, location_ar = $4, updated_at = $5
		WHERE id = $6
		RETURNING id, name_en, name_ar, location_en, location_ar, created_at, updated_at
	`

	var b SimpleBranch
	err := r.db.QueryRow(query, nameEn, nameAr, locationEn, locationAr, time.Now(), id).Scan(
		&b.ID, &b.NameEn, &b.NameAr, &b.LocationEn, &b.LocationAr, &b.CreatedAt, &b.UpdatedAt,
	)

	if err != nil {
		log.Printf("Failed to update branch: %v", err)
		return nil, fmt.Errorf("failed to update branch: %v", err)
	}

	b.IsActive = isActive
	log.Printf("Successfully updated branch ID %s", id)
	return &b, nil
}

// CreateBranch creates a new branch in Supabase
func (r *SimpleBranchRepository) CreateBranch(nameEn, nameAr, locationEn, locationAr string, isActive bool) (*SimpleBranch, error) {
	if r.db == nil {
		return nil, fmt.Errorf("database connection not available")
	}

	log.Printf("Creating new branch in database...")

	// Insert query
	query := `
		INSERT INTO branches (name_en, name_ar, location_en, location_ar, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6)
		RETURNING id, name_en, name_ar, location_en, location_ar, created_at, updated_at
	`

	var b SimpleBranch
	now := time.Now()
	err := r.db.QueryRow(query, nameEn, nameAr, locationEn, locationAr, now, now).Scan(
		&b.ID, &b.NameEn, &b.NameAr, &b.LocationEn, &b.LocationAr, &b.CreatedAt, &b.UpdatedAt,
	)

	if err != nil {
		log.Printf("Failed to create branch: %v", err)
		return nil, fmt.Errorf("failed to create branch: %v", err)
	}

	b.IsActive = isActive
	log.Printf("Successfully created branch with ID %d", b.ID)
	return &b, nil
}

// DeleteBranch deletes a branch from Supabase
func (r *SimpleBranchRepository) DeleteBranch(id string) error {
	if r.db == nil {
		return fmt.Errorf("database connection not available")
	}

	log.Printf("Deleting branch ID %s from database...", id)

	// Delete query
	query := `DELETE FROM branches WHERE id = $1`
	
	result, err := r.db.Exec(query, id)
	if err != nil {
		log.Printf("Failed to delete branch: %v", err)
		return fmt.Errorf("failed to delete branch: %v", err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %v", err)
	}

	if rowsAffected == 0 {
		return fmt.Errorf("branch not found")
	}

	log.Printf("Successfully deleted branch ID %s", id)
	return nil
}

// GetBranchByID retrieves a single branch by ID
func (r *SimpleBranchRepository) GetBranchByID(id string) (*SimpleBranch, error) {
	if r.db == nil {
		return nil, fmt.Errorf("database connection not available")
	}

	query := `
		SELECT 
			id, name_en, name_ar, location_en, location_ar,
			created_at, updated_at
		FROM branches 
		WHERE id = $1
	`

	var b SimpleBranch
	err := r.db.QueryRow(query, id).Scan(
		&b.ID, &b.NameEn, &b.NameAr, &b.LocationEn, &b.LocationAr,
		&b.CreatedAt, &b.UpdatedAt,
	)

	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("branch not found")
		}
		log.Printf("Failed to get branch: %v", err)
		return nil, fmt.Errorf("failed to get branch: %v", err)
	}

	b.IsActive = true
	return &b, nil
}

// ToJSON converts SimpleBranch to JSON for API response
func (b *SimpleBranch) ToJSON() map[string]interface{} {
	return map[string]interface{}{
		"id":           fmt.Sprintf("%d", b.ID),
		"name_en":      b.NameEn,
		"name_ar":      b.NameAr,
		"location_en":  b.LocationEn,
		"location_ar":  b.LocationAr,
		"is_active":    b.IsActive,
		"is_main_branch": b.ID == 1, // Assume first branch is main
		"created_at":   b.CreatedAt,
		"updated_at":   b.UpdatedAt,
	}
}