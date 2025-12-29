<script lang="ts">
	import { supabase } from '$lib/utils/supabase';
	import { currentLocale } from '$lib/i18n';

	interface Props {
		offerId?: string;
		windowId?: string;
	}

	let { offerId = '', windowId = '' }: Props = $props();

	let offer: any = null;
	let isLoading: boolean = $state(true);
	let error: string = $state('');
	let branchName = '';
	let fileExtension = '';

	// Reactive effect to load offer when offerId changes
	$effect(() => {
		console.log('🔍 offerId changed:', offerId);
		if (offerId) {
			console.log('📂 Loading offer:', offerId);
			loadOffer();
		} else {
			console.log('⚠️ offerId is empty!');
		}
	});

	async function loadOffer() {
		isLoading = true;
		error = '';
		try {
			console.log('🔄 Fetching offer with ID:', offerId);
			const { data, error: fetchError } = await supabase
				.from('view_offer')
				.select('*')
				.eq('id', offerId)
				.single();

			if (fetchError) throw fetchError;

			console.log('✅ Offer fetched:', data);
			offer = data;

			// Fetch branch name
			if (offer && offer.branch_id) {
				const { data: branchData, error: branchError } = await supabase
					.from('branches')
					.select('name_en, name_ar')
					.eq('id', offer.branch_id)
					.single();

				if (branchError) throw branchError;

				branchName = $currentLocale === 'ar' ? branchData?.name_ar : branchData?.name_en;
			}

			// Extract file extension
			if (offer && offer.file_url) {
				fileExtension = offer.file_url.split('.').pop()?.toLowerCase() || '';
			}
		} catch (err) {
			console.error('❌ Error loading offer:', err);
			error = 'Failed to load offer details';
		} finally {
			isLoading = false;
			console.log('⏹️ Loading finished. IsLoading:', isLoading);
		}
	}

	function formatDate(dateString: string) {
		const date = new Date(dateString);
		return date.toLocaleDateString($currentLocale === 'ar' ? 'ar-SA' : 'en-US');
	}

	function isImageFile(ext: string) {
		return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].includes(ext.toLowerCase());
	}

	function isVideoFile(ext: string) {
		return ['mp4', 'webm', 'ogg', 'mov', 'avi', 'mkv'].includes(ext.toLowerCase());
	}

	function isPdfFile(ext: string) {
		return ext.toLowerCase() === 'pdf';
	}

	function convertTo12Hour(time24: string): string {
		if (!time24) return '';
		const [hours, minutes] = time24.split(':');
		let hour = parseInt(hours);
		const min = minutes;
		const period = hour >= 12 ? 'PM' : 'AM';
		if (hour > 12) hour -= 12;
		if (hour === 0) hour = 12;
		return `${String(hour).padStart(2, '0')}:${min} ${period}`;
	}
</script>

<div class="open-offer-detail">
	{#if isLoading}
		<div class="loading">
			<div class="spinner"></div>
			<p>Loading offer...</p>
		</div>
	{:else if error}
		<div class="error-message">
			<p>{error}</p>
		</div>
	{:else if offer}
		<div class="offer-content">
			<div class="offer-header">
				<h1>{offer.offer_name}</h1>
				<div class="offer-meta">
					<span class="badge branch-badge">{branchName}</span>
					<span class="badge status-badge">Active</span>
				</div>
			</div>

			<div class="offer-details-grid">
				<div class="detail-item">
					<label>Start Date</label>
					<p>{formatDate(offer.start_date)}</p>
				</div>
				<div class="detail-item">
					<label>Start Time</label>
					<p>{convertTo12Hour(offer.start_time)}</p>
				</div>
				<div class="detail-item">
					<label>End Date</label>
					<p>{formatDate(offer.end_date)}</p>
				</div>
				<div class="detail-item">
					<label>End Time</label>
					<p>{convertTo12Hour(offer.end_time)}</p>
				</div>
			</div>

			<div class="offer-file-section">
				<h2>Offer File</h2>
				<div class="file-preview">
					{#if isImageFile(fileExtension)}
						<img src={offer.file_url} alt={offer.offer_name} class="preview-image" />
					{:else if isVideoFile(fileExtension)}
						<video controls class="preview-video">
							<source src={offer.file_url} type="video/{fileExtension}" />
							Your browser does not support the video tag.
						</video>
					{:else if isPdfFile(fileExtension)}
						<div class="pdf-placeholder">
							<div class="pdf-icon">📄</div>
							<p>PDF Document</p>
						</div>
					{:else}
						<div class="file-placeholder">
							<div class="file-icon">📎</div>
							<p>File (.{fileExtension})</p>
						</div>
					{/if}
				</div>
				<a href={offer.file_url} target="_blank" rel="noopener noreferrer" class="download-btn">
					💾 Download File
				</a>
			</div>

			<div class="offer-timestamps">
				<p class="text-muted">
					Created: {new Date(offer.created_at).toLocaleString($currentLocale === 'ar' ? 'ar-SA' : 'en-US')}
				</p>
				{#if offer.updated_at}
					<p class="text-muted">
						Updated: {new Date(offer.updated_at).toLocaleString($currentLocale === 'ar' ? 'ar-SA' : 'en-US')}
					</p>
				{/if}
			</div>
		</div>
	{/if}
</div>

<style>
	.open-offer-detail {
		width: 100%;
		height: 100%;
		display: flex;
		flex-direction: column;
		background: white;
		overflow-y: auto;
	}

	.loading,
	.error-message {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		height: 100%;
		padding: 2rem;
	}

	.loading {
		gap: 1rem;
	}

	.spinner {
		width: 40px;
		height: 40px;
		border: 4px solid #e5e7eb;
		border-top-color: #10b981;
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
	}

	@keyframes spin {
		to {
			transform: rotate(360deg);
		}
	}

	.error-message {
		color: #dc2626;
		font-size: 1rem;
	}

	.offer-content {
		padding: 2rem;
		max-width: 900px;
	}

	.offer-header {
		margin-bottom: 2rem;
		border-bottom: 2px solid #e5e7eb;
		padding-bottom: 1.5rem;
	}

	.offer-header h1 {
		margin: 0 0 1rem 0;
		font-size: 2rem;
		font-weight: 700;
		color: #1f2937;
	}

	.offer-meta {
		display: flex;
		gap: 0.75rem;
		flex-wrap: wrap;
	}

	.badge {
		display: inline-block;
		padding: 0.5rem 1rem;
		border-radius: 20px;
		font-size: 0.875rem;
		font-weight: 600;
	}

	.branch-badge {
		background: #dbeafe;
		color: #1e40af;
	}

	.status-badge {
		background: #dcfce7;
		color: #166534;
	}

	.offer-details-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
		gap: 1.5rem;
		margin-bottom: 2rem;
		padding: 1.5rem;
		background: #f9fafb;
		border-radius: 8px;
	}

	.detail-item label {
		display: block;
		font-size: 0.875rem;
		font-weight: 600;
		color: #6b7280;
		margin-bottom: 0.5rem;
		text-transform: uppercase;
		letter-spacing: 0.05em;
	}

	.detail-item p {
		margin: 0;
		font-size: 1.125rem;
		font-weight: 500;
		color: #1f2937;
	}

	.offer-file-section {
		margin: 2rem 0;
	}

	.offer-file-section h2 {
		font-size: 1.25rem;
		font-weight: 700;
		color: #1f2937;
		margin-bottom: 1rem;
	}

	.file-preview {
		width: 100%;
		max-height: 400px;
		margin-bottom: 1rem;
		border: 2px solid #e5e7eb;
		border-radius: 8px;
		overflow: hidden;
		display: flex;
		align-items: center;
		justify-content: center;
		background: #f9fafb;
	}

	.preview-image {
		width: 100%;
		height: 100%;
		object-fit: contain;
	}

	.preview-video {
		width: 100%;
		height: 100%;
	}

	.pdf-placeholder,
	.file-placeholder {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		width: 100%;
		height: 300px;
		gap: 1rem;
	}

	.pdf-icon,
	.file-icon {
		font-size: 4rem;
	}

	.pdf-placeholder p,
	.file-placeholder p {
		margin: 0;
		font-size: 1rem;
		color: #6b7280;
		font-weight: 500;
	}

	.download-btn {
		display: inline-block;
		padding: 0.75rem 1.5rem;
		background: linear-gradient(135deg, #10b981 0%, #059669 100%);
		color: white;
		text-decoration: none;
		border-radius: 6px;
		font-weight: 600;
		transition: all 0.2s ease;
		text-align: center;
	}

	.download-btn:hover {
		background: linear-gradient(135deg, #059669 0%, #047857 100%);
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(16, 185, 129, 0.3);
	}

	.offer-timestamps {
		margin-top: 2rem;
		padding-top: 1.5rem;
		border-top: 1px solid #e5e7eb;
	}

	.text-muted {
		margin: 0.5rem 0;
		font-size: 0.875rem;
		color: #9ca3af;
	}

	@media (max-width: 768px) {
		.offer-content {
			padding: 1.5rem;
		}

		.offer-header h1 {
			font-size: 1.5rem;
		}

		.offer-details-grid {
			grid-template-columns: 1fr;
		}

		.file-preview {
			max-height: 300px;
		}
	}
</style>
