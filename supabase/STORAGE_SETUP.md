# Customer App Media Storage Setup

## Storage Bucket Configuration

### Bucket Name: `customer-app-media`

### Structure:
```
customer-app-media/
├── videos/
│   ├── slot-1/
│   ├── slot-2/
│   ├── slot-3/
│   ├── slot-4/
│   ├── slot-5/
│   └── slot-6/
└── images/
    ├── slot-1/
    ├── slot-2/
    ├── slot-3/
    ├── slot-4/
    ├── slot-5/
    └── slot-6/
```

### Bucket Settings:
- **Public Access**: Yes (for customer app to access)
- **File Size Limit**: 
  - Videos: 50 MB
  - Images: 5 MB
- **Allowed File Types**:
  - Videos: `.mp4`, `.webm`, `.mov`
  - Images: `.jpg`, `.jpeg`, `.png`, `.webp`

### Create Bucket via Supabase Dashboard:
1. Go to Storage section
2. Create new bucket: `customer-app-media`
3. Enable public access
4. Set file size limit: 50 MB

### Or Create via SQL:
```sql
-- Create storage bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'customer-app-media',
    'customer-app-media',
    true,
    52428800, -- 50 MB in bytes
    ARRAY[
        'video/mp4',
        'video/webm',
        'video/quicktime',
        'image/jpeg',
        'image/png',
        'image/webp'
    ]
);

-- Set storage policies for authenticated users
CREATE POLICY "Authenticated users can upload media"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'customer-app-media');

CREATE POLICY "Authenticated users can update media"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'customer-app-media');

CREATE POLICY "Authenticated users can delete media"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'customer-app-media');

CREATE POLICY "Public can view media"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'customer-app-media');
```

### File Naming Convention:
- Videos: `videos/slot-{number}/{timestamp}-{original-name}.{ext}`
- Images: `images/slot-{number}/{timestamp}-{original-name}.{ext}`

Example:
- `videos/slot-1/1699363200000-aqua-promo.mp4`
- `images/slot-3/1699363200000-summer-sale.jpg`

### Usage in Code:
```typescript
// Get public URL
const { data } = supabase.storage
  .from('customer-app-media')
  .getPublicUrl('videos/slot-1/1699363200000-aqua-promo.mp4');

// Upload file
const { data, error } = await supabase.storage
  .from('customer-app-media')
  .upload(`videos/slot-${slotNumber}/${timestamp}-${fileName}`, file);
```
