import { createClient } from '@supabase/supabase-js';
import { readFileSync } from 'fs';

// Load Flyer Master environment variables
const flyerMasterEnvPath = 'D:/Aqura/Flyer Master/.env';
const flyerMasterEnv = readFileSync(flyerMasterEnvPath, 'utf-8');
const flyerMasterVars = {};

flyerMasterEnv.split('\n').forEach(line => {
  const trimmed = line.trim();
  if (trimmed && !trimmed.startsWith('#')) {
    const match = trimmed.match(/^([^=]+)=(.*)$/);
    if (match) {
      flyerMasterVars[match[1].trim()] = match[2].trim();
    }
  }
});

// Load Aqura environment variables
const aquraEnvPath = './frontend/.env';
const aquraEnv = readFileSync(aquraEnvPath, 'utf-8');
const aquraVars = {};

aquraEnv.split('\n').forEach(line => {
  const trimmed = line.trim();
  if (trimmed && !trimmed.startsWith('#')) {
    const match = trimmed.match(/^([^=]+)=(.*)$/);
    if (match) {
      aquraVars[match[1].trim()] = match[2].trim();
    }
  }
});

// Create Supabase clients
const flyerMasterSupabase = createClient(
  flyerMasterVars.PUBLIC_SUPABASE_URL,
  flyerMasterVars.SUPABASE_SERVICE_ROLE_KEY
);

const aquraSupabase = createClient(
  aquraVars.PUBLIC_SUPABASE_URL,
  aquraVars.SUPABASE_SERVICE_ROLE_KEY
);

console.log('🚀 Starting image copy process...');
console.log(`Source: ${flyerMasterVars.PUBLIC_SUPABASE_URL} (product-images)`);
console.log(`Destination: ${aquraVars.PUBLIC_SUPABASE_URL} (flyer-product-images)`);
console.log('');

async function copyImages() {
  try {
    // Step 1: List all files from source bucket
    console.log('📋 Listing files from source bucket (product-images)...');
    
    let allFiles = [];
    let page = 1;
    let hasMore = true;
    const limit = 1000;
    
    while (hasMore && page <= 10) {
      console.log(`   Loading page ${page}...`);
      
      const { data: files, error } = await flyerMasterSupabase.storage
        .from('product-images')
        .list('', {
          limit: limit,
          offset: (page - 1) * limit
        });
      
      if (error) {
        console.error('❌ Error listing files:', error);
        break;
      }
      
      if (!files || files.length === 0) {
        hasMore = false;
        break;
      }
      
      // Filter out folders and placeholder files
      const imageFiles = files.filter(file => 
        file.name && 
        !file.name.endsWith('/') && 
        !file.name.includes('.emptyFolder') &&
        /\.(png|jpg|jpeg|webp)$/i.test(file.name)
      );
      
      allFiles.push(...imageFiles);
      
      if (files.length < limit) {
        hasMore = false;
      }
      
      page++;
    }
    
    console.log(`✅ Found ${allFiles.length} images to copy\n`);
    
    if (allFiles.length === 0) {
      console.log('ℹ️  No images to copy. Exiting.');
      return;
    }
    
    // Step 2: Copy each file
    let successCount = 0;
    let errorCount = 0;
    let skippedCount = 0;
    
    console.log('📦 Copying images...\n');
    
    for (let i = 0; i < allFiles.length; i++) {
      const file = allFiles[i];
      const fileName = file.name;
      
      process.stdout.write(`[${i + 1}/${allFiles.length}] ${fileName}... `);
      
      try {
        // Check if file already exists in destination
        const { data: existingFiles } = await aquraSupabase.storage
          .from('flyer-product-images')
          .list('', {
            limit: 1,
            search: fileName
          });
        
        if (existingFiles && existingFiles.length > 0) {
          console.log('⏭️  Already exists (skipped)');
          skippedCount++;
          continue;
        }
        
        // Download from source
        const { data: fileData, error: downloadError } = await flyerMasterSupabase.storage
          .from('product-images')
          .download(fileName);
        
        if (downloadError) {
          console.log(`❌ Download error: ${downloadError.message}`);
          errorCount++;
          continue;
        }
        
        // Upload to destination
        const { error: uploadError } = await aquraSupabase.storage
          .from('flyer-product-images')
          .upload(fileName, fileData, {
            contentType: file.metadata?.mimetype || 'image/png',
            cacheControl: '3600',
            upsert: false
          });
        
        if (uploadError) {
          console.log(`❌ Upload error: ${uploadError.message}`);
          errorCount++;
          continue;
        }
        
        console.log('✅ Copied');
        successCount++;
        
      } catch (err) {
        console.log(`❌ Error: ${err.message}`);
        errorCount++;
      }
    }
    
    // Summary
    console.log('\n' + '='.repeat(50));
    console.log('📊 Copy Summary:');
    console.log('='.repeat(50));
    console.log(`✅ Successfully copied: ${successCount}`);
    console.log(`⏭️  Skipped (already exists): ${skippedCount}`);
    console.log(`❌ Errors: ${errorCount}`);
    console.log(`📁 Total processed: ${allFiles.length}`);
    console.log('='.repeat(50));
    
  } catch (error) {
    console.error('❌ Fatal error:', error);
    process.exit(1);
  }
}

// Run the copy process
copyImages();
