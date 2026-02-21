<script lang="ts">
    import { onMount } from 'svelte';
    import { _ as t, locale } from '$lib/i18n';

    interface WAAccount {
        id: string;
        phone_number: string;
        display_name: string;
        phone_number_id: string;
        access_token: string;
        waba_id: string;
        is_default: boolean;
        status: string;
    }

    interface MetaProfile {
        about: string;
        address: string;
        description: string;
        email: string;
        vertical: string;
        websites: string[];
        profile_picture_url: string;
    }

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
        auto_reply_enabled: boolean;
    }

    const tabs = [
        { id: 'profile', label: 'Business Profile', icon: '🏢', color: 'green' },
        { id: 'hours', label: 'Business Hours', icon: '🕐', color: 'green' },
        { id: 'webhook', label: 'Webhook', icon: '🔗', color: 'green' },
        { id: 'notifications', label: 'Notifications', icon: '🔔', color: 'green' },
        { id: 'defaults', label: 'Defaults', icon: '⚙️', color: 'green' }
    ];

    const categories = [
        { value: '', label: 'Select Category' },
        { value: 'RETAIL', label: 'Retail' },
        { value: 'RESTAURANT', label: 'Restaurant' },
        { value: 'ECOMMERCE', label: 'E-Commerce' },
        { value: 'EDUCATION', label: 'Education' },
        { value: 'HEALTH', label: 'Health' },
        { value: 'AUTOMOTIVE', label: 'Automotive' },
        { value: 'BEAUTY', label: 'Beauty & Spa' },
        { value: 'PROF_SERVICES', label: 'Professional Services' },
        { value: 'TRAVEL', label: 'Travel & Hospitality' },
        { value: 'OTHER', label: 'Other' }
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

    let supabase: any = null;
    let loading = true;
    let saving = false;
    let fetchingProfile = false;
    let uploadingPhoto = false;
    let updatingProfile = false;
    let activeTab = 'profile';
    let accounts: WAAccount[] = [];
    let selectedAccountId = '';
    let settings: WASettings | null = null;
    let metaProfile: MetaProfile | null = null;
    let successMsg = '';
    let errorMsg = '';
    let fileInput: HTMLInputElement;

    function getSelectedAccount(): WAAccount | undefined {
        return accounts.find(a => a.id === selectedAccountId);
    }

    onMount(async () => {
        const mod = await import('$lib/utils/supabase');
        supabase = mod.supabase;
        await loadAccounts();
    });

    async function loadAccounts() {
        try {
            const { data } = await supabase
                .from('wa_accounts')
                .select('id, phone_number, display_name, phone_number_id, access_token, waba_id, is_default, status')
                .eq('status', 'connected')
                .order('is_default', { ascending: false });
            accounts = data || [];
            if (accounts.length > 0) {
                selectedAccountId = accounts[0].id;
                await loadSettings();
                await fetchMetaProfile();
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

    async function fetchMetaProfile() {
        const account = getSelectedAccount();
        if (!account) return;
        fetchingProfile = true;
        errorMsg = '';
        try {
            const res = await fetch(
                `https://graph.facebook.com/v22.0/${account.phone_number_id}/whatsapp_business_profile?fields=about,address,description,email,profile_picture_url,websites,vertical`,
                { headers: { Authorization: `Bearer ${account.access_token}` } }
            );
            const json = await res.json();
            if (!res.ok) throw new Error(json.error?.message || 'Failed to fetch profile');
            
            const profileData = json.data?.[0] || json;
            metaProfile = {
                about: profileData.about || '',
                address: profileData.address || '',
                description: profileData.description || '',
                email: profileData.email || '',
                vertical: profileData.vertical || '',
                websites: profileData.websites || [],
                profile_picture_url: profileData.profile_picture_url || ''
            };

            if (settings) {
                if (metaProfile.about) settings.about_text = metaProfile.about;
                if (metaProfile.address) settings.business_address = metaProfile.address;
                if (metaProfile.description) settings.business_description = metaProfile.description;
                if (metaProfile.email) settings.business_email = metaProfile.email;
                if (metaProfile.vertical) settings.business_category = metaProfile.vertical;
                if (metaProfile.websites?.length) settings.business_website = metaProfile.websites[0];
                if (metaProfile.profile_picture_url) settings.profile_picture_url = metaProfile.profile_picture_url;
            }
            successMsg = '✅ Profile fetched from Meta successfully';
            setTimeout(() => successMsg = '', 3000);
        } catch (e: any) {
            errorMsg = 'Meta API: ' + e.message;
        } finally {
            fetchingProfile = false;
        }
    }

    async function updateMetaProfile() {
        const account = getSelectedAccount();
        if (!account || !settings) return;
        updatingProfile = true;
        errorMsg = '';
        try {
            const body: any = { messaging_product: 'whatsapp' };
            if (settings.about_text) body.about = settings.about_text;
            if (settings.business_address) body.address = settings.business_address;
            if (settings.business_description) body.description = settings.business_description;
            if (settings.business_email) body.email = settings.business_email;
            if (settings.business_category) body.vertical = settings.business_category;
            if (settings.business_website) body.websites = [settings.business_website];

            const res = await fetch(
                `https://graph.facebook.com/v22.0/${account.phone_number_id}/whatsapp_business_profile`,
                {
                    method: 'POST',
                    headers: {
                        Authorization: `Bearer ${account.access_token}`,
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify(body)
                }
            );
            const json = await res.json();
            if (!res.ok) throw new Error(json.error?.message || 'Failed to update profile');
            
            successMsg = '✅ Profile updated on Meta WhatsApp!';
            setTimeout(() => successMsg = '', 3000);
            await saveSettings(true);
            await fetchMetaProfile();
        } catch (e: any) {
            errorMsg = 'Meta API: ' + e.message;
        } finally {
            updatingProfile = false;
        }
    }

    async function uploadProfilePhoto() {
        const account = getSelectedAccount();
        if (!account || !fileInput?.files?.length) return;
        
        const file = fileInput.files[0];
        if (!file.type.startsWith('image/')) {
            errorMsg = 'Please select an image file (JPEG or PNG)';
            return;
        }
        if (file.size > 5 * 1024 * 1024) {
            errorMsg = 'Image must be under 5MB';
            return;
        }

        uploadingPhoto = true;
        errorMsg = '';
        try {
            const formData = new FormData();
            formData.append('messaging_product', 'whatsapp');
            formData.append('file', file);
            formData.append('type', file.type);

            const uploadRes = await fetch(
                `https://graph.facebook.com/v22.0/${account.phone_number_id}/media`,
                {
                    method: 'POST',
                    headers: { Authorization: `Bearer ${account.access_token}` },
                    body: formData
                }
            );
            const uploadJson = await uploadRes.json();
            if (!uploadRes.ok) throw new Error(uploadJson.error?.message || 'Failed to upload image');

            const mediaId = uploadJson.id;

            const profileRes = await fetch(
                `https://graph.facebook.com/v22.0/${account.phone_number_id}/whatsapp_business_profile`,
                {
                    method: 'POST',
                    headers: {
                        Authorization: `Bearer ${account.access_token}`,
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({
                        messaging_product: 'whatsapp',
                        profile_picture_handle: mediaId
                    })
                }
            );
            const profileJson = await profileRes.json();
            if (!profileRes.ok) throw new Error(profileJson.error?.message || 'Failed to set profile picture');

            successMsg = '✅ Profile picture uploaded to WhatsApp!';
            setTimeout(() => successMsg = '', 3000);
            await fetchMetaProfile();
        } catch (e: any) {
            errorMsg = 'Upload: ' + e.message;
        } finally {
            uploadingPhoto = false;
            if (fileInput) fileInput.value = '';
        }
    }

    async function saveSettings(silent = false) {
        if (!settings) return;
        saving = true;
        if (!silent) { successMsg = ''; errorMsg = ''; }
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
                    auto_reply_enabled: settings.auto_reply_enabled,
                    updated_at: new Date().toISOString()
                })
                .eq('id', settings.id);
            if (err) throw err;
            if (!silent) {
                successMsg = '✅ Settings saved to database!';
                setTimeout(() => successMsg = '', 3000);
            }
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
            successMsg = '✅ Webhook endpoint is reachable!';
            setTimeout(() => successMsg = '', 3000);
        } catch (e: any) {
            errorMsg = 'Webhook unreachable: ' + e.message;
        }
    }

    async function onAccountChange() {
        metaProfile = null;
        await loadSettings();
        await fetchMetaProfile();
    }
</script>

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
    <!-- Header - ShiftAndDayOff style -->
    <div class="bg-white border-b border-slate-200 px-6 py-4 flex items-center justify-between shadow-sm">
        <div class="flex items-center gap-3">
            {#if accounts.length > 1}
                <select bind:value={selectedAccountId} on:change={onAccountChange}
                    class="px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-xs font-bold focus:outline-none focus:ring-2 focus:ring-emerald-500">
                    {#each accounts as acc}
                        <option value={acc.id}>{acc.display_name || acc.phone_number}</option>
                    {/each}
                </select>
            {/if}
        </div>
        <div class="flex gap-2 bg-slate-100 p-1.5 rounded-2xl border border-slate-200/50 shadow-inner">
            {#each tabs as tab}
                <button
                    class="group relative flex items-center gap-2.5 px-5 py-2.5 text-[10px] font-black uppercase tracking-wide transition-all duration-500 rounded-xl overflow-hidden
                    {activeTab === tab.id
                        ? 'bg-emerald-600 text-white shadow-lg shadow-emerald-200 scale-[1.02]'
                        : 'text-slate-500 hover:bg-white hover:text-slate-800 hover:shadow-md'}"
                    on:click={() => activeTab = tab.id}
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

    {#if successMsg || errorMsg}
        <div class="px-6 pt-3">
            {#if successMsg}
                <div class="bg-emerald-50 border border-emerald-200 rounded-xl p-3 text-center text-emerald-700 text-xs font-bold">
                    {successMsg}
                </div>
            {/if}
            {#if errorMsg}
                <div class="bg-red-50 border border-red-200 rounded-xl p-3 text-center text-red-700 text-xs font-bold">
                    ❌ {errorMsg}
                    <button class="ml-2 underline text-[10px]" on:click={() => errorMsg = ''}>dismiss</button>
                </div>
            {/if}
        </div>
    {/if}

    <!-- Main Content -->
    <div class="flex-1 p-8 relative overflow-y-auto bg-[radial-gradient(ellipse_at_top_right,_var(--tw-gradient-stops))] from-white via-slate-50/50 to-slate-100/50">
        <div class="absolute top-0 right-0 w-[500px] h-[500px] bg-emerald-100/20 rounded-full blur-[120px] -mr-64 -mt-64 animate-pulse"></div>
        <div class="absolute bottom-0 left-0 w-[500px] h-[500px] bg-green-100/20 rounded-full blur-[120px] -ml-64 -mb-64 animate-pulse" style="animation-delay: 2s;"></div>

        <div class="relative max-w-5xl mx-auto">
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
                    <p class="text-slate-600 font-semibold text-lg">No WhatsApp account connected</p>
                    <p class="text-slate-400 text-sm mt-2">Connect a WhatsApp account first in the Accounts tab</p>
                </div>
            {:else if settings}

                <!-- BUSINESS PROFILE TAB -->
                {#if activeTab === 'profile'}
                    <div class="bg-white/60 backdrop-blur-xl rounded-[2rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden">
                        <!-- Profile Header -->
                        <div class="bg-gradient-to-r from-emerald-600 to-green-600 p-6 flex items-center gap-6">
                            <div class="relative group">
                                {#if metaProfile?.profile_picture_url}
                                    <img src={metaProfile.profile_picture_url} alt="Profile" 
                                        class="w-24 h-24 rounded-2xl object-cover border-4 border-white/30 shadow-xl" />
                                {:else}
                                    <div class="w-24 h-24 rounded-2xl bg-white/20 border-4 border-white/30 flex items-center justify-center text-4xl shadow-xl">🏢</div>
                                {/if}
                                <input type="file" accept="image/jpeg,image/png" bind:this={fileInput} on:change={uploadProfilePhoto} class="hidden" />
                                <button class="absolute -bottom-2 -right-2 w-8 h-8 bg-white rounded-full shadow-lg flex items-center justify-center text-sm hover:scale-110 transition-transform disabled:opacity-50"
                                    on:click={() => fileInput?.click()} disabled={uploadingPhoto}>
                                    {uploadingPhoto ? '⏳' : '📷'}
                                </button>
                            </div>
                            <div class="flex-1">
                                <h3 class="text-white font-black text-xl">{settings.business_name || getSelectedAccount()?.display_name || 'Business Name'}</h3>
                                <p class="text-white/70 text-sm mt-1">{getSelectedAccount()?.phone_number || ''}</p>
                                <p class="text-white/50 text-xs font-mono mt-1">ID: {getSelectedAccount()?.phone_number_id || ''}</p>
                            </div>
                            <div class="flex gap-2">
                                <button class="group flex items-center gap-2 px-4 py-2.5 bg-white/20 hover:bg-white/30 text-white text-[10px] font-black uppercase tracking-wide rounded-xl transition-all duration-300 backdrop-blur-sm border border-white/20 disabled:opacity-50"
                                    on:click={fetchMetaProfile} disabled={fetchingProfile}>
                                    <span class="text-sm transition-transform duration-300 group-hover:rotate-12">{fetchingProfile ? '⏳' : '🔄'}</span>
                                    {fetchingProfile ? 'Fetching...' : 'Fetch from Meta'}
                                </button>
                                <button class="group flex items-center gap-2 px-4 py-2.5 bg-white text-emerald-700 text-[10px] font-black uppercase tracking-wide rounded-xl transition-all duration-300 shadow-lg hover:scale-[1.02] disabled:opacity-50"
                                    on:click={updateMetaProfile} disabled={updatingProfile}>
                                    <span class="text-sm transition-transform duration-300 group-hover:rotate-12">{updatingProfile ? '⏳' : '🚀'}</span>
                                    {updatingProfile ? 'Updating...' : 'Push to Meta'}
                                </button>
                            </div>
                        </div>

                        <!-- Profile Fields Table -->
                        <div class="p-6">
                            <table class="w-full">
                                <thead>
                                    <tr class="border-b-2 border-slate-100">
                                        <th class="px-4 py-3 text-left text-[10px] font-black uppercase tracking-wider text-slate-400 w-[200px]">Field</th>
                                        <th class="px-4 py-3 text-left text-[10px] font-black uppercase tracking-wider text-slate-400">Value</th>
                                        <th class="px-4 py-3 text-center text-[10px] font-black uppercase tracking-wider text-slate-400 w-[100px]">Meta Sync</th>
                                    </tr>
                                </thead>
                                <tbody class="divide-y divide-slate-100">
                                    <tr class="hover:bg-emerald-50/30 transition-colors">
                                        <td class="px-4 py-3"><span class="text-xs font-bold text-slate-700 flex items-center gap-2">🏷️ Business Name</span></td>
                                        <td class="px-4 py-3">
                                            <input type="text" bind:value={settings.business_name} placeholder="Your Business Name"
                                                class="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all" />
                                        </td>
                                        <td class="px-4 py-3 text-center"><span class="text-slate-300 text-xs">Local only</span></td>
                                    </tr>
                                    <tr class="hover:bg-emerald-50/30 transition-colors">
                                        <td class="px-4 py-3"><span class="text-xs font-bold text-slate-700 flex items-center gap-2">📝 About</span></td>
                                        <td class="px-4 py-3">
                                            <input type="text" bind:value={settings.about_text} placeholder="Short about text for WhatsApp"
                                                class="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all" />
                                        </td>
                                        <td class="px-4 py-3 text-center">
                                            {#if metaProfile?.about}<span class="text-emerald-500 text-sm" title="Synced: {metaProfile.about}">✅</span>{:else}<span class="text-slate-300 text-sm">—</span>{/if}
                                        </td>
                                    </tr>
                                    <tr class="hover:bg-emerald-50/30 transition-colors">
                                        <td class="px-4 py-3"><span class="text-xs font-bold text-slate-700 flex items-center gap-2">📋 Description</span></td>
                                        <td class="px-4 py-3">
                                            <textarea bind:value={settings.business_description} rows="2" placeholder="Describe your business..."
                                                class="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent resize-none transition-all"></textarea>
                                        </td>
                                        <td class="px-4 py-3 text-center">
                                            {#if metaProfile?.description}<span class="text-emerald-500 text-sm" title="Synced">✅</span>{:else}<span class="text-slate-300 text-sm">—</span>{/if}
                                        </td>
                                    </tr>
                                    <tr class="hover:bg-emerald-50/30 transition-colors">
                                        <td class="px-4 py-3"><span class="text-xs font-bold text-slate-700 flex items-center gap-2">📍 Address</span></td>
                                        <td class="px-4 py-3">
                                            <input type="text" bind:value={settings.business_address} placeholder="Business Address"
                                                class="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all" />
                                        </td>
                                        <td class="px-4 py-3 text-center">
                                            {#if metaProfile?.address}<span class="text-emerald-500 text-sm" title="Synced: {metaProfile.address}">✅</span>{:else}<span class="text-slate-300 text-sm">—</span>{/if}
                                        </td>
                                    </tr>
                                    <tr class="hover:bg-emerald-50/30 transition-colors">
                                        <td class="px-4 py-3"><span class="text-xs font-bold text-slate-700 flex items-center gap-2">📧 Email</span></td>
                                        <td class="px-4 py-3">
                                            <input type="email" bind:value={settings.business_email} placeholder="info@business.com"
                                                class="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all" />
                                        </td>
                                        <td class="px-4 py-3 text-center">
                                            {#if metaProfile?.email}<span class="text-emerald-500 text-sm" title="Synced: {metaProfile.email}">✅</span>{:else}<span class="text-slate-300 text-sm">—</span>{/if}
                                        </td>
                                    </tr>
                                    <tr class="hover:bg-emerald-50/30 transition-colors">
                                        <td class="px-4 py-3"><span class="text-xs font-bold text-slate-700 flex items-center gap-2">🌐 Website</span></td>
                                        <td class="px-4 py-3">
                                            <input type="url" bind:value={settings.business_website} placeholder="https://www.business.com"
                                                class="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all" />
                                        </td>
                                        <td class="px-4 py-3 text-center">
                                            {#if metaProfile?.websites?.length}<span class="text-emerald-500 text-sm" title="Synced: {metaProfile.websites.join(', ')}">✅</span>{:else}<span class="text-slate-300 text-sm">—</span>{/if}
                                        </td>
                                    </tr>
                                    <tr class="hover:bg-emerald-50/30 transition-colors">
                                        <td class="px-4 py-3"><span class="text-xs font-bold text-slate-700 flex items-center gap-2">🏪 Category</span></td>
                                        <td class="px-4 py-3">
                                            <select bind:value={settings.business_category}
                                                class="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500">
                                                {#each categories as cat}
                                                    <option value={cat.value}>{cat.label}</option>
                                                {/each}
                                            </select>
                                        </td>
                                        <td class="px-4 py-3 text-center">
                                            {#if metaProfile?.vertical}<span class="text-emerald-500 text-sm" title="Synced: {metaProfile.vertical}">✅</span>{:else}<span class="text-slate-300 text-sm">—</span>{/if}
                                        </td>
                                    </tr>
                                </tbody>
                            </table>
                            <div class="mt-6 flex justify-end">
                                <button class="group flex items-center gap-2 px-6 py-3 bg-emerald-600 text-white text-xs font-black uppercase tracking-wide rounded-xl hover:bg-emerald-700 transition-all shadow-lg shadow-emerald-200 hover:scale-[1.02] disabled:opacity-50"
                                    on:click={() => saveSettings()} disabled={saving}>
                                    <span class="text-sm transition-transform duration-300 group-hover:rotate-12">{saving ? '⏳' : '💾'}</span>
                                    {saving ? 'Saving...' : 'Save to Database'}
                                </button>
                            </div>
                        </div>
                    </div>

                <!-- BUSINESS HOURS TAB -->
                {:else if activeTab === 'hours'}
                    <div class="bg-white/60 backdrop-blur-xl rounded-[2rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden">
                        <div class="p-6">
                            <h3 class="text-lg font-black text-slate-800 mb-6 flex items-center gap-2"><span>🕐</span> Business Hours</h3>
                            <table class="w-full">
                                <thead>
                                    <tr class="border-b-2 border-slate-100">
                                        <th class="px-4 py-3 text-left text-[10px] font-black uppercase tracking-wider text-slate-400 w-[80px]">Status</th>
                                        <th class="px-4 py-3 text-left text-[10px] font-black uppercase tracking-wider text-slate-400 w-[150px]">Day</th>
                                        <th class="px-4 py-3 text-center text-[10px] font-black uppercase tracking-wider text-slate-400">Open Time</th>
                                        <th class="px-4 py-3 text-center text-[10px] font-black uppercase tracking-wider text-slate-400">Close Time</th>
                                        <th class="px-4 py-3 text-center text-[10px] font-black uppercase tracking-wider text-slate-400 w-[100px]">Hours</th>
                                    </tr>
                                </thead>
                                <tbody class="divide-y divide-slate-100">
                                    {#each Object.entries(dayLabels) as [day, label], i}
                                        <tr class="hover:bg-emerald-50/30 transition-colors {i % 2 === 0 ? 'bg-slate-50/20' : ''}">
                                            <td class="px-4 py-3">
                                                <button class="relative w-11 h-6 rounded-full transition-colors duration-300 {settings.business_hours[day]?.open ? 'bg-emerald-500' : 'bg-slate-300'}"
                                                    on:click={() => { if (settings) { settings.business_hours[day].open = !settings.business_hours[day].open; settings = settings; } }}>
                                                    <span class="absolute top-0.5 {settings.business_hours[day]?.open ? 'right-0.5' : 'left-0.5'} w-5 h-5 bg-white rounded-full shadow-md transition-all duration-300"></span>
                                                </button>
                                            </td>
                                            <td class="px-4 py-3"><span class="text-sm font-bold text-slate-700">{label}</span></td>
                                            <td class="px-4 py-3 text-center">
                                                {#if settings.business_hours[day]?.open}
                                                    <input type="time" bind:value={settings.business_hours[day].start}
                                                        class="px-3 py-1.5 bg-white border border-slate-200 rounded-lg text-sm focus:ring-2 focus:ring-emerald-500 text-center" />
                                                {:else}<span class="text-slate-300 text-sm italic">—</span>{/if}
                                            </td>
                                            <td class="px-4 py-3 text-center">
                                                {#if settings.business_hours[day]?.open}
                                                    <input type="time" bind:value={settings.business_hours[day].end}
                                                        class="px-3 py-1.5 bg-white border border-slate-200 rounded-lg text-sm focus:ring-2 focus:ring-emerald-500 text-center" />
                                                {:else}<span class="text-slate-300 text-sm italic">—</span>{/if}
                                            </td>
                                            <td class="px-4 py-3 text-center">
                                                {#if settings.business_hours[day]?.open}
                                                    {@const start = settings.business_hours[day].start?.split(':').map(Number) || [0,0]}
                                                    {@const end = settings.business_hours[day].end?.split(':').map(Number) || [0,0]}
                                                    {@const hrs = ((end[0]*60 + end[1]) - (start[0]*60 + start[1])) / 60}
                                                    <span class="inline-flex items-center px-2 py-0.5 bg-emerald-100 text-emerald-700 text-[10px] font-bold rounded-full">{hrs.toFixed(1)}h</span>
                                                {:else}
                                                    <span class="inline-flex items-center px-2 py-0.5 bg-red-100 text-red-600 text-[10px] font-bold rounded-full">Closed</span>
                                                {/if}
                                            </td>
                                        </tr>
                                    {/each}
                                </tbody>
                            </table>
                            <div class="mt-6">
                                <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">Outside Business Hours Auto-Reply</label>
                                <textarea bind:value={settings.outside_hours_message} rows="3"
                                    placeholder="Thank you for contacting us. We are currently closed..."
                                    class="w-full px-4 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 resize-none"></textarea>
                            </div>
                            <div class="mt-6 flex justify-end">
                                <button class="group flex items-center gap-2 px-6 py-3 bg-emerald-600 text-white text-xs font-black uppercase tracking-wide rounded-xl hover:bg-emerald-700 transition-all shadow-lg shadow-emerald-200 hover:scale-[1.02] disabled:opacity-50"
                                    on:click={() => saveSettings()} disabled={saving}>
                                    <span class="text-sm transition-transform duration-300 group-hover:rotate-12">{saving ? '⏳' : '💾'}</span>
                                    {saving ? 'Saving...' : 'Save Hours'}
                                </button>
                            </div>
                        </div>
                    </div>

                <!-- WEBHOOK TAB -->
                {:else if activeTab === 'webhook'}
                    <div class="bg-white/60 backdrop-blur-xl rounded-[2rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden">
                        <div class="p-6">
                            <h3 class="text-lg font-black text-slate-800 mb-6 flex items-center gap-2"><span>🔗</span> Webhook Configuration</h3>
                            <table class="w-full">
                                <thead>
                                    <tr class="border-b-2 border-slate-100">
                                        <th class="px-4 py-3 text-left text-[10px] font-black uppercase tracking-wider text-slate-400 w-[200px]">Setting</th>
                                        <th class="px-4 py-3 text-left text-[10px] font-black uppercase tracking-wider text-slate-400">Value</th>
                                    </tr>
                                </thead>
                                <tbody class="divide-y divide-slate-100">
                                    <tr class="hover:bg-emerald-50/30 transition-colors">
                                        <td class="px-4 py-3"><span class="text-xs font-bold text-slate-700">🔗 Webhook URL</span></td>
                                        <td class="px-4 py-3">
                                            <input type="url" bind:value={settings.webhook_url} placeholder="https://your-server.com/webhook/whatsapp"
                                                class="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 font-mono transition-all" />
                                        </td>
                                    </tr>
                                    <tr class="hover:bg-emerald-50/30 transition-colors">
                                        <td class="px-4 py-3"><span class="text-xs font-bold text-slate-700">🔑 Verify Token</span></td>
                                        <td class="px-4 py-3">
                                            <input type="text" bind:value={settings.webhook_verify_token} placeholder="Your verify token"
                                                class="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 font-mono transition-all" />
                                        </td>
                                    </tr>
                                    <tr class="hover:bg-emerald-50/30 transition-colors">
                                        <td class="px-4 py-3"><span class="text-xs font-bold text-slate-700">⚡ Webhook Active</span></td>
                                        <td class="px-4 py-3">
                                            <div class="flex items-center gap-3">
                                                <button class="relative w-11 h-6 rounded-full transition-colors duration-300 {settings.webhook_active ? 'bg-emerald-500' : 'bg-slate-300'}"
                                                    on:click={() => settings && (settings.webhook_active = !settings.webhook_active)}>
                                                    <span class="absolute top-0.5 {settings.webhook_active ? 'right-0.5' : 'left-0.5'} w-5 h-5 bg-white rounded-full shadow-md transition-all duration-300"></span>
                                                </button>
                                                <span class="text-xs font-bold {settings.webhook_active ? 'text-emerald-600' : 'text-slate-400'}">
                                                    {settings.webhook_active ? 'Active' : 'Inactive'}
                                                </span>
                                            </div>
                                        </td>
                                    </tr>
                                </tbody>
                            </table>
                            <div class="mt-6 p-4 bg-amber-50 rounded-xl border border-amber-100">
                                <p class="text-xs text-amber-700 font-semibold">ℹ️ Webhook URL should point to: <code class="bg-amber-100 px-1.5 py-0.5 rounded text-[10px]">https://supabase.urbanaqura.com/functions/v1/whatsapp-webhook</code></p>
                            </div>
                            <div class="mt-6 flex justify-end gap-3">
                                <button class="group flex items-center gap-2 px-4 py-2.5 bg-blue-50 text-blue-700 text-xs font-bold rounded-xl hover:bg-blue-100 transition-all border border-blue-200"
                                    on:click={testWebhook}>
                                    <span class="text-sm transition-transform duration-300 group-hover:rotate-12">🧪</span>
                                    Test Webhook
                                </button>
                                <button class="group flex items-center gap-2 px-6 py-3 bg-emerald-600 text-white text-xs font-black uppercase tracking-wide rounded-xl hover:bg-emerald-700 transition-all shadow-lg shadow-emerald-200 hover:scale-[1.02] disabled:opacity-50"
                                    on:click={() => saveSettings()} disabled={saving}>
                                    <span class="text-sm transition-transform duration-300 group-hover:rotate-12">{saving ? '⏳' : '💾'}</span>
                                    {saving ? 'Saving...' : 'Save Webhook'}
                                </button>
                            </div>
                        </div>
                    </div>

                <!-- NOTIFICATIONS TAB -->
                {:else if activeTab === 'notifications'}
                    <div class="bg-white/60 backdrop-blur-xl rounded-[2rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden">
                        <div class="p-6">
                            <h3 class="text-lg font-black text-slate-800 mb-6 flex items-center gap-2"><span>🔔</span> Notification Preferences</h3>
                            <table class="w-full">
                                <thead>
                                    <tr class="border-b-2 border-slate-100">
                                        <th class="px-4 py-3 text-left text-[10px] font-black uppercase tracking-wider text-slate-400 w-[60px]">Icon</th>
                                        <th class="px-4 py-3 text-left text-[10px] font-black uppercase tracking-wider text-slate-400">Notification</th>
                                        <th class="px-4 py-3 text-left text-[10px] font-black uppercase tracking-wider text-slate-400">Description</th>
                                        <th class="px-4 py-3 text-center text-[10px] font-black uppercase tracking-wider text-slate-400 w-[100px]">Enabled</th>
                                    </tr>
                                </thead>
                                <tbody class="divide-y divide-slate-100">
                                    {#each [
                                        { key: 'notify_new_message', label: 'New Message', desc: 'Get notified when a customer sends a message', icon: '💬' },
                                        { key: 'notify_bot_escalation', label: 'Bot Escalation', desc: 'When a bot escalates to a human agent', icon: '🤖' },
                                        { key: 'notify_broadcast_complete', label: 'Broadcast Complete', desc: 'When a broadcast finishes sending', icon: '📢' },
                                        { key: 'notify_template_status', label: 'Template Status', desc: 'When a template is approved or rejected', icon: '📝' }
                                    ] as item, i}
                                        <tr class="hover:bg-emerald-50/30 transition-colors {i % 2 === 0 ? 'bg-slate-50/20' : ''}">
                                            <td class="px-4 py-3 text-center"><span class="text-xl">{item.icon}</span></td>
                                            <td class="px-4 py-3"><span class="text-sm font-bold text-slate-700">{item.label}</span></td>
                                            <td class="px-4 py-3"><span class="text-xs text-slate-500">{item.desc}</span></td>
                                            <td class="px-4 py-3 text-center">
                                                <button class="relative w-11 h-6 rounded-full transition-colors duration-300 {settings[item.key] ? 'bg-emerald-500' : 'bg-slate-300'}"
                                                    on:click={() => settings && (settings[item.key] = !settings[item.key])}>
                                                    <span class="absolute top-0.5 {settings[item.key] ? 'right-0.5' : 'left-0.5'} w-5 h-5 bg-white rounded-full shadow-md transition-all duration-300"></span>
                                                </button>
                                            </td>
                                        </tr>
                                    {/each}
                                    <tr class="hover:bg-emerald-50/30 transition-colors bg-slate-50/20">
                                        <td class="px-4 py-3 text-center"><span class="text-xl">🤖</span></td>
                                        <td class="px-4 py-3"><span class="text-sm font-bold text-slate-700">Auto Reply</span></td>
                                        <td class="px-4 py-3"><span class="text-xs text-slate-500">Automatically reply outside business hours</span></td>
                                        <td class="px-4 py-3 text-center">
                                            <button class="relative w-11 h-6 rounded-full transition-colors duration-300 {settings.auto_reply_enabled ? 'bg-emerald-500' : 'bg-slate-300'}"
                                                on:click={() => settings && (settings.auto_reply_enabled = !settings.auto_reply_enabled)}>
                                                <span class="absolute top-0.5 {settings.auto_reply_enabled ? 'right-0.5' : 'left-0.5'} w-5 h-5 bg-white rounded-full shadow-md transition-all duration-300"></span>
                                            </button>
                                        </td>
                                    </tr>
                                </tbody>
                            </table>
                            <div class="mt-6 flex justify-end">
                                <button class="group flex items-center gap-2 px-6 py-3 bg-emerald-600 text-white text-xs font-black uppercase tracking-wide rounded-xl hover:bg-emerald-700 transition-all shadow-lg shadow-emerald-200 hover:scale-[1.02] disabled:opacity-50"
                                    on:click={() => saveSettings()} disabled={saving}>
                                    <span class="text-sm transition-transform duration-300 group-hover:rotate-12">{saving ? '⏳' : '💾'}</span>
                                    {saving ? 'Saving...' : 'Save Notifications'}
                                </button>
                            </div>
                        </div>
                    </div>

                <!-- DEFAULTS TAB -->
                {:else if activeTab === 'defaults'}
                    <div class="bg-white/60 backdrop-blur-xl rounded-[2rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden">
                        <div class="p-6">
                            <h3 class="text-lg font-black text-slate-800 mb-6 flex items-center gap-2"><span>⚙️</span> Default Settings</h3>
                            <table class="w-full">
                                <thead>
                                    <tr class="border-b-2 border-slate-100">
                                        <th class="px-4 py-3 text-left text-[10px] font-black uppercase tracking-wider text-slate-400 w-[200px]">Setting</th>
                                        <th class="px-4 py-3 text-left text-[10px] font-black uppercase tracking-wider text-slate-400">Value</th>
                                    </tr>
                                </thead>
                                <tbody class="divide-y divide-slate-100">
                                    <tr class="hover:bg-emerald-50/30 transition-colors">
                                        <td class="px-4 py-3"><span class="text-xs font-bold text-slate-700">🌐 Default Language</span></td>
                                        <td class="px-4 py-3">
                                            <select bind:value={settings.default_language}
                                                class="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500">
                                                <option value="en">English</option>
                                                <option value="ar">Arabic (العربية)</option>
                                                <option value="auto">Auto-detect</option>
                                            </select>
                                        </td>
                                    </tr>
                                </tbody>
                            </table>
                            <div class="mt-8">
                                <h4 class="text-sm font-black text-slate-700 mb-4 uppercase tracking-wide">📡 API Information</h4>
                                <table class="w-full">
                                    <thead>
                                        <tr class="border-b-2 border-slate-100">
                                            <th class="px-4 py-3 text-left text-[10px] font-black uppercase tracking-wider text-slate-400 w-[200px]">Property</th>
                                            <th class="px-4 py-3 text-left text-[10px] font-black uppercase tracking-wider text-slate-400">Value</th>
                                        </tr>
                                    </thead>
                                    <tbody class="divide-y divide-slate-100">
                                        <tr class="bg-slate-50/30">
                                            <td class="px-4 py-3"><span class="text-xs font-bold text-slate-500">Graph API Version</span></td>
                                            <td class="px-4 py-3"><code class="text-xs text-slate-700 font-mono bg-slate-100 px-2 py-1 rounded">v22.0</code></td>
                                        </tr>
                                        <tr>
                                            <td class="px-4 py-3"><span class="text-xs font-bold text-slate-500">Phone Number</span></td>
                                            <td class="px-4 py-3"><code class="text-xs text-slate-700 font-mono bg-slate-100 px-2 py-1 rounded">{getSelectedAccount()?.phone_number || '—'}</code></td>
                                        </tr>
                                        <tr class="bg-slate-50/30">
                                            <td class="px-4 py-3"><span class="text-xs font-bold text-slate-500">Phone Number ID</span></td>
                                            <td class="px-4 py-3"><code class="text-xs text-slate-700 font-mono bg-slate-100 px-2 py-1 rounded">{getSelectedAccount()?.phone_number_id || '—'}</code></td>
                                        </tr>
                                        <tr>
                                            <td class="px-4 py-3"><span class="text-xs font-bold text-slate-500">WABA ID</span></td>
                                            <td class="px-4 py-3"><code class="text-xs text-slate-700 font-mono bg-slate-100 px-2 py-1 rounded">{getSelectedAccount()?.waba_id || '—'}</code></td>
                                        </tr>
                                        <tr class="bg-slate-50/30">
                                            <td class="px-4 py-3"><span class="text-xs font-bold text-slate-500">Display Name</span></td>
                                            <td class="px-4 py-3"><code class="text-xs text-slate-700 font-mono bg-slate-100 px-2 py-1 rounded">{getSelectedAccount()?.display_name || '—'}</code></td>
                                        </tr>
                                        <tr>
                                            <td class="px-4 py-3"><span class="text-xs font-bold text-slate-500">Status</span></td>
                                            <td class="px-4 py-3">
                                                <span class="inline-flex items-center px-2 py-0.5 text-[10px] font-bold rounded-full
                                                    {getSelectedAccount()?.status === 'connected' ? 'bg-emerald-100 text-emerald-700' : 'bg-red-100 text-red-700'}">
                                                    {getSelectedAccount()?.status === 'connected' ? '🟢 Connected' : '🔴 Disconnected'}
                                                </span>
                                            </td>
                                        </tr>
                                    </tbody>
                                </table>
                            </div>
                            <div class="mt-6 flex justify-end">
                                <button class="group flex items-center gap-2 px-6 py-3 bg-emerald-600 text-white text-xs font-black uppercase tracking-wide rounded-xl hover:bg-emerald-700 transition-all shadow-lg shadow-emerald-200 hover:scale-[1.02] disabled:opacity-50"
                                    on:click={() => saveSettings()} disabled={saving}>
                                    <span class="text-sm transition-transform duration-300 group-hover:rotate-12">{saving ? '⏳' : '💾'}</span>
                                    {saving ? 'Saving...' : 'Save Defaults'}
                                </button>
                            </div>
                        </div>
                    </div>
                {/if}
            {/if}
        </div>
    </div>
</div>
