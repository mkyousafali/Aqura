import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// Directories to analyze
const interfaceDirs = {
  desktop: path.join(__dirname, '..', 'frontend', 'src', 'lib', 'components', 'desktop-interface'),
  mobile: path.join(__dirname, '..', 'frontend', 'src', 'routes', 'mobile-interface'),
  mobileComponents: path.join(__dirname, '..', 'frontend', 'src', 'lib', 'components', 'mobile-interface'),
  customer: path.join(__dirname, '..', 'frontend', 'src', 'routes', 'customer-interface'),
  customerComponents: path.join(__dirname, '..', 'frontend', 'src', 'lib', 'components', 'customer-interface'),
  cashier: path.join(__dirname, '..', 'frontend', 'src', 'lib', 'components', 'cashier-interface'),
  adminCustomer: path.join(__dirname, '..', 'frontend', 'src', 'lib', 'components', 'desktop-interface', 'admin-customer-app'),
  marketing: path.join(__dirname, '..', 'frontend', 'src', 'lib', 'components', 'desktop-interface', 'marketing')
};

// Exclude common components (TopBar, Sidebar, BottomNav, etc.)
const excludePatterns = [
  'Sidebar',
  'TopBar',
  'BottomNav',
  'Taskbar',
  'Window.svelte',
  'WindowManager',
  'VersionChangelog',
  'CommandPalette',
  'PWAInstallPrompt',
  'LoginForm',
  'CustomerLogin',
  'CashierLogin',
  'LanguageToggle',
  'ToastNotifications',
  'NotificationSoundControls',
  'UserSwitcher',
  'WelcomeWindow',
  'FileUpload',
  'FileDownload'
];

// Action button patterns to detect
const actionButtonPatterns = [
  { pattern: /create|add|new/i, action: 'CREATE' },
  { pattern: /edit|modify|update/i, action: 'EDIT' },
  { pattern: /delete|remove|clear/i, action: 'DELETE' },
  { pattern: /export|download/i, action: 'EXPORT' },
  { pattern: /approve|reject/i, action: 'APPROVE' },
  { pattern: /assign|schedule/i, action: 'ASSIGN' },
  { pattern: /upload|import/i, action: 'UPLOAD' },
  { pattern: /save|submit|confirm/i, action: 'SAVE' },
  { pattern: /view|details|show/i, action: 'VIEW' },
  { pattern: /send|notify/i, action: 'SEND' }
];

function shouldExclude(filePath) {
  return excludePatterns.some(pattern => filePath.includes(pattern));
}

function getAllSvelteFiles(dir, fileList = []) {
  if (!fs.existsSync(dir)) {
    return fileList;
  }

  const files = fs.readdirSync(dir);

  files.forEach(file => {
    const filePath = path.join(dir, file);
    const stat = fs.statSync(filePath);

    if (stat.isDirectory()) {
      getAllSvelteFiles(filePath, fileList);
    } else if (file.endsWith('.svelte') && !shouldExclude(filePath)) {
      fileList.push(filePath);
    }
  });

  return fileList;
}

function analyzeButtons(filePath) {
  const content = fs.readFileSync(filePath, 'utf-8');
  const buttons = [];
  
  // Find all button elements
  const buttonRegex = /<button[^>]*>(.*?)<\/button>/gs;
  let match;
  let lineOffset = 0;
  
  while ((match = buttonRegex.exec(content)) !== null) {
    const buttonTag = match[0];
    const buttonText = match[1].replace(/<[^>]*>/g, '').trim();
    
    // Get line number
    const beforeMatch = content.substring(0, match.index);
    const lineNumber = (beforeMatch.match(/\n/g) || []).length + 1;
    
    // Extract attributes
    const classMatch = buttonTag.match(/class\s*=\s*["']([^"']+)["']/);
    const onClickMatch = buttonTag.match(/on:click\s*=\s*[{]?([^}>"']+)[}]?/);
    const typeMatch = buttonTag.match(/type\s*=\s*["']([^"']+)["']/);
    const disabledMatch = buttonTag.match(/disabled\s*=?\s*[{]?([^}>"']*)[}]?/);
    
    // Detect action type
    let actionType = 'OTHER';
    for (const { pattern, action } of actionButtonPatterns) {
      if (pattern.test(buttonText) || (onClickMatch && pattern.test(onClickMatch[1])) || (classMatch && pattern.test(classMatch[1]))) {
        actionType = action;
        break;
      }
    }
    
    // Check for permission checks nearby
    const contextStart = Math.max(0, match.index - 200);
    const contextEnd = Math.min(content.length, match.index + buttonTag.length + 200);
    const context = content.substring(contextStart, contextEnd);
    
    const hasPermissionCheck = /hasPermission|canCreate|canEdit|canDelete|canView|canExport|role_type\s*===|roleType\s*===/.test(context);
    const hasIfCondition = /{#if/.test(context);
    
    buttons.push({
      line: lineNumber,
      text: buttonText.substring(0, 50),
      class: classMatch ? classMatch[1] : '',
      onClick: onClickMatch ? onClickMatch[1].substring(0, 50) : '',
      type: typeMatch ? typeMatch[1] : '',
      disabled: disabledMatch ? disabledMatch[0] : '',
      actionType,
      hasPermissionCheck,
      hasIfCondition
    });
  }
  
  return buttons;
}

function getComponentCategory(filePath) {
  if (filePath.includes('desktop-interface/settings')) return 'Desktop/Settings';
  if (filePath.includes('desktop-interface/master')) return 'Desktop/Master';
  if (filePath.includes('desktop-interface/marketing')) return 'Desktop/Marketing';
  if (filePath.includes('desktop-interface/admin-customer-app')) return 'Desktop/Admin-Customer';
  if (filePath.includes('desktop-interface')) return 'Desktop/Other';
  if (filePath.includes('routes/mobile-interface')) return 'Mobile/Routes';
  if (filePath.includes('components/mobile-interface')) return 'Mobile/Components';
  if (filePath.includes('routes/customer-interface')) return 'Customer/Routes';
  if (filePath.includes('components/customer-interface')) return 'Customer/Components';
  if (filePath.includes('cashier-interface')) return 'Cashier';
  return 'Other';
}

console.log('🔍 Analyzing buttons across all interfaces...\n');

const results = {
  components: [],
  summary: {
    totalComponents: 0,
    totalButtons: 0,
    buttonsWithPermissions: 0,
    buttonsWithoutPermissions: 0,
    byInterface: {},
    byActionType: {}
  }
};

// Analyze all directories
for (const [interfaceName, dir] of Object.entries(interfaceDirs)) {
  const files = getAllSvelteFiles(dir);
  
  files.forEach(filePath => {
    const buttons = analyzeButtons(filePath);
    
    if (buttons.length > 0) {
      const relativePath = path.relative(path.join(__dirname, '..'), filePath);
      const componentName = path.basename(filePath, '.svelte');
      const category = getComponentCategory(filePath);
      
      results.components.push({
        interface: interfaceName,
        category,
        componentName,
        filePath: relativePath,
        buttonCount: buttons.length,
        buttons
      });
      
      results.summary.totalComponents++;
      results.summary.totalButtons += buttons.length;
      results.summary.buttonsWithPermissions += buttons.filter(b => b.hasPermissionCheck).length;
      results.summary.buttonsWithoutPermissions += buttons.filter(b => !b.hasPermissionCheck).length;
      
      // Count by interface
      if (!results.summary.byInterface[interfaceName]) {
        results.summary.byInterface[interfaceName] = 0;
      }
      results.summary.byInterface[interfaceName] += buttons.length;
      
      // Count by action type
      buttons.forEach(button => {
        if (!results.summary.byActionType[button.actionType]) {
          results.summary.byActionType[button.actionType] = 0;
        }
        results.summary.byActionType[button.actionType]++;
      });
    }
  });
}

// Sort by interface and category
results.components.sort((a, b) => {
  if (a.interface !== b.interface) return a.interface.localeCompare(b.interface);
  if (a.category !== b.category) return a.category.localeCompare(b.category);
  return a.componentName.localeCompare(b.componentName);
});

// Generate markdown report
const reportPath = path.join(__dirname, '..', 'Do not delete', 'BUTTON_INVENTORY_REPORT.md');
let markdown = `# Button Inventory Report

**Generated:** ${new Date().toLocaleString()}  
**Total Components:** ${results.summary.totalComponents}  
**Total Buttons:** ${results.summary.totalButtons}  
**Buttons With Permission Checks:** ${results.summary.buttonsWithPermissions}  
**Buttons Without Permission Checks:** ${results.summary.buttonsWithoutPermissions}

---

## 📊 Summary Statistics

### By Interface
| Interface | Button Count |
|-----------|--------------|
`;

for (const [interfaceName, count] of Object.entries(results.summary.byInterface)) {
  markdown += `| ${interfaceName} | ${count} |\n`;
}

markdown += `\n### By Action Type\n\n| Action Type | Button Count |\n|-------------|--------------|n`;

for (const [action, count] of Object.entries(results.summary.byActionType)) {
  markdown += `| ${action} | ${count} |\n`;
}

markdown += `\n---\n\n## 📋 Complete Button Inventory\n\n`;
markdown += `**Format:** Interface | Component Name | Button Purpose | Location (File:Line)\n\n`;

markdown += `| Interface | Component | Button Purpose | Location | Has Permission |\n`;
markdown += `|-----------|-----------|----------------|----------|----------------|\n`;

results.components.forEach(component => {
  component.buttons.forEach(button => {
    const purpose = button.text || button.onClick || button.class || '(unnamed)';
    const cleanPurpose = purpose.replace(/\n/g, ' ').replace(/\s+/g, ' ').substring(0, 60);
    const location = `${component.componentName}.svelte:${button.line}`;
    const interfaceName = component.category.split('/')[0];
    const hasPermCheck = button.hasPermissionCheck ? '✅' : '❌';
    
    markdown += `| ${interfaceName} | ${component.componentName} | ${button.actionType}: ${cleanPurpose} | ${location} | ${hasPermCheck} |\n`;
  });
});

markdown += `\n---\n\n## 🔴 High Priority: CREATE/EDIT/DELETE Buttons Needing Permission Checks\n\n`;
markdown += `| Interface | Component | Action | Button Purpose | Location |\n`;
markdown += `|-----------|-----------|--------|----------------|----------|\n`;

results.components.forEach(component => {
  const criticalButtons = component.buttons.filter(b => 
    ['CREATE', 'EDIT', 'DELETE', 'APPROVE'].includes(b.actionType) && 
    !b.hasPermissionCheck
  );
  
  criticalButtons.forEach(btn => {
    const purpose = btn.text || btn.onClick || btn.class || '(unnamed)';
    const cleanPurpose = purpose.replace(/\n/g, ' ').replace(/\s+/g, ' ').substring(0, 50);
    const location = `${component.componentName}.svelte:${btn.line}`;
    const interfaceName = component.category.split('/')[0];
    
    markdown += `| ${interfaceName} | ${component.componentName} | **${btn.actionType}** | ${cleanPurpose} | ${location} |\n`;
  });
});

markdown += `\n---\n\n## 🟡 Medium Priority: Other Action Buttons Needing Permission Checks\n\n`;
markdown += `| Interface | Component | Action | Button Purpose | Location |\n`;
markdown += `|-----------|-----------|--------|----------------|----------|\n`;

results.components.forEach(component => {
  const mediumButtons = component.buttons.filter(b => 
    ['UPLOAD', 'EXPORT', 'ASSIGN', 'SEND'].includes(b.actionType) && 
    !b.hasPermissionCheck
  );
  
  mediumButtons.forEach(btn => {
    const purpose = btn.text || btn.onClick || btn.class || '(unnamed)';
    const cleanPurpose = purpose.replace(/\n/g, ' ').replace(/\s+/g, ' ').substring(0, 50);
    const location = `${component.componentName}.svelte:${btn.line}`;
    const interfaceName = component.category.split('/')[0];
    
    markdown += `| ${interfaceName} | ${component.componentName} | ${btn.actionType} | ${cleanPurpose} | ${location} |\n`;
  });
});

markdown += `\n---\n\n## 📝 Component Summary (Components with Critical Actions)\n\n`;
markdown += `| Component Name | Interface | Total Buttons | Critical Actions | File Path |\n`;
markdown += `|----------------|-----------|---------------|------------------|------------|\n`;

// Use a Set to track unique components
const processedComponents = new Set();

results.components.forEach(component => {
  const criticalCount = component.buttons.filter(b => 
    ['CREATE', 'EDIT', 'DELETE', 'APPROVE'].includes(b.actionType) && 
    !b.hasPermissionCheck
  ).length;
  
  if (criticalCount > 0) {
    const interfaceName = component.category.split('/')[0];
    const componentKey = `${component.componentName}-${component.filePath}`;
    
    // Only add if not already processed
    if (!processedComponents.has(componentKey)) {
      processedComponents.add(componentKey);
      markdown += `| ${component.componentName} | ${interfaceName} | ${component.buttonCount} | ${criticalCount} | \`${component.filePath}\` |\n`;
    }
  }
});

markdown += `\n---\n\n## ✅ Next Steps\n\n`;
markdown += `1. **Priority 1:** Fix components with CREATE/EDIT/DELETE buttons (see High Priority section)\n`;
markdown += `2. **Priority 2:** Fix components with UPLOAD/EXPORT/ASSIGN buttons (see Medium Priority section)\n`;
markdown += `3. **Priority 3:** Review remaining buttons for permission requirements\n`;
markdown += `4. Add permission checks using:\n`;
markdown += `   - \`hasPermission('FUNCTION_CODE', 'can_add')\` for CREATE buttons\n`;
markdown += `   - \`hasPermission('FUNCTION_CODE', 'can_edit')\` for EDIT buttons\n`;
markdown += `   - \`hasPermission('FUNCTION_CODE', 'can_delete')\` for DELETE buttons\n`;
markdown += `   - Wrap buttons in \`{#if}\` blocks to hide when no permission\n\n`;

fs.writeFileSync(reportPath, markdown, 'utf-8');

console.log('✅ Analysis complete!\n');
console.log('📊 Summary:');
console.log(`   - Components analyzed: ${results.summary.totalComponents}`);
console.log(`   - Total buttons found: ${results.summary.totalButtons}`);
console.log(`   - With permission checks: ${results.summary.buttonsWithPermissions}`);
console.log(`   - Without permission checks: ${results.summary.buttonsWithoutPermissions}`);
console.log(`\n📄 Report saved to: Do not delete/BUTTON_INVENTORY_REPORT.md`);
