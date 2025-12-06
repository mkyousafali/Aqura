<script lang="ts">
	import { onMount } from 'svelte';
	
	let videoSlots = Array.from({ length: 6 }, (_, i) => ({
		slot_number: i + 1,
		id: null,
		title_en: '',
		title_ar: '',
		description_en: '',
		description_ar: '',
		file_url: '',
		file_size: 0,
		duration: 0,
		is_active: false,
		is_infinite: true,
		expiry_date: '',
		created_at: null,
		loading: false
	}));

	let uploading = false;
	let currentSlot = null;
	let showPreview = false;
	let previewUrl = '';
	let previewTitle = '';

	onMount(async () => {
		await loadVideoSlots();
	});

	async function loadVideoSlots() {
		try {
			const { supabase } = await import('$lib/utils/supabase');
			const { data, error } = await supabase
				.from('customer_app_media')
				.select('*')
				.eq('media_type', 'video')
				.order('slot_number', { ascending: true });

			if (error) throw error;

			if (data) {
				data.forEach(item => {
					const index = item.slot_number - 1;
					if (index >= 0 && index < 6) {
						videoSlots[index] = {
							...videoSlots[index],
							...item,
							expiry_date: item.expiry_date ? new Date(item.expiry_date).toISOString().slice(0, 16) : ''
						};
					}
				});
				videoSlots = [...videoSlots];
			}
		} catch (error) {
			console.error('Error loading video slots:', error);
			alert('Failed to load video slots');
		}
	}

	async function handleFileUpload(event, slotNumber) {
		const file = event.target.files?.[0];
		if (!file) return;

		// Validate file type
		if (!file.type.startsWith('video/')) {
			alert('Please select a video file (MP4, WebM, MOV)');
			return;
		}

		// Validate file size (50MB limit)
		if (file.size > 50 * 1024 * 1024) {
			alert('Video file size must be less than 50MB');
			return;
		}

		const slotIndex = slotNumber - 1;
		videoSlots[slotIndex].loading = true;
		videoSlots = [...videoSlots];

		try {
			const { supabase } = await import('$lib/utils/supabase');
			
			console.log('📹 File details:', {
				name: file.name,
				type: file.type,
				size: file.size
			});
			
			// Upload file to storage using admin client (bypasses RLS)
			const timestamp = Date.now();
			const fileName = file.name.replace(/[^a-zA-Z0-9.-]/g, '_');
			const filePath = `videos/slot-${slotNumber}/${timestamp}-${fileName}`;

			console.log('📤 Uploading to path:', filePath);

			// Upload with upsert option to overwrite if exists
			const { data: uploadData, error: uploadError } = await supabase.storage
				.from('customer-app-media')
				.upload(filePath, file, {
					cacheControl: '3600',
					upsert: true,
					contentType: file.type || 'video/mp4'
				});

			if (uploadError) {
				console.error('Upload error details:', uploadError);
				throw uploadError;
			}

			// Get public URL
			const { data: urlData } = supabase.storage
				.from('customer-app-media')
				.getPublicUrl(filePath);

			// Get video duration
			const duration = await getVideoDuration(file);

			videoSlots[slotIndex].file_url = urlData.publicUrl;
			videoSlots[slotIndex].file_size = file.size;
			videoSlots[slotIndex].duration = duration;
			videoSlots = [...videoSlots];

		} catch (error) {
			console.error('Error uploading video:', error);
			console.error('Error details:', JSON.stringify(error, null, 2));
			alert('Failed to upload video: ' + (error.message || error.error || JSON.stringify(error)));
		} finally {
			videoSlots[slotIndex].loading = false;
			videoSlots = [...videoSlots];
		}
	}

	async function getVideoDuration(file): Promise<number> {
		return new Promise((resolve) => {
			const video = document.createElement('video');
			video.preload = 'metadata';
			video.onloadedmetadata = () => {
				window.URL.revokeObjectURL(video.src);
				resolve(Math.round(video.duration));
			};
			video.src = URL.createObjectURL(file);
		});
	}

	async function saveSlot(slotNumber) {
		const slotIndex = slotNumber - 1;
		const slot = videoSlots[slotIndex];

		if (!slot.title_en || !slot.title_ar) {
			alert('Please provide both English and Arabic titles');
			return;
		}

		if (!slot.file_url) {
			alert('Please upload a video file first');
			return;
		}

		if (!slot.is_infinite && !slot.expiry_date) {
			alert('Please set an expiry date or mark as infinite');
			return;
		}

		slot.loading = true;
		videoSlots = [...videoSlots];

		try {
			const { supabase, storage } = await import('$lib/utils/supabase');
			
			// Get current user from custom auth system
			const currentUser = storage.getCurrentAuthUser();
			const userId = currentUser?.id || null;

			const mediaData = {
				media_type: 'video',
				slot_number: slotNumber,
				title_en: slot.title_en,
				title_ar: slot.title_ar,
				description_en: slot.description_en || null,
				description_ar: slot.description_ar || null,
				file_url: slot.file_url,
				file_size: slot.file_size,
				file_type: 'video/mp4',
				duration: slot.duration,
				is_active: slot.is_active || false, // Include active status
				is_infinite: slot.is_infinite,
				expiry_date: slot.is_infinite ? null : slot.expiry_date,
				uploaded_by: userId
			};

			let result;
			if (slot.id) {
				// Update existing
				result = await supabase
					.from('customer_app_media')
					.update(mediaData)
					.eq('id', slot.id)
					.select()
					.single();
			} else {
				// Insert new
				result = await supabase
					.from('customer_app_media')
					.insert(mediaData)
					.select()
					.single();
			}

			if (result.error) throw result.error;

			if (result.data) {
				videoSlots[slotIndex] = {
					...slot,
					...result.data,
					expiry_date: result.data.expiry_date ? new Date(result.data.expiry_date).toISOString().slice(0, 16) : ''
				};
				videoSlots = [...videoSlots];
				alert('Video saved successfully!');
			}

		} catch (error) {
			console.error('Error saving video:', error);
			alert('Failed to save video: ' + error.message);
		} finally {
			slot.loading = false;
			videoSlots = [...videoSlots];
		}
	}

	async function toggleActive(slotNumber) {
		const slotIndex = slotNumber - 1;
		const slot = videoSlots[slotIndex];

		if (!slot.id) {
			alert('Please save the video first');
			return;
		}

		slot.loading = true;
		videoSlots = [...videoSlots];

		try {
			const { supabase } = await import('$lib/utils/supabase');
			
			const { data, error } = await supabase
				.from('customer_app_media')
				.update({ is_active: !slot.is_active })
				.eq('id', slot.id)
				.select()
				.single();

			if (error) throw error;

			if (data) {
				videoSlots[slotIndex].is_active = data.is_active;
				videoSlots = [...videoSlots];
				alert(`Video ${data.is_active ? 'activated' : 'deactivated'} successfully!`);
			}

		} catch (error) {
			console.error('Error toggling active status:', error);
			alert('Failed to toggle active status: ' + error.message);
		} finally {
			slot.loading = false;
			videoSlots = [...videoSlots];
		}
	}

	function previewVideo(slot) {
		if (!slot.file_url) {
			alert('No video to preview');
			return;
		}
		previewUrl = slot.file_url;
		previewTitle = slot.title_en || 'Video Preview';
		showPreview = true;
	}

	function closePreview() {
		showPreview = false;
		previewUrl = '';
	}

	function formatFileSize(bytes) {
		if (bytes === 0) return '0 Bytes';
		const k = 1024;
		const sizes = ['Bytes', 'KB', 'MB', 'GB'];
		const i = Math.floor(Math.log(bytes) / Math.log(k));
		return Math.round(bytes / Math.pow(k, i) * 100) / 100 + ' ' + sizes[i];
	}

	function formatDuration(seconds) {
		if (!seconds) return '0:00';
		const mins = Math.floor(seconds / 60);
		const secs = seconds % 60;
		return `${mins}:${secs.toString().padStart(2, '0')}`;
	}
</script>

<div class="video-templates-container">
	<div class="templates-header">
		<h2>🎥 Video Templates Manager</h2>
		<p class="subtitle">Manage up to 6 video slots for customer home page carousel</p>
	</div>

	<div class="templates-content">
		<div class="slots-grid">
			{#each videoSlots as slot}
				<div class="slot-card" class:active={slot.is_active}>
					<div class="slot-header">
						<div class="slot-number">Slot {slot.slot_number}</div>
						{#if slot.is_active}
							<span class="active-badge">● ACTIVE</span>
						{/if}
					</div>

					<div class="slot-body">
						<!-- File Upload -->
						<div class="upload-section">
							{#if slot.file_url}
								<div class="video-preview-small">
									<video src={slot.file_url} controls={false} class="preview-video">
										<track kind="captions" />
									</video>
									<div class="video-info">
										<div class="info-item">
											<span class="label">Duration:</span>
											<span class="value">{formatDuration(slot.duration)}</span>
										</div>
										<div class="info-item">
											<span class="label">Size:</span>
											<span class="value">{formatFileSize(slot.file_size)}</span>
										</div>
									</div>
									<button class="preview-btn" on:click={() => previewVideo(slot)}>
										Preview
									</button>
								</div>
							{:else}
								<label class="upload-zone">
									<input 
										type="file" 
										accept="video/*" 
										on:change={(e) => handleFileUpload(e, slot.slot_number)}
										disabled={slot.loading}
									/>
									<div class="upload-icon">🎥</div>
									<div class="upload-text">
										{slot.loading ? 'Uploading...' : 'Click to upload video'}
									</div>
									<div class="upload-hint">MP4, WebM (Max 50MB)</div>
								</label>
							{/if}
						</div>

						<!-- Form Fields -->
						<div class="form-group">
							<label>
								<span class="label-text">Title (English) *</span>
								<input 
									type="text" 
									bind:value={slot.title_en}
									placeholder="Enter English title"
									disabled={slot.loading}
								/>
							</label>
						</div>

						<div class="form-group">
							<label>
								<span class="label-text">Title (Arabic) *</span>
								<input 
									type="text" 
									bind:value={slot.title_ar}
									placeholder="أدخل العنوان بالعربية"
									dir="rtl"
									disabled={slot.loading}
								/>
							</label>
						</div>

						<div class="form-group">
							<label>
								<span class="label-text">Description (English)</span>
								<textarea 
									bind:value={slot.description_en}
									placeholder="Enter English description"
									rows="2"
									disabled={slot.loading}
								></textarea>
							</label>
						</div>

						<div class="form-group">
							<label>
								<span class="label-text">Description (Arabic)</span>
								<textarea 
									bind:value={slot.description_ar}
									placeholder="أدخل الوصف بالعربية"
									dir="rtl"
									rows="2"
									disabled={slot.loading}
								></textarea>
							</label>
						</div>

						<!-- Expiry Settings -->
						<div class="expiry-section">
							<label class="checkbox-label">
								<input 
									type="checkbox" 
									bind:checked={slot.is_infinite}
									disabled={slot.loading}
								/>
								<span>No expiry (Infinite)</span>
							</label>

							{#if !slot.is_infinite}
								<div class="form-group">
									<label>
										<span class="label-text">Expiry Date & Time *</span>
										<input 
											type="datetime-local" 
											bind:value={slot.expiry_date}
											disabled={slot.loading}
										/>
									</label>
								</div>
							{/if}
						</div>
					</div>

					<div class="slot-footer">
						<button 
							class="save-btn"
							on:click={() => saveSlot(slot.slot_number)}
							disabled={slot.loading}
						>
							{slot.loading ? 'Saving...' : slot.id ? 'Update' : 'Save'}
						</button>

						{#if slot.id}
							<button 
								class="toggle-btn"
								class:deactivate={slot.is_active}
								on:click={() => toggleActive(slot.slot_number)}
								disabled={slot.loading}
							>
								{slot.is_active ? 'Deactivate' : 'Activate'}
							</button>
						{/if}
					</div>
				</div>
			{/each}
		</div>
	</div>
</div>

<!-- Preview Modal -->
{#if showPreview}
	<div class="preview-modal" on:click={closePreview}>
		<div class="preview-content" on:click|stopPropagation>
			<div class="preview-header">
				<h3>{previewTitle}</h3>
				<button class="close-btn" on:click={closePreview}>×</button>
			</div>
			<div class="preview-body">
				<video src={previewUrl} controls autoplay class="preview-video-large">
					<track kind="captions" />
				</video>
			</div>
		</div>
	</div>
{/if}

<style>
	.video-templates-container {
		display: flex;
		flex-direction: column;
		height: 100%;
		background: #f8fafc;
	}

	.templates-header {
		padding: 1.5rem;
		background: white;
		border-bottom: 2px solid #e2e8f0;
	}

	.templates-header h2 {
		margin: 0 0 0.5rem 0;
		color: #1e293b;
		font-size: 1.5rem;
		font-weight: 600;
	}

	.subtitle {
		margin: 0;
		color: #64748b;
		font-size: 0.875rem;
	}

	.templates-content {
		flex: 1;
		padding: 1.5rem;
		overflow-y: auto;
	}

	.slots-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(350px, 1fr));
		gap: 1.5rem;
	}

	.slot-card {
		background: white;
		border: 2px solid #e2e8f0;
		border-radius: 12px;
		overflow: hidden;
		display: flex;
		flex-direction: column;
	}

	.slot-card.active {
		border-color: #22c55e;
		box-shadow: 0 0 0 3px rgba(34, 197, 94, 0.1);
	}

	.slot-header {
		padding: 1rem;
		background: #f8fafc;
		border-bottom: 1px solid #e2e8f0;
		display: flex;
		justify-content: space-between;
		align-items: center;
	}

	.slot-number {
		font-weight: 600;
		color: #1e293b;
		font-size: 1rem;
	}

	.active-badge {
		color: #22c55e;
		font-size: 0.75rem;
		font-weight: 600;
		display: flex;
		align-items: center;
		gap: 0.25rem;
	}

	.slot-body {
		padding: 1rem;
		flex: 1;
	}

	.upload-section {
		margin-bottom: 1rem;
	}

	.upload-zone {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 2rem;
		border: 2px dashed #cbd5e1;
		border-radius: 8px;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.upload-zone:hover {
		border-color: #3b82f6;
		background: #eff6ff;
	}

	.upload-zone input[type="file"] {
		display: none;
	}

	.upload-icon {
		font-size: 2.5rem;
		margin-bottom: 0.5rem;
	}

	.upload-text {
		color: #475569;
		font-weight: 500;
		margin-bottom: 0.25rem;
	}

	.upload-hint {
		color: #94a3b8;
		font-size: 0.75rem;
	}

	.video-preview-small {
		border: 1px solid #e2e8f0;
		border-radius: 8px;
		overflow: hidden;
	}

	.preview-video {
		width: 100%;
		height: 150px;
		object-fit: cover;
		background: #000;
	}

	.video-info {
		padding: 0.75rem;
		background: #f8fafc;
		display: flex;
		gap: 1rem;
	}

	.info-item {
		display: flex;
		gap: 0.5rem;
		font-size: 0.875rem;
	}

	.info-item .label {
		color: #64748b;
	}

	.info-item .value {
		color: #1e293b;
		font-weight: 500;
	}

	.preview-btn {
		width: 100%;
		padding: 0.5rem;
		background: #3b82f6;
		color: white;
		border: none;
		cursor: pointer;
		font-weight: 500;
		transition: background 0.2s ease;
	}

	.preview-btn:hover {
		background: #2563eb;
	}

	.form-group {
		margin-bottom: 1rem;
	}

	.label-text {
		display: block;
		margin-bottom: 0.5rem;
		color: #475569;
		font-size: 0.875rem;
		font-weight: 500;
	}

	input[type="text"],
	input[type="datetime-local"],
	textarea {
		width: 100%;
		padding: 0.625rem;
		border: 1px solid #cbd5e1;
		border-radius: 6px;
		font-size: 0.875rem;
		transition: border-color 0.2s ease;
	}

	input:focus,
	textarea:focus {
		outline: none;
		border-color: #3b82f6;
	}

	input:disabled,
	textarea:disabled {
		background: #f1f5f9;
		cursor: not-allowed;
	}

	textarea {
		resize: vertical;
		font-family: inherit;
	}

	.expiry-section {
		margin-top: 1rem;
		padding-top: 1rem;
		border-top: 1px solid #e2e8f0;
	}

	.checkbox-label {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		cursor: pointer;
		margin-bottom: 1rem;
	}

	.checkbox-label input[type="checkbox"] {
		width: auto;
		cursor: pointer;
	}

	.slot-footer {
		padding: 1rem;
		background: #f8fafc;
		border-top: 1px solid #e2e8f0;
		display: flex;
		gap: 0.5rem;
	}

	.save-btn,
	.toggle-btn {
		flex: 1;
		padding: 0.625rem;
		border: none;
		border-radius: 6px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.save-btn {
		background: #3b82f6;
		color: white;
	}

	.save-btn:hover:not(:disabled) {
		background: #2563eb;
	}

	.toggle-btn {
		background: #22c55e;
		color: white;
	}

	.toggle-btn:hover:not(:disabled) {
		background: #16a34a;
	}

	.toggle-btn.deactivate {
		background: #ef4444;
	}

	.toggle-btn.deactivate:hover:not(:disabled) {
		background: #dc2626;
	}

	button:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	/* Preview Modal */
	.preview-modal {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.8);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 10000;
		padding: 2rem;
	}

	.preview-content {
		background: white;
		border-radius: 12px;
		max-width: 800px;
		width: 100%;
		max-height: 90vh;
		display: flex;
		flex-direction: column;
	}

	.preview-header {
		padding: 1rem 1.5rem;
		border-bottom: 1px solid #e2e8f0;
		display: flex;
		justify-content: space-between;
		align-items: center;
	}

	.preview-header h3 {
		margin: 0;
		color: #1e293b;
	}

	.close-btn {
		background: none;
		border: none;
		font-size: 2rem;
		color: #64748b;
		cursor: pointer;
		line-height: 1;
		padding: 0;
		width: 32px;
		height: 32px;
		display: flex;
		align-items: center;
		justify-content: center;
		border-radius: 4px;
	}

	.close-btn:hover {
		background: #f1f5f9;
		color: #1e293b;
	}

	.preview-body {
		padding: 1.5rem;
		flex: 1;
		overflow: auto;
	}

	.preview-video-large {
		width: 100%;
		height: auto;
		max-height: 60vh;
		background: #000;
		border-radius: 8px;
	}
</style>
