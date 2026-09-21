import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { databaseClient } from '$lib/server/breakRegisterAuth';
import { safeBoxAccess } from '$lib/server/safeBoxControl';

export const GET: RequestHandler = async ({ cookies, request }) => {
  let access;
  try { access = await safeBoxAccess(cookies); }
  catch { return json({ error: 'Safe Box session required' }, { status: 401 }); }

  const db = databaseClient();
  const encoder = new TextEncoder();
  let cleanup = () => {};
  const stream = new ReadableStream<Uint8Array>({
    start(controller) {
      let closed = false;
      const send = (line: string) => { if (!closed) controller.enqueue(encoder.encode(line)); };
      const channel = db.channel(`safe-box-requests-${access.userId}-${crypto.randomUUID()}`)
        .on('postgres_changes', {
          event: '*', schema: 'public', table: 'aqura_change_requests',
          filter: `requested_to_user_id=eq.${access.userId}`
        }, payload => {
          if ((payload.new as { requested_to_user_id?: string })?.requested_to_user_id === access.userId ||
              (payload.old as { requested_to_user_id?: string })?.requested_to_user_id === access.userId) {
            send('event: change\ndata: {}\n\n');
          }
        });
      if (access.canBalance) channel.on('postgres_changes', {
        event: '*', schema: 'public', table: 'denomination_records',
        filter: `branch_id=eq.${access.branchId}`
      }, () => send('event: balance\ndata: {}\n\n'));
      if (access.controlReady) channel.on('postgres_changes', { event: '*', schema: 'public', table: 'aqura_safe_box_permissions',
        filter: `user_id=eq.${access.userId}` }, () => send('event: permissions\ndata: {}\n\n'));
      channel.subscribe(status => {
          if (status === 'SUBSCRIBED') send('event: ready\ndata: {}\n\n');
        });
      const keepAlive = setInterval(() => send(': keepalive\n\n'), 25000);
      cleanup = () => {
        if (closed) return;
        closed = true;
        clearInterval(keepAlive);
        request.signal.removeEventListener('abort', cleanup);
        void db.removeChannel(channel);
        try { controller.close(); } catch { /* already closed */ }
      };
      request.signal.addEventListener('abort', cleanup, { once: true });
    },
    cancel() { cleanup(); }
  });
  return new Response(stream, {
    headers: { 'Content-Type': 'text/event-stream', 'Cache-Control': 'no-cache, no-transform', Connection: 'keep-alive' }
  });
};
