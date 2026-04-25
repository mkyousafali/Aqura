# 🚀 Deploying Aqura to Vercel - Environment Variables Guide

## Problem
AI image generation (`/api/ai-marketing/generate-poster`) returns 500 errors on deployed versions because Google Cloud environment variables are not configured on Vercel.

## Solution

### 1. Accessing Vercel Project Settings

1. Go to https://vercel.com
2. Select your **Aqura** project
3. Navigate to: **Settings** → **Environment Variables**

### 2. Required Environment Variables

Add the following variables to your Vercel project. All of these are **critical** for AI features:

#### Google Cloud Service Account Variables
These enable Imagen (image generation), Gemini (text generation), and other AI features.

| Variable | Value | Source |
|----------|-------|--------|
| `GOOGLE_PROJECT_ID` | `your-google-project-id` | Google Cloud Console |
| `GOOGLE_CLIENT_EMAIL` | `your-service-account@your-project.iam.gserviceaccount.com` | Google Cloud Console |
| `GOOGLE_PRIVATE_KEY` | `-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n` | Google Cloud Console (service account JSON) |
| `GOOGLE_LOCATION` | `europe-west4` | Google Cloud location for Vertex AI APIs |

#### Supabase Variables
```
VITE_SUPABASE_URL=https://supabase.urbanaqura.com
VITE_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
VITE_SUPABASE_SERVICE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

#### Other APIs
```
GOOGLE_API_KEY=...
VITE_GOOGLE_MAPS_API_KEY=...
REMOVE_BG_API_KEY=...
PIXABAY_API_KEY=...
VAPID_PRIVATE_KEY=...
FACEBOOK_TOKEN=...
```

### 3. How to Format GOOGLE_PRIVATE_KEY for Vercel

**Important:** The private key must be on a SINGLE LINE with escaped newlines.

#### ❌ WRONG (will fail):
```
-----BEGIN PRIVATE KEY-----
<key contents on multiple lines>
-----END PRIVATE KEY-----
```

#### ✅ CORRECT (single line with \n):
```
-----BEGIN PRIVATE KEY-----\n<key contents>\n-----END PRIVATE KEY-----\n
```

### 4. Step-by-Step Instructions

1. **Get Google Service Account Key:**
   - Go to Google Cloud Console
   - Select project `your-google-project-id`
   - Navigate to: **Service Accounts** → `your-service-account@your-project.iam.gserviceaccount.com`
   - Download the JSON key file
   - Open the JSON file and copy the value of `private_key`

2. **Convert Private Key for Vercel:**
   ```bash
   # If you have jq installed:
   jq -r '.private_key' path/to/service-account-key.json
   ```
   This outputs the key already formatted with `\n` (escaped newlines).

3. **Add to Vercel:**
   - In Vercel dashboard, click: **+ Add Environment Variable**
   - **Name:** `GOOGLE_PRIVATE_KEY`
   - **Value:** (paste the key from step 2)
   - Leave **Environments** as: Production, Preview, Development
   - Click **Save**

4. **Repeat for Other Google Variables:**
   - `GOOGLE_PROJECT_ID`
   - `GOOGLE_CLIENT_EMAIL`
   - `GOOGLE_LOCATION`

5. **Redeploy:**
   - Go to: **Deployments**
   - Click the **...** menu on the latest deployment
   - Select: **Redeploy**
   - Or push a new commit to automatically trigger deployment

### 5. Verify Deployment

After redeploying, test the AI image generation:

```bash
curl -X POST https://your-domain.app/api/ai-marketing/generate-poster \
  -H "Content-Type: application/json" \
  -d '{
    "brandId": 1,
    "platform": "instagram_feed",
    "language": "ar",
    "products": [{"id": 1, "product_name_ar": "منتج", "priceAfterOffer": "100"}]
  }'
```

If successful, you'll get:
```json
{
  "ok": true,
  "fileId": "...",
  "signedUrl": "https://...",
  "imagePrompt": "..."
}
```

If still failing, check the error message in the response for specific diagnostic information.

### 6. Debugging Failed Deployments

The enhanced endpoint now returns detailed error messages:

```json
{
  "ok": false,
  "stage": "prompt_generation",
  "message": "Token exchange failed [401]: ...",
  "debug": {
    "errorCode": "...",
    "errorStack": "..."
  }
}
```

Common errors:
- **400 + "Missing GOOGLE_PROJECT_ID"** → Variable not set in Vercel
- **401 + "Token exchange failed"** → Invalid Google credentials
- **403** → Service account doesn't have required permissions
- **429** → Google Cloud quota exceeded
- **500 + "Imagen error"** → Vertex AI API failure (check API enabled in Google Cloud)

### 7. Troubleshooting Checklist

- [ ] All `GOOGLE_*` variables are set in Vercel dashboard
- [ ] `GOOGLE_PRIVATE_KEY` is a single line with `\n` (not actual newlines)
- [ ] Google Cloud Project `your-google-project-id` exists
- [ ] Service account has "Vertex AI User" role
- [ ] Vertex AI APIs are enabled in Google Cloud Console:
  - `aiplatform.googleapis.com`
  - `artifactregistry.googleapis.com`
- [ ] Service account has quota available
- [ ] Deployment has completed and rebuilt (not just redeployed old build)

### 8. For Local Development

Use `frontend/.env` with your credentials:
```
GOOGLE_PROJECT_ID=your-google-project-id
GOOGLE_CLIENT_EMAIL=your-service-account@your-project.iam.gserviceaccount.com
GOOGLE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
GOOGLE_LOCATION=europe-west4
```

The private key in `.env` CAN have actual newlines (the code handles both formats).
