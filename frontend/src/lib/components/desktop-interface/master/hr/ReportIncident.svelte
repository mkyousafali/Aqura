<script lang="ts">
    import { t, locale } from '$lib/i18n';
    import { currentUser } from '$lib/utils/persistentAuth';
    import { onMount } from 'svelte';
    
    export let violation: any;
    export let employees: any[] = [];
    export let branches: any[] = [];
    export let preSelectedIncidentType: string = '';
    export let preSelectedBranch: any = null;
    
    let selectedEmployee = '';
    let selectedEmployeeDetails: any = null;
    let selectedBranch = '';
    let isSaving = false;
    let loadingEmployee = false;
    let employeeSearchQuery = '';
    let showEmployeeDropdown = false;
    let whatHappened = '';
    let proofWitness = '';
    let incidentType = ''; // Will be set to IN2 only if opened from Discipline (with violation)
    let attachments: File[] = [];
    let attachmentPreviews: { file: File; url: string; type: string }[] = [];
    let isUploadingAttachments = false;
    
    // Incident type selector
    let incidentTypes: any[] = [];
    let incidentTypeSearchQuery = '';
    let showIncidentTypeDropdown = false;
    let loadingIncidentTypes = false;
    let selectedIncidentType: any = null;
    
    // Related party fields (for non-employee incidents)
    let relatedPartyDetails = '';
    let customerName = '';
    let customerContact = '';
    
    // Violation selector (for IN2 from sidebar - no violation passed)
    let violations: any[] = [];
    let violationSearchQuery = '';
    let showViolationDropdown = false;
    let selectedViolation: any = null;
    
    // Check if IN2 is selected from sidebar (no violation passed)
    $: needsViolationSelector = incidentType === 'IN2' && !violation;
    
    // Load violations when IN2 is selected from sidebar
    $: if (needsViolationSelector && violations.length === 0) {
        loadViolations();
    }
    
    async function loadViolations() {
        try {
            const { supabase } = await import('$lib/utils/supabase');
            const { data, error } = await supabase
                .from('warning_violation')
                .select('id, name_en, name_ar')
                .order('name_en');
            
            if (error) throw error;
            violations = data || [];
        } catch (err) {
            console.error('Error loading violations:', err);
            violations = [];
        }
    }
    
    // Filter violations based on search
    $: filteredViolations = violations.filter(v => {
        if (!violationSearchQuery.trim()) return true;
        const query = violationSearchQuery.toLowerCase();
        return (v.name_en?.toLowerCase().includes(query) || v.name_ar?.includes(query));
    });
    
    function selectViolation(v: any) {
        selectedViolation = v;
        violationSearchQuery = $locale === 'ar' ? v.name_ar : v.name_en;
        showViolationDropdown = false;
    }
    
    function clearViolation() {
        selectedViolation = null;
        violationSearchQuery = '';
    }
    
    // Local employees list (loaded from DB when employees prop is empty)
    let localEmployees: any[] = [];
    let localBranches: any[] = [];
    
    // Use passed employees/branches or load from DB
    $: availableEmployees = employees.length > 0 ? employees : localEmployees;
    $: availableBranches = branches.length > 0 ? branches : localBranches;
    
    // Load employees when needed
    $: if (employees.length === 0 && localEmployees.length === 0) {
        loadEmployees();
    }
    
    async function loadEmployees() {
        try {
            const { supabase } = await import('$lib/utils/supabase');
            const { data, error } = await supabase
                .from('hr_employee_master')
                .select('id, name_en, name_ar, id_number')
                .order('name_en');
            
            if (error) throw error;
            localEmployees = data || [];
            console.log('Loaded employees:', localEmployees.length);
        } catch (err) {
            console.error('Error loading employees:', err);
            localEmployees = [];
        }
    }
    
    onMount(async () => {
        await loadIncidentTypes();
        await loadBranches();
        if (employees.length === 0) {
            await loadEmployees();
        }
        
        // Pre-select branch if passed
        if (preSelectedBranch && preSelectedBranch.id) {
            selectedBranch = preSelectedBranch.id;
        }
    });
    
    async function loadBranches() {
        try {
            const { supabase } = await import('$lib/utils/supabase');
            const { data, error } = await supabase
                .from('branches')
                .select('id, name_en, name_ar, location_en, location_ar')
                .eq('is_active', true)
                .order('name_en');
            
            if (error) throw error;
            localBranches = data || [];
        } catch (err) {
            console.error('Error loading branches:', err);
        }
    }
    
    async function loadIncidentTypes() {
        loadingIncidentTypes = true;
        try {
            const { supabase } = await import('$lib/utils/supabase');
            const { data, error } = await supabase
                .from('incident_types')
                .select('*')
                .eq('is_active', true)
                .order('id');
            
            if (error) throw error;
            incidentTypes = data || [];
            
            // Pre-select incident type if passed (e.g., IN3 from checklist)
            if (preSelectedIncidentType) {
                incidentType = preSelectedIncidentType;
                selectedIncidentType = incidentTypes.find(t => t.id === preSelectedIncidentType) || null;
                if (selectedIncidentType) {
                    incidentTypeSearchQuery = $locale === 'ar' ? selectedIncidentType.incident_type_ar : selectedIncidentType.incident_type_en;
                }
            }
            // Only auto-select incident type if opened from Discipline (violation is passed)
            else if (violation) {
                incidentType = 'IN2'; // Employee Incidents
                selectedIncidentType = incidentTypes.find(t => t.id === 'IN2') || null;
                if (selectedIncidentType) {
                    incidentTypeSearchQuery = $locale === 'ar' ? selectedIncidentType.incident_type_ar : selectedIncidentType.incident_type_en;
                }
            }
        } catch (err) {
            console.error('Error loading incident types:', err);
            incidentTypes = [];
        } finally {
            loadingIncidentTypes = false;
        }
    }
    
    $: filteredIncidentTypes = incidentTypes.filter(type => {
        if (!incidentTypeSearchQuery.trim()) return true;
        const query = incidentTypeSearchQuery.toLowerCase();
        return (type.incident_type_en?.toLowerCase().includes(query) || 
                type.incident_type_ar?.toLowerCase().includes(query) ||
                type.id?.toLowerCase().includes(query));
    }).sort((a, b) => {
        // Customer-related types (IN1, IN9) at the top
        const customerTypes = ['IN1', 'IN9'];
        const aIsCustomer = customerTypes.includes(a.id);
        const bIsCustomer = customerTypes.includes(b.id);
        if (aIsCustomer && !bIsCustomer) return -1;
        if (!aIsCustomer && bIsCustomer) return 1;
        return a.id.localeCompare(b.id);
    });
    
    function selectIncidentType(type: any) {
        selectedIncidentType = type;
        incidentType = type.id;
        incidentTypeSearchQuery = $locale === 'ar' ? type.incident_type_ar : type.incident_type_en;
        showIncidentTypeDropdown = false;
    }
    
    function clearIncidentType() {
        selectedIncidentType = null;
        incidentType = '';
        incidentTypeSearchQuery = '';
    }

    $: filteredEmployees = availableEmployees.filter(emp => {
        if (!employeeSearchQuery.trim()) return true;
        const query = employeeSearchQuery.toLowerCase();
        return (emp.name_en?.toLowerCase().includes(query) || 
                emp.name_ar?.toLowerCase().includes(query) ||
                emp.id?.toLowerCase().includes(query) ||
                emp.id_number?.toLowerCase().includes(query));
    });

    function selectEmployee(emp: any) {
        selectedEmployee = emp.id;
        employeeSearchQuery = `${emp.name_en}${emp.name_ar ? ' / ' + emp.name_ar : ''}`;
        showEmployeeDropdown = false;
    }

    function clearEmployee() {
        selectedEmployee = '';
        employeeSearchQuery = '';
        selectedEmployeeDetails = null;
    }

    async function loadEmployeeDetails() {
        if (!selectedEmployee) {
            selectedEmployeeDetails = null;
            return;
        }

        loadingEmployee = true;
        try {
            const { supabase } = await import('$lib/utils/supabase');
            const { data, error } = await supabase
                .from('hr_employee_master')
                .select('id, name_en, name_ar, id_number, id_expiry_date')
                .eq('id', selectedEmployee)
                .single();
            
            if (error) throw error;
            selectedEmployeeDetails = data;
        } catch (err) {
            console.error('Error loading employee details:', err);
            selectedEmployeeDetails = null;
        } finally {
            loadingEmployee = false;
        }
    }

    $: if (selectedEmployee) {
        loadEmployeeDetails();
    }

    function handleAttachmentSelect(e: Event) {
        const input = e.target as HTMLInputElement;
        const files = input.files;
        
        if (files && files.length > 0) {
            for (let i = 0; i < files.length; i++) {
                const file = files[i];
                
                // Validate file size (max 10MB per file)
                if (file.size > 10 * 1024 * 1024) {
                    alert($locale === 'ar' ? `حجم الملف "${file.name}" أكبر من 10 ميجابايت` : `File "${file.name}" exceeds 10MB`);
                    continue;
                }
                
                // Add to attachments array
                attachments = [...attachments, file];
                
                // Create preview for images
                if (file.type.startsWith('image/')) {
                    const reader = new FileReader();
                    reader.onload = (e) => {
                        attachmentPreviews = [...attachmentPreviews, {
                            file,
                            url: e.target?.result as string,
                            type: 'image'
                        }];
                    };
                    reader.readAsDataURL(file);
                } else {
                    // Non-image file preview
                    attachmentPreviews = [...attachmentPreviews, {
                        file,
                        url: '',
                        type: file.type.includes('pdf') ? 'pdf' : 'file'
                    }];
                }
            }
            // Reset input to allow selecting the same file again
            input.value = '';
        }
    }

    function removeAttachment(index: number) {
        attachments = attachments.filter((_, i) => i !== index);
        attachmentPreviews = attachmentPreviews.filter((_, i) => i !== index);
    }

    function clearAllAttachments() {
        attachments = [];
        attachmentPreviews = [];
    }

    async function handleReportIncident() {
        const isEmployeeIncident = incidentType === 'IN2';
        
        // Get the active violation (passed prop or selected from dropdown)
        const activeViolation = violation || selectedViolation;
        
        // Validation for employee incidents
        if (isEmployeeIncident && (!selectedEmployee || !activeViolation || !selectedBranch || !whatHappened.trim())) {
            alert($locale === 'ar' ? 'يرجى ملء جميع الحقول المطلوبة' : 'Please fill in all required fields');
            return;
        }
        
        // Validation for non-employee incidents
        if (!isEmployeeIncident && (!incidentType || !selectedBranch || !whatHappened.trim())) {
            alert($locale === 'ar' ? 'يرجى ملء جميع الحقول المطلوبة' : 'Please fill in all required fields');
            return;
        }
        
        // Validation for customer incidents - require name and contact
        if ((incidentType === 'IN1' || incidentType === 'IN9') && (!customerName.trim() || !customerContact.trim())) {
            alert($locale === 'ar' ? 'يرجى إدخال اسم العميل ورقم الاتصال' : 'Please enter customer name and contact number');
            return;
        }
        
        if (!$currentUser || !$currentUser.id) {
            alert($locale === 'ar' ? 'لم يتم تحديد المستخدم الحالي' : 'Current user not identified');
            return;
        }
        
        isSaving = true;
        let uploadedAttachments: any[] = [];
        
        try {
            const { supabase } = await import('$lib/utils/supabase');
            
            // Upload all attachments if any
            if (attachments.length > 0) {
                isUploadingAttachments = true;
                
                for (const file of attachments) {
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
                }
                isUploadingAttachments = false;
            }
            
            // Get the next incident ID (fetch all IDs to compute max numerically, avoiding lexicographic sort issues)
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
            
            // Map incident type to the correct permission column
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
            
            const permissionColumn = incidentTypeToPermission[incidentType] || 'can_receive_other_incidents';
            
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
                .eq('incident_type_id', incidentType);
            const defaultUserIds = (defaultIncidentData || []).map((d: any) => d.user_id);
            
            // Merge default users into recipient list (for notifications), deduplicate
            defaultUserIds.forEach((uid: string) => {
                if (!recipientUserIds.includes(uid)) {
                    recipientUserIds.push(uid);
                }
            });
            
            // Get branch_id for each permitted user to filter same-branch for tasks
            const reporterBranchId = $currentUser?.branch_id;
            let sameBranchUserIds: string[] = [];
            if (reporterBranchId && recipientUserIds.length > 0) {
                const { data: recipientUsers } = await supabase
                    .from('users')
                    .select('id, branch_id')
                    .in('id', recipientUserIds);
                sameBranchUserIds = (recipientUsers || [])
                    .filter((u: any) => String(u.branch_id) === String(reporterBranchId))
                    .map((u: any) => u.id);
            }
            
            // Build task recipient list: same-branch users + default users (deduplicated)
            const taskRecipientIds = [...new Set([...sameBranchUserIds, ...defaultUserIds])];
            
            // Create user_statuses object with 'reported' status for each recipient
            const userStatuses: any = {};
            recipientUserIds.forEach(userId => {
                userStatuses[userId] = {
                    status: 'reported',
                    notified_at: new Date().toISOString(),
                    read_at: null
                };
            });
            
            // Build related_party object based on incident type
            let relatedParty = null;
            if (incidentType === 'IN1' || incidentType === 'IN9') {
                // Customer/POS incidents - store name and contact
                relatedParty = {
                    name: customerName.trim(),
                    contact_number: customerContact.trim()
                };
            } else if (incidentType !== 'IN2' && relatedPartyDetails.trim()) {
                // Other non-employee incidents - store details
                relatedParty = {
                    details: relatedPartyDetails.trim()
                };
            }
            
            // Create the incident report
            const { error: insertError } = await supabase
                .from('incidents')
                .insert([{
                    id: incidentId,
                    incident_type_id: incidentType,
                    employee_id: isEmployeeIncident ? selectedEmployee : null,
                    branch_id: selectedBranch,
                    violation_id: isEmployeeIncident && activeViolation ? activeViolation.id : null,
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
                    created_by: $currentUser.id,
                    updated_by: $currentUser.id
                }]);
            
            if (insertError) throw insertError;
            
            // Send notifications to recipients and employee
            try {
                // Get the name of the created user
                const { data: createdUserData, error: createdUserError } = await supabase
                    .from('hr_employee_master')
                    .select('name_en, name_ar')
                    .eq('user_id', $currentUser.id)
                    .single();
                
                // Get the branch name and location (bilingual)
                const { data: branchData, error: branchError } = await supabase
                    .from('branches')
                    .select('name_en, name_ar, location_en, location_ar')
                    .eq('id', selectedBranch)
                    .single();
                
                const createdByName = createdUserData?.name_en || $currentUser?.email || 'System User';
                const createdByNameAr = createdUserData?.name_ar || $currentUser?.email || 'مستخدم النظام';
                
                // Get incident type name
                const incidentTypeName = selectedIncidentType?.incident_type_en || 'Incident';
                const incidentTypeNameAr = selectedIncidentType?.incident_type_ar || 'حادثة';
                
                // For employee incidents, use employee and violation info
                // For non-employee incidents, use related party info
                const isEmployeeIncident = incidentType === 'IN2';
                const employeeName = isEmployeeIncident ? (selectedEmployeeDetails?.name_en || 'Unknown') : '';
                const employeeNameAr = isEmployeeIncident ? (selectedEmployeeDetails?.name_ar || 'غير معروف') : '';
                
                const branchNameEn = branchData?.name_en && branchData?.location_en 
                    ? `${branchData.name_en} - ${branchData.location_en}`
                    : branchData?.name_en || 'Unknown Branch';
                const branchNameAr = branchData?.name_ar && branchData?.location_ar 
                    ? `${branchData.name_ar} - ${branchData.location_ar}`
                    : branchData?.name_ar || 'فرع غير معروف';
                
                const violationName = activeViolation?.name_en || 'Unknown Violation';
                const violationNameAr = activeViolation?.name_ar || 'انتهاك غير معروف';
                
                // Build related party description for non-employee incidents
                let relatedPartyDesc = '';
                let relatedPartyDescAr = '';
                if (incidentType === 'IN1' || incidentType === 'IN9') {
                    relatedPartyDesc = `Customer: ${customerName}`;
                    relatedPartyDescAr = `العميل: ${customerName}`;
                } else if (!isEmployeeIncident && relatedPartyDetails.trim()) {
                    relatedPartyDesc = relatedPartyDetails.trim().substring(0, 100);
                    relatedPartyDescAr = relatedPartyDetails.trim().substring(0, 100);
                }
                
                // Get the user_id of the selected employee (only for employee incidents)
                let employeeUserId = null;
                if (isEmployeeIncident && selectedEmployee) {
                    const { data: employeeUser, error: empUserError } = await supabase
                        .from('hr_employee_master')
                        .select('user_id')
                        .eq('id', selectedEmployee)
                        .single();
                    
                    if (empUserError) {
                        console.warn('⚠️ Could not fetch employee user_id:', empUserError);
                    } else {
                        employeeUserId = employeeUser?.user_id;
                    }
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
                
                // Build notification array for recipients (bilingual - both at same time)
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
                if (isEmployeeIncident && employeeUserId) {
                    notificationsList.push({
                        title: '✅ Incident Report Submitted | تم إرسال تقرير الحادثة',
                        message: `Incident report (${incidentId}) submitted by ${createdByName} regarding you at ${branchNameEn} related to ${violationName}. Report ID: ${incidentId}\n---\nتم إرسال تقرير حادثة (${incidentId}) من ${createdByNameAr} بخصوصك في ${branchNameAr} المتعلق بـ ${violationNameAr}. رقم التقرير: ${incidentId}`,
                        type: 'success',
                        priority: 'normal',
                        target_type: 'specific_users',
                        target_users: [employeeUserId],
                        created_at: new Date().toISOString()
                    });
                }
                
                // Send all notifications
                if (notificationsList.length > 0) {
                    await supabase
                        .from('notifications')
                        .insert(notificationsList);
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
                                assigned_by: $currentUser.id,
                                assigned_to_branch_id: selectedBranch,
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
                console.warn('⚠️ Failed to send notifications:', notifErr);
                // Don't fail the save if notifications fail
            }
            
            alert($locale === 'ar' ? `✅ تم الإبلاغ عن الحادثة بنجاح: ${incidentId}` : `✅ Incident reported successfully: ${incidentId}`);
            
            // Clear form
            selectedEmployee = '';
            selectedEmployeeDetails = null;
            selectedBranch = '';
            whatHappened = '';
            proofWitness = '';
            employeeSearchQuery = '';
            attachments = [];
            attachmentPreviews = [];
            relatedPartyDetails = '';
            customerName = '';
            customerContact = '';
            selectedViolation = null;
            violationSearchQuery = '';
            
        } catch (err) {
            console.error('Error saving incident:', err);
            alert('Error: ' + (err instanceof Error ? err.message : 'Failed to save'));
        } finally {
            isSaving = false;
        }
    }
</script>

<div class="h-full flex flex-col bg-gradient-to-br from-blue-50 to-slate-50 font-sans">
    <div class="p-6 space-y-4 overflow-y-auto flex-1">
        <!-- 1. Incident Type Selection (same as mobile - always first) -->
        <div>
            <label class="block text-xs font-bold text-slate-600 uppercase tracking-wide mb-2">{$locale === 'ar' ? 'نوع الحادثة *' : 'Incident Type *'}</label>
            <div class="relative">
                <div class="relative">
                    <input 
                        type="text" 
                        bind:value={incidentTypeSearchQuery}
                        on:focus={() => showIncidentTypeDropdown = true}
                        placeholder={$locale === 'ar' ? 'اختر نوع الحادثة...' : 'Select incident type...'}
                        class="w-full px-3 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none text-sm hover:border-slate-300 transition pr-8"
                    />
                    {#if selectedIncidentType}
                        <button 
                            type="button"
                            on:click={clearIncidentType}
                            class="absolute right-2 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600 text-lg"
                        >×</button>
                    {:else}
                        <span class="absolute right-2 top-1/2 -translate-y-1/2 text-slate-400 text-sm">📌</span>
                    {/if}
                </div>
                {#if showIncidentTypeDropdown && !selectedIncidentType}
                    <div class="absolute z-50 top-full left-0 right-0 mt-1 bg-white border border-slate-200 rounded-lg shadow-lg max-h-48 overflow-y-auto">
                        {#if loadingIncidentTypes}
                            <div class="px-3 py-2 text-sm text-slate-500">{$locale === 'ar' ? 'جاري التحميل...' : 'Loading...'}</div>
                        {:else if filteredIncidentTypes.length === 0}
                            <div class="px-3 py-2 text-sm text-slate-500">{$locale === 'ar' ? 'لم يتم العثور على أنواع' : 'No types found'}</div>
                        {:else}
                            {#each filteredIncidentTypes as type}
                                <button 
                                    type="button"
                                    on:click={() => selectIncidentType(type)}
                                    class="w-full px-3 py-2 text-left text-sm hover:bg-blue-50 border-b border-slate-100 last:border-b-0 transition flex items-center gap-2"
                                >
                                    <span class="text-blue-500 font-mono text-xs">{type.id}</span>
                                    <span class="font-medium text-slate-900">{$locale === 'ar' ? type.incident_type_ar : type.incident_type_en}</span>
                                </button>
                            {/each}
                        {/if}
                    </div>
                {/if}
            </div>
            {#if selectedIncidentType}
                <div class="mt-2 bg-blue-50 border border-blue-200 rounded px-3 py-1.5 flex items-center gap-2">
                    <span class="text-blue-600 font-mono text-xs font-bold">{selectedIncidentType.id}</span>
                    <span class="text-sm text-slate-700">{$locale === 'ar' ? selectedIncidentType.incident_type_ar : selectedIncidentType.incident_type_en}</span>
                </div>
            {/if}
        </div>
        
        <!-- 2. Branch Selection (same as mobile - always shown after incident type, before conditional fields) -->
        {#if selectedIncidentType || violation}
            <div>
                <label for="branch-select" class="block text-xs font-bold text-slate-600 uppercase tracking-wide mb-2">{$locale === 'ar' ? 'الفرع *' : 'Branch *'}</label>
                <select 
                    id="branch-select"
                    bind:value={selectedBranch}
                    class="w-full px-3 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none text-sm hover:border-slate-300 transition"
                >
                    <option value="">{$locale === 'ar' ? 'اختر الفرع...' : 'Select Branch...'}</option>
                    {#each availableBranches as branch}
                        <option value={branch.id}>
                            {$locale === 'ar' 
                                ? `${branch.name_ar || branch.name_en} - ${branch.location_ar || branch.location_en}` 
                                : `${branch.name_en} - ${branch.location_en}`}
                        </option>
                    {/each}
                </select>
                {#if !selectedBranch}
                    <p class="text-xs text-red-600 mt-1">{$locale === 'ar' ? 'هذا الحقل مطلوب' : 'This field is required'}</p>
                {/if}
            </div>
        {/if}
        
        <!-- 3. Conditional Fields based on Incident Type -->
        
        <!-- 3a. Employee Incidents (IN2) - Violation & Employee Selection -->
        {#if violation || incidentType === 'IN2'}
            <div>
                <label class="block text-xs font-bold text-slate-600 uppercase tracking-wide mb-2">{$locale === 'ar' ? 'المخالفة *' : 'Violation *'}</label>
                {#if violation}
                    <!-- Violation passed from Discipline - show as static badge -->
                    <div class="bg-blue-50 border border-blue-200 rounded px-3 py-1.5 flex items-center gap-2">
                        <div class="w-1 h-6 bg-blue-500 rounded-full"></div>
                        <div class="text-xs">
                            <span class="font-medium text-slate-900">{$locale === 'ar' ? violation.name_ar : violation.name_en}</span>
                        </div>
                    </div>
                {:else if needsViolationSelector}
                    <!-- IN2 selected from sidebar - show violation search -->
                    <div class="relative">
                        <div class="relative">
                            <input 
                                type="text" 
                                bind:value={violationSearchQuery}
                                on:focus={() => showViolationDropdown = true}
                                placeholder={$locale === 'ar' ? 'بحث عن مخالفة...' : 'Search violation...'}
                                class="w-full px-3 py-2 border border-orange-200 rounded-lg focus:ring-2 focus:ring-orange-500 focus:border-orange-500 outline-none text-sm hover:border-orange-300 transition bg-orange-50 pr-8"
                            />
                            {#if selectedViolation}
                                <button 
                                    type="button"
                                    on:click={clearViolation}
                                    class="absolute right-2 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600 text-lg"
                                >×</button>
                            {:else}
                                <span class="absolute right-2 top-1/2 -translate-y-1/2 text-orange-400 text-sm">⚠</span>
                            {/if}
                        </div>
                        {#if showViolationDropdown && !selectedViolation}
                            <div class="absolute z-50 top-full left-0 right-0 mt-1 bg-white border border-orange-200 rounded-lg shadow-lg max-h-64 overflow-y-auto">
                                {#if filteredViolations.length === 0}
                                    <div class="px-3 py-2 text-sm text-slate-500">{$locale === 'ar' ? 'لم يتم العثور على مخالفات' : 'No violations found'}</div>
                                {:else}
                                    {#each filteredViolations as v}
                                        <button 
                                            type="button"
                                            on:click={() => selectViolation(v)}
                                            class="w-full px-3 py-2 text-left text-sm hover:bg-orange-50 border-b border-slate-100 last:border-b-0 transition"
                                        >
                                            <span class="font-medium text-slate-900">{$locale === 'ar' ? (v.name_ar || v.name_en) : v.name_en}</span>
                                        </button>
                                    {/each}
                                {/if}
                            </div>
                        {/if}
                    </div>
                    {#if selectedViolation}
                        <div class="mt-2 bg-orange-50 border border-orange-200 rounded px-3 py-1.5 flex items-center gap-2">
                            <div class="w-1 h-6 bg-orange-500 rounded-full"></div>
                            <span class="text-xs font-medium text-slate-900">{$locale === 'ar' ? selectedViolation.name_ar : selectedViolation.name_en}</span>
                        </div>
                    {/if}
                {/if}
            </div>
            
            <!-- Employee Selection -->
            <div>
                <label class="block text-xs font-bold text-slate-600 uppercase tracking-wide mb-2">{$locale === 'ar' ? 'الموظف *' : 'Employee *'}</label>
                <div class="relative">
                    <div class="relative">
                        <input 
                            type="text" 
                            bind:value={employeeSearchQuery}
                            on:focus={() => showEmployeeDropdown = true}
                            placeholder={$locale === 'ar' ? 'بحث موظف...' : 'Search employee...'}
                            class="w-full px-3 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none text-sm hover:border-slate-300 transition pr-8"
                        />
                        {#if selectedEmployee}
                            <button 
                                type="button"
                                on:click={clearEmployee}
                                class="absolute right-2 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600 text-lg"
                            >×</button>
                        {:else}
                            <span class="absolute right-2 top-1/2 -translate-y-1/2 text-slate-400 text-sm">🔍</span>
                        {/if}
                    </div>
                    {#if showEmployeeDropdown && !selectedEmployee}
                        <div class="absolute z-50 top-full left-0 right-0 mt-1 bg-white border border-slate-200 rounded-lg shadow-lg max-h-48 overflow-y-auto">
                            {#if filteredEmployees.length === 0}
                                <div class="px-3 py-2 text-sm text-slate-500">{$locale === 'ar' ? 'لم يتم العثور على موظفين' : 'No employees found'}</div>
                            {:else}
                                {#each filteredEmployees.slice(0, 10) as emp}
                                    <button 
                                        type="button"
                                        on:click={() => selectEmployee(emp)}
                                        class="w-full px-3 py-2 text-left text-sm hover:bg-blue-50 border-b border-slate-100 last:border-b-0 transition"
                                    >
                                        <span class="font-medium text-slate-900">{$locale === 'ar' ? (emp.name_ar || emp.name_en) : emp.name_en}</span>
                                        <span class="text-slate-400 text-xs ml-2">({emp.id})</span>
                                    </button>
                                {/each}
                            {/if}
                        </div>
                    {/if}
                </div>
            </div>
            
            <!-- Employee Details Card -->
            {#if selectedEmployee}
                {#if loadingEmployee}
                    <div class="bg-slate-100 border border-slate-200 rounded px-3 py-1.5 flex items-center gap-2">
                        <div class="animate-spin w-4 h-4 border-2 border-slate-300 border-t-slate-600 rounded-full"></div>
                        <span class="text-xs text-slate-500">{$locale === 'ar' ? 'جاري التحميل...' : 'Loading...'}</span>
                    </div>
                {:else if selectedEmployeeDetails}
                    <div>
                        <label class="block text-xs font-bold text-slate-600 uppercase tracking-wide mb-2">{$locale === 'ar' ? 'تفاصيل الموظف' : 'Employee Details'}</label>
                        <div class="bg-green-50 border border-green-200 rounded px-3 py-1.5 flex items-center gap-3">
                            <div class="w-1 h-6 bg-green-500 rounded-full flex-shrink-0"></div>
                            <span class="text-xs font-bold text-green-600">{selectedEmployeeDetails.id || '-'}</span>
                            <span class="text-slate-400">|</span>
                            <span class="text-sm font-medium text-slate-900">{$locale === 'ar' ? (selectedEmployeeDetails.name_ar || selectedEmployeeDetails.name_en) : selectedEmployeeDetails.name_en}</span>
                            <span class="text-slate-400">|</span>
                            <span class="text-sm font-bold text-green-700">{selectedEmployeeDetails.id_number || ($locale === 'ar' ? 'لا يوجد' : 'No ID')}</span>
                        </div>
                    </div>
                {/if}
            {/if}
        {/if}
        
        <!-- 3b. Customer Incidents (IN1, IN9) - Customer Details -->
        {#if !violation && (incidentType === 'IN1' || incidentType === 'IN9')}
            <div class="bg-orange-50 border border-orange-200 rounded-lg p-4 space-y-3">
                <div class="flex items-center gap-2 mb-2">
                    <span class="text-lg">👤</span>
                    <span class="text-sm font-bold text-orange-700">{$locale === 'ar' ? 'تفاصيل العميل' : 'Customer Details'}</span>
                </div>
                <div>
                    <label for="customer-name" class="block text-xs font-bold text-slate-600 uppercase tracking-wide mb-1">{$locale === 'ar' ? 'اسم العميل *' : 'Customer Name *'}</label>
                    <input 
                        id="customer-name"
                        type="text"
                        bind:value={customerName}
                        placeholder={$locale === 'ar' ? 'أدخل اسم العميل...' : 'Enter customer name...'}
                        class="w-full px-3 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-orange-500 focus:border-orange-500 outline-none text-sm hover:border-slate-300 transition"
                    />
                    {#if !customerName.trim()}
                        <p class="text-xs text-red-600 mt-1">{$locale === 'ar' ? 'هذا الحقل مطلوب' : 'This field is required'}</p>
                    {/if}
                </div>
                <div>
                    <label for="customer-contact" class="block text-xs font-bold text-slate-600 uppercase tracking-wide mb-1">{$locale === 'ar' ? 'رقم التواصل *' : 'Contact Number *'}</label>
                    <input 
                        id="customer-contact"
                        type="tel"
                        bind:value={customerContact}
                        placeholder={$locale === 'ar' ? 'أدخل رقم التواصل...' : 'Enter contact number...'}
                        class="w-full px-3 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-orange-500 focus:border-orange-500 outline-none text-sm hover:border-slate-300 transition"
                    />
                    {#if !customerContact.trim()}
                        <p class="text-xs text-red-600 mt-1">{$locale === 'ar' ? 'هذا الحقل مطلوب' : 'This field is required'}</p>
                    {/if}
                </div>
            </div>
        {/if}
        
        <!-- 3c. Other Incidents - Related Party Details -->
        {#if !violation && selectedIncidentType && incidentType !== 'IN2' && incidentType !== 'IN1' && incidentType !== 'IN9'}
            <div class="bg-purple-50 border border-purple-200 rounded-lg p-4">
                <div class="flex items-center gap-2 mb-2">
                    <span class="text-lg">📋</span>
                    <span class="text-sm font-bold text-purple-700">{$locale === 'ar' ? 'تفاصيل الطرف المعني' : 'Related Party Details'}</span>
                </div>
                <textarea 
                    id="related-party-details"
                    bind:value={relatedPartyDetails}
                    placeholder={$locale === 'ar' ? 'أدخل تفاصيل الطرف المعني (الاسم، رقم التواصل، أي معلومات أخرى)...' : 'Enter related party details (name, contact, any other information)...'}
                    rows="3"
                    class="w-full px-3 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500 outline-none text-sm resize-none"
                ></textarea>
            </div>
        {/if}
        
        <!-- 4. What Happened + Proof + Attachments (always shown when type selected - matching mobile flow) -->
        {#if selectedIncidentType || violation}
            <div class="space-y-3">
                <div>
                    <label for="what-happened" class="block text-xs font-bold text-slate-600 uppercase tracking-wide mb-1">{$locale === 'ar' ? 'ماذا حدث؟ *' : 'What Happened? *'}</label>
                    <textarea 
                        id="what-happened"
                        bind:value={whatHappened}
                        placeholder={$locale === 'ar' ? 'صف ما حدث...' : 'Describe what happened...'}
                        rows="3"
                        class="w-full px-3 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none text-sm resize-none"
                    ></textarea>
                    {#if !whatHappened.trim()}
                        <p class="text-xs text-red-600 mt-1">{$locale === 'ar' ? 'هذا الحقل مطلوب' : 'This field is required'}</p>
                    {/if}
                </div>
                <div>
                    <label for="proof-witness" class="block text-xs font-bold text-slate-600 uppercase tracking-wide mb-1">{$locale === 'ar' ? 'الإثبات / الشاهد' : 'Proof / Witness'}</label>
                    <textarea 
                        id="proof-witness"
                        bind:value={proofWitness}
                        placeholder={$locale === 'ar' ? 'أدخل تفاصيل الإثبات أو الشاهد...' : 'Enter proof or witness details...'}
                        rows="2"
                        class="w-full px-3 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none text-sm resize-none"
                    ></textarea>
                </div>
                
                <!-- Attachments Upload Section -->
                <div>
                    <label for="attachments-upload" class="block text-xs font-bold text-slate-600 uppercase tracking-wide mb-1">📎 {$locale === 'ar' ? 'المرفقات (اختياري - غير محدود)' : 'Attachments (Optional - Unlimited)'}</label>
                    <div class="flex gap-2">
                        <input 
                            id="attachments-upload"
                            type="file" 
                            accept="image/*,.pdf,.doc,.docx,.xls,.xlsx"
                            multiple
                            on:change={handleAttachmentSelect}
                            disabled={isUploadingAttachments}
                            class="flex-1 px-3 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none text-sm hover:border-slate-300 transition cursor-pointer disabled:opacity-50"
                        />
                        {#if attachments.length > 0}
                            <button 
                                type="button"
                                on:click={clearAllAttachments}
                                disabled={isUploadingAttachments}
                                class="px-3 py-2 bg-red-100 hover:bg-red-200 text-red-700 rounded-lg text-sm font-bold disabled:opacity-50 transition"
                            >
                                {$locale === 'ar' ? 'مسح الكل' : 'Clear All'}
                            </button>
                        {/if}
                    </div>
                    <p class="text-xs text-slate-500 mt-1">{$locale === 'ar' ? 'يمكنك رفع صور أو PDF أو مستندات (حد أقصى 10 ميجابايت لكل ملف)' : 'You can upload images, PDFs, or documents (max 10MB per file)'}</p>
                    
                    {#if attachments.length > 0}
                        <div class="mt-2 space-y-2">
                            <p class="text-xs font-bold text-green-600">✓ {attachments.length} {$locale === 'ar' ? 'ملف(ات) محددة' : 'file(s) selected'}</p>
                            <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-2">
                                {#each attachmentPreviews as preview, index}
                                    <div class="relative group border border-slate-200 rounded-lg overflow-hidden bg-slate-50">
                                        {#if preview.type === 'image' && preview.url}
                                            <img src={preview.url} alt="Preview" class="w-full h-24 object-cover" />
                                        {:else if preview.type === 'pdf'}
                                            <div class="w-full h-24 flex items-center justify-center bg-red-50">
                                                <span class="text-3xl">📄</span>
                                            </div>
                                        {:else}
                                            <div class="w-full h-24 flex items-center justify-center bg-blue-50">
                                                <span class="text-3xl">📁</span>
                                            </div>
                                        {/if}
                                        <div class="p-1 bg-white border-t">
                                            <p class="text-xs text-slate-600 truncate">{preview.file.name}</p>
                                            <p class="text-xs text-slate-400">{(preview.file.size / 1024).toFixed(1)} KB</p>
                                        </div>
                                        <button 
                                            type="button"
                                            on:click={() => removeAttachment(index)}
                                            class="absolute top-1 right-1 w-5 h-5 bg-red-500 hover:bg-red-600 text-white rounded-full text-xs flex items-center justify-center opacity-0 group-hover:opacity-100 transition"
                                        >×</button>
                                    </div>
                                {/each}
                            </div>
                        </div>
                    {/if}
                </div>
            </div>
        {/if}
    </div>

    <!-- Submit Button -->
    <div class="px-8 py-5 bg-white border-t-2 border-slate-200 flex gap-4 justify-end flex-shrink-0 shadow-lg">
        <button disabled={(!selectedEmployee && (violation || incidentType === 'IN2')) || !selectedBranch || !selectedIncidentType && !violation || isSaving} class="px-8 py-2.5 rounded-lg font-bold text-white bg-blue-600 hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition transform hover:scale-105 active:scale-95" on:click={handleReportIncident}>
            {isSaving ? ($locale === 'ar' ? 'جاري الحفظ...' : 'Saving...') : ($locale === 'ar' ? 'الإبلاغ عن الحادثة' : 'Report Incident')}
        </button>
    </div>
</div>

<style>
    :global(.font-sans) {
        font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    }
</style>
