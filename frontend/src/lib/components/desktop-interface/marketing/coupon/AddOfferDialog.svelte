<script lang="ts">
	import { supabase } from '$lib/utils/supabase';
	import { currentLocale } from '$lib/i18n';
	import { onMount } from 'svelte';

	interface Props {
		windowId?: string;
		offerId?: string;
		onOfferAdded?: () => void;
	}

	let { windowId = '', offerId = '', onOfferAdded = () => {} }: Props = $props();

	let branches: any[] = [];
	let isLoading = false;
	let selectedFile: File | null = null;
	let selectedThumbnail: File | null = null;
	let existingFileUrl = '';
	let existingThumbnailUrl = '';
	let isLoadingData = $state(true);
	
	// Use $derived for isEditing to react to prop changes
	let isEditing = $derived(!!offerId);
	
	// Form state
	let offerName = $state('');
	let selectedBranch = $state('');
	let startDate = $state(''); // ISO format yyyy-mm-dd
	let startDateDisplay = $state(''); // Display format dd/mm/yyyy
	let startHour = $state('09');
	let startMinute = $state('00');
	let startPeriod = $state('AM');
	let endDate = $state(''); // ISO format yyyy-mm-dd
	let endDateDisplay = $state(''); // Display format dd/mm/yyyy
	let endHour = $state('05');
	let endMinute = $state('00');
	let endPeriod = $state('PM');
	let fileInputElement: HTMLInputElement;
	let thumbnailInputElement: HTMLInputElement;

	onMount(async () => {
		await fetchBranches();
		if (offerId) {
			await loadOfferData(offerId);
		} else {
			isLoadingData = false;
		}
	});

	async function loadOfferData(id: string) {
		try {
			console.log('Loading offer with ID:', id);
			const { data, error } = await supabase
				.from('view_offer')
				.select('*')
				.eq('id', id)
				.single();

			if (error) {
				console.error('Error:', error);
				throw error;
			}
			
			if (data) {
				console.log('Offer data loaded:', data);
				offerName = data.offer_name || '';
				selectedBranch = String(data.branch_id);
				startDate = data.start_date || '';
				startDateDisplay = toDisplayDate(data.start_date || '');
				endDate = data.end_date || '';
				endDateDisplay = toDisplayDate(data.end_date || '');
				existingFileUrl = data.file_url || '';
				existingThumbnailUrl = data.thumbnail_url || '';
				
				// Parse start time
				if (data.start_time) {
					const [startHrs, startMins] = data.start_time.split(':');
					let sHour = parseInt(startHrs);
					let sPeriod = 'AM';
					
					if (sHour >= 12) {
						sPeriod = 'PM';
						if (sHour > 12) sHour -= 12;
					} else if (sHour === 0) {
						sHour = 12;
					}
					
					startHour = String(sHour).padStart(2, '0');
					startMinute = startMins || '00';
					startPeriod = sPeriod;
				}

				// Parse end time
				if (data.end_time) {
					const [endHrs, endMins] = data.end_time.split(':');
					let eHour = parseInt(endHrs);
					let ePeriod = 'AM';
					
					if (eHour >= 12) {
						ePeriod = 'PM';
						if (eHour > 12) eHour -= 12;
					} else if (eHour === 0) {
						eHour = 12;
					}
					
					endHour = String(eHour).padStart(2, '0');
					endMinute = endMins || '00';
					endPeriod = ePeriod;
				}
				
				console.log('Form loaded:', { offerName, selectedBranch, startDate, endDate, startHour, startMinute, startPeriod, endHour, endMinute, endPeriod });
			}
		} catch (error) {
			console.error('Error loading offer data:', error);
		} finally {
			isLoadingData = false;
		}
	}

	async function fetchBranches() {
		try {
			const { data, error } = await supabase
				.from('branches')
				.select('id, name_en, name_ar')
				.eq('is_active', true)
				.order('name_en');

			if (error) throw error;
			branches = data || [];
		} catch (error) {
			console.error('Error fetching branches:', error);
		}
	}

	function getBranchName(branch: any) {
		return $currentLocale === 'ar' ? branch.name_ar : branch.name_en;
	}

	// Convert yyyy-mm-dd to dd/mm/yyyy for display
	function toDisplayDate(isoDate: string): string {
		if (!isoDate) return '';
		const [year, month, day] = isoDate.split('-');
		return `${day}/${month}/${year}`;
	}

	// Convert dd/mm/yyyy to yyyy-mm-dd for database
	function toISODate(displayDate: string): string {
		if (!displayDate) return '';
		const parts = displayDate.split('/');
		if (parts.length !== 3) return displayDate;
		const [day, month, year] = parts;
		return `${year}-${month.padStart(2, '0')}-${day.padStart(2, '0')}`;
	}

	// Format date input on blur
	function formatDateInput(e: Event, field: 'start' | 'end') {
		const input = e.target as HTMLInputElement;
		let value = input.value.replace(/[^0-9/]/g, '');
		
		// Auto-format: add slashes after day and month
		if (value.length === 2 && !value.includes('/')) {
			value = value + '/';
		} else if (value.length === 5 && value.split('/').length === 2) {
			value = value + '/';
		}
		
		if (field === 'start') {
			startDateDisplay = value;
		} else {
			endDateDisplay = value;
		}
	}

	function handleFileSelect(event: Event) {
		const target = event.target as HTMLInputElement;
		const files = target.files;
		if (files && files.length > 0) {
			selectedFile = files[0];
		}
	}

	function handleThumbnailSelect(event: Event) {
		const target = event.target as HTMLInputElement;
		const files = target.files;
		if (files && files.length > 0) {
			selectedThumbnail = files[0];
		}
	}

	function triggerFileInput() {
		fileInputElement?.click();
	}

	function triggerThumbnailInput() {
		thumbnailInputElement?.click();
	}

	function resetForm() {
		offerName = '';
		selectedBranch = '';
		startDate = '';
		startHour = '09';
		startMinute = '00';
		startPeriod = 'AM';
		endDate = '';
		endHour = '05';
		endMinute = '00';
		endPeriod = 'PM';
		selectedFile = null;
		selectedThumbnail = null;
		if (fileInputElement) {
			fileInputElement.value = '';
		}
		if (thumbnailInputElement) {
			thumbnailInputElement.value = '';
		}
	}

	function convert12HourTo24Hour(hour: string, period: string): string {
		let h = parseInt(hour);
		if (period === 'PM' && h !== 12) h += 12;
		if (period === 'AM' && h === 12) h = 0;
		return String(h).padStart(2, '0');
	}

	async function handleAddOffer() {
		if (!offerName || !selectedBranch || !startDate || !endDate) {
			if (isEditing) {
				alert('Please fill all fields');
			} else {
				alert('Please fill all fields and select a file');
			}
			return;
		}

		// For new offers, file is required
		if (!isEditing && !selectedFile) {
			alert('Please select a file');
			return;
		}

		// Convert 12-hour format to 24-hour format
		const startTime24 = convert12HourTo24Hour(startHour, startPeriod) + ':' + startMinute;
		const endTime24 = convert12HourTo24Hour(endHour, endPeriod) + ':' + endMinute;

		// Validate dates and times
		const startDateTime = new Date(`${startDate}T${startTime24}`);
		const endDateTime = new Date(`${endDate}T${endTime24}`);
		
		if (startDateTime >= endDateTime) {
			alert('End date/time must be after start date/time');
			return;
		}

		isLoading = true;
		try {
			let fileUrl = existingFileUrl;
			let thumbnailUrl = existingThumbnailUrl;

			// Upload file if a new file is selected
			if (selectedFile) {
				const fileExtension = selectedFile.name.split('.').pop() || 'file';
				const fileName = `offer_${selectedBranch}_${Date.now()}.${fileExtension}`;
				const { error: uploadError } = await supabase.storage
					.from('offer-pdfs')
					.upload(fileName, selectedFile);

				if (uploadError) throw uploadError;

				// Get public URL
				const { data } = supabase.storage
					.from('offer-pdfs')
					.getPublicUrl(fileName);

				fileUrl = data.publicUrl;
			}

			// Upload thumbnail if a new thumbnail is selected
			if (selectedThumbnail) {
				const fileExtension = selectedThumbnail.name.split('.').pop() || 'jpg';
				const fileName = `offer_thumbnail_${selectedBranch}_${Date.now()}.${fileExtension}`;
				const { error: uploadError } = await supabase.storage
					.from('offer-pdfs')
					.upload(fileName, selectedThumbnail);

				if (uploadError) throw uploadError;

				// Get public URL
				const { data } = supabase.storage
					.from('offer-pdfs')
					.getPublicUrl(fileName);

				thumbnailUrl = data.publicUrl;
			}

			if (isEditing && offerId) {
				// Update existing offer
				const { error: updateError } = await supabase
					.from('view_offer')
					.update({
						offer_name: offerName,
						branch_id: parseInt(selectedBranch),
						start_date: startDate,
						start_time: startTime24,
						end_date: endDate,
						end_time: endTime24,
						file_url: fileUrl,
						thumbnail_url: thumbnailUrl,
						updated_at: new Date().toISOString()
					})
					.eq('id', offerId);

				if (updateError) throw updateError;
				alert('Offer updated successfully');
			} else {
				// Insert new offer
				const { error: insertError } = await supabase
					.from('view_offer')
					.insert({
						offer_name: offerName,
						branch_id: parseInt(selectedBranch),
						start_date: startDate,
						start_time: startTime24,
						end_date: endDate,
						end_time: endTime24,
						file_url: fileUrl,
						thumbnail_url: thumbnailUrl,
						created_at: new Date().toISOString()
					});

				if (insertError) throw insertError;
				alert('Offer added successfully');
			}

			resetForm();
			onOfferAdded();
		} catch (error) {
			console.error('Error:', error);
			alert('Error: ' + (error as any).message);
		} finally {
			isLoading = false;
		}
	}
</script>

<div class="add-offer-dialog">
	<div class="dialog-content">
		<h2 class="dialog-title">{isEditing ? '✏️ Edit Offer' : '➕ Add New Offer'}</h2>
		
		{#if isLoadingData}
			<div class="loading-state">
				<div class="spinner"></div>
				<p>Loading offer data...</p>
			</div>
		{:else}
			<form class="dialog-form" onsubmit={(e) => { e.preventDefault(); handleAddOffer(); }}>
			<div class="form-group">
				<label for="offer-name">Offer Name</label>
				<input
					id="offer-name"
					type="text"
					bind:value={offerName}
					placeholder="Enter offer name"
					required
					disabled={isLoading}
				/>
			</div>

			<div class="form-group">
				<label for="branch-select">Branch</label>
				<select
					id="branch-select"
					bind:value={selectedBranch}
					required
					disabled={isLoading}
				>
					<option value="">Select a branch</option>
					{#each branches as branch (branch.id)}
						<option value={branch.id}>{getBranchName(branch)}</option>
					{/each}
				</select>
			</div>

			<div class="form-row">
				<div class="form-group">
					<label for="start-date">Start Date</label>
					<input
						id="start-date"
						type="text"
						placeholder="dd/mm/yyyy"
						bind:value={startDateDisplay}
						onblur={(e) => { startDate = toISODate(startDateDisplay); }}
						required
						disabled={isLoading}
					/>
				</div>
				<div class="form-group">
					<label>Start Time</label>
					<div class="time-input-group">
						<input
							type="number"
							min="1"
							max="12"
							bind:value={startHour}
							placeholder="HH"
							disabled={isLoading}
							class="hour-input"
						/>
						<span class="time-separator">:</span>
						<input
							type="number"
							min="0"
							max="59"
							bind:value={startMinute}
							placeholder="MM"
							disabled={isLoading}
							class="minute-input"
						/>
						<select bind:value={startPeriod} disabled={isLoading} class="period-select">
							<option value="AM">AM</option>
							<option value="PM">PM</option>
						</select>
					</div>
				</div>
			</div>

			<div class="form-row">
				<div class="form-group">
					<label for="end-date">End Date</label>
					<input
						id="end-date"
						type="text"
						placeholder="dd/mm/yyyy"
						bind:value={endDateDisplay}
						onblur={(e) => { endDate = toISODate(endDateDisplay); }}
						required
						disabled={isLoading}
					/>
				</div>
				<div class="form-group">
					<label>End Time</label>
					<div class="time-input-group">
						<input
							type="number"
							min="1"
							max="12"
							bind:value={endHour}
							placeholder="HH"
							disabled={isLoading}
							class="hour-input"
						/>
						<span class="time-separator">:</span>
						<input
							type="number"
							min="0"
							max="59"
							bind:value={endMinute}
							placeholder="MM"
							disabled={isLoading}
							class="minute-input"
						/>
						<select bind:value={endPeriod} disabled={isLoading} class="period-select">
							<option value="AM">AM</option>
							<option value="PM">PM</option>
						</select>
					</div>
				</div>
			</div>

			<div class="form-group">
				<label for="pdf-upload">Upload File {isEditing ? '(Optional - leave blank to keep current)' : ''}</label>
				<div class="file-upload">
					<input
						id="pdf-upload"
						type="file"
						bind:this={fileInputElement}
					onchange={handleFileSelect}
					required={!isEditing}
					disabled={isLoading}
				/>
				<span class="file-name" onclick={triggerFileInput} role="button" tabindex="0">
						{selectedFile ? selectedFile.name : (isEditing ? 'Choose a new file to replace (optional)' : 'Choose any file (PDF, Video, Image, etc.)')}
					</span>
					{#if isEditing && existingFileUrl}
						<p class="file-info">Current: <a href={existingFileUrl} target="_blank" rel="noopener noreferrer">View</a></p>
					{/if}
				</div>
			</div>

			<div class="form-group">
				<label for="thumbnail-upload">Upload Thumbnail {isEditing ? '(Optional)' : ''}</label>
				<div class="file-upload">
					<input
						id="thumbnail-upload"
						type="file"
						accept="image/*"
						bind:this={thumbnailInputElement}
						onchange={handleThumbnailSelect}
						disabled={isLoading}
					/>
					<span class="file-name" onclick={triggerThumbnailInput} role="button" tabindex="0">
						{selectedThumbnail ? selectedThumbnail.name : 'Choose image file for thumbnail'}
					</span>
					{#if isEditing && existingThumbnailUrl}
						<p class="file-info">Current: <a href={existingThumbnailUrl} target="_blank" rel="noopener noreferrer">View</a></p>
					{/if}
				</div>
			</div>

			<div class="dialog-actions">
				<button type="submit" class="btn-submit" disabled={isLoading}>
					{isLoading ? (isEditing ? 'Updating...' : 'Adding...') : (isEditing ? 'Update Offer' : 'Add Offer')}
				</button>
			</div>
		</form>
		{/if}
	</div>
</div>

<style>
	.add-offer-dialog {
		width: 100%;
		height: 100%;
		display: flex;
		flex-direction: column;
		background: white;
		overflow: hidden;
	}

	.dialog-content {
		flex: 1;
		overflow-y: auto;
		padding: 1.5rem;
	}

	.loading-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		height: 100%;
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

	.loading-state p {
		color: #6b7280;
		font-size: 1rem;
	}

	.dialog-title {
		font-size: 1.5rem;
		font-weight: 700;
		color: #1f2937;
		margin: 0 0 1.5rem 0;
		padding-bottom: 1rem;
		border-bottom: 2px solid #e5e7eb;
	}

	.dialog-form {
		display: flex;
		flex-direction: column;
		gap: 1.25rem;
	}

	.form-group {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.form-group label {
		font-size: 0.875rem;
		font-weight: 600;
		color: #374151;
	}

	.form-group input,
	.form-group select {
		padding: 0.75rem;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 1rem;
		font-family: inherit;
		transition: all 0.2s ease;
	}

	.form-group input:focus,
	.form-group select:focus {
		outline: none;
		border-color: #10b981;
		box-shadow: 0 0 0 3px rgba(16, 185, 129, 0.1);
	}

	.form-group input:disabled,
	.form-group select:disabled {
		background: #f9fafb;
		color: #9ca3af;
		cursor: not-allowed;
	}

	.form-row {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 1rem;
	}

	.time-input-group {
		display: flex;
		align-items: center;
		justify-content: flex-start;
		gap: 0.75rem;
		padding: 0.85rem 1rem;
		border: 1.5px solid #d1d5db;
		border-radius: 6px;
		background: #ffffff;
		transition: all 0.2s ease;
	}

	.time-input-group:hover {
		border-color: #10b981;
		background: #fafcfa;
	}

	.time-input-group:focus-within {
		border-color: #10b981;
		box-shadow: 0 0 0 3px rgba(16, 185, 129, 0.1);
		background: #f0fdf4;
	}

	.hour-input,
	.minute-input {
		width: 55px;
		padding: 0.65rem 0.5rem;
		border: 1px solid #d1d5db;
		border-radius: 5px;
		font-size: 1rem;
		font-weight: 700;
		text-align: center;
		transition: all 0.2s ease;
		background: #ffffff;
		color: #111827;
	}

	.hour-input::placeholder,
	.minute-input::placeholder {
		color: #9ca3af;
		font-weight: 500;
	}

	.hour-input:hover,
	.minute-input:hover {
		border-color: #10b981;
		background: #f9fef9;
	}

	.hour-input:focus,
	.minute-input:focus {
		outline: none;
		border-color: #10b981;
		background: #f0fdf4;
		box-shadow: 0 0 0 3px rgba(16, 185, 129, 0.1);
	}

	.hour-input:disabled,
	.minute-input:disabled {
		background: #f3f4f6;
		color: #9ca3af;
		cursor: not-allowed;
		border-color: #e5e7eb;
	}

	/* Remove number input spinners */
	.hour-input::-webkit-outer-spin-button,
	.hour-input::-webkit-inner-spin-button,
	.minute-input::-webkit-outer-spin-button,
	.minute-input::-webkit-inner-spin-button {
		-webkit-appearance: none;
		margin: 0;
	}

	.hour-input[type=number],
	.minute-input[type=number] {
		-moz-appearance: textfield;
	}

	.time-separator {
		font-size: 1.5rem;
		font-weight: 900;
		color: #374151;
		line-height: 1;
		margin: 0 0.25rem;
	}

	.period-select {
		padding: 0.65rem 0.75rem;
		border: 1px solid #d1d5db;
		border-radius: 5px;
		font-size: 0.95rem;
		font-weight: 700;
		cursor: pointer;
		background: white;
		color: #111827;
		transition: all 0.2s ease;
		min-width: 80px;
		text-align: center;
	}

	.period-select:hover {
		border-color: #10b981;
		background: #f9fef9;
	}

	.period-select:focus {
		outline: none;
		border-color: #10b981;
		box-shadow: 0 0 0 3px rgba(16, 185, 129, 0.1);
		background: #f0fdf4;
	}

	.period-select:disabled {
		background: #f3f4f6;
		color: #9ca3af;
		cursor: not-allowed;
		border-color: #e5e7eb;
	}

	.file-upload {
		position: relative;
		display: flex;
		align-items: center;
		gap: 0.75rem;
	}

	.file-upload input[type="file"] {
		position: absolute;
		opacity: 0;
		width: 0;
		height: 0;
	}

	.file-upload input[type="file"]:focus {
		outline: none;
	}

	.file-name {
		flex: 1;
		padding: 0.75rem;
		border: 1px dashed #d1d5db;
		border-radius: 6px;
		font-size: 0.875rem;
		color: #6b7280;
		cursor: pointer;
		text-overflow: ellipsis;
		white-space: nowrap;
		overflow: hidden;
		transition: all 0.2s ease;
		display: flex;
		align-items: center;
		user-select: none;
	}

	.file-name:hover {
		border-color: #10b981;
		background: #f0fdf4;
		color: #059669;
	}

	.file-upload input[type="file"]:disabled ~ .file-name {
		background: #f9fafb;
		cursor: not-allowed;
		color: #9ca3af;
	}

	.file-info {
		font-size: 0.75rem;
		color: #6b7280;
		margin: 0.5rem 0 0 0;
	}

	.file-info a {
		color: #0369a1;
		text-decoration: underline;
		cursor: pointer;
	}

	.file-info a:hover {
		color: #1e40af;
	}

	.dialog-actions {
		display: flex;
		gap: 0.75rem;
		justify-content: flex-end;
		padding-top: 0.75rem;
		border-top: 1px solid #e5e7eb;
		margin-top: auto;
	}

	.btn-submit {
		padding: 0.75rem 1.5rem;
		border-radius: 6px;
		font-size: 1rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s ease;
		border: none;
		background: linear-gradient(135deg, #10b981 0%, #059669 100%);
		color: white;
	}

	.btn-submit:hover:not(:disabled) {
		background: linear-gradient(135deg, #059669 0%, #047857 100%);
		transform: translateY(-2px);
	}

	.btn-submit:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	@media (max-width: 768px) {
		.dialog-content {
			padding: 1rem;
		}

		.form-row {
			grid-template-columns: 1fr;
		}
	}
</style>
