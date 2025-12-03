# Go Backend Implementation Guide

Complete reference for implementing Go backend endpoints with caching, fallback, and error handling.

## 🚀 Quick Start - Implement Any Component

**Ready to implement Go backend for a component?**

### Simple Command:
Just say: **"Implement Go backend for [Component Name]"**

### ⚠️ CRITICAL FIRST STEP - Provide Table Schema:
**BEFORE implementing, you MUST provide the exact table schema.**

**How to Get Schema:**
1. Run: `node scripts/create-schema-md.js`
2. Open generated `DATABASE_SCHEMA.md`
3. Find your table section
4. Copy ONLY that table's schema (including all columns)
5. Paste it in your request

**Example Request:**
```
Implement Go backend for Sales Report

Table Schema:
## erp_daily_sales
**Total Columns:** 16
| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| id | uuid | ✗ No | uuid_generate_v4() |
| branch_id | bigint | ✗ No | - |
| sale_date | date | ✗ No | - |
| total_bills | integer | ✓ Yes | 0 |
| gross_amount | numeric | ✓ Yes | 0 |
... (rest of columns)
```

### What Happens Automatically:
1. ✅ **Schema Validation** - Verifies table structure from your provided schema
2. ✅ **Backend Model** - Creates `backend/models/[entity].go` with proper types matching exact schema
3. ✅ **Backend Handler** - Creates `backend/handlers/[entity].go` with:
   - GET all (with 5min cache)
   - GET by ID
   - CREATE (invalidates cache)
   - UPDATE (invalidates cache)  
   - DELETE/soft delete (invalidates cache)
4. ✅ **Routes** - Adds to `backend/main.go` with CORS
5. ✅ **Frontend API** - Adds to `frontend/src/lib/utils/goAPI.ts` with:
   - Client-side caching
   - Health check before requests
   - Automatic Supabase fallback
   - Error handling
6. ✅ **Component Update** - Updates your Svelte component to use Go API
7. ✅ **Testing** - Validates all endpoints work
8. ✅ **Deployment** - Commits and pushes to Railway/Vercel

### Complete Example Request:
```
Implement Go backend for Sales Report

Table: erp_daily_sales
Component: frontend/src/routes/mobile-interface/reports/+page.svelte

Table Schema (from DATABASE_SCHEMA.md):
## erp_daily_sales
**Total Columns:** 16
| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| id | uuid | ✗ No | uuid_generate_v4() |
| branch_id | bigint | ✗ No | - |
| sale_date | date | ✗ No | - |
| total_bills | integer | ✓ Yes | 0 |
| gross_amount | numeric | ✓ Yes | 0 |
| tax_amount | numeric | ✓ Yes | 0 |
| discount_amount | numeric | ✓ Yes | 0 |
| total_returns | integer | ✓ Yes | 0 |
| return_amount | numeric | ✓ Yes | 0 |
| return_tax | numeric | ✓ Yes | 0 |
| net_bills | integer | ✓ Yes | 0 |
| net_amount | numeric | ✓ Yes | 0 |
| net_tax | numeric | ✓ Yes | 0 |
| last_sync_at | timestamp with time zone | ✓ Yes | - |
| created_at | timestamp with time zone | ✓ Yes | now() |
| updated_at | timestamp with time zone | ✓ Yes | now() |

Operations: GET all (with date filtering), GET by branch
```

### Why Schema is Required:
- ✅ **Accurate Types** - Maps PostgreSQL types to Go types correctly
- ✅ **Nullable Fields** - Uses NullString/NullInt64 for nullable columns
- ✅ **Default Values** - Handles defaults properly in INSERT operations
- ✅ **No Assumptions** - Prevents errors from guessing column names/types
- ✅ **Future-Proof** - Works even if schema changes

### Current Status:
- ✅ **Branch Master** - Fully implemented with caching & fallback
- ⏳ **All others** - Ready for implementation

---

## Table of Contents
1. [Quick Start](#quick-start---implement-any-component)
2. [Backend Structure](#backend-structure)
3. [Handler Implementation](#handler-implementation)
4. [PostgreSQL LISTEN/NOTIFY](#postgresql-listennotify---automatic-cache-updates)
5. [Frontend Integration](#frontend-integration)
6. [Running Local Development](#running-local-development)
7. [Testing](#testing)
8. [Component List](#component-list-ready-for-implementation)

---

## Backend Structure

### File Organization (Interface-Based)
```
backend/
├── main.go                           # Routes and server setup
├── cache/
│   └── cache.go                     # In-memory cache (5min TTL)
├── database/
│   └── supabase.go                  # Database connection
├── handlers/                         # API handlers by interface
│   ├── desktop-interface/           # Desktop admin handlers
│   │   └── branches.go              # Example: Branch Master
│   ├── mobile-interface/            # Mobile employee handlers
│   │   └── dashboard.go             # Example: Mobile Dashboard
│   ├── customer-interface/          # Customer app handlers
│   └── cashier-interface/           # Cashier POS handlers
├── models/                           # Data models by interface
│   ├── common.go                    # Shared types (NullString, etc.)
│   ├── desktop-interface/           # Desktop admin models
│   │   └── branch.go                # Example: Branch model
│   ├── mobile-interface/            # Mobile employee models
│   │   └── dashboard.go             # Example: Dashboard model
│   ├── customer-interface/          # Customer app models
│   └── cashier-interface/           # Cashier POS models
└── middleware/
    └── auth.go                      # JWT authentication
```

**Organization Rules:**
- ✅ **Organize by interface** - Match frontend structure exactly
- ✅ **Common types** - Use `models/common.go` for shared types
- ✅ **Package naming** - Use `package desktopinterface`, `package mobileinterface`, etc.
- ✅ **Import paths** - Use full paths like `github.com/mkyousafali/Aqura/backend/models/desktop-interface`

---

## Handler Implementation

### Step 1: Create Model (Example: `backend/models/desktop-interface/entity.go`)

**Determine Interface Type First:**
- Desktop admin component? → `backend/models/desktop-interface/`
- Mobile employee component? → `backend/models/mobile-interface/`
- Customer app component? → `backend/models/customer-interface/`
- Cashier POS component? → `backend/models/cashier-interface/`

```go
// Example for desktop-interface
package desktopinterface

import (
	"database/sql"
	"time"

	"github.com/mkyousafali/Aqura/backend/models"
)

// Main struct
type YourEntity struct {
	ID        int64            `json:"id"`
	Name      string           `json:"name"`
	IsActive  bool             `json:"is_active"`
	CreatedAt time.Time        `json:"created_at"`
	UpdatedAt time.Time        `json:"updated_at"`
	VatNumber models.NullString `json:"vat_number,omitempty"` // Use shared NullString
}

// Input structs for API requests
type CreateYourEntityInput struct {
	Name     string  `json:"name"`
	IsActive *bool   `json:"is_active,omitempty"`
	VatNumber *string `json:"vat_number,omitempty"`
}

type UpdateYourEntityInput struct {
	Name     *string `json:"name,omitempty"`
	IsActive *bool   `json:"is_active,omitempty"`
	VatNumber *string `json:"vat_number,omitempty"`
}
```

**Note:** Use `models.NullString` from `backend/models/common.go` for nullable string fields.

### Step 2: Create Handler (Example: `backend/handlers/desktop-interface/entity.go`)

**Match the model's interface folder:**
- Model in `desktop-interface/`? → Handler in `desktop-interface/`
- Model in `mobile-interface/`? → Handler in `mobile-interface/`
- Model in `customer-interface/`? → Handler in `customer-interface/`
- Model in `cashier-interface/`? → Handler in `cashier-interface/`

```go
// Example for desktop-interface
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

	entities := []desktopmodels.YourEntity{}
	for rows.Next() {
		var entity desktopmodels.YourEntity
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

	var entity desktopmodels.YourEntity
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
	var input desktopmodels.CreateYourEntityInput
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

	var entity desktopmodels.YourEntity
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

	var input desktopmodels.UpdateYourEntityInput
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

**CRITICAL: Always include proper CORS and OPTIONS handling:**

```go
// Import handlers by interface
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
	// Add other interfaces as needed
)

func main() {
	// ... existing code ...

	// Desktop interface routes (example)
	http.HandleFunc("/api/your-entities", func(w http.ResponseWriter, r *http.Request) {
		enableCORS(w, r)
		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)  // ⚠️ CRITICAL: Must return 200 OK for OPTIONS
			return
		}
		switch r.Method {
		case "GET":
			desktophandlers.GetYourEntities(w, r)
		case "POST":
			desktophandlers.CreateYourEntity(w, r)
		default:
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		}
	})

	http.HandleFunc("/api/your-entities/", func(w http.ResponseWriter, r *http.Request) {
		enableCORS(w, r)
		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)  // ⚠️ CRITICAL: Must return 200 OK for OPTIONS
			return
		}
		switch r.Method {
		case "GET":
			desktophandlers.GetYourEntity(w, r)
		case "PUT":
			desktophandlers.UpdateYourEntity(w, r)
		case "DELETE":
			desktophandlers.DeleteYourEntity(w, r)
		default:
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		}
	})

	// ... rest of code ...
}

// ⚠️ CRITICAL: enableCORS function must set proper headers
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
```

**CORS Checklist:**
- ✅ Call `enableCORS(w, r)` before checking method
- ✅ Return `http.StatusOK` for OPTIONS requests
- ✅ Set `Access-Control-Allow-Origin` header
- ✅ Set `Access-Control-Allow-Credentials: true`
- ✅ Include `apikey` in allowed headers for Supabase compatibility

---

## PostgreSQL LISTEN/NOTIFY - Automatic Cache Updates

### Overview
PostgreSQL LISTEN/NOTIFY enables **real-time automatic cache invalidation** across all Go backend instances when database changes occur. No manual cache invalidation needed!

**How It Works:**
1. User modifies data → PostgreSQL trigger fires
2. Trigger sends NOTIFY to channel (e.g., `branches_changed`)
3. Go backend listener receives notification
4. Cache automatically invalidates
5. Next request fetches fresh data

**Benefits:**
- ✅ Zero polling overhead
- ✅ Real-time updates (< 100ms latency)
- ✅ Works across multiple backend instances
- ✅ Automatic - no manual cache management
- ✅ Database-driven consistency

### Step 1: Database Trigger (Supabase SQL Editor)

Create PostgreSQL trigger for your table:

```sql
-- Function that sends notification when table changes
CREATE OR REPLACE FUNCTION notify_your_table_change() 
RETURNS trigger AS $$
BEGIN
    PERFORM pg_notify(
        'your_table_changed',
        json_build_object(
            'operation', TG_OP,
            'id', COALESCE(NEW.id, OLD.id),
            'timestamp', NOW()
        )::text
    );
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Trigger on INSERT, UPDATE, DELETE
CREATE TRIGGER your_table_notify_trigger
AFTER INSERT OR UPDATE OR DELETE ON your_table
FOR EACH ROW EXECUTE FUNCTION notify_your_table_change();
```

**Real Example (Branches):**
```sql
-- Branches notification function
CREATE OR REPLACE FUNCTION notify_branches_change() 
RETURNS trigger AS $$
BEGIN
    PERFORM pg_notify(
        'branches_changed',
        json_build_object(
            'operation', TG_OP,
            'id', COALESCE(NEW.id, OLD.id),
            'timestamp', NOW()
        )::text
    );
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Trigger on branches table
CREATE TRIGGER branches_notify_trigger
AFTER INSERT OR UPDATE OR DELETE ON branches
FOR EACH ROW EXECUTE FUNCTION notify_branches_change();
```

### Step 2: Backend Listener Setup (Already Done)

The notification listener is already configured in `backend/database/supabase.go` and `backend/main.go`. It will automatically listen to your channels.

**Current Channels:**
- `branches_changed` - Branch table updates
- `cache_invalidate` - Generic cache invalidation

### Step 3: Add Your Channel to Listener

Update `backend/database/supabase.go` to subscribe to your channel:

```go
func StartNotificationListener(callback NotificationCallback) error {
    // ... existing code ...

    // Subscribe to channels
    listener.Listen("branches_changed")
    listener.Listen("your_table_changed")  // ← Add your channel
    listener.Listen("cache_invalidate")

    // ... rest of code ...
}
```

### Step 4: Handle Notification in main.go

Update `handleDatabaseNotification` function in `backend/main.go`:

```go
func handleDatabaseNotification(channel string, payload string) {
    log.Printf("📢 Received notification on channel: %s | Payload: %s", channel, payload)

    switch channel {
    case "branches_changed":
        cache.Invalidate("branches:all")
        log.Printf("🔄 Cache invalidated for branches (trigger: database change)")

    case "your_table_changed":  // ← Add your handler
        cache.Invalidate("your_entities:all")
        log.Printf("🔄 Cache invalidated for your_entities (trigger: database change)")

    case "cache_invalidate":
        // Generic invalidation with JSON payload
        if payload != "" {
            var data map[string]interface{}
            if err := json.Unmarshal([]byte(payload), &data); err == nil {
                if key, ok := data["key"].(string); ok {
                    cache.Invalidate(key)
                    log.Printf("🔄 Cache invalidated: %s", key)
                }
            }
        }

    default:
        log.Printf("⚠️  Unknown notification channel: %s", channel)
    }
}
```

### Step 5: Remove Manual Cache Invalidation (Optional)

Since cache now invalidates automatically via triggers, you can remove manual invalidation from handlers:

**Before (Manual Invalidation):**
```go
func CreateYourEntity(w http.ResponseWriter, r *http.Request) {
    // ... insert logic ...
    
    cache.Invalidate("your_entities:all")  // ← Can remove this!
    
    respondWithJSON(w, http.StatusCreated, entity)
}
```

**After (Automatic via Trigger):**
```go
func CreateYourEntity(w http.ResponseWriter, r *http.Request) {
    // ... insert logic ...
    
    // No manual invalidation needed - trigger handles it!
    
    respondWithJSON(w, http.StatusCreated, entity)
}
```

**Note:** You can keep manual invalidation as a backup or for immediate consistency before the trigger fires.

### Testing LISTEN/NOTIFY

1. **Start Go Backend:**
   ```powershell
   cd D:\Aqura\backend
   go run main.go
   ```
   
   Look for: `🎧 PostgreSQL notification listener started`

2. **Trigger Database Change:**
   ```sql
   -- In Supabase SQL Editor
   UPDATE branches SET name_en = 'Updated Branch' WHERE id = 1;
   ```

3. **Check Backend Logs:**
   ```
   📢 Received notification on channel: branches_changed | Payload: {"operation":"UPDATE","id":1,"timestamp":"2025-12-02T..."}
   🔄 Cache invalidated for branches (trigger: database change)
   ```

4. **Verify Cache Invalidated:**
   ```powershell
   # Next request will be cache MISS
   curl http://localhost:8080/api/branches
   # Response header: X-Cache: MISS
   
   # Second request will be cache HIT
   curl http://localhost:8080/api/branches
   # Response header: X-Cache: HIT
   ```

### Multi-Instance Support

**Scenario:** Multiple Go backend instances (Railway, local dev, etc.)

**How It Works:**
- Each instance connects to PostgreSQL with its own listener
- When database changes, ALL instances receive notification
- ALL caches invalidate simultaneously
- Perfect consistency across all servers!

**Example Flow:**
```
User A → Railway Backend → Insert Branch → PostgreSQL Trigger
                                             |
                                             ├─ NOTIFY "branches_changed"
                                             |
                              ┌──────────────┴──────────────┐
                              ↓                              ↓
                    Railway Listener                 Local Dev Listener
                    Invalidate Cache                 Invalidate Cache
                              ↓                              ↓
                    User B gets fresh data          Developer sees update
```

### Generic Cache Invalidation Channel

For advanced use cases, use the `cache_invalidate` channel with custom payloads:

**SQL Trigger with Custom Key:**
```sql
CREATE OR REPLACE FUNCTION notify_custom_cache() 
RETURNS trigger AS $$
BEGIN
    PERFORM pg_notify(
        'cache_invalidate',
        json_build_object('key', 'custom:cache:key')::text
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

**Backend automatically handles it:**
```go
case "cache_invalidate":
    // Parses JSON and invalidates the specified key
    cache.Invalidate(key)  // key from payload["key"]
```

### Troubleshooting

**Issue:** No notifications received

**Solutions:**
1. Check trigger exists:
   ```sql
   SELECT * FROM pg_trigger WHERE tgname = 'your_table_notify_trigger';
   ```

2. Check function exists:
   ```sql
   SELECT * FROM pg_proc WHERE proname = 'notify_your_table_change';
   ```

3. Test notification manually:
   ```sql
   SELECT pg_notify('your_table_changed', '{"test": true}');
   ```

4. Check backend logs for listener errors

5. Verify database connection is active (listener pings every 90s)

**Issue:** Listener disconnected

**Solution:** Automatic reconnection with exponential backoff (10s to 1min)

### Performance Impact

- **Database:** Near-zero overhead (trigger fires in microseconds)
- **Network:** Minimal (only sends notification when data changes)
- **Backend:** Negligible (single goroutine handles all notifications)
- **Latency:** < 100ms from database change to cache invalidation

### Best Practices

1. ✅ **One trigger per table** - Don't create multiple triggers on same table
2. ✅ **Use FOR EACH ROW** - Gets exact row that changed
3. ✅ **Include operation type** - Know if INSERT/UPDATE/DELETE
4. ✅ **Keep payload small** - Only essential data (id, timestamp)
5. ✅ **Test triggers thoroughly** - Ensure they don't block writes
6. ✅ **Monitor listener health** - Check logs for reconnection issues
7. ✅ **Graceful degradation** - Manual cache invalidation as backup

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
- [ ] Invalidate cache on CREATE/UPDATE/DELETE (or use LISTEN/NOTIFY)
- [ ] Add proper error handling
- [ ] Test all endpoints with curl

### PostgreSQL LISTEN/NOTIFY (Optional but Recommended)
- [ ] Create trigger function in Supabase SQL Editor
- [ ] Create trigger on table (AFTER INSERT/UPDATE/DELETE)
- [ ] Add channel to listener in `database/supabase.go`
- [ ] Add handler in `handleDatabaseNotification` in `main.go`
- [ ] Test notification by modifying data in Supabase
- [ ] Verify cache invalidation in backend logs
- [ ] (Optional) Remove manual cache invalidation from handlers

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

**Reference Implementation:** 
- Backend Model: `backend/models/desktop-interface/branch.go`
- Backend Handler: `backend/handlers/desktop-interface/branches.go`
- Frontend API: `frontend/src/lib/utils/goAPI.ts` branches section
- Common Types: `backend/models/common.go` (NullString)

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

Table: [table_name]
Component: [path/to/component.svelte]

Table Schema (from DATABASE_SCHEMA.md):
## [table_name]
**Total Columns:** [X]
| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| ... | ... | ... | ... |
(paste complete table schema here)

Operations: [GET all, GET by ID, CREATE, UPDATE, DELETE]
Special Requirements: [any custom requirements]
```

**Complete Example:**
```
Implement Go backend for Vendor Master

Table: vendors
Component: frontend/src/lib/components/desktop-interface/master/VendorMaster.svelte

Table Schema (from DATABASE_SCHEMA.md):
## vendors
**Total Columns:** 12
| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| id | bigint | ✗ No | nextval('vendors_id_seq'::regclass) |
| name_en | text | ✗ No | - |
| name_ar | text | ✓ Yes | - |
| vat_number | text | ✓ Yes | - |
| contact_person | text | ✓ Yes | - |
| phone | text | ✓ Yes | - |
| email | text | ✓ Yes | - |
| address | text | ✓ Yes | - |
| is_active | boolean | ✓ Yes | true |
| branch_id | bigint | ✓ Yes | - |
| created_at | timestamp with time zone | ✓ Yes | now() |
| updated_at | timestamp with time zone | ✓ Yes | now() |

Operations: GET all, GET by ID, CREATE, UPDATE, DELETE
Special Requirements: Filter by branch_id, support both English and Arabic names
```

**Important Notes:**
- ⚠️ **ALWAYS include complete table schema** - Copy from DATABASE_SCHEMA.md
- ⚠️ **Run schema generation first** - `node scripts/create-schema-md.js`
- ⚠️ **One table at a time** - Don't try to implement multiple tables in one request
- ⚠️ **Verify column names** - Schema ensures exact column names are used

Copilot will handle everything automatically following the established patterns!
