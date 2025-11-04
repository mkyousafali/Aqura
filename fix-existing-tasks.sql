-- Fix existing completed tasks that still show as pending
UPDATE receiving_tasks 
SET assignment_status = 'completed' 
WHERE task_completed = true AND assignment_status != 'completed';