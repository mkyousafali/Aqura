<script lang="ts">
	import { createEventDispatcher, onDestroy, onMount } from 'svelte';

	export let destinations: string[] = [];
	export let expiresInSeconds = 120;
	export let resendAfterSeconds = 30;
	export let deliveriesRemaining = 0;
	export let loading = false;
	export let attemptsRemaining: number | undefined = undefined;

	const dispatch = createEventDispatcher();
	let digits = ['', '', '', '', '', ''];
	let expires = expiresInSeconds;
	let resend = resendAfterSeconds;
	let timer: ReturnType<typeof setInterval>;

	onMount(() => {
		timer = setInterval(() => {
			if (expires > 0) expires -= 1;
			if (resend > 0) resend -= 1;
		}, 1000);
		setTimeout(() => document.getElementById('employee-otp-0')?.focus(), 50);
	});
	onDestroy(() => clearInterval(timer));

	$: code = digits.join('');
	$: formattedTime = `${Math.floor(expires / 60)}:${String(expires % 60).padStart(2, '0')}`;

	function input(event: Event, index: number) {
		const element = event.target as HTMLInputElement;
		digits[index] = element.value.replace(/\D/g, '').slice(-1);
		element.value = digits[index];
		if (digits[index] && index < 5) document.getElementById(`employee-otp-${index + 1}`)?.focus();
		// Svelte updates the reactive `code` value after this event handler.
		// Build it directly here so the sixth input never submits the previous
		// five-digit value.
		const completedCode = digits.join('');
		if (completedCode.length === 6 && !loading) dispatch('verify', { otp: completedCode });
	}

	function keydown(event: KeyboardEvent, index: number) {
		if (event.key === 'Backspace' && !digits[index] && index > 0) {
			digits[index - 1] = '';
			document.getElementById(`employee-otp-${index - 1}`)?.focus();
		}
	}

	function paste(event: ClipboardEvent) {
		event.preventDefault();
		const pasted = (event.clipboardData?.getData('text') || '').replace(/\D/g, '').slice(0, 6);
		digits = Array.from({ length: 6 }, (_, index) => pasted[index] || '');
		if (pasted.length === 6 && !loading) setTimeout(() => dispatch('verify', { otp: pasted }), 50);
	}

	export function restart(nextExpires = 120, nextResend = 30) {
		digits = ['', '', '', '', '', ''];
		expires = nextExpires;
		resend = nextResend;
		setTimeout(() => document.getElementById('employee-otp-0')?.focus(), 50);
	}
</script>

<div class="otp-card">
	<div class="otp-icon">✉</div>
	<h2>Enter verification code</h2>
	<p class="delivery">A 6-digit code was sent to {destinations.join(' and ')}.</p>
	<div class="timer" class:expired={expires === 0}>{expires > 0 ? `Expires in ${formattedTime}` : 'Code expired'}</div>
	<div class="digits">
		{#each digits as digit, index}
			<input id="employee-otp-{index}" type="password" value={digit} maxlength="1" inputmode="numeric" autocomplete="one-time-code" disabled={loading || expires === 0} on:input={(event) => input(event, index)} on:keydown={(event) => keydown(event, index)} on:paste={paste} />
		{/each}
	</div>
	{#if attemptsRemaining !== undefined}<p class="warning">{attemptsRemaining} incorrect attempt{attemptsRemaining === 1 ? '' : 's'} remaining</p>{/if}
	<button class="verify" type="button" disabled={loading || expires === 0 || code.length !== 6} on:click={() => dispatch('verify', { otp: code })}>{loading ? 'Verifying…' : 'Verify and continue'}</button>
	<button class="resend" type="button" disabled={loading || resend > 0 || deliveriesRemaining <= 0} on:click={() => dispatch('resend')}>
		{resend > 0 ? `Resend available in ${resend}s` : deliveriesRemaining > 0 ? `Resend code (${deliveriesRemaining} remaining)` : 'No resends remaining'}
	</button>
	<button class="back" type="button" disabled={loading} on:click={() => dispatch('back')}>Use a different access code</button>
</div>

<style>
	.otp-card{display:flex;flex-direction:column;align-items:center;gap:12px;padding:10px 0;color:#0f172a;text-align:center}.otp-icon{display:grid;place-items:center;width:48px;height:48px;border-radius:50%;background:#dff9fb;color:#087f9b;font-size:24px;font-weight:900}.otp-card h2{margin:0;font-size:1.35rem}.delivery{margin:0;color:#64748b;font-size:.9rem}.timer{font-weight:800;color:#087f9b}.timer.expired,.warning{color:#dc2626}.digits{display:flex;gap:8px;direction:ltr;margin:4px 0}.digits input{width:42px;height:50px;border:2px solid #cbd5e1;border-radius:10px;text-align:center;font-size:1.35rem;font-weight:800;background:white;color:#0f172a}.digits input:focus{outline:none;border-color:#0891b2;box-shadow:0 0 0 3px rgba(8,145,178,.15)}button{width:100%;border:0;border-radius:10px;padding:11px 14px;font-weight:800;cursor:pointer}.verify{background:linear-gradient(115deg,#10dce5,#079fd0,#034c8c);color:white}.resend{background:#e2e8f0;color:#334155}.back{background:transparent;color:#64748b;text-decoration:underline}button:disabled{opacity:.55;cursor:not-allowed}.warning{margin:0;font-size:.82rem;font-weight:700}@media(max-width:420px){.digits{gap:5px}.digits input{width:38px;height:46px}}
</style>
