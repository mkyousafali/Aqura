-- Store hours for Abu Arish and Al Aridah. Preserve service enablement and human support hours.
BEGIN;
UPDATE public.branches SET is_24_hours = false,
  operating_start_time = '06:00:00',
  operating_end_time = '02:00:00',
  delivery_is_24_hours = false,
  delivery_start_time = '06:00:00',
  delivery_end_time = '02:00:00',
  pickup_is_24_hours = false,
  pickup_start_time = '06:00:00',
  pickup_end_time = '02:00:00',
  delivery_message_en = 'Delivery is currently unavailable',
  delivery_message_ar = 'خدمة التوصيل غير متاحة حالياً' WHERE id = 1;

UPDATE public.branches SET is_24_hours = false,
  operating_start_time = '06:00:00',
  operating_end_time = '02:00:00',
  delivery_is_24_hours = false,
  delivery_start_time = '06:00:00',
  delivery_end_time = '02:00:00',
  pickup_is_24_hours = false,
  pickup_start_time = '06:00:00',
  pickup_end_time = '02:00:00',
  delivery_message_en = 'Delivery is currently unavailable',
  delivery_message_ar = 'خدمة التوصيل غير متاحة حالياً' WHERE id = 3;

UPDATE public.wa_ai_bot_config SET custom_instructions = '# Business Information | معلومات النشاط التجاري

## Business Identity | هوية النشاط
**Official English Name:** Urban Market
**Official Arabic Name:** ايربن ماركت

When communicating in Arabic, always use **ايربن ماركت** exactly. Do not translate the business name or use alternative Arabic spellings.

## Branches | الفروع
Urban Market | ايربن ماركت operates two branches. Use these spellings exactly and never invent variants:

### Abu Arish | أبو عريش
**Official English Name:** Abu Arish
**Official Arabic Name:** أبو عريش

### Al Aridah | العارضة
**Official English Name:** Al Aridah
**Official Arabic Name:** العارضة

What each branch offers is listed under Services. Do not restate it here.

## Loyalty Program | برنامج الولاء
Urban Market | ايربن ماركت provides a customer loyalty program.

Customers can use the loyalty app to register, check their points, and view the latest offers.
Never paste the app address in your reply — tag the reply with the matching link and the system shows it as a button.

## Offers | العروض
The latest available offers can be viewed through the Urban Market | ايربن ماركت loyalty app.

Offers may change according to their validity period and availability.

## Products & Prices | المنتجات والأسعار
Product selection, availability, and prices may vary by branch and may change over time.

The AI must not invent, estimate, or assume current prices or stock availability when verified information is unavailable. When a customer asks about specific product prices or stock, follow Problem & Issue Handling.

## Store Opening Hours | ساعات عمل الفروع
- Abu Arish | أبو عريش: 6:00 AM to 2:00 AM the following day daily, Saudi Arabia time (Asia/Riyadh).
- Al Aridah | العارضة: 6:00 AM to 2:00 AM the following day daily, Saudi Arabia time (Asia/Riyadh).
- يعمل فرعا أبو عريش والعارضة يومياً من الساعة 6 صباحاً إلى 2 صباحاً من اليوم التالي بتوقيت السعودية.
- This replaces the former 24-hour store schedule. Neither branch is open 24 hours.
- These are store hours. Human support remains 12:00 PM to 8:00 PM daily; automated chat may answer outside store hours. Delivery and pickup ordering are currently unavailable.
- Use these current store hours even if an older conversation or message mentions another schedule. Do not claim the store is open now without a verified current Saudi time.
' WHERE id = '00000000-0000-0000-0000-000000000001';

UPDATE public.wa_settings SET business_hours = '{"sunday":{"open":true,"start":"06:00","end":"02:00","allDay":false},"monday":{"open":true,"start":"06:00","end":"02:00","allDay":false},"tuesday":{"open":true,"start":"06:00","end":"02:00","allDay":false},"wednesday":{"open":true,"start":"06:00","end":"02:00","allDay":false},"thursday":{"open":true,"start":"06:00","end":"02:00","allDay":false},"friday":{"open":true,"start":"06:00","end":"02:00","allDay":false},"saturday":{"open":true,"start":"06:00","end":"02:00","allDay":false}}',
  outside_hours_message = 'Our Abu Arish and Al Aridah stores open daily from 6:00 AM to 2:00 AM the following day Saudi time. Automated chat remains available. Human support: 12:00 PM to 8:00 PM Saudi time.' WHERE id = 'dc4da415-957c-43b9-a00e-bcd9c2ef383d';

UPDATE public.delivery_service_settings SET is_24_hours = false,
  operating_start_time = '06:00:00',
  operating_end_time = '02:00:00',
  display_message_en = 'Delivery availability depends on the selected branch',
  display_message_ar = 'توفر التوصيل حسب الفرع المحدد' WHERE id = '00000000-0000-0000-0000-000000000001';
-- Meta already archived this template; sync the stale local approval status.
UPDATE public.wa_templates SET status = 'ARCHIVED' WHERE id = '5e013c06-9d26-4f69-9cb4-d9eef4a21777' AND meta_template_id = '1405655500618915';
COMMIT;
