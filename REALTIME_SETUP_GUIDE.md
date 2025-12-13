# Realtime Setup Guide for Customer Products Interface

## Overview
The customer products interface now uses realtime subscriptions to instantly reflect product, offer, and category changes without manual page refresh.

## Tables That Need Realtime Enabled

### ✅ Already Enabled
- **products** - Main product data (you've enabled this)

### 🔧 Recommended to Enable
These are the tables that affect what customers see on the products page:

1. **product_categories** (MEDIUM priority)
   - Affects category filtering on products page
   - When categories are added/updated/deleted, customers should see changes immediately
   - Subscribe to: INSERT, UPDATE, DELETE events

2. **offer_products** (HIGH priority)
   - Links products to percentage/special price offers
   - When offers are applied to products, prices update in real-time
   - Subscribe to: INSERT, UPDATE, DELETE events

3. **bogo_offer_rules** (HIGH priority)
   - Buy One Get One offers
   - When BOGO rules change, offer badges appear/disappear
   - Subscribe to: INSERT, UPDATE, DELETE events

4. **offers** (HIGH priority)
   - Main offer configuration (active, dates, names)
   - When offers become active/inactive, product display updates
   - Subscribe to: INSERT, UPDATE, DELETE events

### Optional (Lower Priority)
- **product_units** - Only if unit names change frequently
  - Current static mapping exists in code

## How to Enable Realtime in Supabase

### Method 1: Supabase Dashboard
1. Go to **Database** → **Replication** in Supabase Dashboard
2. For each table above, toggle the **Realtime** switch to ON
3. This enables the `postgres_changes` publication for that table

### Method 2: SQL Command
```sql
-- Enable realtime for critical tables
ALTER PUBLICATION supabase_realtime ADD TABLE product_categories;
ALTER PUBLICATION supabase_realtime ADD TABLE offer_products;
ALTER PUBLICATION supabase_realtime ADD TABLE bogo_offer_rules;
ALTER PUBLICATION supabase_realtime ADD TABLE offers;
```

### Method 3: PostgreSQL Admin Panel
- Execute the SQL commands above via your PostgreSQL client or Supabase SQL editor

## Current Implementation

The customer products page (`/customer-interface/products`) now has:

### Subscriptions Set Up
1. **Products Channel** - Monitors product table changes
   - Triggers: INSERT, UPDATE, DELETE
   - Filter: Specific branch (if applicable)

2. **Offers Channel** - Monitors offer-related tables
   - Tables: offer_products, bogo_offer_rules, offers
   - Triggers: INSERT, UPDATE, DELETE

3. **Categories Channel** - Monitors category changes
   - Table: product_categories
   - Triggers: INSERT, UPDATE, DELETE

### What Triggers a Reload
- Product added: New items appear in catalog
- Product updated: Prices, stock, images update instantly
- Product deleted: Item disappears from catalog
- Offer created/updated: Discount badges appear/change
- BOGO rule changed: Special offer indicators update
- Category changed: Filter options update

## Debouncing Strategy (Future Enhancement)

To prevent excessive reloads during bulk operations:

```typescript
// Add this to prevent reload spam during bulk updates
let reloadTimeout: NodeJS.Timeout;
function debouncedReload() {
  clearTimeout(reloadTimeout);
  reloadTimeout = setTimeout(() => {
    loadProducts();
  }, 500); // Wait 500ms for more changes before reloading
}
```

## Performance Considerations

### Current Design
- **Full reload** on any change (current implementation)
- Pros: Simple, always up-to-date
- Cons: Network traffic, client-side processing

### Optimization Ideas (Future)
1. **Selective updates**: Only update affected products
2. **Batch processing**: Collect changes for 2-5 seconds before updating
3. **Conditional loading**: Skip reload if change is for different branch
4. **Caching layer**: Compare new data with cached before reloading

## Monitoring Realtime Activity

Add this to your browser console to monitor realtime events:
```javascript
// In browser console
const debugLogs = [];
window.logRealtimeEvent = (event) => {
  debugLogs.push({
    timestamp: new Date().toISOString(),
    event: event
  });
  console.log(debugLogs.length, 'events logged');
};
```

## Testing Realtime

### Manual Testing
1. Open products page in browser
2. Open another tab/window with admin panel
3. Create/update/delete a product
4. Verify products page updates without refresh

### Automated Testing
```typescript
// Add to your test suite
describe('Realtime Products', () => {
  it('should reload products when product updates', async () => {
    // Subscribe to products page
    // Update a product in admin
    // Verify reload happened
  });
});
```

## Troubleshooting

### Realtime Not Working
1. Check table has realtime enabled in Supabase Dashboard
2. Check browser console for errors
3. Verify Supabase client is initialized correctly
4. Check RLS policies don't block reads

### Too Many Reloads
- See "Debouncing Strategy" above
- Check if multiple admins are editing simultaneously
- Consider batch processing approach

### Performance Issues
- Check network tab for reload frequency
- Consider implementing selective updates
- Add debouncing delay
- Check if pagination/filtering affects reload

## Summary Checklist

- [x] Products table realtime enabled
- [ ] product_categories realtime enabled
- [ ] offer_products realtime enabled
- [ ] bogo_offer_rules realtime enabled
- [ ] offers realtime enabled
- [ ] Customer products page subscriptions configured
- [ ] Test realtime functionality
- [ ] Monitor performance in production
- [ ] (Optional) Implement debouncing for bulk operations
- [ ] (Optional) Implement selective updates for optimization

## Code Location
- Main implementation: `/frontend/src/routes/customer-interface/products/+page.svelte`
- Lines: 107-151 (onMount hook with subscriptions)
- Channels: products-changes, offers-changes, categories-changes
