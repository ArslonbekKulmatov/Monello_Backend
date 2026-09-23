-- =============================================================================
-- SOM SDELKALARIDAGI TO'LOVLARGA SOM QIYMATINI TO'LDIRISH
--
-- MUAMMO
--   Convert_Trade_To_Uzs sdelkani somga o'tkazganda ipt_trade_graphs ni
--   to'ldiradi (payment_amount_uzs, paid_amount_uzs), lekin
--   ipt_trade_graph_paid_amounts ga TEGMAYDI. Fix_Trade_Course ham shunday.
--
--   Natijada o'tkazishdan OLDIN qabul qilingan to'lovlarda
--   paid_amount_uzs = 0 bo'lib qoladi va ular somda ko'rsatilmaydi.
--
-- QAYSI KURS ISHLATILADI
--   Grafik qatorining kursi, u bo'lmasa sdelkaniki:
--       nvl(g.course_usd, t.course_usd)
--   Add_Paid_Amounts dagi vGraph_Course bilan AYNAN bir xil tartib.
--
--   Nega to'lov kunidagi tarixiy kurs emas: u holda qatorlar yig'indisi
--   ipt_trade_graphs.paid_amount_uzs ga teng kelmaydi va hisobotda
--   tushunarsiz farq chiqadi. Grafik kursi bilan hamma narsa o'zaro mos.
--
--   DIQQAT: bu QAYTA QURISH, o'lchov emas. O'sha paytda mijoz haqiqatan
--   qancha som to'lagani saqlanmagan — sdelka o'shanda dollarda edi.
--
-- COURSE_USD GA TEGILMAYDI
--   Ustun izohi: "tulov kunidagi kurs". Biz grafik kursini bilamiz, to'lov
--   kunidagisini emas. Grafik kursini u yerga yozish ustunni yolg'onga
--   aylantiradi, shuning uchun NULL qoldiriladi.
--
--   Bu ikkisi natively som sdelkalarida ham bir xil emas: Add_Paid_Amounts
--   paid_amount_uzs ni GRAFIK kursida hisoblaydi, course_usd ga esa
--   BUGUNGI kursni yozadi. Ular ataylab har xil — kurs farqi shundan chiqadi.
--
-- TARIX YO'Q
--   Bu jadvalning _his nusxasi yo'q. Shuning uchun 2-bo'limda eski
--   qiymatlar alohida jadvalga saqlanadi. Uni o'tkazib yubormang.
--
-- TARTIB: 1 → 2 → 3 → (4 ixtiyoriy) → 5
--
-- Muallif: Arslonbek Kulmatov
-- Sana   : 23.09.2026
-- =============================================================================

prompt 1.1 Nechta qator to'ldiriladi

select t.id                         trade_id,
       t.course_usd / 100           sdelka_kursi,
       count(*)                     tolov_qatori,
       sum(p.paid_amount) / 100     jami_usd
  from ipt_trade_graph_paid_amounts p
  join ipt_trades t
    on t.id = p.trade_id
 where nvl(t.currency_code, '840') = '860'
   and nvl(p.paid_amount_uzs, 0) = 0
   and nvl(p.paid_amount, 0) <> 0
 group by t.id, t.course_usd
 order by t.id;

prompt 1.2 Kursi yo'q sdelkalar — bularni to'ldirib bo'lmaydi

-- Chiqsa: avval o'sha sdelkalarning kursini aniqlang. Kurssiz qator
-- 3-bo'limda ham chetlab o'tiladi, ya'ni jimgina noto'g'ri yozilmaydi.
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

prompt 1.3 Nima yozilishini oldindan ko'rish

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

-- Jadvalda tarix nusxasi yo'q. Bu yagona orqaga qaytish yo'li.
create table ipt_tgpa_uzs_backup as
select p.id,
       p.trade_id,
       p.graph_order_num,
       p.paid_amount,
       p.paid_amount_uzs old_paid_amount_uzs,
       p.course_usd      old_course_usd,   -- tegilmaydi, faqat qayd uchun
       sysdate           saved_on
  from ipt_trade_graph_paid_amounts p
  join ipt_trades t
    on t.id = p.trade_id
 where nvl(t.currency_code, '840') = '860'
   and nvl(p.paid_amount_uzs, 0) = 0
   and nvl(p.paid_amount, 0) <> 0;

select count(*) saqlandi from ipt_tgpa_uzs_backup;


prompt 3. To'ldirish

-- Faqat BO'SH qatorlar to'ldiriladi. To'g'ri to'ldirilganlariga tegilmaydi:
-- somda ochilgan sdelkalarda paid_amount_uzs mijoz haqiqatan to'lagan
-- summa va uni qayta hisoblash xato bo'lardi.
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
  update set d.paid_amount_uzs = s.uzs;

commit;


prompt 4.1 Yaxlitlash farqini ko'rish — IXTIYORIY BO'LIMNING TEKSHIRUVI

-- Har qatorni alohida yaxlitlash yig'indini bir necha tiyinga surishi
-- mumkin. Quyidagi so'rov farqni ko'rsatadi.
--
-- Farqlar KICHIK bo'lsa (bir necha tiyin) — 4.2 ni bajaring.
-- Farq KATTA bo'lsa — 4.2 ni BAJARMANG: sabab yaxlitlash emas, boshqa
-- narsa. Avval o'sha sdelkani tekshiring.
select p.trade_id,
       p.graph_order_num,
       g.paid_amount_uzs / 100                                      grafikda_som,
       sum(case when p.dc_sign = 4 then p.paid_amount_uzs
                else -p.paid_amount_uzs end) / 100                  tolovlarda_som,
       (g.paid_amount_uzs
        - sum(case when p.dc_sign = 4 then p.paid_amount_uzs
                   else -p.paid_amount_uzs end)) / 100              farq_som
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
 order by abs(g.paid_amount_uzs - sum(case when p.dc_sign = 4 then p.paid_amount_uzs
                                           else -p.paid_amount_uzs end)) desc;

prompt 4.2 Yaxlitlash qoldig'ini oxirgi to'lovga berish — IXTIYORIY

-- Add_Paid_Amounts dagi naqsh: qoldiq oxirgi qatorga beriladi.
-- 4.1 katta farq ko'rsatgan bo'lsa BUNI BAJARMANG.
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


prompt 5. Yakuniy tekshiruv

-- 5.1 Bo'sh qolgan qator qolmasligi kerak (kursi yo'qlaridan tashqari)
select count(*) tuldirilmagan
  from ipt_trade_graph_paid_amounts p
  join ipt_trades t
    on t.id = p.trade_id
 where nvl(t.currency_code, '840') = '860'
   and nvl(p.paid_amount_uzs, 0) = 0
   and nvl(p.paid_amount, 0) <> 0;

-- 5.2 Bitta sdelkani ko'z bilan ko'rish
--     <trade_id> o'rniga 1.1 dan bitta raqamni qo'ying
select p.graph_order_num,
       p.paid_date,
       p.dc_sign,
       p.paid_amount / 100     usd,
       p.paid_amount_uzs / 100 som,
       p.course_usd / 100      kurs
  from ipt_trade_graph_paid_amounts p
 where p.trade_id = &&trade_id
 order by p.graph_order_num, p.cr_on;

-- =============================================================================
-- ORQAGA QAYTARISH
--
--   merge into ipt_trade_graph_paid_amounts d
--   using (select id, old_paid_amount_uzs, old_course_usd
--            from ipt_tgpa_uzs_backup) s
--   on (d.id = s.id)
--   when matched then
--     update set d.paid_amount_uzs = s.old_paid_amount_uzs,
--                d.course_usd      = s.old_course_usd;
--   commit;
--
-- Hammasi joyida bo'lsa, bir necha kundan keyin:
--   drop table ipt_tgpa_uzs_backup;
-- =============================================================================
