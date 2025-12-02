# Go Backend Implementation - Backup & Rollback Guide

## 📅 Created: December 2, 2025
## 🎯 Purpose: Safe testing of Go backend with easy rollback

---

## Step 1: Create Backup Branch

### Before Starting Go Backend Work

```powershell
# Make sure you're on master and it's up to date
git checkout master
git pull origin master

# Create a backup branch from current state
git checkout -b backup-before-go-backend
git push origin backup-before-go-backend

# Create working branch for Go backend
git checkout -b go-backend-test
```

### What This Does:
- `backup-before-go-backend` → Safe copy of working code
- `go-backend-test` → Where you'll make changes
- `master` → Remains untouched

---

## Step 2: Work on Go Backend

```powershell
# You're now on go-backend-test branch
# Make your changes, commit regularly

git add .
git commit -m "Add Go backend structure"
git push origin go-backend-test
```

---

## Step 3: If Everything Works ✅

### Merge to Master

```powershell
# Switch to master
git checkout master

# Merge the working branch
git merge go-backend-test

# Push to remote
git push origin master

# Optional: Delete test branch
git branch -d go-backend-test
git push origin --delete go-backend-test
```

---

## Step 4: If Something Goes Wrong ❌

### Option A: Rollback to Backup Branch

```powershell
# Switch to backup branch
git checkout backup-before-go-backend

# Create new master from backup
git checkout -b master-new
git branch -D master
git branch -m master

# Force push to remote (WARNING: This overwrites remote master)
git push origin master --force

# Or safer: Just work from backup branch
git checkout backup-before-go-backend
git checkout -b master-restored
```

### Option B: Undo Last Commits (if on master)

```powershell
# See commit history
git log --oneline

# Undo last commit (keeps changes)
git reset --soft HEAD~1

# Undo last commit (discards changes)
git reset --hard HEAD~1

# Undo multiple commits (e.g., last 3)
git reset --hard HEAD~3
```

### Option C: Revert Specific Commit

```powershell
# Find the commit hash
git log --oneline

# Revert that commit (creates new commit)
git revert <commit-hash>
git push origin master
```

---

## Step 5: Clean Up Branches

### After Successful Implementation

```powershell
# Delete local branches
git branch -d go-backend-test
git branch -d backup-before-go-backend

# Delete remote branches
git push origin --delete go-backend-test
git push origin --delete backup-before-go-backend
```

### Keep Backup for Later

```powershell
# Just delete the test branch
git branch -d go-backend-test
git push origin --delete go-backend-test

# Keep backup branch for reference
# (backup-before-go-backend stays on remote)
```

---

## Quick Reference Commands

### Check Current Branch
```powershell
git branch  # Shows local branches (* = current)
git status  # Shows current state
```

### Switch Branches
```powershell
git checkout master              # Switch to master
git checkout backup-before-go-backend  # Switch to backup
git checkout go-backend-test     # Switch to test branch
```

### View Changes
```powershell
git diff                        # Unstaged changes
git diff --staged              # Staged changes
git log --oneline -10          # Last 10 commits
```

### Emergency Reset
```powershell
# Discard ALL local changes and match remote master
git checkout master
git fetch origin
git reset --hard origin/master
```

---

## Railway Deployment Safety

### Separate Deployments
- Frontend (Vercel): Stays on master branch, unaffected
- Go Backend (Railway): Deploy from `go-backend-test` branch first
- Test thoroughly before merging to master

### Railway Rollback
```powershell
# Railway keeps deployment history
# You can rollback from Railway dashboard:
# 1. Go to your project
# 2. Click "Deployments"
# 3. Click "..." on previous working deployment
# 4. Click "Redeploy"
```

---

## Testing Checklist Before Merge

- [ ] Go backend deploys successfully on Railway
- [ ] Branch Master CRUD operations work
- [ ] Frontend connects to Go API correctly
- [ ] Authentication works
- [ ] No errors in Railway logs
- [ ] Performance is better than before
- [ ] Can switch back to Supabase client if needed

---

## Branch Strategy Summary

```
master (production)
  ├── backup-before-go-backend (safety copy)
  └── go-backend-test (active development)
```

**Rule:** Never work directly on master. Always use feature branches.

---

## Notes

- Keep `backup-before-go-backend` until Go backend is stable in production
- You can create multiple test branches: `go-backend-test-v2`, etc.
- Git commits are cheap - commit often with clear messages
- Railway deployment is independent of git branches
