package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
	"strings"

	"github.com/joho/godotenv"
	"github.com/mkyousafali/Aqura/backend/cache"
	"github.com/mkyousafali/Aqura/backend/database"
	desktophandlers "github.com/mkyousafali/Aqura/backend/handlers/desktop-interface"
	mobilehandlers "github.com/mkyousafali/Aqura/backend/handlers/mobile-interface"
)

func main() {
	// Load environment variables from .env file
	if err := godotenv.Load(); err != nil {
		log.Println("⚠️  No .env file found, using environment variables")
	}

	// Load environment variables
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	// Initialize database connection
	log.Println("🔌 Connecting to Supabase database...")
	if err := database.InitDB(); err != nil {
		log.Fatalf("Failed to initialize database: %v", err)
	}
	defer database.CloseDB()

	// Start notification listener for real-time cache updates
	log.Println("🔔 Starting database notification listener...")
	if err := database.StartNotificationListener(handleDatabaseNotification); err != nil {
		log.Printf("⚠️ Failed to start notification listener: %v", err)
	}

	// Setup routes
	mux := http.NewServeMux()

	// Health check endpoint (no auth required, with CORS)
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		enableCORS(w, r)
		if r.Method == "OPTIONS" {
			return
		}
		healthCheck(w, r)
	})

	// Branch endpoints
	mux.HandleFunc("/api/branches", func(w http.ResponseWriter, r *http.Request) {
		// Enable CORS
		enableCORS(w, r)
		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}

		switch r.Method {
		case http.MethodGet:
			desktophandlers.GetBranches(w, r)
		case http.MethodPost:
			// POST requires authentication (disabled for testing)
			desktophandlers.CreateBranch(w, r)
		default:
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		}
	})

	mux.HandleFunc("/api/branches/", func(w http.ResponseWriter, r *http.Request) {
		// Enable CORS
		enableCORS(w, r)
		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}

		switch r.Method {
		case http.MethodGet:
			desktophandlers.GetBranch(w, r)
		case http.MethodPut:
			// PUT requires authentication (disabled for testing)
			desktophandlers.UpdateBranch(w, r)
		case http.MethodDelete:
			// DELETE requires authentication (disabled for testing)
			desktophandlers.DeleteBranch(w, r)
		default:
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		}
	})

	// Mobile Dashboard endpoint
	mux.HandleFunc("/api/mobile/dashboard", func(w http.ResponseWriter, r *http.Request) {
		// Enable CORS
		enableCORS(w, r)
		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}

		switch r.Method {
		case http.MethodGet:
			mobilehandlers.GetDashboard(w, r)
		default:
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		}
	})

	// Sales Report endpoints
	mux.HandleFunc("/api/mobile/sales", func(w http.ResponseWriter, r *http.Request) {
		// Enable CORS
		enableCORS(w, r)
		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}

		switch r.Method {
		case http.MethodGet:
			mobilehandlers.GetDailySales(w, r)
		default:
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		}
	})

	// Start server
	log.Printf("🚀 Server starting on port %s", port)
	log.Printf("📍 Health check: http://localhost:%s/health", port)
	log.Printf("📍 API endpoint: http://localhost:%s/api/branches", port)
	log.Printf("📍 Mobile Dashboard: http://localhost:%s/api/mobile/dashboard", port)
	log.Printf("📍 Sales Report: http://localhost:%s/api/mobile/sales", port)

	if err := http.ListenAndServe(":"+port, mux); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}

// healthCheck returns server status
func healthCheck(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(`{"status":"ok","service":"aqura-backend","version":"1.0.0"}`))
}

// enableCORS sets CORS headers
func enableCORS(w http.ResponseWriter, r *http.Request) {
	allowedOrigins := os.Getenv("ALLOWED_ORIGINS")
	if allowedOrigins == "" {
		allowedOrigins = "http://localhost:5173,http://localhost:4173"
	}

	origin := r.Header.Get("Origin")
	origins := strings.Split(allowedOrigins, ",")

	// Check if origin is allowed
	for _, o := range origins {
		if strings.TrimSpace(o) == origin {
			w.Header().Set("Access-Control-Allow-Origin", origin)
			break
		}
	}

	// If no specific origin matched, allow all for development
	if w.Header().Get("Access-Control-Allow-Origin") == "" {
		w.Header().Set("Access-Control-Allow-Origin", "*")
	}

	w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization, apikey")
	w.Header().Set("Access-Control-Allow-Credentials", "true")
	w.Header().Set("Access-Control-Max-Age", "3600")
}

// handleDatabaseNotification processes PostgreSQL LISTEN/NOTIFY events
// and invalidates the appropriate cache entries
func handleDatabaseNotification(channel string, payload string) {
	log.Printf("📢 Received notification on channel: %s | Payload: %s", channel, payload)

	switch channel {
	case "branches_changed":
		// Invalidate all branches cache when any branch is modified
		cache.Invalidate("branches:all")
		log.Printf("🔄 Cache invalidated for branches (trigger: database change)")

	case "erp_daily_sales_changed":
		// Invalidate all sales cache when sales data is modified
		cache.InvalidatePattern("daily_sales:")
		log.Printf("🔄 Cache invalidated for daily sales (trigger: database change)")

	case "cache_invalidate":
		// Generic cache invalidation - expects JSON payload with "key" field
		// Example: {"key": "branches:all"} or {"key": "vendors:all"}
		if payload != "" {
			var data map[string]interface{}
			if err := json.Unmarshal([]byte(payload), &data); err == nil {
				if key, ok := data["key"].(string); ok {
					cache.Invalidate(key)
					log.Printf("🔄 Cache invalidated: %s", key)
				}
			} else {
				log.Printf("⚠️  Failed to parse cache_invalidate payload: %v", err)
			}
		}

	default:
		log.Printf("⚠️  Unknown notification channel: %s", channel)
	}
}
