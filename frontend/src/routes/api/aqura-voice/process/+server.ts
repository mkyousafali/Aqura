import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { aquraVoiceAuthError, requireAquraVoiceUser } from '$lib/server/aquraVoiceAuth';

export const POST: RequestHandler = async ({ request }) => {
	try {
		const { db, user } = await requireAquraVoiceUser(request);
		const body = await request.json();
		if (!body?.audioBase64 || !body?.transcriptionPrompt || !body?.translationPrompt) return json({success:false,error:'Invalid audio request'},{status:400});
		const { data:key } = await db.from('system_api_keys').select('api_key').eq('service_name','google_gemini').eq('is_active',true).maybeSingle();
		if (!key?.api_key) return json({success:false,error:'Gemini API key is not configured'},{status:503});
		const call = async (parts:any[]) => {
			const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${key.api_key}`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({contents:[{role:'user',parts}],generationConfig:{temperature:0,topP:.95,topK:40,thinkingConfig:{thinkingBudget:0}}}),signal:AbortSignal.timeout(120000)});
			const result = await response.json();
			if(!response.ok) throw new Error(result?.error?.message||'Gemini request failed');
			return result.candidates?.[0]?.content?.parts?.[0]?.text?.trim();
		};
		const transcript = await call([{inline_data:{mime_type:body.mimeType||'audio/ogg',data:body.audioBase64}},{text:String(body.transcriptionPrompt).slice(0,12000)}]);
		if(!transcript) throw new Error('No speech detected');
		const translationPrompt=String(body.translationPrompt).replace('{{TRANSCRIPT}}',transcript).slice(0,16000);
		const translation = await call([{text:translationPrompt}]);
		if(!translation) throw new Error('Translation failed');
		let usage:any={success:true,unlimited:true};
		if(!user.is_master_admin){ const consumed=await db.rpc('consume_aqura_voice_usage',{p_user_id:user.id}); usage=consumed.data; if(!usage?.success) return json(usage,{status:429}); }
		return json({success:true,transcript,translation,usage});
	} catch(error:any){ const auth=aquraVoiceAuthError(error); return auth||json({success:false,error:error?.message||'Processing failed'},{status:500}); }
};
