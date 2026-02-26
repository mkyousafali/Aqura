-- Fix Arabic content in broadcast messages by copying from template
UPDATE wa_messages m
SET content = t.body_text
FROM wa_templates t
WHERE m.template_name = t.name
  AND m.sent_by = 'broadcast'
  AND m.template_name = 'salaryoffertwo';
