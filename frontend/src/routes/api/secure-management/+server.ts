import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { databaseClient, requireBreakUser } from '$lib/server/breakRegisterAuth';
import { createHash, randomInt, timingSafeEqual } from 'node:crypto';

const otpHash = (value: string) => createHash('sha256').update(value).digest('hex');
const newOtp = () => randomInt(0, 1_000_000).toString().padStart(6, '0');
const normalizePhone = (value: unknown) => {
  let phone = String(value || '').replace(/[^0-9]/g, '');
  if (phone.length === 9) phone = `966${phone}`;
  return phone;
};
const safeEqual = (left: string, right: string) => {
  const a = Buffer.from(left);
  const b = Buffer.from(right);
  return a.length === b.length && timingSafeEqual(a, b);
};
const escapeHtml = (value: unknown) => String(value || '')
  .replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;')
  .replaceAll('"', '&quot;').replaceAll("'", '&#039;');

async function queueEmail(db: ReturnType<typeof databaseClient>, recipient: string, displayName: string, subject: string, textBody: string, htmlBody: string, sourceType = 'otp', redactAfterSend = false) {
  let accountQuery = await db.from('email_accounts').select('id,email_address,from_name')
    .eq('is_active', true).eq('send_enabled', true).eq('default_for_otp', true).limit(1).maybeSingle();
  if (!accountQuery.data) {
    accountQuery = await db.from('email_accounts').select('id,email_address,from_name')
      .eq('is_active', true).eq('send_enabled', true).limit(1).maybeSingle();
  }
  if (accountQuery.error) throw accountQuery.error;
  const account = accountQuery.data;
  if (!account) throw new Error('No email account is configured for sending');
  const messageResult = await db.from('email_messages').insert({
    email_account_id: account.id, direction: 'outgoing', status: 'queued', subject,
    text_body: textBody, html_body: htmlBody, priority: 'critical',
    from_address: account.email_address, from_name: account.from_name || 'Aqura', source_type: sourceType
  }).select('id').single();
  if (messageResult.error) throw messageResult.error;
  const recipientResult = await db.from('email_message_recipients').insert({
    email_message_id: messageResult.data.id, recipient_type: 'to', email_address: recipient, display_name: displayName
  });
  if (recipientResult.error) throw recipientResult.error;
  const queueResult = await db.from('email_queue').insert({
    queue_type: 'normal', priority: 1, email_account_id: account.id,
    email_message_id: messageResult.data.id, status: 'pending', available_at: new Date().toISOString(), maximum_attempts: 3
  }).select('id').single();
  if (queueResult.error) throw queueResult.error;
  const delivery = await db.functions.invoke('email-send', { body: { queue_id: queueResult.data.id } });
  if (delivery.error || delivery.data?.success === false) throw new Error(delivery.error?.message || delivery.data?.error || 'Email delivery failed');
  if (redactAfterSend) {
    const redaction = await db.from('email_messages').update({ text_body: '[redacted after delivery]', html_body: '<p>[redacted after delivery]</p>', body_preview: '[redacted after delivery]' }).eq('id', messageResult.data.id);
    if (redaction.error) throw redaction.error;
  }
  return queueResult.data.id;
}

export const POST: RequestHandler = async ({ cookies, request }) => {
  try {
    const actor = await requireBreakUser(cookies, 'desktop');
    if (!actor.isAdmin && !actor.isMasterAdmin) return json({ error: 'Manager access denied' }, { status: 403 });
    const body = await request.json();
    const db = databaseClient();
    let result: { data: any; error: any };
    switch (body.action) {
      case 'startUserCreationVerification': {
        if (!actor.isMasterAdmin) {
          const permission = await db.from('button_permissions').select('is_enabled')
            .eq('user_id', actor.id).eq('button_code', 'CREATE_USER').eq('is_enabled', true).maybeSingle();
          if (permission.error || !permission.data) return json({ error: 'Create User permission required' }, { status: 403 });
        }
        const email = typeof body.email === 'string' ? body.email.trim().toLowerCase() : '';
        const phone = normalizePhone(body.whatsappNumber);
        const employeeId = typeof body.employeeId === 'string' ? body.employeeId : '';
        if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return json({ error: 'Invalid email address' }, { status: 400 });
        if (!/^9665\d{8}$/.test(phone)) return json({ error: 'Enter a valid Saudi WhatsApp number' }, { status: 400 });
        const employee = await db.from('hr_employees').select('id,name').eq('id', employeeId).maybeSingle();
        if (employee.error || !employee.data) return json({ error: 'Employee not found' }, { status: 404 });
        const recent = await db.from('user_creation_verifications').select('created_at')
          .eq('requested_by', actor.id).gte('created_at', new Date(Date.now() - 60_000).toISOString());
        if (recent.error) throw recent.error;
        if ((recent.data || []).length >= 3) return json({ error: 'Please wait before requesting more verification codes' }, { status: 429 });
        const emailOtp = newOtp();
        const whatsappOtp = newOtp();
        const verification = await db.from('user_creation_verifications').insert({
          requested_by: actor.id, employee_id: employeeId, email, whatsapp_number: phone,
          email_otp_hash: otpHash(emailOtp), whatsapp_otp_hash: otpHash(whatsappOtp),
          expires_at: new Date(Date.now() + 5 * 60_000).toISOString()
        }).select('id,expires_at').single();
        if (verification.error) throw verification.error;
        try {
          const safeName = escapeHtml(employee.data.name);
          const emailPromise = queueEmail(db, email, employee.data.name || '', 'Aqura - User Verification Code',
            `Your Aqura user creation verification code is: ${emailOtp}\nThis code expires in 5 minutes.`,
            `<div style="font-family:Arial,sans-serif;max-width:480px;margin:auto;padding:30px"><h2>Aqura</h2><p>User creation verification code for ${safeName}:</p><div style="font-size:36px;font-weight:700;letter-spacing:8px;color:#2563eb">${emailOtp}</div><p>This code expires in 5 minutes. Do not share it.</p></div>`);
          const whatsappPromise = db.functions.invoke('send-whatsapp', { body: {
            action: 'send_user_creation_otp', phone_number: `+${phone}`,
            access_code: whatsappOtp, customer_name: employee.data.name, language: 'en'
          }});
          const [emailDelivery, whatsappDelivery] = await Promise.allSettled([emailPromise, whatsappPromise]);
          const whatsappFailed = whatsappDelivery.status === 'rejected' || whatsappDelivery.value.error || whatsappDelivery.value.data?.success === false;
          if (emailDelivery.status === 'rejected' || whatsappFailed) {
            await db.from('user_creation_verifications').delete().eq('id', verification.data.id);
            const emailError = emailDelivery.status === 'rejected' ? emailDelivery.reason?.message : '';
            const whatsappError = whatsappDelivery.status === 'rejected' ? whatsappDelivery.reason?.message : whatsappDelivery.value.error?.message || whatsappDelivery.value.data?.error;
            throw new Error([emailError, whatsappError].filter(Boolean).join('; ') || 'Could not send verification codes');
          }
          return json({ success: true, verificationId: verification.data.id, expiresAt: verification.data.expires_at });
        } catch (error) {
          return json({ error: error instanceof Error ? error.message : 'Could not send verification codes' }, { status: 502 });
        }
      }
      case 'verifyUserCreationOtp': {
        const verificationId = typeof body.verificationId === 'string' ? body.verificationId : '';
        const channel = body.channel === 'email' || body.channel === 'whatsapp' ? body.channel : null;
        const otp = typeof body.otp === 'string' ? body.otp.trim() : '';
        if (!verificationId || !channel || !/^\d{6}$/.test(otp)) return json({ error: 'Invalid verification request' }, { status: 400 });
        const verification = await db.from('user_creation_verifications').select('*')
          .eq('id', verificationId).eq('requested_by', actor.id).maybeSingle();
        if (verification.error || !verification.data) return json({ error: 'Verification session not found' }, { status: 404 });
        if (verification.data.consumed_at || new Date(verification.data.expires_at).getTime() <= Date.now()) return json({ error: 'Verification session expired' }, { status: 410 });
        const attemptsKey = `${channel}_attempts`;
        const verifiedKey = `${channel}_verified_at`;
        if (verification.data[verifiedKey]) return json({ success: true, channel, alreadyVerified: true });
        if (Number(verification.data[attemptsKey]) >= 5) return json({ error: 'Too many incorrect attempts' }, { status: 429 });
        const valid = safeEqual(otpHash(otp), verification.data[`${channel}_otp_hash`]);
        if (!valid) {
          const attempts = Number(verification.data[attemptsKey]) + 1;
          await db.from('user_creation_verifications').update({ [attemptsKey]: attempts }).eq('id', verificationId);
          return json({ error: 'Incorrect verification code', attemptsRemaining: Math.max(0, 5 - attempts) }, { status: 400 });
        }
        const update = await db.from('user_creation_verifications').update({ [verifiedKey]: new Date().toISOString() }).eq('id', verificationId);
        if (update.error) throw update.error;
        return json({ success: true, channel });
      }
      case 'createVerifiedUser': {
        const u = body.user || {};
        if (typeof u.verificationId !== 'string' || typeof u.password !== 'string' || typeof u.username !== 'string')
          return json({ error: 'Invalid user creation request' }, { status: 400 });
        let avatarUrl: string | null = null;
        if (typeof u.avatarDataUrl === 'string' && u.avatarDataUrl) {
          const match = u.avatarDataUrl.match(/^data:(image\/(?:png|jpeg|webp));base64,(.+)$/);
          if (!match) return json({ error: 'Invalid avatar image' }, { status: 400 });
          const bytes = Buffer.from(match[2], 'base64');
          if (bytes.length > 5 * 1024 * 1024) return json({ error: 'Avatar must be smaller than 5 MB' }, { status: 400 });
          const extension = match[1] === 'image/jpeg' ? 'jpg' : match[1].split('/')[1];
          const path = `${actor.id}/${u.verificationId}.${extension}`;
          const upload = await db.storage.from('user-avatars').upload(path, bytes, { contentType: match[1], upsert: true });
          if (upload.error) throw upload.error;
          avatarUrl = db.storage.from('user-avatars').getPublicUrl(path).data.publicUrl;
        }
        result = await db.rpc('create_verified_user', {
          p_verification_id: u.verificationId, p_username: u.username, p_password: u.password,
          p_is_master_admin: actor.isMasterAdmin && u.isMasterAdmin === true,
          p_is_admin: u.isAdmin === true, p_user_type: u.userType,
          p_branch_id: u.branchId || null, p_position_id: u.positionId || null,
          p_quick_access_code: u.quickAccessCode || null, p_avatar: avatarUrl,
          p_requesting_user_id: actor.id
        });
        if (result.error) throw result.error;
        if (!result.data?.success) return json({ error: result.data?.message || 'User creation failed' }, { status: 400 });
        let deliveryWarning = '';
        try {
          const username = escapeHtml(u.username);
          const password = escapeHtml(u.password);
          const accessCode = escapeHtml(result.data.quick_access_code);
          await queueEmail(db, result.data.email, '', 'Welcome to Aqura - Your Login Credentials',
            `Your Aqura account has been created.\nUsername: ${u.username}\nPassword: ${u.password}\nAccess Code: ${result.data.quick_access_code}\nYou must change your password after your first login.`,
            `<div style="font-family:Arial,sans-serif;max-width:520px;margin:auto;padding:30px"><h2>Welcome to Aqura</h2><p>Your account has been created.</p><p><b>Username:</b> ${username}<br><b>Temporary password:</b> ${password}<br><b>Access code:</b> ${accessCode}</p><p>Change your password after your first login and do not share these credentials.</p></div>`,
            'transactional', true);
        } catch (error) {
          deliveryWarning = error instanceof Error ? error.message : 'Credential email could not be delivered';
        }
        return json({ data: result.data, success: true, deliveryWarning });
      }
      case 'createUser': {
        const u = body.user || {};
        result = await db.rpc('create_user', {
          p_username: u.username, p_password: u.password,
          p_is_master_admin: actor.isMasterAdmin && u.isMasterAdmin === true,
          p_is_admin: u.isAdmin === true, p_user_type: u.userType,
          p_branch_id: u.branchId || null, p_employee_id: u.employeeId || null,
          p_position_id: u.positionId || null, p_quick_access_code: u.quickAccessCode || null,
          p_requesting_user_id: actor.id
        });
        break;
      }
      case 'updateUser': {
        const u = body.updates || {};
        if (!actor.isMasterAdmin && u.p_is_master_admin === true) return json({ error: 'Master admin required' }, { status: 403 });
        result = await db.rpc('update_user', {
          p_user_id: body.userId, p_username: u.username ?? null,
          p_is_master_admin: actor.isMasterAdmin ? u.p_is_master_admin ?? null : null,
          p_is_admin: u.p_is_admin ?? null, p_user_type: u.user_type ?? null,
          p_branch_id: u.branch_id ?? null, p_employee_id: u.employee_id || null,
          p_position_id: u.position_id || null, p_status: u.status ?? null,
          p_avatar: u.avatar ?? null, p_requesting_user_id: actor.id
        });
        break;
      }
      case 'deactivateUser':
        result = await db.from('users').update({ status: 'inactive' }).eq('id', body.userId);
        break;
      case 'resetPassword': {
        if (typeof body.password !== 'string' || body.password.length < 6) return json({ error: 'Invalid password' }, { status: 400 });
        const salt = await db.rpc('generate_salt');
        if (salt.error) throw salt.error;
        const hash = await db.rpc('hash_password', { password: body.password, salt: salt.data });
        if (hash.error) throw hash.error;
        result = await db.from('users').update({ password_hash: hash.data, salt: salt.data,
          is_first_login: true, failed_login_attempts: 0,
          last_password_change: new Date().toISOString() }).eq('id', body.userId);
        break;
      }
      case 'generateCode': {
        const code = await db.rpc('generate_unique_quick_access_code');
        if (code.error) throw code.error;
        const salt = await db.rpc('generate_salt');
        if (salt.error) throw salt.error;
        const hash = await db.rpc('hash_password', { password: code.data, salt: salt.data });
        if (hash.error) throw hash.error;
        result = await db.from('users').update({ quick_access_code: hash.data, quick_access_salt: salt.data }).eq('id', body.userId);
        if (result.error) throw result.error;
        return json({ code: code.data });
      }
      case 'changeBranch': {
        if (body.branchId !== null && !Number.isInteger(body.branchId)) return json({ error: 'Invalid branch' }, { status: 400 });
        result = await db.from('users').update({ branch_id: body.branchId }).eq('id', body.userId);
        if (result.error) throw result.error;
        result = await db.from('hr_employee_master').update({ current_branch_id: body.branchId }).eq('user_id', body.userId);
        break;
      }
      case 'updateEmployee': {
        const u = body.employee || {};
        result = await db.rpc('update_employee_master_basic', {
          p_id: u.p_id, p_name_en: u.p_name_en ?? null, p_name_ar: u.p_name_ar ?? null,
          p_current_branch_id: u.p_current_branch_id ?? null,
          p_current_position_id: u.p_current_position_id ?? null,
          p_whatsapp_number: u.p_whatsapp_number ?? null, p_email: u.p_email ?? null
        });
        break;
      }
      case 'interfacePermission': {
        const p = body.permission || {};
        if (typeof p.user_id !== 'string') return json({ error: 'Invalid user' }, { status: 400 });
        const existing = await db.from('interface_permissions')
          .select('desktop_enabled,mobile_enabled,customer_enabled,cashier_enabled').eq('user_id', p.user_id).maybeSingle();
        if (existing.error) throw existing.error;
        result = await db.from('interface_permissions').upsert({
          user_id: p.user_id, desktop_enabled: p.desktop_enabled ?? existing.data?.desktop_enabled ?? true,
          mobile_enabled: p.mobile_enabled ?? existing.data?.mobile_enabled ?? true,
          customer_enabled: p.customer_enabled ?? existing.data?.customer_enabled ?? false,
          cashier_enabled: p.cashier_enabled ?? existing.data?.cashier_enabled ?? false, updated_by: actor.id,
          updated_at: new Date().toISOString()
        }, { onConflict: 'user_id' });
        break;
      }
      default: return json({ error: 'Unknown action' }, { status: 400 });
    }
    if (result.error) throw result.error;
    return json({ data: result.data, success: true });
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : 'Management update failed' }, { status: 403 });
  }
};
