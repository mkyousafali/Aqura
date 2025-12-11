#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

const sidebarPath = path.join(__dirname, '../frontend/src/lib/components/desktop-interface/common/Sidebar.svelte');
const content = fs.readFileSync(sidebarPath, 'utf-8');
const lines = content.split('\n');

let currentSection = null;
let currentSubsection = null;
const sectionData = {};

for (let i = 0; i < lines.length; i++) {
  const line = lines[i];
  const trimmed = line.trim();

  // Detect section start: <!-- SectionName Section -->
  const sectionMatch = line.match(/<!-- (\w+[\w\s]*) Section -->/);
  if (sectionMatch) {
    currentSection = sectionMatch[1];
    sectionData[currentSection] = {
      subsections: {}
    };
    continue;
  }

  if (!currentSection) continue;

  // Detect subsection: title="Dashboard|Manage|Operations|Reports"
  const subsectionMatch = line.match(/title="(Dashboard|Manage|Operations|Reports)"/);
  if (subsectionMatch) {
    currentSubsection = subsectionMatch[1];
    if (!sectionData[currentSection].subsections[currentSubsection]) {
      sectionData[currentSection].subsections[currentSubsection] = [];
    }
    continue;
  }

  // Detect buttons: <button ... on:click={open...}>
  if (trimmed.startsWith('<button') && trimmed.includes('on:click={open')) {
    const funcMatch = trimmed.match(/on:click={(\w+)}/);
    if (funcMatch) {
      const handlerFunc = funcMatch[1];
      
      // Look for menu-text span
      let buttonText = '';
      for (let j = i; j < Math.min(i + 5, lines.length); j++) {
        const menuTextLine = lines[j];
        const menuTextMatch = menuTextLine.match(/class="menu-text"[^>]*>\s*\{?t\([^)]*\)\s*\|\|\s*['"]([^'"]+)['"]\s*\}?<\/span>/);
        if (menuTextMatch) {
          buttonText = menuTextMatch[1].trim();
          break;
        }
      }

      if (buttonText && currentSubsection) {
        sectionData[currentSection].subsections[currentSubsection].push({
          name: buttonText,
          handler: handlerFunc
        });
      }
    }
  }
}

// Display results
console.log('\n' + '═'.repeat(80));
console.log('📊 SIDEBAR STRUCTURE ANALYSIS');
console.log('═'.repeat(80) + '\n');

let totalSections = 0;
let totalSubsections = 0;
let totalButtons = 0;
const subsectionCounts = {};

Object.keys(sectionData).forEach(section => {
  totalSections++;
  const subsections = sectionData[section].subsections;
  
  console.log(`\n${'▶'.padEnd(2)} ${section.toUpperCase()}`);
  console.log(`${''.padEnd(2)} ${'─'.repeat(76)}`);
  
  Object.keys(subsections).forEach(subsectionName => {
    const buttons = subsections[subsectionName];
    totalSubsections++;
    totalButtons += buttons.length;
    
    // Track subsection button counts
    if (!subsectionCounts[subsectionName]) {
      subsectionCounts[subsectionName] = 0;
    }
    subsectionCounts[subsectionName] += buttons.length;
    
    console.log(`   📑 ${subsectionName.padEnd(20)} [${buttons.length} button${buttons.length !== 1 ? 's' : ''}]`);
    buttons.forEach((btn, idx) => {
      console.log(`      ${(idx + 1).toString().padStart(2)}. ${btn.name.padEnd(45)} (${btn.handler})`);
    });
  });
});

console.log('\n' + '═'.repeat(80));
console.log('📈 SUMMARY STATISTICS');
console.log('═'.repeat(80));

console.log(`\n✅ Total Main Sections:        ${totalSections}`);
console.log(`✅ Total Subsections:          ${totalSubsections}`);
console.log(`✅ Total Buttons:              ${totalButtons}`);

console.log('\n📊 BUTTONS PER SUBSECTION:');
Object.keys(subsectionCounts)
  .sort()
  .forEach(subName => {
    const count = subsectionCounts[subName];
    console.log(`   • ${subName.padEnd(20)} ${count} button${count !== 1 ? 's' : ''}`);
  });

console.log('\n📋 BUTTONS PER SECTION:');
Object.keys(sectionData)
  .sort()
  .forEach(section => {
    let sectionTotal = 0;
    Object.keys(sectionData[section].subsections).forEach(sub => {
      sectionTotal += sectionData[section].subsections[sub].length;
    });
    console.log(`   • ${section.padEnd(20)} ${sectionTotal} button${sectionTotal !== 1 ? 's' : ''}`);
  });

console.log('\n' + '═'.repeat(80) + '\n');
