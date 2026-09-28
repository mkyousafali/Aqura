import WebSocket from "ws";

// @supabase/realtime-js requires a WebSocket constructor during SSR on Node 20.
if (!globalThis.WebSocket) {
  globalThis.WebSocket = WebSocket;
}
