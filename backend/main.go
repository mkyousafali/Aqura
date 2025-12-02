package main

import (
	"log"
	"net/http"
	"os"
	"strings"

	"github.com/joho/godotenv"
	"github.com/mkyousafali/Aqura/backend/database"
	"github.com/mkyousafali/Aqura/backend/handlers"
	"github.com/mkyousafali/Aqura/backend/middleware"
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

	// Setup routes
	mux := http.NewServeMux()

	// Health check endpoint (no auth required)
	mux.HandleFunc("/health", healthCheck)

	// Branch endpoints
	mux.HandleFunc("/api/branches", func(w http.ResponseWriter, r *http.Request) {
		// Enable CORS
		enableCORS(w, r)
		if r.Method == "OPTIONS" {
			return
		}

		switch r.Method {
		case http.MethodGet:
			handlers.GetBranches(w, r)
		case http.MethodPost:
			// POST requires authentication
			middleware.AuthMiddleware(http.HandlerFunc(handlers.CreateBranch)).ServeHTTP(w, r)
		default:
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		}
	})

	mux.HandleFunc("/api/branches/", func(w http.ResponseWriter, r *http.Request) {
		// Enable CORS
		enableCORS(w, r)
		if r.Method == "OPTIONS" {
			return
		}

		switch r.Method {
		case http.MethodGet:
			handlers.GetBranch(w, r)
		case http.MethodPut:
			// PUT requires authentication
			middleware.AuthMiddleware(http.HandlerFunc(handlers.UpdateBranch)).ServeHTTP(w, r)
		case http.MethodDelete:
			// DELETE requires authentication
			middleware.AuthMiddleware(http.HandlerFunc(handlers.DeleteBranch)).ServeHTTP(w, r)
		default:
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		}
	})

	// Start server
	log.Printf("🚀 Server starting on port %s", port)
	log.Printf("📍 Health check: http://localhost:%s/health", port)
	log.Printf("📍 API endpoint: http://localhost:%s/api/branches", port)

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

	w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
	w.Header().Set("Access-Control-Max-Age", "3600")
}
