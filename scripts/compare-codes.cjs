#!/usr/bin/env node

const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const path = require('path');

const supabaseUrl = 'https://supabase.urbanaqura.com';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NjQ4NzU1MjcsImV4cCI6MjA4MDQ1MTUyN30.6mj0wiHW0ljpYNIEeYG-r--577LDNbxCLj7SZOghbv0';
const supabase = createClient(supabaseUrl, supabaseKey);

async function compareCodes() {
  try {
    console.log('🔍 Comparing Sidebar Codes vs Database Codes\n');

    // Extract from sidebar
    const sidebarPath = path.join(__dirname, '../frontend/src/lib/components/desktop-interface/common/Sidebar.svelte');
    const content = fs.readFileSync(sidebarPath, 'utf-8');
    const lines = content.split('\n');

    let currentSection = null;
    let currentSubsection = null;
    const sectionData = {};

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      const trimmed = line.trim();

      const sectionMatch = line.match(/<!-- (\w+[\w\s]*) Section -->/);
      if (sectionMatch) {
        currentSection = sectionMatch[1];
        sectionData[currentSection] = { subsections: {} };
        continue;
      }

      if (!currentSection) continue;

      const subsectionMatch = line.match(/title="(Dashboard|Manage|Operations|Reports)"/);
      if (subsectionMatch) {
        currentSubsection = subsectionMatch[1];
        if (!sectionData[currentSection].subsections[currentSubsection]) {
          sectionData[currentSection].subsections[currentSubsection] = [];
        }
        continue;
      }

      if (trimmed.startsWith('<button') && trimmed.includes('on:click={open')) {
        const funcMatch = trimmed.match(/on:click={(\w+)}/);
        if (funcMatch) {
          const handlerFunc = funcMatch[1];
          let buttonCode = handlerFunc.replace(/^open/, '');
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
              name: buttonText
            });
          }
        }
      }
    }

    // Get codes from sidebar
    const sidebarCodes = new Set();
    Object.keys(sectionData).forEach(section => {
      Object.keys(sectionData[section].subsections).forEach(subsection => {
        sectionData[section].subsections[subsection].forEach(btn => {
          sidebarCodes.add(btn.code);
        });
      });
    });

    // Get codes from database
    const { data: buttons } = await supabase
      .from('sidebar_buttons')
      .select('button_code')
      .order('button_code');

    const databaseCodes = new Set(buttons.map(b => b.button_code));

    console.log(`📊 STATISTICS:`);
    console.log(`   Sidebar buttons: ${sidebarCodes.size}`);
    console.log(`   Database buttons: ${databaseCodes.size}`);
    console.log();

    // Find missing (in sidebar but not in database)
    const missing = Array.from(sidebarCodes).filter(code => !databaseCodes.has(code)).sort();
    
    // Find extra (in database but not in sidebar)
    const extra = Array.from(databaseCodes).filter(code => !sidebarCodes.has(code)).sort();

    console.log(`❌ MISSING IN DATABASE (${missing.length}):`);
    missing.forEach((code, i) => {
      console.log(`   ${i + 1}. ${code}`);
    });

    console.log();
    console.log(`✅ EXTRA IN DATABASE (${extra.length}):`);
    extra.forEach((code, i) => {
      console.log(`   ${i + 1}. ${code}`);
    });

  } catch (error) {
    console.error('Error:', error.message);
  }
}

compareCodes();
