-- =============================================================================
-- IPT_CATALOG_PARSE — tovar nomidan katalog maydonlarini TAXMIN qilish
--
-- Omborchi nomga hamma narsani yozib qo'ygan:
--   iPhone 17 Pro Max 256Gb Silver sim+esim New imei 073349
--   iPhone 16 Pro Max 256Gb Desert esim B/K 89% imei 567102
--   iWatch 11 46mm Jet Black seria JJFJX03WQY
-- Model, xotira, rang, SIM, holat, batareya va IMEI shu yerda bor — faqat
-- alohida maydonlarga ajratilmagan. Qo'lda ko'chirish haftalar oladi.
--
-- NIMA QILADI
--   IPT_CATALOG_PARSE_V — har qator uchun asl nom va yonida TAXMIN qilingan
--   qiymatlar. Hech narsa yozmaydi, faqat ko'rsatadi.
--
-- NIMA QILMAYDI
--   Avtomatik qo'llamaydi. Yuklamada "Desert"/"Desret", "imei"/"imie" kabi
--   xatolar bor; narx esa nomda umuman yo'q. Xodim ekranda ko'z bilan
--   tekshirib, to'g'rilarini belgilab catalogSaveProduct bilan qo'llaydi.
--
-- QOIDALAR KODDA EMAS
--   Rang, bozor kodi, brend va kategoriya IPT_S_PARSE_ALIASES jadvalidan
--   o'qiladi. Yangi rang yoki model uchrasa — jadvalga qator qo'shiladi,
--   paket qayta kompilyatsiya qilinmaydi.
--
-- ISHGA TUSHIRISH: ipt_catalog_stage6.sql dan keyin.
--
-- Muallif: Arslonbek Kulmatov
-- Sana   : 21.09.2026
-- =============================================================================

prompt 1.0 Ipt_Dictionary ga seq_name ustuni

-- 5-bo'limda bu jadval ma'lumotnomalar formasiga ulanadi. Kaliti sun'iy son
-- bo'lgani uchun formaga "kodni o'zi qo'yadigan" ma'lumotnoma kerak — buni
-- IPT_S_DICTIONARIES.SEQ_NAME beradi.
--
-- Ustun allaqachon bo'lsa ORA-01430 chiqadi, zararsiz — o'tib keting.
-- Shundan keyin db/ipt_dictionary.sql ning 3-bo'limini (paket) qayta
-- kompilyatsiya qilish SHART: eski paket seq_name ni bilmaydi.
alter table IPT_S_DICTIONARIES add (seq_name VARCHAR2(60));
comment on column IPT_S_DICTIONARIES.seq_name
  is 'Son kod uchun ketma-ketlik nomi. Berilgan bo''lsa forma kodni so''ramaydi, baza o''zi qo''yadi';


prompt 1.1 IPT_S_PARSE_ALIASES

-- Kalit sun'iy son: "alias_type + alias" juftligi tabiiy kalit bo'lardi,
-- lekin ma'lumotnomalar formasi bitta ustunli kalit bilan ishlaydi. Juftlik
-- takrorlanmasligini UK ta'minlaydi.
create sequence IPT_S_PARSE_ALIASES_SEQ start with 1 increment by 1 nocache;

create table IPT_S_PARSE_ALIASES
(
  id         NUMBER(12) not null,
  alias_type VARCHAR2(20) not null,
  alias      VARCHAR2(100) not null,
  value      VARCHAR2(40) not null,
  condition  VARCHAR2(2) default 'A' not null
)
;
comment on table IPT_S_PARSE_ALIASES
  is 'Tovar nomini tahlil qilish uchun moslik jadvali. Yangi nom uchrasa shu yerga qator qo''shiladi';
comment on column IPT_S_PARSE_ALIASES.alias_type
  is 'color, market, brand, category';
comment on column IPT_S_PARSE_ALIASES.alias
  is 'Nomda uchraydigan matn. So''z chegarasi bo''yicha qidiriladi: "ja" "Jet" ichiga tushmaydi';
comment on column IPT_S_PARSE_ALIASES.value
  is 'Tegishli ma''lumotnoma kodi';
alter table IPT_S_PARSE_ALIASES
  add constraint IPT_S_PARSE_ALIASES_PK primary key (ID);
alter table IPT_S_PARSE_ALIASES
  add constraint IPT_S_PARSE_ALIASES_UK unique (ALIAS_TYPE, ALIAS);
alter table IPT_S_PARSE_ALIASES
  add constraint IPT_S_PARSE_TYPE_CHK
  check (alias_type in ('color', 'market', 'brand', 'category'));
alter table IPT_S_PARSE_ALIASES
  add constraint IPT_S_PARSE_COND_CHK check (condition in ('A', 'P'));
-- Alias to'g'ridan-to'g'ri regexp ichiga qo'yiladi. Shuning uchun faqat
-- harf, raqam, probel, "/" va "-" ruxsat: "*" yoki "(" kabi belgi tahlilni
-- buzardi. Solishtirish lower() bilan ketgani uchun bosh harf zarar qilmaydi.
alter table IPT_S_PARSE_ALIASES
  add constraint IPT_S_PARSE_ALIAS_CHK
  check (regexp_like(alias, '^[A-Za-z0-9 /-]+$'));

-- =============================================================================
-- 2. MOSLIKLAR
--
-- Uzunroq alias birinchi tekshiriladi: "Rose Gold" "Gold" dan ustun,
-- "Jet Black" "Black" dan ustun.
-- =============================================================================

prompt 2.1 Ranglar

merge into ipt_s_parse_aliases t
using (
  select 'color' tp, 'silver' al, 'silver' vl from dual union all
  select 'color', 'kumush',           'silver' from dual union all
  select 'color', 'space black',      'space-black' from dual union all
  select 'color', 'space gray',       'gray' from dual union all
  select 'color', 'soace gray',       'gray' from dual union all
  select 'color', 'jet black',        'space-black' from dual union all
  select 'color', 'black',            'black' from dual union all
  select 'color', 'qora',             'black' from dual union all
  select 'color', 'midnight',         'black' from dual union all
  select 'color', 'white',            'white' from dual union all
  select 'color', 'oq',               'white' from dual union all
  select 'color', 'starlight',        'white' from dual union all
  select 'color', 'desert',           'desert' from dual union all
  select 'color', 'desret',           'desert' from dual union all
  select 'color', 'natural',          'natural-titanium' from dual union all
  select 'color', 'blue titanium',    'blue-titanium' from dual union all
  select 'color', 'deep blue',        'deep-blue' from dual union all
  select 'color', 'blue',             'deep-blue' from dual union all
  select 'color', 'rose gold',        'pink' from dual union all
  select 'color', 'gold',             'gold' from dual union all
  select 'color', 'oltin',            'gold' from dual union all
  select 'color', 'green',            'green' from dual union all
  select 'color', 'yashil',           'green' from dual union all
  select 'color', 'pink',             'pink' from dual union all
  select 'color', 'purple',           'purple' from dual union all
  select 'color', 'red',              'red' from dual union all
  select 'color', 'gray',             'gray' from dual union all
  select 'color', 'grey',             'gray' from dual union all
  select 'color', 'kulrang',          'gray' from dual
) s
on (t.alias_type = s.tp and t.alias = s.al)
when matched then
  update set t.value = s.vl, t.condition = 'A'
when not matched then
  insert (id, alias_type, alias, value, condition)
  values (ipt_s_parse_aliases_seq.nextval, s.tp, s.al, s.vl, 'A');

prompt 2.2 Bozor kodlari

merge into ipt_s_parse_aliases t
using (
  select 'market' tp, 'll/a' al, 'LL/A' vl from dual union all
  select 'market', 'lla',  'LL/A' from dual union all
  select 'market', 'kh/a', 'KHA'  from dual union all
  select 'market', 'kha',  'KHA'  from dual union all
  select 'market', 'ru/a', 'RUA'  from dual union all
  select 'market', 'rua',  'RUA'  from dual union all
  select 'market', 'lz/a', 'LZA'  from dual union all
  select 'market', 'lza',  'LZA'  from dual union all
  select 'market', 'ja',   'JA'   from dual union all
  select 'market', 'j/a',  'JA'   from dual union all
  select 'market', 'za',   'ZA'   from dual union all
  select 'market', 'ae',   'AE'   from dual
) s
on (t.alias_type = s.tp and t.alias = s.al)
when matched then
  update set t.value = s.vl, t.condition = 'A'
when not matched then
  insert (id, alias_type, alias, value, condition)
  values (ipt_s_parse_aliases_seq.nextval, s.tp, s.al, s.vl, 'A');

prompt 2.3 Brendlar

merge into ipt_s_parse_aliases t
using (
  select 'brand' tp, 'iphone' al, 'apple' vl from dual union all
  select 'brand', 'ipad',        'apple' from dual union all
  select 'brand', 'macbook',     'apple' from dual union all
  select 'brand', 'imac',        'apple' from dual union all
  select 'brand', 'iwatch',      'apple' from dual union all
  select 'brand', 'apple watch', 'apple' from dual union all
  select 'brand', 'airpods',     'apple' from dual union all
  select 'brand', 'samsung',     'samsung' from dual union all
  select 'brand', 'redmi',       'xiaomi' from dual union all
  select 'brand', 'xiaomi',      'xiaomi' from dual union all
  select 'brand', 'poco',        'xiaomi' from dual union all
  select 'brand', 'dyson',       'dyson' from dual union all
  select 'brand', 'baseus',      'baseus' from dual union all
  select 'brand', 'hoco',        'hoco' from dual union all
  select 'brand', 'anker',       'anker' from dual union all
  select 'brand', 'ldnio',       'other' from dual union all
  select 'brand', 'wiwu',        'other' from dual union all
  select 'brand', 'playstation', 'other' from dual union all
  select 'brand', 'ps5',         'other' from dual union all
  select 'brand', 'asus',        'other' from dual
) s
on (t.alias_type = s.tp and t.alias = s.al)
when matched then
  update set t.value = s.vl, t.condition = 'A'
when not matched then
  insert (id, alias_type, alias, value, condition)
  values (ipt_s_parse_aliases_seq.nextval, s.tp, s.al, s.vl, 'A');

prompt 2.4 Kategoriyalar

-- Ishlatilgan texnika uchun "-bu" qo'shimchasini view o'zi qo'yadi
merge into ipt_s_parse_aliases t
using (
  select 'category' tp, 'iphone' al, 'iphone' vl from dual union all
  select 'category', 'ipad',        'ipad' from dual union all
  select 'category', 'macbook',     'mac' from dual union all
  select 'category', 'imac',        'mac' from dual union all
  select 'category', 'iwatch',      'apple-watch' from dual union all
  select 'category', 'apple watch', 'apple-watch' from dual union all
  select 'category', 'airpods',     'airpods' from dual union all
  select 'category', 'samsung',     'samsung' from dual union all
  select 'category', 'redmi',       'samsung' from dual union all
  select 'category', 'dyson',       'dyson' from dual union all
  select 'category', 'playstation', 'gadgets' from dual union all
  select 'category', 'ps5',         'gadgets' from dual union all
  select 'category', 'djostik',     'gadgets' from dual union all
  select 'category', 'holder',      'acc-car' from dual union all
  select 'category', 'socket',      'acc-chargers' from dual union all
  select 'category', 'power',       'acc-chargers' from dual union all
  select 'category', 'chexol',      'acc-cases' from dual union all
  select 'category', 'case',        'acc-cases' from dual
) s
on (t.alias_type = s.tp and t.alias = s.al)
when matched then
  update set t.value = s.vl, t.condition = 'A'
when not matched then
  insert (id, alias_type, alias, value, condition)
  values (ipt_s_parse_aliases_seq.nextval, s.tp, s.al, s.vl, 'A');

commit;

-- =============================================================================
-- 3. IPT_CATALOG_PARSE PAKETI
-- =============================================================================

prompt 3.1 Ipt_Catalog_Parse — spetsifikatsiya

create or replace package Ipt_Catalog_Parse is

  -- Author  : Arslonbek Kulmatov
  -- Created : 21.09.2026
  -- Purpose : Tovar nomidan katalog maydonlarini taxmin qilish

  Function Norm(iText varchar2) return varchar2;
  Function Lookup(iType varchar2, iName varchar2) return varchar2;
  Function Storage_Gb(iName varchar2) return number;
  Function Ram_Gb(iName varchar2) return number;
  Function Battery_Pct(iName varchar2) return number;
  Function Imei(iName varchar2) return varchar2;
  Function Serial_No(iName varchar2) return varchar2;
  Function Sim_Type(iName varchar2) return varchar2;
  Function Item_Condition(iName varchar2) return varchar2;
  Function Model_Name(iName varchar2) return varchar2;
  Function Model_Code(iName varchar2) return varchar2;

end Ipt_Catalog_Parse;
/

prompt 3.2 Ipt_Catalog_Parse — tanasi

create or replace package body Ipt_Catalog_Parse is

  --Cr By: Arslonbek Kulmatov
  --Qidirish uchun matnni tayyorlash.
  --
  --Harf, raqam va "/", "+", "-" qoladi, qolgani probel bo'ladi. Ikki
  --tomondan probel qo'shiladi, shunda " ja " ni qidirganda "Jet" ichiga
  --tushmaydi — bozor kodi bilan rang nomi chalkashmasligi uchun.
  Function Norm(iText varchar2) return varchar2
  is
  begin
    -- Ketma-ket probellar yig'iladi: "Rose  Gold" ham " rose gold " bo'ladi,
    -- aks holda ikki so'zli alias topilmay qolardi.
    return ' '||regexp_replace(
                  regexp_replace(lower(iText), '[^a-z0-9/+-]', ' '),
                  ' +', ' ')||' ';
  end;

  --Cr By: Arslonbek Kulmatov
  --Moslik jadvalidan qidirish. Uzunroq alias ustun: "rose gold" "gold" dan,
  --"jet black" "black" dan oldin tekshiriladi.
  Function Lookup(iType varchar2, iName varchar2) return varchar2
  is
    vHay varchar2(4000) := Norm(iName);
    vVal varchar2(40);
  begin
    for rows in (select a.alias, a.value
                   from ipt_s_parse_aliases a
                  where a.alias_type = iType
                    and a.condition = 'A'
                  order by length(a.alias) desc, a.alias)
    loop
      if instr(vHay, ' '||lower(rows.alias)||' ') > 0 then
        return rows.value;
      end if;
    end loop;

    return null;
  end;

  --Cr By: Arslonbek Kulmatov
  --Xotira. "8/128Gb" da ikkinchi son, "256 gb" da yagona son, "2 TB" da
  --1024 ga ko'paytiriladi.
  Function Storage_Gb(iName varchar2) return number
  is
    vTxt varchar2(20);
  begin
    vTxt := regexp_substr(iName, '(\d+)\s*/\s*(\d+)\s*g\s*b', 1, 1, 'i', 2);

    if vTxt is null then
      vTxt := regexp_substr(iName, '(\d+)\s*g\s*b', 1, 1, 'i', 1);
    end if;

    if vTxt is null then
      vTxt := regexp_substr(iName, '(\d+)\s*t\s*b', 1, 1, 'i', 1);
      if vTxt is not null then
        return to_number(vTxt) * 1024;
      end if;
    end if;

    return to_number(vTxt);
  exception
    when others then
      return null;
  end;

  --Cr By: Arslonbek Kulmatov
  --Operativ xotira. Faqat "16/512Gb" ko'rinishidan olinadi
  Function Ram_Gb(iName varchar2) return number
  is
  begin
    return to_number(regexp_substr(iName, '(\d+)\s*/\s*(\d+)\s*g\s*b', 1, 1, 'i', 1));
  exception
    when others then
      return null;
  end;

  Function Battery_Pct(iName varchar2) return number
  is
    vNum number;
  begin
    vNum := to_number(regexp_substr(iName, '(\d{1,3})\s*%', 1, 1, null, 1));

    if vNum between 1 and 100 then
      return vNum;
    end if;

    return null;
  exception
    when others then
      return null;
  end;

  --Cr By: Arslonbek Kulmatov
  --IMEI. Faqat raqamli qism olinadi: "imei 073349" ham, "imei445809" ham
  Function Imei(iName varchar2) return varchar2
  is
  begin
    return regexp_substr(iName, 'im[ei]{2}\s*(\d{4,})', 1, 1, 'i', 1);
  end;

  --Cr By: Arslonbek Kulmatov
  --Seriya raqami: "seria JJFJX03WQY", yoki "imei" dan keyin raqam emas,
  --harf-raqam aralash kelsa (Dyson: imei 5PK-XD-UMA0929A)
  Function Serial_No(iName varchar2) return varchar2
  is
    vTxt varchar2(50);
  begin
    vTxt := regexp_substr(iName, 'seria\s+([A-Za-z0-9-]{6,})', 1, 1, 'i', 1);

    if vTxt is null then
      vTxt := regexp_substr(iName, 'im[ei]{2}\s*([A-Za-z0-9-]{6,})', 1, 1, 'i', 1);

      -- Raqamdan iborat bo'lsa u IMEI, seriya emas
      if vTxt is not null and regexp_like(vTxt, '^\d+$') then
        return null;
      end if;
    end if;

    return vTxt;
  end;

  --Cr By: Arslonbek Kulmatov
  --SIM turi. Tartib muhim: "sim+esim" ni "esim" dan oldin tekshirish kerak
  Function Sim_Type(iName varchar2) return varchar2
  is
    vHay varchar2(4000) := Norm(iName);
  begin
    if regexp_like(vHay, 'sim\s*\+\s*e-?sim|dual\s*\+\s*e-?sim') then
      return 'sim_esim';
    end if;

    if instr(vHay, ' dual ') > 0 or instr(vHay, ' 2-sim ') > 0 then
      return 'dual';
    end if;

    if instr(vHay, ' 1-sim ') > 0 or instr(vHay, ' single ') > 0 then
      return 'single';
    end if;

    if instr(vHay, ' esim ') > 0 or instr(vHay, ' e-sim ') > 0 then
      return 'esim';
    end if;

    return null;
  end;

  --Cr By: Arslonbek Kulmatov
  --Holati.
  --
  --Batareya foizi bo'lsa — ishlatilgan: yangi telefonda uni yozmaydilar.
  --Aks holda "New" so'zi qaraladi. Ikkalasi ham bo'lmasa NULL — xodim
  --o'zi hal qilsin, taxmin qilgandan ko'ra bo'sh qoldirgan yaxshi.
  Function Item_Condition(iName varchar2) return varchar2
  is
    vHay varchar2(4000) := Norm(iName);
  begin
    if Battery_Pct(iName) is not null then
      return 'used';
    end if;

    if instr(vHay, ' new ') > 0 then
      return 'new';
    end if;

    return null;
  end;

  --Cr By: Arslonbek Kulmatov
  --Model nomi: tanilgan bo'laklarni olib tashlab, qolganini qaytaradi.
  --
  --"iPhone 17 Pro Max 256Gb Silver sim+esim New imei 073349" dan
  --"iPhone 17 Pro Max" qoladi.
  Function Model_Name(iName varchar2) return varchar2
  is
    vTxt varchar2(1000) := iName;
    vVal varchar2(40);
  begin
    -- IMEI va seriya
    vTxt := regexp_replace(vTxt, 'im[ei]{2}\s*[A-Za-z0-9-]*', ' ', 1, 0, 'i');
    vTxt := regexp_replace(vTxt, 'seria\s*[A-Za-z0-9-]*', ' ', 1, 0, 'i');
    -- xotira va ram
    vTxt := regexp_replace(vTxt, '\d+\s*/\s*\d+\s*g\s*b', ' ', 1, 0, 'i');
    vTxt := regexp_replace(vTxt, '\d+\s*g\s*b', ' ', 1, 0, 'i');
    vTxt := regexp_replace(vTxt, '\d+\s*t\s*b', ' ', 1, 0, 'i');
    -- batareya, holat, SIM
    vTxt := regexp_replace(vTxt, '\d{1,3}\s*%', ' ', 1, 0);
    -- Oracle regexp'da \b (so'z chegarasi) YO'Q. Chegara belgilar sinfi
    -- bilan yoziladi; chegara belgisining o'zi probelga almashsa ham zarar
    -- yo'q, baribir probel qo'yayapmiz.
    vTxt := regexp_replace(vTxt, '(^|[^a-z0-9])b\s*/\s*k([^a-z0-9]|$)', ' ', 1, 0, 'i');
    vTxt := regexp_replace(vTxt, '(^|[^a-z0-9])new([^a-z0-9]|$)', ' ', 1, 0, 'i');
    vTxt := regexp_replace(vTxt, 'sim\s*\+\s*e-?sim', ' ', 1, 0, 'i');
    vTxt := regexp_replace(vTxt,
              '(^|[^a-z0-9])(\d-sim|e-?sim|dual|single)([^a-z0-9]|$)', ' ', 1, 0, 'i');

    -- Rang va bozor kodi: topilganini nomdan olib tashlaymiz
    for rows in (select a.alias
                   from ipt_s_parse_aliases a
                  where a.alias_type in ('color', 'market')
                    and a.condition = 'A'
                  order by length(a.alias) desc)
    loop
      vTxt := regexp_replace(vTxt,
                '(^|[^a-z0-9])'||lower(rows.alias)||'([^a-z0-9]|$)', ' ', 1, 0, 'i');
    end loop;

    -- Ketma-ket probellarni yig'ib, chetlarini kesamiz
    vTxt := trim(regexp_replace(vTxt, '\s+', ' '));

    return case when length(vTxt) < 2 then null else vTxt end;
  end;

  --Cr By: Arslonbek Kulmatov
  --Model kodi: kichik harf, harf-raqamdan boshqasi chiziqchaga aylanadi
  Function Model_Code(iName varchar2) return varchar2
  is
    vTxt varchar2(1000) := Model_Name(iName);
  begin
    if vTxt is null then
      return null;
    end if;

    vTxt := lower(vTxt);
    vTxt := regexp_replace(vTxt, '[^a-z0-9]+', '-');
    vTxt := trim(both '-' from vTxt);
    vTxt := regexp_replace(vTxt, '-+', '-');

    return case when length(vTxt) < 2 then null else substr(vTxt, 1, 200) end;
  end;

end Ipt_Catalog_Parse;
/

-- =============================================================================
-- 4. TAKLIFLAR VIEW'I
--
-- Faqat vitrina filiallari: no_site_code = 'N' bo'lgan qatorlar.
-- Hech narsa yozmaydi.
-- =============================================================================

prompt 4.1 IPT_CATALOG_PARSE_V

create or replace force view ipt_catalog_parse_v as
with src as (
  select t.id,
         t.name,
         t.filial_code,
         t.quantity,
         Ipt_Catalog_Parse.Model_Name(t.name)      p_model_name,
         Ipt_Catalog_Parse.Model_Code(t.name)      p_model_code,
         Ipt_Catalog_Parse.Item_Condition(t.name)  p_condition,
         Ipt_Catalog_Parse.Storage_Gb(t.name)      p_storage_gb,
         Ipt_Catalog_Parse.Ram_Gb(t.name)          p_ram_gb,
         Ipt_Catalog_Parse.Battery_Pct(t.name)     p_battery_pct,
         Ipt_Catalog_Parse.Imei(t.name)            p_imei,
         Ipt_Catalog_Parse.Serial_No(t.name)       p_serial,
         Ipt_Catalog_Parse.Sim_Type(t.name)        p_sim_type,
         Ipt_Catalog_Parse.Lookup('color',  t.name) p_color_code,
         Ipt_Catalog_Parse.Lookup('market', t.name) p_market_code,
         Ipt_Catalog_Parse.Lookup('brand',  t.name) p_brand_code,
         Ipt_Catalog_Parse.Lookup('category', t.name) p_category_base
    from ipt_products t
   where t.state = 'S'
     and nvl(t.quantity, 0) > 0
     and t.model_code is null
     and (select f.site_code
            from ipt_s_filials f
           where f.code = nvl(t.phys_filial_code, t.filial_code)) is not null
)
select
  s.id,
  s.name,
  s.filial_code,
  s.quantity,
  s.p_model_code,
  s.p_model_name,
  s.p_brand_code,
  -- Ishlatilgan texnika alohida bo'limga tushadi: iphone -> iphone-bu.
  -- Bunday bo'lim bo'lmasa asl kategoriya qoladi.
  case when s.p_condition = 'used'
        and exists (select 1 from ipt_s_categories c
                     where c.code = s.p_category_base||'-bu'
                       and c.condition = 'A')
       then s.p_category_base||'-bu'
       else s.p_category_base
  end                    p_category_code,
  s.p_condition,
  s.p_storage_gb,
  s.p_ram_gb,
  s.p_color_code,
  s.p_sim_type,
  s.p_market_code,
  s.p_battery_pct,
  s.p_imei,
  s.p_serial,
  -- Nechta asosiy maydon topilgani. 5 dan pasti — nomni ko'z bilan
  -- tekshirish kerak degani.
  (case when s.p_model_code    is not null then 1 else 0 end +
   case when s.p_category_base is not null then 1 else 0 end +
   case when s.p_brand_code    is not null then 1 else 0 end +
   case when s.p_condition     is not null then 1 else 0 end +
   case when s.p_storage_gb    is not null then 1 else 0 end +
   case when s.p_color_code    is not null then 1 else 0 end) topildi
  from src s
;

-- =============================================================================
-- 5. MA'LUMOTNOMALAR FORMASIGA ULASH
--
-- ipt_dictionary.sql ishga tushirilmagan bo'lsa bu blokni o'tkazib yuboring.
-- =============================================================================

-- Kalit — sun'iy ID. Xodim uni yozmaydi, seq_name berilgani uchun forma
-- kod maydonini umuman ko'rsatmaydi (dictList javobida auto_code = true).
prompt 5.1 Ipt_Dictionary

merge into ipt_s_dictionaries t
using (
  select 'parse_aliases' code, 'IPT_S_PARSE_ALIASES' tab,
         'Правила разбора названий' nm_ru, 'Nom tahlili qoidalari' nm_uz,
         'ID' pkc, 'N' pk, 'IPT_S_PARSE_ALIASES_SEQ' sq,
         'CONDITION' st, 'ALIAS_TYPE' oc, 'Y' ins, 'Y' del,
         null lck, 300 ord from dual
) s
on (t.code = s.code)
when matched then
  update set t.table_name = s.tab, t.name_ru = s.nm_ru, t.name_uz = s.nm_uz,
             t.pk_column = s.pkc, t.pk_type = s.pk, t.pk_max_len = null,
             t.seq_name = s.sq,
             t.state_column = s.st, t.order_column = s.oc,
             t.can_insert = s.ins, t.can_delete = s.del,
             t.lock_reason = s.lck, t.ord = s.ord, t.condition = 'A'
when not matched then
  insert (code, table_name, name_ru, name_uz, pk_column, pk_type, seq_name,
          state_column, order_column, can_insert, can_delete, lock_reason,
          ord, condition)
  values (s.code, s.tab, s.nm_ru, s.nm_uz, s.pkc, s.pk, s.sq,
          s.st, s.oc, s.ins, s.del, s.lck, s.ord, 'A');

prompt 5.2 Ipt_Dictionary — ustunlar

merge into ipt_s_dictionary_cols t
using (
  select 'parse_aliases' d, 'ALIAS_TYPE' c, 'Что ищем' nr, 'Nima qidiriladi' nu,
         'L' dt, 20 ml, 'Y' rq,
         'color:Rang;market:Bozor kodi;brand:Brend;category:Kategoriya' lov,
         10 ord from dual union all
  select 'parse_aliases', 'ALIAS', 'Текст в названии', 'Nomdagi matn',
         'S', 100, 'Y', null, 20 from dual union all
  select 'parse_aliases', 'VALUE', 'Код справочника', 'Ma''lumotnoma kodi',
         'S', 40, 'Y', null, 30 from dual union all
  select 'parse_aliases', 'CONDITION', 'Состояние', 'Holati',
         'L', null, 'N', 'A:Faol;P:Nofaol', 40 from dual
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
-- 6. TEKSHIRISH
--
-- 6.1 Taxminlar qanday chiqyapti:
--
--   select id, name, p_model_code, p_storage_gb, p_color_code,
--          p_condition, p_sim_type, p_battery_pct, p_imei, topildi
--     from ipt_catalog_parse_v
--    order by topildi desc, id;
--
-- 6.2 Yomon tahlil qilinganlar — nomni ko'z bilan ko'rish kerak:
--
--   select id, name, topildi from ipt_catalog_parse_v
--    where topildi <= 3 order by id;
--
-- 6.3 Qaysi model kodlari chiqdi va nechtadan:
--
--   select p_model_code, count(*) from ipt_catalog_parse_v
--    where p_model_code is not null
--    group by p_model_code order by count(*) desc;
--
-- Bu ro'yxat ommaviy to'ldirish uchun eng qulay: bir xil model kodini
-- olgan qatorlarni belgilab, catalogSaveProduct bilan birdan qo'yasiz.
-- =============================================================================
