-- Fix broadcast messages with question marks by copying content from a good message
UPDATE wa_messages bad
SET content = good.content
FROM (
  SELECT content 
  FROM wa_messages 
  WHERE template_name = 'salaryoffertwo' 
    AND wa_account_id = '8a829a12-650c-4dfb-a9ee-a769aa67c172'
    AND content NOT LIKE '%????%'
    AND length(content) > 50
  LIMIT 1
) good
WHERE bad.template_name = 'salaryoffertwo'
  AND bad.wa_account_id = '8a829a12-650c-4dfb-a9ee-a769aa67c172'
  AND bad.content LIKE '%????%';
