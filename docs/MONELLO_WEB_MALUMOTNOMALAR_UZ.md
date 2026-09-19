# Ma'lumotnomalar — yagona forma

**Kimga:** Monello web interfeysi jamoasiga
**Nima:** barcha `ipt_s_*` ma'lumotnomalari uchun bitta ekran
**Sana:** 19.09.2026

---

## 1. G'oya

Bitta forma, 15 ta ma'lumotnoma. Har biri uchun alohida ekran yozilmaydi —
forma o'zini **metadata'dan quradi**.

Yangi ma'lumotnoma qo'shilganda **frontend ham, backend ham o'zgarmaydi**:
`ipt_s_dictionaries` va `ipt_s_dictionary_cols` ga qator qo'shiladi, forma uni
o'zi ko'rsata boshlaydi.

Maket: chapda ma'lumotnomalar ro'yxati, o'ngda tanlanganining qatorlari,
tepada qidiruv va "qo'shish" tugmasi.

---

## 2. To'rtta metod

Hammasi `POST /api/app/request` orqali, odatdagidek.

| Metod | Nima qiladi |
|---|---|
| `dictList` | Barcha ma'lumotnomalar va ularning ustunlari |
| `dictRows` | Bitta ma'lumotnomaning qatorlari |
| `dictSave` | Qator qo'shish yoki tahrirlash |
| `dictDelete` | Qatorni o'chirish |

---

## 3. `dictList` — formani qurish uchun

Sahifa ochilganda **bir marta** chaqiriladi. Javob kichik: 15 ta
ma'lumotnoma × ~4 ustun.

```json
{ "method": "dictList", "params": {} }
```

```json
{
  "dictionaries": [
    {
      "code": "colors",
      "name_ru": "Цвета",
      "name_uz": "Ranglar",
      "pk_column": "code",
      "pk_type": "S",
      "pk_max_len": 30,
      "state_column": "condition",
      "can_insert": true,
      "can_delete": true,
      "columns": [
        { "name": "name_ru", "label_ru": "Название (ru)", "label_uz": "Nomi (ru)",
          "type": "S", "max_len": 200, "required": true },
        { "name": "condition", "label_ru": "Состояние", "label_uz": "Holati",
          "type": "L", "required": false,
          "lov": [ { "code": "A", "name": "Faol" }, { "code": "P", "name": "Nofaol" } ] }
      ]
    }
  ]
}
```

### Ustun turlari

| `type` | Nima | Input |
|---|---|---|
| `S` | matn | `<input type="text">`, `max_len` bilan |
| `N` | son | `<input type="number">` |
| `B` | mantiqiy (bazada 1/0) | checkbox, `true`/`false` yuboriladi |
| `F` | bayroq (bazada Y/N) | checkbox, `true`/`false` yuboriladi |
| `L` | ro'yxat | `<select>`, variantlar `lov` dan |

`B` va `F` ning farqi faqat bazada: ikkalasiga ham `true`/`false` yuborasiz,
backend o'zi o'giradi.

### `state_column`

Qaysi ustun "faol/nofaol" ekanini aytadi. U `columns` ichida ham bor
(odatda `L` turi bilan), shuning uchun alohida ishlov shart emas — lekin
gridda uni rang yoki belgi bilan ajratib ko'rsatish qulay.

### `can_insert` / `can_delete`

`false` bo'lsa tegishli tugmani **o'chiring**. Sababi `lock_reason` da keladi
va foydalanuvchiga ko'rsatish kerak — aks holda "nega tugma ishlamayapti"
degan savol chiqadi.

Bloklanganlar va sabablari:

| Ma'lumotnoma | Qo'shish | O'chirish | Nega |
|---|---|---|---|
| Sdelka holatlari | ✗ | ✗ | kodlar PL/SQL da qotirilgan |
| Tovar holatlari | ✗ | ✗ | kodlar PL/SQL da qotirilgan |
| Filiallar | ✗ | ✗ | filial qo'shish sessiya va hisobotlarga tegadi |
| Tovar turlari | ✓ | ✗ | kod o'chsa mavjud tovarlar turi yo'qoladi |

Qolgan 11 tasida ikkalasi ham ochiq. Nomini o'zgartirish **hamma joyda**
mumkin, bloklangan ma'lumotnomalarda ham.

---

## 4. `dictRows` — qatorlar

```json
{ "method": "dictRows",
  "params": { "dict": "colors", "search": "sereb", "page": 1, "per_page": 200 } }
```

| Parametr | Sukut | Izoh |
|---|---|---|
| `dict` | — | majburiy |
| `search` | — | kod va barcha matn ustunlari bo'yicha, registrga sezgir emas |
| `page` | 1 | |
| `per_page` | 200 | maksimum 500 |

```json
{
  "dict": "colors",
  "total": 24,
  "page": 1,
  "per_page": 200,
  "rows": [
    { "code": "silver", "name_ru": "Серебристый", "name_uz": "Kumushrang", "condition": "A" }
  ]
}
```

Kalitlar — ustun nomlari, kichik harfda. **Bo'sh qiymat kaliti umuman
kelmaydi** — ustunlar ro'yxati `dictList` dan allaqachon ma'lum, shuning
uchun javob bo'sh kalitlar bilan shishmaydi.

Saralash: avval faol qatorlar, keyin kod bo'yicha.

---

## 5. `dictSave` — qo'shish va tahrirlash

Bitta metod ikkalasiga ham: kod bazada bor bo'lsa — tahrir, yo'q bo'lsa —
qo'shish. Javobdagi `action` qaysi bo'lganini aytadi (`I` yoki `U`).

```json
{
  "method": "dictSave",
  "params": {
    "dict": "colors",
    "code": "space-gray",
    "values": {
      "name_ru": "Серый космос",
      "name_uz": "Kosmik kulrang",
      "condition": "A"
    }
  }
}
```

```json
{ "oper": true, "data": { "dict": "colors", "code": "space-gray", "action": "I" },
  "message": "Qator qo'shildi." }
```

### Uchta qoida

1. **Kodni o'zgartirib bo'lmaydi.** `code` — qaysi qator ekanini aniqlaydi.
   Kodni almashtirish kerak bo'lsa: yangisini qo'shib, eskisini nofaol
   qilish. Kodni to'g'ridan-to'g'ri o'zgartirish eski yozuvlarni uzib
   qo'yardi.

2. **`values` da yo'q ustun tegilmaydi.** Tahrirda faqat yuborilgan
   ustunlar yoziladi. Tizimning qolgan qismidagi bilan bir xil qoida.

3. **Notanish kalit e'tiborsiz qoladi.** Backend `values` dagi kalitlar
   bo'yicha emas, **metadata'dagi ustunlar** bo'yicha aylanadi. Ya'ni
   `values` ga ortiqcha narsa qo'shilsa u shunchaki yozilmaydi.

Qo'shishda `required: true` bo'lgan barcha ustunlar bo'lishi shart.

---

## 6. `dictDelete` — o'chirish

```json
{ "method": "dictDelete", "params": { "dict": "colors", "code": "space-gray" } }
```

Ishlatilayotgan kodni o'chirib bo'lmaydi — buni baza to'sadi. Foydalanuvchi
tushunarli xabar oladi:

> «space-gray» kodi ishlatilgan, o'chirib bo'lmaydi. Uning o'rniga qatorni
> nofaol qiling — shunda u yangi yozuvlarda tanlanmaydi, eskilari esa
> joyida qoladi.

**Formada shuni odat qiling:** o'chirish o'rniga nofaol qilishni taklif
qiling. Ma'lumotnoma kodi tarixda qolishi kerak, aks holda eski hujjat
"nomsiz" bo'lib qoladi.

---

## 7. Xatolar

Hammasi `ORA-20000` bo'lib keladi, matni foydalanuvchiga ko'rsatsa
bo'ladigan darajada yozilgan:

```
"name_ru" to'ldirilishi shart.
"name_ru" uzunligi 200 belgidan oshmasligi kerak (hozir 240).
"value_type" uchun yaroqsiz qiymat: str. Mumkin qiymatlar: text:Matn;number:Son;bool:Mantiqiy
"Состояния сделки" ma'lumotnomasiga yangi qator qo'shib bo'lmaydi. Kodlar PL/SQL da qotirilgan...
```

---

## 8. Bir narsa — huquq

Hozir ma'lumotnoma tahriri mahsulot tahriri bilan bir xil huquq modelidan
o'tadi (`Check_For_Seller`). Bu **kamlik qiladi**: sdelka holati nomini
o'zgartirish butun tizimga ko'rinadi, bitta tovarni tahrirlash esa yo'q.

Alohida rol ajratilganda `Ipt_Dictionary.Check_Access` ichidagi izohga
olingan uch satr ochiladi va rol id'si qo'yiladi. Formani qurishda buni
hisobga oling: menyu bandini kelajakda o'sha rolga bog'lash kerak bo'ladi.

---

## 9. Yangi ma'lumotnoma qo'shish

Kod yozilmaydi — ikki qator:

```sql
insert into ipt_s_dictionaries(code, table_name, name_ru, name_uz, state_column, ord)
values ('my_dict', 'IPT_S_MY_DICT', 'Мой справочник', 'Mening ma''lumotnomam', 'CONDITION', 200);

insert into ipt_s_dictionary_cols(dict_code, column_name, name_ru, name_uz,
                                  data_type, max_len, is_required, ord)
values ('my_dict', 'NAME', 'Название', 'Nomi', 'S', 500, 'Y', 10);
commit;
```

Keyingi `dictList` chaqiruvida u formada paydo bo'ladi.

---

*Monello backend · 19.09.2026*
