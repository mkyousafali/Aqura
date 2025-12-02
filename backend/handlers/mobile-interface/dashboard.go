package mobileinterface

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/mkyousafali/Aqura/backend/cache"
	"github.com/mkyousafali/Aqura/backend/database"
	mobilemodels "github.com/mkyousafali/Aqura/backend/models/mobile-interface"
)

// GetDashboard retrieves mobile dashboard data with caching
func GetDashboard(w http.ResponseWriter, r *http.Request) {
	// Get user_id from query parameter
	userID := r.URL.Query().Get("user_id")
	if userID == "" {
		respondWithError(w, http.StatusBadRequest, "user_id is required")
		return
	}

	// Try cache first
	cacheKey := fmt.Sprintf("mobile_dashboard:%s", userID)
	if cachedData, found := cache.Get(cacheKey); found {
		w.Header().Set("X-Cache", "HIT")
		respondWithJSON(w, http.StatusOK, cachedData)
		return
	}

	db := database.GetDB()

	// Get pending tasks count
	var pendingTasks int
	taskQuery := `
		SELECT 
			(SELECT COUNT(*) FROM task_assignments 
			 WHERE assigned_to_user_id = $1 AND status NOT IN ('completed', 'cancelled')) +
			(SELECT COUNT(*) FROM quick_task_assignments 
			 WHERE assigned_to_user_id = $1 AND status NOT IN ('completed', 'cancelled')) +
			(SELECT COUNT(*) FROM receiving_tasks 
			 WHERE assigned_user_id = $1 AND task_status NOT IN ('completed', 'cancelled'))
		AS total_pending
	`

	err := db.QueryRow(taskQuery, userID).Scan(&pendingTasks)
	if err != nil {
		respondWithError(w, http.StatusInternalServerError, fmt.Sprintf("Database error: %v", err))
		return
	}

	// Get recent punch records (last 2 punches from last 48 hours)
	punchRecords := []mobilemodels.PunchRecord{}
	
	// First, get employee_id and branch_id from hr_employees using user's employee_id UUID
	var employeeID string
	var branchID *int64
	
	empQuery := `
		SELECT employee_id, branch_id 
		FROM hr_employees 
		WHERE id = (SELECT employee_id FROM users WHERE id = $1)
	`
	
	err = db.QueryRow(empQuery, userID).Scan(&employeeID, &branchID)
	if err != nil {
		// Log the error but don't fail the request
		fmt.Printf("⚠️  Could not get employee info for user %s: %v\n", userID, err)
	} else {
		branchIDVal := int64(0)
		if branchID != nil {
			branchIDVal = *branchID
		}
		fmt.Printf("✅ Found employee: ID=%s, BranchID=%d\n", employeeID, branchIDVal)
	}
	
	if err == nil && employeeID != "" && branchID != nil {
		// Get punches from last 48 hours
		twoDaysAgo := time.Now().Add(-48 * time.Hour).Format("2006-01-02")
		
		fmt.Printf("🔍 Querying punches: employee_id=%s, branch_id=%d, date>=%s\n", employeeID, *branchID, twoDaysAgo)
		
		// First, check if ANY records exist for this employee
		var totalCount int
		countQuery := `SELECT COUNT(*) FROM hr_fingerprint_transactions WHERE employee_id = $1`
		db.QueryRow(countQuery, employeeID).Scan(&totalCount)
		fmt.Printf("📊 Total punch records for employee %s: %d\n", employeeID, totalCount)
		
		if totalCount > 0 {
			// Check with branch filter
			var branchCount int
			db.QueryRow(`SELECT COUNT(*) FROM hr_fingerprint_transactions WHERE employee_id = $1 AND branch_id = $2`, employeeID, branchID).Scan(&branchCount)
			fmt.Printf("📊 Records for employee %s at branch %d: %d\n", employeeID, *branchID, branchCount)
			
			// Check date range
			var dateCount int
			db.QueryRow(`SELECT COUNT(*) FROM hr_fingerprint_transactions WHERE employee_id = $1 AND date >= $2`, employeeID, twoDaysAgo).Scan(&dateCount)
			fmt.Printf("📊 Records for employee %s since %s: %d\n", employeeID, twoDaysAgo, dateCount)
		}
		
		punchQuery := `
			SELECT date, time, status
			FROM hr_fingerprint_transactions
			WHERE employee_id = $1 AND branch_id = $2 AND date >= $3
			ORDER BY date DESC, time DESC
			LIMIT 2
		`
		
		rows, err := db.Query(punchQuery, employeeID, branchID, twoDaysAgo)
		if err == nil {
			defer rows.Close()
			
			recordCount := 0
			for rows.Next() {
				var date, timeStr, status string
				if err := rows.Scan(&date, &timeStr, &status); err == nil {
					recordCount++
					fmt.Printf("📝 Raw record %d: date=%s, time=%s, status=%s\n", recordCount, date, timeStr, status)
					
					// Parse time from RFC3339 format (0000-01-01T08:39:43Z)
					t, err := time.Parse(time.RFC3339, timeStr)
					if err != nil {
						fmt.Printf("⚠️  Failed to parse time '%s': %v\n", timeStr, err)
						continue
					}
					formattedTime := t.Format("03:04 PM")
					
					// Parse date from RFC3339 format (2025-12-02T00:00:00Z)
					d, err := time.Parse(time.RFC3339, date)
					if err != nil {
						fmt.Printf("⚠️  Failed to parse date '%s': %v\n", date, err)
						continue
					}
					formattedDate := d.Format("Mon, Jan 2")
					
					// Determine status - handle "Check In", "Check Out" format
					punchStatus := "check-out"
					statusLower := strings.ToLower(status)
					if strings.Contains(statusLower, "in") {
						punchStatus = "check-in"
					}
					
					punchRecords = append(punchRecords, mobilemodels.PunchRecord{
						Time:    formattedTime,
						Date:    formattedDate,
						Status:  punchStatus,
						RawDate: date,
						RawTime: timeStr,
					})
				}
			}
			fmt.Printf("✅ Found %d punch records\n", recordCount)
		} else {
			fmt.Printf("⚠️  Punch query error: %v\n", err)
		}
	}

	// Build response
	response := mobilemodels.DashboardResponse{
		Stats: mobilemodels.DashboardStats{
			PendingTasks: pendingTasks,
		},
		Punches: mobilemodels.PunchesResponse{
			Records: punchRecords,
			Loading: false,
			Error:   "",
		},
	}

	// Cache for 2 minutes (shorter TTL for dashboard data)
	cache.Set(cacheKey, response, 2*time.Minute)
	w.Header().Set("X-Cache", "MISS")

	respondWithJSON(w, http.StatusOK, response)
}

// Helper functions
func respondWithJSON(w http.ResponseWriter, code int, payload interface{}) {
	response, err := json.Marshal(payload)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		w.Write([]byte("Error encoding response"))
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	w.Write(response)
}

func respondWithError(w http.ResponseWriter, code int, message string) {
	respondWithJSON(w, code, map[string]string{"error": message})
}
