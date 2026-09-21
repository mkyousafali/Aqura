<script lang="ts">
	// Searchable single-user select used by the ERP Entry Task flow: the Default Entry Task Users
	// tab (App Permissions) and the Send popup in ERP Ledgers. Purely presentational -- the parent
	// loads the users (see $lib/utils/entryTaskUsers) and owns `value`; picking here never writes
	// anywhere by itself.
	import { currentLocale } from '$lib/i18n';
	import { userDisplayName, type SelectableUser } from '$lib/utils/entryTaskUsers';

	export let users: SelectableUser[] = [];
	export let value: string | null = null;
	export let disabled = false;
	export let loading = false;
	export let placeholder = 'Search and select a user';
	export let inputId = '';

	const MAX_RESULTS = 50;

	$: isArabic = $currentLocale === 'ar';
	$: selected = value ? users.find((u) => u.id === value) || null : null;

	let search = '';
	let typed = false;
	let open = false;

	// Show the chosen user's name in the box whenever the selection (or the loaded list) changes.
	// Typing does not touch `value`, so this never fights the user's keystrokes.
	$: syncText(selected, isArabic);
	function syncText(user: SelectableUser | null, arabic: boolean) {
		search = user ? userDisplayName(user, arabic) : '';
		typed = false;
	}

	$: query = search.trim().toLowerCase();
	$: filtered = typed && query
		? users.filter(
				(u) =>
					(u.name_en || '').toLowerCase().includes(query) ||
					(u.name_ar || '').toLowerCase().includes(query) ||
					(u.username || '').toLowerCase().includes(query)
			)
		: users;

	function onFocus(e: FocusEvent) {
		open = true;
		(e.currentTarget as HTMLInputElement).select();
	}

	function onInput() {
		typed = true;
		open = true;
	}

	// Delayed so a click on an option (which also blurs the input) still registers first.
	function onBlur() {
		setTimeout(() => {
			open = false;
			syncText(selected, isArabic);
		}, 150);
	}

	function pick(user: SelectableUser) {
		value = user.id;
		open = false;
		syncText(user, isArabic);
	}

	function clear() {
		value = null;
		search = '';
		typed = false;
	}
</script>

<div class="picker" dir={isArabic ? 'rtl' : 'ltr'}>
	<div class="input-row">
		<input
			id={inputId || undefined}
			type="text"
			autocomplete="off"
			placeholder={loading ? 'Loading users...' : placeholder}
			bind:value={search}
			on:focus={onFocus}
			on:input={onInput}
			on:blur={onBlur}
			disabled={disabled || loading}
		/>
		{#if value && !disabled}
			<button type="button" class="clear-btn" title="Clear" on:mousedown|preventDefault={clear}>✕</button>
		{/if}
	</div>

	{#if open && !disabled && !loading}
		<div class="dropdown">
			{#if filtered.length === 0}
				<div class="empty">No users found</div>
			{:else}
				{#each filtered.slice(0, MAX_RESULTS) as user (user.id)}
					<button
						type="button"
						class="option"
						class:active={user.id === value}
						on:mousedown|preventDefault={() => pick(user)}
					>
						<span class="name">{userDisplayName(user, isArabic)}</span>
						<span class="meta">{user.username}</span>
					</button>
				{/each}
				{#if filtered.length > MAX_RESULTS}
					<div class="more">Keep typing to narrow the results ({filtered.length} matches)</div>
				{/if}
			{/if}
		</div>
	{/if}
</div>

<style>
	.picker { position: relative; width: 100%; }
	.input-row { position: relative; display: flex; align-items: center; }
	.input-row input {
		width: 100%;
		padding: 0.5rem 2rem 0.5rem 0.7rem;
		border-radius: 8px;
		border: 1px solid rgba(252, 165, 165, 0.7);
		font-size: 0.85rem;
		color: #7f1d1d;
		background: #fff;
	}
	.input-row input:focus { outline: none; border-color: #ef4444; }
	.input-row input:disabled { background: #fef2f2; cursor: not-allowed; }
	.clear-btn {
		position: absolute;
		right: 0.4rem;
		border: none;
		background: none;
		color: #b91c1c;
		cursor: pointer;
		font-size: 0.8rem;
		padding: 0.2rem 0.35rem;
	}
	.dropdown {
		position: absolute;
		top: calc(100% + 4px);
		left: 0;
		right: 0;
		max-height: 220px;
		overflow-y: auto;
		background: #fff;
		border: 1px solid rgba(252, 165, 165, 0.8);
		border-radius: 10px;
		box-shadow: 0 10px 30px rgba(127, 29, 29, 0.18);
		z-index: 30;
	}
	.option {
		display: flex;
		flex-direction: column;
		align-items: flex-start;
		width: 100%;
		padding: 0.5rem 0.75rem;
		border: none;
		border-bottom: 1px solid rgba(254, 202, 202, 0.5);
		background: none;
		cursor: pointer;
		text-align: start;
	}
	.option:hover, .option.active { background: rgba(254, 226, 226, 0.6); }
	.name { font-size: 0.82rem; font-weight: 600; color: #7f1d1d; }
	.meta { font-size: 0.68rem; color: #b91c1c; opacity: 0.8; }
	.empty, .more { padding: 0.5rem 0.75rem; font-size: 0.75rem; color: #b91c1c; opacity: 0.8; }
</style>
