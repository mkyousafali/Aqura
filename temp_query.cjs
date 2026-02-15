const http = require('http');

function queryBridge(path, body = {}) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify(body);
    const options = {
      hostname: '192.168.0.3',
      port: 3333,
      path: path,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-secret': 'aqura-erp-bridge-2026',
        'Content-Length': data.length
      }
    };
    const req = http.request(options, (res) => {
      let result = '';
      res.on('data', chunk => result += chunk);
      res.on('end', () => resolve(JSON.parse(result)));
    });
    req.on('error', reject);
    req.write(data);
    req.end();
  });
}

async function main() {
  try {
    // Use the /test endpoint to verify connection
    const test = await queryBridge('/test');
    console.log('Database connection:', test.message);
    console.log('Total Products:', test.counts.totalProducts);
    console.log('Total Batches:', test.counts.totalBatches);
    console.log('Unique Barcodes:', test.counts.uniqueBarcodes);
    
    // Unfortunately the bridge doesn't support custom SQL queries
    // We can only use the fixed endpoints: /health, /test, /sync, /update-expiry
    console.log('\n--- NOTE ---');
    console.log('The ERP bridge API does not support custom SQL queries.');
    console.log('To count tables, we need to add a temporary endpoint to the bridge.');
    
    process.exit(0);
  } catch (e) {
    console.error('Error:', e.message);
    process.exit(1);
  }
}

main();
