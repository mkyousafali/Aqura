# Table Structure and Relationships Analysis

**Date:** October 30, 2025  
**Database:** Aqura Supabase Project

---

## Table Structures

### 1. `users` Table
**Primary Key:** `id` (UUID)

#### Columns:
| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `username` | String | User login name |
| `password_hash` | String | Hashed password |
| `salt` | String | Password salt |
| `quick_access_code` | String | Quick login code |
| `quick_access_salt` | String | Quick access salt |
| `user_type` | String | Type of user (e.g., "branch_specific") |
| `employee_id` | UUID | **Foreign key to hr_employees.id** |
| `branch_id` | Integer | Branch identifier |
| `role_type` | String | Role type (e.g., "Position-based") |
| `position_id` | UUID | Position identifier |
| `avatar` | String/Null | Avatar URL |
| `avatar_small_url` | String/Null | Small avatar URL |
| `avatar_medium_url` | String/Null | Medium avatar URL |
| `avatar_large_url` | String/Null | Large avatar URL |
| `is_first_login` | Boolean | First login flag |
| `failed_login_attempts` | Integer | Count of failed logins |
| `locked_at` | Timestamp/Null | Account lock timestamp |
| `locked_by` | String/Null | Who locked the account |
| `last_login_at` | Timestamp | Last successful login |
| `password_expires_at` | Timestamp | Password expiration date |
| `last_password_change` | Timestamp | Last password change date |
| `created_by` | String/Null | Creator user ID |
| `updated_by` | String/Null | Last updater user ID |
| `created_at` | Timestamp | Record creation timestamp |
| `updated_at` | Timestamp | Last update timestamp |
| `status` | String | Account status (e.g., "active") |
| `ai_translation_enabled` | Boolean | AI translation feature flag |
| `can_approve_payments` | Boolean | Payment approval permission |
| `approval_amount_limit` | Number | Maximum approval amount |

#### Sample Data:
```json
{
  "id": "efa4aedd-867f-4223-b9e6-220375892c2d",
  "username": "Noorudheen",
  "employee_id": "f0bd7ba5-e783-4700-8a40-458d981e9d5b",
  "user_type": "branch_specific",
  "branch_id": 3,
  "role_type": "Position-based",
  "status": "active"
}
```

---

### 2. `hr_employees` Table
**Primary Key:** `id` (UUID)

#### Columns:
| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key (referenced by users.employee_id) |
| `employee_id` | String | Human-readable employee number |
| `name` | String | Employee full name |
| `branch_id` | Integer | Branch identifier |
| `hire_date` | Date/Null | Date of hire |
| `status` | String | Employment status (e.g., "active") |
| `created_at` | Timestamp | Record creation timestamp |

#### Sample Data:
```json
{
  "id": "f0bd7ba5-e783-4700-8a40-458d981e9d5b",
  "employee_id": "66",
  "name": "NOORUDHEEN نور الدين",
  "branch_id": 3,
  "status": "active"
}
```

---

### 3. `hr_employee_documents` Table
**Status:** Empty (no records found)

#### Expected Structure:
Based on naming conventions, this table likely stores:
- Employee document uploads
- Document types (ID, passport, certificates, etc.)
- File paths/URLs
- Metadata (upload date, expiry, etc.)

#### Probable Columns:
- `id` (UUID) - Primary key
- `employee_id` (UUID) - Foreign key to hr_employees.id
- `document_type` - Type of document
- `file_path` or `file_url` - Storage location
- `upload_date` - When uploaded
- `expiry_date` - Document expiration (if applicable)
- `status` - Document status
- `created_at`, `updated_at` - Timestamps

---

## Relationship Diagram

```
┌─────────────────────┐
│      users          │
│                     │
│  id (PK)           │
│  username          │
│  employee_id (FK) ──┼──────────┐
│  branch_id         │          │
│  role_type         │          │
│  status            │          │
│  ...               │          │
└─────────────────────┘          │
                                 │
                                 │ Foreign Key Relationship
                                 │ (users.employee_id → hr_employees.id)
                                 │
                                 ↓
                    ┌─────────────────────────┐
                    │    hr_employees         │
                    │                         │
                    │  id (PK)               │
                    │  employee_id (text)    │
                    │  name                  │
                    │  branch_id             │
                    │  hire_date             │
                    │  status                │
                    │  created_at            │
                    └─────────────────────────┘
                                 │
                                 │ Expected Foreign Key Relationship
                                 │ (hr_employee_documents.employee_id → hr_employees.id)
                                 │
                                 ↓
                    ┌─────────────────────────┐
                    │ hr_employee_documents   │
                    │                         │
                    │  id (PK)               │
                    │  employee_id (FK)      │
                    │  document_type         │
                    │  file_path/url         │
                    │  upload_date           │
                    │  status                │
                    │  ...                   │
                    └─────────────────────────┘
```

---

## Key Relationships

### 1. **users → hr_employees** (Many-to-One)
- **Foreign Key:** `users.employee_id` → `hr_employees.id`
- **Type:** UUID reference
- **Purpose:** Links user accounts to employee records
- **Verified:** ✅ Working relationship

**Example Query:**
```javascript
const { data } = await supabase
  .from('users')
  .select('id, username, employee_id, hr_employees(id, employee_id, name, branch_id)')
  .limit(3);
```

**Result:**
```json
{
  "id": "efa4aedd-867f-4223-b9e6-220375892c2d",
  "username": "Noorudheen",
  "employee_id": "f0bd7ba5-e783-4700-8a40-458d981e9d5b",
  "hr_employees": {
    "id": "f0bd7ba5-e783-4700-8a40-458d981e9d5b",
    "name": "NOORUDHEEN نور الدين",
    "branch_id": 3,
    "employee_id": "66"
  }
}
```

### 2. **hr_employees → hr_employee_documents** (One-to-Many)
- **Foreign Key:** `hr_employee_documents.employee_id` → `hr_employees.id` (expected)
- **Type:** UUID reference (expected)
- **Purpose:** Links employee documents to employee records
- **Status:** ⚠️ Table is empty, relationship cannot be verified

---

## Important Notes

### Dual Employee ID System
The database uses TWO types of employee IDs:

1. **`hr_employees.id`** (UUID)
   - Primary key in hr_employees table
   - Used as foreign key in users table
   - Example: `f0bd7ba5-e783-4700-8a40-458d981e9d5b`

2. **`hr_employees.employee_id`** (String/Text)
   - Human-readable employee number
   - Used for display and business logic
   - Example: `"66"`

### Usage in Code
When referencing employees:
- Use `hr_employees.id` (UUID) for database relationships
- Use `hr_employees.employee_id` (String) for user-facing displays

### Warning System Integration
The employee_warnings table should reference:
- `user_id` → `users.id`
- `employee_id` → `hr_employees.id` (UUID, not the text employee_id)

---

## Query Examples

### Get User with Employee Details
```javascript
const { data } = await supabase
  .from('users')
  .select(`
    id,
    username,
    employee_id,
    hr_employees (
      id,
      employee_id,
      name,
      branch_id,
      status
    )
  `)
  .eq('username', 'Noorudheen')
  .single();
```

### Get Employee with User Account
```javascript
const { data } = await supabase
  .from('hr_employees')
  .select(`
    id,
    employee_id,
    name,
    users (
      id,
      username,
      status,
      last_login_at
    )
  `)
  .eq('employee_id', '66')
  .single();
```

### Get Employee with Documents (when populated)
```javascript
const { data } = await supabase
  .from('hr_employees')
  .select(`
    id,
    employee_id,
    name,
    hr_employee_documents (
      id,
      document_type,
      file_url,
      upload_date
    )
  `)
  .eq('id', 'f0bd7ba5-e783-4700-8a40-458d981e9d5b')
  .single();
```

---

## Recommendations

1. **Document the hr_employee_documents table schema** once it has data
2. **Consider adding indexes** on frequently queried foreign keys
3. **Verify RLS policies** for all three tables
4. **Add cascade delete rules** if appropriate for your business logic
5. **Document the relationship** in your application's data model documentation

---

## Connection Verified
✅ Successfully connected using Supabase Service Role Key  
✅ All three tables are accessible  
✅ users → hr_employees relationship is working correctly  
⚠️ hr_employee_documents table exists but is empty
