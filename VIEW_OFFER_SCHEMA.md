# View Offer System - Database & Storage Setup

## Table Schema: `view_offer`

### Columns:

| Column | Type | Description | Required |
|--------|------|-------------|----------|
| `id` | UUID | Primary key, auto-generated | Yes |
| `offer_name` | VARCHAR(255) | Name of the offer | Yes |
| `branch_id` | BIGINT | Reference to branches table | Yes |
| `start_date` | DATE | Offer start date | Yes |
| `start_time` | TIME WITHOUT TIME ZONE | Offer start time | Yes |
| `end_date` | DATE | Offer end date | Yes |
| `end_time` | TIME WITHOUT TIME ZONE | Offer end time | Yes |
| `file_url` | TEXT | URL to the offer file in storage | Yes |
| `created_at` | TIMESTAMP WITH TIME ZONE | Record creation timestamp | Auto |
| `updated_at` | TIMESTAMP WITH TIME ZONE | Record update timestamp | Auto |

### Indexes:
- `idx_view_offer_branch_id` - On `branch_id` for faster branch filtering
- `idx_view_offer_datetime` - On `start_date, start_time, end_date, end_time` for date/time range queries

### Foreign Keys:
- `branch_id` → `branches.id` (CASCADE on delete)

---

## SQL Migration

Run the following SQL in your Supabase SQL Editor or execute the migration file:
`supabase/migrations/create_view_offer_table.sql`

---

## Storage Bucket Setup

### Storage Bucket: `offer-pdfs`

**Configuration:**
- Bucket Name: `offer-pdfs`
- Public: Yes (to allow serving files to authenticated users)
- File Size Limit: 2GB per file (Supabase default)
- Allowed File Types: **ANY** (PDF, Video, Images, Documents, etc.)
  - Supported: `.pdf`, `.mp4`, `.avi`, `.mov`, `.jpg`, `.png`, `.gif`, `.odg`, `.ong`, `.doc`, `.docx`, etc.
  - No file type restrictions - accepts all formats

### SQL to Create Storage Bucket and Policies

Run the following SQL in your Supabase SQL Editor:

```sql
-- Enable storage extension (if not already enabled)
CREATE EXTENSION IF NOT EXISTS "storage" SCHEMA "storage";

-- Create storage bucket (if it doesn't exist)
INSERT INTO storage.buckets (id, name, public)
VALUES ('offer-pdfs', 'offer-pdfs', true)
ON CONFLICT (id) DO NOTHING;

-- Allow authenticated users to upload PDF files
CREATE POLICY "Allow authenticated users to upload PDFs"
ON storage.objects
FOR INSERT
WITH CHECK (
  bucket_id = 'offer-pdfs' 
  AND auth.role() = 'authenticated'
);

-- Allow public read access to PDFs
CREATE POLICY "Allow public read access to PDFs"
ON storage.objects
FOR SELECT
USING (bucket_id = 'offer-pdfs');

-- Allow users to delete their own PDFs
CREATE POLICY "Allow users to delete their own PDFs"
ON storage.objects
FOR DELETE
USING (
  bucket_id = 'offer-pdfs' 
  AND auth.role() = 'authenticated'
);

-- Allow authenticated users to update their own PDFs
CREATE POLICY "Allow authenticated users to update PDFs"
ON storage.objects
FOR UPDATE
USING (
  bucket_id = 'offer-pdfs'
  AND auth.role() = 'authenticated'
)
WITH CHECK (
  bucket_id = 'offer-pdfs'
  AND auth.role() = 'authenticated'
);
```

---

## Complete Setup Steps

### Step 1: Create the Table
Execute the migration file in your Supabase project:
```bash
supabase migration up
```

Or copy and run `create_view_offer_table.sql` in the Supabase SQL Editor

### Step 2: Create Storage Bucket and Policies
Copy the storage SQL above and run it in Supabase SQL Editor

### Step 3: Verify Setup

Run the following queries to verify:

```sql
-- Check if view_offer table exists
SELECT * FROM information_schema.tables 
WHERE table_name = 'view_offer' AND table_schema = 'public';

-- Check if storage bucket exists
SELECT * FROM storage.buckets WHERE id = 'offer-pdfs';

-- Check storage policies
SELECT * FROM storage.s3_multipart_uploads 
WHERE bucket_id = 'offer-pdfs';
```

---

## Row Level Security (RLS)

RLS is enabled on the `view_offer` table with the following policies:

1. **SELECT** - Authenticated users can view all offers
2. **INSERT** - Authenticated users can create offers
3. **UPDATE** - Authenticated users can update offers
4. **DELETE** - Authenticated users can delete offers

---

## File Naming Convention

Files uploaded are named with the pattern:
```
offer_{branch_id}_{timestamp}.{original_extension}
```

Examples:
- `offer_a1b2c3d4-e5f6-47a8-b9c0-d1e2f3a4b5c6_1703596800000.pdf`
- `offer_a1b2c3d4-e5f6-47a8-b9c0-d1e2f3a4b5c6_1703596800000.mp4`
- `offer_a1b2c3d4-e5f6-47a8-b9c0-d1e2f3a4b5c6_1703596800000.jpg`
- `offer_a1b2c3d4-e5f6-47a8-b9c0-d1e2f3a4b5c6_1703596800000.png`

This naming convention:
- Ensures unique filenames with timestamps
- Preserves original file extension for easy identification
- Makes it easy to identify which branch the offer belongs to

---

## Usage in Component

The `ViewOfferManager.svelte` component handles:

1. **Fetching Branches** - Populates the branch dropdown
2. **File Upload** - Uploads PDF to `offer-pdfs` storage bucket
3. **Database Insert** - Creates record in `view_offer` table with PDF URL

### Form Fields:
- Offer Name (text input)
- Branch (dropdown select)
- Start Date (date picker)
- Start Time (time picker - HH:MM format)
- End Date (date picker)
- End Time (time picker - HH:MM format)
- File Upload (file input - accepts ANY file type)

### Supported File Types:
- **Documents:** PDF, DOCX, DOC, ODT, etc.
- **Videos:** MP4, AVI, MOV, WMV, FLV, etc.
- **Images:** JPG, PNG, GIF, ODG, ONG, BMP, WebP, etc.
- **Audio:** MP3, WAV, OGG, M4A, etc.
- **Other:** Any file format is accepted

### Validations:
- All fields required
- End date/time must be after start date/time
- File is required
- No file type restrictions - accepts all formats

---

## Database Queries for Testing

### View all offers
```sql
SELECT 
  vo.id,
  vo.offer_name,
  b.branch_name,
  vo.start_date,
  vo.end_date,
  vo.pdf_url,
  vo.created_at
FROM view_offer vo
JOIN branches b ON vo.branch_id = b.id
ORDER BY vo.created_at DESC;
```

### View offers for specific branch
```sql
SELECT 
  vo.id,
  vo.offer_name,
  vo.start_date,
  vo.end_date,
  vo.pdf_url
FROM view_offer vo
WHERE vo.branch_id = 'YOUR_BRANCH_ID'
ORDER BY vo.start_date DESC;
```

### View active offers (current date within date range)
```sql
SELECT 
  vo.id,
  vo.offer_name,
  b.branch_name,
  vo.start_date,
  vo.end_date,
  vo.pdf_url
FROM view_offer vo
JOIN branches b ON vo.branch_id = b.id
WHERE CURRENT_DATE BETWEEN vo.start_date AND vo.end_date
ORDER BY vo.end_date ASC;
```

### Delete all offers from a branch
```sql
DELETE FROM view_offer
WHERE branch_id = 'YOUR_BRANCH_ID';
```

---

## Troubleshooting

### Issue: Storage bucket not found
**Solution:** Make sure you've created the bucket in Supabase Storage dashboard first, then run the SQL policies

### Issue: RLS denying access
**Solution:** Verify user is authenticated and has proper role. Check RLS policies on table

### Issue: PDF upload fails
**Solution:** 
- Verify file is actually PDF (application/pdf MIME type)
- Check file size is under limit (50MB)
- Verify bucket policies allow authenticated uploads

### Issue: PDF URL not accessible
**Solution:** Make sure bucket is set to "Public" in Supabase Storage settings

---

## Next Steps

1. ✅ Run the table creation SQL
2. ✅ Create and configure the storage bucket
3. ✅ Apply the storage policies
4. ✅ Test the "Add Offer" functionality in the ViewOfferManager window
5. Display offers in a list view (next feature)

