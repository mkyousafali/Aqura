#!/usr/bin/env node

/**
 * Simple Git Push with Auto Version Update (Non-Interactive)
 * 
 * Usage:
 * node scripts/simple-push.js [interface] [commit-message] [change-details]
 * 
 * Examples:
 * node scripts/simple-push.js desktop          # Update desktop version and push
 * node scripts/simple-push.js mobile           # Update mobile version and push
 * node scripts/simple-push.js all              # Update all interfaces and push
 * node scripts/simple-push.js desktop "my message"  # Custom commit message
 * node scripts/simple-push.js mobile "feat(mobile): new feature" "Added task filtering|Improved UI layout|Fixed bugs"
 * 
 * Change details should be separated by | (pipe character)
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
const change_details = process.argv[4]; // Optional: comma-separated list of changes

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
 * Generate change details from modified files
 */
function generateChangeDetails(changes, interface_type, commitMessage) {
  const details = [];
  const fileTypes = new Set();
  const areas = new Set();
  
  // Analyze changed files
  changes.forEach(change => {
    const file = change.substring(3);
    
    // Detect file types
    if (file.endsWith('.svelte')) fileTypes.add('UI components');
    if (file.endsWith('.ts') || file.endsWith('.js')) fileTypes.add('functionality');
    if (file.endsWith('.css')) fileTypes.add('styling');
    if (file.includes('lib/stores')) fileTypes.add('state management');
    if (file.includes('lib/api')) fileTypes.add('API integration');
    if (file.includes('lib/utils')) fileTypes.add('utility functions');
    
    // Detect areas based on path
    if (file.includes('desktop-interface')) areas.add('desktop');
    if (file.includes('mobile-interface')) areas.add('mobile');
    if (file.includes('cashier-interface')) areas.add('cashier');
    if (file.includes('customer-interface')) areas.add('customer');
    
    // Detect specific features
    if (file.includes('tasks') || file.includes('Tasks')) areas.add('task management');
    if (file.includes('orders') || file.includes('Orders')) areas.add('order system');
    if (file.includes('products') || file.includes('Products')) areas.add('product catalog');
    if (file.includes('customers') || file.includes('Customers')) areas.add('customer management');
    if (file.includes('employees') || file.includes('Employees')) areas.add('employee management');
    if (file.includes('reports') || file.includes('Reports')) areas.add('reporting');
    if (file.includes('settings') || file.includes('Settings')) areas.add('settings');
    if (file.includes('auth') || file.includes('Auth')) areas.add('authentication');
  });
  
  // Parse commit message type
  const featureMatch = commitMessage.match(/^(feat|fix|chore|docs|style|refactor|perf|test)\(([^)]+)\):\s*(.+)$/i);
  let commitType = 'update';
  let description = commitMessage;
  
  if (featureMatch) {
    commitType = featureMatch[1].toLowerCase();
    description = featureMatch[3];
  }
  
  // Generate details based on commit type and changes
  switch (commitType) {
    case 'feat':
      details.push(`Implemented ${description}`);
      if (fileTypes.has('UI components')) details.push('Enhanced user interface components');
      if (fileTypes.has('functionality')) details.push('Added new functionality and features');
      if (fileTypes.has('state management')) details.push('Improved state management');
      break;
      
    case 'fix':
      details.push(`Fixed: ${description}`);
      details.push('Resolved reported issues');
      if (fileTypes.has('UI components')) details.push('Corrected UI component behavior');
      break;
      
    case 'refactor':
      details.push('Refactored codebase for better maintainability');
      details.push('Improved code structure and organization');
      if (fileTypes.has('functionality')) details.push('Optimized existing functionality');
      break;
      
    case 'perf':
      details.push('Improved application performance');
      details.push('Optimized rendering and data processing');
      break;
      
    case 'style':
      details.push('Updated visual design and styling');
      details.push('Enhanced user interface appearance');
      break;
      
    default:
      details.push(`Updated ${description}`);
      if (fileTypes.size > 0) details.push(`Modified ${Array.from(fileTypes).join(', ')}`);
  }
  
  // Add area-specific details
  if (areas.size > 0) {
    const areaList = Array.from(areas).filter(a => !['desktop', 'mobile', 'cashier', 'customer'].includes(a));
    if (areaList.length > 0) {
      details.push(`Updated ${areaList.join(' and ')} features`);
    }
  }
  
  // Add file count info
  details.push(`Modified ${changes.length} file${changes.length > 1 ? 's' : ''}`);
  
  return details.slice(0, 5); // Limit to 5 details max
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
 * Generate fresh changelog content for VersionChangelog.svelte
 */
function generateVersionChangelogFile(newVersion, commitMessage, changeDetails) {
  // Parse commit message to extract feature description
  const featureMatch = commitMessage.match(/^(feat|fix|chore|docs|style|refactor|perf|test)\(([^)]+)\):\s*(.+)$/i);
  let updateType = 'Update';
  let updateDescription = commitMessage;
  let typeEmoji = '✨';
  
  if (featureMatch) {
    const [, type, scope, description] = featureMatch;
    switch (type.toLowerCase()) {
      case 'feat':
        updateType = 'New Feature';
        typeEmoji = '✨';
        break;
      case 'fix':
        updateType = 'Bug Fix';
        typeEmoji = '🐛';
        break;
      case 'perf':
        updateType = 'Performance';
        typeEmoji = '⚡';
        break;
      case 'refactor':
        updateType = 'Refactor';
        typeEmoji = '♻️';
        break;
      case 'docs':
        updateType = 'Documentation';
        typeEmoji = '📝';
        break;
      case 'style':
        updateType = 'Style';
        typeEmoji = '💄';
        break;
      case 'test':
        updateType = 'Test';
        typeEmoji = '🧪';
        break;
      default:
        updateType = 'Maintenance';
        typeEmoji = '🔧';
    }
    updateDescription = description.charAt(0).toUpperCase() + description.slice(1);
  }

  const versionParts = newVersion.replace('AQ', '').split('.');
  const [desktop, mobile, cashier, customer] = versionParts;

  // Parse change details - can be array or pipe-separated string
  let changeDetailsHtml = '';
  let changes = [];
  
  if (Array.isArray(changeDetails)) {
    changes = changeDetails;
  } else if (typeof changeDetails === 'string') {
    changes = changeDetails.split('|').map(change => change.trim()).filter(c => c);
  }
  
  if (changes.length > 0) {
    changeDetailsHtml = `
			<div class="change-details">
				<h4>What Changed:</h4>
				<ul>
					${changes.map(change => `<li>${change}</li>`).join('\n					')}
				</ul>
			</div>`;
  }

  return `<script lang="ts">
	export let onClose: () => void;
</script>

<div class="version-changelog-window">
	<div class="window-content">
		<div class="version-format">
			<p class="version-title">Version ${newVersion}</p>
			<p class="version-details">Desktop: ${desktop} | Mobile: ${mobile} | Cashier: ${cashier} | Customer: ${customer}</p>
			<p class="version-note">Format: AQ[Desktop].[Mobile].[Cashier].[Customer]</p>
		</div>

		<div class="latest-change">
			<h3>${typeEmoji} ${updateType}</h3>
			<p class="change-description">${updateDescription}</p>${changeDetailsHtml}
			<p class="date">${new Date().toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' })}</p>
		</div>

		<div class="interface-info">
			<div class="interface-card">
				<h4>🖥️ Desktop Interface</h4>
				<p>Admin and manager features for full business management</p>
			</div>

			<div class="interface-card">
				<h4>📱 Mobile Interface</h4>
				<p>Employee app for tasks and time tracking</p>
			</div>

			<div class="interface-card">
				<h4>🏪 Cashier Interface</h4>
				<p>Internal checkout operations manager</p>
			</div>

			<div class="interface-card">
				<h4>🛒 Customer Interface</h4>
				<p>Shopping app for customers</p>
			</div>
		</div>
	</div>
</div>

<style>
	.version-changelog-window {
		width: 100%;
		height: 100%;
		display: flex;
		flex-direction: column;
		background: #ffffff;
		font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Arial, sans-serif;
	}

	.window-content {
		flex: 1;
		overflow-y: auto;
		padding: 24px;
		background: #f8fafc;
	}

	.version-format {
		background: white;
		padding: 20px;
		border-radius: 6px;
		border: 3px solid #f97316;
		margin-bottom: 20px;
	}

	.version-title {
		margin: 0 0 12px 0;
		color: #22c55e;
		font-size: 24px;
		font-weight: 700;
	}

	.version-details {
		margin: 0 0 8px 0;
		color: #22c55e;
		font-size: 16px;
		font-weight: 600;
	}

	.version-note {
		margin: 0;
		color: #22c55e;
		font-size: 13px;
		font-weight: 500;
	}

	.latest-change {
		background: white;
		padding: 20px;
		border-radius: 6px;
		border: 1px solid #e2e8f0;
		margin-bottom: 20px;
	}

	.latest-change h3 {
		margin: 0 0 12px 0;
		font-size: 18px;
		color: #1e293b;
		font-weight: 600;
	}

	.change-description {
		margin: 0 0 16px 0;
		color: #475569;
		font-size: 15px;
		line-height: 1.6;
		font-weight: 500;
	}

	.change-details {
		background: #f8fafc;
		padding: 16px;
		border-radius: 4px;
		margin-bottom: 16px;
		border-left: 3px solid #3b82f6;
	}

	.change-details h4 {
		margin: 0 0 8px 0;
		font-size: 14px;
		color: #1e293b;
		font-weight: 600;
	}

	.change-details ul {
		margin: 0;
		padding-left: 20px;
		color: #475569;
	}

	.change-details li {
		margin: 4px 0;
		font-size: 13px;
		line-height: 1.5;
	}

	.latest-change .date {
		margin: 0;
		font-size: 13px;
		color: #94a3b8;
	}

	.interface-info {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
		gap: 12px;
	}

	.interface-card {
		background: white;
		padding: 16px;
		border-radius: 6px;
		border: 1px solid #e2e8f0;
		transition: all 0.2s;
	}

	.interface-card:hover {
		border-color: #cbd5e1;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.05);
	}

	.interface-card h4 {
		margin: 0 0 8px 0;
		font-size: 15px;
		color: #1e293b;
		font-weight: 600;
	}

	.interface-card p {
		margin: 0;
		font-size: 13px;
		color: #64748b;
		line-height: 1.5;
	}
</style>
`;
}

/**
 * Update version number in Sidebar.svelte
 */
function updateSidebarVersion(newVersion) {
  const sidebarPath = path.join(__dirname, '../frontend/src/lib/components/desktop-interface/common/Sidebar.svelte');
  
  try {
    let content = fs.readFileSync(sidebarPath, 'utf8');
    
    // Update version number in button
    content = content.replace(
      /AQ[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(?=\s*<\/button>)/g,
      newVersion
    );
    
    fs.writeFileSync(sidebarPath, content);
    return true;
  } catch (error) {
    console.error('❌ Failed to update Sidebar.svelte version:', error.message);
    return false;
  }
}

/**
 * Update VersionChangelog.svelte file
 */
function updateVersionChangelog(newVersion, commitMessage, changeDetails) {
  const changelogPath = path.join(__dirname, '../frontend/src/lib/components/desktop-interface/common/VersionChangelog.svelte');
  
  try {
    const newContent = generateVersionChangelogFile(newVersion, commitMessage, changeDetails);
    fs.writeFileSync(changelogPath, newContent);
    return true;
  } catch (error) {
    console.error('❌ Failed to update VersionChangelog.svelte:', error.message);
    return false;
  }
}

/**
 * Main execution
 */
function main() {
  console.log('\n🚀 Version Update (No Push)\n');
  
  // Step 1: Check git status
  console.log('📊 Checking git status...');
  const changes = getGitStatus();
  
  if (changes.length === 0) {
    console.log('❌ No changes detected\n');
    process.exit(0);
  }
  
  console.log(`✅ Found ${changes.length} changed file(s):\n`);
  changes.forEach(change => {
    const status = change.substring(0, 2);
    const file = change.substring(3);
    console.log(`   ${status} ${file}`);
  });
  console.log();
  
  // Step 2: Get and increment version
  const currentVersion = getCurrentVersion();
  const newVersion = incrementInterfaceVersion(currentVersion, interface_type, 1);
  
  console.log(`📦 Version: ${currentVersion} → ${newVersion}`);
  console.log(`📌 Interface: ${interface_type.toUpperCase()}\n`);
  
  // Step 3: Update files
  console.log('🔄 Updating files...');
  const commitMsg = custom_message || `chore(${interface_type}): bump version to ${newVersion}`;
  
  // Generate automatic change details
  const autoDetails = change_details ? change_details.split('|').map(d => d.trim()) : generateChangeDetails(changes, interface_type, commitMsg);
  
  console.log('   • Updating package.json files...');
  updatePackageJson(newVersion);
  
  console.log('   • Updating Sidebar.svelte version number...');
  updateSidebarVersion(newVersion);
  
  console.log('   • Updating VersionChangelog.svelte...');
  updateVersionChangelog(newVersion, commitMsg, autoDetails);
  
  console.log('✅ Files updated successfully\n');
  
  console.log('='.repeat(50));
  console.log('\n✨ Version update completed!\n');
  console.log(`New Version: ${newVersion}`);
  console.log(`Interface: ${interface_type.toUpperCase()}`);
  console.log(`Commit Message: "${commitMsg}"`);
  console.log('\n⚠️  Changes staged but not pushed. Review and push manually.\n');
}

main();
