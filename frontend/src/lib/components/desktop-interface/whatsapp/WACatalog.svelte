<script lang="ts">
    import { onMount } from 'svelte';
    import { _ as t, locale } from '$lib/i18n';

    // ─── Interfaces ───
    interface WAAccount {
        id: string;
        name: string;
        phone_number: string;
        phone_number_id: string;
        waba_id: string;
        access_token: string;
        is_default: boolean;
    }

    interface Catalog {
        id: string;
        wa_account_id: string;
        meta_catalog_id: string;
        name: string;
        description: string;
        status: string;
        product_count: number;
        synced_at: string;
        created_at: string;
        updated_at: string;
    }

    interface Product {
        id: string;
        catalog_id: string;
        wa_account_id: string;
        meta_product_id: string;
        retailer_id: string;
        name: string;
        description: string;
        price: number;
        currency: string;
        sale_price: number | null;
        image_url: string;
        additional_images: string[];
        url: string;
        category: string;
        availability: string;
        condition: string;
        brand: string;
        sku: string;
        quantity: number;
        is_hidden: boolean;
        status: string;
        synced_at: string;
        created_at: string;
        updated_at: string;
    }

    interface Order {
        id: string;
        wa_account_id: string;
        catalog_id: string;
        customer_phone: string;
        customer_name: string;
        order_status: string;
        items: any[];
        subtotal: number;
        tax: number;
        shipping: number;
        total: number;
        currency: string;
        notes: string;
        meta_order_id: string;
        created_at: string;
        updated_at: string;
    }

    interface CatalogStats {
        total_catalogs: number;
        total_products: number;
        active_products: number;
        hidden_products: number;
        total_orders: number;
        pending_orders: number;
        total_revenue: number;
    }

    // ─── State ───
    let supabase: any = null;
    let account: WAAccount | null = null;
    let accounts: WAAccount[] = [];
    let loading = true;
    let error = '';
    let successMsg = '';
    let saving = false;

    // Tabs
    let activeTab: 'overview' | 'catalogs' | 'products' | 'orders' = 'overview';
    const tabs: { id: typeof activeTab; label: string; icon: string }[] = [
        { id: 'overview', label: 'Overview', icon: '📊' },
        { id: 'catalogs', label: 'Catalogs', icon: '📂' },
        { id: 'products', label: 'Products', icon: '📦' },
        { id: 'orders', label: 'Orders', icon: '🛒' }
    ];

    function getSelectValue(e: Event): string {
        return (e.target as HTMLSelectElement).value;
    }

    // Data
    let catalogs: Catalog[] = [];
    let products: Product[] = [];
    let filteredProducts: Product[] = [];
    let orders: Order[] = [];
    let filteredOrders: Order[] = [];
    let stats: CatalogStats = { total_catalogs: 0, total_products: 0, active_products: 0, hidden_products: 0, total_orders: 0, pending_orders: 0, total_revenue: 0 };

    // Filters
    let searchQuery = '';
    let catalogFilter = 'all';
    let statusFilter = 'all';
    let orderStatusFilter = 'all';

    // Modals
    let showCatalogModal = false;
    let showProductModal = false;
    let showOrderModal = false;
    let editingCatalog: Catalog | null = null;
    let editingProduct: Product | null = null;
    let viewingOrder: Order | null = null;

    // Forms
    let catalogForm = { name: '', description: '', meta_catalog_id: '' };
    let productForm = {
        catalog_id: '',
        retailer_id: '',
        name: '',
        description: '',
        price: 0,
        currency: 'SAR',
        sale_price: null as number | null,
        image_url: '',
        url: '',
        category: '',
        availability: 'in stock',
        condition: 'new',
        brand: '',
        sku: '',
        quantity: 0
    };

    const availabilityOptions = [
        { value: 'in stock', label: 'In Stock', icon: '🟢' },
        { value: 'out of stock', label: 'Out of Stock', icon: '🔴' },
        { value: 'preorder', label: 'Pre-order', icon: '🟡' },
        { value: 'discontinued', label: 'Discontinued', icon: '⚫' }
    ];

    const conditionOptions = [
        { value: 'new', label: 'New' },
        { value: 'refurbished', label: 'Refurbished' },
        { value: 'used', label: 'Used' }
    ];

    const currencyOptions = ['SAR', 'AED', 'USD', 'EUR', 'GBP', 'INR', 'EGP', 'KWD', 'BHD', 'OMR', 'QAR'];

    const orderStatuses = [
        { value: 'pending', label: 'Pending', color: 'text-yellow-400' },
        { value: 'confirmed', label: 'Confirmed', color: 'text-blue-400' },
        { value: 'processing', label: 'Processing', color: 'text-purple-400' },
        { value: 'shipped', label: 'Shipped', color: 'text-cyan-400' },
        { value: 'delivered', label: 'Delivered', color: 'text-emerald-400' },
        { value: 'cancelled', label: 'Cancelled', color: 'text-red-400' },
        { value: 'refunded', label: 'Refunded', color: 'text-orange-400' }
    ];

    // ─── Lifecycle ───
    onMount(async () => {
        const mod = await import('$lib/utils/supabase');
        supabase = mod.supabase;
        await loadAccounts();
    });

    // ─── Data Loading ───
    async function loadAccounts() {
        try {
            const { data } = await supabase
                .from('wa_accounts')
                .select('*')
                .order('is_default', { ascending: false });
            accounts = data || [];
            if (accounts.length > 0) {
                account = accounts.find((a: WAAccount) => a.is_default) || accounts[0];
                await loadAllData();
            } else {
                loading = false;
            }
        } catch (e: any) {
            error = e.message;
            loading = false;
        }
    }

    async function loadAllData() {
        loading = true;
        error = '';
        try {
            await Promise.all([loadCatalogs(), loadProducts(), loadOrders(), loadStats()]);
        } catch (e: any) {
            error = e.message;
        } finally {
            loading = false;
        }
    }

    async function loadCatalogs() {
        const { data, error: e } = await supabase
            .from('wa_catalogs')
            .select('*')
            .eq('wa_account_id', account!.id)
            .order('created_at', { ascending: false });
        if (e) throw e;
        catalogs = data || [];
    }

    async function loadProducts() {
        const { data, error: e } = await supabase
            .from('wa_catalog_products')
            .select('*')
            .eq('wa_account_id', account!.id)
            .order('created_at', { ascending: false });
        if (e) throw e;
        products = data || [];
        applyProductFilters();
    }

    async function loadOrders() {
        const { data, error: e } = await supabase
            .from('wa_catalog_orders')
            .select('*')
            .eq('wa_account_id', account!.id)
            .order('created_at', { ascending: false });
        if (e) throw e;
        orders = data || [];
        applyOrderFilters();
    }

    async function loadStats() {
        const { data, error: e } = await supabase.rpc('get_wa_catalog_stats', { p_account_id: account!.id });
        if (e) throw e;
        if (data && data.length > 0) stats = data[0];
    }

    // ─── Filters ───
    function applyProductFilters() {
        let f = [...products];
        if (searchQuery) {
            const q = searchQuery.toLowerCase();
            f = f.filter(p => p.name?.toLowerCase().includes(q) || p.sku?.toLowerCase().includes(q) || p.brand?.toLowerCase().includes(q) || p.retailer_id?.toLowerCase().includes(q));
        }
        if (catalogFilter !== 'all') f = f.filter(p => p.catalog_id === catalogFilter);
        if (statusFilter === 'active') f = f.filter(p => p.status === 'active' && !p.is_hidden);
        else if (statusFilter === 'hidden') f = f.filter(p => p.is_hidden);
        else if (statusFilter === 'out_of_stock') f = f.filter(p => p.availability === 'out of stock');
        filteredProducts = f;
    }

    function applyOrderFilters() {
        let f = [...orders];
        if (searchQuery) {
            const q = searchQuery.toLowerCase();
            f = f.filter(o => o.customer_name?.toLowerCase().includes(q) || o.customer_phone?.includes(q) || o.meta_order_id?.toLowerCase().includes(q));
        }
        if (orderStatusFilter !== 'all') f = f.filter(o => o.order_status === orderStatusFilter);
        filteredOrders = f;
    }

    $: if (searchQuery !== undefined || catalogFilter || statusFilter) {
        if (activeTab === 'products') applyProductFilters();
        else if (activeTab === 'orders') applyOrderFilters();
    }

    // ─── Catalog CRUD ───
    function openNewCatalog() {
        editingCatalog = null;
        catalogForm = { name: '', description: '', meta_catalog_id: '' };
        showCatalogModal = true;
    }

    function openEditCatalog(cat: Catalog) {
        editingCatalog = cat;
        catalogForm = { name: cat.name, description: cat.description || '', meta_catalog_id: cat.meta_catalog_id || '' };
        showCatalogModal = true;
    }

    async function saveCatalog() {
        if (!catalogForm.name.trim()) { error = 'Catalog name is required'; return; }
        saving = true;
        error = '';
        try {
            if (editingCatalog) {
                const { error: e } = await supabase
                    .from('wa_catalogs')
                    .update({ name: catalogForm.name, description: catalogForm.description, meta_catalog_id: catalogForm.meta_catalog_id, updated_at: new Date().toISOString() })
                    .eq('id', editingCatalog.id);
                if (e) throw e;
                successMsg = 'Catalog updated!';
            } else {
                const { error: e } = await supabase
                    .from('wa_catalogs')
                    .insert({ wa_account_id: account!.id, name: catalogForm.name, description: catalogForm.description, meta_catalog_id: catalogForm.meta_catalog_id });
                if (e) throw e;
                successMsg = 'Catalog created!';
            }
            showCatalogModal = false;
            await loadCatalogs();
            await loadStats();
        } catch (e: any) {
            error = e.message;
        } finally {
            saving = false;
            setTimeout(() => successMsg = '', 3000);
        }
    }

    async function deleteCatalog(cat: Catalog) {
        if (!confirm(`Delete catalog "${cat.name}"? All products in this catalog will also be deleted.`)) return;
        try {
            const { error: e } = await supabase.from('wa_catalogs').delete().eq('id', cat.id);
            if (e) throw e;
            successMsg = 'Catalog deleted!';
            await loadCatalogs();
            await loadProducts();
            await loadStats();
        } catch (e: any) {
            error = e.message;
        }
        setTimeout(() => successMsg = '', 3000);
    }

    // ─── Product CRUD ───
    function openNewProduct() {
        editingProduct = null;
        productForm = {
            catalog_id: catalogs.length > 0 ? catalogs[0].id : '',
            retailer_id: '', name: '', description: '', price: 0, currency: 'SAR',
            sale_price: null, image_url: '', url: '', category: '',
            availability: 'in stock', condition: 'new', brand: '', sku: '', quantity: 0
        };
        showProductModal = true;
    }

    function openEditProduct(prod: Product) {
        editingProduct = prod;
        productForm = {
            catalog_id: prod.catalog_id,
            retailer_id: prod.retailer_id || '',
            name: prod.name,
            description: prod.description || '',
            price: prod.price,
            currency: prod.currency || 'SAR',
            sale_price: prod.sale_price,
            image_url: prod.image_url || '',
            url: prod.url || '',
            category: prod.category || '',
            availability: prod.availability || 'in stock',
            condition: prod.condition || 'new',
            brand: prod.brand || '',
            sku: prod.sku || '',
            quantity: prod.quantity || 0
        };
        showProductModal = true;
    }

    async function saveProduct() {
        if (!productForm.name.trim()) { error = 'Product name is required'; return; }
        if (!productForm.catalog_id) { error = 'Please select a catalog'; return; }
        saving = true;
        error = '';
        try {
            const payload = {
                catalog_id: productForm.catalog_id,
                wa_account_id: account!.id,
                retailer_id: productForm.retailer_id || null,
                name: productForm.name,
                description: productForm.description || null,
                price: productForm.price,
                currency: productForm.currency,
                sale_price: productForm.sale_price || null,
                image_url: productForm.image_url || null,
                url: productForm.url || null,
                category: productForm.category || null,
                availability: productForm.availability,
                condition: productForm.condition,
                brand: productForm.brand || null,
                sku: productForm.sku || null,
                quantity: productForm.quantity,
                updated_at: new Date().toISOString()
            };
            if (editingProduct) {
                const { error: e } = await supabase.from('wa_catalog_products').update(payload).eq('id', editingProduct.id);
                if (e) throw e;
                successMsg = 'Product updated!';
            } else {
                const { error: e } = await supabase.from('wa_catalog_products').insert(payload);
                if (e) throw e;
                successMsg = 'Product created!';
            }
            showProductModal = false;
            await loadProducts();
            await updateCatalogProductCount(productForm.catalog_id);
            await loadStats();
        } catch (e: any) {
            error = e.message;
        } finally {
            saving = false;
            setTimeout(() => successMsg = '', 3000);
        }
    }

    async function deleteProduct(prod: Product) {
        if (!confirm(`Delete product "${prod.name}"?`)) return;
        try {
            const { error: e } = await supabase.from('wa_catalog_products').delete().eq('id', prod.id);
            if (e) throw e;
            successMsg = 'Product deleted!';
            await loadProducts();
            await updateCatalogProductCount(prod.catalog_id);
            await loadStats();
        } catch (e: any) {
            error = e.message;
        }
        setTimeout(() => successMsg = '', 3000);
    }

    async function toggleProductHidden(prod: Product) {
        try {
            const { error: e } = await supabase
                .from('wa_catalog_products')
                .update({ is_hidden: !prod.is_hidden, updated_at: new Date().toISOString() })
                .eq('id', prod.id);
            if (e) throw e;
            await loadProducts();
            await loadStats();
        } catch (e: any) {
            error = e.message;
        }
    }

    async function updateCatalogProductCount(catalogId: string) {
        const count = products.filter(p => p.catalog_id === catalogId).length;
        await supabase.from('wa_catalogs').update({ product_count: count, updated_at: new Date().toISOString() }).eq('id', catalogId);
        await loadCatalogs();
    }

    // ─── Order Management ───
    function viewOrder(order: Order) {
        viewingOrder = order;
        showOrderModal = true;
    }

    async function updateOrderStatus(orderId: string, newStatus: string) {
        try {
            const { error: e } = await supabase
                .from('wa_catalog_orders')
                .update({ order_status: newStatus, updated_at: new Date().toISOString() })
                .eq('id', orderId);
            if (e) throw e;
            successMsg = `Order status updated to ${newStatus}`;
            await loadOrders();
            await loadStats();
        } catch (e: any) {
            error = e.message;
        }
        setTimeout(() => successMsg = '', 3000);
    }

    // ─── Meta Commerce API Sync ───
    let syncing = false;

    async function syncCatalogsFromMeta() {
        if (!account?.waba_id || !account?.access_token) {
            error = 'Missing WABA ID or Access Token. Configure in WA Accounts.';
            return;
        }
        syncing = true;
        error = '';
        try {
            const res = await fetch(`https://graph.facebook.com/v22.0/${account.waba_id}/product_catalogs?access_token=${account.access_token}`);
            const json = await res.json();
            if (json.error) throw new Error(json.error.message);
            const metaCatalogs = json.data || [];
            for (const mc of metaCatalogs) {
                const existing = catalogs.find(c => c.meta_catalog_id === mc.id);
                if (existing) {
                    await supabase.from('wa_catalogs').update({ name: mc.name || existing.name, synced_at: new Date().toISOString() }).eq('id', existing.id);
                } else {
                    await supabase.from('wa_catalogs').insert({ wa_account_id: account!.id, meta_catalog_id: mc.id, name: mc.name || `Catalog ${mc.id}`, synced_at: new Date().toISOString() });
                }
            }
            successMsg = `Synced ${metaCatalogs.length} catalog(s) from Meta`;
            await loadCatalogs();
            await loadStats();
        } catch (e: any) {
            error = `Sync failed: ${e.message}`;
        } finally {
            syncing = false;
            setTimeout(() => successMsg = '', 4000);
        }
    }

    async function syncProductsFromMeta(catalog: Catalog) {
        if (!catalog.meta_catalog_id || !account?.access_token) {
            error = 'Missing Meta Catalog ID or Access Token.';
            return;
        }
        syncing = true;
        error = '';
        try {
            const fields = 'id,name,description,price,currency,image_url,url,category,availability,condition,brand,retailer_id';
            const res = await fetch(`https://graph.facebook.com/v22.0/${catalog.meta_catalog_id}/products?fields=${fields}&access_token=${account.access_token}`);
            const json = await res.json();
            if (json.error) throw new Error(json.error.message);
            const metaProducts = json.data || [];
            let synced = 0;
            for (const mp of metaProducts) {
                const priceNum = mp.price ? parseFloat(String(mp.price).replace(/[^0-9.]/g, '')) : 0;
                const existing = products.find(p => p.meta_product_id === mp.id);
                const payload = {
                    meta_product_id: mp.id,
                    retailer_id: mp.retailer_id || null,
                    name: mp.name || 'Unnamed',
                    description: mp.description || null,
                    price: priceNum,
                    currency: mp.currency || 'SAR',
                    image_url: mp.image_url || null,
                    url: mp.url || null,
                    category: mp.category || null,
                    availability: mp.availability || 'in stock',
                    condition: mp.condition || 'new',
                    brand: mp.brand || null,
                    synced_at: new Date().toISOString()
                };
                if (existing) {
                    await supabase.from('wa_catalog_products').update(payload).eq('id', existing.id);
                } else {
                    await supabase.from('wa_catalog_products').insert({ ...payload, catalog_id: catalog.id, wa_account_id: account!.id });
                }
                synced++;
            }
            successMsg = `Synced ${synced} product(s) from Meta`;
            await loadProducts();
            await updateCatalogProductCount(catalog.id);
            await loadStats();
        } catch (e: any) {
            error = `Product sync failed: ${e.message}`;
        } finally {
            syncing = false;
            setTimeout(() => successMsg = '', 4000);
        }
    }

    // ─── Account Switch ───
    async function switchAccount(e: Event) {
        const target = e.target as HTMLSelectElement;
        const acc = accounts.find(a => a.id === target.value);
        if (acc) {
            account = acc;
            await loadAllData();
        }
    }

    // ─── Helpers ───
    function formatDate(dateStr: string) {
        if (!dateStr) return '—';
        return new Date(dateStr).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
    }

    function formatDateTime(dateStr: string) {
        if (!dateStr) return '—';
        return new Date(dateStr).toLocaleString('en-US', { month: 'short', day: 'numeric', year: 'numeric', hour: '2-digit', minute: '2-digit' });
    }

    function formatCurrency(amount: number, currency: string = 'SAR') {
        return `${currency} ${Number(amount).toFixed(2)}`;
    }

    function getStatusBadge(status: string): string {
        const map: Record<string, string> = {
            active: 'bg-emerald-100 text-emerald-800 border-emerald-300',
            inactive: 'bg-slate-100 text-slate-600 border-slate-300',
            pending: 'bg-yellow-100 text-yellow-800 border-yellow-300',
            confirmed: 'bg-blue-100 text-blue-800 border-blue-300',
            processing: 'bg-purple-100 text-purple-800 border-purple-300',
            shipped: 'bg-cyan-100 text-cyan-800 border-cyan-300',
            delivered: 'bg-emerald-100 text-emerald-800 border-emerald-300',
            cancelled: 'bg-red-100 text-red-800 border-red-300',
            refunded: 'bg-orange-100 text-orange-800 border-orange-300'
        };
        return map[status] || 'bg-slate-100 text-slate-600 border-slate-300';
    }

    function getCatalogName(catalogId: string): string {
        return catalogs.find(c => c.id === catalogId)?.name || '—';
    }
</script>

<!-- ═══════════════ MAIN CONTAINER ═══════════════ -->
<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>

    <!-- Header/Navigation -->
    <div class="bg-white border-b border-slate-200 px-6 py-4 flex items-center gap-4 shadow-sm flex-wrap overflow-visible relative z-50">
        <!-- Account selector -->
        {#if accounts.length > 0}
            <div class="relative z-[60]">
                <select
                    value={account?.id || ''}
                    on:change={switchAccount}
                    class="bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-xs text-slate-700 cursor-pointer min-w-[180px] font-semibold focus:ring-2 focus:ring-emerald-300 focus:border-emerald-400 outline-none"
                >
                    {#each accounts as acc}
                        <option value={acc.id}>📱 {acc.name} — {acc.phone_number || ''}</option>
                    {/each}
                </select>
            </div>
        {/if}

        <!-- Tabs -->
        <div class="flex gap-2 bg-slate-100 p-1.5 rounded-2xl border border-slate-200/50 shadow-inner ml-auto">
            {#each tabs as tab}
                <button 
                    class="group relative flex items-center gap-2.5 px-6 py-2.5 text-xs font-black uppercase tracking-wide transition-all duration-500 rounded-xl overflow-hidden
                    {activeTab === tab.id 
                        ? 'bg-emerald-600 text-white shadow-lg shadow-emerald-200 scale-[1.02]'
                        : 'text-slate-500 hover:bg-white hover:text-slate-800 hover:shadow-md'}"
                    on:click={() => { activeTab = tab.id; searchQuery = ''; }}
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

    <!-- Messages -->
    {#if error}
        <div class="px-6 py-2 bg-red-50 border-b border-red-200 text-red-700 text-xs flex items-center gap-2">
            <span>⚠️</span> {error}
            <button on:click={() => error = ''} class="ml-auto text-red-400 hover:text-red-600 bg-transparent border-none cursor-pointer text-sm">✕</button>
        </div>
    {/if}
    {#if successMsg}
        <div class="px-6 py-2 bg-emerald-50 border-b border-emerald-200 text-emerald-700 text-xs flex items-center gap-2">
            <span>✅</span> {successMsg}
        </div>
    {/if}

    <!-- Main Content Area -->
    <div class="flex-1 p-8 relative overflow-y-auto bg-[radial-gradient(ellipse_at_top_right,_var(--tw-gradient-stops))] from-white via-slate-50/50 to-slate-100/50">
        <!-- Decorative blurred circles -->
        <div class="absolute top-0 right-0 w-[500px] h-[500px] bg-emerald-100/20 rounded-full blur-[120px] -mr-64 -mt-64 animate-pulse pointer-events-none"></div>
        <div class="absolute bottom-0 left-0 w-[500px] h-[500px] bg-purple-100/20 rounded-full blur-[120px] -ml-64 -mb-64 animate-pulse pointer-events-none" style="animation-delay: 2s;"></div>

        <div class="relative max-w-[99%] mx-auto h-full flex flex-col">

            <!-- LOADING -->
            {#if loading}
                <div class="flex items-center justify-center h-full">
                    <div class="text-center">
                        <div class="animate-spin inline-block">
                            <div class="w-12 h-12 border-4 border-emerald-200 border-t-emerald-600 rounded-full"></div>
                        </div>
                        <p class="mt-4 text-slate-600 font-semibold">Loading catalog data...</p>
                    </div>
                </div>

            <!-- NO ACCOUNT -->
            {:else if !account}
                <div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-12 h-full flex flex-col items-center justify-center border-dashed border-2 border-slate-200">
                    <span class="text-6xl mb-4">📱</span>
                    <p class="text-slate-600 font-semibold text-lg">No WhatsApp account configured.</p>
                    <p class="text-slate-400 text-sm mt-1">Set up an account in WA Accounts first.</p>
                </div>

            <!-- ═══ OVERVIEW TAB ═══ -->
            {:else if activeTab === 'overview'}
                <!-- Stats Cards -->
                <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-7 gap-4 mb-6">
                    <div class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-lg p-5 hover:shadow-xl transition-shadow">
                        <div class="text-[10px] text-slate-400 font-black uppercase tracking-wider mb-2">📂 Catalogs</div>
                        <div class="text-3xl font-black text-emerald-600">{stats.total_catalogs}</div>
                    </div>
                    <div class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-lg p-5 hover:shadow-xl transition-shadow">
                        <div class="text-[10px] text-slate-400 font-black uppercase tracking-wider mb-2">📦 Products</div>
                        <div class="text-3xl font-black text-blue-600">{stats.total_products}</div>
                    </div>
                    <div class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-lg p-5 hover:shadow-xl transition-shadow">
                        <div class="text-[10px] text-slate-400 font-black uppercase tracking-wider mb-2">✅ Active</div>
                        <div class="text-3xl font-black text-emerald-600">{stats.active_products}</div>
                    </div>
                    <div class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-lg p-5 hover:shadow-xl transition-shadow">
                        <div class="text-[10px] text-slate-400 font-black uppercase tracking-wider mb-2">👁️‍🗨️ Hidden</div>
                        <div class="text-3xl font-black text-amber-500">{stats.hidden_products}</div>
                    </div>
                    <div class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-lg p-5 hover:shadow-xl transition-shadow">
                        <div class="text-[10px] text-slate-400 font-black uppercase tracking-wider mb-2">🛒 Orders</div>
                        <div class="text-3xl font-black text-purple-600">{stats.total_orders}</div>
                    </div>
                    <div class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-lg p-5 hover:shadow-xl transition-shadow">
                        <div class="text-[10px] text-slate-400 font-black uppercase tracking-wider mb-2">⏳ Pending</div>
                        <div class="text-3xl font-black text-amber-500">{stats.pending_orders}</div>
                    </div>
                    <div class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-lg p-5 hover:shadow-xl transition-shadow">
                        <div class="text-[10px] text-slate-400 font-black uppercase tracking-wider mb-2">💰 Revenue</div>
                        <div class="text-2xl font-black text-emerald-600">{formatCurrency(stats.total_revenue)}</div>
                    </div>
                </div>

                <!-- Quick Actions -->
                <div class="bg-white/40 backdrop-blur-xl rounded-2xl border border-white shadow-lg p-6 mb-6">
                    <div class="text-xs font-black text-slate-700 uppercase tracking-wider mb-4">⚡ Quick Actions</div>
                    <div class="flex flex-wrap gap-3">
                        <button on:click={openNewCatalog} class="inline-flex items-center gap-2 px-5 py-2.5 rounded-xl font-black text-xs text-white bg-emerald-600 hover:bg-emerald-700 hover:shadow-lg transition-all duration-200 transform hover:scale-105 shadow-md border-none cursor-pointer">
                            + New Catalog
                        </button>
                        <button on:click={openNewProduct} class="inline-flex items-center gap-2 px-5 py-2.5 rounded-xl font-black text-xs text-white bg-blue-600 hover:bg-blue-700 hover:shadow-lg transition-all duration-200 transform hover:scale-105 shadow-md border-none cursor-pointer">
                            + New Product
                        </button>
                        <button on:click={syncCatalogsFromMeta} disabled={syncing} class="inline-flex items-center gap-2 px-5 py-2.5 rounded-xl font-black text-xs text-white bg-purple-600 hover:bg-purple-700 hover:shadow-lg transition-all duration-200 transform hover:scale-105 shadow-md border-none cursor-pointer disabled:opacity-50">
                            {syncing ? '⏳ Syncing...' : '🔄 Sync from Meta'}
                        </button>
                        <button on:click={() => loadAllData()} class="inline-flex items-center gap-2 px-5 py-2.5 rounded-xl font-bold text-xs text-slate-600 bg-white hover:bg-slate-50 hover:shadow-lg transition-all duration-200 shadow-md border border-slate-200 cursor-pointer">
                            🔄 Refresh
                        </button>
                    </div>
                </div>

                <!-- Catalogs Grid -->
                {#if catalogs.length > 0}
                    <div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-6">
                        <div class="text-xs font-black text-slate-700 uppercase tracking-wider mb-4">📂 Your Catalogs</div>
                        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
                            {#each catalogs as cat}
                                <div class="bg-white/70 backdrop-blur-sm rounded-2xl border border-slate-200 p-4 flex flex-col gap-2 hover:shadow-lg transition-shadow">
                                    <div class="flex justify-between items-center">
                                        <span class="text-sm font-black text-slate-800">📂 {cat.name}</span>
                                        <span class="px-2 py-0.5 rounded-full text-[10px] font-bold border {getStatusBadge(cat.status)}">{cat.status}</span>
                                    </div>
                                    {#if cat.description}
                                        <p class="text-[11px] text-slate-400 leading-relaxed">{cat.description}</p>
                                    {/if}
                                    <div class="flex justify-between items-center text-[11px] text-slate-400">
                                        <span>📦 {cat.product_count} products</span>
                                        {#if cat.meta_catalog_id}
                                            <span class="font-mono">🔗 {cat.meta_catalog_id.substring(0, 12)}...</span>
                                        {/if}
                                    </div>
                                    <div class="flex gap-2 mt-1">
                                        <button on:click={() => openEditCatalog(cat)} class="flex-1 px-3 py-1.5 rounded-lg bg-slate-100 text-slate-700 text-[11px] font-bold border border-slate-200 cursor-pointer hover:bg-slate-200 transition-colors">✏️ Edit</button>
                                        <button on:click={() => syncProductsFromMeta(cat)} disabled={syncing || !cat.meta_catalog_id} class="flex-1 px-3 py-1.5 rounded-lg bg-purple-50 text-purple-700 text-[11px] font-bold border border-purple-200 cursor-pointer hover:bg-purple-100 transition-colors disabled:opacity-40">🔄 Sync</button>
                                        <button on:click={() => { activeTab = 'products'; catalogFilter = cat.id; }} class="flex-1 px-3 py-1.5 rounded-lg bg-blue-50 text-blue-700 text-[11px] font-bold border border-blue-200 cursor-pointer hover:bg-blue-100 transition-colors">📦 View</button>
                                    </div>
                                </div>
                            {/each}
                        </div>
                    </div>
                {/if}

    <!-- ═══ CATALOGS TAB ═══ -->
            {:else if activeTab === 'catalogs'}
                <!-- Toolbar -->
                <div class="flex items-center gap-3 mb-4 flex-wrap">
                    <button on:click={openNewCatalog} class="inline-flex items-center gap-2 px-5 py-2.5 rounded-xl font-black text-xs text-white bg-emerald-600 hover:bg-emerald-700 hover:shadow-lg transition-all duration-200 transform hover:scale-105 shadow-md border-none cursor-pointer">
                        + New Catalog
                    </button>
                    <button on:click={syncCatalogsFromMeta} disabled={syncing} class="inline-flex items-center gap-2 px-5 py-2.5 rounded-xl font-black text-xs text-white bg-purple-600 hover:bg-purple-700 hover:shadow-lg transition-all duration-200 transform hover:scale-105 shadow-md border-none cursor-pointer disabled:opacity-50">
                        {syncing ? '⏳ Syncing...' : '🔄 Sync from Meta'}
                    </button>
                    <span class="ml-auto text-xs text-slate-400 font-semibold">{catalogs.length} catalog{catalogs.length !== 1 ? 's' : ''}</span>
                </div>

                {#if catalogs.length === 0}
                    <div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-12 h-full flex flex-col items-center justify-center border-dashed border-2 border-slate-200">
                        <span class="text-6xl mb-4">📂</span>
                        <p class="text-slate-600 font-semibold text-lg">No catalogs yet.</p>
                        <p class="text-slate-400 text-sm mt-1">Create a new catalog or sync from Meta.</p>
                    </div>
                {:else}
                    <div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden flex flex-col">
                        <div class="overflow-x-auto flex-1">
                            <table class="w-full border-collapse [&_th]:border-x [&_th]:border-emerald-500/30 [&_td]:border-x [&_td]:border-slate-200">
                                <thead class="sticky top-0 bg-emerald-600 text-white shadow-lg z-10">
                                    <tr>
                                        <th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Name</th>
                                        <th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Meta ID</th>
                                        <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Products</th>
                                        <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Status</th>
                                        <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Synced</th>
                                        <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Actions</th>
                                    </tr>
                                </thead>
                                <tbody class="divide-y divide-slate-200">
                                    {#each catalogs as cat, i}
                                        <tr class="hover:bg-emerald-50/30 transition-colors duration-200 {i % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'}">
                                            <td class="px-4 py-3 text-sm text-slate-700">
                                                <div class="font-bold">📂 {cat.name}</div>
                                                {#if cat.description}<div class="text-xs text-slate-400 mt-0.5">{cat.description}</div>{/if}
                                            </td>
                                            <td class="px-4 py-3 text-xs text-slate-400 font-mono">{cat.meta_catalog_id || '—'}</td>
                                            <td class="px-4 py-3 text-center">
                                                <span class="inline-block px-3 py-0.5 rounded-full text-[11px] font-black bg-blue-100 text-blue-700">{cat.product_count}</span>
                                            </td>
                                            <td class="px-4 py-3 text-center">
                                                <span class="px-2 py-0.5 rounded-full text-[10px] font-bold border {getStatusBadge(cat.status)}">{cat.status}</span>
                                            </td>
                                            <td class="px-4 py-3 text-center text-xs text-slate-400">{cat.synced_at ? formatDate(cat.synced_at) : 'Never'}</td>
                                            <td class="px-4 py-3 text-center">
                                                <div class="flex gap-2 justify-center">
                                                    <button on:click={() => openEditCatalog(cat)} title="Edit" class="inline-flex items-center justify-center px-3 py-1.5 rounded-lg bg-emerald-600 text-white text-xs font-bold hover:bg-emerald-700 hover:shadow-lg transition-all duration-200 transform hover:scale-105 border-none cursor-pointer">✏️</button>
                                                    <button on:click={() => syncProductsFromMeta(cat)} disabled={syncing || !cat.meta_catalog_id} title="Sync" class="inline-flex items-center justify-center px-3 py-1.5 rounded-lg bg-purple-100 text-purple-700 text-xs font-bold hover:bg-purple-200 transition-all duration-200 border-none cursor-pointer disabled:opacity-30">🔄</button>
                                                    <button on:click={() => deleteCatalog(cat)} title="Delete" class="inline-flex items-center justify-center px-3 py-1.5 rounded-lg bg-red-100 text-red-700 text-xs font-bold hover:bg-red-200 transition-all duration-200 border-none cursor-pointer">🗑️</button>
                                                </div>
                                            </td>
                                        </tr>
                                    {/each}
                                </tbody>
                            </table>
                        </div>
                        <div class="px-6 py-3 bg-slate-100/50 border-t border-slate-200 text-xs text-slate-600 font-semibold">
                            Showing {catalogs.length} catalog{catalogs.length !== 1 ? 's' : ''}
                        </div>
                    </div>
                {/if}

    <!-- ═══ PRODUCTS TAB ═══ -->
            {:else if activeTab === 'products'}
                <!-- Toolbar -->
                <div class="flex items-center gap-3 mb-4 flex-wrap">
                    <button on:click={openNewProduct} class="inline-flex items-center gap-2 px-5 py-2.5 rounded-xl font-black text-xs text-white bg-blue-600 hover:bg-blue-700 hover:shadow-lg transition-all duration-200 transform hover:scale-105 shadow-md border-none cursor-pointer">
                        + New Product
                    </button>
                    <input
                        bind:value={searchQuery}
                        placeholder="🔍 Search products..."
                        class="px-4 py-2 rounded-xl bg-white border border-slate-200 text-slate-700 text-xs min-w-[180px] focus:ring-2 focus:ring-emerald-300 focus:border-emerald-400 outline-none shadow-sm"
                    />
                    <select bind:value={catalogFilter} on:change={applyProductFilters} class="px-3 py-2 rounded-xl bg-white border border-slate-200 text-slate-700 text-xs cursor-pointer focus:ring-2 focus:ring-emerald-300 outline-none shadow-sm">
                        <option value="all">All Catalogs</option>
                        {#each catalogs as cat}
                            <option value={cat.id}>{cat.name}</option>
                        {/each}
                    </select>
                    <select bind:value={statusFilter} on:change={applyProductFilters} class="px-3 py-2 rounded-xl bg-white border border-slate-200 text-slate-700 text-xs cursor-pointer focus:ring-2 focus:ring-emerald-300 outline-none shadow-sm">
                        <option value="all">All Status</option>
                        <option value="active">Active</option>
                        <option value="hidden">Hidden</option>
                        <option value="out_of_stock">Out of Stock</option>
                    </select>
                    <span class="ml-auto text-xs text-slate-400 font-semibold">{filteredProducts.length} of {products.length} products</span>
                </div>

                {#if filteredProducts.length === 0}
                    <div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-12 h-full flex flex-col items-center justify-center border-dashed border-2 border-slate-200">
                        <span class="text-6xl mb-4">📦</span>
                        <p class="text-slate-600 font-semibold text-lg">No products found.</p>
                        <p class="text-slate-400 text-sm mt-1">{products.length === 0 ? 'Add products or sync from Meta.' : 'Try adjusting your filters.'}</p>
                    </div>
                {:else}
                    <div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden flex flex-col">
                        <div class="overflow-x-auto flex-1">
                            <table class="w-full border-collapse [&_th]:border-x [&_th]:border-emerald-500/30 [&_td]:border-x [&_td]:border-slate-200">
                                <thead class="sticky top-0 bg-emerald-600 text-white shadow-lg z-10">
                                    <tr>
                                        <th class="px-3 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Image</th>
                                        <th class="px-3 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Product</th>
                                        <th class="px-3 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">SKU</th>
                                        <th class="px-3 py-3 text-right text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Price</th>
                                        <th class="px-3 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Qty</th>
                                        <th class="px-3 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Availability</th>
                                        <th class="px-3 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Catalog</th>
                                        <th class="px-3 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Visible</th>
                                        <th class="px-3 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Actions</th>
                                    </tr>
                                </thead>
                                <tbody class="divide-y divide-slate-200">
                                    {#each filteredProducts as prod, i}
                                        <tr class="hover:bg-emerald-50/30 transition-colors duration-200 {i % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'}">
                                            <td class="px-3 py-2">
                                                {#if prod.image_url}
                                                    <img src={prod.image_url} alt={prod.name} class="w-10 h-10 rounded-lg object-contain bg-white border border-slate-200" />
                                                {:else}
                                                    <div class="w-10 h-10 rounded-lg bg-slate-100 flex items-center justify-center text-base border border-slate-200">📷</div>
                                                {/if}
                                            </td>
                                            <td class="px-3 py-2 text-sm text-slate-700">
                                                <div class="font-bold max-w-[200px] whitespace-nowrap overflow-hidden text-ellipsis">{prod.name}</div>
                                                {#if prod.brand}<div class="text-xs text-slate-400">{prod.brand}</div>{/if}
                                            </td>
                                            <td class="px-3 py-2 text-xs text-slate-400 font-mono">{prod.sku || '—'}</td>
                                            <td class="px-3 py-2 text-right">
                                                <div class="font-bold text-emerald-700 text-sm">{formatCurrency(prod.price, prod.currency)}</div>
                                                {#if prod.sale_price}
                                                    <div class="text-[10px] text-amber-600 font-semibold">Sale: {formatCurrency(prod.sale_price, prod.currency)}</div>
                                                {/if}
                                            </td>
                                            <td class="px-3 py-2 text-center text-sm font-bold text-slate-700">{prod.quantity}</td>
                                            <td class="px-3 py-2 text-center text-xs text-slate-600">
                                                {availabilityOptions.find(a => a.value === prod.availability)?.icon || '⚪'}
                                                {prod.availability}
                                            </td>
                                            <td class="px-3 py-2 text-center text-xs text-slate-400">{getCatalogName(prod.catalog_id)}</td>
                                            <td class="px-3 py-2 text-center">
                                                <button
                                                    on:click={() => toggleProductHidden(prod)}
                                                    title={prod.is_hidden ? 'Show product' : 'Hide product'}
                                                    class="bg-transparent border-none cursor-pointer text-base hover:scale-110 transition-transform"
                                                >
                                                    {prod.is_hidden ? '🙈' : '👁️'}
                                                </button>
                                            </td>
                                            <td class="px-3 py-2 text-center">
                                                <div class="flex gap-1.5 justify-center">
                                                    <button on:click={() => openEditProduct(prod)} title="Edit" class="inline-flex items-center justify-center px-2.5 py-1 rounded-lg bg-emerald-600 text-white text-xs font-bold hover:bg-emerald-700 hover:shadow-lg transition-all duration-200 transform hover:scale-105 border-none cursor-pointer">✏️</button>
                                                    <button on:click={() => deleteProduct(prod)} title="Delete" class="inline-flex items-center justify-center px-2.5 py-1 rounded-lg bg-red-100 text-red-700 text-xs font-bold hover:bg-red-200 transition-all duration-200 border-none cursor-pointer">🗑️</button>
                                                </div>
                                            </td>
                                        </tr>
                                    {/each}
                                </tbody>
                            </table>
                        </div>
                        <div class="px-6 py-3 bg-slate-100/50 border-t border-slate-200 text-xs text-slate-600 font-semibold">
                            Showing {filteredProducts.length} of {products.length} products
                        </div>
                    </div>
                {/if}

    <!-- ═══ ORDERS TAB ═══ -->
            {:else if activeTab === 'orders'}
                <!-- Toolbar -->
                <div class="flex items-center gap-3 mb-4 flex-wrap">
                    <input
                        bind:value={searchQuery}
                        placeholder="🔍 Search orders..."
                        class="px-4 py-2 rounded-xl bg-white border border-slate-200 text-slate-700 text-xs min-w-[180px] focus:ring-2 focus:ring-emerald-300 focus:border-emerald-400 outline-none shadow-sm"
                    />
                    <select bind:value={orderStatusFilter} on:change={applyOrderFilters} class="px-3 py-2 rounded-xl bg-white border border-slate-200 text-slate-700 text-xs cursor-pointer focus:ring-2 focus:ring-emerald-300 outline-none shadow-sm">
                        <option value="all">All Statuses</option>
                        {#each orderStatuses as os}
                            <option value={os.value}>{os.label}</option>
                        {/each}
                    </select>
                    <span class="ml-auto text-xs text-slate-400 font-semibold">{filteredOrders.length} order{filteredOrders.length !== 1 ? 's' : ''}</span>
                </div>

                {#if filteredOrders.length === 0}
                    <div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-12 h-full flex flex-col items-center justify-center border-dashed border-2 border-slate-200">
                        <span class="text-6xl mb-4">🛒</span>
                        <p class="text-slate-600 font-semibold text-lg">No orders yet.</p>
                        <p class="text-slate-400 text-sm mt-1">Orders from WhatsApp Commerce will appear here.</p>
                    </div>
                {:else}
                    <div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden flex flex-col">
                        <div class="overflow-x-auto flex-1">
                            <table class="w-full border-collapse [&_th]:border-x [&_th]:border-emerald-500/30 [&_td]:border-x [&_td]:border-slate-200">
                                <thead class="sticky top-0 bg-emerald-600 text-white shadow-lg z-10">
                                    <tr>
                                        <th class="px-3 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Order</th>
                                        <th class="px-3 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Customer</th>
                                        <th class="px-3 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Items</th>
                                        <th class="px-3 py-3 text-right text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Total</th>
                                        <th class="px-3 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Status</th>
                                        <th class="px-3 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Date</th>
                                        <th class="px-3 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Actions</th>
                                    </tr>
                                </thead>
                                <tbody class="divide-y divide-slate-200">
                                    {#each filteredOrders as order, i}
                                        <tr class="hover:bg-emerald-50/30 transition-colors duration-200 {i % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'}">
                                            <td class="px-3 py-2.5">
                                                <div class="font-bold text-slate-700 font-mono text-sm">#{order.id.substring(0, 8)}</div>
                                                {#if order.meta_order_id}<div class="text-[10px] text-slate-400">Meta: {order.meta_order_id}</div>{/if}
                                            </td>
                                            <td class="px-3 py-2.5">
                                                <div class="font-bold text-slate-700 text-sm">{order.customer_name || '—'}</div>
                                                <div class="text-xs text-slate-400">{order.customer_phone}</div>
                                            </td>
                                            <td class="px-3 py-2.5 text-center">
                                                <span class="bg-blue-100 text-blue-700 px-2 py-0.5 rounded-full text-xs font-bold">{Array.isArray(order.items) ? order.items.length : 0}</span>
                                            </td>
                                            <td class="px-3 py-2.5 text-right">
                                                <div class="font-bold text-emerald-700 text-sm">{formatCurrency(order.total, order.currency)}</div>
                                                {#if order.tax > 0}
                                                    <div class="text-[10px] text-slate-400">Tax: {formatCurrency(order.tax, order.currency)}</div>
                                                {/if}
                                            </td>
                                            <td class="px-3 py-2.5 text-center">
                                                <span class="px-2 py-0.5 rounded-full text-[10px] font-bold border {getStatusBadge(order.order_status)}">{order.order_status}</span>
                                            </td>
                                            <td class="px-3 py-2.5 text-center text-xs text-slate-400">{formatDate(order.created_at)}</td>
                                            <td class="px-3 py-2.5 text-center">
                                                <div class="flex gap-1.5 justify-center items-center">
                                                    <button on:click={() => viewOrder(order)} title="View Details" class="inline-flex items-center justify-center px-2.5 py-1 rounded-lg bg-emerald-600 text-white text-xs font-bold hover:bg-emerald-700 hover:shadow-lg transition-all duration-200 transform hover:scale-105 border-none cursor-pointer">👁️</button>
                                                    <select
                                                        value={order.order_status}
                                                        on:change={(e) => updateOrderStatus(order.id, getSelectValue(e))}
                                                        class="px-2 py-1 rounded-lg bg-white border border-slate-200 text-slate-700 text-[10px] cursor-pointer focus:ring-2 focus:ring-emerald-300 outline-none"
                                                    >
                                                        {#each orderStatuses as os}
                                                            <option value={os.value}>{os.label}</option>
                                                        {/each}
                                                    </select>
                                                </div>
                                            </td>
                                        </tr>
                                    {/each}
                                </tbody>
                            </table>
                        </div>
                        <div class="px-6 py-3 bg-slate-100/50 border-t border-slate-200 text-xs text-slate-600 font-semibold">
                            Showing {filteredOrders.length} order{filteredOrders.length !== 1 ? 's' : ''}
                        </div>
                    </div>
                {/if}
            {/if}
        </div>
    </div>
</div>

<!-- ═══════ CATALOG MODAL ═══════ -->
{#if showCatalogModal}
    <!-- svelte-ignore a11y-click-events-have-key-events a11y-no-static-element-interactions -->
    <div class="fixed inset-0 bg-black/40 backdrop-blur-sm z-[10000] flex items-center justify-center" on:click|self={() => showCatalogModal = false}>
        <div class="bg-white rounded-3xl w-[440px] max-w-[95vw] overflow-hidden shadow-2xl border border-slate-200">
            <div class="px-6 py-4 bg-gradient-to-r from-emerald-600 to-emerald-700 flex items-center justify-between">
                <span class="text-sm font-black text-white uppercase tracking-wider">📂 {editingCatalog ? 'Edit Catalog' : 'New Catalog'}</span>
                <button on:click={() => showCatalogModal = false} class="bg-white/20 hover:bg-white/30 text-white w-7 h-7 rounded-lg flex items-center justify-center border-none cursor-pointer text-lg transition-colors">✕</button>
            </div>
            <div class="p-6 space-y-4">
                <div>
                    <div class="text-[11px] text-slate-500 font-bold uppercase tracking-wider mb-1.5">Catalog Name *</div>
                    <input bind:value={catalogForm.name} placeholder="e.g. Main Product Catalog" class="w-full px-4 py-2.5 rounded-xl bg-slate-50 border border-slate-200 text-slate-700 text-sm focus:ring-2 focus:ring-emerald-300 focus:border-emerald-400 outline-none transition-all box-border" />
                </div>
                <div>
                    <div class="text-[11px] text-slate-500 font-bold uppercase tracking-wider mb-1.5">Description</div>
                    <textarea bind:value={catalogForm.description} rows="3" placeholder="Optional description..." class="w-full px-4 py-2.5 rounded-xl bg-slate-50 border border-slate-200 text-slate-700 text-sm resize-y focus:ring-2 focus:ring-emerald-300 focus:border-emerald-400 outline-none transition-all box-border"></textarea>
                </div>
                <div>
                    <div class="text-[11px] text-slate-500 font-bold uppercase tracking-wider mb-1.5">Meta Catalog ID</div>
                    <input bind:value={catalogForm.meta_catalog_id} placeholder="From Meta Business Manager" class="w-full px-4 py-2.5 rounded-xl bg-slate-50 border border-slate-200 text-slate-700 text-sm font-mono focus:ring-2 focus:ring-emerald-300 focus:border-emerald-400 outline-none transition-all box-border" />
                    <p class="text-[10px] text-slate-400 mt-1.5">Link to an existing Meta catalog for syncing.</p>
                </div>
            </div>
            <div class="px-6 py-4 border-t border-slate-200 bg-slate-50 flex justify-end gap-3">
                <button on:click={() => showCatalogModal = false} class="px-5 py-2.5 rounded-xl bg-white border border-slate-200 text-slate-600 text-xs font-bold hover:bg-slate-50 transition-all cursor-pointer">Cancel</button>
                <button on:click={saveCatalog} disabled={saving} class="px-5 py-2.5 rounded-xl bg-emerald-600 text-white text-xs font-black hover:bg-emerald-700 hover:shadow-lg shadow-md shadow-emerald-200 transition-all transform hover:scale-105 border-none cursor-pointer disabled:opacity-50">
                    {saving ? '⏳ Saving...' : (editingCatalog ? '💾 Update' : '✅ Create')}
                </button>
            </div>
        </div>
    </div>
{/if}

<!-- ═══════ PRODUCT MODAL ═══════ -->
{#if showProductModal}
    <!-- svelte-ignore a11y-click-events-have-key-events a11y-no-static-element-interactions -->
    <div class="fixed inset-0 bg-black/40 backdrop-blur-sm z-[10000] flex items-center justify-center" on:click|self={() => showProductModal = false}>
        <div class="bg-white rounded-3xl w-[600px] max-w-[95vw] max-h-[85vh] overflow-y-auto shadow-2xl border border-slate-200">
            <div class="px-6 py-4 bg-gradient-to-r from-blue-600 to-blue-700 flex items-center justify-between sticky top-0 z-10">
                <span class="text-sm font-black text-white uppercase tracking-wider">📦 {editingProduct ? 'Edit Product' : 'New Product'}</span>
                <button on:click={() => showProductModal = false} class="bg-white/20 hover:bg-white/30 text-white w-7 h-7 rounded-lg flex items-center justify-center border-none cursor-pointer text-lg transition-colors">✕</button>
            </div>
            <div class="p-6 space-y-4">
                <div class="grid grid-cols-2 gap-3">
                    <div>
                        <div class="text-[11px] text-slate-500 font-bold uppercase tracking-wider mb-1.5">Catalog *</div>
                        <select bind:value={productForm.catalog_id} class="w-full px-4 py-2.5 rounded-xl bg-slate-50 border border-slate-200 text-slate-700 text-sm focus:ring-2 focus:ring-blue-300 focus:border-blue-400 outline-none transition-all box-border">
                            <option value="">— Select —</option>
                            {#each catalogs as cat}
                                <option value={cat.id}>{cat.name}</option>
                            {/each}
                        </select>
                    </div>
                    <div>
                        <div class="text-[11px] text-slate-500 font-bold uppercase tracking-wider mb-1.5">Product Name *</div>
                        <input bind:value={productForm.name} placeholder="Product name" class="w-full px-4 py-2.5 rounded-xl bg-slate-50 border border-slate-200 text-slate-700 text-sm focus:ring-2 focus:ring-blue-300 focus:border-blue-400 outline-none transition-all box-border" />
                    </div>
                </div>
                <div>
                    <div class="text-[11px] text-slate-500 font-bold uppercase tracking-wider mb-1.5">Description</div>
                    <textarea bind:value={productForm.description} rows="2" placeholder="Product description..." class="w-full px-4 py-2.5 rounded-xl bg-slate-50 border border-slate-200 text-slate-700 text-sm resize-y focus:ring-2 focus:ring-blue-300 focus:border-blue-400 outline-none transition-all box-border"></textarea>
                </div>
                <div class="grid grid-cols-[1fr_1fr_auto] gap-3">
                    <div>
                        <div class="text-[11px] text-slate-500 font-bold uppercase tracking-wider mb-1.5">Price</div>
                        <input bind:value={productForm.price} type="number" step="0.01" min="0" class="w-full px-4 py-2.5 rounded-xl bg-slate-50 border border-slate-200 text-slate-700 text-sm focus:ring-2 focus:ring-blue-300 focus:border-blue-400 outline-none transition-all box-border" />
                    </div>
                    <div>
                        <div class="text-[11px] text-slate-500 font-bold uppercase tracking-wider mb-1.5">Sale Price</div>
                        <input bind:value={productForm.sale_price} type="number" step="0.01" min="0" placeholder="Optional" class="w-full px-4 py-2.5 rounded-xl bg-slate-50 border border-slate-200 text-slate-700 text-sm focus:ring-2 focus:ring-blue-300 focus:border-blue-400 outline-none transition-all box-border" />
                    </div>
                    <div>
                        <div class="text-[11px] text-slate-500 font-bold uppercase tracking-wider mb-1.5">Currency</div>
                        <select bind:value={productForm.currency} class="px-3 py-2.5 rounded-xl bg-slate-50 border border-slate-200 text-slate-700 text-sm focus:ring-2 focus:ring-blue-300 focus:border-blue-400 outline-none transition-all">
                            {#each currencyOptions as c}
                                <option value={c}>{c}</option>
                            {/each}
                        </select>
                    </div>
                </div>
                <div class="grid grid-cols-[1fr_1fr_100px] gap-3">
                    <div>
                        <div class="text-[11px] text-slate-500 font-bold uppercase tracking-wider mb-1.5">SKU</div>
                        <input bind:value={productForm.sku} placeholder="Stock code" class="w-full px-4 py-2.5 rounded-xl bg-slate-50 border border-slate-200 text-slate-700 text-sm font-mono focus:ring-2 focus:ring-blue-300 focus:border-blue-400 outline-none transition-all box-border" />
                    </div>
                    <div>
                        <div class="text-[11px] text-slate-500 font-bold uppercase tracking-wider mb-1.5">Retailer ID</div>
                        <input bind:value={productForm.retailer_id} placeholder="External ID" class="w-full px-4 py-2.5 rounded-xl bg-slate-50 border border-slate-200 text-slate-700 text-sm font-mono focus:ring-2 focus:ring-blue-300 focus:border-blue-400 outline-none transition-all box-border" />
                    </div>
                    <div>
                        <div class="text-[11px] text-slate-500 font-bold uppercase tracking-wider mb-1.5">Qty</div>
                        <input bind:value={productForm.quantity} type="number" min="0" class="w-full px-4 py-2.5 rounded-xl bg-slate-50 border border-slate-200 text-slate-700 text-sm focus:ring-2 focus:ring-blue-300 focus:border-blue-400 outline-none transition-all box-border" />
                    </div>
                </div>
                <div class="grid grid-cols-2 gap-3">
                    <div>
                        <div class="text-[11px] text-slate-500 font-bold uppercase tracking-wider mb-1.5">Brand</div>
                        <input bind:value={productForm.brand} placeholder="Brand name" class="w-full px-4 py-2.5 rounded-xl bg-slate-50 border border-slate-200 text-slate-700 text-sm focus:ring-2 focus:ring-blue-300 focus:border-blue-400 outline-none transition-all box-border" />
                    </div>
                    <div>
                        <div class="text-[11px] text-slate-500 font-bold uppercase tracking-wider mb-1.5">Category</div>
                        <input bind:value={productForm.category} placeholder="e.g. Electronics" class="w-full px-4 py-2.5 rounded-xl bg-slate-50 border border-slate-200 text-slate-700 text-sm focus:ring-2 focus:ring-blue-300 focus:border-blue-400 outline-none transition-all box-border" />
                    </div>
                </div>
                <div class="grid grid-cols-2 gap-3">
                    <div>
                        <div class="text-[11px] text-slate-500 font-bold uppercase tracking-wider mb-1.5">Availability</div>
                        <select bind:value={productForm.availability} class="w-full px-4 py-2.5 rounded-xl bg-slate-50 border border-slate-200 text-slate-700 text-sm focus:ring-2 focus:ring-blue-300 focus:border-blue-400 outline-none transition-all box-border">
                            {#each availabilityOptions as a}
                                <option value={a.value}>{a.icon} {a.label}</option>
                            {/each}
                        </select>
                    </div>
                    <div>
                        <div class="text-[11px] text-slate-500 font-bold uppercase tracking-wider mb-1.5">Condition</div>
                        <select bind:value={productForm.condition} class="w-full px-4 py-2.5 rounded-xl bg-slate-50 border border-slate-200 text-slate-700 text-sm focus:ring-2 focus:ring-blue-300 focus:border-blue-400 outline-none transition-all box-border">
                            {#each conditionOptions as c}
                                <option value={c.value}>{c.label}</option>
                            {/each}
                        </select>
                    </div>
                </div>
                <div>
                    <div class="text-[11px] text-slate-500 font-bold uppercase tracking-wider mb-1.5">Image URL</div>
                    <input bind:value={productForm.image_url} placeholder="https://..." class="w-full px-4 py-2.5 rounded-xl bg-slate-50 border border-slate-200 text-slate-700 text-sm focus:ring-2 focus:ring-blue-300 focus:border-blue-400 outline-none transition-all box-border" />
                    {#if productForm.image_url}
                        <img src={productForm.image_url} alt="Preview" class="mt-2 w-20 h-20 object-contain rounded-xl bg-white border border-slate-200 shadow-sm" />
                    {/if}
                </div>
                <div>
                    <div class="text-[11px] text-slate-500 font-bold uppercase tracking-wider mb-1.5">Product URL</div>
                    <input bind:value={productForm.url} placeholder="https://yoursite.com/product" class="w-full px-4 py-2.5 rounded-xl bg-slate-50 border border-slate-200 text-slate-700 text-sm focus:ring-2 focus:ring-blue-300 focus:border-blue-400 outline-none transition-all box-border" />
                </div>
            </div>
            <div class="px-6 py-4 border-t border-slate-200 bg-slate-50 flex justify-end gap-3 sticky bottom-0">
                <button on:click={() => showProductModal = false} class="px-5 py-2.5 rounded-xl bg-white border border-slate-200 text-slate-600 text-xs font-bold hover:bg-slate-50 transition-all cursor-pointer">Cancel</button>
                <button on:click={saveProduct} disabled={saving} class="px-5 py-2.5 rounded-xl bg-blue-600 text-white text-xs font-black hover:bg-blue-700 hover:shadow-lg shadow-md shadow-blue-200 transition-all transform hover:scale-105 border-none cursor-pointer disabled:opacity-50">
                    {saving ? '⏳ Saving...' : (editingProduct ? '💾 Update' : '✅ Create')}
                </button>
            </div>
        </div>
    </div>
{/if}

<!-- ═══════ ORDER DETAIL MODAL ═══════ -->
{#if showOrderModal && viewingOrder}
    <!-- svelte-ignore a11y-click-events-have-key-events a11y-no-static-element-interactions -->
    <div class="fixed inset-0 bg-black/40 backdrop-blur-sm z-[10000] flex items-center justify-center" on:click|self={() => showOrderModal = false}>
        <div class="bg-white rounded-3xl w-[520px] max-w-[95vw] max-h-[85vh] overflow-y-auto shadow-2xl border border-slate-200">
            <div class="px-6 py-4 bg-gradient-to-r from-amber-500 to-amber-600 flex items-center justify-between">
                <span class="text-sm font-black text-white uppercase tracking-wider">🛒 Order #{viewingOrder.id.substring(0, 8)}</span>
                <button on:click={() => showOrderModal = false} class="bg-white/20 hover:bg-white/30 text-white w-7 h-7 rounded-lg flex items-center justify-center border-none cursor-pointer text-lg transition-colors">✕</button>
            </div>
            <div class="p-6 space-y-4">
                <div class="bg-slate-50 border border-slate-200 rounded-2xl p-4">
                    <div class="text-[11px] text-slate-400 uppercase font-bold tracking-wider mb-2">Customer</div>
                    <div class="text-base font-bold text-slate-700">{viewingOrder.customer_name || 'Unknown'}</div>
                    <div class="text-sm text-slate-400">{viewingOrder.customer_phone}</div>
                </div>
                <div class="flex items-center gap-3">
                    <span class="text-[11px] text-slate-400 uppercase font-bold tracking-wider">Status:</span>
                    <span class="px-2 py-0.5 rounded-full text-[11px] font-bold border {getStatusBadge(viewingOrder.order_status)}">{viewingOrder.order_status}</span>
                    <select
                        value={viewingOrder.order_status}
                        on:change={(e) => { const v = getSelectValue(e); updateOrderStatus(viewingOrder.id, v); viewingOrder.order_status = v; }}
                        class="ml-auto px-3 py-1.5 rounded-xl bg-slate-50 border border-slate-200 text-slate-700 text-xs cursor-pointer focus:ring-2 focus:ring-emerald-300 outline-none"
                    >
                        {#each orderStatuses as os}
                            <option value={os.value}>{os.label}</option>
                        {/each}
                    </select>
                </div>
                <div>
                    <div class="text-[11px] text-slate-400 uppercase font-bold tracking-wider mb-2">Items ({Array.isArray(viewingOrder.items) ? viewingOrder.items.length : 0})</div>
                    {#if Array.isArray(viewingOrder.items) && viewingOrder.items.length > 0}
                        <div class="flex flex-col gap-2">
                            {#each viewingOrder.items as item}
                                <div class="bg-slate-50 border border-slate-200 rounded-xl px-4 py-3 flex justify-between items-center">
                                    <div>
                                        <div class="text-sm font-bold text-slate-700">{item.name || item.product_name || 'Product'}</div>
                                        <div class="text-[10px] text-slate-400">Qty: {item.quantity || 1}</div>
                                    </div>
                                    <div class="text-sm font-bold text-emerald-600">{formatCurrency(item.price || item.unit_price || 0, viewingOrder.currency)}</div>
                                </div>
                            {/each}
                        </div>
                    {:else}
                        <p class="text-sm text-slate-400">No items data available.</p>
                    {/if}
                </div>
                <div class="bg-slate-50 border border-slate-200 rounded-2xl p-4 space-y-1">
                    <div class="flex justify-between">
                        <span class="text-sm text-slate-400">Subtotal</span>
                        <span class="text-sm text-slate-700 font-semibold">{formatCurrency(viewingOrder.subtotal, viewingOrder.currency)}</span>
                    </div>
                    {#if viewingOrder.tax > 0}
                        <div class="flex justify-between">
                            <span class="text-sm text-slate-400">Tax</span>
                            <span class="text-sm text-slate-700 font-semibold">{formatCurrency(viewingOrder.tax, viewingOrder.currency)}</span>
                        </div>
                    {/if}
                    {#if viewingOrder.shipping > 0}
                        <div class="flex justify-between">
                            <span class="text-sm text-slate-400">Shipping</span>
                            <span class="text-sm text-slate-700 font-semibold">{formatCurrency(viewingOrder.shipping, viewingOrder.currency)}</span>
                        </div>
                    {/if}
                    <div class="border-t border-slate-200 pt-2 mt-2 flex justify-between">
                        <span class="text-base font-black text-slate-700">Total</span>
                        <span class="text-base font-black text-emerald-600">{formatCurrency(viewingOrder.total, viewingOrder.currency)}</span>
                    </div>
                </div>
                {#if viewingOrder.notes}
                    <div>
                        <div class="text-[11px] text-slate-400 uppercase font-bold tracking-wider mb-1.5">Notes</div>
                        <p class="text-sm text-slate-500 leading-relaxed">{viewingOrder.notes}</p>
                    </div>
                {/if}
                <div class="text-xs text-slate-400 pt-2">
                    Created: {formatDateTime(viewingOrder.created_at)} · Updated: {formatDateTime(viewingOrder.updated_at)}
                </div>
            </div>
        </div>
    </div>
{/if}

<style>
    /* Tailwind handles all styling */
</style>
