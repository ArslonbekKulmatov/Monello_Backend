-- =============================================================================
-- IPT KATALOG API — 3-BOSQICH: qolgan barcha maydonlar
--
-- Talablar hujjatining 2-4 bosqichlari bir faylda:
--   2-bosqich: storage_gb, ram_gb, color, sku, old_price
--   3-bosqich: ishlatilgan texnika maydonlari (imei, batareya, sim...)
--   4-bosqich: attributes, rasmlar, tavsiflar
--
-- ISHGA TUSHIRISH TARTIBI
--   1. ipt_catalog_stage1.sql
--   2. ipt_catalog_stage2.sql
--   3. ipt_catalog_stage3.sql          <- shu fayl
--   4. ipt_catalog_package.sql         <- paket, oxirida
--   5. ipt_catalog_product_action.sql  <- Ipt_Methods ga qo'lda
--
-- ASOSIY QAROR: rasm va xarakteristikalar MODEL darajasida saqlanadi,
-- mahsulot qatorida emas. Sababi: omborda bitta model o'nlab qator bo'lib
-- yotadi ("iPhone 16 Pro Max" yuklamada 34 marta). Rasmni har qatorga
-- alohida biriktirish — 34 marta bir xil ish. Sayt ham ularni bitta
-- kartochka deb ko'radi, ya'ni model darajasi to'g'ri daraja.
--
-- Aksincha, rang va xotira QATOR darajasida qoladi: omborda turgan aynan
-- shu apparatning xususiyati. Ishlatilgan texnika maydonlari ham shunday.
--
-- Muallif: Arslonbek Kulmatov
-- Sana   : 13.09.2026
-- =============================================================================


-- =============================================================================
-- 1. MA'LUMOTNOMALAR
-- =============================================================================

prompt 1.1 IPT_S_COLORS

create table IPT_S_COLORS
(
  code      VARCHAR2(30) not null,
  name_ru   VARCHAR2(200) not null,
  name_uz   VARCHAR2(200),
  condition VARCHAR2(2) default 'A' not null
)
;
comment on table IPT_S_COLORS
  is 'Ranglar. Kod lotin harflarida, API''ga shu ko''rinishda chiqadi';

alter table IPT_S_COLORS add constraint IPT_S_COLORS_PK primary key (CODE);
alter table IPT_S_COLORS add constraint IPT_S_COLORS_COND_CHK check (condition in ('A', 'P'));


prompt 1.2 IPT_S_SIM_TYPES

create table IPT_S_SIM_TYPES
(
  code      VARCHAR2(20) not null,
  name      VARCHAR2(200) not null,
  condition VARCHAR2(2) default 'A' not null
)
;
comment on table IPT_S_SIM_TYPES
  is 'SIM turlari: single, dual, esim, sim_esim';

alter table IPT_S_SIM_TYPES add constraint IPT_S_SIM_TYPES_PK primary key (CODE);


prompt 1.3 IPT_S_MARKET_CODES

create table IPT_S_MARKET_CODES
(
  code      VARCHAR2(20) not null,
  name      VARCHAR2(200) not null,
  condition VARCHAR2(2) default 'A' not null
)
;
comment on table IPT_S_MARKET_CODES
  is 'Bozor kodlari: LL/A, KHA, RUA, LZA, JA';

alter table IPT_S_MARKET_CODES add constraint IPT_S_MARKET_CODES_PK primary key (CODE);


prompt 1.4 IPT_S_REPLACED_PARTS

create table IPT_S_REPLACED_PARTS
(
  code      VARCHAR2(30) not null,
  name_ru   VARCHAR2(200) not null,
  name_uz   VARCHAR2(200),
  condition VARCHAR2(2) default 'A' not null
)
;
comment on table IPT_S_REPLACED_PARTS
  is 'Almashtirilgan qismlar: screen, glass, back_cover, body, battery';

alter table IPT_S_REPLACED_PARTS add constraint IPT_S_REPLACED_PARTS_PK primary key (CODE);


prompt 1.5 IPT_S_ATTRIBUTES

create table IPT_S_ATTRIBUTES
(
  code       VARCHAR2(40) not null,
  name_ru    VARCHAR2(200) not null,
  name_uz    VARCHAR2(200),
  value_type VARCHAR2(10) default 'text' not null,
  is_multi   NUMBER(1) default 0 not null,
  condition  VARCHAR2(2) default 'A' not null
)
;
comment on table IPT_S_ATTRIBUTES
  is 'Xarakteristikalar ma''lumotnomasi. Ro''yxat kengayadigan — yangi xarakteristika uchun jadval o''zgartirish shart emas, shu yerga qator qo''shiladi';
comment on column IPT_S_ATTRIBUTES.value_type
  is 'text / number / bool — API javobida qiymat qanday turda chiqishini belgilaydi';
comment on column IPT_S_ATTRIBUTES.is_multi
  is '1 bo''lsa API''da massiv bo''lib chiqadi (acc_compat kabi), 0 bo''lsa bitta qiymat';

alter table IPT_S_ATTRIBUTES add constraint IPT_S_ATTRIBUTES_PK primary key (CODE);
alter table IPT_S_ATTRIBUTES add constraint IPT_S_ATTRIBUTES_TYPE_CHK
  check (value_type in ('text', 'number', 'bool'));


-- =============================================================================
-- 2. MODEL DARAJASIDAGI JADVALLAR
--
-- Kalit — model_code, mahsulot id emas. Bitta model uchun bir marta
-- to'ldiriladi va o'sha modelning barcha ombor qatorlariga tegishli bo'ladi.
-- FK qo'yilmaydi: model_code ipt_products da unikal emas (bitta modelda
-- ko'p qator bor) va ma'lumotni mahsulotdan oldin kiritish mumkin bo'lishi kerak.
-- =============================================================================

prompt 2.1 IPT_MODEL_IMAGES

create table IPT_MODEL_IMAGES
(
  id         NUMBER(20) not null,
  model_code VARCHAR2(200) not null,
  color_code VARCHAR2(30),
  url        VARCHAR2(1000),
  file_name  VARCHAR2(500),
  is_primary NUMBER(1) default 0 not null,
  ord        NUMBER(5) default 100 not null,
  cr_by      NUMBER(20),
  cr_on      DATE,
  up_by      NUMBER(20),
  up_on      DATE
)
;
comment on table IPT_MODEL_IMAGES
  is 'Model rasmlari. Kalit model_code — bitta modelning barcha ombor qatorlariga tegishli';
comment on column IPT_MODEL_IMAGES.color_code
  is 'Rasm qaysi rangga tegishli. Bo''sh bo''lsa — modelning umumiy rasmi';
comment on column IPT_MODEL_IMAGES.url
  is 'TASHQI havola — rasm boshqa joyda saqlansa. file_name bilan birga to''ldirilmaydi';
comment on column IPT_MODEL_IMAGES.file_name
  is 'SERVERDA saqlangan fayl nomi. To''liq havola core_properties.catalog_file_url bilan yig''iladi. Har yuklashda nom yangi bo''ladi — sayt eski rasmni keshdan olmasligi uchun';
comment on column IPT_MODEL_IMAGES.is_primary
  is '1 — kartochkadagi asosiy rasm';
comment on column IPT_MODEL_IMAGES.ord
  is 'Ko''rsatish tartibi';

alter table IPT_MODEL_IMAGES add constraint IPT_MODEL_IMAGES_PK primary key (ID);
alter table IPT_MODEL_IMAGES add constraint IPT_MODEL_IMAGES_COLOR_FK
  foreign key (COLOR_CODE) references IPT_S_COLORS (CODE);
-- Rasm yo serverda, yo tashqarida. Ikkalasi ham bo'sh bo'lsa — havolasiz yozuv,
-- ikkalasi ham to'ldirilgan bo'lsa — qaysi biri haqiqiy ekani noaniq.
alter table IPT_MODEL_IMAGES add constraint IPT_MODEL_IMAGES_SRC_CHK
  check ((url is not null and file_name is null)
      or (url is null and file_name is not null));
create index IPT_MODEL_IMAGES_IDX1 on IPT_MODEL_IMAGES (MODEL_CODE);

create sequence IPT_MODEL_IMAGES_SEQ start with 1 increment by 1 nocache;


prompt 2.2 IPT_MODEL_ATTRIBUTES

create table IPT_MODEL_ATTRIBUTES
(
  id         NUMBER(20) not null,
  model_code VARCHAR2(200) not null,
  attr_code  VARCHAR2(40) not null,
  attr_value VARCHAR2(500) not null,
  ord        NUMBER(5) default 100 not null,
  cr_by      NUMBER(20),
  cr_on      DATE
)
;
comment on table IPT_MODEL_ATTRIBUTES
  is 'Model xarakteristikalari. Ko''p qiymatli xarakteristika (acc_compat) bir necha qator bo''lib yotadi';
comment on column IPT_MODEL_ATTRIBUTES.attr_value
  is 'Qiymat doim matn sifatida saqlanadi. API''da ipt_s_attributes.value_type bo''yicha son yoki mantiqiy turga o''giriladi';

alter table IPT_MODEL_ATTRIBUTES add constraint IPT_MODEL_ATTRIBUTES_PK primary key (ID);
alter table IPT_MODEL_ATTRIBUTES add constraint IPT_MODEL_ATTRIBUTES_FK
  foreign key (ATTR_CODE) references IPT_S_ATTRIBUTES (CODE);
alter table IPT_MODEL_ATTRIBUTES add constraint IPT_MODEL_ATTRIBUTES_UK
  unique (MODEL_CODE, ATTR_CODE, ATTR_VALUE);
create index IPT_MODEL_ATTRIBUTES_IDX1 on IPT_MODEL_ATTRIBUTES (MODEL_CODE);

create sequence IPT_MODEL_ATTRIBUTES_SEQ start with 1 increment by 1 nocache;


-- =============================================================================
-- 3. IPT_PRODUCTS — QATOR DARAJASIDAGI MAYDONLAR
-- =============================================================================

prompt 3.1 IPT_PRODUCTS

alter table IPT_PRODUCTS add
(
  storage_gb         NUMBER(6),
  ram_gb             NUMBER(4),
  color_code         VARCHAR2(30),
  sku                VARCHAR2(100),
  old_price_uzs      NUMBER(22),
  warranty_months    NUMBER(4),
  model_name_uz      VARCHAR2(1000),
  description_ru     VARCHAR2(4000),
  description_uz     VARCHAR2(4000),
  battery_health_pct NUMBER(3),
  imei               VARCHAR2(20),
  serial             VARCHAR2(50),
  sim_type           VARCHAR2(20),
  market_code        VARCHAR2(20),
  replaced_parts     VARCHAR2(200),
  has_box            NUMBER(1),
  has_charger        NUMBER(1)
);

comment on column IPT_PRODUCTS.storage_gb
  is 'Xotira hajmi, GB: 256';
comment on column IPT_PRODUCTS.ram_gb
  is 'Operativ xotira, GB. Android''da "6/128" juftligining birinchi qismi';
comment on column IPT_PRODUCTS.color_code
  is 'ipt_s_colors.code';
comment on column IPT_PRODUCTS.sku
  is 'Artikul, xaridorga ko''rsatiladi';
comment on column IPT_PRODUCTS.old_price_uzs
  is 'Chizib tashlanadigan eski narx, SOMDA, TIYINDA. Bo''sh bo''lsa chegirma yo''q';
comment on column IPT_PRODUCTS.warranty_months
  is 'Kafolat, oyda. Bo''sh bo''lsa sayt 12 deb hisoblaydi';
comment on column IPT_PRODUCTS.description_ru
  is 'Kartochka tavsifi, ruscha';
comment on column IPT_PRODUCTS.battery_health_pct
  is 'Batareya holati, foizda: 88. Ishlatilgan texnikada asosiy ko''rsatkich';
comment on column IPT_PRODUCTS.imei
  is 'IMEI oxirgi 6 raqami — sayt to''liq raqamni so''ramaydi';
comment on column IPT_PRODUCTS.serial
  is 'Mac, iPad va soatlar uchun IMEI o''rniga';
comment on column IPT_PRODUCTS.sim_type
  is 'ipt_s_sim_types.code: single, dual, esim, sim_esim';
comment on column IPT_PRODUCTS.market_code
  is 'ipt_s_market_codes.code: LL/A, KHA, RUA, LZA, JA';
comment on column IPT_PRODUCTS.replaced_parts
  is 'Almashtirilgan qismlar, vergul bilan: "screen,back_cover". API''da massiv bo''lib chiqadi. Yopiq ro''yxat va qidirilmaydi, shuning uchun alohida jadval qilinmadi';
comment on column IPT_PRODUCTS.has_box
  is '1 — qutisi bor, 0 — yo''q, bo''sh — noma''lum';
comment on column IPT_PRODUCTS.has_charger
  is '1 — zaryadkasi bor, 0 — yo''q, bo''sh — noma''lum';

alter table IPT_PRODUCTS add constraint IPT_PRODUCTS_COLOR_FK
  foreign key (COLOR_CODE) references IPT_S_COLORS (CODE);
alter table IPT_PRODUCTS add constraint IPT_PRODUCTS_SIM_FK
  foreign key (SIM_TYPE) references IPT_S_SIM_TYPES (CODE);
alter table IPT_PRODUCTS add constraint IPT_PRODUCTS_MARKET_FK
  foreign key (MARKET_CODE) references IPT_S_MARKET_CODES (CODE);
alter table IPT_PRODUCTS add constraint IPT_PRODUCTS_BATTERY_CHK
  check (battery_health_pct between 1 and 100);
alter table IPT_PRODUCTS add constraint IPT_PRODUCTS_HASBOX_CHK
  check (has_box in (0, 1));
alter table IPT_PRODUCTS add constraint IPT_PRODUCTS_HASCHRG_CHK
  check (has_charger in (0, 1));


prompt 3.2 IPT_PRODUCTS_HIS — ko'zgu

alter table IPT_PRODUCTS_HIS add
(
  storage_gb         NUMBER(6),
  ram_gb             NUMBER(4),
  color_code         VARCHAR2(30),
  sku                VARCHAR2(100),
  old_price_uzs      NUMBER(22),
  warranty_months    NUMBER(4),
  model_name_uz      VARCHAR2(1000),
  description_ru     VARCHAR2(4000),
  description_uz     VARCHAR2(4000),
  battery_health_pct NUMBER(3),
  imei               VARCHAR2(20),
  serial             VARCHAR2(50),
  sim_type           VARCHAR2(20),
  market_code        VARCHAR2(20),
  replaced_parts     VARCHAR2(200),
  has_box            NUMBER(1),
  has_charger        NUMBER(1)
);


-- =============================================================================
-- 4. MA'LUMOTNOMA QIYMATLARI
-- =============================================================================

prompt 4.1 Ranglar

merge into ipt_s_colors t
using (
  select 'silver'           code, 'Серебристый'      name_ru, 'Kumushrang'        name_uz from dual union all
  select 'space-black',           'Чёрный космос',            'Kosmik qora'               from dual union all
  select 'black',                 'Чёрный',                   'Qora'                      from dual union all
  select 'white',                 'Белый',                    'Oq'                        from dual union all
  select 'desert',                'Пустынный титан',          'Sahro titani'              from dual union all
  select 'natural-titanium',      'Натуральный титан',        'Tabiiy titan'              from dual union all
  select 'blue-titanium',         'Синий титан',              'Ko''k titan'               from dual union all
  select 'deep-blue',             'Тёмно-синий',              'To''q ko''k'               from dual union all
  select 'gold',                  'Золотой',                  'Oltin'                     from dual union all
  select 'green',                 'Зелёный',                  'Yashil'                    from dual union all
  select 'pink',                  'Розовый',                  'Pushti'                    from dual union all
  select 'purple',                'Фиолетовый',               'Binafsha'                  from dual union all
  select 'red',                   'Красный',                  'Qizil'                     from dual union all
  select 'gray',                  'Серый',                    'Kulrang'                   from dual
) s
on (t.code = s.code)
when matched then
  update set t.name_ru = s.name_ru, t.name_uz = s.name_uz
when not matched then
  insert (code, name_ru, name_uz, condition) values (s.code, s.name_ru, s.name_uz, 'A');


prompt 4.2 SIM turlari, bozor kodlari, almashtirilgan qismlar

merge into ipt_s_sim_types t
using (
  select 'single'   code, '1 SIM'          name from dual union all
  select 'dual',          '2 SIM'               from dual union all
  select 'esim',          'Только eSIM'         from dual union all
  select 'sim_esim',      'SIM + eSIM'          from dual
) s
on (t.code = s.code)
when matched then update set t.name = s.name
when not matched then insert (code, name, condition) values (s.code, s.name, 'A');

merge into ipt_s_market_codes t
using (
  select 'LL/A' code, 'США'          name from dual union all
  select 'KHA',       'Корея'             from dual union all
  select 'RUA',       'Россия'            from dual union all
  select 'LZA',       'Латинская Америка' from dual union all
  select 'JA',        'Япония'            from dual union all
  select 'ZA',        'Сингапур'          from dual union all
  select 'AE',        'ОАЭ'               from dual
) s
on (t.code = s.code)
when matched then update set t.name = s.name
when not matched then insert (code, name, condition) values (s.code, s.name, 'A');

merge into ipt_s_replaced_parts t
using (
  select 'screen'     code, 'Экран'         name_ru, 'Ekran'        name_uz from dual union all
  select 'glass',           'Стекло',                'Oyna'                 from dual union all
  select 'back_cover',      'Задняя крышка',         'Orqa qopqoq'          from dual union all
  select 'body',            'Корпус',                'Korpus'               from dual union all
  select 'battery',         'Аккумулятор',           'Batareya'             from dual
) s
on (t.code = s.code)
when matched then
  update set t.name_ru = s.name_ru, t.name_uz = s.name_uz
when not matched then
  insert (code, name_ru, name_uz, condition) values (s.code, s.name_ru, s.name_uz, 'A');


prompt 4.3 Xarakteristikalar

merge into ipt_s_attributes t
using (
  select 'chip'          code, 'Чип'              name_ru, 'Chip'                name_uz, 'text'   value_type, 0 is_multi from dual union all
  select 'screen_size',        'Диагональ',                'Diagonal',                    'number',            0         from dual union all
  select 'network_5g',         '5G',                       '5G',                          'bool',              0         from dual union all
  select 'watch_case_mm',      'Корпус часов, мм',         'Soat korpusi, mm',            'number',            0         from dual union all
  select 'watch_band',         'Ремешок',                  'Band',                        'text',              0         from dual union all
  select 'acc_compat',         'Совместимость',            'Moslik',                      'text',              1         from dual union all
  select 'acc_feature',        'Особенности',              'Xususiyatlar',                'text',              1         from dual union all
  select 'acc_material',       'Материал',                 'Material',                    'text',              1         from dual union all
  select 'power_w',            'Мощность, Вт',             'Quvvat, Vt',                  'number',            0         from dual union all
  select 'capacity_mah',       'Ёмкость, мА·ч',            'Sig''im, mA·s',               'number',            0         from dual
) s
on (t.code = s.code)
when matched then
  update set t.name_ru    = s.name_ru,
             t.name_uz    = s.name_uz,
             t.value_type = s.value_type,
             t.is_multi   = s.is_multi
when not matched then
  insert (code, name_ru, name_uz, value_type, is_multi, condition)
  values (s.code, s.name_ru, s.name_uz, s.value_type, s.is_multi, 'A');


prompt 4.4 Rasmlar uchun bazaviy havola

-- Serverga yuklangan rasm havolasi shu prefiks + fayl nomi ko'rinishida
-- yig'iladi. Sayt rasmlarni AVTORIZATSIYASIZ ocha olishi kerak — /api/app/get-file
-- aynan shunday ishlaydi (Spring Security bu endpointni himoyalamaydi).
--
-- Keyinchalik rasmlarni alohida static hostga ko'chirsangiz, faqat shu
-- qiymatni o'zgartirasiz — kodga tegish shart emas.
--
-- DOMENNI O'ZINGIZNIKIGA ALMASHTIRING:
merge into core_properties t
using (select 'catalog_file_url' param_name,
              'https://erp.abmstore.uz/api/app/get-file?file=' param_value from dual) s
on (t.param_name = s.param_name)
when not matched then
  insert (param_name, param_value, condition) values (s.param_name, s.param_value, 'A');

commit;


-- =============================================================================
-- 5. VIEW'LAR
-- =============================================================================

prompt 5.1 Ma'lumotnoma view'lari

create or replace force view ipt_s_colors_v as
select t.code, t.name_ru name, t.name_uz
  From ipt_s_colors t
 where t.condition = 'A'
 order by t.name_ru
;

create or replace force view ipt_s_sim_types_v as
select t.code, t.name
  From ipt_s_sim_types t
 where t.condition = 'A'
 order by t.code
;

create or replace force view ipt_s_market_codes_v as
select t.code, t.name
  From ipt_s_market_codes t
 where t.condition = 'A'
 order by t.code
;

create or replace force view ipt_s_replaced_parts_v as
select t.code, t.name_ru name, t.name_uz
  From ipt_s_replaced_parts t
 where t.condition = 'A'
 order by t.code
;

create or replace force view ipt_s_attributes_v as
select t.code, t.name_ru name, t.name_uz, t.value_type, t.is_multi
  From ipt_s_attributes t
 where t.condition = 'A'
 order by t.code
;


prompt 5.2 IPT_CATALOG_V — yangi maydonlar bilan

-- DIQQAT: bu view API'ga chiqadi. Faqat vitrina maydonlari.
-- name, provider, price (xarid), investor_id — hech qachon.
--
-- Chiqish sharti 1-bosqichdagidek: omborda, soni > 0, majburiy beshta
-- maydon to'ldirilgan, filiali vitrina. Yangi maydonlar IXTIYORIY —
-- ular bo'lmasa ham tovar katalogda ko'rinadi.
create or replace force view ipt_catalog_v as
select
  t.id,
  t.model_code,
  t.model_name,
  t.model_name_uz,
  t.category_code        category,
  t.brand_code           brand,
  t.item_condition       condition,
  t.retail_price_uzs/100 price,
  t.old_price_uzs/100    old_price,
  t.quantity,
  t.sku,
  t.storage_gb,
  t.ram_gb,
  t.color_code,
  (select c.name_ru from ipt_s_colors c where c.code = t.color_code) color_name_ru,
  (select c.name_uz from ipt_s_colors c where c.code = t.color_code) color_name_uz,
  t.warranty_months,
  t.description_ru,
  t.description_uz,
  -- ishlatilgan texnika
  t.battery_health_pct,
  t.imei,
  t.serial,
  t.sim_type,
  t.market_code,
  t.replaced_parts,
  t.has_box,
  t.has_charger,
  --
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
   and t.brand_code is not null
   and t.item_condition is not null
   and (select f.site_code
          from ipt_s_filials f
         where f.code = nvl(t.phys_filial_code, t.filial_code)) is not null
;


prompt 5.3 IPT_MODEL_IMAGES_V va IPT_MODEL_ATTRIBUTES_V

create or replace force view ipt_model_images_v as
select
  t.id,
  t.model_code,
  t.color_code,
  (select c.name_ru from ipt_s_colors c where c.code = t.color_code) color_name,
  -- Serverdagi fayl bo'lsa to'liq havola yig'iladi, aks holda tashqi havola
  nvl(t.url, Core_Util.Get_Properties('catalog_file_url')||t.file_name) url,
  t.file_name,
  case when t.file_name is null then 'EXT' else 'SRV' end source,
  t.is_primary,
  t.ord,
  t.cr_on
  From ipt_model_images t
 order by t.model_code, t.ord, t.id
;

create or replace force view ipt_model_attributes_v as
select
  t.id,
  t.model_code,
  t.attr_code,
  (select a.name_ru from ipt_s_attributes a where a.code = t.attr_code) attr_name,
  t.attr_value,
  t.ord
  From ipt_model_attributes t
 order by t.model_code, t.attr_code, t.ord, t.id
;


-- =============================================================================
-- 6. IPT_METHODS_DML — tarixga barcha yangi ustunlar
--
-- Product_His ustunlarni aniq sanab o'tadi, shuning uchun ALTER uni buzmaydi,
-- lekin yangi ustunlar tarixga tushmay qolardi.
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
      -- katalog, 1-bosqich
      t.retail_price_uzs,
      t.model_code,
      t.model_name,
      t.category_code,
      t.brand_code,
      t.item_condition,
      t.phys_filial_code,
      -- katalog, 3-bosqich
      t.storage_gb,
      t.ram_gb,
      t.color_code,
      t.sku,
      t.old_price_uzs,
      t.warranty_months,
      t.model_name_uz,
      t.description_ru,
      t.description_uz,
      t.battery_health_pct,
      t.imei,
      t.serial,
      t.sim_type,
      t.market_code,
      t.replaced_parts,
      t.has_box,
      t.has_charger
      from ipt_products t
     where t.id = p_Product_Id;
  end;

end Ipt_Methods_Dml;
/
