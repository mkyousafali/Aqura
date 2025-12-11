# Button Access Control System - Current Status

## Overview
Building a comprehensive button access control system for the Aqura application where Master Admin users can manage which buttons are visible to different user roles.

## System Architecture

### Database Tables (4 Total)
1. **button_main_sections** - Main section definitions (10 sections)
2. **button_sub_sections** - Subsection definitions (40 subsections - 4 per section)
3. **sidebar_buttons** - Button definitions with codes and names
4. **button_permissions** - User-level button permissions (is_enabled flag)

### Frontend Components

#### 1. ButtonAccessControl.svelte
- **Location**: `frontend/src/lib/components/desktop-interface/settings/ButtonAccessControl.svelte`
- **Purpose**: Master Admin tool for managing user button permissions
- **Features**:
  - Step 1: User selection with search, filters, pagination
  - Step 2: Permission toggles (placeholder - needs implementation)
  - Two-step workflow for controlled permission management

#### 2. ButtonGenerator.svelte
- **Location**: `frontend/src/lib/components/desktop-interface/settings/ButtonGenerator.svelte`
- **Purpose**: Compare code base structure vs database structure
- **Current State**: Shows 10 sections, 40 subsections, but only 24 buttons instead of 75
- **Features**:
  - Section 1 (Code Base): Extract structure from sidebar code via `/api/parse-sidebar`
  - Section 2 (Database): Query Supabase for stored structure
  - Missing buttons detection with modal popup
  - Independent Generate buttons for each section
  - Summary statistics (sections, subsections, buttons counts)
  
### API Endpoints

#### `/api/parse-sidebar` (+server.ts)
- **Purpose**: Parse Sidebar.svelte to extract button structure
- **Current Issue**: Only extracting 24 buttons out of 75
- **Returns**: JSON with sections array containing subsections and buttons
- **Problem**: Button text extraction regex not matching all buttons correctly

## Known Issues

### Issue 1: Button Extraction (ACTIVE)
- **Problem**: API endpoint extracts only 24 buttons instead of 75
- **Expected**: 10 sections × 4 subsections = 40 subsections with 75 total buttons
- **Current**: Shows correct sections/subsections count but wrong button count
- **Root Cause**: Button text extraction regex failing to match buttons with certain formatting
- **Location**: `frontend/src/routes/api/parse-sidebar/+server.ts` (lines ~50-70)

### Issue 2: Button Text Extraction
- **Problem**: Regex for extracting menu-text from i18n fallback format not working reliably
- **Format**: `<span class="menu-text">{t('admin.key') || 'Fallback Text'}</span>`
- **Attempted Fixes**: 
  - Increased lookahead from 5 to 10 lines
  - Improved regex pattern for i18n format
  - Changed from `trimmed.startsWith()` to `line.includes()`

## Database State
- **Current**: All tables are EMPTY (recently cleared for fresh start)
- **Status**: Ready for auto-population

## Scripts Created

### Analysis Scripts
1. **analyze-sidebar-structure.cjs** - Initial analysis (showed 24 buttons)
2. **analyze-sidebar-complete.cjs** - Complete analysis (shows 75 buttons correctly)
3. **check-button-tables.cjs** - Verify table status
4. **empty-button-tables.cjs** - Clear all button-related tables
5. **compare-codes.cjs** - Compare sidebar codes vs database codes
6. **compare-names.cjs** - Compare sidebar names vs database names
7. **test-extraction.cjs** - Test button code conversion logic

### Utility Scripts
- **check-sidebar.cjs** - Original structure check
- **parse-sidebar.cjs** - Button extraction test

## Sidebar Structure (VERIFIED)
- **Main Sections**: 10 (Delivery, Vendor, Media, Promo, Finance, HR, Tasks, Notifications, User, Controls)
- **Subsections**: 40 (4 per section: Dashboard, Manage, Operations, Reports)
- **Total Buttons**: 75
  - Dashboard: 6 buttons
  - Manage: 39 buttons
  - Operations: 17 buttons
  - Reports: 13 buttons

## Next Steps (TODO)

1. **Fix Button Extraction (CRITICAL)**
   - Debug why API is only finding 24 buttons
   - May need to completely rewrite button text extraction logic
   - Consider using different parsing approach (e.g., parsing JSX/Svelte properly)

2. **Auto-Populate Database**
   - Create feature to automatically populate all 75 buttons from sidebar code
   - Create 7,750 permission records (75 buttons × 103 users) with is_enabled=true by default

3. **Implement ButtonAccessControl Step 2**
   - Add permission toggles UI
   - Connect to button_permissions table
   - Save permission changes

4. **Enforce Button Visibility**
   - Query user's button permissions on app load
   - Filter sidebar buttons based on is_enabled flag
   - Hide/disable unavailable buttons

5. **Testing**
   - Test with different user roles
   - Verify permissions persist
   - Test permission changes in real-time

## File Locations
- Components: `frontend/src/lib/components/desktop-interface/settings/`
- API: `frontend/src/routes/api/parse-sidebar/`
- Utilities: `frontend/src/lib/utils/`
- Database migrations: Supabase console

## Key Statistics
- **Total Users**: 103
- **Total Buttons**: 75
- **Total Permissions Records (when populated)**: 7,750 (75 × 103)
- **Table Count**: 4
- **API Endpoints**: 1 (`/api/parse-sidebar`)
- **Admin Components**: 2 (ButtonAccessControl, ButtonGenerator)

## Integration Points
- Sidebar.svelte: Will query permissions and filter buttons
- User auth store: Current user info for permission checks
- Supabase: All button structure and permission data
- i18n system: Button name translations

---
**Last Updated**: December 11, 2025
**Status**: In Development - Button extraction issue needs resolution
