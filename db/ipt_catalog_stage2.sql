-- =============================================================================
-- IPT KATALOG API — 2-BOSQICH: paket va metodlar
--
-- 1-bosqich (db/ipt_catalog_stage1.sql) ishga tushirilgan bo'lishi shart.
--
-- Bu yerda:
--   1. CORE_API_TOKENS  — tashqi tizimlar uchun doimiy token
--   2. IPT_CATALOG      — katalog va qoldiq metodlari
--   3. CORE_METHODS     — metodlarni ro'yxatga olish
--
-- Muallif: Arslonbek Kulmatov
-- Sana   : 13.09.2026
-- =============================================================================


-- =============================================================================
-- 1. TOKENLAR JADVALI
--
-- Sayt doimiy token so'raydi (talablar hujjati 9-bo'lim), JWT esa 24 soatda
-- tugaydi va bekor qilib bo'lmaydi. Shuning uchun alohida jadval.
--
-- Token OCHIQ SAQLANMAYDI — faqat SHA-256 xesh. Bazani ko'rgan odam ham
-- tokenni tiklay olmaydi.
-- =============================================================================

prompt 1.1 CORE_API_TOKENS

create table CORE_API_TOKENS
(
  id         NUMBER(10) not null,
  name       VARCHAR2(200) not null,
  token_hash VARCHAR2(64) not null,
  user_id    NUMBER(10) not null,
  condition  VARCHAR2(2) default 'A' not null,
  cr_by      NUMBER(10),
  cr_on      DATE,
  up_by      NUMBER(10),
  up_on      DATE
)
;
comment on table CORE_API_TOKENS
  is 'Tashqi tizimlar uchun doimiy API tokenlari. Token ochiq saqlanmaydi';
comment on column CORE_API_TOKENS.name
  is 'Token kimga berilgani: "ABM Store sayti", "ABM Store sayti (test)"';
comment on column CORE_API_TOKENS.token_hash
  is 'Tokenning SHA-256 xeshi, kichik harfli hex. Java tomonda ham shunday hisoblanadi';
comment on column CORE_API_TOKENS.user_id
  is 'Token qaysi core_users nomidan ishlaydi — loglar va sessiya shu foydalanuvchiga yoziladi';
comment on column CORE_API_TOKENS.condition
  is 'A - active; P - passive. Tokenni bekor qilish uchun P ga o''tkaziladi';

alter table CORE_API_TOKENS
  add constraint CORE_API_TOKENS_PK primary key (ID);
alter table CORE_API_TOKENS
  add constraint CORE_API_TOKENS_HASH_UK unique (TOKEN_HASH);
alter table CORE_API_TOKENS
  add constraint CORE_API_TOKENS_USER_FK foreign key (USER_ID)
  references CORE_USERS (USER_ID);
alter table CORE_API_TOKENS
  add constraint CORE_API_TOKENS_COND_CHK
  check (condition in ('A', 'P'));


-- =============================================================================
-- 2. IPT_CATALOG PAKETI
-- =============================================================================

prompt 2.1 Ipt_Catalog — spetsifikatsiya

create or replace package Ipt_Catalog is

  -- Author  : Arslonbek Kulmatov
  -- Created : 13.09.2026
  -- Purpose : ABM Store sayti uchun katalog API

  --Cr By: Arslonbek Kulmatov
  --To'liq katalog, sahifalab
  Procedure Get_Products(iParams clob, oResponse out clob);

  --Cr By: Arslonbek Kulmatov
  --Faqat narx va qoldiq — tez-tez so'raladigan yengil metod
  Procedure Get_Stock(iParams clob, oResponse out clob);

  --Cr By: Arslonbek Kulmatov
  --Katalog maydonlarini to'ldirish (ichki, operatorlar uchun)
  Procedure Save_Product(iParams clob, oResponse out clob);

end Ipt_Catalog;
/


prompt 2.2 Ipt_Catalog — tanasi

create or replace package body Ipt_Catalog is

  -- Sahifa hajmi chegaralari. Sayt 100-500 oralig'ini so'ragan.
  cMax_Per_Page constant number := 500;

  --Cr By: Arslonbek Kulmatov
  --Parametrlar obyekti. Tizimdagi barcha metodlar kabi {"method":..,"params":{..}}
  --ko'rinishida keladi; "params" bo'lmasa bo'sh obyekt qaytadi, chunki
  --get_Number null obyektda xato beradi.
  Function Get_Params(iParams clob) return json_object_t
  is
    vJson   json_object_t := json_object_t.parse(iParams);
    vParams json_object_t;
  begin
    if vJson.has('params') then
      vParams := vJson.get_Object('params');
    end if;

    if vParams is null then
      vParams := json_object_t();
    end if;

    return vParams;
  end;

  --Cr By: Arslonbek Kulmatov
  --Vitrina shourum kodlari ro'yxati
  Function Get_Site_Codes return json_array_t
  is
    vSites json_array_t := json_array_t();
  begin
    for rows in (select distinct f.site_code
                   from ipt_s_filials f
                  where f.site_code is not null
                    and f.condition = 'A'
                  order by 1)
    loop
      vSites.append(rows.site_code);
    end loop;

    return vSites;
  end;

  --Cr By: Arslonbek Kulmatov
  --quantity obyektini yig'ish: {"mirobod": 2, "sebzor": 0}
  --
  --Qatorlar hozircha yopishtirilmagani uchun har bir tovar bitta shourumga
  --tegishli. Qolgan shourumlarga 0 qo'yiladi — sayt tomonda obyekt shakli
  --doim bir xil bo'lishi uchun.
  Function Build_Quantity(iSites json_array_t,
                          iSite  varchar2,
                          iQty   number) return json_object_t
  is
    vQty  json_object_t := json_object_t();
    vCode varchar2(30);
  begin
    for i in 0 .. iSites.get_size - 1
    loop
      vCode := iSites.get_string(i);
      vQty.put(vCode, case when vCode = iSite then nvl(iQty, 0) else 0 end);
    end loop;

    return vQty;
  end;

  --Cr By: Arslonbek Kulmatov
  --ISO-8601 sanani server vaqtiga o'girish: 2026-08-27T10:00:00Z
  Function Parse_Iso_Date(iValue varchar2) return date
  is
    vTxt varchar2(100) := trim(iValue);
  begin
    if vTxt is null then
      return null;
    end if;

    -- 'Z' UTC degani, to_timestamp_tz esa raqamli smeshcheniyeni kutadi
    vTxt := replace(upper(vTxt), 'Z', '+00:00');

    return cast(to_timestamp_tz(vTxt, 'YYYY-MM-DD"T"HH24:MI:SSTZH:TZM') at local as date);
  exception
    when others then
      Ipt_Methods.Raise_Error('"updated_since" formati noto''g''ri. '||
                              'Kutilgan format: 2026-08-27T10:00:00Z');
  end;

  --Cr By: Arslonbek Kulmatov
  --Sanani ISO-8601 ko'rinishida qaytarish, server smeshcheniyesi bilan
  Function To_Iso(iDate date) return varchar2
  is
  begin
    if iDate is null then
      return null;
    end if;

    return to_char(from_tz(cast(iDate as timestamp), sessiontimezone),
                   'YYYY-MM-DD"T"HH24:MI:SSTZH:TZM');
  end;

  --Cr By: Arslonbek Kulmatov
  --To'liq katalog, sahifalab
  Procedure Get_Products(iParams clob, oResponse out clob)
  is
    vParams   json_object_t := Get_Params(iParams);
    vResponse json_object_t := json_object_t();
    vItems    json_array_t  := json_array_t();
    vItem     json_object_t;
    vSites    json_array_t  := Get_Site_Codes;
    vPage     number;
    vPerPage  number;
    vSince    date;
    vTotal    number;
    vOffset   number;
  begin
    vPage    := nvl(vParams.get_Number('page'), 1);
    vPerPage := nvl(vParams.get_Number('per_page'), 200);

    if vPage < 1 then
      Ipt_Methods.Raise_Error('"page" 1 dan kichik bo''lishi mumkin emas.');
    end if;

    if vPerPage < 1 or vPerPage > cMax_Per_Page then
      Ipt_Methods.Raise_Error('"per_page" 1 va '||cMax_Per_Page||' oralig''ida bo''lishi kerak.');
    end if;

    if vParams.has('updated_since') then
      vSince := Parse_Iso_Date(vParams.get_String('updated_since'));
    end if;

    vOffset := (vPage - 1) * vPerPage;

    select count(*) into vTotal
      from ipt_catalog_v t
     where vSince is null
        or t.updated_at > vSince;

    -- order by id — sahifalash barqaror bo'lishi uchun majburiy
    for rows in (select t.id,
                        t.model_code,
                        t.model_name,
                        t.category,
                        t.brand,
                        t.condition,
                        t.price,
                        t.quantity,
                        t.site_code,
                        t.updated_at
                   from ipt_catalog_v t
                  where vSince is null
                     or t.updated_at > vSince
                  order by t.id
                 offset vOffset rows fetch next vPerPage rows only)
    loop
      vItem := json_object_t();
      vItem.put('id', to_char(rows.id));
      vItem.put('model_code', rows.model_code);
      vItem.put('model_name', rows.model_name);
      vItem.put('category', rows.category);
      vItem.put('brand', rows.brand);
      vItem.put('condition', rows.condition);
      vItem.put('price', round(rows.price));
      vItem.put('quantity', Build_Quantity(vSites, rows.site_code, rows.quantity));
      vItem.put('is_active', true);
      vItem.put('updated_at', To_Iso(rows.updated_at));
      vItems.append(vItem);
    end loop;

    vResponse.put('total', vTotal);
    vResponse.put('page', vPage);
    vResponse.put('per_page', vPerPage);
    vResponse.put('items', vItems);

    -- To_String EMAS: u varchar2 qaytaradi va 32 KB da uziladi.
    -- 200 ta tovar bemalol undan oshadi.
    oResponse := vResponse.to_clob();
  end;

  --Cr By: Arslonbek Kulmatov
  --Faqat narx va qoldiq
  Procedure Get_Stock(iParams clob, oResponse out clob)
  is
    vResponse json_object_t := json_object_t();
    vItems    json_array_t  := json_array_t();
    vItem     json_object_t;
    vSites    json_array_t  := Get_Site_Codes;
  begin
    for rows in (select t.id,
                        t.price,
                        t.quantity,
                        t.site_code
                   from ipt_catalog_v t
                  order by t.id)
    loop
      vItem := json_object_t();
      vItem.put('id', to_char(rows.id));
      vItem.put('price', round(rows.price));
      vItem.put('quantity', Build_Quantity(vSites, rows.site_code, rows.quantity));
      vItems.append(vItem);
    end loop;

    vResponse.put('updated_at', To_Iso(sysdate));
    vResponse.put('items', vItems);

    oResponse := vResponse.to_clob();
  end;

  --Cr By: Arslonbek Kulmatov
  --Katalog maydonlarini to'ldirish
  --
  --Product_Action ga ataylab tegilmadi: u investor saldosini debetlaydi,
  --refund qiladi va balans loglarini yozadi. Katalog maydonlari esa pulga
  --umuman aloqador emas — ikkalasini bitta protsedurada aralashtirish
  --xavfli va keraksiz.
  --
  --"ids" massiv, chunki bitta model bo'yicha o'nlab qator bir xil
  --model_code / category_code / brand_code oladi (yuklamada "iPhone 16 Pro
  --Max" 34 marta uchraydi) — ularni bittalab tahrirlash ma'nosiz.
  --
  --FAQAT kelgan maydonlar yangilanadi. Kelmagan maydon NULL bilan
  --ustidan yozilmaydi — aks holda eski frontend har saqlashda katalog
  --ma'lumotini o'chirib yuborardi.
  --
  --retail_price_uzs SOMDA keladi (tiyinsiz), bazada tiyinda saqlanadi.
  Procedure Save_Product(iParams clob, oResponse out clob)
  is
    vParams       json_object_t := Get_Params(iParams);
    vResponse     json_object_t := json_object_t();
    vIds          json_array_t;
    vSession_User number := core_session.Get_User_Id;
    vId           number;
    vCount        pls_integer;
    vUpdated      pls_integer := 0;

    vModel_Code varchar2(200);
    vModel_Name varchar2(1000);
    vCategory   varchar2(30);
    vBrand      varchar2(30);
    vCondition  varchar2(10);
    vPhys_Fil   varchar2(10);
    vPrice      number;

    -- SQL ichida ishlatilgani uchun boolean EMAS
    vHas_Model_Code varchar2(1) := case when vParams.has('model_code')       then 'Y' else 'N' end;
    vHas_Model_Name varchar2(1) := case when vParams.has('model_name')       then 'Y' else 'N' end;
    vHas_Category   varchar2(1) := case when vParams.has('category_code')    then 'Y' else 'N' end;
    vHas_Brand      varchar2(1) := case when vParams.has('brand_code')       then 'Y' else 'N' end;
    vHas_Condition  varchar2(1) := case when vParams.has('item_condition')   then 'Y' else 'N' end;
    vHas_Phys_Fil   varchar2(1) := case when vParams.has('phys_filial_code') then 'Y' else 'N' end;
    vHas_Price      varchar2(1) := case when vParams.has('retail_price_uzs') then 'Y' else 'N' end;
  begin
    Ipt_Methods.Check_For_Seller;

    if not vParams.has('ids') then
      Ipt_Methods.Raise_Error('"ids" ko''rsatilmagan.');
    end if;

    vIds := vParams.get_Array('ids');

    if vIds.get_size = 0 then
      Ipt_Methods.Raise_Error('"ids" bo''sh bo''lishi mumkin emas.');
    end if;

    if vHas_Model_Code  = 'N' and vHas_Model_Name = 'N' and vHas_Category = 'N'
       and vHas_Brand   = 'N' and vHas_Condition = 'N' and vHas_Phys_Fil = 'N'
       and vHas_Price   = 'N' then
      Ipt_Methods.Raise_Error('Yangilash uchun birorta ham maydon berilmagan.');
    end if;

    -- Qiymatlarni o'qish va tekshirish: sikldan OLDIN, bir marta
    if vHas_Model_Code = 'Y' then
      vModel_Code := lower(trim(vParams.get_String('model_code')));

      if vModel_Code is not null and not regexp_like(vModel_Code, '^[a-z0-9]+(-[a-z0-9]+)*$') then
        Ipt_Methods.Raise_Error('"model_code" faqat kichik lotin harflari, raqam va "-" dan iborat bo''lishi kerak: iphone-16-pro-max');
      end if;
    end if;

    if vHas_Model_Name = 'Y' then
      vModel_Name := trim(vParams.get_String('model_name'));
    end if;

    if vHas_Category = 'Y' then
      vCategory := trim(vParams.get_String('category_code'));

      if vCategory is not null then
        select count(*) into vCount
          from ipt_s_categories c
         where c.code = vCategory
           and c.condition = 'A';

        if vCount = 0 then
          Ipt_Methods.Raise_Error('Bunday kategoriya yo''q yoki faol emas: '||vCategory);
        end if;
      end if;
    end if;

    if vHas_Brand = 'Y' then
      vBrand := trim(vParams.get_String('brand_code'));

      if vBrand is not null then
        select count(*) into vCount
          from ipt_s_brands b
         where b.code = vBrand
           and b.condition = 'A';

        if vCount = 0 then
          Ipt_Methods.Raise_Error('Bunday brend yo''q yoki faol emas: '||vBrand);
        end if;
      end if;
    end if;

    if vHas_Condition = 'Y' then
      vCondition := lower(trim(vParams.get_String('item_condition')));

      if vCondition is not null and vCondition not in ('new', 'used') then
        Ipt_Methods.Raise_Error('"item_condition" faqat "new" yoki "used" bo''ladi.');
      end if;
    end if;

    if vHas_Phys_Fil = 'Y' then
      vPhys_Fil := trim(vParams.get_String('phys_filial_code'));

      if vPhys_Fil is not null then
        select count(*) into vCount
          from ipt_s_filials f
         where f.code = vPhys_Fil;

        if vCount = 0 then
          Ipt_Methods.Raise_Error('Bunday filial yo''q: '||vPhys_Fil);
        end if;
      end if;
    end if;

    if vHas_Price = 'Y' then
      vPrice := round(vParams.get_Number('retail_price_uzs'), 2) * 100;

      if vPrice is not null and vPrice <= 0 then
        Ipt_Methods.Raise_Error('"retail_price_uzs" 0 dan katta bo''lishi kerak.');
      end if;
    end if;

    for i in 0 .. vIds.get_size - 1
    loop
      vId := vIds.get_Number(i);

      select count(*) into vCount
        from ipt_products p
       where p.id = vId;

      if vCount = 0 then
        Ipt_Methods.Raise_Error('Bunday tovar yo''q: '||vId);
      end if;

      update ipt_products t
         set t.model_code       = case when vHas_Model_Code = 'Y' then vModel_Code else t.model_code end,
             t.model_name       = case when vHas_Model_Name = 'Y' then vModel_Name else t.model_name end,
             t.category_code    = case when vHas_Category   = 'Y' then vCategory   else t.category_code end,
             t.brand_code       = case when vHas_Brand      = 'Y' then vBrand      else t.brand_code end,
             t.item_condition   = case when vHas_Condition  = 'Y' then vCondition  else t.item_condition end,
             t.phys_filial_code = case when vHas_Phys_Fil   = 'Y' then vPhys_Fil   else t.phys_filial_code end,
             t.retail_price_uzs = case when vHas_Price      = 'Y' then vPrice      else t.retail_price_uzs end,
             t.up_by            = vSession_User,
             t.up_on            = sysdate
       where t.id = vId;

      vUpdated := vUpdated + sql%rowcount;

      Ipt_Methods_Dml.Product_His(p_Product_Id => vId, p_Action => 'U');
    end loop;

    vResponse.put('oper', true);
    vResponse.put('updated', vUpdated);
    vResponse.put('message', vUpdated||' ta tovar yangilandi.');

    oResponse := vResponse.to_clob();
  end;

end Ipt_Catalog;
/


-- =============================================================================
-- 3. METODLARNI RO'YXATGA OLISH
--
-- O'qish metodlarida add_log = 'N': katalog soatiga bir marta, qoldiq esa
-- 5 daqiqada bir marta so'raladi, loglasak core_api_log keraksiz to'lib ketadi.
-- catalogSaveProduct esa ma'lumotni o'zgartiradi va kam chaqiriladi — u loglanadi.
--
-- catalogProducts va catalogStock tashqariga, /api/catalog/* orqali chiqadi.
-- catalogSaveProduct — ichki metod, oddiy /api/app/request/v2 orqali,
-- JWT bilan ishlaydi va tokenga aloqasi yo'q.
--
-- Metodni vaqtincha o'chirish kerak bo'lsa: state = 'P'.
-- =============================================================================

prompt 3.1 core_methods

-- seq kerak: bitta MERGE ichida max(id) hamma qator uchun bir xil o'qiladi,
-- shuning uchun "+1" ikkala yangi metodga ham bir xil id berib, PK ni buzardi.
merge into core_methods t
using (
  select 'catalogProducts' method,
         'Ipt_Catalog.Get_Products' proc_name,
         'N' add_log,
         'Sayt katalogi: to''liq ro''yxat, sahifalab' details,
         1 seq from dual
  union all
  select 'catalogStock',
         'Ipt_Catalog.Get_Stock',
         'N',
         'Sayt katalogi: narx va qoldiq',
         2 from dual
  union all
  select 'catalogSaveProduct',
         'Ipt_Catalog.Save_Product',
         'Y',
         'Katalog maydonlarini to''ldirish (ichki)',
         3 from dual
) s
on (lower(t.method) = lower(s.method))
when matched then
  update set t.proc_name = s.proc_name,
             t.details   = s.details,
             t.add_log   = s.add_log,
             t.state     = 'A'
when not matched then
  insert (id, method, proc_name, state, has_out_param, is_func, add_log, details, cr_on)
  values ((select nvl(max(m.id), 0) from core_methods m) + s.seq,
          s.method, s.proc_name, 'A', 'Y', 'N', s.add_log, s.details, sysdate);

commit;


-- =============================================================================
-- 4. catalogSaveProduct — chaqirish namunasi
--
-- POST /api/app/request/v2  (oddiy JWT bilan, tokenga aloqasi yo'q)
--
--   {
--     "method": "catalogSaveProduct",
--     "params": {
--       "ids": [101, 102, 103],
--       "model_code": "iphone-16-pro-max",
--       "model_name": "iPhone 16 Pro Max",
--       "category_code": "iphone",
--       "brand_code": "apple",
--       "item_condition": "new",
--       "retail_price_uzs": 19500000,
--       "phys_filial_code": "01025"
--     }
--   }
--
-- "ids" dan boshqa hamma maydon ixtiyoriy. Berilmagan maydon TEGILMAYDI —
-- ya'ni faqat model_code ni yuborib, narxni joyida qoldirish mumkin.
--
-- Bir nechta id birdaniga: bitta model bo'yicha o'nlab qator bir xil
-- model_code/category/brand oladi, ularni bittalab tahrirlash ma'nosiz.
-- Narx ham odatda bir xil yangi apparatlarda bir xil.
--
-- retail_price_uzs SOMDA yuboriladi (19500000), bazada tiyinda saqlanadi.
-- =============================================================================


-- =============================================================================
-- 5. TOKEN YARATISH
--
-- Tokenni o'zingiz o'ylab topmang — tasodifiy generatsiya qiling, masalan:
--
--   openssl rand -hex 32
--
-- Chiqqan qiymatni sayt jamoasiga BIR MARTA xavfsiz kanal orqali yuboring va
-- o'zingizda saqlamang: bazada faqat xesh qoladi, tokenni tiklab bo'lmaydi.
-- Yo'qolsa — yangisini yaratib, eskisini condition = 'P' ga o'tkazasiz.
--
--   insert into core_api_tokens(id, name, token_hash, user_id, condition, cr_by, cr_on)
--   values ((select nvl(max(id), 0) + 1 from core_api_tokens),
--           'ABM Store sayti',
--           lower(rawtohex(standard_hash('BU_YERGA_TOKEN', 'SHA256'))),
--           :user_id,          -- katalog nomidan ishlaydigan core_users.user_id
--           'A',
--           :user_id,
--           sysdate);
--   commit;
--
-- Tekshirish:
--   select id, name, user_id, condition from core_api_tokens;
--
-- Bekor qilish:
--   update core_api_tokens set condition = 'P' where id = ?;
-- =============================================================================
