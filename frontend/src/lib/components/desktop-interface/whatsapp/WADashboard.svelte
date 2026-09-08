<script lang="ts">
    import { onMount } from 'svelte';
    import { _ as t, locale } from '$lib/i18n';

    interface Stats {
        totalConversations: number;
        activeConversations: number;
        messagesIn: number;
        messagesOut: number;
        inside24hr: number;
        outside24hr: number;
        botHandled: number;
        aiHandled: number;
        humanHandled: number;
        broadcastsSent: number;
        templatesApproved: number;
        unreadMessages: number;
    }

    interface RecentActivity {
        id: string;
        type: string;
        customer_name: string;
        customer_phone: string;
        preview: string;
        time: string;
    }

    interface TemplatePerf {
        name: string;
        sent: number;
        delivered: number;
        read: number;
    }

    let supabase: any = null;
    let accountId = '';
    let loading = true;
    let stats: Stats = {
        totalConversations: 0, activeConversations: 0,
        messagesIn: 0, messagesOut: 0,
        inside24hr: 0, outside24hr: 0,
        botHandled: 0, aiHandled: 0, humanHandled: 0,
        broadcastsSent: 0, templatesApproved: 0, unreadMessages: 0
    };
    let recentActivity: RecentActivity[] = [];
    let templatePerf: TemplatePerf[] = [];

    onMount(async () => {
        const mod = await import('$lib/utils/supabase');
        supabase = mod.supabase;
        await loadAccount();
    });

    async function loadAccount() {
        try {
            const { data } = await supabase.from('wa_accounts').select('id').eq('is_default', true).single();
            if (data) {
                accountId = data.id;
                await loadAllStats();
            }
        } catch {} finally { loading = false; }
    }

    async function loadAllStats() {
        try {
            const { data, error } = await supabase.rpc('get_wa_dashboard_data', { p_account_id: accountId });
            if (error) throw error;

            const c = data.conversations;
            stats.totalConversations  = Number(c.total)        || 0;
            stats.activeConversations = Number(c.active)       || 0;
            stats.unreadMessages      = Number(c.unread)       || 0;
            stats.inside24hr          = Number(c.inside24hr)   || 0;
            stats.outside24hr         = Number(c.outside24hr)  || 0;
            stats.botHandled          = Number(c.botHandled)   || 0;
            stats.aiHandled           = Number(c.aiHandled)    || 0;
            stats.humanHandled        = Number(c.humanHandled) || 0;
            stats.messagesIn          = Number(data.messages_in)        || 0;
            stats.messagesOut         = Number(data.messages_out)       || 0;
            stats.broadcastsSent      = Number(data.broadcasts_sent)    || 0;
            stats.templatesApproved   = Number(data.templates_approved) || 0;

            recentActivity = (data.recent_activity || []).map((m: any) => ({
                id: m.id,
                type: m.direction,
                customer_name: m.customer_name || 'Unknown',
                customer_phone: m.customer_phone || '',
                preview: (m.content || '').substring(0, 60),
                time: m.created_at
            }));

            const perfMap = new Map<string, TemplatePerf>();
            for (const tp of (data.template_performance || [])) {
                perfMap.set(tp.name, {
                    name: tp.name,
                    sent: Number(tp.sent) || 0,
                    delivered: Number(tp.delivered) || 0,
                    read: Number(tp.read) || 0
                });
            }
            templatePerf = Array.from(perfMap.values());
        } catch (err) {
            console.error('Error loading WA dashboard:', err);
        }
    }

    function formatTime(dateStr: string) {
        const d = new Date(dateStr);
        const now = new Date();
        const diffMs = now.getTime() - d.getTime();
        const diffMins = Math.floor(diffMs / 60000);
        if (diffMins < 1) return 'just now';
        if (diffMins < 60) return `${diffMins}m ago`;
        const diffHrs = Math.floor(diffMs / 3600000);
        if (diffHrs < 24) return `${diffHrs}h ago`;
        return d.toLocaleDateString([], { month: 'short', day: 'numeric' });
    }
</script>

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
    <!-- Header -->
    <div class="bg-white border-b border-slate-200 px-6 py-4">
        <div class="flex items-center gap-3">
            <span class="text-2xl">📊</span>
            <h1 class="text-lg font-black text-slate-800 uppercase tracking-wide">{$t('nav.whatsappDashboard')}</h1>
        </div>
    </div>

    <div class="flex-1 overflow-y-auto p-6">
        {#if loading}
            <div class="flex justify-center items-center h-64">
                <div class="animate-spin w-10 h-10 border-4 border-emerald-200 border-t-emerald-600 rounded-full"></div>
            </div>
        {:else}
            <!-- Stats Cards Row 1 -->
            <div class="grid grid-cols-4 gap-4 mb-6">
                {#each [
                    { label: 'Total Conversations', value: stats.totalConversations, icon: '💬', color: 'emerald' },
                    { label: 'Total Messages', value: stats.messagesIn + stats.messagesOut, icon: '📨', color: 'blue' },
                    { label: 'Unread Messages', value: stats.unreadMessages, icon: '🔵', color: 'amber' },
                    { label: 'Broadcasts Sent', value: stats.broadcastsSent, icon: '📣', color: 'purple' }
                ] as card}
                    <div class="bg-white/60 backdrop-blur-xl border border-white/40 rounded-[2rem] p-5 hover:shadow-lg transition-all">
                        <div class="flex items-center justify-between mb-3">
                            <span class="text-2xl">{card.icon}</span>
                            <span class="text-[10px] font-bold text-slate-400 uppercase">{card.label}</span>
                        </div>
                        <p class="text-3xl font-black text-slate-800">{card.value.toLocaleString()}</p>
                    </div>
                {/each}
            </div>

            <!-- Stats Cards Row 2 -->
            <div class="grid grid-cols-6 gap-3 mb-6">
                {#each [
                    { label: 'Inside 24hr', value: stats.inside24hr, icon: '🟢', bg: 'bg-emerald-50', text: 'text-emerald-700' },
                    { label: 'Outside 24hr', value: stats.outside24hr, icon: '🔴', bg: 'bg-red-50', text: 'text-red-700' },
                    { label: 'Messages In', value: stats.messagesIn, icon: '📥', bg: 'bg-blue-50', text: 'text-blue-700' },
                    { label: 'Messages Out', value: stats.messagesOut, icon: '📤', bg: 'bg-indigo-50', text: 'text-indigo-700' },
                    { label: 'Templates', value: stats.templatesApproved, icon: '📝', bg: 'bg-amber-50', text: 'text-amber-700' },
                    { label: 'Active Chats', value: stats.activeConversations, icon: '💬', bg: 'bg-purple-50', text: 'text-purple-700' }
                ] as card}
                    <div class="{card.bg} rounded-2xl p-4 text-center">
                        <span class="text-lg">{card.icon}</span>
                        <p class="text-xl font-black {card.text} mt-1">{card.value}</p>
                        <p class="text-[9px] font-bold text-slate-400 uppercase mt-0.5">{card.label}</p>
                    </div>
                {/each}
            </div>



            <div class="bg-white/60 backdrop-blur-xl border border-white/40 rounded-[2rem] p-5 mb-6">
                <h3 class="text-xs font-bold text-slate-600 uppercase mb-4">🤖 Bot Handling Distribution</h3>
                <div class="flex items-center gap-3 mb-3">
                    <div class="flex-1 h-8 bg-slate-100 rounded-full overflow-hidden flex">
                        {#if stats.activeConversations > 0}
                            {@const total = stats.humanHandled + stats.aiHandled + stats.botHandled || 1}
                            <div class="bg-slate-500 h-full transition-all" style="width: {(stats.humanHandled / total) * 100}%"></div>
                            <div class="bg-purple-500 h-full transition-all" style="width: {(stats.aiHandled / total) * 100}%"></div>
                            <div class="bg-blue-500 h-full transition-all" style="width: {(stats.botHandled / total) * 100}%"></div>
                        {/if}
                    </div>
                </div>
                <div class="flex gap-6">
                    <div class="flex items-center gap-2">
                        <span class="w-3 h-3 bg-slate-500 rounded-full"></span>
                        <span class="text-xs text-slate-600">👤 Human ({stats.humanHandled})</span>
                    </div>
                    <div class="flex items-center gap-2">
                        <span class="w-3 h-3 bg-purple-500 rounded-full"></span>
                        <span class="text-xs text-slate-600">🤖 AI Bot ({stats.aiHandled})</span>
                    </div>
                    <div class="flex items-center gap-2">
                        <span class="w-3 h-3 bg-blue-500 rounded-full"></span>
                        <span class="text-xs text-slate-600">🔧 Auto-Reply ({stats.botHandled})</span>
                    </div>
                </div>
            </div>

            <!-- Two Column Layout -->
            <div class="grid grid-cols-2 gap-6">
                <!-- Recent Activity -->
                <div class="bg-white/60 backdrop-blur-xl border border-white/40 rounded-[2rem] p-5">
                    <h3 class="text-xs font-bold text-slate-600 uppercase mb-4">📬 Recent Activity</h3>
                    {#if recentActivity.length === 0}
                        <p class="text-xs text-slate-400 text-center py-6">No recent messages</p>
                    {:else}
                        <div class="space-y-2">
                            {#each recentActivity as act}
                                <div class="flex items-center gap-3 py-2 border-b border-slate-100 last:border-0">
                                    <span class="text-sm">{act.type === 'inbound' ? '📥' : '📤'}</span>
                                    <div class="flex-1 min-w-0">
                                        <p class="text-xs font-bold text-slate-700 truncate">{act.customer_name}</p>
                                        <p class="text-[10px] text-slate-500 truncate">{act.preview || '(media)'}</p>
                                    </div>
                                    <span class="text-[10px] text-slate-400 flex-shrink-0">{formatTime(act.time)}</span>
                                </div>
                            {/each}
                        </div>
                    {/if}
                </div>

                <!-- Template Performance -->
                <div class="bg-white/60 backdrop-blur-xl border border-white/40 rounded-[2rem] p-5">
                    <h3 class="text-xs font-bold text-slate-600 uppercase mb-4">📝 Template Performance</h3>
                    {#if templatePerf.length === 0}
                        <p class="text-xs text-slate-400 text-center py-6">No broadcast data yet</p>
                    {:else}
                        <div class="space-y-3">
                            {#each templatePerf as tp}
                                <div class="bg-slate-50 rounded-xl p-3">
                                    <p class="text-xs font-bold text-slate-700 mb-2">{tp.name}</p>
                                    <div class="flex gap-4">
                                        <div class="text-center">
                                            <p class="text-sm font-black text-emerald-600">{tp.sent}</p>
                                            <p class="text-[9px] text-slate-400">Sent</p>
                                        </div>
                                        <div class="text-center">
                                            <p class="text-sm font-black text-blue-600">{tp.delivered}</p>
                                            <p class="text-[9px] text-slate-400">Delivered</p>
                                        </div>
                                        <div class="text-center">
                                            <p class="text-sm font-black text-purple-600">{tp.read}</p>
                                            <p class="text-[9px] text-slate-400">Read</p>
                                        </div>
                                        <!-- Read rate bar -->
                                        <div class="flex-1 flex items-center">
                                            <div class="w-full bg-slate-200 rounded-full h-2">
                                                <div class="bg-emerald-500 rounded-full h-2 transition-all" style="width: {tp.sent > 0 ? Math.round((tp.read / tp.sent) * 100) : 0}%"></div>
                                            </div>
                                            <span class="text-[10px] text-slate-500 ml-2">{tp.sent > 0 ? Math.round((tp.read / tp.sent) * 100) : 0}%</span>
                                        </div>
                                    </div>
                                </div>
                            {/each}
                        </div>
                    {/if}
                </div>
            </div>
        {/if}
    </div>
</div>
