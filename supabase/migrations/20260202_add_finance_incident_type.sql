-- Add Finance Department and Customer/POS incident types to incident_types table

INSERT INTO public.incident_types (id, incident_type_en, incident_type_ar)
VALUES ('IN8', 'Finance Department', 'القسم المالي')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.incident_types (id, incident_type_en, incident_type_ar)
VALUES ('IN9', 'Customer/POS', 'العميل/نقطة البيع')
ON CONFLICT (id) DO NOTHING;
