# Warning Generation System Deployment Guide

## Issue
The warning generation feature was failing with a 404 error in the deployed version because the original configuration used `@sveltejs/adapter-static`, which generates static sites and doesn't support server-side API routes.

## Solution
We've updated the configuration to support server-side API routes for the OpenAI integration.

## Changes Made

### 1. Updated SvelteKit Adapter
- Changed from `@sveltejs/adapter-static` to `@sveltejs/adapter-auto`
- This allows SvelteKit to automatically detect the deployment platform and choose the appropriate adapter

### 2. Environment Variables
Added proper private environment variables for server-side API access:
```
OPENAI_API_KEY=your_openai_api_key_here
VITE_OPENAI_API_KEY=your_openai_api_key_here  # For backwards compatibility
```

### 3. API Route Improvements
- Enhanced error handling and logging in `/api/generate-warning`
- Better environment variable detection
- More detailed error messages

### 4. Utility Functions
Created `warningGenerator.js` utility with:
- Automatic fallback handling
- Better error messages
- Centralized warning generation logic

## Deployment Requirements

### For Vercel
1. Set environment variable: `OPENAI_API_KEY=your_key`
2. The auto adapter will automatically use `@sveltejs/adapter-vercel`

### For Netlify
1. Set environment variable: `OPENAI_API_KEY=your_key`
2. The auto adapter will automatically use `@sveltejs/adapter-netlify`

### For Node.js Server
1. Install additional adapter: `pnpm add @sveltejs/adapter-node`
2. Update svelte.config.js to use `adapter-node` if needed
3. Set environment variable: `OPENAI_API_KEY=your_key`

### For Static Hosting (GitHub Pages, etc.)
If you must use static hosting:
1. Consider using serverless functions (Vercel Functions, Netlify Functions)
2. Or implement a separate backend service for AI generation
3. The current implementation will show a helpful error message

## Environment Variables to Set in Deployment

```bash
OPENAI_API_KEY=sk-proj-your-actual-openai-api-key-here
```

## Testing the Fix

1. Deploy with the new configuration
2. Try generating a warning in the deployed app
3. Check browser console for any error messages
4. Verify the API endpoint is accessible at `/api/generate-warning`

## Troubleshooting

### If you still get 404 errors:
1. Check that environment variables are set correctly
2. Verify the deployment platform supports server-side routes
3. Check deployment logs for any build errors

### If you get API key errors:
1. Verify the OPENAI_API_KEY environment variable is set
2. Check that the API key is valid and has sufficient credits
3. Ensure the key has the correct permissions

### If the app builds but API doesn't work:
1. Check the deployment platform's serverless function limits
2. Verify network connectivity to OpenAI API
3. Review server logs for detailed error messages

## Fallback Options

If server-side API routes are not available:
1. Use a separate backend service
2. Use serverless functions (Vercel/Netlify Functions)
3. Use a third-party AI API proxy service
4. Implement client-side generation (not recommended for production)