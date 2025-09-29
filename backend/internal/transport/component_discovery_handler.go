package transport

import (
	"path/filepath"

	"github.com/gofiber/fiber/v2"
)

// ComponentDiscoveryService interface
type ComponentDiscoveryServiceInterface interface {
	DiscoverComponents(frontendPath string) (*ComponentMetadata, error)
	SyncAppFunctions(metadata *ComponentMetadata) error
	RegisterFunction(name, code, description, category string) error
}

type ComponentFunction struct {
	Name        string `json:"name"`
	Code        string `json:"code"`
	Description string `json:"description"`
	Category    string `json:"category"`
}

type DiscoveredComponent struct {
	Name      string              `json:"name"`
	Path      string              `json:"path"`
	Category  string              `json:"category"`
	Functions []ComponentFunction `json:"functions"`
}

type ComponentMetadata struct {
	Components []DiscoveredComponent `json:"components"`
}

// ComponentDiscoveryHandler handles component discovery API requests
func ComponentDiscoveryHandler(service ComponentDiscoveryServiceInterface) func(*fiber.Ctx) error {
	return func(c *fiber.Ctx) error {
		// Get frontend path - assuming it's relative to the backend
		frontendPath := filepath.Join("..", "frontend")
		
		// Discover components
		metadata, err := service.DiscoverComponents(frontendPath)
		if err != nil {
			return c.Status(500).JSON(fiber.Map{
				"error": "Failed to discover components: " + err.Error(),
			})
		}

		// Sync with database if POST request
		if c.Method() == "POST" {
			err = service.SyncAppFunctions(metadata)
			if err != nil {
				return c.Status(500).JSON(fiber.Map{
					"error": "Failed to sync components to database: " + err.Error(),
				})
			}
		}

		// Return the discovered metadata
		return c.JSON(fiber.Map{
			"success":    true,
			"message":    "Components discovered and synced successfully",
			"components": metadata.Components,
			"count":      len(metadata.Components),
		})
	}
}

// RegisterComponentFunction manually registers a single component function
func RegisterComponentFunction(service ComponentDiscoveryServiceInterface) func(*fiber.Ctx) error {
	return func(c *fiber.Ctx) error {
		var req struct {
			Name        string `json:"name"`
			Code        string `json:"code"`
			Description string `json:"description"`
			Category    string `json:"category"`
		}

		if err := c.BodyParser(&req); err != nil {
			return c.Status(400).JSON(fiber.Map{
				"error": "Invalid request body",
			})
		}

		// Validate required fields
		if req.Name == "" || req.Code == "" {
			return c.Status(400).JSON(fiber.Map{
				"error": "Name and code are required",
			})
		}

		// Set defaults
		if req.Description == "" {
			req.Description = req.Name + " functionality"
		}
		if req.Category == "" {
			req.Category = "Application"
		}

		// Register the function
		err := service.RegisterFunction(req.Name, req.Code, req.Description, req.Category)
		if err != nil {
			return c.Status(500).JSON(fiber.Map{
				"error": "Failed to register function: " + err.Error(),
			})
		}

		return c.JSON(fiber.Map{
			"success": true,
			"message": "Function registered successfully",
			"function": map[string]string{
				"name":        req.Name,
				"code":        req.Code,
				"description": req.Description,
				"category":    req.Category,
			},
		})
	}
}