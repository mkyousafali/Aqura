import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { supabase } from '$lib/utils/supabase';

export const GET: RequestHandler = async ({ url }) => {
  try {
    // Get user ID from query parameter
    const userId = url.searchParams.get('userId');

    // Fetch all buttons from the database with section and subsection info
    const { data: allButtons, error: buttonsError } = await supabase
      .from('sidebar_buttons')
      .select(`
        id,
        button_code,
        button_name_en,
        button_main_sections!inner(section_name_en),
        button_sub_sections!inner(subsection_name_en)
      `)
      .order('button_code', { ascending: true });

    if (buttonsError) {
      console.error('Error fetching buttons:', buttonsError);
      throw new Error('Failed to fetch buttons from database');
    }

    // If user ID is provided, get their button permissions
    let allowedButtonCodes: Set<string> | null = null;
    if (userId) {
      try {
        const { data: permissions, error } = await supabase
          .from('button_permissions')
          .select('button_code')
          .eq('user_id', userId)
          .eq('is_enabled', true);

        if (error) {
          console.error('Error fetching permissions:', error);
        } else if (permissions && permissions.length > 0) {
          allowedButtonCodes = new Set(permissions.map(p => p.button_code));
        }
      } catch (authError) {
        console.error('Error fetching button permissions:', authError);
      }
    }

    // Organize buttons by section and subsection
    const sectionData: Record<string, any> = {};

    // Filter buttons based on permissions if userId provided
    const buttons = allowedButtonCodes 
      ? allButtons?.filter(btn => allowedButtonCodes.has(btn.button_code))
      : allButtons;

    // Group buttons by section and subsection
    buttons?.forEach(button => {
      const section = button.button_main_sections?.section_name_en || 'Other';
      const subsection = button.button_sub_sections?.subsection_name_en || 'Dashboard';

      if (!sectionData[section]) {
        sectionData[section] = {
          subsections: {}
        };
      }

      if (!sectionData[section].subsections[subsection]) {
        sectionData[section].subsections[subsection] = [];
      }

      sectionData[section].subsections[subsection].push({
        code: button.button_code,
        name: button.button_name_en,
        id: button.id
      });
    });

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
