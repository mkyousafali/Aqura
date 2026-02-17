# 🔄 Versioning and Changelog Update Guide for AI Agents

## 🚨 MANDATORY PROTOCOL
**NEVER push changes to the repository without first updating the version numbers and the Version Changelog.** 

This system uses a multi-interface versioning scheme to track updates across Desktop, Mobile, Cashier, and Customer interfaces.

---

## 🛠️ Step 1: Automated Version Update

Always use the specialized script `Do not delete/simple-push.js` to increment version numbers and update the respective UI displays.

### Command Usage:
```bash
# Update ALL interfaces (Default for large features)
node "Do not delete/simple-push.js" all "feat: detailed description of changes"

# Update SPECIFIC interfaces
node "Do not delete/simple-push.js" desktop "feat(hr): add new analysis tool"
node "Do not delete/simple-push.js" mobile "fix(auth): fix login splash"
node "Do not delete/simple-push.js" cashier "feat: add localized branches"
node "Do not delete/simple-push.js" customer "style: update theme colors"

# WITH BRANCH DEPLOYMENT (builds frontend & uploads to cloud database)
node "Do not delete/simple-push.js" desktop "feat: new feature" --deploy
node "Do not delete/simple-push.js" all "feat: major update" --deploy
```

### What this script does:
1. **Increments Version**: Updates `AQ[Desktop].[Mobile].[Cashier].[Customer]` in `package.json`.
2. **Updates Displays**: Synchronizes the version string in `Sidebar.svelte` (Desktop), `+layout.svelte` (Mobile), etc.
3. **Automated Commit**: Stages files and creates a git commit with your provided message.
4. **Branch Deployment** *(with `--deploy` flag)*: Builds the frontend with `adapter-node`, creates a ZIP, uploads it to cloud Supabase storage, and registers it in the `frontend_builds` database table so branches can pull the update from StorageManager.

### `--deploy` Flag Details:
When `--deploy` is passed, the script performs these additional steps after the commit:
1. **Switches adapter** to `adapter-node` (temporarily replaces `adapter-vercel` in `svelte.config.js`)
2. **Builds frontend** using `npm run build` in the frontend directory
3. **Creates ZIP** of the build output using PowerShell `Compress-Archive`
4. **Uploads ZIP** to Supabase Storage bucket `frontend-builds`
5. **Registers build** in the `frontend_builds` database table with version, file size, and notes
6. **Restores** `adapter-vercel` in `svelte.config.js` and cleans up the ZIP file

> **Note:** The `--deploy` flag reads `VITE_SUPABASE_URL` and `VITE_SUPABASE_SERVICE_KEY` from `frontend/.env`. Make sure these are set correctly.
>
> After uploading, branches can update by going to **StorageManager → Branch Sync → Update Frontend** button on each branch card.

---

## 📝 Step 2: Manual Changelog Verification

The script automatically adds a basic entry to `VersionChangelog.svelte`, but an AI agent **MUST** refine this to be accurate and professional.

### Location:
`frontend/src/lib/components/desktop-interface/common/VersionChangelog.svelte`

### Checklist for Changelog Updates:
1. **Review Recent Commits**: Run `git log --since="3 days ago"` to ensure all incremental steps are grouped into the new version entry.
2. **Format by Date**: If changes spanned multiple days, use sub-headers (e.g., `<h4>January 19, 2026:</h4>`) within the `latest-change` section.
3. **Categorize Changes**: Use bold prefixes like **HR Module:**, **Security:**, or **UI/UX:** for readability.
4. **Logic Parity**: Ensure any "logic parity" or "branch localization" work is explicitly mentioned as these are critical for the user.

---

## 🔢 Version Numbering System

**Format: AQ[Desktop].[Mobile].[Cashier].[Customer]**

- **Desktop (Major 1)**: Business management and admin tools.
- **Mobile (Major 2)**: Employee app and HR tools.
- **Cashier (Major 3)**: POS and store operations.
- **Customer (Major 4)**: Consumer-facing shopping app.

*Example: `AQ34.13.8.8` means Desktop is at v34, Mobile at v13, etc.*

---

## 🚀 Final Verification Before Git Push

Before running your final `git push`, perform this check in order:

1. **Check Git Status**: Run `git status` to see which files changed
2. **Verify Version Number**: Check that only the changed interface version incremented:
   - For desktop changes: Desktop version should increase (AQ**X**.14.9.9)
   - For mobile changes: Mobile version should increase (AQ36.**X**.9.9)
   - For cashier changes: Cashier version should increase (AQ36.14.**X**.9)
   - For customer changes: Customer version should increase (AQ36.14.9.**X**)
3. **Update Changelog Display**: ⚠️ **CRITICAL** - Update the version number in `VersionChangelog.svelte`:
   - Open: `frontend/src/lib/components/desktop-interface/common/VersionChangelog.svelte`
   - Find the `<div class="version-format">` section
   - Update `<p class="version-title">Version AQX.X.X.X</p>` to match the new version
   - Update `<p class="version-details">Desktop: X | Mobile: X | Cashier: X | Customer: X</p>` with new numbers
   - **This is displayed to users in the app - do NOT forget!**
4. **Expand Changelog Content**: Open `VersionChangelog.svelte` and expand the automated entry with real details:
   - Add sub-headers by date (e.g., `<h4>January 19, 2026:</h4>`)
   - Use bold prefixes like **HR Module:**, **Security:**, **UI/UX:**
   - Include impact and reasoning
5. **Commit & Push**: 
   - Stage the changelog: `git add frontend/src/lib/components/desktop-interface/common/VersionChangelog.svelte`
   - Commit: `git commit -m "docs(changelog): update AQ[X] entry with [feature details]"`
   - Push: `git push`
6. **Deploy to Branches** *(if applicable)*: If branches need the update, use the `--deploy` flag:
   ```bash
   node "Do not delete/simple-push.js" desktop "feat: your changes" --deploy
   ```
   This builds the frontend, uploads it to cloud storage, and registers it in the database.
   Branches can then pull the update from **StorageManager → Branch Sync → Update Frontend**.

**REMEMBER: The version number in VersionChangelog.svelte is what users see in the app. Missing this step means users see outdated version info!**

**REMEMBER: If branches need the update, always use `--deploy` flag to upload the build to the cloud database!**
