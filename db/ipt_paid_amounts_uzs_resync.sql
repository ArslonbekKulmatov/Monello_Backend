-- =============================================================================
-- TO'LOV QATORLARINI GRAFIKKA QAYTA MOSLASH (RESYNC)
--
-- QACHON KERAK
--   ipt_trade_graphs qo'lda tuzatilgan bo'lsa. To'lov qatorlari eski
--   qiymatlar bilan qolib ketadi va grafik bilan mos kelmaydi.
--
-- BACKFILL SKRIPTI BU YERDA YORDAM BERMAYDI
--   db/ipt_paid_amounts_uzs_backfill.sql faqat BO'SH qatorlarni to'ldiradi
--   (nvl(paid_amount_uzs, 0) = 0). Ular endi to'ldirilgan, shuning uchun
--   uni qayta ishga tushirsangiz hech narsa o'zgarmaydi.
--
--   Bu skript esa MAVJUD qiymatlarni QAYTA YOZADI. Shuning uchun u
--   xavfliroq va qamrovi ataylab cheklangan.
--
-- ENG MUHIM OGOHLANTIRISH
--   Natively som ochilgan sdelkada paid_amount_uzs — mijoz HAQIQATAN
--   to'lagan summa, ya'ni FAKT. Uni grafikdan qayta hisoblash faktni
--   yo'q qiladi.
--
--   Konversiya qilingan sdelkalarda esa u baribir qayta qurilgan qiymat —
--   uni qayta hisoblash zararsiz.
--
--   Shuning uchun qamrov 0-bo'limda QO'LDA beriladi: faqat siz tuzatgan
--   sdelkalar. "Hammasini bir yo'la" qilmang.
--
-- TARTIB: 0 → 1 → 2 → 3 → 4 → (5 ixtiyoriy) → 6 → 7
--
-- Muallif: Arslonbek Kulmatov
-- Sana   : 23.09.2026
-- =============================================================================

prompt 0.1 Qamrov jadvali

create table ipt_tgpa_resync_scope (trade_id number primary key);

prompt 0.2 Qamrovni to'ldirish — SHU YERNI O'ZGARTIRING

-- Variant A: qo'lda tuzatgan sdelkalaringizni yozing
insert into ipt_tgpa_resync_scope (trade_id) values (9202);
-- insert into ipt_tgpa_resync_scope (trade_id) values (<boshqa_sdelka>);
commit;

-- Variant B: grafik bilan mos kelmaydigan HAMMA som sdelkasini topish.
-- Avval faqat select bilan ko'ring, keyin insert qiling.
--
--   select distinct p.trade_id
--     from ipt_trade_graph_paid_amounts p
--     join ipt_trades t on t.id = p.trade_id
--     join ipt_trade_graphs g
--       on  g.trade_id  = p.trade_id
--       and g.order_num = p.graph_order_num
--    where nvl(t.currency_code, '840') = '860'
--    group by p.trade_id, p.graph_order_num, g.paid_amount_uzs
--   having g.paid_amount_uzs <> sum(case when p.dc_sign = 4
--                                        then p.paid_amount_uzs
--                                        else -p.paid_amount_uzs end);

prompt 0.3 Qamrovni tekshirish

select s.trade_id,
       t.currency_code,
       t.course_usd / 100 sdelka_kursi,
       t.state
  from ipt_tgpa_resync_scope s
  join ipt_trades t
    on t.id = s.trade_id
 order by s.trade_id;

-- Dollar sdelkasi chiqsa — uni qamrovdan olib tashlang, bu skript
-- faqat som sdelkalari uchun.


prompt 1.1 Nima o'zgaradi — eski va yangi yonma-yon

select p.id,
       p.trade_id,
       p.graph_order_num,
       p.dc_sign,
       p.paid_amount / 100                                        usd,
       p.paid_amount_uzs / 100                                    hozirgi_som,
       ipt_util.Usd_To_Uzs(p.paid_amount, g.course_usd) / 100     yangi_som,
       (ipt_util.Usd_To_Uzs(p.paid_amount, g.course_usd)
        - p.paid_amount_uzs) / 100                                farq_som,
       p.course_usd / 100                                         hozirgi_kurs,
       g.course_usd / 100                                         yangi_kurs
  from ipt_trade_graph_paid_amounts p
  join ipt_tgpa_resync_scope s
    on s.trade_id = p.trade_id
  join ipt_trades t
    on t.id = p.trade_id
  join ipt_trade_graphs g
    on  g.trade_id  = p.trade_id
    and g.order_num = p.graph_order_num
 where nvl(t.currency_code, '840') = '860'
   and nvl(g.course_usd, 0) > 0
 order by p.trade_id, p.graph_order_num, p.cr_on;

prompt 1.2 Grafik darajasida: hozir qancha farq bor

select p.trade_id,
       p.graph_order_num,
       g.paid_amount / 100                                          grafik_usd,
       g.paid_amount_uzs / 100                                      grafik_som,
       sum(case when p.dc_sign = 4 then p.paid_amount_uzs
                else -p.paid_amount_uzs end) / 100                  tolovlar_som,
       (g.paid_amount_uzs
        - sum(case when p.dc_sign = 4 then p.paid_amount_uzs
                   else -p.paid_amount_uzs end)) / 100              farq_som
  from ipt_trade_graph_paid_amounts p
  join ipt_tgpa_resync_scope s
    on s.trade_id = p.trade_id
  join ipt_trade_graphs g
    on  g.trade_id  = p.trade_id
    and g.order_num = p.graph_order_num
 group by p.trade_id, p.graph_order_num, g.paid_amount, g.paid_amount_uzs
 order by p.trade_id, p.graph_order_num;


prompt 2. Zaxira — MAJBURIY

-- Avvalgi zaxira jadvali boshqa nom bilan, shuning uchun to'qnashmaydi.
create table ipt_tgpa_resync_backup as
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
  join ipt_tgpa_resync_scope s
    on s.trade_id = p.trade_id;

select count(*) saqlandi from ipt_tgpa_resync_backup;


prompt 3. Qayta hisoblash — paid_amount_uzs va course_usd

-- DIQQAT: bu MAVJUD qiymatlarni almashtiradi. 1.1 ni ko'rmagan bo'lsangiz
-- to'xtang va avval o'shani bajaring.
merge into ipt_trade_graph_paid_amounts d
using (
  select p.id                                               row_id,
         ipt_util.Usd_To_Uzs(p.paid_amount, g.course_usd)   uzs,
         g.course_usd                                       crs
    from ipt_trade_graph_paid_amounts p
    join ipt_tgpa_resync_scope s
      on s.trade_id = p.trade_id
    join ipt_trades t
      on t.id = p.trade_id
    join ipt_trade_graphs g
      on  g.trade_id  = p.trade_id
      and g.order_num = p.graph_order_num
   where nvl(t.currency_code, '840') = '860'
     and nvl(g.course_usd, 0) > 0
) s
on (d.id = s.row_id)
when matched then
  update set d.paid_amount_uzs = s.uzs,
             d.course_usd      = s.crs;

commit;


prompt 4. Qoldiqni oxirgi to'lovga berib, grafikka tenglashtirish

-- Qoldiq faqat TO'LOV qatoriga (dc_sign = 4) beriladi: bekor qilish
-- qatori yig'indida ayiriladi va qoldiqni teskari tomonga surardi.
merge into ipt_trade_graph_paid_amounts d
using (
  select x.last_id, x.diff
    from (select max(p.id) keep (dense_rank last order by p.cr_on, p.id) last_id,
                 g.paid_amount_uzs
                 - sum(case when p.dc_sign = 4 then p.paid_amount_uzs
                            else -p.paid_amount_uzs end)                  diff
            from ipt_trade_graph_paid_amounts p
            join ipt_tgpa_resync_scope s
              on s.trade_id = p.trade_id
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


prompt 5. rate_diff_amount — IXTIYORIY

-- Grafikda dollar va som tomoni mos kelmasa, farq shu yerga yoziladi:
--     rate_diff = paid_amount - Uzs_To_Usd(paid_amount_uzs, course_usd)
-- Manfiy = rasxod. Apply_Rate_Difference bilan bir xil ishora.
--
-- Qo'lda tuzatishdan keyin bu farq o'zgargan bo'lishi mumkin, shuning
-- uchun bu yerda 0 bo'lmaganlari ham QAYTA yoziladi — backfill skriptidan
-- farqi shu.
--
-- Bekor qilish qatorlari (dc_sign = 1) tegilmaydi.
merge into ipt_trade_graph_paid_amounts d
using (
  select p.id row_id,
         p.paid_amount
         - ipt_util.Uzs_To_Usd(p.paid_amount_uzs, p.course_usd) diff
    from ipt_trade_graph_paid_amounts p
    join ipt_tgpa_resync_scope s
      on s.trade_id = p.trade_id
    join ipt_trades t
      on t.id = p.trade_id
   where nvl(t.currency_code, '840') = '860'
     and p.dc_sign = 4
     and nvl(p.paid_amount_uzs, 0) <> 0
     and nvl(p.course_usd, 0) > 0
) s
on (d.id = s.row_id)
when matched then
  update set d.rate_diff_amount = s.diff;

commit;


prompt 6.1 Grafik bilan mos keldimi — bo'sh chiqishi kerak

select p.trade_id,
       p.graph_order_num,
       g.paid_amount_uzs / 100                                     grafikda,
       sum(case when p.dc_sign = 4 then p.paid_amount_uzs
                else -p.paid_amount_uzs end) / 100                 tolovlarda
  from ipt_trade_graph_paid_amounts p
  join ipt_tgpa_resync_scope s
    on s.trade_id = p.trade_id
  join ipt_trade_graphs g
    on  g.trade_id  = p.trade_id
    and g.order_num = p.graph_order_num
 group by p.trade_id, p.graph_order_num, g.paid_amount_uzs
having g.paid_amount_uzs <> sum(case when p.dc_sign = 4 then p.paid_amount_uzs
                                     else -p.paid_amount_uzs end);

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

prompt 6.3 View orqali ko'rish

select trade_id, paid_amount, paid_amount_usd, currency_code, paid_date
  from ipt_trade_graph_payments_v2
 where trade_id = &&trade_id
 order by paid_dt desc;


-- =============================================================================
-- 7. TOZALASH — hammasi joyida bo'lsa
--
--   drop table ipt_tgpa_resync_scope;
--
--   Zaxirani bir necha kun saqlang, keyin:
--   drop table ipt_tgpa_resync_backup;
--
-- ORQAGA QAYTARISH
--
--   merge into ipt_trade_graph_paid_amounts d
--   using (select id, old_paid_amount_uzs, old_course_usd, old_rate_diff_amount
--            from ipt_tgpa_resync_backup) s
--   on (d.id = s.id)
--   when matched then
--     update set d.paid_amount_uzs  = s.old_paid_amount_uzs,
--                d.course_usd       = s.old_course_usd,
--                d.rate_diff_amount = s.old_rate_diff_amount;
--   commit;
-- =============================================================================
