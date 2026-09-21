# Monello web — front tomonda qilinadigan ishlar

**Kimga:** Monello web front jamoasiga
**Nima uchun:** baza va API tayyor. Quyida ekran-ekran nima qurilishi,
qaysi metod bilan va qanday tartibda.
**Sana:** 21.09.2026

Bu hujjat **ish ro'yxati**. Metodlarning to'liq tavsifi alohida
hujjatlarda:

| Mavzu | Hujjat |
|---|---|
| Katalog metodlari | `MONELLO_WEB_KATALOG_UZ.md` |
| Oxirgi o'zgarishlar | `MONELLO_WEB_YANGILANISH_UZ.md` |
| Ma'lumotnomalar formasi | `MONELLO_WEB_MALUMOTNOMALAR_UZ.md` |
| Chat | `MONELLO_CHAT_UZ.md` |

---

## 0. Umumiy qoidalar

### Chaqiruv

Hamma narsa bitta yo'ldan ketadi:

```
POST /api/app/request
{ "method": "...", "params": { ... } }
```

Bitta istisno — rasm yuklash:

```
POST /api/app/requestFile     (multipart/form-data)
params = {"method":"catalogUploadImage","params":{...}}
file   = <rasm fayli>
```

> `catalogUploadImage` **katta-kichik harfga sezgir**. Qolgan metodlar
> sezgir emas.

### Javob

```json
{ "success": true, "oper": true, "message": "...", "data": { ... } }
```

Xato bo'lsa `success: false` va `message` da **tayyor o'zbekcha matn**
keladi. Uni foydalanuvchiga **to'g'ridan-to'g'ri ko'rsating** — xabarlar
shu maqsadda yozilgan:

```
"model_code" faqat kichik lotin harflari, raqam va "-" dan iborat bo'lishi kerak
"accessories" — konteyner bo'lim, unga tovar qo'yilmaydi
"vat_rate" 0 va 100 oralig'ida bo'lishi kerak (foizda: 12 = 12%)
```

O'zingizdan "Xatolik yuz berdi" deb yozmang — ma'lumot yo'qoladi.

### Berilmagan maydon tegilmaydi

Hamma saqlash metodlarida bitta qoida: **so'rovda yo'q maydon bazada
o'zgarmaydi**. Ya'ni formani to'liq yuborish shart emas, faqat o'zgarganini
yuborsangiz ham bo'ladi. `null` yuborilsa — maydon tozalanadi. Ikkovi bir
narsa emas.

### Pul birliklari

| Maydon | Qanday yuboriladi |
|---|---|
| `retail_price_uzs`, `old_price_uzs` | **so'mda** (backend tiyinga o'giradi) |
| `vat_rate` | **foizda**: 12 = 12% |

---

## 1. Ustuvorlik

| # | Ekran | Hajmi | Nega shu tartibda |
|---|---|---|---|
| 1 | Mahsulot formasiga katalog maydonlari | O'rta | Boshqa hammasi shunga tayanadi |
| 2 | Ish ro'yxati | Kichik | Nima qolganini ko'rsatadi |
| 3 | **Nom tahlili** | O'rta | ~800 qatorni to'ldirishning yagona tez yo'li |
| 4 | Ommaviy to'ldirish | Kichik | 3-ekranning davomi |
| 5 | Ma'lumotnomalar formasi | O'rta | Bitta forma, 17 ta ma'lumotnoma |
| 6 | Model kartochkasi (rasm, xarakteristika) | O'rta | Sayt kartochkasi bezagi |
| 7 | Chat | Kichik | Mustaqil, katalogga bog'liq emas |

1–4 birgalikda **bitta ish**: ularsiz katalog to'ldirilmaydi va sayt bo'sh
turadi. 5–7 keyin.

---

## 2. Ekran: mahsulot formasiga katalog maydonlari

**Metod:** `ipt.productAction` — mavjud metod, yangi maydonlar qo'shildi.
Alohida "katalogni saqlash" tugmasi **kerak emas**.

### 2.1 Maydonlar guruhlari

Formani uch blokka bo'ling:

**A. Asosiy** — bularsiz tovar saytga chiqmaydi:

| Maydon | Turi | Manba |
|---|---|---|
| `model_code` | matn | qo'lda, `^[a-z0-9-]+$` |
| `model_name` | matn | qo'lda |
| `category_code` | select | `ipt_s_categories_v` |
| `brand_code` | select | `ipt_s_brands_v` |
| `item_condition` | select | `new` / `used` |
| `retail_price_uzs` | son | qo'lda, **so'mda** |

**B. Konfiguratsiya** — saytda kartochkani ajratadi:

`storage_gb`, `ram_gb`, `color_code` (select), `sku`, `warranty_months`,
`description_ru`, `description_uz`

**C. Fiskal** — chek uchun:

| Maydon | Turi | Tekshiruv |
|---|---|---|
| `mxik_code` | matn | faqat raqam, **aniq 17 ta** |
| `unit_code` | select, `ipt_s_units_v` | ro'yxatdan |
| `vat_rate` | son | 0–100, **foizda** |

**D. Faqat `item_condition = 'used'` bo'lganda ko'rinadi:**

`battery_health_pct`, `imei`, `serial`, `sim_type` (select),
`market_code` (select), `replaced_parts`, `has_box`, `has_charger`

Yangi texnikada bu blok **yashirilsin**. Sabab shakliy emas: bu maydonlar
`item_condition = 'used'` bo'lmasa saytga **umuman chiqmaydi** — bazada
saqlanadi, lekin API javobiga qo'shilmaydi. Yangi tovarga `sim_type`
yozgan xodim uni saytda ko'rmay, "nega yo'qoldi" deb o'ylaydi.

### 2.2 Uchta ehtiyot chorasi

**Kategoriya dropdowni.** `ipt_s_categories_v.is_container = 1` bo'lgan
ikkita kod (`accessories`, `used`) — bo'lim sarlavhasi, tovar kategoriyasi
emas. `<optgroup>` qiling yoki `disabled`. Baza baribir to'sadi, lekin
tanlab bo'lgandan keyin xato olish yomon.

**`vat_rate` yoniga `%` belgisi.** Tizimda qolgan hamma stavka ×100 bilan
saqlanadi, bu esa yo'q. Xodim `1200` yozib yuborishi mumkin —
belgi turgani yaxshi.

**`model_code` ni tahrirlashga tasdiq.** Saytdagi kartochka kaliti
`model_code ~ xotira ~ ram ~ rang` dan yig'iladi. Ya'ni `model_code` ni
o'zgartirish sayt uchun **eski kartochkani o'chirib, yangisini yasash**.
Allaqachon saytga chiqqan tovarda shuni so'rang:

> "Bu tovar saytda ko'rinyapti. `model_code` ni o'zgartirsangiz sayt uni
> yangi tovar deb hisoblaydi. Davom etamizmi?"

---

## 3. Ekran: ish ro'yxati

**Manba:** `ipt_catalog_todo_v` — view, metod emas. `core_grids` orqali
chiqariladi, `module_id` ni siz belgilaysiz.

Sotuvga tayyor, lekin **saytga chiqmayotgan** tovarlar. Nimasi
yetishmayotgani ustunlarda:

| Ustun | `Y` bo'lsa |
|---|---|
| `no_price` | narx yo'q |
| `no_model_code` | model kodi yo'q |
| `no_model_name` | model nomi yo'q |
| `no_category` | kategoriya yo'q |
| `no_brand` | brend yo'q |
| `no_condition` | holat yo'q |
| `no_site_code` | tovar vitrina filialida emas |

**Qilinadigan ish:** grid + `Y` bo'lgan kataklarni qizil qilish + qatorga
bosilsa mahsulot formasi ochilsin.

Ro'yxat bo'shashi — katalog to'liq to'ldirilgani. Bu loyihaning
o'lchagichi, shuning uchun jami sonni tepada katta qilib yozing.

---

## 4. Ekran: nom tahlili — eng ko'p vaqt tejaydigani

**Manba:** `ipt_catalog_parse_v` — view, `core_grids` orqali.

### Nima uchun kerak

Omborchi hamma narsani nomga yozgan:

```
iPhone 17 Pro Max 256Gb Silver sim+esim New imei 073349
```

Model, xotira, rang, SIM, holat, batareya, IMEI — hammasi shu yerda.
~800 qatorni qo'lda ko'chirish haftalar oladi. View nomdan taxmin qiladi:

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

### Ekran talablari

1. Grid, `topildi desc` bo'yicha saralangan — ishonchlilari tepada.
2. Har bir `p_` ustuni **tahrirlanadigan**. Taxmin noto'g'ri bo'lsa xodim
   shu yerda tuzatadi, mahsulot formasini ochmaydi.
3. `topildi <= 3` qatorlar rang bilan ajratilsin — ko'z bilan ko'rish shart.
4. **Narx ustuni bo'sh keladi** va qo'lda kiritiladi. Nomda narx yo'q.
5. Checkbox bilan belgilash + "Belgilanganlarni saqlash" tugmasi.
6. `p_model_code` bo'yicha guruhlash/filtr — eng tez ishlash usuli shu:
   bir xil modeldagi 30 qatorni belgilab, narxini bir marta yozib, birdan
   saqlash.

### Saqlash

Belgilangan qatorlar `catalogSaveProduct` ga boradi — bitta chaqiruvda
ko'p qator. Tafsiloti `MONELLO_WEB_KATALOG_UZ.md` ning 8-bo'limida.

### View hech narsa yozmaydi

Bu ataylab. Yuklamada `Desert`/`Desret`, `imei`/`imie` kabi xatolar bor,
narx esa umuman yo'q. Avtomat qo'llash noto'g'ri ma'lumotni 800 qatorga
tarqatardi. **Tasdiqlovchi — odam.**

### Qoidalarni xodim o'zi qo'shadi

Rang, brend, kategoriya va bozor kodi `IPT_S_PARSE_ALIASES` dan o'qiladi,
u esa ma'lumotnomalar formasiga ulangan (5-bo'lim). Yangi rang uchrasa
dasturchi kerak emas — forma orqali qator qo'shiladi va view darhol
yangi qoidani ishlatadi.

Shuning uchun **5-ekran 4-ekrandan oldin yoki u bilan birga** tayyor
bo'lsa yaxshi.

---

## 5. Ekran: ma'lumotnomalar formasi

**Metodlar:** `dictList`, `dictRows`, `dictSave`, `dictDelete`
**To'liq tavsif:** `MONELLO_WEB_MALUMOTNOMALAR_UZ.md`
**Maket:** `prototype/dictionary/index.html` — bitta fayl, build kerak emas

### Asosiy g'oya

Bitta forma, **17 ta** ma'lumotnoma. Har biri uchun alohida kod yozilmaydi:
jadval ustunlari ham, tahrir oynasidagi inputlar ham `dictList`
qaytaradigan metadata'dan quriladi.

| Metadata | Formada |
|---|---|
| `type: S` | matn, `max_len` bilan |
| `type: N` | `<input type="number">` |
| `type: B` / `F` | checkbox |
| `type: L` | `<select>`, variantlar `lov` dan |
| `required: true` | qizil yulduzcha |
| `can_insert: false` | «Qo'shish» o'chadi |
| `can_delete: false` | «O'chirish» yo'q |
| `lock_reason` | tepada sariq izoh |
| `order_column` | saralash tartibi |
| `auto_code: true` | **kod maydoni ko'rsatilmaydi** |

Tekshirish usuli: ro'yxatdan boshqa ma'lumotnomani tanlang. Ustunlar va
input turlari o'zgarishi, sahifa kodi esa o'sha-o'sha qolishi kerak.

### `auto_code` — yangi

`dictList` javobida yangi bayroq. `true` bo'lsa kod ma'noga ega emas, uni
baza o'zi qo'yadi:

| | `auto_code: false` (16 ta) | `auto_code: true` (`parse_aliases`) |
|---|---|---|
| Qo'shish oynasi | kod maydoni bor | kod maydoni **yo'q** |
| `dictSave` | `"code": "..."` bilan | `code` **siz** |
| Kodni qayerdan olasiz | o'zingiz yuborgansiz | javobdagi `"code"` dan |

Tahrirlashda farq yo'q — `code` har doim yuboriladi.

### Bloklangan ma'lumotnomalar

| Ma'lumotnoma | Qo'shish | O'chirish |
|---|---|---|
| Sdelka holatlari | ✗ | ✗ |
| Tovar holatlari | ✗ | ✗ |
| Filiallar | ✗ | ✗ |
| Tovar turlari | ✓ | ✗ |

Sabab `lock_reason` da keladi va foydalanuvchiga **ko'rsatilishi kerak** —
aks holda "nega tugma ishlamayapti" degan savol chiqadi.

---

## 6. Ekran: model kartochkasi — rasm va xarakteristika

### 6.1 Rasmlar

| Metod | Nima qiladi |
|---|---|
| `catalogUploadImage` | fayl yuklash (`/api/app/requestFile`) |
| `catalogSaveImage` | tashqi havolali rasm |
| `catalogDeleteImage` | o'chirish |

Talablar:

- Drag & drop + tartibni sichqoncha bilan o'zgartirish
- Birinchi rasm — asosiy (saytda kartochkada shu ko'rinadi)
- Rasm **modelga** biriktiriladi, qatorga emas: bir model 20 ta qator
  bo'lsa ham rasm bir marta yuklanadi
- `color_code` tanlash imkoni bo'lsin: berilsa rasm shu rangga bog'lanadi
  va xaridor saytda rangni almashtirsa rasm ham almashadi. Berilmasa —
  modelning umumiy rasmi

> **Host kodda qotirib yozilmasin.** Havola prefiksi bazadan keladi
> (`core_properties.catalog_file_url`). Hozir
> `http://37.140.216.159:9999`, domen olinsa `https` ga o'tadi — o'shanda
> front tegilmasligi kerak.

### 6.2 Xarakteristikalar

**Metod:** `catalogSaveAttributes`

Ekran, protsessor, kamera kabi maydonlar. Ular ham **modelga** tegishli.
Ro'yxat `ipt_s_attributes_v` dan keladi — ya'ni yangi xarakteristika
qo'shish uchun front tegilmaydi, ma'lumotnomaga qator qo'shiladi.

> **Eng oson tushib qolinadigan joy:** `catalogSaveAttributes` modelning
> barcha xarakteristikalarini **almashtiradi**, qo'shmaydi. Forma avval
> `ipt_model_attributes_v` dan mavjudlarini o'qib, **to'liq to'plamni**
> qaytarib yuborishi kerak. Faqat o'zgarganini yuborsangiz qolgani
> o'chib ketadi.
>
> Bu `productAction` ning qoidasiga **teskari** — o'sha yerda berilmagan
> maydon tegilmaydi. Ikkalasini aralashtirib yubormang.

Har kodda `value_type` (matn/son/mantiqiy) va `is_multi` bor: `is_multi = 0`
bo'lgan kodga massiv yuborilsa xato qaytadi.

Bularsiz tovar saytga baribir chiqadi, faqat kartochkasi bo'sh ko'rinadi.

---

## 7. Ekran: chat

**Metod:** `POST /api/chat` (odatdagi `/api/app/request` **emas**)
**Holat:** `GET /api/chat/status`
**To'liq tavsif:** `MONELLO_CHAT_UZ.md`
**Maket:** `prototype/chat/index.html`

Oddiy chat oynasi: savol maydoni, javoblar tarixi. Nimalar so'raladi —
filiallar, savdolar, rassrochkalar, qarzdorlar, sdelkalar.

### Ikkita majburiy detal

**1. Har javob ostida qaysi tool ishlatilgani ko'rinsin.** Bosilganda
o'sha tool qaytargan JSON ochilsin.

Bu bezak emas. Xodim raqam qayerdan kelganini tekshira olmasa, chatga
ishonib bo'lmaydi — ayniqsa qarzdorlik raqamlariga.

**2. `GET /api/chat/status` bilan boshlang.** Kalit sozlanmagan bo'lsa
chat oynasini ochmang, "chat sozlanmagan" deb yozing. Aks holda
foydalanuvchi savol yozib, keyin xato oladi.

### Nimani kutmaslik kerak

Model SQL yozmaydi va yoza olmaydi — u faqat beshta ro'yxatdan o'tgan
**o'qish** metodini chaqiradi. Telefon, PINFL va manzil chatga chiqmaydi.
"To'lovni kiritib yubor" kabi so'rovga rad javobi keladi — bu xato emas,
shunday o'ylangan.

Filial cheklovi o'z-o'zidan ishlaydi: chaqiruv foydalanuvchining JWT'i
bilan ketadi, sotuvchi faqat o'z filialining raqamlarini ko'radi.

---

## 8. Nazorat paneli — HOZIRCHA EMAS

`prototype/dashboard/` da maket bor, lekin **Monello web ga qo'yilmaydi**.

Sabab: `reportDebt`, `reportOverdue`, `reportClients`, `reportTrades`
metodlarida filial filtri **ataylab yo'q** — boshqaruv paneliga butun
tarmoq kerak. Ular `/api/report/*` yo'li va `report` qamrovli token uchun
mo'ljallangan.

Bugun ularga huquq tekshiruvi qo'shildi: faqat `report` tokeni egasi
chaqira oladi. Oddiy foydalanuvchi `/api/app/request` orqali chaqirsa
xato oladi.

Monello web ga ham nazorat paneli kerak bo'lsa — **avval rahbariyat roli
kelishilishi kerak**, keyin `Ipt_Dashboard.Check_Access` ga o'sha rol
sharti qo'shiladi. Hozir uni ekranga qo'ysangiz har bir sotuvchi butun
tarmoqning qarzdorlik raqamlarini ko'radi.

---

## 9. Har ekran uchun qabul mezoni

Ekran tayyor deyilishi uchun:

- [ ] Xato xabari backenddan kelgan holicha ko'rsatiladi
- [ ] Bo'sh ro'yxat holati bor ("hammasi to'ldirilgan" / "ma'lumot yo'q")
- [ ] Saqlashdan keyin ro'yxat yangilanadi, sahifa qayta yuklanmaydi
- [ ] Ikki marta bosilsa ikkita so'rov ketmaydi (tugma bloklanadi)
- [ ] Majburiy maydonlar formada belgilangan, backend xatosini kutmaydi
- [ ] Filial `site_code` bo'yicha guruhlangan (10-bo'limga qarang)

---

## 10. Bitta oson unutiladigan narsa: filial va vitrina

| Filial | `site_code` |
|---|---|
| 01030 | `mirobod` |
| 01060 | `sebzor` |
| 01070 | `sebzor` |

`01060` va `01070` — **bitta shourum**, ikkita hisob filiali. Saytda ular
bitta vitrina bo'lib ko'rinadi, qoldiqlari qo'shiladi.

**Shuning uchun:** katalog bilan bog'liq ekranlarda qoldiqni `site_code`
bo'yicha guruhlang, `filial_code` bo'yicha emas. Aks holda xodim gridda
"Sebzor 3" va "Sebzor 2" ko'radi, saytda esa "Sebzor 5" — va raqamlar
nega mos kelmayapti deb o'ylaydi.

`site_code` i bo'sh filialdagi tovar saytga **umuman chiqmaydi**.

---

## 11. Tayyor maketlar

Uchalasi ham bitta fayl, build kerak emas — brauzerda ochiladi:

| Maket | Fayl | Rejim |
|---|---|---|
| Ma'lumotnomalar | `prototype/dictionary/index.html` | demo / jonli |
| Chat | `prototype/chat/index.html` | demo / jonli |
| Nazorat paneli | `prototype/dashboard/index.html` | demo / jonli |

**Demo** rejimda backend kerak emas — maket to'liq ko'rinadi.
**Jonli** rejimda manzil va token so'raladi.

Bular tayyor komponent emas, **kelishuv hujjati**: qaysi ma'lumot qayerda
turishi va qanday ishlashi shu yerda ko'rinadi. Dizayn va stack siznikiki.

---

## 12. Nimani kutish kerak

Front ishga tushishidan oldin backend tomonda bularning bo'lishi shart:

| Nima | Kim | Holati |
|---|---|---|
| Baza o'zgarishlari | bajarildi | ✅ |
| Java deploy (`/api/chat`, `/api/mcp`) | backend | ⏳ hali deployda emas |
| `ANTHROPIC_API_KEY` | backend | ⏳ chat uchun |
| `core_grids` yozuvlari (ish ro'yxati, nom tahlili) | siz + backend | ⏳ `module_id` sizdan |
| Rasm papkasi serverda | backend | ⏳ `mkdir -p /opt/monello71/files/catalog` |

`core_grids` — yagona joy, u yerda sizdan ma'lumot kerak: qaysi
`module_id` ga qo'yish. Shuni ayting, qolganini backend qiladi.

---

*Monello backend · 21.09.2026*
