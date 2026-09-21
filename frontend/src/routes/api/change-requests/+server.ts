import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { databaseClient } from '$lib/server/breakRegisterAuth';
import { changeDenominations as denominations, readSafeBoxAvailability } from '$lib/server/safeBoxAvailability';
import { cashierInBranch } from '$lib/server/cashierChangeBranch';
import { isSafeBoxReceiver } from '$lib/server/safeBoxControl';

export const GET: RequestHandler = async ({ url, request }) => {
  const userId = request.headers.get('x-cashier-user-id');
  const sessionToken = request.headers.get('x-cashier-session-token');
  const branchId = Number(url.searchParams.get('branchId'));
  if (!userId || !sessionToken || !Number.isSafeInteger(branchId) || branchId <= 0) {
    return json({ error: 'Invalid cashier session or branch' }, { status: 400 });
  }
  try {
    const { data: session, error } = await databaseClient().rpc('heartbeat_cashier_session', {
      p_user_id: userId, p_session_token: sessionToken
    });
    if (error || session?.valid !== true) return json({ error: 'Cashier session expired' }, { status: 401 });
    if (!await cashierInBranch(databaseClient(), userId, branchId)) return json({ error: 'Cashier branch mismatch.' }, { status: 403 });
    const available = await readSafeBoxAvailability(branchId);
    return json({ available }, { headers: { 'Cache-Control': 'no-store' } });
  } catch (error) {
    console.error('Safe Box availability failed:', error);
    return json({ error: 'Could not load Safe Box availability' }, { status: 500 });
  }
};

export const POST: RequestHandler = async ({ request }) => {
  try {
    const body = await request.json();
    const { userId, sessionToken, branchId, requestedToUserId, denominationCounts, amount } = body;
    if (typeof userId !== 'string' || typeof sessionToken !== 'string' ||
        !Number.isSafeInteger(Number(branchId)) || Number(branchId) <= 0 ||
        typeof requestedToUserId !== 'string' || !denominationCounts ||
        typeof denominationCounts !== 'object' || Array.isArray(denominationCounts)) {
      return json({ error: 'Invalid change request' }, { status: 400 });
    }
    const keys = Object.keys(denominationCounts);
    if (keys.some(key => !(key in denominations) || !Number.isSafeInteger(denominationCounts[key]) || denominationCounts[key] < 0 || denominationCounts[key] > 100000)) {
      return json({ error: 'Invalid denomination quantities' }, { status: 400 });
    }
    const preferredCents = keys.reduce((total, key) => total + denominations[key] * denominationCounts[key], 0);
    const cents = Math.round(Number(amount) * 100);
    if (typeof amount !== 'number' || !Number.isFinite(amount) || !Number.isSafeInteger(cents) || cents <= 0 || Math.abs(amount * 100 - cents) > 0.000001) {
      return json({ error: 'Enter a valid amount greater than zero, with at most two decimal places' }, { status: 400 });
    }
    if (preferredCents > cents) return json({ error: 'Preferred denominations exceed the requested amount' }, { status: 400 });
    const db = databaseClient();
    const { data: session, error: sessionError } = await db.rpc('heartbeat_cashier_session', {
      p_user_id: userId, p_session_token: sessionToken
    });
    if (sessionError || session?.valid !== true) return json({ error: 'Cashier session expired' }, { status: 401 });
    if (!await cashierInBranch(db, userId, Number(branchId))) return json({ error: 'Cashier branch mismatch.' }, { status: 403 });
    const [{ data: sender }, { data: recipient }, { data: branch }, { data: permission }, { data: recipientEmployee }] = await Promise.all([
      db.from('users').select('id,status').eq('id', userId).maybeSingle(),
      db.from('users').select('id,status').eq('id', requestedToUserId).maybeSingle(),
      db.from('branches').select('id').eq('id', branchId).maybeSingle(),
      db.from('interface_permissions').select('desktop_enabled').eq('user_id', requestedToUserId).maybeSingle(),
      db.from('hr_employee_master').select('user_id').eq('user_id', requestedToUserId).eq('current_branch_id', branchId).maybeSingle()
    ]);
    if (sender?.status !== 'active' || recipient?.status !== 'active' || !branch || !recipientEmployee || permission?.desktop_enabled === false ||
        !await isSafeBoxReceiver(db, requestedToUserId, Number(branchId))) {
      return json({ error: 'Cashier, receiving user, or selected branch is unavailable' }, { status: 400 });
    }
    const available = await readSafeBoxAvailability(Number(branchId));
    const availableCents = Object.entries(denominations).reduce((total, [key, value]) => total + value * (available[key] || 0), 0);
    if (cents > availableCents) {
      return json({ error: `Requested amount exceeds the current Safe Box balance (${(availableCents / 100).toFixed(2)} SAR).`, available }, { status: 409 });
    }
    const insufficient = keys.find(key => denominationCounts[key] > available[key]);
    if (insufficient) {
      return json({ error: `${denominations[insufficient] / 100} SAR is insufficient in Safe Box. Available: ${available[insufficient]}.`, available, denomination: insufficient }, { status: 409 });
    }
    const { data, error } = await db.from('aqura_change_requests').insert({
      requested_by_user_id: sender.id,
      branch_id: branch.id,
      requested_to_user_id: recipient.id,
      denomination_counts: denominationCounts,
      total_amount: cents / 100,
      status: 'Pending'
    }).select('id,request_number').single();
    if (error) throw error;
    return json({ id: data.id, requestNumber: data.request_number, status: 'Pending' }, { status: 201 });
  } catch (error) {
    console.error('Change request creation failed:', error);
    return json({ error: 'Could not save change request' }, { status: 500 });
  }
};
