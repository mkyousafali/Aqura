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
  
  // Push to git
  execSync('git push', { stdio: 'inherit' });
  console.log('✅ Pushed to remote');
  
  console.log('\n🎉 Version updated successfully!');
  console.log(`📌 New version: ${newVersion}`);
  
} catch (error) {
  console.error('❌ Error during git operations:', error.message);
  process.exit(1);
}
