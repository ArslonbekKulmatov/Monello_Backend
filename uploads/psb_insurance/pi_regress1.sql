declare
o_Error_Msg varchar2(2000);
o_Error_Code varchar2(2000);
begin
  -- Call the procedure
  Setup.Set_Employee_Code@Ibsdblink(Dbo_Util.Get_Joyda_user('00440'));
  Gl_Request_Sender.Get_Real_Card@Ibsdblink(i_Card_Id => 605790,
                                  o_Error_Code => o_Error_Msg,
                                  o_Error_Msg => o_Error_Msg);
                                  dbms_output.put_line(o_Error_Msg);
end;

declare
v_Err_Code varchar2(1000);
v_Err_Msg  varchar2(4000);
begin
  Setup.Set_Employee_Code@Ibsdblink(Dbo_Util.Get_Joyda_user('00440'));
  Gl_Request_Sender.Set_Sms_Service@Ibsdblink(137425,
                                              '+998946436468',
                                              'on',
                                              v_Err_Code,
                                              v_Err_Msg);
                                              dbms_output.put_line(v_Err_Msg);
end;

 declare
 v_Err_Code varchar2(1000);
v_Err_Msg  varchar2(4000);
 begin
   Setup.Set_Employee_Code@Ibsdblink(Dbo_Util.Get_Joyda_user('00440'));
   Gl_Request_Sender.Reset_Pin_Counter@Ibsdblink(605790,
                                                 '',
                                                 v_Err_Code,
                                                 v_Err_Msg);
 end;