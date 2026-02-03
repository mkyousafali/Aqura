<script lang="ts">
    import { _ as t } from '$lib/i18n';
    import { locale } from '$lib/i18n';
    import { onMount, onDestroy } from 'svelte';
    import { currentUser } from '$lib/utils/persistentAuth';
    import { openWindow } from '$lib/utils/windowManagerUtils';
    import IssueWarning from './IssueWarning.svelte';
    import Investigation from './Investigation.svelte';
    import Resolution from './Resolution.svelte';
    
    let incidents: any[] = [];
    let isLoading = true;
    let error: string | null = null;
    let supabase: any = null;
    let currentUserID: string | null = null;
    let currentUserName: string | null = null;
    let showAssignModal = false;
    let selectedIncident: any = null;
    let availableUsers: any[] = [];
    let selectedUserId: string | null = null;
    let isAssigning = false;
    let searchQuery = '';
    let filteredUsers: any[] = [];
    let showImagePreview = false;
    let previewImageUrl = '';
    let previewImageName = '';
    let realtimeSubscription: any = null;
    let showPendingUsersModal = false;
    let pendingUsersList: { name_en: string; name_ar: string }[] = [];
    
    // Filter state
    let filterIncidentType = '';
    let filterBranch = '';
    let filterEmployee = '';
    let filterReportedBy = '';
    let filterDateStart = '';
    let filterDateEnd = '';
    
    // Unique options for filters (derived from loaded incidents)
    $: incidentTypeOptions = [...new Map(incidents.map(i => [i.incident_types?.id, {
        id: i.incident_types?.id,
        name_en: i.incident_types?.incident_type_en,
        name_ar: i.incident_types?.incident_type_ar
    }])).values()].filter(o => o.id);
    
    $: branchOptions = [...new Map(incidents.map(i => [i.branch_id, {
        id: i.branch_id,
        name: i.branchName
    }])).values()].filter(o => o.id);
    
    $: employeeOptions = [...new Map(incidents.map(i => [i.employee_id, {
        id: i.employee_id,
        name: i.employeeName
    }])).values()].filter(o => o.id);
    
    $: reporterOptions = [...new Map(incidents.map(i => [i.created_by, {
        id: i.created_by,
        name: i.reporterName
    }])).values()].filter(o => o.id && o.name !== 'Unknown');
    
    // Filtered incidents
    $: filteredIncidents = incidents.filter(incident => {
        if (filterIncidentType && incident.incident_types?.id !== filterIncidentType) return false;
        if (filterBranch && incident.branch_id !== filterBranch) return false;
        if (filterEmployee && incident.employee_id !== filterEmployee) return false;
        if (filterReportedBy && incident.created_by !== filterReportedBy) return false;
        
        // Date range filter
        if (filterDateStart || filterDateEnd) {
            const incidentDate = new Date(incident.created_at).setHours(0, 0, 0, 0);
            if (filterDateStart) {
                const startDate = new Date(filterDateStart).setHours(0, 0, 0, 0);
                if (incidentDate < startDate) return false;
            }
            if (filterDateEnd) {
                const endDate = new Date(filterDateEnd).setHours(23, 59, 59, 999);
                if (incidentDate > endDate) return false;
            }
        }
        
        return true;
    });
    
    function clearFilters() {
        filterIncidentType = '';
        filterBranch = '';
        filterEmployee = '';
        filterReportedBy = '';
        filterDateStart = '';
        filterDateEnd = '';
    }
    
    async function loadIncidents() {
        try {
            isLoading = true;
            error = null;
            const mod = await import('$lib/utils/supabase');
            supabase = mod.supabase;
            
            // Get current user from store
            if ($currentUser && $currentUser.id) {
                currentUserID = $currentUser.id;
                currentUserName = $currentUser.employeeName || $currentUser.username;
                console.log('🔑 Current user from store:', currentUserID, currentUserName);
            } else {
                console.log('⚠️ No user in store');
            }
            
            // Fetch all incidents with related data
            const { data, error: fetchError } = await supabase
                .from('incidents')
                .select(`
                    id,
                    incident_type_id,
                    employee_id,
                    branch_id,
                    violation_id,
                    what_happened,
                    witness_details,
                    report_type,
                    reports_to_user_ids,
                    resolution_status,
                    resolution_report,
                    user_statuses,
                    attachments,
                    investigation_report,
                    created_at,
                    created_by,
                    incident_types(id, incident_type_en, incident_type_ar),
                    warning_violation(id, name_en, name_ar)
                `)
                .order('created_at', { ascending: false });
            
            if (fetchError) {
                throw new Error(`Fetch error: ${fetchError.message}`);
            }
            
            if (!data || data.length === 0) {
                incidents = [];
                isLoading = false;
                return;
            }
            
            // Enrich incidents with employee and branch names
            const enrichedIncidents = await Promise.all(
                data.map(async (incident) => {
                    let employeeName = 'Unknown';
                    let branchName = 'Unknown';
                    let reportToNames: any[] = [];
                    let incidentActions: any[] = [];
                    let reporterName = 'Unknown';
                    
                    try {
                        // Get employee name
                        const { data: empData } = await supabase
                            .from('hr_employee_master')
                            .select('name_en, name_ar')
                            .eq('id', incident.employee_id)
                            .single();
                        
                        if (empData) {
                            employeeName = $locale === 'ar' ? empData.name_ar : empData.name_en;
                        }
                    } catch (e) {
                        console.warn('Employee fetch error:', e);
                    }
                    
                    try {
                        // Get branch name and location
                        const { data: branchData } = await supabase
                            .from('branches')
                            .select('name_en, name_ar, location_en, location_ar')
                            .eq('id', incident.branch_id)
                            .single();
                        
                        if (branchData) {
                            const name = $locale === 'ar' ? branchData.name_ar : branchData.name_en;
                            const location = $locale === 'ar' ? branchData.location_ar : branchData.location_en;
                            branchName = `${name} - ${location}`;
                        }
                    } catch (e) {
                        console.warn('Branch fetch error:', e);
                    }
                    
                    try {
                        // Get user names and statuses for reports_to_user_ids
                        if (incident.reports_to_user_ids && Array.isArray(incident.reports_to_user_ids) && incident.reports_to_user_ids.length > 0) {
                            const { data: reportUsers } = await supabase
                                .from('hr_employee_master')
                                .select('user_id, name_en, name_ar')
                                .in('user_id', incident.reports_to_user_ids);
                            
                            if (reportUsers && reportUsers.length > 0) {
                                const userStatusesObj = typeof incident.user_statuses === 'string' 
                                    ? JSON.parse(incident.user_statuses) 
                                    : (incident.user_statuses || {});
                                
                                reportToNames = reportUsers.map((u: any) => {
                                    const name = $locale === 'ar' ? u.name_ar : u.name_en;
                                    const statusData = userStatusesObj[u.user_id] || {};
                                    return {
                                        name,
                                        userId: u.user_id,
                                        status: statusData.status || 'unknown'
                                    };
                                });
                            }
                        }
                    } catch (e) {
                        console.warn('Reports-to users fetch error:', e);
                    }
                    
                    try {
                        // Get incident actions (warnings, fines)
                        const { data: actionsData } = await supabase
                            .from('incident_actions')
                            .select('*')
                            .eq('incident_id', incident.id)
                            .order('created_at', { ascending: false });
                        
                        if (actionsData && actionsData.length > 0) {
                            incidentActions = actionsData;
                        }
                    } catch (e) {
                        console.warn('Incident actions fetch error:', e);
                    }
                    
                    try {
                        // Get reporter name (who created the incident)
                        if (incident.created_by) {
                            const { data: reporterData } = await supabase
                                .from('hr_employee_master')
                                .select('name_en, name_ar')
                                .eq('user_id', incident.created_by)
                                .single();
                            
                            if (reporterData) {
                                reporterName = $locale === 'ar' ? reporterData.name_ar : reporterData.name_en;
                            }
                        }
                    } catch (e) {
                        console.warn('Reporter fetch error:', e);
                    }
                    
                    return {
                        ...incident,
                        employeeName,
                        branchName,
                        reportToNames,
                        incidentActions,
                        reporterName
                    };
                })
            );
            
            incidents = enrichedIncidents;
            console.log('Loaded incidents:', enrichedIncidents);
        } catch (err) {
            console.error('Error loading incidents:', err);
            error = err instanceof Error ? err.message : 'Failed to load incidents';
        } finally {
            isLoading = false;
        }
    }
    
    function getStatusBadgeColor(status: string): string {
        switch (status) {
            case 'reported':
                return 'bg-blue-100 text-blue-800';
            case 'claimed':
                return 'bg-yellow-100 text-yellow-800';
            case 'resolved':
                return 'bg-green-100 text-green-800';
            default:
                return 'bg-gray-100 text-gray-800';
        }
    }
    
    function hasAnyAssignedUser(incident: any): boolean {
        if (!incident.user_statuses) return false;
        
        const userStatuses = typeof incident.user_statuses === 'string'
            ? JSON.parse(incident.user_statuses)
            : incident.user_statuses;
        
        return Object.values(userStatuses).some((status: any) => 
            status.status === 'Assigned' || status.status === 'acknowledged'
        );
    }
    
    function isClaimedByCurrentUser(incident: any): boolean {
        if (!currentUserID) return false;
        
        // Check if user is in reports_to_user_ids
        let reportsToIds = incident.reports_to_user_ids;
        if (typeof reportsToIds === 'string') {
            try {
                reportsToIds = JSON.parse(reportsToIds);
            } catch (e) {
                reportsToIds = [];
            }
        }
        const isInReportsTo = Array.isArray(reportsToIds) && reportsToIds.includes(currentUserID);
        
        // Check user_statuses for claimed status
        if (incident.user_statuses) {
            const userStatuses = typeof incident.user_statuses === 'string'
                ? JSON.parse(incident.user_statuses)
                : incident.user_statuses;
            
            const currentUserStatus = userStatuses[currentUserID];
            // Check for both 'claimed' and 'Claimed' (case-insensitive)
            if (currentUserStatus?.status?.toLowerCase() === 'claimed') {
                return true;
            }
        }
        
        // Also consider claimed if resolution_status is 'claimed' and user is in reports_to list
        if (incident.resolution_status === 'claimed' && isInReportsTo) {
            return true;
        }
        
        return false;
    }
    
    function hasWarningAction(incident: any): boolean {
        if (!incident.incidentActions || !Array.isArray(incident.incidentActions)) return false;
        return incident.incidentActions.some((a: any) => a.action_type === 'warning' || a.action_type === 'termination');
    }
    
    function getWarningAction(incident: any): any {
        if (!incident.incidentActions || !Array.isArray(incident.incidentActions)) return null;
        return incident.incidentActions.find((a: any) => a.action_type === 'warning' || a.action_type === 'termination');
    }
    
    async function toggleFinePaid(action: any) {
        try {
            const newPaidStatus = !action.is_paid;
            
            const { error } = await supabase
                .from('incident_actions')
                .update({
                    is_paid: newPaidStatus,
                    paid_at: newPaidStatus ? new Date().toISOString() : null,
                    paid_by: newPaidStatus ? currentUserID : null
                })
                .eq('id', action.id);
            
            if (error) {
                throw new Error(error.message);
            }
            
            // Reload incidents to reflect the change
            await loadIncidents();
            
            const message = newPaidStatus
                ? ($locale === 'ar' ? '✅ تم تسجيل الغرامة كمدفوعة' : '✅ Fine marked as paid')
                : ($locale === 'ar' ? 'تم إلغاء تسجيل الدفع' : 'Payment unmarked');
            alert(message);
        } catch (err) {
            console.error('Error updating fine status:', err);
            alert($locale === 'ar' ? 'خطأ في تحديث حالة الغرامة' : 'Error updating fine status');
        }
    }
    
    function formatDate(dateString: string): string {
        const date = new Date(dateString);
        return date.toLocaleDateString($locale === 'ar' ? 'ar-EG' : 'en-US', {
            year: 'numeric',
            month: 'short',
            day: 'numeric'
        });
    }
    
    async function handleClaimIncident(incident: any) {
        try {
            console.log('🔍 Claim button clicked');
            console.log('📌 Current User ID:', currentUserID);
            console.log('📋 Incident:', incident);
            console.log('👥 Reports To User IDs:', incident.reports_to_user_ids);
            
            // Parse reports_to_user_ids if it's a string
            let reportsToIds = incident.reports_to_user_ids;
            if (typeof reportsToIds === 'string') {
                try {
                    reportsToIds = JSON.parse(reportsToIds);
                } catch (e) {
                    console.warn('Failed to parse reports_to_user_ids as JSON:', e);
                }
            }
            
            console.log('✅ Parsed Reports To IDs:', reportsToIds);
            
            // Check if current user is in the reports_to_user_ids
            if (!reportsToIds || !Array.isArray(reportsToIds) || reportsToIds.length === 0) {
                console.log('❌ No reports_to_user_ids found or not an array');
                alert($locale === 'ar' ? 'لا يمكن مطالبة هذه الحادثة' : 'Cannot claim this incident');
                return;
            }
            
            const isAuthorized = reportsToIds.includes(currentUserID);
            console.log('🔐 Is authorized?', isAuthorized, 'IDs:', reportsToIds, 'Current:', currentUserID);
            
            if (!isAuthorized) {
                alert($locale === 'ar' ? 'أنت لست من المخولين بمطالبة هذه الحادثة' : 'You are not authorized to claim this incident');
                return;
            }
            
            // Update incident status to 'claimed'
            const userStatusesObj = typeof incident.user_statuses === 'string' 
                ? JSON.parse(incident.user_statuses) 
                : (incident.user_statuses || {});
            
            // Update current user's status to claimed
            userStatusesObj[currentUserID] = {
                ...userStatusesObj[currentUserID],
                status: 'claimed',
                claimed_at: new Date().toISOString()
            };
            
            const { error: updateError } = await supabase
                .from('incidents')
                .update({
                    resolution_status: 'claimed',
                    user_statuses: userStatusesObj
                })
                .eq('id', incident.id);
            
            if (updateError) {
                throw new Error(updateError.message);
            }
            
            // Create a quick task for the claiming user
            try {
                const incidentTypeName = $locale === 'ar' 
                    ? incident.incident_types?.incident_type_ar 
                    : incident.incident_types?.incident_type_en;
                
                const { data: quickTaskData, error: taskError } = await supabase
                    .from('quick_tasks')
                    .insert({
                        title: $locale === 'ar' 
                            ? `متابعة الحادثة #${incident.id}` 
                            : `Follow up Incident #${incident.id}`,
                        description: $locale === 'ar'
                            ? `تم مطالبتك بمتابعة الحادثة #${incident.id} (${incidentTypeName}). يرجى التحقيق واتخاذ الإجراء المناسب. لا يمكن إغلاق هذه المهمة حتى يتم حل الحادثة.`
                            : `You have claimed incident #${incident.id} (${incidentTypeName}). Please investigate and take appropriate action. This task cannot be closed until the incident is resolved.`,
                        issue_type: 'incident_followup',
                        priority: 'high',
                        assigned_by: currentUserID,
                        incident_id: incident.id,
                        status: 'pending',
                        deadline_datetime: new Date(Date.now() + 3 * 24 * 60 * 60 * 1000).toISOString() // 3 days deadline
                    })
                    .select()
                    .single();
                
                if (taskError) {
                    console.warn('Failed to create quick task:', taskError);
                } else {
                    // Create assignment for the claiming user
                    const { error: assignmentError } = await supabase
                        .from('quick_task_assignments')
                        .insert({
                            quick_task_id: quickTaskData.id,
                            assigned_to_user_id: currentUserID,
                            require_task_finished: true,
                            require_photo_upload: false,
                            require_erp_reference: false
                        });
                    
                    if (assignmentError) {
                        console.warn('Failed to create task assignment:', assignmentError);
                    } else {
                        console.log('✅ Quick task created for claiming user:', quickTaskData.id);
                    }
                }
            } catch (taskErr) {
                console.warn('Error creating quick task:', taskErr);
                // Don't fail the claim if task creation fails
            }
            
            // Reload incidents
            await loadIncidents();
            alert($locale === 'ar' ? 'تم مطالبة الحادثة بنجاح' : 'Incident claimed successfully');
        } catch (err) {
            console.error('Error claiming incident:', err);
            alert($locale === 'ar' ? 'خطأ في مطالبة الحادثة' : 'Error claiming incident');
        }
    }
    
    async function handleResolveIncident(incident: any) {
        try {
            // First, check if there are any pending quick_tasks for this incident
            const { data: pendingTasks, error: taskError } = await supabase
                .from('quick_tasks')
                .select(`
                    id,
                    status,
                    quick_task_assignments (
                        id,
                        assigned_to_user_id,
                        status
                    )
                `)
                .eq('incident_id', incident.id)
                .neq('status', 'completed');
            
            if (taskError) {
                console.error('Error checking tasks:', taskError);
            }
            
            console.log('🔍 Checking pending tasks for incident:', incident.id, pendingTasks);
            
            // Check for users who haven't completed their tasks
            const pendingUsers: { name_en: string; name_ar: string }[] = [];
            
            if (pendingTasks && pendingTasks.length > 0) {
                for (const task of pendingTasks) {
                    const assignments = task.quick_task_assignments || [];
                    for (const assignment of assignments) {
                        // If assignment status is not 'completed'
                        if (assignment.status !== 'completed') {
                            // Get user name from users table with hr_employee_master join
                            try {
                                const { data: userData } = await supabase
                                    .from('users')
                                    .select(`
                                        id,
                                        username,
                                        hr_employee_master (
                                            name_en,
                                            name_ar
                                        )
                                    `)
                                    .eq('id', assignment.assigned_to_user_id)
                                    .single();
                                
                                if (userData) {
                                    const empData = userData.hr_employee_master;
                                    const userObj = {
                                        name_en: empData?.name_en || userData.username,
                                        name_ar: empData?.name_ar || userData.username
                                    };
                                    // Check if already added
                                    if (!pendingUsers.some(u => u.name_en === userObj.name_en)) {
                                        pendingUsers.push(userObj);
                                    }
                                } else {
                                    pendingUsers.push({ name_en: assignment.assigned_to_user_id, name_ar: assignment.assigned_to_user_id });
                                }
                            } catch {
                                pendingUsers.push({ name_en: assignment.assigned_to_user_id, name_ar: assignment.assigned_to_user_id });
                            }
                        }
                    }
                }
            }
            
            // Also check user_statuses for any 'Assigned' status
            const userStatuses = typeof incident.user_statuses === 'string'
                ? JSON.parse(incident.user_statuses || '{}')
                : (incident.user_statuses || {});
            
            console.log('🔍 Checking user_statuses:', userStatuses);
            
            for (const [userId, statusObj] of Object.entries(userStatuses)) {
                const status = (statusObj as any)?.status;
                // If user is assigned but not acknowledged/completed, add to pending list
                if (status === 'Assigned') {
                    // Get user name from users table with hr_employee_master join
                    try {
                        const { data: userData } = await supabase
                            .from('users')
                            .select(`
                                id,
                                username,
                                hr_employee_master (
                                    name_en,
                                    name_ar
                                )
                            `)
                            .eq('id', userId)
                            .single();
                        
                        if (userData) {
                            const empData = userData.hr_employee_master;
                            const userObj = {
                                name_en: empData?.name_en || userData.username,
                                name_ar: empData?.name_ar || userData.username
                            };
                            // Check if already added
                            if (!pendingUsers.some(u => u.name_en === userObj.name_en)) {
                                pendingUsers.push(userObj);
                            }
                        } else if (!pendingUsers.some(u => u.name_en === userId)) {
                            pendingUsers.push({ name_en: userId, name_ar: userId });
                        }
                    } catch {
                        if (!pendingUsers.some(u => u.name_en === userId)) {
                            pendingUsers.push({ name_en: userId, name_ar: userId });
                        }
                    }
                }
            }
            
            console.log('🔍 Pending users:', pendingUsers);
            
            // If there are pending users, show modal
            if (pendingUsers.length > 0) {
                pendingUsersList = pendingUsers;
                showPendingUsersModal = true;
                return;
            }
            
            // Open Resolution window
            openResolutionModal(incident);
            
        } catch (err) {
            console.error('Error checking tasks:', err);
            alert($locale === 'ar' ? 'خطأ في التحقق من المهام' : 'Error checking tasks');
        }
    }
    
    function openResolutionModal(incident: any) {
        const hasResolution = incident.resolution_status === 'resolved';
        const windowId = `resolution-incident-${Date.now()}`;
        openWindow({
            id: windowId,
            title: hasResolution
                ? ($locale === 'ar' ? `عرض تقرير الحل - حادثة #${incident.id}` : `View Resolution - Incident #${incident.id}`)
                : ($locale === 'ar' ? `حل الحادثة - #${incident.id}` : `Resolve Incident - #${incident.id}`),
            component: Resolution,
            icon: hasResolution ? '📋' : '✅',
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
                incident: incident,
                viewMode: hasResolution,
                onResolved: () => loadIncidents()
            }
        });
    }

    function openInvestigationModal(incident: any) {
        const hasInvestigation = !!incident.investigation_report;
        const windowId = `investigation-incident-${Date.now()}`;
        openWindow({
            id: windowId,
            title: hasInvestigation
                ? ($locale === 'ar' ? `عرض التحقيق - حادثة #${incident.id}` : `View Investigation - Incident #${incident.id}`)
                : `Investigation - Incident #${incident.id}`,
            component: Investigation,
            icon: hasInvestigation ? '📋' : '🔍',
            size: { width: 900, height: 650 },
            position: { 
                x: 150 + (Math.random() * 50),
                y: 150 + (Math.random() * 50) 
            },
            resizable: true,
            minimizable: true,
            maximizable: true,
            closable: true,
            props: {
                violation: incident.warning_violation,
                incident: incident,
                viewMode: hasInvestigation,
                employees: incidents.reduce((empList: any[], inc) => {
                    const existingEmp = empList.find(e => e.id === inc.employee_id);
                    if (!existingEmp && inc.employeeName) {
                        empList.push({
                            id: inc.employee_id,
                            name_en: inc.employeeName,
                            name_ar: inc.employeeName
                        });
                    }
                    return empList;
                }, []),
                employeeId: incident.employee_id,
                branchId: incident.branch_id,
                branchName: incident.branch_name
            }
        });
    }
    
    function openWarningModal(incident: any) {
        const existingWarning = getWarningAction(incident);
        const isViewMode = !!existingWarning;
        
        const windowId = `issue-warning-incident-${Date.now()}`;
        openWindow({
            id: windowId,
            title: isViewMode 
                ? ($locale === 'ar' ? `عرض التحذير - حادثة #${incident.id}` : `View Warning - Incident #${incident.id}`)
                : ($locale === 'ar' ? `إصدار تحذير - حادثة #${incident.id}` : `Issue Warning - Incident #${incident.id}`),
            component: IssueWarning,
            icon: isViewMode ? '📋' : '⚠️',
            size: { width: 900, height: 650 },
            position: { 
                x: 150 + (Math.random() * 50),
                y: 150 + (Math.random() * 50) 
            },
            resizable: true,
            minimizable: true,
            maximizable: true,
            closable: true,
            props: {
                violation: incident.warning_violation,
                incident: incident,
                employees: incidents.reduce((empList: any[], inc) => {
                    const existingEmp = empList.find(e => e.id === inc.employee_id);
                    if (!existingEmp && inc.employeeName) {
                        empList.push({
                            id: inc.employee_id,
                            name_en: inc.employeeName,
                            name_ar: inc.employeeName
                        });
                    }
                    return empList;
                }, []),
                employeeId: incident.employee_id,
                branchId: incident.branch_id,
                branchName: incident.branchName,
                viewMode: isViewMode,
                savedAction: existingWarning
            }
        });
    }
    
    async function openAssignModal(incident: any) {
        try {
            selectedIncident = incident;
            selectedUserId = null;
            availableUsers = [];
            
            // Fetch all users with their employee details
            const { data, error: fetchError } = await supabase
                .from('users')
                .select(`
                    id,
                    username,
                    hr_employee_master (
                        name_en,
                        name_ar
                    )
                `)
                .order('username', { ascending: true });
            
            if (fetchError) {
                console.error('Supabase fetch error:', fetchError);
                throw new Error(fetchError.message);
            }
            
            // Map users with employee names
            availableUsers = (data || []).map((user: any) => ({
                user_id: user.id,
                name_en: user.hr_employee_master?.name_en || user.username,
                name_ar: user.hr_employee_master?.name_ar || user.username,
                email: user.username
            }));
            
            console.log('📋 Available users:', availableUsers);
            showAssignModal = true;
        } catch (err) {
            console.error('Error loading users:', err);
            alert($locale === 'ar' ? 'خطأ في تحميل المستخدمين' : 'Error loading users');
        }
    }
    
    async function assignTask() {
        try {
            if (!selectedUserId || !selectedIncident) {
                alert($locale === 'ar' ? 'الرجاء اختيار مستخدم' : 'Please select a user');
                return;
            }
            
            isAssigning = true;
            
            // Create quick task for recovery
            const { data: quickTaskData, error: taskError } = await supabase
                .from('quick_tasks')
                .insert({
                    title: $locale === 'ar' ? 'استرجاع الحادثة' : 'Incident Recovery',
                    description: $locale === 'ar' 
                        ? `تم تعيينك لاسترجاع الحادثة #${selectedIncident.id} بواسطة ${currentUserName}`
                        : `You have been assigned to recover incident #${selectedIncident.id} by ${currentUserName}`,
                    issue_type: 'incident_recovery',
                    priority: 'high',
                    assigned_by: currentUserID,
                    incident_id: selectedIncident.id,
                    status: 'pending',
                    deadline_datetime: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString()
                })
                .select()
                .single();
            
            if (taskError) {
                console.error('Task creation error:', taskError);
                throw new Error(taskError.message);
            }
            
            // Create assignment for the selected user in quick_task_assignments
            const { error: assignmentError } = await supabase
                .from('quick_task_assignments')
                .insert({
                    quick_task_id: quickTaskData.id,
                    assigned_to_user_id: selectedUserId,
                    require_task_finished: true,
                    require_photo_upload: false,
                    require_erp_reference: false
                });
            
            if (assignmentError) {
                console.error('Assignment creation error:', assignmentError);
                throw new Error(assignmentError.message);
            }
            
            // Add user to reports_to_user_ids if not already there
            const reportsToIds = Array.isArray(selectedIncident.reports_to_user_ids) 
                ? [...selectedIncident.reports_to_user_ids]
                : [];
            
            if (!reportsToIds.includes(selectedUserId)) {
                reportsToIds.push(selectedUserId);
            }
            
            // Update user_statuses to set assigned user's status to 'Assigned'
            const userStatuses = typeof selectedIncident.user_statuses === 'string'
                ? JSON.parse(selectedIncident.user_statuses || '{}')
                : (selectedIncident.user_statuses || {});
            
            userStatuses[selectedUserId] = {
                ...userStatuses[selectedUserId],
                status: 'Assigned',
                assigned_at: new Date().toISOString()
            };
            
            // Update incident with new reports_to_user_ids, user_statuses, and status 'claimed'
            const { error: updateError } = await supabase
                .from('incidents')
                .update({
                    reports_to_user_ids: reportsToIds,
                    user_statuses: userStatuses,
                    resolution_status: 'claimed'
                })
                .eq('id', selectedIncident.id);
            
            if (updateError) {
                throw new Error(updateError.message);
            }
            
            // Send notification
            const notificationMessage = $locale === 'ar'
                ? `تم تعيينك لاسترجاع الحادثة #${selectedIncident.id} بواسطة ${currentUserName}`
                : `You have been assigned to recover incident #${selectedIncident.id} by ${currentUserName}`;
            
            await supabase
                .from('notifications')
                .insert({
                    title: $locale === 'ar' ? 'تعيين مهمة جديدة' : 'New Task Assignment',
                    message: notificationMessage,
                    type: 'info',
                    priority: 'normal',
                    target_type: 'specific_users',
                    target_users: [selectedUserId],
                    created_at: new Date().toISOString()
                });
            
            showAssignModal = false;
            
            // Update the incident in the incidents array and trigger reactivity
            const updatedIncidents = incidents.map(inc => 
                inc.id === selectedIncident.id 
                    ? {
                        ...inc,
                        resolution_status: 'claimed',
                        reports_to_user_ids: reportsToIds,
                        user_statuses: userStatuses
                      }
                    : inc
            );
            incidents = updatedIncidents;
            
            alert($locale === 'ar' ? 'تم تعيين المهمة بنجاح' : 'Task assigned successfully');
            
            // Reload incidents in the background
            setTimeout(() => loadIncidents(), 500);
        } catch (err) {
            console.error('Error assigning task:', err);
            alert($locale === 'ar' ? 'خطأ في تعيين المهمة' : 'Error assigning task');
        } finally {
            isAssigning = false;
        }
    }
    
    function closeAssignModal() {
        showAssignModal = false;
        selectedIncident = null;
        selectedUserId = null;
        availableUsers = [];
        searchQuery = '';
        filteredUsers = [];
    }
    
    function handleSearchInput(e: Event) {
        const query = (e.target as HTMLInputElement).value.toLowerCase();
        searchQuery = query;
        
        if (!query) {
            filteredUsers = availableUsers;
        } else {
            filteredUsers = availableUsers.filter(user =>
                user.name_en?.toLowerCase().includes(query) ||
                user.name_ar?.toLowerCase().includes(query) ||
                user.username?.toLowerCase().includes(query)
            );
        }
    }
    
    function selectUser(user: any) {
        selectedUserId = user.user_id;
        searchQuery = $locale === 'ar' ? user.name_ar : user.name_en;
        filteredUsers = [];
    }
    
    function handleAttachmentClick(attachment: any) {
        if (attachment.type === 'image') {
            // Show image preview modal
            previewImageUrl = attachment.url;
            previewImageName = attachment.name || 'Image';
            showImagePreview = true;
        } else {
            // Download/open file in new tab
            window.open(attachment.url, '_blank');
        }
    }
    
    function closeImagePreview() {
        showImagePreview = false;
        previewImageUrl = '';
        previewImageName = '';
    }
    
    onMount(async () => {
        await loadIncidents();
        setupRealtime();
    });
    
    function setupRealtime() {
        if (!supabase) {
            console.log('⚠️ Supabase not initialized, cannot set up realtime');
            return;
        }
        
        console.log('🔄 Setting up realtime subscription for incidents and incident_actions...');
        realtimeSubscription = supabase.channel('incidents-realtime')
            .on('postgres_changes', { event: '*', schema: 'public', table: 'incidents' }, (payload: any) => {
                console.log('🔔 Incidents realtime update:', payload.eventType, payload);
                loadIncidents();
            })
            .on('postgres_changes', { event: '*', schema: 'public', table: 'incident_actions' }, (payload: any) => {
                console.log('🔔 Incident actions realtime update:', payload.eventType, payload);
                loadIncidents();
            })
            .subscribe((status: string) => {
                console.log('📡 Realtime subscription status:', status);
            });
    }
    
    onDestroy(() => {
        // Clean up realtime subscription
        if (realtimeSubscription && supabase) {
            supabase.removeChannel(realtimeSubscription);
            console.log('🔌 Realtime subscription cleaned up');
        }
    });
</script>

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
    <!-- Header/Navigation -->
    <div class="bg-white border-b border-slate-200 px-6 py-4 flex items-center justify-between shadow-sm">
        <div class="flex flex-wrap items-center gap-4">
            <!-- Incident Type Filter -->
            <div class="flex flex-col">
                <label class="text-xs font-medium text-slate-500 mb-1">{$locale === 'ar' ? 'نوع الحادثة' : 'Incident Type'}</label>
                <select
                    bind:value={filterIncidentType}
                    class="px-3 py-2 text-sm border border-slate-200 rounded-lg bg-white focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 min-w-[160px] shadow-sm transition-all"
                >
                    <option value="">{$locale === 'ar' ? 'الكل' : 'All'}</option>
                    {#each incidentTypeOptions as opt}
                        <option value={opt.id}>{$locale === 'ar' ? opt.name_ar : opt.name_en}</option>
                    {/each}
                </select>
            </div>
            
            <!-- Branch Filter -->
            <div class="flex flex-col">
                <label class="text-xs font-medium text-slate-500 mb-1">{$locale === 'ar' ? 'الفرع' : 'Branch'}</label>
                <select
                    bind:value={filterBranch}
                    class="px-3 py-2 text-sm border border-slate-200 rounded-lg bg-white focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 min-w-[160px] shadow-sm transition-all"
                >
                    <option value="">{$locale === 'ar' ? 'الكل' : 'All'}</option>
                    {#each branchOptions as opt}
                        <option value={opt.id}>{opt.name}</option>
                    {/each}
                </select>
            </div>
            
            <!-- Employee Filter -->
            <div class="flex flex-col">
                <label class="text-xs font-medium text-slate-500 mb-1">{$locale === 'ar' ? 'الموظف' : 'Employee'}</label>
                <select
                    bind:value={filterEmployee}
                    class="px-3 py-2 text-sm border border-slate-200 rounded-lg bg-white focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 min-w-[160px] shadow-sm transition-all"
                >
                    <option value="">{$locale === 'ar' ? 'الكل' : 'All'}</option>
                    {#each employeeOptions as opt}
                        <option value={opt.id}>{opt.name}</option>
                    {/each}
                </select>
            </div>
            
            <!-- Reported By Filter -->
            <div class="flex flex-col">
                <label class="text-xs font-medium text-slate-500 mb-1">{$locale === 'ar' ? 'أبلغ بواسطة' : 'Reported By'}</label>
                <select
                    bind:value={filterReportedBy}
                    class="px-3 py-2 text-sm border border-slate-200 rounded-lg bg-white focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 min-w-[160px] shadow-sm transition-all"
                >
                    <option value="">{$locale === 'ar' ? 'الكل' : 'All'}</option>
                    {#each reporterOptions as opt}
                        <option value={opt.id}>{opt.name}</option>
                    {/each}
                </select>
            </div>
            
            <!-- Date Range Filter -->
            <div class="flex flex-col">
                <label class="text-xs font-medium text-slate-500 mb-1">{$locale === 'ar' ? 'من تاريخ' : 'From Date'}</label>
                <input
                    type="date"
                    bind:value={filterDateStart}
                    class="px-3 py-2 text-sm border border-slate-200 rounded-lg bg-white focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 min-w-[140px] shadow-sm transition-all"
                />
            </div>
            
            <div class="flex flex-col">
                <label class="text-xs font-medium text-slate-500 mb-1">{$locale === 'ar' ? 'إلى تاريخ' : 'To Date'}</label>
                <input
                    type="date"
                    bind:value={filterDateEnd}
                    class="px-3 py-2 text-sm border border-slate-200 rounded-lg bg-white focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 min-w-[140px] shadow-sm transition-all"
                />
            </div>
            
            <!-- Clear Filters Button -->
            <div class="flex flex-col">
                <label class="text-xs text-transparent mb-1">Clear</label>
                <button
                    on:click={clearFilters}
                    class="px-4 py-2 bg-slate-100 text-slate-600 text-sm rounded-lg hover:bg-slate-200 transition-all flex items-center gap-2 font-medium shadow-sm"
                    title={$locale === 'ar' ? 'مسح الفلاتر' : 'Clear Filters'}
                >
                    <span>✕</span>
                    {$locale === 'ar' ? 'مسح' : 'Clear'}
                </button>
            </div>
        </div>
        
        <!-- Refresh Button -->
        <button
            on:click={loadIncidents}
            disabled={isLoading}
            class="px-5 py-2.5 bg-gradient-to-r from-emerald-500 to-teal-500 text-white text-sm rounded-lg hover:from-emerald-600 hover:to-teal-600 transition-all disabled:from-gray-400 disabled:to-gray-400 disabled:cursor-not-allowed flex items-center gap-2 font-semibold shadow-md hover:shadow-lg"
            title={$locale === 'ar' ? 'تحديث' : 'Refresh'}
        >
            <span class={isLoading ? 'animate-spin' : ''}>🔄</span>
            {$locale === 'ar' ? 'تحديث' : 'Refresh'}
        </button>
    </div>
    
    <!-- Main Content Area -->
    <div class="flex-1 p-6 relative overflow-y-auto bg-[radial-gradient(ellipse_at_top_right,_var(--tw-gradient-stops))] from-white via-slate-50/50 to-slate-100/50">
    
    {#if isLoading}
        <div class="flex items-center justify-center flex-1">
            <div class="text-center bg-white/80 backdrop-blur-sm rounded-2xl p-10 shadow-lg">
                <div class="w-16 h-16 mx-auto mb-4 bg-gradient-to-br from-emerald-400 to-teal-500 rounded-full flex items-center justify-center animate-pulse">
                    <span class="text-3xl">📋</span>
                </div>
                <p class="text-slate-600 font-medium">{$locale === 'ar' ? 'جاري التحميل...' : 'Loading incidents...'}</p>
            </div>
        </div>
    {:else if error}
        <div class="bg-red-50/80 backdrop-blur-sm border border-red-200 rounded-xl p-6 mb-4 shadow-lg">
            <div class="flex items-center gap-3 mb-3">
                <div class="w-10 h-10 bg-red-100 rounded-full flex items-center justify-center">
                    <span class="text-xl">⚠️</span>
                </div>
                <p class="text-red-800 font-semibold">{$locale === 'ar' ? 'خطأ' : 'Error'}: {error}</p>
            </div>
            <button 
                on:click={loadIncidents}
                class="px-5 py-2.5 bg-gradient-to-r from-red-500 to-red-600 text-white rounded-lg hover:from-red-600 hover:to-red-700 font-medium shadow-md transition-all"
            >
                {$locale === 'ar' ? 'إعادة محاولة' : 'Retry'}
            </button>
        </div>
    {:else if incidents.length === 0}
        <div class="flex items-center justify-center flex-1">
            <div class="text-center bg-white/80 backdrop-blur-sm rounded-2xl p-10 shadow-lg">
                <div class="w-20 h-20 mx-auto mb-4 bg-gradient-to-br from-slate-200 to-slate-300 rounded-full flex items-center justify-center">
                    <span class="text-4xl">📭</span>
                </div>
                <p class="text-slate-600 text-lg font-medium">{$locale === 'ar' ? 'لا توجد حوادث مسجلة' : 'No incidents found'}</p>
            </div>
        </div>
    {:else}
        <div class="bg-white rounded-xl shadow-lg overflow-hidden flex-1 overflow-y-auto border border-slate-200/50">
            <table class="w-full">
                <thead class="bg-gradient-to-r from-slate-100 to-slate-50 sticky top-0 border-b border-slate-200">
                    <tr>
                        <th class="px-4 py-3 text-left text-sm font-semibold text-slate-700">
                            {$locale === 'ar' ? 'رقم التقرير' : 'Report ID'}
                        </th>
                        <th class="px-4 py-3 text-left text-sm font-semibold text-slate-700">
                            {$locale === 'ar' ? 'نوع الحادثة' : 'Incident Type'}
                        </th>
                        <th class="px-4 py-3 text-left text-sm font-semibold text-slate-700">
                            {$locale === 'ar' ? 'الموظف' : 'Employee'}
                        </th>
                        <th class="px-4 py-3 text-left text-sm font-semibold text-slate-700">
                            {$locale === 'ar' ? 'الفرع' : 'Branch'}
                        </th>
                        <th class="px-4 py-3 text-left text-sm font-semibold text-slate-700">
                            {$locale === 'ar' ? 'الانتهاك' : 'Violation'}
                        </th>
                        <th class="px-4 py-3 text-left text-sm font-semibold text-slate-700">
                            {$locale === 'ar' ? 'مُبلّغ إلى' : 'Reports To'}
                        </th>
                        <th class="px-4 py-3 text-left text-sm font-semibold text-slate-700">
                            {$locale === 'ar' ? 'الحالة' : 'Status'}
                        </th>
                        <th class="px-4 py-3 text-left text-sm font-semibold text-slate-700">
                            {$locale === 'ar' ? 'المرفقات' : 'Attachments'}
                        </th>
                        <th class="px-4 py-3 text-left text-sm font-semibold text-slate-700">
                            {$locale === 'ar' ? 'الغرامة' : 'Fine'}
                        </th>
                        <th class="px-4 py-3 text-left text-sm font-semibold text-slate-700">
                            {$locale === 'ar' ? 'التاريخ' : 'Date'}
                        </th>
                        <th class="px-4 py-3 text-left text-sm font-semibold text-slate-700">
                            {$locale === 'ar' ? 'أبلغ بواسطة' : 'Reported By'}
                        </th>
                        <th class="px-4 py-3 text-left text-sm font-semibold text-slate-700">
                            {$locale === 'ar' ? 'الإجراءات' : 'Actions'}
                        </th>
                    </tr>
                </thead>
                <tbody>
                    {#each filteredIncidents as incident (incident.id)}
                        <tr class="hover:bg-gradient-to-r hover:from-emerald-50/30 hover:to-teal-50/30 transition-all duration-200">
                            <td class="px-4 py-3.5">
                                <span class="inline-flex items-center px-2.5 py-1 rounded-lg bg-gradient-to-r from-emerald-50 to-teal-50 text-emerald-700 font-mono text-sm font-semibold border border-emerald-200/50">
                                    #{incident.id}
                                </span>
                            </td>
                            <td class="px-4 py-3.5 text-sm text-slate-700 font-medium">
                                {$locale === 'ar' 
                                    ? incident.incident_types?.incident_type_ar 
                                    : incident.incident_types?.incident_type_en}
                            </td>
                            <td class="px-4 py-3.5 text-sm text-slate-700 font-medium">
                                {incident.employeeName}
                            </td>
                            <td class="px-4 py-3.5 text-sm text-slate-600">
                                {incident.branchName}
                            </td>
                            <td class="px-4 py-3.5 text-sm text-slate-700">
                                {$locale === 'ar' 
                                    ? incident.warning_violation?.name_ar 
                                    : incident.warning_violation?.name_en}
                            </td>
                            <td class="px-4 py-3.5 text-sm text-slate-700">
                                {#if incident.reportToNames && incident.reportToNames.length > 0}
                                    <div class="space-y-2">
                                        {#each incident.reportToNames as user}
                                            <div class="flex items-center gap-2">
                                                <span class="text-sm font-medium text-slate-700">{user.name}</span>
                                                <span class="text-xs px-2 py-1 rounded {user.status === 'reported' ? 'bg-blue-100 text-blue-800' : user.status === 'claimed' ? 'bg-yellow-100 text-yellow-800' : user.status === 'resolved' ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-800'}">
                                                    {$locale === 'ar'
                                                        ? user.status === 'reported' ? 'مبلغ عنه'
                                                        : user.status === 'claimed' ? 'مطالب به'
                                                        : user.status === 'resolved' ? 'تم حله'
                                                        : user.status
                                                        : user.status.charAt(0).toUpperCase() + user.status.slice(1)}
                                                </span>
                                            </div>
                                        {/each}
                                    </div>
                                {:else}
                                    <span class="text-slate-400 italic">{$locale === 'ar' ? 'لا أحد' : 'None'}</span>
                                {/if}
                            </td>
                            <td class="px-4 py-3.5 text-sm">
                                <span class="px-2.5 py-1.5 rounded-full text-xs font-semibold shadow-sm {getStatusBadgeColor(incident.resolution_status)}">
                                    {$locale === 'ar'
                                        ? incident.resolution_status === 'reported' ? 'مبلغ عنه'
                                        : incident.resolution_status === 'claimed' ? 'مطالب به'
                                        : incident.resolution_status === 'resolved' ? 'تم حله'
                                        : incident.resolution_status
                                        : incident.resolution_status.charAt(0).toUpperCase() + incident.resolution_status.slice(1)}
                                </span>
                            </td>
                            <td class="px-4 py-3.5 text-sm">
                                {#if incident.attachments && Array.isArray(incident.attachments) && incident.attachments.length > 0}
                                    <div class="flex flex-wrap gap-1.5">
                                        {#each incident.attachments as attachment, idx}
                                            <button
                                                type="button"
                                                on:click={() => handleAttachmentClick(attachment)}
                                                class="inline-flex items-center gap-1 px-2.5 py-1.5 rounded-lg text-xs font-medium transition-all shadow-sm {attachment.type === 'image' ? 'bg-gradient-to-r from-blue-50 to-indigo-50 text-blue-700 hover:from-blue-100 hover:to-indigo-100 border border-blue-200/50' : 'bg-gradient-to-r from-slate-50 to-slate-100 text-slate-700 hover:from-slate-100 hover:to-slate-200 border border-slate-200/50'}"
                                                title={attachment.name || (attachment.type === 'image' ? 'Image' : 'File')}
                                            >
                                                <span>{attachment.type === 'image' ? '🖼️' : attachment.type === 'pdf' ? '📄' : '📁'}</span>
                                                <span class="max-w-16 truncate">{idx + 1}</span>
                                            </button>
                                        {/each}
                                    </div>
                                {:else}
                                    <span class="text-slate-400 italic text-xs">{$locale === 'ar' ? 'لا مرفقات' : 'None'}</span>
                                {/if}
                            </td>
                            <td class="px-4 py-3.5 text-sm">
                                {#if incident.incidentActions && incident.incidentActions.length > 0}
                                    {#each incident.incidentActions.filter((a: any) => a.has_fine) as action}
                                        <div class="flex flex-col gap-1">
                                            <div class="flex items-center gap-2">
                                                <span class="text-red-600 font-semibold">
                                                    {action.fine_amount > 0 ? `${action.fine_amount} SAR` : `${action.fine_threat_amount} SAR ⚠️`}
                                                </span>
                                            </div>
                                            <label class="flex items-center gap-1 cursor-pointer">
                                                <input
                                                    type="checkbox"
                                                    checked={action.is_paid}
                                                    on:change={() => toggleFinePaid(action)}
                                                    class="w-4 h-4 rounded border-gray-300 text-green-600 focus:ring-green-500"
                                                />
                                                <span class="text-xs {action.is_paid ? 'text-green-600' : 'text-red-500'}">
                                                    {action.is_paid 
                                                        ? ($locale === 'ar' ? 'مدفوعة ✓' : 'Paid ✓')
                                                        : ($locale === 'ar' ? 'غير مدفوعة' : 'Unpaid')}
                                                </span>
                                            </label>
                                        </div>
                                    {/each}
                                    {#if !incident.incidentActions.some((a: any) => a.has_fine)}
                                        <span class="text-slate-400 italic text-xs">{$locale === 'ar' ? 'لا غرامة' : 'No fine'}</span>
                                    {/if}
                                {:else}
                                    <span class="text-slate-400 italic text-xs">{$locale === 'ar' ? 'لا غرامة' : 'No fine'}</span>
                                {/if}
                            </td>
                            <td class="px-4 py-3.5 text-sm text-slate-600 font-medium">
                                {formatDate(incident.created_at)}
                            </td>
                            <td class="px-4 py-3.5 text-sm text-slate-700 font-medium">
                                {incident.reporterName || '-'}
                            </td>
                            <td class="px-4 py-3.5 text-sm">
                                <div class="flex flex-wrap gap-1.5">
                                    <button
                                        on:click={() => handleClaimIncident(incident)}
                                        disabled={incident.resolution_status === 'claimed' || incident.resolution_status === 'resolved'}
                                        class="px-3 py-1.5 bg-gradient-to-r from-blue-500 to-blue-600 text-white text-xs rounded-lg hover:from-blue-600 hover:to-blue-700 transition-all shadow-sm hover:shadow disabled:from-gray-300 disabled:to-gray-400 disabled:cursor-not-allowed font-medium"
                                        title={$locale === 'ar' ? 'مطالبة بالحادثة' : 'Claim incident'}
                                    >
                                        {$locale === 'ar' ? 'مطالبة' : 'Claim'}
                                    </button>
                                    <button
                                        on:click={() => openAssignModal(incident)}
                                        disabled={!isClaimedByCurrentUser(incident) || hasAnyAssignedUser(incident) || !!incident.investigation_report}
                                        class="px-3 py-1.5 bg-gradient-to-r from-emerald-500 to-emerald-600 text-white text-xs rounded-lg hover:from-emerald-600 hover:to-emerald-700 transition-all shadow-sm hover:shadow disabled:from-gray-300 disabled:to-gray-400 disabled:cursor-not-allowed font-medium"
                                        title={$locale === 'ar' ? 'تعيين مهمة' : 'Assign task'}
                                    >
                                        {$locale === 'ar' ? 'تعيين' : 'Assign'}
                                    </button>
                                    <button
                                        on:click={() => openInvestigationModal(incident)}
                                        disabled={!incident.investigation_report && !isClaimedByCurrentUser(incident)}
                                        class="px-3 py-1.5 {incident.investigation_report ? 'bg-gradient-to-r from-teal-500 to-teal-600 hover:from-teal-600 hover:to-teal-700' : 'bg-gradient-to-r from-indigo-500 to-indigo-600 hover:from-indigo-600 hover:to-indigo-700'} text-white text-xs rounded-lg transition-all shadow-sm hover:shadow disabled:from-gray-300 disabled:to-gray-400 disabled:cursor-not-allowed font-medium"
                                        title={$locale === 'ar' ? (incident.investigation_report ? 'عرض التقرير' : 'التحقيق') : (incident.investigation_report ? 'View Report' : 'Investigation')}
                                    >
                                        {$locale === 'ar' ? (incident.investigation_report ? 'تقرير ✓' : 'تحقيق') : (incident.investigation_report ? 'Report ✓' : 'Investigate')}
                                    </button>
                                    <button
                                        on:click={() => openWarningModal(incident)}
                                        disabled={!hasWarningAction(incident) && (!isClaimedByCurrentUser(incident) || incident.resolution_status === 'resolved')}
                                        class="px-3 py-1.5 {hasWarningAction(incident) ? 'bg-gradient-to-r from-teal-500 to-teal-600 hover:from-teal-600 hover:to-teal-700' : 'bg-gradient-to-r from-orange-500 to-orange-600 hover:from-orange-600 hover:to-orange-700'} text-white text-xs rounded-lg transition-all shadow-sm hover:shadow disabled:from-gray-300 disabled:to-gray-400 disabled:cursor-not-allowed font-medium"
                                        title={hasWarningAction(incident) 
                                            ? ($locale === 'ar' ? 'عرض التحذير' : 'View Warning')
                                            : ($locale === 'ar' ? 'إصدار تحذير' : 'Issue warning')}
                                    >
                                        {hasWarningAction(incident)
                                            ? ($locale === 'ar' ? 'تحذير ✓' : 'Warning ✓')
                                            : ($locale === 'ar' ? 'تحذير' : 'Warning')}
                                    </button>
                                    <button
                                        on:click={() => incident.resolution_status === 'resolved' ? openResolutionModal(incident) : handleResolveIncident(incident)}
                                        disabled={incident.resolution_status !== 'resolved' && !incident.investigation_report}
                                        class="px-3 py-1.5 {incident.resolution_status === 'resolved' ? 'bg-gradient-to-r from-teal-500 to-teal-600 hover:from-teal-600 hover:to-teal-700' : 'bg-gradient-to-r from-purple-500 to-purple-600 hover:from-purple-600 hover:to-purple-700'} text-white text-xs rounded-lg transition-all shadow-sm hover:shadow disabled:from-gray-300 disabled:to-gray-400 disabled:cursor-not-allowed font-medium"
                                        title={incident.resolution_status === 'resolved' 
                                            ? ($locale === 'ar' ? 'عرض تقرير الحل' : 'View Resolution')
                                            : ($locale === 'ar' ? 'حل الحادثة' : 'Resolve incident')}
                                    >
                                        {incident.resolution_status === 'resolved'
                                            ? ($locale === 'ar' ? 'حل ✓' : 'Resolved ✓')
                                            : ($locale === 'ar' ? 'حل' : 'Resolve')}
                                    </button>
                                </div>
                            </td>
                        </tr>
                    {/each}
                </tbody>
            </table>
        </div>
    {/if}
    </div>
</div>

<style>
    :global(.font-sans) {
        font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    }
    
    .modal-overlay {
        position: fixed;
        top: 0;
        left: 0;
        right: 0;
        bottom: 0;
        background-color: rgba(0, 0, 0, 0.4);
        backdrop-filter: blur(4px);
        display: flex;
        align-items: center;
        justify-content: center;
        z-index: 50;
        animation: fadeIn 0.2s ease-out;
    }
    
    .modal-content {
        background: white;
        border-radius: 1rem;
        padding: 1.75rem;
        max-width: 500px;
        width: 90%;
        max-height: 80vh;
        overflow-y: auto;
        box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
        animation: scaleIn 0.2s ease-out;
    }
    
    @keyframes fadeIn {
        from { opacity: 0; }
        to { opacity: 1; }
    }
    
    @keyframes scaleIn {
        from {
            opacity: 0;
            transform: scale(0.95);
        }
        to {
            opacity: 1;
            transform: scale(1);
        }
    }
    
    /* RTL fixes for dropdown arrows */
    :global([dir="rtl"] select) {
        background-position: left 0.5rem center;
        padding-left: 2rem;
        padding-right: 0.75rem;
    }
</style>

{#if showAssignModal}
    <div class="modal-overlay" on:click={closeAssignModal}>
        <div class="modal-content" on:click|stopPropagation>
            <h3 class="text-xl font-bold text-slate-800 mb-4">
                {$locale === 'ar' ? 'تعيين مهمة استرجاع' : 'Assign Recovery Task'}
            </h3>
            
            <div class="mb-4">
                <p class="text-sm text-slate-600 mb-2">
                    {$locale === 'ar' ? 'رقم الحادثة' : 'Incident ID'}: <span class="font-mono font-bold">{selectedIncident?.id}</span>
                </p>
                <p class="text-sm text-slate-600 mb-4">
                    {$locale === 'ar' ? 'النوع' : 'Type'}: <span class="font-semibold">{$locale === 'ar' ? selectedIncident?.incident_types?.incident_type_ar : selectedIncident?.incident_types?.incident_type_en}</span>
                </p>
            </div>
            
            <div class="mb-6">
                <label class="block text-sm font-semibold text-slate-700 mb-2">
                    {$locale === 'ar' ? 'اختر المستخدم' : 'Select User'}
                </label>
                <div class="relative">
                    <input
                        type="text"
                        placeholder={$locale === 'ar' ? 'ابحث عن مستخدم...' : 'Search for a user...'}
                        value={searchQuery}
                        on:input={handleSearchInput}
                        on:focus={() => { filteredUsers = availableUsers; }}
                        class="w-full px-3 py-2 border border-slate-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                    />
                    {#if filteredUsers.length > 0}
                        <div class="absolute top-full left-0 right-0 mt-1 border border-slate-300 rounded-md bg-white shadow-lg max-h-48 overflow-y-auto z-10">
                            {#each filteredUsers as user (user.user_id)}
                                <button
                                    type="button"
                                    on:click={() => selectUser(user)}
                                    class="w-full text-left px-3 py-2 hover:bg-slate-100 transition flex justify-between"
                                >
                                    <span class="font-medium">{$locale === 'ar' ? user.name_ar : user.name_en}</span>
                                    <span class="text-xs text-slate-500">({user.email})</span>
                                </button>
                            {/each}
                        </div>
                    {/if}
                </div>
            </div>
            
            <div class="flex gap-3">
                <button
                    on:click={assignTask}
                    disabled={!selectedUserId || isAssigning}
                    class="flex-1 px-4 py-2 bg-green-600 text-white rounded hover:bg-green-700 transition disabled:bg-gray-400 disabled:cursor-not-allowed font-semibold"
                >
                    {isAssigning ? ($locale === 'ar' ? 'جاري التعيين...' : 'Assigning...') : ($locale === 'ar' ? 'تعيين' : 'Assign')}
                </button>
                <button
                    on:click={closeAssignModal}
                    disabled={isAssigning}
                    class="flex-1 px-4 py-2 bg-slate-400 text-white rounded hover:bg-slate-500 transition disabled:bg-gray-300 disabled:cursor-not-allowed font-semibold"
                >
                    {$locale === 'ar' ? 'إلغاء' : 'Cancel'}
                </button>
            </div>
        </div>
    </div>
{/if}

{#if showImagePreview}
    <div 
        class="fixed inset-0 bg-black bg-opacity-80 flex items-center justify-center z-[100]"
        on:click={closeImagePreview}
        on:keydown={(e) => e.key === 'Escape' && closeImagePreview()}
        role="dialog"
        aria-modal="true"
        tabindex="-1"
    >
        <div class="relative max-w-4xl max-h-[90vh] p-4" on:click|stopPropagation>
            <button
                on:click={closeImagePreview}
                class="absolute top-2 right-2 w-10 h-10 bg-white rounded-full flex items-center justify-center text-gray-700 hover:bg-gray-100 shadow-lg z-10"
                aria-label="Close preview"
            >
                ✕
            </button>
            <img 
                src={previewImageUrl} 
                alt={previewImageName} 
                class="max-w-full max-h-[85vh] object-contain rounded-lg shadow-2xl"
            />
            <p class="text-white text-center mt-2 text-sm">{previewImageName}</p>
        </div>
    </div>
{/if}

{#if showPendingUsersModal}
    <div class="modal-overlay" on:click={() => showPendingUsersModal = false}>
        <div class="modal-content" on:click|stopPropagation>
            <!-- Header with warning icon -->
            <div class="flex items-center gap-3 mb-4">
                <div class="w-12 h-12 bg-amber-100 rounded-full flex items-center justify-center">
                    <span class="text-2xl">⚠️</span>
                </div>
                <div>
                    <h3 class="text-xl font-bold text-slate-800">
                        Cannot Resolve Incident | <span dir="rtl">لا يمكن حل الحادثة</span>
                    </h3>
                    <p class="text-sm text-slate-500">
                        Pending Tasks | <span dir="rtl">المهام المعلقة</span>
                    </p>
                </div>
            </div>
            
            <!-- Message -->
            <div class="bg-amber-50 border border-amber-200 rounded-lg p-4 mb-4">
                <p class="text-amber-800 text-sm mb-2">
                    The following users have not completed their assigned tasks. Please inform them to close their tasks before resolving the incident.
                </p>
                <p class="text-amber-800 text-sm" dir="rtl">
                    لم يقم المستخدمون التاليون بإتمام المهام المعينة لهم. يرجى إبلاغهم بإغلاق مهامهم قبل حل الحادثة.
                </p>
            </div>
            
            <!-- Users list -->
            <div class="mb-6">
                <p class="text-sm font-semibold text-slate-700 mb-2">
                    Users who have not acknowledged: | <span dir="rtl">المستخدمون الذين لم يكملوا المهام:</span>
                </p>
                <ul class="space-y-2">
                    {#each pendingUsersList as user, index}
                        <li class="flex items-center gap-2 bg-slate-50 px-3 py-2 rounded-lg">
                            <span class="w-6 h-6 bg-red-100 text-red-600 rounded-full flex items-center justify-center text-xs font-bold">
                                {index + 1}
                            </span>
                            <div class="flex flex-col">
                                <span class="text-slate-700 font-medium">{user.name_en}</span>
                                <span class="text-slate-500 text-sm" dir="rtl">{user.name_ar}</span>
                            </div>
                            <span class="text-xs text-red-500 ml-auto whitespace-nowrap">
                                <span>Not completed</span>
                                <span class="mx-1">|</span>
                                <span dir="rtl">لم يكتمل</span>
                            </span>
                        </li>
                    {/each}
                </ul>
            </div>
            
            <!-- Action button -->
            <button
                on:click={() => showPendingUsersModal = false}
                class="w-full px-4 py-3 bg-amber-600 text-white rounded-lg hover:bg-amber-700 transition font-semibold"
            >
                OK, I understand | <span dir="rtl">حسناً، فهمت</span>
            </button>
        </div>
    </div>
{/if}
