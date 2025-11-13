# Bundle Offer Card - Simplified Layout

## 📋 Card Information Display

The Bundle Offer card now shows **only** the following information in a clean, organized layout:

### Visual Layout

```
┌─────────────────────────────────────────┐
│  📦 Bundle Offer                        │ ← Type Badge
├─────────────────────────────────────────┤
│  test 4                                 │ ← Offer Name (AR/EN)
├─────────────────────────────────────────┤
│       ● Active                          │ ← Active Status (centered)
├─────────────────────────────────────────┤
│  🌍 Global     🚚 Both                  │ ← Branch & Service
├─────────────────────────────────────────┤
│  Total Bundles:              1          │ ← Total Bundles Count
├─────────────────────────────────────────┤
│  📅 Nov 11, 2025 - Dec 11, 2025        │ ← Start Date - End Date
├─────────────────────────────────────────┤
│  Customers Used:             0          │ ← Number of Customers
├─────────────────────────────────────────┤
│ [✏️ Edit] [⏸️ Pause] [🗑️ Delete]      │ ← Action Buttons
└─────────────────────────────────────────┘
```

---

## 🎯 Components

### 1. **Type Badge** (Top)
- Blue background with Bundle Offer icon
- Shows: `📦 Bundle Offer`

### 2. **Offer Name**
- Large, bold text
- Shows Arabic name if locale is Arabic, English otherwise
- Example: "test 4"

### 3. **Active Status**
- Centered badge showing offer status
- States:
  - ✅ **Active** (green)
  - ⏸️ **Paused** (gray)
  - 📅 **Scheduled** (blue)
  - ❌ **Expired** (red)

### 4. **Branch & Service**
- Two badges side by side:
  - **Branch**: 🏢 Branch Name OR 🌍 Global
  - **Service**: 🚚 Delivery, 📦 Pickup, or 🔄 Both

### 5. **Total Bundles**
- Gray info box showing count
- Format: `Total Bundles: [number]`
- Arabic: `إجمالي الحزم: [رقم]`

### 6. **Date Range**
- Calendar icon with start and end dates
- Format: `📅 Nov 11, 2025 - Dec 11, 2025`

### 7. **Customers Used**
- Gray info box showing usage count
- Format: `Customers Used: [number]`
- Arabic: `عدد العملاء: [رقم]`
- Data from: `current_total_uses` field

### 8. **Action Buttons** (Bottom)
Three buttons with labels and icons:

#### Edit Button
- Icon: ✏️
- Label: "Edit" / "تعديل"
- Color: Blue
- Opens the Bundle Offer edit window

#### Status Button (Toggle)
- Icon: ⏸️ (Pause) or ▶️ (Activate)
- Label: "Pause" / "Activate" (AR: "إيقاف" / "تفعيل")
- Color: Green
- Function: `toggleOfferStatus(offer.id, offer.is_active)`
- Shows confirmation dialog before changing status

#### Delete Button
- Icon: 🗑️
- Label: "Delete" / "حذف"
- Color: Red
- Shows confirmation dialog before deletion

---

## 🎨 Styling

### Colors
- **Type Badge**: Blue gradient (`#4F46E5`)
- **Active Status**: Green (`#16A34A`)
- **Info Boxes**: Light gray background (`#F9FAFB`)
- **Edit Button**: Light blue background (`#EEF2FF`)
- **Status Button**: Light green background (`#F0FDF4`)
- **Delete Button**: Light red background (`#FEF2F2`)

### Layout
- Clean, vertical stacking
- Consistent padding and spacing
- Info rows alternate between content and gray boxes
- Full-width action buttons at bottom

---

## 🔧 Functions Added

### `toggleOfferStatus(offerId, currentStatus)`
```javascript
function toggleOfferStatus(offerId, currentStatus) {
  const message = currentStatus
    ? (locale === 'ar' ? 'هل تريد إيقاف هذا العرض؟' : 'Do you want to pause this offer?')
    : (locale === 'ar' ? 'هل تريد تفعيل هذا العرض؟' : 'Do you want to activate this offer?');
  
  if (confirm(message)) {
    updateOfferStatus(offerId, !currentStatus);
  }
}
```

- Shows confirmation dialog
- Toggles between active/inactive
- Refreshes offer list after update
- Bilingual messages (AR/EN)

---

## 📊 Data Fields Used

| Field | Purpose |
|-------|---------|
| `offer.name_ar` / `offer.name_en` | Offer name display |
| `offer.is_active` | Active status |
| `offer.status` | Derived status (active/scheduled/expired/paused) |
| `offer.branch_id` | Branch assignment |
| `offer.service_type` | Delivery/Pickup/Both |
| `offer.bundleCount` | Total number of bundles |
| `offer.start_date` | Offer start date |
| `offer.end_date` | Offer end date |
| `offer.current_total_uses` | Number of customers who used the offer |

---

## 🌍 Bilingual Support

All text elements support both **Arabic** and **English**:

| English | Arabic |
|---------|--------|
| Bundle Offer | عرض حزمة |
| Active | نشط |
| Paused | متوقف |
| Global | عام |
| Both | كلاهما |
| Delivery | توصيل |
| Pickup | استلام |
| Total Bundles | إجمالي الحزم |
| Customers Used | عدد العملاء |
| Edit | تعديل |
| Pause | إيقاف |
| Activate | تفعيل |
| Delete | حذف |

---

## ✨ Differences from Other Offer Types

**Bundle Offers** now have a **distinct, simplified layout** compared to other offer types:

### Bundle Cards Show:
✅ Type badge  
✅ Offer name  
✅ Active status (centered)  
✅ Branch & service  
✅ Total bundles count  
✅ Date range  
✅ Customer usage  
✅ Edit/Status/Delete buttons  

### Other Offer Cards Show:
- Type badge
- Offer name + status (inline)
- Branch & service
- Discount info (percentage/value)
- Date range
- Stats
- "Applicable to" section
- Edit/Analytics/Delete buttons

---

## 🎯 Benefits

1. **Clarity**: Only essential bundle information
2. **Clean**: No cluttered discount displays
3. **Focused**: Bundle-specific metrics
4. **Actionable**: Quick status toggle
5. **Consistent**: Follows design patterns
6. **Responsive**: Works on all screen sizes

---

**Last Updated:** November 13, 2025  
**File Modified:** `frontend/src/lib/components/admin/OfferManagement.svelte`
