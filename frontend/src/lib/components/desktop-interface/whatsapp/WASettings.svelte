<script lang="ts">
    import { onMount } from 'svelte';
    import { _ as t, locale } from '$lib/i18n';

    interface WASettings {
        id: string;
        wa_account_id: string;
        business_name: string;
        business_description: string;
        business_address: string;
        business_email: string;
        business_website: string;
        business_category: string;
        profile_picture_url: string;
        about_text: string;
        webhook_url: string;
        webhook_verify_token: string;
        webhook_active: boolean;
        business_hours: any;
        outside_hours_message: string;
        default_language: string;
        notify_new_message: boolean;
        notify_bot_escalation: boolean;
        notify_broadcast_complete: boolean;
        notify_template_status: boolean;
    }

    interface WAAccount {
        id: string;
        phone_number: string;
        display_name: string;
        phone_number_id: string;
        is_default: boolean;
    }

    let supabase: any = null;
    let loading = true;
    let saving = false;
    let activeTab = 'profile';
    let accounts: WAAccount[] = [];
    let selectedAccountId = '';
    let settings: WASettings | null = null;
    let successMsg = '';
    let errorMsg = '';

    const tabs = [
        { id: 'profile', icon: '🏢', label: 'Business Profile', color: 'green' },
        { id: 'webhook', icon: '🔗', label: 'Webhook', color: 'green' },
        { id: 'notifications', icon: '🔔', label: 'Notifications', color: 'green' },
        { id: 'hours', icon: '🕐', label: 'Business Hours', color: 'green' },
        { id: 'defaults', icon: '⚙️', label: 'Defaults', color: 'green' }
    ];

    const defaultHours: any = {
        sunday: { open: false, start: '09:00', end: '22:00' },
        monday: { open: true, start: '09:00', end: '22:00' },
        tuesday: { open: true, start: '09:00', end: '22:00' },
        wednesday: { open: true, start: '09:00', end: '22:00' },
        thursday: { open: true, start: '09:00', end: '22:00' },
        friday: { open: false, start: '09:00', end: '22:00' },
        saturday: { open: true, start: '09:00', end: '22:00' }
    };

    const dayLabels: Record<string, string> = {
        sunday: 'Sunday', monday: 'Monday', tuesday: 'Tuesday',
        wednesday: 'Wednesday', thursday: 'Thursday', friday: 'Friday', saturday: 'Saturday'
    };

    onMount(async () => {
        const mod = await import('$lib/utils/supabase');
        supabase = mod.supabase;
        await loadAccounts();
    });

    async function loadAccounts() {
        try {
            const { data } = await supabase
                .from('wa_accounts')
                .select('id, phone_number, display_name, phone_number_id, is_default')
                .eq('status', 'connected')
                .order('is_default', { ascending: false });
            accounts = data || [];
            if (accounts.length > 0) {
                selectedAccountId = accounts[0].id;
                await loadSettings();
            } else {
                loading = false;
            }
        } catch (e: any) {
            errorMsg = e.message;
            loading = false;
        }
    }

    async function loadSettings() {
        loading = true;
        try {
            const { data } = await supabase
                .from('wa_settings')
                .select('*')
                .eq('wa_account_id', selectedAccountId)
                .single();

            if (data) {
                settings = data;
                if (!settings!.business_hours || Object.keys(settings!.business_hours).length === 0) {
                    settings!.business_hours = { ...defaultHours };
                }
            } else {
                // Create default settings for this account
                const { data: newData, error: err } = await supabase
                    .from('wa_settings')
                    .insert({
                        wa_account_id: selectedAccountId,
                        business_hours: defaultHours,
                        default_language: 'en'
                    })
                    .select()
                    .single();
                if (err) throw err;
                settings = newData;
            }
        } catch (e: any) {
            errorMsg = e.message;
        } finally {
            loading = false;
        }
    }

    async function saveSettings() {
        if (!settings) return;
        saving = true;
        successMsg = '';
        errorMsg = '';
        try {
            const { error: err } = await supabase
                .from('wa_settings')
                .update({
                    business_name: settings.business_name,
                    business_description: settings.business_description,
                    business_address: settings.business_address,
                    business_email: settings.business_email,
                    business_website: settings.business_website,
                    business_category: settings.business_category,
                    profile_picture_url: settings.profile_picture_url,
                    about_text: settings.about_text,
                    webhook_url: settings.webhook_url,
                    webhook_verify_token: settings.webhook_verify_token,
                    webhook_active: settings.webhook_active,
                    business_hours: settings.business_hours,
                    outside_hours_message: settings.outside_hours_message,
                    default_language: settings.default_language,
                    notify_new_message: settings.notify_new_message,
                    notify_bot_escalation: settings.notify_bot_escalation,
                    notify_broadcast_complete: settings.notify_broadcast_complete,
                    notify_template_status: settings.notify_template_status,
                    updated_at: new Date().toISOString()
                })
                .eq('id', settings.id);
            if (err) throw err;
            successMsg = 'Settings saved successfully!';
            setTimeout(() => successMsg = '', 3000);
        } catch (e: any) {
            errorMsg = e.message;
        } finally {
            saving = false;
        }
    }

    async function testWebhook() {
        if (!settings?.webhook_url) { errorMsg = 'Webhook URL is required'; return; }
        try {
            const res = await fetch(settings.webhook_url, { method: 'GET', mode: 'no-cors' });
            successMsg = 'Webhook endpoint is reachable!';
            setTimeout(() => successMsg = '', 3000);
        } catch (e: any) {
            errorMsg = 'Webhook endpoint unreachable: ' + e.message;
        }
    }

    function getSelectedAccount(): WAAccount | undefined {
        return accounts.find(a => a.id === selectedAccountId);
    }
</script>

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
    <!-- Header with Tabs -->
    <div class="bg-white border-b border-slate-200 px-6 py-4 flex items-center justify-between shadow-sm">
        <div class="flex items-center gap-3">
            <span class="text-2xl">⚙️</span>
            <h2 class="text-lg font-black text-slate-800 uppercase tracking-wide">{$t('nav.whatsappSettings')}</h2>
            {#if accounts.length > 1}
                <select bind:value={selectedAccountId} on:change={loadSettings}
                    class="px-3 py-1.5 bg-slate-100 border border-slate-200 rounded-xl text-xs font-bold">
                    {#each accounts as acc}
                        <option value={acc.id}>{acc.display_name || acc.phone_number}</option>
                    {/each}
                </select>
            {/if}
        </div>
        <div class="flex gap-2 bg-slate-100 p-1.5 rounded-2xl border border-slate-200/50 shadow-inner">
            {#each tabs as tab}
                <button
                    class="group relative flex items-center gap-2 px-4 py-2 text-[10px] font-black uppercase tracking-wide transition-all duration-500 rounded-xl overflow-hidden
                    {activeTab === tab.id
                        ? 'bg-emerald-600 text-white shadow-lg shadow-emerald-200 scale-[1.02]'
                        : 'text-slate-500 hover:bg-white hover:text-slate-800 hover:shadow-md'}"
                    on:click={() => activeTab = tab.id}
                >
                    <span class="text-sm">{tab.icon}</span>
                    <span class="relative z-10">{tab.label}</span>
                </button>
            {/each}
        </div>
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
            {:else if accounts.length === 0}
                <div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-12 text-center border-dashed border-2 border-slate-200">
                    <div class="text-5xl mb-4">📱</div>
                    <p class="text-slate-600 font-semibold text-lg">{$t('whatsapp.settings.noAccount')}</p>
                    <p class="text-slate-400 text-sm mt-2">{$t('whatsapp.settings.connectFirst')}</p>
                </div>
            {:else if settings}
                {#if successMsg}
                    <div class="bg-emerald-50 border border-emerald-200 rounded-2xl p-3 mb-6 text-center text-emerald-700 text-sm font-semibold">
                        ✅ {successMsg}
                    </div>
                {/if}
                {#if errorMsg}
                    <div class="bg-red-50 border border-red-200 rounded-2xl p-3 mb-6 text-center text-red-700 text-sm font-semibold">
                        ❌ {errorMsg}
                        <button class="ml-2 underline text-xs" on:click={() => errorMsg = ''}>dismiss</button>
                    </div>
                {/if}

                <div class="bg-white/60 backdrop-blur-xl rounded-[2rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-8">
                    <!-- Business Profile Tab -->
                    {#if activeTab === 'profile'}
                        <h3 class="text-lg font-black text-slate-800 mb-6 flex items-center gap-2"><span>🏢</span> Business Profile</h3>
                        <div class="grid grid-cols-2 gap-5">
                            <div>
                                <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">Business Name</label>
                                <input type="text" bind:value={settings.business_name} placeholder="Your Business Name"
                                    class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all" />
                            </div>
                            <div>
                                <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">Category</label>
                                <select bind:value={settings.business_category}
                                    class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500">
                                    <option value="">Select Category</option>
                                    <option value="RETAIL">Retail</option>
                                    <option value="RESTAURANT">Restaurant</option>
                                    <option value="ECOMMERCE">E-Commerce</option>
                                    <option value="EDUCATION">Education</option>
                                    <option value="HEALTH">Health</option>
                                    <option value="AUTOMOTIVE">Automotive</option>
                                    <option value="BEAUTY">Beauty & Spa</option>
                                    <option value="OTHER">Other</option>
                                </select>
                            </div>
                            <div class="col-span-2">
                                <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">Description</label>
                                <textarea bind:value={settings.business_description} rows="3" placeholder="Describe your business..."
                                    class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent resize-none"></textarea>
                            </div>
                            <div class="col-span-2">
                                <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">Address</label>
                                <input type="text" bind:value={settings.business_address} placeholder="Business Address"
                                    class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all" />
                            </div>
                            <div>
                                <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">Email</label>
                                <input type="email" bind:value={settings.business_email} placeholder="info@business.com"
                                    class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all" />
                            </div>
                            <div>
                                <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">Website</label>
                                <input type="url" bind:value={settings.business_website} placeholder="https://www.business.com"
                                    class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all" />
                            </div>
                            <div>
                                <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">About Text</label>
                                <input type="text" bind:value={settings.about_text} placeholder="Short about text for WhatsApp profile"
                                    class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all" />
                            </div>
                            <div>
                                <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">Profile Picture URL</label>
                                <input type="url" bind:value={settings.profile_picture_url} placeholder="https://..."
                                    class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all" />
                            </div>
                        </div>

                    <!-- Webhook Tab -->
                    {:else if activeTab === 'webhook'}
                        <h3 class="text-lg font-black text-slate-800 mb-6 flex items-center gap-2"><span>🔗</span> Webhook Configuration</h3>
                        <div class="space-y-5">
                            <div>
                                <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">Webhook URL</label>
                                <input type="url" bind:value={settings.webhook_url} placeholder="https://your-server.com/webhook/whatsapp"
                                    class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all font-mono" />
                            </div>
                            <div>
                                <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">Verify Token</label>
                                <input type="text" bind:value={settings.webhook_verify_token} placeholder="Your webhook verification token"
                                    class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all font-mono" />
                            </div>
                            <div class="flex items-center justify-between p-4 bg-slate-50 rounded-xl">
                                <div>
                                    <p class="text-sm font-bold text-slate-700">Webhook Active</p>
                                    <p class="text-xs text-slate-500">Enable to receive incoming messages</p>
                                </div>
                                <button class="relative w-12 h-6 rounded-full transition-colors duration-300 {settings.webhook_active ? 'bg-emerald-500' : 'bg-slate-300'}"
                                    on:click={() => settings && (settings.webhook_active = !settings.webhook_active)}>
                                    <span class="absolute top-0.5 {settings.webhook_active ? 'right-0.5' : 'left-0.5'} w-5 h-5 bg-white rounded-full shadow-md transition-all duration-300"></span>
                                </button>
                            </div>
                            <button class="px-4 py-2.5 bg-blue-50 text-blue-700 text-xs font-bold rounded-xl hover:bg-blue-100 transition-all border border-blue-200"
                                on:click={testWebhook}>
                                🧪 Test Webhook Endpoint
                            </button>
                        </div>
                        <div class="mt-6 p-4 bg-amber-50 rounded-xl border border-amber-100">
                            <p class="text-xs text-amber-700 font-semibold">ℹ️ The webhook URL should point to your Supabase Edge Function: <code class="bg-amber-100 px-1.5 py-0.5 rounded">{'{SUPABASE_URL}'}/functions/v1/whatsapp-webhook</code></p>
                        </div>

                    <!-- Notifications Tab -->
                    {:else if activeTab === 'notifications'}
                        <h3 class="text-lg font-black text-slate-800 mb-6 flex items-center gap-2"><span>🔔</span> Notification Preferences</h3>
                        <div class="space-y-4">
                            {#each [
                                { key: 'notify_new_message', label: 'New Message', desc: 'Get notified when a customer sends a message', icon: '💬' },
                                { key: 'notify_bot_escalation', label: 'Bot Escalation', desc: 'Get notified when a bot escalates to human', icon: '🤖' },
                                { key: 'notify_broadcast_complete', label: 'Broadcast Complete', desc: 'Get notified when a broadcast finishes sending', icon: '📢' },
                                { key: 'notify_template_status', label: 'Template Status', desc: 'Get notified when a template is approved or rejected', icon: '📝' }
                            ] as item}
                                <div class="flex items-center justify-between p-4 bg-slate-50 rounded-xl hover:bg-slate-100 transition-colors">
                                    <div class="flex items-center gap-3">
                                        <span class="text-xl">{item.icon}</span>
                                        <div>
                                            <p class="text-sm font-bold text-slate-700">{item.label}</p>
                                            <p class="text-xs text-slate-500">{item.desc}</p>
                                        </div>
                                    </div>
                                    <button class="relative w-12 h-6 rounded-full transition-colors duration-300 {settings[item.key] ? 'bg-emerald-500' : 'bg-slate-300'}"
                                        on:click={() => settings && (settings[item.key] = !settings[item.key])}>
                                        <span class="absolute top-0.5 {settings[item.key] ? 'right-0.5' : 'left-0.5'} w-5 h-5 bg-white rounded-full shadow-md transition-all duration-300"></span>
                                    </button>
                                </div>
                            {/each}
                        </div>

                    <!-- Business Hours Tab -->
                    {:else if activeTab === 'hours'}
                        <h3 class="text-lg font-black text-slate-800 mb-6 flex items-center gap-2"><span>🕐</span> Business Hours</h3>
                        <div class="space-y-3">
                            {#each Object.entries(dayLabels) as [day, label]}
                                <div class="flex items-center gap-4 p-4 bg-slate-50 rounded-xl">
                                    <button class="relative w-10 h-5 rounded-full transition-colors duration-300 {settings.business_hours[day]?.open ? 'bg-emerald-500' : 'bg-slate-300'}"
                                        on:click={() => { if (settings) settings.business_hours[day].open = !settings.business_hours[day].open; settings = settings; }}>
                                        <span class="absolute top-0.5 {settings.business_hours[day]?.open ? 'right-0.5' : 'left-0.5'} w-4 h-4 bg-white rounded-full shadow-sm transition-all duration-300"></span>
                                    </button>
                                    <span class="w-28 text-sm font-bold text-slate-700">{label}</span>
                                    {#if settings.business_hours[day]?.open}
                                        <input type="time" bind:value={settings.business_hours[day].start}
                                            class="px-3 py-1.5 bg-white border border-slate-200 rounded-lg text-sm focus:ring-2 focus:ring-emerald-500" />
                                        <span class="text-slate-400 text-sm">to</span>
                                        <input type="time" bind:value={settings.business_hours[day].end}
                                            class="px-3 py-1.5 bg-white border border-slate-200 rounded-lg text-sm focus:ring-2 focus:ring-emerald-500" />
                                    {:else}
                                        <span class="text-sm text-slate-400 italic">Closed</span>
                                    {/if}
                                </div>
                            {/each}
                        </div>
                        <div class="mt-6">
                            <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">Outside Business Hours Auto-Reply</label>
                            <textarea bind:value={settings.outside_hours_message} rows="3"
                                placeholder="Thank you for contacting us. We are currently closed. Our business hours are..."
                                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 resize-none"></textarea>
                        </div>

                    <!-- Defaults Tab -->
                    {:else if activeTab === 'defaults'}
                        <h3 class="text-lg font-black text-slate-800 mb-6 flex items-center gap-2"><span>⚙️</span> Default Settings</h3>
                        <div class="space-y-5">
                            <div>
                                <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">Default Reply Language</label>
                                <select bind:value={settings.default_language}
                                    class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500">
                                    <option value="en">English</option>
                                    <option value="ar">Arabic (العربية)</option>
                                    <option value="auto">Auto-detect</option>
                                </select>
                            </div>

                            <div class="mt-8 p-5 bg-slate-50 rounded-xl border border-slate-200">
                                <h4 class="text-sm font-bold text-slate-700 mb-3">API Information (Read-Only)</h4>
                                {#if getSelectedAccount()}
                                    <div class="grid grid-cols-2 gap-4">
                                        <div>
                                            <span class="text-[10px] font-bold text-slate-400 uppercase">Graph API Version</span>
                                            <p class="text-xs text-slate-600 font-mono mt-0.5">v22.0</p>
                                        </div>
                                        <div>
                                            <span class="text-[10px] font-bold text-slate-400 uppercase">Phone Number</span>
                                            <p class="text-xs text-slate-600 font-mono mt-0.5">{getSelectedAccount()?.phone_number || '—'}</p>
                                        </div>
                                        <div>
                                            <span class="text-[10px] font-bold text-slate-400 uppercase">Phone Number ID</span>
                                            <p class="text-xs text-slate-600 font-mono mt-0.5">{getSelectedAccount()?.phone_number_id || '—'}</p>
                                        </div>
                                        <div>
                                            <span class="text-[10px] font-bold text-slate-400 uppercase">Display Name</span>
                                            <p class="text-xs text-slate-600 font-mono mt-0.5">{getSelectedAccount()?.display_name || '—'}</p>
                                        </div>
                                    </div>
                                {/if}
                            </div>
                        </div>
                    {/if}

                    <!-- Save Button -->
                    <div class="mt-8 flex justify-end">
                        <button
                            class="px-6 py-3 bg-emerald-600 text-white text-xs font-bold uppercase tracking-wide rounded-xl hover:bg-emerald-700 transition-all shadow-lg shadow-emerald-200 hover:scale-[1.02] disabled:opacity-50"
                            on:click={saveSettings}
                            disabled={saving}
                        >
                            {saving ? '⏳ Saving...' : '💾 Save Settings'}
                        </button>
                    </div>
                </div>
            {/if}
        </div>
    </div>
</div>
