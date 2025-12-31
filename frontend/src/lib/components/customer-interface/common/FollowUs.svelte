<script lang="ts">
	import { supabase } from '$lib/utils/supabase';
	import { currentLocale, t } from '$lib/i18n';

	let branches: any[] = [];
	let selectedBranch: string = '';
	let loading = true;
	let socialLinks: any = null;

	const socialPlatforms = [
		{ key: 'facebook', label: 'Facebook', icon: '/icons/facebook logo.jpg' },
		{ key: 'whatsapp', label: 'WhatsApp', icon: '/icons/whatsapp logo.png' },
		{ key: 'instagram', label: 'Instagram', icon: '/icons/instagram logo.png' },
		{ key: 'tiktok', label: 'TikTok', icon: '/icons/tiktok logo.jpg' },
		{ key: 'snapchat', label: 'Snapchat', icon: '/icons/snapchat logo.png' },
		{ key: 'website', label: 'Website', icon: '/icons/logo.png' }
	];

	async function loadBranches() {
		try {
			const { data, error } = await supabase
				.from('branches')
				.select('id, name_en, name_ar')
				.eq('is_active', true)
				.order('name_en');

			if (error) throw error;
			branches = data || [];
			loading = false;
		} catch (err) {
			console.error('Error loading branches:', err);
			loading = false;
		}
	}

	async function loadSocialLinks(branchId: string) {
		if (!branchId) {
			socialLinks = null;
			return;
		}

		try {
			const { data, error } = await supabase
				.from('social_links')
				.select('*')
				.eq('branch_id', branchId)
				.single();

			if (error && error.code !== 'PGRST116') throw error; // PGRST116 = no rows
			socialLinks = data || null;
		} catch (err) {
			console.error('Error loading social links:', err);
			socialLinks = null;
		}
	}

	function handleBranchChange() {
		if (selectedBranch) {
			loadSocialLinks(selectedBranch);
		}
	}

	function getIconPath(platform: any): string {
		if (platform.icon.startsWith('/')) {
			return platform.icon;
		}
		return platform.icon;
	}

	loadBranches();

	$: locale = $currentLocale;
	$: isRTL = locale === 'ar';
</script>

<div class="follow-us-container" dir={isRTL ? 'rtl' : 'ltr'}>
	<div class="follow-us-header">
		<h2>👋 {isRTL ? 'تابعنا على وسائل التواصل' : 'Follow Us'}</h2>
		<p class="subtitle">{isRTL ? 'اختر الفرع لرؤية روابط التواصل الخاصة به' : 'Select a branch to view social media links'}</p>
	</div>

	<div class="branch-selector-wrapper">
		<div class="branch-selector">
			<select id="branch-select" bind:value={selectedBranch} on:change={handleBranchChange} disabled={loading}>
				<option value="">
					{isRTL ? '-- اختر فرعاً --' : '-- Choose Branch --'}
				</option>
				{#each branches as branch (branch.id)}
					<option value={branch.id}>{isRTL ? branch.name_ar : branch.name_en}</option>
				{/each}
			</select>
		</div>
	</div>

	{#if selectedBranch && socialLinks}
		<div class="social-links-display">
			<h3>{isRTL ? 'روابط التواصل' : 'Contact Links'}</h3>
			<div class="links-grid">
				{#each socialPlatforms as platform (platform.key)}
					{#if socialLinks[platform.key]}
						<a href={socialLinks[platform.key]} target="_blank" rel="noopener noreferrer" class="social-link">
							{#if platform.icon.startsWith('/')}
								<img src={platform.icon} alt={platform.label} class="social-icon" />
							{:else}
								<span class="social-emoji">{platform.icon}</span>
							{/if}
							<span class="social-label">{platform.label}</span>
						</a>
					{/if}
				{/each}
			</div>
		</div>
	{:else if selectedBranch && !socialLinks}
		<div class="empty-state">
			<p>{isRTL ? 'لا توجد روابط تواصل متاحة لهذا الفرع' : 'No social links available for this branch'}</p>
		</div>
	{/if}
</div>

<style>
	.follow-us-container {
		display: flex;
		flex-direction: column;
		gap: 20px;
		padding: 24px;
		background: white;
		border-radius: 12px;
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
		max-width: 600px;
		margin: 0 auto;
	}

	.follow-us-header {
		text-align: center;
		margin-bottom: 12px;
	}

	.follow-us-header h2 {
		margin: 0 0 8px 0;
		font-size: 28px;
		font-weight: 700;
		color: #1f2937;
	}

	.subtitle {
		margin: 0;
		font-size: 14px;
		color: #6b7280;
	}

	.branch-selector-wrapper {
		display: flex !important;
		flex-direction: column !important;
		gap: 0;
		width: 100%;
	}

	.branch-selector-wrapper label,
	.branch-selector-wrapper .label,
	.branch-selector-wrapper > label {
		display: none !important;
		visibility: hidden !important;
		height: 0 !important;
		margin: 0 !important;
		padding: 0 !important;
	}

	.branch-selector {
		display: flex;
		align-items: stretch;
		gap: 0;
		width: 100%;
		position: relative;
	}

	.branch-selector::before {
		content: none !important;
		display: none !important;
	}

	.branch-selector select {
		flex: 1;
		padding: 10px 12px;
		border: 2px solid #1DBC83;
		border-radius: 8px;
		font-size: 14px;
		background: white;
		cursor: pointer;
		transition: all 0.2s ease;
		width: 100%;
	}

	.branch-selector select::before {
		display: none !important;
	}

	.branch-selector select option:first-child {
		display: none;
	}

	.branch-selector select:hover:not(:disabled) {
		border-color: #1DBC83;
	}

	.branch-selector select:focus {
		outline: none;
		border-color: #1DBC83;
		box-shadow: 0 0 0 3px rgba(29, 188, 131, 0.1);
	}

	.branch-selector select:disabled {
		background-color: #f3f4f6;
		cursor: not-allowed;
		opacity: 0.6;
	}

	.social-links-display {
		display: flex;
		flex-direction: column;
		gap: 16px;
	}

	.social-links-display h3 {
		margin: 0;
		font-size: 18px;
		font-weight: 600;
		color: #1f2937;
	}

	.links-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(120px, 1fr));
		gap: 16px;
	}

	.social-link {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 8px;
		padding: 16px;
		background: #f9fafb;
		border: 2px solid #e5e7eb;
		border-radius: 8px;
		text-decoration: none;
		color: #374151;
		transition: all 0.2s ease;
		cursor: pointer;
	}

	.social-link:hover {
		background: #f3f4f6;
		border-color: #1DBC83;
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(29, 188, 131, 0.15);
	}

	.social-icon {
		width: 40px;
		height: 40px;
		object-fit: contain;
		border-radius: 6px;
	}

	.social-emoji {
		font-size: 32px;
		line-height: 1;
	}

	.social-label {
		font-size: 12px;
		font-weight: 600;
		text-align: center;
	}

	.empty-state {
		padding: 32px 16px;
		text-align: center;
		background: #f9fafb;
		border-radius: 8px;
		color: #6b7280;
	}

	[dir="rtl"] .branch-selector-wrapper {
		flex-direction: column !important;
	}

	[dir="rtl"] .branch-selector {
		flex-direction: row;
	}
</style>
