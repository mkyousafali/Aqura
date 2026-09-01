<!-- ReceivingTasksManager.svelte -->
<!-- Container with 2 sections: Default Positions & Receiving Task Templates -->
<script lang="ts">
  import { locale } from '$lib/i18n';
  import DefaultPositions from '$lib/components/desktop-interface/master/vendor/DefaultPositions.svelte';
  import ReceivingTaskTemplates from '$lib/components/desktop-interface/master/vendor/ReceivingTaskTemplates.svelte';
  import StandaloneReceivingTasks from '$lib/components/desktop-interface/master/vendor/StandaloneReceivingTasks.svelte';

  let activeTab: 'positions' | 'templates' | 'receivingTasks' = 'positions';

  $: isRTL = $locale === 'ar';
</script>

<div class="rtm-container">
  <div class="rtm-tabs">
    <button
      class="rtm-tab"
      class:active={activeTab === 'positions'}
      on:click={() => (activeTab = 'positions')}
    >
      👥 {isRTL ? 'المناصب الافتراضية' : 'Default Positions'}
    </button>
    <button
      class="rtm-tab"
      class:active={activeTab === 'templates'}
      on:click={() => (activeTab = 'templates')}
    >
      📋 {isRTL ? 'قوالب مهام الاستلام' : 'Receiving Task Templates'}
    </button>
    <button
      class="rtm-tab"
      class:active={activeTab === 'receivingTasks'}
      on:click={() => (activeTab = 'receivingTasks')}
    >
      🧩 {isRTL ? 'مهام الاستلام' : 'Receiving Tasks'}
    </button>
  </div>

  <div class="rtm-content">
    {#if activeTab === 'positions'}
      <DefaultPositions />
    {:else if activeTab === 'templates'}
      <ReceivingTaskTemplates />
    {:else}
      <StandaloneReceivingTasks />
    {/if}
  </div>
</div>

<style>
  .rtm-container {
    height: 100%;
    display: flex;
    flex-direction: column;
    background: linear-gradient(135deg, #e8f0fe 0%, #f0f7ff 50%, #e8f4f8 100%);
  }

  .rtm-tabs {
    display: flex;
    gap: 0.5rem;
    padding: 0.75rem 1rem 0;
    flex-shrink: 0;
  }

  .rtm-tab {
    padding: 0.6rem 1.25rem;
    background: rgba(255, 255, 255, 0.55);
    border: 1px solid rgba(255, 255, 255, 0.9);
    border-bottom: none;
    border-radius: 10px 10px 0 0;
    cursor: pointer;
    font-size: 0.88rem;
    font-weight: 600;
    color: #64748b;
    transition: all 0.2s;
  }
  .rtm-tab:hover { background: rgba(255, 255, 255, 0.8); color: #1e293b; }
  .rtm-tab.active {
    background: rgba(255, 255, 255, 0.85);
    color: #1d4ed8;
    box-shadow: 0 -2px 10px rgba(59, 130, 246, 0.08);
  }

  .rtm-content {
    flex: 1;
    overflow: hidden;
    display: flex;
  }
  .rtm-content > :global(*) {
    flex: 1;
  }

  .coming-soon {
    flex: 1;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 1.1rem;
    font-weight: 600;
    color: #64748b;
  }
</style>
