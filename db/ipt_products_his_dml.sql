-- =============================================================================
-- IPT_METHODS_DML.PRODUCT_HIS — ustunlar aniq sanab o'tiladi
--
-- NEGA QAYTA YOZILDI
--   Eski variant pozitsion insert edi: "insert into ipt_products_his select ...".
--   62 ustunli jadvalda bu juda mo'rt — jadvalga qayerdadir bitta ustun
--   qo'shilsa, insert ORA-00947 bilan yiqiladi, yoki bundan ham yomoni,
--   ustunlar siljib ma'lumot boshqa joyga tushadi va buni hech kim sezmaydi.
--
--   Endi ustunlar aniq sanab o'tilgan. Jadvalda qo'shimcha ustun bo'lsa u
--   NULL qoladi va insert ishlayveradi.
--
-- ISHGA TUSHIRISH: ipt_catalog_stage6.sql dan keyin. Bu fayl stage6 dagi
-- Product_His ni ALMASHTIRADI — stage6 ni qayta bajarmang.
--
-- Muallif: Arslonbek Kulmatov
-- Sana   : 21.09.2026
-- =============================================================================

prompt IPT_METHODS_DML

create or replace package body Ipt_Methods_Dml is

  --Cr By: Arslonbek
  --Product his
  Procedure Product_His(p_Product_Id number, p_Action varchar2)
  is
  begin
    insert into ipt_products_his
    (
      id, name, type, price,
      investor_id, state, cr_by, cr_on,
      up_by, up_on, operation_id, filial_code,
      action, action_by, action_on, provider,
      quantity, car_type, car_plate_number, car_production_year,
      car_color, car_tech_passport_number, car_body_number, car_engine_number,
      car_mileage, car_owner_name, car_gen_trust_name, car_register_name,
      car_expense_amount, car_expense_details, car_market_price_min_max, car_purchase_date,
      car_tuning_details, car_paint_condition, car_price, retail_price_uzs,
      model_code, model_name, category_code, brand_code,
      item_condition, phys_filial_code, storage_gb, ram_gb,
      color_code, sku, old_price_uzs, warranty_months,
      model_name_uz, description_ru, description_uz, battery_health_pct,
      imei, serial, sim_type, market_code,
      replaced_parts, has_box, has_charger, mxik_code,
      unit_code, vat_rate
    )
    select
      t.id, t.name, t.type, t.price,
      t.investor_id, t.state, t.cr_by, t.cr_on,
      t.up_by, t.up_on, t.operation_id, t.filial_code,
      p_Action, core_session.Get_User_Id, sysdate, t.provider,
      t.quantity, t.car_type, t.car_plate_number, t.car_production_year,
      t.car_color, t.car_tech_passport_number, t.car_body_number, t.car_engine_number,
      t.car_mileage, t.car_owner_name, t.car_gen_trust_name, t.car_register_name,
      t.car_expense_amount, t.car_expense_details, t.car_market_price_min_max, t.car_purchase_date,
      t.car_tuning_details, t.car_paint_condition, t.car_price, t.retail_price_uzs,
      t.model_code, t.model_name, t.category_code, t.brand_code,
      t.item_condition, t.phys_filial_code, t.storage_gb, t.ram_gb,
      t.color_code, t.sku, t.old_price_uzs, t.warranty_months,
      t.model_name_uz, t.description_ru, t.description_uz, t.battery_health_pct,
      t.imei, t.serial, t.sim_type, t.market_code,
      t.replaced_parts, t.has_box, t.has_charger, t.mxik_code,
      t.unit_code, t.vat_rate
      from ipt_products t
     where t.id = p_Product_Id;
  end;

end Ipt_Methods_Dml;
/

-- =============================================================================
-- TEKSHIRISH
--
-- Jadvalda nechta ustun bor va yuqoridagi ro'yxatdan qaysi biri tushib
-- qolgan:
--
--   select column_id, column_name
--     from user_tab_columns
--    where table_name = 'IPT_PRODUCTS_HIS'
--    order by column_id;
--
-- Ro'yxatda YO'Q ustun chiqsa — u endi NULL bilan to'ladi. Agar unga
-- qiymat yozilishi kerak bo'lsa, yuqoridagi ikkala ro'yxatga ham qo'shing.
-- =============================================================================
