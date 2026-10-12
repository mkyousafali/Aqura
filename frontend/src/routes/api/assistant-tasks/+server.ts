import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { createClient } from '@supabase/supabase-js';
import { env } from '$env/dynamic/private';
import { databaseClient, requireBreakUser } from '$lib/server/breakRegisterAuth';

function db() {
	return createClient(env.VITE_SUPABASE_URL || '', env.SUPABASE_SERVICE_ROLE_KEY || env.VITE_SUPABASE_SERVICE_KEY || '');
}

export const GET: RequestHandler = async ({ cookies }) => {
	try {
		const user = await requireBreakUser(cookies, 'desktop');
		const { data, error } = await db().from('assistant_workflow_tasks').select('*').eq('assigned_to', user.id).in('status', ['pending', 'in_progress', 'failed']).order('created_at', { ascending: false });
		if (error) throw error;
		return json({ success: true, tasks: data || [] });
	} catch (error: any) {
		return json({ success: false, error: error.message || 'Desktop session required' }, { status: 401 });
	}
};

export const POST: RequestHandler = async ({ request, cookies }) => {
	try {
		const actor = await requireBreakUser(cookies, 'desktop');
		const body = await request.json();
		const branchId = Number(body.branch_id);
		if (!Number.isFinite(branchId) || !body.assigned_to || body.task_type !== 'cash_closing_mjv' || !Array.isArray(body.payload?.lines) || !body.payload.lines.length) {
			return json({ success: false, error: 'Invalid cash-closing MJV task' }, { status: 400 });
		}
		const secureDb = databaseClient();
		const { data: assignee, error: assigneeError } = await secureDb.from('hr_employee_master').select('user_id').eq('is_removed', false).eq('user_id', body.assigned_to).eq('current_branch_id', branchId).maybeSingle();
		if (assigneeError || !assignee) return json({ success: false, error: 'The selected user is not active in this branch' }, { status: 403 });
		const { data, error } = await secureDb.from('assistant_workflow_tasks').insert({
			task_type: body.task_type,
			title: 'Cash Closing MJV',
			branch_id: branchId,
			assigned_to: body.assigned_to,
			created_by: actor.id,
			payload: body.payload,
			status: 'pending'
		}).select().single();
		if (error) throw error;
		return json({ success: true, task: data });
	} catch (error: any) {
		return json({ success: false, error: error.message || 'Task creation failed' }, { status: 400 });
	}
};

export const PATCH: RequestHandler = async ({ request, cookies }) => {
	try {
		const user = await requireBreakUser(cookies, 'desktop');
		const body = await request.json();
		if (!body.id || !['in_progress', 'completed', 'failed'].includes(body.status)) return json({ success: false, error: 'Invalid task update' }, { status: 400 });
		const updates: any = { status: body.status, result: body.result || null };
		if (body.status === 'in_progress') updates.started_at = new Date().toISOString();
		if (body.status === 'completed') updates.completed_at = new Date().toISOString();
		const { data, error } = await db().from('assistant_workflow_tasks').update(updates).eq('id', body.id).eq('assigned_to', user.id).select().single();
		if (error) throw error;
		return json({ success: true, task: data });
	} catch (error: any) {
		return json({ success: false, error: error.message || 'Task update failed' }, { status: 400 });
	}
};
