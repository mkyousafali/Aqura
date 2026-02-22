import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { execSync } from 'child_process';
import https from 'https';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// Get command line arguments
const rawArgs = process.argv.slice(2);
const deployFlag = rawArgs.includes('--deploy');
const args = rawArgs.filter(a => a !== '--deploy');
const interfaceType = args[0]?.toLowerCase();
const customMessage = args[1];

const validInterfaces = ['desktop', 'mobile', 'cashier', 'customer', 'all'];

if (!interfaceType || !validInterfaces.includes(interfaceType)) {
  console.error('❌ Error: Please specify a valid interface type');
  console.error('Usage: node "Do not delete/simple-push.js" <interface> [commit-message] [--deploy]');
  console.error('Valid interfaces: desktop, mobile, cashier, customer, all');
  console.error('Flags:');
  console.error('  --deploy   Build frontend & upload to cloud for branch updates');
  process.exit(1);
}

// Read current versions
const rootPackagePath = path.join(__dirname, '..', 'package.json');
const frontendPackagePath = path.join(__dirname, '..', 'frontend', 'package.json');

const rootPackage = JSON.parse(fs.readFileSync(rootPackagePath, 'utf-8'));
const frontendPackage = JSON.parse(fs.readFileSync(frontendPackagePath, 'utf-8'));

// Parse current version (format: AQ23.8.3.3 = AQ[Desktop].[Mobile].[Cashier].[Customer])
const currentVersion = frontendPackage.version;
const versionMatch = currentVersion.match(/^AQ(\d+)\.(\d+)\.(\d+)\.(\d+)$/);

if (!versionMatch) {
  console.error('❌ Error: Invalid version format in frontend/package.json');
  console.error(`Current version: ${currentVersion}`);
  process.exit(1);
}

let [, desktop, mobile, cashier, customer] = versionMatch.map(Number);

// Increment version based on interface type
switch (interfaceType) {
  case 'desktop':
    desktop++;
    break;
  case 'mobile':
    mobile++;
    break;
  case 'cashier':
    cashier++;
    break;
  case 'customer':
    customer++;
    break;
  case 'all':
    desktop++;
    mobile++;
    cashier++;
    customer++;
    break;
}

const newVersion = `AQ${desktop}.${mobile}.${cashier}.${customer}`;
const shortVersion = `${desktop}.${mobile}.${cashier}`;

console.log(`📦 Updating version: ${currentVersion} → ${newVersion}`);

// Update package.json files
rootPackage.version = shortVersion;
frontendPackage.version = newVersion;

fs.writeFileSync(rootPackagePath, JSON.stringify(rootPackage, null, 2) + '\n', 'utf-8');
fs.writeFileSync(frontendPackagePath, JSON.stringify(frontendPackage, null, 2) + '\n', 'utf-8');

console.log('✅ Updated package.json files');

// Update Sidebar.svelte with new version
const sidebarPath = path.join(__dirname, '..', 'frontend', 'src', 'lib', 'components', 'desktop-interface', 'common', 'Sidebar.svelte');

if (fs.existsSync(sidebarPath)) {
  let sidebarContent = fs.readFileSync(sidebarPath, 'utf-8');
  
  // Replace version in the version display section (in the button)
  sidebarContent = sidebarContent.replace(
    /AQ\d+\.\d+\.\d+\.\d+/g,
    newVersion
  );
  
  fs.writeFileSync(sidebarPath, sidebarContent, 'utf-8');
  console.log('✅ Updated Sidebar.svelte version display');
}

// Update Login Screen (+page.svelte) with new version
const loginPagePath = path.join(__dirname, '..', 'frontend', 'src', 'routes', 'desktop-interface', '+page.svelte');

if (fs.existsSync(loginPagePath)) {
  let loginContent = fs.readFileSync(loginPagePath, 'utf-8');
  
  loginContent = loginContent.replace(
    /AQ\d+\.\d+\.\d+\.\d+/g,
    newVersion
  );
  
  fs.writeFileSync(loginPagePath, loginContent, 'utf-8');
  console.log('✅ Updated Login Screen version display');
}

// Update Mobile Interface layout with new version (shown in top bar hamburger menu)
const mobileLayoutPath = path.join(__dirname, '..', 'frontend', 'src', 'routes', 'mobile-interface', '+layout.svelte');

if (fs.existsSync(mobileLayoutPath)) {
  let mobileLayoutContent = fs.readFileSync(mobileLayoutPath, 'utf-8');
  
  // Update mobile version variable (format: AQ8 from AQ23.8.3.3, extract the mobile number)
  mobileLayoutContent = mobileLayoutContent.replace(
    /let mobileVersion = 'AQ\d+';/,
    `let mobileVersion = 'AQ${mobile}';`
  );
  
  fs.writeFileSync(mobileLayoutPath, mobileLayoutContent, 'utf-8');
  console.log('✅ Updated Mobile Interface version display (top bar menu)');
}

// Update Customer Interface TopBar with new version
const customerTopBarPath = path.join(__dirname, '..', 'frontend', 'src', 'lib', 'components', 'customer-interface', 'common', 'TopBar.svelte');

if (fs.existsSync(customerTopBarPath)) {
  let customerTopBarContent = fs.readFileSync(customerTopBarPath, 'utf-8');
  
  // Update customer version (format: AQ6 from AQ23.8.3.3, extract the customer number)
  customerTopBarContent = customerTopBarContent.replace(
    /let customerVersion = 'AQ\d+';/,
    `let customerVersion = 'AQ${customer}';`
  );
  
  fs.writeFileSync(customerTopBarPath, customerTopBarContent, 'utf-8');
  console.log('✅ Updated Customer Interface version display');
}

// Update Cashier Interface sidebar with new version
const cashierInterfacePath = path.join(__dirname, '..', 'frontend', 'src', 'lib', 'components', 'cashier-interface', 'CashierInterface.svelte');

if (fs.existsSync(cashierInterfacePath)) {
  let cashierInterfaceContent = fs.readFileSync(cashierInterfacePath, 'utf-8');
  
  // Update cashier version (format: AQ5 from AQ23.8.3.3, extract the cashier number)
  cashierInterfaceContent = cashierInterfaceContent.replace(
    /let cashierVersion = 'AQ\d+';/,
    `let cashierVersion = 'AQ${cashier}';`
  );
  
  fs.writeFileSync(cashierInterfacePath, cashierInterfaceContent, 'utf-8');
  console.log('✅ Updated Cashier Interface version display');
}

// Define interface names mapping
const interfaceNames = {
  desktop: 'Desktop',
  mobile: 'Mobile',
  cashier: 'Cashier',
  customer: 'Customer',
  all: 'All Interfaces'
};

const defaultMessage = `chore(version): bump ${interfaceNames[interfaceType]} to ${newVersion}`;
const commitMessage = customMessage || defaultMessage;

// Update VersionChangelog.svelte with new version and changelog entry
const changelogPath = path.join(__dirname, '..', 'frontend', 'src', 'lib', 'components', 'desktop-interface', 'common', 'VersionChangelog.svelte');

if (fs.existsSync(changelogPath)) {
  let changelogContent = fs.readFileSync(changelogPath, 'utf-8');
  
  // Create the new changelog HTML — just update the version-format section
  // The AI agent will manually refine the full changelog entry
  
  // Replace the version-format section
  changelogContent = changelogContent.replace(
    /<p class="version-title">Version AQ\d+\.\d+\.\d+\.\d+<\/p>/,
    `<p class="version-title">Version ${newVersion}</p>`
  );
  changelogContent = changelogContent.replace(
    /<p class="version-details">Desktop: \d+ \| Mobile: \d+ \| Cashier: \d+ \| Customer: \d+<\/p>/,
    `<p class="version-details">Desktop: ${desktop} | Mobile: ${mobile} | Cashier: ${cashier} | Customer: ${customer}</p>`
  );
  
  fs.writeFileSync(changelogPath, changelogContent, 'utf-8');
  console.log('✅ Updated VersionChangelog.svelte with new version');
}

// Stage all changes
try {
  execSync('git add -A', { stdio: 'inherit' });
  console.log('✅ Staged all changes');
  
  // Create commit
  execSync(`git commit -m "${commitMessage}"`, { stdio: 'inherit' });
  console.log('✅ Created commit');
  
  console.log('\n🎉 Version updated successfully!');
  console.log(`📌 New version: ${newVersion}`);
  
  // =============================================
  // DEPLOY: Build & Upload to cloud for branches
  // =============================================
  if (deployFlag) {
    console.log('\n🚀 --deploy flag detected. Building & uploading for branch updates...\n');
    
    // Read Supabase config from frontend/.env
    const envPath = path.join(__dirname, '..', 'frontend', '.env');
    if (!fs.existsSync(envPath)) {
      console.error('❌ frontend/.env not found. Cannot upload build.');
      process.exit(1);
    }
    const envContent = fs.readFileSync(envPath, 'utf-8');
    const envVars = {};
    envContent.split(/\r?\n/).forEach(line => {
      line = line.trim();
      if (!line || line.startsWith('#')) return;
      const eqIdx = line.indexOf('=');
      if (eqIdx > 0) {
        envVars[line.substring(0, eqIdx).trim()] = line.substring(eqIdx + 1).trim();
      }
    });
    
    const SUPABASE_URL = envVars['VITE_SUPABASE_URL'];
    const SERVICE_KEY = envVars['VITE_SUPABASE_SERVICE_KEY'];
    
    if (!SUPABASE_URL || !SERVICE_KEY) {
      console.error('❌ VITE_SUPABASE_URL or VITE_SUPABASE_SERVICE_KEY not found in frontend/.env');
      process.exit(1);
    }
    
    const frontendDir = path.join(__dirname, '..', 'frontend');
    const svelteConfigPath = path.join(frontendDir, 'svelte.config.js');
    const buildDir = path.join(frontendDir, 'build');
    const zipPath = path.join(__dirname, '..', 'aqura-frontend-build.zip');
    
    // Step 1: Set BUILD_ADAPTER=node for adapter-node build
    console.log('📦 Step 1/5: Setting BUILD_ADAPTER=node for branch build...');
    process.env.BUILD_ADAPTER = 'node';
    console.log('   ✅ BUILD_ADAPTER=node set (svelte.config.js reads this automatically)');
    
    try {
      // Step 2: Build frontend
      console.log('🔨 Step 2/5: Building frontend (this may take a minute)...');
      execSync('npm run build', { cwd: frontendDir, stdio: 'inherit', env: { ...process.env, BUILD_ADAPTER: 'node', NODE_OPTIONS: '--max-old-space-size=8192' } });
      console.log('   ✅ Frontend built successfully');
      
      // Step 3: Create ZIP of build output
      console.log('📁 Step 3/5: Creating ZIP archive...');
      if (fs.existsSync(zipPath)) fs.unlinkSync(zipPath);
      
      // Use PowerShell Compress-Archive (Windows)
      const psCmd = `powershell -Command "Compress-Archive -Path '${buildDir}\\*' -DestinationPath '${zipPath}' -Force"`;
      execSync(psCmd, { stdio: 'inherit' });
      
      const zipStats = fs.statSync(zipPath);
      const zipSizeMB = (zipStats.size / (1024 * 1024)).toFixed(1);
      console.log(`   ✅ ZIP created: ${zipSizeMB} MB`);
      
      // Step 4: Upload ZIP to Supabase Storage
      console.log('☁️  Step 4/5: Uploading build to cloud storage...');
      const timestamp = new Date().toISOString().replace(/[-:T]/g, '').slice(0, 14);
      const storagePath = `builds/${newVersion}_${timestamp}.zip`;
      
      await uploadToStorage(SUPABASE_URL, SERVICE_KEY, storagePath, zipPath);
      console.log(`   ✅ Uploaded to storage: ${storagePath}`);
      
      // Step 5: Register in frontend_builds table
      console.log('📝 Step 5/5: Registering build in database...');
      await registerBuild(SUPABASE_URL, SERVICE_KEY, {
        version: newVersion,
        file_name: `${newVersion}_${timestamp}.zip`,
        file_size: zipStats.size,
        storage_path: storagePath,
        notes: customMessage || commitMessage
      });
      console.log('   ✅ Build registered in frontend_builds table');
      
      console.log(`\n🎉 Build ${newVersion} uploaded! Branches can now update.`);
      
    } finally {
      // Reset BUILD_ADAPTER
      delete process.env.BUILD_ADAPTER;
      console.log('🔄 Cleared BUILD_ADAPTER env var');
      
      // Clean up ZIP
      if (fs.existsSync(zipPath)) {
        fs.unlinkSync(zipPath);
        console.log('🧹 Cleaned up build ZIP');
      }
    }
  }
  
  console.log('\n📤 To push to repository, run:');
  console.log('   git push');
  
} catch (error) {
  console.error('❌ Error during git operations:', error.message);
  process.exit(1);
}

// =============================================
// Helper functions for Supabase uploads
// =============================================

function uploadToStorage(supabaseUrl, serviceKey, storagePath, localFilePath) {
  return new Promise((resolve, reject) => {
    const fileData = fs.readFileSync(localFilePath);
    const url = new URL(`/storage/v1/object/frontend-builds/${storagePath}`, supabaseUrl);
    
    const options = {
      hostname: url.hostname,
      port: url.port || 443,
      path: url.pathname,
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${serviceKey}`,
        'apikey': serviceKey,
        'Content-Type': 'application/zip',
        'Content-Length': fileData.length
      }
    };
    
    const req = https.request(options, (res) => {
      let body = '';
      res.on('data', chunk => { body += chunk; });
      res.on('end', () => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          resolve(JSON.parse(body));
        } else {
          reject(new Error(`Storage upload failed (${res.statusCode}): ${body}`));
        }
      });
    });
    
    req.on('error', reject);
    req.write(fileData);
    req.end();
  });
}

function registerBuild(supabaseUrl, serviceKey, buildData) {
  return new Promise((resolve, reject) => {
    const url = new URL('/rest/v1/frontend_builds', supabaseUrl);
    const payload = JSON.stringify(buildData);
    
    const options = {
      hostname: url.hostname,
      port: url.port || 443,
      path: url.pathname,
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${serviceKey}`,
        'apikey': serviceKey,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(payload),
        'Prefer': 'return=minimal'
      }
    };
    
    const req = https.request(options, (res) => {
      let body = '';
      res.on('data', chunk => { body += chunk; });
      res.on('end', () => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          resolve();
        } else {
          reject(new Error(`DB insert failed (${res.statusCode}): ${body}`));
        }
      });
    });
    
    req.on('error', reject);
    req.write(payload);
    req.end();
  });
}
