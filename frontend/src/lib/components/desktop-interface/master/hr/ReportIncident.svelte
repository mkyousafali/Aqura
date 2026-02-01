<script lang="ts">
    import { t, locale } from '$lib/i18n';
    import { currentUser } from '$lib/utils/persistentAuth';
    
    export let violation: any;
    export let employees: any[] = [];
    export let branches: any[] = [];
    
    let selectedEmployee = '';
    let selectedEmployeeDetails: any = null;
    let selectedBranch = '';
    let isSaving = false;
    let loadingEmployee = false;
    let employeeSearchQuery = '';
    let showEmployeeDropdown = false;
    let whatHappened = '';
    let proofWitness = '';
    let incidentType = 'IN2'; // Default to Employee Incidents since this is ReportIncident (employee-related)
    let selectedImage: File | null = null;
    let imagePreviewUrl: string | null = null;
    let isUploadingImage = false;

    $: filteredEmployees = employees.filter(emp => {
        if (!employeeSearchQuery.trim()) return true;
        const query = employeeSearchQuery.toLowerCase();
        return (emp.name_en?.toLowerCase().includes(query) || 
                emp.name_ar?.toLowerCase().includes(query) ||
                emp.id?.toLowerCase().includes(query) ||
                emp.employee_id?.toLowerCase().includes(query));
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

    function handleImageSelect(e: Event) {
        const input = e.target as HTMLInputElement;
        const file = input.files?.[0];
        
        if (file) {
            // Validate file type
            if (!file.type.startsWith('image/')) {
                alert($locale === 'ar' ? 'يرجى تحديد ملف صورة صحيح' : 'Please select a valid image file');
                return;
            }
            
            // Validate file size (max 10MB)
            if (file.size > 10 * 1024 * 1024) {
                alert($locale === 'ar' ? 'حجم الصورة أكبر من 10 ميجابايت' : 'Image size exceeds 10MB');
                return;
            }
            
            selectedImage = file;
            const reader = new FileReader();
            reader.onload = (e) => {
                imagePreviewUrl = e.target?.result as string;
            };
            reader.readAsDataURL(file);
        }
    }

    function clearImage() {
        selectedImage = null;
        imagePreviewUrl = null;
    }

    async function handleReportIncident() {
        if (!selectedEmployee || !violation || !selectedBranch || !whatHappened.trim()) {
            alert($locale === 'ar' ? 'يرجى ملء جميع الحقول المطلوبة' : 'Please fill in all required fields');
            return;
        }
        
        if (!$currentUser || !$currentUser.id) {
            alert($locale === 'ar' ? 'لم يتم تحديد المستخدم الحالي' : 'Current user not identified');
            return;
        }
        
        isSaving = true;
        let uploadedImageUrl: string | null = null;
        
        try {
            const { supabase } = await import('$lib/utils/supabase');
            
            // Upload image if selected
            if (selectedImage) {
                isUploadingImage = true;
                const fileName = `incident-${Date.now()}-${Math.random().toString(36).substr(2, 9)}.${selectedImage.name.split('.').pop()}`;
                const { data: uploadData, error: uploadError } = await supabase.storage
                    .from('documents')
                    .upload(`incidents/${fileName}`, selectedImage);
                
                if (uploadError) {
                    throw new Error(`Image upload failed: ${uploadError.message}`);
                }
                
                // Get the public URL
                const { data: { publicUrl } } = supabase.storage
                    .from('documents')
                    .getPublicUrl(`incidents/${fileName}`);
                
                uploadedImageUrl = publicUrl;
                isUploadingImage = false;
            }
            
            // Get the next incident ID
            const { data: lastIncident, error: lastError } = await supabase
                .from('incidents')
                .select('id')
                .order('id', { ascending: false })
                .limit(1)
                .single();
            
            let nextIncidentNum = 1;
            if (lastIncident && lastIncident.id) {
                const lastNum = parseInt(lastIncident.id.replace('INS', ''));
                nextIncidentNum = lastNum + 1;
            }
            const incidentId = `INS${nextIncidentNum}`;
            
            // Fetch users who can receive employee incidents
            const { data: permissions, error: permError } = await supabase
                .from('approval_permissions')
                .select('user_id')
                .eq('can_receive_employee_incidents', true)
                .eq('is_active', true);
            
            if (permError) throw permError;
            
            const recipientUserIds = permissions?.map(p => p.user_id) || [];
            
            // Create user_statuses object with 'reported' status for each recipient
            const userStatuses: any = {};
            recipientUserIds.forEach(userId => {
                userStatuses[userId] = {
                    status: 'reported',
                    notified_at: new Date().toISOString(),
                    read_at: null
                };
            });
            
            // Create the incident report
            const { error: insertError } = await supabase
                .from('incidents')
                .insert([{
                    id: incidentId,
                    incident_type_id: incidentType,
                    employee_id: selectedEmployee,
                    branch_id: selectedBranch,
                    violation_id: violation.id,
                    what_happened: {
                        description: whatHappened,
                        created_at: new Date().toISOString()
                    },
                    witness_details: proofWitness ? {
                        details: proofWitness,
                        recorded_at: new Date().toISOString()
                    } : null,
                    report_type: 'employee_related',
                    reports_to_user_ids: recipientUserIds,
                    resolution_status: 'reported',
                    user_statuses: userStatuses,
                    image_url: uploadedImageUrl,
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
                const employeeName = selectedEmployeeDetails?.name_en || 'Unknown';
                const employeeNameAr = selectedEmployeeDetails?.name_ar || 'غير معروف';
                
                const branchNameEn = branchData?.name_en && branchData?.location_en 
                    ? `${branchData.name_en} - ${branchData.location_en}`
                    : branchData?.name_en || 'Unknown Branch';
                const branchNameAr = branchData?.name_ar && branchData?.location_ar 
                    ? `${branchData.name_ar} - ${branchData.location_ar}`
                    : branchData?.name_ar || 'فرع غير معروف';
                
                const violationName = violation?.name_en || 'Unknown Violation';
                const violationNameAr = violation?.name_ar || 'انتهاك غير معروف';
                
                // Get the user_id of the selected employee
                const { data: employeeUser, error: empUserError } = await supabase
                    .from('hr_employee_master')
                    .select('user_id')
                    .eq('id', selectedEmployee)
                    .single();
                
                if (empUserError) {
                    console.warn('⚠️ Could not fetch employee user_id:', empUserError);
                }
                
                // Build notification array for recipients (bilingual - both at same time)
                const notificationsList = recipientUserIds.map(userId => ({
                    title: '📋 New Incident Report | تقرير حادثة جديد',
                    message: `New incident report (${incidentId}) from ${createdByName} regarding ${employeeName} at ${branchNameEn} related to ${violationName}\n---\nتقرير حادثة جديد (${incidentId}) من ${createdByNameAr} بخصوص ${employeeNameAr} في ${branchNameAr} المتعلق بـ ${violationNameAr}`,
                    type: 'info',
                    priority: 'normal',
                    target_type: 'specific_users',
                    target_users: [userId],
                    created_at: new Date().toISOString()
                }));
                
                // Add notification for the employee (reporting employee) - bilingual
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
                
                // Send all notifications
                if (notificationsList.length > 0) {
                    await supabase
                        .from('notifications')
                        .insert(notificationsList);
                }
                
                // Create quick tasks for recipients to acknowledge the incident
                if (recipientUserIds.length > 0) {
                    try {
                        // Create the quick task once
                        const { data: quickTaskData, error: taskCreateError } = await supabase
                            .from('quick_tasks')
                            .insert({
                                title: `Acknowledge Incident | تأكيد الحادثة: ${incidentId}`,
                                description: `From ${createdByName} regarding ${employeeName} at ${branchNameEn} related to ${violationName}\n---\nمن ${createdByNameAr} بخصوص ${employeeNameAr} في ${branchNameAr} المتعلق بـ ${violationNameAr}`,
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
                            // Create assignments for each recipient
                            const assignments = recipientUserIds.map(userId => ({
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
            selectedImage = null;
            imagePreviewUrl = null;
            
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
        <!-- Violation & Employee Selection -->
        <div>
            <label class="block text-xs font-bold text-slate-600 uppercase tracking-wide mb-2">{$locale === 'ar' ? 'المخالفة واختيار الموظف' : 'Violation & Select Employee'}</label>
            <div class="flex items-center gap-3">
                {#if violation}
                    <div class="bg-blue-50 border border-blue-200 rounded px-3 py-1.5 flex items-center gap-2 flex-shrink-0">
                        <div class="w-1 h-6 bg-blue-500 rounded-full"></div>
                        <div class="text-xs">
                            <span class="font-medium text-slate-900">{$locale === 'ar' ? violation.name_ar : violation.name_en}</span>
                        </div>
                    </div>
                {/if}
                <div class="flex-1 relative">
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
                                    </button>
                                {/each}
                            {/if}
                        </div>
                    {/if}
                </div>
            </div>
        </div>

        {#if selectedEmployee}
            {#if loadingEmployee}
                <div class="bg-slate-100 border border-slate-200 rounded px-3 py-1.5 flex items-center gap-2">
                    <div class="animate-spin w-4 h-4 border-2 border-slate-300 border-t-slate-600 rounded-full"></div>
                    <span class="text-xs text-slate-500">{$locale === 'ar' ? 'جاري التحميل...' : 'Loading...'}</span>
                </div>
            {:else if selectedEmployeeDetails}
                <!-- Employee Details -->
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

                <!-- Branch Selection -->
                <div>
                    <label for="branch-select" class="block text-xs font-bold text-slate-600 uppercase tracking-wide mb-2">{$locale === 'ar' ? 'اختيار الفرع *' : 'Select Branch *'}</label>
                    <select 
                        id="branch-select"
                        bind:value={selectedBranch}
                        class="w-full px-3 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none text-sm hover:border-slate-300 transition"
                    >
                        <option value="">{$locale === 'ar' ? 'اختر الفرع...' : 'Select Branch...'}</option>
                        {#each branches as branch}
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
                    
                    <!-- Image Upload Section (Optional) -->
                    <div>
                        <label for="image-upload" class="block text-xs font-bold text-slate-600 uppercase tracking-wide mb-1">📸 {$locale === 'ar' ? 'تحميل صورة (اختياري)' : 'Upload Image (Optional)'}</label>
                        <div class="flex gap-2">
                            <input 
                                id="image-upload"
                                type="file" 
                                accept="image/*"
                                on:change={handleImageSelect}
                                disabled={isUploadingImage}
                                class="flex-1 px-3 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none text-sm hover:border-slate-300 transition cursor-pointer disabled:opacity-50"
                            />
                            {#if selectedImage}
                                <button 
                                    type="button"
                                    on:click={clearImage}
                                    disabled={isUploadingImage}
                                    class="px-3 py-2 bg-red-100 hover:bg-red-200 text-red-700 rounded-lg text-sm font-bold disabled:opacity-50 transition"
                                >
                                    ✕
                                </button>
                            {/if}
                        </div>
                        {#if selectedImage}
                            <p class="text-xs text-green-600 mt-1">✓ {selectedImage.name}</p>
                        {/if}
                        {#if imagePreviewUrl}
                            <div class="mt-2 rounded-lg overflow-hidden border border-slate-200">
                                <img src={imagePreviewUrl} alt="Preview" class="w-full h-48 object-cover" />
                            </div>
                        {/if}
                    </div>
                </div>
            {/if}
        {/if}
    </div>

    <div class="px-8 py-5 bg-white border-t-2 border-slate-200 flex gap-4 justify-end flex-shrink-0 shadow-lg">
        <button disabled={!selectedEmployee || isSaving} class="px-8 py-2.5 rounded-lg font-bold text-white bg-blue-600 hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition transform hover:scale-105 active:scale-95" on:click={handleReportIncident}>
            {isSaving ? ($locale === 'ar' ? 'جاري الحفظ...' : 'Saving...') : ($locale === 'ar' ? 'الإبلاغ عن الحادثة' : 'Report Incident')}
        </button>
    </div>
</div>

<style>
    :global(.font-sans) {
        font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    }
</style>
