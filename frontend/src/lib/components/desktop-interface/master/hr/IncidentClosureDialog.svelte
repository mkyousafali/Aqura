<script lang="ts">
    import { _ as t } from '$lib/i18n';
    import { locale } from '$lib/i18n';
    import { createEventDispatcher, onMount } from 'svelte';
    import { supabase } from '$lib/utils/supabase';
    import { currentUser } from '$lib/utils/persistentAuth';

    export let incident: any = null;
    export let onComplete = () => {};

    const dispatch = createEventDispatcher();

    let loading = false;
    let isAcknowledged = false;
    let acknowledgmentNotes = '';
    let selectedImage: File | null = null;
    let imagePreviewUrl: string | null = null;
    let isUploadingImage = false;

    onMount(() => {
        console.log('📋 Incident loaded for acknowledgment:', incident);
    });

    function handleImageSelect(e: Event) {
        const input = e.target as HTMLInputElement;
        const file = input.files?.[0];
        
        if (file) {
            // Validate file type
            if (!file.type.startsWith('image/')) {
                alert($locale === 'ar' ? 'يرجى تحديد ملف صورة صحيح' : 'Please select a valid image file');
                return;
            }
            
            // Validate file size (max 10MB)
            if (file.size > 10 * 1024 * 1024) {
                alert($locale === 'ar' ? 'حجم الصورة أكبر من 10 ميجابايت' : 'Image size exceeds 10MB');
                return;
            }
            
            selectedImage = file;
            const reader = new FileReader();
            reader.onload = (e) => {
                imagePreviewUrl = e.target?.result as string;
            };
            reader.readAsDataURL(file);
        }
    }

    function clearImage() {
        selectedImage = null;
        imagePreviewUrl = null;
    }

    async function handleSubmit() {
        // Check if acknowledgment checkbox is checked
        if (!isAcknowledged) {
            alert($locale === 'ar' 
                ? '⚠️ يجب تحديد أنك قد اطلعت على الحادثة' 
                : '⚠️ You must confirm you have acknowledged the incident');
            return;
        }

        loading = true;
        let uploadedImageUrl: string | null = null;

        try {
            // Upload image if selected
            if (selectedImage) {
                isUploadingImage = true;
                const fileName = `incident-ack-${Date.now()}-${Math.random().toString(36).substr(2, 9)}.${selectedImage.name.split('.').pop()}`;
                const { data: uploadData, error: uploadError } = await supabase.storage
                    .from('documents')
                    .upload(`incidents/${fileName}`, selectedImage);
                
                if (uploadError) {
                    throw new Error(`Image upload failed: ${uploadError.message}`);
                }
                
                // Get the public URL
                const { data: { publicUrl } } = supabase.storage
                    .from('documents')
                    .getPublicUrl(`incidents/${fileName}`);
                
                uploadedImageUrl = publicUrl;
                isUploadingImage = false;
            }
            // Get current user_statuses
            const userStatusesObj = typeof incident.user_statuses === 'string' 
                ? JSON.parse(incident.user_statuses) 
                : (incident.user_statuses || {});
            
            // Update current user's status to acknowledged (but don't overwrite 'claimed' status)
            const currentStatus = userStatusesObj[$currentUser.id];
            const isClaimed = currentStatus?.status?.toLowerCase() === 'claimed' || currentStatus?.claimed_at;
            userStatusesObj[$currentUser.id] = {
                ...currentStatus,
                status: isClaimed ? 'claimed' : 'acknowledged',
                acknowledged_at: new Date().toISOString(),
                acknowledgment_notes: acknowledgmentNotes,
                acknowledgment_image_url: uploadedImageUrl
            };

            // Update incident with new user_statuses
            const updateData: any = {
                user_statuses: userStatusesObj,
                updated_by: $currentUser.id,
                updated_at: new Date().toISOString()
            };
            
            // Append the acknowledgment image to the attachments array
            if (uploadedImageUrl) {
                const currentAttachments = Array.isArray(incident.attachments) ? incident.attachments : [];
                currentAttachments.push({
                    url: uploadedImageUrl,
                    name: selectedImage?.name || 'acknowledgment-image',
                    type: 'image',
                    size: selectedImage?.size || 0,
                    uploaded_at: new Date().toISOString(),
                    uploaded_by: $currentUser.id,
                    context: 'acknowledgment'
                });
                updateData.attachments = currentAttachments;
            }

            const { error: updateError } = await supabase
                .from('incidents')
                .update(updateData)
                .eq('id', incident.id);

            if (updateError) throw updateError;

            alert($locale === 'ar' 
                ? '✅ تم تأكيد الاستلام بنجاح' 
                : '✅ Incident acknowledged successfully');
            
            onComplete();
            dispatch('close');
        } catch (error) {
            console.error('Error acknowledging incident:', error);
            alert($locale === 'ar' 
                ? `❌ خطأ: ${error instanceof Error ? error.message : 'فشل التأكيد'}` 
                : `❌ Error: ${error instanceof Error ? error.message : 'Failed to acknowledge'}`);
        } finally {
            loading = false;
        }
    }

    function handleClose() {
        dispatch('close');
    }
</script>

<div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
    <div class="bg-white rounded-lg shadow-xl max-w-lg w-full">
        <!-- Header -->
        <div class="bg-gradient-to-r from-blue-50 to-cyan-50 border-b border-blue-200 px-6 py-4 flex items-center justify-between">
            <div class="flex items-center gap-3">
                <span class="text-3xl">👍</span>
                <div>
                    <h2 class="text-xl font-bold text-slate-800">
                        {$locale === 'ar' ? 'تأكيد استلام الحادثة' : 'Acknowledge Incident'}
                    </h2>
                    <p class="text-sm text-slate-600">{incident?.id}</p>
                </div>
            </div>
            <button 
                on:click={handleClose}
                class="text-slate-500 hover:text-slate-700"
            >
                ✕
            </button>
        </div>

        <!-- Content -->
        <div class="p-6 space-y-6">
            <!-- Incident Summary -->
            <div class="bg-slate-50 border border-slate-200 rounded-lg p-4">
                <h3 class="font-semibold text-slate-800 mb-3">
                    {$locale === 'ar' ? 'ملخص الحادثة' : 'Incident Summary'}
                </h3>
                <div class="grid grid-cols-2 gap-4 text-sm">
                    <div>
                        <p class="text-slate-600">{$locale === 'ar' ? 'رقم الحادثة' : 'Incident ID'}</p>
                        <p class="font-mono text-slate-800">{incident?.id}</p>
                    </div>
                    <div>
                        <p class="text-slate-600">{$locale === 'ar' ? 'نوع الحادثة' : 'Type'}</p>
                        <p class="font-medium text-slate-800">
                            {$locale === 'ar' 
                                ? incident?.incident_types?.incident_type_ar 
                                : incident?.incident_types?.incident_type_en}
                        </p>
                    </div>
                    <div>
                        <p class="text-slate-600">{$locale === 'ar' ? 'الموظف' : 'Employee'}</p>
                        <p class="font-medium text-slate-800">{incident?.employeeName}</p>
                    </div>
                    <div>
                        <p class="text-slate-600">{$locale === 'ar' ? 'الفرع' : 'Branch'}</p>
                        <p class="font-medium text-slate-800">{incident?.branchName}</p>
                    </div>
                </div>
            </div>

            <!-- Acknowledgment Checkbox (MANDATORY) -->
            <div class="border-l-4 border-yellow-400 bg-yellow-50 p-4 rounded">
                <label class="flex items-start gap-3 cursor-pointer">
                    <input 
                        type="checkbox" 
                        bind:checked={isAcknowledged}
                        class="w-5 h-5 mt-0.5 accent-blue-600"
                    />
                    <div>
                        <p class="font-semibold text-slate-800">
                            {$locale === 'ar' ? '✓ تأكيد الاستلام' : '✓ Confirm Receipt'}
                        </p>
                        <p class="text-sm text-slate-600 mt-1">
                            {$locale === 'ar' 
                                ? 'أؤكد أنني قد اطلعت على هذه الحادثة' 
                                : 'I confirm I have reviewed this incident report'}
                        </p>
                    </div>
                </label>
            </div>

            <!-- Acknowledgment Notes (Optional) -->
            <div>
                <label class="block text-sm font-semibold text-slate-800 mb-2">
                    {$locale === 'ar' ? 'ملاحظات (اختياري)' : 'Notes (Optional)'}
                </label>
                <textarea 
                    bind:value={acknowledgmentNotes}
                    placeholder={$locale === 'ar' ? 'أضف ملاحظاتك...' : 'Add your notes...'}
                    class="w-full px-3 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none text-sm resize-none"
                    rows="3"
                ></textarea>
            </div>

            <!-- Image Upload (Optional) -->
            <div>
                <label for="ack-image-upload" class="block text-sm font-semibold text-slate-800 mb-2">
                    📸 {$locale === 'ar' ? 'تحميل صورة (اختياري)' : 'Upload Image (Optional)'}
                </label>
                <div class="flex gap-2">
                    <input 
                        id="ack-image-upload"
                        type="file" 
                        accept="image/*"
                        on:change={handleImageSelect}
                        disabled={isUploadingImage}
                        class="flex-1 px-3 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none text-sm hover:border-slate-300 transition cursor-pointer disabled:opacity-50"
                    />
                    {#if selectedImage}
                        <button 
                            type="button"
                            on:click={clearImage}
                            disabled={isUploadingImage}
                            class="px-3 py-2 bg-red-100 hover:bg-red-200 text-red-700 rounded-lg text-sm font-bold disabled:opacity-50 transition"
                        >
                            ✕
                        </button>
                    {/if}
                </div>
                {#if selectedImage}
                    <p class="text-xs text-green-600 mt-1">✓ {selectedImage.name}</p>
                {/if}
                {#if imagePreviewUrl}
                    <div class="mt-2 rounded-lg overflow-hidden border border-slate-200">
                        <img src={imagePreviewUrl} alt="Preview" class="w-full h-32 object-cover" />
                    </div>
                {/if}
            </div>
        </div>

        <!-- Footer -->
        <div class="bg-slate-50 border-t border-slate-200 px-6 py-4 flex gap-3 justify-end">
            <button 
                on:click={handleClose}
                disabled={loading}
                class="px-4 py-2 border border-slate-300 text-slate-700 rounded-lg hover:bg-slate-100 disabled:opacity-50"
            >
                {$locale === 'ar' ? 'إلغاء' : 'Cancel'}
            </button>
            <button 
                on:click={handleSubmit}
                disabled={loading || !isAcknowledged}
                class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50 flex items-center gap-2"
            >
                {#if loading}
                    ⏳ {$locale === 'ar' ? 'جاري...' : 'Processing...'}
                {:else}
                    👍 {$locale === 'ar' ? 'تأكيد الاستلام' : 'Acknowledge'}
                {/if}
            </button>
        </div>
    </div>
</div>

<style>
    :global(.font-sans) {
        font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    }
</style>
