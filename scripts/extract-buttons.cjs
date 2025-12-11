#!/usr/bin/env node

/**
 * Script: Extract All Buttons from Sidebar Code
 */

const fs = require('fs');
const path = require('path');

const sidebarPath = path.join(__dirname, '../frontend/src/lib/components/desktop-interface/common/Sidebar.svelte');

try {
  const content = fs.readFileSync(sidebarPath, 'utf-8');
  const lines = content.split('\n');

  console.log('\n🔘 SIDEBAR BUTTONS BY SECTION:\n');
  console.log('═'.repeat(70));

  const sections = ['Delivery', 'Vendor', 'Media', 'Promo', 'Finance', 'HR', 'Tasks', 'Notifications', 'User', 'Controls'];
  let currentSection = '';
  let currentSubsection = '';
  let sectionButtonCount = {};

  // Track buttons by section
  sections.forEach(s => {
    sectionButtonCount[s] = 0;
  });

  let totalButtons = 0;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];

    // Detect section
    for (const section of sections) {
      if (line.includes(`<!-- ${section} Section -->`)) {
        currentSection = section;
        if (sectionButtonCount[currentSection] > 0) {
          console.log(`   📌 Total: ${sectionButtonCount[currentSection]} buttons\n`);
        }
        if (currentSection !== sections[0]) {
          console.log(`\n${sections.indexOf(currentSection) + 1}. ${currentSection.toUpperCase()}`);
        } else {
          console.log(`1. ${currentSection.toUpperCase()}`);
        }
      }
    }

    // Detect subsection
    if (line.includes('title="Dashboard"') || line.includes('title="Manage"') || 
        line.includes('title="Operations"') || line.includes('title="Reports"')) {
      const match = line.match(/title="([^"]+)"/);
      if (match) {
        currentSubsection = match[1];
        console.log(`   └─ ${currentSubsection}`);
      }
    }

    // Detect buttons - look for on:click handlers and menu-text
    if (currentSection && line.includes('on:click={open') && !line.includes('submenu')) {
      // Extract button name from next line or same line
      let buttonName = '';
      
      if (line.includes('menu-text')) {
        const match = line.match(/>([^<]+)<\/span>/);
        if (match) buttonName = match[1].trim();
      } else {
        // Look in next few lines
        for (let j = i; j < Math.min(i + 5, lines.length); j++) {
          const nextMatch = lines[j].match(/menu-text">([^<]+)</);
          if (nextMatch) {
            buttonName = nextMatch[1].trim();
            break;
          }
        }
      }

      if (buttonName && currentSubsection) {
        console.log(`      • ${buttonName}`);
        sectionButtonCount[currentSection]++;
        totalButtons++;
      }
    }
  }

  // Final count for last section
  if (currentSection && sectionButtonCount[currentSection] > 0) {
    console.log(`   📌 Total: ${sectionButtonCount[currentSection]} buttons`);
  }

  console.log('\n' + '═'.repeat(70));
  console.log(`\n📊 TOTAL SUMMARY:`);
  console.log(`   Sections: ${sections.length}`);
  console.log(`   Total Buttons: ${totalButtons}\n`);

} catch (error) {
  console.error('Error:', error.message);
}
