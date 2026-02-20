<script lang="ts">
    import { onMount } from 'svelte';
    import { _ as t, locale } from '$lib/i18n';

    interface WATemplate {
        id: string;
        wa_account_id: string;
        meta_template_id: string;
        name: string;
        category: string;
        language: string;
        status: string;
        header_type: string;
        header_content: string;
        body_text: string;
        footer_text: string;
        buttons: any[];
        created_at: string;
        updated_at: string;
    }

    let supabase: any = null;
    let templates: WATemplate[] = [];
    let filteredTemplates: WATemplate[] = [];
    let loading = true;
    let error = '';
    let successMsg = '';
    let saving = false;
    let activeView = 'list'; // list, create, edit
    let searchQuery = '';
    let categoryFilter = 'all';
    let languageFilter = 'all';
    let accountId = '';
    let editingId: string | null = null;

    // Create/Edit form
    let form = {
        name: '',
        category: 'UTILITY',
        language: 'en',
        header_type: 'none',
        header_content: '',
        body_text: '',
        footer_text: '',
        buttons: [] as any[]
    };

    const categories = [
        { value: 'MARKETING', label: 'Marketing', icon: '📢' },
        { value: 'UTILITY', label: 'Utility', icon: '🔧' },
        { value: 'AUTHENTICATION', label: 'Authentication', icon: '🔐' }
    ];

    onMount(async () => {
        const mod = await import('$lib/utils/supabase');
        supabase = mod.supabase;
        await loadAccount();
    });

    async function loadAccount() {
        try {
            const { data } = await supabase
                .from('wa_accounts')
                .select('id')
                .eq('is_default', true)
                .single();
            if (data) {
                accountId = data.id;
                await loadTemplates();
            } else {
                loading = false;
            }
        } catch (e: any) {
            loading = false;
        }
    }

    async function loadTemplates() {
        loading = true;
        try {
            const { data, error: err } = await supabase
                .from('wa_templates')
                .select('*')
                .eq('wa_account_id', accountId)
                .neq('status', 'REJECTED')
                .order('created_at', { ascending: false });
            if (err) throw err;
            templates = data || [];
            applyFilters();
        } catch (e: any) {
            error = e.message;
        } finally {
            loading = false;
        }
    }

    function applyFilters() {
        let result = [...templates];
        if (searchQuery) {
            const q = searchQuery.toLowerCase();
            result = result.filter(t => t.name.toLowerCase().includes(q) || t.body_text?.toLowerCase().includes(q));
        }
        if (categoryFilter !== 'all') result = result.filter(t => t.category === categoryFilter);
        if (languageFilter !== 'all') result = result.filter(t => t.language === languageFilter);
        filteredTemplates = result;
    }

    $: searchQuery, categoryFilter, languageFilter, applyFilters();

    function startCreate() {
        activeView = 'create';
        editingId = null;
        form = { name: '', category: 'UTILITY', language: 'en', header_type: 'none', header_content: '', body_text: '', footer_text: '', buttons: [] };
    }

    function startEdit(template: WATemplate) {
        activeView = 'edit';
        editingId = template.id;
        form = {
            name: template.name,
            category: template.category,
            language: template.language,
            header_type: template.header_type || 'none',
            header_content: template.header_content || '',
            body_text: template.body_text || '',
            footer_text: template.footer_text || '',
            buttons: template.buttons ? [...template.buttons] : []
        };
    }

    function cancelForm() {
        activeView = 'list';
        editingId = null;
    }

    async function saveTemplate() {
        saving = true;
        error = '';
        try {
            if (!form.name) throw new Error('Template name is required');
            if (!form.body_text) throw new Error('Body text is required');

            const payload = {
                wa_account_id: accountId,
                name: form.name,
                category: form.category,
                language: form.language,
                status: 'PENDING',
                header_type: form.header_type,
                header_content: form.header_content,
                body_text: form.body_text,
                footer_text: form.footer_text,
                buttons: form.buttons,
                updated_at: new Date().toISOString()
            };

            if (editingId) {
                const { error: err } = await supabase.from('wa_templates').update(payload).eq('id', editingId);
                if (err) throw err;
            } else {
                const { error: err } = await supabase.from('wa_templates').insert(payload);
                if (err) throw err;
            }

            successMsg = editingId ? 'Template updated!' : 'Template created!';
            setTimeout(() => successMsg = '', 3000);
            activeView = 'list';
            editingId = null;
            await loadTemplates();
        } catch (e: any) {
            error = e.message;
        } finally {
            saving = false;
        }
    }

    async function duplicateTemplate(template: WATemplate) {
        try {
            const { error: err } = await supabase.from('wa_templates').insert({
                wa_account_id: accountId,
                name: template.name + '_copy',
                category: template.category,
                language: template.language,
                status: 'PENDING',
                header_type: template.header_type,
                header_content: template.header_content,
                body_text: template.body_text,
                footer_text: template.footer_text,
                buttons: template.buttons
            });
            if (err) throw err;
            successMsg = 'Template duplicated!';
            setTimeout(() => successMsg = '', 3000);
            await loadTemplates();
        } catch (e: any) {
            error = e.message;
        }
    }

    async function deleteTemplate(id: string) {
        if (!confirm('Delete this template?')) return;
        try {
            const { error: err } = await supabase.from('wa_templates').delete().eq('id', id);
            if (err) throw err;
            await loadTemplates();
        } catch (e: any) {
            error = e.message;
        }
    }

    function addButton() {
        if (form.buttons.length >= 3) return;
        form.buttons = [...form.buttons, { type: 'QUICK_REPLY', text: '' }];
    }

    function removeButton(index: number) {
        form.buttons = form.buttons.filter((_, i) => i !== index);
    }

    function getStatusBadge(status: string) {
        switch (status) {
            case 'APPROVED': return 'bg-emerald-100 text-emerald-700 border-emerald-200';
            case 'PENDING': return 'bg-amber-100 text-amber-700 border-amber-200';
            default: return 'bg-slate-100 text-slate-600 border-slate-200';
        }
    }

    function getStatusIcon(status: string) {
        switch (status) {
            case 'APPROVED': return '✅';
            case 'PENDING': return '⏳';
            default: return '❓';
        }
    }

    // Preview helper — replace {{1}}, {{2}} with sample text
    function getPreviewBody(text: string) {
        return text
            .replace(/\{\{1\}\}/g, '[Customer Name]')
            .replace(/\{\{2\}\}/g, '[Value 2]')
            .replace(/\{\{3\}\}/g, '[Value 3]')
            .replace(/\{\{4\}\}/g, '[Value 4]');
    }
</script>

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
    <!-- Header -->
    <div class="bg-white border-b border-slate-200 px-6 py-4 flex items-center justify-between shadow-sm">
        <div class="flex items-center gap-3">
            <span class="text-2xl">📝</span>
            <div>
                <h2 class="text-lg font-black text-slate-800 uppercase tracking-wide">{$t('nav.whatsappTemplates')}</h2>
                <p class="text-xs text-slate-500">{templates.length} templates</p>
            </div>
        </div>
        {#if activeView === 'list'}
            <div class="flex items-center gap-3">
                <select bind:value={categoryFilter} class="px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs font-bold">
                    <option value="all">All Categories</option>
                    {#each categories as cat}
                        <option value={cat.value}>{cat.icon} {cat.label}</option>
                    {/each}
                </select>
                <select bind:value={languageFilter} class="px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs font-bold">
                    <option value="all">All Languages</option>
                    <option value="en">🇺🇸 English</option>
                    <option value="ar">🇸🇦 Arabic</option>
                </select>
                <input type="text" bind:value={searchQuery} placeholder="Search templates..."
                    class="px-4 py-2 bg-slate-50 border border-slate-200 rounded-xl text-sm w-48 focus:outline-none focus:ring-2 focus:ring-emerald-500" />
                <button class="flex items-center gap-2 px-5 py-2.5 bg-emerald-600 text-white text-xs font-bold uppercase rounded-xl hover:bg-emerald-700 transition-all shadow-lg shadow-emerald-200"
                    on:click={startCreate}>
                    + Create Template
                </button>
            </div>
        {:else}
            <button class="px-4 py-2 bg-slate-100 text-slate-600 text-xs font-bold rounded-xl hover:bg-slate-200" on:click={cancelForm}>
                ← Back to List
            </button>
        {/if}
    </div>

    <!-- Main Content -->
    <div class="flex-1 p-6 relative overflow-y-auto bg-[radial-gradient(ellipse_at_top_right,_var(--tw-gradient-stops))] from-white via-slate-50/50 to-slate-100/50">
        <div class="absolute top-0 right-0 w-[500px] h-[500px] bg-emerald-100/20 rounded-full blur-[120px] -mr-64 -mt-64 animate-pulse pointer-events-none"></div>

        {#if successMsg}
            <div class="max-w-5xl mx-auto mb-4 bg-emerald-50 border border-emerald-200 rounded-xl p-3 text-center text-emerald-700 text-sm font-semibold">✅ {successMsg}</div>
        {/if}
        {#if error}
            <div class="max-w-5xl mx-auto mb-4 bg-red-50 border border-red-200 rounded-xl p-3 text-center text-red-700 text-sm font-semibold">❌ {error}
                <button class="ml-2 underline text-xs" on:click={() => error = ''}>dismiss</button>
            </div>
        {/if}

        {#if activeView === 'list'}
            <!-- Template List -->
            {#if loading}
                <div class="flex items-center justify-center h-64">
                    <div class="text-center">
                        <div class="animate-spin inline-block">
                            <div class="w-12 h-12 border-4 border-emerald-200 border-t-emerald-600 rounded-full"></div>
                        </div>
                        <p class="mt-4 text-slate-600 font-semibold">{$t('common.loading')}</p>
                    </div>
                </div>
            {:else if filteredTemplates.length === 0}
                <div class="max-w-3xl mx-auto bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-dashed border-2 border-slate-200 p-12 text-center">
                    <div class="text-5xl mb-4">📝</div>
                    <p class="text-slate-600 font-semibold text-lg">No templates found</p>
                    <p class="text-slate-400 text-sm mt-2">Create your first message template to get started</p>
                    <button class="mt-6 px-6 py-3 bg-emerald-600 text-white font-bold rounded-xl hover:bg-emerald-700 transition-all shadow-lg shadow-emerald-200"
                        on:click={startCreate}>+ Create Template</button>
                </div>
            {:else}
                <div class="max-w-5xl mx-auto grid grid-cols-1 md:grid-cols-2 gap-4">
                    {#each filteredTemplates as template}
                        <div class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-[0_8px_32px_-8px_rgba(0,0,0,0.06)] p-5 hover:shadow-[0_16px_48px_-12px_rgba(0,0,0,0.1)] transition-all duration-300">
                            <div class="flex items-start justify-between mb-3">
                                <div>
                                    <h4 class="font-black text-slate-800 text-sm">{template.name}</h4>
                                    <div class="flex items-center gap-2 mt-1">
                                        <span class="px-2 py-0.5 text-[10px] font-bold uppercase rounded-full border {getStatusBadge(template.status)}">
                                            {getStatusIcon(template.status)} {template.status}
                                        </span>
                                        <span class="px-2 py-0.5 text-[10px] font-bold uppercase rounded-full bg-slate-100 text-slate-600 border border-slate-200">
                                            {template.category}
                                        </span>
                                        <span class="px-2 py-0.5 text-[10px] font-bold uppercase rounded-full bg-blue-50 text-blue-600 border border-blue-200">
                                            {template.language === 'ar' ? '🇸🇦 AR' : '🇺🇸 EN'}
                                        </span>
                                    </div>
                                </div>
                            </div>

                            {#if template.header_type !== 'none' && template.header_content}
                                <div class="text-xs text-slate-500 mb-1 font-bold uppercase">Header: {template.header_type}</div>
                            {/if}

                            <div class="bg-slate-50 rounded-xl p-3 text-sm text-slate-700 mb-3 max-h-24 overflow-hidden">
                                {template.body_text || 'No body text'}
                            </div>

                            {#if template.footer_text}
                                <p class="text-[10px] text-slate-400 mb-2">{template.footer_text}</p>
                            {/if}

                            {#if template.buttons && template.buttons.length > 0}
                                <div class="flex gap-1 mb-3">
                                    {#each template.buttons as btn}
                                        <span class="px-2 py-1 bg-blue-50 text-blue-600 text-[10px] font-bold rounded-lg border border-blue-200">
                                            {btn.type === 'URL' ? '🔗' : btn.type === 'PHONE_NUMBER' ? '📞' : '💬'} {btn.text}
                                        </span>
                                    {/each}
                                </div>
                            {/if}

                            <div class="flex gap-2 pt-3 border-t border-slate-100">
                                <button class="px-3 py-1.5 bg-slate-50 text-slate-600 text-xs font-bold rounded-lg hover:bg-slate-100 border border-slate-200"
                                    on:click={() => startEdit(template)}>✏️ Edit</button>
                                <button class="px-3 py-1.5 bg-slate-50 text-slate-600 text-xs font-bold rounded-lg hover:bg-slate-100 border border-slate-200"
                                    on:click={() => duplicateTemplate(template)}>📋 Duplicate</button>
                                <button class="px-3 py-1.5 bg-red-50 text-red-600 text-xs font-bold rounded-lg hover:bg-red-100 border border-red-200"
                                    on:click={() => deleteTemplate(template.id)}>🗑️</button>
                            </div>
                        </div>
                    {/each}
                </div>
            {/if}
        {:else}
            <!-- Create/Edit Form with Live Preview -->
            <div class="max-w-6xl mx-auto flex gap-6">
                <!-- Form -->
                <div class="flex-1 bg-white/60 backdrop-blur-xl rounded-[2rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-8">
                    <h3 class="text-lg font-black text-slate-800 mb-6">
                        {editingId ? '✏️ Edit Template' : '📝 Create Template'}
                    </h3>

                    <div class="space-y-5">
                        <div class="grid grid-cols-3 gap-4">
                            <div>
                                <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">Template Name *</label>
                                <input type="text" bind:value={form.name} placeholder="e.g. order_confirmation"
                                    class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500" />
                                <p class="text-[10px] text-slate-400 mt-1">Lowercase, underscores only</p>
                            </div>
                            <div>
                                <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">Category *</label>
                                <select bind:value={form.category}
                                    class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500">
                                    {#each categories as cat}
                                        <option value={cat.value}>{cat.icon} {cat.label}</option>
                                    {/each}
                                </select>
                            </div>
                            <div>
                                <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">Language *</label>
                                <select bind:value={form.language}
                                    class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500">
                                    <option value="en">🇺🇸 English</option>
                                    <option value="ar">🇸🇦 Arabic</option>
                                </select>
                            </div>
                        </div>

                        <!-- Header -->
                        <div>
                            <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">Header Type</label>
                            <div class="flex gap-2">
                                {#each ['none', 'text', 'image', 'video', 'document'] as ht}
                                    <button class="px-3 py-1.5 text-xs font-bold rounded-lg transition-all
                                        {form.header_type === ht ? 'bg-emerald-600 text-white' : 'bg-slate-100 text-slate-600 hover:bg-slate-200'}"
                                        on:click={() => form.header_type = ht}>
                                        {ht === 'none' ? '—' : ht === 'text' ? '📄' : ht === 'image' ? '🖼️' : ht === 'video' ? '🎥' : '📎'} {ht}
                                    </button>
                                {/each}
                            </div>
                            {#if form.header_type !== 'none'}
                                <input type="text" bind:value={form.header_content}
                                    placeholder={form.header_type === 'text' ? 'Header text...' : 'Media URL...'}
                                    class="w-full mt-2 px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500" />
                            {/if}
                        </div>

                        <!-- Body -->
                        <div>
                            <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">Body Text *</label>
                            <textarea bind:value={form.body_text} rows="5"
                                placeholder={"Hello {{1}}, your order #{{2}} is confirmed. Thank you!"}
                                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 resize-none font-mono"></textarea>
                            <p class="text-[10px] text-slate-400 mt-1">Use {'{{1}}'}, {'{{2}}'} etc. for variables</p>
                        </div>

                        <!-- Footer -->
                        <div>
                            <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">Footer (optional)</label>
                            <input type="text" bind:value={form.footer_text} placeholder="Reply STOP to unsubscribe"
                                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500" />
                        </div>

                        <!-- Buttons -->
                        <div>
                            <div class="flex items-center justify-between mb-2">
                                <label class="text-xs font-bold text-slate-600 uppercase tracking-wide">Buttons ({form.buttons.length}/3)</label>
                                {#if form.buttons.length < 3}
                                    <button class="px-3 py-1 bg-emerald-50 text-emerald-700 text-xs font-bold rounded-lg hover:bg-emerald-100 border border-emerald-200"
                                        on:click={addButton}>+ Add Button</button>
                                {/if}
                            </div>
                            {#each form.buttons as btn, i}
                                <div class="flex gap-2 mb-2 items-center">
                                    <select bind:value={btn.type}
                                        class="px-3 py-2 bg-white border border-slate-200 rounded-lg text-xs focus:ring-2 focus:ring-emerald-500">
                                        <option value="QUICK_REPLY">💬 Quick Reply</option>
                                        <option value="URL">🔗 URL</option>
                                        <option value="PHONE_NUMBER">📞 Phone</option>
                                    </select>
                                    <input type="text" bind:value={btn.text} placeholder="Button text"
                                        class="flex-1 px-3 py-2 bg-white border border-slate-200 rounded-lg text-xs focus:ring-2 focus:ring-emerald-500" />
                                    {#if btn.type === 'URL'}
                                        <input type="text" bind:value={btn.url} placeholder="https://..."
                                            class="flex-1 px-3 py-2 bg-white border border-slate-200 rounded-lg text-xs focus:ring-2 focus:ring-emerald-500 font-mono" />
                                    {:else if btn.type === 'PHONE_NUMBER'}
                                        <input type="text" bind:value={btn.phone_number} placeholder="+966..."
                                            class="flex-1 px-3 py-2 bg-white border border-slate-200 rounded-lg text-xs focus:ring-2 focus:ring-emerald-500 font-mono" />
                                    {/if}
                                    <button class="px-2 py-2 bg-red-50 text-red-500 rounded-lg hover:bg-red-100 text-xs"
                                        on:click={() => removeButton(i)}>✕</button>
                                </div>
                            {/each}
                        </div>

                        <div class="flex gap-3 pt-4">
                            <button class="px-4 py-2.5 bg-slate-100 text-slate-600 text-xs font-bold uppercase rounded-xl hover:bg-slate-200" on:click={cancelForm}>
                                Cancel
                            </button>
                            <button class="px-6 py-2.5 bg-emerald-600 text-white text-xs font-bold uppercase rounded-xl hover:bg-emerald-700 shadow-lg shadow-emerald-200 disabled:opacity-50"
                                on:click={saveTemplate} disabled={saving}>
                                {saving ? '⏳ Saving...' : editingId ? '💾 Update Template' : '📤 Submit Template'}
                            </button>
                        </div>
                    </div>
                </div>

                <!-- Live Mobile Preview -->
                <div class="w-80 flex-shrink-0">
                    <div class="sticky top-0">
                        <p class="text-xs font-bold text-slate-500 uppercase tracking-wide mb-3 text-center">📱 Live Preview</p>
                        <div class="bg-slate-800 rounded-[2.5rem] p-3 shadow-2xl">
                            <div class="bg-[#ECE5DD] rounded-[2rem] overflow-hidden">
                                <!-- Phone Header -->
                                <div class="bg-[#075E54] text-white px-4 py-3 flex items-center gap-2">
                                    <span class="text-lg">←</span>
                                    <div class="w-8 h-8 bg-white/20 rounded-full flex items-center justify-center text-xs">B</div>
                                    <span class="text-sm font-bold">Business</span>
                                </div>

                                <!-- Message Preview -->
                                <div class="p-3 min-h-[400px]">
                                    <div class="bg-white rounded-xl p-3 shadow-sm max-w-[90%]">
                                        {#if form.header_type === 'text' && form.header_content}
                                            <p class="font-bold text-sm text-slate-800 mb-1">{form.header_content}</p>
                                        {:else if form.header_type === 'image'}
                                            <div class="bg-slate-200 rounded-lg h-32 flex items-center justify-center text-3xl mb-2">🖼️</div>
                                        {:else if form.header_type === 'video'}
                                            <div class="bg-slate-200 rounded-lg h-32 flex items-center justify-center text-3xl mb-2">🎥</div>
                                        {:else if form.header_type === 'document'}
                                            <div class="bg-slate-100 rounded-lg p-3 flex items-center gap-2 mb-2">
                                                <span class="text-2xl">📎</span>
                                                <span class="text-xs text-slate-600">Document</span>
                                            </div>
                                        {/if}

                                        <p class="text-sm text-slate-800 whitespace-pre-wrap {form.language === 'ar' ? 'text-right' : 'text-left'}" dir={form.language === 'ar' ? 'rtl' : 'ltr'}>
                                            {form.body_text ? getPreviewBody(form.body_text) : 'Your message body will appear here...'}
                                        </p>

                                        {#if form.footer_text}
                                            <p class="text-[10px] text-slate-400 mt-2">{form.footer_text}</p>
                                        {/if}

                                        <p class="text-[9px] text-slate-400 text-right mt-1">10:30 AM</p>
                                    </div>

                                    {#if form.buttons.length > 0}
                                        <div class="mt-1 space-y-1 max-w-[90%]">
                                            {#each form.buttons as btn}
                                                <div class="bg-white rounded-lg p-2 text-center text-sm text-[#00A5F4] font-semibold shadow-sm cursor-pointer hover:bg-slate-50">
                                                    {btn.type === 'URL' ? '🔗' : btn.type === 'PHONE_NUMBER' ? '📞' : '💬'}
                                                    {btn.text || 'Button'}
                                                </div>
                                            {/each}
                                        </div>
                                    {/if}
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        {/if}
    </div>
</div>
