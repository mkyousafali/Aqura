# ERP Bridge Setup Guide — Complete End-to-End

> **Full step-by-step guide** covering everything from Cloudflare account creation to final testing. Follow from top to bottom. Nothing is skipped.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [What You Need Before Starting](#what-you-need-before-starting)
3. [PART A: One-Time Setup (Do Once)](#part-a-one-time-setup-do-once)
   - [A1. Create Cloudflare Account](#a1-create-cloudflare-account)
   - [A2. Add Your Domain to Cloudflare](#a2-add-your-domain-to-cloudflare)
   - [A3. Create Cloudflare Zero Trust Team](#a3-create-cloudflare-zero-trust-team)
   - [A4. Run Supabase Migrations](#a4-run-supabase-migrations)
4. [PART B: Per-Branch Setup](#part-b-per-branch-setup-repeat-for-each-branch)
   - [B1. Create the Tunnel in Cloudflare Dashboard](#b1-create-the-tunnel-in-cloudflare-dashboard)
   - [B2. Add a Published Route (Public Hostname)](#b2-add-a-published-route-public-hostname)
   - [B3. Install Node.js on the Branch Server](#b3-install-nodejs-on-the-branch-server)
   - [B4. Option A: Setup Wizard (Recommended)](#b4-option-a-setup-wizard-recommended)
   - [B4. Option B: Manual Setup](#b4-option-b-manual-setup)
   - [B5. Verify Everything Works](#b5-verify-everything-works)
   - [B6. Update Supabase with Tunnel URL](#b6-update-supabase-with-tunnel-url)
   - [B7. Test from the App](#b7-test-from-the-app)
5. [Branch Reference Table](#branch-reference-table)
6. [Quick Checklist Per Branch](#quick-checklist-per-branch)
7. [Troubleshooting](#troubleshooting)
8. [Important Details](#important-details)
9. [Files Reference](#files-reference)
10. [How to Update bridge server.js](#how-to-update-bridge-serverjs)

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                        HOW IT ALL CONNECTS                          │
│                                                                     │
│  📱 User's Phone/PC (PWA)                                          │
│      │                                                              │
│      ▼                                                              │
│  ☁️  Vercel (aqura app frontend + serverless API)                   │
│      │  frontend/src/routes/api/erp-products/+server.ts             │
│      │  This is a thin proxy — it forwards requests to the tunnel   │
│      │                                                              │
│      ▼  HTTPS request to:                                           │
│  🌐 Cloudflare Tunnel  (e.g. https://erp-branch3.urbanaqura.com)   │
│      │  Cloudflare receives the request and routes it through       │
│      │  an encrypted tunnel to the branch server                    │
│      │                                                              │
│      ▼  Tunnel connection (encrypted, outbound from server)         │
│  🖥️  Branch Server (Windows + SQL Server)                           │
│      │  cloudflared.exe is running as a Windows service             │
│      │  It receives the tunneled request and forwards to localhost   │
│      │                                                              │
│      ▼  HTTP request to localhost:3333                              │
│  🔌 Bridge API (Node.js Express server on port 3333)               │
│      │  C:\erp-api\server.js — runs as Windows service              │
│      │  Authenticates with x-api-secret header                      │
│      │                                                              │
│      ▼  SQL query                                                   │
│  🗄️  SQL Server (ERP Database, e.g. URBAN2_2025)                    │
│      Returns product data, barcodes, expiry dates                   │
└─────────────────────────────────────────────────────────────────────┘
```

### Why do we need all this?

The Aqura PWA runs on **Vercel** (cloud). The ERP database is on a **local SQL Server** inside each branch (private network, no public IP). Vercel cannot reach `192.168.0.X` directly. So we use:

1. **Cloudflare Tunnel** — creates a secure outbound connection from the branch server to Cloudflare. No need to open ports or have a public IP.
2. **Bridge API** — a small Node.js server that sits on the branch machine, accepts HTTP requests from the tunnel, and queries SQL Server locally.
3. **Vercel Proxy** — the app's API route (`/api/erp-products`) forwards requests to the tunnel URL instead of connecting to SQL directly.

---

## What You Need Before Starting

| Item | Details |
|------|---------|
| **Cloudflare account** | Free account at cloudflare.com |
| **Domain name** | A domain managed in Cloudflare DNS (we use `urbanaqura.com`) |
| **Branch server access** | RDP or physical access to each branch's Windows server |
| **SQL Server** | Running on each branch server with the ERP database |
| **SQL credentials** | Username & password for SQL Server (we use `sa` / `Polosys*123`) |
| **Internet on servers** | Each branch server needs internet to establish the tunnel |
| **Admin access** | You need to run CMD as Administrator on each server |

---

# PART A: One-Time Setup (Do Once)

These steps only need to be done **once**, not per branch.

---

## A1. Create Cloudflare Account

> **Already done?** Our account is `urbanaqura`. Skip to A4 if this is already set up.

1. Go to: **https://dash.cloudflare.com/sign-up**
2. Enter your email and create a password
3. Verify your email
4. You're now on the Cloudflare dashboard

---

## A2. Add Your Domain to Cloudflare

> **Already done?** `urbanaqura.com` is already on Cloudflare. Skip to A3.

1. In the Cloudflare dashboard, click **"+ Add a site"**
2. Enter your domain: `urbanaqura.com`
3. Select the **Free** plan → click **Continue**
4. Cloudflare scans your DNS records → click **Continue**
5. Cloudflare gives you two **nameservers** like:
   ```
   ada.ns.cloudflare.com
   bert.ns.cloudflare.com
   ```
6. Go to your **domain registrar** (where you bought the domain)
7. Change the nameservers to the ones Cloudflare gave you
8. Wait for propagation (usually 5 minutes to 24 hours)
9. Back in Cloudflare dashboard, click **"Check nameservers"**
10. Once verified, you'll see ✅ Active

---

## A3. Create Cloudflare Zero Trust Team

> **Already done?** Our team is `urbanaqura`. Skip to A4.

1. Go to: **https://one.dash.cloudflare.com/**
2. It will ask you to create a **team name** — enter: `urbanaqura`
3. Select the **Free** plan (includes unlimited tunnels, up to 50 users)
4. Complete the setup wizard
5. You're now in the Zero Trust dashboard

### Verify you can see Tunnels

1. In the Zero Trust dashboard left sidebar → **Networks** → **Tunnels**
2. You should see the Tunnels page (empty if no tunnels created yet)

---

## A4. Run Supabase Migrations

Run these SQL statements in the **Supabase SQL Editor** (https://supabase.com/dashboard → your project → SQL Editor). Run each block separately.

### Migration 1: Create `erp_synced_products` table

```sql
-- Create erp_synced_products table
-- Stores product barcodes synced from ERP SQL Server with unit details

CREATE TABLE IF NOT EXISTS erp_synced_products (
  id SERIAL PRIMARY KEY,
  barcode VARCHAR(50) NOT NULL UNIQUE,
  auto_barcode VARCHAR(50),
  parent_barcode VARCHAR(50),
  product_name_en VARCHAR(500),
  product_name_ar VARCHAR(500),
  unit_name VARCHAR(100),
  unit_qty DECIMAL(18,6) DEFAULT 1,
  is_base_unit BOOLEAN DEFAULT false,
  synced_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_erp_synced_products_barcode ON erp_synced_products(barcode);
CREATE INDEX IF NOT EXISTS idx_erp_synced_products_parent_barcode ON erp_synced_products(parent_barcode);
CREATE INDEX IF NOT EXISTS idx_erp_synced_products_product_name_en ON erp_synced_products(product_name_en);

-- Enable RLS
ALTER TABLE erp_synced_products ENABLE ROW LEVEL SECURITY;

-- Permissive policy
CREATE POLICY "Allow all access to erp_synced_products"
  ON erp_synced_products FOR ALL USING (true) WITH CHECK (true);

-- Grant access
GRANT ALL ON erp_synced_products TO authenticated;
GRANT ALL ON erp_synced_products TO service_role;
GRANT ALL ON erp_synced_products TO anon;
GRANT USAGE, SELECT ON SEQUENCE erp_synced_products_id_seq TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE erp_synced_products_id_seq TO service_role;
GRANT USAGE, SELECT ON SEQUENCE erp_synced_products_id_seq TO anon;
```

### Migration 2: Add `expiry_dates` JSONB column + upsert RPC

```sql
-- Add expiry_dates JSONB column
ALTER TABLE public.erp_synced_products
ADD COLUMN IF NOT EXISTS expiry_dates jsonb NULL DEFAULT '[]'::jsonb;

-- Index for GIN queries
CREATE INDEX IF NOT EXISTS idx_erp_synced_products_expiry_dates
ON public.erp_synced_products USING gin (expiry_dates);

-- RPC function: upsert products with expiry date merge
CREATE OR REPLACE FUNCTION upsert_erp_products_with_expiry(
  p_products jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_inserted int := 0;
  v_updated int := 0;
  v_product jsonb;
  v_existing_expiry jsonb;
  v_new_expiry jsonb;
  v_merged_expiry jsonb;
  v_branch_id bigint;
BEGIN
  FOR v_product IN SELECT * FROM jsonb_array_elements(p_products)
  LOOP
    v_new_expiry := COALESCE(v_product->'expiry_dates', '[]'::jsonb);

    -- Extract the branch_id from the first entry
    v_branch_id := NULL;
    IF jsonb_array_length(v_new_expiry) > 0 THEN
      v_branch_id := (v_new_expiry->0->>'branch_id')::bigint;
    END IF;

    -- Try to get existing record
    SELECT expiry_dates INTO v_existing_expiry
    FROM erp_synced_products
    WHERE barcode = v_product->>'barcode';

    IF v_existing_expiry IS NOT NULL THEN
      -- Merge: remove old entries for this branch, add new ones
      IF v_branch_id IS NOT NULL THEN
        SELECT COALESCE(jsonb_agg(elem), '[]'::jsonb)
        INTO v_merged_expiry
        FROM jsonb_array_elements(v_existing_expiry) AS elem
        WHERE (elem->>'branch_id')::bigint IS DISTINCT FROM v_branch_id;
      ELSE
        v_merged_expiry := v_existing_expiry;
      END IF;
      v_merged_expiry := v_merged_expiry || v_new_expiry;

      -- Update the record
      UPDATE erp_synced_products
      SET product_name_en = COALESCE(v_product->>'product_name_en', product_name_en),
          product_name_ar = COALESCE(v_product->>'product_name_ar', product_name_ar),
          auto_barcode = COALESCE(v_product->>'auto_barcode', auto_barcode),
          parent_barcode = COALESCE(v_product->>'parent_barcode', parent_barcode),
          unit_name = COALESCE(v_product->>'unit_name', unit_name),
          unit_qty = COALESCE((v_product->>'unit_qty')::decimal, unit_qty),
          is_base_unit = COALESCE((v_product->>'is_base_unit')::boolean, is_base_unit),
          expiry_dates = v_merged_expiry,
          synced_at = now()
      WHERE barcode = v_product->>'barcode';
      v_updated := v_updated + 1;
    ELSE
      -- Insert new
      INSERT INTO erp_synced_products (
        barcode, auto_barcode, parent_barcode, product_name_en, product_name_ar,
        unit_name, unit_qty, is_base_unit, expiry_dates
      ) VALUES (
        v_product->>'barcode', v_product->>'auto_barcode', v_product->>'parent_barcode',
        v_product->>'product_name_en', v_product->>'product_name_ar',
        v_product->>'unit_name', COALESCE((v_product->>'unit_qty')::decimal, 1),
        COALESCE((v_product->>'is_base_unit')::boolean, false), v_new_expiry
      );
      v_inserted := v_inserted + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'inserted', v_inserted,
    'updated', v_updated,
    'total', v_inserted + v_updated
  );
END;
$$;
```

### Migration 3: Add `tunnel_url` column to `erp_connections`

```sql
-- Add tunnel_url column to erp_connections
ALTER TABLE erp_connections
ADD COLUMN IF NOT EXISTS tunnel_url TEXT;

COMMENT ON COLUMN erp_connections.tunnel_url IS 'Cloudflare Tunnel URL for the ERP bridge API on this branch server (e.g. https://erp-branch3.urbanaqura.com)';
```

**Done!** You only run these migrations once. Now proceed to Part B for each branch.

---

# PART B: Per-Branch Setup (Repeat for Each Branch)

Do these steps for **every branch** you want to connect.

---

## B1. Create the Tunnel in Cloudflare Dashboard

Each branch needs its **own tunnel**. Here's how to create one:

1. Open your browser and go to: **https://one.dash.cloudflare.com/**
2. Log in with your Cloudflare account
3. Make sure you're in the correct team: **urbanaqura** (shown in the top-left)
4. In the left sidebar, click: **Networks** → **Tunnels**
5. Click the blue **"+ Create a tunnel"** button
6. You'll see two options. Select: **"Cloudflared"** → click **Next**
7. Enter a name for the tunnel:
   ```
   erp-branchX
   ```
   Replace X with the branch number. Examples:
   - Branch 1 → `erp-branch1`
   - Branch 2 → `erp-branch2`
   - Branch 3 → `erp-branch3` *(already created)*
   - Branch 4 → `erp-branch4`
   - Branch 5 → `erp-branch5`

8. Click **"Save tunnel"**

9. On the next page ("Install and run a connector"), you'll see tabs for different operating systems. Click: **Windows** → **64-bit**

10. You'll see an install command containing a **token**. The token is the long string that starts with `eyJ...`. It looks like this:
    ```
    cloudflared.exe service install eyJhIjoiMWIxZmUzY2Q2MjkwMDU3OWE0YTJiNDFhYjg0ODI5NTgiLCJ0IjoiMTgz...
    ```
    **Copy the ENTIRE token** (the part after `service install`). You'll need this in step B4.

11. **Do NOT click "Next" or close this page yet** — you need to configure the route first (Step B2).

---

## B2. Add a Published Route (Public Hostname)

Still in the Cloudflare dashboard, on the same tunnel config page:

1. Click the **"Public Hostname"** tab (or you may already be on it after creating the tunnel)
2. Click **"+ Add a public hostname"**
3. Fill in these fields:

   | Field | Value | Example |
   |-------|-------|---------|
   | **Subdomain** | `erp-branchX` | `erp-branch1` |
   | **Domain** | `urbanaqura.com` *(select from dropdown)* | `urbanaqura.com` |
   | **Path** | *(leave empty)* | |
   | **Type** | `HTTP` | `HTTP` |
   | **URL** | `localhost:3333` | `localhost:3333` |

   > **IMPORTANT:** The Type must be **HTTP** (not HTTPS). Cloudflare handles SSL on the outside. The bridge API inside the server runs plain HTTP on port 3333.

4. Click **"Save hostname"**

5. Now click **"Next"** (or navigate back to the Tunnels list)

### What this does

This tells Cloudflare: "When someone visits `https://erp-branch1.urbanaqura.com`, route that request through this tunnel to `localhost:3333` on the connected server."

The tunnel is now created but shows **Status: Connecting** or **Down** — that's expected because we haven't installed cloudflared on the server yet. We'll do that next.

---

## B3. Skip to B4 if Using the Aqura-Data-Manager Folder

> If you have the **Aqura-Data-Manager** folder, **skip B3 entirely** — the Setup.bat handles Node.js installation automatically.

Only follow B3 if you're doing things manually (Option B).

### Install Node.js on the Branch Server (Manual Only)

RDP into the branch server (or sit at it physically). You need a **Windows** machine that has SQL Server running with the ERP database.

### Open Admin CMD

1. Click the Windows Start menu
2. Type `cmd`
3. **Right-click** on "Command Prompt" → select **"Run as administrator"**
4. Click **Yes** on the UAC prompt

> ⚠️ You **MUST** run as admin. Service installation will fail without admin rights.

### Check if Node.js is already installed

```cmd
node --version
```

- If you see something like `v20.11.1` → Node.js is already installed, skip to B4
- If you see `'node' is not recognized` → install it below

### Download and install Node.js

```cmd
:: Download the Node.js MSI installer
curl -o C:\node-setup.msi https://nodejs.org/dist/v20.11.1/node-v20.11.1-x64.msi

:: Run the installer (a GUI window will appear)
msiexec /i C:\node-setup.msi
```

A setup wizard window opens:
1. Click **Next**
2. Accept the license → **Next**
3. Keep default install path → **Next**
4. Keep default features → **Next**
5. Click **Install**
6. Click **Finish**

**IMPORTANT:** After installing, **close the CMD window** and open a **new Admin CMD** (same steps as above). This is needed so the PATH variable updates.

### Verify installation

```cmd
node --version
npm --version
```

Expected output: `v20.11.1` (or similar) and `10.x.x`

---

## B4. Option A: Aqura-Data-Manager Folder (Recommended — Easiest)

The **Aqura-Data-Manager** folder is a self-contained package. Just copy the folder to the branch server and double-click `Setup.bat`. It handles **everything automatically**:

- ✅ Auto-elevates to Administrator (UAC prompt)
- ✅ Checks if Node.js is installed → downloads and installs it silently if not
- ✅ Downloads cloudflared.exe if not present
- ✅ Copies the wizard to C:\erp-api
- ✅ Opens the wizard in your browser

### What's in the folder

```
Aqura-Data-Manager/
  ├── Setup.bat          ← Double-click this
  ├── setup-wizard.js    ← The wizard (don't run directly)
  └── README.txt         ← Instructions
```

### Step 1: Copy the folder to the branch server

Copy the entire **Aqura-Data-Manager** folder to the branch server using:
- **USB drive** (recommended)
- Shared network folder
- Any other method

Put it anywhere — Desktop, C:\, doesn't matter. The folder is portable.

### Step 2: Double-click Setup.bat

1. On the branch server, open the **Aqura-Data-Manager** folder
2. **Double-click `Setup.bat`**
3. Windows will ask for admin permission → click **"Yes"**
4. A black CMD window opens showing progress:
   ```
   [1/5] Checking Node.js...        ✅ Node.js v20.11.1 is already installed
   [2/5] Creating C:\erp-api...     ✅ C:\erp-api ready
   [3/5] Copying setup wizard...    ✅ Wizard copied
   [4/5] Checking cloudflared...    ✅ cloudflared.exe downloaded
   [5/5] Starting setup wizard...   🌐 Browser opens automatically
   ```

5. Your browser opens at `http://localhost:9999` with the wizard

> **If Node.js is not installed**, the bat file downloads and installs it silently (takes 1-2 minutes). No manual steps needed.

### Step 3: Fill in the wizard

Fill in all fields:

| Field | What to enter | Example |
|-------|--------------|---------|
| **Branch Name** | The branch display name | `Urban Market 02` |
| **App Branch ID** | The `branch_id` number from the Aqura app | `5` |
| **SQL Server Address** | Usually `localhost` if SQL is on this machine | `localhost` |
| **Database Name** | The ERP database name | `URBAN2_2025` |
| **SQL Username** | SQL Server login | `sa` |
| **SQL Password** | SQL Server password | `Polosys*123` |
| **Cloudflare Tunnel Token** | The long token you copied in Step B1 | `eyJhIjoiMWIx...` |
| **Bridge API Port** | Keep as `3333` unless you have a conflict | `3333` |
| **Tunnel Subdomain** | Must match what you entered in Step B2 | `erp-branch3` |

### Step 5: Test SQL connection (optional but recommended)

Click the **"🔍 Test SQL Connection"** button. You should see:
- ✅ **Connected! X products found** → SQL is working, proceed
- ❌ **Connection failed** → Check your SQL credentials, make sure SQL Server is running

### Step 6: Install everything

Click **"Install Everything →"**

The wizard runs 9 automated steps. You'll see a live progress log:

| # | Step | What it does |
|---|------|-------------|
| 1 | Create directory | Creates `C:\erp-api` if needed |
| 2 | npm install | Installs `express`, `mssql`, `cors`, `node-windows` |
| 3 | Write server.js | Creates the bridge API with your SQL config baked in |
| 4 | Write service scripts | Creates `install-service.js`, `uninstall-service.js`, `config.json` |
| 5 | Download cloudflared | Downloads `cloudflared.exe` to `C:\cloudflared.exe` (skips if already there) |
| 6 | Install tunnel service | Runs `cloudflared.exe service install TOKEN` → creates Windows service |
| 7 | Install bridge service | Uses `node-windows` to install bridge API as Windows service |
| 8 | Firewall rule | Adds rule to allow port 3333 through Windows Firewall |
| 9 | Health check | Tests `http://localhost:3333/health` |

### Step 7: Done!

If all steps passed, you'll see the **"✅ Setup Complete!"** screen with:
- **Status cards** showing both services running
- **Test URL** — click it to verify the tunnel works
- **Supabase SQL** — the exact UPDATE command to run (copy it)

**You can now close the wizard** (Ctrl+C in the CMD window, or click "Close Wizard").

> **Skip to Step B5** to verify everything.

---

## B4. Option B: Manual Setup

If the wizard doesn't work or you prefer manual control, follow these steps.

### Step 1: Create folder and install dependencies

In Admin CMD:

```cmd
mkdir C:\erp-api
cd C:\erp-api
npm init -y
npm install express mssql cors node-windows
```

### Step 2: Create server.js

```cmd
notepad C:\erp-api\server.js
```

Paste the following code. **Edit the CONFIGURATION section** for this branch:

```javascript
const express = require('express');
const sql = require('mssql');
const cors = require('cors');

// ========== CONFIGURATION — EDIT FOR THIS BRANCH ==========
const SQL_SERVER = 'localhost';
const SQL_DATABASE = 'URBAN2_2025';    // <-- Change per branch
const SQL_USER = 'sa';
const SQL_PASSWORD = 'Polosys*123';    // <-- Change if different
const API_SECRET = 'aqura-erp-bridge-2026';
const PORT = 3333;
// ===========================================================

const app = express();
app.use(cors());
app.use(express.json({ limit: '50mb' }));

const sqlConfig = {
  user: SQL_USER, password: SQL_PASSWORD, server: SQL_SERVER, database: SQL_DATABASE,
  options: { encrypt: false, trustServerCertificate: true },
  pool: { max: 10, min: 0, idleTimeoutMillis: 30000 },
  connectionTimeout: 15000, requestTimeout: 120000
};

let pool = null;
async function getPool() {
  if (!pool) {
    pool = await sql.connect(sqlConfig);
    pool.on('error', (err) => { console.error('SQL Pool Error:', err); pool = null; });
  }
  return pool;
}

function authenticate(req, res, next) {
  if (req.headers['x-api-secret'] !== API_SECRET) return res.status(401).json({ error: 'Unauthorized' });
  next();
}

app.get('/health', async (req, res) => {
  try {
    const p = await getPool(); await p.request().query('SELECT 1 AS ok');
    res.json({ status: 'healthy', database: SQL_DATABASE });
  } catch (err) { pool = null; res.status(500).json({ status: 'unhealthy', error: err.message }); }
});

app.post('/test', authenticate, async (req, res) => {
  try {
    const p = await getPool();
    const counts = await p.request().query(`
      SELECT
        (SELECT COUNT(*) FROM ProductBatches WHERE MannualBarcode IS NOT NULL AND MannualBarcode != '') AS ManualBarcodes,
        (SELECT COUNT(*) FROM ProductBatches WHERE AutoBarcode IS NOT NULL AND AutoBarcode != '') AS AutoBarcodes,
        (SELECT COUNT(*) FROM ProductBatches WHERE Unit2Barcode IS NOT NULL AND Unit2Barcode != '') AS Unit2Barcodes,
        (SELECT COUNT(*) FROM ProductBatches WHERE Unit3Barcode IS NOT NULL AND Unit3Barcode != '') AS Unit3Barcodes,
        (SELECT COUNT(*) FROM ProductUnits WHERE BarCode IS NOT NULL AND BarCode != '') AS UnitBarcodes,
        (SELECT COUNT(*) FROM ProductBarcodes WHERE Barcode IS NOT NULL AND Barcode != '') AS ExtraBarcodes,
        (SELECT COUNT(DISTINCT ProductID) FROM Products) AS TotalProducts,
        (SELECT COUNT(*) FROM ProductBatches) AS TotalBatches,
        (SELECT COUNT(*) FROM (
          SELECT CAST(MannualBarcode AS NVARCHAR(100)) as bc FROM ProductBatches WHERE MannualBarcode IS NOT NULL AND MannualBarcode != ''
          UNION SELECT CAST(AutoBarcode AS NVARCHAR(100)) FROM ProductBatches WHERE AutoBarcode IS NOT NULL AND AutoBarcode != ''
          UNION SELECT CAST(Unit2Barcode AS NVARCHAR(100)) FROM ProductBatches WHERE Unit2Barcode IS NOT NULL AND Unit2Barcode != ''
          UNION SELECT CAST(Unit3Barcode AS NVARCHAR(100)) FROM ProductBatches WHERE Unit3Barcode IS NOT NULL AND Unit3Barcode != ''
          UNION SELECT CAST(BarCode AS NVARCHAR(100)) FROM ProductUnits WHERE BarCode IS NOT NULL AND BarCode != ''
          UNION SELECT CAST(Barcode AS NVARCHAR(100)) FROM ProductBarcodes WHERE Barcode IS NOT NULL AND Barcode != ''
        ) u) AS UniqueBarcodes
    `);
    const c = counts.recordset[0];
    res.json({
      success: true, message: 'Connection successful!',
      counts: {
        manualBarcodes: c.ManualBarcodes, autoBarcodes: c.AutoBarcodes,
        unit2Barcodes: c.Unit2Barcodes, unit3Barcodes: c.Unit3Barcodes,
        unitBarcodes: c.UnitBarcodes, extraBarcodes: c.ExtraBarcodes,
        totalProducts: c.TotalProducts, totalBatches: c.TotalBatches,
        totalAll: c.ManualBarcodes + c.AutoBarcodes + c.Unit2Barcodes + c.Unit3Barcodes + c.UnitBarcodes + c.ExtraBarcodes,
        uniqueBarcodes: c.UniqueBarcodes
      }
    });
  } catch (err) { pool = null; res.json({ success: false, message: 'Connection failed: ' + err.message }); }
});

app.post('/sync', authenticate, async (req, res) => {
  try {
    const { erpBranchId, appBranchId } = req.body;
    const p = await getPool();
    const baseProductsResult = await p.request().query("SELECT pb.ProductBatchID, pb.ProductID, pb.AutoBarcode, pb.MannualBarcode, pb.Unit2Barcode, pb.Unit3Barcode, pb.ExpiryDate, pb.BranchID, p.ProductName, p.ItemNameinSecondLanguage FROM ProductBatches pb INNER JOIN Products p ON pb.ProductID = p.ProductID WHERE (pb.MannualBarcode IS NOT NULL AND pb.MannualBarcode != '') OR (pb.AutoBarcode IS NOT NULL AND pb.AutoBarcode != '') OR (pb.Unit2Barcode IS NOT NULL AND pb.Unit2Barcode != '') OR (pb.Unit3Barcode IS NOT NULL AND pb.Unit3Barcode != '')");
    const baseProducts = baseProductsResult.recordset;
    const unitsResult = await p.request().query("SELECT pu.ProductBatchID, pu.UnitID, pu.MultiFactor, ISNULL(pu.BarCode, '') as BarCode, pu.Sprice, u.UnitName FROM ProductUnits pu INNER JOIN UnitOfMeasures u ON pu.UnitID = u.UnitID ORDER BY pu.ProductBatchID, pu.MultiFactor");
    const allUnits = unitsResult.recordset;
    const extraBarcodesResult = await p.request().query("SELECT pbc.ProductBatchID, pbc.Barcode, pbc.UnitID, ISNULL(u.UnitName, '') as UnitName, pb.MannualBarcode, pb.AutoBarcode, pb.ExpiryDate, pb.BranchID, p.ProductName, p.ItemNameinSecondLanguage FROM ProductBarcodes pbc INNER JOIN ProductBatches pb ON pbc.ProductBatchID = pb.ProductBatchID INNER JOIN Products p ON pb.ProductID = p.ProductID LEFT JOIN UnitOfMeasures u ON pbc.UnitID = u.UnitID WHERE pbc.Barcode IS NOT NULL AND pbc.Barcode != ''");
    const extraBarcodes = extraBarcodesResult.recordset;
    const products = []; const addedBarcodes = new Set(); const expiryMap = new Map();
    function addExpiryEntry(barcode, expiryDate, erpBranchIdFromRow) {
      if (!barcode) return;
      const expStr = expiryDate ? new Date(expiryDate).toISOString().split('T')[0] : null;
      if (!expStr || expStr === '1900-01-01' || expStr === '2000-01-01') return;
      const entry = { expiry_date: expStr };
      if (appBranchId) entry.branch_id = appBranchId;
      if (erpBranchId) entry.erp_branch_id = erpBranchId;
      if (erpBranchIdFromRow != null) entry.erp_row_branch_id = Number(erpBranchIdFromRow);
      if (!expiryMap.has(barcode)) expiryMap.set(barcode, []);
      const existing = expiryMap.get(barcode);
      if (!existing.some(e => e.expiry_date === expStr && e.branch_id === entry.branch_id)) existing.push(entry);
    }
    for (const bp of baseProducts) {
      ['MannualBarcode','AutoBarcode','Unit2Barcode','Unit3Barcode'].forEach(k => {
        const bc = String(bp[k] || '').trim(); if (bc) addExpiryEntry(bc, bp.ExpiryDate, bp.BranchID);
      });
    }
    for (const u of allUnits) {
      const bc = String(u.BarCode || '').trim(); if (!bc) continue;
      const parent = baseProducts.find(bp => String(bp.ProductBatchID) === String(u.ProductBatchID));
      if (parent) addExpiryEntry(bc, parent.ExpiryDate, parent.BranchID);
    }
    for (const eb of extraBarcodes) { const bc = String(eb.Barcode || '').trim(); if (bc) addExpiryEntry(bc, eb.ExpiryDate, eb.BranchID); }
    const unitsByBatchId = new Map();
    for (const u of allUnits) { const bid = String(u.ProductBatchID); if (!unitsByBatchId.has(bid)) unitsByBatchId.set(bid, []); unitsByBatchId.get(bid).push(u); }
    for (const bp of baseProducts) {
      const pu = unitsByBatchId.get(String(bp.ProductBatchID)) || [];
      const baseUnit = pu.find(u => parseFloat(u.MultiFactor) === 1) || pu[0];
      const parentBarcode = String(bp.MannualBarcode || bp.AutoBarcode || '').trim();
      const ubm = new Map(); for (const u of pu) { const bc = String(u.BarCode||'').trim(); if (bc) ubm.set(bc, u); }
      const manualBC = String(bp.MannualBarcode || '').trim();
      if (manualBC && !addedBarcodes.has(manualBC)) { const mu = ubm.get(manualBC); products.push({ barcode: manualBC, auto_barcode: String(bp.AutoBarcode||'').trim(), parent_barcode: parentBarcode, product_name_en: bp.ProductName||'', product_name_ar: bp.ItemNameinSecondLanguage||'', unit_name: mu ? mu.UnitName : (baseUnit ? baseUnit.UnitName : ''), unit_qty: mu ? (parseFloat(mu.MultiFactor)||1) : 1, is_base_unit: true, expiry_dates: expiryMap.get(manualBC)||[] }); addedBarcodes.add(manualBC); }
      const autoBC = String(bp.AutoBarcode || '').trim();
      if (autoBC && !addedBarcodes.has(autoBC)) { if (!manualBC) { const mu = ubm.get(autoBC); products.push({ barcode: autoBC, auto_barcode: autoBC, parent_barcode: parentBarcode, product_name_en: bp.ProductName||'', product_name_ar: bp.ItemNameinSecondLanguage||'', unit_name: mu ? mu.UnitName : (baseUnit ? baseUnit.UnitName : ''), unit_qty: mu ? (parseFloat(mu.MultiFactor)||1) : 1, is_base_unit: true, expiry_dates: expiryMap.get(autoBC)||[] }); } addedBarcodes.add(autoBC); }
      const unit2BC = String(bp.Unit2Barcode || '').trim();
      if (unit2BC && !addedBarcodes.has(unit2BC)) { const mu = ubm.get(unit2BC); products.push({ barcode: unit2BC, auto_barcode: autoBC, parent_barcode: parentBarcode, product_name_en: bp.ProductName||'', product_name_ar: bp.ItemNameinSecondLanguage||'', unit_name: mu ? mu.UnitName : '', unit_qty: mu ? (parseFloat(mu.MultiFactor)||1) : 1, is_base_unit: false, expiry_dates: expiryMap.get(unit2BC)||[] }); addedBarcodes.add(unit2BC); }
      const unit3BC = String(bp.Unit3Barcode || '').trim();
      if (unit3BC && !addedBarcodes.has(unit3BC)) { const mu = ubm.get(unit3BC); products.push({ barcode: unit3BC, auto_barcode: autoBC, parent_barcode: parentBarcode, product_name_en: bp.ProductName||'', product_name_ar: bp.ItemNameinSecondLanguage||'', unit_name: mu ? mu.UnitName : '', unit_qty: mu ? (parseFloat(mu.MultiFactor)||1) : 1, is_base_unit: false, expiry_dates: expiryMap.get(unit3BC)||[] }); addedBarcodes.add(unit3BC); }
      for (const unit of pu) { const ubc = String(unit.BarCode||'').trim(); if (!ubc || addedBarcodes.has(ubc)) continue; products.push({ barcode: ubc, auto_barcode: autoBC, parent_barcode: parentBarcode, product_name_en: bp.ProductName||'', product_name_ar: bp.ItemNameinSecondLanguage||'', unit_name: unit.UnitName||'', unit_qty: parseFloat(unit.MultiFactor)||1, is_base_unit: parseFloat(unit.MultiFactor)===1, expiry_dates: expiryMap.get(ubc)||[] }); addedBarcodes.add(ubc); }
    }
    for (const eb of extraBarcodes) { const ebc = String(eb.Barcode||'').trim(); if (!ebc || addedBarcodes.has(ebc)) continue; products.push({ barcode: ebc, auto_barcode: String(eb.AutoBarcode||'').trim(), parent_barcode: String(eb.MannualBarcode||'').trim(), product_name_en: eb.ProductName||'', product_name_ar: eb.ItemNameinSecondLanguage||'', unit_name: eb.UnitName||'', unit_qty: 1, is_base_unit: false, expiry_dates: expiryMap.get(ebc)||[] }); addedBarcodes.add(ebc); }
    res.json({ success: true, products, totalProducts: products.length, baseProductsCount: baseProducts.length, message: 'Fetched ' + products.length + ' barcodes from ' + baseProducts.length + ' products' });
  } catch (err) { pool = null; console.error('Sync error:', err); res.status(500).json({ success: false, error: err.message }); }
});

app.post('/update-expiry', authenticate, async (req, res) => {
  try {
    const { barcode, newExpiryDate } = req.body;
    const p = await getPool();
    const findResult = await p.request().input('barcode', sql.NVarChar, barcode).query("SELECT DISTINCT pb.ProductBatchID FROM ProductBatches pb WHERE pb.MannualBarcode = @barcode OR CAST(pb.AutoBarcode AS NVARCHAR(100)) = @barcode OR pb.Unit2Barcode = @barcode OR pb.Unit3Barcode = @barcode UNION SELECT DISTINCT pu.ProductBatchID FROM ProductUnits pu WHERE pu.BarCode = @barcode UNION SELECT DISTINCT pbc.ProductBatchID FROM ProductBarcodes pbc WHERE pbc.Barcode = @barcode");
    const batchIds = findResult.recordset.map(r => r.ProductBatchID);
    if (batchIds.length === 0) return res.json({ success: false, error: 'Barcode ' + barcode + ' not found in ERP' });
    const idList = batchIds.map(id => "'" + id + "'").join(',');
    const safeDateStr = newExpiryDate.replace(/-/g, '');
    const updateResult = await p.request().input('newExpiry', sql.NVarChar, safeDateStr).query("UPDATE ProductBatches SET ExpiryDate = CONVERT(datetime, @newExpiry, 112) WHERE ProductBatchID IN (" + idList + ")");
    const verifyResult = await p.request().query("SELECT ProductBatchID, ExpiryDate FROM ProductBatches WHERE ProductBatchID IN (" + idList + ")");
    res.json({ success: true, updatedRows: updateResult.rowsAffected[0], batchIds, verifiedDates: verifyResult.recordset, message: 'Updated ' + updateResult.rowsAffected[0] + ' batch(es) in ERP' });
  } catch (err) { pool = null; console.error('Update expiry error:', err); res.status(500).json({ success: false, error: err.message }); }
});

app.listen(PORT, '0.0.0.0', () => {
  console.log('ERP Bridge API running on port ' + PORT + ' | DB: ' + SQL_DATABASE);
});
```

**Save and close Notepad** (Ctrl+S, then close).

### Step 3: Test the server manually

```cmd
cd C:\erp-api
node server.js
```

**Expected output:** `ERP Bridge API running on port 3333 | DB: URBAN2_2025`

Test it in a browser or another CMD: `http://localhost:3333/health`
Expected: `{"status":"healthy","database":"URBAN2_2025"}`

Leave this running and open a **new Admin CMD** for the next steps.

### Step 4: Download cloudflared

```cmd
curl -Lo C:\cloudflared.exe https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe
```

> **If you get "This app can't run on your PC":** That means you got an MSI instead. Make sure you download the standalone EXE with `-amd64.exe` at the end.

### Step 5: Install cloudflared as a Windows service

Replace `YOUR_TOKEN_HERE` with the token you copied from Step B1:

```cmd
C:\cloudflared.exe service install YOUR_TOKEN_HERE
```

**Expected output:** `cloudflared agent service installed successfully`

### Step 6: Verify the tunnel is HEALTHY

1. Go back to the Cloudflare dashboard: https://one.dash.cloudflare.com/
2. Navigate to **Networks** → **Tunnels**
3. Find your tunnel (`erp-branchX`)
4. Check the **Status** column — it should show **HEALTHY** with a green dot
5. You should see a connector listed

If not healthy:
```cmd
:: Check if the service is running
sc query cloudflared

:: Start it if stopped
net start cloudflared
```

### Step 7: Install bridge API as a Windows service

This makes the bridge API start automatically on server reboot.

Create the installer script:
```cmd
notepad C:\erp-api\install-service.js
```

Paste this:

```javascript
const Service = require('node-windows').Service;

const svc = new Service({
  name: 'ERP Bridge API',
  description: 'ERP Bridge API Server for Aqura - exposes SQL Server via HTTP',
  script: 'C:\\erp-api\\server.js',
  nodeOptions: [],
  env: [{
    name: 'NODE_ENV',
    value: 'production'
  }]
});

svc.on('install', function() {
  console.log('Service installed! Starting...');
  svc.start();
});

svc.on('alreadyinstalled', function() {
  console.log('Service already installed.');
});

svc.on('start', function() {
  console.log('Service started successfully!');
});

svc.install();
```

Save and close Notepad. Now **stop the manual `node server.js`** (go to that CMD window and press Ctrl+C). Then run:

```cmd
cd C:\erp-api
node install-service.js
```

**Expected output:** `Service installed! Starting...` → `Service started successfully!`

### Step 8: Add firewall rule

```cmd
netsh advfirewall firewall add rule name="ERP Bridge API" dir=in action=allow protocol=TCP localport=3333
```

### Step 9: Create uninstall script (for future use)

```cmd
notepad C:\erp-api\uninstall-service.js
```

Paste:

```javascript
const Service = require('node-windows').Service;
const svc = new Service({
  name: 'ERP Bridge API',
  script: 'C:\\erp-api\\server.js'
});
svc.on('uninstall', function() { console.log('Service uninstalled.'); });
svc.uninstall();
```

Save and close. You only need this if you want to remove the service later.

---

## B5. Verify Everything Works

### Check 1: Bridge API is running locally

Open CMD on the branch server:

```cmd
curl http://localhost:3333/health
```

**Expected:** `{"status":"healthy","database":"URBAN2_2025"}`

If not working:
```cmd
:: Check if service is running
sc query "ERP Bridge API"

:: Restart it
net stop "ERP Bridge API"
net start "ERP Bridge API"
```

### Check 2: Windows services are running

```cmd
sc query cloudflared
sc query "ERP Bridge API"
```

Both should show `STATE: 4 RUNNING`

### Check 3: Tunnel is working end-to-end

Open **any browser on any computer** (not just the server — your phone, laptop, anything with internet) and visit:

```
https://erp-branchX.urbanaqura.com/health
```

Replace X with the branch number.

**Expected:** `{"status":"healthy","database":"URBAN2_2025"}`

If you get:
- **502 Bad Gateway** → cloudflared is running but bridge API is not. Start the bridge service.
- **DNS error / site not found** → The published route is wrong, or DNS hasn't propagated yet (wait 2 min).
- **Tunnel connection failed** → cloudflared is not running. Start it with `net start cloudflared`.

### Check 4: Auth-protected endpoint works

```cmd
curl -X POST https://erp-branchX.urbanaqura.com/test -H "Content-Type: application/json" -H "x-api-secret: aqura-erp-bridge-2026"
```

**Expected:** JSON with `"success": true` and product counts

---

## B6. Update Supabase with Tunnel URL

Go to the **Supabase SQL Editor** and run:

```sql
UPDATE erp_connections
SET tunnel_url = 'https://erp-branchX.urbanaqura.com'
WHERE branch_id = X;
```

Replace `X` with the actual branch number. Example for branch 3:

```sql
UPDATE erp_connections
SET tunnel_url = 'https://erp-branch3.urbanaqura.com'
WHERE branch_id = 3;
```

### Verify the update

```sql
SELECT id, branch_id, branch_name, tunnel_url FROM erp_connections ORDER BY branch_id;
```

You should see the `tunnel_url` filled in for this branch.

---

## B7. Test from the App

1. Open the Aqura app (PWA)
2. Go to **ERP Product Manager** (in stock/settings section)
3. Select the branch you just set up
4. Click **"Test SQL Connection"** button in the branch column header
5. You should see a success message with barcode counts

If it works — **this branch is fully connected!**

If not:
- Check the browser console (F12 → Console tab) for error details
- Make sure the `tunnel_url` is saved in Supabase for this branch
- Make sure the tunnel URL is reachable from your browser (try the /health URL)

---

## Branch Reference Table

| Branch | Branch Name | Server IP | ERP DB Name | Tunnel Subdomain | Tunnel URL | Status |
|--------|------------|-----------|-------------|-----------------|------------|--------|
| 3 | Urban Market 02 | 192.168.0.3 | URBAN2_2025 | erp-branch3 | https://erp-branch3.urbanaqura.com | ✅ Done |
| 1 | (fill in) | (fill in) | (fill in) | erp-branch1 | https://erp-branch1.urbanaqura.com | ⏳ |
| 2 | Ali Hassan bin Mohammed Sahli | 192.168.0.151 | ASWAK_ALI_MASARAHA | erp-branch2 | https://erp-branch2.urbanaqura.com | ✅ Done |
| 4 | (fill in) | (fill in) | (fill in) | erp-branch4 | https://erp-branch4.urbanaqura.com | ⏳ |
| 5 | (fill in) | (fill in) | (fill in) | erp-branch5 | https://erp-branch5.urbanaqura.com | ⏳ |

> Tunnel ID for branch 3: `1838ee79-d59c-4b49-91bc-fe4db51c8b7a`

---

## Quick Checklist Per Branch

Print this and check off each item:

### Using Aqura-Data-Manager Folder (Easiest)

- [ ] Create tunnel in Cloudflare: **Networks → Tunnels → + Create** (name: `erp-branchX`)
- [ ] Copy the **tunnel token** from the connector page
- [ ] Add published route: **subdomain** `erp-branchX` → **domain** `urbanaqura.com` → **HTTP** → `localhost:3333`
- [ ] Copy **Aqura-Data-Manager** folder to the branch server (USB/network)
- [ ] **Double-click `Setup.bat`** → click Yes on admin prompt
- [ ] Wait for Node.js + cloudflared auto-install → browser opens wizard
- [ ] Fill in config in wizard → click **Install Everything**
- [ ] Check Cloudflare dashboard → tunnel is **HEALTHY**
- [ ] Open `https://erp-branchX.urbanaqura.com/health` → get `{"status":"healthy"}`
- [ ] Supabase SQL: `UPDATE erp_connections SET tunnel_url = 'https://erp-branchX.urbanaqura.com' WHERE branch_id = X;`
- [ ] Test from app: **ERP Product Manager → select branch → Test**

### Manual Setup

- [ ] Create tunnel in Cloudflare: **Networks → Tunnels → + Create** (name: `erp-branchX`)
- [ ] Copy the **tunnel token**
- [ ] Add published route: **subdomain** `erp-branchX` → **domain** `urbanaqura.com` → **HTTP** → `localhost:3333`
- [ ] RDP into the branch server → open **Admin CMD**
- [ ] Install Node.js if not installed
- [ ] `mkdir C:\erp-api` → `cd C:\erp-api` → `npm init -y` → `npm install express mssql cors node-windows`
- [ ] Create `server.js` with correct `SQL_DATABASE` for this branch
- [ ] Test: `node server.js` → see "running on port 3333" → test `/health`
- [ ] `curl -Lo C:\cloudflared.exe https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe`
- [ ] `C:\cloudflared.exe service install TOKEN`
- [ ] Check Cloudflare dashboard → tunnel is **HEALTHY**
- [ ] Create `install-service.js` → `node install-service.js`
- [ ] Stop manual `node server.js` (Ctrl+C) — service runs it now
- [ ] `netsh advfirewall firewall add rule name="ERP Bridge API" dir=in action=allow protocol=TCP localport=3333`
- [ ] Open `https://erp-branchX.urbanaqura.com/health` → get `{"status":"healthy"}`
- [ ] Supabase SQL: `UPDATE erp_connections SET tunnel_url = 'https://erp-branchX.urbanaqura.com' WHERE branch_id = X;`
- [ ] Test from app: **ERP Product Manager → select branch → Test**

---

## Troubleshooting

### Node.js: `'node' is not recognized`
You installed Node.js but didn't reopen CMD. **Close CMD and open a new Admin CMD.**

### npm install hangs or fails
Check internet connection. If behind a proxy:
```cmd
npm config set proxy http://proxy-server:port
npm config set https-proxy http://proxy-server:port
```

### cloudflared: "This app can't run on your PC"
You downloaded the wrong file (MSI instead of EXE). Use:
```cmd
curl -Lo C:\cloudflared.exe https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe
```

### cloudflared: "Access Denied" on service install
You're **not running as Administrator**. Close CMD and reopen it with right-click → Run as administrator.

### cloudflared: "Service already exists"
The tunnel was previously installed. Remove and reinstall:
```cmd
C:\cloudflared.exe service uninstall
C:\cloudflared.exe service install YOUR_TOKEN_HERE
```

### Tunnel shows "DOWN" or "INACTIVE" in Cloudflare dashboard
```cmd
:: Check if cloudflared service is running
sc query cloudflared

:: If STOPPED, start it
net start cloudflared

:: If it keeps stopping, check Windows Event Viewer for errors
:: Or try reinstalling:
C:\cloudflared.exe service uninstall
C:\cloudflared.exe service install YOUR_TOKEN_HERE
```

### Bridge API: "EADDRINUSE" (port already in use)
Something else is running on port 3333:
```cmd
:: Find what's using the port
netstat -ano | findstr :3333

:: Kill it
taskkill /PID <PID_NUMBER> /F

:: Restart the bridge service
net stop "ERP Bridge API"
net start "ERP Bridge API"
```

### Bridge API: "Failed to connect to SQL Server"
1. Make sure SQL Server is running:
   ```cmd
   sc query MSSQLSERVER
   ```
   If stopped: `net start MSSQLSERVER`

2. Make sure TCP/IP is enabled:
   - Open **SQL Server Configuration Manager**
   - Go to: SQL Server Network Configuration → Protocols for (instance)
   - Enable **TCP/IP**
   - Restart SQL Server service

3. Make sure the database name in `server.js` is correct

4. Make sure the SA password is correct

### 502 Bad Gateway from tunnel URL
Cloudflared is running but it can't reach the bridge API:
```cmd
:: Check if bridge API is running
curl http://localhost:3333/health

:: If not running, restart the service
net stop "ERP Bridge API"
net start "ERP Bridge API"
```

### "Unauthorized" error from the app
The API secret doesn't match. Check that `API_SECRET` in `C:\erp-api\server.js` is:
```
aqura-erp-bridge-2026
```
This must match the secret in the Vercel proxy (`frontend/src/routes/api/erp-products/+server.ts`).

### App shows "No tunnel URL configured for this branch"
The `tunnel_url` column in Supabase `erp_connections` is empty for this branch. Run:
```sql
UPDATE erp_connections SET tunnel_url = 'https://erp-branchX.urbanaqura.com' WHERE branch_id = X;
```

### Services don't start after server reboot
Both cloudflared and ERP Bridge API should auto-start. If they don't:
```cmd
:: Check startup type
sc qc cloudflared
sc qc "ERP Bridge API"

:: If not "AUTO_START", fix it:
sc config cloudflared start=auto
sc config "ERP Bridge API" start=auto
```

---

## Important Details

| Item | Value |
|------|-------|
| **Shared API secret** | `aqura-erp-bridge-2026` — must match in bridge `server.js` AND Vercel proxy |
| **Bridge port** | `3333` on each branch server (internal only, never exposed to internet) |
| **HTTPS** | Cloudflare handles SSL. Bridge runs plain HTTP internally |
| **Cloudflare plan** | Zero Trust Free — unlimited tunnels, up to 50 users |
| **Tunnel tokens** | Each tunnel has a unique token. Don't share tokens between branches |
| **SQL credentials** | Stored only in `server.js` on each branch machine. Never sent to the cloud |
| **Domain** | `urbanaqura.com` managed in Cloudflare |
| **Team name** | `urbanaqura` |
| **Node.js version** | v20.11.1 (LTS) |
| **Cloudflare dashboard** | https://one.dash.cloudflare.com/ |
| **Supabase dashboard** | https://supabase.com/dashboard |

---

## Files Reference

| File | Location | Purpose |
|------|----------|---------|
| **Aqura-Data-Manager/** | `scripts/Aqura-Data-Manager/` in repo | **Portable setup folder** — copy to any branch server |
| `Setup.bat` | Inside Aqura-Data-Manager folder | **One-click launcher** — double-click to start (auto admin + Node.js) |
| `setup-wizard.js` | Inside Aqura-Data-Manager folder | The wizard web GUI (launched by Setup.bat) |
| `erp-setup-wizard.js` | `scripts/erp-setup-wizard.js` in repo | Master copy of the wizard |
| `server.js` | `C:\erp-api\server.js` on each branch server | Bridge API (Node.js + Express) |
| `install-service.js` | `C:\erp-api\install-service.js` | Installs bridge as Windows service |
| `uninstall-service.js` | `C:\erp-api\uninstall-service.js` | Uninstalls bridge Windows service |
| `config.json` | `C:\erp-api\config.json` | Branch config reference (written by wizard) |
| `cloudflared.exe` | `C:\cloudflared.exe` on each branch server | Cloudflare Tunnel connector |
| `+server.ts` | `frontend/src/routes/api/erp-products/+server.ts` | Vercel proxy (forwards to bridge) |
| `erp-bridge-server.js` | `scripts/erp-bridge-server.js` in repo | Full annotated bridge server source |

### App-side files (already in the repo, no need to edit)

| File | Purpose |
|------|---------|
| `frontend/src/routes/api/erp-products/+server.ts` | SvelteKit API route — proxies requests from the app to the bridge via tunnel URL |
| `frontend/src/lib/components/desktop-interface/settings/ErpProductManager.svelte` | Desktop UI for managing ERP product sync & expiry dates |
| `frontend/src/routes/mobile-interface/expiry-manager/+page.svelte` | Mobile page for scanning barcodes and changing expiry dates |
| `supabase/migrations/20260213_create_erp_synced_products.sql` | Migration: create products table |
| `supabase/migrations/20260213_add_expiry_dates_to_erp_synced_products.sql` | Migration: add expiry column + RPC |
| `supabase/migrations/20260214_add_tunnel_url_to_erp_connections.sql` | Migration: add tunnel_url column |

---

## How to Update bridge server.js

If you need to change the bridge API code on a branch server:

### 1. Edit the file

```cmd
notepad C:\erp-api\server.js
```

Make your changes and save.

### 2. Restart the service

```cmd
net stop "ERP Bridge API"
net start "ERP Bridge API"
```

### 3. Verify

```cmd
curl http://localhost:3333/health
```

### To completely reinstall the service

```cmd
cd C:\erp-api
node uninstall-service.js
:: Wait a few seconds
node install-service.js
```
