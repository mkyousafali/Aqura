-- Insert initial data for warning system

-- Insert Main Categories
INSERT INTO warning_main_category (id, name_en, name_ar) VALUES
('wam1', 'Cash & Billing', 'النقد والفواتير'),
('wam2', 'POS & System', 'أنظمة نقاط البيع'),
('wam3', 'Merchandising', 'ترتيب الأرفف'),
('wam4', 'Pricing', 'التسعير'),
('wam5', 'Promotions', 'العروض'),
('wam6', 'Expiry & Inventory', 'الصلاحية والمخزون'),
('wam7', 'Hygiene & Cleaning', 'النظافة'),
('wam8', 'Food Safety', 'سلامة الغذاء'),
('wam9', 'Staff Discipline', 'الانضباط الوظيفي'),
('wam10', 'Customer Service', 'خدمة العملاء'),
('wam11', 'Safety & Security', 'السلامة والأمن'),
('wam12', 'Assets & Ethics', 'الأصول والأخلاقيات')
ON CONFLICT (id) DO NOTHING;

-- Insert Sub Categories
INSERT INTO warning_sub_category (id, main_category_id, name_en, name_ar) VALUES
('was1', 'wam1', 'Cash Handling', 'إدارة النقد'),
('was2', 'wam1', 'Billing Errors', 'أخطاء الفوترة'),
('was3', 'wam2', 'POS Access', 'صلاحيات النظام'),
('was4', 'wam2', 'POS Operation', 'تشغيل النظام'),
('was5', 'wam3', 'Shelf Management', 'إدارة الأرفف'),
('was6', 'wam4', 'Pricing & Tags', 'بطاقات الأسعار'),
('was7', 'wam5', 'Promotions', 'العروض'),
('was8', 'wam6', 'Expiry Control', 'إدارة الصلاحية'),
('was9', 'wam6', 'Inventory Control', 'إدارة المخزون'),
('was10', 'wam7', 'Cleaning Duties', 'مهام التنظيف'),
('was11', 'wam7', 'Hygiene Issues', 'مشاكل النظافة'),
('was12', 'wam8', 'Storage & Temp', 'التخزين والحرارة'),
('was13', 'wam9', 'Attendance', 'الحضور'),
('was14', 'wam9', 'Behavior', 'السلوك'),
('was15', 'wam10', 'Service Quality', 'جودة الخدمة'),
('was16', 'wam10', 'Conduct', 'السلوك'),
('was17', 'wam11', 'Safety Violation', 'مخالفة السلامة'),
('was18', 'wam12', 'Fraud', 'احتيال'),
('was19', 'wam12', 'Ethics', 'أخلاقيات العمل'),
('was20', 'wam3', 'Fresh Produce', 'الخضار والفواكه'),
('was21', 'wam3', 'Bakery Operations', 'عمليات المخبز'),
('was22', 'wam3', 'Deli & Meat Counter', 'قسم اللحوم والأجبان'),
('was23', 'wam8', 'Cold Chain', 'سلسلة التبريد'),
('was24', 'wam10', 'Store Operations', 'عمليات المتجر'),
('was25', 'wam6', 'Receiving & Delivery', 'الاستلام والتوصيل'),
('was26', 'wam10', 'Returns & Exchanges', 'المرتجعات والاستبدالات'),
('was27', 'wam11', 'Loss Prevention', 'منع الخسائر'),
('was28', 'wam7', 'Waste Management', 'إدارة النفايات'),
('was29', 'wam9', 'Staff Area', 'منطقة الموظفين'),
('was30', 'wam3', 'Display & Signage', 'العرض واللافتات')
ON CONFLICT (id) DO NOTHING;

-- Insert Violations
INSERT INTO warning_violation (id, main_category_id, sub_category_id, name_en, name_ar) VALUES
-- Cash & Billing - Cash Handling
('wav1', 'wam1', 'was1', 'Cash shortage at counter', 'عجز نقدي في الكاشير'),
('wav2', 'wam1', 'was1', 'Cash excess at counter', 'زيادة نقدية في الكاشير'),
('wav3', 'wam1', 'was1', 'Incorrect change given', 'إعطاء باقي غير صحيح'),
('wav4', 'wam1', 'was1', 'Cash drawer not balanced', 'درج النقد غير مطابق'),

-- Cash & Billing - Billing Errors
('wav5', 'wam1', 'was2', 'POS amount mismatch', 'عدم تطابق مبلغ الفاتورة'),
('wav6', 'wam1', 'was2', 'Incorrect billing', 'فوترة غير صحيحة'),
('wav7', 'wam1', 'was2', 'Duplicate billing', 'تكرار الفاتورة'),
('wav8', 'wam1', 'was2', 'Manual billing without approval', 'فوترة يدوية بدون موافقة'),
('wav9', 'wam1', 'was2', 'Manual price override', 'تغيير السعر بدون موافقة'),
('wav10', 'wam1', 'was2', 'Refund SOP not followed', 'عدم الالتزام بإجراء الاسترجاع'),
('wav11', 'wam1', 'was2', 'Fake void / cancel', 'إلغاء فاتورة وهمي'),

-- POS & System - POS Access
('wav12', 'wam2', 'was3', 'Sharing POS login', 'مشاركة حساب الكاشير'),
('wav13', 'wam2', 'was3', 'Using another POS', 'استخدام حساب موظف آخر'),
('wav14', 'wam2', 'was3', 'POS left logged in', 'ترك النظام مفتوح'),
('wav15', 'wam2', 'was3', 'Not logged out after shift', 'عدم تسجيل الخروج بعد الشفت'),

-- POS & System - POS Operation
('wav16', 'wam2', 'was4', 'Bypassing barcode scan', 'تجاوز مسح الباركود'),
('wav17', 'wam2', 'was4', 'Wrong item scanned', 'مسح صنف خاطئ'),
('wav18', 'wam2', 'was4', 'Receipt not issued', 'عدم تسليم الإيصال'),

-- Merchandising - Shelf Management
('wav19', 'wam3', 'was5', 'Improper shelf stacking', 'ترتيب خاطئ للأرفف'),
('wav20', 'wam3', 'was5', 'Wrong category placement', 'وضع الصنف في مكان خاطئ'),
('wav21', 'wam3', 'was5', 'Incorrect planogram', 'عدم الالتزام بالمخطط'),
('wav22', 'wam3', 'was5', 'Poor product facing', 'عرض غير منظم'),
('wav23', 'wam3', 'was5', 'Shelf empty at peak', 'رفوف فارغة وقت الذروة'),
('wav24', 'wam3', 'was5', 'Overstocking shelf', 'تكديس زائد على الرف'),
('wav25', 'wam3', 'was5', 'Delay in refill', 'تأخير تعبئة الرف'),

-- Pricing - Pricing & Tags
('wav26', 'wam4', 'was6', 'Wrong price tag', 'بطاقة سعر خاطئة'),
('wav27', 'wam4', 'was6', 'Missing price tag', 'عدم وجود بطاقة سعر'),

-- Promotions
('wav28', 'wam5', 'was7', 'Wrong promotion display', 'عرض ترويجي خاطئ'),
('wav29', 'wam5', 'was7', 'Promotion tag not removed', 'عدم إزالة عرض منتهي'),

-- Expiry & Inventory - Expiry Control
('wav30', 'wam6', 'was8', 'Expired product on shelf', 'منتج منتهي الصلاحية'),
('wav31', 'wam6', 'was8', 'Not removed expired item', 'عدم إزالة منتهي الصلاحية'),
('wav32', 'wam6', 'was8', 'Near-expiry not labeled', 'عدم وضع ملصق قرب الانتهاء'),
('wav33', 'wam6', 'was8', 'Near-expiry not reported', 'عدم الإبلاغ عن قرب الانتهاء'),
('wav34', 'wam6', 'was8', 'Near-expiry sold', 'بيع منتج قرب الانتهاء'),

-- Expiry & Inventory - Inventory Control
('wav35', 'wam6', 'was9', 'FIFO not followed', 'عدم تطبيق FIFO'),
('wav36', 'wam6', 'was9', 'Mixing expired & fresh', 'خلط منتهي مع جديد'),
('wav37', 'wam6', 'was9', 'Expiry check skipped', 'عدم فحص الصلاحية'),

-- Hygiene & Cleaning - Cleaning Duties
('wav38', 'wam7', 'was10', 'Floor not cleaned', 'الأرضية غير نظيفة'),
('wav39', 'wam7', 'was10', 'Shelf dusting skipped', 'عدم تنظيف الأرفف'),
('wav40', 'wam7', 'was10', 'Garbage not removed', 'عدم إخراج النفايات'),
('wav41', 'wam7', 'was10', 'Spillage not cleaned', 'عدم تنظيف الانسكاب'),

-- Hygiene & Cleaning - Hygiene Issues
('wav42', 'wam7', 'was11', 'Washroom hygiene issue', 'سوء نظافة دورة المياه'),
('wav43', 'wam7', 'was11', 'Store bad odour', 'رائحة كريهة في المتجر'),

-- Food Safety - Storage & Temp
('wav44', 'wam8', 'was12', 'Improper food storage', 'تخزين غذاء غير صحيح'),
('wav45', 'wam8', 'was12', 'Freezer temp issue', 'خلل درجة حرارة الفريزر'),
('wav46', 'wam8', 'was12', 'Chiller door open', 'باب الثلاجة مفتوح'),

-- Staff Discipline - Attendance
('wav47', 'wam9', 'was13', 'Late coming', 'تأخير عن الدوام'),
('wav48', 'wam9', 'was13', 'Absence without leave', 'غياب بدون إذن'),

-- Staff Discipline - Behavior
('wav49', 'wam9', 'was14', 'Sleeping on duty', 'نوم أثناء العمل'),
('wav50', 'wam9', 'was14', 'Mobile usage on floor', 'استخدام الجوال أثناء العمل'),

-- Customer Service - Service Quality
('wav51', 'wam10', 'was15', 'Slow service', 'بطء في الخدمة'),

-- Customer Service - Conduct
('wav52', 'wam10', 'was16', 'Rude language', 'استخدام ألفاظ غير لائقة'),

-- Safety & Security - Safety Violation
('wav53', 'wam11', 'was17', 'Blocking fire exit', 'إغلاق مخرج الطوارئ'),
('wav54', 'wam11', 'was17', 'Smoking in restricted area', 'التدخين في مكان ممنوع'),

-- Assets & Ethics - Fraud
('wav55', 'wam12', 'was18', 'Theft / pilferage', 'سرقة / اختلاس'),

-- Assets & Ethics - Ethics
('wav56', 'wam12', 'was19', 'Harassment / abuse', 'تحرش أو إساءة'),
('wav57', 'wam12', 'was19', 'Intoxication at work', 'العمل تحت تأثير مواد'),

-- Additional Cash & Billing - Cash Handling
('wav58', 'wam1', 'was1', 'Cash left unattended', 'ترك النقد بدون مراقبة'),
('wav59', 'wam1', 'was1', 'Not counting cash at shift start', 'عدم عد النقد بداية الشفت'),
('wav60', 'wam1', 'was1', 'Not counting cash at shift end', 'عدم عد النقد نهاية الشفت'),
('wav61', 'wam1', 'was1', 'Accepting counterfeit money', 'قبول نقود مزورة'),
('wav62', 'wam1', 'was1', 'Cash register not locked', 'درج النقد غير مقفل'),

-- Additional Cash & Billing - Billing Errors
('wav63', 'wam1', 'was2', 'Not scanning all items', 'عدم مسح جميع الأصناف'),
('wav64', 'wam1', 'was2', 'Personal purchase during work', 'شراء شخصي أثناء العمل'),
('wav65', 'wam1', 'was2', 'Unauthorized discount given', 'إعطاء خصم غير مصرح'),
('wav66', 'wam1', 'was2', 'Receipt manipulation', 'التلاعب بالفاتورة'),
('wav67', 'wam1', 'was2', 'Transaction not recorded', 'عملية غير مسجلة'),

-- Additional POS & System - POS Access
('wav68', 'wam2', 'was3', 'Password written down', 'كتابة كلمة السر'),
('wav69', 'wam2', 'was3', 'Unauthorized system access', 'دخول غير مصرح للنظام'),

-- Additional POS & System - POS Operation
('wav70', 'wam2', 'was4', 'System misuse', 'إساءة استخدام النظام'),
('wav71', 'wam2', 'was4', 'Not reporting system error', 'عدم الإبلاغ عن خطأ النظام'),
('wav72', 'wam2', 'was4', 'Printing duplicate receipts', 'طباعة فواتير مكررة'),

-- Additional Merchandising - Shelf Management
('wav73', 'wam3', 'was5', 'Damaged product on shelf', 'منتج تالف على الرف'),
('wav74', 'wam3', 'was5', 'Blocking store aisles', 'سد ممرات المتجر'),
('wav75', 'wam3', 'was5', 'Not rotating stock', 'عدم تدوير المخزون'),
('wav76', 'wam3', 'was5', 'Shelf label mismatch', 'عدم تطابق بطاقة الرف'),
('wav77', 'wam3', 'was5', 'Heavy items on top shelf', 'أصناف ثقيلة على رف عالي'),

-- Additional Pricing - Pricing & Tags
('wav78', 'wam4', 'was6', 'Expired price tag', 'بطاقة سعر منتهية'),
('wav79', 'wam4', 'was6', 'Price tag covered/hidden', 'بطاقة سعر مخفية'),
('wav80', 'wam4', 'was6', 'Not updating price changes', 'عدم تحديث تغييرات الأسعار'),

-- Additional Promotions
('wav81', 'wam5', 'was7', 'Promotion not activated', 'عرض غير مفعل'),
('wav82', 'wam5', 'was7', 'Wrong promotion period', 'فترة عرض خاطئة'),
('wav83', 'wam5', 'was7', 'Promotion sign misplaced', 'لافتة عرض في مكان خاطئ'),

-- Additional Expiry & Inventory - Expiry Control
('wav84', 'wam6', 'was8', 'Expiry date tampered', 'التلاعب بتاريخ الصلاحية'),
('wav85', 'wam6', 'was8', 'Not checking delivery expiry', 'عدم فحص صلاحية البضاعة الواردة'),
('wav86', 'wam6', 'was8', 'Expired samples given', 'إعطاء عينات منتهية'),

-- Additional Expiry & Inventory - Inventory Control
('wav87', 'wam6', 'was9', 'Stock count not done', 'عدم إجراء جرد المخزون'),
('wav88', 'wam6', 'was9', 'Wrong quantity recorded', 'تسجيل كمية خاطئة'),
('wav89', 'wam6', 'was9', 'Not reporting shortage', 'عدم الإبلاغ عن نقص'),
('wav90', 'wam6', 'was9', 'Overstocking perishables', 'تخزين زائد للمواد سريعة التلف'),
('wav91', 'wam6', 'was9', 'Wrong storage location', 'موقع تخزين خاطئ'),

-- Additional Hygiene & Cleaning - Cleaning Duties
('wav92', 'wam7', 'was10', 'Cleaning equipment not stored', 'أدوات التنظيف غير مخزنة'),
('wav93', 'wam7', 'was10', 'Using dirty cleaning tools', 'استخدام أدوات تنظيف متسخة'),
('wav94', 'wam7', 'was10', 'Not displaying wet floor sign', 'عدم وضع علامة أرضية مبللة'),

-- Additional Hygiene & Cleaning - Hygiene Issues
('wav95', 'wam7', 'was11', 'Personal hygiene issue', 'مشكلة نظافة شخصية'),
('wav96', 'wam7', 'was11', 'Eating on sales floor', 'الأكل في أرضية المبيعات'),
('wav97', 'wam7', 'was11', 'Not wearing uniform properly', 'عدم ارتداء الزي بشكل صحيح'),

-- Additional Food Safety - Storage & Temp
('wav98', 'wam8', 'was12', 'Cross-contamination risk', 'خطر التلوث المتبادل'),
('wav99', 'wam8', 'was12', 'Not checking temp logs', 'عدم فحص سجلات الحرارة'),
('wav100', 'wam8', 'was12', 'Frozen product thawed', 'منتج مجمد تم إذابته'),
('wav101', 'wam8', 'was12', 'Food not covered', 'طعام غير مغطى'),

-- Additional Staff Discipline - Attendance
('wav102', 'wam9', 'was13', 'Early leaving', 'المغادرة المبكرة'),
('wav103', 'wam9', 'was13', 'Extended break time', 'تمديد وقت الاستراحة'),
('wav104', 'wam9', 'was13', 'Not clocking in/out', 'عدم تسجيل الحضور والانصراف'),
('wav105', 'wam9', 'was13', 'Frequent absences', 'الغياب المتكرر'),

-- Additional Staff Discipline - Behavior
('wav106', 'wam9', 'was14', 'Arguing with colleagues', 'المجادلة مع الزملاء'),
('wav107', 'wam9', 'was14', 'Not following instructions', 'عدم اتباع التعليمات'),
('wav108', 'wam9', 'was14', 'Insubordination', 'عدم الانصياع للمسؤول'),
('wav109', 'wam9', 'was14', 'Gossiping during work', 'النميمة أثناء العمل'),
('wav110', 'wam9', 'was14', 'Personal calls during work', 'المكالمات الشخصية أثناء العمل'),

-- Additional Customer Service - Service Quality
('wav111', 'wam10', 'was15', 'Not greeting customers', 'عدم الترحيب بالعملاء'),
('wav112', 'wam10', 'was15', 'Ignoring customer query', 'تجاهل استفسار العميل'),
('wav113', 'wam10', 'was15', 'Queue not managed', 'عدم إدارة طابور الانتظار'),
('wav114', 'wam10', 'was15', 'Not helping with bags', 'عدم المساعدة في التعبئة'),

-- Additional Customer Service - Conduct
('wav115', 'wam10', 'was16', 'Arguing with customer', 'المجادلة مع العميل'),
('wav116', 'wam10', 'was16', 'Poor body language', 'لغة جسد سيئة'),
('wav117', 'wam10', 'was16', 'Not smiling', 'عدم الابتسام'),

-- Additional Safety & Security - Safety Violation
('wav118', 'wam11', 'was17', 'Not wearing safety gear', 'عدم ارتداء معدات السلامة'),
('wav119', 'wam11', 'was17', 'Chemical storage violation', 'مخالفة تخزين المواد الكيميائية'),
('wav120', 'wam11', 'was17', 'Fire extinguisher blocked', 'إعاقة طفاية الحريق'),
('wav121', 'wam11', 'was17', 'Emergency exit locked', 'مخرج طوارئ مقفل'),
('wav122', 'wam11', 'was17', 'Not reporting hazard', 'عدم الإبلاغ عن خطر'),
('wav123', 'wam11', 'was17', 'Unsafe ladder use', 'استخدام سلم بطريقة خطرة'),

-- Additional Assets & Ethics - Fraud
('wav124', 'wam12', 'was18', 'Stock manipulation', 'التلاعب بالمخزون'),
('wav125', 'wam12', 'was18', 'Data falsification', 'تزوير البيانات'),
('wav126', 'wam12', 'was18', 'Unauthorized removal', 'إخراج غير مصرح'),

-- Additional Assets & Ethics - Ethics
('wav127', 'wam12', 'was19', 'Conflict of interest', 'تضارب المصالح'),
('wav128', 'wam12', 'was19', 'Accepting bribes/gifts', 'قبول رشاوى أو هدايا'),
('wav129', 'wam12', 'was19', 'Disclosing confidential info', 'إفشاء معلومات سرية'),
('wav130', 'wam12', 'was19', 'Social media misuse', 'إساءة استخدام وسائل التواصل'),

-- Fresh Produce Operations
('wav131', 'wam3', 'was20', 'Bruised produce on display', 'خضار وفواكه تالفة في العرض'),
('wav132', 'wam3', 'was20', 'Not misting produce', 'عدم رش الخضار بالماء'),
('wav133', 'wam3', 'was20', 'Mixing old & new produce', 'خلط خضار قديم مع جديد'),
('wav134', 'wam3', 'was20', 'Produce not sorted by grade', 'عدم فرز الخضار حسب الجودة'),
('wav135', 'wam3', 'was20', 'Rotten produce not removed', 'عدم إزالة الخضار الفاسد'),
('wav136', 'wam3', 'was20', 'Not trimming vegetables', 'عدم تقليم الخضروات'),
('wav137', 'wam3', 'was20', 'Produce scale not calibrated', 'ميزان الخضار غير معاير'),
('wav138', 'wam3', 'was20', 'Organic mixed with regular', 'خلط العضوي مع العادي'),

-- Bakery Operations
('wav139', 'wam3', 'was21', 'Stale bread on shelf', 'خبز قديم على الرف'),
('wav140', 'wam3', 'was21', 'Not wearing hair net', 'عدم ارتداء غطاء الشعر'),
('wav141', 'wam3', 'was21', 'Not wearing gloves', 'عدم ارتداء القفازات'),
('wav142', 'wam3', 'was21', 'Bakery display case dirty', 'واجهة المخبز متسخة'),
('wav143', 'wam3', 'was21', 'Wrong baking temperature', 'درجة خبز خاطئة'),
('wav144', 'wam3', 'was21', 'Not labeling bake time', 'عدم تسمية وقت الخبز'),
('wav145', 'wam3', 'was21', 'Bakery tools not sanitized', 'أدوات المخبز غير معقمة'),
('wav146', 'wam3', 'was21', 'Day-old not marked down', 'المخبوزات القديمة غير مخفضة'),

-- Deli & Meat Counter Operations
('wav147', 'wam3', 'was22', 'Meat not at proper temp', 'اللحوم ليست بالحرارة الصحيحة'),
('wav148', 'wam3', 'was22', 'Cross-contamination risk', 'خطر التلوث المتبادل'),
('wav149', 'wam3', 'was22', 'Slicer not cleaned', 'ماكينة التقطيع غير نظيفة'),
('wav150', 'wam3', 'was22', 'Not changing cutting boards', 'عدم تغيير ألواح التقطيع'),
('wav151', 'wam3', 'was22', 'Meat packaging leaking', 'تسرب من تغليف اللحوم'),
('wav152', 'wam3', 'was22', 'Wrong meat weight', 'وزن لحم خاطئ'),
('wav153', 'wam3', 'was22', 'Deli case not covered', 'واجهة اللحوم غير مغطاة'),
('wav154', 'wam3', 'was22', 'Using expired deli products', 'استخدام منتجات منتهية'),

-- Cold Chain Management
('wav155', 'wam8', 'was23', 'Freezer left open too long', 'الفريزر مفتوح مدة طويلة'),
('wav156', 'wam8', 'was23', 'Cold items left on trolley', 'أصناف باردة متروكة على العربة'),
('wav157', 'wam8', 'was23', 'Not monitoring temp hourly', 'عدم مراقبة الحرارة كل ساعة'),
('wav158', 'wam8', 'was23', 'Temp alarm ignored', 'تجاهل إنذار الحرارة'),
('wav159', 'wam8', 'was23', 'Broken cold chain', 'كسر سلسلة التبريد'),
('wav160', 'wam8', 'was23', 'Chiller overcrowded', 'الثلاجة مكتظة'),
('wav161', 'wam8', 'was23', 'Ice cream melted & refrozen', 'آيس كريم ذاب وأعيد تجميده'),

-- Store Operations
('wav162', 'wam10', 'was24', 'Store not opened on time', 'عدم فتح المتجر في الوقت'),
('wav163', 'wam10', 'was24', 'Shopping carts not collected', 'عربات التسوق غير مجمعة'),
('wav164', 'wam10', 'was24', 'Damaged cart in use', 'عربة تالفة قيد الاستخدام'),
('wav165', 'wam10', 'was24', 'Entrance mat not cleaned', 'مدخل المتجر غير نظيف'),
('wav166', 'wam10', 'was24', 'Music volume too high/low', 'صوت الموسيقى مرتفع/منخفض'),
('wav167', 'wam10', 'was24', 'AC not working', 'التكييف لا يعمل'),
('wav168', 'wam10', 'was24', 'Lights not working', 'الإضاءة لا تعمل'),
('wav169', 'wam10', 'was24', 'Store closing delay', 'تأخير إغلاق المتجر'),
('wav170', 'wam10', 'was24', 'Not announcing closing time', 'عدم الإعلان عن وقت الإغلاق'),

-- Receiving & Delivery Operations
('wav171', 'wam6', 'was25', 'Not checking delivery quantity', 'عدم فحص كمية التوصيل'),
('wav172', 'wam6', 'was25', 'Accepting damaged goods', 'قبول بضاعة تالفة'),
('wav173', 'wam6', 'was25', 'Not verifying invoice', 'عدم التحقق من الفاتورة'),
('wav174', 'wam6', 'was25', 'Delivery left unattended', 'ترك التوصيل بدون مراقبة'),
('wav175', 'wam6', 'was25', 'Wrong storage after receiving', 'تخزين خاطئ بعد الاستلام'),
('wav176', 'wam6', 'was25', 'Not checking temp on arrival', 'عدم فحص الحرارة عند الوصول'),
('wav177', 'wam6', 'was25', 'Loading bay not secured', 'منطقة التحميل غير مؤمنة'),

-- Returns & Exchanges Operations
('wav178', 'wam10', 'was26', 'Accepting return without receipt', 'قبول مرتجع بدون فاتورة'),
('wav179', 'wam10', 'was26', 'Not inspecting returned item', 'عدم فحص الصنف المرتجع'),
('wav180', 'wam10', 'was26', 'Returning to shelf without check', 'إرجاع للرف بدون فحص'),
('wav181', 'wam10', 'was26', 'Wrong refund amount', 'مبلغ استرجاع خاطئ'),
('wav182', 'wam10', 'was26', 'Return policy not followed', 'عدم اتباع سياسة الاسترجاع'),

-- Loss Prevention
('wav183', 'wam11', 'was27', 'Not checking bags at exit', 'عدم فحص الأكياس عند الخروج'),
('wav184', 'wam11', 'was27', 'Ignoring alarm activation', 'تجاهل تفعيل الإنذار'),
('wav185', 'wam11', 'was27', 'Not tagging high-value items', 'عدم وضع شريحة أمنية'),
('wav186', 'wam11', 'was27', 'Blind spots not monitored', 'عدم مراقبة النقاط العمياء'),
('wav187', 'wam11', 'was27', 'CCTV not checked', 'عدم فحص الكاميرات'),
('wav188', 'wam11', 'was27', 'Unattended high-risk area', 'منطقة عالية الخطورة بدون مراقبة'),

-- Waste Management
('wav189', 'wam7', 'was28', 'Recyclables not separated', 'عدم فصل المواد القابلة للتدوير'),
('wav190', 'wam7', 'was28', 'Cardboard not broken down', 'الكرتون غير مفكك'),
('wav191', 'wam7', 'was28', 'Dumpster overflowing', 'حاوية النفايات ممتلئة'),
('wav192', 'wam7', 'was28', 'Food waste not sealed', 'نفايات الطعام غير مغلقة'),
('wav193', 'wam7', 'was28', 'Expired items mixed with trash', 'منتجات منتهية مخلوطة بالنفايات'),

-- Staff Area Management
('wav194', 'wam9', 'was29', 'Break room messy', 'غرفة الاستراحة غير منظمة'),
('wav195', 'wam9', 'was29', 'Personal items on sales floor', 'أغراض شخصية في أرضية المبيعات'),
('wav196', 'wam9', 'was29', 'Locker not locked', 'خزانة الموظف غير مقفلة'),
('wav197', 'wam9', 'was29', 'Eating in storage area', 'الأكل في منطقة التخزين'),
('wav198', 'wam9', 'was29', 'Staff door left open', 'باب الموظفين مفتوح'),

-- Display & Signage
('wav199', 'wam3', 'was30', 'Shelf talker missing', 'بطاقة الرف مفقودة'),
('wav200', 'wam3', 'was30', 'Promotional banner damaged', 'لافتة ترويجية تالفة'),
('wav201', 'wam3', 'was30', 'Signage not in both languages', 'لافتة ليست بلغتين'),
('wav202', 'wam3', 'was30', 'End cap not utilized', 'عدم استخدام نهاية الرف'),
('wav203', 'wam3', 'was30', 'Display stand broken', 'حامل العرض مكسور'),
('wav204', 'wam3', 'was30', 'Nutrition info not displayed', 'معلومات غذائية غير معروضة'),

-- Additional Specific Supermarket Issues
('wav205', 'wam1', 'was2', 'Age-restricted sale without ID', 'بيع للقصر بدون تحقق'),
('wav206', 'wam3', 'was5', 'Not facing products forward', 'عدم توجيه المنتجات للأمام'),
('wav207', 'wam6', 'was8', 'Baby food expired', 'طعام أطفال منتهي'),
('wav208', 'wam7', 'was10', 'Spill station not stocked', 'محطة التنظيف غير مجهزة'),
('wav209', 'wam8', 'was12', 'Hot food not at temp', 'طعام ساخن ليس بالحرارة الصحيحة'),

-- Additional Assets & Ethics - Fraud
('wav124', 'wam12', 'was18', 'Stock manipulation', 'التلاعب بالمخزون'),
('wav125', 'wam12', 'was18', 'Data falsification', 'تزوير البيانات'),
('wav126', 'wam12', 'was18', 'Unauthorized removal', 'إخراج غير مصرح'),

-- Additional Assets & Ethics - Ethics
('wav127', 'wam12', 'was19', 'Conflict of interest', 'تضارب المصالح'),
('wav128', 'wam12', 'was19', 'Accepting bribes/gifts', 'قبول رشاوى أو هدايا'),
('wav129', 'wam12', 'was19', 'Disclosing confidential info', 'إفشاء معلومات سرية'),
('wav130', 'wam12', 'was19', 'Social media misuse', 'إساءة استخدام وسائل التواصل')
ON CONFLICT (id) DO NOTHING;
