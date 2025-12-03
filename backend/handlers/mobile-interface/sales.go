package mobileinterface

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"time"

	"github.com/mkyousafali/Aqura/backend/cache"
	"github.com/mkyousafali/Aqura/backend/database"
	mobilemodels "github.com/mkyousafali/Aqura/backend/models/mobile-interface"
)

// ========================================
// GET ALL SALES - With Caching and Filtering
// ========================================
func GetDailySales(w http.ResponseWriter, r *http.Request) {
	// Get query parameters
	branchID := r.URL.Query().Get("branch_id")
	startDate := r.URL.Query().Get("start_date")
	endDate := r.URL.Query().Get("end_date")

	// Build cache key based on filters
	cacheKey := fmt.Sprintf("daily_sales:all")
	if branchID != "" {
		cacheKey = fmt.Sprintf("daily_sales:branch:%s", branchID)
	}
	if startDate != "" && endDate != "" {
		cacheKey = fmt.Sprintf("%s:range:%s:%s", cacheKey, startDate, endDate)
	}

	// Try cache first
	if cachedData, found := cache.Get(cacheKey); found {
		w.Header().Set("X-Cache", "HIT")
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write(cachedData.([]byte))
		log.Printf("✅ Cache HIT for key: %s", cacheKey)
		return
	}

	db := database.GetDB()

	// Build dynamic query
	query := `
		SELECT 
			id, branch_id, sale_date, 
			total_bills, gross_amount, tax_amount, discount_amount,
			total_returns, return_amount, return_tax,
			net_bills, net_amount, net_tax,
			last_sync_at, created_at, updated_at
		FROM erp_daily_sales
		WHERE 1=1
	`
	args := []interface{}{}
	argPos := 1

	// Add branch filter if provided
	if branchID != "" {
		query += fmt.Sprintf(" AND branch_id = $%d", argPos)
		args = append(args, branchID)
		argPos++
	}

	// Add date range filter if provided
	if startDate != "" {
		query += fmt.Sprintf(" AND sale_date >= $%d", argPos)
		args = append(args, startDate)
		argPos++
	}
	if endDate != "" {
		query += fmt.Sprintf(" AND sale_date <= $%d", argPos)
		args = append(args, endDate)
		argPos++
	}

	query += " ORDER BY sale_date DESC, branch_id ASC"

	rows, err := db.Query(query, args...)
	if err != nil {
		log.Printf("❌ Database query error: %v", err)
		respondWithError(w, http.StatusInternalServerError, "Failed to fetch sales data")
		return
	}
	defer rows.Close()

	sales := []mobilemodels.DailySales{}

	for rows.Next() {
		var sale mobilemodels.DailySales
		err := rows.Scan(
			&sale.ID,
			&sale.BranchID,
			&sale.SaleDate,
			&sale.TotalBills,
			&sale.GrossAmount,
			&sale.TaxAmount,
			&sale.DiscountAmount,
			&sale.TotalReturns,
			&sale.ReturnAmount,
			&sale.ReturnTax,
			&sale.NetBills,
			&sale.NetAmount,
			&sale.NetTax,
			&sale.LastSyncAt,
			&sale.CreatedAt,
			&sale.UpdatedAt,
		)
		if err != nil {
			log.Printf("❌ Row scan error: %v", err)
			respondWithError(w, http.StatusInternalServerError, "Failed to parse sales data")
			return
		}
		sales = append(sales, sale)
	}

	if err = rows.Err(); err != nil {
		log.Printf("❌ Rows iteration error: %v", err)
		respondWithError(w, http.StatusInternalServerError, "Failed to process sales data")
		return
	}

	response := mobilemodels.DailySalesResponse{
		Records: sales,
		Count:   len(sales),
	}

	responseJSON, err := json.Marshal(response)
	if err != nil {
		log.Printf("❌ JSON marshal error: %v", err)
		respondWithError(w, http.StatusInternalServerError, "Failed to encode response")
		return
	}

	// Cache for 5 minutes
	cache.Set(cacheKey, responseJSON, 5*time.Minute)
	log.Printf("✅ Cache MISS - Data cached for key: %s (TTL: 5min)", cacheKey)

	w.Header().Set("X-Cache", "MISS")
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write(responseJSON)
}

// ========================================
// GET SALES BY BRANCH - Specific endpoint for branch filtering
// ========================================
func GetDailySalesByBranch(w http.ResponseWriter, r *http.Request) {
	branchID := r.URL.Query().Get("branch_id")
	if branchID == "" {
		respondWithError(w, http.StatusBadRequest, "branch_id is required")
		return
	}

	// Reuse main handler with branch filter
	GetDailySales(w, r)
}
