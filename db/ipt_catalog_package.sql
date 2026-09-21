-- =============================================================================
-- IPT_CATALOG — katalog API paketi
--
-- Bu paketning YAGONA manbasi shu fayl. stage1-stage3 dan KEYIN ishga
-- tushiriladi, chunki u o'sha yerdagi jadval va view'larga tayanadi.
--
-- ISHGA TUSHIRISH TARTIBI
--   1. ipt_catalog_stage1.sql
--   2. ipt_catalog_stage2.sql
--   3. ipt_catalog_stage3.sql
--   4. ipt_catalog_package.sql         <- shu fayl
--   5. ipt_catalog_product_action.sql  <- Ipt_Methods ga qo'lda
--
-- Kompilyatsiya tartibi: Ipt_Catalog spec -> Ipt_Methods body -> Ipt_Catalog
-- body. Ipt_Catalog tanasi Ipt_Methods ni chaqiradi, Ipt_Methods tanasi esa
-- Ipt_Catalog ni — spetsifikatsiyalar bir-biriga bog'liq emas, shuning uchun
-- Oracle buni normal hal qiladi.
--
-- Muallif: Arslonbek Kulmatov
-- Sana   : 13.09.2026
-- =============================================================================

prompt Ipt_Catalog — spetsifikatsiya

create or replace package Ipt_Catalog is

  -- Author  : Arslonbek Kulmatov
  -- Created : 13.09.2026
  -- Purpose : ABM Store sayti uchun katalog API

  --Cr By: Arslonbek Kulmatov
  --So'rovda katalog maydonlaridan birortasi bormi
  Function Has_Any_Catalog_Field(iParams json_object_t) return boolean;

  --Cr By: Arslonbek Kulmatov
  --Katalog maydonlarini tekshirib, mahsulot qatoriga qo'yish.
  --Ipt_Methods.Product_Action shu orqali chaqiradi — bitta mahsulotni
  --saqlash uchun ikkinchi API chaqiruvi kerak bo'lmasligi uchun.
  Procedure Apply_Catalog_Fields(iParams   json_object_t,
                                 ioProduct in out nocopy ipt_products%rowtype);

  --Cr By: Arslonbek Kulmatov
  --To'liq katalog, sahifalab
  Procedure Get_Products(iParams clob, oResponse out clob);

  --Cr By: Arslonbek Kulmatov
  --Faqat narx va qoldiq — tez-tez so'raladigan yengil metod
  Procedure Get_Stock(iParams clob, oResponse out clob);

  --Cr By: Arslonbek Kulmatov
  --Bir nechta tovarga bir xil katalog maydonlarini qo'yish (ommaviy)
  Procedure Save_Product(iParams clob, oResponse out clob);

  --Cr By: Arslonbek Kulmatov
  --Rasmni SERVERGA yuklash. Core_App.Set_Method_File orqali chaqiriladi,
  --shuning uchun imzo (iParams, iFile, oResponse) ko'rinishida.
  Procedure Upload_Image(iParams varchar2, iFile blob default null, oResponse out clob);

  --Cr By: Arslonbek Kulmatov
  --Tashqi havolali rasm qo'shish yoki mavjud rasm ma'lumotini o'zgartirish
  Procedure Save_Image(iParams clob, oResponse out clob);

  --Cr By: Arslonbek Kulmatov
  --Rasmni o'chirish
  Procedure Delete_Image(iParams clob, oResponse out clob);

  --Cr By: Arslonbek Kulmatov
  --Model xarakteristikalari. Modelning BARCHA xarakteristikalari almashtiriladi
  Procedure Save_Model_Attributes(iParams clob, oResponse out clob);

end Ipt_Catalog;
/


prompt Ipt_Catalog — tanasi

create or replace package body Ipt_Catalog is

  -- Sahifa hajmi chegarasi. Sayt 100-500 oralig'ini so'ragan.
  cMax_Per_Page constant number := 500;

  -- ===========================================================================
  -- Kichik yordamchilar
  -- ===========================================================================

  --Cr By: Arslonbek Kulmatov
  --Parametrlar obyekti. Tizimdagi barcha metodlar kabi {"method":..,"params":{..}}
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

  --Cr By: Arslonbek Kulmatov
  --Bo'sh bo'lmagan qiymatnigina javobga qo'yish.
  --Sayt "null yoki maydonning o'zi yo'q — farqi yo'q" degan, shuning uchun
  --bo'shlarini umuman yubormaymiz: javob yengilroq bo'ladi.
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

  Procedure Put_Bool(ioObj in out nocopy json_object_t, iKey varchar2, iVal number)
  is
  begin
    if iVal is not null then
      ioObj.put(iKey, iVal = 1);
    end if;
  end;

  --Cr By: Arslonbek Kulmatov
  --So'rovda kelgan matn maydonini o'qish. Kelmagan bo'lsa TEGILMAYDI.
  Procedure Read_Str(iParams json_object_t, iKey varchar2, ioVal in out nocopy varchar2)
  is
  begin
    if iParams.has(iKey) then
      ioVal := trim(iParams.get_String(iKey));
    end if;
  end;

  Procedure Read_Num(iParams json_object_t, iKey varchar2, ioVal in out nocopy number)
  is
  begin
    if iParams.has(iKey) then
      ioVal := iParams.get_Number(iKey);
    end if;
  end;

  --Cr By: Arslonbek Kulmatov
  --Sonni matnga o'girish. NLS ga bog'liq bo'lmasligi uchun ajratuvchi aniq
  --ko'rsatilgan: aks holda serverda "13,5" chiqib, sayt buni sonsiz deb o'qiydi.
  Function Num_To_Str(iValue number) return varchar2
  is
  begin
    if iValue is null then
      return null;
    end if;

    return trim(to_char(iValue, 'TM9', 'NLS_NUMERIC_CHARACTERS=''.,'''));
  end;

  --Cr By: Arslonbek Kulmatov
  --JSON dagi istalgan oddiy qiymatni matn sifatida o'qish.
  --
  --get_String FAQAT matn qiymatida ishlaydi: {"power_w": 20} da u NULL
  --qaytaradi va qiymat jimgina yo'qoladi. Sayt esa aynan shunday yuboradi
  --("power_w": 20, "network_5g": true), shuning uchun tur bo'yicha ajratamiz.
  Function Json_Scalar(iObj json_object_t, iKey varchar2) return varchar2
  is
    vEl json_element_t;
  begin
    if not iObj.has(iKey) then
      return null;
    end if;

    vEl := iObj.get(iKey);

    if vEl is null then
      return null;
    elsif vEl.is_Number then
      return Num_To_Str(iObj.get_Number(iKey));
    elsif vEl.is_Boolean then
      return case when iObj.get_Boolean(iKey) then 'true' else 'false' end;
    else
      return iObj.get_String(iKey);
    end if;
  end;

  --Cr By: Arslonbek Kulmatov
  --Massiv elementini matn sifatida o'qish — Json_Scalar bilan bir sabab
  Function Json_Scalar(iArr json_array_t, iPos number) return varchar2
  is
    vEl json_element_t := iArr.get(iPos);
  begin
    if vEl is null then
      return null;
    elsif vEl.is_Number then
      return Num_To_Str(iArr.get_Number(iPos));
    elsif vEl.is_Boolean then
      return case when iArr.get_Boolean(iPos) then 'true' else 'false' end;
    else
      return iArr.get_String(iPos);
    end if;
  end;

  --Cr By: Arslonbek Kulmatov
  --Mantiqiy qiymat: bazada 1/0. So'rovda true, "true", 1 — hammasi bo'lishi mumkin.
  Function Json_Bool(iObj json_object_t, iKey varchar2) return number
  is
    vVal varchar2(100) := Json_Scalar(iObj, iKey);
  begin
    if vVal is null then
      return null;
    end if;

    return case when lower(vVal) in ('true', '1', 'y') then 1 else 0 end;
  end;

  --Cr By: Arslonbek Kulmatov
  --Mantiqiy maydonni o'qish. Kelmagan bo'lsa TEGILMAYDI.
  Procedure Read_Bool(iParams json_object_t, iKey varchar2, ioVal in out nocopy number)
  is
  begin
    if iParams.has(iKey) then
      ioVal := Json_Bool(iParams, iKey);
    end if;
  end;

  --Cr By: Arslonbek Kulmatov
  --Matnni songa o'girish. Noto'g'ri qiymat butun API'ni yiqitmasligi uchun.
  Function To_Num_Safe(iValue varchar2) return number
  is
  begin
    return to_number(iValue);
  exception
    when others then
      return null;
  end;

  --Cr By: Arslonbek Kulmatov
  --"a,b,c" -> ["a","b","c"]
  --
  --xmltable ishlatilmadi ataylab: u qulay ko'rinsa ham, foydalanuvchi
  --kiritgan matnda & yoki < uchrasa XML sifatida yiqiladi va tushunarsiz
  --ORA xatosi chiqadi.
  Function Split_Csv(iValue varchar2) return json_array_t
  is
    vParts json_array_t := json_array_t();
    vRest  varchar2(4000) := iValue;
    vPos   pls_integer;
    vItem  varchar2(4000);
  begin
    if vRest is null then
      return vParts;
    end if;

    loop
      vPos := instr(vRest, ',');

      if vPos = 0 then
        vItem := trim(vRest);
        vRest := null;
      else
        vItem := trim(substr(vRest, 1, vPos - 1));
        vRest := substr(vRest, vPos + 1);
      end if;

      if vItem is not null then
        vParts.append(vItem);
      end if;

      exit when vRest is null;
    end loop;

    return vParts;
  end;

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
  --Qolgan shourumlarga 0 qo'yiladi — sayt tomonda obyekt shakli o'zgarmasin.
  --Cr By: Arslonbek Kulmatov
  --Shourumlar bo'yicha qoldiq.
  --
  --View allaqachon {"mirobod":2} ko'rinishidagi JSON beradi, lekin unda
  --faqat qoldig'i BOR shourumlar bo'ladi. Sayt esa barcha shourumlar har
  --doim bo'lishini so'ragan — obyekt shakli pozitsiyadan pozitsiyaga
  --o'zgarmasligi uchun. Yo'qlari shu yerda nol bilan to'ldiriladi.
  Function Build_Quantity(iSites   json_array_t,
                          iQtyJson varchar2) return json_object_t
  is
    vQty  json_object_t := json_object_t();
    vSrc  json_object_t;
    vCode varchar2(30);
  begin
    if iQtyJson is not null then
      vSrc := json_object_t.parse(iQtyJson);
    end if;

    for i in 0 .. iSites.get_size - 1
    loop
      vCode := iSites.get_string(i);
      vQty.put(vCode, case when vSrc is null then 0
                           else nvl(vSrc.get_Number(vCode), 0) end);
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
  --Sanani ISO-8601 ko'rinishida, server smeshcheniyesi bilan
  Function To_Iso(iDate date) return varchar2
  is
  begin
    if iDate is null then
      return null;
    end if;

    return to_char(from_tz(cast(iDate as timestamp), sessiontimezone),
                   'YYYY-MM-DD"T"HH24:MI:SSTZH:TZM');
  end;

  -- ===========================================================================
  -- Katalog maydonlarini saqlash
  -- ===========================================================================

  --Cr By: Arslonbek Kulmatov
  Function Has_Any_Catalog_Field(iParams json_object_t) return boolean
  is
    cKeys constant varchar2(1000) :=
      'model_code,model_name,model_name_uz,category_code,brand_code,item_condition,'||
      'retail_price_uzs,old_price_uzs,phys_filial_code,storage_gb,ram_gb,color_code,'||
      'sku,warranty_months,description_ru,description_uz,battery_health_pct,imei,'||
      'serial,sim_type,market_code,replaced_parts,has_box,has_charger';
    vKeys json_array_t := Split_Csv(cKeys);
  begin
    for i in 0 .. vKeys.get_size - 1
    loop
      if iParams.has(vKeys.get_string(i)) then
        return true;
      end if;
    end loop;

    return false;
  end;

  --Cr By: Arslonbek Kulmatov
  --Ma'lumotnomada kod bor-yo'qligini tekshirish
  Procedure Check_Color(iCode varchar2)
  is
    vCount pls_integer;
  begin
    if iCode is null then
      return;
    end if;

    select count(*) into vCount from ipt_s_colors t
     where t.code = iCode and t.condition = 'A';

    if vCount = 0 then
      Ipt_Methods.Raise_Error('Bunday rang yo''q yoki faol emas: '||iCode);
    end if;
  end;

  Procedure Check_Sim_Type(iCode varchar2)
  is
    vCount pls_integer;
  begin
    if iCode is null then
      return;
    end if;

    select count(*) into vCount from ipt_s_sim_types t
     where t.code = iCode and t.condition = 'A';

    if vCount = 0 then
      Ipt_Methods.Raise_Error('Bunday SIM turi yo''q: '||iCode);
    end if;
  end;

  Procedure Check_Market_Code(iCode varchar2)
  is
    vCount pls_integer;
  begin
    if iCode is null then
      return;
    end if;

    select count(*) into vCount from ipt_s_market_codes t
     where t.code = iCode and t.condition = 'A';

    if vCount = 0 then
      Ipt_Methods.Raise_Error('Bunday bozor kodi yo''q: '||iCode);
    end if;
  end;

  --Cr By: Arslonbek Kulmatov
  --"screen,back_cover" ko'rinishidagi ro'yxatni tekshirish
  Procedure Check_Replaced_Parts(iValue varchar2)
  is
    vParts json_array_t := Split_Csv(iValue);
    vPart  varchar2(100);
    vCount pls_integer;
  begin
    for i in 0 .. vParts.get_size - 1
    loop
      vPart := vParts.get_string(i);

      select count(*) into vCount from ipt_s_replaced_parts t
       where t.code = vPart and t.condition = 'A';

      if vCount = 0 then
        Ipt_Methods.Raise_Error('Bunday almashtirilgan qism yo''q: '||vPart||
                                '. Mumkin qiymatlar ipt_s_replaced_parts_v da.');
      end if;
    end loop;
  end;

  --Cr By: Arslonbek Kulmatov
  --Katalog maydonlarini tekshirib, mahsulot qatoriga qo'yish.
  --
  --FAQAT so'rovda kelgan maydonlar qo'yiladi. Product_Action U tarmog'ida
  --"update ipt_products t set row = vProduct" ishlatadi — ya'ni butun qator
  --almashtiriladi. Shartsiz o'zlashtirsak, bu maydonlarni hali yubormaydigan
  --forma har saqlashda katalog ma'lumotini NULL bilan o'chirib yuborardi.
  Procedure Apply_Catalog_Fields(iParams   json_object_t,
                                 ioProduct in out nocopy ipt_products%rowtype)
  is
    vCount        pls_integer;
    vPrice        number;
    vIs_Container pls_integer;
  begin
    -- --- matn maydonlari, tekshiruvsiz ---
    Read_Str(iParams, 'model_name',     ioProduct.Model_Name);
    Read_Str(iParams, 'model_name_uz',  ioProduct.Model_Name_Uz);
    Read_Str(iParams, 'sku',            ioProduct.Sku);
    Read_Str(iParams, 'description_ru', ioProduct.Description_Ru);
    Read_Str(iParams, 'description_uz', ioProduct.Description_Uz);
    Read_Str(iParams, 'serial',         ioProduct.Serial);
    Read_Str(iParams, 'imei',           ioProduct.Imei);

    -- --- son maydonlari ---
    Read_Num(iParams, 'storage_gb',         ioProduct.Storage_Gb);
    Read_Num(iParams, 'ram_gb',             ioProduct.Ram_Gb);
    Read_Num(iParams, 'warranty_months',    ioProduct.Warranty_Months);
    Read_Num(iParams, 'battery_health_pct', ioProduct.Battery_Health_Pct);

    -- --- mantiqiy maydonlar ---
    Read_Bool(iParams, 'has_box',     ioProduct.Has_Box);
    Read_Bool(iParams, 'has_charger', ioProduct.Has_Charger);

    -- --- model kodi ---
    if iParams.has('model_code') then
      ioProduct.Model_Code := lower(trim(iParams.get_String('model_code')));

      if ioProduct.Model_Code is not null
         and not regexp_like(ioProduct.Model_Code, '^[a-z0-9]+(-[a-z0-9]+)*$') then
        Ipt_Methods.Raise_Error('"model_code" faqat kichik lotin harflari, raqam va "-" dan '||
                                'iborat bo''lishi kerak: iphone-16-pro-max');
      end if;
    end if;

    -- --- kategoriya ---
    if iParams.has('category_code') then
      ioProduct.Category_Code := trim(iParams.get_String('category_code'));

      if ioProduct.Category_Code is not null then
        begin
          select c.is_container into vIs_Container
            from ipt_s_categories c
           where c.code = ioProduct.Category_Code
             and c.condition = 'A';
        exception
          when no_data_found then
            Ipt_Methods.Raise_Error('Bunday kategoriya yo''q yoki faol emas: '||
                                    ioProduct.Category_Code);
        end;

        -- Konteyner bo'lim saytda ro'yxat bo'lib ko'rinadi, tovar esa aniq
        -- bo'limga tushishi kerak. Sayt jamoasi 21.09.2026 da shuni so'radi:
        -- "accessories" va "used" ga tovar qo'yilmaydi.
        if vIs_Container = 1 then
          Ipt_Methods.Raise_Error('"'||ioProduct.Category_Code||'" — konteyner bo''lim, '||
                                  'unga tovar qo''yilmaydi. Aniq bo''limni tanlang: '||
                                  'aksessuar uchun acc-*, ishlatilgan texnika uchun *-bu.');
        end if;
      end if;
    end if;

    -- --- brend ---
    if iParams.has('brand_code') then
      ioProduct.Brand_Code := trim(iParams.get_String('brand_code'));

      if ioProduct.Brand_Code is not null then
        select count(*) into vCount from ipt_s_brands b
         where b.code = ioProduct.Brand_Code and b.condition = 'A';

        if vCount = 0 then
          Ipt_Methods.Raise_Error('Bunday brend yo''q yoki faol emas: '||ioProduct.Brand_Code);
        end if;
      end if;
    end if;

    -- --- holat ---
    if iParams.has('item_condition') then
      ioProduct.Item_Condition := lower(trim(iParams.get_String('item_condition')));

      if ioProduct.Item_Condition is not null
         and ioProduct.Item_Condition not in ('new', 'used') then
        Ipt_Methods.Raise_Error('"item_condition" faqat "new" yoki "used" bo''ladi.');
      end if;
    end if;

    -- --- filial ---
    if iParams.has('phys_filial_code') then
      ioProduct.Phys_Filial_Code := trim(iParams.get_String('phys_filial_code'));

      if ioProduct.Phys_Filial_Code is not null then
        select count(*) into vCount from ipt_s_filials f
         where f.code = ioProduct.Phys_Filial_Code;

        if vCount = 0 then
          Ipt_Methods.Raise_Error('Bunday filial yo''q: '||ioProduct.Phys_Filial_Code);
        end if;
      end if;
    end if;

    -- --- ma'lumotnomali kichik maydonlar ---
    if iParams.has('color_code') then
      ioProduct.Color_Code := trim(iParams.get_String('color_code'));
      Check_Color(ioProduct.Color_Code);
    end if;

    if iParams.has('sim_type') then
      ioProduct.Sim_Type := trim(iParams.get_String('sim_type'));
      Check_Sim_Type(ioProduct.Sim_Type);
    end if;

    if iParams.has('market_code') then
      ioProduct.Market_Code := trim(iParams.get_String('market_code'));
      Check_Market_Code(ioProduct.Market_Code);
    end if;

    if iParams.has('replaced_parts') then
      ioProduct.Replaced_Parts := lower(replace(trim(iParams.get_String('replaced_parts')), ' ', ''));
      Check_Replaced_Parts(ioProduct.Replaced_Parts);
    end if;

    -- --- narxlar: SOMDA keladi, TIYINDA saqlanadi ---
    if iParams.has('retail_price_uzs') then
      vPrice := round(iParams.get_Number('retail_price_uzs'), 2) * 100;

      if vPrice is not null and vPrice <= 0 then
        Ipt_Methods.Raise_Error('"retail_price_uzs" 0 dan katta bo''lishi kerak.');
      end if;

      ioProduct.Retail_Price_Uzs := vPrice;
    end if;

    if iParams.has('old_price_uzs') then
      vPrice := round(iParams.get_Number('old_price_uzs'), 2) * 100;

      if vPrice is not null and vPrice <= 0 then
        Ipt_Methods.Raise_Error('"old_price_uzs" 0 dan katta bo''lishi kerak.');
      end if;

      ioProduct.Old_Price_Uzs := vPrice;
    end if;

    -- --- o'zaro bog'liq tekshiruvlar ---
    if ioProduct.Battery_Health_Pct is not null
       and (ioProduct.Battery_Health_Pct < 1 or ioProduct.Battery_Health_Pct > 100) then
      Ipt_Methods.Raise_Error('"battery_health_pct" 1 va 100 oralig''ida bo''lishi kerak.');
    end if;

    if ioProduct.Old_Price_Uzs is not null
       and ioProduct.Retail_Price_Uzs is not null
       and ioProduct.Old_Price_Uzs <= ioProduct.Retail_Price_Uzs then
      Ipt_Methods.Raise_Error('"old_price_uzs" joriy narxdan katta bo''lishi kerak — '||
                              'aks holda chizib tashlangan narx chegirma emas, qimmatlashish bo''lib ko''rinadi.');
    end if;
  end;

  --Cr By: Arslonbek Kulmatov
  --Bir nechta tovarga bir xil katalog maydonlarini qo'yish.
  --
  --Product_Action bitta mahsulot uchun, bu esa ommaviy hol uchun: bitta
  --model bo'yicha o'nlab qator bir xil model_code va kategoriya oladi.
  --Ikkalasi ham Apply_Catalog_Fields dan o'tadi, ya'ni qoidalar bir xil.
  Procedure Save_Product(iParams clob, oResponse out clob)
  is
    vParams       json_object_t := Get_Params(iParams);
    vResponse     json_object_t := json_object_t();
    vIds          json_array_t;
    vProduct      ipt_products%rowtype;
    vSession_User number := core_session.Get_User_Id;
    vId           number;
    vUpdated      pls_integer := 0;
  begin
    Ipt_Methods.Check_For_Seller;

    if not vParams.has('ids') then
      Ipt_Methods.Raise_Error('"ids" ko''rsatilmagan.');
    end if;

    vIds := vParams.get_Array('ids');

    if vIds.get_size = 0 then
      Ipt_Methods.Raise_Error('"ids" bo''sh bo''lishi mumkin emas.');
    end if;

    if not Has_Any_Catalog_Field(vParams) then
      Ipt_Methods.Raise_Error('Yangilash uchun birorta ham maydon berilmagan.');
    end if;

    for i in 0 .. vIds.get_size - 1
    loop
      vId := vIds.get_Number(i);

      begin
        select t.* into vProduct
          from ipt_products t
         where t.id = vId;
      exception
        when no_data_found then
          Ipt_Methods.Raise_Error('Bunday tovar yo''q: '||vId);
      end;

      Apply_Catalog_Fields(vParams, vProduct);

      vProduct.Up_By := vSession_User;
      vProduct.Up_On := sysdate;

      update ipt_products t
         set row = vProduct
       where t.id = vId;

      vUpdated := vUpdated + sql%rowcount;

      Ipt_Methods_Dml.Product_His(p_Product_Id => vId, p_Action => 'U');
    end loop;

    vResponse.put('oper', true);
    vResponse.put('updated', vUpdated);
    vResponse.put('message', vUpdated||' ta tovar yangilandi.');

    oResponse := vResponse.to_clob();
  end;

  -- ===========================================================================
  -- Model darajasidagi ma'lumot
  -- ===========================================================================

  --Cr By: Arslonbek Kulmatov
  --Faqat bitta rasm asosiy bo'lishi uchun qolganlarini tushirish
  Procedure Reset_Primary(iModel_Code varchar2, iColor_Code varchar2, iKeep_Id number)
  is
  begin
    update ipt_model_images t
       set t.is_primary = 0
     where t.model_code = iModel_Code
       and nvl(t.color_code, '~') = nvl(iColor_Code, '~')
       and t.id <> iKeep_Id
       and t.is_primary = 1;
  end;

  --Cr By: Arslonbek Kulmatov
  --Rasmni SERVERGA yuklash.
  --
  --Core_App.Set_Method_File orqali keladi. U fayl nomi, kengaytmasi va
  --papkasini so'rovning ILDIZIGA qo'shadi (params ichiga emas) — mavjud
  --Insert_Client_Guars ham shunday ishlaydi.
  --
  --Faylning o'zini Java diskka yozadi: biz faqat nomni qaytaramiz va
  --core_methods.file_upload_type dagi SERVER_INSERT shuni ishga soladi.
  --
  --Har yuklashda fayl nomi YANGI bo'ladi. Sayt hujjatida aytilganidek,
  --eski nomga yangi rasm qo'yilsa brauzer va optimizator uzoq vaqt eskisini
  --ko'rsatib turadi.
  Procedure Upload_Image(iParams varchar2, iFile blob default null, oResponse out clob)
  is
    vJson         json_object_t := json_object_t.parse(iParams);
    vParams       json_object_t := Get_Params(iParams);
    vResponse     json_object_t := json_object_t();
    vSession_User number := core_session.Get_User_Id;
    vModel_Code   varchar2(200);
    vColor        varchar2(30);
    vExt          varchar2(20);
    vFile_Name    varchar2(500);
    vId           number;
    vIs_Primary   number;
  begin
    Ipt_Methods.Check_For_Seller;

    if iFile is null then
      Ipt_Methods.Raise_Error('Fayl yuborilmagan.');
    end if;

    vModel_Code := lower(trim(vParams.get_String('model_code')));

    if vModel_Code is null then
      Ipt_Methods.Raise_Error('"model_code" ko''rsatilmagan.');
    end if;

    vColor := trim(vParams.get_String('color_code'));
    Check_Color(vColor);

    vExt := lower(trim(vJson.get_String('fileExtension')));

    if vExt not in ('jpg', 'jpeg', 'png', 'webp') then
      Ipt_Methods.Raise_Error('Rasm formati qo''llab-quvvatlanmaydi: '||vExt||
                              '. Mumkin: jpg, jpeg, png, webp.');
    end if;

    if dbms_lob.getlength(iFile) > 10485760 then
      Ipt_Methods.Raise_Error('Rasm hajmi 10 MB dan oshmasligi kerak.');
    end if;

    vId         := ipt_model_images_seq.nextval;
    vIs_Primary := nvl(Json_Bool(vParams, 'is_primary'), 0);

    -- Nom takrorlanmasligi uchun id va vaqt qo'shiladi.
    -- model_code 200 belgigacha bo'lishi mumkin, fayl tizimi esa 255 da
    -- to'xtaydi — shuning uchun qisqartiriladi. Unikallikni id ta'minlaydi.
    vFile_Name := 'ipt_'||substr(vModel_Code, 1, 60)||'_'||vId||'_'||
                  to_char(sysdate, 'yyyymmddhh24miss')||'.'||vExt;

    insert into ipt_model_images(id, model_code, color_code, url, file_name,
                                 is_primary, ord, cr_by, cr_on)
    values (vId, vModel_Code, vColor, null, vFile_Name,
            vIs_Primary,
            nvl(vParams.get_Number('ord'), vId),
            vSession_User, sysdate);

    if vIs_Primary = 1 then
      Reset_Primary(vModel_Code, vColor, vId);
    end if;

    vResponse.put('oper', true);
    vResponse.put('id', vId);
    -- Java shu nom bo'yicha faylni diskka yozadi
    vResponse.put('file_name', vFile_Name);
    vResponse.put('url', Core_Util.Get_Properties('catalog_file_url')||vFile_Name);
    vResponse.put('message', 'Rasm yuklandi.');

    oResponse := vResponse.to_clob();
  end;

  --Cr By: Arslonbek Kulmatov
  --Tashqi havolali rasm qo'shish yoki mavjud rasmni o'zgartirish.
  --"id" berilsa tahrir, berilmasa yangi yozuv.
  Procedure Save_Image(iParams clob, oResponse out clob)
  is
    vParams       json_object_t := Get_Params(iParams);
    vResponse     json_object_t := json_object_t();
    vSession_User number := core_session.Get_User_Id;
    vImage        ipt_model_images%rowtype;
    vId           number;
    vIs_New       boolean;
  begin
    Ipt_Methods.Check_For_Seller;

    vId    := vParams.get_Number('id');
    vIs_New := vId is null;

    if vIs_New then
      vImage.Id         := ipt_model_images_seq.nextval;
      vImage.Model_Code := lower(trim(vParams.get_String('model_code')));
      vImage.Cr_By      := vSession_User;
      vImage.Cr_On      := sysdate;
      vImage.Ord        := nvl(vParams.get_Number('ord'), vImage.Id);
      vImage.Is_Primary := 0;

      if vImage.Model_Code is null then
        Ipt_Methods.Raise_Error('"model_code" ko''rsatilmagan.');
      end if;
    else
      begin
        select t.* into vImage from ipt_model_images t where t.id = vId;
      exception
        when no_data_found then
          Ipt_Methods.Raise_Error('Bunday rasm yo''q: '||vId);
      end;

      vImage.Up_By := vSession_User;
      vImage.Up_On := sysdate;
      Read_Num(vParams, 'ord', vImage.Ord);
    end if;

    if vParams.has('color_code') then
      vImage.Color_Code := trim(vParams.get_String('color_code'));
      Check_Color(vImage.Color_Code);
    end if;

    if vParams.has('url') then
      vImage.Url := trim(vParams.get_String('url'));

      if vImage.Url is not null then
        -- Sayt havolalar avtorizatsiyasiz va https orqali ochilishini so'ragan
        if not regexp_like(vImage.Url, '^https://', 'i') then
          Ipt_Methods.Raise_Error('Rasm havolasi https:// bilan boshlanishi kerak: '||vImage.Url);
        end if;

        -- Tashqi havola qo'yilsa serverdagi fayl bog'lanishi uziladi
        vImage.File_Name := null;
      end if;
    end if;

    if vImage.Url is null and vImage.File_Name is null then
      Ipt_Methods.Raise_Error('Rasm havolasi ham, serverdagi fayli ham yo''q.');
    end if;

    if vParams.has('is_primary') then
      vImage.Is_Primary := nvl(Json_Bool(vParams, 'is_primary'), 0);
    end if;

    if vIs_New then
      insert into ipt_model_images values vImage;
    else
      update ipt_model_images t set row = vImage where t.id = vImage.Id;
    end if;

    if vImage.Is_Primary = 1 then
      Reset_Primary(vImage.Model_Code, vImage.Color_Code, vImage.Id);
    end if;

    vResponse.put('oper', true);
    vResponse.put('id', vImage.Id);
    vResponse.put('message', case when vIs_New then 'Rasm qo''shildi.' else 'Rasm yangilandi.' end);

    oResponse := vResponse.to_clob();
  end;

  --Cr By: Arslonbek Kulmatov
  --Rasm yozuvini o'chirish.
  --
  --Serverdagi faylning O'ZI o'chirilmaydi: bazadan yozuv ketgach fayl
  --hech qayerdan chaqirilmaydi, lekin uni o'chirish uchun Java tomonidan
  --alohida chaqiruv kerak bo'lardi. Yetim fayllar sekin to'planadi —
  --kerak bo'lsa keyin tozalash jobi qilinadi.
  Procedure Delete_Image(iParams clob, oResponse out clob)
  is
    vParams    json_object_t := Get_Params(iParams);
    vResponse  json_object_t := json_object_t();
    vId        number;
    vFile_Name varchar2(500);
  begin
    Ipt_Methods.Check_For_Seller;

    vId := vParams.get_Number('id');

    if vId is null then
      Ipt_Methods.Raise_Error('"id" ko''rsatilmagan.');
    end if;

    begin
      select t.file_name into vFile_Name
        from ipt_model_images t
       where t.id = vId;
    exception
      when no_data_found then
        Ipt_Methods.Raise_Error('Bunday rasm yo''q: '||vId);
    end;

    delete from ipt_model_images t where t.id = vId;

    vResponse.put('oper', true);
    Put_Str(vResponse, 'file_name', vFile_Name);
    vResponse.put('message', 'Rasm o''chirildi.');

    oResponse := vResponse.to_clob();
  end;

  --Cr By: Arslonbek Kulmatov
  --Model xarakteristikalari. Rasmlar kabi — BARCHASI almashtiriladi.
  --
  --Ko'p qiymatli xarakteristika (acc_compat) massiv bo'lib keladi va
  --bir necha qator bo'lib yotadi. Bitta qiymatlisi oddiy qiymat bo'lib keladi.
  Procedure Save_Model_Attributes(iParams clob, oResponse out clob)
  is
    vParams       json_object_t := Get_Params(iParams);
    vResponse     json_object_t := json_object_t();
    vAttrs        json_object_t;
    vKeys         json_key_list;
    vValues       json_array_t;
    vModel_Code   varchar2(200);
    vAttr_Code    varchar2(40);
    vSession_User number := core_session.Get_User_Id;
    vCount        pls_integer;
    vIs_Multi     number;
    vSaved        pls_integer := 0;

    Procedure Insert_Value(iAttr_Code varchar2, iValue varchar2, iOrd number)
    is
    begin
      if trim(iValue) is null then
        return;
      end if;

      insert into ipt_model_attributes(id, model_code, attr_code, attr_value, ord, cr_by, cr_on)
      values (ipt_model_attributes_seq.nextval,
              vModel_Code, iAttr_Code, trim(iValue), iOrd, vSession_User, sysdate);

      vSaved := vSaved + 1;
    end;
  begin
    Ipt_Methods.Check_For_Seller;

    vModel_Code := lower(trim(vParams.get_String('model_code')));

    if vModel_Code is null then
      Ipt_Methods.Raise_Error('"model_code" ko''rsatilmagan.');
    end if;

    if not vParams.has('attributes') then
      Ipt_Methods.Raise_Error('"attributes" ko''rsatilmagan. Barchasini o''chirish uchun bo''sh obyekt yuboring.');
    end if;

    vAttrs := vParams.get_Object('attributes');
    vKeys  := vAttrs.get_keys;

    delete from ipt_model_attributes t where t.model_code = vModel_Code;

    for k in 1 .. vKeys.count
    loop
      vAttr_Code := vKeys(k);

      begin
        select t.is_multi into vIs_Multi
          from ipt_s_attributes t
         where t.code = vAttr_Code
           and t.condition = 'A';
      exception
        when no_data_found then
          Ipt_Methods.Raise_Error('Bunday xarakteristika yo''q yoki faol emas: '||vAttr_Code||
                                  '. Mumkin qiymatlar ipt_s_attributes_v da.');
      end;

      if vAttrs.get(vAttr_Code).is_Array then
        if vIs_Multi = 0 then
          Ipt_Methods.Raise_Error('"'||vAttr_Code||'" bitta qiymatli xarakteristika, massiv kutilmaydi.');
        end if;

        vValues := vAttrs.get_Array(vAttr_Code);

        for i in 0 .. vValues.get_size - 1
        loop
          Insert_Value(vAttr_Code, Json_Scalar(vValues, i), i + 1);
        end loop;
      else
        Insert_Value(vAttr_Code, Json_Scalar(vAttrs, vAttr_Code), 1);
      end if;
    end loop;

    vResponse.put('oper', true);
    vResponse.put('saved', vSaved);
    vResponse.put('message', vSaved||' ta xarakteristika saqlandi.');

    oResponse := vResponse.to_clob();
  end;

  -- ===========================================================================
  -- Sayt uchun o'qish
  -- ===========================================================================

  --Cr By: Arslonbek Kulmatov
  --Model rasmlari massivi
  --
  --Serverdagi rasm uchun to'liq havola core_properties.catalog_file_url
  --prefiksi bilan yig'iladi — ipt_client_guars_v dagi dbo_url naqshi kabi.
  Function Build_Images(iModel_Code varchar2) return json_array_t
  is
    vImages json_array_t := json_array_t();
    vImage  json_object_t;
    vBase   varchar2(500) := Core_Util.Get_Properties('catalog_file_url');
    vUrl    varchar2(1500);
  begin
    for rows in (select t.url, t.file_name, t.color_code, t.is_primary
                   from ipt_model_images t
                  where t.model_code = iModel_Code
                  order by t.ord, t.id)
    loop
      vUrl := nvl(rows.url, vBase||rows.file_name);

      -- Prefiks sozlanmagan bo'lsa yarim havola chiqmasin
      if vUrl is not null and regexp_like(vUrl, '^https?://', 'i') then
        vImage := json_object_t();
        vImage.put('url', vUrl);
        Put_Str(vImage, 'color', rows.color_code);
        vImage.put('is_primary', rows.is_primary = 1);
        vImages.append(vImage);
      end if;
    end loop;

    return vImages;
  end;

  --Cr By: Arslonbek Kulmatov
  --Model xarakteristikalari obyekti.
  --
  --Ko'p qiymatlisi massiv, bittalisi oddiy qiymat bo'lib chiqadi —
  --sayt aynan shunday kutadi. Tur ipt_s_attributes.value_type dan olinadi.
  Function Build_Attributes(iModel_Code varchar2) return json_object_t
  is
    vAttrs     json_object_t := json_object_t();
    vArr       json_array_t;
    vPrev_Code varchar2(40);
    vPrev_Multi number;
    vNum       number;

    --Qiymatni turi bo'yicha massivga qo'shish
    Procedure Append_Typed(iType varchar2, iValue varchar2)
    is
    begin
      if iType = 'number' then
        vNum := To_Num_Safe(iValue);
        if vNum is not null then
          vArr.append(vNum);
        end if;
      elsif iType = 'bool' then
        vArr.append(lower(iValue) in ('true', '1', 'y'));
      else
        vArr.append(iValue);
      end if;
    end;

    --Qiymatni turi bo'yicha obyektga qo'yish
    Procedure Put_Typed(iKey varchar2, iType varchar2, iValue varchar2)
    is
    begin
      if iType = 'number' then
        vNum := To_Num_Safe(iValue);
        if vNum is not null then
          vAttrs.put(iKey, vNum);
        end if;
      elsif iType = 'bool' then
        vAttrs.put(iKey, lower(iValue) in ('true', '1', 'y'));
      else
        vAttrs.put(iKey, iValue);
      end if;
    end;
  begin
    for rows in (select a.attr_code, a.attr_value, s.value_type, s.is_multi
                   from ipt_model_attributes a,
                        ipt_s_attributes s
                  where s.code = a.attr_code
                    and a.model_code = iModel_Code
                    and s.condition = 'A'
                  order by a.attr_code, a.ord, a.id)
    loop
      -- Yangi xarakteristika boshlandi: oldingisini yakunlaymiz
      if vPrev_Code is null or rows.attr_code <> vPrev_Code then
        if vPrev_Code is not null and vPrev_Multi = 1 then
          vAttrs.put(vPrev_Code, vArr);
        end if;

        vPrev_Code  := rows.attr_code;
        vPrev_Multi := rows.is_multi;
        vArr        := json_array_t();
      end if;

      if rows.is_multi = 1 then
        Append_Typed(rows.value_type, rows.attr_value);
      else
        Put_Typed(rows.attr_code, rows.value_type, rows.attr_value);
      end if;
    end loop;

    -- Oxirgi xarakteristikani yakunlash
    if vPrev_Code is not null and vPrev_Multi = 1 then
      vAttrs.put(vPrev_Code, vArr);
    end if;

    return vAttrs;
  end;

  --Cr By: Arslonbek Kulmatov
  --"screen,back_cover" -> ["screen","back_cover"]
  Function Build_Replaced_Parts(iValue varchar2) return json_array_t
  is
  begin
    return Split_Csv(iValue);
  end;

  --Cr By: Arslonbek Kulmatov
  --Bitta katalog pozitsiyasi
  Function Build_Item(iRow in ipt_catalog_v%rowtype, iSites json_array_t) return json_object_t
  is
    vItem  json_object_t := json_object_t();
    vColor json_object_t;
  begin
    -- Id endi matn: yangi tovarda konfiguratsiyadan yasalgan kalit,
    -- ishlatilganda ombor qatorining raqami. to_char kerak emas.
    vItem.put('id', iRow.Id);
    vItem.put('model_code', iRow.Model_Code);
    vItem.put('model_name', iRow.Model_Name);
    Put_Str(vItem, 'model_name_uz', iRow.Model_Name_Uz);
    vItem.put('category', iRow.Category);
    Put_Str(vItem, 'brand', iRow.Brand);
    vItem.put('condition', iRow.Condition);
    vItem.put('price', round(iRow.Price));
    Put_Num(vItem, 'old_price', round(iRow.Old_Price));
    vItem.put('quantity', Build_Quantity(iSites, iRow.Quantity_Json));
    -- Umumiy qoldiq: sayt shourumlar bo'yicha taqsimotni hozircha
    -- yoqmasligini aytdi va umumiy sonni ko'rsatadi
    vItem.put('quantity_total', nvl(iRow.Quantity_Total, 0));
    Put_Str(vItem, 'sku', iRow.Sku);
    Put_Num(vItem, 'storage_gb', iRow.Storage_Gb);
    Put_Num(vItem, 'ram_gb', iRow.Ram_Gb);

    if iRow.Color_Code is not null then
      vColor := json_object_t();
      vColor.put('code', iRow.Color_Code);
      Put_Str(vColor, 'name_ru', iRow.Color_Name_Ru);
      Put_Str(vColor, 'name_uz', iRow.Color_Name_Uz);
      vItem.put('color', vColor);
    end if;

    Put_Num(vItem, 'warranty_months', iRow.Warranty_Months);
    Put_Str(vItem, 'description_ru', iRow.Description_Ru);
    Put_Str(vItem, 'description_uz', iRow.Description_Uz);

    -- Ishlatilgan texnika maydonlari yangi tovarda umuman chiqmaydi
    if iRow.Condition = 'used' then
      Put_Num(vItem, 'battery_health_pct', iRow.Battery_Health_Pct);
      Put_Str(vItem, 'imei', iRow.Imei);
      Put_Str(vItem, 'serial', iRow.Serial);
      Put_Str(vItem, 'sim_type', iRow.Sim_Type);
      Put_Str(vItem, 'market_code', iRow.Market_Code);
      Put_Bool(vItem, 'has_box', iRow.Has_Box);
      Put_Bool(vItem, 'has_charger', iRow.Has_Charger);

      if iRow.Replaced_Parts is not null then
        vItem.put('replaced_parts', Build_Replaced_Parts(iRow.Replaced_Parts));
      end if;
    end if;

    vItem.put('images', Build_Images(iRow.Model_Code));
    vItem.put('attributes', Build_Attributes(iRow.Model_Code));
    vItem.put('is_active', true);
    vItem.put('updated_at', To_Iso(iRow.Updated_At));

    return vItem;
  end;

  --Cr By: Arslonbek Kulmatov
  --To'liq katalog, sahifalab
  Procedure Get_Products(iParams clob, oResponse out clob)
  is
    vParams   json_object_t := Get_Params(iParams);
    vResponse json_object_t := json_object_t();
    vItems    json_array_t  := json_array_t();
    vSites    json_array_t  := Get_Site_Codes;
    vRow      ipt_catalog_v%rowtype;
    vPage     number;
    vPerPage  number;
    vSince    date;
    vTotal    number;
    vOffset   number;

    -- Aniq kursor: kursor FOR sikli o'z yozuv turini yaratadi va uni
    -- ipt_catalog_v%rowtype ga o'zlashtirib bo'lmaydi (PLS-00382).
    -- FETCH INTO esa pozitsiya bo'yicha ishlaydi va muammo chiqmaydi.
    cursor cCatalog(pSince date, pOffset number, pLimit number) is
      select *
        from ipt_catalog_v t
       where pSince is null
          or t.updated_at > pSince
       order by t.id
      offset pOffset rows fetch next pLimit rows only;
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
    open cCatalog(vSince, vOffset, vPerPage);
    loop
      fetch cCatalog into vRow;
      exit when cCatalog%notfound;

      vItems.append(Build_Item(vRow, vSites));
    end loop;
    close cCatalog;

    vResponse.put('total', vTotal);
    vResponse.put('page', vPage);
    vResponse.put('per_page', vPerPage);
    vResponse.put('items', vItems);

    -- To_String EMAS: u varchar2 qaytaradi va 32 KB da uziladi.
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
                        t.quantity_json,
                        t.quantity_total
                   from ipt_catalog_v t
                  order by t.id)
    loop
      vItem := json_object_t();
      vItem.put('id', rows.id);
      vItem.put('price', round(rows.price));
      vItem.put('quantity', Build_Quantity(vSites, rows.quantity_json));
      vItem.put('quantity_total', nvl(rows.quantity_total, 0));
      vItems.append(vItem);
    end loop;

    vResponse.put('updated_at', To_Iso(sysdate));
    vResponse.put('items', vItems);

    oResponse := vResponse.to_clob();
  end;

end Ipt_Catalog;
/


-- =============================================================================
-- METODLARNI RO'YXATGA OLISH
--
-- seq kerak: bitta MERGE ichida max(id) hamma qator uchun bir xil o'qiladi,
-- shuning uchun "+1" yangi metodlarga bir xil id berib, PK ni buzardi.
--
-- O'qish metodlarida add_log = 'N': katalog soatiga bir marta, qoldiq esa
-- 5 daqiqada bir marta so'raladi, loglasak core_api_log to'lib ketadi.
-- Saqlash metodlari kam chaqiriladi va ma'lumotni o'zgartiradi — loglanadi.
-- =============================================================================

prompt core_methods

merge into core_methods t
using (
  select 'catalogProducts' method, 'Ipt_Catalog.Get_Products' proc_name, 'N' add_log,
         'Sayt katalogi: to''liq ro''yxat, sahifalab' details, 1 seq from dual
  union all
  select 'catalogStock', 'Ipt_Catalog.Get_Stock', 'N',
         'Sayt katalogi: narx va qoldiq', 2 from dual
  union all
  select 'catalogSaveProduct', 'Ipt_Catalog.Save_Product', 'Y',
         'Katalog maydonlarini ommaviy to''ldirish', 3 from dual
  union all
  select 'catalogSaveAttributes', 'Ipt_Catalog.Save_Model_Attributes', 'Y',
         'Model xarakteristikalari (barchasi almashtiriladi)', 4 from dual
  union all
  select 'catalogSaveImage', 'Ipt_Catalog.Save_Image', 'Y',
         'Tashqi havolali rasm qo''shish yoki tahrirlash', 5 from dual
  union all
  select 'catalogDeleteImage', 'Ipt_Catalog.Delete_Image', 'Y',
         'Rasmni o''chirish', 6 from dual
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
-- RASM YUKLASH METODI
--
-- Alohida, chunki unga file_upload_type kerak: Core_App.Set_Method_File
-- protsedurani (iParams, iFile, oAdditional) bilan chaqiradi va Java
-- javobdagi "file_name" ni olib faylni "root" papkasiga yozadi.
--
-- root papkasi SERVERDA OLDINDAN YARATILGAN bo'lishi shart — Files.copy uni
-- o'zi yaratmaydi va yuklash "Could not store the file" bilan tugaydi:
--   mkdir -p /opt/monello71/files/catalog
--
-- Chaqiruv: POST /api/app/requestFile (multipart: params + file)
-- =============================================================================

prompt catalogUploadImage

merge into core_methods t
using (
  select 'catalogUploadImage' method,
         'Ipt_Catalog.Upload_Image' proc_name,
         'Katalog rasmini serverga yuklash' details,
         '{"type":"SERVER_INSERT","root":"/opt/monello71/files/catalog"}' file_upload_type
    from dual
) s
on (lower(t.method) = lower(s.method))
when matched then
  update set t.proc_name        = s.proc_name,
             t.details          = s.details,
             t.file_upload_type = s.file_upload_type,
             t.add_log          = 'Y',
             t.state            = 'A'
when not matched then
  insert (id, method, proc_name, state, has_out_param, is_func, add_log, details, file_upload_type, cr_on)
  values ((select nvl(max(m.id), 0) + 1 from core_methods m),
          s.method, s.proc_name, 'A', 'Y', 'N', 'Y', s.details, s.file_upload_type, sysdate);

commit;
