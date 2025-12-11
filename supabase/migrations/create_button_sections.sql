-- Create main sections table
CREATE TABLE button_main_sections (
  id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  section_name_en VARCHAR(255) NOT NULL,
  section_name_ar VARCHAR(255) NOT NULL,
  section_code VARCHAR(50) NOT NULL UNIQUE,
  display_order INT NOT NULL DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create sub sections table
CREATE TABLE button_sub_sections (
  id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  main_section_id BIGINT NOT NULL,
  subsection_name_en VARCHAR(255) NOT NULL,
  subsection_name_ar VARCHAR(255) NOT NULL,
  subsection_code VARCHAR(50) NOT NULL,
  display_order INT NOT NULL DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  CONSTRAINT fk_main_section FOREIGN KEY (main_section_id) REFERENCES button_main_sections(id) ON DELETE CASCADE,
  UNIQUE(main_section_id, subsection_code)
);

-- Create buttons table
CREATE TABLE sidebar_buttons (
  id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  main_section_id BIGINT NOT NULL,
  subsection_id BIGINT NOT NULL,
  button_name_en VARCHAR(255) NOT NULL,
  button_name_ar VARCHAR(255) NOT NULL,
  button_code VARCHAR(100) NOT NULL,
  icon VARCHAR(50),
  display_order INT NOT NULL DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  CONSTRAINT fk_main_section FOREIGN KEY (main_section_id) REFERENCES button_main_sections(id) ON DELETE CASCADE,
  CONSTRAINT fk_sub_section FOREIGN KEY (subsection_id) REFERENCES button_sub_sections(id) ON DELETE CASCADE,
  UNIQUE(main_section_id, subsection_id, button_code)
);

-- Create button permissions table (for user-specific button access)
CREATE TABLE button_permissions (
  id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  user_id UUID NOT NULL,
  button_id BIGINT NOT NULL,
  is_enabled BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  CONSTRAINT fk_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_button FOREIGN KEY (button_id) REFERENCES sidebar_buttons(id) ON DELETE CASCADE,
  UNIQUE(user_id, button_id)
);

-- Create indexes for performance
CREATE INDEX idx_button_main_sections_active ON button_main_sections(is_active);
CREATE INDEX idx_button_sub_sections_main ON button_sub_sections(main_section_id);
CREATE INDEX idx_button_sub_sections_active ON button_sub_sections(is_active);
CREATE INDEX idx_sidebar_buttons_main ON sidebar_buttons(main_section_id);
CREATE INDEX idx_sidebar_buttons_sub ON sidebar_buttons(subsection_id);
CREATE INDEX idx_sidebar_buttons_active ON sidebar_buttons(is_active);
CREATE INDEX idx_button_permissions_user ON button_permissions(user_id);
CREATE INDEX idx_button_permissions_button ON button_permissions(button_id);

-- Insert main sections
INSERT INTO button_main_sections (section_name_en, section_name_ar, section_code, display_order) VALUES
('Delivery', 'التسليم', 'DELIVERY', 1),
('Vendor', 'البائع', 'VENDOR', 2),
('Media', 'وسائط', 'MEDIA', 3),
('Promo', 'عروض ترويجية', 'PROMO', 4),
('Finance', 'المالية', 'FINANCE', 5),
('HR', 'الموارد البشرية', 'HR', 6),
('Tasks', 'المهام', 'TASKS', 7),
('Notification', 'الإخطارات', 'NOTIFICATION', 8),
('Users', 'المستخدمون', 'USERS', 9),
('Controls', 'المراقبات', 'CONTROLS', 10);

-- Insert subsections for all sections
INSERT INTO button_sub_sections (main_section_id, subsection_name_en, subsection_name_ar, subsection_code, display_order) VALUES
((SELECT id FROM button_main_sections WHERE section_code = 'DELIVERY'), 'Dashboard', 'لوحة التحكم', 'DASHBOARD', 1),
((SELECT id FROM button_main_sections WHERE section_code = 'DELIVERY'), 'Manage', 'إدارة', 'MANAGE', 2),
((SELECT id FROM button_main_sections WHERE section_code = 'DELIVERY'), 'Operations', 'العمليات', 'OPERATIONS', 3),
((SELECT id FROM button_main_sections WHERE section_code = 'DELIVERY'), 'Reports', 'التقارير', 'REPORTS', 4),
((SELECT id FROM button_main_sections WHERE section_code = 'VENDOR'), 'Dashboard', 'لوحة التحكم', 'DASHBOARD', 1),
((SELECT id FROM button_main_sections WHERE section_code = 'VENDOR'), 'Manage', 'إدارة', 'MANAGE', 2),
((SELECT id FROM button_main_sections WHERE section_code = 'VENDOR'), 'Operations', 'العمليات', 'OPERATIONS', 3),
((SELECT id FROM button_main_sections WHERE section_code = 'VENDOR'), 'Reports', 'التقارير', 'REPORTS', 4),
((SELECT id FROM button_main_sections WHERE section_code = 'MEDIA'), 'Dashboard', 'لوحة التحكم', 'DASHBOARD', 1),
((SELECT id FROM button_main_sections WHERE section_code = 'MEDIA'), 'Manage', 'إدارة', 'MANAGE', 2),
((SELECT id FROM button_main_sections WHERE section_code = 'MEDIA'), 'Operations', 'العمليات', 'OPERATIONS', 3),
((SELECT id FROM button_main_sections WHERE section_code = 'MEDIA'), 'Reports', 'التقارير', 'REPORTS', 4),
((SELECT id FROM button_main_sections WHERE section_code = 'PROMO'), 'Dashboard', 'لوحة التحكم', 'DASHBOARD', 1),
((SELECT id FROM button_main_sections WHERE section_code = 'PROMO'), 'Manage', 'إدارة', 'MANAGE', 2),
((SELECT id FROM button_main_sections WHERE section_code = 'PROMO'), 'Operations', 'العمليات', 'OPERATIONS', 3),
((SELECT id FROM button_main_sections WHERE section_code = 'PROMO'), 'Reports', 'التقارير', 'REPORTS', 4),
((SELECT id FROM button_main_sections WHERE section_code = 'FINANCE'), 'Dashboard', 'لوحة التحكم', 'DASHBOARD', 1),
((SELECT id FROM button_main_sections WHERE section_code = 'FINANCE'), 'Manage', 'إدارة', 'MANAGE', 2),
((SELECT id FROM button_main_sections WHERE section_code = 'FINANCE'), 'Operations', 'العمليات', 'OPERATIONS', 3),
((SELECT id FROM button_main_sections WHERE section_code = 'FINANCE'), 'Reports', 'التقارير', 'REPORTS', 4),
((SELECT id FROM button_main_sections WHERE section_code = 'HR'), 'Dashboard', 'لوحة التحكم', 'DASHBOARD', 1),
((SELECT id FROM button_main_sections WHERE section_code = 'HR'), 'Manage', 'إدارة', 'MANAGE', 2),
((SELECT id FROM button_main_sections WHERE section_code = 'HR'), 'Operations', 'العمليات', 'OPERATIONS', 3),
((SELECT id FROM button_main_sections WHERE section_code = 'HR'), 'Reports', 'التقارير', 'REPORTS', 4),
((SELECT id FROM button_main_sections WHERE section_code = 'TASKS'), 'Dashboard', 'لوحة التحكم', 'DASHBOARD', 1),
((SELECT id FROM button_main_sections WHERE section_code = 'TASKS'), 'Manage', 'إدارة', 'MANAGE', 2),
((SELECT id FROM button_main_sections WHERE section_code = 'TASKS'), 'Operations', 'العمليات', 'OPERATIONS', 3),
((SELECT id FROM button_main_sections WHERE section_code = 'TASKS'), 'Reports', 'التقارير', 'REPORTS', 4),
((SELECT id FROM button_main_sections WHERE section_code = 'NOTIFICATION'), 'Dashboard', 'لوحة التحكم', 'DASHBOARD', 1),
((SELECT id FROM button_main_sections WHERE section_code = 'NOTIFICATION'), 'Manage', 'إدارة', 'MANAGE', 2),
((SELECT id FROM button_main_sections WHERE section_code = 'NOTIFICATION'), 'Operations', 'العمليات', 'OPERATIONS', 3),
((SELECT id FROM button_main_sections WHERE section_code = 'NOTIFICATION'), 'Reports', 'التقارير', 'REPORTS', 4),
((SELECT id FROM button_main_sections WHERE section_code = 'USERS'), 'Dashboard', 'لوحة التحكم', 'DASHBOARD', 1),
((SELECT id FROM button_main_sections WHERE section_code = 'USERS'), 'Manage', 'إدارة', 'MANAGE', 2),
((SELECT id FROM button_main_sections WHERE section_code = 'USERS'), 'Operations', 'العمليات', 'OPERATIONS', 3),
((SELECT id FROM button_main_sections WHERE section_code = 'USERS'), 'Reports', 'التقارير', 'REPORTS', 4),
((SELECT id FROM button_main_sections WHERE section_code = 'CONTROLS'), 'Dashboard', 'لوحة التحكم', 'DASHBOARD', 1),
((SELECT id FROM button_main_sections WHERE section_code = 'CONTROLS'), 'Manage', 'إدارة', 'MANAGE', 2),
((SELECT id FROM button_main_sections WHERE section_code = 'CONTROLS'), 'Operations', 'العمليات', 'OPERATIONS', 3),
((SELECT id FROM button_main_sections WHERE section_code = 'CONTROLS'), 'Reports', 'التقارير', 'REPORTS', 4);

-- Grant all button permissions to all 103 users
INSERT INTO button_permissions (user_id, button_id, is_enabled) 
SELECT 
  u.id as user_id,
  b.id as button_id,
  true as is_enabled
FROM (
  SELECT id FROM (VALUES 
    ('197cca74-1ce5-45f7-add1-f19cf0cbb1c0'::uuid),
    ('f9de195b-a970-4e42-887a-f5d1e38b35ff'::uuid),
    ('48fed84b-a69b-40a4-96fa-c83f10489d8c'::uuid),
    ('775166a6-4aea-47e0-8f1e-bbe34bb87284'::uuid),
    ('ee85779f-1651-4a05-934b-7d83c8b9f157'::uuid),
    ('f25c180f-838e-4132-a42c-44a72e074681'::uuid),
    ('31eb78e3-bf56-40dd-8f23-52b9c525167c'::uuid),
    ('125eec71-7eba-4352-b17f-2f4ea6bb28f8'::uuid),
    ('861fcc63-0574-49e7-aa4c-372504e6c632'::uuid),
    ('92261154-aa7c-46c3-af7d-91ad93bf53fb'::uuid),
    ('252b172f-2d8d-4d28-b6b9-90d800dc9672'::uuid),
    ('d031e78b-26ca-4984-ab7f-c2d4a16afcdd'::uuid),
    ('4b8c78cc-f0ea-4337-b677-3ef45d718fdf'::uuid),
    ('6f883b06-13a8-476b-86ce-a7a79553a4bd'::uuid),
    ('68670b6c-246d-4455-9ad0-feb224c43e1c'::uuid),
    ('6c2df6a3-3702-4eaa-ad56-9bb47e14ca22'::uuid),
    ('1bd89dc2-f0b9-4759-94ae-6c3bc3e4cf91'::uuid),
    ('182ae08e-6d73-47a3-8ed2-16cbe6d6bb78'::uuid),
    ('86c0f43f-255f-4d2f-9517-5ac6c66ebac7'::uuid),
    ('e9c0a948-ea0b-430f-89f7-6fc824f1f4b0'::uuid),
    ('ae8040d7-36f1-4ed0-b270-427e4863eed0'::uuid),
    ('924725e0-9ff8-4394-b3af-0dfc90eb6f24'::uuid),
    ('092639c0-da73-4a11-bdff-bcef8af6be6c'::uuid),
    ('007847bf-dec6-4371-8183-6f83e9c6b1ae'::uuid),
    ('e5a399ab-6365-494f-a3f1-5ae6bfd395b5'::uuid),
    ('f3d827bf-a182-4891-a001-8bf045564d5f'::uuid),
    ('e6ad99e1-ccd2-47ea-b684-973bc87d692d'::uuid),
    ('63ff9fde-f7d4-43da-888a-b9e41fa4b74a'::uuid),
    ('f0277bd7-d755-47a0-9916-fa9fa76e8b86'::uuid),
    ('75c4f645-be21-4087-9d2d-0e110382fd2d'::uuid),
    ('667cf5b7-bd49-4e05-a0a9-230684391848'::uuid),
    ('0a5ede9a-ee94-457f-8cb4-b5c0d5994a9b'::uuid),
    ('e99aa03c-ec77-4ee9-bbff-9a59e50f113b'::uuid),
    ('652e463b-0e11-44c8-a89a-bab597469e3f'::uuid),
    ('fedf7bfe-a8d4-42d2-b0d8-5fa9cb5f9581'::uuid),
    ('7b447dc7-4f1a-4cc9-a0db-0bb59d72f96e'::uuid),
    ('26bcedc2-1099-43c7-9b4c-d5e915158ac7'::uuid),
    ('6fcd5873-f2ab-407e-a48e-3519f216c228'::uuid),
    ('133cc9e1-2720-4789-af8f-75516e702c1b'::uuid),
    ('93a5e7f7-7cde-4e72-a249-d1a03ebc9346'::uuid),
    ('efa4aedd-867f-4223-b9e6-220375892c2d'::uuid),
    ('069ec45a-899b-4973-b930-bb34e1f7db93'::uuid),
    ('bc3d6349-8237-407a-aeef-96dab9d51adf'::uuid),
    ('349909ef-a777-4994-a02e-8a1613b8b874'::uuid),
    ('da203481-a780-4abf-8582-a8d7b77c6021'::uuid),
    ('97682056-6ddf-4b88-9dd6-3721f7609c84'::uuid),
    ('d9a98ed7-6602-48d3-8ec6-4ee28b1ea912'::uuid),
    ('c0ee0300-5441-45d4-a58d-eb99cb236ce9'::uuid),
    ('96091f20-6fef-409c-87c3-20476e90b73d'::uuid),
    ('573efff8-ad10-4298-b4fb-0f62862eb9ca'::uuid),
    ('f4823eec-7393-449b-88e8-057a22a4bfc5'::uuid),
    ('60c5b935-45cf-4837-b17e-501e5332dfb5'::uuid),
    ('fb548a19-986e-4f46-9648-aac14724a6c3'::uuid),
    ('36bdb355-e03e-44a4-b795-3fb50caeac8c'::uuid),
    ('14115aab-ea70-4088-b85f-2ed36d6652f8'::uuid),
    ('3a890d8a-f365-4f04-882d-2169c0ffd81f'::uuid),
    ('93318dab-04b0-4c37-a0eb-f07095272600'::uuid),
    ('6f11de96-2ba8-4c63-9e87-48aa8eaec413'::uuid),
    ('7fd00cff-31f8-47cc-a050-618ca445a993'::uuid),
    ('5bcab46b-467f-4a3b-b9a9-c8611a6257a8'::uuid),
    ('564223f2-a373-46f0-ad78-eacdb09becf9'::uuid),
    ('4794548d-b311-452b-a764-5b3c4586bb0d'::uuid),
    ('2190db69-27c4-49b0-939c-272a5448c248'::uuid),
    ('ca4f43f0-0478-4879-95ba-fde049f8470c'::uuid),
    ('f482030e-0864-4dfb-b188-a0abb07a0230'::uuid),
    ('e9f184e8-b85a-4834-b248-29c4e5ff4494'::uuid),
    ('b7e33703-7a0e-4d84-9fff-debf123f53ec'::uuid),
    ('99e148fe-740d-42f8-8d2d-71c2f2eee4bd'::uuid),
    ('02d3ee83-10f8-4474-8132-fcc2c16264d1'::uuid),
    ('05e7f43b-2214-4056-a792-30f466ad7cc7'::uuid),
    ('90c7c901-3474-4fee-bca3-ac859964dfeb'::uuid),
    ('e1fdaee2-97f0-4fc1-872f-9d99c6bd684b'::uuid),
    ('c6661cfd-9591-42dc-bb5e-8652704675da'::uuid),
    ('8963b6ac-cfb0-4e50-acaa-aba8402acba0'::uuid),
    ('9a4e05ff-69fd-49ec-bf5c-908dee1d441d'::uuid),
    ('9401b42a-8d50-44f6-b94a-ea9a597ebdf0'::uuid),
    ('9af50d1e-6810-4af2-9c11-a1e8738be6bd'::uuid),
    ('e2f2497c-4949-48bb-b2cb-990376f71c8c'::uuid),
    ('1debe7d5-0feb-4306-8bbb-32a09b61c5ea'::uuid),
    ('d19be4aa-94ed-436a-8d26-f79cd6d40e65'::uuid),
    ('02e3d5fa-921e-4fc1-be75-94307dd946e8'::uuid),
    ('15dfa37a-ffab-45d6-a87d-b13bb5a0ae43'::uuid),
    ('1d0811b7-30aa-4f68-89c7-21f622927335'::uuid),
    ('1573da66-92ac-41f5-8f2e-c5134942ff76'::uuid),
    ('aa018c9f-5236-4eb5-8008-3afba63a2f36'::uuid),
    ('4ff2dafc-99f9-4fe9-b869-dd98953b9490'::uuid),
    ('1c5ed1c1-65db-42a9-b530-d2ca29d7fb30'::uuid),
    ('9fe9e217-6953-4d0f-99dd-a8fd8bfded9d'::uuid),
    ('3e023c5b-ff0e-4294-8f33-429354def804'::uuid),
    ('32eea432-7212-404a-b419-4c7a7aabe443'::uuid),
    ('2633ae42-ad34-4206-819a-72a9bba0c064'::uuid),
    ('4ff8b724-ac89-4f55-b453-27145ffa3dd5'::uuid),
    ('794cb269-e0c0-43ed-98a3-954f2db45194'::uuid),
    ('45829d20-e500-4b77-b03d-85c42b7361f0'::uuid),
    ('8b97aebf-5eeb-43f9-891c-da2010428ef5'::uuid),
    ('807af948-0f5f-4f36-8925-747b152513c1'::uuid),
    ('2b41bd32-7abc-4721-aa12-756bc5337c26'::uuid),
    ('62b05d1a-57b8-4481-a071-3de2386bf46a'::uuid),
    ('590601e9-af35-4ccb-9d80-323268e847bd'::uuid),
    ('ab18470c-0fe6-442b-9379-2a82bc5883c2'::uuid),
    ('ee47e425-0a10-40c3-aa7d-268efd4264a2'::uuid),
    ('1d1e5b34-4127-405c-81fe-6662dda96056'::uuid),
    ('b658eca1-3cc1-48b2-bd3c-33b81fab5a0f'::uuid)
  ) AS u(id)
) u
CROSS JOIN sidebar_buttons b
ON CONFLICT (user_id, button_id) DO NOTHING;
