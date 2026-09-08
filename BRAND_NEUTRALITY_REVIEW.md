# Brand Neutrality Review — Findings List

Status legend: `⏳ Pending discussion` | `✅ Approved` | `🚫 Skip` | `🔧 Fixed`

Each case below is numbered so we can go through them one at a time. For each, note the decision in the Status column before moving to implementation.

---

## Category A — Hardcoded domain / URL used in functional logic (high risk — breaks for new customer)

> Note: `.env` / `.env.example` values (e.g. `VITE_SUPABASE_URL`) are intentional per-deployment configuration, not hardcoded brand issues — removed from this list.

### 2. Supabase URL rewrite logic
- **File:** [frontend/src/lib/utils/supabase.ts](frontend/src/lib/utils/supabase.ts#L17)
- **Finding:** Comment referenced the literal `urbanaqura.com` domain as an example. Logic itself already uses `VITE_CLOUD_SUPABASE_URL` env var (brand-neutral) — comment-only issue.
- **Status:** 🔧 Fixed — comment updated to remove hardcoded domain example.

### 3. Service worker hostname check
- **File:** [frontend/static/sw.js](frontend/static/sw.js#L269)
- **Finding:** Fetch bypass check had a redundant, brand-hardcoded `url.hostname.includes('urbanaqura.com')` alongside `.includes('supabase')` — the latter alone already matches `supabase.urbanaqura.com`.
- **Status:** 🔧 Fixed — removed the redundant hardcoded domain check; `'supabase'` substring check alone preserves identical behavior for any deployment.

### 4. Storage info config
- **File:** ~~supabase/storage-info.json~~ (deleted)
- **Finding:** Stale, unused snapshot/export artifact containing `"supabase_url": "https://supabase.urbanaqura.com"`. Not referenced anywhere in code.
- **Status:** 🔧 Fixed — file deleted.

### 5. Database trigger function hardcoded edge URL
- **Files:** [supabase/migrations/01_full_schema.sql](supabase/migrations/01_full_schema.sql#L1119), [supabase/migrations/02_functions_rpcs.sql](supabase/migrations/02_functions_rpcs.sql#L783)
- **Finding:** Migration files had `edge_url` and `svc_key` (a live service_role JWT) hardcoded in `broadcast_watchdog()`.
- **Verified:** Live database was already fixed to pull both `supabase_url` and `service_role_key` from Supabase Vault (via the existing Supabase Secrets Manager admin UI), with `current_setting` and Docker-internal fallbacks — no hardcoded values remain live.
- **Status:** 🔧 Fixed — migration files updated to exactly match the live, already-fixed vault-based function so future fresh installs don't recreate the old hardcoded/exposed version.

### 6. Push notification VAPID contact email
- **File:** [supabase/functions/send-push-notification/index.ts](supabase/functions/send-push-notification/index.ts#L122)
- **Finding:** `'mailto:admin@urbanaqura.com'` hardcoded as the VAPID contact claim (required by Web Push spec, not customer-facing).
- **Fix:** Now reads `contact.email` from the existing `login_layout` branding config table (same source BrandingManager's Contact section already writes to), falling back to `VAPID_CONTACT_EMAIL` env var, then a generic default.
- **Status:** 🔧 Fixed

### 7. OpenFoodFacts API User-Agent header
- **File:** [frontend/src/routes/api/openfoodfacts-search/+server.ts](frontend/src/routes/api/openfoodfacts-search/+server.ts#L23) (also L112)
- **Finding:** `'User-Agent': 'Aqura-ProductMaster/1.0 (contact@urbanaqura.com)'`
- **Fix:** Extracted to a shared `OFF_USER_AGENT` constant reading `process.env.SUPPORT_CONTACT_EMAIL`, added `SUPPORT_CONTACT_EMAIL` to [frontend/.env.example](frontend/.env.example) with a generic default.
- **Status:** 🔧 Fixed (this is a SvelteKit server route, deployed via the frontend build — no separate edge-function deploy step needed).

### 8. ERP tunnel URL construction in setup wizards
- **Files:** [scripts/Aqura-Data-Manager/setup-wizard.js](scripts/Aqura-Data-Manager/setup-wizard.js#L499), [scripts/erp-setup-wizard.js](scripts/erp-setup-wizard.js#L421)
- **Finding:** `const tunnelUrl = 'https://' + cfg.subdomain + '.urbanaqura.com';` (also displayed in UI at L607 / L474)
- **Fix:** This is real infrastructure (the actual Cloudflare tunnel domain each branch's subdomain is routed under), not just cosmetic text. Extracted it into a single `TUNNEL_BASE_DOMAIN` constant (`process.env.TUNNEL_BASE_DOMAIN || 'urbanaqura.com'`) near the top of both files, and referenced it via template-literal interpolation everywhere the domain was previously hardcoded — one place to change per deployment, or overridable via env var, with no behavior change by default.
- **Status:** 🔧 Fixed

### 9. WhatsApp AI bot persona + hardcoded loyalty app link
- **File:** [supabase/functions/whatsapp-webhook/index.ts](supabase/functions/whatsapp-webhook/index.ts#L1311-L1454)
- **Finding:** System prompt hardcodes bot identity as "Urban Smart Plus" grocery store persona (Arabic name "ايربن الذكي بلس"), and hardcodes `https://www.urbanksa.app/login` in: prompt instructions, example reply text, `APP_LINK` constant, and a regex that strips this exact URL from outgoing messages.
- **Note:** Most critical functional item — affects live AI behavior, not just cosmetic text.
- **Fix:** Added `bot_name` and `app_link` columns to `wa_ai_bot_config` (seeded with the previous hardcoded values so live behavior is unchanged). Added "🤖 Bot Identity" fields to [WAaiBot.svelte](frontend/src/lib/components/desktop-interface/whatsapp/WAaiBot.svelte) Bot Config tab. Edge function now reads `config.bot_name` / `config.app_link` (with safe fallbacks) instead of hardcoded literals, and the URL-strip regex is generalized to whatever link is configured.
- **Status:** 🔧 Fixed — deployed live and verified (deployed file has zero occurrences of the old hardcoded strings; container healthy).

### 10. Privacy policy page hardcoded company info
- **File:** [frontend/src/routes/privacy/+page.svelte](frontend/src/routes/privacy/+page.svelte#L22-L27)
- **Finding:** `companyName = "Urban Aqura"`, `companyNameAr = "ايربن ماركت أكورا"`, `website = "https://urbanksa.com"`, `email = "CEO@urbanksa.com"` used as the default legal-text fallback (shown when no custom `login_layout.privacy_policy` content is set).
- **Fix:** Constants changed to generic placeholders (`Your Company Name` / `https://example.com` / `privacy@example.com`). Additionally, the entire 18-section default policy text (both English and Arabic) was rewritten to remove exclusive Saudi PDPL/SDAIA framing — now references applicable data protection laws generically (GDPR, CCPA, etc. as examples) instead of assuming Saudi jurisdiction, Saudi-only server residency, SDAIA breach notification, and Saudi-law governing clause. Company name (`cn`) now additionally prefers the centralized `layout.company` config (see note under Case 16) over the static placeholder.
- **Status:** 🔧 Fixed

### 11. Login test page CEO mailto
- **File:** ~~frontend/src/routes/logintest/+page.svelte~~ (deleted)
- **Finding:** Unused test/staging login page, not linked anywhere in the app, containing hardcoded "Urban Market" logo alt text, Saudi Arabia description, `ceo@urbanksa.com` mailto, and `© 2026 Urban Market` copyright.
- **Fix:** Confirmed dead code (no `<a href>`/`goto()` references anywhere) and removed entirely — deleted `frontend/src/routes/logintest/` and cleaned up the `isLoginTestRoute`/`isLoginTestPage` special-casing in [frontend/src/routes/+layout.svelte](frontend/src/routes/+layout.svelte).
- **Status:** 🔧 Fixed (removed)

### 12. WhatsApp bot component (WAaiBot) persona/links
- **File:** [frontend/src/lib/components/desktop-interface/whatsapp/WAaiBot.svelte](frontend/src/lib/components/desktop-interface/whatsapp/WAaiBot.svelte#L86-L483)
- **Finding:** System prompt text "helpful customer service bot for Urban Aqura", plus `Offers portal: https://urbanaqura.com/offers`, `Contact: support@urbanaqura.com`, UI label "Urban Aqura Bot".
- **Fix:** The admin "Bot Test" panel's own system prompt now uses the configured `botName` instead of a hardcoded "Urban Aqura" (real bug — it wasn't respecting the Bot Identity fields added in Case 9). The test-chat header now shows `{botName} Preview` instead of a literal "Urban Aqura Bot". Textarea placeholder examples (Information Library, Bot Name Arabic) genericized to remove brand-specific example text.
- **Status:** 🔧 Fixed

### 13. ERP database name default
- **File:** [scripts/erp-bridge-server.js](scripts/erp-bridge-server.js#L33)
- **Finding:** `const SQL_DATABASE = process.env.SQL_DATABASE || 'URBAN2_2025';`. Also flagged separately: the header comment documented a real-looking example password (`SQL_PASSWORD: Polosys*123`).
- **Fix:** Default fallback changed to generic `'ERP_DB'`; comment example redacted to `(your SQL Server password)`. Since this standalone branch-deployment script isn't part of the Aqura app itself and isn't referenced anywhere else in the codebase, it was also untracked from git and added to `.gitignore` (kept locally, no longer committed/shipped with the repo).
- **Status:** 🔧 Fixed

---

## Category B — Hardcoded brand text in customer-facing UI (page titles, meta, footers)

### 14. Login page (main)
- **File:** [frontend/src/routes/login/+page.svelte](frontend/src/routes/login/+page.svelte#L521-L931)
- **Finding:** Footer copyright "© 2026 Urban Market. All Rights Reserved." / "يو مارت", `<title>Urban Market</title>`, logo alt text "Urban Market logo" (x2 locations).
- **Fix:** Superseded by a proper centralized fix (see note below) — title, footer copyright, and logo alt text now read from `layout.company.name_en` / `name_ar`, set once via Branding Manager, with a generic placeholder fallback if unset.
- **Status:** 🔧 Fixed

### 15. Login page (customer)
- **File:** [frontend/src/routes/login/customer/+page.svelte](frontend/src/routes/login/customer/+page.svelte#L572-L990)
- **Finding:** Same pattern as #14 — footer copyright, page title, logo alt text.
- **Fix:** Same centralized fix as #14 — wired to `layout.company.name_en` / `name_ar`.
- **Status:** 🔧 Fixed

### 16. Mobile interface login footer
- **File:** [frontend/src/routes/mobile-interface/login/+page.svelte](frontend/src/routes/mobile-interface/login/+page.svelte#L30)
- **Finding:** Footer copyright "© 2026 Urban Market. All Rights Reserved."
- **Fix:** Same centralized fix as #14 — footer copyright now built from `layout.company.name_en` / `name_ar`.
- **Status:** 🔧 Fixed

> **Note (Cases 10, 14, 15, 16):** Rather than genericizing each hardcoded company-name occurrence independently, added a proper single source of truth: a new `company` jsonb column on the `login_layout` table (DB), a whitelisted `'company'` section in `update_login_layout_section()` RPC, and a "🏢 Company Name" (English/Arabic) card in Branding Manager's "Top Bar and Layouts" tab. All four pages (main login, customer login, mobile login, privacy policy) now read the company name from this single admin-editable field instead of separate hardcoded/placeholder strings.

### 17. Login test page (full duplicate page)
- **File:** ~~frontend/src/routes/logintest/+page.svelte~~ (deleted)
- **Finding:** `<title>`, meta description, top bar welcome text, hero copy ("Urban Supermarket"), logo alt text, footer copyright — all hardcoded "Urban Market" branding.
- **Fix:** Duplicate of Case 11 — this whole file was already deleted when Case 11 was resolved (unused test route, not linked anywhere in the app).
- **Status:** 🔧 Fixed (removed)

### 18. Customer-interface home page
- **File:** [frontend/src/routes/customer-interface/+page.svelte](frontend/src/routes/customer-interface/+page.svelte#L810-L911)
- **Finding:** `title: 'Home - Urban Market'` (and Arabic variant), logo alt text "Urban Market".
- **Fix:** Same centralized fix as #14 — page now fetches `layout.company` via `get_login_layout()` and builds the title/alt text from `companyName` (with generic placeholder fallback).
- **Status:** 🔧 Fixed

### 19. Customer-interface categories page
- **File:** [frontend/src/routes/customer-interface/categories/+page.svelte](frontend/src/routes/customer-interface/categories/+page.svelte#L115)
- **Finding:** Logo alt text "Urban Market".
- **Fix:** Same centralized fix as #14 — fetches `layout.company` and uses `companyName` for the logo alt text.
- **Status:** 🔧 Fixed

### 20. Customer-interface start page
- **File:** [frontend/src/routes/customer-interface/start/+page.svelte](frontend/src/routes/customer-interface/start/+page.svelte#L244-L261)
- **Finding:** `title: 'Welcome to Urban Market'` (and Arabic variant).
- **Fix:** Same centralized fix as #14 — title now built from `companyName`.
- **Status:** 🔧 Fixed

### 21. Offers page
- **File:** [frontend/src/routes/offers/+page.svelte](frontend/src/routes/offers/+page.svelte#L349-L380)
- **Finding:** `<title>Latest Offers - Urban Market</title>`, meta description, logo alt text "Urban Market Logo", plus a fully hardcoded letter-by-letter colored "Ahl Urban" brand title heading.
- **Fix:** Title, meta description, and logo alt text now built from `companyName` (fetched via `get_login_layout`). The stylized per-letter-colored "Ahl Urban" heading was replaced with a plain `{companyName}` heading, since the colored-letter styling was hardcoded to that specific brand name's letter count and couldn't generalize.
- **Status:** 🔧 Fixed

### 22. Follow-us page
- **File:** [frontend/src/routes/follow-us/+page.svelte](frontend/src/routes/follow-us/+page.svelte#L171-L191)
- **Finding:** Top bar text "Welcome To Urban market" / "مرحباً بكم في ايربن ماركت", comment referencing "Ahl Urban Header Style".
- **Fix:** Top bar text now built from `companyName` (fetched via `get_login_layout`); stray brand-name comment genericized.
- **Status:** 🔧 Fixed

---

## Category C — Hardcoded brand defaults in settings/components (should read from branding config)

### 23. BrandingManager default fallback values
- **File:** [frontend/src/lib/components/desktop-interface/settings/BrandingManager.svelte](frontend/src/lib/components/desktop-interface/settings/BrandingManager.svelte#L1429-L2004)
- **Finding:** Hardcoded default state `footerCopyrightText = '© 2026 Urban Market. All Rights Reserved.'`, `footerCopyrightTextAr = '© 2026 يو مارت...'`, and hero logo alt text "Urban Market logo" — ironic since this is the screen meant to let admins configure branding. Worse, these weren't just cosmetic: since they're the state bound to the save form, if an admin saved the footer section without touching these fields, "Urban Market" would get written into the DB as the real override.
- **Fix:** Defaults genericized to "Your Company Name" / "اسم شركتك" placeholders and generic "Company logo" alt text, consistent with the rest of the app.
- **Status:** 🔧 Fixed

### 24. Order receipt print template
- **File:** [frontend/src/lib/components/desktop-interface/admin-customer-app/OrdersManager.svelte](frontend/src/lib/components/desktop-interface/admin-customer-app/OrdersManager.svelte#L110-L159)
- **Finding:** Printed receipt text "Urban Market • ايربن ماركت • ..." and "Urban Market - Print Test". Also found the Arabic branch didn't actually translate "Urban Market" — it showed an unrelated phrase instead, while English always showed the brand name regardless of locale.
- **Fix:** Added `companyNameEn`/`companyNameAr` state fetched via `get_login_layout` RPC in `onMount`, derived `companyName` based on `isRTL`. Both the printed receipt footer and the internal print-test page label now use `companyName`. Fixed the Arabic footer to say "طباعة تلقائية" (translation of "Printed automatically") instead of the disconnected phrase that was there before.
- **Status:** 🔧 Fixed

### 25. Surprise Box default terms & conditions
- **File:** [frontend/src/lib/components/desktop-interface/marketing/surprise-box/SurpriseBoxManager.svelte](frontend/src/lib/components/desktop-interface/marketing/surprise-box/SurpriseBoxManager.svelte#L22-L35)
- **Finding:** Default T&C text repeatedly references "Urban Market management" (4 occurrences).
- **Fix:** Replaced "Urban Market"/"أوربان ماركت" with neutral "the management"/"الإدارة" (and "the store" where referring to receipt issuance) — reads naturally in legal T&C text without needing to wire a company-name fetch into this component.
- **Status:** 🔧 Fixed


### 26. Loyalty voucher print template
- **File:** [frontend/src/lib/components/cashier-interface/LoyaltyRedemption.svelte](frontend/src/lib/components/cashier-interface/LoyaltyRedemption.svelte#L361-L438)
- **Finding:** Printed voucher HTML: alt text "شعار أهل ايربن", title "قسيمة الولاء — أهل ايربن", program name "أهل ايربن" (x2), footer "أهل ايربن | Urban Aqura".
- **Fix:** Added `companyNameAr` fetched via `get_login_layout` RPC in `onMount`, used as `programName` (falls back to generic "برنامج الولاء" if unset) throughout the printed voucher (alt text, title, program name, thank-you text, footer). Footer now reads `${programName} | Aqura` — kept "Aqura" as the platform name, same treatment as Case 22. Left the `$t('coupon.loyaltyProgramName')` usage elsewhere in this file untouched since that i18n key is tracked separately as Case 28.
- **Status:** 🔧 Fixed

### 27. Customer login OTP success message
- **File:** [frontend/src/lib/components/customer-interface/common/CustomerLogin.svelte](frontend/src/lib/components/customer-interface/common/CustomerLogin.svelte#L785)
- **Finding:** Success message text: "...أنت الآن عضو كامل في برنامج أهل ايربن..." / "...you are now a full Ahl Urban member..."
- **Fix:** Removed the specific loyalty program name from the message — now just "...أنت الآن عضو كامل..." / "...you are now a full member...".
- **Status:** 🔧 Fixed


### 28. i18n loyalty program name key
- **Files:** [frontend/src/lib/i18n/locales/en.ts](frontend/src/lib/i18n/locales/en.ts#L4468), [frontend/src/lib/i18n/locales/ar.ts](frontend/src/lib/i18n/locales/ar.ts#L4486), [frontend/src/lib/components/cashier-interface/CashierTaskbar.svelte](frontend/src/lib/components/cashier-interface/CashierTaskbar.svelte), [frontend/src/lib/components/cashier-interface/LoyaltyRedemption.svelte](frontend/src/lib/components/cashier-interface/LoyaltyRedemption.svelte)
- **Finding:** `loyaltyProgramName: "Ahl Urban"` / `"أهل ايربن"` — translation key value is brand-specific; should likely be admin-configurable rather than a static i18n string. Used in 5 places (window title, menu item, quick-button title in `CashierTaskbar.svelte`; logo alt text and program name display in `LoyaltyRedemption.svelte`).
- **Fix:** All 5 usages now prefer the company name from `login_layout.company` (fetched via `get_login_layout` RPC), falling back to the `coupon.loyaltyProgramName` i18n key only if unconfigured. `CashierTaskbar.svelte` fetches company data in `onMount` and derives `loyaltyProgramNameDisplay`; `LoyaltyRedemption.svelte` fetches both `companyNameEn`/`companyNameAr` and derives `companyNameDisplay` based on `$currentLocale`. The i18n keys themselves were left in place as the fallback default.
- **Status:** 🔧 Fixed

---

## Category D — Cosmetic-only (comments, placeholders — low risk)

### 29. CSS comment
- **File:** [frontend/src/app.css](frontend/src/app.css#L10)
- **Finding:** `/* Urban-Express Design System Variables */` — comment only, no functional impact.
- **Fix:** Changed to `/* App Design System Variables */`.
- **Status:** 🔧 Fixed

### 30. voucherCanvas.ts file header comment
- **File:** [frontend/src/lib/utils/voucherCanvas.ts](frontend/src/lib/utils/voucherCanvas.ts#L2)
- **Finding:** `* Urban Market Surprise Box – Voucher Canvas Generator` — comment only.
- **Fix:** Changed to `* Surprise Box – Voucher Canvas Generator`.
- **Status:** 🔧 Fixed

### 31. ERP settings placeholder text
- **File:** [frontend/src/lib/components/desktop-interface/settings/ERPConnections.svelte](frontend/src/lib/components/desktop-interface/settings/ERPConnections.svelte#L444)
- **Finding:** Input placeholder `"URBAN2_2025"` — example text only, not a functional default.
- **Fix:** Changed to `"ERP_DB"`, consistent with the default used in Case 13.
- **Status:** 🔧 Fixed

### 32. ERP Product Manager URL placeholder
- **File:** [frontend/src/lib/components/desktop-interface/settings/ErpProductManager.svelte](frontend/src/lib/components/desktop-interface/settings/ErpProductManager.svelte#L576)
- **Finding:** Input placeholder `"https://erp-branch3.urbanaqura.com"` — example text only.
- **Fix:** Changed to `"https://erp-branch3.example.com"`.
- **Status:** 🔧 Fixed

### 33. Setup wizard branch name / DB name placeholders
- **Files:** [scripts/Aqura-Data-Manager/setup-wizard.js](scripts/Aqura-Data-Manager/setup-wizard.js#L215-L231), [scripts/erp-setup-wizard.js](scripts/erp-setup-wizard.js#L162-L178)
- **Finding:** Placeholders `"e.g. Urban Market 02"`, `"e.g. URBAN2_2025"` in setup UI inputs.
- **Fix:** Changed to `"e.g. Main Branch 02"` and `"e.g. ERP_DB_2025"` in both files.
- **Status:** 🔧 Fixed

### 34. Documentation reference
- **File:** [AQURA_EMAIL_MODULE_SPECIFICATION.md](AQURA_EMAIL_MODULE_SPECIFICATION.md#L2326)
- **Finding:** Doc text: "Hardcode `support@urbanaqura.com` or any other account." (already flags itself as a thing to avoid — no code change needed, just a doc reference).
- **Status:** ✅ No action needed — this is a "Do not" guideline warning against hardcoding, not an actual hardcoded value.

### 35. Backup/original file (not live code)
- **File:** ~~frontend/src/routes/login/customer/+page.svelte.original-backup.txt~~ (deleted)
- **Finding:** CSS class names `.ahl-urban-branding`, `.ahl-urban-title`, `.ahl-urban-tagline` — this is a `.txt` backup file, not part of the build; consider deleting instead of editing.
- **Fix:** Deleted the file.
- **Status:** 🔧 Fixed

---

## Notes
- Cases 2–13 (Category A) are functional and should be prioritized — they will actually break behavior for a new customer/domain, not just look wrong.
- Recommended general fix pattern: move brand strings to the existing `BrandingManager` settings / database config, and read domain/URLs from environment variables consistently (some already use `VITE_SUPABASE_URL`, others hardcode the literal domain in parallel).
