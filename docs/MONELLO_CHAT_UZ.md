# Chat formasi — Monello yordamchisi

**Kimga:** Monello web jamoasiga va tizimni ishga tushiradiganlarga
**Nima:** filiallar, savdolar, rassrochkalar va qarzdorlar haqida tabiiy tilda savol-javob
**Sana:** 19.09.2026

---

## 1. Qanday ishlaydi

```
Foydalanuvchi savoli
        ↓
POST /api/chat          (JWT bilan, sessiya filiali bilan)
        ↓
SChat  →  Claude API  ←→  tool chaqiruvlari
                            ↓
                    Ipt_Chat paketi (PL/SQL)
                            ↓
                        Oracle
```

Model savolni o'qiydi, kerakli tool'ni o'zi tanlaydi, natijani olib javob
yozadi. Bir savolga bir nechta tool chaqirilishi mumkin.

### Model SQL yozmaydi

Bu eng muhim qaror. Model faqat **beshta ro'yxatdan o'tgan metodni** chaqira
oladi:

| Tool | Nima qaytaradi |
|---|---|
| `chatFilials` | Filiallar, har birida nechta faol sdelka, mijoz va tovar |
| `chatSales` | Davr bo'yicha sdelkalar soni va summasi, filial kesimida |
| `chatInstallments` | Faol rassrochkalar, mijoz ismi bo'yicha qidirish bilan |
| `chatDebtors` | Kechikkan sdelkalar, eng uzoq kechikkanidan |
| `chatTrade` | Bitta sdelka: shartlari va to'lov grafigi |

Modelga SQL yozdirib, uni bajarish mumkin edi. Qilmadim: model yozgan SQL ni
oldindan tekshirib bo'lmaydi, bu esa qarzdorlik bazasi. Qat'iy tool'da eng
yomon holat — noto'g'ri parametr, va u xato xabari bo'lib qaytadi.

---

## 2. Uch cheklov

**Faqat o'qish.** Beshta tool ham `select` qiladi. Yozadigan tool yo'q.
Foydalanuvchi "shu to'lovni kiritib yubor" desa, model qila olmasligini
aytadi.

**Filial bo'yicha cheklangan.** Chat `SApp.post(..., true)` orqali ketadi,
ya'ni sessiya JWT dan o'rnatiladi. `Ipt_Chat.Filial_Scope` shu sessiya
filialini qaytaradi va barcha tool'lar unga tayanadi — Mirobod sotuvchisi
Sebzor qarzdorlarini ko'rmaydi.

Qamrov **bitta joyda**: `Filial_Scope`. Boshqaruvchi barcha filiallarni
ko'rishi kerak bo'lsa, o'sha funksiyadagi izohga olingan uch satr ochiladi
va rol id'si qo'yiladi.

**Shaxsiy ma'lumot chiqmaydi.** `ipt_clients` da `pinfl` va `address` bor —
ular bironta tool da tanlanmaydi. Mijoz ismi chiqadi, chunki "kim qarzdor"
degan savolning javobi shu.

---

## 3. Qator chegarasi

Har tool eng ko'pi bilan **30 qator** qaytaradi va javobda `total` (jami
nechta) bilan `shown` (nechtasi ko'rsatildi) bo'ladi. Qisqartirilgan bo'lsa
`note` maydoni ham keladi va model uni foydalanuvchiga aytadi.

Chegarasiz ro'yxat modelning kontekstini to'ldiradi: u baribir bir
nechtasini o'qib xulosa qiladi, lekin hammasi uchun pul to'lanadi.

---

## 4. API

### `POST /api/chat`

```json
{
  "question": "Eng ko'p kechikkanlar kim?",
  "history": [
    { "role": "user",      "text": "Qaysi filiallar bor?" },
    { "role": "assistant", "text": "To'rtta filial bor: ..." }
  ]
}
```

```json
{
  "ok": true,
  "answer": "Eng uzoq kechikkan 5 ta sdelka: ...",
  "tools_used": ["chatDebtors"]
}
```

`history` — faqat matn. Har savol o'z tool loop'ini boshidan boshlaydi,
shuning uchun oldingi tool chaqiruvlarini qaytarib yuborish shart emas.
Server oxirgi 12 ta navbatni oladi.

Xato bo'lsa: `{ "ok": false, "error": "..." }`. Tafsilot logda qoladi,
foydalanuvchiga chiqmaydi.

### `GET /api/chat/status`

```json
{ "enabled": true }
```

API kaliti berilmagan bo'lsa `false` qaytadi — forma kirish maydonini
o'chirib qo'yishi kerak.

---

## 5. Formada nima ko'rinishi kerak

Prototip: `prototype/chat/index.html`.

**Har javob ostida qaysi tool ishlatilgani ko'rsatiladi.** Yorliqni
bosganda o'sha tool qaytargan JSON ochiladi. Bu bezak emas: xodim raqam
qayerdan kelganini tekshira olishi kerak, aks holda chatga ishonib
bo'lmaydi.

Qolganlari: taklif qilinadigan savollar (bo'sh ekranda), javob kutilayotgani
belgisi, jadvalni gorizontal aylantirish.

---

## 6. MCP — `/api/mcp`

O'sha beshta tool MCP protokoli orqali ham beriladi, Claude Desktop yoki
Claude Code ulanishi uchun. Ichki chat bundan foydalanmaydi — u katalogni
to'g'ridan-to'g'ri chaqiradi.

JSON-RPC 2.0: `initialize`, `tools/list`, `tools/call`, `ping`.
Avtorizatsiya — `Authorization: Bearer <token>`, qamrovi `chat`.

> **Diqqat.** MCP tokenida JWT yo'q, ya'ni sessiya filiali ham yo'q:
> tool'lar **barcha filiallarni** ko'rsatadi. Bu tokenni faqat boshqaruvga
> bering. Sotuvchiga bermang — u web orqali o'z filialini ko'radi, token esa
> hammasini ochadi.

Token yaratish `db/create_api_tokens.sql` dagi kabi, `scope` ni `'chat'`
qilib.

### Nima qilinmadi va nega

Claude'ning **hosted MCP konnektori** ishlatilmadi. Unda Anthropic
serverlari Monello endpointiga o'zi ulanadi — ya'ni ichki qarzdorlik
ma'lumoti tashqi tarmoqqa ochiladi. Buning uchun alohida qaror kerak, uni
o'zim qabul qilmadim.

---

## 7. Ishga tushirish

1. **Baza:** `db/ipt_chat.sql`

2. **API kaliti** — faylga yozilmaydi:

       export ANTHROPIC_API_KEY=sk-ant-...

   Kalit berilmasa ilova ko'tariladi, chat esa o'chiq holatda turadi.

3. **Model:** `application.properties` da `anthropic.model=claude-opus-5`

4. **Tekshirish:**

       curl -H "Authorization: Bearer <JWT>" -H "Content-Type: application/json" \
            -d '{"question":"Qaysi filiallar bor?"}' \
            https://<domen>/api/chat

---

## 8. Bilib qo'yish kerak bo'lgan narsalar

**Har savol pul turadi.** Chat Claude API ga boradi. Narx savolning
uzunligiga va nechta tool chaqirilganiga bog'liq. Birinchi arzonlashtirish
richagi — `effort` ni pasaytirish: `SChat.ask` dagi so'rovga
`output_config.effort = "low"` qo'shiladi. Bu SDK versiyasi
tekshirilgandan keyin qilinsin.

**Versiya to'qnashuvi tuzatilgan, lekin yodda tuting.** Spring Boot 2.6.6
okhttp 3.14.9 va jackson 2.13.2.2 ni majburlaydi, Anthropic SDK esa okhttp
4.12.0 va jackson 2.18.2 bilan qurilgan. Kompilyatsiya ikkala holatda ham
o'tadi — muammo ishga tushganda `NoSuchMethodError` bo'lib chiqadi.
Versiyalar `pom.xml` ning `<properties>` bo'limida ko'tarilgan. SDK
yangilanganda bu qatorlarni ham tekshiring.

**Model xato qilishi mumkin.** Tool'lar to'g'ri ma'lumot qaytaradi, lekin
model uni noto'g'ri talqin qilishi mumkin — masalan davrni chalkashtirib
yuborishi. Shuning uchun tool yorliqlari ko'rinadigan qilib qo'yilgan:
shubha bo'lsa xom ma'lumotni ochib ko'rish mumkin.

**Log.** Beshta tool ham `add_log = 'Y'` bilan ro'yxatdan o'tgan, ya'ni har
chaqiruv `core_api_log` ga tushadi. Kim nima so'raganini bilish kerak — bu
qarzdorlik ma'lumoti.

---

## 9. Qilinmagan ishlar

- Javobni oqim (streaming) bilan berish — hozir javob to'liq tayyor
  bo'lgandan keyin keladi, uzun javobda kutish sezilarli
- Suhbatni saqlash — tarix faqat brauzerda, sahifa yangilansa yo'qoladi
- Narx nazorati — foydalanuvchi boshiga kunlik chegara yo'q
- Tool natijasini formaga qaytarish — hozir forma faqat tool NOMINI oladi,
  natijani emas (prototipda demo ma'lumot ko'rsatiladi)

---

*Monello backend · 19.09.2026*
