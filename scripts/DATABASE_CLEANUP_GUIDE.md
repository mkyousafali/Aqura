# Database Content Audit & Cleanup Guide

## Overview
This guide helps you search for and remove offensive content from the database using SQL queries.

## Steps to Follow

### Step 1: Check for Offensive Content
1. Go to your Supabase Dashboard
2. Click on **SQL Editor** (in the left sidebar)
3. Create a new query
4. Copy the **SEARCH QUERIES** section from `check-offensive-content.sql`
5. Run the query
6. Review the results - it will show all tables and fields containing the offensive word

### Step 2: Review Results
The search will show:
- `table_name`: Which table has the offensive content
- `id`: The ID of the record
- `field_name`: Which field contains the offensive word
- `content`: The actual content

Example result:
```
table_name | id | field_name | content
-----------|----|-----------|---------
branches   | 5  | name_ar   | عاهرة (some branch name)
```

### Step 3: Backup (Optional but Recommended)
Before cleaning, you might want to:
1. Export the data to a CSV for backup
2. Take a screenshot of the results

### Step 4: Clean the Database
1. Go back to SQL Editor in Supabase
2. Copy the **CLEANING QUERIES** section from `check-offensive-content.sql`
3. Run each UPDATE statement one by one OR run them all together
4. Confirm the number of rows affected

The cleaning will replace the offensive word with `*****` in all tables.

### Step 5: Verify Cleaning
1. Copy the **VERIFICATION QUERIES** section from `check-offensive-content.sql`
2. Run it
3. If no results appear, the cleanup was successful! ✅

## SQL Queries Reference

### Quick Check (Just Search)
```sql
SELECT 'branches' as table_name, id, 'name_ar' as field_name, name_ar as content
FROM branches
WHERE name_ar ILIKE '%عاهرة%'
```

### Quick Clean (Branches Only)
```sql
UPDATE branches
SET name_ar = REPLACE(name_ar, 'عاهرة', '*****')
WHERE name_ar ILIKE '%عاهرة%';
```

## Tables Checked
- ✓ branches (name_en, name_ar, location_en, location_ar)
- ✓ vendors (name)
- ✓ products (name_en, name_ar)
- ✓ offers (description_en, description_ar)
- ✓ categories (name_en, name_ar)
- ✓ departments (name)

## Important Notes
⚠️ Always verify the search results BEFORE running cleaning queries
⚠️ These operations cannot be easily reversed - make sure you want to replace with `*****`
⚠️ If you need to see what was there before, take a screenshot first

## Need Help?
If you need to add more tables or fields to search:
1. Add a new UNION ALL section in the search query
2. Replace table name and field names
3. Keep the ILIKE '%عاهرة%' pattern

Example for a new table called `companies`:
```sql
UNION ALL
SELECT 'companies' as table_name, id::text, 'company_name_ar' as field_name, company_name_ar as content
FROM companies
WHERE company_name_ar ILIKE '%عاهرة%'
```
