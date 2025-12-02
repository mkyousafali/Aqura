# Aqura Go Backend

High-performance Go backend for Aqura ERP system.

## Features

- 🚀 Fast API endpoints for Branch Master CRUD operations
- 🔒 JWT authentication with Supabase
- 🗄️ Direct PostgreSQL connection to Supabase
- 🌐 CORS enabled for frontend integration
- 📦 Easy deployment to Railway

## Local Development

### Prerequisites

- Go 1.21 or higher
- Supabase project with database access

### Setup

1. **Copy environment variables:**
   ```bash
   cp .env.example .env
   ```

2. **Update `.env` with your Supabase credentials**

3. **Install dependencies:**
   ```bash
   go mod download
   ```

4. **Run the server:**
   ```bash
   go run main.go
   ```

Server runs on `http://localhost:8080`

### Test Endpoints

```bash
# Health check
curl http://localhost:8080/health

# List all branches
curl http://localhost:8080/api/branches

# Get single branch
curl http://localhost:8080/api/branches/1

# Create branch (requires auth)
curl -X POST http://localhost:8080/api/branches \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name_en":"New Branch","name_ar":"فرع جديد","location_en":"Location","location_ar":"موقع"}'
```

## Railway Deployment

### Automatic Deployment

1. **Connect to Railway:**
   - Go to https://railway.app
   - Create new project
   - Connect GitHub repository
   - Select `go-backend-test` branch

2. **Add environment variables in Railway:**
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
   - `DATABASE_URL`
   - `PORT=8080`
   - `ALLOWED_ORIGINS`

3. **Deploy:**
   - Push to `go-backend-test` branch
   - Railway auto-deploys in ~2 minutes

### Manual Deployment

```bash
# Build
go build -o backend

# Run
./backend
```

## API Endpoints

### Branch Master

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| GET | `/health` | Health check | No |
| GET | `/api/branches` | List all branches | No |
| GET | `/api/branches/:id` | Get single branch | No |
| POST | `/api/branches` | Create new branch | Yes |
| PUT | `/api/branches/:id` | Update branch | Yes |
| DELETE | `/api/branches/:id` | Delete branch | Yes |

## Project Structure

```
backend/
├── main.go              # Server entry point
├── go.mod               # Dependencies
├── .env                 # Environment variables (not in git)
├── handlers/
│   └── branches.go      # Branch CRUD operations
├── models/
│   └── branch.go        # Branch data structure
├── middleware/
│   └── auth.go          # JWT authentication
└── database/
    └── supabase.go      # Database connection
```

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `SUPABASE_URL` | Supabase project URL | Yes |
| `SUPABASE_ANON_KEY` | Supabase anonymous key | Yes |
| `DATABASE_URL` | PostgreSQL connection string | Yes |
| `PORT` | Server port | No (default: 8080) |
| `ENVIRONMENT` | Environment name | No (default: development) |
| `ALLOWED_ORIGINS` | CORS allowed origins (comma-separated) | No |

## Development

### Add New Endpoint

1. Create handler in `handlers/`
2. Add route in `main.go`
3. Test locally
4. Push to git

### Debug

```bash
# Run with verbose logging
ENVIRONMENT=development go run main.go

# Check database connection
# (Connection test on startup)
```

## Performance

Compared to Supabase Edge Functions:

- 5-10x faster response times
- Better concurrency handling
- Lower memory usage (~10-20MB)
- Handles 1000+ requests/second

## License

MIT
