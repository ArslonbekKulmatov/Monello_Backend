# Katalog moduli — qilinadigan ishlar

ABM Store sayti uchun katalog API. Talablar hujjati: «ABM Store — katalog API
talablari», v1.0, 27.08.2026.

**Holat, 19.09.2026:** baza tomoni ishga tushirildi — jadvallar, viewlar,
`Ipt_Catalog` paketi va `core_methods` yozuvlari bazada. Qolgani: ilovani
deploy qilish, web interfeysi, ma'lumot to'ldirish.

---

## 0. Tovar saytga qachon chiqadi

Butun ishning mantig'i shu yerda. `ipt_catalog_v` **yettita** shartni talab
qiladi; bittasi bajarilmasa tovar API'da umuman ko'rinmaydi.

| Shart | Kim qo'yadi | Qayerda |
|---|---|---|
| `state = 'S'`, `quantity > 0` | mavjud mantiq | tegilmaydi |
| `retail_price_uzs` | web | mahsulot formasi |
| `model_code` | web | mahsulot formasi / ommaviy |
| `model_name` | web | mahsulot formasi / ommaviy |
| `category_code` | web | mahsulot formasi / ommaviy |
| `brand_code` | web | mahsulot formasi / ommaviy |
| `item_condition` | web | mahsulot formasi / ommaviy |
| filialning `site_code` i | baza | bir marta, 2 qator |

Bu ataylab qat'iy: yarim to'ldirilgan kartochka vitrinada turgandan ko'ra
umuman turmagani yaxshi.

Rasm va xarakteristika bu ro'yxatda **yo'q** — ularsiz ham tovar saytga
chiqadi, faqat kartochkasi bo'sh ko'rinadi.

---

## 1. Bajarilgan ishlar

| Qism | Holat |
|---|---|
| Baza sxemasi (24 maydon, 7 ma'lumotnoma, 2 model jadvali) | ✅ bazada |
| `Ipt_Catalog` paketi (8 metod) | ✅ bazada |
| `Product_Action` integratsiyasi | ✅ bazada |
| `core_methods` yozuvlari (889–895) | ✅ faol |
| `/api/catalog/*` endpointlari (Java) | ✅ yozildi, **deploy qilinmagan** |
| Rasmlarni serverga yuklash | ✅ yozildi |
| Sayt jamoasiga spetsifikatsiya | ✅ `docs/ABM_STORE_KATALOG_API_RU.md` |
| Web jamoasiga spetsifikatsiya | ✅ `docs/MONELLO_WEB_KATALOG_UZ.md` |
| Web interfeysi | ❌ |
| Ma'lumot (~800 pozitsiya) | ❌ |
| Server papkasi va `catalog_file_url` | ❌ |
| Token | ❌ |

Sayt so'ragan **barcha maydonlar** qoplangan: talablar hujjatining 5, 5.2,
5.3 va 7.4 bo'limlaridagi maydonlarning hammasi bor.

Ro'yxatdan o'tgan metodlar tekshirildi: 889 `catalogProducts`,
890 `catalogStock`, 891 `catalogSaveProduct`, 892 `catalogSaveAttributes`,
893 `catalogSaveImage`, 894 `catalogDeleteImage`, 895 `catalogUploadImage`.
`add_log` qiymatlari ham to'g'ri — o'qish metodlarida `N`, yozishda `Y`.

---

## 2. A qism — Monello webda, shu ketma-ketlikda

### 2.1 Ma'lumotnomalarni o'qishni ulash

Dropdownlar uchun. Jadvallar skriptlar bilan to'ldirilgan, faqat o'qish kerak.
Birinchi, chunki formani bularsiz qurib bo'lmaydi.

- [ ] `ipt_s_categories_v` — kategoriya (24 kod)
- [ ] `ipt_s_brands_v` — brend
- [ ] `ipt_s_colors_v` — rang
- [ ] `ipt_s_sim_types_v` — SIM turi
- [ ] `ipt_s_market_codes_v` — bozor kodi
- [ ] `ipt_s_replaced_parts_v` — almashtirilgan qism
- [ ] `ipt_s_attributes_v` — xarakteristikalar, turi bilan

Hammasi bir xil shaklda: `code` / `name_ru` / `name_uz` / `ord`.

### 2.2 Mahsulot formasiga katalog bo'limi

**Eng muhim qadam.** Yettita shartdan oltitasi shu yerda hal bo'ladi.
Boshqa hech narsa qilinmasa ham, shundan keyin tovarlarni saytga chiqarish
mumkin.

- [ ] 24 ta yangi maydon (to'liq ro'yxat `docs/MONELLO_WEB_KATALOG_UZ.md` da)
- [ ] Dropdownlar 2.1 dagi viewlardan
- [ ] `item_condition = used` tanlanganda b/u maydonlari ochiladi:
      `battery_health_pct`, `imei`, `serial`, `sim_type`, `market_code`,
      `replaced_parts`, `has_box`, `has_charger`
- [ ] `phys_filial_code` ham formada bo'lsin — bo'sh bo'lsa hisob filiali
      olinadi, ular har doim bir xil emas

> **Eng qimmat xato shu yerda.** Formada tegilmagan maydonni JSON'ga
> **umuman qo'shmang**. Kalit yo'q bo'lsa qiymat saqlanadi; kalit `null`
> yoki `""` bilan kelsa maydon **tozalanadi** (Oracle'da bo'sh satr = NULL).
> Ko'p framework to'ldirilmagan input'ni aynan shunday jo'natadi — shu qoida
> buzilsa to'ldirilgan ma'lumot bitta tahrirdan keyin o'chadi.

### 2.3 Ish ro'yxati ekrani

To'ldirish ishidan **oldin** kerak: aks holda xodim nimani to'ldirishni
bilmaydi.

- [ ] `ipt_catalog_todo_v` bo'yicha grid
- [ ] Yetishmayotgan maydon ustunlari ko'rinsin: `no_price`, `no_model_code`,
      `no_model_name`, `no_category`, `no_brand`, `no_condition`,
      `no_site_code`
- [ ] Qolgan/tayyor hisoblagichlari
- [ ] `CORE_GRIDS` ga yozuv. `module_id` kerak:

      select module_id, code, name from core_modules where state = 'A';

> Bu view API'ga **chiqmaydi** — ichida `name` ustuni bor, unda ichki
> belgilar bo'lishi mumkin. Faqat ombor xodimlari uchun.

### 2.4 Ommaviy to'ldirish

~800 qatorni to'ldirishni haqiqatda bajariladigan qiladi. «iPhone 17 Pro Max»
omborda 34 marta yotgan bo'lsa, `model_code` / `category_code` / `brand_code` /
`item_condition` ni bir marta qo'yish kifoya.

- [ ] Gridda checkbox bilan bir nechta qator tanlash
- [ ] Yuqorida umumiy forma → `catalogSaveProduct` (`ids` massivi bilan)
- [ ] Natijani ko'rsatish: javobda `updated` soni keladi

Tekshiruvlar `productAction` dagi bilan bir xil — ikkalasi ham
`Apply_Catalog_Fields` dan o'tadi.

### 2.5 Model kartochkasi — rasm va xarakteristika

Bu yerdan boshlab tovarning saytga chiqishiga ta'sir yo'q, kartochka
sifatiga ta'sir bor. Alohida ekran, chunki rasm va xarakteristika
**modelga** bog'langan, ombor qatoriga emas. Mahsulot formasidan
`model_code` bo'yicha o'tiladigan qilinsa qulay.

Rasmlar:
- [ ] Ro'yxat — `ipt_model_images_v`
- [ ] Yuklash — `POST /api/app/requestFile`, multipart,
      method `catalogUploadImage`
- [ ] Rangga biriktirish, asosiy rasmni belgilash, tartib — `catalogSaveImage`
- [ ] O'chirish — `catalogDeleteImage`
- [ ] Tashqi havola qo'shish — `catalogSaveImage` (`id` siz)

Xarakteristikalar:
- [ ] Ro'yxat — `ipt_model_attributes_v`
- [ ] Turi `ipt_s_attributes_v` dan: `is_multi` bo'lsa ko'p tanlov
- [ ] Saqlash — `catalogSaveAttributes`

> **Tuzoq:** `catalogSaveAttributes` modelning **barcha** xarakteristikalarini
> almashtiradi. Forma avval mavjudini o'qib, to'liq to'plamni qaytarib
> yuborishi kerak, aks holda yuborilmaganlari o'chadi. Barchasini o'chirish
> uchun `"attributes": {}`.

### 2.6 (ixtiyoriy) Ma'lumotnoma boshqaruvi

Yangi brend yoki rangni bazaga kirmasdan qo'shish. Hozircha shart emas —
ro'yxatlar to'ldirilgan.

---

## 3. B qism — web tayyor bo'lgandan keyin

### 3.1 Ilovani deploy qilish

`/api/catalog/*` endpointlari hali yo'q: Java kodi `claude/kind-feynman-9ywzwm`
shoxida. Baza skriptlari qo'llangani bilan bu qism ishlamaydi.

- [ ] Shoxni asosiyga qo'shish, build, deploy
- [ ] `GET /api/app/health` bilan ilova ko'tarilganini tekshirish

### 3.2 Serverni tayyorlash

- [ ] **Rasmlar papkasi.** `Files.copy` papkani o'zi yaratmaydi — bo'lmasa
      yuklash «Could not store the file» bilan tugaydi:

      mkdir -p /opt/monello71/files/catalog
      chown <app_user> /opt/monello71/files/catalog

- [ ] **Rasm havolasi prefiksi:**

      update core_properties
         set param_value = 'https://<domen>/api/app/get-file?file='
       where param_name = 'catalog_file_url';
      commit;

      Tekshirish: havola inkognito oynada, avtorizatsiyasiz ochilishi kerak.

- [ ] **Disk hajmi.** 800 × ~3 rasm × ~1 MB ≈ 2.5 GB.

### 3.3 Vitrina filiallarini belgilash

Ikki qator, lekin yettinchi shart shu. Qo'yilmasa qolgan hamma maydon
to'ldirilgan bo'lsa ham **hech bir tovar** saytga chiqmaydi.

- [ ] Filiallarni ko'rish va kodlarni aniqlash:

      select code, name, type from ipt_s_filials order by code;

- [ ] Belgilash:

      update ipt_s_filials set site_code = 'mirobod' where code = '?????';
      update ipt_s_filials set site_code = 'sebzor'  where code = '?????';
      commit;

### 3.4 Ma'lumot to'ldirish

**Loyihaning eng uzun qismi.** Dasturchi ishi emas — ombor ishi.
~800 pozitsiya. Tartib: avval ommaviy, keyin bittadan.

- [ ] Ish ro'yxatini model bo'yicha saralab ko'rish
- [ ] **Ommaviy:** `model_code`, `category_code`, `brand_code`,
      `item_condition` — guruh-guruh, `catalogSaveProduct` bilan
- [ ] **Qator darajasida:** `retail_price_uzs` — eng ko'p vaqt oladigani,
      xarid narxidan hisoblab bo'lmaydi, har biriga qo'lda
- [ ] `color_code`, `storage_gb`, `ram_gb`, `sku`
- [ ] `phys_filial_code` — «Mirobodda» holati uchun
- [ ] B/u texnika: IMEI, batareya, SIM, bozor kodi, almashtirilgan qism
- [ ] Todo ro'yxati bo'shaguncha davom etish

Jarayonni kuzatish:

    select count(*) qolgan from ipt_catalog_todo_v;
    select count(*) tayyor from ipt_catalog_v;

> **Xodim huquqi.** Katalogni to'ldiradigan odamda **21-rol bo'lmasin**:
> `Check_For_Seller` aynan shu rolni (5-modul roli bilan birga) to'sadi va
> «У вас нет доступа к операциям» chiqadi. Agar o'sha odam haqiqatan 21-rolda
> ishlashi kerak bo'lsa — tekshiruvni katalog metodlaridan olib tashlash
> kerak bo'ladi, lekin bu `Product_Action` ga ham tegadi, shuning uchun
> avval rolni ko'rib chiqish arzonroq.

> **Nomni avtomatik ajratish tavsiya qilinmaydi.** Yuklamada `imei`/`imie`/
> `i mei`, `Desert`/`Desret` kabi xatolar bor — qoralama ajratish qilinsa
> ham ko'z bilan tekshirish kerak, aks holda xato vitrinaga chiqadi.

### 3.5 Rasm va xarakteristika

- [ ] Har model uchun kamida bitta `is_primary` rasm — sayt ro'yxat
      plitkasiga shuni oladi
- [ ] Rangga bog'langan rasmlar: xaridor rangni almashtirsa rasm ham almashadi
- [ ] Aksessuarlarda `acc_compat` — «bu g'ilof qaysi telefonga to'g'ri
      keladi» shundan chiqadi

### 3.6 Tokenni yaratish

    sqlplus ... @db/create_api_tokens.sql

- [ ] Sayt uchun token, qamrovi `catalog`
- [ ] Test uchun alohida token — sayt jamoasi so'ragan

Skript tokenni ishga tushirish paytida so'raydi va faylda saqlamaydi. Bazada
faqat SHA-256 xeshi qoladi — tokenni tiklab bo'lmaydi. Sayt jamoasiga bir
marta xavfsiz kanal orqali berib, o'zingizda saqlamaysiz.

### 3.7 Tekshirish — sayt jamoasiga berishdan oldin

Bazada:

```sql
select count(*) from ipt_catalog_v;

declare v clob;
begin
  Ipt_Catalog.Get_Products('{"params":{"page":1,"per_page":1}}', v);
  dbms_output.put_line(substr(v, 1, 4000));
end;
/
```

API:

```bash
curl -H "Authorization: Bearer $TOKEN" \
     "https://<domen>/api/catalog/products?page=1&per_page=5"

curl -H "Authorization: Bearer $TOKEN" \
     "https://<domen>/api/catalog/stock"

# Token noto'g'ri bo'lsa 401 kutiladi
curl -i -H "Authorization: Bearer yomon" "https://<domen>/api/catalog/stock"
```

**Qamrovni albatta sinang:**

```bash
curl -i -H "Authorization: Bearer $TOKEN" "https://<domen>/api/report/debt"
```

**401 kelishi shart.** 200 qaytsa — sayt jamoasi qarzdorlik va mijoz
ismlarini ko'ryapti, darhol to'xtatish kerak.

Tekshirish nuqtalari:
- [ ] `total` to'ldirilgan pozitsiyalar soniga teng (nol bo'lsa — bu ulanish
      emas, ma'lumot muammosi)
- [ ] `price` butun son, somda
- [ ] `quantity` da ikkala shourum bor, nol bo'lsa ham
- [ ] `images` havolalari inkognito oynada ochiladi
- [ ] `attributes` da `acc_compat` massiv, `power_w` son, `network_5g` mantiqiy
- [ ] B/u tovarda `battery_health_pct` bor, yangisida yo'q
- [ ] `updated_since` bilan kamroq qator qaytadi

### 3.8 Sayt jamoasiga berish

- [ ] Token + manzil + `docs/ABM_STORE_KATALOG_API_RU.md`
- [ ] Undan oldin 4-bo'limdagi ikkita qarorni yopish

---

## 4. Yopilmagan ikkita qaror

Ulanishdan **oldin** hal qilish kerak, keyin qimmatroq.

- [ ] **`id` nimani anglatadi.** Hozir ombor qatorining id'si. Bir xil ikkita
      yangi apparat ikkita yozuv bo'lib keladi. Agar yopishtirishni biz
      qiladigan bo'lsak, `id` konfiguratsiya identifikatoriga aylanadi va
      sayt bir marta qayta bog'lashi kerak bo'ladi.

- [ ] **`quantity` nimani anglatadi.** Hozir hisobdagi bog'lanish.
      `phys_filial_code` to'ldirilmaguncha «Mirobodda» holati API'da
      ko'rinmaydi. Bu variantda samovivozni jangovar rejimda ishga
      tushirmaslik kerak.

### Sayt jamoasidan kutilayotgani

- [ ] Server IP manzili (cheklov qo'yish uchun)
- [ ] Qaysi filiallar `mirobod` va `sebzor`
- [ ] `model_code` shakllantirish qoidalari

---

## 5. Ma'lum cheklovlar

Bular xato emas, ongli qarorlar — lekin bilib qo'yish kerak.

**Yetim fayllar.** Rasm yozuvi o'chirilganda serverdagi faylning o'zi
qolaveradi. Sekin to'planadi. Kerak bo'lsa keyin tozalash jobi qilinadi.

**N+1 so'rov.** Har bir tovar uchun rasm va xarakteristika alohida
so'raladi. 500 tovar ≈ 1000 so'rov. Indekslar bor, soatiga bir marta
so'ralganda muammo emas. Sekinlashsa — model bo'yicha keshlash kerak.

**`Set_Method_File` registrga sezgir.** `Core_App.Set_Method` metod nomini
`lower()` bilan qidiradi, `Set_Method_File` esa **aniq** solishtiradi. Rasm
yuklashda frontend `catalogUploadImage` ni harfma-harf to'g'ri yuborishi
kerak, aks holda «Unknown method».

**`/request/v2` da `oper` va `message` yo'q.** Mavjud xatti-harakat:
`res = outObj` bilan ular tashlab yuboriladi. Saqlash natijasi haqidagi
xabar kerak bo'lsa eski `/api/app/request` ishlatiladi.

**Rol tekshiruvi metod darajasida emas.** `Core_App.Set_Method` rol
tekshirmaydi — tekshiruv har bir protseduraning ichida. Katalog
metodlarining hammasida `Ipt_Methods.Check_For_Seller` turadi.

**IP cheklovi yo'q.** Sayt jamoasi server manzilini hali yubormagan.
Manzil kelganda qo'shiladi.

---

## 6. Fayllar

| Fayl | Nima |
|---|---|
| `db/ipt_catalog_stage1.sql` | Asosiy maydonlar, kategoriya, brend, `ipt_catalog_v` |
| `db/ipt_catalog_stage2.sql` | `core_api_tokens` jadvali |
| `db/ipt_catalog_stage3.sql` | Qolgan maydonlar, rasm va xarakteristika jadvallari |
| `db/ipt_catalog_package.sql` | `Ipt_Catalog` paketi, `core_methods` yozuvlari |
| `db/ipt_catalog_product_action.sql` | `Product_Action` — qo'lda qo'llanadi |
| `db/create_api_tokens.sql` | Token yaratish, qamrov bilan |
| `docs/MONELLO_WEB_KATALOG_UZ.md` | Web jamoasiga spetsifikatsiya |
| `docs/ABM_STORE_KATALOG_API_RU.md` | Sayt jamoasiga spetsifikatsiya |
| `src/.../catalog/controllers/CCatalog.java` | `/api/catalog/*` |
| `src/.../core/services/SExternalApi.java` | Token tekshirish, metod chaqirish, qamrov |

### Metodlar

| Metod | id | Endpoint | Nima qiladi |
|---|---|---|---|
| `catalogProducts` | 889 | `GET /api/catalog/products` | Sayt uchun katalog |
| `catalogStock` | 890 | `GET /api/catalog/stock` | Narx va qoldiq |
| `ipt.productAction` | 705 | `POST /api/app/request` | Mahsulot + katalog maydonlari |
| `catalogSaveProduct` | 891 | `POST /api/app/request` | Ommaviy to'ldirish |
| `catalogSaveAttributes` | 892 | `POST /api/app/request` | Xarakteristikalar |
| `catalogSaveImage` | 893 | `POST /api/app/request` | Tashqi havolali rasm |
| `catalogDeleteImage` | 894 | `POST /api/app/request` | Rasmni o'chirish |
| `catalogUploadImage` | 895 | `POST /api/app/requestFile` | Rasmni serverga yuklash |

---

## 7. Boshqaruv paneli — alohida ish

Bu hujjat faqat katalog haqida. ABM Store boshqaruv paneli (`Ipt_Dashboard`,
`/api/report/*`) alohida iste'molchi va alohida token (qamrovi `report`).
Uning ishlari:

| Fayl | Nima |
|---|---|
| `db/ipt_dashboard.sql` | `Ipt_Dashboard` paketi, metodlar 885–888 |
| `src/.../report/controllers/CDashboard.java` | `/api/report/*` |
| `prototype/dashboard/index.html` | Front maket |

Alohida tekshirish kerak: kunlik snapshot jobi (`IPT_REPORT_BY_FILIAL_JOB`)
ishlayaptimi — qarzdorlik metodi butunlay shunga tayanadi.
