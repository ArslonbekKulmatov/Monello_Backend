-- =============================================================================
-- IPT_PRODUCTS_HIS_V — katalog maydonlari qo'shilgan
--
-- ipt_products_v ga qo'shilgan 24 ta ustunning tarix ko'rinishidagi juftligi.
-- Ustunlar IPT_PRODUCTS_HIS da allaqachon bor (stage1 va stage3 dagi ALTER),
-- Product_His ularni yozadi ham — faqat view'da ko'rinmayotgan edi.
--
-- Shu qilinmasa "kim narxni o'zgartirdi" degan savolga javob yo'q: tarixda
-- yozuv bor, lekin ekranda ko'rinmaydi.
--
-- Eski qismi TEGILMAGAN. Yangi ustunlar oxiriga qo'shildi.
--
-- ISHGA TUSHIRISH: ipt_catalog_stage3.sql dan KEYIN
--
-- Muallif: Arslonbek Kulmatov
-- Sana   : 19.09.2026
-- =============================================================================

prompt IPT_PRODUCTS_HIS_V

create or replace view IPT_PRODUCTS_HIS_V as
Select
  t.id,
  t.name,
  t.type,
  t.price/100 price,
  t.investor_id,
  (select i.name
    from ipt_investors i
   where i.id = t.investor_id
   union
   select i.name
    from ipt_investors_his i
   where i.id = t.investor_id) investor_name,
  t.operation_id,
  t.state,
  (select s.name
     from ipt_s_product_states s
    where s.code = t.state) state_name,
  t.cr_by,
  t.cr_on,
  to_char(t.cr_on, 'dd.mm.yyyy') created_on,
  t.up_by,
  t.up_on,
  to_char(t.up_on, 'dd.mm.yyyy') updated_on,
  decode(t.Action,
         'U',
         'Изменённый',
         'D',
         'Удалено',
         'Вставлено')||' - '||(select u.last_name||' '||u.first_name||' '||u.patronymic_name
                                 from core_users u
                                where u.user_id = t.action_by)||' - '||to_char(t.action_on, 'dd.mm.yyyy hh24:mi:ss') action,
  t.provider,
  t.car_type,
  (Select k.name From ipt_car_types_r k where k.code = t.car_type) car_type_name,
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
  t.car_expense_amount/100 car_expense_amount,
  t.car_expense_details,
  t.car_market_price_min_max,
  to_char(t.car_purchase_date, 'dd.mm.yyyy') car_purchase_date,
  t.car_tuning_details,
  t.car_paint_condition,
  t.car_price/100 car_price,
  -- ===========================================================================
  -- KATALOG MAYDONLARI (sayt uchun)
  --
  -- ipt_products_v dagi bilan bir xil tartib va bir xil nomlar, shunda ikki
  -- ekranni yonma-yon qo'yib solishtirish mumkin.
  --
  -- Nom ustunlari JORIY ma'lumotnomadan olinadi: tarixda kod saqlanadi,
  -- nom emas. Kod keyin nomi o'zgartirilsa tarixda yangi nom ko'rinadi.
  -- Bu view'dagi state_name va car_type_name ham xuddi shunday ishlaydi.
  --
  -- Ma'lumotnoma qatorlari o'chirilmaydi, condition = 'P' ga o'tkaziladi —
  -- shuning uchun lookup'larda condition filtri ataylab YO'Q: nofaol
  -- kategoriya ham tarixda nomi bilan ko'rinishi kerak.
  -- ===========================================================================
  t.model_code,
  t.model_name,
  t.model_name_uz,
  t.retail_price_uzs/100 retail_price_uzs,
  t.old_price_uzs/100    old_price_uzs,
  t.sku,
  t.category_code,
  (select c.name_ru
     from ipt_s_categories c
    where c.code = t.category_code) category_name,
  t.brand_code,
  (select b.name
     from ipt_s_brands b
    where b.code = t.brand_code) brand_name,
  t.item_condition,
  case t.item_condition
    when 'new'  then 'Новый'
    when 'used' then 'Б/у'
  end item_condition_name,
  t.color_code,
  (select c.name_ru
     from ipt_s_colors c
    where c.code = t.color_code) color_name,
  t.storage_gb,
  t.ram_gb,
  t.warranty_months,
  t.description_ru,
  t.description_uz,
  t.phys_filial_code,
  (select f.name
     from ipt_s_filials f
    where f.code = t.phys_filial_code) phys_filial_name,
  -- --- ishlatilgan texnika ---
  t.battery_health_pct,
  t.imei,
  t.serial,
  t.sim_type,
  (select s.name
     from ipt_s_sim_types s
    where s.code = t.sim_type) sim_type_name,
  t.market_code,
  (select m.name
     from ipt_s_market_codes m
    where m.code = t.market_code) market_code_name,
  t.replaced_parts,
  (select listagg(p.name_ru, ', ') within group (order by p.code)
     from ipt_s_replaced_parts p
    where t.replaced_parts is not null
      and ','||t.replaced_parts||',' like '%,'||p.code||',%') replaced_parts_name,
  t.has_box,
  t.has_charger,
  -- --- fiskal maydonlar (6-bosqich) ---
  t.mxik_code,
  t.unit_code,
  (select u.name_ru from ipt_s_units u where u.code = t.unit_code) unit_name,
  t.vat_rate
  -- site_code va in_catalog ATAYLAB yo'q: ular joriy holatni ko'rsatadi,
  -- tarix esa o'sha paytdagi qiymatlarni. Tarix qatorida "hozir saytda bormi"
  -- degan ustun chalg'itadi — ipt_products_v da qarash kerak.
  From ipt_products_his t
  order by t.action_on desc;


-- =============================================================================
-- TEKSHIRISH
--
-- Bitta tovarning katalog maydonlari bo'yicha o'zgarishlar tarixi:
--
--   select action, model_code, model_name, retail_price_uzs, category_name,
--          brand_name, item_condition_name, color_name
--     from ipt_products_his_v
--    where id = ?
--    order by up_on desc nulls last;
--
-- Narx qachon va kim tomonidan o'zgargani shu yerdan ko'rinadi.
-- =============================================================================
