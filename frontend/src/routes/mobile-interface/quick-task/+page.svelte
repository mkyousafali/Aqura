<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { page } from '$app/stores';
	import { supabase, uploadToSupabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { locale, getTranslation, currentLocale } from '$lib/i18n';
	import { notifications } from '$lib/stores/notifications';

	// State management
	let loading = true;
	let branches = [];
	let selectedBranch = null;
	let users = [];
	let selectedUser = null; // Single user selection
	let searchTerm = '';
	let showUserPopup = false;
	let isSubmitting = false;
	let showSuccessMessage = false;
	let successMessage = '';
	let showSuccessPopup = false;
	let successTaskData = null;
	let lastAssignedUser = null; // Keep track for "assign again"

	// Form data
	let taskTitle = ''; // Auto-generated from issue type
	let issueTypeWithPrice = ''; // Combined selection (issue + price)
	let issueType = ''; // Extracted issue type
	let customIssueType = ''; // Custom issue type for "Other"
	let priceTag = 'medium'; // Extracted or default price tag
	let priority = 'medium'; // Default priority
	let taskDescription = '';
	let selectedFiles = [];
	let setAsDefaultSettings = false;
	let fileInput; // Reference to hidden file input
	let cameraInput; // Reference to camera input

	// Image Editor State
	let showImageEditor = false;
	let editorCanvas;
	let editorCtx;
	let editorImage = null;
	let editorFileEntry = null; // The file entry being edited
	let isDrawing = false;
	let editorMode = 'draw'; // 'draw' or 'text'
	let editorColor = '#FF0000';
	let editorLineWidth = 3;
	let lastX = 0;
	let lastY = 0;
	let editorHistory = []; // For undo
	let textInput = '';
	let textPosition = null; // {x, y} where to place text

	// QR Scanner State
	let scanningQR = false;
	let scanVideoEl;
	let scanStream = null;
	let scanInterval = null;
	let scanBarcodeDetector = null;
	let scanCanvas = null;
	let scanCtx = null;

	// Quick Task Completion Requirements
	let requirePhotoUpload = false;
	let requireErpReference = false;
	let requireFileUpload = false;

	// Reactive Options with Translation Support
	$: issueTypeOptions = [
		{ value: 'price-tag', label: getTranslation('mobile.quickTaskContent.issueTypes.priceTag'), issueType: 'price-tag', priceTag: 'medium' },
		{ value: 'cleaning', label: getTranslation('mobile.quickTaskContent.issueTypes.cleaning'), issueType: 'cleaning', priceTag: 'medium' },
		{ value: 'display', label: getTranslation('mobile.quickTaskContent.issueTypes.display'), issueType: 'display', priceTag: 'medium' },
		{ value: 'filling', label: getTranslation('mobile.quickTaskContent.issueTypes.filling'), issueType: 'filling', priceTag: 'medium' },
		{ value: 'maintenance', label: getTranslation('mobile.quickTaskContent.issueTypes.maintenance'), issueType: 'maintenance', priceTag: 'medium' },
		{ value: 'other', label: getTranslation('mobile.quickTaskContent.issueTypes.other'), issueType: 'other', priceTag: 'medium' }
	];

	$: priorityOptions = [
		{ value: 'low', label: getTranslation('mobile.quickTaskContent.priorities.low') },
		{ value: 'medium', label: getTranslation('mobile.quickTaskContent.priorities.medium') },
		{ value: 'high', label: getTranslation('mobile.quickTaskContent.priorities.high') },
		{ value: 'urgent', label: getTranslation('mobile.quickTaskContent.priorities.urgent') }
	];

	$: priceTagOptions = [
		{ value: 'low', label: getTranslation('mobile.quickTaskContent.priceTags.low') },
		{ value: 'medium', label: getTranslation('mobile.quickTaskContent.priceTags.medium') },
		{ value: 'high', label: getTranslation('mobile.quickTaskContent.priceTags.high') },
		{ value: 'critical', label: getTranslation('mobile.quickTaskContent.priceTags.critical') }
	];

	// Extract issueType and priceTag from combined selection
	$: if (issueTypeWithPrice) {
		const selectedOption = issueTypeOptions.find(option => option.value === issueTypeWithPrice);
		if (selectedOption) {
			issueType = selectedOption.issueType;
			priceTag = selectedOption.priceTag;
		}
	}

	// Task title is automatically set from issue type or custom input
	// But allow manual override after form reset
	$: {
		if (issueType === 'other') {
			taskTitle = customIssueType;
		} else if (issueType && issueType !== '') {
			// For predefined types, use the selected label as title
			const selectedOption = issueTypeOptions.find(option => option.issueType === issueType);
			taskTitle = selectedOption ? selectedOption.label : '';
		}
		// Don't automatically clear taskTitle when issueType is empty
		// This allows users to manually type a title after form reset
	}

	// Filtered users for search
	$: filteredUsers = users.filter(user => {
		if (!searchTerm) return true;
		const term = searchTerm.toLowerCase();
		const positionNameEn = user.position_info?.position_title_en || '';
		const positionNameAr = user.position_info?.position_title_ar || '';
		const branchName = user.branch_name || '';
		return (
			user.username?.toLowerCase().includes(term) ||
			user.name_en?.toLowerCase().includes(term) ||
			user.name_ar?.toLowerCase().includes(term) ||
			user.hr_employees?.name?.toLowerCase().includes(term) ||
			user.employee_id?.toLowerCase().includes(term) ||
			positionNameEn.toLowerCase().includes(term) ||
			positionNameAr.toLowerCase().includes(term) ||
			branchName.toLowerCase().includes(term)
		);
	});

	// Auto-fill branch from selected user
	$: if (selectedUser) {
		selectedBranch = selectedUser.current_branch_id;
	} else {
		selectedBranch = null;
	}

	// Get branch name by ID - handle both string and number IDs
	$: selectedBranchName = branches.find(b => b.id == selectedBranch)?.[getBranchNameField()] || 
	                       branches.find(b => b.id == selectedBranch)?.name || 
	                       '';

	// Helper function to get the correct name field based on locale
	function getBranchNameField() {
		return $locale === 'ar' ? 'name_ar' : 'name_en';
	}

	function getBranchLocationField() {
		return $locale === 'ar' ? 'location_ar' : 'location_en';
	}

	// Helper function to get user display name
	function getUserDisplayName(user) {
		if (!user) return '';
		
		// Priority: hr_employees name > username
		const displayName = user.hr_employees?.name || user.username || `User ${user.id}`;
		
		return displayName;
	}

	// Helper function to get the correct position title based on locale
	function getPositionTitle(positionInfo) {
		if (!positionInfo) return '';
		
		const currentLocale = $locale;
		
		// Temporary mapping for Arabic position titles until database query is fixed
		const positionMapping = {
			'Marketing Manager': 'مدير التسويق',
			'Inventory Control Supervisor': 'مشرف مراقبة المخزون',
			'Analytics & Business Intelligence': 'تحليلات وذكاء الأعمال',
			'Shelf Stockers': 'مرص البضائع',
			'Vegetable Department Head': 'رئيس قسم الخضروات',
			'Quality Assurance Manager': 'مدير ضمان الجودة',
			'Cleaners': 'منظف',
			'Cheese Department Head': 'رئيس قسم الجبن',
			'CEO': 'الرئيس التنفيذي',
			'Accountant': 'محاسب',
			'Customer Service Supervisor': 'مشرف خدمة العملاء',
			'Finance Manager': 'مدير مالي',
			'Driver': 'سائق',
			'Branch Manager': 'مدير الفرع',
			'Inventory Manager': 'مدير المخزون',
			'Night Supervisors': 'مشرف ليلي',
			'Bakers': 'خباز',
			'Bakery Department Head': 'رئيس قسم المخبز',
			'Checkout Helpers': 'مساعد الدفع',
			'Vegetable Counter Staff': 'موظف عداد الخضروات',
			'Cheese Counter Staff': 'موظف عداد الجبن',
			'No Position': 'بدون منصب'
		};
		
		// If we're in Arabic locale, try mapping first, then fallback to Arabic field
		if (currentLocale === 'ar') {
			// Try mapping from English to Arabic
			const englishTitle = positionInfo.position_title_en || positionInfo.position_title;
			if (englishTitle && positionMapping[englishTitle]) {
				return positionMapping[englishTitle];
			}
			
			// Fallback to database Arabic field if available
			if (positionInfo.position_title_ar) {
				return positionInfo.position_title_ar;
			}
		}
		
		// Fallback to English or original position title
		return positionInfo.position_title_en || positionInfo.position_title || '';
	}

	onMount(async () => {
		await loadInitialData();
		// Auto-select employee from URL query param (from FAB QR scan)
		const employeeParam = $page.url.searchParams.get('employee');
		if (employeeParam && users.length > 0) {
			const val = employeeParam.trim().toLowerCase();
			const matched = users.find(u =>
				u.employee_id?.toLowerCase() === val ||
				u.id === employeeParam.trim() ||
				u.name_en?.toLowerCase() === val ||
				u.name_ar === employeeParam.trim()
			);
			if (matched) {
				selectUser(matched);
				notifications.add({ type: 'success', message: `User found: ${getUserDisplayName(matched)}` });
			} else {
				notifications.add({ type: 'error', message: `No employee matched for: ${employeeParam}` });
			}
			// Clean URL without reloading
			const url = new URL(window.location.href);
			url.searchParams.delete('employee');
			window.history.replaceState({}, '', url.pathname);
		}
		loading = false;
	});

	async function loadInitialData() {
		try {
			// Load branches
			const { data: branchData, error: branchError } = await supabase
				.from('branches')
				.select('id, name_en, name_ar, location_en, location_ar')
				.eq('is_active', true)
				.order('name_en');

			if (!branchError) {
				branches = branchData || [];
			}

			// Load ALL active employees (no branch filter)
			const { data: employeeData, error } = await supabase
				.from('hr_employee_master')
				.select(`
					id,
					user_id,
					name_en,
					name_ar,
					current_branch_id,
					current_position_id,
					hr_positions(
						id,
						position_title_en,
						position_title_ar
					)
				`)
				.in('employment_status', ['Job (With Finger)', 'Job (No Finger)', 'Remote Job'])
				.neq('user_id', 'e1fdaee2-97f0-4fc1-872f-9d99c6bd684b');

			if (error) {
				console.error('Error loading employees:', error);
				users = [];
				return;
			}

			const isAr = $locale === 'ar';
			users = (employeeData || []).map(emp => {
				const branch = (branchData || []).find(b => b.id === emp.current_branch_id);
				const branchName = branch ? (isAr ? (branch.name_ar || branch.name_en) : (branch.name_en || branch.name_ar)) : '';
				const branchLocation = branch ? (isAr ? (branch.location_ar || branch.location_en) : (branch.location_en || branch.location_ar)) : '';
				return {
					id: emp.user_id,
					username: emp.name_en || emp.name_ar || '',
					employee_id: emp.id,
					name_en: emp.name_en || '',
					name_ar: emp.name_ar || '',
					current_branch_id: emp.current_branch_id,
					branch_name: branchName,
					branch_location: branchLocation,
					hr_employees: {
						id: emp.id,
						name: isAr ? (emp.name_ar || emp.name_en || '') : (emp.name_en || emp.name_ar || '')
					},
					position_info: emp.hr_positions || null
				};
			});
		} catch (error) {
			console.error('Error loading initial data:', error);
		}
	}

	function selectUser(user) {
		selectedUser = user;
		showUserPopup = false;
		searchTerm = '';
	}

	function clearUser() {
		selectedUser = null;
	}

	async function saveAsDefaults() {
		if (!setAsDefaultSettings) return;

		try {
			const defaultsData = {
				user_id: $currentUser?.id,
				default_price_tag: priceTag,
				default_issue_type: issueType,
				default_priority: priority
			};

	const { error } = await supabase
		.from('quick_task_user_preferences')
		.upsert(defaultsData, { onConflict: 'user_id' });			if (error) {
				console.error('Error saving defaults:', error);
			} else {
				console.log('Defaults saved successfully');
			}
		} catch (error) {
			console.error('Error saving defaults:', error);
		}
	}

	async function assignTask() {
		if (!taskTitle || !selectedUser || !issueType || !priority) {
			notifications.add({ type: 'error', message: 'Please fill in all required fields and select a user.' });
			return;
		}

		isSubmitting = true;

		try {
		// Save defaults if requested
		await saveAsDefaults();

		// Create the quick task
		const { data: taskData, error: taskError } = await supabase
			.from('quick_tasks')
			.insert({
				title: taskTitle,
				description: taskDescription,
				price_tag: priceTag,
				issue_type: issueType,
				priority: priority,
				assigned_by: $currentUser?.id,
				assigned_to_branch_id: selectedBranch,
				require_task_finished: true, // Always required
				require_photo_upload: requirePhotoUpload,
				require_erp_reference: requireErpReference
			})
			.select()
			.single();			if (taskError) {
				console.error('Error creating task:', taskError);
				notifications.add({ type: 'error', message: 'Error creating task. Please try again.' });
				return;
			}

			console.log('📋 [QuickTask] Task created successfully:', taskData);

			// Upload files if any are selected
			let uploadedFiles = [];
			if (selectedFiles.length > 0) {
				console.log('📎 [QuickTask] Uploading', selectedFiles.length, 'files...');
				
				for (const selectedFile of selectedFiles) {
					try {
						// Generate unique filename
						const timestamp = Date.now();
						const randomString = Math.random().toString(36).substring(2, 15);
						const fileExtension = selectedFile.name.split('.').pop();
						const uniqueFileName = `quick-task-${timestamp}-${randomString}.${fileExtension}`;
						
						// Upload to Supabase storage
						console.log('⬆️ [QuickTask] Uploading file:', selectedFile.name);
						const uploadResult = await uploadToSupabase(selectedFile.file, 'quick-task-files', uniqueFileName);
						
					
					if (!uploadResult.error) {
						console.log('✅ [QuickTask] File uploaded successfully:', uploadResult.data);
						
						// Save file record to quick_task_files table (use admin client to bypass RLS)
						const { error: fileError } = await supabase
							.from('quick_task_files')
							.insert({
								quick_task_id: taskData.id,
								file_name: selectedFile.name,
								storage_path: uploadResult.data.path,
								file_type: selectedFile.type,
								file_size: selectedFile.size,
								mime_type: selectedFile.type,
								storage_bucket: 'quick-task-files',
								uploaded_by: $currentUser?.id,
								uploaded_at: new Date().toISOString()
							});							if (fileError) {
								console.error('❌ [QuickTask] Error saving file record:', fileError);
							} else {
								uploadedFiles.push({
									name: selectedFile.name,
									storage_path: uploadResult.data.path,
									size: selectedFile.size,
									type: selectedFile.type
								});
								console.log('✅ [QuickTask] File record saved successfully');
							}
						} else {
							console.error('❌ [QuickTask] File upload failed:', uploadResult.error);
						}
					} catch (uploadError) {
						console.error('❌ [QuickTask] Error uploading file:', uploadError);
					}
				}
				
				console.log('📎 [QuickTask] File upload complete. Uploaded files:', uploadedFiles.length);
			}

			// Create assignment for the selected user
			const assignment = {
				quick_task_id: taskData.id,
				assigned_to_user_id: selectedUser.id,
				require_task_finished: true,
				require_photo_upload: requirePhotoUpload,
				require_erp_reference: requireErpReference
			};

		console.log('📋 [QuickTask Mobile] Assignment Object to Insert:', assignment);

		const { data: insertedAssignments, error: assignmentError } = await supabase
			.from('quick_task_assignments')
			.insert([assignment])
			.select();

			if (assignmentError) {
				console.error('Error creating assignment:', assignmentError);
				notifications.add({ type: 'error', message: 'Error assigning task. Please try again.' });
				return;
			}

			// Success - show message and reset form
			const fileText = uploadedFiles.length > 0 ? ` ${uploadedFiles.length} file(s) uploaded.` : '';
			successMessage = getTranslation('mobile.quickTaskContent.success.taskCreated') + fileText;
			
			// Show success popup with task details
			successTaskData = {
				id: taskData.id,
				title: taskData.title || taskTitle,
				assignedUser: getUserDisplayName(selectedUser),
				filesUploaded: uploadedFiles.length,
				branch: selectedBranchName
			};
			showSuccessPopup = true;
			lastAssignedUser = selectedUser;
			
			// Also show banner message
			showSuccessMessage = true;
			
			// Reset form but keep defaults
			resetForm();
			
			// Hide banner message after 5 seconds
			setTimeout(() => {
				showSuccessMessage = false;
			}, 5000);

		} catch (error) {
			console.error('Error assigning task:', error);
			notifications.add({ type: 'error', message: 'Error assigning task. Please try again.' });
		} finally {
			isSubmitting = false;
		}
	}

	function resetForm() {
		// Clear form data
		taskTitle = '';
		taskDescription = '';
		customIssueType = '';
		selectedFiles = [];
		selectedUser = null;
		
		// Reset issue type selection if not saving defaults
		if (!setAsDefaultSettings) {
			issueTypeWithPrice = 'filling';
			issueType = 'filling';
			priority = 'medium';
		}
		
		// Reset completion requirements
		requirePhotoUpload = false;
		requireErpReference = false;
		requireFileUpload = false;
		
		// Reset UI state
		searchTerm = '';
	}

	function closeSuccessPopup() {
		showSuccessPopup = false;
		successTaskData = null;
	}

	function assignAgainSameUser() {
		if (lastAssignedUser) {
			selectedUser = lastAssignedUser;
		}
		closeSuccessPopup();
	}

	function assignToNewUser() {
		selectedUser = null;
		closeSuccessPopup();
		// Open user selection popup
		showUserPopup = true;
		searchTerm = '';
	}

	// File Upload Functions
	function openFileBrowser() {
		fileInput.click();
	}

	function handleFileSelect(event) {
		const files = Array.from(event.target.files);
		files.forEach(file => {
			if (isValidFileType(file)) {
				selectedFiles = [...selectedFiles, {
					file,
					name: file.name,
					size: file.size,
					type: file.type,
					id: Date.now() + Math.random()
				}];
			} else {
				notifications.add({ type: 'error', message: `File type not supported: ${file.name}` });
			}
		});
		// Reset file input so same file can be selected again
		event.target.value = '';
	}

	function removeFile(fileId) {
		selectedFiles = selectedFiles.filter(f => f.id !== fileId);
	}

	function isValidFileType(file) {
		const allowedTypes = [
			'image/jpeg', 'image/png', 'image/gif', 'image/webp',
			'application/pdf',
			'application/vnd.ms-excel',
			'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
			'application/msword',
			'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
			'text/plain', 'text/csv'
		];
		return allowedTypes.includes(file.type);
	}

	function formatFileSize(bytes) {
		if (bytes === 0) return '0 Bytes';
		const k = 1024;
		const sizes = ['Bytes', 'KB', 'MB', 'GB'];
		const i = Math.floor(Math.log(bytes) / Math.log(k));
		return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
	}

	// Camera Functions
	function openCamera() {
		cameraInput.click();
	}

	function handleCameraCapture(event) {
		const files = Array.from(event.target.files);
		if (files.length > 0 && isValidFileType(files[0])) {
			openImageEditor(files[0]);
		}
		event.target.value = '';
	}

	// Image Editor Functions
	function openImageEditor(file) {
		const reader = new FileReader();
		reader.onload = (e) => {
			const img = new Image();
			img.onload = () => {
				editorImage = img;
				editorFileEntry = {
					name: file.name,
					type: file.type,
					originalFile: file
				};
				showImageEditor = true;
				editorHistory = [];
				editorMode = 'draw';
				textPosition = null;
				textInput = '';
				// Wait for canvas to mount
				setTimeout(() => initEditorCanvas(), 50);
			};
			img.src = /** @type {string} */ (e.target?.result);
		};
		reader.readAsDataURL(file);
	}

	function initEditorCanvas() {
		if (!editorCanvas || !editorImage) return;
		editorCtx = editorCanvas.getContext('2d');

		// Scale image to fit canvas while maintaining aspect ratio
		const maxW = Math.min(window.innerWidth - 32, 600);
		const maxH = Math.min(window.innerHeight - 200, 500);
		const scale = Math.min(maxW / editorImage.width, maxH / editorImage.height, 1);
		editorCanvas.width = editorImage.width * scale;
		editorCanvas.height = editorImage.height * scale;
		editorCtx.drawImage(editorImage, 0, 0, editorCanvas.width, editorCanvas.height);
		saveEditorState();
	}

	function saveEditorState() {
		if (!editorCtx || !editorCanvas) return;
		editorHistory = [...editorHistory, editorCtx.getImageData(0, 0, editorCanvas.width, editorCanvas.height)];
	}

	function editorUndo() {
		if (editorHistory.length <= 1) return;
		editorHistory = editorHistory.slice(0, -1);
		editorCtx.putImageData(editorHistory[editorHistory.length - 1], 0, 0);
	}

	function getCanvasPos(e) {
		const rect = editorCanvas.getBoundingClientRect();
		const clientX = e.touches ? e.touches[0].clientX : e.clientX;
		const clientY = e.touches ? e.touches[0].clientY : e.clientY;
		return {
			x: clientX - rect.left,
			y: clientY - rect.top
		};
	}

	function editorPointerDown(e) {
		if (!editorCtx) return;
		e.preventDefault();
		const pos = getCanvasPos(e);
		if (editorMode === 'text') {
			textPosition = pos;
			return;
		}
		isDrawing = true;
		lastX = pos.x;
		lastY = pos.y;
	}

	function editorPointerMove(e) {
		if (!isDrawing || !editorCtx || editorMode !== 'draw') return;
		e.preventDefault();
		const pos = getCanvasPos(e);
		editorCtx.beginPath();
		editorCtx.moveTo(lastX, lastY);
		editorCtx.lineTo(pos.x, pos.y);
		editorCtx.strokeStyle = editorColor;
		editorCtx.lineWidth = editorLineWidth;
		editorCtx.lineCap = 'round';
		editorCtx.lineJoin = 'round';
		editorCtx.stroke();
		lastX = pos.x;
		lastY = pos.y;
	}

	function editorPointerUp() {
		if (isDrawing) {
			isDrawing = false;
			saveEditorState();
		}
	}

	function editorPlaceText() {
		if (!textPosition || !textInput.trim() || !editorCtx) return;
		editorCtx.font = `bold ${editorLineWidth * 6 + 12}px sans-serif`;
		editorCtx.fillStyle = editorColor;
		editorCtx.fillText(textInput.trim(), textPosition.x, textPosition.y);
		saveEditorState();
		textInput = '';
		textPosition = null;
	}

	function editorSave() {
		if (!editorCanvas || !editorFileEntry) return;
		editorCanvas.toBlob((blob) => {
			if (!blob) return;
			const editedFile = new File([blob], editorFileEntry.name, { type: editorFileEntry.type || 'image/jpeg' });
			selectedFiles = [...selectedFiles, {
				file: editedFile,
				name: editedFile.name,
				size: editedFile.size,
				type: editedFile.type,
				id: Date.now() + Math.random()
			}];
			closeImageEditor();
		}, editorFileEntry.type || 'image/jpeg', 0.9);
	}

	function editorSaveSkip() {
		// Save original without edits
		if (!editorFileEntry) return;
		selectedFiles = [...selectedFiles, {
			file: editorFileEntry.originalFile,
			name: editorFileEntry.name,
			size: editorFileEntry.originalFile.size,
			type: editorFileEntry.type,
			id: Date.now() + Math.random()
		}];
		closeImageEditor();
	}

	// QR Scanner Functions
	async function startQRScan() {
		scanningQR = true;
		try {
			scanStream = await navigator.mediaDevices.getUserMedia({
				video: { facingMode: 'environment', width: { ideal: 1280 }, height: { ideal: 720 } }
			});
			await new Promise(r => setTimeout(r, 100));
			if (scanVideoEl) {
				scanVideoEl.srcObject = scanStream;
				await scanVideoEl.play();
				await new Promise(r => setTimeout(r, 500));
				await initQRDetector();
				detectQR();
			}
		} catch (err) {
			console.error('Camera access error:', err);
			scanningQR = false;
		}
	}

	async function initQRDetector() {
		// @ts-ignore
		if ('BarcodeDetector' in window) {
			try {
				// @ts-ignore
				scanBarcodeDetector = new window.BarcodeDetector({ formats: ['qr_code', 'code_128', 'code_39', 'ean_13'] });
				return;
			} catch (e) { /* fallback */ }
		}
		try {
			const { BarcodeDetector: Polyfill } = await import('barcode-detector');
			scanBarcodeDetector = new Polyfill({ formats: ['qr_code', 'code_128', 'code_39', 'ean_13'] });
		} catch (e) {
			console.error('Failed to load barcode detector:', e);
		}
	}

	function detectQR() {
		if (!scanBarcodeDetector) { stopQRScan(); return; }
		scanCanvas = document.createElement('canvas');
		scanCtx = scanCanvas.getContext('2d');

		scanInterval = setInterval(async () => {
			if (!scanVideoEl || scanVideoEl.readyState < 2 || !scanCanvas || !scanCtx) return;
			try {
				const vw = scanVideoEl.videoWidth;
				const vh = scanVideoEl.videoHeight;
				if (vw === 0 || vh === 0) return;
				scanCanvas.width = vw;
				scanCanvas.height = vh;
				scanCtx.drawImage(scanVideoEl, 0, 0, vw, vh);

				let barcodes = [];
				try {
					barcodes = await scanBarcodeDetector.detect(scanCanvas);
				} catch (_) {
					try {
						const imageData = scanCtx.getImageData(0, 0, vw, vh);
						barcodes = await scanBarcodeDetector.detect(imageData);
					} catch (__) {}
				}

				if (barcodes.length > 0) {
					const scannedValue = barcodes[0].rawValue;
					stopQRScan();
					matchScannedUser(scannedValue);
				}
			} catch (_) {}
		}, 400);
	}

	function stopQRScan() {
		if (scanInterval) { clearInterval(scanInterval); scanInterval = null; }
		if (scanStream) { scanStream.getTracks().forEach(t => t.stop()); scanStream = null; }
		scanCanvas = null;
		scanCtx = null;
		scanningQR = false;
	}

	function matchScannedUser(scannedValue) {
		if (!scannedValue) return;
		const val = scannedValue.trim().toLowerCase();
		// Match by employee_id (e.g. EMP55), user_id (UUID), or name
		const matched = users.find(u =>
			u.employee_id?.toLowerCase() === val ||
			u.id === scannedValue.trim() ||
			u.name_en?.toLowerCase() === val ||
			u.name_ar === scannedValue.trim()
		);
		if (matched) {
			selectUser(matched);
			notifications.add({ type: 'success', message: `User found: ${getUserDisplayName(matched)}` });
		} else {
			notifications.add({ type: 'error', message: `No employee matched for: ${scannedValue}` });
		}
	}

	function closeImageEditor() {
		showImageEditor = false;
		editorImage = null;
		editorFileEntry = null;
		editorCtx = null;
		editorHistory = [];
		textPosition = null;
		textInput = '';
	}
</script>

<svelte:head>
	<title>{getTranslation('mobile.quickTaskContent.title')}</title>
</svelte:head>

<div class="quick-task-page" dir={$currentLocale === 'ar' ? 'rtl' : 'ltr'}>
	{#if loading}
		<div class="loading">
			<div class="spinner"></div>
			<p>{getTranslation('mobile.quickTaskContent.loading')}</p>
		</div>
	{:else}
		<!-- Success Message -->
		{#if showSuccessMessage}
			<div class="success-message">
				<div class="success-content">
					<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"></path>
						<polyline points="22,4 12,14.01 9,11.01"></polyline>
					</svg>
					<p>{successMessage}</p>
				</div>
				<button class="close-success" on:click={() => showSuccessMessage = false}>
					<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<line x1="18" y1="6" x2="6" y2="18"></line>
						<line x1="6" y1="6" x2="18" y2="18"></line>
					</svg>
				</button>
			</div>
		{/if}

		<!-- Success Popup Modal -->
		{#if showSuccessPopup && successTaskData}
			<div class="popup-overlay" on:click={closeSuccessPopup}>
				<div class="popup-modal" on:click|stopPropagation>
					<div class="popup-header">
						<div class="success-icon">
							<svg width="64" height="64" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"></path>
								<polyline points="22,4 12,14.01 9,11.01"></polyline>
							</svg>
						</div>
						<h2>✅ {getTranslation('mobile.quickTaskContent.success.taskCreated')}</h2>
					</div>
					
					<div class="popup-content">
						<div class="task-detail">
							<span class="detail-label">📋 {getTranslation('mobile.quickTaskContent.issueTypeLabel')}</span>
							<span class="detail-value">{successTaskData.title}</span>
						</div>
						
						<div class="task-detail">
							<span class="detail-label">👤 {getTranslation('mobile.quickTaskContent.step2.usersLabel')}</span>
							<span class="detail-value">{successTaskData.assignedUser}</span>
						</div>

						<div class="task-detail">
							<span class="detail-label">🏢 {getTranslation('mobile.quickTaskContent.step1.branchLabel')}</span>
							<span class="detail-value">{successTaskData.branch}</span>
						</div>
						
						{#if successTaskData.filesUploaded > 0}
							<div class="task-detail">
								<span class="detail-label">📎 {getTranslation('mobile.quickTaskContent.filesLabel')}</span>
								<span class="detail-value">{successTaskData.filesUploaded} file(s)</span>
							</div>
						{/if}
					</div>
					
					<div class="popup-actions stacked">
						<button class="popup-btn primary" on:click={assignAgainSameUser}>
							🔄 Assign Again to Same User
						</button>
						<button class="popup-btn secondary" on:click={assignToNewUser}>
							👤 Assign to New User
						</button>
					</div>
				</div>
			</div>
		{/if}

		<!-- Step 1: Select User -->
		<div class="form-section">
			<div class="section-header-row">
				<h3>{getTranslation('mobile.quickTaskContent.step2.title')}</h3>
				<div class="header-actions">
					<button type="button" class="scan-qr-btn" on:click={startQRScan} title="Scan QR">
						<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<path d="M3 7V5a2 2 0 0 1 2-2h2"/><path d="M17 3h2a2 2 0 0 1 2 2v2"/>
							<path d="M21 17v2a2 2 0 0 1-2 2h-2"/><path d="M7 21H5a2 2 0 0 1-2-2v-2"/>
							<rect x="7" y="7" width="4" height="4"/><rect x="13" y="7" width="4" height="4"/><rect x="7" y="13" width="4" height="4"/>
						</svg>
					</button>
					<button type="button" class="select-users-btn" on:click={() => { showUserPopup = true; searchTerm = ''; }}>
						{#if selectedUser}
							<span>{getTranslation('mobile.quickTaskContent.step1.change')}</span>
						{:else}
							<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>
							<span>{getTranslation('mobile.quickTaskContent.step2.usersLabel')}</span>
						{/if}
					</button>
				</div>
			</div>
			{#if selectedUser}
				<div class="selected-users-preview">
					<span class="user-chip">
						{getUserDisplayName(selectedUser)}
						<button type="button" class="chip-remove" on:click={clearUser}>&times;</button>
					</span>
					{#if selectedBranchName}
						<span class="branch-auto-badge">🏢 {selectedBranchName}</span>
					{/if}
				</div>
			{/if}
		</div>

		<!-- User Selection Popup -->
		{#if showUserPopup}
			<div class="user-popup-overlay" on:click={() => showUserPopup = false} role="button" tabindex="-1" on:keydown={(e) => e.key === 'Escape' && (showUserPopup = false)}>
				<div class="user-popup" on:click|stopPropagation role="none">
					<div class="user-popup-header">
						<span>{getTranslation('mobile.quickTaskContent.step2.title')}</span>
						<button type="button" class="user-popup-close" on:click={() => showUserPopup = false}>&times;</button>
					</div>
					<div class="user-popup-search">
						<input 
							type="text" 
							placeholder={getTranslation('mobile.quickTaskContent.step2.searchPlaceholder')}
							bind:value={searchTerm}
							class="search-input"
						/>
					</div>
					<div class="user-popup-list">
						{#if users.length > 0}
							{#each filteredUsers as user}
								<button type="button" class="user-item-btn" class:selected={selectedUser?.id === user.id} on:click={() => selectUser(user)}>
									<div class="user-item-info">
										<span class="user-name">{getUserDisplayName(user)}</span>
									</div>
									<div class="user-item-branch">
										<span class="user-branch-label">{user.branch_name}</span>
										{#if user.branch_location}
											<span class="user-branch-location">{user.branch_location}</span>
										{/if}
									</div>
								</button>
							{/each}
						{:else}
							<p class="no-users">No users found</p>
						{/if}
					</div>
				</div>
			</div>
		{/if}

		<!-- QR Scanner Overlay -->
		{#if scanningQR}
			<div class="scanner-overlay" on:click={stopQRScan} role="button" tabindex="-1" on:keydown={(e) => e.key === 'Escape' && stopQRScan()}>
				<div class="scanner-container" on:click|stopPropagation role="none">
					<div class="scanner-header">
						<span>📷 Scan Employee QR / ID</span>
						<button type="button" class="scanner-close" on:click={stopQRScan}>&times;</button>
					</div>
					<div class="scanner-video-wrapper">
						<!-- svelte-ignore a11y-media-has-caption -->
						<video bind:this={scanVideoEl} playsinline autoplay muted class="scanner-video"></video>
						<div class="scan-line"></div>
					</div>
				</div>
			</div>
		{/if}

		{#if selectedUser}

			<!-- Step 3: Task Details -->
			<div class="form-section">
				<h3>{getTranslation('mobile.quickTaskContent.step3.title')}</h3>
				
				<div class="form-group">
					<label>{getTranslation('mobile.quickTaskContent.step3.issueType')}</label>
					<select bind:value={issueTypeWithPrice} class="form-select">
						<option value="">{getTranslation('mobile.quickTaskContent.step3.selectIssueType')}</option>
						{#each issueTypeOptions as option}
							<option value={option.value}>{option.label}</option>
						{/each}
					</select>
				</div>

				{#if issueType === 'other'}
					<div class="form-group">
						<label>{getTranslation('mobile.quickTaskContent.step3.customIssueType')}</label>
						<input 
							type="text" 
							bind:value={customIssueType}
							placeholder={getTranslation('mobile.quickTaskContent.step3.customIssuePlaceholder')}
							class="form-input"
						/>
					</div>
				{/if}

				<div class="form-group">
					<label>{getTranslation('mobile.quickTaskContent.step3.priority')}</label>
					<select bind:value={priority} class="form-select">
						{#each priorityOptions as option}
							<option value={option.value}>{option.label}</option>
						{/each}
					</select>
				</div>

				<div class="form-group">
					<label>{getTranslation('mobile.quickTaskContent.step3.description')}</label>
					<textarea 
						bind:value={taskDescription}
						placeholder={getTranslation('mobile.quickTaskContent.step3.descriptionPlaceholder')}
						class="form-textarea"
						rows="3"
					></textarea>
				</div>

				<label class="checkbox-label">
					<input type="checkbox" bind:checked={setAsDefaultSettings} />
					{getTranslation('mobile.quickTaskContent.step3.saveAsDefault')}
				</label>
			</div>

			<!-- Step 4: File Attachments -->
			<div class="form-section">
				<h3>{getTranslation('mobile.quickTaskContent.step4.title')}</h3>
				
				<div class="file-actions">
					<button type="button" on:click={openFileBrowser} class="file-btn">
						<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path>
							<polyline points="14,2 14,8 20,8"></polyline>
							<line x1="16" y1="13" x2="8" y2="13"></line>
							<line x1="16" y1="17" x2="8" y2="17"></line>
							<polyline points="10,9 9,9 8,9"></polyline>
						</svg>
						{getTranslation('mobile.quickTaskContent.step4.chooseFiles')}
					</button>
					<button type="button" on:click={openCamera} class="file-btn camera-btn">
						<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z"></path>
							<circle cx="12" cy="13" r="4"></circle>
						</svg>
						{getTranslation('mobile.quickTaskContent.step4.camera')}
					</button>
				</div>

				{#if selectedFiles.length > 0}
					<div class="file-list">
						{#each selectedFiles as file}
							<div class="file-item">
								<div class="file-info">
									<span class="file-name">{file.name}</span>
									<span class="file-size">{formatFileSize(file.size)}</span>
								</div>
								<button type="button" on:click={() => removeFile(file.id)} class="remove-file-btn">
									<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
										<line x1="18" y1="6" x2="6" y2="18"></line>
										<line x1="6" y1="6" x2="18" y2="18"></line>
									</svg>
									<span class="sr-only">{getTranslation('mobile.quickTaskContent.step4.removeFile')}</span>
								</button>
							</div>
						{/each}
					</div>
				{/if}
			</div>

			<!-- Step 5: Completion Requirements -->
			<div class="form-section">
				<h3>{getTranslation('mobile.quickTaskContent.step5.title')}</h3>
				<div class="requirements-list">
					<label class="checkbox-label">
						<input type="checkbox" bind:checked={requirePhotoUpload} />
						{getTranslation('mobile.quickTaskContent.step5.requirePhoto')}
					</label>
					<label class="checkbox-label">
						<input type="checkbox" bind:checked={requireErpReference} />
						{getTranslation('mobile.quickTaskContent.step5.requireErp')}
					</label>
					<label class="checkbox-label">
						<input type="checkbox" bind:checked={requireFileUpload} />
						{getTranslation('mobile.quickTaskContent.step5.requireFile')}
					</label>
				</div>
			</div>

			<!-- Submit Button -->
			<div class="form-section">
				<button 
					type="button" 
					on:click={assignTask} 
					class="assign-btn"
					disabled={isSubmitting || !taskTitle || !selectedUser || !issueType || !priority}
				>
					{#if isSubmitting}
						<div class="btn-spinner"></div>
						{getTranslation('mobile.quickTaskContent.actions.creatingTask')}
					{:else}
						{getTranslation('mobile.quickTaskContent.actions.assignTask')}
					{/if}
				</button>
			</div>
		{/if}
	{/if}
</div>

<!-- Image Editor Modal -->
{#if showImageEditor}
	<div class="editor-overlay">
		<div class="editor-modal">
			<div class="editor-header">
				<span class="editor-title">Edit Photo</span>
				<button type="button" class="editor-close-btn" on:click={closeImageEditor}>&times;</button>
			</div>

			<!-- Toolbar -->
			<div class="editor-toolbar">
				<button type="button" class="editor-tool-btn" class:active={editorMode === 'draw'} on:click={() => { editorMode = 'draw'; textPosition = null; }} title="Draw">
					<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 19l7-7 3 3-7 7-3-3z"/><path d="M18 13l-1.5-7.5L2 2l3.5 14.5L13 18l5-5z"/><path d="M2 2l7.586 7.586"/></svg>
				</button>
				<button type="button" class="editor-tool-btn" class:active={editorMode === 'text'} on:click={() => editorMode = 'text'} title="Text">
					<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="4,7 4,4 20,4 20,7"/><line x1="9.5" y1="4" x2="9.5" y2="20"/><line x1="14.5" y1="4" x2="14.5" y2="20"/><line x1="7" y1="20" x2="17" y2="20"/></svg>
				</button>
				<div class="editor-separator"></div>
				<input type="color" bind:value={editorColor} class="editor-color-picker" title="Color" />
				<select bind:value={editorLineWidth} class="editor-size-select">
					<option value={2}>Thin</option>
					<option value={3}>Medium</option>
					<option value={5}>Thick</option>
					<option value={8}>Extra Thick</option>
				</select>
				<div class="editor-separator"></div>
				<button type="button" class="editor-tool-btn" on:click={editorUndo} title="Undo" disabled={editorHistory.length <= 1}>
					<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="1,4 1,10 7,10"/><path d="M3.51 15a9 9 0 1 0 2.13-9.36L1 10"/></svg>
				</button>
			</div>

			<!-- Canvas -->
			<div class="editor-canvas-wrap">
				<canvas
					bind:this={editorCanvas}
					on:mousedown={editorPointerDown}
					on:mousemove={editorPointerMove}
					on:mouseup={editorPointerUp}
					on:mouseleave={editorPointerUp}
					on:touchstart={editorPointerDown}
					on:touchmove={editorPointerMove}
					on:touchend={editorPointerUp}
					class="editor-canvas"
					style="cursor: {editorMode === 'text' ? 'text' : 'crosshair'}"
				></canvas>
				{#if editorMode === 'text' && textPosition}
					<div class="editor-text-input-wrap" style="left: {textPosition.x}px; top: {textPosition.y}px;">
						<input
							type="text"
							bind:value={textInput}
							placeholder="Type here..."
							class="editor-text-field"
							style="color: {editorColor}; font-size: {editorLineWidth * 6 + 12}px;"
							on:keydown={(e) => e.key === 'Enter' && editorPlaceText()}
						/>
						<button type="button" class="editor-text-ok" on:click={editorPlaceText}>OK</button>
					</div>
				{/if}
			</div>

			<!-- Footer Actions -->
			<div class="editor-footer">
				<button type="button" class="editor-btn secondary" on:click={editorSaveSkip}>
					Skip Editing
				</button>
				<button type="button" class="editor-btn primary" on:click={editorSave}>
					Save & Attach
				</button>
			</div>
		</div>
	</div>
{/if}

<!-- Hidden file inputs -->
<input 
	type="file" 
	bind:this={fileInput}
	on:change={handleFileSelect}
	accept="image/*,.pdf,.doc,.docx,.xls,.xlsx,.txt,.csv"
	multiple
	style="display: none;"
/>
<input 
	type="file" 
	bind:this={cameraInput}
	on:change={handleCameraCapture}
	accept="image/*"
	capture="environment"
	style="display: none;"
/>

<style>
	.quick-task-page {
		padding: 0;
		padding-bottom: 0.5rem;
		min-height: 100%;
		background: #F8FAFC;
		display: flex;
		flex-direction: column;
	}

	.loading {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 1.5rem;
		color: #666;
	}

	.spinner {
		width: 32px;
		height: 32px;
		border: 3px solid #f3f3f3;
		border-top: 3px solid #007bff;
		border-radius: 50%;
		animation: spin 1s linear infinite;
		margin-bottom: 1rem;
	}

	@keyframes spin {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}

	/* Section header with inline button */
	.section-header-row {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 0.4rem;
		margin-bottom: 0.3rem;
	}

	.section-header-row h3 {
		margin: 0 !important;
	}

	.select-users-btn {
		display: flex;
		align-items: center;
		gap: 0.3rem;
		padding: 0.3rem 0.65rem;
		background: #007bff;
		color: white;
		border: none;
		border-radius: 6px;
		font-size: 0.88rem;
		font-weight: 600;
		cursor: pointer;
		white-space: nowrap;
	}

	.select-users-btn:active {
		background: #0056b3;
	}

	.chip-remove {
		background: none;
		border: none;
		color: #0066cc;
		font-size: 0.85rem;
		cursor: pointer;
		padding: 0;
		margin-left: 0.15rem;
		line-height: 1;
		font-weight: 700;
	}

	.chip-remove:active {
		color: #EF4444;
	}

	/* User Selection Popup */
	.user-popup-overlay {
		position: fixed;
		inset: 0;
		background: rgba(0, 0, 0, 0.5);
		z-index: 1000;
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 0.75rem;
	}

	.user-popup {
		background: white;
		border-radius: 12px;
		width: 100%;
		max-width: 360px;
		max-height: 65vh;
		display: flex;
		flex-direction: column;
		overflow: hidden;
		margin-bottom: 4rem;
	}

	.user-popup-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 0.65rem 0.85rem;
		border-bottom: 1px solid #E5E7EB;
		font-weight: 700;
		font-size: 0.9rem;
		color: #111827;
		flex-shrink: 0;
	}

	.user-popup-close {
		background: none;
		border: none;
		font-size: 1.3rem;
		cursor: pointer;
		color: #6B7280;
		line-height: 1;
		padding: 0 0.2rem;
	}

	.user-popup-search {
		padding: 0.5rem 0.75rem;
		border-bottom: 1px solid #F3F4F6;
		flex-shrink: 0;
	}

	.user-popup-search .search-input {
		margin-bottom: 0;
	}

	.user-popup-list {
		flex: 1;
		overflow-y: auto;
		-webkit-overflow-scrolling: touch;
		min-height: 0;
	}

	/* Success Message Styles */
	.success-message {
		background: linear-gradient(135deg, #10B981, #059669);
		color: white;
		margin: 0.35rem 0.5rem;
		padding: 0.5rem 0.65rem;
		border-radius: 6px;
		box-shadow: 0 1px 4px rgba(16, 185, 129, 0.3);
		position: relative;
		animation: slideIn 0.3s ease-out;
	}

	.success-content {
		display: flex;
		align-items: center;
		gap: 0.35rem;
	}

	.success-content svg {
		flex-shrink: 0;
		color: white;
	}

	.success-content p {
		margin: 0;
		font-weight: 600;
		font-size: 0.9rem;
		line-height: 1.3;
	}

	.close-success {
		position: absolute;
		top: 0.25rem;
		right: 0.25rem;
		background: rgba(255, 255, 255, 0.2);
		border: none;
		border-radius: 50%;
		width: 24px;
		height: 24px;
		display: flex;
		align-items: center;
		justify-content: center;
		cursor: pointer;
		transition: background-color 0.15s;
	}

	.close-success:active {
		background: rgba(255, 255, 255, 0.3);
	}

	.close-success svg {
		color: white;
	}

	@keyframes slideIn {
		from {
			opacity: 0;
			transform: translateY(-10px);
		}
		to {
			opacity: 1;
			transform: translateY(0);
		}
	}

	.form-section {
		background: white;
		border-radius: 8px;
		padding: 0.65rem 0.75rem;
		margin: 0 0.5rem 0.5rem;
		box-shadow: 0 1px 4px rgba(0, 0, 0, 0.05);
	}

	.form-section h3 {
		margin: 0 0 0.5rem 0;
		font-size: 0.95rem;
		font-weight: 700;
		color: #374151;
	}

	.form-select, .form-input, .form-textarea {
		width: 100%;
		padding: 0.35rem 0.5rem;
		border: 1px solid #D1D5DB;
		border-radius: 0.375rem;
		font-size: 0.9rem;
		margin-bottom: 0.5rem;
		box-sizing: border-box;
		height: 2rem;
	}

	.form-textarea {
		height: auto;
	}

	/* RTL Support for select dropdown arrow */
	:global([dir="rtl"]) .form-select {
		padding-right: 0.5rem;
		padding-left: 1.5rem;
		background-position: left 0.5rem center;
	}

	.form-select:focus, .form-input:focus, .form-textarea:focus {
		outline: none;
		border-color: #007bff;
		box-shadow: 0 0 0 3px rgba(0, 123, 255, 0.1);
	}

	.form-group {
		margin-bottom: 0.6rem;
	}

	.form-group:last-child {
		margin-bottom: 0;
	}

	.form-group label {
		display: block;
		margin-bottom: 0.15rem;
		font-weight: 600;
		color: #374151;
		font-size: 0.88rem;
	}

	.checkbox-label {
		display: flex;
		align-items: center;
		gap: 0.4rem;
		margin-bottom: 0.4rem;
		cursor: pointer;
		font-size: 0.9rem;
		padding: 0.35rem 0.5rem;
		background: #f8f9fa;
		border-radius: 6px;
		border: 1px solid transparent;
		transition: all 0.15s ease;
	}

	.checkbox-label:active {
		background: #e9ecef;
		border-color: #007bff;
	}

	.checkbox-label input[type="checkbox"] {
		width: 16px;
		height: 16px;
		margin: 0;
		cursor: pointer;
		accent-color: #007bff;
		border: 2px solid #007bff;
		border-radius: 3px;
		background: white;
		-webkit-appearance: none;
		-moz-appearance: none;
		appearance: none;
		position: relative;
		flex-shrink: 0;
	}

	.checkbox-label input[type="checkbox"]:checked {
		background: #007bff;
		border-color: #007bff;
	}

	.checkbox-label input[type="checkbox"]:checked::after {
		content: '✓';
		position: absolute;
		top: 50%;
		left: 50%;
		transform: translate(-50%, -50%);
		color: white;
		font-size: 11px;
		font-weight: bold;
	}

	.search-input {
		width: 100%;
		padding: 0.35rem 0.5rem;
		border: 1px solid #D1D5DB;
		border-radius: 0.375rem;
		margin-bottom: 0.4rem;
		font-size: 0.9rem;
		box-sizing: border-box;
		height: 2rem;
	}

	.user-item-btn {
		display: flex;
		align-items: center;
		justify-content: space-between;
		width: 100%;
		gap: 0.4rem;
		padding: 0.6rem 0.75rem;
		border: none;
		border-bottom: 1px solid #F3F4F6;
		cursor: pointer;
		background: white;
		transition: background 0.15s ease;
		text-align: start;
	}

	.user-item-btn:active, .user-item-btn.selected {
		background: #EBF5FF;
	}

	.user-item-btn:last-child {
		border-bottom: none;
	}

	.user-branch-label {
		font-size: 0.7rem;
		color: #6B7280;
		background: #F3F4F6;
		padding: 0.15rem 0.45rem;
		border-radius: 6px;
		white-space: nowrap;
	}

	.user-item-info {
		flex: 1;
		min-width: 0;
	}

	.user-item-branch {
		display: flex;
		flex-direction: column;
		align-items: flex-end;
		gap: 0.1rem;
		flex-shrink: 0;
	}

	.user-branch-location {
		font-size: 0.65rem;
		color: #9CA3AF;
	}

	.branch-auto-badge {
		display: inline-block;
		font-size: 0.75rem;
		color: #1D4ED8;
		background: #EFF6FF;
		padding: 0.2rem 0.5rem;
		border-radius: 8px;
		margin-top: 0.25rem;
	}

	.user-name {
		display: block;
		font-weight: 600;
		color: #111827;
		font-size: 0.9rem;
	}

	.selected-users-preview {
		display: flex;
		gap: 0.3rem;
		flex-wrap: wrap;
		margin-top: 0.25rem;
	}

	.user-chip {
		background: #e7f3ff;
		color: #0066cc;
		padding: 2px 6px;
		border-radius: 10px;
		font-size: 0.8rem;
		font-weight: 500;
	}

	.file-actions {
		display: flex;
		gap: 0.4rem;
		margin-bottom: 0.5rem;
	}

	.file-btn {
		display: flex;
		align-items: center;
		gap: 0.3rem;
		padding: 0.4rem 0.65rem;
		background: #F3F4F6;
		border: 1px solid #D1D5DB;
		border-radius: 6px;
		cursor: pointer;
		font-size: 0.9rem;
		font-weight: 600;
		color: #374151;
	}

	.file-btn:active {
		background: #E5E7EB;
	}

	.camera-btn {
		background: #10B981;
		color: white;
		border-color: #10B981;
	}

	.camera-btn:active {
		background: #059669;
	}

	.file-list {
		border: 1px solid #D1D5DB;
		border-radius: 6px;
		max-height: 100px;
		overflow-y: auto;
	}

	.file-item {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 0.35rem 0.5rem;
		border-bottom: 1px solid #F3F4F6;
	}

	.file-item:last-child {
		border-bottom: none;
	}

	.file-info {
		flex: 1;
	}

	.file-name {
		display: block;
		font-weight: 600;
		color: #111827;
		font-size: 0.88rem;
	}

	.file-size {
		display: block;
		font-size: 0.8rem;
		color: #6B7280;
	}

	.remove-file-btn {
		background: none;
		border: none;
		color: #EF4444;
		cursor: pointer;
		padding: 0.1rem 0.2rem;
		border-radius: 4px;
	}

	.remove-file-btn:active {
		background: #FEE2E2;
	}

	.requirements-list {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}

	.assign-btn {
		width: 100%;
		background: #10B981;
		color: white;
		border: none;
		padding: 0.55rem;
		border-radius: 8px;
		font-size: 0.95rem;
		font-weight: 600;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.35rem;
		box-shadow: 0 2px 8px rgba(16, 185, 129, 0.3);
	}

	.assign-btn:active:not(:disabled) {
		background: #059669;
	}

	.assign-btn:disabled {
		background: #9CA3AF;
		cursor: not-allowed;
		box-shadow: none;
	}

	.btn-spinner {
		width: 14px;
		height: 14px;
		border: 2px solid rgba(255, 255, 255, 0.3);
		border-top-color: white;
		border-radius: 50%;
		animation: spin 0.6s linear infinite;
	}

	.no-users {
		color: #6B7280;
		font-style: italic;
		text-align: center;
		padding: 0.75rem;
		font-size: 0.9rem;
	}

	/* Success Popup Modal */
	.popup-overlay {
		position: fixed;
		inset: 0;
		background: rgba(0, 0, 0, 0.5);
		z-index: 1000;
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 1rem;
		backdrop-filter: blur(4px);
		animation: fadeIn 0.3s ease-out;
	}

	@keyframes fadeIn {
		from {
			opacity: 0;
		}
		to {
			opacity: 1;
		}
	}

	.popup-modal {
		background: white;
		border-radius: 12px;
		max-width: 360px;
		width: 100%;
		box-shadow: 0 10px 40px rgba(0, 0, 0, 0.2);
		animation: slideUp 0.3s ease-out;
		overflow: hidden;
	}

	@keyframes slideUp {
		from {
			transform: translateY(50px);
			opacity: 0;
		}
		to {
			transform: translateY(0);
			opacity: 1;
		}
	}

	.popup-header {
		text-align: center;
		padding: 1rem 0.85rem 0.65rem;
		background: linear-gradient(135deg, #10B981 0%, #059669 100%);
		color: white;
	}

	.success-icon {
		margin-bottom: 0.5rem;
	}

	.success-icon svg {
		width: 64px;
		height: 64px;
		stroke: white;
		animation: checkmark 0.5s ease-out 0.2s;
		animation-fill-mode: both;
	}

	@keyframes checkmark {
		0% {
			transform: scale(0) rotate(-45deg);
		}
		50% {
			transform: scale(1.2) rotate(5deg);
		}
		100% {
			transform: scale(1) rotate(0deg);
		}
	}

	.popup-header h2 {
		margin: 0;
		font-size: 0.95rem;
		font-weight: 700;
		text-shadow: 0 1px 2px rgba(0, 0, 0, 0.1);
	}

	.popup-content {
		padding: 0.75rem 0.85rem;
	}

	.task-detail {
		display: flex;
		flex-direction: column;
		gap: 2px;
		padding: 0.4rem 0.5rem;
		background: #f8f9fa;
		border-radius: 6px;
		margin-bottom: 0.4rem;
	}

	.task-detail:last-child {
		margin-bottom: 0;
	}

	.detail-label {
		font-size: 0.7rem;
		color: #6B7280;
		font-weight: 600;
	}

	.detail-value {
		font-size: 0.8rem;
		color: #111827;
		font-weight: 600;
	}

	.popup-actions {
		padding: 0.65rem 0.85rem;
		background: #f8f9fa;
		border-top: 1px solid #E5E7EB;
	}

	.popup-actions.stacked {
		display: flex;
		flex-direction: column;
		gap: 0.4rem;
	}

	.popup-btn {
		width: 100%;
		padding: 0.5rem;
		border: none;
		border-radius: 8px;
		font-size: 0.85rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.15s;
	}

	.popup-btn.primary {
		background: #10B981;
		color: white;
	}

	.popup-btn.primary:active {
		background: #059669;
	}

	.popup-btn.secondary {
		background: #E5E7EB;
		color: #374151;
	}

	.popup-btn.secondary:active {
		background: #D1D5DB;
	}

	/* QR Scanner Styles */
	.header-actions {
		display: flex;
		align-items: center;
		gap: 0.3rem;
	}

	.scan-qr-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 32px;
		height: 32px;
		background: #047857;
		color: white;
		border: none;
		border-radius: 6px;
		cursor: pointer;
		flex-shrink: 0;
	}

	.scan-qr-btn:active {
		background: #065F46;
	}

	.scanner-overlay {
		position: fixed;
		inset: 0;
		background: rgba(0, 0, 0, 0.8);
		z-index: 1100;
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 1rem;
	}

	.scanner-container {
		background: #111;
		border-radius: 12px;
		overflow: hidden;
		width: 100%;
		max-width: 400px;
	}

	.scanner-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 0.75rem 1rem;
		color: white;
		font-weight: 600;
		font-size: 0.95rem;
	}

	.scanner-close {
		background: none;
		border: none;
		color: white;
		font-size: 1.5rem;
		cursor: pointer;
		line-height: 1;
		padding: 0 0.25rem;
	}

	.scanner-video-wrapper {
		position: relative;
		width: 100%;
		aspect-ratio: 4/3;
		background: #000;
	}

	.scanner-video {
		width: 100%;
		height: 100%;
		object-fit: cover;
	}

	.scan-line {
		position: absolute;
		left: 10%;
		right: 10%;
		height: 2px;
		background: #ff3b30;
		box-shadow: 0 0 8px rgba(255, 59, 48, 0.6);
		top: 50%;
		animation: scanMove 2s ease-in-out infinite;
	}

	@keyframes scanMove {
		0%, 100% { top: 30%; }
		50% { top: 70%; }
	}

	/* Image Editor Styles */
	.editor-overlay {
		position: fixed;
		top: 0; left: 0; right: 0; bottom: 0;
		background: rgba(0,0,0,0.85);
		z-index: 9999;
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 0.5rem;
	}

	.editor-modal {
		background: white;
		border-radius: 12px;
		width: 100%;
		max-width: 640px;
		max-height: 95vh;
		display: flex;
		flex-direction: column;
		overflow: hidden;
	}

	.editor-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 0.6rem 0.8rem;
		border-bottom: 1px solid #E5E7EB;
	}

	.editor-title {
		font-weight: 700;
		font-size: 1rem;
		color: #111827;
	}

	.editor-close-btn {
		background: none;
		border: none;
		font-size: 1.5rem;
		color: #6B7280;
		cursor: pointer;
		padding: 0 0.3rem;
		line-height: 1;
	}

	.editor-toolbar {
		display: flex;
		align-items: center;
		gap: 0.35rem;
		padding: 0.4rem 0.6rem;
		border-bottom: 1px solid #F3F4F6;
		background: #FAFAFA;
		flex-wrap: wrap;
	}

	.editor-tool-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 34px;
		height: 34px;
		border: 1px solid #D1D5DB;
		border-radius: 6px;
		background: white;
		cursor: pointer;
		color: #374151;
		transition: all 0.15s;
	}

	.editor-tool-btn.active {
		background: #007bff;
		color: white;
		border-color: #007bff;
	}

	.editor-tool-btn:disabled {
		opacity: 0.4;
		cursor: not-allowed;
	}

	.editor-separator {
		width: 1px;
		height: 24px;
		background: #D1D5DB;
		margin: 0 0.15rem;
	}

	.editor-color-picker {
		width: 34px;
		height: 34px;
		border: 1px solid #D1D5DB;
		border-radius: 6px;
		padding: 2px;
		cursor: pointer;
		background: white;
	}

	.editor-size-select {
		height: 34px;
		border: 1px solid #D1D5DB;
		border-radius: 6px;
		padding: 0 0.3rem;
		font-size: 0.8rem;
		background: white;
		cursor: pointer;
	}

	.editor-canvas-wrap {
		flex: 1;
		overflow: auto;
		display: flex;
		align-items: center;
		justify-content: center;
		background: #f0f0f0;
		position: relative;
		min-height: 200px;
		-webkit-overflow-scrolling: touch;
	}

	.editor-canvas {
		display: block;
		touch-action: none;
		max-width: 100%;
	}

	.editor-text-input-wrap {
		position: absolute;
		display: flex;
		align-items: center;
		gap: 0.25rem;
		z-index: 10;
	}

	.editor-text-field {
		background: rgba(255,255,255,0.85);
		border: 2px solid #007bff;
		border-radius: 4px;
		padding: 0.2rem 0.4rem;
		font-weight: bold;
		font-family: sans-serif;
		outline: none;
		min-width: 100px;
		max-width: 200px;
	}

	.editor-text-ok {
		background: #007bff;
		color: white;
		border: none;
		border-radius: 4px;
		padding: 0.25rem 0.5rem;
		font-size: 0.8rem;
		font-weight: 600;
		cursor: pointer;
	}

	.editor-footer {
		display: flex;
		gap: 0.5rem;
		padding: 0.5rem 0.8rem;
		border-top: 1px solid #E5E7EB;
	}

	.editor-btn {
		flex: 1;
		padding: 0.55rem 0.75rem;
		border-radius: 8px;
		font-size: 0.9rem;
		font-weight: 600;
		cursor: pointer;
		border: none;
		text-align: center;
	}

	.editor-btn.secondary {
		background: #F3F4F6;
		color: #374151;
	}

	.editor-btn.primary {
		background: #10B981;
		color: white;
	}

	.editor-btn.primary:active {
		background: #059669;
	}

	.editor-btn.secondary:active {
		background: #E5E7EB;
	}
</style>
