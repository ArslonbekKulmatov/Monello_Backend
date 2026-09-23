-- =============================================================================
-- IPT_TRADE_GRAPH_PAYMENTS_V2 — som to'lovlar bilan
--
-- NIMA O'ZGARDI
--   Uchta ustun qo'shildi, mavjudlariga TEGILMADI:
--     paid_amount_uzs — to'lov somda (faqat som sdelkalarida)
--     currency_code   — 840 (dollar) yoki 860 (som)
--     trade_id        — endi tashqi so'rovda, avvalgidek qaytadi
--
--   Mavjud ustunlar o'z tartibida va o'z nomida qoldi, shuning uchun
--   hozirgi gridlar buzilmaydi.
--
-- SOM QAYERDAN
--   Bitta to'lov bir necha grafik qatoriga taqsimlanishi mumkin. Dollar
--   summasi onetime_total_payment da bir marta yotadi, som esa qatorlarga
--   bo'lingan — shuning uchun sum(paid_amount_uzs).
--
--   Add_Paid_Amounts qoldiqni oxirgi qatorga berib bo'ladi, ya'ni yig'indi
--   mijoz haqiqatan to'lagan summaga AYNAN teng.
--
-- NEGA NULL, 0 EMAS
--   Dollar sdelkasida som tushunchasi yo'q. 0 yozilsa "nol som to'lagan"
--   degan ma'no chiqadi va yig'indilarni buzadi. NULL — "bu yerda som yo'q".
--
-- NEGA BITTA USTUNGA QO'SHIB YUBORILMADI
--   "Som bo'lsa som, aks holda dollar" degan yagona ustun qulay ko'rinadi,
--   lekin uning yig'indisi ma'nosiz bo'ladi: dollar va som qo'shiladi.
--   Grid qaysi birini ko'rsatishni currency_code bo'yicha hal qiladi.
--
-- BUNDAN OLDIN: db/ipt_paid_amounts_uzs_backfill.sql ni bajaring.
--   Aks holda somga o'tkazilgan eski sdelkalarda paid_amount_uzs bo'sh
--   bo'lgani uchun to'lovlar somda ko'rinmaydi.
--
-- Muallif: Arslonbek Kulmatov
-- Sana   : 23.09.2026
-- =============================================================================

create or replace view IPT_TRADE_GRAPH_PAYMENTS_V2 as
select x.trade_id,
       x.paid_amount,
       -- Som faqat som sdelkasida. Sabab yuqorida.
       case when nvl(tr.currency_code, '840') = '860'
            then x.paid_amount_uzs
       end                          paid_amount_uzs,
       nvl(tr.currency_code, '840') currency_code,
       x.paid_date,
       x.cr_by,
       x.paid_dt
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
--   select trade_id, paid_amount, paid_amount_uzs, currency_code, paid_date
--     from ipt_trade_graph_payments_v2
--    where currency_code = '860'
--    order by paid_dt desc
--    fetch first 20 rows only;
--
--   Bitta som sdelkasi bo'yicha yig'indi grafik bilan mos kelishi:
--
--   select sum(v.paid_amount_uzs) tolovlarda,
--          (select sum(g.paid_amount_uzs)/100
--             from ipt_trade_graphs g where g.trade_id = &&trade_id) grafikda
--     from ipt_trade_graph_payments_v2 v
--    where v.trade_id = &&trade_id;
--
-- =============================================================================
-- MA'LUM CHEKLOV (bu view'da avvaldan bor, men kiritmadim)
--
--   Guruhlash (onetime_total_payment, cr_on) bo'yicha ketadi. Ikkita
--   BEKOR QILISH bir soniyada bajarilsa (ikkalasida ham
--   onetime_total_payment NULL), ular bitta qator bo'lib qo'shilib
--   ketadi va summasi min() tufayli kam ko'rsatiladi.
--
--   Amalda deyarli uchramaydi. To'g'ri yechim — guruhlashni paid_amounts
--   ning o'z id si yoki alohida "to'lov hujjati" raqami bo'yicha qilish.
--   Kerak bo'lsa aytilsin, alohida qilib beraman.
-- =============================================================================
