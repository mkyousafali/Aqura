-- Arabic translations for 67 product categories

SELECT 'Translations for product categories migration:' as info;

-- Format: ID | English Name | Arabic Name
/*
1   | Baking                      | الخبز والمعجنات
2   | Bath Soap                   | صابون الاستحمام
3   | Biscuits                    | البسكويت
4   | Body Care                   | العناية بالجسم
5   | Body Wash                   | غسول الجسم
6   | Breakfast Cereals           | حبوب الإفطار
7   | Cake Mixes                  | خلطات الكيك
8   | Canned Food                 | الأطعمة المعلبة
9   | Canned Seafood              | المأكولات البحرية المعلبة
10  | Cheese                      | الجبن
11  | Chips                       | رقائق البطاطس
12  | Coffee                      | القهوة
13  | Coffee Mixes                | خلطات القهوة
14  | Concentrated Drinks         | المشروبات المركزة
15  | Condiments                  | التوابل والصلصات
16  | Cooking Fats                | الدهون الطبخ
17  | Cooking Oil                 | زيت الطبخ
18  | Creams                      | الكريمات
19  | Deodorants & Fragrances     | مزيلات العرق والعطور
20  | Dessert Mix                 | خلطات الحلويات
21  | Dishwashing                 | غسيل الصحون
22  | Disinfectants               | المطهرات
23  | Disposable                  | المنتجات التي تستخدم لمرة واحدة
24  | Drain Care                  | العناية بالصرف الصحي
25  | Dry Fruits                  | الفواكه المجففة
26  | Fabric Care                 | العناية بالأقمشة
27  | Fabric Softener             | منعم الأقمشة
28  | Fast Food                   | الوجبات السريعة
29  | Feminine Hygiene            | النظافة النسائية
30  | Flavored Milk               | الحليب المنكه
31  | Floor Care                  | العناية بالأرضيات
32  | Flour                       | الدقيق
33  | Food Packaging              | تغليف الأطعمة
34  | Frozen Foods                | الأطعمة المجمدة
35  | Fruit Jams                  | مربى الفواكه
36  | Grains                      | الحبوب
37  | Hair Care                   | العناية بالشعر
38  | Hand Wash                   | غسول اليدين
39  | Honey                       | العسل
40  | Instant Noodles             | الشعيرية الفورية
41  | Juice                       | العصائر
42  | Kitchen Appliances          | أدوات المطبخ
43  | Laundry Additives           | إضافات الغسيل
44  | Laundry Detergents          | مساحيق الغسيل
45  | Milk                        | الحليب
46  | Milk Powder                 | حليب البودرة
47  | Nut Butters                 | زبدة المكسرات
48  | Oils                        | الزيوت
49  | Outdoor/BBQ                 | منتجات الشواء
50  | Packaged Cakes              | الكيك المعبأ
51  | Paper Products              | المنتجات الورقية
52  | Pasta                       | المعكرونة
53  | Pest Control                | مكافحة الحشرات
54  | Poultry                     | الدواجن
55  | Powdered Drinks             | المشروبات البودرة
56  | Rice                        | الأرز
57  | Skincare                    | العناية بالبشرة
58  | Spices & Seasonings         | البهارات والتوابل
59  | Spreads                     | الدهون القابلة للدهن
60  | Stocks & Bouillon           | المرق والمكعبات
61  | Sugar                       | السكر
62  | Sugar Alternatives          | بدائل السكر
63  | Surface Cleaners            | منظفات الأسطح
64  | Tea                         | الشاي
65  | Tea Mixes                   | خلطات الشاي
66  | Wafers                      | الويفر
67  | Water                       | المياه
*/

-- Full INSERT statements ready for migration:

INSERT INTO product_categories (id, name_en, name_ar, display_order, is_active) VALUES 
(1, 'Baking', 'الخبز والمعجنات', 1, true),
(2, 'Bath Soap', 'صابون الاستحمام', 2, true),
(3, 'Biscuits', 'البسكويت', 3, true),
(4, 'Body Care', 'العناية بالجسم', 4, true),
(5, 'Body Wash', 'غسول الجسم', 5, true),
(6, 'Breakfast Cereals', 'حبوب الإفطار', 6, true),
(7, 'Cake Mixes', 'خلطات الكيك', 7, true),
(8, 'Canned Food', 'الأطعمة المعلبة', 8, true),
(9, 'Canned Seafood', 'المأكولات البحرية المعلبة', 9, true),
(10, 'Cheese', 'الجبن', 10, true),
(11, 'Chips', 'رقائق البطاطس', 11, true),
(12, 'Coffee', 'القهوة', 12, true),
(13, 'Coffee Mixes', 'خلطات القهوة', 13, true),
(14, 'Concentrated Drinks', 'المشروبات المركزة', 14, true),
(15, 'Condiments', 'التوابل والصلصات', 15, true),
(16, 'Cooking Fats', 'الدهون الطبخ', 16, true),
(17, 'Cooking Oil', 'زيت الطبخ', 17, true),
(18, 'Creams', 'الكريمات', 18, true),
(19, 'Deodorants & Fragrances', 'مزيلات العرق والعطور', 19, true),
(20, 'Dessert Mix', 'خلطات الحلويات', 20, true),
(21, 'Dishwashing', 'غسيل الصحون', 21, true),
(22, 'Disinfectants', 'المطهرات', 22, true),
(23, 'Disposable', 'المنتجات التي تستخدم لمرة واحدة', 23, true),
(24, 'Drain Care', 'العناية بالصرف الصحي', 24, true),
(25, 'Dry Fruits', 'الفواكه المجففة', 25, true),
(26, 'Fabric Care', 'العناية بالأقمشة', 26, true),
(27, 'Fabric Softener', 'منعم الأقمشة', 27, true),
(28, 'Fast Food', 'الوجبات السريعة', 28, true),
(29, 'Feminine Hygiene', 'النظافة النسائية', 29, true),
(30, 'Flavored Milk', 'الحليب المنكه', 30, true),
(31, 'Floor Care', 'العناية بالأرضيات', 31, true),
(32, 'Flour', 'الدقيق', 32, true),
(33, 'Food Packaging', 'تغليف الأطعمة', 33, true),
(34, 'Frozen Foods', 'الأطعمة المجمدة', 34, true),
(35, 'Fruit Jams', 'مربى الفواكه', 35, true),
(36, 'Grains', 'الحبوب', 36, true),
(37, 'Hair Care', 'العناية بالشعر', 37, true),
(38, 'Hand Wash', 'غسول اليدين', 38, true),
(39, 'Honey', 'العسل', 39, true),
(40, 'Instant Noodles', 'الشعيرية الفورية', 40, true),
(41, 'Juice', 'العصائر', 41, true),
(42, 'Kitchen Appliances', 'أدوات المطبخ', 42, true),
(43, 'Laundry Additives', 'إضافات الغسيل', 43, true),
(44, 'Laundry Detergents', 'مساحيق الغسيل', 44, true),
(45, 'Milk', 'الحليب', 45, true),
(46, 'Milk Powder', 'حليب البودرة', 46, true),
(47, 'Nut Butters', 'زبدة المكسرات', 47, true),
(48, 'Oils', 'الزيوت', 48, true),
(49, 'Outdoor/BBQ', 'منتجات الشواء', 49, true),
(50, 'Packaged Cakes', 'الكيك المعبأ', 50, true),
(51, 'Paper Products', 'المنتجات الورقية', 51, true),
(52, 'Pasta', 'المعكرونة', 52, true),
(53, 'Pest Control', 'مكافحة الحشرات', 53, true),
(54, 'Poultry', 'الدواجن', 54, true),
(55, 'Powdered Drinks', 'المشروبات البودرة', 55, true),
(56, 'Rice', 'الأرز', 56, true),
(57, 'Skincare', 'العناية بالبشرة', 57, true),
(58, 'Spices & Seasonings', 'البهارات والتوابل', 58, true),
(59, 'Spreads', 'الدهون القابلة للدهن', 59, true),
(60, 'Stocks & Bouillon', 'المرق والمكعبات', 60, true),
(61, 'Sugar', 'السكر', 61, true),
(62, 'Sugar Alternatives', 'بدائل السكر', 62, true),
(63, 'Surface Cleaners', 'منظفات الأسطح', 63, true),
(64, 'Tea', 'الشاي', 64, true),
(65, 'Tea Mixes', 'خلطات الشاي', 65, true),
(66, 'Wafers', 'الويفر', 66, true),
(67, 'Water', 'المياه', 67, true);
