<script lang="ts">
  // Internal account status is read directly from Meta through whatsapp-manage.
  import { onMount } from 'svelte';
  import { getEdgeFunctionUrl } from '$lib/utils/supabase';
  import { getScopedWhatsAppAccount } from '$lib/whatsapp/accountScope';
  import { currentLocale } from '$lib/i18n';
  let supabase:any, account:any=null, loading=true, checking=false, message='', metaDetail='';
  onMount(async()=>{const mod=await import('$lib/utils/supabase');supabase=mod.supabase;await load();});
  async function load(){loading=true;try{account=await getScopedWhatsAppAccount(supabase,'internal','*');}finally{loading=false;}}
  async function checkStatus(){
    checking=true;message='';metaDetail='';
    try{
      const session=(await supabase.auth.getSession()).data.session;
      const response=await fetch(getEdgeFunctionUrl('whatsapp-manage'),{method:'POST',headers:{'Content-Type':'application/json',Authorization:`Bearer ${session?.access_token}`},body:JSON.stringify({action:'get_phone_numbers',account_id:account.id})});
      const result=await response.json();
      if(!response.ok||result?.error)throw new Error(result?.error||'Unable to read status from Meta');
      const payload=result?.data;
      const numbers=Array.isArray(payload)?payload:Array.isArray(payload?.data)?payload.data:[];
      const meta=numbers.find((number:any)=>number.id===account.phone_number_id);
      if(!meta)throw new Error($currentLocale==='ar'?'لم يتم العثور على الرقم في حساب Meta':'The number was not found in the Meta account');
      const verification=String(meta.code_verification_status||'pending').toUpperCase();
      const nameStatus=String(meta.name_status||'pending').toUpperCase();
      const status=verification==='VERIFIED'&&(nameStatus==='APPROVED'||nameStatus==='AVAILABLE')?'connected':'pending';
      const arMeta:Record<string,string>={VERIFIED:'تم التحقق',APPROVED:'تمت الموافقة',AVAILABLE:'متاح',PENDING:'قيد الانتظار',DECLINED:'مرفوض'};
      metaDetail=$currentLocale==='ar'?`تحقق الرقم: ${arMeta[verification]||verification} · حالة الاسم: ${arMeta[nameStatus]||nameStatus}`:`Number verification: ${verification} · Display name: ${nameStatus}`;
      await supabase.from('wa_accounts').update({status,updated_at:new Date().toISOString()}).eq('id',account.id);
      await load();
      message=status==='connected'?($currentLocale==='ar'?'متصل':'Connected'):($currentLocale==='ar'?'قيد انتظار موافقة Meta':'Waiting for Meta approval');
    }catch(error:any){message=error.message||($currentLocale==='ar'?'تعذر التحقق من الحالة':'Unable to check status');}finally{checking=false;}
  }
</script>
<div class="panel">
  <h2>{$currentLocale==='ar'?'حساب واتساب الداخلي':'Internal WhatsApp Account'}</h2>
  {#if loading}<p>{$currentLocale==='ar'?'جارٍ التحميل…':'Loading…'}</p>{:else if account}
    <div class="card"><strong>{account.display_name}</strong><span>{account.phone_number}</span><span>{$currentLocale==='ar'?'معرّف الهاتف':'Phone ID'}: {account.phone_number_id}</span><span class:ok={account.status==='connected'}>{account.status==='connected'?($currentLocale==='ar'?'متصل':'Connected'):($currentLocale==='ar'?'قيد الانتظار':'Pending')}</span>{#if metaDetail}<small>{metaDetail}</small>{/if}</div>
    <button on:click={checkStatus} disabled={checking}>{checking?($currentLocale==='ar'?'جارٍ التحقق…':'Checking…'):($currentLocale==='ar'?'التحقق من الحالة':'Check Status')}</button>
    {#if message}<p>{message}</p>{/if}
  {:else}<p>{$currentLocale==='ar'?'لم يتم إعداد الحساب الداخلي':'Internal account is not configured.'}</p>{/if}
</div>
<style>
  .panel{box-sizing:border-box;min-height:100%;padding:24px;color:#334155;background:#f8fafc}
  h2{margin:0 0 18px;color:#334155;font-size:20px}.card{display:grid;gap:10px;padding:18px;margin:18px 0;background:#fff;border:1px solid #dbe4ee;border-radius:10px;color:#334155;box-shadow:0 3px 12px rgba(15,23,42,.08)}
  .ok{color:#059669}button{padding:10px 18px;border:1px solid #0ea5b7;border-radius:7px;background:#13bfd0;color:#fff;font-weight:700;cursor:pointer;box-shadow:0 3px 10px rgba(19,191,208,.18)}button:hover{background:#0ea5b7}button:disabled{opacity:.6;cursor:wait}small{color:#64748b}
</style>
