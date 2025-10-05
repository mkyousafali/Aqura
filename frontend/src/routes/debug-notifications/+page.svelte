<script lang="ts">
	import { onMount } from 'svelte';
	import { pushNotificationProcessor } from '$lib/utils/pushNotificationProcessor';

	let status = 'Starting tests...';
	let logs: string[] = [];

	function addLog(message: string) {
		logs = [...logs, `[${new Date().toLocaleTimeString()}] ${message}`];
		status = message;
		console.log(message);
	}

	async function testNotificationPermission() {
		addLog('🔍 Checking notification permission...');
		addLog(`Permission status: ${Notification.permission}`);
		
		if (Notification.permission !== 'granted') {
			addLog('📝 Requesting notification permission...');
			const permission = await Notification.requestPermission();
			addLog(`Permission result: ${permission}`);
			return permission === 'granted';
		}
		return true;
	}

	async function testBasicNotification() {
		addLog('🔔 Testing basic browser notification...');
		
		const hasPermission = await testNotificationPermission();
		if (!hasPermission) {
			addLog('❌ Cannot test notifications without permission');
			return;
		}

		try {
			const notification = new Notification('Test Notification', {
				body: 'This is a test notification from the debug page',
				icon: '/favicon.png'
			});
			
			notification.onclick = () => {
				addLog('🖱️ Notification clicked!');
				notification.close();
			};
			
			setTimeout(() => notification.close(), 5000);
			addLog('✅ Basic notification created successfully');
		} catch (error) {
			addLog(`❌ Basic notification failed: ${error}`);
		}
	}

	async function testServiceWorkerNotification() {
		addLog('🔔 Testing service worker notification...');
		
		if (!('serviceWorker' in navigator)) {
			addLog('❌ Service Worker not supported');
			return;
		}

		try {
			const registration = await navigator.serviceWorker.ready;
			addLog('✅ Service Worker ready');
			
			await registration.showNotification('Service Worker Test', {
				body: 'This is a service worker notification test',
				icon: '/favicon.png',
				requireInteraction: true
			});
			
			addLog('✅ Service worker notification created');
		} catch (error) {
			addLog(`❌ Service worker notification failed: ${error}`);
		}
	}

	async function testDatabaseFunction() {
		addLog('🧪 Testing database queue function...');
		
		// Use the notification ID from your SQL test
		const notificationId = 'ed175735-ec26-4d1c-9efd-ca32fc5d00e8';
		
		try {
			// Call the function through the window global
			if (typeof window !== 'undefined' && (window as any).testExistingNotification) {
				addLog('🔍 Calling database function...');
				await (window as any).testExistingNotification();
				addLog('✅ Database function call completed');
			} else {
				addLog('❌ Database function test not available');
			}
		} catch (error) {
			addLog(`❌ Database function test failed: ${error}`);
		}
	}

	async function testQueueProcessing() {
		addLog('🔄 Testing queue processing...');
		
		try {
			if (typeof window !== 'undefined' && (window as any).processPushNotificationQueue) {
				await (window as any).processPushNotificationQueue();
				addLog('✅ Queue processing completed');
			} else {
				addLog('❌ Queue processing function not available');
			}
		} catch (error) {
			addLog(`❌ Queue processing failed: ${error}`);
		}
	}

	async function runAllTests() {
		logs = [];
		addLog('🚀 Starting comprehensive notification tests...');
		
		await testNotificationPermission();
		await new Promise(resolve => setTimeout(resolve, 1000));
		
		await testBasicNotification();
		await new Promise(resolve => setTimeout(resolve, 2000));
		
		await testServiceWorkerNotification();
		await new Promise(resolve => setTimeout(resolve, 2000));
		
		await testDatabaseFunction();
		await new Promise(resolve => setTimeout(resolve, 2000));
		
		await testQueueProcessing();
		
		addLog('🏁 All tests completed');
	}

	onMount(async () => {
		addLog('📱 Debug page loaded');
		addLog(`Notification API supported: ${'Notification' in window}`);
		addLog(`Service Worker supported: ${'serviceWorker' in navigator}`);
		addLog(`Current permission: ${Notification.permission}`);
	});
</script>

<div class="p-6 max-w-4xl mx-auto">
	<h1 class="text-2xl font-bold mb-6">🔧 Push Notification Debug Tool</h1>
	
	<div class="mb-6">
		<p class="text-lg mb-4">Status: <span class="font-mono">{status}</span></p>
		
		<div class="flex flex-wrap gap-2 mb-4">
			<button 
				on:click={testNotificationPermission}
				class="bg-blue-500 text-white px-4 py-2 rounded hover:bg-blue-600"
			>
				Test Permission
			</button>
			
			<button 
				on:click={testBasicNotification}
				class="bg-green-500 text-white px-4 py-2 rounded hover:bg-green-600"
			>
				Test Basic Notification
			</button>
			
			<button 
				on:click={testServiceWorkerNotification}
				class="bg-purple-500 text-white px-4 py-2 rounded hover:bg-purple-600"
			>
				Test Service Worker
			</button>
			
			<button 
				on:click={testDatabaseFunction}
				class="bg-orange-500 text-white px-4 py-2 rounded hover:bg-orange-600"
			>
				Test Database Function
			</button>
			
			<button 
				on:click={testQueueProcessing}
				class="bg-red-500 text-white px-4 py-2 rounded hover:bg-red-600"
			>
				Test Queue Processing
			</button>
			
			<button 
				on:click={runAllTests}
				class="bg-gray-800 text-white px-6 py-2 rounded hover:bg-gray-900"
			>
				🚀 Run All Tests
			</button>
		</div>
	</div>
	
	<div class="bg-gray-100 p-4 rounded-lg">
		<h2 class="font-bold mb-2">📋 Test Logs:</h2>
		<div class="font-mono text-sm space-y-1 max-h-96 overflow-y-auto">
			{#each logs as log}
				<div class="text-gray-800">{log}</div>
			{/each}
		</div>
	</div>
	
	<div class="mt-6 p-4 bg-blue-50 rounded-lg">
		<h2 class="font-bold mb-2">💡 Quick Browser Console Commands:</h2>
		<div class="font-mono text-sm space-y-1">
			<div><code>testBasicNotification()</code> - Test direct browser notification</div>
			<div><code>testExistingNotification()</code> - Test database function with real notification</div>
			<div><code>processPushNotificationQueue()</code> - Manually process the queue</div>
			<div><code>manualQueueTest()</code> - Add a test entry to the queue</div>
		</div>
	</div>
</div>