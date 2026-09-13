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

end Ipt_Catalog;
/


prompt 2.2 Ipt_Catalog — tanasi

create or replace package body Ipt_Catalog is

  -- Sahifa hajmi chegaralari. Sayt 100-500 oralig'ini so'ragan.
  cMax_Per_Page constant number := 500;

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
    vParams   json_object_t := json_object_t.parse(iParams);
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

end Ipt_Catalog;
/


-- =============================================================================
-- 3. METODLARNI RO'YXATGA OLISH
--
-- add_log = 'N': katalog soatiga bir marta, qoldiq esa 5 daqiqada bir marta
-- so'raladi. Loglasak core_api_log keraksiz to'lib ketadi.
--
-- Metodni vaqtincha o'chirish kerak bo'lsa: state = 'P'.
-- =============================================================================

prompt 3.1 core_methods

merge into core_methods t
using (
  select 'catalogProducts' method,
         'Ipt_Catalog.Get_Products' proc_name,
         'Sayt katalogi: to''liq ro''yxat, sahifalab' details from dual
  union all
  select 'catalogStock',
         'Ipt_Catalog.Get_Stock',
         'Sayt katalogi: narx va qoldiq' from dual
) s
on (lower(t.method) = lower(s.method))
when matched then
  update set t.proc_name = s.proc_name,
             t.details   = s.details,
             t.state     = 'A'
when not matched then
  insert (id, method, proc_name, state, has_out_param, is_func, add_log, details, cr_on)
  values ((select nvl(max(m.id), 0) + 1 from core_methods m),
          s.method, s.proc_name, 'A', 'Y', 'N', 'N', s.details, sysdate);

commit;


-- =============================================================================
-- 4. TOKEN YARATISH
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
