# Aqura Git Push Workflow with Auto Version Update

## Overview

The `push-with-version.js` script automates the complete workflow for pushing changes to git with automatic version number updates. It intelligently detects which interfaces were modified and updates version numbers accordingly.

## Features

✅ **Automatic Interface Detection** - Analyzes changed files to determine which interfaces were modified
✅ **Smart Version Updates** - Updates only the version numbers for modified interfaces
✅ **Sidebar Auto-Update** - Automatically updates the version popup display in Sidebar.svelte
✅ **Intelligent Commit Messages** - Generates contextual commit messages based on changes
✅ **Interactive Workflow** - Guides you through each step with confirmations
✅ **Complete Git Integration** - Stages, commits, and pushes all in one command

## Version Format: AQ[Desktop].[Mobile].[Cashier].[Customer]

The Aqura system uses a 4-part version number:
- **Desktop (1st)**: Admin/Manager interface changes
- **Mobile (2nd)**: Employee mobile app changes
- **Cashier (3rd)**: POS/Coupon redemption changes
- **Customer (4th)**: Customer shopping app changes

Example: `AQ1.2.1.3`

## Usage

### Basic Usage

```powershell
node scripts/push-with-version.js
```

### Workflow Steps

The script will automatically:

1. **Check Git Status** - Lists all changed files
2. **Detect Interfaces** - Identifies which interfaces were modified based on file paths
3. **Display Changes** - Shows changed files grouped by interface
4. **Confirm Version Update** - Asks if you want to update version numbers
5. **Update Version** - Increments the appropriate interface versions
6. **Update Sidebar** - Updates version display and popup in Sidebar.svelte
7. **Commit Changes** - Creates and commits with intelligent message
8. **Push to Git** - Pushes to master branch

### Interactive Prompts

The script will ask you:

```
Update version for DESKTOP? (yes/no): yes
Update all interfaces together? (yes/no): no
Commit message (default: "chore(desktop): bump version"): chore(desktop): add new feature
```

## Example Workflows

### Scenario 1: Desktop Interface Changes

```powershell
# You modified desktop-interface files
$ node scripts/push-with-version.js

📊 Step 1: Analyzing changed files...
✅ Found 3 changed file(s)

🎯 Step 2: Detecting modified interfaces...
✅ Modified interfaces: desktop

🎯 DESKTOP Interface:
   ✏️  frontend/src/lib/components/desktop-interface/common/Sidebar.svelte
   ✏️  frontend/src/lib/components/desktop-interface/master/HR.svelte
   ✨ frontend/src/lib/components/desktop-interface/work/TaskWindow.svelte

📦 Current version: AQ1.1.1.1

Update version for DESKTOP? (yes/no): yes
✅ New version: AQ2.1.1.1

🎉 Successfully pushed to git!
```

### Scenario 2: Multiple Interfaces Changed

```powershell
$ node scripts/push-with-version.js

✅ Modified interfaces: desktop, mobile, customer

Update version for DESKTOP, MOBILE, CUSTOMER? (yes/no): yes
Update all interfaces together? (yes/no): yes
✅ New version: AQ2.2.1.2

# If you choose "no", each interface updates individually
# Result: AQ2.1.1.1 → AQ2.2.2.2 (each +1)
```

### Scenario 3: Config/Docs Only (No Interface Changes)

```powershell
$ node scripts/push-with-version.js

⚠️  No interface-specific changes detected (only config/docs)

Update version manually? (yes/no): no
# Version stays AQ1.1.1.1, but changes are still committed
```

## What Gets Updated

### 1. Package.json Files
- `/package.json` - Root version
- `/frontend/package.json` - Frontend version

### 2. Sidebar.svelte
- Version display button (e.g., `AQ1.1.1.1`)
- Version popup header (e.g., `What's New in AQ1.1.1.1`)

### 3. Git Repository
- Stages all changes
- Creates commit with interface-aware message
- Pushes to master branch

## Commit Message Formats

The script generates intelligent commit messages:

```
# Single interface
chore(desktop): bump version to AQ2.1.1.1
chore(mobile): bump version to AQ1.2.1.1

# Multiple interfaces
chore(desktop,mobile): bump version to AQ2.2.1.1

# All interfaces
chore(all): bump version to AQ2.2.2.2

# Custom message (when user provides one)
chore(desktop): add new HR dashboard features
```

## File Detection Logic

The script automatically detects which interfaces were modified by checking file paths:

### Desktop Detection
```
frontend/src/lib/components/desktop-interface/
frontend/src/routes/desktop-interface/
frontend/src/lib/components/desktop-interface/common/Sidebar.svelte
```

### Mobile Detection
```
frontend/src/lib/components/mobile-interface/
frontend/src/routes/mobile-interface/
```

### Cashier Detection
```
frontend/src/lib/components/cashier-interface/
frontend/src/routes/cashier-interface/
```

### Customer Detection
```
frontend/src/lib/components/customer-interface/
frontend/src/routes/customer-interface/
```

## Version Increment Rules

### Increment Amount
- **+1**: Small features, bug fixes, minor improvements
- **+2-3**: Multiple related features, significant UI changes
- **+5+**: Major new features, complete module rewrites

### Manual Override
You can manually edit increment amount before running the script by modifying the script, but interactive mode handles +1 by default.

## Error Handling

If something goes wrong:

1. **Git status check fails** - Ensure you're in the Aqura directory
2. **File not found** - Check that Sidebar.svelte path is correct
3. **Push fails** - Verify your git credentials and network connection

## Tips & Best Practices

✅ **Before running**: Make sure all changes are saved and tests pass
✅ **Use meaningful prompts**: When asked for commit message, be descriptive
✅ **Check changes first**: Review the changed files list before confirming
✅ **Update documentation**: If adding features, update release notes manually in Sidebar popup
✅ **One push per feature**: Separate different features into different commits
✅ **Keep versions sequential**: Don't skip version numbers

## Example: Complete Workflow

```powershell
# 1. Make your changes
# ... edit files ...

# 2. Run the push script
node scripts/push-with-version.js

# 3. Review the detected interfaces
# ... confirm the interfaces that were changed ...

# 4. Approve version update
# Update version for DESKTOP? (yes/no): yes

# 5. Confirm commit message
# Commit message (default: "chore(desktop): bump version"): chore(desktop): add new HR features

# 6. Watch it push!
# ✅ All changes staged
# ✅ Changes committed
# ✅ Changes pushed to master
# 🎉 Successfully pushed to git!

# 7. Check your git log
git log --oneline -5
```

## Troubleshooting

### Q: "No changes detected. Nothing to commit."
**A**: You haven't modified any files. Make sure your changes are saved.

### Q: Version didn't update in Sidebar
**A**: The regex pattern may not match. Check Sidebar.svelte for the exact version format.

### Q: Files weren't pushed
**A**: Check your git credentials: `git config user.email` and `git config user.name`

### Q: Wrong interfaces detected
**A**: Check the file paths - the script looks for specific directory names. Ensure files are in correct folders.

## Advanced Usage

### Update Only Specific Interface
```powershell
# If you want to update just one interface, use the individual version script
node scripts/update-version.js desktop 5  # Desktop +5
```

### Manual Git Operations
```powershell
# If you prefer manual control:
git add -A
git commit -m "chore(desktop): your message"
git push origin master
```

## Integration with CI/CD

This script is designed for local development. For CI/CD pipelines:
- Use `git commit` directly without version updates
- Version updates should be handled by CI/CD automation
- Ensure commit messages follow conventional commit format

## Questions?

Refer to the Copilot instructions in `Do not delete/.copilot-instructions.md` for more details about the version system and best practices.
