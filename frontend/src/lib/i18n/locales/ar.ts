import type { LocaleData } from "../types";

export const arabicLocale: LocaleData = {
  code: "ar",
  name: "العربية",
  nativeName: "العربية",
  direction: "rtl",
  dateFormat: "dd/MM/yyyy",
  timeFormat: "HH:mm",
  currencyFormat: "#,##0.00 ر.س",
  numberFormat: {
    style: "decimal",
    minimumFractionDigits: 0,
    maximumFractionDigits: 2,
  },
  pluralRules: [
    { count: 0, form: "zero" },
    { count: 1, form: "one" },
    { count: 2, form: "two" },
    { count: "other", form: "other" },
  ],
  translations: {
    // App General
    app: {
      name: "نظام إدارة أكورا",
      shortName: "أكورا",
      description: "نظام إدارة مدعوم بالذكاء الاصطناعي",
      loading: "جاري تحميل أكورا...",
      offline: "أنت غير متصل حالياً",
      updateAvailable: "إصدار جديد متوفر",
      updateReady: "التحديث جاهز للتثبيت",
      updateNow: "تحديث الآن",
      updateLater: "لاحقاً",
    },

    // Navigation & UI
    nav: {
      dashboard: "لوحة التحكم",
      master: "الأساسيات",
      admin: "الإدارة",
      user: "واجهة المستخدم",
      work: "العمل",
      customerApp: "تطبيق العملاء",
      customer: "العملاء",
      reports: "التقارير",
      settings: "الإعدادات",
      finance: "المالية",
      help: "المساعدة",
      logout: "تسجيل الخروج",
      language: "اللغة",
      languageToggle: "تبديل اللغة",
      english: "English",
      arabic: "العربية",
      goBack: "العودة",
      goToDashboard: "الذهاب إلى لوحة التحكم",
      viewNotifications: "عرض الإشعارات",
      refreshNotifications: "تحديث الإشعارات",
      approvals: "الموافقات",
      startReceiving: "بدء الاستلام",
      scheduledPayments: "المدفوعات المجدولة",
      monthlyManager: "مدير الأشهر",
      monthlyPaidManager: "مدير المدفوعات الشهرية",
      monthlyBreakdown: "تفصيل شهري",
      expenseManager: "إدارة المصروفات",
      dayBudgetPlanner: "مخطط الميزانية اليومية",
      paidManager: "مدير المدفوعات",
      soundSettings: "إعدادات الصوت",
      users: "المستخدمون",
      interfaceAccess: "وصول الواجهة",
      approvalPermissions: "صلاحيات الموافقة",
      userPermissions: "صلاحيات المستخدم",
      marketingMaster: "إدارة التسويق",
      marketing: "التسويق",
      erpConnections: "اتصالات ERP",
      clearTables: "مسح الجداول",
      delivery: "التوصيل",
      vendor: "الموردين",
      controls: "التحكم",
      hr: "الموارد البشرية",
      tasks: "المهام",
      notification: "الإشعارات",
      media: "الوسائط",
      promo: "الترويج",
      manage: "إدارة",
      operations: "العمليات",
      receiving: "الاستلام",
      receivingRecords: "سجلات الاستلام",
      flyerMaster: "رئيسي النشرات",
      productMaster: "رئيسي المنتجات",
      variationManager: "مدير الاختلافات",
      offerManager: "مدير العروض",
      flyerTemplates: "قوالب النشرات",
      flyerSettings: "إعدادات النشرات",
      socialLinkManager: "مدير روابط التواصل",
      offerProductEditor: "محرر منتجات العرض",
      createNewOffer: "إنشاء عرض جديد",
      pricingManager: "مدير التسعير",
      generateFlyers: "توليد النشرات",
      shelfPaperManager: "مدير ورق الرف",
      couponDashboard: "لوحة التخفيضات",
      manageCampaigns: "إدارة الحملات",
      viewOfferManager: "عرض محرر العروض",
      importCustomers: "استيراد العملاء",
      manageProducts: "إدارة المنتجات",
      reportsAndStats: "التقارير والإحصائيات",
      approvalCenter: "مركز الموافقات",
      categoryManager: "مدير الفئات",
      purchaseVoucherManager: "مدير قسائم الشراء",
      bankReconciliation: "المطابقة البنكية",
      manualScheduling: "الجدولة اليدوية",
      dayBudgetPlanner: "مخطط الميزانية اليومية",
      denomination: "الفئات النقدية",
      pettyCash: "النثرية",
      overdues: "المتأخرات",
      pos: "نقاط البيع",
      usersList: "المستخدمون",
      createUser: "إنشاء مستخدم",
      manageAdminUsers: "إدارة مستخدمي الإدارة",
      manageMasterAdmin: "إدارة المشرف الرئيسي",
      buttonAccessControl: "التحكم في وصول الأزرار",
      buttonGenerator: "مولد الأزرار",
      createDepartment: "إنشاء قسم",
      createLevel: "إنشاء مستوى",
      createPosition: "إنشاء منصب",
      reportingMap: "خريطة التقارير",
      assignPositions: "تعيين المناصب",
      linkID: "ربط المعرف",
      employeeFiles: "ملفات الموظفين",
      fingerprintTransactions: "عمليات البصمة",
      processFingerprint: "معالجة البصمة",
      salaryAndWage: "الرواتب والأجور",
      shiftAndLeave: "الوردية والإجازات",
      leavesAndVacations: "المغادرات والإجازات",
      discipline: "الانضباط",
      leaveRequest: "طلب الإجازة",
      exportBiometricData: "تصدير البيانات الحيوية",
      createTaskTemplate: "إنشاء قالب مهمة",
      viewTaskTemplates: "عرض قوالب المهمات",
      assignTasks: "تعيين المهام",
      viewMyTasks: "عرض مهامي",
      viewMyAssignments: "عرض تعييناتي",
      taskStatus: "حالة المهمة",
      branchPerformance: "أداء الفرع",
      interfaceAccess: "الوصول إلى الواجهة",
      approvalPermissions: "صلاحيات الموافقة",
      buttonAccessControl: "التحكم في الوصول إلى الأزرار",
      buttonGenerator: "منشئ الأزرار",
      whatsNew: "انقر لمعرفة الجديد",
      online: "متصل",
      offline: "غير متصل",
    },

    // Mobile page titles
    mobile: {
      home: "الرئيسية",
      language: "اللغة",
      logout: "تسجيل الخروج",
      dashboard: "لوحة التحكم",
      tasks: "المهام",
      notifications: "الإشعارات",
      assignments: "التكليفات",
      approvals: "الموافقات",
      leaveRequest: "طلب إجازة",
      quickTask: "مهمة سريعة",
      humanResources: "الموارد البشرية",
      fingerprintAnalysis: "تحليل البصمات",
      assignTasks: "تعيين المهام",
      createTask: "إنشاء مهمة",
      completeTask: "إكمال المهمة",
      taskDetails: "تفاصيل المهمة",
      notification: "إشعار",
      createNotification: "إنشاء إشعار",
      assignmentDetails: "تفاصيل التكليف",
      // Bottom navigation
      bottomNav: {
        tasks: "المهام",
        create: "تعيين",
        assignments: "التكليفات",
        purchaseVoucher: "القسائم",
      },
      // Error messages
      error: {
        accessRequired: "مطلوب تسجيل الدخول",
        loginRequired: "يرجى تسجيل الدخول للوصول إلى واجهة الجوال.",
        goToLogin: "الذهاب إلى تسجيل دخول الجوال",
      },
      // Mobile login
      login: {
        title: "الوصول للجوال",
        subtitle: "وصول سريع إلى لوحة تحكم الجوال",
        accessCode: "رمز الوصول",
        accessCodePlaceholder: "أدخل رمز الوصول المكون من 6 أرقام",
        accessButton: "دخول",
        accessingSystem: "جاري الوصول للنظام...",
        invalidCode: "رمز وصول غير صحيح",
        codeRequired: "رمز الوصول مطلوب",
        enterCode: "يرجى إدخال رمز الوصول",
        quickAccess: "بوابة الوصول السريع",
        secureLogin: "تسجيل دخول آمن للجوال",
        footer: "وصول آمن لواجهة أكوا للجوال",
        accessDenied: "تم رفض الوصول",
        accessGranted: "تم منح الوصول",
        invalidDigitError: "أدخل رمز أمان صحيح مكون من 6 أرقام",
        timeoutError: "انتهت مهلة الطلب. يرجى التحقق من اتصالك والمحاولة مرة أخرى.",
        networkError: "خطأ في الشبكة. يرجى التحقق من اتصالك والمحاولة مرة أخرى.",
        loginFailedError: "فشل تسجيل الدخول. يرجى المحاولة مرة أخرى.",
      },
      // Dashboard content
      dashboardContent: {
        stats: {
          pendingTasks: "المهام المعلقة",
          completed: "مكتمل",
          notifications: "الإشعارات",
          totalTasks: "إجمالي المهام",
          checkIn: "دخول",
          checkOut: "خروج",
          lastPunch: "آخر ختم",
          noPunch: "لا توجد بصمة متاحة خلال الـ 24 ساعة الماضية",
        },
        branchPerformance: {
          title: "أداء الفرع",
          dateRange: "📅 نطاق التاريخ",
          specificDate: "📅 تاريخ معين",
          fromDate: "من التاريخ",
          toDate: "إلى التاريخ",
          selectDate: "اختر التاريخ",
          todayPerformance: "أداء اليوم",
          yesterdayPerformance: "أداء الأمس",
          totalPerformance: "📊 الأداء الإجمالي",
          branchWisePerformance: "🏢 أداء الفروع",
          last3Days: "أداء آخر 3 أيام",
          selectBranch: "اختر الفرع:",
          loadPerformance: "📊 تحميل الأداء",
          loadingData: "جارٍ تحميل بيانات الأداء...",
          loadingDashboard: "جارٍ تحميل لوحة التحكم...",
          completed: "مكتمل",
          pending: "معلق",
          total: "المجموع",
          complete: "مكتمل",
          noTasks: "لا توجد مهام",
          noDataToday: "لا توجد بيانات لليوم",
          noDataYesterday: "لا توجد بيانات للأمس",
          noDataTwoDaysAgo: "لا توجد بيانات لقبل يومين",
          twoDaysAgo: "قبل يومين",
        },
        recentNotifications: {
          title: "الإشعارات الأخيرة",
          allInSystem: "جميع الإشعارات في النظام",
          yourRecent: "إشعاراتك الأخيرة",
          noNotifications: "لا توجد إشعارات حديثة",
        },
        actions: {
          createNotification: "إنشاء إشعار",
          download: "تحميل",
          source: "المصدر",
        },
        labels: {
          sentBy: "أرسل بواسطة:",
          sentTo: "أرسل إلى:",
          attachments: "المرفقات",
          system: "النظام",
          from: "من:",
        },
      },
      // Tasks page content
      tasksContent: {
        title: "مهامي - أكورا موبايل",
        createTask: "إنشاء مهمة",
        searchPlaceholder: "البحث في المهام...",
        filters: {
          allStatus: "جميع الحالات",
          pending: "في الانتظار",
          inProgress: "قيد التنفيذ",
          completed: "مكتملة",
          cancelled: "ملغية",
          allPriority: "جميع الأولويات",
          high: "عالية",
          medium: "متوسطة",
          low: "منخفضة",
        },
        results: {
          tasksFound: "مهمة موجودة",
          taskFound: "مهمة موجودة",
        },
        loading: "تحميل المهام...",
        emptyState: {
          title: "لم يتم العثور على مهام",
          description:
            "لا توجد مهام تطابق المرشحات الحالية، أو ليس لديك أي مهام مخصصة بعد.",
        },
        taskCard: {
          quickTask: "مهمة سريعة",
          by: "بواسطة",
          assigned: "مخصصة",
          unknown: "غير معروف",
          attachment: "مرفق",
          attachments: "مرفقات",
          download: "تحميل",
          downloadAll: "تحميل الكل",
          markComplete: "تمييز كمكتملة",
          viewDetails: "عرض التفاصيل",
        },
      },
      // Task assignment page content
      assignContent: {
        title: "تخصيص المهام - أكورا موبايل",
        loading: "تحميل البيانات...",
        createTaskTemplate: "إنشاء قالب مهمة",
        createNotification: "إنشاء إشعار",
        steps: {
          users: "المستخدمين",
          tasks: "المهام",
          settings: "الإعدادات",
          criteria: "المعايير",
        },
        step1: {
          title: "اختيار المستخدمين",
          description: "اختر المستخدمين لتخصيص المهام لهم",
          searchPlaceholder:
            "البحث بالاسم أو اسم المستخدم أو البريد الإلكتروني...",
          allBranches: "جميع الفروع",
        },
        step2: {
          title: "اختيار المهام",
          description: "اختر المهام المراد تخصيصها",
          searchPlaceholder: "البحث في المهام...",
          noDescription: "لا يوجد وصف",
        },
        step3: {
          title: "إعدادات التخصيص",
          description: "تكوين خيارات التخصيص",
          notificationSettings: "إعدادات التنبيهات",
          sendNotifications: "إرسال تنبيهات للمخصص لهم",
          assignmentType: "نوع التخصيص",
          oneTimeAssignment: "تخصيص لمرة واحدة",
          recurringAssignment: "تخصيص متكرر",
          deadlineSettings: "إعدادات الموعد النهائي",
          setDeadline: "تحديد موعد نهائي للتخصيص",
          deadlineDate: "تاريخ الموعد النهائي",
          deadlineTime: "وقت الموعد النهائي",
          allowReassign: "السماح للمستخدمين بإعادة تخصيص المهام",
          notifyAssignees: "إشعار المخصص لهم",
          additionalNotes: "ملاحظات إضافية",
          specialInstructions: "أضف أي تعليمات خاصة...",
          // Repeat Settings
          repeatSettings: "إعدادات التكرار",
          repeatType: "نوع التكرار",
          selectDays: "اختر الأيام",
          repeatEvery: "كرر كل",
          daily: "يومي",
          weekly: "أسبوعي",
          weeklySpecific: "أسبوعي (أيام محددة)",
          monthly: "شهري",
          monthlySpecific: "شهري (تاريخ محدد)",
          everyNDays: "كل عدة أيام",
          everyNWeeks: "كل عدة أسابيع",
          // Days of the week
          monday: "الإثنين",
          tuesday: "الثلاثاء",
          wednesday: "الأربعاء",
          thursday: "الخميس",
          friday: "الجمعة",
          saturday: "السبت",
          sunday: "الأحد",
          // Day abbreviations
          mon: "إثن",
          tue: "ثلا",
          wed: "أرب",
          thu: "خمي",
          fri: "جمع",
          sat: "سبت",
          sun: "أحد",
          priorityOverride: "تجاوز الأولوية",
          defaultPriority: "استخدام أولوية المهمة الافتراضية",
          high: "عالية",
          medium: "متوسطة",
          low: "منخفضة",
          additionalOptions: "خيارات إضافية",
          enableReassigning: "تمكين إعادة التخصيص في حالة عدم توفر المستخدم",
          addNote: "إضافة ملاحظة للمخصص لهم",
        },
        step4: {
          title: "معايير التخصيص",
          description: "تحديد متطلبات الإكمال",
          completionRequirements: "متطلبات الإكمال",
          requireTaskFinished: "يجب تمييز المهمة كمنتهية",
          requirePhotoUpload: "مطلوب تحميل صورة للإكمال",
          requireErpReference: "مطلوب مرجع ERP",
          assignmentSummary: "ملخص التخصيص",
          usersLabel: "المستخدمون:",
          tasksLabel: "المهام:",
          typeLabel: "النوع:",
          deadlineLabel: "الموعد النهائي:",
          oneTimeType: "مرة واحدة",
          recurringType: "متكرر",
          selectedUsers: "مستخدم محدد",
          selectedTasks: "مهمة محددة",
        },
        actions: {
          cancel: "إلغاء",
          previous: "السابق",
          nextStep: "الخطوة التالية",
          assignTasks: "تخصيص المهام",
          assigning: "جاري التخصيص...",
        },
        // Priority and Status translations
        priorities: {
          high: "عالية",
          medium: "متوسطة",
          low: "منخفضة",
        },
        statuses: {
          draft: "مسودة",
          active: "نشط",
          paused: "متوقف",
          completed: "مكتمل",
          cancelled: "ملغي",
        },
      },

      // Create Task Content
      createContent: {
        title: "إنشاء مهمة - أكورا موبايل",
        taskTitle: "عنوان المهمة",
        taskTitleRequired: "عنوان المهمة مطلوب",
        taskTitlePlaceholder: "أدخل عنوان المهمة",
        description: "الوصف",
        descriptionRequired: "الوصف مطلوب",
        descriptionPlaceholder: "وصف المهمة",
        attachments: "المرفقات",
        camera: "الكاميرا",
        uploadFile: "تحميل ملف (اختياري)",
        chooseFiles: "اختر الملفات أو اسحبها هنا",
        supportedFormats:
          "المدعوم: images/pdf, doc, docx, xls, xlsx, txt, ppt • حد أقصى: 10MB",
        actions: {
          cancel: "إلغاء",
          createTask: "إنشاء مهمة",
          creating: "جاري الإنشاء...",
        },
        errors: {
          titleRequired: "عنوان المهمة مطلوب",
          descriptionRequired: "الوصف مطلوب",
          createFailed: "فشل في إنشاء المهمة",
          fillRequired: "يرجى ملء جميع الحقول المطلوبة",
          fixFormErrors: "يرجى إصلاح أخطاء النموذج قبل الإرسال.",
          createFailedTryAgain: "فشل في إنشاء المهمة. يرجى المحاولة مرة أخرى.",
        },
        success: {
          taskCreated: "تم إنشاء المهمة بنجاح!",
        },
      },

      // Quick Task Content
      quickTaskContent: {
        title: "مهمة سريعة - أكورا موبايل",
        loading: "جارِ التحميل...",
        // Steps
        step1: {
          title: "1. اختيار الفرع",
          branchLabel: "الفرع:",
          selectBranch: "-- اختر الفرع --",
          defaultBadge: "افتراضي",
          change: "تغيير",
          confirm: "✓ تأكيد",
          setAsDefault: "تعيين كفرع افتراضي",
        },
        step2: {
          title: "2. اختيار المستخدمين",
          usersLabel: "المستخدمون:",
          selected: "محدد",
          change: "تغيير",
          searchPlaceholder: "البحث عن المستخدمين...",
          more: "المزيد",
          setAsDefault: "حفظ هؤلاء المستخدمين كافتراضي",
          confirmUsers: "✓ تأكيد المستخدمين",
        },
        step3: {
          title: "3. تفاصيل المهمة",
          issueType: "نوع المشكلة:",
          selectIssueType: "-- اختر نوع المشكلة --",
          customIssueType: "نوع مشكلة مخصص:",
          customIssuePlaceholder: "أدخل نوع المشكلة المخصص",
          priority: "الأولوية:",
          description: "الوصف (اختياري):",
          descriptionPlaceholder: "أدخل وصف المهمة...",
          saveAsDefault: "حفظ هذه الإعدادات كافتراضية",
        },
        step4: {
          title: "4. المرفقات (اختياري)",
          chooseFiles: "اختيار الملفات",
          camera: "الكاميرا",
          removeFile: "إزالة الملف",
        },
        step5: {
          title: "5. متطلبات الإكمال",
          requirePhoto: "مطلوب تحميل صورة عند الإكمال",
          requireErp: "مطلوب مرجع ERP عند الإكمال",
          requireFile: "مطلوب تحميل ملف عند الإكمال",
        },
        // Issue Types
        issueTypes: {
          priceTag: "مشكلة البطاقة السعرية",
          cleaning: "مشكلة تنظيف",
          display: "مشكلة عرض",
          filling: "مشكلة تعبئة",
          maintenance: "مشكلة صيانة",
          other: "مشكلة أخرى",
        },
        // Priority Options
        priorities: {
          low: "منخفضة",
          medium: "متوسطة",
          high: "عالية",
          urgent: "عاجلة",
        },
        // Price Tag Options
        priceTags: {
          low: "منخفض",
          medium: "متوسط",
          high: "عالي",
          critical: "حرج",
        },
        // Actions
        actions: {
          assignTask: "تخصيص المهمة",
          creatingTask: "جاري إنشاء المهمة...",
        },
        // Success Messages
        success: {
          taskCreated: "تم إنشاء المهمة بنجاح!",
          gotIt: "حسناً!",
        },
        // Labels
        issueTypeLabel: "المهمة",
        filesLabel: "الملفات",
      },

      // Assignments Content
      assignmentsContent: {
        title: "مهامي - موبايل أكوا",
        loading: "جاري تحميل المهام...",
        // Statistics
        stats: {
          total: "الإجمالي",
          completed: "مكتملة",
          inProgress: "قيد التنفيذ",
          pending: "معلقة",
          overdue: "متأخرة",
        },
        // Search and Filters
        search: {
          placeholder: "البحث في المهام أو المستخدمين...",
          allStatuses: "جميع الحالات",
          allPriorities: "جميع الأولويات",
          clearFilters: "مسح المرشحات",
        },
        // Statuses
        statuses: {
          assigned: "مُعيَّنة",
          inProgress: "قيد التنفيذ",
          completed: "مكتملة",
          cancelled: "ملغية",
          escalated: "مُصعَّدة",
          reassigned: "مُعادة التعيين",
          unknown: "غير معروف",
        },
        // Priorities
        priorities: {
          high: "عالية",
          medium: "متوسطة",
          low: "منخفضة",
          urgent: "عاجلة",
        },
        // Task Details
        taskDetails: {
          unknownTask: "مهمة غير معروفة",
          quickTask: "⚡ مهمة سريعة",
          quickBadge: "⚡ سريع",
          overdue: "⚠️ متأخر",
          description: "الوصف:",
          notes: "الملاحظات:",
          attachments: "📎 المرفقات",
          deadline: "الموعد النهائي:",
          noDeadline: "لا يوجد موعد نهائي",
          assignedTo: "مُعيَّن إلى:",
          createdBy: "أنشأها:",
          branch: "الفرع:",
          priceTag: "علامة السعر:",
          issueType: "نوع المشكلة:",
          status: "الحالة:",
        },
        // Actions
        actions: {
          download: "تحميل",
          viewDetails: "عرض التفاصيل",
          markComplete: "تمييز كمكتمل",
          updateStatus: "تحديث الحالة",
        },
        // Empty States
        emptyStates: {
          noAssignments: "لم يتم العثور على مهام",
          noAssignmentsYet: "لم تقم بتعيين أي مهام بعد.",
          noMatchingFilters: "لا توجد مهام تطابق المرشحات الحالية.",
        },
        // Footer
        footer: {
          showing: "عرض",
          of: "من",
          completionRate: "معدل الإنجاز:",
        },
      },

      // Create Notification Content
      createNotificationContent: {
        basicInformation: "المعلومات الأساسية",
        title: "العنوان",
        titlePlaceholder: "ادخل عنوان الإشعار",
        message: "الرسالة",
        messagePlaceholder: "ادخل رسالة الإشعار",
        type: "النوع",
        priority: "الأولوية",
        targetAudience: "الجمهور المستهدف",
        sendTo: "إرسال إلى",
        allUsers: "جميع المستخدمين",
        specificUsers: "مستخدمين محددين",
        searchPlaceholder: "البحث عن المستخدمين...",
        selectAll: "تحديد الكل",
        deselectAll: "إلغاء تحديد الكل",
        userSelected: "مستخدم محدد",
        loadingUsers: "تحميل المستخدمين...",
        noUsers: "لم يتم العثور على مستخدمين",
        attachments: "المرفقات (اختيارية)",
        reset: "إعادة تعيين",
        publish: "نشر الإشعار",
        publishing: "جاري النشر...",
        success: "تم نشر الإشعار بنجاح!",
        errors: {
          titleRequired: "يرجى إدخال عنوان الإشعار",
          messageRequired: "يرجى إدخال رسالة الإشعار",
          usersRequired: "يرجى تحديد مستخدم واحد على الأقل للاستهداف المحدد",
          uploadFailed: "فشل في تحميل الملف",
        },
        types: {
          info: "معلومات",
          success: "نجاح",
          warning: "تحذير",
          error: "خطأ",
          announcement: "إعلان",
        },
        priorities: {
          low: "منخفضة",
          medium: "متوسطة",
          high: "عالية",
          urgent: "عاجلة",
        },
        fileUpload: {
          label: "تحميل ملف (اختياري)",
          placeholder: "اختر الملفات أو اسحبها وأفلتها هنا",
          hint: "المدعومة: صور/*,ملفات PDF,.doc,.docx,.txt • الحد الأقصى: 10 ميجابايت • ملفات متعددة مسموحة",
        },
      },

      // Purchase Voucher Manager
      purchaseVoucher: {
        title: "مدير قسائم الشراء",
        loading: "جاري تحميل بيانات القسائم...",
        available: "متاح",
        issued: "صُرفت",
        closed: "مغلقة",
        myStock: "مخزوني",
        noAvailableVouchers: "لا توجد قسائم متاحة",
        noIssuedVouchers: "لا توجد قسائم مصروفة",
        noClosedVouchers: "لا توجد قسائم مغلقة",
        noStockAssigned: "لا يوجد مخزون مخصص لك",
        unassigned: "غير مخصص",
        pcs: "قطعة",
        availableBreakdown: "متاح",
        issuedBreakdown: "مصروف",
      },
    },

    // Commands
    commands: {
      // Window management
      window: "نافذة",
      minimizeAll: "تصغير جميع النوافذ",
      minimizeAllDesc: "تصغير جميع النوافذ المفتوحة",
      closeAll: "إغلاق جميع النوافذ",
      closeAllDesc: "إغلاق جميع النوافذ المفتوحة",
      showDesktop: "إظهار سطح المكتب",
      showDesktopDesc: "إظهار سطح المكتب من خلال تصغير جميع النوافذ",
      // Admin functions
      manageBranches: "إدارة فروع الشركة",
      manageVendors: "إدارة الموردين",
      manageInvoices: "إدارة الفواتير والفوترة",
      manageUsers: "إدارة مستخدمي النظام والأدوار",
      importData: "استيراد البيانات من ملفات إكسل",
      // Tools and help
      tools: "الأدوات",
      help: "المساعدة والوثائق",
      helpDesc: "عرض وثائق النظام",
      helpCategory: "المساعدة",
      about: "حول أكورا",
      aboutDesc: "معلومات النظام والإصدار",
      // UI
      searchPlaceholder: "اكتب أمراً أو ابحث...",
      clearSearch: "مسح البحث",
      noResults: "لم يتم العثور على أوامر",
      execute: "تنفيذ",
      navigate: "التنقل",
      close: "إغلاق",
    },

    // Employee Files
    employeeFiles: {
      title: "ملفات الموظفين",
      searchEmployee: "البحث عن موظف",
      filters: "الفلاتر",
      branch: "الفرع",
      position: "المنصب",
      allBranches: "جميع الفروع",
      allPositions: "جميع المناصب",
      searchPlaceholder: "ابحث بالاسم أو الرقم الوظيفي...",
      id: "الرقم",
      name: "الاسم",
      nameAr: "الاسم (عربي)",
      nameEn: "الاسم (إنجليزي)",
      positionAr: "المنصب (عربي)",
      positionEn: "المنصب (إنجليزي)",
      noEmployeesFound: "لم يتم العثور على موظفين",
      loadingEmployees: "جاري تحميل الموظفين...",
      nationality: "الجنسية",
      sponsorshipStatus: "حالة الكفالة",
      active: "نشط",
      inactive: "غير نشط",
      employmentStatus: "الحالة الوظيفية",
      statuses: {
        jobWithFinger: "على رأس العمل (بصمة)",
        jobNoFinger: "على رأس العمل (بدون بصمة)",
        remoteJob: "عمل عن بعد",
        vacation: "إجازة",
        resigned: "مستقيل",
        terminated: "منتهي الخدمات",
        escape: "بلاغ هروب",
        unknown: "غير معروف"
      },
      inJob: "على رأس العمل (بصمة)",
      resigned: "مستقيل",
      vacation: "إجازة",
      terminated: "منتهي الخدمات",
      runAway: "بلاغ هروب",
      remoteJob: "عمل عن بعد",
      jobNoFinger: "على رأس العمل (بدون بصمة)",
      edit: "تعديل",
      save: "حفظ",
      saveStatus: "حفظ الحالة",
      update: "تحديث",
      updating: "جاري التحديث...",
      saveNumber: "حفظ الرقم",
      updateNumber: "تحديث الرقم",
      editNumber: "تعديل الرقم",
      saveDate: "حفظ التاريخ",
      updateDate: "تحديث التاريخ",
      editDate: "تعديل التاريخ",
      idNumber: "رقم الهوية",
      idResidentTitle: "رقم الهوية / الإقامة",
      enterIdNumber: "أدخل رقم الهوية",
      changeIdNumber: "تغيير رقم الهوية",
      expiryDate: "تاريخ الانتهاء",
      changeExpiryDate: "تغيير تاريخ الانتهاء",
      healthCard: "البطاقة الصحية",
      healthCardNumber: "رقم البطاقة الصحية",
      healthCardExpiryDate: "تاريخ انتهاء البطاقة الصحية",
      healthEducationalRenewalDate: "تاريخ التجديد الصحي التعليمي",
      enterHealthCardNumber: "أدخل رقم البطاقة الصحية",
      changeHealthCardNumber: "تغيير رقم البطاقة الصحية",
      educationExpiryDate: "تاريخ انتهاء التعليم",
      changeEducationExpiryDate: "تغيير تاريخ انتهاء التعليم",
      drivingLicence: "رخصة القيادة",
      drivingLicenceNumber: "رقم رخصة القيادة",
      licenceNumber: "رقم الرخصة",
      drivingLicenceExpiryDate: "تاريخ انتهاء رخصة القيادة",
      enterDrivingLicenceNumber: "أدخل رقم رخصة القيادة",
      enterLicenceNumber: "أدخل رقم الرخصة",
      changeDrivingLicenceNumber: "تغيير رقم رخصة القيادة",
      contract: "العقد",
      contractExpiryDate: "تاريخ انتهاء العقد",
      workPermitExpiryDate: "تاريخ انتهاء تصريح العمل",
      saveContractDate: "حفظ تاريخ العقد",
      updateContractDate: "تحديث تاريخ العقد",
      insuranceCompany: "شركة التأمين",
      insuranceExpiryDate: "تاريخ انتهاء التأمين",
      changeInsuranceCompany: "تغيير شركة التأمين",
      saveCompany: "حفظ الشركة",
      editCompany: "تعديل الشركة",
      bankSalaryDetails: "تفاصيل البنك والراتب",
      bankName: "اسم البنك",
      enterBankName: "أدخل اسم البنك",
      changeBankName: "تغيير اسم البنك",
      iban: "رقم الآيبان (IBAN)",
      enterIban: "أدخل رقم الآيبان",
      changeIban: "تغيير رقم الآيبان",
      bankDocument: "مستند البنك",
      healthInsurance: "التأمين الصحي",
      selectCompany: "اختر الشركة",
      createCompany: "إضافة شركة",
      personalInformation: "المعلومات الشخصية",
      dateOfBirth: "تاريخ الميلاد",
      age: "العمر",
      saveDob: "حفظ تاريخ الميلاد",
      updateDob: "تحديث تاريخ الميلاد",
      changeDateOfBirth: "تغيير تاريخ الميلاد",
      nationality: "الجنسية",
      selectNationality: "اختر الجنسية",
      saveNationality: "حفظ الجنسية",
      changeNationality: "تغيير الجنسية",
      joinDate: "تاريخ الانضمام",
      saveJoinDate: "حفظ تاريخ الانضمام",
      updateJoinDate: "تحديث تاريخ الانضمام",
      changeJoinDate: "تغيير تاريخ الانضمام",
      probationPeriod: "فترة التجربة",
      probationPeriodExpiryDate: "تاريخ انتهاء فترة التجربة",
      probationPeriodFinished: "انتهت فترة التجربة",
      saveProbationDate: "حفظ تاريخ فترة التجربة",
      updateProbationDate: "تحديث تاريخ فترة التجربة",
      changeProbationExpiry: "تغيير انتهاء فترة التجربة",
      years: "سنوات",
      upload: "رفع",
      uploadDocument: "رفع مستند",
      viewDocument: "عرض المستند",
      download: "تحميل",
      placeholderEmployeeSelect: "يرجى اختيار موظف لعرض التفاصيل",
      days: "أيام",
      remaining: "متبقية",
      expired: "منتهي",
      saved: "تم الحفظ",
      expiresToday: "ينتهي اليوم!",
      expiredAgo: "منتهي منذ {days} يوم",
      finished: "منتهي",
      underDevelopment: "هذا القسم قيد التطوير.",
      posShortages: "عجوزات نقاط البيع",
      totalShortages: "إجمالي العجوزات",
      total: "الإجمالي",
      proposed: "مقترح",
      forgiven: "معفو عنه",
      deducted: "مخصوم",
      cancelled: "ملغي",
      createInsuranceCompany: "إنشاء شركة تأمين",
      addNationality: "إضافة جنسية",
      createNationality: "إنشاء جنسية جديدة",
      nationalityId: "رقم الجنسية (مثال: SA, UK)",
      nationalityNameEn: "الاسم (إنجليزي)",
      nationalityNameAr: "الاسم (عربي)",
      enterNationalityId: "أدخل الرقم",
      companyNameEn: "اسم الشركة (إنجليزي)",
      companyNameAr: "اسم الشركة (عربي)",
      enterNameEn: "أدخل اسم الشركة بالإنجليزي",
      enterNameAr: "أدخل اسم الشركة بالعربي",
      enterNationalityNameEn: "أدخل اسم الجنسية بالإنجليزي",
      enterNationalityNameAr: "أدخل اسم الجنسية بالعربي",
      cancel: "إلغاء",
      create: "إنشاء",
      creating: "جاري الإنشاء...",
      alerts: {
        enterNationalityDetails: "يرجى إدخال جميع تفاصيل الجنسية (الرقم، الاسم بالإنجليزي، الاسم بالعربي)",
        createNationalityError: "خطأ في إنشاء الجنسية. قد يكون الرقم موجوداً بالفعل.",
        createNationalitySuccess: "تم إنشاء الجنسية بنجاح",
        enterId: "يرجى إدخال رقم الهوية",
        saveSuccess: "تم الحفظ بنجاح!",
        saveError: "فشل في حفظ البيانات",
        selectExpiry: "يرجى اختيار تاريخ الانتهاء",
        selectWorkPermit: "يرجى اختيار تاريخ انتهاء تصريح العمل",
        selectFile: "يرجى اختيار ملف للرفع",
        uploadSuccess: "تم رفع المستند بنجاح!",
        uploadError: "فشل في رفع المستند",
        saveUrlError: "فشل في حفظ رابط المستند",
        enterHealthNumber: "يرجى إدخال رقم البطاقة الصحية",
        selectRenewalDate: "يرجى اختيار تاريخ التجديد",
        enterDrivingNumber: "يرجى إدخال رقم رخصة القيادة",
        enterBankName: "يرجى إدخال اسم البنك",
        enterIban: "يرجى إدخال رقم الآيبان",
        enterDob: "يرجى إدخال تاريخ الميلاد",
        enterJoinDate: "يرجى إدخال تاريخ الانضمام",
        enterProbationDate: "يرجى إدخال تاريخ انتهاء فترة التجربة",
        selectInsuranceCompany: "يرجى اختيار شركة التأمين",
        selectNationality: "يرجى اختيار الجنسية",
        selectEmployee: "يرجى اختيار موظف",
        enterCompanyNames: "يرجى إدخال اسم الشركة باللغتين",
        createCompanySuccess: "تم إنشاء شركة التأمين بنجاح!",
        createCompanyError: "فشل في إنشاء شركة التأمين",
        loadEmployeesError: "فشل في تحميل بيانات الموظفين",
        loadBranchesError: "فشل في تحميل بيانات الفروع"
      }
    },

    // Window Management
    window: {
      minimize: "تصغير",
      maximize: "تكبير",
      restore: "استعادة",
      close: "إغلاق",
      duplicate: "نسخ",
      detach: "فصل",
      newWindow: "نافذة جديدة",
      activeWindows: "النوافذ النشطة",
      noWindows: "لا توجد نوافذ مفتوحة",
    },

    // Authentication
    auth: {
      signIn: "تسجيل الدخول",
      signOut: "تسجيل الخروج",
      signUp: "إنشاء حساب",
      username: "اسم المستخدم",
      enterUsername: "أدخل اسم المستخدم",
      enterPassword: "أدخل كلمة المرور",
      login: "تسجيل الدخول",
      logout: "تسجيل الخروج",
      loggingIn: "جاري تسجيل الدخول...",
      email: "البريد الإلكتروني",
      password: "كلمة المرور",
      confirmPassword: "تأكيد كلمة المرور",
      forgotPassword: "نسيت كلمة المرور؟",
      resetPassword: "إعادة تعيين كلمة المرور",
      rememberMe: "تذكرني",
      invalidCredentials: "البريد الإلكتروني أو كلمة المرور غير صحيحة",
      accountLocked: "الحساب مقفل",
      mfaRequired: "مطلوب تفعيل المصادقة الثنائية",
      mfaCode: "رمز التحقق",
      changePassword: "تغيير كلمة المرور",
      newPassword: "كلمة المرور الجديدة",
      currentPassword: "كلمة المرور الحالية",
      passwordChanged: "تم تغيير كلمة المرور بنجاح",
      mustChangePassword: "يجب تغيير كلمة المرور قبل المتابعة",
      quickAccess: "الوصول السريع",
      accessCode: "رمز الوصول",
      continueLogin: "المتابعة إلى النظام",
      cashierAccessDenied: "تم رفض الوصول. صلاحية الكاشير معطلة لهذا المستخدم.",
    },

    reports: {
      expenseTracker: "متتبع المصروفات",
      salesReport: "تقرير المبيعات",
      vendorPayments: "مدفوعات الموردين",
      vendorRecords: "سجلات الموردين",
      vendorPendings: "المدفوعات المعلقة للموردين",
      dailySalesOverview: "نظرة عامة على المبيعات اليومية",
      todayBranchSales: "مبيعات الفروع اليوم",
      yesterdayBranchSales: "مبيعات الفروع أمس",
      todayCollectionSales: "مبيعات اليوم (التحصيل)",
      yesterdayCollectionSales: "مبيعات أمس (التحصيل)",
      previousMonth: "الشهر السابق",
      currentMonth: "الشهر الحالي",
      previous: "الشهر السابق",
      current: "الشهر الحالي",
      averagePerDay: "المتوسط/اليوم",
      days: "أيام",
      bills: "فواتير",
      basket: "السلة",
      return: "المرتجعات",
      today: "اليوم",
      yesterday: "أمس",
      twoDaysAgo: "منذ يومين",
    },

    // Admin Modules
    admin: {
      title: "الإدارة",
      hrMaster: "إدارة الموارد البشرية",
      branchesMaster: "إدارة الفروع",
      taskMaster: "إدارة المهام",
      vendorsMaster: "إدارة الموردين",
      vendorMaster: "إدارة الموردين",
      invoiceMaster: "إدارة الفواتير",
      operationsMaster: "إدارة العمليات",
      financeMaster: "الإدارة المالية",
      communicationCenter: "مركز الاتصالات",
      // Delivery module
      deliverySettings: "إعدادات التوصيل",
      customerMaster: "العملاء",
      ordersManager: "إدارة الطلبات",
      offerManagement: "إدارة العروض",
      adManager: "إدارة الإعلانات",
      productsManager: "إدارة المنتجات",
      flyerMaster: "إدارة النشرات",
      employeeMaster: "إدارة الموظفين",
      userMaster: "إدارة المستخدمين",
      categoriesMaster: "إدارة الفئات",
      itemsMaster: "إدارة الأصناف",
      userRoles: "أدوار المستخدمين",
      hierarchyMaster: "الهيكل التنظيمي",
      userManagement: "إدارة المستخدمين",
      importData: "استيراد البيانات",
      uploadVendor: "تحميل الموردين",
      createVendor: "إنشاء موردين",
      manageVendor: "إدارة الموردين",
      auditLog: "سجل المراجعة",
      accountRecovery: "استرداد الحساب",
      customerManagement: "إدارة العملاء",
      customerManagementDesc: "إدارة تسجيلات العملاء وموافقات الوصول",
      pendingRegistrationRequests: "طلبات التسجيل المعلقة",
      unresolvedAccountRecovery: "طلبات استرداد الحساب غير المحلولة",
      customerName: "اسم العميل",
      whatsappNumber: "رقم واتساب",
      status: "الحالة",
      registrationDate: "تاريخ التسجيل",
      lastLogin: "آخر تسجيل دخول",
      locations: "المواقع",
      actions: "الإجراءات",
      pending: "معلق",
      approved: "موافق عليه",
      rejected: "مرفوض",
      suspended: "موقوف",
      never: "أبدًا",
      viewLocations: "عرض",
      approve: "موافقة",
      reject: "رفض",
      allStatuses: "جميع الحالات",
      searchPlaceholder: "بحث...",
      loading: "جاري التحميل...",
      noCustomers: "لم يتم العثور على عملاء",
      noDataFound: "لم يتم العثور على بيانات",
      approveCustomer: "موافقة على العميل",
      rejectCustomer: "رفض العميل",
      unknownCustomer: "عميل غير معروف",
      notProvided: "غير مقدم",
      registrationNotes: "ملاحظات التسجيل",
      accessCode: "رمز الوصول",
      generate: "توليد",
      generating: "جاري التوليد...",
      generateAccessCodeHint: "انقر 'توليد' لإنشاء رمز وصول مكون من 6 أرقام للعميل",
      accessCodePlaceholder: "توليد رمز وصول مكون من 6 أرقام",
      notesOptional: "ملاحظات (اختياري)",
      approvalNotesPlaceholder: "إضافة ملاحظات الموافقة أو تعليمات خاصة...",
      rejectionNotesPlaceholder: "قدم سبب الرفض...",
      customerApprovedSuccess: "تمت الموافقة على العميل بنجاح!",
      shareViaWhatsApp: "مشاركة تسجيل الدخول عبر واتساب",
      done: "تم",
      cancel: "إلغاء",
      saveAndApprove: "حفظ وموافقة",
      saving: "جاري الحفظ...",
      viewLocations: "عرض المواقع",
      customer: "العميل",
      whatsapp: "واتساب",
      location: "الموقع",
      name: "الاسم",
      distance: "المسافة",
      coordinates: "الإحداثيات",
      notSet: "غير محدد",
      locationNotSetMessage: "غير محدد من قبل العميل",
      close: "إغلاق",
      customerManagementDescription: "إدارة تسجيلات العملاء وموافقات الوصول",
      pendingRegistrationRequests: "طلبات التسجيل المعلقة",
      unresolvedAccountRecovery: "استرداد الحساب غير المحلول",
      customerAccountRecoveryManager: {
        title: "مدير استرداد حسابات العملاء",
        showResolvedRequests: "إظهار الطلبات المحلولة",
        refresh: "تحديث",
        loading: "جاري التحميل...",
        loadingCustomerData: "جاري تحميل بيانات العملاء...",
        pendingRecoveryRequests: "طلبات الاسترداد المعلقة",
        accessCodeRequests: "طلبات رموز الوصول",
        processedThisWeek: "تمت معالجتها هذا الأسبوع",
        accountRecoveryRequests: "طلبات استرداد الحسابات",
        accessCodeRequestsSection: "طلبات رموز الوصول",
        customer: "العميل",
        whatsapp: "واتساب",
        requestTime: "وقت الطلب",
        status: "الحالة",
        actions: "الإجراءات",
        verifyIdentity: "تحقق من الهوية",
        generateShareCode: "إنتاج ومشاركة الرمز",
        markAsResolved: "تمييز كمحلول",
        generateNewCode: "إنتاج رمز جديد",
        shareViaWhatsapp: "مشاركة عبر واتساب",
        verificationRequired: "مطلوب التحقق",
        resolved: "محلول",
        requestResolved: "تم حل الطلب",
        pending: "معلق",
        processed: "تمت المعالجة",
        newAccessCodeGenerated: "تم إنتاج رمز وصول جديد",
        username: "اسم المستخدم",
        newAccessCode: "رمز الوصول الجديد",
        accessCodeCopied: "تم نسخ رمز الوصول إلى الحافظة",
        copy: "نسخ",
        close: "إغلاق",
      },
      pending: "قيد الانتظار",
      approved: "موافق عليه",
      rejected: "مرفوض",
      approve: "موافقة",
      reject: "رفض",
      approveCustomer: "موافقة العميل",
      rejectCustomer: "رفض العميل",
      notes: "ملاحظات",
      approvalNotesPlaceholder: "أضف ملاحظات الموافقة أو تعليمات خاصة...",
      rejectionNotesPlaceholder: "قدم سبب الرفض...",
      flyer: {
        dashboard: "لوحة النشرات",
        productMaster: "إدارة المنتجات",
        offerTemplates: "قوالب العروض",
        offerProductSelector: "اختيار منتجات العرض",
        offerManager: "إدارة العروض",
        pricingManager: "إدارة الأسعار",
        flyerGenerator: "منشئ النشرات",
        flyerTemplates: "قوالب النشرات",
        flyerSettings: "إعدادات النشرات",
        // Product Master
        products: {
          title: "إدارة المنتجات",
          subtitle: "إدارة كتالوج منتجاتك",
          importExcel: "استيراد من Excel",
          exportExcel: "تصدير Excel",
          uploadImages: "رفع الصور",
          downloadTemplate: "تحميل القالب",
          saveToDatabase: "حفظ في قاعدة البيانات",
          refresh: "تحديث",
          addProduct: "إضافة منتج",
          totalProducts: "إجمالي المنتجات",
          filtered: "المفلترة",
          categories: "الفئات",
          searchPlaceholder: "البحث بالباركود أو الاسم...",
          allCategories: "كل الفئات",
          barcode: "الباركود",
          productNameEn: "اسم المنتج (إنجليزي)",
          productNameAr: "اسم المنتج (عربي)",
          mainCategory: "الفئة الرئيسية",
          subCategory: "الفئة الفرعية",
          finalCategory: "الفئة النهائية",
          unit: "الوحدة",
          image: "الصورة",
          actions: "الإجراءات",
          edit: "تعديل",
          delete: "حذف",
          updateImage: "تحديث الصورة",
          noProducts: "لم يتم العثور على منتجات",
          addFirstProduct: "أضف منتجك الأول أعلاه!",
          adjustFilters: "حاول تعديل البحث أو الفلاتر",
          uploading: "جاري الرفع...",
          saving: "جاري الحفظ...",
          loading: "جاري التحميل...",
          productsWithoutImages: "منتجات بدون صور",
          allProducts: "كل المنتجات",
          chooseImage: "اختر صورة",
          googleSearch: "جوجل",
          duckDuckGo: "DuckDuckGo",
          useThis: "استخدم هذه",
          removeBackground: "إزالة الخلفية بالذكاء الاصطناعي (مجاناً)",
          removeBgApi: "Remove.bg",
          cancel: "إلغاء",
          uploadImage: "رفع الصورة",
          close: "إغلاق",
          searchingImages: "البحث عن الصور...",
          noImagesFound: "لم يتم العثور على صور",
          generateFlyer: "إنشاء نشرة PDF",
        },
        // Offer Templates
        offers: {
          title: "قوالب العروض",
          subtitle: "إنشاء وإدارة قوالب العروض",
          createOffer: "إنشاء عرض جديد",
          templateName: "اسم القالب",
          discountText: "نص الخصم (مثلاً: خصم 20%)",
          startDate: "تاريخ البداية",
          endDate: "تاريخ النهاية",
          description: "الوصف",
          active: "نشط",
          inactive: "غير نشط",
          noOffers: "لا توجد عروض بعد",
          createFirstOffer: "أنشئ قالب العرض الأول أعلاه!",
        },
        // Offer Product Selector
        selector: {
          title: "اختيار منتجات العرض",
          subtitle: "ربط المنتجات بالعروض",
          selectOffer: "اختر العرض",
          selectProducts: "اختر المنتجات",
          linkProducts: "ربط المنتجات بالعرض",
          save: "حفظ",
        },
        // Offer Manager
        manager: {
          title: "إدارة العروض",
          subtitle: "إدارة العروض النشطة",
          viewProducts: "عرض المنتجات",
          editOffer: "تعديل العرض",
          deleteOffer: "حذف العرض",
          toggleStatus: "تبديل الحالة",
        },
        // Pricing Manager
        pricing: {
          title: "إدارة الأسعار",
          subtitle: "تحديد الأسعار وحساب الأرباح",
          costPrice: "سعر التكلفة",
          sellingPrice: "سعر البيع",
          offerPrice: "سعر العرض",
          profit: "الربح",
          margin: "هامش الربح",
          calculate: "احسب",
          update: "تحديث",
        },
        // Flyer Generator
        generator: {
          title: "منشئ النشرات",
          subtitle: "إنشاء نشرات قابلة للطباعة من العروض",
          selectOffer: "اختر العرض",
          preview: "معاينة النشرة",
          generatePdf: "إنشاء نشرة PDF",
          noActiveOffers: "لا توجد عروض نشطة",
          createOffersFirst: "أنشئ العروض أولاً لإنشاء النشرات",
          selectOfferToPreview: "اختر عرضاً لمعاينة النشرة",
        },
        // Flyer Templates
        templates: {
          title: "قوالب النشرات",
          subtitle: "اختر تصميم قالب لنشراتك",
          applyTemplate: "تطبيق القالب",
          selected: "محدد",
          modernGradient: "تدرج حديث",
          boldRed: "أحمر جريء",
          freshGreen: "أخضر منعش",
          royalPurple: "بنفسجي ملكي",
          sunsetOrange: "برتقالي الغروب",
          oceanBlue: "أزرق المحيط",
        },
        // Flyer Settings
        settings: {
          title: "إعدادات النشرات",
          subtitle: "تكوين إعدادات إنشاء النشرات",
          companyInformation: "معلومات الشركة",
          companyName: "اسم الشركة",
          contactPhone: "هاتف الاتصال",
          email: "البريد الإلكتروني",
          address: "العنوان",
          displayOptions: "خيارات العرض",
          showPrices: "إظهار الأسعار",
          showBarcodes: "إظهار الباركود",
          showCompanyInfo: "إظهار معلومات الشركة",
          printSettings: "إعدادات الطباعة",
          pageSize: "حجم الصفحة",
          orientation: "الاتجاه",
          portrait: "عمودي",
          landscape: "أفقي",
          printQuality: "جودة الطباعة",
          draft: "مسودة",
          normal: "عادي",
          high: "عالي",
          saveSettings: "حفظ الإعدادات",
          settingsSaved: "تم حفظ الإعدادات!",
        },
      },
    },

    // Welcome
    welcome: {
      title: "مرحباً بك في أكوارا",
      subtitle: "منصة إدارة متطورة مع واجهة نوافذ متعددة",
      features: {
        multiWindow: "واجهة نوافذ متعددة لزيادة الإنتاجية",
        offline: "إمكانيات العمل دون اتصال للعمل السلس",
        responsive: "تصميم متجاوب يتكيف مع أي جهاز",
        bilingual: "دعم كامل ثنائي اللغة للإنجليزية والعربية",
      },
      instructions: "ابدأ باستكشاف الميزات أعلاه أو انغمس في وحدات الإدارة",
    },

    // Orders Manager
    orders: {
      manager: {
        title: "إدارة الطلبات",
        subtitle: "نظام إدارة طلبات العملاء",
      },
      stats: {
        new: "طلبات جديدة",
        inProgress: "قيد التنفيذ",
        completedToday: "مكتملة اليوم",
        revenue: "إجمالي الإيرادات اليوم",
      },
      filters: {
        search: "بحث",
        searchPlaceholder: "رقم الطلب، العميل، الهاتف",
        status: "الحالة",
        branch: "الفرع",
        payment: "طريقة الدفع",
        clear: "مسح الفلاتر",
      },
      payment: {
        cash: "نقداً",
        card: "بطاقة",
        online: "إلكتروني",
      },
      empty: {
        title: "لا توجد طلبات",
        message: "ستظهر الطلبات هنا عندما يقوم العملاء بتقديمها.",
        pending: "في انتظار ترحيل قاعدة البيانات. سيتم إنشاء جدول الطلبات قريباً.",
      },
      table: {
        orderNumber: "رقم الطلب",
        customer: "العميل",
        dateTime: "التاريخ والوقت",
        branch: "الفرع",
        total: "الإجمالي",
        payment: "الدفع",
        status: "الحالة",
        picker: "المحضّر",
        delivery: "التوصيل",
        actions: "الإجراءات",
      },
      detail: {
        title: "تفاصيل الطلب",
        customer: "معلومات العميل",
        name: "الاسم",
        address: "عنوان التوصيل",
        phone: "رقم الهاتف",
        assignments: "التكليفات",
        picker: "المحضّر",
        selectPicker: "اختر المحضّر",
        delivery: "مندوب التوصيل",
        selectDelivery: "اختر مندوب التوصيل",
        items: "عناصر الطلب",
        summary: "ملخص الطلب",
        subtotal: "المجموع الفرعي",
        deliveryFee: "رسوم التوصيل",
        total: "الإجمالي",
        paymentMethod: "طريقة الدفع",
        fulfillment: "طريقة الاستلام",
        timeline: "مسار الطلب",
        created: "تم إنشاء الطلب بواسطة العميل",
        actions: "إجراءات الطلب",
        accept: "قبول الطلب",
        cancel: "إلغاء الطلب",
        orderSlip: "إيصال الطلب",
        deliveryNote: "بيان التوصيل",
        invoice: "الفاتورة",
      },
    },

    // HR Master
    hr: {
      processFingerprint: {
        title: "معالجة بصمات الأصابع",
        analyze_all: "تحليل الكل",
        checkIn: "الدخول",
        checkOut: "الخروج",
        punch_time: "وقت البصمة",
        auto_filled: "تم ملؤها تلقائياً بناءً على الوردية",
        workedTime: "وقت العمل",
        process_with_data: "المعالجة مع البيانات",
        process_without_data: "المعالجة بدون بيانات",
        process_result: "نتائج المعالجة",
        start_process: "بدء المعالجة",
        loading_employees: "جاري تحميل الموظفين...",
        no_employees_with_finger: "لم يتم العثور على موظفين بحالة 'Job (With Finger)'.",
        total_transactions_processed: "إجمالي المعاملات المعالجة",
        fingerprint_machine_ids: "معرفات جهاز البصمة",
        actions: "الإجراءات",
        analyse: "تحليل",
        select_employees: "اختيار الموظفين",
        search_by_id_or_name: "ابحث بالرقم الوظيفي أو الاسم...",
        employees_selected: "تم اختيار {count} موظف(ين)",
        load_results: "تحميل النتائج",
        process_without_data_view: "سيتم تنفيذ عرض المعالجة بدون بيانات هنا.",
        select_process_type: "اختر نوع المعالجة للبدء",
        no_checkin_checkout_recorded: "لم يتم تسجيل دخول/خروج",
        no_transactions_recorded: "لم يتم تسجيل أي معاملات",
        checkin_missing: "تسجيل الدخول مفقود",
        checkout_missing: "تسجيل الخروج مفقود",
        late: "تأخير",
        early: "مبكر",
        overtime: "وقت إضافي",
        worked: "ساعات العمل",
        no_checkout_recorded: "لم يتم تسجيل خروج",
        no_checkin_recorded: "لم يتم تسجيل دخول",
        from_label: "من",
        load_transactions_title: "تحميل معاملات البصمة",
        load: "تحميل",
        summary_for: "ملخص الفترة من {startDate} إلى {endDate}",
        complete_days: "أيام كاملة",
        checkin_checkout_recorded: "تم تسجيل الدخول والخروج",
        incomplete_days: "أيام غير مكتملة",
        missing_checkin_checkout: "نقص في تسجيل الدخول أو الخروج",
        days_off_approved: "رسمي ومعتمد",
        no_recorded_punches: "لا توجد حركات مسجلة",
        total_late_time: "إجمالي وقت التأخير",
        overtime_across_days: "الوقت الإضافي عبر جميع الأيام",
        total_early_checkout: "إجمالي الخروج المبكر",
        undertime_across_days: "نقص الساعات عبر جميع الأيام",
        total_worked_hours: "إجمالي ساعات العمل",
        across_complete_days: "عبر {count} أيام عمل كاملة",
        expected_vs_actual: "المتوقع مقابل الفعلي",
        expected_total: "المتوقع: {count} ساعة إجمالي",
        total_punch_pairs: "إجمالي أزواج البصمات",
        no_transactions_found: "لم يتم العثور على عمليات للفترة المحددة",
        days_off: "أيام الإجازة",
        unapproved_leaves: "إجازات غير معتمدة",
        select_date_range_employees: "اختر النطاق الزمني والموظفين",
        date_range: "النطاق الزمني",
        ok: "موافق",
        no_processed_records_found: "لم يتم العثور على سجلات بصمة معالجة للمعايير المختارة",
        total_worked_hours_minutes: "إجمالي ساعات ودقائق العمل",
        total_under_worked_hours_minutes: "إجمالي ساعات ودقائق نقص العمل",
        total_late_hours_minutes: "إجمالي ساعات ودقائق التأخير",
        total_incomplete_days: "إجمالي الأيام غير المكتملة",
        total_unapproved_days_off: "إجمالي أيام الغياب غير المعتمدة",
        total_official_leave_days: "إجمالي أيام الإجازات الرسمية",
        total_approved_days_off: "إجمالي أيام الإجازات المعتمدة",
        total_expected_work_days: "إجمالي أيام العمل المتوقعة",
        total_worked_days_header: "إجمالي أيام العمل",
        expected_hours_minutes: "الساعات المتوقعة",
        actual_hours_minutes: "الساعات الفعلية",
        status_worked: "تم العمل",
        status_official_day_off: "إجازة رسمية",
        status_approved_leave: "إجازة معتمدة",
        status_unapproved_day_off: "غياب غير معتمد",
        status_incomplete: "غير مكتمل",
        load_analysis: "تحميل التحليل",
        processing: "جاري المعالجة...",
        select_range_to_begin: "اختر نطاقاً زمنياً واضغط على تحميل التحليل للبدء.",
        analyzing_all_moment: "جاري تحليل جميع الموظفين... قد يستغرق هذا لحظة.",
        sync_status: "حالة المزامنة",
        no_null_transactions: "ℹ️ لم يتم العثور على معاملات بحالة null في النطاق الزمني المحدد",
        late_abbr: "تأخير",
        underworked: "نقص عمل",
        total_days: "إجمالي الأيام"
      },
      employee: "موظف",
      employees: "الموظفون",
      employeeId: "رقم الموظف",
      firstName: "الاسم الأول",
      lastName: "اسم العائلة",
      fullName: "الاسم الكامل",
      branch: "الفرع",
      nationality: "الجنسية",
      employmentStatus: "الحالة الوظيفية",
      sponsorshipStatus: "حالة الكفالة",
      email: "البريد الإلكتروني",
      phone: "الهاتف",
      department: "القسم",
      designation: "المسمى الوظيفي",
      status: "الحالة",
      discipline: {
        managerTitle: "مدير فئات التحذير",
        addMainCategory: "إضافة فئة رئيسية",
        addSubCategory: "إضافة فئة فرعية",
        addViolation: "إضافة مخالفة",
        searchViolations: "البحث في المخالفات...",
        filterMain: "تصفية حسب الفئة الرئيسية",
        filterSub: "تصفية حسب الفئة الفرعية",
        allMain: "جميع الفئات الرئيسية",
        allSub: "جميع الفئات الفرعية",
        id: "المعرف",
        violationName: "اسم المخالفة",
        mainCategory: "الفئة الرئيسية",
        subCategory: "الفئة الفرعية",
        actions: "الإجراءات",
        issueWarning: "إصدار تحذير",
        reportIncident: "الإبلاغ عن حادثة",
        noViolations: "لم يتم العثور على مخالفات تطابق بحثك.",
        idAutoGenerated: "المعرف (توليد تلقائي)",
        nameEn: "الاسم (إنجليزي)",
        nameAr: "الاسم (عربي)",
        enterEnName: "أدخل الاسم بالإنجليزي",
        enterArName: "أدخل الاسم بالعربي",
        selectMain: "اختر الفئة الرئيسية",
        selectSub: "اختر الفئة الفرعية",
      },
      branch: "الفرع",
      manager: "المدير",
      joinDate: "تاريخ الانضمام",
      active: "نشط",
      inactive: "غير نشط",
      pending: "في الانتظار",
      nationality: "الجنسية",
      employmentStatus: "حالة التوظيف",
      sponsorshipStatus: "حالة الكفالة",
      // Biometric Data Dashboard
      biometricData: "بيانات المقاييس البيومترية",
      presentToday: "الحاضرون اليوم",
      invalidDate: "تاريخ غير صحيح",
      branchBreakdown: "توزيع الفروع",
      syncStatus: "حالة المزامنة",
      noSyncData: "لا توجد بيانات مزامنة",
      checkIn: "تسجيل الدخول",
      checkOut: "تسجيل الخروج",
      breakIn: "استراحة دخول",
      breakOut: "استراحة خروج",
      overtimeIn: "وقت إضافي دخول",
      overtimeOut: "وقت إضافي خروج",
      allFingerprint: "جميع معاملات البصمات",
      searchBy: "البحث حسب",
      name: "الاسم",
      position: "المنصب",
      date: "التاريخ",
      time: "الوقت",
      allDates: "جميع التواريخ",
      allBranches: "جميع الفروع",
      clearFilters: "مسح المرشحات",
      clearSearch: "مسح",
      search: "بحث",
      showing: "عرض",
      of: "من",
      transactions: "معاملات",
      prev: "السابق",
      next: "التالي",
      page: "صفحة",
      allStatus: "جميع الحالات",
      loadLast30Days: "تحميل آخر 30 يومًا",
      loadSpecificEmployee: "تحميل لموظف محدد",
      loadSpecificPeriod: "تحميل لفترة محددة",
      searchPlaceholder: "البحث بالاسم أو الرقم الوظيفي...",
      resultsInfo: "عرض {current} من {total} معاملات",
      loadToday: "اليوم",
      loadSpecificDate: "تاريخ محدد",
      loadDateRange: "نطاق التاريخ",
      loadAllData: "جميع البيانات",
      loadData: "تحميل البيانات",
      selectDateRangeError: "يرجى تحديد كل من تاريخي البداية والنهاية",
      exportToExcel: "تصدير إلى Excel",
      exportPlaceholder: "ستكون وظيفة التصدير متاحة هنا قريبًا.",
      filters: "الفلاتر",
      startDate: "تاريخ البداية",
      endDate: "تاريخ النهاية",
      exportInfo: "اختر نطاق التاريخ وفلتر الفرع الاختياري، ثم انقر فوق تصدير لتنزيل ملف Excel مع الأعمدة التالية:",
      exportData: "تصدير البيانات",
      exporting: "جاري التصدير...",
      // HR Master Dashboard
      masterTitle: "لوحة مراقبة إدارة الموارد البشرية",
      masterSubtitle: "نظام إدارة الموارد البشرية الشامل",
      masterUploadEmployees: "تحميل الموظفين",
      masterUploadEmployeesDesc: "استيراد الموظفين من ملف Excel",
      masterCreateDepartment: "إنشاء قسم",
      masterCreateDepartmentDesc: "إضافة أقسام تنظيمية جديدة",
      masterCreateLevel: "إنشاء مستوى",
      masterCreateLevelDesc: "تحديد مستويات الهرمية التنظيمية",
      masterCreatePosition: "إنشاء منصب",
      masterCreatePositionDesc: "إعداد الوظائف والأدوار",
      masterReportingMap: "خريطة الإبلاغ",
      masterReportingMapDesc: "تحديد علاقات الإبلاغ والهرمية",
      masterAssignPositions: "تعيين المناصب",
      masterAssignPositionsDesc: "تعيين المناصب للموظفين",
      masterBiometricData: "بيانات البصمة",
      masterBiometricDataDesc: "استيراد بيانات حضور البصمة",
      masterContactManagement: "إدارة جهات الاتصال",
      masterContactManagementDesc: "إدارة معلومات الاتصال للموظفين",
      masterDocumentManagement: "إدارة المستندات",
      masterDocumentManagementDesc: "إدارة مستندات وشهادات الموظفين",
      masterSalaryManagement: "إدارة الراتب والأجور",
      masterSalaryManagementDesc: "إدارة رواتب الموظفين والبدلات والخصومات",
      
      // مكون تحميل الموظفين
      uploadEmployeesTitle: "تحميل الموظفين",
      uploadEmployeesSubtitle: "استيراد بيانات الموظفين من ملف Excel",
      selectBranchLabel: "اختر الفرع",
      chooseBranch: "اختر الفرع *",
      selectABranch: "اختر فرعاً...",
      uploadExcelFileLabel: "تحميل ملف Excel",
      dropYourExcelFile: "أفلت ملف Excel الخاص بك هنا",
      orClickToBrowse: "أو انقر لتصفح الملفات",
      supportedFormats: "الصيغ المدعومة: .xlsx, .xls",
      excelTemplateLabel: "قالب Excel",
      requiredFormat: "الصيغة المطلوبة",
      yourExcelFileShouldContain: "يجب أن يحتوي ملف Excel على عمودين بالضبط:",
      employeeIdLabel: "رقم الموظف",
      employeeIdDesc: "معرّف فريد",
      nameLabel: "الاسم",
      nameDesc: "الاسم الكامل للموظف",
      downloadTemplate: "تحميل القالب",
      uploadEmployeesBtn: "تحميل الموظفين",
      uploading: "جاري التحميل...",
      pleaseSelectBranch: "يرجى اختيار فرع",
      pleaseSelectFile: "يرجى اختيار ملف للتحميل",
      excelFileEmpty: "ملف Excel فارغ أو لا يحتوي على بيانات صحيحة",
      missingRequiredColumns: "الأعمدة المفقودة:",
      rowNumber: "صف",
      missingEmployeeIdOrName: "رقم الموظف أو الاسم مفقود",
      uploadCompleted: "اكتمل التحميل لـ",
      successfullyUploaded: "تم التحميل بنجاح:",
      uploadedEmployeeCount: "موظفين",
      failedCount: "فشل:",
      errors: "أخطاء:",
      andMoreErrors: "وأخطاء أخرى",
      failedToProcessExcel: "فشل معالجة ملف Excel:",
      selectExcelFile: "يرجى اختيار ملف Excel (.xlsx أو .xls)",
      failedToLoadBranches: "فشل تحميل الفروع: ",
      salary: {
        title: "إدارة الرواتب والأجور",
        id: "رقم الموظف",
        name: "الاسم",
        branch: "الفرع",
        nationality: "الجنسية",
        sponsorship: "الحالة الكفالة",
        idNumber: "رقم الهوية",
        bankInfo: "معلومات البنك",
        basicSalary: "الراتب الأساسي",
        otherAllowance: "بدلات أخرى",
        accommodation: "بدل سكن",
        foodAllowance: "بدل طعام",
        travel: "بدل مواصلات",
        gosiDeduction: "خصم التأمينات",
        totalSalary: "إجمالي الراتب",
        actions: "الإجراءات",
        edit: "تعديل",
        add: "إضافة",
        bank: "بنك",
        cash: "نقدي",
        refresh: "تحديث",
        saving: "جاري الحفظ...",
        saveAll: "حفظ الكل",
        editSalaryFor: "تعديل راتب -",
        usePercentageOfBasic: "استخدام % من الأساسي",
        usePercentageOfBasicAndAccom: "استخدام % من (الأساسي + السكن)",
        cancel: "إلغاء",
        noEmployeesFound: "لم يتم العثور على موظفين",
        active: "نشط",
        inactive: "غير نشط",
        invalidBasicSalary: "يرجى إدخال راتب أساسي صحيح",
        failedToSave: "فشل في حفظ بيانات الراتب",
        failedToLoadEmployees: "فشل في تحميل بيانات الموظفين",
        createDepartment: "إنشاء قسم",
        createLevel: "إنشاء مستوى",
        createPosition: "إنشاء منصب",
        reportingMap: "خريطة التقارير",
        assignPositions: "تعيين المناصب",
        linkID: "ربط الهوية",
        employeeFiles: "ملفات الموظفين",
        fingerprintTransactions: "عمليات البصمة",
        processFingerprint: "معالجة البصمة",
        salaryAndWage: "الراتب والأجور",
        shiftAndLeave: "الوردية والإجازات",
        leavesAndVacations: "الإجازات والعطلات",
        discipline: "الانضباط",
        exportBiometricData: "تصدير البيانات الحيوية",
      },
      shift: {
        shift_details: "تفاصيل الوردية",
        shift_start: "بداية الوردية",
        shift_end: "نهاية الوردية",
        total_working_hours: "إجمالي ساعات العمل",
        no_shift_configured: "لا توجد وردية مكونة لهذا الموظف",
        tabs: {
          shift: "الورديات",
          special_shift: "الورديات الخاصة",
          day_off: "الإجازات",
          day_off_reasons: "أسباب الإجازات",
          regular: "الوردية العادية",
          special_weekday: "الوردية الخاصة (حسب يوم الأسبوع)",
          special_date: "الوردية الخاصة (حسب التاريخ)",
          day_off_date: "إجازة (حسب التاريخ)",
          day_off_weekday: "إجازة (حسب يوم الأسبوع)",
        },
        loading_regular_data: "جاري تحميل بيانات الوردية العادية...",
        loading_special_weekday_data: "جاري تحميل بيانات الوردية الخاصة (يوم الأسبوع)...",
        loading_special_date_data: "جاري تحميل بيانات الوردية الخاصة (التاريخ)...",
        loading_day_off_date_data: "جاري تحميل بيانات الإجازة (التاريخ)...",
        loading_day_off_weekday_data: "جاري تحميل بيانات الإجازة (يوم الأسبوع)...",
        filter_branch: "الفلترة حسب الفرع",
        all_branches: "جميع الفروع",
        filter_nationality: "الفلترة حسب الجنسية",
        all_nationalities: "جميع الجنسيات",
        all_statuses: "جميع الحالات",
        search_employee: "البحث عن موظف",
        search_placeholder: "ابحث بالاسم أو الرقم الوظيفي...",
        no_regular_shifts: "لم يتم العثور على ورديات عادية",
        no_special_shifts: "لم يتم العثور على ورديات خاصة",
        no_day_offs: "لم يتم العثور على إجازات",
        no_employees: "لم يتم العثور على موظفين",
        click_to_configure: "انقر على موظف لتكوين ورديته",
        click_to_assign_special: "انقر لتعيين ورديات خاصة للموظفين",
        click_to_assign_recurring: "انقر لتعيين إجازات متكررة",
        click_to_assign_date: "انقر لتعيين إجازات لتاريخ محدد",
        try_adjusting_filters: "حاول تعديل الفلاتر",
        add_special_shift_weekday: "إضافة وردية خاصة (حسب يوم الأسبوع)",
        add_special_shift_date: "إضافة وردية خاصة (حسب التاريخ)",
        add_day_off_date: "إضافة إجازة (حسب التاريخ)",
        add_day_off_weekday: "إضافة إجازة (حسب يوم الأسبوع)",
        shift_weekday: "يوم الوردية",
        shift_date: "تاريخ الوردية",
        day_off_date: "تاريخ الإجازة",
        day_off_weekday: "يوم الإجازة",
        delete_shift_tooltip: "حذف هذه الوردية",
        delete_day_off_tooltip: "حذف هذه الإجازة",
        delete_tooltip: "حذف الوردية",
        edit_tooltip: "تعديل الوردية",
        add_tooltip: "إضافة وردية",
        loading_employees: "جاري تحميل الموظفين...",
        loading_special_shifts: "جاري تحميل الورديات الخاصة...",
        loading_day_off_data: "جاري تحميل بيانات الإجازات...",
        loading_special_date_wise: "جاري تحميل الورديات الخاصة (حسب التاريخ)...",
        add_edit_special_tooltip: "إضافة أو تعديل وردية خاصة",
        delete_special_tooltip: "حذف الوردية الخاصة",
        add_special_date: "إضافة تاريخ خاص",
        add_special_range: "إضافة نطاق خاص",
        click_to_add_special: "انقر لإضافة وردية خاصة لتاريخ محدد",
        click_button_to_add: "انقر فوق الزر للإضافة",
        click_to_assign_day_off: "انقر لتعيين إجازة",
        showing_regular_shifts: "عرض {current} من {total} موظف(ين)",
        showing_special_shifts: "عرض {current} من {total} وردية(ورديات) خاصة",
        showing_day_offs: "عرض {current} من {total} إجازة(إجازات)",
        showing_employees_filter: "عرض {current} من {total} موظفاً",
        showing_employees: "عرض {count} موظف(ين)",
        showing_shifts: "عرض {current} من {total} وردية",
        shift_configuration: "إعدادات الوردية",
        configuring_for: "إعداد لـ",
        start: "البداية",
        end: "النهاية",
        start_buffer: "وقت عازل للبداية",
        end_buffer: "وقت عازل للنهاية",
        overlaps: "تداخل",
        hours: "ساعات",
        working_hours: "ساعات العمل",
        regularShift: "الوردية العادية",
        buffer_before: "وقت عازل قبل",
        buffer_after: "وقت عازل بعد",
        midnight_shift: "وردية منتصف الليل",
        midnight_shift_hint: "تنتهي الوردية في اليوم التالي",
        specify_working_hours: "تحديد ساعات العمل",
        working_hours_hint: "تجاوز المدة المحسوبة للحضور",
        working_hours_calculation_hint: "سيتم استخدام هذا للحسابات بدلاً من (وقت النهاية - وقت البداية)",
        save_configuration: "حفظ الإعدادات",
        configure_regular_shift: "تكوين الوردية العادية",
        configure_special_shift_weekday: "تكوين الوردية الخاصة (حسب يوم الأسبوع)",
        configure_special_shift_date: "تكوين الوردية الخاصة (حسب التاريخ)",
        assign_day_off_date: "تعيين إجازة (حسب التاريخ)",
        assign_day_off_weekday: "تعيين إجازة (حسب يوم الأسبوع)",
        select_weekday: "اختر يوم الأسبوع",
        shift_start_time: "وقت بداية الوردية",
        shift_end_time: "وقت نهاية الوردية",
        start_buffer_hours: "الوقت العازل للبداية (ساعات)",
        end_buffer_hours: "الوقت العازل للنهاية (ساعات)",
        shift_overlaps_next_day: "الوردية تتداخل مع اليوم التالي",
        select_employee: "اختر الموظف",
        choose_employee_special_shift_date: "اختر موظفًا لتعيين تاريخ وردية خاصة",
        choose_employee_day_off: "اختر موظفًا لتعيين إجازة",
        choose_employee_recurring_day_off: "اختر موظفًا لتعيين إجازة متكررة",
        no_employees_found: "لم يتم العثور على موظفين",
        official_day_off: "إجازة رسمية",
        day_off: "إجازة",
        approved_leave: "إجازة معتمدة",
        unapproved_leave: "إجازة غير معتمدة",
        delete_shift: "حذف الوردية",
        select_day_to_delete: "اختر اليوم المراد حذفه",
        select_weekday_to_delete: "اختر يوم الأسبوع للحذف",
        confirm_delete_shift_for: "هل أنت متأكد من حذف الوردية لـ {day}؟",
        confirm_delete_shift: "هل أنت متأكد من حذف هذه الوردية؟",
        confirm_delete_day_off: "هل أنت متأكد من حذف هذه الإجازة؟",
        error_failed_delete: "فشل الحذف: ",
        error_failed_save: "فشل حفظ بيانات الوردية: ",
        error_failed_save_day_off: "فشل حفظ الإجازة: ",
        error_select_employee_date: "يرجى اختيار موظف وتاريخ",
        error_select_employee_weekday: "يرجى اختيار موظف ويوم أسبوع",
        click_button_to_assign: "انقر فوق الزر أعلاه للتعيين",
        loading_day_off_reasons: "جاري تحميل أسباب الإجازة...",
        add_reason: "إضافة سبب",
        edit_reason: "تعديل السبب",
        delete_reason: "حذف السبب",
        add_day_off_reason: "إضافة سبب إجازة",
        edit_day_off_reason: "تعديل سبب إجازة",
        select_day_off_reason_title: "اختر سبب الإجازة",
        search_by_reason: "ابحث باسم السبب...",
        no_day_off_reasons: "لم يتم العثور على أسباب إجازة",
        click_button_to_add: "انقر فوق الزر أعلاه لإضافة سببك الأول",
        start_date: "تاريخ البدء",
        end_date: "تاريخ الانتهاء",
        search_reason: "البحث عن سبب الإجازة",
        selected_reason: "السبب المختار",
        selected_file: "محدد",
        deductible_yes: "قابل للخصم",
        deductible_no: "غير قابل للخصم",
        document_required_short: "الوثيقة مطلوبة",
        document_optional: "وثيقة اختيارية",
        upload_document_required: "رفع الوثيقة (مطلوب)",
        upload_document_optional: "رفع الوثيقة (اختياري)",
        description_optional: "الوصف (اختياري)",
        enter_description: "أدخل أي تفاصيل إضافية أو ملاحظات حول طلب الإجازة هذا...",
        description_info: "يمكنك إضافة أي معلومات إضافية قد تكون ذات صلة بهذا الطلب.",
        showing_total_reasons: "عرض {count} من أسباب الإجازة",
        ready_for_config: "جاهز للتكوين",
        reason_name_en: "السبب (إنجليزي)",
        reason_name_ar: "السبب (عربي)",
        enter_reason_en: "أدخل السبب بالإنجليزية",
        enter_reason_ar: "أدخل السبب بالعربية",
        is_deductible: "قابل للخصم؟",
        yes_deductible: "نعم - قابل للخصم",
        no_not_deductible: "لا - غير قابل للخصم",
        deductible: "قابل للخصم",
        document_required: "الوثيقة مطلوبة؟",
        yes_document_required: "نعم - الوثيقة مطلوبة",
        no_document_not_required: "لا - الوثيقة غير مطلوبة",
        error_failed_load: "فشل تحميل البيانات: ",
        errors: {
          fill_reason_names: "يرجى ملء أسماء الأسباب باللغتين الإنجليزية والعربية",
          select_employee_date_doc: "يرجى اختيار الموظف والتاريخ والوثيقة",
          start_before_end: "يجب أن يكون تاريخ البداية قبل أو مساوياً لتاريخ النهاية",
          select_day_off_reason: "يرجى اختيار سبب الإجازة",
          doc_mandatory: "الوثيقة إلزامية لهذا السبب. يرجى تحميل وثيقة",
        },
        // Mobile Day Off Request
        mobile_day_off_request: {
          title: "طلب إجازة",
          subtitle: "تقديم طلب إجازة",
          loading: "جاري التحميل...",
          startDate: "تاريخ البداية",
          endDate: "تاريخ النهاية",
          reason: "السبب",
          documentUpload: "تحميل الوثيقة",
          required: "مطلوب",
          optional: "اختياري",
          documentRequired: "الوثيقة مطلوبة",
          mandatoryNotice: "هذه الوثيقة إلزامية لهذا السبب",
          mustUploadFile: "يجب عليك تحميل ملف للمتابعة",
          selectFile: "المختار:",
          pleaseUploadDocument: "يرجى تحميل وثيقة للمتابعة",
          sendRequest: "إرسال الطلب",
          submitting: "جاري الإرسال...",
          chooseFile: "اختيار ملف",
          noFileChosen: "لم يتم اختيار ملف",
          takePhoto: "التقاط صورة",
          description: "الوصف",
          error: "خطأ",
          errorEmployeeNotFound: "لم يتم العثور على رقم الموظف. يرجى الاتصال بالإدارة.",
          requiredFields: "مطلوب",
          selectReason: "يرجى اختيار سبب الإجازة",
          selectDates: "يرجى اختيار تاريخ البداية والنهاية",
          invalidDateRange: "نطاق تاريخ غير صحيح",
          startBeforeEnd: "يجب أن يكون تاريخ البداية قبل أو مساوياً لتاريخ النهاية",
          documentRequiredError: "الوثيقة مطلوبة",
          uploadRelatedDocument: "يرجى تحميل وثيقة ذات صلة\n\nهذا السبب يتطلب مرفق وثيقة إلزامي.",
          successMessage: "تم تقديم طلب الإجازة لـ {days} يوم{plural}!",
          failedToSubmit: "فشل في تقديم الطلب",
          failedToLoadReasons: "فشل في تحميل أسباب الإجازة",
          errorLoadingReasons: "خطأ في تحميل الأسباب",
          failedToLoadEmployee: "فشل في تحميل معلومات الموظف",
          couldNotFindEmployee: "لم يتم العثور على سجل الموظف الخاص بك. يرجى الاتصال بالإدارة.",
        },
        // Punch permission messages
        permissions: {
          add_missing_punch: "إضافة بصمة مفقودة",
          permission_denied_title: "تم رفض الإذن",
          permission_denied_message: "ليس لديك إذن لإضافة بصمة.",
          contact_admin: "يرجى الاتصال بمسؤولك لطلب هذا الإذن.",
        },
        // Add punch modal
        addPunchModal: {
          deduction_percent: "نسبة الخصم %",
          deduction_placeholder: "أدخل نسبة الخصم (0-100)",
          deduction_minutes: "الخصم: {minutes} دقيقة ({hours} ساعة)",
          enter_percentage: "أدخل النسبة لحساب الخصم",
          auto_filled_based_on_shift: "تم التعبئة تلقائيًا بناءً على الوردية",
        }
      }
    },
    tasks: {
      createTaskTemplate: "إنشاء قالب مهمة",
      viewTaskTemplates: "عرض قوالب المهام",
      assignTasks: "تعيين المهام",
      viewMyTasks: "عرض مهامي",
      viewMyAssignments: "عرض تكليفاتي",
      taskStatus: "حالة المهمة",
      branchPerformance: "أداء الفرع",
    },

    // Branches Master
    branches: {
      branch: "فرع",
      branches: "الفروع",
      branchId: "رقم الفرع",
      branchName: "اسم الفرع",
      branchCode: "كود الفرع",
      region: "المنطقة",
      address: "العنوان",
      timezone: "المنطقة الزمنية",
      contactPerson: "جهة الاتصال",
      contactEmail: "بريد الاتصال",
      contactPhone: "هاتف الاتصال",
      // New fields for multilingual support
      createBranch: "إنشاء فرع",
      nameEnglish: "الاسم (إنجليزي)",
      nameArabic: "الاسم (عربي)",
      locationEnglish: "الموقع (إنجليزي)",
      locationArabic: "الموقع (عربي)",
      save: "حفظ",
      cancel: "إلغاء",
      edit: "تعديل",
      update: "تحديث",
      delete: "حذف",
      active: "نشط",
      inactive: "غير نشط",
      mainBranch: "الفرع الرئيسي",
      createdAt: "تاريخ الإنشاء",
      updatedAt: "تاريخ التحديث",
      actions: "الإجراءات",
    },

    // Vendors Master
    vendors: {
      vendor: "مورد",
      vendors: "الموردون",
      vendorId: "رقم المورد",
      vendorName: "اسم المورد",
      taxId: "الرقم الضريبي",
      contactPerson: "جهة الاتصال",
      email: "البريد الإلكتروني",
      phone: "الهاتف",
      address: "العنوان",
      paymentTerms: "شروط الدفع",
      categories: "الفئات",
      category: "فئة",
      selectCategories: "اختر الفئات",
      addCustomCategory: "إضافة فئة مخصصة",
      customCategory: "فئة مخصصة",
      enterCategoryName: "أدخل اسم الفئة",
      dailyFresh: "طازج يومي",
      wholesaler: "تاجر جملة",
      companyDistributor: "موزع الشركة",
      salesVan: "عربة المبيعات",
      maintenanceRelated: "متعلق بالصيانة",
      deliveryModes: "طرق التسليم",
      deliveryMode: "طريقة التسليم",
      selectDeliveryModes: "اختر طرق التسليم",
      addCustomDeliveryMode: "إضافة طريقة تسليم مخصصة",
      customDeliveryMode: "طريقة تسليم مخصصة",
      enterDeliveryModeName: "أدخل اسم طريقة التسليم",
      directPickUp: "استلام مباشر",
      deliveryOnSite: "التسليم في الموقع",
      deliveryToParcelCompanies: "التسليم لشركات الطرود",
      place: "المكان",
      placeArea: "المكان/المنطقة",
      location: "الموقع",
      locationLink: "رابط الموقع",
      openLocation: "فتح الموقع",
      openMap: "فتح الخريطة",
      noPlace: "لا يوجد مكان",
      noLocation: "لا يوجد موقع",
    },

    // Invoice Master
    invoices: {
      invoice: "فاتورة",
      invoices: "الفواتير",
      invoiceNo: "رقم الفاتورة",
      vendor: "المورد",
      branch: "الفرع",
      date: "تاريخ الفاتورة",
      dueDate: "تاريخ الاستحقاق",
      currency: "العملة",
      subtotal: "المجموع الفرعي",
      tax: "الضريبة",
      total: "المجموع الكلي",
      status: "الحالة",
      draft: "مسودة",
      posted: "مرسلة",
      paid: "مدفوعة",
      attachments: "المرفقات",
    },

    // Import System
    import: {
      title: "استيراد البيانات",
      uploadFile: "رفع ملف",
      selectFile: "اختر ملف Excel",
      dragDrop: "اسحب وأفلت ملفك هنا",
      processing: "جاري المعالجة...",
      mapping: "ربط الأعمدة",
      preview: "معاينة البيانات",
      validation: "نتائج التحقق",
      errors: "أخطاء",
      warnings: "تحذيرات",
      valid: "سجلات صحيحة",
      invalid: "سجلات غير صحيحة",
      commitChanges: "تطبيق التغييرات",
      rollback: "التراجع",
      importComplete: "تم الاستيراد بنجاح",
      importFailed: "فشل الاستيراد",
      recordsProcessed: "سجل تمت معالجته",
      recordsCommitted: "سجل تم تطبيقه",
      recordsFailed: "سجل فشل",
    },

    // ERP System
    erp: {
      connections: "اتصالات ERP",
      addConfiguration: "إضافة إعداد",
      editConfiguration: "تعديل الإعداد",
      newConfiguration: "إعداد جديد",
      branch: "الفرع",
      selectBranch: "اختر الفرع",
      deviceId: "معرف الجهاز",
      deviceIdHint: "سيتم تفويض هذا الجهاز لمزامنة بيانات المبيعات",
      serverIp: "عنوان IP للخادم",
      serverName: "اسم الخادم",
      databaseName: "اسم قاعدة البيانات",
      username: "اسم المستخدم",
      password: "كلمة المرور",
      isActive: "نشط",
      testConnection: "اختبار الاتصال",
      testing: "جاري الاختبار...",
      connectionSuccess: "تم الاتصال بنجاح!",
      connectionFailed: "فشل الاتصال",
      saveConfiguration: "حفظ الإعداد",
      saving: "جاري الحفظ...",
      fetchSales: "جلب المبيعات",
      fetching: "جاري الجلب...",
      selectDate: "اختر التاريخ",
      salesData: "بيانات المبيعات",
      grossSales: "إجمالي المبيعات",
      grossBills: "إجمالي الفواتير",
      grossTax: "إجمالي الضريبة",
      returns: "المرتجعات",
      returnBills: "فواتير المرتجعات",
      returnTax: "ضريبة المرتجعات",
      netSales: "صافي المبيعات",
      netBills: "صافي الفواتير",
      netTax: "صافي الضريبة",
      discount: "الخصم",
      noSalesData: "لم يتم العثور على بيانات مبيعات للتاريخ المحدد",
      configurationSaved: "تم حفظ الإعداد بنجاح",
      configurationDeleted: "تم حذف الإعداد بنجاح",
      confirmDelete: "هل أنت متأكد من حذف هذا الإعداد؟",
    },

    // Common Actions
    actions: {
      add: "إضافة",
      edit: "تعديل",
      delete: "حذف",
      save: "حفظ",
      cancel: "إلغاء",
      confirm: "تأكيد",
      yes: "نعم",
      no: "لا",
      ok: "موافق",
      apply: "تطبيق",
      reset: "إعادة تعيين",
      clear: "مسح",
      search: "بحث",
      filter: "تصفية",
      sort: "ترتيب",
      export: "تصدير",
      import: "استيراد",
      upload: "رفع",
      download: "تنزيل",
      print: "طباعة",
      refresh: "تحديث",
      back: "رجوع",
      next: "التالي",
      previous: "السابق",
      continue: "متابعة",
      finish: "إنهاء",
    },

    // Common Messages
    common: {
      alert: "تنبيه",
      requiredFields: "حقول مطلوبة",
      invalidSelection: "اختيار غير صالح",
      invalidDateRange: "نطاق تاريخ غير صالح",
      saveError: "خطأ في الحفظ",
      deleteError: "خطأ في الحذف",
      uploadError: "خطأ في الرفع",
      documentRequired: "الوثيقة مطلوبة",
      confirmDelete: "هل أنت متأكد من حذف هذا العنصر؟",
      noData: "لا توجد بيانات",
      no_data: "غير متاح",
      success: "نجح",
      fullName: "الاسم الكامل",
      status: "الحالة",
      loading: "جاري التحميل...",
      today: "اليوم",
      yesterday: "أمس",
      branch: "الفرع",
      chooseBranch: "اختر الفرع",
      selectBranch: "اختر الفرع",
      error: "حدث خطأ",
      retry: "إعادة المحاولة",
      action: "الإجراء",
      edit: "تعديل",
      save: "حفظ",
      cancel: "إلغاء",
      saving: "جاري الحفظ...",
      delete: "حذف",
      deleting: "جاري الحذف...",
      processing: "جاري المعالجة...",
      yes: "نعم",
      no: "لا",
      date: "التاريخ",
      hours: "ساعات",
      hrs: "ساعة",
      minutes: "دقائق",
      min: "دقيقة",
      h: "ساعة",
      m: "دقيقة",
      am: "صباحاً",
      pm: "مساءً",
      unknown_error: "خطأ غير معروف",
      action_cannot_be_undone: "هذا الإجراء لا يمكن التراجع عنه.",
      rememberDevice: "تذكر هذا الجهاز",
      optional: "اختياري",
      autoDetected: "تم الكشف تلقائياً",
      unknown: "غير معروف",
      view: "عرض",
      reason: "السبب",
      description: "الوصف",
      document: "وثيقة",
      note: "ملاحظة",
      no_document: "لا توجد وثيقة",
      approved: "معتمد",
      rejected: "مرفوض",
      pending: "قيد الانتظار",
      sent_for_approval: "أرسل للموافقة",
      or: "أو",
      users: "المستخدمين",
      customer: "العميل",
      selectLoginType: "اختر نوع تسجيل الدخول",
      chooseAccountType: "اختر نوع حسابك للمتابعة",
      customerLogin: "تسجيل دخول العميل",
      teamLogin: "تسجيل دخول الفريق",
      employeeLogin: "تسجيل دخول الفريق",
      all: "الكل",
      sar: "ريال",
      print: "طباعة",
      printed: "تم الطباعة",
      cancel: "إلغاء",
      close: "إغلاق",
      start: "بدء",
      starting: "جاري البدء...",
      total: "الإجمالي",
      validating: "جاري التحقق...",
      tryAgain: "حاول مرة أخرى",
      back: "رجوع",
      backToLogin: "العودة لتسجيل الدخول",
      refresh: "تحديث",
      active: "نشط",
      inactive: "غير نشط",
      // أيام الأسبوع
      days: {
        monday: "الاثنين",
        tuesday: "الثلاثاء",
        wednesday: "الأربعاء",
        thursday: "الخميس",
        friday: "الجمعة",
        saturday: "السبت",
        sunday: "الأحد",
      },
      // صفحة تسجيل دخول سطح المكتب
      backToInterfaceChoice: "العودة لاختيار الواجهة",
      usernameAndPassword: "اسم المستخدم و كلمة المرور",
      traditionalLoginMethod: "طريقة تسجيل الدخول التقليدية",
      quickAccessCode: "رمز الوصول السريع",
      sixDigitSecureAccess: "وصول آمن برمز سداسي الأرقام",
      welcomeBack: "أهلاً وسهلاً بعودتك",
      enterCredentials: "أدخل بيانات اعتمادك للوصول إلى النظام",
      username: "اسم المستخدم",
      enterUsername: "أدخل اسم المستخدم",
      usernameMustBeThreeCharacters: "يجب أن يكون اسم المستخدم 3 أحرف على الأقل",
      password: "كلمة المرور",
      enterPassword: "أدخل كلمة المرور",
      passwordMustBeSixCharacters: "يجب أن تكون كلمة المرور 6 أحرف على الأقل",
      rememberMeThirtyDays: "تذكري لمدة 30 يوماً",
      signingIn: "جاري تسجيل الدخول...",
      signInToSystem: "تسجيل الدخول إلى النظام",
      quickAccess: "الوصول السريع",
      enterSixDigitSecurityCode: "أدخل رمز الأمان السداسي",
      securityCode: "رمز الأمان",
      enterValidSixDigitCode: "أدخل رمز أمان سداسي صحيح",
      rememberThisDevice: "تذكر هذا الجهاز",
      accessing: "جاري الوصول...",
      accessSystem: "الوصول إلى النظام",
      authenticationFailed: "فشل المصادقة",
      accessGranted: "تم منح الوصول",
      showResolved: "إظهار الطلبات المحلولة",
      time: "الوقت",
      requests: "الطلبات",
      processedThisWeek: "تمت معالجتها هذا الأسبوع",
      verificationRequired: "يتطلب التحقق",
      resolved: "تم الحل",
      verifyIdentity: "التحقق من الهوية",
      generateShare: "إنشاء ومشاركة الرمز",
      markResolved: "وضع علامة كمحلول",
      requestResolved: "تم حل الطلب",
    },

    // Status Messages
    status: {
      success: "نجح",
      error: "خطأ",
      warning: "تحذير",
      info: "معلومات",
      loading: "جاري التحميل...",
      saving: "جاري الحفظ...",
      processing: "جاري المعالجة...",
      complete: "مكتمل",
      failed: "فشل",
      cancelled: "ملغي",
      pending: "في الانتظار",
    },

    // Validation Messages
    validation: {
      required: "هذا الحقل مطلوب",
      email: "يرجى إدخال بريد إلكتروني صحيح",
      phone: "يرجى إدخال رقم هاتف صحيح",
      minLength: "الحد الأدنى {min} أحرف",
      maxLength: "الحد الأقصى {max} حرف",
      numeric: "يرجى إدخال رقم صحيح",
      date: "يرجى إدخال تاريخ صحيح",
      passwordMismatch: "كلمات المرور غير متطابقة",
      weakPassword: "كلمة المرور ضعيفة",
      invalidFormat: "تنسيق غير صحيح",
      duplicateValue: "هذه القيمة موجودة بالفعل",
      invalidRange: "القيمة يجب أن تكون بين {min} و {max}",
    },

    // Empty States
    empty: {
      noData: "لا توجد بيانات متوفرة",
      noResults: "لم يتم العثور على نتائج",
      noFiles: "لم يتم رفع ملفات",
      noWindows: "لا توجد نوافذ مفتوحة",
      noNotifications: "لا توجد إشعارات",
      noHistory: "لا يوجد تاريخ متوفر",
      tryAgain: "حاول مرة أخرى",
      getStarted: "ابدأ بإضافة العنصر الأول",
    },

    // Approvals
    approvals: {
      pending: "قيد الانتظار",
      approved: "موافق عليه",
      rejected: "مرفوض",
      total: "الإجمالي",
      noRequisitions: "لم يتم العثور على طلبات",
    },

    // Customer Interface
    customer: {
      customerName: "اسم العميل",
      companyName: "اسم الشركة",
      username: "اسم المستخدم", 
      mobileNumber: "رقم جوال العميل",
      whatsappNumber: "رقم الجوال",
      status: "الحالة",
      registrationDate: "تاريخ التسجيل",
      
      // Customer Login
      login: {
        title: "بوابة العملاء",
        subtitle: "الوصول إلى حساب العميل",
        pageSubtitle: "الوصول إلى حسابك وخدماتك",
        interfaceOption: "تسجيل دخول العملاء",
        welcomeTitle: "مرحباً بكم في بوابة عملاء أكورا",
        welcomeSubtitle: "وصول آمن لعملائنا الكرام",
        username: "اسم المستخدم",
        usernamePlaceholder: "أدخل اسم المستخدم",
        accessCode: "رمز الوصول",
        accessCodePlaceholder: "أدخل رمز الوصول المكون من 6 أرقام",
        loginButton: "تسجيل الدخول",
        loggingIn: "جاري تسجيل الدخول...",
        viewLatestOffers: "عرض أحدث العروض",
        followUs: "تابعنا",
        loyaltyMemberLogin: "تسجيل دخول عضو الولاء",
        loyaltyMemberTitle: "تسجيل دخول عضو الولاء",
        loyaltyMemberSubtitle: "أدخل رقم جوالك للدخول",
        loyaltyMobileLabel: "رقم الجوال",
        loyaltyMobileError: "يرجى إدخال رقم جوال صحيح (05XXXXXXXX)",
        loyaltyLoggingIn: "جاري تسجيل الدخول...",
        loyaltySubmit: "متابعة",
        cardNotRegistered: "هذا رقم البطاقة غير مسجل في برنامج الولاء",
        cardHolderName: "حامل البطاقة",
        cardBalance: "الرصيد",
        cardNumber: "رقم البطاقة",
        expiryDate: "تاريخ انتهاء الصلاحية",
        loyaltyDetails: "تفاصيل عضو الولاء",
        loyaltyDetailsTitle: "تفاصيل عضو الولاء",
        loyaltyCard: "بطاقة الولاء",
        branchDetails: "تفاصيل الفرع",
        activeCard: "نشطة",
        availableBalance: "الرصيد المتاح",
        points: "نقاط",
        totalRedemptions: "إجمالي الاسترجاعات",
        redemptionCount: "عدد الاسترجاعات",
        lastSyncAt: "آخر تحديث",
        recentActivity: "النشاط الأخير",
        noRecentActivity: "لا يوجد نشاط حديث",
        loyaltyCardFooter: "شكراً لك لكونك عضواً قيماً",
        goToHome: "الذهاب للرئيسية",
        multipleLocations: "البطاقة مسجلة في عدة مواقع",
        forgotCredentials: "نسيت اسم المستخدم أو رمز الوصول؟",
        requestNewAccess: "طلب استرداد الحساب",
        needNewAccess: "تحتاج لاسترداد حسابك؟",
        backToLogin: "العودة لتسجيل الدخول",
        
        // Forgot credentials section
        forgotTitle: "استرداد الحساب",
        forgotSubtitle: "سنساعدك في استرداد حسابك",
        whatsappLabel: "رقم الجوال",
        whatsappPlaceholder: "5X XXX XXXX",
        submitRequest: "إرسال طلب الاسترداد",
        submittingRequest: "جاري إرسال الطلب...",
        requestSubmitted: "تم إرسال طلب الاسترداد بنجاح",
        requestSubmittedMessage: "سيقوم أحد المشرفين بالتحقق من هويتك وإرسال بيانات الدخول عبر الواتساب قريباً.",
        
        // Registration section
        registerTitle: "تسجيل عميل جديد",
        registerSubtitle: "انضم إلى بوابة عملاء أكورا",
        customerName: "الاسم الكامل",
        customerNamePlaceholder: "أدخل اسمك الكامل",
        email: "البريد الإلكتروني (اختياري)",
        emailPlaceholder: "أدخل عنوان البريد الإلكتروني",
        registerButton: "إرسال التسجيل",
        registering: "جاري إرسال التسجيل...",
        registrationSubmitted: "تم إرسال التسجيل بنجاح",
        registrationMessage: "تم إرسال تسجيلك للموافقة عليه. ستتلقى بيانات تسجيل الدخول عبر الواتساب بمجرد الموافقة.",
        alreadyHaveAccount: "هل لديك حساب بالفعل؟ سجل الدخول",
        needNewAccount: "ليس لديك حساب؟",
        
        // Error messages
        errors: {
          usernameRequired: "اسم المستخدم مطلوب",
          accessCodeRequired: "رمز الوصول مطلوب",
          invalidCredentials: "اسم المستخدم أو رمز الوصول غير صحيح",
          accountNotApproved: "حسابك في انتظار الموافقة",
          whatsappRequired: "رقم الجوال مطلوب",
          customerNameRequired: "الاسم الكامل مطلوب",
          invalidWhatsappFormat: "يرجى إدخال رقم جوال صحيح",
          accessCodeLength: "رمز الوصول يجب أن يكون 6 أرقام",
          tooManyRequests: "طلبات كثيرة جداً. يرجى المحاولة لاحقاً",
          networkError: "خطأ في الشبكة. يرجى التحقق من اتصالك",
          serverError: "خطأ في الخادم. يرجى المحاولة لاحقاً",
          registrationFailed: "فشل التسجيل. يرجى المحاولة مرة أخرى",
          recoveryFailed: "فشل طلب الاسترداد. يرجى المحاولة مرة أخرى",
        },
        
        // Success messages
        success: {
          loginSuccessful: "تم تسجيل الدخول بنجاح! مرحباً بعودتك",
          requestSent: "تم إرسال طلب الاسترداد بنجاح",
          registrationSent: "تم إرسال التسجيل بنجاح",
        },
        
        // Interface selection
        interface: {
          desktop: "واجهة سطح المكتب",
          mobile: "واجهة الجوال",
          customer: "بوابة العملاء",
          selectInterface: "اختر واجهتك",
          customerDescription: "بوابة آمنة لوصول العملاء",
          mobileDescription: "محسّنة للأجهزة المحمولة",
          desktopDescription: "تجربة سطح المكتب الكاملة",
        },
      },
      
      // Follow Us
      followUs: {
        title: "تابعنا",
        noBranches: "لا توجد فروع متاحة",
        noLinks: "لا توجد روابط تواصل متاحة لهذا الفرع",
      },
      
      // Customer notifications
      notifications: {
        welcome: "مرحباً بك في بوابة عملاء أكورا",
        accountApproved: "تمت الموافقة على حساب العميل الخاص بك",
        accessCodeSent: "تم إرسال رمز الوصول الجديد الخاص بك",
        accountRecovery: "تم استلام طلب استرداد الحساب",
        credentialsShared: "تم مشاركة بيانات تسجيل الدخول الخاصة بك عبر الواتساب",
        registrationReceived: "تم استلام طلب التسجيل وهو قيد المراجعة",
      },

      // Customer dashboard
      dashboard: {
        title: "لوحة تحكم العميل",
        welcome: "مرحباً بك في بوابتك",
        defaultCompany: "عميل مُقدر",
        accessCode: "رمز الوصول",
        accountStatus: "حالة الحساب",
        
        status: {
          approved: "حسابك معتمد ونشط",
          pending: "حسابك في انتظار الموافقة",
          rejected: "تم رفض الوصول إلى حسابك",
          pendingDescription: "فريقنا يراجع تسجيلك. سيتم إشعارك بمجرد الموافقة.",
          rejectedDescription: "يرجى الاتصال بالدعم للحصول على المساعدة في الوصول إلى حسابك.",
        },

        features: {
          orders: "الطلبات والطلبات",
          ordersDescription: "عرض وإدارة طلباتك وطلبات الخدمة",
          viewOrders: "عرض الطلبات",
          
          support: "دعم العملاء",
          supportDescription: "احصل على المساعدة واتصل بفريق الدعم",
          contactSupport: "اتصل بالدعم",
          
          account: "إعدادات الحساب",
          accountDescription: "إدارة معلومات حسابك وتفضيلاتك",
          manageAccount: "إدارة الحساب",
          
          reports: "التقارير والتاريخ",
          reportsDescription: "الوصول إلى تاريخ المعاملات والتقارير",
          viewReports: "عرض التقارير",
        },

        contact: {
          title: "تحتاج مساعدة؟ اتصل بنا",
          email: "دعم البريد الإلكتروني",
          whatsapp: "دعم الواتساب",
          hours: "ساعات العمل",
          businessHours: "الأحد - الخميس، 9:00 ص - 6:00 م",
        },
      },
    },

    // نظام العروض
    offers: {
      badge: {
        off: "خصم",
        discount: "تخفيض",
        specialPrice: "سعر خاص",
        bogo: "اشتري واحصل",
        bundle: "باقة",
        cartDiscount: "خصم السلة",
        offer: "عرض",
      },
      noActiveOffers: "لا توجد عروض نشطة حالياً",
      usesRemaining: "استخدامات متبقية",
      viewDetails: "عرض التفاصيل",
      expiringSoon: {
        minutes: "ينتهي قريباً",
        hours: "ساعات متبقية",
      },
      modal: {
        validity: "فترة الصلاحية",
        startDate: "تاريخ البدء",
        endDate: "تاريخ الانتهاء",
        expiringSoon: "⚠️ هذا العرض ينتهي قريباً!",
        applicableProducts: "المنتجات المشمولة",
        bogoRules: "قواعد اشتري واحصل",
        buy: "اشتري",
        get: "احصل على",
        free: "مجاناً",
        bundleContents: "محتويات الباقة",
        bundlePrice: "سعر الباقة",
        cartTiers: "مستويات خصم السلة",
        spend: "أنفق",
        limits: "حدود الاستخدام",
        usesPerCustomer: "استخدامات لكل عميل",
        totalUsesRemaining: "إجمالي الاستخدامات المتبقية",
        shopNow: "تسوق الآن",
      },
    },

    // نظام إدارة الكوبونات
    coupon: {
      title: "إدارة الكوبونات",
      subtitle: "إدارة الحملات الترويجية وكوبونات الهدايا",
      manageCampaigns: "إدارة الحملات",
      campaignsDesc: "إنشاء وإدارة الحملات الترويجية",
      importCustomers: "استيراد العملاء",
      customersDesc: "رفع قوائم العملاء المؤهلين",
      manageProducts: "إدارة المنتجات",
      productsDesc: "إضافة وإدارة منتجات الهدايا",
      reportsStats: "التقارير والإحصائيات",
      reportsDesc: "عرض التحليلات والتقارير",
      activeCampaigns: "الحملات النشطة",
      noActiveCampaigns: "لا توجد حملات نشطة",
      createFirst: "إنشاء أول حملة لك",
      
      // Cashier login errors
      invalidAccessCode: "يرجى إدخال رمز وصول صحيح مكون من 6 أرقام",
      invalidBranchSelection: "اختيار فرع غير صحيح",
      
      // إدارة الحملات
      campaignDescription: "إنشاء الحملات وتحديد المواعيد وإدارة الشروط",
      createCampaign: "إنشاء حملة",
      editCampaign: "تعديل الحملة",
      campaignName: "اسم الحملة",
      nameEnglish: "اسم الحملة (إنجليزي)",
      nameArabic: "اسم الحملة (عربي)",
      campaignCode: "رمز الحملة",
      generate: "توليد",
      startDate: "تاريخ البدء",
      endDate: "تاريخ الانتهاء",
      maxClaimsPerCustomer: "الحد الأقصى للاستخدام لكل عميل",
      termsEnglish: "الشروط والأحكام (إنجليزي)",
      termsArabic: "الشروط والأحكام (عربي)",
      campaignActive: "الحملة نشطة",
      save: "حفظ",
      saving: "جاري الحفظ...",
      cancel: "إلغاء",
      edit: "تعديل",
      activate: "تفعيل",
      deactivate: "إيقاف",
      noCampaigns: "لا توجد حملات بعد",
      createFirstCampaign: "أنشئ حملتك الأولى للبدء",
      maxClaims: "الحد الأقصى",
      
      // الحالات
      statusActive: "نشطة",
      statusInactive: "متوقفة",
      statusScheduled: "مجدولة",
      statusExpired: "منتهية",
      
      // الرسائل
      campaignNameRequired: "اسم الحملة مطلوب باللغتين",
      campaignCodeRequired: "رمز الحملة مطلوب",
      datesRequired: "تاريخ البدء والانتهاء مطلوبان",
      campaignCreated: "تم إنشاء الحملة بنجاح",
      campaignUpdated: "تم تحديث الحملة بنجاح",
      campaignDeleted: "تم حذف الحملة بنجاح",
      campaignActivated: "تم تفعيل الحملة",
      campaignDeactivated: "تم إيقاف الحملة",
      confirmDeleteCampaign: "هل أنت متأكد من حذف هذه الحملة؟",
      errorLoadingCampaigns: "فشل تحميل الحملات",
      errorSavingCampaign: "فشل حفظ الحملة",
      errorDeletingCampaign: "فشل حذف الحملة",
      errorTogglingStatus: "فشل تحديث حالة الحملة",
      
      // استيراد العملاء
      customerImportDescription: "رفع أرقام جوال العملاء لجعلهم مؤهلين",
      downloadTemplate: "تحميل القالب",
      selectCampaign: "اختر الحملة",
      chooseCampaign: "اختر حملة...",
      uploadFile: "رفع ملف",
      dragDropFile: "اسحب وأفلت الملف هنا",
      supportedFormats: "الصيغ المدعومة",
      browseFiles: "تصفح الملفات",
      manualEntry: "إدخال يدوي",
      oneNumberPerLine: "أدخل رقم جوال واحد في كل سطر",
      importPreview: "معاينة الاستيراد",
      validNumbers: "أرقام صحيحة",
      invalidNumbers: "أرقام خاطئة",
      duplicateNumbers: "أرقام مكررة",
      invalidNumbersList: "الأرقام الخاطئة",
      duplicateNumbersList: "الأرقام المكررة",
      importing: "جاري الاستيراد...",
      reset: "إعادة تعيين",
      invalidFileFormat: "صيغة ملف غير صالحة. يرجى رفع CSV أو TXT أو XLS أو XLSX",
      errorReadingFile: "خطأ في قراءة الملف",
      selectCampaignFirst: "يرجى اختيار حملة أولاً",
      noValidNumbers: "لا توجد أرقام صحيحة للاستيراد",
      customersImported: "تم استيراد {count} عميل بنجاح",
      errorImportingCustomers: "فشل استيراد العملاء",
      importedCustomers: "العملاء المستوردون",
      selectCampaignToView: "اختر حملة لعرض العملاء المستوردين",
      noCustomersImported: "لم يتم استيراد أي عملاء حتى الآن",
      totalImported: "إجمالي المستوردة",
      loading: "جاري التحميل...",
      
      // إدارة المنتجات
      productDescription: "إدارة منتجات الهدايا والعروض",
      addProduct: "إضافة منتج",
      editProduct: "تعديل منتج",
      productNameEnglish: "اسم المنتج (بالإنجليزية)",
      productNameArabic: "اسم المنتج (بالعربية)",
      productImage: "صورة المنتج",
      maxImageSize: "الحد الأقصى: 5 ميجابايت",
      specialBarcode: "الباركود الخاص",
      originalPrice: "السعر الأصلي",
      offerPrice: "سعر العرض",
      discount: "خصم",
      stockLimit: "الكمية المتاحة",
      stockRemaining: "المتبقي",
      stock: "مخزون",
      barcode: "باركود",
      productActive: "نشط",
      uploading: "جاري الرفع...",
      productNameRequired: "اسم المنتج مطلوب بكلا اللغتين",
      barcodeRequired: "الباركود مطلوب",
      offerPriceMustBeLower: "يجب أن يكون سعر العرض أقل من أو يساوي السعر الأصلي",
      stockLimitRequired: "الكمية المتاحة مطلوبة ويجب أن تكون على الأقل 1",
      imageTooLarge: "حجم الصورة كبير جداً. الحد الأقصى 5 ميجابايت",
      productCreated: "تم إنشاء المنتج بنجاح",
      productUpdated: "تم تحديث المنتج بنجاح",
      productActivated: "تم تفعيل المنتج",
      productDeactivated: "تم إيقاف المنتج",
      errorLoadingProducts: "فشل تحميل المنتجات",
      errorSavingProduct: "فشل حفظ المنتج",
      noProducts: "لا توجد منتجات",
      addFirstProduct: "أضف منتجك الأول",
      selectCampaignToManageProducts: "اختر حملة لإدارة منتجاتها",
      
      // إحصائيات وتقارير
      reportsDescription: "عرض التحليلات ومقاييس الأداء للحملات",
      selectCampaignToViewReports: "اختر حملة لعرض إحصائياتها وأدائها",
      eligibleCustomers: "العملاء المؤهلون",
      totalClaims: "إجمالي الاستخدامات",
      remainingClaims: "الاستخدامات المتبقية",
      claimRate: "معدل الاستخدام",
      claimProgress: "تقدم الاستخدام",
      stockUsage: "استخدام المخزون",
      customers: "عملاء",
      products: "منتجات",
      productPerformance: "أداء المنتجات",
      progress: "التقدم",
      
      // واجهة الكاشير
      cashierInterface: "واجهة الكاشير",
      couponRedemption: "نظام صرف الكوبونات",
      cashier: "كاشير",
      accessCodeInstructions: "أدخل رمز الأمان المكون من 6 أرقام للوصول إلى واجهة الكاشير",
      selectBranch: "اختيار الفرع",
      chooseBranchLocation: "اختر موقع فرعك للمتابعة",
      branch: "موقع الفرع",
      startCashier: "بدء جلسة الكاشير",
      branchSelectionNote: "يمكنك اختيار فرعك مرة واحدة فقط في كل جلسة",
      redeemCoupon: "صرف كوبون",
      saudiMobileFormat: "الصيغة: 05XXXXXXXX (10 أرقام)",
      campaignCodeFormat: "الصيغة: حرفان + 4 أرقام (مثال: AB1234)",
      validateAndClaim: "تحقق وصرف",
      instructions: "التعليمات",
      instruction1: "أدخل رقم جوال العميل (10 أرقام تبدأ بـ 05)",
      instruction2: "أدخل رمز الحملة المقدم من الإدارة",
      instruction3: "انقر على تحقق وصرف للتحقق من الأهلية",
      instruction4: "إذا كان مؤهلاً، سيتم اختيار منتج عشوائي",
      instruction5: "اطبع الإيصال وسلم المنتج للعميل",
      enterDetailsToValidate: "أدخل بيانات العميل للتحقق من الكوبون وصرفه",
      checkingEligibility: "التحقق من أهلية العميل واختيار المنتج",
      eligible: "مؤهل!",
      customerIsEligible: "العميل مؤهل لهذه الحملة",
      newRedemption: "صرف جديد",
      notEligible: "غير مؤهل",
      welcomeMessage: "استخدم زر صرف الكوبون لمعالجة كوبونات العملاء",
      maxClaimsReached: "وصل العميل إلى الحد الأقصى لعدد المطالبات",
      notEligibleForCampaign: "العميل غير مؤهل لهذه الحملة",
      failedToClaim: "فشل صرف الكوبون",
    },

    // ملخص التقارير
    reportsSummary: {
      expenseTracker: "متتبع المصروفات",
      salesReport: "تقرير المبيعات",
      dailySalesOverview: "نظرة عامة على المبيعات اليومية",
      todayBranchSales: "مبيعات الفروع اليوم",
      yesterdayBranchSales: "مبيعات الفروع أمس",
      bills: "فواتير",
      basket: "السلة",
      return: "المرتجعات",
      today: "اليوم",
      yesterday: "أمس",
      twoDaysAgo: "منذ يومين",
      currentMonth: "الشهر الحالي",
      previousMonth: "الشهر السابق",
      averagePerDay: "متوسط يومي",
      days: "أيام",
    },

    // التقارير - للقسم الثاني
    reportsData: {
      expenseTracker: "متتبع المصروفات",
      salesReport: "تقرير المبيعات",
      dailySalesOverview: "نظرة عامة على المبيعات اليومية",
      todayBranchSales: "مبيعات الفروع اليوم",
      yesterdayBranchSales: "مبيعات الفروع أمس",
      bills: "فواتير",
      basket: "السلة",
      return: "المرتجعات",
      today: "اليوم",
      yesterday: "أمس",
      twoDaysAgo: "منذ يومين",
      currentMonth: "الشهر الحالي",
      previousMonth: "الشهر السابق",
      averagePerDay: "متوسط يومي",
      days: "أيام",
    },

    // نقطة البيع
    pos: {
      title: "نقطة البيع",
      availableBoxes: "الصناديق المتاحة",
      box: "صندوق",
      noBoxesWithBalance: "لا توجد صناديق بها رصيد",
      counterCheck: "التحقق من العداد",
      enterRealCount: "إدخال العد الفعلي",
      realTotal: "الإجمالي الفعلي",
      matched: "متطابق",
      notMatched: "غير متطابق",
      difference: "الفرق",
      posNumber: "رقم نقطة البيع",
      cashierAccessCode: "كود دخول الكاشير",
      enterCashierAccessCode: "أدخل كود دخول الكاشير",
      supervisorAccessCode: "كود دخول المشرف",
      enterSupervisorAccessCode: "أدخل كود دخول المشرف",
    },

    // عمليات الصندوق
    boxOperations: {
      posPending: "نقاط البيع في الانتظار",
      posClosed: "نقاط البيع المغلقة",
      completedBoxes: "الصناديق المكتملة",
      pendingBoxes: "في الانتظار",
      noPendingBoxes: "لا توجد صناديق في الانتظار",
      noPendingBoxesDesc: "لا توجد عمليات صناديق في انتظار الإغلاق",
      noClosedBoxes: "لا توجد صناديق مغلقة",
      noClosedBoxesDesc: "لم يتم إكمال أي عمليات صناديق بعد",
      box: "صندوق",
      completed: "مكتمل",
      pendingClose: "في انتظار الإغلاق",
      started: "البدء",
      duration: "المدة",
      closed: "الإغلاق",
      totalDifference: "إجمالي الفرق",
      completedBy: "أكمله",
      inUse: "نقاط البيع النشطة",
    },
  },
};
