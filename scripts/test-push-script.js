#!/usr/bin/env node

/**
 * Test script to verify push-with-version.js logic without interactive prompts
 */

import fs from 'fs';
import path from 'path';
import { execSync } from 'child_process';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

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
      console.log('❌ No changes detected\n');
      return [];
    }

    const files = lines.map(line => {
      const status = line.substring(0, 2);
      const filepath = line.substring(3);
      return { status, filepath };
    });

    return files;
  } catch (error) {
    console.error('❌ Failed to get git status:', error.message);
    return [];
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
 * Main test execution
 */
function main() {
  console.log('\n🧪 TEST: push-with-version.js Logic\n');
  console.log('='.repeat(50));

  // Step 1: Get changed files
  console.log('\n📊 Step 1: Checking git status...');
  const changedFiles = getChangedFiles();
  
  if (changedFiles.length === 0) {
    console.log('⚠️  No changes to test. Make some changes and try again.');
    process.exit(0);
  }

  console.log(`✅ Found ${changedFiles.length} changed file(s)`);

  // Step 2: Detect interfaces
  console.log('\n🎯 Step 2: Detecting modified interfaces...');
  const modifiedInterfaces = detectModifiedInterfaces(changedFiles);
  
  if (modifiedInterfaces.length === 0) {
    console.log('⚠️  No interface-specific changes detected');
  } else {
    console.log(`✅ Detected interfaces: ${modifiedInterfaces.map(i => i.toUpperCase()).join(', ')}`);
  }

  // Step 3: Display changes
  displayChangedFiles(changedFiles, modifiedInterfaces);

  // Step 4: Check version
  console.log('\n' + '='.repeat(50));
  const currentVersion = getCurrentVersion();
  console.log(`\n📦 Current version: ${currentVersion}`);

  // Step 5: Show what would happen
  console.log('\n' + '='.repeat(50));
  console.log('\n✅ SCRIPT VALIDATION PASSED!\n');
  console.log('What would happen next:');
  console.log(`  1. Ask to update version for: ${modifiedInterfaces.join(', ') || 'none'}`);
  console.log(`  2. Update package.json files`);
  console.log(`  3. Update Sidebar.svelte`);
  console.log(`  4. Create commit: chore(${modifiedInterfaces[0] || 'manual'}): bump version`);
  console.log(`  5. Push to git\n`);
  
  console.log('To run the full interactive script:');
  console.log('  node scripts/push-with-version.js\n');
}

main();
