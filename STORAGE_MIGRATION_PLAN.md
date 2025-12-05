## 📦 Storage Migration Plan - Old to New Supabase

**Total Files to Migrate: 5,251**

---

## Migration by Bucket (Priority Order)

### 🔴 **CRITICAL BUCKETS** (Large, Important)
1. **original-bills** - 1,000 files
   - Invoice/bill documents
   - Used by: Receiving system, Finance module
   - Migration: HIGH PRIORITY

2. **completion-photos** - 1,000 files
   - Task completion photos
   - Used by: Task management system
   - Migration: HIGH PRIORITY

3. **clearance-certificates** - 1,000 files
   - Clearance/approval certificates
   - Used by: Employee documents, HR
   - Migration: HIGH PRIORITY

4. **flyer-product-images** - 1,000 files
   - Flyer product images
   - Used by: Admin product management
   - Migration: HIGH PRIORITY

5. **pr-excel-files** - 1,000 files
   - PR/Excel files for receiving
   - Used by: Receiving records, ERP sync
   - Migration: HIGH PRIORITY

### 🟡 **MEDIUM BUCKETS** (Small, Important)
6. **requisition-images** - 173 files
   - Expense requisition attachments
   - Used by: Finance module
   - Migration: MEDIUM PRIORITY

7. **quick-task-files** - 59 files
   - Quick task attachments
   - Used by: Task system
   - Migration: MEDIUM PRIORITY

### 🟢 **SMALL BUCKETS** (Few files)
8. **expense-scheduler-bills** - 4 files
9. **product-images** - 3 files
10. **task-images** - 3 files
11. **flyer-templates** - 2 files
12. **customer-app-media** - 2 files
13. **category-images** - 2 files
14. **shelf-paper-templates** - 1 file
15. **notification-images** - 1 file
16. **warning-documents** - 1 file

---

## Empty Buckets (Skip)
- ✅ employee-documents (0 files)
- ✅ user-avatars (0 files)
- ✅ documents (0 files)
- ✅ vendor-contracts (0 files)
- ✅ coupon-product-images (0 files)

---

## Migration Strategy

### Phase 1: Critical Large Buckets (5,251 files total)
**One bucket at a time, in order:**

1. **Batch 1** - Original Bills (1,000 files) - Est. 5-10 min
2. **Batch 2** - Completion Photos (1,000 files) - Est. 5-10 min
3. **Batch 3** - Clearance Certificates (1,000 files) - Est. 5-10 min
4. **Batch 4** - Flyer Product Images (1,000 files) - Est. 5-10 min
5. **Batch 5** - PR Excel Files (1,000 files) - Est. 5-10 min

### Phase 2: Medium Buckets
6. **Batch 6** - Requisition Images (173 files) - Est. 1-2 min
7. **Batch 7** - Quick Task Files (59 files) - Est. 30 sec

### Phase 3: Small Buckets
8. **Batch 8** - All remaining (69 files total) - Est. 30 sec

---

## File Migration Process

**For each bucket:**
1. List all files in old bucket
2. Copy files one by one to new bucket (maintain path structure)
3. Verify file count matches
4. Mark as complete

---

## Database Records Migrated ✅

Already completed:
- **30,116 rows** across 25 tables ✅
- All data references to storage files are intact
- File paths stored in database need files to exist

---

## Next Steps

Choose one:

**Option A: Automated Migration**
- Create migration script that copies all files one bucket at a time
- Show progress for each bucket
- Estimated time: 40-60 minutes total

**Option B: Manual Priority Migration**
- Migrate critical buckets first (5,000 files)
- Then migrate remaining buckets as needed
- Can pause between buckets

**Option C: On-Demand**
- Wait for user to request file
- Migrate only when needed
- Slower but lowest risk

---

Which option would you prefer?
