<script lang="ts">
	import { supabase } from '$lib/utils/supabase';
	import { currentLocale } from '$lib/i18n';
	import { onMount } from 'svelte';

	interface Props {
		windowId?: string;
		onOfferAdded?: () => void;
	}

	let { windowId = '', onOfferAdded = () => {} }: Props = $props();

	let branches: any[] = [];
	let isLoading = false;
	let selectedFile: File | null = null;
	
	// Form state
	let offerName = '';
	let selectedBranch = '';
	let startDate = '';
	let startHour = '09';
	let startMinute = '00';
	let startPeriod = 'AM';
	let endDate = '';
	let endHour = '05';
	let endMinute = '00';
	let endPeriod = 'PM';
	let fileInputElement: HTMLInputElement;

	onMount(async () => {
		await fetchBranches();
	});

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

	function handleFileSelect(event: Event) {
		const target = event.target as HTMLInputElement;
		const files = target.files;
		if (files && files.length > 0) {
			selectedFile = files[0];
		}
	}

	function triggerFileInput() {
		fileInputElement?.click();
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
		if (fileInputElement) {
			fileInputElement.value = '';
		}
	}

	function convert12HourTo24Hour(hour: string, period: string): string {
		let h = parseInt(hour);
		if (period === 'PM' && h !== 12) h += 12;
		if (period === 'AM' && h === 12) h = 0;
		return String(h).padStart(2, '0');
	}

	async function handleAddOffer() {
		if (!offerName || !selectedBranch || !startDate || !endDate || !selectedFile) {
			alert('Please fill all fields and select a file');
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
			// Upload file to storage
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

			const fileUrl = data.publicUrl;

			// Insert into view_offer table
			const { error: insertError } = await supabase
				.from('view_offer')
				.insert({
					offer_name: offerName,
					branch_id: selectedBranch,
					start_date: startDate,
					start_time: startTime24,
					end_date: endDate,
					end_time: endTime24,
					file_url: fileUrl,
					created_at: new Date().toISOString()
				});

			if (insertError) throw insertError;

			alert('Offer added successfully');
			resetForm();
			onOfferAdded();
		} catch (error) {
			console.error('Error adding offer:', error);
			alert('Error adding offer: ' + (error as any).message);
		} finally {
			isLoading = false;
		}
	}
</script>

<div class="add-offer-dialog">
	<div class="dialog-content">
		<form class="dialog-form" on:submit|preventDefault={handleAddOffer}>
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
						type="date"
						bind:value={startDate}
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
						type="date"
						bind:value={endDate}
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
				<label for="pdf-upload">Upload File</label>
				<div class="file-upload">
					<input
						id="pdf-upload"
						type="file"
						bind:this={fileInputElement}
						on:change={handleFileSelect}
						required
						disabled={isLoading}
					/>
					<span class="file-name" on:click={triggerFileInput} role="button" tabindex="0">
						{selectedFile ? selectedFile.name : 'Choose any file (PDF, Video, Image, etc.)'}
					</span>
				</div>
			</div>

			<div class="dialog-actions">
				<button type="submit" class="btn-submit" disabled={isLoading}>
					{isLoading ? 'Adding...' : 'Add Offer'}
				</button>
			</div>
		</form>
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
