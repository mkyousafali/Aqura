import { json } from '@sveltejs/kit';
import { env } from '$env/dynamic/private';

// Function to create OpenAI client with error handling
function createOpenAIClient() {
	try {
		const apiKey = env.OPENAI_API_KEY || env.VITE_OPENAI_API_KEY || process.env.OPENAI_API_KEY || process.env.VITE_OPENAI_API_KEY;
		
		if (!apiKey) {
			console.warn('No OpenAI API key found in environment variables');
			return null;
		}

		// Dynamic import to avoid initialization errors during build
		return import('openai').then(({ default: OpenAI }) => {
			return new OpenAI({ apiKey });
		});
	} catch (error) {
		console.error('Failed to create OpenAI client:', error);
		return null;
	}
}

export async function POST({ request }) {
	try {
		console.log('API route accessed, checking environment...');
		
		// Create OpenAI client
		const openaiClientPromise = createOpenAIClient();
		if (!openaiClientPromise) {
			console.error('Failed to create OpenAI client');
			return json({ 
				error: 'OpenAI API key not configured. Please check server environment variables.' 
			}, { status: 500 });
		}

		const body = await request.json();
		console.log('Request body received:', JSON.stringify(body, null, 2));

		// Extract assignment and language from the correct structure
		const { assignment, language = 'en' } = body;

		// Debug logging
		console.log('Assignment object keys:', assignment ? Object.keys(assignment) : 'assignment is null/undefined');
		console.log('Assignment object:', assignment);
		console.log('Language:', language);

		// Validate required data
		if (!assignment) {
			return json({ error: 'Assignment data is required' }, { status: 400 });
		}

		// Extract data from assignment - TASK-SPECIFIC VERSION
		const recipientName = assignment.assigned_to || assignment.assignedTo || assignment.username || 'Employee';
		const assignedBy = assignment.assigned_by || assignment.assignedBy || 'Manager';
		const taskTitle = assignment.task_title || assignment.taskTitle || 'Untitled Task';
		const taskDescription = assignment.task_description || assignment.taskDescription || '';
		const taskType = assignment.type || assignment.assignment_type || 'regular';
		const taskPriority = assignment.priority || 'medium';
		const taskStatus = assignment.status || 'pending';
		const taskDeadline = assignment.deadline;
		const branchName = assignment.assigned_to_branch || assignment.branch || 'Not specified';
		const warningLevel = assignment.warning_level || 'normal';
		const isOverdue = assignment.warning_level === 'critical';
		const isDueSoon = assignment.warning_level === 'warning';
		const warningType = assignment.warningType || 'task_delay_no_fine';
		const fineAmount = assignment.fineAmount;
		const fineCurrency = assignment.fineCurrency || 'SAR';
		const taskId = assignment.task_id || assignment.id;
		
		// Extract performance statistics
		const totalAssigned = assignment.total_assigned || assignment.totalAssigned || 0;
		const totalCompleted = assignment.total_completed || assignment.totalCompleted || 0;
		const totalOverdue = assignment.total_overdue || assignment.totalOverdue || 0;
		const completionRate = assignment.completion_rate || assignment.completionRate || 
								(totalAssigned > 0 ? Math.round((totalCompleted / totalAssigned) * 100) : 0);

		console.log('Extracted warning type:', warningType);
		console.log('Extracted fine amount:', fineAmount);
		console.log('Extracted task details:', { taskId, taskTitle, taskDescription, taskPriority, taskStatus });
		console.log('Extracted recipient name:', recipientName);
		console.log('Extracted language:', language);
		console.log('Task warning level:', warningLevel, '| Overdue:', isOverdue, '| Due Soon:', isDueSoon);

		// More lenient validation - only check for language since we provide defaults for other fields
		if (!language) {
			return json({ 
				error: 'Language is required' 
			}, { status: 400 });
		}

		// Log the final recipient name to debug
		console.log('Final recipient name for warning:', recipientName);

		// Parse warning type to get specific components
		const isTaskSpecific = true; // Now using task-specific warnings
		let fineType = 'no_fine';
		
		if (warningType.includes('with_fine')) {
			fineType = 'immediate_fine';
		} else if (warningType.includes('fine_threat')) {
			fineType = 'fine_threat';
		}

		console.log('Parsed warning type - fineType:', fineType);
		console.log('Is task-specific warning:', isTaskSpecific);

		// Map language codes to full names
		const languageMapping = {
			en: 'english',
			ar: 'arabic',
			ur: 'urdu',
			hi: 'hindi',
			ta: 'tamil',
			ml: 'malayalam',
			bn: 'bengali'
		};

		const mappedLanguage = languageMapping[language] || 'english';
		console.log('Mapped language:', mappedLanguage);

		// Task details are no longer needed since we removed task-specific warnings
		let taskDetails = null;

		// Generate fine text based on fine type
		const fineText = {
			no_fine: {
				english: '',
				arabic: '',
				urdu: '',
				hindi: '',
				tamil: '',
				malayalam: '',
				bengali: ''
			},
			fine_threat: {
				english: `IMPORTANT WARNING: Continued poor performance may result in financial penalties of up to ${fineAmount || 50} ${fineCurrency}. This amount will be deducted from future salary payments if performance does not improve immediately.`,
								arabic: `تحذير هام: قد يؤدي استمرار ضعف الأداء إلى فرض غرامات مالية تصل إلى ${fineAmount || 50} ${fineCurrency}. سيتم خصم هذا المبلغ من الراتب المستقبلي إذا لم يتحسن الأداء فوراً.`,
								urdu: `اہم تنبیہ: کارکردگی میں مسلسل کمی کی صورت میں ${fineAmount || 50} ${fineCurrency} تک مالی جرمانہ عائد کیا جا سکتا ہے۔ اگر کارکردگی فوری طور پر بہتر نہیں ہوتی تو یہ رقم مستقبل کی تنخواہ سے کاٹی جائے گی۔`,
				hindi: `महत्वपूर्ण चेतावनी: निरंतर खराब प्रदर्शन के परिणामस्वरूप ${fineAmount || 50} ${fineCurrency} तक का वित्तीय दंड हो सकता है। यदि प्रदर्शन तुरंत नहीं सुधरता तो यह राशि भविष्य के वेतन भुगतान से काटी जाएगी।`,
				tamil: `முக்கிய எச்சரிக்கை: தொடர்ந்து மோசமான செயல்திறன் ${fineAmount || 50} ${fineCurrency} வரை நிதி அபராதங்களுக்கு வழிவகுக்கும். செயல்திறன் உடனடியாக மேம்படாவிட்டால் இந்த தொகை எதிர்கால சம்பள கொடுப்பனவுகளில் இருந்து கழிக்கப்படும்।`,
				malayalam: `പ്രധാന മുന്നറിയിപ്പ്: തുടർച്ചയായ മോശം പ്രകടനം ${fineAmount || 50} ${fineCurrency} വരെ സാമ്പത്തിക പിഴകളിലേക്ക് നയിച്ചേക്കാം. പ്രകടനം ഉടനടി മെച്ചപ്പെടുന്നില്ലെങ്കിൽ ഈ തുക ഭാവി ശമ്പള പേയ്മെന്റുകളിൽ നിന്ന് കിഴിക്കും.`,
				bengali: `গুরুত্বপূর্ণ সতর্কতা: ক্রমাগত খারাপ পারফরমেন্সের ফলে ${fineAmount || 50} ${fineCurrency} পর্যন্ত আর্থিক জরিমানা হতে পারে। যদি পারফরমেন্স অবিলম্বে উন্নত না হয় তাহলে এই পরিমাণ ভবিষ্যতের বেতন পেমেন্ট থেকে কাটা হবে।`
			},
			immediate_fine: {
				english: `Financial Penalty: A fine of ${fineAmount || 0} ${fineCurrency} has been imposed due to this performance issue and will be deducted from your next salary payment.`,
				arabic: `الغرامة المالية: تم فرض غرامة قدرها ${fineAmount || 0} ${fineCurrency} بسبب هذه المشكلة في الأداء وسيتم خصمها من راتبك القادم.`,
				urdu: `مالی جرمانہ: اس کارکردگی کے مسئلے کی وجہ سے ${fineAmount || 0} ${fineCurrency} کا جرمانہ عائد کیا گیا ہے اور آپ کی اگلی تنخواہ سے کاٹا جائے گا۔`,
				hindi: `वित्तीय दंड: इस प्रदर्शन समस्या के कारण ${fineAmount || 0} ${fineCurrency} का जुर्माना लगाया गया है और यह आपके अगले वेतन भुगतान से काटा जाएगा।`,
				tamil: `நிதி அபராதம்: இந்த செயல்திறன் பிரச்சினையின் காரணமாக ${fineAmount || 0} ${fineCurrency} அபராதம் விதிக்கப்பட்டுள்ளது மற்றும் உங்கள் அடுத்த சம்பள கட்டணத்திலிருந்து கழிக்கப்படும்.`,
				malayalam: `സാമ്പത്തിക പിഴ: ഈ പ്രകടന പ്രശ്നം കാരണം ${fineAmount || 0} ${fineCurrency} പിഴ ചുമത്തിയിട്டുണ്ട്, ഇത് നിങ്ങളുടെ അടുത്ത ശമ്പള പേയ്മെന്റിൽ നിന്ന് കിഴിക്കപ്പെടും.`,
				bengali: `আর্থিক জরিমানা: এই পারফরমেন্স সমস্যার কারণে ${fineAmount || 0} ${fineCurrency} জরিমানা আরোপ করা হয়েছে এবং এটি আপনার পরবর্তী বেতন পেমেন্ট থেকে কাটা হবে।`
			}
		};

		// Format deadline and status text for use in prompts (before function definition)
		const deadlineText = taskDeadline ? new Date(taskDeadline).toLocaleString() : 'Not specified';
		const overdueText = isOverdue ? ' (OVERDUE)' : isDueSoon ? ' (DUE SOON)' : '';

		// Create comprehensive prompt system for TASK-SPECIFIC warnings
		function createWarningPrompt(lang, warningType, taskDetails, fineInfo) {
			const { fineAmount, fineCurrency, fineType } = fineInfo;
			
			const basePrompts = {
				english: `Generate a professional warning notice for an employee regarding a specific task issue.

Employee Details:
- Name: ${recipientName}
- Assigned By: ${assignedBy}
- Branch: ${branchName}

Task Details:
- Task Title: ${taskTitle}
- Task Description: ${taskDescription}
- Task Type: ${taskType}
- Priority: ${taskPriority}
- Current Status: ${taskStatus}
- Deadline: ${deadlineText}${overdueText}
- Warning Level: ${warningLevel}`,

				arabic: `أنشئ إشعار تحذير مهني لموظف بخصوص مشكلة في مهمة محددة.

تفاصيل الموظف:
- الاسم: ${recipientName}
- مكلف من قبل: ${assignedBy}
- الفرع: ${branchName}

تفاصيل المهمة:
- عنوان المهمة: ${taskTitle}
- وصف المهمة: ${taskDescription}
- نوع المهمة: ${taskType}
- الأولوية: ${taskPriority}
- الحالة الحالية: ${taskStatus}
- الموعد النهائي: ${deadlineText}${overdueText}
- مستوى التحذير: ${warningLevel}`,

				urdu: `ایک مخصوص کام کے مسئلے کے بارے میں ملازم کے لیے پیشہ ورانہ تنبیہی نوٹس تیار کریں۔

ملازم کی تفصیلات:
- نام: ${recipientName}
- تفویض کنندہ: ${assignedBy}
- شاخ: ${branchName}

کام کی تفصیلات:
- کام کا عنوان: ${taskTitle}
- کام کی تفصیل: ${taskDescription}
- کام کی قسم: ${taskType}
- ترجیح: ${taskPriority}
- موجودہ حالت: ${taskStatus}
- آخری تاریخ: ${deadlineText}${overdueText}
- تنبیہ کی سطح: ${warningLevel}`,

				hindi: `एक विशिष्ट कार्य मुद्दे के संबंध में कर्मचारी के लिए पेशेवर चेतावनी नोटिस तैयार करें।

कर्मचारी विवरण:
- नाम: ${recipientName}
- द्वारा सौंपा गया: ${assignedBy}
- शाखा: ${branchName}

कार्य विवरण:
- कार्य शीर्षक: ${taskTitle}
- कार्य विवरण: ${taskDescription}
- कार्य प्रकार: ${taskType}
- प्राथमिकता: ${taskPriority}
- वर्तमान स्थिति: ${taskStatus}
- समय सीमा: ${deadlineText}${overdueText}
- चेतावनी स्तर: ${warningLevel}`,

				tamil: `ஒரு குறிப்பிட்ட பணி பிரச்சினை தொடர்பாக ஊழியருக்கான தொழில்முறை எச்சரிக்கை அறிவிப்பை உருவாக்கவும்.

ஊழியர் விவரங்கள்:
- பெயர்: ${recipientName}
- ஒதுக்கியவர்: ${assignedBy}
- கிளை: ${branchName}

பணி விவரங்கள்:
- பணி தலைப்பு: ${taskTitle}
- பணி விவரணை: ${taskDescription}
- பணி வகை: ${taskType}
- முன்னுரிமை: ${taskPriority}
- தற்போதைய நிலை: ${taskStatus}
- காலக்கெடு: ${deadlineText}${overdueText}
- எச்சரிக்கை நிலை: ${warningLevel}`,

				malayalam: `ഒരു നിർദ്ദിഷ്ട ടാസ്ക് പ്രശ്നവുമായി ബന്ധപ്പെട്ട് ഒരു ജീവനക്കാരനുള്ള പ്രൊഫഷണൽ മുന്നറിയിപ്പ് നോട്ടീസ് സൃഷ്ടിക്കുക.

ജീവനക്കാരുടെ വിശദാംശങ്ങൾ:
- പേര്: ${recipientName}
- നൽകിയത്: ${assignedBy}
- ബ്രാഞ്ച്: ${branchName}

ടാസ്ക് വിശദാംശങ്ങൾ:
- ടാസ്ക് ശീർഷകം: ${taskTitle}
- ടാസ്ക് വിവരണം: ${taskDescription}
- ടാസ്ക് തരം: ${taskType}
- മുൻഗണന: ${taskPriority}
- നിലവിലെ നില: ${taskStatus}
- അവസാന തീയതി: ${deadlineText}${overdueText}
- മുന്നറിയിപ്പ് നില: ${warningLevel}`,

				bengali: `একটি নির্দিষ্ট টাস্ক সমস্যা সম্পর্কে কর্মচারীর জন্য পেশাদার সতর্কতা নোটিশ তৈরি করুন।

কর্মচারীর বিবরণ:
- নাম: ${recipientName}
- দ্বারা নিয়োগ: ${assignedBy}
- শাখা: ${branchName}

টাস্ক বিবরণ:
- টাস্ক শিরোনাম: ${taskTitle}
- টাস্ক বর্ণনা: ${taskDescription}
- টাস্ক ধরন: ${taskType}
- অগ্রাধিকার: ${taskPriority}
- বর্তমান অবস্থা: ${taskStatus}
- সময়সীমা: ${deadlineText}${overdueText}
- সতর্কতা স্তর: ${warningLevel}`
			};

			return basePrompts[lang] || basePrompts.english;
		}

		// Prepare the system prompt based on language and warning type
		const basePrompt = createWarningPrompt(mappedLanguage, warningType, taskDetails, { fineAmount, fineCurrency, fineType });
		
		const commonRequirements = {
			english: `

${fineText[fineType]?.english || ''}

Please generate a formal, professional warning letter content that:
1. Addresses the specific task issue mentioned above (Task: "${taskTitle}")
2. **MUST include specific details from the task description**: "${taskDescription}" - Reference what needs to be done based on this description
3. References the task details including priority (${taskPriority}), status (${taskStatus}), and deadline${overdueText}
4. ${isOverdue ? 'Emphasizes that the task is OVERDUE and requires immediate action' : isDueSoon ? 'Notes that the deadline is approaching soon' : 'Highlights the importance of timely task completion'}
5. Explains the impact of ${isOverdue ? 'this delay' : 'not completing this task on time'} on team productivity and workflow
6. Sets clear expectations for immediate action and task completion, referencing the specific requirements from the task description
7. Mentions potential consequences if the task is not completed promptly
8. Maintains a professional but firm tone appropriate to the ${taskPriority} priority level
9. Requests a response with action plan and completion timeline
${fineType !== 'no_fine' ? '10. CRITICAL: MUST include the exact fine information provided above - mention the specific amount and currency prominently' : ''}

CRITICAL REQUIREMENTS - MUST FOLLOW:
- **MUST include details from the task description** "${taskDescription}" in the warning text to provide context about what needs to be done
- Do NOT include any dates, sender names, recipient names, or company names
- Do NOT include ANY placeholders like [Your Name], [Your Title], [Company Name], [Date], [HR Assistant], etc.
- Do NOT include signature lines or closing salutations like "Sincerely, [Your Name]"
- Do NOT include any bracketed placeholders or template markers
- Start directly with the warning content paragraph
- End with the main content - no signatures or names
- The response should ONLY be the warning paragraph content
${fineType !== 'no_fine' ? '- MUST include the exact fine text provided above word-for-word in the warning' : ''}`,

			arabic: `

${fineText[fineType]?.arabic || ''}

يرجى إنشاء محتوى خطاب تحذير رسمي ومهني يتضمن:
1. معالجة مشكلة المهمة المحددة المذكورة أعلاه (المهمة: "${taskTitle}")
2. **يجب تضمين تفاصيل محددة من وصف المهمة**: "${taskDescription}" - الإشارة إلى ما يجب القيام به بناءً على هذا الوصف
3. الإشارة إلى تفاصيل المهمة بما في ذلك الأولوية (${taskPriority})، والحالة (${taskStatus})، والموعد النهائي${overdueText}
4. ${isOverdue ? 'التأكيد على أن المهمة متأخرة وتتطلب إجراءً فورياً' : isDueSoon ? 'ملاحظة أن الموعد النهائي يقترب قريباً' : 'تسليط الضوء على أهمية إكمال المهمة في الوقت المحدد'}
5. شرح تأثير ${isOverdue ? 'هذا التأخير' : 'عدم إكمال هذه المهمة في الوقت المحدد'} على إنتاجية الفريق وسير العمل
6. وضع توقعات واضحة للإجراء الفوري وإكمال المهمة، مع الإشارة إلى المتطلبات المحددة من وصف المهمة
7. ذكر العواقب المحتملة إذا لم يتم إكمال المهمة بسرعة
8. الحفاظ على نبرة مهنية لكن حازمة مناسبة لمستوى الأولوية ${taskPriority}
9. طلب رد مع خطة العمل والجدول الزمني للإكمال
${fineType !== 'no_fine' ? '10. حاسم: يجب تضمين معلومات الغرامة المحددة أعلاه - ذكر المبلغ والعملة المحددة بوضوح' : ''}

متطلبات حاسمة - يجب اتباعها:
- **يجب تضمين تفاصيل من وصف المهمة** "${taskDescription}" في نص التحذير لتوفير السياق حول ما يجب القيام به
- لا تضع أي تواريخ أو أسماء مرسلين أو أسماء مستقبلين أو أسماء شركات
- لا تضع أي متغيرات وهمية مثل [اسمك]، [منصبك]، [اسم الشركة]، [التاريخ]، [مساعد الموارد البشرية]، إلخ
- لا تضع خطوط توقيع أو تحيات ختامية مثل "مع التقدير، [اسمك]"
- لا تضع أي متغيرات بين أقواس أو علامات قوالب
- ابدأ مباشرة بفقرة محتوى التحذير
- انته بالمحتوى الرئيسي - بدون توقيعات أو أسماء
- يجب أن تكون الاستجابة فقط محتوى فقرة التحذير
${fineType !== 'no_fine' ? '- يجب تضمين نص الغرامة المقدم أعلاه كلمة بكلمة في التحذير' : ''}`,

			urdu: `

${fineText[fineType]?.urdu || ''}

براہ کرم ایک رسمی، پیشہ ورانہ تنبیہی خط کا مواد تیار کریں جس میں:
1. اوپر بیان کردہ مخصوص کام کے مسئلے کو حل کریں (کام: "${taskTitle}")
2. **کام کی تفصیل سے مخصوص تفصیلات شامل کریں**: "${taskDescription}" - اس تفصیل کی بنیاد پر کیا کرنے کی ضرورت ہے اس کا حوالہ دیں
3. کام کی تفصیلات کا حوالہ دیں بشمول ترجیح (${taskPriority})، حالت (${taskStatus})، اور آخری تاریخ${overdueText}
4. ${isOverdue ? 'اس بات پر زور دیں کہ کام تاخیر سے ہے اور فوری کارروائی کی ضرورت ہے' : isDueSoon ? 'نوٹ کریں کہ آخری تاریخ جلد آ رہی ہے' : 'بروقت کام مکمل کرنے کی اہمیت کو اجاگر کریں'}
5. ${isOverdue ? 'اس تاخیر' : 'وقت پر اس کام کو مکمل نہ کرنے'} کے ٹیم کی پیداوار اور کام کے بہاؤ پر اثرات کی وضاحت کریں
6. فوری کارروائی اور کام کی تکمیل کے لیے واضح توقعات مقرر کریں، کام کی تفصیل سے مخصوص ضروریات کا حوالہ دیتے ہوئے
7. اگر کام فوری طور پر مکمل نہیں ہوتا تو ممکنہ نتائج کا ذکر کریں
8. ${taskPriority} ترجیح کی سطح کے مطابق پیشہ ورانہ لیکن سخت لہجہ برقرار رکھیں
9. عمل کے منصوبے اور تکمیل کی ٹائم لائن کے ساتھ جواب کی درخواست کریں
${fineType !== 'no_fine' ? '10. اہم: لازمی طور پر اوپر فراہم کردہ جرمانے کی معلومات - مخصوص رقم اور کرنسی کا واضح ذکر کریں' : ''}

اہم ضروریات - لازمی پیروی کریں:
- **کام کی تفصیل سے تفصیلات شامل کریں** "${taskDescription}" تنبیہ کے متن میں تاکہ کیا کرنے کی ضرورت ہے اس کا سیاق و سباق فراہم کیا جا سکے
- کوئی تاریخ، بھیجنے والے کا نام، وصول کنندہ کا نام، یا کمپنی کا نام شامل نہ کریں
- [آپ کا نام]، [آپ کا عہدہ]، [کمپنی کا نام]، [تاریخ]، [HR اسسٹنٹ] وغیرہ جیسے کوئی placeholder شامل نہ کریں
- دستخط کی لائنیں یا اختتامی سلام جیسے "خلوص کے ساتھ، [آپ کا نام]" شامل نہ کریں
- کوئی بریکٹ والے placeholder یا ٹیمپلیٹ markers شامل نہ کریں
- براہ راست تنبیہ کے مواد کے پیراگراف سے شروع کریں
- بنیادی مواد کے ساتھ ختم کریں - کوئی دستخط یا نام نہیں
- جواب صرف تنبیہ کے پیراگراف کا مواد ہونا چاہیے
${fineType !== 'no_fine' ? '- لازمی طور پر اوپر فراہم کردہ جرمانے کا متن لفظ بہ لفظ تنبیہ میں شامل کریں' : ''}`
		};

		const systemPrompt = basePrompt + (commonRequirements[mappedLanguage] || commonRequirements.english);
		console.log('Using prompt for language:', mappedLanguage);
		console.log('Prompt preview:', systemPrompt.substring(0, 200) + '...');

		// Get OpenAI client
		const openai = await openaiClientPromise;
		if (!openai) {
			throw new Error('Failed to initialize OpenAI client');
		}

		// Call OpenAI API
		const completion = await openai.chat.completions.create({
			model: 'gpt-3.5-turbo',
			messages: [
				{
					role: 'system',
					content: `You are a professional HR assistant that generates formal warning letters for workplace performance issues. Always maintain a professional, firm but respectful tone. Respond ONLY in ${mappedLanguage}. Do not mix languages. CRITICAL: Never include placeholders like [Your Name], [HR Assistant], [Date], [Company Name] or any bracketed text. Never include signature lines or closing salutations. Generate only the warning content paragraph.`
				},
				{
					role: 'user',
					content: systemPrompt
				}
			],
			max_tokens: 800,
			temperature: 0.7
		});

		const warning = completion.choices[0]?.message?.content;

		if (!warning) {
			throw new Error('No warning content generated');
		}

		// Clean up any remaining placeholders or unwanted content
		let cleanedWarning = warning.trim()
			// Remove common placeholder patterns
			.replace(/\[Your Name\].*$/gm, '')
			.replace(/\[.*?\]/g, '')
			.replace(/Sincerely,.*$/gm, '')
			.replace(/Best regards,.*$/gm, '')
			.replace(/HR Assistant.*$/gm, '')
			.replace(/مع التقدير،.*$/gm, '')
			.replace(/مساعد الموارد البشرية.*$/gm, '')
			// Remove empty lines at the end
			.replace(/\n\s*\n\s*$/g, '')
			.trim();

		return json({ 
			warning: cleanedWarning,
			metadata: {
				language: mappedLanguage,
				warningType,
				fineType,
				isTaskSpecific,
				taskDetails,
				fineAmount: fineType === 'immediate_fine' ? fineAmount : null,
				fineCurrency: fineType === 'immediate_fine' ? fineCurrency : null
			}
		});

	} catch (error) {
		console.error('Error generating warning:', error);
		console.error('Error stack:', error.stack);
		
		// Return user-friendly error message
		return json({ 
			error: 'Failed to generate warning. Please try again.',
			details: error.message,
			type: 'generation_error'
		}, { status: 500 });
	}
}