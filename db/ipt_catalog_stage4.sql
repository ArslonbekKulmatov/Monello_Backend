-- =============================================================================
-- IPT KATALOG — 4-BOSQICH: sayt jamoasining 21.09.2026 dagi javobi bo'yicha
--
-- NIMA O'ZGARADI
--   1. Kategoriyalar 24 tadan 28 taga: gadgets, accessories, dyson-bu, gadgets-bu
--   2. Konteyner bo'limlar belgilanadi: accessories va used — ularga tovar
--      QO'YILMAYDI, tovar acc-* va *-bu ichiga tushadi
--   3. Konteyner kategoriya tanlanishini baza to'sadi
--
-- DIQQAT: bu fayldagi statementlar ichida bo'sh qator yo'q va bo'lmasligi
-- kerak — SQL*Plus bo'sh qatorni "statement tugadi" deb tushunadi.
--
-- ISHGA TUSHIRISH: ipt_catalog_stage3.sql dan keyin.
-- Keyin ipt_catalog_package.sql ni QAYTA kompilyatsiya qiling — tekshiruv
-- o'sha paketda.
--
-- Muallif: Arslonbek Kulmatov
-- Sana   : 21.09.2026
-- =============================================================================

prompt 1.1 IPT_S_CATEGORIES — konteyner bayrog'i

alter table IPT_S_CATEGORIES add
(
  is_container NUMBER(1) default 0 not null
);
comment on column IPT_S_CATEGORIES.is_container
  is '1 - bo''lim konteyner: saytda ro''yxat sifatida ko''rinadi, lekin tovar unga QO''YILMAYDI';
alter table IPT_S_CATEGORIES
  add constraint IPT_S_CATEG_CONTAINER_CHK check (is_container in (0, 1));

-- =============================================================================
-- 2. KATEGORIYALAR — sayt jamoasi bergan 28 ta kod
--
-- Qayta ishga tushirilsa ham xavfsiz.
-- =============================================================================

prompt 2.1 Kategoriyalar

merge into ipt_s_categories t
using (
  select 'iphone'         code, 'iPhone'                    name_ru, 'iPhone'                       name_uz,  10 ord, 0 cont from dual union all
  select 'ipad',                'iPad',                     'iPad',                                  20,     0 from dual union all
  select 'mac',                 'Mac',                      'Mac',                                   30,     0 from dual union all
  select 'apple-watch',         'Apple Watch',              'Apple Watch',                           40,     0 from dual union all
  select 'airpods',             'AirPods',                  'AirPods',                               50,     0 from dual union all
  select 'samsung',             'Samsung',                  'Samsung',                               60,     0 from dual union all
  select 'dyson',               'Dyson',                    'Dyson',                                 70,     0 from dual union all
  select 'gadgets',             'Гаджеты',                  'Gadjetlar',                             80,     0 from dual union all
  select 'accessories',         'Аксессуары',               'Aksessuarlar',                          90,     1 from dual union all
  select 'acc-glass',           'Защитные стёкла',          'Himoya oynalari',                      100,     0 from dual union all
  select 'acc-cases',           'Чехлы',                    'G''iloflar',                           110,     0 from dual union all
  select 'acc-chargers',        'Зарядки и кабели',         'Quvvatlagichlar va kabellar',          120,     0 from dual union all
  select 'acc-powerbanks',      'Внешние аккумуляторы',     'Tashqi batareyalar',                   130,     0 from dual union all
  select 'acc-audio',           'Наушники и колонки',       'Quloqchinlar va kolonkalar',           140,     0 from dual union all
  select 'acc-bands',           'Ремешки',                  'Tasmalar',                             150,     0 from dual union all
  select 'acc-camera',          'Защита камеры',            'Kamera himoyasi',                      160,     0 from dual union all
  select 'acc-car',             'Автоаксессуары',           'Avto aksessuarlar',                    170,     0 from dual union all
  select 'acc-storage',         'Флешки и карты памяти',    'Fleshkalar va xotira kartalari',       180,     0 from dual union all
  select 'acc-gadgets',         'Гаджеты и трекеры',        'Gadjetlar va trekerlar',               190,     0 from dual union all
  select 'used',                'Б/у техника',              'Ishlatilgan texnika',                  200,     1 from dual union all
  select 'iphone-bu',           'Б/у: iPhone',              'Ishlatilgan: iPhone',                  210,     0 from dual union all
  select 'ipad-bu',             'Б/у: iPad',                'Ishlatilgan: iPad',                    220,     0 from dual union all
  select 'mac-bu',              'Б/у: Mac',                 'Ishlatilgan: Mac',                     230,     0 from dual union all
  select 'apple-watch-bu',      'Б/у: Apple Watch',         'Ishlatilgan: Apple Watch',             240,     0 from dual union all
  select 'airpods-bu',          'Б/у: AirPods',             'Ishlatilgan: AirPods',                 250,     0 from dual union all
  select 'samsung-bu',          'Б/у: смартфоны Android',   'Ishlatilgan: Android smartfonlar',     260,     0 from dual union all
  select 'dyson-bu',            'Б/у: Dyson',               'Ishlatilgan: Dyson',                   270,     0 from dual union all
  select 'gadgets-bu',          'Б/у: гаджеты',             'Ishlatilgan: gadjetlar',               280,     0 from dual
) s
on (t.code = s.code)
when matched then
  update set t.name_ru      = s.name_ru,
             t.name_uz      = s.name_uz,
             t.ord          = s.ord,
             t.is_container = s.cont,
             t.condition    = 'A'
when not matched then
  insert (code, name_ru, name_uz, ord, is_container, condition)
  values (s.code, s.name_ru, s.name_uz, s.ord, s.cont, 'A');

commit;

-- =============================================================================
-- 3. MA'LUMOTNOMA VIEW — konteyner bayrog'i bilan
--
-- Web formasi konteyner bo'limlarni tanlab bo'lmaydigan qilib ko'rsatishi
-- uchun. Baza baribir to'sadi, lekin tanlab bo'lgandan keyin xato olish
-- yomon: tanlab bo'lmasligi kerak.
-- =============================================================================

prompt 3.1 IPT_S_CATEGORIES_V

create or replace force view ipt_s_categories_v as
select t.code,
       t.name_ru,
       t.name_uz,
       t.ord,
       t.is_container,
       t.condition
  from ipt_s_categories t
 where t.condition = 'A'
 order by t.ord, t.code
;

-- =============================================================================
-- 3.2 MA'LUMOTNOMALAR FORMASIGA YANGI USTUN
--
-- Ipt_Dictionary metadata'siga is_container qo'shiladi, shunda yangi
-- kategoriya qo'shayotgan xodim uni konteyner qilib belgilay oladi.
-- ipt_dictionary.sql ishga tushirilmagan bo'lsa bu blok xato beradi —
-- o'tkazib yuboring.
-- =============================================================================

prompt 3.2 Ipt_Dictionary metadata

merge into ipt_s_dictionary_cols t
using (
  select 'categories' d, 'IS_CONTAINER' c, 'Раздел-контейнер' nr,
         'Konteyner bo''lim' nu, 'B' dt, null ml, 'N' rq, null lov, 25 ord from dual
) s
on (t.dict_code = s.d and t.column_name = s.c)
when matched then
  update set t.name_ru = s.nr, t.name_uz = s.nu, t.data_type = s.dt,
             t.is_required = s.rq, t.ord = s.ord, t.condition = 'A'
when not matched then
  insert (dict_code, column_name, name_ru, name_uz, data_type, max_len,
          is_required, lov, ord, condition)
  values (s.d, s.c, s.nr, s.nu, s.dt, s.ml, s.rq, s.lov, s.ord, 'A');

commit;

-- =============================================================================
-- 4. MAVJUD MA'LUMOTNI TEKSHIRISH
--
-- Konteyner kategoriyaga biriktirilgan tovar qolib ketmasin. Katalog hali
-- to'ldirilmagani uchun bu ro'yxat bo'sh chiqishi kerak.
--
--   select id, name, category_code
--     from ipt_products
--    where category_code in ('accessories', 'used');
--
-- Bo'sh chiqmasa — o'sha tovarlarni aniq bo'limga ko'chiring:
--
--   update ipt_products set category_code = 'acc-cases'
--    where category_code = 'accessories' and id in (...);
--
-- =============================================================================

prompt 4.1 Konteyner kategoriyali tovarlar

select count(*) konteynerda_qolgan_tovarlar
  from ipt_products t
 where t.category_code in (select c.code from ipt_s_categories c where c.is_container = 1);

-- =============================================================================
-- 5. KEYINGI QADAM
--
-- ipt_catalog_package.sql ni qayta kompilyatsiya qiling: Apply_Catalog_Fields
-- ga konteyner tekshiruvi qo'shilgan. Usiz baza konteyner kategoriyani
-- qabul qilaveradi.
-- =============================================================================
