<script lang="ts">
	import { onMount } from 'svelte';
	import { _ as t, locale } from '$lib/i18n';

	interface Employee {
		id: string;
		name_en: string;
		name_ar: string;
		current_branch_id: string;
		branch_name_en?: string;
		branch_name_ar?: string;
		nationality_id: string;
		nationality_name_en?: string;
		nationality_name_ar?: string;
		employment_status: string;
		sponsorship_status?: string;
	}

	interface Branch {
		id: string;
		name_en: string;
		name_ar: string;
	}

	interface Nationality {
		id: string;
		name_en: string;
		name_ar: string;
	}

	let loading = false;
	let error: string | null = null;
	let employees: Employee[] = [];
	let showTable = false;
	let activeView = ''; // 'with_data', 'without_data', 'result'
	let processedCount = 0;
	let isProcessing = false;
	let processedRecords: any[] = [];
	let filteredProcessedRecords: any[] = [];
	
	// Date and Time Formatters
	function formatDate(dateString: string): string {
		if (!dateString) return '-';
		const [year, month, day] = dateString.split('-');
		return `${day}-${month}-${year}`;
	}
	
	function format12HourTime(timeString: string): string {
		if (!timeString) return '-';
		const [hours, minutes] = timeString.split(':').slice(0, 2);
		const hour = parseInt(hours);
		const ampm = hour >= 12 ? 'PM' : 'AM';
		const hour12 = hour % 12 || 12;
		return `${hour12.toString().padStart(2, '0')}:${minutes} ${ampm}`;
	}
	
	// Shift and Punch Data Management
	// Cache structure: { "employeeId-YYYY-MM-DD": shiftData }
	let shiftDataCache: { [key: string]: any } = {};
	
	function getCacheKey(employeeId: string, punchDate?: string): string {
		return punchDate ? `${employeeId}-${punchDate}` : employeeId;
	}
	
	async function preloadAllShiftData(employeeIds: string[], punchDate?: string): Promise<void> {
		if (!employeeIds || employeeIds.length === 0) return;
		
		try {
			// Start with regular shifts as default for all employees
			const { data: regularShifts, error: regularError } = await supabase
				.from('regular_shift')
				.select('id, shift_start_time, shift_end_time')
				.in('id', employeeIds);
			
			if (regularError) {
				console.warn('Error loading regular shifts:', regularError);
				return;
			}
			
			// Build shift data with regular shifts as base
			const shiftsByEmployee: { [key: string]: any } = {};
			if (regularShifts) {
				for (const shift of regularShifts) {
					shiftsByEmployee[shift.id] = {
						checkInTime: shift.shift_start_time,
						checkOutTime: shift.shift_end_time,
						checkInBuffer: 3, // default 3 hours
						checkOutBuffer: 3, // default 3 hours
						source: 'regular_shift'
					};
				}
			}
			
			// Priority 2: Check special_shift_weekday (only if it matches the punch date's weekday)
			if (punchDate) {
				const { data: weekdayShifts, error: weekdayError } = await supabase
					.from('special_shift_weekday')
					.select('employee_id, weekday, shift_start_time, shift_end_time, shift_start_buffer, shift_end_buffer')
					.in('employee_id', employeeIds);
				
				if (!weekdayError && weekdayShifts) {
					const punchDateObj = new Date(punchDate);
					const punchWeekday = punchDateObj.getDay();
					
					for (const shift of weekdayShifts) {
						if (shift.weekday === punchWeekday) {
							shiftsByEmployee[shift.employee_id] = {
								checkInTime: shift.shift_start_time,
								checkOutTime: shift.shift_end_time,
								checkInBuffer: parseFloat(shift.shift_start_buffer) || 3,
								checkOutBuffer: parseFloat(shift.shift_end_buffer) || 3,
								source: 'special_shift_weekday'
							};
						}
					}
				}
				
				// Priority 1: Check special_shift_date_wise (highest priority - overrides both)
				const { data: dateShifts, error: dateError } = await supabase
					.from('special_shift_date_wise')
					.select('employee_id, shift_start_time, shift_end_time, shift_start_buffer, shift_end_buffer')
					.in('employee_id', employeeIds)
					.eq('shift_date', punchDate);
				
				if (!dateError && dateShifts) {
					for (const shift of dateShifts) {
						shiftsByEmployee[shift.employee_id] = {
							checkInTime: shift.shift_start_time,
							checkOutTime: shift.shift_end_time,
							checkInBuffer: parseFloat(shift.shift_start_buffer) || 3,
							checkOutBuffer: parseFloat(shift.shift_end_buffer) || 3,
							source: 'special_shift_date_wise'
						};
					}
				}
			}
			
			// Store in cache with date key if provided
			for (const empId of employeeIds) {
				const key = getCacheKey(empId, punchDate);
				shiftDataCache[key] = shiftsByEmployee[empId] || null;
			}
			
			console.log(`Preloaded shift data for ${Object.keys(shiftsByEmployee).length} employees${punchDate ? ` on ${punchDate}` : ''}`);
		} catch (err) {
			console.error('Failed to preload shift data:', err);
		}
	}
	
	// Synchronous version - only works if data is pre-fetched
	function getExpectedShiftTimesSync(employeeId: string, punchDate?: string): { checkInTime: string; checkOutTime: string; checkInBuffer: number; checkOutBuffer: number } | null {
		const key = getCacheKey(employeeId, punchDate);
		return shiftDataCache[key] || null;
	}
	
	// Keep async version for backward compatibility
	async function getExpectedShiftTimes(employeeId: string): Promise<{ checkInTime: string; checkOutTime: string; checkInBuffer: number; checkOutBuffer: number } | null> {
		// Try cache first
		if (shiftDataCache.hasOwnProperty(employeeId)) {
			return shiftDataCache[employeeId];
		}
		
		try {
			const { data: shiftData, error: shiftError } = await supabase
				.from('regular_shift')
				.select('shift_start_time, shift_end_time')
				.eq('id', employeeId)
				.single();
			
			if (shiftError) {
				console.warn(`No shift data found for ${employeeId}:`, shiftError);
				shiftDataCache[employeeId] = null;
				return null;
			}

			if (shiftData) {
				const result = {
					checkInTime: shiftData.shift_start_time,
					checkOutTime: shiftData.shift_end_time,
					checkInBuffer: 3,
					checkOutBuffer: 3
				};
				shiftDataCache[employeeId] = result;
				return result;
			}
		} catch (err) {
			console.warn(`Failed to fetch shift data for ${employeeId}:`, err);
			shiftDataCache[employeeId] = null;
		}
		
		return null;
	}
	
	function isWithinCheckInBuffer(punchTime: string, expectedCheckInTime: string, bufferHours: number = 3): boolean {
		if (!punchTime || !expectedCheckInTime) return false;
		
		const punch = new Date(`2026-01-01 ${punchTime}`);
		const expected = new Date(`2026-01-01 ${expectedCheckInTime}`);
		
		const bufferStart = new Date(expected.getTime() - bufferHours * 60 * 60 * 1000);
		const bufferEnd = new Date(expected.getTime() + bufferHours * 60 * 60 * 1000);
		
		return punch >= bufferStart && punch <= bufferEnd;
	}
	
	function isWithinCheckOutBuffer(punchTime: string, expectedCheckOutTime: string, bufferHours: number = 3): boolean {
		if (!punchTime || !expectedCheckOutTime) return false;
		
		const punch = new Date(`2026-01-01 ${punchTime}`);
		const expected = new Date(`2026-01-01 ${expectedCheckOutTime}`);
		
		const bufferStart = new Date(expected.getTime() - bufferHours * 60 * 60 * 1000);
		const bufferEnd = new Date(expected.getTime() + bufferHours * 60 * 60 * 1000);
		
		return punch >= bufferStart && punch <= bufferEnd;
	}
	
	function getPunchStatusColor(employeeId: string, punchTime: string, punchDate: string, isCheckIn: boolean): { bgColor: string; textColor: string; isValid: boolean } {
		const shiftTimes = getExpectedShiftTimesSync(employeeId, punchDate);
		
		if (!shiftTimes) {
			// No shift data found, show neutral color
			return { bgColor: 'bg-gray-100', textColor: 'text-gray-800', isValid: false };
		}
		
		const expectedTime = isCheckIn ? shiftTimes.checkInTime : shiftTimes.checkOutTime;
		const buffer = isCheckIn ? shiftTimes.checkInBuffer : shiftTimes.checkOutBuffer;
		const isWithinBuffer = isCheckIn 
			? isWithinCheckInBuffer(punchTime, expectedTime, buffer)
			: isWithinCheckOutBuffer(punchTime, expectedTime, buffer);
		
		if (isWithinBuffer) {
			// Within buffer - correct
			return { bgColor: 'bg-green-100', textColor: 'text-green-800', isValid: true };
		} else {
			// Outside buffer - mistake
			return { bgColor: 'bg-red-100', textColor: 'text-red-800', isValid: false };
		}
	}
	
	function groupRecordsByDateAndTime(records: any[]): { [date: string]: { checkIn: any; checkOut: any } } {
		const grouped: { [date: string]: { checkIn: any; checkOut: any } } = {};
		
		for (const record of records) {
			if (!grouped[record.punch_date]) {
				grouped[record.punch_date] = { checkIn: null, checkOut: null };
			}
			
			// Simple logic: earlier in the day = check-in, later = check-out
			const isCheckIn = !grouped[record.punch_date].checkIn || 
				(record.punch_time < grouped[record.punch_date].checkIn.punch_time);
			
			if (isCheckIn) {
				// If we already have a check-in and this is earlier, demote the old one to check-out
				if (grouped[record.punch_date].checkIn && !grouped[record.punch_date].checkOut) {
					grouped[record.punch_date].checkOut = grouped[record.punch_date].checkIn;
				}
				grouped[record.punch_date].checkIn = record;
			} else {
				grouped[record.punch_date].checkOut = record;
			}
		}
		
		return grouped;
	}
	
	// Search and Filters
	let searchQuery = '';
	let selectedBranchFilter = '';
	let selectedNationalityFilter = '';
	let availableBranches: Branch[] = [];
	let availableNationalities: Nationality[] = [];
	
	// Process Result filters
	let resultSearchEmployeeId = '';
	let resultSearchEmployeeName = '';
	let resultFilterDate = '';
	let resultFilterStatus = '';
	let availableStatuses: string[] = ['check-in', 'check-out'];

	// Date Range Modal
	let showDateRangeModal = false;
	let dateRangeStartDate = '';
	let dateRangeEndDate = '';
	let loadingWithDateRange = false;

	let supabase: any;

	$: filteredEmployees = employees.filter(emp => {
		const matchesSearch = !searchQuery || 
			emp.id.toLowerCase().includes(searchQuery.toLowerCase()) ||
			emp.name_en.toLowerCase().includes(searchQuery.toLowerCase()) ||
			(emp.name_ar && emp.name_ar.includes(searchQuery));
		
		const matchesBranch = !selectedBranchFilter || emp.current_branch_id === selectedBranchFilter;
		const matchesNationality = !selectedNationalityFilter || emp.nationality_id === selectedNationalityFilter;

		return matchesSearch && matchesBranch && matchesNationality;
	});

	$: filteredProcessedRecords = processedRecords.filter(record => {
		const matchesEmployeeId = !resultSearchEmployeeId || 
			record.employee_id?.toLowerCase().includes(resultSearchEmployeeId.toLowerCase());
		
		const matchesEmployeeName = !resultSearchEmployeeName || 
			(record.hr_employee_master?.name_en?.toLowerCase().includes(resultSearchEmployeeName.toLowerCase()) ||
			 record.hr_employee_master?.name_ar?.includes(resultSearchEmployeeName));
		
		const matchesDate = !resultFilterDate || record.punch_date === resultFilterDate;
		
		const matchesStatus = !resultFilterStatus || record.status === resultFilterStatus;

		return matchesEmployeeId && matchesEmployeeName && matchesDate && matchesStatus;
	});

	onMount(async () => {
		const { supabase: client } = await import('$lib/utils/supabase');
		supabase = client;
	});

	async function loadEmployeesWithFinger() {
		loading = true;
		error = null;
		try {
			const { data: employeeData, error: empError } = await supabase
				.from('hr_employee_master')
				.select(`
					id,
					name_en,
					name_ar,
					current_branch_id,
					nationality_id,
					employment_status,
					sponsorship_status,
					employee_id_mapping
				`)
				.eq('employment_status', 'Job (With Finger)')
				.not('employee_id_mapping', 'is', null);

			if (empError) throw empError;

			if (!employeeData || employeeData.length === 0) {
				employees = [];
				return;
			}

			// Get branches
			const branchIds = [...new Set(employeeData.map(e => e.current_branch_id).filter(Boolean))];
			const { data: branches, error: branchError } = await supabase
				.from('branches')
				.select('id, name_en, name_ar')
				.in('id', branchIds);

			if (branchError) throw branchError;

			// Get nationalities
			const nationalityIds = [...new Set(employeeData.map(e => e.nationality_id).filter(Boolean))];
			const { data: nationalities, error: natError } = await supabase
				.from('nationalities')
				.select('id, name_en, name_ar')
				.in('id', nationalityIds);

			if (natError) throw natError;

			const branchMap = new Map<string, Branch>((branches as Branch[] || []).map(b => [String(b.id), b]));
			const nationalityMap = new Map<string, Nationality>((nationalities as Nationality[] || []).map(n => [String(n.id), n]));

			// Populate available branches and nationalities for filter
			availableBranches = branches as Branch[] || [];
			availableNationalities = nationalities as Nationality[] || [];

			const combinedData = employeeData.map(emp => {
				const branch = branchMap.get(String(emp.current_branch_id));
				const nationality = nationalityMap.get(String(emp.nationality_id));
				return {
					...emp,
					branch_name_en: branch?.name_en || 'N/A',
					branch_name_ar: branch?.name_ar || 'N/A',
					nationality_name_en: nationality?.name_en || 'N/A',
					nationality_name_ar: nationality?.name_ar || 'N/A'
				};
			});

			// Sort using the same logic as ShiftAndDayOff
			employees = sortEmployees(combinedData);

		} catch (err) {
			console.error('Error loading employees:', err);
			error = err instanceof Error ? err.message : String(err);
		} finally {
			loading = false;
		}
	}

	function sortEmployees(employees: any[]): any[] {
		const employmentStatusOrder: { [key: string]: number } = {
			'Job (With Finger)': 1,
			'Job (No Finger)': 2,
			'Remote Job': 3,
			'Vacation': 4,
			'Resigned': 5,
			'Terminated': 6,
			'Run Away': 7
		};

		return employees.sort((a, b) => {
			// 1. Sort by employment status
			const statusOrderA = employmentStatusOrder[a.employment_status] || 99;
			const statusOrderB = employmentStatusOrder[b.employment_status] || 99;
			if (statusOrderA !== statusOrderB) return statusOrderA - statusOrderB;

			// 2. Sort by nationality (Saudi Arabia first)
			const nationalityNameA = a.nationality_name_en || '';
			const nationalityNameB = b.nationality_name_en || '';
			const isSaudiA = nationalityNameA.toLowerCase().includes('saudi') ? 0 : 1;
			const isSaudiB = nationalityNameB.toLowerCase().includes('saudi') ? 0 : 1;
			if (isSaudiA !== isSaudiB) return isSaudiA - isSaudiB;

			// 3. Sort by sponsorship status
			const isSponsoredA = a.sponsorship_status === true || a.sponsorship_status === 'true' || a.sponsorship_status === 'yes' || a.sponsorship_status === 'Yes' || a.sponsorship_status === '1' ? 0 : 1;
			const isSponsoredB = b.sponsorship_status === true || b.sponsorship_status === 'true' || b.sponsorship_status === 'yes' || b.sponsorship_status === 'Yes' || b.sponsorship_status === '1' ? 0 : 1;
			if (isSponsoredA !== isSponsoredB) return isSponsoredA - isSponsoredB;

			// 4. Sort by numeric employee ID
			const numA = parseInt(a.id?.toString().replace(/\D/g, '') || '0') || 0;
			const numB = parseInt(b.id?.toString().replace(/\D/g, '') || '0') || 0;
			if (numA !== numB) return numA - numB;

			return nationalityNameA.localeCompare(nationalityNameB);
		});
	}

	function handleProcessWithData() {
		activeView = 'with_data';
		showTable = true;
		loadEmployeesWithFinger();
	}

	function handleProcessWithoutData() {
		activeView = 'without_data';
		showTable = false;
		// Logic for later
	}

	function handleProcessResult() {
		// Reset filters when opening modal
		resultSearchEmployeeId = '';
		resultSearchEmployeeName = '';
		resultFilterDate = '';
		resultFilterStatus = '';
		dateRangeStartDate = '';
		dateRangeEndDate = '';
		
		// Show date range selection modal
		showDateRangeModal = true;
	}

	function closeDateRangeModal() {
		showDateRangeModal = false;
	}

	async function loadResultsWithDateRange() {
		if (!dateRangeStartDate || !dateRangeEndDate) {
			error = 'Please select both start and end dates';
			return;
		}

		if (dateRangeStartDate > dateRangeEndDate) {
			error = 'Start date must be before end date';
			return;
		}

		showDateRangeModal = false;
		activeView = 'result';
		showTable = false;
		await loadProcessedRecords(dateRangeStartDate, dateRangeEndDate);
	}

	function handleStartProcess(employeeId: string) {
		const selectedEmployee = employees.find(e => e.id === employeeId);
		if (selectedEmployee) {
			processEmployeeFingerprints(selectedEmployee);
		}
	}

	async function processAllEmployees() {
		isProcessing = true;
		error = null;
		processedCount = 0;

		try {
			await initSupabase();

			// Get the current max sequence ONCE at the start
			const { data: maxRecord } = await supabase
				.from('processed_fingerprint_transactions')
				.select('id')
				.order('id', { ascending: false })
				.limit(1);

			let currentSeq = 1;
			if (maxRecord && maxRecord.length > 0 && maxRecord[0].id) {
				const match = maxRecord[0].id.match(/(\d+)$/);
				if (match) {
					currentSeq = parseInt(match[1]) + 1;
				}
			}

			console.log('Starting sequence number:', currentSeq);

			// Process all filtered employees
			for (const employee of filteredEmployees) {
				const { recordsCreated, nextSeq } = await processEmployeeFingerprints(employee, currentSeq);
				processedCount += recordsCreated;
				currentSeq = nextSeq; // Update the sequence for the next employee
			}

			alert($t('common.success') + `: ${processedCount} total transactions processed!`);
		} catch (err) {
			console.error('Error processing all employees:', err);
			error = err instanceof Error ? err.message : 'Failed to process employees';
		} finally {
			isProcessing = false;
		}
	}

	async function initSupabase() {
		if (!supabase) {
			const { supabase: client } = await import('$lib/utils/supabase');
			supabase = client;
		}
	}

	async function loadProcessedRecords(startDate?: string, endDate?: string) {
		loading = true;
		error = null;
		processedRecords = [];

		try {
			await initSupabase();

			let query = supabase
				.from('processed_fingerprint_transactions')
				.select(`
					id,
					center_id,
					employee_id,
					branch_id,
					punch_date,
					punch_time,
					status,
					hr_employee_master!center_id (
						id,
						name_en,
						name_ar,
						nationality_id,
						current_branch_id,
						nationalities (
							id,
							name_en,
							name_ar
						)
					)
				`, { count: 'exact' });

			// Apply date range filter if provided
			if (startDate && endDate) {
				query = query
					.gte('punch_date', startDate)
					.lte('punch_date', endDate);
				console.log(`Loading records from ${startDate} to ${endDate}`);
			} else {
				// If no date range, load all but with limit
				console.log('Loading all available records');
			}

			const { data: records, error: recordError } = await query
				.range(0, 9999)
				.order('center_id', { ascending: true })
				.order('punch_date', { ascending: false });

			if (recordError) throw recordError;

			if (records && records.length > 0) {
				// Get all unique branch IDs to fetch branch data
				const branchIds = [...new Set(records.map(r => r.branch_id).filter(Boolean))];
				let branchMap: { [key: string]: any } = {};

				if (branchIds.length > 0) {
					const { data: branches, error: branchError } = await supabase
						.from('branches')
						.select('id, name_en, name_ar')
						.in('id', branchIds);

					if (branches) {
						branchMap = branches.reduce((acc, branch) => {
							acc[branch.id] = branch;
							return acc;
						}, {});
					}
				}

				// Pre-fetch shift data for all unique employees to avoid concurrent requests
				const uniqueEmployeeIds = [...new Set(records.map(r => r.center_id).filter(Boolean))] as string[];
				const uniqueDates = [...new Set(records.map(r => r.punch_date).filter(Boolean))] as string[];
				
				// Pre-fetch for each date to get date-wise shifts
				for (const punchDate of uniqueDates) {
					await preloadAllShiftData(uniqueEmployeeIds, punchDate);
				}
				
				// Also pre-fetch without date for employees without date-wise shifts
				await preloadAllShiftData(uniqueEmployeeIds);
				console.log(`Pre-loaded shift data for ${uniqueEmployeeIds.length} unique employees across ${uniqueDates.length} dates`);

				// Enrich records with branch data
				const enrichedRecords = records.map(record => ({
					...record,
					branches: branchMap[record.branch_id]
				}));

				// Sort by center_id, then by nationality, then by date (latest first)
				processedRecords = enrichedRecords.sort((a, b) => {
					// Sort by center_id (Employee ID)
					if (a.center_id !== b.center_id) {
						const numA = parseInt(a.center_id.replace(/\D/g, '') || '0') || 0;
						const numB = parseInt(b.center_id.replace(/\D/g, '') || '0') || 0;
						return numA - numB;
					}

					// Then sort by nationality
					const nationalityA = a.hr_employee_master?.nationalities?.name_en || '';
					const nationalityB = b.hr_employee_master?.nationalities?.name_en || '';
					if (nationalityA !== nationalityB) {
						return nationalityA.localeCompare(nationalityB);
					}

					// Finally sort by punch_date (latest first)
					if (a.punch_date !== b.punch_date) {
						return new Date(b.punch_date).getTime() - new Date(a.punch_date).getTime();
					}

					// If same date, sort by time (latest first)
					if (a.punch_time !== b.punch_time) {
						return b.punch_time.localeCompare(a.punch_time);
					}

					return 0;
				});

				showTable = true;
			} else {
				processedRecords = [];
				error = 'No processed fingerprint records found for the selected date range';
			}
		} catch (err) {
			console.error('Error loading processed records:', err);
			error = err instanceof Error ? err.message : 'Failed to load processed records';
		} finally {
			loading = false;
		}
	}

	async function processEmployeeFingerprints(employee: Employee, startSeqParam: number) {
		try {
			await initSupabase();

			// Step 1: Get the complete employee record with employee_id_mapping
			const { data: employeeRecord, error: empRecordError } = await supabase
				.from('hr_employee_master')
				.select('id, employee_id_mapping')
				.eq('id', employee.id)
				.single();

			if (empRecordError) throw empRecordError;
			if (!employeeRecord) throw new Error('Employee record not found');

			// Step 2: Extract employee IDs from the JSONB field
			let employeeIds: string[] = [];
			if (employeeRecord.employee_id_mapping) {
				try {
					// Handle both object and array formats
					const mapping = typeof employeeRecord.employee_id_mapping === 'string' 
						? JSON.parse(employeeRecord.employee_id_mapping) 
						: employeeRecord.employee_id_mapping;

					console.log(`Parsed mapping for ${employee.id}:`, mapping);

					if (Array.isArray(mapping)) {
						employeeIds = mapping.map(item => item.employee_id || item.id || String(item)).filter(Boolean);
					} else if (typeof mapping === 'object') {
						// If it's an object, extract all employee_id values
						employeeIds = Object.values(mapping).map(item => {
							if (typeof item === 'object' && item !== null && 'employee_id' in item) {
								return (item as any).employee_id;
							}
							return String(item);
						}).filter(Boolean);
					}
				} catch (parseError) {
					console.warn('Failed to parse employee_id_mapping:', parseError);
					employeeIds = [employee.id]; // Fallback to current employee ID
				}
			} else {
				employeeIds = [employee.id]; // Use the center employee ID if mapping is empty
			}

			// Remove duplicates
			employeeIds = [...new Set(employeeIds)];

			console.log(`Extracted employee IDs for ${employee.id}:`, employeeIds);

			if (employeeIds.length === 0) {
				throw new Error('No employee IDs found in mapping');
			}

			// Step 3: Get unprocessed fingerprint transactions for all extracted employee IDs
			const { data: fingerprintTransactions, error: fingerprintError } = await supabase
				.from('hr_fingerprint_transactions')
				.select('employee_id, branch_id, date, time, status, id')
				.in('employee_id', employeeIds)
				.eq('processed', false);

			if (fingerprintError) {
				console.warn('Fingerprint query error:', fingerprintError);
				throw fingerprintError;
			}

			console.log(`Found ${fingerprintTransactions?.length || 0} unprocessed transactions for employee IDs:`, employeeIds);

			if (!fingerprintTransactions || fingerprintTransactions.length === 0) {
				console.log(`No unprocessed transactions for employee ${employee.id}`);
				return { recordsCreated: 0, nextSeq: startSeqParam };
			}

			// Step 4: Use the passed sequence number
			let startSeq = startSeqParam;

			// Step 5: Prepare records for insertion
			const recordsToInsert = fingerprintTransactions.map((transaction, index) => {
				const seqNum = startSeq + index;
				return {
					id: `PF${seqNum}`,
					center_id: employee.id,
					employee_id: transaction.employee_id,
					branch_id: transaction.branch_id,
					punch_date: transaction.date,
					punch_time: transaction.time,
					status: transaction.status || 'check-in'
				};
			});

			console.log(`Preparing to insert ${recordsToInsert.length} records for ${employee.id}, starting from PF${startSeq}`);

			// Step 6: Insert or upsert records in batches to avoid size limits
			const batchSize = 500; // Supabase limit is typically 1000, but we use 500 to be safe
			for (let i = 0; i < recordsToInsert.length; i += batchSize) {
				const batch = recordsToInsert.slice(i, i + batchSize);
				console.log(`Inserting batch ${Math.floor(i / batchSize) + 1} with ${batch.length} records (${i}-${i + batch.length})`);

				const { error: insertError, data: insertedData } = await supabase
					.from('processed_fingerprint_transactions')
					.upsert(batch, { onConflict: 'id' });

				if (insertError) {
					console.error(`Batch ${Math.floor(i / batchSize) + 1} insert error:`, insertError);
					throw insertError;
				}
				console.log(`Batch inserted successfully`);
			}

			const nextSeq = startSeq + recordsToInsert.length;
			console.log(`Successfully inserted all ${recordsToInsert.length} records for ${employee.id}. Next sequence: PF${nextSeq}`);

			// Step 7: Mark the source records as processed
			const transactionIds = fingerprintTransactions.map(t => t.id);
			const { error: updateError } = await supabase
				.from('hr_fingerprint_transactions')
				.update({ processed: true })
				.in('id', transactionIds);

			if (updateError) {
				console.warn('Warning: Could not mark records as processed:', updateError);
				// Don't throw here - data is already in processed table
			}

			console.log(`Employee ${employee.id}: ${recordsToInsert.length} transactions processed`);
			
			return { recordsCreated: recordsToInsert.length, nextSeq };
		} catch (err) {
			console.error(`Error processing fingerprints for employee ${employee.id}:`, err);
			error = err instanceof Error ? err.message : 'Failed to process fingerprints';
			throw err;
		}
	}</script>

{#if showDateRangeModal}
	<div class="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
		<div class="bg-white rounded-2xl shadow-2xl p-8 max-w-md w-full mx-4">
			<h2 class="text-2xl font-bold text-slate-900 mb-6">Select Date Range</h2>
			
			{#if error}
				<div class="bg-red-50 border border-red-200 rounded-lg p-3 mb-4 text-sm text-red-700">
					{error}
				</div>
			{/if}

			<div class="space-y-4">
				<div class="flex flex-col gap-2">
					<label class="text-sm font-semibold text-slate-700 uppercase tracking-wider">Start Date</label>
					<input
						type="date"
						bind:value={dateRangeStartDate}
						class="px-4 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
					/>
				</div>

				<div class="flex flex-col gap-2">
					<label class="text-sm font-semibold text-slate-700 uppercase tracking-wider">End Date</label>
					<input
						type="date"
						bind:value={dateRangeEndDate}
						class="px-4 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
					/>
				</div>
			</div>

			<div class="flex gap-3 mt-8">
				<button
					class="flex-1 px-4 py-2 bg-slate-200 text-slate-800 font-semibold rounded-lg hover:bg-slate-300 transition-colors"
					on:click={closeDateRangeModal}
				>
					Cancel
				</button>
				<button
					class="flex-1 px-4 py-2 bg-blue-600 text-white font-semibold rounded-lg hover:bg-blue-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
					on:click={loadResultsWithDateRange}
					disabled={!dateRangeStartDate || !dateRangeEndDate}
				>
					Load Results
				</button>
			</div>
		</div>
	</div>
{/if}

<div class="process-fingerprint-container">
	<!-- Top Buttons -->
	<div class="flex flex-wrap gap-4 mb-8">
		<button 
			class="inline-flex items-center gap-2 px-6 py-3 rounded-xl font-black text-sm text-white bg-emerald-600 hover:bg-emerald-700 hover:shadow-lg transition-all duration-200 transform hover:scale-105 shadow-md {activeView === 'with_data' ? 'ring-4 ring-emerald-200' : ''}"
			on:click={handleProcessWithData}
		>
			<span>📊</span>
			{$t('hr.processFingerprint.process_with_data')}
		</button>

		<button 
			class="inline-flex items-center gap-2 px-6 py-3 rounded-xl font-black text-sm text-white bg-orange-600 hover:bg-orange-700 hover:shadow-lg transition-all duration-200 transform hover:scale-105 shadow-md {activeView === 'without_data' ? 'ring-4 ring-orange-200' : ''}"
			on:click={handleProcessWithoutData}
		>
			<span>📉</span>
			{$t('hr.processFingerprint.process_without_data')}
		</button>

		<button 
			class="inline-flex items-center gap-2 px-6 py-3 rounded-xl font-black text-sm text-white bg-blue-600 hover:bg-blue-700 hover:shadow-lg transition-all duration-200 transform hover:scale-105 shadow-md {activeView === 'result' ? 'ring-4 ring-blue-200' : ''}"
			on:click={handleProcessResult}
		>
			<span>📝</span>
			{$t('hr.processFingerprint.process_result')}
		</button>
	</div>

	{#if activeView === 'with_data'}
		<!-- Filter Controls -->
		<div class="mb-6 flex flex-wrap gap-4">
			<!-- Branch Filter -->
			<div class="flex-1 min-w-[200px]">
				<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="branch-filter">{$t('hr.shift.filter_branch')}</label>
				<select 
					id="branch-filter"
					bind:value={selectedBranchFilter}
					class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all"
				>
					<option value="">{$t('hr.shift.all_branches')}</option>
					{#each availableBranches as branch}
						<option value={branch.id}>
							{$locale === 'ar' ? (branch.name_ar || branch.name_en) : branch.name_en}
						</option>
					{/each}
				</select>
			</div>

			<!-- Nationality Filter -->
			<div class="flex-1 min-w-[200px]">
				<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="nationality-filter">{$t('hr.shift.filter_nationality')}</label>
				<select 
					id="nationality-filter"
					bind:value={selectedNationalityFilter}
					class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all"
				>
					<option value="">{$t('hr.shift.all_nationalities')}</option>
					{#each availableNationalities as nationality}
						<option value={nationality.id}>
							{$locale === 'ar' ? (nationality.name_ar || nationality.name_en) : nationality.name_en}
						</option>
					{/each}
				</select>
			</div>

			<!-- Search -->
			<div class="flex-[2] min-w-[300px]">
				<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="search">{$t('hr.shift.search_employee')}</label>
				<div class="relative">
					<input 
						id="search"
						type="text"
						bind:value={searchQuery}
						placeholder={$t('hr.shift.search_placeholder')}
						class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all pl-10"
					/>
					<span class="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400">🔍</span>
				</div>
			</div>

			<!-- Start Process Button -->
			<div class="flex items-end">
				<button 
					class="inline-flex items-center justify-center px-6 py-2.5 rounded-xl bg-emerald-600 text-white text-sm font-bold hover:bg-emerald-700 hover:shadow-lg transition-all duration-200 transform hover:scale-105 disabled:opacity-50 disabled:cursor-not-allowed shadow-md"
					on:click={processAllEmployees}
					disabled={isProcessing || filteredEmployees.length === 0}
				>
					{#if isProcessing}
						<span class="animate-spin inline-block mr-2">⚡</span>
						{$t('common.processing')}
					{:else}
						⚡ {$t('hr.processFingerprint.start_process')}
					{/if}
				</button>
			</div>
		</div>

		{#if loading}
			<div class="flex-1 flex items-center justify-center">
				<div class="text-center">
					<div class="animate-spin inline-block">
						<div class="w-12 h-12 border-4 border-emerald-200 border-t-emerald-600 rounded-full"></div>
					</div>
					<p class="mt-4 text-slate-600 font-semibold">{$t('hr.processFingerprint.loading_employees')}</p>
				</div>
			</div>
		{:else if error}
			<div class="bg-red-50 border border-red-200 rounded-2xl p-6 text-center">
				<p class="text-red-700 font-semibold">{$t('common.error')}: {error}</p>
				<button 
					class="mt-4 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition"
					on:click={loadEmployeesWithFinger}
				>
					{$t('common.retry')}
				</button>
			</div>
		{:else if employees.length === 0}
			<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-12 flex flex-col items-center justify-center border-dashed border-2 border-slate-200">
				<div class="text-5xl mb-4">📭</div>
				<p class="text-slate-600 font-semibold">{$t('hr.processFingerprint.no_employees_with_finger')}</p>
			</div>
		{:else}
			<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden flex flex-col">
				<div class="overflow-x-auto">
					<table class="w-full border-collapse">
						<thead class="sticky top-0 bg-emerald-600 text-white shadow-lg z-10">
							<tr>
								<th class="px-6 py-4 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('hr.employeeId')}</th>
								<th class="px-6 py-4 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('hr.fullName')}</th>
								<th class="px-6 py-4 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('hr.branch')}</th>
								<th class="px-6 py-4 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('hr.nationality')}</th>
								<th class="px-6 py-4 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Fingerprint Machine IDs</th>
								<th class="px-6 py-4 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('employeeFiles.inJob') || 'Status'}</th>
							</tr>
						</thead>
						<tbody class="divide-y divide-slate-200">
							{#each filteredEmployees as employee, index}
								{@const empIds = (() => {
									try {
										const mapping = typeof employee.employee_id_mapping === 'string' 
											? JSON.parse(employee.employee_id_mapping) 
											: employee.employee_id_mapping;
										if (Array.isArray(mapping)) {
											return mapping.map(item => item.employee_id || item.id || String(item)).filter(Boolean);
										} else if (typeof mapping === 'object') {
											return Object.values(mapping).map(item => {
												if (typeof item === 'object' && item !== null && 'employee_id' in item) {
													return (item as any).employee_id;
												}
												return String(item);
											}).filter(Boolean);
										}
										return [];
									} catch {
										return [];
									}
								})()}
								<tr class="hover:bg-emerald-50/30 transition-colors duration-200 {index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'}">
									<td class="px-6 py-4 text-sm font-semibold text-slate-800">{employee.id}</td>
									<td class="px-6 py-4 text-sm text-slate-700">
										{$locale === 'ar' ? employee.name_ar || employee.name_en : employee.name_en}
									</td>
									<td class="px-6 py-4 text-sm text-slate-700">
										{$locale === 'ar' ? employee.branch_name_ar || employee.branch_name_en : employee.branch_name_en}
									</td>
									<td class="px-6 py-4 text-sm text-slate-700">
										{$locale === 'ar' ? employee.nationality_name_ar || employee.nationality_name_en : employee.nationality_name_en}
									</td>
									<td class="px-6 py-4 text-sm">
										{#if empIds.length > 0}
											<div class="text-xs text-slate-700 font-mono space-y-0.5">
												{#each empIds as id}
													<div>{id}</div>
												{/each}
											</div>
										{:else}
											<span class="text-slate-400">-</span>
										{/if}
									</td>
									<td class="px-6 py-4 text-sm text-center">
										<span class="inline-flex items-center px-3 py-1 rounded-full text-xs font-semibold bg-green-100 text-green-800">
											{$t('employeeFiles.inJob') || 'Job (With Finger)'}
										</span>
									</td>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
				<div class="px-6 py-4 bg-slate-100/50 border-t border-slate-200 text-xs text-slate-600 font-semibold">
					{$t('hr.shift.showing_employees', { count: filteredEmployees.length })}
				</div>
			</div>
		{/if}
	{:else if activeView === 'without_data'}
		<div class="flex-1 flex items-center justify-center">
			<p class="text-slate-500 font-medium">Process Without Data view will be implemented here.</p>
		</div>
	{:else if activeView === 'result'}
		{#if loading}
			<div class="flex-1 flex items-center justify-center">
				<div class="text-center">
					<div class="animate-spin inline-block">
						<div class="w-12 h-12 border-4 border-emerald-200 border-t-emerald-600 rounded-full"></div>
					</div>
					<p class="mt-4 text-slate-600 font-semibold">Loading processed records...</p>
				</div>
			</div>
		{:else if error}
			<div class="bg-red-50 border border-red-200 rounded-2xl p-6 text-center">
				<p class="text-red-700 font-semibold">{$t('common.error')}: {error}</p>
				<button 
					class="mt-4 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition"
					on:click={loadProcessedRecords}
				>
					{$t('common.retry')}
				</button>
			</div>
		{:else if processedRecords.length === 0}
			<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-12 flex flex-col items-center justify-center border-dashed border-2 border-slate-200">
				<div class="text-5xl mb-4">📭</div>
				<p class="text-slate-600 font-semibold">No processed fingerprint records found.</p>
			</div>
		{:else}
			<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden flex flex-col h-full">
				<!-- Filter Section (Fixed) -->
				<div class="px-6 py-4 bg-blue-50/50 border-b border-blue-200 flex-shrink-0">
					<div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-3">
						<div class="flex flex-col gap-2">
							<label class="text-xs font-semibold text-slate-700 uppercase tracking-wider">Center ID</label>
							<input
								type="text"
								bind:value={resultSearchEmployeeId}
								placeholder="Search..."
								class="px-3 py-2 border border-slate-300 rounded-lg text-sm bg-white text-slate-900 placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-blue-500"
							/>
						</div>

						<div class="flex flex-col gap-2">
							<label class="text-xs font-semibold text-slate-700 uppercase tracking-wider">Employee Name</label>
							<input
								type="text"
								bind:value={resultSearchEmployeeName}
								placeholder="Search..."
								class="px-3 py-2 border border-slate-300 rounded-lg text-sm bg-white text-slate-900 placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-blue-500"
							/>
						</div>

						<div class="flex flex-col gap-2">
							<label class="text-xs font-semibold text-slate-700 uppercase tracking-wider">Punch Date</label>
							<input
								type="date"
								bind:value={resultFilterDate}
								class="px-3 py-2 border border-slate-300 rounded-lg text-sm bg-white text-slate-900 focus:outline-none focus:ring-2 focus:ring-blue-500"
							/>
						</div>

						<div class="flex flex-col gap-2">
							<label class="text-xs font-semibold text-slate-700 uppercase tracking-wider">Status</label>
							<select
								bind:value={resultFilterStatus}
								class="px-3 py-2 border border-slate-300 rounded-lg text-sm bg-white text-slate-900 focus:outline-none focus:ring-2 focus:ring-blue-500"
							>
								<option value="">All Statuses</option>
								{#each availableStatuses as status}
									<option value={status}>{status}</option>
								{/each}
							</select>
						</div>
					</div>

					<!-- Clear Filters Button -->
					<button
						class="px-4 py-2 bg-slate-400 text-white text-sm font-semibold rounded-lg hover:bg-slate-500 transition-colors"
						on:click={() => {
							resultSearchEmployeeId = '';
							resultSearchEmployeeName = '';
							resultFilterDate = '';
							resultFilterStatus = '';
						}}
					>
						Clear Filters
					</button>
				</div>

				<!-- Results Count -->
				<div class="px-6 py-3 bg-slate-50/30 border-b border-slate-200 text-xs text-slate-600 font-semibold flex-shrink-0">
					Showing {filteredProcessedRecords.length} of {processedRecords.length} records
				</div>

				<!-- Grouped Table by Employee (Scrollable) -->
				<div class="flex-1 overflow-y-auto">
					{#if filteredProcessedRecords.length > 0}
						<div class="space-y-4 p-6">
						{#each Object.entries(
							filteredProcessedRecords.reduce((acc, record) => {
								const key = record.center_id;
								if (!acc[key]) acc[key] = [];
								acc[key].push(record);
								return acc;
							}, {})
						) as [employeeId, records]}
							{@const firstRecord = records[0]}
							{@const groupedByDate = groupRecordsByDateAndTime(records)}
							<div class="border border-slate-200 rounded-lg overflow-hidden shadow-sm">
								<!-- Employee Header -->
								<div class="bg-gradient-to-r from-blue-600 to-blue-700 text-white px-6 py-4">
									<div class="grid grid-cols-5 gap-4 text-sm font-semibold">
										<div>
											<div class="text-xs opacity-75 mb-1">Employee ID</div>
											<div class="font-bold text-base">{employeeId}</div>
										</div>
										<div>
											<div class="text-xs opacity-75 mb-1">Full Name</div>
											<div>{$locale === 'ar' ? (firstRecord.hr_employee_master?.name_ar || firstRecord.hr_employee_master?.name_en || '-') : (firstRecord.hr_employee_master?.name_en || '-')}</div>
										</div>
										<div>
											<div class="text-xs opacity-75 mb-1">Branch</div>
											<div>{$locale === 'ar' ? (firstRecord.branches?.name_ar || firstRecord.branches?.name_en || '-') : (firstRecord.branches?.name_en || '-')}</div>
										</div>
										<div>
											<div class="text-xs opacity-75 mb-1">Nationality</div>
											<div>{$locale === 'ar' ? (firstRecord.hr_employee_master?.nationalities?.name_ar || firstRecord.hr_employee_master?.nationalities?.name_en || '-') : (firstRecord.hr_employee_master?.nationalities?.name_en || '-')}</div>
										</div>
										<div>
											<div class="text-xs opacity-75 mb-1">ID Information</div>
											<div class="font-mono text-xs">-</div>
										</div>
									</div>
								</div>

								<!-- Records Table -->
								<div class="overflow-x-auto">
									<table class="w-full">
											<thead class="bg-slate-100 border-b border-slate-300">
												<tr>
													<th class="px-6 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider text-slate-700">Date</th>
													<th class="px-6 py-3 text-left text-xs font-black uppercase tracking-wider text-slate-700">Check-In</th>
													<th class="px-6 py-3 text-left text-xs font-black uppercase tracking-wider text-slate-700">Check-Out</th>
												</tr>
											</thead>
											<tbody class="divide-y divide-slate-200">
												{#each Object.entries(groupedByDate)
													.sort(([dateA], [dateB]) => new Date(dateB).getTime() - new Date(dateA).getTime())
													as [date, timeData], idx
												}
													<tr class="hover:bg-blue-50/50 transition-colors {idx % 2 === 0 ? 'bg-white' : 'bg-slate-50/30'}">
														<td class="px-6 py-3 text-sm font-semibold text-slate-800">{formatDate(date)}</td>
														
														<!-- Check-In Column -->
														<td class="px-6 py-3 text-sm">
															{#if timeData.checkIn}
																{@const statusColor = getPunchStatusColor(employeeId, timeData.checkIn.punch_time, date, true)}
																<div class="rounded-lg px-3 py-2 {statusColor.bgColor} {statusColor.textColor} space-y-1">
																	<div class="font-mono font-semibold">{format12HourTime(timeData.checkIn.punch_time)}</div>
																	<div class="text-xs opacity-75">Machine: {timeData.checkIn.employee_id}</div>
																	<div class="text-xs opacity-75">{statusColor.isValid ? '✓ On Time' : '⚠ Outside Buffer'}</div>
																</div>
															{:else}
																<span class="text-slate-400">-</span>
															{/if}
														</td>
														
														<!-- Check-Out Column -->
														<td class="px-6 py-3 text-sm">
															{#if timeData.checkOut}
																{@const statusColor = getPunchStatusColor(employeeId, timeData.checkOut.punch_time, date, false)}
																<div class="rounded-lg px-3 py-2 {statusColor.bgColor} {statusColor.textColor} space-y-1">
																	<div class="font-mono font-semibold">{format12HourTime(timeData.checkOut.punch_time)}</div>
																	<div class="text-xs opacity-75">Machine: {timeData.checkOut.employee_id}</div>
																	<div class="text-xs opacity-75">{statusColor.isValid ? '✓ On Time' : '⚠ Outside Buffer'}</div>
																</div>
															{:else}
																<span class="text-slate-400">-</span>
															{/if}
														</td>
													</tr>
												{/each}
											</tbody>
										</table>
									</div>

								<!-- Records Count Footer -->
								<div class="bg-slate-50/50 border-t border-slate-200 px-6 py-2 text-xs text-slate-600 font-medium">
									{records.length} {records.length === 1 ? 'punch record' : 'punch records'} ({Object.keys(groupRecordsByDateAndTime(records)).length} days)
								</div>
							</div>
						{/each}
					</div>
					{:else}
						<div class="p-8 text-center">
							<div class="text-3xl mb-2">🔍</div>
							<p class="text-slate-600 font-semibold">No records match your filters</p>
						</div>
					{/if}
				</div>
			</div>
		{/if}
	{:else}
		<div class="flex-1 flex flex-col items-center justify-center text-slate-400">
			<div class="text-6xl mb-4">👆</div>
			<p class="text-lg font-medium">Select a process type to begin</p>
		</div>
	{/if}
</div>

<style>
	.process-fingerprint-container {
		padding: 2rem;
		height: 100%;
		display: flex;
		flex-direction: column;
		background: #f8fafc;
	}
</style>
