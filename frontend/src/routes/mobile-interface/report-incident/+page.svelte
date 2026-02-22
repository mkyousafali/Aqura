<script lang="ts">
	import { onMount } from 'svelte';
	import { page } from '$app/stores';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { get } from 'svelte/store';
	import { supabase } from '$lib/utils/supabase';
	import { _ as t, currentLocale } from '$lib/i18n';

	// Accept optional preset from parent (desktop popup) or query param (mobile nav)
	export let presetTypeId: string = '';
	export let presetCustomerName: string = '';
	export let presetCustomerPhone: string = '';
	
	interface IncidentType {
		id: string;
		incident_type_en: string;
		incident_type_ar: string;
	}
	
	interface Branch {
		id: string;
		name_en: string;
		name_ar: string;
		location_en: string;
		location_ar: string;
	}
	
	interface Violation {
		id: string;
		name_en: string;
		name_ar: string;
	}
	
	interface Employee {
		id: string;
		name_en: string;
		name_ar: string;
		id_number?: string;
	}

	let loading = false;
	let saving = false;
	let incidentTypes: IncidentType[] = [];
	let branches: Branch[] = [];
	let violations: Violation[] = [];
	let employees: Employee[] = [];
	
	// Form state
	let selectedIncidentType: IncidentType | null = null;
	let selectedBranch: Branch | null = null;
	let selectedViolation: Violation | null = null;
	let selectedEmployee: Employee | null = null;
	let whatHappened = '';
	let proofWitness = '';
	let customerName = '';
	let customerContact = '';
	let relatedPartyDetails = '';
	
	// User info
	let userEmployeeId: string | null = null;
	let userEmployeeName = '';
	let userEmployeeNameAr = '';
	
	// Dropdown states
	let showIncidentTypeDropdown = false;
	let showBranchDropdown = false;
	let showViolationDropdown = false;
	let showEmployeeDropdown = false;
	
	// Search queries
	let incidentTypeSearch = '';
	let branchSearch = '';
	let violationSearch = '';
	let employeeSearch = '';
	
	// Modal states
	let showAlertModal = false;
	let showSuccessModal = false;
	let alertMessage = '';
	let alertTitle = '';
	let errorMessage = '';
	let successMessage = '';
	
	// Attachment handling
	let attachments: File[] = [];
	let attachmentPreviews: { file: File; url: string; type: string }[] = [];
	let isUploadingAttachments = false;
	
	// Check if selected incident type is employee incident (IN2)
	$: isEmployeeIncident = selectedIncidentType?.id === 'IN2';
	$: isCustomerIncident = selectedIncidentType?.id === 'IN1' || selectedIncidentType?.id === 'IN9';
	
	// Filter lists based on search
	$: filteredIncidentTypes = incidentTypes.filter(it => {
		if (!incidentTypeSearch.trim()) return true;
		const query = incidentTypeSearch.toLowerCase();
		return (it.incident_type_en?.toLowerCase().includes(query) || it.incident_type_ar?.includes(query) || it.id?.toLowerCase().includes(query));
	}).sort((a, b) => {
		// Customer-related types (IN1, IN9) at the top - same as desktop
		const customerTypes = ['IN1', 'IN9'];
		const aIsCustomer = customerTypes.includes(a.id);
		const bIsCustomer = customerTypes.includes(b.id);
		if (aIsCustomer && !bIsCustomer) return -1;
		if (!aIsCustomer && bIsCustomer) return 1;
		return a.id.localeCompare(b.id);
	});
	
	$: filteredBranches = branches.filter(b => {
		if (!branchSearch.trim()) return true;
		const query = branchSearch.toLowerCase();
		return (b.name_en?.toLowerCase().includes(query) || b.name_ar?.includes(query) || b.location_en?.toLowerCase().includes(query) || b.location_ar?.includes(query));
	});
	
	$: filteredViolations = violations.filter(v => {
		if (!violationSearch.trim()) return true;
		const query = violationSearch.toLowerCase();
		return (v.name_en?.toLowerCase().includes(query) || v.name_ar?.includes(query));
	});
	
	$: filteredEmployees = employees.filter(e => {
		if (!employeeSearch.trim()) return true;
		const query = employeeSearch.toLowerCase();
		return (e.name_en?.toLowerCase().includes(query) || e.name_ar?.includes(query) || e.id?.toLowerCase().includes(query));
	});

	onMount(async () => {
		loading = true;
		
		// Load current user's employee ID
		const currentUserData = get(currentUser);
		if (currentUserData?.id) {
			try {
				const { data: employee, error } = await supabase
					.from('hr_employee_master')
					.select('id, name_en, name_ar')
					.eq('user_id', currentUserData.id)
					.single();

				if (!error && employee) {
					userEmployeeId = employee.id;
					userEmployeeName = employee.name_en || employee.id;
					userEmployeeNameAr = employee.name_ar || employee.name_en || employee.id;
				}
			} catch (err) {
				console.error('Error loading employee:', err);
			}
		}
		
		// Load all data in parallel
		await Promise.all([
			loadIncidentTypes(),
			loadBranches(),
			loadViolations(),
			loadEmployees()
		]);

		// Auto-select incident type from prop or query param
		const typeToSelect = presetTypeId || $page.url.searchParams.get('type') || '';
		if (typeToSelect && incidentTypes.length > 0) {
			const match = incidentTypes.find(it => it.id === typeToSelect);
			if (match) selectedIncidentType = match;
		}

		// Auto-fill customer name and contact from props or query params
		const nameToFill = presetCustomerName || $page.url.searchParams.get('name') || '';
		const phoneToFill = presetCustomerPhone || $page.url.searchParams.get('phone') || '';
		if (nameToFill) customerName = nameToFill;
		if (phoneToFill) customerContact = phoneToFill;
		
		loading = false;
	});

	async function loadIncidentTypes() {
		try {
			const { data, error } = await supabase
				.from('incident_types')
				.select('*')
				.eq('is_active', true)
				.order('id');
			
			if (!error && data) {
				// Sort to put customer-related types at top
				const customerTypes = data.filter(t => t.id === 'IN1' || t.id === 'IN9');
				const otherTypes = data.filter(t => t.id !== 'IN1' && t.id !== 'IN9');
				incidentTypes = [...customerTypes, ...otherTypes];
			}
		} catch (err) {
			console.error('Error loading incident types:', err);
		}
	}

	async function loadBranches() {
		try {
			const { data, error } = await supabase
				.from('branches')
				.select('id, name_en, name_ar, location_en, location_ar')
				.eq('is_active', true)
				.order('name_en');
			
			if (!error && data) {
				branches = data;
			}
		} catch (err) {
			console.error('Error loading branches:', err);
		}
	}

	async function loadViolations() {
		try {
			const { data, error } = await supabase
				.from('warning_violation')
				.select('id, name_en, name_ar')
				.order('name_en');
			
			if (!error && data) {
				violations = data;
			}
		} catch (err) {
			console.error('Error loading violations:', err);
		}
	}

	async function loadEmployees() {
		try {
			console.log('Loading employees...');
			const { data, error } = await supabase
				.from('hr_employee_master')
				.select('id, name_en, name_ar, id_number')
				.order('name_en');
			
			if (error) {
				console.error('Error loading employees:', error);
				return;
			}
			
			employees = data || [];
			console.log('Loaded employees:', employees.length, employees);
		} catch (err) {
			console.error('Error loading employees:', err);
		}
	}

	function showAlert(title: string, message: string) {
		alertTitle = title;
		alertMessage = message;
		showAlertModal = true;
	}

	function closeAlert() {
		showAlertModal = false;
	}

	function closeSuccessModal() {
		showSuccessModal = false;
		successMessage = '';
	}
	
	function handleAttachmentSelect(event: Event) {
		const input = event.target as HTMLInputElement;
		const files = input.files;
		if (!files) return;
		
		for (let i = 0; i < files.length; i++) {
			const file = files[i];
			if (attachments.length >= 5) break; // Max 5 attachments
			
			// Validate file size (max 10MB per file) - same as desktop
			if (file.size > 10 * 1024 * 1024) {
				showAlert(
					$currentLocale === 'ar' ? 'حجم الملف كبير جداً' : 'File Too Large',
					$currentLocale === 'ar' ? `حجم الملف "${file.name}" أكبر من 10 ميجابايت` : `File "${file.name}" exceeds 10MB`
				);
				continue;
			}
			
			attachments = [...attachments, file];
			
			// Create preview
			const url = URL.createObjectURL(file);
			const type = file.type.startsWith('image/') ? 'image' : 'file';
			attachmentPreviews = [...attachmentPreviews, { file, url, type }];
		}
		
		// Reset input
		input.value = '';
	}
	
	function removeAttachment(index: number) {
		URL.revokeObjectURL(attachmentPreviews[index].url);
		attachments = attachments.filter((_, i) => i !== index);
		attachmentPreviews = attachmentPreviews.filter((_, i) => i !== index);
	}

	async function submitIncident() {
		errorMessage = '';
		
		// Validation
		if (!selectedIncidentType) {
			showAlert($currentLocale === 'ar' ? 'حقول مطلوبة' : 'Required Fields', $currentLocale === 'ar' ? 'الرجاء اختيار نوع الحادثة' : 'Please select incident type');
			return;
		}
		
		if (!selectedBranch) {
			showAlert($currentLocale === 'ar' ? 'حقول مطلوبة' : 'Required Fields', $currentLocale === 'ar' ? 'الرجاء اختيار الفرع' : 'Please select branch');
			return;
		}
		
		if (!whatHappened.trim()) {
			showAlert($currentLocale === 'ar' ? 'حقول مطلوبة' : 'Required Fields', $currentLocale === 'ar' ? 'الرجاء وصف ما حدث' : 'Please describe what happened');
			return;
		}
		
		if (isEmployeeIncident) {
			if (!selectedViolation) {
				showAlert($currentLocale === 'ar' ? 'حقول مطلوبة' : 'Required Fields', $currentLocale === 'ar' ? 'الرجاء اختيار المخالفة' : 'Please select violation');
				return;
			}
			if (!selectedEmployee) {
				showAlert($currentLocale === 'ar' ? 'حقول مطلوبة' : 'Required Fields', $currentLocale === 'ar' ? 'الرجاء اختيار الموظف' : 'Please select employee');
				return;
			}
		}
		
		if (isCustomerIncident) {
			if (!customerName.trim() || !customerContact.trim()) {
				showAlert($currentLocale === 'ar' ? 'حقول مطلوبة' : 'Required Fields', $currentLocale === 'ar' ? 'يرجى إدخال اسم العميل ورقم الاتصال' : 'Please enter customer name and contact number');
				return;
			}
		}
		
		saving = true;
		
		try {
			const currentUserData = get(currentUser);
			if (!currentUserData?.id) {
				throw new Error('Not logged in');
			}
			
			// Get the next incident ID (fetch all to compute max numerically, avoiding lexicographic sort issues)
			const { data: allIncidents } = await supabase
				.from('incidents')
				.select('id');
			
			let nextIncidentNum = 1;
			if (allIncidents && allIncidents.length > 0) {
				const nums = allIncidents
					.map((i: any) => parseInt(i.id.replace('INS', '')))
					.filter((n: number) => !isNaN(n));
				if (nums.length > 0) {
					nextIncidentNum = Math.max(...nums) + 1;
				}
			}
			const incidentId = `INS${nextIncidentNum}`;
			
			// Upload attachments if any (same format as desktop)
			let uploadedAttachments: any[] = [];
			if (attachments.length > 0) {
				isUploadingAttachments = true;
				for (const file of attachments) {
					try {
						const fileName = `incident-${Date.now()}-${Math.random().toString(36).substr(2, 9)}.${file.name.split('.').pop()}`;
						const { data: uploadData, error: uploadError } = await supabase.storage
							.from('documents')
							.upload(`incidents/${fileName}`, file);
						
						if (uploadError) {
							console.warn(`Failed to upload ${file.name}:`, uploadError.message);
							continue;
						}
						
						// Get the public URL
						const { data: { publicUrl } } = supabase.storage
							.from('documents')
							.getPublicUrl(`incidents/${fileName}`);
						
						uploadedAttachments.push({
							url: publicUrl,
							name: file.name,
							type: file.type.startsWith('image/') ? 'image' : (file.type.includes('pdf') ? 'pdf' : 'file'),
							size: file.size,
							uploaded_at: new Date().toISOString()
						});
					} catch (uploadErr) {
						console.error('Upload error:', uploadErr);
					}
				}
				isUploadingAttachments = false;
			}
			
			// Get permission column based on incident type
			const incidentTypeToPermission: Record<string, string> = {
				'IN1': 'can_receive_customer_incidents',
				'IN2': 'can_receive_employee_incidents',
				'IN3': 'can_receive_maintenance_incidents',
				'IN4': 'can_receive_vendor_incidents',
				'IN5': 'can_receive_vehicle_incidents',
				'IN6': 'can_receive_government_incidents',
				'IN7': 'can_receive_other_incidents',
				'IN8': 'can_receive_finance_incidents',
				'IN9': 'can_receive_pos_incidents'
			};
			
			const permissionColumn = incidentTypeToPermission[selectedIncidentType.id] || 'can_receive_other_incidents';
			
			// Fetch users who can receive this incident type
			const { data: permissions, error: permError } = await supabase
				.from('approval_permissions')
				.select('user_id')
				.eq(permissionColumn, true)
				.eq('is_active', true);
			
			if (permError) throw permError;
			
			const recipientUserIds = permissions?.map(p => p.user_id) || [];
			
			// Fetch default incident users for this type (get tasks + notifications regardless of branch)
			const { data: defaultIncidentData } = await supabase
				.from('default_incident_users')
				.select('user_id')
				.eq('incident_type_id', selectedIncidentType.id);
			const defaultUserIds = (defaultIncidentData || []).map(d => d.user_id);
			
			// Merge default users into recipient list (for notifications), deduplicate
			defaultUserIds.forEach(uid => {
				if (!recipientUserIds.includes(uid)) {
					recipientUserIds.push(uid);
				}
			});
			
			// Get branch_id for each permitted user to filter same-branch for tasks
			const reporterBranchId = currentUserData.branch_id || get(currentUser)?.branch_id;
			let sameBranchUserIds: string[] = [];
			if (reporterBranchId && recipientUserIds.length > 0) {
				const { data: recipientUsers } = await supabase
					.from('users')
					.select('id, branch_id')
					.in('id', recipientUserIds);
				sameBranchUserIds = (recipientUsers || [])
					.filter(u => String(u.branch_id) === String(reporterBranchId))
					.map(u => u.id);
			}
			
			// Build task recipient list: same-branch users + default users (deduplicated)
			const taskRecipientIds = [...new Set([...sameBranchUserIds, ...defaultUserIds])];
			
			// Create user_statuses object
			const userStatuses: any = {};
			recipientUserIds.forEach(userId => {
				userStatuses[userId] = {
					status: 'reported',
					notified_at: new Date().toISOString(),
					read_at: null
				};
			});
			
			// Build related_party object
			let relatedParty = null;
			if (isCustomerIncident) {
				relatedParty = {
					name: customerName.trim(),
					contact_number: customerContact.trim()
				};
			} else if (!isEmployeeIncident && relatedPartyDetails.trim()) {
				relatedParty = {
					details: relatedPartyDetails.trim()
				};
			}
			
			// Create the incident
			const { error: insertError } = await supabase
				.from('incidents')
				.insert([{
					id: incidentId,
					incident_type_id: selectedIncidentType.id,
					employee_id: isEmployeeIncident ? selectedEmployee?.id : null,
					branch_id: selectedBranch.id,
					violation_id: isEmployeeIncident && selectedViolation ? selectedViolation.id : null,
					what_happened: {
						description: whatHappened,
						created_at: new Date().toISOString()
					},
					witness_details: proofWitness ? {
						details: proofWitness,
						recorded_at: new Date().toISOString()
					} : null,
					related_party: relatedParty,
					report_type: isEmployeeIncident ? 'employee_related' : 'general',
					reports_to_user_ids: recipientUserIds,
					resolution_status: 'reported',
					user_statuses: userStatuses,
					attachments: uploadedAttachments,
					created_by: currentUserData.id,
					updated_by: currentUserData.id
				}]);
			
			if (insertError) throw insertError;
			
			// Send notifications (same format as desktop)
			try {
				// Get the name of the created user
				const { data: createdUserData } = await supabase
					.from('hr_employee_master')
					.select('name_en, name_ar')
					.eq('user_id', currentUserData.id)
					.single();
				
				const createdByName = createdUserData?.name_en || currentUserData?.email || 'System User';
				const createdByNameAr = createdUserData?.name_ar || currentUserData?.email || 'مستخدم النظام';
				
				const incidentTypeName = selectedIncidentType.incident_type_en || 'Incident';
				const incidentTypeNameAr = selectedIncidentType.incident_type_ar || 'حادثة';
				
				const branchNameEn = `${selectedBranch.name_en} - ${selectedBranch.location_en}`;
				const branchNameAr = `${selectedBranch.name_ar || selectedBranch.name_en} - ${selectedBranch.location_ar || selectedBranch.location_en}`;
				
				const violationName = selectedViolation?.name_en || 'Unknown Violation';
				const violationNameAr = selectedViolation?.name_ar || 'انتهاك غير معروف';
				
				const employeeName = selectedEmployee?.name_en || 'Unknown';
				const employeeNameAr = selectedEmployee?.name_ar || selectedEmployee?.name_en || 'غير معروف';
				
				// Build related party description for non-employee incidents
				let relatedPartyDesc = '';
				let relatedPartyDescAr = '';
				if (isCustomerIncident) {
					relatedPartyDesc = `Customer: ${customerName}`;
					relatedPartyDescAr = `العميل: ${customerName}`;
				} else if (!isEmployeeIncident && relatedPartyDetails.trim()) {
					relatedPartyDesc = relatedPartyDetails.trim().substring(0, 100);
					relatedPartyDescAr = relatedPartyDetails.trim().substring(0, 100);
				}
				
				// Build notification message based on incident type
				let notificationMsgEn = '';
				let notificationMsgAr = '';
				
				if (isEmployeeIncident) {
					notificationMsgEn = `New incident report (${incidentId}) from ${createdByName} regarding ${employeeName} at ${branchNameEn} related to ${violationName}`;
					notificationMsgAr = `تقرير حادثة جديد (${incidentId}) من ${createdByNameAr} بخصوص ${employeeNameAr} في ${branchNameAr} المتعلق بـ ${violationNameAr}`;
				} else {
					notificationMsgEn = `New ${incidentTypeName} incident (${incidentId}) from ${createdByName} at ${branchNameEn}${relatedPartyDesc ? ` - ${relatedPartyDesc}` : ''}`;
					notificationMsgAr = `حادثة ${incidentTypeNameAr} جديدة (${incidentId}) من ${createdByNameAr} في ${branchNameAr}${relatedPartyDescAr ? ` - ${relatedPartyDescAr}` : ''}`;
				}
				
				// Build notification array for recipients
				const notificationsList = recipientUserIds.map(userId => ({
					title: '📋 New Incident Report | تقرير حادثة جديد',
					message: `${notificationMsgEn}\n---\n${notificationMsgAr}`,
					type: 'info',
					priority: 'normal',
					target_type: 'specific_users',
					target_users: [userId],
					created_at: new Date().toISOString()
				}));
				
				// Add notification for the employee (only for employee incidents)
				if (isEmployeeIncident && selectedEmployee) {
					const { data: employeeUser } = await supabase
						.from('hr_employee_master')
						.select('user_id')
						.eq('id', selectedEmployee.id)
						.single();
					
					if (employeeUser?.user_id) {
						notificationsList.push({
							title: '✅ Incident Report Submitted | تم إرسال تقرير الحادثة',
							message: `Incident report (${incidentId}) submitted by ${createdByName} regarding you at ${branchNameEn} related to ${violationName}. Report ID: ${incidentId}\n---\nتم إرسال تقرير حادثة (${incidentId}) من ${createdByNameAr} بخصوصك في ${branchNameAr} المتعلق بـ ${violationNameAr}. رقم التقرير: ${incidentId}`,
							type: 'success',
							priority: 'normal',
							target_type: 'specific_users',
							target_users: [employeeUser.user_id],
							created_at: new Date().toISOString()
						});
					}
				}
				
				// Send all notifications
				if (notificationsList.length > 0) {
					await supabase.from('notifications').insert(notificationsList);
				}
				
				// Create quick tasks for same-branch + default incident users
				if (taskRecipientIds.length > 0) {
					try {
						// Build task description based on incident type
						let taskDescEn = '';
						let taskDescAr = '';
						
						if (isEmployeeIncident) {
							taskDescEn = `From ${createdByName} regarding ${employeeName} at ${branchNameEn} related to ${violationName}`;
							taskDescAr = `من ${createdByNameAr} بخصوص ${employeeNameAr} في ${branchNameAr} المتعلق بـ ${violationNameAr}`;
						} else {
							taskDescEn = `${incidentTypeName} incident from ${createdByName} at ${branchNameEn}${relatedPartyDesc ? ` - ${relatedPartyDesc}` : ''}`;
							taskDescAr = `حادثة ${incidentTypeNameAr} من ${createdByNameAr} في ${branchNameAr}${relatedPartyDescAr ? ` - ${relatedPartyDescAr}` : ''}`;
						}
						
						// Create the quick task once
						const { data: quickTaskData, error: taskCreateError } = await supabase
							.from('quick_tasks')
							.insert({
								title: `Acknowledge Incident | تأكيد الحادثة: ${incidentId}`,
								description: `${taskDescEn}\n---\n${taskDescAr}`,
								priority: 'high',
								issue_type: 'incident_acknowledgement',
								assigned_by: currentUserData.id,
								assigned_to_branch_id: selectedBranch.id,
								incident_id: incidentId
							})
							.select()
							.single();

						if (taskCreateError) {
							console.warn('⚠️ Failed to create quick task:', taskCreateError);
						} else if (quickTaskData) {
							// Create assignments for all task recipients (same-branch + default users, deduplicated)
							const assignments = taskRecipientIds.map(userId => ({
								quick_task_id: quickTaskData.id,
								assigned_to_user_id: userId,
								require_task_finished: true
							}));

							const { error: assignmentError } = await supabase
								.from('quick_task_assignments')
								.insert(assignments);

							if (assignmentError) {
								console.warn('⚠️ Failed to create quick task assignments:', assignmentError);
							} else {
								console.log('✅ Quick task assignments created successfully');
							}
						}
					} catch (taskErr) {
						console.warn('⚠️ Error creating quick tasks:', taskErr);
					}
				}
			} catch (notifErr) {
				console.warn('Failed to send notifications:', notifErr);
			}
			
			// Success
			successMessage = $currentLocale === 'ar' 
				? `✅ تم الإبلاغ عن الحادثة بنجاح: ${incidentId}` 
				: `✅ Incident reported successfully: ${incidentId}`;
			showSuccessModal = true;
			
			// Reset form
			resetForm();
			
		} catch (err) {
			console.error('Error submitting incident:', err);
			errorMessage = $currentLocale === 'ar' 
				? 'خطأ: ' + (err instanceof Error ? err.message : 'فشل في إرسال التقرير')
				: 'Error: ' + (err instanceof Error ? err.message : 'Failed to submit report');
		} finally {
			saving = false;
		}
	}
	
	function resetForm() {
		selectedIncidentType = null;
		selectedBranch = null;
		selectedViolation = null;
		selectedEmployee = null;
		whatHappened = '';
		proofWitness = '';
		customerName = '';
		customerContact = '';
		relatedPartyDetails = '';
		incidentTypeSearch = '';
		branchSearch = '';
		violationSearch = '';
		employeeSearch = '';
		attachments = [];
		attachmentPreviews.forEach(p => URL.revokeObjectURL(p.url));
		attachmentPreviews = [];
	}
	
	function closeAllDropdowns() {
		showViolationDropdown = false;
		showEmployeeDropdown = false;
	}
</script>

<svelte:window on:click={closeAllDropdowns} />

<div class="mobile-page" dir={$currentLocale === 'ar' ? 'rtl' : 'ltr'}>
	<div class="mobile-content">
		{#if loading}
			<div class="loading-spinner">
				<div class="spinner"></div>
				<p>{$currentLocale === 'ar' ? 'جاري التحميل...' : 'Loading...'}</p>
			</div>
		{:else}
			<div class="form-container">
				<!-- Error Message -->
				{#if errorMessage}
					<div class="alert error-alert">
						<div class="alert-icon">⚠️</div>
						<div class="alert-content">
							<p>{errorMessage}</p>
						</div>
					</div>
				{/if}
				
				<!-- Incident Type Selection -->
				<div class="form-group">
					<label>{$currentLocale === 'ar' ? 'نوع الحادثة *' : 'Incident Type *'}</label>
					<button 
						type="button"
						class="dropdown-trigger"
						on:click|stopPropagation={() => { showIncidentTypeDropdown = true; showBranchDropdown = false; showViolationDropdown = false; showEmployeeDropdown = false; incidentTypeSearch = ''; }}
					>
						{#if selectedIncidentType}
							<span class="selected-value">
								<span class="type-code">{selectedIncidentType.id}</span>
								{$currentLocale === 'ar' ? selectedIncidentType.incident_type_ar : selectedIncidentType.incident_type_en}
							</span>
							<!-- svelte-ignore a11y_no_static_element_interactions -->
							<span class="clear-btn" on:click|stopPropagation={() => { selectedIncidentType = null; incidentTypeSearch = ''; }}>×</span>
						{:else}
							<span class="placeholder">{$currentLocale === 'ar' ? 'اختر نوع الحادثة...' : 'Select incident type...'}</span>
							<span class="dropdown-arrow">▼</span>
						{/if}
					</button>
				</div>
				
				<!-- Branch Selection -->
				<div class="form-group">
					<label>{$currentLocale === 'ar' ? 'الفرع *' : 'Branch *'}</label>
					<button 
						type="button"
						class="dropdown-trigger"
						on:click|stopPropagation={() => { showBranchDropdown = true; showIncidentTypeDropdown = false; showViolationDropdown = false; showEmployeeDropdown = false; branchSearch = ''; }}
					>
						{#if selectedBranch}
							<span class="selected-value">
								{$currentLocale === 'ar' 
									? `${selectedBranch.name_ar || selectedBranch.name_en} - ${selectedBranch.location_ar || selectedBranch.location_en}`
									: `${selectedBranch.name_en} - ${selectedBranch.location_en}`}
							</span>
							<!-- svelte-ignore a11y_no_static_element_interactions -->
							<span class="clear-btn" on:click|stopPropagation={() => { selectedBranch = null; branchSearch = ''; }}>×</span>
						{:else}
							<span class="placeholder">{$currentLocale === 'ar' ? 'اختر الفرع...' : 'Select branch...'}</span>
							<span class="dropdown-arrow">▼</span>
						{/if}
					</button>
				</div>
				
				<!-- Employee Incident Fields (IN2) -->
				{#if isEmployeeIncident}
					<!-- Violation Selection -->
					<div class="form-group">
						<label>{$currentLocale === 'ar' ? 'المخالفة *' : 'Violation *'}</label>
						<div class="dropdown-container" on:click|stopPropagation>
							<button 
								type="button"
								class="dropdown-trigger"
								on:click={() => { showViolationDropdown = !showViolationDropdown; showIncidentTypeDropdown = false; showBranchDropdown = false; showEmployeeDropdown = false; }}
							>
								{#if selectedViolation}
									<span class="selected-value">
										{$currentLocale === 'ar' ? selectedViolation.name_ar : selectedViolation.name_en}
									</span>
									<button type="button" class="clear-btn" on:click|stopPropagation={() => { selectedViolation = null; violationSearch = ''; }}>×</button>
								{:else}
									<span class="placeholder">{$currentLocale === 'ar' ? 'اختر المخالفة...' : 'Select violation...'}</span>
									<span class="dropdown-arrow">▼</span>
								{/if}
							</button>
							
							{#if showViolationDropdown}
								<div class="dropdown-menu">
									<input 
										type="text"
										class="dropdown-search"
										placeholder={$currentLocale === 'ar' ? 'بحث...' : 'Search...'}
										bind:value={violationSearch}
										on:click|stopPropagation
									/>
									<div class="dropdown-options">
										{#each filteredViolations as violation}
											<button 
												type="button"
												class="dropdown-option"
												on:click={() => { selectedViolation = violation; showViolationDropdown = false; violationSearch = ''; }}
											>
												{$currentLocale === 'ar' ? violation.name_ar : violation.name_en}
											</button>
										{/each}
										{#if filteredViolations.length === 0}
											<div class="no-results">{$currentLocale === 'ar' ? 'لا توجد نتائج' : 'No results'}</div>
										{/if}
									</div>
								</div>
							{/if}
						</div>
					</div>
					
					<!-- Employee Selection -->
					<div class="form-group">
						<label>{$currentLocale === 'ar' ? 'الموظف *' : 'Employee *'}</label>
						<div class="dropdown-container" on:click|stopPropagation>
							<button 
								type="button"
								class="dropdown-trigger"
								on:click={() => { showEmployeeDropdown = !showEmployeeDropdown; showIncidentTypeDropdown = false; showBranchDropdown = false; showViolationDropdown = false; }}
							>
								{#if selectedEmployee}
									<span class="selected-value">
										{$currentLocale === 'ar' 
											? `${selectedEmployee.name_ar || selectedEmployee.name_en} (${selectedEmployee.id})`
											: `${selectedEmployee.name_en} (${selectedEmployee.id})`}
									</span>
									<button type="button" class="clear-btn" on:click|stopPropagation={() => { selectedEmployee = null; employeeSearch = ''; }}>×</button>
								{:else}
									<span class="placeholder">{$currentLocale === 'ar' ? 'اختر الموظف...' : 'Select employee...'}</span>
									<span class="dropdown-arrow">▼</span>
								{/if}
							</button>
							
							{#if showEmployeeDropdown}
								<div class="dropdown-menu">
									<input 
										type="text"
										class="dropdown-search"
										placeholder={$currentLocale === 'ar' ? 'بحث...' : 'Search...'}
										bind:value={employeeSearch}
										on:click|stopPropagation
									/>
									<div class="dropdown-options">
										{#each filteredEmployees as employee}
											<button 
												type="button"
												class="dropdown-option"
												on:click={() => { selectedEmployee = employee; showEmployeeDropdown = false; employeeSearch = ''; }}
											>
												<span class="emp-name">{$currentLocale === 'ar' ? (employee.name_ar || employee.name_en) : employee.name_en}</span>
												<span class="emp-id">{employee.id}</span>
											</button>
										{/each}
										{#if filteredEmployees.length === 0}
											<div class="no-results">{$currentLocale === 'ar' ? 'لا توجد نتائج' : 'No results'}</div>
										{/if}
									</div>
								</div>
							{/if}
						</div>
					</div>
					
					<!-- Employee Details Card (like desktop) -->
					{#if selectedEmployee}
						<div class="employee-details-card">
							<label class="card-label">{$currentLocale === 'ar' ? 'تفاصيل الموظف' : 'Employee Details'}</label>
							<div class="details-row">
								<span class="emp-code">{selectedEmployee.id}</span>
								<span class="divider">|</span>
								<span class="emp-name-display">{$currentLocale === 'ar' ? (selectedEmployee.name_ar || selectedEmployee.name_en) : selectedEmployee.name_en}</span>
								<span class="divider">|</span>
								<span class="id-number">{selectedEmployee.id_number || ($currentLocale === 'ar' ? 'لا يوجد' : 'No ID')}</span>
							</div>
						</div>
					{/if}
				{/if}
				
				<!-- Customer Incident Fields (IN1, IN9) -->
				{#if isCustomerIncident}
					<div class="form-group">
						<label>{$currentLocale === 'ar' ? 'اسم العميل *' : 'Customer Name *'}</label>
						<input 
							type="text"
							class="form-input"
							bind:value={customerName}
							placeholder={$currentLocale === 'ar' ? 'أدخل اسم العميل' : 'Enter customer name'}
						/>
					</div>
					
					<div class="form-group">
						<label>{$currentLocale === 'ar' ? 'رقم التواصل' : 'Contact Number'}</label>
						<input 
							type="tel"
							class="form-input"
							bind:value={customerContact}
							placeholder={$currentLocale === 'ar' ? 'أدخل رقم التواصل' : 'Enter contact number'}
						/>
					</div>
				{/if}
				
				<!-- Other Incident Fields (non-employee, non-customer) -->
				{#if selectedIncidentType && !isEmployeeIncident && !isCustomerIncident}
					<div class="form-group">
						<label>{$currentLocale === 'ar' ? 'تفاصيل الطرف المعني' : 'Related Party Details'}</label>
						<textarea 
							class="form-textarea"
							bind:value={relatedPartyDetails}
							rows="2"
							placeholder={$currentLocale === 'ar' ? 'أدخل تفاصيل الطرف المعني (اختياري)' : 'Enter related party details (optional)'}
						></textarea>
					</div>
				{/if}
				
				<!-- What Happened -->
				<div class="form-group">
					<label>{$currentLocale === 'ar' ? 'ماذا حدث؟ *' : 'What Happened? *'}</label>
					<textarea 
						class="form-textarea"
						bind:value={whatHappened}
						rows="4"
						placeholder={$currentLocale === 'ar' ? 'اشرح ما حدث بالتفصيل...' : 'Describe what happened in detail...'}
					></textarea>
				</div>
				
				<!-- Proof/Witness -->
				<div class="form-group">
					<label>{$currentLocale === 'ar' ? 'الأدلة / الشهود' : 'Proof / Witnesses'}</label>
					<textarea 
						class="form-textarea"
						bind:value={proofWitness}
						rows="2"
						placeholder={$currentLocale === 'ar' ? 'أي أدلة أو شهود (اختياري)' : 'Any evidence or witnesses (optional)'}
					></textarea>
				</div>
				
				<!-- Attachments -->
				<div class="form-group">
					<label>{$currentLocale === 'ar' ? 'المرفقات (حد أقصى 5)' : 'Attachments (max 5)'}</label>
					<p class="helper-text">{$currentLocale === 'ar' ? 'يمكنك رفع صور أو PDF أو مستندات (حد أقصى 10 ميجابايت لكل ملف)' : 'You can upload images, PDFs, or documents (max 10MB per file)'}</p>
					
					{#if attachmentPreviews.length > 0}
						<div class="attachment-grid">
							{#each attachmentPreviews as preview, index}
								<div class="attachment-item">
									{#if preview.type === 'image'}
										<img src={preview.url} alt="Preview" />
									{:else}
										<div class="file-icon">📄</div>
									{/if}
									<button type="button" class="remove-attachment" on:click={() => removeAttachment(index)}>×</button>
									<span class="file-name">{preview.file.name.substring(0, 15)}</span>
								</div>
							{/each}
						</div>
					{/if}
					
					{#if attachments.length < 5}
						<div class="attachment-buttons">
							<!-- Camera Button -->
							<label class="camera-btn">
								<input 
									type="file"
									accept="image/*"
									capture="environment"
									on:change={handleAttachmentSelect}
									hidden
								/>
								<span>📷 {$currentLocale === 'ar' ? 'الكاميرا' : 'Camera'}</span>
							</label>
							
							<!-- Gallery/File Button -->
							<label class="upload-btn">
								<input 
									type="file"
									accept="image/*,.pdf,.doc,.docx"
									multiple
									on:change={handleAttachmentSelect}
									hidden
								/>
								<span>📎 {$currentLocale === 'ar' ? 'من الملفات' : 'From Files'}</span>
							</label>
						</div>
					{/if}
				</div>
				
				<!-- Submit Button -->
				<div class="submit-section">
					<button 
						type="button"
						class="submit-btn"
						on:click={submitIncident}
						disabled={saving || isUploadingAttachments}
					>
						{#if saving || isUploadingAttachments}
							<span class="btn-spinner"></span>
							{$currentLocale === 'ar' ? 'جاري الإرسال...' : 'Submitting...'}
						{:else}
							📤 {$currentLocale === 'ar' ? 'إرسال التقرير' : 'Submit Report'}
						{/if}
					</button>
				</div>
			</div>
		{/if}
	</div>
</div>

<!-- Incident Type Popup -->
{#if showIncidentTypeDropdown}
	<div class="popup-overlay" on:click={() => { showIncidentTypeDropdown = false; incidentTypeSearch = ''; }}>
		<div class="popup-panel" on:click|stopPropagation dir={$currentLocale === 'ar' ? 'rtl' : 'ltr'}>
			<div class="popup-header">
				<h3>{$currentLocale === 'ar' ? 'نوع الحادثة' : 'Incident Type'}</h3>
				<button type="button" class="popup-close" on:click={() => { showIncidentTypeDropdown = false; incidentTypeSearch = ''; }}>✕</button>
			</div>
			<div class="popup-search">
				<input 
					type="text"
					placeholder={$currentLocale === 'ar' ? 'بحث...' : 'Search...'}
					bind:value={incidentTypeSearch}
				/>
			</div>
			<div class="popup-list">
				{#each filteredIncidentTypes as type}
					<button 
						type="button"
						class="popup-option"
						class:selected={selectedIncidentType?.id === type.id}
						on:click={() => { selectedIncidentType = type; showIncidentTypeDropdown = false; incidentTypeSearch = ''; }}
					>
						<span class="type-code">{type.id}</span>
						<span>{$currentLocale === 'ar' ? type.incident_type_ar : type.incident_type_en}</span>
						{#if selectedIncidentType?.id === type.id}<span class="check-mark">✓</span>{/if}
					</button>
				{/each}
				{#if filteredIncidentTypes.length === 0}
					<div class="popup-no-results">{$currentLocale === 'ar' ? 'لا توجد نتائج' : 'No results'}</div>
				{/if}
			</div>
		</div>
	</div>
{/if}

<!-- Branch Popup -->
{#if showBranchDropdown}
	<div class="popup-overlay" on:click={() => { showBranchDropdown = false; branchSearch = ''; }}>
		<div class="popup-panel" on:click|stopPropagation dir={$currentLocale === 'ar' ? 'rtl' : 'ltr'}>
			<div class="popup-header">
				<h3>{$currentLocale === 'ar' ? 'اختر الفرع' : 'Select Branch'}</h3>
				<button type="button" class="popup-close" on:click={() => { showBranchDropdown = false; branchSearch = ''; }}>✕</button>
			</div>
			<div class="popup-search">
				<input 
					type="text"
					placeholder={$currentLocale === 'ar' ? 'بحث...' : 'Search...'}
					bind:value={branchSearch}
				/>
			</div>
			<div class="popup-list">
				{#each filteredBranches as branch}
					<button 
						type="button"
						class="popup-option"
						class:selected={selectedBranch?.id === branch.id}
						on:click={() => { selectedBranch = branch; showBranchDropdown = false; branchSearch = ''; }}
					>
						<span>{$currentLocale === 'ar' 
							? `${branch.name_ar || branch.name_en} - ${branch.location_ar || branch.location_en}`
							: `${branch.name_en} - ${branch.location_en}`}</span>
						{#if selectedBranch?.id === branch.id}<span class="check-mark">✓</span>{/if}
					</button>
				{/each}
				{#if filteredBranches.length === 0}
					<div class="popup-no-results">{$currentLocale === 'ar' ? 'لا توجد نتائج' : 'No results'}</div>
				{/if}
			</div>
		</div>
	</div>
{/if}

<!-- Alert Modal -->
{#if showAlertModal}
	<div class="modal-overlay" on:click={closeAlert}>
		<div class="modal-content alert-modal" on:click|stopPropagation>
			<div class="modal-icon">⚠️</div>
			<h3>{alertTitle}</h3>
			<p>{alertMessage}</p>
			<button class="modal-btn" on:click={closeAlert}>
				{$currentLocale === 'ar' ? 'حسناً' : 'OK'}
			</button>
		</div>
	</div>
{/if}

<!-- Success Modal -->
{#if showSuccessModal}
	<div class="modal-overlay" on:click={closeSuccessModal}>
		<div class="modal-content success-modal" on:click|stopPropagation>
			<div class="modal-icon">✅</div>
			<h3>{$currentLocale === 'ar' ? 'تم بنجاح!' : 'Success!'}</h3>
			<p>{successMessage}</p>
			<button class="modal-btn success" on:click={closeSuccessModal}>
				{$currentLocale === 'ar' ? 'حسناً' : 'OK'}
			</button>
		</div>
	</div>
{/if}

<style>
	.mobile-page {
		min-height: 100%;
		background: #F8FAFC;
		padding: 0;
	}
	
	.mobile-content {
		padding: 0;
		max-width: 100%;
	}
	
	.loading-spinner {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		min-height: 40vh;
		gap: 0.5rem;
		font-size: 0.82rem;
		color: #6B7280;
	}
	
	.spinner {
		width: 24px;
		height: 24px;
		border: 2px solid #e2e8f0;
		border-top-color: #3b82f6;
		border-radius: 50%;
		animation: spin 1s linear infinite;
	}
	
	@keyframes spin {
		to { transform: rotate(360deg); }
	}
	
	.form-container {
		background: white;
		border-radius: 0;
		padding: 0.5rem 0.6rem;
		box-shadow: none;
	}
	
	.alert {
		display: flex;
		gap: 0.4rem;
		padding: 0.4rem 0.5rem;
		border-radius: 5px;
		margin-bottom: 0.5rem;
	}
	
	.error-alert {
		background: #fef2f2;
		border: 1px solid #fecaca;
	}
	
	.alert-icon {
		font-size: 0.88rem;
	}
	
	.alert-content p {
		margin: 0;
		color: #dc2626;
		font-size: 0.76rem;
	}
	
	.form-group {
		margin-bottom: 0.5rem;
	}
	
	.form-group label {
		display: block;
		font-size: 0.76rem;
		font-weight: 600;
		color: #374151;
		margin-bottom: 0.2rem;
	}
	
	.form-group .helper-text {
		font-size: 0.66rem;
		color: #64748b;
		margin: -0.1rem 0 0.3rem 0;
	}
	
	.form-input,
	.form-textarea {
		width: 100%;
		padding: 0.4rem 0.5rem;
		border: 1px solid #d1d5db;
		border-radius: 5px;
		font-size: 0.78rem;
		transition: border-color 0.2s, box-shadow 0.2s;
		box-sizing: border-box;
	}
	
	.form-input:focus,
	.form-textarea:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 2px rgba(59, 130, 246, 0.1);
	}
	
	.form-textarea {
		resize: vertical;
		min-height: 60px;
	}
	
	/* Dropdown Styles */
	.dropdown-container {
		position: relative;
	}
	
	.dropdown-trigger {
		width: 100%;
		padding: 0.4rem 0.5rem;
		border: 1px solid #d1d5db;
		border-radius: 5px;
		background: white;
		display: flex;
		justify-content: space-between;
		align-items: center;
		cursor: pointer;
		font-size: 0.78rem;
		text-align: start;
	}
	
	.dropdown-trigger:hover {
		border-color: #9ca3af;
	}
	
	.placeholder {
		color: #9ca3af;
	}
	
	.selected-value {
		color: #1f2937;
		display: flex;
		align-items: center;
		gap: 0.3rem;
		flex: 1;
		font-size: 0.76rem;
	}
	
	.type-code {
		background: #3b82f6;
		color: white;
		padding: 0.1rem 0.25rem;
		border-radius: 3px;
		font-size: 0.66rem;
		font-weight: 600;
		font-family: monospace;
	}
	
	.dropdown-arrow {
		color: #9ca3af;
		font-size: 0.62rem;
	}
	
	.clear-btn {
		background: #ef4444;
		color: white;
		border: none;
		border-radius: 50%;
		width: 16px;
		height: 16px;
		font-size: 0.7rem;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		flex-shrink: 0;
	}
	
	.dropdown-menu {
		position: absolute;
		top: 100%;
		left: 0;
		right: 0;
		background: white;
		border: 1px solid #d1d5db;
		border-radius: 5px;
		box-shadow: 0 6px 16px rgba(0, 0, 0, 0.12);
		z-index: 100;
		margin-top: 0.15rem;
		max-height: 200px;
		overflow: hidden;
		display: flex;
		flex-direction: column;
	}
	
	.dropdown-search {
		padding: 0.4rem 0.5rem;
		border: none;
		border-bottom: 1px solid #e5e7eb;
		font-size: 0.76rem;
		outline: none;
	}
	
	.dropdown-options {
		overflow-y: auto;
		max-height: 160px;
	}
	
	.dropdown-option {
		width: 100%;
		padding: 0.4rem 0.5rem;
		border: none;
		background: white;
		text-align: start;
		cursor: pointer;
		font-size: 0.76rem;
		display: flex;
		align-items: center;
		gap: 0.3rem;
		border-bottom: 1px solid #f3f4f6;
	}
	
	.dropdown-option:hover {
		background: #f0f9ff;
	}
	
	.dropdown-option:last-child {
		border-bottom: none;
	}
	
	.emp-name {
		flex: 1;
	}
	
	.emp-id {
		color: #6b7280;
		font-size: 0.66rem;
		font-family: monospace;
	}
	
	.no-results {
		padding: 0.5rem;
		text-align: center;
		color: #9ca3af;
		font-size: 0.76rem;
	}
	
	/* Attachment Styles */
	.attachment-grid {
		display: grid;
		grid-template-columns: repeat(3, 1fr);
		gap: 0.35rem;
		margin-bottom: 0.35rem;
	}
	
	.attachment-item {
		position: relative;
		background: #f3f4f6;
		border-radius: 5px;
		overflow: hidden;
		aspect-ratio: 1;
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
	}
	
	.attachment-item img {
		width: 100%;
		height: 100%;
		object-fit: cover;
	}
	
	.file-icon {
		font-size: 1.2rem;
	}
	
	.file-name {
		position: absolute;
		bottom: 0;
		left: 0;
		right: 0;
		background: rgba(0, 0, 0, 0.6);
		color: white;
		font-size: 0.625rem;
		padding: 0.25rem;
		text-align: center;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}
	
	.remove-attachment {
		position: absolute;
		top: 0.15rem;
		right: 0.15rem;
		width: 1rem;
		height: 1rem;
		background: #ef4444;
		color: white;
		border: none;
		border-radius: 50%;
		font-size: 0.6rem;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
	}
	
	/* Attachment Buttons Container */
	.attachment-buttons {
		display: flex;
		gap: 0.4rem;
		flex-wrap: wrap;
	}
	
	.camera-btn {
		display: inline-flex;
		align-items: center;
		gap: 0.3rem;
		padding: 0.35rem 0.6rem;
		background: linear-gradient(135deg, #dc2626 0%, #b91c1c 100%);
		border: none;
		border-radius: 5px;
		color: white;
		font-weight: 600;
		font-size: 0.74rem;
		cursor: pointer;
		transition: all 0.2s;
		box-shadow: 0 1px 4px rgba(220, 38, 38, 0.3);
	}
	
	.camera-btn:hover {
		transform: translateY(-1px);
		box-shadow: 0 4px 12px rgba(220, 38, 38, 0.4);
	}
	
	.camera-btn:active {
		transform: translateY(0);
	}
	
	.upload-btn {
		display: inline-flex;
		align-items: center;
		gap: 0.3rem;
		padding: 0.35rem 0.6rem;
		background: #f0f9ff;
		border: 1px dashed #3b82f6;
		border-radius: 5px;
		color: #3b82f6;
		font-weight: 500;
		font-size: 0.74rem;
		cursor: pointer;
		transition: all 0.2s;
	}
	
	.upload-btn:hover {
		background: #dbeafe;
	}
	
	/* Submit Button */
	.submit-section {
		margin-top: 0.5rem;
		padding-top: 0.5rem;
		border-top: 1px solid #e5e7eb;
	}
	
	.submit-btn {
		width: 100%;
		padding: 0.5rem;
		background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
		color: white;
		border: none;
		border-radius: 6px;
		font-size: 0.82rem;
		font-weight: 600;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.3rem;
		min-height: 36px;
		transition: transform 0.2s, box-shadow 0.2s;
	}
	
	.submit-btn:hover:not(:disabled) {
		transform: translateY(-1px);
		box-shadow: 0 4px 12px rgba(59, 130, 246, 0.4);
	}
	
	.submit-btn:disabled {
		opacity: 0.7;
		cursor: not-allowed;
	}
	
	.btn-spinner {
		width: 1rem;
		height: 1rem;
		border: 2px solid white;
		border-top-color: transparent;
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
	}
	
	/* Modal Styles */
	.modal-overlay {
		position: fixed;
		inset: 0;
		background: rgba(0, 0, 0, 0.5);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 1000;
		padding: 1rem;
	}
	
	.modal-content {
		background: white;
		border-radius: 8px;
		padding: 1rem;
		max-width: 280px;
		width: 100%;
		text-align: center;
	}
	
	.modal-icon {
		font-size: 2rem;
		margin-bottom: 0.4rem;
	}
	
	.modal-content h3 {
		font-size: 0.88rem;
		font-weight: 700;
		color: #1e293b;
		margin: 0 0 0.3rem;
	}
	
	.modal-content p {
		color: #64748b;
		margin: 0 0 0.75rem;
		font-size: 0.78rem;
	}
	
	.modal-btn {
		width: 100%;
		padding: 0.4rem;
		border: none;
		border-radius: 5px;
		font-size: 0.82rem;
		font-weight: 600;
		cursor: pointer;
		background: #e5e7eb;
		color: #374151;
	}
	
	.modal-btn.success {
		background: #22c55e;
		color: white;
	}
	
	/* Popup Selection Modal */
	.popup-overlay {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: calc(3.6rem + env(safe-area-inset-bottom));
		background: rgba(0, 0, 0, 0.5);
		z-index: 999;
		display: flex;
		align-items: flex-end;
		justify-content: center;
	}
	
	.popup-panel {
		background: white;
		width: 100%;
		max-height: 70vh;
		border-radius: 12px 12px 0 0;
		display: flex;
		flex-direction: column;
		overflow: hidden;
		animation: slideUp 0.2s ease-out;
	}
	
	@keyframes slideUp {
		from { transform: translateY(100%); }
		to { transform: translateY(0); }
	}
	
	.popup-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 0.6rem 0.8rem;
		border-bottom: 1px solid #e5e7eb;
		flex-shrink: 0;
	}
	
	.popup-header h3 {
		margin: 0;
		font-size: 0.88rem;
		font-weight: 700;
		color: #1e293b;
	}
	
	.popup-close {
		background: #f1f5f9;
		border: none;
		border-radius: 50%;
		width: 24px;
		height: 24px;
		font-size: 0.7rem;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		color: #64748b;
	}
	
	.popup-search {
		padding: 0.4rem 0.6rem;
		border-bottom: 1px solid #e5e7eb;
		flex-shrink: 0;
	}
	
	.popup-search input {
		width: 100%;
		padding: 0.4rem 0.5rem;
		border: 1px solid #d1d5db;
		border-radius: 5px;
		font-size: 0.78rem;
		outline: none;
		box-sizing: border-box;
	}
	
	.popup-search input:focus {
		border-color: #3b82f6;
	}
	
	.popup-list {
		overflow-y: auto;
		flex: 1;
		-webkit-overflow-scrolling: touch;
	}
	
	.popup-option {
		width: 100%;
		padding: 0.5rem 0.8rem;
		border: none;
		border-bottom: 1px solid #f3f4f6;
		background: white;
		text-align: start;
		cursor: pointer;
		font-size: 0.78rem;
		display: flex;
		align-items: center;
		gap: 0.4rem;
		color: #1f2937;
	}
	
	.popup-option:active {
		background: #f0f9ff;
	}
	
	.popup-option.selected {
		background: #eff6ff;
		color: #2563eb;
		font-weight: 600;
	}
	
	.check-mark {
		margin-inline-start: auto;
		color: #2563eb;
		font-weight: 700;
		font-size: 0.82rem;
	}
	
	.popup-no-results {
		padding: 1rem;
		text-align: center;
		color: #9ca3af;
		font-size: 0.76rem;
	}
	
	/* RTL Support */
	:global([dir="rtl"]) .dropdown-trigger {
		text-align: right;
	}
	
	:global([dir="rtl"]) .dropdown-option {
		text-align: right;
	}
	
	:global([dir="rtl"]) .remove-attachment {
		right: auto;
		left: 0.25rem;
	}
	
	/* Employee Details Card (like desktop) */
	.employee-details-card {
		margin-top: 0.3rem;
	}
	
	.employee-details-card .card-label {
		display: block;
		font-size: 0.66rem;
		font-weight: 700;
		color: #475569;
		text-transform: uppercase;
		letter-spacing: 0.05em;
		margin-bottom: 0.25rem;
	}
	
	.employee-details-card .details-row {
		background: #f0fdf4;
		border: 1px solid #bbf7d0;
		border-radius: 5px;
		padding: 0.4rem 0.5rem;
		display: flex;
		align-items: center;
		gap: 0.3rem;
		flex-wrap: wrap;
	}
	
	.employee-details-card .emp-code {
		font-size: 0.68rem;
		font-weight: 700;
		color: #16a34a;
	}
	
	.employee-details-card .divider {
		color: #d1d5db;
	}
	
	.employee-details-card .emp-name-display {
		font-size: 0.76rem;
		font-weight: 500;
		color: #1e293b;
	}
	
	.employee-details-card .id-number {
		font-size: 0.76rem;
		font-weight: 700;
		color: #15803d;
	}
</style>
