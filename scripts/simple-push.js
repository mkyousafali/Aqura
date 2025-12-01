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
 * Generate fresh changelog content
 */
function generateChangelogContent(newVersion, commitMessage) {
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

  return `				<!-- Version Format Header -->
				<div class="update-section" style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 16px; border-radius: 8px; margin-bottom: 16px;">
					<h4>🎯 Version Format: AQ[Desktop].[Mobile].[Cashier].[Customer]</h4>
					<p style="margin: 8px 0 0 0; font-size: 14px;">AQ1.1.1.1 = Desktop v1, Mobile v1, Cashier v1, Customer v1</p>
				</div>

				<!-- Latest Update - ${newVersion} -->
				<div class="update-section" style="border-left: 4px solid #10b981; padding-left: 16px; background: linear-gradient(135deg, #d4fc79 0%, #96e6a1 100%); padding: 12px; margin-bottom: 16px;">
					<h4 style="color: #065f46; margin: 0 0 8px 0;">${updateType} - ${newVersion}</h4>
					<ul style="margin: 0; padding-left: 20px; font-size: 13px;">
						<li><strong>${updateDescription}</strong></li>
						<li><small style="opacity: 0.7;">Updated: ${new Date().toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' })}</small></li>
					</ul>
				</div>

				<!-- Desktop Interface Section -->
				<div class="update-section" style="border-left: 4px solid #3b82f6; padding-left: 16px; background: #eff6ff; padding: 12px;">
					<h4 style="color: #1e40af; margin: 0 0 8px 0;">🖥️ Desktop Interface - Version ${newVersion.split('.')[0].replace('AQ', '')}</h4>
					<ul style="margin: 0; padding-left: 20px; font-size: 13px;">
						<li><strong>Admin/Manager features:</strong> User management, task assignments</li>
						<li><strong>Window Management:</strong> Drag/resize/minimize windows, taskbar</li>
						<li><strong>Master Data:</strong> HR, Branch, Vendor, Product management</li>
						<li><strong>Work Operations:</strong> Receiving, Tasks, Finance, Notifications</li>
						<li><strong>Update Command:</strong> <code style="background: #fff; padding: 2px 4px;">node scripts/simple-push.js desktop</code></li>
					</ul>
				</div>

				<!-- Mobile Interface Section -->
				<div class="update-section" style="border-left: 4px solid #8b5cf6; padding-left: 16px; background: #faf5ff; padding: 12px; margin-top: 12px;">
					<h4 style="color: #6d28d9; margin: 0 0 8px 0;">📱 Mobile Interface - Version ${newVersion.split('.')[1]}</h4>
					<ul style="margin: 0; padding-left: 20px; font-size: 13px;">
						<li><strong>Employee App:</strong> Mobile task management, notifications</li>
						<li><strong>Punch Card:</strong> Last check-in/check-out time display</li>
						<li><strong>Task System:</strong> View, complete, and manage assigned tasks</li>
						<li><strong>Notifications:</strong> Real-time alerts and updates</li>
						<li><strong>Update Command:</strong> <code style="background: #fff; padding: 2px 4px;">node scripts/simple-push.js mobile</code></li>
					</ul>
				</div>

				<!-- Cashier Interface Section -->
				<div class="update-section" style="border-left: 4px solid #f59e0b; padding-left: 16px; background: #fffbeb; padding: 12px; margin-top: 12px;">
					<h4 style="color: #b45309; margin: 0 0 8px 0;">🏪 Cashier Interface - Version ${newVersion.split('.')[2]}</h4>
					<ul style="margin: 0; padding-left: 20px; font-size: 13px;">
						<li><strong>POS System:</strong> Standalone point-of-sale interface</li>
						<li><strong>Coupon Redemption:</strong> Customer coupon validation and processing</li>
						<li><strong>Cashier Features:</strong> Dedicated taskbar and window management</li>
						<li><strong>Access Control:</strong> Access code based authentication</li>
						<li><strong>Update Command:</strong> <code style="background: #fff; padding: 2px 4px;">node scripts/simple-push.js cashier</code></li>
					</ul>
				</div>

				<!-- Customer Interface Section -->
				<div class="update-section" style="border-left: 4px solid #10b981; padding-left: 16px; background: #f0fdf4; padding: 12px; margin-top: 12px;">
					<h4 style="color: #065f46; margin: 0 0 8px 0;">🛒 Customer Interface - Version ${newVersion.split('.')[3]}</h4>
					<ul style="margin: 0; padding-left: 20px; font-size: 13px;">
						<li><strong>Shopping App:</strong> Mobile customer-facing application</li>
						<li><strong>Product Browsing:</strong> View products by category</li>
						<li><strong>Offers System:</strong> Featured offers and discounts</li>
						<li><strong>Cart & Orders:</strong> Add to cart, checkout, order tracking</li>
						<li><strong>Update Command:</strong> <code style="background: #fff; padding: 2px 4px;">node scripts/simple-push.js customer</code></li>
					</ul>
				</div>

				<div class="version-info-footer">
					<p><strong>Release Date:</strong> ${new Date().toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' })}</p>
					<p><strong>Build:</strong> Production Ready</p>
					<p><strong>Version:</strong> ${newVersion}</p>
					<p><strong>Latest Change:</strong> ${updateDescription}</p>
				</div>`;
}

/**
 * Update Sidebar.svelte version and changelog
 */
function updateSidebarVersion(newVersion, commitMessage) {
  const sidebarPath = path.join(__dirname, '../frontend/src/lib/components/desktop-interface/common/Sidebar.svelte');
  
  try {
    let content = fs.readFileSync(sidebarPath, 'utf8');
    
    // Update version numbers in button
    content = content.replace(
      /AQ[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(?=\s*<\/button>)/g,
      newVersion
    );
    
    // Update version in popup header
    content = content.replace(
      /What's New in AQ[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/g,
      `What's New in ${newVersion}`
    );
    
    // Generate fresh changelog content
    const newChangelogContent = generateChangelogContent(newVersion, commitMessage);
    
    // Replace everything between <div class="version-popup-content"> and </div> (before closing popup content div)
    const contentStart = content.indexOf('<div class="version-popup-content">');
    const contentEnd = content.indexOf('</div>\n\t\t</div>\n\t{/if}\n</div>\n\n<!-- Notification Popup -->');
    
    if (contentStart !== -1 && contentEnd !== -1) {
      const beforeContent = content.substring(0, contentStart + '<div class="version-popup-content">'.length);
      const afterContent = content.substring(contentEnd);
      
      content = beforeContent + '\n' + newChangelogContent + '\n\t\t\t' + afterContent;
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
