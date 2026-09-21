<script lang="ts">
  import { currentLocale } from '$lib/i18n';

  export let kind: 'safeBox' | 'cashier';
  export let active = false;

  type Branch = { id: number; name_en: string; name_ar: string };
  type User = { id: string; nameEn: string; nameAr: string; branchId: number };
  type Row = {
    id: string; at: string; branchId: number; userId: string; userNameEn: string; userNameAr: string;
    branchNameEn: string; branchNameAr: string; action: string; reason: string;
    requestId: string; requestNumber: string; printer: string; printStatus: string; posCounter: string; posNumber: string;
    amount: number | null; status: string; details: Record<string, unknown>;
  };

  const denominations: [string, string, number][] = [
    ['d500', '500 SAR', 500], ['d200', '200 SAR', 200], ['d100', '100 SAR', 100],
    ['d50', '50 SAR', 50], ['d20', '20 SAR', 20], ['d10', '10 SAR', 10],
    ['d5', '5 SAR', 5], ['d2', '2 SAR', 2], ['d1', '1 SAR', 1],
    ['d05', '0.5 SAR', 0.5], ['d025', '0.25 SAR', 0.25], ['coins', 'Coins', 1], ['damage', 'Damage', 1]
  ];
  let initialized = false;
  let loading = false;
  let error = '';
  let rows: Row[] = [];
  let branches: Branch[] = [];
  let users: User[] = [];
  let actions: string[] = [];
  let statuses: string[] = [];
  let from = '';
  let to = '';
  let branchId = '';
  let userId = '';
  let action = '';
  let status = '';
  let search = '';
  let page = 0;
  let pageSize = 75;
  let total = 0;
  let truncated = false;
  let expandedId = '';
  let searchTimer: ReturnType<typeof setTimeout>;
  let requestSequence = 0;

  $: if (active && !initialized) {
    initialized = true;
    void initialize();
  }
  $: visibleUsers = users.filter(user => !branchId || String(user.branchId) === branchId);

  async function initialize() {
    try {
      const response = await fetch('/api/drawer-action-audit?mode=options', { cache: 'no-store' });
      const data = await response.json();
      if (!response.ok) throw new Error(data.error || 'Could not load report filters.');
      branches = data.branches || [];
      users = data.users || [];
      await loadRows();
    } catch (cause) { error = cause instanceof Error ? cause.message : 'Could not load report filters.'; }
  }

  async function loadRows() {
    const sequence = ++requestSequence;
    loading = true;
    error = '';
    try {
      const params = new URLSearchParams({ kind, page: String(page) });
      if (from) params.set('from', from);
      if (to) params.set('to', to);
      if (branchId) params.set('branchId', branchId);
      if (userId) params.set('userId', userId);
      if (action) params.set('action', action);
      if (status) params.set('status', status);
      if (search.trim()) params.set('search', search.trim());
      const response = await fetch(`/api/drawer-action-audit?${params}`, { cache: 'no-store' });
      const data = await response.json();
      if (!response.ok) throw new Error(data.error || 'Could not load actions.');
      if (sequence !== requestSequence) return;
      rows = data.rows || [];
      total = data.total || 0;
      pageSize = data.pageSize || 75;
      actions = data.actions || [];
      statuses = data.statuses || [];
      users = [...new Map([...users, ...(data.reportUsers || [])].map(user => [`${user.id}:${user.branchId}`, user] as const)).values()];
      truncated = data.truncated === true;
      expandedId = '';
    } catch (cause) {
      if (sequence === requestSequence) error = cause instanceof Error ? cause.message : 'Could not load actions.';
    } finally { if (sequence === requestSequence) loading = false; }
  }

  function applyFilters() { page = 0; void loadRows(); }
  function searchChanged() { clearTimeout(searchTimer); searchTimer = setTimeout(applyFilters, 350); }
  function resetFilters() {
    from = ''; to = ''; branchId = ''; userId = ''; action = ''; status = ''; search = '';
    clearTimeout(searchTimer); applyFilters();
  }
  function branchChanged() { userId = ''; applyFilters(); }
  function movePage(next: number) { page = next; void loadRows(); }
  function person(row: Row) { return $currentLocale === 'ar' ? row.userNameAr : row.userNameEn; }
  function branch(row: Row) { return $currentLocale === 'ar' ? row.branchNameAr : row.branchNameEn; }
  function userLabel(user: User) { return ($currentLocale === 'ar' ? user.nameAr || user.nameEn : user.nameEn || user.nameAr) || user.id; }
  function branchLabel(item: Branch) { return ($currentLocale === 'ar' ? item.name_ar || item.name_en : item.name_en || item.name_ar) || `Branch ${item.id}`; }
  function datePart(value: string) { return new Intl.DateTimeFormat($currentLocale === 'ar' ? 'ar-SA' : 'en-GB',
    { timeZone: 'Asia/Riyadh', calendar: 'gregory', day: '2-digit', month: '2-digit', year: 'numeric' }).format(new Date(value)); }
  function timePart(value: string) { return new Intl.DateTimeFormat($currentLocale === 'ar' ? 'ar-SA' : 'en-GB',
    { timeZone: 'Asia/Riyadh', hour: '2-digit', minute: '2-digit', second: '2-digit' }).format(new Date(value)); }
  function money(value: number | null) { return value == null ? '—' : `${value.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} SAR`; }
  function detailLabel(key: string) { return key.replace(/([A-Z])/g, ' $1').replace(/^./, letter => letter.toUpperCase()); }
  function isCountMap(key: string, value: unknown): value is Record<string, number> {
    return /Counts$/.test(key) && !!value && typeof value === 'object' && !Array.isArray(value);
  }
  type AuditEvent = { at: string; action: string; status?: string; printStatus: string; reason: string; printer: string; error: string };
  function isAuditEvents(key: string, value: unknown): value is AuditEvent[] {
    return key === 'auditEvents' && Array.isArray(value);
  }
  function countLines(value: Record<string, number>) {
    return denominations.filter(([key]) => Number(value[key]) > 0).map(([key, label, amount]) => ({
      label, count: Number(value[key]), total: Number(value[key]) * amount
    }));
  }
  function detailText(value: unknown): string {
    if (value == null || value === '') return '—';
    if (typeof value === 'object') return JSON.stringify(value);
    return String(value);
  }
</script>

<div class="audit-report">
  <div class="audit-filters">
    <label>From Date<input type="date" bind:value={from} on:change={applyFilters} /></label>
    <label>To Date<input type="date" bind:value={to} on:change={applyFilters} /></label>
    <label>Branch<select bind:value={branchId} on:change={branchChanged} disabled={branches.length <= 1}>
      <option value="">All permitted branches</option>
      {#each branches as item}<option value={item.id}>{branchLabel(item)}</option>{/each}
    </select></label>
    <label>User<select bind:value={userId} on:change={applyFilters}>
      <option value="">All users</option>
      {#each visibleUsers as user}<option value={user.id}>{userLabel(user)}</option>{/each}
    </select></label>
    <label>Action Type<select bind:value={action} on:change={applyFilters}>
      <option value="">All actions</option>
      {#each actions as item}<option value={item}>{item}</option>{/each}
    </select></label>
    <label>Status<select bind:value={status} on:change={applyFilters}>
      <option value="">All statuses</option>
      {#each statuses as item}<option value={item}>{item}</option>{/each}
    </select></label>
    <label class="search-label">Search<input type="search" bind:value={search} on:input={searchChanged} on:keydown={(event) => { if (event.key === 'Enter') { clearTimeout(searchTimer); applyFilters(); } }} placeholder="Reason, request, printer, user…" /></label>
    <button class="filter-button" type="button" on:click={resetFilters}>Reset</button>
    <button class="filter-button primary" type="button" on:click={() => void loadRows()} disabled={loading}>Refresh</button>
  </div>
  {#if error}<p class="audit-error" role="alert">{error}</p>{/if}
  {#if truncated}<p class="audit-note">Showing the newest records from a large audit history. Narrow the date or branch filters to see older actions.</p>{/if}
  <div class="audit-summary"><span>{loading ? 'Loading actions…' : `${total.toLocaleString()} actions`}</span><span>Times shown in Saudi Arabia time</span></div>
  <div class="audit-table-wrap">
    <table class="audit-table">
      <thead><tr><th>Date</th><th>Time</th><th>Branch</th><th>User</th><th>Action</th><th>Reason</th><th>Request ID</th><th>Printer</th><th>Print Status</th>{#if kind === 'safeBox'}<th>Amount</th>{:else}<th>POS Counter</th><th>POS Number</th>{/if}<th>Status</th><th>Details</th></tr></thead>
      <tbody>
        {#each rows as row (row.id)}
          <tr><td>{datePart(row.at)}</td><td>{timePart(row.at)}</td><td>{branch(row)}</td><td>{person(row)}</td><td class="action-name">{row.action}</td><td>{row.reason || '—'}</td><td title={row.requestId}>{row.requestNumber || '—'}</td><td>{row.printer || '—'}</td><td>{row.printStatus || '—'}</td>{#if kind === 'safeBox'}<td>{money(row.amount)}</td>{:else}<td>{row.posCounter || '—'}</td><td>{row.posNumber || '—'}</td>{/if}<td><span class="report-status">{row.status || '—'}</span></td><td><button type="button" class="details-button" aria-expanded={expandedId === row.id} on:click={() => (expandedId = expandedId === row.id ? '' : row.id)}>{expandedId === row.id ? 'Hide Details' : 'View Details'}</button></td></tr>
          {#if expandedId === row.id}
            <tr class="details-row"><td colspan={kind === 'safeBox' ? 12 : 13}>
              <div class="details-grid">
                {#each Object.entries(row.details).filter(([, value]) => value !== null && value !== undefined && value !== '') as [key, value]}
                  <div class="detail-item"><strong>{detailLabel(key)}</strong>
                    {#if isAuditEvents(key, value)}
                      <table class="breakdown"><thead><tr><th>Date</th><th>Time</th><th>Step</th><th>Status</th><th>Print Status</th><th>Reason</th><th>Printer</th><th>Error</th></tr></thead>
                        <tbody>{#each value as event}<tr><td>{datePart(event.at)}</td><td>{timePart(event.at)}</td><td>{event.action}</td><td>{event.status || '—'}</td><td>{event.printStatus || '—'}</td><td>{event.reason || '—'}</td><td>{event.printer || '—'}</td><td>{event.error || '—'}</td></tr>{/each}</tbody></table>
                    {:else if isCountMap(key, value)}
                      {@const lines = countLines(value)}
                      {#if lines.length}<table class="breakdown"><thead><tr><th>Denomination</th><th>Quantity</th><th>Total</th></tr></thead><tbody>{#each lines as line}<tr><td>{line.label}</td><td>{line.count}</td><td>{money(line.total)}</td></tr>{/each}</tbody></table>
                      {:else}<span>None</span>{/if}
                    {:else}<span>{detailText(value)}</span>{/if}
                  </div>
                {/each}
              </div>
            </td></tr>
          {/if}
        {:else}
          {#if !loading && !error}<tr><td class="empty-row" colspan={kind === 'safeBox' ? 12 : 13}>No actions match these filters.</td></tr>{/if}
        {/each}
      </tbody>
    </table>
  </div>
  <div class="audit-pagination">
    <span>{total ? `${page * pageSize + 1}–${Math.min((page + 1) * pageSize, total)} of ${total}` : '0 actions'}</span>
    <div><button type="button" disabled={loading || page === 0} on:click={() => movePage(page - 1)}>Previous</button>
      <button type="button" disabled={loading || (page + 1) * pageSize >= total} on:click={() => movePage(page + 1)}>Next</button></div>
  </div>
</div>

<style>
  .audit-report { display:flex; flex-direction:column; gap:.75rem; min-height:0; height:100%; }
  .audit-filters { display:flex; flex-wrap:wrap; align-items:end; gap:.65rem; padding:.85rem; background:#fffafa; border:1px solid #fecaca; border-radius:12px; }
  .audit-filters label { display:grid; gap:.25rem; min-width:135px; color:#991b1b; font-size:.72rem; font-weight:700; }
  .audit-filters input,.audit-filters select { min-height:34px; padding:.35rem .5rem; border:1px solid #fca5a5; border-radius:7px; background:white; color:#334155; font-size:.8rem; }
  .audit-filters .search-label { flex:1 1 180px; }
  .filter-button,.audit-pagination button,.details-button { border:1px solid #fca5a5; border-radius:7px; padding:.45rem .7rem; background:white; color:#991b1b; font-size:.78rem; font-weight:700; cursor:pointer; }
  .filter-button.primary { background:#dc2626; color:white; border-color:#dc2626; }
  button:disabled { opacity:.45; cursor:not-allowed; }
  .audit-error { margin:0; padding:.65rem; color:#991b1b; background:#fee2e2; border-radius:8px; }
  .audit-note { margin:0; padding:.55rem; color:#854d0e; background:#fef3c7; border-radius:8px; font-size:.78rem; }
  .audit-summary,.audit-pagination { display:flex; justify-content:space-between; align-items:center; gap:.7rem; color:#7f1d1d; font-size:.78rem; font-weight:700; }
  .audit-pagination > div { display:flex; gap:.45rem; }
  .audit-table-wrap { flex:1 1 auto; min-height:0; overflow:auto; border:1px solid #fecaca; border-radius:10px; background:white; }
  .audit-table { width:100%; min-width:1300px; border-collapse:collapse; font-size:.78rem; }
  .audit-table th { position:sticky; top:0; z-index:1; padding:.6rem; text-align:left; color:#991b1b; background:#fee2e2; white-space:nowrap; }
  .audit-table td { padding:.55rem .6rem; border-top:1px solid #fee2e2; color:#334155; vertical-align:top; }
  .audit-table .action-name { font-weight:700; color:#7f1d1d; }
  .report-status { display:inline-block; border-radius:999px; background:#fef2f2; color:#991b1b; padding:.2rem .5rem; white-space:nowrap; }
  .details-button { white-space:nowrap; }
  .details-row td { background:#fff7f7; }
  .details-grid { display:grid; grid-template-columns:repeat(auto-fit,minmax(210px,1fr)); gap:.7rem; }
  .detail-item { display:grid; align-content:start; gap:.25rem; min-width:0; overflow-wrap:anywhere; }
  .detail-item > strong { color:#991b1b; font-size:.72rem; }
  .breakdown { width:100%; border-collapse:collapse; }
  .breakdown th,.breakdown td { position:static; padding:.25rem; border:0; background:transparent; color:#334155; font-size:.72rem; }
  .empty-row { text-align:center; padding:2rem !important; color:#64748b !important; }
</style>
