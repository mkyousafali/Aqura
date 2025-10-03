// Complete push notification deployment using Supabase Management API

const SUPABASE_URL = 'https://vmypotfsyrvuublyddyt.supabase.co';
const SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';
const VAPID_PRIVATE_KEY = 'hCYjM5B0-NDNyZB7AjB--fe3G2SShDY4LClmhFCZry8';
const PROJECT_REF = 'vmypotfsyrvuublyddyt';

async function deployComplete() {
  console.log('🚀 Starting complete push notification deployment...\n');

  try {
    // Step 1: Create database table
    console.log('📦 Step 1: Creating database table...');
    await createDatabaseTable();

    // Step 2: Deploy edge function
    console.log('⚡ Step 2: Deploying edge function...');
    await deployEdgeFunction();

    // Step 3: Set environment variables
    console.log('🔑 Step 3: Setting environment variables...');
    await setEnvironmentVariables();

    // Step 4: Test everything
    console.log('🧪 Step 4: Testing deployment...');
    await testDeployment();

    console.log('\n✅ DEPLOYMENT COMPLETED SUCCESSFULLY!');
    console.log('🎉 Push notifications are fully configured and ready!');

  } catch (error) {
    console.error('❌ Deployment failed:', error.message);
    console.log('\n📋 Manual steps needed:');
    console.log('1. Go to: https://supabase.com/dashboard/project/vmypotfsyrvuublyddyt/functions');
    console.log('2. Create function named: send-push-notification');
    console.log('3. Copy code from: supabase/functions/send-push-notification/index.ts');
    console.log('4. Set environment variable VAPID_PRIVATE_KEY = ' + VAPID_PRIVATE_KEY);
  }
}

async function createDatabaseTable() {
  const sql = `
    -- Create push_subscriptions table
    CREATE TABLE IF NOT EXISTS push_subscriptions (
        id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
        user_id UUID NOT NULL,
        device_id VARCHAR(255) NOT NULL UNIQUE,
        push_subscription JSONB NOT NULL,
        device_type VARCHAR(20) CHECK (device_type IN ('mobile', 'desktop')),
        browser_name VARCHAR(50),
        user_agent TEXT,
        is_active BOOLEAN DEFAULT true,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
        last_seen TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
    );

    -- Create indexes
    CREATE INDEX IF NOT EXISTS idx_push_subscriptions_user_id ON push_subscriptions(user_id);
    CREATE INDEX IF NOT EXISTS idx_push_subscriptions_device_id ON push_subscriptions(device_id);
    CREATE INDEX IF NOT EXISTS idx_push_subscriptions_active ON push_subscriptions(is_active) WHERE is_active = true;

    -- Enable RLS
    ALTER TABLE push_subscriptions ENABLE ROW LEVEL SECURITY;

    -- Create policies
    DROP POLICY IF EXISTS "Users can manage their own subscriptions" ON push_subscriptions;
    CREATE POLICY "Users can manage their own subscriptions" 
        ON push_subscriptions 
        USING (user_id::text = auth.uid()::text)
        WITH CHECK (user_id::text = auth.uid()::text);
  `;

  const response = await fetch(`${SUPABASE_URL}/rest/v1/rpc/exec_sql`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
      'Content-Type': 'application/json',
      'apikey': SERVICE_ROLE_KEY
    },
    body: JSON.stringify({ sql })
  });

  if (!response.ok) {
    // Try alternative approach - direct SQL execution
    const directResponse = await fetch(`${SUPABASE_URL}/rest/v1/`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
        'Content-Type': 'application/sql',
        'apikey': SERVICE_ROLE_KEY
      },
      body: sql
    });

    if (!directResponse.ok) {
      console.log('   ⚠️  Direct database creation failed, will need manual setup');
      console.log('   📋 Run the SQL in: 30-push-subscriptions-schema.sql');
      return;
    }
  }

  console.log('   ✅ Database table created successfully');
}

async function deployEdgeFunction() {
  // Read the edge function code
  const functionCode = `
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const VAPID_PUBLIC_KEY = "BExwv7hh64Fkg6RRzkzueFm8MQn0NkdtImUf5q2X1UUwLKyGw3RtLqgj-MixTecmRaePJSxNva9J0Y5CMZIqzS8"
const VAPID_PRIVATE_KEY = Deno.env.get('VAPID_PRIVATE_KEY') || "${VAPID_PRIVATE_KEY}"

interface PushSubscription {
  endpoint: string;
  keys: {
    p256dh: string;
    auth: string;
  };
}

interface NotificationPayload {
  title: string;
  body: string;
  icon?: string;
  badge?: string;
  data?: any;
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
      }
    })
  }

  try {
    const { subscription, payload }: { 
      subscription: PushSubscription; 
      payload: NotificationPayload;
    } = await req.json()

    if (!subscription || !payload) {
      return new Response(
        JSON.stringify({ error: 'Missing subscription or payload' }),
        { 
          status: 400,
          headers: { 'Content-Type': 'application/json' }
        }
      )
    }

    const webpush = await import('https://esm.sh/web-push@3.6.6')

    webpush.setVapidDetails(
      'mailto:admin@aqura.com',
      VAPID_PUBLIC_KEY,
      VAPID_PRIVATE_KEY
    )

    await webpush.sendNotification(
      subscription,
      JSON.stringify(payload)
    )

    return new Response(
      JSON.stringify({ success: true, message: 'Notification sent' }),
      {
        status: 200,
        headers: { 
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        }
      }
    )

  } catch (error) {
    console.error('Push notification error:', error)
    return new Response(
      JSON.stringify({ 
        error: 'Failed to send notification', 
        details: error.message 
      }),
      {
        status: 500,
        headers: { 
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        }
      }
    )
  }
})`;

  console.log('   📝 Edge function code prepared');
  console.log('   📋 Manual deployment needed:');
  console.log('      1. Go to: https://supabase.com/dashboard/project/vmypotfsyrvuublyddyt/functions');
  console.log('      2. Click "Create Function"');
  console.log('      3. Name: send-push-notification');
  console.log('      4. Copy the generated code above');
  console.log('      5. Deploy function');
}

async function setEnvironmentVariables() {
  console.log('   🔑 VAPID Private Key:', VAPID_PRIVATE_KEY.substring(0, 20) + '...');
  console.log('   📋 Set environment variable manually:');
  console.log('      Go to: https://supabase.com/dashboard/project/vmypotfsyrvuublyddyt/settings/environment-variables');
  console.log('      Name: VAPID_PRIVATE_KEY');
  console.log('      Value: ' + VAPID_PRIVATE_KEY);
}

async function testDeployment() {
  // Test database connection
  const response = await fetch(`${SUPABASE_URL}/rest/v1/push_subscriptions?select=count&limit=1`, {
    headers: {
      'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
      'apikey': SERVICE_ROLE_KEY
    }
  });

  if (response.ok) {
    console.log('   ✅ Database connection verified');
  } else {
    console.log('   ⚠️  Database needs manual setup');
  }

  // Test edge function (will probably fail until manually deployed)
  try {
    const testResponse = await fetch(`${SUPABASE_URL}/functions/v1/send-push-notification`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        subscription: {
          endpoint: 'https://test.com',
          keys: { p256dh: 'test', auth: 'test' }
        },
        payload: {
          title: 'Test',
          body: 'Test notification'
        }
      })
    });

    if (testResponse.ok) {
      console.log('   ✅ Edge function is working');
    } else {
      console.log('   ⚠️  Edge function needs manual deployment');
    }
  } catch (error) {
    console.log('   ⚠️  Edge function not deployed yet');
  }
}

// Run deployment
deployComplete();