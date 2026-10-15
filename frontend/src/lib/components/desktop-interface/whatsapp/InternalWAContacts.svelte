<script lang="ts">
  import { onMount } from 'svelte';
  import { currentLocale } from '$lib/i18n';
  let supabase:any; let contacts:any[]=[]; let loading=true; let search=''; let selected=new Set<string>();
  onMount(async()=>{const mod=await import('$lib/utils/supabase');supabase=mod.supabase;await load();});
  async function load(){loading=true;const {data}=await supabase.rpc('get_internal_whatsapp_contacts',{p_limit:500,p_offset:0,p_search:search||null});contacts=data||[];selected=new Set();loading=false;}
  function toggle(id:string){const n=new Set(selected);n.has(id)?n.delete(id):n.add(id);selected=n;}
  function all(){selected=selected.size===contacts.length?new Set():new Set(contacts.map(c=>c.employee_id));}
  function employeeName(c:any){return $currentLocale==='ar'?(c.name_ar||c.name):(c.name||c.name_ar);}
  function statusLabel(status:string){
    if($currentLocale!=='ar')return status;
    return ({'Job (With Finger)':'على رأس العمل','Remote Job':'عمل عن بُعد','Vacation':'إجازة','Resigned':'مستقيل'} as Record<string,string>)[status]||status;
  }
</script>
<div class="panel"><h2>{$currentLocale==='ar'?'جهات الاتصال الداخلية':'Internal Contacts'}</h2><div class="tools"><input bind:value={search} on:keydown={(e)=>e.key==='Enter'&&load()} placeholder={$currentLocale==='ar'?'بحث الموظفين':'Search employees'}><button on:click={load}>{$currentLocale==='ar'?'بحث':'Search'}</button><button on:click={all}>{selected.size===contacts.length?($currentLocale==='ar'?'إلغاء التحديد':'Clear'):($currentLocale==='ar'?'تحديد الكل':'Select all')}</button></div>
{#if loading}<p>{$currentLocale==='ar'?'جارٍ التحميل…':'Loading…'}</p>{:else}<div class="list">{#each contacts as c}<label><input type="checkbox" checked={selected.has(c.employee_id)} on:change={()=>toggle(c.employee_id)}><span><strong>{employeeName(c)}</strong><small>{c.whatsapp_number} · {statusLabel(c.employment_status)}</small></span></label>{/each}</div>{/if}</div>
<style>
  .panel{box-sizing:border-box;min-height:100%;padding:24px;color:#334155;background:#f8fafc}h2{margin:0;color:#334155;font-size:20px}
  .tools{display:flex;gap:8px;margin:18px 0}.tools input{flex:1;padding:10px 12px;background:#fff;border:1px solid #cbd5e1;color:#0f172a;border-radius:7px;outline:none}.tools input:focus{border-color:#13bfd0;box-shadow:0 0 0 3px rgba(19,191,208,.12)}.tools button{padding:9px 14px;border-radius:7px;border:1px solid #0ea5b7;background:#13bfd0;color:#fff;font-weight:600;cursor:pointer}.tools button:hover{background:#0ea5b7}
  .list{display:grid;gap:8px}label{display:flex;align-items:center;gap:12px;padding:13px;background:#fff;border:1px solid #dbe4ee;border-radius:8px;box-shadow:0 1px 3px rgba(15,23,42,.04);transition:.15s}label:hover{border-color:#94a3b8;background:#f8fafc}label span{display:grid}input[type="checkbox"]{accent-color:#13bfd0}small{color:#64748b;margin-top:4px}
</style>
