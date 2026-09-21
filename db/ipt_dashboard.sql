-- =============================================================================
-- IPT_DASHBOARD — ABM Store boshqaruv paneli uchun hisobot API
--
-- Talablar: "Monello API integratsiyasi - texnik talablar", ABM Store
-- nazorat paneli uchun.
--
-- ISHGA TUSHIRISH TARTIBI
--   db/ipt_catalog_stage2.sql dan KEYIN (core_api_tokens o'sha yerda yaratiladi)
--
-- NIMA BERILADI
--   1. Mijozlar — filial kesimida, davr bo'yicha yangilari
--   2. Qarzdorlik — filial va kun kesimida, muddat guruhlari bilan
--   3. Kechikkanlar — sdelkalar ro'yxati, necha kun va qancha summa
--   4. Sdelkalar dinamikasi — davr bo'yicha yangi sdelkalar va summalar
--
-- NIMA BERILMAYDI VA NEGA
--   Skoring/konversiya (tasdiqlangan va rad etilgan arizalar foizi) —
--   Monello'da ariza degan tushuncha yo'q, sotuvchi sdelkani to'g'ridan-to'g'ri
--   ochadi. ipt_clients.scoring_value esa sdelka TO'LANGANDAN KEYIN qo'yiladigan
--   1-5 ballik qo'lda baho, ya'ni boshqa narsa. Buning o'rniga sdelkalar
--   dinamikasida bekor qilingan va qaytarib olinganlar soni beriladi.
--
--   Mijoz telefoni, PINFL va manzili ataylab CHIQARILMAYDI. Dashboard'ga
--   "necha mijoz, necha kun kechikkan" kerak, shaxsiy ma'lumot emas.
--
-- VALYUTA
--   Barcha summalar DOLLARDA. Sababi: qarz kanonik ravishda USD da yuritiladi
--   (ipt_trade_graphs.payment_amount), som esa hosila. Mavjud kunlik hisobot
--   (ipt_report_by_filials_v_t) ham dollarda. Somga o'girish uchun javobda
--   o'sha kungi kurs ham beriladi.
--
-- Muallif: Arslonbek Kulmatov
-- Sana   : 18.09.2026
-- =============================================================================


-- =============================================================================
-- 1. TOKEN QAMROVI
--
-- Hozircha istalgan token istalgan metodga kirardi. Ya'ni sayt jamoasiga
-- berilgan katalog tokeni qarzdorlik va mijoz ismlarini ham o'qiy olardi.
-- Qamrov ajratilmasa bu ma'lumot sizib chiqishi aniq.
-- =============================================================================

prompt 1.1 CORE_API_TOKENS.scope

alter table CORE_API_TOKENS add
(
  scope VARCHAR2(50) default 'catalog' not null
);

comment on column CORE_API_TOKENS.scope
  is 'Token qaysi API''ga kiradi: catalog — sayt katalogi, report — boshqaruv paneli. Bitta tokenda bitta qamrov: alohida iste''molchiga alohida token, shunda birini bekor qilish ikkinchisiga tegmaydi';

alter table CORE_API_TOKENS
  add constraint CORE_API_TOKENS_SCOPE_CHK
  check (scope in ('catalog', 'report'));

-- Mavjud tokenlar katalog uchun berilgan edi — default shuni qo'yadi.


-- =============================================================================
-- 2. VIEW
--
-- Kechikkanlar ro'yxati. Mavjud ipt_dc_v va sheriklaridan foydalanib bo'lmaydi:
-- ular QO'NG'IROQ ro'yxatlari, qarzdorlar reyestri emas. Ularda
--   - core_session.Get_Filial_Code filtri bor (dashboard'ga hamma filial kerak)
--   - bugun gaplashilganlar chiqarib tashlanadi
--   - to'lash va'da qilganlar ham chiqarib tashlanadi
-- Dashboard uchun esa kechikkanlarning HAMMASI kerak.
-- =============================================================================

prompt 2.1 IPT_DASHBOARD_OVERDUE_V

create or replace force view ipt_dashboard_overdue_v as
select *
  from (select
          t.id        trade_id,
          t.client_id,
          (select c.name
             from ipt_clients c
            where c.id = t.client_id) client_name,
          t.filial_code,
          (select f.name
             from ipt_s_filials f
            where f.code = t.filial_code) filial_name,
          -- Funksiya bir marta chaqiriladi va tashqi so'rovda filtrlanadi.
          -- where ichida qayta chaqirilsa har satr uchun ikki barobar ish bo'lardi.
          ipt_util.Get_Pros_Days(iTrade_Id => t.id, iDate => trunc(sysdate)) overdue_days,
          ipt_util.Get_Trade_Current_Debt(iTrade_Id => t.id)/100 overdue_amount,
          ipt_util.Get_Trade_All_Debt(iTrade_Id => t.id)/100     total_debt,
          t.ip_date   trade_date,
          t.currency_code,
          t.payment_term/100 payment_term
          from ipt_trades t
         -- 03 to'langan, 05 yashirin, 06 bekor, 07 qaytarilgan
         where t.state not in ('03', '05', '06', '07'))
 where overdue_days > 0
;

comment on table IPT_DASHBOARD_OVERDUE_V
  is 'Kechikkan sdelkalar, barcha filiallar bo''yicha. Telefon, PINFL va manzil ataylab yo''q';


-- =============================================================================
-- 3. IPT_DASHBOARD PAKETI
-- =============================================================================

prompt 3.1 Ipt_Dashboard — spetsifikatsiya

create or replace package Ipt_Dashboard is

  -- Author  : Arslonbek Kulmatov
  -- Created : 18.09.2026
  -- Purpose : ABM Store boshqaruv paneli uchun hisobot API

  --Cr By: Arslonbek Kulmatov
  --Mijozlar soni, filial kesimida
  Procedure Get_Clients(iParams clob, oResponse out clob);

  --Cr By: Arslonbek Kulmatov
  --Qarzdorlik, filial va kun kesimida
  Procedure Get_Debt(iParams clob, oResponse out clob);

  --Cr By: Arslonbek Kulmatov
  --Kechikkan sdelkalar ro'yxati
  Procedure Get_Overdue(iParams clob, oResponse out clob);

  --Cr By: Arslonbek Kulmatov
  --Sdelkalar dinamikasi, davr bo'yicha
  Procedure Get_Trades(iParams clob, oResponse out clob);

end Ipt_Dashboard;
/


prompt 3.2 Ipt_Dashboard — tanasi

create or replace package body Ipt_Dashboard is

  cMax_Per_Page constant number := 1000;

  -- ===========================================================================
  -- Yordamchilar
  --
  -- Ipt_Catalog dagilarning nusxasi. Ular o'sha yerda private, bu paket esa
  -- katalogga bog'lanmasligi kerak — katalogdagi o'zgarish hisobotni
  -- buzmasligi uchun. Ipt_Util keyingi safar tahrirlanganda o'sha yerga
  -- ko'chirilsa, ikkala paket ham undan foydalanadi.
  -- ===========================================================================

  --Cr By: Arslonbek Kulmatov
  --Parametrlar obyekti: {"method":..,"params":{..}}
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

  Procedure Put_Num(ioObj in out nocopy json_object_t, iKey varchar2, iVal number)
  is
  begin
    if iVal is not null then
      ioObj.put(iKey, iVal);
    end if;
  end;

  --Cr By: Arslonbek Kulmatov
  --YYYY-MM-DD sanani o'qish
  Function Parse_Date(iValue varchar2) return date
  is
    vTxt varchar2(50) := trim(iValue);
  begin
    if vTxt is null then
      return null;
    end if;

    return to_date(substr(vTxt, 1, 10), 'YYYY-MM-DD');
  exception
    when others then
      Ipt_Methods.Raise_Error('Sana formati noto''g''ri: '||iValue||
                              '. Kutilgan format: 2026-09-18');
  end;

  Function To_Iso_Day(iDate date) return varchar2
  is
  begin
    return to_char(iDate, 'YYYY-MM-DD');
  end;

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
  --Javob asosi: har javobda so'rov qachon bajarilgani va valyuta bo'ladi.
  --Dashboard raqamni ko'rsatganda "qaysi payt holati" deb yozishi uchun.
  Function New_Response return json_object_t
  is
    vResp json_object_t := json_object_t();
  begin
    vResp.put('as_of', To_Iso(sysdate));
    return vResp;
  end;

  --Cr By: Arslonbek Kulmatov
  --Hisobot ko'rish huquqi.
  --
  --Bu paketda filial filtri ATAYLAB yo'q: boshqaruv paneliga hamma filial
  --kerak. Lekin metodlar core_methods da ro'yxatda turibdi, ya'ni ularni
  --/api/app/request orqali ISTALGAN tizimga kirgan foydalanuvchi ham
  --chaqira oladi. Tekshiruvsiz qolsa oddiy sotuvchi butun tarmoqning
  --qarzdorlik raqamlarini va mijozlar reyestrini ko'rib qolardi.
  --
  --Shuning uchun: faqat "report" qamrovli token egasi. Amalda bu
  --/api/report/* yo'li — token qaysi foydalanuvchiga berilgan bo'lsa,
  --sessiya ham o'shaniki.
  Procedure Check_Access
  is
    vCount pls_integer;
  begin
    select count(*) into vCount
      from core_api_tokens t
     where t.user_id   = core_session.Get_User_Id
       and t.scope     = 'report'
       and t.condition = 'A';

    if vCount = 0 then
      Ipt_Methods.Raise_Error('Bu hisobotni ko''rish uchun ruxsat yo''q. '||
                              'Hisobot API si "report" qamrovli token bilan ishlaydi.');
    end if;
  end;
  -- Monello web ga ham nazorat paneli kerak bo'lsa shu yerga rol sharti
  -- qo'shiladi, masalan:
  --     or ipt_util.Has_Access_For_Role(<rahbariyat roli>) = 1
  -- Rol raqamini men bilmayman, shuning uchun qo'ymadim: noto'g'ri raqam
  -- qo'yilsa tekshiruv borga o'xshab turadi, lekin hech kimni to'smaydi.

  --Cr By: Arslonbek Kulmatov
  --Davr chegaralari. Berilmasa — joriy oy boshidan bugungacha.
  Procedure Read_Period(iParams json_object_t,
                        oFrom   out date,
                        oTo     out date)
  is
  begin
    oFrom := Parse_Date(iParams.get_String('date_from'));
    oTo   := Parse_Date(iParams.get_String('date_to'));

    if oFrom is null then
      oFrom := trunc(sysdate, 'MM');
    end if;

    if oTo is null then
      oTo := trunc(sysdate);
    end if;

    if oFrom > oTo then
      Ipt_Methods.Raise_Error('"date_from" "date_to" dan katta bo''lishi mumkin emas.');
    end if;
  end;

  -- ===========================================================================
  -- Metodlar
  -- ===========================================================================

  --Cr By: Arslonbek Kulmatov
  --Mijozlar soni, filial kesimida.
  --
  --with_active_trade — ochiq sdelkasi bor mijozlar. "Jami mijoz" va "hozir
  --nasiyada turgan mijoz" dashboard uchun ikki xil raqam, ikkalasi ham kerak.
  Procedure Get_Clients(iParams clob, oResponse out clob)
  is
    vParams   json_object_t := Get_Params(iParams);
    vResponse json_object_t := New_Response;
    vRows     json_array_t  := json_array_t();
    vRow      json_object_t;
    vFilial   varchar2(10);
    vFrom     date;
    vTo       date;
  begin
    Check_Access;

    Read_Period(vParams, vFrom, vTo);
    vFilial := trim(vParams.get_String('filial_code'));

    vResponse.put('date_from', To_Iso_Day(vFrom));
    vResponse.put('date_to',   To_Iso_Day(vTo));

    -- Ochiq sdelka borligi ichki so'rovda hisoblanadi: agregat ichidagi
    -- EXISTS Oracle'da ishonchsiz, rownum = 1 esa birinchi moslikda to'xtaydi.
    for rows in (select
                   f.code filial_code,
                   f.name filial_name,
                   count(c.id) total_clients,
                   count(case when c.condition = 'A' then 1 end) active_clients,
                   count(case when c.cr_on_day between vFrom and vTo then 1 end) new_clients,
                   nvl(sum(c.has_active_trade), 0) with_active_trade
                   from ipt_s_filials f
                   left join (select
                                cl.id,
                                cl.filial_code,
                                cl.condition,
                                trunc(cl.cr_on) cr_on_day,
                                (select count(*)
                                   from ipt_trades t
                                  where t.client_id = cl.id
                                    and t.state not in ('03', '05', '06', '07')
                                    and rownum = 1) has_active_trade
                                from ipt_clients cl) c
                     on c.filial_code = f.code
                  where (vFilial is null or f.code = vFilial)
                  group by f.code, f.name
                  order by f.code)
    loop
      vRow := json_object_t();
      vRow.put('filial_code', rows.filial_code);
      Put_Str(vRow, 'filial_name', rows.filial_name);
      vRow.put('total_clients', rows.total_clients);
      vRow.put('active_clients', rows.active_clients);
      vRow.put('new_clients', rows.new_clients);
      vRow.put('with_active_trade', rows.with_active_trade);
      vRows.append(vRow);
    end loop;

    vResponse.put('rows', vRows);
    oResponse := vResponse.to_clob();
  end;

  --Cr By: Arslonbek Kulmatov
  --Qarzdorlik, filial va kun kesimida.
  --
  --Manba — ipt_report_by_filials_v_t, kunlik snapshot jadvali. U har kuni
  --KECHAGI kun uchun to'ldiriladi (Ipt_Report.Insert_Data_By_Filial_Job),
  --shuning uchun ertalabki so'rov kechagi yopilgan raqamlarni oladi.
  --
  --Joriy holatni qayta hisoblamaymiz ataylab: Get_Pros_Days har sdelka uchun
  --grafikni aylanib chiqadi va butun portfel bo'yicha bu og'ir. Snapshot esa
  --tayyor turibdi va kun davomida o'zgarmaydi — dashboard uchun aynan shu kerak.
  Procedure Get_Debt(iParams clob, oResponse out clob)
  is
    vParams   json_object_t := Get_Params(iParams);
    vResponse json_object_t := New_Response;
    vRows     json_array_t  := json_array_t();
    vRow      json_object_t;
    vFilial   varchar2(10);
    vFrom     date;
    vTo       date;
    vLast_Day date;
  begin
    Check_Access;

    vFilial := trim(vParams.get_String('filial_code'));
    vFrom   := Parse_Date(vParams.get_String('date_from'));
    vTo     := Parse_Date(vParams.get_String('date_to'));

    -- Davr berilmasa — faqat oxirgi mavjud kun. Dashboard odatda joriy
    -- holatni so'raydi, butun tarixni emas.
    if vFrom is null and vTo is null then
      select max(t.calc_day) into vLast_Day from ipt_report_by_filials_v_t t;
      vFrom := vLast_Day;
      vTo   := vLast_Day;
    else
      vFrom := nvl(vFrom, vTo);
      vTo   := nvl(vTo, vFrom);
    end if;

    if vFrom is not null and vFrom > vTo then
      Ipt_Methods.Raise_Error('"date_from" "date_to" dan katta bo''lishi mumkin emas.');
    end if;

    vResponse.put('currency', 'USD');
    Put_Num(vResponse, 'rate_usd', ipt_util.Get_Rate('840'));
    Put_Str(vResponse, 'date_from', To_Iso_Day(vFrom));
    Put_Str(vResponse, 'date_to',   To_Iso_Day(vTo));

    for rows in (select
                   t.calc_day,
                   t.code filial_code,
                   t.name filial_name,
                   t.graph_amount,
                   t.paid_amount,
                   t.debt_30,
                   t.debt_31_60,
                   t.debt_61_90,
                   t.debt_90_more,
                   t.total_debt
                   from ipt_report_by_filials_v_t t
                  where t.calc_day between vFrom and vTo
                    and (vFilial is null or t.code = vFilial)
                  order by t.calc_day desc, t.code)
    loop
      vRow := json_object_t();
      vRow.put('calc_day', To_Iso_Day(rows.calc_day));
      vRow.put('filial_code', rows.filial_code);
      Put_Str(vRow, 'filial_name', rows.filial_name);
      Put_Num(vRow, 'graph_amount', rows.graph_amount);
      Put_Num(vRow, 'paid_amount', rows.paid_amount);
      Put_Num(vRow, 'debt_30', rows.debt_30);
      Put_Num(vRow, 'debt_31_60', rows.debt_31_60);
      Put_Num(vRow, 'debt_61_90', rows.debt_61_90);
      Put_Num(vRow, 'debt_90_more', rows.debt_90_more);
      Put_Num(vRow, 'total_debt', rows.total_debt);
      vRows.append(vRow);
    end loop;

    vResponse.put('rows', vRows);
    oResponse := vResponse.to_clob();
  end;

  --Cr By: Arslonbek Kulmatov
  --Kechikkan sdelkalar ro'yxati.
  --
  --min_days bilan chegaralash mumkin: masalan 30 dan katta kechikkanlar.
  --Sahifalash bor, chunki portfel kattalashsa ro'yxat ham kattalashadi.
  Procedure Get_Overdue(iParams clob, oResponse out clob)
  is
    vParams   json_object_t := Get_Params(iParams);
    vResponse json_object_t := New_Response;
    vRows     json_array_t  := json_array_t();
    vRow      json_object_t;
    vFilial   varchar2(10);
    vMin_Days number;
    vPage     number;
    vPerPage  number;
    vOffset   number;
    vTotal    number;
    vSum      number;
  begin
    Check_Access;

    vFilial   := trim(vParams.get_String('filial_code'));
    vMin_Days := nvl(vParams.get_Number('min_days'), 1);
    vPage     := nvl(vParams.get_Number('page'), 1);
    vPerPage  := nvl(vParams.get_Number('per_page'), 200);

    if vPage < 1 then
      Ipt_Methods.Raise_Error('"page" 1 dan kichik bo''lishi mumkin emas.');
    end if;

    if vPerPage < 1 or vPerPage > cMax_Per_Page then
      Ipt_Methods.Raise_Error('"per_page" 1 va '||cMax_Per_Page||' oralig''ida bo''lishi kerak.');
    end if;

    vOffset := (vPage - 1) * vPerPage;

    select count(*), nvl(sum(v.overdue_amount), 0)
      into vTotal, vSum
      from ipt_dashboard_overdue_v v
     where v.overdue_days >= vMin_Days
       and (vFilial is null or v.filial_code = vFilial);

    vResponse.put('currency', 'USD');
    vResponse.put('total_trades', vTotal);
    vResponse.put('total_amount', vSum);
    vResponse.put('min_days', vMin_Days);
    vResponse.put('page', vPage);
    vResponse.put('per_page', vPerPage);

    for rows in (select v.*
                   from ipt_dashboard_overdue_v v
                  where v.overdue_days >= vMin_Days
                    and (vFilial is null or v.filial_code = vFilial)
                  order by v.overdue_days desc, v.trade_id
                 offset vOffset rows fetch next vPerPage rows only)
    loop
      vRow := json_object_t();
      vRow.put('trade_id', to_char(rows.trade_id));
      vRow.put('client_id', to_char(rows.client_id));
      Put_Str(vRow, 'client_name', rows.client_name);
      Put_Str(vRow, 'filial_code', rows.filial_code);
      Put_Str(vRow, 'filial_name', rows.filial_name);
      vRow.put('overdue_days', rows.overdue_days);
      Put_Num(vRow, 'overdue_amount', rows.overdue_amount);
      Put_Num(vRow, 'total_debt', rows.total_debt);
      Put_Str(vRow, 'trade_date', To_Iso_Day(rows.trade_date));
      Put_Num(vRow, 'payment_term', rows.payment_term);
      vRows.append(vRow);
    end loop;

    vResponse.put('rows', vRows);
    oResponse := vResponse.to_clob();
  end;

  --Cr By: Arslonbek Kulmatov
  --Sdelkalar dinamikasi, davr bo'yicha.
  --
  --cancelled_count va returned_count — konversiya o'rniga beriladigan narsa.
  --Monello'da ariza tasdiqlash bosqichi yo'q, lekin sotilgandan keyin bekor
  --qilingan va qaytarib olingan sdelkalar soni sifat ko'rsatkichi sifatida
  --ishlaydi.
  Procedure Get_Trades(iParams clob, oResponse out clob)
  is
    vParams   json_object_t := Get_Params(iParams);
    vResponse json_object_t := New_Response;
    vRows     json_array_t  := json_array_t();
    vRow      json_object_t;
    vFilial   varchar2(10);
    vFrom     date;
    vTo       date;
  begin
    Check_Access;

    Read_Period(vParams, vFrom, vTo);
    vFilial := trim(vParams.get_String('filial_code'));

    vResponse.put('currency', 'USD');
    vResponse.put('date_from', To_Iso_Day(vFrom));
    vResponse.put('date_to',   To_Iso_Day(vTo));

    for rows in (select
                   f.code filial_code,
                   f.name filial_name,
                   count(t.id) trades_count,
                   nvl(sum(t.product_new_price), 0)/100 sold_amount,
                   nvl(sum(t.initial_payment), 0)/100   initial_amount,
                   nvl(sum(t.ip_amount), 0)/100         financed_amount,
                   count(case when t.state = '06' then 1 end) cancelled_count,
                   count(case when t.state = '07' then 1 end) returned_count
                   -- Sana sharti ON ichida: WHERE ga qo'yilsa tashqi birikma
                   -- ichkiga aylanadi va o'sha davrda sotuvi yo'q filial
                   -- javobdan butunlay tushib qoladi.
                   from ipt_s_filials f
                   left join ipt_trades t
                     on t.filial_code = f.code
                    and trunc(nvl(t.ip_date, t.cr_on)) between vFrom and vTo
                  where (vFilial is null or f.code = vFilial)
                  group by f.code, f.name
                  order by f.code)
    loop
      vRow := json_object_t();
      vRow.put('filial_code', rows.filial_code);
      Put_Str(vRow, 'filial_name', rows.filial_name);
      vRow.put('trades_count', rows.trades_count);
      Put_Num(vRow, 'sold_amount', rows.sold_amount);
      Put_Num(vRow, 'initial_amount', rows.initial_amount);
      Put_Num(vRow, 'financed_amount', rows.financed_amount);
      vRow.put('cancelled_count', rows.cancelled_count);
      vRow.put('returned_count', rows.returned_count);
      vRows.append(vRow);
    end loop;

    vResponse.put('rows', vRows);
    oResponse := vResponse.to_clob();
  end;

end Ipt_Dashboard;
/


-- =============================================================================
-- 4. METODLARNI RO'YXATGA OLISH
--
-- add_log = 'N': dashboard kuniga bir marta so'raydi, lekin agregatlar og'ir
-- bo'lishi mumkin — javobni core_api_log ga yozishdan foyda yo'q.
-- =============================================================================

prompt 4.1 core_methods

merge into core_methods t
using (
  select 'reportClients' method, 'Ipt_Dashboard.Get_Clients' proc_name,
         'Dashboard: mijozlar filial kesimida' details, 1 seq from dual
  union all
  select 'reportDebt', 'Ipt_Dashboard.Get_Debt',
         'Dashboard: qarzdorlik filial va kun kesimida', 2 from dual
  union all
  select 'reportOverdue', 'Ipt_Dashboard.Get_Overdue',
         'Dashboard: kechikkan sdelkalar ro''yxati', 3 from dual
  union all
  select 'reportTrades', 'Ipt_Dashboard.Get_Trades',
         'Dashboard: sdelkalar dinamikasi', 4 from dual
) s
on (lower(t.method) = lower(s.method))
when matched then
  update set t.proc_name = s.proc_name,
             t.details   = s.details,
             t.state     = 'A'
when not matched then
  insert (id, method, proc_name, state, has_out_param, is_func, add_log, details, cr_on)
  values ((select nvl(max(m.id), 0) from core_methods m) + s.seq,
          s.method, s.proc_name, 'A', 'Y', 'N', 'N', s.details, sysdate);

commit;


-- =============================================================================
-- 5. TOKEN YARATISH
--
-- Dashboard uchun ALOHIDA token, katalognikidan boshqa. Shunda birini bekor
-- qilish ikkinchisiga tegmaydi va sayt jamoasi qarzdorlik ma'lumotini ko'ra
-- olmaydi.
--
--   openssl rand -hex 32
--
--   insert into core_api_tokens(id, name, token_hash, user_id, scope, condition, cr_by, cr_on)
--   values ((select nvl(max(id), 0) + 1 from core_api_tokens),
--           'ABM Store boshqaruv paneli',
--           lower(rawtohex(standard_hash('BU_YERGA_TOKEN', 'SHA256'))),
--           :user_id,
--           'report',        -- MUHIM: katalog tokenidan farqi shu
--           'A',
--           :user_id,
--           sysdate);
--   commit;
--
-- Tekshirish:
--   select id, name, scope, condition from core_api_tokens;
--
-- =============================================================================


-- =============================================================================
-- 6. ISHGA TUSHIRGANDAN KEYIN TEKSHIRISH
--
-- 6.1 Kunlik snapshot jobi ishlayaptimi? Qarzdorlik metodi butunlay shunga
--     tayanadi — job qo'yilmagan bo'lsa jadval bo'sh yoki eskirgan bo'ladi.
--
--       select max(calc_day), count(*) from ipt_report_by_filials_v_t;
--
--       select job_name, enabled, state, last_start_date, next_run_date
--         from user_scheduler_jobs;
--
--     Agar job yo'q bo'lsa, har kuni ertalab (dashboard so'rovidan OLDIN)
--     ishga tushadigan qilib qo'yiladi:
--
--       begin
--         dbms_scheduler.create_job(
--           job_name        => 'IPT_REPORT_BY_FILIAL_JOB',
--           job_type        => 'PLSQL_BLOCK',
--           job_action      => 'begin Ipt_Report.Insert_Data_By_Filial_Job; end;',
--           start_date      => trunc(sysdate) + 1 + 6/24,
--           repeat_interval => 'FREQ=DAILY; BYHOUR=6; BYMINUTE=0',
--           enabled         => true);
--       end;
--       /
--
-- 6.2 Metodlarni bazadan sinash:
--
--       declare v clob;
--       begin
--         Ipt_Dashboard.Get_Debt('{"params":{}}', v);
--         dbms_output.put_line(substr(v, 1, 4000));
--       end;
--       /
--
-- 6.3 Kechikkanlar view'i sekin ishlasa: u Get_Pros_Days ni har sdelka uchun
--     chaqiradi. Portfel kattalashganda kunlik snapshot qilish kerak bo'ladi —
--     qarzdorlik uchun qilinganidek.
-- =============================================================================
