-- Backfill settlement rules with cycle units and seed ticket rule examples

ALTER TABLE public.settlement_rules
    ADD COLUMN IF NOT EXISTS qualification_cycle_value integer NOT NULL DEFAULT 1;

ALTER TABLE public.settlement_rules
    ADD COLUMN IF NOT EXISTS qualification_cycle_unit text NOT NULL DEFAULT 'year';

ALTER TABLE public.settlement_rules
    DROP CONSTRAINT IF EXISTS settlement_rules_qualification_cycle_unit_check;

ALTER TABLE public.settlement_rules
    ADD CONSTRAINT settlement_rules_qualification_cycle_unit_check
    CHECK (qualification_cycle_unit IN ('year', 'month'));

UPDATE public.settlement_rules
SET qualification_cycle_value = qualification_cycle_years,
    qualification_cycle_unit = 'year'
WHERE qualification_cycle_unit = 'year'
  AND qualification_cycle_value = 1;

UPDATE public.settlement_rules
SET rule_name_en = 'Travel Tickets Rule - 1 Year / 1 Ticket',
    rule_name_ar = 'قاعدة تذاكر السفر - سنة واحدة / تذكرة واحدة',
    qualification_cycle_years = 1,
    qualification_cycle_value = 1,
    qualification_cycle_unit = 'year',
    ticket_count = 1,
    entitled_days = NULL
WHERE rule_type = 'ticket'
  AND rule_name_en IN ('Travel Tickets Rule', 'Travel Tickets Rule - 1 Year / 1 Ticket');

INSERT INTO public.settlement_rules (
    rule_type,
    rule_name_en,
    rule_name_ar,
    qualification_cycle_years,
    qualification_cycle_value,
    qualification_cycle_unit,
    ticket_count,
    entitled_days,
    is_active,
    created_by,
    updated_by
)
SELECT
    'ticket',
    'Travel Tickets Rule - 1 Year / 1 Ticket',
    'قاعدة تذاكر السفر - سنة واحدة / تذكرة واحدة',
    1,
    1,
    'year',
    1,
    NULL::integer,
    true,
    NULL::uuid,
    NULL::uuid
WHERE NOT EXISTS (
    SELECT 1
    FROM public.settlement_rules existing
    WHERE existing.rule_type = 'ticket'
      AND existing.rule_name_en = 'Travel Tickets Rule - 1 Year / 1 Ticket'
);

UPDATE public.settlement_rules
SET rule_name_en = 'Leave Salary Rule - 1 Year / 21 Days',
        rule_name_ar = 'قاعدة راتب الإجازة - سنة واحدة / 21 يومًا',
        qualification_cycle_years = 1,
        qualification_cycle_value = 1,
        qualification_cycle_unit = 'year',
        ticket_count = NULL,
        entitled_days = 21
WHERE rule_type = 'leave_salary'
    AND rule_name_en IN ('Leave Salary Rule', 'Leave Salary Rule - 1 Year / 21 Days', 'Leave Salary Rule - 1 Year / 30 Days');

INSERT INTO public.settlement_rules (
    rule_type,
    rule_name_en,
    rule_name_ar,
    qualification_cycle_years,
    qualification_cycle_value,
    qualification_cycle_unit,
    ticket_count,
    entitled_days,
    is_active,
    created_by,
    updated_by
)
SELECT *
FROM (
    VALUES
        ('ticket', 'Travel Tickets Rule - 2 Years / 2 Tickets', 'قاعدة تذاكر السفر - سنتان / تذكرتان', 2, 2, 'year', 2, NULL::integer, true, NULL::uuid, NULL::uuid),
        ('ticket', 'Travel Tickets Rule - 3 Months / 2 Tickets', 'قاعدة تذاكر السفر - 3 أشهر / تذكرتان', 1, 3, 'month', 2, NULL::integer, true, NULL::uuid, NULL::uuid),
        ('leave_salary', 'Leave Salary Rule - 1 Year / 30 Days', 'قاعدة راتب الإجازة - سنة واحدة / 30 يومًا', 1, 1, 'year', NULL::integer, 30, true, NULL::uuid, NULL::uuid)
) AS seed(rule_type, rule_name_en, rule_name_ar, qualification_cycle_years, qualification_cycle_value, qualification_cycle_unit, ticket_count, entitled_days, is_active, created_by, updated_by)
WHERE NOT EXISTS (
    SELECT 1
    FROM public.settlement_rules existing
    WHERE existing.rule_type = seed.rule_type
      AND existing.rule_name_en = seed.rule_name_en
);
