<script lang="ts">
	// Mobile Live Chat — reuses the desktop WhatsApp Live Chat component.
	// WALiveChat measures its own container width and switches to a single-panel
	// (list <-> chat) responsive layout automatically, so no mobile-only fork is needed.
	import WALiveChat from '$lib/components/desktop-interface/whatsapp/WALiveChat.svelte';
</script>

<div class="wa-live-chat-mobile">
	<WALiveChat />
</div>

<style>
	/* This page manages its own scrolling — stop the layout from double-scrolling */
	:global(.mobile-layout) {
		overflow-y: hidden !important;
	}
	:global(.mobile-content) {
		overflow-y: hidden !important;
		display: flex;
		flex-direction: column;
	}

	/* WALiveChat positions itself with `absolute inset-0`, so give it a
	   positioned box that fills the content area above the bottom nav. */
	.wa-live-chat-mobile {
		position: relative;
		flex: 1;
		width: 100%;
		min-height: 0;
		overflow: hidden;
		background: #ffffff;
	}
</style>
