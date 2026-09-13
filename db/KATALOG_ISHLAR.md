# Katalog moduli — qilinadigan ishlar

ABM Store sayti uchun katalog API. Talablar hujjati: «ABM Store — katalog API
talablari», v1.0, 27.08.2026.

**Holat:** backend kodi to'liq yozildi va commit qilindi. Bazada hali ishga
tushirilmagan, ma'lumot to'ldirilmagan, frontend qilinmagan.

---

## 0. Nima tayyor

| Qism | Holat |
|---|---|
| Baza sxemasi (24 maydon, 7 ma'lumotnoma, 2 model jadvali) | ✅ yozildi |
| `Ipt_Catalog` paketi (8 metod) | ✅ yozildi |
| `Product_Action` integratsiyasi | ✅ yozildi |
| `/api/catalog/*` endpointlari (Java) | ✅ kompilyatsiya o'tdi |
| Rasmlarni serverga yuklash | ✅ yozildi |
| Sayt jamoasiga javob xati + API spetsifikatsiyasi | ✅ tayyor |
| Web jamoasiga spetsifikatsiya | ⚠️ yangilanishi kerak, 4.6 ga qarang |
| Bazada ishga tushirish | ❌ |
| Ma'lumot to'ldirish (~800 pozitsiya) | ❌ |
| Frontend | ❌ |

Sayt so'ragan **barcha maydonlar** qoplangan: hujjatning 5, 5.2, 5.3 va 7.4
bo'limlaridagi maydonlarning hammasi bor.

---

## 1. Serverni tayyorlash

- [ ] **Rasmlar papkasini yaratish.** `Files.copy` papkani o'zi yaratmaydi —
      bo'lmasa yuklash «Could not store the file» bilan tugaydi.

      mkdir -p /opt/monello71/files/catalog
      chown <app_user> /opt/monello71/files/catalog

- [ ] **Rasm havolasi prefiksini to'g'rilash.** `ipt_catalog_stage3.sql`,
      4.4-bo'limda domen namunaviy qoldirilgan:

      update core_properties
         set param_value = 'https://<sizning_domen>/api/app/get-file?file='
       where param_name = 'catalog_file_url';

      Tekshirish: brauzerda inkognito oynada rasm havolasi ochilishi kerak —
      sayt uni avtorizatsiyasiz oladi.

- [ ] **Disk hajmini baholash.** 800 pozitsiya × ~3 rasm × ~1 MB ≈ 2.5 GB.

---

## 2. Bazani yangilash

Skriptlar **shu tartibda**, tartibni o'zgartirib bo'lmaydi:

- [ ] `db/ipt_catalog_stage1.sql` — asosiy maydonlar, kategoriya, brend
- [ ] `db/ipt_catalog_stage2.sql` — tashqi tizim tokeni
- [ ] `db/ipt_catalog_stage3.sql` — qolgan maydonlar, rasm va xarakteristikalar
- [ ] `db/ipt_catalog_package.sql` — `Ipt_Catalog` paketi va metodlar ro'yxati
- [ ] `db/ipt_catalog_product_action.sql` — **qo'lda**: PL/SQL Developer'da
      `Ipt_Methods` paket tanasidagi `Product_Action` ni almashtirib,
      paketni rekompilyatsiya qilish

Kompilyatsiya tartibi: `Ipt_Catalog` spec → `Ipt_Methods` body → `Ipt_Catalog`
body. Ikkala paket bir-birini chaqiradi, lekin spetsifikatsiyalar bog'liq emas.

- [ ] **Xatolarni tekshirish:**

      select object_name, object_type, status
        from user_objects
       where object_name like 'IPT_%' and status <> 'VALID';

      select * from user_errors where name like 'IPT_%' order by sequence;

### 2.1 Ishga tushirgandan keyingi qo'lda ishlar

- [ ] **Vitrina filiallarini belgilash.** Bu qilinmasa katalog **bo'sh**
      qaytadi — `site_code` yo'q filial saytga umuman chiqmaydi.

      select code, name, type from ipt_s_filials order by code;

      update ipt_s_filials set site_code = 'mirobod' where code = '?????';
      update ipt_s_filials set site_code = 'sebzor'  where code = '?????';
      commit;

- [ ] **Sayt uchun token yaratish.** `ipt_catalog_stage2.sql` 3-bo'limida
      namuna bor. Token tasodifiy generatsiya qilinadi (`openssl rand -hex 32`),
      bazada faqat SHA-256 xeshi qoladi. Tokenni sayt jamoasiga bir marta
      xavfsiz kanal orqali berib, o'zingizda saqlamaysiz.

- [ ] **Test uchun alohida token** — sayt jamoasi so'ragan.

---

## 3. Ma'lumot to'ldirish

**Loyihaning eng uzun qismi.** Dasturchi ishi emas — ombor ishi.
~800 pozitsiya.

Saytga chiqishi uchun tovarda **oltita maydon** to'ldirilgan bo'lishi shart:

`retail_price_uzs` · `model_code` · `model_name` · `category_code` ·
`brand_code` · `item_condition`

Bularsiz tovar `ipt_catalog_v` ga tushmaydi. Bu ataylab: yarim to'ldirilgan
kartochka vitrinada turgandan ko'ra umuman turmagani yaxshi.

- [ ] **Ish ro'yxatini ko'rish:** `select * from ipt_catalog_todo_v;`
- [ ] **Chakana narxlarni kiritish** — eng ko'p vaqt oladigani. Xarid
      narxidan hisoblab bo'lmaydi, har biriga qo'lda.
- [ ] **`model_code` qo'yish** — bir xil modeldagi qatorlarga ommaviy
      (`catalogSaveProduct`, `ids` massivi bilan)
- [ ] **Kategoriya va brend**
- [ ] **`item_condition`** — yangi/ishlatilgan
- [ ] **`phys_filial_code`** — «Mirobodda» holati uchun
- [ ] **Xotira, rang, artikul** (2-bosqich maydonlari)
- [ ] **Ishlatilgan texnika maydonlari** — IMEI, batareya, SIM, bozor kodi
- [ ] **Rasmlar** — model bo'yicha, har bir model uchun bir marta
- [ ] **Xarakteristikalar** — aksessuarlar uchun `acc_compat` muhim

**Jarayonni kuzatish:**

    select count(*) qolgan  from ipt_catalog_todo_v;
    select count(*) tayyor  from ipt_catalog_v;

**Nomni avtomatik ajratish tavsiya qilinmaydi.** Yuklamada `imei`/`imie`/
`i mei`, `Desert`/`Desret` kabi xatolar bor — qoralama ajratish qilinsa ham
ko'z bilan tekshirish kerak, aks holda xato vitrinaga chiqadi.

---

## 4. Frontend (web)

### 4.1 Mahsulot formasi
- [ ] 24 ta yangi maydon qo'shish (ro'yxat web spetsifikatsiyasida)
- [ ] Kategoriya, brend, rang, SIM, bozor kodi — dropdown
- [ ] **Muhim:** formada yo'q maydonni JSON'ga **umuman qo'shmaslik**.
      `null` yoki `""` yuborilsa maydon **tozalanadi** (Oracle'da bo'sh satr
      = NULL). Ko'p framework to'ldirilmagan input'ni aynan shunday jo'natadi —
      shu qoida buzilsa to'ldirilgan ma'lumot bitta tahrirdan keyin o'chadi.

### 4.2 To'ldirish ekrani
- [ ] `ipt_catalog_todo_v` bo'yicha grid
- [ ] Checkbox bilan bir nechta qator tanlash
- [ ] Yuqorida umumiy forma → `catalogSaveProduct` bilan hammasiga birdan
- [ ] Qolgan/tayyor hisoblagichlari

### 4.3 Rasmlar ekrani
- [ ] Model bo'yicha rasmlar ro'yxati (`ipt_model_images_v`)
- [ ] Yuklash: `POST /api/app/requestFile`, multipart, method
      `catalogUploadImage`
- [ ] Rangga biriktirish, asosiy rasmni belgilash, tartib
- [ ] O'chirish: `catalogDeleteImage`
- [ ] Tashqi havola qo'shish: `catalogSaveImage`

### 4.4 Xarakteristikalar ekrani
- [ ] Model bo'yicha (`ipt_model_attributes_v`)
- [ ] `ipt_s_attributes_v` dan tur olinadi: `is_multi` bo'lsa ko'p tanlov
- [ ] `catalogSaveAttributes` — modelning barcha xarakteristikalari
      almashtiriladi

### 4.5 Grid
- [ ] `CORE_GRIDS` ga `ipt_catalog_todo_v` uchun yozuv. `module_id` kerak:

      select module_id, code, name from core_modules where state = 'A';

### 4.6 Hujjatni yangilash
- [ ] Web spetsifikatsiyasida `catalogSaveImages` metodi bor edi — u olib
      tashlandi, o'rniga `catalogUploadImage` / `catalogSaveImage` /
      `catalogDeleteImage`. Yangi maydonlar ham qo'shilishi kerak.

---

## 5. Sayt jamoasi bilan

### 5.1 Ulardan kutilayotgani
- [ ] Kategoriya va ishlatilgan texnika turlari ro'yxati (JSON yoki CSV)
- [ ] `model_code` shakllantirish qoidalari
- [ ] Server IP manzili (cheklov qo'yish uchun)
- [ ] Qaysi filiallar `mirobod` va `sebzor`

### 5.2 Hal qilinmagan ikkita qaror

- [ ] **`quantity` nimani anglatadi.** Hozir hisobdagi bog'lanish.
      `phys_filial_code` to'ldirilmaguncha «Mirobodda» holati API'da
      ko'rinmaydi. Bu variantda samovivozni jangovar rejimda ishga
      tushirmaslik kerak.

- [ ] **`id` nimani anglatadi.** Hozir ombor qatorining id'si. Bir xil
      ikkita yangi apparat ikkita yozuv bo'lib keladi. Agar yopishtirishni
      biz qiladigan bo'lsak, `id` konfiguratsiya identifikatoriga aylanadi
      va sayt bir marta qayta bog'lashi kerak bo'ladi — **ulanishdan oldin
      hal qilish kerak**, keyin qimmatroq.

### 5.3 Rasmlar — javob
Sayt jamoasiga «rasmlarni kim joylashtiradi» degan savol yuborilgan edi.
Endi javob bor: **serverda o'zimizda saqlaymiz**, ular hech narsa qilmaydi.
Xatni shunga qarab yangilash kerak.

---

## 6. Tekshirish

### 6.1 Bazada
```sql
-- Katalogda nechta tovar bor
select count(*) from ipt_catalog_v;

-- Bitta tovarning to'liq JSON javobi
declare v clob;
begin
  Ipt_Catalog.Get_Products('{"params":{"page":1,"per_page":1}}', v);
  dbms_output.put_line(substr(v, 1, 4000));
end;
/
```

### 6.2 API
```bash
curl -H "Authorization: Bearer $TOKEN" \
     "https://<domen>/api/catalog/products?page=1&per_page=5"

curl -H "Authorization: Bearer $TOKEN" \
     "https://<domen>/api/catalog/stock"

# Token noto'g'ri bo'lsa 401 kutiladi
curl -i -H "Authorization: Bearer yomon" \
     "https://<domen>/api/catalog/stock"
```

### 6.3 Tekshirish nuqtalari
- [ ] `price` butun son, somda
- [ ] `quantity` da ikkala shourum bor
- [ ] `images` havolalari inkognito oynada ochiladi
- [ ] `attributes` da `acc_compat` massiv, `power_w` son
- [ ] Ishlatilgan tovarda `battery_health_pct` bor, yangisida yo'q
- [ ] `updated_since` bilan kamroq qator qaytadi

---

## 7. Ma'lum cheklovlar

Bular xato emas, ongli qarorlar — lekin bilib qo'yish kerak.

**Yetim fayllar.** Rasm yozuvi o'chirilganda serverdagi faylning o'zi
qolaveradi. Sekin to'planadi. Kerak bo'lsa keyin tozalash jobi qilinadi.

**N+1 so'rov.** Har bir tovar uchun rasm va xarakteristika alohida
so'raladi. 500 tovar = ~1000 so'rov. Indekslar bor, soatiga bir marta
so'ralganda muammo emas. Sekinlashsa — model bo'yicha keshlash kerak.

**`Check_For_Seller`.** Katalog metodlari `Product_Action` bilan bir xil
ruxsat modelidan o'tadi (21-rol + 5-modul kombinatsiyasi bloklanadi).
To'ldirishni qiladigan odamlar «У вас нет доступа» olsa — shu tekshiruvni
olib tashlash kerak.

**`Set_Method_File` registrga sezgir.** `Core_App.Set_Method` metod nomini
`lower()` bilan qidiradi, `Set_Method_File` esa **aniq** solishtiradi.
Ya'ni rasm yuklashda frontend `catalogUploadImage` ni harfma-harf to'g'ri
yuborishi kerak.

**`/request/v2` da `oper` va `message` yo'q.** Mavjud xatti-harakat:
`res = outObj` bilan ular tashlab yuboriladi. Saqlash natijasi haqidagi
xabar kerak bo'lsa eski `/api/app/request` ishlatiladi.

**IP cheklovi yo'q.** Sayt jamoasi server manzilini hali yubormagan.
Manzil kelganda qo'shiladi.

---

## 8. Fayllar

| Fayl | Nima |
|---|---|
| `db/ipt_catalog_stage1.sql` | Asosiy maydonlar, kategoriya, brend, `ipt_catalog_v` |
| `db/ipt_catalog_stage2.sql` | `core_api_tokens`, token yaratish yo'riqnomasi |
| `db/ipt_catalog_stage3.sql` | Qolgan maydonlar, rasm va xarakteristika jadvallari |
| `db/ipt_catalog_package.sql` | `Ipt_Catalog` paketi, `core_methods` yozuvlari |
| `db/ipt_catalog_product_action.sql` | `Product_Action` — qo'lda qo'llanadi |
| `src/.../catalog/controllers/CCatalog.java` | `/api/catalog/*` |
| `src/.../catalog/services/SCatalog.java` | Token tekshirish, metod chaqirish |

### Metodlar

| Metod | Endpoint | Nima qiladi |
|---|---|---|
| `catalogProducts` | `GET /api/catalog/products` | Sayt uchun katalog |
| `catalogStock` | `GET /api/catalog/stock` | Narx va qoldiq |
| `productAction` | `POST /api/app/request` | Mahsulot + katalog maydonlari |
| `catalogSaveProduct` | `POST /api/app/request` | Ommaviy to'ldirish |
| `catalogUploadImage` | `POST /api/app/requestFile` | Rasmni serverga yuklash |
| `catalogSaveImage` | `POST /api/app/request` | Tashqi havolali rasm |
| `catalogDeleteImage` | `POST /api/app/request` | Rasmni o'chirish |
| `catalogSaveAttributes` | `POST /api/app/request` | Xarakteristikalar |
