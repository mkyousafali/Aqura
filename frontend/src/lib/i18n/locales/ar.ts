import type { LocaleData } from '../types';

export const arabicLocale: LocaleData = {
	code: 'ar',
	name: 'العربية',
	nativeName: 'العربية',
	direction: 'rtl',
	dateFormat: 'dd/MM/yyyy',
	timeFormat: 'HH:mm',
	currencyFormat: '#,##0.00 ر.س',
	numberFormat: {
		style: 'decimal',
		minimumFractionDigits: 0,
		maximumFractionDigits: 2
	},
	pluralRules: [
		{ count: 0, form: 'zero' },
		{ count: 1, form: 'one' },
		{ count: 2, form: 'two' },
		{ count: 'other', form: 'other' }
	],
	translations: {
		// App General
		app: {
			name: 'نظام إدارة أكوا',
			shortName: 'أكوا',
			description: 'نظام إدارة مدعوم بالذكاء الاصطناعي',
			loading: 'جاري تحميل أكوا...',
			offline: 'أنت غير متصل حالياً',
			updateAvailable: 'إصدار جديد متوفر',
			updateReady: 'التحديث جاهز للتثبيت',
			updateNow: 'تحديث الآن',
			updateLater: 'لاحقاً'
		},

		// Navigation & UI
		nav: {
			dashboard: 'لوحة التحكم',
			admin: 'الإدارة',
			user: 'واجهة المستخدم',
			settings: 'الإعدادات',
			help: 'المساعدة',
			logout: 'تسجيل الخروج'
		},

		// Window Management
		window: {
			minimize: 'تصغير',
			maximize: 'تكبير',
			restore: 'استعادة',
			close: 'إغلاق',
			duplicate: 'نسخ',
			detach: 'فصل',
			newWindow: 'نافذة جديدة',
			activeWindows: 'النوافذ النشطة',
			noWindows: 'لا توجد نوافذ مفتوحة'
		},

		// Authentication
		auth: {
			signIn: 'تسجيل الدخول',
			signOut: 'تسجيل الخروج',
			signUp: 'إنشاء حساب',
			email: 'البريد الإلكتروني',
			password: 'كلمة المرور',
			confirmPassword: 'تأكيد كلمة المرور',
			forgotPassword: 'نسيت كلمة المرور؟',
			resetPassword: 'إعادة تعيين كلمة المرور',
			rememberMe: 'تذكرني',
			invalidCredentials: 'البريد الإلكتروني أو كلمة المرور غير صحيحة',
			accountLocked: 'الحساب مقفل',
			mfaRequired: 'مطلوب تفعيل المصادقة الثنائية',
			mfaCode: 'رمز التحقق',
			changePassword: 'تغيير كلمة المرور',
			newPassword: 'كلمة المرور الجديدة',
			currentPassword: 'كلمة المرور الحالية',
			passwordChanged: 'تم تغيير كلمة المرور بنجاح',
			mustChangePassword: 'يجب تغيير كلمة المرور قبل المتابعة'
		},

		// Admin Modules
		admin: {
			title: 'الإدارة',
			hrMaster: 'إدارة الموارد البشرية',
			branchesMaster: 'إدارة الفروع',
			taskMaster: 'إدارة المهام',
			vendorsMaster: 'إدارة الموردين',
			invoiceMaster: 'إدارة الفواتير',
			userRoles: 'أدوار المستخدمين',
			hierarchyMaster: 'الهيكل التنظيمي',
			userManagement: 'إدارة المستخدمين',
			importData: 'استيراد البيانات',
			auditLog: 'سجل المراجعة'
		},

		// Welcome
		welcome: {
			title: 'مرحباً بك في أكوارا',
			subtitle: 'منصة إدارة متطورة مع واجهة نوافذ متعددة',
			features: {
				multiWindow: 'واجهة نوافذ متعددة لزيادة الإنتاجية',
				offline: 'إمكانيات العمل دون اتصال للعمل السلس',
				responsive: 'تصميم متجاوب يتكيف مع أي جهاز',
				bilingual: 'دعم كامل ثنائي اللغة للإنجليزية والعربية'
			},
			instructions: 'ابدأ باستكشاف الميزات أعلاه أو انغمس في وحدات الإدارة'
		},

		// HR Master
		hr: {
			employee: 'موظف',
			employees: 'الموظفون',
			employeeId: 'رقم الموظف',
			firstName: 'الاسم الأول',
			lastName: 'اسم العائلة',
			fullName: 'الاسم الكامل',
			email: 'البريد الإلكتروني',
			phone: 'الهاتف',
			department: 'القسم',
			designation: 'المسمى الوظيفي',
			status: 'الحالة',
			branch: 'الفرع',
			manager: 'المدير',
			joinDate: 'تاريخ الانضمام',
			active: 'نشط',
			inactive: 'غير نشط',
			pending: 'في الانتظار'
		},

		// Branches Master
		branches: {
			branch: 'فرع',
			branches: 'الفروع',
			branchId: 'رقم الفرع',
			branchName: 'اسم الفرع',
			branchCode: 'كود الفرع',
			region: 'المنطقة',
			address: 'العنوان',
			timezone: 'المنطقة الزمنية',
			contactPerson: 'جهة الاتصال',
			contactEmail: 'بريد الاتصال',
			contactPhone: 'هاتف الاتصال',
			// New fields for multilingual support
			createBranch: 'إنشاء فرع',
			nameEnglish: 'الاسم (إنجليزي)',
			nameArabic: 'الاسم (عربي)',
			locationEnglish: 'الموقع (إنجليزي)',
			locationArabic: 'الموقع (عربي)',
			save: 'حفظ',
			cancel: 'إلغاء',
			edit: 'تعديل',
			update: 'تحديث',
			delete: 'حذف',
			active: 'نشط',
			inactive: 'غير نشط',
			mainBranch: 'الفرع الرئيسي',
			createdAt: 'تاريخ الإنشاء',
			updatedAt: 'تاريخ التحديث',
			actions: 'الإجراءات'
		},

		// Vendors Master
		vendors: {
			vendor: 'مورد',
			vendors: 'الموردون',
			vendorId: 'رقم المورد',
			vendorName: 'اسم المورد',
			taxId: 'الرقم الضريبي',
			contactPerson: 'جهة الاتصال',
			email: 'البريد الإلكتروني',
			phone: 'الهاتف',
			address: 'العنوان',
			paymentTerms: 'شروط الدفع',
			category: 'الفئة'
		},

		// Invoice Master
		invoices: {
			invoice: 'فاتورة',
			invoices: 'الفواتير',
			invoiceNo: 'رقم الفاتورة',
			vendor: 'المورد',
			branch: 'الفرع',
			date: 'تاريخ الفاتورة',
			dueDate: 'تاريخ الاستحقاق',
			currency: 'العملة',
			subtotal: 'المجموع الفرعي',
			tax: 'الضريبة',
			total: 'المجموع الكلي',
			status: 'الحالة',
			draft: 'مسودة',
			posted: 'مرسلة',
			paid: 'مدفوعة',
			attachments: 'المرفقات'
		},

		// Import System
		import: {
			title: 'استيراد البيانات',
			uploadFile: 'رفع ملف',
			selectFile: 'اختر ملف Excel',
			dragDrop: 'اسحب وأفلت ملفك هنا',
			processing: 'جاري المعالجة...',
			mapping: 'ربط الأعمدة',
			preview: 'معاينة البيانات',
			validation: 'نتائج التحقق',
			errors: 'أخطاء',
			warnings: 'تحذيرات',
			valid: 'سجلات صحيحة',
			invalid: 'سجلات غير صحيحة',
			commitChanges: 'تطبيق التغييرات',
			rollback: 'التراجع',
			importComplete: 'تم الاستيراد بنجاح',
			importFailed: 'فشل الاستيراد',
			recordsProcessed: 'سجل تمت معالجته',
			recordsCommitted: 'سجل تم تطبيقه',
			recordsFailed: 'سجل فشل'
		},

		// Common Actions
		actions: {
			add: 'إضافة',
			edit: 'تعديل',
			delete: 'حذف',
			save: 'حفظ',
			cancel: 'إلغاء',
			confirm: 'تأكيد',
			yes: 'نعم',
			no: 'لا',
			ok: 'موافق',
			apply: 'تطبيق',
			reset: 'إعادة تعيين',
			clear: 'مسح',
			search: 'بحث',
			filter: 'تصفية',
			sort: 'ترتيب',
			export: 'تصدير',
			import: 'استيراد',
			upload: 'رفع',
			download: 'تنزيل',
			print: 'طباعة',
			refresh: 'تحديث',
			back: 'رجوع',
			next: 'التالي',
			previous: 'السابق',
			continue: 'متابعة',
			finish: 'إنهاء'
		},

		// Common Messages
		common: {
			confirmDelete: 'هل أنت متأكد من حذف هذا العنصر؟',
			noData: 'لا توجد بيانات',
			status: 'الحالة',
			loading: 'جاري التحميل...',
			error: 'حدث خطأ'
		},

		// Status Messages
		status: {
			success: 'نجح',
			error: 'خطأ',
			warning: 'تحذير',
			info: 'معلومات',
			loading: 'جاري التحميل...',
			saving: 'جاري الحفظ...',
			processing: 'جاري المعالجة...',
			complete: 'مكتمل',
			failed: 'فشل',
			cancelled: 'ملغي',
			pending: 'في الانتظار'
		},

		// Validation Messages
		validation: {
			required: 'هذا الحقل مطلوب',
			email: 'يرجى إدخال بريد إلكتروني صحيح',
			phone: 'يرجى إدخال رقم هاتف صحيح',
			minLength: 'الحد الأدنى {min} أحرف',
			maxLength: 'الحد الأقصى {max} حرف',
			numeric: 'يرجى إدخال رقم صحيح',
			date: 'يرجى إدخال تاريخ صحيح',
			passwordMismatch: 'كلمات المرور غير متطابقة',
			weakPassword: 'كلمة المرور ضعيفة',
			invalidFormat: 'تنسيق غير صحيح',
			duplicateValue: 'هذه القيمة موجودة بالفعل',
			invalidRange: 'القيمة يجب أن تكون بين {min} و {max}'
		},

		// Empty States
		empty: {
			noData: 'لا توجد بيانات متوفرة',
			noResults: 'لم يتم العثور على نتائج',
			noFiles: 'لم يتم رفع ملفات',
			noWindows: 'لا توجد نوافذ مفتوحة',
			noNotifications: 'لا توجد إشعارات',
			noHistory: 'لا يوجد تاريخ متوفر',
			tryAgain: 'حاول مرة أخرى',
			getStarted: 'ابدأ بإضافة العنصر الأول'
		}
	}
};
