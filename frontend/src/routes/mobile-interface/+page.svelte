<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { goto } from '$app/navigation';
	import { page } from '$app/stores';
	import { currentUser, isAuthenticated, persistentAuthService } from '$lib/utils/persistentAuth';
	import { interfacePreferenceService } from '$lib/utils/interfacePreference';
	import { supabase } from '$lib/utils/supabase';
	import { dataService } from '$lib/utils/dataService';
	import { realtimeService } from '$lib/utils/realtimeService';
	// import { goAPI } from '$lib/utils/goAPI'; // Removed - Go backend no longer used
	import { localeData } from '$lib/i18n';
	
	let currentUserData = null;
	let stats = {
		pendingTasks: 0,
		pendingToClose: 0,
		closedBoxes: 0,
		inUseBoxes: 0,
		pendingChecklists: 0
	};
	let hasAssignedChecklists = false;
	let isLoading = true;
	let currentTime = new Date();
	let unsubscribeFingerprint: (() => void) | null = null;
	let employeeCode: string | null = null; // Store employee code for realtime subscription
	
	// Computed formatted time and date based on current locale
	$: formattedTime = currentTime.toLocaleTimeString($localeData.code === 'ar' ? 'ar-SA' : 'en-US', { hour: '2-digit', minute: '2-digit' });
	$: formattedDate = currentTime.toLocaleDateString($localeData.code === 'ar' ? 'ar-SA' : 'en-US', { weekday: 'long', month: 'short', day: 'numeric', year: 'numeric' });
	
	// Punch/Fingerprint Data - Store last 2 punches
	let punches = {
		records: [],
		loading: false,
		error: ''
	};

	// Attendance analysis data for today and yesterday
	let attendanceToday: any = null;
	let attendanceYesterday: any = null;
	let attendanceLoading = false;
	// Shift info looked up directly from shift tables (priority: special_shift_date_wise → special_shift_weekday → regular_shift)
	let todayShiftInfo: { shift_end_time: string; shift_start_time: string; is_shift_overlapping_next_day: boolean } | null = null;

	/** Check if shift end time has passed (Saudi timezone) for today's attendance.
	 *  Uses todayShiftInfo from shift tables (not from analysed data).
	 *  For overlapping shifts (e.g. 20:00-08:00), shift always ends next day → not passed yet today. */
	function isTodayShiftEndPassed(att: any): boolean {
		// Use shift info from shift tables if available
		if (todayShiftInfo) {
			// If shift overlaps to next day, it can't have ended today
			if (todayShiftInfo.is_shift_overlapping_next_day) return false;
			const nowSaudi = new Date().toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit', second: '2-digit', hour12: false, timeZone: 'Asia/Riyadh' });
			return nowSaudi >= todayShiftInfo.shift_end_time.slice(0, 8);
		}
		// Fallback to analysed data shift_end_time
		if (!att?.shift_end_time) return false;
		const nowSaudi = new Date().toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit', second: '2-digit', hour12: false, timeZone: 'Asia/Riyadh' });
		return nowSaudi >= att.shift_end_time.slice(0, 8);
	}

	/** Get display status for today — if Absent/Missing but shift not over yet, show 'Not yet' */
	function getTodayDisplayStatus(att: any): string {
		if (!att) return '';
		const isNotFinal = att.status === 'Absent' || att.status?.includes('Missing');
		if (isNotFinal && !isTodayShiftEndPassed(att)) {
			return $localeData.code === 'ar' ? 'لم يحن الوقت بعد' : 'Not yet';
		}
		return translateStatus(att.status);
	}

	/** Translate attendance status to Arabic */
	const statusTranslations: Record<string, string> = {
		'Worked': 'حاضر',
		'Absent': 'غائب',
		'Official Day Off': 'يوم إجازة رسمي',
		'Approved Leave (Deductible)': 'إجازة معتمدة (قابلة للخصم)',
		'Approved Leave (No Deduction)': 'إجازة معتمدة (بدون خصم)',
		'Pending Approval': 'بانتظار الموافقة',
		'Rejected-Deducted': 'مرفوض - مخصوم',
		'Rejected-Not Deducted': 'مرفوض - غير مخصوم',
		'Check-In Missing': 'تسجيل الدخول مفقود',
		'Check-Out Missing': 'تسجيل الخروج مفقود',
	};

	function translateStatus(status: string): string {
		if (!status) return '';
		if ($localeData.code === 'ar') {
			return statusTranslations[status] || status;
		}
		return status;
	}

	/** Convert HH:MM:SS or HH:MM to 12-hour format (locale-aware) */
	function to12h(time: string | null): string {
		if (!time) return '';
		const [h, m] = time.split(':').map(Number);
		const timeDate = new Date(2000, 0, 1, h, m);
		const locale = $localeData.code === 'ar' ? 'ar-SA' : 'en-US';
		return timeDate.toLocaleTimeString(locale, { hour: '2-digit', minute: '2-digit', hour12: true });
	}

	/** Format shift_date (YYYY-MM-DD) as "DayName DD-MM-YYYY" (locale-aware) */
	function formatAttDate(dateStr: string): string {
		if (!dateStr) return '';
		const d = new Date(dateStr + 'T00:00:00');
		const locale = $localeData.code === 'ar' ? 'ar-SA' : 'en-US';
		const dayName = d.toLocaleDateString(locale, { weekday: 'short' });
		const formatted = d.toLocaleDateString(locale, { day: '2-digit', month: '2-digit', year: 'numeric' });
		// Rearrange to DD-MM-YYYY with dashes
		const parts = new Intl.DateTimeFormat(locale, { day: '2-digit', month: '2-digit', year: 'numeric' }).formatToParts(d);
		const dd = parts.find(p => p.type === 'day')?.value;
		const mm = parts.find(p => p.type === 'month')?.value;
		const yyyy = parts.find(p => p.type === 'year')?.value;
		return `${dayName} ${dd}-${mm}-${yyyy}`;
	}
	
	// Update time every second
	let timeInterval: ReturnType<typeof setInterval>;
	// Computed role check
	$: userRole = currentUserData?.role || 'Position-based';
	$: isAdminOrMaster = userRole === 'Admin' || userRole === 'Master Admin';
	// Format date as dd-mm-yyyy
	function formatChecklistDate(date = new Date()): string {
		const day = String(date.getDate()).padStart(2, '0');
		const month = String(date.getMonth() + 1).padStart(2, '0');
		const year = date.getFullYear();
		return `${day}-${month}-${year}`;
	}
	
	// Helper function to get translations
	function getTranslation(keyPath: string): string {
		const keys = keyPath.split('.');
		let value: any = $localeData.translations;
		for (const key of keys) {
			if (value && typeof value === 'object' && key in value) {
				value = value[key];
			} else {
				return keyPath; // Return key path if translation not found
			}
		}
		return typeof value === 'string' ? value : keyPath;
	}
	
	onMount(async () => {
		currentUserData = $currentUser;
		if (currentUserData) {
			// Load dashboard data from Go backend (combines tasks + punches)
			await loadDashboardData();
		}
		isLoading = false;
		
		// Update time every second
		timeInterval = setInterval(() => {
			currentTime = new Date();
		}, 1000);
		
		// Cleanup on destroy
		return () => {
			if (timeInterval) clearInterval(timeInterval);
			if (unsubscribeFingerprint) {
				console.log('🔌 Cleaning up fingerprint realtime subscription');
				unsubscribeFingerprint();
			}
		};
	});
	
	onDestroy(() => {
		if (unsubscribeFingerprint) {
			unsubscribeFingerprint();
		}
	});
	
	async function loadBoxOperationsCounts() {
		try {
			if (!currentUserData?.id) {
				console.warn('⚠️ No user ID for box operations count');
				return;
			}
			
			console.log('📦 Loading box operations counts for user:', currentUserData.id);
			
			// Get pending to close count
			const { count: pendingCount, error: pendingError } = await supabase
				.from('box_operations')
				.select('*', { count: 'exact', head: true })
				.eq('user_id', currentUserData.id)
				.eq('status', 'pending_close');
			
			if (pendingError) {
				console.error('❌ Error loading pending to close count:', pendingError);
			} else {
				stats.pendingToClose = pendingCount || 0;
				console.log('📦 Pending to close boxes:', stats.pendingToClose);
			}
			
			// Get total completed count (all time)
			const { count: completedCount, error: completedError } = await supabase
				.from('box_operations')
				.select('*', { count: 'exact', head: true })
				.eq('user_id', currentUserData.id)
				.eq('status', 'completed');
			
			if (completedError) {
				console.error('❌ Error loading closed boxes count:', completedError);
			} else {
				stats.closedBoxes = completedCount || 0;
				console.log('✅ Total closed boxes:', stats.closedBoxes);
			}
			
			// Get in use count
			const { count: inUseCount, error: inUseError } = await supabase
				.from('box_operations')
				.select('*', { count: 'exact', head: true })
				.eq('user_id', currentUserData.id)
				.eq('status', 'in_use');
			
			if (inUseError) {
				console.error('❌ Error loading in use boxes count:', inUseError);
			} else {
				stats.inUseBoxes = inUseCount || 0;
				console.log('🔄 In use boxes:', stats.inUseBoxes);
			}
			
			console.log('📊 Final stats:', stats);
		} catch (error) {
			console.error('❌ Error loading box operations counts:', error);
		}
	}
	
	async function loadPendingChecklistsCount() {
		try {
			if (!currentUserData?.id) {
				console.warn('⚠️ No user ID for pending checklists count');
				return;
			}

			console.log('📋 Loading pending checklists count for user:', currentUserData.id);

			// Get employee ID for the current user
			const { data: employeeData, error: empError } = await supabase
				.from('hr_employee_master')
				.select('id')
				.eq('user_id', currentUserData.id)
				.single();

			if (empError || !employeeData) {
				console.warn('⚠️ Employee record not found:', empError);
				return;
			}

			const employeeId = employeeData.id;

			// Get today's date (ISO format)
			const today = new Date().toISOString().split('T')[0];

			// Get checklists assigned to user
			const { data: assignments, error: assignmentError } = await supabase
				.from('employee_checklist_assignments')
				.select('id, frequency_type, day_of_week, checklist_id')
				.eq('assigned_to_user_id', currentUserData.id)
				.is('deleted_at', null)
				.eq('is_active', true);

			if (assignmentError) {
				console.error('❌ Error loading checklist assignments:', assignmentError);
				return;
			}

			// Get today's submissions to exclude submitted checklists
			const { data: submissions, error: submissionsError } = await supabase
				.from('hr_checklist_operations')
				.select('checklist_id')
				.eq('employee_id', employeeId)
				.eq('operation_date', today);

			if (submissionsError) {
				console.error('❌ Error loading submissions:', submissionsError);
				return;
			}

			const submittedChecklistIds = new Set((submissions || []).map((s) => s.checklist_id));

			// Check if user has any assigned checklists
			hasAssignedChecklists = assignments && assignments.length > 0;

			// Get today's day of week for weekly checklists
			const today_date = new Date();
			const saudiTimezone = 'Asia/Riyadh';
			const saudiDate = new Date(
				new Intl.DateTimeFormat('en-CA', {
					timeZone: saudiTimezone,
					year: 'numeric',
					month: '2-digit',
					day: '2-digit'
				}).format(today_date)
			);
			const saToday = saudiDate.getDay();

			// Count pending checklists
			let pendingCount = 0;
			if (assignments) {
				for (const assignment of assignments) {
					// Skip if already submitted today
					if (submittedChecklistIds.has(assignment.checklist_id)) {
						continue;
					}
					// Allow daily checklists
					if (assignment.frequency_type === 'daily') {
						pendingCount++;
					}
					// Allow weekly checklists for today
					if (assignment.frequency_type === 'weekly' && assignment.day_of_week === saToday) {
						pendingCount++;
					}
				}
			}

			stats.pendingChecklists = pendingCount;
			console.log('📋 Pending checklists count:', stats.pendingChecklists);
		} catch (error) {
			console.error('❌ Error loading pending checklists count:', error);
		}
	}
	
	function handleViewOffer(event: CustomEvent) {
		selectedOffer = event.detail;
		showOfferModal = true;
	}

	function closeOfferModal() {
		showOfferModal = false;
		selectedOffer = null;
	}
	async function loadDashboardData() {
		try {
			const startTime = performance.now();
			console.log('🔍 Loading mobile dashboard from Supabase...');
			
			// Step 1: Get current user's UUID
			const userUuid = currentUserData?.id;
			console.log('👤 Step 1 - Current user UUID:', userUuid);
			
			if (!userUuid) {
				console.warn('⚠️ Current user UUID not found');
				punches = {
					records: [],
					loading: false,
					error: 'User ID not found'
				};
				return;
			}
		
		// Step 2: Look up hr_employee_master record to get employee code mapping
		console.log('🔍 Step 2 - Looking up employee record in hr_employee_master...');
		const { data: employeeRecord, error: empError } = await supabase
			.from('hr_employee_master')
			.select('id, current_branch_id, employee_id_mapping')
			.eq('user_id', userUuid)
			.single();
		
		if (empError || !employeeRecord) {
			console.warn('⚠️ Employee record not found:', empError);
			punches = {
				records: [],
				loading: false,
				error: 'Employee record not found'
			};
			return;
		}
		
		console.log('👥 Step 2 - Employee record:', employeeRecord);
		
		// Step 3: Extract ALL employee codes from employee_id_mapping (across all branches)
		console.log('🔍 Step 3 - Extracting all employee codes from mapping...');
		const employeeIdMapping = employeeRecord.employee_id_mapping;
		
		let allEmployeeCodes = [];
		if (typeof employeeIdMapping === 'string') {
			const mappingObj = JSON.parse(employeeIdMapping);
			allEmployeeCodes = Object.values(mappingObj) as string[];
		} else {
			allEmployeeCodes = Object.values(employeeIdMapping) as string[];
		}
		
		if (!allEmployeeCodes || allEmployeeCodes.length === 0) {
			console.warn('⚠️ No employee codes found in mapping');
			punches = {
				records: [],
				loading: false,
				error: 'No employee codes found'
			};
			return;
		}
		
		console.log('🎯 Step 3 - Found employee codes across all branches:', allEmployeeCodes);
		
		// Step 4: Load attendance analysis data for today and yesterday
		console.log('🔍 Step 4 - Loading attendance analysis data...');
		attendanceLoading = true;
		try {
			const today = new Date();
			const yesterday = new Date(today);
			yesterday.setDate(yesterday.getDate() - 1);
			const todayStr = today.toLocaleDateString('en-CA', { timeZone: 'Asia/Riyadh' });
			const yesterdayStr = yesterday.toLocaleDateString('en-CA', { timeZone: 'Asia/Riyadh' });

			const { data: attData, error: attError } = await supabase
				.from('hr_analysed_attendance_data')
				.select('*')
				.eq('employee_id', employeeRecord.id)
				.in('shift_date', [todayStr, yesterdayStr])
				.order('shift_date', { ascending: false });

			if (attError) {
				console.error('Error loading attendance data:', attError);
			} else if (attData) {
				attendanceToday = attData.find(r => r.shift_date === todayStr) || null;
				attendanceYesterday = attData.find(r => r.shift_date === yesterdayStr) || null;
				console.log('✅ Step 4 - Today:', attendanceToday, 'Yesterday:', attendanceYesterday);
			}
		} catch (e) {
			console.error('Error in attendance data load:', e);
		} finally {
			attendanceLoading = false;
		}

		// Step 4b: Look up today's shift end time from shift tables (priority: special_shift_date_wise → special_shift_weekday → regular_shift)
		try {
			const todaySaudi = new Date().toLocaleDateString('en-CA', { timeZone: 'Asia/Riyadh' });
			const todayWeekday = new Date(new Date().toLocaleString('en-US', { timeZone: 'Asia/Riyadh' })).getDay(); // 0=Sun, 5=Fri

			// 1) Check special_shift_date_wise first
			const { data: dateShift } = await supabase
				.from('special_shift_date_wise')
				.select('shift_end_time, shift_start_time, is_shift_overlapping_next_day')
				.eq('employee_id', employeeRecord.id)
				.eq('shift_date', todaySaudi)
				.maybeSingle();

			if (dateShift) {
				todayShiftInfo = dateShift;
				console.log('✅ Step 4b - Shift from special_shift_date_wise:', todayShiftInfo);
			} else {
				// 2) Check special_shift_weekday
				const { data: weekdayShift } = await supabase
					.from('special_shift_weekday')
					.select('shift_end_time, shift_start_time, is_shift_overlapping_next_day')
					.eq('employee_id', employeeRecord.id)
					.eq('weekday', todayWeekday)
					.maybeSingle();

				if (weekdayShift) {
					todayShiftInfo = weekdayShift;
					console.log('✅ Step 4b - Shift from special_shift_weekday:', todayShiftInfo);
				} else {
					// 3) Fallback to regular_shift (id = employee_id)
					const { data: regShift } = await supabase
						.from('regular_shift')
						.select('shift_end_time, shift_start_time, is_shift_overlapping_next_day')
						.eq('id', employeeRecord.id)
						.maybeSingle();

					if (regShift) {
						todayShiftInfo = regShift;
						console.log('✅ Step 4b - Shift from regular_shift:', todayShiftInfo);
					} else {
						console.warn('⚠️ Step 4b - No shift info found for employee');
					}
				}
			}
		} catch (e) {
			console.error('Error looking up shift info:', e);
		}

		// Step 5: Also load last 2 raw punches for backward compatibility
		console.log('🔍 Step 5 - Searching fingerprint transactions for all branches...');
		const { data: punchData, error: punchError } = await supabase
			.from('hr_fingerprint_transactions')
			.select('*')
			.in('employee_id', allEmployeeCodes)
			.order('date', { ascending: false })
			.order('time', { ascending: false })
			.limit(2);
			
			console.log('📊 Step 5 - Punch data:', punchData);
			console.log('❌ Step 5 - Error:', punchError);
			
			if (punchError) {
				console.error('Error loading punches:', punchError);
				punches = {
					records: [],
					loading: false,
					error: punchError.message
				};
				return;
			}
			
		// Step 6: Display the last 2 punch records
			if (punchData && punchData.length > 0) {
				console.log('✅ Step 6 - Found', punchData.length, 'punch records');
				
				const punchRecords = punchData
					.map(punch => {
						// Convert time to locale-aware format
						let formattedTime = punch.time || '';
						if (formattedTime) {
							try {
								// Parse time string (HH:MM:SS or HH:MM)
								const [hours, minutes] = formattedTime.split(':').slice(0, 2);
								const hour = parseInt(hours, 10);
								const minute = minutes || '00';
								
								// Use locale-aware formatting
								const timeDate = new Date(2000, 0, 1, hour, parseInt(minute, 10));
								const locale = $localeData.code === 'ar' ? 'ar-SA' : 'en-US';
								formattedTime = timeDate.toLocaleTimeString(locale, { hour: '2-digit', minute: '2-digit' });
							} catch (e) {
								console.error('Error formatting time:', e);
							}
						}
						
						// Format date with locale awareness
						let formattedDate = punch.date || '';
						if (formattedDate) {
							try {
								const dateObj = new Date(formattedDate);
								const locale = $localeData.code === 'ar' ? 'ar-SA' : 'en-US';
								formattedDate = dateObj.toLocaleDateString(locale, { month: 'short', day: 'numeric', year: 'numeric' });
							} catch (e) {
								console.error('Error formatting date:', e);
							}
						}
						
						// Map database columns to display format
						const mappedPunch = {
							time: formattedTime,
							date: formattedDate,
							status: punch.status === 'Check In' ? 'check-in' : 'check-out',
							raw: punch
						};
						console.log('📍 Mapped punch:', mappedPunch);
						return mappedPunch;
					});
				
				console.log('✅ Step 6 - Displaying', punchRecords.length, 'punch records');
				punches = {
					records: punchRecords,
					loading: false,
					error: ''
				};
			} else {
				console.log('ℹ️ Step 6 - No punch records found');
				punches = {
					records: [],
					loading: false,
					error: ''
				};
			}
			
			// Step 7: Setup real-time subscription for this employee's punches (all branches)
			console.log('📡 Step 7 - Setting up real-time subscription for employee codes:', allEmployeeCodes);
			if (unsubscribeFingerprint) {
				console.log('🔌 Cleaning up previous subscription');
				unsubscribeFingerprint();
			}
			
			// Subscribe to all employee codes
			unsubscribeFingerprint = realtimeService.subscribeToEmployeeFingerprintChangesMultiple(
				allEmployeeCodes,
				(payload) => {
					console.log('🔔 Real-time punch update received:', payload);
					
					// Only process changes for today
					const today = new Date().toISOString().split('T')[0];
					const punchDate = payload.new?.date || payload.old?.date;
					
					if (punchDate !== today) {
						console.log('⏭️ Punch is not for today, skipping');
						return;
					}
					
					if (payload.eventType === 'INSERT') {
						// New punch record - format and add to display
						const newPunch = payload.new;
						let formattedTime = newPunch.time || '';
						
						if (formattedTime) {
							try {
								const [hours, minutes] = formattedTime.split(':').slice(0, 2);
								const hour = parseInt(hours, 10);
								const minute = minutes || '00';
								const ampm = hour >= 12 ? 'PM' : 'AM';
								const hour12 = hour % 12 || 12;
								formattedTime = `${hour12.toString().padStart(2, '0')}:${minute} ${ampm}`;
							} catch (e) {
								console.error('Error formatting realtime punch time:', e);
							}
						}
						
						const mappedNewPunch = {
							time: formattedTime,
							date: newPunch.date || '',
							status: newPunch.status === 'Check In' ? 'check-in' : 'check-out',
							raw: newPunch
						};
						
						// Add to beginning of list and keep only last 2
						punches.records = [mappedNewPunch, ...punches.records].slice(0, 2);
						console.log('✅ Punch list updated in real-time:', punches.records);
					}
				}
			);
			
			console.log('✅ Real-time subscription set up successfully');
			
			// Load box operations counts
			await loadBoxOperationsCounts();
			
			// Load pending checklists count
			await loadPendingChecklistsCount();
			
			// Set pending tasks to 0 for now (TODO: implement task loading)
			stats.pendingTasks = 0;
			
			const endTime = performance.now();
			console.log(`✅ Dashboard loaded in ${(endTime - startTime).toFixed(2)}ms`);
			
		} catch (error) {
			console.error('Error loading dashboard data:', error);
			punches = {
				records: [],
				loading: false,
				error: error instanceof Error ? error.message : 'Failed to load punch data'
			};
		}
	}

	// Helper function to get proper file URL
	function getFileUrl(attachment) {
		const baseUrl = 'https://supabase.urbanaqura.com/storage/v1/object/public';
		if (attachment.type === 'task_image') {
			// Task images use file_url or file_path
			const fileName = attachment.file_url || attachment.file_path;
			if (fileName) {
				const url = `${baseUrl}/task-images/${fileName}`;
				return url;
			}
		} else if (attachment.type === 'quick_task_file') {
			// Quick task files use storage_path
			if (attachment.storage_path) {
				const url = `${baseUrl}/quick-task-files/${attachment.storage_path}`;
				return url;
			}
		} else if (attachment.type === 'notification_attachment') {
			// Notification attachments use file_path
			const fileName = attachment.file_path || attachment.file_url;
			if (fileName) {
				const url = `${baseUrl}/notification-images/${fileName}`;
				return url;
			}
		}
		// Fallback: if it's already a full URL, use it
		if (attachment.file_url && attachment.file_url.startsWith('http')) {
			return attachment.file_url;
		}
		return null;
	}
	// Helper function to download files
	function downloadFile(attachment) {
		const downloadUrl = getFileUrl(attachment);
		if (downloadUrl) {
			// Create a temporary link and trigger download
			const link = document.createElement('a');
			link.href = downloadUrl;
			link.download = attachment.file_name || 'download';
			link.target = '_blank';
			link.rel = 'noopener noreferrer';
			document.body.appendChild(link);
			link.click();
			document.body.removeChild(link);
		} else {
			console.error('No download URL available for attachment:', attachment);
		}
	}
	// Image preview functions
	function openImagePreview(attachment) {
		previewImage = {
			url: getFileUrl(attachment),
			name: attachment.file_name,
			source: attachment.source || 'Unknown'
		};
		showImagePreview = true;
	}
	function closeImagePreview() {
		showImagePreview = false;
		previewImage = null;
	}
	function formatDate(dateString) {
		const date = new Date(dateString);
		const now = new Date();
		const diffInMs = now.getTime() - date.getTime();
		const diffInHours = diffInMs / (1000 * 60 * 60);
		const diffInDays = diffInMs / (1000 * 60 * 60 * 24);
		if (diffInHours < 1) {
			const diffInMinutes = Math.floor(diffInMs / (1000 * 60));
			return `${diffInMinutes}m ago`;
		} else if (diffInHours < 24) {
			return `${Math.floor(diffInHours)}h ago`;
		} else if (diffInDays < 7) {
			return `${Math.floor(diffInDays)}d ago`;
		} else {
			return date.toLocaleDateString();
		}
	}
	function logout() {
		// Clear interface preference to allow user to choose again
		interfacePreferenceService.clearPreference(currentUserData?.id);
		// Logout from persistent auth service
		persistentAuthService.logout().then(() => {
			// Redirect to login page to choose interface again
			goto('/login');
		}).catch((error) => {
			console.error('Logout error:', error);
			// Still redirect even if logout fails
			goto('/login');
		});
	}
	function openCreateNotification() {
		showCreateNotificationModal = true;
	}
	function closeCreateNotification() {
		showCreateNotificationModal = false;
		// Refresh notifications after creating a new one
		loadDashboardData();
	}
</script>
<svelte:head>
	<title>Dashboard - Aqura Mobile</title>
</svelte:head>
<div class="mobile-dashboard">
	{#if isLoading}
		<div class="loading-content">
			<div class="loading-spinner"></div>
			<p>{getTranslation('mobile.dashboardContent.branchPerformance.loadingDashboard')}</p>
		</div>
	{:else}
		<!-- Stats Grid -->
		<section class="stats-section">
			<div class="stats-grid">
			<div class="stat-card date-time">
				<div class="stat-icon">
					<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<rect x="3" y="4" width="18" height="18" rx="2" ry="2"/>
						<line x1="16" y1="2" x2="16" y2="6"/>
						<line x1="8" y1="2" x2="8" y2="6"/>
						<line x1="3" y1="10" x2="21" y2="10"/>
					</svg>
				</div>
				<div class="stat-info">
					<h3>{formattedTime}</h3>
					<p>{formattedDate}</p>
				</div>
			</div>
			<div class="stat-card pending">
				<div class="stat-icon">
					<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<circle cx="12" cy="12" r="10"/>
						<polyline points="12,6 12,12 16,14"/>
					</svg>
				</div>
				<div class="stat-info">
					<h3>{stats.pendingTasks}</h3>
					<p>{getTranslation('mobile.dashboardContent.stats.pendingTasks')}</p>
				</div>
			</div>
			<div class="stat-card attendance-card clickable" on:click={() => goto('/mobile-interface/fingerprint-analysis')}>
				<div class="stat-icon" style="background: rgba(16, 185, 129, 0.1); color: #10B981;">
					<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<rect x="3" y="4" width="18" height="18" rx="2" ry="2"/>
						<line x1="16" y1="2" x2="16" y2="6"/>
						<line x1="8" y1="2" x2="8" y2="6"/>
						<line x1="3" y1="10" x2="21" y2="10"/>
					</svg>
				</div>
				<div class="stat-info">
					<p class="attendance-label">{$localeData.code === 'ar' ? 'اليوم' : 'Today'}</p>
					{#if attendanceLoading}
						<div class="loading-text" style="font-size: 0.7rem;">...</div>
					{:else if attendanceToday}
						<p class="attendance-date">{formatAttDate(attendanceToday.shift_date)}</p>
						{@const isNotFinal = attendanceToday.status === 'Absent' || attendanceToday.status?.includes('Missing')}
						{@const shiftOver = isTodayShiftEndPassed(attendanceToday)}
						<p class="attendance-status" class:status-worked={attendanceToday.status === 'Worked'} class:status-absent={attendanceToday.status === 'Absent' && shiftOver} class:status-dayoff={attendanceToday.status === 'Official Day Off'} class:status-leave={attendanceToday.status?.includes('Leave')} class:status-missing={attendanceToday.status?.includes('Missing') && shiftOver} class:status-notyet={isNotFinal && !shiftOver}>
							{getTodayDisplayStatus(attendanceToday)}
						</p>
						{#if attendanceToday.check_in_time}
							<p class="attendance-time">✅ {to12h(attendanceToday.check_in_time)}{attendanceToday.check_out_time ? ' → ' + to12h(attendanceToday.check_out_time) : ''}</p>
						{/if}
						{#if attendanceToday.late_minutes > 0}
							<p class="attendance-late">⏰ {$localeData.code === 'ar' ? 'تأخير' : 'Late'}: {attendanceToday.late_minutes} {$localeData.code === 'ar' ? 'دقيقة' : 'min'}</p>
						{/if}
					{:else}
						<h3>—</h3>
						<p style="font-size: 0.6rem; color: #9CA3AF;">{$localeData.code === 'ar' ? 'لا توجد بيانات' : 'No data'}</p>
					{/if}
				</div>
			</div>
			<div class="stat-card attendance-card clickable" on:click={() => goto('/mobile-interface/fingerprint-analysis')}>
				<div class="stat-icon" style="background: rgba(99, 102, 241, 0.1); color: #6366F1;">
					<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<rect x="3" y="4" width="18" height="18" rx="2" ry="2"/>
						<line x1="16" y1="2" x2="16" y2="6"/>
						<line x1="8" y1="2" x2="8" y2="6"/>
						<line x1="3" y1="10" x2="21" y2="10"/>
					</svg>
				</div>
				<div class="stat-info">
					<p class="attendance-label">{$localeData.code === 'ar' ? 'أمس' : 'Yesterday'}</p>
					{#if attendanceLoading}
						<div class="loading-text" style="font-size: 0.7rem;">...</div>
					{:else if attendanceYesterday}
						<p class="attendance-date">{formatAttDate(attendanceYesterday.shift_date)}</p>
						<p class="attendance-status" class:status-worked={attendanceYesterday.status === 'Worked'} class:status-absent={attendanceYesterday.status === 'Absent'} class:status-dayoff={attendanceYesterday.status === 'Official Day Off'} class:status-leave={attendanceYesterday.status?.includes('Leave')} class:status-missing={attendanceYesterday.status?.includes('Missing')}>
							{translateStatus(attendanceYesterday.status)}
						</p>
						{#if attendanceYesterday.check_in_time}
							<p class="attendance-time">✅ {to12h(attendanceYesterday.check_in_time)}{attendanceYesterday.check_out_time ? ' → ' + to12h(attendanceYesterday.check_out_time) : ''}</p>
						{/if}
						{#if attendanceYesterday.late_minutes > 0}
							<p class="attendance-late">⏰ {$localeData.code === 'ar' ? 'تأخير' : 'Late'}: {attendanceYesterday.late_minutes} {$localeData.code === 'ar' ? 'دقيقة' : 'min'}</p>
						{/if}
					{:else}
						<h3>—</h3>
						<p style="font-size: 0.6rem; color: #9CA3AF;">{$localeData.code === 'ar' ? 'لا توجد بيانات' : 'No data'}</p>
					{/if}
				</div>
			</div>
			
			<!-- Blank Card 1 - Pending POS (only show if data exists) -->
			{#if stats.pendingToClose > 0}
				<div class="stat-card blank clickable pending-box" on:click={() => goto('/mobile-interface/pos-pending')}>
					<div class="stat-icon">
						<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<circle cx="12" cy="12" r="10"/>
							<polyline points="12 6 12 12 16 14"/>
						</svg>
					</div>
					<div class="stat-info">
						<h3>{stats.pendingToClose}</h3>
						<p>{getTranslation('boxOperations.posPending')}</p>
						<p class="click-hint">{$localeData.code === 'ar' ? 'اضغط للتفاصيل' : 'Click for details'}</p>
					</div>
				</div>
			{/if}
			
			<!-- Blank Card 2 - Closed POS (only show if data exists) -->
			{#if stats.closedBoxes > 0}
				<div class="stat-card blank clickable closed-box" on:click={() => goto('/mobile-interface/pos-closed')}>
					<div class="stat-icon">
						<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<polyline points="20 6 9 17 4 12"/>
						</svg>
					</div>
					<div class="stat-info">
						<h3>{stats.closedBoxes}</h3>
						<p>{getTranslation('boxOperations.posClosed')}</p>
						<p class="click-hint">{$localeData.code === 'ar' ? 'اضغط للتفاصيل' : 'Click for details'}</p>
					</div>
				</div>
			{/if}
			
			<!-- Blank Card 3 - Active POS (only show if data exists) -->
			{#if stats.inUseBoxes > 0}
				<div class="stat-card blank in-use-box">
					<div class="stat-icon">
						<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<circle cx="12" cy="12" r="1"/>
							<path d="M12 6v6M12 18v0"/>
							<path d="M6 12h6M18 12h0"/>
						</svg>
					</div>
					<div class="stat-info">
						<h3>{stats.inUseBoxes}</h3>
						<p>{getTranslation('boxOperations.inUse')}</p>
					</div>
				</div>
			{/if}

			<!-- My Checklist Card (always show) -->
			<div class="stat-card blank clickable my-checklist" on:click={() => stats.pendingChecklists > 0 && goto('/mobile-interface/my-checklist')} class:completed={stats.pendingChecklists === 0 && hasAssignedChecklists} class:disabled={stats.pendingChecklists === 0}>
				{#if stats.pendingChecklists > 0}
					<div class="stat-icon">
						<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<rect x="3" y="5" width="18" height="14" rx="2"/>
							<path d="M7 15h10M7 10h10"/>
						</svg>
					</div>
					<div class="stat-info">
						<h3>{stats.pendingChecklists}</h3>
						<p>{$localeData.code === 'ar' ? 'قائمة مجدولة' : 'Pending Checklists'}</p>
						<p class="click-hint">{$localeData.code === 'ar' ? 'اضغط للإرسال' : 'Click to submit'}</p>
					</div>
				{:else if hasAssignedChecklists}
					<div class="stat-icon completed">
						<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<polyline points="20 6 9 17 4 12"/>
						</svg>
					</div>
					<div class="stat-info">
						<h3 class="completed-date">{formatChecklistDate()}</h3>
						<p>{$localeData.code === 'ar' ? 'تم إرسال جميع القوائم' : 'All Checklists Submitted'}</p>
					</div>
				{:else}
					<div class="stat-icon">
						<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<rect x="3" y="5" width="18" height="14" rx="2"/>
							<path d="M7 15h10M7 10h10"/>
						</svg>
					</div>
					<div class="stat-info">
						<h3>—</h3>
						<p>{$localeData.code === 'ar' ? 'لا توجد قوائم مسندة' : 'No Checklists Assigned'}</p>
					</div>
				{/if}
			</div>
		</div>
	</section>
	{/if}
</div>

<style>
	.mobile-dashboard {
		min-height: 100vh;
		min-height: 100dvh;
		background: #F8FAFC;
		overflow-x: hidden;
		overflow-y: auto;
		-webkit-overflow-scrolling: touch;
		position: relative;
	}

	/* Featured Offers LED Screen - Top Section */
	.offers-section.led-screen {
		padding: 0;
		margin: 0;
		background: linear-gradient(180deg, #000000 0%, #1a1a1a 100%);
		min-height: 180px;
	}

	.offers-loading {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 3rem 2rem;
		color: #9CA3AF;
	}

	.loading-spinner-small {
		width: 24px;
		height: 24px;
		border: 3px solid rgba(255, 255, 255, 0.2);
		border-top: 3px solid #3B82F6;
		border-radius: 50%;
		animation: spin 1s linear infinite;
		margin-bottom: 1rem;
	}

	.offers-loading p {
		margin: 0;
		font-size: 0.875rem;
		color: rgba(255, 255, 255, 0.7);
	}

	.no-offers-message {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 3rem 2rem;
		text-align: center;
		color: rgba(255, 255, 255, 0.7);
	}

	.no-offers-message .offer-icon {
		font-size: 3rem;
		margin-bottom: 0.75rem;
		opacity: 0.5;
	}

	.no-offers-message p {
		margin: 0 0 0.5rem 0;
		font-size: 1rem;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.9);
	}

	.no-offers-message small {
		font-size: 0.8125rem;
		color: rgba(255, 255, 255, 0.5);
	}

	/* Loading */
	.loading-content {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 4rem 2rem;
		text-align: center;
		color: #6B7280;
	}
	.loading-spinner {
		width: 32px;
		height: 32px;
		border: 3px solid #E5E7EB;
		border-top: 3px solid #3B82F6;
		border-radius: 50%;
		animation: spin 1s linear infinite;
		margin-bottom: 1rem;
	}
	@keyframes spin {
		to {
			transform: rotate(360deg);
		}
	}
	/* Stats Section */
	.stats-section {
		padding: 1.2rem; /* Reduced from 1.5rem (20% smaller) */
	}

	.stats-grid {
		display: grid;
		grid-template-columns: repeat(2, 1fr);
		gap: 0.8rem; /* Reduced from 1rem (20% smaller) */
	}
	.stat-card {
		background: white;
		border-radius: 8px;
		padding: 0.6rem;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
		display: flex;
		align-items: center;
		gap: 0.4rem;
		transition: all 0.3s ease;
		text-decoration: none;
		color: inherit;
	}
	.stat-card:hover {
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
	}
	.stat-icon {
		width: 38px; /* Reduced from 48px (20% smaller) */
		height: 38px; /* Reduced from 48px (20% smaller) */
		border-radius: 10px; /* Reduced from 12px (20% smaller) */
		display: flex;
		align-items: center;
		justify-content: center;
		flex-shrink: 0;
	}
	.stat-card.date-time .stat-icon {
		background: rgba(139, 92, 246, 0.1);
		color: #8B5CF6;
	}
	.stat-card.pending .stat-icon {
		background: rgba(59, 130, 246, 0.1);
		color: #3B82F6;
	}
	.stat-card.performance .stat-icon {
		background: rgba(16, 185, 129, 0.1);
		color: #10B981;
	}
	.stat-card.notifications .stat-icon {
		background: rgba(245, 158, 11, 0.1);
		color: #F59E0B;
	}
	.stat-card.notifications {
		cursor: pointer;
	}
	.stat-card.notifications:hover {
		transform: translateY(-3px);
		box-shadow: 0 6px 16px rgba(245, 158, 11, 0.2);
	}
	.stat-card.notifications:active {
		transform: translateY(-1px);
	}
	.stat-card.total .stat-icon {
		background: rgba(107, 114, 128, 0.1);
		color: #6B7280;
	}
	.stat-card.punch .stat-icon {
		background: rgba(239, 68, 68, 0.1);
		color: #EF4444;
	}
	/* Attendance card styles */
	.attendance-card {
		cursor: pointer;
		border: 2px solid transparent;
		transition: all 0.2s ease;
	}
	.attendance-card:active {
		transform: scale(0.97);
	}
	.attendance-label {
		font-size: 0.6rem !important;
		font-weight: 700 !important;
		text-transform: uppercase;
		letter-spacing: 0.05em;
		color: #6B7280 !important;
		margin-bottom: 0.1rem !important;
	}
	.attendance-date {
		font-size: 0.55rem !important;
		color: #374151 !important;
		font-weight: 600;
		margin: 0 0 0.15rem 0 !important;
	}
	.attendance-status {
		font-size: 0.7rem !important;
		font-weight: 700 !important;
		margin: 0.1rem 0 !important;
	}
	.attendance-status.status-worked { color: #10B981 !important; }
	.attendance-status.status-absent { color: #EF4444 !important; }
	.attendance-status.status-dayoff { color: #6366F1 !important; }
	.attendance-status.status-leave { color: #F59E0B !important; }
	.attendance-status.status-missing { color: #F97316 !important; }
	.attendance-status.status-notyet { color: #9CA3AF !important; font-style: italic; }
	.attendance-time {
		font-size: 0.55rem !important;
		color: #6B7280 !important;
		margin: 0.1rem 0 0 0 !important;
	}
	.attendance-late {
		font-size: 0.55rem !important;
		color: #EF4444 !important;
		font-weight: 600;
		margin: 0.1rem 0 0 0 !important;
	}
	.stat-info h3 {
		font-size: 1rem;
		font-weight: 700;
		margin: 0 0 0.1rem 0;
		color: #1F2937;
	}
	.stat-info p {
		font-size: 0.625rem;
		color: #6B7280;
		margin: 0;
	}
	.punch-detail {
		width: 100%;
	}
	.punch-date {
		font-size: 0.5rem;
		color: #9CA3AF;
		margin-top: 0.2rem;
	}
	.punch-status {
		font-size: 0.5rem;
		margin-top: 0.2rem;
		font-weight: 600;
		text-transform: capitalize;
	}
	.punch-status.checkin {
		color: #10B981;
	}
	.punch-status.checkout {
		color: #EF4444;
	}
	
	.stat-card.blank .stat-icon {
		background: rgba(156, 163, 175, 0.1);
		color: #9CA3AF;
	}
	
	.stat-card.clickable {
		cursor: pointer;
		border: 2px solid transparent;
		transition: all 0.3s ease;
		position: relative;
		overflow: hidden;
	}

	/* Pending Box Styling */
	.pending-box {
		background: linear-gradient(135deg, #FED7AA 0%, #FDBA74 100%) !important;
	}

	.pending-box .stat-icon {
		background: rgba(253, 124, 0, 0.3) !important;
		color: #EA580C !important;
	}

	.pending-box h3 {
		color: #9A3412;
	}

	.pending-box p {
		color: #7C2D12;
	}

	/* Closed Box Styling */
	.closed-box {
		background: linear-gradient(135deg, #BBFBFE 0%, #A7F3D0 100%) !important;
	}

	.closed-box .stat-icon {
		background: rgba(16, 185, 129, 0.3) !important;
		color: #059669 !important;
	}

	.closed-box h3 {
		color: #1E40AF;
	}

	.closed-box p {
		color: #1E3A8A;
	}

	/* In Use Box Styling */
	.in-use-box {
		background: linear-gradient(135deg, #DDD6FE 0%, #C7D2FE 100%) !important;
	}

	.in-use-box .stat-icon {
		background: rgba(79, 70, 229, 0.3) !important;
		color: #4F46E5 !important;
	}

	.in-use-box h3 {
		color: #3730A3;
	}

	.in-use-box p {
		color: #312E81;
	}

	/* My Checklist Styling */
	.my-checklist .stat-icon {
		background: rgba(251, 146, 60, 0.1);
		color: #FB923C;
	}
	
	.my-checklist.completed .stat-icon.completed {
		background: rgba(34, 197, 94, 0.1);
		color: #22C55E;
	}
	
	.my-checklist.completed .completed-date {
		font-family: 'Courier New', monospace;
		font-weight: 600;
		color: #22C55E;
	}
	
	.my-checklist.disabled {
		cursor: default;
	}
	
	.my-checklist.disabled:hover {
		transform: none;
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
	}
	
	.stat-card.clickable:hover {
		transform: translateY(-5px);
		box-shadow: 0 12px 24px rgba(0, 0, 0, 0.15);
		border-color: rgba(0, 0, 0, 0.1);
	}
	
	.stat-card.clickable:active {
		transform: translateY(-2px);
	}

	.click-hint {
		font-size: 0.75rem;
		color: #9CA3AF;
		margin-top: 0.25rem !important;
		font-style: italic;
	}

	.loading-text {
		font-size: 0.625rem;
		color: #6B7280;
	}

	/* Branch Performance Section */
	.performance-section {
		padding: 0 1.2rem 1.2rem 1.2rem;
	}

	.section-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		margin-bottom: 1rem;
	}

	.section-header h2 {
		font-size: 1.25rem;
		font-weight: 700;
		color: #1F2937;
		margin: 0;
	}

	.refresh-btn {
		background: white;
		border: 1px solid #E5E7EB;
		border-radius: 8px;
		padding: 0.5rem;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: all 0.2s ease;
	}

	.refresh-btn:hover {
		background: #F3F4F6;
		border-color: #D1D5DB;
	}

	.refresh-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.refresh-btn svg {
		color: #6B7280;
	}

	.performance-loading {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 2rem;
		background: white;
		border-radius: 12px;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
	}

	.performance-loading p {
		color: #6B7280;
		font-size: 0.875rem;
		margin: 0;
	}

	.performance-group {
		margin-bottom: 1.5rem;
	}

	.group-title {
		font-size: 1.125rem;
		font-weight: 600;
		color: #1F2937;
		margin: 0 0 1rem 0;
		padding: 0.5rem 0.75rem;
		background: white;
		border-radius: 8px;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
	}

	.branch-grid {
		display: grid;
		grid-template-columns: repeat(2, 1fr);
		gap: 1rem;
	}

	.branch-card {
		background: white;
		border-radius: 6px;
		padding: 0.5rem;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
		display: flex;
		flex-direction: column;
		gap: 0.375rem;
	}

	.branch-name {
		font-size: 0.625rem;
		font-weight: 600;
		color: #1F2937;
		margin: 0;
		text-align: center;
	}

	.pie-chart-container {
		width: 100%;
		height: 140px;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.pie-chart {
		width: 100%;
		height: 100%;
		max-width: 150px;
		max-height: 150px;
	}

	.pie-percent {
		font-size: 10px;
		font-weight: 700;
		fill: #1F2937;
	}

	.pie-label {
		font-size: 6px;
		fill: #6B7280;
	}

	.pie-empty {
		font-size: 7px;
		fill: #9CA3AF;
	}

	.branch-stats {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}

	.stat-item {
		display: flex;
		align-items: center;
		gap: 0.25rem;
		font-size: 0.5rem;
		color: #6B7280;
	}

	.stat-item.completed .stat-dot {
		background: #10B981;
	}

	.stat-item.pending .stat-dot {
		background: #FCA5A5;
	}

	.stat-item.total {
		font-weight: 600;
		color: #1F2937;
		padding-top: 0.5rem;
		border-top: 1px solid #E5E7EB;
		justify-content: center;
	}

	.stat-dot {
		width: 6px;
		height: 6px;
		border-radius: 50%;
	}

	@media (max-width: 480px) {
		.branch-grid {
			grid-template-columns: 1fr;
		}
	}

	/* Safe area handling for iOS */
	@supports (padding: max(0px)) {
		.mobile-header {
			padding-top: max(1rem, env(safe-area-inset-top));
		}
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
		padding: 1rem;
	}
	.modal-container {
		background: white;
		border-radius: 12px;
		max-width: 500px;
		width: 100%;
		max-height: 90vh;
		overflow: hidden;
		box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04);
	}
	.modal-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 1rem 1.5rem;
		border-bottom: 1px solid #E5E7EB;
		background: #F9FAFB;
	}
	.modal-header h2 {
		margin: 0;
		font-size: 1.25rem;
		font-weight: 600;
		color: #1F2937;
	}
	.close-btn {
		background: none;
		border: none;
		padding: 0.5rem;
		cursor: pointer;
		border-radius: 6px;
		color: #6B7280;
		transition: all 0.2s ease;
	}
	.close-btn:hover {
		background: #E5E7EB;
		color: #374151;
	}
	.modal-content {
		padding: 0;
		overflow-y: auto;
		max-height: calc(90vh - 80px);
	}
</style>




