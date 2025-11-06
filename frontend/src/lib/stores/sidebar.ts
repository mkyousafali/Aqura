import { writable } from "svelte/store";

interface SidebarState {
  collapsed: boolean;
  width: number;
}

function createSidebarStore() {
  const { subscribe, set, update } = writable<SidebarState>({
    collapsed: false,
    width: 140,
  });

  return {
    subscribe,
    toggle: () =>
      update((state) => ({
        collapsed: false, // Always keep expanded
        width: 140, // Fixed width
      })),
    setCollapsed: (collapsed: boolean) =>
      update((state) => ({
        collapsed: false, // Always keep expanded
        width: 140, // Fixed width
      })),
  };
}

export const sidebar = createSidebarStore();
