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

    let supabase: any = null;
    let accounts: WAAccount[] = [];
    let loading = true;
    let error = '';
    let showAddForm = false;
    let saving = false;
    let testingConnection = false;
    let testResult: { success: boolean; message: string } | null = null;

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
            const phoneId = showAddForm ? newAccount.phone_number_id : editAccount.phone_number_id;
            const token = showAddForm ? newAccount.access_token : editAccount.access_token;
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
                // Auto-fill display name if available
                if (data.display_phone_number && showAddForm && !newAccount.display_name) {
                    newAccount.display_name = data.verified_name || '';
                }
                if (data.display_phone_number && !showAddForm && !editAccount.display_name) {
                    editAccount.display_name = data.verified_name || '';
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

            showAddForm = false;
            resetForm();
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
            await loadAccounts();
        } catch (e: any) {
            error = e.message;
        } finally {
            saving = false;
        }
    }

    async function setDefault(accountId: string) {
        try {
            // Remove default from all
            await supabase.from('wa_accounts').update({ is_default: false }).neq('id', '');
            // Set new default
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

    async function disconnectAccount(accountId: string) {
        if (!confirm('Are you sure you want to disconnect this WhatsApp account?')) return;
        try {
            const { error: err } = await supabase
                .from('wa_accounts')
                .update({ status: 'disconnected', is_default: false, updated_at: new Date().toISOString() })
                .eq('id', accountId);
            if (err) throw err;
            await loadAccounts();
        } catch (e: any) {
            error = e.message;
        }
    }

    async function reconnectAccount(accountId: string) {
        try {
            const { error: err } = await supabase
                .from('wa_accounts')
                .update({ status: 'connected', updated_at: new Date().toISOString() })
                .eq('id', accountId);
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
        if (!token) return '';
        if (token.length <= 12) return '••••••••';
        return token.substring(0, 6) + '••••••••' + token.substring(token.length - 4);
    }
</script>

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
    <!-- Header -->
    <div class="bg-white border-b border-slate-200 px-6 py-4 flex items-center justify-between shadow-sm">
        <div class="flex items-center gap-3">
            <span class="text-2xl">🔗</span>
            <div>
                <h2 class="text-lg font-black text-slate-800 uppercase tracking-wide">{$t('nav.whatsappAccounts')}</h2>
                <p class="text-xs text-slate-500">{$t('whatsapp.accounts.subtitle')}</p>
            </div>
        </div>
        <button
            class="flex items-center gap-2 px-5 py-2.5 bg-emerald-600 text-white text-xs font-bold uppercase tracking-wide rounded-xl hover:bg-emerald-700 transition-all shadow-lg shadow-emerald-200 hover:shadow-emerald-300 hover:scale-[1.02]"
            on:click={() => { showAddForm = !showAddForm; resetForm(); }}
        >
            <span class="text-base">{showAddForm ? '✕' : '+'}</span>
            {showAddForm ? $t('common.cancel') : $t('whatsapp.accounts.connectNew')}
        </button>
    </div>

    <!-- Main Content -->
    <div class="flex-1 p-8 relative overflow-y-auto bg-[radial-gradient(ellipse_at_top_right,_var(--tw-gradient-stops))] from-white via-slate-50/50 to-slate-100/50">
        <div class="absolute top-0 right-0 w-[500px] h-[500px] bg-emerald-100/20 rounded-full blur-[120px] -mr-64 -mt-64 animate-pulse"></div>
        <div class="absolute bottom-0 left-0 w-[500px] h-[500px] bg-green-100/20 rounded-full blur-[120px] -ml-64 -mb-64 animate-pulse" style="animation-delay: 2s;"></div>

        <div class="relative max-w-4xl mx-auto">
            {#if loading}
                <div class="flex items-center justify-center h-64">
                    <div class="text-center">
                        <div class="animate-spin inline-block">
                            <div class="w-12 h-12 border-4 border-emerald-200 border-t-emerald-600 rounded-full"></div>
                        </div>
                        <p class="mt-4 text-slate-600 font-semibold">{$t('common.loading')}</p>
                    </div>
                </div>
            {:else}
                {#if error}
                    <div class="bg-red-50 border border-red-200 rounded-2xl p-4 mb-6 text-center">
                        <p class="text-red-700 font-semibold text-sm">{error}</p>
                        <button class="mt-2 text-xs text-red-600 underline" on:click={() => error = ''}>{$t('common.dismiss')}</button>
                    </div>
                {/if}

                <!-- Add New Account Form -->
                {#if showAddForm}
                    <div class="bg-white/60 backdrop-blur-xl rounded-[2rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-8 mb-8">
                        <h3 class="text-lg font-black text-slate-800 mb-6 flex items-center gap-2">
                            <span>📲</span> {$t('whatsapp.accounts.connectNew')}
                        </h3>

                        <div class="grid grid-cols-2 gap-5">
                            <div>
                                <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('whatsapp.accounts.phoneNumber')} *</label>
                                <input type="text" bind:value={newAccount.phone_number} placeholder="+966 5X XXX XXXX"
                                    class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all" />
                            </div>
                            <div>
                                <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('whatsapp.accounts.displayName')}</label>
                                <input type="text" bind:value={newAccount.display_name} placeholder="Business Name"
                                    class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all" />
                            </div>
                            <div>
                                <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">WABA ID</label>
                                <input type="text" bind:value={newAccount.waba_id} placeholder="WhatsApp Business Account ID"
                                    class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all" />
                            </div>
                            <div>
                                <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('whatsapp.accounts.phoneNumberId')} *</label>
                                <input type="text" bind:value={newAccount.phone_number_id} placeholder="Meta Phone Number ID"
                                    class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all" />
                            </div>
                            <div class="col-span-2">
                                <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('whatsapp.accounts.accessToken')} *</label>
                                <input type="password" bind:value={newAccount.access_token} placeholder="WhatsApp Cloud API Access Token"
                                    class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all font-mono" />
                            </div>
                        </div>

                        {#if testResult}
                            <div class="mt-4 p-3 rounded-xl text-sm font-semibold {testResult.success ? 'bg-emerald-50 text-emerald-700 border border-emerald-200' : 'bg-red-50 text-red-700 border border-red-200'}">
                                {testResult.success ? '✅' : '❌'} {testResult.message}
                            </div>
                        {/if}

                        <div class="flex justify-end gap-3 mt-6">
                            <button
                                class="px-5 py-2.5 bg-slate-100 text-slate-700 text-xs font-bold uppercase rounded-xl hover:bg-slate-200 transition-all"
                                on:click={testConnection}
                                disabled={testingConnection}
                            >
                                {testingConnection ? '⏳' : '🔌'} {$t('whatsapp.accounts.testConnection')}
                            </button>
                            <button
                                class="px-5 py-2.5 bg-emerald-600 text-white text-xs font-bold uppercase rounded-xl hover:bg-emerald-700 transition-all shadow-lg shadow-emerald-200 disabled:opacity-50"
                                on:click={saveAccount}
                                disabled={saving}
                            >
                                {saving ? '⏳' : '💾'} {$t('common.save')}
                            </button>
                        </div>
                    </div>
                {/if}

                <!-- Account Cards -->
                {#if accounts.length === 0 && !showAddForm}
                    <div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-12 text-center border-dashed border-2 border-slate-200">
                        <div class="text-5xl mb-4">📱</div>
                        <p class="text-slate-600 font-semibold text-lg">{$t('whatsapp.accounts.noAccounts')}</p>
                        <p class="text-slate-400 text-sm mt-2">{$t('whatsapp.accounts.noAccountsDesc')}</p>
                        <button
                            class="mt-6 px-6 py-3 bg-emerald-600 text-white font-bold rounded-xl hover:bg-emerald-700 transition-all shadow-lg shadow-emerald-200"
                            on:click={() => { showAddForm = true; resetForm(); }}
                        >
                            + {$t('whatsapp.accounts.connectFirst')}
                        </button>
                    </div>
                {:else}
                    <div class="space-y-4">
                        {#each accounts as account}
                            <div class="bg-white/60 backdrop-blur-xl rounded-[2rem] border border-white shadow-[0_16px_48px_-12px_rgba(0,0,0,0.06)] p-6 hover:shadow-[0_24px_64px_-16px_rgba(0,0,0,0.1)] transition-all duration-300">
                                {#if editingId === account.id}
                                    <!-- Edit Mode -->
                                    <div class="grid grid-cols-2 gap-4">
                                        <div>
                                            <label class="block text-xs font-bold text-slate-600 mb-1 uppercase">{$t('whatsapp.accounts.phoneNumber')}</label>
                                            <input type="text" bind:value={editAccount.phone_number}
                                                class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500" />
                                        </div>
                                        <div>
                                            <label class="block text-xs font-bold text-slate-600 mb-1 uppercase">{$t('whatsapp.accounts.displayName')}</label>
                                            <input type="text" bind:value={editAccount.display_name}
                                                class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500" />
                                        </div>
                                        <div>
                                            <label class="block text-xs font-bold text-slate-600 mb-1 uppercase">WABA ID</label>
                                            <input type="text" bind:value={editAccount.waba_id}
                                                class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500" />
                                        </div>
                                        <div>
                                            <label class="block text-xs font-bold text-slate-600 mb-1 uppercase">{$t('whatsapp.accounts.phoneNumberId')}</label>
                                            <input type="text" bind:value={editAccount.phone_number_id}
                                                class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500" />
                                        </div>
                                        <div class="col-span-2">
                                            <label class="block text-xs font-bold text-slate-600 mb-1 uppercase">{$t('whatsapp.accounts.accessToken')}</label>
                                            <input type="password" bind:value={editAccount.access_token}
                                                class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 font-mono" />
                                        </div>
                                    </div>
                                    {#if testResult}
                                        <div class="mt-3 p-3 rounded-xl text-sm font-semibold {testResult.success ? 'bg-emerald-50 text-emerald-700 border border-emerald-200' : 'bg-red-50 text-red-700 border border-red-200'}">
                                            {testResult.success ? '✅' : '❌'} {testResult.message}
                                        </div>
                                    {/if}
                                    <div class="flex justify-end gap-3 mt-4">
                                        <button class="px-4 py-2 bg-slate-100 text-slate-600 text-xs font-bold rounded-xl hover:bg-slate-200" on:click={testConnection}>
                                            🔌 {$t('whatsapp.accounts.testConnection')}
                                        </button>
                                        <button class="px-4 py-2 bg-slate-100 text-slate-600 text-xs font-bold rounded-xl hover:bg-slate-200" on:click={cancelEdit}>
                                            {$t('common.cancel')}
                                        </button>
                                        <button class="px-4 py-2 bg-emerald-600 text-white text-xs font-bold rounded-xl hover:bg-emerald-700 disabled:opacity-50" on:click={updateAccount} disabled={saving}>
                                            {saving ? '⏳' : '💾'} {$t('common.save')}
                                        </button>
                                    </div>
                                {:else}
                                    <!-- View Mode -->
                                    <div class="flex items-center justify-between">
                                        <div class="flex items-center gap-4">
                                            <div class="w-14 h-14 rounded-2xl bg-emerald-100 flex items-center justify-center text-2xl shadow-inner">
                                                {account.status === 'connected' ? '📱' : '📵'}
                                            </div>
                                            <div>
                                                <div class="flex items-center gap-2">
                                                    <h3 class="font-black text-slate-800 text-base">{account.display_name || account.phone_number}</h3>
                                                    {#if account.is_default}
                                                        <span class="px-2 py-0.5 bg-emerald-100 text-emerald-700 text-[10px] font-bold uppercase rounded-full border border-emerald-200">
                                                            {$t('whatsapp.accounts.default')}
                                                        </span>
                                                    {/if}
                                                </div>
                                                <p class="text-sm text-slate-500 font-mono mt-0.5">{account.phone_number}</p>
                                                <div class="flex items-center gap-3 mt-1.5">
                                                    <span class="px-2 py-0.5 text-[10px] font-bold uppercase rounded-full border {account.status === 'connected' ? 'bg-emerald-50 text-emerald-700 border-emerald-200' : 'bg-red-50 text-red-700 border-red-200'}">
                                                        {account.status === 'connected' ? '● Connected' : '● Disconnected'}
                                                    </span>
                                                    <span class="px-2 py-0.5 text-[10px] font-bold uppercase rounded-full border {getQualityColor(account.quality_rating)}">
                                                        {getQualityDot(account.quality_rating)} Quality: {account.quality_rating || 'N/A'}
                                                    </span>
                                                </div>
                                            </div>
                                        </div>

                                        <div class="flex items-center gap-2">
                                            {#if !account.is_default && account.status === 'connected'}
                                                <button class="px-3 py-2 bg-blue-50 text-blue-700 text-xs font-bold rounded-xl hover:bg-blue-100 transition-all border border-blue-200"
                                                    on:click={() => setDefault(account.id)}>
                                                    ⭐ {$t('whatsapp.accounts.setDefault')}
                                                </button>
                                            {/if}
                                            <button class="px-3 py-2 bg-slate-50 text-slate-600 text-xs font-bold rounded-xl hover:bg-slate-100 transition-all border border-slate-200"
                                                on:click={() => startEdit(account)}>
                                                ✏️ {$t('common.edit')}
                                            </button>
                                            {#if account.status === 'connected'}
                                                <button class="px-3 py-2 bg-amber-50 text-amber-700 text-xs font-bold rounded-xl hover:bg-amber-100 transition-all border border-amber-200"
                                                    on:click={() => disconnectAccount(account.id)}>
                                                    🔌 {$t('whatsapp.accounts.disconnect')}
                                                </button>
                                            {:else}
                                                <button class="px-3 py-2 bg-emerald-50 text-emerald-700 text-xs font-bold rounded-xl hover:bg-emerald-100 transition-all border border-emerald-200"
                                                    on:click={() => reconnectAccount(account.id)}>
                                                    🔗 {$t('whatsapp.accounts.reconnect')}
                                                </button>
                                            {/if}
                                            <button class="px-3 py-2 bg-red-50 text-red-700 text-xs font-bold rounded-xl hover:bg-red-100 transition-all border border-red-200"
                                                on:click={() => deleteAccount(account.id)}>
                                                🗑️
                                            </button>
                                        </div>
                                    </div>

                                    <!-- Account Details Row -->
                                    <div class="mt-4 grid grid-cols-3 gap-4 pt-4 border-t border-slate-100">
                                        <div>
                                            <span class="text-[10px] font-bold text-slate-400 uppercase">WABA ID</span>
                                            <p class="text-xs text-slate-600 font-mono mt-0.5">{account.waba_id || '—'}</p>
                                        </div>
                                        <div>
                                            <span class="text-[10px] font-bold text-slate-400 uppercase">Phone Number ID</span>
                                            <p class="text-xs text-slate-600 font-mono mt-0.5">{account.phone_number_id || '—'}</p>
                                        </div>
                                        <div>
                                            <span class="text-[10px] font-bold text-slate-400 uppercase">Access Token</span>
                                            <p class="text-xs text-slate-600 font-mono mt-0.5">{maskToken(account.access_token)}</p>
                                        </div>
                                    </div>
                                {/if}
                            </div>
                        {/each}
                    </div>
                {/if}

                <!-- Info Card -->
                <div class="mt-8 bg-blue-50/50 backdrop-blur-xl rounded-2xl border border-blue-100 p-6">
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
            {/if}
        </div>
    </div>
</div>
