<script lang="ts">
	import { windowManager } from '$lib/stores/windowManager';

	export let windowId: string;

	function closeWindow() {
		windowManager.closeWindow(windowId);
	}
</script>

<div class="leave-request-container">
	<!-- Blank content area -->
	<div class="content-area">
		<!-- Leave request form and content will be added here -->
	</div>
</div>

<style>
	.leave-request-container {
		display: flex;
		flex-direction: column;
		height: 100%;
		background: white;
	}

	.content-area {
		flex: 1;
		padding: 0;
		overflow-y: auto;
	}
</style>
