-- =============================================================================
-- IPT_TRADE_GRAPH_PAYMENTS_V2 — som to'lovlar bilan
--
-- PAID_AMOUNT ENDI VALYUTAGA QARAB O'ZGARADI
--     som sdelkasi  (currency_code = 860) -> SOM
--     dollar sdelkasi (840)               -> DOLLAR
--
--   Front tegilmasligi uchun shunday qilindi: grid o'sha ustunni o'qiydi,
--   qiymat esa to'g'ri valyutada keladi.
--
--   >>> DIQQAT: bu ustunni YIG'IB BO'LMAYDI. <<<
--   sum(paid_amount) dollar va somni qo'shib yuboradi va ma'nosiz raqam
--   beradi. Yig'indi kerak bo'lsa paid_amount_usd yoki paid_amount_uzs
--   ishlatilsin, currency_code bo'yicha ajratib.
--
-- USTUN TARTIBI
--   Dastlabki beshta ustun O'Z O'RNIDA va o'z nomida qoldi:
--     trade_id, paid_amount, paid_date, cr_by, paid_dt
--   Yangilari OXIRIGA qo'shildi, shuning uchun pozitsiya bo'yicha o'qiydigan
--   grid ham buzilmaydi:
--     currency_code, paid_amount_usd, paid_amount_uzs
--
--   paid_amount_usd — dollar qiymati hech qayerga yo'qolmasin uchun.
--   Eski hisobotlar unga o'tsa, valyuta aralashmaydi.
--
-- SOM QAYERDAN
--   Bitta to'lov bir necha grafik qatoriga taqsimlanishi mumkin. Dollar
--   summasi onetime_total_payment da bir marta yotadi, som esa qatorlarga
--   bo'lingan — shuning uchun sum(paid_amount_uzs).
--
--   Add_Paid_Amounts qoldiqni oxirgi qatorga berib bo'ladi, ya'ni yig'indi
--   mijoz haqiqatan to'lagan summaga AYNAN teng.
--
-- BUNDAN OLDIN: db/ipt_paid_amounts_uzs_backfill.sql ni bajaring.
--   Aks holda somga o'tkazilgan eski sdelkalarda paid_amount_uzs bo'sh va
--   paid_amount NOL bo'lib ko'rinadi — dollar qiymati ham yo'qoladi.
--
-- Muallif: Arslonbek Kulmatov
-- Sana   : 23.09.2026
-- =============================================================================

create or replace view IPT_TRADE_GRAPH_PAYMENTS_V2 as
select x.trade_id,
       -- Valyutaga qarab almashadi. Yig'ib bo'lmaydi — yuqoridagi izohga qarang.
       case when nvl(tr.currency_code, '840') = '860'
            then x.paid_amount_uzs
            else x.paid_amount
       end                          paid_amount,
       x.paid_date,
       x.cr_by,
       x.paid_dt,
       -- --- yangilari, oxirida ---
       nvl(tr.currency_code, '840') currency_code,
       x.paid_amount                paid_amount_usd,
       -- Dollar sdelkasida som tushunchasi yo'q: 0 emas, NULL.
       -- 0 yozilsa "nol som to'lagan" degan ma'no chiqadi.
       case when nvl(tr.currency_code, '840') = '860'
            then x.paid_amount_uzs
       end                          paid_amount_uzs
  from (select min(t.trade_id) trade_id,
               nvl((t.onetime_total_payment/100), -min(t.paid_amount/100)) paid_amount,
               -- To'lov: qatorlarga taqsimlangan som yig'indisi.
               -- Bekor qilish (onetime_total_payment yo'q): bitta qator,
               -- dollar tomoni kabi manfiy ko'rsatiladi.
               case when t.onetime_total_payment is not null
                    then sum(t.paid_amount_uzs)/100
                    else -min(t.paid_amount_uzs)/100
               end paid_amount_uzs,
               to_char(min(t.paid_date), 'dd.mm.yyyy') paid_date,
               min(t.cr_by)||'-'||core_user.Get_User_Name(p_User_Id => min(t.cr_by)) cr_by,
               min(t.paid_date) paid_dt
          from ipt_trade_graph_paid_amounts t
         group by t.onetime_total_payment,
                  t.cr_on) x
  left join ipt_trades tr
    on tr.id = x.trade_id
 order by x.paid_dt desc
;

-- =============================================================================
-- TEKSHIRISH
--
-- 1. Som sdelkalari — paid_amount somda chiqishi kerak
--
--    select trade_id, paid_amount, paid_amount_usd, currency_code, paid_date
--      from ipt_trade_graph_payments_v2
--     where currency_code = '860'
--     order by paid_dt desc
--     fetch first 20 rows only;
--
-- 2. Dollar sdelkalari — paid_amount va paid_amount_usd teng, som bo'sh
--
--    select trade_id, paid_amount, paid_amount_usd, paid_amount_uzs
--      from ipt_trade_graph_payments_v2
--     where currency_code = '840'
--     fetch first 10 rows only;
--
-- 3. Bitta som sdelkasi grafik bilan mos kelishi
--
--    select sum(v.paid_amount_uzs) tolovlarda,
--           (select sum(g.paid_amount_uzs)/100
--              from ipt_trade_graphs g where g.trade_id = &&trade_id) grafikda
--      from ipt_trade_graph_payments_v2 v
--     where v.trade_id = &&trade_id;
--
-- =============================================================================
-- MA'LUM CHEKLOV (bu view'da avvaldan bor, men kiritmadim)
--
--   Guruhlash (onetime_total_payment, cr_on) bo'yicha ketadi. Ikkita
--   BEKOR QILISH bir soniyada bajarilsa (ikkalasida ham
--   onetime_total_payment NULL), ular bitta qator bo'lib qo'shilib ketadi
--   va summasi min() tufayli kam ko'rsatiladi.
--
--   Amalda deyarli uchramaydi. To'g'ri yechim — guruhlashni paid_amounts
--   ning o'z id si yoki alohida "to'lov hujjati" raqami bo'yicha qilish.
--   Kerak bo'lsa aytilsin, alohida qilib beraman.
-- =============================================================================
