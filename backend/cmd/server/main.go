package main

import (
	"fmt"
	"log"
	"os"
	"strconv"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/cors"
	"github.com/gofiber/fiber/v2/middleware/helmet"
	"github.com/gofiber/fiber/v2/middleware/limiter"
	"github.com/gofiber/fiber/v2/middleware/logger"
	"github.com/gofiber/fiber/v2/middleware/recover"
	"github.com/joho/godotenv"
	
	"aqura-backend/internal/database"
	"aqura-backend/internal/domain"
	"aqura-backend/internal/repository"
	"aqura-backend/internal/service"
)

// Branch represents a branch in the system
type Branch struct {
	ID           string    `json:"id"`
	NameEn       string    `json:"name_en"`
	NameAr       string    `json:"name_ar"`
	LocationEn   string    `json:"location_en"`
	LocationAr   string    `json:"location_ar"`
	IsActive     bool      `json:"is_active"`
	IsMainBranch bool      `json:"is_main_branch"`
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"`
}

// In-memory branch storage (replace with database later)
var branches = []Branch{
	{
		ID:           "1",
		NameEn:       "Urban Market (AB)",
		NameAr:       "ايربن ماركت (AB)",
		LocationEn:   "Abu Arish",
		LocationAr:   "أبو عريش",
		IsActive:     true,
		IsMainBranch: true,
		CreatedAt:    time.Now().Add(-time.Hour * 24 * 30),
		UpdatedAt:    time.Now().Add(-time.Hour * 24 * 30),
	},
	{
		ID:           "2",
		NameEn:       "Ali Hassan bin Mohammed Sahli Trading Grocery Store",
		NameAr:       "تموينات علي حسن بن محمد سهلي للتجارة",
		LocationEn:   "Ahad al Masarah",
		LocationAr:   "أحد المسارحة",
		IsActive:     true,
		IsMainBranch: false,
		CreatedAt:    time.Now().Add(-time.Hour * 24 * 25),
		UpdatedAt:    time.Now().Add(-time.Hour * 24 * 25),
	},
	{
		ID:           "3",
		NameEn:       "Urban Market (AR)",
		NameAr:       "ايربن ماركت (AR)",
		LocationEn:   "Al-Aridhah",
		LocationAr:   "العارضة",
		IsActive:     true,
		IsMainBranch: false,
		CreatedAt:    time.Now().Add(-time.Hour * 24 * 20),
		UpdatedAt:    time.Now().Add(-time.Hour * 24 * 20),
	},
}

var nextBranchID = 4

func main() {
	// Load environment variables
	if err := godotenv.Load(".env"); err != nil {
		log.Println("No .env file found, using system environment variables")
	}

	// Initialize database
	err := database.InitDB()
	if err != nil {
		log.Fatalf("Failed to initialize database: %v", err)
	}
	defer database.CloseDB()

	// Initialize Fiber app
	app := fiber.New(fiber.Config{
		AppName:      "Aqura Backend API v1.0.0",
		ServerHeader: "Aqura",
		ErrorHandler: errorHandler,
		BodyLimit:    50 * 1024 * 1024, // 50MB for file uploads
	})

	// Middleware
	app.Use(logger.New(logger.Config{
		Format: "[${time}] ${status} - ${method} ${path} (${latency})\n",
	}))
	app.Use(recover.New())
	app.Use(helmet.New())
	
	// CORS configuration
	app.Use(cors.New(cors.Config{
		AllowOrigins:     "http://localhost:5173,http://localhost:5174,http://localhost:5175,http://localhost:5176,https://*.vercel.app,https://*.netlify.app",
		AllowMethods:     "GET,POST,PUT,DELETE,OPTIONS",
		AllowHeaders:     "Origin,Content-Type,Accept,Authorization,X-User-ID,X-User-Name,X-User-Role",
		AllowCredentials: true,
	}))

	// Rate limiting
	app.Use(limiter.New(limiter.Config{
		Max: 100, // requests per minute
	}))

	// Health check
	app.Get("/health", func(c *fiber.Ctx) error {
		return c.JSON(fiber.Map{
			"status":  "ok",
			"service": "aqura-backend",
			"version": "1.0.0",
		})
	})

	// API routes
	api := app.Group("/api/v1")
	
	// Auth routes
	api.Post("/auth/login", handleLogin)
	api.Post("/auth/logout", handleLogout)
	api.Post("/auth/refresh", handleRefresh)
	api.Post("/auth/change-password", handleChangePassword)
	api.Post("/auth/setup-mfa", handleSetupMFA)
	
	// Admin routes (protected)
	admin := api.Group("/admin")
	admin.Use(authMiddleware)
	
	// HR Master routes
	hr := admin.Group("/hr")
	hr.Get("/employees", getEmployees)
	hr.Post("/employees", createEmployee)
	hr.Put("/employees/:id", updateEmployee)
	hr.Delete("/employees/:id", deleteEmployee)
	hr.Post("/employees/import", importEmployees)
	
	// Branches Master routes
	branches := admin.Group("/branches")
	branches.Get("/", getBranches)
	branches.Post("/", createBranch)
	branches.Put("/:id", updateBranch)
	branches.Delete("/:id", deleteBranch)
	branches.Post("/import", importBranches)
	
	// Vendors Master routes
	vendors := admin.Group("/vendors")
	vendors.Get("/", getVendors)
	vendors.Post("/", createVendor)
	vendors.Put("/:id", updateVendor)
	vendors.Delete("/:id", deleteVendor)
	vendors.Post("/import", importVendors)
	
	// Invoice Master routes
	invoices := admin.Group("/invoices")
	invoices.Get("/", getInvoices)
	invoices.Post("/", createInvoice)
	invoices.Put("/:id", updateInvoice)
	invoices.Delete("/:id", deleteInvoice)
	invoices.Post("/import", importInvoices)
	
	// User Management routes
	users := admin.Group("/users")
	users.Get("/", getUsers)
	users.Post("/", createUser)
	users.Put("/:id", updateUser)
	users.Delete("/:id", deleteUser)
	
	// Notification routes
	notifications := admin.Group("/notifications")
	notifications.Get("/", getNotificationsSimple)
	notifications.Post("/", createNotificationSimple)
	notifications.Put("/:id", updateNotificationSimple)
	notifications.Delete("/:id", deleteNotificationSimple)
	notifications.Post("/:id/read", markNotificationAsReadSimple)
	notifications.Post("/mark-all-read", markAllNotificationsAsReadSimple)
	notifications.Get("/read-status", getAdminReadStatusSimple) // Master Admin only
	
	// Task Master routes
	tasks := admin.Group("/tasks")
	tasks.Get("/", getTasksHandler)
	tasks.Post("/", createTaskHandler)
	tasks.Get("/search", searchTasksHandler)
	tasks.Get("/statistics", getTaskStatisticsHandler)
	tasks.Get("/:id", getTaskByIDHandler)
	tasks.Put("/:id", updateTaskHandler)
	tasks.Delete("/:id", deleteTaskHandler)
	tasks.Post("/:id/activate", activateTaskHandler)
	tasks.Post("/:id/pause", pauseTaskHandler)
	tasks.Post("/:id/resume", resumeTaskHandler)
	tasks.Post("/:id/complete", completeTaskHandler)
	tasks.Get("/:id/images", getTaskImagesHandler)
	tasks.Post("/:id/images", addTaskImageHandler)
	tasks.Get("/:id/assignments", getTaskAssignmentsHandler)
	tasks.Post("/assign", assignTasksHandler)
	
	// Import status and audit routes
	imports := admin.Group("/imports")
	imports.Get("/", getImportJobs)
	imports.Get("/:id", getImportJob)
	imports.Post("/:id/commit", commitImport)
	imports.Post("/:id/rollback", rollbackImport)
	
	// Audit log routes
	audit := admin.Group("/audit")
	audit.Get("/", getAuditLogs)
	audit.Get("/:id", getAuditLog)
	
	// Component Discovery routes (for dynamic app function management)
	// Initialize component discovery service (will need database connection later)
	// componentService := service.NewComponentDiscoveryService(db) // TODO: Add database connection
	// components := admin.Group("/components")
	// components.Get("/discover", transport.ComponentDiscoveryHandler(componentService))
	// components.Post("/discover", transport.ComponentDiscoveryHandler(componentService))
	// components.Post("/register", transport.RegisterComponentFunction(componentService))

	// Temporary endpoint for testing component discovery without database
	admin.Get("/components/discover", func(c *fiber.Ctx) error {
		return c.JSON(fiber.Map{
			"message": "Component discovery endpoint - will be implemented with database connection",
			"note":    "This will automatically scan Svelte components and register app functions",
		})
	})

	// Get port from environment
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("🚀 Aqura Backend starting on port %s", port)
	log.Fatal(app.Listen(":" + port))
}

// Error handler
func errorHandler(c *fiber.Ctx, err error) error {
	code := fiber.StatusInternalServerError
	if e, ok := err.(*fiber.Error); ok {
		code = e.Code
	}

	return c.Status(code).JSON(fiber.Map{
		"error":   true,
		"message": err.Error(),
		"code":    code,
	})
}

// Middleware
func authMiddleware(c *fiber.Ctx) error {
	// TODO: Implement JWT authentication
	return c.Next()
}

// Placeholder handlers - will be implemented in separate files
func handleLogin(c *fiber.Ctx) error {
	return c.JSON(fiber.Map{"message": "Login endpoint"})
}

func handleLogout(c *fiber.Ctx) error {
	return c.JSON(fiber.Map{"message": "Logout endpoint"})
}

func handleRefresh(c *fiber.Ctx) error {
	return c.JSON(fiber.Map{"message": "Refresh endpoint"})
}

func handleChangePassword(c *fiber.Ctx) error {
	return c.JSON(fiber.Map{"message": "Change password endpoint"})
}

func handleSetupMFA(c *fiber.Ctx) error {
	return c.JSON(fiber.Map{"message": "Setup MFA endpoint"})
}

func getEmployees(c *fiber.Ctx) error {
	return c.JSON(fiber.Map{"message": "Get employees endpoint"})
}

func createEmployee(c *fiber.Ctx) error {
	return c.JSON(fiber.Map{"message": "Create employee endpoint"})
}

func updateEmployee(c *fiber.Ctx) error {
	return c.JSON(fiber.Map{"message": "Update employee endpoint"})
}

func deleteEmployee(c *fiber.Ctx) error {
	return c.JSON(fiber.Map{"message": "Delete employee endpoint"})
}

func importEmployees(c *fiber.Ctx) error {
	return c.JSON(fiber.Map{"message": "Import employees endpoint"})
}

func getBranches(c *fiber.Ctx) error {
	// Try to get database connection
	db := database.GetDB()
	if db == nil {
		log.Printf("Database connection is nil, using mock data")
		// Fallback to mock data if no database connection
		return c.JSON(branches)
	}

	// Use simple repository to get real data from Supabase
	branchRepo := repository.NewSimpleBranchRepository(db)
	realBranches, err := branchRepo.GetAllBranches()
	
	if err != nil {
		log.Printf("Error getting branches from database: %v, using mock data", err)
		// Fallback to mock data if database query fails
		return c.JSON(branches)
	}

	// Convert to map format for JSON response
	var data []map[string]interface{}
	for _, branch := range realBranches {
		data = append(data, branch.ToJSON())
	}

	log.Printf("Successfully returning %d branches from Supabase", len(data))
	return c.JSON(data)
}

func createBranch(c *fiber.Ctx) error {
	var newBranch Branch
	
	if err := c.BodyParser(&newBranch); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body"})
	}
	
	// Validate required fields
	if newBranch.NameEn == "" || newBranch.NameAr == "" || newBranch.LocationEn == "" || newBranch.LocationAr == "" {
		return c.Status(400).JSON(fiber.Map{"error": "Missing required fields"})
	}
	
	// Try to get database connection
	db := database.GetDB()
	if db == nil {
		log.Printf("Database connection is nil, using mock data for create")
		// Fallback to original mock data logic
		newBranch.ID = strconv.Itoa(nextBranchID)
		nextBranchID++
		newBranch.CreatedAt = time.Now()
		newBranch.UpdatedAt = time.Now()
		
		// Add to in-memory storage
		branches = append(branches, newBranch)
		
		return c.Status(201).JSON(newBranch)
	}

	// Use SimpleBranchRepository to create real data in Supabase
	branchRepo := repository.NewSimpleBranchRepository(db)
	log.Printf("Database connection successful, creating new branch...")
	
	createdBranch, err := branchRepo.CreateBranch(
		newBranch.NameEn,
		newBranch.NameAr,
		newBranch.LocationEn,
		newBranch.LocationAr,
		newBranch.IsActive,
	)
	
	if err != nil {
		log.Printf("Error creating branch in database: %v", err)
		return c.Status(500).JSON(fiber.Map{"error": "Failed to create branch"})
	}

	log.Printf("Successfully created branch in Supabase")
	return c.Status(201).JSON(createdBranch.ToJSON())
}

func updateBranch(c *fiber.Ctx) error {
	id := c.Params("id")
	
	var updateData Branch
	if err := c.BodyParser(&updateData); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body"})
	}
	
	// Try to get database connection
	db := database.GetDB()
	if db == nil {
		log.Printf("Database connection is nil, using mock data for update")
		// Fallback to original mock data logic
		for i, branch := range branches {
			if branch.ID == id {
				// Update fields if provided
				if updateData.NameEn != "" {
					branches[i].NameEn = updateData.NameEn
				}
				if updateData.NameAr != "" {
					branches[i].NameAr = updateData.NameAr
				}
				if updateData.LocationEn != "" {
					branches[i].LocationEn = updateData.LocationEn
				}
				if updateData.LocationAr != "" {
					branches[i].LocationAr = updateData.LocationAr
				}
				
				branches[i].IsActive = updateData.IsActive
				branches[i].IsMainBranch = updateData.IsMainBranch
				branches[i].UpdatedAt = time.Now()
				
				return c.JSON(branches[i])
			}
		}
		return c.Status(404).JSON(fiber.Map{"error": "Branch not found"})
	}

	// Use SimpleBranchRepository to update real data in Supabase
	branchRepo := repository.NewSimpleBranchRepository(db)
	log.Printf("Database connection successful, updating branch %s...", id)
	
	updatedBranch, err := branchRepo.UpdateBranch(
		id,
		updateData.NameEn,
		updateData.NameAr,
		updateData.LocationEn,
		updateData.LocationAr,
		updateData.IsActive,
	)
	
	if err != nil {
		log.Printf("Error updating branch in database: %v", err)
		return c.Status(500).JSON(fiber.Map{"error": "Failed to update branch"})
	}

	log.Printf("Successfully updated branch %s in Supabase", id)
	return c.JSON(updatedBranch.ToJSON())
}

func deleteBranch(c *fiber.Ctx) error {
	id := c.Params("id")
	
	// Try to get database connection
	db := database.GetDB()
	if db == nil {
		log.Printf("Database connection is nil, using mock data for delete")
		// Fallback to original mock data logic
		for i, branch := range branches {
			if branch.ID == id {
				branches = append(branches[:i], branches[i+1:]...)
				return c.JSON(fiber.Map{"message": "Branch deleted successfully"})
			}
		}
		return c.Status(404).JSON(fiber.Map{"error": "Branch not found"})
	}

	// Use SimpleBranchRepository to delete real data from Supabase
	branchRepo := repository.NewSimpleBranchRepository(db)
	log.Printf("Database connection successful, deleting branch %s...", id)
	
	err := branchRepo.DeleteBranch(id)
	if err != nil {
		if err.Error() == "branch not found" {
			return c.Status(404).JSON(fiber.Map{"error": "Branch not found"})
		}
		log.Printf("Error deleting branch from database: %v", err)
		return c.Status(500).JSON(fiber.Map{"error": "Failed to delete branch"})
	}

	log.Printf("Successfully deleted branch %s from Supabase", id)
	return c.JSON(fiber.Map{"message": "Branch deleted successfully"})
}

func importBranches(c *fiber.Ctx) error {
	return c.JSON(fiber.Map{"message": "Import branches endpoint"})
}

func getVendors(c *fiber.Ctx) error {
	return c.JSON(fiber.Map{"message": "Get vendors endpoint"})
}

func createVendor(c *fiber.Ctx) error {
	return c.JSON(fiber.Map{"message": "Create vendor endpoint"})
}

func updateVendor(c *fiber.Ctx) error {
	return c.JSON(fiber.Map{"message": "Update vendor endpoint"})
}

func deleteVendor(c *fiber.Ctx) error {
	return c.JSON(fiber.Map{"message": "Delete vendor endpoint"})
}

func importVendors(c *fiber.Ctx) error {
	return c.JSON(fiber.Map{"message": "Import vendors endpoint"})
}

func getInvoices(c *fiber.Ctx) error {
	return c.JSON(fiber.Map{"message": "Get invoices endpoint"})
}

func createInvoice(c *fiber.Ctx) error {
	return c.JSON(fiber.Map{"message": "Create invoice endpoint"})
}

func updateInvoice(c *fiber.Ctx) error {
	return c.JSON(fiber.Map{"message": "Update invoice endpoint"})
}

func deleteInvoice(c *fiber.Ctx) error {
	return c.JSON(fiber.Map{"message": "Delete invoice endpoint"})
}

func importInvoices(c *fiber.Ctx) error {
	return c.JSON(fiber.Map{"message": "Import invoices endpoint"})
}

func getUsers(c *fiber.Ctx) error {
	return c.JSON(fiber.Map{"message": "Get users endpoint"})
}

func createUser(c *fiber.Ctx) error {
	return c.JSON(fiber.Map{"message": "Create user endpoint"})
}

func updateUser(c *fiber.Ctx) error {
	return c.JSON(fiber.Map{"message": "Update user endpoint"})
}

func deleteUser(c *fiber.Ctx) error {
	return c.JSON(fiber.Map{"message": "Delete user endpoint"})
}

func getImportJobs(c *fiber.Ctx) error {
	return c.JSON(fiber.Map{"message": "Get import jobs endpoint"})
}

func getImportJob(c *fiber.Ctx) error {
	return c.JSON(fiber.Map{"message": "Get import job endpoint"})
}

func commitImport(c *fiber.Ctx) error {
	return c.JSON(fiber.Map{"message": "Commit import endpoint"})
}

func rollbackImport(c *fiber.Ctx) error {
	return c.JSON(fiber.Map{"message": "Rollback import endpoint"})
}

func getAuditLogs(c *fiber.Ctx) error {
	return c.JSON(fiber.Map{"message": "Get audit logs endpoint"})
}

func getAuditLog(c *fiber.Ctx) error {
	return c.JSON(fiber.Map{"message": "Get audit log endpoint"})
}

// Simple Notification handlers (bypass complex service layer)
func getNotificationsSimple(c *fiber.Ctx) error {
	// Parse query parameters
	limit := 50
	if l := c.Query("limit"); l != "" {
		if parsed, err := strconv.Atoi(l); err == nil && parsed > 0 {
			limit = parsed
		}
	}
	
	offset := 0
	if o := c.Query("offset"); o != "" {
		if parsed, err := strconv.Atoi(o); err == nil && parsed >= 0 {
			offset = parsed
		}
	}

	// Get user ID from header (default to 'default-user' if not provided)
	userID := c.Get("X-User-ID", "default-user")
	log.Printf("Getting notifications for user: %s", userID)

	// Try to get database connection
	db := database.GetDB()
	if db == nil {
		log.Printf("Database connection is nil")
		return c.Status(500).JSON(fiber.Map{
			"success": false,
			"error":   "Database connection not available",
		})
	}

	// Use simple repository with user-specific read states
	simpleRepo := repository.NewSimpleNotificationRepository(db)
	data, total, err := simpleRepo.GetAllNotificationsWithUserReadStates(limit, offset, userID)
	
	if err != nil {
		log.Printf("Error getting notifications from database: %v", err)
		return c.Status(500).JSON(fiber.Map{
			"success": false,
			"error":   "Failed to retrieve notifications from database",
			"details": err.Error(),
		})
	}

	log.Printf("Successfully returning %d notifications with user read states from Supabase", len(data))
	return c.JSON(fiber.Map{
		"success": true,
		"data":    data,
		"total":   total,
		"limit":   limit,
		"offset":  offset,
		"user_id": userID,
	})
}

func createNotificationSimple(c *fiber.Ctx) error {
	var requestData struct {
		Title    string `json:"title"`
		Message  string `json:"message"`
		Type     string `json:"type"`
		Priority string `json:"priority"`
	}
	
	if err := c.BodyParser(&requestData); err != nil {
		return c.Status(400).JSON(fiber.Map{
			"success": false,
			"error":   "Invalid request body",
		})
	}

	// Get database connection
	db := database.GetDB()
	if db == nil {
		return c.Status(500).JSON(fiber.Map{
			"success": false,
			"error":   "Database connection not available",
		})
	}

	// Use simple repository
	simpleRepo := repository.NewSimpleNotificationRepository(db)
	notification, err := simpleRepo.CreateNotification(
		requestData.Title, 
		requestData.Message, 
		requestData.Type, 
		requestData.Priority,
	)
	
	if err != nil {
		log.Printf("Error creating notification: %v", err)
		return c.Status(500).JSON(fiber.Map{
			"success": false,
			"error":   "Failed to create notification",
			"details": err.Error(),
		})
	}
	
	return c.Status(201).JSON(fiber.Map{
		"success": true,
		"data":    notification.ToJSON(),
	})
}

func updateNotificationSimple(c *fiber.Ctx) error {
	id := c.Params("id")
	
	var requestData struct {
		Title    string `json:"title"`
		Message  string `json:"message"`
		Type     string `json:"type"`
		Priority string `json:"priority"`
	}
	
	if err := c.BodyParser(&requestData); err != nil {
		return c.Status(400).JSON(fiber.Map{
			"success": false,
			"error":   "Invalid request body",
		})
	}

	// Get database connection
	db := database.GetDB()
	if db == nil {
		return c.Status(500).JSON(fiber.Map{
			"success": false,
			"error":   "Database connection not available",
		})
	}

	// Use simple repository
	simpleRepo := repository.NewSimpleNotificationRepository(db)
	log.Printf("Database connection successful, updating notification %s...", id)
	
	notification, err := simpleRepo.UpdateNotification(
		id,
		requestData.Title, 
		requestData.Message, 
		requestData.Type, 
		requestData.Priority,
	)
	
	if err != nil {
		if err.Error() == "notification not found" {
			return c.Status(404).JSON(fiber.Map{
				"success": false,
				"error":   "Notification not found",
			})
		}
		log.Printf("Error updating notification: %v", err)
		return c.Status(500).JSON(fiber.Map{
			"success": false,
			"error":   "Failed to update notification",
			"details": err.Error(),
		})
	}
	
	log.Printf("Successfully updated notification %s in Supabase", id)
	return c.JSON(fiber.Map{
		"success": true,
		"data":    notification.ToJSON(),
	})
}

func deleteNotificationSimple(c *fiber.Ctx) error {
	id := c.Params("id")
	
	// Get database connection
	db := database.GetDB()
	if db == nil {
		return c.Status(500).JSON(fiber.Map{
			"success": false,
			"error":   "Database connection not available",
		})
	}

	// Use simple repository
	simpleRepo := repository.NewSimpleNotificationRepository(db)
	log.Printf("Database connection successful, deleting notification %s...", id)
	
	err := simpleRepo.DeleteNotification(id)
	
	if err != nil {
		if err.Error() == "notification not found" {
			return c.Status(404).JSON(fiber.Map{
				"success": false,
				"error":   "Notification not found",
			})
		}
		log.Printf("Error deleting notification: %v", err)
		return c.Status(500).JSON(fiber.Map{
			"success": false,
			"error":   "Failed to delete notification",
			"details": err.Error(),
		})
	}
	
	log.Printf("Successfully deleted notification %s from Supabase", id)
	return c.JSON(fiber.Map{
		"success": true,
		"message": "Notification deleted successfully",
	})
}

func markNotificationAsReadSimple(c *fiber.Ctx) error {
	id := c.Params("id")
	
	// Get user ID from request (for now, we'll use a default user ID)
	// In a real application, this would come from authentication middleware
	userID := c.Get("X-User-ID", "default-user") // Get from header or use default
	if userID == "" {
		userID = "default-user" // Fallback
	}
	
	log.Printf("Marking notification %s as read for user: %s", id, userID)
	
	// Get database connection
	db := database.GetDB()
	if db == nil {
		return c.Status(500).JSON(fiber.Map{
			"success": false,
			"error":   "Database connection not available",
		})
	}

	// Use read state repository to mark as read for this user (no need to check existence - UPSERT handles it)
	readStateRepo := repository.NewNotificationReadStateRepository(db)
	log.Printf("Database connection successful, marking notification %s as read for user %s...", id, userID)
	
	err := readStateRepo.MarkAsRead(id, userID)
	if err != nil {
		log.Printf("Error marking notification as read: %v", err)
		return c.Status(500).JSON(fiber.Map{
			"success": false,
			"error":   "Failed to mark notification as read",
			"details": err.Error(),
		})
	}
	
	log.Printf("Successfully marked notification %s as read for user %s in Supabase", id, userID)
	return c.JSON(fiber.Map{
		"success": true,
		"message": "Notification marked as read",
		"user_id": userID,
	})
}

func markAllNotificationsAsReadSimple(c *fiber.Ctx) error {
	// Get database connection
	db := database.GetDB()
	if db == nil {
		return c.Status(500).JSON(fiber.Map{
			"success": false,
			"error":   "Database connection not available",
		})
	}

	// Get user ID from header (default to 'default-user' if not provided)
	userID := c.Get("X-User-ID", "default-user")
	log.Printf("Marking all notifications as read for user: %s", userID)

	// Use notification read state repository for per-user tracking
	readStateRepo := repository.NewNotificationReadStateRepository(db)
	
	err := readStateRepo.MarkAllAsRead(userID)
	
	if err != nil {
		log.Printf("Error marking all notifications as read for user %s: %v", userID, err)
		return c.Status(500).JSON(fiber.Map{
			"success": false,
			"error":   "Failed to mark all notifications as read",
			"details": err.Error(),
		})
	}
	
	log.Printf("Successfully marked all notifications as read for user: %s", userID)
	return c.JSON(fiber.Map{
		"success": true,
		"message": "All notifications marked as read",
		"user_id": userID,
	})
}

func getAdminReadStatusSimple(c *fiber.Ctx) error {
	// Role-based access control - only Master Admin should access this endpoint
	userRole := c.Get("X-User-Role", "")
	if userRole != "Master Admin" {
		log.Printf("Access denied for role: %s (requires Master Admin)", userRole)
		return c.Status(403).JSON(fiber.Map{
			"success": false,
			"error":   "Access denied. Master Admin role required.",
		})
	}
	
	// Get database connection
	db := database.GetDB()
	if db == nil {
		return c.Status(500).JSON(fiber.Map{
			"success": false,
			"error":   "Database connection not available",
		})
	}

	log.Printf("Fetching admin read status data...")

	// Get all notifications
	simpleRepo := repository.NewSimpleNotificationRepository(db)
	notifications, _, err := simpleRepo.GetAllNotifications(100, 0) // Get first 100 notifications
	if err != nil {
		log.Printf("Error getting notifications for admin read status: %v", err)
		return c.Status(500).JSON(fiber.Map{
			"success": false,
			"error":   "Failed to fetch notifications",
		})
	}

	// Get all read states
	readStateRepo := repository.NewNotificationReadStateRepository(db)
	readStates, err := readStateRepo.GetAllReadStates()
	if err != nil {
		log.Printf("Error getting read states for admin: %v", err)
		return c.Status(500).JSON(fiber.Map{
			"success": false,
			"error":   "Failed to fetch read states",
		})
	}

	// Get unique users from read states
	userMap := make(map[string]bool)
	for _, readState := range readStates {
		userMap[readState.UserID] = true
	}
	
	// Fetch actual usernames from the database
	users := make([]map[string]string, 0, len(userMap))
	for userID := range userMap {
		var username string
		var employeeName string
		
		// Try to get username from users table first
		err := db.QueryRow("SELECT username FROM users WHERE id = $1", userID).Scan(&username)
		if err != nil {
			// If no user found, try to get name from hr_employees table
			err = db.QueryRow("SELECT name FROM hr_employees WHERE id = $1", userID).Scan(&employeeName)
			if err != nil {
				// If neither found, use the user ID as fallback
				username = userID
			} else {
				username = employeeName
			}
		}
		
		users = append(users, map[string]string{
			"id":   userID,
			"name": username,
		})
	}

	// Transform notifications for frontend
	notificationList := make([]map[string]interface{}, len(notifications))
	for i, n := range notifications {
		notificationList[i] = map[string]interface{}{
			"id":         n.ID,
			"title":      n.Title,
			"type":       n.Type,
			"priority":   n.Priority,
			"created_at": n.CreatedAt,
		}
	}

	// Transform read states for frontend
	readStateList := make([]map[string]interface{}, len(readStates))
	for i, rs := range readStates {
		// Find notification title for this read state
		var notificationTitle string
		var notificationType string
		for _, n := range notifications {
			if n.ID == rs.NotificationID {
				notificationTitle = n.Title
				notificationType = n.Type
				break
			}
		}

		// Find username for this read state
		var username string
		var employeeName string
		
		// Try to get username from users table first
		err := db.QueryRow("SELECT username FROM users WHERE id = $1", rs.UserID).Scan(&username)
		if err != nil {
			// If no user found, try to get name from hr_employees table
			err = db.QueryRow("SELECT name FROM hr_employees WHERE id = $1", rs.UserID).Scan(&employeeName)
			if err != nil {
				// If neither found, use the user ID as fallback
				username = rs.UserID
			} else {
				username = employeeName
			}
		}

		readStateList[i] = map[string]interface{}{
			"notification_id":    rs.NotificationID,
			"notification_title": notificationTitle,
			"notification_type":  notificationType,
			"user_id":           rs.UserID,
			"user_name":         username,
			"read_at":           rs.ReadAt,
		}
	}

	log.Printf("Successfully fetched admin read status data: %d notifications, %d read states, %d users", 
		len(notifications), len(readStates), len(users))

	return c.JSON(fiber.Map{
		"success": true,
		"data": fiber.Map{
			"notifications": notificationList,
			"readStates":   readStateList,
			"users":        users,
		},
	})
}

// =====================================================
// TASK MASTER HANDLERS
// =====================================================

// getTasksHandler retrieves all tasks with optional filtering
func getTasksHandler(c *fiber.Ctx) error {
	// Parse query parameters
	limit := 50
	if l := c.Query("limit"); l != "" {
		if parsed, err := strconv.Atoi(l); err == nil && parsed > 0 {
			limit = parsed
		}
	}
	
	offset := 0
	if o := c.Query("offset"); o != "" {
		if parsed, err := strconv.Atoi(o); err == nil && parsed >= 0 {
			offset = parsed
		}
	}

	status := c.Query("status")
	createdBy := c.Query("created_by")
	userID := c.Get("X-User-ID", "default-user")

	log.Printf("Getting tasks for user: %s (limit: %d, offset: %d, status: %s, createdBy: %s)", 
		userID, limit, offset, status, createdBy)

	// Get database connection
	db := database.GetDB()
	if db == nil {
		return c.Status(500).JSON(fiber.Map{
			"success": false,
			"error":   "Database connection not available",
		})
	}

	// Use task repository
	taskRepo := repository.NewTaskRepository(db)
	taskService := service.NewTaskService(taskRepo)

	tasks, total, err := taskService.GetAllTasks(limit, offset, status, createdBy)
	if err != nil {
		log.Printf("Error getting tasks: %v", err)
		return c.Status(500).JSON(fiber.Map{
			"success": false,
			"error":   "Failed to retrieve tasks",
			"details": err.Error(),
		})
	}

	log.Printf("Successfully returning %d tasks from database", len(tasks))
	return c.JSON(fiber.Map{
		"success": true,
		"data":    tasks,
		"total":   total,
		"limit":   limit,
		"offset":  offset,
	})
}

// createTaskHandler creates a new task
func createTaskHandler(c *fiber.Ctx) error {
	var req domain.CreateTaskRequest
	
	if err := c.BodyParser(&req); err != nil {
		return c.Status(400).JSON(fiber.Map{
			"success": false,
			"error":   "Invalid request body",
			"details": err.Error(),
		})
	}

	// Get user info from headers
	userID := c.Get("X-User-ID", "default-user")
	userName := c.Get("X-User-Name", "Unknown User")
	userRole := c.Get("X-User-Role", "User")

	log.Printf("Creating task: %s by user: %s", req.Title, userID)

	// Get database connection
	db := database.GetDB()
	if db == nil {
		return c.Status(500).JSON(fiber.Map{
			"success": false,
			"error":   "Database connection not available",
		})
	}

	// Use task service
	taskRepo := repository.NewTaskRepository(db)
	taskService := service.NewTaskService(taskRepo)

	task, err := taskService.CreateTask(req, userID, userName, userRole)
	if err != nil {
		log.Printf("Error creating task: %v", err)
		return c.Status(500).JSON(fiber.Map{
			"success": false,
			"error":   "Failed to create task",
			"details": err.Error(),
		})
	}

	log.Printf("Successfully created task with ID: %s", task.ID)
	return c.Status(201).JSON(fiber.Map{
		"success": true,
		"data":    task.ToJSON(),
	})
}

// getTaskByIDHandler retrieves a task by ID
func getTaskByIDHandler(c *fiber.Ctx) error {
	taskID := c.Params("id")
	
	if taskID == "" {
		return c.Status(400).JSON(fiber.Map{
			"success": false,
			"error":   "Task ID is required",
		})
	}

	log.Printf("Getting task by ID: %s", taskID)

	// Get database connection
	db := database.GetDB()
	if db == nil {
		return c.Status(500).JSON(fiber.Map{
			"success": false,
			"error":   "Database connection not available",
		})
	}

	// Use task service
	taskRepo := repository.NewTaskRepository(db)
	taskService := service.NewTaskService(taskRepo)

	task, err := taskService.GetTaskByID(taskID)
	if err != nil {
		log.Printf("Error getting task: %v", err)
		return c.Status(404).JSON(fiber.Map{
			"success": false,
			"error":   "Task not found",
			"details": err.Error(),
		})
	}

	return c.JSON(fiber.Map{
		"success": true,
		"data":    task.ToJSON(),
	})
}

// updateTaskHandler updates an existing task
func updateTaskHandler(c *fiber.Ctx) error {
	taskID := c.Params("id")
	
	if taskID == "" {
		return c.Status(400).JSON(fiber.Map{
			"success": false,
			"error":   "Task ID is required",
		})
	}

	var req domain.UpdateTaskRequest
	
	if err := c.BodyParser(&req); err != nil {
		return c.Status(400).JSON(fiber.Map{
			"success": false,
			"error":   "Invalid request body",
			"details": err.Error(),
		})
	}

	userID := c.Get("X-User-ID", "default-user")

	log.Printf("Updating task ID: %s by user: %s", taskID, userID)

	// Get database connection
	db := database.GetDB()
	if db == nil {
		return c.Status(500).JSON(fiber.Map{
			"success": false,
			"error":   "Database connection not available",
		})
	}

	// Use task service
	taskRepo := repository.NewTaskRepository(db)
	taskService := service.NewTaskService(taskRepo)

	err := taskService.UpdateTask(taskID, req, userID)
	if err != nil {
		log.Printf("Error updating task: %v", err)
		return c.Status(500).JSON(fiber.Map{
			"success": false,
			"error":   "Failed to update task",
			"details": err.Error(),
		})
	}

	return c.JSON(fiber.Map{
		"success": true,
		"message": "Task updated successfully",
	})
}

// deleteTaskHandler soft deletes a task
func deleteTaskHandler(c *fiber.Ctx) error {
	taskID := c.Params("id")
	
	if taskID == "" {
		return c.Status(400).JSON(fiber.Map{
			"success": false,
			"error":   "Task ID is required",
		})
	}

	userID := c.Get("X-User-ID", "default-user")

	log.Printf("Deleting task ID: %s by user: %s", taskID, userID)

	// Get database connection
	db := database.GetDB()
	if db == nil {
		return c.Status(500).JSON(fiber.Map{
			"success": false,
			"error":   "Database connection not available",
		})
	}

	// Use task service
	taskRepo := repository.NewTaskRepository(db)
	taskService := service.NewTaskService(taskRepo)

	err := taskService.DeleteTask(taskID, userID)
	if err != nil {
		log.Printf("Error deleting task: %v", err)
		return c.Status(500).JSON(fiber.Map{
			"success": false,
			"error":   "Failed to delete task",
			"details": err.Error(),
		})
	}

	return c.JSON(fiber.Map{
		"success": true,
		"message": "Task deleted successfully",
	})
}

// searchTasksHandler performs full-text search on tasks
func searchTasksHandler(c *fiber.Ctx) error {
	query := c.Query("q", "")
	userID := c.Get("X-User-ID", "default-user")
	
	limit := 50
	if l := c.Query("limit"); l != "" {
		if parsed, err := strconv.Atoi(l); err == nil && parsed > 0 {
			limit = parsed
		}
	}
	
	offset := 0
	if o := c.Query("offset"); o != "" {
		if parsed, err := strconv.Atoi(o); err == nil && parsed >= 0 {
			offset = parsed
		}
	}

	log.Printf("Searching tasks with query: '%s' for user: %s", query, userID)

	// Get database connection
	db := database.GetDB()
	if db == nil {
		return c.Status(500).JSON(fiber.Map{
			"success": false,
			"error":   "Database connection not available",
		})
	}

	// Use task service
	taskRepo := repository.NewTaskRepository(db)
	taskService := service.NewTaskService(taskRepo)

	results, total, err := taskService.SearchTasks(query, userID, limit, offset)
	if err != nil {
		log.Printf("Error searching tasks: %v", err)
		return c.Status(500).JSON(fiber.Map{
			"success": false,
			"error":   "Failed to search tasks",
			"details": err.Error(),
		})
	}

	return c.JSON(fiber.Map{
		"success": true,
		"data":    results,
		"total":   total,
		"query":   query,
		"limit":   limit,
		"offset":  offset,
	})
}

// assignTasksHandler assigns multiple tasks to users, branches, or all
func assignTasksHandler(c *fiber.Ctx) error {
	var req domain.AssignTaskRequest
	
	if err := c.BodyParser(&req); err != nil {
		return c.Status(400).JSON(fiber.Map{
			"success": false,
			"error":   "Invalid request body",
			"details": err.Error(),
		})
	}

	userID := c.Get("X-User-ID", "default-user")
	userName := c.Get("X-User-Name", "Unknown User")

	log.Printf("Assigning %d tasks (type: %s) by user: %s", len(req.TaskIDs), req.AssignmentType, userID)

	// Get database connection
	db := database.GetDB()
	if db == nil {
		return c.Status(500).JSON(fiber.Map{
			"success": false,
			"error":   "Database connection not available",
		})
	}

	// Use task service
	taskRepo := repository.NewTaskRepository(db)
	taskService := service.NewTaskService(taskRepo)

	err := taskService.AssignTasks(req, userID, userName)
	if err != nil {
		log.Printf("Error assigning tasks: %v", err)
		return c.Status(500).JSON(fiber.Map{
			"success": false,
			"error":   "Failed to assign tasks",
			"details": err.Error(),
		})
	}

	return c.JSON(fiber.Map{
		"success": true,
		"message": fmt.Sprintf("Successfully assigned %d tasks", len(req.TaskIDs)),
	})
}

// getTaskStatisticsHandler retrieves task statistics for a user
func getTaskStatisticsHandler(c *fiber.Ctx) error {
	userID := c.Get("X-User-ID", "default-user")

	log.Printf("Getting task statistics for user: %s", userID)

	// Get database connection
	db := database.GetDB()
	if db == nil {
		return c.Status(500).JSON(fiber.Map{
			"success": false,
			"error":   "Database connection not available",
		})
	}

	// Use task service
	taskRepo := repository.NewTaskRepository(db)
	taskService := service.NewTaskService(taskRepo)

	stats, err := taskService.GetTaskStatistics(userID)
	if err != nil {
		log.Printf("Error getting task statistics: %v", err)
		return c.Status(500).JSON(fiber.Map{
			"success": false,
			"error":   "Failed to get task statistics",
			"details": err.Error(),
		})
	}

	return c.JSON(fiber.Map{
		"success": true,
		"data":    stats,
	})
}

// getTaskImagesHandler retrieves all images for a task
func getTaskImagesHandler(c *fiber.Ctx) error {
	taskID := c.Params("id")
	
	if taskID == "" {
		return c.Status(400).JSON(fiber.Map{
			"success": false,
			"error":   "Task ID is required",
		})
	}

	log.Printf("Getting images for task: %s", taskID)

	// Get database connection
	db := database.GetDB()
	if db == nil {
		return c.Status(500).JSON(fiber.Map{
			"success": false,
			"error":   "Database connection not available",
		})
	}

	// Use task service
	taskRepo := repository.NewTaskRepository(db)
	taskService := service.NewTaskService(taskRepo)

	images, err := taskService.GetTaskImages(taskID)
	if err != nil {
		log.Printf("Error getting task images: %v", err)
		return c.Status(500).JSON(fiber.Map{
			"success": false,
			"error":   "Failed to get task images",
			"details": err.Error(),
		})
	}

	return c.JSON(fiber.Map{
		"success": true,
		"data":    images,
	})
}

// addTaskImageHandler adds an image to a task
func addTaskImageHandler(c *fiber.Ctx) error {
	taskID := c.Params("id")
	
	if taskID == "" {
		return c.Status(400).JSON(fiber.Map{
			"success": false,
			"error":   "Task ID is required",
		})
	}

	var image domain.TaskImage
	
	if err := c.BodyParser(&image); err != nil {
		return c.Status(400).JSON(fiber.Map{
			"success": false,
			"error":   "Invalid request body",
			"details": err.Error(),
		})
	}

	userID := c.Get("X-User-ID", "default-user")
	userName := c.Get("X-User-Name", "Unknown User")

	image.UploadedBy = userID
	image.UploadedByName = &userName

	log.Printf("Adding image to task: %s (type: %s)", taskID, image.ImageType)

	// Get database connection
	db := database.GetDB()
	if db == nil {
		return c.Status(500).JSON(fiber.Map{
			"success": false,
			"error":   "Database connection not available",
		})
	}

	// Use task service
	taskRepo := repository.NewTaskRepository(db)
	taskService := service.NewTaskService(taskRepo)

	createdImage, err := taskService.AddTaskImage(taskID, image)
	if err != nil {
		log.Printf("Error adding task image: %v", err)
		return c.Status(500).JSON(fiber.Map{
			"success": false,
			"error":   "Failed to add task image",
			"details": err.Error(),
		})
	}

	return c.Status(201).JSON(fiber.Map{
		"success": true,
		"data":    createdImage,
	})
}

// getTaskAssignmentsHandler retrieves all assignments for a task
func getTaskAssignmentsHandler(c *fiber.Ctx) error {
	taskID := c.Params("id")
	
	if taskID == "" {
		return c.Status(400).JSON(fiber.Map{
			"success": false,
			"error":   "Task ID is required",
		})
	}

	log.Printf("Getting assignments for task: %s", taskID)

	// Get database connection
	db := database.GetDB()
	if db == nil {
		return c.Status(500).JSON(fiber.Map{
			"success": false,
			"error":   "Database connection not available",
		})
	}

	// Use task service
	taskRepo := repository.NewTaskRepository(db)
	taskService := service.NewTaskService(taskRepo)

	assignments, err := taskService.GetTaskAssignments(taskID)
	if err != nil {
		log.Printf("Error getting task assignments: %v", err)
		return c.Status(500).JSON(fiber.Map{
			"success": false,
			"error":   "Failed to get task assignments",
			"details": err.Error(),
		})
	}

	return c.JSON(fiber.Map{
		"success": true,
		"data":    assignments,
	})
}

// activateTaskHandler activates a draft task
func activateTaskHandler(c *fiber.Ctx) error {
	taskID := c.Params("id")
	userID := c.Get("X-User-ID", "default-user")
	
	// Get database connection
	db := database.GetDB()
	if db == nil {
		return c.Status(500).JSON(fiber.Map{
			"success": false,
			"error":   "Database connection not available",
		})
	}

	// Use task service
	taskRepo := repository.NewTaskRepository(db)
	taskService := service.NewTaskService(taskRepo)

	err := taskService.ActivateTask(taskID, userID)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{
			"success": false,
			"error":   "Failed to activate task",
			"details": err.Error(),
		})
	}

	return c.JSON(fiber.Map{
		"success": true,
		"message": "Task activated successfully",
	})
}

// pauseTaskHandler pauses an active task
func pauseTaskHandler(c *fiber.Ctx) error {
	taskID := c.Params("id")
	userID := c.Get("X-User-ID", "default-user")
	
	// Get database connection
	db := database.GetDB()
	if db == nil {
		return c.Status(500).JSON(fiber.Map{
			"success": false,
			"error":   "Database connection not available",
		})
	}

	// Use task service
	taskRepo := repository.NewTaskRepository(db)
	taskService := service.NewTaskService(taskRepo)

	err := taskService.PauseTask(taskID, userID)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{
			"success": false,
			"error":   "Failed to pause task",
			"details": err.Error(),
		})
	}

	return c.JSON(fiber.Map{
		"success": true,
		"message": "Task paused successfully",
	})
}

// resumeTaskHandler resumes a paused task
func resumeTaskHandler(c *fiber.Ctx) error {
	taskID := c.Params("id")
	userID := c.Get("X-User-ID", "default-user")
	
	// Get database connection
	db := database.GetDB()
	if db == nil {
		return c.Status(500).JSON(fiber.Map{
			"success": false,
			"error":   "Database connection not available",
		})
	}

	// Use task service
	taskRepo := repository.NewTaskRepository(db)
	taskService := service.NewTaskService(taskRepo)

	err := taskService.ResumeTask(taskID, userID)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{
			"success": false,
			"error":   "Failed to resume task",
			"details": err.Error(),
		})
	}

	return c.JSON(fiber.Map{
		"success": true,
		"message": "Task resumed successfully",
	})
}

// completeTaskHandler marks a task as completed
func completeTaskHandler(c *fiber.Ctx) error {
	taskID := c.Params("id")
	userID := c.Get("X-User-ID", "default-user")
	
	// Get database connection
	db := database.GetDB()
	if db == nil {
		return c.Status(500).JSON(fiber.Map{
			"success": false,
			"error":   "Database connection not available",
		})
	}

	// Use task service
	taskRepo := repository.NewTaskRepository(db)
	taskService := service.NewTaskService(taskRepo)

	err := taskService.CompleteTask(taskID, userID)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{
			"success": false,
			"error":   "Failed to complete task",
			"details": err.Error(),
		})
	}

	return c.JSON(fiber.Map{
		"success": true,
		"message": "Task completed successfully",
	})
}
