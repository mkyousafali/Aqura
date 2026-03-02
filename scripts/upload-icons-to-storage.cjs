/**
 * Upload existing static icons to Supabase storage bucket 'app-icons'
 * Run: node scripts/upload-icons-to-storage.js
 */
const fs = require('fs');
const path = require('path');

const SUPABASE_URL = 'https://supabase.urbanaqura.com';
const SERVICE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NjQ4NzU1MjcsImV4cCI6MjA4MDQ1MTUyN30.6mj0wiHW0ljpYNIEeYG-r--577LDNbxCLj7SZOghbv0';

const BUCKET = 'app-icons';
const ICONS_DIR = path.join(__dirname, '..', 'frontend', 'static', 'icons');

const MIME_MAP = {
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.svg': 'image/svg+xml',
    '.webp': 'image/webp',
    '.gif': 'image/gif'
};

async function uploadFile(filePath, fileName) {
    const ext = path.extname(fileName).toLowerCase();
    const mime = MIME_MAP[ext];
    if (!mime) {
        console.log(`⏩ Skipping ${fileName} (not an image)`);
        return false;
    }

    const fileBuffer = fs.readFileSync(filePath);
    
    const url = `${SUPABASE_URL}/storage/v1/object/${BUCKET}/${encodeURIComponent(fileName)}`;
    
    const response = await fetch(url, {
        method: 'POST',
        headers: {
            'Authorization': `Bearer ${SERVICE_KEY}`,
            'Content-Type': mime,
            'x-upsert': 'true'
        },
        body: fileBuffer
    });

    if (response.ok) {
        console.log(`✅ Uploaded: ${fileName}`);
        return true;
    } else {
        const errText = await response.text();
        console.error(`❌ Failed ${fileName}: ${response.status} ${errText}`);
        return false;
    }
}

async function main() {
    console.log(`📂 Reading icons from: ${ICONS_DIR}`);
    
    const files = fs.readdirSync(ICONS_DIR);
    console.log(`Found ${files.length} files\n`);
    
    let success = 0;
    let failed = 0;
    let skipped = 0;
    
    for (const file of files) {
        const filePath = path.join(ICONS_DIR, file);
        const stat = fs.statSync(filePath);
        
        if (stat.isDirectory()) {
            console.log(`📁 Skipping directory: ${file}`);
            skipped++;
            continue;
        }
        
        const result = await uploadFile(filePath, file);
        if (result) success++;
        else if (result === false && !MIME_MAP[path.extname(file).toLowerCase()]) skipped++;
        else failed++;
    }
    
    console.log(`\n📊 Results: ${success} uploaded, ${failed} failed, ${skipped} skipped`);
}

main().catch(console.error);
