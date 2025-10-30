# Warning Image Storage System

## Overview
This document describes the warning image storage system that captures warning templates as images, stores them in Supabase Storage, and enables sharing via WhatsApp.

## Features

### 1. **Save as Image** 📸
- Captures the warning template as a high-quality PNG image
- Uses html2canvas library for accurate rendering
- Stores in Supabase Storage bucket: `warning-documents`
- Updates `employee_warnings` table with image URL

### 2. **Send Notification** 📤
- Sends internal notification to recipient with image URL
- Uses existing notification management system
- Includes push notifications

### 3. **Share to WhatsApp** 📱
- Opens WhatsApp Web with pre-filled message
- Includes link to saved image
- User can select recipient from WhatsApp contacts

## Workflow

```
┌─────────────┐      ┌──────────────┐      ┌────────────────┐
│   Step 1    │─────▶│    Step 2    │─────▶│    Step 3      │
│ Save Image  │      │ Send Notify  │      │ Share WhatsApp │
└─────────────┘      └──────────────┘      └────────────────┘
```

### Step-by-Step Process

1. **Edit Warning** (Initial State)
   - User can edit warning text
   - Preview template with all details
   - Click "💾 Save as Image" to proceed

2. **Save as Image**
   - Captures `.template-body` element
   - Converts to PNG blob
   - Uploads to `warning-documents/YYYY/MM/reference-timestamp.png`
   - Updates database with public URL
   - Shows "📤 Send Notification" button

3. **Send Notification**
   - Creates internal notification
   - Includes image URL in message
   - Triggers push notification
   - Shows "📱 Share to WhatsApp" button

4. **Share to WhatsApp**
   - Generates WhatsApp Web URL
   - Includes message with image link
   - Opens in new tab
   - User selects recipient

## Database Schema

### Filename Format Benefits

The system generates filenames that include the employee name for better organization:

**Format**: `employeename_reference_employeeid_timestamp.png`

**Benefits**:
1. **Easy Identification**: Employee name in filename makes it instantly recognizable
2. **Searchability**: Can search storage by employee name
3. **Uniqueness**: Combination of name, reference, ID, and timestamp ensures no conflicts
4. **Organization**: Files naturally group by employee when sorted alphabetically
5. **Debugging**: Easier to trace issues when filename contains meaningful information

**Sanitization Rules**:
- Special characters removed
- Spaces replaced with underscores
- Converted to lowercase
- Arabic/UTF-8 names transliterated to ASCII-safe characters

**Examples**:
```
john_doe_WRN-20251030-0001_a1b2c3d4_1730304000000.png
jane_smith_WRN-20251030-0002_b2c3d4e5_1730304500000.png
abdul_rahman_WRN-20251030-0003_c3d4e5f6_1730305000000.png
maria_garcia_WRN-20251030-0004_d4e5f6a7_1730305500000.png
```

### Table: `employee_warnings`
```sql
Column: warning_document_url
Type: TEXT
Description: Public URL to the warning image in storage
Format: https://vmypotfsyrvuublyddyt.supabase.co/storage/v1/object/public/warning-documents/YYYY/MM/employeename_reference_employeeid_timestamp.png
Example: https://vmypotfsyrvuublyddyt.supabase.co/storage/v1/object/public/warning-documents/2025/10/john_doe_WRN-20251030-0001_a1b2c3d4_1730304000000.png
```

### Storage Bucket: `warning-documents`
- **Public**: Yes (read-only)
- **File Size Limit**: 5MB
- **Allowed Types**: PNG, JPEG, JPG, WebP
- **Path Format**: `YYYY/MM/employeename_reference_employeeid_timestamp.png`
- **Filename Components**:
  - Employee name (sanitized, lowercase, underscores)
  - Warning reference number
  - Employee ID (first 8 characters)
  - Unix timestamp (for uniqueness)

Example:
```
warning-documents/
  ├── 2025/
  │   ├── 10/
  │   │   ├── john_doe_WRN-20251030-0001_a1b2c3d4_1730304000000.png
  │   │   ├── jane_smith_WRN-20251030-0002_b2c3d4e5_1730304500000.png
  │   │   ├── abdul_rahman_WRN-20251030-0003_c3d4e5f6_1730305000000.png
  │   │   └── ...
  │   └── 11/
  │       └── ...
  └── 2026/
      └── ...
```

## Storage Policies

### 1. **Insert Policy**
- **Name**: Authenticated users can upload warning documents
- **Action**: INSERT
- **Role**: authenticated
- **Check**: `bucket_id = 'warning-documents' AND auth.uid() IS NOT NULL`

### 2. **Select Policy**
- **Name**: Public read access to warning documents
- **Action**: SELECT
- **Role**: public
- **Check**: `bucket_id = 'warning-documents'`

### 3. **Update Policy**
- **Name**: Users can update their own warning documents
- **Action**: UPDATE
- **Role**: authenticated
- **Check**: User owns the document

### 4. **Delete Policy**
- **Name**: Users can delete their own warning documents
- **Action**: DELETE
- **Role**: authenticated
- **Check**: User owns the document

## API Reference

### `warningImageStorage.js`

#### `elementToBlob(element, options)`
Converts HTML element to PNG blob.

**Parameters:**
- `element` (HTMLElement): Element to capture
- `options` (Object): html2canvas options

**Returns:** `Promise<Blob>`

**Example:**
```javascript
const blob = await elementToBlob(templateElement, { scale: 2 });
```

#### `generateWarningImagePath(warningReference, employeeName, employeeId)`
Generates unique filename with employee name.

**Parameters:**
- `warningReference` (string): Warning reference number
- `employeeName` (string): Name of warned employee (default: 'Unknown')
- `employeeId` (string): Employee ID (optional, for extra uniqueness)

**Returns:** `string` - Path format: `YYYY/MM/employeename_reference_id_timestamp.png`

**Example:**
```javascript
const path = generateWarningImagePath(
  'WRN-20251030-0001', 
  'John Doe',
  'a1b2c3d4-5678-90ab-cdef-1234567890ab'
);
// Returns: "2025/10/john_doe_WRN-20251030-0001_a1b2c3d4_1730304000000.png"
```

#### `uploadWarningImage(imageBlob, warningReference, employeeName, employeeId)`
Uploads image blob to Supabase Storage with employee name in filename.

**Parameters:**
- `imageBlob` (Blob): Image data
- `warningReference` (string): Warning reference number
- `employeeName` (string): Name of warned employee
- `employeeId` (string): Employee ID (optional)

**Returns:** `Promise<Object>`
```javascript
{
  success: true,
  path: "2025/10/john_doe_WRN-20251030-0001_a1b2c3d4_1730304000000.png",
  publicUrl: "https://...",
  fullPath: "..."
}
```

**Example:**
```javascript
const result = await uploadWarningImage(
  imageBlob, 
  'WRN-20251030-0001',
  'John Doe',
  'a1b2c3d4-5678-90ab-cdef-1234567890ab'
);
```

#### `updateWarningWithImageUrl(warningId, imageUrl)`
Updates employee_warnings record with image URL.

**Parameters:**
- `warningId` (string): Warning record UUID
- `imageUrl` (string): Public URL of uploaded image

**Returns:** `Promise<Object>`

#### `captureAndSaveWarning(element, warningId, warningReference, employeeName, employeeId)`
Complete workflow: capture → upload → update database.

**Parameters:**
- `element` (HTMLElement): Template element to capture
- `warningId` (string): Warning record UUID
- `warningReference` (string): Warning reference number
- `employeeName` (string): Name of warned employee
- `employeeId` (string): Employee ID (optional)

**Returns:** `Promise<Object>`
```javascript
{
  success: true,
  imageUrl: "https://...",
  imagePath: "2025/10/john_doe_WRN-20251030-0001_a1b2c3d4_1730304000000.png",
  warningId: "...",
  warningData: {...}
}
```

**Example:**
```javascript
const result = await captureAndSaveWarning(
  templateElement,
  'uuid-of-warning',
  'WRN-20251030-0001',
  'John Doe',
  'a1b2c3d4-5678-90ab-cdef-1234567890ab'
);
```

#### `generateWhatsAppShareUrl(imageUrl, recipientName, message)`
Generates WhatsApp Web share URL.

**Parameters:**
- `imageUrl` (string): Public image URL
- `recipientName` (string): Recipient name
- `message` (string): Optional custom message

**Returns:** `string` - WhatsApp Web URL

## Component Integration

### `WarningTemplate.svelte`

#### State Variables
```javascript
let workflowStep = 'edit'; // 'edit' | 'save' | 'send' | 'share'
let savedWarningId = null;
let savedImageUrl = null;
let isSavingImage = false;
let saveImageError = null;
```

#### Functions
- `saveAsImage()` - Step 1: Capture and upload
- `sendNotificationWithImage()` - Step 2: Send notification
- `shareToWhatsApp()` - Step 3: Open WhatsApp

## UI Components

### Progress Indicator
Shows current step in workflow:
```
(1) Save  ──▶  (2) Send  ──▶  (3) Share
  🟣         🟢           ⚪
```

### Image Link Section
Displays saved image link after upload:
```
┌────────────────────────────────────┐
│ Saved Image: [View Image 🔗]      │
└────────────────────────────────────┘
```

## Migration Files

### `20251030000001_warning_images_storage.sql`
- Creates storage bucket
- Sets up storage policies
- Adds database indexes
- Creates helper functions

**Run migration:**
```bash
node scripts/create-warning-storage.cjs
```

## Testing Checklist

- [ ] Save warning as image (check quality)
- [ ] Verify image appears in Supabase Storage
- [ ] Check public URL is accessible
- [ ] Test image dimensions and clarity
- [ ] Send notification with image
- [ ] Verify notification includes image URL
- [ ] Share to WhatsApp Web
- [ ] Test on mobile browser
- [ ] Check workflow progression UI
- [ ] Test error handling (network failure)
- [ ] Verify database record updated
- [ ] Test with different languages (AR, UR, HI, etc.)
- [ ] Check image file size (<5MB)
- [ ] Test delete functionality

## Error Handling

### Common Errors

1. **"Template body not found"**
   - Element selector failed
   - Solution: Ensure `.template-body` class exists

2. **"Failed to upload image"**
   - Storage permissions issue
   - Solution: Check storage policies in Supabase Dashboard

3. **"Failed to convert canvas to blob"**
   - html2canvas rendering failed
   - Solution: Check element visibility and CORS issues

4. **"Please save the warning as image first"**
   - Workflow step skipped
   - Solution: Follow step-by-step workflow

## Performance Considerations

### Image Size Optimization
- Default scale: 2x (high quality)
- Compression: PNG at 95% quality
- Expected size: 200KB - 1MB per image

### Storage Limits
- Bucket limit: 5MB per file
- Monthly bandwidth: Check Supabase plan
- Total storage: Check Supabase plan

### Browser Compatibility
- Requires html2canvas support
- Works on modern browsers (Chrome, Firefox, Safari, Edge)
- Mobile browsers supported

## Security Considerations

1. **Public Access**: Images are publicly readable (anyone with URL can view)
2. **Authentication**: Upload requires authenticated user
3. **File Validation**: Only image types allowed
4. **File Size**: Limited to 5MB
5. **Path Structure**: Organized by date to prevent conflicts

## Future Enhancements

- [ ] Add PDF export option
- [ ] Implement image watermarking
- [ ] Add bulk download feature
- [ ] Create gallery view for all warnings
- [ ] Add image preview modal
- [ ] Implement email sharing
- [ ] Add signature capture on mobile
- [ ] Create print-optimized version
- [ ] Add image compression options
- [ ] Implement expiry dates for old images

## Troubleshooting

### Image Not Saving
1. Check browser console for errors
2. Verify Supabase service role key
3. Check storage bucket exists
4. Verify network connectivity

### WhatsApp Not Opening
1. Ensure URL encoding is correct
2. Check browser popup blockers
3. Verify WhatsApp Web accessibility

### Image Quality Poor
1. Increase scale option (default: 2)
2. Check source element rendering
3. Verify font loading completed

## Support

For issues or questions:
1. Check browser console logs
2. Review Supabase Storage logs
3. Verify migration was applied correctly
4. Contact development team

---

**Last Updated**: October 30, 2025
**Version**: 1.0.0
