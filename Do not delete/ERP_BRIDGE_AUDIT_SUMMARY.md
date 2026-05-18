# ERP Bridge & Database Integration — Audit Summary

> Last audited: 2026-05-17

---

## Quick Stats

| Metric | Count |
|---|---|
| ERP Bridge callers (API routes + edge functions) | 9 |
| Direct SQL Server access points | 1 (bridge server only) |
| Frontend components with indirect ERP access | 8 |
| ERP-related Supabase tables | 6 |
| ERP-specific RPC functions | 4 |
| Hardcoded secrets found | 1 ⚠️ |

---

## Architecture Overview

```
┌─────────────────────────────────────────────┐
│              FRONTEND (SvelteKit)            │
│                                             │
│  Components → API Routes → ERP Bridge Proxy │
│              (erp-products/+server.ts)       │
└──────────────────────┬──────────────────────┘
                       │ HTTP + x-api-secret
                       ▼
┌─────────────────────────────────────────────┐
│   ERP BRIDGE SERVER (scripts/erp-bridge-    │
│   server.js) — runs on each branch machine  │
│   Exposed via Cloudflare Tunnel              │
└──────────────────────┬──────────────────────┘
                       │ mssql (TCP)
                       ▼
┌─────────────────────────────────────────────┐
│         SQL SERVER ERP DATABASE             │
│   Tables: InvProductItems, PrivilegeCards,  │
│           InvTransactionMaster              │
└─────────────────────────────────────────────┘
```

---

## ERP Bridge Callers

| File | What It Does |
|---|---|
| `supabase/functions/auto-sync-erp/index.ts` | Syncs product catalog from ERP → `erp_synced_products` |
| `supabase/functions/get-contact-bills/index.ts` | Aggregates loyalty card bills across all branches |
| `frontend/src/routes/api/erp-products/+server.ts` | Generic bridge proxy (all actions route through here) |
| `frontend/src/routes/api/batch-erp-check/+server.ts` | Checks if phone numbers exist in ERP PrivilegeCards |
| `frontend/src/routes/api/batch-bill-counts/+server.ts` | Batch bill counts + totals per contact |
| `frontend/src/routes/api/contact-bill-details/+server.ts` | Individual bill rows for a single contact |

---

## Indirect ERP Users (Read Synced Supabase Tables)

| Component | Table Used | Purpose |
|---|---|---|
| `ERPConnections.svelte` | `erp_connections` | Configure SQL Server credentials per branch |
| `ErpCredentialsModal.svelte` | `user_erp_credentials` | Manage per-user ERP login for mobile QR |
| `ErpProductManager.svelte` | `erp_synced_products` | Admin panel — view/manage synced products |
| `ErpProductsList.svelte` | `erp_synced_products` | Reusable product list with search |
| `ERPSyncButton.svelte` | via `sync-erp` API route | Trigger ERP invoice sync for receiving records |
| `ErpEntryManager.svelte` | `erp_synced_products` | Flyer/offer product name editor |
| `MobileErpModal.svelte` | `user_erp_credentials` | Build QR-encoded ERP login credentials |

---

## ERP Supabase Tables

| Table | Purpose |
|---|---|
| `erp_connections` | SQL Server credentials + Cloudflare tunnel URLs per branch |
| `erp_synced_products` | Product catalog synced from ERP (barcodes, names, units, expiry) |
| `erp_sync_logs` | Audit trail of every sync operation |
| `erp_daily_sales` | Daily sales aggregates from ERP *(no writer found — may be in separate repo)* |
| `user_erp_credentials` | Per-user ERP username/password for mobile QR auth |
| `branch_sync_config` | Branch-level Supabase tunnel config for erp-sync-app *(separate repo)* |

---

## ERP RPC Functions (Supabase/PostgreSQL)

| Function | Purpose |
|---|---|
| `upsert_erp_products_with_expiry(jsonb)` | Batch upsert products from ERP sync |
| `sync_erp_reference_for_receiving_record(uuid)` | Link ERP invoice ref to a receiving record |
| `check_erp_sync_status_for_record(uuid)` | Check if a receiving record's ERP ref is synced |
| `check_erp_sync_status()` | Overall sync completion % across all receiving records |

---

## Data Flow Diagrams

### Product Sync
```
SQL Server (InvProductItems)
  → Bridge /sync endpoint
  → auto-sync-erp edge function
  → upsert_erp_products_with_expiry() RPC
  → erp_synced_products table
  → ErpProductManager / ErpProductsList (display)
```

### Bill History (CRM)
```
Contact detail page
  → batch-bill-counts API route
  → Loads tunnel URLs from erp_connections
  → POST /query to each branch bridge (parallel)
  → InvTransactionMaster JOIN PrivilegeCards
  → Returns totals per branch → aggregated display
```

### Receiving Records ERP Reference
```
ReceivingRecordsWithSync.svelte
  → ERPSyncButton
  → receiving-records/sync-erp API
  → sync_erp_reference_for_receiving_record() RPC
  → Joins receiving_records → receiving_tasks → task_completions
  (no bridge involved — internal Supabase only)
```

### Mobile QR Login
```
user_erp_credentials table
  → MobileErpModal.svelte
  → QR Code: username + TAB + password + CR
  → Mobile scanner (keyboard wedge) auto-types into ERP login
```

---

## Risks & Action Items

| # | Risk | Severity | Location |
|---|---|---|---|
| 1 | Bridge API secret `aqura-erp-bridge-2026` is **hardcoded** in source code | HIGH | `erp-products/+server.ts` |
| 2 | `/query` endpoint accepts arbitrary SQL — no input parameterization audit done | HIGH | `erp-bridge-server.js` |
| 3 | `erp_daily_sales` table has no writer in this repo (may be in separate `erp-sync-app` repo) | MEDIUM | `erp_daily_sales` table |
| 4 | `erp_connections` RLS policy is `allow all authenticated` — any logged-in user can read credentials | MEDIUM | `erp_connections` table |
| 5 | Separate `erp-sync-app` repo referenced but not audited | LOW | `PRIVILEGE_CARDS_SYNC_REFERENCE.md` |

---

## Files with No ERP Usage (Confirmed Clean)

- `frontend/src/routes/api/auth/` — authentication only
- `frontend/src/lib/components/desktop-interface/master/sales/` — Supabase sales tables only
- `frontend/src/lib/components/desktop-interface/hr/` — HR/payroll, no ERP
- `frontend/src/lib/components/desktop-interface/master/finance/` — finance, no ERP
- `supabase/migrations/` non-ERP tables (leases, rent, users, branches)
- `desktop/` — app shell only
