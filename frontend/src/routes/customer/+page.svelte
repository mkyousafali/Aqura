<script lang="ts">
  import { onMount } from "svelte";
  import { goto } from "$app/navigation";
  import { t } from "$lib/i18n";

  let customerData: any = null;
  let loading = true;

  onMount(() => {
    // Check for customer session in localStorage
    const customerSession = localStorage.getItem('customer_session');
    
    if (!customerSession) {
      goto("/login");
      return;
    }

    try {
      customerData = JSON.parse(customerSession);
      loading = false;

      // Validate that the customer is approved
      if (customerData.registration_status !== 'approved') {
        localStorage.removeItem('customer_session');
        goto("/login");
        return;
      }
    } catch (error) {
      console.error("❌ [Customer] Invalid customer session:", error);
      localStorage.removeItem('customer_session');
      goto("/login");
    }
  });

  function logout() {
    localStorage.removeItem('customer_session');
    goto("/login");
  }
</script>

<svelte:head>
  <title>Customer Dashboard - Aqura</title>
</svelte:head>

{#if loading}
  <div class="loading-container">
    <div class="spinner"></div>
    <p>Loading...</p>
  </div>
{:else if customerData}
  <div class="customer-dashboard">
    <!-- Header -->
    <header class="dashboard-header">
      <div class="header-content">
        <div class="user-info">
          <div class="avatar">
            <span class="avatar-text">
              {customerData.customer_name?.charAt(0)?.toUpperCase() || "C"}
            </span>
          </div>
          <div class="user-details">
            <h1>Welcome to your portal</h1>
            <p class="company-name">{customerData.customer_name || "Valued Customer"}</p>
            <p class="access-code">
              Access Code: 
              <span class="code">{customerData.customer_id || "N/A"}</span>
            </p>
          </div>
        </div>
        <button class="logout-btn" on:click={logout}>
          <span class="icon">🚪</span>
          Logout
        </button>
      </div>
    </header>

    <!-- Main Content -->
    <main class="dashboard-main">
      <div class="container">
        <!-- Status Card -->
        <div class="status-card">
          <div class="status-icon">
            {#if customerData.registration_status === "approved"}
              <span class="approved">✅</span>
            {:else if customerData.registration_status === "pending"}
              <span class="pending">⏳</span>
            {:else}
              <span class="rejected">❌</span>
            {/if}
          </div>
          <div class="status-content">
            <h2>Account Status</h2>
            <p class="status-text">
              {#if customerData.registration_status === "approved"}
                Your account is approved and active
              {:else if customerData.registration_status === "pending"}
                Your account is pending approval
              {:else}
                Your account access has been denied
              {/if}
            </p>
            {#if customerData.registration_status === "pending"}
              <p class="status-description">
                Our team is reviewing your registration. You will be notified once approved.
              </p>
            {:else if customerData.registration_status === "rejected"}
              <p class="status-description">
                Please contact support for assistance with your account access.
              </p>
            {/if}
          </div>
        </div>

        <!-- Features Grid -->
        <div class="features-grid">
          <!-- Orders Section -->
          <div class="feature-card">
            <div class="feature-icon">📋</div>
            <h3>Orders & Requests</h3>
            <p>View and manage your orders and service requests</p>
            <button class="feature-btn" disabled={customerData.registration_status !== "approved"}>
              View Orders
            </button>
          </div>

          <!-- Support Section -->
          <div class="feature-card">
            <div class="feature-icon">💬</div>
            <h3>Customer Support</h3>
            <p>Get help and contact our support team</p>
            <button class="feature-btn">
              Contact Support
            </button>
          </div>

          <!-- Account Section -->
          <div class="feature-card">
            <div class="feature-icon">⚙️</div>
            <h3>Account Settings</h3>
            <p>Manage your account information and preferences</p>
            <button class="feature-btn">
              Manage Account
            </button>
          </div>

          <!-- Reports Section -->
          <div class="feature-card">
            <div class="feature-icon">📊</div>
            <h3>Reports & History</h3>
            <p>Access your transaction history and reports</p>
            <button class="feature-btn" disabled={customerData.registration_status !== "approved"}>
              View Reports
            </button>
          </div>
        </div>

        <!-- Contact Information -->
        <div class="contact-card">
          <h3>Need Help? Contact Us</h3>
          <div class="contact-grid">
            <div class="contact-item">
              <span class="contact-icon">📧</span>
              <div>
                <p class="contact-label">Email Support</p>
                <p class="contact-value">support@aqura.com</p>
              </div>
            </div>
            <div class="contact-item">
              <span class="contact-icon">📱</span>
              <div>
                <p class="contact-label">WhatsApp Support</p>
                <p class="contact-value">+966 XX XXX XXXX</p>
              </div>
            </div>
            <div class="contact-item">
              <span class="contact-icon">🕐</span>
              <div>
                <p class="contact-label">Business Hours</p>
                <p class="contact-value">Sunday - Thursday, 9:00 AM - 6:00 PM</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </main>
  </div>
{/if}

<style>
  .loading-container {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    min-height: 100vh;
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

  .customer-dashboard {
    min-height: 100vh;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  }

  .dashboard-header {
    background: rgba(255, 255, 255, 0.1);
    backdrop-filter: blur(10px);
    border-bottom: 1px solid rgba(255, 255, 255, 0.2);
    padding: 1.5rem 0;
  }

  .header-content {
    max-width: 1200px;
    margin: 0 auto;
    padding: 0 1rem;
    display: flex;
    justify-content: space-between;
    align-items: center;
  }

  .user-info {
    display: flex;
    align-items: center;
    gap: 1rem;
  }

  .avatar {
    width: 60px;
    height: 60px;
    background: rgba(255, 255, 255, 0.2);
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    border: 2px solid rgba(255, 255, 255, 0.3);
  }

  .avatar-text {
    font-size: 1.5rem;
    font-weight: bold;
    color: white;
  }

  .user-details h1 {
    color: white;
    margin: 0;
    font-size: 1.5rem;
    font-weight: 600;
  }

  .company-name {
    color: rgba(255, 255, 255, 0.9);
    margin: 0.25rem 0;
    font-size: 1rem;
  }

  .access-code {
    color: rgba(255, 255, 255, 0.8);
    margin: 0;
    font-size: 0.875rem;
  }

  .code {
    font-family: 'Courier New', monospace;
    background: rgba(255, 255, 255, 0.2);
    padding: 0.25rem 0.5rem;
    border-radius: 4px;
    margin-left: 0.5rem;
  }

  .logout-btn {
    background: rgba(255, 255, 255, 0.2);
    color: white;
    border: 1px solid rgba(255, 255, 255, 0.3);
    padding: 0.75rem 1.5rem;
    border-radius: 8px;
    cursor: pointer;
    transition: all 0.2s ease;
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-size: 0.875rem;
  }

  .logout-btn:hover {
    background: rgba(255, 255, 255, 0.3);
    transform: translateY(-1px);
  }

  .dashboard-main {
    padding: 2rem 0;
  }

  .container {
    max-width: 1200px;
    margin: 0 auto;
    padding: 0 1rem;
  }

  .status-card {
    background: rgba(255, 255, 255, 0.95);
    border-radius: 12px;
    padding: 2rem;
    margin-bottom: 2rem;
    display: flex;
    align-items: center;
    gap: 1.5rem;
    box-shadow: 0 10px 25px rgba(0, 0, 0, 0.1);
  }

  .status-icon {
    font-size: 3rem;
  }

  .status-content h2 {
    margin: 0 0 0.5rem 0;
    color: #374151;
    font-size: 1.25rem;
  }

  .status-text {
    margin: 0 0 0.5rem 0;
    font-weight: 600;
    font-size: 1.1rem;
  }

  .status-description {
    margin: 0;
    color: #6b7280;
    line-height: 1.5;
  }

  .approved { color: #10b981; }
  .pending { color: #f59e0b; }
  .rejected { color: #ef4444; }

  .features-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
    gap: 1.5rem;
    margin-bottom: 2rem;
  }

  .feature-card {
    background: rgba(255, 255, 255, 0.95);
    border-radius: 12px;
    padding: 2rem;
    text-align: center;
    box-shadow: 0 10px 25px rgba(0, 0, 0, 0.1);
    transition: transform 0.2s ease;
  }

  .feature-card:hover {
    transform: translateY(-2px);
  }

  .feature-icon {
    font-size: 3rem;
    margin-bottom: 1rem;
  }

  .feature-card h3 {
    margin: 0 0 1rem 0;
    color: #374151;
    font-size: 1.25rem;
  }

  .feature-card p {
    margin: 0 0 1.5rem 0;
    color: #6b7280;
    line-height: 1.5;
  }

  .feature-btn {
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    color: white;
    border: none;
    padding: 0.75rem 1.5rem;
    border-radius: 8px;
    cursor: pointer;
    transition: all 0.2s ease;
    font-weight: 500;
    width: 100%;
  }

  .feature-btn:hover:not(:disabled) {
    transform: translateY(-1px);
    box-shadow: 0 4px 12px rgba(102, 126, 234, 0.4);
  }

  .feature-btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .contact-card {
    background: rgba(255, 255, 255, 0.95);
    border-radius: 12px;
    padding: 2rem;
    box-shadow: 0 10px 25px rgba(0, 0, 0, 0.1);
  }

  .contact-card h3 {
    margin: 0 0 1.5rem 0;
    color: #374151;
    font-size: 1.25rem;
    text-align: center;
  }

  .contact-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
    gap: 1.5rem;
  }

  .contact-item {
    display: flex;
    align-items: center;
    gap: 1rem;
  }

  .contact-icon {
    font-size: 1.5rem;
  }

  .contact-label {
    margin: 0;
    color: #6b7280;
    font-size: 0.875rem;
    font-weight: 500;
  }

  .contact-value {
    margin: 0.25rem 0 0 0;
    color: #374151;
    font-weight: 600;
  }

  /* Mobile Responsive */
  @media (max-width: 768px) {
    .header-content {
      flex-direction: column;
      gap: 1rem;
      text-align: center;
    }

    .user-info {
      flex-direction: column;
      text-align: center;
    }

    .status-card {
      flex-direction: column;
      text-align: center;
      padding: 1.5rem;
    }

    .features-grid {
      grid-template-columns: 1fr;
    }

    .contact-grid {
      grid-template-columns: 1fr;
    }

    .dashboard-main {
      padding: 1rem 0;
    }
  }
</style>