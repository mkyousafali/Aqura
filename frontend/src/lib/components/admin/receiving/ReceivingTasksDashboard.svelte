<!-- ReceivingTasksDashboard.svelte -->
<script>
  import { onMount } from 'svelte';
  import { currentUser } from '$lib/utils/persistentAuth';
  
  export let userId = null;
  
  let dashboard = null;
  let loading = true;
  let error = '';
  let selectedFilter = 'all'; // all, pending, completed, overdue
  let filteredTasks = [];
  
  // Load user's receiving tasks dashboard
  async function loadDashboard() {
    if (!userId) return;
    
    try {
      loading = true;
      error = '';
      
      const response = await fetch(`/api/receiving-tasks/dashboard?user_id=${userId}`);
      const result = await response.json();
      
      if (!result.success) {
        throw new Error(result.error);
      }
      
      dashboard = result.dashboard;
      filterTasks();
      
    } catch (err) {
      console.error('Error loading dashboard:', err);
      error = err.message;
    } finally {
      loading = false;
    }
  }
  
  // Filter tasks based on selected filter
  function filterTasks() {
    if (!dashboard || !dashboard.recent_tasks) {
      filteredTasks = [];
      return;
    }
    
    const tasks = dashboard.recent_tasks;
    
    switch (selectedFilter) {
      case 'pending':
        filteredTasks = tasks.filter(task => 
          task.status !== 'completed' && !task.is_overdue
        );
        break;
      case 'completed':
        filteredTasks = tasks.filter(task => task.status === 'completed');
        break;
      case 'overdue':
        filteredTasks = tasks.filter(task => task.is_overdue);
        break;
      default:
        filteredTasks = tasks;
    }
  }
  
  // Complete a receiving task
  async function completeTask(task, erpReference = '', completionNotes = '') {
    try {
      const response = await fetch('/api/receiving-tasks/complete', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          receiving_task_id: task.task_id,
          user_id: userId,
          erp_reference: erpReference || null,
          completion_notes: completionNotes || null
        })
      });
      
      const result = await response.json();
      
      if (!result.success) {
        throw new Error(result.error);
      }
      
      // Reload dashboard to reflect changes
      await loadDashboard();
      
      return result;
      
    } catch (err) {
      console.error('Error completing task:', err);
      throw err;
    }
  }
  
  // Validate task completion requirements
  async function validateTaskCompletion(task) {
    try {
      const response = await fetch(
        `/api/receiving-tasks/complete?receiving_task_id=${task.task_id}&user_id=${userId}`
      );
      const result = await response.json();
      
      if (result.success) {
        return result.validation;
      }
      
      return null;
      
    } catch (err) {
      console.error('Error validating task completion:', err);
      return null;
    }
  }
  
  // Get task status color class
  function getStatusColor(status, isOverdue) {
    if (isOverdue) return 'bg-red-100 text-red-800';
    
    switch (status) {
      case 'completed': return 'bg-green-100 text-green-800';
      case 'in_progress': return 'bg-blue-100 text-blue-800';
      case 'assigned': return 'bg-yellow-100 text-yellow-800';
      default: return 'bg-gray-100 text-gray-800';
    }
  }
  
  // Get priority color class
  function getPriorityColor(priority) {
    switch (priority) {
      case 'high': return 'bg-red-100 text-red-800';
      case 'medium': return 'bg-yellow-100 text-yellow-800';
      case 'low': return 'bg-green-100 text-green-800';
      default: return 'bg-gray-100 text-gray-800';
    }
  }
  
  // Get role display name
  function getRoleDisplayName(roleType) {
    switch (roleType) {
      case 'branch_manager': return 'Branch Manager';
      case 'purchase_manager': return 'Purchase Manager';
      case 'inventory_manager': return 'Inventory Manager';
      case 'night_supervisor': return 'Night Supervisor';
      case 'warehouse_handler': return 'Warehouse Handler';
      case 'shelf_stocker': return 'Shelf Stocker';
      case 'accountant': return 'Accountant';
      default: return roleType;
    }
  }
  
  // Format date
  function formatDate(dateString) {
    return new Date(dateString).toLocaleString();
  }
  
  // Load dashboard when userId changes
  $: if (userId) {
    loadDashboard();
  }
  
  // Update filtered tasks when filter changes
  $: if (selectedFilter) filterTasks();
  
  onMount(() => {
    // Auto-load if userId is available from currentUser
    if (!userId && $currentUser?.id) {
      userId = $currentUser.id;
    }
  });
</script>

<div class="bg-white rounded-lg shadow-sm border border-gray-200">
  <!-- Header -->
  <div class="bg-gradient-to-r from-blue-600 to-blue-700 text-white px-6 py-4 rounded-t-lg">
    <h2 class="text-xl font-semibold">My Receiving Tasks</h2>
    <p class="text-blue-100 text-sm">Tasks generated from receiving clearance certificates</p>
  </div>
  
  {#if loading}
    <!-- Loading State -->
    <div class="p-6">
      <div class="flex items-center justify-center py-8">
        <svg class="animate-spin h-8 w-8 text-blue-600" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
        <span class="ml-3 text-gray-600">Loading tasks...</span>
      </div>
    </div>
  {:else if error}
    <!-- Error State -->
    <div class="p-6">
      <div class="bg-red-50 border border-red-200 rounded-lg p-4">
        <div class="flex items-center">
          <svg class="h-5 w-5 text-red-500 mr-2" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
          </svg>
          <div>
            <h3 class="text-sm font-medium text-red-800">Error Loading Tasks</h3>
            <p class="text-sm text-red-700 mt-1">{error}</p>
          </div>
        </div>
      </div>
    </div>
  {:else if dashboard}
    <!-- Dashboard Content -->
    <div class="p-6">
      <!-- Statistics Cards -->
      <div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
        <div class="bg-blue-50 rounded-lg p-4">
          <div class="text-2xl font-bold text-blue-600">{dashboard.statistics.total_tasks}</div>
          <div class="text-sm text-blue-800">Total Tasks</div>
        </div>
        <div class="bg-yellow-50 rounded-lg p-4">
          <div class="text-2xl font-bold text-yellow-600">{dashboard.statistics.pending_tasks}</div>
          <div class="text-sm text-yellow-800">Pending</div>
        </div>
        <div class="bg-green-50 rounded-lg p-4">
          <div class="text-2xl font-bold text-green-600">{dashboard.statistics.completed_tasks}</div>
          <div class="text-sm text-green-800">Completed</div>
        </div>
        <div class="bg-red-50 rounded-lg p-4">
          <div class="text-2xl font-bold text-red-600">{dashboard.statistics.overdue_tasks}</div>
          <div class="text-sm text-red-800">Overdue</div>
        </div>
      </div>
      
      <!-- Completion Rate -->
      {#if dashboard.statistics.total_tasks > 0}
        <div class="bg-gray-50 rounded-lg p-4 mb-6">
          <div class="flex items-center justify-between mb-2">
            <span class="text-sm font-medium text-gray-700">Completion Rate</span>
            <span class="text-sm text-gray-600">{dashboard.statistics.completion_rate}%</span>
          </div>
          <div class="bg-gray-200 rounded-full h-2">
            <div class="bg-green-600 h-2 rounded-full transition-all duration-300" 
                 style="width: {dashboard.statistics.completion_rate}%"></div>
          </div>
        </div>
      {/if}
      
      <!-- Task Requirements Summary -->
      {#if dashboard.statistics.needs_erp_reference > 0 || dashboard.statistics.needs_original_bill_upload > 0}
        <div class="bg-orange-50 border border-orange-200 rounded-lg p-4 mb-6">
          <h3 class="font-medium text-orange-800 mb-2">Action Required</h3>
          <div class="space-y-1 text-sm text-orange-700">
            {#if dashboard.statistics.needs_erp_reference > 0}
              <div>📊 {dashboard.statistics.needs_erp_reference} task(s) need ERP reference numbers</div>
            {/if}
            {#if dashboard.statistics.needs_original_bill_upload > 0}
              <div>📎 {dashboard.statistics.needs_original_bill_upload} task(s) need original bill uploads</div>
            {/if}
          </div>
        </div>
      {/if}
      
      <!-- Task Filter -->
      <div class="flex space-x-2 mb-4">
        <button
          class="px-3 py-1 rounded-full text-sm font-medium transition-colors {selectedFilter === 'all' ? 'bg-blue-600 text-white' : 'bg-gray-100 text-gray-700 hover:bg-gray-200'}"
          on:click={() => selectedFilter = 'all'}
        >
          All ({dashboard.statistics.total_tasks})
        </button>
        <button
          class="px-3 py-1 rounded-full text-sm font-medium transition-colors {selectedFilter === 'pending' ? 'bg-yellow-600 text-white' : 'bg-gray-100 text-gray-700 hover:bg-gray-200'}"
          on:click={() => selectedFilter = 'pending'}
        >
          Pending ({dashboard.statistics.pending_tasks})
        </button>
        <button
          class="px-3 py-1 rounded-full text-sm font-medium transition-colors {selectedFilter === 'completed' ? 'bg-green-600 text-white' : 'bg-gray-100 text-gray-700 hover:bg-gray-200'}"
          on:click={() => selectedFilter = 'completed'}
        >
          Completed ({dashboard.statistics.completed_tasks})
        </button>
        <button
          class="px-3 py-1 rounded-full text-sm font-medium transition-colors {selectedFilter === 'overdue' ? 'bg-red-600 text-white' : 'bg-gray-100 text-gray-700 hover:bg-gray-200'}"
          on:click={() => selectedFilter = 'overdue'}
        >
          Overdue ({dashboard.statistics.overdue_tasks})
        </button>
      </div>
      
      <!-- Tasks List -->
      {#if filteredTasks.length > 0}
        <div class="space-y-4">
          {#each filteredTasks as task}
            <div class="border border-gray-200 rounded-lg p-4 hover:shadow-sm transition-shadow">
              <div class="flex items-start justify-between mb-3">
                <div class="flex-1">
                  <div class="flex items-center space-x-2 mb-2">
                    <span class="px-2 py-1 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                      {getRoleDisplayName(task.role_type)}
                    </span>
                    <span class="px-2 py-1 rounded-full text-xs font-medium {getStatusColor(task.status, task.is_overdue)}">
                      {task.status}
                    </span>
                    <span class="px-2 py-1 rounded-full text-xs font-medium {getPriorityColor(task.priority)}">
                      {task.priority}
                    </span>
                  </div>
                  
                  <h4 class="font-medium text-gray-900 mb-1">{task.title}</h4>
                  <p class="text-sm text-gray-600 mb-2">{task.description}</p>
                  
                  <div class="text-xs text-gray-500 space-y-1">
                    {#if task.deadline_datetime}
                      <div>📅 Deadline: {formatDate(task.deadline_datetime)}</div>
                    {/if}
                    <div>🕒 Created: {formatDate(task.created_at)}</div>
                  </div>
                </div>
              </div>
              
              <!-- Task Requirements -->
              {#if task.requires_erp_reference || task.requires_original_bill_upload}
                <div class="bg-gray-50 rounded p-3 mb-3">
                  <h5 class="text-sm font-medium text-gray-700 mb-2">Requirements:</h5>
                  <div class="space-y-1 text-sm">
                    {#if task.requires_erp_reference}
                      <div class="flex items-center">
                        {#if task.erp_reference_number}
                          <svg class="h-4 w-4 text-green-500 mr-2" fill="currentColor" viewBox="0 0 20 20">
                            <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
                          </svg>
                          <span class="text-green-700">ERP Reference: {task.erp_reference_number}</span>
                        {:else}
                          <svg class="h-4 w-4 text-orange-500 mr-2" fill="currentColor" viewBox="0 0 20 20">
                            <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd" />
                          </svg>
                          <span class="text-orange-700">ERP Reference required</span>
                        {/if}
                      </div>
                    {/if}
                    
                    {#if task.requires_original_bill_upload}
                      <div class="flex items-center">
                        {#if task.original_bill_uploaded}
                          <svg class="h-4 w-4 text-green-500 mr-2" fill="currentColor" viewBox="0 0 20 20">
                            <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
                          </svg>
                          <span class="text-green-700">Original bill uploaded</span>
                        {:else}
                          <svg class="h-4 w-4 text-orange-500 mr-2" fill="currentColor" viewBox="0 0 20 20">
                            <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd" />
                          </svg>
                          <span class="text-orange-700">Original bill upload required</span>
                        {/if}
                      </div>
                    {/if}
                  </div>
                </div>
              {/if}
              
              <!-- Clearance Certificate Link -->
              {#if task.clearance_certificate_url}
                <div class="mb-3">
                  <a 
                    href={task.clearance_certificate_url} 
                    target="_blank" 
                    class="text-blue-600 hover:text-blue-800 text-sm flex items-center"
                  >
                    <svg class="h-4 w-4 mr-1" fill="currentColor" viewBox="0 0 20 20">
                      <path fill-rule="evenodd" d="M6 2a2 2 0 00-2 2v12a2 2 0 002 2h8a2 2 0 002-2V7.414A2 2 0 0015.414 6L12 2.586A2 2 0 0010.586 2H6zm5 6a1 1 0 10-2 0v3.586l-1.293-1.293a1 1 0 10-1.414 1.414l3 3a1 1 0 001.414 0l3-3a1 1 0 00-1.414-1.414L11 11.586V8z" clip-rule="evenodd" />
                    </svg>
                    View Clearance Certificate
                  </a>
                </div>
              {/if}
              
              <!-- Action Button -->
              {#if task.can_be_completed && task.status !== 'completed'}
                <button
                  class="bg-green-600 text-white px-4 py-2 rounded text-sm font-medium hover:bg-green-700 transition-colors"
                  on:click={() => completeTask(task)}
                >
                  Mark as Complete
                </button>
              {/if}
            </div>
          {/each}
        </div>
      {:else}
        <div class="text-center py-8">
          <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
          </svg>
          <h3 class="mt-2 text-sm font-medium text-gray-900">No tasks found</h3>
          <p class="mt-1 text-sm text-gray-500">
            {selectedFilter === 'all' ? 'No receiving tasks have been assigned to you yet.' : `No ${selectedFilter} tasks found.`}
          </p>
        </div>
      {/if}
    </div>
  {:else}
    <!-- No Data State -->
    <div class="p-6">
      <div class="text-center py-8">
        <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
        </svg>
        <h3 class="mt-2 text-sm font-medium text-gray-900">No user provided</h3>
        <p class="mt-1 text-sm text-gray-500">Please provide a user ID to load receiving tasks.</p>
      </div>
    </div>
  {/if}
</div>