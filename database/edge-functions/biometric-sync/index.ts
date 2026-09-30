import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const H = { 'Content-Type': 'application/json' };
const TIMEOUT = 45_000;
const SAUDI_OFFSET_MS = 3 * 60 * 60 * 1000;
type R = Record<string, any>;
const statusMap: Record<number, string> = { 0:'Check In', 1:'Check Out', 2:'Break Out', 3:'Break In', 4:'Overtime In', 5:'Overtime Out' };

const response = (status:number, body:R) => new Response(JSON.stringify(body), { status, headers:H });
const d = (v:any) => String(v || '').slice(0,10);
const t = (v:any) => String(v || '').match(/T(\d{2}:\d{2}:\d{2})/)?.[1] || String(v || '').slice(11,19);
const key = (r:R) => `${r.employee_id}-${r.date}-${r.time}-${r.status}-${r.branch_id}`;

async function postBridge(base:string, secret:string, path:string, body:R) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), TIMEOUT);
  try {
    const res = await fetch(`${base.replace(/\/$/,'')}${path}`, { method:'POST', headers:{...H,'x-api-secret':secret}, body:JSON.stringify(body), signal:controller.signal });
    const raw = await res.text();
    let payload:R;
    try { payload=JSON.parse(raw); } catch { throw new Error(`BRIDGE_INVALID_RESPONSE: HTTP ${res.status}`); }
    if (!res.ok || payload.success !== true) throw new Error(`BRIDGE_ERROR: ${payload.error || `HTTP ${res.status}`}`);
    return Array.isArray(payload.recordset) ? payload.recordset as R[] : [];
  } catch (e) {
    if (e instanceof DOMException && e.name === 'AbortError') throw new Error('BRIDGE_TIMEOUT: request exceeded 45 seconds');
    throw e;
  } finally { clearTimeout(timer); }
}

async function processBranch(sb:any, config:R, options:R, actor:string|null) {
  const runId=crypto.randomUUID();
  const branchId=Number(config.branch_id);
  const branchName=String(config.branch_name || `Branch ${branchId}`);
  const syncType=String(options.syncType || 'punches');
  const dryRun=Boolean(options.dryRun);
  const triggerType=String(options.triggerType || 'scheduled');
  const started=Date.now();
  let logId:number|null=null;
  let locked=false;
  try {
    const {data:lock,error:lockError}=await sb.rpc('acquire_biometric_sync_lock',{p_branch_id:branchId,p_run_id:runId,p_seconds:240});
    if(lockError) throw new Error(`LOCK_ERROR: ${lockError.message}`);
    if(!lock) return {branchId,branchName,status:'skipped',reason:'Another synchronization is already running'};
    locked=true;
    const {data:log,error:logError}=await sb.from('biometric_sync_logs').insert({run_id:runId,branch_id:branchId,branch_name:branchName,sync_type:dryRun?'dry-run':syncType,trigger_type:triggerType,triggered_by:actor,status:'running'}).select('id').single();
    if(logError) throw new Error(`LOG_ERROR: ${logError.message}`);
    logId=log.id;

    let fetched=0, inserted=0, updated=0, skipped=0, duplicates=0;
    const details:R={};
    const now=new Date();
    const maxDays=Math.max(1,Math.min(Number(options.windowDays || 3),30));
    let from=new Date(now.getTime()-maxDays*86_400_000);
    if(!options.from && !dryRun && config.last_sync_at){
      const cursor=new Date(config.last_sync_at);
      const catchup=new Date(cursor.getTime()-maxDays*86_400_000);
      const floor=new Date(now.getTime()-30*86_400_000);
      from=catchup>floor?catchup:floor;
    }
    if(options.from) from=new Date(String(options.from));
    const to=options.to?new Date(String(options.to)):now;
    if(!Number.isFinite(from.getTime())||!Number.isFinite(to.getTime())||from>=to) throw new Error('INVALID_WINDOW: invalid synchronization date range');

    if(syncType==='employees'||syncType==='both'){
      const source=await postBridge(config.tunnel_url,config.bridge_api_secret,'/biometric/employees',{});
      fetched+=source.length;
      const employees=source.filter((x:R)=>x.emp_code!=null&&x.first_name!=null).map((x:R)=>({employee_id:`${config.branch_location_code}${x.emp_code}`,name:String(x.first_name),branch_id:branchId}));
      const {data:existing,error}=await sb.from('hr_employees').select('employee_id,name').eq('branch_id',branchId);
      if(error) throw new Error(`AQURA_READ_ERROR: ${error.message}`);
      const map=new Map((existing||[]).map((x:R)=>[String(x.employee_id),String(x.name||'')]));
      const creates=employees.filter((x:R)=>!map.has(x.employee_id)).map((x:R)=>({...x,status:'active'}));
      const changes=employees.filter((x:R)=>map.has(x.employee_id)&&map.get(x.employee_id)!==x.name);
      skipped+=employees.length-creates.length-changes.length;
      details.employees={fetched:source.length,wouldCreate:creates.length,wouldUpdate:changes.length};
      if(!dryRun){
        if(creates.length){const {error:e}=await sb.from('hr_employees').insert(creates);if(e)throw new Error(`EMPLOYEE_INSERT_ERROR: ${e.message}`);inserted+=creates.length;}
        for(const emp of changes){const {error:e}=await sb.from('hr_employees').update({name:emp.name,updated_at:new Date().toISOString()}).eq('branch_id',branchId).eq('employee_id',emp.employee_id);if(e)throw new Error(`EMPLOYEE_UPDATE_ERROR: ${e.message}`);updated++;}
        const {error:e}=await sb.from('biometric_connections').update({last_employee_sync_at:new Date().toISOString()}).eq('branch_id',branchId).eq('is_active',true);if(e)throw new Error(`CURSOR_UPDATE_ERROR: ${e.message}`);
      }
    }

    if(syncType==='punches'||syncType==='both'){
      // ZKBioTime stores punch_time as a Saudi local wall-clock value in a
      // timezone-less SQL Server column. Shift UTC boundaries to UTC+3 before
      // the bridge binds them as DateTime2 values.
      const bridgeFrom=new Date(from.getTime()+SAUDI_OFFSET_MS);
      const bridgeTo=new Date(to.getTime()+SAUDI_OFFSET_MS);
      const source=await postBridge(config.tunnel_url,config.bridge_api_secret,'/biometric/punches',{from:bridgeFrom.toISOString(),to:bridgeTo.toISOString()});
      fetched+=source.length;
      const transformed=source.map((x:R)=>{const status=statusMap[Number(x.punch_state)];return status?{employee_id:`${config.branch_location_code}${x.emp_code}`,date:d(x.punch_time),time:t(x.punch_time),status,device_id:String(x.terminal_sn||x.terminal_alias||'Unknown'),location:String(x.area_alias||'Unknown'),branch_id:branchId}:null}).filter(Boolean) as R[];
      const grouped=new Map<string,R[]>();
      for(const row of transformed)grouped.set(row.employee_id,[...(grouped.get(row.employee_id)||[]),row]);
      const filtered:R[]=[];
      for(const rows of grouped.values()){
        rows.sort((a,b)=>`${a.date}T${a.time}`.localeCompare(`${b.date}T${b.time}`));
        for(let i=0;i<rows.length;i++){
          const next=rows[i+1];
          if(next){const diff=new Date(`${next.date}T${next.time}Z`).getTime()-new Date(`${rows[i].date}T${rows[i].time}Z`).getTime();if(diff>=0&&diff<=120000){duplicates++;continue;}}
          filtered.push(rows[i]);
        }
      }
      const min=filtered.map(x=>x.date).sort()[0]||d(from.toISOString());
      const max=filtered.map(x=>x.date).sort().at(-1)||d(to.toISOString());
      const {data:existing,error}=await sb.from('hr_fingerprint_transactions').select('employee_id,date,time,status,branch_id').eq('branch_id',branchId).gte('date',min).lte('date',max);
      if(error)throw new Error(`AQURA_READ_ERROR: ${error.message}`);
      const keys=new Set((existing||[]).map((x:R)=>key(x)));
      const fresh=filtered.filter(x=>!keys.has(key(x)));
      skipped+=filtered.length-fresh.length;
      details.punches={fetched:source.length,valid:transformed.length,duplicatesFiltered:duplicates,alreadyExisting:filtered.length-fresh.length,wouldInsert:fresh.length,from:from.toISOString(),to:to.toISOString(),bridgeFrom:bridgeFrom.toISOString(),bridgeTo:bridgeTo.toISOString()};
      if(!dryRun){
        for(let i=0;i<fresh.length;i+=100){const batch=fresh.slice(i,i+100);const {error:e}=await sb.from('hr_fingerprint_transactions').upsert(batch,{onConflict:'employee_id,date,time,status,branch_id',ignoreDuplicates:true});if(e)throw new Error(`PUNCH_INSERT_ERROR: ${e.message}`);inserted+=batch.length;}
        const {error:e}=await sb.from('biometric_connections').update({last_sync_at:new Date().toISOString()}).eq('branch_id',branchId).eq('is_active',true);if(e)throw new Error(`CURSOR_UPDATE_ERROR: ${e.message}`);
      }
    }

    const finalStatus='success';
    await sb.from('biometric_sync_logs').update({status:finalStatus,finished_at:new Date().toISOString(),window_from:from.toISOString(),window_to:to.toISOString(),records_fetched:fetched,records_inserted:dryRun?0:inserted,records_updated:dryRun?0:updated,records_skipped:skipped,duplicates_filtered:duplicates,details:{...details,dryRun,durationMs:Date.now()-started}}).eq('id',logId);
    const result={branchId,branchName,status:finalStatus,dryRun,fetched,inserted:dryRun?0:inserted,updated:dryRun?0:updated,skipped,duplicatesFiltered:duplicates,details,durationMs:Date.now()-started};
    console.log(JSON.stringify({event:'biometric_sync_completed',...result}));
    return result;
  }catch(error){
    const message=error instanceof Error?error.message:String(error);const code=message.includes(':')?message.split(':')[0]:'SYNC_ERROR';
    if(logId)await sb.from('biometric_sync_logs').update({status:'failed',finished_at:new Date().toISOString(),error_code:code,error_message:message,details:{durationMs:Date.now()-started}}).eq('id',logId);
    console.error(JSON.stringify({event:'biometric_sync_failed',branchId,branchName,error:message}));
    return {branchId,branchName,status:'failed',error:message};
  }finally{if(locked)await sb.rpc('release_biometric_sync_lock',{p_branch_id:branchId,p_run_id:runId});}
}

Deno.serve(async(req:Request)=>{
  if(req.method==='OPTIONS')return response(200,{ok:true});
  if(req.method!=='POST')return response(405,{success:false,error:'POST required'});
  const url=Deno.env.get('SUPABASE_URL')||'';const serviceKey=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')||'';
  if(!url||!serviceKey)return response(500,{success:false,error:'Server configuration is incomplete'});
  const token=req.headers.get('authorization')?.replace(/^Bearer\s+/i,'')||'';
  const sb=createClient(url,serviceKey,{auth:{persistSession:false}});
  const isService=token===serviceKey;
  let actor:string|null=null;
  if(!isService){const {data,error}=await sb.auth.getUser(token);if(error||!data.user)return response(401,{success:false,error:'Authentication required'});actor=data.user.id;}
  let body:R={};try{body=await req.json();}catch{}
  const triggerType=isService
    ? (body.triggerType === 'test' ? 'test' : body.triggerType === 'manual' ? 'manual' : 'scheduled')
    : 'manual';
  const syncType=['punches','employees','both'].includes(body.syncType)?body.syncType:'punches';
  const dryRun=Boolean(body.dryRun);
  let query=sb.from('branches').select('id,name_en,is_active,biometric_edge_sync_enabled');
  if(body.branchId)query=query.eq('id',Number(body.branchId));else query=query.eq('biometric_edge_sync_enabled',true).eq('is_active',true);
  const {data:branches,error}=await query;if(error)return response(500,{success:false,error:error.message});
  if(!branches?.length)return response(200,{success:true,message:'No eligible branches',results:[]});
  const results=[];
  for(const branch of branches){
    const [{data:erp},{data:bio}]=await Promise.all([
      sb.from('erp_connections').select('tunnel_url,bridge_api_secret,is_active').eq('branch_id',branch.id).eq('is_active',true).limit(1).maybeSingle(),
      sb.from('biometric_connections').select('branch_location_code,last_sync_at,last_employee_sync_at,is_active').eq('branch_id',branch.id).eq('is_active',true).limit(1).maybeSingle()
    ]);
    const missing=[];if(!branch.is_active)missing.push('Branch is inactive');if(!erp?.tunnel_url)missing.push('Cloudflare tunnel URL is missing');if(!erp?.bridge_api_secret)missing.push('Bridge API secret is missing');if(!bio)missing.push('Active biometric connection is missing');if(!bio?.branch_location_code)missing.push('Branch location code is missing');
    if(missing.length){results.push({branchId:branch.id,branchName:branch.name_en,status:'failed',error:missing.join('; ')});continue;}
    if(triggerType==='scheduled'&&!branch.biometric_edge_sync_enabled){results.push({branchId:branch.id,branchName:branch.name_en,status:'skipped',reason:'Automatic synchronization is disabled'});continue;}
    results.push(await processBranch(sb,{branch_id:branch.id,branch_name:branch.name_en,...erp,...bio},{syncType,dryRun,triggerType,windowDays:body.windowDays,from:body.from,to:body.to},actor));
  }
  return response(results.some(x=>x.status==='failed')?207:200,{success:!results.some(x=>x.status==='failed'),dryRun,results});
});
