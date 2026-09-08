<script lang="ts">
	import { _ as t } from '$lib/i18n';

	let currentStep = 0;
	const totalSteps = 10;

	// Local-only checklist state (not persisted)
	let checks: Record<string, boolean> = {};

	function next() { if (currentStep < totalSteps - 1) currentStep++; }
	function prev() { if (currentStep > 0) currentStep--; }
	function restart() { currentStep = 0; checks = {}; }
	function goTo(step: number) { currentStep = step; }

	function openExternal(url: string) { window.open(url, '_blank', 'noopener,noreferrer'); }

	// Open Email Accounts window via custom event
	function openEmailAccounts() {
		window.dispatchEvent(new CustomEvent('aqura-open-window', { detail: { type: 'email-accounts' } }));
	}
	function openEmailCentre() {
		window.dispatchEvent(new CustomEvent('aqura-open-window', { detail: { type: 'email-centre' } }));
	}

	const steps = [
		{ title: 'Domain', icon: '🌐' },
		{ title: 'Cloudflare', icon: '☁️' },
		{ title: 'Private Email', icon: '📧' },
		{ title: 'Mailbox', icon: '📬' },
		{ title: 'DNS Records', icon: '🔧' },
		{ title: 'Webmail Test', icon: '✅' },
		{ title: 'Aqura Account', icon: '⚙️' },
		{ title: 'SMTP Test', icon: '📡' },
		{ title: 'IMAP Test', icon: '📥' },
		{ title: 'Complete', icon: '🎉' },
	];

	$: progress = ((currentStep + 1) / totalSteps) * 100;
</script>

<div class="setup-guide">
	<!-- Progress Bar -->
	<div class="progress-section">
		<div class="progress-bar"><div class="progress-fill" style="width:{progress}%"></div></div>
		<div class="progress-label">Step {currentStep + 1} of {totalSteps} — {steps[currentStep].title}</div>
	</div>

	<!-- Step Navigation Pills -->
	<div class="step-pills">
		{#each steps as step, i}
			<button class="pill" class:active={i === currentStep} class:completed={i < currentStep} on:click={() => goTo(i)} title={step.title}>
				<span class="pill-icon">{step.icon}</span>
				<span class="pill-text">{step.title}</span>
			</button>
		{/each}
	</div>

	<!-- Step Content -->
	<div class="step-content">

		<!-- Step 1: Domain -->
		{#if currentStep === 0}
			<div class="card">
				<h3>🌐 Step 1 — Purchase or Use a Domain</h3>
				<p>You need a domain name for your business email (e.g. <code>yourcompany.com</code>).</p>
				<ol>
					<li>Open <strong>Namecheap</strong>.</li>
					<li>Search for a suitable domain name.</li>
					<li>Purchase the domain — or select an existing domain you already own.</li>
					<li>Open the domain management page to verify ownership.</li>
				</ol>
				<div class="example-box">
					<strong>Example:</strong> <code>yourcompany.com</code>
				</div>
				<div class="action-bar">
					<button class="glass-btn external" on:click={() => openExternal('https://www.namecheap.com/domains/')}>🔗 Open Namecheap</button>
				</div>
			</div>

		<!-- Step 2: Cloudflare -->
		{:else if currentStep === 1}
			<div class="card">
				<h3>☁️ Step 2 — Add the Domain to Cloudflare</h3>
				<p>Cloudflare will manage your domain's DNS, which is required for email delivery.</p>
				<ol>
					<li>Sign in to <strong>Cloudflare</strong>.</li>
					<li>Click <strong>Add a Domain</strong>.</li>
					<li>Enter your purchased domain.</li>
					<li>Select the required Cloudflare plan (Free works fine).</li>
					<li>Allow Cloudflare to scan existing DNS records.</li>
					<li>Copy the <strong>two nameservers</strong> provided by Cloudflare.</li>
					<li>Return to <strong>Namecheap</strong> → Domain List → Manage.</li>
					<li>Under <strong>Nameservers</strong>, select <strong>Custom DNS</strong>.</li>
					<li>Paste the two Cloudflare nameservers and save.</li>
					<li>Wait until Cloudflare shows the domain as <strong>Active</strong> (can take up to 24 hours).</li>
				</ol>
				<div class="action-bar">
					<button class="glass-btn external" on:click={() => openExternal('https://dash.cloudflare.com/')}>🔗 Open Cloudflare</button>
					<button class="glass-btn external" on:click={() => openExternal('https://www.namecheap.com/myaccount/domain-list/')}>🔗 Open Namecheap Domains</button>
				</div>
			</div>

		<!-- Step 3: Private Email -->
		{:else if currentStep === 2}
			<div class="card">
				<h3>📧 Step 3 — Purchase Namecheap Private Email</h3>
				<p>Namecheap Private Email provides professional SMTP and IMAP email hosting.</p>
				<ol>
					<li>Open <strong>Namecheap Private Email</strong>.</li>
					<li>Select a suitable plan for your needs.</li>
					<li>Assign the email subscription to your domain.</li>
					<li>Complete the purchase or activate the free trial.</li>
					<li>Open the Private Email management page.</li>
				</ol>
				<div class="action-bar">
					<button class="glass-btn external" on:click={() => openExternal('https://www.namecheap.com/hosting/email/')}>🔗 Open Namecheap Private Email</button>
				</div>
			</div>

		<!-- Step 4: Mailbox -->
		{:else if currentStep === 3}
			<div class="card">
				<h3>📬 Step 4 — Create the Mailbox</h3>
				<p>Create one or more email addresses on your domain.</p>
				<ol>
					<li>Open the Private Email subscription.</li>
					<li>Click <strong>Create Mailbox</strong>.</li>
					<li>Enter the mailbox name (e.g. <code>support</code>).</li>
					<li>Create a <strong>secure password</strong>.</li>
					<li>Save the mailbox.</li>
					<li>Open webmail and confirm that login works.</li>
				</ol>
				<div class="example-box">
					<strong>Common mailbox names:</strong><br>
					<code>support@yourcompany.com</code><br>
					<code>info@yourcompany.com</code><br>
					<code>accounts@yourcompany.com</code><br>
					<code>hr@yourcompany.com</code>
				</div>
				<div class="warning-box">
					⚠️ Never share the mailbox password or include it in screenshots.
				</div>
				<div class="action-bar">
					<button class="glass-btn external" on:click={() => openExternal('https://privateemail.com/')}>🔗 Open Webmail</button>
				</div>
			</div>

		<!-- Step 5: DNS Records -->
		{:else if currentStep === 4}
			<div class="card">
				<h3>🔧 Step 5 — Configure Cloudflare Email DNS</h3>
				<p>Add the required DNS records so email can be sent and received through your domain.</p>
				<p class="note">⚠️ If you have existing email-forwarding MX records in Cloudflare, remove them first.</p>

				<h4>MX Records</h4>
				<div class="dns-record">
					<div class="dns-row"><span class="dns-label">Type:</span> <code>MX</code></div>
					<div class="dns-row"><span class="dns-label">Name:</span> <code>@</code></div>
					<div class="dns-row"><span class="dns-label">Target:</span> <code>mx1.privateemail.com</code></div>
					<div class="dns-row"><span class="dns-label">Priority:</span> <code>10</code></div>
				</div>
				<div class="dns-record">
					<div class="dns-row"><span class="dns-label">Type:</span> <code>MX</code></div>
					<div class="dns-row"><span class="dns-label">Name:</span> <code>@</code></div>
					<div class="dns-row"><span class="dns-label">Target:</span> <code>mx2.privateemail.com</code></div>
					<div class="dns-row"><span class="dns-label">Priority:</span> <code>10</code></div>
				</div>

				<h4>SPF Record</h4>
				<div class="dns-record">
					<div class="dns-row"><span class="dns-label">Type:</span> <code>TXT</code></div>
					<div class="dns-row"><span class="dns-label">Name:</span> <code>@</code></div>
					<div class="dns-row"><span class="dns-label">Content:</span> <code>v=spf1 include:spf.privateemail.com ~all</code></div>
				</div>
				<div class="warning-box">⚠️ Do not create multiple separate SPF records for the same domain. Merge them into one.</div>

				<h4>DKIM Record</h4>
				<ol>
					<li>Open the Namecheap Private Email management page.</li>
					<li>Click <strong>Show DKIM</strong> or <strong>Generate DKIM</strong>.</li>
					<li>Copy the <strong>DKIM host</strong> (e.g. <code>default._domainkey</code>).</li>
					<li>Copy the complete <strong>DKIM value</strong>.</li>
					<li>Add it as a <strong>TXT record</strong> in Cloudflare.</li>
				</ol>
				<p class="note">Each domain gets a unique DKIM value. Do not copy someone else's DKIM.</p>

				<h4>DMARC Record <span class="badge-optional">Recommended</span></h4>
				<div class="dns-record">
					<div class="dns-row"><span class="dns-label">Type:</span> <code>TXT</code></div>
					<div class="dns-row"><span class="dns-label">Name:</span> <code>_dmarc</code></div>
					<div class="dns-row"><span class="dns-label">Content:</span> <code>v=DMARC1; p=none;</code></div>
				</div>
				<p class="note">This is a starting policy. Stricter policies (quarantine/reject) can be configured later once email delivery is confirmed.</p>

				<div class="action-bar">
					<button class="glass-btn external" on:click={() => openExternal('https://dash.cloudflare.com/')}>🔗 Open Cloudflare DNS</button>
				</div>
			</div>

		<!-- Step 6: Webmail Test -->
		{:else if currentStep === 5}
			<div class="card">
				<h3>✅ Step 6 — Test Through Webmail</h3>
				<p>Before configuring Aqura, verify that email works directly through the webmail interface.</p>

				<h4>Sending Test</h4>
				<ol>
					<li>Log in to <strong>Namecheap Private Email webmail</strong>.</li>
					<li>Send an email from your business mailbox to a <strong>personal email</strong> (e.g. Gmail).</li>
					<li>Check both the Inbox and Spam folders on the personal account.</li>
				</ol>

				<h4>Receiving Test</h4>
				<ol>
					<li>Reply from your personal email address.</li>
					<li>Confirm the reply appears inside the Namecheap webmail inbox.</li>
				</ol>

				<div class="checklist">
					<label><input type="checkbox" bind:checked={checks.webmail_sent} /> Test email sent from webmail</label>
					<label><input type="checkbox" bind:checked={checks.webmail_received_personal} /> Test email received in personal inbox</label>
					<label><input type="checkbox" bind:checked={checks.webmail_reply_sent} /> Reply sent from personal email</label>
					<label><input type="checkbox" bind:checked={checks.webmail_reply_received} /> Reply received in webmail inbox</label>
				</div>

				<div class="action-bar">
					<button class="glass-btn external" on:click={() => openExternal('https://privateemail.com/')}>🔗 Open Webmail</button>
				</div>
			</div>

		<!-- Step 7: Aqura Email Account -->
		{:else if currentStep === 6}
			<div class="card">
				<h3>⚙️ Step 7 — Create the Email Account in Aqura</h3>
				<p>Open <strong>Email Accounts</strong> in Aqura and create a new account with these settings:</p>

				<h4>General</h4>
				<div class="settings-table">
					<div class="setting-row"><span>Account Name</span><code>Aqura Support Email</code></div>
					<div class="setting-row"><span>Provider</span><code>Namecheap Private Email</code></div>
					<div class="setting-row"><span>Email Address</span><code>support@yourcompany.com</code></div>
					<div class="setting-row"><span>From Name</span><code>Company Support</code></div>
				</div>

				<h4>SMTP — Sending</h4>
				<div class="settings-table">
					<div class="setting-row"><span>SMTP Host</span><code>mail.privateemail.com</code></div>
					<div class="setting-row"><span>Port</span><code>465</code></div>
					<div class="setting-row"><span>Encryption</span><code>SSL (465)</code></div>
					<div class="setting-row"><span>Username</span><code>Full mailbox email address</code></div>
					<div class="setting-row"><span>Password</span><code>Mailbox password</code></div>
					<div class="setting-row"><span>Sending Enabled</span><code>Yes</code></div>
				</div>

				<h4>IMAP — Receiving</h4>
				<div class="settings-table">
					<div class="setting-row"><span>IMAP Host</span><code>mail.privateemail.com</code></div>
					<div class="setting-row"><span>Port</span><code>993</code></div>
					<div class="setting-row"><span>Encryption</span><code>SSL (993)</code></div>
					<div class="setting-row"><span>Username</span><code>Full mailbox email address</code></div>
					<div class="setting-row"><span>Password</span><code>Mailbox password</code></div>
					<div class="setting-row"><span>Sync Enabled</span><code>Yes</code></div>
				</div>

				<h4>Suggested Limits</h4>
				<div class="settings-table">
					<div class="setting-row"><span>Hourly Limit</span><code>20</code></div>
					<div class="setting-row"><span>Daily Limit</span><code>480</code></div>
					<div class="setting-row"><span>Max Recipients/Message</span><code>50</code></div>
					<div class="setting-row"><span>Critical Reserve/Hour</span><code>5</code></div>
					<div class="setting-row"><span>Batch Size</span><code>10</code></div>
					<div class="setting-row"><span>Min Delay</span><code>3 seconds</code></div>
				</div>
				<p class="note">These are recommended starting values for a Namecheap trial. Adjust according to your plan.</p>

				<h4>Default Purposes</h4>
				<div class="settings-table">
					<div class="setting-row"><span>Manual Email</span><code>✅ Enabled</code></div>
					<div class="setting-row"><span>Transactional</span><code>✅ Enabled</code></div>
					<div class="setting-row"><span>OTP</span><code>✅ Enabled</code></div>
					<div class="setting-row"><span>Incoming Sync</span><code>✅ Enabled</code></div>
					<div class="setting-row"><span>Broadcast</span><code>⬜ Disabled initially</code></div>
				</div>

				<div class="action-bar">
					<button class="glass-btn primary" on:click={openEmailAccounts}>📱 Open Email Accounts</button>
				</div>
			</div>

		<!-- Step 8: SMTP Test -->
		{:else if currentStep === 7}
			<div class="card">
				<h3>📡 Step 8 — Test SMTP</h3>
				<p>Verify that Aqura can send emails through your account.</p>
				<ol>
					<li>Save the Email Account in Aqura.</li>
					<li>Click <strong>Test SMTP</strong> (📡 button in Actions).</li>
					<li>Confirm that the status shows <strong>✅ success</strong>.</li>
					<li>Send a test email to a personal email address using <strong>Compose Email</strong>.</li>
					<li>Confirm that it arrives in your personal inbox.</li>
				</ol>

				<h4>Troubleshooting</h4>
				<div class="troubleshoot-list">
					<div class="troubleshoot-item">❌ Confirm the SMTP host is <code>mail.privateemail.com</code></div>
					<div class="troubleshoot-item">❌ Confirm port <code>465</code> is selected</div>
					<div class="troubleshoot-item">❌ Confirm encryption is <code>SSL (465)</code></div>
					<div class="troubleshoot-item">❌ Confirm the username is the <strong>complete email address</strong></div>
					<div class="troubleshoot-item">❌ Re-enter the mailbox password</div>
					<div class="troubleshoot-item">❌ Confirm <strong>Sending Enabled</strong> is checked</div>
				</div>

				<div class="action-bar">
					<button class="glass-btn primary" on:click={openEmailAccounts}>📱 Open Email Accounts</button>
				</div>
			</div>

		<!-- Step 9: IMAP Test -->
		{:else if currentStep === 8}
			<div class="card">
				<h3>📥 Step 9 — Test IMAP</h3>
				<p>Verify that Aqura can receive and sync emails.</p>
				<ol>
					<li>Click <strong>Test IMAP</strong> (📥 button in Actions).</li>
					<li>Confirm that authentication succeeds.</li>
					<li>Open <strong>Email Centre</strong> and click <strong>🔄 Sync</strong>.</li>
					<li>Send an email from a personal address to your business mailbox.</li>
					<li>Click <strong>🔄 Sync</strong> again.</li>
					<li>Confirm the email appears in the Aqura inbox.</li>
				</ol>

				<h4>Troubleshooting</h4>
				<div class="troubleshoot-list">
					<div class="troubleshoot-item">❌ Confirm the IMAP host is <code>mail.privateemail.com</code></div>
					<div class="troubleshoot-item">❌ Confirm port <code>993</code> is selected</div>
					<div class="troubleshoot-item">❌ Confirm encryption is <code>SSL (993)</code></div>
					<div class="troubleshoot-item">❌ Confirm the username is the <strong>complete email address</strong></div>
					<div class="troubleshoot-item">❌ Re-enter the mailbox password</div>
					<div class="troubleshoot-item">❌ Confirm <strong>Sync Enabled</strong> is checked</div>
				</div>

				<div class="action-bar">
					<button class="glass-btn primary" on:click={openEmailAccounts}>📱 Open Email Accounts</button>
					<button class="glass-btn" on:click={openEmailCentre}>📬 Open Email Centre</button>
				</div>
			</div>

		<!-- Step 10: Complete -->
		{:else if currentStep === 9}
			<div class="card completion-card">
				<h3>🎉 Email Account Setup Completed</h3>
				<p>Verify that all steps have been completed successfully:</p>

				<div class="final-checklist">
					<label><input type="checkbox" bind:checked={checks.domain} /> Domain purchased or selected</label>
					<label><input type="checkbox" bind:checked={checks.cloudflare} /> Domain added to Cloudflare</label>
					<label><input type="checkbox" bind:checked={checks.nameservers} /> Nameservers updated</label>
					<label><input type="checkbox" bind:checked={checks.private_email} /> Private Email purchased or activated</label>
					<label><input type="checkbox" bind:checked={checks.mailbox} /> Mailbox created</label>
					<label><input type="checkbox" bind:checked={checks.mx} /> MX records added</label>
					<label><input type="checkbox" bind:checked={checks.spf} /> SPF record added</label>
					<label><input type="checkbox" bind:checked={checks.dkim} /> DKIM record added</label>
					<label><input type="checkbox" bind:checked={checks.webmail_send} /> Webmail sending tested</label>
					<label><input type="checkbox" bind:checked={checks.webmail_receive} /> Webmail receiving tested</label>
					<label><input type="checkbox" bind:checked={checks.aqura_account} /> Email Account created in Aqura</label>
					<label><input type="checkbox" bind:checked={checks.smtp_pass} /> SMTP test passed</label>
					<label><input type="checkbox" bind:checked={checks.imap_pass} /> IMAP test passed</label>
					<label><input type="checkbox" bind:checked={checks.inbox_works} /> Incoming email appears in Email Centre</label>
				</div>

				<div class="action-bar">
					<button class="glass-btn" on:click={openEmailCentre}>📬 Open Email Centre</button>
					<button class="glass-btn" on:click={openEmailAccounts}>📱 Open Email Accounts</button>
					<button class="glass-btn" on:click={restart}>🔄 Restart Guide</button>
				</div>
			</div>
		{/if}
	</div>

	<!-- Navigation -->
	<div class="nav-bar">
		<button class="glass-btn" on:click={prev} disabled={currentStep === 0}>← Previous</button>
		<button class="glass-btn restart" on:click={restart}>🔄 Restart</button>
		<button class="glass-btn primary" on:click={next} disabled={currentStep === totalSteps - 1}>Next →</button>
	</div>
</div>

<style>
	.setup-guide { display: flex; flex-direction: column; height: 100%; background: #f8fafc; }

	/* Progress */
	.progress-section { padding: 14px 20px 8px; }
	.progress-bar { height: 6px; background: #e2e8f0; border-radius: 3px; overflow: hidden; }
	.progress-fill { height: 100%; background: linear-gradient(90deg, #f08300, #f59e0b); border-radius: 3px; transition: width 0.3s; }
	.progress-label { font-size: 12px; color: #64748b; margin-top: 4px; text-align: center; }

	/* Step Pills */
	.step-pills { display: flex; gap: 4px; padding: 4px 20px 10px; overflow-x: auto; }
	.pill { display: flex; align-items: center; gap: 3px; padding: 4px 8px; border: 1px solid #e2e8f0; border-radius: 6px; background: white; font-size: 10px; cursor: pointer; white-space: nowrap; color: #64748b; transition: all 0.15s; }
	.pill:hover { background: #f1f5f9; }
	.pill.active { background: #fff7ed; border-color: #f08300; color: #c2410c; font-weight: 600; }
	.pill.completed { background: #f0fdf4; border-color: #86efac; color: #166534; }
	.pill-icon { font-size: 12px; }
	.pill-text { font-size: 10px; }

	/* Content */
	.step-content { flex: 1; overflow-y: auto; padding: 0 20px 12px; }
	.card { background: white; border-radius: 12px; padding: 20px; border: 1px solid #e2e8f0; box-shadow: 0 1px 3px rgba(0,0,0,0.04); }
	.card h3 { font-size: 16px; font-weight: 600; color: #1e293b; margin-bottom: 12px; }
	.card h4 { font-size: 13px; font-weight: 600; color: #334155; margin: 16px 0 8px; border-bottom: 1px solid #f1f5f9; padding-bottom: 4px; }
	.card p { font-size: 13px; color: #475569; line-height: 1.6; margin-bottom: 8px; }
	.card ol, .card ul { font-size: 13px; color: #475569; line-height: 1.8; padding-left: 20px; margin-bottom: 10px; }
	.card li { margin-bottom: 2px; }
	.card code { background: #f1f5f9; padding: 1px 6px; border-radius: 4px; font-size: 12px; color: #0f172a; font-family: 'Consolas', monospace; }
	.note { font-size: 12px; color: #64748b; font-style: italic; }

	.example-box { background: #f0fdf4; border: 1px solid #bbf7d0; border-radius: 8px; padding: 10px 14px; font-size: 13px; margin: 10px 0; }
	.warning-box { background: #fef3c7; border: 1px solid #fde68a; border-radius: 8px; padding: 10px 14px; font-size: 12px; color: #92400e; margin: 10px 0; }

	/* DNS Records */
	.dns-record { background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 8px; padding: 10px 14px; margin: 8px 0; }
	.dns-row { font-size: 12px; color: #334155; margin: 2px 0; }
	.dns-label { font-weight: 600; display: inline-block; min-width: 60px; color: #64748b; }

	/* Settings Table */
	.settings-table { background: #f8fafc; border-radius: 8px; padding: 8px 12px; margin: 8px 0; border: 1px solid #e2e8f0; }
	.setting-row { display: flex; justify-content: space-between; align-items: center; padding: 4px 0; font-size: 12px; border-bottom: 1px solid #f1f5f9; }
	.setting-row:last-child { border-bottom: none; }
	.setting-row span { color: #475569; font-weight: 500; }

	/* Troubleshooting */
	.troubleshoot-list { display: flex; flex-direction: column; gap: 4px; margin: 8px 0; }
	.troubleshoot-item { font-size: 12px; color: #475569; padding: 4px 8px; background: #fef2f2; border-radius: 4px; }

	/* Checklist */
	.checklist, .final-checklist { display: flex; flex-direction: column; gap: 6px; margin: 12px 0; }
	.checklist label, .final-checklist label { display: flex; align-items: center; gap: 8px; font-size: 13px; color: #334155; cursor: pointer; padding: 4px 0; }
	.checklist input, .final-checklist input { width: 16px; height: 16px; accent-color: #f08300; }

	.badge-optional { font-size: 10px; background: #dbeafe; color: #1d4ed8; padding: 1px 6px; border-radius: 4px; font-weight: 400; }

	.completion-card { border-color: #86efac; background: #f0fdf4; }
	.completion-card h3 { color: #166534; }

	/* Action Bar */
	.action-bar { display: flex; gap: 8px; margin-top: 16px; flex-wrap: wrap; }

	/* Navigation */
	.nav-bar { display: flex; justify-content: space-between; padding: 10px 20px; border-top: 1px solid #e2e8f0; background: white; }

	/* Buttons */
	.glass-btn { padding: 8px 16px; border-radius: 8px; font-size: 13px; font-weight: 500; border: 1px solid rgba(255,255,255,0.3); cursor: pointer; background: rgba(255,255,255,0.7); backdrop-filter: blur(8px); box-shadow: 0 2px 8px rgba(0,0,0,0.06); transition: all 0.15s; color: #334155; }
	.glass-btn:hover { background: rgba(255,255,255,0.9); box-shadow: 0 4px 12px rgba(0,0,0,0.1); }
	.glass-btn:active { transform: scale(0.98); }
	.glass-btn:focus-visible { outline: 2px solid #f08300; outline-offset: 2px; }
	.glass-btn:disabled { opacity: 0.4; cursor: not-allowed; transform: none; }
	.glass-btn.primary { background: rgba(240,131,0,0.12); border-color: rgba(240,131,0,0.3); color: #c2410c; }
	.glass-btn.primary:hover { background: rgba(240,131,0,0.22); }
	.glass-btn.external { background: rgba(59,130,246,0.08); border-color: rgba(59,130,246,0.2); color: #1d4ed8; }
	.glass-btn.external:hover { background: rgba(59,130,246,0.15); }
	.glass-btn.restart { background: rgba(100,116,139,0.08); color: #64748b; border-color: #e2e8f0; }
</style>
