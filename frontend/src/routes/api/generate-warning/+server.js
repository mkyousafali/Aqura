import { json } from '@sveltejs/kit';
import OpenAI from 'openai';
import { env } from '$env/dynamic/private';

// Initialize OpenAI client
const openai = new OpenAI({
	apiKey: env.OPENAI_API_KEY || env.VITE_OPENAI_API_KEY || process.env.OPENAI_API_KEY || process.env.VITE_OPENAI_API_KEY
});

export async function POST({ request }) {
	try {
		console.log('API route accessed, checking environment...');
		
		// Check if OpenAI API key is available
		const apiKey = env.OPENAI_API_KEY || env.VITE_OPENAI_API_KEY || process.env.OPENAI_API_KEY || process.env.VITE_OPENAI_API_KEY;
		console.log('API key available:', !!apiKey);
		
		if (!apiKey) {
			console.error('No OpenAI API key found in environment variables');
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

		// Extract data from assignment with enhanced warning types
		const recipientName = assignment.assignedToEmployee || assignment.assignedTo || assignment.username || 'Employee';
		const assignedBy = assignment.assignedBy || 'Manager';
		const taskType = assignment.assignmentType || 'Task';
		const totalTasks = assignment.totalAssigned || 0;
		const completedTasks = assignment.totalCompleted || 0;
		const overdueTasks = assignment.totalOverdue || 0;
		const completionRate = totalTasks > 0 ? Math.round((completedTasks / totalTasks) * 100) : 0;
		const performanceStatus = completionRate >= 80 ? 'satisfactory' : completionRate >= 60 ? 'needs improvement' : 'poor';
		const branchName = assignment.branch || 'Not specified';
		const warningType = assignment.warningType || 'overall_performance_no_fine';
		const fineAmount = assignment.fineAmount;
		const fineCurrency = assignment.fineCurrency || 'USD';
		const taskId = assignment.taskId;
		const taskTitle = assignment.taskTitle;
		const taskDescription = assignment.taskDescription;

		console.log('Extracted warning type:', warningType);
		console.log('Extracted fine amount:', fineAmount);
		console.log('Extracted task details:', { taskId, taskTitle, taskDescription });
		console.log('Extracted recipient name:', recipientName);
		console.log('Extracted language:', language);

		// More lenient validation - only check for language since we provide defaults for other fields
		if (!language) {
			return json({ 
				error: 'Language is required' 
			}, { status: 400 });
		}

		// Log the final recipient name to debug
		console.log('Final recipient name for warning:', recipientName);

		// Parse warning type to get specific components
		const isTaskSpecific = false; // Removed task-specific warnings
		let fineType = 'no_fine';
		
		if (warningType.includes('with_fine')) {
			fineType = 'immediate_fine';
		} else if (warningType.includes('fine_threat')) {
			fineType = 'fine_threat';
		}

		console.log('Parsed warning type - fineType:', fineType);

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

		// Create comprehensive prompt system
		function createWarningPrompt(lang, warningType, taskDetails, fineInfo) {
			const { fineAmount, fineCurrency, fineType } = fineInfo;
			
			const basePrompts = {
				english: `Generate a professional performance warning notice for an employee with poor task completion performance.

Employee Details:
- Name: ${recipientName}
- Assigned By: ${assignedBy}
- Assignment Type: ${taskType}
- Branch: ${branchName}

Performance Statistics:
- Total Tasks Assigned: ${totalTasks}
- Tasks Completed: ${completedTasks}
- Overdue Tasks: ${overdueTasks}
- Completion Rate: ${completionRate}%
- Performance Status: ${performanceStatus}`,

				arabic: `أنشئ محتوى إشعار تحذير مهني لموظف لديه أداء ضعيف في إنجاز المهام.

تفاصيل الموظف:
- الاسم: ${recipientName}
- مكلف من قبل: ${assignedBy}
- نوع التكليف: ${taskType}
- الفرع: ${branchName}

إحصائيات الأداء:
- إجمالي المهام المكلفة: ${totalTasks}
- المهام المكتملة: ${completedTasks}
- المهام المتأخرة: ${overdueTasks}
- معدل الإنجاز: ${completionRate}%
- حالة الأداء: ${performanceStatus}`,

				urdu: `ایک ملازم کے لیے جو کاموں کی تکمیل میں کمزور کارکردگی رکھتا ہے، پیشہ ورانہ کارکردگی کی تنبیہی نوٹس تیار کریں۔

ملازم کی تفصیلات:
- نام: ${recipientName}
- تفویض کنندہ: ${assignedBy}
- تفویض کی قسم: ${taskType}
- شاخ: ${branchName}

کارکردگی کے اعداد و شمار:
- کل تفویض شدہ کام: ${totalTasks}
- مکمل شدہ کام: ${completedTasks}
- تاخیر شدہ کام: ${overdueTasks}
- تکمیل کی شرح: ${completionRate}%
- کارکردگی کی حالت: ${performanceStatus}`
			};

			return basePrompts[lang] || basePrompts.english;
		}

		// Prepare the system prompt based on language and warning type
		const basePrompt = createWarningPrompt(mappedLanguage, warningType, taskDetails, { fineAmount, fineCurrency, fineType });
		
		const commonRequirements = {
			english: `

${fineText[fineType]?.english || ''}

Please generate a formal, professional warning letter content that:
1. States the performance concerns clearly about the overall task completion performance
2. References the specific performance statistics provided above (Total: ${totalTasks}, Completed: ${completedTasks}, Overdue: ${overdueTasks}, Rate: ${completionRate}%)
3. Addresses the overall performance patterns
4. Explains the impact on productivity and team performance
5. Sets clear expectations for immediate improvement
6. Mentions potential consequences if performance doesn't improve promptly
7. Maintains a professional but firm tone
8. Requests a response with improvement plan and timeline
${fineType !== 'no_fine' ? '9. CRITICAL: MUST include the exact fine information provided above - mention the specific amount and currency prominently' : ''}

CRITICAL REQUIREMENTS - MUST FOLLOW:
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
1. ذكر مخاوف الأداء بوضوح حول أداء إنجاز المهام بشكل عام
2. الإشارة إلى إحصائيات الأداء المحددة (المجموع: ${totalTasks}، المكتمل: ${completedTasks}، المتأخر: ${overdueTasks}، المعدل: ${completionRate}%)
3. معالجة أنماط الأداء العامة
4. شرح التأثير على الإنتاجية وأداء الفريق
5. وضع توقعات واضحة للتحسن الفوري
6. ذكر العواقب المحتملة إذا لم يتحسن الأداء بسرعة
7. الحفاظ على نبرة مهنية لكن حازمة
8. طلب رد مع خطة التحسن والجدول الزمني
${fineType !== 'no_fine' ? '9. حاسم: يجب تضمين معلومات الغرامة المحددة أعلاه - ذكر المبلغ والعملة المحددة بوضوح' : ''}

متطلبات حاسمة - يجب اتباعها:
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
1. مجموعی کام کی تکمیل کی کارکردگی کے بارے میں واضح طور پر کارکردگی کے خدشات بیان کریں
2. اوپر فراہم کردہ مخصوص کارکردگی کے اعداد و شمار کا حوالہ دیں (کل: ${totalTasks}، مکمل: ${completedTasks}، تاخیر: ${overdueTasks}، شرح: ${completionRate}%)
3. مجموعی کارکردگی کے نمونوں سے نمٹیں
4. پیداوار اور ٹیم کی کارکردگی پر اثرات کی وضاحت کریں
5. فوری بہتری کے لیے واضح توقعات مقرر کریں
6. اگر کارکردگی فوری طور پر بہتر نہیں ہوتی تو ممکنہ نتائج کا ذکر کریں
7. پیشہ ورانہ لیکن سخت لہجہ برقرار رکھیں
8. بہتری کے منصوبے اور ٹائم لائن کے ساتھ جواب کی درخواست کریں
${fineType !== 'no_fine' ? '9. اہم: لازمی طور پر اوپر فراہم کردہ جرمانے کی معلومات - مخصوص رقم اور کرنسی کا واضح ذکر کریں' : ''}

اہم ضروریات - لازمی پیروی کریں:
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