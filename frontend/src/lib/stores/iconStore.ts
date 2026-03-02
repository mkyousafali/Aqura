import { writable, derived, get } from 'svelte/store';

export interface AppIcon {
    id: string;
    name: string;
    icon_key: string;
    category: string;
    storage_path: string;
    mime_type: string | null;
    file_size: number;
    description: string | null;
    is_active: boolean;
    created_at: string;
    updated_at: string;
    url?: string; // resolved public URL
}

// Stores
const icons = writable<AppIcon[]>([]);
const loading = writable(false);
const loaded = writable(false);
const error = writable<string | null>(null);

let supabaseClient: any = null;
let supabaseUrl = '';

async function getSupabase() {
    if (!supabaseClient) {
        const mod = await import('$lib/utils/supabase');
        supabaseClient = mod.supabase;
        supabaseUrl = mod.supabaseUrl || import.meta.env.VITE_SUPABASE_URL || 'https://supabase.urbanaqura.com';
    }
    return supabaseClient;
}

let cacheBuster = Date.now();

function buildIconUrl(storagePath: string): string {
    const url = supabaseUrl || import.meta.env.VITE_SUPABASE_URL || 'https://supabase.urbanaqura.com';
    return `${url}/storage/v1/object/public/app-icons/${encodeURIComponent(storagePath)}?t=${cacheBuster}`;
}

/**
 * Load all icons from the database (cached after first load)
 */
export async function loadIcons(force = false): Promise<void> {
    if (get(loaded) && !force) return;
    
    loading.set(true);
    error.set(null);
    
    try {
        const supabase = await getSupabase();
        const { data, error: err } = await supabase.rpc('get_app_icons');
        
        if (err) throw err;
        
        // Bust cache on every reload
        cacheBuster = Date.now();
        
        const iconsWithUrls = (data || []).map((icon: AppIcon) => ({
            ...icon,
            url: buildIconUrl(icon.storage_path)
        }));
        
        icons.set(iconsWithUrls);
        loaded.set(true);
    } catch (e: any) {
        error.set(e.message || 'Failed to load icons');
        console.error('Failed to load app icons:', e);
    } finally {
        loading.set(false);
    }
}

/**
 * Get an icon URL by its key. Falls back to the old static path if not found.
 */
export function getIconUrl(iconKey: string, fallbackStaticPath?: string): string {
    const allIcons = get(icons);
    const icon = allIcons.find(i => i.icon_key === iconKey);
    
    if (icon?.url) return icon.url;
    
    // Fallback to static path
    if (fallbackStaticPath) return fallbackStaticPath;
    
    // Build a default URL assuming the icon exists in storage
    return buildIconUrl(iconKey);
}

/**
 * Reactive derived store: map of icon_key -> url for quick access
 */
export const iconUrlMap = derived(icons, ($icons) => {
    const map: Record<string, string> = {};
    for (const icon of $icons) {
        map[icon.icon_key] = icon.url || buildIconUrl(icon.storage_path);
    }
    return map;
});

/**
 * Get icons filtered by category
 */
export const iconsByCategory = derived(icons, ($icons) => {
    const map: Record<string, AppIcon[]> = {};
    for (const icon of $icons) {
        if (!map[icon.category]) map[icon.category] = [];
        map[icon.category].push(icon);
    }
    return map;
});

// Re-export stores
export { icons, loading, loaded, error };
