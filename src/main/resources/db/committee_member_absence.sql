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
-- CORE_METHODS ga 2 ta yangi metod ro'yxatga olish
-- ===========================================================================
Insert Into Core_Methods (id, method, proc_name, state, has_out_param, details, cr_by, cr_on)
Values (Core_Methods_Seq.Nextval, 'setMemberReason', 'Pi_Committee.set_member_reason',
        'A', 'Y', 'Qo''mita a''zosining hozirgi holatini belgilash', Core_Session.Get_User_Id, Sysdate);

Insert Into Core_Methods (id, method, proc_name, state, has_out_param, details, cr_by, cr_on)
Values (Core_Methods_Seq.Nextval, 'getAbsenceReasons', 'Pi_Committee.get_absence_reasons',
        'A', 'Y', 'A''zolar uchun ishtirok holatlari spravochnigi', Core_Session.Get_User_Id, Sysdate);
Commit;

-- getMembersList / getVotes CORE_METHODS'da allaqachon bor — protsedura tanasi
-- yangilanganligi sabab uni qayta qo'shish shart emas.
