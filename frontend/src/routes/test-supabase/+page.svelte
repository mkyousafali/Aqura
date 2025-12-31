<script lang="ts">
  import { onMount } from 'svelte';

  let status = 'Loading...';
  let details: any = null;

  onMount(async () => {
    try {
      // Test direct fetch with header
      const key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzY0ODc1NTI3LCJleHAiOjIwODA0NTE1Mjd9.IT_YSPU9oivuGveKfRarwccr59SNMzX_36cw04Lf448';
      
      const response = await fetch('https://supabase.urbanaqura.com/rest/v1/hr_employees?select=id,name&limit=1', {
        method: 'GET',
        headers: {
          'apikey': key,
          'Authorization': `Bearer ${key}`,
          'Content-Type': 'application/json'
        }
      });

      details = {
        status: response.status,
        statusText: response.statusText,
        headers: Object.fromEntries(response.headers.entries()),
        body: await response.text()
      };

      status = response.status === 200 ? '✅ Success' : `❌ Failed (${response.status})`;
    } catch (error) {
      status = `❌ Error: ${error}`;
      details = { error: String(error) };
    }
  });
</script>

<div style="padding: 20px; font-family: monospace; white-space: pre-wrap;">
  <h1>Supabase Connection Test</h1>
  <p><strong>Status:</strong> {status}</p>
  <p><strong>Details:</strong></p>
  <pre>{JSON.stringify(details, null, 2)}</pre>
</div>
