package main

import (
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
		AllowHeaders:     "Origin,Content-Type,Accept,Authorization",
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
	return c.JSON(branches)
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
	
	// Set automatic fields
	newBranch.ID = strconv.Itoa(nextBranchID)
	nextBranchID++
	newBranch.CreatedAt = time.Now()
	newBranch.UpdatedAt = time.Now()
	
	// Add to in-memory storage
	branches = append(branches, newBranch)
	
	return c.Status(201).JSON(newBranch)
}

func updateBranch(c *fiber.Ctx) error {
	id := c.Params("id")
	
	var updateData Branch
	if err := c.BodyParser(&updateData); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body"})
	}
	
	// Find branch by ID
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

func deleteBranch(c *fiber.Ctx) error {
	id := c.Params("id")
	
	// Find and remove branch by ID
	for i, branch := range branches {
		if branch.ID == id {
			branches = append(branches[:i], branches[i+1:]...)
			return c.JSON(fiber.Map{"message": "Branch deleted successfully"})
		}
	}
	
	return c.Status(404).JSON(fiber.Map{"error": "Branch not found"})
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
