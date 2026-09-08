<script lang="ts">
  import ManualFlyerGenerator from './ManualFlyerGenerator.svelte';
  import AiFlyerGenerator from './AiFlyerGenerator.svelte';
  let tab: 'manual' | 'ai' | 'library' = 'manual';
  let aiOpened = false;
  let aiBusy = false;
  function selectTab(value: typeof tab) {
    tab = value;
    if (value !== 'manual') aiOpened = true;
  }
</script>

<div class="flyer-window">
  <nav aria-label="Flyer generation methods">
    <button disabled={aiBusy} class:active={tab === 'manual'} aria-pressed={tab === 'manual'} on:click={() => selectTab('manual')}>Generate Without AI</button>
    <button disabled={aiBusy} class:active={tab === 'ai'} aria-pressed={tab === 'ai'} on:click={() => selectTab('ai')}>Generate With AI</button>
    <button disabled={aiBusy} class:active={tab === 'library'} aria-pressed={tab === 'library'} on:click={() => selectTab('library')}>AI Generated Flyers</button>
  </nav>
  <!-- Keep both instances mounted so switching tabs preserves manual edits and generated pages. -->
  <div class="panel" class:inactive={tab !== 'manual'}><ManualFlyerGenerator /></div>
  {#if aiOpened}<div class="panel" class:inactive={tab === 'manual'}><AiFlyerGenerator bind:busy={aiBusy} section={tab === 'library' ? 'library' : 'generate'} /></div>{/if}
</div>

<style>
  .flyer-window{height:100%;display:flex;flex-direction:column;min-height:0;}nav{display:flex;gap:8px;padding:12px 16px;background:white;border-bottom:1px solid #e2e8f0;flex-shrink:0;flex-wrap:wrap;}button{padding:10px 16px;border-radius:8px;background:#f1f5f9;color:#334155;font-weight:600;border:1px solid transparent;cursor:pointer;}button.active{background:#4338ca;color:white;}.panel{flex:1;min-height:0;overflow:auto;}.inactive{display:none;}
</style>
