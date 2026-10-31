begin;
set local lock_timeout='8s';
lock table public."Polosys_product_groups" in exclusive mode;
create temporary table requested_polosys_groups (
  ordinal integer primary key, name text unique not null, name_ar text not null
) on commit drop;
insert into requested_polosys_groups values
  (1,'Ice Cream','آيس كريم'),
  (2,'Eggs','بيض'),
  (3,'Beverages','مشروبات'),
  (4,'Urban Bakery','مخبوزات إيربن'),
  (5,'Sweets & Chocolate','حلويات وشوكولاتة'),
  (6,'Cat Food','طعام القطط'),
  (7,'Fresh Meat','لحوم طازجة'),
  (8,'Cheese','أجبان'),
  (9,'Electronics','إلكترونيات'),
  (10,'Other Bakery','مخبوزات معبأة'),
  (11,'Personal Care','عناية شخصية'),
  (12,'Fresh Chicken','دجاج طازج'),
  (13,'Fresh Dairy','ألبان طازجة'),
  (14,'Dry Grocery / Pantry','بقالة'),
  (15,'Water','مياه'),
  (16,'Frozen Food','مجمدات'),
  (17,'Baby Products','مستلزمات أطفال'),
  (18,'Snacks','وجبات خفيفة'),
  (19,'Toys','ألعاب'),
  (20,'Coffee Counter','ركن القهوة'),
  (21,'Dates','تمور'),
  (22,'Temporary Group','مجموعة مؤقتة'),
  (23,'Fruits & Vegetables','خضار وفواكه'),
  (24,'Household Cleaning','منظفات منزلية'),
  (25,'Stationery & School Supplies','قرطاسية ومستلزمات مدرسية'),
  (26,'Mobile Accessories','إكسسوارات الجوالات');
do $$
begin
  if exists(select 1 from public."Polosys_product_groups" g where not exists(select 1 from requested_polosys_groups r where r.name=g.name)) then
    raise exception 'Unexpected existing group names; seed cancelled for review';
  end if;
end; $$;
insert into public."Polosys_product_groups" (name,name_ar)
  select name,name_ar from requested_polosys_groups order by ordinal
  on conflict(name) do update set name_ar=excluded.name_ar;
do $$
begin
  if (select count(*) from public."Polosys_product_groups")<>26 or exists(
    select 1 from requested_polosys_groups r left join public."Polosys_product_groups" g
      on g.name=r.name and g.name_ar=r.name_ar where g.id is null
  ) then raise exception 'Product group verification failed'; end if;
end; $$;
commit;
