<script lang="ts">
	import BakeryWindow from './BakeryWindow.svelte';
	import { COFFEE_COUNTER } from '$lib/types/businessCounter';

	export let windowId: string;
</script>

<BakeryWindow {windowId} profile={COFFEE_COUNTER} />
