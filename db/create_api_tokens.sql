-- =============================================================================
-- TASHQI TIZIMLAR UCHUN API TOKEN YARATISH
--
-- Ikkita iste'molchi uchun ikkita alohida token:
--   catalog — ABM Store sayti,          /api/catalog/*
--   report  — ABM Store boshqaruv paneli, /api/report/*
--
-- ALOHIDA bo'lishi shart. Bitta token ikkalasiga berilsa, sayt jamoasi
-- mijoz ismlari va qarzdorlik ma'lumotini ham o'qiy oladi.
--
-- OLDIN ISHGA TUSHIRILGAN BO'LISHI KERAK
--   db/ipt_catalog_stage2.sql  — core_api_tokens jadvali
--   db/ipt_dashboard.sql       — scope ustuni
--
-- =============================================================================
-- TOKEN BILAN ISHLASH QOIDALARI
--
-- 1. Token bazada OCHIQ SAQLANMAYDI — faqat SHA-256 xeshi. Ya'ni uni
--    bazadan tiklab bo'lmaydi, hatto siz ham.
--
-- 2. Shuning uchun tokenni SHU FAYLGA YOZMANG. Quyidagi skript uni ishga
--    tushirish paytida so'raydi (&&token_value), fayl ichida qolmaydi.
--
-- 3. Tokenni iste'molchiga BIR MARTA xavfsiz kanal orqali bering va
--    o'zingizda saqlamang. Telegram yoki elektron pochtaga tashlamang —
--    ular tarixda qoladi.
--
-- 4. Yo'qolsa yoki sizib chiqsa: yangisini yaratasiz, eskisini
--    condition = 'P' ga o'tkazasiz. 5-bo'limga qarang.
--
-- 5. Kichik nuqta, lekin bilib qo'ying: skript ishga tushganda token
--    bajarilgan SQL matnining ichida ketadi va bir muddat v$sql da
--    ko'rinishi mumkin. U o'z-o'zidan eskirib yo'qoladi. Buni butunlay
--    chetlab o'tish kerak bo'lsa — 1-bo'limdagi VARIANT B: token bazaning
--    o'zida generatsiya qilinadi va SQL matniga umuman tushmaydi.
-- =============================================================================

set define on
set verify off
set serveroutput on size unlimited


-- =============================================================================
-- 0. XIZMAT FOYDALANUVCHISINI TANLASH
--
-- Token qaysidir core_users nomidan ishlaydi: loglar va sessiya o'shanga
-- yoziladi. Administrator hisobini BERMANG — sayt jamoasi ham buni so'ragan.
--
-- Eng to'g'risi: ilovaning foydalanuvchi formasidan "ABM API" kabi alohida
-- xizmat hisobi ochib, uning id sini shu yerda ishlatish. Unga hech qanday
-- rol berilmasa ham bo'ladi — token metodlari rol tekshirmaydi.
--
-- Mavjudlarini ko'rish:
--
--   select user_id, login, first_name, last_name, state
--     from core_users
--    where state = 'A'
--    order by user_id;
--
-- Tanlangan id ni quyidagi ikkala blokda &&service_user_id sifatida
-- kiritasiz.
-- =============================================================================


-- =============================================================================
-- 1. TOKENNI QANDAY GENERATSIYA QILISH
--
-- VARIANT A — terminal orqali (tavsiya etiladi)
--
--   openssl rand -hex 32
--
--   Windows PowerShell da:
--     -join ((1..32) | % { '{0:x2}' -f (Get-Random -Max 256) })
--
--   Chiqqan 64 belgili qatorni pastdagi skript so'raganda kiritasiz.
--
--
-- VARIANT B — bazaning o'zida
--
--   Agar dbms_crypto ga huquqingiz bo'lsa (grant execute on dbms_crypto),
--   quyidagi blok token generatsiya qilib ekranga chiqaradi. U hech qayerda
--   saqlanmaydi — faqat chiqish oynasida turadi:
--
--     declare
--       vBytes raw(32);
--     begin
--       execute immediate 'begin :b := dbms_crypto.randombytes(32); end;'
--         using out vBytes;
--       dbms_output.put_line('TOKEN: '||lower(rawtohex(vBytes)));
--     end;
--     /
--
--   dbms_random ISHLATMANG: u kriptografik emas va tokenni taxmin qilish
--   mumkin bo'lib qoladi.
-- =============================================================================


-- =============================================================================
-- 2. SAYT UCHUN TOKEN — qamrov "catalog"
-- =============================================================================

prompt
prompt === SAYT TOKENI ===
prompt

declare
  cName   constant varchar2(200) := 'ABM Store sayti';
  cScope  constant varchar2(50)  := 'catalog';

  vToken  varchar2(200) := '&&token_catalog';
  vUser   number        := &&service_user_id;
  vId     number;
  vCount  pls_integer;
begin
  vToken := trim(vToken);

  -- Qisqa token — tokenning o'zi yo'qligidan yomonroq: xavfsizlik bor deb
  -- o'ylanadi, aslida yo'q.
  if length(vToken) < 32 then
    raise_application_error(-20000,
      'Token juda qisqa ('||length(vToken)||' belgi). Kamida 32 belgi kerak. '||
      '1-bo''limdagi usul bilan generatsiya qiling.');
  end if;

  -- Faqat ASCII harf, raqam, "-" va "_". Sabab shunchaki tozalik emas:
  -- Oracle standard_hash tokenni BAZA kodlashida, Java esa UTF-8 da xeshlaydi.
  -- ASCII da ikkalasi bir xil bayt beradi, undan tashqarida esa xeshlar
  -- farq qilib, token hech qachon ishlamaydi — sababi esa topilmaydi.
  if not regexp_like(vToken, '^[A-Za-z0-9_-]+$') then
    raise_application_error(-20000,
      'Tokenda ruxsat etilmagan belgi bor. Faqat ASCII harf, raqam, "-" va "_" '||
      'bo''lishi kerak. openssl rand -hex 32 aynan shunday chiqaradi.');
  end if;

  select count(*) into vCount
    from core_users t
   where t.user_id = vUser;

  if vCount = 0 then
    raise_application_error(-20000, 'Bunday foydalanuvchi yo''q: '||vUser);
  end if;

  -- Bir xil nomdagi faol token borligini tekshiramiz: jimgina ikkinchisini
  -- yaratsak, qaysi biri kimda ekani chalkashib ketadi.
  select count(*) into vCount
    from core_api_tokens t
   where t.name = cName
     and t.condition = 'A';

  if vCount > 0 then
    raise_application_error(-20000,
      '"'||cName||'" nomi bilan faol token allaqachon bor. '||
      'Avval uni bekor qiling (5-bo''limga qarang), keyin yangisini yarating.');
  end if;

  select nvl(max(t.id), 0) + 1 into vId from core_api_tokens t;

  insert into core_api_tokens(id, name, token_hash, user_id, scope, condition, cr_by, cr_on)
  values (vId,
          cName,
          lower(rawtohex(standard_hash(vToken, 'SHA256'))),
          vUser,
          cScope,
          'A',
          vUser,
          sysdate);

  commit;

  -- Tokenning O'ZI chiqarilmaydi: u sizda allaqachon bor, ekranga qayta
  -- chiqarish esa uni loglar va skrinshotlarga tarqatadi.
  dbms_output.put_line('Token yaratildi.');
  dbms_output.put_line('  id     : '||vId);
  dbms_output.put_line('  nomi   : '||cName);
  dbms_output.put_line('  qamrov : '||cScope);
  dbms_output.put_line('  user_id: '||vUser);
  dbms_output.put_line('Endi uni sayt jamoasiga xavfsiz kanal orqali bering.');
end;
/


-- =============================================================================
-- 3. BOSHQARUV PANELI UCHUN TOKEN — qamrov "report"
-- =============================================================================

prompt
prompt === DASHBOARD TOKENI ===
prompt

declare
  cName   constant varchar2(200) := 'ABM Store boshqaruv paneli';
  cScope  constant varchar2(50)  := 'report';

  vToken  varchar2(200) := '&&token_report';
  vUser   number        := &&service_user_id;
  vId     number;
  vCount  pls_integer;
begin
  vToken := trim(vToken);

  if length(vToken) < 32 then
    raise_application_error(-20000,
      'Token juda qisqa ('||length(vToken)||' belgi). Kamida 32 belgi kerak.');
  end if;

  -- Faqat ASCII harf, raqam, "-" va "_". Sabab shunchaki tozalik emas:
  -- Oracle standard_hash tokenni BAZA kodlashida, Java esa UTF-8 da xeshlaydi.
  -- ASCII da ikkalasi bir xil bayt beradi, undan tashqarida esa xeshlar
  -- farq qilib, token hech qachon ishlamaydi — sababi esa topilmaydi.
  if not regexp_like(vToken, '^[A-Za-z0-9_-]+$') then
    raise_application_error(-20000,
      'Tokenda ruxsat etilmagan belgi bor. Faqat ASCII harf, raqam, "-" va "_" '||
      'bo''lishi kerak. openssl rand -hex 32 aynan shunday chiqaradi.');
  end if;

  -- Ikkala tokenning bir xil bo'lishi qamrovni ma'nosiz qiladi
  if lower(vToken) = lower(trim('&&token_catalog')) then
    raise_application_error(-20000,
      'Dashboard tokeni sayt tokeni bilan bir xil. Har biri uchun alohida '||
      'token generatsiya qiling — aks holda qamrovni ajratishdan foyda yo''q.');
  end if;

  select count(*) into vCount
    from core_api_tokens t
   where t.name = cName
     and t.condition = 'A';

  if vCount > 0 then
    raise_application_error(-20000,
      '"'||cName||'" nomi bilan faol token allaqachon bor. Avval uni bekor qiling.');
  end if;

  select nvl(max(t.id), 0) + 1 into vId from core_api_tokens t;

  insert into core_api_tokens(id, name, token_hash, user_id, scope, condition, cr_by, cr_on)
  values (vId,
          cName,
          lower(rawtohex(standard_hash(vToken, 'SHA256'))),
          vUser,
          cScope,
          'A',
          vUser,
          sysdate);

  commit;

  dbms_output.put_line('Token yaratildi.');
  dbms_output.put_line('  id     : '||vId);
  dbms_output.put_line('  nomi   : '||cName);
  dbms_output.put_line('  qamrov : '||cScope);
  dbms_output.put_line('  user_id: '||vUser);
  dbms_output.put_line('Endi uni dashboard jamoasiga xavfsiz kanal orqali bering.');
end;
/

undefine token_catalog
undefine token_report
undefine service_user_id


-- =============================================================================
-- 4. TEKSHIRISH
--
-- Tokenlar ro'yxati. token_hash ataylab ko'rsatilmaydi — u kerak emas.
--
--   select id, name, scope, user_id, condition, cr_on
--     from core_api_tokens
--    order by id;
--
-- Kutilgani: ikkita qator, biri catalog, ikkinchisi report, ikkalasi 'A'.
--
--
-- API ishlayotganini tekshirish:
--
--   curl -i -H "Authorization: Bearer <sayt_tokeni>" \
--        "https://<manzil>/api/catalog/stock"
--
--   curl -i -H "Authorization: Bearer <dashboard_tokeni>" \
--        "https://<manzil>/api/report/debt"
--
--
-- QAMROV ISHLAYOTGANINI tekshirish — buni albatta qiling.
-- Sayt tokeni bilan hisobot so'raymiz, 401 kutiladi:
--
--   curl -i -H "Authorization: Bearer <sayt_tokeni>" \
--        "https://<manzil>/api/report/debt"
--
-- Agar 200 qaytsa — qamrov ishlamayapti va sayt jamoasi qarzdorlik
-- ma'lumotini ko'rmoqda. Darhol to'xtating.
-- =============================================================================


-- =============================================================================
-- 5. BEKOR QILISH VA ALMASHTIRISH
--
-- Bekor qilish — bir zumda kuchga kiradi, ilovani qayta ishga tushirish
-- shart emas:
--
--   update core_api_tokens set condition = 'P', up_on = sysdate
--    where id = ?;
--   commit;
--
--
-- Almashtirish (token sizib chiqqanda yoki muddatli almashtirishda):
--   1. Eskisini yuqoridagidek 'P' ga o'tkazasiz
--   2. Shu skriptni qayta ishga tushirasiz, yangi token bilan
--   3. Yangisini iste'molchiga berasiz
--
-- Almashtirish paytida qisqa uzilish bo'ladi: eski token o'chgandan yangisi
-- ularda sozlangunicha so'rovlar 401 qaytaradi. Sayt bunga chidaydi — oxirgi
-- ma'lumotda ishlayveradi; dashboard esa kuniga bir marta so'raydi, shuning
-- uchun kun davomida almashtirsangiz sezilmaydi ham.
--
--
-- Tokenni O'CHIRMANG (delete), faqat 'P' ga o'tkazing: qachon va kim
-- yaratganini bilib turish keyin asqotadi.
-- =============================================================================
