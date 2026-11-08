<script lang="ts">
  import { currentLocale, t } from '$lib/i18n';
  import AvailabilityPosters from './AvailabilityPosters.svelte';

  const tabs = ['availability', 'newArrival'] as const;
  const instanceId = `posters-${Math.random().toString(36).slice(2)}`;
  let activeTab: typeof tabs[number] = 'availability';

  function handleTabKeydown(event: KeyboardEvent) {
    const index = tabs.indexOf(activeTab);
    const forward = $currentLocale === 'ar' ? 'ArrowLeft' : 'ArrowRight';
    const backward = $currentLocale === 'ar' ? 'ArrowRight' : 'ArrowLeft';
    let nextIndex = index;

    if (event.key === forward) nextIndex = (index + 1) % tabs.length;
    else if (event.key === backward) nextIndex = (index + tabs.length - 1) % tabs.length;
    else if (event.key === 'Home') nextIndex = 0;
    else if (event.key === 'End') nextIndex = tabs.length - 1;
    else return;

    event.preventDefault();
    activeTab = tabs[nextIndex];
    const button = event.currentTarget as HTMLButtonElement;
    button.parentElement?.querySelectorAll<HTMLButtonElement>('[role="tab"]')[nextIndex]?.focus();
  }
</script>

  <div class="posters" dir={$currentLocale === 'ar' ? 'rtl' : 'ltr'}>
    {#key $currentLocale}
    <div class="tabs" role="tablist" aria-label={t('nav.posters')}>
      {#each tabs as tab}
        <button
          type="button"
          role="tab"
          id={`${instanceId}-${tab}-tab`}
          aria-controls={`${instanceId}-${tab}-panel`}
          aria-selected={activeTab === tab}
          tabindex={activeTab === tab ? 0 : -1}
          class:active={activeTab === tab}
          on:click={() => activeTab = tab}
          on:keydown={handleTabKeydown}
        >
          {t(`posters.${tab}`)}
        </button>
      {/each}
    </div>
    {/key}

    {#each tabs as tab}
      <section
        class="tab-content"
        role="tabpanel"
        id={`${instanceId}-${tab}-panel`}
        aria-labelledby={`${instanceId}-${tab}-tab`}
        tabindex="0"
        hidden={activeTab !== tab}
      >
        {#if tab === 'availability'}
          <AvailabilityPosters />
        {:else}
          {#key $currentLocale}
            <p class="coming-soon">{t('posters.comingSoon')}</p>
          {/key}
        {/if}
      </section>
    {/each}
  </div>

<style>
  .posters {
    display: flex;
    flex-direction: column;
    min-height: 100%;
    background: #f8fafc;
  }

  .tabs {
    display: flex;
    gap: 0.5rem;
    padding: 1rem 1rem 0;
    border-bottom: 1px solid #e2e8f0;
    background: white;
  }

  .tabs button {
    padding: 0.75rem 1.25rem;
    border: 0;
    border-bottom: 3px solid transparent;
    background: transparent;
    color: #64748b;
    font: inherit;
    font-weight: 600;
    cursor: pointer;
  }

  .tabs button:hover {
    color: #c46600;
    background: #fff7ed;
  }

  .tabs button.active {
    border-bottom-color: #f08300;
    color: #c46600;
  }

  .tabs button:focus-visible,
  .tab-content:focus-visible {
    outline: 2px solid #f08300;
    outline-offset: -2px;
  }

  .tab-content {
    flex: 1;
    padding: 1.5rem;
    color: #64748b;
  }

  .coming-soon {
    padding: 2.5rem 0;
    text-align: center;
  }
</style>
