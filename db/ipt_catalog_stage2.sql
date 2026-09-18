-- =============================================================================
-- IPT KATALOG API — 2-BOSQICH: tashqi tizim tokeni
--
-- ISHGA TUSHIRISH TARTIBI
--   1. ipt_catalog_stage1.sql
--   2. ipt_catalog_stage2.sql          <- shu fayl
--   3. ipt_catalog_stage3.sql
--   4. ipt_catalog_package.sql
--   5. ipt_catalog_product_action.sql  <- Ipt_Methods ga qo'lda
--
-- Ipt_Catalog paketi va core_methods yozuvlari ipt_catalog_package.sql da —
-- paket ikki joyda turmasligi uchun.
--
-- Muallif: Arslonbek Kulmatov
-- Sana   : 13.09.2026
-- =============================================================================


-- =============================================================================
-- 1. TOKENLAR JADVALI
--
-- Sayt doimiy token so'raydi (talablar hujjati 9-bo'lim), JWT esa 24 soatda
-- tugaydi va bekor qilib bo'lmaydi. Shuning uchun alohida jadval.
--
-- Token OCHIQ SAQLANMAYDI — faqat SHA-256 xesh. Bazani ko'rgan odam ham
-- tokenni tiklay olmaydi.
-- =============================================================================

prompt 1.1 CORE_API_TOKENS

create table CORE_API_TOKENS
(
  id         NUMBER(10) not null,
  name       VARCHAR2(200) not null,
  token_hash VARCHAR2(64) not null,
  user_id    NUMBER(10) not null,
  condition  VARCHAR2(2) default 'A' not null,
  cr_by      NUMBER(10),
  cr_on      DATE,
  up_by      NUMBER(10),
  up_on      DATE
)
;
comment on table CORE_API_TOKENS
  is 'Tashqi tizimlar uchun doimiy API tokenlari. Token ochiq saqlanmaydi';
comment on column CORE_API_TOKENS.name
  is 'Token kimga berilgani: "ABM Store sayti", "ABM Store sayti (test)"';
comment on column CORE_API_TOKENS.token_hash
  is 'Tokenning SHA-256 xeshi, kichik harfli hex. Java tomonda ham shunday hisoblanadi';
comment on column CORE_API_TOKENS.user_id
  is 'Token qaysi core_users nomidan ishlaydi — loglar va sessiya shu foydalanuvchiga yoziladi';
comment on column CORE_API_TOKENS.condition
  is 'A - active; P - passive. Tokenni bekor qilish uchun P ga o''tkaziladi';

alter table CORE_API_TOKENS
  add constraint CORE_API_TOKENS_PK primary key (ID);
alter table CORE_API_TOKENS
  add constraint CORE_API_TOKENS_HASH_UK unique (TOKEN_HASH);
alter table CORE_API_TOKENS
  add constraint CORE_API_TOKENS_USER_FK foreign key (USER_ID)
  references CORE_USERS (USER_ID);
alter table CORE_API_TOKENS
  add constraint CORE_API_TOKENS_COND_CHK
  check (condition in ('A', 'P'));


-- =============================================================================
-- 2. KATALOG MAYDONLARINI TO'LDIRISH — ikki yo'l
--
-- 2.1 BITTA MAHSULOT — mahsulotning o'z formasi orqali, qo'shimcha chaqiruvsiz.
--     Ipt_Methods.Product_Action ga db/ipt_catalog_product_action.sql
--     qo'llanilgandan keyin ishlaydi.
--
--   {
--     "method": "productAction",
--     "params": {
--       "action": "U",
--       "id": 101,
--       "name": "...", "price": 850, "investor_id": 3,
--       "type": "M", "quantity": 1,
--
--       "model_code": "iphone-16-pro-max",
--       "model_name": "iPhone 16 Pro Max",
--       "category_code": "iphone",
--       "brand_code": "apple",
--       "item_condition": "new",
--       "retail_price_uzs": 19500000,
--       "phys_filial_code": "01025"
--     }
--   }
--
-- 2.2 BIR NECHTA MAHSULOT — catalogSaveProduct, faqat ommaviy hol uchun.
--     Bitta model bo'yicha o'nlab qator bir xil model_code va kategoriya
--     oladi ("iPhone 16 Pro Max" yuklamada 34 marta uchraydi).
--
--   {
--     "method": "catalogSaveProduct",
--     "params": {
--       "ids": [101, 102, 103],
--       "model_code": "iphone-16-pro-max",
--       "category_code": "iphone",
--       "brand_code": "apple"
--     }
--   }
--
-- Ikkala yo'lda ham katalog maydonlari ixtiyoriy va bir xil tekshiruvdan
-- o'tadi (Apply_Catalog_Fields). Berilmagan maydon TEGILMAYDI — faqat
-- model_code ni yuborib, narxni joyida qoldirish mumkin.
--
-- retail_price_uzs SOMDA yuboriladi (19500000), bazada tiyinda saqlanadi.
-- =============================================================================


-- =============================================================================
-- 3. TOKEN YARATISH
--
-- Tokenni o'zingiz o'ylab topmang — tasodifiy generatsiya qiling, masalan:
--
--   openssl rand -hex 32
--
-- Chiqqan qiymatni sayt jamoasiga BIR MARTA xavfsiz kanal orqali yuboring va
-- o'zingizda saqlamang: bazada faqat xesh qoladi, tokenni tiklab bo'lmaydi.
-- Yo'qolsa — yangisini yaratib, eskisini condition = 'P' ga o'tkazasiz.
--
--   insert into core_api_tokens(id, name, token_hash, user_id, scope, condition, cr_by, cr_on)
--   values ((select nvl(max(id), 0) + 1 from core_api_tokens),
--           'ABM Store sayti',
--           lower(rawtohex(standard_hash('BU_YERGA_TOKEN', 'SHA256'))),
--           :user_id,          -- katalog nomidan ishlaydigan core_users.user_id
--           'catalog',         -- qamrov: bu token faqat /api/catalog/* ga kiradi
--           'A',
--           :user_id,
--           sysdate);
--   commit;
--
-- scope ustuni db/ipt_dashboard.sql da qo'shiladi. Agar u hali ishga
-- tushirilmagan bo'lsa, insert dan scope ni olib tashlang.
--
-- Tekshirish:
--   select id, name, scope, condition from core_api_tokens;
--
-- Bekor qilish:
--   update core_api_tokens set condition = 'P' where id = ?;
-- =============================================================================
