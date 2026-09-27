<script lang="ts">
 import { onMount, tick } from 'svelte';
 import { API_SETUP_GUIDES } from '$lib/config/apiSetupGuides';
 import { API_SERVICES, findApiService } from '$lib/config/apiServices';
 let guideDialog: HTMLDialogElement;
 let guideService = '';
 $: guide = API_SETUP_GUIDES[guideService];
 async function showGuide(name: string) {
  guideService = name;
  await tick();
  guideDialog.showModal();
 }
 let apiKeys: any[] = [];
 let loading = true;
 let busy = false;
 let globalError = '';
 let message = '';
 let addingNew = false;
 let serviceName = '';
 let newKey = '';
 let replacing: string | number | null = null;
 let replacement = '';
 let revealed: Record<string, boolean> = {};
 $: missingServices = API_SERVICES.filter(service => !apiKeys.some(key => key.service_name === service.name));
 $: cards = [
  ...API_SERVICES.map(service => apiKeys.find(key => key.service_name === service.name) || { service_name: service.name, is_active: false }),
  ...apiKeys.filter(key => !findApiService(key.service_name))
 ];
 onMount(loadKeys);
 async function loadKeys() {
  loading = true;
  globalError = '';
  try {
   const response = await fetch('/api/system-api-keys', { cache: 'no-store' });
   const result = await response.json();
   if (!response.ok || !result.success) throw new Error(result.error || 'Unable to load keys.');
   apiKeys = result.keys;
  } catch (error: any) { globalError = error.message; }
  finally { loading = false; }
 }
 async function change(action: string, params: Record<string, unknown>) {
  busy = true;
  globalError = '';
  message = '';
  try {
   const response = await fetch('/api/system-api-keys', {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ action, ...params })
   });
   const result = await response.json();
   if (!response.ok || !result.success) throw new Error(result.error || 'Unable to save changes.');
   if (action === 'delete') { apiKeys = apiKeys.filter(key => key.id !== params.id); replacing = null; replacement = ''; revealed[String(params.id)] = false; }
   else apiKeys = [...apiKeys.filter(key => key.id !== result.key.id), result.key].sort((a, b) => a.service_name.localeCompare(b.service_name));
   if (action === 'rotate') { replacing = null; replacement = ''; revealed[String(params.id)] = false; }
   if (action === 'insert') { addingNew = false; serviceName = ''; newKey = ''; }
   message = action === 'rotate' ? 'Replacement saved. Test the service before revoking the old key with its provider.' : 'Changes saved.';
  } catch (error: any) { globalError = error.message; }
  finally { busy = false; }
 }
 function removeKey(key: any) {
  if (confirm(`Remove ${key.service_name}? Its listed features will stop working until an active key is added.`)) void change('delete', { id: key.id });
 }
 function maskKey(value: string) { return value?.length > 8 ? value.slice(0, 4) + ' ******** ' + value.slice(-4) : '********'; }
</script>

<div class="api-keys-manager">
 <div class="header">
  <div class="header-left"><div><h2 class="header-title">API Keys Manager</h2><p class="header-subtitle">Shared keys stored in system_api_keys</p></div></div>
  <div class="card-actions">
   <button class="btn-add" disabled={busy || loading} on:click={loadKeys}>Refresh</button>
   <button class="btn-add" disabled={busy || loading || missingServices.length === 0} on:click={() => { addingNew = !addingNew; newKey = ''; serviceName = missingServices[0]?.name || ''; }}> {addingNew ? 'Cancel' : '+ Add key'}</button>
  </div>
 </div>
 <p class="help">Replace key: create a new key with its provider, save it here, test, then revoke the old key with the provider. New requests use the saved key. Reload pages after changing the Google key.</p>
 <p class="help">WhatsApp / Meta tokens: manage in <strong>WhatsApp Accounts</strong> (wa_accounts).</p>
 {#if globalError}<div class="error-banner" role="alert">{globalError}</div>{/if}
 {#if message}<p class="notice" role="status">{message}</p>{/if}
 {#if loading}<div class="loading">Loading API keys...</div>
 {:else}
  {#if missingServices.length}<p class="help">Missing: {missingServices.map(service => service.title).join(', ')}. Use Add key to restore them.</p>{/if}
  <div class="keys-list">
   {#each cards as key (key.service_name)}
    {@const service = findApiService(key.service_name)}
    <div class="key-card" class:inactive={!key.is_active}>
     <div class="card-header">
      <div class="service-info"><span class="service-icon">{service?.icon || ''}</span><div><div class="service-name">{service?.title || key.service_name}</div><div class="service-desc">Table key: <code>{key.service_name}</code></div></div></div>
      <div class="card-actions">
       {#if API_SETUP_GUIDES[key.service_name]}
        <button class="btn-icon" title="How to get this key and enable its APIs" aria-haspopup="dialog" on:click={() => showGuide(key.service_name)}>Setup guide</button>
       {/if}
       {#if key.id != null}
       <button class="toggle-btn" class:active={key.is_active} disabled={busy} on:click={() => change('toggle', { id: key.id, is_active: !key.is_active })}>{key.is_active ? 'Active / Disable' : 'Disabled / Enable'}</button>
       <button class="btn-delete" disabled={busy} on:click={() => removeKey(key)}>Remove</button>
       {:else}
       <span class="service-desc">Not configured</span>
       {/if}
      </div>
     </div>
     {#if service}
      <table class="usage"><thead><tr><th>API / function</th><th>Used in</th></tr></thead><tbody>{#each service.usage as use}<tr><td>{use.api}</td><td>{use.usedIn}</td></tr>{/each}</tbody></table>
     {:else}<p class="help">{key.description || 'Usage not registered for this service.'}</p>{/if}
     {#if key.id != null}
     <div class="key-input-row">
      <input class="key-input" aria-label={`${key.service_name} current key`} readonly value={revealed[key.id] ? key.api_key : maskKey(key.api_key)} />
      <button class="btn-icon" on:click={() => revealed[key.id] = !revealed[key.id]}>{revealed[key.id] ? 'Hide' : 'Show'}</button>
      <button class="btn-save-key" disabled={busy} on:click={() => { replacing = key.id; replacement = ''; }}>Replace key</button>
     </div>
     {#if replacing === key.id}
      <form class="key-input-row" on:submit|preventDefault={() => change('rotate', { id: key.id, api_key: replacement })}>
       <input class="key-input" aria-label={`${key.service_name} replacement key`} type="password" autocomplete="new-password" placeholder="Paste replacement key" bind:value={replacement} disabled={busy} />
       <button class="btn-save-key" disabled={busy || !replacement.trim()}>{busy ? 'Saving...' : 'Save replacement'}</button>
       <button type="button" class="btn-icon" disabled={busy} on:click={() => { replacing = null; replacement = ''; }}>Cancel</button>
      </form>
     {/if}
     <div class="card-footer">Updated: {key.updated_at ? new Date(key.updated_at).toLocaleString() : 'Unknown'}{#if !key.is_active} - Disabled: enable this key to use its services.{/if}</div>
     {:else}
      <form class="key-input-row" on:submit|preventDefault={() => change('insert', { service_name: key.service_name, api_key: newKey })}>
       {#if addingNew && serviceName === key.service_name}
        <input class="key-input" aria-label={`${key.service_name} new key`} type="password" autocomplete="new-password" placeholder="Paste API key" bind:value={newKey} disabled={busy} />
        <button class="btn-save-key" disabled={busy || !newKey.trim()}>{busy ? 'Saving...' : 'Save key'}</button>
        <button type="button" class="btn-icon" disabled={busy} on:click={() => { addingNew = false; newKey = ''; }}>Cancel</button>
       {:else}
        <button type="button" class="btn-save-key" disabled={busy} on:click={() => { addingNew = true; serviceName = key.service_name; newKey = ''; }}>Add key</button>
       {/if}
      </form>
     {/if}
    </div>
   {/each}
  </div>
 {/if}
</div>

<dialog class="setup-dialog" bind:this={guideDialog} aria-labelledby="setup-guide-title">
 {#if guide}
  <div class="guide-header">
   <h2 id="setup-guide-title">{findApiService(guideService)?.title} setup</h2>
   <button class="btn-icon" on:click={() => guideDialog.close()} aria-label="Close setup guide">Close</button>
  </div>
  <div class="guide-body">
   <h3>Get the key</h3>
   <ol>{#each guide.steps as step}<li>{step}</li>{/each}</ol>
   <h3>Enable / allow</h3>
   <ul>{#each guide.enable as item}<li>{item}</li>{/each}</ul>
   <h3>Before saving</h3>
   <ul>{#each guide.notes as note}<li>{note}</li>{/each}</ul>
   <h3>Check it works</h3>
   <p>{guide.check}</p>
   <p>Replacing a key: save the new key, test, then revoke the old key with the provider.</p>
   <h3>Official links</h3>
   <div class="guide-links">{#each guide.links as link}<a href={link.url} target="_blank" rel="noopener noreferrer">{link.label} (opens new tab)</a>{/each}</div>
  </div>
 {/if}
</dialog>

<style>
 .setup-dialog { width: min(640px, calc(100vw - 2rem)); max-height: calc(100dvh - 2rem); padding: 0; border: 1px solid #e2e8f0; border-radius: 12px; background: #fff; color: #1e293b; box-shadow: 0 20px 60px rgb(15 23 42 / 20%); font-family: inherit; }
 .setup-dialog::backdrop { background: rgb(15 23 42 / 45%); }
 .guide-header { display: flex; align-items: center; justify-content: space-between; gap: 1rem; padding: 1rem 1.25rem; background: #f8fafc; border-bottom: 1px solid #e2e8f0; }
 .guide-header h2 { margin: 0; font-size: 1.1rem; color: #0f172a; }
 .guide-body { padding: .25rem 1.25rem 1.25rem; font-size: .875rem; line-height: 1.6; }
 .guide-body h3 { margin: 1rem 0 .4rem; font-size: .9rem; color: #0f172a; }
 .guide-body ul, .guide-body ol { margin: 0; padding-inline-start: 1.25rem; }
 .guide-body li { margin-bottom: .4rem; }
 .guide-links { display: flex; flex-wrap: wrap; gap: .5rem 1rem; }
 .guide-links a { color: #1d4ed8; text-underline-offset: 3px; }
 .guide-links a:focus-visible { outline: 2px solid #3b82f6; outline-offset: 2px; }

 .api-keys-manager { padding: 1.5rem; background: #f8fafc; min-height: 100%; color: #1e293b; font-family: inherit; box-sizing: border-box; }
 .header, .card-header { display: flex; align-items: center; justify-content: space-between; gap: 1rem; flex-wrap: wrap; }
 .header { margin-bottom: 1.25rem; padding-bottom: 1rem; border-bottom: 1px solid #e2e8f0; }
 .header-title { margin: 0; font-size: 1.25rem; font-weight: 700; color: #0f172a; }
 .header-subtitle { margin: .25rem 0 0; font-size: .8rem; color: #64748b; }
 .help { color: #64748b; font-size: .85rem; line-height: 1.5; margin-bottom: 1rem; }
 .notice, .error-banner { padding: .75rem 1rem; border-radius: 8px; margin-bottom: 1rem; font-size: .85rem; line-height: 1.5; }
 .notice { background: #dcfce7; color: #166534; border: 1px solid #bbf7d0; }
 .error-banner { background: #fee2e2; color: #991b1b; border: 1px solid #fecaca; }
 .loading { text-align: center; color: #64748b; padding: 3rem; font-size: .9rem; }
 .keys-list { display: flex; flex-direction: column; gap: 1rem; }
 .key-card { background: #fff; border: 1px solid #e2e8f0; border-radius: 12px; padding: 1.25rem; box-shadow: 0 1px 3px rgb(15 23 42 / 4%); }
 .key-card.inactive { border-style: dashed; }
 .service-info { display: flex; align-items: center; gap: .75rem; min-width: 0; }
 .service-icon { display: flex; align-items: center; justify-content: center; width: 2.5rem; height: 2.5rem; border-radius: 10px; background: #eff6ff; font-size: 1.5rem; flex-shrink: 0; }
 .service-name { font-weight: 700; font-size: .95rem; color: #0f172a; }
 .service-desc { font-size: .78rem; color: #64748b; margin-top: .2rem; overflow-wrap: anywhere; }
 .card-actions { display: flex; align-items: center; gap: .5rem; flex-wrap: wrap; }
 button { font-family: inherit; font-size: .8rem; font-weight: 600; padding: .5rem .8rem; border-radius: 6px; border: 1px solid transparent; cursor: pointer; transition: background .15s; }
 button:disabled { opacity: .5; cursor: not-allowed; }
 button:focus-visible, .key-input:focus-visible { outline: 2px solid #3b82f6; outline-offset: 2px; }
 .btn-add, .btn-save-key { background: #3b82f6; color: #fff; }
 .btn-add:hover:not(:disabled), .btn-save-key:hover:not(:disabled) { background: #2563eb; }
 .toggle-btn { background: #f1f5f9; color: #475569; border-color: #cbd5e1; }
 .toggle-btn:hover:not(:disabled) { background: #e2e8f0; }
 .toggle-btn.active { background: #dcfce7; color: #166534; border-color: #bbf7d0; }
 .toggle-btn.active:hover:not(:disabled) { background: #bbf7d0; }
 .btn-delete { background: #fff; color: #b91c1c; border-color: #fecaca; }
 .btn-delete:hover:not(:disabled) { background: #fee2e2; }
 .btn-icon { background: #f1f5f9; color: #475569; }
 .btn-icon:hover:not(:disabled) { background: #e2e8f0; }
 .usage { width: 100%; border-collapse: collapse; font-size: .85rem; margin: 1rem 0; }
 .usage th, .usage td { text-align: start; padding: .65rem .75rem; border-bottom: 1px solid #e2e8f0; vertical-align: top; overflow-wrap: anywhere; }
 .usage th { color: #475569; background: #f8fafc; font-size: .78rem; font-weight: 600; }
 .usage td:first-child { width: 28%; font-weight: 500; }
 .key-input-row { display: flex; align-items: center; flex-wrap: wrap; gap: .5rem; background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 8px; padding: .5rem; margin-top: .5rem; }
 .key-input { min-width: 0; flex: 1 1 12rem; padding: .5rem; border: 1px solid #cbd5e1; border-radius: 6px; background: #fff; color: #1e293b; font-family: monospace; font-size: .85rem; }
 .key-input[readonly] { background: transparent; border-color: transparent; }
 .key-input::placeholder { color: #64748b; }
 .card-footer { font-size: .75rem; color: #64748b; margin-top: .75rem; text-align: end; }
 @media (max-width: 640px) {
  .api-keys-manager { padding: 1rem; }
  .key-card { padding: 1rem; }
  .usage th, .usage td { padding: .5rem; }
  .key-input { flex-basis: 100%; }
 }
</style>
