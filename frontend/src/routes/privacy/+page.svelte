<script lang="ts">
    import { currentLocale, switchLocale } from '$lib/i18n';

    const companyName = "Urban Aqura";
    const companyNameAr = "ايربن ماركت أكورا";
    const appName = "Aqura";
    const appNameAr = "أكورا";
    const website = "https://urbanksa.com";
    const email = "CEO@urbanksa.com";
    const lastUpdatedEn = "February 22, 2026";
    const lastUpdatedAr = "22 فبراير 2026";

    $: isAr = $currentLocale === 'ar';
    let dir: 'rtl' | 'ltr' = 'ltr';
    $: dir = isAr ? 'rtl' : 'ltr';
    $: cn = isAr ? companyNameAr : companyName;
    $: an = isAr ? appNameAr : appName;
    $: lastUpdated = isAr ? lastUpdatedAr : lastUpdatedEn;

    function toggleLang() {
        switchLocale(isAr ? 'en' : 'ar');
    }
</script>

<svelte:head>
    <title>{isAr ? 'سياسة الخصوصية' : 'Privacy Policy'} - {an}</title>
</svelte:head>

<div class="min-h-screen bg-gray-50 py-12 px-4 sm:px-6 lg:px-8" {dir}>
    <div class="max-w-3xl mx-auto bg-white rounded-2xl shadow-sm p-8 sm:p-12">

        <!-- Language Toggle -->
        <div style="display: flex; justify-content: {isAr ? 'flex-start' : 'flex-end'}; margin-bottom: 1rem;">
            <button 
                on:click={toggleLang}
                style="padding: 0.5rem 1rem; border-radius: 8px; border: 1px solid #d1d5db; background: white; cursor: pointer; font-size: 0.875rem; font-weight: 600; color: #374151;"
            >
                {isAr ? 'English' : 'العربية'}
            </button>
        </div>

        <h1 class="text-3xl font-bold text-gray-900 mb-2">{isAr ? 'سياسة الخصوصية' : 'Privacy Policy'}</h1>
        <p class="text-sm text-gray-500 mb-8">{isAr ? 'آخر تحديث:' : 'Last updated:'} {lastUpdated}</p>

        <div class="space-y-6 text-gray-700 leading-relaxed">

            <!-- Section 1: Introduction -->
            <section>
                <h2 class="text-xl font-semibold text-gray-900 mb-3">{isAr ? '1. المقدمة' : '1. Introduction'}</h2>
                {#if isAr}
                    <p>{cn} ("نحن" أو "لنا") تدير نظام إدارة {an} والخدمات المرتبطة المتوفرة على <a href={website} class="text-blue-600 underline">{website}</a>. توضح سياسة الخصوصية هذه كيفية جمع واستخدام والإفصاح عن وحماية معلوماتك عند استخدام تطبيقنا وخدماتنا، بما في ذلك تكامل واتساب للأعمال.</p>
                    <p class="mt-2">تم تصميم هذه السياسة وفقاً <strong>لنظام حماية البيانات الشخصية في المملكة العربية السعودية (PDPL)</strong> (المرسوم الملكي رقم م/19 بتاريخ 9/2/1443هـ)، ولوائحه التنفيذية، ومعايير حماية البيانات الدولية المعمول بها بما في ذلك <strong>اللائحة العامة لحماية البيانات الأوروبية (GDPR)</strong> حيثما ينطبق ذلك على أصحاب البيانات داخل المنطقة الاقتصادية الأوروبية.</p>
                {:else}
                    <p>{cn} ("we", "our", or "us") operates the {an} management system and related services available at <a href={website} class="text-blue-600 underline">{website}</a>. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our application and services, including our WhatsApp Business integration.</p>
                    <p class="mt-2">This policy is designed in compliance with the <strong>Kingdom of Saudi Arabia's Personal Data Protection Law (PDPL)</strong> (Royal Decree M/19, dated 9/2/1443H), its implementing regulations, and applicable international data protection standards including the <strong>EU General Data Protection Regulation (GDPR)</strong> where applicable to data subjects within the European Economic Area.</p>
                {/if}
            </section>

            <!-- Section 2: Definitions -->
            <section>
                <h2 class="text-xl font-semibold text-gray-900 mb-3">{isAr ? '2. التعريفات' : '2. Definitions'}</h2>
                {#if isAr}
                    <ul class="list-disc pr-6 space-y-1">
                        <li><strong>البيانات الشخصية:</strong> أي بيانات يمكن من خلالها تحديد هوية شخص طبيعي بشكل مباشر أو غير مباشر، بما في ذلك الاسم ورقم الهوية والعناوين وأرقام الهواتف والصور والبيانات البيومترية، كما هو محدد في نظام حماية البيانات الشخصية السعودي.</li>
                        <li><strong>البيانات الحساسة:</strong> البيانات التي تكشف عن الأصل العرقي أو الإثني أو المعتقدات الدينية أو الفلسفية أو السجلات الجنائية أو البيانات البيومترية أو الجينية أو الصحية أو الائتمانية.</li>
                        <li><strong>المعالجة:</strong> أي عملية تتم على البيانات الشخصية، بما في ذلك الجمع والتسجيل والتخزين والتنظيم والهيكلة والتعديل والاسترجاع والاستخدام والإفصاح والنقل والتقييد والمحو أو الإتلاف.</li>
                        <li><strong>المتحكم في البيانات:</strong> {cn}، التي تحدد أغراض ووسائل معالجة البيانات الشخصية.</li>
                        <li><strong>صاحب البيانات:</strong> الفرد الذي تتم معالجة بياناته الشخصية (أنت، المستخدم).</li>
                    </ul>
                {:else}
                    <ul class="list-disc pl-6 space-y-1">
                        <li><strong>Personal Data:</strong> Any data that can identify a natural person directly or indirectly, including name, identification number, addresses, phone numbers, photos, and biometric data, as defined under the Saudi PDPL.</li>
                        <li><strong>Sensitive Data:</strong> Data revealing racial or ethnic origin, religious or philosophical beliefs, criminal records, biometric data, genetic data, health data, or credit data.</li>
                        <li><strong>Processing:</strong> Any operation performed on personal data, including collection, recording, storage, organization, structuring, adaptation, retrieval, use, disclosure, transmission, restriction, erasure, or destruction.</li>
                        <li><strong>Data Controller:</strong> {cn}, which determines the purposes and means of processing personal data.</li>
                        <li><strong>Data Subject:</strong> The individual whose personal data is being processed (you, the user).</li>
                    </ul>
                {/if}
            </section>

            <!-- Section 3: Information We Collect -->
            <section>
                <h2 class="text-xl font-semibold text-gray-900 mb-3">{isAr ? '3. المعلومات التي نجمعها' : '3. Information We Collect'}</h2>
                <p class="mb-2">{isAr ? 'قد نجمع الأنواع التالية من المعلومات:' : 'We may collect the following types of information:'}</p>
                {#if isAr}
                    <ul class="list-disc pr-6 space-y-2">
                        <li><strong>معلومات الحساب:</strong> الاسم وعنوان البريد الإلكتروني ورقم الهاتف ورقم الهوية الوطنية أو الإقامة (حيثما ينطبق) والدور عند التسجيل أو الإضافة كمستخدم.</li>
                        <li><strong>بيانات الأعمال:</strong> بيانات المخزون والمبيعات والمالية والتشغيلية المدخلة في النظام من قبل المستخدمين المصرح لهم.</li>
                        <li><strong>بيانات رسائل واتساب:</strong> أرقام الهواتف ومحتوى الرسائل وحالة التسليم وسجل المحادثات عند التفاعل مع تكامل واتساب للأعمال.</li>
                        <li><strong>بيانات الاستخدام:</strong> نشاط تسجيل الدخول واستخدام الميزات ومعلومات الجهاز ونوع المتصفح ونظام التشغيل وعناوين IP والطوابع الزمنية للوصول لأغراض الأمان والتحليلات.</li>
                        <li><strong>البيانات البيومترية:</strong> سجلات بصمات الأصابع لتتبع الحضور. تُصنف هذه كـ<strong>بيانات شخصية حساسة</strong> بموجب نظام حماية البيانات الشخصية السعودي وتتم معالجتها فقط بموافقة صريحة لغرض محدد وهو إدارة حضور القوى العاملة.</li>
                        <li><strong>بيانات الموقع:</strong> إحداثيات GPS وعناوين التوصيل عند استخدام خدماتنا القائمة على الموقع أو ميزات التوصيل.</li>
                        <li><strong>بيانات المعاملات:</strong> سجل الطلبات وتفضيلات الدفع وسجلات الشراء.</li>
                        <li><strong>بيانات الاتصال:</strong> استفسارات دعم العملاء والتعليقات والمراسلات.</li>
                    </ul>
                {:else}
                    <ul class="list-disc pl-6 space-y-2">
                        <li><strong>Account Information:</strong> Name, email address, phone number, national ID or Iqama number (where applicable), and role when you register or are added as a user.</li>
                        <li><strong>Business Data:</strong> Inventory, sales, financial, and operational data entered into the system by authorized users.</li>
                        <li><strong>WhatsApp Messaging Data:</strong> Phone numbers, message content, delivery status, and conversation history when you interact with our WhatsApp Business integration.</li>
                        <li><strong>Usage Data:</strong> Login activity, feature usage, device information, browser type, operating system, IP addresses, and access timestamps for security and analytics purposes.</li>
                        <li><strong>Biometric Data:</strong> Fingerprint records for attendance tracking. This is classified as <strong>sensitive personal data</strong> under the Saudi PDPL and is processed only with explicit consent for the specific purpose of workforce attendance management.</li>
                        <li><strong>Location Data:</strong> GPS coordinates and delivery addresses when you use our location-based services or delivery features.</li>
                        <li><strong>Transaction Data:</strong> Order history, payment preferences, and purchase records.</li>
                        <li><strong>Communication Data:</strong> Customer support inquiries, feedback, and correspondence.</li>
                    </ul>
                {/if}
            </section>

            <!-- Section 4: Legal Basis -->
            <section>
                <h2 class="text-xl font-semibold text-gray-900 mb-3">{isAr ? '4. الأساس القانوني للمعالجة' : '4. Legal Basis for Processing'}</h2>
                <p class="mb-2">{isAr ? 'وفقاً لنظام حماية البيانات الشخصية السعودي (المادة 5) واللائحة العامة لحماية البيانات (المادة 6)، نعالج بياناتك الشخصية بناءً على واحد أو أكثر من الأسس القانونية التالية:' : 'In accordance with the Saudi PDPL (Article 5) and GDPR (Article 6), we process your personal data based on one or more of the following legal grounds:'}</p>
                {#if isAr}
                    <ul class="list-disc pr-6 space-y-1">
                        <li><strong>الموافقة:</strong> لقد قدمت موافقة صريحة على المعالجة لغرض واحد أو أكثر. يمكنك سحب الموافقة في أي وقت دون التأثير على مشروعية المعالجة قبل السحب.</li>
                        <li><strong>الضرورة التعاقدية:</strong> المعالجة ضرورية لتنفيذ عقد أنت طرف فيه، أو لاتخاذ خطوات بناءً على طلبك قبل الدخول في عقد.</li>
                        <li><strong>الالتزام القانوني:</strong> المعالجة ضرورية للامتثال للأنظمة والقوانين السعودية، بما في ذلك نظام مكافحة غسل الأموال ومتطلبات السجل التجاري ونظام العمل واللوائح الضريبية.</li>
                        <li><strong>المصلحة المشروعة:</strong> المعالجة ضرورية لمصالحنا المشروعة، مثل تحسين خدماتنا ومنع الاحتيال وضمان أمن الشبكة، شريطة ألا تتجاوز هذه المصالح حقوقك الأساسية.</li>
                        <li><strong>المصلحة العامة:</strong> المعالجة ضرورية لمهام تُنفذ في المصلحة العامة أو في ممارسة سلطة رسمية.</li>
                        <li><strong>المصلحة الحيوية:</strong> المعالجة ضرورية لحماية المصالح الحيوية لصاحب البيانات أو شخص طبيعي آخر.</li>
                    </ul>
                {:else}
                    <ul class="list-disc pl-6 space-y-1">
                        <li><strong>Consent:</strong> You have given explicit consent for processing for one or more specific purposes. You may withdraw consent at any time without affecting the lawfulness of processing before withdrawal.</li>
                        <li><strong>Contractual Necessity:</strong> Processing is necessary for the performance of a contract to which you are a party, or to take steps at your request prior to entering into a contract.</li>
                        <li><strong>Legal Obligation:</strong> Processing is necessary for compliance with Saudi laws and regulations, including the Anti-Money Laundering Law, Commercial Registration requirements, Labor Law, and tax regulations.</li>
                        <li><strong>Legitimate Interest:</strong> Processing is necessary for our legitimate interests, such as improving our services, preventing fraud, and ensuring network security, provided such interests are not overridden by your fundamental rights.</li>
                        <li><strong>Public Interest:</strong> Processing is necessary for tasks carried out in the public interest or in the exercise of official authority.</li>
                        <li><strong>Vital Interest:</strong> Processing is necessary to protect the vital interests of the data subject or another natural person.</li>
                    </ul>
                {/if}
            </section>

            <!-- Section 5: How We Use -->
            <section>
                <h2 class="text-xl font-semibold text-gray-900 mb-3">{isAr ? '5. كيف نستخدم معلوماتك' : '5. How We Use Your Information'}</h2>
                {#if isAr}
                    <ul class="list-disc pr-6 space-y-1">
                        <li>لتوفير وتشغيل وصيانة خدماتنا</li>
                        <li>لمعالجة المعاملات وإدارة العمليات التجارية</li>
                        <li>لإرسال رسائل المعاملات عبر واتساب (رموز الوصول، تحديثات الطلبات، الإشعارات)</li>
                        <li>لتقديم دعم العملاء من خلال رسائل واتساب للأعمال</li>
                        <li>لتحسين وتخصيص تجربتك</li>
                        <li>لضمان الأمان ومنع الوصول غير المصرح به واكتشاف الاحتيال</li>
                        <li>للامتثال للالتزامات القانونية بموجب القوانين السعودية والدولية المعمول بها</li>
                        <li>لإدارة عمليات الموارد البشرية بما في ذلك تتبع الحضور وإدارة الورديات والرواتب</li>
                        <li>لإجراء التحليلات وإنشاء التقارير لتحسين العمليات التجارية</li>
                        <li>لتنفيذ عمليات التوصيل واللوجستيات</li>
                    </ul>
                {:else}
                    <ul class="list-disc pl-6 space-y-1">
                        <li>To provide, operate, and maintain our services</li>
                        <li>To process transactions and manage business operations</li>
                        <li>To send transactional messages via WhatsApp (access codes, order updates, notifications)</li>
                        <li>To provide customer support through WhatsApp Business messaging</li>
                        <li>To improve and personalize your experience</li>
                        <li>To ensure security, prevent unauthorized access, and detect fraud</li>
                        <li>To comply with legal obligations under Saudi and applicable international laws</li>
                        <li>To manage human resources operations including attendance tracking, shift management, and payroll</li>
                        <li>To perform analytics and generate reports for business operations improvement</li>
                        <li>To fulfill delivery and logistics operations</li>
                    </ul>
                {/if}
            </section>

            <!-- Section 6: WhatsApp -->
            <section>
                <h2 class="text-xl font-semibold text-gray-900 mb-3">{isAr ? '6. تكامل واتساب للأعمال' : '6. WhatsApp Business Integration'}</h2>
                <p>{isAr ? 'نستخدم واجهة برمجة تطبيقات Meta WhatsApp Business للتواصل مع العملاء. عند إرسال رسالة إلى رقم واتساب للأعمال الخاص بنا:' : 'We use the Meta WhatsApp Business API to communicate with customers. When you message our WhatsApp Business number:'}</p>
                {#if isAr}
                    <ul class="list-disc pr-6 space-y-1">
                        <li>تتم معالجة رقم هاتفك ومحتوى الرسالة للرد على استفساراتك</li>
                        <li>قد يتم التعامل مع الرسائل بواسطة روبوتات آلية (مدعومة بالذكاء الاصطناعي) أو وكلاء بشريين</li>
                        <li>يتم تخزين سجل المحادثات بشكل آمن لجودة الخدمة والاستمرارية وحل النزاعات</li>
                        <li>لا نبيع أو نشارك بيانات واتساب الخاصة بك مع أطراف ثالثة لأغراض التسويق</li>
                        <li>قد تتم معالجة بيانات الرسائل بواسطة شركة Meta Platforms, Inc. وفقاً لسياسة الخصوصية الخاصة بها وشروط خدمة واتساب للأعمال</li>
                        <li>تُرسل الرسائل النموذجية والإشعارات فقط لأغراض المعاملات المشروعة (تحديثات الطلبات، رموز الوصول، إشعارات التوصيل)</li>
                    </ul>
                {:else}
                    <ul class="list-disc pl-6 space-y-1">
                        <li>Your phone number and message content are processed to respond to your inquiries</li>
                        <li>Messages may be handled by automated bots (AI-powered) or human agents</li>
                        <li>Conversation history is stored securely for service quality, continuity, and dispute resolution</li>
                        <li>We do not sell or share your WhatsApp data with third parties for marketing purposes</li>
                        <li>Message data may be processed by Meta Platforms, Inc. in accordance with their own privacy policy and the WhatsApp Business Terms of Service</li>
                        <li>Template messages and notifications are sent only for legitimate transactional purposes (order updates, access codes, delivery notifications)</li>
                    </ul>
                {/if}
            </section>

            <!-- Section 7: Biometric -->
            <section>
                <h2 class="text-xl font-semibold text-gray-900 mb-3">{isAr ? '7. معالجة البيانات البيومترية' : '7. Biometric Data Processing'}</h2>
                <p class="mb-2">{isAr ? 'امتثالاً لأحكام نظام حماية البيانات الشخصية السعودي بشأن البيانات الحساسة (المادة 25)، نعالج البيانات البيومترية (بصمات الأصابع) وفق الشروط الصارمة التالية:' : 'In compliance with the Saudi PDPL\'s provisions on sensitive data (Article 25), we process biometric data (fingerprints) under the following strict conditions:'}</p>
                {#if isAr}
                    <ul class="list-disc pr-6 space-y-1">
                        <li><strong>تحديد الغرض:</strong> تُجمع البيانات البيومترية فقط لأغراض تتبع حضور الموظفين والتحقق منه</li>
                        <li><strong>الموافقة الصريحة:</strong> نحصل على موافقة صريحة ومستنيرة من الموظفين قبل جمع البيانات البيومترية</li>
                        <li><strong>تقليل البيانات:</strong> نجمع فقط الحد الأدنى من البيانات البيومترية اللازمة للتحقق من الحضور</li>
                        <li><strong>التخزين الآمن:</strong> تُشفر البيانات البيومترية باستخدام تشفير AES-256 وتُخزن على خوادم مؤمنة داخل المملكة العربية السعودية</li>
                        <li><strong>الوصول المقيد:</strong> يقتصر الوصول إلى البيانات البيومترية على موظفي الموارد البشرية المصرح لهم فقط</li>
                        <li><strong>الاحتفاظ:</strong> تُحتفظ بالبيانات البيومترية فقط طوال فترة علاقة العمل بالإضافة إلى فترة الاحتفاظ المطلوبة قانونياً</li>
                        <li><strong>حق السحب:</strong> يمكن للموظفين سحب موافقتهم على معالجة البيانات البيومترية، وعندها سيتم ترتيب طرق حضور بديلة</li>
                    </ul>
                {:else}
                    <ul class="list-disc pl-6 space-y-1">
                        <li><strong>Purpose Limitation:</strong> Biometric data is collected solely for employee attendance tracking and verification purposes</li>
                        <li><strong>Explicit Consent:</strong> We obtain explicit, informed consent from employees before collecting biometric data</li>
                        <li><strong>Data Minimization:</strong> We collect only the minimum biometric data necessary for attendance verification</li>
                        <li><strong>Secure Storage:</strong> Biometric data is encrypted using AES-256 encryption and stored on secured servers within the Kingdom of Saudi Arabia</li>
                        <li><strong>Restricted Access:</strong> Access to biometric data is limited to authorized HR personnel only</li>
                        <li><strong>Retention:</strong> Biometric data is retained only for the duration of the employment relationship plus the legally required retention period</li>
                        <li><strong>Right to Withdraw:</strong> Employees may withdraw consent for biometric processing, at which point alternative attendance methods will be arranged</li>
                    </ul>
                {/if}
            </section>

            <!-- Section 8: Data Storage -->
            <section>
                <h2 class="text-xl font-semibold text-gray-900 mb-3">{isAr ? '8. تخزين البيانات والأمان' : '8. Data Storage and Security'}</h2>
                <p class="mb-2">{isAr ? 'تُخزن بياناتك على خوادم آمنة مع إجراءات أمنية شاملة تتوافق مع نظام حماية البيانات الشخصية السعودي والمعايير الدولية:' : 'Your data is stored on secure servers with comprehensive security measures in compliance with the Saudi PDPL and international standards:'}</p>
                {#if isAr}
                    <ul class="list-disc pr-6 space-y-1">
                        <li><strong>التشفير:</strong> تُشفر البيانات في حالة السكون (AES-256) وأثناء النقل (TLS 1.2+)</li>
                        <li><strong>ضوابط الوصول:</strong> يضمن التحكم في الوصول القائم على الأدوار (RBAC) وصول الموظفين المصرح لهم فقط إلى بيانات محددة</li>
                        <li><strong>المراقبة:</strong> مراقبة أمنية مستمرة وكشف التسلل وتسجيل التدقيق</li>
                        <li><strong>الاستجابة للحوادث:</strong> نحتفظ بخطة استجابة للحوادث وسنُخطر هيئة البيانات والذكاء الاصطناعي السعودية (سدايا) وأصحاب البيانات المتأثرين بأي خرق للبيانات الشخصية خلال 72 ساعة كما يتطلب نظام حماية البيانات الشخصية</li>
                        <li><strong>التقييمات المنتظمة:</strong> تقييمات أمنية دورية واختبارات الثغرات</li>
                        <li><strong>تدريب الموظفين:</strong> يتلقى الموظفون الذين يتعاملون مع البيانات الشخصية تدريباً منتظماً على حماية البيانات</li>
                    </ul>
                {:else}
                    <ul class="list-disc pl-6 space-y-1">
                        <li><strong>Encryption:</strong> Data is encrypted at rest (AES-256) and in transit (TLS 1.2+)</li>
                        <li><strong>Access Controls:</strong> Role-based access control (RBAC) ensures only authorized personnel can access specific data</li>
                        <li><strong>Monitoring:</strong> Continuous security monitoring, intrusion detection, and audit logging</li>
                        <li><strong>Incident Response:</strong> We maintain an incident response plan and will notify the Saudi Data & Artificial Intelligence Authority (SDAIA) and affected data subjects of any personal data breach within 72 hours as required by the PDPL</li>
                        <li><strong>Regular Assessments:</strong> Periodic security assessments and vulnerability testing</li>
                        <li><strong>Employee Training:</strong> Staff handling personal data receive regular data protection training</li>
                    </ul>
                {/if}
            </section>

            <!-- Section 9: Data Sharing -->
            <section>
                <h2 class="text-xl font-semibold text-gray-900 mb-3">{isAr ? '9. مشاركة البيانات والإفصاح لأطراف ثالثة' : '9. Data Sharing and Third-Party Disclosure'}</h2>
                <p class="mb-2">{isAr ? 'نحن لا نبيع معلوماتك الشخصية. وفقاً لنظام حماية البيانات الشخصية السعودي (المادة 10)، قد نشارك البيانات فقط في الظروف التالية:' : 'We do not sell your personal information. In accordance with the Saudi PDPL (Article 10), we may share data only under the following circumstances:'}</p>
                {#if isAr}
                    <ul class="list-disc pr-6 space-y-1">
                        <li><strong>مزودو الخدمات:</strong> مع مزودي خدمات موثوقين يساعدون في تشغيل منصتنا (الاستضافة السحابية، واجهات برمجة الرسائل، معالجات الدفع)، ملزمين باتفاقيات معالجة بيانات تضمن حماية مكافئة للبيانات</li>
                        <li><strong>المتطلبات القانونية:</strong> عند الاقتضاء بموجب القانون السعودي أو أوامر المحكمة أو السلطات التنظيمية بما في ذلك سدايا وهيئة الاتصالات والفضاء والتقنية أو الجهات الأمنية</li>
                        <li><strong>حماية الأعمال:</strong> لحماية حقوقنا وخصوصيتنا وسلامتنا أو ممتلكاتنا، وكذلك حقوق مستخدمينا</li>
                        <li><strong>بالموافقة:</strong> بموافقتك الصريحة لأي غرض غير مشمول أعلاه</li>
                        <li><strong>نقل الأعمال:</strong> في حالة الاندماج أو الاستحواذ أو بيع الأصول، قد تُنقل بياناتك إلى الجهة الخلف، مع مراعاة نفس التزامات الخصوصية</li>
                    </ul>
                {:else}
                    <ul class="list-disc pl-6 space-y-1">
                        <li><strong>Service Providers:</strong> With trusted service providers who assist in operating our platform (cloud hosting, messaging APIs, payment processors), bound by data processing agreements ensuring equivalent data protection</li>
                        <li><strong>Legal Requirements:</strong> When required by Saudi law, court orders, or regulatory authorities including SDAIA, the Communications, Space & Technology Commission (CST), or law enforcement</li>
                        <li><strong>Business Protection:</strong> To protect our rights, privacy, safety, or property, and that of our users</li>
                        <li><strong>With Consent:</strong> With your explicit consent for any purpose not covered above</li>
                        <li><strong>Business Transfers:</strong> In the event of a merger, acquisition, or sale of assets, your data may be transferred to the successor entity, subject to the same privacy commitments</li>
                    </ul>
                {/if}
            </section>

            <!-- Section 10: Cross-Border -->
            <section>
                <h2 class="text-xl font-semibold text-gray-900 mb-3">{isAr ? '10. نقل البيانات عبر الحدود' : '10. Cross-Border Data Transfers'}</h2>
                <p class="mb-2">{isAr ? 'وفقاً لنظام حماية البيانات الشخصية السعودي (المادة 29) واللائحة العامة لحماية البيانات (الفصل الخامس):' : 'In accordance with the Saudi PDPL (Article 29) and GDPR (Chapter V):'}</p>
                {#if isAr}
                    <ul class="list-disc pr-6 space-y-1">
                        <li>تُخزن البيانات الشخصية بشكل أساسي على خوادم داخل المملكة العربية السعودية</li>
                        <li>عند الحاجة إلى نقل عبر الحدود (مثل البنية التحتية السحابية أو خدمات واجهات برمجة التطبيقات لأطراف ثالثة)، نضمن أن الدولة المستقبلة توفر مستوى كافٍ من حماية البيانات كما تحدده سدايا</li>
                        <li>ننفذ ضمانات مناسبة بما في ذلك البنود التعاقدية المعيارية أو القواعد المؤسسية الملزمة أو الموافقة الصريحة لنقل البيانات الدولي</li>
                        <li>بالنسبة للنقل إلى دول داخل المنطقة الاقتصادية الأوروبية، نلتزم بمتطلبات اللائحة العامة لحماية البيانات لنقل البيانات عبر الحدود</li>
                        <li>سيتم إخطارك بأي نقل عبر الحدود وهوية الجهة المستقبلة</li>
                    </ul>
                {:else}
                    <ul class="list-disc pl-6 space-y-1">
                        <li>Personal data is primarily stored on servers within the Kingdom of Saudi Arabia</li>
                        <li>Where cross-border transfer is necessary (e.g., cloud infrastructure, third-party API services), we ensure the receiving country provides an adequate level of data protection as determined by SDAIA</li>
                        <li>We implement appropriate safeguards including standard contractual clauses, binding corporate rules, or explicit consent for international data transfers</li>
                        <li>For transfers to countries within the European Economic Area, we comply with GDPR requirements for cross-border data transfers</li>
                        <li>You will be informed of any cross-border transfer and the identity of the recipient entity</li>
                    </ul>
                {/if}
            </section>

            <!-- Section 11: Data Retention -->
            <section>
                <h2 class="text-xl font-semibold text-gray-900 mb-3">{isAr ? '11. الاحتفاظ بالبيانات' : '11. Data Retention'}</h2>
                <p class="mb-2">{isAr ? 'وفقاً لنظام حماية البيانات الشخصية السعودي (المادة 18)، نحتفظ بالبيانات الشخصية فقط طالما كان ذلك ضرورياً لتحقيق الأغراض التي جُمعت من أجلها:' : 'In accordance with the Saudi PDPL (Article 18), we retain personal data only for as long as necessary to fulfill the purposes for which it was collected:'}</p>
                {#if isAr}
                    <ul class="list-disc pr-6 space-y-1">
                        <li><strong>بيانات الحساب:</strong> تُحتفظ بها طوال فترة نشاط حسابك بالإضافة إلى 5 سنوات للامتثال القانوني (متطلبات النظام التجاري السعودي)</li>
                        <li><strong>سجلات المعاملات:</strong> تُحتفظ بها لمدة 10 سنوات كما تتطلب اللوائح الضريبية والتجارية السعودية</li>
                        <li><strong>محادثات واتساب:</strong> تُحتفظ بها لمدة 3 سنوات لحفظ السجلات التجارية وحل النزاعات</li>
                        <li><strong>البيانات البيومترية:</strong> تُحتفظ بها طوال فترة التوظيف بالإضافة إلى سنتين، ثم تُتلف بشكل آمن</li>
                        <li><strong>سجلات الاستخدام:</strong> تُحتفظ بها لمدة سنة واحدة لمراقبة الأمان والتحليلات</li>
                        <li><strong>البيانات المحذوفة:</strong> عند طلب الحذف، تُمحى البيانات نهائياً خلال 30 يوماً، إلا إذا كان الاحتفاظ بها مطلوباً بموجب القانون</li>
                    </ul>
                {:else}
                    <ul class="list-disc pl-6 space-y-1">
                        <li><strong>Account Data:</strong> Retained for the duration of your account plus 5 years for legal compliance (Saudi Commercial Law requirements)</li>
                        <li><strong>Transaction Records:</strong> Retained for 10 years as required by Saudi tax and commercial regulations</li>
                        <li><strong>WhatsApp Conversations:</strong> Retained for 3 years for business record-keeping and dispute resolution</li>
                        <li><strong>Biometric Data:</strong> Retained for the duration of employment plus 2 years, then securely destroyed</li>
                        <li><strong>Usage Logs:</strong> Retained for 1 year for security monitoring and analytics</li>
                        <li><strong>Deleted Data:</strong> Upon deletion request, data is permanently erased within 30 days, except where retention is required by law</li>
                    </ul>
                {/if}
            </section>

            <!-- Section 12: Saudi PDPL Rights -->
            <section>
                <h2 class="text-xl font-semibold text-gray-900 mb-3">{isAr ? '12. حقوقك بموجب نظام حماية البيانات الشخصية السعودي' : '12. Your Rights Under Saudi PDPL'}</h2>
                <p class="mb-2">{isAr ? 'بموجب نظام حماية البيانات الشخصية السعودي، لديك الحقوق التالية:' : 'Under the Saudi Personal Data Protection Law, you have the following rights:'}</p>
                {#if isAr}
                    <ul class="list-disc pr-6 space-y-1">
                        <li><strong>الحق في الإعلام (المادة 11):</strong> لديك الحق في معرفة البيانات الشخصية التي نحتفظ بها عنك، والغرض من المعالجة، وهوية أي جهة تم الإفصاح لها عن بياناتك</li>
                        <li><strong>حق الوصول (المادة 12):</strong> يمكنك طلب نسخة من بياناتك الشخصية بتنسيق واضح وقابل للقراءة</li>
                        <li><strong>حق التصحيح (المادة 13):</strong> يمكنك طلب تصحيح أو إكمال أو تحديث البيانات الشخصية غير الدقيقة أو غير المكتملة</li>
                        <li><strong>حق الإتلاف (المادة 14):</strong> يمكنك طلب إتلاف بياناتك الشخصية عندما لم تعد ضرورية للغرض الذي جُمعت من أجله</li>
                        <li><strong>حق سحب الموافقة (المادة 6):</strong> عندما تستند المعالجة إلى الموافقة، يمكنك سحب الموافقة في أي وقت</li>
                        <li><strong>حق الاعتراض:</strong> يمكنك الاعتراض على معالجة بياناتك الشخصية في ظروف معينة</li>
                        <li><strong>حق نقل البيانات:</strong> يمكنك طلب بياناتك الشخصية بتنسيق منظم وشائع الاستخدام وقابل للقراءة آلياً</li>
                        <li><strong>حق تقديم شكوى:</strong> لديك الحق في تقديم شكوى إلى هيئة البيانات والذكاء الاصطناعي السعودية (سدايا) إذا كنت تعتقد أنه تم انتهاك حقوق حماية بياناتك</li>
                    </ul>
                    <p class="mt-3">لممارسة أي من هذه الحقوق، يرجى التواصل معنا على <a href="mailto:{email}" class="text-blue-600 underline">{email}</a>. سنرد على طلبك خلال 30 يوماً كما يتطلب القانون.</p>
                {:else}
                    <ul class="list-disc pl-6 space-y-1">
                        <li><strong>Right to Be Informed (Article 11):</strong> You have the right to know what personal data we hold about you, the purpose of processing, and the identity of any entity to whom your data has been disclosed</li>
                        <li><strong>Right of Access (Article 12):</strong> You may request a copy of your personal data in a clear and readable format</li>
                        <li><strong>Right to Rectification (Article 13):</strong> You may request correction, completion, or updating of inaccurate or incomplete personal data</li>
                        <li><strong>Right to Destruction (Article 14):</strong> You may request the destruction of your personal data when it is no longer necessary for the purpose for which it was collected</li>
                        <li><strong>Right to Withdraw Consent (Article 6):</strong> Where processing is based on consent, you may withdraw consent at any time</li>
                        <li><strong>Right to Object:</strong> You may object to the processing of your personal data in certain circumstances</li>
                        <li><strong>Right to Data Portability:</strong> You may request your personal data in a structured, commonly used, machine-readable format</li>
                        <li><strong>Right to Lodge a Complaint:</strong> You have the right to lodge a complaint with the Saudi Data & Artificial Intelligence Authority (SDAIA) if you believe your data protection rights have been violated</li>
                    </ul>
                    <p class="mt-3">To exercise any of these rights, please contact us at <a href="mailto:{email}" class="text-blue-600 underline">{email}</a>. We will respond to your request within 30 days as required by law.</p>
                {/if}
            </section>

            <!-- Section 13: GDPR -->
            <section>
                <h2 class="text-xl font-semibold text-gray-900 mb-3">{isAr ? '13. حقوق إضافية بموجب اللائحة العامة لحماية البيانات (لسكان المنطقة الاقتصادية الأوروبية)' : '13. Additional Rights Under GDPR (for EEA Residents)'}</h2>
                <p class="mb-2">{isAr ? 'إذا كنت مقيماً في المنطقة الاقتصادية الأوروبية، لديك بالإضافة إلى ذلك الحقوق التالية بموجب اللائحة العامة لحماية البيانات:' : 'If you are located in the European Economic Area, you additionally have the following rights under the GDPR:'}</p>
                {#if isAr}
                    <ul class="list-disc pr-6 space-y-1">
                        <li><strong>حق تقييد المعالجة (المادة 18):</strong> يمكنك طلب تقييد المعالجة في ظروف معينة</li>
                        <li><strong>حق المحو / الحق في النسيان (المادة 17):</strong> يمكنك طلب محو بياناتك الشخصية في ظروف معينة</li>
                        <li><strong>اتخاذ القرار الآلي (المادة 22):</strong> لديك الحق في عدم الخضوع لقرار يعتمد فقط على المعالجة الآلية التي تنتج آثاراً قانونية أو مماثلة بشكل كبير</li>
                        <li><strong>السلطة الإشرافية:</strong> لديك الحق في تقديم شكوى إلى سلطة حماية البيانات الإشرافية المحلية</li>
                    </ul>
                {:else}
                    <ul class="list-disc pl-6 space-y-1">
                        <li><strong>Right to Restriction of Processing (Article 18):</strong> You may request restriction of processing in certain circumstances</li>
                        <li><strong>Right to Erasure / Right to Be Forgotten (Article 17):</strong> You may request erasure of your personal data under certain conditions</li>
                        <li><strong>Automated Decision-Making (Article 22):</strong> You have the right not to be subject to a decision based solely on automated processing that produces legal or similarly significant effects</li>
                        <li><strong>Supervisory Authority:</strong> You have the right to lodge a complaint with your local data protection supervisory authority</li>
                    </ul>
                {/if}
            </section>

            <!-- Section 14: Cookies -->
            <section>
                <h2 class="text-xl font-semibold text-gray-900 mb-3">{isAr ? '14. ملفات تعريف الارتباط وتقنيات التتبع' : '14. Cookies and Tracking Technologies'}</h2>
                <p class="mb-2">{isAr ? 'قد يستخدم تطبيقنا ملفات تعريف الارتباط وتقنيات مماثلة:' : 'Our application may use cookies and similar technologies:'}</p>
                {#if isAr}
                    <ul class="list-disc pr-6 space-y-1">
                        <li><strong>ملفات تعريف الارتباط الأساسية:</strong> مطلوبة للمصادقة والأمان والوظائف الأساسية (رموز الجلسة، حماية CSRF)</li>
                        <li><strong>ملفات تعريف الارتباط الوظيفية:</strong> تُستخدم لتذكر تفضيلاتك مثل إعدادات اللغة وتفضيلات العرض</li>
                        <li><strong>ملفات تعريف الارتباط التحليلية:</strong> تُستخدم لفهم كيفية تفاعل المستخدمين مع تطبيقنا لتحسين الخدمات</li>
                        <li>يمكنك إدارة تفضيلات ملفات تعريف الارتباط من خلال إعدادات المتصفح. قد يؤثر تعطيل ملفات تعريف الارتباط الأساسية على وظائف التطبيق</li>
                    </ul>
                {:else}
                    <ul class="list-disc pl-6 space-y-1">
                        <li><strong>Essential Cookies:</strong> Required for authentication, security, and basic functionality (session tokens, CSRF protection)</li>
                        <li><strong>Functional Cookies:</strong> Used to remember your preferences such as language settings and display preferences</li>
                        <li><strong>Analytics Cookies:</strong> Used to understand how users interact with our application to improve services</li>
                        <li>You may manage cookie preferences through your browser settings. Disabling essential cookies may affect application functionality</li>
                    </ul>
                {/if}
            </section>

            <!-- Section 15: Children -->
            <section>
                <h2 class="text-xl font-semibold text-gray-900 mb-3">{isAr ? '15. خصوصية الأطفال' : '15. Children\'s Privacy'}</h2>
                {#if isAr}
                    <p>خدماتنا غير موجهة للأفراد دون سن 18 عاماً. نحن لا نجمع عمداً بيانات شخصية من القاصرين. إذا علمنا أننا جمعنا بيانات شخصية من طفل دون موافقة الوالدين، سنتخذ خطوات لحذف تلك المعلومات فوراً. إذا كنت تعتقد أننا جمعنا بيانات من قاصر عن غير قصد، يرجى التواصل معنا فوراً على <a href="mailto:{email}" class="text-blue-600 underline">{email}</a>.</p>
                {:else}
                    <p>Our services are not directed at individuals under the age of 18. We do not knowingly collect personal data from minors. If we become aware that we have collected personal data from a child without parental consent, we will take steps to delete that information promptly. If you believe we have inadvertently collected data from a minor, please contact us immediately at <a href="mailto:{email}" class="text-blue-600 underline">{email}</a>.</p>
                {/if}
            </section>

            <!-- Section 16: Changes -->
            <section>
                <h2 class="text-xl font-semibold text-gray-900 mb-3">{isAr ? '16. التغييرات على سياسة الخصوصية هذه' : '16. Changes to This Privacy Policy'}</h2>
                {#if isAr}
                    <p>قد نقوم بتحديث سياسة الخصوصية هذه من وقت لآخر لتعكس التغييرات في ممارساتنا أو التقنيات أو المتطلبات القانونية أو عوامل أخرى. سنُخطرك بأي تغييرات جوهرية عن طريق نشر السياسة المحدثة على موقعنا الإلكتروني وتحديث تاريخ "آخر تحديث". بالنسبة للتغييرات المهمة التي تؤثر على حقوقك، سنقدم إشعاراً بارزاً من خلال تطبيقنا أو عبر البريد الإلكتروني. استمرارك في استخدام خدماتنا بعد أي تغييرات يعني قبولك للسياسة المحدثة.</p>
                {:else}
                    <p>We may update this Privacy Policy from time to time to reflect changes in our practices, technologies, legal requirements, or other factors. We will notify you of any material changes by posting the updated policy on our website and updating the "Last Updated" date. For significant changes affecting your rights, we will provide prominent notice through our application or via email. Your continued use of our services after any changes constitutes acceptance of the updated policy.</p>
                {/if}
            </section>

            <!-- Section 17: Governing Law -->
            <section>
                <h2 class="text-xl font-semibold text-gray-900 mb-3">{isAr ? '17. القانون الحاكم والاختصاص القضائي' : '17. Governing Law and Jurisdiction'}</h2>
                {#if isAr}
                    <p>تخضع سياسة الخصوصية هذه وتُفسر وفقاً لأنظمة المملكة العربية السعودية. أي نزاعات ناشئة عن أو متعلقة بهذه السياسة تخضع للاختصاص الحصري للمحاكم المختصة في المملكة العربية السعودية. بالنسبة لأصحاب البيانات داخل المنطقة الاقتصادية الأوروبية، تنطبق أيضاً الأحكام المعمول بها من اللائحة العامة لحماية البيانات.</p>
                {:else}
                    <p>This Privacy Policy is governed by and construed in accordance with the laws of the Kingdom of Saudi Arabia. Any disputes arising from or related to this policy shall be subject to the exclusive jurisdiction of the competent courts in the Kingdom of Saudi Arabia. For data subjects within the European Economic Area, applicable provisions of the GDPR shall also apply.</p>
                {/if}
            </section>

            <!-- Section 18: Contact -->
            <section>
                <h2 class="text-xl font-semibold text-gray-900 mb-3">{isAr ? '18. اتصل بنا' : '18. Contact Us'}</h2>
                {#if isAr}
                    <p>إذا كانت لديك أسئلة حول سياسة الخصوصية هذه، أو ترغب في ممارسة حقوق حماية بياناتك، أو لديك مخاوف بشأن ممارسات البيانات لدينا، يرجى التواصل معنا على:</p>
                {:else}
                    <p>If you have questions about this Privacy Policy, wish to exercise your data protection rights, or have concerns about our data practices, please contact us at:</p>
                {/if}
                <div class="mt-3 bg-gray-50 rounded-lg p-4">
                    <p class="font-semibold text-gray-900">{cn}</p>
                    <p class="mt-1">{isAr ? 'البريد الإلكتروني:' : 'Email:'} <a href="mailto:{email}" class="text-blue-600 underline">{email}</a></p>
                    <p class="mt-1">{isAr ? 'الموقع الإلكتروني:' : 'Website:'} <a href={website} class="text-blue-600 underline">{website}</a></p>
                    <p class="mt-3 text-sm text-gray-500">{isAr ? 'للشكاوى المتعلقة بحماية البيانات، يمكنك أيضاً التواصل مع هيئة البيانات والذكاء الاصطناعي السعودية (سدايا) على' : 'For complaints regarding data protection, you may also contact the Saudi Data & Artificial Intelligence Authority (SDAIA) at'} <a href="https://sdaia.gov.sa" class="text-blue-600 underline">sdaia.gov.sa</a>.</p>
                </div>
            </section>
        </div>

        <div class="mt-10 pt-6 border-t border-gray-200 text-center">
            <a href="/" class="text-blue-600 hover:underline text-sm">{isAr ? '← العودة إلى' : '← Back to'} {an}</a>
        </div>
    </div>
</div>
