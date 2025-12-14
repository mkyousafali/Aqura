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
    },

    // Mobile page titles
    mobile: {
      dashboard: "لوحة التحكم",
      tasks: "المهام",
      notifications: "الإشعارات",
      assignments: "التكليفات",
      approvals: "الموافقات",
      quickTask: "مهمة سريعة",
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
      employee: "موظف",
      employees: "الموظفون",
      employeeId: "رقم الموظف",
      firstName: "الاسم الأول",
      lastName: "اسم العائلة",
      fullName: "الاسم الكامل",
      email: "البريد الإلكتروني",
      phone: "الهاتف",
      department: "القسم",
      designation: "المسمى الوظيفي",
      status: "الحالة",
      branch: "الفرع",
      manager: "المدير",
      joinDate: "تاريخ الانضمام",
      active: "نشط",
      inactive: "غير نشط",
      pending: "في الانتظار",
      // Biometric Data Dashboard
      biometricData: "بيانات المقاييس البيومترية",
      presentToday: "الحاضرون اليوم",
      invalidDate: "تاريخ غير صحيح",
      branchBreakdown: "توزيع الفروع",
      syncStatus: "حالة المزامنة",
      noSyncData: "لا توجد بيانات مزامنة",
      checkIn: "تسجيل الدخول",
      checkOut: "تسجيل الخروج",
      allFingerprint: "جميع معاملات البصمات",
      searchBy: "البحث حسب",
      name: "الاسم",
      position: "المنصب",
      date: "التاريخ",
      time: "الوقت",
      allDates: "جميع التواريخ",
      clearFilters: "مسح المرشحات",
      clearSearch: "مسح",
      search: "بحث",
      showing: "عرض",
      of: "من",
      transactions: "معاملات",
      loadToday: "اليوم",
      loadSpecificDate: "تاريخ محدد",
      loadDateRange: "نطاق التاريخ",
      loadAllData: "جميع البيانات",
      loadData: "تحميل البيانات",
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
      masterWarningMaster: "إدارة التحذيرات",
      masterWarningMasterDesc: "نظام إدارة التحذيرات الشامل",
      
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
      confirmDelete: "هل أنت متأكد من حذف هذا العنصر؟",
      noData: "لا توجد بيانات",
      status: "الحالة",
      loading: "جاري التحميل...",
      today: "اليوم",
      yesterday: "أمس",
      chooseBranch: "اختر الفرع",
      error: "حدث خطأ",
      rememberDevice: "تذكر هذا الجهاز",
      optional: "اختياري",
      autoDetected: "تم الكشف تلقائياً",
      users: "المستخدمين",
      customer: "العميل",
      employeeLogin: "تسجيل دخول الفريق",
      all: "الكل",
      sar: "ريال",
      print: "طباعة",
      printed: "تم الطباعة",
      cancel: "إلغاء",
      validating: "جاري التحقق...",
      tryAgain: "حاول مرة أخرى",
      back: "رجوع",
      backToLogin: "العودة لتسجيل الدخول",
      refresh: "تحديث",
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
  },
};
