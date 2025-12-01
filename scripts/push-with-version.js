#!/usr/bin/env node

/**
 * Aqura Git Push with Automatic Version Update
 * 
 * This script automates the complete workflow for pushing changes to git:
 * 1. Checks git status and identifies changed files
 * 2. Determines which interface(s) were changed
 * 3. Updates version number(s) based on interfaces modified
 * 4. Updates Sidebar.svelte version popup with changes
 * 5. Commits and pushes to remote repository
 * 
 * Usage:
 * node scripts/push-with-version.js
 * 
 * The script will:
 * - Analyze changed files to detect which interfaces were modified
 * - Prompt for interface selection if changes span multiple interfaces
 * - Automatically update version numbers
 * - Update version popup content in Sidebar
 * - Create intelligent commit message
 * - Push to master branch
 */

import fs from 'fs';
import path from 'path';
import { execSync } from 'child_process';
import { fileURLToPath } from 'url';
import readline from 'readline';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Create readline interface for user input
const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

// Helper function to ask user questions
function askQuestion(query) {
  return new Promise((resolve) => {
    rl.question(query, resolve);
  });
}

// Interface detection based on file paths
const INTERFACE_PATTERNS = {
  desktop: [
    'frontend/src/lib/components/desktop-interface/',
    'frontend/src/routes/desktop-interface/',
  ],
  mobile: [
    'frontend/src/lib/components/mobile-interface/',
    'frontend/src/routes/mobile-interface/',
  ],
  cashier: [
    'frontend/src/lib/components/cashier-interface/',
    'frontend/src/routes/cashier-interface/',
  ],
  customer: [
    'frontend/src/lib/components/customer-interface/',
    'frontend/src/routes/customer-interface/',
  ],
};

/**
 * Get git status and extract changed files
 */
function getChangedFiles() {
  try {
    const output = execSync('git status --porcelain', { encoding: 'utf8' });
    const lines = output.trim().split('\n').filter(line => line);
    
    if (lines.length === 0) {
      console.log('❌ No changes detected. Nothing to commit.\n');
      process.exit(0);
    }

    const files = lines.map(line => {
      const status = line.substring(0, 2);
      const filepath = line.substring(3);
      return { status, filepath };
    });

    return files;
  } catch (error) {
    console.error('❌ Failed to get git status:', error.message);
    process.exit(1);
  }
}

/**
 * Detect which interfaces were modified based on changed files
 */
function detectModifiedInterfaces(files) {
  const interfaces = new Set();

  files.forEach(file => {
    Object.entries(INTERFACE_PATTERNS).forEach(([interfaceName, patterns]) => {
      if (patterns.some(pattern => file.filepath.includes(pattern))) {
        interfaces.add(interfaceName);
      }
    });
  });

  // Always include sidebar changes as desktop interface
  if (files.some(file => file.filepath.includes('Sidebar.svelte'))) {
    interfaces.add('desktop');
  }

  return Array.from(interfaces);
}

/**
 * Display changed files grouped by interface
 */
function displayChangedFiles(files, interfaces) {
  console.log('\n📝 Changed Files:\n');
  
  interfaces.forEach(iface => {
    const patterns = INTERFACE_PATTERNS[iface];
    const interfaceFiles = files.filter(file => 
      patterns.some(pattern => file.filepath.includes(pattern))
    );

    if (interfaceFiles.length > 0) {
      console.log(`\n🎯 ${iface.toUpperCase()} Interface:`);
      interfaceFiles.forEach(file => {
        const statusIcon = file.status === ' M' ? '✏️' : file.status === '??' ? '✨' : file.status === ' D' ? '🗑️' : '📄';
        console.log(`   ${statusIcon} ${file.filepath}`);
      });
    }
  });

  // Show other files
  const otherFiles = files.filter(file => 
    !Object.values(INTERFACE_PATTERNS).some(patterns => 
      patterns.some(pattern => file.filepath.includes(pattern))
    )
  );

  if (otherFiles.length > 0) {
    console.log(`\n📋 Other Changes:`);
    otherFiles.forEach(file => {
      const statusIcon = file.status === ' M' ? '✏️' : file.status === '??' ? '✨' : file.status === ' D' ? '🗑️' : '📄';
      console.log(`   ${statusIcon} ${file.filepath}`);
    });
  }
}

/**
 * Read current version from package.json
 */
function getCurrentVersion() {
  const packagePath = path.join(__dirname, '../package.json');
  const packageJson = JSON.parse(fs.readFileSync(packagePath, 'utf8'));
  return packageJson.version;
}

/**
 * Increment interface version
 */
function incrementInterfaceVersion(currentVersion, interface_type, increment = 1) {
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
 * Update package.json files
 */
function updatePackageJson(newVersion) {
  const rootPath = path.join(__dirname, '../package.json');
  const frontendPath = path.join(__dirname, '../frontend/package.json');
  
  try {
    const rootJson = JSON.parse(fs.readFileSync(rootPath, 'utf8'));
    const frontendJson = JSON.parse(fs.readFileSync(frontendPath, 'utf8'));
    
    rootJson.version = newVersion;
    frontendJson.version = newVersion;
    
    fs.writeFileSync(rootPath, JSON.stringify(rootJson, null, 2) + '\n');
    fs.writeFileSync(frontendPath, JSON.stringify(frontendJson, null, 2) + '\n');
    
    console.log(`\n✅ Updated package.json files to ${newVersion}`);
    return true;
  } catch (error) {
    console.error('❌ Failed to update package.json:', error.message);
    return false;
  }
}

/**
 * Update Sidebar.svelte version display
 */
function updateSidebarVersion(newVersion) {
  const sidebarPath = path.join(__dirname, '../frontend/src/lib/components/desktop-interface/common/Sidebar.svelte');
  
  try {
    let content = fs.readFileSync(sidebarPath, 'utf8');
    
    // Replace version in button
    content = content.replace(
      /AQ[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(?=\s*<\/button>)/g,
      newVersion
    );
    
    // Replace version in popup header
    content = content.replace(
      /What's New in AQ[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/g,
      `What's New in ${newVersion}`
    );
    
    fs.writeFileSync(sidebarPath, content);
    console.log(`✅ Updated Sidebar.svelte to ${newVersion}`);
    return true;
  } catch (error) {
    console.error('❌ Failed to update Sidebar.svelte:', error.message);
    return false;
  }
}

/**
 * Get git diff summary for commit message
 */
function getCommitMessageSummary(interfaces) {
  if (interfaces.length === 0) return 'chore: update files';
  if (interfaces.length === 1) return `chore(${interfaces[0]}): bump version`;
  if (interfaces.length === 4) return 'chore(all): bump version';
  return `chore(${interfaces.join(',')}): bump version`;
}

/**
 * Main execution
 */
async function main() {
  console.log('\n🚀 Aqura Git Push with Auto Version Update\n');
  console.log('='.repeat(50));

  // Step 1: Get changed files
  console.log('\n📊 Step 1: Analyzing changed files...');
  const changedFiles = getChangedFiles();
  console.log(`✅ Found ${changedFiles.length} changed file(s)`);

  // Step 2: Detect interfaces
  console.log('\n🎯 Step 2: Detecting modified interfaces...');
  const modifiedInterfaces = detectModifiedInterfaces(changedFiles);
  
  if (modifiedInterfaces.length === 0) {
    console.log('⚠️  No interface-specific changes detected (only config/docs)');
  } else {
    console.log(`✅ Modified interfaces: ${modifiedInterfaces.join(', ').toUpperCase()}`);
  }

  // Step 3: Display changes
  displayChangedFiles(changedFiles, modifiedInterfaces);

  // Step 4: Ask user for version update confirmation
  console.log('\n' + '='.repeat(50));
  const currentVersion = getCurrentVersion();
  console.log(`\n📦 Current version: ${currentVersion}`);

  let versionsToUpdate = [];
  
  if (modifiedInterfaces.length > 0) {
    const updateVersions = await askQuestion(
      `\nUpdate version for ${modifiedInterfaces.map(i => i.toUpperCase()).join(', ')}? (yes/no): `
    );
    
    if (updateVersions.toLowerCase() === 'yes' || updateVersions.toLowerCase() === 'y') {
      versionsToUpdate = modifiedInterfaces;
    }
  } else {
    const customUpdate = await askQuestion('\nUpdate version manually? (yes/no): ');
    if (customUpdate.toLowerCase() === 'yes' || customUpdate.toLowerCase() === 'y') {
      versionsToUpdate = ['desktop']; // Default to desktop
    }
  }

  let newVersion = currentVersion;
  if (versionsToUpdate.length > 0) {
    console.log('\n🔄 Step 3: Updating version numbers...');
    
    // If multiple interfaces, ask if user wants to update all together
    if (versionsToUpdate.length > 1) {
      const updateAll = await askQuestion(
        `Update all ${versionsToUpdate.length} interfaces together? (yes/no): `
      );
      
      if (updateAll.toLowerCase() === 'yes' || updateAll.toLowerCase() === 'y') {
        newVersion = incrementInterfaceVersion(currentVersion, 'all', 1);
      } else {
        // Update each individually
        let tempVersion = currentVersion;
        for (const iface of versionsToUpdate) {
          tempVersion = incrementInterfaceVersion(tempVersion, iface, 1);
        }
        newVersion = tempVersion;
      }
    } else {
      newVersion = incrementInterfaceVersion(currentVersion, versionsToUpdate[0], 1);
    }

    console.log(`✅ New version: ${newVersion}`);

    // Update files
    updatePackageJson(newVersion);
    updateSidebarVersion(newVersion);
  }

  // Step 4: Create commit message
  console.log('\n📝 Step 4: Creating commit message...');
  const defaultMessage = getCommitMessageSummary(versionsToUpdate);
  const customMessage = await askQuestion(`\nCommit message (default: "${defaultMessage}"): `);
  const commitMessage = customMessage.trim() || defaultMessage;
  console.log(`✅ Commit message: "${commitMessage}"`);

  // Step 5: Stage, commit, and push
  console.log('\n📤 Step 5: Staging changes...');
  try {
    execSync('git add -A', { stdio: 'inherit' });
    console.log('✅ All changes staged');

    console.log('\n💾 Step 6: Committing changes...');
    execSync(`git commit -m "${commitMessage}"`, { stdio: 'inherit' });
    console.log('✅ Changes committed');

    console.log('\n🚀 Step 7: Pushing to remote...');
    execSync('git push origin master', { stdio: 'inherit' });
    console.log('✅ Changes pushed to master');

    console.log('\n' + '='.repeat(50));
    console.log('\n🎉 Successfully pushed to git!\n');
    console.log('Summary:');
    console.log(`  Version: ${newVersion}`);
    console.log(`  Interfaces: ${versionsToUpdate.length > 0 ? versionsToUpdate.join(', ') : 'none'}`);
    console.log(`  Files changed: ${changedFiles.length}`);
    console.log(`  Commit: "${commitMessage}"\n`);

  } catch (error) {
    console.error('\n❌ Failed to push changes:', error.message);
    process.exit(1);
  }

  rl.close();
}

// Run the main function
main().catch(console.error);
