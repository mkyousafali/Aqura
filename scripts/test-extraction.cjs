#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

// Read Sidebar.svelte and extract buttons like the API does
const sidebarPath = path.join(__dirname, '../frontend/src/lib/components/desktop-interface/common/Sidebar.svelte');
const content = fs.readFileSync(sidebarPath, 'utf-8');
const lines = content.split('\n');

let currentSection = null;
let currentSubsection = null;
const sectionData = {};

for (let i = 0; i < lines.length; i++) {
  const line = lines[i];
  const trimmed = line.trim();

  // Detect section start
  const sectionMatch = line.match(/<!-- (\w+[\w\s]*) Section -->/);
  if (sectionMatch) {
    currentSection = sectionMatch[1];
    sectionData[currentSection] = {
      subsections: {},
      buttons: []
    };
    continue;
  }

  if (!currentSection) continue;

  // Detect subsection
  const subsectionMatch = line.match(/title="(Dashboard|Manage|Operations|Reports)"/);
  if (subsectionMatch) {
    currentSubsection = subsectionMatch[1];
    if (!sectionData[currentSection].subsections[currentSubsection]) {
      sectionData[currentSection].subsections[currentSubsection] = [];
    }
    continue;
  }

  // Detect buttons
  if (trimmed.startsWith('<button') && trimmed.includes('on:click={open')) {
    const funcMatch = trimmed.match(/on:click={(\w+)}/);
    if (funcMatch) {
      const handlerFunc = funcMatch[1];
      // Convert function name to button code
      let buttonCode = handlerFunc.replace(/^open/, ''); // Remove 'open' prefix
      buttonCode = buttonCode.replace(/([A-Z])/g, '_$1').replace(/^_/, '');
      buttonCode = buttonCode.toUpperCase();
      
      let buttonText = '';
      for (let j = i; j < Math.min(i + 10, lines.length); j++) {
        const textMatch = lines[j].match(/>([^<{]+)<\/span>/);
        if (textMatch) {
          buttonText = textMatch[1].trim();
          if (buttonText && 
              buttonText !== 'Dashboard' && 
              buttonText !== 'Manage' && 
              buttonText !== 'Operations' && 
              buttonText !== 'Reports' && 
              buttonText !== '▼') {
            break;
          }
        }
      }

      if (buttonText && currentSubsection) {
        sectionData[currentSection].subsections[currentSubsection].push({
          code: buttonCode,
          name: buttonText,
          handlerFunc: handlerFunc
        });
      }
    }
  }
}

console.log('🔍 Extracted Button Codes from Sidebar:\n');
console.log('═'.repeat(80));

let totalButtons = 0;
Object.keys(sectionData).forEach(section => {
  console.log(`\n${section.toUpperCase()}`);
  Object.keys(sectionData[section].subsections).forEach(subsection => {
    const buttons = sectionData[section].subsections[subsection];
    console.log(`  ${subsection}: [${buttons.length}]`);
    buttons.forEach((btn, i) => {
      totalButtons++;
      console.log(`    ${i + 1}. ${btn.code.padEnd(25)} | ${btn.handlerFunc.padEnd(25)} | ${btn.name}`);
    });
  });
});

console.log(`\n═'.repeat(80)`);
console.log(`\nTotal buttons extracted: ${totalButtons}`);
