package desktopinterface

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"
	"time"

	"github.com/mkyousafali/Aqura/backend/cache"
	"github.com/mkyousafali/Aqura/backend/database"
	desktopmodels "github.com/mkyousafali/Aqura/backend/models/desktop-interface"
)

// GetBranches retrieves all branches with caching
func GetBranches(w http.ResponseWriter, r *http.Request) {
	// Try to get from cache first
	cacheKey := "branches:all"
	if cachedData, found := cache.Get(cacheKey); found {
		// Set cache headers
		w.Header().Set("X-Cache", "HIT")
		respondWithJSON(w, http.StatusOK, cachedData)
		return
	}

	db := database.GetDB()

	query := `
		SELECT id, name_en, name_ar, location_en, location_ar, is_active, 
		       is_main_branch, created_at, updated_at, vat_number,
		       delivery_service_enabled, pickup_service_enabled, 
		       minimum_order_amount, is_24_hours
		FROM branches
		WHERE is_active = true
		ORDER BY id ASC
	`

	rows, err := db.Query(query)
	if err != nil {
		respondWithError(w, http.StatusInternalServerError, fmt.Sprintf("Database error: %v", err))
		return
	}
	defer rows.Close()

	branches := []desktopmodels.Branch{}
	for rows.Next() {
		var branch desktopmodels.Branch
		err := rows.Scan(
			&branch.ID,
			&branch.NameEn,
			&branch.NameAr,
			&branch.LocationEn,
			&branch.LocationAr,
			&branch.IsActive,
			&branch.IsMainBranch,
			&branch.CreatedAt,
			&branch.UpdatedAt,
			&branch.VatNumber,
			&branch.DeliveryServiceEnabled,
			&branch.PickupServiceEnabled,
			&branch.MinimumOrderAmount,
			&branch.Is24Hours,
		)
		if err != nil {
			respondWithError(w, http.StatusInternalServerError, fmt.Sprintf("Scan error: %v", err))
			return
		}
		branches = append(branches, branch)
	}

	// Cache for 5 minutes
	cache.Set(cacheKey, branches, 5*time.Minute)
	w.Header().Set("X-Cache", "MISS")
	
	respondWithJSON(w, http.StatusOK, branches)
}

// GetBranch retrieves a single branch by ID
func GetBranch(w http.ResponseWriter, r *http.Request) {
	// Extract ID from URL path
	idStr := r.URL.Path[len("/api/branches/"):]
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		respondWithError(w, http.StatusBadRequest, "Invalid branch ID")
		return
	}

	db := database.GetDB()

	query := `
		SELECT id, name_en, name_ar, location_en, location_ar, is_active, 
		       is_main_branch, created_at, updated_at, vat_number,
		       delivery_service_enabled, pickup_service_enabled, 
		       minimum_order_amount, is_24_hours
		FROM branches
		WHERE id = $1
	`

	var branch desktopmodels.Branch
	err = db.QueryRow(query, id).Scan(
		&branch.ID,
		&branch.NameEn,
		&branch.NameAr,
		&branch.LocationEn,
		&branch.LocationAr,
		&branch.IsActive,
		&branch.IsMainBranch,
		&branch.CreatedAt,
		&branch.UpdatedAt,
		&branch.VatNumber,
		&branch.DeliveryServiceEnabled,
		&branch.PickupServiceEnabled,
		&branch.MinimumOrderAmount,
		&branch.Is24Hours,
	)

	if err == sql.ErrNoRows {
		respondWithError(w, http.StatusNotFound, "Branch not found")
		return
	}
	if err != nil {
		respondWithError(w, http.StatusInternalServerError, fmt.Sprintf("Database error: %v", err))
		return
	}

	respondWithJSON(w, http.StatusOK, branch)
}

// CreateBranch creates a new branch
func CreateBranch(w http.ResponseWriter, r *http.Request) {
	var input desktopmodels.CreateBranchInput
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		respondWithError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	// Validate required fields
	if input.NameEn == "" || input.NameAr == "" || input.LocationEn == "" || input.LocationAr == "" {
		respondWithError(w, http.StatusBadRequest, "Missing required fields")
		return
	}

	db := database.GetDB()

	query := `
		INSERT INTO branches (
			name_en, name_ar, location_en, location_ar, is_active, is_main_branch,
			vat_number, delivery_service_enabled, pickup_service_enabled,
			minimum_order_amount, is_24_hours
		)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
		RETURNING id, created_at
	`

	var branch desktopmodels.Branch
	branch.NameEn = input.NameEn
	branch.NameAr = input.NameAr
	branch.LocationEn = input.LocationEn
	branch.LocationAr = input.LocationAr

	// Set defaults
	isActive := true
	if input.IsActive != nil {
		isActive = *input.IsActive
	}
	isMainBranch := false
	if input.IsMainBranch != nil {
		isMainBranch = *input.IsMainBranch
	}
	is24Hours := true
	if input.Is24Hours != nil {
		is24Hours = *input.Is24Hours
	}

	err := db.QueryRow(
		query,
		input.NameEn,
		input.NameAr,
		input.LocationEn,
		input.LocationAr,
		isActive,
		isMainBranch,
		input.VatNumber,
		input.DeliveryServiceEnabled,
		input.PickupServiceEnabled,
		input.MinimumOrderAmount,
		is24Hours,
	).Scan(&branch.ID, &branch.CreatedAt)

	if err != nil {
		respondWithError(w, http.StatusInternalServerError, fmt.Sprintf("Failed to create branch: %v", err))
		return
	}

	// Invalidate cache
	cache.Invalidate("branches:all")

	respondWithJSON(w, http.StatusCreated, branch)
}

// UpdateBranch updates an existing branch
func UpdateBranch(w http.ResponseWriter, r *http.Request) {
	// Extract ID from URL path
	idStr := r.URL.Path[len("/api/branches/"):]
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		respondWithError(w, http.StatusBadRequest, "Invalid branch ID")
		return
	}

	var input desktopmodels.UpdateBranchInput
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		respondWithError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	db := database.GetDB()

	// Build dynamic update query
	query := "UPDATE branches SET updated_at = NOW()"
	args := []interface{}{}
	argPos := 1

	if input.NameEn != nil {
		query += fmt.Sprintf(", name_en = $%d", argPos)
		args = append(args, *input.NameEn)
		argPos++
	}
	if input.NameAr != nil {
		query += fmt.Sprintf(", name_ar = $%d", argPos)
		args = append(args, *input.NameAr)
		argPos++
	}
	if input.LocationEn != nil {
		query += fmt.Sprintf(", location_en = $%d", argPos)
		args = append(args, *input.LocationEn)
		argPos++
	}
	if input.LocationAr != nil {
		query += fmt.Sprintf(", location_ar = $%d", argPos)
		args = append(args, *input.LocationAr)
		argPos++
	}
	if input.IsActive != nil {
		query += fmt.Sprintf(", is_active = $%d", argPos)
		args = append(args, *input.IsActive)
		argPos++
	}

	query += fmt.Sprintf(" WHERE id = $%d", argPos)
	args = append(args, id)

	result, err := db.Exec(query, args...)
	if err != nil {
		respondWithError(w, http.StatusInternalServerError, fmt.Sprintf("Failed to update branch: %v", err))
		return
	}

	rowsAffected, _ := result.RowsAffected()
	if rowsAffected == 0 {
		respondWithError(w, http.StatusNotFound, "Branch not found")
		return
	}

	// Invalidate cache
	cache.Invalidate("branches:all")

	respondWithJSON(w, http.StatusOK, map[string]string{"message": "Branch updated successfully"})
}

// DeleteBranch deletes a branch (soft delete by setting is_active = false)
func DeleteBranch(w http.ResponseWriter, r *http.Request) {
	// Extract ID from URL path
	idStr := r.URL.Path[len("/api/branches/"):]
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		respondWithError(w, http.StatusBadRequest, "Invalid branch ID")
		return
	}

	db := database.GetDB()

	query := "UPDATE branches SET is_active = false, updated_at = NOW() WHERE id = $1"
	result, err := db.Exec(query, id)
	if err != nil {
		respondWithError(w, http.StatusInternalServerError, fmt.Sprintf("Failed to delete branch: %v", err))
		return
	}

	rowsAffected, _ := result.RowsAffected()
	if rowsAffected == 0 {
		respondWithError(w, http.StatusNotFound, "Branch not found")
		return
	}

	// Invalidate cache
	cache.Invalidate("branches:all")

	respondWithJSON(w, http.StatusOK, map[string]string{"message": "Branch deleted successfully"})
}

// Helper functions
func respondWithJSON(w http.ResponseWriter, code int, payload interface{}) {
	response, _ := json.Marshal(payload)
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	w.Write(response)
}

func respondWithError(w http.ResponseWriter, code int, message string) {
	respondWithJSON(w, code, map[string]string{"error": message})
}
