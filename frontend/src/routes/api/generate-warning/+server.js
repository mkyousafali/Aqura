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

Please generate a SHORT and CONCISE formal warning (maximum 4-5 sentences) that:
1. Mentions ONLY the task name: "${taskTitle}"
2. References the deadline${overdueText} and branch: ${branchName}
3. ${isOverdue ? 'States this is OVERDUE and needs immediate action' : isDueSoon ? 'Notes the deadline is approaching' : 'Emphasizes timely completion'}
4. Briefly states consequences of delay
${fineType !== 'no_fine' ? '5. Includes the fine information above' : ''}

CRITICAL - KEEP IT SHORT:
- Maximum 4-5 sentences only
- Do NOT include full task description details
- Do NOT mention task type, priority, status, or description
- Only mention: Task name, deadline, branch
- No placeholders like [Name], [Date], [Company]
- No signatures or salutations
- Direct warning content only
${fineType !== 'no_fine' ? '- Must include fine amount and currency' : ''}`,

			arabic: `

${fineText[fineType]?.arabic || ''}

أنشئ تحذيراً رسمياً قصيراً وموجزاً (4-5 جمل كحد أقصى) يتضمن:
1. ذكر اسم المهمة فقط: "${taskTitle}"
2. الإشارة إلى الموعد النهائي${overdueText} والفرع: ${branchName}
3. ${isOverdue ? 'التصريح بأن المهمة متأخرة وتحتاج إجراءً فورياً' : isDueSoon ? 'ملاحظة اقتراب الموعد النهائي' : 'التأكيد على الإنجاز في الوقت المحدد'}
4. ذكر موجز لعواقب التأخير
${fineType !== 'no_fine' ? '5. تضمين معلومات الغرامة أعلاه' : ''}

حاسم - اجعله قصيراً:
- 4-5 جمل كحد أقصى فقط
- لا تضمن تفاصيل وصف المهمة الكامل
- لا تذكر نوع المهمة أو الأولوية أو الحالة أو الوصف
- اذكر فقط: اسم المهمة، الموعد النهائي، الفرع
- لا تضع متغيرات مثل [الاسم]، [التاريخ]، [الشركة]
- لا توقيعات أو تحيات
- محتوى التحذير مباشرة فقط
${fineType !== 'no_fine' ? '- يجب تضمين مبلغ وعملة الغرامة' : ''}`,

			urdu: `

${fineText[fineType]?.urdu || ''}

ایک مختصر اور جامع رسمی تنبیہ (زیادہ سے زیادہ 4-5 جملے) تیار کریں جس میں:
1. صرف کام کا نام بتائیں: "${taskTitle}"
2. آخری تاریخ${overdueText} اور شاخ کا حوالہ دیں: ${branchName}
3. ${isOverdue ? 'بیان کریں کہ یہ تاخیر سے ہے اور فوری کارروائی چاہیے' : isDueSoon ? 'نوٹ کریں کہ آخری تاریخ قریب آ رہی ہے' : 'بروقت تکمیل پر زور دیں'}
4. تاخیر کے نتائج کا مختصر ذکر کریں
${fineType !== 'no_fine' ? '5. اوپر جرمانے کی معلومات شامل کریں' : ''}

اہم - مختصر رکھیں:
- زیادہ سے زیادہ 4-5 جملے
- کام کی مکمل تفصیل شامل نہ کریں
- کام کی قسم، ترجیح، حالت، یا تفصیل نہ بتائیں
- صرف بتائیں: کام کا نام، آخری تاریخ، شاخ
- [نام]، [تاریخ]، [کمپنی] جیسے placeholders نہیں
- دستخط یا سلام نہیں
- صرف تنبیہ کا مواد براہ راست
${fineType !== 'no_fine' ? '- جرمانے کی رقم اور کرنسی شامل کریں' : ''}`,

			hindi: `

${fineText[fineType]?.hindi || ''}

एक संक्षिप्त और स्पष्ट औपचारिक चेतावनी (अधिकतम 4-5 वाक्य) तैयार करें जो:
1. केवल कार्य का नाम बताएं: "${taskTitle}"
2. समय सीमा${overdueText} और शाखा का उल्लेख करें: ${branchName}
3. ${isOverdue ? 'बताएं कि यह विलंबित है और तत्काल कार्रवाई की आवश्यकता है' : isDueSoon ? 'नोट करें कि समय सीमा नजदीक आ रही है' : 'समय पर पूरा करने पर जोर दें'}
4. देरी के परिणामों का संक्षिप्त उल्लेख करें
${fineType !== 'no_fine' ? '5. ऊपर दिए गए जुर्माने की जानकारी शामिल करें' : ''}

महत्वपूर्ण - संक्षिप्त रखें:
- केवल अधिकतम 4-5 वाक्य
- पूर्ण कार्य विवरण शामिल न करें
- कार्य प्रकार, प्राथमिकता, स्थिति या विवरण का उल्लेख न करें
- केवल बताएं: कार्य का नाम, समय सीमा, शाखा
- [नाम], [तिथि], [कंपनी] जैसे placeholders नहीं
- हस्ताक्षर या अभिवादन नहीं
- केवल सीधे चेतावनी की सामग्री
${fineType !== 'no_fine' ? '- जुर्माने की राशि और मुद्रा शामिल करें' : ''}`,

			tamil: `

${fineText[fineType]?.tamil || ''}

ஒரு சுருக்கமான மற்றும் தெளிவான முறையான எச்சரிக்கை (அதிகபட்சம் 4-5 வாக்கியங்கள்) உருவாக்கவும்:
1. பணி பெயர் மட்டும் குறிப்பிடவும்: "${taskTitle}"
2. காலக்கெடு${overdueText} மற்றும் கிளையை குறிப்பிடவும்: ${branchName}
3. ${isOverdue ? 'இது தாமதமானது மற்றும் உடனடி நடவடிக்கை தேவை என்று கூறவும்' : isDueSoon ? 'காலக்கெடு நெருங்குகிறது என்று குறிப்பிடவும்' : 'சரியான நேரத்தில் முடிப்பதை வலியுறுத்தவும்'}
4. தாமதத்தின் விளைவுகளை சுருக்கமாக கூறவும்
${fineType !== 'no_fine' ? '5. மேலே உள்ள அபராத தகவலை சேர்க்கவும்' : ''}

முக்கியம் - சுருக்கமாக வைக்கவும்:
- அதிகபட்சம் 4-5 வாக்கியங்கள் மட்டும்
- முழு பணி விவரங்களை சேர்க்காதீர்கள்
- பணி வகை, முன்னுரிமை, நிலை அல்லது விவரணையை குறிப்பிடாதீர்கள்
- மட்டும் குறிப்பிடவும்: பணி பெயர், காலக்கெடு, கிளை
- [பெயர்], [தேதி], [நிறுவனம்] போன்ற placeholders இல்லை
- கையொப்பம் அல்லது வாழ்த்துக்கள் இல்லை
- நேரடியாக எச்சரிக்கை உள்ளடக்கம் மட்டும்
${fineType !== 'no_fine' ? '- அபராத தொகை மற்றும் நாணயத்தை சேர்க்கவும்' : ''}`,

			malayalam: `

${fineText[fineType]?.malayalam || ''}

ഒരു ചെറുതും വ്യക്തവുമായ ഔപചാരിക മുന്നറിയിപ്പ് (പരമാവധി 4-5 വാക്യങ്ങൾ) സൃഷ്ടിക്കുക:
1. ടാസ്ക് പേര് മാത്രം പരാമർശിക്കുക: "${taskTitle}"
2. അവസാന തീയതി${overdueText} ഉം ബ്രാഞ്ചും പരാമർശിക്കുക: ${branchName}
3. ${isOverdue ? 'ഇത് കാലഹരണപ്പെട്ടതാണെന്നും ഉടനടി നടപടി ആവശ്യമാണെന്നും പറയുക' : isDueSoon ? 'അവസാന തീയതി അടുത്തുവരുന്നുവെന്ന് രേഖപ്പെടുത്തുക' : 'സമയബന്ധിതമായ പൂർത്തീകരണം ഊന്നിപ്പറയുക'}
4. കാലതാമസത്തിന്റെ അനന്തരഫലങ്ങൾ ചുരുക്കി പറയുക
${fineType !== 'no_fine' ? '5. മുകളിൽ നൽകിയ പിഴ വിവരങ്ങൾ ഉൾപ്പെടുത്തുക' : ''}

നിർണായകം - ചെറുതാക്കുക:
- പരമാവധി 4-5 വാക്യങ്ങൾ മാത്രം
- മുഴുവൻ ടാസ്ക് വിവരണം ഉൾപ്പെടുത്തരുത്
- ടാസ്ക് തരം, മുൻഗണന, നില അല്ലെങ്കിൽ വിവരണം പരാമർശിക്കരുത്
- മാത്രം പരാമർശിക്കുക: ടാസ്ക് പേര്, അവസാന തീയതി, ബ്രാഞ്ച്
- [പേര്], [തീയതി], [കമ്പനി] പോലുള്ള placeholders ഇല്ല
- ഒപ്പുകളോ അഭിവാദനങ്ങളോ ഇല്ല
- നേരിട്ടുള്ള മുന്നറിയിപ്പ് ഉള്ളടക്കം മാത്രം
${fineType !== 'no_fine' ? '- പിഴ തുകയും കറൻസിയും ഉൾപ്പെടുത്തുക' : ''}`,

			bengali: `

${fineText[fineType]?.bengali || ''}

একটি সংক্ষিপ্ত এবং স্পষ্ট আনুষ্ঠানিক সতর্কতা (সর্বোচ্চ 4-5 বাক্য) তৈরি করুন যা:
1. শুধুমাত্র টাস্কের নাম উল্লেখ করুন: "${taskTitle}"
2. সময়সীমা${overdueText} এবং শাখা উল্লেখ করুন: ${branchName}
3. ${isOverdue ? 'বলুন এটি বিলম্বিত এবং অবিলম্বে পদক্ষেপ প্রয়োজন' : isDueSoon ? 'নোট করুন যে সময়সীমা এগিয়ে আসছে' : 'সময়মত সমাপ্তির উপর জোর দিন'}
4. বিলম্বের পরিণতি সংক্ষেপে বলুন
${fineType !== 'no_fine' ? '5. উপরের জরিমানা তথ্য অন্তর্ভুক্ত করুন' : ''}

গুরুত্বপূর্ণ - সংক্ষিপ্ত রাখুন:
- সর্বোচ্চ 4-5 বাক্য মাত্র
- সম্পূর্ণ টাস্ক বিবরণ অন্তর্ভুক্ত করবেন না
- টাস্ক ধরন, অগ্রাধিকার, অবস্থা বা বর্ণনা উল্লেখ করবেন না
- শুধুমাত্র উল্লেখ করুন: টাস্ক নাম, সময়সীমা, শাখা
- [নাম], [তারিখ], [কোম্পানি] এর মত placeholders নেই
- স্বাক্ষর বা শুভেচ্ছা নেই
- সরাসরি সতর্কতা বিষয়বস্তু শুধুমাত্র
${fineType !== 'no_fine' ? '- জরিমানা পরিমাণ এবং মুদ্রা অন্তর্ভুক্ত করুন' : ''}`
		};		const systemPrompt = basePrompt + (commonRequirements[mappedLanguage] || commonRequirements.english);
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
					content: `You are a professional HR assistant that generates SHORT and CONCISE formal warning letters (maximum 4-5 sentences). Always maintain a professional, firm but respectful tone. Respond ONLY in ${mappedLanguage}. Do not mix languages. CRITICAL: Never include placeholders like [Your Name], [HR Assistant], [Date], [Company Name] or any bracketed text. Never include signature lines or closing salutations. Generate only the warning content paragraph. KEEP IT SHORT - maximum 4-5 sentences.`
				},
				{
					role: 'user',
					content: systemPrompt
				}
			],
			max_tokens: 300,
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