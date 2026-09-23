-- =============================================================================
-- SOM SDELKALARIDA TO'LOV QATORLARINI TO'LDIRISH
--   paid_amount_uzs, course_usd, rate_diff_amount
--
-- MUAMMO
--   Convert_Trade_To_Uzs va Fix_Trade_Course ipt_trade_graphs ni to'ldiradi
--   (payment_amount_uzs, paid_amount_uzs, course_usd), lekin
--   ipt_trade_graph_paid_amounts ga TEGMAYDI. Shuning uchun o'tkazishdan
--   OLDIN qabul qilingan to'lovlarda uchala ustun ham bo'sh qoladi.
--
-- MANBA — IPT_TRADE_GRAPHS
--   Grafik qatorida som ham, kurs ham allaqachon to'g'ri turibdi. Qayta
--   hisoblash o'rniga o'shandan olamiz: shunda to'lov qatorlari grafik
--   bilan AYNAN mos tushadi va hisobotda farq chiqmaydi.
--
--   Kurs tartibi Add_Paid_Amounts dagi bilan bir xil:
--       nvl(g.course_usd, t.course_usd)
--
-- COURSE_USD HAQIDA BIR IZOH
--   Ustun izohi "to'lov kunidagi kurs" deydi. Biz grafik kursini yozamiz —
--   to'lov kunidagisini hech kim saqlamagan. Foydasi shunda: qator
--   o'z-o'zini tekshiradigan bo'ladi, ya'ni
--       paid_amount_uzs / course_usd * 100 = paid_amount + rate_diff_amount
--   Natively som sdelkalarida bu ikkisi ataylab har xil (biri grafik, biri
--   bugungi kurs) — shuning uchun eski qatorlarni bu bilan chalkashtirmang.
--
-- RATE_DIFF_AMOUNT
--   9202-sdelkaning 1-qatorida: dollarda 356.00$ yozilgan, som esa
--   4 280 000 — u grafik kursida 359.66$ turadi. Farq 3.66$.
--   Bu farq hozir HECH QAYERDA yozilmagan. 5-bo'lim uni rate_diff_amount
--   ga qo'yadi (manfiy = rasxod, Apply_Rate_Difference bilan bir xil ishora).
--
--   5-bo'lim ALOHIDA va ixtiyoriy: farqni qayd etmaslik ham mumkin, u holda
--   0 bo'lib qolaveradi.
--
-- TARIX YO'Q
--   Jadvalning _his nusxasi yo'q. 2-bo'limni o'tkazib yubormang.
--
-- TARTIB: 1 → 2 → 3 → 4 → (5 ixtiyoriy) → 6
--   1-bo'lim hech narsa yozmaydi, faqat ko'rsatadi.
--
-- Muallif: Arslonbek Kulmatov
-- Sana   : 23.09.2026
-- =============================================================================

prompt 1.1 Nechta qator to'ldiriladi

select t.id                     trade_id,
       count(*)                 tolov_qatori,
       sum(p.paid_amount) / 100 jami_usd,
       min(g.course_usd) / 100  kurs
  from ipt_trade_graph_paid_amounts p
  join ipt_trades t
    on t.id = p.trade_id
  left join ipt_trade_graphs g
    on  g.trade_id  = p.trade_id
    and g.order_num = p.graph_order_num
 where nvl(t.currency_code, '840') = '860'
   and nvl(p.paid_amount_uzs, 0) = 0
   and nvl(p.paid_amount, 0) <> 0
 group by t.id
 order by t.id;

prompt 1.2 Kursi yo'q — bularni to'ldirib bo'lmaydi

-- Chiqsa: avval o'sha sdelkalarning kursini aniqlang. Kurssiz qator
-- 3-bo'limda chetlab o'tiladi, jimgina noto'g'ri yozilmaydi.
select distinct p.trade_id
  from ipt_trade_graph_paid_amounts p
  join ipt_trades t
    on t.id = p.trade_id
  left join ipt_trade_graphs g
    on  g.trade_id  = p.trade_id
    and g.order_num = p.graph_order_num
 where nvl(t.currency_code, '840') = '860'
   and nvl(p.paid_amount_uzs, 0) = 0
   and nvl(p.paid_amount, 0) <> 0
   and nvl(nvl(g.course_usd, t.course_usd), 0) <= 0;

prompt 1.3 Grafikda som va dollar tomoni mos kelmaydigan qatorlar

-- Bu 5-bo'limga kiradigan farq. Katta farqlar shu yerda ko'rinadi.
-- 9202-sdelkada 1-qator 3.66$ farq beradi.
select g.trade_id,
       g.order_num,
       g.paid_amount / 100                                          dollarda,
       g.paid_amount_uzs / 100                                      somda,
       ipt_util.Uzs_To_Usd(g.paid_amount_uzs, g.course_usd) / 100   som_dollarda,
       (g.paid_amount
        - ipt_util.Uzs_To_Usd(g.paid_amount_uzs, g.course_usd)) / 100 farq_usd
  from ipt_trade_graphs g
  join ipt_trades t
    on t.id = g.trade_id
 where nvl(t.currency_code, '840') = '860'
   and nvl(g.paid_amount, 0) <> 0
   and nvl(g.course_usd, 0) > 0
   and g.paid_amount <> ipt_util.Uzs_To_Usd(g.paid_amount_uzs, g.course_usd)
 order by abs(g.paid_amount
              - ipt_util.Uzs_To_Usd(g.paid_amount_uzs, g.course_usd)) desc;

prompt 1.4 Yopilgan, lekin dollarda to'lanmagan qatorlar

-- Konversiya payment_amount ni qayta hisoblagan bo'lsa, o'shanda yopilgan
-- qator endi "to'lanmagan" bo'lib ko'rinishi mumkin: state = 1, lekin
-- paid_amount < payment_amount.
--
-- 9202-sdelkaning 1-qatori shunga o'xshaydi: state = 1, paid_amount 356.00$,
-- som tomoni esa 359.66$ ga to'g'ri keladi.
--
-- Chiqqan qatorlar buzilgan degani EMAS — to'lov o'sha paytda to'g'ri
-- yopilgan, keyin summalar qayta yozilgan. Lekin qarz hisobida ular
-- "yetmayapti" bo'lib chiqishi mumkin, shuning uchun ko'rib qo'ying.
select g.trade_id,
       g.order_num,
       g.state,
       g.payment_amount / 100     kerak_usd,
       g.paid_amount / 100        tolangan_usd,
       (g.payment_amount - g.paid_amount) / 100 farq_usd,
       g.payment_amount_uzs / 100 kerak_som,
       g.paid_amount_uzs / 100    tolangan_som
  from ipt_trade_graphs g
  join ipt_trades t
    on t.id = g.trade_id
 where nvl(t.currency_code, '840') = '860'
   and g.state = 1
   and nvl(g.paid_amount, 0) < nvl(g.payment_amount, 0)
 order by (g.payment_amount - g.paid_amount) desc;

prompt 1.5 Nima yozilishini oldindan ko'rish

select p.id,
       p.trade_id,
       p.graph_order_num,
       p.dc_sign,
       p.paid_amount / 100                                        usd,
       nvl(g.course_usd, t.course_usd) / 100                      kurs,
       ipt_util.Usd_To_Uzs(p.paid_amount,
                           nvl(g.course_usd, t.course_usd)) / 100 yoziladigan_som
  from ipt_trade_graph_paid_amounts p
  join ipt_trades t
    on t.id = p.trade_id
  left join ipt_trade_graphs g
    on  g.trade_id  = p.trade_id
    and g.order_num = p.graph_order_num
 where nvl(t.currency_code, '840') = '860'
   and nvl(p.paid_amount_uzs, 0) = 0
   and nvl(p.paid_amount, 0) <> 0
   and nvl(nvl(g.course_usd, t.course_usd), 0) > 0
 order by p.trade_id, p.graph_order_num, p.cr_on;


prompt 2. Eski qiymatlarni saqlash — MAJBURIY

create table ipt_tgpa_uzs_backup as
select p.id,
       p.trade_id,
       p.graph_order_num,
       p.dc_sign,
       p.paid_amount,
       p.paid_amount_uzs  old_paid_amount_uzs,
       p.course_usd       old_course_usd,
       p.rate_diff_amount old_rate_diff_amount,
       sysdate            saved_on
  from ipt_trade_graph_paid_amounts p
  join ipt_trades t
    on t.id = p.trade_id
 where nvl(t.currency_code, '840') = '860'
   and nvl(p.paid_amount_uzs, 0) = 0
   and nvl(p.paid_amount, 0) <> 0;

select count(*) saqlandi from ipt_tgpa_uzs_backup;


prompt 3. paid_amount_uzs va course_usd

-- Faqat BO'SH qatorlar. To'g'ri to'ldirilganlariga tegilmaydi: natively som
-- sdelkasida paid_amount_uzs mijoz haqiqatan to'lagan summa.
merge into ipt_trade_graph_paid_amounts d
using (
  select p.id                                                  row_id,
         ipt_util.Usd_To_Uzs(p.paid_amount,
                             nvl(g.course_usd, t.course_usd))  uzs,
         nvl(g.course_usd, t.course_usd)                       crs
    from ipt_trade_graph_paid_amounts p
    join ipt_trades t
      on t.id = p.trade_id
    left join ipt_trade_graphs g
      on  g.trade_id  = p.trade_id
      and g.order_num = p.graph_order_num
   where nvl(t.currency_code, '840') = '860'
     and nvl(p.paid_amount_uzs, 0) = 0
     and nvl(p.paid_amount, 0) <> 0
     and nvl(nvl(g.course_usd, t.course_usd), 0) > 0
) s
on (d.id = s.row_id)
when matched then
  update set d.paid_amount_uzs = s.uzs,
             d.course_usd      = nvl(d.course_usd, s.crs);

commit;


prompt 4.1 Grafik bilan farqni ko'rish

-- Har qatorni alohida yaxlitlash yig'indini bir necha tiyinga suradi.
-- Farq KICHIK bo'lsa — 4.2 ni bajaring.
-- Farq KATTA bo'lsa — 4.2 ni BAJARMANG, avval sababini toping.
select p.trade_id,
       p.graph_order_num,
       g.paid_amount_uzs / 100                                     grafikda_som,
       sum(case when p.dc_sign = 4 then p.paid_amount_uzs
                else -p.paid_amount_uzs end) / 100                 tolovlarda_som,
       (g.paid_amount_uzs
        - sum(case when p.dc_sign = 4 then p.paid_amount_uzs
                   else -p.paid_amount_uzs end)) / 100             farq_som
  from ipt_trade_graph_paid_amounts p
  join ipt_trades t
    on t.id = p.trade_id
  join ipt_trade_graphs g
    on  g.trade_id  = p.trade_id
    and g.order_num = p.graph_order_num
 where nvl(t.currency_code, '840') = '860'
 group by p.trade_id, p.graph_order_num, g.paid_amount_uzs
having g.paid_amount_uzs <> sum(case when p.dc_sign = 4 then p.paid_amount_uzs
                                     else -p.paid_amount_uzs end)
 order by abs(g.paid_amount_uzs
              - sum(case when p.dc_sign = 4 then p.paid_amount_uzs
                         else -p.paid_amount_uzs end)) desc;

prompt 4.2 Qoldiqni oxirgi to'lovga berib, grafikka tenglashtirish

-- Add_Paid_Amounts dagi naqsh: qoldiq oxirgi qatorga beriladi.
merge into ipt_trade_graph_paid_amounts d
using (
  select x.last_id, x.diff
    from (select max(p.id) keep (dense_rank last order by p.cr_on, p.id) last_id,
                 g.paid_amount_uzs
                 - sum(case when p.dc_sign = 4 then p.paid_amount_uzs
                            else -p.paid_amount_uzs end)                  diff
            from ipt_trade_graph_paid_amounts p
            join ipt_trades t
              on t.id = p.trade_id
            join ipt_trade_graphs g
              on  g.trade_id  = p.trade_id
              and g.order_num = p.graph_order_num
           where nvl(t.currency_code, '840') = '860'
             and p.dc_sign = 4
           group by p.trade_id, p.graph_order_num, g.paid_amount_uzs) x
   where x.diff <> 0
) s
on (d.id = s.last_id)
when matched then
  update set d.paid_amount_uzs = d.paid_amount_uzs + s.diff;

commit;


prompt 5. rate_diff_amount — IXTIYORIY, avval o'qing

-- NIMA YOZILADI
--   rate_diff = paid_amount - Uzs_To_Usd(paid_amount_uzs, course_usd)
--
--   Ya'ni: dollarda qancha yozilgan MINUS o'sha som grafik kursida qancha
--   turadi. Manfiy = rasxod, musbat = prixod — Apply_Rate_Difference bilan
--   bir xil ishora.
--
--   9202-sdelka, 1-qator: 356.00 - 359.66 = -3.66$ (rasxod).
--
-- NEGA FAQAT dc_sign = 4
--   Bekor qilish qatorlarida (dc_sign = 1) farqning ishorasi teskari
--   bo'lishi kerak va uning qoidasi Minus_Paid_Amounts da boshqacha.
--   Taxmin qilmaslik uchun ular 0 bo'lib qoladi. Kerak bo'lsa aytilsin.
--
-- BU SALDOGA TEGMAYDI
--   Faqat qatorga qayd etiladi. Investor qoldig'i o'zgarmaydi — chunki
--   o'sha paytda haqiqatan dollar tushgan va u allaqachon hisobga olingan.
--   Agar farq saldoga ham tushishi kerak bo'lsa — bu alohida ish, ayting.
merge into ipt_trade_graph_paid_amounts d
using (
  select p.id row_id,
         p.paid_amount
         - ipt_util.Uzs_To_Usd(p.paid_amount_uzs, p.course_usd) diff
    from ipt_trade_graph_paid_amounts p
    join ipt_trades t
      on t.id = p.trade_id
   where nvl(t.currency_code, '840') = '860'
     and p.dc_sign = 4
     and nvl(p.rate_diff_amount, 0) = 0
     and nvl(p.paid_amount_uzs, 0) <> 0
     and nvl(p.course_usd, 0) > 0
     and p.paid_amount <> ipt_util.Uzs_To_Usd(p.paid_amount_uzs, p.course_usd)
) s
on (d.id = s.row_id)
when matched then
  update set d.rate_diff_amount = s.diff;

commit;


prompt 6.1 Bo'sh qolgan qator bormi

select count(*) tuldirilmagan
  from ipt_trade_graph_paid_amounts p
  join ipt_trades t
    on t.id = p.trade_id
 where nvl(t.currency_code, '840') = '860'
   and nvl(p.paid_amount_uzs, 0) = 0
   and nvl(p.paid_amount, 0) <> 0;

prompt 6.2 Bitta sdelkani ko'z bilan ko'rish

select p.graph_order_num,
       p.paid_date,
       p.dc_sign,
       p.paid_amount / 100      usd,
       p.paid_amount_uzs / 100  som,
       p.course_usd / 100       kurs,
       p.rate_diff_amount / 100 kurs_farqi
  from ipt_trade_graph_paid_amounts p
 where p.trade_id = &&trade_id
 order by p.graph_order_num, p.cr_on;

-- =============================================================================
-- ORQAGA QAYTARISH
--
--   merge into ipt_trade_graph_paid_amounts d
--   using (select id, old_paid_amount_uzs, old_course_usd, old_rate_diff_amount
--            from ipt_tgpa_uzs_backup) s
--   on (d.id = s.id)
--   when matched then
--     update set d.paid_amount_uzs   = s.old_paid_amount_uzs,
--                d.course_usd        = s.old_course_usd,
--                d.rate_diff_amount  = s.old_rate_diff_amount;
--   commit;
--
-- Hammasi joyida bo'lsa, bir necha kundan keyin:
--   drop table ipt_tgpa_uzs_backup;
-- =============================================================================
