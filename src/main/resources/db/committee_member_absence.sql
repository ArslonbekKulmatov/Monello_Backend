-- ===========================================================================
-- Qo'mita a'zolarining hozirgi ishtirok holati (Absence Reasons)
--
-- Author  : Arslonbek Kulmatov
-- Purpose : Rais/a'zo xizmat safarida yoki ta'tilda bo'lsa, uni ro'yxatdan
--           tushurmasdan (Faol qoldirib), ovoz berish varaqasida "Rози" /
--           "Норози" o'rniga aynan sabab (Хизмат сафарида, Таътилда, va h.k.)
--           ko'rinadigan qilish.
--
-- Ish oqimi:
--   1) A'zo hozirgi holatini tanlaydi (yoki admin tanlab qo'yadi):
--      spravochnikdan reason + sana + izoh.
--   2) get_votes:
--      - reason = PARTICIPATES → oldingi kabi "Кутилмоқда"/"Рози"/"Норози"
--      - boshqa reason → aynan sabab nomi (Хизмат сафарида) va ovoz qabul
--        qilinmaydi (kutilmaydi).
--   3) reason_to o'tsa avtomatik PARTICIPATES ga qaytadi (view/scheduler).
-- ===========================================================================


-- ----- 1) Sabablar spravochnigi ------------------------------------------
Create Table Pi_S_Committee_Absence_Reasons (
  code       Varchar2(32)  Not Null,
  name_uz    Varchar2(128) Not Null,
  name_ru    Varchar2(128) Not Null,
  color      Varchar2(16),                 -- 'success' / 'warning' / 'danger' / 'info' / 'muted'
  order_by   Number(3),
  is_active  Char(1)       Default 'Y',
  is_default Char(1)       Default 'N',    -- Y — bu default holat (PARTICIPATES uchun)
  Constraint Pk_Pi_S_Com_Absence_Reasons Primary Key (code)
);

Insert Into Pi_S_Committee_Absence_Reasons Values
  ('PARTICIPATES',  'Иштирок этади',       'Участвует',            'success', 1, 'Y', 'Y');
Insert Into Pi_S_Committee_Absence_Reasons Values
  ('BUSINESS_TRIP', 'Хизмат сафарида',     'В командировке',       'info',    2, 'Y', 'N');
Insert Into Pi_S_Committee_Absence_Reasons Values
  ('VACATION',      'Таътилда',            'В отпуске',            'warning', 3, 'Y', 'N');
Insert Into Pi_S_Committee_Absence_Reasons Values
  ('SICK_LEAVE',    'Касаллик варақасида', 'На больничном',        'danger',  4, 'Y', 'N');
Insert Into Pi_S_Committee_Absence_Reasons Values
  ('OTHER',         'Бошқа',               'Другое',               'muted',   5, 'Y', 'N');
Commit;


-- ----- 1a) Spravochnikni execSelect orqali o'qish uchun view -----------
-- Frontend dropdown ni to'ldirish uchun:
--   POST /api/app/execSelect { "view": "pi_s_committee_absence_reasons_v" }
Create Or Replace View Pi_S_Committee_Absence_Reasons_V As
Select t.code,
       t.name_uz,
       t.name_ru,
       t.color,
       t.order_by,
       t.is_active,
       t.is_default
  From Pi_S_Committee_Absence_Reasons t
 Order By t.order_by;


-- ----- 2) A'zolar jadvaliga hozirgi holat maydonlari qo'shildi ------------
Alter Table Pi_S_Committee_Members Add (
  current_reason Varchar2(32) Default 'PARTICIPATES',
  reason_from    Date,
  reason_to      Date,
  reason_note    Varchar2(512),
  reason_set_by  Number(10),
  reason_set_on  Date
);

Alter Table Pi_S_Committee_Members
  Add Constraint Fk_Pi_S_Com_Mem_Reason
  Foreign Key (current_reason)
  References Pi_S_Committee_Absence_Reasons(code);


-- ----- 3) Hozirgi holatni "effektiv" qilib qaytaruvchi view --------------
-- Agar reason_to bugundan oldin bo'lsa yoki reason PARTICIPATES bo'lsa, a'zo
-- ovoz beruvchi hisoblanadi.
Create Or Replace View Pi_S_Committee_Members_Now_V As
Select
  m.user_id,
  m.name,
  m.position,
  m.order_by,
  m.added_on,
  m.expired_on,
  Case
    When m.reason_to Is Not Null And m.reason_to < Trunc(Sysdate) Then 'PARTICIPATES'
    Else Nvl(m.current_reason, 'PARTICIPATES')
  End                             As effective_reason,
  m.reason_from,
  m.reason_to,
  m.reason_note,
  Case
    When Trunc(Sysdate) Between Nvl(m.added_on, Trunc(Sysdate))
                            And Nvl(m.expired_on, Trunc(Sysdate)) Then 'A'
    Else 'P'
  End                             As is_active
From Pi_S_Committee_Members m;


-- ===========================================================================
-- PACKAGE SPEC — ADD (inside PI_COMMITTEE spec)
-- ===========================================================================
--
--   -- Sabablar spravochnigi ro'yxatini olish (dropdown uchun)
--   Procedure get_absence_reasons(p_Request Clob, o_Response Out Clob);
--
--   -- Qo'mita a'zosining hozirgi holatini o'zgartirish
--   Procedure set_member_reason (p_Request Clob, o_Response Out Clob);


-- ===========================================================================
-- PACKAGE BODY — ADD (inside PI_COMMITTEE body)
-- ===========================================================================

  Procedure get_absence_reasons(p_Request Clob, o_Response Out Clob)
  Is
    v_Resp Json_Object_t := Json_Object_t();
    v_Arr  Json_Array_t  := Json_Array_t();
    v_Row  Json_Object_t;
  Begin
    For r In (Select code, name_uz, name_ru, color, is_default
                From Pi_S_Committee_Absence_Reasons
               Where is_active = 'Y'
               Order By order_by) Loop
      v_Row := Json_Object_t();
      v_Row.Put('code',       r.code);
      v_Row.Put('name_uz',    r.name_uz);
      v_Row.Put('name_ru',    r.name_ru);
      v_Row.Put('color',      r.color);
      v_Row.Put('is_default', r.is_default);
      v_Arr.Append(v_Row);
    End Loop;

    v_Resp.Put('reasons', v_Arr);
    o_Response := v_Resp.To_Clob();
  End get_absence_reasons;


  Procedure set_member_reason(p_Request Clob, o_Response Out Clob)
  Is
    v_Json    Json_Object_t := Json_Object_t.Parse(p_Request);
    v_Params  Json_Object_t := v_Json.get_Object('params');
    v_Resp    Json_Object_t := Json_Object_t();
    v_User_Id Number(20)    := core_session.get_user_id();
    v_Target  Number(20);
    v_Reason  Varchar2(32);
    v_From    Date;
    v_To      Date;
    v_Note    Varchar2(512);
    v_Count   Number(5);
    v_Row     Pi_S_Committee_Members%Rowtype;
    v_ReasonName Varchar2(128);
  Begin
    -- Ruxsat: admin (role_id = 6) yoki foydalanuvchi o'zi
    v_Target := v_Params.get_Number('user_id');

    If v_Target <> v_User_Id Then
      Select Count(*) Into v_Count
        From core_user_roles t
       Where t.role_id = 6 And t.user_id = v_User_Id;
      If v_Count = 0 Then
        Pi_Util.Raise_Error('Faqat o''zingiz uchun holat belgilay olasiz yoki admin bo''lishingiz kerak');
      End If;
    End If;

    -- A'zoni tekshirish
    Select Count(*) Into v_Count
      From Pi_S_Committee_Members m
     Where m.user_id = v_Target;
    If v_Count = 0 Then
      Pi_Util.Raise_Error('Qo''mita a''zosi topilmadi: user_id = ' || v_Target);
    End If;

    -- Reason kod
    v_Reason := Upper(Nvl(v_Params.get_String('reason'), 'PARTICIPATES'));
    Select Count(*) Into v_Count
      From Pi_S_Committee_Absence_Reasons
     Where code = v_Reason And is_active = 'Y';
    If v_Count = 0 Then
      Pi_Util.Raise_Error('Noto''g''ri holat kodi: ' || v_Reason);
    End If;

    -- Sana
    If v_Params.has('from') And v_Params.get_String('from') Is Not Null Then
      Begin
        v_From := To_Date(v_Params.get_String('from'), 'dd.mm.yyyy');
      Exception When Others Then
        Pi_Util.Raise_Error('"from" formati noto''g''ri. Kerak: dd.mm.yyyy');
      End;
    End If;
    If v_Params.has('to') And v_Params.get_String('to') Is Not Null Then
      Begin
        v_To := To_Date(v_Params.get_String('to'), 'dd.mm.yyyy');
      Exception When Others Then
        Pi_Util.Raise_Error('"to" formati noto''g''ri. Kerak: dd.mm.yyyy');
      End;
    End If;

    If v_From Is Not Null And v_To Is Not Null And v_From > v_To Then
      Pi_Util.Raise_Error('"from" "to"dan katta bo''lishi mumkin emas');
    End If;

    If v_Params.has('note') Then
      v_Note := Substr(v_Params.get_String('note'), 1, 512);
    End If;

    -- PARTICIPATES bo'lsa sana/izohni tozalaymiz
    If v_Reason = 'PARTICIPATES' Then
      v_From := Null;
      v_To   := Null;
      v_Note := Null;
    End If;

    -- Update
    Update Pi_S_Committee_Members m
       Set m.current_reason = v_Reason,
           m.reason_from    = v_From,
           m.reason_to      = v_To,
           m.reason_note    = v_Note,
           m.reason_set_by  = v_User_Id,
           m.reason_set_on  = Sysdate
     Where m.user_id = v_Target;
    Commit;

    Select name_uz Into v_ReasonName
      From Pi_S_Committee_Absence_Reasons Where code = v_Reason;

    v_Resp.Put('success', True);
    v_Resp.Put('message', 'Holat yangilandi: ' || v_ReasonName);
    v_Resp.Put('reason',  v_Reason);
    o_Response := v_Resp.To_Clob();
  End set_member_reason;


-- ===========================================================================
-- get_votes PROCEDURA YANGILANISHI
--   Absence reason'ni hisobga oladi:
--   - PARTICIPATES → hozirgidek "Кутилмоқда"/"Рози"/"Норози"
--   - boshqa       → sabab nomi (masalan "Хизмат сафарида") va reason color
--
-- Original get_votes PL/SQL Developer'da bor. Uni to'liq quyidagi bilan
-- almashtiring:
-- ===========================================================================

  Procedure get_votes(p_Request Clob, o_Response Out Clob)
  Is
    v_Json     Json_Object_t := Json_Object_t.Parse(p_Request);
    v_Response Json_Object_t := Json_Object_t();
    v_Params   Json_Object_t := v_Json.get_Object('params');
    v_Data     Json_Object_t;
    v_Datas    Json_Array_t  := Json_Array_t();
    v_Id       Number(20)    := v_Params.get_Number('id');
    v_Vote     Varchar2(128);
    v_Vote_On  Varchar2(64);
    v_Comments Varchar2(2048);
    v_Reason   Varchar2(32);
    v_ReasonName Varchar2(128);
    v_Color    Varchar2(16);
    v_Note     Varchar2(512);
    v_Row      Pi_Committees_V%Rowtype;
  Begin
    For i In (Select
                m.user_id,
                m.name,
                m.position,
                Nvl(m.added_on, To_Date('01.11.2025', 'dd.mm.yyyy')) added_on,
                m.expired_on,
                Case
                  When m.reason_to Is Not Null And m.reason_to < Trunc(Sysdate) Then 'PARTICIPATES'
                  Else Nvl(m.current_reason, 'PARTICIPATES')
                End effective_reason,
                m.reason_note
              From Pi_S_Committee_Members m
              Order By m.order_by) Loop
      Begin
        Select k.* Into v_Row
          From Pi_Committees_V k
         Where k.id = v_Id;

        If To_Date(v_Row.application_date, 'dd.mm.yyyy') < i.added_on Then Continue; End If;
        If To_Date(v_Row.application_date, 'dd.mm.yyyy') > i.expired_on Then Continue; End If;
      Exception
        When Others Then Null;
      End;

      v_Reason := i.effective_reason;
      v_Note   := i.reason_note;

      -- Reason nomi va rangi
      Begin
        Select name_uz, color
          Into v_ReasonName, v_Color
          From Pi_S_Committee_Absence_Reasons
         Where code = v_Reason;
      Exception When No_Data_Found Then
        v_ReasonName := 'Иштирок этади';
        v_Color := 'success';
      End;

      If v_Reason = 'PARTICIPATES' Then
        Begin
          Select v.vote, v.comments, To_Char(v.vote_on, 'dd.mm.yyyy hh24:mi:ss')
            Into v_Vote, v_Comments, v_Vote_On
            From Pi_Committee_Member_Votes v
           Where v.user_id = i.user_id
             And v.committee_id = v_Id;
        Exception When No_Data_Found Then
          v_Vote     := 'Кутилмоқда';
          v_Vote_On  := Null;
          v_Comments := Null;
        End;
      Else
        -- Ovoz kutilmaydi — o'rniga sabab ko'rsatiladi
        v_Vote     := v_ReasonName;
        v_Vote_On  := Null;
        v_Comments := v_Note;
      End If;

      v_Data := Json_Object_t();
      v_Data.Put('committee_id',   v_Id);
      v_Data.Put('user_id',        i.user_id);
      v_Data.Put('user_name',      i.name);
      v_Data.Put('role',           i.position);
      v_Data.Put('vote',           v_Vote);
      v_Data.Put('vote_on',        v_Vote_On);
      v_Data.Put('comments',       v_Comments);
      v_Data.Put('reason',         v_Reason);
      v_Data.Put('reason_name',    v_ReasonName);
      v_Data.Put('reason_color',   v_Color);
      v_Data.Put('is_voter',       Case When v_Reason = 'PARTICIPATES' Then 'Y' Else 'N' End);
      v_Datas.Append(v_Data);
    End Loop;

    v_Response.Put('votes', v_Datas);
    o_Response := v_Response.To_Clob();
  End get_votes;


-- ===========================================================================
-- get_members_list PROCEDURA YANGILANISHI
--   Hozirgi holat (current_reason) qaytariladi. Frontend qatorlarda "Ҳозирги
--   ҳолати" ustunini rangli badge sifatida ko'rsatishi mumkin.
--
-- get_members_list'ning hozirgi implementatsiyasini shu bilan almashtiring:
-- ===========================================================================

  Procedure get_members_list(p_Request Varchar2, o_Response Out Clob)
  Is
    v_Resp    Json_Object_t := Json_Object_t();
    v_Rows    Json_Array_t  := Json_Array_t();
    v_Row     Json_Object_t;
    v_Json    Json_Object_t;
    v_Params  Json_Object_t;
    v_OnlyAct Number(1)     := 0;
  Begin
    Begin
      v_Json   := Json_Object_t.Parse(p_Request);
      v_Params := v_Json.get_Object('params');
      If v_Params.has('only_active') Then
        v_OnlyAct := v_Params.get_Number('only_active');
      End If;
    Exception When Others Then Null;
    End;

    For m In (
      Select v.user_id, v.name, v.position, v.order_by, v.added_on, v.expired_on,
             v.effective_reason, v.reason_from, v.reason_to, v.reason_note, v.is_active,
             r.name_uz As reason_name, r.color As reason_color
        From Pi_S_Committee_Members_Now_V v
             Left Join Pi_S_Committee_Absence_Reasons r
                    On r.code = v.effective_reason
       Where v_OnlyAct = 0 Or v.is_active = 'A'
       Order By v.order_by
    ) Loop
      v_Row := Json_Object_t();
      v_Row.Put('user_id',      m.user_id);
      v_Row.Put('name',         m.name);
      v_Row.Put('position',     m.position);
      v_Row.Put('order_by',     m.order_by);
      v_Row.Put('added_on',     To_Char(m.added_on,   'dd.mm.yyyy'));
      v_Row.Put('expired_on',   To_Char(m.expired_on, 'dd.mm.yyyy'));
      v_Row.Put('is_active',    m.is_active);
      v_Row.Put('reason',       m.effective_reason);
      v_Row.Put('reason_name',  m.reason_name);
      v_Row.Put('reason_color', m.reason_color);
      v_Row.Put('reason_from',  To_Char(m.reason_from, 'dd.mm.yyyy'));
      v_Row.Put('reason_to',    To_Char(m.reason_to,   'dd.mm.yyyy'));
      v_Row.Put('reason_note',  m.reason_note);
      v_Rows.Append(v_Row);
    End Loop;

    v_Resp.Put('members', v_Rows);
    o_Response := v_Resp.To_Clob();
  End get_members_list;


-- ===========================================================================
-- member_ref_action YANGILANISHI: reason maydonlarini ham qabul qilish
--
-- Frontend endi bitta so'rov bilan a'zo va uning hozirgi holatini
-- birgalikda saqlaydi. setMemberReason ixtiyoriy qoladi — a'zo o'zi
-- holatini o'zgartirishi kabi kichik holatlar uchun.
--
-- Params ichida yangi ixtiyoriy maydonlar:
--   "reason":      "PARTICIPATES" | "BUSINESS_TRIP" | "VACATION" | "SICK_LEAVE" | "OTHER"
--   "reason_from": "dd.mm.yyyy"  (agar reason != PARTICIPATES bo'lsa)
--   "reason_to":   "dd.mm.yyyy"  (agar reason != PARTICIPATES bo'lsa)
--   "reason_note": "matn"        (ixtiyoriy izoh)
--
-- Namunali chaqiruv:
--   {"method":"member_ref_action",
--    "params":{"action":"U","user_id":107,
--              "position":"Суғурта Қўмитаси аъзоси",
--              "added_on":"01.04.2026","expired_on":"06.04.2036",
--              "reason":"BUSINESS_TRIP",
--              "reason_from":"15.09.2026","reason_to":"25.09.2026",
--              "reason_note":"Toshkent, buyruq #384"}}
-- ===========================================================================

  Procedure member_ref_action(p_Request Clob, o_Response Out Clob)
  Is
    v_Json         Json_Object_t := Json_Object_t.Parse(p_Request);
    v_Response     Json_Object_t := Json_Object_t();
    v_Params       Json_Object_t := v_Json.get_Object('params');
    v_Action       Varchar2(2)   := v_Params.get_String('action');
    v_User_Id      Number(20)    := core_session.get_user_id();
    v_Row          pi_s_committee_members%rowtype;
    v_Count        Number(5);
    v_ReasonCount  Number(1);
  Begin
    -- 1. Ruxsat (admin — role_id = 6)
    Select Count(*) Into v_Count
      From core_user_roles t
     Where t.role_id = 6 And t.user_id = v_User_Id;
    If v_Count = 0 Then
      Pi_Util.Raise_Error('У вас нет доступа к этим действиям!');
    End If;

    Pi_Util.Check_For_Existance(v_Params, 'action');
    Pi_Util.Check_For_Existance(v_Params, 'user_id');
    v_Row.User_Id := v_Params.get_Number('user_id');

    If v_Action In ('I', 'U') Then
      -- 2. Foydalanuvchi mavjudligi
      Select Count(*) Into v_Count
        From core_users t Where t.user_id = v_Row.User_Id;
      If v_Count = 0 Then
        Pi_Util.Raise_Error('Пользователь не найден: user_id = ' || v_Row.User_Id);
      End If;

      -- 3. Mavjudligini tekshirish
      Select Count(*) Into v_Count
        From pi_s_committee_members t Where t.user_id = v_Row.User_Id;

      If v_Action = 'I' And v_Count > 0 Then
        Pi_Util.Raise_Error('Этот пользователь уже является членом комитета!');
      End If;
      If v_Action = 'U' And v_Count = 0 Then
        Pi_Util.Raise_Error('Член комитета не найден: user_id = ' || v_Row.User_Id);
      End If;

      -- 4. Update: eski qatorni olib history yozamiz
      If v_Action = 'U' Then
        Select t.* Into v_Row
          From pi_s_committee_members t
         Where t.user_id = v_Row.User_Id;

        Insert Into pi_s_committee_members_his
          (user_id, position, name, order_by, added_on, expired_on,
           action, action_by, action_on)
        Values
          (v_Row.User_Id, v_Row.Position, v_Row.Name, v_Row.Order_By,
           v_Row.Added_On, v_Row.Expired_On, 'U', v_User_Id, Sysdate);
      End If;

      -- 5. Asosiy maydonlar
      Pi_Util.Check_For_Existance(v_Params, 'position');
      Pi_Util.Check_For_Existance(v_Params, 'name');

      v_Row.Position := Pi_Util.Get_By_Validation(v_Params, 'position', 1, 256, false);
      v_Row.Name     := Pi_Util.Get_By_Validation(v_Params, 'name', 1, 256, false);

      If v_Params.has('order_by') Then
        v_Row.Order_By := v_Params.get_Number('order_by');
      End If;

      If v_Params.has('added_on') Then
        Begin
          v_Row.Added_On := to_date(v_Params.get_String('added_on'), 'dd.mm.yyyy');
        Exception When Others Then
          Pi_Util.Raise_Error('Неправильный формат "added_on". Нужно: dd.mm.yyyy');
        End;
      End If;

      If v_Params.has('expired_on') Then
        Begin
          v_Row.Expired_On := to_date(v_Params.get_String('expired_on'), 'dd.mm.yyyy');
        Exception When Others Then
          Pi_Util.Raise_Error('Неправильный формат "expired_on". Нужно: dd.mm.yyyy');
        End;
      End If;

      -- 6. YANGI: hozirgi holat (reason) maydonlari
      If v_Params.has('reason') And v_Params.get_String('reason') Is Not Null Then
        v_Row.Current_Reason := Upper(v_Params.get_String('reason'));

        Select Count(*) Into v_ReasonCount
          From Pi_S_Committee_Absence_Reasons
         Where code = v_Row.Current_Reason And is_active = 'Y';
        If v_ReasonCount = 0 Then
          Pi_Util.Raise_Error('Noto''g''ri holat kodi: ' || v_Row.Current_Reason);
        End If;

        If v_Row.Current_Reason = 'PARTICIPATES' Then
          v_Row.Reason_From := Null;
          v_Row.Reason_To   := Null;
          v_Row.Reason_Note := Null;
        Else
          If v_Params.has('reason_from') And v_Params.get_String('reason_from') Is Not Null Then
            Begin
              v_Row.Reason_From := to_date(v_Params.get_String('reason_from'), 'dd.mm.yyyy');
            Exception When Others Then
              Pi_Util.Raise_Error('"reason_from" formati noto''g''ri. Kerak: dd.mm.yyyy');
            End;
          End If;
          If v_Params.has('reason_to') And v_Params.get_String('reason_to') Is Not Null Then
            Begin
              v_Row.Reason_To := to_date(v_Params.get_String('reason_to'), 'dd.mm.yyyy');
            Exception When Others Then
              Pi_Util.Raise_Error('"reason_to" formati noto''g''ri. Kerak: dd.mm.yyyy');
            End;
          End If;
          If v_Params.has('reason_note') Then
            v_Row.Reason_Note := Substr(v_Params.get_String('reason_note'), 1, 512);
          End If;

          If v_Row.Reason_From Is Not Null And v_Row.Reason_To Is Not Null
             And v_Row.Reason_From > v_Row.Reason_To Then
            Pi_Util.Raise_Error('"reason_from" "reason_to"dan katta bo''lishi mumkin emas');
          End If;
        End If;

        v_Row.Reason_Set_By := v_User_Id;
        v_Row.Reason_Set_On := Sysdate;

      Elsif v_Action = 'I' Then
        -- Insert vaqtida reason yuborilmagan bo'lsa — default PARTICIPATES
        v_Row.Current_Reason := 'PARTICIPATES';
      End If;

      -- 7. Sana tekshiruvi
      If v_Row.Added_On Is Not Null
         And v_Row.Expired_On Is Not Null
         And v_Row.Added_On > v_Row.Expired_On Then
        Pi_Util.Raise_Error('"added_on" не может быть больше "expired_on".');
      End If;

      -- 8. order_by dublikat
      If v_Row.Order_By Is Not Null Then
        Select Count(*) Into v_Count
          From pi_s_committee_members t
         Where t.order_by = v_Row.Order_By
           And t.user_id <> v_Row.User_Id;
        If v_Count > 0 Then
          Pi_Util.Raise_Error('Этот порядковый номер уже занят: order_by = ' || v_Row.Order_By);
        End If;
      End If;

      -- 9. Yozish
      If v_Action = 'I' Then
        If v_Row.Added_On Is Null Then
          v_Row.Added_On := Sysdate;
        End If;

        Insert Into pi_s_committee_members Values v_Row;

        Insert Into pi_s_committee_members_his
          (user_id, position, name, order_by, added_on, expired_on,
           action, action_by, action_on)
        Values
          (v_Row.User_Id, v_Row.Position, v_Row.Name, v_Row.Order_By,
           v_Row.Added_On, v_Row.Expired_On, 'I', v_User_Id, Sysdate);

        v_Response.put('message', 'Данные успешно добавлены!');
      Else
        Update pi_s_committee_members t
           Set Row = v_Row
         Where t.user_id = v_Row.User_Id;

        v_Response.put('message', 'Данные успешно обновлены!');
      End If;

    Elsif v_Action = 'D' Then
      Select Count(*) Into v_Count
        From pi_s_committee_members t Where t.user_id = v_Row.User_Id;
      If v_Count = 0 Then
        Pi_Util.Raise_Error('Член комитета не найден: user_id = ' || v_Row.User_Id);
      End If;

      Select t.* Into v_Row
        From pi_s_committee_members t Where t.user_id = v_Row.User_Id;

      Insert Into pi_s_committee_members_his
        (user_id, position, name, order_by, added_on, expired_on,
         action, action_by, action_on)
      Values
        (v_Row.User_Id, v_Row.Position, v_Row.Name, v_Row.Order_By,
         v_Row.Added_On, v_Row.Expired_On, 'D', v_User_Id, Sysdate);

      Delete From pi_s_committee_members Where user_id = v_Row.User_Id;

      v_Response.put('message', 'Данные успешно удалены!');
    Else
      Pi_Util.Raise_Error('Noto''g''ri action: ' || v_Action);
    End If;
    Commit;

    v_Response.put('success', True);
    o_Response := v_Response.to_clob;
  End member_ref_action;


-- ===========================================================================
-- CORE_METHODS ga yangi metod ro'yxatga olish
-- ===========================================================================
Insert Into Core_Methods (id, method, proc_name, state, has_out_param, details, cr_by, cr_on)
Values (Core_Methods_Seq.Nextval, 'setMemberReason', 'Pi_Committee.set_member_reason',
        'A', 'Y', 'Qo''mita a''zosining hozirgi holatini belgilash', Core_Session.Get_User_Id, Sysdate);
Commit;

-- Eslatma: getAbsenceReasons CORE_METHODS'ga qo'shilmaydi — spravochnik
-- Pi_S_Committee_Absence_Reasons_V view orqali /api/app/execSelect endpoint'idan
-- olinadi. Shu bilan get_absence_reasons protsedurasi ham ixtiyoriy (qoldirish
-- mumkin, lekin frontend'da ishlatilmaydi).

-- getMembersList / getVotes CORE_METHODS'da allaqachon bor — protsedura tanasi
-- yangilanganligi sabab uni qayta qo'shish shart emas.
