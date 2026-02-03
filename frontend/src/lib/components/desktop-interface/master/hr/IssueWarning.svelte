<script lang="ts">
    import { t, locale } from '$lib/i18n';
    import { currentUser } from '$lib/utils/persistentAuth';
    import { onMount } from 'svelte';
    
    export let violation: any;
    export let employees: any[] = [];
    export let employeeId: string | null = null;
    export let branchId: string | null = null;
    export let branchName: string | null = null;
    export let incident: any = null;
    export let viewMode: boolean = false;
    export let savedAction: any = null;
    
    let incidentDescription = '';
    let witnessDetails = '';
    let investigationReport = '';
    let selectedEmployee = employeeId || '';
    let selectedBranch = branchId || '';
    let employeeSearchQuery = '';
    let showEmployeeDropdown = false;
    let selectedEmployeeDetails: any = null;
    let isSaving = false;
    let loadingEmployee = false;
    let warningNotes = '';
    let branches: any[] = [];
    let selectedLanguages: string[] = [];
    let selectedRecourse = '';
    let fineAmount = '';
    let isGenerating = false;
    let isInitialLoadDone = false;
    
    // For non-employee incidents - violation selection
    let violations: any[] = [];
    let violationSearchQuery = '';
    let showViolationDropdown = false;
    let selectedViolation: any = violation;
    
    // Local employees list (loaded from DB for non-employee incidents)
    let localEmployees: any[] = [];
    
    // Check if this is a non-employee incident
    $: isNonEmployeeIncident = incident && incident.incident_type_id !== 'IN2';
    
    // For non-employee incidents, always use loaded employees; otherwise use passed employees
    $: availableEmployees = isNonEmployeeIncident ? localEmployees : (employees.length > 0 ? employees : localEmployees);
    
    // Load violations when it's a non-employee incident
    $: if (isNonEmployeeIncident && violations.length === 0) {
        loadViolations();
    }
    
    // Load employees when it's a non-employee incident
    $: if (isNonEmployeeIncident && localEmployees.length === 0) {
        loadEmployees();
    }
    
    // Load saved action data if in view mode, and load branches
    onMount(async () => {
        await loadBranches();
        
        // Load violations and employees for non-employee incidents
        if (incident && incident.incident_type_id !== 'IN2') {
            await loadViolations();
            if (employees.length === 0) {
                await loadEmployees();
            }
        }
        
        if (viewMode && savedAction?.action_report) {
            const report = savedAction.action_report;
            warningNotes = report.report_content || '';
            selectedLanguages = report.languages || [];
            selectedRecourse = report.recourse_type || savedAction.recourse_type || '';
            fineAmount = savedAction.fine_amount > 0 ? String(savedAction.fine_amount) : (savedAction.fine_threat_amount > 0 ? String(savedAction.fine_threat_amount) : '');
            incidentDescription = report.incident_description || '';
            witnessDetails = report.witness_details || '';
            investigationReport = report.investigation_report || '';
            if (report.employee) {
                selectedEmployeeDetails = report.employee;
                selectedEmployee = report.employee.id || '';
                
                // If id_number is missing, fetch it from the database
                if (!selectedEmployeeDetails.id_number && selectedEmployee) {
                    try {
                        const { supabase } = await import('$lib/utils/supabase');
                        const { data: empData } = await supabase
                            .from('hr_employee_master')
                            .select('id_number')
                            .eq('id', selectedEmployee)
                            .single();
                        if (empData?.id_number) {
                            selectedEmployeeDetails = { ...selectedEmployeeDetails, id_number: empData.id_number };
                        }
                    } catch (e) {
                        console.warn('Could not fetch employee id_number:', e);
                    }
                }
            }
            selectedBranch = report.branch_id || branchId || '';
        }
        
        isInitialLoadDone = true;
    });
    
    const availableLanguages = [
        { code: 'ar', name: 'Arabic', nameAr: 'العربية' },
        { code: 'en', name: 'English', nameAr: 'الإنجليزية' },
        { code: 'ml', name: 'Malayalam', nameAr: 'الملايالامية' },
        { code: 'bn', name: 'Bengali', nameAr: 'البنغالية' },
        { code: 'hi', name: 'Hindi', nameAr: 'الهندية' },
        { code: 'ur', name: 'Urdu', nameAr: 'الأردية' },
        { code: 'ta', name: 'Tamil', nameAr: 'التاميلية' }
    ];

    const recourseOptions = [
        { id: 'warning', label: 'Just Warning', labelAr: 'تحذير فقط' },
        { id: 'warning_fine', label: 'Warning with Fine', labelAr: 'تحذير مع غرامة' },
        { id: 'warning_fine_threat', label: 'Warning with Fine Threat', labelAr: 'تحذير مع تهديد بالغرامة' },
        { id: 'warning_fine_termination_threat', label: 'Warning with Fine + Termination Threat', labelAr: 'تحذير مع غرامة وتهديد بالفصل' },
        { id: 'termination', label: 'Termination', labelAr: 'إنهاء الخدمة' }
    ];

    function toggleLanguage(langCode: string) {
        if (selectedLanguages.includes(langCode)) {
            selectedLanguages = selectedLanguages.filter(l => l !== langCode);
        } else {
            selectedLanguages = [...selectedLanguages, langCode];
        }
    }

    async function generateReportUsingAI() {
        if (!selectedLanguages.length) {
            alert($locale === 'ar' ? 'يرجى اختيار لغة واحدة على الأقل' : 'Please select at least one language');
            return;
        }
        if (!selectedRecourse) {
            alert($locale === 'ar' ? 'يرجى اختيار نوع الإجراء' : 'Please select a recourse type');
            return;
        }
        if (!incidentDescription && !witnessDetails) {
            alert($locale === 'ar' ? 'لا توجد تفاصيل حادثة لإنشاء التقرير' : 'No incident details available to generate report');
            return;
        }

        isGenerating = true;
        try {
            const response = await fetch('/api/generate-incident-warning', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    languages: selectedLanguages,
                    recourseType: selectedRecourse,
                    fineAmount: fineAmount || null,
                    whatHappened: incidentDescription,
                    witnessDetails: witnessDetails,
                    investigationReport: investigationReport || null,
                    violationName: violation?.name_en || '',
                    violationNameAr: violation?.name_ar || '',
                    employeeName: selectedEmployeeDetails?.name_en || '',
                    employeeNameAr: selectedEmployeeDetails?.name_ar || '',
                    branchName: branchName || getBranchDisplayName()
                })
            });

            if (!response.ok) {
                const errorData = await response.json();
                throw new Error(errorData.error || 'Failed to generate report');
            }

            const data = await response.json();
            warningNotes = data.generatedText || '';
            
        } catch (err) {
            console.error('Error generating report:', err);
            alert($locale === 'ar' 
                ? `خطأ في إنشاء التقرير: ${err instanceof Error ? err.message : 'فشل الإنشاء'}` 
                : `Error generating report: ${err instanceof Error ? err.message : 'Generation failed'}`);
        } finally {
            isGenerating = false;
        }
    }

    async function loadBranches() {
        try {
            const { supabase } = await import('$lib/utils/supabase');
            const { data, error } = await supabase
                .from('branches')
                .select('id, name_en, name_ar, location_en, location_ar')
                .eq('is_active', true)
                .order('name_en');
            
            if (error) throw error;
            branches = data || [];
        } catch (err) {
            console.error('Error loading branches:', err);
            branches = [];
        }
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
            console.log('Loaded violations:', violations.length);
        } catch (err) {
            console.error('Error loading violations:', err);
            violations = [];
        }
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

    function getBranchDisplayName(): string {
        if (!selectedBranch) return '';
        const branch = branches.find(b => b.id == selectedBranch);
        if (!branch) return '';
        const name = $locale === 'ar' ? (branch.name_ar || branch.name_en) : branch.name_en;
        const location = $locale === 'ar' ? (branch.location_ar || branch.location_en) : branch.location_en;
        return `${name} - ${location}`;
    }

    // Auto-populate incident details - only if NOT in view mode
    $: if (incident && !viewMode) {
        if (incident.what_happened) {
            const whatHappened = incident.what_happened;
            incidentDescription = typeof whatHappened === 'string' 
                ? whatHappened 
                : whatHappened.description || '';
        }
        if (incident.witness_details) {
            const witnesses = incident.witness_details;
            witnessDetails = typeof witnesses === 'string' 
                ? witnesses 
                : witnesses.details || '';
        }
        if (incident.investigation_report) {
            const report = incident.investigation_report;
            investigationReport = typeof report === 'string' 
                ? report 
                : report.content || '';
        }
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
            
            // Update search query to show selected employee name
            if (data && !employeeSearchQuery) {
                employeeSearchQuery = `${data.name_en}${data.name_ar ? ' / ' + data.name_ar : ''}`;
            }
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

    async function handleIssueWarning() {
        // Validate required fields
        const needsFineAmount = selectedRecourse === 'warning_fine' || selectedRecourse === 'warning_fine_threat' || selectedRecourse === 'warning_fine_termination_threat';
        const hasFine = selectedRecourse === 'warning_fine' || selectedRecourse === 'warning_fine_termination_threat';
        const hasFineThreat = selectedRecourse === 'warning_fine_threat';
        
        // Use selectedViolation for non-employee incidents, otherwise use prop violation
        const activeViolation = isNonEmployeeIncident ? selectedViolation : violation;
        
        if (!selectedLanguages.length || !selectedRecourse || !selectedEmployee || !selectedBranch || !activeViolation || !warningNotes.trim()) {
            alert($locale === 'ar' ? 'الرجاء ملء جميع الحقول المطلوبة' : 'Please fill all required fields');
            return;
        }
        
        if (needsFineAmount && !fineAmount) {
            alert($locale === 'ar' ? 'الرجاء إدخال مبلغ الغرامة' : 'Please enter fine amount');
            return;
        }
        
        isSaving = true;
        try {
            const supabaseModule = await import('$lib/utils/supabase');
            const supabase = supabaseModule.supabase;
            
            // Prepare action report JSONB
            const actionReport = {
                languages: selectedLanguages,
                recourse_type: selectedRecourse,
                report_content: warningNotes,
                violation: {
                    id: activeViolation.id,
                    name_en: activeViolation.name_en,
                    name_ar: activeViolation.name_ar
                },
                employee: selectedEmployeeDetails ? {
                    id: selectedEmployeeDetails.id,
                    name_en: selectedEmployeeDetails.name_en,
                    name_ar: selectedEmployeeDetails.name_ar,
                    id_number: selectedEmployeeDetails.id_number,
                    job_title: selectedEmployeeDetails.job_title
                } : null,
                branch_id: selectedBranch,
                branch_name: branchName,
                incident_description: incidentDescription,
                witness_details: witnessDetails,
                investigation_report: investigationReport,
                generated_at: new Date().toISOString()
            };
            
            // Save to incident_actions table
            const { data, error } = await supabase
                .from('incident_actions')
                .insert({
                    action_type: selectedRecourse === 'termination' ? 'termination' : 'warning',
                    recourse_type: selectedRecourse,
                    action_report: actionReport,
                    has_fine: hasFine,
                    fine_amount: hasFine ? parseFloat(fineAmount) : 0,
                    fine_threat_amount: hasFineThreat ? parseFloat(fineAmount) : 0,
                    is_paid: false,
                    employee_id: selectedEmployee,
                    incident_id: incident?.id || null,
                    incident_type_id: incident?.incident_type_id || null,
                    created_by: $currentUser?.id || null
                })
                .select()
                .single();
            
            if (error) {
                throw new Error(error.message);
            }
            
            console.log('Warning saved:', data);
            
            // Send notifications
            try {
                const recourseLabel = recourseOptions.find(r => r.id === selectedRecourse);
                const recourseText = $locale === 'ar' ? recourseLabel?.labelAr : recourseLabel?.label;
                const fineText = hasFine || hasFineThreat ? ` - ${$locale === 'ar' ? 'غرامة' : 'Fine'}: ${fineAmount} SAR` : '';
                
                // Get employee's user_id for notification
                const { data: empUserData } = await supabase
                    .from('hr_employee_master')
                    .select('user_id, name_en, name_ar')
                    .eq('id', selectedEmployee)
                    .single();
                
                const employeeName = $locale === 'ar' 
                    ? (selectedEmployeeDetails?.name_ar || empUserData?.name_ar) 
                    : (selectedEmployeeDetails?.name_en || empUserData?.name_en);
                
                const violationName = $locale === 'ar' ? activeViolation.name_ar : activeViolation.name_en;
                const issuerName = ($currentUser as any)?.employeeName || ($currentUser as any)?.name || $currentUser?.email;
                
                // Notification to employee
                if (empUserData?.user_id) {
                    const employeeNotificationTitle = '⚠️ Official Warning Issued / تحذير رسمي صدر لك';
                    
                    const recourseTextAr = selectedRecourse === 'fine' ? 'غرامة مالية' : selectedRecourse === 'warning' ? 'تحذير' : 'إنهاء خدمة';
                    const violationNameAr = activeViolation.name_ar || violationName;
                    const fineTextAr = selectedRecourse === 'fine' && fineAmount ? ` - المبلغ: ${fineAmount} ريال` : '';
                    
                    // Build comprehensive notification with all details
                    let incidentDescSection = incidentDescription ? `\n\n📝 INCIDENT DESCRIPTION:\n${incidentDescription}` : '';
                    let witnessSection = witnessDetails ? `\n\n👥 WITNESS DETAILS:\n${witnessDetails}` : '';
                    let investigationSection = investigationReport ? `\n\n🔍 INVESTIGATION REPORT:\n${investigationReport}` : '';
                    let warningReportSection = warningNotes ? `\n\n📄 WARNING REPORT:\n${warningNotes}` : '';
                    
                    let incidentDescSectionAr = incidentDescription ? `\n\n📝 وصف الحادثة:\n${incidentDescription}` : '';
                    let witnessSectionAr = witnessDetails ? `\n\n👥 تفاصيل الشهود:\n${witnessDetails}` : '';
                    let investigationSectionAr = investigationReport ? `\n\n🔍 تقرير التحقيق:\n${investigationReport}` : '';
                    let warningReportSectionAr = warningNotes ? `\n\n📄 تقرير الإنذار:\n${warningNotes}` : '';
                    
                    const employeeNotificationMessage = `A ${recourseText} has been issued regarding: ${violationName}${fineText}
${incidentDescSection}${witnessSection}${investigationSection}${warningReportSection}

📋 IMPORTANT NOTICE:
• Please collect the printed warning from HR Department.
• This is an electronically issued warning and does not require a physical signature.
• This acknowledgment confirms that you were given an opportunity to explain your side, and the final decision was made by management.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━

تم إصدار ${recourseTextAr} بشأن: ${violationNameAr}${fineTextAr}
${incidentDescSectionAr}${witnessSectionAr}${investigationSectionAr}${warningReportSectionAr}

📋 ملاحظة هامة:
• يرجى استلام التحذير المطبوع من قسم الموارد البشرية.
• هذا تحذير صادر إلكترونياً ولا يتطلب توقيعاً ورقياً.
• هذا الإقرار يثبت أنه تم منحك فرصة لتوضيح موقفك، والقرار النهائي تم اتخاذه من قبل الإدارة.`;
                    
                    await supabase.from('notifications').insert({
                        title: employeeNotificationTitle,
                        message: employeeNotificationMessage,
                        type: 'warning',
                        priority: 'high',
                        target_type: 'specific_users',
                        target_users: [empUserData.user_id],
                        created_at: new Date().toISOString()
                    });
                    console.log('📧 Notification sent to employee:', empUserData.user_id);
                }
                
                // Notification to all users in reports_to_user_ids
                if (incident?.reports_to_user_ids && Array.isArray(incident.reports_to_user_ids) && incident.reports_to_user_ids.length > 0) {
                    const reportsToNotificationTitle = `✅ Action Taken - Incident #${incident.id} / تم اتخاذ إجراء - حادثة #${incident.id}`;
                    
                    const recourseTextAr = selectedRecourse === 'fine' ? 'غرامة مالية' : selectedRecourse === 'warning' ? 'تحذير' : 'إنهاء خدمة';
                    const violationNameAr = activeViolation.name_ar || violationName;
                    const fineTextAr = selectedRecourse === 'fine' && fineAmount ? ` - المبلغ: ${fineAmount} ريال` : '';
                    
                    const reportsToNotificationMessage = `A ${recourseText} has been issued to employee: ${employeeName}\n\nViolation: ${violationName}${fineText}\n\nIssued by: ${issuerName}\n\nReport Summary:\n${warningNotes.substring(0, 200)}${warningNotes.length > 200 ? '...' : ''}\n\n---\n\nتم إصدار ${recourseTextAr} للموظف: ${employeeName}\n\nالمخالفة: ${violationNameAr}${fineTextAr}\n\nصدر بواسطة: ${issuerName}\n\nملخص التقرير:\n${warningNotes.substring(0, 200)}${warningNotes.length > 200 ? '...' : ''}`;
                    
                    await supabase.from('notifications').insert({
                        title: reportsToNotificationTitle,
                        message: reportsToNotificationMessage,
                        type: 'info',
                        priority: 'normal',
                        target_type: 'specific_users',
                        target_users: incident.reports_to_user_ids,
                        created_at: new Date().toISOString()
                    });
                    console.log('📧 Notification sent to reports_to users:', incident.reports_to_user_ids);
                }
            } catch (notifError) {
                console.warn('Failed to send notifications:', notifError);
                // Don't fail the whole operation if notifications fail
            }
            
            // For non-employee incidents, update the incident with the selected employee and violation
            if (isNonEmployeeIncident && incident?.id) {
                const { error: updateError } = await supabase
                    .from('incidents')
                    .update({
                        employee_id: selectedEmployee,
                        violation_id: activeViolation.id,
                        updated_by: $currentUser?.id || null
                    })
                    .eq('id', incident.id);
                
                if (updateError) {
                    console.warn('Failed to update incident with employee:', updateError);
                }
            }
            
            // Clear form
            selectedEmployee = '';
            selectedEmployeeDetails = null;
            selectedBranch = '';
            employeeSearchQuery = '';
            warningNotes = '';
            selectedLanguages = [];
            selectedRecourse = '';
            fineAmount = '';
            violationSearchQuery = '';
            selectedViolation = null;
            
            alert($locale === 'ar' ? '✅ تم إصدار التحذير بنجاح' : '✅ Warning issued successfully');
        } catch (err) {
            console.error('Error issuing warning:', err);
            alert('Error: ' + (err instanceof Error ? err.message : 'Failed to save'));
        } finally {
            isSaving = false;
        }
    }
    
    function handlePrint() {
        // Create a print-friendly version of the warning with logo - fits A4 page
        const printContent = `
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="UTF-8">
                <title>${$locale === 'ar' ? 'تحذير رسمي' : 'Official Warning'}</title>
                <style>
                    @page { 
                        margin: 1cm; 
                        size: A4;
                    }
                    * { box-sizing: border-box; }
                    body { 
                        font-family: 'Arial', sans-serif; 
                        line-height: 1.4; 
                        direction: ${$locale === 'ar' ? 'rtl' : 'ltr'};
                        padding: 10px;
                        margin: 0;
                        font-size: 12px;
                        max-height: 100vh;
                    }
                    .header { 
                        text-align: center; 
                        border-bottom: 2px solid #333; 
                        padding-bottom: 10px; 
                        margin-bottom: 10px; 
                    }
                    .logo { 
                        max-width: 100px; 
                        height: auto; 
                        margin-bottom: 8px;
                    }
                    .header h1 { margin: 0; color: #c00; font-size: 18px; }
                    .content { 
                        white-space: pre-wrap; 
                        font-size: 11px; 
                        line-height: 1.3;
                        max-height: 45vh;
                        overflow: hidden;
                    }
                    .footer { margin-top: 15px; text-align: center; font-size: 10px; color: #666; }
                    .info-row { margin: 5px 0; font-size: 11px; }
                    .label { font-weight: bold; }
                    .signatures { 
                        display: flex; 
                        justify-content: space-between; 
                        margin-top: 30px; 
                        padding-top: 10px;
                    }
                    .signature-box { 
                        width: 45%; 
                        text-align: center; 
                    }
                    .signature-line { 
                        border-top: 1px solid #333; 
                        margin-top: 40px; 
                        padding-top: 5px; 
                    }
                    .signature-label { 
                        font-weight: bold; 
                        font-size: 11px; 
                    }
                    .signature-date { 
                        font-size: 10px; 
                        color: #666; 
                        margin-top: 3px; 
                    }
                </style>
            </head>
            <body>
                <div class="header">
                    <img src="/icons/logo.png" alt="Logo" class="logo" />
                    <h1>⚠️ تحذير رسمي / Official Warning</h1>
                </div>
                <div class="info-row">
                    <span class="label">الموظف / Employee:</span> 
                    ${selectedEmployeeDetails?.name_ar || ''} ${selectedEmployeeDetails?.name_ar && selectedEmployeeDetails?.name_en ? ' / ' : ''} ${selectedEmployeeDetails?.name_en || 'N/A'}
                </div>
                <div class="info-row">
                    <span class="label">رقم الهوية / ID Number:</span> 
                    ${selectedEmployeeDetails?.id_number || 'N/A'}
                </div>
                <div class="info-row">
                    <span class="label">المخالفة / Violation:</span> 
                    ${violation?.name_ar || ''} ${violation?.name_ar && violation?.name_en ? ' / ' : ''} ${violation?.name_en || 'N/A'}
                </div>
                ${fineAmount ? `<div class="info-row"><span class="label">مبلغ الغرامة / Fine Amount:</span> ${fineAmount} SAR</div>` : ''}
                <hr style="margin: 10px 0;">
                <div class="content">${warningNotes.replace(/\n/g, '<br>')}</div>
                
                <!-- Acknowledgment Signatures -->
                <div class="signatures">
                    <div class="signature-box">
                        <div class="signature-line">
                            <div class="signature-label">مدير الموارد البشرية / HR Manager</div>
                            <div class="signature-date">التاريخ / Date: _______________</div>
                        </div>
                    </div>
                    <div class="signature-box">
                        <div class="signature-line">
                            <div class="signature-label">توقيع الموظف / Employee Signature</div>
                            <div class="signature-date">التاريخ / Date: _______________</div>
                        </div>
                    </div>
                </div>
                
                <div class="footer">
                    تم إنشاء هذا بتاريخ / Generated on: ${new Date().toLocaleDateString()}
                </div>
            </body>
            </html>
        `;
        
        const printWindow = window.open('', '_blank');
        if (printWindow) {
            printWindow.document.write(printContent);
            printWindow.document.close();
            printWindow.focus();
            setTimeout(() => {
                printWindow.print();
            }, 250);
        }
    }
</script>

<div class="h-full flex flex-col bg-gradient-to-br from-orange-50 to-slate-50 font-sans">
    <div class="p-6 space-y-4 overflow-y-auto flex-1">
        <!-- Language Selection -->
        <div>
            <label class="block text-xs font-bold text-slate-600 uppercase tracking-wide mb-2">{$locale === 'ar' ? 'اختر اللغات' : 'Select Languages'}</label>
            <div class="flex flex-wrap gap-2">
                {#each availableLanguages as lang}
                    <button
                        type="button"
                        on:click={() => toggleLanguage(lang.code)}
                        class="px-3 py-1.5 text-xs font-semibold rounded-lg transition border-2 {selectedLanguages.includes(lang.code) ? 'bg-orange-600 text-white border-orange-600' : 'bg-white text-slate-700 border-slate-200 hover:border-orange-400'}"
                    >
                        {$locale === 'ar' ? lang.nameAr : lang.name}
                    </button>
                {/each}
            </div>
            {#if selectedLanguages.length === 0}
                <p class="text-xs text-red-600 mt-1">{$locale === 'ar' ? 'يجب تحديد لغة واحدة على الأقل' : 'Select at least one language'}</p>
            {/if}
        </div>

        <!-- Recourse Type Selection -->
        <div>
            <label class="block text-xs font-bold text-slate-600 uppercase tracking-wide mb-2">{$locale === 'ar' ? 'نوع الإجراء *' : 'Recourse Type *'}</label>
            <div class="flex flex-wrap gap-2">
                {#each recourseOptions as option}
                    <button
                        type="button"
                        on:click={() => { selectedRecourse = option.id; fineAmount = ''; }}
                        class="px-3 py-1.5 text-xs font-semibold rounded-lg transition border-2 {selectedRecourse === option.id ? 'bg-orange-600 text-white border-orange-600' : 'bg-white text-slate-700 border-slate-200 hover:border-orange-400'}"
                    >
                        {$locale === 'ar' ? option.labelAr : option.label}
                    </button>
                {/each}
            </div>
            {#if !selectedRecourse}
                <p class="text-xs text-red-600 mt-1">{$locale === 'ar' ? 'يجب تحديد نوع الإجراء' : 'Select a recourse type'}</p>
            {/if}
        </div>

        <!-- Fine Amount (if applicable) -->
        {#if selectedRecourse === 'warning_fine' || selectedRecourse === 'warning_fine_threat' || selectedRecourse === 'warning_fine_termination_threat'}
            <div>
                <label for="fine-amount" class="block text-xs font-bold text-slate-600 uppercase tracking-wide mb-2">{$locale === 'ar' ? 'مبلغ الغرامة *' : 'Fine Amount *'}</label>
                <input 
                    id="fine-amount"
                    type="number"
                    bind:value={fineAmount}
                    placeholder={$locale === 'ar' ? 'أدخل مبلغ الغرامة...' : 'Enter fine amount...'}
                    min="0"
                    step="0.01"
                    class="w-full px-3 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-orange-500 focus:border-orange-500 outline-none text-sm hover:border-slate-300 transition"
                />
                {#if !fineAmount}
                    <p class="text-xs text-red-600 mt-1">{$locale === 'ar' ? 'هذا الحقل مطلوب' : 'This field is required'}</p>
                {/if}
            </div>
        {/if}

        <!-- Violation & Employee Selection -->
        <div>
            <label class="block text-xs font-bold text-slate-600 uppercase tracking-wide mb-2">{$locale === 'ar' ? 'المخالفة واختيار الموظف' : 'Violation & Select Employee'}</label>
            <div class="flex items-center gap-3">
                {#if isNonEmployeeIncident}
                    <!-- Violation Search for non-employee incidents -->
                    <div class="flex-1 relative">
                        <div class="relative">
                            <input 
                                type="text" 
                                bind:value={violationSearchQuery}
                                on:focus={() => showViolationDropdown = true}
                                placeholder={$locale === 'ar' ? 'بحث عن مخالفة...' : 'Search violation...'}
                                class="w-full px-3 py-2 border border-orange-200 rounded-lg focus:ring-2 focus:ring-orange-500 focus:border-orange-500 outline-none text-sm hover:border-orange-300 transition bg-orange-50"
                            />
                            {#if selectedViolation}
                                <button 
                                    type="button"
                                    on:click={() => { selectedViolation = null; violationSearchQuery = ''; }}
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
                {:else if violation}
                    <div class="bg-orange-50 border border-orange-200 rounded px-3 py-1.5 flex items-center gap-2 flex-shrink-0">
                        <div class="w-1 h-6 bg-orange-500 rounded-full"></div>
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
                            class="w-full px-3 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-orange-500 focus:border-orange-500 outline-none text-sm hover:border-slate-300 transition pr-8"
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
                        <div class="absolute z-50 top-full left-0 right-0 mt-1 bg-white border border-slate-200 rounded-lg shadow-lg max-h-64 overflow-y-auto">
                            {#if filteredEmployees.length === 0}
                                <div class="px-3 py-2 text-sm text-slate-500">{$locale === 'ar' ? 'لم يتم العثور على موظفين' : 'No employees found'}</div>
                            {:else}
                                {#each filteredEmployees as emp}
                                    <button 
                                        type="button"
                                        on:click={() => selectEmployee(emp)}
                                        class="w-full px-3 py-2 text-left text-sm hover:bg-orange-50 border-b border-slate-100 last:border-b-0 transition"
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
                    <div class="bg-orange-50 border border-orange-200 rounded px-3 py-1.5 flex items-center gap-3">
                        <div class="w-1 h-6 bg-orange-500 rounded-full flex-shrink-0"></div>
                        <span class="text-xs font-bold text-orange-600">{selectedEmployeeDetails.id || '-'}</span>
                        <span class="text-slate-400">|</span>
                        <span class="text-sm font-medium text-slate-900">{$locale === 'ar' ? (selectedEmployeeDetails.name_ar || selectedEmployeeDetails.name_en) : selectedEmployeeDetails.name_en}</span>
                        <span class="text-slate-400">|</span>
                        <span class="text-sm font-bold text-orange-700">{selectedEmployeeDetails.id_number || ($locale === 'ar' ? 'لا يوجد' : 'No ID')}</span>
                    </div>
                </div>

                <!-- Incident: What Happened -->
                {#if incidentDescription}
                    <div>
                        <label class="block text-xs font-bold text-slate-600 uppercase tracking-wide mb-2">{$locale === 'ar' ? 'ماذا حدث (من التقرير)' : 'What Happened (from Report)'}</label>
                        <div class="bg-blue-50 border border-blue-200 rounded px-3 py-2 text-sm text-slate-700">
                            {incidentDescription}
                        </div>
                    </div>
                {/if}

                <!-- Incident: Witness Details -->
                {#if witnessDetails}
                    <div>
                        <label class="block text-xs font-bold text-slate-600 uppercase tracking-wide mb-2">{$locale === 'ar' ? 'تفاصيل الشهود (من التقرير)' : 'Witness Details (from Report)'}</label>
                        <div class="bg-blue-50 border border-blue-200 rounded px-3 py-2 text-sm text-slate-700">
                            {witnessDetails}
                        </div>
                    </div>
                {/if}

                <!-- Branch Selection -->
                <div>
                    <label for="branch-select" class="block text-xs font-bold text-slate-600 uppercase tracking-wide mb-2">{$locale === 'ar' ? 'اختيار الفرع *' : 'Select Branch *'}</label>
                    <select 
                        id="branch-select"
                        bind:value={selectedBranch}
                        class="w-full px-3 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-orange-500 focus:border-orange-500 outline-none text-sm hover:border-slate-300 transition"
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

                <!-- Investigation Report (if available) -->
                {#if investigationReport}
                    <div>
                        <label class="block text-xs font-bold text-slate-600 uppercase tracking-wide mb-2">{$locale === 'ar' ? 'تقرير التحقيق' : 'Investigation Report'}</label>
                        <div class="bg-indigo-50 border border-indigo-200 rounded px-3 py-2 text-sm text-slate-700 whitespace-pre-wrap max-h-48 overflow-y-auto">
                            {investigationReport}
                        </div>
                    </div>
                {/if}

                <!-- Report and Action -->
                <div>
                    <label for="warning-notes" class="block text-xs font-bold text-slate-600 uppercase tracking-wide mb-2">
                        {$locale === 'ar' ? 'التقرير والإجراء' : 'Report and Action'}{#if !viewMode} *{/if}
                        {#if viewMode}
                            <span class="text-xs text-slate-400 font-normal ml-2">({$locale === 'ar' ? 'للعرض فقط' : 'View Only'})</span>
                        {/if}
                    </label>
                    <textarea 
                        id="warning-notes"
                        bind:value={warningNotes}
                        readonly={viewMode}
                        placeholder={$locale === 'ar' ? 'أدخل التقرير والإجراء المطلوب...' : 'Enter report and action required...'}
                        rows={Math.max(8, warningNotes.split('\n').length + 2)}
                        class="w-full px-3 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-orange-500 focus:border-orange-500 outline-none text-sm hover:border-slate-300 transition resize-y min-h-[200px] max-h-[500px] {viewMode ? 'bg-slate-50 cursor-default' : ''}"
                    ></textarea>
                    {#if !warningNotes.trim() && !viewMode}
                        <p class="text-xs text-red-600 mt-1">{$locale === 'ar' ? 'هذا الحقل مطلوب' : 'This field is required'}</p>
                    {/if}
                    <div class="flex gap-2 mt-2">
                        {#if !viewMode}
                            <button
                                type="button"
                                on:click={generateReportUsingAI}
                                disabled={isGenerating || !selectedLanguages.length || !selectedRecourse}
                                class="px-4 py-1.5 text-xs font-semibold rounded-lg bg-blue-600 text-white hover:bg-blue-700 transition disabled:bg-gray-400 disabled:cursor-not-allowed flex items-center gap-2"
                            >
                                {#if isGenerating}
                                    <span class="animate-spin">⏳</span>
                                    {$locale === 'ar' ? 'جاري الإنشاء...' : 'Generating...'}
                                {:else}
                                    ✨ {$locale === 'ar' ? 'إنشاء بالذكاء الاصطناعي' : 'Generate using AI'}
                                {/if}
                            </button>
                            <button
                                type="button"
                                on:click={handleIssueWarning}
                                disabled={isSaving || !warningNotes.trim() || !selectedEmployee || !selectedRecourse}
                                class="px-4 py-1.5 text-xs font-semibold rounded-lg bg-green-600 text-white hover:bg-green-700 transition disabled:bg-gray-400 disabled:cursor-not-allowed flex items-center gap-2"
                            >
                                {#if isSaving}
                                    <span class="animate-spin">⏳</span>
                                    {$locale === 'ar' ? 'جاري الحفظ...' : 'Saving...'}
                                {:else}
                                    💾 {$locale === 'ar' ? 'حفظ' : 'Save'}
                                {/if}
                            </button>
                        {/if}
                        <button
                            type="button"
                            on:click={handlePrint}
                            disabled={!warningNotes.trim()}
                            class="px-4 py-1.5 text-xs font-semibold rounded-lg bg-purple-600 text-white hover:bg-purple-700 transition disabled:bg-gray-400 disabled:cursor-not-allowed flex items-center gap-2"
                        >
                            🖨️ {$locale === 'ar' ? 'طباعة' : 'Print'}
                        </button>
                    </div>
                </div>
            {/if}
        {/if}
    </div>

    <div class="px-6 py-4 bg-white border-t border-slate-200 flex gap-3 justify-end flex-shrink-0 shadow-lg">
        <!-- Buttons moved inline with Generate button -->
    </div>
</div>

<style>
    :global(.font-sans) {
        font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    }
</style>
