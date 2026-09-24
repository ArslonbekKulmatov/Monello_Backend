-- =============================================================================
-- IPT KATALOG — 5-BOSQICH: id ni birlashtirish
--
-- Sayt jamoasining 21.09.2026 dagi javobi, 3-band:
--   "Yangi pozitsiyalarni birlashtiring, ishlatilganlarni — yo'q."
--
-- NEGA
--   Yangi tovarda xaridor KONFIGURATSIYANI tanlaydi: bir xil ikki xarid —
--   bu 2 dona, ikkita kartochka emas. Ishlatilganda esa o'z IMEI va
--   batareyasiga ega ANIQ apparat, uni birlashtirib bo'lmaydi.
--
-- ID QANDAY YASALADI
--   Yangi tovar : model_code ~ storage_gb ~ ram_gb ~ color_code
--                 masalan  iphone-17-pro-max~256~x~silver
--   Ishlatilgan : ombor qatorining id'si, masalan  104721
--
--   Ajratgich "~" ataylab: model_code ichida "-" bor, shuning uchun "-"
--   bilan ajratsak qism chegarasini topib bo'lmaydi.
--   Bo'sh maydon o'rniga "x" qo'yiladi — aks holda ikkita bo'sh maydon
--   qo'shni bo'lib, turli konfiguratsiyalar bir xil id olardi.
--
-- MUHIM: id KONFIGURATSIYADAN yasaladi, ya'ni model_code, xotira, ram yoki
-- rang o'zgarsa id ham o'zgaradi. Bu tabiiy — boshqa konfiguratsiya boshqa
-- kartochka. Lekin xatoni tuzatish (masalan model_code dagi xato) sayt
-- tomonida yangi kartochka bo'lib ko'rinadi. Shuning uchun model_code ni
-- to'ldirishdan oldin sayt bilan kelishib oling.
--
-- NARX
--   Bir konfiguratsiyaning ikki qatorida narx har xil bo'lsa — ENG PASTI
--   olinadi. Sabab: e'lon qilingan narxni pasaytirib bo'lmaydi, ko'tarib
--   ham bo'lmaydi; eng pastini ko'rsatish har doim bajarib bo'ladigan
--   va'da. Narxlar farq qilishi odatda xato, shuning uchun 4-bo'limdagi
--   tekshiruv so'rovini vaqti-vaqti bilan bajarib turing.
--
-- TAVSIFIY MAYDONLAR
--   Guruhdagi eng kichik id'li qator VAKIL bo'ladi va sku, kafolat, tavsif
--   kabi maydonlar undan olinadi. Har maydonni alohida min() qilish mumkin
--   emas edi: u holda sku bir qatordan, tavsif boshqasidan kelib, mavjud
--   bo'lmagan tovar yasalardi.
--
-- ISHGA TUSHIRISH: ipt_catalog_stage4.sql dan keyin.
-- Keyin ipt_catalog_package.sql ni QAYTA kompilyatsiya qiling.
--
-- Muallif: Arslonbek Kulmatov
-- Sana   : 21.09.2026
-- =============================================================================

prompt 1.1 IPT_CATALOG_BASE_V — qator darajasi va katalog kaliti

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

prompt 1.2 IPT_CATALOG_QTY_V — shourumlar bo'yicha qoldiq

-- Ikki bosqich: avval (katalog elementi, shourum) bo'yicha yig'iladi, keyin
-- element bo'yicha JSON qilinadi. Bitta bosqichda qilib bo'lmaydi —
-- json_objectagg ichiga sum() ni joylab bo'lmaydi.
create or replace force view ipt_catalog_qty_v as
select q.catalog_id,
       json_objectagg(key q.site_code value q.quantity returning varchar2(4000)) quantity_json,
       sum(q.quantity) quantity_total
  from (select b.catalog_id,
               b.site_code,
               sum(nvl(b.quantity, 0)) quantity
          from ipt_catalog_base_v b
         group by b.catalog_id, b.site_code) q
 group by q.catalog_id
;

prompt 1.3 IPT_CATALOG_V — sayt ko'radigan katalog

create or replace force view ipt_catalog_v as
select
  b.catalog_id id,
  min(b.model_code)         keep (dense_rank first order by b.product_id) model_code,
  min(b.model_name)         keep (dense_rank first order by b.product_id) model_name,
  min(b.model_name_uz)      keep (dense_rank first order by b.product_id) model_name_uz,
  min(b.category)           keep (dense_rank first order by b.product_id) category,
  min(b.brand)              keep (dense_rank first order by b.product_id) brand,
  min(b.condition)          keep (dense_rank first order by b.product_id) condition,
  -- Narx: eng pasti. Sabab yuqoridagi izohda.
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
  q.quantity_json,
  q.quantity_total,
  -- Nechta ombor qatori birlashtirilgani. API'ga chiqmaydi, ichki
  -- tekshiruv uchun: kutilmagan katta son ko'rsatkich bo'ladi.
  count(*)                  row_count,
  1                         is_active,
  max(b.updated_at)         updated_at
  from ipt_catalog_base_v b
  join ipt_catalog_qty_v q
    on q.catalog_id = b.catalog_id
 group by b.catalog_id, q.quantity_json, q.quantity_total
;

-- =============================================================================
-- 2. TEKSHIRISH
--
-- 2.1 Nechta ombor qatori nechta katalog elementiga aylandi:
--
--   select count(*) qatorlar from ipt_catalog_base_v;
--   select count(*) elementlar from ipt_catalog_v;
--
-- 2.2 Eng ko'p birlashgan elementlar:
--
--   select id, model_code, storage_gb, color_code, row_count, quantity_total
--     from ipt_catalog_v
--    where row_count > 1
--    order by row_count desc fetch first 20 rows only;
--
-- 2.3 Ishlatilgan texnika birlashmaganini tekshirish — nol chiqishi kerak:
--
--   select count(*) xato from ipt_catalog_v
--    where condition = 'used' and row_count > 1;
--
-- =============================================================================
-- 3. QO'LDA TEKSHIRILADIGAN NARSA: bir konfiguratsiyada har xil narx
--
-- Katalogda eng past narx ko'rsatiladi. Quyidagi so'rov farq bor
-- elementlarni chiqaradi — ro'yxat bo'sh bo'lishi kerak.
-- =============================================================================

prompt 3.1 Bir konfiguratsiyada har xil narx

select b.catalog_id,
       count(distinct b.price) narxlar_soni,
       min(b.price) eng_past,
       max(b.price) eng_baland
  from ipt_catalog_base_v b
 where b.condition = 'new'
 group by b.catalog_id
having count(distinct b.price) > 1
 order by max(b.price) - min(b.price) desc;
