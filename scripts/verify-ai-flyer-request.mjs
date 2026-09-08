// Read-only local dry run: real offer data stays local; OpenAI calls are replaced with fixtures.
import { config } from 'dotenv';
import { createServer } from 'vite';
config({ path: 'frontend/.env', quiet: true });
const offerId = process.argv[2];
if (!offerId) throw new Error('Supply an offer UUID.');
process.chdir('frontend');
const server = await createServer({ server: { middlewareMode: true, hmr: false }, logLevel: 'error' });
try {
  const { POST } = await server.ssrLoadModule('/src/routes/api/ai-flyers/design/+server.ts');
  let shared;
  for (const pageNumber of [1, 2]) {
    const body = { offerId, offerName: 'Week 2', pageNumber, ...(shared ? { design: shared.design, revision: shared.revision } : {}) };
    const localAi = async (url) => {
      if (new URL(url).hostname !== 'api.openai.com') throw new Error('Unexpected outbound request');
      const result = shared ? { columns: 3 } : { columns: 3, primary: '#174c2c', paper: '#fff8e8', accent: '#cf201b', motif: 'botanical', shadowDepth: 5, shadowBlur: 12, shadowOpacity: .18, bevelOpacity: .3 };
      return Response.json({ choices: [{ message: { content: JSON.stringify(result) } }] });
    };
    const response = await POST({ request: new Request('http://localhost/api/ai-flyers/design', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) }), url: new URL('http://localhost/api/ai-flyers/design'), fetch: localAi });
    const data = await response.json();
    console.log(JSON.stringify({ status: response.status, page: pageNumber, pageCount: data.pageCount, cards: data.page?.slots?.length, requestBytes: data.requestBytes, styleConsistent: shared ? JSON.stringify(shared.design) === JSON.stringify(data.design) : undefined, error: data.error }));
    if (!response.ok) { process.exitCode = 1; break; }
    shared = data;
  }
} finally { await server.close(); }
