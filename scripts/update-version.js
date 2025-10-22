#!/usr/bin/env node

/**
 * Version Update Script for Aqura Management System
 * 
 * This script automatically updates version numbers across the project:
 * - Updates package.json files (root and frontend)
 * - Updates version display in Sidebar.svelte
 * - Increments patch version by default, or accepts version type as argument
 * 
 * Usage:
 * node scripts/update-version.js [patch|minor|major]
 * 
 * Examples:
 * node scripts/update-version.js        # Increments patch version (1.0.0 -> 1.0.1)
 * node scripts/update-version.js minor  # Increments minor version (1.0.0 -> 1.1.0)
 * node scripts/update-version.js major  # Increments major version (1.0.0 -> 2.0.0)
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Get version type from command line argument (default: patch)
const versionType = process.argv[2] || 'patch';

if (!['patch', 'minor', 'major'].includes(versionType)) {
  console.error('❌ Invalid version type. Use: patch, minor, or major');
  process.exit(1);
}

/**
 * Parse version string and increment based on type
 */
function incrementVersion(currentVersion, type) {
  const parts = currentVersion.split('.').map(Number);
  const [major, minor, patch] = parts;
  
  switch (type) {
    case 'major':
      return `${major + 1}.0.0`;
    case 'minor':
      return `${major}.${minor + 1}.0`;
    case 'patch':
    default:
      return `${major}.${minor}.${patch + 1}`;
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
function updateSidebarVersion(newVersion) {
  const sidebarPath = path.join(__dirname, '../frontend/src/lib/components/Sidebar.svelte');
  
  try {
    let content = fs.readFileSync(sidebarPath, 'utf8');
    
    // Find and replace version in the version-text span
    const versionRegex = /<span class="version-text">v[\d.]+<\/span>/g;
    const newVersionTag = `<span class="version-text">v${newVersion}</span>`;
    
    if (content.match(versionRegex)) {
      content = content.replace(versionRegex, newVersionTag);
      fs.writeFileSync(sidebarPath, content);
      console.log(`✅ Updated Sidebar.svelte version display to v${newVersion}`);
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
  console.log(`🚀 Updating version (${versionType})...\n`);
  
  // Read current version from root package.json
  const rootPackagePath = path.join(__dirname, '../package.json');
  const rootPackage = JSON.parse(fs.readFileSync(rootPackagePath, 'utf8'));
  const currentVersion = rootPackage.version;
  const newVersion = incrementVersion(currentVersion, versionType);
  
  console.log(`📦 Current version: ${currentVersion}`);
  console.log(`📦 New version: ${newVersion}\n`);
  
  let success = true;
  
  // Update root package.json
  success = updatePackageJson(rootPackagePath, newVersion) && success;
  
  // Update frontend package.json
  const frontendPackagePath = path.join(__dirname, '../frontend/package.json');
  success = updatePackageJson(frontendPackagePath, newVersion) && success;
  
  // Update Sidebar.svelte version display
  success = updateSidebarVersion(newVersion) && success;
  
  if (success) {
    console.log(`\n🎉 Successfully updated all files to version ${newVersion}`);
    console.log('\n📝 Next steps:');
    console.log('   git add -A');
    console.log(`   git commit -m "chore: bump version to ${newVersion}"`);
    console.log('   git push origin master');
  } else {
    console.log('\n❌ Some updates failed. Please check the errors above.');
    process.exit(1);
  }
}

main().catch(console.error);