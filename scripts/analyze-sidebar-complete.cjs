#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

const sidebarPath = path.join(__dirname, '../frontend/src/lib/components/desktop-interface/common/Sidebar.svelte');
const content = fs.readFileSync(sidebarPath, 'utf-8');
const lines = content.split('\n');

// Extract ALL buttons first
const allButtons = [];
const allSections = new Map();
const allSubsections = new Map();

let currentSection = null;
let currentSubsection = null;

for (let i = 0; i < lines.length; i++) {
  const line = lines[i];
  const trimmed = line.trim();

  // Detect section: <!-- SectionName Section -->
  const sectionMatch = line.match(/<!-- (\w+[\w\s]*) Section -->/);
  if (sectionMatch) {
    currentSection = sectionMatch[1].trim();
    if (!allSections.has(currentSection)) {
      allSections.set(currentSection, []);
    }
    continue;
  }

  // Detect subsection title
  const subsectionMatch = line.match(/title="(Dashboard|Manage|Operations|Reports)"/);
  if (subsectionMatch) {
    currentSubsection = subsectionMatch[1];
    if (currentSection) {
      const key = `${currentSection}__${currentSubsection}`;
      if (!allSubsections.has(key)) {
        allSubsections.set(key, []);
      }
    }
    continue;
  }

  // Find ALL buttons - more robust detection
  if (line.includes('on:click={open') && line.includes('<button')) {
    const funcMatch = line.match(/on:click={(\w+)}/);
    if (funcMatch) {
      const handler = funcMatch[1];
      
      // Find button text/name (look in same line or next few lines)
      let buttonName = '';
      for (let j = i; j < Math.min(i + 5, lines.length); j++) {
        // Look for menu-text span
        const textMatch = lines[j].match(/class="menu-text"[^>]*>\s*\{?t\([^)]*\)\s*\|\|\s*['"]([^'"]+)['"]\s*\}?<\/span>/);
        if (textMatch) {
          buttonName = textMatch[1].trim();
          break;
        }
      }

      if (!buttonName) {
        // Fallback: just extract any text in the button
        for (let j = i; j < Math.min(i + 5, lines.length); j++) {
          const simpleMatch = lines[j].match(/>([^<{]+)<\/(span|button)>/);
          if (simpleMatch && simpleMatch[1].trim() && simpleMatch[1].trim() !== '▼') {
            buttonName = simpleMatch[1].trim();
            if (buttonName && buttonName.length > 1) break;
          }
        }
      }

      if (buttonName) {
        allButtons.push({
          name: buttonName,
          handler: handler,
          section: currentSection,
          subsection: currentSubsection
        });

        if (currentSection && currentSubsection) {
          const key = `${currentSection}__${currentSubsection}`;
          allSubsections.get(key).push({
            name: buttonName,
            handler: handler
          });
        }
      }
    }
  }
}

// Display results
console.log('\n' + '═'.repeat(90));
console.log('📊 COMPLETE SIDEBAR STRUCTURE ANALYSIS');
console.log('═'.repeat(90) + '\n');

// Group by section
const sections = {};
allButtons.forEach(btn => {
  if (!sections[btn.section]) {
    sections[btn.section] = {};
  }
  if (!sections[btn.section][btn.subsection]) {
    sections[btn.section][btn.subsection] = [];
  }
  sections[btn.section][btn.subsection].push(btn);
});

let sectionCount = 0;
let subsectionCount = 0;
let buttonCount = 0;

Object.keys(sections).sort().forEach(sectionName => {
  sectionCount++;
  console.log(`\n▶  ${sectionName.toUpperCase()}`);
  console.log(`   ${'─'.repeat(86)}`);
  
  const subsections = sections[sectionName];
  Object.keys(subsections).sort().forEach(subName => {
    subsectionCount++;
    const buttons = subsections[subName];
    buttonCount += buttons.length;
    
    console.log(`   📑 ${(subName || 'NONE').padEnd(22)} [${buttons.length} button${buttons.length !== 1 ? 's' : ''}]`);
    buttons.forEach((btn, idx) => {
      console.log(`      ${String(idx + 1).padStart(2)}. ${btn.name.padEnd(47)} (${btn.handler})`);
    });
  });
});

console.log('\n' + '═'.repeat(90));
console.log('📈 FINAL SUMMARY');
console.log('═'.repeat(90));

console.log(`\n✅ Total Main Sections:        ${sectionCount}`);
console.log(`✅ Total Subsections:          ${subsectionCount}`);
console.log(`✅ Total Buttons:              ${buttonCount}`);

// Summary by subsection type
console.log('\n📊 BUTTON DISTRIBUTION BY SUBSECTION TYPE:');
const subTypes = {};
allButtons.forEach(btn => {
  if (!subTypes[btn.subsection]) {
    subTypes[btn.subsection] = 0;
  }
  subTypes[btn.subsection]++;
});

Object.keys(subTypes).sort().forEach(subType => {
  console.log(`   • ${(subType || 'NONE').padEnd(20)} ${subTypes[subType]} button${subTypes[subType] !== 1 ? 's' : ''}`);
});

console.log('\n' + '═'.repeat(90) + '\n');
