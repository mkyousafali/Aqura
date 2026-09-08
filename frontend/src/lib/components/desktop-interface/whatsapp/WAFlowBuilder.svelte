<script lang="ts">
    import { onMount, onDestroy } from 'svelte';
    import { _ as t, locale } from '$lib/i18n';

    // ─── Types ────────────────────────────────────
    interface FlowButton {
        id: string;
        title: string;
        type: 'quick_reply' | 'url' | 'phone';
        url?: string;
        phone?: string;
        action?: 'none' | 'subscribe' | 'unsubscribe';
    }

    interface FlowNode {
        id: string;
        type: 'start' | 'text' | 'image' | 'video' | 'document' | 'buttons' | 'delay' | 'subscribe' | 'unsubscribe';
        x: number;
        y: number;
        data: {
            label?: string;
            text?: string;
            mediaUrl?: string;
            caption?: string;
            filename?: string;
            buttons?: FlowButton[];
            delaySeconds?: number;
            triggerWords?: string[];
            triggerWordsAr?: string[];
            matchType?: string;
        };
    }

    interface FlowEdge {
        id: string;
        from: string;       // node id
        fromPort: string;   // 'out' or 'btn_0', 'btn_1', 'btn_2'
        to: string;         // node id
        toPort: string;     // 'in'
    }

    interface BotFlow {
        id: string;
        name: string;
        trigger_words_en: string[];
        trigger_words_ar: string[];
        match_type: string;
        nodes: FlowNode[];
        edges: FlowEdge[];
        is_active: boolean;
        priority: number;
        created_at: string;
    }

    let supabase: any = null;
    let accountId = '';
    let loading = true;
    let saving = false;
    let flows: BotFlow[] = [];

    // View state
    let activeView: 'list' | 'editor' = 'list';
    let editingFlow: BotFlow | null = null;

    // Canvas state
    let canvasEl: HTMLDivElement;
    let canvasOffset = { x: 0, y: 0 };
    let zoom = 1;
    let isPanning = false;
    let panStart = { x: 0, y: 0 };

    // Dragging node
    let draggingNodeId: string | null = null;
    let dragOffset = { x: 0, y: 0 };

    // Drawing edge
    let drawingEdge: { fromId: string; fromPort: string; x: number; y: number } | null = null;

    // Selected node (for property panel)
    let selectedNodeId: string | null = null;

    // Trigger word inputs
    let triggerWordInput = '';
    let triggerWordArInput = '';

    // File upload
    let fileInputEl: HTMLInputElement;
    let uploading = false;
    let uploadProgress = '';

    // ─── Reactive ──────────────────────────────────
    $: selectedNode = editingFlow?.nodes.find(n => n.id === selectedNodeId) ?? null;
    $: flowNodes = editingFlow?.nodes ?? [];
    $: flowEdges = editingFlow?.edges ?? [];

    // ─── Node Dimensions ──────────────────────────
    const NODE_W = 220;
    const NODE_H_BASE = 60;

    function getNodeHeight(node: FlowNode): number {
        if (node.type === 'start') return 50;
        if (node.type === 'delay') return 50;
        if (node.type === 'subscribe' || node.type === 'unsubscribe') return 50;
        if (node.type === 'buttons') return 60 + (node.data.buttons?.length || 0) * 24;
        return NODE_H_BASE;
    }

    // ─── Lifecycle ─────────────────────────────────
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
                await loadFlows();
            }
        } catch {} finally { loading = false; }
    }

    async function loadFlows() {
        const { data } = await supabase.from('wa_bot_flows')
            .select('*')
            .eq('wa_account_id', accountId)
            .order('priority', { ascending: true });
        flows = data || [];
    }

    // ─── Flow CRUD ────────────────────────────────
    function createNewFlow() {
        const startNode: FlowNode = {
            id: generateId(),
            type: 'start',
            x: 80,
            y: 200,
            data: { label: 'Start', triggerWords: [], triggerWordsAr: [], matchType: 'contains' }
        };
        editingFlow = {
            id: '',
            name: 'New Flow',
            trigger_words_en: [],
            trigger_words_ar: [],
            match_type: 'contains',
            nodes: [startNode],
            edges: [],
            is_active: true,
            priority: flows.length + 1,
            created_at: new Date().toISOString()
        };
        selectedNodeId = startNode.id;
        activeView = 'editor';
        canvasOffset = { x: 0, y: 0 };
        zoom = 1;
    }

    function editFlow(flow: BotFlow) {
        editingFlow = JSON.parse(JSON.stringify(flow));
        selectedNodeId = editingFlow!.nodes[0]?.id || null;
        activeView = 'editor';
        canvasOffset = { x: 0, y: 0 };
        zoom = 1;
    }

    async function saveFlow() {
        if (!editingFlow || !editingFlow.name.trim() || saving) return;
        saving = true;
        try {
            // Sync trigger words from start node
            const startNode = editingFlow.nodes.find(n => n.type === 'start');
            if (startNode) {
                editingFlow.trigger_words_en = startNode.data.triggerWords || [];
                editingFlow.trigger_words_ar = startNode.data.triggerWordsAr || [];
                editingFlow.match_type = startNode.data.matchType || 'contains';
            }

            const payload = {
                wa_account_id: accountId,
                name: editingFlow.name,
                trigger_words_en: editingFlow.trigger_words_en,
                trigger_words_ar: editingFlow.trigger_words_ar,
                match_type: editingFlow.match_type,
                nodes: editingFlow.nodes,
                edges: editingFlow.edges,
                is_active: editingFlow.is_active,
                priority: editingFlow.priority,
                updated_at: new Date().toISOString()
            };

            if (editingFlow.id) {
                await supabase.from('wa_bot_flows').update(payload).eq('id', editingFlow.id);
            } else {
                const { data } = await supabase.from('wa_bot_flows').insert(payload).select().single();
                if (data) editingFlow.id = data.id;
            }
            await loadFlows();
        } catch (e: any) {
            alert('Error saving: ' + e.message);
        } finally { saving = false; }
    }

    async function deleteFlow(id: string) {
        if (!confirm('Delete this flow?')) return;
        await supabase.from('wa_bot_flows').delete().eq('id', id);
        await loadFlows();
    }

    async function toggleFlow(flow: BotFlow) {
        await supabase.from('wa_bot_flows').update({ is_active: !flow.is_active }).eq('id', flow.id);
        flow.is_active = !flow.is_active;
        flows = [...flows];
    }

    // ─── Node Operations ──────────────────────────
    function addNode(type: FlowNode['type']) {
        if (!editingFlow) return;
        const id = generateId();
        const newNode: FlowNode = {
            id,
            type,
            x: 300 + Math.random() * 200 - canvasOffset.x,
            y: 150 + Math.random() * 200 - canvasOffset.y,
            data: getDefaultNodeData(type)
        };
        editingFlow.nodes = [...editingFlow.nodes, newNode];
        selectedNodeId = id;
    }

    function getDefaultNodeData(type: FlowNode['type']): FlowNode['data'] {
        switch (type) {
            case 'text': return { label: 'Text Message', text: '' };
            case 'image': return { label: 'Image', mediaUrl: '', caption: '' };
            case 'video': return { label: 'Video', mediaUrl: '', caption: '' };
            case 'document': return { label: 'Document', mediaUrl: '', caption: '', filename: 'document.pdf' };
            case 'buttons': return { label: 'Buttons', text: '', buttons: [{ id: generateId(), title: 'Button 1', type: 'quick_reply' as const }] };
            case 'delay': return { label: 'Delay', delaySeconds: 5 };
            case 'subscribe': return { label: 'Subscribe Customer', text: 'You have been subscribed successfully! ✅' };
            case 'unsubscribe': return { label: 'Unsubscribe Customer', text: 'You have been unsubscribed. You will no longer receive messages.' };
            default: return { label: '' };
        }
    }

    function deleteNode(nodeId: string) {
        if (!editingFlow) return;
        const node = editingFlow.nodes.find(n => n.id === nodeId);
        if (!node || node.type === 'start') return;
        editingFlow.nodes = editingFlow.nodes.filter(n => n.id !== nodeId);
        editingFlow.edges = editingFlow.edges.filter(e => e.from !== nodeId && e.to !== nodeId);
        if (selectedNodeId === nodeId) selectedNodeId = null;
    }

    // ─── Edge Operations ──────────────────────────
    function startDrawingEdge(nodeId: string, port: string, e: MouseEvent) {
        e.stopPropagation();
        const rect = canvasEl.getBoundingClientRect();
        drawingEdge = {
            fromId: nodeId,
            fromPort: port,
            x: (e.clientX - rect.left) / zoom - canvasOffset.x,
            y: (e.clientY - rect.top) / zoom - canvasOffset.y
        };
    }

    function finishDrawingEdge(nodeId: string) {
        if (!drawingEdge || !editingFlow) return;
        if (drawingEdge.fromId === nodeId) { drawingEdge = null; return; }

        // Prevent duplicate edge from same port to same target
        const duplicate = editingFlow.edges.some(e =>
            e.from === drawingEdge!.fromId && e.fromPort === drawingEdge!.fromPort && e.to === nodeId
        );
        if (duplicate) { drawingEdge = null; return; }

        editingFlow.edges = [...editingFlow.edges, {
            id: generateId(),
            from: drawingEdge.fromId,
            fromPort: drawingEdge.fromPort,
            to: nodeId,
            toPort: 'in'
        }];
        drawingEdge = null;
    }

    function deleteEdge(edgeId: string) {
        if (!editingFlow) return;
        editingFlow.edges = editingFlow.edges.filter(e => e.id !== edgeId);
    }

    // ─── Port Positions ───────────────────────────
    function getOutPortPos(node: FlowNode, port: string): { x: number; y: number } {
        const h = getNodeHeight(node);
        if (port === 'out') {
            return { x: node.x + NODE_W, y: node.y + h / 2 };
        }
        // Button ports
        const btnIdx = parseInt(port.replace('btn_', ''));
        const btnY = 55 + btnIdx * 24;
        return { x: node.x + NODE_W, y: node.y + btnY };
    }

    function getInPortPos(node: FlowNode): { x: number; y: number } {
        const h = getNodeHeight(node);
        return { x: node.x, y: node.y + h / 2 };
    }

    // ─── Canvas Mouse Handlers ────────────────────
    function onCanvasMouseDown(e: MouseEvent) {
        if (e.button === 1 || (e.button === 0 && e.altKey)) {
            isPanning = true;
            panStart = { x: e.clientX - canvasOffset.x * zoom, y: e.clientY - canvasOffset.y * zoom };
            e.preventDefault();
        } else if (e.button === 0 && !(e.target as HTMLElement)?.closest?.('.flow-node')) {
            selectedNodeId = null;
        }
    }

    function onCanvasMouseMove(e: MouseEvent) {
        if (isPanning) {
            canvasOffset = {
                x: (e.clientX - panStart.x) / zoom,
                y: (e.clientY - panStart.y) / zoom
            };
            return;
        }
        if (draggingNodeId && editingFlow) {
            const rect = canvasEl.getBoundingClientRect();
            const node = editingFlow.nodes.find(n => n.id === draggingNodeId);
            if (node) {
                node.x = (e.clientX - rect.left) / zoom - canvasOffset.x - dragOffset.x;
                node.y = (e.clientY - rect.top) / zoom - canvasOffset.y - dragOffset.y;
                editingFlow.nodes = [...editingFlow.nodes];
            }
            return;
        }
        if (drawingEdge) {
            const rect = canvasEl.getBoundingClientRect();
            drawingEdge = {
                ...drawingEdge,
                x: (e.clientX - rect.left) / zoom - canvasOffset.x,
                y: (e.clientY - rect.top) / zoom - canvasOffset.y
            };
        }
    }

    function onCanvasMouseUp() {
        isPanning = false;
        draggingNodeId = null;
        if (drawingEdge) drawingEdge = null;
    }

    function onNodeMouseDown(nodeId: string, e: MouseEvent) {
        if (e.button !== 0) return;
        e.stopPropagation();
        selectedNodeId = nodeId;
        const node = editingFlow?.nodes.find(n => n.id === nodeId);
        if (!node) return;
        const rect = canvasEl.getBoundingClientRect();
        dragOffset = {
            x: (e.clientX - rect.left) / zoom - canvasOffset.x - node.x,
            y: (e.clientY - rect.top) / zoom - canvasOffset.y - node.y
        };
        draggingNodeId = nodeId;
    }

    function onWheel(e: WheelEvent) {
        e.preventDefault();
        const delta = e.deltaY > 0 ? -0.05 : 0.05;
        zoom = Math.max(0.3, Math.min(2, zoom + delta));
    }

    // ─── Trigger Words ────────────────────────────
    function addFlowTriggerWord(lang: 'en' | 'ar') {
        if (!selectedNode || selectedNode.type !== 'start') return;
        const input = lang === 'en' ? triggerWordInput.trim() : triggerWordArInput.trim();
        if (!input) return;
        if (lang === 'en') {
            selectedNode.data.triggerWords = [...(selectedNode.data.triggerWords || []), input];
            triggerWordInput = '';
        } else {
            selectedNode.data.triggerWordsAr = [...(selectedNode.data.triggerWordsAr || []), input];
            triggerWordArInput = '';
        }
        editingFlow!.nodes = [...editingFlow!.nodes];
    }

    function removeFlowTriggerWord(lang: 'en' | 'ar', idx: number) {
        if (!selectedNode || selectedNode.type !== 'start') return;
        if (lang === 'en') {
            selectedNode.data.triggerWords = selectedNode.data.triggerWords!.filter((_: any, i: number) => i !== idx);
        } else {
            selectedNode.data.triggerWordsAr = selectedNode.data.triggerWordsAr!.filter((_: any, i: number) => i !== idx);
        }
        editingFlow!.nodes = [...editingFlow!.nodes];
    }

    // ─── Button Management ────────────────────────
    $: buttonCounts = (() => {
        if (!selectedNode || selectedNode.type !== 'buttons') return { total: 0, cta: 0, qr: 0 };
        const btns = selectedNode.data.buttons || [];
        const cta = btns.filter(b => b.type === 'url' || b.type === 'phone').length;
        return { total: btns.length, cta, qr: btns.length - cta };
    })();

    $: canAddQuickReply = buttonCounts.total < 3;
    $: canAddCTA = buttonCounts.total < 3 && buttonCounts.cta < 2;

    function addButtonToNode(btnType: 'quick_reply' | 'url' | 'phone' = 'quick_reply') {
        if (!selectedNode || selectedNode.type !== 'buttons' || !editingFlow) return;
        if (buttonCounts.total >= 3) return;
        if ((btnType === 'url' || btnType === 'phone') && buttonCounts.cta >= 2) return;
        const newBtn: FlowButton = { id: generateId(), title: '', type: btnType, action: 'none' };
        if (btnType === 'url') newBtn.url = '';
        if (btnType === 'phone') newBtn.phone = '';
        selectedNode.data.buttons = [...(selectedNode.data.buttons || []), newBtn];
        editingFlow.nodes = [...editingFlow.nodes];
    }

    function changeButtonType(idx: number, newType: 'quick_reply' | 'url' | 'phone') {
        if (!selectedNode || !editingFlow) return;
        const btns = selectedNode.data.buttons || [];
        const btn = btns[idx];
        if (!btn) return;
        // Validate CTA limit
        if ((newType === 'url' || newType === 'phone') && btn.type === 'quick_reply') {
            const currentCta = btns.filter(b => b.type === 'url' || b.type === 'phone').length;
            if (currentCta >= 2) return; // can't add more CTA
        }
        btn.type = newType;
        if (newType === 'url') { btn.url = btn.url || ''; delete btn.phone; delete btn.action; }
        else if (newType === 'phone') { btn.phone = btn.phone || ''; delete btn.url; delete btn.action; }
        else { delete btn.url; delete btn.phone; btn.action = btn.action || 'none'; }
        editingFlow.nodes = [...editingFlow.nodes];
    }

    function removeButtonFromNode(idx: number) {
        if (!selectedNode || !editingFlow) return;
        // Remove associated edge and re-index
        const port = `btn_${idx}`;
        editingFlow.edges = editingFlow.edges.filter(e => !(e.from === selectedNode!.id && e.fromPort === port));
        // Re-index edges for buttons after the deleted one
        editingFlow.edges = editingFlow.edges.map(e => {
            if (e.from === selectedNode!.id && e.fromPort.startsWith('btn_')) {
                const eIdx = parseInt(e.fromPort.replace('btn_', ''));
                if (eIdx > idx) return { ...e, fromPort: `btn_${eIdx - 1}` };
            }
            return e;
        });
        selectedNode.data.buttons = selectedNode.data.buttons!.filter((_: any, i: number) => i !== idx);
        editingFlow.nodes = [...editingFlow.nodes];
    }

    // ─── Edge Path ────────────────────────────────
    function getEdgePath(edge: FlowEdge): string {
        const fromNode = flowNodes.find(n => n.id === edge.from);
        const toNode = flowNodes.find(n => n.id === edge.to);
        if (!fromNode || !toNode) return '';
        const from = getOutPortPos(fromNode, edge.fromPort);
        const to = getInPortPos(toNode);
        const dx = Math.abs(to.x - from.x) * 0.5;
        return `M ${from.x} ${from.y} C ${from.x + dx} ${from.y}, ${to.x - dx} ${to.y}, ${to.x} ${to.y}`;
    }

    function getDrawingEdgePath(): string {
        if (!drawingEdge) return '';
        const fromNode = flowNodes.find(n => n.id === drawingEdge!.fromId);
        if (!fromNode) return '';
        const from = getOutPortPos(fromNode, drawingEdge.fromPort);
        const to = { x: drawingEdge.x, y: drawingEdge.y };
        const dx = Math.abs(to.x - from.x) * 0.5;
        return `M ${from.x} ${from.y} C ${from.x + dx} ${from.y}, ${to.x - dx} ${to.y}, ${to.x} ${to.y}`;
    }

    // ─── Utils ────────────────────────────────────
    function generateId(): string {
        return 'n' + Date.now().toString(36) + Math.random().toString(36).slice(2, 6);
    }

    function getNodeIcon(type: string): string {
        const icons: Record<string, string> = {
            start: '🚀', text: '💬', image: '🖼️', video: '🎥',
            document: '📎', buttons: '🔘', delay: '⏱️',
            subscribe: '✅', unsubscribe: '🚫'
        };
        return icons[type] || '📦';
    }

    function getNodeColor(type: string): string {
        const colors: Record<string, string> = {
            start: 'border-emerald-500 bg-emerald-50',
            text: 'border-blue-400 bg-blue-50',
            image: 'border-purple-400 bg-purple-50',
            video: 'border-pink-400 bg-pink-50',
            document: 'border-amber-400 bg-amber-50',
            buttons: 'border-indigo-400 bg-indigo-50',
            delay: 'border-orange-400 bg-orange-50',
            subscribe: 'border-green-400 bg-green-50',
            unsubscribe: 'border-red-400 bg-red-50'
        };
        return colors[type] || 'border-slate-300 bg-white';
    }

    function getNodeHeaderColor(type: string): string {
        const colors: Record<string, string> = {
            start: 'bg-emerald-500',
            text: 'bg-blue-500',
            image: 'bg-purple-500',
            video: 'bg-pink-500',
            document: 'bg-amber-500',
            buttons: 'bg-indigo-500',
            delay: 'bg-orange-500',
            subscribe: 'bg-green-600',
            unsubscribe: 'bg-red-600'
        };
        return colors[type] || 'bg-slate-500';
    }

    function handleTriggerWordKeydown(e: KeyboardEvent, lang: 'en' | 'ar') {
        if (e.key === 'Enter') { e.preventDefault(); addFlowTriggerWord(lang); }
    }

    // ─── Media Upload ─────────────────────────────
    function getAcceptTypes(nodeType: string): string {
        switch (nodeType) {
            case 'image': return 'image/jpeg,image/png,image/webp';
            case 'video': return 'video/mp4,video/3gpp';
            case 'document': return '.pdf,.doc,.docx,.xls,.xlsx,.ppt,.pptx,.txt';
            default: return '*/*';
        }
    }

    function triggerMediaUpload() {
        if (!selectedNode || uploading) return;
        if (fileInputEl) {
            fileInputEl.accept = getAcceptTypes(selectedNode.type);
            fileInputEl.click();
        }
    }

    async function handleMediaUpload(event: Event) {
        const input = event.target as HTMLInputElement;
        const file = input?.files?.[0];
        if (!file || !selectedNode || !editingFlow) return;

        uploading = true;
        uploadProgress = 'Uploading...';
        try {
            const ext = file.name.split('.').pop() || 'bin';
            const fileName = `flow_${selectedNode.type}_${Date.now()}.${ext}`;
            const filePath = `${accountId}/flows/${fileName}`;

            const { error: uploadErr } = await supabase.storage.from('whatsapp-media').upload(filePath, file, {
                contentType: file.type,
                upsert: false
            });
            if (uploadErr) throw uploadErr;

            const { data: urlData } = supabase.storage.from('whatsapp-media').getPublicUrl(filePath);
            const publicUrl = urlData?.publicUrl;
            if (!publicUrl) throw new Error('Failed to get public URL');

            selectedNode.data.mediaUrl = publicUrl;
            if (selectedNode.type === 'document' && !selectedNode.data.filename) {
                selectedNode.data.filename = file.name;
            }
            editingFlow.nodes = [...editingFlow.nodes];
            uploadProgress = '✅ Uploaded!';
            setTimeout(() => uploadProgress = '', 3000);
        } catch (e: any) {
            uploadProgress = '❌ ' + e.message;
            setTimeout(() => uploadProgress = '', 5000);
        } finally {
            uploading = false;
            if (input) input.value = '';
        }
    }
</script>

<div class="h-full flex flex-col bg-[#f0f2f5] overflow-hidden font-sans" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
    <!-- Header -->
    <div class="bg-white border-b border-slate-200 px-6 py-3 flex items-center justify-between shrink-0">
        <div class="flex items-center gap-3">
            <span class="text-2xl">🔀</span>
            <h1 class="text-lg font-black text-slate-800 uppercase tracking-wide">Flow Builder</h1>
        </div>
        {#if activeView === 'list'}
            <button class="px-6 py-2.5 bg-emerald-600 text-white font-bold text-xs rounded-xl hover:bg-emerald-700 shadow-lg shadow-emerald-200"
                on:click={createNewFlow}>
                + New Flow
            </button>
        {:else}
            <div class="flex items-center gap-3">
                <input type="text" bind:value={editingFlow.name} placeholder="Flow name"
                    class="px-4 py-2 bg-slate-50 border border-slate-200 rounded-xl text-sm font-bold focus:outline-none focus:ring-2 focus:ring-emerald-500 w-56" />
                <label class="flex items-center gap-2 cursor-pointer text-xs font-bold text-slate-600">
                    <input type="checkbox" bind:checked={editingFlow.is_active} class="w-4 h-4 rounded text-emerald-600" />
                    Active
                </label>
                <button class="px-5 py-2 bg-slate-200 text-slate-700 font-bold text-xs rounded-xl hover:bg-slate-300"
                    on:click={() => { activeView = 'list'; editingFlow = null; selectedNodeId = null; }}>
                    ← Back
                </button>
                <button class="px-6 py-2 bg-emerald-600 text-white font-bold text-xs rounded-xl hover:bg-emerald-700 shadow-lg disabled:opacity-50"
                    on:click={saveFlow} disabled={saving}>
                    {saving ? '⏳ Saving...' : '💾 Save Flow'}
                </button>
            </div>
        {/if}
    </div>

    {#if loading}
        <div class="flex-1 flex items-center justify-center">
            <div class="animate-spin w-10 h-10 border-4 border-emerald-200 border-t-emerald-600 rounded-full"></div>
        </div>

    {:else if activeView === 'list'}
        <!-- ═══ Flow List ═══ -->
        <div class="flex-1 overflow-y-auto p-6">
            {#if flows.length === 0}
                <div class="flex flex-col items-center justify-center py-20">
                    <div class="text-5xl mb-4">🔀</div>
                    <h3 class="text-lg font-bold text-slate-600">No Bot Flows</h3>
                    <p class="text-sm text-slate-400 mt-1">Create visual conversation flows with the drag-and-drop builder</p>
                    <button class="mt-4 px-6 py-2.5 bg-emerald-600 text-white font-bold text-xs rounded-xl hover:bg-emerald-700"
                        on:click={createNewFlow}>+ Create Flow</button>
                </div>
            {:else}
                <div class="space-y-3 max-w-4xl">
                    {#each flows as flow, idx}
                        <div class="bg-white/60 backdrop-blur-xl border border-white/40 rounded-2xl p-5 hover:shadow-lg transition-all {!flow.is_active ? 'opacity-60' : ''}">
                            <div class="flex items-start justify-between">
                                <div class="flex-1">
                                    <div class="flex items-center gap-2">
                                        <span class="text-xs text-slate-400 font-mono">#{flow.priority}</span>
                                        <h3 class="font-bold text-sm text-slate-800">{flow.name}</h3>
                                        <span class="px-2 py-0.5 text-[10px] font-bold rounded-full bg-emerald-100 text-emerald-600">
                                            {flow.nodes?.length || 0} nodes
                                        </span>
                                        <span class="px-2 py-0.5 text-[10px] font-bold rounded-full {flow.match_type === 'exact' ? 'bg-blue-100 text-blue-600' : 'bg-amber-100 text-amber-600'}">
                                            {flow.match_type}
                                        </span>
                                    </div>
                                    <div class="flex flex-wrap gap-1 mt-2">
                                        {#each (flow.trigger_words_en || []) as word}
                                            <span class="px-2 py-0.5 text-[10px] bg-emerald-100 text-emerald-700 rounded-full font-bold">🇺🇸 {word}</span>
                                        {/each}
                                        {#each (flow.trigger_words_ar || []) as word}
                                            <span class="px-2 py-0.5 text-[10px] bg-blue-100 text-blue-700 rounded-full font-bold">🇸🇦 {word}</span>
                                        {/each}
                                    </div>
                                </div>
                                <div class="flex items-center gap-2 ml-4">
                                    <button class="w-8 h-8 rounded-lg flex items-center justify-center text-sm transition-colors
                                        {flow.is_active ? 'bg-emerald-100 text-emerald-600' : 'bg-slate-100 text-slate-400'}"
                                        on:click={() => toggleFlow(flow)}>
                                        {flow.is_active ? '✅' : '⏸️'}
                                    </button>
                                    <button class="w-8 h-8 bg-blue-100 text-blue-600 rounded-lg flex items-center justify-center text-sm hover:bg-blue-200"
                                        on:click={() => editFlow(flow)}>✏️</button>
                                    <button class="w-8 h-8 bg-red-100 text-red-600 rounded-lg flex items-center justify-center text-sm hover:bg-red-200"
                                        on:click={() => deleteFlow(flow.id)}>🗑️</button>
                                </div>
                            </div>
                        </div>
                    {/each}
                </div>
            {/if}
        </div>

    {:else if activeView === 'editor' && editingFlow}
        <!-- ═══ Flow Editor ═══ -->
        <div class="flex-1 flex overflow-hidden">
            <!-- ─── Toolbox (Left) ─── -->
            <div class="w-56 bg-white border-r border-slate-200 p-4 flex flex-col gap-2 shrink-0 overflow-y-auto">
                <p class="text-[10px] font-bold text-slate-400 uppercase mb-1">Drag to canvas</p>
                {#each [
                    { type: 'text' as FlowNode['type'], label: '💬 Text Message' },
                    { type: 'image' as FlowNode['type'], label: '🖼️ Image' },
                    { type: 'video' as FlowNode['type'], label: '🎥 Video' },
                    { type: 'document' as FlowNode['type'], label: '📎 Document' },
                    { type: 'buttons' as FlowNode['type'], label: '🔘 Buttons' },
                    { type: 'delay' as FlowNode['type'], label: '⏱️ Delay' },
                    { type: 'subscribe' as FlowNode['type'], label: '✅ Subscribe' },
                    { type: 'unsubscribe' as FlowNode['type'], label: '🚫 Unsubscribe' }
                ] as item}
                    <button class="w-full text-left px-3 py-2.5 bg-slate-50 hover:bg-slate-100 border border-slate-200 rounded-xl text-xs font-bold text-slate-700 transition-all hover:shadow-sm hover:border-emerald-300"
                        on:click={() => addNode(item.type)}>
                        {item.label}
                    </button>
                {/each}

                <div class="mt-auto pt-3 border-t border-slate-200">
                    <p class="text-[10px] text-slate-400 font-bold uppercase mb-1">Controls</p>
                    <p class="text-[9px] text-slate-400">• Click node to select</p>
                    <p class="text-[9px] text-slate-400">• Drag node to move</p>
                    <p class="text-[9px] text-slate-400">• Drag ● port to connect</p>
                    <p class="text-[9px] text-slate-400">• Alt+drag to pan canvas</p>
                    <p class="text-[9px] text-slate-400">• Scroll to zoom</p>
                </div>
            </div>

            <!-- ─── Canvas (Center) ─── -->
            <div class="flex-1 relative overflow-hidden bg-[#f8f9fc]"
                bind:this={canvasEl}
                on:mousedown={onCanvasMouseDown}
                on:mousemove={onCanvasMouseMove}
                on:mouseup={onCanvasMouseUp}
                on:mouseleave={onCanvasMouseUp}
                on:wheel|preventDefault={onWheel}
                role="application"
                tabindex="0"
            >
                <!-- Grid background -->
                <div class="absolute inset-0 pointer-events-none" style="background-image: radial-gradient(circle, #d1d5db 1px, transparent 1px); background-size: {20 * zoom}px {20 * zoom}px; background-position: {canvasOffset.x * zoom}px {canvasOffset.y * zoom}px;"></div>

                <!-- Zoom indicator -->
                <div class="absolute top-3 right-3 bg-white/80 backdrop-blur px-3 py-1.5 rounded-lg text-[10px] font-bold text-slate-500 z-20">
                    {Math.round(zoom * 100)}%
                </div>

                <!-- Transform group -->
                <div class="absolute inset-0" style="transform: scale({zoom}); transform-origin: 0 0;">
                    <div style="transform: translate({canvasOffset.x}px, {canvasOffset.y}px);">
                        <!-- SVG Edges -->
                        <svg class="absolute inset-0 w-[4000px] h-[4000px] pointer-events-none" style="overflow: visible;">
                            <defs>
                                <marker id="arrowhead" markerWidth="8" markerHeight="6" refX="8" refY="3" orient="auto">
                                    <polygon points="0 0, 8 3, 0 6" fill="#94a3b8" />
                                </marker>
                            </defs>
                            {#each flowEdges as edge}
                                <path d={getEdgePath(edge)} fill="none" stroke="#94a3b8" stroke-width="2" marker-end="url(#arrowhead)"
                                    class="cursor-pointer hover:stroke-red-400 pointer-events-auto" stroke-dasharray=""
                                    on:click={() => deleteEdge(edge.id)} role="button" tabindex="0" on:keydown={() => {}} />
                            {/each}
                            {#if drawingEdge}
                                <path d={getDrawingEdgePath()} fill="none" stroke="#10b981" stroke-width="2" stroke-dasharray="6 3" />
                            {/if}
                        </svg>

                        <!-- Nodes -->
                        {#each flowNodes as node (node.id)}
                            {@const h = getNodeHeight(node)}
                            <div class="flow-node absolute select-none cursor-grab active:cursor-grabbing"
                                style="left: {node.x}px; top: {node.y}px; width: {NODE_W}px;"
                                on:mousedown={(e) => onNodeMouseDown(node.id, e)}
                                on:mouseup={() => { if (drawingEdge) finishDrawingEdge(node.id); }}
                                role="button" tabindex="0" on:keydown={() => {}}
                            >
                                <div class="rounded-xl border-2 shadow-lg overflow-hidden transition-shadow
                                    {getNodeColor(node.type)}
                                    {selectedNodeId === node.id ? 'ring-2 ring-emerald-400 shadow-emerald-200/50' : 'hover:shadow-xl'}">

                                    <!-- Node Header -->
                                    <div class="flex items-center gap-1.5 px-3 py-1.5 {getNodeHeaderColor(node.type)} text-white">
                                        <span class="text-xs">{getNodeIcon(node.type)}</span>
                                        <span class="text-[10px] font-black uppercase tracking-wider flex-1 truncate">
                                            {node.data.label || node.type}
                                        </span>
                                        {#if node.type !== 'start'}
                                            <button class="text-white/60 hover:text-white text-xs leading-none"
                                                on:mousedown|stopPropagation={() => {}}
                                                on:click|stopPropagation={() => deleteNode(node.id)}>✕</button>
                                        {/if}
                                    </div>

                                    <!-- Node Body -->
                                    <div class="px-3 py-2 text-[10px] text-slate-600">
                                        {#if node.type === 'start'}
                                            <div class="flex flex-wrap gap-0.5">
                                                {#each (node.data.triggerWords || []) as w}
                                                    <span class="px-1.5 py-0.5 bg-emerald-200 text-emerald-800 rounded text-[9px] font-bold">{w}</span>
                                                {/each}
                                                {#each (node.data.triggerWordsAr || []) as w}
                                                    <span class="px-1.5 py-0.5 bg-blue-200 text-blue-800 rounded text-[9px] font-bold">{w}</span>
                                                {/each}
                                                {#if !(node.data.triggerWords?.length) && !(node.data.triggerWordsAr?.length)}
                                                    <span class="text-slate-400 italic">Set keywords →</span>
                                                {/if}
                                            </div>
                                        {:else if node.type === 'text'}
                                            <p class="line-clamp-2">{node.data.text || 'Empty text'}</p>
                                        {:else if node.type === 'image' || node.type === 'video' || node.type === 'document'}
                                            <p class="truncate">{node.data.mediaUrl ? '📂 Media set' : '⚠️ No media'}</p>
                                            {#if node.data.caption}<p class="truncate text-[9px] text-slate-400">{node.data.caption}</p>{/if}
                                        {:else if node.type === 'buttons'}
                                            <p class="line-clamp-1 mb-1">{node.data.text || 'Button message'}</p>
                                            {#each (node.data.buttons || []) as btn, bi}
                                                <div class="flex items-center gap-1 mt-0.5">
                                                    <span class="text-[8px] shrink-0 w-3">{btn.type === 'url' ? '🔗' : btn.type === 'phone' ? '📞' : '↩️'}</span>
                                                    <span class="px-2 py-0.5 rounded text-[9px] font-bold flex-1 truncate
                                                        {btn.type === 'url' ? 'bg-cyan-200 text-cyan-800' : btn.type === 'phone' ? 'bg-amber-200 text-amber-800' : 'bg-indigo-200 text-indigo-800'}">
                                                        {btn.title || '...'}
                                                    </span>
                                                    {#if btn.type === 'quick_reply' && btn.action && btn.action !== 'none'}
                                                        <span class="text-[7px] shrink-0 {btn.action === 'subscribe' ? 'text-green-500' : 'text-red-500'}">{btn.action === 'subscribe' ? '✅' : '🚫'}</span>
                                                    {/if}
                                                </div>
                                            {/each}
                                        {:else if node.type === 'delay'}
                                            <p>⏳ {node.data.delaySeconds || 0}s</p>
                                        {:else if node.type === 'subscribe'}
                                            <p class="text-green-700 font-bold">✅ Subscribe</p>
                                        {:else if node.type === 'unsubscribe'}
                                            <p class="text-red-700 font-bold">🚫 Unsubscribe</p>
                                        {/if}
                                    </div>
                                </div>

                                <!-- Input port (left) -->
                                {#if node.type !== 'start'}
                                    <div class="absolute -left-2 top-1/2 -translate-y-1/2 w-4 h-4 rounded-full bg-slate-400 border-2 border-white shadow cursor-crosshair hover:bg-emerald-500 hover:scale-125 transition-all z-10"
                                        on:mouseup|stopPropagation={() => { if (drawingEdge) finishDrawingEdge(node.id); }}
                                        role="button" tabindex="0" on:keydown={() => {}}></div>
                                {/if}

                                <!-- Output port (right) -->
                                <div class="absolute -right-2 top-1/2 -translate-y-1/2 w-4 h-4 rounded-full bg-emerald-500 border-2 border-white shadow cursor-crosshair hover:scale-125 transition-all z-10"
                                    on:mousedown|stopPropagation={(e) => startDrawingEdge(node.id, 'out', e)}
                                    role="button" tabindex="0" on:keydown={() => {}}></div>
                            </div>
                        {/each}
                    </div>
                </div>
            </div>

            <!-- ─── Properties Panel (Right) ─── -->
            <div class="w-72 bg-white border-l border-slate-200 overflow-y-auto shrink-0">
                {#if selectedNode}
                    <div class="p-4 space-y-4">
                        <div class="flex items-center gap-2">
                            <span class="text-lg">{getNodeIcon(selectedNode.type)}</span>
                            <h3 class="text-sm font-black text-slate-800 uppercase">{selectedNode.type} Properties</h3>
                        </div>

                        <!-- Label -->
                        <div>
                            <label class="block text-[10px] font-bold text-slate-500 uppercase mb-1">Label</label>
                            <input type="text" bind:value={selectedNode.data.label}
                                class="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-lg text-xs focus:outline-none focus:ring-2 focus:ring-emerald-500"
                                on:input={() => { editingFlow.nodes = [...editingFlow.nodes]; }} />
                        </div>

                        <!-- START node props -->
                        {#if selectedNode.type === 'start'}
                            <div>
                                <label class="block text-[10px] font-bold text-slate-500 uppercase mb-1">Match Type</label>
                                <div class="flex gap-1">
                                    {#each ['contains', 'exact', 'starts_with', 'regex'] as mt}
                                        <button class="px-2 py-1 text-[10px] font-bold rounded-lg
                                            {selectedNode.data.matchType === mt ? 'bg-emerald-600 text-white' : 'bg-slate-100 text-slate-600'}"
                                            on:click={() => { selectedNode.data.matchType = mt; editingFlow.nodes = [...editingFlow.nodes]; }}>
                                            {mt}
                                        </button>
                                    {/each}
                                </div>
                            </div>
                            <div>
                                <label class="block text-[10px] font-bold text-slate-500 uppercase mb-1">🇺🇸 English Keywords</label>
                                <div class="flex gap-1">
                                    <input type="text" bind:value={triggerWordInput} placeholder="Add keyword"
                                        class="flex-1 px-2 py-1.5 bg-slate-50 border border-slate-200 rounded-lg text-[10px]"
                                        on:keydown={(e) => handleTriggerWordKeydown(e, 'en')} />
                                    <button class="px-2 py-1 bg-emerald-100 text-emerald-700 text-[10px] font-bold rounded-lg"
                                        on:click={() => addFlowTriggerWord('en')}>+</button>
                                </div>
                                <div class="flex flex-wrap gap-1 mt-1">
                                    {#each (selectedNode.data.triggerWords || []) as w, i}
                                        <span class="px-1.5 py-0.5 bg-emerald-100 text-emerald-700 text-[9px] rounded-full font-bold flex items-center gap-0.5">
                                            {w} <button class="text-emerald-400 hover:text-red-500" on:click={() => removeFlowTriggerWord('en', i)}>✕</button>
                                        </span>
                                    {/each}
                                </div>
                            </div>
                            <div>
                                <label class="block text-[10px] font-bold text-slate-500 uppercase mb-1">🇸🇦 Arabic Keywords</label>
                                <div class="flex gap-1">
                                    <input type="text" bind:value={triggerWordArInput} placeholder="أضف كلمة" dir="rtl"
                                        class="flex-1 px-2 py-1.5 bg-slate-50 border border-slate-200 rounded-lg text-[10px]"
                                        on:keydown={(e) => handleTriggerWordKeydown(e, 'ar')} />
                                    <button class="px-2 py-1 bg-blue-100 text-blue-700 text-[10px] font-bold rounded-lg"
                                        on:click={() => addFlowTriggerWord('ar')}>+</button>
                                </div>
                                <div class="flex flex-wrap gap-1 mt-1">
                                    {#each (selectedNode.data.triggerWordsAr || []) as w, i}
                                        <span class="px-1.5 py-0.5 bg-blue-100 text-blue-700 text-[9px] rounded-full font-bold flex items-center gap-0.5">
                                            {w} <button class="text-blue-400 hover:text-red-500" on:click={() => removeFlowTriggerWord('ar', i)}>✕</button>
                                        </span>
                                    {/each}
                                </div>
                            </div>

                        <!-- TEXT node -->
                        {:else if selectedNode.type === 'text'}
                            <div>
                                <label class="block text-[10px] font-bold text-slate-500 uppercase mb-1">Message Text</label>
                                <textarea bind:value={selectedNode.data.text} rows="4" placeholder="Type message..."
                                    class="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-lg text-xs resize-none focus:outline-none focus:ring-2 focus:ring-emerald-500"
                                    on:input={() => { editingFlow.nodes = [...editingFlow.nodes]; }}></textarea>
                            </div>

                        <!-- IMAGE / VIDEO / DOCUMENT -->
                        {:else if selectedNode.type === 'image' || selectedNode.type === 'video' || selectedNode.type === 'document'}
                            <input type="file" bind:this={fileInputEl} class="hidden" on:change={handleMediaUpload} />
                            <div>
                                <label class="block text-[10px] font-bold text-slate-500 uppercase mb-1">Media</label>
                                <!-- svelte-ignore a11y-no-static-element-interactions -->
                                <div class="w-full rounded-xl border-2 border-dashed transition-all cursor-pointer
                                    {selectedNode.data.mediaUrl ? 'border-emerald-300 bg-emerald-50' : 'border-slate-300 bg-slate-50 hover:border-emerald-400 hover:bg-emerald-50/50'}"
                                    on:dblclick={triggerMediaUpload}>
                                    {#if uploading}
                                        <div class="flex flex-col items-center justify-center py-6">
                                            <div class="w-6 h-6 border-2 border-emerald-300 border-t-emerald-600 rounded-full animate-spin mb-2"></div>
                                            <span class="text-[10px] font-bold text-emerald-600">{uploadProgress}</span>
                                        </div>
                                    {:else if selectedNode.data.mediaUrl}
                                        <div class="p-3">
                                            {#if selectedNode.type === 'image'}
                                                <img src={selectedNode.data.mediaUrl} alt="Preview" class="w-full max-h-32 object-cover rounded-lg mb-2" />
                                            {:else if selectedNode.type === 'video'}
                                                <video src={selectedNode.data.mediaUrl} class="w-full max-h-32 rounded-lg mb-2" controls></video>
                                            {:else}
                                                <div class="flex items-center gap-2 mb-2">
                                                    <span class="text-2xl">📎</span>
                                                    <span class="text-xs font-bold text-slate-700 truncate">{selectedNode.data.filename || 'Document'}</span>
                                                </div>
                                            {/if}
                                            <p class="text-[9px] text-slate-400 truncate">{selectedNode.data.mediaUrl}</p>
                                            <div class="flex items-center gap-2 mt-2">
                                                <span class="text-[9px] text-emerald-600 font-bold">{uploadProgress || 'Double-click to replace'}</span>
                                                <button class="text-[9px] text-red-400 hover:text-red-600 font-bold ml-auto"
                                                    on:click|stopPropagation={() => { selectedNode.data.mediaUrl = ''; editingFlow.nodes = [...editingFlow.nodes]; }}>✕ Remove</button>
                                            </div>
                                        </div>
                                    {:else}
                                        <div class="flex flex-col items-center justify-center py-6">
                                            <span class="text-2xl mb-1">
                                                {selectedNode.type === 'image' ? '🖼️' : selectedNode.type === 'video' ? '🎥' : '📎'}
                                            </span>
                                            <span class="text-[10px] font-bold text-slate-500">Double-click to upload</span>
                                            <span class="text-[9px] text-slate-400 mt-0.5">
                                                {selectedNode.type === 'image' ? 'JPG, PNG, WebP' : selectedNode.type === 'video' ? 'MP4, 3GPP' : 'PDF, DOC, XLS, etc.'}
                                            </span>
                                        </div>
                                    {/if}
                                </div>
                            </div>
                            <div>
                                <label class="block text-[10px] font-bold text-slate-500 uppercase mb-1">Caption</label>
                                <textarea bind:value={selectedNode.data.caption} rows="2" placeholder="Caption (optional)"
                                    class="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-lg text-xs resize-none focus:outline-none focus:ring-2 focus:ring-emerald-500"
                                    on:input={() => { editingFlow.nodes = [...editingFlow.nodes]; }}></textarea>
                            </div>
                            {#if selectedNode.type === 'document'}
                                <div>
                                    <label class="block text-[10px] font-bold text-slate-500 uppercase mb-1">Filename</label>
                                    <input type="text" bind:value={selectedNode.data.filename} placeholder="file.pdf"
                                        class="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-lg text-xs focus:outline-none focus:ring-2 focus:ring-emerald-500" />
                                </div>
                            {/if}

                        <!-- BUTTONS -->
                        {:else if selectedNode.type === 'buttons'}
                            <div>
                                <label class="block text-[10px] font-bold text-slate-500 uppercase mb-1">Body Text</label>
                                <textarea bind:value={selectedNode.data.text} rows="2" placeholder="Choose an option"
                                    class="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-lg text-xs resize-none focus:outline-none focus:ring-2 focus:ring-emerald-500"
                                    on:input={() => { editingFlow.nodes = [...editingFlow.nodes]; }}></textarea>
                            </div>

                            <!-- Combination Rules -->
                            <div class="bg-slate-50 rounded-xl p-3 border border-slate-200">
                                <p class="text-[10px] font-black text-slate-600 uppercase mb-2">📌 Button Rules</p>
                                <div class="space-y-1">
                                    {#each [
                                        { combo: '3 Quick Replies', ok: true },
                                        { combo: '2 CTA + 1 Quick Reply', ok: true },
                                        { combo: '1 CTA + 2 Quick Replies', ok: true },
                                        { combo: '3 CTA buttons', ok: false },
                                        { combo: '4 buttons total', ok: false }
                                    ] as rule}
                                        <div class="flex items-center gap-1.5">
                                            <span class="text-[9px]">{rule.ok ? '✅' : '❌'}</span>
                                            <span class="text-[9px] text-slate-500">{rule.combo}</span>
                                        </div>
                                    {/each}
                                </div>
                                <div class="mt-2 pt-2 border-t border-slate-200 flex items-center gap-3">
                                    <span class="text-[9px] font-bold {buttonCounts.total >= 3 ? 'text-red-500' : 'text-slate-500'}">
                                        {buttonCounts.total}/3 total
                                    </span>
                                    <span class="text-[9px] font-bold {buttonCounts.cta >= 2 ? 'text-amber-500' : 'text-slate-500'}">
                                        {buttonCounts.cta}/2 CTA
                                    </span>
                                    <span class="text-[9px] font-bold text-slate-500">
                                        {buttonCounts.qr} QR
                                    </span>
                                </div>
                            </div>

                            <div>
                                <div class="flex items-center justify-between mb-2">
                                    <label class="text-[10px] font-bold text-slate-500 uppercase">Buttons</label>
                                </div>

                                {#each (selectedNode.data.buttons || []) as btn, idx}
                                    <div class="mb-2 p-2 bg-slate-50 rounded-xl border border-slate-200">
                                        <div class="flex items-center gap-1 mb-1.5">
                                            <!-- Type selector -->
                                            <select class="px-1.5 py-1 bg-white border border-slate-200 rounded-lg text-[9px] font-bold"
                                                value={btn.type}
                                                on:change={(e) => changeButtonType(idx, e.currentTarget.value)}>
                                                <option value="quick_reply">↩️ Quick Reply</option>
                                                <option value="url" disabled={btn.type !== 'url' && buttonCounts.cta >= 2}>🔗 URL</option>
                                                <option value="phone" disabled={btn.type !== 'phone' && buttonCounts.cta >= 2}>📞 Phone</option>
                                            </select>
                                            <input type="text" bind:value={btn.title} placeholder="Button text"
                                                class="flex-1 px-2 py-1 bg-white border border-slate-200 rounded-lg text-[10px]"
                                                on:input={() => { editingFlow.nodes = [...editingFlow.nodes]; }} />
                                            <button class="text-red-400 hover:text-red-600 text-xs shrink-0" on:click={() => removeButtonFromNode(idx)}>✕</button>
                                        </div>
                                        {#if btn.type === 'url'}
                                            <input type="url" bind:value={btn.url} placeholder="https://..."
                                                class="w-full px-2 py-1 bg-white border border-slate-200 rounded-lg text-[10px] mt-1"
                                                on:input={() => { editingFlow.nodes = [...editingFlow.nodes]; }} />
                                        {:else if btn.type === 'phone'}
                                            <input type="tel" bind:value={btn.phone} placeholder="+966..."
                                                class="w-full px-2 py-1 bg-white border border-slate-200 rounded-lg text-[10px] mt-1"
                                                on:input={() => { editingFlow.nodes = [...editingFlow.nodes]; }} />
                                        {:else if btn.type === 'quick_reply'}
                                            <!-- Action dropdown for quick_reply buttons -->
                                            <select class="w-full px-2 py-1 bg-white border border-slate-200 rounded-lg text-[10px] mt-1 font-bold"
                                                bind:value={btn.action}>
                                                <option value="none">— بدون إجراء</option>
                                                <option value="subscribe">✅ اشتراك</option>
                                                <option value="unsubscribe">🚫 إلغاء الاشتراك</option>
                                            </select>
                                        {/if}
                                    </div>
                                {/each}

                                <!-- Add button options -->
                                {#if buttonCounts.total < 3}
                                    <div class="flex gap-1 mt-2">
                                        {#if canAddQuickReply}
                                            <button class="flex-1 px-2 py-1.5 bg-indigo-100 text-indigo-700 text-[9px] font-bold rounded-lg hover:bg-indigo-200 transition-colors"
                                                on:click={() => addButtonToNode('quick_reply')}>+ ↩️ Quick Reply</button>
                                        {/if}
                                        {#if canAddCTA}
                                            <button class="flex-1 px-2 py-1.5 bg-cyan-100 text-cyan-700 text-[9px] font-bold rounded-lg hover:bg-cyan-200 transition-colors"
                                                on:click={() => addButtonToNode('url')}>+ 🔗 URL</button>
                                            <button class="flex-1 px-2 py-1.5 bg-amber-100 text-amber-700 text-[9px] font-bold rounded-lg hover:bg-amber-200 transition-colors"
                                                on:click={() => addButtonToNode('phone')}>+ 📞 Phone</button>
                                        {/if}
                                    </div>
                                {:else}
                                    <p class="text-[9px] text-red-400 font-bold text-center mt-1">Maximum 3 buttons reached</p>
                                {/if}

                                <p class="text-[9px] text-slate-400 mt-2">💡 Quick Reply buttons can trigger Subscribe/Unsubscribe actions via the dropdown</p>
                            </div>

                        <!-- DELAY -->
                        {:else if selectedNode.type === 'delay'}
                            <div>
                                <label class="block text-[10px] font-bold text-slate-500 uppercase mb-1">Delay (seconds)</label>
                                <input type="number" bind:value={selectedNode.data.delaySeconds} min="1" max="86400"
                                    class="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-lg text-xs focus:outline-none focus:ring-2 focus:ring-emerald-500"
                                    on:input={() => { editingFlow.nodes = [...editingFlow.nodes]; }} />
                                <p class="text-[9px] text-slate-400 mt-1">
                                    = {Math.floor((selectedNode.data.delaySeconds || 0) / 3600)}h {Math.floor(((selectedNode.data.delaySeconds || 0) % 3600) / 60)}m {(selectedNode.data.delaySeconds || 0) % 60}s
                                </p>
                            </div>

                        <!-- SUBSCRIBE -->
                        {:else if selectedNode.type === 'subscribe'}
                            <div class="bg-green-50 border border-green-200 rounded-lg p-3">
                                <p class="text-[10px] font-bold text-green-800 mb-1">✅ Subscribe Action</p>
                                <p class="text-[9px] text-green-600">Sets the customer as subscribed (is_deleted = false). The customer will be able to receive messages again.</p>
                            </div>
                            <div>
                                <label class="block text-[10px] font-bold text-slate-500 uppercase mb-1">Confirmation Message (optional)</label>
                                <textarea bind:value={selectedNode.data.text} rows="3"
                                    placeholder="You have been subscribed successfully!"
                                    class="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-lg text-xs focus:outline-none focus:ring-2 focus:ring-emerald-500 resize-none"
                                    on:input={() => { editingFlow.nodes = [...editingFlow.nodes]; }}></textarea>
                                <p class="text-[9px] text-slate-400 mt-1">If set, this message will be sent to the customer after subscribing.</p>
                            </div>

                        <!-- UNSUBSCRIBE -->
                        {:else if selectedNode.type === 'unsubscribe'}
                            <div class="bg-red-50 border border-red-200 rounded-lg p-3">
                                <p class="text-[10px] font-bold text-red-800 mb-1">🚫 Unsubscribe Action</p>
                                <p class="text-[9px] text-red-600">Sets the customer as unsubscribed (is_deleted = true). The customer will no longer receive broadcast messages.</p>
                            </div>
                            <div>
                                <label class="block text-[10px] font-bold text-slate-500 uppercase mb-1">Confirmation Message (optional)</label>
                                <textarea bind:value={selectedNode.data.text} rows="3"
                                    placeholder="You have been unsubscribed. You will no longer receive messages."
                                    class="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-lg text-xs focus:outline-none focus:ring-2 focus:ring-emerald-500 resize-none"
                                    on:input={() => { editingFlow.nodes = [...editingFlow.nodes]; }}></textarea>
                                <p class="text-[9px] text-slate-400 mt-1">If set, this message will be sent to the customer after unsubscribing.</p>
                            </div>
                        {/if}
                    </div>
                {:else}
                    <div class="flex flex-col items-center justify-center h-full text-center p-6">
                        <div class="text-4xl mb-3">👈</div>
                        <p class="text-xs font-bold text-slate-500">Select a node to edit its properties</p>
                        <p class="text-[10px] text-slate-400 mt-2">Or add new nodes from the toolbox on the left</p>
                    </div>
                {/if}
            </div>
        </div>
    {/if}
</div>
