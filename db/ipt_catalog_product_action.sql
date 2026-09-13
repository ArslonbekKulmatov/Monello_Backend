-- =============================================================================
-- IPT KATALOG API — Ipt_Methods.Product_Action ga o'zgartirish
--
-- Nima uchun: bitta mahsulotni saqlash uchun ikkita API chaqirish noto'g'ri.
-- Katalog maydonlari endi mahsulotning o'z formasi bilan birga saqlanadi.
--
-- O'zgarish hajmi: I va U tarmoqlariga BITTADAN qator qo'shildi, boshqa
-- hech nimaga tegilmadi. Investor saldosi, refund, PRDEL/PREDT operatsiyalari
-- va balans loglari avvalgidek qoladi — katalog maydonlari pulga aloqador emas.
--
-- QANDAY QO'LLANADI
--   1. Avval db/ipt_catalog_stage1.sql va stage2.sql ishga tushirilgan bo'lsin
--      (Ipt_Catalog spetsifikatsiyasi Ipt_Methods dan oldin kerak).
--   2. PL/SQL Developer da Ipt_Methods paket TANASINI oching.
--   3. Undagi Product_Action protsedurasini quyidagi matn bilan almashtiring.
--   4. Paketni rekompilyatsiya qiling.
--
-- DIQQAT: bu fayl butun paket tanasi emas, faqat bitta protsedura.
-- To'g'ridan-to'g'ri ishga tushirib bo'lmaydi.
--
-- Kompilyatsiya tartibi: Ipt_Catalog spec -> Ipt_Methods body -> Ipt_Catalog body.
-- Ipt_Catalog tanasi Ipt_Methods ni chaqiradi, Ipt_Methods tanasi esa
-- Ipt_Catalog ni — bu Oracle uchun normal, chunki spetsifikatsiyalar
-- bir-biriga bog'liq emas.
--
-- Muallif: Arslonbek Kulmatov
-- Sana   : 13.09.2026
-- =============================================================================

  Procedure Product_Action(iParams varchar2, oResponse out varchar2)
  is
    vJson                  json_object_t := json_object_t.parse(iParams);
    vParams                json_object_t := vJson.get_Object('params');
    vAction                varchar2(5);
    vSession_User          number := core_session.Get_User_Id;
    vResponse              json_object_t := json_object_t();
    vProduct               ipt_products%rowtype;
    vCount                 pls_integer;
    vInvestor_Saldo        number(22);
    vResponse_Code         number;
    vResponse_Msg          varchar2(4000);
    vOperation_Id          number;
    vWork_In_Loss          varchar2(100) := ipt_util.Get_Param_Value(2);
    vOld_Price             number;
    vOld_Investor_Id       number;
    vOld_Quantity          number;
  begin
    Check_For_Seller;
    Check_For_Existance(vParams, 'action');

    vAction := vParams.get_String('action');
    if vAction is null then
      Raise_Error('действие не может быть нулевым.');
    end if;

    if vAction not in ('I', 'U', 'D') then
      Raise_Error('действие должно быть только «I», «U», «D».');
    end if;

    if vAction = 'I' then
      Check_For_Existance(vParams, 'name');
      Check_For_Existance(vParams, 'price');
      Check_For_Existance(vParams, 'investor_id');
      Check_For_Existance(vParams, 'type');
      Check_For_Existance(vParams, 'quantity');

      vProduct.Id := ipt_products_seq.nextval;
      vProduct.Name := vParams.get_String('name');
      vProduct.Price := round(vParams.get_Number('price'), 2)*100;
      vProduct.Investor_Id := vParams.get_Number('investor_id');
      vProduct.Provider := vParams.get_String('provider');
      vProduct.Type := vParams.get_String('type');
      vProduct.Quantity := vParams.get_Number('quantity');
      
      if vProduct.Type = 'T' then
        vProduct.Car_Type                  := vParams.get_Number('car_type');
        vProduct.Car_Plate_Number          := vParams.get_String('car_plate_number');
        vProduct.Car_Production_Year       := vParams.get_Number('car_production_year');
        vProduct.Car_Color                 := vParams.get_String('car_color');
        vProduct.Car_Tech_Passport_Number  := vParams.get_String('car_tech_passport_number');
        vProduct.Car_Body_Number           := vParams.get_String('car_body_number');
        vProduct.Car_Engine_Number         := vParams.get_String('car_engine_number');
        vProduct.Car_Mileage               := vParams.get_Number('car_mileage');
        vProduct.Car_Owner_Name            := vParams.get_String('car_owner_name');
        vProduct.Car_Gen_Trust_Name        := vParams.get_String('car_gen_trust_name');
        vProduct.Car_Register_Name         := vParams.get_String('car_register_name');
        vProduct.Car_Expense_Amount        := round(vParams.get_Number('car_expense_amount'), 2)*100;
        vProduct.Car_Expense_Details       := vParams.get_String('car_expense_details');
        vProduct.Car_Market_Price_Min_Max  := vParams.get_String('car_market_price_min_max');
        vProduct.Car_Purchase_Date         := to_date(vParams.get_String('car_purchase_date'), 'dd.mm.yyyy');
        vProduct.Car_Tuning_Details        := vParams.get_String('car_tuning_details');
        vProduct.Car_Paint_Condition       := vParams.get_String('car_paint_condition');
        vProduct.Car_Price                 := round(vParams.get_Number('car_price'), 2)*100;
      end if;
      

      -- Katalog maydonlari (sayt uchun): model_code, model_name, category_code,
      -- brand_code, item_condition, phys_filial_code, retail_price_uzs.
      -- Faqat so'rovda KELGAN maydonlar qo'yiladi — sababi Apply_Catalog_Fields da.
      Ipt_Catalog.Apply_Catalog_Fields(vParams, vProduct);

      select count(*) into vCount
        from ipt_investors t
       where t.condition = 'A'
        and t.id = vProduct.Investor_Id;

      if vCount = 0 then
        Raise_Error('инвестор с таким идентификатором не найден.');
      end if;

      vProduct.State := 'S';
      vProduct.Cr_By := vSession_User;
      vProduct.Cr_On := sysdate;
      vProduct.filial_code := core_session.Get_Filial_Code;

      vInvestor_Saldo := Ipt_Util.Get_Investor_Saldo(iInvestor_Id => vProduct.Investor_Id);

      if vInvestor_Saldo < (vProduct.Price * nvl(vProduct.Quantity, 1)) and vWork_In_Loss = 'N' then
        Raise_Error('Недостаточно сальдо для этого инвестора для этого продукта. сальдо = '||vInvestor_Saldo/100);
      end if;

      Debit_From_Investor_Saldo(iInvestor_Id   => vProduct.Investor_Id,
                                iAmount        => vProduct.Price * nvl(vProduct.Quantity, 1),
                                oResponse_Code => vResponse_Code,
                                oResponse_Msg  => vResponse_Msg,
                                oOperation_Id  => vOperation_Id);
      if vResponse_Code = 0 then
        vProduct.Operation_Id := vOperation_Id;
        insert into ipt_products values vProduct;
        
        Ipt_methods_Dml.Product_His(p_Product_Id => vProduct.Id, p_Action => vAction);

        -- Sklad snapshot: mahsulot omborga kirdi, warehouse_amount o'zgardi.
        -- (Saldo o'zgarishi Debit_From_Investor_Saldo ichida loglangan, bu esa
        --  sklad qiymati yangilangandan keyingi holat.)
        Ipt_Balance_Log.Log_Operation(iOperation_Id => vOperation_Id,
                                      iInvestor_Id  => vProduct.Investor_Id,
                                      iSource_Module => 'product_action_i:'||vProduct.Id);
      else
        Raise_Error('Невозможно выполнить эту операцию: '||vResponse_Msg);
      end if;

      vResponse.put('oper', true);
      vResponse.put('id', vProduct.Id);
      vResponse.put('message', 'Product successfully inserted.');
    elsif vAction = 'U' then
      Check_For_Existance(vParams, 'id');
      Check_For_Existance(vParams, 'name');
      Check_For_Existance(vParams, 'price');
      Check_For_Existance(vParams, 'investor_id');
      Check_For_Existance(vParams, 'type');
      Check_For_Existance(vParams, 'quantity');

      vProduct.Id := vParams.get_Number('id');

      begin
        select t.* into vProduct
          from ipt_products t
         where t.id = vProduct.Id;
      exception
        when no_data_found then
          Raise_Error('товар с таким идентификатором не найден.');
      end;

      if vProduct.State not in ('S') then
        Raise_Error('Невозможно обновить этот продукт в этом состоянии.');
      end if;
      
      -- Eski (DB) qiymatlar — refund eski narx/investor bo'yicha bo'lishi kerak.
      -- vProduct.Quantity bu allaqachon QOLGAN (sotilmagan) miqdor.
      vOld_Price       := vProduct.Price;
      vOld_Investor_Id := vProduct.Investor_Id;
      vOld_Quantity    := nvl(vProduct.Quantity, 0);

      vProduct.Name := vParams.get_String('name');
      vProduct.Price := round(vParams.get_Number('price'), 2)*100;
      vProduct.Investor_Id := vParams.get_Number('investor_id');
      vProduct.Provider := vParams.get_String('provider');
      vProduct.Type := vParams.get_String('type');
      vProduct.Quantity := vParams.get_Number('quantity');
      
      if vProduct.Type = 'T' then
        vProduct.Car_Type                  := vParams.get_Number('car_type');
        vProduct.Car_Plate_Number          := vParams.get_String('car_plate_number');
        vProduct.Car_Production_Year       := vParams.get_Number('car_production_year');
        vProduct.Car_Color                 := vParams.get_String('car_color');
        vProduct.Car_Tech_Passport_Number  := vParams.get_String('car_tech_passport_number');
        vProduct.Car_Body_Number           := vParams.get_String('car_body_number');
        vProduct.Car_Engine_Number         := vParams.get_String('car_engine_number');
        vProduct.Car_Mileage               := vParams.get_Number('car_mileage');
        vProduct.Car_Owner_Name            := vParams.get_String('car_owner_name');
        vProduct.Car_Gen_Trust_Name        := vParams.get_String('car_gen_trust_name');
        vProduct.Car_Register_Name         := vParams.get_String('car_register_name');
        vProduct.Car_Expense_Amount        := round(vParams.get_Number('car_expense_amount'), 2)*100;
        vProduct.Car_Expense_Details       := vParams.get_String('car_expense_details');
        vProduct.Car_Market_Price_Min_Max  := vParams.get_String('car_market_price_min_max');
        vProduct.Car_Purchase_Date         := to_date(vParams.get_String('car_purchase_date'), 'dd.mm.yyyy');
        vProduct.Car_Tuning_Details        := vParams.get_String('car_tuning_details');
        vProduct.Car_Paint_Condition       := vParams.get_String('car_paint_condition');
        vProduct.Car_Price                 := round(vParams.get_Number('car_price'), 2)*100;
      end if;

      -- Katalog maydonlari (sayt uchun): model_code, model_name, category_code,
      -- brand_code, item_condition, phys_filial_code, retail_price_uzs.
      -- Faqat so'rovda KELGAN maydonlar qo'yiladi — sababi Apply_Catalog_Fields da.
      Ipt_Catalog.Apply_Catalog_Fields(vParams, vProduct);

      select count(*) into vCount
        from ipt_investors t
       where t.condition = 'A'
        and t.id = vProduct.Investor_Id;

      if vCount = 0 then
        Raise_Error('инвестор с таким идентификатором не найден.');
      end if;
      
      vProduct.Up_By := vSession_User;
      vProduct.Up_On := sysdate;

      -- ESKI: Cancel_Investor_Operation butun IW ni (old_price*boshlang'ich_qty) qaytarardi.
      -- YANGI: faqat QOLGAN donalarni eski narxda qaytaramiz (D blokidagi PRDEL patterni).
      declare
        vRefund_Amount   number := vOld_Price * vOld_Quantity;
        vRefund_Op       ipt_operations%rowtype;
        vRefund_Op_Id    number;
      begin
        if vRefund_Amount > 0 then
          vRefund_Op.Investor_Id := vOld_Investor_Id;
          vRefund_Op.Oper_Code   := 'PREDT';   -- mahsulot tahriri: qolgan qism qaytarish
          vRefund_Op.Amount      := vRefund_Amount;
          vRefund_Op.Comments    := 'Mahsulot tahrirlanishi sababli qolgan '||vOld_Quantity||
                                    ' dona eski narxda ('||vOld_Price/100||'$) investor qoldig''iga '||
                                    'qaytarilmoqda (product_id = '||vProduct.Id||')';
          vRefund_Op.Initiator   := 'I';

          Create_Operation(iOperation     => vRefund_Op,
                           oOperation_Id  => vRefund_Op_Id,
                           oResponse_Code => vResponse_Code,
                           oResponse_Msg  => vResponse_Msg);

          if vResponse_Code <> 0 then
            rollback;
            Raise_Error('Невозможно вернуть остаток: '||vResponse_Msg);
          end if;

          insert into ipt_investors_his
          select t.*, 'U', vSession_User, sysdate
            from ipt_investors t
           where t.id = vOld_Investor_Id;

          update ipt_investors t
             set t.saldo_out = t.saldo_out + vRefund_Amount,
                 t.up_by     = vSession_User,
                 t.up_on     = sysdate
           where t.id = vOld_Investor_Id;

          -- Ostatok snapshot: tahrir sababli qolgan qism ESKI investorga qaytdi.
          -- Yangi IW (Debit_From_Investor_Saldo) o'z ichida alohida loglanadi.
          Ipt_Balance_Log.Log_Operation(iOperation_Id => vRefund_Op_Id,
                                        iInvestor_Id  => vOld_Investor_Id,
                                        iSource_Module => 'product_action_u_refund:'||vProduct.Id);
        end if;
      end;

      -- Yangi konfiguratsiya bo'yicha qaytadan yechish (yangi investor/narx/qty)
      vResponse_Code := null;
      Debit_From_Investor_Saldo(iInvestor_Id   => vProduct.Investor_Id,
                                iAmount        => vProduct.Price * nvl(vProduct.Quantity, 1),
                                oResponse_Code => vResponse_Code,
                                oResponse_Msg  => vResponse_Msg,
                                oOperation_Id  => vOperation_Id);

      if vResponse_Code = 0 then
        vProduct.Operation_Id := vOperation_Id;

        -- History: update'DAN OLDIN (before-image) — Trade_Action bilan bir xil.
        -- Eski koddagi Product_His update'dan KEYIN edi -> after-image saqlanardi.
        Ipt_methods_Dml.Product_His(p_Product_Id => vProduct.Id, p_Action => vAction);

        update ipt_products t
          set row = vProduct
         where t.id = vProduct.Id;

        -- Sklad snapshot: yangi narx/miqdor bo'yicha warehouse_amount o'zgardi
        Ipt_Balance_Log.Log_Operation(iOperation_Id => vOperation_Id,
                                      iInvestor_Id  => vProduct.Investor_Id,
                                      iSource_Module => 'product_action_u_debit:'||vProduct.Id);
      else
        rollback;
        Raise_Error('Невозможно выполнить эту операцию: '||vResponse_Msg);
      end if;

      vResponse.put('oper', true);
      vResponse.put('id', vProduct.Id);
      vResponse.put('message', 'Product successfully updated.');
    elsif vAction = 'D' then
      Check_For_Existance(vParams, 'id');

      vProduct.Id := vParams.get_Number('id');

      begin
        select t.* into vProduct
          from ipt_products t
         where t.id = vProduct.Id;
      exception
        when no_data_found then
          Raise_Error('товар с таким идентификатором не найден.');
      end;

      if vProduct.State <> 'S' then
        Raise_Error('Невозможно удалить этот продукт в этом состоянии.');
      end if;

      declare
        vRemaining_Qty      number := 0;
        vRefund_Amount      number := 0;
        vNew_Operation_Id   number;
        vRefund_Operation   ipt_operations%rowtype;
        vAny_Sale           number := 0;
      begin
        vRemaining_Qty := nvl(vProduct.Quantity, 0);

        if vRemaining_Qty <= 0 then
          Raise_Error('Невозможно удалить этот продукт. Такого товара не существует. Количество: 0.');
        end if;

        vRefund_Amount := vProduct.Price * vRemaining_Qty;

        Ipt_methods_Dml.Product_His(p_Product_Id => vProduct.Id, p_Action => vAction);

        -- Sotilmagan qism uchun investor saldosiga qaytarish (PRDEL)
        vRefund_Operation.Investor_Id := vProduct.Investor_Id;
        vRefund_Operation.Oper_Code   := 'PRDEL';
        vRefund_Operation.Amount      := vRefund_Amount;
        vRefund_Operation.Comments    := 'Mahsulot omboridan o''chirilishi sababli sotilmagan '||
                                         vRemaining_Qty||' dona uchun ('||vProduct.Price/100||
                                         '$ x '||vRemaining_Qty||') investor qoldig''iga qaytarilmoqda '||
                                         '(product_id = '||vProduct.Id||')';
        vRefund_Operation.Initiator   := 'I';

        Create_Operation(iOperation     => vRefund_Operation,
                         oOperation_Id  => vNew_Operation_Id,
                         oResponse_Code => vResponse_Code,
                         oResponse_Msg  => vResponse_Msg);

        if vResponse_Code <> 0 then
          rollback;
          Raise_Error('Невозможно вернуть остаток: '||vResponse_Msg);
        end if;

        -- Investor tarixi va saldo
        insert into ipt_investors_his
        select t.*, 'U', vSession_User, sysdate
          from ipt_investors t
         where t.id = vProduct.Investor_Id;

        update ipt_investors t
           set t.saldo_out = t.saldo_out + vRefund_Amount,
               t.up_by    = vSession_User,
               t.up_on    = sysdate
         where t.id = vProduct.Investor_Id;

        -- FK bog'lanish tekshiruvi: agar biror sotuv bo'lgan bo'lsa yumshoq o'chirish
        select count(*) into vAny_Sale
          from (select 1 from ipt_product_sells where product_id = vProduct.Id
                union all
                select 1 from ipt_trades where product_id = vProduct.Id);

        if vAny_Sale > 0 then
          update ipt_products t
             set t.quantity = 0,
                 t.state    = 'P',
                 t.up_by    = vSession_User,
                 t.up_on    = sysdate
           where t.id = vProduct.Id;
        else
          delete from ipt_products t where t.id = vProduct.Id;
        end if;

        -- Ostatok/sklad snapshot: sotilmagan qism saldoga qaytdi va
        -- mahsulot skladdan chiqdi (warehouse_amount kamaydi).
        -- Mahsulot o'chirilgandan KEYIN chaqiriladi, shunda sklad qiymati to'g'ri.
        Ipt_Balance_Log.Log_Operation(iOperation_Id => vNew_Operation_Id,
                                      iInvestor_Id  => vProduct.Investor_Id,
                                      iSource_Module => 'product_action_d:'||vProduct.Id);
      end;

      vResponse.put('oper', true);
      vResponse.put('id', vProduct.Id);
      vResponse.put('message', 'Product successfully deleted.');
    end if;
    oResponse := vResponse.To_String;
  end;
