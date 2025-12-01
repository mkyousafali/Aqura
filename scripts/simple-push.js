#!/usr/bin/env node

/**
 * Simple Git Push with Auto Version Update (Non-Interactive)
 * 
 * Usage:
 * node scripts/simple-push.js [interface] [commit-message]
 * 
 * Examples:
 * node scripts/simple-push.js desktop          # Update desktop version and push
 * node scripts/simple-push.js mobile           # Update mobile version and push
 * node scripts/simple-push.js all              # Update all interfaces and push
 * node scripts/simple-push.js desktop "my message"  # Custom commit message
 */

import fs from 'fs';
import path from 'path';
import { execSync } from 'child_process';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Get interface from command line (default: desktop)
const interface_type = process.argv[2] || 'desktop';
const custom_message = process.argv[3];

const VALID_INTERFACES = ['desktop', 'mobile', 'cashier', 'customer', 'all'];

if (!VALID_INTERFACES.includes(interface_type)) {
  console.error(`❌ Invalid interface. Use: ${VALID_INTERFACES.join(', ')}`);
  process.exit(1);
}

/**
 * Get git status
 */
function getGitStatus() {
  try {
    const output = execSync('git status --porcelain', { encoding: 'utf8' });
    return output.trim().split('\n').filter(line => line);
  } catch (error) {
    console.error('❌ Failed to get git status');
    process.exit(1);
  }
}

/**
 * Read current version
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
    
    return true;
  } catch (error) {
    console.error('❌ Failed to update package.json:', error.message);
    return false;
  }
}

/**
 * Update Sidebar.svelte version and changelog
 */
function updateSidebarVersion(newVersion, commitMessage) {
  const sidebarPath = path.join(__dirname, '../frontend/src/lib/components/desktop-interface/common/Sidebar.svelte');
  
  try {
    let content = fs.readFileSync(sidebarPath, 'utf8');
    
    // Update version numbers
    content = content.replace(
      /AQ[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(?=\s*<\/button>)/g,
      newVersion
    );
    
    content = content.replace(
      /What's New in AQ[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/g,
      `What's New in ${newVersion}`
    );
    
    // Parse commit message to extract feature description
    const featureMatch = commitMessage.match(/^(feat|fix|chore|docs|style|refactor|perf|test)\(([^)]+)\):\s*(.+)$/i);
    let updateType = '✨ Update';
    let updateDescription = commitMessage;
    
    if (featureMatch) {
      const [, type, scope, description] = featureMatch;
      switch (type.toLowerCase()) {
        case 'feat':
          updateType = '✨ New Feature';
          break;
        case 'fix':
          updateType = '🐛 Bug Fix';
          break;
        case 'perf':
          updateType = '⚡ Performance';
          break;
        case 'refactor':
          updateType = '♻️ Refactor';
          break;
        case 'docs':
          updateType = '📝 Documentation';
          break;
        case 'style':
          updateType = '💄 Style';
          break;
        case 'test':
          updateType = '🧪 Test';
          break;
        default:
          updateType = '🔧 Maintenance';
      }
      updateDescription = description.charAt(0).toUpperCase() + description.slice(1);
    }
    
    // Add new update section at the top of the changelog (after Version Format Header)
    const updateSection = `
				<!-- Latest Update - ${newVersion} -->
				<div class="update-section" style="border-left: 4px solid #10b981; padding-left: 16px; background: linear-gradient(135deg, #d4fc79 0%, #96e6a1 100%); padding: 12px; margin-bottom: 16px;">
					<h4 style="color: #065f46; margin: 0 0 8px 0;">${updateType} - ${newVersion}</h4>
					<ul style="margin: 0; padding-left: 20px; font-size: 13px;">
						<li><strong>${updateDescription}</strong></li>
						<li><small style="opacity: 0.7;">Updated: ${new Date().toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' })}</small></li>
					</ul>
				</div>
`;
    
    // Find the position after the Version Format Header and insert the new update
    const versionFormatEnd = content.indexOf('</div>\n\n				<!-- Desktop Interface Section -->');
    if (versionFormatEnd !== -1) {
      content = content.slice(0, versionFormatEnd + 7) + updateSection + content.slice(versionFormatEnd + 7);
    }
    
    fs.writeFileSync(sidebarPath, content);
    return true;
  } catch (error) {
    console.error('❌ Failed to update Sidebar.svelte:', error.message);
    return false;
  }
}

/**
 * Main execution
 */
function main() {
  console.log('\n🚀 Simple Git Push with Version Update\n');
  
  // Step 1: Check git status
  console.log('📊 Checking git status...');
  const changes = getGitStatus();
  
  if (changes.length === 0) {
    console.log('❌ No changes to commit\n');
    process.exit(0);
  }
  
  console.log(`✅ Found ${changes.length} changed file(s)\n`);
  
  // Step 2: Get and increment version
  const currentVersion = getCurrentVersion();
  const newVersion = incrementInterfaceVersion(currentVersion, interface_type, 1);
  
  console.log(`📦 Version: ${currentVersion} → ${newVersion}`);
  console.log(`📌 Interface: ${interface_type.toUpperCase()}\n`);
  
  // Step 3: Update files
  console.log('🔄 Updating files...');
  const commitMsg = custom_message || `chore(${interface_type}): bump version to ${newVersion}`;
  updatePackageJson(newVersion);
  updateSidebarVersion(newVersion, commitMsg);
  console.log('✅ Files updated\n');
  
  // Step 4: Git operations
  console.log('📤 Staging changes...');
  try {
    execSync('git add -A', { stdio: 'pipe' });
    console.log('✅ Changes staged\n');
    
    const commitMsg = custom_message || `chore(${interface_type}): bump version to ${newVersion}`;
    console.log(`💾 Committing: "${commitMsg}"`);
    execSync(`git commit -m "${commitMsg}"`, { stdio: 'pipe' });
    console.log('✅ Committed\n');
    
    console.log('🚀 Pushing to master...');
    execSync('git push origin master', { stdio: 'pipe' });
    console.log('✅ Pushed\n');
    
    console.log('='.repeat(50));
    console.log('\n✨ Success! All changes pushed to git\n');
    console.log(`Version: ${newVersion}`);
    console.log(`Interface: ${interface_type.toUpperCase()}`);
    console.log(`Files: ${changes.length}\n`);
    
  } catch (error) {
    console.error('\n❌ Error:', error.message);
    process.exit(1);
  }
}

main();
