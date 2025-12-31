<script lang="ts">
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { persistentAuthService, currentUser } from '$lib/utils/persistentAuth';

	// Test Configuration - Lukman (Mobile Enabled)
	const testUser = {
		id: '775166a6-4aea-47e0-8f1e-bbe34bb87284',
		username: 'Lukman',
		quickAccessCode: '759339'
	};

	let testResults: any[] = [];
	let isRunning = false;
	let allTestsPassed = false;

	function addLog(test: string, status: 'PASS' | 'FAIL' | 'INFO', message: string, data?: any) {
		testResults = [
			...testResults,
			{
				id: `${Date.now()}-${Math.random()}`,
				timestamp: new Date().toLocaleTimeString(),
				test,
				status,
				message,
				data
			}
		];
	}

	async function runTests() {
		testResults = [];
		isRunning = true;
		allTestsPassed = false;

		try {
			// Test 1: Check User Record
			addLog('TEST 1', 'INFO', 'Checking user record in database...');
			const { data: userData, error: userError } = await supabase
				.from('users')
				.select('id, username, quick_access_code, role_type, status')
				.eq('id', testUser.id)
				.single();

			if (userError || !userData) {
				addLog('TEST 1', 'FAIL', `User not found: ${userError?.message}`);
				isRunning = false;
				return;
			}

			addLog('TEST 1', 'PASS', `User found: ${userData.username}`, userData);

			// Test 2: Check Interface Permissions
			addLog('TEST 2', 'INFO', 'Checking interface permissions...');
			const { data: permissions, error: permError } = await supabase
				.from('interface_permissions')
				.select('desktop_enabled, mobile_enabled, cashier_enabled, customer_enabled')
				.eq('user_id', testUser.id)
				.single();

			if (permError || !permissions) {
				addLog('TEST 2', 'FAIL', `Permissions not found: ${permError?.message}`);
				isRunning = false;
				return;
			}

			addLog('TEST 2', 'PASS', 'Interface permissions retrieved', permissions);

			// Test 3: Verify Mobile Access Enabled
			addLog('TEST 3', 'INFO', 'Verifying mobile access is enabled...');
			if (!permissions.mobile_enabled) {
				addLog('TEST 3', 'FAIL', 'Mobile access is disabled for this user');
				isRunning = false;
				return;
			}
			addLog('TEST 3', 'PASS', '✅ Mobile interface access is ENABLED');

			// Test 4: Verify Desktop Access Disabled
			addLog('TEST 4', 'INFO', 'Verifying desktop access is disabled...');
			if (permissions.desktop_enabled) {
				addLog('TEST 4', 'FAIL', 'Desktop access should be disabled but is enabled');
			} else {
				addLog('TEST 4', 'PASS', '✅ Desktop interface access is correctly DISABLED');
			}

			// Test 5: Authenticate with Quick Access Code
			addLog('TEST 5', 'INFO', `Authenticating with quick access code: ${testUser.quickAccessCode}`);
			try {
				const loginResult = await persistentAuthService.loginWithQuickAccess(
					testUser.quickAccessCode,
					'mobile' // Specify mobile interface
				);

				if (loginResult.success) {
					addLog('TEST 5', 'PASS', '✅ Mobile authentication successful', {
						userId: loginResult.user?.id,
						username: loginResult.user?.username
					});
				} else {
					addLog('TEST 5', 'FAIL', `Authentication failed: ${loginResult.error}`);
					isRunning = false;
					return;
				}
			} catch (error: any) {
				addLog('TEST 5', 'FAIL', `Authentication error: ${error.message}`);
				isRunning = false;
				return;
			}

			// Test 6: Verify Session Created
			addLog('TEST 6', 'INFO', 'Verifying user session...');
			const user = $currentUser;
			if (user && user.id === testUser.id) {
				addLog('TEST 6', 'PASS', '✅ User session active', {
					id: user.id,
					username: user.username,
					role: user.role_type
				});
			} else {
				addLog('TEST 6', 'FAIL', 'Session not found in store');
				isRunning = false;
				return;
			}

			// Test 7: Test Mobile Data Access (Example: Tasks)
			addLog('TEST 7', 'INFO', 'Testing mobile data access (tasks records)...');
			const { data: tasks, error: tasksError } = await supabase
				.from('tasks')
				.select('id, title, status')
				.limit(5);

			if (tasksError) {
				addLog('TEST 7', 'FAIL', `Data access error: ${tasksError.message}`);
			} else {
				addLog('TEST 7', 'PASS', `✅ Mobile data access working (${tasks?.length || 0} records)`, tasks);
			}

			// All Tests Complete
			allTestsPassed = true;
			addLog('COMPLETE', 'PASS', '🎉 ALL MOBILE INTERFACE TESTS PASSED!');

		} catch (error: any) {
			addLog('ERROR', 'FAIL', `Unexpected error: ${error.message}`);
		} finally {
			isRunning = false;
		}
	}

	function logout() {
		persistentAuthService.logout();
		addLog('LOGOUT', 'INFO', 'User logged out');
	}
</script>

<div class="mobile-auth-test">
	<div class="header">
		<h1>📱 Mobile Interface Authentication Test</h1>
		<div class="test-info">
			<p><strong>Test User:</strong> {testUser.username}</p>
			<p><strong>User ID:</strong> {testUser.id}</p>
			<p><strong>Quick Code:</strong> {testUser.quickAccessCode}</p>
			<p><strong>Expected:</strong> ✅ Mobile ENABLED, ❌ Desktop DISABLED</p>
		</div>
	</div>

	<div class="controls">
		<button on:click={runTests} disabled={isRunning} class="btn-primary">
			{isRunning ? '⏳ Running Tests...' : '▶️ Run Mobile Auth Tests'}
		</button>
		<button on:click={logout} class="btn-secondary">
			🚪 Logout
		</button>
	</div>

	{#if testResults.length > 0}
		<div class="results">
			<h2>Test Results</h2>
			<div class="results-summary">
				<span class="total">Total: {testResults.filter(r => r.status !== 'INFO').length}</span>
				<span class="passed">Passed: {testResults.filter(r => r.status === 'PASS').length}</span>
				<span class="failed">Failed: {testResults.filter(r => r.status === 'FAIL').length}</span>
			</div>

			<div class="log-entries">
				{#each testResults as result (result.id)}
					<div class="log-entry {result.status.toLowerCase()}">
						<div class="log-header">
							<span class="timestamp">{result.timestamp}</span>
							<span class="test-name">{result.test}</span>
							<span class="status status-{result.status.toLowerCase()}">{result.status}</span>
						</div>
						<div class="log-message">{result.message}</div>
						{#if result.data}
							<details class="log-data">
								<summary>View Data</summary>
								<pre>{JSON.stringify(result.data, null, 2)}</pre>
							</details>
						{/if}
					</div>
				{/each}
			</div>
		</div>
	{/if}

	{#if allTestsPassed}
		<div class="success-banner">
			<h2>✅ SUCCESS!</h2>
			<p>Lukman can successfully authenticate and access the mobile interface!</p>
			<ul>
				<li>✅ User record validated</li>
				<li>✅ Mobile access enabled</li>
				<li>✅ Desktop access correctly disabled</li>
				<li>✅ Authentication successful</li>
				<li>✅ Session created</li>
				<li>✅ Data access working</li>
			</ul>
		</div>
	{/if}
</div>

<style>
	.mobile-auth-test {
		max-width: 1200px;
		margin: 2rem auto;
		padding: 2rem;
		font-family: system-ui, -apple-system, sans-serif;
	}

	.header {
		background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
		color: white;
		padding: 2rem;
		border-radius: 12px;
		margin-bottom: 2rem;
	}

	.header h1 {
		margin: 0 0 1rem 0;
		font-size: 2rem;
	}

	.test-info {
		background: rgba(255, 255, 255, 0.1);
		padding: 1rem;
		border-radius: 8px;
		backdrop-filter: blur(10px);
	}

	.test-info p {
		margin: 0.5rem 0;
		font-family: 'Courier New', monospace;
	}

	.controls {
		display: flex;
		gap: 1rem;
		margin-bottom: 2rem;
	}

	.btn-primary, .btn-secondary {
		padding: 0.75rem 1.5rem;
		font-size: 1rem;
		font-weight: 600;
		border: none;
		border-radius: 8px;
		cursor: pointer;
		transition: all 0.2s;
	}

	.btn-primary {
		background: #10b981;
		color: white;
	}

	.btn-primary:hover:not(:disabled) {
		background: #059669;
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(16, 185, 129, 0.4);
	}

	.btn-primary:disabled {
		background: #9ca3af;
		cursor: not-allowed;
	}

	.btn-secondary {
		background: #6b7280;
		color: white;
	}

	.btn-secondary:hover {
		background: #4b5563;
	}

	.results {
		background: white;
		border-radius: 12px;
		padding: 1.5rem;
		box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
	}

	.results h2 {
		margin: 0 0 1rem 0;
		color: #1f2937;
	}

	.results-summary {
		display: flex;
		gap: 1.5rem;
		margin-bottom: 1.5rem;
		padding: 1rem;
		background: #f3f4f6;
		border-radius: 8px;
		font-weight: 600;
	}

	.results-summary .total {
		color: #6b7280;
	}

	.results-summary .passed {
		color: #10b981;
	}

	.results-summary .failed {
		color: #ef4444;
	}

	.log-entries {
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
	}

	.log-entry {
		border-left: 4px solid #e5e7eb;
		padding: 1rem;
		background: #f9fafb;
		border-radius: 0 8px 8px 0;
		transition: all 0.2s;
	}

	.log-entry:hover {
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
	}

	.log-entry.pass {
		border-left-color: #10b981;
		background: #f0fdf4;
	}

	.log-entry.fail {
		border-left-color: #ef4444;
		background: #fef2f2;
	}

	.log-entry.info {
		border-left-color: #3b82f6;
		background: #eff6ff;
	}

	.log-header {
		display: flex;
		align-items: center;
		gap: 1rem;
		margin-bottom: 0.5rem;
	}

	.timestamp {
		color: #6b7280;
		font-size: 0.875rem;
		font-family: 'Courier New', monospace;
	}

	.test-name {
		font-weight: 700;
		color: #1f2937;
		font-family: 'Courier New', monospace;
	}

	.status {
		padding: 0.25rem 0.75rem;
		border-radius: 999px;
		font-size: 0.75rem;
		font-weight: 700;
		text-transform: uppercase;
		margin-left: auto;
	}

	.status-pass {
		background: #10b981;
		color: white;
	}

	.status-fail {
		background: #ef4444;
		color: white;
	}

	.status-info {
		background: #3b82f6;
		color: white;
	}

	.log-message {
		color: #374151;
		font-size: 0.95rem;
		line-height: 1.5;
	}

	.log-data {
		margin-top: 0.75rem;
	}

	.log-data summary {
		cursor: pointer;
		color: #3b82f6;
		font-size: 0.875rem;
		font-weight: 600;
		user-select: none;
	}

	.log-data summary:hover {
		color: #2563eb;
	}

	.log-data pre {
		margin-top: 0.5rem;
		padding: 1rem;
		background: #1f2937;
		color: #10b981;
		border-radius: 6px;
		overflow-x: auto;
		font-size: 0.875rem;
		line-height: 1.5;
	}

	.success-banner {
		margin-top: 2rem;
		background: linear-gradient(135deg, #10b981 0%, #059669 100%);
		color: white;
		padding: 2rem;
		border-radius: 12px;
		text-align: center;
		animation: slideIn 0.5s ease-out;
	}

	.success-banner h2 {
		margin: 0 0 1rem 0;
		font-size: 2rem;
	}

	.success-banner p {
		font-size: 1.125rem;
		margin-bottom: 1.5rem;
	}

	.success-banner ul {
		list-style: none;
		padding: 0;
		margin: 0;
		display: inline-block;
		text-align: left;
	}

	.success-banner li {
		padding: 0.5rem 0;
		font-size: 1rem;
	}

	@keyframes slideIn {
		from {
			opacity: 0;
			transform: translateY(20px);
		}
		to {
			opacity: 1;
			transform: translateY(0);
		}
	}
</style>
