# Monello web — katalog o'zgarishlari

**Kimga:** Monello web interfeysi jamoasiga
**Nima uchun:** ABM Store sayti katalogni Monello bazasidan oladi. Ma'lumotni
kiritish joyi — Monello web. Quyida nima o'zgargani va nima qurish kerakligi.
**Holati:** baza tomoni ishga tushirilgan, metodlar `core_methods` da faol
**Sana:** 19.09.2026, **yangilandi:** 21.09.2026

> **21.09 yangilanishi.** Sayt jamoasining javobidan keyin uchta narsa
> qo'shildi: fiskal maydonlar (MXIK, o'lchov birligi, QQS), 28 ta
> kategoriya konteyner bo'limlar bilan, va bir xil konfiguratsiyali
> tovarlarni saytda bitta kartochkaga birlashtirish. Shu hujjat
> yangilangan. Ekran-ekran ish ro'yxati esa alohida:
> `MONELLO_WEB_FRONT_ISHLAR_UZ.md`.

---

## 1. Bir qarashda

| | |
|---|---|
| O'zgargan metod | `ipt.productAction` — **27 ta** ixtiyoriy maydon qo'shildi |
| Yangi metodlar | 6 ta: rasm, xarakteristika, ommaviy to'ldirish |
| Yangi ma'lumotnomalar | kategoriya, brend, rang, SIM, bozor kodi, almashtirilgan qism, xarakteristika, **o'lchov birligi**, **nom tahlili qoidalari** |
| Yangi ish ro'yxati | `ipt_catalog_todo_v` — saytga chiqmayotgan tovarlar |
| Yangi yordamchi | `ipt_catalog_parse_v` — tovar nomidan maydonlarni taxmin qilish |
| Moliyaviy mantiq | **tegilmagan** |

Eng muhim qoida: **bitta mahsulotni saqlash uchun bitta chaqiruv**. Katalog
maydonlari mavjud `productAction` ning ichiga qo'shildi, alohida "katalogni
saqlash" tugmasi kerak emas.

---

## 2. Chaqiruv yo'llari

Odatdagi metodlar:

```
POST /api/app/request
Content-Type: application/json

{ "method": "...", "params": { ... } }
```

Fayl yuklaydigan metod (faqat `catalogUploadImage`):

```
POST /api/app/requestFile
Content-Type: multipart/form-data

params = {"method":"catalogUploadImage","params":{...}}   (matn maydoni)
file   = <rasm fayli>                                      (fayl maydoni)
```

Javob konverti ikkalasida bir xil:

```json
{ "success": true, "oper": true, "message": "Rasm yuklandi.", "data": { "id": 412, "url": "..." } }
```

`oper` va `message` javobdan ko'chirib olinadi, qolgani `data` ichida qoladi.

> `catalogUploadImage` nomi **katta-kichik harfga sezgir**: `Core_App.Set_Method_File`
> metodni `t.Method = vMethod` bo'yicha qidiradi, odatdagi `Set_Method` esa
> `lower()` bilan. Xato yozilsa "Unknown method" chiqadi.

---

## 3. `ipt.productAction` — asosiy o'zgarish

Mahsulot formasi qanday ishlagan bo'lsa, shunday ishlayveradi. Unga 24 ta
ixtiyoriy maydon qo'shildi. Hech biri majburiy emas, shuning uchun eski forma
ham buzilmay ishlaydi.

```json
{
  "method": "ipt.productAction",
  "params": {
    "action": "U",
    "id": 104721,

    "name": "iPhone 17 Pro Max 256 Silver",
    "price": 850,
    "investor_id": 3,
    "type": "M",
    "quantity": 1,

    "model_code": "iphone-17-pro-max",
    "model_name": "iPhone 17 Pro Max",
    "category_code": "iphone",
    "brand_code": "apple",
    "item_condition": "new",
    "retail_price_uzs": 19500000,
    "color_code": "silver",
    "storage_gb": 256,
    "sku": "IP17PM-256-SL"
  }
}
```

### Berilmagan maydon TEGILMAYDI

Bu eng muhim xulq va uni forma yozayotganda yodda tutish kerak:

| So'rovda | Natija |
|---|---|
| Kalit umuman yo'q | Bazadagi qiymat **o'zgarmaydi** |
| Kalit bor, qiymati `null` | Maydon **tozalanadi** |
| Kalit bor, qiymati bor | Qiymat qo'yiladi |

Ya'ni faqat `model_code` ni yuborib, narxni joyida qoldirish mumkin. Lekin
bo'sh forma maydonini `null` qilib yuborsangiz — bazadagi qiymat o'chadi.
Forma "faqat o'zgarganini yubor" tarzida qurilsa eng xavfsizi.

### Maydonlar

Narxlar **so'mda** yuboriladi, bazada tiyinda saqlanadi — o'girishni o'zingiz
qilmang.

| Maydon | Tur | Tekshiruv |
|---|---|---|
| `model_code` | matn | faqat kichik lotin, raqam, `-`: `iphone-17-pro-max` |
| `model_name` | matn | tozalangan nom, xizmat belgilarisiz |
| `model_name_uz` | matn | — |
| `category_code` | matn | `ipt_s_categories_v` da faol bo'lishi shart |
| `brand_code` | matn | `ipt_s_brands_v` da faol bo'lishi shart |
| `item_condition` | matn | faqat `new` yoki `used` |
| `phys_filial_code` | matn | `ipt_s_filials` da bo'lishi shart |
| `retail_price_uzs` | son | so'mda, 0 dan katta |
| `old_price_uzs` | son | so'mda, **joriy narxdan katta** bo'lishi shart |
| `sku` | matn | — |
| `color_code` | matn | `ipt_s_colors_v` |
| `storage_gb` | son | — |
| `ram_gb` | son | — |
| `warranty_months` | son | — |
| `description_ru` | matn | — |
| `description_uz` | matn | — |
| `has_box` | mantiqiy | `true` / `false` |
| `has_charger` | mantiqiy | `true` / `false` |

### Fiskal maydonlar — 21.09 da qo'shildi

Sayt onlayn to'lov chekini shular bilan yig'adi. Bazada bunday maydonlar
umuman yo'q edi.

| Maydon | Tur | Tekshiruv |
|---|---|---|
| `mxik_code` | matn | faqat raqam, **aniq 17 ta** |
| `unit_code` | matn | `ipt_s_units_v` da bo'lishi shart |
| `vat_rate` | son | 0–100 |

> **`vat_rate` FOIZDA saqlanadi: `12` = 12%.**
>
> Tizimda pul tiyinda (×100), `interest_rate` ham ×100. Bu esa oddiy foiz —
> fiskal hujjatlarda stavka shunday yoziladi. Formada `%` belgisini yoniga
> qo'ying, aks holda xodim `1200` yozib yuboradi.

MXIK uzunligi tekshiruvi bitta joyda — `Ipt_Catalog.Read_Catalog_Fields`.
Boshqa uzunlikdagi kodlar uchrasa o'sha shartni yumshatasiz.

### Faqat b/u texnika uchun

| Maydon | Tur | Tekshiruv |
|---|---|---|
| `battery_health_pct` | son | 1–100 |
| `imei` | matn | — |
| `serial` | matn | Mac, iPad, soat uchun |
| `sim_type` | matn | `ipt_s_sim_types_v` |
| `market_code` | matn | `ipt_s_market_codes_v` |
| `replaced_parts` | matn | vergul bilan: `screen,battery` — har biri `ipt_s_replaced_parts_v` da |

`item_condition` = `new` bo'lsa bu maydonlar saytga umuman chiqmaydi, lekin
bazada saqlanaveradi. Forma ularni `used` tanlanganda ko'rsatsa yetarli.

### Nega `item_condition`, `condition` emas

`condition` ustuni tizim bo'ylab A/P (faol/nofaol) uchun band. Tovar holati
uchun boshqa nom kerak bo'ldi.

---

## 4. Ma'lumotnomalar — dropdown uchun

Hammasi `code` / `name_ru` / `name_uz` / `ord` ko'rinishida, faol yozuvlar
bilan. To'g'ridan-to'g'ri grid yoki `execSelect` orqali o'qiladi.

| View | Nima uchun |
|---|---|
| `ipt_s_categories_v` | Kategoriya — **28 ta** kod, `is_container` ustuni bilan |
| `ipt_s_brands_v` | Brend |
| `ipt_s_colors_v` | Rang |
| `ipt_s_sim_types_v` | SIM turi |
| `ipt_s_market_codes_v` | Bozor kodi: `LL/A`, `KHA`, `RUA`, `LZA`, `JA` |
| `ipt_s_replaced_parts_v` | Almashtirilgan qism |
| `ipt_s_attributes_v` | Xarakteristikalar ro'yxati, turi bilan |
| `ipt_s_units_v` | O'lchov birligi: `dona`, `komplekt`, `upakovka`, `kg`, `litr`, `metr` |

Ro'yxatlar kengaytiriladigan: yangi rang yoki kategoriya kerak bo'lsa
ma'lumotnomaga qator qo'shiladi, kod o'zgarmaydi. Hammasini bitta formadan
tahrirlash uchun — `MONELLO_WEB_MALUMOTNOMALAR_UZ.md`.

### Konteyner kategoriyalar — dropdownda tanlab bo'lmaydi

`ipt_s_categories_v.is_container = 1` bo'lgan ikkita kod saytda **bo'lim
sarlavhasi**, tovar kategoriyasi emas:

| Kod | Nomi | Ichida nima bor |
|---|---|---|
| `accessories` | Aksessuarlar | `acc-glass`, `acc-cases`, `acc-chargers`, … |
| `used` | Ishlatilgan texnika | `iphone-bu`, `ipad-bu`, `mac-bu`, … |

Formada ularni `<optgroup>` sarlavhasi qiling yoki `disabled`. Baza baribir
to'sadi:

```
"accessories" — konteyner bo'lim, unga tovar qo'yilmaydi. Aniq bo'limni
tanlang: aksessuar uchun acc-*, ishlatilgan texnika uchun *-bu.
```

Lekin tanlab bo'lgandan keyin xato olish yomon — tanlab bo'lmasligi kerak.

---

## 5. Qaysi ma'lumot qayerda turadi — UI uchun asosiy qoida

Buni noto'g'ri tushunish eng qimmat xatoga olib keladi, shuning uchun alohida:

| Daraja | Nima | Qayerda tahrirlanadi |
|---|---|---|
| **Model** | rasmlar, xarakteristikalar | bir marta, model bo'yicha |
| **Ombor qatori** | narx, rang, IMEI, xotira, holat, SKU | har bir tovar uchun alohida |

Sabab: omborda "iPhone 17 Pro Max" 34 ta qator bo'lib yotishi mumkin. Rasmni
har biriga alohida biriktirish — 34 marta bir xil ish. Narx va IMEI esa
haqiqatan har qatorda boshqacha.

Shuning uchun interfeysda ikkita alohida joy kerak:

1. **Mahsulot formasi** (mavjud) — `productAction`, qator maydonlari
2. **Model kartochkasi** (yangi) — rasm va xarakteristika, `model_code` bo'yicha

Model kartochkasiga o'tish mahsulot formasidan `model_code` orqali bo'lsa
qulay: "Bu modelning rasmlari" tugmasi.

### Uchinchi daraja: saytdagi kartochka — 21.09 da qo'shildi

Sayt jamoasining talabi: bir xil telefonning 10 ta donasi katalogda 10 ta
kartochka bo'lib ko'rinmasin. Shuning uchun saytga chiqadigan element
kaliti shunday yig'iladi:

| Tovar holati | Katalog kaliti |
|---|---|
| Yangi | `model_code ~ xotira ~ ram ~ rang` |
| Ishlatilgan (`used`) | qatorning **o'z** `id` si |

Ya'ni endi uch daraja bor:

| Daraja | Nechta | Misol |
|---|---|---|
| Model | 1 | `iphone-17-pro-max` |
| **Sayt kartochkasi** | bir nechta | `iphone-17-pro-max` + 256Gb + silver |
| Ombor qatori | ko'p | o'sha konfiguratsiyadagi 8 ta dona |

Ishlatilgan texnika birlashmaydi — har bir dona o'ziga xos (batareya, IMEI).

**Bundan kelib chiqadigan uchta narsa:**

1. **`model_code` ni o'zgartirish — sayt uchun yangi kartochka.** Kalit
   konfiguratsiyadan yasalgani uchun xatoni tuzatsangiz eski kartochka
   yo'qoladi, o'rniga yangisi paydo bo'ladi: havola va statistika uziladi.
   Allaqachon saytga chiqqan tovarda formada tasdiq so'rang.

2. **Bir konfiguratsiyada har xil narx bo'lsa — eng pasti olinadi.**
   E'lon qilingan narxni ko'tarib bo'lmaydi, shuning uchun eng past narx
   tanlandi: u har doim bajarib bo'ladigan va'da. Lekin narxlar farq
   qilishi odatda **xato** — tekshiruv so'rovi
   `db/ipt_catalog_stage5.sql` ning 3-bo'limida.

3. **Sku, kafolat va tavsif guruhdagi eng kichik `id` li qatordan
   olinadi** — hammasi bitta qatordan. Har maydonni alohida olsak sku bir
   qatordan, tavsif boshqasidan kelib, mavjud bo'lmagan tovar yasalardi.

---

## 6. Rasmlar

Rasmlar **bizning serverda** saqlanadi — sayt jamoasi shuni so'ragan. Uchta
metod bor.

### 6.1 Serverga yuklash — `catalogUploadImage` (895)

```
POST /api/app/requestFile     (multipart)

params = {
  "method": "catalogUploadImage",
  "params": {
    "model_code": "iphone-17-pro-max",
    "color_code": "silver",
    "is_primary": true,
    "ord": 1
  }
}
file = <jpg | jpeg | png | webp, 10 MB gacha>
```

Javob:

```json
{ "oper": true, "data": { "id": 412,
  "file_name": "ipt_iphone-17-pro-max_412_20260919143012.jpg",
  "url": "http://37.140.216.159:9999/api/app/get-file?file=ipt_..." } }
```

Fayl nomini baza beradi, Java shu nom bilan diskka yozadi. **Har yuklashda nom
yangi** — ataylab: eski nomga yangi rasm qo'yilsa brauzer va sayt
optimizatori uzoq vaqt eskisini ko'rsatib turadi.

`color_code` berilsa rasm shu rangga bog'lanadi: xaridor saytda rangni
almashtirsa, rasm ham almashadi. Berilmasa — modelning umumiy rasmi.

`is_primary: true` bo'lsa o'sha model+rang bo'yicha qolgan rasmlarning asosiy
belgisi avtomatik tushiriladi.

### 6.2 Tashqi havolali rasm — `catalogSaveImage` (893)

Rasm boshqa joyda tursa yoki mavjud rasmning tartibi/rangi o'zgarsa:

```json
{ "method": "catalogSaveImage",
  "params": { "id": 412, "color_code": "black", "ord": 2, "is_primary": false } }
```

`id` berilmasa yangi yozuv yaratiladi, u holda `model_code` va `url` kerak.
Havola `https://` bilan boshlanishi shart. Tashqi havola qo'yilsa serverdagi
faylga bog'lanish uziladi.

### 6.3 O'chirish — `catalogDeleteImage` (894)

```json
{ "method": "catalogDeleteImage", "params": { "id": 412 } }
```

Bazadan yozuv o'chadi, saytga chiqmay qoladi. Serverdagi faylning o'zi
qoladi — uni o'chirish uchun alohida chaqiruv kerak bo'lardi. Yetim fayllar
sekin to'planadi; kerak bo'lganda tozalash jobi qo'yiladi.

### Ko'rish

`ipt_model_images_v` — modelning barcha rasmlari, to'liq havolasi bilan.

---

## 7. Xarakteristikalar — `catalogSaveAttributes` (892)

```json
{
  "method": "catalogSaveAttributes",
  "params": {
    "model_code": "case-magsafe-17",
    "attributes": {
      "acc_compat":   ["iphone-17-pro-max", "iphone-17-pro"],
      "acc_material": "silicone",
      "power_w":      20,
      "network_5g":   true
    }
  }
}
```

**Diqqat:** modelning barcha xarakteristikalari almashtiriladi, qo'shilmaydi.
Forma avval mavjudlarini o'qib, to'liq to'plamni qaytarib yuborishi kerak.
Barchasini o'chirish uchun `"attributes": {}`.

Har bir kod `ipt_s_attributes_v` da bo'lishi shart. U yerda `value_type`
(matn/son/mantiqiy) va `is_multi` bor: `is_multi = 0` bo'lgan kodga massiv
yuborilsa xato qaytadi.

Ko'rish: `ipt_model_attributes_v`.

---

## 8. Ommaviy to'ldirish — `catalogSaveProduct` (891)

Bitta model bo'yicha o'nlab qatorga bir xil qiymat qo'yish uchun. Gridda
qatorlarni belgilab, bittadan chaqiruv bilan to'ldirish:

```json
{
  "method": "catalogSaveProduct",
  "params": {
    "ids": [104721, 104722, 104723],
    "model_code": "iphone-17-pro-max",
    "category_code": "iphone",
    "brand_code": "apple",
    "item_condition": "new"
  }
}
```

Maydonlar va tekshiruvlar `productAction` dagi bilan **bir xil** — ikkalasi
ham `Ipt_Catalog.Apply_Catalog_Fields` dan o'tadi. Berilmagan maydon bu yerda
ham tegilmaydi.

Javob: `{ "oper": true, "data": { "updated": 3 } }`

Bu metod ~800 ta mavjud qatorni birinchi marta to'ldirish uchun eng tez yo'l.
Har biriga alohida forma ochish shart emas.

Fiskal maydonlar uchun ayniqsa qulay: telefon va aksessuarda `unit_code`
deyarli har doim `dona`, `vat_rate` esa bir xil. Ularni butun guruhga
bitta chaqiruv bilan qo'yib chiqish mumkin.

---

## 9. Ish ro'yxati ekrani — `ipt_catalog_todo_v`

Sotuvga tayyor, lekin katalog maydonlari to'liq emasligi uchun **saytga
chiqmayotgan** tovarlar. Nimasi yetishmayotgani ustunlarda ko'rsatilgan:

| Ustun | Ma'nosi |
|---|---|
| `no_price` | `retail_price_uzs` yo'q |
| `no_model_code` | `model_code` yo'q |
| `no_model_name` | `model_name` yo'q |
| `no_category` | `category_code` yo'q |
| `no_brand` | `brand_code` yo'q |
| `no_condition` | `item_condition` yo'q |
| `no_site_code` | filialning `site_code` i yo'q — bu tovar vitrina filialida emas |

Har birida `Y` yoki `N`. Ro'yxat bo'shashi — katalog to'liq to'ldirilgani.

> Bu view API'ga **chiqmaydi**: ichida `name` ustuni bor, unda ichki
> belgilar bo'lishi mumkin. Faqat ombor xodimlari uchun.

Ekranga qo'yish uchun `core_grids` ga yozuv kerak — `module_id` ni siz
belgilaysiz, men bilmayman.

### 9.1 Nom tahlili — `ipt_catalog_parse_v` (21.09)

Ish ro'yxati "nima qolgani" ni ko'rsatadi. Bu view esa **qolganini
to'ldirishga yordam beradi**.

Omborchi hamma narsani tovar nomiga yozgan:

```
iPhone 17 Pro Max 256Gb Silver sim+esim New imei 073349
```

Model, xotira, rang, SIM, holat, batareya, IMEI — hammasi shu yerda, faqat
alohida maydonlarga ajratilmagan. View har bir to'ldirilmagan qator uchun
nomdan **taxmin** qiladi:

| Ustun | Nima |
|---|---|
| `id`, `name`, `filial_code`, `quantity` | asl qator |
| `p_model_code`, `p_model_name` | model |
| `p_category_code`, `p_brand_code` | kategoriya, brend |
| `p_condition` | `new` / `used` |
| `p_storage_gb`, `p_ram_gb`, `p_color_code` | konfiguratsiya |
| `p_sim_type`, `p_market_code` | SIM, bozor kodi |
| `p_battery_pct`, `p_imei`, `p_serial` | b/u uchun |
| `topildi` | nechta maydon topilgani, **0–6** |

**View hech narsa yozmaydi.** Bu ataylab: yuklamada `Desert`/`Desret`,
`imei`/`imie` kabi xatolar bor, narx esa nomda umuman yo'q. Xodim ekranda
ko'z bilan tekshirib, to'g'rilarini belgilab `catalogSaveProduct` bilan
qo'llaydi.

Ekran talablari va ish tartibi — `MONELLO_WEB_FRONT_ISHLAR_UZ.md` ning
4-bo'limida.

**Qoidalar kodda emas.** Rang, brend, kategoriya va bozor kodi
`IPT_S_PARSE_ALIASES` jadvalidan o'qiladi, u esa ma'lumotnomalar
formasiga ulangan. Yangi rang uchrasa dasturchi kerak emas — forma orqali
qator qo'shiladi, view darhol yangi qoidani ishlatadi.

Bu ham `core_grids` orqali chiqariladi: ichida `name` ustuni bor, API'ga
chiqmaydi.

---

## 10. Huquqlar va xatolar

**Huquq.** `Core_App.Set_Method` rol tekshirmaydi — tekshiruv har bir
protsedura ichida. Katalog metodlarining hammasida `Ipt_Methods.Check_For_Seller`
turadi, ya'ni sotuvchi huquqi bo'lgan foydalanuvchi ishlata oladi.

**Xatolar.** Hammasi `ORA-20000` bo'lib keladi va tushunarli matn bilan:

```
"model_code" faqat kichik lotin harflari, raqam va "-" dan iborat bo'lishi kerak: iphone-16-pro-max
Bunday kategoriya yo'q yoki faol emas: iphonee
"old_price_uzs" joriy narxdan katta bo'lishi kerak — aks holda chizib tashlangan narx chegirma emas, qimmatlashish bo'lib ko'rinadi.
```

Xabarni foydalanuvchiga to'g'ridan-to'g'ri ko'rsatish mumkin, ular shu maqsadda
yozilgan. Xato bo'lsa butun tranzaksiya `rollback` bo'ladi — yarim saqlangan
holat bo'lmaydi.

---

## 11. Qurish kerak bo'lgan ekranlar

Ustuvorlik **21.09 da o'zgardi**: nom tahlili birinchi o'ringa chiqdi.

1. **Nom tahlili** (`ipt_catalog_parse_v`, 9.1) — ~800 qatorni
   to'ldirishning yagona tez yo'li. Bu bo'lmasa qolgani qo'lda ketadi.
2. **Mahsulot formasiga yangi maydonlar** — `productAction` allaqachon
   qabul qiladi, forma qo'shilsa bo'ldi. Fiskal uchtasi ham shu yerda.
3. **Ish ro'yxati** (`ipt_catalog_todo_v`) — nima qolganini ko'rsatadi.
4. **Ommaviy to'ldirish** — gridda belgilab, `catalogSaveProduct`.
5. **Model kartochkasi** — rasm yuklash va xarakteristika.
   Bularsiz sayt kartochkasi bo'sh ko'rinadi, lekin tovar baribir chiqadi.

Har ekran uchun aniq talablar va qabul mezoni —
`MONELLO_WEB_FRONT_ISHLAR_UZ.md`.

---

## 12. Ishga tushirishdan oldin

- `core_properties.catalog_file_url` haqiqiy manzilga qo'yilgan bo'lsin —
  rasm havolalari shu prefiks bilan yig'iladi. Hozir
  `http://37.140.216.159:9999`; domen olinsa **faqat shu qator**
  o'zgaradi, front kodda host qotirib yozilmasin
- serverda papka oldindan yaratilgan bo'lsin, Java uni o'zi yaratmaydi:
  `mkdir -p /opt/monello71/files/catalog`
- filiallarning `site_code` i to'ldirilgan bo'lsin — **bajarilgan**:
  `01030` → `mirobod`, `01060` va `01070` → `sebzor`.
  `01060` va `01070` bitta shourum, saytda bitta vitrina bo'lib ko'rinadi
  va qoldiqlari qo'shiladi. Katalog ekranlarida qoldiqni `site_code`
  bo'yicha guruhlang, `filial_code` bo'yicha emas
- `ipt_s_units` dagi birlik kodlari buxgalteriya bilan tekshirilsin —
  boshlang'ich ro'yxat taxminiy, fiskal chek uchun soliq
  klassifikatoridagi kodlar bilan mos bo'lishi kerak

---

## 13. Bog'liq hujjatlar

| Hujjat | Nima uchun |
|---|---|
| `MONELLO_WEB_FRONT_ISHLAR_UZ.md` | ekran-ekran ish ro'yxati va qabul mezoni |
| `MONELLO_WEB_YANGILANISH_UZ.md` | 19.09 dan keyingi o'zgarishlar ro'yxati |
| `MONELLO_WEB_MALUMOTNOMALAR_UZ.md` | 17 ta ma'lumotnomani bitta formadan tahrirlash |
| `MONELLO_CHAT_UZ.md` | chat formasi |
| `ABM_STORE_KATALOG_API_RU.md` | sayt jamoasi oladigan API |

---

*Monello backend · 19.09.2026, yangilandi 21.09.2026*
