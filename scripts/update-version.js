#!/usr/bin/env node

/**
 * Version Update Script for Aqura Management System (AQ1.1.1.1 Format)
 * 
 * This script automatically updates version numbers across the project using:
 * Format: AQ[Desktop].[Mobile].[Cashier].[Customer]
 * 
 * Example: AQ1.2.1.3
 * - Desktop Interface: 1
 * - Mobile Interface: 2
 * - Cashier Interface: 1
 * - Customer Interface: 3
 * 
 * Usage:
 * node scripts/update-version.js desktop [increment]  # Update desktop version (default: +1)
 * node scripts/update-version.js mobile [increment]   # Update mobile version
 * node scripts/update-version.js cashier [increment]  # Update cashier version
 * node scripts/update-version.js customer [increment] # Update customer version
 * node scripts/update-version.js all [increment]      # Update all interfaces
 * 
 * Examples:
 * node scripts/update-version.js desktop      # AQ1.2.1.3 -> AQ2.2.1.3
 * node scripts/update-version.js desktop 5    # AQ1.2.1.3 -> AQ6.2.1.3
 * node scripts/update-version.js mobile       # AQ1.2.1.3 -> AQ1.3.1.3
 * node scripts/update-version.js all          # AQ1.2.1.3 -> AQ2.3.2.4 (increment each by 1)
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Get interface and increment from command line arguments
const interface_type = process.argv[2] || 'desktop';
const increment_amount = parseInt(process.argv[3] || '1');

if (!['desktop', 'mobile', 'cashier', 'customer', 'all'].includes(interface_type)) {
  console.error('❌ Invalid interface. Use: desktop, mobile, cashier, customer, or all');
  process.exit(1);
}

if (isNaN(increment_amount) || increment_amount < 1) {
  console.error('❌ Invalid increment amount. Must be a positive number');
  process.exit(1);
}

/**
 * Parse AQ version string (e.g., AQ1.2.1.3) and increment interface version
 */
function incrementInterfaceVersion(currentVersion, interface_type, increment) {
  // Remove 'AQ' prefix and split
  const version_str = currentVersion.startsWith('AQ') ? currentVersion.substring(2) : currentVersion;
  const parts = version_str.split('.').map(Number);
  const [desktop, mobile, cashier, customer] = parts;
  
  switch (interface_type) {
    case 'desktop':
      return `AQ${desktop + increment}.${mobile}.${cashier}.${customer}`;
    case 'mobile':
      return `AQ${desktop}.${mobile + increment}.${cashier}.${customer}`;
    case 'cashier':
      return `AQ${desktop}.${mobile}.${cashier + increment}.${customer}`;
    case 'customer':
      return `AQ${desktop}.${mobile}.${cashier}.${customer + increment}`;
    case 'all':
      return `AQ${desktop + increment}.${mobile + increment}.${cashier + increment}.${customer + increment}`;
    default:
      return currentVersion;
  }
}

/**
 * Update package.json version
 */
function updatePackageJson(filePath, newVersion) {
  try {
    const packageJson = JSON.parse(fs.readFileSync(filePath, 'utf8'));
    const oldVersion = packageJson.version;
    packageJson.version = newVersion;
    
    fs.writeFileSync(filePath, JSON.stringify(packageJson, null, 2) + '\n');
    console.log(`✅ Updated ${filePath}: ${oldVersion} → ${newVersion}`);
    return true;
  } catch (error) {
    console.error(`❌ Failed to update ${filePath}:`, error.message);
    return false;
  }
}

/**
 * Update version in Sidebar.svelte
 */
function updateSidebarVersion(newVersion, interface_type) {
  const sidebarPath = path.join(__dirname, '../frontend/src/lib/components/desktop-interface/common/Sidebar.svelte');
  
  try {
    let content = fs.readFileSync(sidebarPath, 'utf8');
    let updated = false;
    
    // Find and replace version in the clickable button - match AQ followed by digits and dots
    const buttonVersionRegex = /AQ\d+\.\d+\.\d+\.\d+/g;
    const matchCount = (content.match(buttonVersionRegex) || []).length;
    
    if (matchCount > 0) {
      content = content.replace(buttonVersionRegex, newVersion);
      updated = true;
    }
    
    if (updated) {
      fs.writeFileSync(sidebarPath, content);
      console.log(`✅ Updated Sidebar.svelte to ${newVersion} (${interface_type} interface)`);
      return true;
    } else {
      console.error('❌ Could not find version display in Sidebar.svelte');
      return false;
    }
  } catch (error) {
    console.error('❌ Failed to update Sidebar.svelte:', error.message);
    return false;
  }
}

/**
 * Main execution
 */
async function main() {
  console.log(`🚀 Updating ${interface_type} interface version (+${increment_amount})...\n`);
  
  // Read current version from root package.json
  const rootPackagePath = path.join(__dirname, '../package.json');
  const rootPackage = JSON.parse(fs.readFileSync(rootPackagePath, 'utf8'));
  const currentVersion = rootPackage.version;
  const newVersion = incrementInterfaceVersion(currentVersion, interface_type, increment_amount);
  
  console.log(`📦 Current version: ${currentVersion}`);
  console.log(`📦 New version: ${newVersion}\n`);
  
  let success = true;
  
  // Update root package.json
  success = updatePackageJson(rootPackagePath, newVersion) && success;
  
  // Update frontend package.json
  const frontendPackagePath = path.join(__dirname, '../frontend/package.json');
  success = updatePackageJson(frontendPackagePath, newVersion) && success;
  
  // Update Sidebar.svelte version display
  success = updateSidebarVersion(newVersion, interface_type) && success;
  
  if (success) {
    console.log(`\n🎉 Successfully updated all files to version ${newVersion}`);
    console.log(`📌 Interface updated: ${interface_type}`);
    console.log('\n📝 Next steps:');
    console.log('   git add -A');
    console.log(`   git commit -m "chore(${interface_type}): bump version to ${newVersion}"`);
    console.log('   git push origin master');
  } else {
    console.log('\n❌ Some updates failed. Please check the errors above.');
    process.exit(1);
  }
}

main().catch(console.error);