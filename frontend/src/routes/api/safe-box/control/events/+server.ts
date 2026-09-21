import type { RequestHandler } from './$types';
import { databaseClient, requireBreakUser } from '$lib/server/breakRegisterAuth';

export const GET: RequestHandler = async ({ cookies, request }) => {
  let actor;
  try { actor = await requireBreakUser(cookies, 'desktop'); }
  catch { return new Response('Login required', { status: 401 }); }
  if (!actor.isMasterAdmin) return new Response('Master Admin required', { status: 403 });
  const db = databaseClient();
  const encoder = new TextEncoder();
  let cleanup = () => {};
  const stream = new ReadableStream<Uint8Array>({
    start(controller) {
      let closed = false;
      const send = (value: string) => { if (!closed) controller.enqueue(encoder.encode(value)); };
      const channel = db.channel(`safe-box-control-${crypto.randomUUID()}`)
        .on('postgres_changes', { event: '*', schema: 'public', table: 'aqura_safe_box_permissions' }, () => send('event: change\ndata: {}\n\n'))
        .subscribe(status => { if (status === 'SUBSCRIBED') send('event: ready\ndata: {}\n\n'); });
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
  return new Response(stream, { headers: { 'Content-Type': 'text/event-stream', 'Cache-Control': 'no-cache, no-transform' } });
};
