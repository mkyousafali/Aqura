<script lang="ts">
	import { onMount } from 'svelte';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { supabase } from '$lib/utils/supabase';
	import { localeData } from '$lib/i18n';

	let currentUserData = null;
	let pendingBoxes = [];
	let isLoading = true;

	function getTranslation(keyPath: string): string {
		const keys = keyPath.split('.');
		let value: any = $localeData.translations;
		for (const key of keys) {
			if (value && typeof value === 'object' && key in value) {
				value = value[key];
			} else {
				return keyPath;
			}
		}
		return typeof value === 'string' ? value : keyPath;
	}

	onMount(async () => {
		currentUserData = $currentUser;
if (currentUserData) {
await loadPendingBoxes();
}
isLoading = false;
});

async function loadPendingBoxes() {
	try {
		const { data, error } = await supabase
			.from('box_operations')
			.select(`
				*,
				branches:branch_id(id, name_en, name_ar, location_en, location_ar)
			`)
			.eq('user_id', currentUserData.id)
			.eq('status', 'pending_close')
			.order('start_time', { ascending: false });

if (error) throw error;

pendingBoxes = data || [];
console.log(' Loaded pending boxes:', pendingBoxes);
} catch (error) {
console.error('Error loading pending boxes:', error);
}
}

function getBranchDisplay(branch: any): string {
	if (!branch) return '';
	
	const isArabic = $localeData.code === 'ar';
	const name = isArabic ? (branch.name_ar || branch.name_en) : branch.name_en;
	const location = isArabic ? (branch.location_ar || branch.location_en) : branch.location_en;
	
	console.log('🏢 Branch display:', { name, location, isArabic, branchName_ar: branch.name_ar, branchName_en: branch.name_en, branchLocation_ar: branch.location_ar, branchLocation_en: branch.location_en });
	
	return location ? `${name} - ${location}` : name || '';
}

function formatDate(dateString) {
if (!dateString) return '';
const date = new Date(dateString);
	const locale = $localeData.code === 'ar' ? 'ar-SA' : 'en-US';
	return date.toLocaleDateString(locale, { 
hour: '2-digit',
minute: '2-digit'
});
}

function formatCurrency(amount) {
if (amount === null || amount === undefined) return '';
	const locale = $localeData.code === 'ar' ? 'ar-SA' : 'en-US';
	return new Intl.NumberFormat(locale, {
		minimumFractionDigits: 2,
		maximumFractionDigits: 2
}).format(amount);
}
</script>

<svelte:head>
<title>POS Pending - Aqura Mobile</title>
</svelte:head>

<div class="pos-pending-page">
<div class="page-header">
<h1>📦 {getTranslation('boxOperations.posPending')}</h1>
<p>{pendingBoxes.length} {getTranslation('boxOperations.pendingBoxes')}</p>
</div>

{#if isLoading}
<div class="loading-container">
<div class="spinner"></div>
<p>{getTranslation('common.loading')}</p>
</div>
{:else if pendingBoxes.length === 0}
<div class="empty-state">
<svg width="64" height="64" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
<rect x="3" y="3" width="18" height="18" rx="2"/>
<path d="M9 9h6v6H9z"/>
</svg>
<h3>{getTranslation('boxOperations.noPendingBoxes')}</h3>
<p>{getTranslation('boxOperations.noPendingBoxesDesc')}</p>
</div>
{:else}
<div class="boxes-list">
{#each pendingBoxes as box (box.id)}
<div class="box-card">
<div class="box-header">
<div class="box-number">{getTranslation('boxOperations.box')} #{box.box_number}</div>
<div class="box-status pending">{getTranslation('boxOperations.pendingClose')}</div>
</div>

<div class="box-info">
<div class="info-row">
<span class="label">{getTranslation('common.branch')}:</span>
<span class="value">{getBranchDisplay(box.branches)}</span>
</div>
<div class="info-row">
<span class="label">{getTranslation('boxOperations.started')}:</span>
<span class="value">{formatDate(box.start_time)}</span>
</div>

{#if box.closing_details}
{@const details = typeof box.closing_details === 'string' ? JSON.parse(box.closing_details) : box.closing_details}

{#if details.total_difference !== undefined}
<div class="info-row">
<span class="label">{getTranslation('boxOperations.totalDifference')}:</span>
<span class="value" class:positive={details.total_difference > 0} class:negative={details.total_difference < 0}>
{#if $localeData.code === 'ar'}
{formatCurrency(details.total_difference)}
<img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon" />
{:else}
<img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon" />
{formatCurrency(details.total_difference)}
{/if}
</span>
</div>
{/if}
{/if}
</div>

{#if box.notes}
<div class="box-notes">
<strong>Notes:</strong> {box.notes}
</div>
{/if}
</div>
{/each}
</div>
{/if}
</div>

<style>
.pos-pending-page {
min-height: 100vh;
background: #F8FAFC;
padding: 1rem;
padding-bottom: 80px;
}

.page-header {
margin-bottom: 1.5rem;
}

.page-header h1 {
font-size: 1.5rem;
font-weight: 700;
color: #1F2937;
margin: 0 0 0.5rem 0;
}

.page-header p {
font-size: 0.875rem;
color: #6B7280;
margin: 0;
}

.loading-container {
display: flex;
flex-direction: column;
align-items: center;
justify-content: center;
padding: 3rem 1rem;
color: #6B7280;
}

.spinner {
width: 40px;
height: 40px;
border: 4px solid #E5E7EB;
border-top-color: #3B82F6;
border-radius: 50%;
animation: spin 1s linear infinite;
margin-bottom: 1rem;
}

@keyframes spin {
to { transform: rotate(360deg); }
}

.empty-state {
display: flex;
flex-direction: column;
align-items: center;
justify-content: center;
padding: 3rem 1rem;
text-align: center;
color: #9CA3AF;
}

.empty-state svg {
margin-bottom: 1rem;
opacity: 0.5;
}

.empty-state h3 {
font-size: 1.125rem;
font-weight: 600;
color: #6B7280;
margin: 0 0 0.5rem 0;
}

.empty-state p {
font-size: 0.875rem;
margin: 0;
}

.boxes-list {
display: flex;
flex-direction: column;
gap: 1rem;
}

.box-card {
background: white;
border-radius: 12px;
padding: 1rem;
box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
}

.box-header {
display: flex;
align-items: center;
justify-content: space-between;
margin-bottom: 1rem;
padding-bottom: 0.75rem;
border-bottom: 1px solid #E5E7EB;
}

.box-number {
font-size: 1.125rem;
font-weight: 700;
color: #1F2937;
}

.box-status {
padding: 0.25rem 0.75rem;
border-radius: 12px;
font-size: 0.75rem;
font-weight: 600;
}

.box-status.pending {
background: #FEF3C7;
color: #92400E;
}

.box-info {
display: flex;
flex-direction: column;
gap: 0.5rem;
}

.info-row {
display: flex;
justify-content: space-between;
font-size: 0.875rem;
}

.info-row .label {
color: #6B7280;
}

.info-row .value {
font-weight: 600;
color: #1F2937;
}

.info-row .value.positive {
color: #10B981;
}

.info-row .value.negative {
color: #EF4444;
}

.currency-icon {
width: 12.15px;
height: 12.15px;
margin-left: 0.5rem;
margin-right: 0;
vertical-align: middle;
display: inline-block;
}

:global(html[lang="ar"]) .currency-icon {
margin-left: 0;
margin-right: 0.5rem;
}

.box-notes {
margin-top: 0.75rem;
padding-top: 0.75rem;
border-top: 1px solid #E5E7EB;
font-size: 0.875rem;
color: #6B7280;
}

.box-notes strong {
color: #1F2937;
}
</style>
