<script>
  import { onMount } from 'svelte';
  import { supabase } from '$lib/utils/supabase';

  let branches = [];
  let selectedBranch = 'all';
  let loading = false;
  let error = null;

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
      const today = new Date();
      const yesterday = new Date(today);
      yesterday.setDate(yesterday.getDate() - 1);

      const todayStr = today.toISOString().split('T')[0];
      const yesterdayStr = yesterday.toISOString().split('T')[0];

      let receivingQuery = supabase.from('receiving_tasks').select('id, task_status, created_at, receiving_records!inner(branch_id)');
      let taskQuery = supabase.from('task_assignments').select('id, status, assigned_at, assigned_to_branch_id');
      let quickQuery = supabase.from('quick_task_assignments').select('id, status, created_at, quick_tasks!inner(assigned_to_branch_id)');

      if (selectedBranch !== 'all') {
        const branchId = parseInt(selectedBranch);
        receivingQuery = receivingQuery.eq('receiving_records.branch_id', branchId);
        taskQuery = taskQuery.eq('assigned_to_branch_id', branchId);
        quickQuery = quickQuery.eq('quick_tasks.assigned_to_branch_id', branchId);
      }

      const [recRes, taskRes, quickRes] = await Promise.all([
        receivingQuery,
        taskQuery,
        quickQuery
      ]);

      if (recRes.error) throw recRes.error;
      if (taskRes.error) throw taskRes.error;
      if (quickRes.error) throw quickRes.error;

      const receiving = recRes.data || [];
      const tasks = taskRes.data || [];
      const quick = (quickRes.data || []).filter(q => q.quick_tasks && q.quick_tasks.assigned_to_branch_id);

      // Filter by date
      const todayReceiving = receiving.filter(r => r.created_at?.startsWith(todayStr));
      const yesterdayReceiving = receiving.filter(r => r.created_at?.startsWith(yesterdayStr));
      
      const todayTasks = tasks.filter(t => t.assigned_at?.startsWith(todayStr));
      const yesterdayTasks = tasks.filter(t => t.assigned_at?.startsWith(yesterdayStr));
      
      const todayQuick = quick.filter(q => q.created_at?.startsWith(todayStr));
      const yesterdayQuick = quick.filter(q => q.created_at?.startsWith(yesterdayStr));

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
  }

  .controls label {
    font-weight: 500;
    color: #374151;
    direction: rtl;
  }

  .controls select {
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
</style>

<div class="bp-container">
  <div class="header">
    <h3 class="bilingual-text">
      <span class="arabic-text">📊 {text.title.ar}</span>
      <span class="english-text">({text.title.en})</span>
    </h3>
  </div>

  <div class="controls">
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
        <!-- Today's Chart -->
        <div class="chart-section">
          <h4 class="chart-title bilingual-text">
            <span class="arabic-text">📅 {text.todayPerformance.ar}</span>
            <span class="english-text">({text.todayPerformance.en})</span>
          </h4>
          <div class="pie-chart">
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
              <div class="total-label">{text.today.ar}</div>
            </div>
          </div>
        </div>

        <!-- Yesterday's Chart -->
        <div class="chart-section">
          <h4 class="chart-title bilingual-text">
            <span class="arabic-text">📆 {text.yesterdayPerformance.ar}</span>
            <span class="english-text">({text.yesterdayPerformance.en})</span>
          </h4>
          <div class="pie-chart">
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
              <div class="total-label">{text.yesterday.ar}</div>
            </div>
          </div>
        </div>

        <!-- Total Chart -->
        <div class="chart-section">
          <h4 class="chart-title bilingual-text">
            <span class="arabic-text">📊 {text.totalPerformance.ar}</span>
            <span class="english-text">({text.totalPerformance.en})</span>
          </h4>
          <div class="pie-chart">
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
                {text.total.ar}: {item.value} | {text.today.ar}: {todayStats[item.label.ar === text.completedTasks.ar ? 'completed' : 'notCompleted']} | {text.yesterday.ar}: {yesterdayStats[item.label.ar === text.completedTasks.ar ? 'completed' : 'notCompleted']}
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
            <span class="arabic-text">📅 {text.todayPerformance.ar}</span>
            <span class="english-text">({text.todayPerformance.en})</span>
          </h4>
          <div class="pie-chart">
            <svg class="pie-svg" viewBox="0 0 300 300">
              <circle cx="150" cy="150" r="120" fill="#e5e7eb" />
            </svg>
            <div class="chart-center">
              <div class="total-number">0</div>
              <div class="total-label">{text.today.ar}</div>
            </div>
          </div>
        </div>
        
        <div class="chart-section">
          <h4 class="chart-title bilingual-text">
            <span class="arabic-text">📆 {text.yesterdayPerformance.ar}</span>
            <span class="english-text">({text.yesterdayPerformance.en})</span>
          </h4>
          <div class="pie-chart">
            <svg class="pie-svg" viewBox="0 0 300 300">
              <circle cx="150" cy="150" r="120" fill="#e5e7eb" />
            </svg>
            <div class="chart-center">
              <div class="total-number">0</div>
              <div class="total-label">{text.yesterday.ar}</div>
            </div>
          </div>
        </div>
        
        <div class="chart-section">
          <h4 class="chart-title bilingual-text">
            <span class="arabic-text">📊 {text.totalPerformance.ar}</span>
            <span class="english-text">({text.totalPerformance.en})</span>
          </h4>
          <div class="pie-chart">
            <svg class="pie-svg" viewBox="0 0 300 300">
              <circle cx="150" cy="150" r="120" fill="#e5e7eb" />
            </svg>
            <div class="chart-center">
              <div class="total-number">0</div>
              <div class="total-label">{text.total.ar}</div>
            </div>
          </div>
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