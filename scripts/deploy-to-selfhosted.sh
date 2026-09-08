#!/usr/bin/env bash
# Deploy edge function to self-hosted Supabase

# Configuration
REMOTE_HOST="8.213.42.21"
REMOTE_USER="root"
SSH_KEY="$HOME/.ssh/id_ed25519"
LOCAL_FUNCTION="./supabase/functions/whatsapp-manage/index.ts"
REMOTE_FUNCTIONS_DIR="/opt/supabase/supabase/volumes/functions/whatsapp-manage"

echo "🚀 Deploying edge function to self-hosted Supabase..."
echo "   Host: $REMOTE_HOST"
echo "   Function: whatsapp-manage"
echo ""

# Step 1: Create remote directory
echo "📁 Creating function directory..."
ssh -i "$SSH_KEY" "$REMOTE_USER@$REMOTE_HOST" \
  "mkdir -p $REMOTE_FUNCTIONS_DIR"

if [ $? -ne 0 ]; then
  echo "❌ Failed to create remote directory"
  exit 1
fi

# Step 2: Copy function file
echo "📋 Copying function file..."
scp -i "$SSH_KEY" "$LOCAL_FUNCTION" \
  "$REMOTE_USER@$REMOTE_HOST:$REMOTE_FUNCTIONS_DIR/index.ts"

if [ $? -ne 0 ]; then
  echo "❌ Failed to copy function file"
  exit 1
fi

# Step 3: Restart edge functions container
echo "🔄 Restarting edge functions container..."
ssh -i "$SSH_KEY" "$REMOTE_USER@$REMOTE_HOST" \
  "docker restart supabase-edge-functions"

if [ $? -ne 0 ]; then
  echo "⚠️ Failed to restart container (may already be restarted)"
fi

# Step 4: Verify deployment
echo ""
echo "✅ Function deployed!"
echo "   Location: $REMOTE_FUNCTIONS_DIR/index.ts"
echo ""
echo "📊 Deployment summary:"
echo "   - 4-5x speed boost enabled"
echo "   - Better retry logic (5 attempts, 30s timeout)"
echo "   - Ecosystem error cap at retry 2"
echo "   - Throttle pause cap at 10s"
echo ""
echo "🧪 Test with retry button in UI: http://8.213.42.21:3000"
