-- =============================================================================
-- IPT KATALOG — 6-BOSQICH: MXIK, o'lchov birligi, QQS stavkasi
--
-- Sayt jamoasining 6-bandi. Qaror: maydonlar Monello'da ochiladi va web
-- orqali to'ldiriladi.
--
-- NIMA QO'SHILADI
--   mxik_code  — MXIK (IKPU) kodi, fiskal chek uchun
--   unit_code  — o'lchov birligi, IPT_S_UNITS ma'lumotnomasidan
--   vat_rate   — QQS stavkasi, FOIZDA (12 = 12%), tiyin emas
--
-- ISHGA TUSHIRISH: ipt_catalog_stage5.sql dan keyin.
-- Keyin ipt_catalog_package.sql ni QAYTA kompilyatsiya qiling.
--
-- DIQQAT: statementlar ichida bo'sh qator yo'q va bo'lmasligi kerak.
--
-- Muallif: Arslonbek Kulmatov
-- Sana   : 21.09.2026
-- =============================================================================

prompt 1.1 IPT_S_UNITS — o'lchov birliklari

create table IPT_S_UNITS
(
  code      VARCHAR2(30) not null,
  name_ru   VARCHAR2(200) not null,
  name_uz   VARCHAR2(200),
  ord       NUMBER(5) default 100 not null,
  condition VARCHAR2(2) default 'A' not null
)
;
comment on table IPT_S_UNITS
  is 'O''lchov birliklari. Kodlar fiskal klassifikator bilan mos bo''lishi kerak';
alter table IPT_S_UNITS add constraint IPT_S_UNITS_PK primary key (CODE);
alter table IPT_S_UNITS add constraint IPT_S_UNITS_COND_CHK check (condition in ('A', 'P'));

-- =============================================================================
-- 1.2 BIRLIKLAR — boshlang'ich ro'yxat
--
-- DIQQAT: bu kodlar taxminiy. Fiskal chek uchun ular soliq
-- klassifikatoridagi kodlar bilan MOS bo'lishi kerak. Haqiqiy kodlarni
-- buxgalteriyadan oling va ma'lumotnomalar formasidan tuzating — kod
-- o'zgartirish uchun bu faylni qayta bajarish shart emas.
--
-- Telefon va aksessuar uchun amalda "dona" yetarli.
-- =============================================================================

prompt 1.2 Birliklar

merge into ipt_s_units t
using (
  select 'dona'     code, 'Штука'    name_ru, 'Dona'     name_uz, 10 ord from dual union all
  select 'komplekt',      'Комплект',         'Komplekt',         20 from dual union all
  select 'upakovka',      'Упаковка',         'Upakovka',         30 from dual union all
  select 'kg',            'Килограмм',        'Kilogramm',        40 from dual union all
  select 'litr',          'Литр',             'Litr',             50 from dual union all
  select 'metr',          'Метр',             'Metr',             60 from dual
) s
on (t.code = s.code)
when matched then
  update set t.name_ru = s.name_ru, t.name_uz = s.name_uz,
             t.ord = s.ord, t.condition = 'A'
when not matched then
  insert (code, name_ru, name_uz, ord, condition)
  values (s.code, s.name_ru, s.name_uz, s.ord, 'A');

commit;

prompt 1.3 IPT_S_UNITS_V

create or replace force view ipt_s_units_v as
select t.code, t.name_ru, t.name_uz, t.ord, t.condition
  from ipt_s_units t
 where t.condition = 'A'
 order by t.ord, t.code
;

-- =============================================================================
-- 2. MAHSULOT MAYDONLARI
--
-- Ustunlar IPT_PRODUCTS va IPT_PRODUCTS_HIS ga BIR XIL TARTIBDA qo'shiladi:
-- Product_His pozitsion insert ishlatadi, tartib buzilsa ma'lumot boshqa
-- ustunga tushadi va buni hech kim sezmaydi.
-- =============================================================================

prompt 2.1 IPT_PRODUCTS

alter table IPT_PRODUCTS add
(
  mxik_code VARCHAR2(20),
  unit_code VARCHAR2(30),
  vat_rate  NUMBER(5,2)
);
comment on column IPT_PRODUCTS.mxik_code
  is 'MXIK (IKPU) kodi, faqat raqam. Fiskal chek uchun';
comment on column IPT_PRODUCTS.unit_code
  is 'O''lchov birligi, ipt_s_units dan';
comment on column IPT_PRODUCTS.vat_rate
  is 'QQS stavkasi FOIZDA: 12 = 12%. Tiyinda emas, koeffitsient ham emas';
alter table IPT_PRODUCTS add constraint IPT_PRODUCTS_UNIT_FK
  foreign key (UNIT_CODE) references IPT_S_UNITS (CODE);
alter table IPT_PRODUCTS add constraint IPT_PRODUCTS_MXIK_CHK
  check (mxik_code is null or regexp_like(mxik_code, '^[0-9]+$'));
alter table IPT_PRODUCTS add constraint IPT_PRODUCTS_VAT_CHK
  check (vat_rate is null or (vat_rate >= 0 and vat_rate <= 100));

prompt 2.2 IPT_PRODUCTS_HIS — ko'zgu

alter table IPT_PRODUCTS_HIS add
(
  mxik_code VARCHAR2(20),
  unit_code VARCHAR2(30),
  vat_rate  NUMBER(5,2)
);

-- =============================================================================
-- 3. PRODUCT_HIS — yangi ustunlarni tarixga yozish
--
-- Pozitsion insert, shuning uchun uchta yangi ustun OXIRIGA qo'shiladi.
-- =============================================================================

prompt 3.1 IPT_METHODS_DML

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
      t.has_charger,
      -- katalog, 6-bosqich: fiskal maydonlar
      t.mxik_code,
      t.unit_code,
      t.vat_rate
      from ipt_products t
     where t.id = p_Product_Id;
  end;

end Ipt_Methods_Dml;
/

-- =============================================================================
-- 4. KATALOG VIEW'LARI — uchta maydonni saytga chiqarish
--
-- ipt_catalog_base_v va ipt_catalog_v stage5 dagi ta'rifga uchta ustun
-- qo'shib qayta yaratiladi.
-- =============================================================================

prompt 4.1 IPT_CATALOG_BASE_V

create or replace force view ipt_catalog_base_v as
select
  t.id                   product_id,
  case when t.item_condition = 'used'
       then to_char(t.id)
       else lower(t.model_code)
            ||'~'|| nvl(to_char(t.storage_gb), 'x')
            ||'~'|| nvl(to_char(t.ram_gb), 'x')
            ||'~'|| nvl(t.color_code, 'x')
  end                    catalog_id,
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
  t.battery_health_pct,
  t.imei,
  t.serial,
  t.sim_type,
  t.market_code,
  t.replaced_parts,
  t.has_box,
  t.has_charger,
  t.mxik_code,
  t.unit_code,
  (select u.name_ru from ipt_s_units u where u.code = t.unit_code) unit_name_ru,
  (select u.name_uz from ipt_s_units u where u.code = t.unit_code) unit_name_uz,
  t.vat_rate,
  (select f.site_code
     from ipt_s_filials f
    where f.code = nvl(t.phys_filial_code, t.filial_code)) site_code,
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

prompt 4.2 IPT_CATALOG_V

create or replace force view ipt_catalog_v as
select
  b.catalog_id id,
  min(b.model_code)         keep (dense_rank first order by b.product_id) model_code,
  min(b.model_name)         keep (dense_rank first order by b.product_id) model_name,
  min(b.model_name_uz)      keep (dense_rank first order by b.product_id) model_name_uz,
  min(b.category)           keep (dense_rank first order by b.product_id) category,
  min(b.brand)              keep (dense_rank first order by b.product_id) brand,
  min(b.condition)          keep (dense_rank first order by b.product_id) condition,
  min(b.price)              price,
  max(b.old_price)          old_price,
  min(b.sku)                keep (dense_rank first order by b.product_id) sku,
  min(b.storage_gb)         keep (dense_rank first order by b.product_id) storage_gb,
  min(b.ram_gb)             keep (dense_rank first order by b.product_id) ram_gb,
  min(b.color_code)         keep (dense_rank first order by b.product_id) color_code,
  min(b.color_name_ru)      keep (dense_rank first order by b.product_id) color_name_ru,
  min(b.color_name_uz)      keep (dense_rank first order by b.product_id) color_name_uz,
  min(b.warranty_months)    keep (dense_rank first order by b.product_id) warranty_months,
  min(b.description_ru)     keep (dense_rank first order by b.product_id) description_ru,
  min(b.description_uz)     keep (dense_rank first order by b.product_id) description_uz,
  min(b.battery_health_pct) keep (dense_rank first order by b.product_id) battery_health_pct,
  min(b.imei)               keep (dense_rank first order by b.product_id) imei,
  min(b.serial)             keep (dense_rank first order by b.product_id) serial,
  min(b.sim_type)           keep (dense_rank first order by b.product_id) sim_type,
  min(b.market_code)        keep (dense_rank first order by b.product_id) market_code,
  min(b.replaced_parts)     keep (dense_rank first order by b.product_id) replaced_parts,
  min(b.has_box)            keep (dense_rank first order by b.product_id) has_box,
  min(b.has_charger)        keep (dense_rank first order by b.product_id) has_charger,
  min(b.mxik_code)          keep (dense_rank first order by b.product_id) mxik_code,
  min(b.unit_code)          keep (dense_rank first order by b.product_id) unit_code,
  min(b.unit_name_ru)       keep (dense_rank first order by b.product_id) unit_name_ru,
  min(b.unit_name_uz)       keep (dense_rank first order by b.product_id) unit_name_uz,
  min(b.vat_rate)           keep (dense_rank first order by b.product_id) vat_rate,
  q.quantity_json,
  q.quantity_total,
  count(*)                  row_count,
  1                         is_active,
  max(b.updated_at)         updated_at
  from ipt_catalog_base_v b
  join ipt_catalog_qty_v q
    on q.catalog_id = b.catalog_id
 group by b.catalog_id, q.quantity_json, q.quantity_total
;

-- =============================================================================
-- 5. MA'LUMOTNOMALAR FORMASIGA BIRLIKLARNI QO'SHISH
--
-- ipt_dictionary.sql ishga tushirilmagan bo'lsa bu blok xato beradi —
-- o'tkazib yuboring.
-- =============================================================================

prompt 5.1 Ipt_Dictionary — birliklar

merge into ipt_s_dictionaries t
using (
  select 'units' code, 'IPT_S_UNITS' tab, 'Единицы измерения' nm_ru,
         'O''lchov birliklari' nm_uz, 'S' pk, 30 pl, 'CONDITION' st, 'ORD' oc,
         'Y' ins, 'Y' del, null lck, 75 ord from dual
) s
on (t.code = s.code)
when matched then
  update set t.table_name = s.tab, t.name_ru = s.nm_ru, t.name_uz = s.nm_uz,
             t.pk_type = s.pk, t.pk_max_len = s.pl, t.state_column = s.st,
             t.order_column = s.oc, t.can_insert = s.ins, t.can_delete = s.del,
             t.lock_reason = s.lck, t.ord = s.ord, t.condition = 'A'
when not matched then
  insert (code, table_name, name_ru, name_uz, pk_type, pk_max_len, state_column,
          order_column, can_insert, can_delete, lock_reason, ord, condition)
  values (s.code, s.tab, s.nm_ru, s.nm_uz, s.pk, s.pl, s.st, s.oc, s.ins,
          s.del, s.lck, s.ord, 'A');

prompt 5.2 Ipt_Dictionary — birliklar ustunlari

merge into ipt_s_dictionary_cols t
using (
  select 'units' d, 'NAME_RU' c, 'Название (ru)' nr, 'Nomi (ru)' nu, 'S' dt, 200 ml, 'Y' rq, null lov, 10 ord from dual union all
  select 'units', 'NAME_UZ',   'Название (uz)', 'Nomi (uz)', 'S', 200,  'N', null, 20 from dual union all
  select 'units', 'ORD',       'Порядок',       'Tartib',    'N', null, 'N', null, 30 from dual union all
  select 'units', 'CONDITION', 'Состояние',     'Holati',    'L', null, 'N', 'A:Faol;P:Nofaol', 40 from dual
) s
on (t.dict_code = s.d and t.column_name = s.c)
when matched then
  update set t.name_ru = s.nr, t.name_uz = s.nu, t.data_type = s.dt,
             t.max_len = s.ml, t.is_required = s.rq, t.lov = s.lov,
             t.ord = s.ord, t.condition = 'A'
when not matched then
  insert (dict_code, column_name, name_ru, name_uz, data_type, max_len,
          is_required, lov, ord, condition)
  values (s.d, s.c, s.nr, s.nu, s.dt, s.ml, s.rq, s.lov, s.ord, 'A');

commit;

-- =============================================================================
-- 6. RASM HAVOLASI PREFIKSI
--
-- Hozircha domen yo'q, IP va port bilan ishlaymiz.
--
-- DIQQAT: bu HTTP. Saytning o'zi HTTPS bo'lgani uchun brauzer HTTP rasmni
-- BLOKLAYDI va kartochka rasmsiz chiqadi. Vaqtincha yechim — sayt rasmni
-- o'z serveriga ko'chirib, o'zining HTTPS manzilidan bersin. Domen olingach
-- shu qator https ga o'zgartiriladi va muammo yo'qoladi.
-- =============================================================================

prompt 6.1 catalog_file_url

update core_properties
   set param_value = 'http://37.140.216.159:9999/api/app/get-file?file='
 where param_name = 'catalog_file_url';

commit;

-- =============================================================================
-- 7. TEKSHIRISH
--
--   select code, name_ru, name_uz from ipt_s_units_v;
--
--   select param_name, param_value from core_properties
--    where param_name = 'catalog_file_url';
--
-- Paketni qayta kompilyatsiya qilgandan keyin:
--
--   declare v clob;
--   begin
--     Ipt_Catalog.Get_Products('{"params":{"page":1,"per_page":1}}', v);
--     dbms_output.put_line(substr(v, 1, 4000));
--   end;
--   /
-- =============================================================================
