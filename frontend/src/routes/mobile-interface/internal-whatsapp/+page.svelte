<script lang="ts">
  import WALiveChat from '$lib/components/desktop-interface/whatsapp/WALiveChat.svelte';
</script>
<div class="internal-wa"><WALiveChat accountScope="internal" /></div>
<style>:global(.mobile-layout),:global(.mobile-content){overflow-y:hidden!important}.internal-wa{position:relative;flex:1;width:100%;min-height:0;overflow:hidden;background:#fff}</style>
