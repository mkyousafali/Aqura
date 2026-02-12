<script lang="ts">
    import { onMount, onDestroy } from 'svelte';
    import { _ as t, locale } from '$lib/i18n';
    import { currentUser } from '$lib/utils/persistentAuth';
    import { supabase } from '$lib/utils/supabase';
    import XLSX from 'xlsx-js-style';

    function formatDate(d: string | null): string {
        if (!d) return '-';
        const date = new Date(d);
        if (isNaN(date.getTime())) return d;
        const dd = String(date.getDate()).padStart(2, '0');
        const mm = String(date.getMonth() + 1).padStart(2, '0');
        const yyyy = date.getFullYear();
        return `${dd}-${mm}-${yyyy}`;
    }
    
    let activeTab = 'Add Asset';

    // Add Asset form fields
    let selectedSubCategoryId = '';
    let assetNameEn = '';
    let assetNameAr = '';
    let purchaseDate = '';
    let purchaseValue = '';
    let selectedBranch = '';
    let invoiceFile: File | null = null;
    let savingAsset = false;
    let previewAssetId = '';
    let loadingPreviewId = false;

    // Filtered sub categories for Add Asset dropdown (show all)
    $: filteredAddItems = dbItems;

    // Auto-generate asset ID preview when sub category changes
    $: if (selectedSubCategoryId) {
        generatePreviewAssetId(selectedSubCategoryId);
    } else {
        previewAssetId = '';
    }

    async function generatePreviewAssetId(subCatId: string) {
        loadingPreviewId = true;
        try {
            const subCat = dbItems.find(i => String(i.id) === String(subCatId));
            if (!subCat) { previewAssetId = ''; return; }
            const groupCode = subCat.group_code;
            const { data: existing } = await supabase
                .from('assets')
                .select('asset_id')
                .like('asset_id', `${groupCode}-%`)
                .order('asset_id', { ascending: false });
            let nextNum = 1;
            if (existing && existing.length > 0) {
                const nums = existing.map(a => {
                    const parts = a.asset_id.split('-');
                    return parseInt(parts[parts.length - 1]) || 0;
                });
                nextNum = Math.max(...nums) + 1;
            }
            previewAssetId = `${groupCode}-${nextNum}`;
        } finally {
            loadingPreviewId = false;
        }
    }

    let branches: any[] = [];

    onMount(async () => {
        const { data } = await supabase
            .from('branches')
            .select('*')
            .eq('is_active', true)
            .order('name_en');
        branches = data || [];
        await loadCategories();
        await loadItems();
        await loadAssets();
    });

    function handleFileSelect(e: Event) {
        const target = e.target as HTMLInputElement;
        invoiceFile = target.files?.[0] || null;
    }

    async function saveAsset() {
        if (!selectedSubCategoryId || !assetNameEn.trim()) return;
        savingAsset = true;
        try {
            // Use the preview asset ID (auto-generated or manually edited)
            const assetId = previewAssetId.trim() || '';
            if (!assetId) {
                // If somehow empty, generate it
                await generatePreviewAssetId(selectedSubCategoryId);
                if (!previewAssetId) return;
            }
            const finalAssetId = previewAssetId.trim();

            // Upload invoice if provided
            let invoiceUrl = null;
            if (invoiceFile) {
                const fileExt = invoiceFile.name.split('.').pop();
                const filePath = `${finalAssetId}.${fileExt}`;
                const { error: uploadErr } = await supabase.storage
                    .from('asset-invoices')
                    .upload(filePath, invoiceFile);
                if (!uploadErr) {
                    const { data: urlData } = supabase.storage.from('asset-invoices').getPublicUrl(filePath);
                    invoiceUrl = urlData?.publicUrl || null;
                }
            }

            await supabase.from('assets').insert({
                asset_id: finalAssetId,
                sub_category_id: parseInt(selectedSubCategoryId),
                asset_name_en: assetNameEn.trim(),
                asset_name_ar: assetNameAr.trim() || null,
                purchase_date: purchaseDate || null,
                purchase_value: parseFloat(purchaseValue) || 0,
                branch_id: selectedBranch ? parseInt(selectedBranch) : null,
                invoice_url: invoiceUrl
            });

            // Reset form
            selectedSubCategoryId = '';
            assetNameEn = '';
            assetNameAr = '';
            purchaseDate = '';
            purchaseValue = '';
            selectedBranch = '';
            invoiceFile = null;
            previewAssetId = '';
            await loadAssets();
        } finally {
            savingAsset = false;
        }
    }

    // Import state
    let importPreview: { name_en: string; name_ar: string; value: number }[] = [];
    let importFileName = '';
    let importingAssets = false;
    let importFileInput: HTMLInputElement;

    function handleImportFile(e: Event) {
        const target = e.target as HTMLInputElement;
        const file = target.files?.[0];
        if (!file) return;
        importFileName = file.name;

        const reader = new FileReader();
        reader.onload = (evt) => {
            const data = new Uint8Array(evt.target?.result as ArrayBuffer);
            const wb = XLSX.read(data, { type: 'array' });
            const ws = wb.Sheets[wb.SheetNames[0]];
            const rows: any[][] = XLSX.utils.sheet_to_json(ws, { header: 1 });

            // Skip header row, parse data
            importPreview = [];
            for (let i = 1; i < rows.length; i++) {
                const row = rows[i];
                if (!row || (!row[0] && !row[1])) continue;
                importPreview.push({
                    name_en: String(row[0] || '').trim(),
                    name_ar: String(row[1] || '').trim(),
                    value: parseFloat(row[2]) || 0
                });
            }
        };
        reader.readAsArrayBuffer(file);
    }

    async function saveImportedAssets() {
        if (importPreview.length === 0) return;
        importingAssets = true;
        try {
            // Find the "Temporary" sub category
            const tempSubCat = dbItems.find(i => i.group_code === 'TMP-000');
            if (!tempSubCat) {
                alert('Temporary sub category not found. Please add it first.');
                return;
            }
            const groupCode = tempSubCat.group_code;

            // Get max existing number for TMP-000
            const { data: existing } = await supabase
                .from('assets')
                .select('asset_id')
                .like('asset_id', `${groupCode}-%`)
                .order('asset_id', { ascending: false });

            let nextNum = 1;
            if (existing && existing.length > 0) {
                const nums = existing.map(a => {
                    const parts = a.asset_id.split('-');
                    return parseInt(parts[parts.length - 1]) || 0;
                });
                nextNum = Math.max(...nums) + 1;
            }

            // Insert all rows
            const inserts = importPreview.map((row, i) => ({
                asset_id: `${groupCode}-${nextNum + i}`,
                sub_category_id: tempSubCat.id,
                asset_name_en: row.name_en,
                asset_name_ar: row.name_ar,
                purchase_date: null,
                purchase_value: row.value,
                branch_id: null,
                invoice_url: null
            }));

            await supabase.from('assets').insert(inserts);

            // Reset
            importPreview = [];
            importFileName = '';
            await loadAssets();
        } finally {
            importingAssets = false;
        }
    }

    function downloadTemplate() {
        const headers = [
            [$locale === 'ar' ? 'اسم الأصل (إنجليزي)' : 'Asset Name (EN)', $locale === 'ar' ? 'اسم الأصل (عربي)' : 'Asset Name (AR)', $locale === 'ar' ? 'قيمة الشراء' : 'Purchase Value'],
            ['Dell Precision 3170', 'ديل بريسيجن 3170', 3500],
            ['HP LaserJet Pro M404', 'إتش بي ليزرجيت برو M404', 1800],
            ['Toyota Hiace 2025', 'تويوتا هايس 2025', 85000],
        ];

        const ws = XLSX.utils.aoa_to_sheet(headers);

        // Style header row
        const headerStyle = {
            font: { bold: true, color: { rgb: 'FFFFFF' }, sz: 12 },
            fill: { fgColor: { rgb: 'EA580C' } },
            alignment: { horizontal: 'center', vertical: 'center' },
            border: {
                top: { style: 'thin', color: { rgb: '000000' } },
                bottom: { style: 'thin', color: { rgb: '000000' } },
                left: { style: 'thin', color: { rgb: '000000' } },
                right: { style: 'thin', color: { rgb: '000000' } },
            }
        };

        for (let c = 0; c < 3; c++) {
            const ref = XLSX.utils.encode_cell({ r: 0, c });
            if (ws[ref]) ws[ref].s = headerStyle;
        }

        // Set column widths
        ws['!cols'] = [
            { wch: 30 },
            { wch: 30 },
            { wch: 20 },
        ];

        const wb = XLSX.utils.book_new();
        XLSX.utils.book_append_sheet(wb, ws, 'Asset Template');
        XLSX.writeFile(wb, 'Asset_Import_Template.xlsx');
    }

    // All Assets state
    let allAssets: any[] = [];
    let loadingAssets = false;
    let uploadingInvoiceForId: number | null = null;
    let assetsSearch = '';
    $: filteredAssets = allAssets.filter(a => {
        if (!assetsSearch.trim()) return true;
        const s = assetsSearch.toLowerCase();
        return (a.asset_id || '').toLowerCase().includes(s)
            || (a.asset_name_en || '').toLowerCase().includes(s)
            || (a.asset_name_ar || '').includes(assetsSearch)
            || (a.asset_sub_categories?.name_en || '').toLowerCase().includes(s)
            || (a.asset_sub_categories?.name_ar || '').includes(assetsSearch)
            || (a.asset_sub_categories?.asset_main_categories?.name_en || '').toLowerCase().includes(s)
            || (a.asset_sub_categories?.asset_main_categories?.name_ar || '').includes(assetsSearch)
            || (a.branches?.name_en || '').toLowerCase().includes(s)
            || (a.branches?.name_ar || '').includes(assetsSearch)
            || (a.branches?.location_en || '').toLowerCase().includes(s)
            || (a.branches?.location_ar || '').includes(assetsSearch);
    });

    async function uploadInvoiceInline(assetId: number, assetCode: string, file: File) {
        uploadingInvoiceForId = assetId;
        try {
            const fileExt = file.name.split('.').pop();
            const filePath = `${assetCode}.${fileExt}`;
            const { error: uploadErr } = await supabase.storage
                .from('asset-invoices')
                .upload(filePath, file, { upsert: true });
            if (!uploadErr) {
                const { data: urlData } = supabase.storage.from('asset-invoices').getPublicUrl(filePath);
                await supabase.from('assets').update({ invoice_url: urlData?.publicUrl || null, updated_at: new Date().toISOString() }).eq('id', assetId);
                await loadAssets();
            }
        } finally {
            uploadingInvoiceForId = null;
        }
    }

    function handleInlineInvoice(e: Event, asset: any) {
        const target = e.target as HTMLInputElement;
        const file = target.files?.[0];
        if (file) uploadInvoiceInline(asset.id, asset.asset_id, file);
        target.value = '';
    }

    // Edit Asset popup state
    let showEditAssetPopup = false;
    let editingAssetId: number | null = null;
    let editAssetSubCategoryId = '';
    let editAssetNameEn = '';
    let editAssetNameAr = '';
    let editAssetPurchaseDate = '';
    let editAssetPurchaseValue = '';
    let editAssetBranch = '';
    let editAssetInvoiceFile: File | null = null;
    let editAssetInvoiceUrl = '';
    let savingEditAsset = false;
    let editAssetIdValue = '';
    let editAssetOriginalSubCatId = '';

    function openEditAsset(asset: any) {
        editingAssetId = asset.id;
        editAssetIdValue = asset.asset_id || '';
        editAssetSubCategoryId = String(asset.sub_category_id || '');
        editAssetOriginalSubCatId = editAssetSubCategoryId;
        editAssetNameEn = asset.asset_name_en || '';
        editAssetNameAr = asset.asset_name_ar || '';
        editAssetPurchaseDate = asset.purchase_date || '';
        editAssetPurchaseValue = asset.purchase_value ? String(asset.purchase_value) : '';
        editAssetBranch = asset.branch_id ? String(asset.branch_id) : '';
        editAssetInvoiceFile = null;
        editAssetInvoiceUrl = asset.invoice_url || '';
        showEditAssetPopup = true;
    }

    // Auto-regenerate asset ID when sub category changes in edit popup
    $: if (showEditAssetPopup && editAssetSubCategoryId && editAssetSubCategoryId !== editAssetOriginalSubCatId) {
        regenerateEditAssetId(editAssetSubCategoryId);
    }

    async function regenerateEditAssetId(subCatId: string) {
        const subCat = dbItems.find(i => String(i.id) === String(subCatId));
        if (!subCat) return;
        const groupCode = subCat.group_code;
        const { data: existing } = await supabase
            .from('assets')
            .select('asset_id')
            .like('asset_id', `${groupCode}-%`)
            .order('asset_id', { ascending: false });
        let nextNum = 1;
        if (existing && existing.length > 0) {
            const nums = existing.map(a => {
                const parts = a.asset_id.split('-');
                return parseInt(parts[parts.length - 1]) || 0;
            });
            nextNum = Math.max(...nums) + 1;
        }
        editAssetIdValue = `${groupCode}-${nextNum}`;
        editAssetOriginalSubCatId = subCatId;
    }

    function cancelEditAsset() {
        showEditAssetPopup = false;
        editingAssetId = null;
    }

    function handleEditFileSelect(e: Event) {
        const target = e.target as HTMLInputElement;
        editAssetInvoiceFile = target.files?.[0] || null;
    }

    async function saveEditAsset() {
        if (!editingAssetId || !editAssetNameEn.trim()) return;
        savingEditAsset = true;
        try {
            const updates: any = {
                asset_id: editAssetIdValue.trim(),
                sub_category_id: editAssetSubCategoryId ? parseInt(editAssetSubCategoryId) : null,
                asset_name_en: editAssetNameEn.trim(),
                asset_name_ar: editAssetNameAr.trim() || null,
                purchase_date: editAssetPurchaseDate || null,
                purchase_value: parseFloat(editAssetPurchaseValue) || 0,
                branch_id: editAssetBranch ? parseInt(editAssetBranch) : null,
                updated_at: new Date().toISOString()
            };

            // Upload new invoice if provided
            if (editAssetInvoiceFile) {
                const asset = allAssets.find(a => a.id === editingAssetId);
                const fileExt = editAssetInvoiceFile.name.split('.').pop();
                const filePath = `${asset?.asset_id || editingAssetId}.${fileExt}`;
                const { error: uploadErr } = await supabase.storage
                    .from('asset-invoices')
                    .upload(filePath, editAssetInvoiceFile, { upsert: true });
                if (!uploadErr) {
                    const { data: urlData } = supabase.storage.from('asset-invoices').getPublicUrl(filePath);
                    updates.invoice_url = urlData?.publicUrl || null;
                }
            }

            await supabase.from('assets').update(updates).eq('id', editingAssetId);
            showEditAssetPopup = false;
            editingAssetId = null;
            await loadAssets();
        } finally {
            savingEditAsset = false;
        }
    }

    async function loadAssets() {
        loadingAssets = true;
        const { data } = await supabase
            .from('assets')
            .select('*, asset_sub_categories(name_en, name_ar, group_code, asset_main_categories(name_en, name_ar)), branches(name_en, name_ar, location_en, location_ar)')
            .order('created_at', { ascending: false });
        allAssets = data || [];
        loadingAssets = false;
    }

    async function deleteAsset(assetId: number) {
        if (!confirm($t('finance.assets.confirmDeleteAsset'))) return;
        const { error } = await supabase.from('assets').delete().eq('id', assetId);
        if (error) { alert(error.message); return; }
        await loadAssets();
    }

    // Manage Categories state
    let dbCategories: any[] = [];
    let loadingCategories = false;
    let categoriesSearch = '';
    $: filteredCategories = dbCategories.filter(c => {
        if (!categoriesSearch.trim()) return true;
        const s = categoriesSearch.toLowerCase();
        return (c.group_code || '').toLowerCase().includes(s)
            || (c.name_en || '').toLowerCase().includes(s)
            || (c.name_ar || '').includes(categoriesSearch);
    });
    let showAddCategoryPopup = false;
    let showEditCategoryPopup = false;
    let newCatGroupCode = '';
    let newCatNameEn = '';
    let newCatNameAr = '';
    let catDuplicateError = '';
    let editingCategoryId: number | null = null;
    let editCatGroupCode = '';
    let editCatNameEn = '';
    let editCatNameAr = '';

    async function loadCategories() {
        loadingCategories = true;
        const { data } = await supabase
            .from('asset_main_categories')
            .select('*')
            .order('group_code');
        dbCategories = data || [];
        loadingCategories = false;
    }

    async function addCategory() {
        if (!newCatGroupCode.trim() || !newCatNameEn.trim() || !newCatNameAr.trim()) return;
        const code = newCatGroupCode.trim().toUpperCase();
        // Check for duplicate group_code
        const duplicate = dbCategories.find(c => c.group_code === code);
        if (duplicate) {
            catDuplicateError = $locale === 'ar' 
                ? `رمز المجموعة "${code}" مستخدم بالفعل في "${duplicate.name_ar}"` 
                : `Group code "${code}" is already used by "${duplicate.name_en}"`;
            return;
        }
        catDuplicateError = '';
        await supabase.from('asset_main_categories').insert({
            group_code: code,
            name_en: newCatNameEn.trim(),
            name_ar: newCatNameAr.trim()
        });
        newCatGroupCode = '';
        newCatNameEn = '';
        newCatNameAr = '';
        showAddCategoryPopup = false;
        await loadCategories();
    }

    function openAddCategoryPopup() {
        newCatGroupCode = '';
        newCatNameEn = '';
        newCatNameAr = '';
        catDuplicateError = '';
        showAddCategoryPopup = true;
    }

    function closeAddCategoryPopup() {
        showAddCategoryPopup = false;
        catDuplicateError = '';
    }

    function startEditCategory(cat: any) {
        editingCategoryId = cat.id;
        editCatGroupCode = cat.group_code;
        editCatNameEn = cat.name_en;
        editCatNameAr = cat.name_ar;
        catDuplicateError = '';
        showEditCategoryPopup = true;
    }

    function cancelEditCategory() {
        editingCategoryId = null;
        editCatGroupCode = '';
        editCatNameEn = '';
        editCatNameAr = '';
        showEditCategoryPopup = false;
        catDuplicateError = '';
    }

    async function saveEditCategory() {
        if (!editingCategoryId || !editCatGroupCode.trim() || !editCatNameEn.trim() || !editCatNameAr.trim()) return;
        const newCode = editCatGroupCode.trim().toUpperCase();
        // Find old group_code before update
        const oldCat = dbCategories.find(c => c.id === editingCategoryId);
        const oldCode = oldCat?.group_code;
        // Update the category
        await supabase.from('asset_main_categories').update({
            group_code: newCode,
            name_en: editCatNameEn.trim(),
            name_ar: editCatNameAr.trim()
        }).eq('id', editingCategoryId);
        // If group_code changed, also update all matching sub categories in asset_sub_categories
        if (oldCode && oldCode !== newCode) {
            await supabase.from('asset_sub_categories')
                .update({ group_code: newCode })
                .eq('category_id', editingCategoryId)
                .eq('group_code', oldCode);
        }
        cancelEditCategory();
        await loadCategories();
    }
    async function deleteCategory(id: number) {
        await supabase.from('asset_main_categories').delete().eq('id', id);
        await loadCategories();
    }

    // Manage Items state
    let manageSubTab: 'categories' | 'items' = 'categories';
    let dbItems: any[] = [];
    let loadingItems = false;
    let itemsSearch = '';
    $: filteredItems = dbItems.filter(it => {
        if (!itemsSearch.trim()) return true;
        const s = itemsSearch.toLowerCase();
        return (it.group_code || '').toLowerCase().includes(s)
            || (it.name_en || '').toLowerCase().includes(s)
            || (it.name_ar || '').includes(itemsSearch)
            || (it.asset_main_categories?.name_en || '').toLowerCase().includes(s)
            || (it.asset_main_categories?.name_ar || '').includes(itemsSearch);
    });
    let showAddItemPopup = false;
    let itemDuplicateError = '';
    let newItemCategoryId = '';
    let newItemGroupCode = '';
    let newItemNameEn = '';
    let newItemNameAr = '';
    let newItemUsefulLife = '';
    let newItemAnnualDep = '';
    let newItemMonthlyDep = '';
    let newItemResidualPct = '';
    let editingItemId: number | null = null;
    let showEditItemPopup = false;
    let editItemCategoryId = '';
    let editItemGroupCode = '';
    let editItemNameEn = '';
    let editItemNameAr = '';
    let editItemUsefulLife = '';
    let editItemAnnualDep = '';
    let editItemMonthlyDep = '';
    let editItemResidualPct = '';

    async function loadItems() {
        loadingItems = true;
        const { data } = await supabase
            .from('asset_sub_categories')
            .select('*, asset_main_categories(name_en, name_ar, group_code)')
            .order('group_code');
        dbItems = data || [];
        loadingItems = false;
    }

    async function addItem() {
        if (!newItemCategoryId || !newItemGroupCode.trim() || !newItemNameEn.trim() || !newItemNameAr.trim()) return;
        const code = newItemGroupCode.trim().toUpperCase();
        const nameEn = newItemNameEn.trim();
        // Check for duplicate group_code + name_en
        const duplicate = dbItems.find(it => it.group_code === code && it.name_en === nameEn);
        if (duplicate) {
            itemDuplicateError = $locale === 'ar'
                ? `الصنف "${nameEn}" برمز "${code}" موجود بالفعل`
                : `Sub category "${nameEn}" with code "${code}" already exists`;
            return;
        }
        itemDuplicateError = '';
        await supabase.from('asset_sub_categories').insert({
            category_id: parseInt(newItemCategoryId),
            group_code: code,
            name_en: nameEn,
            name_ar: newItemNameAr.trim(),
            useful_life_years: newItemUsefulLife.trim() || null,
            annual_depreciation_pct: parseFloat(newItemAnnualDep) || 0,
            monthly_depreciation_pct: parseFloat(newItemMonthlyDep) || 0,
            residual_pct: newItemResidualPct.trim() || '0%'
        });
        newItemCategoryId = '';
        newItemGroupCode = '';
        newItemNameEn = '';
        newItemNameAr = '';
        newItemUsefulLife = '';
        newItemAnnualDep = '';
        newItemMonthlyDep = '';
        newItemResidualPct = '';
        showAddItemPopup = false;
        await loadItems();
    }

    function openAddItemPopup() {
        newItemCategoryId = '';
        newItemGroupCode = '';
        newItemNameEn = '';
        newItemNameAr = '';
        newItemUsefulLife = '';
        newItemAnnualDep = '';
        newItemMonthlyDep = '';
        newItemResidualPct = '';
        itemDuplicateError = '';
        showAddItemPopup = true;
    }

    function closeAddItemPopup() {
        showAddItemPopup = false;
        itemDuplicateError = '';
    }

    function startEditItem(item: any) {
        editingItemId = item.id;
        editItemCategoryId = String(item.category_id);
        editItemGroupCode = item.group_code;
        editItemNameEn = item.name_en;
        editItemNameAr = item.name_ar;
        editItemUsefulLife = item.useful_life_years || '';
        editItemAnnualDep = String(item.annual_depreciation_pct || 0);
        editItemMonthlyDep = String(item.monthly_depreciation_pct || 0);
        editItemResidualPct = item.residual_pct || '0%';
        itemDuplicateError = '';
        showEditItemPopup = true;
    }

    function cancelEditItem() {
        editingItemId = null;
        showEditItemPopup = false;
        itemDuplicateError = '';
    }

    async function saveEditItem() {
        if (!editingItemId || !editItemCategoryId || !editItemGroupCode.trim() || !editItemNameEn.trim() || !editItemNameAr.trim()) return;
        await supabase.from('asset_sub_categories').update({
            category_id: parseInt(editItemCategoryId),
            group_code: editItemGroupCode.trim().toUpperCase(),
            name_en: editItemNameEn.trim(),
            name_ar: editItemNameAr.trim(),
            useful_life_years: editItemUsefulLife.trim() || null,
            annual_depreciation_pct: parseFloat(editItemAnnualDep) || 0,
            monthly_depreciation_pct: parseFloat(editItemMonthlyDep) || 0,
            residual_pct: editItemResidualPct.trim() || '0%'
        }).eq('id', editingItemId);
        cancelEditItem();
        await loadItems();
    }

    async function deleteItem(id: number) {
        await supabase.from('asset_sub_categories').delete().eq('id', id);
        await loadItems();
    }

    async function switchManageSubTab(sub: 'categories' | 'items') {
        manageSubTab = sub;
        if (sub === 'categories') await loadCategories();
        else { await loadCategories(); await loadItems(); }
    }

    $: tabs = [
        { id: 'Add Asset', label: $t('finance.assets.addAsset'), icon: '➕', color: 'orange' },
        { id: 'Download Template', label: $t('finance.assets.downloadTemplate'), icon: '📥', color: 'green' },
        { id: 'Import Assets', label: $t('finance.assets.importAssets'), icon: '📤', color: 'orange' },
        { id: 'Manage Assets', label: $t('finance.assets.manageAssets'), icon: '⚙️', color: 'green' },
        { id: 'Manage Categories', label: $t('finance.assets.manageCategories'), icon: '🗂️', color: 'orange' },
    ];
</script>

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
    <!-- Header/Navigation -->
    <div class="bg-white border-b border-slate-200 px-6 py-4 flex items-center justify-between shadow-sm">
        <button
            class="flex items-center gap-2 px-4 py-2.5 bg-slate-100 text-slate-600 font-bold rounded-xl hover:bg-slate-200 transition-all text-xs"
            on:click={async () => { await loadCategories(); await loadItems(); await loadAssets(); }}
        >
            <span>🔄</span>
            {$t('finance.assets.refresh')}
        </button>
        <div class="flex gap-2 bg-slate-100 p-1.5 rounded-2xl border border-slate-200/50 shadow-inner">
            {#each tabs as tab}
                <button 
                    class="group relative flex items-center gap-2.5 px-6 py-2.5 text-xs font-black uppercase tracking-fast transition-all duration-500 rounded-xl overflow-hidden
                    {activeTab === tab.id 
                        ? (tab.color === 'green' ? 'bg-emerald-600 text-white shadow-lg shadow-emerald-200 scale-[1.02]' : 'bg-orange-600 text-white shadow-lg shadow-orange-200 scale-[1.02]')
                        : 'text-slate-500 hover:bg-white hover:text-slate-800 hover:shadow-md'}"
                    on:click={() => { activeTab = tab.id; if (tab.id === 'Manage Categories') switchManageSubTab('categories'); if (tab.id === 'Manage Assets') loadAssets(); if (tab.id === 'Import Assets') { importPreview = []; importFileName = ''; if (importFileInput) importFileInput.value = ''; setTimeout(() => importFileInput?.click(), 100); } }}
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
        <!-- Decorative background -->
        <div class="absolute top-0 right-0 w-[500px] h-[500px] bg-emerald-100/20 rounded-full blur-[120px] -mr-64 -mt-64 animate-pulse"></div>
        <div class="absolute bottom-0 left-0 w-[500px] h-[500px] bg-orange-100/20 rounded-full blur-[120px] -ml-64 -mb-64 animate-pulse" style="animation-delay: 2s;"></div>

        <div class="relative max-w-[99%] mx-auto h-full flex flex-col">
            {#if activeTab === 'Add Asset'}
                <!-- Add Asset Form -->
                <div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-8 overflow-y-auto">
                    <h3 class="text-lg font-bold text-slate-800 mb-6">{$t('finance.assets.addAsset')}</h3>

                    <div class="grid grid-cols-2 gap-6 max-w-4xl">
                        <!-- Asset Sub Category -->
                        <div class="form-group">
                            <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="asset-sub-category">{$t('finance.assets.selectAssetItem')}</label>
                            <select 
                                id="asset-sub-category"
                                bind:value={selectedSubCategoryId}
                                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent transition-all"
                            >
                                <option value="">{$t('finance.assets.selectAssetItem')}</option>
                                {#each filteredAddItems as item}
                                    <option value={item.id}>{$locale === 'ar' ? item.name_ar : item.name_en}</option>
                                {/each}
                            </select>
                        </div>

                        <!-- Asset ID (Auto-generated, editable) -->
                        <div class="form-group">
                            <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('finance.assets.assetId')}</label>
                            <input 
                                type="text"
                                bind:value={previewAssetId}
                                placeholder={$t('finance.assets.autoGenerated')}
                                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm font-mono font-bold focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent transition-all {previewAssetId ? 'text-emerald-700' : 'text-slate-400'}"
                            />
                        </div>

                        <!-- Asset Name (English) -->
                        <div class="form-group">
                            <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="asset-name-en">{$t('finance.assets.assetNameEn')}</label>
                            <input 
                                id="asset-name-en"
                                type="text"
                                bind:value={assetNameEn}
                                placeholder="Asset name"
                                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent transition-all"
                            />
                        </div>

                        <!-- Asset Name (Arabic) -->
                        <div class="form-group">
                            <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="asset-name-ar">{$t('finance.assets.assetNameAr')}</label>
                            <input 
                                id="asset-name-ar"
                                type="text"
                                bind:value={assetNameAr}
                                placeholder="اسم الأصل"
                                dir="rtl"
                                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent transition-all"
                            />
                        </div>

                        <!-- Purchase Date -->
                        <div class="form-group">
                            <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="purchase-date">{$t('finance.assets.purchaseDate')}</label>
                            <input 
                                id="purchase-date"
                                type="date"
                                bind:value={purchaseDate}
                                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent transition-all"
                            />
                        </div>

                        <!-- Purchase Value -->
                        <div class="form-group">
                            <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="purchase-value">{$t('finance.assets.purchaseValue')}</label>
                            <input 
                                id="purchase-value"
                                type="number"
                                bind:value={purchaseValue}
                                placeholder="0.00"
                                step="0.01"
                                min="0"
                                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent transition-all"
                            />
                        </div>

                        <!-- Select Branch -->
                        <div class="form-group">
                            <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="select-branch">{$t('finance.assets.selectBranch')}</label>
                            <select 
                                id="select-branch"
                                bind:value={selectedBranch}
                                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent transition-all"
                            >
                                <option value="">{$t('finance.assets.selectBranchPlaceholder')}</option>
                                {#each branches as branch}
                                    <option value={branch.id}>{$locale === 'ar' ? (branch.name_ar || branch.name_en) : branch.name_en}{$locale === 'ar' ? (branch.location_ar ? ` - ${branch.location_ar}` : '') : (branch.location_en ? ` - ${branch.location_en}` : '')}</option>
                                {/each}
                            </select>
                        </div>

                        <!-- Upload Invoice -->
                        <div class="form-group">
                            <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="upload-invoice">{$t('finance.assets.uploadInvoice')}</label>
                            <div class="flex items-center gap-3">
                                <label 
                                    for="upload-invoice"
                                    class="flex items-center gap-2 px-4 py-2.5 bg-orange-50 border border-orange-200 rounded-xl text-sm text-orange-700 font-semibold cursor-pointer hover:bg-orange-100 transition-all"
                                >
                                    <span>📤</span>
                                    <span>{$t('finance.assets.chooseFile')}</span>
                                </label>
                                <input 
                                    id="upload-invoice"
                                    type="file"
                                    on:change={handleFileSelect}
                                    class="hidden"
                                />
                                {#if invoiceFile}
                                    <span class="text-xs text-slate-500 truncate max-w-[200px]">{invoiceFile.name}</span>
                                {:else}
                                    <span class="text-xs text-slate-400">{$t('finance.assets.noFileSelected')}</span>
                                {/if}
                            </div>
                        </div>
                    </div>

                    <!-- Save Button -->
                    <div class="mt-8 flex justify-end max-w-4xl">
                        <button 
                            class="px-8 py-3 bg-orange-600 text-white font-bold rounded-xl hover:bg-orange-700 transition-all shadow-lg shadow-orange-200 text-sm flex items-center gap-2 disabled:opacity-50 disabled:cursor-not-allowed"
                            on:click={saveAsset}
                            disabled={savingAsset || !selectedSubCategoryId || !assetNameEn.trim()}
                        >
                            {#if savingAsset}
                                <span class="animate-spin">⏳</span>
                            {:else}
                                <span>💾</span>
                            {/if}
                            {$t('finance.assets.save')}
                        </button>
                    </div>
                </div>
            {:else if activeTab === 'Download Template'}
                <!-- Download Template tab content -->
                <div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-12 h-full flex flex-col items-center justify-center">
                    <div class="text-5xl mb-4">📥</div>
                    <p class="text-slate-600 font-semibold mb-6">{$t('finance.assets.downloadTemplate')}</p>
                    <button
                        class="px-6 py-3 bg-orange-600 text-white font-bold rounded-xl hover:bg-orange-700 transition-all shadow-lg shadow-orange-200 flex items-center gap-2"
                        on:click={downloadTemplate}
                    >
                        <span>📥</span>
                        <span>{$t('finance.assets.downloadTemplate')}</span>
                    </button>
                </div>
            {:else if activeTab === 'Import Assets'}
                <!-- Import Assets tab content -->
                <input type="file" accept=".xlsx,.xls" on:change={handleImportFile} class="hidden" bind:this={importFileInput} />
                <div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-8 h-full flex flex-col overflow-hidden">
                    {#if importPreview.length > 0}
                        <div class="flex items-center justify-between mb-4">
                            <h3 class="text-lg font-bold text-slate-800 flex items-center gap-2">
                                <span>📤</span>
                                {importFileName}
                            </h3>
                            <button class="px-4 py-2 bg-slate-100 text-slate-600 font-semibold rounded-xl hover:bg-slate-200 transition-all text-xs flex items-center gap-2" on:click={() => { if (importFileInput) importFileInput.value = ''; importFileInput?.click(); }}>
                                <span>📂</span>
                                {$t('finance.assets.chooseFile')}
                            </button>
                        </div>
                        <div class="flex-1 overflow-auto">
                            <table class="w-full text-xs border-collapse border border-slate-300">
                                <thead class="sticky top-0 z-10">
                                    <tr class="bg-orange-600 text-white">
                                        <th class="border-r border-slate-300 py-2 px-3 text-left font-bold">#</th>
                                        <th class="border-r border-slate-300 py-2 px-3 text-left font-bold">{$t('finance.assets.assetNameEn')}</th>
                                        <th class="border-r border-slate-300 py-2 px-3 text-left font-bold">{$t('finance.assets.assetNameAr')}</th>
                                        <th class="border-r border-slate-300 py-2 px-3 text-left font-bold">{$t('finance.assets.purchaseValue')}</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    {#each importPreview as row, i}
                                        <tr class="border-b border-slate-300 hover:bg-slate-50/50">
                                            <td class="border-r border-slate-300 py-2 px-3 text-slate-400 font-mono">{i + 1}</td>
                                            <td class="border-r border-slate-300 py-2 px-3 font-semibold text-slate-800">{row.name_en}</td>
                                            <td class="border-r border-slate-300 py-2 px-3 font-semibold text-slate-800" dir="rtl">{row.name_ar}</td>
                                            <td class="border-r border-slate-300 py-2 px-3 text-slate-600">{row.value}</td>
                                        </tr>
                                    {/each}
                                </tbody>
                            </table>
                        </div>

                        <div class="mt-4 flex items-center justify-between">
                            <span class="text-sm text-slate-500">{importPreview.length} {$t('finance.assets.rowsFound')}</span>
                            <button
                                class="px-8 py-3 bg-orange-600 text-white font-bold rounded-xl hover:bg-orange-700 transition-all shadow-lg shadow-orange-200 text-sm flex items-center gap-2 disabled:opacity-50 disabled:cursor-not-allowed"
                                on:click={saveImportedAssets}
                                disabled={importingAssets}
                            >
                                {#if importingAssets}
                                    <span class="animate-spin">⏳</span>
                                {:else}
                                    <span>💾</span>
                                {/if}
                                {$t('finance.assets.importAndSave')}
                            </button>
                        </div>
                    {:else}
                        <div class="flex-1 flex flex-col items-center justify-center">
                            <div class="text-5xl mb-4">📂</div>
                            <p class="text-slate-500 font-semibold mb-2">{$t('finance.assets.importNote')}</p>
                            <button class="mt-4 px-6 py-3 bg-orange-600 text-white font-bold rounded-xl hover:bg-orange-700 transition-all shadow-lg shadow-orange-200 text-sm flex items-center gap-2" on:click={() => { if (importFileInput) importFileInput.value = ''; importFileInput?.click(); }}>
                                <span>📂</span>
                                {$t('finance.assets.chooseFile')}
                            </button>
                        </div>
                    {/if}
                </div>
            {:else if activeTab === 'Manage Assets'}
                <!-- Manage Assets tab content -->
                <div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-8 h-full flex flex-col overflow-hidden">
                    <div class="flex items-center justify-between mb-4">
                        <h3 class="text-lg font-bold text-slate-800 flex items-center gap-2">
                            <span>⚙️</span>
                            {$t('finance.assets.manageAssets')}
                            <span class="text-xs font-normal bg-slate-100 px-3 py-1 rounded-full text-slate-500">{filteredAssets.length}/{allAssets.length}</span>
                        </h3>
                        <div class="flex items-center gap-2">
                            <div class="relative">
                                <span class="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 text-xs">🔍</span>
                                <input type="text" bind:value={assetsSearch} placeholder={$t('finance.assets.search')} class="pl-8 pr-4 py-2 bg-white border border-slate-200 rounded-xl text-xs focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent w-[32rem]" />
                            </div>
                            <div class="px-4 py-2 bg-emerald-50 border border-emerald-200 rounded-xl text-xs font-bold text-emerald-700 flex items-center gap-1">
                                {$t('finance.assets.totalAssetValue')}: <img src="/icons/saudi-currency.png" alt="SAR" class="inline h-2 w-2" /> {filteredAssets.reduce((sum, a) => sum + (Number(a.purchase_value) || 0), 0).toLocaleString()}
                            </div>
                            <button class="px-4 py-2 bg-slate-100 text-slate-600 font-semibold rounded-xl hover:bg-slate-200 transition-all text-xs flex items-center gap-2" on:click={loadAssets}>
                                <span>🔄</span>
                                {$t('finance.assets.refresh')}
                            </button>
                        </div>
                    </div>
                    {#if loadingAssets}
                        <div class="flex-1 flex items-center justify-center">
                            <span class="animate-spin text-3xl">⏳</span>
                        </div>
                    {:else if allAssets.length === 0}
                        <div class="flex-1 flex flex-col items-center justify-center">
                            <div class="text-5xl mb-4">📦</div>
                            <p class="text-slate-500 font-semibold">{$t('finance.assets.noAssets')}</p>
                        </div>
                    {:else}
                        <div class="flex-1 overflow-auto">
                            <table class="w-full text-xs border-collapse border border-slate-300">
                                <thead class="sticky top-0 z-10">
                                    <tr class="bg-emerald-600 text-white">
                                        <th class="border-r border-slate-300 py-2 px-3 text-left font-bold">#</th>
                                        <th class="border-r border-slate-300 py-2 px-3 text-left font-bold">{$t('finance.assets.assetId')}</th>
                                        <th class="border-r border-slate-300 py-2 px-3 text-left font-bold">{$t('finance.assets.assetName')}</th>
                                        <th class="border-r border-slate-300 py-2 px-3 text-left font-bold">{$t('finance.assets.assetCategory')}</th>
                                        <th class="border-r border-slate-300 py-2 px-3 text-left font-bold">{$t('finance.assets.selectAssetItem')}</th>
                                        <th class="border-r border-slate-300 py-2 px-3 text-left font-bold">{$t('finance.assets.purchaseDate')}</th>
                                        <th class="border-r border-slate-300 py-2 px-3 text-left font-bold">{$t('finance.assets.assetValue')}</th>
                                        <th class="border-r border-slate-300 py-2 px-3 text-left font-bold">{$t('finance.assets.selectBranch')}</th>
                                        <th class="border-r border-slate-300 py-2 px-3 text-left font-bold">{$t('finance.assets.invoice')}</th>
                                        <th class="border-r border-slate-300 py-2 px-3 text-center font-bold">{$t('finance.assets.actions')}</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    {#each filteredAssets as asset, i}
                                        <tr class="border-b border-slate-300 hover:bg-slate-50/50 {i % 2 === 0 ? 'bg-white/30' : 'bg-slate-50/30'}">
                                            <td class="border-r border-slate-300 py-2 px-3 text-slate-400 font-mono">{i + 1}</td>
                                            <td class="border-r border-slate-300 py-2 px-3 font-bold text-emerald-700 font-mono">{asset.asset_id}</td>
                                            <td class="border-r border-slate-300 py-2 px-3 font-semibold text-slate-800" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
                                                {$locale === 'ar' ? (asset.asset_name_ar || asset.asset_name_en || '-') : (asset.asset_name_en || asset.asset_name_ar || '-')}
                                            </td>
                                            <td class="border-r border-slate-300 py-2 px-3 font-semibold text-slate-800" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
                                                {$locale === 'ar' ? (asset.asset_sub_categories?.asset_main_categories?.name_ar || '-') : (asset.asset_sub_categories?.asset_main_categories?.name_en || '-')}
                                            </td>
                                            <td class="border-r border-slate-300 py-2 px-3 font-semibold text-slate-800" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
                                                {$locale === 'ar' ? (asset.asset_sub_categories?.name_ar || '-') : (asset.asset_sub_categories?.name_en || '-')}
                                            </td>
                                            <td class="border-r border-slate-300 py-2 px-3 text-slate-500">{formatDate(asset.purchase_date)}</td>
                                            <td class="border-r border-slate-300 py-2 px-3 text-slate-600 font-mono">{#if asset.purchase_value}<img src="/icons/saudi-currency.png" alt="SAR" class="inline h-2 w-2" /> {Number(asset.purchase_value).toLocaleString()}{:else}-{/if}</td>
                                            <td class="border-r border-slate-300 py-2 px-3">
                                                {#if asset.branches}
                                                    <span class="font-semibold text-slate-800" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>{$locale === 'ar' ? asset.branches.name_ar : asset.branches.name_en}{$locale === 'ar' ? (asset.branches.location_ar ? ` - ${asset.branches.location_ar}` : '') : (asset.branches.location_en ? ` - ${asset.branches.location_en}` : '')}</span>
                                                {:else}
                                                    <span class="text-slate-400">-</span>
                                                {/if}
                                            </td>
                                            <td class="border-r border-slate-300 py-2 px-3">
                                                {#if uploadingInvoiceForId === asset.id}
                                                    <span class="animate-spin text-sm">⏳</span>
                                                {:else if asset.invoice_url}
                                                    <div class="flex items-center gap-1.5">
                                                        <a href={asset.invoice_url} target="_blank" class="px-2 py-1 bg-blue-50 text-blue-600 hover:bg-blue-100 rounded-lg text-[10px] font-bold transition-all flex items-center gap-1">
                                                            <span>👁️</span>
                                                            {$t('finance.assets.viewInvoice')}
                                                        </a>
                                                        <label class="px-2 py-1 bg-orange-50 text-orange-600 hover:bg-orange-100 rounded-lg text-[10px] font-bold transition-all flex items-center gap-1 cursor-pointer">
                                                            <span>🔄</span>
                                                            {$t('finance.assets.updateInvoice')}
                                                            <input type="file" class="hidden" on:change={(e) => handleInlineInvoice(e, asset)} />
                                                        </label>
                                                    </div>
                                                {:else}
                                                    <label class="px-2 py-1 bg-emerald-50 text-emerald-600 hover:bg-emerald-100 rounded-lg text-[10px] font-bold transition-all flex items-center gap-1 cursor-pointer">
                                                        <span>📤</span>
                                                        {$t('finance.assets.uploadInvoice')}
                                                        <input type="file" class="hidden" on:change={(e) => handleInlineInvoice(e, asset)} />
                                                    </label>
                                                {/if}
                                            </td>
                                            <td class="border-r border-slate-300 py-2 px-3 text-center">
                                                <div class="flex items-center justify-center gap-1.5">
                                                    <button class="p-1.5 bg-emerald-50 hover:bg-emerald-100 rounded-lg transition-all text-emerald-600 hover:text-emerald-800" on:click={() => openEditAsset(asset)} title="{$t('finance.assets.editAsset')}">
                                                        ✏️
                                                    </button>
                                                    {#if $currentUser?.isMasterAdmin}
                                                        <button class="p-1.5 bg-red-50 hover:bg-red-100 rounded-lg transition-all text-red-600 hover:text-red-800" on:click={() => deleteAsset(asset.id)} title="{$t('finance.assets.deleteAsset')}">
                                                            🗑️
                                                        </button>
                                                    {/if}
                                                </div>
                                            </td>
                                        </tr>
                                    {/each}
                                </tbody>
                            </table>
                        </div>
                    {/if}
                </div>
            {:else if activeTab === 'Manage Categories'}
                <!-- Manage Categories tab content -->
                <div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-8 h-full flex flex-col overflow-hidden">
                    
                    <!-- Sub-tab toggle buttons -->
                    <div class="flex gap-3 mb-6">
                        <button
                            class="flex items-center gap-2 px-6 py-3 rounded-2xl font-bold text-sm transition-all duration-300 {manageSubTab === 'categories' ? 'bg-emerald-600 text-white shadow-lg shadow-emerald-200 scale-[1.02]' : 'bg-slate-100 text-slate-600 hover:bg-slate-200'}"
                            on:click={() => switchManageSubTab('categories')}
                        >
                            <span class="text-base">🗂️</span>
                            {$t('finance.assets.manageCategories')}
                        </button>
                        <button
                            class="flex items-center gap-2 px-6 py-3 rounded-2xl font-bold text-sm transition-all duration-300 {manageSubTab === 'items' ? 'bg-orange-600 text-white shadow-lg shadow-orange-200 scale-[1.02]' : 'bg-slate-100 text-slate-600 hover:bg-slate-200'}"
                            on:click={() => switchManageSubTab('items')}
                        >
                            <span class="text-base">📦</span>
                            {$t('finance.assets.manageItems')}
                        </button>
                    </div>

                    {#if manageSubTab === 'categories'}
                        <!-- ==================== CATEGORIES TABLE ==================== -->
                        <!-- Add Category Button -->
                        <div class="flex items-center justify-between mb-4">
                            <div class="relative">
                                <span class="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 text-xs">🔍</span>
                                <input type="text" bind:value={categoriesSearch} placeholder={$t('finance.assets.search')} class="pl-8 pr-4 py-2 bg-white border border-slate-200 rounded-xl text-xs focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent w-[32rem]" />
                            </div>
                            <button
                                class="px-5 py-2.5 bg-emerald-600 text-white font-bold rounded-xl hover:bg-emerald-700 transition-all shadow-lg shadow-emerald-200 flex items-center gap-2 text-sm"
                                on:click={openAddCategoryPopup}
                            >
                                <span>➕</span>
                                {$t('finance.assets.addCategory')}
                            </button>
                        </div>

                        <!-- Categories Table -->
                        <div class="flex-1 overflow-y-auto">
                            {#if loadingCategories}
                                <div class="flex items-center justify-center h-32">
                                    <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-emerald-600"></div>
                                </div>
                            {:else if dbCategories.length === 0}
                                <div class="flex flex-col items-center justify-center h-32 text-slate-400">
                                    <span class="text-3xl mb-2">📭</span>
                                    <p class="text-sm">{$t('finance.assets.noCategories')}</p>
                                </div>
                            {:else}
                                <table class="w-full border-collapse border border-slate-300">
                                    <thead class="sticky top-0 z-10 bg-white">
                                        <tr class="border-b-2 border-slate-200">
                                            <th class="border-r border-slate-300 text-start text-xs font-black text-slate-500 uppercase tracking-wide py-3 px-4">#</th>
                                            <th class="border-r border-slate-300 text-start text-xs font-black text-slate-500 uppercase tracking-wide py-3 px-4">{$t('finance.assets.groupCode')}</th>
                                            <th class="border-r border-slate-300 text-start text-xs font-black text-slate-500 uppercase tracking-wide py-3 px-4">{$t('finance.assets.assetName')}</th>
                                            <th class="border-r border-slate-300 text-center text-xs font-black text-slate-500 uppercase tracking-wide py-3 px-4">{$t('finance.assets.actions')}</th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        {#each filteredCategories as cat, i}
                                            <tr class="border-b border-slate-300 hover:bg-slate-50/50 transition-colors">
                                                <td class="border-r border-slate-300 py-3 px-4 text-sm text-slate-400 font-mono">{i + 1}</td>
                                                <td class="border-r border-slate-300 py-3 px-4 text-sm font-mono font-bold text-emerald-700">{cat.group_code}</td>
                                                <td class="border-r border-slate-300 py-3 px-4 text-sm font-semibold text-slate-800" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
                                                    {$locale === 'ar' ? cat.name_ar : cat.name_en}
                                                </td>
                                                <td class="border-r border-slate-300 py-3 px-4 text-center">
                                                    <div class="flex items-center justify-center gap-1.5">
                                                        <button class="p-1.5 bg-blue-100 text-blue-700 rounded-lg hover:bg-blue-200 transition-all text-xs" on:click={() => startEditCategory(cat)} title="Edit">✏️</button>
                                                        <button class="p-1.5 bg-red-100 text-red-700 rounded-lg hover:bg-red-200 transition-all text-xs" on:click={() => deleteCategory(cat.id)} title="Delete">🗑️</button>
                                                    </div>
                                                </td>
                                            </tr>
                                        {/each}
                                    </tbody>
                                </table>
                            {/if}
                        </div>
                    {:else}
                        <!-- ==================== ITEMS TABLE ==================== -->
                        <!-- Add Item Button -->
                        <div class="flex items-center justify-between mb-4">
                            <div class="relative">
                                <span class="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 text-xs">🔍</span>
                                <input type="text" bind:value={itemsSearch} placeholder={$t('finance.assets.search')} class="pl-8 pr-4 py-2 bg-white border border-slate-200 rounded-xl text-xs focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent w-[32rem]" />
                            </div>
                            <button
                                class="px-5 py-2.5 bg-orange-600 text-white font-bold rounded-xl hover:bg-orange-700 transition-all shadow-lg shadow-orange-200 flex items-center gap-2 text-sm"
                                on:click={openAddItemPopup}
                            >
                                <span>➕</span>
                                {$t('finance.assets.addItem')}
                            </button>
                        </div>

                        <!-- Items Table -->
                        <div class="flex-1 overflow-y-auto">
                            {#if loadingItems}
                                <div class="flex items-center justify-center h-32">
                                    <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-orange-600"></div>
                                </div>
                            {:else if dbItems.length === 0}
                                <div class="flex flex-col items-center justify-center h-32 text-slate-400">
                                    <span class="text-3xl mb-2">📭</span>
                                    <p class="text-sm">{$t('finance.assets.noItems')}</p>
                                </div>
                            {:else}
                                <table class="w-full text-xs border-collapse border border-slate-300">
                                    <thead class="sticky top-0 z-10 bg-white">
                                        <tr class="border-b-2 border-slate-200">
                                            <th class="border-r border-slate-300 text-start font-black text-slate-500 uppercase tracking-wide py-2 px-2">#</th>
                                            <th class="border-r border-slate-300 text-start font-black text-slate-500 uppercase tracking-wide py-2 px-2">{$t('finance.assets.assetCategory')}</th>
                                            <th class="border-r border-slate-300 text-start font-black text-slate-500 uppercase tracking-wide py-2 px-2">{$t('finance.assets.groupCode')}</th>
                                            <th class="border-r border-slate-300 text-start font-black text-slate-500 uppercase tracking-wide py-2 px-2">{$t('finance.assets.assetName')}</th>
                                            <th class="border-r border-slate-300 text-start font-black text-slate-500 uppercase tracking-wide py-2 px-2">{$t('finance.assets.usefulLife')}</th>
                                            <th class="border-r border-slate-300 text-start font-black text-slate-500 uppercase tracking-wide py-2 px-2">{$t('finance.assets.annualDep')}</th>
                                            <th class="border-r border-slate-300 text-start font-black text-slate-500 uppercase tracking-wide py-2 px-2">{$t('finance.assets.monthlyDep')}</th>
                                            <th class="border-r border-slate-300 text-start font-black text-slate-500 uppercase tracking-wide py-2 px-2">{$t('finance.assets.residual')}</th>
                                            <th class="border-r border-slate-300 text-center font-black text-slate-500 uppercase tracking-wide py-2 px-2">{$t('finance.assets.actions')}</th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        {#each filteredItems as item, i}
                                            <tr class="border-b border-slate-300 hover:bg-slate-50/50 transition-colors">
                                                <td class="border-r border-slate-300 py-2 px-2 text-slate-400 font-mono">{i + 1}</td>
                                                <td class="border-r border-slate-300 py-2 px-2 font-semibold text-slate-800" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
                                                    {$locale === 'ar' ? item.asset_main_categories?.name_ar : item.asset_main_categories?.name_en}
                                                </td>
                                                <td class="border-r border-slate-300 py-2 px-2 font-mono font-bold text-orange-700">{item.group_code}</td>
                                                <td class="border-r border-slate-300 py-2 px-2 font-semibold text-slate-800" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
                                                    {$locale === 'ar' ? item.name_ar : item.name_en}
                                                </td>
                                                <td class="border-r border-slate-300 py-2 px-2 text-slate-600">{item.useful_life_years || '—'}</td>
                                                <td class="border-r border-slate-300 py-2 px-2 text-slate-600">{item.annual_depreciation_pct}%</td>
                                                <td class="border-r border-slate-300 py-2 px-2 text-slate-600">{item.monthly_depreciation_pct}%</td>
                                                <td class="border-r border-slate-300 py-2 px-2 text-slate-600">{item.residual_pct}</td>
                                                <td class="border-r border-slate-300 py-2 px-2 text-center">
                                                    <div class="flex items-center justify-center gap-1">
                                                        <button class="p-1 bg-blue-100 text-blue-700 rounded hover:bg-blue-200 transition-all" on:click={() => startEditItem(item)}>✏️</button>
                                                        <button class="p-1 bg-red-100 text-red-700 rounded hover:bg-red-200 transition-all" on:click={() => deleteItem(item.id)}>🗑️</button>
                                                    </div>
                                                </td>
                                            </tr>
                                        {/each}
                                    </tbody>
                                </table>
                            {/if}
                        </div>
                    {/if}
                </div>
            {/if}
        </div>
    </div>
</div>

<!-- ==================== ADD CATEGORY POPUP ==================== -->
{#if showAddCategoryPopup}
    <div class="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-[9999]" on:click|self={closeAddCategoryPopup}>
        <div class="bg-white rounded-3xl shadow-2xl p-8 w-full max-w-lg mx-4 transform transition-all" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
            <div class="flex items-center justify-between mb-6">
                <h3 class="text-lg font-bold text-slate-800 flex items-center gap-2">
                    <span>🗂️</span>
                    {$t('finance.assets.addCategory')}
                </h3>
                <button class="p-2 hover:bg-slate-100 rounded-xl transition-all text-slate-400 hover:text-slate-600" on:click={closeAddCategoryPopup}>❌</button>
            </div>

            {#if catDuplicateError}
                <div class="mb-4 p-3 bg-red-50 border border-red-200 rounded-xl text-red-700 text-sm font-semibold flex items-center gap-2">
                    <span>⚠️</span>
                    {catDuplicateError}
                </div>
            {/if}

            <div class="space-y-4">
                <div>
                    <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('finance.assets.groupCode')}</label>
                    <input type="text" bind:value={newCatGroupCode} placeholder="PPE-XXX" class="w-full px-4 py-3 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent uppercase font-mono" />
                </div>
                <div>
                    <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('finance.assets.categoryNameEn')}</label>
                    <input type="text" bind:value={newCatNameEn} placeholder="Category name" class="w-full px-4 py-3 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent" />
                </div>
                <div>
                    <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('finance.assets.categoryNameAr')}</label>
                    <input type="text" bind:value={newCatNameAr} placeholder="اسم الفئة" dir="rtl" class="w-full px-4 py-3 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent" />
                </div>
            </div>

            <div class="flex justify-end gap-3 mt-8">
                <button class="px-5 py-2.5 bg-slate-100 text-slate-700 font-bold rounded-xl hover:bg-slate-200 transition-all text-sm" on:click={closeAddCategoryPopup}>
                    {$t('finance.assets.cancel')}
                </button>
                <button class="px-6 py-2.5 bg-emerald-600 text-white font-bold rounded-xl hover:bg-emerald-700 transition-all shadow-lg shadow-emerald-200 text-sm flex items-center gap-2" on:click={addCategory}>
                    <span>💾</span>
                    {$t('finance.assets.save')}
                </button>
            </div>
        </div>
    </div>
{/if}

<!-- ==================== EDIT CATEGORY POPUP ==================== -->
{#if showEditCategoryPopup}
    <div class="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-[9999]" on:click|self={cancelEditCategory}>
        <div class="bg-white rounded-3xl shadow-2xl p-8 w-full max-w-lg mx-4 transform transition-all" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
            <div class="flex items-center justify-between mb-6">
                <h3 class="text-lg font-bold text-slate-800 flex items-center gap-2">
                    <span>✏️</span>
                    {$t('finance.assets.editCategory')}
                </h3>
                <button class="p-2 hover:bg-slate-100 rounded-xl transition-all text-slate-400 hover:text-slate-600" on:click={cancelEditCategory}>❌</button>
            </div>

            {#if catDuplicateError}
                <div class="mb-4 p-3 bg-red-50 border border-red-200 rounded-xl text-red-700 text-sm font-semibold flex items-center gap-2">
                    <span>⚠️</span>
                    {catDuplicateError}
                </div>
            {/if}

            <div class="space-y-4">
                <div>
                    <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('finance.assets.groupCode')}</label>
                    <input type="text" bind:value={editCatGroupCode} placeholder="PPE-XXX" class="w-full px-4 py-3 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent uppercase font-mono" />
                </div>
                <div>
                    <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('finance.assets.categoryNameEn')}</label>
                    <input type="text" bind:value={editCatNameEn} placeholder="Category name" class="w-full px-4 py-3 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent" />
                </div>
                <div>
                    <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('finance.assets.categoryNameAr')}</label>
                    <input type="text" bind:value={editCatNameAr} placeholder="اسم الفئة" dir="rtl" class="w-full px-4 py-3 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent" />
                </div>
            </div>

            <div class="flex justify-end gap-3 mt-8">
                <button class="px-5 py-2.5 bg-slate-100 text-slate-700 font-bold rounded-xl hover:bg-slate-200 transition-all text-sm" on:click={cancelEditCategory}>
                    {$t('finance.assets.cancel')}
                </button>
                <button class="px-6 py-2.5 bg-emerald-600 text-white font-bold rounded-xl hover:bg-emerald-700 transition-all shadow-lg shadow-emerald-200 text-sm flex items-center gap-2" on:click={saveEditCategory}>
                    <span>💾</span>
                    {$t('finance.assets.save')}
                </button>
            </div>
        </div>
    </div>
{/if}

<!-- ==================== ADD ITEM POPUP ==================== -->
{#if showAddItemPopup}
    <div class="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-[9999]" on:click|self={closeAddItemPopup}>
        <div class="bg-white rounded-3xl shadow-2xl p-8 w-full max-w-2xl mx-4 transform transition-all" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
            <div class="flex items-center justify-between mb-6">
                <h3 class="text-lg font-bold text-slate-800 flex items-center gap-2">
                    <span>📦</span>
                    {$t('finance.assets.addItem')}
                </h3>
                <button class="p-2 hover:bg-slate-100 rounded-xl transition-all text-slate-400 hover:text-slate-600" on:click={closeAddItemPopup}>❌</button>
            </div>

            {#if itemDuplicateError}
                <div class="mb-4 p-3 bg-red-50 border border-red-200 rounded-xl text-red-700 text-sm font-semibold flex items-center gap-2">
                    <span>⚠️</span>
                    {itemDuplicateError}
                </div>
            {/if}

            <div class="grid grid-cols-2 gap-4">
                <div>
                    <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('finance.assets.assetCategory')}</label>
                    <select bind:value={newItemCategoryId} on:change={() => { const cat = dbCategories.find(c => String(c.id) === String(newItemCategoryId)); newItemGroupCode = cat ? cat.group_code : ''; }} class="w-full px-4 py-3 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500">
                        <option value="">{$t('finance.assets.selectCategory')}</option>
                        {#each dbCategories as cat}
                            <option value={cat.id}>{$locale === 'ar' ? cat.name_ar : cat.name_en}</option>
                        {/each}
                    </select>
                </div>
                <div>
                    <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('finance.assets.groupCode')}</label>
                    <input type="text" value={newItemGroupCode} readonly class="w-full px-4 py-3 bg-slate-100 border border-slate-200 rounded-xl text-sm text-slate-500 uppercase font-mono cursor-not-allowed" />
                </div>
                <div>
                    <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('finance.assets.itemNameEn')}</label>
                    <input type="text" bind:value={newItemNameEn} placeholder="Item name" class="w-full px-4 py-3 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500" />
                </div>
                <div>
                    <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('finance.assets.itemNameAr')}</label>
                    <input type="text" bind:value={newItemNameAr} placeholder="اسم الصنف" dir="rtl" class="w-full px-4 py-3 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500" />
                </div>
                <div>
                    <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('finance.assets.usefulLife')}</label>
                    <input type="text" bind:value={newItemUsefulLife} placeholder="5" class="w-full px-4 py-3 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500" />
                </div>
                <div>
                    <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('finance.assets.annualDep')}</label>
                    <input type="number" bind:value={newItemAnnualDep} on:input={() => { newItemMonthlyDep = newItemAnnualDep ? (parseFloat(newItemAnnualDep) / 12).toFixed(2) : ''; }} placeholder="0" step="0.01" class="w-full px-4 py-3 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500" />
                </div>
                <div>
                    <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('finance.assets.monthlyDep')}</label>
                    <input type="number" value={newItemMonthlyDep} readonly class="w-full px-4 py-3 bg-slate-100 border border-slate-200 rounded-xl text-sm text-slate-500 cursor-not-allowed" />
                </div>
                <div>
                    <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('finance.assets.residual')}</label>
                    <input type="text" bind:value={newItemResidualPct} placeholder="0%" class="w-full px-4 py-3 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500" />
                </div>
            </div>

            <div class="flex justify-end gap-3 mt-8">
                <button class="px-5 py-2.5 bg-slate-100 text-slate-700 font-bold rounded-xl hover:bg-slate-200 transition-all text-sm" on:click={closeAddItemPopup}>
                    {$t('finance.assets.cancel')}
                </button>
                <button class="px-6 py-2.5 bg-orange-600 text-white font-bold rounded-xl hover:bg-orange-700 transition-all shadow-lg shadow-orange-200 text-sm flex items-center gap-2" on:click={addItem}>
                    <span>💾</span>
                    {$t('finance.assets.save')}
                </button>
            </div>
        </div>
    </div>
{/if}

<!-- ==================== EDIT ITEM POPUP ==================== -->
{#if showEditItemPopup}
    <div class="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-[9999]" on:click|self={cancelEditItem}>
        <div class="bg-white rounded-3xl shadow-2xl p-8 w-full max-w-2xl mx-4 transform transition-all" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
            <div class="flex items-center justify-between mb-6">
                <h3 class="text-lg font-bold text-slate-800 flex items-center gap-2">
                    <span>✏️</span>
                    {$t('finance.assets.editItem')}
                </h3>
                <button class="p-2 hover:bg-slate-100 rounded-xl transition-all text-slate-400 hover:text-slate-600" on:click={cancelEditItem}>❌</button>
            </div>

            {#if itemDuplicateError}
                <div class="mb-4 p-3 bg-red-50 border border-red-200 rounded-xl text-red-700 text-sm font-semibold flex items-center gap-2">
                    <span>⚠️</span>
                    {itemDuplicateError}
                </div>
            {/if}

            <div class="grid grid-cols-2 gap-4">
                <div>
                    <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('finance.assets.itemNameEn')}</label>
                    <input type="text" bind:value={editItemNameEn} placeholder="Item name" class="w-full px-4 py-3 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500" />
                </div>
                <div>
                    <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('finance.assets.itemNameAr')}</label>
                    <input type="text" bind:value={editItemNameAr} placeholder="اسم الصنف" dir="rtl" class="w-full px-4 py-3 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500" />
                </div>
                <div>
                    <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('finance.assets.usefulLife')}</label>
                    <input type="text" bind:value={editItemUsefulLife} placeholder="5" class="w-full px-4 py-3 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500" />
                </div>
                <div>
                    <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('finance.assets.annualDep')}</label>
                    <input type="number" bind:value={editItemAnnualDep} on:input={() => { editItemMonthlyDep = editItemAnnualDep ? (parseFloat(editItemAnnualDep) / 12).toFixed(2) : ''; }} placeholder="0" step="0.01" class="w-full px-4 py-3 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500" />
                </div>
                <div>
                    <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('finance.assets.monthlyDep')}</label>
                    <input type="number" value={editItemMonthlyDep} readonly class="w-full px-4 py-3 bg-slate-100 border border-slate-200 rounded-xl text-sm text-slate-500 cursor-not-allowed" />
                </div>
                <div>
                    <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('finance.assets.residual')}</label>
                    <input type="text" bind:value={editItemResidualPct} placeholder="0%" class="w-full px-4 py-3 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500" />
                </div>
            </div>

            <div class="flex justify-end gap-3 mt-8">
                <button class="px-5 py-2.5 bg-slate-100 text-slate-700 font-bold rounded-xl hover:bg-slate-200 transition-all text-sm" on:click={cancelEditItem}>
                    {$t('finance.assets.cancel')}
                </button>
                <button class="px-6 py-2.5 bg-orange-600 text-white font-bold rounded-xl hover:bg-orange-700 transition-all shadow-lg shadow-orange-200 text-sm flex items-center gap-2" on:click={saveEditItem}>
                    <span>💾</span>
                    {$t('finance.assets.save')}
                </button>
            </div>
        </div>
    </div>
{/if}

<!-- ==================== EDIT ASSET POPUP ==================== -->
{#if showEditAssetPopup}
    <div class="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-[9999]" on:click|self={cancelEditAsset}>
        <div class="bg-white rounded-3xl shadow-2xl p-8 w-full max-w-2xl mx-4 transform transition-all max-h-[90vh] overflow-y-auto" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
            <div class="flex items-center justify-between mb-6">
                <h3 class="text-lg font-bold text-slate-800 flex items-center gap-2">
                    <span>✏️</span>
                    {$t('finance.assets.editAsset')}
                </h3>
                <button class="p-2 hover:bg-slate-100 rounded-xl transition-all text-slate-400 hover:text-slate-600" on:click={cancelEditAsset}>❌</button>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-2 gap-5">
                <!-- Asset ID (editable) -->
                <div>
                    <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('finance.assets.assetId')}</label>
                    <input type="text" bind:value={editAssetIdValue} class="w-full px-4 py-3 bg-slate-50 border border-slate-200 rounded-xl text-sm font-mono font-bold text-emerald-700 focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent" />
                </div>

                <!-- Sub Category -->
                <div>
                    <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('finance.assets.selectAssetItem')}</label>
                    <select bind:value={editAssetSubCategoryId} class="w-full px-4 py-3 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent">
                        <option value="">{$t('finance.assets.selectAssetItem')}</option>
                        {#each dbItems as item}
                            <option value={item.id}>{$locale === 'ar' ? (item.name_ar || item.name_en) : item.name_en} ({item.group_code})</option>
                        {/each}
                    </select>
                </div>

                <!-- Asset Name EN -->
                <div>
                    <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('finance.assets.assetNameEn')}</label>
                    <input type="text" bind:value={editAssetNameEn} placeholder="Asset name" class="w-full px-4 py-3 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent" />
                </div>

                <!-- Asset Name AR -->
                <div>
                    <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('finance.assets.assetNameAr')}</label>
                    <input type="text" bind:value={editAssetNameAr} placeholder="اسم الأصل" dir="rtl" class="w-full px-4 py-3 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent" />
                </div>

                <!-- Purchase Date -->
                <div>
                    <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('finance.assets.purchaseDate')}</label>
                    <input type="date" bind:value={editAssetPurchaseDate} class="w-full px-4 py-3 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent" />
                </div>

                <!-- Purchase Value -->
                <div>
                    <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('finance.assets.purchaseValue')}</label>
                    <input type="number" bind:value={editAssetPurchaseValue} placeholder="0.00" step="0.01" min="0" class="w-full px-4 py-3 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent" />
                </div>

                <!-- Branch -->
                <div>
                    <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('finance.assets.selectBranch')}</label>
                    <select bind:value={editAssetBranch} class="w-full px-4 py-3 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent">
                        <option value="">{$t('finance.assets.selectBranchPlaceholder')}</option>
                        {#each branches as branch}
                            <option value={branch.id}>{$locale === 'ar' ? (branch.name_ar || branch.name_en) : branch.name_en}{$locale === 'ar' ? (branch.location_ar ? ` - ${branch.location_ar}` : '') : (branch.location_en ? ` - ${branch.location_en}` : '')}</option>
                        {/each}
                    </select>
                </div>

                <!-- Invoice -->
                <div class="md:col-span-2">
                    <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('finance.assets.invoice')}</label>
                    <div class="flex items-center gap-3">
                        {#if editAssetInvoiceUrl && !editAssetInvoiceFile}
                            <a href={editAssetInvoiceUrl} target="_blank" class="px-3 py-2 bg-blue-50 border border-blue-200 text-blue-600 hover:bg-blue-100 rounded-xl text-xs font-bold transition-all flex items-center gap-1.5">
                                <span>👁️</span>
                                {$t('finance.assets.viewInvoice')}
                            </a>
                            <label class="px-3 py-2 bg-orange-50 border border-orange-200 text-orange-600 hover:bg-orange-100 rounded-xl text-xs font-bold transition-all flex items-center gap-1.5 cursor-pointer">
                                <span>🔄</span>
                                {$t('finance.assets.updateInvoice')}
                                <input type="file" on:change={handleEditFileSelect} class="hidden" />
                            </label>
                        {:else if editAssetInvoiceFile}
                            <span class="text-xs text-emerald-600 font-semibold truncate max-w-[200px]">✅ {editAssetInvoiceFile.name}</span>
                            <button class="px-2 py-1 bg-red-50 text-red-500 hover:bg-red-100 rounded-lg text-xs font-bold" on:click={() => { editAssetInvoiceFile = null; }}>✖</button>
                        {:else}
                            <label class="px-3 py-2 bg-emerald-50 border border-emerald-200 text-emerald-600 hover:bg-emerald-100 rounded-xl text-xs font-bold transition-all flex items-center gap-1.5 cursor-pointer">
                                <span>📤</span>
                                {$t('finance.assets.uploadInvoice')}
                                <input type="file" on:change={handleEditFileSelect} class="hidden" />
                            </label>
                        {/if}
                    </div>
                </div>
            </div>

            <div class="flex justify-end gap-3 mt-8">
                <button class="px-5 py-2.5 bg-slate-100 text-slate-700 font-bold rounded-xl hover:bg-slate-200 transition-all text-sm" on:click={cancelEditAsset}>
                    {$t('finance.assets.cancel')}
                </button>
                <button
                    class="px-6 py-2.5 bg-emerald-600 text-white font-bold rounded-xl hover:bg-emerald-700 transition-all shadow-lg shadow-emerald-200 text-sm flex items-center gap-2 disabled:opacity-50 disabled:cursor-not-allowed"
                    on:click={saveEditAsset}
                    disabled={savingEditAsset || !editAssetNameEn.trim()}
                >
                    {#if savingEditAsset}
                        <span class="animate-spin">⏳</span>
                    {:else}
                        <span>💾</span>
                    {/if}
                    {$t('finance.assets.save')}
                </button>
            </div>
        </div>
    </div>
{/if}

