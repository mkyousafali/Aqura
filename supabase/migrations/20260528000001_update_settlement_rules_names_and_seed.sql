-- Add bilingual rule names to settlement rules and seed example records

ALTER TABLE public.settlement_rules
    RENAME COLUMN rule_name TO rule_name_en;

ALTER TABLE public.settlement_rules
    ADD COLUMN IF NOT EXISTS rule_name_ar text NOT NULL DEFAULT ''::text;

ALTER TABLE public.settlement_rules
    DROP CONSTRAINT IF EXISTS settlement_rules_rule_name_check;

ALTER TABLE public.settlement_rules
    ADD CONSTRAINT settlement_rules_rule_name_en_check CHECK (btrim(rule_name_en) <> '');

ALTER TABLE public.settlement_rules
    ADD CONSTRAINT settlement_rules_rule_name_ar_check CHECK (btrim(rule_name_ar) <> '');

UPDATE public.settlement_rules
SET rule_name_ar = CASE
    WHEN rule_type = 'ticket' THEN 'قاعدة تذاكر السفر'
    WHEN rule_type = 'leave_salary' THEN 'قاعدة راتب الإجازة'
    ELSE rule_name_ar
END
WHERE btrim(rule_name_ar) = '';

INSERT INTO public.settlement_rules (
    rule_type,
    rule_name_en,
    rule_name_ar,
    qualification_cycle_years,
    ticket_count,
    entitled_days,
    is_active,
    created_by,
    updated_by
)
SELECT *
FROM (
    VALUES
        ('ticket', 'Travel Tickets Rule', 'قاعدة تذاكر السفر', 1, 1, NULL::integer, true, NULL::uuid, NULL::uuid),
        ('leave_salary', 'Leave Salary Rule', 'قاعدة راتب الإجازة', 1, NULL::integer, 21, true, NULL::uuid, NULL::uuid)
) AS seed(rule_type, rule_name_en, rule_name_ar, qualification_cycle_years, ticket_count, entitled_days, is_active, created_by, updated_by)
WHERE NOT EXISTS (
    SELECT 1
    FROM public.settlement_rules existing
    WHERE existing.rule_type = seed.rule_type
      AND existing.rule_name_en = seed.rule_name_en
);
