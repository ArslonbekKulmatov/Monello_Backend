Select * From alr_debited_amounts_log_his t where t.card_number like '%2937'
 and trunc(t.cr_on) = trunc(sysdate - 1)
 order by t.cr_on desc
 
 
select t.*, t.rowid from ALR_LOG_his t
 where t.request like '%9860020128252937%'
 and trunc(t.cr_on) = trunc(sysdate - 1) 


select 
  t.method,
  dbms_lob.substr(t.request, 4000, 1) request,
  dbms_lob.substr(t.response, 4000, 1) response,
  t.cr_on,
  t.up_on
  from ALR_LOG_his t
 where t.response like '%{"data":{},"success":true,"error":{"code":0,"message":"211 GuzzleHttp\\Exception\\ServerException: Server error: `POST http:\/\/192.168.35.150:11215` resulted in a `504 Gateway Time-out` response:\n<html><body><h1>504 Gateway Time-out<\/h1>\nThe server didn%'
 and trunc(t.cr_on) = trunc(sysdate - 1) 
