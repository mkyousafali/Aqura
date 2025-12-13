# Quick Reference: Realtime Tables to Enable

## 🎯 Action Required

Go to **Supabase Dashboard** → **Database** → **Replication**

Enable these 4 tables:

### 1. product_categories
- **Purpose**: Category filter dropdown updates
- **Triggers**: When categories are added/edited/deleted
- **Impact**: Category options appear/disappear instantly

### 2. offer_products  
- **Purpose**: Product discount/offer links
- **Triggers**: When offers are applied/removed from products
- **Impact**: Discount badges appear/disappear, prices change instantly

### 3. bogo_offer_rules
- **Purpose**: Buy One Get One offer rules
- **Triggers**: When BOGO offers are created/updated/deleted
- **Impact**: BOGO badges appear/disappear instantly

### 4. offers
- **Purpose**: Main offer configuration (active/inactive, dates, names)
- **Triggers**: When offers are activated/deactivated/expire
- **Impact**: Offer visibility updates instantly

---

## 🧪 How to Verify

1. Open `/customer-interface/products` page
2. Open Supabase Dashboard in another window
3. Make a change (update price, create offer, etc)
4. Watch the products page **update without refresh**
5. Check browser console (F12) for emoji logs: ✨ 🔄 📦 🎁 📊 🏷️

---

## 📍 Current Status

| Table | Status | Action |
|-------|--------|--------|
| products | ✅ Enabled | Done |
| product_categories | ❌ Not enabled | Enable now |
| offer_products | ❌ Not enabled | Enable now |
| bogo_offer_rules | ❌ Not enabled | Enable now |
| offers | ❌ Not enabled | Enable now |

---

## 🚀 That's All!

Frontend code is ready. Just enable those 4 tables and realtime will work automatically.
