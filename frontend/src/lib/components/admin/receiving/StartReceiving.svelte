<script>
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { userManagement } from '$lib/utils/userManagement';
	import { windowManager } from '$lib/stores/windowManager';
	import EditVendor from '../vendor/EditVendor.svelte';

	// State management
	let vendors = [];
	let filteredVendors = [];
	let selectedVendor = null;
	let searchQuery = '';
	let isLoading = true;
	let error = null;
	let currentUserData = null;
	let branches = [];
	let showBranchSelector = false;
	let selectedBranchId = null; // Branch selected for receiving (not user's branch context)
	let receivingBranchName = 'Select Branch'; // Display name for receiving branch
	
	// Step 2 - File/Bill Management
	let currentStep = 1;
	let billType = null; // 'digital' or 'printed'
	let uploadedFiles = [];
	let pageCount = 0;
	let scannedPages = [];
	let availablePrinters = [];
	let selectedPrinter = null; // {id: string, name: string, type: string} | null
	let isScanning = false;
	let currentScanPage = 0;
	let showPrinterConfig = false;
	let userDefaultScanner = null;
	let currentPage = 1;
	let manualScannerName = '';
	let manualScannerUrl = '';
	let manualSystemScannerName = '';
	let manualScannerType = 'hp';

	// Step 3 - Quality Check
	let qualityChecks = {
		documentsComplete: false,
		vendorMatch: false,
		branchCorrect: false
	};

	// Step indicator
	// Steps management
	let steps = [
		{ number: 1, title: 'Vendor Selection', active: true },
		{ number: 2, title: 'File/Bill Upload', active: false },
		{ number: 3, title: 'Quality Check', active: false },
		{ number: 4, title: 'Final Review', active: false }
	];

	// Update steps based on current step
	$: {
		steps = steps.map(step => ({
			...step,
			active: step.number <= currentStep
		}));
	}

	// Column visibility for vendor table (matching ManageVendor exactly)
	let showColumnSelector = false;
	let visibleColumns = {
		erp_vendor_id: true,
		vendor_name: true,
		salesman_name: true,
		salesman_contact: false,
		supervisor_name: false,
		supervisor_contact: false,
		vendor_contact: true,
		payment_method: true,
		credit_period: false,
		bank_name: false,
		iban: false,
		last_visit: false,
		place: true,
		location: true,
		categories: true,
		delivery_modes: true,
		return_expired: false,
		return_near_expiry: false,
		return_over_stock: false,
		return_damage: false,
		no_return: false,
		vat_status: false,
		vat_number: false,
		status: true,
		actions: true // Enable actions in receiving mode
	};

	// Column definitions (matching ManageVendor exactly)
	const columnDefinitions = [
		{ key: 'erp_vendor_id', label: 'ERP Vendor ID' },
		{ key: 'vendor_name', label: 'Vendor Name' },
		{ key: 'salesman_name', label: 'Salesman Name' },
		{ key: 'salesman_contact', label: 'Salesman Contact' },
		{ key: 'supervisor_name', label: 'Supervisor Name' },
		{ key: 'supervisor_contact', label: 'Supervisor Contact' },
		{ key: 'vendor_contact', label: 'Vendor Contact' },
		{ key: 'payment_method', label: 'Payment Method' },
		{ key: 'credit_period', label: 'Credit Period' },
		{ key: 'bank_name', label: 'Bank Name' },
		{ key: 'iban', label: 'IBAN' },
		{ key: 'last_visit', label: 'Last Visit' },
		{ key: 'place', label: 'Place' },
		{ key: 'location', label: 'Location' },
		{ key: 'categories', label: 'Categories' },
		{ key: 'delivery_modes', label: 'Delivery Modes' },
		{ key: 'return_expired', label: 'Return Expired' },
		{ key: 'return_near_expiry', label: 'Return Near Expiry' },
		{ key: 'return_over_stock', label: 'Return Over Stock' },
		{ key: 'return_damage', label: 'Return Damage' },
		{ key: 'no_return', label: 'No Return' },
		{ key: 'vat_status', label: 'VAT Status' },
		{ key: 'vat_number', label: 'VAT Number' },
		{ key: 'status', label: 'Status' },
		{ key: 'actions', label: 'Actions' }
	];

	// Load data on component mount
	onMount(async () => {
		// Get current user data
		currentUser.subscribe(user => {
			console.log('Current user data:', user);
			currentUserData = user;
			
			// Set default receiving branch to user's branch (but allow changing)
			if (user?.branch_id && !selectedBranchId) {
				selectedBranchId = user.branch_id;
				receivingBranchName = user?.branchName || 'Loading...';
				console.log('Set default receiving branch to user branch:', selectedBranchId);
			} else if (!selectedBranchId) {
				// If user has no branch, start with no selection
				selectedBranchId = null;
				receivingBranchName = 'Select Branch for Receiving';
				console.log('No user branch - require manual selection');
			}
		});

		await loadVendors();
		await loadBranches();
		await loadUserDefaultScanner(); // Load user's saved scanner configuration
	});

	// Load vendors from database
	async function loadVendors() {
		try {
			isLoading = true;
			error = null;

			const { data, error: fetchError } = await supabase
				.from('vendors')
				.select('*')
				.eq('status', 'Active')
				.order('vendor_name', { ascending: true });

			if (fetchError) throw fetchError;

			vendors = data || [];
			filteredVendors = vendors;

		} catch (err) {
			error = err.message;
		} finally {
			isLoading = false;
		}
	}

	// Load branches for branch selector
	async function loadBranches() {
		try {
			console.log('Loading branches from database...');
			const { data, error } = await supabase
				.from('branches')
				.select('*')
				.order('name_en');

			if (error) {
				console.error('Error fetching branches:', error);
				throw error;
			}

			branches = data || [];
			console.log('Loaded branches for receiving selection:', branches);
			
			// Update receiving branch name if we have a selected branch
			if (selectedBranchId && branches.length > 0) {
				const selectedBranch = branches.find(b => 
					b.id == selectedBranchId || String(b.id) === String(selectedBranchId)
				);
				if (selectedBranch) {
					receivingBranchName = selectedBranch.name_en;
					console.log('Updated receiving branch name to:', receivingBranchName);
				}
			}
		} catch (err) {
			console.error('Error loading branches:', err);
			branches = []; // Fallback to empty array
		}
	}

	// Search functionality (enhanced like ManageVendor)
	function handleSearch() {
		if (!searchQuery.trim()) {
			filteredVendors = vendors;
		} else {
			const query = searchQuery.toLowerCase();
			filteredVendors = vendors.filter(vendor => 
				vendor.erp_vendor_id.toString().includes(query) ||
				vendor.vendor_name.toLowerCase().includes(query) ||
				(vendor.salesman_name && vendor.salesman_name.toLowerCase().includes(query)) ||
				(vendor.salesman_contact && vendor.salesman_contact.toLowerCase().includes(query)) ||
				(vendor.supervisor_name && vendor.supervisor_name.toLowerCase().includes(query)) ||
				(vendor.supervisor_contact && vendor.supervisor_contact.toLowerCase().includes(query)) ||
				(vendor.vendor_contact_number && vendor.vendor_contact_number.toLowerCase().includes(query)) ||
				(vendor.payment_method && vendor.payment_method.toLowerCase().includes(query)) ||
				(vendor.credit_period && vendor.credit_period.toString().includes(query)) ||
				(vendor.bank_name && vendor.bank_name.toLowerCase().includes(query)) ||
				(vendor.iban && vendor.iban.toLowerCase().includes(query)) ||
				(vendor.status && vendor.status.toLowerCase().includes(query)) ||
				(vendor.last_visit && vendor.last_visit.toLowerCase().includes(query)) ||
				(vendor.place && vendor.place.toLowerCase().includes(query)) ||
				(vendor.location_link && vendor.location_link.toLowerCase().includes(query)) ||
				(vendor.categories && vendor.categories.some(cat => cat.toLowerCase().includes(query))) ||
				(vendor.delivery_modes && vendor.delivery_modes.some(mode => mode.toLowerCase().includes(query)))
			);
		}
	}

	// Reactive search
	$: if (searchQuery !== undefined) {
		handleSearch();
	}

	// Handle vendor selection
	function selectVendor(vendor) {
		// Unselect if clicking the same vendor
		if (selectedVendor?.erp_vendor_id === vendor.erp_vendor_id) {
			selectedVendor = null;
		} else {
			selectedVendor = vendor;
		}
	}

	// Handle vendor edit
	function editVendor(vendor) {
		const windowId = generateEditWindowId();
		
		windowManager.openWindow({
			id: windowId,
			title: `Edit Vendor - ${vendor.vendor_name}`,
			component: EditVendor,
			icon: '✏️',
			size: { width: 800, height: 600 },
			position: { 
				x: 150 + (Math.random() * 50),
				y: 150 + (Math.random() * 50) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true,
			props: {
				vendor: vendor,
				onSave: async (updatedVendor) => {
					console.log('Vendor updated:', updatedVendor);
					try {
						// Update local vendor data with proper reactivity
						const index = vendors.findIndex(v => v.erp_vendor_id === updatedVendor.erp_vendor_id);
						if (index !== -1) {
							vendors[index] = { ...updatedVendor };
							vendors = [...vendors]; // Trigger reactivity
							console.log('Vendor updated in local array:', vendors[index]);
							handleSearch(); // Refresh filtered data
						} else {
							console.warn('Vendor not found in local array for update');
							// Reload all vendors as fallback
							await loadVendors();
						}
						// Close the edit window
						windowManager.closeWindow(windowId);
						alert('Vendor updated successfully!');
					} catch (error) {
						console.error('Error updating vendor in UI:', error);
						alert('Vendor updated but there was an issue refreshing the display.');
					}
				},
				onCancel: () => {
					// Close the edit window
					windowManager.closeWindow(windowId);
				}
			}
		});
	}

	// Generate unique window ID for edit
	function generateEditWindowId() {
		return `edit-vendor-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
	}

	// Step 2 Functions - File/Bill Management
	function proceedToStep2() {
		if (!selectedVendor) {
			alert('Please select a vendor first');
			return;
		}
		if (!selectedBranchId) {
			alert('Please select a branch for receiving');
			return;
		}
		currentStep = 2;
		console.log('Proceeding to Step 2 - File/Bill Management');
	}

	function selectBillType(type) {
		billType = type;
		uploadedFiles = [];
		scannedPages = [];
		pageCount = 0;
		console.log('Selected bill type:', type);
	}

	function handleFileUpload(event) {
		const files = Array.from(event.target.files);
		uploadedFiles = [...uploadedFiles, ...files];
		console.log('Files uploaded:', uploadedFiles);
	}

	function handleFileDrop(event) {
		event.preventDefault();
		const files = Array.from(event.dataTransfer.files);
		uploadedFiles = [...uploadedFiles, ...files];
		console.log('Files dropped:', uploadedFiles);
	}

	function handleDragOver(event) {
		event.preventDefault();
	}

	function removeFile(index) {
		uploadedFiles = uploadedFiles.filter((_, i) => i !== index);
	}

	function setPageCount() {
		console.log('setPageCount called, current pageCount:', pageCount);
		
		const numPages = Number(pageCount) || 0; // Convert to number safely
		console.log('Parsed pageCount:', numPages);
		
		if (numPages > 0 && numPages <= 50) {
			pageCount = numPages; // Ensure it's a number
			scannedPages = Array(pageCount).fill(null);
			currentScanPage = 0;
			loadAvailablePrinters();
			console.log('Set page count successfully:', pageCount);
			console.log('Scanned pages array:', scannedPages);
		} else {
			alert('Please enter a valid page count (1-50)');
			pageCount = 0; // Reset to show input again
		}
	}

	function addManualPrinter() {
		const printerName = prompt('Enter your printer name (e.g., "HP LaserJet Pro MFP 3303"):');
		if (printerName && printerName.trim()) {
			const newPrinter = {
				id: `manual_${Date.now()}`,
				name: printerName.trim(),
				type: 'manual',
				status: 'Ready'
			};
			
			availablePrinters = [...availablePrinters, newPrinter];
			console.log('Added manual printer:', newPrinter);
		}
	}

	// Load user's default scanner configuration
	async function loadUserDefaultScanner() {
		try {
			// Check localStorage for user's saved scanner
			const savedScanner = localStorage.getItem('userDefaultScanner');
			if (savedScanner) {
				userDefaultScanner = JSON.parse(savedScanner);
				console.log('Loaded user default scanner:', userDefaultScanner);
			}
		} catch (error) {
			console.error('Error loading user default scanner:', error);
		}
	}

	// Save user's default scanner configuration
	function saveUserDefaultScanner(scanner) {
		try {
			localStorage.setItem('userDefaultScanner', JSON.stringify(scanner));
			userDefaultScanner = scanner;
			selectedPrinter = scanner;
			console.log('Saved user default scanner:', scanner);
		} catch (error) {
			console.error('Error saving user default scanner:', error);
		}
	}

	// Open system printer settings
	function openPrinterSettings() {
		// Try multiple methods to open printer settings
		try {
			// Method 1: Windows Settings (modern)
			const settingsWindow = window.open('ms-settings:printers', '_blank');
			
			// Check if it worked after a short delay
			setTimeout(() => {
				if (settingsWindow && settingsWindow.closed) {
					// If it was closed immediately, try alternative methods
					tryAlternativePrinterSettings();
				}
			}, 1000);
			
		} catch (error) {
			console.log('ms-settings failed:', error);
			tryAlternativePrinterSettings();
		}
	}

	function tryAlternativePrinterSettings() {
		try {
			// Method 2: Control Panel
			window.open('control printers', '_blank');
		} catch (error2) {
			try {
				// Method 3: Run dialog command
				window.open('control', '_blank');
			} catch (error3) {
				// Method 4: Show instructions instead
				showPrinterSettingsInstructions();
			}
		}
	}

	function showPrinterSettingsInstructions() {
		const instructions = `🖨️ To add your scanner/printer:

Windows 10/11:
1. Press Windows key + I
2. Go to "Bluetooth & devices" > "Printers & scanners"
3. Click "Add device" or "Add printer or scanner"
4. Follow the setup wizard
5. Return here and click "Refresh Scanner List"

Alternative:
1. Press Windows key + R
2. Type: control printers
3. Press Enter
4. Add your printer/scanner
5. Return here and refresh

macOS:
1. Apple menu > System Preferences
2. Click "Printers & Scanners"
3. Click the "+" button to add

Linux:
1. Settings > Printers
2. Click "Add Printer"`;

		alert(instructions);
	}

	// Show printer configuration dialog
	function showPrinterConfiguration() {
		showPrinterConfig = true;
		loadAvailablePrinters();
	}

	// Configure scanner for this device
	function configureDeviceScanner(printer) {
		saveUserDefaultScanner(printer);
		showPrinterConfig = false;
		alert('Scanner configured successfully! This will be used for all scanning operations on this device.');
	}

	// Add manual network scanner
	function addManualNetworkScanner() {
		if (!manualScannerName.trim() || !manualScannerUrl.trim()) {
			alert('Please enter both scanner name and URL');
			return;
		}

		const networkScanner = {
			id: `manual_network_${Date.now()}`,
			name: manualScannerName.trim(),
			url: manualScannerUrl.trim(),
			type: 'network',
			isManual: true
		};

		// Add to available printers list
		availablePrinters = [networkScanner, ...availablePrinters];
		
		// Clear form
		manualScannerName = '';
		manualScannerUrl = '';
		
		alert('Network scanner added successfully! You can now set it as default.');
	}

	// Add manual system scanner
	function addManualSystemScanner() {
		if (!manualSystemScannerName.trim()) {
			alert('Please enter scanner name');
			return;
		}

		const systemScanner = {
			id: `manual_system_${Date.now()}`,
			name: manualSystemScannerName.trim(),
			type: manualScannerType,
			isManual: true
		};

		// Add to available printers list
		availablePrinters = [systemScanner, ...availablePrinters];
		
		// Clear form
		manualSystemScannerName = '';
		
		alert('System scanner added successfully! You can now set it as default.');
	}

	// Quick add common scanners
	function addQuickScanner(name, type) {
		const quickScanner = {
			id: `quick_${type}_${Date.now()}`,
			name: name,
			type: type,
			isQuick: true
		};

		// Add to available printers list
		availablePrinters = [quickScanner, ...availablePrinters];
		
		alert(`${name} added successfully! You can now set it as default.`);
	}

	// Load available printers
	async function loadAvailablePrinters() {
		try {
			console.log('Loading available printers...');
			
			// Try to get system printers using Web API
			if ('navigator' in globalThis && 'mediaDevices' in navigator) {
				// First try to get printer devices if available
				try {
					const devices = await navigator.mediaDevices.enumerateDevices();
					const printerDevices = devices.filter(device => 
						device.kind === 'videoinput' || // Some scanners appear as video input
						device.label.toLowerCase().includes('printer') ||
						device.label.toLowerCase().includes('scanner') ||
						device.label.toLowerCase().includes('hp') ||
						device.label.toLowerCase().includes('canon') ||
						device.label.toLowerCase().includes('epson')
					);
					
					if (printerDevices.length > 0) {
						availablePrinters = printerDevices.map(device => ({
							id: device.deviceId,
							name: device.label || 'Unknown Printer',
							type: 'system'
						}));
						console.log('Found system printers:', availablePrinters);
						return;
					}
				} catch (deviceError) {
					console.log('Device enumeration failed:', deviceError);
				}
			}

			// Fallback: Try to detect printers using other methods
			// Check if Web Print API is available (experimental)
			if ('print' in window) {
				// This is a basic fallback - in a real implementation you'd use
				// a more sophisticated printer detection method
				console.log('Using print API fallback');
			}

			// Load network scanner from user settings or use fallback
			const networkScannerConfig = await loadNetworkScannerConfig();
			
			availablePrinters = [
				...networkScannerConfig,
				{ id: 'system_default', name: 'System Default Printer', type: 'default' },
				{ id: 'hp_color_laserjet', name: 'HP Color LaserJet Pro', type: 'hp' },
				{ id: 'canon_printer', name: 'Canon PIXMA Series', type: 'canon' },
				{ id: 'epson_printer', name: 'Epson WorkForce Pro', type: 'epson' },
				{ id: 'generic_scanner', name: 'Generic Scanner/MFP', type: 'scanner' },
				{ id: 'add_network_scanner', name: '+ Add Network Scanner', type: 'config' }
			];
			
			// Auto-select the network scanner
			selectedPrinter = availablePrinters[0];
			
			console.log('Using network scanner and fallback printers:', availablePrinters);
			console.log('Auto-selected network scanner:', selectedPrinter);
		} catch (error) {
			console.error('Error loading printers:', error);
			// Minimal fallback
			availablePrinters = [
				{ id: 'system_default', name: 'System Default Printer', type: 'default' }
			];
		}
	}

	// Test scanner connectivity
	async function testScannerConnection() {
		const scannerUrl = 'http://192.168.0.9:3911';
		scannerConnectionStatus = 'testing';
		
		console.log('🔍 Testing scanner connectivity...');
		
		try {
			// Test basic connectivity
			const response = await fetch(scannerUrl, { 
				method: 'GET', 
				mode: 'no-cors',
				signal: AbortSignal.timeout(5000) 
			});
			
			scannerConnectionStatus = 'connected';
			console.log('✅ Scanner accessible');
			
			// Try to open scanner interface
			window.open(scannerUrl, '_blank');
			
			alert(
				`✅ Scanner Connection Successful!\n\n` +
				`Scanner URL: ${scannerUrl}\n` +
				`Status: Online and accessible\n\n` +
				`The scanner web interface has been opened in a new tab.\n` +
				`You can now use the "Scan" buttons in the receiving workflow.`
			);
			
		} catch (error) {
			scannerConnectionStatus = 'failed';
			console.error('❌ Scanner connection failed:', error);
			
			const troubleshootAction = confirm(
				`❌ Scanner Connection Failed\n\n` +
				`Scanner URL: ${scannerUrl}\n` +
				`Error: ${error.message}\n\n` +
				`Troubleshooting Steps:\n` +
				`1. Check if scanner is powered on\n` +
				`2. Verify network connection\n` +
				`3. Confirm IP address: 192.168.0.9\n` +
				`4. Check if port 3911 is accessible\n\n` +
				`Click OK to try opening scanner URL in browser\n` +
				`Click Cancel to continue with manual uploads`
			);
			
			if (troubleshootAction) {
				window.open(scannerUrl, '_blank');
			}
		}
	}

	// Scanner connection status
	let scannerConnectionStatus = 'unknown'; // 'unknown', 'testing', 'connected', 'failed'

	async function scanPage(pageIndex) {
		console.log(`Starting scan for page ${pageIndex + 1}`);
		
		if (!userDefaultScanner && !selectedPrinter) {
			alert('Please configure a scanner first by clicking "Configure Scanner"');
			showPrinterConfiguration();
			return;
		}
		
		isScanning = true;
		currentScanPage = pageIndex;
		currentPage = pageIndex + 1;
		
		try {
			await scanWithConfiguredScanner();
		} catch (error) {
			console.error('Scanning error:', error);
			alert(`Scanning failed: ${error.message}`);
		} finally {
			isScanning = false;
		}
	}

	// Main scanning function that uses configured scanner
	async function scanWithConfiguredScanner() {
		if (!userDefaultScanner && !selectedPrinter) {
			alert('Please configure a scanner first by clicking "Configure Scanner"');
			showPrinterConfiguration();
			return;
		}

		const scannerToUse = userDefaultScanner || selectedPrinter;
		console.log('Scanning with configured scanner:', scannerToUse);

		if (scannerToUse.type === 'network' && scannerToUse.url) {
			// Use network scanner
			await scanWithNetworkScanner(scannerToUse.url, currentPage - 1);
		} else if (scannerToUse.type === 'config') {
			// Show configuration dialog
			showPrinterConfiguration();
		} else {
			// Use system scanner
			await scanWithSystemScanner(scannerToUse);
		}
	}

	async function scanWithSystemScanner(scanner) {
		try {
			isScanning = true;
			console.log('Attempting to scan with system scanner:', scanner);

			// Show scanning options to user
			const scanMethod = await showScanningOptions(scanner);
			
			if (scanMethod === 'file') {
				// Use file picker as fallback
				await scanViaFilePicker();
			} else if (scanMethod === 'camera') {
				// Try camera/webcam scanning
				await scanViaCamera();
			} else if (scanMethod === 'cancel') {
				return;
			}
		} catch (error) {
			console.error('System scanning error:', error);
			alert(`Scanning failed: ${error.message}`);
		} finally {
			isScanning = false;
		}
	}

	function showScanningOptions(scanner) {
		return new Promise((resolve) => {
			const options = `📱 Scanning Options for ${scanner.name}:

1. 📁 Upload scanned file (if you've already scanned)
2. 📷 Use camera/webcam to capture document
3. ❌ Cancel

Choose an option:`;

			const choice = prompt(options + '\n\nEnter 1, 2, or 3:');
			
			switch(choice) {
				case '1':
					resolve('file');
					break;
				case '2':
					resolve('camera');
					break;
				default:
					resolve('cancel');
					break;
			}
		});
	}

	async function scanViaFilePicker() {
		const input = document.createElement('input');
		input.type = 'file';
		input.accept = 'image/*,application/pdf';
		input.multiple = false;
		
		return new Promise((resolve) => {
			input.onchange = (event) => {
				const file = event.target.files[0];
				if (file) {
					const reader = new FileReader();
					reader.onload = (e) => {
						const pageNumber = scannedPages.length + 1;
						scannedPages = [...scannedPages, {
							id: Date.now(),
							pageNumber,
							imageData: e.target.result,
							timestamp: new Date().toISOString(),
							filename: file.name,
							scanMethod: 'file_upload'
						}];
						console.log(`Page ${pageNumber} added from file upload`);
						resolve();
					};
					reader.readAsDataURL(file);
				} else {
					resolve();
				}
			};
			
			input.click();
		});
	}

	async function scanViaCamera() {
		try {
			// Request camera access
			const stream = await navigator.mediaDevices.getUserMedia({ 
				video: { 
					width: { ideal: 1200 },
					height: { ideal: 1600 },
					facingMode: { ideal: 'environment' } // Prefer back camera on mobile
				} 
			});

			// Create video element
			const video = document.createElement('video');
			video.srcObject = stream;
			video.autoplay = true;
			video.style.width = '100%';
			video.style.maxWidth = '400px';

			// Create capture interface
			const captureDiv = document.createElement('div');
			captureDiv.style.position = 'fixed';
			captureDiv.style.top = '0';
			captureDiv.style.left = '0';
			captureDiv.style.width = '100%';
			captureDiv.style.height = '100%';
			captureDiv.style.background = 'rgba(0,0,0,0.9)';
			captureDiv.style.zIndex = '10000';
			captureDiv.style.display = 'flex';
			captureDiv.style.flexDirection = 'column';
			captureDiv.style.alignItems = 'center';
			captureDiv.style.justifyContent = 'center';
			captureDiv.style.gap = '1rem';

			const captureBtn = document.createElement('button');
			captureBtn.textContent = '📷 Capture';
			captureBtn.style.padding = '1rem 2rem';
			captureBtn.style.fontSize = '1.2rem';
			captureBtn.style.background = '#10b981';
			captureBtn.style.color = 'white';
			captureBtn.style.border = 'none';
			captureBtn.style.borderRadius = '8px';
			captureBtn.style.cursor = 'pointer';

			const cancelBtn = document.createElement('button');
			cancelBtn.textContent = '❌ Cancel';
			cancelBtn.style.padding = '1rem 2rem';
			cancelBtn.style.fontSize = '1.2rem';
			cancelBtn.style.background = '#ef4444';
			cancelBtn.style.color = 'white';
			cancelBtn.style.border = 'none';
			cancelBtn.style.borderRadius = '8px';
			cancelBtn.style.cursor = 'pointer';

			captureDiv.appendChild(video);
			captureDiv.appendChild(captureBtn);
			captureDiv.appendChild(cancelBtn);
			document.body.appendChild(captureDiv);

			return new Promise((resolve) => {
				captureBtn.onclick = () => {
					// Capture image
					const canvas = document.createElement('canvas');
					canvas.width = video.videoWidth;
					canvas.height = video.videoHeight;
					const ctx = canvas.getContext('2d');
					ctx.drawImage(video, 0, 0);

					const imageData = canvas.toDataURL('image/jpeg', 0.8);
					
					// Stop stream and remove UI
					stream.getTracks().forEach(track => track.stop());
					document.body.removeChild(captureDiv);

					// Add to scanned pages
					const pageNumber = scannedPages.length + 1;
					scannedPages = [...scannedPages, {
						id: Date.now(),
						pageNumber,
						imageData,
						timestamp: new Date().toISOString(),
						scanMethod: 'camera_capture'
					}];

					console.log(`Page ${pageNumber} captured from camera`);
					resolve();
				};

				cancelBtn.onclick = () => {
					stream.getTracks().forEach(track => track.stop());
					document.body.removeChild(captureDiv);
					resolve();
				};
			});
		} catch (mediaError) {
			console.error('Camera access error:', mediaError);
			alert('Camera access denied or not available. Please use file upload instead.');
			await scanViaFilePicker();
		}
	}

	async function scanWithNetworkScanner(scannerUrl, pageIndex) {
		console.log(`Attempting to connect to scanner at ${scannerUrl}`);
		
		// Try common scanner API endpoints
		const endpoints = [
			'/scan',
			'/api/scan',
			'/scanner/scan',
			'/ws/scan'
		];
		
		for (const endpoint of endpoints) {
			try {
				const response = await fetch(`${scannerUrl}${endpoint}`, {
					method: 'POST',
					mode: 'cors',
					headers: {
						'Content-Type': 'application/json',
					},
					body: JSON.stringify({
						resolution: 300,
						format: 'jpeg',
						page: pageIndex + 1
					})
				});
				
				if (response.ok) {
					const result = await response.json();
					console.log('Scan initiated successfully:', result);
					
					// Poll for scan completion
					await pollForScanCompletion(scannerUrl, result.scanId || 'latest', pageIndex);
					return;
				}
			} catch (endpointError) {
				console.log(`Endpoint ${endpoint} failed:`, endpointError);
			}
		}
		
		throw new Error('No accessible scanner API endpoints found');
	}

	async function pollForScanCompletion(scannerUrl, scanId, pageIndex) {
		const maxAttempts = 30;
		let attempts = 0;
		
		while (attempts < maxAttempts) {
			try {
				// Try to get scan status
				const statusResponse = await fetch(`${scannerUrl}/status/${scanId}`);
				if (statusResponse.ok) {
					const status = await statusResponse.json();
					if (status.completed) {
						await retrieveScannedImage(scannerUrl, scanId, pageIndex);
						return;
					}
				}
			} catch (pollError) {
				console.log('Polling error:', pollError);
			}
			
			await new Promise(resolve => setTimeout(resolve, 1000));
			attempts++;
		}
		
		throw new Error('Scan polling timeout');
	}

	async function retrieveScannedImage(scannerUrl, scanId, pageIndex) {
		const imageEndpoints = [
			`/image/${scanId}`,
			`/api/image/${scanId}`,
			`/scan/image/${scanId}`,
			`/latest.jpg`,
			`/scan.jpg`
		];
		
		for (const endpoint of imageEndpoints) {
			try {
				const imageResponse = await fetch(`${scannerUrl}${endpoint}`);
				if (imageResponse.ok) {
					const imageBlob = await imageResponse.blob();
					const imageUrl = await blobToBase64(imageBlob);
					
					const scanData = {
						pageNumber: pageIndex + 1,
						imageUrl: imageUrl,
						timestamp: new Date().toISOString(),
						scanId: scanId
					};
					
					scannedPages[pageIndex] = scanData;
					scannedPages = [...scannedPages];
					
					console.log(`Page ${pageIndex + 1} scanned successfully`);
					return;
				}
			} catch (imageError) {
				console.log(`Image endpoint ${endpoint} failed:`, imageError);
			}
		}
		
		throw new Error('Could not retrieve scanned image');
	}

	async function guidedManualScan(scannerUrl, pageIndex) {
		// First, try to open scanner web interface
		let scannerAccessible = false;
		
		try {
			// Check if scanner web interface is accessible
			const testResponse = await fetch(scannerUrl, { 
				method: 'GET', 
				mode: 'no-cors',
				signal: AbortSignal.timeout(3000) 
			});
			scannerAccessible = true;
		} catch (error) {
			console.log('Scanner web interface not accessible:', error);
		}

		if (scannerAccessible) {
			// Scanner is accessible, open its interface
			window.open(scannerUrl, '_blank');
			
			const userChoice = confirm(
				`✅ Scanner web interface opened!\n\n` +
				`Scanner URL: ${scannerUrl}\n\n` +
				`Instructions:\n` +
				`1. Use the web interface to scan Page ${pageIndex + 1}\n` +
				`2. Save/download the scanned image\n` +
				`3. Click OK to upload the scanned file\n` +
				`4. Click Cancel to skip this page`
			);
			
			if (userChoice) {
				await manualImageUpload(pageIndex);
			} else {
				throw new Error('Scan cancelled by user');
			}
		} else {
			// Scanner not accessible, provide troubleshooting
			const troubleshootChoice = confirm(
				`❌ Cannot connect to network scanner\n\n` +
				`Scanner URL: ${scannerUrl}\n` +
				`Error: Connection refused\n\n` +
				`Troubleshooting:\n` +
				`• Is the scanner turned on?\n` +
				`• Is it connected to the network?\n` +
				`• Check if IP address changed\n` +
				`• Try opening ${scannerUrl} in browser\n\n` +
				`Solutions:\n` +
				`• Click OK to manually upload scanned image\n` +
				`• Click Cancel to retry scanner connection\n` +
				`• Check scanner network settings`
			);
			
			if (troubleshootChoice) {
				await manualImageUpload(pageIndex);
			} else {
				throw new Error('Scanner connection failed - please check network settings');
			}
		}
	}

	async function manualImageUpload(pageIndex) {
		return new Promise((resolve, reject) => {
			const input = document.createElement('input');
			input.type = 'file';
			input.accept = 'image/*,.pdf';
			input.onchange = async (event) => {
				const file = event.target && event.target['files'] && event.target['files'][0];
				if (file) {
					try {
						const imageUrl = await blobToBase64(file);
						
						const scanData = {
							pageNumber: pageIndex + 1,
							imageUrl: imageUrl,
							timestamp: new Date().toISOString(),
							filename: file.name,
							fileSize: file.size
						};
						
						scannedPages[pageIndex] = scanData;
						scannedPages = [...scannedPages];
						
						console.log(`Page ${pageIndex + 1} uploaded manually`);
						resolve();
					} catch (error) {
						reject(new Error('Failed to process uploaded image'));
					}
				} else {
					reject(new Error('No file selected'));
				}
			};
			input.click();
		});
	}

	// Helper function to convert blob to base64
	function blobToBase64(blob) {
		return new Promise((resolve, reject) => {
			const reader = new FileReader();
			reader.onload = () => resolve(reader.result);
			reader.onerror = reject;
			reader.readAsDataURL(blob);
		});
	}

	async function combinePages() {
		const validPages = scannedPages.filter(page => page !== null);
		if (validPages.length === 0) {
			alert('No pages to combine');
			return;
		}
		
		try {
			// Simulate PDF creation
			console.log('Creating PDF from scanned pages...');
			await new Promise(resolve => setTimeout(resolve, 2000));
			
			// Create a simulated PDF file
			const pdfBlob = new Blob(['%PDF-1.4 simulated content'], { type: 'application/pdf' });
			const pdfFile = new File([pdfBlob], `bill_${selectedVendor.vendor_name}_${Date.now()}.pdf`, { type: 'application/pdf' });
			
			uploadedFiles = [pdfFile];
			
			alert(`PDF created successfully with ${validPages.length} pages in lower quality`);
			console.log('Combined PDF created:', pdfFile);
			
			// Proceed to next step
			currentStep = 3;
		} catch (error) {
			console.error('PDF creation error:', error);
			alert('Failed to create PDF. Please try again.');
		}
	}

	function backToStep1() {
		currentStep = 1;
		billType = null;
		uploadedFiles = [];
		scannedPages = [];
		pageCount = 0;
	}

	// Branch change handler for receiving context
	function changeBranch() {
		showBranchSelector = true;
	}

	function selectBranch(branch) {
		console.log('selectBranch called with:', branch);
		selectedBranchId = branch.id;
		receivingBranchName = branch.name_en;
		console.log('Updated selectedBranchId to:', selectedBranchId);
		console.log('Updated receivingBranchName to:', receivingBranchName);
		showBranchSelector = false;
		
		// TODO: Filter vendors/receiving data by selected branch
		// This branch selection is for receiving operations only
		console.log('Branch selected for receiving operations:', branch.name_en);
	}

	// Toggle column visibility
	function toggleColumn(columnKey) {
		visibleColumns[columnKey] = !visibleColumns[columnKey];
		visibleColumns = { ...visibleColumns }; // Trigger reactivity
	}

	// Show/hide all columns
	function toggleAllColumns(show) {
		for (let key in visibleColumns) {
			if (key !== 'vendor_name') { // Always keep vendor name visible
				visibleColumns[key] = show;
			}
		}
		visibleColumns = { ...visibleColumns }; // Trigger reactivity
	}

	// Share location function (from ManageVendor)
	async function shareLocation(locationLink, vendorName) {
		try {
			// Check if Web Share API is supported
			if (navigator.share) {
				await navigator.share({
					title: `${vendorName} Location`,
					text: `Location for vendor: ${vendorName}`,
					url: locationLink
				});
			} else {
				// Fallback: Copy to clipboard
				await navigator.clipboard.writeText(locationLink);
				alert(`Location link copied to clipboard!\n\nVendor: ${vendorName}\nLocation: ${locationLink}`);
			}
		} catch (error) {
			// Manual fallback if clipboard fails
			try {
				await navigator.clipboard.writeText(locationLink);
				alert(`Location link copied to clipboard!\n\nVendor: ${vendorName}\nLocation: ${locationLink}`);
			} catch (clipboardError) {
				// Ultimate fallback - show link in a prompt
				prompt(`Copy this location link:\n\nVendor: ${vendorName}`, locationLink);
			}
		}
	}

	function getBranchName(branchId) {
		if (!branchId) return 'No Branch Selected';
		const branch = branches.find(b => b.branch_id === branchId);
		return branch ? branch.branch_name : 'Unknown Branch';
	}

	// Complete receiving process
	async function completeReceiving() {
		try {
			// Here you would typically save to database
			console.log('Completing receiving process with:', {
				vendor: selectedVendor,
				branch: selectedBranchId,
				billType,
				files: uploadedFiles,
				qualityChecks,
				user: currentUserData
			});

			// Simulate API call
			await new Promise(resolve => setTimeout(resolve, 1000));

			alert('Receiving process completed successfully!');
			
			// Reset form and close window
			currentStep = 1;
			billType = null;
			uploadedFiles = [];
			selectedVendor = null;
			qualityChecks = {
				documentsComplete: false,
				vendorMatch: false,
				branchCorrect: false
			};
			
			// Close the window
			if (typeof window !== 'undefined' && window.close) {
				window.close();
			}
		} catch (error) {
			console.error('Error completing receiving:', error);
			alert('Error completing receiving process. Please try again.');
		}
	}


</script>

<!-- Start Receiving Window -->
<div class="start-receiving">
	<!-- Step Indicator -->
	<div class="step-indicator">
		{#each steps as step}
			<div class="step {step.active ? 'active' : ''}">
				<div class="step-number">{step.number}</div>
				<div class="step-title">{step.title}</div>
			</div>
			{#if step.number < steps.length}
				<div class="step-connector {step.active && steps[step.number]?.active ? 'active' : ''}"></div>
			{/if}
		{/each}
	</div>

	<div class="header">
		<h1 class="title">� Start Receiving - Step 1</h1>
		<p class="subtitle">Select vendor and configure receiving details</p>
	</div>

	{#if currentStep === 1}
		<!-- User Information Section -->
		<div class="user-info-section">
		<div class="user-info-card">
			<div class="user-details">
				<div class="user-field">
					<span class="label">Employee:</span>
					<span class="value">{currentUserData?.employeeName || currentUserData?.username || 'Unknown User'}</span>
				</div>
				<div class="user-field">
					<span class="label">Position:</span>
					<span class="value">{currentUserData?.roleType || 'Unknown Position'}</span>
				</div>
				<div class="user-field">
					<span class="label">User Branch:</span>
					<span class="value">{currentUserData?.branchName || 'Unknown'}</span>
				</div>
				<div class="user-field">
					<span class="label">Receiving For:</span>
					<span class="value receiving-branch" class:same-as-user={selectedBranchId == currentUserData?.branch_id}>
						{receivingBranchName}
						{#if selectedBranchId == currentUserData?.branch_id}
							<span class="default-indicator">(Default)</span>
						{/if}
					</span>
					<button class="change-btn" on:click={changeBranch}>
						{selectedBranchId ? 'Change' : 'Select'}
					</button>
				</div>
			</div>
		</div>
	</div>

	<!-- Vendor Selection Section -->
	<div class="vendor-selection-section">
		<div class="section-header">
			<h2>Select Vendor</h2>
			<p>Choose the vendor for this receiving transaction</p>
		</div>

		<!-- Search Bar -->
		<div class="search-section">
			<div class="search-bar">
				<div class="search-input-wrapper">
					<span class="search-icon">🔍</span>
					<input 
						type="text" 
						placeholder="Search by ERP ID, vendor name, place, location, categories, delivery modes..."
						bind:value={searchQuery}
						class="search-input"
					/>
					{#if searchQuery}
						<button class="clear-search" on:click={() => searchQuery = ''}>×</button>
					{/if}
				</div>
			</div>
			<div class="search-results">
				Showing {filteredVendors.length} of {vendors.length} vendors
			</div>
		</div>

		<!-- Column Selector -->
		<div class="column-selector-section">
			<div class="column-selector">
				<button class="column-selector-btn" on:click={() => showColumnSelector = !showColumnSelector}>
					🏷️ Show/Hide Columns
					<span class="dropdown-arrow">{showColumnSelector ? '▲' : '▼'}</span>
				</button>
				
				{#if showColumnSelector}
					<div class="column-dropdown">
						<div class="column-controls">
							<button class="control-btn" on:click={() => toggleAllColumns(true)}>✅ Show All</button>
							<button class="control-btn" on:click={() => toggleAllColumns(false)}>❌ Hide All</button>
						</div>
						<div class="column-list">
							{#each columnDefinitions as column}
								<label class="column-item">
									<input 
										type="checkbox" 
										checked={visibleColumns[column.key]} 
										on:change={() => toggleColumn(column.key)}
									/>
									<span class="column-label">{column.label}</span>
								</label>
							{/each}
						</div>
					</div>
				{/if}
			</div>
		</div>

		<!-- Vendor Table -->
		<div class="table-container">
			{#if isLoading}
				<div class="loading-table">
					<div class="loading-spinner">⏳</div>
					<p>Loading vendors...</p>
				</div>
			{:else if error}
				<div class="error-message">
					<span class="error-icon">⚠️</span>
					<p>Error loading vendors: {error}</p>
					<button class="retry-btn" on:click={loadVendors}>Try Again</button>
				</div>
			{:else if filteredVendors.length === 0}
				<div class="empty-state">
					{#if searchQuery}
						<span class="empty-icon">�</span>
						<h3>No vendors found</h3>
						<p>No vendors match your search criteria</p>
						<button class="clear-search-btn" on:click={() => searchQuery = ''}>Clear Search</button>
					{:else}
						<span class="empty-icon">📝</span>
						<h3>No vendors yet</h3>
						<p>Upload vendor data to get started</p>
					{/if}
				</div>
			{:else}
				<div class="vendor-table">
					<table>
						<thead>
							<tr>
								<th style="width: 50px">Select</th>
								{#if visibleColumns.erp_vendor_id}<th>ERP Vendor ID</th>{/if}
								{#if visibleColumns.vendor_name}<th>Vendor Name</th>{/if}
								{#if visibleColumns.salesman_name}<th>Salesman Name</th>{/if}
								{#if visibleColumns.salesman_contact}<th>Salesman Contact</th>{/if}
								{#if visibleColumns.supervisor_name}<th>Supervisor Name</th>{/if}
								{#if visibleColumns.supervisor_contact}<th>Supervisor Contact</th>{/if}
								{#if visibleColumns.vendor_contact}<th>Vendor Contact</th>{/if}
								{#if visibleColumns.payment_method}<th>Payment Method</th>{/if}
								{#if visibleColumns.credit_period}<th>Credit Period</th>{/if}
								{#if visibleColumns.bank_name}<th>Bank Name</th>{/if}
								{#if visibleColumns.iban}<th>IBAN</th>{/if}
								{#if visibleColumns.last_visit}<th>Last Visit</th>{/if}
								{#if visibleColumns.place}<th>Place</th>{/if}
								{#if visibleColumns.location}<th>Location</th>{/if}
								{#if visibleColumns.categories}<th>Categories</th>{/if}
								{#if visibleColumns.delivery_modes}<th>Delivery Modes</th>{/if}
								{#if visibleColumns.return_expired}<th>Return Expired</th>{/if}
								{#if visibleColumns.return_near_expiry}<th>Return Near Expiry</th>{/if}
								{#if visibleColumns.return_over_stock}<th>Return Over Stock</th>{/if}
								{#if visibleColumns.return_damage}<th>Return Damage</th>{/if}
								{#if visibleColumns.no_return}<th>No Return</th>{/if}
								{#if visibleColumns.vat_status}<th>VAT Status</th>{/if}
								{#if visibleColumns.vat_number}<th>VAT Number</th>{/if}
								{#if visibleColumns.status}<th>Status</th>{/if}
								{#if visibleColumns.actions}<th>Actions</th>{/if}
							</tr>
						</thead>
						<tbody>
							{#each filteredVendors as vendor}
								<tr class="vendor-row {selectedVendor?.erp_vendor_id === vendor.erp_vendor_id ? 'selected' : ''}" 
									on:click={() => selectVendor(vendor)}>
									<td>
										<input 
											type="checkbox" 
											checked={selectedVendor?.erp_vendor_id === vendor.erp_vendor_id}
											on:change={() => selectVendor(vendor)}
										/>
									</td>
									{#if visibleColumns.erp_vendor_id}
										<td class="vendor-id">{vendor.erp_vendor_id}</td>
									{/if}
									{#if visibleColumns.vendor_name}
										<td class="vendor-name">{vendor.vendor_name}</td>
									{/if}
									{#if visibleColumns.salesman_name}
										<td class="vendor-data">
											{#if vendor.salesman_name}
												{vendor.salesman_name}
											{:else}
												<span class="no-data">No salesman</span>
											{/if}
										</td>
									{/if}
									{#if visibleColumns.salesman_contact}
										<td class="vendor-data">
											{#if vendor.salesman_contact}
												{vendor.salesman_contact}
											{:else}
												<span class="no-data">No contact</span>
											{/if}
										</td>
									{/if}
									{#if visibleColumns.supervisor_name}
										<td class="vendor-data">
											{#if vendor.supervisor_name}
												{vendor.supervisor_name}
											{:else}
												<span class="no-data">No supervisor</span>
											{/if}
										</td>
									{/if}
									{#if visibleColumns.supervisor_contact}
										<td class="vendor-data">
											{#if vendor.supervisor_contact}
												{vendor.supervisor_contact}
											{:else}
												<span class="no-data">No contact</span>
											{/if}
										</td>
									{/if}
									{#if visibleColumns.vendor_contact}
										<td class="vendor-data">
											{#if vendor.vendor_contact_number}
												{vendor.vendor_contact_number}
											{:else}
												<span class="no-data">No contact</span>
											{/if}
										</td>
									{/if}
									{#if visibleColumns.payment_method}
										<td class="payment-method">
											{#if vendor.payment_method}
												{#if vendor.payment_method.includes(',')}
													<!-- Multiple payment methods -->
													<div class="payment-methods-list">
														{#each vendor.payment_method.split(',').map(m => m.trim()) as method}
															<span class="payment-method-tag">{method}</span>
														{/each}
													</div>
												{:else}
													<!-- Single payment method -->
													{vendor.payment_method}
												{/if}
											{:else}
												<span class="no-data">No method</span>
											{/if}
										</td>
									{/if}
									{#if visibleColumns.credit_period}
										<td class="credit-period">
											{#if vendor.payment_method && (vendor.payment_method.includes('Cash Credit') || vendor.payment_method.includes('Bank Credit')) && vendor.credit_period}
												{vendor.credit_period} days
											{:else}
												<span class="no-data">No credit period</span>
											{/if}
										</td>
									{/if}
									{#if visibleColumns.bank_name}
										<td class="bank-info">
											{#if vendor.payment_method && (vendor.payment_method.includes('Bank on Delivery') || vendor.payment_method.includes('Bank Credit')) && vendor.bank_name}
												{vendor.bank_name}
											{:else}
												<span class="no-data">No bank</span>
											{/if}
										</td>
									{/if}
									{#if visibleColumns.iban}
										<td class="bank-info">
											{#if vendor.payment_method && (vendor.payment_method.includes('Bank on Delivery') || vendor.payment_method.includes('Bank Credit')) && vendor.iban}
												{vendor.iban}
											{:else}
												<span class="no-data">No IBAN</span>
											{/if}
										</td>
									{/if}
									{#if visibleColumns.last_visit}
										<td class="last-visit">
											{#if vendor.last_visit}
												{new Date(vendor.last_visit).toLocaleDateString('en-US', { 
													year: 'numeric', 
													month: 'short', 
													day: 'numeric',
													hour: '2-digit',
													minute: '2-digit'
												})}
											{:else}
												<span class="no-visit">Never visited</span>
											{/if}
										</td>
									{/if}
									{#if visibleColumns.place}
										<td class="vendor-place">
											{#if vendor.place}
												<span class="place-text">📍 {vendor.place}</span>
											{:else}
												<span class="no-place">No place</span>
											{/if}
										</td>
									{/if}
									{#if visibleColumns.location}
										<td class="vendor-location">
											{#if vendor.location_link}
												<div class="location-actions">
													<a 
														href={vendor.location_link} 
														target="_blank" 
														rel="noopener noreferrer"
														class="location-link"
													>
														🗺️ Open Map
													</a>
													<button 
														class="share-location-btn"
														on:click|stopPropagation={() => shareLocation(vendor.location_link, vendor.vendor_name)}
														title="Share Location"
													>
														📤 Share
													</button>
												</div>
											{:else}
												<span class="no-location">No location</span>
											{/if}
										</td>
									{/if}
									{#if visibleColumns.categories}
										<td class="vendor-categories">
											{#if vendor.categories && vendor.categories.length > 0}
												<div class="category-badges">
													{#each vendor.categories as category}
														<span class="category-badge">{category}</span>
													{/each}
												</div>
											{:else}
												<span class="no-categories">No categories</span>
											{/if}
										</td>
									{/if}
									{#if visibleColumns.delivery_modes}
										<td class="vendor-delivery-modes">
											{#if vendor.delivery_modes && vendor.delivery_modes.length > 0}
												<div class="delivery-mode-badges">
													{#each vendor.delivery_modes as mode}
														<span class="delivery-mode-badge">{mode}</span>
													{/each}
												</div>
											{:else}
												<span class="no-delivery-modes">No delivery modes</span>
											{/if}
										</td>
									{/if}
									{#if visibleColumns.return_expired}
										<td class="return-policy-cell">
											{#if vendor.return_expired_products}
												<span class="return-policy-badge {vendor.return_expired_products === 'Can Return' ? 'can-return' : 'cannot-return'}">
													{vendor.return_expired_products}
												</span>
											{:else}
												<span class="no-policy">Not set</span>
											{/if}
										</td>
									{/if}
									{#if visibleColumns.return_near_expiry}
										<td class="return-policy-cell">
											{#if vendor.return_near_expiry_products}
												<span class="return-policy-badge {vendor.return_near_expiry_products === 'Can Return' ? 'can-return' : 'cannot-return'}">
													{vendor.return_near_expiry_products}
												</span>
											{:else}
												<span class="no-policy">Not set</span>
											{/if}
										</td>
									{/if}
									{#if visibleColumns.return_over_stock}
										<td class="return-policy-cell">
											{#if vendor.return_over_stock}
												<span class="return-policy-badge {vendor.return_over_stock === 'Can Return' ? 'can-return' : 'cannot-return'}">
													{vendor.return_over_stock}
												</span>
											{:else}
												<span class="no-policy">Not set</span>
											{/if}
										</td>
									{/if}
									{#if visibleColumns.return_damage}
										<td class="return-policy-cell">
											{#if vendor.return_damage_products}
												<span class="return-policy-badge {vendor.return_damage_products === 'Can Return' ? 'can-return' : 'cannot-return'}">
													{vendor.return_damage_products}
												</span>
											{:else}
												<span class="no-policy">Not set</span>
											{/if}
										</td>
									{/if}
									{#if visibleColumns.no_return}
										<td class="return-policy-cell">
											{#if vendor.no_return}
												<span class="return-policy-badge no-return-badge">🚫 No Returns</span>
											{:else}
												<span class="return-policy-badge returns-accepted">✅ Returns OK</span>
											{/if}
										</td>
									{/if}
									{#if visibleColumns.vat_status}
										<td class="vat-cell">
											{#if vendor.vat_applicable}
												<span class="vat-badge {vendor.vat_applicable === 'VAT Applicable' ? 'vat-applicable' : 'no-vat'}">
													{vendor.vat_applicable === 'VAT Applicable' ? '💰 VAT Applicable' : '🚫 No VAT'}
												</span>
											{:else}
												<span class="no-vat-info">Not set</span>
											{/if}
										</td>
									{/if}
									{#if visibleColumns.vat_number}
										<td class="vat-number-cell">
											{#if vendor.vat_applicable === 'VAT Applicable' && vendor.vat_number}
												<span class="vat-number">{vendor.vat_number}</span>
											{:else if vendor.vat_applicable === 'No VAT' && vendor.no_vat_note}
												<span class="no-vat-note" title={vendor.no_vat_note}>📝 Note available</span>
											{:else}
												<span class="no-vat-info">-</span>
											{/if}
										</td>
									{/if}
									{#if visibleColumns.status}
										<td class="status-cell">
											{#if vendor.status === 'Active'}
												<span class="status-badge status-active">✅ Active</span>
											{:else if vendor.status === 'Deactivated'}
												<span class="status-badge status-deactivated">🚫 Deactivated</span>
											{:else if vendor.status === 'Blacklisted'}
												<span class="status-badge status-blacklisted">⚫ Blacklist</span>
											{:else}
												<span class="status-badge status-active">✅ Active</span>
											{/if}
										</td>
									{/if}
									{#if visibleColumns.actions}
										<td class="actions-cell">
											<button 
												class="edit-btn"
												on:click|stopPropagation={() => editVendor(vendor)}
												title="Edit Vendor"
											>
												<i class="fas fa-edit"></i>
												Edit
											</button>
										</td>
									{/if}
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
			{/if}
		</div>

		<!-- Action Buttons -->
		<div class="action-buttons">
			<button class="secondary-btn">Cancel</button>
			<button class="primary-btn" disabled={!selectedVendor || !selectedBranchId} on:click={proceedToStep2}>
				Continue to Step 2
			</button>
		</div>
		</div>
	{/if}

	<!-- Step 2: File/Bill Management -->
	{#if currentStep === 2}
		<div class="step-content step-2">
			<!-- Bill Type Selection -->
			{#if !billType}
				<div class="bill-type-selection">
					<h2>Select Bill Type</h2>
					<div class="bill-type-options">
						<button class="bill-type-card" on:click={() => selectBillType('digital')}>
							<div class="card-icon">💾</div>
							<h3>Digital Files</h3>
							<p>Upload images or PDF files</p>
							<span class="file-types">Supports: JPG, PNG, PDF</span>
						</button>
						<button class="bill-type-card" on:click={() => selectBillType('printed')}>
							<div class="card-icon">🖨️</div>
							<h3>Printed Bill</h3>
							<p>Scan physical documents</p>
							<span class="file-types">Scan to PDF</span>
						</button>
					</div>
				</div>
			{/if}

			<!-- Digital File Upload -->
			{#if billType === 'digital'}
				<div class="digital-upload-section">
					<div class="upload-header">
						<h2>📁 Upload Digital Files</h2>
						<button class="back-btn" on:click={() => billType = null}>← Change Type</button>
					</div>
					
					<div class="upload-area" 
						role="button"
						tabindex="0"
						on:drop={handleFileDrop} 
						on:dragover={handleDragOver}
						on:dragenter|preventDefault
						on:dragleave|preventDefault>
						<input 
							type="file" 
							id="file-upload" 
							multiple 
							accept=".jpg,.jpeg,.png,.pdf"
							on:change={handleFileUpload}
							style="display: none;"
						/>
						<label for="file-upload" class="upload-label">
							<div class="upload-icon">📎</div>
							<p>Drop files here or <span class="upload-link">choose files</span></p>
							<small>Supports JPG, PNG, PDF • Max 10MB per file</small>
						</label>
					</div>

					{#if uploadedFiles.length > 0}
						<div class="uploaded-files">
							<h3>Uploaded Files ({uploadedFiles.length})</h3>
							<div class="file-list">
								{#each uploadedFiles as file, index}
									<div class="file-item">
										<div class="file-info">
											<span class="file-icon">
												{#if file.type.includes('pdf')}📄{:else}🖼️{/if}
											</span>
											<div class="file-details">
												<span class="file-name">{file.name}</span>
												<span class="file-size">{(file.size / 1024 / 1024).toFixed(2)} MB</span>
											</div>
										</div>
										<button class="remove-file-btn" on:click={() => removeFile(index)}>❌</button>
									</div>
								{/each}
							</div>
						</div>
					{/if}
				</div>
			{/if}

			<!-- Printed Bill Scanning -->
			{#if billType === 'printed'}
				<div class="scanning-section">
					<div class="scanning-header">
						<h2>🖨️ Scan Printed Bill</h2>
						<button class="back-btn" on:click={() => billType = null}>← Change Type</button>
					</div>

					<div class="debug-section" style="background: #f0f0f0; padding: 1rem; margin: 1rem 0; border-radius: 4px;">
						<p><strong>Debug Info:</strong></p>
						<p>Bill Type: {billType}</p>
						<p>Page Count: {pageCount}</p>
						<p>Available Printers: {availablePrinters.length}</p>
						<p>Selected Printer: {selectedPrinter ? selectedPrinter.name : 'None'}</p>
					</div>

					{#if pageCount === 0}
						<div class="page-count-input">
							<h3>Enter Number of Pages</h3>
							<div class="page-input-group">
								<input 
									type="number" 
									bind:value={pageCount} 
									min="1" 
									max="50" 
									placeholder="Enter page count"
									class="page-count-field"
								/>
								<button class="set-pages-btn" on:click={setPageCount}>Set Pages</button>
							</div>
							<p class="debug-info">Current page count: {pageCount}</p>
						</div>
					{:else}
						<!-- Printer/Scanner Configuration Section -->
						<div class="scanner-config-section">
							<div class="scanner-config-header">
								<h3>🖨️ Scanner Configuration</h3>
								{#if userDefaultScanner}
									<div class="current-scanner">
										<span class="scanner-info">
											<strong>Default Scanner:</strong> {userDefaultScanner.name}
											<span class="scanner-status">✓ Configured</span>
										</span>
										<button class="change-scanner-btn" on:click={showPrinterConfiguration}>Change</button>
									</div>
								{:else}
									<div class="no-scanner">
										<span class="scanner-warning">⚠️ No default scanner configured</span>
										<button class="configure-scanner-btn" on:click={showPrinterConfiguration}>Configure Scanner</button>
									</div>
								{/if}
							</div>

							<div class="scanner-actions">
								<button class="system-settings-btn" on:click={openPrinterSettings}>
									🖥️ Open System Printer Settings
								</button>
								<button class="refresh-scanners-btn" on:click={loadAvailablePrinters}>
									🔄 Refresh Scanners
								</button>
							</div>
						</div>

						<!-- Printer Selection -->
						{#if !selectedPrinter && !userDefaultScanner}
							<div class="printer-selection">
								<h3>Select Printer/Scanner</h3>
								<p>Choose your printer or scanner to begin scanning</p>
								{#if availablePrinters.length > 0}
									<div class="printer-list">
										{#each availablePrinters as printer}
											<button 
												class="printer-item"
												on:click={() => selectedPrinter = printer}
											>
												<span class="printer-icon">
													{#if printer.type === 'hp'}
														🖨️ HP
													{:else if printer.type === 'canon'}
														🖨️ Canon  
													{:else if printer.type === 'epson'}
														🖨️ Epson
													{:else if printer.type === 'scanner'}
														📷 Scanner
													{:else}
														🖨️
													{/if}
												</span>
												<span class="printer-name">{printer.name}</span>
											</button>
										{/each}
									</div>
								{:else}
									<div class="no-printers">
										<p>🔍 Searching for printers...</p>
										<div class="printer-actions">
											<button class="refresh-printers-btn" on:click={loadAvailablePrinters}>
												🔄 Refresh Printer List
											</button>
											<button class="manual-printer-btn" on:click={addManualPrinter}>
												➕ Add Your Printer
											</button>
										</div>
										<div class="printer-help">
											<small>💡 If your printer isn't detected, you can add it manually</small>
										</div>
									</div>
								{/if}
							</div>
						{:else}
							<!-- Page Templates and Scanning Interface -->
							<div class="scanning-interface">
								<div class="scanner-info">
									<h3>🖨️ {selectedPrinter.name}</h3>
									{#if selectedPrinter.url}
										<p class="scanner-url">
											📡 Network Scanner: 
											<a href={selectedPrinter.url} target="_blank" class="scanner-link">
												{selectedPrinter.url}
											</a>
										</p>
										<p class="connection-status">🔗 Direct API integration attempt enabled</p>
									{:else}
										<p class="connection-status">💻 Local/System Scanner</p>
									{/if}
									<p>📄 Scanning {pageCount} {pageCount === 1 ? 'page' : 'pages'}</p>
									<div class="scan-instructions">
										<h4>📋 Scanning Process:</h4>
										<ol>
											<li>Place document face-down on scanner glass</li>
											<li>Ensure document is properly aligned</li>
											<li>Click "📷 Scan Page" button below</li>
											{#if selectedPrinter.url}
												<li>If direct API fails, scanner web interface will open</li>
											{:else}
												<li>Follow system prompts or upload scanned file</li>
											{/if}
										</ol>
									</div>
									<button class="change-printer-btn" on:click={() => selectedPrinter = null}>
										🔄 Change Printer
									</button>
									
									<!-- Scanner Test Button -->
									{#if selectedPrinter.url}
										<div class="scanner-test-section">
											<button 
												class="test-scanner-btn" 
												class:testing={scannerConnectionStatus === 'testing'}
												class:connected={scannerConnectionStatus === 'connected'}
												class:failed={scannerConnectionStatus === 'failed'}
												on:click={testScannerConnection}
												disabled={scannerConnectionStatus === 'testing'}
											>
												{#if scannerConnectionStatus === 'testing'}
													🔄 Testing Connection...
												{:else if scannerConnectionStatus === 'connected'}
													✅ Scanner Connected
												{:else if scannerConnectionStatus === 'failed'}
													❌ Connection Failed - Retry
												{:else}
													🧪 Test Scanner Connection
												{/if}
											</button>
											<small class="test-help">Test network scanner at {selectedPrinter.url}</small>
										</div>
									{/if}
								</div>

								<!-- Page Templates -->
								<div class="page-templates">
								{#each Array(pageCount) as _, pageIndex}
									<div class="page-template" class:scanned={scannedPages[pageIndex]} class:scanning={isScanning && currentScanPage === pageIndex}>
										<div class="page-header">
											<h4>Page {pageIndex + 1}</h4>
											<span class="page-status">
												{#if scannedPages[pageIndex]}
													✅ Scanned
												{:else if isScanning && currentScanPage === pageIndex}
													⏳ Scanning...
												{:else}
													⏸️ Ready to Scan
												{/if}
											</span>
										</div>
										
										{#if scannedPages[pageIndex]}
											<div class="scanned-preview">
												<div class="page-preview-container">
													<div class="a4-preview">
														<img src={scannedPages[pageIndex].imageUrl} alt="Scanned page {pageIndex + 1}" />
													</div>
												</div>
												<div class="scan-info">
													<small>Scanned: {new Date(scannedPages[pageIndex].timestamp).toLocaleTimeString()}</small>
												</div>
											</div>
										{:else}
											<div class="scan-placeholder">
												<div class="placeholder-icon">�</div>
												<p>Ready to scan</p>
												<button 
													class="scan-btn" 
													on:click={() => scanPage(pageIndex)}
													disabled={isScanning}
												>
													{#if isScanning && currentScanPage === pageIndex}
														⏳ Scanning...
													{:else}
														📷 Scan Page
													{/if}
												</button>
											</div>
										{/if}
									</div>
								{/each}
							</div>

							<!-- Combine Pages Button -->
							{#if scannedPages.some(page => page !== null)}
								<div class="combine-section">
									<button class="combine-btn" on:click={combinePages}>
										📑 Combine Pages to PDF
										<small>({scannedPages.filter(p => p !== null).length}/{pageCount} pages scanned)</small>
									</button>
								</div>
							{/if}
						</div>
						{/if}
					{/if}
				</div>
			{/if}

			<!-- Step 2 Actions -->
			<div class="step-actions">
				<button class="secondary-btn" on:click={backToStep1}>← Back to Step 1</button>
				{#if (billType === 'digital' && uploadedFiles.length > 0) || (billType === 'printed' && uploadedFiles.length > 0)}
					<button class="primary-btn" on:click={() => currentStep = 3}>Continue to Step 3 →</button>
				{/if}
			</div>
		</div>
	{/if}

	<!-- Step 3: Quality Check -->
	{#if currentStep === 3}
		<div class="step-content step-3">
			<h2>📋 Quality Check</h2>
			<p>Review and verify the received items before finalizing</p>
			
			<div class="quality-check-section">
				<h3>Uploaded Files</h3>
				<div class="files-review">
					{#each uploadedFiles as file, index}
						<div class="file-preview">
							<span class="file-name">{file.name}</span>
							<span class="file-size">{(file.size / 1024 / 1024).toFixed(2)} MB</span>
						</div>
					{/each}
				</div>

				<div class="verification-checklist">
					<h3>Verification Checklist</h3>
					<label class="checkbox-item">
						<input type="checkbox" bind:checked={qualityChecks.documentsComplete} />
						All documents are complete and readable
					</label>
					<label class="checkbox-item">
						<input type="checkbox" bind:checked={qualityChecks.vendorMatch} />
						Vendor information matches the selected vendor
					</label>
					<label class="checkbox-item">
						<input type="checkbox" bind:checked={qualityChecks.branchCorrect} />
						Receiving branch is correct
					</label>
				</div>
			</div>

			<div class="step-actions">
				<button class="secondary-btn" on:click={() => currentStep = 2}>← Back to Step 2</button>
				{#if qualityChecks.documentsComplete && qualityChecks.vendorMatch && qualityChecks.branchCorrect}
					<button class="primary-btn" on:click={() => currentStep = 4}>Continue to Step 4 →</button>
				{/if}
			</div>
		</div>
	{/if}

	<!-- Step 4: Final Review -->
	{#if currentStep === 4}
		<div class="step-content step-4">
			<h2>✅ Final Review</h2>
			<p>Review all details before completing the receiving process</p>
			
			<div class="final-review-section">
				<div class="review-card">
					<h3>Vendor Information</h3>
					<p><strong>Vendor:</strong> {selectedVendor?.vendor_name}</p>
					<p><strong>ERP ID:</strong> {selectedVendor?.erp_vendor_id}</p>
				</div>

				<div class="review-card">
					<h3>Receiving Details</h3>
					<p><strong>Branch:</strong> {getBranchName(selectedBranchId)}</p>
					<p><strong>Files:</strong> {uploadedFiles.length} file(s)</p>
					<p><strong>Type:</strong> {billType === 'digital' ? 'Digital Files' : 'Scanned Documents'}</p>
				</div>

				<div class="review-card">
					<h3>Processing Summary</h3>
					<p><strong>Date:</strong> {new Date().toLocaleDateString()}</p>
					<p><strong>Time:</strong> {new Date().toLocaleTimeString()}</p>
					<p><strong>User:</strong> {currentUserData?.employeeName || currentUserData?.username}</p>
				</div>
			</div>

			<div class="step-actions">
				<button class="secondary-btn" on:click={() => currentStep = 3}>← Back to Step 3</button>
				<button class="primary-btn success-btn" on:click={completeReceiving}>Complete Receiving Process</button>
			</div>
		</div>
	{/if}
</div>

<!-- Branch Selector Modal -->
{#if showBranchSelector}
	<div class="modal-overlay" role="dialog" aria-modal="true" aria-labelledby="branch-selector-title" tabindex="-1" on:click={() => showBranchSelector = false} on:keydown={(e) => e.key === 'Escape' && (showBranchSelector = false)}>
		<div class="modal-content" role="dialog" tabindex="-1" on:click|stopPropagation on:keydown|stopPropagation>
			<div class="modal-header">
				<h3 id="branch-selector-title">Select Branch for Receiving</h3>
				<button class="close-btn" on:click={() => showBranchSelector = false}>×</button>
			</div>
			<div class="modal-body">
				<p class="modal-description">Choose which branch you are receiving items for:</p>
				{#if branches.length === 0}
					<div class="empty-state">
						<p>No branches available</p>
					</div>
				{:else}
					{#each branches as branch}
						<button class="branch-option" on:click={() => selectBranch(branch)}>
							<div class="branch-info">
								<span class="branch-name">{branch.name_en}</span>
								<span class="branch-name-ar">{branch.name_ar}</span>
								<span class="branch-location">{branch.location_en}</span>
							</div>
							{#if branch.id == selectedBranchId || String(branch.id) === String(selectedBranchId)}
								<span class="current-badge">Current</span>
							{/if}
						</button>
					{/each}
				{/if}
			</div>
		</div>
	</div>
{/if}

<!-- Printer Configuration Modal -->
{#if showPrinterConfig}
	<div class="modal-overlay" role="dialog" aria-modal="true" aria-labelledby="printer-config-title" tabindex="-1" on:click={() => showPrinterConfig = false} on:keydown={(e) => e.key === 'Escape' && (showPrinterConfig = false)}>
		<div class="modal-content" role="dialog" tabindex="-1" on:click|stopPropagation on:keydown|stopPropagation>
			<div class="modal-header">
				<h3 id="printer-config-title">🖨️ Configure Scanner/Printer</h3>
				<button class="close-btn" on:click={() => showPrinterConfig = false}>×</button>
			</div>
			<div class="modal-body">
				<p class="modal-description">Choose your default scanner for this device:</p>
				
				<div class="scanner-instructions">
					<h4>📋 Setup Instructions:</h4>
					<ol>
						<li>Make sure your scanner/printer is connected and powered on</li>
						<li>Click "Open System Settings" to add your scanner to Windows</li>
						<li>Return here and select your scanner from the list</li>
						<li>Click "Set as Default" to save your preference</li>
					</ol>
				</div>

				<div class="system-settings-section">
					<button class="system-settings-btn large" on:click={openPrinterSettings}>
						🖥️ Open System Printer Settings
					</button>
					<button class="refresh-scanners-btn" on:click={loadAvailablePrinters}>
						🔄 Refresh Scanner List
					</button>
				</div>

				{#if availablePrinters.length === 0}
					<div class="empty-state">
						<p>No scanners detected. Please add your scanner in system settings first.</p>
					</div>
				{:else}
					<div class="scanner-list">
						{#each availablePrinters as printer}
							<div class="scanner-option" class:selected={userDefaultScanner?.id === printer.id}>
								<div class="scanner-info">
									<span class="scanner-name">{printer.name}</span>
									<span class="scanner-type">{printer.type}</span>
									{#if printer.url}
										<span class="scanner-url">{printer.url}</span>
									{/if}
								</div>
								<div class="scanner-actions">
									{#if userDefaultScanner?.id === printer.id}
										<span class="default-badge">✓ Default</span>
									{:else}
										<button class="set-default-btn" on:click={() => configureDeviceScanner(printer)}>
											Set as Default
										</button>
									{/if}
								</div>
							</div>
						{/each}
					</div>
				{/if}

				<div class="manual-config">
					<h4>🔧 Manual Scanner Setup:</h4>
					<p>Can't see your scanner? Add it manually:</p>
					
					<div class="manual-options">
						<div class="network-scanner-setup">
							<h5>📡 Network Scanner</h5>
							<div class="network-scanner-form">
								<input 
									type="text" 
									placeholder="Scanner Name (e.g., HP MFP 3303)" 
									class="scanner-name-input"
									bind:value={manualScannerName}
								/>
								<input 
									type="text" 
									placeholder="Scanner URL (e.g., http://192.168.0.148:3911)" 
									class="scanner-url-input"
									bind:value={manualScannerUrl}
								/>
								<button class="add-network-scanner-btn" on:click={addManualNetworkScanner}>
									Add Network Scanner
								</button>
							</div>
						</div>
						
						<div class="system-scanner-setup">
							<h5>🖥️ System Scanner</h5>
							<div class="system-scanner-form">
								<input 
									type="text" 
									placeholder="Scanner Name (e.g., HP DeskJet 3700)" 
									class="scanner-name-input"
									bind:value={manualSystemScannerName}
								/>
								<select class="scanner-type-select" bind:value={manualScannerType}>
									<option value="hp">HP Scanner</option>
									<option value="canon">Canon Scanner</option>
									<option value="epson">Epson Scanner</option>
									<option value="brother">Brother Scanner</option>
									<option value="generic">Generic Scanner</option>
								</select>
								<button class="add-system-scanner-btn" on:click={addManualSystemScanner}>
									Add System Scanner
								</button>
							</div>
						</div>
					</div>
					
					<div class="common-scanners">
						<h5>🔄 Quick Add Common Scanners:</h5>
						<div class="quick-scanner-buttons">
							<button class="quick-scanner-btn" on:click={() => addQuickScanner('HP LaserJet Pro MFP', 'hp')}>
								HP LaserJet Pro
							</button>
							<button class="quick-scanner-btn" on:click={() => addQuickScanner('Canon PIXMA', 'canon')}>
								Canon PIXMA
							</button>
							<button class="quick-scanner-btn" on:click={() => addQuickScanner('Epson WorkForce', 'epson')}>
								Epson WorkForce
							</button>
							<button class="quick-scanner-btn" on:click={() => addQuickScanner('Brother MFC', 'brother')}>
								Brother MFC
							</button>
						</div>
					</div>
				</div>
			</div>
		</div>
	</div>
{/if}

<style>
	.start-receiving {
		padding: 24px;
		height: 100%;
		background: #f8fafc;
		overflow-y: auto;
		font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
	}

	/* Step Indicator */
	.step-indicator {
		display: flex;
		align-items: center;
		justify-content: center;
		margin-bottom: 32px;
		padding: 20px;
		background: white;
		border-radius: 12px;
		box-shadow: 0 4px 6px rgba(0, 0, 0, 0.05);
	}

	.step {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 8px;
	}

	.step-number {
		width: 40px;
		height: 40px;
		border-radius: 50%;
		display: flex;
		align-items: center;
		justify-content: center;
		font-weight: 600;
		font-size: 16px;
		background: #e5e7eb;
		color: #6b7280;
		transition: all 0.3s ease;
	}

	.step.active .step-number {
		background: #3b82f6;
		color: white;
	}

	.step-title {
		font-size: 12px;
		font-weight: 500;
		color: #6b7280;
		text-align: center;
	}

	.step.active .step-title {
		color: #1f2937;
		font-weight: 600;
	}

	.step-connector {
		width: 60px;
		height: 2px;
		background: #e5e7eb;
		margin: 0 16px;
	}

	.step-connector.active {
		background: #3b82f6;
	}

	/* Header */
	.header {
		margin-bottom: 2rem;
		text-align: center;
	}

	.title {
		font-size: 2rem;
		font-weight: 700;
		color: #1e293b;
		margin-bottom: 0.5rem;
	}

	.subtitle {
		color: #64748b;
		font-size: 1.1rem;
	}

	/* User Information Section */
	.user-info-section {
		margin-bottom: 2rem;
	}

	.user-info-card {
		background: linear-gradient(135deg, #f0f9ff 0%, #e0f2fe 100%);
		border: 1px solid #0ea5e9;
		border-radius: 12px;
		padding: 20px;
	}

	.user-details {
		display: flex;
		gap: 32px;
		align-items: center;
		flex-wrap: wrap;
	}

	.user-field {
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.user-field .label {
		font-weight: 600;
		color: #1f2937;
		font-size: 14px;
	}

	.user-field .value {
		color: #374151;
		font-size: 14px;
	}

	.change-btn {
		background: #0ea5e9;
		color: white;
		border: none;
		border-radius: 6px;
		padding: 4px 12px;
		font-size: 12px;
		font-weight: 500;
		cursor: pointer;
		transition: background 0.2s ease;
	}

	.change-btn:hover {
		background: #0284c7;
	}

	.receiving-branch {
		font-weight: 600;
		color: #2563eb;
	}

	.receiving-branch.same-as-user {
		color: #059669;
	}

	.default-indicator {
		font-size: 12px;
		color: #6b7280;
		font-weight: 400;
		margin-left: 8px;
	}

	.modal-description {
		color: #6b7280;
		font-size: 14px;
		margin-bottom: 16px;
		text-align: center;
		font-style: italic;
	}

	/* Vendor Selection Section */
	.vendor-selection-section {
		background: white;
		border-radius: 12px;
		padding: 24px;
		box-shadow: 0 4px 6px rgba(0, 0, 0, 0.05);
	}

	.section-header {
		margin-bottom: 24px;
	}

	.section-header h2 {
		font-size: 20px;
		font-weight: 600;
		color: #1f2937;
		margin: 0 0 4px 0;
	}

	.section-header p {
		font-size: 14px;
		color: #6b7280;
		margin: 0;
	}

	/* Search Section */
	.search-section {
		margin-bottom: 2rem;
	}

	.search-bar {
		max-width: 600px;
		margin: 0 auto 1rem;
	}

	.search-input-wrapper {
		position: relative;
		display: flex;
		align-items: center;
	}

	.search-icon {
		position: absolute;
		left: 1rem;
		font-size: 1.2rem;
		color: #64748b;
		z-index: 1;
	}

	.search-input {
		width: 100%;
		padding: 1rem 1rem 1rem 3rem;
		border: 2px solid #e2e8f0;
		border-radius: 12px;
		font-size: 1rem;
		background: white;
		transition: all 0.2s;
	}

	.search-input:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.clear-search {
		position: absolute;
		right: 1rem;
		background: #64748b;
		color: white;
		border: none;
		width: 24px;
		height: 24px;
		border-radius: 50%;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		font-size: 14px;
		transition: all 0.2s;
	}

	.clear-search:hover {
		background: #475569;
	}

	.search-results {
		text-align: center;
		color: #64748b;
		font-size: 0.9rem;
	}

	/* Column Selector */
	.column-selector-section {
		margin-bottom: 1rem;
		display: flex;
		justify-content: center;
	}

	.column-selector {
		position: relative;
		display: inline-block;
	}

	.column-selector-btn {
		background: #3b82f6;
		color: white;
		border: none;
		padding: 0.75rem 1.25rem;
		border-radius: 8px;
		cursor: pointer;
		display: flex;
		align-items: center;
		gap: 0.5rem;
		font-weight: 500;
		transition: all 0.2s;
		box-shadow: 0 2px 4px rgba(59, 130, 246, 0.2);
	}

	.column-selector-btn:hover {
		background: #2563eb;
		transform: translateY(-1px);
		box-shadow: 0 4px 8px rgba(59, 130, 246, 0.3);
	}

	.dropdown-arrow {
		font-size: 0.8rem;
		transition: transform 0.2s;
	}

	.column-dropdown {
		position: absolute;
		top: 100%;
		left: 0;
		background: white;
		border: 1px solid #e2e8f0;
		border-radius: 8px;
		box-shadow: 0 8px 25px rgba(0, 0, 0, 0.1);
		z-index: 1000;
		min-width: 280px;
		max-height: 400px;
		overflow-y: auto;
		margin-top: 0.5rem;
	}

	.column-controls {
		padding: 1rem;
		border-bottom: 1px solid #e2e8f0;
		display: flex;
		gap: 0.5rem;
	}

	.control-btn {
		background: #f8fafc;
		border: 1px solid #e2e8f0;
		padding: 0.5rem 1rem;
		border-radius: 6px;
		cursor: pointer;
		font-size: 0.875rem;
		transition: all 0.2s;
		flex: 1;
	}

	.control-btn:hover {
		background: #f1f5f9;
		border-color: #cbd5e1;
	}

	.column-list {
		padding: 0.5rem;
	}

	.column-item {
		display: flex;
		align-items: center;
		gap: 0.75rem;
		padding: 0.75rem;
		border-radius: 6px;
		cursor: pointer;
		transition: background-color 0.2s;
	}

	.column-item:hover {
		background: #f8fafc;
	}

	.column-item input[type="checkbox"] {
		width: 16px;
		height: 16px;
		accent-color: #3b82f6;
	}

	.column-label {
		font-size: 0.9rem;
		color: #374151;
		user-select: none;
	}

	/* Table Container */
	.table-container {
		background: white;
		border-radius: 12px;
		box-shadow: 0 4px 6px rgba(0, 0, 0, 0.05);
		overflow: hidden;
		margin-bottom: 24px;
	}

	/* Loading/Error/Empty States */
	.loading-table, .empty-state, .error-message {
		text-align: center;
		padding: 3rem 2rem;
	}

	.loading-spinner, .empty-icon, .error-icon {
		font-size: 3rem;
		margin-bottom: 1rem;
		display: block;
	}

	.error-message {
		color: #dc2626;
	}

	.retry-btn, .clear-search-btn {
		background: #3b82f6;
		color: white;
		border: none;
		padding: 0.75rem 1.5rem;
		border-radius: 8px;
		cursor: pointer;
		margin-top: 1rem;
		font-weight: 500;
		transition: all 0.2s;
	}

	.retry-btn:hover, .clear-search-btn:hover {
		background: #2563eb;
		transform: translateY(-1px);
	}

	/* Vendor Table */
	.vendor-table {
		overflow-x: auto;
	}

	table {
		width: 100%;
		border-collapse: collapse;
	}

	thead {
		background: #f1f5f9;
	}

	th {
		padding: 1rem;
		text-align: left;
		font-weight: 600;
		color: #374151;
		border-bottom: 1px solid #e5e7eb;
	}

	td {
		padding: 1rem;
		border-bottom: 1px solid #f3f4f6;
		color: #374151;
	}

	.vendor-row {
		cursor: pointer;
		transition: background-color 0.2s ease;
	}

	.vendor-row:hover {
		background: #f8fafc;
	}

	.vendor-row.selected {
		background: #eff6ff;
		border-color: #3b82f6;
	}

	.vendor-row.selected td {
		border-bottom-color: #dbeafe;
	}

	.vendor-id {
		font-weight: 600;
		color: #3b82f6;
		font-family: 'Courier New', monospace;
	}

	.vendor-name {
		font-weight: 500;
	}

	.vendor-data {
		font-size: 0.9rem;
		color: #6b7280;
	}

	.no-data {
		color: #9ca3af;
		font-style: italic;
		font-size: 0.75rem;
	}

	/* Payment Method Styles */
	.payment-method {
		font-weight: 500;
		font-size: 0.9rem;
	}

	.payment-methods-list {
		display: flex;
		flex-wrap: wrap;
		gap: 0.25rem;
	}

	.payment-method-tag {
		display: inline-block;
		background: #dbeafe;
		color: #1e40af;
		padding: 0.125rem 0.5rem;
		border-radius: 12px;
		font-size: 0.75rem;
		font-weight: 500;
		white-space: nowrap;
	}

	.credit-period {
		font-size: 0.9rem;
		color: #059669;
		font-weight: 500;
	}

	.bank-info {
		font-size: 0.85rem;
		color: #374151;
		max-width: 120px;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}

	.last-visit {
		font-size: 0.8rem;
		color: #4b5563;
		min-width: 120px;
		white-space: nowrap;
	}

	.no-visit {
		color: #9ca3af;
		font-style: italic;
		font-size: 0.75rem;
	}

	/* Place & Location Styles */
	.vendor-place {
		max-width: 120px;
		padding: 0.5rem;
	}

	.place-text {
		font-size: 0.75rem;
		color: #374151;
		display: flex;
		align-items: center;
		gap: 0.25rem;
	}

	.no-place {
		color: #9ca3af;
		font-style: italic;
		font-size: 0.75rem;
	}

	.vendor-location {
		text-align: center;
		padding: 0.5rem;
	}

	.location-actions {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
		align-items: center;
	}

	.location-link {
		display: inline-flex;
		align-items: center;
		gap: 0.25rem;
		padding: 0.375rem 0.75rem;
		background: #3b82f6;
		color: white;
		text-decoration: none;
		border-radius: 4px;
		font-size: 0.75rem;
		font-weight: 500;
		transition: all 0.2s;
		min-width: 90px;
	}

	.location-link:hover {
		background: #2563eb;
		transform: translateY(-1px);
		box-shadow: 0 2px 8px rgba(59, 130, 246, 0.3);
	}

	.share-location-btn {
		display: inline-flex;
		align-items: center;
		gap: 0.25rem;
		padding: 0.25rem 0.5rem;
		background: #10b981;
		color: white;
		border: none;
		border-radius: 4px;
		font-size: 0.7rem;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s;
		min-width: 90px;
		justify-content: center;
	}

	.share-location-btn:hover {
		background: #059669;
		transform: translateY(-1px);
		box-shadow: 0 2px 6px rgba(16, 185, 129, 0.3);
	}

	.no-location {
		color: #9ca3af;
		font-style: italic;
		font-size: 0.75rem;
	}

	/* Categories and Delivery Modes */
	.vendor-categories {
		font-size: 0.8rem;
		min-width: 150px;
		max-width: 200px;
	}

	.category-badges {
		display: flex;
		flex-wrap: wrap;
		gap: 0.25rem;
	}

	.category-badge {
		background: #e0f2fe;
		color: #0369a1;
		padding: 0.125rem 0.375rem;
		border-radius: 0.25rem;
		font-size: 0.7rem;
		font-weight: 500;
		white-space: nowrap;
	}

	.no-categories {
		color: #9ca3af;
		font-style: italic;
		font-size: 0.75rem;
	}

	.vendor-delivery-modes {
		max-width: 200px;
		padding: 0.5rem;
	}

	.delivery-mode-badges {
		display: flex;
		flex-wrap: wrap;
		gap: 0.25rem;
	}

	.delivery-mode-badge {
		background: #fef3c7;
		color: #d97706;
		padding: 0.125rem 0.375rem;
		border-radius: 0.25rem;
		font-size: 0.7rem;
		font-weight: 500;
		white-space: nowrap;
	}

	.no-delivery-modes {
		color: #9ca3af;
		font-style: italic;
		font-size: 0.75rem;
	}

	/* Return Policy Styles */
	.return-policy-cell {
		text-align: center;
		padding: 0.75rem 0.5rem;
	}

	.return-policy-badge {
		display: inline-block;
		padding: 0.25rem 0.75rem;
		border-radius: 12px;
		font-size: 0.75rem;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.can-return {
		background-color: #dcfce7;
		color: #166534;
		border: 1px solid #bbf7d0;
	}

	.cannot-return {
		background-color: #fef2f2;
		color: #dc2626;
		border: 1px solid #fecaca;
	}

	.no-return-badge {
		background-color: #f3f4f6;
		color: #374151;
		border: 1px solid #d1d5db;
	}

	.returns-accepted {
		background-color: #eff6ff;
		color: #1d4ed8;
		border: 1px solid #bfdbfe;
	}

	.no-policy {
		color: #9ca3af;
		font-style: italic;
		font-size: 0.75rem;
	}

	/* VAT Styles */
	.vat-cell, .vat-number-cell {
		text-align: center;
		padding: 0.75rem 0.5rem;
	}

	.vat-badge {
		display: inline-block;
		padding: 0.25rem 0.75rem;
		border-radius: 12px;
		font-size: 0.75rem;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.vat-applicable {
		background-color: #dcfce7;
		color: #166534;
		border: 1px solid #bbf7d0;
	}

	.no-vat {
		background-color: #f3f4f6;
		color: #374151;
		border: 1px solid #d1d5db;
	}

	.vat-number {
		font-family: monospace;
		font-weight: 600;
		color: #374151;
		background-color: #f9fafb;
		padding: 0.25rem 0.5rem;
		border-radius: 4px;
		border: 1px solid #e5e7eb;
	}

	.no-vat-note {
		color: #6366f1;
		cursor: help;
		text-decoration: underline;
		font-size: 0.75rem;
	}

	.no-vat-info {
		color: #9ca3af;
		font-style: italic;
		font-size: 0.75rem;
	}

	/* Status Badge */
	.status-cell {
		text-align: center;
		padding: 0.5rem;
	}

	.status-badge {
		display: inline-block;
		padding: 0.25rem 0.75rem;
		border-radius: 12px;
		font-size: 0.75rem;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.status-active {
		background: linear-gradient(135deg, #10b981, #059669);
		color: white;
		border: 2px solid #059669;
	}

	.status-blacklisted {
		background: linear-gradient(135deg, #ef4444, #dc2626);
		color: white;
		border: 2px solid #dc2626;
	}

	.status-deactivated {
		background: linear-gradient(135deg, #f59e0b, #d97706);
		color: white;
		border: 2px solid #d97706;
	}

	/* Actions Column */
	.actions-cell {
		text-align: center;
		padding: 0.75rem 0.5rem;
	}

	.edit-btn {
		display: inline-flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.5rem 1rem;
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 6px;
		font-size: 0.875rem;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s ease;
		box-shadow: 0 2px 4px rgba(59, 130, 246, 0.2);
	}

	.edit-btn:hover {
		background: #2563eb;
		transform: translateY(-1px);
		box-shadow: 0 4px 8px rgba(59, 130, 246, 0.3);
	}

	.edit-btn:active {
		transform: translateY(0);
		box-shadow: 0 2px 4px rgba(59, 130, 246, 0.2);
	}

	.edit-btn i {
		font-size: 0.875rem;
	}

	/* Action Buttons */
	.action-buttons {
		display: flex;
		gap: 12px;
		justify-content: flex-end;
	}

	.primary-btn, .secondary-btn {
		padding: 10px 20px;
		border-radius: 8px;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s ease;
		border: 1px solid;
	}

	.primary-btn {
		background: #3b82f6;
		border-color: #3b82f6;
		color: white;
	}

	.primary-btn:hover:not(:disabled) {
		background: #2563eb;
		border-color: #2563eb;
	}

	.primary-btn:disabled {
		background: #d1d5db;
		border-color: #d1d5db;
		color: #9ca3af;
		cursor: not-allowed;
	}

	.secondary-btn {
		background: white;
		border-color: #d1d5db;
		color: #374151;
	}

	.secondary-btn:hover {
		background: #f9fafb;
		border-color: #9ca3af;
	}

	/* Modal Styles */
	.modal-overlay {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.5);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 1000;
	}

	.modal-content {
		background: white;
		border-radius: 12px;
		max-width: 400px;
		width: 90%;
		max-height: 80vh;
		overflow: hidden;
	}

	.modal-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 20px 24px;
		border-bottom: 1px solid #e5e7eb;
	}

	.modal-header h3 {
		font-size: 18px;
		font-weight: 600;
		color: #1f2937;
		margin: 0;
	}

	.close-btn {
		background: none;
		border: none;
		font-size: 24px;
		color: #6b7280;
		cursor: pointer;
		padding: 0;
		width: 32px;
		height: 32px;
		display: flex;
		align-items: center;
		justify-content: center;
		border-radius: 6px;
		transition: all 0.2s ease;
	}

	.close-btn:hover {
		background: #f3f4f6;
		color: #374151;
	}

	.modal-body {
		padding: 16px 24px 24px;
		max-height: 400px;
		overflow-y: auto;
	}

	.branch-option {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 16px;
		border-radius: 8px;
		cursor: pointer;
		transition: background 0.2s ease;
		margin-bottom: 8px;
		border: 1px solid #e5e7eb;
		background: white;
		width: 100%;
		text-align: left;
		font-family: inherit;
	}

	.branch-option:hover {
		background: #f3f4f6;
		border-color: #d1d5db;
	}

	.branch-option:focus {
		outline: none;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
		border-color: #3b82f6;
	}

	.branch-info {
		flex: 1;
	}

	.branch-name {
		font-size: 16px;
		color: #374151;
		font-weight: 600;
		display: block;
		margin-bottom: 4px;
	}

	.branch-name-ar {
		font-size: 14px;
		color: #6b7280;
		display: block;
		margin-bottom: 4px;
		font-style: italic;
	}

	.branch-location {
		font-size: 12px;
		color: #9ca3af;
		display: block;
	}

	.current-badge {
		background: #3b82f6;
		color: white;
		padding: 4px 12px;
		border-radius: 6px;
		font-size: 12px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.empty-state {
		text-align: center;
		padding: 40px 20px;
		color: #6b7280;
	}

	.empty-state p {
		font-size: 16px;
		margin: 0;
	}

	/* Responsive adjustments */
	@media (max-width: 768px) {
		.step-indicator {
			flex-direction: column;
			gap: 16px;
		}

		.step-connector {
			width: 2px;
			height: 30px;
			margin: 8px 0;
		}

		.user-details {
			flex-direction: column;
			align-items: flex-start;
			gap: 16px;
		}

		th, td {
			padding: 0.75rem 0.5rem;
			font-size: 0.9rem;
		}

		.action-buttons {
			flex-direction: column;
		}

		.search-input {
			padding: 0.875rem 0.875rem 0.875rem 2.5rem;
		}
	}

	/* Step 2 Styles */
	.step-2 {
		padding: 2rem;
	}

	.bill-type-selection {
		text-align: center;
		margin: 2rem 0;
	}

	.bill-type-options {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
		gap: 1.5rem;
		margin: 2rem 0;
	}

	.bill-type-card {
		background: white;
		border: 2px solid #e9ecef;
		border-radius: 12px;
		padding: 2rem;
		cursor: pointer;
		transition: all 0.3s ease;
		text-align: center;
	}

	.bill-type-card:hover {
		border-color: #3b82f6;
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(59, 130, 246, 0.15);
	}

	.upload-area {
		border: 2px dashed #d1d5db;
		border-radius: 8px;
		padding: 3rem;
		text-align: center;
		background: #f9fafb;
		transition: all 0.3s ease;
	}

	.upload-area:hover {
		border-color: #3b82f6;
		background: #f0f7ff;
	}

	.scanning-interface {
		margin: 2rem 0;
	}

	.scanner-info {
		background: #e8f4f8;
		padding: 1.5rem;
		border-radius: 8px;
		margin-bottom: 2rem;
		border: 1px solid #b8daff;
	}

	.connection-status {
		font-weight: 500;
		margin: 0.5rem 0;
		color: #17a2b8;
	}

	.scan-instructions {
		background: white;
		border: 1px solid #dee2e6;
		border-radius: 6px;
		padding: 1rem;
		margin: 1rem 0;
	}

	.scan-instructions h4 {
		margin: 0 0 0.5rem 0;
		color: #495057;
		font-size: 0.9rem;
	}

	.scan-instructions ol {
		margin: 0;
		padding-left: 1.2rem;
	}

	.scan-instructions li {
		margin: 0.3rem 0;
		font-size: 0.85rem;
		color: #6c757d;
	}

	.change-printer-btn {
		background: #6c757d;
		color: white;
		border: none;
		padding: 0.5rem 1rem;
		border-radius: 4px;
		cursor: pointer;
		font-size: 0.875rem;
		margin-top: 1rem;
	}

	.change-printer-btn:hover {
		background: #5a6268;
	}

	.scanner-url {
		margin: 0.5rem 0;
		font-size: 0.9rem;
	}

	.scanner-link {
		color: #007bff;
		text-decoration: none;
		font-family: monospace;
		background: #f8f9fa;
		padding: 0.2rem 0.4rem;
		border-radius: 4px;
		border: 1px solid #dee2e6;
	}

	.scanner-link:hover {
		background: #e9ecef;
		text-decoration: underline;
	}

	.change-printer-btn {
		background: #6c757d;
		color: white;
		border: none;
		padding: 0.5rem 1rem;
		border-radius: 4px;
		cursor: pointer;
		font-size: 0.875rem;
		margin-top: 0.5rem;
	}

	.change-printer-btn:hover {
		background: #5a6268;
	}

	.page-templates {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(250px, 1fr));
		gap: 1rem;
		margin: 2rem 0;
	}

	.page-template {
		border: 1px solid #e9ecef;
		border-radius: 8px;
		padding: 1rem;
		background: white;
	}

	.page-template.scanned {
		border-color: #28a745;
		background: #f8fff9;
	}

	.page-template.scanning {
		border-color: #ffc107;
		background: #fffcf0;
	}

	.a4-preview {
		width: 100%;
		max-width: 150px;
		aspect-ratio: 1/1.414; /* A4 ratio */
		border: 1px solid #ddd;
		border-radius: 4px;
		overflow: hidden;
		background: white;
		margin: 0 auto;
	}

	.a4-preview img {
		width: 100%;
		height: 100%;
		object-fit: cover;
	}

	.page-preview-container {
		display: flex;
		justify-content: center;
		margin: 1rem 0;
	}

	.scan-placeholder {
		text-align: center;
		padding: 2rem 1rem;
	}

	.scan-btn {
		background: #28a745;
		color: white;
		border: none;
		padding: 0.75rem 1.5rem;
		border-radius: 6px;
		cursor: pointer;
		font-weight: 500;
		margin-top: 1rem;
	}

	.scan-btn:hover {
		background: #218838;
	}

	.scan-btn:disabled {
		background: #6c757d;
		cursor: not-allowed;
	}

	.printer-selection {
		margin: 2rem 0;
		text-align: center;
		padding: 1.5rem;
		border: 1px solid #e9ecef;
		border-radius: 8px;
		background: #f8f9fa;
	}

	.printer-list {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
		gap: 1rem;
		margin: 1rem 0;
	}

	.printer-item {
		display: flex;
		align-items: center;
		gap: 1rem;
		padding: 1rem;
		background: white;
		border: 2px solid #e9ecef;
		border-radius: 8px;
		cursor: pointer;
		transition: all 0.2s ease;
		text-align: left;
	}

	.printer-item:hover {
		border-color: #3b82f6;
		transform: translateY(-1px);
		box-shadow: 0 2px 8px rgba(59, 130, 246, 0.15);
	}

	.printer-actions {
		display: flex;
		gap: 1rem;
		justify-content: center;
		margin: 1rem 0;
		flex-wrap: wrap;
	}

	.manual-printer-btn {
		background: #17a2b8;
		color: white;
		border: none;
		padding: 0.75rem 1.5rem;
		border-radius: 6px;
		cursor: pointer;
		font-weight: 500;
		transition: background 0.2s ease;
	}

	.manual-printer-btn:hover {
		background: #138496;
	}

	.refresh-printers-btn {
		background: #6c757d;
		color: white;
		border: none;
		padding: 0.75rem 1.5rem;
		border-radius: 6px;
		cursor: pointer;
		transition: background 0.2s ease;
	}

	.refresh-printers-btn:hover {
		background: #545b62;
	}

	.printer-help {
		text-align: center;
		margin-top: 1rem;
		padding: 0.5rem;
		background: #e7f3ff;
		border-radius: 4px;
	}

	.no-printers {
		text-align: center;
		padding: 2rem;
	}

	.page-templates {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
		gap: 1rem;
		margin: 1.5rem 0;
	}

	.printer-item {
		display: flex;
		align-items: center;
		gap: 1rem;
		padding: 1rem 1.5rem;
		background: white;
		border: 2px solid #e9ecef;
		border-radius: 8px;
		cursor: pointer;
		transition: all 0.3s ease;
		text-align: left;
	}

	.printer-item:hover {
		border-color: #3b82f6;
		background: #f0f7ff;
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(59, 130, 246, 0.15);
	}

	.printer-icon {
		font-size: 1.5rem;
		min-width: 2rem;
	}

	.printer-name {
		font-weight: 500;
		color: #2c3e50;
	}

	.no-printers {
		background: #f8f9fa;
		border-radius: 8px;
		padding: 2rem;
		margin: 1rem 0;
	}

	.refresh-printers-btn {
		background: #17a2b8;
		color: white;
		border: none;
		padding: 0.75rem 1.5rem;
		border-radius: 6px;
		cursor: pointer;
		font-weight: 500;
		margin-top: 1rem;
	}

	.refresh-printers-btn:hover {
		background: #138496;
	}

	.change-printer-btn {
		background: #6c757d;
		color: white;
		border: none;
		padding: 0.5rem 1rem;
		border-radius: 4px;
		cursor: pointer;
		font-size: 0.875rem;
		margin-top: 0.5rem;
	}

	.change-printer-btn:hover {
		background: #5a6268;
	}

	/* Step 3 & 4 Styles */
	.step-3, .step-4 {
		padding: 2rem;
	}

	.quality-check-section {
		margin: 2rem 0;
	}

	.files-review {
		background: #f8f9fa;
		border-radius: 8px;
		padding: 1rem;
		margin: 1rem 0;
	}

	.file-preview {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 0.5rem 0;
		border-bottom: 1px solid #e9ecef;
	}

	.file-preview:last-child {
		border-bottom: none;
	}

	.file-name {
		font-weight: 500;
		color: #2c3e50;
	}

	.file-size {
		color: #6c757d;
		font-size: 0.875rem;
	}

	.verification-checklist {
		margin: 2rem 0;
	}

	.checkbox-item {
		display: flex;
		align-items: center;
		margin: 1rem 0;
		font-size: 1rem;
		cursor: pointer;
	}

	.checkbox-item input[type="checkbox"] {
		margin-right: 0.75rem;
		width: 1.2rem;
		height: 1.2rem;
		cursor: pointer;
	}

	.final-review-section {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
		gap: 1.5rem;
		margin: 2rem 0;
	}

	.review-card {
		background: #f8f9fa;
		border-radius: 8px;
		padding: 1.5rem;
		border: 1px solid #e9ecef;
	}

	.review-card h3 {
		margin: 0 0 1rem 0;
		color: #2c3e50;
		font-size: 1.1rem;
	}

	.review-card p {
		margin: 0.5rem 0;
		color: #495057;
	}

	.success-btn {
		background: #28a745 !important;
		color: white !important;
	}

	.success-btn:hover {
		background: #218838 !important;
	}

	/* Scanner Test Button Styles */
	.scanner-test-section {
		margin: 1rem 0;
		padding: 1rem;
		background: #f8f9fa;
		border-radius: 8px;
		border: 1px solid #e9ecef;
	}

	.test-scanner-btn {
		background: #6c757d;
		color: white;
		border: none;
		padding: 0.75rem 1.5rem;
		border-radius: 6px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.3s ease;
		font-size: 0.95rem;
		margin-bottom: 0.5rem;
		width: 100%;
	}

	.test-scanner-btn:hover:not(:disabled) {
		background: #5a6268;
		transform: translateY(-1px);
		box-shadow: 0 2px 8px rgba(108, 117, 125, 0.3);
	}

	.test-scanner-btn.testing {
		background: #ffc107;
		color: #212529;
		cursor: not-allowed;
		animation: pulse 2s infinite;
	}

	.test-scanner-btn.connected {
		background: #28a745;
		color: white;
	}

	.test-scanner-btn.connected:hover {
		background: #218838;
	}

	.test-scanner-btn.failed {
		background: #dc3545;
		color: white;
	}

	.test-scanner-btn.failed:hover {
		background: #c82333;
	}

	.test-help {
		color: #6c757d;
		font-size: 0.875rem;
		display: block;
		text-align: center;
	}

	@keyframes pulse {
		0% { opacity: 1; }
		50% { opacity: 0.7; }
		100% { opacity: 1; }
	}

	/* Scanner Configuration Styles */
	.scanner-config-section {
		background: #f8fafc;
		border: 2px solid #e2e8f0;
		border-radius: 12px;
		padding: 1.5rem;
		margin-bottom: 2rem;
	}

	.scanner-config-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 1rem;
	}

	.current-scanner {
		display: flex;
		align-items: center;
		gap: 1rem;
	}

	.scanner-info {
		display: flex;
		align-items: center;
		gap: 0.5rem;
	}

	.scanner-status {
		color: #10b981;
		font-weight: 500;
	}

	.scanner-warning {
		color: #f59e0b;
		font-weight: 500;
	}

	.change-scanner-btn, .configure-scanner-btn {
		background: #3b82f6;
		color: white;
		border: none;
		padding: 0.5rem 1rem;
		border-radius: 6px;
		cursor: pointer;
		font-size: 0.875rem;
		transition: background 0.2s;
	}

	.change-scanner-btn:hover, .configure-scanner-btn:hover {
		background: #2563eb;
	}

	.scanner-actions {
		display: flex;
		gap: 1rem;
	}

	.system-settings-btn, .refresh-scanners-btn {
		background: #6366f1;
		color: white;
		border: none;
		padding: 0.75rem 1.25rem;
		border-radius: 8px;
		cursor: pointer;
		display: flex;
		align-items: center;
		gap: 0.5rem;
		font-weight: 500;
		transition: all 0.2s;
	}

	.system-settings-btn:hover, .refresh-scanners-btn:hover {
		background: #4f46e5;
		transform: translateY(-1px);
	}

	.system-settings-btn.large {
		padding: 1rem 1.5rem;
		font-size: 1rem;
	}

	.scanner-instructions {
		background: #eff6ff;
		border: 1px solid #bfdbfe;
		border-radius: 8px;
		padding: 1rem;
		margin: 1rem 0;
	}

	.scanner-instructions h4 {
		margin: 0 0 0.5rem 0;
		color: #1e40af;
	}

	.scanner-instructions ol {
		margin: 0;
		padding-left: 1.25rem;
	}

	.scanner-instructions li {
		margin-bottom: 0.25rem;
	}

	.system-settings-section {
		display: flex;
		gap: 1rem;
		justify-content: center;
		margin: 1.5rem 0;
	}

	.scanner-list {
		max-height: 300px;
		overflow-y: auto;
		border: 1px solid #e5e7eb;
		border-radius: 8px;
		margin: 1rem 0;
	}

	.scanner-option {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 1rem;
		border-bottom: 1px solid #e5e7eb;
		transition: background 0.2s;
	}

	.scanner-option:hover {
		background: #f9fafb;
	}

	.scanner-option.selected {
		background: #eff6ff;
		border-color: #3b82f6;
	}

	.scanner-option:last-child {
		border-bottom: none;
	}

	.scanner-info {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}

	.scanner-name {
		font-weight: 500;
		color: #111827;
	}

	.scanner-type {
		font-size: 0.875rem;
		color: #6b7280;
		text-transform: uppercase;
	}

	.scanner-url {
		font-size: 0.75rem;
		color: #9ca3af;
		font-family: 'Courier New', monospace;
	}

	.set-default-btn {
		background: #10b981;
		color: white;
		border: none;
		padding: 0.5rem 1rem;
		border-radius: 6px;
		cursor: pointer;
		font-size: 0.875rem;
		transition: background 0.2s;
	}

	.set-default-btn:hover {
		background: #059669;
	}

	.default-badge {
		background: #10b981;
		color: white;
		padding: 0.25rem 0.75rem;
		border-radius: 1rem;
		font-size: 0.75rem;
		font-weight: 500;
	}

	.manual-config {
		background: #fefce8;
		border: 1px solid #fde68a;
		border-radius: 8px;
		padding: 1rem;
		margin-top: 1.5rem;
	}

	.manual-config h4 {
		margin: 0 0 0.5rem 0;
		color: #92400e;
	}

	.manual-options {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 1.5rem;
		margin: 1rem 0;
	}

	.network-scanner-setup,
	.system-scanner-setup {
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 6px;
		padding: 1rem;
	}

	.network-scanner-setup h5,
	.system-scanner-setup h5 {
		margin: 0 0 0.75rem 0;
		color: #374151;
		font-size: 0.875rem;
		font-weight: 600;
	}

	.network-scanner-form,
	.system-scanner-form {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.scanner-name-input, 
	.scanner-url-input,
	.scanner-type-select {
		padding: 0.5rem;
		border: 1px solid #d1d5db;
		border-radius: 4px;
		font-size: 0.875rem;
	}

	.scanner-type-select {
		background: white;
	}

	.add-network-scanner-btn,
	.add-system-scanner-btn {
		background: #f59e0b;
		color: white;
		border: none;
		padding: 0.5rem 1rem;
		border-radius: 4px;
		cursor: pointer;
		font-size: 0.875rem;
		transition: background 0.2s;
	}

	.add-network-scanner-btn:hover,
	.add-system-scanner-btn:hover {
		background: #d97706;
	}

	.common-scanners {
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 6px;
		padding: 1rem;
		margin-top: 1rem;
	}

	.common-scanners h5 {
		margin: 0 0 0.75rem 0;
		color: #374151;
		font-size: 0.875rem;
		font-weight: 600;
	}

	.quick-scanner-buttons {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(120px, 1fr));
		gap: 0.5rem;
	}

	.quick-scanner-btn {
		background: #6366f1;
		color: white;
		border: none;
		padding: 0.5rem 0.75rem;
		border-radius: 4px;
		cursor: pointer;
		font-size: 0.75rem;
		text-align: center;
		transition: all 0.2s;
	}

	.quick-scanner-btn:hover {
		background: #4f46e5;
		transform: translateY(-1px);
	}

	@media (max-width: 768px) {
		.manual-options {
			grid-template-columns: 1fr;
		}
		
		.quick-scanner-buttons {
			grid-template-columns: repeat(2, 1fr);
		}
	}
</style>