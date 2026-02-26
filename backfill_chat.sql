-- Step 1: Create conversations for phones that don't have one
INSERT INTO wa_conversations (wa_account_id, customer_phone, customer_name, status, handled_by, is_bot_handling, bot_type, last_message_at, unread_count)
SELECT DISTINCT
    '8a829a12-650c-4dfb-a9ee-a769aa67c172'::uuid,
    '+' || regexp_replace(r.phone_number, '[^0-9]', '', 'g'),
    'Unknown',
    'active',
    'bot',
    true,
    'ai',
    NOW(),
    0
FROM wa_broadcast_recipients r
WHERE r.broadcast_id = '8edf843f-1cc2-4308-a835-0760b10a48dd'
  AND r.status IN ('sent','delivered','read')
  AND NOT EXISTS (
    SELECT 1 FROM wa_conversations c
    WHERE c.wa_account_id = '8a829a12-650c-4dfb-a9ee-a769aa67c172'
      AND c.customer_phone = '+' || regexp_replace(r.phone_number, '[^0-9]', '', 'g')
      AND c.status = 'active'
  );

-- Step 2: Insert wa_messages for all sent broadcast messages
INSERT INTO wa_messages (conversation_id, wa_account_id, direction, message_type, content, template_name, whatsapp_message_id, status, sent_by, created_at)
SELECT
    c.id,
    '8a829a12-650c-4dfb-a9ee-a769aa67c172'::uuid,
    'outbound',
    'template',
    'Broadcast: salaryoffertwo',
    'salaryoffertwo',
    r.whatsapp_message_id,
    'sent',
    'broadcast',
    COALESCE(r.sent_at, NOW())
FROM wa_broadcast_recipients r
JOIN wa_conversations c
    ON c.wa_account_id = '8a829a12-650c-4dfb-a9ee-a769aa67c172'
    AND c.customer_phone = '+' || regexp_replace(r.phone_number, '[^0-9]', '', 'g')
    AND c.status = 'active'
WHERE r.broadcast_id = '8edf843f-1cc2-4308-a835-0760b10a48dd'
  AND r.status IN ('sent','delivered','read')
  AND r.whatsapp_message_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM wa_messages m
    WHERE m.whatsapp_message_id = r.whatsapp_message_id
  );
