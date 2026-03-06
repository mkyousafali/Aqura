-- Find all AI or bot related tables
SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_name LIKE '%ai%' OR table_name LIKE '%bot%';
