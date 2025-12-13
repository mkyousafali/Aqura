# Realtime Tables - Enabling Checklist

## Status as of December 13, 2025

### ✅ Enabled
- [x] **products** - Main product catalog

### Required to Enable (For Customer Interface)
- [ ] **product_categories** - Category filtering
- [ ] **offer_products** - Percentage & special price offers
- [ ] **bogo_offer_rules** - Buy One Get One offers
- [ ] **offers** - Main offer configuration (start/end dates, active status)

---

## Quick Enable Instructions

### Via Supabase Dashboard
1. Login to https://app.supabase.com
2. Navigate to your **Aqura** project
3. Go to **Database** → **Replication** (left sidebar)
4. Find each table below and toggle **Enable** button:
   - product_categories
   - offer_products
   - bogo_offer_rules
   - offers

### Via SQL Command (Alternative)
Run these in SQL Editor under **Aqura** project:

```sql
-- Add tables to realtime publication
ALTER PUBLICATION supabase_realtime ADD TABLE product_categories;
ALTER PUBLICATION supabase_realtime ADD TABLE offer_products;
ALTER PUBLICATION supabase_realtime ADD TABLE bogo_offer_rules;
ALTER PUBLICATION supabase_realtime ADD TABLE offers;

-- Verify they're enabled
SELECT tablename FROM pg_publication_tables 
WHERE pubname = 'supabase_realtime' 
ORDER BY tablename;
```

---

## What Changes to Expect

### When Enabled
- Customers see **instant** product updates without refresh
- Offer badges appear/disappear immediately
- Price changes reflect in real-time
- Category list updates dynamically

### Example Scenarios
1. **Admin updates product price** → Customers see new price instantly
2. **Admin creates BOGO offer** → Badge appears on matching products instantly
3. **Admin adds new category** → Filter options update instantly
4. **Admin deletes offer** → Discount badges disappear instantly

---

## Performance Notes

### Current Implementation
- **Reload Type**: Full product list reload per event
- **Channels**: 3 independent channels (products, offers, categories)
- **Event Types**: INSERT, UPDATE, DELETE

### Optimization Available
If you experience performance issues:
1. Add debouncing (wait 500ms before reloading)
2. Implement selective updates (only update affected products)
3. Filter by branch_id if applicable

See `REALTIME_SETUP_GUIDE.md` for details.

---

## Verification Steps

### Confirm Realtime is Working

1. **Open Customer Products Page**
   - Go to http://localhost:5173/customer-interface/products

2. **Open Admin Panel in Another Window**
   - Login to admin interface

3. **Make a Change**
   - Update any product price
   - Create a new offer
   - Add a new category

4. **Check Customer Page**
   - Should update automatically **without refresh**
   - Check browser console for realtime logs

5. **Verify Console Logs**
   - Should see messages like:
     - `🔄 Product updated: PRD0001`
     - `📊 New offer created`
     - `🏷️ Product categories changed`

---

## Troubleshooting

### Not Seeing Updates?
1. Confirm realtime is **enabled** in Dashboard
2. Check browser console for errors
3. Verify Supabase client is connected
4. Check RLS policies (see below)

### RLS Policy Check
Make sure public/customer users can read from these tables:

```sql
-- Check product_categories policies
SELECT * FROM pg_policies 
WHERE tablename = 'product_categories';

-- Check offer_products policies
SELECT * FROM pg_policies 
WHERE tablename = 'offer_products';

-- Check bogo_offer_rules policies
SELECT * FROM pg_policies 
WHERE tablename = 'bogo_offer_rules';

-- Check offers policies
SELECT * FROM pg_policies 
WHERE tablename = 'offers';
```

All should have at least one **SELECT** policy that allows the role being used.

---

## Files Modified

### Frontend
- `/frontend/src/routes/customer-interface/products/+page.svelte`
  - Added 3 realtime channels
  - Now subscribes to 5 tables: products, offer_products, bogo_offer_rules, offers, product_categories
  - Lines 117-177 (onMount hook)

### Documentation
- `REALTIME_SETUP_GUIDE.md` - Comprehensive setup guide
- `REALTIME_TABLES_CHECKLIST.md` - This file

---

## Next Steps

1. **Enable realtime** for the 4 tables above
2. **Test** with the verification steps
3. **Monitor** console logs for realtime events
4. **(Optional)** Implement debouncing if needed

---

## Questions?

Check browser console (F12) for detailed logs:
```
✨ New product added, reloading products...
🔄 Product updated: PRD0001
📦 Offer product updated: OP123
🎁 BOGO offer updated: BOGO456
📊 New offer created: OFFER789
🏷️ Product categories changed, reloading categories...
```
