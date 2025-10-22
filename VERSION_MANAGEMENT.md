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
3. **`/frontend/src/lib/components/Sidebar.svelte`** - User-visible version display

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