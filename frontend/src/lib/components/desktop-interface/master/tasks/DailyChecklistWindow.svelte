<script lang="ts">
	import { windowManager } from '$lib/stores/windowManager';

	export let windowId: string;
</script>

<div class="daily-checklist-window">
	<p>Daily Checklist Content</p>
</div>

<style>
	.daily-checklist-window {
		padding: 20px;
		height: 100%;
		overflow-y: auto;
	}
</style>
