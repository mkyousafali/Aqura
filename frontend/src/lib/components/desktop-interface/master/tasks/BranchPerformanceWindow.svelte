<script>
  import { onMount } from 'svelte';
  import { supabase } from '$lib/utils/supabase';
  import { currentUser } from '$lib/utils/persistentAuth';
  import { notifications } from '$lib/stores/notifications';

  let branches = [];
  let selectedBranch = 'all';
  let loading = false;
  let error = null;
  
  // Filter options
  let filterType = 'today'; // 'today', 'week', 'date', 'month'
  let customDate = '';
  let selectedMonth = '';
  let showDatePicker = false;
  let showMonthPicker = false;
  
  // Date labels for charts
  let currentPeriodLabel = '';
  let previousPeriodLabel = '';
  
  // Task data storage for detail view
  let allTasksData = {
    current: [],
    previous: [],
    total: []
  };
  
  // Detail window state
  let showDetailWindow = false;
  let detailWindowTasks = [];
  let detailWindowTitle = '';

  // Bilingual text content
  const text = {
    title: {
      ar: 'صحة أداء الفروع',
      en: 'Branch Performance Health'
    },
    filterBy: {
      ar: 'تصفية حسب الفرع:',
      en: 'Filter by branch:'
    },
    allBranches: {
      ar: 'جميع الفروع',
      en: 'All Branches'
    },
    refresh: {
      ar: 'تحديث',
      en: 'Refresh'
    },
    loading: {
      ar: 'جاري التحميل...',
      en: 'Loading...'
    },
    todayPerformance: {
      ar: 'أداء اليوم',
      en: "Today's Performance"
    },
    yesterdayPerformance: {
      ar: 'أداء الأمس',
      en: "Yesterday's Performance"
    },
    totalPerformance: {
      ar: 'الأداء الإجمالي',
      en: 'Total Performance'
    },
    completedTasks: {
      ar: 'المهام المكتملة',
      en: 'Completed Tasks'
    },
    notCompleted: {
      ar: 'غير مكتملة',
      en: 'Not Completed'
    },
    today: {
      ar: 'اليوم',
      en: 'TODAY'
    },
    yesterday: {
      ar: 'أمس',
      en: 'YESTERDAY'
    },
    total: {
      ar: 'المجموع',
      en: 'TOTAL'
    },
    detailedBreakdown: {
      ar: 'التفصيل المفصل',
      en: 'Detailed Breakdown'
    },
    receivingTotal: {
      ar: 'إجمالي الاستلام:',
      en: 'Receiving Total:'
    },
    receivingCompleted: {
      ar: 'الاستلام المكتمل:',
      en: 'Receiving Completed:'
    },
    receivingPending: {
      ar: 'الاستلام المعلق:',
      en: 'Receiving Pending:'
    },
    taskAssignmentsCompleted: {
      ar: 'تعيينات المهام المكتملة:',
      en: 'Task Assignments Completed:'
    },
    taskAssignmentsPending: {
      ar: 'تعيينات المهام المعلقة:',
      en: 'Task Assignments Pending:'
    },
    quickTasksCompleted: {
      ar: 'المهام السريعة المكتملة:',
      en: 'Quick Tasks Completed:'
    },
    quickTasksPending: {
      ar: 'المهام السريعة المعلقة:',
      en: 'Quick Tasks Pending:'
    },
    filterType: {
      ar: 'نوع الفلتر:',
      en: 'Filter Type:'
    },
    today: {
      ar: 'اليوم والأمس',
      en: 'Today & Yesterday'
    },
    thisWeek: {
      ar: 'هذا الأسبوع',
      en: 'This Week'
    },
    customDate: {
      ar: 'تاريخ محدد',
      en: 'Custom Date'
    },
    customMonth: {
      ar: 'شهر محدد',
      en: 'Custom Month'
    },
    selectDate: {
      ar: 'اختر التاريخ:',
      en: 'Select Date:'
    },
    selectMonth: {
      ar: 'اختر الشهر:',
      en: 'Select Month:'
    },
    apply: {
      ar: 'تطبيق',
      en: 'Apply'
    },
    currentPeriod: {
      ar: 'الفترة الحالية',
      en: 'Current Period'
    },
    previousPeriod: {
      ar: 'الفترة السابقة',
      en: 'Previous Period'
    },
    thisWeekLabel: {
      ar: 'هذا الأسبوع',
      en: 'THIS WEEK'
    },
    lastWeekLabel: {
      ar: 'الأسبوع الماضي',
      en: 'LAST WEEK'
    },
    selectedDateLabel: {
      ar: 'التاريخ المحدد',
      en: 'SELECTED DATE'
    },
    previousDayLabel: {
      ar: 'اليوم السابق',
      en: 'PREVIOUS DAY'
    },
    selectedMonthLabel: {
      ar: 'الشهر المحدد',
      en: 'SELECTED MONTH'
    },
    previousMonthLabel: {
      ar: 'الشهر السابق',
      en: 'PREVIOUS MONTH'
    },
    taskDetails: {
      ar: 'تفاصيل المهام',
      en: 'Task Details'
    },
    close: {
      ar: 'إغلاق',
      en: 'Close'
    },
    taskType: {
      ar: 'نوع المهمة',
      en: 'Task Type'
    },
    status: {
      ar: 'الحالة',
      en: 'Status'
    },
    date: {
      ar: 'التاريخ',
      en: 'Date'
    },
    branch: {
      ar: 'الفرع',
      en: 'Branch'
    },
    taskId: {
      ar: 'رقم المهمة',
      en: 'Task ID'
    },
    completed: {
      ar: 'مكتمل',
      en: 'Completed'
    },
    pending: {
      ar: 'معلق',
      en: 'Pending'
    },
    receiving: {
      ar: 'استلام',
      en: 'Receiving'
    },
    taskAssignment: {
      ar: 'تعيين مهمة',
      en: 'Task Assignment'
    },
    quickTask: {
      ar: 'مهمة سريعة',
      en: 'Quick Task'
    },
    clickToViewDetails: {
      ar: 'انقر لعرض التفاصيل',
      en: 'Click to view details'
    },
    assignedBy: {
      ar: 'تم التعيين بواسطة',
      en: 'Assigned By'
    },
    assignedTo: {
      ar: 'تم التعيين إلى',
      en: 'Assigned To'
    },
    delete: {
      ar: 'حذف',
      en: 'Delete'
    },
    confirmDelete: {
      ar: 'هل أنت متأكد من حذف هذه المهمة؟',
      en: 'Are you sure you want to delete this task?'
    },
    deleteSuccess: {
      ar: 'تم حذف المهمة بنجاح',
      en: 'Task deleted successfully'
    },
    deleteFailed: {
      ar: 'فشل حذف المهمة',
      en: 'Failed to delete task'
    },
    actions: {
      ar: 'الإجراءات',
      en: 'Actions'
    }
  };

  // Aggregated stats for chart and details
  let stats = {
    receiving: 0,
    completed: 0,
    notCompleted: 0,
    total: 0,
    details: {}
  };

  let todayStats = {
    completed: 0,
    notCompleted: 0,
    total: 0
  };

  let yesterdayStats = {
    completed: 0,
    notCompleted: 0,
    total: 0
  };

  onMount(() => {
    loadBranches();
    loadStats();
  });

  // Helper function to fetch all data with pagination
  async function fetchAllData(table, selectQuery, filters = null) {
    const BATCH_SIZE = 1000;
    let allData = [];
    let from = 0;
    let hasMore = true;

    while (hasMore) {
      let query = supabase
        .from(table)
        .select(selectQuery, { count: 'exact' })
        .range(from, from + BATCH_SIZE - 1);

      // Apply filters if provided
      if (filters) {
        Object.entries(filters).forEach(([key, value]) => {
          query = query.eq(key, value);
        });
      }

      const { data, error, count } = await query;

      if (error) {
        console.error(`Error fetching ${table}:`, error);
        throw error;
      }

      if (data && data.length > 0) {
        allData = allData.concat(data);
        from += BATCH_SIZE;
        hasMore = data.length === BATCH_SIZE;
      } else {
        hasMore = false;
      }
    }

    return allData;
  }

  async function loadBranches() {
    try {
      const { data, error: err } = await supabase.from('branches').select('id, name_ar, name_en').order('name_en');
      if (err) throw err;
      branches = (data || []).map(b => ({ 
        id: b.id, 
        name: `${b.name_ar || ''} ${b.name_en || ''}`.trim() || b.name_en || b.name_ar 
      }));
    } catch (e) {
      console.error('Failed to load branches', e);
      error = 'Failed to load branches';
    }
  }

  async function loadStats() {
    loading = true;
    error = null;

    try {
      let currentPeriodStr, previousPeriodStr;
      let currentPeriodStart, currentPeriodEnd, previousPeriodStart, previousPeriodEnd;

      // Calculate date ranges based on filter type
      if (filterType === 'today') {
        const today = new Date();
        const yesterday = new Date(today);
        yesterday.setDate(yesterday.getDate() - 1);
        currentPeriodStr = today.toISOString().split('T')[0];
        previousPeriodStr = yesterday.toISOString().split('T')[0];
        currentPeriodStart = currentPeriodEnd = currentPeriodStr;
        previousPeriodStart = previousPeriodEnd = previousPeriodStr;
        
        currentPeriodLabel = formatDate(today);
        previousPeriodLabel = formatDate(yesterday);
      } else if (filterType === 'week') {
        const today = new Date();
        const currentWeekStart = new Date(today);
        currentWeekStart.setDate(today.getDate() - today.getDay()); // Start of this week (Sunday)
        const currentWeekEnd = new Date(currentWeekStart);
        currentWeekEnd.setDate(currentWeekStart.getDate() + 6); // End of this week (Saturday)
        
        const lastWeekStart = new Date(currentWeekStart);
        lastWeekStart.setDate(currentWeekStart.getDate() - 7);
        const lastWeekEnd = new Date(lastWeekStart);
        lastWeekEnd.setDate(lastWeekStart.getDate() + 6);
        
        currentPeriodStart = currentWeekStart.toISOString().split('T')[0];
        currentPeriodEnd = currentWeekEnd.toISOString().split('T')[0];
        previousPeriodStart = lastWeekStart.toISOString().split('T')[0];
        previousPeriodEnd = lastWeekEnd.toISOString().split('T')[0];
        
        currentPeriodLabel = `${formatDate(currentWeekStart)} - ${formatDate(currentWeekEnd)}`;
        previousPeriodLabel = `${formatDate(lastWeekStart)} - ${formatDate(lastWeekEnd)}`;
      } else if (filterType === 'date') {
        if (!customDate) {
          error = 'Please select a date';
          loading = false;
          return;
        }
        const selectedDate = new Date(customDate + 'T00:00:00');
        const previousDate = new Date(selectedDate);
        previousDate.setDate(selectedDate.getDate() - 1);
        
        currentPeriodStart = currentPeriodEnd = customDate;
        previousPeriodStart = previousPeriodEnd = previousDate.toISOString().split('T')[0];
        
        currentPeriodLabel = formatDate(selectedDate);
        previousPeriodLabel = formatDate(previousDate);
      } else if (filterType === 'month') {
        if (!selectedMonth) {
          error = 'Please select a month';
          loading = false;
          return;
        }
        const [year, month] = selectedMonth.split('-').map(Number);
        const currentMonthStart = new Date(year, month - 1, 1);
        const currentMonthEnd = new Date(year, month, 0);
        
        const previousMonthStart = new Date(year, month - 2, 1);
        const previousMonthEnd = new Date(year, month - 1, 0);
        
        currentPeriodStart = currentMonthStart.toISOString().split('T')[0];
        currentPeriodEnd = currentMonthEnd.toISOString().split('T')[0];
        previousPeriodStart = previousMonthStart.toISOString().split('T')[0];
        previousPeriodEnd = previousMonthEnd.toISOString().split('T')[0];
        
        currentPeriodLabel = formatMonth(currentMonthStart);
        previousPeriodLabel = formatMonth(previousMonthStart);
      }

      // Fetch all data with pagination to avoid Supabase limits
      let receiving, tasks, quick;
      
      if (selectedBranch !== 'all') {
        const branchId = parseInt(selectedBranch);
        receiving = await fetchAllData('receiving_tasks', 'id, task_status, created_at, assigned_user_id, receiving_records!inner(branch_id, user_id)', { 'receiving_records.branch_id': branchId });
        tasks = await fetchAllData('task_assignments', 'id, status, assigned_at, assigned_to_branch_id, assigned_by, assigned_to_user_id', { 'assigned_to_branch_id': branchId });
        quick = (await fetchAllData('quick_task_assignments', 'id, status, created_at, assigned_to_user_id, quick_tasks!inner(assigned_to_branch_id, assigned_by)', { 'quick_tasks.assigned_to_branch_id': branchId })).filter(q => q.quick_tasks && q.quick_tasks.assigned_to_branch_id);
      } else {
        receiving = await fetchAllData('receiving_tasks', 'id, task_status, created_at, assigned_user_id, receiving_records!inner(branch_id, user_id)', null);
        tasks = await fetchAllData('task_assignments', 'id, status, assigned_at, assigned_to_branch_id, assigned_by, assigned_to_user_id', null);
        quick = (await fetchAllData('quick_task_assignments', 'id, status, created_at, assigned_to_user_id, quick_tasks!inner(assigned_to_branch_id, assigned_by)', null)).filter(q => q.quick_tasks && q.quick_tasks.assigned_to_branch_id);
      }

      // Filter by date ranges
      const isInCurrentPeriod = (dateStr) => dateStr >= currentPeriodStart && dateStr <= currentPeriodEnd;
      const isInPreviousPeriod = (dateStr) => dateStr >= previousPeriodStart && dateStr <= previousPeriodEnd;
      
      const todayReceiving = receiving.filter(r => r.created_at && isInCurrentPeriod(r.created_at.split('T')[0]));
      const yesterdayReceiving = receiving.filter(r => r.created_at && isInPreviousPeriod(r.created_at.split('T')[0]));
      
      const todayTasks = tasks.filter(t => t.assigned_at && isInCurrentPeriod(t.assigned_at.split('T')[0]));
      const yesterdayTasks = tasks.filter(t => t.assigned_at && isInPreviousPeriod(t.assigned_at.split('T')[0]));
      
      const todayQuick = quick.filter(q => q.created_at && isInCurrentPeriod(q.created_at.split('T')[0]));
      const yesterdayQuick = quick.filter(q => q.created_at && isInPreviousPeriod(q.created_at.split('T')[0]));

      // Calculate total counts
      const recCount = receiving.length;
      const recCompleted = receiving.filter(r => r.task_status === 'completed').length;
      const recPending = recCount - recCompleted;

      const taskCompleted = tasks.filter(t => t.status === 'completed').length;
      const taskPending = tasks.length - taskCompleted;

      const quickCompleted = quick.filter(q => q.status === 'completed').length;
      const quickPending = quick.length - quickCompleted;

      const totalCompleted = recCompleted + taskCompleted + quickCompleted;
      const totalPending = recPending + taskPending + quickPending;
      const totalTasks = recCount + tasks.length + quick.length;

      // Calculate today's counts
      const todayRecCompleted = todayReceiving.filter(r => r.task_status === 'completed').length;
      const todayTaskCompleted = todayTasks.filter(t => t.status === 'completed').length;
      const todayQuickCompleted = todayQuick.filter(q => q.status === 'completed').length;
      const todayTotalCompleted = todayRecCompleted + todayTaskCompleted + todayQuickCompleted;
      const todayTotal = todayReceiving.length + todayTasks.length + todayQuick.length;

      // Calculate yesterday's counts
      const yesterdayRecCompleted = yesterdayReceiving.filter(r => r.task_status === 'completed').length;
      const yesterdayTaskCompleted = yesterdayTasks.filter(t => t.status === 'completed').length;
      const yesterdayQuickCompleted = yesterdayQuick.filter(q => q.status === 'completed').length;
      const yesterdayTotalCompleted = yesterdayRecCompleted + yesterdayTaskCompleted + yesterdayQuickCompleted;
      const yesterdayTotal = yesterdayReceiving.length + yesterdayTasks.length + yesterdayQuick.length;

      // Store task data for detail view
      allTasksData = {
        current: [
          ...todayReceiving.map(r => ({ ...r, taskType: 'receiving', date: r.created_at, assigned_by: r.receiving_records?.user_id, assigned_to: r.assigned_user_id })),
          ...todayTasks.map(t => ({ ...t, taskType: 'task_assignment', date: t.assigned_at, assigned_by: t.assigned_by, assigned_to: t.assigned_to_user_id })),
          ...todayQuick.map(q => ({ ...q, taskType: 'quick_task', date: q.created_at, assigned_by: q.quick_tasks?.assigned_by, assigned_to: q.assigned_to_user_id }))
        ],
        previous: [
          ...yesterdayReceiving.map(r => ({ ...r, taskType: 'receiving', date: r.created_at, assigned_by: r.receiving_records?.user_id, assigned_to: r.assigned_user_id })),
          ...yesterdayTasks.map(t => ({ ...t, taskType: 'task_assignment', date: t.assigned_at, assigned_by: t.assigned_by, assigned_to: t.assigned_to_user_id })),
          ...yesterdayQuick.map(q => ({ ...q, taskType: 'quick_task', date: q.created_at, assigned_by: q.quick_tasks?.assigned_by, assigned_to: q.assigned_to_user_id }))
        ],
        total: [
          ...receiving.map(r => ({ ...r, taskType: 'receiving', date: r.created_at, assigned_by: r.receiving_records?.user_id, assigned_to: r.assigned_user_id })),
          ...tasks.map(t => ({ ...t, taskType: 'task_assignment', date: t.assigned_at, assigned_by: t.assigned_by, assigned_to: t.assigned_to_user_id })),
          ...quick.map(q => ({ ...q, taskType: 'quick_task', date: q.created_at, assigned_by: q.quick_tasks?.assigned_by, assigned_to: q.assigned_to_user_id }))
        ]
      };

      stats = {
        receiving: recCount,
        completed: totalCompleted,
        notCompleted: totalPending,
        total: totalTasks,
        details: {
          recCount,
          recCompleted,
          recPending,
          taskCompleted,
          taskPending,
          quickCompleted,
          quickPending
        }
      };

      todayStats = {
        completed: todayTotalCompleted,
        notCompleted: todayTotal - todayTotalCompleted,
        total: todayTotal
      };

      yesterdayStats = {
        completed: yesterdayTotalCompleted,
        notCompleted: yesterdayTotal - yesterdayTotalCompleted,
        total: yesterdayTotal
      };

    } catch (e) {
      console.error('Failed to load stats', e);
      error = 'Failed to load branch stats';
    } finally {
      loading = false;
    }
  }

  function onBranchChange(e) {
    selectedBranch = e.target.value;
    console.log('Selected branch:', selectedBranch, typeof selectedBranch);
    loadStats();
  }

  function onFilterTypeChange(e) {
    filterType = e.target.value;
    showDatePicker = filterType === 'date';
    showMonthPicker = filterType === 'month';
    
    // Auto-load for 'today' and 'week', wait for user input for 'date' and 'month'
    if (filterType === 'today' || filterType === 'week') {
      loadStats();
    }
  }

  function onApplyCustomFilter() {
    loadStats();
  }

  function getCurrentLabel() {
    if (filterType === 'today') return text.today.ar;
    if (filterType === 'week') return text.thisWeekLabel.ar;
    if (filterType === 'date') return text.selectedDateLabel.ar;
    if (filterType === 'month') return text.selectedMonthLabel.ar;
    return text.today.ar;
  }

  function getPreviousLabel() {
    if (filterType === 'today') return text.yesterday.ar;
    if (filterType === 'week') return text.lastWeekLabel.ar;
    if (filterType === 'date') return text.previousDayLabel.ar;
    if (filterType === 'month') return text.previousMonthLabel.ar;
    return text.yesterday.ar;
  }

  // Format date as DD/MM/YYYY
  function formatDate(date) {
    const d = new Date(date);
    const day = String(d.getDate()).padStart(2, '0');
    const month = String(d.getMonth() + 1).padStart(2, '0');
    const year = d.getFullYear();
    return `${day}/${month}/${year}`;
  }

  // Format month name and year
  function formatMonth(date) {
    const d = new Date(date);
    const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const monthNamesAr = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
    return `${monthNamesAr[d.getMonth()]} ${d.getFullYear()} / ${monthNames[d.getMonth()]} ${d.getFullYear()}`;
  }

  // Show task details in a window
  function showTaskDetails(period) {
    const tasks = allTasksData[period] || [];
    
    // Sort: incomplete tasks first, then completed
    const sortedTasks = [...tasks].sort((a, b) => {
      const aCompleted = getTaskStatus(a) === 'completed';
      const bCompleted = getTaskStatus(b) === 'completed';
      if (aCompleted === bCompleted) return 0;
      return aCompleted ? 1 : -1;
    });
    
    detailWindowTasks = sortedTasks;
    
    if (period === 'current') {
      detailWindowTitle = `${text.currentPeriod.ar} - ${currentPeriodLabel}`;
    } else if (period === 'previous') {
      detailWindowTitle = `${text.previousPeriod.ar} - ${previousPeriodLabel}`;
    } else {
      detailWindowTitle = `${text.totalPerformance.ar}`;
    }
    
    showDetailWindow = true;
    
    // Fetch user names for the tasks
    fetchUserNames(sortedTasks);
  }

  async function fetchUserNames(tasks) {
    const userIds = new Set();
    tasks.forEach(task => {
      if (task.assigned_by) userIds.add(task.assigned_by);
      if (task.assigned_to) userIds.add(task.assigned_to);
    });

    if (userIds.size === 0) return;

    try {
      const { data, error } = await supabase
        .from('users')
        .select('id, username, employee_id')
        .in('id', Array.from(userIds));

      if (error) throw error;

      const userMap = {};
      (data || []).forEach(user => {
        userMap[user.id] = user.username || `User ${user.id}`;
      });

      // Update tasks with user names
      detailWindowTasks = detailWindowTasks.map(task => ({
        ...task,
        assigned_by_name: task.assigned_by ? userMap[task.assigned_by] : null,
        assigned_to_name: task.assigned_to ? userMap[task.assigned_to] : null
      }));
    } catch (e) {
      console.error('Failed to fetch user names', e);
    }
  }

  function getTaskStatus(task) {
    if (task.taskType === 'receiving') return task.task_status;
    return task.status;
  }

  function getTaskTypeLabel(type) {
    if (type === 'receiving') return text.receiving;
    if (type === 'task_assignment') return text.taskAssignment;
    if (type === 'quick_task') return text.quickTask;
    return { ar: type, en: type };
  }

  function getStatusLabel(status) {
    return status === 'completed' ? text.completed : text.pending;
  }

  function closeDetailWindow() {
    showDetailWindow = false;
    detailWindowTasks = [];
    detailWindowTitle = '';
  }

  // Check if current user is master admin
  function isMasterAdmin() {
    console.log('Checking master admin:', {
      currentUser: $currentUser,
      isMasterAdmin: $currentUser?.isMasterAdmin,
      check: $currentUser && $currentUser.isMasterAdmin
    });
    return $currentUser && $currentUser.isMasterAdmin;
  }

  // Delete task
  async function deleteTask(task) {
    if (!confirm(`${text.confirmDelete.ar}\n${text.confirmDelete.en}`)) {
      return;
    }

    try {
      let deleteError = null;

      if (task.taskType === 'receiving') {
        const { error } = await supabase
          .from('receiving_tasks')
          .delete()
          .eq('id', task.id);
        deleteError = error;
      } else if (task.taskType === 'task_assignment') {
        const { error } = await supabase
          .from('task_assignments')
          .delete()
          .eq('id', task.id);
        deleteError = error;
      } else if (task.taskType === 'quick_task') {
        const { error } = await supabase
          .from('quick_task_assignments')
          .delete()
          .eq('id', task.id);
        deleteError = error;
      }

      if (deleteError) {
        throw deleteError;
      }

      // Remove from display
      detailWindowTasks = detailWindowTasks.filter(t => t.id !== task.id);
      
      // Reload stats to update charts
      loadStats();

      notifications.add({
        message: `${text.deleteSuccess.ar} / ${text.deleteSuccess.en}`,
        type: 'success',
        duration: 3000
      });
    } catch (err) {
      console.error('Failed to delete task:', err);
      notifications.add({
        message: `${text.deleteFailed.ar} / ${text.deleteFailed.en}`,
        type: 'error',
        duration: 5000
      });
    }
  }

  // Calculate percentage
  function getPercentage(value, total) {
    if (total === 0) return 0;
    return Math.round((value / total) * 100);
  }

  // Calculate SVG path for pie segments
  function createArcPath(centerX, centerY, radius, startAngle, endAngle) {
    const start = polarToCartesian(centerX, centerY, radius, endAngle);
    const end = polarToCartesian(centerX, centerY, radius, startAngle);
    const largeArcFlag = endAngle - startAngle <= 180 ? "0" : "1";
    
    return [
      "M", centerX, centerY,
      "L", start.x, start.y,
      "A", radius, radius, 0, largeArcFlag, 0, end.x, end.y,
      "Z"
    ].join(" ");
  }

  function polarToCartesian(centerX, centerY, radius, angleInDegrees) {
    const angleInRadians = (angleInDegrees - 90) * Math.PI / 180.0;
    return {
      x: centerX + (radius * Math.cos(angleInRadians)),
      y: centerY + (radius * Math.sin(angleInRadians))
    };
  }

  // Calculate text position for percentage labels
  function getTextPosition(centerX, centerY, radius, startAngle, endAngle) {
    const midAngle = (startAngle + endAngle) / 2;
    const textRadius = radius * 0.7; // Position text at 70% of radius
    return polarToCartesian(centerX, centerY, textRadius, midAngle);
  }

  // Generate chart data for any stats object
  function createChartData(statsObj) {
    return [
      { 
        label: text.completedTasks,
        value: statsObj.completed, 
        percentage: getPercentage(statsObj.completed, statsObj.total),
        color: '#22c55e',
        shadowColor: '#16a34a'
      },
      { 
        label: text.notCompleted,
        value: statsObj.notCompleted, 
        percentage: getPercentage(statsObj.notCompleted, statsObj.total),
        color: '#ef4444',
        shadowColor: '#dc2626'
      }
    ].filter(item => item.value > 0);
  }

  // Generate segments for any chart data
  function createSegments(chartData, total) {
    let currentAngle = 0;
    return chartData.map(item => {
      const angle = total > 0 ? (item.value / total) * 360 : 0;
      const textPos = getTextPosition(150, 150, 120, currentAngle, currentAngle + angle);
      const segment = {
        ...item,
        startAngle: currentAngle,
        endAngle: currentAngle + angle,
        path: createArcPath(150, 150, 120, currentAngle, currentAngle + angle),
        textX: textPos.x,
        textY: textPos.y
      };
      currentAngle += angle;
      return segment;
    });
  }

  // Create chart data
  $: totalChartData = createChartData(stats);
  $: todayChartData = createChartData(todayStats);
  $: yesterdayChartData = createChartData(yesterdayStats);

  // Calculate segments for each chart
  $: totalSegments = createSegments(totalChartData, stats.total);
  $: todaySegments = createSegments(todayChartData, todayStats.total);
  $: yesterdaySegments = createSegments(yesterdayChartData, yesterdayStats.total);
</script>

<style>
  .bp-container {
    padding: 20px;
    font-family: var(--font-family, 'Inter', Arial);
    background: white;
    max-height: 100vh;
    overflow-y: auto;
    direction: rtl;
  }

  .bilingual-text {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .arabic-text {
    font-weight: 600;
    color: #1f2937;
  }

  .english-text {
    font-weight: 500;
    color: #6b7280;
    font-size: 0.9em;
  }

  .header {
    display: flex;
    align-items: center;
    margin-bottom: 24px;
    padding-bottom: 16px;
    border-bottom: 2px solid #e5e7eb;
  }

  .header h3 {
    margin: 0;
    font-size: 24px;
    font-weight: 600;
    color: #1f2937;
  }

  .controls {
    display: flex;
    gap: 16px;
    align-items: center;
    margin-bottom: 24px;
    padding: 16px;
    background: #f9fafb;
    border-radius: 8px;
    border: 1px solid #e5e7eb;
    direction: ltr;
    flex-wrap: wrap;
  }

  .controls label {
    font-weight: 500;
    color: #374151;
    direction: rtl;
  }

  .controls select,
  .controls input[type="date"],
  .controls input[type="month"] {
    padding: 8px 12px;
    border: 1px solid #d1d5db;
    border-radius: 6px;
    background: white;
    font-size: 14px;
  }

  .controls button {
    padding: 8px 16px;
    background: #3b82f6;
    color: white;
    border: none;
    border-radius: 6px;
    cursor: pointer;
    font-size: 14px;
    font-weight: 500;
  }

  .controls button:hover {
    background: #2563eb;
  }

  .controls button.apply-btn {
    background: #10b981;
  }

  .controls button.apply-btn:hover {
    background: #059669;
  }

  .filter-group {
    display: flex;
    gap: 12px;
    align-items: center;
    padding: 8px 12px;
    background: white;
    border-radius: 6px;
    border: 1px solid #e5e7eb;
  }

  .chart-container {
    display: flex;
    flex-direction: column;
    gap: 40px;
    margin: 40px 0;
    padding: 20px;
    background: #f8fafc;
    border-radius: 12px;
    border: 1px solid #e2e8f0;
  }

  .charts-row {
    display: flex;
    align-items: center;
    justify-content: space-around;
    gap: 30px;
    flex-wrap: wrap;
  }

  .chart-section {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 16px;
    min-width: 280px;
  }

  .chart-title {
    font-size: 18px;
    font-weight: 600;
    color: #1f2937;
    text-align: center;
    margin-bottom: 8px;
  }

  .pie-chart {
    position: relative;
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    transition: transform 0.2s ease;
  }

  .pie-chart:hover {
    transform: scale(1.02);
  }

  .pie-svg {
    width: 250px;
    height: 250px;
    filter: drop-shadow(0 6px 12px rgba(0,0,0,0.15));
  }

  .pie-segment {
    cursor: pointer;
    transition: all 0.3s ease;
    filter: drop-shadow(0 4px 8px rgba(0,0,0,0.2));
  }

  .pie-segment:hover {
    transform: scale(1.05);
    filter: drop-shadow(0 6px 12px rgba(0,0,0,0.3)) brightness(1.1);
  }

  .pie-shadow {
    filter: blur(2px);
    opacity: 0.6;
    transform: translate(3px, 3px);
  }

  .segment-text {
    font-size: 16px;
    font-weight: 700;
    fill: white;
    text-anchor: middle;
    dominant-baseline: middle;
    text-shadow: 1px 1px 2px rgba(0,0,0,0.8);
    pointer-events: none;
  }

  .chart-center {
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    text-align: center;
    background: linear-gradient(135deg, #3b82f6 0%, #1d4ed8 50%, #1e40af 100%);
    border-radius: 50%;
    width: 100px;
    height: 100px;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    box-shadow: 0 6px 16px rgba(59, 130, 246, 0.4), inset 0 2px 4px rgba(255,255,255,0.2);
    border: 2px solid #1e40af;
  }

  .total-number {
    font-size: 28px;
    font-weight: 700;
    color: white;
    line-height: 1;
    text-shadow: 0 2px 4px rgba(0,0,0,0.3);
  }

  .total-label {
    font-size: 10px;
    color: rgba(255,255,255,0.9);
    font-weight: 600;
    margin-top: 2px;
    letter-spacing: 1px;
  }

  .legend {
    display: flex;
    flex-direction: column;
    gap: 16px;
  }

  .legend-item {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 12px 16px;
    background: white;
    border-radius: 8px;
    box-shadow: 0 1px 3px rgba(0,0,0,0.1);
    min-width: 200px;
  }

  .legend-color {
    width: 20px;
    height: 20px;
    border-radius: 50%;
    flex-shrink: 0;
  }

  .legend-text {
    display: flex;
    flex-direction: column;
    flex-grow: 1;
  }

  .legend-label {
    font-size: 14px;
    font-weight: 500;
    color: #1f2937;
  }

  .legend-stats {
    font-size: 12px;
    color: #6b7280;
    margin-top: 2px;
  }

  .legend-percentage {
    font-size: 18px;
    font-weight: 600;
    color: #1f2937;
  }

  .details {
    margin-top: 24px;
    border-top: 1px solid #e5e7eb;
    padding-top: 24px;
  }

  .details h4 {
    margin: 0 0 16px 0;
    font-size: 18px;
    font-weight: 600;
    color: #1f2937;
  }

  .details-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 16px;
  }

  .detail-item {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 12px 16px;
    background: #f9fafb;
    border-radius: 6px;
    border-left: 4px solid #3b82f6;
  }

  .detail-label {
    color: #6b7280;
    font-size: 14px;
  }

  .detail-value {
    font-weight: 600;
    font-size: 16px;
    color: #1f2937;
  }

  .error {
    padding: 12px 16px;
    background: #fef2f2;
    border: 1px solid #fecaca;
    border-radius: 6px;
    color: #dc2626;
    margin-bottom: 16px;
  }

  .loading {
    color: #6b7280;
    font-style: italic;
  }

  .detail-window-overlay {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.5);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 10000;
    padding: 20px;
  }

  .detail-window {
    background: white;
    border-radius: 12px;
    box-shadow: 0 20px 60px rgba(0,0,0,0.3);
    max-width: 1200px;
    width: 100%;
    max-height: 90vh;
    display: flex;
    flex-direction: column;
    direction: rtl;
  }

  .detail-window-header {
    padding: 20px 24px;
    border-bottom: 2px solid #e5e7eb;
    display: flex;
    justify-content: space-between;
    align-items: center;
    background: linear-gradient(135deg, #3b82f6 0%, #1d4ed8 100%);
    color: white;
    border-radius: 12px 12px 0 0;
  }

  .detail-window-header h3 {
    margin: 0;
    font-size: 20px;
    font-weight: 600;
  }

  .detail-window-header button {
    background: rgba(255, 255, 255, 0.2);
    border: 1px solid rgba(255, 255, 255, 0.3);
    color: white;
    padding: 8px 16px;
    border-radius: 6px;
    cursor: pointer;
    font-size: 14px;
    font-weight: 500;
    transition: background 0.2s ease;
  }

  .detail-window-header button:hover {
    background: rgba(255, 255, 255, 0.3);
  }

  .detail-window-body {
    padding: 24px;
    overflow-y: auto;
    flex: 1;
  }

  .task-table {
    width: 100%;
    border-collapse: collapse;
    background: white;
    border-radius: 8px;
    overflow: hidden;
    box-shadow: 0 1px 3px rgba(0,0,0,0.1);
  }

  .task-table thead {
    background: linear-gradient(135deg, #f3f4f6 0%, #e5e7eb 100%);
    position: sticky;
    top: 0;
    z-index: 10;
  }

  .task-table th {
    padding: 12px 16px;
    text-align: right;
    font-weight: 600;
    color: #1f2937;
    border-bottom: 2px solid #d1d5db;
    font-size: 14px;
  }

  .task-table td {
    padding: 12px 16px;
    text-align: right;
    border-bottom: 1px solid #e5e7eb;
    font-size: 14px;
    color: #374151;
  }

  .task-table tbody tr {
    transition: background 0.2s ease;
  }

  .task-table tbody tr:hover {
    background: #f9fafb;
  }

  .task-table tbody tr.incomplete {
    background: #fef2f2;
  }

  .task-table tbody tr.incomplete:hover {
    background: #fee2e2;
  }

  .task-table tbody tr.completed {
    opacity: 0.7;
  }

  .status-badge {
    display: inline-block;
    padding: 4px 12px;
    border-radius: 12px;
    font-size: 12px;
    font-weight: 600;
  }

  .status-badge.completed {
    background: #d1fae5;
    color: #065f46;
  }

  .status-badge.pending {
    background: #fee2e2;
    color: #991b1b;
  }

  .task-type-badge {
    display: inline-block;
    padding: 4px 10px;
    border-radius: 6px;
    font-size: 11px;
    font-weight: 500;
    background: #dbeafe;
    color: #1e40af;
  }

  .no-tasks {
    text-align: center;
    padding: 40px;
    color: #6b7280;
    font-size: 16px;
  }

  .click-hint {
    font-size: 11px;
    color: #6b7280;
    text-align: center;
    margin-top: 8px;
    font-style: italic;
  }

  .delete-btn {
    background: #ef4444;
    color: white;
    border: none;
    padding: 6px 12px;
    border-radius: 4px;
    cursor: pointer;
    font-size: 12px;
    font-weight: 500;
    transition: background 0.2s ease;
  }

  .delete-btn:hover {
    background: #dc2626;
  }

  .delete-btn:disabled {
    background: #9ca3af;
    cursor: not-allowed;
  }
</style>

<div class="bp-container">
  <div class="header">
    <h3 class="bilingual-text">
      <span class="arabic-text">📊 {text.title.ar}</span>
      <span class="english-text">({text.title.en})</span>
    </h3>
  </div>

  <div class="controls">
    <div class="filter-group">
      <label for="branch-select" class="bilingual-text">
        <span class="arabic-text">{text.filterBy.ar}</span>
        <span class="english-text">({text.filterBy.en})</span>
      </label>
      <select id="branch-select" on:change={onBranchChange} bind:value={selectedBranch}>
        <option value="all">{text.allBranches.ar} ({text.allBranches.en})</option>
        {#each branches as b}
          <option value={String(b.id)}>{b.name}</option>
        {/each}
      </select>
    </div>

    <div class="filter-group">
      <label for="filter-type" class="bilingual-text">
        <span class="arabic-text">{text.filterType.ar}</span>
        <span class="english-text">({text.filterType.en})</span>
      </label>
      <select id="filter-type" on:change={onFilterTypeChange} bind:value={filterType}>
        <option value="today">{text.today.ar} ({text.today.en})</option>
        <option value="week">{text.thisWeek.ar} ({text.thisWeek.en})</option>
        <option value="date">{text.customDate.ar} ({text.customDate.en})</option>
        <option value="month">{text.customMonth.ar} ({text.customMonth.en})</option>
      </select>
    </div>

    {#if showDatePicker}
      <div class="filter-group">
        <label for="custom-date" class="bilingual-text">
          <span class="arabic-text">{text.selectDate.ar}</span>
          <span class="english-text">({text.selectDate.en})</span>
        </label>
        <input type="date" id="custom-date" bind:value={customDate} />
        <button class="apply-btn" on:click={onApplyCustomFilter}>✓ {text.apply.ar}</button>
      </div>
    {/if}

    {#if showMonthPicker}
      <div class="filter-group">
        <label for="custom-month" class="bilingual-text">
          <span class="arabic-text">{text.selectMonth.ar}</span>
          <span class="english-text">({text.selectMonth.en})</span>
        </label>
        <input type="month" id="custom-month" bind:value={selectedMonth} />
        <button class="apply-btn" on:click={onApplyCustomFilter}>✓ {text.apply.ar}</button>
      </div>
    {/if}

    <button on:click={loadStats}>🔄 {text.refresh.ar} ({text.refresh.en})</button>
    {#if loading}
      <span class="loading">{text.loading.ar} ({text.loading.en})</span>
    {/if}
  </div>

  {#if error}
    <div class="error">❌ {error}</div>
  {/if}

  {#if stats.total > 0 || todayStats.total > 0 || yesterdayStats.total > 0}
    <div class="chart-container">
      <div class="charts-row">
        <!-- Current Period Chart -->
        <div class="chart-section">
          <h4 class="chart-title bilingual-text">
            <span class="arabic-text">📅 {text.currentPeriod.ar}</span>
            <span class="english-text">({text.currentPeriod.en})</span>
          </h4>
          {#if currentPeriodLabel}
            <div style="text-align: center; font-size: 13px; color: #6b7280; margin-bottom: 8px; font-weight: 500;">
              {currentPeriodLabel}
            </div>
          {/if}
          <div class="pie-chart" on:click={() => showTaskDetails('current')} title="{text.clickToViewDetails.ar} ({text.clickToViewDetails.en})" role="button" tabindex="0">
            <svg class="pie-svg" viewBox="0 0 300 300">
              <defs>
                {#each todaySegments as segment, i}
                  <radialGradient id="today-gradient-{i}" cx="30%" cy="30%">
                    <stop offset="0%" style="stop-color:{segment.color};stop-opacity:1" />
                    <stop offset="100%" style="stop-color:{segment.shadowColor};stop-opacity:1" />
                  </radialGradient>
                {/each}
              </defs>
              
              {#if todayStats.total > 0}
                <!-- Shadow layer -->
                {#each todaySegments as segment, i}
                  <path d={segment.path} fill={segment.shadowColor} class="pie-shadow" opacity="0.3" />
                {/each}
                
                <!-- Main segments -->
                {#each todaySegments as segment, i}
                  <path d={segment.path} fill="url(#today-gradient-{i})" class="pie-segment" 
                        title="{segment.label}: {segment.value} ({segment.percentage}%)" />
                {/each}
                
                <!-- Percentage text -->
                {#each todaySegments as segment}
                  {#if segment.percentage >= 5}
                    <text x={segment.textX} y={segment.textY} class="segment-text">{segment.percentage}%</text>
                  {/if}
                {/each}
              {:else}
                <circle cx="150" cy="150" r="120" fill="#e5e7eb" />
              {/if}
            </svg>
            <div class="chart-center">
              <div class="total-number">{todayStats.total}</div>
              <div class="total-label">{getCurrentLabel()}</div>
            </div>
          </div>
          <div class="click-hint">👆 {text.clickToViewDetails.ar}</div>
        </div>

        <!-- Previous Period Chart -->
        <div class="chart-section">
          <h4 class="chart-title bilingual-text">
            <span class="arabic-text">📆 {text.previousPeriod.ar}</span>
            <span class="english-text">({text.previousPeriod.en})</span>
          </h4>
          {#if previousPeriodLabel}
            <div style="text-align: center; font-size: 13px; color: #6b7280; margin-bottom: 8px; font-weight: 500;">
              {previousPeriodLabel}
            </div>
          {/if}
          <div class="pie-chart" on:click={() => showTaskDetails('previous')} title="{text.clickToViewDetails.ar} ({text.clickToViewDetails.en})" role="button" tabindex="0">
            <svg class="pie-svg" viewBox="0 0 300 300">
              <defs>
                {#each yesterdaySegments as segment, i}
                  <radialGradient id="yesterday-gradient-{i}" cx="30%" cy="30%">
                    <stop offset="0%" style="stop-color:{segment.color};stop-opacity:1" />
                    <stop offset="100%" style="stop-color:{segment.shadowColor};stop-opacity:1" />
                  </radialGradient>
                {/each}
              </defs>
              
              {#if yesterdayStats.total > 0}
                <!-- Shadow layer -->
                {#each yesterdaySegments as segment, i}
                  <path d={segment.path} fill={segment.shadowColor} class="pie-shadow" opacity="0.3" />
                {/each}
                
                <!-- Main segments -->
                {#each yesterdaySegments as segment, i}
                  <path d={segment.path} fill="url(#yesterday-gradient-{i})" class="pie-segment" 
                        title="{segment.label}: {segment.value} ({segment.percentage}%)" />
                {/each}
                
                <!-- Percentage text -->
                {#each yesterdaySegments as segment}
                  {#if segment.percentage >= 5}
                    <text x={segment.textX} y={segment.textY} class="segment-text">{segment.percentage}%</text>
                  {/if}
                {/each}
              {:else}
                <circle cx="150" cy="150" r="120" fill="#e5e7eb" />
              {/if}
            </svg>
            <div class="chart-center">
              <div class="total-number">{yesterdayStats.total}</div>
              <div class="total-label">{getPreviousLabel()}</div>
            </div>
          </div>
          <div class="click-hint">👆 {text.clickToViewDetails.ar}</div>
        </div>

        <!-- Combined Total Chart -->
        <div class="chart-section">
          <h4 class="chart-title bilingual-text">
            <span class="arabic-text">📊 {text.totalPerformance.ar}</span>
            <span class="english-text">({text.totalPerformance.en})</span>
          </h4>
          <div class="pie-chart" on:click={() => showTaskDetails('total')} title="{text.clickToViewDetails.ar} ({text.clickToViewDetails.en})" role="button" tabindex="0">
            <svg class="pie-svg" viewBox="0 0 300 300">
              <defs>
                {#each totalSegments as segment, i}
                  <radialGradient id="total-gradient-{i}" cx="30%" cy="30%">
                    <stop offset="0%" style="stop-color:{segment.color};stop-opacity:1" />
                    <stop offset="100%" style="stop-color:{segment.shadowColor};stop-opacity:1" />
                  </radialGradient>
                {/each}
              </defs>
              
              {#if stats.total > 0}
                <!-- Shadow layer -->
                {#each totalSegments as segment, i}
                  <path d={segment.path} fill={segment.shadowColor} class="pie-shadow" opacity="0.3" />
                {/each}
                
                <!-- Main segments -->
                {#each totalSegments as segment, i}
                  <path d={segment.path} fill="url(#total-gradient-{i})" class="pie-segment" 
                        title="{segment.label}: {segment.value} ({segment.percentage}%)" />
                {/each}
                
                <!-- Percentage text -->
                {#each totalSegments as segment}
                  {#if segment.percentage >= 5}
                    <text x={segment.textX} y={segment.textY} class="segment-text">{segment.percentage}%</text>
                  {/if}
                {/each}
              {:else}
                <circle cx="150" cy="150" r="120" fill="#e5e7eb" />
              {/if}
            </svg>
            <div class="chart-center">
              <div class="total-number">{stats.total}</div>
              <div class="total-label">{text.total.ar}</div>
            </div>
          </div>
          <div class="click-hint">👆 {text.clickToViewDetails.ar}</div>
        </div>
      </div>

      <!-- Legend for all charts -->
      <div class="legend">
        {#each totalChartData as item, index}
          <div class="legend-item">
            <div class="legend-color" style="background: linear-gradient(135deg, {item.color} 0%, {item.shadowColor} 100%); box-shadow: 0 2px 4px rgba(0,0,0,0.2);"></div>
            <div class="legend-text">
              <div class="legend-label bilingual-text">
                <span class="arabic-text">{item.label.ar}</span>
                <span class="english-text">({item.label.en})</span>
              </div>
              <div class="legend-stats">
                {text.total.ar}: {item.value} | {getCurrentLabel()}: {todayStats[item.label.ar === text.completedTasks.ar ? 'completed' : 'notCompleted']} | {getPreviousLabel()}: {yesterdayStats[item.label.ar === text.completedTasks.ar ? 'completed' : 'notCompleted']}
              </div>
            </div>
            <div class="legend-percentage">{item.percentage}%</div>
          </div>
        {/each}
      </div>
    </div>
  {:else}
    <div class="chart-container">
      <div class="charts-row">
        <div class="chart-section">
          <h4 class="chart-title bilingual-text">
            <span class="arabic-text">📅 {text.currentPeriod.ar}</span>
            <span class="english-text">({text.currentPeriod.en})</span>
          </h4>
          {#if currentPeriodLabel}
            <div style="text-align: center; font-size: 13px; color: #6b7280; margin-bottom: 8px; font-weight: 500;">
              {currentPeriodLabel}
            </div>
          {/if}
          <div class="pie-chart" on:click={() => showTaskDetails('current')} title="{text.clickToViewDetails.ar} ({text.clickToViewDetails.en})" role="button" tabindex="0">
            <svg class="pie-svg" viewBox="0 0 300 300">
              <circle cx="150" cy="150" r="120" fill="#e5e7eb" />
            </svg>
            <div class="chart-center">
              <div class="total-number">0</div>
              <div class="total-label">{getCurrentLabel()}</div>
            </div>
          </div>
          <div class="click-hint">👆 {text.clickToViewDetails.ar}</div>
        </div>
        
        <div class="chart-section">
          <h4 class="chart-title bilingual-text">
            <span class="arabic-text">📆 {text.previousPeriod.ar}</span>
            <span class="english-text">({text.previousPeriod.en})</span>
          </h4>
          {#if previousPeriodLabel}
            <div style="text-align: center; font-size: 13px; color: #6b7280; margin-bottom: 8px; font-weight: 500;">
              {previousPeriodLabel}
            </div>
          {/if}
          <div class="pie-chart" on:click={() => showTaskDetails('previous')} title="{text.clickToViewDetails.ar} ({text.clickToViewDetails.en})" role="button" tabindex="0">
            <svg class="pie-svg" viewBox="0 0 300 300">
              <circle cx="150" cy="150" r="120" fill="#e5e7eb" />
            </svg>
            <div class="chart-center">
              <div class="total-number">0</div>
              <div class="total-label">{getPreviousLabel()}</div>
            </div>
          </div>
          <div class="click-hint">👆 {text.clickToViewDetails.ar}</div>
        </div>
        
        <div class="chart-section">
          <h4 class="chart-title bilingual-text">
            <span class="arabic-text">📊 {text.totalPerformance.ar}</span>
            <span class="english-text">({text.totalPerformance.en})</span>
          </h4>
          <div class="pie-chart" on:click={() => showTaskDetails('total')} title="{text.clickToViewDetails.ar} ({text.clickToViewDetails.en})" role="button" tabindex="0">
            <svg class="pie-svg" viewBox="0 0 300 300">
              <circle cx="150" cy="150" r="120" fill="#e5e7eb" />
            </svg>
            <div class="chart-center">
              <div class="total-number">0</div>
              <div class="total-label">{text.total.ar}</div>
            </div>
          </div>
          <div class="click-hint">👆 {text.clickToViewDetails.ar}</div>
        </div>
      </div>
    </div>
  {/if}

  <div class="details">
    <h4 class="bilingual-text">
      <span class="arabic-text">📋 {text.detailedBreakdown.ar}</span>
      <span class="english-text">({text.detailedBreakdown.en})</span>
    </h4>
    <div class="details-grid">
      <div class="detail-item">
        <span class="detail-label bilingual-text">
          <span class="arabic-text">{text.receivingTotal.ar}</span>
          <span class="english-text">({text.receivingTotal.en})</span>
        </span>
        <span class="detail-value">{stats.details.recCount ?? 0}</span>
      </div>
      <div class="detail-item">
        <span class="detail-label bilingual-text">
          <span class="arabic-text">{text.receivingCompleted.ar}</span>
          <span class="english-text">({text.receivingCompleted.en})</span>
        </span>
        <span class="detail-value">{stats.details.recCompleted ?? 0}</span>
      </div>
      <div class="detail-item">
        <span class="detail-label bilingual-text">
          <span class="arabic-text">{text.receivingPending.ar}</span>
          <span class="english-text">({text.receivingPending.en})</span>
        </span>
        <span class="detail-value">{stats.details.recPending ?? 0}</span>
      </div>
      <div class="detail-item">
        <span class="detail-label bilingual-text">
          <span class="arabic-text">{text.taskAssignmentsCompleted.ar}</span>
          <span class="english-text">({text.taskAssignmentsCompleted.en})</span>
        </span>
        <span class="detail-value">{stats.details.taskCompleted ?? 0}</span>
      </div>
      <div class="detail-item">
        <span class="detail-label bilingual-text">
          <span class="arabic-text">{text.taskAssignmentsPending.ar}</span>
          <span class="english-text">({text.taskAssignmentsPending.en})</span>
        </span>
        <span class="detail-value">{stats.details.taskPending ?? 0}</span>
      </div>
      <div class="detail-item">
        <span class="detail-label bilingual-text">
          <span class="arabic-text">{text.quickTasksCompleted.ar}</span>
          <span class="english-text">({text.quickTasksCompleted.en})</span>
        </span>
        <span class="detail-value">{stats.details.quickCompleted ?? 0}</span>
      </div>
      <div class="detail-item">
        <span class="detail-label bilingual-text">
          <span class="arabic-text">{text.quickTasksPending.ar}</span>
          <span class="english-text">({text.quickTasksPending.en})</span>
        </span>
        <span class="detail-value">{stats.details.quickPending ?? 0}</span>
      </div>
    </div>
  </div>
</div>

{#if showDetailWindow}
  <div class="detail-window-overlay" on:click={closeDetailWindow}>
    <div class="detail-window" on:click|stopPropagation>
      <div class="detail-window-header">
        <h3 class="bilingual-text">
          <span class="arabic-text">📋 {text.taskDetails.ar} - {detailWindowTitle}</span>
        </h3>
        <button on:click={closeDetailWindow}>✕ {text.close.ar} ({text.close.en})</button>
      </div>
      <div class="detail-window-body">
        {#if detailWindowTasks.length > 0}
          <table class="task-table">
            <thead>
              <tr>
                <th>{text.taskId.ar} ({text.taskId.en})</th>
                <th>{text.taskType.ar} ({text.taskType.en})</th>
                <th>{text.status.ar} ({text.status.en})</th>
                <th>{text.assignedBy.ar} ({text.assignedBy.en})</th>
                <th>{text.assignedTo.ar} ({text.assignedTo.en})</th>
                <th>{text.date.ar} ({text.date.en})</th>
                {#if isMasterAdmin()}
                  <th>{text.actions.ar} ({text.actions.en})</th>
                {/if}
              </tr>
            </thead>
            <tbody>
              {#each detailWindowTasks as task}
                {@const taskStatus = getTaskStatus(task)}
                {@const isCompleted = taskStatus === 'completed'}
                <tr class={isCompleted ? 'completed' : 'incomplete'}>
                  <td>#{task.id}</td>
                  <td>
                    <span class="task-type-badge">
                      {getTaskTypeLabel(task.taskType).ar} ({getTaskTypeLabel(task.taskType).en})
                    </span>
                  </td>
                  <td>
                    <span class="status-badge {taskStatus}">
                      {getStatusLabel(taskStatus).ar} ({getStatusLabel(taskStatus).en})
                    </span>
                  </td>
                  <td>{task.assigned_by_name || '-'}</td>
                  <td>{task.assigned_to_name || '-'}</td>
                  <td>{task.date ? formatDate(new Date(task.date)) : '-'}</td>
                  {#if isMasterAdmin()}
                    <td>
                      <button class="delete-btn" on:click={() => deleteTask(task)} title="{text.delete.ar} ({text.delete.en})">
                        🗑️ {text.delete.ar}
                      </button>
                    </td>
                  {/if}
                </tr>
              {/each}
            </tbody>
          </table>
        {:else}
          <div class="no-tasks">
            لا توجد مهام لعرضها<br>
            <span style="font-size: 14px; color: #9ca3af;">(No tasks to display)</span>
          </div>
        {/if}
      </div>
    </div>
  </div>
{/if}