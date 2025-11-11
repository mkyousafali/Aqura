# Deleted Bundle Offers System

## Overview
Instead of permanently deleting bundle offers, the system now archives them to a separate table for audit trail and potential recovery.

## Database Setup

### Step 1: Create the Archive Table
Run this SQL in Supabase SQL Editor:

```sql
-- Located in: create-deleted-bundle-offers-table.sql
```

Or run the setup script:
```bash
node create-deleted-bundle-offers-table.js
```

## Table Structure: `deleted_bundle_offers`

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `original_offer_id` | UUID | Original offer ID (unique) |
| `offer_data` | JSONB | Complete offer data |
| `bundles_data` | JSONB | Array of all bundles |
| `deleted_at` | TIMESTAMP | When deleted |
| `deleted_by` | UUID | User who deleted |
| `deletion_reason` | TEXT | Optional reason |

## How It Works

### When User Clicks Delete:

1. **Confirmation Dialog**
   - User confirms deletion

2. **Archive Process**
   - Fetches complete offer data from `offers` table
   - Fetches all bundles from `offer_bundles` table
   - Inserts into `deleted_bundle_offers` table with:
     - Original offer data as JSON
     - All bundles as JSON array
     - Timestamp and deletion info

3. **Remove from Active Tables**
   - Deletes bundles from `offer_bundles`
   - Deletes offer from `offers`

4. **Success Message**
   - Shows: "✅ Offer archived successfully!"
   - Refreshes offer list

### Benefits

✅ **Audit Trail** - See who deleted what and when
✅ **Recovery** - Can restore deleted offers if needed
✅ **Compliance** - Meet data retention requirements
✅ **Analytics** - Analyze deleted offers patterns
✅ **No Data Loss** - Complete offer and bundle data preserved

## Future: Deleted Offers Management Interface

You can later create an admin interface to:
- View all deleted offers
- Filter by date, user, etc.
- Restore offers if needed
- Permanently delete (hard delete) old archives

### Example Query to View Deleted Offers:

```javascript
const { data, error } = await supabase
  .from('deleted_bundle_offers')
  .select('*')
  .order('deleted_at', { ascending: false });
```

### Example Restore Function:

```javascript
async function restoreDeletedOffer(deletedOfferId) {
  // Get archived data
  const { data } = await supabase
    .from('deleted_bundle_offers')
    .select('*')
    .eq('id', deletedOfferId)
    .single();
  
  // Restore offer
  await supabase.from('offers').insert(data.offer_data);
  
  // Restore bundles
  if (data.bundles_data.length > 0) {
    await supabase.from('offer_bundles').insert(data.bundles_data);
  }
  
  // Remove from archive
  await supabase.from('deleted_bundle_offers').delete().eq('id', deletedOfferId);
}
```

## Important Notes

⚠️ **Must Run SQL First**: The `deleted_bundle_offers` table must be created before deleting any offers
⚠️ **Service Role Key**: Uses `supabaseAdmin` for proper permissions
⚠️ **RLS Policies**: Table has Row Level Security enabled
⚠️ **Unique Constraint**: Cannot archive the same offer_id twice (prevents duplicates)

## Error Handling

If the archive table doesn't exist, the system will:
- Show error message to user
- Prevent deletion
- Prompt admin to create the table

## Migration Checklist

- [ ] Run `create-deleted-bundle-offers-table.sql` in Supabase
- [ ] Verify table created with: `SELECT * FROM deleted_bundle_offers LIMIT 1;`
- [ ] Test delete functionality
- [ ] Verify data archived correctly
- [ ] Plan future "Deleted Offers" management interface
