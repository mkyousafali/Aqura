<script lang="ts">
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { dataService } from '$lib/utils/dataService';
	import { _ as t, localeData, locale } from '$lib/i18n';

	// State
	let branches: any[] = [];
	let nationalities: any[] = [];
	let employees: any[] = [];
	let filteredEmployees: any[] = [];
	let selectedBranch = '';
	let selectedPositionId = '';
	let searchTerm = '';
	let selectedEmployee: any = null;
	let selectedNationality = '';
	let sponsorshipStatus = false;
	let savedSponsorshipStatus = false;
	let employmentStatus = 'Resigned';
	let savedEmploymentStatus = 'Resigned';
	let isLoading = false;
	let errorMessage = '';
	let filtersOpen = true;
	let isSaved = false;
	let idNumber = '';
	let savedIdNumber = '';
	let idExpiryDate = '';
	let savedIdExpiryDate = '';
	let workPermitExpiryDate = '';
	let savedWorkPermitExpiryDate = '';
	let workPermitDaysUntilExpiry = 0;
	let idDocumentFile: File | null = null;
	let isUploadingDocument = false;
	let daysUntilExpiry = 0;
	let healthCardNumber = '';
	let savedHealthCardNumber = '';
	let healthCardExpiryDate = '';
	let savedHealthCardExpiryDate = '';
	let healthEducationalRenewalDate = '';
	let savedHealthEducationalRenewalDate = '';
	let healthEducationalRenewalDaysUntilExpiry = 0;
	let healthCardFile: File | null = null;
	let isUploadingHealthCard = false;
	let healthCardDaysUntilExpiry = 0;
	let drivingLicenceNumber = '';
	let savedDrivingLicenceNumber = '';
	let drivingLicenceExpiryDate = '';
	let savedDrivingLicenceExpiryDate = '';
	let drivingLicenceFile: File | null = null;
	let isUploadingDrivingLicence = false;
	let drivingLicenceDaysUntilExpiry = 0;
	let contractExpiryDate = '';
	let savedContractExpiryDate = '';
	let contractFile: File | null = null;
	let isUploadingContract = false;
	let contractDaysUntilExpiry = 0;
	let bankName = '';
	let savedBankName = '';
	let iban = '';
	let savedIban = '';
	let dateOfBirth = '';
	let savedDateOfBirth = '';
	let age = 0;
	let joinDate = '';
	let savedJoinDate = '';
	let workedYears = 0;
	let workedMonths = 0;
	let workedDays = 0;
	let probationPeriodExpiryDate = '';
	let savedProbationPeriodExpiryDate = '';
	let probationPeriodDaysUntilExpiry = 0;
	let insuranceCompanies: any[] = [];
	let positions: any[] = [];
	let selectedInsuranceCompanyId = '';
	let savedInsuranceCompanyId = '';
	let insuranceExpiryDate = '';
	let savedInsuranceExpiryDate = '';
	let insuranceDaysUntilExpiry = 0;
	let isCreatingInsuranceCompany = false;
	let newInsuranceCompanyNameEn = '';
	let newInsuranceCompanyNameAr = '';
	let showCreateInsuranceModal = false;
	let showEffectiveDateModal = false;
	let effectiveDate = '';
	let effectiveDateReason = '';

	let isCreatingNationality = false;
	let newNationalityId = '';
	let newNationalityNameEn = '';
	let newNationalityNameAr = '';
	let showCreateNationalityModal = false;
	
	// POS Shortages
	let posShortages: any = {
		total: 0,
		proposed: 0,
		forgiven: 0,
		deducted: 0,
		cancelled: 0
	};

	// Banks list
	const banks = [
		{ name_en: 'Saudi National Bank (SNB)', name_ar: 'البنك الأهلي السعودي' },
		{ name_en: 'Al Rajhi Bank', name_ar: 'مصرف الراجحي' },
		{ name_en: 'Riyad Bank', name_ar: 'بنك الرياض' },
		{ name_en: 'Saudi Awwal Bank (SAB)', name_ar: 'البنك السعودي الأول' },
		{ name_en: 'Arab National Bank (ANB)', name_ar: 'البنك العربي الوطني' },
		{ name_en: 'Alinma Bank', name_ar: 'مصرف الإنماء' },
		{ name_en: 'Banque Saudi Fransi (BSF)', name_ar: 'البنك السعودي الفرنسي' },
		{ name_en: 'The Saudi Investment Bank (SAIB)', name_ar: 'البنك السعودي للاستثمار' },
		{ name_en: 'Bank Albilad', name_ar: 'بنك البلاد' },
		{ name_en: 'Bank Aljazira', name_ar: 'بنك الجزيرة' },
		{ name_en: 'Gulf International Bank Saudi Arabia (GIB-SA)', name_ar: 'بنك الخليج الدولي' },
		{ name_en: 'D360 Bank', name_ar: 'بنك دال ثلاثمائة وستون' },
		{ name_en: 'STC Bank', name_ar: 'بنك إس تي سي' },
		{ name_en: 'Vision Bank', name_ar: 'بنك فيجن' },
		{ name_en: 'EZ Bank', name_ar: 'آيزي بنك' }
	];

	onMount(async () => {
		await loadBranches();
		await loadNationalities();
		await loadInsuranceCompanies();
		await loadPositions();
		await loadEmployees();
	});

	async function loadPOSShortages(employeeId: string) {
		try {
			const { data, error } = await supabase
				.from('pos_deduction_transfers')
				.select('status, short_amount')
				.eq('cashier_user_id', employeeId);

			if (error) throw error;

			// Reset totals
			posShortages = {
				total: 0,
				proposed: 0,
				forgiven: 0,
				deducted: 0,
				cancelled: 0
			};

			// Calculate totals by status
			(data || []).forEach(record => {
				const amount = parseFloat(record.short_amount || 0);
				posShortages.total += amount;
				
				if (record.status === 'Proposed') {
					posShortages.proposed += amount;
				} else if (record.status === 'Forgiven') {
					posShortages.forgiven += amount;
				} else if (record.status === 'Deducted') {
					posShortages.deducted += amount;
				} else if (record.status === 'Cancelled') {
					posShortages.cancelled += amount;
				}
			});
		} catch (error) {
			console.error('Error loading POS shortages:', error);
		}
	}

	function toggleFilters() {
		filtersOpen = !filtersOpen;
	}

	async function loadNationalities() {
		try {
			const { data, error } = await supabase
				.from('nationalities')
				.select('id, name_en, name_ar')
				.order('name_en');
			if (error) {
				console.error('Error loading nationalities:', error);
				return;
			}
			
			// Sort with priority order: SA, IND, BAN, YEM, then others
			const priorityOrder = ['SA', 'IND', 'BAN', 'YEM'];
			const priorityNationalities = data.filter(n => priorityOrder.includes(n.id))
				.sort((a, b) => priorityOrder.indexOf(a.id) - priorityOrder.indexOf(b.id));
			const otherNationalities = data.filter(n => !priorityOrder.includes(n.id))
				.sort((a, b) => a.name_en.localeCompare(b.name_en));
			
			nationalities = [...priorityNationalities, ...otherNationalities];
		} catch (error) {
			console.error('Error loading nationalities:', error);
		}
	}

	async function loadInsuranceCompanies() {
		try {
			const { data, error } = await supabase
				.from('hr_insurance_companies')
				.select('id, name_en, name_ar')
				.order('name_en');
			if (error) {
				console.error('Error loading insurance companies:', error);
				return;
			}
			insuranceCompanies = data || [];
		} catch (error) {
			console.error('Error loading insurance companies:', error);
		}
	}

	async function loadPositions() {
		try {
			const { data, error } = await supabase
				.from('hr_positions')
				.select('id, position_title_en, position_title_ar')
				.order('position_title_en');
			if (error) {
				console.error('Error loading positions:', error);
				return;
			}
			positions = data || [];
		} catch (error) {
			console.error('Error loading positions:', error);
		}
	}

	async function createInsuranceCompany() {
		if (!newInsuranceCompanyNameEn || !newInsuranceCompanyNameAr) {
			alert($t('employeeFiles.alerts.enterCompanyNames'));
			return;
		}

		isCreatingInsuranceCompany = true;

		try {
			const { data, error } = await supabase
				.from('hr_insurance_companies')
				.insert([
					{
						name_en: newInsuranceCompanyNameEn,
						name_ar: newInsuranceCompanyNameAr
					}
				])
				.select();

			if (error) {
				console.error('Error creating insurance company:', error);
				alert($t('employeeFiles.alerts.createCompanyError'));
				return;
			}

			if (data && data[0]) {
				insuranceCompanies = [...insuranceCompanies, data[0]];
				selectedInsuranceCompanyId = data[0].id;
				newInsuranceCompanyNameEn = '';
				newInsuranceCompanyNameAr = '';
				showCreateInsuranceModal = false;
				alert($t('employeeFiles.alerts.createCompanySuccess'));
			}
		} catch (error) {
			console.error('Error creating insurance company:', error);
			alert($t('employeeFiles.alerts.createCompanyError'));
		} finally {
			isCreatingInsuranceCompany = false;
		}
	}

	async function createNationality() {
		if (!newNationalityId || !newNationalityNameEn || !newNationalityNameAr) {
			alert($t('employeeFiles.alerts.enterNationalityDetails') || 'Please enter all nationality details (ID, English Name, Arabic Name)');
			return;
		}

		isCreatingNationality = true;

		try {
			const { data, error } = await supabase
				.from('nationalities')
				.insert([
					{
						id: newNationalityId.toUpperCase(),
						name_en: newNationalityNameEn,
						name_ar: newNationalityNameAr
					}
				])
				.select();

			if (error) {
				console.error('Error creating nationality:', error);
				alert($t('employeeFiles.alerts.createNationalityError') || 'Error creating nationality. The ID might already exist.');
				return;
			}

			if (data && data[0]) {
				// Update nationalities list and sort it again
				await loadNationalities();
				selectedNationality = data[0].id;
				newNationalityId = '';
				newNationalityNameEn = '';
				newNationalityNameAr = '';
				showCreateNationalityModal = false;
				alert($t('employeeFiles.alerts.createNationalitySuccess') || 'Nationality created successfully');
			}
		} catch (error) {
			console.error('Error creating nationality:', error);
			alert($t('employeeFiles.alerts.createNationalityError') || 'Error creating nationality');
		} finally {
			isCreatingNationality = false;
		}
	}

	async function loadBranches() {
		isLoading = true;
		errorMessage = '';
		
		try {
			const { data, error } = await dataService.branches.getAll();
			if (error) {
				console.error('Error loading branches:', error);
				errorMessage = $t('employeeFiles.alerts.loadBranchesError');
				return;
			}
			branches = data || [];
		} catch (error) {
			console.error('Error loading branches:', error);
			errorMessage = $t('employeeFiles.alerts.loadBranchesError');
		} finally {
			isLoading = false;
		}
	}

	async function loadEmployees() {
		isLoading = true;
		errorMessage = '';
		
		try {
			const { data, error } = await supabase
				.from('hr_employee_master')
				.select(`
					id,
					name_en,
					name_ar,
					current_branch_id,
					current_position_id,
					hr_positions:current_position_id (
						position_title_en,
						position_title_ar
					),
					nationality_id,
					sponsorship_status,
					employment_status,
					id_number,
					id_expiry_date,
					work_permit_expiry_date,
					id_document_url,
					health_card_number,
					health_card_expiry_date,
					health_card_document_url,
					health_educational_renewal_date,
					driving_licence_number,
					driving_licence_expiry_date,
					driving_licence_document_url,
					contract_expiry_date,
					contract_document_url,
					bank_name,
					iban,
					date_of_birth,
					join_date,
					probation_period_expiry_date,
					insurance_company_id,
					insurance_expiry_date
				`);

			if (error) {
				console.error('Error loading employees:', error);
				errorMessage = $t('employeeFiles.alerts.loadEmployeesError');
				return;
			}
			
			// Sort numerically by extracting the number from the ID
			employees = (data || []).sort((a, b) => {
				const numA = parseInt(a.id.replace(/\D/g, '')) || 0;
				const numB = parseInt(b.id.replace(/\D/g, '')) || 0;
				return numA - numB;
			});
			
			filterEmployees();
		} catch (error) {
			console.error('Error loading employees:', error);
			errorMessage = $t('employeeFiles.alerts.loadEmployeesError');
		} finally {
			isLoading = false;
		}
	}

	function filterEmployees() {
		let filtered = employees;

		// Filter by branch
		if (selectedBranch) {
			filtered = filtered.filter(emp => 
				emp.current_branch_id === parseInt(selectedBranch)
			);
		}

		// Filter by position
		if (selectedPositionId) {
			filtered = filtered.filter(emp => 
				String(emp.current_position_id) === String(selectedPositionId)
			);
		}

		// Filter by search term
		if (searchTerm) {
			const search = searchTerm.toLowerCase();
			filtered = filtered.filter(emp => 
				emp.id?.toLowerCase().includes(search) ||
				emp.name_en?.toLowerCase().includes(search) ||
				emp.name_ar?.includes(search) ||
				emp.hr_positions?.position_title_en?.toLowerCase().includes(search) ||
				emp.hr_positions?.position_title_ar?.includes(search)
			);
		}

		filteredEmployees = filtered;
	}

	function selectEmployee(employee: any) {
		selectedEmployee = employee;
		selectedNationality = employee.nationality_id || '';
		sponsorshipStatus = employee.sponsorship_status || false;
		savedSponsorshipStatus = employee.sponsorship_status || false;
		employmentStatus = employee.employment_status || 'Resigned';
		savedEmploymentStatus = employee.employment_status || 'Resigned';
		isSaved = !!employee.nationality_id;
		idNumber = employee.id_number || '';
		savedIdNumber = employee.id_number || '';
		idExpiryDate = employee.id_expiry_date || '';
		savedIdExpiryDate = employee.id_expiry_date || '';
		workPermitExpiryDate = employee.work_permit_expiry_date || '';
		savedWorkPermitExpiryDate = employee.work_permit_expiry_date || '';
		idDocumentFile = null;
		healthCardNumber = employee.health_card_number || '';
		savedHealthCardNumber = employee.health_card_number || '';
		healthCardExpiryDate = employee.health_card_expiry_date || '';
		savedHealthCardExpiryDate = employee.health_card_expiry_date || '';
		healthEducationalRenewalDate = employee.health_educational_renewal_date || '';
		savedHealthEducationalRenewalDate = employee.health_educational_renewal_date || '';
		healthCardFile = null;
		drivingLicenceNumber = employee.driving_licence_number || '';
		savedDrivingLicenceNumber = employee.driving_licence_number || '';
		drivingLicenceExpiryDate = employee.driving_licence_expiry_date || '';
		savedDrivingLicenceExpiryDate = employee.driving_licence_expiry_date || '';
		drivingLicenceFile = null;
		contractExpiryDate = employee.contract_expiry_date || '';
		savedContractExpiryDate = employee.contract_expiry_date || '';
		contractFile = null;
		bankName = employee.bank_name || '';
		savedBankName = employee.bank_name || '';
		iban = employee.iban || '';
		savedIban = employee.iban || '';
		dateOfBirth = employee.date_of_birth || '';
		savedDateOfBirth = employee.date_of_birth || '';
		joinDate = employee.join_date || '';
		savedJoinDate = employee.join_date || '';
		probationPeriodExpiryDate = employee.probation_period_expiry_date || '';
		savedProbationPeriodExpiryDate = employee.probation_period_expiry_date || '';
		selectedInsuranceCompanyId = employee.insurance_company_id || '';
		savedInsuranceCompanyId = employee.insurance_company_id || '';
		insuranceExpiryDate = employee.insurance_expiry_date || '';
		savedInsuranceExpiryDate = employee.insurance_expiry_date || '';
		calculateDaysUntilExpiry();
		calculateWorkPermitDaysUntilExpiry();
		calculateHealthCardDaysUntilExpiry();
		calculateHealthEducationalRenewalDaysUntilExpiry();
		calculateDrivingLicenceDaysUntilExpiry();
		calculateContractDaysUntilExpiry();
		calculateInsuranceDaysUntilExpiry();
		calculateAge();
		calculateProbationPeriodDaysUntilExpiry();
		calculateWorkedDuration(employee);
		loadPOSShortages(employee.id);
	}

	function toggleEdit() {
		isSaved = false;
	}

	function calculateDaysUntilExpiry() {
		if (!idExpiryDate) {
			daysUntilExpiry = 0;
			return;
		}

		const today = new Date();
		const expiry = new Date(idExpiryDate);
		const diffTime = expiry.getTime() - today.getTime();
		const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
		daysUntilExpiry = diffDays;
	}

	function calculateWorkPermitDaysUntilExpiry() {
		if (!workPermitExpiryDate) {
			workPermitDaysUntilExpiry = 0;
			return;
		}

		const today = new Date();
		const expiry = new Date(workPermitExpiryDate);
		const diffTime = expiry.getTime() - today.getTime();
		const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
		workPermitDaysUntilExpiry = diffDays;
	}

	async function saveIDNumber() {
		if (!selectedEmployee || !idNumber) {
			alert($t('employeeFiles.alerts.enterId'));
			return;
		}

		try {
			const { error } = await supabase
				.from('hr_employee_master')
				.update({ id_number: idNumber })
				.eq('id', selectedEmployee.id);

			if (error) {
				console.error('Error saving ID number:', error);
				alert($t('employeeFiles.alerts.saveError'));
				return;
			}

			selectedEmployee.id_number = idNumber;
			savedIdNumber = idNumber;
			alert($t('employeeFiles.alerts.saveSuccess'));
		} catch (error) {
			console.error('Error saving ID number:', error);
			alert($t('employeeFiles.alerts.saveError'));
		}
	}

	async function saveIDExpiryDate() {
		if (!selectedEmployee || !idExpiryDate) {
			alert($t('employeeFiles.alerts.selectExpiry'));
			return;
		}

		try {
			const { error } = await supabase
				.from('hr_employee_master')
				.update({ id_expiry_date: idExpiryDate })
				.eq('id', selectedEmployee.id);

			if (error) {
				console.error('Error saving expiry date:', error);
				alert($t('employeeFiles.alerts.saveError'));
				return;
			}

			selectedEmployee.id_expiry_date = idExpiryDate;
			savedIdExpiryDate = idExpiryDate;
			calculateDaysUntilExpiry();
			alert($t('employeeFiles.alerts.saveSuccess'));
		} catch (error) {
			console.error('Error saving expiry date:', error);
			alert($t('employeeFiles.alerts.saveError'));
		}
	}

	async function saveWorkPermitExpiryDate() {
		if (!selectedEmployee || !workPermitExpiryDate) {
			alert($t('employeeFiles.alerts.selectWorkPermit'));
			return;
		}

		try {
			const { error } = await supabase
				.from('hr_employee_master')
				.update({ work_permit_expiry_date: workPermitExpiryDate })
				.eq('id', selectedEmployee.id);

			if (error) {
				console.error('Error saving work permit expiry date:', error);
				alert($t('employeeFiles.alerts.saveError'));
				return;
			}

			selectedEmployee.work_permit_expiry_date = workPermitExpiryDate;
			savedWorkPermitExpiryDate = workPermitExpiryDate;
			calculateWorkPermitDaysUntilExpiry();
			alert($t('employeeFiles.alerts.saveSuccess'));
		} catch (error) {
			console.error('Error saving work permit expiry date:', error);
			alert($t('employeeFiles.alerts.saveError'));
		}
	}

	async function uploadIDDocument() {
		if (!selectedEmployee || !idDocumentFile) {
			alert($t('employeeFiles.alerts.selectFile'));
			return;
		}

		isUploadingDocument = true;

		try {
			const fileExt = idDocumentFile.name.split('.').pop();
			const fileName = `${selectedEmployee.id}-id-document-${Date.now()}.${fileExt}`;
			const filePath = `${selectedEmployee.id}/${fileName}`;

			const { error: uploadError } = await supabase.storage
				.from('employee-documents')
				.upload(filePath, idDocumentFile, { upsert: true });

			if (uploadError) {
				console.error('Error uploading document:', uploadError);
				alert($t('employeeFiles.alerts.uploadError'));
				return;
			}

			const { data: publicUrl } = supabase.storage
				.from('employee-documents')
				.getPublicUrl(filePath);

			const { error: updateError } = await supabase
				.from('hr_employee_master')
				.update({ id_document_url: publicUrl.publicUrl })
				.eq('id', selectedEmployee.id);

			if (updateError) {
				console.error('Error updating document URL:', updateError);
				alert($t('employeeFiles.alerts.saveUrlError'));
				return;
			}

			selectedEmployee.id_document_url = publicUrl.publicUrl;
			idDocumentFile = null;
			alert($t('employeeFiles.alerts.uploadSuccess'));
		} catch (error) {
			console.error('Error uploading document:', error);
			alert($t('employeeFiles.alerts.uploadError'));
		} finally {
			isUploadingDocument = false;
		}
	}

	function viewIDDocument() {
		if (selectedEmployee?.id_document_url) {
			window.open(selectedEmployee.id_document_url, '_blank');
		}
	}

	function calculateHealthCardDaysUntilExpiry() {
		if (!healthCardExpiryDate) {
			healthCardDaysUntilExpiry = 0;
			return;
		}

		const today = new Date();
		const expiry = new Date(healthCardExpiryDate);
		const diffTime = expiry.getTime() - today.getTime();
		const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
		healthCardDaysUntilExpiry = diffDays;
	}

	function calculateHealthEducationalRenewalDaysUntilExpiry() {
		if (!healthEducationalRenewalDate) {
			healthEducationalRenewalDaysUntilExpiry = 0;
			return;
		}

		const today = new Date();
		const expiry = new Date(healthEducationalRenewalDate);
		const diffTime = expiry.getTime() - today.getTime();
		const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
		healthEducationalRenewalDaysUntilExpiry = diffDays;
	}

	function calculateAge() {
		if (!dateOfBirth) {
			age = 0;
			return;
		}

		const today = new Date();
		const birthDate = new Date(dateOfBirth);
		let calculatedAge = today.getFullYear() - birthDate.getFullYear();
		const monthDiff = today.getMonth() - birthDate.getMonth();
		
		// Adjust age if birthday hasn't occurred this year
		if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < birthDate.getDate())) {
			calculatedAge--;
		}
		
		age = calculatedAge;
	}

	function calculateWorkedDuration(employee: any) {
		if (!savedJoinDate) {
			workedYears = 0;
			workedMonths = 0;
			workedDays = 0;
			return;
		}

		// Determine the end date based on employment status
		let endDate = new Date(); // Default to today

		const statusesWithEffectiveDate = ['Resigned', 'Terminated', 'Run Away'];
		if (statusesWithEffectiveDate.includes(employmentStatus) && employee.employment_status_effective_date) {
			endDate = new Date(employee.employment_status_effective_date);
		}

		const startDate = new Date(savedJoinDate);
		
		// Calculate years, months, and days
		let years = endDate.getFullYear() - startDate.getFullYear();
		let months = endDate.getMonth() - startDate.getMonth();
		let days = endDate.getDate() - startDate.getDate();

		// Adjust for negative days
		if (days < 0) {
			months--;
			const prevMonth = new Date(endDate.getFullYear(), endDate.getMonth(), 0);
			days += prevMonth.getDate();
		}

		// Adjust for negative months
		if (months < 0) {
			years--;
			months += 12;
		}

		workedYears = years;
		workedMonths = months;
		workedDays = days;
	}

	function calculateProbationPeriodDaysUntilExpiry() {
		if (!probationPeriodExpiryDate) {
			probationPeriodDaysUntilExpiry = 0;
			return;
		}

		const today = new Date();
		const expiry = new Date(probationPeriodExpiryDate);
		const diffTime = expiry.getTime() - today.getTime();
		const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
		probationPeriodDaysUntilExpiry = diffDays;
	}

	async function saveHealthCardNumber() {
		if (!selectedEmployee || !healthCardNumber) {
			alert($t('employeeFiles.alerts.enterHealthNumber'));
			return;
		}

		try {
			const { error } = await supabase
				.from('hr_employee_master')
				.update({ health_card_number: healthCardNumber })
				.eq('id', selectedEmployee.id);

			if (error) {
				console.error('Error saving health card number:', error);
				alert($t('employeeFiles.alerts.saveError'));
				return;
			}

			selectedEmployee.health_card_number = healthCardNumber;
			savedHealthCardNumber = healthCardNumber;
			alert($t('employeeFiles.alerts.saveSuccess'));
		} catch (error) {
			console.error('Error saving health card number:', error);
			alert($t('employeeFiles.alerts.saveError'));
		}
	}

	async function saveHealthCardExpiryDate() {
		if (!selectedEmployee || !healthCardExpiryDate) {
			alert($t('employeeFiles.alerts.selectExpiry'));
			return;
		}

		try {
			const { error } = await supabase
				.from('hr_employee_master')
				.update({ health_card_expiry_date: healthCardExpiryDate })
				.eq('id', selectedEmployee.id);

			if (error) {
				console.error('Error saving health card expiry date:', error);
				alert($t('employeeFiles.alerts.saveError'));
				return;
			}

			selectedEmployee.health_card_expiry_date = healthCardExpiryDate;
			savedHealthCardExpiryDate = healthCardExpiryDate;
			calculateHealthCardDaysUntilExpiry();
			alert($t('employeeFiles.alerts.saveSuccess'));
		} catch (error) {
			console.error('Error saving health card expiry date:', error);
			alert($t('employeeFiles.alerts.saveError'));
		}
	}

	async function saveHealthEducationalRenewalDate() {
		if (!selectedEmployee || !healthEducationalRenewalDate) {
			alert($t('employeeFiles.alerts.selectRenewalDate'));
			return;
		}

		try {
			const { error } = await supabase
				.from('hr_employee_master')
				.update({ health_educational_renewal_date: healthEducationalRenewalDate })
				.eq('id', selectedEmployee.id);

			if (error) {
				console.error('Error saving health educational renewal date:', error);
				alert($t('employeeFiles.alerts.saveError'));
				return;
			}

			selectedEmployee.health_educational_renewal_date = healthEducationalRenewalDate;
			savedHealthEducationalRenewalDate = healthEducationalRenewalDate;
			calculateHealthEducationalRenewalDaysUntilExpiry();
			alert($t('employeeFiles.alerts.saveSuccess'));
		} catch (error) {
			console.error('Error saving health educational renewal date:', error);
			alert($t('employeeFiles.alerts.saveError'));
		}
	}

	async function uploadHealthCardDocument() {
		if (!selectedEmployee || !healthCardFile) {
			alert($t('employeeFiles.alerts.selectFile'));
			return;
		}

		isUploadingHealthCard = true;

		try {
			const fileExt = healthCardFile.name.split('.').pop();
			const fileName = `${selectedEmployee.id}-health-card-${Date.now()}.${fileExt}`;
			const filePath = `${selectedEmployee.id}/${fileName}`;

			const { error: uploadError } = await supabase.storage
				.from('employee-documents')
				.upload(filePath, healthCardFile, { upsert: true });

			if (uploadError) {
				console.error('Error uploading health card document:', uploadError);
				alert($t('employeeFiles.alerts.uploadError'));
				return;
			}

			const { data: publicUrl } = supabase.storage
				.from('employee-documents')
				.getPublicUrl(filePath);

			const { error: updateError } = await supabase
				.from('hr_employee_master')
				.update({ health_card_document_url: publicUrl.publicUrl })
				.eq('id', selectedEmployee.id);

			if (updateError) {
				console.error('Error updating health card document URL:', updateError);
				alert($t('employeeFiles.alerts.saveUrlError'));
				return;
			}

			selectedEmployee.health_card_document_url = publicUrl.publicUrl;
			healthCardFile = null;
			alert($t('employeeFiles.alerts.uploadSuccess'));
		} catch (error) {
			console.error('Error uploading health card document:', error);
			alert($t('employeeFiles.alerts.uploadError'));
		} finally {
			isUploadingHealthCard = false;
		}
	}

	function viewHealthCardDocument() {
		if (selectedEmployee?.health_card_document_url) {
			window.open(selectedEmployee.health_card_document_url, '_blank');
		}
	}

	function calculateDrivingLicenceDaysUntilExpiry() {
		if (!drivingLicenceExpiryDate) {
			drivingLicenceDaysUntilExpiry = 0;
			return;
		}

		const today = new Date();
		const expiry = new Date(drivingLicenceExpiryDate);
		const diffTime = expiry.getTime() - today.getTime();
		const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
		drivingLicenceDaysUntilExpiry = diffDays;
	}

	async function saveDrivingLicenceNumber() {
		if (!selectedEmployee || !drivingLicenceNumber) {
			alert($t('employeeFiles.alerts.enterDrivingNumber'));
			return;
		}

		try {
			const { error } = await supabase
				.from('hr_employee_master')
				.update({ driving_licence_number: drivingLicenceNumber })
				.eq('id', selectedEmployee.id);

			if (error) {
				console.error('Error saving driving licence number:', error);
				alert($t('employeeFiles.alerts.saveError'));
				return;
			}

			selectedEmployee.driving_licence_number = drivingLicenceNumber;
			savedDrivingLicenceNumber = drivingLicenceNumber;
			alert($t('employeeFiles.alerts.saveSuccess'));
		} catch (error) {
			console.error('Error saving driving licence number:', error);
			alert($t('employeeFiles.alerts.saveError'));
		}
	}

	async function saveDrivingLicenceExpiryDate() {
		if (!selectedEmployee || !drivingLicenceExpiryDate) {
			alert($t('employeeFiles.alerts.selectExpiry'));
			return;
		}

		try {
			const { error } = await supabase
				.from('hr_employee_master')
				.update({ driving_licence_expiry_date: drivingLicenceExpiryDate })
				.eq('id', selectedEmployee.id);

			if (error) {
				console.error('Error saving driving licence expiry date:', error);
				alert($t('employeeFiles.alerts.saveError'));
				return;
			}

			selectedEmployee.driving_licence_expiry_date = drivingLicenceExpiryDate;
			savedDrivingLicenceExpiryDate = drivingLicenceExpiryDate;
			calculateDrivingLicenceDaysUntilExpiry();
			alert($t('employeeFiles.alerts.saveSuccess'));
		} catch (error) {
			console.error('Error saving driving licence expiry date:', error);
			alert($t('employeeFiles.alerts.saveError'));
		}
	}

	async function uploadDrivingLicenceDocument() {
		if (!selectedEmployee || !drivingLicenceFile) {
			alert($t('employeeFiles.alerts.selectFile'));
			return;
		}

		isUploadingDrivingLicence = true;

		try {
			const fileExt = drivingLicenceFile.name.split('.').pop();
			const fileName = `${selectedEmployee.id}-driving-licence-${Date.now()}.${fileExt}`;
			const filePath = `${selectedEmployee.id}/${fileName}`;

			const { error: uploadError } = await supabase.storage
				.from('employee-documents')
				.upload(filePath, drivingLicenceFile, { upsert: true });

			if (uploadError) {
				console.error('Error uploading driving licence document:', uploadError);
				alert($t('employeeFiles.alerts.uploadError'));
				return;
			}

			const { data: publicUrl } = supabase.storage
				.from('employee-documents')
				.getPublicUrl(filePath);

			const { error: updateError } = await supabase
				.from('hr_employee_master')
				.update({ driving_licence_document_url: publicUrl.publicUrl })
				.eq('id', selectedEmployee.id);

			if (updateError) {
				console.error('Error updating driving licence document URL:', updateError);
				alert($t('employeeFiles.alerts.saveError'));
				return;
			}

			selectedEmployee.driving_licence_document_url = publicUrl.publicUrl;
			drivingLicenceFile = null;
			alert($t('employeeFiles.alerts.uploadSuccess'));
		} catch (error) {
			console.error('Error uploading driving licence document:', error);
			alert($t('employeeFiles.alerts.uploadError'));
		} finally {
			isUploadingDrivingLicence = false;
		}
	}

	function viewDrivingLicenceDocument() {
		if (selectedEmployee?.driving_licence_document_url) {
			window.open(selectedEmployee.driving_licence_document_url, '_blank');
		}
	}

	function calculateContractDaysUntilExpiry() {
		if (!contractExpiryDate) {
			contractDaysUntilExpiry = 0;
			return;
		}

		const today = new Date();
		const expiry = new Date(contractExpiryDate);
		const diffTime = expiry.getTime() - today.getTime();
		const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
		contractDaysUntilExpiry = diffDays;
	}

	async function saveContractExpiryDate() {
		if (!selectedEmployee || !contractExpiryDate) {
			alert($t('employeeFiles.alerts.selectDate'));
			return;
		}

		try {
			const { error } = await supabase
				.from('hr_employee_master')
				.update({ contract_expiry_date: contractExpiryDate })
				.eq('id', selectedEmployee.id);

			if (error) {
				console.error('Error saving contract expiry date:', error);
				alert($t('employeeFiles.alerts.saveError'));
				return;
			}

			selectedEmployee.contract_expiry_date = contractExpiryDate;
			savedContractExpiryDate = contractExpiryDate;
			calculateContractDaysUntilExpiry();
			alert($t('employeeFiles.alerts.saveSuccess'));
		} catch (error) {
			console.error('Error saving contract expiry date:', error);
			alert($t('employeeFiles.alerts.saveError'));
		}
	}

	async function uploadContractDocument() {
		if (!selectedEmployee || !contractFile) {
			alert($t('employeeFiles.alerts.selectFile'));
			return;
		}

		isUploadingContract = true;

		try {
			const fileExt = contractFile.name.split('.').pop();
			const fileName = `${selectedEmployee.id}-contract-${Date.now()}.${fileExt}`;
			const filePath = `${selectedEmployee.id}/${fileName}`;

			const { error: uploadError } = await supabase.storage
				.from('employee-documents')
				.upload(filePath, contractFile, { upsert: true });

			if (uploadError) {
				console.error('Error uploading contract document:', uploadError);
				alert($t('employeeFiles.alerts.uploadError'));
				return;
			}

			const { data: publicUrl } = supabase.storage
				.from('employee-documents')
				.getPublicUrl(filePath);

			const { error: updateError } = await supabase
				.from('hr_employee_master')
				.update({ contract_document_url: publicUrl.publicUrl })
				.eq('id', selectedEmployee.id);

			if (updateError) {
				console.error('Error updating contract document URL:', updateError);
				alert($t('employeeFiles.alerts.saveError'));
				return;
			}

			selectedEmployee.contract_document_url = publicUrl.publicUrl;
			contractFile = null;
			alert($t('employeeFiles.alerts.uploadSuccess'));
		} catch (error) {
			console.error('Error uploading contract document:', error);
			alert($t('employeeFiles.alerts.uploadError'));
		} finally {
			isUploadingContract = false;
		}
	}

	function viewContractDocument() {
		if (selectedEmployee?.contract_document_url) {
			window.open(selectedEmployee.contract_document_url, '_blank');
		}
	}

	async function saveBankName() {
		if (!selectedEmployee || !bankName) {
			alert($t('employeeFiles.alerts.enterBankName'));
			return;
		}

		try {
			const { error } = await supabase
				.from('hr_employee_master')
				.update({ bank_name: bankName })
				.eq('id', selectedEmployee.id);

			if (error) {
				console.error('Error saving bank name:', error);
				alert($t('employeeFiles.alerts.saveError'));
				return;
			}

			selectedEmployee.bank_name = bankName;
			savedBankName = bankName;
			alert($t('employeeFiles.alerts.saveSuccess'));
		} catch (error) {
			console.error('Error saving bank name:', error);
			alert($t('employeeFiles.alerts.saveError'));
		}
	}

	async function saveIban() {
		if (!selectedEmployee || !iban) {
			alert($t('employeeFiles.alerts.enterIban'));
			return;
		}

		try {
			const { error } = await supabase
				.from('hr_employee_master')
				.update({ iban: iban })
				.eq('id', selectedEmployee.id);

			if (error) {
				console.error('Error saving IBAN:', error);
				alert($t('employeeFiles.alerts.saveError'));
				return;
			}

			selectedEmployee.iban = iban;
			savedIban = iban;
			alert($t('employeeFiles.alerts.saveSuccess'));
		} catch (error) {
			console.error('Error saving IBAN:', error);
			alert($t('employeeFiles.alerts.saveError'));
		}
	}

	async function saveDateOfBirth() {
		if (!selectedEmployee || !dateOfBirth) {
			alert($t('employeeFiles.alerts.enterDob'));
			return;
		}

		try {
			const { error } = await supabase
				.from('hr_employee_master')
				.update({ date_of_birth: dateOfBirth })
				.eq('id', selectedEmployee.id);

			if (error) {
				console.error('Error saving date of birth:', error);
				alert($t('employeeFiles.alerts.saveError'));
				return;
			}

			selectedEmployee.date_of_birth = dateOfBirth;
			savedDateOfBirth = dateOfBirth;
			calculateAge();
			alert($t('employeeFiles.alerts.saveSuccess'));
		} catch (error) {
			console.error('Error saving date of birth:', error);
			alert($t('employeeFiles.alerts.saveError'));
		}
	}

	async function saveJoinDate() {
		if (!selectedEmployee || !joinDate) {
			alert($t('employeeFiles.alerts.enterJoinDate'));
			return;
		}

		try {
			const { error } = await supabase
				.from('hr_employee_master')
				.update({ join_date: joinDate })
				.eq('id', selectedEmployee.id);

			if (error) {
				console.error('Error saving join date:', error);
				alert($t('employeeFiles.alerts.saveError'));
				return;
			}

			selectedEmployee.join_date = joinDate;
			savedJoinDate = joinDate;
			// Recalculate worked duration when join date changes
			calculateWorkedDuration(selectedEmployee);
			alert($t('employeeFiles.alerts.saveSuccess'));
		} catch (error) {
			console.error('Error saving join date:', error);
			alert($t('employeeFiles.alerts.saveError'));
		}
	}

	async function saveProbationPeriodExpiryDate() {
		if (!selectedEmployee || !probationPeriodExpiryDate) {
			alert($t('employeeFiles.alerts.enterProbationDate'));
			return;
		}

		try {
			const { error } = await supabase
				.from('hr_employee_master')
				.update({ probation_period_expiry_date: probationPeriodExpiryDate })
				.eq('id', selectedEmployee.id);

			if (error) {
				console.error('Error saving probation period expiry date:', error);
				alert($t('employeeFiles.alerts.saveError'));
				return;
			}

			selectedEmployee.probation_period_expiry_date = probationPeriodExpiryDate;
			savedProbationPeriodExpiryDate = probationPeriodExpiryDate;
			calculateProbationPeriodDaysUntilExpiry();
			alert($t('employeeFiles.alerts.saveSuccess'));
		} catch (error) {
			console.error('Error saving probation period expiry date:', error);
			alert($t('employeeFiles.alerts.saveError'));
		}
	}

	function calculateInsuranceDaysUntilExpiry() {
		if (!insuranceExpiryDate) {
			insuranceDaysUntilExpiry = 0;
			return;
		}

		const today = new Date();
		const expiry = new Date(insuranceExpiryDate);
		const diffTime = expiry.getTime() - today.getTime();
		const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
		insuranceDaysUntilExpiry = diffDays;
	}

	async function saveInsuranceCompanyId() {
		if (!selectedEmployee || !selectedInsuranceCompanyId) {
			alert($t('employeeFiles.alerts.selectInsuranceCompany'));
			return;
		}

		try {
			const { error } = await supabase
				.from('hr_employee_master')
				.update({ insurance_company_id: selectedInsuranceCompanyId })
				.eq('id', selectedEmployee.id);

			if (error) {
				console.error('Error saving insurance company:', error);
				alert($t('employeeFiles.alerts.saveError'));
				return;
			}

			selectedEmployee.insurance_company_id = selectedInsuranceCompanyId;
			savedInsuranceCompanyId = selectedInsuranceCompanyId;
			alert($t('employeeFiles.alerts.saveSuccess'));
		} catch (error) {
			console.error('Error saving insurance company:', error);
			alert($t('employeeFiles.alerts.saveError'));
		}
	}

	async function saveInsuranceExpiryDate() {
		if (!selectedEmployee || !insuranceExpiryDate) {
			alert($t('employeeFiles.alerts.selectExpiry'));
			return;
		}

		try {
			const { error } = await supabase
				.from('hr_employee_master')
				.update({ insurance_expiry_date: insuranceExpiryDate })
				.eq('id', selectedEmployee.id);

			if (error) {
				console.error('Error saving insurance expiry date:', error);
				alert($t('employeeFiles.alerts.saveError'));
				return;
			}

			selectedEmployee.insurance_expiry_date = insuranceExpiryDate;
			savedInsuranceExpiryDate = insuranceExpiryDate;
			calculateInsuranceDaysUntilExpiry();
			alert($t('employeeFiles.alerts.saveSuccess'));
		} catch (error) {
			console.error('Error saving insurance expiry date:', error);
			alert($t('employeeFiles.alerts.saveError'));
		}
	}

	async function saveNationality() {
		if (!selectedEmployee || !selectedNationality) {
			alert($t('employeeFiles.alerts.selectNationality'));
			return;
		}

		try {
			const { error } = await supabase
				.from('hr_employee_master')
				.update({ nationality_id: selectedNationality })
				.eq('id', selectedEmployee.id);

			if (error) {
				console.error('Error saving nationality:', error);
				alert($t('employeeFiles.alerts.saveError'));
				return;
			}

			selectedEmployee.nationality_id = selectedNationality;
			isSaved = true;
			alert($t('employeeFiles.alerts.saveSuccess'));
		} catch (error) {
			console.error('Error saving nationality:', error);
			alert($t('employeeFiles.alerts.saveError'));
		}
	}

	async function saveSponsorshipStatus() {
		if (!selectedEmployee) {
			alert($t('employeeFiles.alerts.selectEmployee'));
			return;
		}

		try {
			const { error } = await supabase
				.from('hr_employee_master')
				.update({ sponsorship_status: sponsorshipStatus })
				.eq('id', selectedEmployee.id);

			if (error) {
				console.error('Error saving sponsorship status:', error);
				alert($t('employeeFiles.alerts.saveError'));
				return;
			}

			selectedEmployee.sponsorship_status = sponsorshipStatus;
			savedSponsorshipStatus = sponsorshipStatus;
			alert($t('employeeFiles.alerts.saveSuccess'));
		} catch (error) {
			console.error('Error saving sponsorship status:', error);
			alert($t('employeeFiles.alerts.saveError'));
		}
	}

	function getEmploymentStatusText(status: string) {
		switch (status) {
			case 'Job (With Finger)': return $t('employeeFiles.inJob');
			case 'Job (No Finger)': return $t('employeeFiles.jobNoFinger');
			case 'Remote Job': return $t('employeeFiles.remoteJob');
			case 'Vacation': return $t('employeeFiles.vacation');
			case 'Terminated': return $t('employeeFiles.terminated');
			case 'Run Away': return $t('employeeFiles.runAway');
			case 'Resigned': return $t('employeeFiles.resigned');
			default: return status;
		}
	}

	function checkStatusRequiresEffectiveDate(status: string) {
		const statusesRequiringEffectiveDate = ['Resigned', 'Terminated', 'Run Away'];
		if (statusesRequiringEffectiveDate.includes(status)) {
			effectiveDate = '';
			effectiveDateReason = '';
			showEffectiveDateModal = true;
		}
	}

	async function saveEmploymentStatus() {
		if (!selectedEmployee) {
			alert($t('employeeFiles.alerts.selectEmployee'));
			return;
		}

		try {
			const updateData: any = { employment_status: employmentStatus };
			
			// Add effective date if the status requires it
			const statusesRequiringEffectiveDate = ['Resigned', 'Terminated', 'Run Away'];
			if (statusesRequiringEffectiveDate.includes(employmentStatus)) {
				updateData.employment_status_effective_date = effectiveDate;
				updateData.employment_status_reason = effectiveDateReason;
			}

			const { error } = await supabase
				.from('hr_employee_master')
				.update(updateData)
				.eq('id', selectedEmployee.id);

			if (error) {
				console.error('Error saving employment status:', error);
				alert($t('employeeFiles.alerts.saveError'));
				return;
			}

			selectedEmployee.employment_status = employmentStatus;
			savedEmploymentStatus = employmentStatus;
			// Update the effective date in the employee object if applicable
			if (statusesRequiringEffectiveDate.includes(employmentStatus)) {
				selectedEmployee.employment_status_effective_date = effectiveDate;
			}
			// Recalculate worked duration
			calculateWorkedDuration(selectedEmployee);
			alert($t('employeeFiles.alerts.saveSuccess'));
		} catch (error) {
			console.error('Error saving employment status:', error);
			alert($t('employeeFiles.alerts.saveError'));
		}
	}

	// Reactive statements to trigger filtering
	$: if (selectedBranch !== undefined || selectedPositionId !== undefined || searchTerm !== undefined) {
		filterEmployees();
	}
</script>

<div class="employee-files-container">
	<div class="cards-wrapper">
		<!-- Card 1: Search & Select Employee -->
		<div class="card">
			<div class="card-header">
				<h3>🔍 {$t('employeeFiles.searchEmployee')}</h3>
			</div>
			<div class="card-content">
			<!-- Frozen Filter Section -->
			<div class="filters-section-header">
				<h4>{$t('employeeFiles.filters')}</h4>
				<button class="seal-button" on:click={toggleFilters}>
					{#if filtersOpen}
						✕ {$t('commands.close')}
					{:else}
						{$localeData.direction === 'rtl' ? '◀' : '▶'} {$t('commands.open')}
					{/if}
				</button>
			</div>
			{#if filtersOpen}
			<div class="filters-section">
				<!-- Branch Filter -->
				<div class="form-group">
						<label for="branch-filter">{$t('employeeFiles.branch')}</label>
						<select id="branch-filter" bind:value={selectedBranch}>
							<option value="">{$t('employeeFiles.allBranches')}</option>
							{#each branches as branch}
								<option value={branch.id} style="color: #000000; background-color: #ffffff;">
									{$locale === 'ar' 
										? `${branch.name_ar || branch.name_en}${branch.location_ar ? ' (' + branch.location_ar + ')' : ''}`
										: `${branch.name_en || branch.name}${branch.location_en ? ' (' + branch.location_en + ')' : ''}`}
								</option>
							{/each}
						</select>
					</div>

					<!-- Position Filter -->
					<div class="form-group">
						<label for="position-filter">{$t('employeeFiles.position')}</label>
						<select id="position-filter" bind:value={selectedPositionId}>
							<option value="">{$t('employeeFiles.allPositions')}</option>
							{#each positions as pos}
								<option value={pos.id}>{pos.position_title_en} | {pos.position_title_ar}</option>
							{/each}
						</select>
					</div>

					<!-- Search Input -->
					<div class="form-group">
						<label for="search">{$t('employeeFiles.searchPlaceholder')}</label>
						<input 
							type="text" 
							id="search" 
							bind:value={searchTerm} 
							placeholder={$t('employeeFiles.searchPlaceholder')}
						/>
					</div>
				</div>
			{/if}

			<!-- Employee List -->
			<div class="employee-list">
					{#if isLoading}
						<div class="loading">{$t('employeeFiles.loadingEmployees')}</div>
					{:else if errorMessage}
						<div class="error">{errorMessage}</div>
					{:else}
						<div class="list-header-wrapper">
							<div class="list-header">
								<span>{$t('employeeFiles.id')}</span>
								<span>{$t('employeeFiles.name')}</span>
								<span>{$t('employeeFiles.position')}</span>
							</div>
						</div>
						<div class="list-body">
							{#each filteredEmployees as employee}
								<div 
									class="employee-item" 
									class:selected={selectedEmployee?.id === employee.id}
									on:click={() => selectEmployee(employee)}
								>
									<span class="emp-id">{employee.id}</span>
									<div class="emp-name-stack">
										{#if $localeData.direction === 'rtl'}
											<div class="emp-name-ar">{employee.name_ar || '-'}</div>
										{:else}
											<div class="emp-name-en">{employee.name_en || '-'}</div>
										{/if}
									</div>
									<div class="emp-position-stack">
										{#if $localeData.direction === 'rtl'}
											<div class="emp-position-ar">{employee.hr_positions?.position_title_ar || '-'}</div>
										{:else}
											<div class="emp-position-en">{employee.hr_positions?.position_title_en || '-'}</div>
										{/if}
									</div>
								</div>
							{:else}
								<div class="no-results">{$t('employeeFiles.noEmployeesFound')}</div>
							{/each}
						</div>
					{/if}
				</div>
			</div>
		</div>

		<!-- Card 2: Employee Files -->
		<div class="card">
			<div class="card-header">
				<h3>📄 {$t('employeeFiles.title')}</h3>
			</div>
			<div class="card-content">
				{#if selectedEmployee}
					<div class="selected-info">
						<div class="info-grid">
							<div class="info-item">
								<span class="info-label">{$t('employeeFiles.id')}</span>
								<span class="info-value">{selectedEmployee.id}</span>
							</div>
							<div class="info-item">
								<span class="info-label">{$t('employeeFiles.nameAr')}</span>
								<span class="info-value info-arabic">{selectedEmployee.name_ar || '-'}</span>
							</div>
							<div class="info-item">
								<span class="info-label">{$t('employeeFiles.nameEn')}</span>
								<span class="info-value">{selectedEmployee.name_en || '-'}</span>
							</div>
							<div class="info-item">
								<span class="info-label">{$t('employeeFiles.positionAr')}</span>
								<span class="info-value info-arabic">{selectedEmployee.hr_positions?.position_title_ar || '-'}</span>
							</div>
							<div class="info-item">
								<span class="info-label">{$t('employeeFiles.positionEn')}</span>
								<span class="info-value">{selectedEmployee.hr_positions?.position_title_en || '-'}</span>
							</div>
						</div>
					</div>

					<!-- File Management Cards Grid -->
					<div class="file-cards-grid">
						<!-- Card 1: Nationality Selector -->
						<div class="file-card nationality-card">
							<div class="file-card-content nationality-content">
								<div class="nationality-form">
									<h5>{$t('employeeFiles.nationality')}</h5>
									{#if isSaved}
										<!-- Display saved nationality -->
										<div class="saved-nationality">
											<span class="nationality-display">
												{nationalities.find(n => n.id === selectedNationality)?.name_ar || ''} / 
												{nationalities.find(n => n.id === selectedNationality)?.name_en || ''}
											</span>
										</div>
									{:else}
										<!-- Edit mode -->
										<div class="input-with-button">
											<select bind:value={selectedNationality}>
												<option value="">{$t('commands.close')}</option>
												{#each nationalities as nationality}
													<option value={nationality.id}>{nationality.name_ar} / {nationality.name_en}</option>
												{/each}
											</select>
											<button class="add-btn-small" on:click={() => showCreateNationalityModal = true} title={$t('employeeFiles.addNationality') || 'Add Nationality'}>
												➕
											</button>
										</div>
									{/if}
									<button class="save-button" on:click={isSaved ? toggleEdit : saveNationality}>
										{#if isSaved}
											✏️ {$t('employeeFiles.edit')}
										{:else}
											💾 {$t('employeeFiles.save')}
										{/if}
									</button>
									
									<!-- Sponsorship Status Toggle -->
									<div class="sponsorship-toggle">
										<label class="toggle-label">
											<span>{$t('employeeFiles.sponsorshipStatus')}</span>
											<div class="toggle-switch">
												<input 
													type="checkbox" 
													bind:checked={sponsorshipStatus}
													class="toggle-input"
												/>
												<span class="toggle-slider"></span>
											</div>
											<span class="toggle-status">{sponsorshipStatus ? $t('employeeFiles.active') : $t('employeeFiles.inactive')}</span>
										</label>
										{#if sponsorshipStatus !== savedSponsorshipStatus}
											<button class="save-button-small" on:click={saveSponsorshipStatus}>
												💾 {$t('employeeFiles.saveStatus')}
											</button>
										{/if}
									</div>

									<!-- Employment Status Toggle Buttons (7 Rows) -->
									<div class="employment-status-section">
										<label class="status-section-label">{$t('employeeFiles.employmentStatus')}</label>
										<div class="employment-status-rows">
											{#each ['Job (With Finger)', 'Job (No Finger)', 'Remote Job', 'Vacation', 'Resigned', 'Terminated', 'Run Away'] as status}
												<div class="status-row">
													<label class="status-radio-label">
														<input 
															type="radio" 
															name="employment-status"
															value={status}
															bind:group={employmentStatus}
															on:change={() => checkStatusRequiresEffectiveDate(status)}
															class="status-radio-input"
														/>
														<span class="status-radio-button"></span>
														<span class="status-text">{getEmploymentStatusText(status)}</span>
													</label>
												</div>
											{/each}
										</div>
										{#if employmentStatus !== savedEmploymentStatus}
											<button class="save-button-small" on:click={saveEmploymentStatus}>
												💾 {$t('employeeFiles.saveStatus')}
											</button>
										{/if}
									</div>
								</div>
							</div>
						</div>

					<!-- Card 2: ID Document Management -->
					<div class="file-card id-card">
						<div class="file-card-content id-content">
							<div class="id-form">
								<h5>{$t('employeeFiles.idResidentTitle')}</h5>
								
								<!-- ID Number Field -->
								{#if !savedIdNumber}
									<!-- Show input when no number is saved -->
									<div class="form-group-compact">
										<label for="id-number">{$t('employeeFiles.idNumber')}</label>
										<input 
											type="text" 
											id="id-number" 
											bind:value={idNumber}
											placeholder={$t('employeeFiles.enterIdNumber')}
										/>
									</div>
									<button class="save-button-small" on:click={saveIDNumber}>
										💾 {$t('employeeFiles.saveNumber')}
									</button>
								{:else}
									<!-- Show saved number info -->
									<div class="saved-date-info">
										<div class="saved-date-display">
											<span class="date-label">{$t('employeeFiles.idNumber')}:</span>
											<span class="date-value">{savedIdNumber}</span>
										</div>
									</div>
									
									<!-- Edit number input (hidden by default) -->
									{#if idNumber !== savedIdNumber}
										<div class="form-group-compact">
											<label for="id-number-edit">{$t('employeeFiles.changeIdNumber')}</label>
											<input 
												type="text" 
												id="id-number-edit" 
												bind:value={idNumber}
												placeholder={$t('employeeFiles.enterIdNumber')}
											/>
										</div>
										<button class="save-button-small" on:click={saveIDNumber}>
											💾 {$t('employeeFiles.updateNumber')}
										</button>
									{:else}
										<button class="update-button" on:click={() => idNumber = ''}>
											✏️ {$t('employeeFiles.editNumber')}
										</button>
									{/if}
								{/if}
								
								<!-- Expiry Date Field -->
								{#if !savedIdExpiryDate}
									<!-- Show input when no date is saved -->
									<div class="form-group-compact">
										<label for="id-expiry">{$t('employeeFiles.expiryDate')}</label>
										<input 
											type="date" 
											id="id-expiry" 
											bind:value={idExpiryDate}
											on:change={calculateDaysUntilExpiry}
										/>
									</div>
									<button class="save-button-small" on:click={saveIDExpiryDate}>
										💾 {$t('employeeFiles.saveDate')}
									</button>
								{:else}
									<!-- Show saved date info when saved -->
									<div class="saved-date-info">
										<div class="saved-date-display">
											<span class="date-label">{$t('employeeFiles.save')}:</span>
											<span class="date-value">
												{savedIdExpiryDate ? new Date(savedIdExpiryDate).toLocaleDateString('en-GB') : '-'}
											</span>
										</div>
										{#if daysUntilExpiry > 0}
											<span class="expiry-valid">⏰ {daysUntilExpiry} {$t('employeeFiles.days')} {$t('employeeFiles.remaining')}</span>
										{:else if daysUntilExpiry === 0}
											<span class="expiry-warning">⚠️ {$t('employeeFiles.expiresToday')}</span>
										{:else}
											<span class="expiry-expired">❌ {$t('employeeFiles.expiredAgo').replace('{days}', Math.abs(daysUntilExpiry).toString())}</span>
										{/if}
									</div>
									
									<!-- Edit date input (hidden by default) -->
									{#if idExpiryDate !== savedIdExpiryDate}
										<div class="form-group-compact">
											<label for="id-expiry">{$t('employeeFiles.changeExpiryDate')}</label>
											<input 
												type="date" 
												id="id-expiry" 
												bind:value={idExpiryDate}
												on:change={calculateDaysUntilExpiry}
											/>
										</div>
										<button class="save-button-small" on:click={saveIDExpiryDate}>
											💾 {$t('employeeFiles.saveDate')}
										</button>
									{:else}
										<button class="update-button" on:click={() => idExpiryDate = ''}>
											✏️ {$t('employeeFiles.updateDate')}
										</button>
									{/if}
								{/if}

								<!-- Work Permit Expiry Date Field -->
								{#if !savedWorkPermitExpiryDate}
									<!-- Show input when no date is saved -->
									<div class="form-group-compact">
										<label for="work-permit-expiry">{$t('employeeFiles.workPermitExpiryDate')}</label>
										<input 
											type="date" 
											id="work-permit-expiry" 
											bind:value={workPermitExpiryDate}
											on:change={calculateWorkPermitDaysUntilExpiry}
										/>
									</div>
									<button class="save-button-small" on:click={saveWorkPermitExpiryDate}>
										💾 {$t('employeeFiles.saveDate')}
									</button>
								{:else}
									<!-- Show saved date info when saved -->
									<div class="saved-date-info">
										<div class="saved-date-display">
											<span class="date-label">{$t('employeeFiles.workPermitExpiryDate')}:</span>
											<span class="date-value">
												{savedWorkPermitExpiryDate ? new Date(savedWorkPermitExpiryDate).toLocaleDateString('en-GB') : '-'}
											</span>
										</div>
										{#if workPermitDaysUntilExpiry > 0}
											<span class="expiry-valid">⏰ {workPermitDaysUntilExpiry} {$t('employeeFiles.days')} {$t('employeeFiles.remaining')}</span>
										{:else if workPermitDaysUntilExpiry === 0}
											<span class="expiry-warning">⚠️ {$t('employeeFiles.expiresToday')}</span>
										{:else}
											<span class="expiry-expired">❌ {$t('employeeFiles.expiredAgo').replace('{days}', Math.abs(workPermitDaysUntilExpiry).toString())}</span>
										{/if}
									</div>
									
									<!-- Edit date input (hidden by default) -->
									{#if workPermitExpiryDate !== savedWorkPermitExpiryDate}
										<div class="form-group-compact">
											<label for="work-permit-expiry">{$t('employeeFiles.changeExpiryDate')}</label>
											<input 
												type="date" 
												id="work-permit-expiry" 
												bind:value={workPermitExpiryDate}
												on:change={calculateWorkPermitDaysUntilExpiry}
											/>
										</div>
										<button class="save-button-small" on:click={saveWorkPermitExpiryDate}>
											💾 {$t('employeeFiles.saveDate')}
										</button>
									{:else}
										<button class="update-button" on:click={() => workPermitExpiryDate = ''}>
											✏️ {$t('employeeFiles.updateDate')}
										</button>
									{/if}
								{/if}

								<!-- File Upload -->
								<div class="file-upload-group">
									<label for="id-document">{$t('employeeFiles.uploadDocument')}</label>
									{#if selectedEmployee?.id_document_url}
										<!-- Document already uploaded -->
										<button class="view-button" on:click={viewIDDocument}>
											👁️ {$t('employeeFiles.viewDocument')}
										</button>
										{#if !idDocumentFile}
											<button class="update-button" on:click={() => idDocumentFile = {} as any}>
												✏️ {$t('employeeFiles.update')}
											</button>
										{:else}
											<!-- Show upload input when updating -->
											<input 
												type="file" 
												id="id-document"
												accept=".pdf,.jpg,.jpeg,.png"
												on:change={(e) => idDocumentFile = e.target.files?.[0] || null}
											/>
											<button 
												class="upload-button" 
												on:click={uploadIDDocument}
												disabled={!idDocumentFile || isUploadingDocument}
											>
												{isUploadingDocument ? '⏳ ' + $t('employeeFiles.updating') : '📤 ' + $t('employeeFiles.upload')}
											</button>
										{/if}
									{:else}
										<!-- No document uploaded yet -->
										<input 
											type="file" 
											id="id-document"
											accept=".pdf,.jpg,.jpeg,.png"
											on:change={(e) => idDocumentFile = e.target.files?.[0] || null}
										/>
										<button 
											class="upload-button" 
											on:click={uploadIDDocument}
											disabled={!idDocumentFile || isUploadingDocument}
										>
											{isUploadingDocument ? '⏳ ' + $t('employeeFiles.updating') : '📤 ' + $t('employeeFiles.upload')}
										</button>
									{/if}
								</div>
							</div>
						</div>
					</div>

					<!-- Card 3: Health Card Management -->
					<div class="file-card health-card">
						<div class="file-card-content health-content">
							<div class="health-form">
								<h5>{$t('employeeFiles.healthCard')}</h5>
								
								<!-- Health Card Number Field -->
								{#if !savedHealthCardNumber}
									<!-- Show input when no number is saved -->
									<div class="form-group-compact">
										<label for="health-card-number">{$t('employeeFiles.healthCardNumber')}</label>
										<input 
											type="text" 
											id="health-card-number" 
											bind:value={healthCardNumber}
											placeholder={$t('employeeFiles.enterHealthCardNumber')}
										/>
									</div>
									<button class="save-button-small" on:click={saveHealthCardNumber}>
										💾 {$t('employeeFiles.saveNumber')}
									</button>
								{:else}
									<!-- Show saved number info -->
									<div class="saved-date-info">
										<div class="saved-date-display">
											<span class="date-label">{$t('employeeFiles.healthCardNumber')}:</span>
											<span class="date-value">{savedHealthCardNumber}</span>
										</div>
									</div>
									
									<!-- Edit number input (hidden by default) -->
									{#if healthCardNumber !== savedHealthCardNumber}
										<div class="form-group-compact">
											<label for="health-card-number-edit">{$t('employeeFiles.changeHealthCardNumber')}</label>
											<input 
												type="text" 
												id="health-card-number-edit" 
												bind:value={healthCardNumber}
												placeholder={$t('employeeFiles.enterHealthCardNumber')}
											/>
										</div>
										<button class="save-button-small" on:click={saveHealthCardNumber}>
											💾 {$t('employeeFiles.updateNumber')}
										</button>
									{:else}
										<button class="update-button" on:click={() => healthCardNumber = ''}>
											✏️ {$t('employeeFiles.editNumber')}
										</button>
									{/if}
								{/if}
								
								<!-- Expiry Date Field -->
								{#if !savedHealthCardExpiryDate}
									<!-- Show input when no date is saved -->
									<div class="form-group-compact">
										<label for="health-expiry">{$t('employeeFiles.expiryDate')}</label>
										<input 
											type="date" 
											id="health-expiry" 
											bind:value={healthCardExpiryDate}
											on:change={calculateHealthCardDaysUntilExpiry}
										/>
									</div>
									<button class="save-button-small" on:click={saveHealthCardExpiryDate}>
										💾 {$t('employeeFiles.saveDate')}
									</button>
								{:else}
									<!-- Show saved date info when saved -->
									<div class="saved-date-info">
										<div class="saved-date-display">
											<span class="date-label">{$t('employeeFiles.save')}:</span>
											<span class="date-value">
												{savedHealthCardExpiryDate ? new Date(savedHealthCardExpiryDate).toLocaleDateString('en-GB') : '-'}
											</span>
										</div>
										{#if healthCardDaysUntilExpiry > 0}
											<span class="expiry-valid">⏰ {healthCardDaysUntilExpiry} {$t('employeeFiles.days')} {$t('employeeFiles.remaining')}</span>
										{:else if healthCardDaysUntilExpiry === 0}
											<span class="expiry-warning">⚠️ {$t('employeeFiles.expiresToday')}</span>
										{:else}
											<span class="expiry-expired">❌ {$t('employeeFiles.expiredAgo').replace('{days}', Math.abs(healthCardDaysUntilExpiry).toString())}</span>
										{/if}
									</div>
									
									<!-- Edit date input (hidden by default) -->
									{#if healthCardExpiryDate !== savedHealthCardExpiryDate}
										<div class="form-group-compact">
											<label for="health-expiry">{$t('employeeFiles.changeExpiryDate')}</label>
											<input 
												type="date" 
												id="health-expiry" 
												bind:value={healthCardExpiryDate}
												on:change={calculateHealthCardDaysUntilExpiry}
											/>
										</div>
										<button class="save-button-small" on:click={saveHealthCardExpiryDate}>
											💾 {$t('employeeFiles.saveDate')}
										</button>
									{:else}
										<button class="update-button" on:click={() => healthCardExpiryDate = ''}>
											✏️ {$t('employeeFiles.updateDate')}
										</button>
									{/if}
								{/if}

								<!-- File Upload -->
								<div class="file-upload-group">
									<label for="health-document">{$t('employeeFiles.uploadDocument')}</label>
									{#if selectedEmployee?.health_card_document_url}
										<!-- Document already uploaded -->
										<button class="view-button" on:click={viewHealthCardDocument}>
											👁️ {$t('employeeFiles.viewDocument')}
										</button>
										{#if !healthCardFile}
											<button class="update-button" on:click={() => healthCardFile = {} as any}>
												✏️ {$t('employeeFiles.update')}
											</button>
										{:else}
											<!-- Show upload input when updating -->
											<input 
												type="file" 
												id="health-document"
												accept=".pdf,.jpg,.jpeg,.png"
												on:change={(e) => healthCardFile = e.target.files?.[0] || null}
											/>
											<button 
												class="upload-button" 
												on:click={uploadHealthCardDocument}
												disabled={!healthCardFile || isUploadingHealthCard}
											>
												{isUploadingHealthCard ? '⏳ ' + $t('employeeFiles.updating') : '📤 ' + $t('employeeFiles.upload')}
											</button>
										{/if}
									{:else}
										<!-- No document uploaded yet -->
										<input 
											type="file" 
											id="health-document"
											accept=".pdf,.jpg,.jpeg,.png"
											on:change={(e) => healthCardFile = e.target.files?.[0] || null}
										/>
										<button 
											class="upload-button" 
											on:click={uploadHealthCardDocument}
											disabled={!healthCardFile || isUploadingHealthCard}
										>
											{isUploadingHealthCard ? '⏳ ' + $t('employeeFiles.updating') : '📤 ' + $t('employeeFiles.upload')}
										</button>
									{/if}
								</div>

								<!-- Health Educational Renewal Date Field -->
								{#if !savedHealthEducationalRenewalDate}
									<!-- Show input when no date is saved -->
									<div class="form-group-compact">
										<label for="health-educational-renewal">{$t('employeeFiles.educationExpiryDate')}</label>
										<input 
											type="date" 
											id="health-educational-renewal" 
											bind:value={healthEducationalRenewalDate}
											on:change={calculateHealthEducationalRenewalDaysUntilExpiry}
										/>
									</div>
									<button class="save-button-small" on:click={saveHealthEducationalRenewalDate}>
										💾 {$t('employeeFiles.saveDate')}
									</button>
								{:else}
									<!-- Show saved date info when saved -->
									<div class="saved-date-info">
										<div class="saved-date-display">
											<span class="date-label">{$t('employeeFiles.educationExpiryDate')}:</span>
											<span class="date-value">
												{savedHealthEducationalRenewalDate ? new Date(savedHealthEducationalRenewalDate).toLocaleDateString('en-GB') : '-'}
											</span>
										</div>
										{#if healthEducationalRenewalDaysUntilExpiry > 0}
											<span class="expiry-valid">⏰ {healthEducationalRenewalDaysUntilExpiry} {$t('employeeFiles.days')} {$t('employeeFiles.remaining')}</span>
										{:else if healthEducationalRenewalDaysUntilExpiry === 0}
											<span class="expiry-warning">⚠️ {$t('employeeFiles.expiresToday')}</span>
										{:else}
											<span class="expiry-expired">❌ {$t('employeeFiles.expiredAgo').replace('{days}', Math.abs(healthEducationalRenewalDaysUntilExpiry).toString())}</span>
										{/if}
									</div>
									
									<!-- Edit date input (hidden by default) -->
									{#if healthEducationalRenewalDate !== savedHealthEducationalRenewalDate}
										<div class="form-group-compact">
											<label for="health-educational-renewal">{$t('employeeFiles.changeEducationExpiryDate')}</label>
											<input 
												type="date" 
												id="health-educational-renewal" 
												bind:value={healthEducationalRenewalDate}
												on:change={calculateHealthEducationalRenewalDaysUntilExpiry}
											/>
										</div>
										<button class="save-button-small" on:click={saveHealthEducationalRenewalDate}>
											💾 {$t('employeeFiles.saveDate')}
										</button>
									{:else}
										<button class="update-button" on:click={() => healthEducationalRenewalDate = ''}>
											✏️ {$t('employeeFiles.updateDate')}
										</button>
									{/if}
								{/if}
							</div>
						</div>
					</div>

					<!-- Card 4: Driving Licence Management -->
					<div class="file-card driving-licence-card">
						<div class="file-card-content driving-licence-content">
							<div class="driving-licence-form">
								<h5>{$t('employeeFiles.drivingLicence')}</h5>
								
								<!-- Driving Licence Number Field -->
								{#if !savedDrivingLicenceNumber}
									<!-- Show input when no number is saved -->
									<div class="form-group-compact">
										<label for="driving-licence-number">{$t('employeeFiles.licenceNumber')}</label>
										<input 
											type="text" 
											id="driving-licence-number" 
											bind:value={drivingLicenceNumber}
											placeholder={$t('employeeFiles.enterLicenceNumber')}
										/>
									</div>
									<button class="save-button-small" on:click={saveDrivingLicenceNumber}>
										💾 {$t('employeeFiles.saveNumber')}
									</button>
								{:else}
									<!-- Show saved number info -->
									<div class="saved-date-info">
										<div class="saved-date-display">
											<span class="date-label">{$t('employeeFiles.licenceNumber')}:</span>
											<span class="date-value">{savedDrivingLicenceNumber}</span>
										</div>
									</div>
									
									<!-- Edit number input (hidden by default) -->
									{#if drivingLicenceNumber !== savedDrivingLicenceNumber}
										<div class="form-group-compact">
											<label for="driving-licence-number-edit">{$t('employeeFiles.changeLicenceNumber')}</label>
											<input 
												type="text" 
												id="driving-licence-number-edit" 
												bind:value={drivingLicenceNumber}
												placeholder={$t('employeeFiles.enterLicenceNumber')}
											/>
										</div>
										<button class="save-button-small" on:click={saveDrivingLicenceNumber}>
											💾 {$t('employeeFiles.updateNumber')}
										</button>
									{:else}
										<button class="update-button" on:click={() => drivingLicenceNumber = ''}>
											✏️ {$t('employeeFiles.editNumber')}
										</button>
									{/if}
								{/if}
								
								<!-- Expiry Date Field -->
								{#if !savedDrivingLicenceExpiryDate}
									<!-- Show input when no date is saved -->
									<div class="form-group-compact">
										<label for="driving-expiry">{$t('employeeFiles.expiryDate')}</label>
										<input 
											type="date" 
											id="driving-expiry" 
											bind:value={drivingLicenceExpiryDate}
											on:change={calculateDrivingLicenceDaysUntilExpiry}
										/>
									</div>
									<button class="save-button-small" on:click={saveDrivingLicenceExpiryDate}>
										💾 {$t('employeeFiles.saveDate')}
									</button>
								{:else}
									<!-- Show saved date info when saved -->
									<div class="saved-date-info">
										<div class="saved-date-display">
											<span class="date-label">{$t('employeeFiles.save')}:</span>
											<span class="date-value">
												{savedDrivingLicenceExpiryDate ? new Date(savedDrivingLicenceExpiryDate).toLocaleDateString('en-GB') : '-'}
											</span>
										</div>
										{#if drivingLicenceDaysUntilExpiry > 0}
											<span class="expiry-valid">⏰ {drivingLicenceDaysUntilExpiry} {$t('employeeFiles.days')} {$t('employeeFiles.remaining')}</span>
										{:else if drivingLicenceDaysUntilExpiry === 0}
											<span class="expiry-warning">⚠️ {$t('employeeFiles.expiresToday')}</span>
										{:else}
											<span class="expiry-expired">❌ {$t('employeeFiles.expiredAgo').replace('{days}', Math.abs(drivingLicenceDaysUntilExpiry).toString())}</span>
										{/if}
									</div>
									
									<!-- Edit date input (hidden by default) -->
									{#if drivingLicenceExpiryDate !== savedDrivingLicenceExpiryDate}
										<div class="form-group-compact">
											<label for="driving-expiry">{$t('employeeFiles.changeExpiryDate')}</label>
											<input 
												type="date" 
												id="driving-expiry" 
												bind:value={drivingLicenceExpiryDate}
												on:change={calculateDrivingLicenceDaysUntilExpiry}
											/>
										</div>
										<button class="save-button-small" on:click={saveDrivingLicenceExpiryDate}>
											💾 {$t('employeeFiles.saveDate')}
										</button>
									{:else}
										<button class="update-button" on:click={() => drivingLicenceExpiryDate = ''}>
											✏️ {$t('employeeFiles.updateDate')}
										</button>
									{/if}
								{/if}

								<!-- File Upload -->
								<div class="file-upload-group">
									<label for="driving-document">{$t('employeeFiles.uploadDocument')}</label>
									{#if selectedEmployee?.driving_licence_document_url}
										<!-- Document already uploaded -->
										<button class="view-button" on:click={viewDrivingLicenceDocument}>
											👁️ {$t('employeeFiles.viewDocument')}
										</button>
										{#if !drivingLicenceFile}
											<button class="update-button" on:click={() => drivingLicenceFile = {} as any}>
												✏️ {$t('employeeFiles.update')}
											</button>
										{:else}
											<!-- Show upload input when updating -->
											<input 
												type="file" 
												id="driving-document"
												accept=".pdf,.jpg,.jpeg,.png"
												on:change={(e) => drivingLicenceFile = e.target.files?.[0] || null}
											/>
											<button 
												class="upload-button" 
												on:click={uploadDrivingLicenceDocument}
												disabled={!drivingLicenceFile || isUploadingDrivingLicence}
											>
												{isUploadingDrivingLicence ? '⏳ ' + $t('employeeFiles.updating') : '📤 ' + $t('employeeFiles.upload')}
											</button>
										{/if}
									{:else}
										<!-- No document uploaded yet -->
										<input 
											type="file" 
											id="driving-document"
											accept=".pdf,.jpg,.jpeg,.png"
											on:change={(e) => drivingLicenceFile = e.target.files?.[0] || null}
										/>
										<button 
											class="upload-button" 
											on:click={uploadDrivingLicenceDocument}
											disabled={!drivingLicenceFile || isUploadingDrivingLicence}
										>
											{isUploadingDrivingLicence ? '⏳ ' + $t('employeeFiles.updating') : '📤 ' + $t('employeeFiles.upload')}
										</button>
									{/if}
								</div>
							</div>
						</div>
					</div>

					<!-- Card 5: Contract Management -->
					<div class="file-card contract-card">
						<div class="file-card-content contract-content">
							<div class="contract-form">
								<h5>{$t('employeeFiles.contract')}</h5>
								
								<!-- Expiry Date Field -->
								{#if !savedContractExpiryDate}
									<!-- Show input when no date is saved -->
									<div class="form-group-compact">
										<label for="contract-expiry">{$t('employeeFiles.expiryDate')}</label>
										<input 
											type="date" 
											id="contract-expiry" 
											bind:value={contractExpiryDate}
											on:change={calculateContractDaysUntilExpiry}
										/>
									</div>
									<button class="save-button-small" on:click={saveContractExpiryDate}>
										💾 {$t('employeeFiles.saveDate')}
									</button>
								{:else}
									<!-- Show saved date info when saved -->
									<div class="saved-date-info">
										<div class="saved-date-display">
											<span class="date-label">{$t('employeeFiles.expiryDate')}:</span>
											<span class="date-value">
												{savedContractExpiryDate ? new Date(savedContractExpiryDate).toLocaleDateString('en-GB') : '-'}
											</span>
										</div>
										{#if contractDaysUntilExpiry > 0}
											<span class="expiry-valid">⏰ {contractDaysUntilExpiry} {$t('employeeFiles.days')} {$t('employeeFiles.remaining')}</span>
										{:else if contractDaysUntilExpiry === 0}
											<span class="expiry-warning">⚠️ {$t('employeeFiles.expiresToday')}</span>
										{:else}
											<span class="expiry-expired">❌ {$t('employeeFiles.expiredAgo').replace('{days}', Math.abs(contractDaysUntilExpiry).toString())}</span>
										{/if}
									</div>
									
									<!-- Edit date input (hidden by default) -->
									{#if contractExpiryDate !== savedContractExpiryDate}
										<div class="form-group-compact">
											<label for="contract-expiry">{$t('employeeFiles.changeExpiryDate')}</label>
											<input 
												type="date" 
												id="contract-expiry" 
												bind:value={contractExpiryDate}
												on:change={calculateContractDaysUntilExpiry}
											/>
										</div>
										<button class="save-button-small" on:click={saveContractExpiryDate}>
											💾 {$t('employeeFiles.saveDate')}
										</button>
									{:else}
										<button class="update-button" on:click={() => contractExpiryDate = ''}>
											✏️ {$t('employeeFiles.updateDate')}
										</button>
									{/if}
								{/if}

								<!-- File Upload -->
								<div class="file-upload-group">
									<label for="contract-document">{$t('employeeFiles.uploadDocument')}</label>
									{#if selectedEmployee?.contract_document_url}
										<!-- Document already uploaded -->
										<button class="view-button" on:click={viewContractDocument}>
											👁️ {$t('employeeFiles.viewDocument')}
										</button>
										{#if !contractFile}
											<button class="update-button" on:click={() => contractFile = {} as any}>
												✏️ {$t('employeeFiles.update')}
											</button>
										{:else}
											<!-- Show upload input when updating -->
											<input 
												type="file" 
												id="contract-document"
												accept=".pdf,.jpg,.jpeg,.png"
												on:change={(e) => contractFile = e.target.files?.[0] || null}
											/>
											<button 
												class="upload-button" 
												on:click={uploadContractDocument}
												disabled={!contractFile || isUploadingContract}
											>
												{isUploadingContract ? '⏳ ' + $t('employeeFiles.updating') : '📤 ' + $t('employeeFiles.upload')}
											</button>
										{/if}
									{:else}
										<!-- No document uploaded yet -->
										<input 
											type="file" 
											id="contract-document"
											accept=".pdf,.jpg,.jpeg,.png"
											on:change={(e) => contractFile = e.target.files?.[0] || null}
										/>
										<button 
											class="upload-button" 
											on:click={uploadContractDocument}
											disabled={!contractFile || isUploadingContract}
										>
											{isUploadingContract ? '⏳ ' + $t('employeeFiles.updating') : '📤 ' + $t('employeeFiles.upload')}
										</button>
									{/if}
								</div>
							</div>
						</div>
					</div>

					<!-- Card 6: Bank Information -->
					<div class="file-card bank-card">
						<div class="file-card-content bank-content">
							<div class="bank-form">
								<h5>{$t('employeeFiles.bankSalaryDetails')}</h5>
								
								<!-- Bank Name Field -->
								{#if !savedBankName}
									<!-- Show dropdown when no bank name is saved -->
									<div class="form-group-compact">
										<label for="bank-name">{$t('employeeFiles.bankName')}</label>
										<select 
											id="bank-name" 
											bind:value={bankName}
										>
											<option value="">{$t('employeeFiles.bankName')}</option>
											{#each banks as bank}
												<option value="{bank.name_en}">
													{bank.name_ar} / {bank.name_en}
												</option>
											{/each}
										</select>
									</div>
									<button class="save-button-small" on:click={saveBankName}>
										💾 {$t('employeeFiles.saveNumber')}
									</button>
								{:else}
									<!-- Show saved bank name info -->
									<div class="saved-date-info">
										<div class="saved-date-display">
											<span class="date-label">{$t('employeeFiles.bankName')}:</span>
											<span class="date-value">{savedBankName}</span>
										</div>
									</div>
									
									<!-- Edit bank name dropdown (hidden by default) -->
									{#if bankName !== savedBankName}
										<div class="form-group-compact">
											<label for="bank-name-edit">{$t('employeeFiles.changeBankName')}</label>
											<select 
												id="bank-name-edit" 
												bind:value={bankName}
											>
												<option value="">{$t('employeeFiles.bankName')}</option>
												{#each banks as bank}
													<option value="{bank.name_en}">
														{bank.name_ar} / {bank.name_en}
													</option>
												{/each}
											</select>
										</div>
										<button class="save-button-small" on:click={saveBankName}>
											💾 {$t('employeeFiles.updateNumber')}
										</button>
									{:else}
										<button class="update-button" on:click={() => bankName = ''}>
											✏️ {$t('employeeFiles.editNumber')}
										</button>
									{/if}
								{/if}
								
								<!-- IBAN Field -->
								{#if !savedIban}
									<!-- Show input when no IBAN is saved -->
									<div class="form-group-compact">
										<label for="iban">{$t('employeeFiles.iban')}</label>
										<input 
											type="text" 
											id="iban" 
											bind:value={iban}
											placeholder={$t('employeeFiles.enterIban')}
										/>
									</div>
									<button class="save-button-small" on:click={saveIban}>
										💾 {$t('employeeFiles.saveNumber')}
									</button>
								{:else}
									<!-- Show saved IBAN info -->
									<div class="saved-date-info">
										<div class="saved-date-display">
											<span class="date-label">{$t('employeeFiles.iban')}:</span>
											<span class="date-value">{savedIban}</span>
										</div>
									</div>
									
									<!-- Edit IBAN input (hidden by default) -->
									{#if iban !== savedIban}
										<div class="form-group-compact">
											<label for="iban-edit">{$t('employeeFiles.changeIban')}</label>
											<input 
												type="text" 
												id="iban-edit" 
												bind:value={iban}
												placeholder={$t('employeeFiles.enterIban')}
											/>
										</div>
										<button class="save-button-small" on:click={saveIban}>
											💾 {$t('employeeFiles.updateNumber')}
										</button>
									{:else}
										<button class="update-button" on:click={() => iban = ''}>
											✏️ {$t('employeeFiles.editNumber')}
										</button>
									{/if}
								{/if}
							</div>
						</div>
					</div>

					<!-- Card 6: Health Insurance Management -->
					<div class="file-card insurance-card">
						<div class="file-card-content insurance-content">
							<div class="insurance-form">
								<h5>{$t('employeeFiles.healthInsurance')}</h5>
								
								<!-- Insurance Company Field -->
								{#if !savedInsuranceCompanyId}
									<!-- Show input when no company is saved -->
									<div class="form-group-compact">
										<label for="insurance-company">{$t('employeeFiles.insuranceCompany')}</label>
										<select 
											id="insurance-company"
											bind:value={selectedInsuranceCompanyId}
										>
											<option value="">{$t('employeeFiles.selectCompany')}</option>
											{#each insuranceCompanies as company}
												<option value={company.id}>
													{company.name_ar} / {company.name_en}
												</option>
											{/each}
										</select>
										<button class="secondary-button" on:click={() => showCreateInsuranceModal = true}>
											➕ {$t('employeeFiles.createCompany')}
										</button>
									</div>
									<button class="save-button-small" on:click={saveInsuranceCompanyId}>
										💾 {$t('employeeFiles.saveCompany')}
									</button>
								{:else}
									<!-- Show saved company info -->
									<div class="saved-date-info">
										<div class="saved-date-display">
											<span class="date-label">{$t('employeeFiles.insuranceCompany')}:</span>
											<span class="date-value">
												{insuranceCompanies.find(c => c.id === savedInsuranceCompanyId)?.name_ar || savedInsuranceCompanyId}
											</span>
										</div>
									</div>
									
									<!-- Edit company input (hidden by default) -->
									{#if selectedInsuranceCompanyId !== savedInsuranceCompanyId}
										<div class="form-group-compact">
											<label for="insurance-company-edit">{$t('employeeFiles.changeInsuranceCompany')}</label>
											<select 
												id="insurance-company-edit"
												bind:value={selectedInsuranceCompanyId}
											>
												<option value="">{$t('employeeFiles.selectCompany')}</option>
												{#each insuranceCompanies as company}
													<option value={company.id}>
														{company.name_ar} / {company.name_en}
													</option>
												{/each}
											</select>
											<button class="secondary-button" on:click={() => showCreateInsuranceModal = true}>
												➕ {$t('employeeFiles.createCompany')}
											</button>
										</div>
										<button class="save-button-small" on:click={saveInsuranceCompanyId}>
											💾 {$t('employeeFiles.saveCompany')}
										</button>
									{:else}
										<button class="update-button" on:click={() => selectedInsuranceCompanyId = ''}>
											✏️ {$t('employeeFiles.editCompany')}
										</button>
									{/if}
								{/if}
								
								<!-- Expiry Date Field -->
								{#if !savedInsuranceExpiryDate}
									<!-- Show input when no date is saved -->
									<div class="form-group-compact">
										<label for="insurance-expiry">{$t('employeeFiles.expiryDate')}</label>
										<input 
											type="date" 
											id="insurance-expiry" 
											bind:value={insuranceExpiryDate}
											on:change={calculateInsuranceDaysUntilExpiry}
										/>
									</div>
									<button class="save-button-small" on:click={saveInsuranceExpiryDate}>
										💾 {$t('employeeFiles.saveDate')}
									</button>
								{:else}
									<!-- Show saved date info when saved -->
									<div class="saved-date-info">
										<div class="saved-date-display">
											<span class="date-label">{$t('employeeFiles.saved')}:</span>
											<span class="date-value">
												{savedInsuranceExpiryDate ? new Date(savedInsuranceExpiryDate).toLocaleDateString('en-GB') : '-'}
											</span>
										</div>
										{#if insuranceDaysUntilExpiry > 0}
											<span class="expiry-valid">⏰ {insuranceDaysUntilExpiry} {$t('employeeFiles.days')} {$t('employeeFiles.remaining')}</span>
										{:else if insuranceDaysUntilExpiry === 0}
											<span class="expiry-warning">⚠️ {$t('employeeFiles.expiresToday')}</span>
										{:else}
											<span class="expiry-expired">❌ {$t('employeeFiles.expiredAgo').replace('{days}', Math.abs(insuranceDaysUntilExpiry).toString())}</span>
										{/if}
									</div>
									
									<!-- Edit date input (hidden by default) -->
									{#if insuranceExpiryDate !== savedInsuranceExpiryDate}
										<div class="form-group-compact">
											<label for="insurance-expiry">{$t('employeeFiles.changeExpiryDate')}</label>
											<input 
												type="date" 
												id="insurance-expiry" 
												bind:value={insuranceExpiryDate}
												on:change={calculateInsuranceDaysUntilExpiry}
											/>
										</div>
										<button class="save-button-small" on:click={saveInsuranceExpiryDate}>
											💾 {$t('employeeFiles.saveDate')}
										</button>
									{:else}
										<button class="update-button" on:click={() => insuranceExpiryDate = ''}>
											✏️ {$t('employeeFiles.updateDate')}
										</button>
									{/if}
								{/if}
							</div>
						</div>
					</div>

					<!-- Card 7: Personal Information (Birth Date & Join Date) -->
					<div class="file-card personal-info-card">
						<div class="file-card-content personal-info-content">
							<div class="personal-info-form">
								<h5>{$t('employeeFiles.personalInformation')}</h5>
								
								<!-- Date of Birth Field -->
								{#if !savedDateOfBirth}
									<!-- Show input when no date is saved -->
									<div class="form-group-compact">
										<label for="date-of-birth">{$t('employeeFiles.dateOfBirth')}</label>
										<input 
											type="date" 
											id="date-of-birth" 
											bind:value={dateOfBirth}
											on:change={calculateAge}
										/>
									</div>
									<button class="save-button-small" on:click={saveDateOfBirth}>
										💾 {$t('employeeFiles.saveDob')}
									</button>
								{:else}
									<!-- Show saved date info when saved -->
									<div class="saved-date-info">
										<div class="saved-date-display">
											<span class="date-label">{$t('employeeFiles.dateOfBirth')}:</span>
											<span class="date-value">
												{savedDateOfBirth ? new Date(savedDateOfBirth).toLocaleDateString('en-GB') : '-'}
											</span>
										</div>
										<span class="age-display">{$t('employeeFiles.age')}: {age} {$t('employeeFiles.years')}</span>
									</div>
									
									<!-- Edit date input (hidden by default) -->
									{#if dateOfBirth !== savedDateOfBirth}
										<div class="form-group-compact">
											<label for="date-of-birth">{$t('employeeFiles.changeDateOfBirth')}</label>
											<input 
												type="date" 
												id="date-of-birth" 
												bind:value={dateOfBirth}
												on:change={calculateAge}
											/>
										</div>
										<button class="save-button-small" on:click={saveDateOfBirth}>
											💾 {$t('employeeFiles.saveDob')}
										</button>
									{:else}
										<button class="update-button" on:click={() => dateOfBirth = ''}>
											✏️ {$t('employeeFiles.updateDob')}
										</button>
									{/if}
								{/if}

								<!-- Join Date Field -->
								{#if !savedJoinDate}
									<!-- Show input when no date is saved -->
									<div class="form-group-compact">
										<label for="join-date">{$t('employeeFiles.joinDate')}</label>
										<input 
											type="date" 
											id="join-date" 
											bind:value={joinDate}
										/>
									</div>
									<button class="save-button-small" on:click={saveJoinDate}>
										💾 {$t('employeeFiles.saveJoinDate')}
									</button>
								{:else}
									<!-- Show saved date info when saved -->
									<div class="saved-date-info">
										<div class="saved-date-display">
											<span class="date-label">{$t('employeeFiles.joinDate')}:</span>
											<span class="date-value">
												{savedJoinDate ? new Date(savedJoinDate).toLocaleDateString('en-GB') : '-'}
											</span>
										</div>
									</div>
									
									<!-- Edit date input (hidden by default) -->
									{#if joinDate !== savedJoinDate}
										<div class="form-group-compact">
											<label for="join-date">{$t('employeeFiles.changeJoinDate')}</label>
											<input 
												type="date" 
												id="join-date" 
												bind:value={joinDate}
											/>
										</div>
										<button class="save-button-small" on:click={saveJoinDate}>
											💾 {$t('employeeFiles.saveJoinDate')}
										</button>
									{:else}
										<button class="update-button" on:click={() => joinDate = ''}>
											✏️ {$t('employeeFiles.updateJoinDate')}
										</button>
									{/if}
								{/if}

								<!-- Worked Duration Display -->
								{#if savedJoinDate}
									<div class="worked-duration-info">
										<div class="duration-label">{$t('employeeFiles.workedDuration') || 'Worked Duration'}:</div>
										<div class="duration-display">
											{#if workedYears > 0}
												<span class="duration-item">{workedYears} {workedYears === 1 ? $t('employeeFiles.year') || 'year' : $t('employeeFiles.years') || 'years'}</span>
											{/if}
											{#if workedMonths > 0}
												<span class="duration-item">{workedMonths} {workedMonths === 1 ? $t('employeeFiles.month') || 'month' : $t('employeeFiles.months') || 'months'}</span>
											{/if}
											{#if workedDays > 0 || (workedYears === 0 && workedMonths === 0)}
												<span class="duration-item">{workedDays} {workedDays === 1 ? $t('employeeFiles.day') || 'day' : $t('employeeFiles.days') || 'days'}</span>
											{/if}
										</div>
									</div>
								{/if}

							<!-- Probation Period Expiry Date Field -->
							{#if !savedProbationPeriodExpiryDate}
								<!-- Show input when no date is saved -->
								<div class="form-group-compact">
									<label for="probation-period-expiry">{$t('employeeFiles.probationPeriodExpiryDate')}</label>
									<input 
										type="date" 
										id="probation-period-expiry" 
										bind:value={probationPeriodExpiryDate}
										on:change={calculateProbationPeriodDaysUntilExpiry}
									/>
								</div>
								<button class="save-button-small" on:click={saveProbationPeriodExpiryDate}>
									💾 {$t('employeeFiles.saveProbationDate')}
								</button>
							{:else}
								<!-- Show saved date info when saved -->
								<div class="saved-date-info">
									{#if probationPeriodDaysUntilExpiry < 0}
										<div class="probation-finished">
											<span class="finish-badge">✓ {$t('employeeFiles.probationPeriodFinished')}</span>
										</div>
									{/if}
									<div class="saved-date-display">
										<span class="date-label">{$t('employeeFiles.probationPeriod')}:</span>
										<span class="date-value">
											{savedProbationPeriodExpiryDate ? new Date(savedProbationPeriodExpiryDate).toLocaleDateString('en-GB') : '-'}
										</span>
									</div>
									{#if probationPeriodDaysUntilExpiry > 0}
										<span class="expiry-valid">⏰ {probationPeriodDaysUntilExpiry} {$t('employeeFiles.days')} {$t('employeeFiles.remaining')}</span>
									{:else if probationPeriodDaysUntilExpiry === 0}
										<span class="expiry-warning">⚠️ {$t('employeeFiles.expiresToday')}</span>
									{:else}
										<span class="expiry-expired">❌ {$t('employeeFiles.probationPeriodFinished')}</span>
									{/if}
								</div>
								
								<!-- Edit date input (hidden by default) -->
								{#if probationPeriodExpiryDate !== savedProbationPeriodExpiryDate}
									<div class="form-group-compact">
										<label for="probation-period-expiry">{$t('employeeFiles.changeProbationExpiry')}</label>
										<input 
											type="date" 
											id="probation-period-expiry" 
											bind:value={probationPeriodExpiryDate}
											on:change={calculateProbationPeriodDaysUntilExpiry}
										/>
									</div>
									<button class="save-button-small" on:click={saveProbationPeriodExpiryDate}>
										💾 {$t('employeeFiles.saveProbationDate')}
									</button>
								{:else}
									<button class="update-button" on:click={() => probationPeriodExpiryDate = ''}>
										✏️ {$t('employeeFiles.updateProbationDate')}
									</button>
								{/if}
							{/if}
						</div>
					</div>
				</div>

				<!-- Card 8: POS Shortages -->
				<div class="file-card pos-shortages-card">
					<div class="file-card-content pos-shortages-content">
						<div class="pos-shortages-form">
							<h5>💰 {$t('employeeFiles.posShortages')}</h5>
							
							<div class="shortage-total-compact">
								<span class="label-text">{$t('employeeFiles.totalShortages')}:</span>
								<span class="value-text total-value">{posShortages.total.toFixed(2)} {$t('common.sar')}</span>
							</div>
							
							<div class="shortage-items-compact">
								<div class="shortage-row proposed">
									<span class="status-text">🟢 {$t('employeeFiles.proposed')}</span>
									<span class="amount-text">{posShortages.proposed.toFixed(2)} {$t('common.sar')}</span>
								</div>
								
								<div class="shortage-row forgiven">
									<span class="status-text">🟠 {$t('employeeFiles.forgiven')}</span>
									<span class="amount-text">{posShortages.forgiven.toFixed(2)} {$t('common.sar')}</span>
								</div>
								
								<div class="shortage-row deducted">
									<span class="status-text">🔴 {$t('employeeFiles.deducted')}</span>
									<span class="amount-text">{posShortages.deducted.toFixed(2)} {$t('common.sar')}</span>
								</div>
								
								<div class="shortage-row cancelled">
									<span class="status-text">⚫ {$t('employeeFiles.cancelled')}</span>
									<span class="amount-text">{posShortages.cancelled.toFixed(2)} {$t('common.sar')}</span>
								</div>
							</div>
						</div>
					</div>
				</div>

				<!-- End of file cards grid -->
				</div>
			{:else}
				<div class="placeholder">
					<p>{$t('employeeFiles.placeholderEmployeeSelect')}</p>
				</div>
			{/if}
		</div>
	</div>
</div>
</div>

<!-- Create Insurance Company Modal -->
{#if showCreateInsuranceModal}
	<div class="modal-overlay" on:click={() => showCreateInsuranceModal = false}>
		<div class="modal-content" on:click={(e) => e.stopPropagation()}>
			<div class="modal-header">
				<h3>{$t('employeeFiles.createInsuranceCompany')}</h3>
				<button class="close-button" on:click={() => showCreateInsuranceModal = false}>✕</button>
			</div>
			<div class="modal-body">
				<div class="form-group-compact">
					<label for="company-name-en">{$t('employeeFiles.companyNameEn')}</label>
					<input 
						type="text" 
						id="company-name-en" 
						bind:value={newInsuranceCompanyNameEn}
						placeholder={$t('employeeFiles.enterNameEn')}
					/>
				</div>
				<div class="form-group-compact">
					<label for="company-name-ar">{$t('employeeFiles.companyNameAr')}</label>
					<input 
						type="text" 
						id="company-name-ar" 
						bind:value={newInsuranceCompanyNameAr}
						placeholder={$t('employeeFiles.enterNameAr')}
					/>
				</div>
			</div>
			<div class="modal-footer">
				<button class="cancel-button" on:click={() => showCreateInsuranceModal = false}>
					{$t('employeeFiles.cancel')}
				</button>
				<button class="save-button" on:click={createInsuranceCompany} disabled={isCreatingInsuranceCompany}>
					{isCreatingInsuranceCompany ? `⏳ ${$t('employeeFiles.creating')}` : `✅ ${$t('employeeFiles.create')}`}
				</button>
			</div>
		</div>
	</div>
{/if}

<!-- Employment Status Effective Date Modal -->
{#if showEffectiveDateModal}
	<div class="modal-overlay" on:click={() => showEffectiveDateModal = false}>
		<div class="modal-content" on:click={(e) => e.stopPropagation()}>
			<div class="modal-header">
				<h3>{$t('employeeFiles.effectiveDate') || 'Effective Date'}</h3>
				<button class="close-button" on:click={() => showEffectiveDateModal = false}>✕</button>
			</div>
			<div class="modal-body">
				<div class="form-group-compact">
					<label for="effective-date">{$t('employeeFiles.effectiveDate') || 'Effective Date'} *</label>
					<input 
						type="date" 
						id="effective-date" 
						bind:value={effectiveDate}
					/>
				</div>
				<div class="form-group-compact">
					<label for="effective-reason">{$t('employeeFiles.reason') || 'Reason'}</label>
					<textarea 
						id="effective-reason" 
						bind:value={effectiveDateReason}
						placeholder="Enter reason (optional)"
						rows="3"
					></textarea>
				</div>
			</div>
			<div class="modal-footer">
				<button class="cancel-button" on:click={() => showEffectiveDateModal = false}>
					{$t('employeeFiles.cancel')}
				</button>
				<button 
					class="save-button" 
					on:click={() => {
						if (!effectiveDate) {
							alert('Effective date is required');
							return;
						}
						showEffectiveDateModal = false;
						saveEmploymentStatus();
					}}
					disabled={!effectiveDate}
				>
					✅ {$t('employeeFiles.saveStatus')}
				</button>
			</div>
		</div>
	</div>
{/if}

<!-- Create Nationality Modal -->
{#if showCreateNationalityModal}
	<div class="modal-overlay" on:click={() => showCreateNationalityModal = false}>
		<div class="modal-content" on:click={(e) => e.stopPropagation()}>
			<div class="modal-header">
				<h3>{$t('employeeFiles.createNationality') || 'Create New Nationality'}</h3>
				<button class="close-button" on:click={() => showCreateNationalityModal = false}>✕</button>
			</div>
			<div class="modal-body">
				<div class="form-group-compact">
					<label for="nationality-id">{$t('employeeFiles.nationalityId') || 'Nationality ID (e.g., SA, UK)'}</label>
					<input 
						type="text" 
						id="nationality-id" 
						bind:value={newNationalityId}
						maxlength="10"
						placeholder={$t('employeeFiles.enterNationalityId') || 'Enter ID'}
					/>
				</div>
				<div class="form-group-compact">
					<label for="nationality-name-en">{$t('employeeFiles.nationalityNameEn') || 'Name (English)'}</label>
					<input 
						type="text" 
						id="nationality-name-en" 
						bind:value={newNationalityNameEn}
						placeholder={$t('employeeFiles.enterNationalityNameEn') || 'Enter name in English'}
					/>
				</div>
				<div class="form-group-compact">
					<label for="nationality-name-ar">{$t('employeeFiles.nationalityNameAr') || 'Name (Arabic)'}</label>
					<input 
						type="text" 
						id="nationality-name-ar" 
						bind:value={newNationalityNameAr}
						placeholder={$t('employeeFiles.enterNationalityNameAr') || 'Enter name in Arabic'}
					/>
				</div>
			</div>
			<div class="modal-footer">
				<button class="cancel-button" on:click={() => showCreateNationalityModal = false}>
					{$t('employeeFiles.cancel')}
				</button>
				<button class="save-button" on:click={createNationality} disabled={isCreatingNationality}>
					{isCreatingNationality ? `⏳ ${$t('employeeFiles.creating')}` : `✅ ${$t('employeeFiles.create')}`}
				</button>
			</div>
		</div>
	</div>
{/if}

<style>
	.employee-files-container {
		display: flex;
		flex-direction: column;
		height: 100%;
		overflow: auto;
	}

	.cards-wrapper {
		display: grid;
		grid-template-columns: 3fr 5fr;
		gap: 1.5rem;
		height: 100%;
	}

	.card {
		background: white;
		border-radius: 8px;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
		display: flex;
		flex-direction: column;
		overflow: hidden;
	}

	.card-header {
		background: linear-gradient(135deg, #ff9500 0%, #ff8000 100%);
		padding: 1rem 1.5rem;
		color: white;
	}

	.card-header h3 {
		margin: 0;
		font-size: 1.25rem;
		font-weight: 600;
	}

	.card-content {
		padding: 0;
		flex: 1;
		overflow: hidden;
		display: flex;
		flex-direction: column;
	}

	.filters-section {
		padding: 1.5rem;
		background: white;
		border-bottom: 2px solid #e0e0e0;
		position: sticky;
		top: 3.5rem;
		z-index: 10;
	}

	.filters-section-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 1rem 1.5rem;
		background: white;
		border-bottom: 1px solid #f0f0f0;
		position: sticky;
		top: 0;
		z-index: 11;
	}

	.filters-section-header h4 {
		margin: 0;
		font-size: 0.95rem;
		font-weight: 600;
		color: #333;
	}

	.seal-button {
		padding: 0.5rem 1rem;
		background: #ff9500;
		color: white;
		border: none;
		border-radius: 4px;
		cursor: pointer;
		font-size: 0.85rem;
		font-weight: 500;
		transition: background-color 0.2s;
	}

	.seal-button:hover {
		background: #ff8000;
	}

	.seal-button:active {
		transform: scale(0.98);
	}

	.nationality-section {
		padding: 1.5rem;
		background: #f0f8f5;
		border-radius: 6px;
		border-left: 3px solid #10b981;
		margin-bottom: 1.5rem;
	}

	.nationality-section h4 {
		margin: 0 0 1rem 0;
		font-size: 0.95rem;
		color: #333;
	}

	.save-button {
		padding: 0.75rem 1.5rem;
		background: #ff9500;
		color: white;
		border: none;
		border-radius: 4px;
		cursor: pointer;
		font-size: 0.9rem;
		font-weight: 500;
		transition: background-color 0.2s;
		margin-top: 1rem;
	}

	.save-button:hover {
		background: #ff8000;
	}

	.save-button:active {
		transform: scale(0.98);
	}

	.form-group {
		margin-bottom: 1.25rem;
	}

	.form-group:last-child {
		margin-bottom: 0;
	}

	.form-group label {
		display: block;
		margin-bottom: 0.5rem;
		font-weight: 500;
		color: #333;
		font-size: 0.9rem;
	}

	.form-group select,
	.form-group input {
		width: 100%;
		padding: 0.75rem;
		border: 1px solid #ddd;
		border-radius: 6px;
		font-size: 0.95rem;
		transition: border-color 0.2s;
		color: #000000 !important;
		background-color: #ffffff !important;
	}

	.form-group select option {
		color: #000000 !important;
		background-color: #ffffff !important;
	}

	:global([dir="rtl"]) .form-group select {
		background-position: left 0.75rem center;
		padding-left: 2.5rem;
		padding-right: 0.75rem;
	}

	.form-group select:focus,
	.form-group input:focus {
		outline: none;
		border-color: #ff9500;
		box-shadow: 0 0 0 3px rgba(255, 149, 0, 0.1);
	}

	.employee-list {
		flex: 1;
		display: flex;
		flex-direction: column;
		overflow: hidden;
	}

	.list-header-wrapper {
		position: sticky;
		top: 0;
		z-index: 5;
		background: white;
	}

	.list-header {
		display: grid;
		grid-template-columns: 100px 1fr 1fr;
		gap: 0.75rem;
		padding: 0.75rem 1rem;
		background: #f8f9fa;
		font-weight: 600;
		font-size: 0.85rem;
		color: #666;
		border-bottom: 1px solid #e0e0e0;
	}

	.list-body {
		flex: 1;
		overflow-y: auto;
	}

	.employee-item {
		display: grid;
		grid-template-columns: 100px 1fr 1fr;
		gap: 0.75rem;
		padding: 0.875rem 1rem;
		cursor: pointer;
		transition: background-color 0.2s;
		border-bottom: 1px solid #f0f0f0;
		align-items: center;
	}

	.employee-item:hover {
		background-color: #f0f8f5;
	}

	.employee-item.selected {
		background-color: #fff7ed;
		border-left: 4px solid #f97316;
		font-weight: 500;
	}

	.employee-item:last-child {
		border-bottom: none;
	}

	.emp-id {
		font-weight: 500;
		color: #10b981;
	}

	.emp-name-stack,
	.emp-position-stack {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}

	.emp-name-ar,
	.emp-position-ar {
		color: #333;
		font-weight: 500;
		font-size: 0.95rem;
	}

	.emp-name-en,
	.emp-position-en {
		color: #333;
		font-weight: 500;
		font-size: 0.95rem;
	}

	.placeholder {
		display: flex;
		align-items: center;
		justify-content: center;
		height: 100%;
		color: #999;
		font-style: italic;
	}

	.selected-info {
		background: #f0f8f5;
		padding: 1rem;
		border-radius: 6px;
		border-left: 3px solid #10b981;
	}

	.info-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
		gap: 1rem;
	}

	.info-item {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}

	.info-label {
		font-size: 0.7rem;
		font-weight: 600;
		color: #ff9500;
		text-transform: uppercase;
		letter-spacing: 0.3px;
	}

	.info-value {
		font-size: 0.95rem;
		color: #333;
		font-weight: 500;
	}

	.info-select {
		padding: 0.5rem 0.75rem;
		border: 1px solid #ddd;
		border-radius: 4px;
		font-size: 0.9rem;
		background-color: white;
		cursor: pointer;
		transition: border-color 0.2s;
	}

	.info-select:focus {
		outline: none;
		border-color: #ff9500;
		box-shadow: 0 0 0 3px rgba(255, 149, 0, 0.1);
	}

	.info-arabic {
		direction: rtl;
		text-align: right;
		font-size: 1rem;
	}

	.file-cards-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
		gap: 1.5rem;
		padding: 1rem;
		max-width: 100%;
		overflow-y: auto;
		overflow-x: auto;
		height: auto;
	}

	.file-card {
		background: white;
		border: 2px solid #ff9500;
		border-radius: 8px;
		min-height: auto;
		max-height: none;
		transition: box-shadow 0.2s, border-color 0.2s;
	}

	.file-card:hover {
		border-color: #10b981;
		box-shadow: 0 2px 8px rgba(16, 185, 129, 0.15);
	}

	.file-card-content {
		padding: 1rem;
		height: auto;
		display: flex;
		align-items: flex-start;
		justify-content: flex-start;
		overflow-y: auto;
		max-height: 600px;
	}

	.nationality-card {
		background: #f0f8f5;
		border: 2px solid #10b981 !important;
	}

	.nationality-content {
		align-items: stretch;
		justify-content: flex-start;
	}

	.id-card {
		background: #f0f8ff;
		border: 2px solid #ff9500 !important;
	}

	.id-content {
		align-items: stretch;
		justify-content: flex-start;
	}

	.nationality-form,
	.id-form {
		width: 100%;
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
	}

	.nationality-form h5,
	.id-form h5 {
		margin: 0;
		font-size: 0.85rem;
		font-weight: 600;
		color: #333;
	}

	.nationality-form select,
	.id-form select {
		padding: 0.5rem;
		border: 1px solid #ddd;
		border-radius: 4px;
		font-size: 0.85rem;
		background-color: white;
		cursor: pointer;
	}

	.nationality-form select:focus,
	.id-form select:focus {
		outline: none;
		border-color: #ff9500;
		box-shadow: 0 0 0 3px rgba(255, 149, 0, 0.1);
	}

	.saved-nationality {
		padding: 0.75rem;
		background: #e8f5f1;
		border: 1px solid #10b981;
		border-radius: 4px;
		text-align: center;
	}

	.nationality-display {
		font-size: 0.9rem;
		font-weight: 500;
		color: #10b981;
	}

	.sponsorship-toggle {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
		padding: 0.75rem;
		background: #f0f8f5;
		border-radius: 4px;
		border: 1px solid #d4f3e8;
	}

	.toggle-label {
		display: flex;
		align-items: center;
		gap: 0.75rem;
		font-size: 0.85rem;
		font-weight: 500;
		color: #333;
		cursor: pointer;
	}

	.toggle-switch {
		position: relative;
		display: inline-block;
		width: 44px;
		height: 24px;
	}

	.toggle-input {
		opacity: 0;
		width: 0;
		height: 0;
	}

	.toggle-slider {
		position: absolute;
		cursor: pointer;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background-color: #ccc;
		transition: 0.3s;
		border-radius: 24px;
	}

	.toggle-slider:before {
		position: absolute;
		content: "";
		height: 18px;
		width: 18px;
		left: 3px;
		bottom: 3px;
		background-color: white;
		transition: 0.3s;
		border-radius: 50%;
	}

	.toggle-input:checked + .toggle-slider {
		background-color: #10b981;
	}

	.toggle-input:checked + .toggle-slider:before {
		transform: translateX(20px);
	}

	.toggle-status {
		font-size: 0.8rem;
		font-weight: 600;
		color: #ff9500;
	}

	.employment-status-section {
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
		padding: 0.75rem;
		background: #f0f8f5;
		border-radius: 4px;
		border: 1px solid #d4f3e8;
	}

	.status-section-label {
		font-size: 0.9rem;
		font-weight: 600;
		color: #333;
		margin-bottom: 0.25rem;
	}

	.employment-status-rows {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.status-row {
		display: flex;
		align-items: center;
	}

	.status-radio-label {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		cursor: pointer;
		flex: 1;
	}

	.status-radio-input {
		appearance: none;
		width: 18px;
		height: 18px;
		border: 2px solid #10b981;
		border-radius: 50%;
		cursor: pointer;
		transition: all 0.3s ease;
		margin: 0;
		padding: 0;
	}

	.status-radio-input:hover {
		border-color: #059669;
		box-shadow: 0 0 6px rgba(16, 185, 129, 0.3);
	}

	.status-radio-input:checked {
		background: #10b981;
		box-shadow: inset 0 0 4px rgba(255, 255, 255, 0.5);
	}

	.status-radio-button {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		width: 18px;
		height: 18px;
	}

	.status-text {
		font-size: 0.9rem;
		color: #333;
		font-weight: 500;
		user-select: none;
	}

	.form-group-compact {
		display: flex;
		flex-direction: column;
		gap: 0.35rem;
	}

	.form-group-compact label {
		font-size: 0.8rem;
		font-weight: 500;
		color: #666;
	}

	.form-group-compact input {
		padding: 0.5rem;
		border: 1px solid #ddd;
		border-radius: 4px;
		font-size: 0.85rem;
	}

	.form-group-compact input:focus {
		outline: none;
		border-color: #ff9500;
		box-shadow: 0 0 0 3px rgba(255, 149, 0, 0.1);
	}

	.saved-date-info {
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
		padding: 0.75rem;
		background: #fff8f0;
		border: 1px solid #ff9500;
		border-radius: 4px;
	}

	.saved-date-display {
		display: flex;
		justify-content: space-between;
		align-items: center;
		font-size: 0.9rem;
	}

	.date-label {
		font-weight: 500;
		color: #666;
	}

	.date-value {
		font-weight: 600;
		color: #ff9500;
	}

	.worked-duration-info {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
		padding: 0.75rem;
		background: #f0f8f5;
		border: 1px solid #10b981;
		border-radius: 4px;
		margin-top: 0.5rem;
	}

	.duration-label {
		font-weight: 600;
		color: #047857;
		font-size: 0.9rem;
	}

	.duration-display {
		display: flex;
		flex-wrap: wrap;
		gap: 0.5rem;
		font-size: 0.85rem;
	}

	.duration-item {
		background: #d1f3dc;
		color: #065f46;
		padding: 0.25rem 0.6rem;
		border-radius: 3px;
		font-weight: 500;
	}

	.expiry-info {
		padding: 0.5rem;
		border-radius: 4px;
		font-size: 0.85rem;
		text-align: center;
	}

	.expiry-valid {
		color: #10b981;
		font-weight: 500;
	}

	.expiry-warning {
		color: #eab308;
		font-weight: 500;
	}

	.expiry-expired {
		color: #ef4444;
		font-weight: 500;
	}

	.probation-finished {
		margin-bottom: 0.5rem;
	}

	.finish-badge {
		display: inline-block;
		background: #10b981;
		color: white;
		padding: 0.35rem 0.75rem;
		border-radius: 4px;
		font-size: 0.8rem;
		font-weight: 600;
	}

	.save-button-small {
		padding: 0.5rem 1rem;
		background: #ff9500;
		color: white;
		border: none;
		border-radius: 4px;
		cursor: pointer;
		font-size: 0.8rem;
		font-weight: 500;
		transition: background-color 0.2s;
	}

	.save-button-small:hover {
		background: #ff8000;
	}

	.update-button {
		padding: 0.5rem 1rem;
		background: #10b981;
		color: white;
		border: none;
		border-radius: 4px;
		cursor: pointer;
		font-size: 0.8rem;
		font-weight: 500;
		transition: background-color 0.2s;
	}

	.update-button:hover {
		background: #059669;
	}

	.expiry-expired {
		color: #ef4444;
		font-weight: 500;
	}

	.save-button-small {
		padding: 0.5rem 1rem;
		background: #ff9500;
		color: white;
		border: none;
		border-radius: 4px;
		cursor: pointer;
		font-size: 0.8rem;
		font-weight: 500;
		transition: background-color 0.2s;
	}

	.save-button-small:hover {
		background: #ff8000;
	}

	.file-upload-group {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.file-upload-group label {
		font-size: 0.8rem;
		font-weight: 500;
		color: #666;
	}

	.file-upload-group input[type="file"] {
		font-size: 0.8rem;
		padding: 0.5rem;
		border: 1px dashed #ddd;
		border-radius: 4px;
	}

	.upload-button {
		padding: 0.5rem 1rem;
		background: #667eea;
		color: white;
		border: none;
		border-radius: 4px;
		cursor: pointer;
		font-size: 0.8rem;
		font-weight: 500;
		transition: background-color 0.2s;
	}

	.upload-button:hover:not(:disabled) {
		background: #5568d3;
	}

	.contract-card {
		background: #f0f8ff;
		border: 2px solid #ff9500 !important;
	}

	.contract-content {
		align-items: stretch;
		justify-content: flex-start;
	}

	.contract-form {
		width: 100%;
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
	}

	.contract-form h5 {
		margin: 0;
		font-size: 0.85rem;
		font-weight: 600;
		color: #333;
	}

	.bank-card {
		background: #f0f8ff;
		border: 2px solid #667eea !important;
	}

	.bank-content {
		align-items: stretch;
		justify-content: flex-start;
	}

	.bank-form {
		width: 100%;
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
	}

	.bank-form h5 {
		margin: 0;
		font-size: 0.85rem;
		font-weight: 600;
		color: #333;
	}

	.upload-button:disabled {
		background: #ccc;
		cursor: not-allowed;
	}

	.view-button {
		padding: 0.5rem 1rem;
		background: #667eea;
		color: white;
		border: none;
		border-radius: 4px;
		cursor: pointer;
		font-size: 0.8rem;
		font-weight: 500;
		transition: background-color 0.2s;
	}

	.view-button:hover {
		background: #5568d3;
	}

	.health-card {
		background: #f0f8ff;
		border: 2px solid #ff9500 !important;
	}

	.health-content {
		align-items: stretch;
		justify-content: flex-start;
	}

	.health-form {
		width: 100%;
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
	}

	.health-form h5 {
		margin: 0;
		font-size: 0.85rem;
		font-weight: 600;
		color: #333;
	}

	.health-form select {
		padding: 0.5rem;
		border: 1px solid #ddd;
		border-radius: 4px;
		font-size: 0.85rem;
		background-color: white;
		cursor: pointer;
	}

	.health-form select:focus {
		outline: none;
		border-color: #ff9500;
		box-shadow: 0 0 0 3px rgba(255, 149, 0, 0.1);
	}

	.driving-licence-card {
		background: #f0f8ff;
		border: 2px solid #ff9500 !important;
	}

	.driving-licence-content {
		align-items: stretch;
		justify-content: flex-start;
	}

	.driving-licence-form {
		width: 100%;
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
	}

	.driving-licence-form h5 {
		margin: 0;
		font-size: 0.85rem;
		font-weight: 600;
		color: #333;
	}

	.driving-licence-form select {
		padding: 0.5rem;
		border: 1px solid #ddd;
		border-radius: 4px;
		font-size: 0.85rem;
		background-color: white;
		cursor: pointer;
	}

	.driving-licence-form select:focus {
		outline: none;
		border-color: #ff9500;
		box-shadow: 0 0 0 3px rgba(255, 149, 0, 0.1);
	}

	.bank-card {
		background: #f0f8ff;
		border: 2px solid #667eea !important;
	}

	.bank-content {
		align-items: stretch;
		justify-content: flex-start;
	}

	.bank-form {
		width: 100%;
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
	}

	.bank-form h5 {
		margin: 0;
		font-size: 0.85rem;
		font-weight: 600;
		color: #333;
	}

	.bank-form select {
		padding: 0.5rem;
		border: 1px solid #ddd;
		border-radius: 4px;
		font-size: 0.85rem;
		background-color: white;
		cursor: pointer;
	}

	.bank-form select:focus {
		outline: none;
		border-color: #667eea;
		box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
	}

	.card-number {
		font-size: 1.5rem;
		font-weight: bold;
		color: #ff9500;
	}

	.loading,
	.error,
	.no-results {
		padding: 2rem;
		text-align: center;
		color: #666;
	}

	.error {
		color: #e53e3e;
	}

	.loading {
		color: #667eea;
	}

	/* Insurance Card Styles */
	.insurance-card {
		background: #f0fdf4;
		border: 2px solid #10b981 !important;
	}

	.insurance-content {
		align-items: stretch;
		justify-content: flex-start;
	}

	.insurance-form {
		width: 100%;
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
	}

	.insurance-form h5 {
		margin: 0;
		font-size: 0.85rem;
		font-weight: 600;
		color: #333;
	}

	.personal-info-card {
		background: #f0f4ff;
		border: 2px solid #3b82f6 !important;
	}

	.personal-info-content {
		align-items: stretch;
		justify-content: flex-start;
	}

	.personal-info-form {
		width: 100%;
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
	}

	.personal-info-form h5 {
		margin: 0;
		font-size: 0.85rem;
		font-weight: 600;
		color: #333;
	}

	.age-display {
		font-size: 0.7rem;
		color: #3b82f6;
		font-weight: 600;
		background: #eff6ff;
		padding: 2px 8px;
		border-radius: 4px;
		display: inline-block;
		margin-top: 0.25rem;
		border: 1px solid #dbeafe;
		text-transform: uppercase;
		letter-spacing: 0.025em;
	}

	/* POS Shortages Card Styles */
	.pos-shortages-card {
		background: #fef3c7;
		border: 2px solid #f59e0b !important;
	}

	.pos-shortages-content {
		align-items: stretch;
		justify-content: flex-start;
	}

	.pos-shortages-form {
		width: 100%;
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
	}

	.pos-shortages-form h5 {
		margin: 0;
		font-size: 0.85rem;
		font-weight: 600;
		color: #333;
		text-align: center;
	}

	.shortage-total-compact {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 0.5rem;
		background: white;
		border-radius: 4px;
		border: 1px solid #fbbf24;
	}

	.shortage-total-compact .label-text {
		font-size: 0.75rem;
		font-weight: 600;
		color: #78350f;
	}

	.shortage-total-compact .total-value {
		font-size: 0.9rem;
		font-weight: 700;
		color: #d97706;
	}

	.shortage-items-compact {
		display: flex;
		flex-direction: column;
		gap: 0.35rem;
	}

	.shortage-row {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 0.35rem 0.5rem;
		background: white;
		border-radius: 3px;
		border-left: 3px solid;
		font-size: 0.75rem;
	}

	.shortage-row.proposed {
		border-left-color: #15a34a;
	}

	.shortage-row.forgiven {
		border-left-color: #f59e0b;
	}

	.shortage-row.deducted {
		border-left-color: #dc2626;
	}

	.shortage-row.cancelled {
		border-left-color: #6b7280;
	}

	.shortage-row .status-text {
		font-weight: 500;
		color: #333;
	}

	.shortage-row .amount-text {
		font-weight: 600;
		font-family: 'Courier New', monospace;
		color: #666;
	}

	.secondary-button {
		padding: 0.5rem 1rem;
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 4px;
		cursor: pointer;
		font-size: 0.8rem;
		font-weight: 500;
		transition: background-color 0.2s;
		margin-top: 0.5rem;
	}

	.secondary-button:hover {
		background: #2563eb;
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
		background: white;
		border-radius: 8px;
		box-shadow: 0 10px 40px rgba(0, 0, 0, 0.2);
		max-width: 500px;
		width: 90%;
		max-height: 80vh;
		overflow-y: auto;
	}

	.modal-header {
		padding: 1.5rem;
		border-bottom: 1px solid #e5e7eb;
		display: flex;
		justify-content: space-between;
		align-items: center;
	}

	.modal-header h3 {
		margin: 0;
		font-size: 1.3rem;
		color: #1f2937;
		font-weight: 600;
	}

	.close-button {
		background: none;
		border: none;
		font-size: 1.5rem;
		cursor: pointer;
		color: #6b7280;
		padding: 0;
		width: 2rem;
		height: 2rem;
		display: flex;
		align-items: center;
		justify-content: center;
		border-radius: 4px;
		transition: background-color 0.2s;
	}

	.close-button:hover {
		background-color: #f3f4f6;
	}

	.modal-body {
		padding: 1.5rem;
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}

	.modal-footer {
		padding: 1.5rem;
		border-top: 1px solid #e5e7eb;
		display: flex;
		gap: 1rem;
		justify-content: flex-end;
	}

	.cancel-button {
		padding: 0.6rem 1.5rem;
		background: #e5e7eb;
		color: #1f2937;
		border: none;
		border-radius: 4px;
		cursor: pointer;
		font-weight: 500;
		transition: background-color 0.2s;
	}

	.cancel-button:hover {
		background: #d1d5db;
	}

	.save-button {
		padding: 0.6rem 1.5rem;
		background: #10b981;
		color: white;
		border: none;
		border-radius: 4px;
		cursor: pointer;
		font-weight: 500;
		transition: background-color 0.2s;
	}

	.save-button:hover:not(:disabled) {
		background: #059669;
	}

	.save-button:disabled {
		background: #d1d5db;
		cursor: not-allowed;
	}

	.input-with-button {
		display: flex;
		gap: 0.5rem;
		align-items: center;
	}

	.input-with-button select,
	.input-with-button input {
		flex: 1;
	}

	.add-btn-small {
		padding: 0.4rem 0.6rem;
		background: #10b981;
		color: white;
		border: none;
		border-radius: 4px;
		cursor: pointer;
		font-size: 0.8rem;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: transform 0.2s, background-color 0.2s;
	}

	.add-btn-small:hover {
		background: #059669;
		transform: scale(1.05);
	}
</style>
