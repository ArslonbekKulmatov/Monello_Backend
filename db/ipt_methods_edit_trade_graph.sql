-- =============================================================================
-- Ipt_Methods.Edit_Trade_Graph — yangi qator qo'shishdagi xato
--
-- XATO
--   ORA-01400: cannot insert NULL into ("MONELLO"."IPT_TRADE_GRAPHS"."ID")
--
--   Yangi qator tarmog'ida vTrade_Graph.Id umuman qo'yilmagan. Grafikka
--   qator QO'SHILGANDA (JSON da mavjudidan ko'p qator kelsa) shu yerga
--   tushadi. Shuning uchun u avval sezilmagan: odatda qatorlar soni
--   o'zgarmaydi va faqat update tarmog'i ishlaydi.
--
-- >>> NEGA ipt_trade_graphs_seq.nextval EMAS <<<
--
--   IPT_TRADE_GRAPHS.ID — QATORNING emas, SDELKANING raqami.
--   Generate_Pay_Graph ketma-ketlikni sikldan TASHQARIDA bir marta oladi:
--
--       vGraph.Id := ipt_trade_graphs_seq.nextval;
--       for months in 1 .. floor(iPayment_Term/100)
--       loop
--         ...
--         insert into ipt_trade_graphs values vGraph;   <- id HAR SAFAR BIR XIL
--       end loop;
--
--   V2 va V3 da ham xuddi shunday. Ya'ni bitta sdelkaning 36 ta qatorida
--   ham id bitta. Haqiqiy kalit — (trade_id, order_num), shuning uchun
--   Convert_Trade_To_Uzs va Fix_Trade_Course o'sha juftlik bilan
--   yangilaydi.
--
--   Agar yangi qatorga nextval berilsa, bitta sdelkada ikki xil id paydo
--   bo'ladi. Oqibati:
--     - Add_Paid_Amounts to'lov qatoriga graph_id ni yozadi; keyin o'sha
--       sdelka bo'yicha qaysi id to'g'ri ekani noaniq bo'lib qoladi
--     - "id bo'yicha sdelka grafigi" deb yozilgan har qanday so'rov
--       qatorlarning bir qismini yo'qotadi
--
--   Shuning uchun yangi qator SHU SDELKANING mavjud id sini oladi.
--
-- IKKINCHI XATO: PAYMENT_AMOUNT_WITHOUT_PERC
--   ORA-01400 shu ustunda ham chiqadi — u ham qo'yilmagan edi.
--
--   Bu ustun bezak emas: Add_Paid_Amounts nasiya foydasini
--   "payment_amount - payment_amount_without_perc" deb hisoblaydi.
--   Shuning uchun uni 0 qilib qo'yib ketib bo'lmaydi — u holda butun
--   to'lov foiz deb hisoblanadi.
--
--   Yechim sikldan keyin: asosiy qarz to'lov summasiga proporsional
--   qayta taqsimlanadi. Tafsiloti o'sha joyda.
--
-- NIMA O'ZGARDI
--   1. vGraph_Id — sikldan oldin bir marta o'qiladi, yangi qatorga o'sha
--      beriladi. Grafik umuman bo'sh bo'lsa yangi nextval olinadi.
--   2. Yangi qatorga without_perc = 0 (NULL bo'lmasin uchun), keyin
--      butun grafik bo'ylab qayta taqsimlanadi.
--
--   Boshqa hech narsa o'zgarmadi.
--
-- Muallif: Arslonbek Kulmatov
-- Sana   : 26.09.2026
-- =============================================================================

  --Cr By: Arslonbek Kulmatov
  --Edit Trade Graphs
  Procedure Edit_Trade_Graph(iParams clob, oResponse out clob)
  is
    vJson                  json_object_t := json_object_t.parse(iParams);
    vParams                json_object_t := vJson.get_Object('params');
    vSession_User          number := core_session.Get_User_Id;
    vResponse              json_object_t := json_object_t();
    vCount                 pls_integer;
    vTrade                 ipt_trades%rowtype;
    vRows                  json_array_t := json_array_t();
    vTrade_Graph           ipt_trade_graphs%rowtype;
    vObj                   json_object_t := json_object_t();
    vTotal_Payments        number := 0;
    vMin_Date              date;
    vMax_Date              date;
    vCheck                 varchar2(2) := ipt_util.Get_Param_Value(3);
    vJson_Rows_Count       pls_integer;
    vInvestor_Id           number;
    vIs_Uzs                varchar2(1) := 'N';   -- SQL da ishlatilgani uchun boolean EMAS
    vCourse_Usd            number := 0;
    vTotal_Payments_Uzs    number := 0;
    vGraph_Id              number;               -- sdelkaning grafik raqami
  begin
    Check_For_Seller;
    Check_For_Existance(vParams, 'trade_id');
    Check_For_Existance(vParams, 'rows');

    vTrade.Id := vParams.get_Number('trade_id');
    vRows := vParams.get_Array('rows');
    vJson_Rows_Count := vRows.Get_Size;

    if vJson_Rows_Count = 0 then
      Raise_Error('Графы не могут быть нулевыми.');
    end if;

    begin
      select t.* into vTrade
        from ipt_trades t
       where t.id = vTrade.Id;
    exception
      when no_data_found then
        Raise_Error('С этим идентификатором сделка не найдена = '||vTrade.Id);
    end;

    vIs_Uzs     := case when nvl(vTrade.Currency_Code, '840') = '860' then 'Y' else 'N' end;
    vCourse_Usd := vTrade.Course_Usd;

    if vIs_Uzs = 'Y' and nvl(vCourse_Usd, 0) <= 0 then
      Raise_Error('У этой сделки не зафиксирован курс. Невозможно редактировать график.');
    end if;

    -- Sdelkaning grafik raqami. Butun sdelkada bitta — yuqoridagi izohga qarang.
    -- Agregat har doim bitta qator qaytaradi, qator bo'lmasa NULL.
    select max(t.id) into vGraph_Id
      from ipt_trade_graphs t
     where t.trade_id = vTrade.Id;

    -- Grafik umuman bo'sh bo'lsa yangi raqam olamiz
    if vGraph_Id is null then
      vGraph_Id := ipt_trade_graphs_seq.nextval;
    end if;

    -- Grafik umumiy summasi rassrochka summasiga mos kelishini tekshirish.
    -- Som sdelkada foydalanuvchi SOMDA kiritadi, USD esa savdo kursida chiqadi.
    if vIs_Uzs = 'Y' then
      select sum(round(payment_amount, 2)*100) into vTotal_Payments_Uzs
        from json_table(iParams,
                        '$.params.rows[*]'
                        columns(payment_amount number path '$.payment_amount'));

      vTotal_Payments := ipt_util.Uzs_To_Usd(vTotal_Payments_Uzs, vCourse_Usd);
    else
      select sum(round(payment_amount, 2)*100) into vTotal_Payments
        from json_table(iParams,
                        '$.params.rows[*]'
                        columns(payment_amount number path '$.payment_amount'));

      vTotal_Payments_Uzs := 0;
    end if;

    if vCheck = 'A' then
      if vIs_Uzs = 'Y' then
        if nvl(vTrade.Ip_Amount_Uzs, 0) <> vTotal_Payments_Uzs then
          Raise_Error('Общая сумма платежа по графику должна быть равна сумме рассрочки. '
                      ||vTotal_Payments_Uzs/100||' сум <> '||nvl(vTrade.Ip_Amount_Uzs, 0)/100||' сум');
        end if;
      else
        if vTrade.Ip_Amount <> vTotal_Payments then
          Raise_Error('Общая сумма платежа по графику должна быть равна сумме рассрочки. '
                      ||vTotal_Payments/100||' <> '||vTrade.Ip_Amount/100);
        end if;
      end if;
    else
      insert into ipt_trades_his
      select t.*, 'U', vSession_User, sysdate
        from ipt_trades t
       where t.id = vTrade.Id;

      update ipt_trades t
        set t.ip_amount     = vTotal_Payments,
            t.ip_amount_uzs = case when vIs_Uzs = 'Y' then vTotal_Payments_Uzs
                                   else t.ip_amount_uzs end,
            t.up_by         = vSession_User,
            t.up_on         = sysdate
       where t.id = vTrade.Id;
    end if;

    -- O'zgarishdan OLDIN grafik tarixini yozib qo'yamiz (audit)
    insert into ipt_trade_graphs_his
    select t.*, 'U', vSession_User, sysdate
      from ipt_trade_graphs t
     where t.trade_id = vTrade.Id;

    -- Har bir kelgan qatorni order_num bo'yicha moslashtiramiz:
    --   mavjud bo'lsa -> UPDATE (income_division_id, is_income_divided, id, cr_by, cr_on TEGILMAYDI)
    --   yangi bo'lsa  -> INSERT
    -- Bu delete/insert rebuild'dagi "rownum=1 dan bayroq ko'chishi" bug'ini butunlay yo'q qiladi.
    for rows in 0 .. vRows.Get_Size - 1 loop
      vObj := json_object_t(vRows.get(rows));

      vTrade_Graph.Order_Num      := rows + 1;
      vTrade_Graph.Payment_Date   := to_date(vObj.get_String('payment_date'), 'dd.mm.yyyy');
      vTrade_Graph.Paid_Date      := to_date(vObj.get_String('paid_date'), 'dd.mm.yyyy');

      if vIs_Uzs = 'Y' then
        -- JSON'da summalar SOMDA keladi
        vTrade_Graph.Currency           := '860';
        vTrade_Graph.Course_Usd         := vCourse_Usd;
        vTrade_Graph.Payment_Amount_Uzs := round(vObj.get_Number('payment_amount'), 2)*100;
        vTrade_Graph.Paid_Amount_Uzs    := nvl(round(vObj.get_Number('paid_amount'), 2)*100, 0);
        vTrade_Graph.Payment_Amount     := ipt_util.Uzs_To_Usd(vTrade_Graph.Payment_Amount_Uzs, vCourse_Usd);
        vTrade_Graph.Paid_Amount        := ipt_util.Uzs_To_Usd(vTrade_Graph.Paid_Amount_Uzs, vCourse_Usd);
      else
        vTrade_Graph.Currency           := '840';
        vTrade_Graph.Course_Usd         := null;
        vTrade_Graph.Payment_Amount     := round(vObj.get_Number('payment_amount'), 2)*100;
        vTrade_Graph.Paid_Amount        := nvl(round(vObj.get_Number('paid_amount'), 2)*100, 0);
        vTrade_Graph.Payment_Amount_Uzs := 0;
        vTrade_Graph.Paid_Amount_Uzs    := 0;
      end if;

      if vTrade_Graph.Paid_Amount > 0 and vTrade_Graph.Paid_Date is null then
        Raise_Error('"paid_date" не может быть нулевым.');
      end if;

      if vTrade_Graph.Payment_Amount < 0 then
        Raise_Error('"payment_amount" не может быть меньше 0.');
      end if;

      if vTrade_Graph.Paid_Amount < 0 then
        Raise_Error('"paid_amount" не может быть меньше 0.');
      end if;

      if vTrade_Graph.Paid_Amount >= vTrade_Graph.Payment_Amount then
        vTrade_Graph.State := 1;
      else
        vTrade_Graph.State := 0;
      end if;

      select count(*) into vCount
        from ipt_trade_graphs t
       where t.trade_id  = vTrade.Id
        and t.order_num = vTrade_Graph.Order_Num;

      if vCount > 0 then
        -- MAVJUD qator: faqat foydalanuvchi kiritgan maydonlarni yangilaymiz.
        -- income_division_id, is_income_divided, id, cr_by, cr_on saqlanadi.
        update ipt_trade_graphs t
           set t.payment_amount     = vTrade_Graph.Payment_Amount,
               t.paid_amount        = vTrade_Graph.Paid_Amount,
               t.payment_amount_uzs = vTrade_Graph.Payment_Amount_Uzs,
               t.paid_amount_uzs    = vTrade_Graph.Paid_Amount_Uzs,
               t.currency           = vTrade_Graph.Currency,
               t.course_usd         = vTrade_Graph.Course_Usd,
               t.payment_date       = vTrade_Graph.Payment_Date,
               t.paid_date          = vTrade_Graph.Paid_Date,
               t.state              = vTrade_Graph.State,
               t.up_by              = vSession_User,
               t.up_on              = sysdate
         where t.trade_id  = vTrade.Id
          and t.order_num = vTrade_Graph.Order_Num;
      else
        -- YANGI qator: to'liq to'ldirib qo'shamiz. Income hali bo'linmagan.
        --
        -- Id — SDELKANING grafik raqami, qatorniki emas. Yangisi olinmaydi:
        -- Generate_Pay_Graph butun grafikka bitta raqam beradi va kalit
        -- (trade_id, order_num) bo'lib ishlaydi. Tafsiloti fayl boshida.
        vTrade_Graph.Id                 := vGraph_Id;
        vTrade_Graph.Trade_Id           := vTrade.Id;
        -- Vaqtinchalik 0. Haqiqiy qiymat sikldan keyin, butun grafik
        -- bo'ylab qayta taqsimlanadi — pastdagi izohga qarang.
        vTrade_Graph.Payment_Amount_Without_Perc := 0;
        vTrade_Graph.Is_Income_Divided  := 0;
        vTrade_Graph.Income_Division_Id := null;
        vTrade_Graph.Cr_By              := vSession_User;
        vTrade_Graph.Cr_On              := sysdate;
        vTrade_Graph.Up_By              := null;
        vTrade_Graph.Up_On              := null;

        insert into ipt_trade_graphs values vTrade_Graph;
      end if;
    end loop;

    -- JSON'da bo'lmagan ortiqcha (eski) qatorlarni o'chiramiz
    delete from ipt_trade_graphs t
     where t.trade_id = vTrade.Id
      and t.order_num > vJson_Rows_Count;

    -- =======================================================================
    -- ASOSIY QARZNI QATORLARGA QAYTA TAQSIMLASH
    --
    -- payment_amount_without_perc — oylik to'lovning FOIZSIZ qismi, ya'ni
    -- asosiy qarz ulushi. U bezak emas: Add_Paid_Amounts nasiya foydasini
    -- aynan shundan hisoblaydi —
    --
    --     vIncome := vGraph.Payment_Amount - vGraph.Payment_Amount_Without_Perc;
    --
    -- Shuning uchun bitta shart BUZILMASLIGI kerak:
    --
    --     sum(payment_amount_without_perc) = remaining_debt
    --
    -- Generate_Pay_Graph uni shunday qo'yadi. Grafik tahrirlanganda esa
    -- eski kod bu ustunga umuman tegmasdi va ikki xil buzilish chiqardi:
    --
    --   - yangi qator qo'shilsa qiymat NULL bo'lardi (ORA-01400)
    --   - qatorning to'lovi kamaytirilsa foiz MANFIY chiqardi
    --     (masalan to'lov 1 428 000 dan 428 000 ga tushsa, without_perc esa
    --      eski holicha qolsa). Add_Paid_Amounts da "if vIncome > 0" bor,
    --      ya'ni xato bermaydi — foyda jimgina taqsimlanmay qoladi.
    --
    -- Endi qarz to'lov summasiga PROPORSIONAL taqsimlanadi, yaxlitlash
    -- qoldig'i oxirgi qatorga beriladi — Generate_Pay_Graph dagi naqsh.
    --
    -- DIQQAT: bu MAVJUD qatorlarning without_perc ini ham qayta yozadi.
    -- Boshqacha bo'lishi mumkin emas: qator qo'shilsa yoki summa o'zgarsa,
    -- eski taqsimot baribir noto'g'ri bo'lib qoladi.
    -- =======================================================================
    declare
      vTotal_Pay number;
      vLast_Ord  number;
      vDebt      number := nvl(vTrade.Remaining_Debt, 0);
      vAllocated number := 0;
      vShare     number;
    begin
      select sum(t.payment_amount), max(t.order_num)
        into vTotal_Pay, vLast_Ord
        from ipt_trade_graphs t
       where t.trade_id = vTrade.Id;

      if nvl(vTotal_Pay, 0) > 0 and vDebt > 0 then
        for g in (select t.order_num, t.payment_amount
                    from ipt_trade_graphs t
                   where t.trade_id = vTrade.Id
                   order by t.order_num)
        loop
          if g.order_num = vLast_Ord then
            -- Oxirgi qator qoldiqni oladi: yig'indi aynan qarzga teng bo'lsin
            vShare := vDebt - vAllocated;
          else
            -- Bu KO'PAYTIRISH emas, ULUSH:
            --
            --     vShare = vDebt * ( payment_amount / vTotal_Pay )
            --                       \___ shu qatorning ulushi ___/
            --
            -- Ko'paytirish oldinga chiqarilgan: bo'linish avval bajarilsa
            -- oraliq kasr yaxlitlanib, aniqlik yo'qoladi.
            --
            -- NEGA TENG TAQSIMOT EMAS
            --   Generate_Pay_Graph qarzni qatorlarga TENG bo'ladi
            --   (floor(iAmount/muddat)) — u yerda to'lovlar ham teng,
            --   shuning uchun teng va proporsional bir xil chiqadi.
            --
            --   Tahrirdan keyin to'lovlar teng bo'lmay qoladi va teng
            --   taqsimot buziladi. 7 oylik, 7 140 000 qarz, to'lovlar
            --   1 428 000 x5, 428 000, 1 000 000 bo'lsa:
            --
            --     teng          : har qatorga 1 020 000
            --                     6-qator: 428 000 - 1 020 000 = -592 000
            --                     7-qator: 1 000 000 - 1 020 000 = -20 000
            --                     -> ikkala qatorda foiz MANFIY
            --
            --     proporsional  : 6-qator 356 666 -> foiz  +71 334
            --                     7-qator 833 334 -> foiz +166 666
            --
            --   Manfiy foizda Add_Paid_Amounts "if vIncome > 0" sharti
            --   tufayli foydani umuman taqsimlamaydi — xato bermaydi,
            --   foyda jimgina yo'qoladi.
            --
            -- floor: har ulush aniq qiymatdan KICHIK yoki teng, shuning
            -- uchun vAllocated hech qachon qarzdan oshmaydi va oxirgi
            -- qatorga qoladigan ulush manfiy chiqmaydi.
            vShare     := floor(vDebt * g.payment_amount / vTotal_Pay);
            vAllocated := vAllocated + vShare;
          end if;

          update ipt_trade_graphs t
             set t.payment_amount_without_perc = vShare
           where t.trade_id  = vTrade.Id
             and t.order_num = g.order_num;
        end loop;
      end if;
    end;

    -- begin_date / end_date ni yangi grafik bo'yicha yangilaymiz
    select sum(t.payment_amount),
           nvl(sum(t.payment_amount_uzs), 0),
           min(t.payment_date),
           max(t.payment_date)
      into vTotal_Payments, vTotal_Payments_Uzs, vMin_Date, vMax_Date
      from ipt_trade_graphs t
     where t.trade_id = vTrade.Id;

    update ipt_trades t
      set t.begin_date = vMin_Date,
          t.end_date   = vMax_Date,
          t.up_by      = vSession_User,
          t.up_on      = sysdate
     where t.id = vTrade.Id;

    -- Pogashenie snapshot: grafik o'zgargani uchun total_repayment o'zgardi.
    -- Saldo tegilmaydi, shuning uchun operation_id yo'q (null).
    begin
      select p.investor_id into vInvestor_Id
        from ipt_products p
       where p.id = vTrade.Product_Id;

      Ipt_Balance_Log.Log_Operation(iOperation_Id => null,
                                    iInvestor_Id  => vInvestor_Id,
                                    iSource_Module => 'edit_trade_graph:'||vTrade.Id);
    exception
      when others then null;   -- log xatosi asosiy oqimni buzmasin
    end;

    vResponse.put('oper', true);
    vResponse.put('id', vTrade.Id);
    vResponse.put('message', 'Successfully updated.');

    oResponse := vResponse.To_String;
  end;

-- =============================================================================
-- TEKSHIRISH
--
-- 1. Shart buzilmaganmi: without_perc yig'indisi qarzga teng bo'lishi kerak
--
--    select t.id trade_id,
--           t.remaining_debt / 100                       qarz,
--           sum(g.payment_amount_without_perc) / 100     taqsimlangan,
--           (t.remaining_debt
--            - sum(g.payment_amount_without_perc)) / 100 farq
--      from ipt_trades t
--      join ipt_trade_graphs g on g.trade_id = t.id
--     where t.state in ('01', '02')
--     group by t.id, t.remaining_debt
--    having t.remaining_debt <> sum(g.payment_amount_without_perc)
--     order by abs(t.remaining_debt - sum(g.payment_amount_without_perc)) desc;
--
--    Bo'sh chiqishi kerak. Qator chiqsa — o'sha sdelkalar ilgari
--    tahrirlangan va foydasi noto'g'ri hisoblanayotgan bo'lishi mumkin.
--    Ularni tuzatish uchun grafikni shu procedura orqali qayta saqlash
--    yetarli: taqsimot o'z-o'zidan to'g'rilanadi.
--
-- 2. Manfiy foizli qatorlar bormi
--
--    select g.trade_id, g.order_num,
--           g.payment_amount / 100               tolov,
--           g.payment_amount_without_perc / 100  asosiy,
--           (g.payment_amount
--            - g.payment_amount_without_perc) / 100 foiz
--      from ipt_trade_graphs g
--     where g.payment_amount < g.payment_amount_without_perc
--     order by (g.payment_amount - g.payment_amount_without_perc);
--
--    Bunday qatorda Add_Paid_Amounts foydani umuman taqsimlamaydi
--    ("if vIncome > 0" sharti) — xato bermaydi, foyda jimgina yo'qoladi.
-- =============================================================================
