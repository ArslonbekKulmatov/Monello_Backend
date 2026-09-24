-- =============================================================================
-- INVESTOR "INVESTITSIYA (SUMMA)" XATOSINI TEKSHIRISH
--
-- Muammo: ipt_investors.total_investment haqiqiy sarmoyadan katta chiqadi.
--
-- Sabab: INCE (investor foydadan pul yechishi) xato kiritilganda, uni
-- QAYTARISH uchun INC yozilgan. INC esa "yangi sarmoya" degani —
-- total_investment ni ko'taradi. Natijada har bir bunday tuzatish
-- investitsiya summasini butunlay noto'g'ri oshirib yuboradi.
--
-- Bu fayl hech narsani o'zgartirmaydi — faqat ko'rsatadi.
-- Tuzatish varianti 4-bo'limda, ataylab bajarilmaydigan holda.
--
-- Muallif: Arslonbek Kulmatov
-- Sana   : 22.09.2026
-- =============================================================================

prompt 1. total_investment ni operatsiyalardan qayta hisoblash

-- Farqi bor investorlar chiqadi. Farq nolga teng bo'lsa — jadval to'g'ri,
-- lekin bu "summa to'g'ri" degani emas: INC larning o'zi xato bo'lishi mumkin
-- (2-bo'limga qarang).
select i.id,
       i.name,
       i.total_investment / 100                          jadvalda_usd,
       nvl(o.hisoblangan, 0) / 100                       hisoblangan_usd,
       (i.total_investment - nvl(o.hisoblangan, 0)) / 100 farq_usd
  from ipt_investors i
  left join (select t.investor_id,
                    sum(case when t.oper_code = 'INC' then  t.amount
                             when t.oper_code = 'EXP' then -t.amount
                             else 0 end) hisoblangan
               from ipt_operations t
              where t.manager_id is null
              group by t.investor_id) o
    on o.investor_id = i.id
 where i.condition = 'A'
 order by abs(i.total_investment - nvl(o.hisoblangan, 0)) desc;


prompt 2. Shubhali INC lar — INCE ni qaytarish uchun yozilganlari

-- Naqsh: bir xil summadagi INCE (yechish) va INC (kiritish) bir-biriga yaqin
-- kunlarda. Izohlarda odatda "adashib", "xato", "qaytardim" so'zlari bo'ladi.
--
-- Bunday INC total_investment ni oshiradi, INCE esa uni kamaytirmaydi —
-- shuning uchun juftlik nolga kelmaydi, faqat investitsiya shishadi.
select inc.investor_id,
       inc.id              inc_id,
       inc.amount / 100    usd,
       trunc(inc.cr_on)    inc_kuni,
       ince.id             ince_id,
       trunc(ince.cr_on)   ince_kuni,
       substr(inc.comments, 1, 100) inc_izohi
  from ipt_operations inc
  join ipt_operations ince
    on  ince.investor_id = inc.investor_id
    and ince.oper_code   = 'INCE'
    and ince.amount      = inc.amount
    and ince.manager_id is null
    and ince.cr_on between inc.cr_on - 30 and inc.cr_on + 30
 where inc.oper_code = 'INC'
   and inc.manager_id is null
 order by inc.investor_id, inc.cr_on;


prompt 3. Bitta investorning butun INC/EXP tarixi

-- &&investor_id o'rniga tekshirilayotgan investor raqamini qo'ying.
select t.id,
       t.oper_code,
       t.amount / 100 usd,
       trunc(t.cr_on) kuni,
       substr(t.comments, 1, 120) izohi
  from ipt_operations t
 where t.investor_id = &&investor_id
   and t.manager_id is null
   and t.oper_code in ('INC', 'EXP')
 order by t.cr_on, t.id;

-- Operatsiya kodlari kesimida umumiy manzara
select t.oper_code,
       count(*)                                                              soni,
       sum(case when t.manager_id is null     then t.amount else 0 end)/100  investor_usd,
       sum(case when t.manager_id is not null then t.amount else 0 end)/100  manager_usd
  from ipt_operations t
 where t.investor_id = &&investor_id
 group by t.oper_code
 order by t.oper_code;


-- =============================================================================
-- 4. TUZATISH — BAJARMANG, AVVAL O'QING
--
-- Ikki xil ish bor va ularni aralashtirmaslik kerak.
--
-- 4.1 KODNI TUZATISH (asosiysi)
--     INCE ni qaytarish uchun alohida operatsiya kodi kerak: u investor
--     qoldig'ini (saldo_out) ko'taradi, lekin total_investment ga TEGMAYDI.
--     Hozir bunday kod yo'q, shuning uchun xodim INC yozishga majbur.
--     Bu tuzatilmaguncha xato qayta-qayta takrorlanadi.
--
-- 4.2 MAVJUD MA'LUMOTNI TUZATISH
--     DIQQAT: saldo_out TO'G'RI. Xato INC qoldiqni ko'targan, lekin u
--     o'rinli edi — chunki xato INCE qoldiqni tushirgan edi. Ya'ni
--     saldo_out ga TEGMASLIK kerak, faqat total_investment tushiriladi.
--
--     Shuning uchun quyidagi update saldo_out ni o'zgartirmaydi:
--
--       insert into ipt_investors_his
--       select t.*, 'U', <foydalanuvchi_id>, sysdate
--         from ipt_investors t where t.id = &&investor_id;
--
--       update ipt_investors t
--          set t.total_investment = t.total_investment - <shubhali_INC_summasi>,
--              t.up_by = <foydalanuvchi_id>,
--              t.up_on = sysdate
--        where t.id = &&investor_id;
--
--     <shubhali_INC_summasi> — 2-bo'lim chiqargan qatorlar yig'indisi,
--     TIYINDA (ya'ni dollarning 100 barobari).
--
--     Bajarishdan oldin: 2-bo'lim chiqargan har bir qatorni buxgalter
--     ko'zdan kechirsin. Naqsh mos kelgani bilan qator haqiqiy sarmoya
--     bo'lishi ham mumkin — masalan investor o'sha kuni tasodifan xuddi
--     shu summani kiritgan bo'lsa.
--
-- 4.3 NIMA QILMASLIK KERAK
--     Xato INC ni "EXP yozib" tuzatmang. EXP — investorga pul QAYTARILDI
--     degani: u total_investment ni tushiradi, lekin ayni paytda
--     saldo_out ni ham tushiradi. Qoldiq esa to'g'ri turibdi — shuning
--     uchun EXP uni buzadi.
-- =============================================================================
