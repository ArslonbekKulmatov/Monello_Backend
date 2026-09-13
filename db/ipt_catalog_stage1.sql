-- =============================================================================
-- IPT KATALOG API — 1-BOSQICH
--
-- Maqsad : ABM Store saytiga katalog berish uchun minimal maydonlar to'plami.
--          Talablar hujjati: "ABM Store — katalog API talablari", v1.0, 27.08.2026
--          1-bosqich maydonlari: id, model_code, model_name, category,
--          condition, price, quantity.
--
-- Muallif: Arslonbek Kulmatov
-- Sana   : 13.09.2026
--
-- MUHIM  : Barcha summalar tizim bo'yicha TIYINDA saqlanadi (x100).
--          View'larda /100 qilib beriladi — ipt_trades_v va boshqalar kabi.
--
-- Bo'limlar KETMA-KET bajariladi (1 -> 5), tartibni o'zgartirib bo'lmaydi:
-- ma'lumotnomalar FK uchun oldin yaratilishi kerak.
-- CREATE/ALTER qismlari bir marta bajariladi; ma'lumotnoma qiymatlari (3-bo'lim)
-- MERGE orqali, qayta ishga tushirilsa ham xavfsiz.
-- =============================================================================


-- =============================================================================
-- 1. MA'LUMOTNOMALAR
-- =============================================================================

prompt 1.1 IPT_S_CATEGORIES

create table IPT_S_CATEGORIES
(
  code      VARCHAR2(30) not null,
  name_ru   VARCHAR2(500) not null,
  name_uz   VARCHAR2(500),
  ord       NUMBER(5) default 100 not null,
  condition VARCHAR2(2) default 'A' not null
)
;
comment on table IPT_S_CATEGORIES
  is 'Sayt katalogi kategoriyalari. Kodlar sayt jamoasining ma''lumotnomasidan olingan (talablar hujjati 7.1) — moslashtirish qatlami qurilmasligi uchun asosiy sifatida shu yerda yuritiladi';
comment on column IPT_S_CATEGORIES.code
  is 'Kategoriya kodi, API''ga shu ko''rinishda chiqadi: iphone, acc-cases, iphone-bu';
comment on column IPT_S_CATEGORIES.ord
  is 'Ro''yxatda ko''rsatish tartibi';
comment on column IPT_S_CATEGORIES.condition
  is 'A - active; P - passive';

alter table IPT_S_CATEGORIES
  add constraint IPT_S_CATEGORIES_PK primary key (CODE);
alter table IPT_S_CATEGORIES
  add constraint IPT_S_CATEGORIES_COND_CHK
  check (condition in ('A', 'P'));


prompt 1.2 IPT_S_BRANDS

create table IPT_S_BRANDS
(
  code      VARCHAR2(30) not null,
  name      VARCHAR2(500) not null,
  condition VARCHAR2(2) default 'A' not null
)
;
comment on table IPT_S_BRANDS
  is 'Brendlar ma''lumotnomasi. Kod lotin harflarida, API''ga shu ko''rinishda chiqadi';

alter table IPT_S_BRANDS
  add constraint IPT_S_BRANDS_PK primary key (CODE);
alter table IPT_S_BRANDS
  add constraint IPT_S_BRANDS_COND_CHK
  check (condition in ('A', 'P'));


-- =============================================================================
-- 2. MAVJUD JADVALLARGA USTUNLAR
-- =============================================================================

prompt 2.1 IPT_PRODUCTS — katalog ustunlari

alter table IPT_PRODUCTS add
(
  retail_price_uzs NUMBER(22),
  model_code       VARCHAR2(200),
  model_name       VARCHAR2(1000),
  category_code    VARCHAR2(30),
  brand_code       VARCHAR2(30),
  item_condition   VARCHAR2(10),
  phys_filial_code VARCHAR2(10)
);

comment on column IPT_PRODUCTS.retail_price_uzs
  is 'Saytdagi chakana narx, SOMDA, TIYINDA saqlanadi (19 500 000 som -> 1950000000). price ustuni bilan aralashtirmaslik kerak: u xarid narxi, dollarda';
comment on column IPT_PRODUCTS.model_code
  is 'Model kodi — bir model pozitsiyalarini saytda bitta kartochkaga yig''adi: iphone-16-pro-max. Lotin harflari, kichik registr, ajratuvchi "-"';
comment on column IPT_PRODUCTS.model_name
  is 'Saytga chiqadigan TOZA nom: "iPhone 17 Pro Max". name ustunidan farqli — unda konfiguratsiya, IMEI va xizmat izohlari aralash yotadi va u API''ga CHIQMAYDI';
comment on column IPT_PRODUCTS.category_code
  is 'ipt_s_categories.code';
comment on column IPT_PRODUCTS.brand_code
  is 'ipt_s_brands.code';
comment on column IPT_PRODUCTS.item_condition
  is 'Tovar holati saytda: new / used. "condition" nomi band bo''lgani uchun (butun tizimda u A/P ma''nosida ishlatiladi) shu nom tanlandi';
comment on column IPT_PRODUCTS.phys_filial_code
  is 'Tovar JISMONAN turgan filial — undan olib ketish mumkin. filial_code esa hisobdagi bog''lanish. "Mirobodda" holati: ikkalasi farq qiladi. Bo''sh bo''lsa filial_code olinadi';

alter table IPT_PRODUCTS
  add constraint IPT_PRODUCTS_ITEM_COND_CHK
  check (item_condition in ('new', 'used'));
alter table IPT_PRODUCTS
  add constraint IPT_PRODUCTS_CATEGORY_FK foreign key (CATEGORY_CODE)
  references IPT_S_CATEGORIES (CODE);
alter table IPT_PRODUCTS
  add constraint IPT_PRODUCTS_BRAND_FK foreign key (BRAND_CODE)
  references IPT_S_BRANDS (CODE);
alter table IPT_PRODUCTS
  add constraint IPT_PRODUCTS_PHYS_FILIAL_FK foreign key (PHYS_FILIAL_CODE)
  references IPT_S_FILIALS (CODE);

create index IPT_PRODUCTS_MODEL_CODE_IDX on IPT_PRODUCTS (MODEL_CODE);
create index IPT_PRODUCTS_CATALOG_IDX on IPT_PRODUCTS (STATE, CATEGORY_CODE);


prompt 2.2 IPT_PRODUCTS_HIS — tarix jadvali ham bir xil bo'lishi kerak

-- ipt_products_his ipt_products ning ko'zgusi. Yangi ustunlar bu yerga
-- qo'shilmasa, narx va model_code o'zgarishlari tarixda qolmaydi —
-- keyinchalik old_price (chizib tashlangan narx) shu tarixdan olinadi.
alter table IPT_PRODUCTS_HIS add
(
  retail_price_uzs NUMBER(22),
  model_code       VARCHAR2(200),
  model_name       VARCHAR2(1000),
  category_code    VARCHAR2(30),
  brand_code       VARCHAR2(30),
  item_condition   VARCHAR2(10),
  phys_filial_code VARCHAR2(10)
);

-- Tarix jadvaliga FK va CHECK QO'YILMAYDI: u eski holatlarni saqlaydi,
-- ma'lumotnoma esa vaqt o'tishi bilan o'zgaradi.


prompt 2.3 IPT_S_FILIALS — shourum kodi

alter table IPT_S_FILIALS add
(
  site_code VARCHAR2(30)
);

comment on column IPT_S_FILIALS.site_code
  is 'Saytdagi shourum kodi: mirobod, sebzor. Bo''sh bo''lsa — bu filial vitrina emas va uning tovarlari saytga chiqmaydi';


-- =============================================================================
-- 3. MA'LUMOTNOMA QIYMATLARI
--
-- Qayta ishga tushirilsa ham xavfsiz. Sayt jamoasi ro'yxatni kengaytirsa,
-- shu bo'limga qator qo'shib qayta bajariladi.
-- =============================================================================

prompt 3.1 Kategoriyalar

merge into ipt_s_categories t
using (
  select 'iphone'        code, 'iPhone'                    name_ru, 'iPhone'                     name_uz,  10 ord from dual union all
  select 'ipad',               'iPad',                     'iPad',                                20      from dual union all
  select 'mac',                'Mac',                      'Mac',                                 30      from dual union all
  select 'apple-watch',        'Apple Watch',              'Apple Watch',                         40      from dual union all
  select 'airpods',            'AirPods',                  'AirPods',                             50      from dual union all
  select 'samsung',            'Samsung',                  'Samsung',                             60      from dual union all
  select 'dyson',              'Dyson',                    'Dyson',                               70      from dual union all
  -- ishlatilgan texnika
  select 'used',               'Б/у техника',              'Ishlatilgan texnika',                100      from dual union all
  select 'iphone-bu',          'iPhone б/у',               'iPhone, ishlatilgan',                110      from dual union all
  select 'ipad-bu',            'iPad б/у',                 'iPad, ishlatilgan',                  120      from dual union all
  select 'mac-bu',             'Mac б/у',                  'Mac, ishlatilgan',                   130      from dual union all
  select 'apple-watch-bu',     'Apple Watch б/у',          'Apple Watch, ishlatilgan',           140      from dual union all
  select 'airpods-bu',         'AirPods б/у',              'AirPods, ishlatilgan',               150      from dual union all
  select 'samsung-bu',         'Samsung б/у',              'Samsung, ishlatilgan',               160      from dual union all
  -- aksessuarlar
  select 'acc-glass',          'Защитные стёкла',          'Himoya oynalari',                    200      from dual union all
  select 'acc-cases',          'Чехлы',                    'Chexollar',                          210      from dual union all
  select 'acc-chargers',       'Зарядки и кабели',         'Zaryadkalar va kabellar',            220      from dual union all
  select 'acc-powerbanks',     'Внешние аккумуляторы',     'Tashqi akkumulyatorlar',             230      from dual union all
  select 'acc-audio',          'Наушники и колонки',       'Quloqchin va kolonkalar',            240      from dual union all
  select 'acc-bands',          'Ремешки',                  'Bandlar',                            250      from dual union all
  select 'acc-camera',         'Защита камеры',            'Kamera himoyasi',                    260      from dual union all
  select 'acc-car',            'Автоаксессуары',           'Avtoaksessuarlar',                   270      from dual union all
  select 'acc-storage',        'Флешки и карты памяти',    'Fleshka va xotira kartalari',        280      from dual union all
  select 'acc-gadgets',        'Гаджеты и трекеры',        'Gadjet va trekerlar',                290      from dual
) s
on (t.code = s.code)
when matched then
  update set t.name_ru = s.name_ru,
             t.name_uz = s.name_uz,
             t.ord     = s.ord
when not matched then
  insert (code, name_ru, name_uz, ord, condition)
  values (s.code, s.name_ru, s.name_uz, s.ord, 'A');


prompt 3.2 Brendlar

merge into ipt_s_brands t
using (
  select 'apple'   code, 'Apple'   name from dual union all
  select 'samsung',      'Samsung'      from dual union all
  select 'xiaomi',       'Xiaomi'       from dual union all
  select 'dyson',        'Dyson'        from dual union all
  select 'green',        'Green'        from dual union all
  select 'baseus',       'Baseus'       from dual union all
  select 'hoco',         'Hoco'         from dual union all
  select 'anker',        'Anker'        from dual union all
  select 'other',        'Boshqa'       from dual
) s
on (t.code = s.code)
when matched then
  update set t.name = s.name
when not matched then
  insert (code, name, condition) values (s.code, s.name, 'A');

commit;


-- =============================================================================
-- 4. VIEW'LAR
-- =============================================================================

prompt 4.1 IPT_CATALOG_V — API uchun

-- DIQQAT: bu view API'ga chiqadi.
--
-- Faqat vitrina maydonlari kiritilgan. Mavjud ipt_products_v dan foydalanib
-- bo'lmaydi: unda provider, xarid narxi (price), investor_name bor va ular
-- tijorat siri (talablar hujjati 10-bo'lim). Shuningdek ipt_products_v
-- core_session.Get_Filial_Code bilan filtrlangan, katalog esa barcha
-- vitrinalarni ko'rishi kerak.
--
-- Bu yerga YANGI USTUN QO'SHISHDAN OLDIN o'ylab ko'ring: u to'g'ridan-to'g'ri
-- saytga chiqadi. name, provider, price, investor_id — hech qachon.
--
-- Chiqadigan qatorlar: omborda turgan (state='S'), soni > 0, katalog
-- maydonlari to'ldirilgan va vitrina filialiga tegishli tovarlar.
-- To'ldirilmagan tovarlar bu yerga tushmaydi — ular ipt_catalog_todo_v da.
--
-- Qatorlar ombor pozitsiyalari bo'yicha, YOPISHTIRILMAGAN holda beriladi.
-- Bir konfiguratsiyani bitta pozitsiyaga yig'ish (talablar hujjati 4.2)
-- sayt jamoasi bilan kelishilgandan keyin qo'shiladi.
create or replace force view ipt_catalog_v as
select
  t.id,
  t.model_code,
  t.model_name,
  t.category_code        category,
  t.brand_code           brand,
  t.item_condition       condition,
  t.retail_price_uzs/100 price,
  t.quantity,
  (select f.site_code
     from ipt_s_filials f
    where f.code = nvl(t.phys_filial_code, t.filial_code)) site_code,
  1                      is_active,
  -- up_on hech tahrirlanmagan tovarda NULL bo'ladi. O'shanda cr_on olinadi,
  -- aks holda bunday tovar updated_since bo'yicha delta'ga hech tushmaydi.
  nvl(t.up_on, t.cr_on)  updated_at
  From ipt_products t
 where t.state = 'S'
   and nvl(t.quantity, 0) > 0
   and t.retail_price_uzs is not null
   and t.model_code is not null
   and t.model_name is not null
   and t.category_code is not null
   and t.item_condition is not null
   and (select f.site_code
          from ipt_s_filials f
         where f.code = nvl(t.phys_filial_code, t.filial_code)) is not null
;


prompt 4.2 Ma'lumotnoma view'lari — frontend dropdownlari uchun

-- Tizimdagi qolgan ipt_s_*_v kabi: code + name.
-- Frontend bularni execSelect orqali oladi.
create or replace force view ipt_s_categories_v as
select
  t.code,
  t.name_ru name,
  t.name_uz,
  t.ord
  From ipt_s_categories t
 where t.condition = 'A'
 order by t.ord, t.code
;

create or replace force view ipt_s_brands_v as
select
  t.code,
  t.name
  From ipt_s_brands t
 where t.condition = 'A'
 order by t.name
;


prompt 4.3 IPT_CATALOG_TODO_V — ichki ish ro'yxati

-- DIQQAT: bu view API'ga CHIQMAYDI. Unda name ustuni bor, ichida mijoz
-- ismlari va qarz summalari bo'lishi mumkin. Faqat ombor xodimlari uchun.
--
-- Sotuvga tayyor, lekin katalog maydonlari to'ldirilmagani uchun saytga
-- chiqmayotgan tovarlar. Qo'lda to'ldirish ishining ro'yxati shu.
-- Barcha filiallar bo'yicha, filtrsiz.
create or replace force view ipt_catalog_todo_v as
select
  t.id,
  t.name,
  t.filial_code,
  t.quantity,
  case when t.retail_price_uzs is null then 'Y' else 'N' end no_price,
  case when t.model_code       is null then 'Y' else 'N' end no_model_code,
  case when t.model_name       is null then 'Y' else 'N' end no_model_name,
  case when t.category_code    is null then 'Y' else 'N' end no_category,
  case when t.item_condition   is null then 'Y' else 'N' end no_condition,
  case when (select f.site_code
               from ipt_s_filials f
              where f.code = nvl(t.phys_filial_code, t.filial_code)) is null
       then 'Y' else 'N' end no_site_code
  From ipt_products t
 where t.state = 'S'
   and nvl(t.quantity, 0) > 0
   and (t.retail_price_uzs is null
     or t.model_code is null
     or t.model_name is null
     or t.category_code is null
     or t.item_condition is null
     or (select f.site_code
           from ipt_s_filials f
          where f.code = nvl(t.phys_filial_code, t.filial_code)) is null)
 order by t.filial_code, t.id desc
;


-- =============================================================================
-- 5. IPT_METHODS_DML — tarixga yangi ustunlarni yozish
--
-- Product_His ustunlarni aniq sanab o'tadi, shuning uchun 2.1 dagi ALTER uni
-- buzmaydi. Lekin yangi ustunlar tarixga tushmay qolardi — quyida qo'shildi.
-- =============================================================================

create or replace package body Ipt_Methods_Dml is

  --Cr By: Arslonbek
  --Product his
  Procedure Product_His(p_Product_Id number, p_Action varchar2)
  is
  begin
    insert into ipt_products_his
    select
      t.id,
      t.name,
      t.type,
      t.price,
      t.investor_id,
      t.state,
      t.cr_by,
      t.cr_on,
      t.up_by,
      t.up_on,
      t.operation_id,
      t.filial_code,
      p_Action,
      core_session.Get_User_Id,
      sysdate,
      t.provider,
      t.quantity,
      t.car_type,
      t.car_plate_number,
      t.car_production_year,
      t.car_color,
      t.car_tech_passport_number,
      t.car_body_number,
      t.car_engine_number,
      t.car_mileage,
      t.car_owner_name,
      t.car_gen_trust_name,
      t.car_register_name,
      t.car_expense_amount,
      t.car_expense_details,
      t.car_market_price_min_max,
      t.car_purchase_date,
      t.car_tuning_details,
      t.car_paint_condition,
      t.car_price,
      -- katalog ustunlari
      t.retail_price_uzs,
      t.model_code,
      t.model_name,
      t.category_code,
      t.brand_code,
      t.item_condition,
      t.phys_filial_code
      from ipt_products t
     where t.id = p_Product_Id;
  end;

end Ipt_Methods_Dml;
/


-- =============================================================================
-- 6. ISHGA TUSHIRGANDAN KEYIN QO'LDA BAJARILADI
--
-- 6.1 Vitrina filiallarini belgilash. Qaysi kod qaysi shourum ekanini
--     aniqlagandan keyin:
--
--       update ipt_s_filials set site_code = 'mirobod' where code = '?????';
--       update ipt_s_filials set site_code = 'sebzor'  where code = '?????';
--       commit;
--
--     site_code qo'yilmagan filiallar saytga umuman chiqmaydi.
--
-- 6.2 Qoldiq bo'yicha katalog maydonlarini to'ldirish (~800 pozitsiya).
--     Ish ro'yxati:  select * from ipt_catalog_todo_v;
--     Qolgani:       select count(*) from ipt_catalog_todo_v;
--     Tayyor bo'lgani: select count(*) from ipt_catalog_v;
-- =============================================================================
