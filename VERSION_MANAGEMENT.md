# Version Management System

This project uses an automated version management system that ensures consistency across all version displays and package files.

## 🚀 Quick Start

### Update Version Before Committing:

```bash
# Update patch version (recommended for most changes)
npm run version:patch

# Update minor version (for new features)
npm run version:minor

# Update major version (for breaking changes)
npm run version:major
```

### Then commit and push as usual:

```bash
git add -A
git commit -m "feat: your feature description"
git push origin master
```

## 📁 Files Updated Automatically

The version update script modifies:

1. **`/package.json`** - Root project version
2. **`/frontend/package.json`** - Frontend project version
3. **`/frontend/src/lib/components/Sidebar.svelte`** - Desktop interface version display
4. **`/frontend/src/routes/mobile/+layout.svelte`** - Mobile interface version display (top bar badge)

## 📝 Version Popup Content Update

**Important**: After running the version update script, you MUST manually update the version popup content to reflect the changes made in the new version.

### Location
File: `/frontend/src/lib/components/Sidebar.svelte` (lines ~610-650)

**Note**: The version number in the mobile interface top bar (`/frontend/src/routes/mobile/+layout.svelte`) is automatically updated by the script and does not require manual editing.

### Required Updates
1. **Update Section Headers**: Change feature categories to match your changes
2. **Update Feature Lists**: Replace bullet points with actual features implemented
3. **Update Release Date**: Set to current date
4. **Update Version Description**: Update the version subtitle and focus areas

### Content Structure Template
```svelte
<div class="update-section">
    <h4>📱 [Category Name]</h4>
    <ul>
        <li><strong>[Feature Name]:</strong> [Description of what was implemented]</li>
        <li><strong>[Feature Name]:</strong> [Description of what was implemented]</li>
    </ul>
</div>
```

### Common Categories
- 📱 Mobile Interface Improvements
- 💰 Financial Management Features  
- 🔧 Technical Improvements
- 🎯 User Experience Enhancements
- 🛠 Database & Functions
- 📊 Data Management Updates
- 🔐 Security Improvements
- 🎨 UI/UX Improvements

### Footer Template
```svelte
<div class="version-info-footer">
    <p><strong>Release Date:</strong> [Current Date]</p>
    <p><strong>Build:</strong> Production Ready</p>
    <p><strong>Version:</strong> [Version Number] - [Short Description]</p>
    <p><strong>Focus:</strong> [Main Focus Areas]</p>
</div>
```

### Example Workflow
1. Run version update: `npm run version:patch`
2. Edit Sidebar.svelte version popup content
3. Update feature descriptions to match your changes
4. Update release date and version info
5. Commit all changes: `git add -A && git commit -m "feat: description"`
6. Push to repository: `git push origin master`

### Content Guidelines
- **Be Specific**: Describe exactly what was implemented, not just "improvements"
- **Use Action Words**: "Fixed", "Implemented", "Enhanced", "Added", "Optimized"
- **Include Context**: Mention specific components, features, or user benefits
- **Group Related Changes**: Organize features by category for better readability
- **Update Dates**: Always use the current release date

## 📱 Mobile Version Display

The mobile interface displays the version number in the top header bar as a badge. This is automatically updated by the version script and requires no manual intervention.

**Location**: `/frontend/src/routes/mobile/+layout.svelte` (line ~501)

The script automatically finds and updates:
```svelte
<span class="version-text">v2.0.1</span>
```

This ensures version consistency across both desktop and mobile interfaces.

## 🔧 Manual Script Usage

```bash
# From project root directory
node scripts/update-version.js [patch|minor|major]
```

Examples:
- `node scripts/update-version.js` - Defaults to patch
- `node scripts/update-version.js patch` - 1.0.0 → 1.0.1
- `node scripts/update-version.js minor` - 1.0.0 → 1.1.0  
- `node scripts/update-version.js major` - 1.0.0 → 2.0.0

## 📋 Version Type Guidelines

### Patch (x.x.X)
- Bug fixes
- UI improvements
- Performance optimizations
- Documentation updates
- Small refactoring

### Minor (x.X.0)
- New features
- New components
- API enhancements (backward compatible)
- Significant UI changes
- New configuration options

### Major (X.0.0)
- Breaking changes
- Major architecture changes
- Database schema changes
- API breaking changes
- Complete rewrites

## 🎯 For GitHub Copilot Users

**Important**: Always run version update before committing:

```bash
# 1. Update version first
npm run version:patch

# 2. Then commit your changes
git add -A
git commit -m "feat: your changes"
git push origin master
```

This ensures the version number in the sidebar stays current with each release.

## 🔍 Troubleshooting

### Script Fails to Run
- Ensure Node.js is installed (>=18.0.0)
- Check file permissions
- Verify all target files exist

### Version Not Updating in UI
- Check browser cache (hard refresh: Ctrl+F5)
- Verify Sidebar.svelte was modified correctly
- Restart development server

### Git Hook Issues
- Ensure `.git/hooks/pre-push` is executable
- Check hook permissions: `chmod +x .git/hooks/pre-push`

## 📂 File Structure

```
/scripts/
  └── update-version.js          # Main version update script
/.git/hooks/
  └── pre-push                   # Git hook (optional automation)
/.copilot-instructions.md        # Instructions for AI assistants
/package.json                    # Root version
/frontend/package.json           # Frontend version
/frontend/src/lib/components/
  └── Sidebar.svelte            # User-visible version display
```

---

*This system ensures version consistency across the entire Aqura Management System.*