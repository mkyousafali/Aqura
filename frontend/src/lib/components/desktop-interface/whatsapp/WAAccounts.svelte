<script lang="ts">
    import { onMount, onDestroy } from 'svelte';
    import { _ as t, locale } from '$lib/i18n';

    interface WAAccount {
        id: string;
        phone_number: string;
        display_name: string;
        waba_id: string;
        phone_number_id: string;
        access_token: string;
        quality_rating: string;
        status: string;
        is_default: boolean;
        created_at: string;
        updated_at: string;
    }

    const tabs = [
        { id: 'accounts', label: 'Connected Accounts', icon: '📱', color: 'green' },
        { id: 'create', label: 'Create Account', icon: '➕', color: 'orange' }
    ];

    let supabase: any = null;
    let accounts: WAAccount[] = [];
    let loading = true;
    let error = '';
    let activeTab = 'accounts';
    let saving = false;
    let testingConnection = false;
    let testResult: { success: boolean; message: string } | null = null;
    let searchQuery = '';

    // New account form
    let newAccount = {
        phone_number: '',
        display_name: '',
        waba_id: '',
        phone_number_id: '',
        access_token: ''
    };

    // Edit mode
    let editingId: string | null = null;
    let editAccount = { ...newAccount };

    // Filtered accounts
    $: filteredAccounts = accounts.filter(a => {
        if (!searchQuery.trim()) return true;
        const q = searchQuery.toLowerCase();
        return (a.display_name || '').toLowerCase().includes(q) ||
            (a.phone_number || '').toLowerCase().includes(q) ||
            (a.waba_id || '').toLowerCase().includes(q) ||
            (a.phone_number_id || '').toLowerCase().includes(q);
    });

    onMount(async () => {
        const mod = await import('$lib/utils/supabase');
        supabase = mod.supabase;
        await loadAccounts();
    });

    async function loadAccounts() {
        loading = true;
        error = '';
        try {
            const { data, error: err } = await supabase
                .from('wa_accounts')
                .select('*')
                .order('is_default', { ascending: false })
                .order('created_at', { ascending: false });
            if (err) throw err;
            accounts = data || [];
        } catch (e: any) {
            error = e.message || 'Failed to load accounts';
        } finally {
            loading = false;
        }
    }

    async function testConnection() {
        testingConnection = true;
        testResult = null;
        try {
            const phoneId = activeTab === 'create' ? newAccount.phone_number_id : editAccount.phone_number_id;
            const token = activeTab === 'create' ? newAccount.access_token : editAccount.access_token;
            if (!phoneId || !token) {
                testResult = { success: false, message: 'Phone Number ID and Access Token are required' };
                return;
            }
            const res = await fetch(`https://graph.facebook.com/v22.0/${phoneId}`, {
                headers: { Authorization: `Bearer ${token}` }
            });
            const data = await res.json();
            if (res.ok && data.id) {
                testResult = { success: true, message: `Connected! Verified phone: ${data.display_phone_number || data.id}` };
                if (data.verified_name) {
                    if (activeTab === 'create' && !newAccount.display_name) {
                        newAccount.display_name = data.verified_name;
                    }
                    if (activeTab !== 'create' && !editAccount.display_name) {
                        editAccount.display_name = data.verified_name;
                    }
                }
            } else {
                testResult = { success: false, message: data.error?.message || 'Connection failed' };
            }
        } catch (e: any) {
            testResult = { success: false, message: e.message || 'Network error' };
        } finally {
            testingConnection = false;
        }
    }

    async function saveAccount() {
        saving = true;
        error = '';
        try {
            if (!newAccount.phone_number || !newAccount.phone_number_id || !newAccount.access_token) {
                throw new Error('Phone Number, Phone Number ID, and Access Token are required');
            }

            const isFirst = accounts.length === 0;
            const { error: err } = await supabase.from('wa_accounts').insert({
                phone_number: newAccount.phone_number,
                display_name: newAccount.display_name || newAccount.phone_number,
                waba_id: newAccount.waba_id,
                phone_number_id: newAccount.phone_number_id,
                access_token: newAccount.access_token,
                is_default: isFirst,
                status: 'connected'
            });
            if (err) throw err;

            resetForm();
            activeTab = 'accounts';
            await loadAccounts();
        } catch (e: any) {
            error = e.message;
        } finally {
            saving = false;
        }
    }

    async function updateAccount() {
        if (!editingId) return;
        saving = true;
        error = '';
        try {
            const { error: err } = await supabase
                .from('wa_accounts')
                .update({
                    phone_number: editAccount.phone_number,
                    display_name: editAccount.display_name,
                    waba_id: editAccount.waba_id,
                    phone_number_id: editAccount.phone_number_id,
                    access_token: editAccount.access_token,
                    updated_at: new Date().toISOString()
                })
                .eq('id', editingId);
            if (err) throw err;

            editingId = null;
            testResult = null;
            await loadAccounts();
        } catch (e: any) {
            error = e.message;
        } finally {
            saving = false;
        }
    }

    async function setDefault(accountId: string) {
        try {
            await supabase.from('wa_accounts').update({ is_default: false }).neq('id', '');
            const { error: err } = await supabase
                .from('wa_accounts')
                .update({ is_default: true, updated_at: new Date().toISOString() })
                .eq('id', accountId);
            if (err) throw err;
            await loadAccounts();
        } catch (e: any) {
            error = e.message;
        }
    }

    async function toggleStatus(account: WAAccount) {
        const newStatus = account.status === 'connected' ? 'disconnected' : 'connected';
        if (newStatus === 'disconnected' && !confirm('Are you sure you want to disconnect this WhatsApp account?')) return;
        try {
            const updates: any = { status: newStatus, updated_at: new Date().toISOString() };
            if (newStatus === 'disconnected') updates.is_default = false;
            const { error: err } = await supabase.from('wa_accounts').update(updates).eq('id', account.id);
            if (err) throw err;
            await loadAccounts();
        } catch (e: any) {
            error = e.message;
        }
    }

    async function deleteAccount(accountId: string) {
        if (!confirm('Are you sure you want to permanently delete this account? This cannot be undone.')) return;
        try {
            const { error: err } = await supabase.from('wa_accounts').delete().eq('id', accountId);
            if (err) throw err;
            await loadAccounts();
        } catch (e: any) {
            error = e.message;
        }
    }

    function startEdit(account: WAAccount) {
        editingId = account.id;
        editAccount = {
            phone_number: account.phone_number,
            display_name: account.display_name,
            waba_id: account.waba_id,
            phone_number_id: account.phone_number_id,
            access_token: account.access_token
        };
        testResult = null;
    }

    function cancelEdit() {
        editingId = null;
        testResult = null;
    }

    function resetForm() {
        newAccount = { phone_number: '', display_name: '', waba_id: '', phone_number_id: '', access_token: '' };
        testResult = null;
    }

    function getQualityColor(rating: string) {
        switch (rating?.toUpperCase()) {
            case 'GREEN': return 'bg-emerald-100 text-emerald-700 border-emerald-200';
            case 'YELLOW': return 'bg-amber-100 text-amber-700 border-amber-200';
            case 'RED': return 'bg-red-100 text-red-700 border-red-200';
            default: return 'bg-slate-100 text-slate-600 border-slate-200';
        }
    }

    function getQualityDot(rating: string) {
        switch (rating?.toUpperCase()) {
            case 'GREEN': return '🟢';
            case 'YELLOW': return '🟡';
            case 'RED': return '🔴';
            default: return '⚪';
        }
    }

    function maskToken(token: string) {
        if (!token) return '—';
        if (token.length <= 12) return '••••••••';
        return token.substring(0, 6) + '••••••••' + token.substring(token.length - 4);
    }

    function formatDate(dateStr: string) {
        if (!dateStr) return '—';
        try {
            return new Date(dateStr).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' });
        } catch { return dateStr; }
    }
</script>

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
    <!-- Header/Navigation -->
    <div class="bg-white border-b border-slate-200 px-6 py-4 flex items-center justify-end shadow-sm">
        <div class="flex gap-2 bg-slate-100 p-1.5 rounded-2xl border border-slate-200/50 shadow-inner">
            {#each tabs as tab}
                <button
                    class="group relative flex items-center gap-2.5 px-6 py-2.5 text-xs font-black uppercase tracking-wide transition-all duration-500 rounded-xl overflow-hidden
                    {activeTab === tab.id
                        ? (tab.color === 'green' ? 'bg-emerald-600 text-white shadow-lg shadow-emerald-200 scale-[1.02]' : 'bg-orange-600 text-white shadow-lg shadow-orange-200 scale-[1.02]')
                        : 'text-slate-500 hover:bg-white hover:text-slate-800 hover:shadow-md'}"
                    on:click={() => { activeTab = tab.id; testResult = null; }}
                >
                    <span class="text-base filter drop-shadow-sm transition-transform duration-500 group-hover:rotate-12">{tab.icon}</span>
                    <span class="relative z-10">{tab.label}</span>
                    {#if activeTab === tab.id}
                        <div class="absolute inset-0 bg-white/10 animate-pulse"></div>
                    {/if}
                </button>
            {/each}
        </div>
    </div>

    <!-- Main Content Area -->
    <div class="flex-1 p-8 relative overflow-y-auto bg-[radial-gradient(ellipse_at_top_right,_var(--tw-gradient-stops))] from-white via-slate-50/50 to-slate-100/50">
        <!-- Background decorative elements -->
        <div class="absolute top-0 right-0 w-[500px] h-[500px] bg-emerald-100/20 rounded-full blur-[120px] -mr-64 -mt-64 animate-pulse"></div>
        <div class="absolute bottom-0 left-0 w-[500px] h-[500px] bg-orange-100/20 rounded-full blur-[120px] -ml-64 -mb-64 animate-pulse" style="animation-delay: 2s;"></div>

        <div class="relative max-w-[99%] mx-auto h-full flex flex-col">

            {#if error}
                <div class="bg-red-50 border border-red-200 rounded-2xl p-4 mb-4 flex items-center justify-between">
                    <p class="text-red-700 font-semibold text-sm">❌ {error}</p>
                    <button class="text-xs text-red-600 underline font-bold" on:click={() => error = ''}>{$t('common.dismiss') || 'Dismiss'}</button>
                </div>
            {/if}

            <!-- ===== CONNECTED ACCOUNTS TAB ===== -->
            {#if activeTab === 'accounts'}
                {#if loading}
                    <div class="flex items-center justify-center h-full">
                        <div class="text-center">
                            <div class="animate-spin inline-block">
                                <div class="w-12 h-12 border-4 border-emerald-200 border-t-emerald-600 rounded-full"></div>
                            </div>
                            <p class="mt-4 text-slate-600 font-semibold">{$t('common.loading')}</p>
                        </div>
                    </div>
                {:else if accounts.length === 0}
                    <div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-12 flex flex-col items-center justify-center border-dashed border-2 border-slate-200">
                        <div class="text-5xl mb-4">📱</div>
                        <p class="text-slate-600 font-semibold text-lg">{$t('whatsapp.accounts.noAccounts')}</p>
                        <p class="text-slate-400 text-sm mt-2">{$t('whatsapp.accounts.noAccountsDesc')}</p>
                        <button
                            class="mt-6 px-6 py-3 bg-orange-600 text-white font-bold rounded-xl hover:bg-orange-700 transition-all shadow-lg shadow-orange-200"
                            on:click={() => { activeTab = 'create'; resetForm(); }}
                        >
                            ➕ {$t('whatsapp.accounts.connectFirst')}
                        </button>
                    </div>
                {:else}
                    <!-- Search -->
                    <div class="mb-4 flex gap-3">
                        <div class="flex-1">
                            <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="account-search">Search Accounts</label>
                            <input
                                id="account-search"
                                type="text"
                                bind:value={searchQuery}
                                placeholder="Search by name, phone, WABA ID..."
                                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all"
                            />
                        </div>
                        <div class="flex items-end">
                            <button
                                class="px-5 py-2.5 bg-emerald-600 text-white text-xs font-bold uppercase tracking-wide rounded-xl hover:bg-emerald-700 transition-all shadow-lg shadow-emerald-200 hover:scale-[1.02]"
                                on:click={loadAccounts}
                            >
                                🔄 Refresh
                            </button>
                        </div>
                    </div>

                    <!-- Accounts Table -->
                    <div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden flex flex-col flex-1">
                        <div class="overflow-x-auto flex-1">
                            <table class="w-full border-collapse [&_th]:border-x [&_th]:border-emerald-500/30 [&_td]:border-x [&_td]:border-slate-200">
                                <thead class="sticky top-0 bg-emerald-600 text-white shadow-lg z-10">
                                    <tr>
                                        <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">#</th>
                                        <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Display Name</th>
                                        <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Phone Number</th>
                                        <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Status</th>
                                        <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Quality</th>
                                        <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Default</th>
                                        <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">WABA ID</th>
                                        <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Phone Number ID</th>
                                        <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Access Token</th>
                                        <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Updated</th>
                                        <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Actions</th>
                                    </tr>
                                </thead>
                                <tbody class="divide-y divide-slate-200">
                                    {#each filteredAccounts as account, index}
                                        <tr class="hover:bg-emerald-50/30 transition-colors duration-200 {index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'}">
                                            <td class="px-4 py-3 text-sm text-slate-500 font-mono">{index + 1}</td>
                                            <td class="px-4 py-3 text-sm">
                                                {#if editingId === account.id}
                                                    <input type="text" bind:value={editAccount.display_name}
                                                        class="w-full px-2 py-1.5 bg-white border border-emerald-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500" />
                                                {:else}
                                                    <span class="font-bold text-slate-800">{account.display_name || '—'}</span>
                                                {/if}
                                            </td>
                                            <td class="px-4 py-3 text-sm">
                                                {#if editingId === account.id}
                                                    <input type="text" bind:value={editAccount.phone_number}
                                                        class="w-full px-2 py-1.5 bg-white border border-emerald-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 font-mono" />
                                                {:else}
                                                    <span class="text-slate-700 font-mono">{account.phone_number}</span>
                                                {/if}
                                            </td>
                                            <td class="px-4 py-3 text-center">
                                                <span class="inline-flex items-center px-2.5 py-1 text-[10px] font-bold uppercase rounded-full border
                                                    {account.status === 'connected' ? 'bg-emerald-50 text-emerald-700 border-emerald-200' : 'bg-red-50 text-red-600 border-red-200'}">
                                                    {account.status === 'connected' ? '● Connected' : '● Disconnected'}
                                                </span>
                                            </td>
                                            <td class="px-4 py-3 text-center">
                                                <span class="inline-flex items-center px-2.5 py-1 text-[10px] font-bold uppercase rounded-full border {getQualityColor(account.quality_rating)}">
                                                    {getQualityDot(account.quality_rating)} {account.quality_rating || 'N/A'}
                                                </span>
                                            </td>
                                            <td class="px-4 py-3 text-center">
                                                {#if account.is_default}
                                                    <span class="inline-flex items-center px-2.5 py-1 text-[10px] font-bold uppercase rounded-full bg-emerald-100 text-emerald-700 border border-emerald-200">
                                                        ⭐ Default
                                                    </span>
                                                {:else if account.status === 'connected'}
                                                    <button class="text-[10px] font-bold text-blue-600 hover:text-blue-800 underline uppercase"
                                                        on:click={() => setDefault(account.id)}>
                                                        Set Default
                                                    </button>
                                                {:else}
                                                    <span class="text-slate-400 text-xs">—</span>
                                                {/if}
                                            </td>
                                            <td class="px-4 py-3 text-sm">
                                                {#if editingId === account.id}
                                                    <input type="text" bind:value={editAccount.waba_id}
                                                        class="w-full px-2 py-1.5 bg-white border border-emerald-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 font-mono" />
                                                {:else}
                                                    <span class="text-slate-600 font-mono text-xs">{account.waba_id || '—'}</span>
                                                {/if}
                                            </td>
                                            <td class="px-4 py-3 text-sm">
                                                {#if editingId === account.id}
                                                    <input type="text" bind:value={editAccount.phone_number_id}
                                                        class="w-full px-2 py-1.5 bg-white border border-emerald-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 font-mono" />
                                                {:else}
                                                    <span class="text-slate-600 font-mono text-xs">{account.phone_number_id || '—'}</span>
                                                {/if}
                                            </td>
                                            <td class="px-4 py-3 text-sm">
                                                {#if editingId === account.id}
                                                    <input type="password" bind:value={editAccount.access_token}
                                                        class="w-full px-2 py-1.5 bg-white border border-emerald-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 font-mono" />
                                                {:else}
                                                    <span class="text-slate-500 font-mono text-xs">{maskToken(account.access_token)}</span>
                                                {/if}
                                            </td>
                                            <td class="px-4 py-3 text-xs text-slate-500">{formatDate(account.updated_at || account.created_at)}</td>
                                            <td class="px-4 py-3 text-center">
                                                <div class="flex items-center justify-center gap-1.5 flex-wrap">
                                                    {#if editingId === account.id}
                                                        <button class="px-3 py-1.5 bg-slate-100 text-slate-600 text-[10px] font-bold rounded-lg hover:bg-slate-200 border border-slate-200"
                                                            on:click={testConnection} disabled={testingConnection}>
                                                            {testingConnection ? '⏳' : '🔌'} Test
                                                        </button>
                                                        <button class="px-3 py-1.5 bg-emerald-600 text-white text-[10px] font-bold rounded-lg hover:bg-emerald-700 disabled:opacity-50"
                                                            on:click={updateAccount} disabled={saving}>
                                                            {saving ? '⏳' : '💾'} Save
                                                        </button>
                                                        <button class="px-3 py-1.5 bg-slate-100 text-slate-600 text-[10px] font-bold rounded-lg hover:bg-slate-200 border border-slate-200"
                                                            on:click={cancelEdit}>
                                                            ✕
                                                        </button>
                                                    {:else}
                                                        <button class="inline-flex items-center justify-center px-3 py-1.5 rounded-lg bg-emerald-600 text-white text-[10px] font-bold hover:bg-emerald-700 hover:shadow-lg transition-all duration-200 transform hover:scale-105"
                                                            on:click={() => startEdit(account)} title="Edit">
                                                            ✏️ Edit
                                                        </button>
                                                        <button class="px-3 py-1.5 text-[10px] font-bold rounded-lg border transition-all hover:scale-105
                                                            {account.status === 'connected'
                                                                ? 'bg-amber-50 text-amber-700 border-amber-200 hover:bg-amber-100'
                                                                : 'bg-emerald-50 text-emerald-700 border-emerald-200 hover:bg-emerald-100'}"
                                                            on:click={() => toggleStatus(account)}>
                                                            {account.status === 'connected' ? '🔌 Disconnect' : '🔗 Reconnect'}
                                                        </button>
                                                        <button class="px-3 py-1.5 bg-red-50 text-red-600 text-[10px] font-bold rounded-lg hover:bg-red-100 border border-red-200 transition-all hover:scale-105"
                                                            on:click={() => deleteAccount(account.id)} title="Delete">
                                                            🗑️
                                                        </button>
                                                        <a href="https://business.facebook.com/latest/whatsapp_manager/phone_numbers/?waba_id={account.waba_id}"
                                                            target="_blank" rel="noopener noreferrer"
                                                            class="inline-flex items-center px-3 py-1.5 bg-blue-50 text-blue-700 text-[10px] font-bold rounded-lg hover:bg-blue-100 border border-blue-200 transition-all hover:scale-105 no-underline"
                                                            title="Open Meta Business Settings">
                                                            ⚙️ Meta
                                                        </a>
                                                    {/if}
                                                </div>
                                                {#if editingId === account.id && testResult}
                                                    <div class="mt-1.5 px-2 py-1 rounded-lg text-[10px] font-semibold {testResult.success ? 'bg-emerald-50 text-emerald-700' : 'bg-red-50 text-red-600'}">
                                                        {testResult.success ? '✅' : '❌'} {testResult.message}
                                                    </div>
                                                {/if}
                                            </td>
                                        </tr>
                                    {/each}
                                </tbody>
                            </table>
                        </div>

                        <!-- Table Footer -->
                        <div class="px-6 py-3 border-t border-slate-200 bg-white/50 flex items-center justify-between">
                            <span class="text-xs text-slate-500 font-semibold">
                                Showing {filteredAccounts.length} of {accounts.length} accounts
                            </span>
                            <span class="text-xs text-slate-400">
                                {accounts.filter(a => a.status === 'connected').length} connected · {accounts.filter(a => a.is_default).length} default
                            </span>
                        </div>
                    </div>
                {/if}

            <!-- ===== CREATE ACCOUNT TAB ===== -->
            {:else if activeTab === 'create'}
                <div class="max-w-3xl mx-auto w-full">
                    <div class="bg-white/60 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-8">
                        <h3 class="text-lg font-black text-slate-800 mb-2 flex items-center gap-2">
                            <span>📲</span> {$t('whatsapp.accounts.connectNew')}
                        </h3>
                        <p class="text-xs text-slate-500 mb-6">Fill in the details from your Meta WhatsApp Business Platform.</p>

                        <div class="grid grid-cols-2 gap-5">
                            <div>
                                <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="new-phone">{$t('whatsapp.accounts.phoneNumber')} *</label>
                                <input id="new-phone" type="text" bind:value={newAccount.phone_number} placeholder="+966 5X XXX XXXX"
                                    class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent transition-all" />
                            </div>
                            <div>
                                <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="new-name">{$t('whatsapp.accounts.displayName')}</label>
                                <input id="new-name" type="text" bind:value={newAccount.display_name} placeholder="Business Name"
                                    class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent transition-all" />
                            </div>
                            <div>
                                <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="new-waba">WABA ID</label>
                                <input id="new-waba" type="text" bind:value={newAccount.waba_id} placeholder="WhatsApp Business Account ID"
                                    class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent transition-all" />
                            </div>
                            <div>
                                <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="new-phone-id">{$t('whatsapp.accounts.phoneNumberId')} *</label>
                                <input id="new-phone-id" type="text" bind:value={newAccount.phone_number_id} placeholder="Meta Phone Number ID"
                                    class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent transition-all" />
                            </div>
                            <div class="col-span-2">
                                <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="new-token">{$t('whatsapp.accounts.accessToken')} *</label>
                                <input id="new-token" type="password" bind:value={newAccount.access_token} placeholder="WhatsApp Cloud API Access Token"
                                    class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent transition-all font-mono" />
                            </div>
                        </div>

                        {#if testResult}
                            <div class="mt-4 p-3 rounded-xl text-sm font-semibold {testResult.success ? 'bg-emerald-50 text-emerald-700 border border-emerald-200' : 'bg-red-50 text-red-700 border border-red-200'}">
                                {testResult.success ? '✅' : '❌'} {testResult.message}
                            </div>
                        {/if}

                        <div class="flex justify-end gap-3 mt-6">
                            <button
                                class="px-5 py-2.5 bg-slate-100 text-slate-700 text-xs font-bold uppercase rounded-xl hover:bg-slate-200 transition-all border border-slate-200"
                                on:click={testConnection}
                                disabled={testingConnection}
                            >
                                {testingConnection ? '⏳' : '🔌'} {$t('whatsapp.accounts.testConnection')}
                            </button>
                            <button
                                class="px-5 py-2.5 bg-slate-100 text-slate-700 text-xs font-bold uppercase rounded-xl hover:bg-slate-200 transition-all border border-slate-200"
                                on:click={resetForm}
                            >
                                🔄 Reset
                            </button>
                            <button
                                class="px-6 py-2.5 bg-orange-600 text-white text-xs font-bold uppercase rounded-xl hover:bg-orange-700 transition-all shadow-lg shadow-orange-200 disabled:opacity-50 hover:scale-[1.02]"
                                on:click={saveAccount}
                                disabled={saving}
                            >
                                {saving ? '⏳' : '💾'} {$t('common.save')}
                            </button>
                        </div>
                    </div>

                    <!-- Info Card -->
                    <div class="mt-6 bg-blue-50/50 backdrop-blur-xl rounded-2xl border border-blue-100 p-6">
                        <h4 class="font-bold text-blue-800 text-sm mb-3 flex items-center gap-2">
                            <span>ℹ️</span> {$t('whatsapp.accounts.howToConnect')}
                        </h4>
                        <ol class="text-xs text-blue-700 space-y-2 list-decimal list-inside">
                            <li>{$t('whatsapp.accounts.step1')}</li>
                            <li>{$t('whatsapp.accounts.step2')}</li>
                            <li>{$t('whatsapp.accounts.step3')}</li>
                            <li>{$t('whatsapp.accounts.step4')}</li>
                            <li>{$t('whatsapp.accounts.step5')}</li>
                        </ol>
                    </div>
                </div>
            {/if}
        </div>
    </div>
</div>
