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
			name: 'نظام إدارة أكورا',
			shortName: 'أكورا',
			description: 'نظام إدارة مدعوم بالذكاء الاصطناعي',
			loading: 'جاري تحميل أكورا...',
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
			logout: 'تسجيل الخروج',
			language: 'اللغة',
			languageToggle: 'تبديل اللغة',
			english: 'English',
			arabic: 'العربية',
			goBack: 'العودة',
			goToDashboard: 'الذهاب إلى لوحة التحكم',
			viewNotifications: 'عرض الإشعارات',
			refreshNotifications: 'تحديث الإشعارات'
		},

		// Mobile page titles
		mobile: {
			dashboard: 'لوحة التحكم',
			tasks: 'المهام',
			notifications: 'الإشعارات',
			assignments: 'التكليفات',
			quickTask: 'مهمة سريعة',
			assignTasks: 'تعيين المهام',
			createTask: 'إنشاء مهمة',
			completeTask: 'إكمال المهمة',
			taskDetails: 'تفاصيل المهمة',
			notification: 'إشعار',
			createNotification: 'إنشاء إشعار',
			assignmentDetails: 'تفاصيل التكليف',
			// Bottom navigation
			bottomNav: {
				tasks: 'المهام',
				create: 'تعيين',
				assignments: 'التكليفات'
			},
			// Error messages
			error: {
				accessRequired: 'مطلوب تسجيل الدخول',
				loginRequired: 'يرجى تسجيل الدخول للوصول إلى واجهة الجوال.',
				goToLogin: 'الذهاب إلى تسجيل دخول الجوال'
			},
			// Mobile login
			login: {
				title: 'الوصول للجوال',
				subtitle: 'وصول سريع إلى لوحة تحكم الجوال',
				accessCode: 'رمز الوصول',
				accessCodePlaceholder: 'أدخل رمز الوصول المكون من 6 أرقام',
				accessButton: 'دخول',
				accessingSystem: 'جاري الوصول للنظام...',
				invalidCode: 'رمز وصول غير صحيح',
				codeRequired: 'رمز الوصول مطلوب',
				enterCode: 'يرجى إدخال رمز الوصول',
				quickAccess: 'بوابة الوصول السريع',
				secureLogin: 'تسجيل دخول آمن للجوال',
				footer: 'وصول آمن لواجهة أكوا للجوال',
				accessDenied: 'تم رفض الوصول',
				accessGranted: 'تم منح الوصول'
			},
			// Dashboard content
			dashboardContent: {
				stats: {
					pendingTasks: 'المهام المعلقة',
					completed: 'مكتمل',
					notifications: 'الإشعارات',
					totalTasks: 'إجمالي المهام'
				},
				recentNotifications: {
					title: 'الإشعارات الأخيرة',
					allInSystem: 'جميع الإشعارات في النظام',
					yourRecent: 'إشعاراتك الأخيرة',
					noNotifications: 'لا توجد إشعارات حديثة'
				},
				actions: {
					createNotification: 'إنشاء إشعار',
					download: 'تحميل',
					source: 'المصدر'
				},
				labels: {
					sentBy: 'أرسل بواسطة:',
					sentTo: 'أرسل إلى:',
					attachments: 'المرفقات',
					system: 'النظام',
					from: 'من:'
				}
			},
			// Tasks page content
			tasksContent: {
				title: 'مهامي - أكورا موبايل',
				createTask: 'إنشاء مهمة',
				searchPlaceholder: 'البحث في المهام...',
				filters: {
					allStatus: 'جميع الحالات',
					pending: 'في الانتظار',
					inProgress: 'قيد التنفيذ',
					completed: 'مكتملة',
					cancelled: 'ملغية',
					allPriority: 'جميع الأولويات',
					high: 'عالية',
					medium: 'متوسطة',
					low: 'منخفضة'
				},
				results: {
					tasksFound: 'مهمة موجودة',
					taskFound: 'مهمة موجودة'
				},
				loading: 'تحميل المهام...',
				emptyState: {
					title: 'لم يتم العثور على مهام',
					description: 'لا توجد مهام تطابق المرشحات الحالية، أو ليس لديك أي مهام مخصصة بعد.'
				},
				taskCard: {
					quickTask: 'مهمة سريعة',
					by: 'بواسطة',
					assigned: 'مخصصة',
					unknown: 'غير معروف',
					attachment: 'مرفق',
					attachments: 'مرفقات',
					download: 'تحميل',
					downloadAll: 'تحميل الكل',
					markComplete: 'تمييز كمكتملة',
					viewDetails: 'عرض التفاصيل'
				}
			},
			// Task assignment page content
			assignContent: {
				title: 'تخصيص المهام - أكورا موبايل',
				loading: 'تحميل البيانات...',
				createTaskTemplate: 'إنشاء قالب مهمة',
				createNotification: 'إنشاء إشعار',
				steps: {
					users: 'المستخدمين',
					tasks: 'المهام',
					settings: 'الإعدادات',
					criteria: 'المعايير'
				},
				step1: {
					title: 'اختيار المستخدمين',
					description: 'اختر المستخدمين لتخصيص المهام لهم',
					searchPlaceholder: 'البحث بالاسم أو اسم المستخدم أو البريد الإلكتروني...',
					allBranches: 'جميع الفروع'
				},
				step2: {
					title: 'اختيار المهام',
					description: 'اختر المهام المراد تخصيصها',
					searchPlaceholder: 'البحث في المهام...',
					noDescription: 'لا يوجد وصف'
				},
				step3: {
					title: 'إعدادات التخصيص',
					description: 'تكوين خيارات التخصيص',
					notificationSettings: 'إعدادات التنبيهات',
					sendNotifications: 'إرسال تنبيهات للمخصص لهم',
					assignmentType: 'نوع التخصيص',
					oneTimeAssignment: 'تخصيص لمرة واحدة',
					recurringAssignment: 'تخصيص متكرر',
					deadlineSettings: 'إعدادات الموعد النهائي',
					setDeadline: 'تحديد موعد نهائي للتخصيص',
					deadlineDate: 'تاريخ الموعد النهائي',
					deadlineTime: 'وقت الموعد النهائي',
					allowReassign: 'السماح للمستخدمين بإعادة تخصيص المهام',
					notifyAssignees: 'إشعار المخصص لهم',
					additionalNotes: 'ملاحظات إضافية',
					specialInstructions: 'أضف أي تعليمات خاصة...',
					// Repeat Settings
					repeatSettings: 'إعدادات التكرار',
					repeatType: 'نوع التكرار',
					selectDays: 'اختر الأيام',
					repeatEvery: 'كرر كل',
					daily: 'يومي',
					weekly: 'أسبوعي',
					weeklySpecific: 'أسبوعي (أيام محددة)',
					monthly: 'شهري',
					monthlySpecific: 'شهري (تاريخ محدد)',
					everyNDays: 'كل عدة أيام',
					everyNWeeks: 'كل عدة أسابيع',
					// Days of the week
					monday: 'الإثنين',
					tuesday: 'الثلاثاء',
					wednesday: 'الأربعاء',
					thursday: 'الخميس',
					friday: 'الجمعة',
					saturday: 'السبت',
					sunday: 'الأحد',
					// Day abbreviations
					mon: 'إثن',
					tue: 'ثلا',
					wed: 'أرب',
					thu: 'خمي',
					fri: 'جمع',
					sat: 'سبت',
					sun: 'أحد',
					priorityOverride: 'تجاوز الأولوية',
					defaultPriority: 'استخدام أولوية المهمة الافتراضية',
					high: 'عالية',
					medium: 'متوسطة',
					low: 'منخفضة',
					additionalOptions: 'خيارات إضافية',
					enableReassigning: 'تمكين إعادة التخصيص في حالة عدم توفر المستخدم',
					addNote: 'إضافة ملاحظة للمخصص لهم'
				},
				step4: {
					title: 'معايير التخصيص',
					description: 'تحديد متطلبات الإكمال',
					completionRequirements: 'متطلبات الإكمال',
					requireTaskFinished: 'يجب تمييز المهمة كمنتهية',
					requirePhotoUpload: 'مطلوب تحميل صورة للإكمال',
					requireErpReference: 'مطلوب مرجع ERP',
					assignmentSummary: 'ملخص التخصيص',
					usersLabel: 'المستخدمون:',
					tasksLabel: 'المهام:',
					typeLabel: 'النوع:',
					deadlineLabel: 'الموعد النهائي:',
					oneTimeType: 'مرة واحدة',
					recurringType: 'متكرر',
					selectedUsers: 'مستخدم محدد',
					selectedTasks: 'مهمة محددة'
				},
				actions: {
					cancel: 'إلغاء',
					previous: 'السابق',
					nextStep: 'الخطوة التالية',
					assignTasks: 'تخصيص المهام',
					assigning: 'جاري التخصيص...'
				},
				// Priority and Status translations
				priorities: {
					high: 'عالية',
					medium: 'متوسطة',
					low: 'منخفضة'
				},
				statuses: {
					draft: 'مسودة',
					active: 'نشط',
					paused: 'متوقف',
					completed: 'مكتمل',
					cancelled: 'ملغي'
				}
			},

			// Create Task Content
			createContent: {
				title: 'إنشاء مهمة - أكورا موبايل',
				taskTitle: 'عنوان المهمة',
				taskTitleRequired: 'عنوان المهمة مطلوب',
				taskTitlePlaceholder: 'أدخل عنوان المهمة',
				description: 'الوصف',
				descriptionRequired: 'الوصف مطلوب',
				descriptionPlaceholder: 'وصف المهمة',
				attachments: 'المرفقات',
				camera: 'الكاميرا',
				uploadFile: 'تحميل ملف (اختياري)',
				chooseFiles: 'اختر الملفات أو اسحبها هنا',
				supportedFormats: 'المدعوم: images/pdf, doc, docx, xls, xlsx, txt, ppt • حد أقصى: 10MB',
				actions: {
					cancel: 'إلغاء',
					createTask: 'إنشاء مهمة',
					creating: 'جاري الإنشاء...'
				},
				errors: {
					titleRequired: 'عنوان المهمة مطلوب',
					descriptionRequired: 'الوصف مطلوب',
					createFailed: 'فشل في إنشاء المهمة',
					fillRequired: 'يرجى ملء جميع الحقول المطلوبة',
					fixFormErrors: 'يرجى إصلاح أخطاء النموذج قبل الإرسال.',
					createFailedTryAgain: 'فشل في إنشاء المهمة. يرجى المحاولة مرة أخرى.'
				},
				success: {
					taskCreated: 'تم إنشاء المهمة بنجاح!'
				}
			},

			// Quick Task Content
			quickTaskContent: {
				title: 'مهمة سريعة - أكورا موبايل',
				loading: 'جارِ التحميل...',
				// Steps
				step1: {
					title: '1. اختيار الفرع',
					branchLabel: 'الفرع:',
					selectBranch: '-- اختر الفرع --',
					defaultBadge: 'افتراضي',
					change: 'تغيير',
					confirm: '✓ تأكيد',
					setAsDefault: 'تعيين كفرع افتراضي'
				},
				step2: {
					title: '2. اختيار المستخدمين',
					usersLabel: 'المستخدمون:',
					selected: 'محدد',
					change: 'تغيير',
					searchPlaceholder: 'البحث عن المستخدمين...',
					more: 'المزيد',
					setAsDefault: 'حفظ هؤلاء المستخدمين كافتراضي',
					confirmUsers: '✓ تأكيد المستخدمين'
				},
				step3: {
					title: '3. تفاصيل المهمة',
					issueType: 'نوع المشكلة:',
					selectIssueType: '-- اختر نوع المشكلة --',
					customIssueType: 'نوع مشكلة مخصص:',
					customIssuePlaceholder: 'أدخل نوع المشكلة المخصص',
					priority: 'الأولوية:',
					description: 'الوصف (اختياري):',
					descriptionPlaceholder: 'أدخل وصف المهمة...',
					saveAsDefault: 'حفظ هذه الإعدادات كافتراضية'
				},
				step4: {
					title: '4. المرفقات (اختياري)',
					chooseFiles: 'اختيار الملفات',
					camera: 'الكاميرا',
					removeFile: 'إزالة الملف'
				},
				step5: {
					title: '5. متطلبات الإكمال',
					requirePhoto: 'مطلوب تحميل صورة عند الإكمال',
					requireErp: 'مطلوب مرجع ERP عند الإكمال',
					requireFile: 'مطلوب تحميل ملف عند الإكمال'
				},
				// Issue Types
				issueTypes: {
					priceTag: 'مشكلة البطاقة السعرية',
					cleaning: 'مشكلة تنظيف',
					display: 'مشكلة عرض',
					filling: 'مشكلة تعبئة',
					maintenance: 'مشكلة صيانة',
					other: 'مشكلة أخرى'
				},
				// Priority Options
				priorities: {
					low: 'منخفضة',
					medium: 'متوسطة',
					high: 'عالية',
					urgent: 'عاجلة'
				},
				// Price Tag Options
				priceTags: {
					low: 'منخفض',
					medium: 'متوسط',
					high: 'عالي',
					critical: 'حرج'
				},
				// Actions
				actions: {
					assignTask: 'تخصيص المهمة',
					creatingTask: 'جاري إنشاء المهمة...'
				},
				// Success Messages
				success: {
					taskCreated: 'تم إنشاء المهمة بنجاح!'
				}
			},

			// Assignments Content
			assignmentsContent: {
				title: 'مهامي - موبايل أكوا',
				loading: 'جاري تحميل المهام...',
				// Statistics
				stats: {
					total: 'الإجمالي',
					completed: 'مكتملة',
					inProgress: 'قيد التنفيذ',
					pending: 'معلقة',
					overdue: 'متأخرة'
				},
				// Search and Filters
				search: {
					placeholder: 'البحث في المهام أو المستخدمين...',
					allStatuses: 'جميع الحالات',
					allPriorities: 'جميع الأولويات',
					clearFilters: 'مسح المرشحات'
				},
				// Statuses
				statuses: {
					assigned: 'مُعيَّنة',
					inProgress: 'قيد التنفيذ',
					completed: 'مكتملة',
					cancelled: 'ملغية',
					escalated: 'مُصعَّدة',
					reassigned: 'مُعادة التعيين',
					unknown: 'غير معروف'
				},
				// Priorities
				priorities: {
					high: 'عالية',
					medium: 'متوسطة',
					low: 'منخفضة',
					urgent: 'عاجلة'
				},
				// Task Details
				taskDetails: {
					unknownTask: 'مهمة غير معروفة',
					quickTask: '⚡ مهمة سريعة',
					quickBadge: '⚡ سريع',
					overdue: '⚠️ متأخر',
					description: 'الوصف:',
					notes: 'الملاحظات:',
					attachments: '📎 المرفقات',
					deadline: 'الموعد النهائي:',
					noDeadline: 'لا يوجد موعد نهائي',
					assignedTo: 'مُعيَّن إلى:',
					createdBy: 'أنشأها:',
					branch: 'الفرع:',
					priceTag: 'علامة السعر:',
					issueType: 'نوع المشكلة:',
					status: 'الحالة:'
				},
				// Actions
				actions: {
					download: 'تحميل',
					viewDetails: 'عرض التفاصيل',
					markComplete: 'تمييز كمكتمل',
					updateStatus: 'تحديث الحالة'
				},
				// Empty States
				emptyStates: {
					noAssignments: 'لم يتم العثور على مهام',
					noAssignmentsYet: 'لم تقم بتعيين أي مهام بعد.',
					noMatchingFilters: 'لا توجد مهام تطابق المرشحات الحالية.'
				},
				// Footer
				footer: {
					showing: 'عرض',
					of: 'من',
					completionRate: 'معدل الإنجاز:'
				}
			},

			// Create Notification Content
			createNotificationContent: {
				basicInformation: 'المعلومات الأساسية',
				title: 'العنوان',
				titlePlaceholder: 'ادخل عنوان الإشعار',
				message: 'الرسالة',
				messagePlaceholder: 'ادخل رسالة الإشعار',
				type: 'النوع',
				priority: 'الأولوية',
				targetAudience: 'الجمهور المستهدف',
				sendTo: 'إرسال إلى',
				allUsers: 'جميع المستخدمين',
				specificUsers: 'مستخدمين محددين',
				searchPlaceholder: 'البحث عن المستخدمين...',
				selectAll: 'تحديد الكل',
				deselectAll: 'إلغاء تحديد الكل',
				userSelected: 'مستخدم محدد',
				loadingUsers: 'تحميل المستخدمين...',
				noUsers: 'لم يتم العثور على مستخدمين',
				attachments: 'المرفقات (اختيارية)',
				reset: 'إعادة تعيين',
				publish: 'نشر الإشعار',
				publishing: 'جاري النشر...',
				success: 'تم نشر الإشعار بنجاح!',
				errors: {
					titleRequired: 'يرجى إدخال عنوان الإشعار',
					messageRequired: 'يرجى إدخال رسالة الإشعار',
					usersRequired: 'يرجى تحديد مستخدم واحد على الأقل للاستهداف المحدد',
					uploadFailed: 'فشل في تحميل الملف'
				},
				types: {
					info: 'معلومات',
					success: 'نجاح',
					warning: 'تحذير',
					error: 'خطأ',
					announcement: 'إعلان'
				},
				priorities: {
					low: 'منخفضة',
					medium: 'متوسطة',
					high: 'عالية',
					urgent: 'عاجلة'
				},
				fileUpload: {
					label: 'تحميل ملف (اختياري)',
					placeholder: 'اختر الملفات أو اسحبها وأفلتها هنا',
					hint: 'المدعومة: صور/*,ملفات PDF,.doc,.docx,.txt • الحد الأقصى: 10 ميجابايت • ملفات متعددة مسموحة'
				}
			}
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
