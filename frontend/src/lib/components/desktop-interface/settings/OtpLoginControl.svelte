<script lang="ts">
	import { onMount } from 'svelte';
	type InterfaceType = 'cashier' | 'mobile' | 'desktop';
	type Mode = 'disabled' | 'email' | 'whatsapp' | 'both';
	const interfaces: Array<{ id: InterfaceType; name: string; icon: string; description: string }> = [
		{ id: 'cashier', name: 'Cashier Interface', icon: '🧾', description: 'POS and cashier workspace login' },
		{ id: 'mobile', name: 'Mobile Interface', icon: '📱', description: 'Employee mobile application login' },
		{ id: 'desktop', name: 'Desktop Interface', icon: '🖥️', description: 'Management desktop workspace login' }
	];
	const options: Array<{ value: Mode; label: string }> = [
		{ value: 'disabled', label: 'OTP disabled — access code only' },
		{ value: 'email', label: 'Email OTP only' },
		{ value: 'whatsapp', label: 'WhatsApp OTP only' },
		{ value: 'both', label: 'Email + WhatsApp OTP' }
	];
	let modes: Record<InterfaceType, Mode> = { cashier: 'both', mobile: 'both', desktop: 'both' };
	let loading = true;
	let saving: InterfaceType | null = null;
	let message = '';
	let error = '';

	onMount(load);
	async function load() {
		loading = true; error = '';
		try {
			const response = await fetch('/api/otp-login-control');
			const result = await response.json();
			if (!response.ok || !result.success) throw new Error(result.error || 'Could not load settings');
			for (const row of result.settings) modes[row.interface_type as InterfaceType] = row.delivery_mode as Mode;
			modes = { ...modes };
		} catch (cause) { error = cause instanceof Error ? cause.message : 'Could not load settings'; }
		finally { loading = false; }
	}

	async function save(interfaceType: InterfaceType, deliveryMode: Mode) {
		saving = interfaceType; error = ''; message = '';
		try {
			const response = await fetch('/api/otp-login-control', { method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ interfaceType, deliveryMode }) });
			const result = await response.json();
			if (!response.ok || !result.success) throw new Error(result.error || 'Could not save setting');
			message = `${interfaces.find(item => item.id === interfaceType)?.name} updated successfully.`;
			setTimeout(() => message = '', 3000);
		} catch (cause) { error = cause instanceof Error ? cause.message : 'Could not save setting'; await load(); }
		finally { saving = null; }
	}
</script>

<div class="control-page">
	<header><div><span class="eyebrow">SECURITY CONTROL</span><h1>OTP Login Control</h1><p>Configure two-step login independently for each employee interface.</p></div><div class="policy">6 digits · 2 minutes · 3 attempts</div></header>
	{#if error}<div class="alert error">{error}</div>{/if}
	{#if message}<div class="alert success">{message}</div>{/if}
	{#if loading}<div class="loading">Loading OTP settings…</div>{:else}
		<div class="cards">
			{#each interfaces as item}
				<section>
					<div class="icon">{item.icon}</div><div class="copy"><h2>{item.name}</h2><p>{item.description}</p></div>
					<select value={modes[item.id]} disabled={saving === item.id} on:change={(event) => { const mode = (event.currentTarget as HTMLSelectElement).value as Mode; modes[item.id] = mode; modes = { ...modes }; save(item.id, mode); }}>
						{#each options as option}<option value={option.value}>{option.label}</option>{/each}
					</select>
					<div class="status" class:enabled={modes[item.id] !== 'disabled'}>{saving === item.id ? 'Saving…' : modes[item.id] === 'disabled' ? 'Direct access-code login' : 'Two-step login enabled'}</div>
				</section>
			{/each}
		</div>
	{/if}
	<div class="note"><strong>Security behavior</strong><span>The same OTP is sent through all enabled available channels. Three incorrect OTP entries deactivate the entire user account and terminate active interface sessions. Administrators reactivate users from User Management.</span></div>
</div>

<style>
	.control-page{height:100%;overflow:auto;padding:28px;background:#f8fafc;color:#0f172a}header{display:flex;justify-content:space-between;gap:20px;align-items:flex-start;margin-bottom:24px}h1{margin:3px 0;font-size:1.8rem}header p,.copy p{margin:0;color:#64748b}.eyebrow{font-size:.72rem;font-weight:900;letter-spacing:.14em;color:#0891b2}.policy{padding:10px 14px;border-radius:12px;background:#cffafe;color:#155e75;font-weight:800}.cards{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:18px}.cards section{background:white;border:1px solid #e2e8f0;border-radius:18px;padding:20px;box-shadow:0 8px 24px rgba(15,23,42,.06)}.icon{font-size:2rem}.copy{margin:12px 0 18px}.copy h2{margin:0 0 4px;font-size:1.05rem}select{width:100%;padding:11px;border:1px solid #cbd5e1;border-radius:10px;background:white;color:#0f172a;font-weight:700}.status{margin-top:12px;padding:8px;border-radius:8px;background:#f1f5f9;color:#64748b;text-align:center;font-size:.8rem;font-weight:800}.status.enabled{background:#dcfce7;color:#166534}.note{display:flex;flex-direction:column;gap:6px;margin-top:20px;padding:18px;border:1px solid #bae6fd;border-radius:14px;background:#f0f9ff;color:#0c4a6e}.alert,.loading{padding:12px 14px;border-radius:10px;margin-bottom:16px}.error{background:#fee2e2;color:#991b1b}.success{background:#dcfce7;color:#166534}.loading{background:white;color:#64748b}@media(max-width:900px){.cards{grid-template-columns:1fr}header{flex-direction:column}.control-page{padding:18px}}
</style>
