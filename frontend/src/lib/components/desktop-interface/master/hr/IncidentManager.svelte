<script lang="ts">
    import { _ as t } from '$lib/i18n';
    import { locale } from '$lib/i18n';
    import { onMount } from 'svelte';
    import { currentUser } from '$lib/utils/persistentAuth';
    import { openWindow } from '$lib/utils/windowManagerUtils';
    import IssueWarning from './IssueWarning.svelte';
    
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
                    user_statuses,
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
                    
                    return {
                        ...incident,
                        employeeName,
                        branchName,
                        reportToNames
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
            const { error } = await supabase
                .from('incidents')
                .update({
                    resolution_status: 'resolved'
                })
                .eq('id', incident.id);
            
            if (error) {
                throw new Error(error.message);
            }
            
            // Reload incidents
            await loadIncidents();
            alert($locale === 'ar' ? 'تم حل الحادثة بنجاح' : 'Incident resolved successfully');
        } catch (err) {
            console.error('Error resolving incident:', err);
            alert($locale === 'ar' ? 'خطأ في حل الحادثة' : 'Error resolving incident');
        }
    }
    
    function openWarningModal(incident: any) {
        const windowId = `issue-warning-incident-${Date.now()}`;
        openWindow({
            id: windowId,
            title: `Issue Warning - Incident #${incident.id}`,
            component: IssueWarning,
            icon: '⚠️',
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
                branchName: incident.branchName
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
    
    onMount(() => {
        loadIncidents();
    });
</script>

<div class="h-full w-full flex flex-col bg-gradient-to-br from-slate-50 to-slate-100 p-4">
    <div class="mb-6">
        <h2 class="text-3xl font-bold text-slate-800 flex items-center gap-2">
            <span>📋</span>
            {$t('hr.incidentManager.title') || 'Incident Manager'}
        </h2>
        <p class="text-slate-600 mt-1">{$t('hr.incidentManager.description') || 'View and manage all incident reports'}</p>
    </div>
    
    {#if isLoading}
        <div class="flex items-center justify-center flex-1">
            <div class="text-center">
                <div class="animate-spin text-4xl mb-4">⏳</div>
                <p class="text-slate-600">{$locale === 'ar' ? 'جاري التحميل...' : 'Loading incidents...'}</p>
            </div>
        </div>
    {:else if error}
        <div class="bg-red-50 border border-red-200 rounded-lg p-4 mb-4">
            <p class="text-red-800 font-semibold">{$locale === 'ar' ? 'خطأ' : 'Error'}: {error}</p>
            <button 
                on:click={loadIncidents}
                class="mt-2 px-4 py-2 bg-red-600 text-white rounded hover:bg-red-700"
            >
                {$locale === 'ar' ? 'إعادة محاولة' : 'Retry'}
            </button>
        </div>
    {:else if incidents.length === 0}
        <div class="flex items-center justify-center flex-1">
            <div class="text-center">
                <div class="text-5xl mb-4">📭</div>
                <p class="text-slate-600 text-lg">{$locale === 'ar' ? 'لا توجد حوادث مسجلة' : 'No incidents found'}</p>
            </div>
        </div>
    {:else}
        <div class="bg-white rounded-lg shadow overflow-hidden flex-1 overflow-y-auto">
            <table class="w-full">
                <thead class="bg-slate-200 sticky top-0">
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
                            {$locale === 'ar' ? 'التاريخ' : 'Date'}
                        </th>
                        <th class="px-4 py-3 text-left text-sm font-semibold text-slate-700">
                            {$locale === 'ar' ? 'الإجراءات' : 'Actions'}
                        </th>
                    </tr>
                </thead>
                <tbody>
                    {#each incidents as incident (incident.id)}
                        <tr class="border-b border-slate-200 hover:bg-slate-50 transition">
                            <td class="px-4 py-3 text-sm font-mono text-blue-600">
                                {incident.id}
                            </td>
                            <td class="px-4 py-3 text-sm text-slate-700">
                                {$locale === 'ar' 
                                    ? incident.incident_types?.incident_type_ar 
                                    : incident.incident_types?.incident_type_en}
                            </td>
                            <td class="px-4 py-3 text-sm text-slate-700">
                                {incident.employeeName}
                            </td>
                            <td class="px-4 py-3 text-sm text-slate-700">
                                {incident.branchName}
                            </td>
                            <td class="px-4 py-3 text-sm text-slate-700">
                                {$locale === 'ar' 
                                    ? incident.warning_violation?.name_ar 
                                    : incident.warning_violation?.name_en}
                            </td>
                            <td class="px-4 py-3 text-sm text-slate-700">
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
                            <td class="px-4 py-3 text-sm">
                                <span class="px-2 py-1 rounded-full text-xs font-semibold {getStatusBadgeColor(incident.resolution_status)}">
                                    {$locale === 'ar'
                                        ? incident.resolution_status === 'reported' ? 'مبلغ عنه'
                                        : incident.resolution_status === 'claimed' ? 'مطالب به'
                                        : incident.resolution_status === 'resolved' ? 'تم حله'
                                        : incident.resolution_status
                                        : incident.resolution_status.charAt(0).toUpperCase() + incident.resolution_status.slice(1)}
                                </span>
                            </td>
                            <td class="px-4 py-3 text-sm text-slate-600">
                                {formatDate(incident.created_at)}
                            </td>
                            <td class="px-4 py-3 text-sm">
                                <div class="flex gap-2">
                                    <button
                                        on:click={() => handleClaimIncident(incident)}
                                        disabled={incident.resolution_status === 'claimed'}
                                        class="px-3 py-1 bg-blue-600 text-white text-xs rounded hover:bg-blue-700 transition disabled:bg-gray-400 disabled:cursor-not-allowed"
                                        title={$locale === 'ar' ? 'مطالبة بالحادثة' : 'Claim incident'}
                                    >
                                        {$locale === 'ar' ? 'مطالبة' : 'Claim'}
                                    </button>
                                    <button
                                        on:click={() => openAssignModal(incident)}
                                        disabled={incident.resolution_status !== 'claimed' || hasAnyAssignedUser(incident)}
                                        class="px-3 py-1 bg-green-600 text-white text-xs rounded hover:bg-green-700 transition disabled:bg-gray-400 disabled:cursor-not-allowed"
                                        title={$locale === 'ar' ? 'تعيين مهمة' : 'Assign task'}
                                    >
                                        {$locale === 'ar' ? 'تعيين' : 'Assign'}
                                    </button>
                                    <button
                                        on:click={() => openWarningModal(incident)}
                                        disabled={incident.resolution_status !== 'claimed'}
                                        class="px-3 py-1 bg-orange-600 text-white text-xs rounded hover:bg-orange-700 transition disabled:bg-gray-400 disabled:cursor-not-allowed"
                                        title={$locale === 'ar' ? 'إصدار تحذير' : 'Issue warning'}
                                    >
                                        {$locale === 'ar' ? 'تحذير' : 'Warning'}
                                    </button>
                                    <button
                                        on:click={() => handleResolveIncident(incident)}
                                        disabled={incident.resolution_status === 'resolved'}
                                        class="px-3 py-1 bg-purple-600 text-white text-xs rounded hover:bg-purple-700 transition disabled:bg-gray-400 disabled:cursor-not-allowed"
                                        title={$locale === 'ar' ? 'حل الحادثة' : 'Resolve incident'}
                                    >
                                        {$locale === 'ar' ? 'حل' : 'Resolve'}
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
        background-color: rgba(0, 0, 0, 0.5);
        display: flex;
        align-items: center;
        justify-content: center;
        z-index: 50;
    }
    
    .modal-content {
        background: white;
        border-radius: 0.5rem;
        padding: 1.5rem;
        max-width: 500px;
        width: 90%;
        max-height: 80vh;
        overflow-y: auto;
        box-shadow: 0 10px 25px rgba(0, 0, 0, 0.2);
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
