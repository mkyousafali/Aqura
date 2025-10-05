<script lang="ts">
	import { createEventDispatcher, onMount } from 'svelte';
	import { windowManager } from '$lib/stores/windowManager';
	import { t } from '$lib/i18n';

	export let visible = false;

	const dispatch = createEventDispatcher();

	let searchInput: HTMLInputElement;
	let searchQuery = '';
	let selectedIndex = 0;
	let filteredCommands: Command[] = [];

	interface Command {
		id: string;
		title: string;
		description?: string;
		category: string;
		icon?: string;
		action: () => void;
		keywords?: string[];
	}

	// Available commands
	const commands: Command[] = [
		// Window Management
		{
			id: 'minimize-all',
			title: t('commands.minimizeAll') || 'Minimize All Windows',
			description: t('commands.minimizeAllDesc') || 'Minimize all open windows',
			category: t('commands.window') || 'Window',
			icon: '🔽',
			action: () => windowManager.minimizeAllWindows()
		},
		{
			id: 'close-all',
			title: t('commands.closeAll') || 'Close All Windows',
			description: t('commands.closeAllDesc') || 'Close all open windows',
			category: t('commands.window') || 'Window',
			icon: '❌',
			action: () => windowManager.closeAllWindows()
		},
		{
			id: 'show-desktop',
			title: t('commands.showDesktop') || 'Show Desktop',
			description: t('commands.showDesktopDesc') || 'Show desktop by minimizing all windows',
			category: t('commands.window') || 'Window',
			icon: '🖥️',
			action: () => windowManager.minimizeAllWindows(),
			keywords: ['desktop', 'minimize']
		},

		// Navigation
		{
			id: 'open-branches',
			title: t('admin.branchesMaster') || 'Branch Master',
			description: t('commands.manageBranches') || 'Manage company branches',
			category: t('admin.title') || 'Admin',
			icon: '🏢',
			action: () => openWindow('branch-master'),
			keywords: ['office', 'location']
		},
		{
			id: 'open-vendors',
			title: t('admin.vendorsMaster') || 'Vendor Master',
			description: t('commands.manageVendors') || 'Manage vendors and suppliers',
			category: t('admin.title') || 'Admin',
			icon: '🤝',
			action: () => openWindow('vendor-master'),
			keywords: ['supplier', 'contractor']
		},
		{
			id: 'open-invoices',
			title: t('admin.invoiceMaster') || 'Invoice Management',
			description: t('commands.manageInvoices') || 'Manage invoices and billing',
			category: t('nav.finance') || 'Finance',
			icon: '📄',
			action: () => openWindow('invoice-master'),
			keywords: ['bill', 'payment', 'finance']
		},
		{
			id: 'open-users',
			title: t('admin.userManagement') || 'User Management',
			description: t('commands.manageUsers') || 'Manage system users and roles',
			category: t('admin.title') || 'Admin',
			icon: '👤',
			action: () => openWindow('user-master'),
			keywords: ['account', 'permission', 'role']
		},
		{
			id: 'open-import',
			title: t('admin.importData') || 'Data Import',
			description: t('commands.importData') || 'Import data from Excel files',
			category: t('commands.tools') || 'Tools',
			icon: '📥',
			action: () => openWindow('data-import'),
			keywords: ['excel', 'xlsx', 'upload']
		},

		// System
		{
			id: 'help',
			title: t('commands.help') || 'Help & Documentation',
			description: t('commands.helpDesc') || 'View system documentation',
			category: t('commands.helpCategory') || 'Help',
			icon: '❓',
			action: () => openWindow('help'),
			keywords: ['docs', 'manual', 'guide']
		},
		{
			id: 'about',
			title: t('commands.about') || 'About Aqura',
			description: t('commands.aboutDesc') || 'System information and version',
			category: t('commands.helpCategory') || 'Help',
			icon: 'ℹ️',
			action: () => openWindow('about'),
			keywords: ['version', 'info']
		}
	];

	// Reactive filtering
	$: {
		if (searchQuery.trim()) {
			const query = searchQuery.toLowerCase();
			filteredCommands = commands.filter(cmd => 
				cmd.title.toLowerCase().includes(query) ||
				cmd.description?.toLowerCase().includes(query) ||
				cmd.category.toLowerCase().includes(query) ||
				cmd.keywords?.some(keyword => keyword.toLowerCase().includes(query))
			);
		} else {
			filteredCommands = commands;
		}
		selectedIndex = 0; // Reset selection when filtering
	}

	onMount(() => {
		if (visible && searchInput) {
			searchInput.focus();
		}
	});

	$: if (visible && searchInput) {
		searchInput.focus();
	}

	function openWindow(windowType: string) {
		// This would normally import the actual components
		// For now, just create placeholder windows
		const config = {
			'branch-master': {
				title: 'Branch Master', 
				component: null,
				icon: '🏢'
			},
			'vendor-master': {
				title: 'Vendor Master',
				component: null,
				icon: '🤝'
			},
			'invoice-master': {
				title: 'Invoice Management',
				component: null,
				icon: '📄'
			},
			'user-master': {
				title: 'User Management',
				component: null,
				icon: '👤'
			},
			'data-import': {
				title: 'Data Import',
				component: null,
				icon: '📥'
			},
			'help': {
				title: 'Help & Documentation',
				component: null,
				icon: '❓'
			},
			'about': {
				title: 'About Aqura',
				component: null,
				icon: 'ℹ️'
			}
		}[windowType];

		if (config) {
			// For demo purposes, create a simple content div
			const PlaceholderComponent = {
				render: () => `<div class="p-6"><h2 class="text-xl font-bold mb-4">${config.title}</h2><p>This module is under development.</p></div>`
			};
			
			windowManager.openWindow({
				...config,
				component: PlaceholderComponent
			});
		}
	}

	function executeCommand(command: Command) {
		command.action();
		closeCommandPalette();
	}

	function closeCommandPalette() {
		visible = false;
		searchQuery = '';
		selectedIndex = 0;
		dispatch('close');
	}

	function handleKeydown(event: KeyboardEvent) {
		switch (event.key) {
			case 'Escape':
				closeCommandPalette();
				break;
			case 'ArrowDown':
				event.preventDefault();
				selectedIndex = Math.min(selectedIndex + 1, filteredCommands.length - 1);
				break;
			case 'ArrowUp':
				event.preventDefault();
				selectedIndex = Math.max(selectedIndex - 1, 0);
				break;
			case 'Enter':
				event.preventDefault();
				if (filteredCommands[selectedIndex]) {
					executeCommand(filteredCommands[selectedIndex]);
				}
				break;
		}
	}

	function handleBackdropClick(event: MouseEvent) {
		if (event.target === event.currentTarget) {
			closeCommandPalette();
		}
	}
</script>

<!-- Command Palette Modal -->
{#if visible}
	<div 
		class="command-palette-backdrop" 
		on:click={handleBackdropClick}
		on:keydown={handleKeydown}
		role="dialog"
		aria-modal="true"
		aria-label="Command palette"
		tabindex="-1"
	>
		<div class="command-palette">
			<!-- Search Input -->
			<div class="search-container">
				<div class="search-icon">
					<svg viewBox="0 0 20 20" width="20" height="20">
						<path fill="currentColor" d="M9 3.5a5.5 5.5 0 1 0 0 11 5.5 5.5 0 0 0 0-11ZM2 9a7 7 0 1 1 12.452 4.391l3.328 3.329a.75.75 0 1 1-1.06 1.06l-3.329-3.328A7 7 0 0 1 2 9Z"/>
					</svg>
				</div>
				<input
					bind:this={searchInput}
					bind:value={searchQuery}
					type="text"
					placeholder={t('commands.searchPlaceholder') || 'Type a command or search...'}
					class="search-input"
					on:keydown={handleKeydown}
				/>
				{#if searchQuery}
					<button 
						class="clear-button"
						on:click={() => searchQuery = ''}
						title={t('commands.clearSearch') || 'Clear search'}
						aria-label={t('commands.clearSearch') || 'Clear search'}
					>
						<svg viewBox="0 0 20 20" width="16" height="16">
							<path fill="currentColor" d="M6.28 5.22a.75.75 0 0 0-1.06 1.06L8.94 10l-3.72 3.72a.75.75 0 1 0 1.06 1.06L10 11.06l3.72 3.72a.75.75 0 1 0 1.06-1.06L11.06 10l3.72-3.72a.75.75 0 0 0-1.06-1.06L10 8.94 6.28 5.22Z"/>
						</svg>
					</button>
				{/if}
			</div>

			<!-- Command List -->
			<div class="command-list">
				{#if filteredCommands.length === 0}
					<div class="no-results">
						<div class="no-results-icon">🔍</div>
						<div class="no-results-text">{t('commands.noResults') || 'No commands found'}</div>
					</div>
				{:else}
					{#each filteredCommands as command, index (command.id)}
						<button
							class="command-item"
							class:selected={index === selectedIndex}
							on:click={() => executeCommand(command)}
						>
							<div class="command-icon">
								{command.icon || '📦'}
							</div>
							<div class="command-content">
								<div class="command-title">{command.title}</div>
								{#if command.description}
									<div class="command-description">{command.description}</div>
								{/if}
							</div>
							<div class="command-category">{command.category}</div>
						</button>
					{/each}
				{/if}
			</div>

			<!-- Footer -->
			<div class="command-footer">
				<div class="keyboard-hints">
					<span class="hint">
						<kbd>↑↓</kbd> Navigate
					</span>
					<span class="hint">
						<kbd>Enter</kbd> {t('commands.execute') || 'Execute'}
					</span>
					<span class="hint">
						<kbd>Esc</kbd> {t('commands.close') || 'Close'}
					</span>
				</div>
			</div>
		</div>
	</div>
{/if}

<style>
	.command-palette-backdrop {
		position: fixed;
		top: 0;
		left: 0;
		width: 100vw;
		height: 100vh;
		background: rgba(0, 0, 0, 0.5);
		backdrop-filter: blur(4px);
		display: flex;
		align-items: flex-start;
		justify-content: center;
		padding-top: 20vh;
		z-index: 3000;
	}

	.command-palette {
		background: white;
		border-radius: 12px;
		box-shadow: 0 25px 50px rgba(0, 0, 0, 0.25);
		width: 100%;
		max-width: 600px;
		max-height: 70vh;
		overflow: hidden;
		border: 1px solid #e2e8f0;
	}

	.search-container {
		position: relative;
		border-bottom: 1px solid #e2e8f0;
	}

	.search-icon {
		position: absolute;
		left: 16px;
		top: 50%;
		transform: translateY(-50%);
		color: #64748b;
		pointer-events: none;
	}

	.search-input {
		width: 100%;
		padding: 16px 16px 16px 48px;
		border: none;
		outline: none;
		font-size: 16px;
		background: transparent;
		color: #1e293b;
	}

	.search-input::placeholder {
		color: #94a3b8;
	}

	.clear-button {
		position: absolute;
		right: 16px;
		top: 50%;
		transform: translateY(-50%);
		background: none;
		border: none;
		color: #64748b;
		cursor: pointer;
		padding: 4px;
		border-radius: 4px;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.clear-button:hover {
		background: #f1f5f9;
		color: #374151;
	}

	.command-list {
		max-height: 400px;
		overflow-y: auto;
	}

	.command-item {
		width: 100%;
		display: flex;
		align-items: center;
		gap: 12px;
		padding: 12px 16px;
		border: none;
		background: none;
		text-align: left;
		cursor: pointer;
		transition: background-color 0.15s ease;
		border-bottom: 1px solid #f1f5f9;
	}

	.command-item:hover,
	.command-item.selected {
		background: #f8fafc;
	}

	.command-item.selected {
		background: #fef3e2;
		border-left: 3px solid #f08300;
	}

	.command-icon {
		font-size: 20px;
		width: 24px;
		text-align: center;
		flex-shrink: 0;
	}

	.command-content {
		flex: 1;
		min-width: 0;
	}

	.command-title {
		font-weight: 500;
		color: #1e293b;
		margin-bottom: 2px;
	}

	.command-description {
		font-size: 13px;
		color: #64748b;
		line-height: 1.4;
	}

	.command-category {
		font-size: 12px;
		color: #94a3b8;
		background: #f1f5f9;
		padding: 4px 8px;
		border-radius: 4px;
		flex-shrink: 0;
	}

	.no-results {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 48px 24px;
		color: #64748b;
	}

	.no-results-icon {
		font-size: 48px;
		margin-bottom: 16px;
		opacity: 0.5;
	}

	.no-results-text {
		font-size: 16px;
		font-weight: 500;
	}

	.command-footer {
		border-top: 1px solid #e2e8f0;
		padding: 12px 16px;
		background: #f8fafc;
	}

	.keyboard-hints {
		display: flex;
		gap: 16px;
		justify-content: center;
	}

	.hint {
		display: flex;
		align-items: center;
		gap: 4px;
		font-size: 12px;
		color: #64748b;
	}

	kbd {
		background: #e2e8f0;
		border: 1px solid #cbd5e1;
		border-radius: 3px;
		padding: 2px 6px;
		font-size: 11px;
		font-family: 'Segoe UI', monospace;
		color: #374151;
	}

	/* Custom scrollbar */
	.command-list::-webkit-scrollbar {
		width: 6px;
	}

	.command-list::-webkit-scrollbar-track {
		background: #f1f5f9;
	}

	.command-list::-webkit-scrollbar-thumb {
		background: #cbd5e1;
		border-radius: 3px;
	}

	.command-list::-webkit-scrollbar-thumb:hover {
		background: #94a3b8;
	}

	/* Animation */
	.command-palette {
		animation: slideUp 0.2s ease-out;
	}

	@keyframes slideUp {
		from {
			opacity: 0;
			transform: translateY(20px) scale(0.95);
		}
		to {
			opacity: 1;
			transform: translateY(0) scale(1);
		}
	}
</style>
