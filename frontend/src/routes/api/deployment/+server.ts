import { json } from '@sveltejs/kit';
import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);

// Store for deployment status
const deploymentStatus: {
	[key: string]: { log: string[]; complete: boolean; error: string | null; progress: number }
} = {};

export async function POST({ request }) {
	try {
		// Parse request body to get user data
		const body = await request.json();
		const user = body.user;
		
		if (!user) {
			return json(
				{ error: 'Unauthorized - no user provided' },
				{ status: 401 }
			);
		}

		// Check if it's a master admin
		const isMasterAdmin = user?.isMasterAdmin === true;
		if (!isMasterAdmin) {
			return json(
				{ error: 'Only master admins can trigger deployments' },
				{ status: 403 }
			);
		}
	} catch (parseError) {
		return json(
			{ error: 'Invalid request body' },
			{ status: 400 }
		);
	}

	try {
		const sessionId = `deploy-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
		
		// Initialize deployment status
		deploymentStatus[sessionId] = {
			log: [],
			complete: false,
			error: null,
			progress: 0
		};

		// Start async deployment
		triggerDeployment(sessionId).catch(err => {
			deploymentStatus[sessionId].error = err.message;
			deploymentStatus[sessionId].complete = true;
		});

		return json(
			{
				message: 'Deployment started',
				sessionId,
				stream: true
			},
			{ status: 202 }
		);
	} catch (error) {
		console.error('Deployment init error:', error);
		return json(
			{ error: error instanceof Error ? error.message : 'Failed to start deployment' },
			{ status: 500 }
		);
	}
}

// GET endpoint for SSE status updates
export async function GET({ url }) {
	const sessionId = url.searchParams.get('sessionId') as string;

	if (!sessionId || !deploymentStatus[sessionId]) {
		return new Response('Session not found', { status: 404 });
	}

	const encoder = new TextEncoder();
	let lastLogCount = 0;
	let pollCount = 0;

	return new Response(
		new ReadableStream({
			start(controller) {
				const sendUpdates = () => {
					try {
						const status = deploymentStatus[sessionId];
						if (!status) return;

						// Send only new log lines since last send
						const newLines = status.log.slice(lastLogCount);
						newLines.forEach((line) => {
							controller.enqueue(encoder.encode(`data: ${line}\n\n`));
						});
						lastLogCount = status.log.length;
						pollCount++;

						// Safety limit: close after 120 polls (60 seconds)
						if (pollCount > 120 || status.complete) {
							if (status.error) {
								controller.enqueue(
									encoder.encode(`data: [ERROR] ${status.error}\n\n`)
								);
							}
							controller.enqueue(encoder.encode(`data: [COMPLETE]\n\n`));
							controller.close();
						} else {
							// Poll every 500ms
							setTimeout(sendUpdates, 500);
						}
					} catch (error) {
						// Stream might be closed, silently fail
						console.error('SSE error:', error);
					}
				};

				sendUpdates();
			}
		}),
		{
			headers: {
				'Content-Type': 'text/event-stream',
				'Cache-Control': 'no-cache',
				'Connection': 'keep-alive'
			}
		}
	);
}

async function triggerDeployment(sessionId: string) {
	const status = deploymentStatus[sessionId];

	try {
		status.log.push('[INIT] Deploying to local branch server...');
		status.log.push('[INIT] Connecting to Windows PC at 192.168.0.163...');

		// SSH command using key-based authentication from branch server
		// This executes the database sync script on Windows PC
		// Only syncs database from cloud → branch, resets sequences, and verifies HTTP 200
		const sshCommand = `ssh -i ~/.ssh/id_ed25519_nopass -o StrictHostKeyChecking=no me@192.168.0.163 powershell -NoProfile -Command 'cd D:\\Aqura; .\\scripts\\sync-database-only.ps1' 2>&1`;

		status.log.push('[1/4] Creating database dump on cloud server...');
		status.progress = 20;

		const { stdout, stderr } = await execAsync(sshCommand, {
			maxBuffer: 20 * 1024 * 1024, // 20MB
			timeout: 600000 // 10 minutes
		});

		// Parse output and add to log
		const output = stdout || stderr || '';
		const lines = output.split('\n');

		status.log.push('[2/4] Downloading dump to PC and uploading to branch...');
		status.progress = 40;

		lines.forEach(line => {
			if (line.trim()) {
				status.log.push(line);

				// Update progress based on content
				if (line.includes('Downloaded:')) status.progress = 50;
				else if (line.includes('Restored')) status.progress = 70;
				else if (line.includes('Sequences reset')) status.progress = 85;
				else if (line.includes('HTTP 200') || line.includes('verified')) status.progress = 100;
			}
		});

		if (output.includes('DATABASE SYNC COMPLETE') || output.includes('HTTP 200')) {
			status.log.push('[3/4] Sequences reset successfully');
			status.log.push('[4/4] Frontend verified');
			status.log.push('[SUCCESS] Database sync completed successfully!');
			status.log.push('[COMPLETE]');
		} else {
			throw new Error('Database sync script did not complete successfully');
		}

		status.complete = true;
		status.error = null;
	} catch (error) {
		const errorMsg = error instanceof Error ? error.message : 'Unknown error';
		status.log.push(`[ERROR] ${errorMsg}`);
		status.log.push('[FAILED] Deployment failed');
		status.complete = true;
		status.error = errorMsg;
		throw error;
	}
}
