# Coupon Product Images Storage Setup

## Storage Bucket Configuration

The Product Manager requires a Supabase storage bucket for product images.

### Bucket Name
```
coupon-product-images
```

### Required Settings

1. **Public Access**: Yes (for customer app to display product images)
2. **File Size Limit**: 5 MB (enforced in frontend)
3. **Allowed MIME Types**: 
   - image/jpeg
   - image/png
   - image/webp
   - image/gif

### Supabase Dashboard Setup Steps

1. Go to **Storage** in Supabase Dashboard
2. Click **New bucket**
3. Set bucket name: `coupon-product-images`
4. Enable **Public bucket** (customers need to view images)
5. Click **Create bucket**

### RLS Policy (if needed)

```sql
-- Allow authenticated users to upload
CREATE POLICY "Authenticated users can upload product images"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'coupon-product-images');

-- Allow everyone to view product images
CREATE POLICY "Anyone can view product images"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'coupon-product-images');

-- Allow authenticated users to update their uploads
CREATE POLICY "Authenticated users can update product images"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'coupon-product-images');

-- Allow authenticated users to delete product images
CREATE POLICY "Authenticated users can delete product images"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'coupon-product-images');
```

### File Naming Convention

Files are uploaded with unique names generated in the service:
```
products/{timestamp}-{originalFileName}
```

Example: `products/1732614000000-product-image.jpg`

### Frontend Implementation

**Upload Function** (`couponService.ts`):
```typescript
export async function uploadProductImage(file: File): Promise<string> {
  const fileExt = file.name.split('.').pop();
  const fileName = `${Date.now()}-${Math.random().toString(36).substring(2)}.${fileExt}`;
  const filePath = `products/${fileName}`;
  
  const { data, error } = await supabaseAdmin
    .storage
    .from('coupon-product-images')
    .upload(filePath, file, {
      cacheControl: '3600',
      upsert: false
    });
    
  if (error) throw error;
  
  return data.path;
}
```

**Get Public URL**:
```typescript
const { data: { publicUrl } } = supabaseAdmin
  .storage
  .from('coupon-product-images')
  .getPublicUrl(filePath);
```

### Testing Checklist

After creating the bucket:

- [ ] Create new product with image upload
- [ ] Verify image appears in product card preview
- [ ] Check image URL is publicly accessible
- [ ] Edit product and change image
- [ ] Verify old image is replaced
- [ ] Check file size validation (try uploading >5MB)
- [ ] Test with different image formats (JPEG, PNG, WebP)

### Troubleshooting

**Error: "Bucket not found"**
- Solution: Create the bucket in Supabase Dashboard

**Error: "Access denied"**
- Solution: Check RLS policies allow authenticated users to insert

**Image not displaying**
- Solution: Verify bucket is set to **Public** in settings
- Check the `getPublicUrl()` returns a valid URL

**Upload fails**
- Check file size < 5MB
- Verify MIME type is image/*
- Check user is authenticated

### Security Considerations

✅ **Good Practices:**
- Frontend validates file size (5MB limit)
- File type validation (images only)
- Unique file names prevent collisions
- Public read access for customer app
- Authenticated write access only

❌ **Avoid:**
- Don't store sensitive data in public bucket
- Don't allow anonymous uploads
- Don't use predictable file names (prevents guessing URLs)
