import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import fs from 'fs';
import path from 'path';
import { supabase } from '$lib/utils/supabase';

export const GET: RequestHandler = async ({ url }) => {
  try {
    // Get user ID from query parameter
    const userId = url.searchParams.get('userId');
    let allowedButtonCodes: Set<string> | null = null;

    // If user ID is provided, get their button permissions
    if (userId) {
      try {
        // Fetch user's button permissions
        const { data: permissions, error } = await supabase
          .from('button_permissions')
          .select('button_code')
          .eq('user_id', userId)
          .eq('is_enabled', true);

        if (error) {
          console.error('Error fetching permissions:', error);
        } else if (permissions && permissions.length > 0) {
          // Create a set of allowed button codes
          allowedButtonCodes = new Set(permissions.map(p => p.button_code));
        }
      } catch (authError) {
        // If auth fails, continue without filtering
        console.error('Error fetching button permissions:', authError);
      }
    }

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
      const line = lines[i].trim();

      // Detect section start - e.g., "<!-- Delivery Section -->"
      const sectionMatch = content.substring(content.indexOf(lines[i])).match(/<!-- (\w+[\w\s]*) Section -->/);
      if (line.match(/<!-- (\w+[\w\s]*) Section -->/)) {
        const sectionRegex = line.match(/<!-- (\w+[\w\s]*) Section -->/);
        if (sectionRegex) {
          currentSection = sectionRegex[1].trim();
          sectionData[currentSection] = {
            subsections: {}
          };
        }
        continue;
      }

      if (!currentSection) continue;

      // Detect subsection headers - look for title="Dashboard|Manage|Operations|Reports"
      if (line.includes('title="') && (line.includes('Dashboard') || line.includes('Manage') || line.includes('Operations') || line.includes('Reports'))) {
        const subsectionMatch = line.match(/title="(Dashboard|Manage|Operations|Reports)"/);
        if (subsectionMatch) {
          currentSubsection = subsectionMatch[1];
          if (!sectionData[currentSection].subsections[currentSubsection]) {
            sectionData[currentSection].subsections[currentSubsection] = [];
          }
        }
        continue;
      }

      // Detect actual menu buttons with on:click={open...}
      // These are inside submenu-subitem-container divs with on:click handlers
      if (line.includes('on:click={open') && line.includes('<button')) {
        const funcMatch = line.match(/on:click={(\w+)}/);
        if (funcMatch) {
          const handlerFunc = funcMatch[1];
          
          // Convert function name to button code (e.g., openCustomerMaster -> CUSTOMER_MASTER)
          let buttonCode = handlerFunc.replace(/^open/, '');
          buttonCode = buttonCode.replace(/([A-Z])/g, '_$1').replace(/^_/, '');
          buttonCode = buttonCode.toUpperCase();
          
          // Look for button text in next 15 lines (more generous search)
          let buttonText = '';
          for (let j = i; j < Math.min(i + 15, lines.length); j++) {
            const searchLine = lines[j];
            
            // Match patterns like:
            // {t('admin.customerMaster') || 'Customer Master'}
            // {t('key') || 'Fallback'}
            // 'Plain Text'
            const match1 = searchLine.match(/\{t\(['"]([\w.]+)['"]\)\s*\|\|\s*['"]([^'"]+)['"]\}/);
            if (match1) {
              buttonText = match1[2]; // Get fallback text
              break;
            }
            
            // Also try matching just the plain text in menu-text span
            const match2 = searchLine.match(/class="menu-text"[^>]*>([^<{]+)<\/span>/);
            if (match2) {
              const text = match2[1].trim();
              if (text && !text.includes('{')) {
                buttonText = text;
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

    // Filter buttons if user has permissions set
    if (allowedButtonCodes !== null) {
      Object.keys(sectionData).forEach(sectionName => {
        Object.keys(sectionData[sectionName].subsections).forEach(subsectionName => {
          sectionData[sectionName].subsections[subsectionName] = 
            sectionData[sectionName].subsections[subsectionName].filter((btn: any) =>
              allowedButtonCodes!.has(btn.code)
            );
        });
      });
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
