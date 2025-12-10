import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { execSync } from 'child_process';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// Get command line arguments
const args = process.argv.slice(2);
const interfaceType = args[0]?.toLowerCase();
const customMessage = args[1];

const validInterfaces = ['desktop', 'mobile', 'cashier', 'customer', 'all'];

if (!interfaceType || !validInterfaces.includes(interfaceType)) {
  console.error('❌ Error: Please specify a valid interface type');
  console.error('Usage: node "Do not delete/simple-push.js" <interface> [commit-message]');
  console.error('Valid interfaces: desktop, mobile, cashier, customer, all');
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
const sidebarPath = path.join(__dirname, '..', 'frontend', 'src', 'lib', 'components', 'desktop-interface', 'Sidebar.svelte');

if (fs.existsSync(sidebarPath)) {
  let sidebarContent = fs.readFileSync(sidebarPath, 'utf-8');
  
  // Replace version in the version display section
  sidebarContent = sidebarContent.replace(
    /const version = ['"]AQ[\d.]+['"];/,
    `const version = '${newVersion}';`
  );
  
  fs.writeFileSync(sidebarPath, sidebarContent, 'utf-8');
  console.log('✅ Updated Sidebar.svelte version display');
}

// Generate commit message
const interfaceNames = {
  desktop: 'Desktop',
  mobile: 'Mobile',
  cashier: 'Cashier',
  customer: 'Customer',
  all: 'All Interfaces'
};

const defaultMessage = `chore(version): bump ${interfaceNames[interfaceType]} to ${newVersion}`;
const commitMessage = customMessage || defaultMessage;

// Stage all changes
try {
  execSync('git add -A', { stdio: 'inherit' });
  console.log('✅ Staged all changes');
  
  // Create commit
  execSync(`git commit -m "${commitMessage}"`, { stdio: 'inherit' });
  console.log('✅ Created commit');
  
  console.log('\n🎉 Version updated successfully!');
  console.log(`📌 New version: ${newVersion}`);
  console.log('\n📤 To push to repository, run:');
  console.log('   git push');
  
} catch (error) {
  console.error('❌ Error during git operations:', error.message);
  process.exit(1);
}
