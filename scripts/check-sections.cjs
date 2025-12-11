#!/usr/bin/env node

/**
 * Script: Check Sidebar Sections, Subsections, and Buttons
 */

const fs = require('fs');
const path = require('path');

const sidebarPath = path.join(__dirname, '../frontend/src/lib/components/desktop-interface/common/Sidebar.svelte');

try {
  const content = fs.readFileSync(sidebarPath, 'utf-8');

  // Find all section comments
  const sectionRegex = /<!-- (\w+[\w\s]*) Section -->/g;
  const sections = [];
  let match;

  while ((match = sectionRegex.exec(content)) !== null) {
    sections.push(match[1]);
  }

  console.log('\n📋 SIDEBAR SECTIONS, SUBSECTIONS & BUTTONS:\n');
  console.log('═'.repeat(70));

  // Standard subsections that appear in most sections
  const standardSubsections = ['Dashboard', 'Manage', 'Operations', 'Reports'];
  let totalButtons = 0;

  sections.forEach((section, index) => {
    console.log(`\n${index + 1}. ${section.toUpperCase()}`);
    
    // Find buttons in this section
    const sectionStart = content.indexOf(`<!-- ${section} Section -->`);
    const nextSectionStart = content.indexOf('<!-- ', sectionStart + 1);
    const sectionContent = nextSectionStart > 0 
      ? content.substring(sectionStart, nextSectionStart) 
      : content.substring(sectionStart);

    // Count buttons by looking for menu-text spans with button names
    const buttonMatches = sectionContent.match(/<span class="menu-text">([^<]+)<\/span>/g) || [];
    const sectionButtonCount = buttonMatches.length;

    standardSubsections.forEach(sub => {
      // Try to count buttons per subsection (rough estimate)
      const subsectionStart = sectionContent.indexOf(`title="${sub}"`);
      let subsectionButtonCount = 0;
      
      if (subsectionStart > 0) {
        // Find next subsection
        const nextSubStart = sectionContent.indexOf(`title="`, subsectionStart + 1);
        const subsectionRange = nextSubStart > 0 
          ? sectionContent.substring(subsectionStart, nextSubStart)
          : sectionContent.substring(subsectionStart);
        
        // Count menu items in this range
        subsectionButtonCount = (subsectionRange.match(/<span class="menu-text">/g) || []).length;
      }
      
      const buttonText = subsectionButtonCount > 0 ? `[${subsectionButtonCount} buttons]` : '';
      console.log(`   └─ ${sub} ${buttonText}`);
      totalButtons += subsectionButtonCount;
    });

    if (sectionButtonCount > 0) {
      console.log(`   📌 Total buttons in section: ${sectionButtonCount}`);
    }
  });

  console.log('\n' + '═'.repeat(70));
  console.log(`\nSummary:`);
  console.log(`  Sections: ${sections.length}`);
  console.log(`  Subsections per section: ${standardSubsections.length}`);
  console.log(`  Total subsections: ${sections.length * standardSubsections.length}`);
  console.log(`  Estimated total buttons: ${totalButtons}\n`);

} catch (error) {
  console.error('Error:', error.message);
}
