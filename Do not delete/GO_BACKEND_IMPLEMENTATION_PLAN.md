# Go Backend Implementation Plan

## 📅 Created: December 2, 2025
## 🎯 Goal: Add Go backend for Branch Master component with Railway auto-deploy

---

## Phase 1: Setup Go Backend Structure (Local)

### What We'll Create:
```
backend/
├── main.go                 # Entry point - starts server
├── go.mod                  # Dependencies (like package.json)
├── go.sum                  # Lock file (like pnpm-lock.yaml)
├── .env.example            # Environment variables template
├── Dockerfile              # For Railway deployment
├── railway.json            # Railway configuration
├── handlers/
│   └── branches.go         # Branch Master CRUD operations
├── models/
│   └── branch.go           # Branch data structure
├── middleware/
│   └── auth.go             # JWT authentication
└── database/
    └── supabase.go         # Supabase connection
```

### Steps:
1. ✅ Create `backend/` folder
2. ✅ Initialize Go module: `go mod init github.com/mkyousafali/Aqura/backend`
3. ✅ Create all files with basic structure
4. ✅ Install dependencies (Go will auto-download)
5. ✅ Test locally: `go run main.go`

---

## Phase 2: Implement Branch Master API

### Endpoints to Create:
```
GET    /api/branches           → List all branches
GET    /api/branches/:id       → Get single branch
POST   /api/branches           → Create new branch
PUT    /api/branches/:id       → Update branch
DELETE /api/branches/:id       → Delete branch
GET    /health                 → Health check for Railway
```

### What Each File Does:

**main.go** - Simple server setup
```go
package main

func main() {
    // Start HTTP server on port 8080
    // Route requests to handlers
}
```

**handlers/branches.go** - Business logic
```go
// GetBranches - fetch from Supabase
// CreateBranch - insert to Supabase
// UpdateBranch - update in Supabase
// DeleteBranch - delete from Supabase
```

**models/branch.go** - Data structure
```go
type Branch struct {
    ID        string
    Name      string
    Address   string
    Phone     string
    IsActive  bool
}
```

**middleware/auth.go** - Security
```go
// Check JWT token from Supabase
// Verify user is logged in
```

---

## Phase 3: Railway Deployment Setup

### What is Railway?
- Cloud platform (like Vercel but for backends)
- Auto-deploys when you push to GitHub
- Free $5/month credit (enough for testing)
- No complex configuration needed

### Setup Steps (One-time):

#### 1. Create Railway Account
- Go to: https://railway.app
- Click "Login with GitHub"
- Authorize Railway to access your repos

#### 2. Create New Project
- Click "New Project"
- Select "Deploy from GitHub repo"
- Choose `mkyousafali/Aqura` repository
- Select `go-backend-test` branch
- Railway auto-detects Go and builds it

#### 3. Configure Environment Variables
In Railway dashboard, add:
```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_KEY=your-anon-key
PORT=8080
```

#### 4. Get Your API URL
Railway gives you: `https://aqura-backend-production.up.railway.app`

---

## Phase 4: Auto-Deploy Configuration

### What We'll Add:

**railway.json** - Tells Railway how to deploy
```json
{
  "build": {
    "builder": "NIXPACKS"
  },
  "deploy": {
    "startCommand": "./backend",
    "healthcheckPath": "/health"
  }
}
```

**Dockerfile** (optional, Railway can work without it)
```dockerfile
FROM golang:1.21-alpine
WORKDIR /app
COPY . .
RUN go build -o backend
CMD ["./backend"]
```

### How Auto-Deploy Works:
1. You make changes to Go code
2. Run: `git add . && git commit -m "Update" && git push`
3. Railway detects push to `go-backend-test` branch
4. Railway automatically builds & deploys
5. New version live in ~2 minutes
6. You get notification: "Deployment successful"

---

## Phase 5: Frontend Integration

### Update Frontend to Use Go API

**Create env variable** (frontend/.env)
```
VITE_GO_API_URL=https://aqura-backend-production.up.railway.app
```

**Update Branch Master component** (example)
```javascript
// OLD: Direct Supabase
const { data } = await supabase.from('branches').select('*');

// NEW: Go API
const response = await fetch(`${import.meta.env.VITE_GO_API_URL}/api/branches`, {
  headers: {
    'Authorization': `Bearer ${session.access_token}`
  }
});
const data = await response.json();
```

### Testing Strategy:
1. Keep old Supabase code (commented)
2. Add Go API code
3. Test both work
4. If Go works → remove Supabase code
5. If Go fails → rollback to Supabase code

---

## Phase 6: Testing & Verification

### Local Testing:
```powershell
# Terminal 1: Run Go backend
cd backend
go run main.go
# Server runs on http://localhost:8080

# Terminal 2: Test with curl
curl http://localhost:8080/health
curl http://localhost:8080/api/branches
```

### Railway Testing:
```powershell
# Test deployed API
curl https://aqura-backend-production.up.railway.app/health
```

### Frontend Testing:
1. Run frontend: `npm run dev`
2. Go to Branch Master page
3. Try: List, Create, Update, Delete branches
4. Check Railway logs for any errors

---

## Timeline Estimate

| Phase | Time | What You'll See |
|-------|------|-----------------|
| 1. Setup | 30 min | Files created, Go installed |
| 2. Implement | 1 hour | API working locally |
| 3. Railway Setup | 15 min | Account created, project linked |
| 4. Deploy Config | 15 min | Auto-deploy working |
| 5. Frontend Update | 30 min | Branch Master using Go |
| 6. Testing | 30 min | Everything working |
| **Total** | **~3 hours** | Full Go backend live |

---

## What You Need:

### Required:
- ✅ Go installed (we'll install it)
- ✅ GitHub account (you have it)
- ✅ Supabase credentials (you have them)
- ⬜ Railway account (free, we'll create)

### Not Required:
- ❌ Go programming knowledge (I'll write code)
- ❌ Docker knowledge (Railway handles it)
- ❌ DevOps experience (Railway auto-configures)

---

## Cost Breakdown

### Railway Pricing:
- **Hobby Plan**: $5/month credit (free tier)
- Usage:
  - 500MB RAM: ~$1.50/month
  - 1GB Storage: ~$0.20/month
  - Bandwidth: Free for starter usage
- **First month**: Free (enough credit for testing)
- **Ongoing**: ~$2-3/month if you keep it

### Current Setup (for comparison):
- Vercel (Frontend): Free
- Supabase: Free tier
- **With Go**: Vercel + Supabase + Railway ~$2-3/month

---

## Success Criteria

### You'll know it's working when:
1. ✅ Go code runs locally without errors
2. ✅ Railway dashboard shows "Deployment successful"
3. ✅ Health check returns 200 OK
4. ✅ Branch Master CRUD operations work in frontend
5. ✅ Railway logs show requests coming through
6. ✅ Performance is faster than before

---

## Rollback Plan (If Needed)

### Quick Rollback:
```powershell
# Switch back to backup branch
git checkout backup-before-go-backend

# Or just update frontend to use Supabase again
# (Go backend stays on Railway but unused)
```

### Delete Railway Project:
1. Go to Railway dashboard
2. Click project settings
3. Click "Delete Project"
4. Confirm deletion

---

## Next Steps

### Ready to Start?

**Step 1**: Install Go
```powershell
winget install GoLang.Go
```

**Step 2**: Create backend structure
- I'll create all files
- You just review

**Step 3**: Test locally
- Run `go run main.go`
- See it working

**Step 4**: Deploy to Railway
- Follow Railway setup guide
- Push to git = auto deploy

### Questions Before Starting?
- Do you have Go installed?
- Do you have Supabase URL & API key ready?
- Ready to create Railway account?

---

## Support Resources

### If Something Goes Wrong:

**Go Backend Not Starting:**
- Check: `go mod tidy` (fixes dependencies)
- Check: Port 8080 not in use
- Check: `.env` file exists with correct values

**Railway Deployment Failed:**
- Check: Railway logs (dashboard → deployment → logs)
- Check: Environment variables set correctly
- Check: `go.mod` file is in backend/ folder

**Frontend Can't Connect:**
- Check: CORS enabled in Go backend
- Check: API URL is correct
- Check: JWT token is being sent

### Get Help:
- Railway Discord: https://discord.gg/railway
- Go Documentation: https://go.dev/doc/
- Ask me anytime!

---

## Ready?

Say "yes" and I'll:
1. Check if Go is installed
2. Create complete backend structure
3. Guide you through Railway setup
4. Update frontend to use Go API
5. Test everything works

No Go knowledge needed - I'll write all the code! 🚀
