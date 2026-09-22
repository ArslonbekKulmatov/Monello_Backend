-- =============================================================================
-- Ipt_Methods.Investor_Operations — OINC va OEXP qo'shildi
--
-- MUAMMO
--   Investor qoldig'iga pul qo'shishning yagona yo'li INC edi. INC esa
--   "yangi sarmoya" degani: u total_investment ni ham oshiradi.
--   Natijada xato kiritilgan INCE ni qaytarish uchun INC yozilganda
--   investitsiya summasi noto'g'ri shishib ketardi.
--   291-investorda shu tufayli 6 154$ ortiqcha chiqdi (67338, 68162, 68708).
--
-- YECHIM
--   OINC — qoldiqqa pul qo'shadi, total_investment ga TEGMAYDI.
--   OEXP — uning teskarisi: qoldiqdan ayiradi, total_investment ga tegmaydi.
--
--   | Kod  | total_investment | saldo_out | Qachon                          |
--   |------|------------------|-----------|---------------------------------|
--   | INC  | + oshadi         | + oshadi  | investor YANGI SARMOYA kiritdi  |
--   | EXP  | - kamayadi       | - kamayadi| investorga sarmoya QAYTARILDI   |
--   | OINC | tegilmaydi       | + oshadi  | qoldiqqa pul tushdi, sarmoya emas|
--   | OEXP | tegilmaydi       | - kamayadi| qoldiqdan pul chiqdi, qaytarish emas|
--
--   Ikkalasi birga qo'shildi. Faqat OINC qo'shilsa eski tuzoq qaytadi:
--   xato OINC ni bekor qilish uchun yana EXP yozishga to'g'ri kelardi, u esa
--   total_investment ni tushirib yuborardi.
--
-- ISHGA TUSHIRISHDAN OLDIN
--   Ikkala kod ipt_s_operations da initiator = 'I' bilan turganini tekshiring:
--
--     select code, name, initiator, is_expense
--       from ipt_s_operations
--      where code in ('OINC', 'OEXP');
--
--   Bo'lmasa qo'shing — aks holda "этот код операции не существует" chiqadi.
--
-- ESLATMA: TELEGRAM
--   Qo'lda kiritilgan OINC/OEXP Telegramga YUBORILMAYDI. Sabab:
--   Send_Expense_To_Telegram ning oq ro'yxatida OINC yo'q va bo'lishi ham
--   mumkin emas — har bir grafik to'lovi avtomat OINC yaratadi, ular
--   yuborilsa kanal spamga to'ladi. Qo'lda kiritilganini ajratish uchun
--   alohida belgi kerak. Kerak bo'lsa aytilsin.
--
-- Muallif: Arslonbek Kulmatov
-- Sana   : 22.09.2026
-- =============================================================================

  --Cr By: Arslonbek Kulmatov
  --Investor operation actions
  Procedure Investor_Operations(iParams varchar2, oResponse out varchar2)
  is
    vJson                  json_object_t := json_object_t.parse(iParams);
    vParams                json_object_t := vJson.get_Object('params');
    vSession_User          number := core_session.Get_User_Id;
    vResponse              json_object_t := json_object_t();
    vOperation             ipt_operations%rowtype;
    vCount                 pls_integer;
    vInvestor              ipt_investors%rowtype;
    vInvestor2             ipt_investors%rowtype;
    vResponse_Code         number;
    vResponse_Msg          varchar2(3000);
    vOperation_Id          number;
    vShould_Minus_Saldo    boolean := nvl(vParams.get_Boolean('should_minus_saldo'), true);
    vComment               varchar2(1000);
  begin
    Check_For_Existance(vParams, 'oper_code');
    Check_For_Existance(vParams, 'investor_id');
    Check_For_Existance(vParams, 'amount');
    Check_For_Existance(vParams, 'comments');

    vOperation.Oper_Code    := vParams.get_String('oper_code');
    vOperation.Expense_Code := vParams.get_Number('expense_type');
    vOperation.Investor_Id  := vParams.get_Number('investor_id');
    vOperation.Amount       := round(vParams.get_Number('amount'), 2)*100;
    vComment := vParams.get_String('comments');

    if vOperation.Oper_Code = 'I2IO' then
      Check_For_Existance(vParams, 'to_investor_id');
      vOperation.From_To_Investor_Id := vParams.get_Number('to_investor_id');

      begin
        select t.* into vInvestor2
          from ipt_investors t
         where t.id = vOperation.From_To_Investor_Id
          and t.condition = 'A';
      exception
        when no_data_found then
          vInvestor2.Id := null;
      end;

      if vInvestor2.Id is null then
        Raise_Error('Невозможно выполнить операцию: инвестор2 с таким идентификатором не существует или не активен.');
      end if;
    end if;

    if vOperation.Amount <= 0 and vWork_In_Loss = 'N' then
      Raise_Error('Невозможно выполнить операцию, если сумма <= 0. Сумма должна быть больше 0.');
    end if;

    select count(*) into vCount
      from ipt_s_operations t
     where t.initiator = 'I'
      and t.code = vOperation.Oper_Code;

    if vCount = 0 then
      Raise_Error(vOperation.Oper_Code||' этот код операции не существует или не относится к инвестору.');
    end if;

    select count(*) into vCount
      from ipt_investors t
     where t.id = vOperation.Investor_Id
      and t.condition = 'A';

    if vCount = 0 then
      Raise_Error('Невозможно выполнить операцию: инвестор с таким идентификатором не существует или не активен.');
    else
      select t.* into vInvestor
        from ipt_investors t
       where t.id = vOperation.Investor_Id
        and t.condition = 'A';
    end if;

    -- I2IO uchun asosiy INSERT'dan OLDIN barcha tekshiruvlarni bajaramiz,
    -- shunda yarim yozuv qolish xavfi bo'lmaydi
    if vOperation.Oper_Code = 'I2IO' then
      if vInvestor.Id = vInvestor2.Id then
        Raise_Error('Невозможно выполнить операцию: инвестор не может перевести самому себе.');
      end if;

      if vInvestor.Saldo_Out < vOperation.Amount and vWork_In_Loss = 'N' then
        Raise_Error('Невозможно выполнить эту операцию. У инвестора-отправителя Сальдо недостаточно. Сальдо = '||vInvestor.Saldo_Out/100);
      end if;

      if vInvestor.Total_Investment < vOperation.Amount and vWork_In_Loss = 'N' then
        Raise_Error('Невозможно выполнить эту операцию. У инвестора-отправителя Total_Investment недостаточно. Total_Investment = '||vInvestor.Total_Investment/100);
      end if;

      vComment := vComment||' (from-'||vInvestor.Filial_Code||' filialdagi '||vInvestor.Id||'-'||vInvestor.Name||' dan '||
                            'to-'||vInvestor2.Filial_Code||' filialdagi '||vInvestor2.Id||'-'||vInvestor2.Name||' ga o''tkazma.)';
    end if;

    vOperation.Id          := ipt_operations_seq.nextval;
    vOperation.Comments    := vComment;
    vOperation.Initiator   := 'I';
    vOperation.Cr_By       := vSession_User;
    vOperation.Cr_On       := sysdate;
    vOperation.Filial_Code := core_session.Get_Filial_Code;

    insert into ipt_operations values vOperation;

    --Agar operatsiya "Приход" bulsa
    if vOperation.Oper_Code = 'INC' then
      insert into ipt_investors_his
      select t.*, 'U', vSession_User, sysdate
        from ipt_investors t
       where t.id = vOperation.Investor_Id;

      update ipt_investors t
        set t.total_investment = t.total_investment + vOperation.Amount,
            t.saldo_out        = t.saldo_out + vOperation.Amount,
            t.up_by            = vSession_User,
            t.up_on            = sysdate
       where t.id = vOperation.Investor_Id;
    --Agarda operatsiya "Расход" bulsa
    elsif vOperation.Oper_Code = 'EXP' then
      if vInvestor.Saldo_Out < vOperation.Amount then
        Raise_Error('Невозможно выполнить эту операцию. У инвестора Сальдо недостаточно денег для списания. Сальдо = '||vInvestor.Saldo_Out/100);
      end if;

      insert into ipt_investors_his
      select t.*, 'U', vSession_User, sysdate
        from ipt_investors t
       where t.id = vOperation.Investor_Id;

      update ipt_investors t
        set t.total_investment = t.total_investment - vOperation.Amount,
            t.saldo_out        = t.saldo_out - vOperation.Amount,
            t.up_by            = vSession_User,
            t.up_on            = sysdate
       where t.id = vOperation.Investor_Id;
    --Agar operatsiya "Прочее приход" bulsa
    --
    --QOLDIQNI oshiradi, TOTAL_INVESTMENT ga TEGMAYDI. INC dan farqi shu.
    --
    --Qachon ishlatiladi:
    --  - xato kiritilgan INCE yoki OPE ni qaytarish
    --  - kassadan investor qoldig'iga qaytgan pul
    --  - hisob-kitobdagi tuzatishlar
    --
    --Bu operatsiya bo'lmagani uchun xodimlar shunday hollarda INC yozishga
    --majbur edi va investitsiya summasi noto'g'ri oshib ketardi.
    elsif vOperation.Oper_Code = 'OINC' then
      insert into ipt_investors_his
      select t.*, 'U', vSession_User, sysdate
        from ipt_investors t
       where t.id = vOperation.Investor_Id;

      update ipt_investors t
        set t.saldo_out = t.saldo_out + vOperation.Amount,
            t.up_by     = vSession_User,
            t.up_on     = sysdate
       where t.id = vOperation.Investor_Id;
    --Agar operatsiya "Прочее расход" bulsa
    --
    --OINC ning teskarisi: qoldiqdan ayiradi, total_investment ga tegmaydi.
    --
    --Bu shart: xato kiritilgan OINC ni faqat shu bilan bekor qilish mumkin.
    --Aks holda EXP yozishga to'g'ri kelardi, u esa qoldiq bilan birga
    --investitsiya summasini ham tushirib yuborardi.
    elsif vOperation.Oper_Code = 'OEXP' then
      if vInvestor.Saldo_Out < vOperation.Amount and vWork_In_Loss = 'N' then
        Raise_Error('Невозможно выполнить эту операцию. У инвестора Сальдо недостаточно денег для списания. Сальдо = '||vInvestor.Saldo_Out/100);
      end if;

      insert into ipt_investors_his
      select t.*, 'U', vSession_User, sysdate
        from ipt_investors t
       where t.id = vOperation.Investor_Id;

      update ipt_investors t
        set t.saldo_out = t.saldo_out - vOperation.Amount,
            t.up_by     = vSession_User,
            t.up_on     = sysdate
       where t.id = vOperation.Investor_Id;
    --Agar operatsiya "Фойда расход" bulsa
    elsif vOperation.Oper_Code = 'INCE' then
      if vInvestor.Income_Ip_Sum = 0 then
        Raise_Error('Невозможно выполнить эту операцию. Этот инвестор не имеет дохода INCE.');
      end if;

      vInvestor.Income_Ip_Sum := vInvestor.Income_Ip_Sum - ipt_util.Get_Investor_Trade_All_Debt(vInvestor.Id);

      if nvl(vInvestor.Income_Ip_Sum, 0) < vOperation.Amount and vWork_In_Loss = 'N' then
        Raise_Error('Невозможно выполнить эту операцию. У дохода INCE недостаточно денег для списания. INCE доход сальдо = '||vInvestor.Income_Ip_Sum/100);
      end if;

      if vInvestor.Saldo_Out < vOperation.Amount and vWork_In_Loss = 'N' then
        Raise_Error('Невозможно выполнить эту операцию. У инвестора Сальдо недостаточно денег для списания. Сальдо = '||vInvestor.Saldo_Out/100);
      end if;

      if vShould_Minus_Saldo then
        insert into ipt_investors_his
        select t.*,'U', vSession_User, sysdate
          from ipt_investors t
         where t.id = vOperation.Investor_Id;

        vOperation.Investor_Id := vInvestor.Id;
        vOperation.Oper_Code   := 'OEXP';
        vOperation.Comments    := 'Nasiya foydadan investor chiqim qilyotgani uchun investor qoldig''idan ayirilmoqda '||
                                  '(investor_id = '||vInvestor.Id||')';
        vOperation.Initiator   := 'I';

        Create_Operation(iOperation     => vOperation,
                         oOperation_Id  => vOperation_Id,
                         oResponse_Code => vResponse_Code,
                         oResponse_Msg  => vResponse_Msg);

        if vResponse_Code <> 0 then
          rollback;
          Raise_Error(vResponse_Msg);
        end if;

        update ipt_investors t
          set t.income_ip_sum = t.income_ip_sum - vOperation.Amount,
              t.saldo_out     = t.saldo_out - vOperation.Amount,
              t.up_by         = vSession_User,
              t.up_on         = sysdate
         where t.id = vOperation.Investor_Id;
      else
        update ipt_investors t
          set t.income_ip_sum = t.income_ip_sum - vOperation.Amount,
              t.up_by         = vSession_User,
              t.up_on         = sysdate
         where t.id = vOperation.Investor_Id;
      end if;
    --Agar operatsiya "Устама расход" bulsa
    elsif vOperation.Oper_Code = 'OPE' then
      if vInvestor.Income_Op_Sum = 0 then
        Raise_Error('Невозможно выполнить эту операцию. Этот инвестор не имеет дохода от OPE.');
      end if;

      if vInvestor.Income_Op_Sum < vOperation.Amount and vWork_In_Loss = 'N' then
        Raise_Error('Невозможно выполнить эту операцию. В доходе OPE недостаточно денег для списания. Доход ОПЕ = '||vInvestor.Income_Op_Sum/100);
      end if;

      if vInvestor.Saldo_Out < vOperation.Amount and vWork_In_Loss = 'N' then
        Raise_Error('Невозможно выполнить эту операцию. У инвестора Сальдо недостаточно денег для списания. Сальдо = '||vInvestor.Saldo_Out/100);
      end if;

      if vShould_Minus_Saldo then
        insert into ipt_investors_his
        select t.*, 'U', vSession_User, sysdate
          from ipt_investors t
         where t.id = vOperation.Investor_Id;

        vOperation.Investor_Id := vInvestor.Id;
        vOperation.Oper_Code   := 'OEXP';
        vOperation.Comments    := 'Ustama foydadan investor chiqim qilyotgani uchun investor qoldig''idan ayirilmoqda '||
                                  '(investor_id = '||vInvestor.Id||')';
        vOperation.Initiator   := 'I';

        Create_Operation(iOperation     => vOperation,
                         oOperation_Id  => vOperation_Id,
                         oResponse_Code => vResponse_Code,
                         oResponse_Msg  => vResponse_Msg);

        if vResponse_Code <> 0 then
          rollback;
          Raise_Error(vResponse_Msg);
        end if;

        update ipt_investors t
          set t.Income_Op_Sum = t.Income_Op_Sum - vOperation.Amount,
              t.saldo_out     = t.saldo_out - vOperation.Amount,
              t.up_by         = vSession_User,
              t.up_on         = sysdate
         where t.id = vOperation.Investor_Id;
      else
        update ipt_investors t
          set t.Income_Op_Sum = t.Income_Op_Sum - vOperation.Amount,
              t.up_by         = vSession_User,
              t.up_on         = sysdate
         where t.id = vOperation.Investor_Id;
      end if;
    --Agar operatsiya "Прочее расходы" bulsa
    --Manager_Operations dan KO'CHIRILDI. Manager versiyasida operatsiya ikki
    --marta yaratilardi (asosiy insert + Create_Operation, chunki mirror kodi
    --'OEXP' ga o'zgartirilmagan edi) -> dublikat xarajat bug'i.
    --Bu yerda Create_Operation CHAQIRILMAYDI: asosiy OTHEREXP operatsiyasi
    --procedura boshida allaqachon insert qilingan.
    elsif vOperation.Oper_Code = 'OTHEREXP' then
      if vInvestor.Income_Ip_Sum = 0 and vWork_In_Loss = 'N' then
        Raise_Error('Невозможно выполнить эту операцию. Этот инвестор не имеет дохода INCE.');
      end if;

      vInvestor.Income_Ip_Sum := vInvestor.Income_Ip_Sum - ipt_util.Get_Investor_Trade_All_Debt(vInvestor.Id);

      if nvl(vInvestor.Income_Ip_Sum, 0) < vOperation.Amount and vWork_In_Loss = 'N' then
        Raise_Error('Невозможно выполнить эту операцию. У дохода INCE недостаточно денег для списания. INCE доход сальдо = '||vInvestor.Income_Ip_Sum/100);
      end if;

      if vInvestor.Saldo_Out < vOperation.Amount and vWork_In_Loss = 'N' then
        Raise_Error('Невозможно выполнить эту операцию. У инвестора Сальдо недостаточно денег для списания. Сальдо = '||vInvestor.Saldo_Out/100);
      end if;

      insert into ipt_investors_his
      select t.*, 'U', vSession_User, sysdate
        from ipt_investors t
       where t.id = vOperation.Investor_Id;

      update ipt_investors t
        set t.income_ip_sum = t.income_ip_sum - vOperation.Amount,
            t.saldo_out     = t.saldo_out - vOperation.Amount,
            t.up_by         = vSession_User,
            t.up_on         = sysdate
       where t.id = vOperation.Investor_Id;
    --Agar operatsiya "Investor -> Investor" (transfer, chiqim tomoni) bo'lsa
    elsif vOperation.Oper_Code = 'I2IO' then
      -- Tekshiruvlar yuqorida (asosiy INSERT'dan oldin) bajarilgan.
      -- Bu yerda faqat saldo o'zgarishlari va qarama-qarshi operatsiya.

      -- 1) Jo'natuvchi (from) investor tarixi va kamaytirish
      insert into ipt_investors_his
      select t.*, 'U', vSession_User, sysdate
        from ipt_investors t
       where t.id = vInvestor.Id;

      update ipt_investors t
         set t.total_investment = t.total_investment - vOperation.Amount,
             t.saldo_out        = t.saldo_out - vOperation.Amount,
             t.up_by            = vSession_User,
             t.up_on            = sysdate
       where t.id = vInvestor.Id;

      -- 2) Qabul qiluvchi (to) investor uchun kirim operatsiyasini yaratish
      vOperation.Investor_Id         := vInvestor2.Id;
      vOperation.From_To_Investor_Id := vInvestor.Id;
      vOperation.Oper_Code           := 'I2II';
      vOperation.Filial_Code         := vInvestor2.Filial_Code;
      vOperation.Comments            := vComment||' (source_operation_id = '||vOperation.Id||')';
      vOperation.Initiator           := 'I';

      Create_Operation(iOperation     => vOperation,
                       oOperation_Id  => vOperation_Id,
                       oResponse_Code => vResponse_Code,
                       oResponse_Msg  => vResponse_Msg);

      if vResponse_Code <> 0 then
        rollback;
        Raise_Error(vResponse_Msg);
      end if;

      -- 3) Qabul qiluvchi investor tarixi va oshirish
      insert into ipt_investors_his
      select t.*, 'U', vSession_User, sysdate
        from ipt_investors t
       where t.id = vInvestor2.Id;

      update ipt_investors t
         set t.total_investment = t.total_investment + vOperation.Amount,
             t.saldo_out        = t.saldo_out + vOperation.Amount,
             t.up_by            = vSession_User,
             t.up_on            = sysdate
       where t.id = vInvestor2.Id;
    else
      Raise_Error('Неправильная операция.');
    end if;

    -- Ostatok/oborot snapshot: asosiy (I2IO da jo'natuvchi) investor.
    -- DIQQAT: vOperation.Investor_Id I2IO blokida vInvestor2 ga qayta yozilgan,
    -- shuning uchun bu yerda vInvestor.Id ishlatiladi.
    Ipt_Balance_Log.Log_Operation(iOperation_Id => vOperation.Id,
                                  iInvestor_Id  => vInvestor.Id,
                                  iSource_Module => 'investor_operations');

    -- I2IO bo'lsa qabul qiluvchi investorni ham loglaymiz
    if vInvestor2.Id is not null then
      Ipt_Balance_Log.Log_Operation(iOperation_Id => vOperation_Id,
                                    iInvestor_Id  => vInvestor2.Id,
                                    iSource_Module => 'investor_operations_i2ii');
    end if;

    vResponse.put('oper', true);
    vResponse.put('id', vOperation.Id);
    vResponse.put('message', 'Operation created successfully.');
    oResponse := vResponse.To_String;
  end;
