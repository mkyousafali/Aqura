import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { databaseClient } from '$lib/server/breakRegisterAuth';
import { safeBoxSchemaUnavailable } from '$lib/server/safeBoxControl';

export const GET: RequestHandler = async ({ request }) => {
  const userId = request.headers.get('x-cashier-user-id');
  const token = request.headers.get('x-cashier-session-token');
  if (!userId || !token) return json({ error: 'Cashier session required.' }, { status: 401 });
  const db = databaseClient();
  const { data: session, error } = await db.rpc('heartbeat_cashier_session', {
    p_user_id: userId, p_session_token: token
  });
  if (error || session?.valid !== true) return json({ error: 'Cashier session expired.' }, { status: 401 });
  const { data: employee } = await db.from('hr_employee_master').select('current_branch_id').eq('user_id', userId).maybeSingle();
  const { error: permissionsError } = await db.from('aqura_safe_box_permissions').select('id').limit(1);
  const canWatchPermissions = !permissionsError;
  if (permissionsError && !safeBoxSchemaUnavailable(permissionsError)) return json({ error: 'Could not watch receiver permissions.' }, { status: 500 });
  const encoder = new TextEncoder();
  let cleanup = () => {};
  const stream = new ReadableStream<Uint8Array>({
    start(controller) {
      let closed = false;
      const send = (event: string) => { if (!closed) controller.enqueue(encoder.encode(event)); };
      const channel = db.channel(`cashier-change-${userId}-${crypto.randomUUID()}`)
        .on('postgres_changes', { event: '*', schema: 'public', table: 'aqura_change_requests',
          filter: `requested_by_user_id=eq.${userId}` }, () => send('event: change\ndata: {}\n\n'));
      if (canWatchPermissions && employee?.current_branch_id) channel.on('postgres_changes', {
        event: '*', schema: 'public', table: 'aqura_safe_box_permissions',
        filter: `branch_id=eq.${employee.current_branch_id}`
      }, () => send('event: receivers\ndata: {}\n\n'));
      channel.subscribe(status => { if (status === 'SUBSCRIBED') send('event: ready\ndata: {}\n\n'); });
      const keepAlive = setInterval(() => send(': keepalive\n\n'), 25000);
      cleanup = () => {
        if (closed) return;
        closed = true; clearInterval(keepAlive);
        request.signal.removeEventListener('abort', cleanup);
        void db.removeChannel(channel);
        try { controller.close(); } catch { /* closed */ }
      };
      request.signal.addEventListener('abort', cleanup, { once: true });
    },
    cancel() { cleanup(); }
  });
  return new Response(stream, { headers: { 'Content-Type': 'text/event-stream',
    'Cache-Control': 'no-cache, no-transform', Connection: 'keep-alive' } });
};
