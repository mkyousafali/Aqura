import { writable, derived, get } from 'svelte/store';
import { supabase } from '$lib/utils/supabase';

export interface FavoriteButton {
	button_code: string;
	button_name_en: string;
	icon: string;
	order?: number;  // Display order for drag-and-drop reordering (0-based index)
}

interface FavoritesState {
	favorites: FavoriteButton[];
	loading: boolean;
	loaded: boolean;
	saving: boolean;
	error: string | null;
	rowId: string | null;
}

function createFavoritesStore() {
	const { subscribe, set, update } = writable<FavoritesState>({
		favorites: [],
		loading: false,
		loaded: false,
		saving: false,
		error: null,
		rowId: null
	});

	let currentUserId: string | null = null;
	let currentEmployeeId: string | null = null;

	return {
		subscribe,

		/** Load favorites from DB for the current user */
		async load(userId: string, employeeId?: string | null) {
			currentUserId = userId;
			currentEmployeeId = employeeId || null;

			update(s => ({ ...s, loading: true, error: null }));

			try {
				const { data, error } = await supabase
					.from('user_favorite_buttons')
					.select('id, favorite_config')
					.eq('user_id', userId)
					.maybeSingle();

				if (error) {
					console.error('❌ [Favorites] Error loading:', error);
					update(s => ({ ...s, loading: false, loaded: true, error: error.message }));
					return;
				}

				let favorites: FavoriteButton[] = data?.favorite_config || [];
				
				// Ensure all favorites have order property (for backward compatibility)
				favorites = favorites.map((fav, index) => ({
					...fav,
					order: fav.order ?? index
				}));

				const rowId = data?.id || null;

				update(s => ({
					...s,
					favorites,
					rowId,
					loading: false,
					loaded: true,
					error: null
				}));

				console.log('✅ [Favorites] Loaded', favorites.length, 'favorites');
			} catch (err: any) {
				console.error('❌ [Favorites] Error loading:', err);
				update(s => ({ ...s, loading: false, loaded: true, error: err.message }));
			}
		},

		/** Save favorites to DB (upsert — one row per user) */
		async save(favorites: FavoriteButton[]) {
			if (!currentUserId) return;

			update(s => ({ ...s, saving: true, error: null }));

			try {
				const state = get({ subscribe });
				const rowId = state.rowId || `fv${Date.now()}`;

				// Ensure all favorites have order property
				const favoritesWithOrder = favorites.map((fav, index) => ({
					...fav,
					order: fav.order ?? index
				}));

				const { error } = await supabase
					.from('user_favorite_buttons')
					.upsert({
						id: rowId,
						user_id: currentUserId,
						favorite_config: favoritesWithOrder,
						updated_at: new Date().toISOString()
					}, {
						onConflict: 'user_id'
					});

				if (error) {
					console.error('❌ [Favorites] Error saving:', error);
					update(s => ({ ...s, saving: false, error: error.message }));
					return;
				}

				update(s => ({
					...s,
					favorites: favoritesWithOrder,
					rowId,
					saving: false,
					error: null
				}));

				console.log('✅ [Favorites] Saved', favoritesWithOrder.length, 'favorites');
			} catch (err: any) {
				console.error('❌ [Favorites] Error saving:', err);
				update(s => ({ ...s, saving: false, error: err.message }));
			}
		},

		/** Reorder favorites by moving an item from one index to another */
		async reorder(fromIndex: number, toIndex: number) {
			const state = get({ subscribe });
			const favorites = [...state.favorites];

			// Validate indices
			if (fromIndex < 0 || fromIndex >= favorites.length || toIndex < 0 || toIndex >= favorites.length) {
				console.warn('❌ [Favorites] Invalid reorder indices:', { fromIndex, toIndex });
				return;
			}

			// Move item
			const [movedItem] = favorites.splice(fromIndex, 1);
			favorites.splice(toIndex, 0, movedItem);

			// Update order property for all items
			const reorderedFavorites = favorites.map((fav, index) => ({
				...fav,
				order: index
			}));

			// Save to DB
			await this.save(reorderedFavorites);
		},

		/** Check if a button_code is in favorites */
		isFavorite(buttonCode: string): boolean {
			const state = get({ subscribe });
			return state.favorites.some(f => f.button_code === buttonCode);
		},

		/** Reset store */
		reset() {
			currentUserId = null;
			currentEmployeeId = null;
			set({
				favorites: [],
				loading: false,
				loaded: false,
				saving: false,
				error: null,
				rowId: null
			});
		}
	};
}

export const favoritesStore = createFavoritesStore();

/** Derived store: just the favorite button codes as a Set for quick lookup */
export const favoriteButtonCodes = derived(
	{ subscribe: favoritesStore.subscribe },
	($state) => new Set($state.favorites.map(f => f.button_code))
);

/** Store for managing the manage favorites panel visibility */
export const favoritesPanelOpen = writable(false);
