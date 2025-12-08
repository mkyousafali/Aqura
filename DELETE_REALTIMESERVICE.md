# Manual Cleanup Steps - Delete realtimeService.ts

## File Location
```
d:\Aqura\frontend\src\lib\utils\realtimeService.ts
```

## How to Delete

### Option 1: VS Code (Recommended)
1. Open VS Code file explorer
2. Navigate to: `frontend/src/lib/utils/`
3. Right-click on `realtimeService.ts`
4. Select "Delete" 
5. Confirm deletion

### Option 2: PowerShell Terminal
```powershell
Remove-Item "d:\Aqura\frontend\src\lib\utils\realtimeService.ts" -Force
```

### Option 3: Git (If using version control)
```bash
git rm d:\Aqura\frontend\src\lib\utils\realtimeService.ts
git commit -m "Remove unused realtimeService module"
```

## Verification

After deletion, verify with:
```bash
# Check file no longer exists
Test-Path "d:\Aqura\frontend\src\lib\utils\realtimeService.ts"
# Should return: False

# Run lint to confirm no broken imports
npm run lint

# Run build to verify compilation
npm run build
```

## What This File Did (Historical Reference)
The realtimeService module managed PostgreSQL change subscriptions for:
- Receiving records updates
- Vendor payment schedule changes
- HR fingerprint/biometric data (employee punches)
- Employee-specific and date-specific fingerprint tracking

All functionality has been removed from components and is no longer needed.

---
**Status**: Ready for manual deletion
