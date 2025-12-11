const { createClient } = require('@supabase/supabase-js');
const url = 'https://supabase.urbanaqura.com';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NjQ4NzU1MjcsImV4cCI6MjA4MDQ1MTUyN30.6mj0wiHW0ljpYNIEeYG-r--577LDNbxCLj7SZOghbv0';
const supabase = createClient(url, serviceKey);

// Button data structure from SIDEBAR_SECTIONS_AND_BUTTONS.md
const buttonData = {
  DELIVERY: {
    DASHBOARD: [],
    MANAGE: [
      { en: 'Customer Master', ar: 'سيد العملاء', code: 'CUSTOMER_MASTER' },
      { en: 'Ad Manager', ar: 'مدير الإعلانات', code: 'AD_MANAGER' },
      { en: 'Products Manager', ar: 'مدير المنتجات', code: 'PRODUCTS_MANAGER' },
      { en: 'Delivery Settings', ar: 'إعدادات التسليم', code: 'DELIVERY_SETTINGS' }
    ],
    OPERATIONS: [
      { en: 'Orders Manager', ar: 'مدير الطلبات', code: 'ORDERS_MANAGER' },
      { en: 'Offer Management', ar: 'إدارة العروض', code: 'OFFER_MANAGEMENT' }
    ],
    REPORTS: []
  },
  VENDOR: {
    DASHBOARD: [
      { en: 'Receiving', ar: 'الاستقبال', code: 'RECEIVING' }
    ],
    MANAGE: [
      { en: 'Upload Vendor', ar: 'تحميل البائع', code: 'UPLOAD_VENDOR' },
      { en: 'Create Vendor', ar: 'إنشاء بائع', code: 'CREATE_VENDOR' },
      { en: 'Manage Vendor', ar: 'إدارة البائع', code: 'MANAGE_VENDOR' }
    ],
    OPERATIONS: [
      { en: 'Start Receiving', ar: 'بدء الاستقبال', code: 'START_RECEIVING' },
      { en: 'Receiving Records', ar: 'سجلات الاستقبال', code: 'RECEIVING_RECORDS' }
    ],
    REPORTS: [
      { en: 'Vendor Records', ar: 'سجلات البائع', code: 'VENDOR_RECORDS' }
    ]
  },
  MEDIA: {
    DASHBOARD: [],
    MANAGE: [
      { en: 'Product Master', ar: 'سيد المنتج', code: 'PRODUCT_MASTER' },
      { en: 'Variation Manager', ar: 'مدير الاختلافات', code: 'VARIATION_MANAGER' },
      { en: 'Offer Manager', ar: 'مدير العروض', code: 'OFFER_MANAGER' },
      { en: 'Flyer Templates', ar: 'نماذج المنشورات', code: 'FLYER_TEMPLATES' },
      { en: 'Settings', ar: 'الإعدادات', code: 'SETTINGS' }
    ],
    OPERATIONS: [
      { en: 'Offer Product Editor', ar: 'محرر منتج العرض', code: 'OFFER_PRODUCT_EDITOR' },
      { en: 'Create New Offer', ar: 'إنشاء عرض جديد', code: 'CREATE_NEW_OFFER' },
      { en: 'Pricing Manager', ar: 'مدير التسعير', code: 'PRICING_MANAGER' },
      { en: 'Generate Flyers', ar: 'إنشاء منشورات', code: 'GENERATE_FLYERS' },
      { en: 'Shelf Paper Manager', ar: 'مدير ورقة الرف', code: 'SHELF_PAPER_MANAGER' }
    ],
    REPORTS: []
  },
  PROMO: {
    DASHBOARD: [
      { en: 'Coupon Dashboard', ar: 'لوحة تحكم القسيمة', code: 'COUPON_DASHBOARD' }
    ],
    MANAGE: [
      { en: 'Manage Campaigns', ar: 'إدارة الحملات', code: 'MANAGE_CAMPAIGNS' }
    ],
    OPERATIONS: [
      { en: 'Import Customers', ar: 'استيراد العملاء', code: 'IMPORT_CUSTOMERS' },
      { en: 'Manage Products', ar: 'إدارة المنتجات', code: 'MANAGE_PRODUCTS' }
    ],
    REPORTS: [
      { en: 'Reports & Stats', ar: 'التقارير والإحصائيات', code: 'REPORTS_STATS' }
    ]
  },
  FINANCE: {
    DASHBOARD: [],
    MANAGE: [],
    OPERATIONS: [
      { en: 'Manual Scheduling', ar: 'الجدولة اليدوية', code: 'MANUAL_SCHEDULING' },
      { en: 'Day Budget Planner', ar: 'مخطط ميزانية اليوم', code: 'DAY_BUDGET_PLANNER' },
      { en: 'Monthly Manager', ar: 'مدير شهري', code: 'MONTHLY_MANAGER' },
      { en: 'Expense Manager', ar: 'مدير النفقات', code: 'EXPENSE_MANAGER' },
      { en: 'Paid Manager', ar: 'مدير المدفوعات', code: 'PAID_MANAGER' }
    ],
    REPORTS: [
      { en: 'Expense Tracker', ar: 'متتبع النفقات', code: 'EXPENSE_TRACKER' },
      { en: 'Sales Report', ar: 'تقرير المبيعات', code: 'SALES_REPORT' },
      { en: 'Monthly Breakdown', ar: 'التفصيل الشهري', code: 'MONTHLY_BREAKDOWN' },
      { en: 'Over dues', ar: 'المستحقات', code: 'OVER_DUES' },
      { en: 'Vendor Payments', ar: 'مدفوعات البائع', code: 'VENDOR_PAYMENTS' }
    ]
  },
  HR: {
    DASHBOARD: [],
    MANAGE: [
      { en: 'Upload Employees', ar: 'تحميل الموظفين', code: 'UPLOAD_EMPLOYEES' },
      { en: 'Create Department', ar: 'إنشاء قسم', code: 'CREATE_DEPARTMENT' },
      { en: 'Create Level', ar: 'إنشاء مستوى', code: 'CREATE_LEVEL' },
      { en: 'Create Position', ar: 'إنشاء وظيفة', code: 'CREATE_POSITION' },
      { en: 'Reporting Map', ar: 'خريطة التقارير', code: 'REPORTING_MAP' },
      { en: 'Assign Positions', ar: 'تعيين الوظائف', code: 'ASSIGN_POSITIONS' },
      { en: 'Contact Management', ar: 'إدارة جهات الاتصال', code: 'CONTACT_MANAGEMENT' },
      { en: 'Document Management', ar: 'إدارة المستندات', code: 'DOCUMENT_MANAGEMENT' },
      { en: 'Salary & Wage Management', ar: 'إدارة الراتب والأجر', code: 'SALARY_WAGE_MANAGEMENT' },
      { en: 'Warning Master', ar: 'سيد التحذير', code: 'WARNING_MASTER' }
    ],
    OPERATIONS: [],
    REPORTS: [
      { en: 'Biometric Data', ar: 'بيانات المقاييس الحيوية', code: 'BIOMETRIC_DATA' },
      { en: 'Export Biometric Data', ar: 'تصدير بيانات المقاييس الحيوية', code: 'EXPORT_BIOMETRIC_DATA' }
    ]
  },
  TASKS: {
    DASHBOARD: [
      { en: 'Task Master', ar: 'سيد المهام', code: 'TASK_MASTER' }
    ],
    MANAGE: [
      { en: 'Create Task Template', ar: 'إنشاء قالب المهام', code: 'CREATE_TASK_TEMPLATE' },
      { en: 'View Task Templates', ar: 'عرض قوالب المهام', code: 'VIEW_TASK_TEMPLATES' }
    ],
    OPERATIONS: [
      { en: 'Assign Tasks', ar: 'تعيين المهام', code: 'ASSIGN_TASKS' }
    ],
    REPORTS: [
      { en: 'View My Tasks', ar: 'عرض مهامي', code: 'VIEW_MY_TASKS' },
      { en: 'View My Assignments', ar: 'عرض تعييناتي', code: 'VIEW_MY_ASSIGNMENTS' },
      { en: 'Task Status', ar: 'حالة المهام', code: 'TASK_STATUS' },
      { en: 'Branch Performance', ar: 'أداء الفرع', code: 'BRANCH_PERFORMANCE' }
    ]
  },
  NOTIFICATION: {
    DASHBOARD: [
      { en: 'Communication Center', ar: 'مركز الاتصالات', code: 'COMMUNICATION_CENTER' }
    ],
    MANAGE: [],
    OPERATIONS: [],
    REPORTS: []
  },
  USERS: {
    DASHBOARD: [
      { en: 'Users', ar: 'المستخدمون', code: 'USERS' }
    ],
    MANAGE: [
      { en: 'Create User', ar: 'إنشاء مستخدم', code: 'CREATE_USER' },
      { en: 'Assign Roles', ar: 'تعيين الأدوار', code: 'ASSIGN_ROLES' },
      { en: 'Create User Roles', ar: 'إنشاء أدوار المستخدم', code: 'CREATE_USER_ROLES' },
      { en: 'Manage Admin Users', ar: 'إدارة مستخدمي الإدارة', code: 'MANAGE_ADMIN_USERS' },
      { en: 'Manage Master Admin', ar: 'إدارة الإدارة الرئيسية', code: 'MANAGE_MASTER_ADMIN' },
      { en: 'Interface Access', ar: 'الوصول إلى الواجهة', code: 'INTERFACE_ACCESS' },
      { en: 'Approval Permissions', ar: 'أذونات الموافقة', code: 'APPROVAL_PERMISSIONS' },
      { en: 'User Permissions', ar: 'أذونات المستخدم', code: 'USER_PERMISSIONS' }
    ],
    OPERATIONS: [],
    REPORTS: []
  },
  CONTROLS: {
    DASHBOARD: [],
    MANAGE: [
      { en: 'Branch Master', ar: 'سيد الفرع', code: 'BRANCH_MASTER' },
      { en: 'Sound Settings', ar: 'إعدادات الصوت', code: 'SOUND_SETTINGS' },
      { en: 'ERP Connections', ar: 'اتصالات ERP', code: 'ERP_CONNECTIONS' },
      { en: 'Clear Tables', ar: 'مسح الجداول', code: 'CLEAR_TABLES' },
      { en: 'Button Access Control', ar: 'التحكم في وصول الأزرار', code: 'BUTTON_ACCESS_CONTROL' }
    ],
    OPERATIONS: [],
    REPORTS: []
  }
};

(async () => {
  try {
    console.log('=== INSERTING BUTTONS INTO DATABASE ===\n');

    // Get all sections and subsections
    const { data: sections } = await supabase.from('button_main_sections').select('id, section_code');
    const { data: subsections } = await supabase.from('button_sub_sections').select('id, subsection_code, main_section_id');

    // Build lookup maps
    const sectionMap = {};
    sections.forEach(s => { sectionMap[s.section_code] = s.id; });

    const subsectionMap = {};
    subsections.forEach(s => {
      const key = `${s.main_section_id}_${s.subsection_code}`;
      subsectionMap[key] = s.id;
    });

    let totalButtons = 0;
    let insertedButtons = 0;

    // Iterate through all button data
    for (const [sectionCode, subsections_data] of Object.entries(buttonData)) {
      const mainSectionId = sectionMap[sectionCode];
      
      for (const [subsectionCode, buttons] of Object.entries(subsections_data)) {
        const subsectionKey = `${mainSectionId}_${subsectionCode}`;
        const subsectionId = subsectionMap[subsectionKey];

        for (let i = 0; i < buttons.length; i++) {
          const button = buttons[i];
          totalButtons++;

          const { error } = await supabase.from('sidebar_buttons').insert({
            main_section_id: mainSectionId,
            subsection_id: subsectionId,
            button_name_en: button.en,
            button_name_ar: button.ar,
            button_code: button.code,
            icon: '📌',
            display_order: i + 1,
            is_active: true
          });

          if (!error) {
            insertedButtons++;
          } else {
            console.error(`Error inserting ${button.code}:`, error.message);
          }
        }
      }
    }

    console.log(`✓ Inserted ${insertedButtons}/${totalButtons} buttons successfully\n`);

    // Now insert permissions for all users and all buttons
    console.log('=== INSERTING BUTTON PERMISSIONS ===\n');

    const { data: allButtons } = await supabase.from('sidebar_buttons').select('id');
    const { data: allUsers } = await supabase.from('users').select('id');

    console.log(`Found ${allButtons.length} buttons and ${allUsers.length} users`);
    console.log(`Creating ${allButtons.length * allUsers.length} permission records...\n`);

    let permissionsInserted = 0;
    const batchSize = 100;

    for (let i = 0; i < allUsers.length; i += batchSize) {
      const userBatch = allUsers.slice(i, i + batchSize);
      
      const permissionRecords = [];
      userBatch.forEach(user => {
        allButtons.forEach(button => {
          permissionRecords.push({
            user_id: user.id,
            button_id: button.id,
            is_enabled: true
          });
        });
      });

      const { error } = await supabase.from('button_permissions').insert(permissionRecords);
      
      if (!error) {
        permissionsInserted += permissionRecords.length;
        console.log(`✓ Inserted ${permissionRecords.length} permission records (batch ${Math.floor(i / batchSize) + 1})`);
      } else {
        console.error(`Error in batch ${Math.floor(i / batchSize) + 1}:`, error.message);
      }
    }

    console.log(`\n✓ Total permissions inserted: ${permissionsInserted}`);
    console.log('\n=== SETUP COMPLETE ===');
    console.log(`Buttons: ${insertedButtons}`);
    console.log(`Permissions: ${permissionsInserted}`);
    console.log('\nButton Access Control System is ready!');

  } catch (err) {
    console.error('Exception:', err.message);
  }
})();
