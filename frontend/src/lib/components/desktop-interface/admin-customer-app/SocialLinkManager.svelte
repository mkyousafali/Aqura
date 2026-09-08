<script lang="ts">
	import { supabase } from '$lib/utils/supabase';
	import { onMount } from 'svelte';
	import { openWindow } from '$lib/utils/windowManagerUtils';
	import SocialLinksEditor from './SocialLinksEditor.svelte';

	interface SocialLinkRecord {
		id: string;
		branch_id: number;
		facebook: string | null;
		whatsapp: string | null;
		instagram: string | null;
		tiktok: string | null;
		snapchat: string | null;
		website: string | null;
		location_link: string | null;
		facebook_clicks: number;
		whatsapp_clicks: number;
		instagram_clicks: number;
		tiktok_clicks: number;
		snapchat_clicks: number;
		website_clicks: number;
		location_link_clicks: number;
		created_at: string;
		updated_at: string;
	}

	let branches: any[] = [];
	let socialLinksData: SocialLinkRecord[] = [];
	let selectedBranch: string = '';
	let loading = true;

	const socialPlatforms = [
		{ key: 'facebook', label: 'Facebook' },
		{ key: 'whatsapp', label: 'WhatsApp' },
		{ key: 'instagram', label: 'Instagram' },
		{ key: 'tiktok', label: 'TikTok' },
		{ key: 'snapchat', label: 'Snapchat' },
		{ key: 'website', label: 'Website' },
		{ key: 'location_link', label: 'Location' }
	];

	// Generate unique window ID using timestamp and random number
	function generateWindowId(type: string): string {
		return `${type}-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
	}

	onMount(async () => {
		await loadData();
	});

	async function loadData() {
		try {
			loading = true;

			// Load branches
			const { data: branchesData, error: branchesError } = await supabase
				.from('branches')
				.select('id, name_en, name_ar')
				.eq('is_active', true)
				.order('name_en');

			if (branchesError) throw branchesError;
			branches = branchesData || [];

			// Load all social links
			const { data: linksData, error: linksError } = await supabase
				.from('social_links')
				.select('*')
				.order('branch_id');

			if (linksError) throw linksError;
			socialLinksData = linksData || [];
		} catch (err) {
			console.error('Error loading data:', err);
		} finally {
			loading = false;
		}
	}

	function getBranchName(branchId: number): string {
		const branch = branches.find(b => b.id === branchId);
		return branch ? branch.name_en : `Branch #${branchId}`;
	}

	function openEditModal(branchId: number) {
		const windowId = generateWindowId('social-links-editor');
		
		openWindow({
			id: windowId,
			title: `Update Social Links - ${getBranchName(branchId)}`,
			component: SocialLinksEditor,
			icon: '🔗',
			width: 600,
			height: 500,
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true,
			props: {
				branchId: branchId,
				isAddMode: false,
				onSave: loadData
			}
		});
	}

	function openAddNewModal() {
		const windowId = generateWindowId('social-links-editor');
		
		openWindow({
			id: windowId,
			title: 'Add New Social Links',
			component: SocialLinksEditor,
			icon: '🔗',
			width: 600,
			height: 500,
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true,
			props: {
				branchId: null,
				isAddMode: true,
				onSave: loadData
			}
		});
	}
</script>

<div class="social-link-manager">
	<div class="manager-header">
		<h2>Social Links Manager</h2>
		<button class="add-new-btn" on:click={openAddNewModal}>+ Add New Links</button>
	</div>

	{#if loading}
		<div class="loading">Loading social links...</div>
	{:else}
		<div class="table-container">
			<table class="social-links-table">
				<thead>
					<tr>
						<th>Branch</th>
						<th>Facebook <span class="clicks-header">(Clicks)</span></th>
						<th>WhatsApp <span class="clicks-header">(Clicks)</span></th>
						<th>Instagram <span class="clicks-header">(Clicks)</span></th>
						<th>TikTok <span class="clicks-header">(Clicks)</span></th>
						<th>Snapchat <span class="clicks-header">(Clicks)</span></th>
						<th>Website <span class="clicks-header">(Clicks)</span></th>
						<th>Location <span class="clicks-header">(Clicks)</span></th>
						<th>Total Clicks</th>
						<th>Actions</th>
					</tr>
				</thead>
				<tbody>
					{#each socialLinksData as link (link.id)}
						<tr>
							<td class="branch-cell">{getBranchName(link.branch_id)}</td>
							<td class="link-cell">
								<div class="link-status">{link.facebook ? '✓' : '—'}</div>
								<div class="click-count">{link.facebook_clicks || 0}</div>
							</td>
							<td class="link-cell">
								<div class="link-status">{link.whatsapp ? '✓' : '—'}</div>
								<div class="click-count">{link.whatsapp_clicks || 0}</div>
							</td>
							<td class="link-cell">
								<div class="link-status">{link.instagram ? '✓' : '—'}</div>
								<div class="click-count">{link.instagram_clicks || 0}</div>
							</td>
							<td class="link-cell">
								<div class="link-status">{link.tiktok ? '✓' : '—'}</div>
								<div class="click-count">{link.tiktok_clicks || 0}</div>
							</td>
							<td class="link-cell">
								<div class="link-status">{link.snapchat ? '✓' : '—'}</div>
								<div class="click-count">{link.snapchat_clicks || 0}</div>
							</td>
							<td class="link-cell">
								<div class="link-status">{link.website ? '✓' : '—'}</div>
								<div class="click-count">{link.website_clicks || 0}</div>
							</td>
							<td class="link-cell">
								<div class="link-status">{link.location_link ? '✓' : '—'}</div>
								<div class="click-count">{link.location_link_clicks || 0}</div>
							</td>
							<td class="total-clicks-cell">
								<div class="total-badge">
									{link.facebook_clicks + link.whatsapp_clicks + link.instagram_clicks + link.tiktok_clicks + link.snapchat_clicks + link.website_clicks + link.location_link_clicks || 0}
								</div>
							</td>
							<td class="action-cell">
								<button class="edit-btn" on:click={() => openEditModal(link.branch_id)}>
									Update
								</button>
							</td>
						</tr>
					{/each}
				</tbody>
			</table>
		</div>

		{#if socialLinksData.length === 0}
			<p class="empty-state">No social links found. Click "Add New Links" to create one.</p>
		{/if}
	{/if}
</div>

<style>
	.social-link-manager {
		padding: 2rem;
		background: #f9fafb;
		border-radius: 8px;
	}

	.manager-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		margin-bottom: 2rem;
	}

	h2 {
		margin: 0;
		color: #111827;
		font-size: 1.5rem;
	}

	.add-new-btn {
		padding: 0.75rem 1.5rem;
		background: #10b981;
		color: white;
		border: none;
		border-radius: 4px;
		font-size: 0.875rem;
		font-weight: 500;
		cursor: pointer;
		transition: background-color 0.2s;
	}

	.add-new-btn:hover {
		background: #059669;
	}

	.loading {
		text-align: center;
		padding: 2rem;
		color: #6b7280;
	}

	.table-container {
		background: white;
		border-radius: 8px;
		overflow: auto;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
	}

	.social-links-table {
		width: 100%;
		border-collapse: collapse;
		font-size: 0.875rem;
	}

	.social-links-table thead {
		background: #f3f4f6;
		border-bottom: 2px solid #e5e7eb;
	}

	.social-links-table th {
		padding: 1rem;
		text-align: left;
		font-weight: 600;
		color: #374151;
	}

	.clicks-header {
		display: block;
		font-size: 0.75rem;
		font-weight: 400;
		color: #6b7280;
	}

	.social-links-table tbody tr {
		border-bottom: 1px solid #e5e7eb;
		transition: background-color 0.2s;
	}

	.social-links-table tbody tr:hover {
		background-color: #f9fafb;
	}

	.social-links-table td {
		padding: 1rem;
		color: #374151;
	}

	.branch-cell {
		font-weight: 500;
	}

	.link-cell {
		text-align: center;
		color: #10b981;
		font-weight: 600;
	}

	.link-status {
		font-size: 1.2rem;
		margin-bottom: 0.25rem;
	}

	.click-count {
		font-size: 0.75rem;
		color: #6b7280;
		font-weight: 400;
		background: #f3f4f6;
		padding: 0.25rem 0.5rem;
		border-radius: 3px;
		display: inline-block;
	}

	.total-clicks-cell {
		text-align: center;
		font-weight: 600;
	}

	.total-badge {
		background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
		color: white;
		padding: 0.5rem 1rem;
		border-radius: 20px;
		font-weight: 600;
		display: inline-block;
		min-width: 60px;
	}

	.action-cell {
		text-align: center;
	}

	.edit-btn {
		padding: 0.5rem 1rem;
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 4px;
		cursor: pointer;
		font-size: 0.875rem;
		font-weight: 500;
		transition: background-color 0.2s;
	}

	.edit-btn:hover {
		background: #2563eb;
	}

	.empty-state {
		padding: 3rem 1rem;
		text-align: center;
		color: #6b7280;
	}
</style>
