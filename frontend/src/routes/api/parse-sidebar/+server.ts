import { json } from '@sveltejs/kit';
import fs from 'fs';
import path from 'path';

export async function GET() {
  try {
    const sidebarPath = path.join(
      process.cwd(),
      'src/lib/components/desktop-interface/common/Sidebar.svelte'
    );

    const content = fs.readFileSync(sidebarPath, 'utf-8');
    const lines = content.split('\n');

    let currentSection = null;
    let currentSubsection = null;
    const sectionData: Record<string, any> = {};

    // Parse line by line
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];

      // Detect section start
      const sectionMatch = line.match(/<!-- (\w+[\w\s]*) Section -->/);
      if (sectionMatch) {
        currentSection = sectionMatch[1].trim();
        sectionData[currentSection] = {
          subsections: {}
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

      // Detect buttons - match button tag with on:click handler
      if (line.includes('on:click={open') && line.includes('<button')) {
        const funcMatch = line.match(/on:click={(\w+)}/);
        if (funcMatch) {
          const handlerFunc = funcMatch[1];
          // Convert function name to button code (e.g., openCustomerMaster -> CUSTOMER_MASTER)
          let buttonCode = handlerFunc.replace(/^open/, '');
          buttonCode = buttonCode.replace(/([A-Z])/g, '_$1').replace(/^_/, '');
          buttonCode = buttonCode.toUpperCase();
          
          // Look for button text in menu-text span - search forward
          let buttonText = '';
          for (let j = i; j < Math.min(i + 10, lines.length); j++) {
            // Try to match menu-text with i18n fallback
            const match = lines[j].match(/class="menu-text"[^>]*>\{?t\(['"]([\w.]+)['"]\)\s*\|\|\s*['"]([^'"]+)['"]\}?<\/span>/);
            if (match) {
              buttonText = match[2]; // Get fallback text
              break;
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

    // Format response
    const subsectionOrder = ['Dashboard', 'Manage', 'Operations', 'Reports'];
    const sections = Object.keys(sectionData).map(sectionName => {
      const subsections = subsectionOrder.map(subName => ({
        name: subName,
        buttonCount: sectionData[sectionName].subsections[subName]?.length || 0,
        buttons: sectionData[sectionName].subsections[subName] || []
      }));

      return {
        name: sectionName,
        subsections,
        totalButtons: Object.values(sectionData[sectionName].subsections)
          .reduce((sum: number, arr: any) => sum + arr.length, 0)
      };
    });

    return json({ sections });
  } catch (error) {
    return json(
      { error: error instanceof Error ? error.message : 'Unknown error' },
      { status: 500 }
    );
  }
}
