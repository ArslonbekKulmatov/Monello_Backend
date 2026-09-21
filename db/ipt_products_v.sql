-- =============================================================================
-- IPT_PRODUCTS_V — katalog maydonlari qo'shilgan
--
-- Mavjud view'ga 24 ta katalog ustuni va ularning nom tarjimalari qo'shildi.
-- Web mahsulot formasi va gridi shu view'dan o'qiydi: metodlar maydonlarni
-- YOZADI, lekin o'qish uchun view kerak edi.
--
-- Eski qismi TEGILMAGAN — ustunlar tartibi, filial filtri, order by va
-- izohga olingan blok o'z joyida. Yangi ustunlar oxiriga qo'shildi: biror
-- joyda %rowtype yoki pozitsion fetch ishlatilgan bo'lsa buzilmasligi uchun.
--
-- ISHGA TUSHIRISH: ipt_catalog_stage3.sql dan KEYIN
--
-- Muallif: Arslonbek Kulmatov
-- Sana   : 19.09.2026
-- =============================================================================

prompt IPT_PRODUCTS_V

create or replace view IPT_PRODUCTS_V as
Select
  t.id,
  t.name,
  t.type,
  t.price/100 price,
  /*(select nvl(s.price/100, 0)
     from ipt_product_sells s
    where s.product_id = t.id
   union
   select nvl(tr.product_new_price/100, 0)
     from ipt_trades tr
    where tr.product_id = t.id) new_price,*/
  nvl((select tr.product_new_price/100
         from ipt_trades tr
        where tr.product_id = t.id
         and tr.state not in ('06', '07')
         and rownum = 1), (select max(s.price/100)
                             from ipt_product_sells s
                            where s.product_id = t.id)) new_price,
  (select max(to_char(s.cr_on, 'dd.mm.yyyy'))
     from ipt_product_sells s
    where s.product_id = t.id) sold_date,
  t.investor_id,
  (select i.name
    from ipt_investors i
   where i.id = t.investor_id) investor_name,
  t.operation_id,
  t.state,
  (select s.name
     from ipt_s_product_states s
    where s.code = t.state) state_name,
  (select k.name
     from ipt_s_product_types k
    where k.code = t.type) type_name,
  t.quantity,
  t.quantity*t.price/100 total_price,
  t.cr_by,
  t.cr_on,
  to_char(t.cr_on, 'dd.mm.yyyy') created_on,
  t.up_by,
  t.up_on,
  to_char(t.up_on, 'dd.mm.yyyy') updated_on,
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
  -- Narxlar view'da SOMDA — bazada tiyinda yotadi. Mahsulot formasi ham
  -- somda yuboradi, ya'ni o'qish va yozish bir xil birlikda.
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
  -- View'dagi YAGONA qotirilgan yozuv: item_condition uchun ma'lumotnoma
  -- jadvali yo'q, u check constraint bilan cheklangan ('new' / 'used').
  -- Interfeys o'zbekcha bo'lsa shu ikki satrni almashtirish kifoya.
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
  -- Fizik joylashuv. Bo'sh bo'lsa hisob filiali hisoblanadi — ipt_catalog_v
  -- ham shunday qaraydi.
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
  -- replaced_parts vergul bilan ajratilgan ro'yxat: "screen,battery".
  -- Nomga o'girish uchun ma'lumotnomani ro'yxat ichidan qidiramiz.
  (select listagg(p.name_ru, ', ') within group (order by p.code)
     from ipt_s_replaced_parts p
    where t.replaced_parts is not null
      and ','||t.replaced_parts||',' like '%,'||p.code||',%') replaced_parts_name,
  -- Bazada 1/0 saqlanadi, forma esa true/false yuboradi
  t.has_box,
  t.has_charger,
  -- --- fiskal maydonlar (6-bosqich) ---
  t.mxik_code,
  t.unit_code,
  (select u.name_ru from ipt_s_units u where u.code = t.unit_code) unit_name,
  t.vat_rate,
  -- ===========================================================================
  -- SAYTGA CHIQADIMI
  --
  -- ipt_catalog_v ning yettita sharti bilan AYNAN bir xil. Gridda ko'rinsa,
  -- xodim qaysi tovar hali vitrinada yo'qligini darhol ko'radi.
  -- Keraksiz bo'lsa shu ikki ustunni olib tashlash mumkin — qolgani ishlaydi.
  -- ===========================================================================
  (select f.site_code
     from ipt_s_filials f
    where f.code = nvl(t.phys_filial_code, t.filial_code)) site_code,
  case when t.state = 'S'
        and nvl(t.quantity, 0) > 0
        and t.retail_price_uzs is not null
        and t.model_code       is not null
        and t.model_name       is not null
        and t.category_code    is not null
        and t.brand_code       is not null
        and t.item_condition   is not null
        and (select f.site_code
               from ipt_s_filials f
              where f.code = nvl(t.phys_filial_code, t.filial_code)) is not null
       then 'Y' else 'N'
  end in_catalog
  From ipt_products t
  where t.filial_code = core_session.Get_Filial_Code
   --and t.cr_by = decode(ipt_util.Has_Access_For_Role(21), 0, t.cr_by, core_session.Get_User_Id)
  order by Decode(t.state, 'S', 1, 'K', 2,  'P', 3), t.id desc
;


-- =============================================================================
-- TEKSHIRISH
--
--   select id, name, model_code, retail_price_uzs, category_name, brand_name,
--          item_condition_name, site_code, in_catalog
--     from ipt_products_v
--    where rownum <= 20;
--
-- in_catalog = 'N' bo'lgan qatorlar saytga chiqmaydi. Nimasi yetishmayotgani
-- ipt_catalog_todo_v da maydon-maydon ko'rsatilgan.
--
-- Nazorat: ikkala raqam teng bo'lishi kerak (joriy filial bo'yicha)
--
--   select count(*) from ipt_products_v where in_catalog = 'Y';
--   select count(*) from ipt_catalog_v c
--    where exists (select 1 from ipt_products p
--                   where p.id = c.id
--                     and p.filial_code = core_session.Get_Filial_Code);
-- =============================================================================
