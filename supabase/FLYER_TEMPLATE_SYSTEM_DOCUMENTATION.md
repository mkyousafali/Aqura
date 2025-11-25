# Flyer Template System - Complete Documentation

## 📋 Overview

The Flyer Template System allows you to create, manage, and use customizable flyer templates with product field configurations for the Aqura management system.

## 🗃️ Database Structure

### Table: `flyer_templates`

Stores all flyer template designs with unlimited sub-pages and product field configurations.

#### Columns:

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `name` | VARCHAR(255) | Template name (unique) |
| `description` | TEXT | Template description |
| `first_page_image_url` | TEXT | Storage URL for first page template |
| `sub_page_image_urls` | TEXT[] | Array of storage URLs for sub-pages |
| `first_page_configuration` | JSONB | Product field configurations for first page |
| `sub_page_configurations` | JSONB | 2D array of configurations for sub-pages |
| `metadata` | JSONB | Template dimensions and metadata |
| `is_active` | BOOLEAN | Template active status |
| `is_default` | BOOLEAN | Is this the default template? |
| `category` | VARCHAR(100) | Template category |
| `tags` | TEXT[] | Search tags |
| `usage_count` | INTEGER | Times used counter |
| `last_used_at` | TIMESTAMP | Last usage timestamp |
| `created_by` | UUID | Creator user ID |
| `updated_by` | UUID | Last editor user ID |
| `created_at` | TIMESTAMP | Creation timestamp |
| `updated_at` | TIMESTAMP | Last update timestamp |
| `deleted_at` | TIMESTAMP | Soft delete timestamp |

#### Configuration Structure:

**First Page Configuration:**
```json
[
  {
    "id": "field-uuid-1",
    "number": 1,
    "x": 50,
    "y": 100,
    "width": 200,
    "height": 150,
    "fields": [
      {
        "type": "product_name_en",
        "fontSize": 16,
        "alignment": "left",
        "color": "#000000"
      },
      {
        "type": "price",
        "fontSize": 20,
        "alignment": "right",
        "color": "#ff0000"
      }
    ]
  }
]
```

**Sub Page Configurations:**
```json
[
  [ /* Sub Page 1 fields */ ],
  [ /* Sub Page 2 fields */ ],
  [ /* Sub Page 3 fields */ ]
]
```

#### Field Types:
- `product_name_en` - Product name (English)
- `product_name_ar` - Product name (Arabic)
- `unit_name` - Unit of measurement
- `price` - Regular price
- `offer_price` - Discounted price
- `offer_qty` - Offer quantity
- `limit_qty` - Quantity limit
- `image` - Product image
- `special_symbol` - Special badge/icon

## 🗄️ Storage Bucket

### Bucket: `flyer-templates`
- **Access**: Public read, admin write
- **File Types**: image/jpeg, image/jpg, image/png, image/webp
- **Size Limit**: 10MB per file
- **Usage**: Stores template background images

## ⚡ Functions

### `get_active_flyer_templates()`
Returns all active, non-deleted templates ordered by default status, usage count, and creation date.

**Returns:**
```sql
TABLE (
  id, name, description, first_page_image_url,
  sub_page_image_urls, first_page_configuration,
  sub_page_configurations, metadata, is_default,
  category, tags, usage_count, last_used_at, created_at
)
```

### `get_default_flyer_template()`
Returns the current default template.

### `soft_delete_flyer_template(template_id UUID)`
Soft deletes a template (prevents deletion of default template).

**Returns:** BOOLEAN

### `duplicate_flyer_template(template_id UUID, new_name VARCHAR, user_id UUID)`
Creates a copy of an existing template.

**Returns:** UUID (new template ID)

### `validate_flyer_template_configuration(config JSONB)`
Validates the structure of a template configuration.

**Returns:** BOOLEAN

## 🔒 Security (RLS Policies)

### Table Policies:
1. ✅ **Users can view active templates** - All authenticated users
2. ✅ **Admins can view all templates** - Including deleted ones
3. ✅ **Admins can insert/update/delete** - Full CRUD access

### Storage Policies:
1. ✅ **Public read access** - Anyone can view template images
2. ✅ **Admin write access** - Only admins can upload/update/delete

## 📦 Installation & Setup

### Step 1: Apply Migration

**Option A - Using SQL Editor (Recommended):**
1. Open Supabase Dashboard
2. Go to SQL Editor
3. Copy contents from `supabase/migrations/20251125_create_flyer_template_system.sql`
4. Run the script

**Option B - Using Script:**
```bash
node apply-flyer-template-migration.js
```

### Step 2: Verify Installation

```bash
node verify-flyer-template-table.js
```

### Step 3: Create Storage Bucket (if not auto-created)

1. Go to Supabase Dashboard > Storage
2. Click "New bucket"
3. Name: `flyer-templates`
4. Check "Public bucket"
5. Click "Create bucket"

### Step 4: Test in Application

1. Open Aqura management system
2. Navigate to Flyer Templates
3. Create a new template
4. Upload first page image
5. Add sub-pages as needed
6. Configure product fields
7. Save template

## 🎨 Using the Template Designer

### Creating a Template:

1. **Enter Template Info:**
   - Name (required)
   - Description (optional)

2. **Upload First Page:**
   - Click upload area
   - Select A4 image (794×1123px recommended)

3. **Add Sub-Pages:**
   - Click "➕ Add Sub Page" button
   - Upload image for each sub-page
   - Unlimited sub-pages supported

4. **Add Product Fields:**
   - Click "➕ Add Product Field"
   - Drag field to position
   - Resize using corner handles
   - Double-click to configure

5. **Configure Fields:**
   - Select data types (name, price, etc.)
   - Set font size and alignment
   - Add icons if needed
   - Position symbols

6. **Save Template:**
   - Click "💾 Save Template"
   - Wait for upload completion

### Field Configuration Options:

- **Position**: Drag anywhere on canvas
- **Size**: Resize using handles
- **Data Fields**: Multiple data types per field
- **Icons**: Upload and position custom icons
- **Symbols**: Add special badges/icons
- **Layering**: Text → Fields → Symbols → Icons

## 🔧 API Usage

### Fetch All Templates:
```javascript
const { data, error } = await supabase
  .from('flyer_templates')
  .select('*')
  .eq('is_active', true)
  .order('is_default', { ascending: false });
```

### Get Default Template:
```javascript
const { data, error } = await supabase
  .rpc('get_default_flyer_template');
```

### Create Template:
```javascript
const { data, error } = await supabase
  .from('flyer_templates')
  .insert({
    name: 'My Template',
    description: 'Custom flyer template',
    first_page_image_url: 'https://...',
    sub_page_image_urls: ['https://...'],
    first_page_configuration: [],
    sub_page_configurations: [[]],
    metadata: {
      first_page_width: 794,
      first_page_height: 1123,
      sub_page_width: 794,
      sub_page_height: 1123
    },
    created_by: userId
  });
```

### Upload Template Image:
```javascript
const { data, error } = await supabase.storage
  .from('flyer-templates')
  .upload(`templates/${fileName}`, file, {
    contentType: file.type,
    upsert: false
  });

const publicUrl = supabase.storage
  .from('flyer-templates')
  .getPublicUrl(data.path).data.publicUrl;
```

### Duplicate Template:
```javascript
const { data, error } = await supabase
  .rpc('duplicate_flyer_template', {
    template_id: existingTemplateId,
    new_name: 'Copy of Template',
    user_id: currentUserId
  });
```

## 📊 Usage Statistics

The system automatically tracks:
- ✅ Template usage count
- ✅ Last used timestamp
- ✅ Creator and last editor
- ✅ Creation and update timestamps

## 🚀 Future Enhancements

Potential additions:
- [ ] Template versioning
- [ ] Template sharing between branches
- [ ] Template marketplace
- [ ] Auto-generated templates from AI
- [ ] Template preview generation
- [ ] Bulk template import/export
- [ ] Template analytics dashboard

## 🐛 Troubleshooting

### Table doesn't exist
- Run migration script again
- Check Supabase logs for errors
- Verify user permissions

### Can't upload images
- Check storage bucket exists
- Verify storage policies
- Check file size (<10MB)
- Verify file type (jpeg/png/webp)

### Can't save template
- Check RLS policies
- Verify user is admin
- Check required fields filled
- Verify image URLs are valid

### Configuration not saving
- Validate JSON structure
- Check field IDs are unique
- Verify all required properties exist
- Check array dimensions match

## 📞 Support

For issues or questions:
1. Check migration logs
2. Run verification script
3. Check Supabase logs
4. Review RLS policies
5. Contact system administrator

---

**Version:** 1.0.0  
**Last Updated:** November 25, 2025  
**Aqura Management System**
