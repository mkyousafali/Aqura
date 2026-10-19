<script lang="ts">
  import WALiveChat from '$lib/components/desktop-interface/whatsapp/WALiveChat.svelte';
</script>

<div class="internal-wa">
  <WALiveChat accountScope="internal" />
</div>

<style>
  :global(.mobile-layout) {
    overflow-y: hidden !important;
  }

  /* The shared chat is absolutely positioned; its wrapper needs a flex parent
     to fill the mobile content area instead of collapsing to zero height. */
  :global(.mobile-content) {
    display: flex;
    flex-direction: column;
    min-height: 0;
    overflow-y: hidden !important;
  }

  .internal-wa {
    position: relative;
    flex: 1;
    width: 100%;
    min-height: 0;
    overflow: hidden;
    background: #ffffff;
  }
</style>
