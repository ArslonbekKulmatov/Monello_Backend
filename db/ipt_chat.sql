-- =============================================================================
-- IPT_CHAT — Monello chat formasi uchun o'qish tool'lari
--
-- Chat foydalanuvchining savoliga javob berish uchun shu paketdagi
-- metodlarni chaqiradi. Model SQL YOZMAYDI — faqat shu yerdagi qat'iy
-- parametrli metodlarni chaqira oladi. Sabab oddiy: model yozgan SQL ni
-- oldindan tekshirib bo'lmaydi, bu esa qarzdorlik bazasi.
--
-- UCH QOIDA
--   1. Hammasi FAQAT O'QISH. Bironta ham insert/update/delete yo'q.
--   2. Filial bo'yicha cheklangan. Mirobod sotuvchisi Sebzor qarzdorlarini
--      ko'rmaydi — Filial_Scope shuni ta'minlaydi.
--   3. Shaxsiy ma'lumot CHIQMAYDI. ipt_clients da pinfl va address bor,
--      ular hech bir metodda tanlanmaydi. Mijoz ismi chiqadi, chunki
--      "kim qarzdor" degan savolning javobi shu.
--
-- QATOR CHEGARASI
--   Har metod qaytaradigan qator soni cheklangan va javobda "jami nechta,
--   nechtasi ko'rsatildi" yoziladi. Chegarasiz ro'yxat modelning kontekstini
--   to'ldiradi va har savol qimmatga tushadi.
--
-- ISHGA TUSHIRISH: ipt_dashboard.sql dan keyin (bog'liqlik yo'q, lekin
-- o'sha yerdagi ipt_dashboard_overdue_v dan foydalaniladi)
--
-- Muallif: Arslonbek Kulmatov
-- Sana   : 19.09.2026
-- =============================================================================

-- =============================================================================
-- 0. TOKEN QAMROVIGA "chat" QO'SHISH
--
-- MCP mijozlari (Claude Desktop va h.k.) shu qamrovli token bilan ulanadi.
-- Cheklov ipt_dashboard.sql da ('catalog', 'report') bilan qo'yilgan edi —
-- uni almashtiramiz.
--
-- DIQQAT: "chat" qamrovli tokenda sessiya filiali yo'q, ya'ni u BARCHA
-- filiallarni ko'radi. Sotuvchiga bermang.
-- =============================================================================

prompt 0.1 CORE_API_TOKENS.scope

alter table CORE_API_TOKENS drop constraint CORE_API_TOKENS_SCOPE_CHK;

alter table CORE_API_TOKENS
  add constraint CORE_API_TOKENS_SCOPE_CHK
  check (scope in ('catalog', 'report', 'chat'));

prompt Ipt_Chat — spetsifikatsiya

create or replace package Ipt_Chat is

  -- Author  : Arslonbek Kulmatov
  -- Created : 19.09.2026
  -- Purpose : Chat formasi uchun o'qish tool'lari

  --Cr By: Arslonbek Kulmatov
  --Filiallar va ularning joriy holati
  Procedure Get_Filials(iParams clob, oResponse out clob);

  --Cr By: Arslonbek Kulmatov
  --Savdolar: davr bo'yicha soni va summasi, filial kesimida
  Procedure Get_Sales(iParams clob, oResponse out clob);

  --Cr By: Arslonbek Kulmatov
  --Faol rassrochkalar ro'yxati
  Procedure Get_Installments(iParams clob, oResponse out clob);

  --Cr By: Arslonbek Kulmatov
  --Qarzdorlar: kechikkan sdelkalar
  Procedure Get_Debtors(iParams clob, oResponse out clob);

  --Cr By: Arslonbek Kulmatov
  --Bitta sdelka: shartlari va to'lov grafigi
  Procedure Get_Trade(iParams clob, oResponse out clob);

end Ipt_Chat;
/

prompt Ipt_Chat — tanasi

create or replace package body Ipt_Chat is

  -- Chat uchun qator chegarasi. Ko'p qator modelga foyda bermaydi:
  -- u baribir bir nechtasini o'qib xulosa qiladi, lekin hammasi uchun
  -- pul to'lanadi.
  cMax_Rows constant number := 30;

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

  Procedure Put_Num(ioObj in out nocopy json_object_t, iKey varchar2, iVal number)
  is
  begin
    if iVal is not null then
      ioObj.put(iKey, iVal);
    end if;
  end;

  --Cr By: Arslonbek Kulmatov
  --JSON dagi oddiy qiymatni matn sifatida o'qish.
  --Model son yuborishi ham, matn yuborishi ham mumkin — get_String faqat
  --matnda ishlaydi va sonni jimgina yo'qotadi.
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
      return case when iObj.get_Boolean(iKey) then 'true' else 'false' end;
    end if;
    return vEl.to_String;
  end;

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
      Ipt_Methods.Raise_Error('Sana formati noto''g''ri: '||iValue||'. Kutilgan: 2026-09-19');
  end;

  Function To_Iso_Day(iDate date) return varchar2
  is
  begin
    return to_char(iDate, 'YYYY-MM-DD');
  end;

  --Cr By: Arslonbek Kulmatov
  --Chat qaysi filiallarni ko'rsatishi mumkin.
  --
  --Sessiya filiali qaytadi — ya'ni foydalanuvchi o'z filialini ko'radi.
  --NULL qaytsa barcha filiallar ochiladi.
  --
  --Barcha filiallarni ko'radigan rol ajratilganda quyidagi satr ochiladi:
  --
  --  if ipt_util.Has_Access_For_Role(iRole_Id => <boshqaruvchi_rol_id>) > 0 then
  --    return null;
  --  end if;
  --
  --Bu YAGONA joy: qolgan metodlar shu funksiyaga tayanadi, shuning uchun
  --qamrovni bir joydan o'zgartirish yetarli.
  Function Filial_Scope return varchar2
  is
  begin
    return core_session.Get_Filial_Code;
  end;

  --Cr By: Arslonbek Kulmatov
  --Javob asosi: har javobda qamrov va valyuta ko'rsatiladi, shunda model
  --"bu raqam nimani anglatadi" deb taxmin qilmaydi.
  Function New_Response return json_object_t
  is
    vResp   json_object_t := json_object_t();
    vFilial varchar2(10)  := Filial_Scope;
  begin
    vResp.put('currency', 'USD');
    vResp.put('as_of', to_char(sysdate, 'YYYY-MM-DD"T"HH24:MI:SS'));
    if vFilial is null then
      vResp.put('scope', 'barcha filiallar');
    else
      vResp.put('scope', 'filial '||vFilial);
      vResp.put('filial_code', vFilial);
    end if;
    return vResp;
  end;

  --Cr By: Arslonbek Kulmatov
  --Davr chegaralari. Berilmasa — joriy oy boshidan bugungacha.
  Procedure Read_Period(iParams json_object_t, oFrom out date, oTo out date)
  is
  begin
    oFrom := Parse_Date(Json_Scalar(iParams, 'date_from'));
    oTo   := Parse_Date(Json_Scalar(iParams, 'date_to'));
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

  --Cr By: Arslonbek Kulmatov
  --Sdelka holati kodining o'qiladigan nomi. Model kod bilan emas, nom bilan
  --javob bersin.
  Function State_Name(iState varchar2) return varchar2
  is
  begin
    return case iState
             when '01' then 'faol'
             when '02' then 'muddati o''tgan'
             when '03' then 'to''langan'
             when '04' then 'qo''lda tuzatilgan'
             when '05' then 'yashirin'
             when '06' then 'bekor qilingan'
             when '07' then 'qaytarilgan'
             else iState
           end;
  end;

  -- ===========================================================================
  -- Tool'lar
  -- ===========================================================================

  --Cr By: Arslonbek Kulmatov
  --Filiallar va ularning joriy holati.
  --Parametrlar yo'q — foydalanuvchi qamroviga qarab qaytadi.
  Procedure Get_Filials(iParams clob, oResponse out clob)
  is
    vResponse json_object_t := New_Response;
    vRows     json_array_t  := json_array_t();
    vRow      json_object_t;
    vFilial   varchar2(10)  := Filial_Scope;
  begin
    Ipt_Methods.Check_For_Seller;
    for rows in (select
                   f.code,
                   f.name,
                   f.site_code,
                   (select count(*)
                      from ipt_trades t
                     where t.filial_code = f.code
                       and t.state in ('01', '02', '04')) active_trades,
                   (select count(*)
                      from ipt_clients c
                     where c.filial_code = f.code
                       and c.condition = 'A') clients,
                   (select count(*)
                      from ipt_products p
                     where p.filial_code = f.code
                       and p.state = 'S'
                       and nvl(p.quantity, 0) > 0) stock_items
                   from ipt_s_filials f
                  where f.condition = 'A'
                    and (vFilial is null or f.code = vFilial)
                  order by f.code)
    loop
      vRow := json_object_t();
      vRow.put('filial_code', rows.code);
      Put_Str(vRow, 'filial_name', rows.name);
      Put_Str(vRow, 'site_code', rows.site_code);
      vRow.put('active_trades', rows.active_trades);
      vRow.put('clients', rows.clients);
      vRow.put('stock_items', rows.stock_items);
      vRows.append(vRow);
    end loop;
    vResponse.put('total', vRows.get_size);
    vResponse.put('rows', vRows);
    oResponse := vResponse.to_clob();
  end;

  --Cr By: Arslonbek Kulmatov
  --Savdolar: davr bo'yicha soni va summasi, filial kesimida.
  --
  --Sana sharti ON ichida: WHERE ga qo'yilsa tashqi birikma ichkiga aylanadi
  --va o'sha davrda sotuvi yo'q filial javobdan butunlay tushib qoladi.
  Procedure Get_Sales(iParams clob, oResponse out clob)
  is
    vParams   json_object_t := Get_Params(iParams);
    vResponse json_object_t := New_Response;
    vRows     json_array_t  := json_array_t();
    vRow      json_object_t;
    vFilial   varchar2(10)  := Filial_Scope;
    vFrom     date;
    vTo       date;
    vCount    number := 0;
    vAmount   number := 0;
  begin
    Ipt_Methods.Check_For_Seller;
    Read_Period(vParams, vFrom, vTo);
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
                   from ipt_s_filials f
                   left join ipt_trades t
                     on t.filial_code = f.code
                    and trunc(nvl(t.ip_date, t.cr_on)) between vFrom and vTo
                  where f.condition = 'A'
                    and (vFilial is null or f.code = vFilial)
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
      vCount  := vCount + rows.trades_count;
      vAmount := vAmount + rows.sold_amount;
    end loop;
    vResponse.put('total_trades', vCount);
    vResponse.put('total_amount', vAmount);
    vResponse.put('rows', vRows);
    oResponse := vResponse.to_clob();
  end;

  --Cr By: Arslonbek Kulmatov
  --Faol rassrochkalar ro'yxati.
  --
  --client_name bo'yicha qidirish mumkin: "Azizovning rassrochkasi bormi"
  --degan savol shu orqali javob topadi.
  Procedure Get_Installments(iParams clob, oResponse out clob)
  is
    vParams   json_object_t := Get_Params(iParams);
    vResponse json_object_t := New_Response;
    vRows     json_array_t  := json_array_t();
    vRow      json_object_t;
    vFilial   varchar2(10)  := Filial_Scope;
    vSearch   varchar2(500);
    vTotal    number;
    vShown    pls_integer := 0;
  begin
    Ipt_Methods.Check_For_Seller;
    vSearch := trim(Json_Scalar(vParams, 'client_name'));
    if vSearch is not null then
      vSearch := '%'||upper(vSearch)||'%';
    end if;
    select count(*) into vTotal
      from ipt_trades t
     where t.state in ('01', '02', '04')
       and (vFilial is null or t.filial_code = vFilial)
       and (vSearch is null
            or upper((select c.name from ipt_clients c where c.id = t.client_id)) like vSearch);
    for rows in (select
                   t.id trade_id,
                   t.client_id,
                   (select c.name from ipt_clients c where c.id = t.client_id) client_name,
                   t.filial_code,
                   (select p.name from ipt_products p where p.id = t.product_id) product_name,
                   t.state,
                   t.ip_date,
                   t.end_date,
                   t.payment_term/100        payment_term,
                   t.product_new_price/100   price,
                   t.initial_payment/100     initial_payment,
                   t.monthly_payment/100     monthly_payment,
                   ipt_util.Get_Trade_All_Debt(iTrade_Id => t.id)/100 debt,
                   ipt_util.Get_Pros_Days(iTrade_Id => t.id, iDate => trunc(sysdate)) overdue_days
                   from ipt_trades t
                  where t.state in ('01', '02', '04')
                    and (vFilial is null or t.filial_code = vFilial)
                    and (vSearch is null
                         or upper((select c.name from ipt_clients c where c.id = t.client_id)) like vSearch)
                  order by t.ip_date desc nulls last, t.id desc
                 fetch first cMax_Rows rows only)
    loop
      vRow := json_object_t();
      vRow.put('trade_id', to_char(rows.trade_id));
      vRow.put('client_id', to_char(rows.client_id));
      Put_Str(vRow, 'client_name', rows.client_name);
      Put_Str(vRow, 'filial_code', rows.filial_code);
      Put_Str(vRow, 'product_name', rows.product_name);
      vRow.put('state', State_Name(rows.state));
      Put_Str(vRow, 'trade_date', To_Iso_Day(rows.ip_date));
      Put_Str(vRow, 'end_date', To_Iso_Day(rows.end_date));
      Put_Num(vRow, 'payment_term_months', rows.payment_term);
      Put_Num(vRow, 'price', rows.price);
      Put_Num(vRow, 'initial_payment', rows.initial_payment);
      Put_Num(vRow, 'monthly_payment', rows.monthly_payment);
      Put_Num(vRow, 'debt', rows.debt);
      vRow.put('overdue_days', nvl(rows.overdue_days, 0));
      vRows.append(vRow);
      vShown := vShown + 1;
    end loop;
    Put_Str(vResponse, 'search', trim(Json_Scalar(vParams, 'client_name')));
    vResponse.put('total', vTotal);
    vResponse.put('shown', vShown);
    if vTotal > vShown then
      vResponse.put('note', 'Jami '||vTotal||' ta, birinchi '||vShown||' tasi ko''rsatildi. '||
                            'Aniqroq qidiruv uchun client_name bering.');
    end if;
    vResponse.put('rows', vRows);
    oResponse := vResponse.to_clob();
  end;

  --Cr By: Arslonbek Kulmatov
  --Qarzdorlar: kechikkan sdelkalar.
  --
  --Manba — ipt_dashboard_overdue_v. Uni qayta yozmaymiz: bitta ta'rif
  --ikki joyda tursa, biri tuzatilib ikkinchisi unutiladi.
  Procedure Get_Debtors(iParams clob, oResponse out clob)
  is
    vParams   json_object_t := Get_Params(iParams);
    vResponse json_object_t := New_Response;
    vRows     json_array_t  := json_array_t();
    vRow      json_object_t;
    vFilial   varchar2(10)  := Filial_Scope;
    vMinDays  number;
    vTotal    number;
    vSum      number;
    vShown    pls_integer := 0;
  begin
    Ipt_Methods.Check_For_Seller;
    vMinDays := nvl(to_number(Json_Scalar(vParams, 'min_days')), 1);
    if vMinDays < 1 then
      vMinDays := 1;
    end if;
    select count(*), nvl(sum(v.overdue_amount), 0)
      into vTotal, vSum
      from ipt_dashboard_overdue_v v
     where v.overdue_days >= vMinDays
       and (vFilial is null or v.filial_code = vFilial);
    for rows in (select v.*
                   from ipt_dashboard_overdue_v v
                  where v.overdue_days >= vMinDays
                    and (vFilial is null or v.filial_code = vFilial)
                  order by v.overdue_days desc, v.trade_id
                 fetch first cMax_Rows rows only)
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
      vRows.append(vRow);
      vShown := vShown + 1;
    end loop;
    vResponse.put('min_days', vMinDays);
    vResponse.put('total_debtors', vTotal);
    vResponse.put('total_overdue_amount', vSum);
    vResponse.put('shown', vShown);
    if vTotal > vShown then
      vResponse.put('note', 'Jami '||vTotal||' ta kechikkan sdelka, eng uzoq kechikkan '||
                            vShown||' tasi ko''rsatildi. Ro''yxatni qisqartirish uchun '||
                            'min_days ni oshiring.');
    end if;
    vResponse.put('rows', vRows);
    oResponse := vResponse.to_clob();
  end;

  --Cr By: Arslonbek Kulmatov
  --Bitta sdelka: shartlari va to'lov grafigi.
  --
  --Grafik butunlay beriladi, chegarasiz: eng uzun muddat 24-36 oy, ya'ni
  --qatorlar soni oldindan ma'lum va kichik.
  Procedure Get_Trade(iParams clob, oResponse out clob)
  is
    vParams   json_object_t := Get_Params(iParams);
    vResponse json_object_t := New_Response;
    vGraph    json_array_t  := json_array_t();
    vRow      json_object_t;
    vFilial   varchar2(10)  := Filial_Scope;
    vTradeId  number;
    vTrade    ipt_trades%rowtype;
  begin
    Ipt_Methods.Check_For_Seller;
    vTradeId := to_number(Json_Scalar(vParams, 'trade_id'));
    if vTradeId is null then
      Ipt_Methods.Raise_Error('"trade_id" ko''rsatilmagan.');
    end if;
    begin
      select * into vTrade from ipt_trades t where t.id = vTradeId;
    exception
      when no_data_found then
        Ipt_Methods.Raise_Error('Bunday sdelka yo''q: '||vTradeId);
    end;
    -- Boshqa filialning sdelkasi ko'rsatilmaydi. "Topilmadi" deymiz, chunki
    -- "sizga ruxsat yo'q" degan javob ham ma'lumot beradi: sdelka bor ekan.
    if vFilial is not null and nvl(vTrade.Filial_Code, '-') <> vFilial then
      Ipt_Methods.Raise_Error('Bunday sdelka yo''q: '||vTradeId);
    end if;
    vResponse.put('trade_id', to_char(vTrade.Id));
    vResponse.put('client_id', to_char(vTrade.Client_Id));
    Put_Str(vResponse, 'client_name',
            (select c.name from ipt_clients c where c.id = vTrade.Client_Id));
    Put_Str(vResponse, 'product_name',
            (select p.name from ipt_products p where p.id = vTrade.Product_Id));
    Put_Str(vResponse, 'trade_filial_code', vTrade.Filial_Code);
    vResponse.put('state', State_Name(vTrade.State));
    Put_Str(vResponse, 'trade_date', To_Iso_Day(vTrade.Ip_Date));
    Put_Str(vResponse, 'end_date', To_Iso_Day(vTrade.End_Date));
    Put_Num(vResponse, 'payment_term_months', vTrade.Payment_Term/100);
    Put_Num(vResponse, 'interest_rate_pct', vTrade.Interest_Rate/100);
    Put_Num(vResponse, 'price', vTrade.Product_New_Price/100);
    Put_Num(vResponse, 'initial_payment', vTrade.Initial_Payment/100);
    Put_Num(vResponse, 'financed_amount', vTrade.Ip_Amount/100);
    Put_Num(vResponse, 'monthly_payment', vTrade.Monthly_Payment/100);
    Put_Num(vResponse, 'debt', ipt_util.Get_Trade_All_Debt(iTrade_Id => vTrade.Id)/100);
    Put_Num(vResponse, 'overdue_days',
            ipt_util.Get_Pros_Days(iTrade_Id => vTrade.Id, iDate => trunc(sysdate)));
    for rows in (select g.order_num,
                        g.payment_date,
                        g.paid_date,
                        g.payment_amount/100 payment_amount,
                        g.paid_amount/100    paid_amount
                   from ipt_trade_graphs g
                  where g.trade_id = vTradeId
                  order by g.order_num)
    loop
      vRow := json_object_t();
      vRow.put('n', rows.order_num);
      vRow.put('due_date', To_Iso_Day(rows.payment_date));
      Put_Str(vRow, 'paid_date', To_Iso_Day(rows.paid_date));
      Put_Num(vRow, 'amount', rows.payment_amount);
      Put_Num(vRow, 'paid', rows.paid_amount);
      vRow.put('status', case
                           when nvl(rows.paid_amount, 0) >= rows.payment_amount then 'to''langan'
                           when rows.payment_date < trunc(sysdate) then 'kechikkan'
                           else 'kutilmoqda'
                         end);
      vGraph.append(vRow);
    end loop;
    vResponse.put('schedule', vGraph);
    oResponse := vResponse.to_clob();
  end;

end Ipt_Chat;
/

-- =============================================================================
-- METODLARNI RO'YXATGA OLISH
--
-- add_log = 'Y': chat so'rovlari logga tushsin. Kim nima so'raganini bilish
-- kerak — bu qarzdorlik ma'lumoti.
-- =============================================================================

prompt core_methods

merge into core_methods t
using (
  select 'chatFilials' method, 'Ipt_Chat.Get_Filials' proc_name,
         'Chat: filiallar va joriy holati' details, 1 seq from dual
  union all
  select 'chatSales', 'Ipt_Chat.Get_Sales',
         'Chat: savdolar davr bo''yicha', 2 from dual
  union all
  select 'chatInstallments', 'Ipt_Chat.Get_Installments',
         'Chat: faol rassrochkalar', 3 from dual
  union all
  select 'chatDebtors', 'Ipt_Chat.Get_Debtors',
         'Chat: qarzdorlar', 4 from dual
  union all
  select 'chatTrade', 'Ipt_Chat.Get_Trade',
         'Chat: bitta sdelka va to''lov grafigi', 5 from dual
) s
on (lower(t.method) = lower(s.method))
when matched then
  update set t.proc_name = s.proc_name,
             t.details   = s.details,
             t.add_log   = 'Y',
             t.state     = 'A'
when not matched then
  insert (id, method, proc_name, state, has_out_param, is_func, add_log, details, cr_on)
  values ((select nvl(max(m.id), 0) from core_methods m) + s.seq,
          s.method, s.proc_name, 'A', 'Y', 'N', 'Y', s.details, sysdate);

commit;

-- =============================================================================
-- TEKSHIRISH
--
--   select object_name, status from user_objects where object_name = 'IPT_CHAT';
--
--   declare v clob;
--   begin
--     Ipt_Chat.Get_Debtors('{"params":{"min_days":30}}', v);
--     dbms_output.put_line(substr(v, 1, 4000));
--   end;
--   /
--
-- DIQQAT: bu metodlar core_session.Get_Filial_Code ga tayanadi. PL/SQL
-- Developer'dan to'g'ridan-to'g'ri chaqirilganda kontekst bo'sh bo'ladi va
-- filial NULL chiqadi — ya'ni barcha filiallar. Ilova orqali chaqirilganda
-- kontekst to'g'ri o'rnatiladi.
-- =============================================================================
