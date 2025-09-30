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

		const { 
			assignment,
			language = 'en'
		} = await request.json();

		console.log('Received language:', language); // Debug log

		// Validate required data
		if (!assignment) {
			return json({ error: 'Assignment data is required' }, { status: 400 });
		}

		// Map language codes to language names
		const languageMap = {
			'en': 'english',
			'hi': 'hindi',
			'ar': 'arabic',
			'ur': 'urdu',
			'ta': 'tamil',
			'ml': 'malayalam',
			'bn': 'bengali'
		};

		const mappedLanguage = languageMap[language] || 'english';
		console.log('Mapped language:', mappedLanguage); // Debug log

		// Extract assignment details
		const recipientName = assignment.assignedToEmployee || assignment.assignedTo || 'Employee';
		const assignedBy = assignment.assignedBy || 'Manager';
		const taskType = assignment.assignmentType || 'Task';
		const branchName = assignment.branch || 'Not specified';
		const totalTasks = assignment.totalAssigned || 0;
		const completedTasks = assignment.totalCompleted || 0;
		const overdueTasks = assignment.totalOverdue || 0;
		const completionRate = totalTasks > 0 ? Math.round((completedTasks / totalTasks) * 100) : 0;
		
		// Calculate performance status
		const performanceStatus = completionRate >= 80 ? 'satisfactory' : completionRate >= 60 ? 'needs improvement' : 'poor';

		// Prepare the system prompt based on language
		const prompts = {
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
- Performance Status: ${performanceStatus}

Please generate a formal, professional warning letter content that:
1. States the performance concerns clearly about the poor task completion rate
2. References the specific performance statistics
3. Explains the impact on productivity and team performance
4. Sets clear expectations for immediate improvement
5. Mentions potential consequences if performance doesn't improve promptly
6. Maintains a professional but firm tone
7. Requests a response with improvement plan and timeline

CRITICAL REQUIREMENTS - MUST FOLLOW:
- Do NOT include any dates, sender names, recipient names, or company names
- Do NOT include ANY placeholders like [Your Name], [Your Title], [Company Name], [Date], [HR Assistant], etc.
- Do NOT include signature lines or closing salutations like "Sincerely, [Your Name]"
- Do NOT include any bracketed placeholders or template markers
- Start directly with the warning content paragraph
- End with the main content - no signatures or names
- The response should ONLY be the warning paragraph content`,

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
- حالة الأداء: ${performanceStatus}

يرجى إنشاء محتوى خطاب تحذير رسمي ومهني يتضمن:
1. ذكر مخاوف الأداء بوضوح حول ضعف معدل إنجاز المهام
2. الإشارة إلى إحصائيات الأداء المحددة
3. شرح التأثير على الإنتاجية وأداء الفريق
4. وضع توقعات واضحة للتحسن الفوري
5. ذكر العواقب المحتملة إذا لم يتحسن الأداء بسرعة
6. الحفاظ على نبرة مهنية لكن حازمة
7. طلب رد مع خطة التحسن والجدول الزمني

متطلبات حاسمة - يجب اتباعها:
- لا تضع أي تواريخ أو أسماء مرسلين أو أسماء مستقبلين أو أسماء شركات
- لا تضع أي متغيرات وهمية مثل [اسمك]، [منصبك]، [اسم الشركة]، [التاريخ]، [مساعد الموارد البشرية]، إلخ
- لا تضع خطوط توقيع أو تحيات ختامية مثل "مع التقدير، [اسمك]"
- لا تضع أي متغيرات بين أقواس أو علامات قوالب
- ابدأ مباشرة بفقرة محتوى التحذير
- انته بالمحتوى الرئيسي - بدون توقيعات أو أسماء
- يجب أن تكون الاستجابة فقط محتوى فقرة التحذير`,

			urdu: `ایک ملازم کے لیے پیشہ ورانہ کارکردگی کی انتباہی نوٹس کا مواد تیار کریں جس کی کام مکمل کرنے کی کارکردگی خراب ہے۔

ملازم کی تفصیلات:
- نام: ${recipientName}
- تفویض کنندہ: ${assignedBy}
- تفویض کی قسم: ${taskType}
- شاخ: ${branchName}

کارکردگی کے اعداد و شمار:
- کل تفویض شدہ کام: ${totalTasks}
- مکمل شدہ کام: ${completedTasks}
- تاخیر سے کام: ${overdueTasks}
- تکمیل کی شرح: ${completionRate}%
- کارکردگی کی حالت: ${performanceStatus}

براہ کرم ایک رسمی، پیشہ ورانہ انتباہی خط کا مواد بنائیں جو:
1. کام کی خراب تکمیل کی شرح کے بارے میں کارکردگی کے خدشات کو واضح طور پر بیان کرے
2. مخصوص کارکردگی کے اعداد و شمار کا حوالہ دے
3. پیداوار اور ٹیم کی کارکردگی پر اثرات کی وضاحت کرے
4. فوری بہتری کے لیے واضح توقعات مقرر کرے
5. اگر کارکردگی فوری طور پر بہتر نہیں ہوتی تو ممکنہ نتائج کا ذکر کرے
6. پیشہ ورانہ لیکن سخت لہجہ برقرار رکھے
7. بہتری کے منصوبے اور وقت کے ساتھ جواب کی درخواست کرے

اہم:
- مواد میں تاریخ، بھیجنے والے کا نام، وصول کنندہ کا نام، یا کمپنی کا نام شامل نہ کریں
- [آپ کا نام]، [آپ کا عہدہ]، [کمپنی کا نام]، [موجودہ تاریخ] جیسے نعم البدل استعمال نہ کریں
- انتباہ کے مواد سے براہ راست شروع کریں
- صرف خط کے مواد کی ضرورت ہے، مکمل خط کی شکل نہیں`,

			hindi: `एक कर्मचारी के लिए व्यावसायिक प्रदर्शन चेतावनी नोटिस की सामग्री तैयार करें जिसकी कार्य पूर्णता का प्रदर्शन खराब है।

कर्मचारी विवरण:
- नाम: ${recipientName}
- द्वारा सौंपा गया: ${assignedBy}
- असाइनमेंट प्रकार: ${taskType}
- शाखा: ${branchName}

प्रदर्शन आंकड़े:
- कुल सौंपे गए कार्य: ${totalTasks}
- पूर्ण किए गए कार्य: ${completedTasks}
- विलंबित कार्य: ${overdueTasks}
- पूर्णता दर: ${completionRate}%
- प्रदर्शन स्थिति: ${performanceStatus}

कृपया एक औपचारिक, व्यावसायिक चेतावनी पत्र की सामग्री तैयार करें जो:
1. कार्य की खराब पूर्णता दर के बारे में प्रदर्शन चिंताओं को स्पष्ट रूप से बताए
2. विशिष्ट प्रदर्शन आंकड़ों का संदर्भ दे
3. उत्पादकता और टीम प्रदर्शन पर प्रभाव की व्याख्या करे
4. तत्काल सुधार के लिए स्पष्ट अपेक्षाएं निर्धारित करे
5. यदि प्रदर्शन तुरंत नहीं सुधरता तो संभावित परिणामों का उल्लेख करे
6. व्यावसायिक लेकिन दृढ़ स्वर बनाए रखे
7. सुधार योजना और समयसीमा के साथ प्रतिक्रिया का अनुरोध करे

महत्वपूर्ण:
- सामग्री में दिनांक, भेजने वाले का नाम, प्राप्तकर्ता का नाम, या कंपनी का नाम शामिल न करें
- [आपका नाम], [आपका पद], [कंपनी का नाम], [वर्तमान दिनांक] जैसे प्लेसहोल्डर का उपयोग न करें
- चेतावनी की सामग्री से सीधे शुरुआत करें
- केवल पत्र की सामग्री की आवश्यकता है, पूर्ण पत्र प्रारूप की नहीं`,

			tamil: `ஒரு ஊழியருக்கான தொழில்முறை செயல்திறன் எச்சரிக்கை அறிவிப்பின் உள்ளடக்கத்தை உருவாக்கவும், அவர் பணி நிறைவேற்றத்தில் மோசமான செயல்திறனைக் கொண்டுள்ளார்.

ஊழியர் விவரங்கள்:
- பெயர்: ${recipientName}
- ஒதுக்கியவர்: ${assignedBy}
- ஒதுக்கீட்டு வகை: ${taskType}
- கிளை: ${branchName}

செயல்திறன் புள்ளிவிவரங்கள்:
- மொத்த ஒதுக்கப்பட்ட பணிகள்: ${totalTasks}
- நிறைவேற்றப்பட்ட பணிகள்: ${completedTasks}
- தாமதமான பணிகள்: ${overdueTasks}
- நிறைவேற்றல் விகிதம்: ${completionRate}%
- செயல்திறன் நிலை: ${performanceStatus}

தயவுசெய்து ஒரு முறையான, தொழில்முறை எச்சரிக்கை கடித உள்ளடக்கத்தை உருவாக்கவும்:
1. மோசமான பணி நிறைவேற்றல் விகிதம் குறித்த செயல்திறன் கவலைகளை தெளிவாக கூறவும்
2. குறிப்பிட்ட செயல்திறன் புள்ளிவிவரங்களை குறிப்பிடவும்
3. உற்பாதகத்தில் மற்றும் குழு செயல்திறனில் தாக்கத்தை விளக்கவும்
4. உடனடி முன்னேற்றத்திற்கான தெளிவான எதிர்பார்ப்புகளை அமைக்கவும்
5. செயல்திறன் உடனடியாக மேம்படாவிட்டால் சாத்தியமான விளைவுகளை குறிப்பிடவும்
6. தொழில்முறை ஆனால் உறுதியான தொனியை பராமரிக்கவும்
7. முன்னேற்ற திட்டம் மற்றும் கால அட்டவணையுடன் பதிலை கோரவும்

முக்கியமான தேவைகள் - கண்டிப்பாக பின்பற்ற வேண்டும்:
- எந்த தேதிகள், அனுப்புநர் பெயர்கள், பெறுநர் பெயர்கள் அல்லது நிறுவன பெயர்களை சேர்க்க வேண்டாம்
- [உங்கள் பெயர்], [உங்கள் பதவி], [நிறுவன பெயர்], [தேதி], [HR உதவியாளர்] போன்ற இடங்காட்டிகளை சேர்க்க வேண்டாம்
- கையொப்ப வரிகள் அல்லது நிறைவு வாழ்த்துகளை சேர்க்க வேண்டாம்
- எந்த அடைப்பு குறி இடங்காட்டிகளையும் சேர்க்க வேண்டாம்
- எச்சரிக்கை உள்ளடக்க பத்தியுடன் நேரடியாக தொடங்கவும்
- முக்கிய உள்ளடக்கத்துடன் முடிக்கவும் - கையொப்பங்கள் அல்லது பெயர்கள் இல்லாமல்
- பதில் எச்சரிக்கை பத்தி உள்ளடக்கம் மட்டுமே இருக்க வேண்டும்`,

			malayalam: `ജോലി പൂർത്തീകരണത്തിൽ മോശം പ്രകടനമുള്ള ഒരു ജീവനക്കാരനുവേണ്ടി പ്രൊഫഷണൽ പ്രകടന മുന്നറിയിപ്പ് നോട്ടീസിന്റെ ഉള്ളടക്കം സൃഷ്ടിക്കുക.

ജീവനക്കാരന്റെ വിശദാംശങ്ങൾ:
- പേര്: ${recipientName}
- നിയോഗിച്ചത്: ${assignedBy}
- നിയോഗ തരം: ${taskType}
- ശാഖ: ${branchName}

പ്രകടന സ്ഥിതിവിവരക്കണക്കുകൾ:
- മൊത്തം നിയോഗിച്ച ജോലികൾ: ${totalTasks}
- പൂർത്തീകരിച്ച ജോലികൾ: ${completedTasks}
- കാലഹരണപ്പെട്ട ജോലികൾ: ${overdueTasks}
- പൂർത്തീകരണ നിരക്ക്: ${completionRate}%
- പ്രകടന നില: ${performanceStatus}

ദയവായി ഒരു ഔപചാരികവും പ്രൊഫഷണലുമായ മുന്നറിയിപ്പ് കത്തിന്റെ ഉള്ളടക്കം സൃഷ്ടിക്കുക:
1. മോശം ജോലി പൂർത്തീകരണ നിരക്കിനെക്കുറിച്ചുള്ള പ്രകടന ആശങ്കകൾ വ്യക്തമായി പ്രസ്താവിക്കുക
2. നിർദ്ദിഷ്ട പ്രകടന സ്ഥിതിവിവരക്കണക്കുകൾ പരാമർശിക്കുക
3. ഉൽപ്പാദനക്ഷമതയിലും ടീം പ്രകടനത്തിലുമുള്ള സ്വാധീനം വിശദീകരിക്കുക
4. ഉടനടി പുരോഗതിക്കായി വ്യക്തമായ പ്രതീക്ഷകൾ സ്ഥാപിക്കുക
5. പ്രകടനം പെട്ടെന്ന് മെച്ചപ്പെടുന്നില്ലെങ്കിൽ സാധ്യമായ അനന്തരഫലങ്ങൾ പരാമർശിക്കുക
6. പ്രൊഫഷണൽ എന്നാൽ ഉറച്ച ടോൺ നിലനിർത്തുക
7. പുരോഗതി പദ്ധതിയും സമയക്രമവുമായി പ്രതികരണം അഭ്യർത്ഥിക്കുക

നിർണ്ണായക ആവശ്യകതകൾ - പാലിക്കേണ്ടത്:
- ഏതെങ്കിലും തീയതികൾ, അയയ്ക്കുന്ന വ്യക്തിയുടെ പേരുകൾ, സ്വീകർത്താവിന്റെ പേരുകൾ അല്ലെങ്കിൽ കമ്പനി പേരുകൾ ഉൾപ്പെടുത്തരുത്
- [നിങ്ങളുടെ പേര്], [നിങ്ങളുടെ പദവി], [കമ്പനി പേര്], [തീയതി], [HR അസിസ്റ്റന്റ്] തുടങ്ങിയ പ്ലേസ്‌ഹോൾഡറുകൾ ഉൾപ്പെടുത്തരുത്
- ഒപ്പ് വരികളോ അവസാന അഭിവാദനങ്ങളോ ഉൾപ്പെടുത്തരുത്
- ഏതെങ്കിലും ബ്രാക്കറ്റ് പ്ലേസ്‌ഹോൾഡറുകൾ ഉൾപ്പെടുത്തരുത്
- മുന്നറിയിപ്പ് ഉള്ളടക്ക ഖണ്ഡികയിൽ നിന്ന് നേരിട്ട് ആരംഭിക്കുക
- പ്രധാന ഉള്ളടക്കത്തോടെ അവസാനിപ്പിക്കുക - ഒപ്പുകളോ പേരുകളോ ഇല്ലാതെ
- പ്രതികരണം മുന്നറിയിപ്പ് ഖണ്ഡിക ഉള്ളടക്കം മാത്രമായിരിക്കണം`,

			bengali: `একজন কর্মচারীর জন্য পেশাদার কর্মক্ষমতা সতর্কতা নোটিশের বিষয়বস্তু তৈরি করুন যার কাজ সম্পূর্ণ করার কর্মক্ষমতা দুর্বল।

কর্মচারীর বিবরণ:
- নাম: ${recipientName}
- নিয়োগদাতা: ${assignedBy}
- নিয়োগের ধরন: ${taskType}
- শাখা: ${branchName}

কর্মক্ষমতার পরিসংখ্যান:
- মোট নির্ধারিত কাজ: ${totalTasks}
- সম্পূর্ণ করা কাজ: ${completedTasks}
- বিলম্বিত কাজ: ${overdueTasks}
- সমাপ্তির হার: ${completionRate}%
- কর্মক্ষমতার অবস্থা: ${performanceStatus}

অনুগ্রহ করে একটি আনুষ্ঠানিক, পেশাদার সতর্কতা চিঠির বিষয়বস্তু তৈরি করুন যা:
1. দুর্বল কাজ সম্পূর্ণ করার হার সম্পর্কে কর্মক্ষমতার উদ্বেগগুলি স্পষ্টভাবে বর্ণনা করে
2. নির্দিষ্ট কর্মক্ষমতার পরিসংখ্যান উল্লেখ করে
3. উৎপাদনশীলতা এবং দলের কর্মক্ষমতায় প্রভাব ব্যাখ্যা করে
4. তাৎক্ষণিক উন্নতির জন্য স্পষ্ট প্রত্যাশা নির্ধারণ করে
5. কর্মক্ষমতা অবিলম্বে উন্নত না হলে সম্ভাব্য পরিণতির উল্লেখ করে
6. পেশাদার কিন্তু দৃঢ় স্বর বজায় রাখে
7. উন্নতি পরিকল্পনা এবং সময়সূচী সহ প্রতিক্রিয়ার জন্য অনুরোধ করে

গুরুত্বপূর্ণ প্রয়োজনীয়তা - অবশ্যই অনুসরণ করতে হবে:
- কোনো তারিখ, প্রেরকের নাম, প্রাপকের নাম বা কোম্পানির নাম অন্তর্ভুক্ত করবেন না
- [আপনার নাম], [আপনার পদবি], [কোম্পানির নাম], [তারিখ], [HR সহায়ক] এর মতো কোনো স্থানধারক অন্তর্ভুক্ত করবেন না
- স্বাক্ষরের লাইন বা সমাপনী শুভেচ্ছা অন্তর্ভুক্ত করবেন না
- কোনো বন্ধনী স্থানধারক অন্তর্ভুক্ত করবেন না
- সতর্কতা বিষয়বস্তুর অনুচ্ছেদ দিয়ে সরাসরি শুরু করুন
- মূল বিষয়বস্তু দিয়ে শেষ করুন - কোনো স্বাক্ষর বা নাম ছাড়া
- প্রতিক্রিয়া শুধুমাত্র সতর্কতা অনুচ্ছেদের বিষয়বস্তু হওয়া উচিত`
		};

		const systemPrompt = prompts[mappedLanguage] || prompts.english;
		console.log('Using prompt for language:', mappedLanguage); // Debug log
		console.log('Prompt preview:', systemPrompt.substring(0, 200) + '...'); // Debug log

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
			success: true 
		});

	} catch (error) {
		console.error('OpenAI API error:', error);
		
		// Handle specific OpenAI errors
		if (error.code === 'insufficient_quota') {
			return json({ 
				error: 'OpenAI API quota exceeded. Please check your billing settings.' 
			}, { status: 429 });
		}
		
		if (error.code === 'invalid_api_key') {
			return json({ 
				error: 'Invalid OpenAI API key configuration.' 
			}, { status: 401 });
		}

		// Generic error response
		return json({ 
			error: 'Failed to generate warning. Please try again.' 
		}, { status: 500 });
	}
}