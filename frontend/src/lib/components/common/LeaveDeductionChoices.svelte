<script lang="ts">
  import { locale, t } from '$lib/i18n';
  export let days: { id: string; date: string }[] = [];
  export let choices: Record<string, boolean> = {};
  export let approvedDays: Record<string, boolean> = {};
  export let showApproval = false;
  export let disabled = false;

  function choose(id: string, deduct: boolean) {
    const next = { ...choices };
    if (next[id] === deduct) delete next[id];
    else next[id] = deduct;
    choices = next;
  }

  function chooseAll(deduct: boolean) {
    choices = Object.fromEntries(days.map(day => [day.id, deduct]));
  }
</script>

<section class="leave-decisions" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
  <p>{t('approvalCenter.leaveDeductionRequired')}</p>
  <div class="bulk-choices">
    <button type="button" on:click={() => chooseAll(true)} {disabled}>{t('approvalCenter.deductAll')}</button>
    <button type="button" on:click={() => chooseAll(false)} {disabled}>{t('approvalCenter.dontDeductAll')}</button>
  </div>
  <div class="decision-days">
    {#each days as day (day.id)}
      <div class="decision-day">
        <div class="day-heading">
          <strong>{new Date(day.date + 'T12:00:00Z').toLocaleDateString($locale === 'ar' ? 'ar-SA-u-ca-gregory' : 'en-GB', { timeZone: 'Asia/Riyadh' })}</strong>
          {#if showApproval}
            <label><input type="checkbox" bind:checked={approvedDays[day.id]} {disabled} />{t('approvalCenter.approve')}</label>
          {/if}
        </div>
        <div class="day-choices" role="group" aria-label={`${t('approvalCenter.deductibleOnSalary')} ${day.date}`}>
          <label><input type="checkbox" checked={choices[day.id] === true} on:change={() => choose(day.id, true)} {disabled} />{t('approvalCenter.deductSalary')}</label>
          <label><input type="checkbox" checked={choices[day.id] === false} on:change={() => choose(day.id, false)} {disabled} />{t('approvalCenter.dontDeductSalary')}</label>
        </div>
      </div>
    {/each}
  </div>
</section>

<style>
  .leave-decisions { margin: .75rem 0; font-size: .875rem; text-align: start; }
  p { color: #475569; margin: 0 0 .6rem; }
  .bulk-choices { display: flex; flex-wrap: wrap; gap: .5rem; margin-bottom: .75rem; }
  button { border: 1px solid #cbd5e1; border-radius: 6px; background: #f1f5f9; padding: .5rem .7rem; cursor: pointer; }
  .decision-days { max-height: 45vh; overflow: auto; display: grid; gap: .5rem; }
  .decision-day { padding: .7rem; border: 1px solid #e2e8f0; border-radius: 8px; background: #fff; }
  .day-heading, .day-choices { display: flex; justify-content: space-between; flex-wrap: wrap; gap: .6rem; }
  .day-choices { margin-top: .55rem; justify-content: flex-start; column-gap: 1rem; }
  label { display: inline-flex; align-items: center; gap: .4rem; min-height: 2rem; cursor: pointer; }
  .leave-decisions input[type="checkbox"] {
    appearance: none;
    -webkit-appearance: none;
    display: inline-block;
    flex: 0 0 18px;
    width: 18px;
    height: 18px;
    margin: 0;
    border: 2px solid #64748b;
    border-radius: 3px;
    background-color: #fff;
    background-image: none;
    background-position: center;
    background-repeat: no-repeat;
    background-size: 14px 14px;
    cursor: pointer;
  }
  .leave-decisions input[type="checkbox"]:checked {
    border-color: #1d4ed8;
    background-color: #2563eb;
    background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16'%3E%3Cpath d='m3 8 3 3 7-7' fill='none' stroke='white' stroke-width='2.5' stroke-linecap='round' stroke-linejoin='round'/%3E%3C/svg%3E");
  }
  .leave-decisions input[type="checkbox"]:focus-visible { outline: 2px solid #2563eb; outline-offset: 3px; }
  .leave-decisions input[type="checkbox"]:disabled { opacity: .5; cursor: default; }
  button:disabled { opacity: .5; cursor: default; }
</style>
