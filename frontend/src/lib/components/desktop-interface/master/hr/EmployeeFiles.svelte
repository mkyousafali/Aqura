<script lang="ts">
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { dataService } from '$lib/utils/dataService';

	// State
	let branches: any[] = [];
	let nationalities: any[] = [];
	let employees: any[] = [];
	let filteredEmployees: any[] = [];
	let selectedBranch = '';
	let searchTerm = '';
	let selectedEmployee: any = null;
	let selectedNationality = '';
	let sponsorshipStatus = false;
	let savedSponsorshipStatus = false;
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
	let insuranceCompanies: any[] = [];
	let selectedInsuranceCompanyId = '';
	let savedInsuranceCompanyId = '';
	let insuranceExpiryDate = '';
	let savedInsuranceExpiryDate = '';
	let insuranceDaysUntilExpiry = 0;
	let isCreatingInsuranceCompany = false;
	let newInsuranceCompanyNameEn = '';
	let newInsuranceCompanyNameAr = '';
	let showCreateInsuranceModal = false;

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
		await loadEmployees();
	});

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

	async function createInsuranceCompany() {
		if (!newInsuranceCompanyNameEn || !newInsuranceCompanyNameAr) {
			alert('Please enter company names in both languages');
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
				alert('Failed to create insurance company');
				return;
			}

			if (data && data[0]) {
				insuranceCompanies = [...insuranceCompanies, data[0]];
				selectedInsuranceCompanyId = data[0].id;
				newInsuranceCompanyNameEn = '';
				newInsuranceCompanyNameAr = '';
				showCreateInsuranceModal = false;
				alert('Insurance company created successfully!');
			}
		} catch (error) {
			console.error('Error creating insurance company:', error);
			alert('Failed to create insurance company');
		} finally {
			isCreatingInsuranceCompany = false;
		}
	}

	async function loadBranches() {
		isLoading = true;
		errorMessage = '';
		
		try {
			const { data, error } = await dataService.branches.getAll();
			if (error) {
				console.error('Error loading branches:', error);
				errorMessage = 'Failed to load branches';
				return;
			}
			branches = data || [];
		} catch (error) {
			console.error('Error loading branches:', error);
			errorMessage = 'Failed to load branches';
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
					nationality_id,
					sponsorship_status,
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
					insurance_company_id,
					insurance_expiry_date
				`);

			if (error) {
				console.error('Error loading employees:', error);
				errorMessage = 'Failed to load employees';
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
			errorMessage = 'Failed to load employees';
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

		// Filter by nationality
		if (selectedNationality) {
			filtered = filtered.filter(emp => 
				emp.nationality_id === selectedNationality
			);
		}

		// Filter by search term
		if (searchTerm) {
			const search = searchTerm.toLowerCase();
			filtered = filtered.filter(emp => 
				emp.id?.toLowerCase().includes(search) ||
				emp.name_en?.toLowerCase().includes(search) ||
				emp.name_ar?.includes(search)
			);
		}

		filteredEmployees = filtered;
	}

	function selectEmployee(employee: any) {
		selectedEmployee = employee;
		selectedNationality = employee.nationality_id || '';
		sponsorshipStatus = employee.sponsorship_status || false;
		savedSponsorshipStatus = employee.sponsorship_status || false;
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
			alert('Please enter ID number');
			return;
		}

		try {
			const { error } = await supabase
				.from('hr_employee_master')
				.update({ id_number: idNumber })
				.eq('id', selectedEmployee.id);

			if (error) {
				console.error('Error saving ID number:', error);
				alert('Failed to save ID number');
				return;
			}

			selectedEmployee.id_number = idNumber;
			savedIdNumber = idNumber;
			alert('ID number saved successfully!');
		} catch (error) {
			console.error('Error saving ID number:', error);
			alert('Failed to save ID number');
		}
	}

	async function saveIDExpiryDate() {
		if (!selectedEmployee || !idExpiryDate) {
			alert('Please select an expiry date');
			return;
		}

		try {
			const { error } = await supabase
				.from('hr_employee_master')
				.update({ id_expiry_date: idExpiryDate })
				.eq('id', selectedEmployee.id);

			if (error) {
				console.error('Error saving expiry date:', error);
				alert('Failed to save expiry date');
				return;
			}

			selectedEmployee.id_expiry_date = idExpiryDate;
			savedIdExpiryDate = idExpiryDate;
			calculateDaysUntilExpiry();
			alert('Expiry date saved successfully!');
		} catch (error) {
			console.error('Error saving expiry date:', error);
			alert('Failed to save expiry date');
		}
	}

	async function saveWorkPermitExpiryDate() {
		if (!selectedEmployee || !workPermitExpiryDate) {
			alert('Please select work permit expiry date');
			return;
		}

		try {
			const { error } = await supabase
				.from('hr_employee_master')
				.update({ work_permit_expiry_date: workPermitExpiryDate })
				.eq('id', selectedEmployee.id);

			if (error) {
				console.error('Error saving work permit expiry date:', error);
				alert('Failed to save work permit expiry date');
				return;
			}

			selectedEmployee.work_permit_expiry_date = workPermitExpiryDate;
			savedWorkPermitExpiryDate = workPermitExpiryDate;
			calculateWorkPermitDaysUntilExpiry();
			alert('Work permit expiry date saved successfully!');
		} catch (error) {
			console.error('Error saving work permit expiry date:', error);
			alert('Failed to save work permit expiry date');
		}
	}

	async function uploadIDDocument() {
		if (!selectedEmployee || !idDocumentFile) {
			alert('Please select a file to upload');
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
				alert('Failed to upload document');
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
				alert('Failed to save document URL');
				return;
			}

			selectedEmployee.id_document_url = publicUrl.publicUrl;
			idDocumentFile = null;
			alert('Document uploaded successfully!');
		} catch (error) {
			console.error('Error uploading document:', error);
			alert('Failed to upload document');
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

	async function saveHealthCardNumber() {
		if (!selectedEmployee || !healthCardNumber) {
			alert('Please enter health card number');
			return;
		}

		try {
			const { error } = await supabase
				.from('hr_employee_master')
				.update({ health_card_number: healthCardNumber })
				.eq('id', selectedEmployee.id);

			if (error) {
				console.error('Error saving health card number:', error);
				alert('Failed to save health card number');
				return;
			}

			selectedEmployee.health_card_number = healthCardNumber;
			savedHealthCardNumber = healthCardNumber;
			alert('Health card number saved successfully!');
		} catch (error) {
			console.error('Error saving health card number:', error);
			alert('Failed to save health card number');
		}
	}

	async function saveHealthCardExpiryDate() {
		if (!selectedEmployee || !healthCardExpiryDate) {
			alert('Please select an expiry date');
			return;
		}

		try {
			const { error } = await supabase
				.from('hr_employee_master')
				.update({ health_card_expiry_date: healthCardExpiryDate })
				.eq('id', selectedEmployee.id);

			if (error) {
				console.error('Error saving health card expiry date:', error);
				alert('Failed to save expiry date');
				return;
			}

			selectedEmployee.health_card_expiry_date = healthCardExpiryDate;
			savedHealthCardExpiryDate = healthCardExpiryDate;
			calculateHealthCardDaysUntilExpiry();
			alert('Health card expiry date saved successfully!');
		} catch (error) {
			console.error('Error saving health card expiry date:', error);
			alert('Failed to save expiry date');
		}
	}

	async function saveHealthEducationalRenewalDate() {
		if (!selectedEmployee || !healthEducationalRenewalDate) {
			alert('Please select a renewal date');
			return;
		}

		try {
			const { error } = await supabase
				.from('hr_employee_master')
				.update({ health_educational_renewal_date: healthEducationalRenewalDate })
				.eq('id', selectedEmployee.id);

			if (error) {
				console.error('Error saving health educational renewal date:', error);
				alert('Failed to save renewal date');
				return;
			}

			selectedEmployee.health_educational_renewal_date = healthEducationalRenewalDate;
			savedHealthEducationalRenewalDate = healthEducationalRenewalDate;
			calculateHealthEducationalRenewalDaysUntilExpiry();
			alert('Health educational renewal date saved successfully!');
		} catch (error) {
			console.error('Error saving health educational renewal date:', error);
			alert('Failed to save renewal date');
		}
	}

	async function uploadHealthCardDocument() {
		if (!selectedEmployee || !healthCardFile) {
			alert('Please select a file to upload');
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
				alert('Failed to upload document');
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
				alert('Failed to save document URL');
				return;
			}

			selectedEmployee.health_card_document_url = publicUrl.publicUrl;
			healthCardFile = null;
			alert('Health card document uploaded successfully!');
		} catch (error) {
			console.error('Error uploading health card document:', error);
			alert('Failed to upload document');
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
			alert('Please enter driving licence number');
			return;
		}

		try {
			const { error } = await supabase
				.from('hr_employee_master')
				.update({ driving_licence_number: drivingLicenceNumber })
				.eq('id', selectedEmployee.id);

			if (error) {
				console.error('Error saving driving licence number:', error);
				alert('Failed to save driving licence number');
				return;
			}

			selectedEmployee.driving_licence_number = drivingLicenceNumber;
			savedDrivingLicenceNumber = drivingLicenceNumber;
			alert('Driving licence number saved successfully!');
		} catch (error) {
			console.error('Error saving driving licence number:', error);
			alert('Failed to save driving licence number');
		}
	}

	async function saveDrivingLicenceExpiryDate() {
		if (!selectedEmployee || !drivingLicenceExpiryDate) {
			alert('Please select an expiry date');
			return;
		}

		try {
			const { error } = await supabase
				.from('hr_employee_master')
				.update({ driving_licence_expiry_date: drivingLicenceExpiryDate })
				.eq('id', selectedEmployee.id);

			if (error) {
				console.error('Error saving driving licence expiry date:', error);
				alert('Failed to save expiry date');
				return;
			}

			selectedEmployee.driving_licence_expiry_date = drivingLicenceExpiryDate;
			savedDrivingLicenceExpiryDate = drivingLicenceExpiryDate;
			calculateDrivingLicenceDaysUntilExpiry();
			alert('Driving licence expiry date saved successfully!');
		} catch (error) {
			console.error('Error saving driving licence expiry date:', error);
			alert('Failed to save expiry date');
		}
	}

	async function uploadDrivingLicenceDocument() {
		if (!selectedEmployee || !drivingLicenceFile) {
			alert('Please select a file to upload');
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
				alert('Failed to upload document');
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
				alert('Failed to save document URL');
				return;
			}

			selectedEmployee.driving_licence_document_url = publicUrl.publicUrl;
			drivingLicenceFile = null;
			alert('Driving licence document uploaded successfully!');
		} catch (error) {
			console.error('Error uploading driving licence document:', error);
			alert('Failed to upload document');
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
			alert('Please select an expiry date');
			return;
		}

		try {
			const { error } = await supabase
				.from('hr_employee_master')
				.update({ contract_expiry_date: contractExpiryDate })
				.eq('id', selectedEmployee.id);

			if (error) {
				console.error('Error saving contract expiry date:', error);
				alert('Failed to save expiry date');
				return;
			}

			selectedEmployee.contract_expiry_date = contractExpiryDate;
			savedContractExpiryDate = contractExpiryDate;
			calculateContractDaysUntilExpiry();
			alert('Contract expiry date saved successfully!');
		} catch (error) {
			console.error('Error saving contract expiry date:', error);
			alert('Failed to save expiry date');
		}
	}

	async function uploadContractDocument() {
		if (!selectedEmployee || !contractFile) {
			alert('Please select a file to upload');
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
				alert('Failed to upload document');
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
				alert('Failed to save document URL');
				return;
			}

			selectedEmployee.contract_document_url = publicUrl.publicUrl;
			contractFile = null;
			alert('Contract document uploaded successfully!');
		} catch (error) {
			console.error('Error uploading contract document:', error);
			alert('Failed to upload document');
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
			alert('Please enter bank name');
			return;
		}

		try {
			const { error } = await supabase
				.from('hr_employee_master')
				.update({ bank_name: bankName })
				.eq('id', selectedEmployee.id);

			if (error) {
				console.error('Error saving bank name:', error);
				alert('Failed to save bank name');
				return;
			}

			selectedEmployee.bank_name = bankName;
			savedBankName = bankName;
			alert('Bank name saved successfully!');
		} catch (error) {
			console.error('Error saving bank name:', error);
			alert('Failed to save bank name');
		}
	}

	async function saveIban() {
		if (!selectedEmployee || !iban) {
			alert('Please enter IBAN');
			return;
		}

		try {
			const { error } = await supabase
				.from('hr_employee_master')
				.update({ iban: iban })
				.eq('id', selectedEmployee.id);

			if (error) {
				console.error('Error saving IBAN:', error);
				alert('Failed to save IBAN');
				return;
			}

			selectedEmployee.iban = iban;
			savedIban = iban;
			alert('IBAN saved successfully!');
		} catch (error) {
			console.error('Error saving IBAN:', error);
			alert('Failed to save IBAN');
		}
	}

	async function saveDateOfBirth() {
		if (!selectedEmployee || !dateOfBirth) {
			alert('Please enter date of birth');
			return;
		}

		try {
			const { error } = await supabase
				.from('hr_employee_master')
				.update({ date_of_birth: dateOfBirth })
				.eq('id', selectedEmployee.id);

			if (error) {
				console.error('Error saving date of birth:', error);
				alert('Failed to save date of birth');
				return;
			}

			selectedEmployee.date_of_birth = dateOfBirth;
			savedDateOfBirth = dateOfBirth;
			calculateAge();
			alert('Date of birth saved successfully!');
		} catch (error) {
			console.error('Error saving date of birth:', error);
			alert('Failed to save date of birth');
		}
	}

	async function saveJoinDate() {
		if (!selectedEmployee || !joinDate) {
			alert('Please enter join date');
			return;
		}

		try {
			const { error } = await supabase
				.from('hr_employee_master')
				.update({ join_date: joinDate })
				.eq('id', selectedEmployee.id);

			if (error) {
				console.error('Error saving join date:', error);
				alert('Failed to save join date');
				return;
			}

			selectedEmployee.join_date = joinDate;
			savedJoinDate = joinDate;
			alert('Join date saved successfully!');
		} catch (error) {
			console.error('Error saving join date:', error);
			alert('Failed to save join date');
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
			alert('Please select an insurance company');
			return;
		}

		try {
			const { error } = await supabase
				.from('hr_employee_master')
				.update({ insurance_company_id: selectedInsuranceCompanyId })
				.eq('id', selectedEmployee.id);

			if (error) {
				console.error('Error saving insurance company:', error);
				alert('Failed to save insurance company');
				return;
			}

			selectedEmployee.insurance_company_id = selectedInsuranceCompanyId;
			savedInsuranceCompanyId = selectedInsuranceCompanyId;
			alert('Insurance company saved successfully!');
		} catch (error) {
			console.error('Error saving insurance company:', error);
			alert('Failed to save insurance company');
		}
	}

	async function saveInsuranceExpiryDate() {
		if (!selectedEmployee || !insuranceExpiryDate) {
			alert('Please select an expiry date');
			return;
		}

		try {
			const { error } = await supabase
				.from('hr_employee_master')
				.update({ insurance_expiry_date: insuranceExpiryDate })
				.eq('id', selectedEmployee.id);

			if (error) {
				console.error('Error saving insurance expiry date:', error);
				alert('Failed to save insurance expiry date');
				return;
			}

			selectedEmployee.insurance_expiry_date = insuranceExpiryDate;
			savedInsuranceExpiryDate = insuranceExpiryDate;
			calculateInsuranceDaysUntilExpiry();
			alert('Insurance expiry date saved successfully!');
		} catch (error) {
			console.error('Error saving insurance expiry date:', error);
			alert('Failed to save insurance expiry date');
		}
	}

	async function saveNationality() {
		if (!selectedEmployee || !selectedNationality) {
			alert('Please select both an employee and a nationality');
			return;
		}

		try {
			const { error } = await supabase
				.from('hr_employee_master')
				.update({ nationality_id: selectedNationality })
				.eq('id', selectedEmployee.id);

			if (error) {
				console.error('Error saving nationality:', error);
				alert('Failed to save nationality');
				return;
			}

			selectedEmployee.nationality_id = selectedNationality;
			isSaved = true;
			alert('Nationality saved successfully!');
		} catch (error) {
			console.error('Error saving nationality:', error);
			alert('Failed to save nationality');
		}
	}

	async function saveSponsorshipStatus() {
		if (!selectedEmployee) {
			alert('Please select an employee');
			return;
		}

		try {
			const { error } = await supabase
				.from('hr_employee_master')
				.update({ sponsorship_status: sponsorshipStatus })
				.eq('id', selectedEmployee.id);

			if (error) {
				console.error('Error saving sponsorship status:', error);
				alert('Failed to save sponsorship status');
				return;
			}

			selectedEmployee.sponsorship_status = sponsorshipStatus;
			savedSponsorshipStatus = sponsorshipStatus;
			alert('Sponsorship status saved successfully!');
		} catch (error) {
			console.error('Error saving sponsorship status:', error);
			alert('Failed to save sponsorship status');
		}
	}

	// Reactive statements to trigger filtering
	$: if (selectedBranch !== undefined || searchTerm !== undefined || selectedNationality !== undefined) {
		filterEmployees();
	}
</script>

<div class="employee-files-container">
	<div class="cards-wrapper">
		<!-- Card 1: Search & Select Employee -->
		<div class="card">
			<div class="card-header">
				<h3>🔍 Search Employee</h3>
			</div>
			<div class="card-content">
			<!-- Frozen Filter Section -->
			<div class="filters-section-header">
				<h4>Filters</h4>
				<button class="seal-button" on:click={toggleFilters}>
					{filtersOpen ? '✕ Close' : '▶ Open'}
				</button>
			</div>
			{#if filtersOpen}
			<div class="filters-section">
				<!-- Branch Filter -->
				<div class="form-group">
						<label for="branch-filter">Branch</label>
						<select id="branch-filter" bind:value={selectedBranch}>
							<option value="">All Branches</option>
							{#each branches as branch}
								<option value={branch.id}>{branch.branch_name}</option>
							{/each}
						</select>
					</div>

					<!-- Search Input -->
					<div class="form-group">
						<label for="search">Search by Name or ID</label>
						<input 
							type="text" 
							id="search" 
							bind:value={searchTerm} 
							placeholder="Enter employee name or ID..."
						/>
					</div>

					<!-- Nationality Filter -->
					<div class="form-group">
						<label for="nationality-filter">الجنسية | Nationality</label>
						<select id="nationality-filter" bind:value={selectedNationality}>
							<option value="">All Nationalities</option>
							{#each nationalities as nationality}
								<option value={nationality.id}>{nationality.name_ar} / {nationality.name_en}</option>
							{/each}
						</select>
					</div>
				</div>
			{/if}

			<!-- Employee List -->
			<div class="employee-list">
					{#if isLoading}
						<div class="loading">Loading employees...</div>
					{:else if errorMessage}
						<div class="error">{errorMessage}</div>
					{:else}
						<div class="list-header-wrapper">
							<div class="list-header">
								<span>ID</span>
								<span>Name</span>
								<span>Position</span>
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
										<div class="emp-name-ar">{employee.name_ar || '-'}</div>
										<div class="emp-name-en">{employee.name_en || '-'}</div>
									</div>
									<div class="emp-position-stack">
										<div class="emp-position-ar">{employee.hr_positions?.position_title_ar || '-'}</div>
										<div class="emp-position-en">{employee.hr_positions?.position_title_en || '-'}</div>
									</div>
								</div>
							{:else}
								<div class="no-results">No employees found</div>
							{/each}
						</div>
					{/if}
				</div>
			</div>
		</div>

		<!-- Card 2: Employee Files -->
		<div class="card">
			<div class="card-header">
				<h3>📄 Employee Files</h3>
			</div>
			<div class="card-content">
				{#if selectedEmployee}
					<div class="selected-info">
						<div class="info-grid">
							<div class="info-item">
								<span class="info-label">الرقم | ID</span>
								<span class="info-value">{selectedEmployee.id}</span>
							</div>
							<div class="info-item">
								<span class="info-label">الاسم (عربي) | Name (AR)</span>
								<span class="info-value info-arabic">{selectedEmployee.name_ar || '-'}</span>
							</div>
							<div class="info-item">
								<span class="info-label">الاسم (انجليزي) | Name (EN)</span>
								<span class="info-value">{selectedEmployee.name_en || '-'}</span>
							</div>
							<div class="info-item">
								<span class="info-label">المنصب (عربي) | Position (AR)</span>
								<span class="info-value info-arabic">{selectedEmployee.hr_positions?.position_title_ar || '-'}</span>
							</div>
							<div class="info-item">
								<span class="info-label">المنصب (انجليزي) | Position (EN)</span>
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
									<h5>الجنسية | Nationality</h5>
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
										<select bind:value={selectedNationality}>
											<option value="">Select</option>
											{#each nationalities as nationality}
												<option value={nationality.id}>{nationality.name_ar} / {nationality.name_en}</option>
											{/each}
										</select>
									{/if}
									<button class="save-button" on:click={isSaved ? toggleEdit : saveNationality}>
										{#if isSaved}
											✏️ Edit
										{:else}
											💾 Save
										{/if}
									</button>
									
									<!-- Sponsorship Status Toggle -->
									<div class="sponsorship-toggle">
										<label class="toggle-label">
											<span>Sponsorship Status</span>
											<div class="toggle-switch">
												<input 
													type="checkbox" 
													bind:checked={sponsorshipStatus}
													class="toggle-input"
												/>
												<span class="toggle-slider"></span>
											</div>
											<span class="toggle-status">{sponsorshipStatus ? 'Active' : 'Inactive'}</span>
										</label>
										{#if sponsorshipStatus !== savedSponsorshipStatus}
											<button class="save-button-small" on:click={saveSponsorshipStatus}>
												💾 Save Status
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
								<h5>رقم الهوية | ID/Resident ID</h5>
								
								<!-- ID Number Field -->
								{#if !savedIdNumber}
									<!-- Show input when no number is saved -->
									<div class="form-group-compact">
										<label for="id-number">ID Number</label>
										<input 
											type="text" 
											id="id-number" 
											bind:value={idNumber}
											placeholder="Enter ID number"
										/>
									</div>
									<button class="save-button-small" on:click={saveIDNumber}>
										💾 Save Number
									</button>
								{:else}
									<!-- Show saved number info -->
									<div class="saved-date-info">
										<div class="saved-date-display">
											<span class="date-label">ID Number:</span>
											<span class="date-value">{savedIdNumber}</span>
										</div>
									</div>
									
									<!-- Edit number input (hidden by default) -->
									{#if idNumber !== savedIdNumber}
										<div class="form-group-compact">
											<label for="id-number-edit">Change ID Number</label>
											<input 
												type="text" 
												id="id-number-edit" 
												bind:value={idNumber}
												placeholder="Enter ID number"
											/>
										</div>
										<button class="save-button-small" on:click={saveIDNumber}>
											💾 Update Number
										</button>
									{:else}
										<button class="update-button" on:click={() => idNumber = ''}>
											✏️ Edit Number
										</button>
									{/if}
								{/if}
								
								<!-- Expiry Date Field -->
								{#if !savedIdExpiryDate}
									<!-- Show input when no date is saved -->
									<div class="form-group-compact">
										<label for="id-expiry">Expiry Date</label>
										<input 
											type="date" 
											id="id-expiry" 
											bind:value={idExpiryDate}
											on:change={calculateDaysUntilExpiry}
										/>
									</div>
									<button class="save-button-small" on:click={saveIDExpiryDate}>
										💾 Save Date
									</button>
								{:else}
									<!-- Show saved date info when saved -->
									<div class="saved-date-info">
										<div class="saved-date-display">
											<span class="date-label">Saved:</span>
											<span class="date-value">
												{savedIdExpiryDate ? new Date(savedIdExpiryDate).toLocaleDateString('en-GB') : '-'}
											</span>
										</div>
										{#if daysUntilExpiry > 0}
											<span class="expiry-valid">⏰ {daysUntilExpiry} days remaining</span>
										{:else if daysUntilExpiry === 0}
											<span class="expiry-warning">⚠️ Expires today!</span>
										{:else}
											<span class="expiry-expired">❌ Expired {Math.abs(daysUntilExpiry)} days ago</span>
										{/if}
									</div>
									
									<!-- Edit date input (hidden by default) -->
									{#if idExpiryDate !== savedIdExpiryDate}
										<div class="form-group-compact">
											<label for="id-expiry">Change Expiry Date</label>
											<input 
												type="date" 
												id="id-expiry" 
												bind:value={idExpiryDate}
												on:change={calculateDaysUntilExpiry}
											/>
										</div>
										<button class="save-button-small" on:click={saveIDExpiryDate}>
											💾 Save Date
										</button>
									{:else}
										<button class="update-button" on:click={() => idExpiryDate = ''}>
											✏️ Update Date
										</button>
									{/if}
								{/if}

								<!-- Work Permit Expiry Date Field -->
								{#if !savedWorkPermitExpiryDate}
									<!-- Show input when no date is saved -->
									<div class="form-group-compact">
										<label for="work-permit-expiry">Work Permit Expiry Date</label>
										<input 
											type="date" 
											id="work-permit-expiry" 
											bind:value={workPermitExpiryDate}
											on:change={calculateWorkPermitDaysUntilExpiry}
										/>
									</div>
									<button class="save-button-small" on:click={saveWorkPermitExpiryDate}>
										💾 Save Work Permit Date
									</button>
								{:else}
									<!-- Show saved date info when saved -->
									<div class="saved-date-info">
										<div class="saved-date-display">
											<span class="date-label">Work Permit:</span>
											<span class="date-value">
												{savedWorkPermitExpiryDate ? new Date(savedWorkPermitExpiryDate).toLocaleDateString('en-GB') : '-'}
											</span>
										</div>
										{#if workPermitDaysUntilExpiry > 0}
											<span class="expiry-valid">⏰ {workPermitDaysUntilExpiry} days remaining</span>
										{:else if workPermitDaysUntilExpiry === 0}
											<span class="expiry-warning">⚠️ Expires today!</span>
										{:else}
											<span class="expiry-expired">❌ Expired {Math.abs(workPermitDaysUntilExpiry)} days ago</span>
										{/if}
									</div>
									
									<!-- Edit date input (hidden by default) -->
									{#if workPermitExpiryDate !== savedWorkPermitExpiryDate}
										<div class="form-group-compact">
											<label for="work-permit-expiry">Change Work Permit Date</label>
											<input 
												type="date" 
												id="work-permit-expiry" 
												bind:value={workPermitExpiryDate}
												on:change={calculateWorkPermitDaysUntilExpiry}
											/>
										</div>
										<button class="save-button-small" on:click={saveWorkPermitExpiryDate}>
											💾 Save Work Permit Date
										</button>
									{:else}
										<button class="update-button" on:click={() => workPermitExpiryDate = ''}>
											✏️ Update Work Permit Date
										</button>
									{/if}
								{/if}

								<!-- File Upload -->
								<div class="file-upload-group">
									<label for="id-document">Upload Document</label>
									{#if selectedEmployee?.id_document_url}
										<!-- Document already uploaded -->
										<button class="view-button" on:click={viewIDDocument}>
											👁️ View Document
										</button>
										{#if !idDocumentFile}
											<button class="update-button" on:click={() => idDocumentFile = {} as any}>
												✏️ Update Document
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
												{isUploadingDocument ? '⏳ Uploading...' : '📤 Upload'}
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
											{isUploadingDocument ? '⏳ Uploading...' : '📤 Upload'}
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
								<h5>بطاقة صحية | Health Card</h5>
								
								<!-- Health Card Number Field -->
								{#if !savedHealthCardNumber}
									<!-- Show input when no number is saved -->
									<div class="form-group-compact">
										<label for="health-card-number">Card Number</label>
										<input 
											type="text" 
											id="health-card-number" 
											bind:value={healthCardNumber}
											placeholder="Enter health card number"
										/>
									</div>
									<button class="save-button-small" on:click={saveHealthCardNumber}>
										💾 Save Number
									</button>
								{:else}
									<!-- Show saved number info -->
									<div class="saved-date-info">
										<div class="saved-date-display">
											<span class="date-label">Card Number:</span>
											<span class="date-value">{savedHealthCardNumber}</span>
										</div>
									</div>
									
									<!-- Edit number input (hidden by default) -->
									{#if healthCardNumber !== savedHealthCardNumber}
										<div class="form-group-compact">
											<label for="health-card-number-edit">Change Card Number</label>
											<input 
												type="text" 
												id="health-card-number-edit" 
												bind:value={healthCardNumber}
												placeholder="Enter health card number"
											/>
										</div>
										<button class="save-button-small" on:click={saveHealthCardNumber}>
											💾 Update Number
										</button>
									{:else}
										<button class="update-button" on:click={() => healthCardNumber = ''}>
											✏️ Edit Number
										</button>
									{/if}
								{/if}
								
								<!-- Expiry Date Field -->
								{#if !savedHealthCardExpiryDate}
									<!-- Show input when no date is saved -->
									<div class="form-group-compact">
										<label for="health-expiry">Expiry Date</label>
										<input 
											type="date" 
											id="health-expiry" 
											bind:value={healthCardExpiryDate}
											on:change={calculateHealthCardDaysUntilExpiry}
										/>
									</div>
									<button class="save-button-small" on:click={saveHealthCardExpiryDate}>
										💾 Save Date
									</button>
								{:else}
									<!-- Show saved date info when saved -->
									<div class="saved-date-info">
										<div class="saved-date-display">
											<span class="date-label">Saved:</span>
											<span class="date-value">
												{savedHealthCardExpiryDate ? new Date(savedHealthCardExpiryDate).toLocaleDateString('en-GB') : '-'}
											</span>
										</div>
										{#if healthCardDaysUntilExpiry > 0}
											<span class="expiry-valid">⏰ {healthCardDaysUntilExpiry} days remaining</span>
										{:else if healthCardDaysUntilExpiry === 0}
											<span class="expiry-warning">⚠️ Expires today!</span>
										{:else}
											<span class="expiry-expired">❌ Expired {Math.abs(healthCardDaysUntilExpiry)} days ago</span>
										{/if}
									</div>
									
									<!-- Edit date input (hidden by default) -->
									{#if healthCardExpiryDate !== savedHealthCardExpiryDate}
										<div class="form-group-compact">
											<label for="health-expiry">Change Expiry Date</label>
											<input 
												type="date" 
												id="health-expiry" 
												bind:value={healthCardExpiryDate}
												on:change={calculateHealthCardDaysUntilExpiry}
											/>
										</div>
										<button class="save-button-small" on:click={saveHealthCardExpiryDate}>
											💾 Save Date
										</button>
									{:else}
										<button class="update-button" on:click={() => healthCardExpiryDate = ''}>
											✏️ Update Date
										</button>
									{/if}
								{/if}

								<!-- File Upload -->
								<div class="file-upload-group">
									<label for="health-document">Upload Document</label>
									{#if selectedEmployee?.health_card_document_url}
										<!-- Document already uploaded -->
										<button class="view-button" on:click={viewHealthCardDocument}>
											👁️ View Document
										</button>
										{#if !healthCardFile}
											<button class="update-button" on:click={() => healthCardFile = {} as any}>
												✏️ Update Document
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
												{isUploadingHealthCard ? '⏳ Uploading...' : '📤 Upload'}
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
											{isUploadingHealthCard ? '⏳ Uploading...' : '📤 Upload'}
										</button>
									{/if}
								</div>

								<!-- Health Educational Renewal Date Field -->
								{#if !savedHealthEducationalRenewalDate}
									<!-- Show input when no date is saved -->
									<div class="form-group-compact">
										<label for="health-educational-renewal">Education Expiry Date</label>
										<input 
											type="date" 
											id="health-educational-renewal" 
											bind:value={healthEducationalRenewalDate}
											on:change={calculateHealthEducationalRenewalDaysUntilExpiry}
										/>
									</div>
									<button class="save-button-small" on:click={saveHealthEducationalRenewalDate}>
										💾 Save Expiry Date
									</button>
								{:else}
									<!-- Show saved date info when saved -->
									<div class="saved-date-info">
										<div class="saved-date-display">
											<span class="date-label">Education Expiry Date:</span>
											<span class="date-value">
												{savedHealthEducationalRenewalDate ? new Date(savedHealthEducationalRenewalDate).toLocaleDateString('en-GB') : '-'}
											</span>
										</div>
										{#if healthEducationalRenewalDaysUntilExpiry > 0}
											<span class="expiry-valid">⏰ {healthEducationalRenewalDaysUntilExpiry} days remaining</span>
										{:else if healthEducationalRenewalDaysUntilExpiry === 0}
											<span class="expiry-warning">⚠️ Expires today!</span>
										{:else}
											<span class="expiry-expired">❌ Expired {Math.abs(healthEducationalRenewalDaysUntilExpiry)} days ago</span>
										{/if}
									</div>
									
									<!-- Edit date input (hidden by default) -->
									{#if healthEducationalRenewalDate !== savedHealthEducationalRenewalDate}
										<div class="form-group-compact">
											<label for="health-educational-renewal">Change Education Expiry Date</label>
											<input 
												type="date" 
												id="health-educational-renewal" 
												bind:value={healthEducationalRenewalDate}
												on:change={calculateHealthEducationalRenewalDaysUntilExpiry}
											/>
										</div>
										<button class="save-button-small" on:click={saveHealthEducationalRenewalDate}>
											💾 Save Expiry Date
										</button>
									{:else}
										<button class="update-button" on:click={() => healthEducationalRenewalDate = ''}>
											✏️ Update Expiry Date
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
								<h5>رخصة القيادة | Driving Licence</h5>
								
								<!-- Driving Licence Number Field -->
								{#if !savedDrivingLicenceNumber}
									<!-- Show input when no number is saved -->
									<div class="form-group-compact">
										<label for="driving-licence-number">Licence Number</label>
										<input 
											type="text" 
											id="driving-licence-number" 
											bind:value={drivingLicenceNumber}
											placeholder="Enter driving licence number"
										/>
									</div>
									<button class="save-button-small" on:click={saveDrivingLicenceNumber}>
										💾 Save Number
									</button>
								{:else}
									<!-- Show saved number info -->
									<div class="saved-date-info">
										<div class="saved-date-display">
											<span class="date-label">Licence Number:</span>
											<span class="date-value">{savedDrivingLicenceNumber}</span>
										</div>
									</div>
									
									<!-- Edit number input (hidden by default) -->
									{#if drivingLicenceNumber !== savedDrivingLicenceNumber}
										<div class="form-group-compact">
											<label for="driving-licence-number-edit">Change Licence Number</label>
											<input 
												type="text" 
												id="driving-licence-number-edit" 
												bind:value={drivingLicenceNumber}
												placeholder="Enter driving licence number"
											/>
										</div>
										<button class="save-button-small" on:click={saveDrivingLicenceNumber}>
											💾 Update Number
										</button>
									{:else}
										<button class="update-button" on:click={() => drivingLicenceNumber = ''}>
											✏️ Edit Number
										</button>
									{/if}
								{/if}
								
								<!-- Expiry Date Field -->
								{#if !savedDrivingLicenceExpiryDate}
									<!-- Show input when no date is saved -->
									<div class="form-group-compact">
										<label for="driving-expiry">Expiry Date</label>
										<input 
											type="date" 
											id="driving-expiry" 
											bind:value={drivingLicenceExpiryDate}
											on:change={calculateDrivingLicenceDaysUntilExpiry}
										/>
									</div>
									<button class="save-button-small" on:click={saveDrivingLicenceExpiryDate}>
										💾 Save Date
									</button>
								{:else}
									<!-- Show saved date info when saved -->
									<div class="saved-date-info">
										<div class="saved-date-display">
											<span class="date-label">Saved:</span>
											<span class="date-value">
												{savedDrivingLicenceExpiryDate ? new Date(savedDrivingLicenceExpiryDate).toLocaleDateString('en-GB') : '-'}
											</span>
										</div>
										{#if drivingLicenceDaysUntilExpiry > 0}
											<span class="expiry-valid">⏰ {drivingLicenceDaysUntilExpiry} days remaining</span>
										{:else if drivingLicenceDaysUntilExpiry === 0}
											<span class="expiry-warning">⚠️ Expires today!</span>
										{:else}
											<span class="expiry-expired">❌ Expired {Math.abs(drivingLicenceDaysUntilExpiry)} days ago</span>
										{/if}
									</div>
									
									<!-- Edit date input (hidden by default) -->
									{#if drivingLicenceExpiryDate !== savedDrivingLicenceExpiryDate}
										<div class="form-group-compact">
											<label for="driving-expiry">Change Expiry Date</label>
											<input 
												type="date" 
												id="driving-expiry" 
												bind:value={drivingLicenceExpiryDate}
												on:change={calculateDrivingLicenceDaysUntilExpiry}
											/>
										</div>
										<button class="save-button-small" on:click={saveDrivingLicenceExpiryDate}>
											💾 Save Date
										</button>
									{:else}
										<button class="update-button" on:click={() => drivingLicenceExpiryDate = ''}>
											✏️ Update Date
										</button>
									{/if}
								{/if}

								<!-- File Upload -->
								<div class="file-upload-group">
									<label for="driving-document">Upload Document</label>
									{#if selectedEmployee?.driving_licence_document_url}
										<!-- Document already uploaded -->
										<button class="view-button" on:click={viewDrivingLicenceDocument}>
											👁️ View Document
										</button>
										{#if !drivingLicenceFile}
											<button class="update-button" on:click={() => drivingLicenceFile = {} as any}>
												✏️ Update Document
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
												{isUploadingDrivingLicence ? '⏳ Uploading...' : '📤 Upload'}
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
											{isUploadingDrivingLicence ? '⏳ Uploading...' : '📤 Upload'}
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
								<h5>العقد | Contract</h5>
								
								<!-- Expiry Date Field -->
								{#if !savedContractExpiryDate}
									<!-- Show input when no date is saved -->
									<div class="form-group-compact">
										<label for="contract-expiry">Expiry Date</label>
										<input 
											type="date" 
											id="contract-expiry" 
											bind:value={contractExpiryDate}
											on:change={calculateContractDaysUntilExpiry}
										/>
									</div>
									<button class="save-button-small" on:click={saveContractExpiryDate}>
										💾 Save Date
									</button>
								{:else}
									<!-- Show saved date info when saved -->
									<div class="saved-date-info">
										<div class="saved-date-display">
											<span class="date-label">Expiry Date:</span>
											<span class="date-value">
												{savedContractExpiryDate ? new Date(savedContractExpiryDate).toLocaleDateString('en-GB') : '-'}
											</span>
										</div>
										{#if contractDaysUntilExpiry > 0}
											<span class="expiry-valid">⏰ {contractDaysUntilExpiry} days remaining</span>
										{:else if contractDaysUntilExpiry === 0}
											<span class="expiry-warning">⚠️ Expires today!</span>
										{:else}
											<span class="expiry-expired">❌ Expired {Math.abs(contractDaysUntilExpiry)} days ago</span>
										{/if}
									</div>
									
									<!-- Edit date input (hidden by default) -->
									{#if contractExpiryDate !== savedContractExpiryDate}
										<div class="form-group-compact">
											<label for="contract-expiry">Change Expiry Date</label>
											<input 
												type="date" 
												id="contract-expiry" 
												bind:value={contractExpiryDate}
												on:change={calculateContractDaysUntilExpiry}
											/>
										</div>
										<button class="save-button-small" on:click={saveContractExpiryDate}>
											💾 Save Date
										</button>
									{:else}
										<button class="update-button" on:click={() => contractExpiryDate = ''}>
											✏️ Update Date
										</button>
									{/if}
								{/if}

								<!-- File Upload -->
								<div class="file-upload-group">
									<label for="contract-document">Upload Document</label>
									{#if selectedEmployee?.contract_document_url}
										<!-- Document already uploaded -->
										<button class="view-button" on:click={viewContractDocument}>
											👁️ View Document
										</button>
										{#if !contractFile}
											<button class="update-button" on:click={() => contractFile = {} as any}>
												✏️ Update Document
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
												{isUploadingContract ? '⏳ Uploading...' : '📤 Upload'}
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
											{isUploadingContract ? '⏳ Uploading...' : '📤 Upload'}
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
								<h5>معلومات البنك | Bank Information</h5>
								
								<!-- Bank Name Field -->
								{#if !savedBankName}
									<!-- Show dropdown when no bank name is saved -->
									<div class="form-group-compact">
										<label for="bank-name">Bank Name</label>
										<select 
											id="bank-name" 
											bind:value={bankName}
										>
											<option value="">Select Bank</option>
											{#each banks as bank}
												<option value="{bank.name_en}">
													{bank.name_ar} / {bank.name_en}
												</option>
											{/each}
										</select>
									</div>
									<button class="save-button-small" on:click={saveBankName}>
										💾 Save Bank Name
									</button>
								{:else}
									<!-- Show saved bank name info -->
									<div class="saved-date-info">
										<div class="saved-date-display">
											<span class="date-label">Bank Name:</span>
											<span class="date-value">{savedBankName}</span>
										</div>
									</div>
									
									<!-- Edit bank name dropdown (hidden by default) -->
									{#if bankName !== savedBankName}
										<div class="form-group-compact">
											<label for="bank-name-edit">Change Bank Name</label>
											<select 
												id="bank-name-edit" 
												bind:value={bankName}
											>
												<option value="">Select Bank</option>
												{#each banks as bank}
													<option value="{bank.name_en}">
														{bank.name_ar} / {bank.name_en}
													</option>
												{/each}
											</select>
										</div>
										<button class="save-button-small" on:click={saveBankName}>
											💾 Update Bank Name
										</button>
									{:else}
										<button class="update-button" on:click={() => bankName = ''}>
											✏️ Edit Bank Name
										</button>
									{/if}
								{/if}
								
								<!-- IBAN Field -->
								{#if !savedIban}
									<!-- Show input when no IBAN is saved -->
									<div class="form-group-compact">
										<label for="iban">IBAN</label>
										<input 
											type="text" 
											id="iban" 
											bind:value={iban}
											placeholder="Enter IBAN"
										/>
									</div>
									<button class="save-button-small" on:click={saveIban}>
										💾 Save IBAN
									</button>
								{:else}
									<!-- Show saved IBAN info -->
									<div class="saved-date-info">
										<div class="saved-date-display">
											<span class="date-label">IBAN:</span>
											<span class="date-value">{savedIban}</span>
										</div>
									</div>
									
									<!-- Edit IBAN input (hidden by default) -->
									{#if iban !== savedIban}
										<div class="form-group-compact">
											<label for="iban-edit">Change IBAN</label>
											<input 
												type="text" 
												id="iban-edit" 
												bind:value={iban}
												placeholder="Enter IBAN"
											/>
										</div>
										<button class="save-button-small" on:click={saveIban}>
											💾 Update IBAN
										</button>
									{:else}
										<button class="update-button" on:click={() => iban = ''}>
											✏️ Edit IBAN
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
								<h5>التأمين الصحي | Health Insurance</h5>
								
								<!-- Insurance Company Field -->
								{#if !savedInsuranceCompanyId}
									<!-- Show input when no company is saved -->
									<div class="form-group-compact">
										<label for="insurance-company">Insurance Company</label>
										<select 
											id="insurance-company"
											bind:value={selectedInsuranceCompanyId}
										>
											<option value="">Select Company</option>
											{#each insuranceCompanies as company}
												<option value={company.id}>
													{company.name_ar} / {company.name_en}
												</option>
											{/each}
										</select>
										<button class="secondary-button" on:click={() => showCreateInsuranceModal = true}>
											➕ Create Company
										</button>
									</div>
									<button class="save-button-small" on:click={saveInsuranceCompanyId}>
										💾 Save Company
									</button>
								{:else}
									<!-- Show saved company info -->
									<div class="saved-date-info">
										<div class="saved-date-display">
											<span class="date-label">Insurance Company:</span>
											<span class="date-value">
												{insuranceCompanies.find(c => c.id === savedInsuranceCompanyId)?.name_ar || savedInsuranceCompanyId}
											</span>
										</div>
									</div>
									
									<!-- Edit company input (hidden by default) -->
									{#if selectedInsuranceCompanyId !== savedInsuranceCompanyId}
										<div class="form-group-compact">
											<label for="insurance-company-edit">Change Insurance Company</label>
											<select 
												id="insurance-company-edit"
												bind:value={selectedInsuranceCompanyId}
											>
												<option value="">Select Company</option>
												{#each insuranceCompanies as company}
													<option value={company.id}>
														{company.name_ar} / {company.name_en}
													</option>
												{/each}
											</select>
											<button class="secondary-button" on:click={() => showCreateInsuranceModal = true}>
												➕ Create Company
											</button>
										</div>
										<button class="save-button-small" on:click={saveInsuranceCompanyId}>
											💾 Save Company
										</button>
									{:else}
										<button class="update-button" on:click={() => selectedInsuranceCompanyId = ''}>
											✏️ Edit Company
										</button>
									{/if}
								{/if}
								
								<!-- Expiry Date Field -->
								{#if !savedInsuranceExpiryDate}
									<!-- Show input when no date is saved -->
									<div class="form-group-compact">
										<label for="insurance-expiry">Expiry Date</label>
										<input 
											type="date" 
											id="insurance-expiry" 
											bind:value={insuranceExpiryDate}
											on:change={calculateInsuranceDaysUntilExpiry}
										/>
									</div>
									<button class="save-button-small" on:click={saveInsuranceExpiryDate}>
										💾 Save Date
									</button>
								{:else}
									<!-- Show saved date info when saved -->
									<div class="saved-date-info">
										<div class="saved-date-display">
											<span class="date-label">Saved:</span>
											<span class="date-value">
												{savedInsuranceExpiryDate ? new Date(savedInsuranceExpiryDate).toLocaleDateString('en-GB') : '-'}
											</span>
										</div>
										{#if insuranceDaysUntilExpiry > 0}
											<span class="expiry-valid">⏰ {insuranceDaysUntilExpiry} days remaining</span>
										{:else if insuranceDaysUntilExpiry === 0}
											<span class="expiry-warning">⚠️ Expires today!</span>
										{:else}
											<span class="expiry-expired">❌ Expired {Math.abs(insuranceDaysUntilExpiry)} days ago</span>
										{/if}
									</div>
									
									<!-- Edit date input (hidden by default) -->
									{#if insuranceExpiryDate !== savedInsuranceExpiryDate}
										<div class="form-group-compact">
											<label for="insurance-expiry">Change Expiry Date</label>
											<input 
												type="date" 
												id="insurance-expiry" 
												bind:value={insuranceExpiryDate}
												on:change={calculateInsuranceDaysUntilExpiry}
											/>
										</div>
										<button class="save-button-small" on:click={saveInsuranceExpiryDate}>
											💾 Save Date
										</button>
									{:else}
										<button class="update-button" on:click={() => insuranceExpiryDate = ''}>
											✏️ Update Date
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
								<h5>المعلومات الشخصية | Personal Information</h5>
								
								<!-- Date of Birth Field -->
								{#if !savedDateOfBirth}
									<!-- Show input when no date is saved -->
									<div class="form-group-compact">
										<label for="date-of-birth">Date of Birth</label>
										<input 
											type="date" 
											id="date-of-birth" 
											bind:value={dateOfBirth}
											on:change={calculateAge}
										/>
									</div>
									<button class="save-button-small" on:click={saveDateOfBirth}>
										💾 Save DOB
									</button>
								{:else}
									<!-- Show saved date info when saved -->
									<div class="saved-date-info">
										<div class="saved-date-display">
											<span class="date-label">Date of Birth:</span>
											<span class="date-value">
												{savedDateOfBirth ? new Date(savedDateOfBirth).toLocaleDateString('en-GB') : '-'}
											</span>
										</div>
										<span class="age-display">🎂 Age: <strong>{age} years</strong></span>
									</div>
									
									<!-- Edit date input (hidden by default) -->
									{#if dateOfBirth !== savedDateOfBirth}
										<div class="form-group-compact">
											<label for="date-of-birth">Change Date of Birth</label>
											<input 
												type="date" 
												id="date-of-birth" 
												bind:value={dateOfBirth}
												on:change={calculateAge}
											/>
										</div>
										<button class="save-button-small" on:click={saveDateOfBirth}>
											💾 Save DOB
										</button>
									{:else}
										<button class="update-button" on:click={() => dateOfBirth = ''}>
											✏️ Update DOB
										</button>
									{/if}
								{/if}

								<!-- Join Date Field -->
								{#if !savedJoinDate}
									<!-- Show input when no date is saved -->
									<div class="form-group-compact">
										<label for="join-date">Join Date</label>
										<input 
											type="date" 
											id="join-date" 
											bind:value={joinDate}
										/>
									</div>
									<button class="save-button-small" on:click={saveJoinDate}>
										💾 Save Join Date
									</button>
								{:else}
									<!-- Show saved date info when saved -->
									<div class="saved-date-info">
										<div class="saved-date-display">
											<span class="date-label">Join Date:</span>
											<span class="date-value">
												{savedJoinDate ? new Date(savedJoinDate).toLocaleDateString('en-GB') : '-'}
											</span>
										</div>
									</div>
									
									<!-- Edit date input (hidden by default) -->
									{#if joinDate !== savedJoinDate}
										<div class="form-group-compact">
											<label for="join-date">Change Join Date</label>
											<input 
												type="date" 
												id="join-date" 
												bind:value={joinDate}
											/>
										</div>
										<button class="save-button-small" on:click={saveJoinDate}>
											💾 Save Join Date
										</button>
									{:else}
										<button class="update-button" on:click={() => joinDate = ''}>
											✏️ Update Join Date
										</button>
									{/if}
								{/if}
							</div>
						</div>
					</div>

				<!-- End of file cards grid -->
				</div>
			{:else}
				<div class="placeholder">
					<p>Select an employee to view files</p>
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
				<h3>Create Insurance Company</h3>
				<button class="close-button" on:click={() => showCreateInsuranceModal = false}>✕</button>
			</div>
			<div class="modal-body">
				<div class="form-group-compact">
					<label for="company-name-en">Company Name (English)</label>
					<input 
						type="text" 
						id="company-name-en" 
						bind:value={newInsuranceCompanyNameEn}
						placeholder="Enter company name in English"
					/>
				</div>
				<div class="form-group-compact">
					<label for="company-name-ar">اسم الشركة (عربي)</label>
					<input 
						type="text" 
						id="company-name-ar" 
						bind:value={newInsuranceCompanyNameAr}
						placeholder="أدخل اسم الشركة بالعربية"
					/>
				</div>
			</div>
			<div class="modal-footer">
				<button class="cancel-button" on:click={() => showCreateInsuranceModal = false}>
					Cancel
				</button>
				<button class="save-button" on:click={createInsuranceCompany} disabled={isCreatingInsuranceCompany}>
					{isCreatingInsuranceCompany ? '⏳ Creating...' : '✅ Create'}
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
		background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
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
		background: #f8f9ff;
		border-radius: 6px;
		border-left: 3px solid #667eea;
		margin-bottom: 1.5rem;
	}

	.nationality-section h4 {
		margin: 0 0 1rem 0;
		font-size: 0.95rem;
		color: #333;
	}

	.save-button {
		padding: 0.75rem 1.5rem;
		background: #667eea;
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
		background: #5568d3;
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
	}

	.form-group select:focus,
	.form-group input:focus {
		outline: none;
		border-color: #667eea;
		box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
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
		background-color: #f8f9ff;
	}

	.employee-item.selected {
		background-color: #e8ecff;
		border-left: 3px solid #667eea;
	}

	.employee-item:last-child {
		border-bottom: none;
	}

	.emp-id {
		font-weight: 500;
		color: #667eea;
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
		direction: rtl;
		text-align: right;
		font-size: 0.95rem;
	}

	.emp-name-en,
	.emp-position-en {
		color: #666;
		font-size: 0.85rem;
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
		background: #f8f9ff;
		padding: 1rem;
		border-radius: 6px;
		border-left: 3px solid #667eea;
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
		color: #667eea;
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
		border-color: #667eea;
		box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
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
		border-color: #667eea;
		box-shadow: 0 2px 8px rgba(102, 126, 234, 0.15);
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
		background: #f8f9ff;
		border: 2px solid #667eea !important;
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
		border-color: #667eea;
		box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
	}

	.saved-nationality {
		padding: 0.75rem;
		background: #e8ecff;
		border: 1px solid #667eea;
		border-radius: 4px;
		text-align: center;
	}

	.nationality-display {
		font-size: 0.9rem;
		font-weight: 500;
		color: #667eea;
	}

	.sponsorship-toggle {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
		padding: 0.75rem;
		background: #f8f9ff;
		border-radius: 4px;
		border: 1px solid #e0e0f0;
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
		background-color: #667eea;
	}

	.toggle-input:checked + .toggle-slider:before {
		transform: translateX(20px);
	}

	.toggle-status {
		font-size: 0.8rem;
		font-weight: 600;
		color: #667eea;
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

	.expiry-info {
		padding: 0.5rem;
		border-radius: 4px;
		font-size: 0.85rem;
		text-align: center;
	}

	.expiry-valid {
		color: #22c55e;
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
		background: #667eea;
		color: white;
		border: none;
		border-radius: 4px;
		cursor: pointer;
		font-size: 0.8rem;
		font-weight: 500;
		transition: background-color 0.2s;
	}

	.update-button:hover {
		background: #5568d3;
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
		font-size: 0.75rem;
		color: #3b82f6;
		font-weight: 600;
		margin-top: 0.25rem;
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
</style>
