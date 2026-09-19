# Ma'lumotnomalar formasi — front prototip

`Ipt_Dictionary` ning to'rtta metodi ustiga qurilgan bir faylli maket.
Build ham, npm ham kerak emas: `index.html` ni brauzerda ochsangiz bo'ldi.

    prototype/dictionary/index.html

## Gap nimada

Bitta forma, 15 ta ma'lumotnoma. Sahifada har ma'lumotnoma uchun alohida
kod **yo'q** — jadval ustunlari ham, tahrir oynasidagi inputlar ham
`dictList` qaytaradigan metadata'dan quriladi.

Buni tekshirish oson: chapdagi ro'yxatdan boshqasini tanlang. Ustunlar,
input turlari va majburiy maydonlar o'zgaradi, sahifa kodi esa o'sha-o'sha.

| Metadata | Formada nima bo'ladi |
|---|---|
| `type: S` | matn maydoni, `max_len` bilan |
| `type: N` | `<input type="number">` |
| `type: B` / `F` | checkbox |
| `type: L` | `<select>`, variantlar `lov` dan |
| `required: true` | yonida qizil yulduzcha |
| `can_insert: false` | «Qo'shish» tugmasi o'chadi |
| `can_delete: false` | qatorlarda «O'chirish» tugmasi yo'q |
| `lock_reason` | tepada sariq izoh bo'lib chiqadi |
| `order_column` | saralash tartibi (kategoriyalarda `ord`) |

## Ikki rejim

**Demo** (sukut bo'yicha) — qo'shish, tahrirlash va o'chirish haqiqatda
ishlaydi, o'zgarishlar brauzer xotirasida qoladi va sahifa yangilansa
qaytadi. Metadata va qiymatlar bazadagi seed bilan bir xil: kategoriyalar
24 ta, ranglar 14 ta, bozor kodlari 7 ta va hokazo.

Bloklangan ma'lumotnomalarni ham sinab ko'rish mumkin: «Sdelka holatlari»
ni tanlang — «Qo'shish» o'chiq, «O'chirish» yo'q, tepada sababi yozilgan.

**Jonli** — Monello manzili va **JWT** so'raladi. Bu yerda API tokeni emas,
aynan sessiya tokeni kerak: ichki metodlar `/api/app/request` orqali
ishlaydi va JWT bilan avtorizatsiya qilinadi. JWT Monello'ga kirganda
olinadi.

Jonli rejim faqat sahifa o'z serveringizdan ochilganda ishlaydi.

## Ishga tushirishdan oldin

Token yoki JWT brauzerda turishi — faqat sinov uchun. Haqiqiy formada
sessiya odatdagidek cookie yoki ilova holatidan olinadi.

`db/ipt_dictionary.sql` bazada bajarilgan bo'lishi kerak.

## Nimasi to'g'rilanishi kerak

- sahifalash yo'q: `per_page` 200, undan oshsa «ko'rsatilgan N / jami M»
  deb yozadi va qolganini qidiruv orqali topish kerak bo'ladi
- ustun bo'yicha saralash yo'q, tartib backenddan keladi
- o'chirishda `confirm()` ishlatilgan, ilovaning o'z dialogi emas
