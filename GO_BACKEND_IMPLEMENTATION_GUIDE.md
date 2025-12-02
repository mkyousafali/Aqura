# Go Backend Implementation Guide

Complete reference for implementing Go backend endpoints with caching, fallback, and error handling.

## 🚀 Quick Start - Implement Any Component

**Ready to implement Go backend for a component?**

### Simple Command:
Just say: **"Implement Go backend for [Component Name]"**

### What Happens Automatically:
1. ✅ **Backend Model** - Creates `backend/models/[entity].go` with proper types
2. ✅ **Backend Handler** - Creates `backend/handlers/[entity].go` with:
   - GET all (with 5min cache)
   - GET by ID
   - CREATE (invalidates cache)
   - UPDATE (invalidates cache)  
   - DELETE/soft delete (invalidates cache)
3. ✅ **Routes** - Adds to `backend/main.go` with CORS
4. ✅ **Frontend API** - Adds to `frontend/src/lib/utils/goAPI.ts` with:
   - Client-side caching
   - Health check before requests
   - Automatic Supabase fallback
   - Error handling
5. ✅ **Component Update** - Updates your Svelte component to use Go API
6. ✅ **Testing** - Validates all endpoints work
7. ✅ **Deployment** - Commits and pushes to Railway/Vercel

### Examples:
```
"Implement Go backend for Vendor Master"
"Implement Go backend for Employee Master"  
"Implement Go backend for Product Categories"
"Implement Go backend for Receiving Records"
```

### Current Status:
- ✅ **Branch Master** - Fully implemented with caching & fallback
- ⏳ **All others** - Ready for implementation

---

## Table of Contents
1. [Quick Start](#quick-start---implement-any-component)
2. [Backend Structure](#backend-structure)
3. [Handler Implementation](#handler-implementation)
4. [Frontend Integration](#frontend-integration)
5. [Running Local Development](#running-local-development)
6. [Testing](#testing)
7. [Component List](#component-list-ready-for-implementation)

---

## Backend Structure

### File Organization
```
backend/
├── main.go                 # Routes and server setup
├── cache/
│   └── cache.go           # In-memory cache (5min TTL)
├── database/
│   └── supabase.go        # Database connection
├── handlers/
│   └── your_handler.go    # API handlers
├── models/
│   └── your_model.go      # Data structures
└── middleware/
    └── auth.go            # JWT authentication
```

---

## Handler Implementation

### Step 1: Create Model (`backend/models/your_model.go`)

```go
package models

import (
	"database/sql"
	"encoding/json"
	"time"
)

// Main struct
type YourEntity struct {
	ID        int64     `json:"id"`
	Name      string    `json:"name"`
	IsActive  bool      `json:"is_active"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

// Custom NullString for proper JSON serialization
type NullString struct {
	sql.NullString
}

func (ns NullString) MarshalJSON() ([]byte, error) {
	if ns.Valid {
		return json.Marshal(ns.String)
	}
	return json.Marshal(nil)
}

func (ns *NullString) UnmarshalJSON(data []byte) error {
	var s *string
	if err := json.Unmarshal(data, &s); err != nil {
		return err
	}
	if s != nil {
		ns.Valid = true
		ns.String = *s
	} else {
		ns.Valid = false
	}
	return nil
}

// Input structs for API requests
type CreateYourEntityInput struct {
	Name     string `json:"name"`
	IsActive *bool  `json:"is_active,omitempty"`
}

type UpdateYourEntityInput struct {
	Name     *string `json:"name,omitempty"`
	IsActive *bool   `json:"is_active,omitempty"`
}
```

### Step 2: Create Handler (`backend/handlers/your_handler.go`)

```go
package handlers

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"
	"time"

	"github.com/mkyousafali/Aqura/backend/cache"
	"github.com/mkyousafali/Aqura/backend/database"
	"github.com/mkyousafali/Aqura/backend/models"
)

// ========================================
// GET ALL - With Caching
// ========================================
func GetYourEntities(w http.ResponseWriter, r *http.Request) {
	// Try cache first
	cacheKey := "your_entities:all"
	if cachedData, found := cache.Get(cacheKey); found {
		w.Header().Set("X-Cache", "HIT")
		respondWithJSON(w, http.StatusOK, cachedData)
		return
	}

	db := database.GetDB()

	query := `
		SELECT id, name, is_active, created_at, updated_at
		FROM your_table
		WHERE is_active = true
		ORDER BY id ASC
	`

	rows, err := db.Query(query)
	if err != nil {
		respondWithError(w, http.StatusInternalServerError, fmt.Sprintf("Database error: %v", err))
		return
	}
	defer rows.Close()

	entities := []models.YourEntity{}
	for rows.Next() {
		var entity models.YourEntity
		err := rows.Scan(
			&entity.ID,
			&entity.Name,
			&entity.IsActive,
			&entity.CreatedAt,
			&entity.UpdatedAt,
		)
		if err != nil {
			respondWithError(w, http.StatusInternalServerError, fmt.Sprintf("Scan error: %v", err))
			return
		}
		entities = append(entities, entity)
	}

	// Cache for 5 minutes
	cache.Set(cacheKey, entities, 5*time.Minute)
	w.Header().Set("X-Cache", "MISS")
	
	respondWithJSON(w, http.StatusOK, entities)
}

// ========================================
// GET ONE - By ID
// ========================================
func GetYourEntity(w http.ResponseWriter, r *http.Request) {
	// Extract ID from URL
	idStr := r.URL.Path[len("/api/your-entities/"):]
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		respondWithError(w, http.StatusBadRequest, "Invalid ID")
		return
	}

	db := database.GetDB()

	query := `
		SELECT id, name, is_active, created_at, updated_at
		FROM your_table
		WHERE id = $1
	`

	var entity models.YourEntity
	err = db.QueryRow(query, id).Scan(
		&entity.ID,
		&entity.Name,
		&entity.IsActive,
		&entity.CreatedAt,
		&entity.UpdatedAt,
	)

	if err == sql.ErrNoRows {
		respondWithError(w, http.StatusNotFound, "Entity not found")
		return
	}
	if err != nil {
		respondWithError(w, http.StatusInternalServerError, fmt.Sprintf("Database error: %v", err))
		return
	}

	respondWithJSON(w, http.StatusOK, entity)
}

// ========================================
// CREATE - With Cache Invalidation
// ========================================
func CreateYourEntity(w http.ResponseWriter, r *http.Request) {
	var input models.CreateYourEntityInput
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		respondWithError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	// Validate required fields
	if input.Name == "" {
		respondWithError(w, http.StatusBadRequest, "Missing required fields")
		return
	}

	db := database.GetDB()

	query := `
		INSERT INTO your_table (name, is_active)
		VALUES ($1, $2)
		RETURNING id, created_at
	`

	var entity models.YourEntity
	entity.Name = input.Name

	// Set defaults
	isActive := true
	if input.IsActive != nil {
		isActive = *input.IsActive
	}

	err := db.QueryRow(query, input.Name, isActive).Scan(&entity.ID, &entity.CreatedAt)

	if err != nil {
		respondWithError(w, http.StatusInternalServerError, fmt.Sprintf("Failed to create: %v", err))
		return
	}

	// Invalidate cache
	cache.Invalidate("your_entities:all")

	respondWithJSON(w, http.StatusCreated, entity)
}

// ========================================
// UPDATE - With Cache Invalidation
// ========================================
func UpdateYourEntity(w http.ResponseWriter, r *http.Request) {
	// Extract ID from URL
	idStr := r.URL.Path[len("/api/your-entities/"):]
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		respondWithError(w, http.StatusBadRequest, "Invalid ID")
		return
	}

	var input models.UpdateYourEntityInput
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		respondWithError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	db := database.GetDB()

	// Build dynamic update query
	query := "UPDATE your_table SET updated_at = NOW()"
	args := []interface{}{}
	argPos := 1

	if input.Name != nil {
		query += fmt.Sprintf(", name = $%d", argPos)
		args = append(args, *input.Name)
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
		respondWithError(w, http.StatusInternalServerError, fmt.Sprintf("Failed to update: %v", err))
		return
	}

	rowsAffected, _ := result.RowsAffected()
	if rowsAffected == 0 {
		respondWithError(w, http.StatusNotFound, "Entity not found")
		return
	}

	// Invalidate cache
	cache.Invalidate("your_entities:all")

	respondWithJSON(w, http.StatusOK, map[string]string{"message": "Updated successfully"})
}

// ========================================
// DELETE - Soft Delete with Cache Invalidation
// ========================================
func DeleteYourEntity(w http.ResponseWriter, r *http.Request) {
	// Extract ID from URL
	idStr := r.URL.Path[len("/api/your-entities/"):]
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		respondWithError(w, http.StatusBadRequest, "Invalid ID")
		return
	}

	db := database.GetDB()

	query := "UPDATE your_table SET is_active = false, updated_at = NOW() WHERE id = $1"
	result, err := db.Exec(query, id)
	if err != nil {
		respondWithError(w, http.StatusInternalServerError, fmt.Sprintf("Failed to delete: %v", err))
		return
	}

	rowsAffected, _ := result.RowsAffected()
	if rowsAffected == 0 {
		respondWithError(w, http.StatusNotFound, "Entity not found")
		return
	}

	// Invalidate cache
	cache.Invalidate("your_entities:all")

	respondWithJSON(w, http.StatusOK, map[string]string{"message": "Deleted successfully"})
}

// ========================================
// Helper Functions
// ========================================
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
```

### Step 3: Add Routes (`backend/main.go`)

```go
// Import your handler
import (
	"github.com/mkyousafali/Aqura/backend/handlers"
)

func main() {
	// ... existing code ...

	// Your entity routes
	http.HandleFunc("/api/your-entities", func(w http.ResponseWriter, r *http.Request) {
		enableCORS(w, r)
		if r.Method == "OPTIONS" {
			return
		}
		switch r.Method {
		case "GET":
			handlers.GetYourEntities(w, r)
		case "POST":
			handlers.CreateYourEntity(w, r)
		default:
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		}
	})

	http.HandleFunc("/api/your-entities/", func(w http.ResponseWriter, r *http.Request) {
		enableCORS(w, r)
		if r.Method == "OPTIONS" {
			return
		}
		switch r.Method {
		case "GET":
			handlers.GetYourEntity(w, r)
		case "PUT":
			handlers.UpdateYourEntity(w, r)
		case "DELETE":
			handlers.DeleteYourEntity(w, r)
		default:
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		}
	})

	// ... rest of code ...
}
```

---

## Frontend Integration

### Step 1: Add to `frontend/src/lib/utils/goAPI.ts`

```typescript
// Add inside goAPI object
yourEntities: {
  /**
   * Get all entities with caching and fallback
   */
  async getAll(useCache = true) {
    const cacheKey = 'your_entities:all';
    
    // Try cache first
    if (useCache) {
      const cached = getCached(cacheKey);
      if (cached) {
        console.log('✅ Loaded entities from client cache');
        return { data: cached, error: null };
      }
    }
    
    // Check backend health
    const isHealthy = await checkBackendHealth();
    
    try {
      if (isHealthy && USE_GO_BACKEND) {
        // Try Go backend
        const data = await goFetch('/api/your-entities');
        setCache(cacheKey, data);
        console.log('✅ Loaded entities from Go backend');
        return { data, error: null };
      } else {
        // Supabase fallback
        const { data, error } = await supabase
          .from('your_table')
          .select('*')
          .eq('is_active', true)
          .order('id', { ascending: true });
        if (error) throw error;
        setCache(cacheKey, data);
        console.log('✅ Loaded entities from Supabase (fallback)');
        return { data, error: null };
      }
    } catch (error: any) {
      // Fallback on error
      console.warn('⚠️ Go backend failed, trying Supabase fallback:', error.message);
      try {
        const { data, error: fbError } = await supabase
          .from('your_table')
          .select('*')
          .eq('is_active', true)
          .order('id', { ascending: true });
        if (fbError) throw fbError;
        setCache(cacheKey, data);
        backendHealthy = false;
        console.log('✅ Loaded entities from Supabase (fallback after error)');
        return { data, error: null };
      } catch (fallbackError: any) {
        console.error('❌ Both Go backend and Supabase failed:', fallbackError);
        return { data: null, error: { message: fallbackError.message } };
      }
    }
  },

  /**
   * Get single entity by ID
   */
  async getById(id: string | number) {
    const cacheKey = `your_entities:${id}`;
    const cached = getCached(cacheKey);
    if (cached) return { data: cached, error: null };
    
    const isHealthy = await checkBackendHealth();
    
    try {
      if (isHealthy && USE_GO_BACKEND) {
        const data = await goFetch(`/api/your-entities/${id}`);
        setCache(cacheKey, data);
        return { data, error: null };
      } else {
        const { data, error } = await supabase
          .from('your_table')
          .select('*')
          .eq('id', id)
          .single();
        if (error) throw error;
        setCache(cacheKey, data);
        return { data, error: null };
      }
    } catch (error: any) {
      try {
        const { data, error: fbError } = await supabase
          .from('your_table')
          .select('*')
          .eq('id', id)
          .single();
        if (fbError) throw fbError;
        setCache(cacheKey, data);
        backendHealthy = false;
        return { data, error: null };
      } catch (fallbackError: any) {
        return { data: null, error: { message: fallbackError.message } };
      }
    }
  },

  /**
   * Create new entity
   */
  async create(entity: any) {
    const isHealthy = await checkBackendHealth();
    
    try {
      if (isHealthy && USE_GO_BACKEND) {
        const data = await goFetch('/api/your-entities', {
          method: 'POST',
          body: JSON.stringify(entity),
        });
        invalidateCache('your_entities');
        return { data, error: null };
      } else {
        const { data, error } = await supabase
          .from('your_table')
          .insert([entity])
          .select()
          .single();
        if (error) throw error;
        invalidateCache('your_entities');
        return { data, error: null };
      }
    } catch (error: any) {
      try {
        const { data, error: fbError } = await supabase
          .from('your_table')
          .insert([entity])
          .select()
          .single();
        if (fbError) throw fbError;
        invalidateCache('your_entities');
        backendHealthy = false;
        return { data, error: null };
      } catch (fallbackError: any) {
        return { data: null, error: { message: fallbackError.message } };
      }
    }
  },

  /**
   * Update entity
   */
  async update(id: string | number, updates: any) {
    const isHealthy = await checkBackendHealth();
    
    try {
      if (isHealthy && USE_GO_BACKEND) {
        const data = await goFetch(`/api/your-entities/${id}`, {
          method: 'PUT',
          body: JSON.stringify(updates),
        });
        invalidateCache('your_entities');
        return { data, error: null };
      } else {
        const { data, error } = await supabase
          .from('your_table')
          .update(updates)
          .eq('id', id)
          .select()
          .single();
        if (error) throw error;
        invalidateCache('your_entities');
        return { data, error: null };
      }
    } catch (error: any) {
      try {
        const { data, error: fbError } = await supabase
          .from('your_table')
          .update(updates)
          .eq('id', id)
          .select()
          .single();
        if (fbError) throw fbError;
        invalidateCache('your_entities');
        backendHealthy = false;
        return { data, error: null };
      } catch (fallbackError: any) {
        return { data: null, error: { message: fallbackError.message } };
      }
    }
  },

  /**
   * Delete entity (soft delete)
   */
  async delete(id: string | number) {
    const isHealthy = await checkBackendHealth();
    
    try {
      if (isHealthy && USE_GO_BACKEND) {
        const data = await goFetch(`/api/your-entities/${id}`, {
          method: 'DELETE',
        });
        invalidateCache('your_entities');
        return { data, error: null };
      } else {
        const { data, error } = await supabase
          .from('your_table')
          .update({ is_active: false })
          .eq('id', id)
          .select()
          .single();
        if (error) throw error;
        invalidateCache('your_entities');
        return { data, error: null };
      }
    } catch (error: any) {
      try {
        const { data, error: fbError } = await supabase
          .from('your_table')
          .update({ is_active: false })
          .eq('id', id)
          .select()
          .single();
        if (fbError) throw fbError;
        invalidateCache('your_entities');
        backendHealthy = false;
        return { data, error: null };
      } catch (fallbackError: any) {
        return { data: null, error: { message: fallbackError.message } };
      }
    }
  },
},
```

### Step 2: Update Component

```typescript
// In your Svelte component
import { goAPI } from '$lib/utils/goAPI';

async function loadData() {
  const startTime = performance.now();
  isLoading = true;
  
  try {
    const { data, error } = await goAPI.yourEntities.getAll();
    const loadTime = Math.round(performance.now() - startTime);
    
    if (error) {
      errorMessage = error.message;
    } else {
      entities = data;
      console.log(`✅ Loaded ${data.length} entities in ${loadTime}ms`);
    }
  } catch (error) {
    errorMessage = 'Failed to load data';
  } finally {
    isLoading = false;
  }
}
```

---

## Running Local Development

### Option 1: Manual (Two Terminals)

**Terminal 1 - Backend:**
```powershell
cd D:\Aqura\backend
go run main.go
```

**Terminal 2 - Frontend:**
```powershell
cd D:\Aqura\frontend
npm run dev
```

### Option 2: VS Code Tasks (Recommended)

Add to `.vscode/tasks.json`:

```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "🖥️ Dev Local Server",
      "type": "shell",
      "command": "go",
      "args": ["run", "main.go"],
      "options": {
        "cwd": "${workspaceFolder}/backend"
      },
      "isBackground": true,
      "problemMatcher": {
        "pattern": {
          "regexp": "^(.*):(\\d+):(\\d+):\\s+(warning|error):\\s+(.*)$",
          "file": 1,
          "line": 2,
          "column": 3,
          "severity": 4,
          "message": 5
        },
        "background": {
          "activeOnStart": true,
          "beginsPattern": "^Starting server",
          "endsPattern": "^.*Server listening on"
        }
      },
      "group": "build",
      "presentation": {
        "reveal": "always",
        "panel": "dedicated",
        "group": "backend"
      }
    },
    {
      "label": "🎨 Dev Frontend (npm)",
      "type": "shell",
      "command": "npm",
      "args": ["run", "dev"],
      "options": {
        "cwd": "${workspaceFolder}/frontend"
      },
      "isBackground": true,
      "problemMatcher": {
        "pattern": {
          "regexp": "^([^\\s].*)\\((\\d+|\\d+,\\d+|\\d+,\\d+,\\d+,\\d+)\\):\\s+(error|warning|info)\\s+(TS\\d+)\\s*:\\s*(.*)$",
          "file": 1,
          "location": 2,
          "severity": 3,
          "code": 4,
          "message": 5
        },
        "background": {
          "activeOnStart": true,
          "beginsPattern": "^.*VITE.*",
          "endsPattern": "^.*Local:.*"
        }
      },
      "group": {
        "kind": "build",
        "isDefault": true
      },
      "presentation": {
        "reveal": "always",
        "panel": "dedicated",
        "group": "frontend"
      }
    },
    {
      "label": "🚀 Dev Full Stack",
      "dependsOn": [
        "🖥️ Dev Local Server",
        "🎨 Dev Frontend (npm)"
      ],
      "group": "build",
      "presentation": {
        "reveal": "always"
      }
    }
  ]
}
```

**Usage:**
1. Press `Ctrl+Shift+P`
2. Type "Run Task"
3. Select "🚀 Dev Full Stack"
4. Both servers start simultaneously!

**Access:**
- Frontend: http://localhost:5173
- Backend: http://localhost:8080
- Health Check: http://localhost:8080/health

---

## Testing

### Test Backend Endpoints

```powershell
# Health check
curl http://localhost:8080/health

# Get all (should show X-Cache: MISS first time)
curl http://localhost:8080/api/your-entities

# Get all again (should show X-Cache: HIT)
curl http://localhost:8080/api/your-entities

# Get one
curl http://localhost:8080/api/your-entities/1

# Create
curl -X POST http://localhost:8080/api/your-entities `
  -H "Content-Type: application/json" `
  -d '{"name":"Test","is_active":true}'

# Update
curl -X PUT http://localhost:8080/api/your-entities/1 `
  -H "Content-Type: application/json" `
  -d '{"name":"Updated Name"}'

# Delete
curl -X DELETE http://localhost:8080/api/your-entities/1
```

### Test Frontend Console

Open browser console (F12) and look for:
```
✅ Loaded entities from client cache
✅ Loaded entities from Go backend
✅ Loaded entities from Supabase (fallback)
⚠️ Go backend unreachable, using Supabase fallback
```

---

## Checklist for Each Entity

### Backend
- [ ] Create model in `backend/models/`
- [ ] Create handler in `backend/handlers/`
- [ ] Add routes in `backend/main.go`
- [ ] Add cache with 5min TTL
- [ ] Invalidate cache on CREATE/UPDATE/DELETE
- [ ] Add proper error handling
- [ ] Test all endpoints with curl

### Frontend
- [ ] Add API methods to `goAPI` object
- [ ] Include health check before each request
- [ ] Implement Supabase fallback for all operations
- [ ] Add client-side caching
- [ ] Invalidate cache on mutations
- [ ] Add console logging for debugging
- [ ] Update component to use goAPI

### Testing
- [ ] Test cache HIT/MISS headers
- [ ] Test with Go backend running
- [ ] Test with Go backend stopped (fallback)
- [ ] Test CREATE/UPDATE/DELETE operations
- [ ] Verify cache invalidation works
- [ ] Check console logs

---

## Performance Targets

| Scenario | Target Time | Cache Layer |
|----------|-------------|-------------|
| First load (cold) | 500-800ms | Database query |
| Backend cached | 50-100ms | Go memory cache |
| Client cached | 5-15ms | Browser memory |
| Fallback mode | 500-800ms | Direct Supabase |

---

## Common Patterns

### NullString for Optional Fields
```go
VatNumber NullString `json:"vat_number"`
```

### Dynamic Updates
```go
if input.Field != nil {
    query += fmt.Sprintf(", field = $%d", argPos)
    args = append(args, *input.Field)
    argPos++
}
```

### Cache Keys
- List: `"entity:all"`
- Single: `"entity:{id}"`
- Filtered: `"entity:branch:{branchId}"`

### Error Responses
```go
respondWithError(w, http.StatusBadRequest, "Message")
```

---

## Quick Start Commands

```powershell
# Clone and setup
cd D:\Aqura

# Backend setup
cd backend
go mod tidy
go run main.go

# Frontend setup (new terminal)
cd D:\Aqura\frontend
npm install
npm run dev

# Or use VS Code task: "🚀 Dev Full Stack"
```

---

## Environment Variables

### Backend (.env)
```env
DATABASE_URL=postgresql://user:pass@host:port/db
PORT=8080
ENVIRONMENT=development
```

### Frontend (.env)
```env
VITE_GO_API_URL=http://localhost:8080
VITE_USE_GO_BACKEND=true
```

---

## Deployment

When ready to deploy:
1. Push to master branch
2. Railway auto-builds Go backend
3. Vercel auto-builds frontend
4. Update Vercel env vars if needed

---

**Reference Implementation:** See `backend/handlers/branches.go` and `frontend/src/lib/utils/goAPI.ts` branches section for complete working example.

---

## Component List - Ready for Implementation

### Master Data
- [ ] **Vendor Master** - `vendors` table
- [ ] **Product Master** - `products` table  
- [ ] **Product Categories** - `product_categories` table
- [ ] **Employee Master** - `hr_employees` table
- [ ] **Position Master** - `hr_positions` table
- [ ] **Department Master** - `departments` table
- [ ] **User Management** - `users` table

### Operations
- [ ] **Receiving Records** - `receiving_records` table
- [ ] **Purchase Orders** - `purchase_orders` table
- [ ] **Stock Management** - `stock_items` table
- [ ] **Inventory** - `inventory` table

### HR
- [ ] **Attendance/Fingerprint** - `hr_fingerprint_data` table
- [ ] **Assignments** - `hr_assignments` table
- [ ] **Contacts** - `hr_contacts` table
- [ ] **Documents** - `hr_documents` table

### Finance
- [ ] **Expense Scheduler** - `expense_scheduler` table
- [ ] **Payment Tracking** - `payment_tracking` table

### Tasks
- [ ] **Task Assignments** - `task_assignments` table
- [ ] **Quick Tasks** - `quick_task_assignments` table
- [ ] **Receiving Tasks** - `receiving_tasks` table

### Communication
- [ ] **Notifications** - `notifications` table
- [ ] **Push Queue** - `push_notification_queue` table

---

## How to Request Implementation

**Template:**
```
Implement Go backend for [Component Name]

Details:
- Table: [table_name]
- Component: [path/to/component.svelte]
- Operations: GET all, GET by ID, CREATE, UPDATE, DELETE
- Special: [any custom requirements]
```

**Example:**
```
Implement Go backend for Vendor Master

Details:
- Table: vendors
- Component: frontend/src/lib/components/desktop-interface/master/VendorMaster.svelte
- Operations: GET all, GET by ID, CREATE, UPDATE, DELETE
- Special: Need to filter by branch_id
```

Copilot will handle everything automatically following the established patterns!
