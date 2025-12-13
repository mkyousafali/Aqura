# AI Agent Instructions: Login System Redesign

## Project Overview
Restructure the main login system to show Customer Login prominently with an Employee Login button that redirects to interface selection.

## Current State
- Single login page (`/routes/login/+page.svelte`) with interface selection icons (Desktop/Mobile/Cashier)
- Customer login exists as a separate component (`CustomerLogin.svelte`)
- Employee login options mixed with customer interface

## Target State
**Main Login Page (`/login`):**
1. Customer Login Card (displayed directly)
   - Access Code input (6 digits)
   - Remember this device checkbox
   - Sign In button
   - Forgot username/access code link
   - Request Account Recovery link
   - New Customer Registration link
   - Language toggle (العربية)

2. Employee Login Button (below customer card)
   - Styled button that redirects to employee login page

**Employee Login Page (`/login/employee`):**
1. Back button (to return to `/login`)
2. Interface selection with 4 icons:
   - Desktop Interface
   - Mobile Interface
   - Cashier Interface
   - [Any other existing interfaces]
3. After selection → show username/password or quick access login form

## Implementation Tasks

### Task 1: Create Employee Login Page
- **File:** `frontend/src/routes/login/employee/+page.svelte`
- **Content:**
  - Import necessary components and utilities
  - Add Back button with navigation to `/login`
  - Display interface selection icons (Desktop/Mobile/Cashier)
  - On icon click: set `interfaceChoice` and show login form below
  - Reuse existing login form logic (username/password + quick access)
  - Maintain responsive design for mobile/tablet/desktop

### Task 2: Restructure Main Login Page
- **File:** `frontend/src/routes/login/+page.svelte` (REDESIGN)
- **Changes:**
  1. Remove interface choice logic from main page
  2. Import CustomerLogin component
  3. Create Employee Login button with styling
  4. Layout:
     - Customer Login Card (full width, prominent)
     - Spacer/divider
     - "Employee Login" button below
  5. Employee Login button → navigate to `/login/employee`
  6. Keep language toggle in customer card
  7. Maintain all existing authentication logic for customer login

### Task 3: Styling & Responsive Design
- **Mobile (< 768px):**
  - Customer card: full width with adequate padding
  - Employee button: full width, below customer card
  - Spacing: clear visual separation

- **Tablet/Desktop (≥ 768px):**
  - Customer card: max-width ~500px, centered
  - Employee button: below customer card, same width
  - Professional spacing and hierarchy

### Task 4: Navigation & Routing
- Main page: `/login` → shows customer + employee button
- Employee path: `/login/employee` → shows interface selection
- Back button logic: on `/login/employee`, back button → `/login`
- No breaking of existing redirect logic after authentication

### Task 5: Component Imports & Reusability
- Ensure `CustomerLogin.svelte` can be imported cleanly in main page
- Existing authentication logic must remain intact
- Persistent auth service integration unchanged
- All translations/i18n preserved

## Success Criteria (98% Confidence)
✅ Customer login card displays on main `/login` page
✅ Employee Login button visible below customer card
✅ Clicking Employee Login redirects to `/login/employee`
✅ Employee page shows interface selection icons
✅ Back button returns to main login page
✅ All existing auth logic functions correctly
✅ Responsive design works on mobile/tablet/desktop
✅ No console errors or broken links
✅ Language toggle works in customer card
✅ All authentication flows unchanged

## Files to Modify
1. `frontend/src/routes/login/+page.svelte` - REDESIGN (restructure)
2. `frontend/src/routes/login/employee/+page.svelte` - CREATE (new)

## Files NOT to Touch
- `frontend/src/lib/utils/persistentAuth.ts` - authentication logic
- `frontend/src/lib/components/customer-interface/common/CustomerLogin.svelte` - customer login component
- `frontend/src/lib/components/cashier-interface/CashierLogin.svelte` - cashier component
- `frontend/src/routes/+layout.svelte` - routing guard logic

## Implementation Order
1. Create `/login/employee/+page.svelte` (new page with back button + interface selection)
2. Restructure `/login/+page.svelte` (remove interface selection, add employee button)
3. Test navigation flows: main → employee → interfaces → login forms
4. Test responsive design across devices
5. Verify all auth flows still work
6. Check console for errors

## Estimated Implementation Time
- Task 1 (Employee page creation): 15 min
- Task 2 (Main page restructure): 15 min
- Task 3 (Styling adjustments): 10 min
- Task 4 (Navigation verification): 5 min
- Testing & fixes: 10 min
- **Total: ~55 minutes**

## Risk Mitigation
- Back up current `/login/+page.svelte` logic before modifying
- Test all redirect flows after changes
- Verify persistent auth state management
- Check mobile viewport with DevTools before final commit
- Run `npm run dev` and manually test each flow

---

**Ready to implement? Confirm and I'll begin!**
