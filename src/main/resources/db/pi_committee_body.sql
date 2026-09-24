-- ===========================================================================
-- PI_COMMITTEE package body — to'liq, kompilyatsiyaga tayyor
--
-- committee_absence_history.sql dagi 1- va 2-bo'limni (jadval + backfill)
-- BUNDAN OLDIN bajaring, aks holda kompilyatsiya xato beradi.
--
-- O'zgargan joylar (qolgan hamma protsedura o'zgarishsiz):
--   1) write_absence_history — YANGI, paket ichidagi yordamchi protsedura.
--      Sabab qo'yilganda/olib tashlanganda tarix jadvalini yuritadi.
--   2) get_votes — sabab endi MAJLIS SANASI uchun tanlanadi (Sysdate emas).
--   3) set_member_reason — tarixga ham yozadi.
--   4) member_ref_action — tarixga ham yozadi.
-- ===========================================================================

Create Or Replace Noneditionable Package Body Pi_Committee Is

  -- Author  : Saidazim
  -- Created : 07.08.2025 12:31:02
  -- Purpose : Методы для модуля "Комитет"

  -- -------------------------------------------------------------------------
  -- YANGI (private): a'zoning yo'qligi tarixini yuritish.
  --
  -- Nega kerak: pi_s_committee_members da faqat BITTA "hozirgi" sabab
  -- saqlanadi. Ovoz varaqasi esa tarixiy hujjat — o'tgan majlis kunida a'zo
  -- qaysi holatda bo'lganini bilishi kerak. Shu jadval bo'lmasa, a'zoga
  -- keyingi safar boshqa sabab qo'yilishi bilan eski varaqalar buziladi.
  -- -------------------------------------------------------------------------
  Procedure write_absence_history(p_User_Id Number,
                                  p_Reason  Varchar2,
                                  p_From    Date,
                                  p_To      Date,
                                  p_Note    Varchar2,
                                  p_By      Number)
  Is
    v_Updated Number(5);
  Begin
    If p_Reason Is Null Then
      Return;
    End If;

    If p_Reason = 'PARTICIPATES' Then
      -- Ishga qaytdi: ochiq davrni kechagi kun bilan yopamiz,
      -- hali boshlanmagan davrni esa butunlay olib tashlaymiz.
      Update Pi_S_Committee_Member_Absences a
         Set a.date_to = Trunc(Sysdate) - 1
       Where a.user_id = p_User_Id
         And a.date_from < Trunc(Sysdate)
         And (a.date_to Is Null Or a.date_to >= Trunc(Sysdate));

      Delete From Pi_S_Committee_Member_Absences a
       Where a.user_id = p_User_Id
         And a.date_from >= Trunc(Sysdate);
      Return;
    End If;

    -- Bir xil davr qayta yuborilsa dublikat yaratmaymiz: a'zoning ismini
    -- tahrirlashda frontend reason'ni ham qayta yuboradi.
    Update Pi_S_Committee_Member_Absences a
       Set a.note  = p_Note,
           a.cr_by = p_By,
           a.cr_on = Sysdate
     Where a.user_id   = p_User_Id
       And a.reason    = p_Reason
       And a.date_from = Nvl(p_From, Trunc(Sysdate))
       And Nvl(a.date_to, To_Date('31.12.9999', 'dd.mm.yyyy'))
           = Nvl(p_To,    To_Date('31.12.9999', 'dd.mm.yyyy'));
    v_Updated := Sql%Rowcount;

    If v_Updated = 0 Then
      Insert Into Pi_S_Committee_Member_Absences
        (user_id, reason, date_from, date_to, note, cr_by, cr_on)
      Values
        (p_User_Id, p_Reason, Nvl(p_From, Trunc(Sysdate)), p_To,
         p_Note, p_By, Sysdate);
    End If;
  End write_absence_history;

	Procedure save_committee(p_External_Id Number, p_Type Varchar2)
	Is
	  v_User_Id Number(20) := core_session.get_user_id();
		v_Id      Number(20);
	Begin

		v_Id := pi_committees_seq.nextval();
		Insert Into pi_committees(Id, external_id, Type, state, cr_by, cr_on)
		Values (v_Id, p_External_Id, p_Type, 'A', v_User_Id, Sysdate);

		Insert Into pi_committees_his(Id, external_id, Type, state, cr_by, cr_on, action, action_by, action_on)
		Values (v_Id, p_External_Id, p_Type, 'A', v_User_Id, Sysdate, 'Создан', v_User_Id, Sysdate);

		Commit;

	End;

	Procedure delete_committee(p_Request Clob, o_Response Out Clob)
  Is
    v_Json     json_object_t := json_object_t.parse(p_Request);
    v_Response json_object_t := json_object_t;
    v_Params   json_object_t := v_Json.get_Object('params');
    v_Ids      json_array_t  := v_Params.get_Array('id');
    v_User_Id  Number(20)    := core_session.get_user_id();
    v_Id       Number(20);
    v_Count    Number(2);
  Begin

    Select Count(*)
		  Into v_Count
		  From core_user_roles t
		 Where t.role_id = 6 -- Администратор
		   And t.user_id = v_User_Id;

    If v_Count = 0 Then
      Raise_Application_Error(-20001, 'У вас нет доступа к этим действиям!');
    End If;

    For i In 0 .. v_Ids.Get_Size - 1 Loop
      v_Id := v_Ids.get_Number(i);

			Insert Into pi_committees_his
      Select t.id, t.external_id, t.type, 'D', t.cr_by, t.cr_on, t.up_by, t.up_on, 'Удален', v_User_Id, Sysdate
        From pi_committees t
       Where t.id = v_Id;

			Delete From pi_committees t Where t.id = v_Id;
		End Loop;
		Commit;

		v_Response.put('success', True);
    v_Response.put('message', 'Данные успешно удалены!');

		o_Response := v_Response.to_clob;

	End;

	Procedure delete_internal_committee(p_External_Id Number, p_Type Varchar2)
	Is
	  v_User_Id Number(20) := core_session.get_user_id();
		v_Id      Number(20);
		v_Count   Number(20);
	Begin

	  Select Count(*)
		  Into v_Count
			From pi_committees t
		 Where t.external_id = p_External_Id
		   And t.type = p_Type;

		If v_Count > 0 Then
			Select t.id
		    Into v_Id
			  From pi_committees t
		   Where t.external_id = p_External_Id
		     And t.type = p_Type;

 	    Insert Into pi_committees_his(Id, external_id, Type, state, cr_by, cr_on, action, action_by, action_on)
		  Values (v_Id, p_External_Id, p_Type, 'D', v_User_Id, Sysdate, 'Удален', v_User_Id, Sysdate);

		  Delete pi_committees t Where t.id = v_Id;

		  Commit;
		End If;
	End;

	Procedure member_action(p_Request Clob, o_Response Out Clob)
	Is
	  v_Json     json_object_t := json_object_t.parse(p_Request);
		v_Response json_object_t := json_object_t;
    v_Params   json_object_t := v_Json.get_Object('params');
		v_Ids      json_array_t  := v_Params.get_Array('id');
		v_Action   Varchar2(32)  := v_Params.get_String('action');
		v_Comment  Varchar2(512) := v_Params.get_String('comments');
	  v_User_Id  Number(20)    := core_session.get_user_id();
		v_Id       Number(20);
		v_Vote     Varchar2(64);
		v_Count    Number(2);
	Begin

		Select Count(*)
		  Into v_Count
		  From pi_s_committee_members t
		 Where t.user_id = v_User_Id;

		If v_Count = 0 Then
			Raise_Application_Error(-20001, 'У вас нет доступа к этим действиям!');
		End If;

		For i In 0 .. v_Ids.Get_Size - 1 Loop
			v_Id := v_Ids.get_Number(i);

			Select Count(*)
		    Into v_Count
			  From pi_committee_member_votes t
		   Where t.user_id = v_User_Id
		     And t.committee_id = v_Id;

		  If v_Count > 0 Then
			  Raise_Application_Error(-20001, 'Вы уже голосовали за эту претензию!');
		  End If;

		  v_Vote := Case v_Action When 'agree' Then 'Рози' When 'disagree' Then 'Норози' Else 'Қайтарилди' End;

		  Insert Into pi_committee_member_votes (committee_id, user_id, vote, comments, vote_on)
		  Values (v_Id, v_User_Id, v_Vote, v_Comment, Sysdate);
		End Loop;
		Commit;

		v_Response.put('success', True);
    v_Response.put('message', 'Ваш голос принят!');

		o_Response := v_Response.to_clob;

	End;

	Procedure get_votes_v1(p_Request Clob, o_Response Out Clob)
	Is
	  v_Json     json_object_t := json_object_t.parse(p_Request);
		v_Response json_object_t := json_object_t;
    v_Params   json_object_t := v_Json.get_Object('params');
		v_Data     json_object_t := json_object_t();
		v_Datas    json_array_t  := json_array_t();
		v_Id       Number(20)    := v_Params.get_Number('id');
		v_Vote     Varchar2(128);
		v_Vote_On  Varchar2(64);
		v_Comments Varchar2(2048);
    v_Row      pi_committees_v%rowtype;
	Begin

	  For i In (Select
                t.user_id,
                t.name,
                t.position,
                nvl(t.added_on, to_date('01.11.2025', 'dd.mm.yyyy')) added_on,
                t.expired_on
                From pi_s_committee_members t Order By t.order_by) Loop
			begin
        Select k.* into v_Row
          From pi_committees_v k
         where k.ID = v_Id;

        if to_date(v_Row.APPLICATION_DATE, 'dd.mm.yyyy') < i.added_on then
          continue;
        end if;

        if to_date(v_Row.APPLICATION_DATE, 'dd.mm.yyyy') > i.expired_on then
          continue;
        end if;
      exception
        when others then
          null;
      end;

			Begin
				Select v.vote, v.comments, to_char(v.vote_on, 'dd.mm.yyyy hh24:mi:ss')
				  Into v_Vote, v_Comments, v_Vote_On
				  From pi_committee_member_votes v
				 Where v.user_id = i.user_id
				   And v.committee_id = v_Id;
			Exception
				When no_data_found Then
					v_Vote     := 'Кутилмоқда';
					v_Vote_On  := Null;
					v_Comments := Null;
			End;

			v_Data.put('committee_id', v_Id);
			v_Data.put('user_id', i.user_id);
			v_Data.put('user_name', i.name);
      v_Data.put('vote', v_Vote);
			v_Data.put('vote_on', v_Vote_On);
			v_Data.put('comments', v_Comments);
			v_Data.put('role', i.position);

			v_Datas.append(v_Data);
		End Loop;


		v_Response.put('votes', v_Datas);

		o_Response := v_Response.to_clob;

	End;

	Function has_role(p_User_Id In Number, p_Role_Id In Number) Return Varchar2
	Is
	  v_Count Pls_Integer := 0;
	Begin
		Select Count(*)
		  Into v_Count
		  From core_user_roles t
		 Where t.user_id = p_User_Id
		   And t.role_id = p_Role_Id;

	  Return Case v_Count When 0 Then 'N' Else 'Y' End;
	End;

  Procedure generate_payout_file(p_Request In Clob, o_Response Out Clob)
	Is
	  v_Json      json_object_t := json_object_t.parse(p_Request);
		v_Variables json_array_t  := json_array_t();
		v_Payload   json_object_t := json_object_t();
    v_Params    json_object_t := v_Json.get_Object('params');
		v_Id        Number(20)    := v_Params.get_Number('id');
		v_Type      Varchar2(32);
		v_Ext_Id    Number(20);
		v_Response  Clob;
		v_Item      json_object_t;
	Begin

		Begin
		  Select t.type, t.external_id
		    Into v_Type, v_Ext_Id
			  From pi_committees t
		   Where t.id = v_Id
		     And t.state = 'A';
		Exception
			When no_data_found Then
			  Raise_Application_Error(-20001, 'Данные не найдены в модуле Комитет');
		End;

	  If v_Type != 'IP' Then
			Raise_Application_Error(-20001, 'Доступны только протоколы для страховых выплат');
		End If;

		For i In (Select * From pi_covers_v2_v t Where t.id = v_Ext_Id) Loop

			-- Номер платежного документа ст. 4
			v_Item := json_object_t();
      v_Item.put('name', 'document_number');
      v_Item.put('value', i.applicant_payment_document_number);
      v_Variables.append(v_Item);

      -- Дата оплата ст. 4
      v_Item := json_object_t();
      v_Item.put('name', 'payment_date');
      v_Item.put('value', i.sum_pay_date);
      v_Variables.append(v_Item);

      -- Сумма страховой выплаты ст. 4
      v_Item := json_object_t();
      v_Item.put('name', 'payment_amount');
      v_Item.put('value', pi_util.get_sum_space(i.sum_pay));
      v_Variables.append(v_Item);

			v_Item := json_object_t();
      v_Item.put('name', 'payment_summ_text');
      v_Item.put('value', nls_util.sum_doc_word(i.sum_pay, 1, '000'));
      v_Variables.append(v_Item);

      -- Заемщик ст. 2
      v_Item := json_object_t();
      v_Item.put('name', 'client_name');
      v_Item.put('value', i.ext_loan_debtor);
      v_Variables.append(v_Item);

      -- Счет ст. 5
      v_Item := json_object_t();
      v_Item.put('name', 'account');
      v_Item.put('value', i.account);
      v_Variables.append(v_Item);

      -- Страховщик (банк) ст. 2
      v_Item := json_object_t();
      v_Item.put('name', 'bank_name');
      v_Item.put('value', i.insurer_bank_name);
      v_Variables.append(v_Item);

      -- ИНН ст. 5
      v_Item := json_object_t();
      v_Item.put('name', 'inn');
      v_Item.put('value', i.account_inn);
      v_Variables.append(v_Item);

      -- МФО ст. 5
      v_Item := json_object_t();
      v_Item.put('name', 'mfo');
      v_Item.put('value', i.account_mfo);
      v_Variables.append(v_Item);

      -- № договора ст. 2
      v_Item := json_object_t();
      v_Item.put('name', 'contract_number');
      v_Item.put('value', i.ext_contract_num);
      v_Variables.append(v_Item);

      -- Дата договора ст. 2
      v_Item := json_object_t();
      v_Item.put('name', 'contract_date');
      v_Item.put('value', i.ext_contract_date);
      v_Variables.append(v_Item);
		End Loop;

		v_Payload.put('id', '3'); -- ИД шаблона в таблице CORE_FILE_TEMPLATES
		v_Payload.put('qrcode', 'null');
		v_Payload.put('variables', v_Variables);

		dbms_output.put_line(''||v_Payload.To_Clob);

		v_Response := core_util.send_http(v_Payload.to_clob(), 'http://192.168.1.198:9999/api/document/generate-document');

		o_Response := v_Response;

	End;

	Procedure generate_decision_file(p_Request In Clob, o_Response Out Clob)
	Is
	  v_Json      json_object_t := json_object_t.parse(p_Request);
		v_Variables json_array_t  := json_array_t();
		v_Payload   json_object_t := json_object_t();
    v_Params    json_object_t := v_Json.get_Object('params');
		v_Id        Number(20)    := v_Params.get_Number('id');
		v_Type      Varchar2(32);
		v_Ext_Id    Number(20);
		v_Response  Clob;
		v_Item      json_object_t;
	Begin

		Begin
		  Select t.type, t.external_id
		    Into v_Type, v_Ext_Id
			  From pi_committees t
		   Where t.id = v_Id
		     And t.state = 'A';
		Exception
			When no_data_found Then
			  Raise_Application_Error(-20001, 'Данные не найдены в модуле Комитет');
		End;

	  If v_Type != 'IP' Then
			Raise_Application_Error(-20001, 'Доступны только протоколы для страховых выплат');
		End If;

		For i In (Select * From pi_covers_v2_v t Where t.id = v_Ext_Id) Loop

		  v_Item := json_object_t();
      v_Item.put('name', 'current_date');
      v_Item.put('value', to_char(Sysdate, 'dd.mm.yyyy'));
      v_Variables.append(v_Item);

      -- Дата договора ст. 2
      v_Item := json_object_t();
      v_Item.put('name', 'contract_date');
      v_Item.put('value', i.ext_contract_date);
      v_Variables.append(v_Item);

			-- № договора ст. 2
      v_Item := json_object_t();
      v_Item.put('name', 'contract_number');
      v_Item.put('value', i.ext_contract_num);
      v_Variables.append(v_Item);

			-- Номер платежного документа ст. 4
			v_Item := json_object_t();
      v_Item.put('name', 'document_number');
      v_Item.put('value', i.applicant_payment_document_number);
      v_Variables.append(v_Item);

			-- Дата выдачи полиса ст. 2
      v_Item := json_object_t();
      v_Item.put('name', 'polis_date');
      v_Item.put('value', i.ext_polis_given_date);
      v_Variables.append(v_Item);

			-- Серия и номер полиса ст. 2
      v_Item := json_object_t();
      v_Item.put('name', 'polis_number');
      v_Item.put('value', i.ext_polis_series || ' ' || i.ext_polis_number);
      v_Variables.append(v_Item);

			-- Страховщик (банк) ст. 2
      v_Item := json_object_t();
      v_Item.put('name', 'bank_name');
      v_Item.put('value', i.insurer_bank_name || ' ' || i.insurer_filial_name);
      v_Variables.append(v_Item);

			-- Заемщик ст. 2
      v_Item := json_object_t();
      v_Item.put('name', 'client_name');
      v_Item.put('value', i.ext_loan_debtor);
      v_Variables.append(v_Item);

      -- Дата оплата ст. 4
      v_Item := json_object_t();
      v_Item.put('name', 'payment_date');
      v_Item.put('value', i.sum_pay_date);
      v_Variables.append(v_Item);

      -- Сумма страховой выплаты ст. 4
      v_Item := json_object_t();
      v_Item.put('name', 'payment_amount');
      v_Item.put('value', pi_util.get_sum_space(i.sum_pay));
      v_Variables.append(v_Item);

			-- Сумма страховой выплаты ст. 4
      v_Item := json_object_t();
      v_Item.put('name', 'payment_amount_text');
      v_Item.put('value', nls_util.sum_doc_word(i.sum_pay, 2, '000'));
      v_Variables.append(v_Item);

      -- Счет ст. 5
      v_Item := json_object_t();
      v_Item.put('name', 'account');
      v_Item.put('value', i.account);
      v_Variables.append(v_Item);

			-- МФО ст. 5
      v_Item := json_object_t();
      v_Item.put('name', 'mfo');
      v_Item.put('value', i.account_mfo);
      v_Variables.append(v_Item);

      -- ИНН ст. 5
      v_Item := json_object_t();
      v_Item.put('name', 'inn');
      v_Item.put('value', i.account_inn);
      v_Variables.append(v_Item);

		End Loop;

		v_Payload.put('id', '2'); -- ИД шаблона в таблице CORE_FILE_TEMPLATES
		v_Payload.put('qrcode', 'null');
		v_Payload.put('variables', v_Variables);

		--dbms_output.put_line(''||v_Payload.To_Clob);

		v_Response := core_util.send_http(v_Payload.to_clob(), 'http://192.168.1.198:9999/api/document/generate-document');

		o_Response := v_Response;

	End;

	Procedure generate_protocol_file(p_Request In Clob, o_Response Out Clob)
	Is
	  v_Json      json_object_t := json_object_t.parse(p_Request);
		v_Variables json_array_t  := json_array_t();
		v_Payload   json_object_t := json_object_t();
    v_Params    json_object_t := v_Json.get_Object('params');
		v_Id        Number(20)    := v_Params.get_Number('id');
		v_Type      Varchar2(32);
		v_Ext_Id    Number(20);
		v_Response  Clob;
		v_Item      json_object_t;
		v_Index     Pls_Integer := 1;
		v_Vote      Varchar2(128);
		v_Vote_On   Varchar2(64);
		v_Comments  Varchar2(1024);
	Begin

		Begin
		  Select t.type, t.external_id
		    Into v_Type, v_Ext_Id
			  From pi_committees t
		   Where t.id = v_Id
		     And t.state = 'A';
		Exception
			When no_data_found Then
			  Raise_Application_Error(-20001, 'Данные не найдены в модуле Комитет');
		End;

	  If v_Type != 'IP' Then
			Raise_Application_Error(-20001, 'Доступны только протоколы для страховых выплат');
		End If;

		For i In (Select t.user_id,
                     (Select Upper(r.last_name) || ' ' || Upper(r.first_name)
			                  From Core_Users r
				               Where r.user_id = t.user_id) user_name,
										 t.position
								From pi_s_committee_members t
							 Order By t.position Desc) Loop

			Begin
				Select nvl(v.vote, ''), nvl(v.comments, ''), nvl(to_char(v.vote_on, 'dd.mm.yyyy'),'')
				  Into v_Vote, v_Comments, v_Vote_On
				  From pi_committee_member_votes v
				 Where v.user_id = i.user_id
				   And v.committee_id = v_Id;
			Exception
				When no_data_found Then
					v_Vote     := '';
					v_Vote_On  := '';
					v_Comments := '';
			End;

		  v_Item := json_object_t();
      v_Item.put('name', 'role_name_' || v_Index);
      v_Item.put('value', i.position);
      v_Variables.append(v_Item);

			v_Item := json_object_t();
      v_Item.put('name', 'member_name_' || v_Index);
      v_Item.put('value', i.user_name);
      v_Variables.append(v_Item);

			v_Item := json_object_t();
      v_Item.put('name', 'vote_' || v_Index);
      v_Item.put('value', v_Vote);
      v_Variables.append(v_Item);

			v_Item := json_object_t();
      v_Item.put('name', 'vote_date_' || v_Index);
      v_Item.put('value', v_Vote_On);
      v_Variables.append(v_Item);

      v_Item := json_object_t();
      v_Item.put('name', 'comment_' || v_Index);
      v_Item.put('value', v_Comments);
      v_Variables.append(v_Item);

			v_Index := v_Index + 1;

		End Loop;

		v_Payload.put('id', '4'); -- ИД шаблона в таблице CORE_FILE_TEMPLATES
		v_Payload.put('qrcode', 'Ushbu xujjat komitet a''zolari tomonidan Elektron Imzo orqali '|| to_char(Sysdate, 'dd.mm.yyyy') ||' da tasdiqlangan');
		v_Payload.put('variables', v_Variables);

--		dbms_output.put_line(''||v_Payload.To_Clob);

		v_Response := core_util.send_http(v_Payload.to_clob(), 'http://192.168.1.198:9999/api/document/generate-document');

		o_Response := v_Response;

	End;

	Procedure save_qrcode_file(p_Request Clob, p_File Blob Default Null, o_Response Out Clob)
	Is
	  v_Json     json_object_t := json_object_t.parse(p_Request);
		v_Response json_object_t := json_object_t;
    v_Params   json_object_t := v_Json.get_Object('params');
		v_Id       Number(20)    := v_Params.get_Number('id');
		v_Uuid     Varchar2(256) := v_Params.get_String('uuid');
		v_Url      Varchar2(512);
		v_File_Id  Number(20);
		v_Count    Number(2);
		v_User_Id  Number(20) := core_session.get_user_id();
	Begin

	  Select Count(*)
		  Into v_Count
			From pi_committee_files t
		 Where t.uuid = v_Uuid;

		If v_Count > 0 Then
			Raise_Application_Error(-20001, 'Наименования файла должен быть уникальным!');
		End If;

	  Select Count(*)
		  Into v_Count
			From pi_committee_files t
		 Where t.committee_id = v_Id
		   And t.type = 'DECISION'
		   And t.state = 'A';

	  If v_Count > 0 Then
			v_Response.put('message', 'successOk');
		  v_Response.put('oper', False);
		  v_Response.put('file_name', v_Uuid || '.pdf');

		  o_Response := v_Response.to_clob;
			Return;
		End If;

		Select Count(*)
		  Into v_Count
			From pi_committees t
		 Where t.id = v_Id
		   And t.type = 'IP'
		   And t.state = 'A';

		If v_Count = 0 Then
			Raise_Application_Error(-20001, 'QR-код можно сгенерировать только для Страховых выплат!');
		End If;

	  v_File_Id := pi_committee_files_seq.nextval();
		v_Url     := 'http://185.74.7.37:9999/api/app/get-file?file='|| v_Uuid ||'.pdf';

	  Insert Into pi_committee_files (id, committee_id, uuid, url, Type, state, cr_by, cr_on)
		Values (v_File_Id, v_Id, v_Uuid, v_Url, 'DECISION', 'A', v_User_Id, Sysdate);
		Commit;

		v_Response.put('message', 'successOk');
		v_Response.put('oper', True);
		v_Response.put('file_name', v_Uuid || '.pdf');

		o_Response := v_Response.to_clob;

	End;

	Procedure get_payout_file_data(p_Request Clob, o_Response Out Clob)
  Is
    v_Json     json_object_t := json_object_t.parse(p_Request);
    v_Response json_object_t := json_object_t();
		v_Data     json_object_t := json_object_t();
    v_Params   json_object_t := v_Json.get_Object('params');
    v_Id       Number(20)    := v_Params.get_Number('id');
		v_Type     Varchar2(32);
		v_Ext_Id   Number(20);
  Begin

    Begin
      Select t.type, t.external_id
        Into v_Type, v_Ext_Id
        From pi_committees t
       Where t.id = v_Id
         And t.state = 'A';
    Exception
      When no_data_found Then
        Raise_Application_Error(-20001, 'Данные не найдены в модуле Комитет');
    End;

    If v_Type != 'IP' Then
      Raise_Application_Error(-20001, 'Доступны только для страховых выплат');
    End If;

    For i In (Select * From pi_covers_v2_v t Where t.id = v_Ext_Id) Loop
      v_Data.put('document_number', i.applicant_payment_document_number); -- Номер платежного документа ст. 4
      v_Data.put('payment_date', i.sum_pay_date); -- Дата оплата ст. 4
      v_Data.put('payment_amount', pi_util.get_sum_space(i.sum_pay)); -- Сумма страховой выплаты ст. 4
      v_Data.put('payment_summ_text', nls_util.sum_doc_word(i.sum_pay, 1, '000')); -- Сумма прописю
      v_Data.put('client_name', i.ext_loan_debtor); -- Заемщик ст. 2
      v_Data.put('account', i.account); -- Счет ст. 5
      v_Data.put('bank_name', i.insurer_bank_name); -- Страховщик (банк) ст. 2
      v_Data.put('inn', i.account_inn); -- ИНН ст. 5
      v_Data.put('mfo', i.account_mfo); -- МФО ст. 5
      v_Data.put('contract_number', i.ext_contract_num); -- № договора ст. 2
      v_Data.put('contract_date', i.ext_contract_date); -- Дата договора ст. 2
    End Loop;

    v_Response.put('message', 'successOk');
    v_Response.put('payout', v_Data);

    o_Response := v_Response.to_clob;

  End;

	Procedure save_payout_file(p_Request Clob, p_File Blob Default Null, o_Response Out Clob)
	Is
	  v_Json     json_object_t := json_object_t.parse(p_Request);
		v_Response json_object_t := json_object_t;
    v_Params   json_object_t := v_Json.get_Object('params');
		v_Id       Number(20)    := v_Params.get_Number('id');
		v_Uuid     Varchar2(256) := v_Params.get_String('uuid');
		v_Url      Varchar2(512);
		v_File_Id  Number(20);
		v_Count    Number(2);
		v_User_Id  Number(20) := core_session.get_user_id();
	Begin

	  Select Count(*)
		  Into v_Count
			From pi_committee_files t
		 Where t.uuid = v_Uuid;

		If v_Count > 0 Then
			Raise_Application_Error(-20001, 'Наименования файла должен быть уникальным!');
		End If;

	  Select Count(*)
		  Into v_Count
			From pi_committee_files t
		 Where t.committee_id = v_Id
		   And t.type = 'PAYOUT'
		   And t.state = 'A';

	  If v_Count > 0 Then
			v_Response.put('message', 'successOk');
		  v_Response.put('oper', False);
		  v_Response.put('file_name', v_Uuid || '.pdf');

		  o_Response := v_Response.to_clob;
			Return;
		End If;

		Select Count(*)
		  Into v_Count
			From pi_committees t
		 Where t.id = v_Id
		   And t.type = 'IP'
		   And t.state = 'A';

		If v_Count = 0 Then
			Raise_Application_Error(-20001, 'Только для Страховых выплат!');
		End If;

	  v_File_Id := pi_committee_files_seq.nextval();
		v_Url     := 'http://185.74.7.37:9999/api/app/get-file?file='|| v_Uuid ||'.pdf';

	  Insert Into pi_committee_files (id, committee_id, uuid, url, Type, state, cr_by, cr_on)
		Values (v_File_Id, v_Id, v_Uuid, v_Url, 'PAYOUT', 'A', v_User_Id, Sysdate);

		Commit;

		v_Response.put('message', 'successOk');
		v_Response.put('oper', True);
		v_Response.put('file_name', v_Uuid || '.pdf');

		o_Response := v_Response.to_clob;

	End;

	Procedure send_qrcode_file(p_Request Clob, o_Response Out Clob) Is
		v_Json       json_object_t := json_object_t.parse(p_Request);
		v_Response   json_object_t := json_object_t;
		v_Resp       Clob;
		v_Request    json_object_t := json_object_t;
    v_Params     json_object_t := v_Json.get_Object('params');
		v_Id         Number(20)    := v_Params.get_Number('id');
		v_File_Name  Varchar2(256);
		v_Claim_Uuid Varchar2(256);
		v_Ext_Id     Number(20);
		v_Data       Clob;
		v_Count      Number(2);
  Begin

	  Select Count(*)
		  Into v_Count
      From pi_committee_files t
	   Where t.committee_id = v_Id
	     And t.type = 'DECISION'
			 And t.state = 'A'
			 And t.is_send = 'Y';

		If v_Count > 0 Then
			v_Response.put('message', 'Файл уже отправлено!');

		  o_Response := v_Response.to_clob;
			Return;
		End If;

	  Begin
	    Select t.uuid || '.pdf'
		    Into v_File_Name
		    From pi_committee_files t
		   Where t.committee_id = v_Id
		     And t.type = 'DECISION'
			   And t.state = 'A'
			   And t.is_send Is Null;
		Exception
			When no_data_found Then
				Raise_Application_Error(-20001, 'Файл протокола не найдено!');
		End;

	  Select t.external_id
		  Into v_Ext_Id
		  From pi_committees t
		 Where t.id = v_Id
		   And t.type = 'IP'
		   And t.state = 'A';

		Begin
		  Select t.fond_uuid
		    Into v_Claim_Uuid
			  From pi_covers_v2 t
		   Where t.id = v_Ext_Id
		     And t.fond_uuid Is Not Null;
		Exception
			When no_data_found Then
				raise_Application_Error(-20001, 'claimUuid не найден, сначала отправьте претензию!');
		End;

		v_Data := '{ "claimUuids[]": ["'|| v_Claim_Uuid ||'"] }';

    v_Request.put('body', json_object_t.parse(v_Data));
    v_Request.put('token', pi_insurance_service.Get_Token_V2);
    v_Request.put('method_type', 'POST');
    v_Request.put('is_proxy', True);
    v_Request.put('proxy_ip', '192.168.1.201');
    v_Request.put('proxy_port', 8080);
    v_Request.put('url', pi_insurance_service.c_Host||'/api/v3/claim/upload-decision-file');
		v_Request.put('file_name', v_File_Name);

    v_Resp := Core_Util.Send_Http(v_Request.to_clob(), 'http://192.168.1.198:9999/api/app/send-form-data-request');

		Update pi_committee_files t
		   Set t.request = v_Data,
					 t.response = v_Resp
		 Where t.committee_id = v_Id
		   And t.type = 'DECISION'
			 And t.state = 'A';
		Commit;

	  If json_value(v_Resp, '$.success') = 'true' Then
		  Update pi_committee_files t
			   Set t.is_send = 'Y'
			 Where t.committee_id = v_Id
		     And t.type = 'DECISION'
			   And t.state = 'A';
		  Commit;
		Else
			Raise_Application_Error(-20001, 'Ошибка в отправке протокола - ' || v_Resp);
		End If;

		v_Response.put('message', 'Файл успешно отправлено!');

		o_Response := v_Response.to_clob;

  End;

	Procedure send_payout_file(p_Request Clob, o_Response Out Clob) Is
		v_Json       json_object_t := json_object_t.parse(p_Request);
		v_Response   json_object_t := json_object_t;
		v_Resp       Clob;
		v_Request    json_object_t := json_object_t;
    v_Params     json_object_t := v_Json.get_Object('params');
		v_Id         Number(20)    := v_Params.get_Number('id');
		v_File_Name  Varchar2(256);
		v_Claim_Uuid Varchar2(256);
		v_Ext_Id     Number(20);
		v_Data       Clob;
		v_Count      Number(2);
  Begin

	  Select Count(*)
		  Into v_Count
      From pi_committee_files t
	   Where t.committee_id = v_Id
	     And t.type = 'PAYOUT'
			 And t.state = 'A'
			 And t.is_send = 'Y';

		If v_Count > 0 Then
			v_Response.put('message', 'Файл уже отправлено!');

		  o_Response := v_Response.to_clob;
			Return;
		End If;

	  Begin
	    Select t.uuid || '.pdf'
		    Into v_File_Name
		    From pi_committee_files t
		   Where t.committee_id = v_Id
		     And t.type = 'PAYOUT'
			   And t.state = 'A'
			   And t.is_send Is Null;
		Exception
			When no_data_found Then
				Raise_Application_Error(-20001, 'Файл не найден или уже отправлено в Фонд!');
		End;

	  Select t.external_id
		  Into v_Ext_Id
		  From pi_committees t
		 Where t.id = v_Id
		   And t.type = 'IP'
		   And t.state = 'A';

		Begin
		  Select t.fond_uuid
		    Into v_Claim_Uuid
			  From pi_covers_v2 t
		   Where t.id = v_Ext_Id
		     And t.fond_uuid Is Not Null;
		Exception
			When no_data_found Then
				raise_Application_Error(-20001, 'claimUuid не найден, сначала отправьте претензию!');
		End;

		v_Data := '{ "claimUuids[]": ["'|| v_Claim_Uuid ||'"] }';

    v_Request.put('body', json_object_t.parse(v_Data));
    v_Request.put('token', pi_insurance_service.Get_Token_V2);
    v_Request.put('method_type', 'POST');
    v_Request.put('is_proxy', True);
    v_Request.put('proxy_ip', '192.168.1.201');
    v_Request.put('proxy_port', 8080);
    v_Request.put('url', pi_insurance_service.c_Host||'/api/v3/claim/upload-payout-file');
		v_Request.put('file_name', v_File_Name);

    v_Resp := Core_Util.Send_Http(v_Request.to_clob(), 'http://192.168.1.198:9999/api/app/send-form-data-request');

		Update pi_committee_files t
		   Set t.request = v_Data,
					 t.response = v_Resp
		 Where t.committee_id = v_Id
		   And t.type = 'PAYOUT'
			 And t.state = 'A';
		Commit;

	  If json_value(v_Resp, '$.success') = 'true' Then
		  Update pi_committee_files t
			   Set t.is_send = 'Y'
			 Where t.committee_id = v_Id
		     And t.type = 'PAYOUT'
			   And t.state = 'A';
		  Commit;
		Else
			Raise_Application_Error(-20001, 'Ошибка в отправке выплаты - ' || v_Resp);
		End If;

		v_Response.put('message', 'Файл успешно отправлено!');

		o_Response := v_Response.to_clob;

  End;

  procedure save_application_file(p_Request  clob,
                                  p_File     blob default null,
                                  o_Response out clob) is
    v_Json     json_object_t := json_object_t.parse(p_Request);
    v_Response json_object_t := json_object_t;
    v_Params   json_object_t := v_Json.get_Object('params');
    v_Ids      json_array_t;
    v_Uuid     varchar2(256) := v_Params.get_String('uuid');
    v_Url      varchar2(512);
    v_File_Id  number(20);
    v_Count    number(2);
    v_User_Id  number(20) := core_session.get_user_id();
    v_Id       number;
    vExtension varchar2(10) := v_Json.get_String('fileExtension');
  begin
    -- Get array
    v_Ids := v_Params.get_Array('ids');
    for i in 0 .. v_Ids.get_size - 1
    loop
      v_Id := v_Ids.get_Number(i);

      select count(*)
        into v_Count
        from pi_committee_files t
       where t.committee_id = v_Id
         and t.type = 'APPLICATION'
         and t.state = 'A';

      if v_Count > 0 then
        continue;
      end if;

      select count(*)
        into v_Count
        from pi_committees t
       where t.id = v_Id
         and t.type = 'IP'
         and t.state = 'A';

      if v_Count = 0 then
        CONTINUE;
      end if;

      v_File_Id := pi_committee_files_seq.nextval();
      v_Url     := 'http://185.74.7.37:9999/api/app/get-file?file=' ||
                   v_Uuid || '.'||vExtension;

      insert into pi_committee_files
        (id, committee_id, uuid, url, type, state, cr_by, cr_on)
      values
        (v_File_Id, v_Id, v_Uuid, v_Url, 'APPLICATION', 'A', v_User_Id, sysdate);

      commit;
    end loop;

    v_Response.put('message', 'successOk');
    v_Response.put('oper', true);
    v_Response.put('file_name', v_Uuid || '.'||vExtension);

    o_Response := v_Response.to_clob;

  end;

  Procedure send_application_file(pRequest varchar2, oResponse out clob) Is
    v_Json     json_object_t := json_object_t.parse(pRequest);
    v_Params   json_object_t := v_Json.get_Object('params');
    v_Response   json_object_t := json_object_t;
    v_Resp       Clob;
    v_Request    json_object_t := json_object_t;
    v_Id         Number(20);
    v_File_Name  Varchar2(256);
    v_Claim_Uuid Varchar2(256);
    v_Ext_Id     Number(20);
    v_Data       Clob;
    v_Count      Number(2);
    v_Ids      json_array_t;
  Begin
    -- Get array
    v_Ids := v_Params.get_Array('ids');
    for i in 0 .. v_Ids.get_size - 1
    loop
      v_Id := v_Ids.get_Number(i);

    Select Count(*)
      Into v_Count
      From pi_committee_files t
     Where t.committee_id = v_Id
       And t.type = 'APPLICATION'
       And t.state = 'A'
       And t.is_send = 'Y';

    If v_Count > 0 Then
      continue;
    End If;

    Begin
      Select t.uuid || '.pdf'
        Into v_File_Name
        From pi_committee_files t
       Where t.committee_id = v_Id
         And t.type = 'APPLICATION'
         And t.state = 'A'
         And t.is_send Is Null;
    Exception
      When no_data_found Then
        continue;
    End;

    Select t.external_id
      Into v_Ext_Id
      From pi_committees t
     Where t.id = v_Id
       And t.type = 'IP'
       And t.state = 'A';

    Begin
      Select t.fond_uuid
        Into v_Claim_Uuid
        From pi_covers_v2 t
       Where t.id = v_Ext_Id
         And t.fond_uuid Is Not Null;
    Exception
      When no_data_found Then
       continue;
    End;

    v_Data := '{ "claimUuid": "'|| v_Claim_Uuid ||'" }';

    v_Request.put('body', json_object_t.parse(v_Data));
    v_Request.put('token', pi_insurance_service.Get_Token_V2);
    v_Request.put('method_type', 'POST');
    v_Request.put('is_proxy', True);
    v_Request.put('proxy_ip', '192.168.1.201');
    v_Request.put('proxy_port', 8080);
    v_Request.put('url', pi_insurance_service.c_Host||'/api/v3/claim/upload-application-file');
    v_Request.put('file_name', v_File_Name);

    v_Resp := Core_Util.Send_Http(v_Request.to_clob(), 'http://192.168.1.198:9999/api/app/send-form-data-request');

    Update pi_committee_files t
       Set t.request = v_Data,
           t.response = v_Resp
     Where t.committee_id = v_Id
       And t.type = 'APPLICATION'
       And t.state = 'A';
    Commit;

    If json_value(v_Resp, '$.success') = 'true' Then
      Update pi_committee_files t
         Set t.is_send = 'Y'
       Where t.committee_id = v_Id
         And t.type = 'APPLICATION'
         And t.state = 'A';
      Commit;
    Else
      Raise_Application_Error(-20001, 'Ошибка в отправке выплаты - ' || v_Resp);
    End If;
    end loop;
    v_Response.put('message', 'Файл успешно отправлено!');
    oResponse := v_Response.to_clob;

  End;

  --Cr By: Arslonbek Kulmatov
  --Qo'mita a'zolari spravochnigi: qo'shish/o'zgartirish/o'chirish
  Procedure member_ref_action_v1(p_Request Clob, o_Response Out Clob)
  Is
    v_Json     json_object_t := json_object_t.parse(p_Request);
    v_Response json_object_t := json_object_t();
    v_Params   json_object_t := v_Json.get_Object('params');
    v_Action   Varchar2(2)   := v_Params.get_String('action');
    v_User_Id  Number(20)    := core_session.get_user_id();
    v_Row      pi_s_committee_members%rowtype;
    v_Count    Number(5);
  Begin
    --1. Ruxsat tekshiruvi (faqat administrator)
    Select Count(*)
      Into v_Count
      From core_user_roles t
     Where t.role_id = 6
       And t.user_id = v_User_Id;

    If v_Count = 0 Then
      Pi_Util.Raise_Error('У вас нет доступа к этим действиям!');
    End If;

    Pi_Util.Check_For_Existance(v_Params, 'action');
    Pi_Util.Check_For_Existance(v_Params, 'user_id');

    v_Row.User_Id := v_Params.get_Number('user_id');

    If v_Action In ('I', 'U') Then
      --2. Foydalanuvchi mavjudligi
      Select Count(*)
        Into v_Count
        From core_users t
       Where t.user_id = v_Row.User_Id;

      If v_Count = 0 Then
        Pi_Util.Raise_Error('Пользователь не найден: user_id = '||v_Row.User_Id);
      End If;

      --3. Mavjudligini tekshirish
      Select Count(*)
        Into v_Count
        From pi_s_committee_members t
       Where t.user_id = v_Row.User_Id;

      If v_Action = 'I' And v_Count > 0 Then
        Pi_Util.Raise_Error('Этот пользователь уже является членом комитета!');
      End If;

      If v_Action = 'U' And v_Count = 0 Then
        Pi_Util.Raise_Error('Член комитета не найден: user_id = '||v_Row.User_Id);
      End If;

      --4. O'zgartirishda avvalgi qiymatlarni olamiz
      If v_Action = 'U' Then
        Select t.* Into v_Row
          From pi_s_committee_members t
         Where t.user_id = v_Row.User_Id;

        --history: eski holat
        Insert Into pi_s_committee_members_his
          (user_id, position, name, order_by, added_on, expired_on,
           action, action_by, action_on)
        Values
          (v_Row.User_Id, v_Row.Position, v_Row.Name, v_Row.Order_By,
           v_Row.Added_On, v_Row.Expired_On, 'U', v_User_Id, Sysdate);
      End If;

      --5. Maydonlar
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
        Exception
          When others Then
            Pi_Util.Raise_Error('Неправильный формат "added_on". Нужно: dd.mm.yyyy');
        End;
      End If;

      If v_Params.has('expired_on') Then
        Begin
          v_Row.Expired_On := to_date(v_Params.get_String('expired_on'), 'dd.mm.yyyy');
        Exception
          When others Then
            Pi_Util.Raise_Error('Неправильный формат "expired_on". Нужно: dd.mm.yyyy');
        End;
      End If;

      --6. Sana tekshiruvi
      If v_Row.Added_On Is Not Null
         And v_Row.Expired_On Is Not Null
         And v_Row.Added_On > v_Row.Expired_On Then
        Pi_Util.Raise_Error('"added_on" не может быть больше "expired_on".');
      End If;

      --7. order_by takrorlanmasligi
      If v_Row.Order_By Is Not Null Then
        Select Count(*)
          Into v_Count
          From pi_s_committee_members t
         Where t.order_by = v_Row.Order_By
           And t.user_id <> v_Row.User_Id;

        If v_Count > 0 Then
          Pi_Util.Raise_Error('Этот порядковый номер уже занят: order_by = '||v_Row.Order_By);
        End If;
      End If;

      --8. Yozish
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
           Set row = v_Row
         Where t.user_id = v_Row.User_Id;

        v_Response.put('message', 'Данные успешно обновлены!');
      End If;

    Elsif v_Action = 'D' Then
      Select Count(*)
        Into v_Count
        From pi_s_committee_members t
       Where t.user_id = v_Row.User_Id;

      If v_Count = 0 Then
        Pi_Util.Raise_Error('Член комитета не найден: user_id = '||v_Row.User_Id);
      End If;

      --ovoz bergan bo'lsa o'chirmaymiz (tarix buzilmasligi uchun)
      Select Count(*)
        Into v_Count
        From pi_committee_member_votes t
       Where t.user_id = v_Row.User_Id;

      If v_Count > 0 Then
        Pi_Util.Raise_Error('Этот член уже голосовал ('||v_Count||' раз). '||
                            'Удаление невозможно - укажите "expired_on".');
      End If;

      Insert Into pi_s_committee_members_his
        (user_id, position, name, order_by, added_on, expired_on,
         action, action_by, action_on)
      Select t.user_id, t.position, t.name, t.order_by, t.added_on, t.expired_on,
             'D', v_User_Id, Sysdate
        From pi_s_committee_members t
       Where t.user_id = v_Row.User_Id;

      Delete From pi_s_committee_members t Where t.user_id = v_Row.User_Id;

      v_Response.put('message', 'Данные успешно удалены!');
    Else
      Pi_Util.Raise_Error('Неправильное действие. Доступны: I, U, D');
    End If;

    Commit;

    v_Response.put('user_id', v_Row.User_Id);
    v_Response.put('success', True);
    v_Response.put('oper', True);

    o_Response := v_Response.to_clob;
  Exception
    When others Then
      Rollback;
      Pi_Util.Raise_Error(sqlerrm);
  End;

  --Cr By: Arslonbek Kulmatov
  --Qo'mita a'zolari ro'yxati
  Procedure get_members_list_v1(p_Request varchar2, o_Response Out Clob)
  Is
    v_Json        json_object_t := json_object_t.parse(p_Request);
    v_Response    json_object_t := json_object_t();
    v_Params      json_object_t;
    v_Data        json_object_t;
    v_Datas       json_array_t  := json_array_t();
    v_Only_Active Number(1) := 0;
  Begin
    Begin
      v_Params := v_Json.get_Object('params');
      If v_Params.has('only_active') Then
        v_Only_Active := v_Params.get_Number('only_active');
      End If;
    Exception
      When others Then
        v_Only_Active := 0;
    End;

    For i In (Select t.user_id,
                     t.position,
                     t.name,
                     t.order_by,
                     t.added_on,
                     t.expired_on,
                     (Select Count(*) From pi_committee_member_votes v
                       Where v.user_id = t.user_id) votes_count
                From pi_s_committee_members t
               Where (v_Only_Active = 0
                      Or (nvl(t.added_on, Sysdate - 1) <= Sysdate
                          And nvl(t.expired_on, Sysdate + 1) >= Sysdate))
               Order By t.order_by)
    Loop
      v_Data := json_object_t();
      v_Data.put('user_id',     i.user_id);
      v_Data.put('position',    i.position);
      v_Data.put('name',        i.name);
      v_Data.put('order_by',    i.order_by);
      v_Data.put('added_on',    to_char(i.added_on, 'dd.mm.yyyy'));
      v_Data.put('expired_on',  to_char(i.expired_on, 'dd.mm.yyyy'));
      v_Data.put('votes_count', i.votes_count);
      v_Data.put('is_active',
                 Case When nvl(i.added_on, Sysdate - 1) <= Sysdate
                       And nvl(i.expired_on, Sysdate + 1) >= Sysdate
                      Then 1 Else 0 End);

      v_Datas.append(v_Data);
    End Loop;

    v_Response.put('members', v_Datas);
    v_Response.put('oper', False);

    o_Response := v_Response.to_clob;
  End;

  --Cr By: Arslonbek Kulmatov
  --Qo'mita a'zolari tartibini o'zgartirish (drag&drop)
  Procedure member_reorder(p_Request Clob, o_Response Out Clob)
  Is
    v_Json     json_object_t := json_object_t.parse(p_Request);
    v_Response json_object_t := json_object_t();
    v_Params   json_object_t := v_Json.get_Object('params');
    v_Ids      json_array_t;
    v_User_Id  Number(20) := core_session.get_user_id();
    v_Count    Number(5);

    Type t_Num_Tab Is Table Of Number;
    v_Members  t_Num_Tab := t_Num_Tab();
    v_Orders   t_Num_Tab := t_Num_Tab();
    v_Neg      t_Num_Tab := t_Num_Tab();
  Begin
    --1. Ruxsat (faqat administrator)
    Select Count(*)
      Into v_Count
      From core_user_roles t
     Where t.role_id = 6
       And t.user_id = v_User_Id;

    If v_Count = 0 Then
      Pi_Util.Raise_Error('У вас нет доступа к этим действиям!');
    End If;

    --2. Ro'yxatni olish
    Pi_Util.Check_For_Existance(v_Params, 'ids');
    v_Ids := v_Params.get_Array('ids');

    If v_Ids.Get_Size = 0 Then
      Pi_Util.Raise_Error('Список пуст.');
    End If;

    v_Members.extend(v_Ids.Get_Size);
    v_Orders.extend(v_Ids.Get_Size);
    v_Neg.extend(v_Ids.Get_Size);

    For i In 0 .. v_Ids.Get_Size - 1 Loop
      v_Members(i + 1) := v_Ids.get_Number(i);
      v_Orders(i + 1)  := i + 1;
      v_Neg(i + 1)     := -1 * (i + 1);
    End Loop;

    --3. Dublikat tekshiruvi
    For i In 1 .. v_Members.count Loop
      For j In i + 1 .. v_Members.count Loop
        If v_Members(i) = v_Members(j) Then
          Pi_Util.Raise_Error('Дубликат user_id = '||v_Members(i));
        End If;
      End Loop;
    End Loop;

    --4. Barcha a'zolar mavjudmi
    For i In 1 .. v_Members.count Loop
      Select Count(*)
        Into v_Count
        From pi_s_committee_members t
       Where t.user_id = v_Members(i);

      If v_Count = 0 Then
        Pi_Util.Raise_Error('Член комитета не найден: user_id = '||v_Members(i));
      End If;
    End Loop;

    --5. Butun ro'yxat kelganmi (yarim ro'yxat tartibni buzadi)
    Select Count(*) Into v_Count From pi_s_committee_members;

    If v_Count <> v_Members.count Then
      Pi_Util.Raise_Error('Нужно отправить весь список. В базе: '||v_Count||
                          ', отправлено: '||v_Members.count);
    End If;

    --6. History (eski holat)
    Insert Into pi_s_committee_members_his
      (user_id, position, name, order_by, added_on, expired_on,
       action, action_by, action_on)
    Select t.user_id, t.position, t.name, t.order_by, t.added_on, t.expired_on,
           'U', v_User_Id, Sysdate
      From pi_s_committee_members t;

    --7. Avval vaqtincha manfiy qiymat (order_by unique bo'lsa to'qnashmasligi uchun)
    Forall i In 1 .. v_Members.count
      Update pi_s_committee_members
         Set order_by = v_Neg(i)
       Where user_id = v_Members(i);

    --8. Haqiqiy qiymatlar
    Forall i In 1 .. v_Members.count
      Update pi_s_committee_members
         Set order_by = v_Orders(i)
       Where user_id = v_Members(i);

    Commit;

    v_Response.put('success', True);
    v_Response.put('oper', True);
    v_Response.put('updated', v_Members.count);
    v_Response.put('message', 'Порядок успешно обновлён!');

    o_Response := v_Response.to_clob;
  Exception
    When others Then
      Rollback;
      Pi_Util.Raise_Error(sqlerrm);
  End;

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

  -- -------------------------------------------------------------------------
  -- O'ZGARDI: endi sabab tarixiga ham yoziladi (write_absence_history).
  -- -------------------------------------------------------------------------
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

    -- Hozirgi holat (ro'yxat uchun)
    Update Pi_S_Committee_Members m
       Set m.current_reason = v_Reason,
           m.reason_from    = v_From,
           m.reason_to      = v_To,
           m.reason_note    = v_Note,
           m.reason_set_by  = v_User_Id,
           m.reason_set_on  = Sysdate
     Where m.user_id = v_Target;

    -- YANGI: tarix (o'tgan majlislar uchun)
    write_absence_history(v_Target, v_Reason, v_From, v_To, v_Note, v_User_Id);

    Commit;

    Select name_uz Into v_ReasonName
      From Pi_S_Committee_Absence_Reasons Where code = v_Reason;

    v_Resp.Put('success', True);
    v_Resp.Put('message', 'Holat yangilandi: ' || v_ReasonName);
    v_Resp.Put('reason',  v_Reason);
    o_Response := v_Resp.To_Clob();
  End set_member_reason;

  -- -------------------------------------------------------------------------
  -- O'ZGARDI: ovoz varaqasi endi MAJLIS SANASIDAGI holatni ko'rsatadi.
  --
  -- Ilgari sabab Sysdate bilan solishtirilardi, shuning uchun taътil
  -- tugagan kuni ertasiga eski varaqa "Кутилмоқда"ga aylanib qolardi.
  -- Endi sabab Pi_S_Committee_Member_Absences dan majlis sanasi uchun
  -- tanlanadi va Sysdate umuman ishlatilmaydi.
  --
  -- Majlis sanasi loop'dan oldin bir marta o'qiladi (ilgari har a'zo
  -- uchun qayta o'qilardi).
  -- -------------------------------------------------------------------------
  Procedure get_votes(p_Request Clob, o_Response Out Clob)
  Is
    v_Json       Json_Object_t := Json_Object_t.Parse(p_Request);
    v_Response   Json_Object_t := Json_Object_t();
    v_Params     Json_Object_t := v_Json.get_Object('params');
    v_Data       Json_Object_t;
    v_Datas      Json_Array_t  := Json_Array_t();
    v_Id         Number(20)    := v_Params.get_Number('id');
    v_Vote       Varchar2(128);
    v_Vote_On    Varchar2(64);
    v_Comments   Varchar2(2048);
    v_Reason     Varchar2(32);
    v_ReasonName Varchar2(128);
    v_Color      Varchar2(16);
    v_App_Date   Date;
    v_Row        Pi_Committees_V%Rowtype;
  Begin
    -- Majlis sanasi — barcha a'zolar uchun bitta
    Begin
      Select k.* Into v_Row
        From Pi_Committees_V k
       Where k.id = v_Id;
      v_App_Date := To_Date(v_Row.application_date, 'dd.mm.yyyy');
    Exception When Others Then
      v_App_Date := Trunc(Sysdate);
    End;
    If v_App_Date Is Null Then
      v_App_Date := Trunc(Sysdate);
    End If;

    For i In (Select m.user_id,
                     m.name,
                     m.position,
                     Nvl(m.added_on, To_Date('01.11.2025', 'dd.mm.yyyy')) added_on,
                     m.expired_on,
                     Nvl(ab.reason, 'PARTICIPATES') effective_reason,
                     ab.note                        effective_note
                From Pi_S_Committee_Members m
                Outer Apply (Select a.reason, a.note
                               From Pi_S_Committee_Member_Absences a
                              Where a.user_id = m.user_id
                                And a.date_from <= v_App_Date
                                And (a.date_to Is Null Or a.date_to >= v_App_Date)
                              Order By a.date_from Desc, a.id Desc
                              Fetch First 1 Row Only) ab
               Order By m.order_by) Loop

      -- A'zolik muddati majlis sanasini qamrab olmasa — ro'yxatga tushmaydi
      If i.added_on   Is Not Null And v_App_Date < i.added_on   Then Continue; End If;
      If i.expired_on Is Not Null And v_App_Date > i.expired_on Then Continue; End If;

      v_Reason := i.effective_reason;

      Begin
        Select name_uz, color
          Into v_ReasonName, v_Color
          From Pi_S_Committee_Absence_Reasons
         Where code = v_Reason;
      Exception When No_Data_Found Then
        v_ReasonName := 'Иштирок этади';
        v_Color      := 'success';
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
        v_Comments := i.effective_note;
      End If;

      v_Data := Json_Object_t();
      v_Data.Put('committee_id', v_Id);
      v_Data.Put('user_id',      i.user_id);
      v_Data.Put('user_name',    i.name);
      v_Data.Put('role',         i.position);
      v_Data.Put('vote',         v_Vote);
      v_Data.Put('vote_on',      v_Vote_On);
      v_Data.Put('comments',     v_Comments);
      v_Data.Put('reason',       v_Reason);
      v_Data.Put('reason_name',  v_ReasonName);
      v_Data.Put('reason_color', v_Color);
      v_Data.Put('is_voter',     Case When v_Reason = 'PARTICIPATES' Then 'Y' Else 'N' End);
      v_Datas.Append(v_Data);
    End Loop;

    v_Response.Put('votes', v_Datas);
    o_Response := v_Response.To_Clob();
  End get_votes;

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
             r.name_uz As reason_name, r.color As reason_color,
             (Select Count(*)
                From Pi_Committee_Member_Votes cv
               Where cv.user_id = v.user_id) As votes_count
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
      v_Row.Put('votes_count',  m.votes_count);
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

  -- -------------------------------------------------------------------------
  -- O'ZGARDI: reason qo'yilganda sabab tarixiga ham yoziladi (9-qadamdan keyin).
  -- -------------------------------------------------------------------------
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
    v_Reason_Sent  Boolean       := False;
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

      -- 6. Hozirgi holat (reason) maydonlari
      If v_Params.has('reason') And v_Params.get_String('reason') Is Not Null Then
        v_Reason_Sent := True;
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

      -- 10. YANGI: sabab tarixiga yozish (o'tgan majlislar uchun)
      If v_Reason_Sent Then
        write_absence_history(v_Row.User_Id, v_Row.Current_Reason,
                              v_Row.Reason_From, v_Row.Reason_To,
                              v_Row.Reason_Note, v_User_Id);
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

      -- Sabab tarixi ataylab O'CHIRILMAYDI: eski ovoz varaqalari
      -- a'zo o'chirilgandan keyin ham to'g'ri chiqishi kerak.

      v_Response.put('message', 'Данные успешно удалены!');
    Else
      Pi_Util.Raise_Error('Noto''g''ri action: ' || v_Action);
    End If;
    Commit;

    v_Response.put('success', True);
    o_Response := v_Response.to_clob;
  End member_ref_action;

End;
/
