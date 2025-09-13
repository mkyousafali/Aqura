package main

import (
	"log"
	"os"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/cors"
	"github.com/gofiber/fiber/v2/middleware/helmet"
	"github.com/gofiber/fiber/v2/middleware/limiter"
	"github.com/gofiber/fiber/v2/middleware/logger"
	"github.com/gofiber/fiber/v2/middleware/recover"
	"github.com/joho/godotenv"
)

func main() {
	// Load environment variables
	if err := godotenv.Load("../../.env"); err != nil {
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
		AllowOrigins:     "http://localhost:5173,https://*.vercel.app,https://*.netlify.app",
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
	return c.JSON(fiber.Map{"message": "Get branches endpoint"})
}

func createBranch(c *fiber.Ctx) error {
	return c.JSON(fiber.Map{"message": "Create branch endpoint"})
}

func updateBranch(c *fiber.Ctx) error {
	return c.JSON(fiber.Map{"message": "Update branch endpoint"})
}

func deleteBranch(c *fiber.Ctx) error {
	return c.JSON(fiber.Map{"message": "Delete branch endpoint"})
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
