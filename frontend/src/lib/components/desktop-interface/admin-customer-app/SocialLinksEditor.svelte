<script lang="ts">
	import { supabase } from '$lib/utils/supabase';
	import { windowManager } from '$lib/stores/windowManager';
	import { onMount } from 'svelte';

	// Props passed from window manager
	export let windowId: string;
	export let branchId: number | null = null;
	export let isAddMode: boolean = false;
	export let onSave: (() => void) | undefined = undefined;

	let branches: any[] = [];
	let saving = false;
	let selectedBranch: string = branchId?.toString() || '';

	let editingLinks = {
		facebook: '',
		whatsapp: '',
		instagram: '',
		tiktok: '',
		snapchat: '',
		website: '',
		location_link: ''
	};

	const socialPlatforms = [
		{ key: 'facebook', label: 'Facebook', icon: '/icons/facebook logo.jpg' },
		{ key: 'whatsapp', label: 'WhatsApp', icon: '/icons/whatsapp logo.png' },
		{ key: 'instagram', label: 'Instagram', icon: '/icons/instagram logo.png' },
		{ key: 'tiktok', label: 'TikTok', icon: '/icons/tiktok logo.jpg' },
		{ key: 'snapchat', label: 'Snapchat', icon: '/icons/snapchat logo.png' },
		{ key: 'website', label: 'Website', icon: null },
		{ key: 'location_link', label: 'Location', icon: '/icons/map icon.png' }
	];

	// React to selected branch changes to load existing links
	$: if (selectedBranch && isAddMode) {
		loadExistingLinks(parseInt(selectedBranch));
	}

	async function loadExistingLinks(branchId: number) {
		try {
			const { data, error } = await supabase
				.from('social_links')
				.select('*')
				.eq('branch_id', branchId)
				.single();

			if (error && error.code !== 'PGRST116') throw error;

			if (data) {
				editingLinks = {
					facebook: data.facebook || '',
					whatsapp: data.whatsapp || '',
					instagram: data.instagram || '',
					tiktok: data.tiktok || '',
					snapchat: data.snapchat || '',
					website: data.website || '',
					location_link: data.location_link || ''
				};
			} else {
				// Reset to empty if no links found for this branch
				editingLinks = {
					facebook: '',
					whatsapp: '',
					instagram: '',
					tiktok: '',
					snapchat: '',
					website: '',
					location_link: ''
				};
			}
		} catch (err) {
			console.error('Error loading existing links:', err);
		}
	}

	onMount(async () => {
		try {
			// Load branches
			const { data: branchesData, error: branchesError } = await supabase
				.from('branches')
				.select('id, name_en, name_ar')
				.eq('is_active', true)
				.order('name_en');

			if (branchesError) throw branchesError;
			branches = branchesData || [];

			// If editing existing social links, load them
			if (branchId && !isAddMode) {
				const { data, error } = await supabase
					.from('social_links')
					.select('*')
					.eq('branch_id', branchId)
					.single();

				if (error && error.code !== 'PGRST116') throw error;

				if (data) {
					editingLinks = {
						facebook: data.facebook || '',
						whatsapp: data.whatsapp || '',
						instagram: data.instagram || '',
						tiktok: data.tiktok || '',
						snapchat: data.snapchat || '',
						website: data.website || '',
						location_link: data.location_link || ''
					};
				}
			}
		} catch (err) {
			console.error('Error loading data:', err);
		}
	});

	function getBranchName(branchIdParam: string): string {
		const branch = branches.find(b => b.id === parseInt(branchIdParam));
		return branch ? branch.name_en : `Branch #${branchIdParam}`;
	}

	async function saveLinks() {
		if (!selectedBranch) {
			alert('Please select a branch');
			return;
		}

		saving = true;
		try {
			const { data, error } = await supabase.rpc('upsert_social_links', {
				_branch_id: parseInt(selectedBranch),
				_facebook: editingLinks.facebook || null,
				_whatsapp: editingLinks.whatsapp || null,
				_instagram: editingLinks.instagram || null,
				_tiktok: editingLinks.tiktok || null,
				_snapchat: editingLinks.snapchat || null,
				_website: editingLinks.website || null,
				_location_link: editingLinks.location_link || null
			});

			if (error) throw error;
			alert('Social links saved successfully!');
			
			// Call callback if provided
			if (onSave) onSave();
			
			// Close the window via window manager
			windowManager.closeWindow(windowId);
		} catch (err) {
			console.error('Error saving links:', err);
			alert('Error saving links: ' + (err.message || 'Unknown error'));
		} finally {
			saving = false;
		}
	}

	function closeWindow() {
		windowManager.closeWindow(windowId);
	}
</script>

<div class="editor-window">
	<div class="window-header">
		<h2>{isAddMode ? 'Add New Social Links' : `Update Social Links - ${getBranchName(selectedBranch)}`}</h2>
	</div>

	<div class="window-body">
		{#if isAddMode}
			<div class="branch-selector-group">
				<label for="branch-select">Select Branch:</label>
				<select id="branch-select" bind:value={selectedBranch}>
					<option value="">-- Choose Branch --</option>
					{#each branches as branch (branch.id)}
						<option value={branch.id}>{branch.name_en}</option>
					{/each}
				</select>
			</div>
		{/if}

		<div class="form-grid">
			{#each socialPlatforms as platform}
				<div class="form-group">
					<div class="label-with-icon">
						{#if platform.icon}
							<img src={platform.icon} alt={platform.label} class="platform-icon" />
						{:else}
							<span class="icon-placeholder">🌐</span>
						{/if}
						<label for={platform.key}>{platform.label}</label>
					</div>
					<input
						id={platform.key}
						type="url"
						placeholder={`Enter ${platform.label} URL`}
						bind:value={editingLinks[platform.key]}
					/>
				</div>
			{/each}
		</div>
	</div>

	<div class="window-footer">
		<button class="cancel-btn" on:click={closeWindow} disabled={saving}>
			Cancel
		</button>
		<button class="save-btn" on:click={saveLinks} disabled={saving || (isAddMode && !selectedBranch)}>
			{saving ? 'Saving...' : 'Save Links'}
		</button>
	</div>
</div>

<style>
	.editor-window {
		display: flex;
		flex-direction: column;
		height: 100%;
		background: white;
		overflow: hidden;
		padding: 1rem;
	}

	.window-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		margin-bottom: 1.5rem;
		border-bottom: 1px solid #e5e7eb;
		padding-bottom: 1rem;
	}

	.window-header h2 {
		margin: 0;
		color: #111827;
		font-size: 1.25rem;
	}

	.window-body {
		flex: 1;
		overflow-y: auto;
		margin-bottom: 1rem;
	}

	.branch-selector-group {
		margin-bottom: 1.5rem;
	}

	.branch-selector-group label {
		display: block;
		margin-bottom: 0.5rem;
		font-weight: 600;
		color: #374151;
	}

	.branch-selector-group select {
		width: 100%;
		padding: 0.5rem;
		border: 1px solid #d1d5db;
		border-radius: 0.375rem;
		font-size: 1rem;
	}

	.form-grid {
		display: grid;
		grid-template-columns: 1fr;
		gap: 1rem;
	}

	.form-group {
		display: flex;
		flex-direction: column;
	}

	.label-with-icon {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		margin-bottom: 0.5rem;
	}

	.platform-icon {
		width: 28px;
		height: 28px;
		object-fit: contain;
		border-radius: 4px;
	}

	.icon-placeholder {
		font-size: 1.5rem;
		width: 28px;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.form-group label {
		margin: 0;
		font-weight: 600;
		color: #374151;
	}

	.form-group input {
		padding: 0.5rem;
		border: 1px solid #d1d5db;
		border-radius: 0.375rem;
		font-size: 1rem;
	}

	.form-group input:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.window-footer {
		display: flex;
		gap: 0.5rem;
		justify-content: flex-end;
		border-top: 1px solid #e5e7eb;
		padding-top: 1rem;
	}

	.cancel-btn,
	.save-btn {
		padding: 0.5rem 1rem;
		border-radius: 0.375rem;
		font-weight: 600;
		cursor: pointer;
		border: none;
		font-size: 0.95rem;
		transition: all 0.2s;
	}

	.cancel-btn {
		background: #e5e7eb;
		color: #374151;
	}

	.cancel-btn:hover:not(:disabled) {
		background: #d1d5db;
	}

	.save-btn {
		background: #3b82f6;
		color: white;
	}

	.save-btn:hover:not(:disabled) {
		background: #2563eb;
	}

	.cancel-btn:disabled,
	.save-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}
</style>
