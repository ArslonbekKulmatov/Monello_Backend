-- =============================================================================
-- IPT_DICTIONARY — barcha ipt_s_* ma'lumotnomalari uchun yagona CRUD
--
-- Monello web'da bitta forma: chapda ma'lumotnomalar ro'yxati, o'ngda
-- tanlanganining qatorlari. Forma o'zini METADATA'dan quradi — har
-- ma'lumotnoma uchun alohida ekran yozilmaydi.
--
-- Yangi ma'lumotnoma qo'shilganda kod O'ZGARMAYDI: ikkita jadvalga qator
-- qo'shiladi va forma uni o'zi ko'rsata boshlaydi.
--
-- ISHGA TUSHIRISH: ipt_catalog_stage3.sql dan KEYIN (yangi ma'lumotnomalar
-- o'sha yerda yaratiladi)
--
-- Muallif: Arslonbek Kulmatov
-- Sana   : 19.09.2026
-- =============================================================================


-- =============================================================================
-- 1. METADATA JADVALLARI
-- =============================================================================

prompt 1.1 IPT_S_DICTIONARIES

create table IPT_S_DICTIONARIES
(
  code          VARCHAR2(40) not null,
  table_name    VARCHAR2(30) not null,
  name_ru       VARCHAR2(200) not null,
  name_uz       VARCHAR2(200),
  pk_column     VARCHAR2(30) default 'CODE' not null,
  pk_type       VARCHAR2(1)  default 'S' not null,
  pk_max_len    NUMBER(6),
  state_column  VARCHAR2(30),
  order_column  VARCHAR2(30),
  state_active  VARCHAR2(2) default 'A',
  state_passive VARCHAR2(2) default 'P',
  can_insert    VARCHAR2(1) default 'Y' not null,
  can_delete    VARCHAR2(1) default 'Y' not null,
  lock_reason   VARCHAR2(500),
  ord           NUMBER(5) default 100 not null,
  condition     VARCHAR2(2) default 'A' not null
)
;
comment on table IPT_S_DICTIONARIES
  is 'Tahrirlanadigan ma''lumotnomalar ro''yxati. Yangi ma''lumotnoma shu yerga qator qo''shish bilan qo''shiladi';
comment on column IPT_S_DICTIONARIES.pk_type
  is 'S - matn kod, N - son kod';
comment on column IPT_S_DICTIONARIES.state_column
  is 'Faol/nofaol ustuni nomi: CONDITION yoki STATE. Yo''q bo''lsa NULL';
comment on column IPT_S_DICTIONARIES.order_column
  is 'Ko''rsatish tartibi ustuni, masalan ORD. Yo''q bo''lsa kod bo''yicha saralanadi';
comment on column IPT_S_DICTIONARIES.can_insert
  is 'N - yangi qator qo''shib bo''lmaydi. Kodlar PL/SQL da qotirilgan bo''lsa shunday qilinadi';
comment on column IPT_S_DICTIONARIES.can_delete
  is 'N - o''chirib bo''lmaydi';
comment on column IPT_S_DICTIONARIES.lock_reason
  is 'Nega bloklangani. Formada foydalanuvchiga ko''rsatiladi';

alter table IPT_S_DICTIONARIES add constraint IPT_S_DICTIONARIES_PK primary key (CODE);
alter table IPT_S_DICTIONARIES add constraint IPT_S_DICT_TABLE_UK unique (TABLE_NAME);
alter table IPT_S_DICTIONARIES add constraint IPT_S_DICT_PKTYPE_CHK check (pk_type in ('S', 'N'));
alter table IPT_S_DICTIONARIES add constraint IPT_S_DICT_INS_CHK check (can_insert in ('Y', 'N'));
alter table IPT_S_DICTIONARIES add constraint IPT_S_DICT_DEL_CHK check (can_delete in ('Y', 'N'));
alter table IPT_S_DICTIONARIES add constraint IPT_S_DICT_COND_CHK check (condition in ('A', 'P'));


prompt 1.2 IPT_S_DICTIONARY_COLS

create table IPT_S_DICTIONARY_COLS
(
  dict_code   VARCHAR2(40) not null,
  column_name VARCHAR2(30) not null,
  name_ru     VARCHAR2(200) not null,
  name_uz     VARCHAR2(200),
  data_type   VARCHAR2(1) default 'S' not null,
  max_len     NUMBER(6),
  is_required VARCHAR2(1) default 'N' not null,
  lov         VARCHAR2(1000),
  ord         NUMBER(5) default 100 not null,
  condition   VARCHAR2(2) default 'A' not null
)
;
comment on table IPT_S_DICTIONARY_COLS
  is 'Ma''lumotnomaning tahrirlanadigan ustunlari. Bu yerda yo''q ustun formaga chiqmaydi va yozilmaydi ham';
comment on column IPT_S_DICTIONARY_COLS.data_type
  is 'S - matn, N - son, B - mantiqiy (1/0), F - bayroq (Y/N), L - ro''yxat (lov dan)';
comment on column IPT_S_DICTIONARY_COLS.lov
  is 'L turi uchun: "kod:Nomi;kod:Nomi". Masalan "text:Matn;number:Son;bool:Mantiqiy"';

alter table IPT_S_DICTIONARY_COLS add constraint IPT_S_DICT_COLS_PK primary key (DICT_CODE, COLUMN_NAME);
alter table IPT_S_DICTIONARY_COLS add constraint IPT_S_DICT_COLS_FK
  foreign key (DICT_CODE) references IPT_S_DICTIONARIES (CODE);
alter table IPT_S_DICTIONARY_COLS add constraint IPT_S_DICT_COLS_TYPE_CHK
  check (data_type in ('S', 'N', 'B', 'F', 'L'));
alter table IPT_S_DICTIONARY_COLS add constraint IPT_S_DICT_COLS_REQ_CHK
  check (is_required in ('Y', 'N'));
alter table IPT_S_DICTIONARY_COLS add constraint IPT_S_DICT_COLS_COND_CHK
  check (condition in ('A', 'P'));


-- =============================================================================
-- 2. MA'LUMOTNOMALAR RO'YXATI
--
-- BLOKLANGANLAR VA SABABI
--
--   product_states, trade_states — kodlari PL/SQL da qotirilgan
--     (ipt_methods da state = 'S', state not in ('03','05','06','07') kabi
--     tekshiruvlar bor). Yangi kod qo'shilsa uni hech qanday kod ishlatmaydi,
--     mavjudi o'chirilsa mantiq jimgina buziladi. Nomini o'zgartirish mumkin.
--
--   filials — filial qo'shish bitta qator emas: sessiya filiali, hisobotlar,
--     grafiklar va huquqlar bilan bog'liq. Nomini va site_code ni
--     o'zgartirish mumkin, aynan shu yerdan.
--
-- Qolganlarida o'chirish FK bilan himoyalangan: ishlatilayotgan kodni
-- o'chirib bo'lmaydi va foydalanuvchi tushunarli xabar oladi.
--
-- Blokni ochish — bitta update:
--   update ipt_s_dictionaries set can_insert = 'Y' where code = '...';
-- =============================================================================

prompt 2.1 Ma'lumotnomalar

merge into ipt_s_dictionaries t
using (
  --          code                  table_name                 name_ru                      name_uz                      pk_type pk_len state_col    ord_col ins del ord
  select 'categories'          code, 'IPT_S_CATEGORIES'   tab, 'Категории товаров'    nm_ru, 'Tovar kategoriyalari' nm_uz, 'S' pk, 30  pl, 'CONDITION' st, 'ORD' oc, 'Y' ins, 'Y' del, null lock, 10 ord from dual union all
  select 'brands',                   'IPT_S_BRANDS',           'Бренды',                     'Brendlar',                   'S', 30,     'CONDITION',     null, 'Y',      'Y',      null,      20 from dual union all
  select 'colors',                   'IPT_S_COLORS',           'Цвета',                      'Ranglar',                    'S', 30,     'CONDITION',     null, 'Y',      'Y',      null,      30 from dual union all
  select 'attributes',               'IPT_S_ATTRIBUTES',       'Характеристики моделей',     'Model xarakteristikalari',   'S', 40,     'CONDITION',     null, 'Y',      'Y',      null,      40 from dual union all
  select 'sim_types',                'IPT_S_SIM_TYPES',        'Типы SIM',                   'SIM turlari',                'S', 20,     'CONDITION',     null, 'Y',      'Y',      null,      50 from dual union all
  select 'market_codes',             'IPT_S_MARKET_CODES',     'Коды рынка',                 'Bozor kodlari',              'S', 20,     'CONDITION',     null, 'Y',      'Y',      null,      60 from dual union all
  select 'replaced_parts',           'IPT_S_REPLACED_PARTS',   'Заменённые детали',          'Almashtirilgan qismlar',     'S', 30,     'CONDITION',     null, 'Y',      'Y',      null,      70 from dual union all
  select 'expense_types',            'IPT_S_EXPENSE_TYPES',    'Виды расходов',              'Xarajat turlari',            'N', null,   'STATE',         null, 'Y',      'Y',      null,      80 from dual union all
  select 'client_guar_types',        'IPT_S_CLIENT_GUAR_TYPES','Виды обеспечения',           'Ta''minot turlari',          'S', 2,      'CONDITION',     null, 'Y',      'Y',      null,      90 from dual union all
  select 'operations',               'IPT_S_OPERATIONS',       'Операции',                   'Operatsiyalar',              'S', 10,     'CONDITION',     null, 'Y',      'Y',      null,     100 from dual union all
  select 'balance_log_modules',      'IPT_S_BALANCE_LOG_MODULES','Модули журнала баланса',   'Balans jurnali modullari',   'S', 60,     'CONDITION',     null, 'Y',      'Y',      null,     110 from dual union all
  select 'product_types',            'IPT_S_PRODUCT_TYPES',    'Типы товара',                'Tovar turlari',              'S', 2,      'CONDITION',     null, 'Y',      'N',
         'Kod o''chirilsa mavjud tovarlar turi yo''qoladi. Nofaol qilish yetarli.',                                                                                                    120 from dual union all
  select 'filials',                  'IPT_S_FILIALS',          'Филиалы',                    'Filiallar',                  'S', 10,     'CONDITION',     null, 'N',      'N',
         'Filial qo''shish bitta qator emas: sessiya filiali, hisobotlar va huquqlar bilan bog''liq. Nomi va site_code ni bu yerdan o''zgartirish mumkin.',                             130 from dual union all
  select 'product_states',           'IPT_S_PRODUCT_STATES',   'Состояния товара',           'Tovar holatlari',            'S', 2,      'CONDITION',     null, 'N',      'N',
         'Kodlar PL/SQL da qotirilgan (state = ''S'' kabi). Yangi kodni hech qanday kod ishlatmaydi. Faqat nomini o''zgartirish mumkin.',                                               140 from dual union all
  select 'trade_states',             'IPT_S_TRADE_STATES',     'Состояния сделки',           'Sdelka holatlari',           'S', 3,      'CONDITION',     null, 'N',      'N',
         'Kodlar PL/SQL da qotirilgan (state not in (''03'',''05'',''06'',''07'') kabi). Faqat nomini o''zgartirish mumkin.',                                                           150 from dual
) s
on (t.code = s.code)
when matched then
  update set t.table_name  = s.tab,
             t.name_ru     = s.nm_ru,
             t.name_uz     = s.nm_uz,
             t.pk_type     = s.pk,
             t.pk_max_len  = s.pl,
             t.state_column= s.st,
             t.order_column= s.oc,
             t.can_insert  = s.ins,
             t.can_delete  = s.del,
             t.lock_reason = s.lock,
             t.ord         = s.ord,
             t.condition   = 'A'
when not matched then
  insert (code, table_name, name_ru, name_uz, pk_type, pk_max_len, state_column,
          order_column, can_insert, can_delete, lock_reason, ord, condition)
  values (s.code, s.tab, s.nm_ru, s.nm_uz, s.pk, s.pl, s.st,
          s.oc, s.ins, s.del, s.lock, s.ord, 'A');

commit;


prompt 2.2 Ustunlar

-- Faol/nofaol ustuni ham oddiy ustun sifatida ro'yxatdan o'tadi — shunda
-- paketda alohida shart kerak emas, forma esa uni state_column nomi bo'yicha
-- tugmacha qilib chizadi.
merge into ipt_s_dictionary_cols t
using (
  select 'categories' d, 'NAME_RU' c, 'Название (ru)' nr, 'Nomi (ru)' nu, 'S' dt, 500 ml, 'Y' rq, null lov, 10 ord from dual union all
  select 'categories', 'NAME_UZ',   'Название (uz)',   'Nomi (uz)',      'S', 500,  'N', null, 20 from dual union all
  select 'categories', 'ORD',       'Порядок',         'Tartib',         'N', null, 'N', null, 30 from dual union all
  select 'categories', 'CONDITION', 'Состояние',       'Holati',         'L', null, 'N', 'A:Faol;P:Nofaol', 40 from dual union all

  select 'brands', 'NAME',      'Название', 'Nomi',   'S', 500,  'Y', null, 10 from dual union all
  select 'brands', 'CONDITION', 'Состояние','Holati', 'L', null, 'N', 'A:Faol;P:Nofaol', 20 from dual union all

  select 'colors', 'NAME_RU',   'Название (ru)','Nomi (ru)','S', 200,  'Y', null, 10 from dual union all
  select 'colors', 'NAME_UZ',   'Название (uz)','Nomi (uz)','S', 200,  'N', null, 20 from dual union all
  select 'colors', 'CONDITION', 'Состояние',    'Holati',   'L', null, 'N', 'A:Faol;P:Nofaol', 30 from dual union all

  select 'attributes', 'NAME_RU',    'Название (ru)','Nomi (ru)',      'S', 200,  'Y', null, 10 from dual union all
  select 'attributes', 'NAME_UZ',    'Название (uz)','Nomi (uz)',      'S', 200,  'N', null, 20 from dual union all
  select 'attributes', 'VALUE_TYPE', 'Тип значения', 'Qiymat turi',    'L', null, 'Y', 'text:Matn;number:Son;bool:Mantiqiy', 30 from dual union all
  select 'attributes', 'IS_MULTI',   'Много значений','Ko''p qiymatli','B', null, 'Y', null, 40 from dual union all
  select 'attributes', 'CONDITION',  'Состояние',    'Holati',         'L', null, 'N', 'A:Faol;P:Nofaol', 50 from dual union all

  select 'sim_types', 'NAME',      'Название', 'Nomi',   'S', 200,  'Y', null, 10 from dual union all
  select 'sim_types', 'CONDITION', 'Состояние','Holati', 'L', null, 'N', 'A:Faol;P:Nofaol', 20 from dual union all

  select 'market_codes', 'NAME',      'Название', 'Nomi',   'S', 200,  'Y', null, 10 from dual union all
  select 'market_codes', 'CONDITION', 'Состояние','Holati', 'L', null, 'N', 'A:Faol;P:Nofaol', 20 from dual union all

  select 'replaced_parts', 'NAME_RU',   'Название (ru)','Nomi (ru)','S', 200,  'Y', null, 10 from dual union all
  select 'replaced_parts', 'NAME_UZ',   'Название (uz)','Nomi (uz)','S', 200,  'N', null, 20 from dual union all
  select 'replaced_parts', 'CONDITION', 'Состояние',    'Holati',   'L', null, 'N', 'A:Faol;P:Nofaol', 30 from dual union all

  select 'expense_types', 'NAME',  'Название', 'Nomi',   'S', 500,  'N', null, 10 from dual union all
  select 'expense_types', 'STATE', 'Состояние','Holati', 'L', null, 'N', 'A:Faol;P:Nofaol', 20 from dual union all

  select 'client_guar_types', 'NAME',      'Название', 'Nomi',   'S', 1000, 'Y', null, 10 from dual union all
  select 'client_guar_types', 'CONDITION', 'Состояние','Holati', 'L', null, 'Y', 'A:Faol;P:Nofaol', 20 from dual union all

  select 'operations', 'NAME',       'Название',   'Nomi',        'S', 500,  'Y', null, 10 from dual union all
  select 'operations', 'INITIATOR',  'Инициатор',  'Tashabbuskor','S', 2,    'Y', null, 20 from dual union all
  select 'operations', 'IS_EXPENSE', 'Расход',     'Xarajat',     'F', null, 'N', null, 30 from dual union all
  select 'operations', 'CONDITION',  'Состояние',  'Holati',      'L', null, 'Y', 'A:Faol;P:Nofaol', 40 from dual union all

  select 'balance_log_modules', 'NAME',        'Название',  'Nomi',       'S', 200,  'Y', null, 10 from dual union all
  select 'balance_log_modules', 'DESCRIPTION', 'Описание',  'Izoh',       'S', 1000, 'N', null, 20 from dual union all
  select 'balance_log_modules', 'HAS_CONTEXT', 'Есть контекст','Kontekst bor','F', null, 'Y', null, 30 from dual union all
  select 'balance_log_modules', 'AFFECTS',     'Влияет на', 'Nimaga ta''sir qiladi','S', 40, 'N', null, 40 from dual union all
  select 'balance_log_modules', 'CONDITION',   'Состояние', 'Holati',     'L', null, 'N', 'A:Faol;P:Nofaol', 50 from dual union all

  select 'product_types', 'NAME',      'Название', 'Nomi',   'S', 500,  'Y', null, 10 from dual union all
  select 'product_types', 'CONDITION', 'Состояние','Holati', 'L', null, 'Y', 'A:Faol;P:Nofaol', 20 from dual union all

  -- Filialda site_code ayni shu forma orqali qo'yiladi: sayt katalogi
  -- to'ldirilmagan site_code da butunlay bo'sh qaytadi.
  select 'filials', 'NAME',      'Название',        'Nomi',            'S', 1000, 'Y', null, 10 from dual union all
  select 'filials', 'TYPE',      'Тип',             'Turi',            'S', 100,  'N', null, 20 from dual union all
  select 'filials', 'SITE_CODE', 'Код витрины',     'Shourum kodi',    'S', 30,   'N', null, 30 from dual union all
  select 'filials', 'CONDITION', 'Состояние',       'Holati',          'L', null, 'Y', 'A:Faol;P:Nofaol', 40 from dual union all

  select 'product_states', 'NAME',      'Название', 'Nomi',   'S', 500,  'Y', null, 10 from dual union all
  select 'product_states', 'CONDITION', 'Состояние','Holati', 'L', null, 'Y', 'A:Faol;P:Nofaol', 20 from dual union all

  select 'trade_states', 'NAME',      'Название', 'Nomi',   'S', 500,  'Y', null, 10 from dual union all
  select 'trade_states', 'CONDITION', 'Состояние','Holati', 'L', null, 'Y', 'A:Faol;P:Nofaol', 20 from dual
) s
on (t.dict_code = s.d and t.column_name = s.c)
when matched then
  update set t.name_ru     = s.nr,
             t.name_uz     = s.nu,
             t.data_type   = s.dt,
             t.max_len     = s.ml,
             t.is_required = s.rq,
             t.lov         = s.lov,
             t.ord         = s.ord,
             t.condition   = 'A'
when not matched then
  insert (dict_code, column_name, name_ru, name_uz, data_type, max_len,
          is_required, lov, ord, condition)
  values (s.d, s.c, s.nr, s.nu, s.dt, s.ml, s.rq, s.lov, s.ord, 'A');

commit;


-- =============================================================================
-- 3. IPT_DICTIONARY PAKETI
-- =============================================================================

prompt 3.1 Ipt_Dictionary — spetsifikatsiya

create or replace package Ipt_Dictionary is

  -- Author  : Arslonbek Kulmatov
  -- Created : 19.09.2026
  -- Purpose : ipt_s_* ma'lumotnomalari uchun yagona CRUD

  --Cr By: Arslonbek Kulmatov
  --Barcha ma'lumotnomalar va ularning ustunlari. Forma shundan quriladi
  Procedure Get_List(iParams clob, oResponse out clob);

  --Cr By: Arslonbek Kulmatov
  --Bitta ma'lumotnomaning qatorlari, qidiruv va sahifalash bilan
  Procedure Get_Rows(iParams clob, oResponse out clob);

  --Cr By: Arslonbek Kulmatov
  --Qator qo'shish yoki tahrirlash
  Procedure Save_Row(iParams clob, oResponse out clob);

  --Cr By: Arslonbek Kulmatov
  --Qatorni o'chirish
  Procedure Delete_Row(iParams clob, oResponse out clob);

end Ipt_Dictionary;
/


prompt 3.2 Ipt_Dictionary — tanasi

create or replace package body Ipt_Dictionary is

  cMax_Per_Page constant number := 500;

  -- Bolalar yozuvi bor: FK buzilishi
  eChild_Found exception;
  pragma exception_init(eChild_Found, -2292);

  type tCols is table of ipt_s_dictionary_cols%rowtype index by pls_integer;

  -- ===========================================================================
  -- Yordamchilar
  -- ===========================================================================

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

  Procedure Put_Str(ioObj in out nocopy json_object_t, iKey varchar2, iVal varchar2)
  is
  begin
    if iVal is not null then
      ioObj.put(iKey, iVal);
    end if;
  end;

  --Cr By: Arslonbek Kulmatov
  --JSON dagi istalgan oddiy qiymatni matn sifatida o'qish.
  --get_String faqat matnda ishlaydi: {"ord": 10} da u NULL qaytaradi va
  --qiymat jimgina yo'qoladi.
  Function Json_Scalar(iObj json_object_t, iKey varchar2) return varchar2
  is
    vEl json_element_t;
  begin
    if iObj is null or not iObj.has(iKey) then
      return null;
    end if;

    vEl := iObj.get(iKey);

    if vEl is null or vEl.is_Null then
      return null;
    end if;

    if vEl.is_String then
      return iObj.get_String(iKey);
    end if;

    if vEl.is_Number then
      return trim(to_char(iObj.get_Number(iKey), 'TM9', 'NLS_NUMERIC_CHARACTERS=''.,'''));
    end if;

    if vEl.is_Boolean then
      return case when iObj.get_Boolean(iKey) then '1' else '0' end;
    end if;

    return vEl.to_String;
  end;

  --Cr By: Arslonbek Kulmatov
  --Identifikatorni tekshirish. Jadval va ustun nomlari METADATA'dan keladi,
  --foydalanuvchidan emas — lekin dinamik SQL ga qo'yilayotgani uchun baribir
  --tekshiramiz: metadata jadvaliga kimdir qo'lda yozib qo'ysa ham.
  Function Safe_Name(iName varchar2) return varchar2
  is
  begin
    return dbms_assert.simple_sql_name(iName);
  exception
    when others then
      Ipt_Methods.Raise_Error('Ma''lumotnoma sozlamasida yaroqsiz nom: '||iName);
  end;

  --Cr By: Arslonbek Kulmatov
  --Ma'lumotnomani olish
  Function Get_Dict(iCode varchar2) return ipt_s_dictionaries%rowtype
  is
    vDict ipt_s_dictionaries%rowtype;
  begin
    if trim(iCode) is null then
      Ipt_Methods.Raise_Error('"dict" ko''rsatilmagan.');
    end if;

    begin
      select * into vDict
        from ipt_s_dictionaries t
       where t.code = trim(iCode)
         and t.condition = 'A';
    exception
      when no_data_found then
        Ipt_Methods.Raise_Error('Bunday ma''lumotnoma yo''q yoki faol emas: '||iCode);
    end;

    vDict.Table_Name := Safe_Name(vDict.Table_Name);
    vDict.Pk_Column  := Safe_Name(vDict.Pk_Column);

    return vDict;
  end;

  --Cr By: Arslonbek Kulmatov
  --Ma'lumotnomaning ustunlari, tartib bo'yicha
  Function Get_Cols(iDict varchar2) return tCols
  is
    vCols tCols;
    i     pls_integer := 0;
  begin
    for rows in (select * from ipt_s_dictionary_cols t
                  where t.dict_code = iDict
                    and t.condition = 'A'
                  order by t.ord, t.column_name)
    loop
      i := i + 1;
      vCols(i) := rows;
      vCols(i).Column_Name := Safe_Name(rows.column_name);
    end loop;

    if i = 0 then
      Ipt_Methods.Raise_Error('"'||iDict||'" uchun ustunlar sozlanmagan. '||
                              'ipt_s_dictionary_cols ga qator qo''shing.');
    end if;

    return vCols;
  end;

  --Cr By: Arslonbek Kulmatov
  --"kod:Nomi;kod:Nomi" -> JSON massiv
  Function Parse_Lov(iLov varchar2) return json_array_t
  is
    vArr  json_array_t := json_array_t();
    vItem json_object_t;
    vRest varchar2(1000) := iLov;
    vPart varchar2(1000);
    vPos  pls_integer;
  begin
    while vRest is not null
    loop
      vPos := instr(vRest, ';');

      if vPos = 0 then
        vPart := vRest;
        vRest := null;
      else
        vPart := substr(vRest, 1, vPos - 1);
        vRest := substr(vRest, vPos + 1);
      end if;

      vPart := trim(vPart);

      if vPart is not null then
        vPos   := instr(vPart, ':');
        vItem  := json_object_t();
        vItem.put('code', case when vPos = 0 then vPart else substr(vPart, 1, vPos - 1) end);
        vItem.put('name', case when vPos = 0 then vPart else substr(vPart, vPos + 1) end);
        vArr.append(vItem);
      end if;
    end loop;

    return vArr;
  end;

  --Cr By: Arslonbek Kulmatov
  --Qiymatni turiga qarab tekshirish va normal ko'rinishga keltirish
  Function Check_Value(iCol ipt_s_dictionary_cols%rowtype, iValue varchar2) return varchar2
  is
    vVal   varchar2(4000) := trim(iValue);
    vLov   json_array_t;
    vFound boolean := false;
    vNum   number;
  begin
    if vVal is null then
      if iCol.Is_Required = 'Y' then
        Ipt_Methods.Raise_Error('"'||lower(iCol.Column_Name)||'" to''ldirilishi shart.');
      end if;
      return null;
    end if;

    if iCol.Data_Type = 'N' then
      begin
        vNum := to_number(vVal);
      exception
        when others then
          Ipt_Methods.Raise_Error('"'||lower(iCol.Column_Name)||'" son bo''lishi kerak: '||vVal);
      end;
      return trim(to_char(vNum, 'TM9', 'NLS_NUMERIC_CHARACTERS=''.,'''));
    end if;

    if iCol.Data_Type = 'B' then
      if lower(vVal) in ('1', 'true', 'y') then return '1'; end if;
      if lower(vVal) in ('0', 'false', 'n') then return '0'; end if;
      Ipt_Methods.Raise_Error('"'||lower(iCol.Column_Name)||'" mantiqiy qiymat bo''lishi kerak.');
    end if;

    if iCol.Data_Type = 'F' then
      if lower(vVal) in ('1', 'true', 'y') then return 'Y'; end if;
      if lower(vVal) in ('0', 'false', 'n') then return 'N'; end if;
      Ipt_Methods.Raise_Error('"'||lower(iCol.Column_Name)||'" Y yoki N bo''lishi kerak.');
    end if;

    if iCol.Data_Type = 'L' then
      vLov := Parse_Lov(iCol.Lov);

      for i in 0 .. vLov.get_size - 1
      loop
        if treat(vLov.get(i) as json_object_t).get_String('code') = vVal then
          vFound := true;
          exit;
        end if;
      end loop;

      if not vFound then
        Ipt_Methods.Raise_Error('"'||lower(iCol.Column_Name)||'" uchun yaroqsiz qiymat: '||vVal||
                                '. Mumkin qiymatlar: '||iCol.Lov);
      end if;

      return vVal;
    end if;

    -- matn
    if iCol.Max_Len is not null and length(vVal) > iCol.Max_Len then
      Ipt_Methods.Raise_Error('"'||lower(iCol.Column_Name)||'" uzunligi '||iCol.Max_Len||
                              ' belgidan oshmasligi kerak (hozir '||length(vVal)||').');
    end if;

    return vVal;
  end;

  --Cr By: Arslonbek Kulmatov
  --Ma'lumotnomalarni tahrirlash huquqi.
  --
  --Hozir Product_Action bilan bir xil model. Ma'lumotnoma tahriri undan
  --jiddiyroq — sdelka holati nomini o'zgartirish butun tizimga ko'rinadi.
  --Alohida rol ajratilganda quyidagi satr ochiladi va rol id'si qo'yiladi:
  --
  --  if ipt_util.Has_Access_For_Role(iRole_Id => <admin_rol_id>) = 0 then
  --    Ipt_Methods.Raise_Error('Ma''lumotnomalarni tahrirlash huquqi yo''q.');
  --  end if;
  Procedure Check_Access
  is
  begin
    Ipt_Methods.Check_For_Seller;
  end;

  -- ===========================================================================
  -- Metodlar
  -- ===========================================================================

  --Cr By: Arslonbek Kulmatov
  --Barcha ma'lumotnomalar va ustunlari. Forma shu bitta chaqiruvdan quriladi:
  --15 ta ma'lumotnoma x ~4 ustun — javob kichik, alohida meta chaqiruvi shart emas.
  Procedure Get_List(iParams clob, oResponse out clob)
  is
    vResponse json_object_t := json_object_t();
    vDicts    json_array_t  := json_array_t();
    vDict     json_object_t;
    vCols     json_array_t;
    vCol      json_object_t;
  begin
    for d in (select * from ipt_s_dictionaries t
               where t.condition = 'A'
               order by t.ord, t.code)
    loop
      vCols := json_array_t();

      for c in (select * from ipt_s_dictionary_cols t
                 where t.dict_code = d.code
                   and t.condition = 'A'
                 order by t.ord, t.column_name)
      loop
        vCol := json_object_t();
        vCol.put('name', lower(c.column_name));
        vCol.put('label_ru', c.name_ru);
        Put_Str(vCol, 'label_uz', c.name_uz);
        vCol.put('type', c.data_type);
        vCol.put('required', c.is_required = 'Y');

        if c.max_len is not null then
          vCol.put('max_len', c.max_len);
        end if;

        if c.lov is not null then
          vCol.put('lov', Parse_Lov(c.lov));
        end if;

        vCols.append(vCol);
      end loop;

      vDict := json_object_t();
      vDict.put('code', d.code);
      vDict.put('name_ru', d.name_ru);
      Put_Str(vDict, 'name_uz', d.name_uz);
      vDict.put('pk_column', lower(d.pk_column));
      vDict.put('pk_type', d.pk_type);

      if d.pk_max_len is not null then
        vDict.put('pk_max_len', d.pk_max_len);
      end if;

      Put_Str(vDict, 'state_column', lower(d.state_column));
      Put_Str(vDict, 'order_column', lower(d.order_column));
      vDict.put('can_insert', d.can_insert = 'Y');
      vDict.put('can_delete', d.can_delete = 'Y');
      Put_Str(vDict, 'lock_reason', d.lock_reason);
      vDict.put('columns', vCols);

      vDicts.append(vDict);
    end loop;

    vResponse.put('dictionaries', vDicts);
    oResponse := vResponse.to_clob();
  end;

  --Cr By: Arslonbek Kulmatov
  --Bitta ma'lumotnomaning qatorlari.
  --
  --dbms_sql ishlatiladi, chunki ustunlar soni oldindan ma'lum emas.
  --Jadval va ustun nomlari faqat metadata'dan keladi va Safe_Name dan
  --o'tadi; qiymatlar esa har doim bind bilan.
  Procedure Get_Rows(iParams clob, oResponse out clob)
  is
    vParams   json_object_t := Get_Params(iParams);
    vResponse json_object_t := json_object_t();
    vRows     json_array_t  := json_array_t();
    vRow      json_object_t;
    vDict     ipt_s_dictionaries%rowtype;
    vCols     tCols;
    vSelect   varchar2(4000);
    vSearchable varchar2(4000);
    vSql      varchar2(8000);
    vSearch   varchar2(500);
    vPage     number;
    vPerPage  number;
    vTotal    number;
    vCursor   integer;
    vDummy    integer;
    vBuf      varchar2(4000);
    vName     varchar2(30);
  begin
    vDict    := Get_Dict(Json_Scalar(vParams, 'dict'));
    vCols    := Get_Cols(vDict.Code);
    vSearch  := trim(Json_Scalar(vParams, 'search'));
    vPage    := nvl(to_number(Json_Scalar(vParams, 'page')), 1);
    vPerPage := nvl(to_number(Json_Scalar(vParams, 'per_page')), 200);

    if vPage < 1 then
      Ipt_Methods.Raise_Error('"page" 1 dan kichik bo''lishi mumkin emas.');
    end if;

    if vPerPage < 1 or vPerPage > cMax_Per_Page then
      Ipt_Methods.Raise_Error('"per_page" 1 va '||cMax_Per_Page||' oralig''ida bo''lishi kerak.');
    end if;

    -- Barcha ustunlar matn sifatida olinadi: define_column bir xil bo'lsin.
    -- Sonlar NLS dan qat'i nazar nuqta bilan chiqsin deb format aniq berilgan.
    vSelect     := 'to_char('||vDict.Pk_Column||')';
    vSearchable := 'lower(to_char('||vDict.Pk_Column||'))';

    for i in 1 .. vCols.count
    loop
      if vCols(i).Data_Type = 'N' then
        vSelect := vSelect||', to_char('||vCols(i).Column_Name||
                   ', ''TM9'', ''NLS_NUMERIC_CHARACTERS=".,"'')';
      else
        vSelect := vSelect||', '||vCols(i).Column_Name;
        vSearchable := vSearchable||'||'' ''||lower('||vCols(i).Column_Name||')';
      end if;
    end loop;

    if vSearch is not null then
      vSearch := '%'||lower(vSearch)||'%';
    end if;

    -- Jami soni
    execute immediate
      'select count(*) from '||vDict.Table_Name||
      ' where :s is null or '||vSearchable||' like :s'
      into vTotal using vSearch, vSearch;

    vSql := 'select '||vSelect||' from '||vDict.Table_Name||
            ' where :s is null or '||vSearchable||' like :s'||
            -- Tartib: avval faollar, keyin o'z tartib ustuni (bo'lsa),
            -- oxirida kod. Kategoriyalarda ORD aynan shu uchun bor —
            -- usiz ro'yxat "acc-audio" dan boshlanadi, "iphone" dan emas.
            ' order by '||
            case when vDict.State_Column is not null
                 then Safe_Name(vDict.State_Column)||', ' else '' end||
            case when vDict.Order_Column is not null
                 then Safe_Name(vDict.Order_Column)||', ' else '' end||
            vDict.Pk_Column||
            ' offset :o rows fetch next :l rows only';

    vCursor := dbms_sql.open_cursor;

    begin
      dbms_sql.parse(vCursor, vSql, dbms_sql.native);
      dbms_sql.bind_variable(vCursor, 's', vSearch);
      dbms_sql.bind_variable(vCursor, 'o', (vPage - 1) * vPerPage);
      dbms_sql.bind_variable(vCursor, 'l', vPerPage);

      for i in 1 .. vCols.count + 1
      loop
        dbms_sql.define_column(vCursor, i, vBuf, 4000);
      end loop;

      vDummy := dbms_sql.execute(vCursor);

      while dbms_sql.fetch_rows(vCursor) > 0
      loop
        vRow := json_object_t();

        dbms_sql.column_value(vCursor, 1, vBuf);
        vRow.put(lower(vDict.Pk_Column),
                 case when vDict.Pk_Type = 'N' and vBuf is not null
                      then to_number(vBuf) else vBuf end);

        for i in 1 .. vCols.count
        loop
          dbms_sql.column_value(vCursor, i + 1, vBuf);
          vName := lower(vCols(i).Column_Name);

          -- Bo'sh qiymat kaliti umuman qo'yilmaydi: tizimda hamma joyda
          -- shunday, va ustunlar ro'yxati dictList dan allaqachon ma'lum.
          if vBuf is null then
            null;
          elsif vCols(i).Data_Type = 'N' then
            vRow.put(vName, to_number(vBuf));
          elsif vCols(i).Data_Type = 'B' then
            vRow.put(vName, vBuf = '1');
          else
            vRow.put(vName, vBuf);
          end if;
        end loop;

        vRows.append(vRow);
      end loop;

      dbms_sql.close_cursor(vCursor);
    exception
      when others then
        if dbms_sql.is_open(vCursor) then
          dbms_sql.close_cursor(vCursor);
        end if;
        raise;
    end;

    vResponse.put('dict', vDict.Code);
    vResponse.put('total', vTotal);
    vResponse.put('page', vPage);
    vResponse.put('per_page', vPerPage);
    vResponse.put('rows', vRows);

    oResponse := vResponse.to_clob();
  end;

  --Cr By: Arslonbek Kulmatov
  --Qator qo'shish yoki tahrirlash.
  --
  --Kod bazada bor bo'lsa — tahrir, yo'q bo'lsa — qo'shish. Tahrirda faqat
  --SO'ROVDA KELGAN ustunlar yoziladi: tizimning qolgan qismidagi bilan
  --bir xil qoida.
  Procedure Save_Row(iParams clob, oResponse out clob)
  is
    vParams   json_object_t := Get_Params(iParams);
    vValues   json_object_t;
    vResponse json_object_t := json_object_t();
    vDict     ipt_s_dictionaries%rowtype;
    vCols     tCols;
    vPk       varchar2(4000);
    vSet      varchar2(4000);
    vInsCols  varchar2(4000);
    vInsVals  varchar2(4000);
    vSql      varchar2(8000);
    vCursor   integer;
    vDummy    integer;
    vExists   pls_integer;
    vIsNew    boolean;
    vUsed     pls_integer := 0;
    vBindName varchar2(40);

    -- Tekshirilgan qiymatlar. Ikki marta tekshirmaslik uchun: bir marta
    -- SQL yig'ilayotganda, keyin bind paytida shu yerdan olinadi —
    -- aks holda ikki joyda ikki xil natija chiqib qolish xavfi bor.
    type tVals is table of varchar2(4000) index by pls_integer;
    vVals     tVals;
    vBound    tVals;
  begin
    Check_Access;

    vDict := Get_Dict(Json_Scalar(vParams, 'dict'));
    vCols := Get_Cols(vDict.Code);

    vPk := trim(Json_Scalar(vParams, 'code'));

    if vPk is null then
      Ipt_Methods.Raise_Error('"code" ko''rsatilmagan.');
    end if;

    if vDict.Pk_Type = 'N' then
      begin
        vPk := trim(to_char(to_number(vPk), 'TM9', 'NLS_NUMERIC_CHARACTERS=''.,'''));
      exception
        when others then
          Ipt_Methods.Raise_Error('"code" son bo''lishi kerak: '||vPk);
      end;
    elsif vDict.Pk_Max_Len is not null and length(vPk) > vDict.Pk_Max_Len then
      Ipt_Methods.Raise_Error('"code" uzunligi '||vDict.Pk_Max_Len||
                              ' belgidan oshmasligi kerak.');
    end if;

    if vParams.has('values') then
      vValues := vParams.get_Object('values');
    end if;

    if vValues is null then
      Ipt_Methods.Raise_Error('"values" ko''rsatilmagan.');
    end if;

    execute immediate
      'select count(*) from '||vDict.Table_Name||' where '||vDict.Pk_Column||' = :p'
      into vExists using vPk;

    vIsNew := (vExists = 0);

    if vIsNew and vDict.Can_Insert = 'N' then
      Ipt_Methods.Raise_Error('"'||vDict.Name_Ru||'" ma''lumotnomasiga yangi qator '||
                              'qo''shib bo''lmaydi. '||nvl(vDict.Lock_Reason, ''));
    end if;

    -- Ustunlar ro'yxati METADATA'dan aylanadi, so'rovdagi kalitlardan emas:
    -- so'rovda notanish kalit bo'lsa u jimgina e'tiborsiz qoladi.
    for i in 1 .. vCols.count
    loop
      if vValues.has(vCols(i).Column_Name)
         or vValues.has(lower(vCols(i).Column_Name)) then

        vUsed     := vUsed + 1;
        vBindName := 'v'||vUsed;

        vVals(vUsed)  := Check_Value(vCols(i),
                                     nvl(Json_Scalar(vValues, lower(vCols(i).Column_Name)),
                                         Json_Scalar(vValues, vCols(i).Column_Name)));
        vBound(vUsed) := vCols(i).Data_Type;

        vSet      := vSet     ||case when vSet is null then '' else ', ' end||
                     vCols(i).Column_Name||' = :'||vBindName;
        vInsCols  := vInsCols ||', '||vCols(i).Column_Name;
        vInsVals  := vInsVals ||', :'||vBindName;

      elsif vIsNew and vCols(i).Is_Required = 'Y' then
        Ipt_Methods.Raise_Error('"'||lower(vCols(i).Column_Name)||'" to''ldirilishi shart.');
      end if;
    end loop;

    if vUsed = 0 then
      Ipt_Methods.Raise_Error('Saqlash uchun birorta ham maydon berilmagan.');
    end if;

    if vIsNew then
      vSql := 'insert into '||vDict.Table_Name||
              ' ('||vDict.Pk_Column||vInsCols||')'||
              ' values (:pk'||vInsVals||')';
    else
      vSql := 'update '||vDict.Table_Name||' set '||vSet||
              ' where '||vDict.Pk_Column||' = :pk';
    end if;

    vCursor := dbms_sql.open_cursor;

    begin
      dbms_sql.parse(vCursor, vSql, dbms_sql.native);
      dbms_sql.bind_variable(vCursor, 'pk', vPk);

      for i in 1 .. vUsed
      loop
        if vBound(i) in ('N', 'B') then
          dbms_sql.bind_variable(vCursor, 'v'||i, to_number(vVals(i)));
        else
          dbms_sql.bind_variable(vCursor, 'v'||i, vVals(i));
        end if;
      end loop;

      vDummy := dbms_sql.execute(vCursor);
      dbms_sql.close_cursor(vCursor);
    exception
      when others then
        if dbms_sql.is_open(vCursor) then
          dbms_sql.close_cursor(vCursor);
        end if;
        raise;
    end;

    -- commit YO'Q: tranzaksiyani Core_App.Set_Method boshqaradi va xatoda
    -- rollback qiladi. Bu yerda commit qilsak o'sha rollback foydasiz bo'ladi.
    vResponse.put('oper', true);
    vResponse.put('dict', vDict.Code);
    vResponse.put('code', vPk);
    vResponse.put('action', case when vIsNew then 'I' else 'U' end);
    vResponse.put('message', case when vIsNew then 'Qator qo''shildi.' else 'Qator saqlandi.' end);

    oResponse := vResponse.to_clob();
  end;

  --Cr By: Arslonbek Kulmatov
  --Qatorni o'chirish.
  --
  --Ishlatilayotgan kodni o'chirishni FK to'sadi. Xom ORA-02292 o'rniga
  --tushunarli xabar beramiz: xodim nima qilish kerakligini bilsin.
  Procedure Delete_Row(iParams clob, oResponse out clob)
  is
    vParams   json_object_t := Get_Params(iParams);
    vResponse json_object_t := json_object_t();
    vDict     ipt_s_dictionaries%rowtype;
    vPk       varchar2(4000);
    vExists   pls_integer;
  begin
    Check_Access;

    vDict := Get_Dict(Json_Scalar(vParams, 'dict'));
    vPk   := trim(Json_Scalar(vParams, 'code'));

    if vPk is null then
      Ipt_Methods.Raise_Error('"code" ko''rsatilmagan.');
    end if;

    if vDict.Can_Delete = 'N' then
      Ipt_Methods.Raise_Error('"'||vDict.Name_Ru||'" ma''lumotnomasidan o''chirib '||
                              'bo''lmaydi. '||nvl(vDict.Lock_Reason, '')||
                              ' Uning o''rniga qatorni nofaol qiling.');
    end if;

    execute immediate
      'select count(*) from '||vDict.Table_Name||' where '||vDict.Pk_Column||' = :p'
      into vExists using vPk;

    if vExists = 0 then
      Ipt_Methods.Raise_Error('Bunday qator yo''q: '||vPk);
    end if;

    begin
      execute immediate
        'delete from '||vDict.Table_Name||' where '||vDict.Pk_Column||' = :p'
        using vPk;
    exception
      when eChild_Found then
        Ipt_Methods.Raise_Error('"'||vPk||'" kodi ishlatilgan, o''chirib bo''lmaydi. '||
                                'Uning o''rniga qatorni nofaol qiling — shunda u '||
                                'yangi yozuvlarda tanlanmaydi, eskilari esa joyida qoladi.');
    end;

    vResponse.put('oper', true);
    vResponse.put('dict', vDict.Code);
    vResponse.put('code', vPk);
    vResponse.put('message', 'Qator o''chirildi.');

    oResponse := vResponse.to_clob();
  end;

end Ipt_Dictionary;
/


-- =============================================================================
-- 4. METODLARNI RO'YXATGA OLISH
--
-- add_log: o'qish metodlarida 'N', yozish metodlarida 'Y' — ma'lumotnoma
-- o'zgarishi kam bo'ladi, lekin kim o'zgartirgani bilinishi kerak.
-- =============================================================================

prompt 4.1 core_methods

merge into core_methods t
using (
  select 'dictList' method, 'Ipt_Dictionary.Get_List' proc_name, 'N' add_log,
         'Ma''lumotnomalar ro''yxati va ustunlari' details, 1 seq from dual
  union all
  select 'dictRows', 'Ipt_Dictionary.Get_Rows', 'N',
         'Ma''lumotnoma qatorlari', 2 from dual
  union all
  select 'dictSave', 'Ipt_Dictionary.Save_Row', 'Y',
         'Ma''lumotnoma qatorini qo''shish yoki tahrirlash', 3 from dual
  union all
  select 'dictDelete', 'Ipt_Dictionary.Delete_Row', 'Y',
         'Ma''lumotnoma qatorini o''chirish', 4 from dual
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
-- 5. TEKSHIRISH
--
-- 5.1 Paket kompilyatsiya bo'ldimi:
--
--   select object_name, status from user_objects
--    where object_name = 'IPT_DICTIONARY';
--
-- 5.2 Ro'yxat:
--
--   declare v clob;
--   begin
--     Ipt_Dictionary.Get_List('{"params":{}}', v);
--     dbms_output.put_line(substr(v, 1, 4000));
--   end;
--   /
--
-- 5.3 Qatorlar:
--
--   declare v clob;
--   begin
--     Ipt_Dictionary.Get_Rows('{"params":{"dict":"colors"}}', v);
--     dbms_output.put_line(substr(v, 1, 4000));
--   end;
--   /
--
-- 5.4 Bloklangan ma'lumotnomaga qo'shishga urinish — xato kutiladi:
--
--   declare v clob;
--   begin
--     Ipt_Dictionary.Save_Row(
--       '{"params":{"dict":"trade_states","code":"99","values":{"name":"Test","condition":"A"}}}', v);
--   end;
--   /
--
-- 5.5 Yangi ma'lumotnoma qo'shish — kod o'zgarmaydi, ikki qator yetadi:
--
--   insert into ipt_s_dictionaries(code, table_name, name_ru, name_uz, state_column, ord)
--   values ('my_dict', 'IPT_S_MY_DICT', 'Мой справочник', 'Mening ma''lumotnomam', 'CONDITION', 200);
--
--   insert into ipt_s_dictionary_cols(dict_code, column_name, name_ru, name_uz, data_type, max_len, is_required, ord)
--   values ('my_dict', 'NAME', 'Название', 'Nomi', 'S', 500, 'Y', 10);
--   commit;
-- =============================================================================
