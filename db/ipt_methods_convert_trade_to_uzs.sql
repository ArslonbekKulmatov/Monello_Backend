-- =============================================================================
-- Ipt_Methods.Convert_Trade_To_Uzs — to'lov qatorlarini ham to'ldiradi
--
-- MUAMMO
--   Procedura ipt_trade_graphs ni to'ldirardi (payment_amount_uzs,
--   paid_amount_uzs, course_usd), lekin ipt_trade_graph_paid_amounts ga
--   TEGMASDI. Natijada o'tkazishdan oldin qabul qilingan to'lovlarda
--   paid_amount_uzs = 0 bo'lib qolardi va ular somda ko'rinmasdi.
--
-- NIMA QO'SHILDI
--   Sikl ichida, grafik qatori yangilangandan KEYIN, o'sha qatorga tegishli
--   to'lov yozuvlari ham yangilanadi:
--       paid_amount_uzs = Usd_To_Uzs(paid_amount, kurs)
--       course_usd      = nvl(mavjud, kurs)
--   va yaxlitlash qoldig'i oxirgi to'lov qatoriga beriladi, shunda
--   yig'indi grafikdagi paid_amount_uzs ga AYNAN teng bo'ladi.
--
-- NEGA QOLDIQ KERAK
--   Har qatorni alohida yaxlitlash yig'indini bir necha tiyinga suradi.
--   Add_Paid_Amounts da ham xuddi shu naqsh: qoldiq oxirgi qatorga.
--
-- RATE_DIFF_AMOUNT GA TEGILMAYDI
--   Bu yerda som dollardan hosil qilinadi, ya'ni haqiqiy kurs farqi yo'q —
--   faqat yaxlitlash. Farqni qayd etish ma'nosiz bo'lardi.
--
--   Eski, allaqachon o'tkazilgan sdelkalarda farq bor (9202 da 3.66$) —
--   ular uchun db/ipt_paid_amounts_uzs_backfill.sql ning 5-bo'limi.
--
-- DRY RUN
--   iApply = 'N' da hech narsa yozilmaydi, lekin javobda
--   paid_amount_rows chiqadi — nechta to'lov qatori tegishini ko'rsatadi.
--
-- SHUNDAY MUAMMO FIX_TRADE_COURSE DA HAM BOR
--   U ham faqat grafikni yangilaydi. Undagi yechim biroz boshqacha bo'ladi,
--   chunki anchor = 'S' bo'lganda somga tegmaslik kerak. Kerak bo'lsa
--   alohida qilib beraman.
--
-- Muallif: Arslonbek Kulmatov
-- Sana   : 23.09.2026
-- =============================================================================

  --Cr By: Arslonbek Kulmatov
  --Mavjud USD sdelkani SOM grafigiga o'tkazish.
  --
  --IKKI REJIM:
  --
  --  'E' (Exact) - faqat ko'rinish. USD summalar TEGILMAYDI, som ustunlari
  --      kursda hisoblab to'ldiriladi. Moliyaviy ta'sir NOL. Sdelka dollarda
  --      to'g'ri tuzilgan, shunchaki mijozga somda ko'rsatilishi kerak bo'lsa.
  --
  --  'R' (Round) - som ASOSIY. Mijoz bilan aslida somda kelishilgan bo'lsa
  --      (masalan "oyiga 3 000 000 sum"), lekin tizimga dollarda kiritilgan.
  --      TO'LANMAGAN qatorlarga iMonthly_Uzs qo'yiladi va ularning USD summasi
  --      qayta hisoblanadi. TO'LANGAN qatorlarga TEGILMAYDI - ular bo'yicha
  --      operatsiya, saldo va IPC foyda allaqachon yozilgan, ularni o'zgartirish
  --      hisobni buzadi.
  --      Natijada ip_amount va interest_rate o'zgaradi (bu KUTILGAN narsa -
  --      sdelka shartlari haqiqatan boshqa edi).
  --
  --iApply = 'N' bo'lsa hech narsa yozilmaydi, faqat hisobot qaytadi (dry-run).
  --Avval DOIM 'N' bilan chaqirib, natijani ko'ring.
  Procedure Convert_Trade_To_Uzs(iTrade_Id      number,
                                 iCourse_Usd    number   default null,
                                 iMode          varchar2 default 'E',
                                 iMonthly_Uzs   number   default null,
                                 iApply         varchar2 default 'N',
                                 oResponse      out clob)
  is
    vTrade          ipt_trades%rowtype;
    vSession_User   number := core_session.Get_User_Id;
    vCourse         number := 0;
    vResponse       json_object_t := json_object_t();
    vRows           json_array_t  := json_array_t();
    vRow            json_object_t;
    vNew_Total_Usd  number := 0;
    vNew_Total_Uzs  number := 0;
    vNew_Rate       number := 0;
    vPaid_Rows      pls_integer := 0;
    vFree_Rows      pls_integer := 0;
    vNew_Pay_Usd    number;
    vNew_Pay_Uzs    number;
    vInvestor_Id    number;
    vPay_Rows       pls_integer := 0;   -- tegiladigan to'lov yozuvlari soni
    vPay_Cnt        pls_integer;
  begin
    if iMode not in ('E', 'R') then
      Raise_Error('"iMode" должен быть «E» (только отображение) или «R» (сумма — основная).');
    end if;

    if iApply not in ('Y', 'N') then
      Raise_Error('"iApply" должен быть «Y» или «N».');
    end if;

    begin
      select t.* into vTrade
        from ipt_trades t
       where t.id = iTrade_Id;
    exception
      when no_data_found then
        Raise_Error('С этим идентификатором сделка не найдена = '||iTrade_Id);
    end;

    if nvl(vTrade.Currency_Code, '840') = '860' then
      Raise_Error('Эта сделка уже в сумах.');
    end if;

    if vTrade.State not in ('01', '02') then
      Raise_Error('Конвертировать можно только действующую или просроченную сделку. Состояние = '||vTrade.State);
    end if;

    -- Kurs: berilmasa sdelka ochilgan kundagi kurs, u ham topilmasa joriy kurs
    vCourse := iCourse_Usd;

    if nvl(vCourse, 0) <= 0 then
      begin
        select round(r.rate*100) into vCourse
          from (select c.rate
                  from ipt_currency_rates c
                 where c.code = '840'
                  and c.cr_on <= vTrade.Cr_On
                 order by c.id desc
                 fetch first 1 row only) r;
      exception
        when no_data_found then
          vCourse := ipt_util.Get_Rate_Tiyin('840');
      end;
    end if;

    if nvl(vCourse, 0) <= 0 then
      Raise_Error('Курс не установлен и не может быть определён.');
    end if;

    if iMode = 'R' and nvl(iMonthly_Uzs, 0) <= 0 then
      Raise_Error('В режиме «R» необходимо указать "iMonthly_Uzs" (ежемесячный платёж в сумах).');
    end if;

    ---------------------------------------------------------------------------
    -- Grafik qatorlarini ko'rib chiqamiz
    ---------------------------------------------------------------------------
    for g in (select t.* from ipt_trade_graphs t
               where t.trade_id = iTrade_Id
               order by t.order_num)
    loop
      if iMode = 'E' or nvl(g.paid_amount, 0) > 0 then
        -- Tegilmaydi: USD o'sha, som aniq konvertatsiya
        vNew_Pay_Usd := g.payment_amount;
        vNew_Pay_Uzs := ipt_util.Usd_To_Uzs(g.payment_amount, vCourse);

        if nvl(g.paid_amount, 0) > 0 then
          vPaid_Rows := vPaid_Rows + 1;
        else
          vFree_Rows := vFree_Rows + 1;
        end if;
      else
        -- 'R' + to'lanmagan qator: som asosiy, USD qayta hisoblanadi
        vNew_Pay_Uzs := iMonthly_Uzs;
        vNew_Pay_Usd := ipt_util.Uzs_To_Usd(iMonthly_Uzs, vCourse);
        vFree_Rows := vFree_Rows + 1;
      end if;

      vNew_Total_Usd := vNew_Total_Usd + vNew_Pay_Usd;
      vNew_Total_Uzs := vNew_Total_Uzs + vNew_Pay_Uzs;

      -- Dry-run da ham ko'rinsin: nechta to'lov yozuvi tegiladi
      select count(*) into vPay_Cnt
        from ipt_trade_graph_paid_amounts p
       where p.trade_id        = iTrade_Id
         and p.graph_order_num = g.order_num;

      vPay_Rows := vPay_Rows + vPay_Cnt;

      vRow := json_object_t();
      vRow.put('order_num', g.order_num);
      vRow.put('payment_date', to_char(g.payment_date, 'dd.mm.yyyy'));
      vRow.put('old_payment_amount', g.payment_amount/100);
      vRow.put('new_payment_amount', vNew_Pay_Usd/100);
      vRow.put('new_payment_amount_uzs', vNew_Pay_Uzs/100);
      vRow.put('paid_amount', nvl(g.paid_amount, 0)/100);
      vRow.put('paid_amount_uzs', ipt_util.Usd_To_Uzs(nvl(g.paid_amount, 0), vCourse)/100);
      vRow.put('paid_rows', vPay_Cnt);
      vRow.put('touched', case when vNew_Pay_Usd <> g.payment_amount then 'Y' else 'N' end);
      vRows.append(vRow);

      if iApply = 'Y' then
        update ipt_trade_graphs t
           set t.currency           = '860',
               t.course_usd         = vCourse,
               t.payment_amount     = vNew_Pay_Usd,
               t.payment_amount_uzs = vNew_Pay_Uzs,
               t.paid_amount_uzs    = ipt_util.Usd_To_Uzs(nvl(t.paid_amount, 0), vCourse),
               t.up_by              = vSession_User,
               t.up_on              = sysdate
         where t.id = g.id
          and t.trade_id = iTrade_Id
          and t.order_num = g.order_num;

        -- ===================================================================
        -- YANGI: o'sha qatorga tegishli TO'LOV YOZUVLARI
        --
        -- Grafik yangilandi, endi ipt_trade_graph_paid_amounts ham. Busiz
        -- eski to'lovlar somda ko'rinmaydi (IPT_TRADE_GRAPH_PAYMENTS_V2).
        -- ===================================================================
        declare
          vTarget_Uzs number := ipt_util.Usd_To_Uzs(nvl(g.paid_amount, 0), vCourse);
          vAllocated  number := 0;
          vThis_Uzs   number;
          vLast_Id    number;
        begin
          if nvl(g.paid_amount, 0) <> 0 then
            -- Qoldiq beriladigan qator: oxirgi TO'LOV (dc_sign = 4).
            -- Bekor qilish qatoriga berib bo'lmaydi — u ayiriladi.
            -- Agregat har doim bitta qator qaytaradi: qator bo'lmasa NULL,
            -- shuning uchun no_data_found ushlash shart emas.
            select max(p.id) keep (dense_rank last order by p.cr_on, p.id)
              into vLast_Id
              from ipt_trade_graph_paid_amounts p
             where p.trade_id        = iTrade_Id
               and p.graph_order_num = g.order_num
               and p.dc_sign         = 4;

            for pr in (select p.id, p.paid_amount, p.dc_sign
                         from ipt_trade_graph_paid_amounts p
                        where p.trade_id        = iTrade_Id
                          and p.graph_order_num = g.order_num
                        order by p.cr_on, p.id)
            loop
              vThis_Uzs := ipt_util.Usd_To_Uzs(pr.paid_amount, vCourse);

              update ipt_trade_graph_paid_amounts d
                 set d.paid_amount_uzs = vThis_Uzs,
                     d.course_usd      = nvl(d.course_usd, vCourse)
               where d.id = pr.id;

              vAllocated := vAllocated
                          + case when pr.dc_sign = 4 then vThis_Uzs else -vThis_Uzs end;
            end loop;

            -- Yaxlitlash qoldig'i: yig'indi grafikdagi som bilan bir xil bo'lsin
            if vLast_Id is not null and vAllocated <> vTarget_Uzs then
              update ipt_trade_graph_paid_amounts d
                 set d.paid_amount_uzs = d.paid_amount_uzs + (vTarget_Uzs - vAllocated)
               where d.id = vLast_Id;
            end if;
          end if;
        end;
      end if;
    end loop;

    if vRows.Get_Size = 0 then
      Raise_Error('У этой сделки нет графика.');
    end if;

    -- Yangi foiz stavkasi
    if nvl(vTrade.Remaining_Debt, 0) > 0 then
      vNew_Rate := floor((vNew_Total_Usd - vTrade.Remaining_Debt)/vTrade.Remaining_Debt*100);
    end if;

    if iMode = 'R' and vNew_Rate <= 0 then
      rollback;
      Raise_Error('Невозможно конвертировать: при платеже '||iMonthly_Uzs/100||
                  ' сум клиент вернёт '||vNew_Total_Usd/100||'$ при долге '||
                  vTrade.Remaining_Debt/100||'$. Процентная ставка стала бы '||vNew_Rate||'%.');
    end if;

    ---------------------------------------------------------------------------
    -- Sdelka sarlavhasi
    ---------------------------------------------------------------------------
    if iApply = 'Y' then
      insert into ipt_trades_his
      select t.*, 'U', vSession_User, sysdate
        from ipt_trades t
       where t.id = iTrade_Id;

      update ipt_trades t
         set t.currency_code       = '860',
             t.course_usd          = vCourse,
             t.ip_amount           = vNew_Total_Usd,
             t.ip_amount_uzs       = vNew_Total_Uzs,
             t.monthly_payment     = case when iMode = 'R'
                                          then ipt_util.Uzs_To_Usd(iMonthly_Uzs, vCourse)
                                          else t.monthly_payment end,
             t.monthly_payment_uzs = case when iMode = 'R'
                                          then iMonthly_Uzs
                                          else ipt_util.Usd_To_Uzs(t.monthly_payment, vCourse) end,
             t.interest_rate       = vNew_Rate*100,
             t.up_by               = vSession_User,
             t.up_on               = sysdate
       where t.id = iTrade_Id;

      Log_Uzs_Convert(iTrade_Id      => iTrade_Id,
                      iAction        => 'CONVERT',
                      iMode          => iMode,
                      iOld_Course    => null,
                      iNew_Course    => vCourse,
                      iOld_Ip_Amount => vTrade.Ip_Amount,
                      iNew_Ip_Amount => vNew_Total_Usd,
                      iOld_Ip_Uzs    => vTrade.Ip_Amount_Uzs,
                      iNew_Ip_Uzs    => vNew_Total_Uzs,
                      iOld_Rate      => vTrade.Interest_Rate,
                      iNew_Rate      => vNew_Rate*100,
                      iPaid_Rows     => vPaid_Rows,
                      iFree_Rows     => vFree_Rows);

      -- Oborot snapshot: 'R' rejimda kutilayotgan qaytarish summasi o'zgardi.
      -- DIQQAT: procedura argumentiga scalar subquery yozib bo'lmaydi (PLS-00103),
      -- shuning uchun avval o'zgaruvchiga olamiz.
      begin
        select p.investor_id into vInvestor_Id
          from ipt_products p
         where p.id = vTrade.Product_Id;

        Ipt_Balance_Log.Log_Operation(
          iOperation_Id  => null,
          iInvestor_Id   => vInvestor_Id,
          iSource_Module => 'convert_trade_to_uzs:'||iTrade_Id);
      exception
        when others then null;
      end;

      commit;

      Notify_Convert_To_Uzs(iTrade         => vTrade,
                            iMode          => iMode,
                            iCourse_Usd    => vCourse,
                            iOld_Ip_Amount => vTrade.Ip_Amount,
                            iNew_Ip_Amount => vNew_Total_Usd,
                            iNew_Ip_Uzs    => vNew_Total_Uzs,
                            iOld_Rate      => vTrade.Interest_Rate/100,
                            iNew_Rate      => vNew_Rate,
                            iPaid_Rows     => vPaid_Rows,
                            iFree_Rows     => vFree_Rows,
                            iIs_Success    => true,
                            iUser_Id       => vSession_User);
    else
      rollback;
    end if;

    vResponse.put('oper', true);
    vResponse.put('applied', iApply);
    vResponse.put('mode', iMode);
    vResponse.put('trade_id', iTrade_Id);
    vResponse.put('course_usd', vCourse/100);
    vResponse.put('remaining_debt', vTrade.Remaining_Debt/100);
    vResponse.put('old_ip_amount', vTrade.Ip_Amount/100);
    vResponse.put('new_ip_amount', vNew_Total_Usd/100);
    vResponse.put('new_ip_amount_uzs', vNew_Total_Uzs/100);
    vResponse.put('ip_amount_diff', (vNew_Total_Usd - vTrade.Ip_Amount)/100);
    vResponse.put('old_interest_rate', vTrade.Interest_Rate/100);
    vResponse.put('new_interest_rate', vNew_Rate);
    vResponse.put('paid_rows_untouched', vPaid_Rows);
    vResponse.put('free_rows', vFree_Rows);
    -- Nechta to'lov yozuvi somga o'tkazildi (dry-run da: o'tkazilardi)
    vResponse.put('paid_amount_rows', vPay_Rows);
    --vResponse.put('rows', vRows);
    vResponse.put('message', case when iApply = 'Y'
                                  then 'Converted.'
                                  else 'DRY RUN - ничего не записано.' end);

    oResponse := vResponse.To_Clob;
  exception
    when others then
      rollback;
      -- Dry-run xatosi uchun xabar yubormaymiz - u shunchaki tekshiruv
      if iApply = 'Y' then
        Notify_Convert_To_Uzs(iTrade      => vTrade,
                              iMode       => iMode,
                              iCourse_Usd => vCourse,
                              iIs_Success => false,
                              iError_Msg  => sqlerrm,
                              iUser_Id    => vSession_User);
      end if;

      raise;
  end;
