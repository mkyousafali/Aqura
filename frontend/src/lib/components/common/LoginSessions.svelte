<script lang="ts">
  import { onMount } from 'svelte';
  import { currentLocale } from '$lib/i18n';
  import { currentUser } from '$lib/utils/persistentAuth';
  import { supabase } from '$lib/utils/supabase';
  import { getCurrentInterfaceSessionToken } from '$lib/utils/interfaceSessionGuard';

  export let mobile = false;

  type SessionRow = {
    id: string;
    interface_type: 'desktop' | 'mobile';
    login_at: string;
    last_activity: string;
    is_current: boolean;
  };

  let sessions: SessionRow[] = [];
  let loading = true;
  let error = '';
  let removing = '';

  $: ar = $currentLocale === 'ar';

  function currentToken(): string | null {
    const user = $currentUser;
    if (!user?.id || !user.interfaceType) return null;
    return getCurrentInterfaceSessionToken(user.id, user.interfaceType);
  }

  async function loadSessions() {
    const token = currentToken();
    if (!$currentUser?.id || !token) return;
    loading = true;
    error = '';
    const { data, error: rpcError } = await supabase.rpc('list_my_interface_sessions', {
      p_user_id: $currentUser.id,
      p_session_token: token
    });
    if (rpcError) error = ar ? 'تعذر تحميل جلسات تسجيل الدخول.' : 'Unable to load login sessions.';
    else sessions = Array.isArray(data) ? data : [];
    loading = false;
  }

  async function logoutSession(session: SessionRow) {
    if (session.is_current || removing) return;
    const accepted = window.confirm(ar
      ? 'هل تريد بالتأكيد تسجيل خروج هذه الجلسة؟'
      : 'Are you sure you want to log out this session?');
    if (!accepted) return;
    const token = currentToken();
    if (!$currentUser?.id || !token) return;
    removing = session.id;
    const { data, error: rpcError } = await supabase.rpc('logout_my_interface_session', {
      p_user_id: $currentUser.id,
      p_current_session_token: token,
      p_session_id: session.id
    });
    if (rpcError || !data?.success) error = ar ? 'تعذر تسجيل خروج الجلسة.' : 'Unable to log out the session.';
    await loadSessions();
    removing = '';
  }

  function formatTime(value: string): string {
    return new Intl.DateTimeFormat(ar ? 'ar-SA' : 'en-GB', {
      dateStyle: 'medium', timeStyle: 'short'
    }).format(new Date(value));
  }

  onMount(() => { void loadSessions(); });
</script>

<section class:mobile class="sessions" dir={ar ? 'rtl' : 'ltr'}>
  <header>
    <div>
      <h2>{ar ? 'جلسات تسجيل الدخول' : 'Login Sessions'}</h2>
      <p>{ar ? 'إدارة جلسات سطح المكتب والجوال النشطة.' : 'Manage your active Desktop and Mobile sessions.'}</p>
    </div>
    <button class="refresh" on:click={loadSessions} disabled={loading} aria-label={ar ? 'تحديث' : 'Refresh'}>↻</button>
  </header>

  {#if error}<div class="error">{error}</div>{/if}
  {#if loading}
    <div class="state">{ar ? 'جارٍ التحميل…' : 'Loading…'}</div>
  {:else if sessions.length === 0}
    <div class="state">{ar ? 'لا توجد جلسات نشطة.' : 'No active sessions.'}</div>
  {:else}
    <div class="list">
      {#each sessions as session (session.id)}
        <article class:current={session.is_current}>
          <div class="topline">
            <strong>{session.interface_type === 'desktop' ? (ar ? 'سطح المكتب' : 'Desktop') : (ar ? 'الجوال' : 'Mobile')}</strong>
            {#if session.is_current}<span class="badge">{ar ? 'الجلسة الحالية' : 'Current session'}</span>{/if}
          </div>
          <dl>
            <div><dt>{ar ? 'وقت تسجيل الدخول' : 'Login time'}</dt><dd>{formatTime(session.login_at)}</dd></div>
            <div><dt>{ar ? 'آخر نشاط' : 'Last activity'}</dt><dd>{formatTime(session.last_activity)}</dd></div>
          </dl>
          {#if !session.is_current}
            <button class="logout" disabled={removing === session.id} on:click={() => logoutSession(session)}>
              {removing === session.id ? (ar ? 'جارٍ تسجيل الخروج…' : 'Logging out…') : (ar ? 'تسجيل الخروج' : 'Log out')}
            </button>
          {/if}
        </article>
      {/each}
    </div>
  {/if}
</section>

<style>
  .sessions{height:100%;overflow:auto;background:#f8fafc;padding:24px;color:#172033;font-family:inherit}.sessions.mobile{min-height:100%;padding:18px 14px 100px}header{display:flex;align-items:flex-start;justify-content:space-between;gap:16px;margin-bottom:20px}h2{margin:0;font-size:24px}p{margin:5px 0 0;color:#64748b}.refresh{border:1px solid #cbd5e1;background:white;border-radius:10px;width:40px;height:40px;font-size:22px;cursor:pointer}.list{display:grid;gap:12px}article{background:white;border:1px solid #e2e8f0;border-radius:14px;padding:18px;box-shadow:0 2px 8px rgba(15,23,42,.04)}article.current{border-color:#38bdf8;background:#f0f9ff}.topline{display:flex;align-items:center;justify-content:space-between;gap:12px;font-size:17px}.badge{background:#0284c7;color:white;border-radius:999px;padding:4px 9px;font-size:12px;font-weight:700}dl{display:grid;grid-template-columns:1fr 1fr;gap:12px;margin:16px 0 0}dl div{min-width:0}dt{font-size:12px;color:#64748b;margin-bottom:3px}dd{margin:0;font-weight:600;font-size:14px}.logout{margin-top:16px;border:0;border-radius:9px;background:#dc2626;color:white;padding:9px 15px;font-weight:700;cursor:pointer}.logout:disabled,.refresh:disabled{opacity:.55}.state,.error{padding:28px;text-align:center;background:white;border-radius:12px}.error{color:#b91c1c;background:#fef2f2;margin-bottom:12px;padding:12px}@media(max-width:600px){dl{grid-template-columns:1fr}.sessions{padding:16px}h2{font-size:21px}}
</style>
