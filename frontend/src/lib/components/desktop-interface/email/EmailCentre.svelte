<script lang="ts">
	import { onMount } from 'svelte';
	import { _ as t } from '$lib/i18n';

	let supabase: any = null;
	let loading = true;
	let accounts: any[] = [];
	let selectedAccountId = '';
	let folders: any[] = [];
	let messages: any[] = [];
	let selectedMessage: any = null;
	let messageDetail: any = null;
	let searchQuery = '';
	let currentFolder = '';
	let page = 1;
	let totalMessages = 0;
	let pageSize = 50;
	let syncing = false;
	let syncMessage = '';
	let showInlineCompose = false;
	let composeTo = '';
	let composeSubject = '';
	let composeBody = '';
	let composeSending = false;

	onMount(async () => {
		const mod = await import('$lib/utils/supabase');
		supabase = mod.supabase;
		await loadAccounts();
	});

	async function loadAccounts() {
		const { data } = await supabase.rpc('get_email_accounts');
		accounts = data || [];
		if (accounts.length > 0) {
			selectedAccountId = accounts[0].id;
			await loadFolders();
		}
		loading = false;
	}

	async function loadFolders() {
		if (!selectedAccountId) return;
		const { data } = await supabase.rpc('get_email_folders', { p_account_id: selectedAccountId });
		folders = data || [];
		currentFolder = '';
		await loadMessages();
	}

	async function syncNow() {
		if (!selectedAccountId || syncing) return;
		syncing = true;
		syncMessage = '';
		try {
			const { data, error } = await supabase.functions.invoke('email-imap-sync', {
				body: { account_id: selectedAccountId }
			});
			if (error) throw error;
			if (data?.success) {
				syncMessage = `✅ Synced ${data.synced} new emails`;
				await loadFolders();
			} else {
				syncMessage = '❌ ' + (data?.error || 'Sync failed');
			}
		} catch (err: any) {
			syncMessage = '❌ Sync error: ' + (err.message || err);
		} finally {
			syncing = false;
			setTimeout(() => syncMessage = '', 5000);
		}
	}

	async function sendCompose() {
		if (!composeTo.trim() || !composeBody.trim()) return;
		composeSending = true;
		const account = accounts.find((a: any) => a.id === selectedAccountId);
		try {
			const recipients = composeTo.split(/[,;]/).map(e => ({ type: 'to', email: e.trim(), name: '' })).filter(r => r.email);
			const { data: draftData, error: draftErr } = await supabase.rpc('save_email_draft', { p_data: {
				email_account_id: selectedAccountId,
				subject: composeSubject,
				html_body: `<p>${composeBody.replace(/\n/g, '<br>')}</p>`,
				text_body: composeBody,
				from_name: account?.from_name || account?.account_name || '',
				from_address: account?.email_address || '',
				recipients
			}});
			if (draftErr) throw draftErr;

			const { data: queueData, error: qErr } = await supabase.rpc('queue_email_send', {
				p_message_id: draftData.id, p_queue_type: 'normal', p_priority: 5
			});
			if (qErr) throw qErr;

			const { data: sendResult } = await supabase.functions.invoke('email-send', {
				body: { queue_id: queueData.queue_id }
			});

			if (sendResult?.success) {
				showInlineCompose = false;
				composeTo = ''; composeSubject = ''; composeBody = '';
				syncMessage = '✅ Email sent!';
				await loadMessages();
			} else {
				syncMessage = '❌ Send failed: ' + (sendResult?.error || 'Unknown');
			}
		} catch (err: any) {
			syncMessage = '❌ ' + err.message;
		} finally {
			composeSending = false;
			setTimeout(() => syncMessage = '', 5000);
		}
	}

	async function loadMessages() {
		if (!selectedAccountId) return;
		const { data } = await supabase.rpc('get_email_messages_threaded', {
			p_account_id: selectedAccountId,
			p_folder_id: currentFolder || null,
			p_search: searchQuery || null,
			p_page: page,
			p_page_size: pageSize
		});
		if (data) {
			messages = data.threads || [];
			totalMessages = data.total || 0;
		}
	}

	let threadMessages: any[] = [];

	async function selectMessage(msg: any) {
		selectedMessage = msg;
		showReplyForm = false;
		replyText = '';
		
		// If it's a thread with multiple messages, load all
		if (msg.thread_id && msg.message_count > 1) {
			const { data } = await supabase.rpc('get_email_thread_messages', { p_thread_id: msg.thread_id });
			threadMessages = data || [];
		} else {
			// Single message
			const { data } = await supabase.rpc('get_email_message', { p_message_id: msg.latest_message_id || msg.id });
			threadMessages = data ? [data] : [];
		}
		// Mark as read in list
		msg.is_read = true;
		msg.unread_in_thread = 0;
		messages = [...messages];
	}

	async function toggleStar(msg: any) {
		const msgId = msg.latest_message_id || msg.id;
		await supabase.rpc('email_toggle_star', { p_message_ids: [msgId], p_is_starred: !msg.is_starred });
		msg.is_starred = !msg.is_starred;
		messages = [...messages];
	}

	async function archiveMessage(msgId: string) {
		await supabase.rpc('email_archive', { p_message_ids: [msgId] });
		messages = messages.filter(m => (m.latest_message_id || m.id) !== msgId);
		if (selectedMessage?.id === msgId) { selectedMessage = null; messageDetail = null; }
	}

	async function deleteMessage(msgId: string) {
		if (!msgId) return;
		await supabase.rpc('email_soft_delete', { p_message_ids: [msgId] });
		messages = messages.filter(m => (m.latest_message_id || m.id) !== msgId);
		selectedMessage = null;
		threadMessages = [];
	}

	function selectFolder(folderId: string) {
		currentFolder = folderId;
		page = 1;
		selectedMessage = null;
		messageDetail = null;
		loadMessages();
	}

	function onAccountChange() { loadFolders(); selectedMessage = null; messageDetail = null; }
	function onSearch() { page = 1; loadMessages(); }
	function prevPage() { if (page > 1) { page--; loadMessages(); } }
	function nextPage() { if (page * pageSize < totalMessages) { page++; loadMessages(); } }

	function formatDate(ts: string): string {
		if (!ts) return '';
		const d = new Date(ts);
		const now = new Date();
		if (d.toDateString() === now.toDateString()) return d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
		return d.toLocaleDateString([], { month: 'short', day: 'numeric' });
	}

	// Extract readable content from raw MIME body
	function extractReadableBody(text: string, html: string): { displayHtml: string; displayText: string } {
		if (html && !html.includes('Content-Type:') && !html.includes('--00')) {
			return { displayHtml: html, displayText: text || '' };
		}
		// If text contains MIME boundaries, try to extract parts
		const content = text || html || '';
		if (content.includes('Content-Type:') || content.includes('--0')) {
			// Try to extract HTML part
			const htmlMatch = content.match(/Content-Type:\s*text\/html[^\r\n]*\r?\n(?:Content-Transfer-Encoding:[^\r\n]*\r?\n)?\r?\n([\s\S]*?)(?=\r?\n--|\s*$)/i);
			if (htmlMatch) {
				let htmlContent = htmlMatch[1].trim();
				// Decode quoted-printable
				htmlContent = decodeQuotedPrintable(htmlContent);
				return { displayHtml: htmlContent, displayText: '' };
			}
			// Try plain text part
			const textMatch = content.match(/Content-Type:\s*text\/plain[^\r\n]*\r?\n(?:Content-Transfer-Encoding:[^\r\n]*\r?\n)?\r?\n([\s\S]*?)(?=\r?\n--|\s*$)/i);
			if (textMatch) {
				return { displayHtml: '', displayText: textMatch[1].trim() };
			}
			// Fallback: strip MIME headers/boundaries
			const cleaned = content.replace(/--[0-9a-f]+--?\r?\n?/gi, '')
				.replace(/Content-Type:[^\r\n]*\r?\n/gi, '')
				.replace(/Content-Transfer-Encoding:[^\r\n]*\r?\n/gi, '')
				.trim();
			return { displayHtml: '', displayText: cleaned };
		}
		return { displayHtml: html || '', displayText: text || '' };
	}

	function decodeQuotedPrintable(str: string): string {
		return str
			.replace(/=\r?\n/g, '') // soft line breaks
			.replace(/=([0-9A-Fa-f]{2})/g, (_, hex) => String.fromCharCode(parseInt(hex, 16)));
	}

	// Reply handling
	let showReplyForm = false;
	let replyText = '';
	let replySending = false;

	let replyMode: 'reply' | 'replyAll' | 'forward' = 'reply';
	let forwardTo = '';

	function startReply(mode: 'reply' | 'replyAll' | 'forward') {
		if (!threadMessages.length) return;
		// Get the latest message in thread
		const lastItem = threadMessages[threadMessages.length - 1];
		const msg = lastItem.message || lastItem;
		showReplyForm = true;
		replyMode = mode;
		forwardTo = '';
		
		if (mode === 'forward') {
			replyText = `\n\n---------- Forwarded message ----------\nFrom: ${msg.from_name || ''} <${msg.from_address}>\nSubject: ${msg.subject}\n\n${msg.text_body || msg.body_preview || ''}`;
		} else {
			replyText = `\n\nOn ${formatDate(msg.received_at || msg.sent_at)}, ${msg.from_name || msg.from_address} wrote:\n> `;
		}
	}

	async function sendReply() {
		if (!threadMessages.length || !replyText.trim()) return;
		if (replyMode === 'forward' && !forwardTo.trim()) { syncMessage = '❌ Enter a recipient email to forward to'; return; }
		replySending = true;
		const lastItem = threadMessages[threadMessages.length - 1];
		const msg = lastItem.message || lastItem;
		const account = accounts.find((a: any) => a.id === selectedAccountId);
		
		try {
			// Determine recipients based on mode
			let recipients: Array<{type: string; email: string; name: string}>;
			let subjectPrefix: string;
			
			if (replyMode === 'forward') {
				recipients = forwardTo.split(/[,;]/).map(e => ({ type: 'to', email: e.trim(), name: '' })).filter(r => r.email);
				subjectPrefix = msg.subject?.startsWith('Fwd:') ? '' : 'Fwd: ';
			} else {
				recipients = [{ type: 'to', email: msg.from_address, name: msg.from_name || '' }];
				subjectPrefix = msg.subject?.startsWith('Re:') ? '' : 'Re: ';
			}

			const { data: draftData, error: draftErr } = await supabase.rpc('save_email_draft', { p_data: {
				email_account_id: selectedAccountId,
				subject: subjectPrefix + (msg.subject || ''),
				html_body: `<p>${replyText.replace(/\n/g, '<br>')}</p>`,
				text_body: replyText,
				from_name: account?.from_name || account?.account_name || '',
				from_address: account?.email_address || '',
				recipients
			}});
			if (draftErr) throw draftErr;

			// Queue and send
			const { data: queueData, error: qErr } = await supabase.rpc('queue_email_send', {
				p_message_id: draftData.id, p_queue_type: 'normal', p_priority: 5
			});
			if (qErr) throw qErr;

			const { data: sendResult } = await supabase.functions.invoke('email-send', {
				body: { queue_id: queueData.queue_id }
			});

			if (sendResult?.success) {
				showReplyForm = false;
				replyText = '';
				syncMessage = '✅ Reply sent!';
				setTimeout(() => syncMessage = '', 3000);
			} else {
				syncMessage = '❌ Reply failed: ' + (sendResult?.error || 'Unknown');
			}
		} catch (err: any) {
			syncMessage = '❌ ' + err.message;
		} finally {
			replySending = false;
		}
	}
</script>

<div class="email-centre">
	<!-- Top Bar -->
	<div class="top-bar">
		<select bind:value={selectedAccountId} on:change={onAccountChange} class="account-select">
			{#each accounts as acc}<option value={acc.id}>{acc.account_name} ({acc.email_address})</option>{/each}
		</select>
		<div class="search-box">
			<input type="text" placeholder="Search emails..." bind:value={searchQuery} on:keydown={(e) => e.key === 'Enter' && onSearch()} />
			<button on:click={onSearch}>🔍</button>
		</div>
		<button class="compose-btn" on:click={() => showInlineCompose = true}>
			✉️ Compose
		</button>
		<button class="sync-btn" on:click={syncNow} disabled={syncing}>
			{syncing ? '⏳ Syncing...' : '🔄 Sync'}
		</button>
		{#if syncMessage}<span class="sync-msg">{syncMessage}</span>{/if}
	</div>

	{#if loading}
		<div class="loading-container"><div class="loading-spinner"></div></div>
	{:else}
		<div class="email-layout">
			<!-- Folder Panel -->
			<div class="folder-panel">
				<button class="folder-item" class:active={!currentFolder} on:click={() => selectFolder('')}>
					📬 All Mail
				</button>
				{#each folders as folder}
					<button class="folder-item" class:active={currentFolder === folder.id} on:click={() => selectFolder(folder.id)}>
						{#if folder.folder_type === 'inbox'}📥
						{:else if folder.folder_type === 'sent'}📤
						{:else if folder.folder_type === 'drafts'}📝
						{:else if folder.folder_type === 'trash'}🗑️
						{:else if folder.folder_type === 'spam'}⚠️
						{:else if folder.folder_type === 'archive'}📦
						{:else if folder.folder_type === 'starred'}⭐
						{:else}📁{/if}
						{folder.display_name || folder.remote_folder_name}
						{#if folder.unread_count > 0}<span class="unread-badge">{folder.unread_count}</span>{/if}
					</button>
				{/each}
			</div>

			<!-- Message List -->
			<div class="message-list">
				{#each messages as msg}
				<div class="message-item" class:unread={!msg.is_read || msg.unread_in_thread > 0} class:active={selectedMessage?.thread_id === msg.thread_id} on:click={() => selectMessage(msg)} on:keydown={() => {}} role="button" tabindex="0">
					<span class="star-btn" on:click|stopPropagation={() => toggleStar(msg)} on:keydown|stopPropagation={() => {}} role="button" tabindex="0">{msg.is_starred ? '⭐' : '☆'}</span>
						<div class="msg-content">
							<div class="msg-top">
								<span class="msg-from">{msg.direction === 'inbound' ? (msg.from_name || msg.from_address) : 'To: recipients'}</span>
								<span class="msg-date">{formatDate(msg.latest_at)}</span>
							</div>
							<div class="msg-subject">
								{msg.subject || '(no subject)'}
								{#if msg.message_count > 1}<span class="thread-count">({msg.message_count})</span>{/if}
							</div>
							<div class="msg-preview">{msg.body_preview || ''}</div>
						</div>
						{#if msg.has_attachments}<span class="attachment-icon">📎</span>{/if}
					</div>
				{/each}
				{#if messages.length === 0}
					<div class="empty-state">No emails found</div>
				{/if}
				{#if totalMessages > pageSize}
					<div class="pagination">
						<button on:click={prevPage} disabled={page <= 1}>←</button>
						<span>Page {page} of {Math.ceil(totalMessages / pageSize)}</span>
						<button on:click={nextPage} disabled={page * pageSize >= totalMessages}>→</button>
					</div>
				{/if}
			</div>

			<!-- Reading Pane -->
			<div class="reading-pane">
				{#if showInlineCompose}
					<div class="inline-compose">
						<div class="compose-header">
							<h4>✉️ New Email</h4>
							<button class="glass-btn" on:click={() => showInlineCompose = false}>✕ Close</button>
						</div>
						<div class="compose-fields">
							<div class="field-row"><label>To:</label><input type="text" bind:value={composeTo} placeholder="recipient@example.com" /></div>
							<div class="field-row"><label>Subject:</label><input type="text" bind:value={composeSubject} placeholder="Email subject..." /></div>
							<textarea bind:value={composeBody} rows="12" placeholder="Type your message..."></textarea>
						</div>
						<div class="compose-actions">
							<button class="glass-btn" on:click={() => showInlineCompose = false}>Cancel</button>
							<button class="glass-btn primary" on:click={sendCompose} disabled={composeSending || !composeTo.trim() || !composeBody.trim()}>
								{composeSending ? 'Sending...' : '📤 Send'}
							</button>
						</div>
					</div>
				{:else if selectedMessage && threadMessages.length > 0}
					<div class="thread-header">
						<h4>{selectedMessage.subject || '(no subject)'}</h4>
						<div class="msg-actions">
							<button class="glass-btn" on:click={() => startReply('reply')}>↩️ Reply</button>
							<button class="glass-btn" on:click={() => startReply('replyAll')}>↩️↩️ Reply All</button>
							<button class="glass-btn" on:click={() => startReply('forward')}>↪️ Forward</button>
							<button class="glass-btn danger" on:click={() => deleteMessage(selectedMessage.latest_message_id)}>🗑️ Delete</button>
						</div>
					</div>

					<!-- Reply Form -->
					{#if showReplyForm}
						<div class="reply-form">
							{#if replyMode === 'forward'}
								<div class="forward-to-field">
									<label>Forward to:</label>
									<input type="email" bind:value={forwardTo} placeholder="recipient@example.com" />
								</div>
							{/if}
							<textarea bind:value={replyText} rows="6" placeholder={replyMode === 'forward' ? 'Add a message (optional)...' : 'Type your reply...'}></textarea>
							<div class="reply-actions">
								<button class="glass-btn" on:click={() => { showReplyForm = false; replyText = ''; forwardTo = ''; }}>Cancel</button>
								<button class="glass-btn primary" on:click={sendReply} disabled={replySending || !replyText.trim() || (replyMode === 'forward' && !forwardTo.trim())}>
									{replySending ? 'Sending...' : (replyMode === 'forward' ? '↪️ Forward' : '📤 Send Reply')}
								</button>
							</div>
						</div>
					{/if}

					<!-- Thread Messages -->
					<div class="thread-messages">
						{#each threadMessages as item, i}
							{@const msg = item.message || item}
							{@const parsed = extractReadableBody(msg.text_body || '', msg.html_body || '')}
							<div class="thread-message" class:outbound={msg.direction === 'outbound'}>
								<div class="thread-msg-header">
									<span class="thread-sender">
										{#if msg.direction === 'outbound'}📤 Me{:else}📥 {msg.from_name || msg.from_address}{/if}
									</span>
									<span class="thread-date">{formatDate(msg.received_at || msg.sent_at || msg.created_at)}</span>
								</div>
								<div class="thread-msg-body">
									{#if parsed.displayHtml}
										<iframe srcdoc={parsed.displayHtml} sandbox="allow-same-origin allow-popups" title="Email {i}"></iframe>
									{:else}
										<pre>{parsed.displayText}</pre>
									{/if}
								</div>
							</div>
						{/each}
					</div>
				{:else}
					<div class="empty-pane">Select an email to read</div>
				{/if}
			</div>
		</div>
	{/if}
</div>

<style>
	.email-centre { display: flex; flex-direction: column; height: 100%; background: #f8fafc; }
	.top-bar { display: flex; gap: 12px; padding: 10px 16px; background: white; border-bottom: 1px solid #e2e8f0; align-items: center; }
	.account-select { padding: 6px 10px; border: 1px solid #e2e8f0; border-radius: 6px; font-size: 13px; max-width: 280px; }
	.search-box { display: flex; flex: 1; max-width: 400px; }
	.search-box input { flex: 1; padding: 6px 10px; border: 1px solid #e2e8f0; border-radius: 6px 0 0 6px; font-size: 13px; }
	.search-box button { padding: 6px 12px; border: 1px solid #e2e8f0; border-left: none; border-radius: 0 6px 6px 0; background: #f8fafc; cursor: pointer; }
	.sync-btn { padding: 6px 14px; border: 1px solid #e2e8f0; border-radius: 6px; font-size: 12px; background: #f0fdf4; color: #166534; cursor: pointer; font-weight: 500; white-space: nowrap; }
	.sync-btn:hover { background: #dcfce7; }
	.sync-btn:disabled { opacity: 0.6; cursor: not-allowed; }
	.compose-btn { padding: 6px 14px; border: 1px solid rgba(240,131,0,0.3); border-radius: 6px; font-size: 12px; background: rgba(240,131,0,0.1); color: #c2410c; cursor: pointer; font-weight: 600; white-space: nowrap; }
	.compose-btn:hover { background: rgba(240,131,0,0.2); }
	.sync-msg { font-size: 11px; color: #64748b; white-space: nowrap; }

	.inline-compose { display: flex; flex-direction: column; height: 100%; padding: 16px; gap: 12px; }
	.compose-header { display: flex; justify-content: space-between; align-items: center; }
	.compose-header h4 { font-size: 16px; font-weight: 600; color: #1e293b; }
	.compose-fields { display: flex; flex-direction: column; gap: 8px; flex: 1; }
	.compose-fields .field-row { display: flex; align-items: center; gap: 8px; }
	.compose-fields .field-row label { font-size: 12px; font-weight: 600; color: #64748b; min-width: 50px; }
	.compose-fields .field-row input { flex: 1; padding: 8px 10px; border: 1px solid #e2e8f0; border-radius: 6px; font-size: 13px; }
	.compose-fields .field-row input:focus { border-color: #f08300; outline: none; }
	.compose-fields textarea { flex: 1; padding: 10px; border: 1px solid #e2e8f0; border-radius: 6px; font-size: 13px; resize: none; font-family: inherit; }
	.compose-fields textarea:focus { border-color: #f08300; outline: none; }
	.compose-actions { display: flex; justify-content: flex-end; gap: 8px; }
	.loading-container { display: flex; align-items: center; justify-content: center; flex: 1; }
	.loading-spinner { width: 32px; height: 32px; border: 3px solid #e2e8f0; border-top-color: #f08300; border-radius: 50%; animation: spin 0.8s linear infinite; }
	@keyframes spin { to { transform: rotate(360deg); } }

	.email-layout { display: flex; flex: 1; overflow: hidden; }
	.folder-panel { width: 180px; min-width: 180px; overflow-y: auto; background: white; border-right: 1px solid #e2e8f0; padding: 8px; }
	.folder-item { display: flex; align-items: center; gap: 6px; width: 100%; padding: 8px 10px; border: none; background: none; cursor: pointer; border-radius: 6px; font-size: 12px; text-align: left; color: #475569; }
	.folder-item:hover { background: #f1f5f9; }
	.folder-item.active { background: #fff7ed; color: #c2410c; font-weight: 500; }
	.unread-badge { background: #f08300; color: white; font-size: 10px; padding: 1px 5px; border-radius: 10px; margin-left: auto; }

	.message-list { width: 340px; min-width: 300px; overflow-y: auto; border-right: 1px solid #e2e8f0; background: white; }
	.message-item { display: flex; align-items: flex-start; gap: 8px; width: 100%; padding: 10px 12px; border: none; border-bottom: 1px solid #f1f5f9; background: white; cursor: pointer; text-align: left; }
	.message-item:hover { background: #fafafa; }
	.message-item.active { background: #fff7ed; }
	.message-item.unread { background: #fffbeb; }
	.message-item.unread .msg-from { font-weight: 700; }
	.star-btn { background: none; border: none; cursor: pointer; font-size: 14px; padding: 0; line-height: 1; }
	.msg-content { flex: 1; min-width: 0; }
	.msg-top { display: flex; justify-content: space-between; align-items: center; }
	.msg-from { font-size: 12px; color: #1e293b; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 180px; }
	.msg-date { font-size: 11px; color: #94a3b8; white-space: nowrap; }
	.msg-subject { font-size: 12px; color: #334155; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; margin-top: 2px; }
	.msg-preview { font-size: 11px; color: #94a3b8; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
	.attachment-icon { font-size: 12px; }
	.pagination { display: flex; justify-content: center; align-items: center; gap: 8px; padding: 10px; font-size: 12px; color: #64748b; }
	.pagination button { padding: 4px 10px; border: 1px solid #e2e8f0; border-radius: 4px; background: white; cursor: pointer; }
	.pagination button:disabled { opacity: 0.4; cursor: not-allowed; }

	.reading-pane { flex: 1; overflow-y: auto; padding: 16px; display: flex; flex-direction: column; }
	.msg-detail-header { margin-bottom: 12px; }
	.msg-detail-header h4 { font-size: 16px; font-weight: 600; color: #1e293b; margin-bottom: 8px; }
	.msg-meta { display: flex; flex-direction: column; gap: 2px; font-size: 12px; color: #64748b; margin-bottom: 6px; }
	.msg-recipients { display: flex; flex-wrap: wrap; gap: 4px; margin-bottom: 10px; }
	.recipient-chip { font-size: 11px; background: #f1f5f9; padding: 2px 8px; border-radius: 4px; color: #475569; }
	.msg-actions { display: flex; gap: 6px; flex-wrap: wrap; }
	.attachments-bar { display: flex; flex-wrap: wrap; gap: 6px; margin-bottom: 12px; }
	.attachment-chip { font-size: 11px; background: #f1f5f9; padding: 4px 8px; border-radius: 4px; color: #475569; }
	.msg-body { flex: 1; background: white; border-radius: 8px; border: 1px solid #e2e8f0; overflow: hidden; }
	.msg-body iframe { width: 100%; height: 100%; min-height: 400px; border: none; }
	.msg-body pre { padding: 16px; font-size: 13px; white-space: pre-wrap; word-break: break-word; color: #334155; }
	.empty-pane { display: flex; align-items: center; justify-content: center; height: 100%; color: #94a3b8; font-size: 14px; }
	.empty-state { text-align: center; padding: 40px; color: #94a3b8; font-size: 13px; }

	.reply-form { margin-bottom: 12px; padding: 12px; background: white; border: 1px solid #e2e8f0; border-radius: 8px; }
	.reply-form textarea { width: 100%; padding: 10px; border: 1px solid #e2e8f0; border-radius: 6px; font-size: 13px; resize: vertical; font-family: inherit; }
	.reply-form textarea:focus { border-color: #f08300; outline: none; }
	.reply-actions { display: flex; justify-content: flex-end; gap: 8px; margin-top: 8px; }
	.forward-to-field { display: flex; align-items: center; gap: 8px; margin-bottom: 8px; }
	.forward-to-field label { font-size: 12px; font-weight: 600; color: #64748b; white-space: nowrap; }
	.forward-to-field input { flex: 1; padding: 8px 10px; border: 1px solid #e2e8f0; border-radius: 6px; font-size: 13px; }
	.forward-to-field input:focus { border-color: #f08300; outline: none; }

	.thread-count { font-size: 10px; background: #e0e7ff; color: #3730a3; padding: 1px 5px; border-radius: 8px; margin-left: 4px; font-weight: 600; }
	.thread-header { margin-bottom: 12px; }
	.thread-header h4 { font-size: 16px; font-weight: 600; color: #1e293b; margin-bottom: 8px; }
	.thread-messages { display: flex; flex-direction: column; gap: 10px; flex: 1; overflow-y: auto; }
	.thread-message { background: white; border: 1px solid #e2e8f0; border-radius: 8px; overflow: hidden; }
	.thread-message.outbound { border-left: 3px solid #f08300; }
	.thread-msg-header { display: flex; justify-content: space-between; padding: 8px 12px; background: #f8fafc; border-bottom: 1px solid #f1f5f9; }
	.thread-sender { font-size: 12px; font-weight: 600; color: #334155; }
	.thread-date { font-size: 11px; color: #94a3b8; }
	.thread-msg-body { padding: 0; min-height: 60px; }
	.thread-msg-body iframe { width: 100%; min-height: 100px; border: none; }
	.thread-msg-body pre { padding: 10px 12px; font-size: 13px; white-space: pre-wrap; word-break: break-word; color: #334155; margin: 0; }

	.glass-btn { padding: 6px 12px; border-radius: 6px; font-size: 12px; font-weight: 500; border: 1px solid rgba(255,255,255,0.3); cursor: pointer; background: rgba(255,255,255,0.7); backdrop-filter: blur(8px); box-shadow: 0 1px 4px rgba(0,0,0,0.04); transition: all 0.15s; color: #334155; }
	.glass-btn:hover { background: rgba(255,255,255,0.9); box-shadow: 0 2px 8px rgba(0,0,0,0.08); }
	.glass-btn:disabled { opacity: 0.5; cursor: not-allowed; }
	.glass-btn.primary { background: rgba(240,131,0,0.15); border-color: rgba(240,131,0,0.3); color: #c2410c; }
	.glass-btn.primary:hover { background: rgba(240,131,0,0.25); }
	.glass-btn.danger { color: #dc2626; }
	.glass-btn.danger:hover { background: #fee2e2; }
</style>
