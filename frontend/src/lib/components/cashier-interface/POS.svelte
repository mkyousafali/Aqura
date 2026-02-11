<script lang="ts">
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { t, currentLocale } from '$lib/i18n';
	import { openWindow } from '$lib/utils/windowManagerUtils';
	import CloseBox from './CloseBox.svelte';
	import ClosingDetails from './ClosingDetails.svelte';
	import CounterCheck from './CounterCheck.svelte';
	import ReportIncident from '$lib/components/desktop-interface/master/hr/ReportIncident.svelte';

	export let branch: any;
	export let user: any;

	let availableBoxes: any[] = [];
	let operationBoxes: any[] = [];
	let loading = true;
	let fullBranch: any = null;
	let currencySymbolUrl = '/icons/saudi-currency.png';
	let userHasActiveOperation = false;

	// Checklist popup state
	let showChecklistPopup = false;
	let pendingBox: any = null;
	let checklists: any[] = [];
	let loadingChecklists = false;
	let selectedChecklist: any = null;
	let checklistQuestions: any[] = [];
	let loadingQuestions = false;
	let selectedAnswers: Record<string, string> = {};
	let remarksValues: Record<string, string> = {};
	let otherValues: Record<string, string> = {};
	let currentQuestionIndex = 0;

	// Generate unique window ID
	function generateWindowId(type: string): string {
		return `${type}-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
	}

	// Modal state
	let showModal = false;
	let selectedBox: any = null;
	let realCounts: Record<string, number> = {};
	let matchStatus: 'match' | 'mismatch' | null = null;
	let isStarting = false;
	let cashierAccessCode = '';
	let cashierName = '';
	let cashierCodeValid = false;
	let supervisorAccessCode = '';
	let supervisorName = '';
	let selectedPosNumber: number | null = null;
	let isValidated = false;
	let errorMessage = '';

	// Denomination values
	const denomValues: Record<string, number> = {
		'd500': 500,
		'd200': 200,
		'd100': 100,
		'd50': 50,
		'd20': 20,
		'd10': 10,
		'd5': 5,
		'd2': 2,
		'd1': 1,
		'd05': 0.5,
		'd025': 0.25,
		'coins': 1
	};

	// Helper function to get display name for box number
	function getBoxDisplayName(boxNum: number): string {
		if (boxNum === 10) return 'E1';
		if (boxNum === 11) return 'E2';
		if (boxNum === 12) return 'E3';
		return `${t('pos.box') || 'BOX'} ${boxNum}`;
	}

	const denomLabels: Record<string, string> = {
		'd500': '500',
		'd200': '200',
		'd100': '100',
		'd50': '50',
		'd20': '20',
		'd10': '10',
		'd5': '5',
		'd2': '2',
		'd1': '1',
		'd05': '0.5',
		'd025': '0.25',
		'coins': 'Coins'
	};

	let unsubscribeBoxOps: any;
	let unsubscribeDenomRecords: any;
	let previousBranchId: string | number | null = null;
	let previousUserId: string | null = null;
	let isRefreshing = false;

	onMount(async () => {
		console.log('POS Component mounted with branch:', branch);
		console.log('Branch ID:', branch?.id);
		console.log('User ID:', user?.id || user?.user_id);
		
		if (branch && branch.id) {
			previousBranchId = branch.id;
			previousUserId = user?.id || user?.user_id;
			
			// Fetch full branch details including location
			await fetchFullBranch(branch.id);
			await fetchAvailableBoxes(branch.id);
			await fetchOperationBoxes(branch.id);
			
			// Set up realtime subscriptions
			setupRealtimeSubscriptions();
		}
		loading = false;
		
		// Cleanup subscriptions on unmount
		return () => {
			console.log('Cleaning up POS subscriptions on unmount');
			if (unsubscribeBoxOps) unsubscribeBoxOps();
			if (unsubscribeDenomRecords) unsubscribeDenomRecords();
		};
	});

	// Re-fetch when branch or user changes - FORCE FRESH DATA FROM DATABASE
	$: if (branch?.id && (user?.id || user?.user_id) && !isRefreshing) {
		const currentBranchId = branch.id;
		const currentUserId = user?.id || user?.user_id;
		
		// Only trigger if branch or user actually changed
		if (previousBranchId !== currentBranchId || previousUserId !== currentUserId) {
			console.log('⚠️ BRANCH OR USER CHANGED - CLEARING ALL CACHED DATA AND FETCHING FRESH');
			console.log('Old Branch:', previousBranchId, 'New Branch:', currentBranchId);
			console.log('Old User:', previousUserId, 'New User:', currentUserId);
			
			previousBranchId = currentBranchId;
			previousUserId = currentUserId;
			
			isRefreshing = true;
			
			// Unsubscribe from old subscriptions
			if (unsubscribeBoxOps) unsubscribeBoxOps();
			if (unsubscribeDenomRecords) unsubscribeDenomRecords();
			
			// Reset ALL data to empty - FORCE FRESH START
			operationBoxes = [];
			availableBoxes = [];
			fullBranch = null;
			userHasActiveOperation = false;
			
			// Force reload from database ONLY
			(async () => {
				loading = true;
				try {
					await fetchFullBranch(currentBranchId);
					await fetchAvailableBoxes(currentBranchId);
					await fetchOperationBoxes(currentBranchId);
					setupRealtimeSubscriptions();
				} finally {
					loading = false;
					isRefreshing = false;
				}
			})();
		}
	}

	function setupRealtimeSubscriptions() {
		console.log('Setting up real-time subscriptions for branch:', branch.id);
		
		// Subscribe to box_operations changes
		const boxOpsChannel = supabase
			.channel(`box-operations-${branch.id}-${Date.now()}`)
			.on(
				'postgres_changes',
				{
					event: '*',
					schema: 'public',
					table: 'box_operations',
					filter: `branch_id=eq.${branch.id}`
				},
				async (payload) => {
					console.log('🔄 Real-time box operation change detected:', payload);
					// Always fetch fresh from database
					await fetchOperationBoxes(branch.id);
					await fetchAvailableBoxes(branch.id);
				}
			)
			.subscribe((status) => {
				console.log('Box operations subscription status:', status);
			});

		unsubscribeBoxOps = () => {
			console.log('Unsubscribing from box operations');
			boxOpsChannel.unsubscribe();
		};

		// Subscribe to denomination_records changes
		const denomChannel = supabase
			.channel(`denomination-records-${branch.id}-${Date.now()}`)
			.on(
				'postgres_changes',
				{
					event: '*',
					schema: 'public',
					table: 'denomination_records',
					filter: `branch_id=eq.${branch.id}`
				},
				async (payload) => {
					console.log('🔄 Real-time denomination record change detected:', payload);
					// Always fetch fresh from database
					await fetchAvailableBoxes(branch.id);
				}
			)
			.subscribe((status) => {
				console.log('Denomination records subscription status:', status);
			});

		unsubscribeDenomRecords = () => {
			console.log('Unsubscribing from denomination records');
			denomChannel.unsubscribe();
		};
	}

	async function fetchFullBranch(branchId: string) {
		try {
			const { data, error } = await supabase
				.from('branches')
				.select('id, name_en, name_ar, location_en, location_ar')
				.eq('id', branchId)
				.single();

			if (error) throw error;
			fullBranch = data;
		} catch (error) {
			console.error('Error fetching branch details:', error);
			fullBranch = branch;
		}
	}

	$: if (fullBranch) {
		// Reactively update when locale changes
		fullBranch = fullBranch;
	}

	async function fetchAvailableBoxes(branchId: string) {
		try {
			console.log('📦 FETCHING AVAILABLE BOXES from database for branch:', branchId);
			
			// Fetch boxes from denomination_records for the selected branch
			const { data, error } = await supabase
				.from('denomination_records')
				.select('id, box_number, counts, grand_total, created_at, branch_id')
				.eq('branch_id', branchId)
				.eq('record_type', 'advance_box')
				.order('box_number', { ascending: true });

			if (error) throw error;
			
			console.log('✅ Fetched denomination records from database:', data?.length || 0, 'records');
			
			// Fetch boxes that are currently in use or pending close
			const { data: inUseBoxes, error: opError } = await supabase
				.from('box_operations')
				.select('box_number, user_id, status')
				.eq('branch_id', branchId)
				.in('status', ['in_use', 'pending_close']);

			if (opError) throw opError;

			console.log('✅ Fetched in-use/pending boxes from database:', inUseBoxes?.length || 0, 'boxes');
			
			const inUseBoxNumbers = new Set(inUseBoxes?.map(op => op.box_number) || []);
			
			// Create a map of box data
			const boxDataMap = new Map();
			data?.forEach(record => {
				// Only add if not in use or pending close
				if (!inUseBoxNumbers.has(record.box_number)) {
					boxDataMap.set(record.box_number, record);
				}
			});

			// Create available boxes array (1-12) with data
			availableBoxes = Array.from({ length: 12 }, (_, i) => {
				const boxNum = i + 1;
				const boxData = boxDataMap.get(boxNum);
				
				return {
					number: boxNum,
					available: !!boxData,
					counts: boxData?.counts || {},
					total: boxData?.grand_total || 0,
					id: boxData?.id
				};
			});
			
			console.log('✅ Available boxes updated:', availableBoxes.filter(b => b.available).length, 'boxes available');
		} catch (error) {
			console.error('❌ Error fetching boxes:', error);
		}
	}

	async function fetchOperationBoxes(branchId: string) {
		try {
			const userId = user?.id || user?.user_id;
			console.log('👤 FETCHING OPERATIONS from database for branch:', branchId, 'user:', userId);
			
			if (!userId) {
				console.warn('⚠️ No user ID available, skipping operation fetch');
				operationBoxes = [];
				userHasActiveOperation = false;
				return;
			}
			
			const { data, error } = await supabase
				.from('box_operations')
				.select('id, box_number, counts_before, counts_after, total_before, total_after, difference, is_matched, start_time, notes, user_id, status, closing_details')
				.eq('branch_id', branchId)
				.eq('user_id', userId)
				.in('status', ['in_use', 'pending_close'])
				.order('start_time', { ascending: false });

			if (error) throw error;

			console.log('✅ Fetched operations from database:', data?.length || 0, 'operations');
			operationBoxes = data || [];
			
			// Check if current user has any active operation (in_use status only for blocking)
			userHasActiveOperation = operationBoxes.some(op => op.status === 'in_use');
			console.log('👤 User has active operation:', userHasActiveOperation);
		} catch (error) {
			console.error('❌ Error fetching operation boxes:', error);
			operationBoxes = [];
			userHasActiveOperation = false;
		}
	}

	function openBoxModal(box: any) {
		if (userHasActiveOperation) {
			alert('You already have an active box operation. Please complete it before starting another one.');
			return;
		}
		
		// Show checklist popup first
		pendingBox = box;
		showChecklistPopup = true;
		loadChecklists();
	}

	async function loadChecklists() {
		loadingChecklists = true;
		const { data, error } = await supabase
			.from('hr_checklists')
			.select('id, checklist_name_en, checklist_name_ar, question_ids')
			.order('created_at', { ascending: true });
		if (!error) {
			checklists = data || [];
			// Auto-select CL1 (first checklist) and load its questions
			if (checklists.length > 0) {
				const cl1 = checklists.find(c => c.id === 'CL1') || checklists[0];
				await selectChecklist(cl1);
			}
		}
		loadingChecklists = false;
	}

	function closeChecklistPopup() {
		showChecklistPopup = false;
		pendingBox = null;
		selectedChecklist = null;
		checklistQuestions = [];
		selectedAnswers = {};
		remarksValues = {};
		otherValues = {};
		currentQuestionIndex = 0;
	}

	async function saveChecklistAndOpenModal() {
		if (!pendingBox || !selectedChecklist) return;

		// Build answers array with points
		const answersData: any[] = [];
		let totalPoints = 0;
		let maxPoints = 0;

		for (const q of checklistQuestions) {
			// Calculate max possible points for this question
			let questionMaxPoints = 0;
			for (let i = 1; i <= 6; i++) {
				const pts = q[`answer_${i}_points`] || 0;
				if (pts > questionMaxPoints) questionMaxPoints = pts;
			}
			if (q.has_other && (q.other_points || 0) > questionMaxPoints) {
				questionMaxPoints = q.other_points || 0;
			}
			maxPoints += questionMaxPoints;

			const answerKey = selectedAnswers[q.id];
			if (!answerKey) continue;

			let points = 0;
			let answerText = '';

			if (answerKey === 'other') {
				points = q.other_points || 0;
				answerText = 'Other';
			} else {
				// Extract answer index (a1 -> 1)
				const ansIdx = parseInt(answerKey.replace('a', ''));
				points = q[`answer_${ansIdx}_points`] || 0;
				answerText = q[`answer_${ansIdx}_en`] || q[`answer_${ansIdx}_ar`] || '';
			}

			totalPoints += points;

			answersData.push({
				question_id: q.id,
				answer_key: answerKey,
				answer_text: answerText,
				points: points,
				remarks: remarksValues[q.id] || null,
				other_value: answerKey === 'other' ? (otherValues[q.id] || null) : null
			});
		}

		console.log('Saving checklist operation:', {
			user_id: user?.id,
			checklist_id: selectedChecklist.id,
			answers: answersData,
			total_points: totalPoints,
			max_points: maxPoints,
			branch_id: branch?.id
		});

		// Lookup employee_id from hr_employee_master using user_id
		let employeeId: string | null = null;
		if (user?.id) {
			const { data: empData } = await supabase
				.from('hr_employee_master')
				.select('id')
				.eq('user_id', user.id)
				.single();
			if (empData) {
				employeeId = empData.id;
			}
		}

		// Save to hr_checklist_operations
		const { data, error } = await supabase
			.from('hr_checklist_operations')
			.insert({
				user_id: user?.id || null,
				employee_id: employeeId,
				box_number: pendingBox?.number || null,
				box_operation_id: null, // Box operation not created yet
				checklist_id: selectedChecklist.id,
				answers: answersData,
				total_points: totalPoints,
				max_points: maxPoints,
				branch_id: branch?.id || null,
				submission_type_en: 'POS',
				submission_type_ar: 'نقاط البيع'
			})
			.select('*, submission_type_en, submission_type_ar');

		if (error) {
			console.error('Error saving checklist operation:', error);
			alert('Error saving checklist: ' + error.message);
		} else {
			console.log('Checklist operation saved successfully:', data);
		}

		// Store pending box in selectedBox and open modal
		const boxToOpen = pendingBox;
		const checklistIdToSave = selectedChecklist.id;

		// Reset checklist popup state
		showChecklistPopup = false;
		pendingBox = null;
		selectedChecklist = null;
		checklistQuestions = [];
		selectedAnswers = {};
		remarksValues = {};
		otherValues = {};
		currentQuestionIndex = 0;

		// Open counter check as a window
		const windowId = `counter-check-${Date.now()}`;
		openWindow({
			id: windowId,
			title: `${getBoxDisplayName(boxToOpen.number)} - ${t('pos.counterCheck') || 'Counter Check'}`,
			component: CounterCheck,
			props: { 
				windowId,
				box: boxToOpen, 
				branch, 
				user 
			},
			icon: '📋',
			size: { width: 600, height: 700 },
			position: { x: 150, y: 50 },
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	async function selectChecklist(cl: any) {
		selectedChecklist = cl;
		loadingQuestions = true;
		
		// Get question IDs from the checklist
		const { data: fullCl, error: clError } = await supabase
			.from('hr_checklists')
			.select('question_ids')
			.eq('id', cl.id)
			.single();
		
		if (clError || !fullCl?.question_ids || fullCl.question_ids.length === 0) {
			checklistQuestions = [];
			loadingQuestions = false;
			return;
		}
		
		// Fetch questions by IDs
		const { data: questions, error: qError } = await supabase
			.from('hr_checklist_questions')
			.select('*')
			.in('id', fullCl.question_ids);
		
		if (!qError) {
			checklistQuestions = questions || [];
			// Initialize selected answers
			selectedAnswers = {};
			remarksValues = {};
			otherValues = {};
			currentQuestionIndex = 0;
		}
		loadingQuestions = false;
	}

	function goBackToChecklists() {
		selectedChecklist = null;
		checklistQuestions = [];
		selectedAnswers = {};
		remarksValues = {};
		otherValues = {};
		currentQuestionIndex = 0;
	}

	function openIncidentReport() {
		const windowId = generateWindowId('report-incident');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Report Incident #${instanceNumber}`,
			component: ReportIncident,
			icon: '📝',
			size: { width: 900, height: 700 },
			position: { 
				x: 50 + (Math.random() * 100),
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true,
			props: {
				violation: null,
				employees: [],
				branches: [],
				preSelectedIncidentType: 'IN3',
				preSelectedBranch: branch
			}
		});
	}

	function getQuestionAnswers(q: any): { key: string; en: string; ar: string; points: number }[] {
		const answers: { key: string; en: string; ar: string; points: number }[] = [];
		for (let i = 1; i <= 6; i++) {
			if (q[`answer_${i}_en`] || q[`answer_${i}_ar`]) {
				answers.push({
					key: `a${i}`,
					en: q[`answer_${i}_en`] || '',
					ar: q[`answer_${i}_ar`] || '',
					points: q[`answer_${i}_points`] || 0
				});
			}
		}
		return answers;
	}

	function closeModal() {
		showModal = false;
		selectedBox = null;
		realCounts = {};
		matchStatus = null;
		cashierAccessCode = '';
		cashierName = '';
		cashierCodeValid = false;
		supervisorAccessCode = '';
		supervisorName = '';
		isValidated = false;
	}

	function openCloseModal(operation: any) {
		const windowId = generateWindowId(`close-box-${operation.box_number}`);
		
		// If status is pending_close, open ClosingDetails (read-only view), otherwise open CloseBox (editable)
		const component = operation.status === 'pending_close' ? ClosingDetails : CloseBox;
		const title = operation.status === 'pending_close' 
			? `Closing Details - ${getBoxDisplayName(operation.box_number)}` 
			: `Close ${getBoxDisplayName(operation.box_number)}`;
		
		openWindow({
			id: windowId,
			title,
			component,
			props: {
				windowId,
				operation,
				branch: fullBranch || branch
			},
			icon: '📦',
			size: { width: 700, height: 700 },
			position: { x: 300, y: 100 },
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	function calculateRealTotal(): number {
		let total = 0;
		for (const [key, count] of Object.entries(realCounts)) {
			const numCount = typeof count === 'number' ? count : parseFloat(count as any) || 0;
			const denomValue = denomValues[key] || 0;
			total += numCount * denomValue;
		}
		return total;
	}

	$: displayTotal = Object.entries(realCounts).reduce((sum, [key, count]) => {
		const numCount = typeof count === 'number' ? count : parseFloat(count as any) || 0;
		const denomValue = denomValues[key] || 0;
		return sum + (numCount * denomValue);
	}, 0);

	function checkMatchStatus() {
		if (!selectedBox) return;

		const existingTotal = selectedBox.total;
		const realTotal = calculateRealTotal();

		// Only show match status if user has entered at least one value
		if (realTotal > 0) {
			matchStatus = Math.abs(existingTotal - realTotal) < 0.01 ? 'match' : 'mismatch';
		} else {
			matchStatus = null;
		}
	}

	let checkTimeout: any;
	function triggerCheck() {
		clearTimeout(checkTimeout);
		checkTimeout = setTimeout(() => {
			checkMatchStatus();
		}, 500); // Increased to 500ms
	}

	function checkDenominationMatch(key: string): 'match' | 'mismatch' | null {
		const enteredValue = Number(realCounts[key]) || 0;
		if (enteredValue === 0) return null;
		
		const storedCount = Number(selectedBox?.counts?.[key] || 0);
		
		// Use tolerance-based comparison to handle floating-point precision issues
		return Math.abs(enteredValue - storedCount) < 0.0001 ? 'match' : 'mismatch';
	}

	async function startOperation() {
		if (!selectedBox || isStarting || !isValidated) return;

		isStarting = true;
		try {
			const realTotal = displayTotal;
			const difference = selectedBox.total - realTotal;
			const userId = user?.id || user?.user_id;

			console.log('📝 Starting operation for box:', selectedBox.number, 'user:', userId, 'branch:', branch.id);

			// Create box operation record
			const { data: operation, error: opError } = await supabase
				.from('box_operations')
				.insert({
					box_number: selectedBox.number,
					branch_id: branch.id,
					user_id: userId,
					denomination_record_id: selectedBox.id,
					counts_before: selectedBox.counts,
					counts_after: realCounts,
					total_before: selectedBox.total,
					total_after: realTotal,
					difference: difference,
					is_matched: matchStatus === 'match',
					status: 'in_use',
					start_time: new Date().toISOString(),
					notes: JSON.stringify({
						cashier_name: cashierName,
						cashier_access_code: cashierAccessCode,
						supervisor_name: supervisorName,
						pos_number: selectedPosNumber
					})
				})
				.select()
				.single();

			if (opError) throw opError;

			console.log('✅ Operation created:', operation.id);
			
			// Force refresh from database - don't use local state
			await fetchOperationBoxes(branch.id);
			await fetchAvailableBoxes(branch.id);
			
			closeModal();
		} catch (error) {
			console.error('❌ Error starting operation:', error);
			alert('Failed to start operation');
		} finally {
			isStarting = false;
		}
	}

	function handleModalKeydown(e: KeyboardEvent) {
		if (e.key === 'Escape') {
			closeModal();
		}
	}

	function formatDateTime(dateString: string): string {
		const date = new Date(dateString);
		const day = String(date.getDate()).padStart(2, '0');
		const month = String(date.getMonth() + 1).padStart(2, '0');
		const year = date.getFullYear();
		const hours = String(date.getHours()).padStart(2, '0');
		const minutes = String(date.getMinutes()).padStart(2, '0');
		const seconds = String(date.getSeconds()).padStart(2, '0');
		return `${day}/${month}/${year}, ${hours}:${minutes}:${seconds}`;
	}

	async function verifyCashierAccessCode() {
		if (!cashierAccessCode) {
			cashierCodeValid = false;
			cashierName = '';
			return;
		}

		try {
			// Check if access code matches logged user
			const { data, error } = await supabase
				.from('users')
				.select('id, username, quick_access_code')
				.eq('id', user.id)
				.single();

			if (error) throw error;

			if (data && data.quick_access_code === cashierAccessCode) {
				cashierCodeValid = true;
				cashierName = data.username || '';
			} else {
				cashierCodeValid = false;
				cashierName = '';
				errorMessage = $currentLocale === 'ar' ? 'رمز الدخول لا يتطابق مع المستخدم المسجل' : 'Access code does not match logged user';
			}
		} catch (error) {
			console.error('Error verifying cashier access code:', error);
			cashierCodeValid = false;
			cashierName = '';
		}
	}

	async function lookupSupervisorAccessCode() {
		if (!supervisorAccessCode) {
			supervisorName = '';
			return;
		}

		try {
			const { data, error } = await supabase
				.from('users')
				.select('username')
				.eq('quick_access_code', supervisorAccessCode)
				.single();

			if (error) throw error;

			if (data) {
				supervisorName = data.username || '';
			} else {
				supervisorName = '';
				errorMessage = $currentLocale === 'ar' ? 'الرجاء إدخال رمز الدخول الصحيح' : 'Please enter correct access code';
			}
		} catch (error) {
			console.error('Error looking up supervisor:', error);
			supervisorName = '';
			errorMessage = $currentLocale === 'ar' ? 'الرجاء إدخال رمز الدخول الصحيح' : 'Please enter correct access code';
		}
	}

	async function validateAccessCodes() {
		// Validate cashier access code matches logged user
		await verifyCashierAccessCode();
		
		if (!cashierCodeValid || !cashierName) {
			errorMessage = 'Cashier access code must match logged user';
			return;
		}

		// Validate supervisor access code
		await lookupSupervisorAccessCode();
		
		if (!supervisorName) {
			errorMessage = 'Please enter a valid supervisor access code';
			return;
		}

		// Check denomination matching after access codes validated
		checkMatchStatus();

		// All validations passed
		isValidated = true;
	}
</script>

<div class="pos-container">
	<div class="cards-grid">
		<div class="blank-card">
			<div class="card-header">
				<h3>{t('pos.availableBoxes') || 'Available Boxes'}</h3>
				<p class="branch-info">
					{#if $currentLocale === 'ar'}
						{fullBranch?.name_ar || branch?.name_ar || ''} - {fullBranch?.location_ar || ''}
					{:else}
						{fullBranch?.name_en || branch?.name_en || ''} - {fullBranch?.location_en || ''}
					{/if}
				</p>
			</div>
			<div class="card-content">
				{#if loading}
					<p class="loading">{t('common.loading') || 'Loading boxes...'}</p>
				{:else}
					{#if userHasActiveOperation}
						<p class="warning-message">{$currentLocale === 'ar' ? 'لديك عملية صندوق نشطة. أكملها قبل بدء عملية أخرى.' : 'You have an active box operation. Complete it before starting another one.'}</p>
					{/if}
					<div class="boxes-grid">
						{#each availableBoxes.filter(box => box.available && (box.total > 0 || box.number >= 10)) as box (box.number)}
							{@const boxOperation = operationBoxes.find(op => op.box_number === box.number)}
							{@const isPendingClose = boxOperation?.status === 'pending_close'}
							<button 
								class="box-item"
								class:special-box={box.number >= 10}
								class:disabled={userHasActiveOperation || isPendingClose}
								disabled={userHasActiveOperation || isPendingClose}
								on:click={() => openBoxModal(box)}
							>
								<span class="box-number">{getBoxDisplayName(box.number)}</span>
								{#if box.total > 0}
									<div class="box-amount">
										<img src={currencySymbolUrl} alt="SAR" class="currency-icon" />
										<span class="box-total">{box.total.toLocaleString('en-US', { minimumFractionDigits: 0, maximumFractionDigits: 2 })}</span>
									</div>
								{:else}
									<div class="box-empty-label">{$currentLocale === 'ar' ? 'فارغ' : 'Empty'}</div>
								{/if}
							</button>
						{/each}
					</div>
					{#if availableBoxes.filter(box => box.available && (box.total > 0 || box.number >= 10)).length === 0}
						<p class="no-data">{t('pos.noBoxesWithBalance') || 'No boxes with balance'}</p>
					{/if}
				{/if}
			</div>
		</div>
		<div class="blank-card">
			<div class="card-header">
				<h3>{$currentLocale === 'ar' ? 'صندوق العملية' : 'Operation Box'}</h3>
				<p class="branch-info">
					{#if $currentLocale === 'ar'}
						{fullBranch?.name_ar || branch?.name_ar || ''} - {fullBranch?.location_ar || ''}
					{:else}
						{fullBranch?.name_en || branch?.name_en || ''} - {fullBranch?.location_en || ''}
					{/if}
				</p>
			</div>
			<div class="card-content">
				{#if loading}
					<p class="loading">{t('common.loading') || 'Loading...'}</p>
				{:else if operationBoxes.length > 0}
					<div class="operation-boxes-list">
						{#each operationBoxes as opBox (opBox.id)}
							<div class="operation-box-item">
								<div class="operation-header">
									<span class="box-number">{getBoxDisplayName(opBox.box_number)}</span>
									<span class={`status-badge ${opBox.status === 'pending_close' ? 'pending' : 'active'}`}>
										{opBox.status === 'pending_close' ? ($currentLocale === 'ar' ? '⏳ انتظار الإغلاق' : '⏳ PENDING CLOSE') : ($currentLocale === 'ar' ? '🔴 قيد الاستخدام' : '🔴 IN USE')}
									</span>
									<span class={`match-badge ${opBox.is_matched ? 'matched' : 'unmatched'}`}>
										{opBox.is_matched ? (t('pos.matched') || 'MATCHED') : (t('pos.notMatched') || 'NOT MATCHED')}
									</span>
								</div>
								<div class="operation-details">
									<div class="detail-row">
										<span>{$currentLocale === 'ar' ? 'الكاشير:' : 'Cashier:'}</span>
										<span>{opBox.notes ? JSON.parse(opBox.notes).cashier_name || '' : ''}</span>
									</div>
									<div class="detail-row">
										<span>{$currentLocale === 'ar' ? 'المشرف:' : 'Supervisor:'}</span>
										<span>{opBox.notes ? JSON.parse(opBox.notes).supervisor_name || '' : ''}</span>
									</div>
									<div class="detail-row">
										<span>{$currentLocale === 'ar' ? 'وقت البداية:' : 'Start Time:'}</span>
										<span>{formatDateTime(opBox.start_time)}</span>
									</div>
									<div class="detail-row">
										<span>{$currentLocale === 'ar' ? 'الصادر:' : 'Issued:'}</span>
										<span>
											<img src={currencySymbolUrl} alt="SAR" class="currency-icon" />
											{(opBox.total_before || 0).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
										</span>
									</div>
									<div class="detail-row">
										<span>{$currentLocale === 'ar' ? 'المفحوص:' : 'Checked:'}</span>
										<span>
											<img src={currencySymbolUrl} alt="SAR" class="currency-icon" />
											{(opBox.total_after || 0).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
										</span>
									</div>
									{#if !opBox.is_matched && opBox.difference !== undefined}
										<div class="detail-row difference-row">
											<span>{$currentLocale === 'ar' ? 'الفرق:' : 'Difference:'}</span>
											<span>
												<img src={currencySymbolUrl} alt="SAR" class="currency-icon" />
												{Math.abs(opBox.difference || 0).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
											</span>
										</div>
									{/if}
									
									<!-- Closing Details when status is pending_close -->
									{#if opBox.status === 'pending_close' && opBox.closing_details}
										{@const closingData = typeof opBox.closing_details === 'string' ? JSON.parse(opBox.closing_details) : opBox.closing_details}
										<div class="closing-details-section">
											<div class="closing-details-title">{$currentLocale === 'ar' ? 'تفاصيل الإغلاق' : 'Closing Details'}</div>
											
											<!-- Card 7: Total Cash Sales & Total Bank Sales -->
											<div class="detail-row">
												<span>{$currentLocale === 'ar' ? 'إجمالي المبيعات النقدية:' : 'Total Cash Sales:'}</span>
												<span>
													<img src={currencySymbolUrl} alt="SAR" class="currency-icon" />
													{(closingData.total_cash_sales || 0).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
												</span>
											</div>
											<div class="detail-row">
												<span>{$currentLocale === 'ar' ? 'إجمالي المبيعات البنكية:' : 'Total Bank Sales:'}</span>
												<span>
													<img src={currencySymbolUrl} alt="SAR" class="currency-icon" />
													{(closingData.bank_total || 0).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
												</span>
											</div>
											
											<!-- Card 10: ERP Sales -->
											<div class="detail-row">
												<span>{$currentLocale === 'ar' ? 'مبيعات النظام النقدية:' : 'ERP Cash Sales:'}</span>
												<span>
													<img src={currencySymbolUrl} alt="SAR" class="currency-icon" />
													{(closingData.system_cash_sales || 0).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
												</span>
											</div>
											<div class="detail-row">
												<span>{$currentLocale === 'ar' ? 'مبيعات النظام بالبطاقة:' : 'ERP Card Sales:'}</span>
												<span>
													<img src={currencySymbolUrl} alt="SAR" class="currency-icon" />
													{(closingData.system_card_sales || 0).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
												</span>
											</div>
											<div class="detail-row">
												<span>{$currentLocale === 'ar' ? 'المرتجعات:' : 'Return:'}</span>
												<span>
													<img src={currencySymbolUrl} alt="SAR" class="currency-icon" />
													{(closingData.system_return || 0).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
												</span>
											</div>
											<div class="detail-row">
												<span>{$currentLocale === 'ar' ? 'إجمالي مبيعات النظام:' : 'ERP Total Sales:'}</span>
												<span>
													<img src={currencySymbolUrl} alt="SAR" class="currency-icon" />
													{(closingData.total_system_sales || 0).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
												</span>
											</div>
											
											<!-- Card 11: Recharge Card Sales -->
											<div class="detail-row">
												<span>{$currentLocale === 'ar' ? 'مبيعات بطاقات الشحن:' : 'Recharge Card Sales:'}</span>
												<span>
													<img src={currencySymbolUrl} alt="SAR" class="currency-icon" />
													{(closingData.recharge_sales || 0).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
												</span>
											</div>
											
											<!-- Card 12: Total Difference -->
											<div class="detail-row difference-highlight">
												<span>{$currentLocale === 'ar' ? 'إجمالي الفرق:' : 'Total Difference:'}</span>
												<span class={closingData.total_difference > 0 ? 'excess' : closingData.total_difference < 0 ? 'short' : 'match'}>
													<img src={currencySymbolUrl} alt="SAR" class="currency-icon" />
													{closingData.total_difference > 0 ? '+ ' : ''}{(closingData.total_difference || 0).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
													{closingData.total_difference > 0 ? ($currentLocale === 'ar' ? ' (زيادة)' : ' (Excess)') : closingData.total_difference < 0 ? ($currentLocale === 'ar' ? ' (نقص)' : ' (Short)') : ($currentLocale === 'ar' ? ' (متطابق)' : ' (Match)')}
												</span>
											</div>
										</div>
									{/if}
								</div>
								<div class="operation-actions">
									<button 
										class="btn-close-operation" 
										on:click={() => openCloseModal(opBox)}
									>
										{opBox.status === 'pending_close' ? ($currentLocale === 'ar' ? '✓ تم الإرسال' : '✓ Submitted') : ($currentLocale === 'ar' ? 'إغلاق' : 'Close')}
									</button>
								</div>
							</div>
						{/each}
					</div>
				{:else}
					<p class="no-data">{$currentLocale === 'ar' ? 'لا توجد عمليات نشطة' : 'No active operations'}</p>
				{/if}
			</div>
		</div>
	</div>
</div>

{#if showModal && selectedBox}
	<div class="modal-overlay" on:click={closeModal} on:keydown={handleModalKeydown}>
		<div class="modal-content" on:click|stopPropagation>
			<div class="modal-header">
				<h2>{getBoxDisplayName(selectedBox.number)} - {t('pos.counterCheck') || 'Counter Check'}</h2>
				<button class="close-btn" on:click={closeModal}>×</button>
			</div>

			<div class="modal-body">

				<div class="pos-number-section">
					<div class="access-code-group">
						<label>{t('pos.posNumber') || 'POS Number'}</label>
						<select bind:value={selectedPosNumber} class="pos-number-select">
							<option value={null} disabled selected>{$currentLocale === 'ar' ? 'اختر نقطة بيع' : 'Select POS'}</option>
							<option value={1}>POS 1</option>
							<option value={2}>POS 2</option>
							<option value={3}>POS 3</option>
							<option value={4}>POS 4</option>
							<option value={5}>POS 5</option>
							<option value={6}>POS 6</option>
							<option value={7}>POS 7</option>
							<option value={8}>POS 8</option>
							<option value={9}>POS 9</option>
						</select>
					</div>
				</div>

				<div class="section">
					<h3>{t('pos.enterRealCount') || 'Enter Real Count'}</h3>
					<div class="real-count-inputs">
						{#each Object.entries(denomLabels) as [key, label] (key)}
							<div class="input-group">
								<label>
									{#if label !== 'Coins'}
										<span>{label}</span>
										<img src={currencySymbolUrl} alt="SAR" class="currency-icon" />
									{:else}
										{label}
									{/if}
								</label>
								<div class="input-with-status">
									<input
										type="number"
										min="0"
										step="1"
										value={realCounts[key] || ''}
										on:input={(e) => {
											const val = e.currentTarget.value;
											realCounts[key] = val === '' ? undefined : Number(val);
										}}
									/>
									{#if realCounts[key] > 0 && selectedBox && isValidated}
										<div class="status-indicator">
											{#if checkDenominationMatch(key) === 'match'}
												<span class="status-icon match">✓</span>
											{:else if checkDenominationMatch(key) === 'mismatch'}
												<span class="status-icon mismatch">✗</span>
											{/if}
										</div>
									{/if}
								</div>
							</div>
						{/each}
					</div>
				</div>

				<div class={`total-match-status ${matchStatus || ''}`}>
					<div class="status-row">
						<span class="label">{t('pos.realTotal') || 'Real Total'}:</span>
						<div class="amount">
							<img src={currencySymbolUrl} alt="SAR" class="currency-icon" />
							<span>{displayTotal.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
						</div>
					</div>
					<div class="status-row">
						<span class="label">{t('pos.box') || 'Box'} {t('common.total') || 'Total'}:</span>
						<div class="amount">
							<img src={currencySymbolUrl} alt="SAR" class="currency-icon" />
							<span>{selectedBox.total.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
						</div>
					</div>
					{#if matchStatus === 'match'}
						<div class="match-indicator match">
							<span class="icon">✓</span>
							<span class="text">{t('pos.matched') || 'MATCHED'}</span>
						</div>
					{:else if matchStatus === 'mismatch'}
						<div class="match-indicator mismatch">
							<span class="icon">✗</span>
							<span class="text">{t('pos.notMatched') || 'NOT MATCHED'}</span>
							<div class="difference">
								{t('pos.difference') || 'Difference'}: 
								<img src={currencySymbolUrl} alt="SAR" class="currency-icon-small" />
									{Math.abs(selectedBox.total - calculateRealTotal()).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
								</div>
							</div>
						{/if}
				</div>

				<div class="access-codes-section">
					<div class="signature-header">
						{$currentLocale === 'ar' ? 'التوقيع الإلكتروني' : 'ELECTRONIC SIGNATURE'}
					</div>
					<div class="access-code-group">
						<label>{t('pos.cashierAccessCode') || 'Cashier Access Code'}</label>
						<div class="code-input-wrapper">
							<input
								type="password"
								placeholder={t('pos.enterCashierAccessCode') || 'Enter cashier access code'}
								bind:value={cashierAccessCode}
								on:blur={verifyCashierAccessCode}
							/>
							{#if cashierCodeValid && cashierName}
								<span class="verified-name">✓ {cashierName}</span>
							{/if}
						</div>
					</div>

					<div class="access-code-group">
						<label>{t('pos.supervisorAccessCode') || 'Supervisor Access Code'}</label>
						<div class="code-input-wrapper">
							<input
								type="password"
								placeholder={t('pos.enterSupervisorAccessCode') || 'Enter supervisor access code'}
								bind:value={supervisorAccessCode}
								on:blur={lookupSupervisorAccessCode}
							/>
							{#if supervisorName}
								<span class="verified-name">✓ {supervisorName}</span>
							{/if}
						</div>
					</div>
				</div>
			</div>

			<div class="modal-footer">
				<button class="btn-validate" on:click={validateAccessCodes} disabled={isValidated || !cashierCodeValid || !supervisorName}>
					{isValidated ? '✓ Validated' : 'Validate'}
				</button>
				<button class="btn-primary" on:click={startOperation} disabled={isStarting || !isValidated}>
					{isStarting ? (t('common.starting') || 'Starting...') : (t('common.start') || 'Start')}
				</button>
				<button class="btn-secondary" on:click={closeModal}>{t('common.close') || 'Close'}</button>
			</div>
		</div>
	</div>
{/if}

{#if errorMessage}
	<div class="error-overlay">
		<div class="error-popup">
			<div class="error-header">
				<span class="error-icon">⚠️</span>
				<h3>Error</h3>
			</div>
			<p class="error-text">{errorMessage}</p>
			<button class="btn-close-error" on:click={() => errorMessage = ''}>Close</button>
		</div>
	</div>
{/if}

{#if showChecklistPopup && pendingBox}
	<div class="modal-overlay" on:click={closeChecklistPopup} on:keydown={(e) => { if (e.key === 'Escape') closeChecklistPopup(); }}>
		<div class="checklist-popup" class:expanded={selectedChecklist} on:click|stopPropagation>
			<div class="checklist-popup-header">
				{#if selectedChecklist}
					<h3>{selectedChecklist.id} - {$currentLocale === 'ar' ? (selectedChecklist.checklist_name_ar || selectedChecklist.checklist_name_en) : (selectedChecklist.checklist_name_en || selectedChecklist.checklist_name_ar)}</h3>
				{:else}
					<h3>{$currentLocale === 'ar' ? 'قائمة التحقق' : 'Checklist'} - {getBoxDisplayName(pendingBox.number)}</h3>
				{/if}
				<button class="close-btn" on:click={closeChecklistPopup}>×</button>
			</div>
			<div class="checklist-popup-body">
				{#if !selectedChecklist}
					{#if loadingChecklists}
						<div class="checklist-loading">
							<svg class="spinner" viewBox="0 0 24 24"><circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" fill="none" opacity="0.25"></circle><path fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" opacity="0.75"></path></svg>
						</div>
					{:else if checklists.length === 0}
						<p class="no-checklists">{$currentLocale === 'ar' ? 'لا توجد قوائم تحقق' : 'No checklists available'}</p>
					{:else}
						<div class="checklist-list">
							{#each checklists as cl}
								<button class="checklist-item" on:click={() => selectChecklist(cl)}>
									<span class="checklist-code">{cl.id}</span>
									<span class="checklist-name">{$currentLocale === 'ar' ? (cl.checklist_name_ar || cl.checklist_name_en || '-') : (cl.checklist_name_en || cl.checklist_name_ar || '-')}</span>
								</button>
							{/each}
						</div>
					{/if}
				{:else}
					{#if loadingQuestions}
						<div class="checklist-loading">
							<svg class="spinner" viewBox="0 0 24 24"><circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" fill="none" opacity="0.25"></circle><path fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" opacity="0.75"></path></svg>
						</div>
					{:else if checklistQuestions.length === 0}
						<p class="no-checklists">{$currentLocale === 'ar' ? 'لا توجد أسئلة' : 'No questions in this checklist'}</p>
					{:else if currentQuestionIndex >= checklistQuestions.length}
						<div class="checklist-complete">
							<div class="complete-icon">✓</div>
							<p class="complete-text">{$currentLocale === 'ar' ? 'تم إكمال القائمة!' : 'Checklist Complete!'}</p>
							<button class="complete-btn" on:click={saveChecklistAndOpenModal}>
								{$currentLocale === 'ar' ? 'متابعة' : 'Continue'}
							</button>
						</div>
					{:else}
						{@const q = checklistQuestions[currentQuestionIndex]}
						<div class="question-progress">
							<span>{$currentLocale === 'ar' ? 'السؤال' : 'Question'} {currentQuestionIndex + 1} / {checklistQuestions.length}</span>
							<div class="progress-bar">
								<div class="progress-fill" style="width: {((currentQuestionIndex) / checklistQuestions.length) * 100}%"></div>
							</div>
						</div>
						<div class="questions-list">
							<div class="question-card">
								<div class="question-header">
									<span class="question-number">{q.id}</span>
									<span class="question-text">{$currentLocale === 'ar' ? (q.question_ar || q.question_en) : (q.question_en || q.question_ar)}</span>
								</div>
								<div class="answers-list">
									{#each getQuestionAnswers(q) as ans}
										<label class="answer-option" class:selected={selectedAnswers[q.id] === ans.key}>
											<input
												type="radio"
												name={`q-${q.id}`}
												value={ans.key}
												checked={selectedAnswers[q.id] === ans.key}
												on:change={() => { selectedAnswers[q.id] = ans.key; }}
											/>
											<span class="answer-text">{$currentLocale === 'ar' ? (ans.ar || ans.en) : (ans.en || ans.ar)}</span>
											{#if ans.points !== 0}
												<span class="answer-points" class:negative={ans.points < 0}>{ans.points > 0 ? '+' : ''}{ans.points}</span>
											{/if}
										</label>
									{/each}
									{#if q.has_other}
										<label class="answer-option other-option" class:selected={selectedAnswers[q.id] === 'other'}>
											<input
												type="radio"
												name={`q-${q.id}`}
												value="other"
												checked={selectedAnswers[q.id] === 'other'}
												on:change={() => { selectedAnswers[q.id] = 'other'; }}
											/>
											<span class="answer-text">{$currentLocale === 'ar' ? 'أخرى' : 'Other'}</span>
											{#if q.other_points !== 0}
												<span class="answer-points" class:negative={q.other_points < 0}>{q.other_points > 0 ? '+' : ''}{q.other_points}</span>
											{/if}
										</label>
										{#if selectedAnswers[q.id] === 'other'}
											<div class="other-input-wrapper">
												<input
													type="text"
													class="other-input"
													placeholder={$currentLocale === 'ar' ? 'أدخل إجابتك...' : 'Enter your answer...'}
													bind:value={otherValues[q.id]}
												/>
												<button class="next-btn" on:click={() => { if (currentQuestionIndex < checklistQuestions.length) currentQuestionIndex++; }}>
													{$currentLocale === 'ar' ? 'التالي' : 'Next'} →
												</button>
											</div>
										{/if}
									{/if}
								</div>
								{#if q.has_remarks}
									<div class="remarks-section">
										<label class="remarks-label">{$currentLocale === 'ar' ? 'ملاحظات:' : 'Remarks:'}</label>
										<textarea
											class="remarks-input"
											rows="2"
											placeholder={$currentLocale === 'ar' ? 'أدخل ملاحظاتك...' : 'Enter remarks...'}
											bind:value={remarksValues[q.id]}
										></textarea>
									</div>
								{/if}
								<div class="nav-btn-wrapper">
									{#if currentQuestionIndex > 0}
										<button 
											class="back-question-btn" 
											on:click={() => { currentQuestionIndex--; }}
										>
											← {$currentLocale === 'ar' ? 'السابق' : 'Back'}
										</button>
									{/if}
									<button 
										class="next-question-btn" 
										disabled={!selectedAnswers[q.id]}
										on:click={() => { if (currentQuestionIndex < checklistQuestions.length) currentQuestionIndex++; }}
									>
										{$currentLocale === 'ar' ? 'التالي' : 'Next'} →
									</button>
									<button 
										class="incident-btn" 
										on:click={openIncidentReport}
									>
										⚠️ {$currentLocale === 'ar' ? 'الإبلاغ عن مشكلة' : 'Report a Problem'}
									</button>
								</div>
							</div>
						</div>
					{/if}
				{/if}
			</div>
		</div>
	</div>
{/if}

<style>
	.checklist-popup {
		background: white;
		border-radius: 1rem;
		width: 400px;
		max-height: 80vh;
		box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
		overflow: hidden;
	}

	.checklist-popup-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 1rem 1.5rem;
		background: linear-gradient(135deg, #2563eb, #3b82f6);
		color: white;
	}

	.checklist-popup-header h3 {
		margin: 0;
		font-size: 1rem;
		font-weight: 700;
	}

	.checklist-popup-body {
		padding: 1rem 1.5rem;
		max-height: 60vh;
		overflow-y: auto;
	}

	.checklist-loading {
		display: flex;
		justify-content: center;
		padding: 2rem;
	}

	.checklist-loading .spinner {
		width: 2rem;
		height: 2rem;
		color: #3b82f6;
		animation: spin 1s linear infinite;
	}

	.no-checklists {
		text-align: center;
		color: #94a3b8;
		padding: 2rem;
		font-size: 0.875rem;
	}

	.checklist-list {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.checklist-item {
		display: flex;
		align-items: center;
		gap: 0.75rem;
		padding: 0.75rem 1rem;
		border: 2px solid #e2e8f0;
		border-radius: 0.75rem;
		background: #f8fafc;
		cursor: pointer;
		transition: all 0.2s;
		width: 100%;
		text-align: left;
	}

	.checklist-item:hover {
		border-color: #3b82f6;
		background: #eff6ff;
		transform: translateY(-1px);
		box-shadow: 0 4px 6px -1px rgba(59, 130, 246, 0.15);
	}

	.checklist-code {
		font-size: 0.875rem;
		font-weight: 800;
		color: #1e40af;
		background: #dbeafe;
		padding: 0.25rem 0.625rem;
		border-radius: 0.5rem;
		white-space: nowrap;
	}

	.checklist-name {
		font-size: 0.875rem;
		font-weight: 600;
		color: #334155;
	}

	.checklist-popup.expanded {
		width: 600px;
		max-width: 95%;
	}

	.questions-list {
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}

	.question-card {
		border: 2px solid #e2e8f0;
		border-radius: 0.75rem;
		padding: 1rem;
		background: #f8fafc;
	}

	.question-header {
		display: flex;
		align-items: flex-start;
		gap: 0.75rem;
		margin-bottom: 0.75rem;
	}

	.question-number {
		font-size: 0.75rem;
		font-weight: 800;
		color: #7c3aed;
		background: #ede9fe;
		padding: 0.25rem 0.5rem;
		border-radius: 0.375rem;
		white-space: nowrap;
	}

	.question-text {
		font-size: 0.9rem;
		font-weight: 600;
		color: #1e293b;
		line-height: 1.4;
	}

	.answers-list {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
		margin-left: 0.5rem;
	}

	.answer-option {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.5rem 0.75rem;
		border: 1px solid #e2e8f0;
		border-radius: 0.5rem;
		background: white;
		cursor: pointer;
		transition: all 0.2s;
	}

	.answer-option:hover {
		border-color: #3b82f6;
		background: #f0f9ff;
	}

	.answer-option.selected {
		border-color: #3b82f6;
		background: #dbeafe;
	}

	.answer-option input[type="radio"] {
		-webkit-appearance: none;
		-moz-appearance: none;
		appearance: none;
		width: 1rem;
		height: 1rem;
		border: 2px solid #cbd5e1;
		border-radius: 0.25rem;
		background: white;
		cursor: pointer;
		position: relative;
	}

	.answer-option input[type="radio"]:checked {
		background: #3b82f6;
		border-color: #3b82f6;
	}

	.answer-option input[type="radio"]:checked::after {
		content: '✓';
		position: absolute;
		top: 50%;
		left: 50%;
		transform: translate(-50%, -50%);
		color: white;
		font-size: 0.7rem;
		font-weight: bold;
	}

	.answer-text {
		flex: 1;
		font-size: 0.875rem;
		color: #334155;
	}

	.answer-points {
		font-size: 0.75rem;
		font-weight: 700;
		color: #059669;
		background: #d1fae5;
		padding: 0.125rem 0.375rem;
		border-radius: 0.25rem;
	}

	.answer-points.negative {
		color: #dc2626;
		background: #fee2e2;
	}

	.question-progress {
		margin-bottom: 1rem;
		text-align: center;
	}

	.question-progress span {
		font-size: 0.8rem;
		color: #64748b;
		font-weight: 600;
	}

	.progress-bar {
		height: 6px;
		background: #e2e8f0;
		border-radius: 3px;
		margin-top: 0.5rem;
		overflow: hidden;
	}

	.progress-fill {
		height: 100%;
		background: linear-gradient(90deg, #3b82f6, #2563eb);
		border-radius: 3px;
		transition: width 0.3s ease;
	}

	.checklist-complete {
		text-align: center;
		padding: 2rem;
	}

	.complete-icon {
		width: 4rem;
		height: 4rem;
		background: linear-gradient(135deg, #10b981, #059669);
		color: white;
		font-size: 2rem;
		border-radius: 50%;
		display: flex;
		align-items: center;
		justify-content: center;
		margin: 0 auto 1rem;
	}

	.complete-text {
		font-size: 1.1rem;
		font-weight: 700;
		color: #1e293b;
		margin-bottom: 1rem;
	}

	.complete-btn {
		background: linear-gradient(135deg, #3b82f6, #2563eb);
		color: white;
		border: none;
		padding: 0.75rem 2rem;
		border-radius: 0.5rem;
		font-weight: 600;
		cursor: pointer;
		transition: transform 0.2s, box-shadow 0.2s;
	}

	.complete-btn:hover {
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(59, 130, 246, 0.4);
	}

	.other-input-wrapper {
		display: flex;
		gap: 0.5rem;
		align-items: center;
		width: 100%;
		margin-top: 0.5rem;
	}

	.other-input-wrapper .other-input {
		flex: 1;
		margin-top: 0;
	}

	.next-btn {
		background: #3b82f6;
		color: white;
		border: none;
		padding: 0.5rem 1rem;
		border-radius: 0.375rem;
		font-weight: 600;
		font-size: 0.875rem;
		cursor: pointer;
		white-space: nowrap;
		transition: background 0.2s;
	}

	.next-btn:hover {
		background: #2563eb;
	}

	.nav-btn-wrapper {
		display: flex;
		justify-content: center;
		gap: 1rem;
		margin-top: 1rem;
		padding-top: 0.75rem;
		border-top: 1px solid #e2e8f0;
	}

	.back-question-btn {
		background: #6b7280;
		color: white;
		border: none;
		padding: 0.75rem 1.5rem;
		border-radius: 0.5rem;
		font-weight: 600;
		font-size: 1rem;
		cursor: pointer;
		transition: background 0.2s;
	}

	.back-question-btn:hover {
		background: #4b5563;
	}

	.next-question-btn {
		background: #3b82f6;
		color: white;
		border: none;
		padding: 0.75rem 2rem;
		border-radius: 0.5rem;
		font-weight: 600;
		font-size: 1rem;
		cursor: pointer;
		transition: background 0.2s, opacity 0.2s;
	}

	.next-question-btn:hover:not(:disabled) {
		background: #2563eb;
	}

	.next-question-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.incident-btn {
		background: #ef4444;
		color: white;
		border: none;
		padding: 0.75rem 1.5rem;
		border-radius: 0.5rem;
		font-weight: 600;
		font-size: 1rem;
		cursor: pointer;
		transition: background 0.2s;
	}

	.incident-btn:hover {
		background: #dc2626;
	}

	.other-option {
		flex-wrap: wrap;
	}

	.other-input {
		width: 100%;
		margin-top: 0.5rem;
		padding: 0.5rem;
		border: 1px solid #e2e8f0;
		border-radius: 0.375rem;
		font-size: 0.875rem;
	}

	.other-input:focus {
		outline: none;
		border-color: #3b82f6;
	}

	.remarks-section {
		margin-top: 0.75rem;
		padding-top: 0.75rem;
		border-top: 1px dashed #e2e8f0;
	}

	.remarks-label {
		display: block;
		font-size: 0.8rem;
		font-weight: 600;
		color: #64748b;
		margin-bottom: 0.375rem;
	}

	.remarks-input {
		width: 100%;
		padding: 0.5rem;
		border: 1px solid #e2e8f0;
		border-radius: 0.375rem;
		font-size: 0.875rem;
		resize: vertical;
		min-height: 2.5rem;
	}

	.remarks-input:focus {
		outline: none;
		border-color: #3b82f6;
	}

	.pos-container {
		width: 100%;
		height: 100%;
		padding: 1rem;
	}

	.cards-grid {
		display: grid;
		grid-template-columns: repeat(2, 1fr);
		gap: 1rem;
	}

	.blank-card {
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 0.5rem;
		min-height: 200px;
		display: flex;
		flex-direction: column;
		overflow: hidden;
	}

	.card-header {
		padding: 1rem;
		border-bottom: 1px solid #e5e7eb;
		background: #f9fafb;
	}

	.card-header h3 {
		margin: 0;
		font-size: 1rem;
		font-weight: 600;
		color: #1f2937;
	}

	.branch-info {
		margin: 0.25rem 0 0 0;
		font-size: 0.75rem;
		color: #6b7280;
	}

	.card-content {
		padding: 1rem;
		flex: 1;
		overflow-y: auto;
	}

	.boxes-grid {
		display: grid;
		grid-template-columns: repeat(3, 1fr);
		gap: 0.75rem;
	}

	.box-item {
		background: #f3f4f6;
		border: 1px solid #d1d5db;
		border-radius: 0.375rem;
		padding: 0.75rem;
		text-align: center;
		cursor: pointer;
		transition: all 0.2s;
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
		align-items: center;
		font-family: inherit;
		font-size: inherit;
	}

	.box-item.special-box {
		background: linear-gradient(135deg, #fecaca 0%, #fca5a5 100%);
		border: 2px solid #f87171;
		box-shadow: 0 4px 6px -1px rgba(239, 68, 68, 0.2);
	}

	.box-item:hover {
		background: #e5e7eb;
		border-color: #9ca3af;
		transform: translateY(-2px);
	}

	.box-item.special-box:hover {
		background: linear-gradient(135deg, #f87171 0%, #f05252 100%);
		border-color: #dc2626;
		box-shadow: 0 10px 15px -3px rgba(239, 68, 68, 0.3);
		transform: translateY(-2px);
	}

	.box-item.disabled,
	.box-item:disabled {
		opacity: 0.4;
		cursor: not-allowed;
		pointer-events: none;
	}

	.box-item.disabled:hover,
	.box-item:disabled:hover {
		background: #f3f4f6;
		border-color: #d1d5db;
		transform: none;
	}

	.warning-message {
		background: #fef3c7;
		border: 1px solid #fbbf24;
		color: #92400e;
		padding: 0.75rem;
		border-radius: 0.375rem;
		text-align: center;
		font-size: 0.875rem;
		font-weight: 500;
		margin-bottom: 1rem;
	}

	.box-number {
		font-weight: 600;
		color: #374151;
		font-size: 0.875rem;
	}

	.box-total {
		font-size: 0.75rem;
		color: #059669;
		font-weight: 600;
	}

	.box-empty-label {
		font-size: 0.75rem;
		color: #9ca3af;
		font-weight: 600;
	}

	.box-amount {
		display: flex;
		align-items: center;
		gap: 0.25rem;
		justify-content: center;
	}

	.currency-icon {
		width: 0.5rem;
		height: 0.5rem;
		object-fit: contain;
	}

	.currency-icon-small {
		width: 0.375rem;
		height: 0.375rem;
		object-fit: contain;
		display: inline-block;
		margin: 0 0.25rem;
	}

	.total-amount {
		display: flex;
		align-items: center;
		gap: 0.5rem;
	}

	.loading,
	.no-data {
		text-align: center;
		color: #9ca3af;
		font-size: 0.875rem;
		padding: 2rem 0;
	}

	/* Operation Box Styles */
	.operation-boxes-list {
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
	}

	.operation-box-item {
		background: #f9fafb;
		border: 1px solid #e5e7eb;
		border-radius: 0.375rem;
		padding: 0.75rem;
	}

	.operation-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 0.5rem;
		padding-bottom: 0.5rem;
		border-bottom: 1px solid #e5e7eb;
	}

	.match-badge {
		font-size: 0.65rem;
		font-weight: 600;
		padding: 0.25rem 0.5rem;
		border-radius: 0.25rem;
		text-transform: uppercase;
	}

	.match-badge.matched {
		background: #dcfce7;
		color: #166534;
	}

	.match-badge.unmatched {
		background: #fee2e2;
		color: #991b1b;
	}

	.status-badge {
		font-size: 0.65rem;
		font-weight: 600;
		padding: 0.25rem 0.5rem;
		border-radius: 0.25rem;
	}

	.status-badge.active {
		background: #fee2e2;
		color: #991b1b;
	}

	.status-badge.pending {
		background: #fef3c7;
		color: #92400e;
	}

	.operation-details {
		display: flex;
		flex-direction: column;
		gap: 0.375rem;
	}

	.detail-row {
		display: flex;
		justify-content: space-between;
		align-items: center;
		font-size: 0.8125rem;
	}

	.detail-row span:first-child {
		color: #6b7280;
		font-weight: 500;
	}

	.detail-row span:last-child {
		color: #1f2937;
		font-weight: 600;
		display: flex;
		align-items: center;
		gap: 0.25rem;
	}

	.difference-row {
		color: #dc2626;
		font-weight: 600;
	}

	/* Closing Details Section */
	.closing-details-section {
		margin-top: 0.75rem;
		padding-top: 0.75rem;
		border-top: 2px solid #10b981;
		border-left: 3px solid #10b981;
		padding-left: 0.75rem;
	}

	.closing-details-title {
		font-size: 0.75rem;
		font-weight: 700;
		color: #065f46;
		text-transform: uppercase;
		margin-bottom: 0.5rem;
		letter-spacing: 0.5px;
	}

	.closing-details-section .detail-row {
		font-size: 0.75rem;
		gap: 0.5rem;
	}

	.difference-highlight {
		padding: 0.4rem;
		background: linear-gradient(135deg, #f0fdf4 0%, #dcfce7 100%);
		border-radius: 0.375rem;
		border-left: 3px solid #10b981;
		margin-top: 0.5rem;
		font-weight: 700;
	}

	.difference-highlight .excess {
		color: #92400e;
	}

	.difference-highlight .short {
		color: #dc2626;
	}

	.difference-highlight .match {
		color: #065f46;
	}

	.operation-actions {
		margin-top: 0.75rem;
		padding-top: 0.75rem;
		border-top: 1px solid #e5e7eb;
		display: flex;
		justify-content: flex-end;
	}

	.btn-close-operation {
		padding: 0.5rem 1rem;
		background: #ef4444;
		color: white;
		border: none;
		border-radius: 0.375rem;
		font-size: 0.8125rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
	}

	.btn-close-operation:hover:not(:disabled) {
		background: #dc2626;
	}

	.btn-close-operation:disabled {
		background: #22c55e;
		cursor: not-allowed;
		opacity: 0.9;
	}

	.total-display {
		padding: 1rem;
		background: #f0f9ff;
		border-radius: 0.375rem;
		border: 1px solid #bae6fd;
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
		background: linear-gradient(135deg, #ffffff 0%, #f0fdf4 100%);
		border-radius: 1rem;
		width: 90%;
		max-width: 600px;
		max-height: 90vh;
		display: flex;
		flex-direction: column;
		box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25), 0 0 0 1px rgba(34, 197, 94, 0.1);
		border: 2px solid rgba(34, 197, 94, 0.2);
	}

	.modal-header {
		padding: 0.75rem 1rem;
		border-bottom: none;
		display: flex;
		justify-content: space-between;
		align-items: center;
		background: linear-gradient(135deg, #22c55e 0%, #16a34a 100%);
		border-radius: 0.875rem 0.875rem 0 0;
		box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
	}

	.modal-header h2 {
		margin: 0;
		font-size: 0.95rem;
		font-weight: 700;
		color: white;
		text-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
	}

	.close-btn {
		background: rgba(255, 255, 255, 0.2);
		border: none;
		font-size: 1.25rem;
		cursor: pointer;
		color: white;
		padding: 0;
		width: 1.5rem;
		height: 1.5rem;
		display: flex;
		align-items: center;
		justify-content: center;
		border-radius: 0.25rem;
		transition: all 0.2s;
	}

	.close-btn:hover {
		background: rgba(255, 255, 255, 0.3);
		transform: scale(1.1);
	}

	.modal-body {
		padding: 0.75rem;
		flex: 1;
		overflow-y: auto;
	}

	.section {
		margin-bottom: 1rem;
	}

	.section h3 {
		margin: 1rem 0 0.5rem 0;
		font-size: 0.8rem;
		font-weight: 700;
		color: #166534;
		text-transform: uppercase;
		letter-spacing: 0.5px;
		text-shadow: 0 1px 2px rgba(34, 197, 94, 0.1);
	}

	.denomination-display {
		background: #f9fafb;
		border: 1px solid #e5e7eb;
		border-radius: 0.375rem;
		overflow: hidden;
	}

	.denom-row,
	.denom-total {
		display: flex;
		justify-content: space-between;
		padding: 0.3rem 0.75rem;
		border-bottom: 1px solid #e5e7eb;
		font-size: 0.75rem;
	}

	.denom-row:last-child {
		border-bottom: none;
	}

	.denom-total {
		background: #f3f4f6;
		font-weight: 600;
		border-bottom: none;
	}

	.denom-label {
		color: #6b7280;
	}

	.denom-count {
		color: #1f2937;
		font-weight: 500;
	}

	.real-count-inputs {
		display: grid;
		grid-template-columns: repeat(2, 1fr);
		gap: 0.5rem;
		margin-bottom: 0.5rem;
		padding: 0.75rem;
		background: linear-gradient(135deg, #f0fdf4 0%, #dcfce7 100%);
		border-radius: 0.5rem;
		border: 2px solid #86efac;
		box-shadow: 0 4px 6px -1px rgba(34, 197, 94, 0.1), inset 0 2px 4px 0 rgba(255, 255, 255, 0.6);
	}

	.input-group {
		display: flex;
		flex-direction: column;
		gap: 0.125rem;
	}

	.input-group label {
		font-size: 0.625rem;
		font-weight: 700;
		color: #ea580c;
		display: flex;
		align-items: center;
		gap: 0.25rem;
		text-shadow: 0 1px 2px rgba(249, 115, 22, 0.1);
	}

	.input-with-status {
		display: flex;
		gap: 0.5rem;
		align-items: center;
	}

	.input-group input {
		padding: 0.3rem 0.4rem;
		border: 2px solid #d1fae5;
		border-radius: 0.5rem;
		font-size: 0.75rem;
		flex: 1;
		background: white;
		font-weight: 600;
		color: #166534;
		box-shadow: inset 0 2px 4px rgba(0, 0, 0, 0.06), 0 1px 2px rgba(34, 197, 94, 0.1);
		transition: all 0.2s;
	}

	.input-group input:focus {
		outline: none;
		border-color: #22c55e;
		box-shadow: 0 0 0 3px rgba(34, 197, 94, 0.2), 0 4px 6px rgba(34, 197, 94, 0.15);
		transform: translateY(-1px);
	}

	.status-indicator {
		width: 1.25rem;
		height: 1.25rem;
		display: flex;
		align-items: center;
		justify-content: center;
		border-radius: 0.5rem;
		font-weight: 700;
		font-size: 0.75rem;
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
	}

	.status-icon {
		display: block;
	}

	.status-icon.match {
		color: #059669;
	}

	.status-icon.mismatch {
		color: #dc2626;
	}

	.real-total {
		background: linear-gradient(135deg, #dbeafe 0%, #bfdbfe 100%);
		padding: 0.5rem 0.75rem;
		border-radius: 0.5rem;
		display: flex;
		justify-content: space-between;
		align-items: center;
		font-weight: 700;
		color: #1e40af;
		margin-bottom: 0.5rem;
		font-size: 0.8rem;
		border: 2px solid #93c5fd;
		box-shadow: 0 4px 6px -1px rgba(59, 130, 246, 0.2), inset 0 2px 4px 0 rgba(255, 255, 255, 0.6);
	}

	.match-status {
		padding: 0.75rem;
		border-radius: 0.75rem;
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
		align-items: center;
		text-align: center;
		font-weight: 700;
		margin-bottom: 0.5rem;
		box-shadow: 0 6px 12px rgba(0, 0, 0, 0.15), inset 0 2px 4px rgba(255, 255, 255, 0.5);
		transform: translateZ(0);
	}

	.match-status.match {
		background: linear-gradient(135deg, #dcfce7 0%, #bbf7d0 100%);
		color: #166534;
		border: 3px solid #22c55e;
		text-shadow: 0 1px 2px rgba(34, 197, 94, 0.2);
	}

	.match-status.mismatch {
		background: linear-gradient(135deg, #fee2e2 0%, #fecaca 100%);
		color: #991b1b;
		border: 3px solid #f97316;
		text-shadow: 0 1px 2px rgba(249, 115, 22, 0.2);
	}

	.match-icon {
		font-size: 1.5rem;
	}

	.match-text {
		font-size: 1rem;
	}

	.difference {
		font-size: 0.875rem;
		font-weight: 500;
		margin-top: 0.5rem;
	}

	.total-match-status {
		padding: 0.5rem 1rem;
		border-top: 1px solid #e5e7eb;
		margin-bottom: 0.25rem;
	}

	.status-row {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 0.5rem;
		font-size: 0.875rem;
	}

	.access-codes-section {
		display: grid;
		grid-template-columns: repeat(2, 1fr);
		gap: 0.5rem;
		padding: 0.75rem;
		background: linear-gradient(135deg, #fff7ed 0%, #ffedd5 100%);
		border-radius: 0.5rem;
		margin-top: 0.125rem;
		border: 2px solid #fed7aa;
		box-shadow: 0 4px 6px -1px rgba(249, 115, 22, 0.1), inset 0 2px 4px 0 rgba(255, 255, 255, 0.6);
	}

	.signature-header {
		grid-column: 1 / -1;
		font-size: 0.75rem;
		font-weight: 700;
		color: #15803d;
		letter-spacing: 1px;
		padding-bottom: 0.5rem;
		margin-bottom: 0.25rem;
		border-bottom: 1px solid #fed7aa;
	}

	.access-code-group {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}

	.access-code-group label {
		font-size: 0.75rem;
		font-weight: 700;
		color: #ea580c;
		letter-spacing: 0.5px;
	}

	.pos-number-select {
		padding: 0.3rem 0.4rem;
		border: 2px solid #22c55e;
		border-radius: 0.5rem;
		font-size: 0.75rem;
		background: linear-gradient(to bottom, #ffffff, #f0fdf4);
		cursor: pointer;
		font-weight: 700;
		color: #166534;
		box-shadow: 0 2px 4px rgba(34, 197, 94, 0.2), inset 0 1px 0 rgba(255, 255, 255, 0.5);
		transition: all 0.2s;
	}

	.pos-number-select:focus {
		outline: none;
		border-color: #16a34a;
		box-shadow: 0 0 0 3px rgba(34, 197, 94, 0.2), 0 4px 6px rgba(34, 197, 94, 0.3);
		transform: translateY(-1px);
	}

	.pos-number-select:hover {
		border-color: #16a34a;
		transform: translateY(-1px);
		box-shadow: 0 4px 6px rgba(34, 197, 94, 0.3);
	}

	.code-input-wrapper {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}

	.code-input-wrapper input {
		padding: 0.3rem 0.4rem;
		border: 2px solid #fed7aa;
		border-radius: 0.5rem;
		font-size: 0.75rem;
		background: white;
		box-shadow: inset 0 2px 4px rgba(0, 0, 0, 0.06), 0 1px 2px rgba(249, 115, 22, 0.1);
		transition: all 0.2s;
	}

	.code-input-wrapper input:focus {
		outline: none;
		border-color: #f97316;
		box-shadow: 0 0 0 3px rgba(249, 115, 22, 0.2), 0 4px 6px rgba(249, 115, 22, 0.15);
		transform: translateY(-1px);
	}

	.verified-name {
		font-size: 0.625rem;
		color: #16a34a;
		font-weight: 700;
		margin-top: 0.125rem;
		text-shadow: 0 1px 2px rgba(34, 197, 94, 0.2);
	}

	.status-row .label {
		color: #6b7280;
		font-weight: 500;
	}

	.status-row .amount {
		display: flex;
		align-items: center;
		gap: 0.25rem;
		color: #1f2937;
		font-weight: 600;
	}

	.match-indicator {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.75rem;
		border-radius: 0.375rem;
		text-align: center;
		justify-content: center;
		margin-top: 0.75rem;
		flex-direction: column;
		font-weight: 600;
	}

	.match-indicator.match {
		background: #dcfce7;
		color: #166534;
		border: 1px solid #86efac;
	}

	.match-indicator.mismatch {
		background: #fee2e2;
		color: #991b1b;
		border: 1px solid #fca5a5;
	}

	.match-indicator .icon {
		font-size: 1.25rem;
	}

	.match-indicator .text {
		font-size: 0.875rem;
	}

	.modal-footer {
		padding: 1.5rem;
		border-top: 1px solid #e5e7eb;
		display: flex;
		gap: 0.75rem;
		justify-content: flex-end;
		background: #f9fafb;
	}

	.btn-primary,
	.btn-secondary,
	.btn-validate {
		padding: 0.5rem 1.5rem;
		border-radius: 0.375rem;
		border: none;
		font-size: 0.875rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
	}

	.btn-validate {
		background: linear-gradient(135deg, #10b981 0%, #059669 100%);
		color: white;
		box-shadow: 0 2px 4px rgba(16, 185, 129, 0.2);
	}

	.btn-validate:hover:not(:disabled) {
		background: linear-gradient(135deg, #059669 0%, #047857 100%);
		box-shadow: 0 4px 8px rgba(16, 185, 129, 0.3);
	}

	.btn-validate:disabled {
		background: #10b981;
		cursor: not-allowed;
		opacity: 0.7;
	}

	.btn-primary {
		background: #3b82f6;
		color: white;
	}

	.btn-primary:hover {
		background: #2563eb;
	}

	.btn-primary:disabled {
		background: #9ca3af;
		cursor: not-allowed;
		opacity: 0.6;
	}

	.btn-secondary {
		background: #e5e7eb;
		color: #374151;
	}

	.btn-secondary:hover {
		background: #d1d5db;
	}

	.error-overlay {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.5);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 10000;
	}

	.error-popup {
		background: white;
		border-radius: 0.5rem;
		padding: 1.5rem;
		max-width: 400px;
		width: 90%;
		box-shadow: 0 10px 25px rgba(0, 0, 0, 0.2);
		animation: slideIn 0.2s ease-out;
	}

	@keyframes slideIn {
		from {
			transform: translateY(-20px);
			opacity: 0;
		}
		to {
			transform: translateY(0);
			opacity: 1;
		}
	}

	.error-header {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		margin-bottom: 1rem;
	}

	.error-icon {
		font-size: 1.5rem;
	}

	.error-header h3 {
		margin: 0;
		color: #dc2626;
		font-size: 1.25rem;
	}

	.error-text {
		margin: 0 0 1.5rem 0;
		color: #374151;
		line-height: 1.5;
	}

	.btn-close-error {
		width: 100%;
		padding: 0.625rem 1rem;
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 0.375rem;
		font-size: 0.875rem;
		font-weight: 600;
		cursor: pointer;
		transition: background 0.2s;
	}

	.btn-close-error:hover {
		background: #2563eb;
	}
</style>
