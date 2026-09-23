<script lang="ts">
  import { onMount, onDestroy, tick } from 'svelte';
  import { supabase } from '$lib/utils/supabase';
  import { locale } from '$lib/i18n';
  import { currentUser } from '$lib/utils/persistentAuth';
  import { taskCountService } from '$lib/stores/taskCount';

  export let compact = false;
  export let embedded = false;
  export let tableView = false;
  export let unifiedTableRows = false;
  export let taskCount = 0;
  export let loaded = false;
  export let searchQuery = '';
  export let selectedType = '';
  export let selectedStatus = '';
  export let selectedPriority = '';
  export let selectedBranch = '';
  export let rowStartIndex = 0;

  let tasks: any[] = [];
  let loading = true;
  let error = '';
  let busyTaskId = '';
  let filesByTask: Record<string, File[]> = {};
  let balanceByTask: Record<string, string> = {};
  let isRefreshing = false;

  let cameraTaskId = '';
  let cameraStream: MediaStream | null = null;
  let cameraError = '';
  let videoEl: HTMLVideoElement;
  let canvasEl: HTMLCanvasElement;

  $: isArabic = $locale === 'ar';
  $: displayedTasks = tasks.filter((task) => {
    const query = searchQuery.trim().toLowerCase();
    const refs = task.source_refs || {};
    const matchesSearch = !query || [title(task), refs.vendor_name, refs.bill_number, refs.received_by].some((value) => String(value || '').toLowerCase().includes(query));
    const matchesType = !selectedType || selectedType === 'auto_task';
    const matchesStatus = !selectedStatus || task.status === selectedStatus || (selectedStatus === 'assigned' && task.status === 'active');
    const matchesPriority = !selectedPriority || task.priority === selectedPriority;
    const branch = String(refs.branch_name || refs.branch_id || task.branch_id || '');
    const matchesBranch = !selectedBranch || branch === selectedBranch;
    return matchesSearch && matchesType && matchesStatus && matchesPriority && matchesBranch;
  });

  onMount(() => {
    loadTasks();
    const timer = setInterval(() => loadTasks(true), 5000);
    const refreshWhenVisible = () => {
      if (document.visibilityState === 'visible') loadTasks(true);
    };
    window.addEventListener('focus', refreshWhenVisible);
    document.addEventListener('visibilitychange', refreshWhenVisible);
    return () => {
      clearInterval(timer);
      window.removeEventListener('focus', refreshWhenVisible);
      document.removeEventListener('visibilitychange', refreshWhenVisible);
    };
  });

  export async function refresh() {
    await loadTasks();
  }

  async function loadTasks(silent = false) {
    if (isRefreshing) return;
    isRefreshing = true;
    if (!silent || tasks.length === 0) loading = true;
    error = '';
    if (!$currentUser?.id) {
      tasks = [];
      taskCount = 0;
      error = 'Current Aqura user is unavailable.';
      loading = false;
      isRefreshing = false;
      loaded = true;
      return;
    }
    const { data, error: rpcError } = await supabase.rpc('Autotask_list_my_tasks', {
      p_user_id: $currentUser.id,
      p_include_completed: false,
      p_limit: 500
    });
    if (rpcError) {
      error = rpcError.message || 'Failed to load Auto Tasks.';
    } else {
      tasks = data || [];
      taskCount = tasks.length;
      taskCountService.setAutoTaskCounts(taskCount, tasks.filter((task) => task.is_overdue).length);
    }
    loading = false;
    isRefreshing = false;
    loaded = true;
  }

  function title(task: any) {
    return isArabic ? task.title_ar : task.title_en;
  }

  function dueText(task: any) {
    if (task.is_overdue) return isArabic ? 'متأخرة' : 'Overdue';
    return new Date(task.due_at).toLocaleString(isArabic ? 'ar-SA' : 'en-GB', { hour12: true });
  }

  function receivingDateText(value: string) {
    return new Date(value).toLocaleString(isArabic ? 'ar-SA' : 'en-GB', { hour12: true });
  }

  // Opens the device camera directly (getUserMedia) instead of the OS file/gallery picker.
  async function openCamera(taskId: string) {
    cameraError = '';
    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: { ideal: 'environment' } },
        audio: false
      });
      cameraTaskId = taskId;
      await tick();
      cameraStream = stream;
      if (videoEl) {
        videoEl.srcObject = stream;
        await videoEl.play();
      }
    } catch (caught) {
      cameraError = isArabic ? 'تعذر الوصول إلى الكاميرا.' : 'Unable to access the camera.';
    }
  }

  function capturePhoto() {
    if (!videoEl || !canvasEl || !cameraTaskId) return;
    canvasEl.width = videoEl.videoWidth;
    canvasEl.height = videoEl.videoHeight;
    const ctx = canvasEl.getContext('2d');
    if (!ctx) return;
    ctx.drawImage(videoEl, 0, 0, canvasEl.width, canvasEl.height);
    const taskId = cameraTaskId;
    canvasEl.toBlob((blob) => {
      if (!blob) return;
      const file = new File([blob], `evidence-${Date.now()}.jpg`, { type: 'image/jpeg' });
      filesByTask = { ...filesByTask, [taskId]: [...(filesByTask[taskId] || []), file] };
    }, 'image/jpeg', 0.9);
  }

  function removePhoto(taskId: string, index: number) {
    const files = [...(filesByTask[taskId] || [])];
    files.splice(index, 1);
    filesByTask = { ...filesByTask, [taskId]: files };
  }

  function stopCameraStream() {
    cameraStream?.getTracks().forEach((track) => track.stop());
    cameraStream = null;
  }

  function closeCamera() {
    stopCameraStream();
    cameraTaskId = '';
  }

  onDestroy(stopCameraStream);

  async function uploadEvidence(task: any) {
    const files = filesByTask[task.id] || [];
    for (const file of files) {
      const safeName = file.name.replace(/[^a-zA-Z0-9._-]/g, '_');
      const path = `${task.source_table}/${task.source_record_id}/${task.id}/${crypto.randomUUID()}-${safeName}`;
      const { error: uploadError } = await supabase.storage.from('Autotask_evidence').upload(path, file, {
        contentType: file.type || undefined,
        upsert: false
      });
      if (uploadError) throw uploadError;
      const { error: evidenceError } = await supabase.rpc('Autotask_register_evidence', {
        p_actor_user_id: $currentUser.id,
        p_task_id: task.id,
        p_storage_path: path,
        p_mime_type: file.type || null,
        p_size_bytes: file.size
      });
      if (evidenceError) {
        await supabase.storage.from('Autotask_evidence').remove([path]);
        throw evidenceError;
      }
    }
  }

  async function complete(task: any) {
    busyTaskId = task.id;
    error = '';
    try {
      if (task.task_number === 1 && (filesByTask[task.id] || []).length < 1) {
        throw new Error(isArabic ? 'يجب رفع صورة واحدة على الأقل.' : 'Upload at least one photo.');
      }
      if (task.task_number === 3 && !balanceByTask[task.id]) {
        throw new Error(isArabic ? 'حدد حالة رصيد المستودع.' : 'Select the warehouse balance status.');
      }
      if (task.task_number === 3 && balanceByTask[task.id] === 'yes' && (filesByTask[task.id] || []).length < 1) {
        throw new Error(isArabic ? 'الصورة مطلوبة عند وجود رصيد.' : 'A photo is required when balance remains.');
      }
      await uploadEvidence(task);
      const completionData = task.task_number === 3
        ? { has_warehouse_balance: balanceByTask[task.id] === 'yes' }
        : {};
      const { error: completionError } = await supabase.rpc('Autotask_complete_task', {
        p_actor_user_id: $currentUser.id,
        p_task_id: task.id,
        p_completion_data: completionData
      });
      if (completionError) throw completionError;
      filesByTask = { ...filesByTask, [task.id]: [] };
      await loadTasks();
    } catch (caught: any) {
      error = caught?.message || 'Failed to complete Auto Task.';
    } finally {
      busyTaskId = '';
    }
  }
</script>

<svelte:element this={unifiedTableRows ? 'tbody' : 'section'} class:compact class:embedded class="autotask-panel" aria-label={isArabic ? 'مهامي' : 'My Tasks'}>
  {#if !embedded}<div class="panel-heading">
    <h2>{isArabic ? 'المهام التلقائية' : 'Auto Tasks'}</h2>
    <button type="button" on:click={loadTasks} disabled={loading}>{isArabic ? 'تحديث' : 'Refresh'}</button>
  </div>{/if}

  {#if error && !unifiedTableRows}<p class="error" role="alert">{error}</p>{/if}
  {#if loading}
    {#if unifiedTableRows}
      <tr><td colspan="9" class="unified-loading">{isArabic ? 'جارٍ تحميل المهام التلقائية…' : 'Loading Auto Tasks…'}</td></tr>
    {:else}
      <p class="empty">{isArabic ? 'جارٍ التحميل…' : 'Loading…'}</p>
    {/if}
  {:else if tasks.length === 0 && !embedded}
    <p class="empty">{isArabic ? 'لا توجد مهام تلقائية نشطة.' : 'No active Auto Tasks.'}</p>
  {:else if unifiedTableRows}
    {#each displayedTasks as task, index (task.id)}
      <tr class:overdue-row={task.is_overdue} class:blocked-row={task.status === 'blocked'} class="unified-auto-row">
        <td class="unified-cell unified-number">{rowStartIndex + index + 1}</td>
        <td class="unified-cell"><div class="unified-title">{title(task)}</div><div class="unified-subtitle">{task.source_refs?.vendor_name || '—'}{#if task.source_refs?.bill_number} · {task.source_refs.bill_number}{/if}</div></td>
        <td class="unified-cell unified-center"><span class="unified-type">⚙️ {isArabic ? 'تلقائي' : 'Auto Task'}</span></td>
        <td class="unified-cell">{task.source_refs?.branch_name || task.source_refs?.branch_id || task.branch_id || '—'}</td>
        <td class="unified-cell unified-center"><span class="status">{task.is_overdue ? (isArabic ? 'متأخرة' : 'Overdue') : task.status}</span></td>
        <td class="unified-cell unified-center"><span class="unified-priority">{task.priority || (isArabic ? 'متوسط' : 'Medium')}</span></td>
        <td class="unified-cell unified-center">{dueText(task)}</td>
        <td class="unified-cell">{isArabic ? 'النظام التلقائي' : 'Auto Task System'}</td>
        <td class="unified-cell unified-center unified-actions">
          {#if task.status === 'blocked'}
            <span class="condition-text">{isArabic ? 'بانتظار المهام السابقة' : 'Waiting for dependencies'}</span>
          {:else if task.task_number === 1 || task.task_number === 2 || task.task_number === 3}
            {#if task.task_number === 3}
              <label><input type="radio" name={`unified-balance-${task.id}`} value="no" bind:group={balanceByTask[task.id]} /> {isArabic ? 'لا يوجد رصيد' : 'No balance'}</label>
              <label><input type="radio" name={`unified-balance-${task.id}`} value="yes" bind:group={balanceByTask[task.id]} /> {isArabic ? 'يوجد رصيد' : 'Balance remains'}</label>
            {/if}
            {#if task.task_number === 1 || (task.task_number === 3 && balanceByTask[task.id] === 'yes')}
              <button type="button" class="camera-btn" on:click={() => openCamera(task.id)}>{isArabic ? 'صورة' : 'Photo'}{#if (filesByTask[task.id] || []).length} ({filesByTask[task.id].length}){/if}</button>
            {/if}
            <button class="complete" type="button" on:click={() => complete(task)} disabled={busyTaskId === task.id}>{busyTaskId === task.id ? (isArabic ? 'جارٍ…' : 'Completing…') : (isArabic ? 'إكمال' : 'Complete')}</button>
          {:else}
            <span class="condition-text">{isArabic ? 'تغلق تلقائياً' : 'Closes automatically'}</span>
          {/if}
        </td>
      </tr>
    {/each}
  {:else if tableView}
    <div class="table-wrap">
      <table class="task-table">
        <thead>
          <tr>
            <th>#</th><th>{isArabic ? 'المهمة' : 'Task'}</th><th>{isArabic ? 'الحالة' : 'Status'}</th>
            <th>{isArabic ? 'الموعد' : 'Due'}</th><th>{isArabic ? 'المورد' : 'Vendor'}</th>
            <th>{isArabic ? 'رقم الفاتورة' : 'Bill number'}</th><th>{isArabic ? 'تاريخ الاستلام' : 'Receiving date'}</th>
            <th>{isArabic ? 'تم الاستلام بواسطة' : 'Received by'}</th><th>{isArabic ? 'الإجراء' : 'Action'}</th>
          </tr>
        </thead>
        <tbody>
          {#each tasks as task}
            <tr class:overdue-row={task.is_overdue} class:blocked-row={task.status === 'blocked'}>
              <td class="task-number">#{task.task_number}</td>
              <td class="task-name">{title(task)}</td>
              <td><span class="status">{task.is_overdue ? (isArabic ? 'متأخرة' : 'Overdue') : task.status}</span></td>
              <td>{dueText(task)}</td>
              <td>{task.source_refs?.vendor_name || '—'}</td>
              <td>{task.source_refs?.bill_number || '—'}</td>
              <td>{task.source_refs?.receiving_date ? receivingDateText(task.source_refs.receiving_date) : '—'}</td>
              <td>{task.source_refs?.received_by || '—'}</td>
              <td class="table-action">
                {#if task.status === 'blocked'}
                  <span class="condition-text">{isArabic ? 'بانتظار اكتمال المهام السابقة' : 'Waiting for dependencies'}</span>
                {:else if task.task_number === 1 || task.task_number === 2 || task.task_number === 3}
                  {#if task.task_number === 3}
                    <label><input type="radio" name={`table-balance-${task.id}`} value="no" bind:group={balanceByTask[task.id]} /> {isArabic ? 'لا يوجد رصيد' : 'No balance'}</label>
                    <label><input type="radio" name={`table-balance-${task.id}`} value="yes" bind:group={balanceByTask[task.id]} /> {isArabic ? 'يوجد رصيد' : 'Balance remains'}</label>
                  {/if}
                  {#if task.task_number === 1 || (task.task_number === 3 && balanceByTask[task.id] === 'yes')}
                    <button type="button" class="camera-btn table-camera-btn" on:click={() => openCamera(task.id)}>
                      <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M23 19a2 2 0 01-2 2H3a2 2 0 01-2-2V8a2 2 0 012-2h4l2-3h6l2 3h4a2 2 0 012 2z"/><circle cx="12" cy="13" r="4"/></svg>
                      {isArabic ? 'التقاط صورة' : 'Take Photo'}{#if (filesByTask[task.id] || []).length > 0} ({(filesByTask[task.id] || []).length}){/if}
                    </button>
                  {/if}
                  <button class="complete table-complete" type="button" on:click={() => complete(task)} disabled={busyTaskId === task.id}>
                    {busyTaskId === task.id ? (isArabic ? 'جارٍ الإكمال…' : 'Completing…') : (isArabic ? 'إكمال' : 'Complete')}
                  </button>
                {:else}
                  <span class="condition-text">{isArabic ? 'تُغلق تلقائيًا عند تحقق الشرط' : 'Closes automatically'}</span>
                {/if}
              </td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>
  {:else}
    <div class="task-grid">
      {#each tasks as task}
        <article class:overdue={task.is_overdue} class:blocked={task.status === 'blocked'} class="task-card">
          <div class="task-title-row">
            <span class="number">#{task.task_number}</span>
            <h3>{title(task)}</h3>
            <span class="status">{task.is_overdue ? (isArabic ? 'متأخرة' : 'Overdue') : task.status}</span>
          </div>
          <div class="meta">
            <span>{isArabic ? 'الموعد:' : 'Due:'} {dueText(task)}</span>
            <span><strong>{isArabic ? 'المورد:' : 'Vendor:'}</strong> {task.source_refs?.vendor_name || '—'}</span>
            <span><strong>{isArabic ? 'رقم الفاتورة:' : 'Bill number:'}</strong> {task.source_refs?.bill_number || '—'}</span>
            <span><strong>{isArabic ? 'تاريخ الاستلام:' : 'Receiving date:'}</strong> {task.source_refs?.receiving_date ? receivingDateText(task.source_refs.receiving_date) : '—'}</span>
            <span><strong>{isArabic ? 'تم الاستلام بواسطة:' : 'Received by:'}</strong> {task.source_refs?.received_by || '—'}</span>
          </div>

          {#if task.status === 'blocked'}
            <p class="blocked-message">{isArabic ? 'مرئية الآن، لكن لا يمكن إغلاقها حتى تكتمل المهام السابقة.' : 'Visible now, but cannot be closed until its dependencies are complete.'}</p>
          {:else if task.task_number === 1 || task.task_number === 2 || task.task_number === 3}
            {#if task.task_number === 3}
              <div class="choice-row">
                <label><input type="radio" name={`balance-${task.id}`} value="no" bind:group={balanceByTask[task.id]} /> {isArabic ? 'لا يوجد رصيد في المستودع' : 'No warehouse balance remains'}</label>
                <label><input type="radio" name={`balance-${task.id}`} value="yes" bind:group={balanceByTask[task.id]} /> {isArabic ? 'يوجد رصيد في المستودع' : 'Warehouse balance remains'}</label>
              </div>
            {/if}
            {#if task.task_number === 1 || (task.task_number === 3 && balanceByTask[task.id] === 'yes')}
              <div class="upload-label">
                <span>{isArabic ? 'صور الإثبات (صورة واحدة على الأقل)' : 'Evidence photos (minimum one)'}</span>
                <button type="button" class="camera-btn" on:click={() => openCamera(task.id)}>
                  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M23 19a2 2 0 01-2 2H3a2 2 0 01-2-2V8a2 2 0 012-2h4l2-3h6l2 3h4a2 2 0 012 2z"/><circle cx="12" cy="13" r="4"/></svg>
                  {isArabic ? 'التقاط صورة' : 'Take Photo'}
                </button>
              </div>
              {#if (filesByTask[task.id] || []).length > 0}<small>{(filesByTask[task.id] || []).length} {isArabic ? 'ملف' : 'file(s) selected'}</small>{/if}
            {/if}
            <button class="complete" type="button" on:click={() => complete(task)} disabled={busyTaskId === task.id}>
              {busyTaskId === task.id ? (isArabic ? 'جارٍ الإكمال…' : 'Completing…') : (isArabic ? 'إكمال المهمة' : 'Complete Task')}
            </button>
          {:else}
            <p class="automatic">{isArabic ? 'تُغلق هذه المهمة تلقائيًا عند تحقق شرطها.' : 'This task closes automatically when its operational condition is met.'}</p>
          {/if}
        </article>
      {/each}
    </div>
  {/if}
</svelte:element>

{#if cameraTaskId}
  <div class="camera-modal" role="dialog" aria-modal="true">
    <div class="camera-modal-inner">
      <video bind:this={videoEl} autoplay playsinline muted class="camera-video"></video>
      <canvas bind:this={canvasEl} class="camera-canvas" hidden></canvas>
      {#if cameraError}<p class="error">{cameraError}</p>{/if}
      {#if (filesByTask[cameraTaskId] || []).length > 0}
        <div class="camera-thumbs">
          {#each filesByTask[cameraTaskId] as file, index (index)}
            <div class="camera-thumb">
              <img src={URL.createObjectURL(file)} alt="" />
              <button type="button" class="thumb-remove" on:click={() => removePhoto(cameraTaskId, index)}>×</button>
            </div>
          {/each}
        </div>
      {/if}
      <div class="camera-actions">
        <button type="button" class="camera-capture" on:click={capturePhoto} disabled={!cameraStream}>{isArabic ? 'التقاط' : 'Capture'}</button>
        <button type="button" class="camera-done" on:click={closeCamera}>{isArabic ? 'تم' : 'Done'}{#if (filesByTask[cameraTaskId] || []).length > 0} ({(filesByTask[cameraTaskId] || []).length}){/if}</button>
      </div>
    </div>
  </div>
{/if}

<style>
  .autotask-panel{margin:1rem 0;padding:1rem;border:1px solid #cbd5e1;border-radius:14px;background:#f8fafc}.autotask-panel.embedded{margin:0;padding:0;border:0;border-radius:0;background:transparent}.panel-heading{display:flex;align-items:center;justify-content:space-between;gap:1rem}.panel-heading h2{margin:0;font-size:1.15rem}.panel-heading button,.complete{border:0;border-radius:8px;padding:.55rem .85rem;cursor:pointer}.panel-heading button{background:#e2e8f0}.task-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(270px,1fr));gap:.75rem;margin-top:.8rem}.embedded .task-grid{margin-top:0;margin-bottom:.75rem}.task-card{padding:.85rem;border:1px solid #dbeafe;border-left:4px solid #2563eb;border-radius:10px;background:white}.task-card.overdue{border-left-color:#dc2626}.task-card.blocked{border-left-color:#64748b;background:#f1f5f9}.task-title-row{display:flex;align-items:center;gap:.45rem}.task-title-row h3{font-size:.95rem;margin:0;flex:1}.number{font-weight:800;color:#2563eb}.status{text-transform:capitalize;font-size:.72rem;padding:.2rem .4rem;border-radius:999px;background:#e2e8f0}.meta{display:flex;flex-direction:column;gap:.2rem;margin:.55rem 0;color:#475569;font-size:.78rem}.blocked-message,.automatic{font-size:.8rem;color:#475569}.choice-row{display:flex;flex-direction:column;gap:.35rem;font-size:.82rem;margin:.6rem 0}.upload-label{display:flex;flex-direction:column;gap:.35rem;font-size:.8rem;font-weight:600}.complete{margin-top:.65rem;background:#2563eb;color:white}.complete:disabled,.panel-heading button:disabled{opacity:.55;cursor:not-allowed}.error{color:#b91c1c;background:#fee2e2;padding:.6rem;border-radius:8px}.empty{color:#64748b}.compact{padding:.75rem}.compact.embedded{padding:0}.compact .task-grid{grid-template-columns:1fr}
  .table-wrap{width:100%;overflow:auto;margin-bottom:1rem;border:1px solid #e2e8f0;border-radius:12px;background:white}.task-table{width:100%;min-width:1180px;border-collapse:collapse;font-size:.75rem;color:#475569}.task-table th{position:sticky;top:0;z-index:1;padding:.7rem .6rem;text-align:left;background:#f1f5f9;color:#334155;font-weight:800;border-bottom:1px solid #cbd5e1;white-space:nowrap}.task-table td{padding:.65rem .6rem;vertical-align:top;border-bottom:1px solid #e2e8f0}.task-table tbody tr:last-child td{border-bottom:0}.task-table tbody tr:hover{background:#f8fafc}.task-table .blocked-row{background:#f8fafc}.task-table .overdue-row{background:#fff7f7}.task-number{font-weight:900;color:#2563eb;white-space:nowrap}.task-name{min-width:165px;font-weight:700;color:#1e293b}.table-action{min-width:190px}.table-action label{display:block;margin-bottom:.25rem;white-space:nowrap}.condition-text{font-size:.7rem;color:#64748b}.table-file{display:none}.table-complete{margin-top:.3rem;padding:.4rem .65rem;font-size:.72rem}
  .file-input{display:none}.camera-btn{display:inline-flex;align-items:center;gap:.4rem;padding:.5rem .85rem;background:#10b981;color:white;border-radius:8px;font-size:.8rem;font-weight:600;cursor:pointer;border:none;width:fit-content}.camera-btn:hover{background:#059669}.table-camera-btn{display:inline-flex;padding:.35rem .6rem;font-size:.7rem;margin:.25rem 0}
  .camera-modal{position:fixed;inset:0;background:rgba(15,23,42,.85);display:flex;align-items:center;justify-content:center;z-index:1000;padding:1rem}.camera-modal-inner{background:#0f172a;border-radius:14px;padding:.75rem;display:flex;flex-direction:column;gap:.6rem;max-width:480px;width:100%}.camera-video{width:100%;border-radius:10px;background:#000;max-height:60vh;object-fit:cover}.camera-thumbs{display:flex;gap:.4rem;flex-wrap:wrap;max-height:90px;overflow-y:auto}.camera-thumb{position:relative;width:56px;height:56px}.camera-thumb img{width:100%;height:100%;object-fit:cover;border-radius:6px}.thumb-remove{position:absolute;top:-6px;right:-6px;background:#dc2626;color:#fff;border:none;border-radius:999px;width:18px;height:18px;font-size:.7rem;line-height:1;cursor:pointer;padding:0}.camera-actions{display:flex;gap:.5rem}.camera-capture,.camera-done{flex:1;border:none;border-radius:8px;padding:.65rem;font-weight:700;cursor:pointer;color:#fff}.camera-capture{background:#2563eb}.camera-capture:disabled{opacity:.5;cursor:not-allowed}.camera-done{background:#10b981}
  .autotask-panel:has(.unified-auto-row){display:contents}.unified-auto-row{transition:background .2s}.unified-auto-row:hover{background:#f0fdfa}.unified-cell{padding:.625rem 1rem;border-inline:1px solid #e2e8f0;font-size:.78rem;color:#475569}.unified-number{font-family:monospace;color:#94a3b8}.unified-center{text-align:center}.unified-title{max-width:280px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;font-size:.875rem;font-weight:600;color:#1e293b}.unified-subtitle{max-width:280px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;font-size:.65rem;color:#94a3b8}.unified-type{display:inline-flex;gap:.25rem;padding:.25rem .625rem;border:1px solid #99f6e4;border-radius:.5rem;background:#f0fdfa;color:#0f766e;font-size:.65rem;font-weight:700}.unified-priority{font-size:.72rem;font-weight:700;color:#d97706}.unified-actions{min-width:170px}.unified-actions label{display:block;font-size:.65rem}.unified-actions button{min-height:30px;margin:.15rem;border:0;border-radius:.5rem;padding:.35rem .55rem;color:#fff;font-size:.68rem;font-weight:700}.unified-actions .camera-btn{background:#3b82f6}.unified-actions .complete{background:#10b981}
  tbody.autotask-panel{display:table-row-group!important}
</style>
