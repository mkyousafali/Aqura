<script lang="ts">
	import DirectOrder from '$lib/components/desktop-interface/master/vendor/DirectOrder.svelte';
	import { t } from '$lib/i18n';
</script>

<svelte:head><title>{t('nav.directOrder')} - Aqura</title></svelte:head>

<DirectOrder mobile />
