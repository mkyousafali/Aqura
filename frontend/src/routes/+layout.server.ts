import type { LayoutServerLoad } from "./$types";

export const load: LayoutServerLoad = async ({ url }) => {
  // Don't redirect on server-side - let client handle authentication
  // This prevents redirect loops since auth is stored in localStorage

  return {
    pathname: url.pathname,
  };
};
