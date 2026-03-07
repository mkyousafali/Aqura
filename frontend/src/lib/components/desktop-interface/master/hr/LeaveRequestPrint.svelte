<script lang="ts">
    import { _ as t, locale } from '$lib/i18n';
    import { onMount } from 'svelte';

    export let dayOff: any = null;
    export let onClose = () => {};

    let printWindow: Window | null = null;
    let appIconUrl: string = '📋'; // Fallback emoji
    let supabase: any = null;
    let iconLoaded = false;

    onMount(async () => {
        // Load Supabase client and fetch icon first
        try {
            const mod = await import('$lib/utils/supabase');
            supabase = mod.supabase;
            
            // Fetch app icon
            const { data: appIcons } = await supabase
                .from('app_icons')
                .select('storage_path')
                .eq('name', 'Aqura Logo')
                .single();
            
            if (appIcons?.storage_path) {
                const { data: { publicUrl } } = supabase.storage
                    .from('app-icons')
                    .getPublicUrl(appIcons.storage_path);
                
                if (publicUrl) {
                    appIconUrl = publicUrl;
                }
            }
        } catch (err) {
            console.error('Error loading app icon:', err);
            // Keep fallback emoji
        } finally {
            iconLoaded = true;
        }
        
        // Auto-open print dialog AFTER icon is loaded
        if (printWindow === null && iconLoaded) {
            // Small delay to ensure icon URL is set before generating print HTML
            await new Promise(resolve => setTimeout(resolve, 100));
            openPrintDialog();
        }
    });

    function getEmployeeName(): string {
        return $locale === 'ar'
            ? (dayOff.employee_name_ar || dayOff.employee_name_en || 'N/A')
            : (dayOff.employee_name_en || dayOff.employee_name_ar || 'N/A');
    }

    function getReasonText(): string {
        return $locale === 'ar'
            ? (dayOff.reason_ar || dayOff.reason_en || 'N/A')
            : (dayOff.reason_en || dayOff.reason_ar || 'N/A');
    }

    function getApprovedDaysCount(): number {
        // If this is a grouped leave, count approved days
        if (dayOff._dayCount && dayOff._dayCount > 1) {
            return dayOff._statusCounts?.approved || 0;
        }
        // Single day leave
        return dayOff.approval_status === 'approved' ? 1 : 0;
    }

    function getApprovedDaysText(): string {
        const count = getApprovedDaysCount();
        const countText = $locale === 'ar' ? 'أيام' : 'days';
        
        if (dayOff.approval_status === 'approved') {
            const approverName = $locale === 'ar' 
                ? (dayOff.approver_name_ar || dayOff.approver_name_en || 'نظام الإدارة')
                : (dayOff.approver_name_en || dayOff.approver_name_ar || 'Aqura Management System');
            
            const approvalText = $locale === 'ar'
                ? `تمت الموافقة بواسطة ${approverName} عبر نظام إدارة أكوا`
                : `Approved by ${approverName} through the Aqura Management System`;
            return `${count} ${countText}\n(${approvalText})`;
        }
        
        return `${count} ${countText}`;
    }

    function getLeaveDates(): string {
        if (dayOff._dayCount && dayOff._dayCount > 1) {
            return `${formatDate(dayOff._dateFrom)} - ${formatDate(dayOff._dateTo)}`;
        }
        return formatDate(dayOff.day_off_date);
    }

    function getTotalDays(): number {
        if (dayOff._dayCount && dayOff._dayCount > 1) {
            return dayOff._dayCount;
        }
        return 1;
    }

    function formatPrintDateTime(): { date: string; time: string } {
        const now = new Date();
        
        // Format date as dd-mm-yyyy
        const day = String(now.getDate()).padStart(2, '0');
        const month = String(now.getMonth() + 1).padStart(2, '0');
        const year = now.getFullYear();
        const date = `${day}-${month}-${year}`;
        
        // Format time as 12-hour format with AM/PM
        const hours = now.getHours();
        const minutes = String(now.getMinutes()).padStart(2, '0');
        const seconds = String(now.getSeconds()).padStart(2, '0');
        const ampm = hours >= 12 ? 'PM' : 'AM';
        const hours12 = String(hours % 12 || 12).padStart(2, '0');
        const time = `${hours12}:${minutes}:${seconds} ${ampm}`;
        
        return { date, time };
    }

    function formatDate(dateStr: string): string {
        if (!dateStr) return 'N/A';
        try {
            const date = new Date(dateStr);
            const options: Intl.DateTimeFormatOptions = {
                year: 'numeric',
                month: 'long',
                day: 'numeric'
            };
            return date.toLocaleDateString($locale === 'ar' ? 'ar-SA' : 'en-US', options);
        } catch {
            return dateStr;
        }
    }

    function openPrintDialog() {
        const printContent = generatePrintHTML();
        printWindow = window.open('', '', 'height=900,width=1000');
        
        if (printWindow) {
            printWindow.document.write(printContent);
            printWindow.document.close();
            
            // Trigger print after content is loaded
            setTimeout(() => {
                if (printWindow) {
                    printWindow.print();
                    printWindow.close();
                    printWindow = null;
                }
            }, 250);
        }
    }

    function generatePrintHTML(): string {
        const isArabic = $locale === 'ar';
        const direction = isArabic ? 'rtl' : 'ltr';
        
        return `
<!DOCTYPE html>
<html dir="${direction}" lang="${$locale}">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${isArabic ? 'طلب إجازة' : 'Leave Request'}</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: #ffffff;
            color: #000000;
            line-height: 1.4;
            padding: 0;
            margin: 0;
        }
        
        @media print {
            body {
                padding: 0;
                margin: 0;
                width: 210mm;
            }
            @page {
                size: A4;
                margin: 8mm;
            }
        }
        
        .container {
            width: 210mm;
            margin: 0;
            background: white;
            padding: 8mm;
            box-sizing: border-box;
            display: flex;
            flex-direction: column;
            page-break-inside: avoid;
            overflow: hidden;
            word-wrap: break-word;
            overflow-wrap: break-word;
        }
        
        html[dir="rtl"] .container {
            direction: rtl;
        }
        
        .header {
            text-align: center;
            margin-bottom: 8px;
            border-bottom: 2px solid #0f172a;
            padding-bottom: 4px;
            flex-shrink: 0;
        }
        
        html[dir="rtl"] .header {
            direction: rtl;
        }
        
        .logo {
            font-size: 48px;
            margin-bottom: 6px;
            height: 80px;
            display: flex;
            align-items: center;
            justify-content: center;
            flex-shrink: 0;
        }
        
        html[dir="rtl"] .logo {
            direction: rtl;
        }
        
        .logo img {
            max-width: 100%;
            max-height: 100%;
            height: auto;
            object-fit: contain;
        }
        
        .title {
            font-size: 22px;
            font-weight: 900;
            color: #0f172a;
            margin-bottom: 2px;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        
        html[dir="rtl"] .title {
            direction: rtl;
        }
        
        .subtitle {
            font-size: 11px;
            color: #000000;
            font-style: italic;
        }
        
        .form-section {
            margin-bottom: 7px;
            flex-shrink: 0;
            page-break-inside: avoid;
        }
        
        html[dir="rtl"] .form-section {
            direction: rtl;
        }
        
        .section-title {
            font-size: 11px;
            font-weight: 900;
            color: #000000;
            background: #ffffff;
            padding: 6px 10px;
            margin-bottom: 5px;
            text-transform: uppercase;
            letter-spacing: 0.3px;
            border: 1px solid #000000;
            border-radius: 2px;
            flex-shrink: 0;
        }
        
        html[dir="rtl"] .section-title {
            direction: rtl;
            text-align: center;
        }
        
        .form-row {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 15px;
            margin-bottom: 5px;
            page-break-inside: avoid;
            min-width: 0;
        }
        
        html[dir="rtl"] .form-row {
            direction: rtl;
        }
        
        .form-row.full {
            grid-template-columns: 1fr;
        }
        
        .form-group {
            display: flex;
            flex-direction: column;
            flex-shrink: 0;
            min-width: 0;
            word-wrap: break-word;
            overflow-wrap: break-word;
        }
        
        .form-label {
            font-size: 10px;
            font-weight: 900;
            color: #000000;
            text-transform: uppercase;
            letter-spacing: 0.3px;
            margin-bottom: 2px;
            text-decoration: underline;
            line-height: 1.2;
            word-wrap: break-word;
            overflow-wrap: break-word;
        }
        
        html[dir="rtl"] .form-label {
            direction: rtl;
            text-align: right;
        }
        
        html[dir="ltr"] .form-label {
            text-align: left;
        }
        
        .form-value {
            font-size: 12px;
            color: #000000;
            font-weight: 500;
            padding: 2px 0;
            border-bottom: 1px solid #000000;
            min-height: 16px;
            line-height: 1.2;
            word-break: break-word;
            word-wrap: break-word;
            overflow-wrap: break-word;
            max-width: 100%;
            unicode-bidi: isolate;
        }
        
        html[dir="rtl"] .form-value {
            direction: rtl;
            text-align: right;
        }
        
        .form-value.highlight {
            background: #ffffff;
            padding: 4px 8px;
            border-left: 3px solid #0f172a;
        }
        
        html[dir="rtl"] .form-value.highlight {
            border-left: none;
            border-right: 3px solid #0f172a;
        }
        
        .signature-section {
            margin-top: 4px;
            border-top: 1px solid #0f172a;
            padding-top: 4px;
            flex-shrink: 0;
            page-break-inside: avoid;
        }
        
        html[dir="rtl"] .signature-section {
            direction: rtl;
        }
        
        .signature-row {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 10px;
            margin-bottom: 4px;
            page-break-inside: avoid;
            min-width: 0;
        }
        
        html[dir="rtl"] .signature-row {
            direction: rtl;
        }
        
        .signature-block {
            text-align: center;
            flex-shrink: 0;
        }
        
        .signature-line {
            border-top: 1px solid #000000;
            margin: 15px 0 1px 0;
            min-height: 35px;
        }
        
        .signature-name {
            font-size: 10px;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 0.2px;
            margin-top: 2px;
            line-height: 1.1;
        }
        
        .date-field {
            margin-top: 6px;
            text-align: center;
            flex-shrink: 0;
        }
        
        .signature-card {
            border: 1px solid #000000;
            border-radius: 2px;
            padding: 8px;
            text-align: center;
            flex-shrink: 0;
            page-break-inside: avoid;
            background: #ffffff;
            min-width: 0;
            word-wrap: break-word;
            overflow-wrap: break-word;
        }
        
        html[dir="rtl"] .signature-card {
            direction: rtl;
        }
        
        .signature-card-title {
            font-size: 10px;
            font-weight: 700;
            color: #0f172a;
            margin-bottom: 4px;
            text-transform: uppercase;
            letter-spacing: 0.2px;
            border-bottom: 1px solid #000000;
            padding-bottom: 2px;
            line-height: 1.1;
            word-wrap: break-word;
            overflow-wrap: break-word;
        }
        
        html[dir="rtl"] .signature-card-title {
            direction: rtl;
            text-align: center;
        }
        
        .signature-card-content {
            display: flex;
            flex-direction: column;
            gap: 4px;
            min-width: 0;
            word-wrap: break-word;
            overflow-wrap: break-word;
        }
        
        html[dir="rtl"] .signature-card-content {
            direction: rtl;
        }
        
        .signature-card-line {
            border-top: 1px solid #000000;
            min-height: 40px;
            margin: 2px 0;
        }
        
        .signature-card-date {
            display: grid;
            grid-template-columns: auto 1fr;
            gap: 4px;
            align-items: center;
            font-size: 10px;
        }
        
        .signature-card-date-label {
            font-weight: 600;
            color: #000000;
        }
        
        .signature-card-date-line {
            border-top: 1px solid #000000;
            min-height: 28px;
        }
        
        .footer {
            margin-top: 4px;
            font-size: 8px;
            text-align: center;
            color: #000000;
            padding-top: 2px;
            flex-shrink: 0;
            line-height: 1.2;
        }
        
        html[dir="rtl"] .footer {
            direction: rtl;
        }
        
        .status-badge {
            display: inline-block;
            padding: 3px 8px;
            border-radius: 2px;
            font-weight: 700;
            font-size: 10px;
            text-transform: uppercase;
        }
        
        .status-approved {
            background: #dcfce7;
            color: #166534;
        }
        
        .status-pending {
            background: #fef3c7;
            color: #92400e;
        }
        
        .status-rejected {
            background: #fee2e2;
            color: #991b1b;
        }
        
        @media print {
            .container {
                box-shadow: none;
            }
            body {
                background: white;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <!-- Header -->
        <div class="header">
            <div class="logo">
                ${appIconUrl.startsWith('http') ? `<img src="${appIconUrl}" alt="Aqura Logo" style="height: ${isArabic ? '50px' : '80px'};" />` : '📋'}
            </div>
            <div class="title">${isArabic ? 'طلب إجازة' : 'LEAVE REQUEST'}</div>
            <div class="subtitle">${isArabic ? 'نموذج طلب الإجازة الرسمي' : 'Official Leave Request Form'}</div>
        </div>
        
        <!-- Submission Info Section -->
        <div class="form-section" style="margin-bottom: 6px; border-bottom: 1px solid #000000; padding-bottom: 4px;">
            <div class="form-row">
                <div class="form-group" style="flex: 1;">
                    <label class="form-label">${isArabic ? 'تاريخ التقديم' : 'Leave Submitted Date'}</label>
                    <div class="form-value highlight" style="font-weight: 700;">${dayOff.approval_requested_at ? formatDate(dayOff.approval_requested_at) : 'N/A'}</div>
                </div>
                <div class="form-group" style="flex: 2;">
                    <label class="form-label">${isArabic ? 'الفرع والموقع' : 'Branch & Location'}</label>
                    <div class="form-value highlight" style="font-weight: 700;">
                        ${isArabic 
                            ? (dayOff.branch_name_ar || dayOff.branch_name_en) 
                            : dayOff.branch_name_en}
                        <div style="font-size: 10px; font-weight: 500; margin-top: 2px;">
                            ${isArabic 
                                ? (dayOff.branch_location_ar || dayOff.branch_location_en || '') 
                                : (dayOff.branch_location_en || '')}
                        </div>
                    </div>
                </div>
            </div>
        </div>
        
        <!-- Employee Information Section -->
        <div class="form-section">
            <div class="section-title">${isArabic ? 'معلومات الموظف' : 'Employee Information'}</div>
            
            <div class="form-row">
                <div class="form-group">
                    <label class="form-label">${isArabic ? 'نام الموظف' : 'Employee Name'}</label>
                    <div class="form-value highlight">${getEmployeeName()}</div>
                </div>
                <div class="form-group">
                    <label class="form-label">${isArabic ? 'معرف الموظف' : 'Employee ID'}</label>
                    <div class="form-value highlight">${dayOff.employee_id || 'N/A'}</div>
                </div>
            </div>
            
            <div class="form-row">
                <div class="form-group">
                    <label class="form-label">${isArabic ? 'رقم الهوية/الإقامة' : 'National/Resident ID Card Number'}</label>
                    <div class="form-value highlight">${dayOff.employee_id_number || 'N/A'}</div>
                </div>
                <div class="form-group">
                    <label class="form-label">${isArabic ? 'الجنسية' : 'Nationality'}</label>
                    <div class="form-value highlight">${isArabic ? (dayOff.nationality_name_ar || dayOff.nationality_name_en) : (dayOff.nationality_name_en || dayOff.nationality_name_ar) || 'N/A'}</div>
                </div>
            </div>
            
            <div class="form-row">
                <div class="form-group">
                    <label class="form-label">${isArabic ? 'البريد الإلكتروني' : 'Email'}</label>
                    <div class="form-value">${dayOff.employee_email || 'N/A'}</div>
                </div>
                <div class="form-group">
                    <label class="form-label">${isArabic ? 'رقم واتس اب' : 'WhatsApp Number'}</label>
                    <div class="form-value">${dayOff.employee_whatsapp || 'N/A'}</div>
                </div>
            </div>
        </div>
        
        <!-- Replacement Employee Section -->
        <div class="form-section">
            <div class="section-title">${isArabic ? 'الموظف البديل' : 'Replacement Employee'}</div>
            
            <div class="form-row">
                <div class="form-group">
                    <label class="form-label">${isArabic ? 'اسم الموظف البديل' : 'Replacement Employee Name'}</label>
                    <div class="form-value" style="min-height: 28px;"></div>
                </div>
                <div class="form-group">
                    <label class="form-label">${isArabic ? 'معرف الموظف البديل' : 'Replacement Employee ID'}</label>
                    <div class="form-value" style="min-height: 28px;"></div>
                </div>
            </div>
        </div>
        
        <!-- Leave Details Section -->
        <div class="form-section">
            <div class="section-title">${isArabic ? 'تفاصيل الإجازة' : 'Leave Details'}</div>
            
            <div class="form-row">
                <div class="form-group">
                    <label class="form-label">${isArabic ? 'تاريخ الإجازة' : 'Leave Date(s)'}</label>
                    <div class="form-value highlight">${getLeaveDates()}</div>
                </div>
                <div class="form-group">
                    <label class="form-label">${isArabic ? 'إجمالي أيام الإجازة' : 'Total Leave Days'}</label>
                    <div class="form-value highlight">${getTotalDays()} ${isArabic ? 'أيام' : 'days'}</div>
                </div>
            </div>
            
            <div class="form-row">
                <div class="form-group">
                    <label class="form-label">${isArabic ? 'أيام الموافقة' : 'Approved Days'}</label>
                    <div class="form-value highlight" style="white-space: pre-line; line-height: 1.6;">${getApprovedDaysText()}</div>
                </div>
                <div class="form-group">
                    <label class="form-label">${isArabic ? 'سبب الإجازة' : 'Leave Reason'}</label>
                    <div class="form-value">${getReasonText()}</div>
                </div>
            </div>
            
            ${dayOff.description ? `
            <div class="form-row full">
                <div class="form-group">
                    <label class="form-label">${isArabic ? 'ملاحظات' : 'Notes'}</label>
                    <div class="form-value" style="border: 1px solid #000000; padding: 4px; min-height: 25px; font-size: 11px; overflow: hidden; max-height: 35px;">${dayOff.description}</div>
                </div>
            </div>
            ` : ''}
        </div>
        
        <!-- Remarks Section -->
        <div class="form-section">
            <div class="section-title">${isArabic ? 'ملاحظات إضافية' : 'Remarks'}</div>
            <div style="border: 1px solid #000000; min-height: 50px; padding: 4px; page-break-inside: avoid;"></div>
        </div>
        
        <!-- Signature Section -->
        <div class="signature-section">
            <div class="section-title">${isArabic ? 'التوقيعات والموافقات' : 'Signatures & Approvals'}</div>
            
            <div style="display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 10px; margin-bottom: 10px; page-break-inside: avoid;">
                <!-- Employee Card -->
                <div class="signature-card">
                    <div class="signature-card-title">${isArabic ? 'الموظف' : 'Employee'}</div>
                    <div class="signature-card-content">
                        <div class="signature-card-line"></div>
                        <div class="signature-card-date">
                            <span class="signature-card-date-label">${isArabic ? 'ت:' : 'D:'}</span>
                            <div class="signature-card-date-line"></div>
                        </div>
                    </div>
                </div>
                
                <!-- Replacement Employee Card -->
                <div class="signature-card">
                    <div class="signature-card-title">${isArabic ? 'الموظف البديل' : 'Replacement Emp.'}</div>
                    <div class="signature-card-content">
                        <div class="signature-card-line"></div>
                        <div class="signature-card-date">
                            <span class="signature-card-date-label">${isArabic ? 'ت:' : 'D:'}</span>
                            <div class="signature-card-date-line"></div>
                        </div>
                    </div>
                </div>
                
                <!-- Direct Manager Card -->
                <div class="signature-card">
                    <div class="signature-card-title">${isArabic ? 'المدير المباشر' : 'Direct Manager'}</div>
                    <div class="signature-card-content">
                        <div class="signature-card-line"></div>
                        <div class="signature-card-date">
                            <span class="signature-card-date-label">${isArabic ? 'ت:' : 'D:'}</span>
                            <div class="signature-card-date-line"></div>
                        </div>
                    </div>
                </div>
            </div>
            
            <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 10px; page-break-inside: avoid;">
                <!-- HR Manager Card -->
                <div class="signature-card">
                    <div class="signature-card-title">${isArabic ? 'مدير إدارة الموارد البشرية' : 'HR Manager'}</div>
                    <div class="signature-card-content">
                        <div class="signature-card-line"></div>
                        <div class="signature-card-date">
                            <span class="signature-card-date-label">${isArabic ? 'ت:' : 'D:'}</span>
                            <div class="signature-card-date-line"></div>
                        </div>
                    </div>
                </div>
                
                <!-- General Manager Card -->
                <div class="signature-card">
                    <div class="signature-card-title">${isArabic ? 'المدير العام' : 'General Manager'}</div>
                    <div class="signature-card-content">
                        <div class="signature-card-line"></div>
                        <div class="signature-card-date">
                            <span class="signature-card-date-label">${isArabic ? 'ت:' : 'D:'}</span>
                            <div class="signature-card-date-line"></div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
        
        <!-- Footer -->
        <div class="footer">
            <p>${isArabic ? 'تم طباعة هذا النموذج بتاريخ: ' : 'This form was printed on: '}${formatPrintDateTime().date} ${formatPrintDateTime().time}</p>
            <p>${isArabic ? 'أكورا' : 'Aqura'}</p>
        </div>
    </div>
</body>
</html>
        `;
    }

    function handleClose() {
        if (printWindow) {
            printWindow.close();
            printWindow = null;
        }
        onClose();
    }
</script>

<!-- Dialog Overlay -->
<div class="fixed inset-0 bg-black bg-opacity-40 flex items-center justify-center z-50 backdrop-blur-sm">
    <div class="bg-white rounded-2xl shadow-2xl max-w-2xl w-full max-h-96 overflow-y-auto">
        <!-- Header -->
        <div class="sticky top-0 bg-gradient-to-r from-blue-50 to-cyan-50 border-b border-blue-200 px-6 py-4 flex items-center justify-between">
            <div class="flex items-center gap-3">
                {#if appIconUrl.startsWith('http')}
                    <img src={appIconUrl} alt="Aqura Logo" class="h-12 w-12 object-contain" />
                {:else}
                    <span class="text-3xl">🖨️</span>
                {/if}
                <div>
                    <h2 class="text-xl font-bold text-slate-800">
                        {$locale === 'ar' ? 'معاينة طلب الإجازة' : 'Leave Request Preview'}
                    </h2>
                    <p class="text-sm text-slate-600">{getEmployeeName()}</p>
                </div>
            </div>
            <button 
                on:click={handleClose}
                class="text-slate-500 hover:text-slate-700 text-2xl"
            >
                ✕
            </button>
        </div>

        <!-- Content -->
        <div class="p-6 space-y-4">
            <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 text-sm text-blue-800">
                <p class="font-semibold">
                    {$locale === 'ar' ? '📣 سيتم فتح نافذة الطباعة تلقائياً. اختر الطابعة أو احفظ كـ PDF.' : '📣 Print dialog will open automatically. Select printer or save as PDF.'}
                </p>
            </div>

            <div class="grid grid-cols-2 gap-4 text-sm">
                <div class="bg-slate-50 p-3 rounded-lg">
                    <p class="text-slate-600">{$locale === 'ar' ? 'اسم الموظف' : 'Employee Name'}</p>
                    <p class="font-semibold text-slate-800 mt-1">{getEmployeeName()}</p>
                </div>
                <div class="bg-slate-50 p-3 rounded-lg">
                    <p class="text-slate-600">{$locale === 'ar' ? 'معرف الموظف' : 'Employee ID'}</p>
                    <p class="font-semibold text-slate-800 mt-1">{dayOff.employee_id}</p>
                </div>
                <div class="bg-slate-50 p-3 rounded-lg">
                    <p class="text-slate-600">{$locale === 'ar' ? 'رقم الهوية/الإقامة' : 'National/Resident ID'}</p>
                    <p class="font-semibold text-slate-800 mt-1">{dayOff.employee_id_number || 'N/A'}</p>
                </div>
                <div class="bg-slate-50 p-3 rounded-lg">
                    <p class="text-slate-600">{$locale === 'ar' ? 'الجنسية' : 'Nationality'}</p>
                    <p class="font-semibold text-slate-800 mt-1">{$locale === 'ar' ? (dayOff.nationality_name_ar || dayOff.nationality_name_en) : (dayOff.nationality_name_en || dayOff.nationality_name_ar) || 'N/A'}</p>
                </div>
                <div class="bg-slate-50 p-3 rounded-lg">
                    <p class="text-slate-600">{$locale === 'ar' ? 'تواريخ الإجازة' : 'Leave Dates'}</p>
                    <p class="font-semibold text-slate-800 mt-1">{getLeaveDates()}</p>
                </div>
                <div class="bg-slate-50 p-3 rounded-lg">
                    <p class="text-slate-600">{$locale === 'ar' ? 'عدد الأيام' : 'Total Days'}</p>
                    <p class="font-semibold text-slate-800 mt-1">{getTotalDays()}</p>
                </div>
            </div>
        </div>

        <!-- Footer -->
        <div class="bg-slate-50 border-t border-slate-200 px-6 py-4 flex gap-3 justify-end">
            <button 
                on:click={handleClose}
                class="px-4 py-2 border border-slate-300 text-slate-700 rounded-lg hover:bg-slate-100 transition"
            >
                {$locale === 'ar' ? 'إغلاق' : 'Close'}
            </button>
            <button 
                on:click={openPrintDialog}
                class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition flex items-center gap-2"
            >
                🖨️ {$locale === 'ar' ? 'طباعة مرة أخرى' : 'Print Again'}
            </button>
        </div>
    </div>
</div>
