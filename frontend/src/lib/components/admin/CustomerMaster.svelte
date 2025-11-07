<script lang="ts">
  import { onMount } from "svelte";
  import { supabase } from "$lib/utils/supabase";
  import { currentUser } from "$lib/utils/persistentAuth";
  import { notificationManagement } from '$lib/utils/notificationManagement';
  import { t } from "$lib/i18n";
  import { openWindow } from '$lib/utils/windowManagerUtils';
  import CustomerAccountRecoveryManager from './CustomerAccountRecoveryManager.svelte';

  interface Customer {
    id: string;
    name: string;
    access_code: string;
    whatsapp_number: string;
    registration_status: "pending" | "approved" | "rejected" | "suspended";
    registration_notes: string;
    approved_by: string;
    approved_at: string;
    access_code_generated_at: string;
    last_login_at: string;
    created_at: string;
    updated_at: string;
  }

  let customers: Customer[] = [];
  let loading = true;
  let searchTerm = "";
  let statusFilter = "all";
  let selectedCustomer: Customer | null = null;
  let showApprovalModal = false;
  let approvalNotes = "";
  let actionType: "approve" | "reject" = "approve";
  let generatedAccessCode = "";
  let showAccessCodeInput = false;
  let showWhatsAppButton = false;
  let isGeneratingCode = false;
  let isSavingApproval = false;
  
  // Statistics
  let pendingRegistrations = 0;
  let pendingRecoveryRequests = 0;

  onMount(() => {
    loadCustomers();
    loadStatistics();
  });

  async function loadCustomers() {
    try {
      loading = true;
      console.log("🔍 [CustomerMaster] Loading customers...");
      const { data, error } = await supabase.rpc("get_customers_list");

      if (error) {
        console.error("❌ [CustomerMaster] Error loading customers:", error);
        alert("Error loading customers");
        return;
      }

      customers = data || [];
      console.log("✅ [CustomerMaster] Loaded customers:", customers.length, "customers");
      console.log("📊 [CustomerMaster] Sample customer data:", customers[0]);
      
      // Load statistics
      await loadStatistics();
    } catch (error) {
      console.error("❌ [CustomerMaster] Error loading customers:", error);
      alert("Error loading customers");
    } finally {
      loading = false;
    }
  }

  async function loadStatistics() {
    try {
      // Load pending registration requests
      const { data: pendingRegs, error: regError } = await supabase
        .from("customers")
        .select("id")
        .eq("registration_status", "pending");

      if (regError) {
        console.error("Error loading pending registrations:", regError);
      } else {
        pendingRegistrations = pendingRegs?.length || 0;
      }

      // Load unresolved account recovery requests
      const { data: recoveryReqs, error: recoveryError } = await supabase
        .from("customer_recovery_requests")
        .select("id")
        .neq("verification_status", "processed");

      if (recoveryError) {
        console.error("Error loading recovery requests:", recoveryError);
      } else {
        pendingRecoveryRequests = recoveryReqs?.length || 0;
      }
    } catch (error) {
      console.error("Error loading statistics:", error);
    }
  }

  async function updateCustomerStatus(customerId: string, status: "approved" | "rejected", notes?: string, accessCode?: string) {
    try {
      const user = $currentUser;
      if (!user) {
        alert("Login required");
        return;
      }

      // First update the access code if provided (for approved customers)
      if (status === "approved" && accessCode) {
        const { error: codeError } = await supabase
          .from("customers")
          .update({ 
            access_code: accessCode,
            access_code_generated_at: new Date().toISOString()
          })
          .eq("id", customerId);

        if (codeError) {
          console.error("Error updating access code:", codeError);
          alert("Failed to update access code");
          return;
        }
      }

      // Then update the customer status
      const { data, error } = await supabase.rpc("approve_customer_account", {
        p_customer_id: customerId,
        p_status: status,
        p_notes: notes || "",
        p_approved_by: user.id,
      });

      if (error) {
        console.error("Error updating customer status:", error);
        alert("Update failed");
        return;
      }

      // Send notification through notification center
      await sendAdminNotification(customerId, status, notes || "", accessCode);
      
      // Reload customers list and statistics
      await loadCustomers();
      await loadStatistics();
      
    } catch (error) {
      console.error("Error updating customer status:", error);
      alert("Update failed");
    }
  }

  async function sendAdminNotification(customerId: string, status: string, notes: string, accessCode?: string) {
    try {
      const customer = customers.find(c => c.id === customerId);
      if (!customer) return;

      const isApproved = status === 'approved';
      
      // Send notification to all admins about the customer approval/rejection
      const adminNotificationData = {
        title: isApproved 
          ? `✅ Customer Approved: ${customer.name}`
          : `❌ Customer Rejected: ${customer.name}`,
        message: isApproved 
          ? `Customer "${customer.name}" has been approved. Access code: ${accessCode || 'Not generated'}. WhatsApp: ${customer.whatsapp_number}`
          : `Customer "${customer.name}" has been rejected. ${notes ? 'Reason: ' + notes : 'No reason provided.'}`,
        type: isApproved ? 'success' : 'warning',
        priority: 'normal',
        target_type: 'all_admins'
      };

      await notificationManagement.createNotification(
        adminNotificationData, 
        $currentUser?.username || 'admin'
      );

      console.log("✅ Admin notification sent successfully");
    } catch (error) {
      console.error("❌ Failed to send admin notification:", error);
      // Don't block the approval process if notification fails
    }
  }

  function shareToWhatsApp() {
    if (!selectedCustomer || !generatedAccessCode) return;

    const loginUrl = window.location.origin + '/login';
    const message = `🎉 *أهلاً بك في بوابة عملاء أكورا!*

عزيزي ${selectedCustomer.name || 'العميل'},

تم *قبول* وتفعيل حساب العميل الخاص بك!

*بيانات تسجيل الدخول:*
👤 اسم العميل: ${selectedCustomer.name}
🔑 رمز الدخول: ${generatedAccessCode}
🌐 البوابة: ${loginUrl}

*كيفية تسجيل الدخول:*
1. قم بزيارة بوابة عملاء أكورا
2. اضغط على "دخول العملاء"
3. أدخل رمز الدخول الخاص بك
4. ادخل إلى لوحة تحكم العميل

أهلاً وسهلاً بك! 🚀

*هذه الرسالة من نظام إدارة أكورا*

---

🎉 *Welcome to Aqura Customer Portal!*

Dear ${selectedCustomer.name || 'Customer'},

Your customer account has been *APPROVED* and activated! 

*Your Login Credentials:*
👤 Customer Name: ${selectedCustomer.name}
🔑 Access Code: ${generatedAccessCode}
🌐 Portal: ${loginUrl}

*How to Login:*
1. Visit the Aqura Customer Portal
2. Click "Customer Login"
3. Enter your access code
4. Access your customer dashboard

Welcome aboard! 🚀

*This message is from Aqura Management System*`;

    // Clean phone number (remove any formatting)
    const phoneNumber = selectedCustomer.whatsapp_number.replace(/[^\d+]/g, '');
    
    // Create WhatsApp URL
    const whatsappUrl = `https://web.whatsapp.com/send?phone=${phoneNumber}&text=${encodeURIComponent(message)}`;
    
    // Open WhatsApp Web
    window.open(whatsappUrl, '_blank');
    
    // Close modal after sharing
    setTimeout(() => {
      closeApprovalModal();
    }, 1000);
  }

  function openApprovalModal(customer: Customer, type: "approve" | "reject") {
    selectedCustomer = customer;
    actionType = type;
    approvalNotes = "";
    generatedAccessCode = "";
    showAccessCodeInput = type === "approve";
    showWhatsAppButton = false;
    showApprovalModal = true;
  }

  function closeApprovalModal() {
    showApprovalModal = false;
    selectedCustomer = null;
    approvalNotes = "";
    generatedAccessCode = "";
    showAccessCodeInput = false;
    showWhatsAppButton = false;
  }

  function generateAccessCode() {
    isGeneratingCode = true;
    // Generate 6-digit access code
    generatedAccessCode = Math.floor(100000 + Math.random() * 900000).toString();
    isGeneratingCode = false;
  }

  async function saveApproval() {
    if (!selectedCustomer) return;
    
    isSavingApproval = true;
    try {
      const finalStatus = actionType === "approve" ? "approved" : "rejected";
      
      // For approval, we need the access code
      if (actionType === "approve" && !generatedAccessCode) {
        alert("Please generate an access code first");
        return;
      }

      await updateCustomerStatus(selectedCustomer.id, finalStatus, approvalNotes, generatedAccessCode);
      
      // After successful save, show WhatsApp button for approved customers
      if (actionType === "approve" && selectedCustomer.whatsapp_number && selectedCustomer.whatsapp_number !== 'Not Provided') {
        showWhatsAppButton = true;
      }
      
    } catch (error) {
      console.error("Error saving approval:", error);
      alert("Failed to save approval");
    } finally {
      isSavingApproval = false;
    }
  }

  $: filteredCustomers = customers.filter(customer => {
    const matchesSearch = (customer.name || '').toLowerCase().includes(searchTerm.toLowerCase()) ||
                         (customer.whatsapp_number || '').toLowerCase().includes(searchTerm.toLowerCase());
    
    const matchesStatus = statusFilter === "all" || customer.registration_status === statusFilter;
    
    return matchesSearch && matchesStatus;
  });

  function formatDate(dateString: string) {
    return new Date(dateString).toLocaleDateString();
  }

  function getStatusColor(status: string) {
    switch (status) {
      case "approved": return "text-green-600 bg-green-100";
      case "rejected": return "text-red-600 bg-red-100";
      case "pending": return "text-yellow-600 bg-yellow-100";
      case "suspended": return "text-orange-600 bg-orange-100";
      default: return "text-gray-600 bg-gray-100";
    }
  }

  function openAccountRecoveryManager() {
    const windowId = `account-recovery-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
    const instanceNumber = Math.floor(Math.random() * 1000) + 1;
    
    openWindow({
      id: windowId,
      title: `Customer Account Recovery Manager #${instanceNumber}`,
      component: CustomerAccountRecoveryManager,
      icon: '🔐',
      size: { width: 1400, height: 900 },
      position: { 
        x: 50 + (Math.random() * 100), 
        y: 50 + (Math.random() * 100) 
      },
      resizable: true,
      minimizable: true,
      maximizable: true,
      closable: true
    });
  }
</script>

<div class="customer-management">
  <div class="header">
    <div class="header-content">
      <div class="header-text">
        <h1>Customer Management</h1>
        <p>Manage customer registrations and access approvals</p>
      </div>
      <div class="header-actions">
        <button 
          class="account-recovery-btn"
          on:click={openAccountRecoveryManager}
          title="Open Account Recovery Manager"
        >
          <span class="btn-icon">🔐</span>
          <span class="btn-text">Account Recovery</span>
        </button>
      </div>
    </div>
  </div>

  <!-- Status Cards -->
  <div class="status-cards">
    <div class="status-card registration-card">
      <div class="card-icon">👥</div>
      <div class="card-content">
        <div class="card-number">{pendingRegistrations}</div>
        <div class="card-label">{t('admin.pendingRegistrationRequests')}</div>
      </div>
    </div>
    <div class="status-card recovery-card">
      <div class="card-icon">🔓</div>
      <div class="card-content">
        <div class="card-number">{pendingRecoveryRequests}</div>
        <div class="card-label">{t('admin.unresolvedAccountRecovery')}</div>
      </div>
    </div>
  </div>

  <!-- Filters -->
  <div class="filters">
    <div class="search-box">
      <input
        type="text"
        placeholder="Search..."
        bind:value={searchTerm}
        class="search-input"
      />
    </div>
    
    <select bind:value={statusFilter} class="status-filter">
      <option value="all">All Statuses</option>
      <option value="pending">Pending</option>
      <option value="approved">Approved</option>
      <option value="rejected">Rejected</option>
      <option value="suspended">Suspended</option>
    </select>
  </div>

  <!-- Loading State -->
  {#if loading}
    <div class="loading">
      <div class="spinner"></div>
      <p>Loading...</p>
    </div>
  {:else}
    <!-- Customers Table -->
    <div class="table-container">
      <table class="customers-table">
        <thead>
          <tr>
            <th>Customer Name</th>
            <th>WhatsApp Number</th>
            <th>Status</th>
            <th>Registration Date</th>
            <th>Last Login</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          {#each filteredCustomers as customer (customer.id)}
            <tr>
              <td>{customer.name || 'Unknown Customer'}</td>
              <td>{customer.whatsapp_number || 'Not Provided'}</td>
              <td>
                <span class="status-badge {getStatusColor(customer.registration_status)}">
                  {customer.registration_status === "pending" ? "Pending" : 
                   customer.registration_status === "approved" ? "Approved" : 
                   customer.registration_status === "rejected" ? "Rejected" : 
                   customer.registration_status === "suspended" ? "Suspended" : 
                   customer.registration_status}
                </span>
              </td>
              <td>{formatDate(customer.created_at)}</td>
              <td>{customer.last_login_at ? formatDate(customer.last_login_at) : 'Never'}</td>
              <td>
                <div class="actions">
                  {#if customer.registration_status === "pending"}
                    <button
                      class="approve-btn"
                      on:click={() => openApprovalModal(customer, "approve")}
                    >
                      ✅ Approve
                    </button>
                    <button
                      class="reject-btn"
                      on:click={() => openApprovalModal(customer, "reject")}
                    >
                      ❌ Reject
                    </button>
                  {:else}
                    <span class="status-text">
                      {customer.registration_status === "approved" ? "Approved" : 
                       customer.registration_status === "rejected" ? "Rejected" : 
                       customer.registration_status === "suspended" ? "Suspended" : 
                       customer.registration_status}
                    </span>
                    {#if customer.approved_at}
                      <small class="approval-date">
                        {formatDate(customer.approved_at)}
                      </small>
                    {/if}
                  {/if}
                </div>
              </td>
            </tr>
          {:else}
            <tr>
              <td colspan="6" class="no-data">
                No data found
              </td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>
  {/if}
</div>

<!-- Approval Modal -->
{#if showApprovalModal && selectedCustomer}
  <div class="modal-overlay" on:click={closeApprovalModal} role="dialog" tabindex="-1">
    <div class="modal-content" on:click|stopPropagation role="document" tabindex="-1">
      <div class="modal-header">
        <h3>
          {actionType === "approve" ? "✅ Approve Customer" : "❌ Reject Customer"}
        </h3>
        <button class="close-btn" on:click={closeApprovalModal}>✕</button>
      </div>
      
      <div class="modal-body">
        <div class="customer-info">
          <p><strong>Customer Name:</strong> {selectedCustomer.name || 'Unknown Customer'}</p>
          <p><strong>WhatsApp Number:</strong> {selectedCustomer.whatsapp_number || 'Not Provided'}</p>
          <p><strong>Registration Date:</strong> {formatDate(selectedCustomer.created_at)}</p>
          {#if selectedCustomer.registration_notes}
            <p><strong>Registration Notes:</strong> {selectedCustomer.registration_notes}</p>
          {/if}
        </div>

        {#if actionType === "approve" && showAccessCodeInput}
          <div class="access-code-section">
            <label for="accessCode">Access Code:</label>
            <div class="access-code-input-group">
              <input
                id="accessCode"
                type="text"
                bind:value={generatedAccessCode}
                placeholder="Generate 6-digit access code"
                maxlength="6"
                readonly
              />
              <button 
                class="generate-btn"
                on:click={generateAccessCode}
                disabled={isGeneratingCode}
              >
                {#if isGeneratingCode}
                  Generating...
                {:else}
                  🎲 Generate
                {/if}
              </button>
            </div>
            <p class="access-code-hint">Click "Generate" to create a 6-digit access code for the customer</p>
          </div>
        {/if}
        
        <div class="notes-section">
          <label for="approvalNotes">Notes (Optional):</label>
          <textarea
            id="approvalNotes"
            bind:value={approvalNotes}
            placeholder={actionType === "approve" ? "Add approval notes or special instructions..." : "Provide reason for rejection..."}
            rows="3"
          ></textarea>
        </div>
      </div>
      
      <div class="modal-footer">
        {#if showWhatsAppButton}
          <div class="whatsapp-section">
            <p class="success-message">✅ Customer approved successfully!</p>
            <button class="whatsapp-btn" on:click={shareToWhatsApp}>
              📱 Share Login via WhatsApp
            </button>
            <button class="done-btn" on:click={closeApprovalModal}>
              Done
            </button>
          </div>
        {:else}
          <button class="cancel-btn" on:click={closeApprovalModal}>
            Cancel
          </button>
          <button 
            class="confirm-btn {actionType === 'approve' ? 'approve' : 'reject'}"
            on:click={saveApproval}
            disabled={isSavingApproval || (actionType === 'approve' && !generatedAccessCode)}
          >
            {#if isSavingApproval}
              Saving...
            {:else}
              {actionType === "approve" ? "Save & Approve" : "Reject"}
            {/if}
          </button>
        {/if}
      </div>
    </div>
  </div>
{/if}

<style>
  .customer-management {
    padding: 2rem;
    max-width: 1400px;
    margin: 0 auto;
  }

  .header {
    margin-bottom: 2rem;
  }

  .header-content {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 1rem;
  }

  .header-text {
    flex: 1;
  }

  .header h1 {
    margin: 0 0 0.5rem 0;
    color: #374151;
    font-size: 1.875rem;
    font-weight: 700;
  }

  .header p {
    margin: 0;
    color: #6b7280;
    font-size: 1rem;
  }

  .header-actions {
    flex-shrink: 0;
  }

  .account-recovery-btn {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.75rem 1rem;
    background: linear-gradient(135deg, #3b82f6 0%, #1d4ed8 100%);
    border: none;
    border-radius: 0.5rem;
    color: white;
    font-size: 0.875rem;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s ease;
    box-shadow: 0 2px 4px rgba(59, 130, 246, 0.3);
  }

  .account-recovery-btn:hover {
    background: linear-gradient(135deg, #2563eb 0%, #1e40af 100%);
    transform: translateY(-1px);
    box-shadow: 0 4px 8px rgba(59, 130, 246, 0.4);
  }

  .account-recovery-btn:active {
    transform: translateY(0);
    box-shadow: 0 2px 4px rgba(59, 130, 246, 0.3);
  }

  .account-recovery-btn .btn-icon {
    font-size: 1rem;
  }

  .account-recovery-btn .btn-text {
    white-space: nowrap;
  }

  /* Status Cards */
  .status-cards {
    display: flex;
    gap: 1.5rem;
    margin-bottom: 2rem;
  }

  .status-card {
    flex: 1;
    display: flex;
    align-items: center;
    gap: 1rem;
    padding: 1.5rem;
    background: white;
    border-radius: 1rem;
    box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
    border: 1px solid #e5e7eb;
    transition: all 0.3s ease;
  }

  .status-card:hover {
    transform: translateY(-2px);
    box-shadow: 0 8px 25px rgba(0, 0, 0, 0.15);
  }

  .card-icon {
    font-size: 2.5rem;
    min-width: 3rem;
    text-align: center;
  }

  .card-content {
    flex: 1;
  }

  .card-number {
    font-size: 2rem;
    font-weight: 700;
    line-height: 1;
    margin-bottom: 0.25rem;
  }

  .card-label {
    font-size: 0.875rem;
    color: #6b7280;
    font-weight: 500;
    line-height: 1.2;
  }

  .registration-card .card-number {
    color: #f59e0b;
  }

  .recovery-card .card-number {
    color: #ef4444;
  }

  @media (max-width: 768px) {
    .status-cards {
      flex-direction: column;
      gap: 1rem;
    }
  }

  .filters {
    display: flex;
    gap: 1rem;
    margin-bottom: 2rem;
    flex-wrap: wrap;
  }

  .search-box {
    flex: 1;
    min-width: 250px;
  }

  .search-input {
    width: 100%;
    padding: 0.75rem 1rem;
    border: 1px solid #d1d5db;
    border-radius: 8px;
    font-size: 0.875rem;
  }

  .search-input:focus {
    outline: none;
    border-color: #3b82f6;
    box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
  }

  .status-filter {
    padding: 0.75rem 1rem;
    border: 1px solid #d1d5db;
    border-radius: 8px;
    background: white;
    font-size: 0.875rem;
    cursor: pointer;
  }

  .loading {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 4rem 2rem;
    gap: 1rem;
  }

  .spinner {
    width: 40px;
    height: 40px;
    border: 4px solid #e5e7eb;
    border-top: 4px solid #3b82f6;
    border-radius: 50%;
    animation: spin 1s linear infinite;
  }

  @keyframes spin {
    0% { transform: rotate(0deg); }
    100% { transform: rotate(360deg); }
  }

  .table-container {
    background: white;
    border-radius: 12px;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
    overflow: hidden;
  }

  .customers-table {
    width: 100%;
    border-collapse: collapse;
  }

  .customers-table th {
    background: #f9fafb;
    padding: 1rem;
    text-align: left;
    font-weight: 600;
    color: #374151;
    border-bottom: 1px solid #e5e7eb;
  }

  .customers-table td {
    padding: 1rem;
    border-bottom: 1px solid #e5e7eb;
    vertical-align: top;
  }

  .customers-table tr:last-child td {
    border-bottom: none;
  }

  .username {
    font-family: 'Courier New', monospace;
    background: #f3f4f6;
    font-size: 0.875rem;
  }

  .status-badge {
    padding: 0.25rem 0.75rem;
    border-radius: 9999px;
    font-size: 0.75rem;
    font-weight: 500;
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }

  .actions {
    display: flex;
    gap: 0.5rem;
    flex-wrap: wrap;
  }

  .approve-btn, .reject-btn {
    padding: 0.5rem 1rem;
    border: none;
    border-radius: 6px;
    font-size: 0.75rem;
    font-weight: 500;
    cursor: pointer;
    transition: all 0.2s ease;
  }

  .approve-btn {
    background: #10b981;
    color: white;
  }

  .approve-btn:hover {
    background: #059669;
  }

  .reject-btn {
    background: #ef4444;
    color: white;
  }

  .reject-btn:hover {
    background: #dc2626;
  }

  .status-text {
    font-size: 0.875rem;
    color: #6b7280;
  }

  .approval-date {
    display: block;
    font-size: 0.75rem;
    color: #9ca3af;
  }

  .no-data {
    text-align: center;
    color: #6b7280;
    font-style: italic;
    padding: 3rem;
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
    backdrop-filter: blur(4px);
  }

  .modal-content {
    background: white;
    border-radius: 12px;
    max-width: 500px;
    width: 90vw;
    max-height: 90vh;
    overflow-y: auto;
    box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1);
  }

  .modal-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 1.5rem;
    border-bottom: 1px solid #e5e7eb;
  }

  .modal-header h3 {
    margin: 0;
    font-size: 1.125rem;
    font-weight: 600;
    color: #374151;
  }

  .close-btn {
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
  }

  .close-btn:hover {
    color: #374151;
  }

  .modal-body {
    padding: 1.5rem;
  }

  .customer-info {
    margin-bottom: 1.5rem;
    padding: 1rem;
    background: #f9fafb;
    border-radius: 8px;
  }

  .customer-info p {
    margin: 0.5rem 0;
    color: #374151;
  }

  .notes-section label {
    display: block;
    margin-bottom: 0.5rem;
    font-weight: 500;
    color: #374151;
  }

  .notes-section textarea {
    width: 100%;
    padding: 0.75rem;
    border: 1px solid #d1d5db;
    border-radius: 8px;
    font-size: 0.875rem;
    resize: vertical;
    font-family: inherit;
  }

  .notes-section textarea:focus {
    outline: none;
    border-color: #3b82f6;
    box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
  }

  .modal-footer {
    display: flex;
    justify-content: flex-end;
    gap: 1rem;
    padding-top: 1.5rem;
    border-top: 1px solid #e5e7eb;
  }

  .access-code-section {
    margin: 1.5rem 0;
    padding: 1rem;
    background: #f8fafc;
    border-radius: 8px;
    border: 1px solid #e2e8f0;
  }

  .access-code-input-group {
    display: flex;
    gap: 0.5rem;
    margin-top: 0.5rem;
  }

  .access-code-input-group input {
    flex: 1;
    padding: 0.75rem;
    border: 1px solid #d1d5db;
    border-radius: 6px;
    font-family: monospace;
    font-size: 1.1rem;
    text-align: center;
    letter-spacing: 0.2em;
    background: white;
  }

  .generate-btn {
    padding: 0.75rem 1rem;
    background: #3b82f6;
    color: white;
    border: none;
    border-radius: 6px;
    cursor: pointer;
    font-weight: 500;
    transition: background 0.2s;
  }

  .generate-btn:hover:not(:disabled) {
    background: #2563eb;
  }

  .generate-btn:disabled {
    background: #9ca3af;
    cursor: not-allowed;
  }

  .access-code-hint {
    margin-top: 0.5rem;
    font-size: 0.875rem;
    color: #6b7280;
    font-style: italic;
  }

  .whatsapp-section {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 1rem;
    width: 100%;
  }

  .success-message {
    color: #059669;
    font-weight: 600;
    margin: 0;
  }

  .whatsapp-btn {
    padding: 0.75rem 1.5rem;
    background: #25d366;
    color: white;
    border: none;
    border-radius: 8px;
    cursor: pointer;
    font-weight: 600;
    font-size: 1rem;
    transition: background 0.2s;
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }

  .whatsapp-btn:hover {
    background: #128c7e;
  }

  .done-btn {
    padding: 0.5rem 1rem;
    background: #6b7280;
    color: white;
    border: none;
    border-radius: 6px;
    cursor: pointer;
    font-size: 0.875rem;
  }

  .done-btn:hover {
    background: #4b5563;
  }

  .cancel-btn, .confirm-btn {
    padding: 0.75rem 1.5rem;
    border: none;
    border-radius: 8px;
    font-weight: 500;
    cursor: pointer;
    transition: all 0.2s ease;
  }

  .cancel-btn {
    background: #f3f4f6;
    color: #374151;
  }

  .cancel-btn:hover {
    background: #e5e7eb;
  }

  .confirm-btn {
    color: white;
  }

  .confirm-btn.approve {
    background: #10b981;
  }

  .confirm-btn.approve:hover {
    background: #059669;
  }

  .confirm-btn.reject {
    background: #ef4444;
  }

  .confirm-btn.reject:hover {
    background: #dc2626;
  }

  /* Mobile Responsive */
  @media (max-width: 768px) {
    .customer-management {
      padding: 1rem;
    }

    .filters {
      flex-direction: column;
    }

    .customers-table {
      font-size: 0.875rem;
    }

    .customers-table th,
    .customers-table td {
      padding: 0.75rem 0.5rem;
    }

    .actions {
      flex-direction: column;
    }

    .modal-content {
      width: 95vw;
    }
  }
</style>