# Change: Stop Syncing expiry_dates from ERP During Product Sync

**Date:** 2026-04-30  
**Status:** Applied

---

## What Was Changed

**File:** `frontend/src/lib/components/desktop-interface/settings/ErpProductManager.svelte`  
**Function:** `syncProducts()` (~line 267)

### The Change

Before upserting each batch of products into Supabase, `expiry_dates` is now stripped from every product object. This means the `Sync Products` button **no longer overwrites** expiry dates stored in Aqura's database with data from the ERP.

### Before (original code)
```ts
// Step 2: Upsert this batch to Supabase
for (let i = 0; i < fetchedProducts.length; i += UPSERT_BATCH_SIZE) {
    const batch = fetchedProducts.slice(i, i + UPSERT_BATCH_SIZE);

    const { data: rpcResult, error: rpcError } = await supabase
        .rpc('upsert_erp_products_with_expiry', {
            p_products: batch
        });
    // ...
    syncStatus = {
        success: true,
        message: `⏳ Batch ${batchNumber}: ${i + batch.length}/${fetchedProducts.length} upserted ...`
    };
}
```

### After (current code)
```ts
// Step 2: Upsert this batch to Supabase (strip expiry_dates — managed manually, not from ERP)
const productsWithoutExpiry = fetchedProducts.map(({ expiry_dates, ...p }) => p);
for (let i = 0; i < productsWithoutExpiry.length; i += UPSERT_BATCH_SIZE) {
    const batch = productsWithoutExpiry.slice(i, i + UPSERT_BATCH_SIZE);

    const { data: rpcResult, error: rpcError } = await supabase
        .rpc('upsert_erp_products_with_expiry', {
            p_products: batch
        });
    // ...
    syncStatus = {
        success: true,
        message: `⏳ Batch ${batchNumber}: ${i + batch.length}/${productsWithoutExpiry.length} upserted ...`
    };
}
```

---

## Why It Was Changed

The ERP database may have stale or incorrect expiry dates. Expiry dates are now managed **manually** through the mobile Expiry Manager, and syncing from ERP was overwriting manually-set dates.

---

## What Is NOT Affected

- The **mobile Expiry Manager** still updates both ERP and Aqura when you save a date.
- The **desktop ERP Product Manager** inline expiry editor still works as before.
- All other product fields (barcode, names, unit, qty, is_base_unit) still sync normally.

---

## How to Revert

To restore the original behavior (expiry dates sync from ERP again):

1. Open `frontend/src/lib/components/desktop-interface/settings/ErpProductManager.svelte`
2. Find the `syncProducts()` function, locate this block:

```ts
// Step 2: Upsert this batch to Supabase (strip expiry_dates — managed manually, not from ERP)
const productsWithoutExpiry = fetchedProducts.map(({ expiry_dates, ...p }) => p);
for (let i = 0; i < productsWithoutExpiry.length; i += UPSERT_BATCH_SIZE) {
    const batch = productsWithoutExpiry.slice(i, i + UPSERT_BATCH_SIZE);
```

3. Replace it with:

```ts
// Step 2: Upsert this batch to Supabase
for (let i = 0; i < fetchedProducts.length; i += UPSERT_BATCH_SIZE) {
    const batch = fetchedProducts.slice(i, i + UPSERT_BATCH_SIZE);
```

4. Also find this line:
```ts
message: `⏳ Batch ${batchNumber}: ${i + batch.length}/${productsWithoutExpiry.length} upserted ...`
```
And change `productsWithoutExpiry.length` back to `fetchedProducts.length`.

That's it — no database changes needed, no migrations, no server restarts.
