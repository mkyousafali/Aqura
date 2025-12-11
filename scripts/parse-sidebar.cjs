#!/usr/bin/env node

/**
 * Parse Sidebar.svelte Code to Extract Sections, Subsections, and Buttons
 */

const fs = require('fs');
const path = require('path');

const sidebarPath = path.join(__dirname, '../frontend/src/lib/components/desktop-interface/common/Sidebar.svelte');

try {
  const content = fs.readFileSync(sidebarPath, 'utf-8');
  const lines = content.split('\n');

  console.log('\n🔘 SIDEBAR STRUCTURE FROM CODE:\n');
  console.log('═'.repeat(70));

  let currentSection = null;
  let currentSubsection = null;
  let sectionData = {};

  // Parse line by line
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

    // Skip if no current section
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

    // Detect buttons - look for opening button tag with on:click
    if (trimmed.startsWith('<button') && trimmed.includes('on:click={open')) {
      // Extract function name to identify button
      const funcMatch = trimmed.match(/on:click={(\w+)}/);
      if (funcMatch) {
        const funcName = funcMatch[1];
        
        // Look ahead for the button text
        let buttonText = '';
        for (let j = i; j < Math.min(i + 10, lines.length); j++) {
          const textMatch = lines[j].match(/>([^<{]+)<\/span>/);
          if (textMatch) {
            buttonText = textMatch[1].trim();
            if (buttonText && buttonText !== 'Dashboard' && buttonText !== 'Manage' && 
                buttonText !== 'Operations' && buttonText !== 'Reports' && buttonText !== '▼') {
              break;
            }
          }
        }

        if (buttonText && currentSubsection) {
          sectionData[currentSection].subsections[currentSubsection].push({
            name: buttonText,
            function: funcName
          });
        }
      }
    }
  }

  // Print results
  let totalButtons = 0;
  const subsectionOrder = ['Dashboard', 'Manage', 'Operations', 'Reports'];

  Object.keys(sectionData).forEach((section, index) => {
    console.log(`\n${index + 1}. ${section.toUpperCase()}`);
    
    subsectionOrder.forEach(subsec => {
      const buttons = sectionData[section].subsections[subsec] || [];
      console.log(`   └─ ${subsec} [${buttons.length}]`);
      
      buttons.slice(0, 2).forEach(btn => {
        console.log(`      • ${btn.name}`);
      });
      
      if (buttons.length > 2) {
        console.log(`      ... and ${buttons.length - 2} more`);
      }
      
      totalButtons += buttons.length;
    });

    const sectionTotal = Object.values(sectionData[section].subsections)
      .reduce((sum, arr) => sum + arr.length, 0);
    console.log(`   📌 Section Total: ${sectionTotal}`);
  });

  console.log('\n' + '═'.repeat(70));
  console.log(`\n📊 SUMMARY FROM CODE:`);
  console.log(`   Sections: ${Object.keys(sectionData).length}`);
  console.log(`   Subsections: ${Object.keys(sectionData).length * 4}`);
  console.log(`   Total Buttons: ${totalButtons}\n`);

} catch (error) {
  console.error('Error:', error.message);
}
