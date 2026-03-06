-- Deploy AI Bot Training Manual Updates to Database
-- Urban Market Virtual Assistant - wa_ai_bot_config
-- Date: March 7, 2026

-- UPDATE training_qa with new Q&A pairs (JSON format)
UPDATE wa_ai_bot_config 
SET training_qa = '[
  {"prompt": "مرحبا", "response": "🤖 ايربن ماركت مساعد افتراضي 🇸🇦💚\n🌟 حياك الله وبياك في ايربن ماركت!\n🌟 Welcome to Urban Market! We are here to serve you with joy."},
  {"prompt": "Hello", "response": "🤖 Urban Market Virtual Assistant 🇸🇦💚\n🌟 Welcome! Delighted to serve you.\n🌟 حياك الله في ايربن ماركت!"},
  {"prompt": "السلام عليكم", "response": "🤖 وعليكم السلام ورحمة الله وبركاته 🤲\nايربن ماركت مساعد افتراضي 🇸🇦💚\n🌟 حياك الله وبياك! نتشرف بخدمتك."},
  {"prompt": "كم سعر المنتج", "response": "🛍️ شكرًا لاهتمامك! إن شاء الله سيساعدك أحد فريقنا على اختيار الأفضل لك. يرجى كتابة خدمة. سيتواصل معك الفريق خلال 12-24 ساعة. 🇸🇦💚"},
  {"prompt": "Do you have custom cakes?", "response": "🎂 Yes! Custom cakes are available at our Al-Arada branch. Bring your photo and we will print it on the cake! 🇸🇦💚"},
  {"prompt": "الكعكات المخصصة", "response": "🎂 تتوفر الكعكات المخصصة في فرع العارضة. أحضر صورتك ونطبعها على الكعكة! 🇸🇦💚"},
  {"prompt": "هل يوجد واي فاي", "response": "📶 واي فاي مجاني في كلا الفرعين. الرمز: U2025 🇸🇦💚"},
  {"prompt": "Is there Wi-Fi?", "response": "📶 Free Wi-Fi at both branches. Password: U2025 🇸🇦💚"},
  {"prompt": "أين فرعكم", "response": "🏪 أبو عريش و العارضة\n\n🏪 أبو عريش: منتجات حصرية\n🏪 العارضة: مخبز حي وكعكات مخصصة وسندويتشات جاهزة وزاوية بيتزا\n\nللمزيد: https://www.urbanksa.app/login/customer 🇸🇦💚"},
  {"prompt": "خدمة", "response": "🤖 بكل سرور! سيتواصل معك أحد موظفينا الكرام خلال 12-24 ساعة. شكرًا لاختيارك لنا. 🇸🇦💚"},
  {"prompt": "شكرا", "response": "💚 شكرًا لك على تواصلك معنا! حفظك الله ويسر أمرك. نتمنى أن نكون دائمًا في خدمتك. 🇸🇦\n🔗 زرنا قريبًا: https://www.urbanksa.app/login/customer"}
]'::jsonb,
updated_at = now()
WHERE id IS NOT NULL;

-- Verify updates
SELECT 
  id,
  jsonb_array_length(training_qa) as qa_count,
  updated_at
FROM wa_ai_bot_config;
