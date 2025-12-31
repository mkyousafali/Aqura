<script lang="ts">
	import { t } from '$lib/i18n';
	// Welcome window component
</script>

<div class="p-6">
	<div class="mb-6 text-center">
		<div class="w-24 h-24 bg-gradient-to-br from-orange-400 to-orange-600 rounded-2xl mx-auto mb-4 flex items-center justify-center">
			<span class="text-white text-3xl font-bold">A</span>
		</div>
		<h1 class="text-2xl font-bold mb-2">{t('welcome.title') || 'Welcome to Aqura!'}</h1>
		<p class="text-gray-600">{t('welcome.subtitle') || 'Your PWA-first windowed management platform'}</p>
	</div>
	<div class="space-y-3 text-left max-w-md mx-auto">
		<div class="flex items-center gap-3">
			<span class="text-green-500">✓</span>
			<span>{t('welcome.features.multiWindow') || 'Multi-window interface'}</span>
		</div>
		<div class="flex items-center gap-3">
			<span class="text-green-500">✓</span>
			<span>{t('welcome.features.offline') || 'Offline-first functionality'}</span>
		</div>
		<div class="flex items-center gap-3">
			<span class="text-green-500">✓</span>
			<span>{t('welcome.features.responsive') || 'Mobile & desktop ready'}</span>
		</div>
		<div class="flex items-center gap-3">
			<span class="text-green-500">✓</span>
			<span>{t('welcome.features.bilingual') || 'Bilingual support'}</span>
		</div>
	</div>
	<div class="mt-6 text-center">
		<p class="text-sm text-gray-500">
			{t('welcome.instructions') || 'Try dragging windows, resizing them, and using the window controls!'}
		</p>
	</div>
</div>
