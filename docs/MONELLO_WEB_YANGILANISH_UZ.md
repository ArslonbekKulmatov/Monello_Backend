# Monello web — oxirgi o'zgarishlar

**Kimga:** Monello web interfeysi jamoasiga
**Nima uchun:** 19.09 dagi `MONELLO_WEB_KATALOG_UZ.md` dan keyin baza tomonida
yana beshta ish bajarildi. Quyida faqat **yangi** narsalar — eski hujjat
o'z kuchida qoladi.
**Holati:** baza o'zgarishlari bazaga qo'yilgan. Java tomoni (`/api/chat`,
`/api/mcp`) hali deployda emas.
**Sana:** 21.09.2026

---

## 1. Bir qarashda

| # | Nima o'zgardi | Web tomonda ish bormi |
|---|---|---|
| 1 | Kategoriyalar 28 taga chiqdi, ikkitasi "konteyner" | **Ha** — dropdownda konteynerni tanlatmaslik |
| 2 | Bir xil konfiguratsiyali tovarlar saytda **bitta kartochka** bo'ladi | **Ha** — xodimni ogohlantirish |
| 3 | Fiskal maydonlar: MXIK, o'lchov birligi, QQS | **Ha** — formaga uchta maydon |
| 4 | Ma'lumotnomalar 17 taga chiqdi, kodni baza qo'yadigan turi paydo bo'ldi | **Ha** — kichik tuzatish |
| 5 | Nom tahlili: tovar nomidan maydonlarni taxmin qilish | **Ha** — yangi ekran, eng katta foyda |
| 6 | Chat formasi (filial, savdo, rassrochka, qarzdor) | **Ha** — yangi ekran |

---

## 2. Kategoriyalar — 28 ta kod va konteyner bo'limlar

Sayt jamoasi o'z menyusiga mos 28 ta kodni berdi, hammasi bazaga qo'yildi.
To'liq ro'yxat: `select * from ipt_s_categories_v order by ord`.

Ikkita kod **konteyner** — ular menyuda bo'lim sarlavhasi, tovar kategoriyasi
emas:

| Kod | Nomi | Nega tanlab bo'lmaydi |
|---|---|---|
| `accessories` | Aksessuarlar | ichida `acc-cases`, `acc-glass` va h.k. bor |
| `used` | Ishlatilgan texnika | ichida `iphone-bu`, `ipad-bu` va h.k. bor |

`ipt_s_categories_v` da yangi ustun — `is_container` (1 yoki 0).

**Web tomonda:** kategoriya dropdownida `is_container = 1` bo'lganlarni
`<optgroup>` sarlavhasi qilib chiqaring yoki `disabled` qiling. Baza baribir
to'sadi, lekin tanlab bo'lgandan keyin xato olish yomon — tanlab bo'lmasligi
kerak.

Baza qaytaradigan xato:

```
"accessories" — konteyner bo'lim, unga tovar qo'yilmaydi. Aniq bo'limni
tanlang: aksessuar uchun acc-*, ishlatilgan texnika uchun *-bu.
```

---

## 3. Katalog kaliti — bir xil konfiguratsiya birlashadi

Sayt jamoasining talabi: bir xil telefonning 10 ta donasi katalogda 10 ta
kartochka bo'lib ko'rinmasin.

Endi saytga chiqadigan element kaliti shunday yig'iladi:

| Tovar holati | Katalog kaliti |
|---|---|
| Yangi (`item_condition <> 'used'`) | `model_code ~ xotira ~ ram ~ rang` |
| Ishlatilgan (`item_condition = 'used'`) | qatorning **o'z** `id` si |

Ya'ni yangi texnikada `iphone-16-pro-max` + `256` + `-` + `black` bo'lgan
hamma qatorlar **bitta** kartochka bo'ladi, qoldiq esa qo'shiladi.
Ishlatilgan texnika birlashmaydi — har bir dona o'ziga xos (batareya, IMEI).

### Bundan kelib chiqadigan uchta narsa

**1. `model_code` ni o'zgartirish sayt uchun yangi kartochka.**
Kalit konfiguratsiyadan yasalgani uchun `model_code` dagi xatoni tuzatsangiz
eski kartochka yo'qoladi, o'rniga yangisi paydo bo'ladi. Bu sayt tomonida
havola va statistikani uzadi.

> **Formaga ogohlantirish qo'ying:** allaqachon saytga chiqqan tovarning
> `model_code` ini tahrirlashda "Bu sayt kartochkasini almashtiradi" degan
> tasdiq so'ralsin.

**2. Bir konfiguratsiyada har xil narx bo'lsa — eng pasti olinadi.**
E'lon qilingan narxni ko'tarib bo'lmaydi, shuning uchun eng past narx
tanlandi: u har doim bajarib bo'ladigan va'da. Lekin narxlar farq qilishi
odatda **xato**. Shuni ko'rsatadigan so'rov `db/ipt_catalog_stage5.sql`
ning 3-bo'limida — uni gridga chiqarsangiz ombor xodimi o'zi tuzatadi.

**3. Tavsifiy maydonlar guruhdagi eng kichik `id` li qatordan olinadi.**
Ya'ni sku, kafolat va tavsif **bitta** qatordan keladi. Har maydonni alohida
olsak sku bir qatordan, tavsif boshqasidan kelib, mavjud bo'lmagan tovar
yasalardi.

Saytga chiqadigan javobda shourumlar bo'yicha qoldiq `quantity` obyektida
(`{"mirobod": 2, "sebzor": 0}`), umumiysi `quantity_total` da.

---

## 4. Fiskal maydonlar — MXIK, birlik, QQS

Sayt jamoasi fiskal chek uchun so'radi. Bazada bunday maydonlar **umuman
yo'q edi**, uchtasi yangi qo'shildi. To'ldirish joyi — Monello web.

`ipt.productAction` (va `catalogSaveProduct`) endi shularni ham qabul qiladi:

| Maydon | Tur | Tekshiruv | Izoh |
|---|---|---|---|
| `mxik_code` | matn | faqat raqam, **aniq 17 ta** | MXIK (IKPU) kodi |
| `unit_code` | matn | `ipt_s_units` da bo'lishi shart | o'lchov birligi |
| `vat_rate` | son | 0–100 | **FOIZDA**: `12` = 12% |

> ### `vat_rate` foizda, tiyinda emas
>
> Tizimda pul **tiyinda** (×100), `interest_rate` ham ×100 saqlanadi.
> `vat_rate` esa **oddiy foiz**: 12% uchun `12` yuboriladi, `1200` emas.
> Bu ataylab shunday — fiskal hujjatlarda stavka foizda yoziladi.
> Formada `%` belgisini yoniga qo'ying, xodim adashmasin.

O'lchov birliklari yangi ma'lumotnomadan keladi — `ipt_s_units_v`:

| Kod | Nomi |
|---|---|
| `dona` | Dona |
| `komplekt` | Komplekt |
| `upakovka` | Upakovka |
| `kg` / `litr` / `metr` | — |

> **Buxgalteriyadan tekshiring:** bu kodlar taxminiy. Fiskal chek uchun ular
> soliq klassifikatoridagi kodlar bilan mos bo'lishi kerak. Tuzatish uchun
> baza tegish shart emas — ma'lumotnomalar formasidan o'zgartiriladi.

Amalda telefon va aksessuar uchun `dona` yetarli. Ommaviy to'ldirishda
`catalogSaveProduct` bilan hammasiga birdan qo'yib chiqish qulay.

---

## 5. Ma'lumotnomalar formasi — ikkita yangilik

`MONELLO_WEB_MALUMOTNOMALAR_UZ.md` dagi forma o'z kuchida. Ikki narsa
qo'shildi.

### 5.1 Ikkita yangi ma'lumotnoma

| Kod | Nomi | Nima uchun |
|---|---|---|
| `units` | O'lchov birliklari | 4-bo'limdagi `unit_code` uchun |
| `parse_aliases` | Nom tahlili qoidalari | 6-bo'limdagi ekran uchun |

Jami 17 ta bo'ldi. Forma metadatadan chizilgani uchun **kod yozish shart
emas** — `dictList` ikkalasini o'zi qaytaradi.

### 5.2 `auto_code` — kodni baza qo'yadigan ma'lumotnoma

`dictList` javobidagi har bir ma'lumotnomada yangi bayroq bor:

```json
{ "code": "parse_aliases", "pk_type": "N", "auto_code": true, ... }
```

`auto_code: true` bo'lsa kod ma'noga ega emas, uni baza ketma-ketlikdan
o'zi qo'yadi.

**Web tomonda:**

| | `auto_code: false` (16 ta) | `auto_code: true` (`parse_aliases`) |
|---|---|---|
| Qo'shish oynasi | kod maydoni bor, majburiy | kod maydoni **ko'rsatilmaydi** |
| `dictSave` so'rovi | `"code": "..."` bilan | `code` **siz** |
| Kodni qayerdan bilasiz | o'zingiz yuborgansiz | javobdagi `"code"` dan |

Tahrirlashda farq yo'q — `code` har doim yuboriladi.

---

## 6. Nom tahlili — eng ko'p vaqt tejaydigan ekran

### Muammo

Omborchi hamma narsani tovar nomiga yozgan:

```
iPhone 17 Pro Max 256Gb Silver sim+esim New imei 073349
iPhone 16 Pro Max 256Gb Desert esim B/K 89% imei 567102
iWatch 11 46mm Jet Black seria JJFJX03WQY
```

Model, xotira, rang, SIM, holat, batareya va IMEI — hammasi shu yerda bor,
faqat alohida maydonlarga ajratilmagan. ~800 qatorni qo'lda ko'chirish
haftalar oladi.

### Yechim

`IPT_CATALOG_PARSE_V` har bir to'ldirilmagan qator uchun nomdan **taxmin
qilingan** qiymatlarni beradi:

| Ustun | Nima |
|---|---|
| `id`, `name`, `filial_code`, `quantity` | asl qator |
| `p_model_code`, `p_model_name` | model |
| `p_category_code`, `p_brand_code` | kategoriya, brend |
| `p_condition` | `new` yoki `used` |
| `p_storage_gb`, `p_ram_gb` | xotira |
| `p_color_code`, `p_sim_type`, `p_market_code` | rang, SIM, bozor kodi |
| `p_battery_pct`, `p_imei`, `p_serial` | b/u uchun |
| `topildi` | nechta asosiy maydon topilgani, 0–6 |

Misol (haqiqiy ma'lumotda tekshirilgan):

| name | p_model_code | p_condition | p_storage_gb | p_color_code | topildi |
|---|---|---|---|---|---|
| iPhone 17 Pro Max 256Gb Silver sim+esim New imei 073349 | `iphone-17-pro-max` | new | 256 | silver | 6 |
| iPhone 16 Pro Max 256Gb Desert esim B/K 89% imei 567102 | `iphone-16-pro-max` | used | 256 | desert | 6 |
| iWatch 11 46mm Jet Black seria JJFJX03WQY | `iwatch-11-46mm` | — | — | space-black | 4 |

### View HECH NARSA YOZMAYDI

Bu ataylab. Yuklamada `Desert`/`Desret`, `imei`/`imie` kabi xatolar bor,
**narx esa nomda umuman yo'q**. Shuning uchun avtomatga qo'yilmadi: xodim
ekranda ko'z bilan tekshiradi, to'g'rilarini belgilaydi va
`catalogSaveProduct` bilan qo'llaydi.

### Ekran qanday bo'lishi kerak

1. Grid — `IPT_CATALOG_PARSE_V`, `topildi desc` bo'yicha saralangan.
   Yuqorida eng ishonchlilari turadi.
2. Har bir `p_` ustuni **tahrirlanadigan** bo'lsin: taxmin noto'g'ri bo'lsa
   xodim shu yerda tuzatsin.
3. `topildi <= 3` bo'lgan qatorlarni rang bilan ajrating — ularni albatta
   ko'z bilan ko'rish kerak.
4. Belgilangan qatorlar → `catalogSaveProduct` → bitta chaqiruvda saqlanadi.
5. Narx maydoni **bo'sh** keladi, uni xodim qo'lda kiritadi.

`p_model_code` bo'yicha guruhlab ishlash eng tez yo'l: bir xil model kodini
olgan 30 ta qatorni belgilab, narxini bir marta yozib, birdan saqlash.

```sql
select p_model_code, count(*) from ipt_catalog_parse_v
 where p_model_code is not null
 group by p_model_code order by count(*) desc;
```

### Qoidalar kodda emas

Rang, bozor kodi, brend va kategoriya `IPT_S_PARSE_ALIASES` jadvalidan
o'qiladi — u esa ma'lumotnomalar formasiga ulangan (5-bo'lim). Yangi rang
yoki model uchrasa xodim **formadan** qator qo'shadi, dasturchi kerak emas:

| Nima qidiriladi | Nomdagi matn | Ma'lumotnoma kodi |
|---|---|---|
| Rang | `jet black` | `space-black` |
| Rang | `desret` (xato yozilishi) | `desert` |
| Bozor kodi | `ll/a` | `LL/A` |
| Brend | `apple` | `apple` |

Uzunroq matn birinchi tekshiriladi: `rose gold` `gold` dan ustun,
`jet black` `black` dan ustun.

> Bu view ham `ipt_catalog_todo_v` kabi API'ga chiqmaydi — ichida `name`
> ustuni bor. `core_grids` orqali ekranga qo'yiladi, `module_id` ni siz
> belgilaysiz.

---

## 7. Chat formasi

Alohida hujjat bor: **`MONELLO_CHAT_UZ.md`**. Qisqacha:

| | |
|---|---|
| Yo'l | `POST /api/chat` (odatdagi `/api/app/request` emas) |
| Holati | `GET /api/chat/status` — kalit sozlanganini tekshiradi |
| Nima bilan javob beradi | filiallar, savdolar, rassrochkalar, qarzdorlar, sdelkalar |
| Ma'lumot qayerdan | faqat beshta ro'yxatdan o'tgan **o'qish** metodidan |

Model SQL yozmaydi va yoza olmaydi — u faqat shu beshta metodni chaqiradi.
Har bir chaqiruv sizning JWT'ingiz bilan ketadi, ya'ni **filial bo'yicha
cheklov o'z-o'zidan ishlaydi**: sotuvchi faqat o'z filialining raqamlarini
ko'radi.

Telefon, PINFL va manzil chatga umuman chiqmaydi.

**Web tomonda:** oddiy chat oynasi — savol maydoni, javoblar tarixi.
Front maket tayyor, `prototype/chat/` da.

---

## 8. Yangilangan view'lar

Ikkala view'ga katalog va fiskal maydonlar qo'shildi:

| View | Nima qo'shildi |
|---|---|
| `IPT_PRODUCTS_V` | 24 ta katalog maydoni + `mxik_code`, `unit_code`, `unit_name`, `vat_rate` + `site_code`, `in_catalog` |
| `IPT_PRODUCTS_HIS_V` | xuddi shular (tarixda `in_catalog` yo'q) |

`in_catalog` — eng foydali ustun. `'Y'` bo'lsa tovar saytda ko'rinadi,
`'N'` bo'lsa yo'q. Shartlari `ipt_catalog_v` bilan **aynan** bir xil, ya'ni
gridda ko'rinsa saytda ham chiqqan bo'ladi.

Nimasi yetishmayotgani maydon-maydon `ipt_catalog_todo_v` da.

---

## 9. Rasm havolalari va host

Hozircha host: **`http://37.140.216.159:9999`**. `core_properties.catalog_file_url`
shu qiymatga qo'yilgan, rasm havolalari shu prefiks bilan yig'iladi.

> Domen olinib `https` ga o'tilganda **faqat shu bitta qator** o'zgaradi:
>
> ```sql
> update core_properties set value = 'https://<domen>/api/app/get-file?file='
>  where code = 'catalog_file_url';
> commit;
> ```
>
> Web tomonda kodda host qotirib yozilmasin — havola bazadan kelgani bilan
> ishlang.

---

## 10. Qurish kerak bo'lgan ekranlar — yangilangan ro'yxat

Ustuvorlik bo'yicha:

| # | Ekran | Nega shu tartibda |
|---|---|---|
| 1 | **Nom tahlili** (6-bo'lim) | ~800 qatorni to'ldirishning eng tez yo'li. Bu bo'lmasa qolgani qo'lda ketadi |
| 2 | **Mahsulot formasiga fiskal 3 ta maydon** (4-bo'lim) | `productAction` allaqachon qabul qiladi |
| 3 | **Kategoriya dropdowniga `is_container`** (2-bo'lim) | kichik ish, xatoni oldini oladi |
| 4 | **Ma'lumotnomalarga `auto_code`** (5.2) | kichik ish, `parse_aliases` shusiz ishlamaydi |
| 5 | **Chat formasi** (7-bo'lim) | mustaqil, katalogga bog'liq emas |

1, 3 va 4 birga ketadi: nom tahlili ekrani ikkalasiga ham tayanadi.

---

## 11. Baza tomonida ishga tushirish tartibi

Agar bazangiz eski bo'lsa, fayllar **shu tartibda** bajariladi:

| # | Fayl | Izoh |
|---|---|---|
| 1 | `db/ipt_catalog_stage4.sql` | 28 kategoriya, `is_container` |
| 2 | `db/ipt_catalog_stage5.sql` | katalog kaliti, qoldiq |
| 3 | `db/ipt_catalog_package.sql` | **qayta kompilyatsiya** — stage5 view'lariga tayanadi |
| 4 | `db/ipt_catalog_stage6.sql` | MXIK, birlik, QQS, `ipt_s_units`. **3-bo'limni o'tkazib yuboring** |
| 5 | `db/ipt_products_his_dml.sql` | stage6 ning 3-bo'limi o'rniga: ustunlar aniq sanaladi |
| 6 | `db/ipt_dictionary.sql` | **qayta kompilyatsiya** — `seq_name` uchun |
| 7 | `db/ipt_catalog_parse.sql` | nom tahlili |
| 8 | `db/ipt_products_v.sql`, `db/ipt_products_his_v.sql` | yangilangan view'lar |

Kutilgan, zararsiz xatolar:

| Xato | Qayerda | Nega zararsiz |
|---|---|---|
| `ORA-00955` | 6-qadam | jadval allaqachon bor, merge'lar baribir ishlaydi |
| `ORA-01430` | 7-qadam, 1.0 bo'limi | `seq_name` ustuni allaqachon qo'shilgan |

`ORA-00947` chiqsa — stage6 ning 3-bo'limi o'tkazib yuborilmagan. U pozitsion
insert ishlatadi va 62 ustunli jadvalda yiqiladi. 5-qadamdagi fayl uning
o'rnini bosadi.

Oxirida:

```sql
select object_name, object_type from user_objects where status <> 'VALID';
```

Bo'sh chiqishi kerak.

> **Diqqat:** `ipt_dictionary.sql` va `ipt_catalog_parse.sql` da bo'sh
> qatorlar ataylab olib tashlangan. SQL*Plus va PL/SQL Developer operator
> ichidagi bo'sh qatorni "operator tugadi" deb tushunadi — fayllarni
> tahrirlaganda merge yoki insert ichiga bo'sh qator qo'shmang.

---

## 12. Vitrina filiallari

| Filial | `site_code` | Saytda |
|---|---|---|
| 01030 | `mirobod` | Mirobod vitrinasi |
| 01060 | `sebzor` | Sebzor vitrinasi |
| 01070 | `sebzor` | **xuddi o'sha** Sebzor vitrinasi |

`01060` va `01070` — bitta shourum, ikkita hisob filiali. Shuning uchun
saytda ular bitta vitrina bo'lib ko'rinadi va qoldiqlari **qo'shiladi**.
Sozlama to'g'ri, o'zgartirish kerak emas.

**Web tomonda bundan kelib chiqadigan narsa:** katalog bilan bog'liq
ekranlarda (ish ro'yxati, nom tahlili, qoldiq) filialni `site_code` bo'yicha
guruhlash kerak, `filial_code` bo'yicha emas. Aks holda xodim gridda ikkita
"Sebzor" ko'radi, saytda esa bitta — va nega raqamlar mos kelmayapti deb
o'ylaydi.

`site_code` i bo'sh filialdagi tovar saytga **umuman chiqmaydi** — bu
katalogga chiqishning yettinchi sharti. `ipt_products_v.site_code` va
`ipt_catalog_todo_v.no_site_code` shuni ko'rsatadi.

---

*Monello backend · 21.09.2026*
