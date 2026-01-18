-- Insert day off reasons in English and Arabic
-- Medical reasons, personal reasons, official reasons, etc.

INSERT INTO day_off_reasons (id, reason_en, reason_ar, is_deductible, is_document_mandatory) VALUES
-- Medical Reasons (Deductible, Document Mandatory)
('DRS001', 'Sick leave', 'إجازة مرضية', true, true),
('DRS002', 'Doctor''s appointment', 'موعد طبي', true, true),
('DRS003', 'Medical check-up', 'فحص طبي', true, true),
('DRS004', 'Hospital visit', 'زيارة مستشفى', true, true),
('DRS005', 'Recovery after illness', 'التعافي من المرض', true, true),
('DRS006', 'Follow-up medical treatment', 'متابعة علاج طبي', true, true),
('DRS007', 'Quarantine / contagious illness', 'الحجر الصحي / مرض معدي', true, true),
('DRS008', 'Caring for a sick family member', 'رعاية فرد أسري مريض', true, true),

-- Personal Reasons (Deductible, No Document Required)
('DRS009', 'Personal work', 'عمل شخصي', true, false),
('DRS010', 'Family matter', 'شؤون عائلية', true, false),
('DRS011', 'Personal emergency', 'حالة طارئة شخصية', true, false),
('DRS012', 'Mental health day', 'يوم الصحة النفسية', true, false),
('DRS013', 'Stress recovery', 'التعافي من الإجهاد', true, false),
('DRS014', 'Rest / fatigue recovery', 'الراحة / التعافي من الإرهاق', true, false),

-- Home & Household Reasons (Deductible, Document Mandatory)
('DRS015', 'Home relocation', 'نقل منزل', true, true),
('DRS016', 'House maintenance / repair', 'صيانة / إصلاح المنزل', true, true),
('DRS017', 'Important personal appointment', 'موعد شخصي مهم', true, false),

-- Family & Social Events (Deductible, No Document Required)
('DRS018', 'Family function', 'مناسبة عائلية', true, false),
('DRS019', 'Wedding / engagement', 'حفل زفاف / خطوبة', true, false),
('DRS020', 'Funeral / bereavement', 'جنازة / فقدان', true, false),

-- Child & Parent Care (Deductible, Document Mandatory)
('DRS021', 'Child care responsibilities', 'مسؤوليات رعاية الأطفال', true, true),
('DRS022', 'School meeting / child exam support', 'اجتماع مدرسي / دعم امتحان الطفل', true, true),
('DRS023', 'Parent care', 'رعاية الوالدين', true, true),

-- Official/Legal Reasons (Not Deductible, Document Mandatory)
('DRS024', 'Government office work', 'عمل بالجهات الحكومية', false, true),
('DRS025', 'Legal appointment', 'موعد قانوني', false, true),
('DRS026', 'Court appearance', 'حضور المحكمة', false, true),
('DRS027', 'Bank-related work', 'عمل متعلق بالبنك', false, true),
('DRS028', 'Document verification', 'التحقق من المستندات', false, true),
('DRS029', 'ID / license renewal', 'تجديد الهوية / الرخصة', false, true),
('DRS030', 'Visa / immigration work', 'تأشيرة / عمل الهجرة', false, true),

-- Travel & Planned Leave (Deductible, No Document Required)
('DRS031', 'Planned leave', 'إجازة مخطط لها', true, false),
('DRS032', 'Outstation travel', 'سفر خارج المحافظة', true, false),
('DRS033', 'Vacation / holiday', 'إجازة / عطلة', true, false),
('DRS034', 'Emergency travel', 'سفر طارئ', true, false),

-- Transportation & Weather (Not Deductible, No Document Required)
('DRS035', 'Transportation issues', 'مشاكل النقل', false, false),
('DRS036', 'Vehicle breakdown', 'تعطل المركبة', false, false),
('DRS037', 'Public transport strike', 'إضراب المواصلات', false, false),
('DRS038', 'Heavy rain / flood', 'أمطار غزيرة / فيضان', false, false),
('DRS039', 'Natural disaster', 'كارثة طبيعية', false, false),
('DRS040', 'Power or utility issues', 'انقطاع الكهرباء أو المرافق', false, false),
('DRS041', 'Internet outage (work from home not possible)', 'انقطاع الإنترنت (العمل من المنزل غير ممكن)', false, false),

-- Religious & Cultural (Deductible, Document Mandatory)
('DRS042', 'Religious observance', 'ممارسة دينية', true, true),
('DRS043', 'Festival leave', 'إجازة المهرجان', true, false),
('DRS044', 'Pilgrimage travel', 'سفر الحج', true, true),

-- Compensatory & Shift Adjustments (Not Deductible, No Document Required)
('DRS045', 'Compensatory off', 'إجازة تعويضية', false, false),
('DRS046', 'Worked on previous holiday', 'عمل في عطلة سابقة', false, false),
('DRS047', 'Shift adjustment', 'تعديل المناوبة', false, false),

-- Training & Development (Not Deductible, Document Mandatory)
('DRS048', 'Training / exam attendance', 'حضور التدريب / الامتحان', false, true),
('DRS049', 'Personal development course', 'دورة التنمية الشخصية', false, true),
('DRS050', 'Exam preparation', 'التحضير للامتحان', false, true),

-- Official Duties (Not Deductible, Document Mandatory)
('DRS051', 'Jury duty / official summons', 'واجب هيئة المحلفين / استدعاء رسمي', false, true),
('DRS052', 'Security or safety concern', 'مخاوف الأمان أو السلامة', false, false)

ON CONFLICT (id) DO NOTHING;
