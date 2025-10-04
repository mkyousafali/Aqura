# Manual Service Worker Removal via DevTools

## Steps:
1. Open your browser (Chrome/Edge/Firefox)
2. Press F12 to open DevTools
3. Go to **Application** tab (Chrome/Edge) or **Application** tab (Firefox)
4. In the left sidebar, click **Service Workers**
5. You'll see all registered service workers
6. For each service worker:
   - Click **Unregister** button
   - Or click **Stop** if it's running
7. Clear all storage:
   - Go to **Storage** section in left sidebar
   - Click **Clear site data**
   - Check all boxes and click **Clear site data**

## Alternative (Chrome/Edge):
1. Go to chrome://settings/content/all
2. Find your localhost site
3. Click the trash icon to delete all data