import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// Read Sidebar.svelte file
const sidebarPath = path.join(__dirname, '..', 'frontend', 'src', 'lib', 'components', 'desktop-interface', 'common', 'Sidebar.svelte');
const content = fs.readFileSync(sidebarPath, 'utf-8');

// Map menu items to function codes based on actual sidebar content
const menuToFunctionMap = {
  // Dashboard
  'Dashboard': 'DASHBOARD',
  
  // Master
  'Branch Master': 'BRANCH_MASTER',
  'HR Master': 'HR_MASTER',
  'Task Master': 'TASK_MASTER',
  'Operations Master': 'RECEIVING_MGMT',
  
  // Vendor
  'Vendor': 'VENDOR_MGMT',
  'Manage Vendor': 'VENDOR_MGMT',
  'Edit Vendor': 'VENDOR_MGMT',
  'Upload Vendor': 'VENDOR_MGMT',
  'Create Vendor': 'VENDOR_MGMT',
  
  // Finance
  'Finance': 'FINANCIAL_REPORTS',
  'Approval Center': 'REQUISITION_MGMT',
  'Monthly Manager': 'FINANCIAL_REPORTS',
  'Monthly Breakdown': 'FINANCIAL_REPORTS',
  'Expenses Manager': 'EXPENSE_MGMT',
  'Expense Manager': 'EXPENSE_MGMT',
  'Day Budget Planner': 'BUDGET_TRACKING',
  'Manual Scheduling': 'PAYMENT_SCHEDULER',
  'Paid Manager': 'PAYMENT_SCHEDULER',
  'Expense Tracker': 'FINANCIAL_REPORTS',
  'Sales Report': 'SALES_REPORTS',
  'Vendor Pending Payments': 'FINANCIAL_REPORTS',
  'Vendor Payments': 'FINANCIAL_REPORTS',
  'Vendor Records': 'FINANCIAL_REPORTS',
  'Overdues Report': 'FINANCIAL_REPORTS',
  'Over dues': 'FINANCIAL_REPORTS',
  
  // HR
  'Upload Employees': 'HR_MASTER',
  'Create Department': 'HR_MASTER',
  'Create Level': 'HR_MASTER',
  'Create Position': 'HR_MASTER',
  'Reporting Map': 'HR_MASTER',
  'Assign Positions': 'HR_MASTER',
  'Biometric Export': 'HR_MASTER',
  'Export Biometric Data': 'HR_MASTER',
  'Biometric Data': 'HR_MASTER',
  'Document Management': 'HR_MASTER',
  'Salary Management': 'HR_MASTER',
  'Salary & Wage Management': 'HR_MASTER',
  'Warning Master': 'HR_MASTER',
  'Contact Management': 'HR_MASTER',
  
  // Tasks
  'Task Create Form': 'TASK_MASTER',
  'Task View Table': 'TASK_MASTER',
  'Task Assignment View': 'TASK_MASTER',
  'My Tasks View': 'TASK_MASTER',
  'My Assignments View': 'TASK_MASTER',
  'Task Status View': 'TASK_MASTER',
  'Branch Performance': 'TASK_MASTER',
  'Create Task Template': 'TASK_MASTER',
  'View Task Templates': 'TASK_MASTER',
  'Assign Tasks': 'TASK_MASTER',
  'View My Tasks': 'TASK_MASTER',
  'View My Assignments': 'TASK_MASTER',
  'Task Status': 'TASK_MASTER',
  
  // Receiving
  'Start Receiving': 'RECEIVING_MGMT',
  'New Start Receiving': 'RECEIVING_MGMT',
  'Receiving Records': 'RECEIVING_MGMT',
  'Receiving': 'RECEIVING_MGMT',
  
  // Customer/Delivery
  'Customer Master': 'CUSTOMER_MGMT',
  'Ad Manager': 'NOTIFICATION_CENTER',
  'Products Manager': 'PRODUCT_MGMT',
  'Delivery Settings': 'SETTINGS',
  'Orders Manager': 'CUSTOMER_MGMT',
  'Offer Management': 'OFFER_MGMT',
  
  // Marketing/Flyer
  'Flyer Master Dashboard': 'OFFER_MGMT',
  'Flyer Master': 'OFFER_MGMT',
  'Product Master': 'PRODUCT_MGMT',
  'Variation Manager': 'PRODUCT_MGMT',
  'Offer Templates': 'OFFER_MGMT',
  'Offer Product Selector': 'OFFER_MGMT',
  'Offer Product Editor': 'OFFER_MGMT',
  'Create New Offer': 'OFFER_MGMT',
  'Offer Manager': 'OFFER_MGMT',
  'Pricing Manager': 'PRICE_MGMT',
  'Flyer Generator': 'OFFER_MGMT',
  'Generate Flyers': 'OFFER_MGMT',
  'Flyer Templates': 'OFFER_MGMT',
  'Flyer Settings': 'SETTINGS',
  'Design Planner': 'OFFER_MGMT',
  'Shelf Paper Manager': 'OFFER_MGMT',
  
  // Coupon
  'Coupon Dashboard': 'COUPON_MGMT',
  'Campaign Manager': 'COUPON_MGMT',
  'Manage Campaigns': 'COUPON_MGMT',
  'Customer Importer': 'COUPON_MGMT',
  'Import Customers': 'COUPON_MGMT',
  'Product Manager': 'COUPON_MGMT',
  'Manage Products': 'COUPON_MGMT',
  'Coupon Reports': 'COUPON_MGMT',
  'Reports & Stats': 'COUPON_MGMT',
  
  // Communication
  'Communication Center': 'NOTIFICATION_CENTER',
  'Com Center': 'NOTIFICATION_CENTER',
  
  // Settings
  'Settings': 'SETTINGS',
  'Sound Settings': 'SETTINGS',
  'User Management': 'USER_MGMT',
  'Users': 'USER_MGMT',
  'Approval Permissions Manager': 'USER_MGMT',
  'Approval Permissions': 'USER_MGMT',
  'Interface Access Manager': 'SETTINGS',
  'Interface Access': 'SETTINGS',
  'ERP Connections': 'SETTINGS',
  'Clear Tables': 'SETTINGS',
  'User Permissions Window': 'USER_MGMT',
  'User Permissions': 'USER_MGMT'
};

// Extract menu items from sidebar
const menuItems = [];
const lines = content.split('\n');

for (let i = 0; i < lines.length; i++) {
  const line = lines[i];
  
  // Look for button clicks that open windows
  if (line.includes('on:click={open') && !line.includes('showSubmenu')) {
    const functionMatch = line.match(/on:click=\{([a-zA-Z]+)\}/);
    if (functionMatch) {
      const functionName = functionMatch[1];
      
      // Extract menu text (look ahead for menu-text or section-text)
      let menuText = '';
      for (let j = i; j < Math.min(i + 5, lines.length); j++) {
        const textMatch = lines[j].match(/<span class="(?:menu-text|section-text)">([^<]+)<\/span>/);
        if (textMatch) {
          menuText = textMatch[1];
          // Remove translation keys
          menuText = menuText.replace(/\{t\('.*?'\) \|\| '([^']+)'\}/, '$1');
          menuText = menuText.replace(/\{t\('.*?'\)\}/, '');
          menuText = menuText.replace(/\|\| '([^']+)'/, '$1').trim();
          break;
        }
      }
      
      // Check for permission check
      let hasPermissionCheck = false;
      for (let j = Math.max(0, i - 10); j < Math.min(i + 5, lines.length); j++) {
        if (lines[j].includes('roleType ===') || lines[j].includes('role_type ===')) {
          hasPermissionCheck = true;
          break;
        }
      }
      
      if (menuText) {
        const functionCode = menuToFunctionMap[menuText] || 'UNKNOWN';
        
        menuItems.push({
          menuText,
          functionName,
          functionCode,
          lineNumber: i + 1,
          hasPermissionCheck
        });
      }
    }
  }
}

// Generate report
const reportPath = path.join(__dirname, '..', 'Do not delete', 'SIDEBAR_BUTTON_MAPPING.md');
let markdown = `# Sidebar Button Mapping Report

**Generated:** ${new Date().toLocaleString()}  
**Total Sidebar Menu Items:** ${menuItems.length}  
**Items With Permission Checks:** ${menuItems.filter(item => item.hasPermissionCheck).length}  
**Items Without Permission Checks:** ${menuItems.filter(item => !item.hasPermissionCheck).length}

---

## 📊 Summary by Function Code

`;

// Group by function code
const byFunctionCode = {};
menuItems.forEach(item => {
  if (!byFunctionCode[item.functionCode]) {
    byFunctionCode[item.functionCode] = [];
  }
  byFunctionCode[item.functionCode].push(item);
});

markdown += `| Function Code | Menu Items Count |\n`;
markdown += `|---------------|------------------|\n`;
Object.keys(byFunctionCode).sort().forEach(code => {
  markdown += `| ${code} | ${byFunctionCode[code].length} |\n`;
});

markdown += `\n---\n\n## 📋 Complete Sidebar Menu Mapping\n\n`;
markdown += `| Menu Text | Function Code | Handler | Line | Has Permission Check |\n`;
markdown += `|-----------|---------------|---------|------|---------------------|\n`;

menuItems.forEach(item => {
  const hasCheck = item.hasPermissionCheck ? '✅' : '❌';
  markdown += `| ${item.menuText} | ${item.functionCode} | ${item.functionName} | ${item.lineNumber} | ${hasCheck} |\n`;
});

markdown += `\n---\n\n## 🔴 Items Needing Permission Checks\n\n`;
markdown += `| Menu Text | Function Code | Recommended Permission | Line |\n`;
markdown += `|-----------|---------------|------------------------|------|\n`;

menuItems.filter(item => !item.hasPermissionCheck).forEach(item => {
  markdown += `| ${item.menuText} | ${item.functionCode} | \`canView('${item.functionCode}')\` | ${item.lineNumber} |\n`;
});

markdown += `\n---\n\n## ✅ Implementation Guide\n\n`;
markdown += `### Step 1: Add Permission Utility Import\n\n`;
markdown += `\`\`\`typescript\nimport { canView } from '$lib/utils/permissions';\n\`\`\`\n\n`;
markdown += `### Step 2: Replace Role Checks with Permission Checks\n\n`;
markdown += `**OLD PATTERN:**\n\`\`\`svelte\n{#if $currentUser?.roleType === 'Master Admin' || $currentUser?.roleType === 'Admin'}\n  <button on:click={openCustomerMaster}>\n    Customer Master\n  </button>\n{/if}\n\`\`\`\n\n`;
markdown += `**NEW PATTERN:**\n\`\`\`svelte\n{#if canView('CUSTOMER_MGMT')}\n  <button on:click={openCustomerMaster}>\n    Customer Master\n  </button>\n{/if}\n\`\`\`\n\n`;
markdown += `### Step 3: Menu Items by Function Code\n\n`;

Object.keys(byFunctionCode).sort().forEach(code => {
  markdown += `#### ${code}\n`;
  markdown += `- **Permission Check:** \`canView('${code}')\`\n`;
  markdown += `- **Menu Items:**\n`;
  byFunctionCode[code].forEach(item => {
    markdown += `  - ${item.menuText} (line ${item.lineNumber})\n`;
  });
  markdown += `\n`;
});

fs.writeFileSync(reportPath, markdown, 'utf-8');

console.log('✅ Sidebar analysis complete!\n');
console.log('📊 Summary:');
console.log(`   - Total menu items: ${menuItems.length}`);
console.log(`   - With permission checks: ${menuItems.filter(item => item.hasPermissionCheck).length}`);
console.log(`   - Without permission checks: ${menuItems.filter(item => !item.hasPermissionCheck).length}`);
console.log(`   - Unique function codes: ${Object.keys(byFunctionCode).length}`);
console.log(`\n📄 Report saved to: Do not delete/SIDEBAR_BUTTON_MAPPING.md`);
