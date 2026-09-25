BEGIN;

WITH titles(task_number, title_ar) AS (
  VALUES
    (1, convert_from(decode('d988d8b6d8b920d8a7d984d985d986d8aad8acd8a7d8aa20d8b9d984d98920d8a7d984d8b1d981', 'hex'), 'UTF8')),
    (2, convert_from(decode('d985d8aad8a7d8a8d8b9d8a920d988d8b6d8b920d8a7d984d985d986d8aad8acd8a7d8aa', 'hex'), 'UTF8')),
    (3, convert_from(decode('d8aad8a3d983d98ad8af20d988d8b6d8b920d8a7d984d985d986d8aad8acd8a7d8aa20d981d98a20d8a7d984d985d8b3d8aad988d8afd8b9', 'hex'), 'UTF8')),
    (4, convert_from(decode('d981d8add8b520d8a7d984d981d8a7d8aad988d8b1d8a920d8a7d984d8a3d8b5d984d98ad8a920d8a8d8a7d984d8b0d983d8a7d8a120d8a7d984d8a7d8b5d8b7d986d8a7d8b9d98a', 'hex'), 'UTF8')),
    (5, convert_from(decode('d8b1d981d8b920d985d984d98120505220457863656c', 'hex'), 'UTF8')),
    (6, convert_from(decode('d8a7d984d8aad8add982d98220d985d98620d8a7d984d8a3d8b3d8b9d8a7d8b120d988d8a7d984d8aad983d984d981d8a9', 'hex'), 'UTF8')),
    (7, convert_from(decode('d8a5d8afd8aed8a7d98420d985d8b1d8acd8b920d981d8a7d8aad988d8b1d8a920d8a7d984d985d8b4d8aad8b1d98ad8a7d8aa20d981d98a20455250', 'hex'), 'UTF8')),
    (8, convert_from(decode('d981d8add8b520d981d8a7d8aad988d8b1d8a920d8a7d984d985d8b4d8aad8b1d98ad8a7d8aa20d981d98a20455250', 'hex'), 'UTF8')),
    (9, convert_from(decode('d8a7d984d8add8b5d988d98420d8b9d984d98920d985d988d8a7d981d982d8a920d8a7d984d8afd981d8b9d8a920d8a7d984d985d982d8afd985d8a9', 'hex'), 'UTF8')),
    (10, convert_from(decode('d8a7d984d8aad8add982d98220d8a7d984d986d987d8a7d8a6d98a20d985d98620d8a7d984d8a7d8b3d8aad984d8a7d985', 'hex'), 'UTF8'))
)
UPDATE public."Autotask_rules" r
SET title_ar = titles.title_ar,
    updated_at = now()
FROM titles
WHERE r.task_number = titles.task_number;

WITH titles(task_number, title_ar) AS (
  VALUES
    (1, convert_from(decode('d988d8b6d8b920d8a7d984d985d986d8aad8acd8a7d8aa20d8b9d984d98920d8a7d984d8b1d981', 'hex'), 'UTF8')),
    (2, convert_from(decode('d985d8aad8a7d8a8d8b9d8a920d988d8b6d8b920d8a7d984d985d986d8aad8acd8a7d8aa', 'hex'), 'UTF8')),
    (3, convert_from(decode('d8aad8a3d983d98ad8af20d988d8b6d8b920d8a7d984d985d986d8aad8acd8a7d8aa20d981d98a20d8a7d984d985d8b3d8aad988d8afd8b9', 'hex'), 'UTF8')),
    (4, convert_from(decode('d981d8add8b520d8a7d984d981d8a7d8aad988d8b1d8a920d8a7d984d8a3d8b5d984d98ad8a920d8a8d8a7d984d8b0d983d8a7d8a120d8a7d984d8a7d8b5d8b7d986d8a7d8b9d98a', 'hex'), 'UTF8')),
    (5, convert_from(decode('d8b1d981d8b920d985d984d98120505220457863656c', 'hex'), 'UTF8')),
    (6, convert_from(decode('d8a7d984d8aad8add982d98220d985d98620d8a7d984d8a3d8b3d8b9d8a7d8b120d988d8a7d984d8aad983d984d981d8a9', 'hex'), 'UTF8')),
    (7, convert_from(decode('d8a5d8afd8aed8a7d98420d985d8b1d8acd8b920d981d8a7d8aad988d8b1d8a920d8a7d984d985d8b4d8aad8b1d98ad8a7d8aa20d981d98a20455250', 'hex'), 'UTF8')),
    (8, convert_from(decode('d981d8add8b520d981d8a7d8aad988d8b1d8a920d8a7d984d985d8b4d8aad8b1d98ad8a7d8aa20d981d98a20455250', 'hex'), 'UTF8')),
    (9, convert_from(decode('d8a7d984d8add8b5d988d98420d8b9d984d98920d985d988d8a7d981d982d8a920d8a7d984d8afd981d8b9d8a920d8a7d984d985d982d8afd985d8a9', 'hex'), 'UTF8')),
    (10, convert_from(decode('d8a7d984d8aad8add982d98220d8a7d984d986d987d8a7d8a6d98a20d985d98620d8a7d984d8a7d8b3d8aad984d8a7d985', 'hex'), 'UTF8'))
)
UPDATE public."Autotask_tasks" t
SET title_ar = titles.title_ar,
    updated_at = now()
FROM titles
WHERE t.task_number = titles.task_number;

COMMIT;
