import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const json = (data: unknown, status = 200) => new Response(JSON.stringify(data), {
  status,
  headers: { ...corsHeaders, 'Content-Type': 'application/json' },
})

const safeError = (error: unknown) => error instanceof Error ? error.message.slice(0, 500) : String(error).slice(0, 500)

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return json({ success: false, error: 'Method not allowed' }, 405)

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL') || ''
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || ''
    const bearer = req.headers.get('Authorization')?.replace(/^Bearer\s+/i, '') || ''
    if (!bearer) return json({ success: false, error: 'Authentication required' }, 401)

    const admin = createClient(supabaseUrl, serviceKey)
    const { data: authData, error: authError } = await admin.auth.getUser(bearer)
    if (authError || !authData.user) return json({ success: false, error: 'Invalid session' }, 401)

    const actorId = authData.user.user_metadata?.aqura_user_id || authData.user.id
    const { data: actor } = await admin.from('users')
      .select('id,status,is_master_admin')
      .eq('id', actorId)
      .maybeSingle()
    if (!actor || actor.status !== 'active' || actor.is_master_admin !== true) {
      return json({ success: false, error: 'Master Admin access required' }, 403)
    }

    const body = await req.json().catch(() => ({}))
    if (body.action === 'run_today') {
      const response = await fetch(`${supabaseUrl}/functions/v1/attendance-no-show`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${serviceKey}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ trigger: 'manual', force_resend: true, requested_by: actor.id }),
      })
      const result = await response.json().catch(() => ({}))
      if (!response.ok || !result.success) {
        throw new Error(result.error || `Today's attendance check failed (${response.status})`)
      }
      return json({ success: true, action: 'run_today', result })
    }

    const recipientUserId = String(body.recipient_user_id || '')
    const channel = String(body.channel || '')
    if (!recipientUserId || !['whatsapp', 'email', 'in_app'].includes(channel)) {
      return json({ success: false, error: 'Invalid recipient or test channel' }, 400)
    }

    const [{ data: config }, { data: user }, { data: contact }] = await Promise.all([
      admin.from('attendance_notification_recipients')
        .select('id,is_enabled,delivery_mode')
        .eq('user_id', recipientUserId)
        .maybeSingle(),
      admin.from('users').select('id,username,status').eq('id', recipientUserId).maybeSingle(),
      admin.from('hr_employee_master')
        .select('name_en,name_ar,whatsapp_number,email')
        .eq('user_id', recipientUserId)
        .maybeSingle(),
    ])
    if (!config?.is_enabled || !user || user.status !== 'active') {
      return json({ success: false, error: 'Save and enable this recipient before testing' }, 400)
    }
    if (!contact?.whatsapp_number || !contact?.email) {
      return json({ success: false, error: 'Recipient WhatsApp number and email are required' }, 400)
    }

    const recipientName = contact.name_en || contact.name_ar || user.username
    const recipientNameAr = contact.name_ar || contact.name_en || user.username
    const now = new Date()

    if (channel === 'in_app') {
      const { data: notification, error } = await admin.from('notifications').insert({
        title: 'Attendance notification test',
        title_en: 'Attendance notification test',
        title_ar: 'اختبار إشعار الحضور',
        message: 'This is a test notification. No employee attendance event occurred.',
        message_en: 'This is a test notification. No employee attendance event occurred.',
        message_ar: 'هذا إشعار تجريبي. لم يتم تسجيل أي حالة حضور فعلية لموظف.',
        created_by: 'system',
        created_by_name: 'Attendance Monitor',
        created_by_role: 'System',
        target_type: 'specific_users',
        target_users: [recipientUserId],
        type: 'info',
        priority: 'normal',
        total_recipients: 1,
        metadata: { attendance_notification_test: true, tested_by: actor.id, tested_at: now.toISOString() },
      }).select('id').single()
      if (error) throw error
      return json({ success: true, channel, provider_id: notification.id })
    }

    if (channel === 'whatsapp') {
      const { data: account } = await admin.from('wa_accounts')
        .select('access_token,phone_number_id')
        .eq('is_active', true)
        .eq('is_default', true)
        .maybeSingle()
      if (!account?.access_token || !account?.phone_number_id) throw new Error('WhatsApp account is not configured')

      const phone = String(contact.whatsapp_number).replace(/[^0-9]/g, '')
      const response = await fetch(`https://graph.facebook.com/v22.0/${account.phone_number_id}/messages`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${account.access_token}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          messaging_product: 'whatsapp',
          to: phone,
          type: 'template',
          template: {
            name: 'attendance_not_reported_ar',
            language: { code: 'ar' },
            components: [{ type: 'body', parameters: [
              { type: 'text', text: 'موظف تجريبي' },
              { type: 'text', text: 'فرع تجريبي' },
              { type: 'text', text: 'موقع تجريبي' },
              { type: 'text', text: new Intl.DateTimeFormat('ar-SA-u-ca-gregory', { timeZone: 'Asia/Riyadh', dateStyle: 'medium' }).format(now) },
              { type: 'text', text: '08:00 ص' },
              { type: 'text', text: '05:00 م' },
              { type: 'text', text: new Intl.DateTimeFormat('ar-SA', { timeZone: 'Asia/Riyadh', hour: '2-digit', minute: '2-digit' }).format(now) },
              { type: 'text', text: '16' },
            ] }],
          },
        }),
      })
      const result = await response.json()
      if (!response.ok) throw new Error(result?.error?.message || `WhatsApp delivery failed (${response.status})`)
      const providerId = result.messages?.[0]?.id || null
      await admin.from('whatsapp_message_log').insert({
        phone_number: contact.whatsapp_number,
        message_type: 'attendance_no_show_test',
        template_name: 'attendance_not_reported_ar',
        template_language: 'ar',
        whatsapp_message_id: providerId,
        status: 'sent',
        customer_name: recipientName,
      })
      return json({ success: true, channel, provider_id: providerId })
    }

    const { data: account } = await admin.from('email_accounts')
      .select('*')
      .eq('is_active', true)
      .eq('send_enabled', true)
      .eq('default_for_transactional', true)
      .maybeSingle()
    if (!account) throw new Error('Transactional email account is not configured')

    const subject = 'Attendance notification test | اختبار إشعار الحضور'
    const textBody = `Attendance Notification Test\n\nHello ${recipientName},\nThis confirms that attendance email notifications are configured correctly.\nNo employee attendance event occurred.\nTest time: ${now.toISOString()}\n\nاختبار إشعار الحضور\n\nمرحباً ${recipientNameAr}،\nيؤكد هذا الاختبار أن إشعارات الحضور عبر البريد الإلكتروني تعمل بشكل صحيح.\nلم يتم تسجيل أي حالة حضور فعلية لموظف.\nوقت الاختبار: ${now.toISOString()}`
    const htmlBody = `<div dir="ltr"><h2>Attendance Notification Test</h2><p>Hello ${recipientName},</p><p>This confirms that attendance email notifications are configured correctly.</p><p><b>No employee attendance event occurred.</b></p><p>Test time: ${now.toISOString()}</p></div><hr><div dir="rtl"><h2>اختبار إشعار الحضور</h2><p>مرحباً ${recipientNameAr}،</p><p>يؤكد هذا الاختبار أن إشعارات الحضور عبر البريد الإلكتروني تعمل بشكل صحيح.</p><p><b>لم يتم تسجيل أي حالة حضور فعلية لموظف.</b></p><p>وقت الاختبار: ${now.toISOString()}</p></div>`
    const { data: message, error: messageError } = await admin.from('email_messages').insert({
      email_account_id: account.id,
      direction: 'outbound',
      status: 'queued',
      subject,
      from_name: account.from_name || account.account_name,
      from_address: account.email_address,
      html_body: htmlBody,
      text_body: textBody,
      body_preview: textBody.slice(0, 500),
      source_type: 'attendance_no_show_test',
      source_reference: actor.id,
      priority: 'normal',
    }).select('id').single()
    if (messageError) throw messageError
    await admin.from('email_message_recipients').insert({
      email_message_id: message.id,
      recipient_type: 'to',
      display_name: recipientName,
      email_address: contact.email,
    })
    const { data: queued, error: queueError } = await admin.from('email_queue').insert({
      queue_type: 'transactional',
      priority: 5,
      email_account_id: account.id,
      email_message_id: message.id,
      status: 'waiting',
      maximum_attempts: 3,
      idempotency_key: `attendance-test-${crypto.randomUUID()}`,
    }).select('id').single()
    if (queueError) throw queueError

    const response = await fetch(`${supabaseUrl}/functions/v1/email-send`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${serviceKey}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ queue_id: queued.id }),
    })
    const result = await response.json()
    if (!response.ok || !result.success) throw new Error(result.error || `Email delivery failed (${response.status})`)
    return json({ success: true, channel, provider_id: queued.id })
  } catch (error) {
    console.error('[attendance-notification-test]', error)
    return json({ success: false, error: safeError(error) }, 500)
  }
})
