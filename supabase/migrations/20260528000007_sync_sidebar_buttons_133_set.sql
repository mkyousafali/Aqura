-- Synchronize sidebar_buttons with current Sidebar.svelte permission codes
-- Adds 8 new codes and removes 8 obsolete codes identified by full audit.

BEGIN;

CREATE TEMP TABLE tmp_desired_buttons (
    section_code varchar,
    section_name_en varchar,
    subsection_code varchar,
    subsection_name_en varchar,
    button_code varchar,
    button_name_en varchar,
    icon varchar
) ON COMMIT DROP;

INSERT INTO tmp_desired_buttons (
    section_code,
    section_name_en,
    subsection_code,
    subsection_name_en,
    button_code,
    button_name_en,
    icon
)
VALUES
    ('PROMO', 'Promo', 'MANAGE', 'Manage', 'GIFT_WHEEL_MANAGER', 'Gift Wheel Manager', '🎡'),
    ('PROMO', 'Promo', 'MANAGE', 'Manage', 'SURPRISE_BOX_MANAGER', 'Surprise Box Manager', '🎁'),
    ('PROMO', 'Promo', 'MANAGE', 'Manage', 'VIP_CAMPAIGN', 'Vip Campaign', '👑'),
    ('HR', 'HR', 'MANAGE', 'Manage', 'HR_SERVICES', 'HR Services', '✅'),
    ('LOYALTY', 'Loyalty', 'DASHBOARD', 'Dashboard', 'CUSTOMER_APP', 'Customer App', '👥'),
    ('CONTROLS', 'Controls', 'MANAGE', 'Manage', 'ICON_MANAGER', 'Icon Manager', '🎨'),
    ('CONTROLS', 'Controls', 'OPERATIONS', 'Operations', 'PUSH_NOTIFICATION_SETTINGS', 'Push Notification Settings', '🔔'),
    ('CONTROLS', 'Controls', 'OPERATIONS', 'Operations', 'LOCAL_UPDATE', 'Local Update', '🚀');

-- Ensure required sections exist
INSERT INTO public.button_main_sections (
    section_name_en,
    section_name_ar,
    section_code,
    display_order,
    is_active
)
SELECT
    d.section_name_en,
    d.section_name_en,
    d.section_code,
    COALESCE((SELECT MAX(display_order) FROM public.button_main_sections), 0)
        + ROW_NUMBER() OVER (ORDER BY d.section_code),
    true
FROM (
    SELECT DISTINCT section_code, section_name_en
    FROM tmp_desired_buttons
) d
WHERE NOT EXISTS (
    SELECT 1
    FROM public.button_main_sections m
    WHERE m.section_code = d.section_code
);

-- Ensure required subsections exist
INSERT INTO public.button_sub_sections (
    main_section_id,
    subsection_name_en,
    subsection_name_ar,
    subsection_code,
    display_order,
    is_active
)
SELECT
    m.id,
    d.subsection_name_en,
    d.subsection_name_en,
    d.subsection_code,
    CASE d.subsection_code
        WHEN 'DASHBOARD' THEN 1
        WHEN 'MANAGE' THEN 2
        WHEN 'OPERATIONS' THEN 3
        WHEN 'REPORTS' THEN 4
        ELSE 5
    END,
    true
FROM (
    SELECT DISTINCT section_code, subsection_code, subsection_name_en
    FROM tmp_desired_buttons
) d
JOIN public.button_main_sections m
    ON m.section_code = d.section_code
WHERE NOT EXISTS (
    SELECT 1
    FROM public.button_sub_sections s
    WHERE s.main_section_id = m.id
      AND s.subsection_code = d.subsection_code
);

-- Insert missing buttons
INSERT INTO public.sidebar_buttons (
    main_section_id,
    subsection_id,
    button_name_en,
    button_name_ar,
    button_code,
    icon,
    display_order,
    is_active
)
SELECT
    m.id,
    s.id,
    d.button_name_en,
    d.button_name_en,
    d.button_code,
    d.icon,
    1,
    true
FROM tmp_desired_buttons d
JOIN public.button_main_sections m
    ON m.section_code = d.section_code
JOIN public.button_sub_sections s
    ON s.main_section_id = m.id
   AND s.subsection_code = d.subsection_code
WHERE NOT EXISTS (
    SELECT 1
    FROM public.sidebar_buttons b
    WHERE b.button_code = d.button_code
);

-- Ensure permissions exist for newly added buttons
INSERT INTO public.button_permissions (user_id, button_id, is_enabled)
SELECT
    u.id,
    b.id,
    true
FROM public.users u
JOIN public.sidebar_buttons b
    ON b.button_code IN (SELECT button_code FROM tmp_desired_buttons)
WHERE NOT EXISTS (
    SELECT 1
    FROM public.button_permissions p
    WHERE p.user_id = u.id
      AND p.button_id = b.id
);

-- Remove obsolete button permissions first, then buttons
WITH obsolete_buttons AS (
    SELECT id
    FROM public.sidebar_buttons
    WHERE button_code IN (
        'UPLOAD_EMPLOYEES',
        'CONTACT_MANAGEMENT',
        'DOCUMENT_MANAGEMENT',
        'WARNING_MASTER',
        'SALARY_WAGE_MANAGEMENT',
        'BIOMETRIC_DATA',
        'LEAVES_AND_VACATIONS',
        'LEAVE_REQUEST'
    )
)
DELETE FROM public.button_permissions p
USING obsolete_buttons o
WHERE p.button_id = o.id;

DELETE FROM public.sidebar_buttons
WHERE button_code IN (
    'UPLOAD_EMPLOYEES',
    'CONTACT_MANAGEMENT',
    'DOCUMENT_MANAGEMENT',
    'WARNING_MASTER',
    'SALARY_WAGE_MANAGEMENT',
    'BIOMETRIC_DATA',
    'LEAVES_AND_VACATIONS',
    'LEAVE_REQUEST'
);

COMMIT;
