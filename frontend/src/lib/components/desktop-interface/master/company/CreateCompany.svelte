<script lang="ts">
	import { onMount } from 'svelte';
	import BranchMaster from '$lib/components/desktop-interface/master/BranchMaster.svelte';
	import { locale } from '$lib/i18n';

	let activeTab: 'create' | 'manage' | 'branches' = 'create';
	let documentSection: 'create' | 'manage' = 'create';
	let supabase: any = null;
	let companies: Array<{ id: number; name_ar: string; name_en: string; owner_emails?: string[]; owner_whatsapp_numbers?: string[]; created_at: string }> = [];
	let companyBranches: Array<{ id: number; company_id: number; name_ar: string; name_en: string; location_ar: string; location_en: string }> = [];
	let showForm = false;
	let editingCompanyId: number | null = null;
	let nameAr = '';
	let nameEn = '';
	let ownerEmails = [''];
	let ownerWhatsAppNumbers = [''];
	let loading = true;
	let saving = false;
	let errorMessage = '';
	type DocumentScope = 'common' | 'branch_wise';
	type DocumentType = { id: number | string; name_ar: string; name_en: string; scope: DocumentScope; requires_number: boolean; requires_expiry_date: boolean; requires_upload: boolean; created_at?: string; source: 'default' | 'custom' };
	const defaultDocumentTypes: DocumentType[] = [
		{ id: 'default-commercial-activity', name_en: 'Commercial Activity License', name_ar: 'رخصة النشاط التجاري', scope: 'common', requires_number: true, requires_expiry_date: true, requires_upload: true, source: 'default' },
		{ id: 'default-municipal', name_en: 'Municipal License', name_ar: 'رخصة البلدية', scope: 'branch_wise', requires_number: true, requires_expiry_date: true, requires_upload: true, source: 'default' },
		{ id: 'default-salamah', name_en: 'Salamah License', name_ar: 'ترخيص سلامة', scope: 'branch_wise', requires_number: true, requires_expiry_date: true, requires_upload: true, source: 'default' },
		{ id: 'default-lease', name_en: 'Commercial Lease Contract', name_ar: 'عقد الإيجار التجاري', scope: 'branch_wise', requires_number: true, requires_expiry_date: true, requires_upload: true, source: 'default' },
		{ id: 'default-address', name_en: 'National Address', name_ar: 'العنوان الوطني', scope: 'common', requires_number: false, requires_expiry_date: false, requires_upload: true, source: 'default' },
		{ id: 'default-fire-alarm', name_en: 'Fire Alarm System Maintenance Contract', name_ar: 'عقد صيانة نظام إنذار الحريق', scope: 'branch_wise', requires_number: false, requires_expiry_date: true, requires_upload: true, source: 'default' },
		{ id: 'default-scale-calibration', name_en: 'Weighing Scale Calibration Certificate', name_ar: 'شهادة معايرة الميزان', scope: 'branch_wise', requires_number: false, requires_expiry_date: true, requires_upload: true, source: 'default' }
	];
	let documentTypes: DocumentType[] = [];
	$: allDocumentTypes = [...defaultDocumentTypes, ...documentTypes];
	let showDocumentForm = false;
	let documentNameAr = '';
	let documentNameEn = '';
	let documentScope: DocumentScope = 'common';
	let documentRequiresNumber = false;
	let documentRequiresExpiryDate = false;
	let documentRequiresUpload = true;
	let showManageDocumentPicker = false;
	let selectedManageDocumentId = '';
	let selectedManageCompanyId = '';
	let selectedManageBranchId = '';
	let manageDocumentNumber = '';
	let manageExpiryDate = '';
	let selectedManageDocumentFile: File | null = null;
	let documentNotificationEmails: string[] = [];
	let documentNotificationWhatsAppNumbers: string[] = [];
	let notificationPeriods = ['30', '15', '5'];
	let reminderTime = '09:00';
	$: selectedManageDocument = allDocumentTypes.find((document) => String(document.id) === selectedManageDocumentId) || null;
	$: availableManageBranches = selectedManageCompanyId
		? companyBranches.filter((branch) => String(branch.company_id) === selectedManageCompanyId)
		: [];
	let documentsLoading = true;
	let documentSaving = false;
	let documentError = '';

	onMount(async () => {
		const mod = await import('$lib/utils/supabase');
		supabase = mod.supabase;
		await loadCompanies();
		await loadCompanyBranches();
		await loadDocumentTypes();
	});

	async function loadCompanyBranches() {
		if (!supabase) return;
		const { data } = await supabase
			.from('branches')
			.select('id, company_id, name_ar, name_en, location_ar, location_en')
			.eq('is_active', true)
			.order('name_en', { ascending: true });
		companyBranches = data || [];
	}

	function resetManageDocumentFields() {
		selectedManageCompanyId = '';
		selectedManageBranchId = '';
		manageDocumentNumber = '';
		manageExpiryDate = '';
		selectedManageDocumentFile = null;
		documentNotificationEmails = [];
		documentNotificationWhatsAppNumbers = [];
		notificationPeriods = ['30', '15', '5'];
		reminderTime = '09:00';
	}

	function changeManageCompany() {
		selectedManageBranchId = '';
		const company = companies.find((item) => String(item.id) === selectedManageCompanyId);
		documentNotificationEmails = company?.owner_emails?.length ? [...company.owner_emails] : [''];
		documentNotificationWhatsAppNumbers = company?.owner_whatsapp_numbers?.length ? [...company.owner_whatsapp_numbers] : [''];
	}

	function addDocumentNotificationEmail() {
		documentNotificationEmails = [...documentNotificationEmails, ''];
	}

	function removeDocumentNotificationEmail(index: number) {
		documentNotificationEmails = documentNotificationEmails.length === 1 ? [''] : documentNotificationEmails.filter((_, itemIndex) => itemIndex !== index);
	}

	function addDocumentNotificationWhatsApp() {
		documentNotificationWhatsAppNumbers = [...documentNotificationWhatsAppNumbers, ''];
	}

	function removeDocumentNotificationWhatsApp(index: number) {
		documentNotificationWhatsAppNumbers = documentNotificationWhatsAppNumbers.length === 1 ? [''] : documentNotificationWhatsAppNumbers.filter((_, itemIndex) => itemIndex !== index);
	}

	function addNotificationPeriod() {
		if (notificationPeriods.length < 3) notificationPeriods = [...notificationPeriods, ''];
	}

	function removeNotificationPeriod(index: number) {
		notificationPeriods = notificationPeriods.length === 1 ? [''] : notificationPeriods.filter((_, itemIndex) => itemIndex !== index);
	}

	function selectManageDocumentFile(event: Event) {
		const input = event.currentTarget as HTMLInputElement;
		selectedManageDocumentFile = input.files?.[0] || null;
	}

	async function loadDocumentTypes() {
		if (!supabase) return;
		documentsLoading = true;
		documentError = '';
		const { data, error } = await supabase
			.from('company_document_types')
			.select('id, name_ar, name_en, scope, requires_number, requires_expiry_date, requires_upload, created_at')
			.order('created_at', { ascending: false });
		if (error) documentError = $locale === 'ar' ? 'فشل تحميل المستندات' : (error.message || 'Failed to load documents');
		else documentTypes = (data || []).map((row: any) => ({ ...row, source: 'custom' as const }));
		documentsLoading = false;
	}

	function openDocumentForm() {
		documentNameAr = '';
		documentNameEn = '';
		documentScope = 'common';
		documentRequiresNumber = false;
		documentRequiresExpiryDate = false;
		documentRequiresUpload = true;
		documentError = '';
		showDocumentForm = true;
	}

	function closeDocumentForm() {
		if (documentSaving) return;
		showDocumentForm = false;
		documentNameAr = '';
		documentNameEn = '';
		documentScope = 'common';
		documentRequiresNumber = false;
		documentRequiresExpiryDate = false;
		documentRequiresUpload = true;
		documentError = '';
	}

	async function saveDocumentType() {
		const arabicName = documentNameAr.trim();
		const englishName = documentNameEn.trim();
		if (!arabicName || !englishName) {
			documentError = $locale === 'ar' ? 'اسما المستند بالعربية والإنجليزية مطلوبان.' : 'Arabic and English document names are required.';
			return;
		}
		documentSaving = true;
		documentError = '';
		const { error } = await supabase.rpc('create_company_document_type', {
			p_name_ar: arabicName,
			p_name_en: englishName,
			p_scope: documentScope,
			p_requires_number: documentRequiresNumber,
			p_requires_expiry_date: documentRequiresExpiryDate,
			p_requires_upload: documentRequiresUpload
		});
		documentSaving = false;
		if (error) {
			documentError = $locale === 'ar' ? (error.code === '23505' ? 'يوجد مستند بهذا الاسم بالفعل.' : 'فشل إنشاء المستند') : (error.code === '23505' ? 'A document with this name already exists.' : (error.message || 'Failed to create document'));
			return;
		}
		closeDocumentForm();
		await loadDocumentTypes();
	}

	async function loadCompanies() {
		if (!supabase) return;
		loading = true;
		errorMessage = '';
		const { data, error } = await supabase
			.from('company_master')
			.select('id, name_ar, name_en, owner_emails, owner_whatsapp_numbers, created_at')
			.order('created_at', { ascending: false });
		if (error) errorMessage = $locale === 'ar' ? 'فشل تحميل الشركات / المؤسسات' : (error.message || 'Failed to load companies / establishments');
		else companies = data || [];
		loading = false;
	}

	function openForm() {
		editingCompanyId = null;
		nameAr = '';
		nameEn = '';
		ownerEmails = [''];
		ownerWhatsAppNumbers = [''];
		errorMessage = '';
		showForm = true;
	}

	function openEditForm(company: { id: number; name_ar: string; name_en: string; owner_emails?: string[]; owner_whatsapp_numbers?: string[] }) {
		editingCompanyId = company.id;
		nameAr = company.name_ar;
		nameEn = company.name_en;
		ownerEmails = company.owner_emails?.length ? [...company.owner_emails] : [''];
		ownerWhatsAppNumbers = company.owner_whatsapp_numbers?.length ? [...company.owner_whatsapp_numbers] : [''];
		errorMessage = '';
		showForm = true;
	}

	function closeForm() {
		if (saving) return;
		showForm = false;
		editingCompanyId = null;
		nameAr = '';
		nameEn = '';
		ownerEmails = [''];
		ownerWhatsAppNumbers = [''];
		errorMessage = '';
	}

	function addOwnerEmail() {
		ownerEmails = [...ownerEmails, ''];
	}

	function removeOwnerEmail(index: number) {
		ownerEmails = ownerEmails.length === 1 ? [''] : ownerEmails.filter((_, itemIndex) => itemIndex !== index);
	}

	function addOwnerWhatsApp() {
		ownerWhatsAppNumbers = [...ownerWhatsAppNumbers, ''];
	}

	function removeOwnerWhatsApp(index: number) {
		ownerWhatsAppNumbers = ownerWhatsAppNumbers.length === 1 ? [''] : ownerWhatsAppNumbers.filter((_, itemIndex) => itemIndex !== index);
	}

	async function saveCompany() {
		const arabicName = nameAr.trim();
		const englishName = nameEn.trim();
		const cleanedOwnerEmails = ownerEmails.map((value) => value.trim()).filter(Boolean);
		const cleanedOwnerWhatsAppNumbers = ownerWhatsAppNumbers.map((value) => value.trim()).filter(Boolean);
		if (!arabicName || !englishName) {
			errorMessage = $locale === 'ar' ? 'اسما الشركة / المؤسسة بالعربية والإنجليزية مطلوبان.' : 'Arabic and English company / establishment names are required.';
			return;
		}
		if (cleanedOwnerEmails.length === 0 || cleanedOwnerWhatsAppNumbers.length === 0) {
			errorMessage = $locale === 'ar' ? 'مطلوب بريد إلكتروني واحد ورقم واتساب واحد على الأقل للمالك.' : 'At least one owner email and one owner WhatsApp number are required.';
			return;
		}

		saving = true;
		errorMessage = '';
		const { error } = editingCompanyId === null
			? await supabase.rpc('create_company', {
				p_name_ar: arabicName,
				p_name_en: englishName,
				p_owner_emails: cleanedOwnerEmails,
				p_owner_whatsapp_numbers: cleanedOwnerWhatsAppNumbers
			})
			: await supabase.rpc('update_company', {
				p_company_id: editingCompanyId,
				p_name_ar: arabicName,
				p_name_en: englishName,
				p_owner_emails: cleanedOwnerEmails,
				p_owner_whatsapp_numbers: cleanedOwnerWhatsAppNumbers
			});
		saving = false;
		if (error) {
			errorMessage = $locale === 'ar' ? (error.code === '23505' ? 'توجد شركة / مؤسسة بهذا الاسم بالفعل.' : 'فشل حفظ الشركة / المؤسسة') : (error.code === '23505' ? 'A company / establishment with this name already exists.' : (error.message || 'Failed to create company / establishment'));
			return;
		}

		closeForm();
		await loadCompanies();
	}

	function formatDate(value: string) {
		return value ? new Intl.DateTimeFormat($locale === 'ar' ? 'ar-SA' : 'en-GB', { dateStyle: 'medium' }).format(new Date(value)) : '';
	}
</script>

<div class="create-company-window" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
	<div class="tab-bar">
		<button
			class="tab-button"
			class:active={activeTab === 'create'}
			on:click={() => activeTab = 'create'}
		>
			{$locale === 'ar' ? 'إنشاء' : 'Create'}
		</button>
		<button
			class="tab-button"
			class:active={activeTab === 'manage'}
			on:click={() => activeTab = 'manage'}
		>
			{$locale === 'ar' ? 'إدارة المستندات' : 'Manage Documents'}
		</button>
		<button
			class="tab-button"
			class:active={activeTab === 'branches'}
			on:click={() => activeTab = 'branches'}
		>
			{$locale === 'ar' ? 'إدارة الفروع' : 'Branch Master'}
		</button>
	</div>

	<div class="tab-content">
		{#if activeTab === 'create'}
			<div class="content-area create-content">
				<div class="content-toolbar">
					<h2>{$locale === 'ar' ? 'الشركات / المؤسسات' : 'Companies / Establishments'}</h2>
					<button class="add-button" on:click={openForm} aria-label={$locale === 'ar' ? 'إنشاء شركة / مؤسسة' : 'Create company / establishment'}>+</button>
				</div>

				{#if showForm}
					<div class="inline-form">
						<label>
							<span>{$locale === 'ar' ? 'الاسم بالعربية' : 'Arabic Name'} <strong>*</strong></span>
							<input bind:value={nameAr} dir="rtl" placeholder={$locale === 'ar' ? 'أدخل الاسم بالعربية' : 'Enter Arabic name'} disabled={saving} required />
						</label>
						<label>
							<span>{$locale === 'ar' ? 'الاسم بالإنجليزية' : 'English Name'} <strong>*</strong></span>
							<input bind:value={nameEn} placeholder={$locale === 'ar' ? 'أدخل الاسم بالإنجليزية' : 'Enter English name'} disabled={saving} required />
						</label>
						<div class="contact-list-field">
							<div class="contact-list-heading"><span>{$locale === 'ar' ? 'البريد الإلكتروني للمالك' : 'Owner Emails'} <strong>*</strong></span><button type="button" on:click={addOwnerEmail} disabled={saving}>+ {$locale === 'ar' ? 'إضافة بريد' : 'Add Email'}</button></div>
							{#each ownerEmails as email, index}
								<div class="contact-input-row"><input type="email" bind:value={ownerEmails[index]} placeholder={$locale === 'ar' ? 'أدخل بريد المالك' : 'Enter owner email'} disabled={saving} /><button type="button" class="remove-contact" on:click={() => removeOwnerEmail(index)} disabled={saving}>×</button></div>
							{/each}
						</div>
						<div class="contact-list-field">
							<div class="contact-list-heading"><span>{$locale === 'ar' ? 'أرقام واتساب للمالك' : 'Owner WhatsApp Numbers'} <strong>*</strong></span><button type="button" on:click={addOwnerWhatsApp} disabled={saving}>+ {$locale === 'ar' ? 'إضافة واتساب' : 'Add WhatsApp'}</button></div>
							{#each ownerWhatsAppNumbers as number, index}
								<div class="contact-input-row"><input type="tel" bind:value={ownerWhatsAppNumbers[index]} placeholder={$locale === 'ar' ? 'أدخل رقم واتساب' : 'Enter WhatsApp number'} disabled={saving} /><button type="button" class="remove-contact" on:click={() => removeOwnerWhatsApp(index)} disabled={saving}>×</button></div>
							{/each}
						</div>
						<div class="form-actions">
							<button class="cancel-button" on:click={closeForm} disabled={saving}>{$locale === 'ar' ? 'إلغاء' : 'Cancel'}</button>
							<button class="save-button" on:click={saveCompany} disabled={saving}>{saving ? ($locale === 'ar' ? 'جارٍ الحفظ...' : 'Saving...') : (editingCompanyId === null ? ($locale === 'ar' ? 'حفظ' : 'Save') : ($locale === 'ar' ? 'تحديث' : 'Update'))}</button>
						</div>
					</div>
				{/if}

				{#if errorMessage}<div class="error-message">{errorMessage}</div>{/if}

				<div class="table-wrap">
					<table>
						<thead><tr><th>#</th><th>{$locale === 'ar' ? 'اسم الشركة / المؤسسة' : 'Company / Establishment Name'}</th><th>{$locale === 'ar' ? 'بريد المالك' : 'Owner Email'}</th><th>{$locale === 'ar' ? 'واتساب المالك' : 'Owner WhatsApp'}</th><th>{$locale === 'ar' ? 'تاريخ الإنشاء' : 'Created'}</th><th>{$locale === 'ar' ? 'الإجراء' : 'Action'}</th></tr></thead>
						<tbody>
							{#if loading}
								<tr><td colspan="6" class="empty-row">{$locale === 'ar' ? 'جارٍ التحميل...' : 'Loading...'}</td></tr>
							{:else if companies.length === 0}
								<tr><td colspan="6" class="empty-row">{$locale === 'ar' ? 'لم يتم إنشاء شركات / مؤسسات بعد.' : 'No companies / establishments created yet.'}</td></tr>
							{:else}
								{#each companies as company, index (company.id)}
									<tr>
										<td>{index + 1}</td><td dir={$locale === 'ar' ? 'rtl' : 'ltr'}>{$locale === 'ar' ? company.name_ar : company.name_en}</td><td>{company.owner_emails?.join(', ') || '—'}</td><td>{company.owner_whatsapp_numbers?.join(', ') || '—'}</td><td>{formatDate(company.created_at)}</td>
										<td><button class="edit-button" on:click={() => openEditForm(company)}>{$locale === 'ar' ? 'تعديل' : 'Edit'}</button></td>
									</tr>
								{/each}
							{/if}
						</tbody>
					</table>
				</div>
			</div>
		{:else if activeTab === 'manage'}
			<div class="content-area manage-content">
				<div class="sub-tab-bar">
					<button class="sub-tab-button" class:active={documentSection === 'create'} on:click={() => documentSection = 'create'}>{$locale === 'ar' ? 'إنشاء' : 'Create'}</button>
					<button class="sub-tab-button" class:active={documentSection === 'manage'} on:click={() => documentSection = 'manage'}>{$locale === 'ar' ? 'إدارة' : 'Manage'}</button>
				</div>
				<div class="sub-tab-content">
					{#if documentSection === 'create'}
						<div class="document-content-area create-documents-content">
							<div class="content-toolbar">
								<h2>{$locale === 'ar' ? 'إنشاء مستند' : 'Create Document'}</h2>
								<button class="add-button" on:click={openDocumentForm} aria-label={$locale === 'ar' ? 'إنشاء مستند' : 'Create document'}>+</button>
							</div>
							{#if showDocumentForm}
								<div class="document-create-form">
									<label><span>{$locale === 'ar' ? 'اسم المستند بالعربية' : 'Arabic Name'} <strong>*</strong></span><input bind:value={documentNameAr} dir="rtl" placeholder={$locale === 'ar' ? 'أدخل اسم المستند بالعربية' : 'Enter Arabic document name'} disabled={documentSaving} required /></label>
									<label><span>{$locale === 'ar' ? 'اسم المستند بالإنجليزية' : 'English Name'} <strong>*</strong></span><input bind:value={documentNameEn} placeholder={$locale === 'ar' ? 'أدخل اسم المستند بالإنجليزية' : 'Enter English document name'} disabled={documentSaving} required /></label>
									<div class="scope-options">
										<span>{$locale === 'ar' ? 'نطاق المستند' : 'Document Scope'}</span>
										<label class="scope-checkbox" class:selected={documentScope === 'common'}><input type="checkbox" checked={documentScope === 'common'} on:change={() => documentScope = 'common'} /><span class="scope-dot"></span>{$locale === 'ar' ? 'مشترك' : 'Common'}</label>
										<label class="scope-checkbox" class:selected={documentScope === 'branch_wise'}><input type="checkbox" checked={documentScope === 'branch_wise'} on:change={() => documentScope = 'branch_wise'} /><span class="scope-dot"></span>{$locale === 'ar' ? 'حسب الفرع' : 'Branch-wise'}</label>
									</div>
									<div class="requirement-options">
										<div class="requirement-row">
											<span>{$locale === 'ar' ? 'رقم المستند' : 'Document Number'}</span>
											<button type="button" class="requirement-toggle" class:mandatory={documentRequiresNumber} on:click={() => documentRequiresNumber = !documentRequiresNumber}>
												<span class="toggle-track"><span class="toggle-knob"></span></span><span>{$locale === 'ar' ? (documentRequiresNumber ? 'إلزامي' : 'اختياري') : (documentRequiresNumber ? 'Mandatory' : 'Optional')}</span>
											</button>
										</div>
										<div class="requirement-row">
											<span>{$locale === 'ar' ? 'تاريخ الانتهاء' : 'Expiry Date'}</span>
											<button type="button" class="requirement-toggle" class:mandatory={documentRequiresExpiryDate} on:click={() => documentRequiresExpiryDate = !documentRequiresExpiryDate}>
												<span class="toggle-track"><span class="toggle-knob"></span></span><span>{$locale === 'ar' ? (documentRequiresExpiryDate ? 'إلزامي' : 'اختياري') : (documentRequiresExpiryDate ? 'Mandatory' : 'Optional')}</span>
											</button>
										</div>
										<div class="requirement-row">
											<span>{$locale === 'ar' ? 'رفع المستند' : 'Document Upload'}</span>
											<button type="button" class="requirement-toggle" class:mandatory={documentRequiresUpload} on:click={() => documentRequiresUpload = !documentRequiresUpload}>
												<span class="toggle-track"><span class="toggle-knob"></span></span><span>{$locale === 'ar' ? (documentRequiresUpload ? 'إلزامي' : 'اختياري') : (documentRequiresUpload ? 'Mandatory' : 'Optional')}</span>
											</button>
										</div>
									</div>
									<div class="form-actions">
										<button class="cancel-button" on:click={closeDocumentForm} disabled={documentSaving}>{$locale === 'ar' ? 'إلغاء' : 'Cancel'}</button>
										<button class="save-button" on:click={saveDocumentType} disabled={documentSaving}>{documentSaving ? ($locale === 'ar' ? 'جارٍ الحفظ...' : 'Saving...') : ($locale === 'ar' ? 'حفظ' : 'Save')}</button>
									</div>
								</div>
							{/if}
							{#if documentError}<div class="error-message">{documentError}</div>{/if}
							<div class="table-wrap document-table-wrap">
								<table>
									<thead><tr><th>#</th><th>{$locale === 'ar' ? 'اسم المستند' : 'Document Name'}</th><th>{$locale === 'ar' ? 'النطاق' : 'Scope'}</th><th>{$locale === 'ar' ? 'الرقم' : 'Number'}</th><th>{$locale === 'ar' ? 'تاريخ الانتهاء' : 'Expiry Date'}</th><th>{$locale === 'ar' ? 'رفع المستند' : 'Upload'}</th><th>{$locale === 'ar' ? 'المصدر' : 'Source'}</th><th>{$locale === 'ar' ? 'تاريخ الإنشاء' : 'Created'}</th></tr></thead>
									<tbody>
										{#if documentsLoading}<tr><td colspan="8" class="empty-row">{$locale === 'ar' ? 'جارٍ التحميل...' : 'Loading...'}</td></tr>
										{:else}
											{#each allDocumentTypes as document, index (document.id)}
												<tr><td>{index + 1}</td><td dir={$locale === 'ar' ? 'rtl' : 'ltr'}>{$locale === 'ar' ? document.name_ar : document.name_en}</td><td>{$locale === 'ar' ? (document.scope === 'common' ? 'مشترك' : 'حسب الفرع') : (document.scope === 'common' ? 'Common' : 'Branch-wise')}</td><td>{$locale === 'ar' ? (document.requires_number ? 'إلزامي' : 'اختياري') : (document.requires_number ? 'Mandatory' : 'Optional')}</td><td>{$locale === 'ar' ? (document.requires_expiry_date ? 'إلزامي' : 'اختياري') : (document.requires_expiry_date ? 'Mandatory' : 'Optional')}</td><td>{$locale === 'ar' ? (document.requires_upload ? 'إلزامي' : 'اختياري') : (document.requires_upload ? 'Mandatory' : 'Optional')}</td><td>{$locale === 'ar' ? (document.source === 'default' ? 'افتراضي' : 'مخصص') : (document.source === 'default' ? 'Default' : 'Custom')}</td><td>{document.created_at ? formatDate(document.created_at) : '—'}</td></tr>
											{/each}
										{/if}
									</tbody>
								</table>
							</div>
						</div>
					{:else}
						<div class="document-content-area manage-documents-content">
							<div class="content-toolbar">
								<h2>{$locale === 'ar' ? 'إدارة المستندات' : 'Manage Documents'}</h2>
								<button class="add-button" on:click={() => showManageDocumentPicker = !showManageDocumentPicker} aria-label={$locale === 'ar' ? 'اختيار مستند' : 'Select document'}>+</button>
							</div>
							{#if showManageDocumentPicker}
								<div class="manage-document-picker">
									<label for="manage-document-select">{$locale === 'ar' ? 'اختر المستند' : 'Select Document'}</label>
									<select id="manage-document-select" bind:value={selectedManageDocumentId} on:change={resetManageDocumentFields}>
										<option value="">{$locale === 'ar' ? 'اختر مستنداً' : 'Choose a document'}</option>
										{#each allDocumentTypes as document (document.id)}
											<option value={String(document.id)}>{$locale === 'ar' ? document.name_ar : document.name_en}</option>
										{/each}
									</select>
									{#if selectedManageDocument}
										<div class="manage-document-fields">
											<label>
								<span>{$locale === 'ar' ? 'الشركة / المؤسسة' : 'Company / Establishment'} <strong>*</strong></span>
												<select bind:value={selectedManageCompanyId} on:change={changeManageCompany} required>
									<option value="">{$locale === 'ar' ? 'اختر الشركة / المؤسسة' : 'Select company / establishment'}</option>
													{#each companies as company (company.id)}
										<option value={String(company.id)}>{$locale === 'ar' ? company.name_ar : company.name_en}</option>
													{/each}
												</select>
											</label>
							{#if selectedManageDocument.scope === 'branch_wise' && selectedManageCompanyId}
												<label>
									<span>{$locale === 'ar' ? 'الفرع' : 'Branch'} <strong>*</strong></span>
													<select bind:value={selectedManageBranchId} required>
										<option value="">{$locale === 'ar' ? 'اختر الفرع' : 'Select branch'}</option>
														{#each availableManageBranches as branch (branch.id)}
											<option value={String(branch.id)}>{$locale === 'ar' ? `${branch.name_ar} — ${branch.location_ar}` : `${branch.name_en} — ${branch.location_en}`}</option>
														{/each}
													</select>
												</label>
							{/if}
							{#if selectedManageCompanyId && selectedManageDocument.requires_expiry_date}
								<div class="owner-alert-section">
									<div class="owner-alert-title">🔔 {$locale === 'ar' ? 'إشعارات المالك' : 'Owner Notifications'}</div>
									<p>{$locale === 'ar' ? 'تم تحميل بيانات المالك تلقائياً. يمكنك إضافة بيانات اتصال إضافية لهذا المستند.' : 'Owner contacts were loaded automatically. You can add extra contacts for this document.'}</p>
									<div class="notification-contact-columns">
										<div class="notification-contact-list">
											<div class="notification-heading"><span>{$locale === 'ar' ? 'عناوين البريد الإلكتروني' : 'Email Addresses'}</span><button type="button" on:click={addDocumentNotificationEmail}>+ {$locale === 'ar' ? 'إضافة بريد' : 'Add Email'}</button></div>
											{#each documentNotificationEmails as email, index}
												<div class="contact-input-row"><input type="email" bind:value={documentNotificationEmails[index]} placeholder={$locale === 'ar' ? 'بريد الإشعار' : 'Notification email'} /><button type="button" class="remove-contact" on:click={() => removeDocumentNotificationEmail(index)}>×</button></div>
											{/each}
										</div>
										<div class="notification-contact-list">
											<div class="notification-heading"><span>{$locale === 'ar' ? 'أرقام واتساب' : 'WhatsApp Numbers'}</span><button type="button" on:click={addDocumentNotificationWhatsApp}>+ {$locale === 'ar' ? 'إضافة واتساب' : 'Add WhatsApp'}</button></div>
											{#each documentNotificationWhatsAppNumbers as number, index}
												<div class="contact-input-row"><input type="tel" bind:value={documentNotificationWhatsAppNumbers[index]} placeholder={$locale === 'ar' ? 'واتساب الإشعار' : 'Notification WhatsApp'} /><button type="button" class="remove-contact" on:click={() => removeDocumentNotificationWhatsApp(index)}>×</button></div>
											{/each}
										</div>
									</div>
									<div class="reminder-settings">
										<div class="notification-periods">
											<div class="notification-heading">
												<span>{$locale === 'ar' ? 'فترات الإشعار — أيام قبل الانتهاء' : 'Notification Periods — Days Before Expiry'}</span>
												<button type="button" on:click={addNotificationPeriod} disabled={notificationPeriods.length >= 3}>+ {$locale === 'ar' ? 'إضافة فترة' : 'Add Period'}</button>
											</div>
											<div class="period-inputs">
												{#each notificationPeriods as period, index}
													<div class="period-input-row"><input type="number" min="1" bind:value={notificationPeriods[index]} placeholder={index === 0 ? '30' : index === 1 ? '15' : '5'} /><span>{$locale === 'ar' ? 'يوم' : 'days'}</span><button type="button" on:click={() => removeNotificationPeriod(index)}>×</button></div>
												{/each}
											</div>
										</div>
										<label class="reminder-time-field"><span>{$locale === 'ar' ? 'وقت التذكير' : 'Reminder Time'}</span><input type="time" bind:value={reminderTime} /></label>
									</div>
								</div>
							{/if}
							{#if selectedManageDocument.requires_number}
								<label><span>{$locale === 'ar' ? 'رقم المستند' : 'Document Number'} <strong>*</strong></span><input bind:value={manageDocumentNumber} placeholder={$locale === 'ar' ? 'أدخل رقم المستند' : 'Enter document number'} required /></label>
											{/if}
							{#if selectedManageDocument.requires_expiry_date}
								<label><span>{$locale === 'ar' ? 'تاريخ الانتهاء' : 'Expiry Date'} <strong>*</strong></span><input type="date" bind:value={manageExpiryDate} required /></label>
							{/if}
							<div class="document-upload-field">
								<span>{$locale === 'ar' ? 'رفع المستند' : 'Upload Document'} {#if selectedManageDocument.requires_upload}<strong>*</strong>{/if}</span>
								<div class="upload-options">
									<label class="upload-option camera-option">
										<span>📷 {$locale === 'ar' ? 'استخدام الكاميرا' : 'Use Camera'}</span>
										<input type="file" accept="image/*" capture="environment" on:change={selectManageDocumentFile} />
									</label>
									<label class="upload-option file-option">
										<span>📁 {$locale === 'ar' ? 'اختيار ملف' : 'Choose File'}</span>
										<input type="file" accept="image/*,application/pdf" on:change={selectManageDocumentFile} />
									</label>
								</div>
								<div class="selected-file-name">{selectedManageDocumentFile?.name || ($locale === 'ar' ? 'لم يتم اختيار مستند' : 'No document selected')}</div>
							</div>
						</div>
									{/if}
								</div>
							{/if}
						</div>
					{/if}
				</div>
			</div>
		{:else}
			<div class="branch-master-content">
				<BranchMaster initialTab="branches" hideTabSwitcher={true} />
			</div>
		{/if}
	</div>
</div>

<style>
	.create-company-window {
		display: flex;
		flex-direction: column;
		width: 100%;
		height: 100%;
		background: #f8fafc;
	}

	.tab-bar {
		display: flex;
		gap: 4px;
		padding: 12px 14px 0;
		border-bottom: 1px solid #dbe4ee;
		background: #ffffff;
	}

	.tab-button {
		min-width: 110px;
		padding: 10px 18px;
		border: 1px solid #dbe4ee;
		border-bottom: 0;
		border-radius: 7px 7px 0 0;
		background: #edf2f7;
		color: #475569;
		font-size: 13px;
		font-weight: 600;
		cursor: pointer;
	}

	.tab-button.active {
		background: #13bfd0;
		color: #ffffff;
		border-color: #13bfd0;
	}

	.tab-content {
		flex: 1;
		min-height: 0;
		padding: 16px;
	}

	.content-area {
		width: 100%;
		height: 100%;
		min-height: 300px;
		border: 1px solid #dbe4ee;
		border-radius: 8px;
		background: #ffffff;
		overflow: auto;
	}

	.manage-content {
		display: flex;
		flex-direction: column;
		overflow: hidden;
	}

	.sub-tab-bar {
		display: flex;
		gap: 8px;
		padding: 12px 14px;
		border-bottom: 1px solid #dbe4ee;
		background: #f8fafc;
	}

	.sub-tab-button {
		padding: 8px 16px;
		border: 1px solid #cbd5e1;
		border-radius: 7px;
		background: #ffffff;
		color: #475569;
		font-size: 12px;
		font-weight: 700;
		cursor: pointer;
	}

	.sub-tab-button.active {
		border-color: #13bfd0;
		background: #13bfd0;
		color: #ffffff;
		box-shadow: 0 2px 6px rgba(19, 191, 208, .25);
	}

	.sub-tab-content {
		flex: 1;
		min-height: 0;
		padding: 14px;
	}

	.document-content-area {
		width: 100%;
		height: 100%;
		min-height: 260px;
		border: 1px solid #dbe4ee;
		border-radius: 8px;
		background: #ffffff;
	}

	.document-create-form {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 14px;
		padding: 18px;
	}

	.document-create-form > label,
	.scope-options {
		display: flex;
		flex-direction: column;
		gap: 6px;
		color: #475569;
		font-size: 12px;
		font-weight: 700;
	}

	.document-create-form input[type='text'],
	.document-create-form input:not([type]) {
		padding: 10px;
		border: 1px solid #cbd5e1;
		border-radius: 6px;
	}

	.scope-options {
		grid-column: 1 / -1;
		flex-direction: row;
		align-items: center;
		gap: 18px;
		padding: 12px;
		border: 1px solid #dbe4ee;
		border-radius: 7px;
		background: #f8fafc;
	}

	.scope-checkbox {
		display: inline-flex;
		align-items: center;
		gap: 8px;
		min-width: 112px;
		padding: 7px 12px;
		border: 1px solid #cbd5e1;
		border-radius: 999px;
		background: #ffffff;
		color: #64748b;
		font-weight: 700;
		cursor: pointer;
		transition: border-color 0.18s ease, background 0.18s ease, color 0.18s ease, box-shadow 0.18s ease;
	}

	.scope-checkbox:hover {
		border-color: #06b6d4;
	}

	.scope-checkbox input {
		position: absolute;
		opacity: 0;
		pointer-events: none;
	}

	.scope-checkbox.selected {
		border-color: #06b6d4;
		background: #ecfeff;
		color: #0e7490;
		box-shadow: 0 0 0 2px rgba(6, 182, 212, 0.12);
	}

	.scope-dot {
		width: 14px;
		height: 14px;
		border: 2px solid #94a3b8;
		border-radius: 50%;
		background: #ffffff;
		box-shadow: inset 0 0 0 3px #ffffff;
	}

	.scope-checkbox.selected .scope-dot {
		border-color: #06b6d4;
		background: #06b6d4;
	}

	.document-create-form .form-actions {
		grid-column: 1 / -1;
		justify-content: flex-end;
	}

	.requirement-options {
		display: grid;
		grid-template-columns: repeat(2, minmax(220px, 1fr));
		grid-column: 1 / -1;
		gap: 12px;
	}

	.requirement-row {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 12px;
		padding: 11px 12px;
		border: 1px solid #dbe4ee;
		border-radius: 7px;
		background: #f8fafc;
		color: #475569;
		font-size: 12px;
		font-weight: 700;
	}

	.requirement-toggle {
		display: inline-flex;
		align-items: center;
		justify-content: space-between;
		gap: 9px;
		min-width: 116px;
		padding: 5px 9px;
		border: 1px solid #cbd5e1;
		border-radius: 999px;
		background: #ffffff;
		color: #64748b;
		font-size: 11px;
		font-weight: 700;
		cursor: pointer;
		transition: border-color 0.18s ease, background 0.18s ease, color 0.18s ease;
	}

	.requirement-toggle:hover {
		border-color: #14b8a6;
	}

	.toggle-track {
		position: relative;
		display: inline-block;
		flex: 0 0 36px;
		width: 36px;
		height: 20px;
		border-radius: 999px;
		background: #cbd5e1;
		box-shadow: inset 0 1px 2px rgba(15, 23, 42, 0.15);
		transition: background 0.2s ease;
	}

	.toggle-knob {
		position: absolute;
		top: 2px;
		left: 2px;
		width: 16px;
		height: 16px;
		border-radius: 50%;
		background: #ffffff;
		box-shadow: 0 1px 3px rgba(15, 23, 42, 0.3);
		transition: transform 0.2s ease;
	}

	.requirement-toggle.mandatory {
		border-color: #14b8a6;
		background: #f0fdfa;
		color: #0f766e;
	}

	.requirement-toggle.mandatory .toggle-track {
		background: #14b8a6;
	}

	.requirement-toggle.mandatory .toggle-knob {
		transform: translateX(16px);
	}

	.manage-document-picker {
		display: flex;
		flex-direction: column;
		gap: 7px;
		width: calc(100% - 36px);
		max-width: none;
		margin: 18px;
		padding: 16px;
		border: 1px solid #dbe4ee;
		border-radius: 8px;
		background: #f8fafc;
	}

	.manage-document-picker label {
		color: #475569;
		font-size: 12px;
		font-weight: 700;
	}

	.manage-document-picker select {
		width: 100%;
		padding: 10px 12px;
		border: 1px solid #cbd5e1;
		border-radius: 7px;
		background: #ffffff;
		color: #334155;
		font-size: 13px;
	}

	.manage-document-fields {
		display: grid;
		grid-template-columns: repeat(2, minmax(0, 1fr));
		gap: 12px;
		margin-top: 8px;
		padding-top: 14px;
		border-top: 1px solid #dbe4ee;
	}

	.manage-document-fields label {
		display: flex;
		flex-direction: column;
		gap: 6px;
	}

	.manage-document-fields strong {
		color: #dc2626;
	}

	.manage-document-fields input {
		width: 100%;
		padding: 10px 12px;
		border: 1px solid #cbd5e1;
		border-radius: 7px;
		background: #ffffff;
		color: #334155;
		font-size: 13px;
	}

	.document-upload-field {
		display: flex;
		flex-direction: column;
		grid-column: 1 / -1;
		gap: 8px;
		padding: 13px;
		border: 1px dashed #67e8f9;
		border-radius: 8px;
		background: #ecfeff;
	}

	.upload-options {
		display: flex;
		gap: 10px;
		flex-wrap: wrap;
	}

	.upload-option {
		display: inline-flex !important;
		flex-direction: row !important;
		align-items: center;
		justify-content: center;
		min-width: 135px;
		padding: 9px 13px;
		border: 1px solid #0891b2;
		border-radius: 7px;
		background: #ffffff;
		color: #0e7490;
		font-size: 12px;
		font-weight: 700;
		cursor: pointer;
	}

	.upload-option:hover { background: #cffafe; }
	.upload-option input { display: none; }

	.selected-file-name {
		padding: 8px 10px;
		border-radius: 6px;
		background: #ffffff;
		color: #64748b;
		font-size: 12px;
	}

	.owner-alert-section {
		display: flex;
		flex-direction: column;
		grid-column: 1 / -1;
		gap: 8px;
		padding: 14px;
		border: 1px solid #fbbf24;
		border-left: 4px solid #f59e0b;
		border-radius: 8px;
		background: #fffbeb;
	}

	.owner-alert-title {
		color: #92400e;
		font-size: 13px;
		font-weight: 800;
	}

	.owner-alert-section p {
		margin: 0;
		color: #78716c;
		font-size: 11px;
	}

	.notification-contact-columns {
		display: grid;
		grid-template-columns: repeat(2, minmax(0, 1fr));
		gap: 12px;
	}

	.notification-contact-list {
		display: flex;
		flex-direction: column;
		gap: 7px;
	}

	.notification-heading {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 8px;
		color: #57534e;
		font-size: 11px;
		font-weight: 700;
	}

	.notification-heading button {
		padding: 4px 8px;
		border: 1px solid #f59e0b;
		border-radius: 5px;
		background: #ffffff;
		color: #92400e;
		font-size: 10px;
		font-weight: 700;
		cursor: pointer;
	}

	.notification-heading button:disabled {
		opacity: .45;
		cursor: default;
	}

	.reminder-settings {
		display: grid;
		grid-template-columns: 1fr 190px;
		gap: 14px;
		padding-top: 12px;
		border-top: 1px solid #fde68a;
	}

	.notification-periods {
		display: flex;
		flex-direction: column;
		gap: 8px;
	}

	.period-inputs {
		display: flex;
		gap: 8px;
		flex-wrap: wrap;
	}

	.period-input-row {
		display: flex;
		align-items: center;
		gap: 5px;
		padding: 5px;
		border: 1px solid #fcd34d;
		border-radius: 6px;
		background: #ffffff;
	}

	.period-input-row input {
		width: 64px;
		padding: 6px !important;
		border: 1px solid #d6d3d1;
		border-radius: 5px;
		text-align: center;
	}

	.period-input-row span { color: #78716c; font-size: 10px; }
	.period-input-row button { border: 0; background: transparent; color: #dc2626; font-size: 16px; cursor: pointer; }

	.reminder-time-field {
		display: flex;
		flex-direction: column;
		gap: 7px;
		color: #57534e;
		font-size: 11px;
		font-weight: 700;
	}

	@media (max-width: 700px) {
		.manage-document-fields,
		.notification-contact-columns,
		.reminder-settings { grid-template-columns: 1fr; }
	}

	.branch-master-content {
		width: 100%;
		height: 100%;
		min-height: 0;
		overflow: hidden;
		border: 1px solid #dbe4ee;
		border-radius: 8px;
		background: #ffffff;
	}

	.content-toolbar {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 14px 16px;
		border-bottom: 1px solid #e2e8f0;
	}

	.content-toolbar h2 { margin: 0; color: #334155; font-size: 16px; }
	.add-button { width: 34px; height: 34px; border: 0; border-radius: 7px; background: #13bfd0; color: white; font-size: 22px; cursor: pointer; }
	.inline-form { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 12px; align-items: end; padding: 14px 16px; background: #f8fafc; border-bottom: 1px solid #e2e8f0; }
	.inline-form label { display: flex; flex-direction: column; gap: 6px; color: #475569; font-size: 12px; font-weight: 600; }
	.inline-form input { padding: 9px 10px; border: 1px solid #cbd5e1; border-radius: 6px; background: white; color: #0f172a; }
	.inline-form > .contact-list-field { grid-column: span 2; }
	.contact-list-field { display: flex; flex-direction: column; gap: 7px; min-width: 0; }
	.contact-list-heading { display: flex; align-items: center; justify-content: space-between; gap: 8px; color: #475569; font-size: 12px; font-weight: 700; }
	.contact-list-heading button { padding: 4px 8px; border: 1px solid #13bfd0; border-radius: 5px; background: #ecfeff; color: #0e7490; font-size: 10px; font-weight: 700; cursor: pointer; }
	.contact-input-row { display: flex; gap: 6px; }
	.contact-input-row input { flex: 1; min-width: 0; }
	.contact-input-row .remove-contact { width: 34px; border: 1px solid #fecaca; border-radius: 6px; background: #fff1f2; color: #dc2626; font-size: 18px; cursor: pointer; }
	.form-actions { display: flex; gap: 8px; }
	.form-actions button { padding: 9px 16px; border-radius: 6px; font-weight: 600; cursor: pointer; }
	.cancel-button { border: 1px solid #cbd5e1; background: white; color: #475569; }
	.save-button { border: 1px solid #10b981; background: #10b981; color: white; }
	.form-actions button:disabled { opacity: .6; cursor: default; }
	.error-message { margin: 12px 16px 0; padding: 9px 12px; border-radius: 6px; background: #fee2e2; color: #b91c1c; font-size: 12px; }
	.table-wrap { margin: 14px 16px; overflow: auto; border: 1px solid #cbd5e1; border-radius: 9px; box-shadow: 0 2px 8px rgba(15, 23, 42, .06); }
	table { width: 100%; border-collapse: separate; border-spacing: 0; font-size: 13px; background: #ffffff; }
	th { padding: 11px 12px; background: linear-gradient(180deg, #f5f3ff 0%, #ede9fe 100%); color: #5b21b6; text-align: center; font-size: 12px; font-weight: 700; text-transform: uppercase; letter-spacing: .025em; border-right: 1px solid #c4b5fd; border-bottom: 1px solid #a78bfa; }
	td { padding: 11px 12px; color: #334155; text-align: center; border-right: 1px solid #e2e8f0; border-bottom: 1px solid #e2e8f0; }
	th:last-child, td:last-child { border-right: 0; }
	tbody tr:last-child td { border-bottom: 0; }
	tbody tr:nth-child(even) { background: #f8fafc; }
	tbody tr:hover { background: #ecfeff; }
	.empty-row { padding: 28px; text-align: center; color: #94a3b8; }
	.edit-button { padding: 6px 14px; border: 1px solid #13bfd0; border-radius: 5px; background: #ecfeff; color: #0e7490; font-weight: 600; cursor: pointer; }
	.edit-button:hover { background: #cffafe; }

	@media (max-width: 700px) {
		.inline-form { grid-template-columns: 1fr; }
		.inline-form > .contact-list-field { grid-column: span 1; }
	}
</style>
