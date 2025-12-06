
<script lang="ts">
  import StepIndicator from './StepIndicator.svelte';
  import ClearanceCertificateManager from './ClearanceCertificateManager.svelte';
  import { currentUser } from '$lib/utils/persistentAuth';
  import { supabase } from '$lib/utils/supabase';
  import { windowManager } from '$lib/stores/windowManager';
import { openWindow } from '$lib/utils/windowManagerUtils';
  import EditVendor from '$lib/components/desktop-interface/master/vendor/EditVendor.svelte';
  import { onMount } from 'svelte';
  
  let steps = ['Select Branch', 'Select Vendor', 'Bill Information', 'Finalization'];
  let currentStep = 0;
  let allRequiredUsersSelected = false; // Track if all required users are selected
  
  // Clearance Certification state
  let showCertification = false;
  let showCertificateManager = false;
  let currentReceivingRecord = null;
  let savedReceivingId = null; // Track the saved receiving record ID
  
  // Branch selection state
  let branches = [];
  let selectedBranch = '';
  let selectedBranchName = '';
  let showBranchSelector = true;
  let setAsDefaultBranch = false;
  let isLoading = false;
  let errorMessage = '';
  let branchManagers = []; // All users from selected branch
  let actualBranchManagers = []; // Only users with "Branch Manager" position
  let filteredBranchManagers = [];
  let selectedBranchManager = null;
  let branchManagersLoading = false;
  let branchManagerSearchQuery = '';
  let receivingUser = null; // Current logged-in user (auto-selected)
  let showAllUsers = false; // Flag to show all users when no branch manager found

  // Shelf Stocker selection state
  let shelfStockers = []; // All users from selected branch
  let actualShelfStockers = []; // Only users with "Shelf Stocker" position
  let filteredShelfStockers = [];
  let selectedShelfStocker = null; // Single selection
  let shelfStockersLoading = false;
  let shelfStockerSearchQuery = '';
  let showAllUsersForShelfStockers = false; // Flag to show all users when no shelf stockers found

  // Accountant selection state
  let accountants = []; // All users from selected branch
  let actualAccountants = []; // Only users with "Accountant" position
  let filteredAccountants = [];
  let selectedAccountant = null; // Single selection
  let accountantsLoading = false;
  let accountantSearchQuery = '';
  let showAllUsersForAccountant = false; // Flag to show all users when no accountant found

  // Purchasing Manager selection state
  let purchasingManagers = []; // All users from selected branch
  let actualPurchasingManagers = []; // Only users with "Purchasing Manager" position
  let filteredPurchasingManagers = [];
  let selectedPurchasingManager = null; // Single selection
  let purchasingManagersLoading = false;
  let purchasingManagerSearchQuery = '';
  let showAllUsersForPurchasingManager = false; // Flag to show all users when no purchasing manager found

  // Inventory Manager selection state
  let inventoryManagers = []; // All users from selected branch
  let actualInventoryManagers = []; // Only users with "Inventory Manager" position
  let filteredInventoryManagers = [];
  let selectedInventoryManager = null; // Single selection
  let inventoryManagersLoading = false;
  let inventoryManagerSearchQuery = '';
  let showAllUsersForInventoryManager = false; // Flag to show all users when no inventory manager found

  // Night Supervisors selection state
  let nightSupervisors = []; // All users from selected branch
  let actualNightSupervisors = []; // Only users with "Night Supervisor" position
  let filteredNightSupervisors = [];
  let selectedNightSupervisors = []; // Multiple selection
  let nightSupervisorsLoading = false;
  let nightSupervisorSearchQuery = '';
  let showAllUsersForNightSupervisors = false; // Flag to show all users when no night supervisors found

  // Warehouse & Stock Handlers selection state
  let warehouseHandlers = []; // All users from selected branch
  let actualWarehouseHandlers = []; // Only users with "Warehouse" or "Stock Handler" position
  let filteredWarehouseHandlers = [];
  let selectedWarehouseHandler = null; // Single selection
  let warehouseHandlersLoading = false;
  let warehouseHandlerSearchQuery = '';
  let showAllUsersForWarehouseHandlers = false; // Flag to show all users when no warehouse handlers found

  // Vendor selection state
  let vendors = [];
  let filteredVendors = [];
  let searchQuery = '';
  let selectedVendor = null;
  let vendorLoading = false;
  let vendorError = '';

  // Vendor update popup state
  let showVendorUpdatePopup = false;
  let vendorToUpdate = null;
  let updatedSalesmanName = '';
  let updatedSalesmanContact = '';
  let updatedVatNumber = '';
  let isUpdatingVendor = false;

  // Date information for Step 3
  let currentDateTime = '';
  let billDate = '';
  let billAmount = '';
  let billNumber = '';

  // Payment information (from vendor, can be changed for this receiving)
  let paymentMethod = '';
  let creditPeriod = '';
  let bankName = '';
  let iban = '';
  let paymentChanged = false;
  let paymentUpdateChoice = ''; // 'vendor' or 'receiving'
  let dueDate = ''; // Calculated from bill date + credit period

  // VAT verification information
  let vendorVatNumber = ''; // VAT number from vendor record
  let billVatNumber = ''; // VAT number entered from bill
  let vatMismatchReason = ''; // Reason for VAT number mismatch

  // Function to mask VAT number (show only last 4 digits)
  function maskVatNumber(vatNumber) {
    if (!vatNumber || vatNumber.length <= 4) {
      return vatNumber;
    }
    const lastFour = vatNumber.slice(-4);
    const maskedPart = '*'.repeat(vatNumber.length - 4);
    return maskedPart + lastFour;
  }

  // Return processing information with ERP document details for each category
  let returns = {
    expired: { 
      hasReturn: 'no', 
      amount: '',
      erpDocumentType: '',
      erpDocumentNumber: '',
      vendorDocumentNumber: ''
    },
    nearExpiry: { 
      hasReturn: 'no', 
      amount: '',
      erpDocumentType: '',
      erpDocumentNumber: '',
      vendorDocumentNumber: ''
    },
    overStock: { 
      hasReturn: 'no', 
      amount: '',
      erpDocumentType: '',
      erpDocumentNumber: '',
      vendorDocumentNumber: ''
    },
    damage: { 
      hasReturn: 'no', 
      amount: '',
      erpDocumentType: '',
      erpDocumentNumber: '',
      vendorDocumentNumber: ''
    }
  };

  // Column visibility management
  let showColumnSelector = false;
  let visibleColumns = {
    erp_vendor_id: true,
    vendor_name: true,
    salesman_name: true,
    salesman_contact: false,
    supervisor_name: false,
    supervisor_contact: false,
    vendor_contact: true,
    payment_method: true,
    credit_period: false,
    bank_name: false,
    iban: false,
    last_visit: false,
    place: true,
    location: false,
    categories: true,
    delivery_modes: true,
    return_expired: false,
    return_near_expiry: false,
    return_over_stock: false,
    return_damage: false,
    no_return: false,
    vat_status: false,
    vat_number: false,
    status: true,
    actions: true
  };

  // Column definitions
  const columnDefinitions = [
    { key: 'erp_vendor_id', label: 'ERP Vendor ID' },
    { key: 'vendor_name', label: 'Vendor Name' },
    { key: 'salesman_name', label: 'Salesman Name' },
    { key: 'salesman_contact', label: 'Salesman Contact' },
    { key: 'supervisor_name', label: 'Supervisor Name' },
    { key: 'supervisor_contact', label: 'Supervisor Contact' },
    { key: 'vendor_contact', label: 'Vendor Contact' },
    { key: 'payment_method', label: 'Payment Method' },
    { key: 'credit_period', label: 'Credit Period' },
    { key: 'bank_name', label: 'Bank Name' },
    { key: 'iban', label: 'IBAN' },
    { key: 'last_visit', label: 'Last Visit' },
    { key: 'place', label: 'Place' },
    { key: 'location', label: 'Location' },
    { key: 'categories', label: 'Categories' },
    { key: 'delivery_modes', label: 'Delivery Modes' },
    { key: 'return_expired', label: 'Return Expired' },
    { key: 'return_near_expiry', label: 'Return Near Expiry' },
    { key: 'return_over_stock', label: 'Return Over Stock' },
    { key: 'return_damage', label: 'Return Damage' },
    { key: 'no_return', label: 'No Return' },
    { key: 'vat_status', label: 'VAT Status' },
    { key: 'vat_number', label: 'VAT Number' },
    { key: 'status', label: 'Status' },
    { key: 'actions', label: 'Actions' }
  ];

  // Add reactive statement to reload vendors when branch changes
  $: if (selectedBranch && !showBranchSelector) {
    loadVendors();
  }

  // Reactive statement to check if all required users are selected
  // Note: Night Supervisors require at least 1 selection (multiple selection but minimum 1)
  $: allRequiredUsersSelected = selectedBranch && 
    selectedBranchManager && 
    selectedAccountant && 
    selectedPurchasingManager && 
    selectedInventoryManager && 
    selectedShelfStocker && 
    selectedWarehouseHandler &&
    selectedNightSupervisors.length > 0;

  onMount(async () => {
    await loadBranches();
    // Check if user has a default branch
    if ($currentUser?.branch_id) {
      selectedBranch = $currentUser.branch_id;
      selectedBranchName = $currentUser.branchName || '';
      showBranchSelector = false;
      // Stay on step 0 to select branch manager and other positions
      // currentStep = 1; // Don't auto-advance to vendor selection
      await loadVendors();
    }
  });

  async function loadBranches() {
    try {
      isLoading = true;
      errorMessage = '';

      const { data, error } = await supabase
        .from('branches')
        .select('id, name_en, name_ar, location_en')
        .eq('is_active', true)
        .order('name_en');

      if (error) throw error;
      branches = data || [];
      console.log('Loaded branches:', branches);
    } catch (err) {
      errorMessage = 'Failed to load branches: ' + err.message;
      console.error('Error loading branches:', err);
    } finally {
      isLoading = false;
    }
  }

  async function loadVendors() {
    try {
      vendorLoading = true;
      vendorError = '';

      if (!selectedBranch) {
        vendors = [];
        filteredVendors = [];
        vendorLoading = false;
        return;
      }

      // Load vendors filtered by selected branch
      const { data, error } = await supabase
        .from('vendors')
        .select('*')
        .or(`branch_id.eq.${selectedBranch},branch_id.is.null`) // Include vendors for this branch or unassigned vendors
        .eq('status', 'Active')
        .order('vendor_name', { ascending: true })
        .limit(10000); // Increase limit to show all vendors

      if (error) throw error;
      vendors = data || [];
      filteredVendors = vendors;
      
      // Show message if no vendors found for this branch
      if (vendors.length === 0) {
        vendorError = `No vendors assigned to this branch. Please upload vendor data for this branch first.`;
      }
      
    } catch (err) {
      vendorError = 'Failed to load vendors: ' + err.message;
      console.error('Error loading vendors:', err);
    } finally {
      vendorLoading = false;
    }
  }

  async function loadBranchUsers(branchId) {
    try {
      branchManagersLoading = true;
      branchManagers = [];
      actualBranchManagers = [];
      filteredBranchManagers = [];
      selectedBranchManager = null;
      showAllUsers = false;

      // Query to get all active users from the selected branch with their employee info
      const { data: usersData, error: usersError } = await supabase
        .from('users')
        .select(`
          id,
          username,
          status,
          hr_employees!inner(
            id,
            name,
            employee_id
          )
        `)
        .eq('branch_id', branchId)
        .eq('status', 'active')
        .order('username');

      if (usersError) throw usersError;

      // Now get position assignments for these employees
      const employeeUUIDs = usersData?.map(user => user.hr_employees?.id).filter(Boolean) || [];
      
      let positionsData = [];
      if (employeeUUIDs.length > 0) {
        const { data: posData, error: posError } = await supabase
          .from('hr_position_assignments')
          .select(`
            employee_id,
            is_current,
            hr_positions!inner(
              position_title_en,
              position_title_ar
            )
          `)
          .in('employee_id', employeeUUIDs)
          .eq('is_current', true);

        if (posError) {
          console.warn('Error loading positions:', posError);
        } else {
          positionsData = posData || [];
        }
      }

      // Combine the data
      branchManagers = (usersData || []).map(user => {
        const positionAssignment = positionsData.find(pos => pos.employee_id === user.hr_employees?.id);
        return {
          id: user.id,
          username: user.username,
          employeeName: user.hr_employees?.name || 'N/A',
          employeeId: user.hr_employees?.employee_id || 'N/A',
          position: positionAssignment?.hr_positions?.position_title_en || 'No Position Assigned'
        };
      });

      // Filter for actual branch managers
      actualBranchManagers = branchManagers.filter(user => 
        user.position.toLowerCase().includes('branch') && 
        user.position.toLowerCase().includes('manager')
      );

      // If branch managers found, show only them. Otherwise, prepare to show all users
      if (actualBranchManagers.length > 0) {
        filteredBranchManagers = actualBranchManagers;
        showAllUsers = false;
        console.log('Found branch managers:', actualBranchManagers);
      } else {
        filteredBranchManagers = branchManagers;
        showAllUsers = true;
        console.log('No branch managers found, showing all users for selection');
      }

      console.log('Loaded branch users for manager selection:', {
        totalUsers: branchManagers.length,
        branchManagers: actualBranchManagers.length,
        showingAllUsers: showAllUsers
      });
    } catch (err) {
      console.error('Error loading branch users:', err);
      branchManagers = [];
      actualBranchManagers = [];
      filteredBranchManagers = [];
    } finally {
      branchManagersLoading = false;
    }
  }

  // Load shelf stockers for the selected branch
  async function loadShelfStockersForSelection() {
    if (!selectedBranch) return;
    
    try {
      shelfStockersLoading = true;
      shelfStockers = [];
      actualShelfStockers = [];
      filteredShelfStockers = [];
      selectedShelfStocker = null;

      // Get all users for the selected branch
      const { data: usersData, error: usersError } = await supabase
        .from('users')
        .select(`
          id,
          username,
          hr_employees (
            id,
            name,
            employee_id
          )
        `)
        .eq('branch_id', parseInt(selectedBranch))
        .eq('status', 'active');

      if (usersError) {
        console.error('Error loading users:', usersError);
        return;
      }

      // Get position assignments for the branch users using chunked queries
      let positionsData = [];
      if (usersData && usersData.length > 0) {
        const employeeUUIDs = usersData
          .filter(user => user.hr_employees?.id)
          .map(user => user.hr_employees.id);

        // Chunk the UUIDs into smaller batches to avoid URL length limits
        const chunkSize = 25;
        const positionPromises = [];
        
        for (let i = 0; i < employeeUUIDs.length; i += chunkSize) {
          const chunk = employeeUUIDs.slice(i, i + chunkSize);
          const promise = supabase
            .from('hr_position_assignments')
            .select(`
              employee_id,
              hr_positions (
                position_title_en
              )
            `)
            .in('employee_id', chunk)
            .eq('is_current', true);
          positionPromises.push(promise);
        }

        try {
          const results = await Promise.all(positionPromises);
          results.forEach(result => {
            if (result.data) {
              positionsData = positionsData.concat(result.data);
            } else if (result.error) {
              console.warn('Error in position chunk:', result.error);
            }
          });
        } catch (chunkError) {
          console.warn('Error loading positions in chunks:', chunkError);
        }
      }

      // Combine the data
      shelfStockers = (usersData || []).map(user => {
        const positionAssignment = positionsData.find(pos => pos.employee_id === user.hr_employees?.id);
        return {
          id: user.id,
          username: user.username,
          employeeName: user.hr_employees?.name || 'N/A',
          employeeId: user.hr_employees?.employee_id || 'N/A',
          position: positionAssignment?.hr_positions?.position_title_en || 'No Position Assigned'
        };
      });

      // Filter for actual shelf stockers
      actualShelfStockers = shelfStockers.filter(user => 
        user.position.toLowerCase().includes('shelf') && 
        user.position.toLowerCase().includes('stocker')
      );

      // If shelf stockers found, show only them. Otherwise, prepare to show all users
      if (actualShelfStockers.length > 0) {
        filteredShelfStockers = actualShelfStockers;
        showAllUsersForShelfStockers = false;
        console.log('Found shelf stockers:', actualShelfStockers);
      } else {
        filteredShelfStockers = shelfStockers;
        showAllUsersForShelfStockers = true;
        console.log('No shelf stockers found, showing all users for selection');
      }

      console.log('Loaded branch users for shelf stocker selection:', {
        totalUsers: shelfStockers.length,
        shelfStockers: actualShelfStockers.length,
        showingAllUsers: showAllUsersForShelfStockers
      });
    } catch (err) {
      console.error('Error loading shelf stockers:', err);
      shelfStockers = [];
      actualShelfStockers = [];
      filteredShelfStockers = [];
    } finally {
      shelfStockersLoading = false;
    }
  }

  // Load accountants for the selected branch
  async function loadAccountantsForSelection() {
    if (!selectedBranch) return;
    
    try {
      accountantsLoading = true;
      accountants = [];
      actualAccountants = [];
      filteredAccountants = [];
      selectedAccountant = null;

      // Get all users for the selected branch
      const { data: usersData, error: usersError } = await supabase
        .from('users')
        .select(`
          id,
          username,
          hr_employees (
            id,
            name,
            employee_id
          )
        `)
        .eq('branch_id', parseInt(selectedBranch))
        .eq('status', 'active');

      if (usersError) {
        console.error('Error loading users:', usersError);
        return;
      }

      // Get position assignments for the branch users using chunked queries
      let positionsData = [];
      if (usersData && usersData.length > 0) {
        const employeeUUIDs = usersData
          .filter(user => user.hr_employees?.id)
          .map(user => user.hr_employees.id);

        // Chunk the UUIDs into smaller batches to avoid URL length limits
        const chunkSize = 25;
        const positionPromises = [];
        
        for (let i = 0; i < employeeUUIDs.length; i += chunkSize) {
          const chunk = employeeUUIDs.slice(i, i + chunkSize);
          const promise = supabase
            .from('hr_position_assignments')
            .select(`
              employee_id,
              hr_positions (
                position_title_en
              )
            `)
            .in('employee_id', chunk)
            .eq('is_current', true);
          positionPromises.push(promise);
        }

        try {
          const results = await Promise.all(positionPromises);
          results.forEach(result => {
            if (result.data) {
              positionsData = positionsData.concat(result.data);
            } else if (result.error) {
              console.warn('Error in position chunk:', result.error);
            }
          });
        } catch (chunkError) {
          console.warn('Error loading positions in chunks:', chunkError);
        }
      }

      // Combine the data
      accountants = (usersData || []).map(user => {
        const positionAssignment = positionsData.find(pos => pos.employee_id === user.hr_employees?.id);
        return {
          id: user.id,
          username: user.username,
          employeeName: user.hr_employees?.name || 'N/A',
          employeeId: user.hr_employees?.employee_id || 'N/A',
          position: positionAssignment?.hr_positions?.position_title_en || 'No Position Assigned'
        };
      });

      // Filter for actual accountants
      actualAccountants = accountants.filter(user => 
        user.position.toLowerCase().includes('accountant')
      );

      // If accountants found, show only them. Otherwise, prepare to show all users
      if (actualAccountants.length > 0) {
        filteredAccountants = actualAccountants;
        showAllUsersForAccountant = false;
        console.log('Found accountants:', actualAccountants);
      } else {
        filteredAccountants = accountants;
        showAllUsersForAccountant = true;
        console.log('No accountants found, showing all users for selection');
      }

      console.log('Loaded branch users for accountant selection:', {
        totalUsers: accountants.length,
        accountants: actualAccountants.length,
        showingAllUsers: showAllUsersForAccountant
      });
    } catch (err) {
      console.error('Error loading accountants:', err);
      accountants = [];
      actualAccountants = [];
      filteredAccountants = [];
    } finally {
      accountantsLoading = false;
    }
  }

  // Load purchasing managers from ALL branches (not just selected branch)
  async function loadPurchasingManagersForSelection() {
    try {
      purchasingManagersLoading = true;
      purchasingManagers = [];
      actualPurchasingManagers = [];
      filteredPurchasingManagers = [];
      selectedPurchasingManager = null;

      // Get all active users from ALL branches with their branch information
      const { data: usersData, error: usersError } = await supabase
        .from('users')
        .select(`
          id,
          username,
          branch_id,
          branches!inner (
            id,
            name_en
          ),
          hr_employees (
            id,
            name,
            employee_id
          )
        `)
        .eq('status', 'active');

      if (usersError) {
        console.error('Error loading users:', usersError);
        return;
      }

      // Get position assignments for all users using chunked queries to avoid URL length limits
      let positionsData = [];
      if (usersData && usersData.length > 0) {
        const employeeUUIDs = usersData
          .filter(user => user.hr_employees?.id)
          .map(user => user.hr_employees.id);

        // Chunk the UUIDs into smaller batches (max 25 per query to avoid URL length limits)
        const chunkSize = 25;
        const positionPromises = [];
        
        for (let i = 0; i < employeeUUIDs.length; i += chunkSize) {
          const chunk = employeeUUIDs.slice(i, i + chunkSize);
          const promise = supabase
            .from('hr_position_assignments')
            .select(`
              employee_id,
              hr_positions (
                position_title_en
              )
            `)
            .in('employee_id', chunk)
            .eq('is_current', true);
          positionPromises.push(promise);
        }

        try {
          const results = await Promise.all(positionPromises);
          
          // Combine results from all chunks
          results.forEach(result => {
            if (result.data) {
              positionsData = positionsData.concat(result.data);
            } else if (result.error) {
              console.warn('Error in position chunk:', result.error);
            }
          });
        } catch (chunkError) {
          console.warn('Error loading positions in chunks:', chunkError);
        }
      }

      // Combine the data with branch information
      purchasingManagers = (usersData || []).map(user => {
        const positionAssignment = positionsData.find(pos => pos.employee_id === user.hr_employees?.id);
        return {
          id: user.id,
          username: user.username,
          employeeName: user.hr_employees?.name || 'N/A',
          employeeId: user.hr_employees?.employee_id || 'N/A',
          position: positionAssignment?.hr_positions?.position_title_en || 'No Position Assigned',
          branchName: user.branches?.name_en || 'Unknown Branch',
          branchId: user.branch_id
        };
      });

      // Filter for actual purchasing managers from all branches
      actualPurchasingManagers = purchasingManagers.filter(user => 
        user.position.toLowerCase().includes('purchasing') && 
        user.position.toLowerCase().includes('manager')
      );

      // If purchasing managers found, show only them. Otherwise, prepare to show all users
      if (actualPurchasingManagers.length > 0) {
        filteredPurchasingManagers = actualPurchasingManagers;
        showAllUsersForPurchasingManager = false;
        console.log('Found purchasing managers across all branches:', actualPurchasingManagers);
      } else {
        filteredPurchasingManagers = purchasingManagers;
        showAllUsersForPurchasingManager = true;
        console.log('No purchasing managers found, showing all users for selection');
      }

      console.log('Loaded users from all branches for purchasing manager selection:', {
        totalUsers: purchasingManagers.length,
        purchasingManagers: actualPurchasingManagers.length,
        showingAllUsers: showAllUsersForPurchasingManager
      });
    } catch (err) {
      console.error('Error loading purchasing managers:', err);
      purchasingManagers = [];
      actualPurchasingManagers = [];
      filteredPurchasingManagers = [];
    } finally {
      purchasingManagersLoading = false;
    }
  }

  // Load inventory managers for the selected branch
  async function loadInventoryManagersForSelection() {
    if (!selectedBranch) return;
    
    try {
      inventoryManagersLoading = true;
      inventoryManagers = [];
      actualInventoryManagers = [];
      filteredInventoryManagers = [];
      selectedInventoryManager = null;

      // Get all users for the selected branch
      const { data: usersData, error: usersError } = await supabase
        .from('users')
        .select(`
          id,
          username,
          hr_employees (
            id,
            name,
            employee_id
          )
        `)
        .eq('branch_id', parseInt(selectedBranch))
        .eq('status', 'active');

      if (usersError) {
        console.error('Error loading users:', usersError);
        return;
      }

      // Get position assignments for the branch users using chunked queries
      let positionsData = [];
      if (usersData && usersData.length > 0) {
        const employeeUUIDs = usersData
          .filter(user => user.hr_employees?.id)
          .map(user => user.hr_employees.id);

        // Chunk the UUIDs into smaller batches to avoid URL length limits
        const chunkSize = 25;
        const positionPromises = [];
        
        for (let i = 0; i < employeeUUIDs.length; i += chunkSize) {
          const chunk = employeeUUIDs.slice(i, i + chunkSize);
          const promise = supabase
            .from('hr_position_assignments')
            .select(`
              employee_id,
              hr_positions (
                position_title_en
              )
            `)
            .in('employee_id', chunk)
            .eq('is_current', true);
          positionPromises.push(promise);
        }

        try {
          const results = await Promise.all(positionPromises);
          results.forEach(result => {
            if (result.data) {
              positionsData = positionsData.concat(result.data);
            } else if (result.error) {
              console.warn('Error in position chunk:', result.error);
            }
          });
        } catch (chunkError) {
          console.warn('Error loading positions in chunks:', chunkError);
        }
      }

      // Combine the data
      inventoryManagers = (usersData || []).map(user => {
        const positionAssignment = positionsData.find(pos => pos.employee_id === user.hr_employees?.id);
        return {
          id: user.id,
          username: user.username,
          employeeName: user.hr_employees?.name || 'N/A',
          employeeId: user.hr_employees?.employee_id || 'N/A',
          position: positionAssignment?.hr_positions?.position_title_en || 'No Position Assigned'
        };
      });

      // Filter for actual inventory managers
      actualInventoryManagers = inventoryManagers.filter(user => 
        user.position.toLowerCase().includes('inventory') && 
        user.position.toLowerCase().includes('manager')
      );

      // If inventory managers found, show only them. Otherwise, prepare to show all users
      if (actualInventoryManagers.length > 0) {
        filteredInventoryManagers = actualInventoryManagers;
        showAllUsersForInventoryManager = false;
        console.log('Found inventory managers:', actualInventoryManagers);
      } else {
        filteredInventoryManagers = inventoryManagers;
        showAllUsersForInventoryManager = true;
        console.log('No inventory managers found, showing all users for selection');
      }

      console.log('Loaded branch users for inventory manager selection:', {
        totalUsers: inventoryManagers.length,
        inventoryManagers: actualInventoryManagers.length,
        showingAllUsers: showAllUsersForInventoryManager
      });
    } catch (err) {
      console.error('Error loading inventory managers:', err);
      inventoryManagers = [];
      actualInventoryManagers = [];
      filteredInventoryManagers = [];
    } finally {
      inventoryManagersLoading = false;
    }
  }

  // Load night supervisors for the selected branch
  async function loadNightSupervisorsForSelection() {
    if (!selectedBranch) return;
    
    try {
      nightSupervisorsLoading = true;
      nightSupervisors = [];
      actualNightSupervisors = [];
      filteredNightSupervisors = [];
      selectedNightSupervisors = [];

      // Get all users for the selected branch
      const { data: usersData, error: usersError } = await supabase
        .from('users')
        .select(`
          id,
          username,
          hr_employees (
            id,
            name,
            employee_id
          )
        `)
        .eq('branch_id', parseInt(selectedBranch))
        .eq('status', 'active');

      if (usersError) {
        console.error('Error loading users:', usersError);
        return;
      }

      // Get position assignments for the branch users using chunked queries
      let positionsData = [];
      if (usersData && usersData.length > 0) {
        const employeeUUIDs = usersData
          .filter(user => user.hr_employees?.id)
          .map(user => user.hr_employees.id);

        // Chunk the UUIDs into smaller batches to avoid URL length limits
        const chunkSize = 25;
        const positionPromises = [];
        
        for (let i = 0; i < employeeUUIDs.length; i += chunkSize) {
          const chunk = employeeUUIDs.slice(i, i + chunkSize);
          const promise = supabase
            .from('hr_position_assignments')
            .select(`
              employee_id,
              hr_positions (
                position_title_en
              )
            `)
            .in('employee_id', chunk)
            .eq('is_current', true);
          positionPromises.push(promise);
        }

        try {
          const results = await Promise.all(positionPromises);
          results.forEach(result => {
            if (result.data) {
              positionsData = positionsData.concat(result.data);
            } else if (result.error) {
              console.warn('Error in position chunk:', result.error);
            }
          });
        } catch (chunkError) {
          console.warn('Error loading positions in chunks:', chunkError);
        }
      }

      // Combine the data
      nightSupervisors = (usersData || []).map(user => {
        const positionAssignment = positionsData.find(pos => pos.employee_id === user.hr_employees?.id);
        return {
          id: user.id,
          username: user.username,
          employeeName: user.hr_employees?.name || 'N/A',
          employeeId: user.hr_employees?.employee_id || 'N/A',
          position: positionAssignment?.hr_positions?.position_title_en || 'No Position Assigned'
        };
      });

      // Filter for actual night supervisors
      actualNightSupervisors = nightSupervisors.filter(user => 
        user.position.toLowerCase().includes('night') && 
        user.position.toLowerCase().includes('supervisor')
      );

      // If night supervisors found, show only them. Otherwise, prepare to show all users
      if (actualNightSupervisors.length > 0) {
        filteredNightSupervisors = actualNightSupervisors;
        showAllUsersForNightSupervisors = false;
        console.log('Found night supervisors:', actualNightSupervisors);
      } else {
        filteredNightSupervisors = nightSupervisors;
        showAllUsersForNightSupervisors = true;
        console.log('No night supervisors found, showing all users for selection');
      }

      console.log('Loaded branch users for night supervisor selection:', {
        totalUsers: nightSupervisors.length,
        nightSupervisors: actualNightSupervisors.length,
        showingAllUsers: showAllUsersForNightSupervisors
      });
    } catch (err) {
      console.error('Error loading night supervisors:', err);
      nightSupervisors = [];
      actualNightSupervisors = [];
      filteredNightSupervisors = [];
    } finally {
      nightSupervisorsLoading = false;
    }
  }

  // Load warehouse handlers for the selected branch
  async function loadWarehouseHandlersForSelection() {
    if (!selectedBranch) return;
    
    try {
      warehouseHandlersLoading = true;
      warehouseHandlers = [];
      actualWarehouseHandlers = [];
      filteredWarehouseHandlers = [];
      selectedWarehouseHandler = null;

      // Get all users for the selected branch
      const { data: usersData, error: usersError } = await supabase
        .from('users')
        .select(`
          id,
          username,
          hr_employees (
            id,
            name,
            employee_id
          )
        `)
        .eq('branch_id', parseInt(selectedBranch))
        .eq('status', 'active');

      if (usersError) {
        console.error('Error loading users:', usersError);
        return;
      }

      // Get position assignments for the branch users using chunked queries
      let positionsData = [];
      if (usersData && usersData.length > 0) {
        const employeeUUIDs = usersData
          .filter(user => user.hr_employees?.id)
          .map(user => user.hr_employees.id);

        // Chunk the UUIDs into smaller batches to avoid URL length limits
        const chunkSize = 25;
        const positionPromises = [];
        
        for (let i = 0; i < employeeUUIDs.length; i += chunkSize) {
          const chunk = employeeUUIDs.slice(i, i + chunkSize);
          const promise = supabase
            .from('hr_position_assignments')
            .select(`
              employee_id,
              hr_positions (
                position_title_en
              )
            `)
            .in('employee_id', chunk)
            .eq('is_current', true);
          positionPromises.push(promise);
        }

        try {
          const results = await Promise.all(positionPromises);
          results.forEach(result => {
            if (result.data) {
              positionsData = positionsData.concat(result.data);
            } else if (result.error) {
              console.warn('Error in position chunk:', result.error);
            }
          });
        } catch (chunkError) {
          console.warn('Error loading positions in chunks:', chunkError);
        }
      }

      // Combine the data
      warehouseHandlers = (usersData || []).map(user => {
        const positionAssignment = positionsData.find(pos => pos.employee_id === user.hr_employees?.id);
        return {
          id: user.id,
          username: user.username,
          employeeName: user.hr_employees?.name || 'N/A',
          employeeId: user.hr_employees?.employee_id || 'N/A',
          position: positionAssignment?.hr_positions?.position_title_en || 'No Position Assigned'
        };
      });

      // Filter for actual warehouse & stock handlers
      actualWarehouseHandlers = warehouseHandlers.filter(user => 
        (user.position.toLowerCase().includes('warehouse') || 
         user.position.toLowerCase().includes('stock') && user.position.toLowerCase().includes('handler'))
      );

      // If warehouse handlers found, show only them. Otherwise, prepare to show all users
      if (actualWarehouseHandlers.length > 0) {
        filteredWarehouseHandlers = actualWarehouseHandlers;
        showAllUsersForWarehouseHandlers = false;
        console.log('Found warehouse handlers:', actualWarehouseHandlers);
      } else {
        filteredWarehouseHandlers = warehouseHandlers;
        showAllUsersForWarehouseHandlers = true;
        console.log('No warehouse handlers found, showing all users for selection');
      }

      console.log('Loaded branch users for warehouse handler selection:', {
        totalUsers: warehouseHandlers.length,
        warehouseHandlers: actualWarehouseHandlers.length,
        showingAllUsers: showAllUsersForWarehouseHandlers
      });
    } catch (err) {
      console.error('Error loading warehouse handlers:', err);
      warehouseHandlers = [];
      actualWarehouseHandlers = [];
      filteredWarehouseHandlers = [];
    } finally {
      warehouseHandlersLoading = false;
    }
  }

  // Branch manager search functionality
  function handleBranchUserSearch() {
    const sourceList = showAllUsers ? branchManagers : actualBranchManagers;
    
    if (!branchManagerSearchQuery.trim()) {
      filteredBranchManagers = sourceList;
    } else {
      const query = branchManagerSearchQuery.toLowerCase();
      filteredBranchManagers = sourceList.filter(user => 
        user.username.toLowerCase().includes(query) ||
        user.employeeName.toLowerCase().includes(query) ||
        user.employeeId.toLowerCase().includes(query) ||
        user.position.toLowerCase().includes(query)
      );
    }
  }

  function selectBranchManager(user) {
    selectedBranchManager = user;
    console.log('Selected branch manager:', selectedBranchManager);
  }

  // Function to show all users when no branch manager found
  function showAllUsersForSelection() {
    showAllUsers = true;
    filteredBranchManagers = branchManagers;
    branchManagerSearchQuery = ''; // Reset search
  }

  // Shelf stocker search functionality
  function handleShelfStockerSearch() {
    const sourceList = showAllUsersForShelfStockers ? shelfStockers : actualShelfStockers;
    
    if (!shelfStockerSearchQuery.trim()) {
      filteredShelfStockers = sourceList;
    } else {
      const query = shelfStockerSearchQuery.toLowerCase();
      filteredShelfStockers = sourceList.filter(user => 
        user.username.toLowerCase().includes(query) ||
        user.employeeName.toLowerCase().includes(query) ||
        user.employeeId.toLowerCase().includes(query) ||
        user.position.toLowerCase().includes(query)
      );
    }
  }

  function selectShelfStocker(user) {
    selectedShelfStocker = user;
    console.log('Selected shelf stocker:', selectedShelfStocker);
  }

  function removeShelfStocker() {
    selectedShelfStocker = null;
    console.log('Removed shelf stocker selection');
  }

  // Function to show all users when no shelf stockers found
  function showAllUsersForShelfStockerSelection() {
    showAllUsersForShelfStockers = true;
    filteredShelfStockers = shelfStockers;
    shelfStockerSearchQuery = ''; // Reset search
  }

  // Accountant search functionality
  function handleAccountantSearch() {
    const sourceList = showAllUsersForAccountant ? accountants : actualAccountants;
    
    if (!accountantSearchQuery.trim()) {
      filteredAccountants = sourceList;
    } else {
      const query = accountantSearchQuery.toLowerCase();
      filteredAccountants = sourceList.filter(user => 
        user.username.toLowerCase().includes(query) ||
        user.employeeName.toLowerCase().includes(query) ||
        user.employeeId.toLowerCase().includes(query) ||
        user.position.toLowerCase().includes(query)
      );
    }
  }

  function selectAccountant(user) {
    selectedAccountant = user;
    console.log('Selected accountant:', selectedAccountant);
  }

  // Function to show all users when no accountant found
  function showAllUsersForAccountantSelection() {
    showAllUsersForAccountant = true;
    filteredAccountants = accountants;
    accountantSearchQuery = ''; // Reset search
  }

  // Purchasing manager search functionality
  function handlePurchasingManagerSearch() {
    const sourceList = showAllUsersForPurchasingManager ? purchasingManagers : actualPurchasingManagers;
    
    if (!purchasingManagerSearchQuery.trim()) {
      filteredPurchasingManagers = sourceList;
    } else {
      const query = purchasingManagerSearchQuery.toLowerCase();
      filteredPurchasingManagers = sourceList.filter(user => 
        user.username.toLowerCase().includes(query) ||
        user.employeeName.toLowerCase().includes(query) ||
        user.employeeId.toLowerCase().includes(query) ||
        user.position.toLowerCase().includes(query) ||
        user.branchName.toLowerCase().includes(query)
      );
    }
  }

  function selectPurchasingManager(user) {
    selectedPurchasingManager = user;
    console.log('Selected purchasing manager:', selectedPurchasingManager);
  }

  // Function to show all users when no purchasing manager found
  function showAllUsersForPurchasingManagerSelection() {
    showAllUsersForPurchasingManager = true;
    filteredPurchasingManagers = purchasingManagers;
    purchasingManagerSearchQuery = ''; // Reset search
  }

  // Inventory manager search functionality
  function handleInventoryManagerSearch() {
    const sourceList = showAllUsersForInventoryManager ? inventoryManagers : actualInventoryManagers;
    
    if (!inventoryManagerSearchQuery.trim()) {
      filteredInventoryManagers = sourceList;
    } else {
      const query = inventoryManagerSearchQuery.toLowerCase();
      filteredInventoryManagers = sourceList.filter(user => 
        user.username.toLowerCase().includes(query) ||
        user.employeeName.toLowerCase().includes(query) ||
        user.employeeId.toLowerCase().includes(query) ||
        user.position.toLowerCase().includes(query)
      );
    }
  }

  function selectInventoryManager(user) {
    selectedInventoryManager = user;
    console.log('Selected inventory manager:', selectedInventoryManager);
  }

  function showAllUsersForInventoryManagerSelection() {
    showAllUsersForInventoryManager = true;
    filteredInventoryManagers = inventoryManagers;
    inventoryManagerSearchQuery = ''; // Reset search
  }

  // Night supervisor search functionality
  function handleNightSupervisorSearch() {
    const sourceList = showAllUsersForNightSupervisors ? nightSupervisors : actualNightSupervisors;
    
    if (!nightSupervisorSearchQuery.trim()) {
      filteredNightSupervisors = sourceList;
    } else {
      const query = nightSupervisorSearchQuery.toLowerCase();
      filteredNightSupervisors = sourceList.filter(user => 
        user.username.toLowerCase().includes(query) ||
        user.employeeName.toLowerCase().includes(query) ||
        user.employeeId.toLowerCase().includes(query) ||
        user.position.toLowerCase().includes(query)
      );
    }
  }

  function selectNightSupervisor(user) {
    const isAlreadySelected = selectedNightSupervisors.some(supervisor => supervisor.id === user.id);
    
    if (!isAlreadySelected) {
      selectedNightSupervisors = [...selectedNightSupervisors, user];
      console.log('Selected night supervisors:', selectedNightSupervisors);
    }
  }

  function removeNightSupervisor(userId) {
    selectedNightSupervisors = selectedNightSupervisors.filter(supervisor => supervisor.id !== userId);
    console.log('Updated selected night supervisors:', selectedNightSupervisors);
  }

  function showAllUsersForNightSupervisorSelection() {
    showAllUsersForNightSupervisors = true;
    filteredNightSupervisors = nightSupervisors;
    nightSupervisorSearchQuery = ''; // Reset search
  }

  // Warehouse handler search functionality
  function handleWarehouseHandlerSearch() {
    const sourceList = showAllUsersForWarehouseHandlers ? warehouseHandlers : actualWarehouseHandlers;
    
    if (!warehouseHandlerSearchQuery.trim()) {
      filteredWarehouseHandlers = sourceList;
    } else {
      const query = warehouseHandlerSearchQuery.toLowerCase();
      filteredWarehouseHandlers = sourceList.filter(user => 
        user.username.toLowerCase().includes(query) ||
        user.employeeName.toLowerCase().includes(query) ||
        user.employeeId.toLowerCase().includes(query) ||
        user.position.toLowerCase().includes(query)
      );
    }
  }

  function selectWarehouseHandler(user) {
    selectedWarehouseHandler = user;
    console.log('Selected warehouse handler:', selectedWarehouseHandler);
  }

  function removeWarehouseHandler() {
    selectedWarehouseHandler = null;
    console.log('Removed warehouse handler selection');
  }

  function showAllUsersForWarehouseHandlerSelection() {
    showAllUsersForWarehouseHandlers = true;
    filteredWarehouseHandlers = warehouseHandlers;
    warehouseHandlerSearchQuery = ''; // Reset search
  }

  // Vendor search functionality
  function handleVendorSearch() {
    if (!searchQuery.trim()) {
      filteredVendors = vendors;
    } else {
      const query = searchQuery.toLowerCase();
      filteredVendors = vendors.filter(vendor => 
        vendor.erp_vendor_id.toString().includes(query) ||
        vendor.vendor_name.toLowerCase().includes(query) ||
        (vendor.salesman_name && vendor.salesman_name.toLowerCase().includes(query)) ||
        (vendor.salesman_contact && vendor.salesman_contact.toLowerCase().includes(query)) ||
        (vendor.supervisor_name && vendor.supervisor_name.toLowerCase().includes(query)) ||
        (vendor.supervisor_contact && vendor.supervisor_contact.toLowerCase().includes(query)) ||
        (vendor.vendor_contact_number && vendor.vendor_contact_number.toLowerCase().includes(query)) ||
        (vendor.payment_method && vendor.payment_method.toLowerCase().includes(query)) ||
        (vendor.credit_period && vendor.credit_period.toString().includes(query)) ||
        (vendor.bank_name && vendor.bank_name.toLowerCase().includes(query)) ||
        (vendor.iban && vendor.iban.toLowerCase().includes(query)) ||
        (vendor.last_visit && vendor.last_visit.toLowerCase().includes(query)) ||
        (vendor.place && vendor.place.toLowerCase().includes(query)) ||
        (vendor.location_link && vendor.location_link.toLowerCase().includes(query)) ||
        (vendor.categories && vendor.categories.some(cat => cat.toLowerCase().includes(query))) ||
        (vendor.delivery_modes && vendor.delivery_modes.some(mode => mode.toLowerCase().includes(query))) ||
        (vendor.return_expired_products && vendor.return_expired_products.toLowerCase().includes(query)) ||
        (vendor.return_near_expiry_products && vendor.return_near_expiry_products.toLowerCase().includes(query)) ||
        (vendor.return_over_stock && vendor.return_over_stock.toLowerCase().includes(query)) ||
        (vendor.return_damage_products && vendor.return_damage_products.toLowerCase().includes(query)) ||
        (vendor.vat_applicable && vendor.vat_applicable.toLowerCase().includes(query)) ||
        (vendor.vat_number && vendor.vat_number.toLowerCase().includes(query)) ||
        (vendor.status && vendor.status.toLowerCase().includes(query))
      );
    }
  }

  // Reactive search
  // Reactive statement to update branch name when selectedBranch changes
  $: if (selectedBranch && branches.length > 0) {
    console.log('Reactive update - selectedBranch:', selectedBranch, 'Type:', typeof selectedBranch);
    // Since option values are strings, convert selectedBranch to number for comparison
    const branchId = parseInt(selectedBranch);
    const branch = branches.find(b => b.id === branchId);
    selectedBranchName = branch ? branch.name_en : '';
    console.log('Reactive update - Found branch:', branch, 'selectedBranchName:', selectedBranchName);
    
    // Load branch users for the selected branch
    loadBranchUsers(branchId);
  }

  $: if (branchManagerSearchQuery !== undefined) {
    handleBranchUserSearch();
  }

  $: if (shelfStockerSearchQuery !== undefined) {
    handleShelfStockerSearch();
  }

  $: if (accountantSearchQuery !== undefined) {
    handleAccountantSearch();
  }

  $: if (purchasingManagerSearchQuery !== undefined) {
    handlePurchasingManagerSearch();
  }

  $: if (inventoryManagerSearchQuery !== undefined) {
    handleInventoryManagerSearch();
  }

  $: if (nightSupervisorSearchQuery !== undefined) {
    handleNightSupervisorSearch();
  }

  $: if (warehouseHandlerSearchQuery !== undefined) {
    handleWarehouseHandlerSearch();
  }

  $: if (searchQuery !== undefined) {
    handleVendorSearch();
  }

  // Load shelf stockers when branch manager is selected
  $: if (selectedBranchManager && selectedBranch) {
    loadShelfStockersForSelection();
  }

  // Load accountants when branch manager is selected
  $: if (selectedBranchManager && selectedBranch) {
    loadAccountantsForSelection();
  }

  // Load purchasing managers from all branches when branch manager is selected
  $: if (selectedBranchManager) {
    loadPurchasingManagersForSelection();
  }

  // Load inventory managers when branch manager is selected
  $: if (selectedBranchManager && selectedBranch) {
    loadInventoryManagersForSelection();
  }

  // Load night supervisors when branch manager is selected
  $: if (selectedBranchManager && selectedBranch) {
    loadNightSupervisorsForSelection();
  }

  // Load warehouse handlers when branch manager is selected
  $: if (selectedBranchManager && selectedBranch) {
    loadWarehouseHandlersForSelection();
  }

  // Reactive calculations for return amounts
  $: totalReturnAmount = 
    (returns.expired.hasReturn === 'yes' ? parseFloat(returns.expired.amount || 0) : 0) +
    (returns.nearExpiry.hasReturn === 'yes' ? parseFloat(returns.nearExpiry.amount || 0) : 0) +
    (returns.overStock.hasReturn === 'yes' ? parseFloat(returns.overStock.amount || 0) : 0) +
    (returns.damage.hasReturn === 'yes' ? parseFloat(returns.damage.amount || 0) : 0);

  $: finalBillAmount = parseFloat(billAmount || 0) - totalReturnAmount;

  // Reactive statement to calculate due date based on payment method
  $: if (paymentMethod) {
    if (paymentMethod === 'Cash on Delivery' || paymentMethod === 'Bank on Delivery') {
      // For delivery methods, due date is the same as bill date (payment on delivery)
      dueDate = billDate || '';
    } else if (billDate && creditPeriod && (paymentMethod === 'Cash Credit' || paymentMethod === 'Bank Credit')) {
      // For credit methods, due date is bill date + credit period
      const billDateObj = new Date(billDate);
      const dueDateObj = new Date(billDateObj);
      dueDateObj.setDate(billDateObj.getDate() + parseInt(creditPeriod));
      dueDate = dueDateObj.toISOString().split('T')[0]; // Format as YYYY-MM-DD
    } else {
      dueDate = '';
    }
  } else {
    dueDate = '';
  }

  // Reactive statement to check VAT number match
  $: vatNumbersMatch = vendorVatNumber && billVatNumber ? 
    vendorVatNumber.trim().toLowerCase() === billVatNumber.trim().toLowerCase() : null;

  // Reactive statement to clear fields when payment method changes
  $: if (paymentMethod) {
    // Clear credit period and bank fields for delivery methods
    if (paymentMethod === 'Cash on Delivery' || paymentMethod === 'Bank on Delivery') {
      creditPeriod = '';
      if (paymentMethod === 'Cash on Delivery') {
        bankName = '';
        iban = '';
      }
    }
    // Clear bank fields for cash credit
    else if (paymentMethod === 'Cash Credit') {
      bankName = '';
      iban = '';
    }
  }

  // Reactive statement to populate payment info when vendor is selected
  $: if (selectedVendor && !paymentChanged) {
    paymentMethod = selectedVendor.payment_method || '';
    creditPeriod = selectedVendor.credit_period || '';
    bankName = selectedVendor.bank_name || '';
    iban = selectedVendor.iban || '';
    vendorVatNumber = selectedVendor.vat_number || '';
  }

  function confirmBranchSelection() {
    if (selectedBranch) {
      showBranchSelector = false;
      // Stay on step 0 to select branch manager and other positions
      // currentStep will be updated to 1 when continue button is clicked
      
      // Load vendors for step 2 (but don't go there yet)
      loadVendors();
      
      // TODO: Save as default if checkbox is checked
      if (setAsDefaultBranch) {
        console.log('Would save branch as default:', selectedBranch);
      }
    }
  }

  function changeBranch() {
    showBranchSelector = true;
    currentStep = 0; // Go back to branch selection step
    selectedVendor = null; // Clear vendor selection
    // Clear all position selections
    selectedBranchManager = null;
    selectedPurchasingManager = null;
    selectedInventoryManager = null;
    selectedAccountant = null;
    selectedShelfStocker = null;
    selectedNightSupervisors = [];
    selectedWarehouseHandler = null;
  }

  function selectVendor(vendor) {
    // Check if vendor is missing critical information
    const missingSalesmanName = !vendor.salesman_name || vendor.salesman_name.trim() === '';
    const missingSalesmanContact = !vendor.salesman_contact || vendor.salesman_contact.trim() === '';
    const missingVatNumber = !vendor.vat_number || vendor.vat_number.trim() === '';

    if (missingSalesmanName || missingSalesmanContact || missingVatNumber) {
      // Show popup to update vendor information
      vendorToUpdate = vendor;
      updatedSalesmanName = vendor.salesman_name || '';
      updatedSalesmanContact = vendor.salesman_contact || '';
      updatedVatNumber = vendor.vat_number || '';
      showVendorUpdatePopup = true;
    } else {
      // Vendor has all required information, proceed normally
      selectedVendor = vendor;
      currentStep = 2; // Move to bill information step
    }
  }

  function changeVendor() {
    selectedVendor = null;
    currentStep = 1; // Go back to vendor selection
  }

  // Handle vendor update popup actions
  async function updateVendorInformation() {
    if (!vendorToUpdate) return;

    isUpdatingVendor = true;
    try {
      const updateData = {};
      
      // Only update fields that were changed
      if (updatedSalesmanName !== vendorToUpdate.salesman_name) {
        updateData.salesman_name = updatedSalesmanName.trim();
      }
      if (updatedSalesmanContact !== vendorToUpdate.salesman_contact) {
        updateData.salesman_contact = updatedSalesmanContact.trim();
      }
      if (updatedVatNumber !== vendorToUpdate.vat_number) {
        updateData.vat_number = updatedVatNumber.trim();
      }

      if (Object.keys(updateData).length > 0) {
        const { error } = await supabase
          .from('vendors')
          .update(updateData)
          .eq('erp_vendor_id', vendorToUpdate.erp_vendor_id)
          .eq('branch_id', selectedBranch);

        if (error) {
          console.error('Error updating vendor:', error);
          alert('Failed to update vendor information: ' + error.message);
          return;
        }

        // Update the vendor in the local vendors array
        const vendorIndex = vendors.findIndex(v => 
          v.erp_vendor_id === vendorToUpdate.erp_vendor_id && 
          v.branch_id === selectedBranch
        );
        if (vendorIndex !== -1) {
          vendors[vendorIndex] = { ...vendors[vendorIndex], ...updateData };
          vendors = [...vendors]; // Trigger reactivity
        }

        // Update vendorToUpdate with new values
        vendorToUpdate = { ...vendorToUpdate, ...updateData };
        
        alert('Vendor information updated successfully!');
      }

      // Proceed with vendor selection
      proceedWithVendorSelection();
      
    } catch (error) {
      console.error('Unexpected error updating vendor:', error);
      alert('An unexpected error occurred while updating vendor information.');
    } finally {
      isUpdatingVendor = false;
    }
  }

  function proceedWithVendorSelection() {
    selectedVendor = vendorToUpdate;
    showVendorUpdatePopup = false;
    vendorToUpdate = null;
    currentStep = 2; // Move to bill information step
  }

  function skipVendorUpdate() {
    proceedWithVendorSelection();
  }

  function closeVendorUpdatePopup() {
    showVendorUpdatePopup = false;
    vendorToUpdate = null;
    updatedSalesmanName = '';
    updatedSalesmanContact = '';
    updatedVatNumber = '';
  }

  // Toggle column visibility
  function toggleColumn(columnKey) {
    visibleColumns[columnKey] = !visibleColumns[columnKey];
    visibleColumns = { ...visibleColumns }; // Trigger reactivity
  }

  // Show/hide all columns
  function toggleAllColumns(show) {
    for (let key in visibleColumns) {
      if (key !== 'vendor_name' && key !== 'actions') { // Always keep vendor name and actions
        visibleColumns[key] = show;
      }
    }
    visibleColumns = { ...visibleColumns }; // Trigger reactivity
  }

  // Generate unique window ID for edit vendor
  function generateWindowId() {
    return `edit-vendor-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  }

  // Open edit vendor window
  function openEditWindow(vendor) {
    const windowId = generateWindowId();
    
    openWindow({
      id: windowId,
      title: `Edit Vendor - ${vendor.vendor_name}`,
      component: EditVendor,
      icon: '✏️',
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
        vendor: vendor,
        onSave: async (updatedVendor) => {
          console.log('Vendor updated:', updatedVendor);
          try {
            // Update local vendor data with proper reactivity
            const index = vendors.findIndex(v => v.erp_vendor_id === updatedVendor.erp_vendor_id);
            if (index !== -1) {
              vendors[index] = { ...updatedVendor };
              vendors = [...vendors]; // Trigger reactivity
              console.log('Vendor updated in local array:', vendors[index]);
              handleVendorSearch(); // Refresh filtered data
            } else {
              console.warn('Vendor not found in local array for update');
              // Reload all vendors as fallback
              await loadVendors();
            }
            // Close the edit window
            windowManager.closeWindow(windowId);
            alert('Vendor updated successfully!');
          } catch (error) {
            console.error('Error updating vendor in UI:', error);
            alert('Vendor updated but there was an issue refreshing the display.');
          }
        },
        onCancel: () => {
          // Close the edit window
          windowManager.closeWindow(windowId);
        }
      }
    });
  }

  // Date and Step 3 functions
  function updateCurrentDateTime() {
    const now = new Date();
    currentDateTime = now.toLocaleString('en-US', {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
      hour12: true
    });
  }

  function goBackToVendorSelection() {
    currentStep = 1; // Go back to vendor selection step
    selectedVendor = null;
  }

  function proceedToReceiving() {
    if (!billDate) {
      alert('Please enter the bill date before proceeding.');
      return;
    }
    if (!billAmount || parseFloat(billAmount) <= 0) {
      alert('Please enter a valid bill amount before proceeding.');
      return;
    }
    if ((paymentMethod === 'Cash Credit' || paymentMethod === 'Bank Credit') && !creditPeriod) {
      alert('Please enter credit period for credit payment methods.');
      return;
    }
    if (paymentChanged && !paymentUpdateChoice) {
      alert('Please choose whether to update vendor payment information or save for this receiving only.');
      return;
    }
    if (selectedVendor && selectedVendor.vat_applicable === 'VAT Applicable' && billVatNumber && vatNumbersMatch === false && !vatMismatchReason.trim()) {
      alert('Please provide a reason for the VAT number mismatch before proceeding.');
      return;
    }
    currentStep = 3; // Move to step 4 (finalization)
    console.log('Proceeding to receiving with:', {
      vendor: selectedVendor,
      billDate: billDate,
      billAmount: parseFloat(billAmount),
      billNumber: billNumber,
      paymentMethod: paymentMethod,
      creditPeriod: creditPeriod ? parseInt(creditPeriod) : null,
      dueDate: dueDate,
      bankName: bankName,
      iban: iban,
      paymentChanged: paymentChanged,
      paymentUpdateChoice: paymentUpdateChoice,
      vendorVatNumber: vendorVatNumber,
      billVatNumber: billVatNumber,
      vatNumbersMatch: vatNumbersMatch,
      vatMismatchReason: vatMismatchReason,
      returns: returns,
      totalReturnAmount: totalReturnAmount,
      finalBillAmount: finalBillAmount,
      currentDateTime: currentDateTime
    });
  }

  // Payment update functions
  async function updateVendorPaymentInfo() {
    if (!selectedVendor) return;
    
    try {
      // Prepare update data based on payment method
      let updateData = {
        payment_method: paymentMethod,
        updated_at: new Date().toISOString()
      };

      // Only include credit period if not delivery methods
      if (paymentMethod === 'Cash on Delivery') {
        updateData.credit_period = null;
        updateData.bank_name = null;
        updateData.iban = null;
      } else if (paymentMethod === 'Bank on Delivery') {
        updateData.credit_period = null;
        updateData.bank_name = bankName || null;
        updateData.iban = iban || null;
      } else if (paymentMethod === 'Cash Credit') {
        updateData.credit_period = creditPeriod ? parseInt(creditPeriod) : null;
        updateData.bank_name = null;
        updateData.iban = null;
      } else {
        // Bank Credit
        updateData.credit_period = creditPeriod ? parseInt(creditPeriod) : null;
        updateData.bank_name = bankName || null;
        updateData.iban = iban || null;
      }

      const { error } = await supabase
        .from('vendors')
        .update(updateData)
        .eq('erp_vendor_id', selectedVendor.erp_vendor_id);

      if (error) {
        console.error('Error updating vendor payment info:', error);
        alert('Failed to update vendor payment information: ' + error.message);
        return;
      }

      // Update the selectedVendor object to reflect changes
      selectedVendor = {
        ...selectedVendor,
        ...updateData
      };

      paymentChanged = false;
      paymentUpdateChoice = 'vendor';
      alert('Vendor payment information updated successfully!');
    } catch (err) {
      console.error('Error updating vendor payment info:', err);
      alert('Failed to update vendor payment information: ' + err.message);
    }
  }

  async function updateReceivingOnlyPaymentInfo() {
    // This function just marks that we want to use different payment info for this receiving
    // The actual saving will happen when the receiving record is created
    paymentChanged = false;
    paymentUpdateChoice = 'receiving';
    alert('Payment information will be saved only for this receiving record.');
  }

  // Update current date/time when component mounts and every second
  onMount(() => {
    updateCurrentDateTime();
    // Update every second to show live time
    const interval = setInterval(updateCurrentDateTime, 1000);
    
    // Cleanup interval on component destroy
    return () => clearInterval(interval);
  });

  // Clearance Certification Functions
  async function saveReceivingData() {
    // Validate required fields before saving
    if (!billDate || !billAmount || !billNumber || !billNumber.trim()) {
      const missingFields = [];
      if (!billDate) missingFields.push('Bill Date');
      if (!billAmount) missingFields.push('Bill Amount');
      if (!billNumber || !billNumber.trim()) missingFields.push('Bill Number');
      
      alert(`Please fill in the following required fields:\n• ${missingFields.join('\n• ')}`);
      return;
    }

    // Validate bill amount is greater than 0
    if (parseFloat(billAmount) <= 0) {
      alert('Bill Amount must be greater than 0');
      return;
    }

    try {
      // Prepare receiving record data according to the actual schema
      const receivingData = {
        user_id: $currentUser?.id,
        branch_id: parseInt(selectedBranch, 10), // Convert string to integer
        vendor_id: selectedVendor?.erp_vendor_id, // Use erp_vendor_id as foreign key
        bill_date: billDate,
        bill_amount: parseFloat(billAmount || 0),
        bill_number: billNumber || null,
        payment_method: paymentMethod || selectedVendor?.payment_method || null,
        credit_period: creditPeriod || selectedVendor?.credit_period || null,
        due_date: dueDate || null, // Use calculated due date
        bank_name: bankName || selectedVendor?.bank_name || null,
        iban: iban || selectedVendor?.iban || null,
        vendor_vat_number: vendorVatNumber || selectedVendor?.vat_number || null,
        bill_vat_number: billVatNumber || null, // Use bill VAT number from form
        vat_numbers_match: vatNumbersMatch, // Use calculated VAT number match
        vat_mismatch_reason: vatMismatchReason || null,
        branch_manager_user_id: selectedBranchManager?.id || null,
        accountant_user_id: selectedAccountant?.id || null,
        purchasing_manager_user_id: selectedPurchasingManager?.id || null,
        shelf_stocker_user_ids: selectedShelfStocker ? [selectedShelfStocker.id] : [],
        // New fields from migration 68
        inventory_manager_user_id: selectedInventoryManager?.id || null,
        night_supervisor_user_ids: selectedNightSupervisors?.map(s => s.id) || [],
        warehouse_handler_user_ids: selectedWarehouseHandler ? [selectedWarehouseHandler.id] : [],
        expired_return_amount: returns.expired.hasReturn === 'yes' ? parseFloat(returns.expired.amount || '0') : 0,
        near_expiry_return_amount: returns.nearExpiry.hasReturn === 'yes' ? parseFloat(returns.nearExpiry.amount || '0') : 0,
        over_stock_return_amount: returns.overStock.hasReturn === 'yes' ? parseFloat(returns.overStock.amount || '0') : 0,
        damage_return_amount: returns.damage.hasReturn === 'yes' ? parseFloat(returns.damage.amount || '0') : 0,
        has_expired_returns: returns.expired.hasReturn === 'yes',
        has_near_expiry_returns: returns.nearExpiry.hasReturn === 'yes',
        has_over_stock_returns: returns.overStock.hasReturn === 'yes',
        has_damage_returns: returns.damage.hasReturn === 'yes',
        // ERP document information
        expired_erp_document_type: returns.expired.hasReturn === 'yes' ? returns.expired.erpDocumentType : null,
        expired_erp_document_number: returns.expired.hasReturn === 'yes' ? returns.expired.erpDocumentNumber : null,
        expired_vendor_document_number: returns.expired.hasReturn === 'yes' ? returns.expired.vendorDocumentNumber : null,
        near_expiry_erp_document_type: returns.nearExpiry.hasReturn === 'yes' ? returns.nearExpiry.erpDocumentType : null,
        near_expiry_erp_document_number: returns.nearExpiry.hasReturn === 'yes' ? returns.nearExpiry.erpDocumentNumber : null,
        near_expiry_vendor_document_number: returns.nearExpiry.hasReturn === 'yes' ? returns.nearExpiry.vendorDocumentNumber : null,
        over_stock_erp_document_type: returns.overStock.hasReturn === 'yes' ? returns.overStock.erpDocumentType : null,
        over_stock_erp_document_number: returns.overStock.hasReturn === 'yes' ? returns.overStock.erpDocumentNumber : null,
        over_stock_vendor_document_number: returns.overStock.hasReturn === 'yes' ? returns.overStock.vendorDocumentNumber : null,
        damage_erp_document_type: returns.damage.hasReturn === 'yes' ? returns.damage.erpDocumentType : null,
        damage_erp_document_number: returns.damage.hasReturn === 'yes' ? returns.damage.erpDocumentNumber : null,
        damage_vendor_document_number: returns.damage.hasReturn === 'yes' ? returns.damage.vendorDocumentNumber : null
      };

      // Check for duplicate bills before saving
      console.log('Checking for duplicate bills...');
      const { data: existingRecords, error: duplicateError } = await supabase
        .from('receiving_records')
        .select('id, bill_number, bill_amount, created_at')
        .eq('vendor_id', selectedVendor?.erp_vendor_id)
        .eq('branch_id', selectedBranch)
        .eq('bill_amount', parseFloat(billAmount))
        .eq('bill_number', billNumber.trim());

      if (duplicateError) {
        console.error('Error checking for duplicates:', duplicateError);
        alert('Error checking for duplicate bills: ' + duplicateError.message);
        return;
      }

      if (existingRecords && existingRecords.length > 0) {
        const duplicateRecord = existingRecords[0];
        const duplicateDate = new Date(duplicateRecord.created_at).toLocaleDateString();
        
        alert(
          `❌ Bill Already Recorded!\n\n` +
          `This bill has already been recorded:\n` +
          `• Bill Number: ${duplicateRecord.bill_number}\n` +
          `• Bill Amount: SAR ${duplicateRecord.bill_amount}\n` +
          `• Vendor: ${selectedVendor?.vendor_name}\n` +
          `• Branch: ${selectedBranchName}\n` +
          `• Previously recorded on: ${duplicateDate}\n\n` +
          `Please check the bill details and ensure this is not a duplicate entry.`
        );
        
        console.log('Duplicate bill found:', duplicateRecord);
        return; // Don't save the duplicate
      }

      console.log('No duplicate found, proceeding with save...');
      
      // DEBUG: Log the data being sent
      console.log('📊 receivingData being sent:', JSON.stringify(receivingData, null, 2));
      console.log('User ID:', receivingData.user_id);
      console.log('Branch ID:', receivingData.branch_id);
      console.log('Vendor ID:', receivingData.vendor_id);
      console.log('Bill Date:', receivingData.bill_date);
      console.log('Bill Amount:', receivingData.bill_amount);

      // Save to receiving_records table - don't select anything back to avoid permission issues
      const { data, error } = await supabase
        .from('receiving_records')
        .insert([receivingData]);

      if (error) {
        console.error('Error saving receiving record:', error);
        alert('Error saving receiving data: ' + error.message);
        return;
      }

      console.log('Receiving record saved (no data returned due to permission checks)');
      // Note: data will be null since we didn't use .select(), but the INSERT succeeded if no error
      // We'll need to fetch the ID from the database if needed
      
      // Fetch the ID of the newly created record by querying the most recent one for this user/vendor/bill
      const { data: fetchedData, error: fetchError } = await supabase
        .from('receiving_records')
        .select('id')
        .eq('user_id', $currentUser?.id)
        .eq('vendor_id', selectedVendor?.erp_vendor_id)
        .eq('bill_date', receivingData.bill_date)
        .eq('bill_amount', receivingData.bill_amount)
        .order('created_at', { ascending: false })
        .limit(1);

      if (fetchError) {
        console.error('Error fetching receiving record ID:', fetchError);
        alert('Record saved but could not retrieve ID. Please refresh and try again.');
        return;
      }

      if (fetchedData && fetchedData.length > 0) {
        savedReceivingId = fetchedData[0].id;
        console.log('Retrieved saved receiving record ID:', savedReceivingId);
      } else {
        console.error('Could not find the newly created receiving record');
        alert('Record saved but ID could not be retrieved.');
        return;
      }
      
      // Check if payment method differs from vendor's default and ask to update vendor table
      const paymentMethodChanged = paymentMethod && selectedVendor?.payment_method && 
                                   paymentMethod !== selectedVendor.payment_method;
      const bankNameChanged = bankName && selectedVendor?.bank_name && 
                              bankName !== selectedVendor.bank_name;
      const ibanChanged = iban && selectedVendor?.iban && 
                          iban !== selectedVendor.iban;

      if (paymentMethodChanged || bankNameChanged || ibanChanged) {
        const shouldUpdateVendor = confirm(
          `Payment information differs from vendor's default settings:\n\n` +
          (paymentMethodChanged ? `• Payment Method: ${selectedVendor.payment_method} → ${paymentMethod}\n` : '') +
          (bankNameChanged ? `• Bank Name: ${selectedVendor.bank_name} → ${bankName}\n` : '') +
          (ibanChanged ? `• IBAN: ${selectedVendor.iban} → ${iban}\n` : '') +
          `\nWould you like to update the vendor table with these new payment details?`
        );

        if (shouldUpdateVendor) {
          try {
            const vendorUpdateData = {};
            if (paymentMethodChanged) vendorUpdateData.payment_method = paymentMethod;
            if (bankNameChanged) vendorUpdateData.bank_name = bankName;
            if (ibanChanged) vendorUpdateData.iban = iban;

            const { error: vendorError } = await supabase
              .from('vendors')
              .update(vendorUpdateData)
              .eq('erp_vendor_id', selectedVendor.erp_vendor_id)
              .eq('branch_id', selectedBranch);

            if (vendorError) {
              console.error('Error updating vendor:', vendorError);
              alert('Failed to update vendor table: ' + vendorError.message);
            } else {
              alert('Vendor table updated successfully with new payment information!');
            }
          } catch (error) {
            console.error('Error updating vendor:', error);
            alert('Error updating vendor: ' + error.message);
          }
        }
      }
      
      // Move to step 4 for certification generation
      currentStep = 3;
      
      alert('Receiving data saved successfully! You can now generate the clearance certification.');

    } catch (error) {
      console.error('Error saving receiving data:', error);
      alert('Error saving receiving data: ' + error.message);
    }
  }

  async function generateClearanceCertification() {
    if (savedReceivingId) {
      // Get the saved receiving record for task generation
      try {
        const { data, error } = await supabase
          .from('receiving_records')
          .select('*')
          .eq('id', savedReceivingId)
          .single();
        
        if (error) throw error;
        
        currentReceivingRecord = data;
        showCertificateManager = true;
      } catch (error) {
        console.error('Error loading receiving record:', error);
        alert('Error loading receiving record: ' + error.message);
      }
    } else {
      alert('Please save the receiving data first before generating clearance certificate.');
    }
  }

  // Certificate saving function - FIXED
  async function saveCertificateAsImage() {
    try {
      if (!savedReceivingId) {
        console.warn('No receiving ID available for certificate generation');
        return;
      }

      // Import html2canvas dynamically
      const { default: html2canvas } = await import('html2canvas');
      
      const certificateElement = document.getElementById('certification-template');
      if (!certificateElement) {
        console.error('Certificate template element not found');
        return;
      }

      console.log('Generating certificate image...');
      
      // Capture the certificate as canvas
      const canvas = await html2canvas(certificateElement, {
        scale: 2, // Higher quality
        useCORS: true,
        allowTaint: true,
        backgroundColor: '#ffffff',
        width: certificateElement.scrollWidth,
        height: certificateElement.scrollHeight
      });

      // Convert canvas to blob  
      const blob = await new Promise(resolve => {
        canvas.toBlob(resolve, 'image/png', 0.95);
      });

      if (!blob) {
        throw new Error('Failed to generate certificate image');
      }

      // Generate filename with simpler format
      const timestamp = new Date().toISOString().replace(/[:.]/g, '-').replace('T', '_').slice(0, 19);
      const fileName = `cert_${savedReceivingId}_${timestamp}.png`;

      console.log('Uploading certificate to storage...', fileName);
      console.log('Blob size:', blob.size, 'bytes');
      console.log('User:', $currentUser?.id);

      // Check blob size (max 10MB as per bucket settings)
      if (blob.size > 10 * 1024 * 1024) {
        throw new Error(`Certificate image too large: ${blob.size} bytes. Max 10MB allowed.`);
      }

      // Convert blob to File object which might work better
      const file = new File([blob], fileName, { type: 'image/png' });
      
      // Upload to Supabase storage
      const { data: uploadData, error: uploadError } = await supabase.storage
        .from('clearance-certificates')
        .upload(fileName, file, {
          contentType: 'image/png',
          upsert: false
        });

      if (uploadError) {
        console.error('Upload error details:', {
          message: uploadError.message,
          error: uploadError,
          fileName,
          fileSize: file.size,
          userId: $currentUser?.id
        });
        
        // Try alternative approach if first fails
        console.log('Trying alternative upload method...');
        const { data: altUploadData, error: altUploadError } = await supabase.storage
          .from('clearance-certificates')
          .upload(fileName, blob, {
            contentType: 'image/png'
          });
        
        if (altUploadError) {
          console.error('Alternative upload also failed:', altUploadError);
          throw new Error(`Failed to upload certificate: ${uploadError.message}`);
        }
        
        console.log('Alternative upload succeeded');
      }

      // Get public URL
      const { data: urlData } = supabase.storage
        .from('clearance-certificates')
        .getPublicUrl(fileName);

      const certificateUrl = urlData.publicUrl;
      console.log('Certificate uploaded successfully:', certificateUrl);

      // Update receiving record with certificate URL
      const { error: updateError } = await supabase
        .from('receiving_records')
        .update({
          certificate_url: certificateUrl,
          certificate_generated_at: new Date().toISOString(),
          certificate_file_name: fileName
        })
        .eq('id', savedReceivingId);

      if (updateError) {
        console.error('Error updating receiving record with certificate URL:', updateError);
        throw updateError;
      }

      console.log('✅ Certificate saved and URL updated in receiving record');
      
    } catch (error) {
      console.error('❌ Error saving certificate as image:', error);
      // Don't show error to user as this is a background process
    }
  }

  // Print function for certificate
  function printCertification() {
    const printContent = document.getElementById('certification-template');
    if (!printContent) return;
    
    // Create a new window for printing instead of modifying current page
    const printWindow = window.open('', '_blank', 'width=800,height=600');
    if (!printWindow) return;
    
    printWindow.document.write(`
      <!DOCTYPE html>
      <html>
      <head>
        <title>Clearance Certificate</title>
        <style>
          * { 
            margin: 0; 
            padding: 0; 
            box-sizing: border-box; 
          }
          
          body { 
            font-family: Arial, sans-serif; 
            background: white; 
            color: black;
            font-size: 10px;
            line-height: 1.3;
          }
          
          .certification-template {
            padding: 8mm;
            background: white;
            font-family: Arial, sans-serif;
            width: 190mm;
            max-width: 190mm;
            height: 277mm;
            margin: 0 auto;
            box-sizing: border-box;
            page-break-inside: avoid;
            font-size: 9px;
            line-height: 1.2;
            overflow: hidden;
          }
          
          .cert-header {
            text-align: center;
            margin-bottom: 8px;
            border-bottom: 2px solid #2c5aa0;
            padding-bottom: 6px;
          }
          
          .cert-logo {
            margin-bottom: 4px;
          }
          
          .cert-logo .logo {
            width: 60px;
            height: 45px;
            margin: 0 auto;
            display: block;
            border: 1px solid #ff6b35;
            border-radius: 3px;
            padding: 3px;
            background: white;
            object-fit: contain;
          }
          
          .cert-title {
            margin-top: 4px;
          }
          
          .title-english {
            color: #2c5aa0;
            margin: 2px 0;
            font-size: 14px;
            font-weight: 700;
            letter-spacing: 0.3px;
            text-transform: uppercase;
          }
          
          .title-arabic {
            color: #2c5aa0;
            margin: 2px 0;
            font-size: 12px;
            font-weight: 700;
            direction: rtl;
            font-family: Arial, sans-serif;
          }
          
          .cert-details {
            margin: 6px 0;
          }
          
          .cert-row {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 2px 0;
            border-bottom: 1px solid #eee;
            min-height: 16px;
          }
          
          .cert-row.final-amount {
            border-bottom: 2px solid #2c5aa0;
            font-weight: 700;
            font-size: 10px;
            color: #2c5aa0;
            background: #f8f9fa;
            padding: 3px;
            margin: 2px 0;
            border-radius: 2px;
          }
          
          .label-group {
            display: flex;
            flex-direction: column;
            min-width: 100px;
          }
          
          .label-english {
            font-weight: 600;
            color: #495057;
            font-size: 8px;
            margin-bottom: 1px;
          }
          
          .label-arabic {
            font-weight: 600;
            color: #6c757d;
            font-size: 7px;
            direction: rtl;
            font-family: Arial, sans-serif;
          }
          
          .cert-row .value {
            color: #212529;
            text-align: right;
            font-weight: 500;
            min-width: 60px;
            font-size: 9px;
          }
          
          .returns-section {
            margin: 4px 0;
            padding: 3px;
            background: #f8f9fa;
            border-radius: 2px;
            border: 1px solid #dee2e6;
          }
          
          .returns-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 3px;
            padding-bottom: 2px;
            border-bottom: 1px solid #dee2e6;
          }
          
          .return-row {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 1px 0;
            font-size: 7px;
            border-bottom: 1px solid #f1f3f4;
          }
          
          .return-row:last-child {
            border-bottom: none;
          }
          
          .return-row.total-returns {
            border-top: 1px solid #dee2e6;
            padding-top: 2px;
            margin-top: 2px;
            font-weight: 600;
            background: #e9ecef;
            padding: 2px;
            border-radius: 2px;
          }
          
          .return-type {
            display: flex;
            flex-direction: column;
            min-width: 80px;
          }
          
          .type-english {
            font-size: 7px;
            color: #495057;
            margin-bottom: 1px;
          }
          
          .type-arabic {
            font-size: 6px;
            color: #6c757d;
            direction: rtl;
            font-family: Arial, sans-serif;
          }
          
          .return-details {
            display: flex;
            gap: 3px;
            align-items: center;
            font-size: 7px;
          }
          
          .status {
            background: #dc3545;
            color: white;
            padding: 1px 2px;
            border-radius: 1px;
            font-size: 6px;
            font-weight: 500;
          }
          
          .status.yes {
            background: #28a745;
          }
          
          .status.no {
            background: #6c757d;
          }
          
          .amount {
            color: #212529;
            font-weight: 500;
            min-width: 25px;
            text-align: right;
            font-size: 7px;
          }
          
          .amount.total {
            font-size: 8px;
            font-weight: 700;
            color: #2c5aa0;
          }
          
          .signatures-section {
            margin-top: 6px;
            display: flex;
            justify-content: space-between;
            gap: 8px;
          }
          
          .signature-box {
            flex: 1;
            text-align: center;
            padding: 4px;
            border: 1px solid #dee2e6;
            border-radius: 2px;
            background: #f8f9fa;
            min-height: 60px;
          }
          
          .signature-line {
            height: 35px;
            border-bottom: 1px solid #495057;
            margin-bottom: 3px;
          }
          
          .signature-labels {
            display: flex;
            flex-direction: column;
            margin-bottom: 2px;
          }
          
          .signature-labels .label-english {
            font-size: 7px;
            color: #495057;
            font-weight: 600;
            margin-bottom: 1px;
          }
          
          .signature-labels .label-arabic {
            font-size: 6px;
            color: #6c757d;
            direction: rtl;
            font-weight: 600;
            font-family: Arial, sans-serif;
          }
          
          .signature-box p {
            color: #212529;
            font-size: 8px;
            font-weight: 500;
            margin-top: 2px;
          }
          
          .cert-footer {
            text-align: center;
            margin-top: 6px;
            padding-top: 4px;
            border-top: 1px solid #dee2e6;
            font-size: 7px;
            color: #6c757d;
            line-height: 1.2;
          }
          
          .footer-english {
            margin-bottom: 2px;
          }
          
          .footer-arabic {
            direction: rtl;
            font-family: Arial, sans-serif;
            margin-bottom: 3px;
          }
          
          .date-stamp {
            display: flex;
            justify-content: space-between;
            margin-top: 4px;
            padding-top: 3px;
            border-top: 1px solid #dee2e6;
            font-size: 7px;
            color: #495057;
          }
          
          .date-arabic {
            direction: rtl;
            font-family: Arial, sans-serif;
          }
          
          @media print { 
            @page {
              size: A4;
              margin: 8mm;
            }
            
            body { 
              margin: 0; 
              font-size: 9px;
            }
            
            .certification-template {
              width: 194mm;
              max-width: 194mm;
              height: 281mm;
              margin: 0;
              padding: 6mm;
              box-shadow: none;
              page-break-inside: avoid;
              font-size: 8px;
              overflow: hidden;
            }
            
            .cert-logo .logo {
              width: 50px;
              height: 38px;
            }
            
            .title-english {
              font-size: 12px;
            }
            
            .title-arabic {
              font-size: 10px;
            }
            
            .cert-row {
              padding: 1px 0;
              min-height: 12px;
            }
            
            .label-english {
              font-size: 7px;
            }
            
            .label-arabic {
              font-size: 6px;
            }
            
            .cert-row .value {
              font-size: 8px;
            }
            
            .return-row {
              padding: 0.5px 0;
              font-size: 6px;
            }
            
            .signature-box {
              min-height: 45px;
              padding: 3px;
            }
            
            .signature-line {
              height: 25px;
            }
            
            .cert-footer {
              font-size: 6px;
            }
            
            .date-stamp {
              font-size: 6px;
            }
          }
        </style>
      </head>
      <body>
        ${printContent.outerHTML}
      </body>
      </html>
    `);
    
    printWindow.document.close();
    printWindow.focus();
    
    // Wait for content to load then print
    setTimeout(() => {
      printWindow.print();
      printWindow.close();
    }, 500);
  }

  async function saveClearanceCertification() {
    try {
      if (!savedReceivingId) {
        alert('No receiving data found. Please go back and save the receiving data first.');
        return;
      }

      // Show the certificate manager instead of the old certification modal
      await generateClearanceCertification();

    } catch (error) {
      console.error('Error opening certificate manager:', error);
      alert('Error opening certificate manager: ' + error.message);
    }
  }
  
  // Handle certificate manager close
  function handleCertificateManagerClose() {
    showCertificateManager = false;
    // Optionally redirect back to main menu or close window
    // windowManager.closeWindow();
  }
</script>
<StepIndicator {steps} {currentStep} />

<!-- Current User Section -->
<div class="user-info-section">
  <h2>Start Receiving Process</h2>
  {#if $currentUser}
    <p class="user-greeting">
      Welcome, <strong>{$currentUser.employeeName || $currentUser.username}</strong>
      {#if $currentUser.branchName}
        <span class="branch-info">({$currentUser.branchName})</span>
      {/if}
    </p>
  {:else}
    <p class="user-greeting">Welcome to the Receiving Process</p>
  {/if}
</div>

<!-- Step 1: Branch Selection Section -->
{#if currentStep === 0}
<div class="form-section">
  <h3>Step 1: Select Branch</h3>
  
  {#if selectedBranch && !showBranchSelector}
    <div class="current-selection">
      <div class="selection-info">
        <span class="label">Selected Branch:</span>
        <span class="value">{selectedBranchName}</span>
      </div>
      <button type="button" on:click={changeBranch} class="change-btn">
        Change Branch
      </button>
    </div>

    <!-- Branch Manager Selection -->
    <div class="branch-users-section">
      <h4>
        {#if showAllUsers}
          Select Responsible User
        {:else}
          Select Branch Manager
        {/if}
      </h4>
      
      {#if selectedBranchManager}
        <div class="selected-user">
          <div class="user-info">
            <span class="user-label">
              {#if showAllUsers}
                Selected Responsible User:
              {:else}
                Selected Branch Manager:
              {/if}
            </span>
            <span class="user-value">{selectedBranchManager.username} - {selectedBranchManager.employeeName}</span>
          </div>
          <button type="button" on:click={() => selectedBranchManager = null} class="change-user-btn">
            Change Selection
          </button>
        </div>
      {:else}
        {#if branchManagersLoading}
          <div class="users-loading">
            <div class="spinner"></div>
            <span>Loading branch users...</span>
          </div>
        {:else if actualBranchManagers.length === 0 && !showAllUsers}
          <!-- No Branch Manager Found - Show Message -->
          <div class="no-manager-found">
            <div class="no-manager-message">
              <span class="warning-icon">⚠️</span>
              <div class="message-content">
                <h5>No Branch Manager Found</h5>
                <p>No user with "Branch Manager" position found for this branch.</p>
                <button type="button" class="select-responsible-btn" on:click={showAllUsersForSelection}>
                  Select Responsible User Instead
                </button>
              </div>
            </div>
          </div>
        {:else if filteredBranchManagers.length === 0}
          <div class="no-users">
            <span class="notice-icon">⚠️</span>
            <span>No active users found for this branch</span>
          </div>
        {:else}
          <!-- Show instructions based on current view -->
          {#if showAllUsers}
            <div class="fallback-notice">
              <span class="info-icon">ℹ️</span>
              <span>No branch manager found. Please select a responsible user from the list below:</span>
            </div>
          {/if}

          <!-- Search Box -->
          <div class="user-search">
            <input 
              type="text" 
              bind:value={branchManagerSearchQuery}
              placeholder="Search by username, employee name, or position..."
              class="search-input"
            />
          </div>

          <!-- Users Table for Branch Manager Selection -->
          <div class="users-table-container">
            <table class="users-table">
              <thead>
                <tr>
                  <th>Username</th>
                  <th>Employee Name</th>
                  <th>Employee ID</th>
                  <th>Position</th>
                  <th>Action</th>
                </tr>
              </thead>
              <tbody>
                {#each filteredBranchManagers as user}
                  <tr class="user-row" class:is-manager={user.position.toLowerCase().includes('branch') && user.position.toLowerCase().includes('manager')}>
                    <td class="username-cell">{user.username}</td>
                    <td class="name-cell">{user.employeeName}</td>
                    <td class="id-cell">{user.employeeId}</td>
                    <td class="position-cell">
                      {user.position}
                      {#if user.position.toLowerCase().includes('branch') && user.position.toLowerCase().includes('manager')}
                        <span class="manager-badge">Branch Manager</span>
                      {/if}
                    </td>
                    <td class="action-cell">
                      <button 
                        type="button" 
                        class="select-user-btn"
                        on:click={() => selectBranchManager(user)}
                      >
                        Select
                      </button>
                    </td>
                  </tr>
                {/each}
              </tbody>
            </table>
            
            {#if filteredBranchManagers.length === 0 && branchManagerSearchQuery}
              <div class="no-search-results">
                <p>No users found matching "{branchManagerSearchQuery}"</p>
              </div>
            {/if}
          </div>
        {/if}
      {/if}
    </div>

    <!-- Purchasing Manager Selection (Single Selection) -->
    {#if selectedBranchManager}
      <div class="purchasing-manager-section">
        <h4>
          {#if showAllUsersForPurchasingManager}
            Select User as Purchasing Manager
          {:else}
            Select Purchasing Manager
          {/if}
        </h4>
        
        {#if selectedPurchasingManager}
          <div class="selected-purchasing-manager">
            <div class="purchasing-manager-info">
              <span class="purchasing-manager-label">
                {#if showAllUsersForPurchasingManager}
                  Selected User as Purchasing Manager:
                {:else}
                  Selected Purchasing Manager:
                {/if}
              </span>
              <span class="purchasing-manager-value">
                {selectedPurchasingManager.username} - {selectedPurchasingManager.employeeName}
                <span class="selected-branch-info">({selectedPurchasingManager.branchName})</span>
                {#if selectedPurchasingManager.position.toLowerCase().includes('purchasing') && selectedPurchasingManager.position.toLowerCase().includes('manager')}
                  <span class="purchasing-manager-badge">Purchasing Manager</span>
                {/if}
              </span>
            </div>
            <button type="button" on:click={() => selectedPurchasingManager = null} class="change-purchasing-manager-btn">
              Change Selection
            </button>
          </div>
        {:else}
          {#if purchasingManagersLoading}
            <div class="purchasing-managers-loading">
              <div class="spinner"></div>
              <span>Loading purchasing managers...</span>
            </div>
          {:else if actualPurchasingManagers.length === 0 && !showAllUsersForPurchasingManager}
            <!-- No Purchasing Manager Found - Show Message -->
            <div class="no-purchasing-manager-found">
              <div class="no-purchasing-manager-message">
                <span class="warning-icon">⚠️</span>
                <div class="message-content">
                  <h5>No Purchasing Manager Found</h5>
                  <p>No users with "Purchasing Manager" position found across all branches. You can select any other user to handle purchasing tasks.</p>
                  <button type="button" class="select-any-user-btn" on:click={showAllUsersForPurchasingManagerSelection}>
                    Select Any User as Purchasing Manager
                  </button>
                </div>
              </div>
            </div>
          {:else if filteredPurchasingManagers.length === 0}
            <div class="no-purchasing-managers">
              <span class="notice-icon">⚠️</span>
              <span>No active users found for purchasing manager selection</span>
            </div>
          {:else}
            <!-- Show instructions based on current view -->
            {#if showAllUsersForPurchasingManager}
              <div class="fallback-notice">
                <span class="info-icon">ℹ️</span>
                <span>No official purchasing manager found across all branches. Please select any user from the list below to handle purchasing tasks:</span>
              </div>
            {/if}

            <!-- Search Box -->
            <div class="purchasing-manager-search">
              <input 
                type="text" 
                bind:value={purchasingManagerSearchQuery}
                placeholder="Search by username, employee name, branch, or position..."
                class="search-input"
              />
            </div>

            <!-- Purchasing Managers Table -->
            <div class="purchasing-managers-table-container">
              <table class="purchasing-managers-table">
                <thead>
                  <tr>
                    <th>Username</th>
                    <th>Employee Name</th>
                    <th>Employee ID</th>
                    <th>Branch</th>
                    <th>Position</th>
                    <th>Action</th>
                  </tr>
                </thead>
                <tbody>
                  {#each filteredPurchasingManagers as user}
                    <tr class="purchasing-manager-row" class:is-purchasing-manager={user.position.toLowerCase().includes('purchasing') && user.position.toLowerCase().includes('manager')}>
                      <td class="username-cell">{user.username}</td>
                      <td class="name-cell">{user.employeeName}</td>
                      <td class="id-cell">{user.employeeId}</td>
                      <td class="branch-cell">
                        <span class="branch-name">{user.branchName}</span>
                        {#if user.branchId == selectedBranch}
                          <span class="current-branch-badge">Current</span>
                        {/if}
                      </td>
                      <td class="position-cell">
                        {user.position}
                        {#if user.position.toLowerCase().includes('purchasing') && user.position.toLowerCase().includes('manager')}
                          <span class="purchasing-manager-badge">Purchasing Manager</span>
                        {/if}
                      </td>
                      <td class="action-cell">
                        <button 
                          type="button" 
                          class="select-purchasing-manager-btn"
                          on:click={() => selectPurchasingManager(user)}
                        >
                          Select
                        </button>
                      </td>
                    </tr>
                  {/each}
                </tbody>
              </table>
              
              {#if filteredPurchasingManagers.length === 0 && purchasingManagerSearchQuery}
                <div class="no-search-results">
                  <p>No users found matching "{purchasingManagerSearchQuery}"</p>
                </div>
              {/if}
            </div>
          {/if}
        {/if}
      </div>
    {/if}

    <!-- Inventory Manager Selection (Single Selection) -->
    {#if selectedBranchManager}
      <div class="inventory-manager-section">
        <h4>
          {#if showAllUsersForInventoryManager}
            Select User as Inventory Manager
          {:else}
            Select Inventory Manager
          {/if}
        </h4>
        
        {#if selectedInventoryManager}
          <div class="selected-inventory-manager">
            <div class="inventory-manager-info">
              <span class="inventory-manager-label">
                {#if showAllUsersForInventoryManager}
                  Selected User as Inventory Manager:
                {:else}
                  Selected Inventory Manager:
                {/if}
              </span>
              <span class="inventory-manager-value">
                {selectedInventoryManager.username} - {selectedInventoryManager.employeeName}
                {#if selectedInventoryManager.position.toLowerCase().includes('inventory') && selectedInventoryManager.position.toLowerCase().includes('manager')}
                  <span class="inventory-manager-badge">Inventory Manager</span>
                {/if}
              </span>
            </div>
            <button type="button" on:click={() => selectedInventoryManager = null} class="change-inventory-manager-btn">
              Change Selection
            </button>
          </div>
        {:else}
          {#if inventoryManagersLoading}
            <div class="inventory-managers-loading">
              <div class="spinner"></div>
              <span>Loading inventory managers...</span>
            </div>
          {:else if actualInventoryManagers.length === 0 && !showAllUsersForInventoryManager}
            <div class="no-inventory-manager-found">
              <div class="no-inventory-manager-message">
                <span class="warning-icon">⚠️</span>
                <div class="message-content">
                  <h5>No Inventory Manager Found</h5>
                  <p>No users with "Inventory Manager" position found for this branch. You can select any other user to handle inventory tasks.</p>
                  <button type="button" class="select-any-user-btn" on:click={showAllUsersForInventoryManagerSelection}>
                    Select Any User as Inventory Manager
                  </button>
                </div>
              </div>
            </div>
          {:else if filteredInventoryManagers.length === 0}
            <div class="no-inventory-managers">
              <span class="notice-icon">⚠️</span>
              <span>No active users found for inventory manager selection</span>
            </div>
          {:else}
            {#if showAllUsersForInventoryManager}
              <div class="fallback-notice">
                <span class="info-icon">ℹ️</span>
                <span>No official inventory manager found. Please select any user from the list below to handle inventory tasks:</span>
              </div>
            {/if}

            <div class="inventory-manager-search">
              <input 
                type="text" 
                bind:value={inventoryManagerSearchQuery}
                placeholder="Search by username, employee name, or position..."
                class="search-input"
              />
            </div>

            <div class="inventory-managers-table-container">
              <table class="inventory-managers-table">
                <thead>
                  <tr>
                    <th>Username</th>
                    <th>Employee Name</th>
                    <th>Employee ID</th>
                    <th>Position</th>
                    <th>Action</th>
                  </tr>
                </thead>
                <tbody>
                  {#each filteredInventoryManagers as user}
                    <tr class="inventory-manager-row" class:is-inventory-manager={user.position.toLowerCase().includes('inventory') && user.position.toLowerCase().includes('manager')}>
                      <td class="username-cell">{user.username}</td>
                      <td class="name-cell">{user.employeeName}</td>
                      <td class="id-cell">{user.employeeId}</td>
                      <td class="position-cell">
                        {user.position}
                        {#if user.position.toLowerCase().includes('inventory') && user.position.toLowerCase().includes('manager')}
                          <span class="inventory-manager-badge">Inventory Manager</span>
                        {/if}
                      </td>
                      <td class="action-cell">
                        <button 
                          type="button" 
                          class="select-inventory-manager-btn"
                          on:click={() => selectInventoryManager(user)}
                        >
                          Select
                        </button>
                      </td>
                    </tr>
                  {/each}
                </tbody>
              </table>
              
              {#if filteredInventoryManagers.length === 0 && inventoryManagerSearchQuery}
                <div class="no-search-results">
                  <p>No users found matching "{inventoryManagerSearchQuery}"</p>
                </div>
              {/if}
            </div>
          {/if}
        {/if}
      </div>
    {/if}

    <!-- Night Supervisors Selection (Multiple Selection) -->
    {#if selectedBranchManager}
      <div class="night-supervisors-section">
        <h4>
          {#if showAllUsersForNightSupervisors}
            Select Users as Night Supervisors (Multiple)
          {:else}
            Select Night Supervisors (Multiple)
          {/if}
        </h4>
        
        {#if selectedNightSupervisors.length > 0}
          <div class="selected-night-supervisors">
            <h5>Selected Night Supervisors ({selectedNightSupervisors.length}):</h5>
            <div class="selected-night-supervisors-list">
              {#each selectedNightSupervisors as supervisor}
                <div class="selected-night-supervisor-item">
                  <span class="night-supervisor-info">
                    {supervisor.username} - {supervisor.employeeName}
                    {#if supervisor.position.toLowerCase().includes('night') && supervisor.position.toLowerCase().includes('supervisor')}
                      <span class="night-supervisor-badge">Night Supervisor</span>
                    {/if}
                  </span>
                  <button 
                    type="button" 
                    class="remove-night-supervisor-btn"
                    on:click={() => removeNightSupervisor(supervisor.id)}
                    title="Remove this night supervisor"
                  >
                    ×
                  </button>
                </div>
              {/each}
            </div>
          </div>
        {/if}
        
        {#if nightSupervisorsLoading}
          <div class="night-supervisors-loading">
            <div class="spinner"></div>
            <span>Loading night supervisors...</span>
          </div>
        {:else if actualNightSupervisors.length === 0 && !showAllUsersForNightSupervisors}
          <div class="no-night-supervisors-found">
            <div class="no-night-supervisors-message">
              <span class="warning-icon">⚠️</span>
              <div class="message-content">
                <h5>No Night Supervisors Found</h5>
                <p>No users with "Night Supervisor" position found for this branch. You can select any other users to help with night supervision.</p>
                <button type="button" class="select-any-user-btn" on:click={showAllUsersForNightSupervisorSelection}>
                  Select Any Users as Night Supervisors
                </button>
              </div>
            </div>
          </div>
        {:else if filteredNightSupervisors.length === 0}
          <div class="no-night-supervisors">
            <span class="notice-icon">⚠️</span>
            <span>No active users found for night supervisor selection</span>
          </div>
        {:else}
          {#if showAllUsersForNightSupervisors}
            <div class="fallback-notice">
              <span class="info-icon">ℹ️</span>
              <span>No official night supervisors found. Please select any users from the list below to help with night supervision:</span>
            </div>
          {/if}

          <div class="night-supervisor-search">
            <input 
              type="text" 
              bind:value={nightSupervisorSearchQuery}
              placeholder="Search by username, employee name, or position..."
              class="search-input"
            />
          </div>

          <div class="night-supervisors-table-container">
            <table class="night-supervisors-table">
              <thead>
                <tr>
                  <th>Username</th>
                  <th>Employee Name</th>
                  <th>Employee ID</th>
                  <th>Position</th>
                  <th>Action</th>
                </tr>
              </thead>
              <tbody>
                {#each filteredNightSupervisors as user}
                  {@const isSelected = selectedNightSupervisors.some(supervisor => supervisor.id === user.id)}
                  <tr class="night-supervisor-row" class:is-night-supervisor={user.position.toLowerCase().includes('night') && user.position.toLowerCase().includes('supervisor')} class:is-selected={isSelected}>
                    <td class="username-cell">{user.username}</td>
                    <td class="name-cell">{user.employeeName}</td>
                    <td class="id-cell">{user.employeeId}</td>
                    <td class="position-cell">
                      {user.position}
                      {#if user.position.toLowerCase().includes('night') && user.position.toLowerCase().includes('supervisor')}
                        <span class="night-supervisor-badge">Night Supervisor</span>
                      {/if}
                    </td>
                    <td class="action-cell">
                      {#if isSelected}
                        <button 
                          type="button" 
                          class="remove-night-supervisor-btn"
                          on:click={() => removeNightSupervisor(user.id)}
                        >
                          Remove
                        </button>
                      {:else}
                        <button 
                          type="button" 
                          class="select-night-supervisor-btn"
                          on:click={() => selectNightSupervisor(user)}
                        >
                          Select
                        </button>
                      {/if}
                    </td>
                  </tr>
                {/each}
              </tbody>
            </table>
            
            {#if filteredNightSupervisors.length === 0 && nightSupervisorSearchQuery}
              <div class="no-search-results">
                <p>No users found matching "{nightSupervisorSearchQuery}"</p>
              </div>
            {/if}
          </div>
        {/if}
      </div>
    {/if}

    <!-- Warehouse & Stock Handlers Selection (Multiple Selection) -->
    {#if selectedBranchManager}
      <div class="warehouse-handlers-section">
        <h4>
          {#if showAllUsersForWarehouseHandlers}
            Select User as Warehouse & Stock Handler
          {:else}
            Select Warehouse & Stock Handler
          {/if}
        </h4>
        
        {#if selectedWarehouseHandler}
          <div class="selected-warehouse-handler">
            <h5>Selected Warehouse & Stock Handler:</h5>
            <div class="selected-warehouse-handler-item">
              <span class="warehouse-handler-info">
                {selectedWarehouseHandler.username} - {selectedWarehouseHandler.employeeName}
                {#if (selectedWarehouseHandler.position.toLowerCase().includes('warehouse') || (selectedWarehouseHandler.position.toLowerCase().includes('stock') && selectedWarehouseHandler.position.toLowerCase().includes('handler')))}
                  <span class="warehouse-handler-badge">Warehouse Handler</span>
                {/if}
              </span>
              <button 
                type="button" 
                class="remove-warehouse-handler-btn"
                on:click={removeWarehouseHandler}
                title="Remove this warehouse handler"
              >
                ×
              </button>
            </div>
          </div>
        {/if}
        
        {#if warehouseHandlersLoading}
          <div class="warehouse-handlers-loading">
            <div class="spinner"></div>
            <span>Loading warehouse handlers...</span>
          </div>
        {:else if actualWarehouseHandlers.length === 0 && !showAllUsersForWarehouseHandlers}
          <div class="no-warehouse-handlers-found">
            <div class="no-warehouse-handlers-message">
              <span class="warning-icon">⚠️</span>
              <div class="message-content">
                <h5>No Warehouse & Stock Handlers Found</h5>
                <p>No users with "Warehouse" or "Stock Handler" positions found for this branch. You can select any other users to help with warehouse tasks.</p>
                <button type="button" class="select-any-user-btn" on:click={showAllUsersForWarehouseHandlerSelection}>
                  Select Any Users as Warehouse Handlers
                </button>
              </div>
            </div>
          </div>
        {:else if filteredWarehouseHandlers.length === 0}
          <div class="no-warehouse-handlers">
            <span class="notice-icon">⚠️</span>
            <span>No active users found for warehouse handler selection</span>
          </div>
        {:else}
          {#if showAllUsersForWarehouseHandlers}
            <div class="fallback-notice">
              <span class="info-icon">ℹ️</span>
              <span>No official warehouse handlers found. Please select any users from the list below to help with warehouse tasks:</span>
            </div>
          {/if}

          <div class="warehouse-handler-search">
            <input 
              type="text" 
              bind:value={warehouseHandlerSearchQuery}
              placeholder="Search by username, employee name, or position..."
              class="search-input"
            />
          </div>

          <div class="warehouse-handlers-table-container">
            <table class="warehouse-handlers-table">
              <thead>
                <tr>
                  <th>Username</th>
                  <th>Employee Name</th>
                  <th>Employee ID</th>
                  <th>Position</th>
                  <th>Action</th>
                </tr>
              </thead>
              <tbody>
                {#each filteredWarehouseHandlers as user}
                  {@const isSelected = selectedWarehouseHandler && selectedWarehouseHandler.id === user.id}
                  <tr class="warehouse-handler-row" class:is-warehouse-handler={(user.position.toLowerCase().includes('warehouse') || (user.position.toLowerCase().includes('stock') && user.position.toLowerCase().includes('handler')))} class:is-selected={isSelected}>
                    <td class="username-cell">{user.username}</td>
                    <td class="name-cell">{user.employeeName}</td>
                    <td class="id-cell">{user.employeeId}</td>
                    <td class="position-cell">
                      {user.position}
                      {#if (user.position.toLowerCase().includes('warehouse') || (user.position.toLowerCase().includes('stock') && user.position.toLowerCase().includes('handler')))}
                        <span class="warehouse-handler-badge">Warehouse Handler</span>
                      {/if}
                    </td>
                    <td class="action-cell">
                      {#if isSelected}
                        <button 
                          type="button" 
                          class="remove-warehouse-handler-btn"
                          on:click={removeWarehouseHandler}
                        >
                          Remove
                        </button>
                      {:else}
                        <button 
                          type="button" 
                          class="select-warehouse-handler-btn"
                          on:click={() => selectWarehouseHandler(user)}
                        >
                          Select
                        </button>
                      {/if}
                    </td>
                  </tr>
                {/each}
              </tbody>
            </table>
            
            {#if filteredWarehouseHandlers.length === 0 && warehouseHandlerSearchQuery}
              <div class="no-search-results">
                <p>No users found matching "{warehouseHandlerSearchQuery}"</p>
              </div>
            {/if}
          </div>
        {/if}
      </div>
    {/if}

    <!-- Receiving User Information (Auto-selected: logged-in user) -->
    <div class="receiving-user-section">
      <h4>Receiving User</h4>
      <div class="receiving-user-info">
        <div class="auto-selected-user">
          <span class="receiving-label">Performed by:</span>
          <span class="receiving-value">{$currentUser?.username || 'Current User'}</span>
        </div>
        <div class="user-note">
          <span class="note-icon">ℹ️</span>
          <span>This receiving will be recorded under your account</span>
        </div>
      </div>
    </div>

    <!-- Shelf Stockers Selection (Multiple Selection) -->
    {#if selectedBranchManager}
      <div class="shelf-stockers-section">
        <h4>
          {#if showAllUsersForShelfStockers}
            Select User as Shelf Stocker
          {:else}
            Select Shelf Stocker
          {/if}
        </h4>
        
        <!-- Selected Shelf Stocker Display -->
        {#if selectedShelfStocker}
          <div class="selected-stocker">
            <h5>Selected Shelf Stocker:</h5>
            <div class="selected-stocker-item">
              <span class="stocker-info">
                {selectedShelfStocker.username} - {selectedShelfStocker.employeeName}
                {#if selectedShelfStocker.position.toLowerCase().includes('shelf') && selectedShelfStocker.position.toLowerCase().includes('stocker')}
                  <span class="stocker-badge">Shelf Stocker</span>
                {/if}
              </span>
              <button 
                type="button" 
                class="remove-stocker-btn"
                on:click={removeShelfStocker}
                title="Remove this shelf stocker"
              >
                ×
              </button>
            </div>
          </div>
        {/if}
        
        {#if shelfStockersLoading}
          <div class="stockers-loading">
            <div class="spinner"></div>
            <span>Loading shelf stockers...</span>
          </div>
        {:else if actualShelfStockers.length === 0 && !showAllUsersForShelfStockers}
          <!-- No Shelf Stockers Found - Show Message -->
          <div class="no-stockers-found">
            <div class="no-stockers-message">
              <span class="warning-icon">⚠️</span>
              <div class="message-content">
                <h5>No Shelf Stockers Found</h5>
                <p>No users with "Shelf Stocker" position found for this branch. You can select any other users to help with shelf stocking.</p>
                <button type="button" class="select-any-user-btn" on:click={showAllUsersForShelfStockerSelection}>
                  Select Any User as Shelf Stocker
                </button>
              </div>
            </div>
          </div>
        {:else if filteredShelfStockers.length === 0}
          <div class="no-stockers">
            <span class="notice-icon">⚠️</span>
            <span>No active users found for shelf stocker selection</span>
          </div>
        {:else}
          <!-- Show instructions based on current view -->
          {#if showAllUsersForShelfStockers}
            <div class="fallback-notice">
              <span class="info-icon">ℹ️</span>
              <span>No official shelf stockers found. Please select any users from the list below to help with shelf stocking:</span>
            </div>
          {/if}

          <!-- Search Box -->
          <div class="stocker-search">
            <input 
              type="text" 
              bind:value={shelfStockerSearchQuery}
              placeholder="Search by username, employee name, or position..."
              class="search-input"
            />
          </div>

          <!-- Shelf Stockers Table -->
          <div class="stockers-table-container">
            <table class="stockers-table">
              <thead>
                <tr>
                  <th>Username</th>
                  <th>Employee Name</th>
                  <th>Employee ID</th>
                  <th>Position</th>
                  <th>Action</th>
                </tr>
              </thead>
              <tbody>
                {#each filteredShelfStockers as user}
                  {@const isSelected = selectedShelfStocker && selectedShelfStocker.id === user.id}
                  <tr class="stocker-row" class:is-stocker={user.position.toLowerCase().includes('shelf') && user.position.toLowerCase().includes('stocker')} class:is-selected={isSelected}>
                    <td class="username-cell">{user.username}</td>
                    <td class="name-cell">{user.employeeName}</td>
                    <td class="id-cell">{user.employeeId}</td>
                    <td class="position-cell">
                      {user.position}
                      {#if user.position.toLowerCase().includes('shelf') && user.position.toLowerCase().includes('stocker')}
                        <span class="stocker-badge">Shelf Stocker</span>
                      {/if}
                    </td>
                    <td class="action-cell">
                      {#if isSelected}
                        <button 
                          type="button" 
                          class="remove-stocker-btn"
                          on:click={removeShelfStocker}
                        >
                          Remove
                        </button>
                      {:else}
                        <button 
                          type="button" 
                          class="select-stocker-btn"
                          on:click={() => selectShelfStocker(user)}
                        >
                          Select
                        </button>
                      {/if}
                    </td>
                  </tr>
                {/each}
              </tbody>
            </table>
            
            {#if filteredShelfStockers.length === 0 && shelfStockerSearchQuery}
              <div class="no-search-results">
                <p>No users found matching "{shelfStockerSearchQuery}"</p>
              </div>
            {/if}
          </div>
        {/if}
      </div>
    {/if}

    <!-- Accountant Selection (Single Selection) -->
    {#if selectedBranchManager}
      <div class="accountant-section">
        <h4>
          {#if showAllUsersForAccountant}
            Select User as Accountant
          {:else}
            Select Accountant
          {/if}
        </h4>
        
        {#if selectedAccountant}
          <div class="selected-accountant">
            <div class="accountant-info">
              <span class="accountant-label">
                {#if showAllUsersForAccountant}
                  Selected User as Accountant:
                {:else}
                  Selected Accountant:
                {/if}
              </span>
              <span class="accountant-value">
                {selectedAccountant.username} - {selectedAccountant.employeeName}
                {#if selectedAccountant.position.toLowerCase().includes('accountant')}
                  <span class="accountant-badge">Accountant</span>
                {/if}
              </span>
            </div>
            <button type="button" on:click={() => selectedAccountant = null} class="change-accountant-btn">
              Change Selection
            </button>
          </div>
        {:else}
          {#if accountantsLoading}
            <div class="accountants-loading">
              <div class="spinner"></div>
              <span>Loading accountants...</span>
            </div>
          {:else if actualAccountants.length === 0 && !showAllUsersForAccountant}
            <!-- No Accountant Found - Show Message -->
            <div class="no-accountant-found">
              <div class="no-accountant-message">
                <span class="warning-icon">⚠️</span>
                <div class="message-content">
                  <h5>No Accountant Found</h5>
                  <p>No users with "Accountant" position found for this branch. You can select any other user to handle accounting tasks.</p>
                  <button type="button" class="select-any-user-btn" on:click={showAllUsersForAccountantSelection}>
                    Select Any User as Accountant
                  </button>
                </div>
              </div>
            </div>
          {:else if filteredAccountants.length === 0}
            <div class="no-accountants">
              <span class="notice-icon">⚠️</span>
              <span>No active users found for accountant selection</span>
            </div>
          {:else}
            <!-- Show instructions based on current view -->
            {#if showAllUsersForAccountant}
              <div class="fallback-notice">
                <span class="info-icon">ℹ️</span>
                <span>No official accountant found. Please select any user from the list below to handle accounting tasks:</span>
              </div>
            {/if}

            <!-- Search Box -->
            <div class="accountant-search">
              <input 
                type="text" 
                bind:value={accountantSearchQuery}
                placeholder="Search by username, employee name, or position..."
                class="search-input"
              />
            </div>

            <!-- Accountants Table -->
            <div class="accountants-table-container">
              <table class="accountants-table">
                <thead>
                  <tr>
                    <th>Username</th>
                    <th>Employee Name</th>
                    <th>Employee ID</th>
                    <th>Position</th>
                    <th>Action</th>
                  </tr>
                </thead>
                <tbody>
                  {#each filteredAccountants as user}
                    <tr class="accountant-row" class:is-accountant={user.position.toLowerCase().includes('accountant')}>
                      <td class="username-cell">{user.username}</td>
                      <td class="name-cell">{user.employeeName}</td>
                      <td class="id-cell">{user.employeeId}</td>
                      <td class="position-cell">
                        {user.position}
                        {#if user.position.toLowerCase().includes('accountant')}
                          <span class="accountant-badge">Accountant</span>
                        {/if}
                      </td>
                      <td class="action-cell">
                        <button 
                          type="button" 
                          class="select-accountant-btn"
                          on:click={() => selectAccountant(user)}
                        >
                          Select
                        </button>
                      </td>
                    </tr>
                  {/each}
                </tbody>
              </table>
              
              {#if filteredAccountants.length === 0 && accountantSearchQuery}
                <div class="no-search-results">
                  <p>No users found matching "{accountantSearchQuery}"</p>
                </div>
              {/if}
            </div>
          {/if}
        {/if}
      </div>
    {/if}
  {:else}
    <div class="branch-selector">
      {#if isLoading}
        <div class="loading-state">
          <div class="spinner"></div>
          <span>Loading branches...</span>
        </div>
      {:else if errorMessage}
        <div class="error-state">
          <p>{errorMessage}</p>
          <button on:click={loadBranches} class="retry-btn">Retry</button>
        </div>
      {:else}
        <label for="branch-select" class="form-label">Choose Branch:</label>
        <select 
          id="branch-select" 
          bind:value={selectedBranch}
          class="form-select"
        >
          <option value="">-- Select Branch --</option>
          {#each branches as branch}
            <option value={branch.id.toString()}>
              {branch.name_en}
              {#if branch.location_en} - {branch.location_en}{/if}
            </option>
          {/each}
        </select>
        
        {#if selectedBranch}
          <div class="branch-actions">
            <label class="checkbox-label">
              <input type="checkbox" bind:checked={setAsDefaultBranch} />
              <span class="checkmark"></span>
              Set as default branch
            </label>
            <button type="button" on:click={confirmBranchSelection} class="confirm-btn">
              ✓ Confirm Branch
            </button>
          </div>
        {/if}
      {/if}
    </div>
  {/if}
</div>
{/if}

<!-- Step 1 Complete - Continue Button -->
{#if currentStep === 0 && selectedBranch && !showBranchSelector}
  <div class="step-navigation">
    <div class="step-complete-info">
      {#if allRequiredUsersSelected}
        <span class="step-complete-icon">✅</span>
        <span class="step-complete-text">Step 1 Complete: Branch & Staff Selected</span>
      {:else}
        <span class="step-incomplete-icon">⚠️</span>
        <span class="step-incomplete-text">Please select all required staff members</span>
      {/if}
    </div>
    <button 
      type="button" 
      on:click={() => currentStep = 1} 
      class="continue-step-btn"
      disabled={!allRequiredUsersSelected}
    >
      Continue to Step 2: Select Vendor →
    </button>
  </div>
{/if}

<!-- Step 2: Vendor Selection Section -->
{#if currentStep === 1 && selectedBranch && !showBranchSelector}
  <div class="form-section">
    <h3>Step 2: Select Vendor</h3>
    
    {#if selectedVendor}
      <div class="current-selection">
        <div class="selection-info">
          <span class="label">Selected Vendor:</span>
          <span class="value">{selectedVendor.vendor_name}</span>
          <span class="vendor-id">({selectedVendor.erp_vendor_id})</span>
        </div>
        <button type="button" on:click={changeVendor} class="change-btn">
          Change Vendor
        </button>
      </div>
    {:else}
      <div class="vendor-selector">
        <!-- Search Bar -->
        <div class="vendor-search">
          <div class="search-input-wrapper">
            <span class="search-icon">🔍</span>
            <input 
              type="text" 
              placeholder="Search by ERP ID, vendor name, salesman, place, location, categories, delivery modes..."
              bind:value={searchQuery}
              class="search-input"
            />
            {#if searchQuery}
              <button class="clear-search" on:click={() => searchQuery = ''}>×</button>
            {/if}
          </div>
          <div class="search-results-info">
            Showing {filteredVendors.length} of {vendors.length} vendors
          </div>
        </div>

        <!-- Column Selector -->
        <div class="column-selector-section">
          <div class="column-selector">
            <button class="column-selector-btn" on:click={() => showColumnSelector = !showColumnSelector}>
              🏷️ Show/Hide Columns
              <span class="dropdown-arrow">{showColumnSelector ? '▲' : '▼'}</span>
            </button>
            
            {#if showColumnSelector}
              <div class="column-dropdown">
                <div class="column-controls">
                  <button class="control-btn" on:click={() => toggleAllColumns(true)}>✅ Show All</button>
                  <button class="control-btn" on:click={() => toggleAllColumns(false)}>❌ Hide All</button>
                </div>
                <div class="column-list">
                  {#each columnDefinitions as column}
                    <label class="column-item">
                      <input 
                        type="checkbox" 
                        checked={visibleColumns[column.key]} 
                        on:change={() => toggleColumn(column.key)}
                      />
                      <span class="column-label">{column.label}</span>
                    </label>
                  {/each}
                </div>
              </div>
            {/if}
          </div>
        </div>

        {#if vendorLoading}
          <div class="loading-state">
            <div class="spinner"></div>
            <span>Loading vendors...</span>
          </div>
        {:else if vendorError}
          <div class="error-state">
            <p>{vendorError}</p>
            <button on:click={loadVendors} class="retry-btn">Retry</button>
          </div>
        {:else if filteredVendors.length === 0}
          <div class="empty-state">
            {#if searchQuery}
              <span class="empty-icon">🔍</span>
              <h4>No vendors found</h4>
              <p>No vendors match your search criteria</p>
              <button class="clear-search-btn" on:click={() => searchQuery = ''}>Clear Search</button>
            {:else}
              <span class="empty-icon">📝</span>
              <h4>No vendors available</h4>
              <p>No active vendors found</p>
            {/if}
          </div>
        {:else}
          <!-- Enhanced Vendor Table with Column Visibility -->
          <div class="vendor-table">
            <table>
              <thead>
                <tr>
                  {#if visibleColumns.erp_vendor_id}<th>ERP Vendor ID</th>{/if}
                  {#if visibleColumns.vendor_name}<th>Vendor Name</th>{/if}
                  {#if visibleColumns.salesman_name}<th>Salesman Name</th>{/if}
                  {#if visibleColumns.salesman_contact}<th>Salesman Contact</th>{/if}
                  {#if visibleColumns.supervisor_name}<th>Supervisor Name</th>{/if}
                  {#if visibleColumns.supervisor_contact}<th>Supervisor Contact</th>{/if}
                  {#if visibleColumns.vendor_contact}<th>Vendor Contact</th>{/if}
                  {#if visibleColumns.payment_method}<th>Payment Method</th>{/if}
                  {#if visibleColumns.credit_period}<th>Credit Period</th>{/if}
                  {#if visibleColumns.bank_name}<th>Bank Name</th>{/if}
                  {#if visibleColumns.iban}<th>IBAN</th>{/if}
                  {#if visibleColumns.last_visit}<th>Last Visit</th>{/if}
                  {#if visibleColumns.place}<th>Place</th>{/if}
                  {#if visibleColumns.location}<th>Location</th>{/if}
                  {#if visibleColumns.categories}<th>Categories</th>{/if}
                  {#if visibleColumns.delivery_modes}<th>Delivery Modes</th>{/if}
                  {#if visibleColumns.return_expired}<th>Return Expired</th>{/if}
                  {#if visibleColumns.return_near_expiry}<th>Return Near Expiry</th>{/if}
                  {#if visibleColumns.return_over_stock}<th>Return Over Stock</th>{/if}
                  {#if visibleColumns.return_damage}<th>Return Damage</th>{/if}
                  {#if visibleColumns.no_return}<th>No Return</th>{/if}
                  {#if visibleColumns.vat_status}<th>VAT Status</th>{/if}
                  {#if visibleColumns.vat_number}<th>VAT Number</th>{/if}
                  {#if visibleColumns.status}<th>Status</th>{/if}
                  {#if visibleColumns.actions}<th>Actions</th>{/if}
                </tr>
              </thead>
              <tbody>
                {#each filteredVendors as vendor}
                  <tr>
                    {#if visibleColumns.erp_vendor_id}
                      <td class="vendor-id">{vendor.erp_vendor_id}</td>
                    {/if}
                    {#if visibleColumns.vendor_name}
                      <td class="vendor-name">{vendor.vendor_name}</td>
                    {/if}
                    {#if visibleColumns.salesman_name}
                      <td class="vendor-data">
                        {#if vendor.salesman_name}
                          {vendor.salesman_name}
                        {:else}
                          <span class="no-data">No salesman</span>
                        {/if}
                      </td>
                    {/if}
                    {#if visibleColumns.salesman_contact}
                      <td class="vendor-data">
                        {#if vendor.salesman_contact}
                          {vendor.salesman_contact}
                        {:else}
                          <span class="no-data">No contact</span>
                        {/if}
                      </td>
                    {/if}
                    {#if visibleColumns.supervisor_name}
                      <td class="vendor-data">
                        {#if vendor.supervisor_name}
                          {vendor.supervisor_name}
                        {:else}
                          <span class="no-data">No supervisor</span>
                        {/if}
                      </td>
                    {/if}
                    {#if visibleColumns.supervisor_contact}
                      <td class="vendor-data">
                        {#if vendor.supervisor_contact}
                          {vendor.supervisor_contact}
                        {:else}
                          <span class="no-data">No contact</span>
                        {/if}
                      </td>
                    {/if}
                    {#if visibleColumns.vendor_contact}
                      <td class="vendor-data">
                        {#if vendor.vendor_contact_number}
                          {vendor.vendor_contact_number}
                        {:else}
                          <span class="no-data">No contact</span>
                        {/if}
                      </td>
                    {/if}
                    {#if visibleColumns.payment_method}
                      <td class="vendor-data">
                        {#if vendor.payment_method}
                          {vendor.payment_method}
                        {:else}
                          <span class="no-data">N/A</span>
                        {/if}
                      </td>
                    {/if}
                    {#if visibleColumns.credit_period}
                      <td class="vendor-data">
                        {#if vendor.credit_period}
                          {vendor.credit_period} days
                        {:else}
                          <span class="no-data">N/A</span>
                        {/if}
                      </td>
                    {/if}
                    {#if visibleColumns.bank_name}
                      <td class="vendor-data">
                        {#if vendor.bank_name}
                          {vendor.bank_name}
                        {:else}
                          <span class="no-data">No bank</span>
                        {/if}
                      </td>
                    {/if}
                    {#if visibleColumns.iban}
                      <td class="vendor-data">
                        {#if vendor.iban}
                          {vendor.iban}
                        {:else}
                          <span class="no-data">No IBAN</span>
                        {/if}
                      </td>
                    {/if}
                    {#if visibleColumns.last_visit}
                      <td class="vendor-data">
                        {#if vendor.last_visit}
                          {new Date(vendor.last_visit).toLocaleDateString()}
                        {:else}
                          <span class="no-data">No visit</span>
                        {/if}
                      </td>
                    {/if}
                    {#if visibleColumns.place}
                      <td class="vendor-data">
                        {#if vendor.place}
                          📍 {vendor.place}
                        {:else}
                          <span class="no-data">No place</span>
                        {/if}
                      </td>
                    {/if}
                    {#if visibleColumns.location}
                      <td class="vendor-data">
                        {#if vendor.location_link}
                          <button class="location-btn" on:click={() => window.open(vendor.location_link, '_blank')}>
                            🌐 Open Map
                          </button>
                        {:else}
                          <span class="no-data">No location</span>
                        {/if}
                      </td>
                    {/if}
                    {#if visibleColumns.categories}
                      <td class="vendor-categories">
                        {#if vendor.categories && vendor.categories.length > 0}
                          <div class="category-badges">
                            {#each vendor.categories.slice(0, 2) as category}
                              <span class="category-badge">{category}</span>
                            {/each}
                            {#if vendor.categories.length > 2}
                              <span class="category-badge more">+{vendor.categories.length - 2}</span>
                            {/if}
                          </div>
                        {:else}
                          <span class="no-data">No categories</span>
                        {/if}
                      </td>
                    {/if}
                    {#if visibleColumns.delivery_modes}
                      <td class="vendor-data">
                        {#if vendor.delivery_modes && vendor.delivery_modes.length > 0}
                          <div class="delivery-badges">
                            {#each vendor.delivery_modes.slice(0, 2) as mode}
                              <span class="delivery-badge">{mode}</span>
                            {/each}
                            {#if vendor.delivery_modes.length > 2}
                              <span class="delivery-badge more">+{vendor.delivery_modes.length - 2}</span>
                            {/if}
                          </div>
                        {:else}
                          <span class="no-data">No delivery modes</span>
                        {/if}
                      </td>
                    {/if}
                    {#if visibleColumns.return_expired}
                      <td class="vendor-data">
                        {#if vendor.return_expired_products}
                          <span class="return-policy {vendor.return_expired_products.toLowerCase()}">{vendor.return_expired_products}</span>
                        {:else}
                          <span class="no-data">N/A</span>
                        {/if}
                      </td>
                    {/if}
                    {#if visibleColumns.return_near_expiry}
                      <td class="vendor-data">
                        {#if vendor.return_near_expiry_products}
                          <span class="return-policy {vendor.return_near_expiry_products.toLowerCase()}">{vendor.return_near_expiry_products}</span>
                        {:else}
                          <span class="no-data">N/A</span>
                        {/if}
                      </td>
                    {/if}
                    {#if visibleColumns.return_over_stock}
                      <td class="vendor-data">
                        {#if vendor.return_over_stock}
                          <span class="return-policy {vendor.return_over_stock.toLowerCase()}">{vendor.return_over_stock}</span>
                        {:else}
                          <span class="no-data">N/A</span>
                        {/if}
                      </td>
                    {/if}
                    {#if visibleColumns.return_damage}
                      <td class="vendor-data">
                        {#if vendor.return_damage_products}
                          <span class="return-policy {vendor.return_damage_products.toLowerCase()}">{vendor.return_damage_products}</span>
                        {:else}
                          <span class="no-data">N/A</span>
                        {/if}
                      </td>
                    {/if}
                    {#if visibleColumns.no_return}
                      <td class="vendor-data">
                        {#if vendor.no_return !== undefined}
                          <span class="return-policy {vendor.no_return ? 'true' : 'false'}">{vendor.no_return ? 'Yes' : 'No'}</span>
                        {:else}
                          <span class="no-data">N/A</span>
                        {/if}
                      </td>
                    {/if}
                    {#if visibleColumns.vat_status}
                      <td class="vendor-data">
                        {#if vendor.vat_applicable}
                          <span class="vat-status {vendor.vat_applicable.toLowerCase().replace(' ', '-')}">{vendor.vat_applicable}</span>
                        {:else}
                          <span class="no-data">N/A</span>
                        {/if}
                      </td>
                    {/if}
                    {#if visibleColumns.vat_number}
                      <td class="vendor-data">
                        {#if vendor.vat_number}
                          {vendor.vat_number}
                        {:else}
                          <span class="no-data">No VAT number</span>
                        {/if}
                      </td>
                    {/if}
                    {#if visibleColumns.status}
                      <td class="vendor-status">
                        <span class="status-badge {vendor.status ? vendor.status.toLowerCase() : 'active'}">{vendor.status || 'Active'}</span>
                      </td>
                    {/if}
                    {#if visibleColumns.actions}
                      <td class="action-cell">
                        <div class="action-buttons">
                          <button class="select-btn" on:click={() => selectVendor(vendor)}>
                            Select
                          </button>
                          <button class="edit-btn" on:click={() => openEditWindow(vendor)}>
                            ✏️ Edit
                          </button>
                        </div>
                      </td>
                    {/if}
                  </tr>
                {/each}
              </tbody>
            </table>
          </div>
        {/if}
      </div>
    {/if}
  </div>
{/if}

<!-- Step 2 Complete - Continue Button -->
{#if currentStep === 1 && selectedVendor}
  <div class="step-navigation">
    <div class="step-complete-info">
      <span class="step-complete-icon">✅</span>
      <span class="step-complete-text">Step 2 Complete: Vendor Selected</span>
    </div>
    <button type="button" on:click={() => currentStep = 2} class="continue-step-btn">
      Continue to Step 3: Bill Information →
    </button>
  </div>
{/if}

<!-- Step 3: Bill Information -->
{#if currentStep === 2 && selectedVendor}
  <div class="form-section">
    <h3>Step 3: Bill Information</h3>
    <p class="step-description">Review current date and enter bill details</p>
    
    <div class="bill-info-grid">
      <div class="date-field">
        <label>Current Date & Time:</label>
        <input 
          type="text" 
          value={currentDateTime} 
          readonly 
          class="readonly-input"
        />
      </div>
      
      <div class="date-field">
        <label for="billDate">Bill Date: <span class="required">*</span></label>
        <input 
          type="date" 
          id="billDate"
          bind:value={billDate}
          class="editable-input"
          required
        />
      </div>

      <div class="amount-field">
        <label for="billAmount">Bill Amount: <span class="required">*</span></label>
        <input 
          type="number" 
          id="billAmount"
          bind:value={billAmount}
          step="0.01"
          min="0"
          placeholder="0.00"
          class="editable-input"
          required
        />
      </div>

      <div class="bill-number-field">
        <label for="billNumber">Bill Number: <span class="required">*</span></label>
        <input 
          type="text" 
          id="billNumber"
          bind:value={billNumber}
          placeholder="Enter bill number"
          class="editable-input"
          required
        />
      </div>
    </div>

    <!-- Current Return Policy Section -->
    <div class="return-policy-section">
      <h4>Current Return Policy for {selectedVendor.vendor_name}</h4>
      <div class="policy-grid">
        <div class="policy-item">
          <label>Expired Products:</label>
          <span class="policy-value {selectedVendor.return_expired_products ? selectedVendor.return_expired_products.toLowerCase() : 'not-specified'}">
            {selectedVendor.return_expired_products || 'Not specified'}
          </span>
        </div>
        <div class="policy-item">
          <label>Near Expiry Products:</label>
          <span class="policy-value {selectedVendor.return_near_expiry_products ? selectedVendor.return_near_expiry_products.toLowerCase() : 'not-specified'}">
            {selectedVendor.return_near_expiry_products || 'Not specified'}
          </span>
        </div>
        <div class="policy-item">
          <label>Over Stock:</label>
          <span class="policy-value {selectedVendor.return_over_stock ? selectedVendor.return_over_stock.toLowerCase() : 'not-specified'}">
            {selectedVendor.return_over_stock || 'Not specified'}
          </span>
        </div>
        <div class="policy-item">
          <label>Damage Products:</label>
          <span class="policy-value {selectedVendor.return_damage_products ? selectedVendor.return_damage_products.toLowerCase() : 'not-specified'}">
            {selectedVendor.return_damage_products || 'Not specified'}
          </span>
        </div>
        <div class="policy-item">
          <label>Return Policy Status:</label>
          <span class="policy-value {selectedVendor.no_return ? 'no-returns' : 'returns-accepted'}">
            {selectedVendor.no_return ? 'No Returns Accepted' : 'Returns Accepted'}
          </span>
        </div>
      </div>
    </div>

    <!-- Return Processing Section -->
    {#if selectedVendor && !selectedVendor.no_return}
      <div class="return-processing-section">
        <h4>Return Processing</h4>
        <p class="section-description">Mark if there are any returns for this receiving and enter amounts</p>
        
        <div class="return-questions-grid">
          <!-- Expired Products Return -->
          <div class="return-question">
            <label>Returns for Expired Products:</label>
            <select bind:value={returns.expired.hasReturn} class="return-dropdown">
              <option value="no">No</option>
              <option value="yes">Yes</option>
            </select>
            {#if returns.expired.hasReturn === 'yes'}
              <input 
                type="number" 
                bind:value={returns.expired.amount}
                placeholder="Enter return amount"
                step="0.01"
                min="0"
                class="return-amount-input"
              />
              <select bind:value={returns.expired.erpDocumentType} class="return-dropdown">
                <option value="">Select ERP Document Type</option>
                <option value="GRR">GRR (Goods Return Receipt)</option>
                <option value="PRI">PRI (Purchase Return Invoice)</option>
              </select>
              <input 
                type="text" 
                bind:value={returns.expired.erpDocumentNumber}
                placeholder="Enter ERP document number"
                class="return-amount-input"
              />
              <input 
                type="text" 
                bind:value={returns.expired.vendorDocumentNumber}
                placeholder="Enter vendor document number"
                class="return-amount-input"
              />
            {/if}
          </div>

          <!-- Near Expiry Products Return -->
          <div class="return-question">
            <label>Returns for Near Expiry Products:</label>
            <select bind:value={returns.nearExpiry.hasReturn} class="return-dropdown">
              <option value="no">No</option>
              <option value="yes">Yes</option>
            </select>
            {#if returns.nearExpiry.hasReturn === 'yes'}
              <input 
                type="number" 
                bind:value={returns.nearExpiry.amount}
                placeholder="Enter return amount"
                step="0.01"
                min="0"
                class="return-amount-input"
              />
              <select bind:value={returns.nearExpiry.erpDocumentType} class="return-dropdown">
                <option value="">Select ERP Document Type</option>
                <option value="GRR">GRR (Goods Return Receipt)</option>
                <option value="PRI">PRI (Purchase Return Invoice)</option>
              </select>
              <input 
                type="text" 
                bind:value={returns.nearExpiry.erpDocumentNumber}
                placeholder="Enter ERP document number"
                class="return-amount-input"
              />
              <input 
                type="text" 
                bind:value={returns.nearExpiry.vendorDocumentNumber}
                placeholder="Enter vendor document number"
                class="return-amount-input"
              />
            {/if}
          </div>

          <!-- Over Stock Return -->
          <div class="return-question">
            <label>Returns for Over Stock:</label>
            <select bind:value={returns.overStock.hasReturn} class="return-dropdown">
              <option value="no">No</option>
              <option value="yes">Yes</option>
            </select>
            {#if returns.overStock.hasReturn === 'yes'}
              <input 
                type="number" 
                bind:value={returns.overStock.amount}
                placeholder="Enter return amount"
                step="0.01"
                min="0"
                class="return-amount-input"
              />
              <select bind:value={returns.overStock.erpDocumentType} class="return-dropdown">
                <option value="">Select ERP Document Type</option>
                <option value="GRR">GRR (Goods Return Receipt)</option>
                <option value="PRI">PRI (Purchase Return Invoice)</option>
              </select>
              <input 
                type="text" 
                bind:value={returns.overStock.erpDocumentNumber}
                placeholder="Enter ERP document number"
                class="return-amount-input"
              />
              <input 
                type="text" 
                bind:value={returns.overStock.vendorDocumentNumber}
                placeholder="Enter vendor document number"
                class="return-amount-input"
              />
            {/if}
          </div>

          <!-- Damage Products Return -->
          <div class="return-question">
            <label>Returns for Damage Products:</label>
            <select bind:value={returns.damage.hasReturn} class="return-dropdown">
              <option value="no">No</option>
              <option value="yes">Yes</option>
            </select>
            {#if returns.damage.hasReturn === 'yes'}
              <input 
                type="number" 
                bind:value={returns.damage.amount}
                placeholder="Enter return amount"
                step="0.01"
                min="0"
                class="return-amount-input"
              />
              <select bind:value={returns.damage.erpDocumentType} class="return-dropdown">
                <option value="">Select ERP Document Type</option>
                <option value="GRR">GRR (Goods Return Receipt)</option>
                <option value="PRI">PRI (Purchase Return Invoice)</option>
              </select>
              <input 
                type="text" 
                bind:value={returns.damage.erpDocumentNumber}
                placeholder="Enter ERP document number"
                class="return-amount-input"
              />
              <input 
                type="text" 
                bind:value={returns.damage.vendorDocumentNumber}
                placeholder="Enter vendor document number"
                class="return-amount-input"
              />
            {/if}
          </div>
        </div>

        <!-- Bill Amount Summary -->
        <div class="bill-summary">
          <div class="summary-row">
            <label>Original Bill Amount:</label>
            <span class="amount-display">{parseFloat(billAmount || 0).toFixed(2)}</span>
          </div>
          <div class="summary-row">
            <label>Total Return Amount:</label>
            <span class="amount-display return-amount">{totalReturnAmount.toFixed(2)}</span>
          </div>
          <div class="summary-row final-amount">
            <label>Final Bill Amount:</label>
            <span class="amount-display">{finalBillAmount.toFixed(2)}</span>
          </div>
        </div>
      </div>
    {/if}

    <!-- Payment Information Section -->
    {#if selectedVendor}
      <div class="payment-section">
        <h4>Payment Information</h4>
        <p class="section-description">Current payment details from vendor (can be changed for this receiving)</p>
        
        <div class="payment-grid">
          <div class="payment-field">
            <label for="paymentMethod">Payment Method:</label>
            <select 
              id="paymentMethod"
              bind:value={paymentMethod}
              on:change={() => paymentChanged = true}
              class="editable-input"
            >
              <option value="">Select Payment Method</option>
              <option value="Cash on Delivery">Cash on Delivery</option>
              <option value="Bank on Delivery">Bank on Delivery</option>
              <option value="Cash Credit">Cash Credit</option>
              <option value="Bank Credit">Bank Credit</option>
            </select>
          </div>

          <!-- Credit Period - Show only for Credit methods -->
          {#if paymentMethod && (paymentMethod === 'Cash Credit' || paymentMethod === 'Bank Credit')}
            <div class="payment-field">
              <label for="creditPeriod">Credit Period (Days):</label>
              <input 
                type="number" 
                id="creditPeriod"
                bind:value={creditPeriod}
                on:input={() => paymentChanged = true}
                placeholder="Enter credit period in days"
                min="0"
                class="editable-input"
              />
            </div>
          {/if}

          <!-- Bank Name - Show for Bank methods only -->
          {#if paymentMethod && (paymentMethod === 'Bank on Delivery' || paymentMethod === 'Bank Credit')}
            <div class="payment-field">
              <label for="bankName">Bank Name:</label>
              <input 
                type="text" 
                id="bankName"
                bind:value={bankName}
                on:input={() => paymentChanged = true}
                placeholder="Enter bank name"
                class="editable-input"
              />
            </div>

            <div class="payment-field">
              <label for="iban">IBAN:</label>
              <input 
                type="text" 
                id="iban"
                bind:value={iban}
                on:input={() => paymentChanged = true}
                placeholder="Enter IBAN number"
                class="editable-input"
              />
            </div>
          {/if}
        </div>

        {#if paymentChanged}
          <div class="payment-notice">
            <span class="notice-icon">ℹ️</span>
            <span>Payment information has been modified for this receiving.</span>
          </div>
        {/if}
      </div>
    {/if}

    <!-- Due Date Section - Show for all payment methods -->
    {#if selectedVendor && paymentMethod}
      <div class="due-date-section">
        <h4>Due Date Information</h4>
        
        {#if paymentMethod === 'Cash on Delivery' || paymentMethod === 'Bank on Delivery'}
          <p class="section-description">Payment due on delivery (current date)</p>
        {:else if paymentMethod === 'Cash Credit' || paymentMethod === 'Bank Credit'}
          <p class="section-description">Calculated based on bill date and credit period</p>
        {/if}
        
        <div class="due-date-field">
          <label for="dueDate">Due Date:</label>
          {#if dueDate}
            <input 
              type="date" 
              id="dueDate"
              value={dueDate}
              readonly
              class="readonly-input"
              title={paymentMethod === 'Cash on Delivery' || paymentMethod === 'Bank on Delivery' 
                     ? 'Due on delivery (current date)' 
                     : 'Calculated as Bill Date + Credit Period'}
            />
            {#if paymentMethod === 'Cash Credit' || paymentMethod === 'Bank Credit'}
              <span class="calculation-info">Bill Date + {creditPeriod} days</span>
            {:else}
              <span class="calculation-info">Due on delivery</span>
            {/if}
          {:else if (paymentMethod === 'Cash Credit' || paymentMethod === 'Bank Credit') && billDate && !creditPeriod}
            <div class="due-date-notice">
              <span class="notice-text">Please enter credit period to calculate due date</span>
            </div>
          {:else}
            <input 
              type="date" 
              id="dueDate"
              value=""
              readonly
              placeholder="Due date will be calculated"
              class="readonly-input"
            />
            <span class="calculation-info">Waiting for bill date and credit period</span>
          {/if}
        </div>
      </div>
    {/if}

    <!-- VAT Number Verification Section -->
    {#if selectedVendor}
      <div class="vat-verification-section">
        <h4>VAT Number Verification</h4>
        <p class="section-description">Verify VAT number on bill matches vendor VAT number</p>
        
        {#if selectedVendor.vat_applicable !== 'VAT Applicable'}
          <div class="vat-not-applicable">
            <span class="info-icon">ℹ️</span>
            <span>VAT is not applicable for this vendor</span>
          </div>
        {:else}
          <div class="vat-grid">
            <div class="vat-field">
              <label for="vendorVatNumber">Vendor VAT Number:</label>
              <input 
                type="text" 
                id="vendorVatNumber"
                value={vendorVatNumber ? maskVatNumber(vendorVatNumber) : ''}
                readonly
                class="readonly-input masked-vat"
                placeholder="No VAT number on file"
                title="Enter full VAT number in the field below to verify"
              />
              {#if vendorVatNumber}
                <small class="vat-hint">Enter full VAT number below to verify</small>
              {/if}
            </div>

            <div class="vat-field">
              <label for="billVatNumber">VAT Number on Bill:</label>
              <input 
                type="text" 
                id="billVatNumber"
                bind:value={billVatNumber}
                placeholder="Enter VAT number from bill"
                class="editable-input"
              />
            </div>
          </div>

          <!-- VAT Verification Status -->
          {#if billVatNumber}
            <div class="vat-status">
              {#if vatNumbersMatch === true}
                <div class="vat-match">
                  <span class="status-icon">✅</span>
                  <span>VAT numbers match - you can proceed</span>
                </div>
              {:else if vatNumbersMatch === false}
                <div class="vat-mismatch">
                  <span class="status-icon">⚠️</span>
                  <span>VAT numbers don't match</span>
                </div>
                
                <div class="mismatch-reason">
                  <label for="vatMismatchReason">Reason for VAT Number Mismatch:</label>
                  <textarea 
                    id="vatMismatchReason"
                    bind:value={vatMismatchReason}
                    placeholder="Please explain why VAT numbers don't match (e.g., bill from different entity, subsidiary, etc.)"
                    rows="3"
                    class="reason-textarea"
                  ></textarea>
                  <p class="reason-note">You can still proceed with the receiving after providing a reason.</p>
                </div>
              {/if}
            </div>
          {/if}
        {/if}
      </div>
    {/if}

    <!-- Action Buttons for Step 3 -->
    {#if currentStep !== 2 && currentStep !== 3}
    <div class="step-actions">
      <button type="button" class="secondary-btn" on:click={goBackToVendorSelection}>
        ← Back to Vendor Selection
      </button>
      <button type="button" class="primary-btn" on:click={proceedToReceiving}>
        Continue to Receiving →
      </button>
    </div>
    {/if}
    
    <!-- Navigation for Step 3 (Bill Information) -->
    {#if currentStep === 2}
    <div class="step-actions">
      <button type="button" class="secondary-btn" on:click={() => currentStep = 1}>
        ← Back to Vendor Selection
      </button>
    </div>
    {/if}
  </div>
{/if}

<!-- Step 3 Complete - Continue Button -->
{#if currentStep === 2 && selectedBranchManager && billDate && billAmount && billNumber && billNumber.trim() && (!selectedVendor || selectedVendor.vat_applicable !== 'VAT Applicable' || !selectedVendor.vat_number || (billVatNumber && billVatNumber.trim() && (vatNumbersMatch !== false || vatMismatchReason.trim())))}
  <div class="step-navigation">
    <div class="step-complete-info">
      <span class="step-complete-icon">✅</span>
      <span class="step-complete-text">Step 3 Complete: Bill Information & User Roles Assigned</span>
    </div>
    <button type="button" on:click={saveReceivingData} class="save-continue-btn">
      💾 Save & Continue to Certification →
    </button>
  </div>
{/if}

<!-- Step 4: Finalization -->
{#if currentStep === 3}
  <div class="form-section">
    <h3>Step 4: Finalization</h3>
    {#if savedReceivingId}
      <p class="step-description">✅ Receiving data saved successfully! Generate clearance certificate template.</p>
    {:else}
      <p class="step-description">⚠️ Please go back to Step 3 and save the receiving data first.</p>
    {/if}
    
    <div class="clearance-section">
      {#if savedReceivingId}
        <button type="button" class="generate-cert-btn" on:click={generateClearanceCertification}>
          � Generate Clearance Certificate 
        </button>
      {:else}
        <button type="button" class="generate-cert-btn-disabled" disabled>
          � Generate Clearance Certificate
        </button>
        <p class="warning-text">Please save the receiving data from Step 3 first.</p>
      {/if}
    </div>

    <!-- Clearance Certification Modal -->
    {#if showCertification}
      <div class="certification-modal" on:click|self={() => showCertification = false}>
        <div class="certification-content">
          <div class="certification-header">
            <button class="close-btn" on:click={() => showCertification = false}>×</button>
            <button class="print-btn" on:click={printCertification}>🖨️ Print</button>
          </div>
          
          <div class="certification-template" id="certification-template">
            <!-- Company Logo - Top Center -->
            <div class="cert-header">
              <div class="cert-logo">
                <img src="/icons/icon-192x192.png" alt="Company Logo" class="logo" />
              </div>
              
              <!-- Bilingual Title -->
              <div class="cert-title">
                <h2 class="title-english">CLEARANCE CERTIFICATION</h2>
                <h2 class="title-arabic">شهادة تخليص البضائع</h2>
              </div>
            </div>
            
            <!-- Certification Details - Bilingual -->
            <div class="cert-details">
              <div class="cert-row">
                <div class="label-group">
                  <label class="label-english">Bill Number:</label>
                  <label class="label-arabic">رقم الفاتورة:</label>
                </div>
                <span class="value">{billNumber || 'N/A'}</span>
              </div>
              
              <div class="cert-row">
                <div class="label-group">
                  <label class="label-english">Bill Date:</label>
                  <label class="label-arabic">تاريخ الفاتورة:</label>
                </div>
                <span class="value">{billDate}</span>
              </div>
              
              <div class="cert-row">
                <div class="label-group">
                  <label class="label-english">Branch:</label>
                  <label class="label-arabic">الفرع:</label>
                </div>
                <span class="value">{selectedBranchName}</span>
              </div>
              
              <div class="cert-row">
                <div class="label-group">
                  <label class="label-english">Bill Amount:</label>
                  <label class="label-arabic">مبلغ الفاتورة:</label>
                </div>
                <span class="value">{parseFloat(billAmount || '0').toFixed(2)}</span>
              </div>
              
              <!-- Returns Section -->
              <div class="returns-section">
                <div class="returns-header">
                  <div class="label-group">
                    <label class="label-english">Returns Summary:</label>
                    <label class="label-arabic">ملخص المرتجعات:</label>
                  </div>
                </div>
                
                <!-- Expired Returns -->
                <div class="return-row">
                  <div class="return-type">
                    <span class="type-english">Expired Returns</span>
                    <span class="type-arabic">مرتجعات منتهية الصلاحية</span>
                  </div>
                  <div class="return-details">
                    <span class="status {returns.expired.hasReturn === 'yes' ? 'yes' : 'no'}">
                      {returns.expired.hasReturn === 'yes' ? 'Yes / نعم' : 'No / لا'}
                    </span>
                    <span class="amount">
                      {returns.expired.hasReturn === 'yes' ? parseFloat(returns.expired.amount || '0').toFixed(2) : '0.00'}
                    </span>
                  </div>
                </div>
                
                <!-- Near Expiry Returns -->
                <div class="return-row">
                  <div class="return-type">
                    <span class="type-english">Near Expiry Returns</span>
                    <span class="type-arabic">مرتجعات قريبة الانتهاء</span>
                  </div>
                  <div class="return-details">
                    <span class="status {returns.nearExpiry.hasReturn === 'yes' ? 'yes' : 'no'}">
                      {returns.nearExpiry.hasReturn === 'yes' ? 'Yes / نعم' : 'No / لا'}
                    </span>
                    <span class="amount">
                      {returns.nearExpiry.hasReturn === 'yes' ? parseFloat(returns.nearExpiry.amount || '0').toFixed(2) : '0.00'}
                    </span>
                  </div>
                </div>
                
                <!-- Over Stock Returns -->
                <div class="return-row">
                  <div class="return-type">
                    <span class="type-english">Over Stock Returns</span>
                    <span class="type-arabic">مرتجعات فائض المخزون</span>
                  </div>
                  <div class="return-details">
                    <span class="status {returns.overStock.hasReturn === 'yes' ? 'yes' : 'no'}">
                      {returns.overStock.hasReturn === 'yes' ? 'Yes / نعم' : 'No / لا'}
                    </span>
                    <span class="amount">
                      {returns.overStock.hasReturn === 'yes' ? parseFloat(returns.overStock.amount || '0').toFixed(2) : '0.00'}
                    </span>
                  </div>
                </div>
                
                <!-- Damage Returns -->
                <div class="return-row">
                  <div class="return-type">
                    <span class="type-english">Damage Returns</span>
                    <span class="type-arabic">مرتجعات تالفة</span>
                  </div>
                  <div class="return-details">
                    <span class="status {returns.damage.hasReturn === 'yes' ? 'yes' : 'no'}">
                      {returns.damage.hasReturn === 'yes' ? 'Yes / نعم' : 'No / لا'}
                    </span>
                    <span class="amount">
                      {returns.damage.hasReturn === 'yes' ? parseFloat(returns.damage.amount || '0').toFixed(2) : '0.00'}
                    </span>
                  </div>
                </div>
                
                <!-- Total Returns -->
                <div class="return-row total-returns">
                  <div class="return-type">
                    <span class="type-english">Total Returns</span>
                    <span class="type-arabic">إجمالي المرتجعات</span>
                  </div>
                  <div class="return-details">
                    <span class="amount total">{totalReturnAmount.toFixed(2)}</span>
                  </div>
                </div>
              </div>
              
              <div class="cert-row final-amount">
                <div class="label-group">
                  <label class="label-english">Final Amount:</label>
                  <label class="label-arabic">المبلغ النهائي:</label>
                </div>
                <span class="value">{finalBillAmount.toFixed(2)}</span>
              </div>
              
              <div class="cert-row">
                <div class="label-group">
                  <label class="label-english">Salesman Name:</label>
                  <label class="label-arabic">اسم البائع:</label>
                </div>
                <span class="value">{selectedVendor?.salesman_name || 'N/A'}</span>
              </div>
              
              <div class="cert-row">
                <div class="label-group">
                  <label class="label-english">Salesman Contact:</label>
                  <label class="label-arabic">رقم البائع:</label>
                </div>
                <span class="value">{selectedVendor?.salesman_contact || 'N/A'}</span>
              </div>
              
              <div class="cert-row">
                <div class="label-group">
                  <label class="label-english">Logged Employee:</label>
                  <label class="label-arabic">الموظف المسجل:</label>
                </div>
                <span class="value">{$currentUser?.employeeName || $currentUser?.username}</span>
              </div>
            </div>

            <!-- Signatures Section - Bilingual -->
            <div class="signatures-section">
              <div class="signature-box">
                <div class="signature-line"></div>
                <div class="signature-labels">
                  <label class="label-english">Salesman Signature</label>
                  <label class="label-arabic">توقيع البائع</label>
                </div>
                <p>{selectedVendor?.salesman_name || 'N/A'}</p>
              </div>
              <div class="signature-box">
                <div class="signature-line"></div>
                <div class="signature-labels">
                  <label class="label-english">Receiver Signature</label>
                  <label class="label-arabic">توقيع المستلم</label>
                </div>
                <p>{$currentUser?.employeeName || $currentUser?.username}</p>
              </div>
            </div>

            <!-- Certification Footer - Bilingual -->
            <div class="cert-footer">
              <p class="footer-english">This certification confirms the receipt of goods as per the details mentioned above.</p>
              <p class="footer-arabic">تؤكد هذه الشهادة استلام البضائع وفقاً للتفاصيل المذكورة أعلاه.</p>
              <div class="date-stamp">
                <span class="date-english"><strong>Date: {new Date().toLocaleDateString()}</strong></span>
                <span class="date-arabic"><strong>التاريخ: {new Date().toLocaleDateString()}</strong></span>
              </div>
            </div>
          </div>

          <!-- Action Buttons -->
          <div class="cert-actions">
            <button type="button" class="save-btn" on:click={saveClearanceCertification}>
              ✅ Confirm Certification
            </button>
            <button type="button" class="cancel-btn" on:click={() => showCertification = false}>
              Cancel
            </button>
          </div>
        </div>
      </div>
    {/if}
    
    <div class="step-actions">
      <button type="button" class="secondary-btn" on:click={() => currentStep = 2}>
        ← Back to Bill Information
      </button>
    </div>
  </div>
{/if}

<!-- More StartReceiving content will be added here -->

<style>
	.user-info-section {
		margin-bottom: 2rem;
		padding: 1rem;
		background: #f8f9fa;
		border-radius: 8px;
		border-left: 4px solid #1976d2;
	}
	
	.user-info-section h2 {
		margin: 0 0 0.5rem 0;
		color: #1976d2;
		font-size: 1.5rem;
		font-weight: 600;
	}
	
	.user-greeting {
		margin: 0;
		color: #333;
		font-size: 1rem;
	}
	
	.user-greeting strong {
		color: #1976d2;
	}
	
	.branch-info {
		color: #666;
		font-style: italic;
		margin-left: 0.5rem;
	}

	.form-section {
		margin-bottom: 2rem;
		padding: 1.5rem;
		background: #fff;
		border-radius: 8px;
		box-shadow: 0 2px 4px rgba(0,0,0,0.1);
	}

	.form-section h3 {
		margin: 0 0 1rem 0;
		color: #333;
		font-size: 1.25rem;
		font-weight: 600;
	}

	.current-selection {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 1rem;
		background: #e8f5e8;
		border-radius: 6px;
		border: 1px solid #4caf50;
	}

	.selection-info .label {
		color: #666;
		margin-right: 0.5rem;
	}

	.branch-users-section {
		margin-top: 1.5rem;
		padding: 1rem;
		background: #f8f9fa;
		border-radius: 6px;
		border: 1px solid #dee2e6;
	}

	.branch-users-section h4 {
		margin: 0 0 1rem 0;
		color: #495057;
		font-size: 1.1rem;
		font-weight: 600;
	}

	.selected-user {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 1rem;
		background: #e8f5e8;
		border-radius: 6px;
		border: 1px solid #4caf50;
	}

	.user-info {
		display: flex;
		align-items: center;
		gap: 0.5rem;
	}

	.user-label {
		font-weight: 600;
		color: #495057;
	}

	.user-value {
		color: #212529;
	}

	.change-user-btn {
		background: #6c757d;
		color: white;
		border: none;
		padding: 0.5rem 1rem;
		border-radius: 4px;
		cursor: pointer;
		font-size: 0.9rem;
	}

	.change-user-btn:hover {
		background: #5a6268;
	}

	.users-loading {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		color: #6c757d;
		font-size: 0.9rem;
		padding: 1rem;
	}

	.no-users {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.75rem;
		background: #fff3cd;
		border: 1px solid #ffeaa7;
		border-radius: 4px;
		color: #856404;
		font-size: 0.9rem;
	}

	.user-search {
		margin-bottom: 1rem;
	}

	.search-input {
		width: 100%;
		padding: 0.75rem;
		border: 1px solid #ced4da;
		border-radius: 6px;
		font-size: 1rem;
	}

	.users-table-container {
		max-height: 400px;
		overflow-y: auto;
		border: 1px solid #dee2e6;
		border-radius: 6px;
		background: white;
	}

	.users-table {
		width: 100%;
		border-collapse: collapse;
	}

	.users-table th {
		background: #f8f9fa;
		padding: 0.75rem;
		text-align: left;
		font-weight: 600;
		color: #495057;
		border-bottom: 2px solid #dee2e6;
		position: sticky;
		top: 0;
		z-index: 10;
	}

	.users-table td {
		padding: 0.75rem;
		border-bottom: 1px solid #dee2e6;
		vertical-align: middle;
	}

	.user-row:hover {
		background: #f8f9fa;
	}

	.username-cell {
		font-weight: 600;
		color: #007bff;
	}

	.name-cell {
		color: #212529;
	}

	.id-cell {
		color: #6c757d;
		font-family: monospace;
	}

	.position-cell {
		color: #495057;
		font-size: 0.9rem;
	}

	.action-cell {
		text-align: center;
	}

	.select-user-btn {
		background: #28a745;
		color: white;
		border: none;
		padding: 0.4rem 0.8rem;
		border-radius: 4px;
		cursor: pointer;
		font-size: 0.85rem;
		font-weight: 500;
	}

	.select-user-btn:hover {
		background: #218838;
	}

	.no-search-results {
		padding: 2rem;
		text-align: center;
		color: #6c757d;
	}

	.receiving-user-section {
		margin-top: 1.5rem;
		padding: 1rem;
		background: #e8f5e8;
		border-radius: 6px;
		border: 1px solid #4caf50;
	}

	.receiving-user-section h4 {
		margin: 0 0 1rem 0;
		color: #2e7d32;
		font-size: 1.1rem;
		font-weight: 600;
	}

	.receiving-user-info {
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
	}

	.auto-selected-user {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.5rem;
		background: white;
		border-radius: 4px;
		border: 1px solid #c8e6c9;
	}

	.receiving-label {
		font-weight: 600;
		color: #2e7d32;
	}

	.receiving-value {
		color: #1b5e20;
		font-weight: 500;
	}

	.user-note {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		color: #2e7d32;
		font-size: 0.9rem;
		font-style: italic;
	}

	.note-icon {
		font-size: 1rem;
	}

	/* Shelf Stockers Section Styles */
	.shelf-stockers-section {
		margin-top: 1.5rem;
		padding: 1rem;
		background: #f0f8ff;
		border-radius: 6px;
		border: 1px solid #007bff;
	}

	.shelf-stockers-section h4 {
		margin: 0 0 1rem 0;
		color: #004085;
		font-size: 1.1rem;
		font-weight: 600;
	}

	.selected-stockers {
		margin-bottom: 1.5rem;
		padding: 1rem;
		background: white;
		border-radius: 6px;
		border: 1px solid #b3d7ff;
	}

	.selected-stockers h5 {
		margin: 0 0 1rem 0;
		color: #004085;
		font-size: 1rem;
		font-weight: 600;
	}

	.selected-stockers-list {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.selected-stocker-item {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 0.75rem;
		background: #e3f2fd;
		border-radius: 4px;
		border: 1px solid #bbdefb;
	}

	.stocker-info {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		color: #1565c0;
		font-weight: 500;
	}

	.stocker-badge {
		background: #1976d2;
		color: white;
		padding: 0.2rem 0.5rem;
		border-radius: 12px;
		font-size: 0.75rem;
		font-weight: 500;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.remove-stocker-btn {
		background: #dc3545;
		color: white;
		border: none;
		padding: 0.3rem 0.6rem;
		border-radius: 4px;
		cursor: pointer;
		font-size: 0.9rem;
		font-weight: 500;
		min-width: auto;
	}

	.remove-stocker-btn:hover {
		background: #c82333;
	}

	.stockers-loading {
		display: flex;
		align-items: center;
		gap: 0.75rem;
		padding: 1rem;
		background: #f8f9fa;
		border-radius: 6px;
		color: #6c757d;
	}

	.no-stockers-found {
		margin-bottom: 1rem;
	}

	.no-stockers-message {
		display: flex;
		align-items: flex-start;
		gap: 1rem;
		padding: 1rem;
		background: #fff3cd;
		border: 1px solid #ffeaa7;
		border-radius: 6px;
		color: #856404;
	}

	.select-any-user-btn {
		background: #007bff;
		color: white;
		border: none;
		padding: 0.5rem 1rem;
		border-radius: 4px;
		cursor: pointer;
		font-size: 0.9rem;
		font-weight: 500;
	}

	.select-any-user-btn:hover {
		background: #0056b3;
	}

	.stocker-search {
		margin-bottom: 1rem;
	}

	.stockers-table-container {
		max-height: 300px;
		overflow-y: auto;
		border: 1px solid #dee2e6;
		border-radius: 6px;
	}

	.stockers-table {
		width: 100%;
		border-collapse: collapse;
		background: white;
	}

	.stockers-table th {
		background: #f8f9fa;
		color: #495057;
		font-weight: 600;
		padding: 0.75rem;
		text-align: left;
		border-bottom: 2px solid #dee2e6;
		position: sticky;
		top: 0;
		z-index: 10;
	}

	.stockers-table td {
		padding: 0.75rem;
		border-bottom: 1px solid #dee2e6;
		vertical-align: middle;
	}

	.stocker-row {
		transition: background-color 0.2s;
	}

	.stocker-row:hover {
		background: #f8f9fa;
	}

	.stocker-row.is-stocker {
		background: #e3f2fd;
	}

	.stocker-row.is-selected {
		background: #d4edda;
		border-left: 4px solid #28a745;
	}

	.select-stocker-btn {
		background: #28a745;
		color: white;
		border: none;
		padding: 0.4rem 0.8rem;
		border-radius: 4px;
		cursor: pointer;
		font-size: 0.9rem;
		font-weight: 500;
	}

	.select-stocker-btn:hover {
		background: #218838;
	}

	/* Accountant Section Styles */
	.accountant-section {
		margin-top: 1.5rem;
		padding: 1rem;
		background: #fff8e1;
		border-radius: 6px;
		border: 1px solid #ff9800;
	}

	.accountant-section h4 {
		margin: 0 0 1rem 0;
		color: #e65100;
		font-size: 1.1rem;
		font-weight: 600;
	}

	.selected-accountant {
		margin-bottom: 1.5rem;
		padding: 1rem;
		background: white;
		border-radius: 6px;
		border: 1px solid #ffcc02;
		display: flex;
		align-items: center;
		justify-content: space-between;
	}

	.accountant-info {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.accountant-label {
		font-weight: 600;
		color: #e65100;
		font-size: 0.9rem;
	}

	.accountant-value {
		color: #bf360c;
		font-weight: 500;
		display: flex;
		align-items: center;
		gap: 0.5rem;
	}

	.accountant-badge {
		background: #ff9800;
		color: white;
		padding: 0.2rem 0.5rem;
		border-radius: 12px;
		font-size: 0.75rem;
		font-weight: 500;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.change-accountant-btn {
		background: #ff9800;
		color: white;
		border: none;
		padding: 0.5rem 1rem;
		border-radius: 4px;
		cursor: pointer;
		font-size: 0.9rem;
		font-weight: 500;
	}

	.change-accountant-btn:hover {
		background: #f57c00;
	}

	.accountants-loading {
		display: flex;
		align-items: center;
		gap: 0.75rem;
		padding: 1rem;
		background: #f8f9fa;
		border-radius: 6px;
		color: #6c757d;
	}

	.no-accountant-found {
		margin-bottom: 1rem;
	}

	.no-accountant-message {
		display: flex;
		align-items: flex-start;
		gap: 1rem;
		padding: 1rem;
		background: #fff3cd;
		border: 1px solid #ffeaa7;
		border-radius: 6px;
		color: #856404;
	}

	.accountant-search {
		margin-bottom: 1rem;
	}

	.accountants-table-container {
		max-height: 300px;
		overflow-y: auto;
		border: 1px solid #dee2e6;
		border-radius: 6px;
	}

	.accountants-table {
		width: 100%;
		border-collapse: collapse;
		background: white;
	}

	.accountants-table th {
		background: #f8f9fa;
		color: #495057;
		font-weight: 600;
		padding: 0.75rem;
		text-align: left;
		border-bottom: 2px solid #dee2e6;
		position: sticky;
		top: 0;
		z-index: 10;
	}

	.accountants-table td {
		padding: 0.75rem;
		border-bottom: 1px solid #dee2e6;
		vertical-align: middle;
	}

	.accountant-row {
		transition: background-color 0.2s;
	}

	.accountant-row:hover {
		background: #f8f9fa;
	}

	.accountant-row.is-accountant {
		background: #fff8e1;
	}

	.select-accountant-btn {
		background: #ff9800;
		color: white;
		border: none;
		padding: 0.4rem 0.8rem;
		border-radius: 4px;
		cursor: pointer;
		font-size: 0.9rem;
		font-weight: 500;
	}

	.select-accountant-btn:hover {
		background: #f57c00;
	}

	/* Purchasing Manager Section Styles */
	.purchasing-manager-section {
		margin-top: 1.5rem;
		padding: 1rem;
		background: #f3e5f5;
		border-radius: 6px;
		border: 1px solid #9c27b0;
	}

	.purchasing-manager-section h4 {
		margin: 0 0 1rem 0;
		color: #6a1b9a;
		font-size: 1.1rem;
		font-weight: 600;
	}

	.selected-purchasing-manager {
		margin-bottom: 1.5rem;
		padding: 1rem;
		background: white;
		border-radius: 6px;
		border: 1px solid #ce93d8;
		display: flex;
		align-items: center;
		justify-content: space-between;
	}

	.purchasing-manager-info {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.purchasing-manager-label {
		font-weight: 600;
		color: #6a1b9a;
		font-size: 0.9rem;
	}

	.purchasing-manager-value {
		color: #4a148c;
		font-weight: 500;
		display: flex;
		align-items: center;
		gap: 0.5rem;
	}

	.purchasing-manager-badge {
		background: #9c27b0;
		color: white;
		padding: 0.2rem 0.5rem;
		border-radius: 12px;
		font-size: 0.75rem;
		font-weight: 500;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.change-purchasing-manager-btn {
		background: #9c27b0;
		color: white;
		border: none;
		padding: 0.5rem 1rem;
		border-radius: 4px;
		cursor: pointer;
		font-size: 0.9rem;
		font-weight: 500;
	}

	.change-purchasing-manager-btn:hover {
		background: #7b1fa2;
	}

	.purchasing-managers-loading {
		display: flex;
		align-items: center;
		gap: 0.75rem;
		padding: 1rem;
		background: #f8f9fa;
		border-radius: 6px;
		color: #6c757d;
	}

	.no-purchasing-manager-found {
		margin-bottom: 1rem;
	}

	.no-purchasing-manager-message {
		display: flex;
		align-items: flex-start;
		gap: 1rem;
		padding: 1rem;
		background: #fff3cd;
		border: 1px solid #ffeaa7;
		border-radius: 6px;
		color: #856404;
	}

	.purchasing-manager-search {
		margin-bottom: 1rem;
	}

	.purchasing-managers-table-container {
		max-height: 300px;
		overflow-y: auto;
		border: 1px solid #dee2e6;
		border-radius: 6px;
	}

	.purchasing-managers-table {
		width: 100%;
		border-collapse: collapse;
		background: white;
	}

	.purchasing-managers-table th {
		background: #f8f9fa;
		color: #495057;
		font-weight: 600;
		padding: 0.75rem;
		text-align: left;
		border-bottom: 2px solid #dee2e6;
		position: sticky;
		top: 0;
		z-index: 10;
	}

	.purchasing-managers-table td {
		padding: 0.75rem;
		border-bottom: 1px solid #dee2e6;
		vertical-align: middle;
	}

	.purchasing-manager-row {
		transition: background-color 0.2s;
	}

	.purchasing-manager-row:hover {
		background: #f8f9fa;
	}

	.purchasing-manager-row.is-purchasing-manager {
		background: #f3e5f5;
	}

	.branch-cell {
		padding: 0.75rem;
		border-bottom: 1px solid #dee2e6;
		vertical-align: middle;
	}

	.branch-name {
		font-weight: 500;
		color: #495057;
	}

	.current-branch-badge {
		display: inline-block;
		background: #28a745;
		color: white;
		font-size: 0.75rem;
		font-weight: 600;
		padding: 2px 6px;
		border-radius: 3px;
		margin-left: 8px;
		text-transform: uppercase;
	}

	.selected-branch-info {
		color: #6c757d;
		font-style: italic;
		margin-left: 8px;
		font-size: 0.9rem;
	}

	.select-purchasing-manager-btn {
		background: #9c27b0;
		color: white;
		border: none;
		padding: 0.4rem 0.8rem;
		border-radius: 4px;
		cursor: pointer;
		font-size: 0.9rem;
		font-weight: 500;
	}

	.select-purchasing-manager-btn:hover {
		background: #7b1fa2;
	}

	/* Inventory Manager Section - Teal theme */
	.inventory-manager-section {
		margin-top: 20px;
		background: linear-gradient(135deg, #e6fffa 0%, #b2f5ea 100%);
		border: 2px solid #38b2ac;
		border-radius: 12px;
		padding: 20px;
	}

	.inventory-manager-section h4 {
		color: #234e52;
		margin-bottom: 15px;
		font-weight: 600;
	}

	.selected-inventory-manager {
		display: flex;
		justify-content: space-between;
		align-items: center;
		background: white;
		padding: 15px;
		border-radius: 8px;
		border-left: 4px solid #38b2ac;
		margin-bottom: 10px;
	}

	.inventory-manager-info {
		display: flex;
		flex-direction: column;
		gap: 5px;
	}

	.inventory-manager-label {
		font-weight: 500;
		color: #234e52;
		font-size: 14px;
	}

	.inventory-manager-value {
		font-weight: 600;
		color: #2c7a7b;
		display: flex;
		align-items: center;
		gap: 10px;
	}

	.inventory-manager-badge {
		background: #38b2ac;
		color: white;
		padding: 2px 8px;
		border-radius: 12px;
		font-size: 12px;
		font-weight: 500;
	}

	.change-inventory-manager-btn {
		background: #38b2ac;
		color: white;
		border: none;
		padding: 8px 16px;
		border-radius: 6px;
		cursor: pointer;
		font-size: 14px;
		transition: background-color 0.2s;
	}

	.change-inventory-manager-btn:hover {
		background: #319795;
	}

	.inventory-managers-loading {
		display: flex;
		align-items: center;
		gap: 10px;
		padding: 20px;
		color: #2c7a7b;
	}

	.no-inventory-manager-found {
		background: #fff5f5;
		border: 2px solid #fed7d7;
		border-radius: 8px;
		padding: 20px;
		margin: 15px 0;
	}

	.no-inventory-manager-message {
		display: flex;
		align-items: flex-start;
		gap: 15px;
	}

	.inventory-manager-search {
		margin: 15px 0;
	}

	.inventory-managers-table-container {
		max-height: 300px;
		overflow-y: auto;
		border: 1px solid #cbd5e0;
		border-radius: 8px;
	}

	.inventory-managers-table {
		width: 100%;
		border-collapse: collapse;
		background: white;
	}

	.inventory-managers-table th {
		background: #38b2ac;
		color: white;
		padding: 12px;
		text-align: left;
		font-weight: 600;
		border-bottom: 2px solid #319795;
		position: sticky;
		top: 0;
		z-index: 1;
	}

	.inventory-manager-row {
		border-bottom: 1px solid #e2e8f0;
		transition: background-color 0.2s;
	}

	.inventory-manager-row:hover {
		background: #f7fafc;
	}

	.inventory-manager-row.is-inventory-manager {
		background: #e6fffa;
	}

	.inventory-manager-row.is-inventory-manager:hover {
		background: #b2f5ea;
	}

	.inventory-managers-table td {
		padding: 12px;
		border-bottom: 1px solid #e2e8f0;
	}

	.select-inventory-manager-btn {
		background: #38b2ac;
		color: white;
		border: none;
		padding: 6px 12px;
		border-radius: 4px;
		cursor: pointer;
		font-size: 14px;
		transition: background-color 0.2s;
	}

	.select-inventory-manager-btn:hover {
		background: #319795;
	}

	/* Night Supervisors Section - Indigo theme */
	.night-supervisors-section {
		margin-top: 20px;
		background: linear-gradient(135deg, #ebf4ff 0%, #c3dafe 100%);
		border: 2px solid #5a67d8;
		border-radius: 12px;
		padding: 20px;
	}

	.night-supervisors-section h4 {
		color: #3c366b;
		margin-bottom: 15px;
		font-weight: 600;
	}

	.selected-night-supervisors {
		background: white;
		padding: 15px;
		border-radius: 8px;
		border-left: 4px solid #5a67d8;
		margin-bottom: 15px;
	}

	.selected-night-supervisors h5 {
		color: #3c366b;
		margin: 0 0 10px 0;
		font-weight: 600;
	}

	.selected-night-supervisors-list {
		display: flex;
		flex-wrap: wrap;
		gap: 10px;
	}

	.selected-night-supervisor-item {
		display: flex;
		align-items: center;
		gap: 8px;
		background: #ebf4ff;
		padding: 8px 12px;
		border-radius: 6px;
		border: 1px solid #c3dafe;
	}

	.night-supervisor-info {
		display: flex;
		align-items: center;
		gap: 8px;
		color: #3c366b;
		font-weight: 500;
	}

	.night-supervisor-badge {
		background: #5a67d8;
		color: white;
		padding: 2px 8px;
		border-radius: 12px;
		font-size: 12px;
		font-weight: 500;
	}

	.remove-night-supervisor-btn {
		background: #e53e3e;
		color: white;
		border: none;
		width: 20px;
		height: 20px;
		border-radius: 50%;
		cursor: pointer;
		font-size: 14px;
		font-weight: bold;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: background-color 0.2s;
	}

	.remove-night-supervisor-btn:hover {
		background: #c53030;
	}

	.night-supervisors-loading {
		display: flex;
		align-items: center;
		gap: 10px;
		padding: 20px;
		color: #553c9a;
	}

	.no-night-supervisors-found {
		background: #fff5f5;
		border: 2px solid #fed7d7;
		border-radius: 8px;
		padding: 20px;
		margin: 15px 0;
	}

	.no-night-supervisors-message {
		display: flex;
		align-items: flex-start;
		gap: 15px;
	}

	.night-supervisor-search {
		margin: 15px 0;
	}

	.night-supervisors-table-container {
		max-height: 300px;
		overflow-y: auto;
		border: 1px solid #cbd5e0;
		border-radius: 8px;
	}

	.night-supervisors-table {
		width: 100%;
		border-collapse: collapse;
		background: white;
	}

	.night-supervisors-table th {
		background: #5a67d8;
		color: white;
		padding: 12px;
		text-align: left;
		font-weight: 600;
		border-bottom: 2px solid #4c51bf;
		position: sticky;
		top: 0;
		z-index: 1;
	}

	.night-supervisor-row {
		border-bottom: 1px solid #e2e8f0;
		transition: background-color 0.2s;
	}

	.night-supervisor-row:hover {
		background: #f7fafc;
	}

	.night-supervisor-row.is-night-supervisor {
		background: #ebf4ff;
	}

	.night-supervisor-row.is-night-supervisor:hover {
		background: #c3dafe;
	}

	.night-supervisor-row.is-selected {
		background: #faf5ff;
		border-left: 3px solid #5a67d8;
	}

	.night-supervisors-table td {
		padding: 12px;
		border-bottom: 1px solid #e2e8f0;
	}

	.select-night-supervisor-btn {
		background: #5a67d8;
		color: white;
		border: none;
		padding: 6px 12px;
		border-radius: 4px;
		cursor: pointer;
		font-size: 14px;
		transition: background-color 0.2s;
	}

	.select-night-supervisor-btn:hover {
		background: #4c51bf;
	}

	/* Warehouse Handlers Section - Red theme */
	.warehouse-handlers-section {
		margin-top: 20px;
		background: linear-gradient(135deg, #fed7d7 0%, #feb2b2 100%);
		border: 2px solid #e53e3e;
		border-radius: 12px;
		padding: 20px;
	}

	.warehouse-handlers-section h4 {
		color: #742a2a;
		margin-bottom: 15px;
		font-weight: 600;
	}

	.selected-warehouse-handlers {
		background: white;
		padding: 15px;
		border-radius: 8px;
		border-left: 4px solid #e53e3e;
		margin-bottom: 15px;
	}

	.selected-warehouse-handlers h5 {
		color: #742a2a;
		margin: 0 0 10px 0;
		font-weight: 600;
	}

	.selected-warehouse-handlers-list {
		display: flex;
		flex-wrap: wrap;
		gap: 10px;
	}

	.selected-warehouse-handler-item {
		display: flex;
		align-items: center;
		gap: 8px;
		background: #fed7d7;
		padding: 8px 12px;
		border-radius: 6px;
		border: 1px solid #feb2b2;
	}

	.warehouse-handler-info {
		display: flex;
		align-items: center;
		gap: 8px;
		color: #742a2a;
		font-weight: 500;
	}

	.warehouse-handler-badge {
		background: #e53e3e;
		color: white;
		padding: 2px 8px;
		border-radius: 12px;
		font-size: 12px;
		font-weight: 500;
	}

	.remove-warehouse-handler-btn {
		background: #e53e3e;
		color: white;
		border: none;
		width: 20px;
		height: 20px;
		border-radius: 50%;
		cursor: pointer;
		font-size: 14px;
		font-weight: bold;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: background-color 0.2s;
	}

	.remove-warehouse-handler-btn:hover {
		background: #c53030;
	}

	.warehouse-handlers-loading {
		display: flex;
		align-items: center;
		gap: 10px;
		padding: 20px;
		color: #c53030;
	}

	.no-warehouse-handlers-found {
		background: #fff5f5;
		border: 2px solid #fed7d7;
		border-radius: 8px;
		padding: 20px;
		margin: 15px 0;
	}

	.no-warehouse-handlers-message {
		display: flex;
		align-items: flex-start;
		gap: 15px;
	}

	.warehouse-handler-search {
		margin: 15px 0;
	}

	.warehouse-handlers-table-container {
		max-height: 300px;
		overflow-y: auto;
		border: 1px solid #cbd5e0;
		border-radius: 8px;
	}

	.warehouse-handlers-table {
		width: 100%;
		border-collapse: collapse;
		background: white;
	}

	.warehouse-handlers-table th {
		background: #e53e3e;
		color: white;
		padding: 12px;
		text-align: left;
		font-weight: 600;
		border-bottom: 2px solid #c53030;
		position: sticky;
		top: 0;
		z-index: 1;
	}

	.warehouse-handler-row {
		border-bottom: 1px solid #e2e8f0;
		transition: background-color 0.2s;
	}

	.warehouse-handler-row:hover {
		background: #f7fafc;
	}

	.warehouse-handler-row.is-warehouse-handler {
		background: #fed7d7;
	}

	.warehouse-handler-row.is-warehouse-handler:hover {
		background: #feb2b2;
	}

	.warehouse-handler-row.is-selected {
		background: #faf5ff;
		border-left: 3px solid #e53e3e;
	}

	.warehouse-handlers-table td {
		padding: 12px;
		border-bottom: 1px solid #e2e8f0;
	}

	.select-warehouse-handler-btn {
		background: #e53e3e;
		color: white;
		border: none;
		padding: 6px 12px;
		border-radius: 4px;
		cursor: pointer;
		font-size: 14px;
		transition: background-color 0.2s;
	}

	.select-warehouse-handler-btn:hover {
		background: #c53030;
	}

	.no-manager-found {
		margin-bottom: 1rem;
	}

	.no-manager-message {
		display: flex;
		align-items: flex-start;
		gap: 1rem;
		padding: 1rem;
		background: #fff3cd;
		border: 1px solid #ffeaa7;
		border-radius: 6px;
		color: #856404;
	}

	.warning-icon {
		font-size: 1.5rem;
		flex-shrink: 0;
	}

	.message-content h5 {
		margin: 0 0 0.5rem 0;
		color: #856404;
		font-size: 1rem;
		font-weight: 600;
	}

	.message-content p {
		margin: 0 0 1rem 0;
		font-size: 0.9rem;
	}

	.select-responsible-btn {
		background: #007bff;
		color: white;
		border: none;
		padding: 0.5rem 1rem;
		border-radius: 4px;
		cursor: pointer;
		font-size: 0.9rem;
		font-weight: 500;
	}

	.select-responsible-btn:hover {
		background: #0056b3;
	}

	.fallback-notice {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.75rem;
		background: #e3f2fd;
		border: 1px solid #90caf9;
		border-radius: 4px;
		color: #1565c0;
		font-size: 0.9rem;
		margin-bottom: 1rem;
	}

	.info-icon {
		font-size: 1.1rem;
	}

	.is-manager {
		background: #f0f8f0 !important;
	}

	.is-manager:hover {
		background: #e8f5e8 !important;
	}

	.manager-badge {
		display: inline-block;
		background: #28a745;
		color: white;
		padding: 0.2rem 0.5rem;
		border-radius: 12px;
		font-size: 0.75rem;
		font-weight: 500;
		margin-left: 0.5rem;
	}

	.selection-info .value {
		font-weight: 600;
		color: #333;
	}

	.change-btn {
		padding: 0.5rem 1rem;
		background: #1976d2;
		color: white;
		border: none;
		border-radius: 4px;
		cursor: pointer;
		font-size: 0.9rem;
	}

	.change-btn:hover {
		background: #1565c0;
	}

	.branch-selector {
		max-width: 500px;
	}

	.form-label {
		display: block;
		margin-bottom: 0.5rem;
		color: #333;
		font-weight: 500;
	}

	.form-select {
		width: 100%;
		padding: 0.75rem;
		border: 1px solid #ddd;
		border-radius: 4px;
		font-size: 1rem;
		margin-bottom: 1rem;
	}

	.form-select:focus {
		outline: none;
		border-color: #1976d2;
		box-shadow: 0 0 0 2px rgba(25, 118, 210, 0.2);
	}

	.branch-actions {
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}

	.checkbox-label {
		display: flex;
		align-items: center;
		cursor: pointer;
		color: #333;
	}

	.checkbox-label input[type="checkbox"] {
		margin-right: 0.5rem;
	}

	.confirm-btn {
		align-self: flex-start;
		padding: 0.75rem 1.5rem;
		background: #4caf50;
		color: white;
		border: none;
		border-radius: 4px;
		cursor: pointer;
		font-size: 1rem;
		font-weight: 500;
	}

	.confirm-btn:hover {
		background: #45a049;
	}

	.loading-state, .error-state {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 1rem;
		color: #666;
	}

	.spinner {
		width: 20px;
		height: 20px;
		border: 2px solid #f3f3f3;
		border-top: 2px solid #1976d2;
		border-radius: 50%;
		animation: spin 1s linear infinite;
	}

	@keyframes spin {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}

	.retry-btn {
		padding: 0.5rem 1rem;
		background: #ff9800;
		color: white;
		border: none;
		border-radius: 4px;
		cursor: pointer;
		margin-left: 1rem;
	}

	.retry-btn:hover {
		background: #e68900;
	}

	/* Vendor Selector Styles */
	.vendor-selector {
		max-width: 100%;
	}

	.vendor-search {
		margin-bottom: 1.5rem;
	}

	.search-input-wrapper {
		position: relative;
		display: flex;
		align-items: center;
	}

	.search-icon {
		position: absolute;
		left: 1rem;
		color: #666;
		font-size: 1.1rem;
		z-index: 1;
	}

	.search-input {
		width: 100%;
		padding: 0.75rem 0.75rem 0.75rem 3rem;
		border: 1px solid #ddd;
		border-radius: 4px;
		font-size: 1rem;
	}

	.search-input:focus {
		outline: none;
		border-color: #1976d2;
		box-shadow: 0 0 0 2px rgba(25, 118, 210, 0.2);
	}

	.clear-search {
		position: absolute;
		right: 0.75rem;
		background: none;
		border: none;
		font-size: 1.2rem;
		cursor: pointer;
		color: #666;
		padding: 0.25rem;
	}

	.clear-search:hover {
		color: #333;
	}

	.search-results-info {
		margin-top: 0.5rem;
		color: #666;
		font-size: 0.9rem;
	}

	.empty-state {
		text-align: center;
		padding: 3rem 1rem;
		color: #666;
	}

	.empty-icon {
		font-size: 3rem;
		display: block;
		margin-bottom: 1rem;
	}

	.empty-state h4 {
		margin: 0 0 0.5rem 0;
		color: #333;
	}

	.empty-state p {
		margin: 0 0 1rem 0;
	}

	.clear-search-btn {
		padding: 0.5rem 1rem;
		background: #1976d2;
		color: white;
		border: none;
		border-radius: 4px;
		cursor: pointer;
	}

	.clear-search-btn:hover {
		background: #1565c0;
	}

	/* Vendor Table Styles */
	.vendor-table {
		background: white;
		border-radius: 8px;
		overflow: hidden;
		box-shadow: 0 2px 4px rgba(0,0,0,0.1);
	}

	.vendor-table table {
		width: 100%;
		border-collapse: collapse;
	}

	.vendor-table th {
		background: #f8f9fa;
		padding: 1rem;
		text-align: left;
		font-weight: 600;
		color: #333;
		border-bottom: 1px solid #e9ecef;
	}

	.vendor-table td {
		padding: 1rem;
		border-bottom: 1px solid #e9ecef;
		vertical-align: top;
	}

	.vendor-table tbody tr:hover {
		background: #f8f9fa;
	}

	.vendor-id {
		font-weight: 600;
		color: #1976d2;
	}

	.vendor-name {
		font-weight: 600;
		color: #333;
	}

	.vendor-data {
		color: #666;
	}

	.no-data {
		color: #999;
		font-style: italic;
	}

	.category-badges {
		display: flex;
		flex-wrap: wrap;
		gap: 0.25rem;
	}

	.category-badge {
		background: #e3f2fd;
		color: #1976d2;
		padding: 0.25rem 0.5rem;
		border-radius: 12px;
		font-size: 0.8rem;
		font-weight: 500;
	}

	.category-badge.more {
		background: #f5f5f5;
		color: #666;
	}

	.select-btn {
		background: #4caf50;
		color: white;
		border: none;
		padding: 0.5rem 1rem;
		border-radius: 4px;
		cursor: pointer;
		font-weight: 500;
		font-size: 0.9rem;
	}

	.select-btn:hover {
		background: #45a049;
	}

	.edit-btn {
		background: #2196f3;
		color: white;
		border: none;
		padding: 0.5rem 1rem;
		border-radius: 4px;
		cursor: pointer;
		font-weight: 500;
		font-size: 0.9rem;
		display: flex;
		align-items: center;
		gap: 0.25rem;
	}

	.edit-btn:hover {
		background: #1976d2;
	}

	.action-buttons {
		display: flex;
		gap: 0.5rem;
		flex-wrap: wrap;
	}

	.action-cell {
		min-width: 140px;
	}

	.selection-info .vendor-id {
		color: #666;
		font-weight: normal;
		margin-left: 0.5rem;
	}

	/* Column Selector Styles */
	.column-selector-section {
		margin: 16px 0;
	}

	.column-selector {
		position: relative;
		display: inline-block;
	}

	.column-selector-btn {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 8px 16px;
		background: #f8f9fa;
		border: 1px solid #dee2e6;
		border-radius: 6px;
		cursor: pointer;
		font-size: 14px;
		color: #495057;
		transition: all 0.2s;
	}

	.column-selector-btn:hover {
		background: #e9ecef;
		border-color: #adb5bd;
	}

	.dropdown-arrow {
		font-size: 12px;
		transition: transform 0.2s;
	}

	.column-dropdown {
		position: absolute;
		top: 100%;
		left: 0;
		min-width: 280px;
		background: white;
		border: 1px solid #dee2e6;
		border-radius: 8px;
		box-shadow: 0 4px 12px rgba(0,0,0,0.15);
		z-index: 1000;
		max-height: 400px;
		overflow-y: auto;
	}

	.column-controls {
		padding: 12px;
		border-bottom: 1px solid #e9ecef;
		display: flex;
		gap: 8px;
	}

	.control-btn {
		padding: 6px 12px;
		border: 1px solid #dee2e6;
		border-radius: 4px;
		background: white;
		color: #495057;
		cursor: pointer;
		font-size: 12px;
		transition: all 0.2s;
	}

	.control-btn:hover {
		background: #f8f9fa;
		border-color: #adb5bd;
	}

	.column-list {
		padding: 8px 0;
	}

	.column-item {
		display: flex;
		align-items: center;
		padding: 8px 16px;
		cursor: pointer;
		transition: background-color 0.2s;
	}

	.column-item:hover {
		background: #f8f9fa;
	}

	.column-item input[type="checkbox"] {
		margin-right: 12px;
		margin-bottom: 0;
	}

	.column-label {
		font-size: 14px;
		color: #495057;
	}

	/* Enhanced Table Styles */
	.delivery-badges {
		display: flex;
		flex-wrap: wrap;
		gap: 0.25rem;
	}

	.delivery-badge {
		background: #fff3e0;
		color: #f57c00;
		padding: 0.25rem 0.5rem;
		border-radius: 12px;
		font-size: 0.8rem;
		font-weight: 500;
	}

	.delivery-badge.more {
		background: #f5f5f5;
		color: #666;
	}

	.vendor-status {
		text-align: center;
	}

	.status-badge {
		padding: 0.25rem 0.75rem;
		border-radius: 12px;
		font-size: 0.8rem;
		font-weight: 500;
		text-transform: uppercase;
	}

	.status-badge.active {
		background: #e8f5e8;
		color: #2e7d32;
	}

	.status-badge.inactive {
		background: #ffebee;
		color: #c62828;
	}

	.status-badge.blacklisted {
		background: #fce4ec;
		color: #ad1457;
	}

	.location-btn {
		background: #2196f3;
		color: white;
		border: none;
		padding: 0.25rem 0.5rem;
		border-radius: 4px;
		cursor: pointer;
		font-size: 0.8rem;
		transition: background-color 0.2s;
	}

	.location-btn:hover {
		background: #1976d2;
	}

	/* Return Policy Styles */
	.return-policy {
		padding: 0.25rem 0.5rem;
		border-radius: 12px;
		font-size: 0.8rem;
		font-weight: 500;
		text-transform: capitalize;
	}

	.return-policy.accepted {
		background: #e8f5e8;
		color: #2e7d32;
	}

	.return-policy.not-accepted {
		background: #ffebee;
		color: #c62828;
	}

	.return-policy.true {
		background: #ffebee;
		color: #c62828;
	}

	.return-policy.false {
		background: #e8f5e8;
		color: #2e7d32;
	}

	/* VAT Status Styles */
	.vat-status {
		padding: 0.25rem 0.5rem;
		border-radius: 12px;
		font-size: 0.8rem;
		font-weight: 500;
	}

	.vat-status.vat-applicable {
		background: #e3f2fd;
		color: #1976d2;
	}

	.vat-status.vat-not-applicable {
		background: #fff3e0;
		color: #f57c00;
	}

	/* Step 3: Bill Information Styles */
	.bill-info-grid {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 2rem;
		margin: 2rem 0;
		max-width: 1200px;
	}

	.date-field, .amount-field, .bill-number-field {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.date-field label, .amount-field label, .bill-number-field label {
		font-weight: 600;
		color: #333;
		font-size: 1rem;
	}

	.required {
		color: #e53e3e;
		font-weight: bold;
	}

	.readonly-input {
		padding: 0.75rem;
		border: 2px solid #e0e0e0;
		border-radius: 8px;
		background-color: #f5f5f5;
		color: #666;
		font-size: 1rem;
		cursor: not-allowed;
		transition: all 0.2s ease;
	}

	.readonly-input:focus {
		outline: none;
		border-color: #ccc;
	}

	.editable-input {
		padding: 0.75rem;
		border: 2px solid #e0e0e0;
		border-radius: 8px;
		background-color: white;
		color: #333;
		font-size: 1rem;
		transition: all 0.2s ease;
	}

	.editable-input:invalid, .editable-input[required]:not(:focus):invalid {
		border-color: #fed7d7;
		background-color: #fef5f5;
	}

	.editable-input:required:not(:focus):not([value=""]):invalid {
		border-color: #e53e3e;
		background-color: #fef5f5;
	}

	.editable-input:focus {
		outline: none;
		border-color: #667eea;
		box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
	}

	/* Return Policy Section Styles */
	.return-policy-section {
		margin: 2rem 0;
		padding: 1.5rem;
		background: #f8f9fa;
		border-radius: 12px;
		border-left: 4px solid #667eea;
	}

	.return-policy-section h4 {
		margin: 0 0 1rem 0;
		color: #333;
		font-size: 1.1rem;
		font-weight: 600;
	}

	.policy-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
		gap: 1rem;
	}

	.policy-item {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 0.75rem;
		background: white;
		border-radius: 8px;
		border: 1px solid #e0e0e0;
		transition: all 0.2s ease;
	}

	.policy-item:hover {
		border-color: #ccc;
		box-shadow: 0 2px 4px rgba(0,0,0,0.1);
	}

	.policy-item label {
		font-weight: 600;
		color: #333;
		font-size: 0.9rem;
	}

	.policy-value {
		font-weight: 500;
		padding: 0.3rem 0.8rem;
		border-radius: 15px;
		font-size: 0.8rem;
		text-transform: capitalize;
		text-align: center;
		min-width: 80px;
	}

	.policy-value.accepted {
		background: #e8f5e8;
		color: #2e7d32;
	}

	.policy-value.rejected {
		background: #ffebee;
		color: #d32f2f;
	}

	.policy-value.yes {
		background: #ffebee;
		color: #d32f2f;
	}

	.policy-value.no {
		background: #e8f5e8;
		color: #2e7d32;
	}

	.policy-value.not-specified {
		background: #fff3e0;
		color: #f57c00;
	}

	.policy-value.returns-accepted {
		background: #e8f5e8;
		color: #2e7d32;
		font-weight: 600;
	}

	.policy-value.no-returns {
		background: #ffebee;
		color: #d32f2f;
		font-weight: 600;
	}

	/* Return Processing Section Styles */
	.return-processing-section {
		margin: 2rem 0;
		padding: 1.5rem;
		background: #f0f4ff;
		border-radius: 12px;
		border-left: 4px solid #2196f3;
	}

	.return-processing-section h4 {
		margin: 0 0 0.5rem 0;
		color: #1976d2;
		font-size: 1.1rem;
		font-weight: 600;
	}

	.section-description {
		margin: 0 0 1.5rem 0;
		color: #666;
		font-size: 0.9rem;
	}

	.return-questions-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
		gap: 1.5rem;
		margin-bottom: 2rem;
	}

	.return-question {
		background: white;
		padding: 1rem;
		border-radius: 8px;
		border: 1px solid #e3f2fd;
		box-shadow: 0 2px 4px rgba(0,0,0,0.05);
	}

	.return-question label {
		display: block;
		font-weight: 600;
		color: #333;
		margin-bottom: 0.5rem;
		font-size: 0.9rem;
	}

	.return-dropdown {
		width: 100%;
		padding: 0.5rem;
		border: 2px solid #e0e0e0;
		border-radius: 6px;
		background: white;
		font-size: 0.9rem;
		margin-bottom: 0.5rem;
	}

	.return-dropdown:focus {
		outline: none;
		border-color: #2196f3;
	}

	.return-amount-input {
		width: 100%;
		padding: 0.5rem;
		border: 2px solid #e0e0e0;
		border-radius: 6px;
		background: white;
		font-size: 0.9rem;
	}

	.return-amount-input:focus {
		outline: none;
		border-color: #2196f3;
		box-shadow: 0 0 0 3px rgba(33, 150, 243, 0.1);
	}

	/* Bill Summary Styles */
	.bill-summary {
		background: white;
		padding: 1.5rem;
		border-radius: 8px;
		border: 2px solid #e3f2fd;
		box-shadow: 0 2px 8px rgba(0,0,0,0.1);
	}

	.summary-row {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 0.75rem 0;
		border-bottom: 1px solid #f0f0f0;
	}

	.summary-row:last-child {
		border-bottom: none;
	}

	.summary-row.final-amount {
		border-top: 2px solid #2196f3;
		font-weight: 600;
		font-size: 1.1rem;
		background: #f8fcff;
		margin-top: 0.5rem;
		padding: 1rem 0;
		border-radius: 4px;
	}

	.summary-row label {
		font-weight: 600;
		color: #333;
	}

	.amount-display {
		font-size: 1.1rem;
		font-weight: 600;
		color: #2e7d32;
	}

	.amount-display.return-amount {
		color: #d32f2f;
	}

	.final-amount .amount-display {
		color: #1976d2;
		font-size: 1.2rem;
	}

	/* Payment Information Section Styles */
	.payment-section {
		margin: 2rem 0;
		padding: 1.5rem;
		background: #f8fcf8;
		border-radius: 12px;
		border-left: 4px solid #4caf50;
	}

	.payment-section h4 {
		margin: 0 0 0.5rem 0;
		color: #2e7d32;
		font-size: 1.1rem;
		font-weight: 600;
	}

	.payment-grid {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 2rem;
		margin: 1.5rem 0;
	}

	.payment-field {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.payment-field label {
		font-weight: 600;
		color: #333;
		font-size: 1rem;
	}

	.readonly-input {
		background: #f8f9fa;
		border: 1px solid #dee2e6;
		border-radius: 6px;
		padding: 0.75rem;
		font-size: 1rem;
		color: #495057;
		cursor: not-allowed;
	}

	.due-date-notice {
		background: #e3f2fd;
		border: 1px solid #90caf9;
		border-radius: 6px;
		padding: 0.75rem;
		text-align: center;
	}

	.notice-text {
		color: #1565c0;
		font-size: 0.9rem;
		font-style: italic;
	}

	.due-date-section {
		background: #f8f9fa;
		border: 1px solid #dee2e6;
		border-radius: 8px;
		padding: 1.5rem;
		margin: 1.5rem 0;
	}

	.due-date-section h4 {
		color: #495057;
		margin-bottom: 0.5rem;
		font-size: 1.1rem;
		font-weight: 600;
	}

	.due-date-field {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
		margin-top: 1rem;
	}

	.due-date-field label {
		font-weight: 600;
		color: #333;
		font-size: 1rem;
	}

	.calculation-info {
		font-size: 0.85rem;
		color: #6c757d;
		font-style: italic;
		margin-top: 0.25rem;
	}

	.vat-verification-section {
		background: #f8f9fa;
		border: 1px solid #dee2e6;
		border-radius: 8px;
		padding: 1.5rem;
		margin: 1.5rem 0;
	}

	.vat-verification-section h4 {
		color: #495057;
		margin-bottom: 0.5rem;
		font-size: 1.1rem;
		font-weight: 600;
	}

	.vat-not-applicable {
		background: #e3f2fd;
		border: 1px solid #90caf9;
		border-radius: 6px;
		padding: 0.75rem;
		display: flex;
		align-items: center;
		gap: 0.5rem;
		color: #1565c0;
		font-size: 0.9rem;
	}

	.info-icon {
		font-size: 1.1rem;
	}

	.vat-grid {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 1.5rem;
		margin: 1rem 0;
	}

	.vat-field {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.vat-field label {
		font-weight: 600;
		color: #333;
		font-size: 1rem;
	}

	.readonly-input.masked-vat {
		background: #f8f9fa;
		border: 2px solid #6c757d;
		color: #495057;
		font-family: 'Courier New', monospace;
		font-weight: 600;
		letter-spacing: 2px;
		font-size: 1.1rem;
	}

	.vat-hint {
		color: #6c757d;
		font-size: 0.85rem;
		font-style: italic;
		margin-top: 0.25rem;
	}

	.vat-status {
		margin-top: 1rem;
		padding: 1rem;
		border-radius: 6px;
	}

	.vat-match {
		background: #d4edda;
		border: 1px solid #c3e6cb;
		color: #155724;
		padding: 0.75rem;
		border-radius: 6px;
		display: flex;
		align-items: center;
		gap: 0.5rem;
	}

	.vat-mismatch {
		background: #fff3cd;
		border: 1px solid #ffeaa7;
		color: #856404;
		padding: 0.75rem;
		border-radius: 6px;
		display: flex;
		align-items: center;
		gap: 0.5rem;
		margin-bottom: 1rem;
	}

	.status-icon {
		font-size: 1.1rem;
	}

	.mismatch-reason {
		margin-top: 1rem;
	}

	.mismatch-reason label {
		font-weight: 600;
		color: #333;
		font-size: 1rem;
		display: block;
		margin-bottom: 0.5rem;
	}

	.reason-textarea {
		width: 100%;
		border: 1px solid #ced4da;
		border-radius: 6px;
		padding: 0.75rem;
		font-size: 1rem;
		resize: vertical;
		min-height: 80px;
	}

	.reason-note {
		font-size: 0.85rem;
		color: #6c757d;
		margin-top: 0.5rem;
		font-style: italic;
	}

	.payment-notice {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		background: #fff3cd;
		border: 1px solid #ffeaa7;
		border-radius: 6px;
		padding: 0.75rem;
		margin-top: 1rem;
		font-size: 0.9rem;
		color: #856404;
	}

	.notice-icon {
		font-size: 1.1rem;
	}

	.payment-actions {
		display: flex;
		gap: 1rem;
		margin-top: 1rem;
		justify-content: flex-end;
	}

	.update-vendor-btn {
		background: #2196f3;
		color: white;
		border: none;
		padding: 0.75rem 1.25rem;
		border-radius: 6px;
		cursor: pointer;
		font-size: 0.9rem;
		font-weight: 500;
		transition: background-color 0.2s ease;
	}

	.update-vendor-btn:hover {
		background: #1976d2;
	}

	.update-receiving-btn {
		background: #4caf50;
		color: white;
		border: none;
		padding: 0.75rem 1.25rem;
		border-radius: 6px;
		cursor: pointer;
		font-size: 0.9rem;
		font-weight: 500;
		transition: background-color 0.2s ease;
	}

	.update-receiving-btn:hover {
		background: #388e3c;
	}

	.step-actions {
		display: flex;
		justify-content: space-between;
		margin-top: 2rem;
		padding-top: 1.5rem;
		border-top: 1px solid #e0e0e0;
	}

	/* Step Navigation Buttons */
	.step-navigation {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 15px;
		margin: 30px 0;
		padding: 20px;
		background: linear-gradient(135deg, #e8f5e8 0%, #f0f8f0 100%);
		border: 2px solid #4caf50;
		border-radius: 12px;
	}

	.step-complete-info {
		display: flex;
		align-items: center;
		gap: 10px;
		color: #2e7d32;
		font-weight: 600;
		font-size: 16px;
	}

	.step-complete-icon {
		font-size: 20px;
	}

	.step-complete-text {
		color: #2e7d32;
	}

	.step-incomplete-icon {
		font-size: 20px;
	}

	.step-incomplete-text {
		color: #f57c00;
		font-weight: 500;
	}

	.continue-step-btn {
		background: linear-gradient(135deg, #4caf50 0%, #66bb6a 100%);
		color: white;
		border: none;
		padding: 12px 24px;
		border-radius: 8px;
		cursor: pointer;
		font-size: 16px;
		font-weight: 600;
		transition: all 0.3s ease;
		box-shadow: 0 4px 12px rgba(76, 175, 80, 0.3);
		text-transform: none;
	}

	.continue-step-btn:hover:not(:disabled) {
		background: linear-gradient(135deg, #388e3c 0%, #4caf50 100%);
		transform: translateY(-2px);
		box-shadow: 0 6px 16px rgba(76, 175, 80, 0.4);
	}

	.continue-step-btn:active:not(:disabled) {
		transform: translateY(0);
		box-shadow: 0 2px 8px rgba(76, 175, 80, 0.3);
	}

	.continue-step-btn:disabled {
		background: linear-gradient(135deg, #bdbdbd 0%, #9e9e9e 100%);
		cursor: not-allowed;
		transform: none;
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
		opacity: 0.6;
	}

	.save-continue-btn {
		background: linear-gradient(135deg, #2196f3 0%, #1976d2 100%);
		color: white;
		border: none;
		border-radius: 12px;
		padding: 1rem 2rem;
		font-size: 1.1rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.3s ease;
		box-shadow: 0 4px 12px rgba(33, 150, 243, 0.3);
		display: flex;
		align-items: center;
		gap: 0.5rem;
	}

	.save-continue-btn:hover {
		background: linear-gradient(135deg, #1976d2 0%, #1565c0 100%);
		transform: translateY(-2px);
		box-shadow: 0 6px 16px rgba(33, 150, 243, 0.4);
	}

	.save-continue-btn:active {
		transform: translateY(0);
		box-shadow: 0 2px 8px rgba(33, 150, 243, 0.3);
	}

	.secondary-btn {
		background: #6c757d;
		color: white;
		border: none;
		padding: 0.8rem 1.5rem;
		border-radius: 8px;
		cursor: pointer;
		font-size: 1rem;
		font-weight: 500;
		transition: all 0.2s ease;
		display: flex;
		align-items: center;
		gap: 0.5rem;
	}

	.secondary-btn:hover {
		background: #5a6268;
		transform: translateY(-1px);
	}

	.primary-btn {
		background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
		color: white;
		border: none;
		padding: 0.8rem 1.5rem;
		border-radius: 8px;
		cursor: pointer;
		font-size: 1rem;
		font-weight: 500;
		transition: all 0.2s ease;
		display: flex;
		align-items: center;
		gap: 0.5rem;
	}

	.primary-btn:hover {
		transform: translateY(-1px);
		box-shadow: 0 4px 12px rgba(102, 126, 234, 0.4);
	}

	/* Responsive design for bill information */
	@media (max-width: 1024px) {
		.bill-info-grid {
			grid-template-columns: 1fr 1fr;
			max-width: 800px;
		}
	}

	@media (max-width: 768px) {
		.bill-info-grid {
			grid-template-columns: 1fr;
			gap: 1.5rem;
			max-width: 500px;
		}

		.step-actions {
			flex-direction: column;
			gap: 1rem;
		}

		.secondary-btn,
		.primary-btn {
			width: 100%;
			justify-content: center;
		}
	}

	/* Step 4: Receiving Summary */
	.receiving-summary {
		background: #f8f9fa;
		border: 1px solid #dee2e6;
		border-radius: 12px;
		padding: 2rem;
		margin-bottom: 2rem;
	}

	.receiving-summary h4 {
		color: #495057;
		margin-bottom: 1.5rem;
		font-size: 1.3rem;
		font-weight: 600;
		display: flex;
		align-items: center;
		gap: 0.5rem;
	}

	.receiving-summary h4::before {
		content: "📋";
		font-size: 1.2rem;
	}

	.step-summary {
		background: #ffffff;
		border: 1px solid #e9ecef;
		border-radius: 8px;
		padding: 1.5rem;
		margin-bottom: 1.5rem;
		box-shadow: 0 2px 4px rgba(0,0,0,0.05);
	}

	.step-summary h5 {
		color: #2c5aa0;
		margin-bottom: 1rem;
		font-size: 1.1rem;
		font-weight: 600;
		border-bottom: 2px solid #e9ecef;
		padding-bottom: 0.5rem;
	}

	.step-summary:last-child {
		margin-bottom: 0;
	}

	.summary-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
		gap: 1rem;
	}

	.summary-item {
		background: white;
		padding: 1rem;
		border-radius: 8px;
		border-left: 4px solid #1976d2;
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.summary-item label {
		font-weight: 600;
		color: #495057;
		font-size: 0.9rem;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.summary-item span {
		color: #212529;
		font-size: 1rem;
		font-weight: 500;
	}

	@media (max-width: 768px) {
		.summary-grid {
			grid-template-columns: 1fr;
		}
	}

	/* Clearance Certification Styles */
	.clearance-section {
		text-align: center;
		padding: 2rem;
	}

	.generate-cert-btn {
		background: #28a745;
		color: white;
		border: none;
		border-radius: 12px;
		padding: 1.5rem 3rem;
		font-size: 1.2rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.3s ease;
		box-shadow: 0 4px 12px rgba(40, 167, 69, 0.3);
	}

	.generate-cert-btn:hover {
		background: #218838;
		transform: translateY(-2px);
		box-shadow: 0 6px 16px rgba(40, 167, 69, 0.4);
	}

	.generate-cert-btn-disabled {
		background: #6c757d;
		color: #adb5bd;
		border: none;
		border-radius: 12px;
		padding: 1.5rem 3rem;
		font-size: 1.2rem;
		font-weight: 600;
		cursor: not-allowed;
		box-shadow: 0 4px 12px rgba(108, 117, 125, 0.3);
	}

	.warning-text {
		color: #dc3545;
		margin-top: 1rem;
		font-weight: 500;
		text-align: center;
	}

	.certification-modal {
		position: fixed;
		top: 0;
		left: 0;
		width: 100%;
		height: 100%;
		background: rgba(0, 0, 0, 0.8);
		display: flex;
		justify-content: center;
		align-items: center;
		z-index: 1000;
	}

	.certification-content {
		background: white;
		border-radius: 12px;
		width: 95%;
		max-width: 850px;
		max-height: 95vh;
		overflow-y: auto;
		box-shadow: 0 20px 40px rgba(0, 0, 0, 0.3);
		/* Better support for A4 content with proper width */
		min-height: 80vh;
	}

	.certification-header {
		display: flex;
		justify-content: space-between;
		padding: 1rem;
		border-bottom: 1px solid #dee2e6;
		background: #f8f9fa;
		border-radius: 12px 12px 0 0;
	}

	.close-btn, .print-btn {
		background: none;
		border: none;
		font-size: 1.5rem;
		cursor: pointer;
		padding: 0.5rem;
		border-radius: 6px;
		transition: background-color 0.2s;
	}

	.close-btn:hover {
		background: #dc3545;
		color: white;
	}

	.print-btn:hover {
		background: #007bff;
		color: white;
	}

	.certification-template {
		padding: 1rem;
		background: white;
		font-family: 'Arial', sans-serif;
		/* A4 Size Dimensions - Fixed width to prevent overflow */
		width: 190mm;
		max-width: 190mm;
		min-height: 297mm;
		margin: 0 auto;
		box-sizing: border-box;
		page-break-inside: avoid;
		font-size: 0.8rem;
		line-height: 1.2;
		overflow: hidden;
	}

	/* A4 Print Styles */
	@media print {
		.certification-template {
			width: 190mm;
			max-width: 190mm;
			height: auto;
			margin: 0;
			padding: 8mm;
			box-shadow: none;
			page-break-inside: avoid;
			font-size: 0.75rem;
			overflow: hidden;
		}
		
		@page {
			size: A4;
			margin: 10mm;
		}
	}

	.cert-header {
		text-align: center;
		margin-bottom: 1rem;
		border-bottom: 2px solid #2c5aa0;
		padding-bottom: 0.75rem;
	}

	.cert-logo {
		margin-bottom: 0.5rem;
	}

	.cert-logo .logo {
		width: 100px;
		height: 75px;
		margin: 0 auto;
		display: block;
		border: 2px solid #ff6b35;
		border-radius: 6px;
		padding: 8px;
		background: white;
		box-shadow: 0 2px 6px rgba(255, 107, 53, 0.2);
		object-fit: contain;
	}

	.cert-title {
		margin-top: 0.5rem;
	}

	.title-english {
		color: #2c5aa0;
		margin: 0.15rem 0;
		font-size: 1.4rem;
		font-weight: 700;
		letter-spacing: 0.5px;
		text-transform: uppercase;
	}

	.title-arabic {
		color: #2c5aa0;
		margin: 0.15rem 0;
		font-size: 1.2rem;
		font-weight: 700;
		direction: rtl;
		font-family: 'Arial', 'Tahoma', sans-serif;
	}

	.cert-details {
		margin: 1rem 0;
	}

	.cert-row {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 0.35rem 0;
		border-bottom: 1px solid #eee;
		min-height: 25px;
	}

	.cert-row.final-amount {
		border-bottom: 2px solid #2c5aa0;
		font-weight: 700;
		font-size: 0.9rem;
		color: #2c5aa0;
		background: #f8f9fa;
		padding: 0.5rem;
		margin: 0.15rem 0;
		border-radius: 3px;
	}

	.label-group {
		display: flex;
		flex-direction: column;
		min-width: 160px;
	}

	.label-english {
		font-weight: 600;
		color: #495057;
		font-size: 0.75rem;
		margin-bottom: 1px;
	}

	.label-arabic {
		font-weight: 600;
		color: #6c757d;
		font-size: 0.7rem;
		direction: rtl;
		font-family: 'Arial', 'Tahoma', sans-serif;
	}

	.cert-row .value {
		color: #212529;
		text-align: right;
		font-weight: 500;
		min-width: 100px;
		font-size: 0.8rem;
	}

	/* Returns Section Styles - Ultra Compact */
	.returns-section {
		margin: 0.75rem 0;
		padding: 0.5rem;
		background: #f8f9fa;
		border-radius: 4px;
		border: 1px solid #dee2e6;
	}

	.returns-header {
		border-bottom: 1px solid #2c5aa0;
		padding-bottom: 0.15rem;
		margin-bottom: 0.5rem;
	}

	.returns-header .label-group {
		min-width: auto;
	}

	.returns-header .label-english {
		font-size: 0.85rem;
		font-weight: 700;
		color: #2c5aa0;
	}

	.returns-header .label-arabic {
		font-size: 0.75rem;
		font-weight: 700;
		color: #2c5aa0;
	}

	.return-row {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 0.15rem 0;
		border-bottom: 1px solid #e9ecef;
	}

	.return-row.total-returns {
		border-bottom: none;
		border-top: 1px solid #2c5aa0;
		padding-top: 0.25rem;
		margin-top: 0.15rem;
		font-weight: 700;
	}

	.return-type {
		display: flex;
		flex-direction: column;
		min-width: 120px;
	}

	.type-english {
		font-weight: 600;
		color: #495057;
		font-size: 0.7rem;
	}

	.type-arabic {
		font-weight: 600;
		color: #6c757d;
		font-size: 0.65rem;
		direction: rtl;
		font-family: 'Arial', 'Tahoma', sans-serif;
	}

	.return-details {
		display: flex;
		gap: 0.5rem;
		align-items: center;
	}

	.status {
		padding: 0.1rem 0.25rem;
		border-radius: 2px;
		font-size: 0.65rem;
		font-weight: 600;
		min-width: 50px;
		text-align: center;
	}

	.status.yes {
		background: #d4edda;
		color: #155724;
		border: 1px solid #c3e6cb;
	}

	.status.no {
		background: #f8d7da;
		color: #721c24;
		border: 1px solid #f5c6cb;
	}

	.amount {
		font-weight: 600;
		color: #212529;
		min-width: 40px;
		text-align: right;
		font-size: 0.75rem;
	}

	.amount.total {
		font-size: 0.85rem;
		color: #2c5aa0;
	}

	.signatures-section {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 1.5rem;
		margin: 1rem 0;
		padding: 1rem;
		background: #f8f9fa;
		border-radius: 4px;
	}

	.signature-box {
		text-align: center;
	}

	.signature-line {
		border-top: 2px solid #495057;
		margin-bottom: 0.5rem;
		margin-top: 2rem;
	}

	.signature-labels {
		margin-bottom: 0.15rem;
	}

	.signature-box .label-english {
		font-weight: 600;
		color: #495057;
		display: block;
		margin-bottom: 0.1rem;
		font-size: 0.75rem;
	}

	.signature-box .label-arabic {
		font-weight: 600;
		color: #6c757d;
		display: block;
		direction: rtl;
		font-family: 'Arial', 'Tahoma', sans-serif;
		font-size: 0.7rem;
	}

	.signature-box p {
		margin: 0.15rem 0 0 0;
		color: #6c757d;
		font-style: italic;
		font-size: 0.7rem;
	}

	.cert-footer {
		text-align: center;
		margin-top: 1rem;
		padding-top: 0.75rem;
		border-top: 1px solid #dee2e6;
		color: #495057;
	}

	.footer-english {
		margin: 0.15rem 0;
		font-size: 0.8rem;
		line-height: 1.3;
	}

	.footer-arabic {
		margin: 0.15rem 0;
		direction: rtl;
		font-family: 'Arial', 'Tahoma', sans-serif;
		font-size: 0.75rem;
		line-height: 1.4;
	}

	.date-stamp {
		margin-top: 0.5rem;
		padding-top: 0.5rem;
		border-top: 1px solid #dee2e6;
		display: flex;
		justify-content: space-between;
		align-items: center;
	}

	.date-english {
		color: #2c5aa0;
		font-size: 0.8rem;
	}

	.date-arabic {
		color: #2c5aa0;
		direction: rtl;
		font-family: 'Arial', 'Tahoma', sans-serif;
		font-size: 0.75rem;
	}

	.cert-actions {
		display: flex;
		justify-content: center;
		gap: 1rem;
		padding: 1.5rem;
		background: #f8f9fa;
		border-radius: 0 0 12px 12px;
	}

	.save-btn, .cancel-btn {
		padding: 0.75rem 2rem;
		border: none;
		border-radius: 8px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
	}

	.save-btn {
		background: #28a745;
		color: white;
	}

	.save-btn:hover {
		background: #218838;
	}

	.cancel-btn {
		background: #6c757d;
		color: white;
	}

	.cancel-btn:hover {
		background: #5a6268;
	}

	@media print {
		.certification-header,
		.cert-actions {
			display: none !important;
		}
		
		.certification-content {
			width: 100%;
			max-width: none;
			box-shadow: none;
			border-radius: 0;
		}
		
		.certification-template {
			padding: 1rem;
		}
	}

	/* Vendor Update Popup Styles */
	.modal-overlay {
		position: fixed;
		top: 0;
		left: 0;
		width: 100%;
		height: 100%;
		background: rgba(0, 0, 0, 0.6);
		display: flex;
		justify-content: center;
		align-items: center;
		z-index: 10000;
	}

	.vendor-update-modal {
		background: white;
		border-radius: 12px;
		width: 90%;
		max-width: 500px;
		max-height: 90vh;
		overflow-y: auto;
		box-shadow: 0 10px 30px rgba(0, 0, 0, 0.3);
		animation: modalSlideIn 0.3s ease-out;
	}

	@keyframes modalSlideIn {
		from {
			opacity: 0;
			transform: translateY(-20px) scale(0.95);
		}
		to {
			opacity: 1;
			transform: translateY(0) scale(1);
		}
	}

	.modal-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 1.5rem;
		border-bottom: 1px solid #e5e7eb;
		background: #f8fafc;
		border-radius: 12px 12px 0 0;
	}

	.modal-header h3 {
		margin: 0;
		color: #1f2937;
		font-size: 1.25rem;
		font-weight: 600;
	}

	.close-btn {
		background: none;
		border: none;
		font-size: 24px;
		color: #6b7280;
		cursor: pointer;
		width: 32px;
		height: 32px;
		border-radius: 50%;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: all 0.2s;
	}

	.close-btn:hover {
		background: #f3f4f6;
		color: #374151;
	}

	.modal-content {
		padding: 1.5rem;
	}

	.vendor-info {
		background: #f0f9ff;
		border: 1px solid #bae6fd;
		border-radius: 8px;
		padding: 1rem;
		margin-bottom: 1rem;
		color: #0c4a6e;
	}

	.missing-info-message {
		color: #d97706;
		background: #fef3c7;
		border: 1px solid #fcd34d;
		border-radius: 8px;
		padding: 1rem;
		margin-bottom: 1.5rem;
		font-size: 0.95rem;
	}

	.form-group {
		margin-bottom: 1.25rem;
	}

	.form-group label {
		display: block;
		margin-bottom: 0.5rem;
		color: #374151;
		font-weight: 500;
		font-size: 0.95rem;
	}

	.form-input {
		width: 100%;
		padding: 0.75rem;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 1rem;
		transition: border-color 0.2s, box-shadow 0.2s;
		box-sizing: border-box;
	}

	.form-input:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.modal-actions {
		display: flex;
		gap: 1rem;
		padding: 1.5rem;
		border-top: 1px solid #e5e7eb;
		background: #f8fafc;
		border-radius: 0 0 12px 12px;
	}

	.btn-update {
		flex: 1;
		background: #10b981;
		color: white;
		border: none;
		padding: 0.75rem 1.5rem;
		border-radius: 6px;
		font-weight: 500;
		cursor: pointer;
		transition: background-color 0.2s;
	}

	.btn-update:hover:not(:disabled) {
		background: #059669;
	}

	.btn-update:disabled {
		background: #9ca3af;
		cursor: not-allowed;
	}

	.btn-skip {
		flex: 1;
		background: #6b7280;
		color: white;
		border: none;
		padding: 0.75rem 1.5rem;
		border-radius: 6px;
		font-weight: 500;
		cursor: pointer;
		transition: background-color 0.2s;
	}

	.btn-skip:hover:not(:disabled) {
		background: #4b5563;
	}

	.btn-skip:disabled {
		background: #9ca3af;
		cursor: not-allowed;
	}
</style>

<!-- Vendor Update Popup -->
{#if showVendorUpdatePopup && vendorToUpdate}
<div class="modal-overlay" on:click={closeVendorUpdatePopup}>
  <div class="vendor-update-modal" on:click|stopPropagation>
    <div class="modal-header">
      <h3>Update Vendor Information</h3>
      <button class="close-btn" on:click={closeVendorUpdatePopup}>×</button>
    </div>
    
    <div class="modal-content">
      <p class="vendor-info">
        <strong>Vendor:</strong> {vendorToUpdate.vendor_name}
      </p>
      <p class="missing-info-message">
        This vendor is missing some important information. Would you like to update it now?
      </p>
      
      <div class="form-group">
        <label for="salesmanName">Salesman Name:</label>
        <input 
          id="salesmanName"
          type="text" 
          bind:value={updatedSalesmanName}
          placeholder="Enter salesman name"
          class="form-input"
        />
      </div>
      
      <div class="form-group">
        <label for="salesmanContact">Salesman Contact:</label>
        <input 
          id="salesmanContact"
          type="text" 
          bind:value={updatedSalesmanContact}
          placeholder="Enter salesman contact number"
          class="form-input"
        />
      </div>
      
      <div class="form-group">
        <label for="vatNumber">VAT Number:</label>
        <input 
          id="vatNumber"
          type="text" 
          bind:value={updatedVatNumber}
          placeholder="Enter VAT number"
          class="form-input"
        />
      </div>
    </div>
    
    <div class="modal-actions">
      <button 
        class="btn-update" 
        on:click={updateVendorInformation}
        disabled={isUpdatingVendor}
      >
        {isUpdatingVendor ? 'Updating...' : 'Update & Continue'}
      </button>
      <button 
        class="btn-skip" 
        on:click={skipVendorUpdate}
        disabled={isUpdatingVendor}
      >
        Not Now
      </button>
    </div>
  </div>
</div>
{/if}

<!-- Clearance Certificate Manager -->
<ClearanceCertificateManager 
  bind:show={showCertificateManager}
  receivingRecord={currentReceivingRecord}
  on:close={handleCertificateManagerClose}
/>