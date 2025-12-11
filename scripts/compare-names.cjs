#!/usr/bin/env node

const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const path = require('path');

const supabaseUrl = 'https://supabase.urbanaqura.com';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NjQ4NzU1MjcsImV4cCI6MjA4MDQ1MTUyN30.6mj0wiHW0ljpYNIEeYG-r--577LDNbxCLj7SZOghbv0';
const supabase = createClient(supabaseUrl, supabaseKey);

async function compareNames() {
  try {
    console.log('🔍 Comparing Sidebar Names vs Database Names\n');

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
          
          let buttonText = '';
          for (let j = i; j < Math.min(i + 5, lines.length); j++) {
            const menuTextLine = lines[j];
            // Match: <span class="menu-text">{t(...) || 'Text'}</span>
            const menuTextMatch = menuTextLine.match(/class="menu-text"[^>]*>\s*\{?t\([^)]*\)\s*\|\|\s*['"]([^'"]+)['"]\s*\}?<\/span>/);
            if (menuTextMatch) {
              buttonText = menuTextMatch[1].trim();
              break;
            }
          }

          if (buttonText && currentSubsection) {
            sectionData[currentSection].subsections[currentSubsection].push({
              name: buttonText,
              handlerFunc: handlerFunc
            });
          }
        }
      }
    }

    // Get names from sidebar
    const sidebarNames = new Map();
    Object.keys(sectionData).forEach(section => {
      Object.keys(sectionData[section].subsections).forEach(subsection => {
        sectionData[section].subsections[subsection].forEach(btn => {
          sidebarNames.set(btn.name, btn.handlerFunc);
        });
      });
    });

    // Get names from database
    const { data: buttons } = await supabase
      .from('sidebar_buttons')
      .select('button_name_en, button_code')
      .order('button_name_en');

    const databaseNames = new Map(buttons.map(b => [b.button_name_en, b.button_code]));

    console.log(`📊 STATISTICS:`);
    console.log(`   Sidebar buttons: ${sidebarNames.size}`);
    console.log(`   Database buttons: ${databaseNames.size}`);
    console.log();

    // Find missing (in sidebar but not in database)
    const missing = [];
    for (const [name, func] of sidebarNames) {
      if (!databaseNames.has(name)) {
        missing.push({ name, func });
      }
    }

    missing.sort((a, b) => a.name.localeCompare(b.name));

    console.log(`❌ MISSING IN DATABASE (${missing.length}):`);
    missing.forEach((btn, i) => {
      console.log(`   ${i + 1}. "${btn.name}" (handler: ${btn.func})`);
    });

    console.log();

    // Find extra (in database but not in sidebar)
    const extra = [];
    for (const [name, code] of databaseNames) {
      if (!sidebarNames.has(name)) {
        extra.push({ name, code });
      }
    }

    extra.sort((a, b) => a.name.localeCompare(b.name));

    console.log(`✅ EXTRA IN DATABASE (${extra.length}):`);
    extra.forEach((btn, i) => {
      console.log(`   ${i + 1}. "${btn.name}" (code: ${btn.code})`);
    });

  } catch (error) {
    console.error('Error:', error.message);
  }
}

compareNames();
