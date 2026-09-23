# Monello — biznes talablari hujjati (BT)

**Tizim:** Monello — nasiya savdosini boshqarish tizimi
**Buyurtmachi:** ABM Store
**Hujjat versiyasi:** 1.0
**Sana:** 22.09.2026
**Muallif:** Arslonbek Kulmatov

---

## 1. Hujjat haqida

### 1.1 Maqsad

Bu hujjat Monello tizimining **nima qilishi kerakligini** qayd etadi —
qanday qilishini emas. U uch maqsad uchun yozilgan:

1. Biznes va dasturchilar bir xil narsani tushunishi uchun
2. Yangi funksiya so'ralganda "bu mavjud qoidaga zidmi?" degan savolga
   javob topish uchun
3. Yangi xodim va yangi dasturchi tizimni bir joydan o'rganishi uchun

### 1.2 Kimga

| Kim | Nima uchun o'qiydi |
|---|---|
| Rahbariyat | tizim nimani qamrab olgani, qaysi qarorlar unda qotirilgani |
| Buxgalteriya | pul qanday hisoblanishi, foyda qanday bo'linishi |
| Dasturchilar | talab manbai, o'zgartirishdan oldin tekshiriladigan qoidalar |
| Yangi xodim | jarayonlar ketma-ketligi |

### 1.3 Belgilar

- **BT-x.y** — biznes talabi raqami. O'zgartirish so'ralganda shu raqamga
  murojaat qilinadi.
- **〈tasdiqlash kerak〉** — hujjat yozilayotganda kodda aniq javob
  topilmagan joy. Biznes tasdiqlashi lozim.

---

## 2. Biznes konteksti

### 2.1 Kompaniya nima qiladi

ABM Store uch toifadagi tovarni **naqd** va **nasiya** (rassrochka)
evaziga sotadi:

| Toifa | Misol | Xususiyati |
|---|---|---|
| Telefon va gadjetlar | iPhone, Samsung, Apple Watch, AirPods | seriyali, IMEI bo'yicha hisob |
| Aksessuarlar | g'ilof, quvvatlagich, quloqchin | ommaviy, seriyasiz |
| Avtomobillar | Gentra, Spark, Tracker | alohida rekvizitlar: raqam, kuzov, dvigatel |

Savdo **bir nechta filialda** olib boriladi. Ikkita filial saytda bitta
vitrina bo'lib ko'rinadi (10-bo'limga qarang).

### 2.2 Pul qayerdan keladi

Tovar kompaniyaning o'z pulida emas, **investorlar sarmoyasida** olinadi.
Bu tizimning eng muhim xususiyati va uning butun hisob mantiqi shundan
kelib chiqadi:

```
Investor pul kiritadi
      ↓
Pul bilan tovar olinadi (investor qoldig'idan yechiladi)
      ↓
Tovar sotiladi (naqd yoki nasiya)
      ↓
Tushgan pul investor qoldig'iga qaytadi
      ↓
Foyda investor va boshqaruvchi o'rtasida kelishilgan foizda bo'linadi
```

### 2.3 Tizim yechadigan asosiy muammolar

| # | Muammo | Tizim nima qiladi |
|---|---|---|
| 1 | Kimning puliga qaysi tovar olingani noaniq | har bir tovar aniq investorga bog'lanadi |
| 2 | Foyda kimga qancha tegishi qo'lda hisoblanardi | avtomat taqsimlanadi, har tiyin qayd etiladi |
| 3 | Mijoz qancha qarzdor — aniq emas | to'lov grafigi va qoldiq real vaqtda |
| 4 | Kechikkanlar qo'lda kuzatilardi | avtomat reestr va qo'ng'iroq jurnali |
| 5 | Ombor qoldig'i saytda ko'rinmasdi | katalog API orqali saytga uzatiladi |

---

## 3. Maqsadlar va muvaffaqiyat mezonlari

| # | Maqsad | Qanday o'lchanadi |
|---|---|---|
| M-1 | Har bir tiyin izlanadigan bo'lishi | har bir pul harakati `ipt_operations` da izoh bilan |
| M-2 | Investor o'z pulining holatini ko'rishi | qoldiq, sarmoya, foyda — har lahzada |
| M-3 | Foyda tortishuvsiz bo'linishi | foizlar oldindan kelishiladi, hisob avtomat |
| M-4 | Qarzdorlik nazorat ostida bo'lishi | kechikish yoshi bo'yicha reestr |
| M-5 | Ombor qoldig'i saytda real bo'lishi | katalog API, filial kesimida |
| M-6 | Har bir o'zgarish tarixi saqlanishi | barcha asosiy jadvallarda `_his` nusxasi |

---

## 4. Foydalanuvchi rollari

| Rol | Nima qiladi | Nimaga ruxsati yo'q |
|---|---|---|
| **Sotuvchi** | mijoz kiritish, sdelka ochish, to'lov qabul qilish, tovar kiritish | boshqa filial ma'lumotlari, tarmoq bo'yicha hisobotlar |
| **Boshqaruvchi (manager)** | o'z ulushidagi foydani ko'rish va chiqim qilish | investor sarmoyasiga tegish |
| **Investor** | o'z qoldig'i, sarmoyasi va foydasini ko'rish | boshqa investor ma'lumotlari |
| **Buxgalter** | operatsiyalar, hisobotlar, ma'lumotnomalar | 〈tasdiqlash kerak〉 |
| **Administrator** | ma'lumotnomalar, foydalanuvchilar, tizim parametrlari | — |
| **Undiruv xodimi** | kechikkanlar ro'yxati, qo'ng'iroq natijasi | moliyaviy operatsiyalar |

**BT-4.1.** Foydalanuvchi faqat **o'z filiali** ma'lumotlarini ko'radi.
Sessiya filiali tizimga kirishda belgilanadi va so'rovlarga avtomat
qo'llaniladi.

**BT-4.2.** Tarmoq bo'yicha (hamma filial) hisobotlar **alohida huquq**
talab qiladi. Ular oddiy foydalanuvchiga ko'rinmaydi.

**BT-4.3.** Rol tekshiruvi har bir amalning **ichida** bajariladi, faqat
interfeys darajasida emas. Tugmani yashirish — himoya emas.

---

## 5. Glossariy

| Atama | Ma'nosi |
|---|---|
| **Investor** | tovar olish uchun pul kirituvchi. Foydaning bir qismini oladi |
| **Boshqaruvchi** | investor bilan ishlaydigan shaxs. Foydaning qolgan qismini oladi |
| **Qoldiq (saldo)** | investorning ishlatilmagan, tovarda turmagan puli |
| **Sarmoya** | investor umuman kiritgan pul (chiqarib olingani ayirilgan) |
| **Sdelka (trade)** | bitta mijozga bitta tovarni nasiyaga berish shartnomasi |
| **Grafik** | sdelka bo'yicha oylik to'lovlar jadvali |
| **Ustama (OPC)** | tovarni xarid narxidan qimmat sotishdan kelgan foyda |
| **Nasiya foizi (IPC)** | muddatli to'lash uchun qo'yilgan foiz foydasi |
| **Boshlang'ich to'lov** | sdelka ochilishida mijoz to'laydigan summa |
| **Filial** | savdo nuqtasi. Hisob va jismoniy joylashuv har xil bo'lishi mumkin |
| **Vitrina (site_code)** | saytdagi shourum. Bir nechta filial bitta vitrina bo'lishi mumkin |

---

## 6. Asosiy obyektlar

### 6.1 Investor

**BT-6.1.** Investorning to'rtta mustaqil pul ko'rsatkichi bo'ladi:

| Ko'rsatkich | Ma'nosi | Qachon o'zgaradi |
|---|---|---|
| Sarmoya (`total_investment`) | umumiy kiritilgan pul | faqat sarmoya kiritish/qaytarish |
| Qoldiq (`saldo_out`) | ishlatilmagan pul | har bir pul harakati |
| Nasiya foydasi (`income_ip_sum`) | IPC dan yig'ilgan | to'lov grafigi yopilganda |
| Ustama foydasi (`income_op_sum`) | OPC dan yig'ilgan | tovar sotilganda |

**BT-6.2.** Sarmoya va qoldiq **bir narsa emas**. Investor 100 000$
kiritib, hammasi tovarda turgan bo'lsa: sarmoya 100 000$, qoldiq 0$.

**BT-6.3.** Investorga kamida bitta boshqaruvchi biriktiriladi.

**BT-6.4.** Investor va boshqaruvchilar foizlari yig'indisi **aynan 100%**
bo'lishi shart — nasiya foydasi uchun ham, ustama foydasi uchun ham
alohida. Aks holda saqlash rad etiladi.

### 6.2 Tovar

**BT-6.5.** Har bir tovar **bitta investorga** tegishli. Investorsiz tovar
omborga kirmaydi.

**BT-6.6.** Tovar holatlari:

| Kod | Nomi | Ma'nosi |
|---|---|---|
| `S` | Omborda | sotuvga tayyor |
| `P` | Naqd sotilgan | qoldiq 0 ga tushgan |
| `K` | Nasiyaga sotilgan | qoldiq 0 ga tushgan |
| `R` | Qaytarilgan | mijozdan qaytib kelgan, qayta sotiladi |

**BT-6.7.** Tovar bir necha dona bo'lishi mumkin (`quantity`). Har sotuvda
miqdor bittaga kamayadi; nolga tushganda holat `P` yoki `K` bo'ladi.

**BT-6.8.** Avtomobil tovar turi (`T`) uchun qo'shimcha rekvizitlar
majburiy: davlat raqami, ishlab chiqarish yili, rangi, texpasport, kuzov
va dvigatel raqami, probeg, egasi, ishonchnoma, xarajatlar.

### 6.3 Mijoz

**BT-6.9.** Mijoz kodi tizim tomonidan beriladi: `6` + 9 xonali raqam.

**BT-6.10.** PINFL **aynan 14 raqam** bo'lishi shart.

**BT-6.11.** Telefon raqami **aynan 12 belgi** va `998` bilan boshlanishi
shart. Mijozda bir nechta raqam bo'lishi mumkin, har birida egasi
ko'rsatiladi (o'zi, qarindoshi, ish joyi).

**BT-6.12.** Mijoz ta'minoti (garov, kafillik) PDF fayl sifatida
biriktiriladi. Bir turdagi ta'minot bir marta biriktiriladi.

**BT-6.13.** Mijoz **skoring bahosi** (1–5) oladi. Baho sdelka **to'liq
yopilganda majburiy** so'raladi — bu keyingi murojaatda qaror qabul
qilish uchun.

### 6.4 Sdelka

**BT-6.14.** Bitta sdelka = bitta mijoz + bitta tovar donasi.

**BT-6.15.** Sdelka holatlari:

| Kod | Nomi | Qarz hisoblanadimi | Izoh |
|---|---|---|---|
| `01` | Действующий | **Ha** | amaldagi, to'lov qabul qilinadi |
| `02` | Просроченный | **Ha** | kechikkan, undiruvda |
| `04` | Блок icloud | **Ha** | qurilma iCloud orqali bloklangan, qarz saqlanadi |
| `03` | Оплачен | Yo'q | to'liq to'langan |
| `05` | Умидсиз | Yo'q | umidsiz qarz, undirish to'xtatilgan |
| `06` | Возврат | Yo'q | bekor qilingan, tovar omborga qaytgan |
| `07` | Изъятие | Yo'q | qaytarib olingan, to'langani qaytarilmaydi |

**BT-6.15.1.** "Qarz hisoblanadimi" ustuni mijozning **ochiq sdelkasi bor**
deb sanalishini belgilaydi. `01`, `02` va `04` — sanaladi; qolganlari yo'q.

> **`04` alohida e'tiborga loyiq.** Qurilma bloklangan bo'lsa ham mijoz
> qarzdor bo'lib qoladi — shuning uchun u ochiq sdelka sifatida sanaladi.
> Bu to'g'ri: blok qarzni bekor qilmaydi.

**BT-6.15.2.** Bekor qilish (`06`) va qaytarib olish (`07`) faqat `01` va
`02` holatidan mumkin.

> **Bu cheklov `04` uchun muammo.** iCloud bloklangan qurilma — aynan
> qaytarib olish yoki umidsiz deb belgilash kerak bo'ladigan holat, lekin
> `04` dan to'g'ridan-to'g'ri o'tib bo'lmaydi: avval sdelkani `01`/`02`
> ga qaytarish kerak. 〈biznes tasdiqlasin: shunday bo'lishi kerakmi〉

**BT-6.16.** Sdelka ochilgandan keyin **o'zgartirib bo'lmaydigan**
maydonlar: mijoz, tovar, chiqish narxi, boshlang'ich to'lov, muddat,
foiz stavkasi (qo'lda rejimda), valyuta.

> **Sabab.** Bular o'zgarsa grafik, foyda taqsimoti va investor qoldig'i
> qayta hisoblanishi kerak bo'ladi — allaqachon yozilgan operatsiyalar
> bilan ziddiyat chiqadi. O'zgartirish kerak bo'lsa sdelka bekor qilinib,
> yangisi ochiladi.

---

## 7. Pul, valyuta va yaxlitlash

**BT-7.1.** Tizimda hisob-kitob valyutasi — **AQSh dollari**. Barcha ichki
hisoblar dollarda yuritiladi.

**BT-7.2.** Pul bazada **tiyinda** saqlanadi (dollarning yuzdan biri).
Interfeysga chiqishda 100 ga bo'linadi. Bu suzuvchi nuqta xatolarini
oldini olish uchun.

**BT-7.3.** Foiz stavkasi ham 100 ga ko'paytirilgan holda saqlanadi:
`12%` → `1200`.

**BT-7.4.** **Istisno:** QQS stavkasi oddiy foizda saqlanadi (`12` = 12%).
Sabab: fiskal hujjatlarda stavka shunday yoziladi.

### 7.5 So'mdagi grafik

**BT-7.5.** Mijoz bilan **so'mda** kelishish mumkin. Bunday sdelkada:

- mijoz har oy **aynan bir xil so'm** to'laydi (yaxlit summa)
- dollardagi ekvivalent sdelka ochilgan kun kursida hisoblanadi
- butun ichki hisob (foyda, qarz, qoldiq) **dollarda** ketaveradi

**BT-7.6.** To'lov kuni kurs o'zgargan bo'lsa, farq **alohida operatsiya**
sifatida yoziladi (kurs farqi). U investor qoldig'iga ta'sir qiladi,
lekin sarmoyaga tegmaydi.

> **Nega shunday.** Mijozga "bu oy 3 100 000, keyingi oy 3 050 000"
> deyish mumkin emas — shartnomada bitta summa turadi. Lekin kompaniya
> dollarda hisob yuritadi. Farqni yashirish o'rniga uni ochiq qayd etamiz.

**BT-7.7.** So'm summasi dollardan **qayta hisoblanmaydi**. Aks holda
som → dollar → som aylanishi yaxlitlash tufayli mijoz kiritgan summadan
farq qiladi. Oxirgi qatorga aniq qoldiq beriladi.

---

## 8. Biznes jarayonlari

### 8.1 Sarmoya kiritish va qaytarish

**BT-8.1.** Investor pul kiritganda sarmoyasi ham, qoldig'i ham oshadi.

**BT-8.2.** Investorga pul qaytarilganda sarmoyasi ham, qoldig'i ham
kamayadi. Qoldiq yetmasa amal rad etiladi.

**BT-8.3.** Qoldiqqa pul qo'shish yoki undan ayirishning **sarmoyaga
tegmaydigan** usuli bo'lishi shart (`OINC` / `OEXP`).

> **Nega kerak.** Xato kiritilgan foyda chiqimini qaytarish, kassadan
> qaytgan pul, hisob tuzatishlari — bular sarmoya emas. Bu operatsiya
> bo'lmagani uchun xodimlar sarmoya kirimini ishlatishga majbur bo'lgan
> va investitsiya summasi noto'g'ri shishgan (291-investorda 6 154$).

### 8.2 Tovarni omborga kiritish

**BT-8.4.** Tovar kiritilganda uning to'liq qiymati (narx × miqdor)
investor qoldig'idan yechiladi.

**BT-8.5.** Qoldiq yetmasa tovar kiritilmaydi — tizim parametri
"zararda ishlash" yoqilgan bo'lmasa (16-bo'lim).

**BT-8.6.** Tovar tahrirlanganda eski qiymat qoldiqqa **qaytariladi**,
yangi qiymat qaytadan yechiladi. Faqat sotilmagan donalar uchun.

**BT-8.7.** Tovar o'chirilganda sotilmagan donalar qiymati qoldiqqa
qaytariladi. Agar tovar bo'yicha sotuv bo'lgan bo'lsa, u fizik
o'chirilmaydi — miqdori nolga tushiriladi va nofaol qilinadi.

> **Nega.** Sotuv tarixini yo'qotib bo'lmaydi: u mijoz shartnomasi va
> foyda taqsimoti bilan bog'langan.

### 8.3 Naqd sotuv

**BT-8.8.** Naqd sotuvda:

1. Sotish narxi va tannarx farqi = **ustama foyda** (OPC), darhol
   investor va boshqaruvchi o'rtasida bo'linadi
2. Sotuv summasining **to'liq qismi** investor qoldig'iga qaytadi
3. Tovar miqdori bittaga kamayadi

**BT-8.9.** Zararga sotish mumkin (farq manfiy). U holda foyda emas,
zarar taqsimlanadi — o'sha nisbatda.

### 8.4 Nasiya sotuv (rassrochka)

**BT-8.10.** Sdelka ochish uchun kerak: mijoz, tovar, chiqish narxi,
boshlang'ich to'lov, muddat, foiz turi, sana.

**BT-8.11.** Foiz ikki usulda belgilanadi:

| Usul | Nima kiritiladi | Foiz qayerdan |
|---|---|---|
| **Qo'lda (M)** | foiz stavkasi | xodim kiritadi |
| **Avtomat (A)** | oylik to'lov summasi | tizim hisoblaydi |

**BT-8.12.** Avtomat usulda oylik to'lov shunchalik kichik bo'lsaki,
mijoz qarzdan kam qaytarsa — sdelka ochilmaydi. Xato xabarida
**minimal oylik to'lov summasi** ko'rsatiladi (so'm sdelkada — so'mda).

**BT-8.13.** Chiqish narxi va boshlang'ich to'lov farqi tizim
parametridagi **maksimal sdelka summasidan** oshmasligi kerak.

**BT-8.14.** Sdelka ochilganda darhol:

1. Chiqish narxi va tannarx farqi = ustama foyda, taqsimlanadi
2. To'lov grafigi generatsiya qilinadi
3. Boshlang'ich to'lov investor qoldig'iga qo'shiladi
4. Tovar miqdori kamayadi

**BT-8.15.** Grafik teng oylik to'lovlardan iborat. Yaxlitlash qoldig'i
**oxirgi oyga** qo'shiladi.

### 8.5 To'lov qabul qilish

**BT-8.16.** To'lov aniq grafik qatoriga tushadi. Oldingi oylarda qarz
bo'lsa, avval o'sha yopilishi kerak.

**BT-8.17.** To'lov qator summasidan **ko'p** bo'lsa, ortiqcha qism
keyingi oylarga taqsimlanadi. Taqsimlash tartibini xodim tanlaydi:

| Tartib | Ta'siri |
|---|---|
| Oxiridan (`desc`) | muddat qisqaradi, oylik to'lov o'zgarmaydi |
| Boshidan (`asc`) | keyingi oylar yengillashadi |

**BT-8.18.** To'lov umumiy qarzdan ko'p bo'lishi mumkin emas.

**BT-8.19.** Grafik qatori **to'liq yopilganda** o'sha oy uchun nasiya
foizi foydasi hisoblanadi va taqsimlanadi. Yarim to'langan qator foyda
bermaydi.

**BT-8.20.** Tushgan summa investor qoldig'iga qo'shiladi.

**BT-8.21.** Oxirgi qarz yopilganda sdelka `03` holatiga o'tadi va
mijoz skoringi **majburiy** so'raladi.

**BT-8.22.** Har to'lovdan keyin mijozning barcha telefon raqamlariga
**SMS** yuboriladi.

**BT-8.23.** To'lovdan oldin grafik jami summasi sdelka summasiga mos
kelishi tekshiriladi. Mos kelmasa to'lov qabul qilinmaydi.

> **Nega.** Grafik qo'lda tahrirlangan bo'lishi mumkin. Mos kelmagan
> grafikka to'lov yozish qarzni noto'g'ri hisoblab yuboradi.

### 8.6 To'lovni bekor qilish

**BT-8.24.** Xato kiritilgan to'lovni bekor qilish mumkin. Bunda:

1. Grafik qatori ochiladi
2. Investor qoldig'idan summa ayiriladi
3. O'sha qator bo'yicha **taqsimlangan foyda bekor qilinadi** —
   investordan ham, boshqaruvchidan ham
4. So'm sdelkada kurs farqi ham teskari qilinadi

**BT-8.25.** Bekor qilish summasi to'langan summadan ko'p bo'lolmaydi.

### 8.7 Sdelkani bekor qilish va qaytarib olish

**BT-8.26.** **Bekor qilish** (`06`) — sdelka umuman bo'lmagandek.
Faqat hech qanday to'lov bo'lmagan sdelkada mumkin. Bunda ustama foyda
bekor qilinadi, boshlang'ich to'lov qaytariladi, tovar omborga qaytadi.

**BT-8.27.** **Qaytarib olish** (`07`, izyatiye) — mijoz to'lay
olmagani uchun tovar qaytarib olinadi. To'langan summalar
**qaytarilmaydi**. To'lanmagan grafik qatorlari nolga tushiriladi,
tovar yangi narxda omborga kiritiladi.

> **Farqi muhim.** Bekor qilish — xatoni tuzatish. Qaytarib olish —
> biznes qarori: mijoz to'lamadi, tovar qaytdi, to'langani kompaniyada
> qoldi.

### 8.8 Foyda taqsimoti

**BT-8.28.** Ikki xil foyda alohida hisoblanadi va alohida taqsimlanadi:

| Foyda | Qachon | Manbai |
|---|---|---|
| **Ustama (OPC)** | tovar sotilganda darhol | sotish narxi − tannarx |
| **Nasiya foizi (IPC)** | grafik qatori yopilganda | oylik to'lov − asosiy qarz ulushi |

**BT-8.29.** Har taqsimlashda investor va har bir boshqaruvchining
ulushi alohida operatsiya sifatida yoziladi. Har tiyin qayd etiladi.

**BT-8.30.** Foyda chiqim qilinganda (investor yoki boshqaruvchi pul
olganda) uning foyda hisobidan **ham**, investor qoldig'idan **ham**
ayiriladi.

**BT-8.31.** Foyda chiqimi mumkin bo'lgan summadan oshmasligi kerak.
Nasiya foydasi uchun hisobda **mijozlardagi qarz ayiriladi**: hali
qaytmagan pul foyda sifatida chiqarilmaydi.

### 8.9 Undiruv (soft collection)

**BT-8.32.** Kechikkan sdelkalar bo'yicha qo'ng'iroq natijasi qayd
etiladi: natija kodi, izoh, qo'ng'iroq paytidagi qarz summasi.

**BT-8.33.** Mijoz to'lashga va'da bergan bo'lsa, **va'da sanasi**
majburiy kiritiladi.

**BT-8.34.** Jarima muddati tugashiga 3, 2, 1 kun qolganda va tugagan
kuni avtomat eslatma yuboriladi. Har eslatma bir marta yuboriladi.

### 8.10 Filiallararo o'tkazma

**BT-8.35.** Bir filialdagi investordan boshqa filialdagi investorga pul
o'tkazish mumkin. Ikki tomonda ham sarmoya va qoldiq o'zgaradi.

**BT-8.36.** O'zidan o'ziga o'tkazib bo'lmaydi. Jo'natuvchida qoldiq ham,
sarmoya ham yetarli bo'lishi shart.

---

## 9. Operatsiyalar reestri

**BT-9.1.** Investor puliga tegadigan **har bir** harakat
`ipt_operations` ga yoziladi. Tizimda "izsiz" pul harakati bo'lmaydi.

**BT-9.2.** Har operatsiyada majburiy: kod, investor, summa, **izoh**,
kim va qachon yaratgani, filial.

| Kod | Nomi | Sarmoya | Qoldiq | Kim yaratadi |
|---|---|---|---|---|
| `INC` | Sarmoya kirimi | **+** | **+** | xodim |
| `EXP` | Sarmoya qaytarish | **−** | **−** | xodim |
| `OINC` | Boshqa kirim | — | **+** | xodim va tizim |
| `OEXP` | Boshqa chiqim | — | **−** | xodim va tizim |
| `IW` | Tovar omborga | — | **−** | tizim |
| `OPC` | Ustama foyda | — | — | tizim |
| `IPC` | Nasiya foydasi | — | — | tizim |
| `INCE` | Nasiya foydasidan chiqim | — | **−** | xodim |
| `OPE` | Ustama foydasidan chiqim | — | **−** | xodim |
| `OTHEREXP` | Boshqa xarajat | — | **−** | xodim |
| `I2IO` / `I2II` | Filiallararo o'tkazma | **−** / **+** | **−** / **+** | xodim |
| `PRDEL` | Tovar o'chirilgani uchun qaytarish | — | **+** | tizim |
| `PREDT` | Tovar tahriri uchun qaytarish | — | **+** | tizim |
| `PRFIX` | Tuzatish | 〈tasdiqlash kerak〉 | 〈tasdiqlash kerak〉 | tizim |

**BT-9.3.** Sarmoyaga **faqat** `INC`, `EXP` va filiallararo o'tkazma
tegadi. Boshqa hech qanday operatsiya sarmoya summasini o'zgartirmaydi.

> Bu qoida buzilgani uchun 291-investorda investitsiya 6 154$ ortiqcha
> chiqqan edi. Qoida endi kodda ham, hujjatda ham qayd etilgan.

---

## 10. Sayt katalogi

**BT-10.1.** ABM Store sayti tovar katalogini Monello bazasidan oladi.
Ma'lumot kiritish joyi — faqat Monello. Saytda tahrirlash yo'q.

**BT-10.2.** Tovar saytga chiqishi uchun **yettita shart** bajarilishi
kerak:

1. Holati "omborda" (`S`)
2. Miqdori noldan katta
3. Chakana narxi kiritilgan
4. Model kodi va nomi kiritilgan
5. Kategoriyasi kiritilgan
6. Brendi kiritilgan
7. Filialning vitrina kodi (`site_code`) belgilangan

Bittasi yetishmasa — tovar saytda **umuman ko'rinmaydi**.

**BT-10.3.** Bir xil konfiguratsiyadagi yangi tovarlar saytda **bitta
kartochka** bo'lib ko'rinadi, qoldiqlari qo'shiladi. Konfiguratsiya =
model + xotira + operativ xotira + rang.

**BT-10.4.** Ishlatilgan texnika birlashmaydi — har bir dona o'ziga xos
(batareya holati, IMEI).

**BT-10.5.** Bir konfiguratsiyada turli narx bo'lsa, saytga **eng past**
narx chiqadi.

> **Nega.** E'lon qilingan narxni ko'tarib bo'lmaydi. Eng past narx —
> har doim bajarib bo'ladigan va'da. Lekin narx farqi odatda xato,
> shuning uchun uni ko'rsatadigan tekshiruv bo'lishi kerak.

**BT-10.6.** Bir nechta hisob filiali bitta vitrinaga bog'lanishi mumkin.
U holda saytda bitta shourum ko'rinadi va qoldiqlari qo'shiladi.

**BT-10.7.** Katalogda **mijoz ma'lumotlari, ta'minotchi, tannarx va
investor** bo'lmasligi shart.

**BT-10.8.** Fiskal chek uchun tovarda MXIK kodi, o'lchov birligi va QQS
stavkasi bo'lishi kerak.

---

## 11. Hisobotlar va nazorat

**BT-11.1.** Qarzdorlik hisoboti kechikish yoshi bo'yicha guruhlanadi:
30 kungacha, 31–60, 61–90, 90 dan ortiq.

**BT-11.2.** Qarzdorlik hisoboti **kunlik surat** asosida quriladi, joriy
qayta hisoblash bilan emas.

> **Nega.** Har sdelka bo'yicha grafikni aylanib chiqish butun portfel
> uchun og'ir. Surat kun davomida o'zgarmaydi — nazorat paneli uchun
> aynan shu kerak.

**BT-11.3.** Kechikkanlar reestrida **hamma** kechikkan sdelka bo'ladi —
qo'ng'iroq ro'yxatidan farqli, u yerda bugun gaplashilganlar va to'lashga
va'da berganlar chiqarib tashlanadi.

**BT-11.4.** Sdelkalar dinamikasida bekor qilingan va qaytarib olingan
sdelkalar soni alohida ko'rsatiladi — bu sifat ko'rsatkichi.

**BT-11.5.** Hisobot metodlarida filial filtri **yo'q** — ular butun
tarmoq uchun. Shuning uchun ularga kirish alohida huquq bilan
cheklanadi.

**BT-11.6.** Investor qoldig'ining har o'zgarishi suratga olinadi
(balans jurnali) — keyin "bu raqam qayerdan chiqdi" degan savolga javob
berish uchun.

---

## 12. Integratsiyalar

| Integratsiya | Yo'nalish | Nima uchun |
|---|---|---|
| **SMS** | chiqish | to'lov qabul qilinganda mijozga xabar |
| **Telegram** | chiqish | xodim qo'lda qilgan moliyaviy amallar, xatolar, eslatmalar |
| **Sayt katalogi** | chiqish | tovar ro'yxati va qoldiq |
| **Hisobot API** | chiqish | boshqaruv paneli |
| **Valyuta kursi** | kirish | so'mdagi grafiklar uchun |
| **Chat (sun'iy intellekt)** | ikki tomonlama | xodim savoliga tizim ma'lumoti asosida javob |

**BT-12.1.** Tashqi tizimlarga kirish **token** orqali beriladi. Har
token aniq **qamrovga** ega: katalog, hisobot yoki chat. Bir qamrov
tokeni boshqasiga kira olmaydi.

**BT-12.2.** Tashqi tizimga baza xatolari **chiqmaydi** — ular logda
qoladi, tashqariga umumiy xabar ketadi.

**BT-12.3.** Telegramga **avtomat** operatsiyalar yuborilmaydi — faqat
xodim qo'lda qilgan amallar. Aks holda kanal spamga to'ladi.

**BT-12.4.** Chat tizimi **faqat o'qiy oladi**. U hech narsa yozmaydi,
SQL tuza olmaydi va faqat ro'yxatdan o'tgan so'rovlarni bajaradi.

**BT-12.5.** Mijozning telefon raqami, PINFL va manzili tashqi
tizimlarga (sayt, chat, hisobot) **hech qachon** chiqmaydi.

---

## 13. Ma'lumotnomalar

**BT-13.1.** Kategoriya, brend, rang, xarajat turi kabi ro'yxatlar
**ma'lumotnoma** sifatida saqlanadi. Yangi qiymat qo'shish uchun
dasturchi kerak emas.

**BT-13.2.** Ma'lumotnomalar bitta umumiy formadan boshqariladi.

**BT-13.3.** Kodlari dasturda qotirilgan ma'lumotnomalarda (tovar holati,
sdelka holati, filial) **qo'shish va o'chirish yopiq** — faqat nomini
o'zgartirish mumkin. Sabab foydalanuvchiga ko'rsatiladi.

**BT-13.4.** Ishlatilayotgan kodni o'chirib bo'lmaydi. O'rniga nofaol
qilinadi.

---

## 14. Nofunksional talablar

### 14.1 Audit va tarix

**BT-14.1.** Asosiy jadvallarning har bir o'zgarishidan **oldin** eski
holat tarix jadvaliga yoziladi. Kim, qachon, qanday amal — saqlanadi.

**BT-14.2.** Moliyaviy yozuvlar **o'chirilmaydi**. Xato bo'lsa teskari
operatsiya yoziladi.

### 14.2 Yaxlitlik

**BT-14.3.** Bir biznes amali — bitta tranzaksiya. Xato bo'lsa hammasi
qaytariladi, yarim holat qolmaydi.

**BT-14.4.** Tekshiruvlar **yozishdan oldin** bajariladi.

### 14.3 Xato xabarlari

**BT-14.5.** Xato xabari foydalanuvchiga tushunarli tilda bo'ladi va
**nima qilish kerakligini** aytadi. Texnik matn (baza xatosi, kod qatori)
chiqmaydi.

Misol: *"Ежемесячный платёж слишком мал. При долге 1 000$ и сроке 10 мес.
клиент вернёт всего 900$ — меньше суммы долга. Минимальный платёж:
1 300 000 сум."*

### 14.4 Til

**BT-14.6.** Interfeys va xato xabarlari — rus va o'zbek tillarida.
Ma'lumotnomalarda ikkala til uchun nom maydoni bor.

### 14.5 Xavfsizlik

**BT-14.7.** Tashqi tokenlar bazada **ochiq saqlanmaydi** — faqat xesh.

**BT-14.8.** API tokenlari administrator hisobiga bog'lanmaydi.

**BT-14.9.** Tizimga kirish filialga bog'lanadi; so'rovlar sessiya
filiali bo'yicha cheklanadi.

---

## 15. Tizim parametrlari

**BT-15.1.** Quyidagi qiymatlar kodda qotirilmaydi, sozlanadi:

| # | Parametr | Ta'siri |
|---|---|---|
| 1 | Maksimal sdelka summasi | undan katta nasiya berilmaydi |
| 2 | Zararda ishlash (Ha/Yo'q) | qoldiq yetmaganda amalga ruxsat |
| 3 | Grafik summasini tekshirish | grafik jami sdelka summasiga mos kelishi shartmi |
| 4 | Maksimal oylik to'lov (dollarda) | undan katta oylik to'lov qabul qilinmaydi |
| 5 | Minimal oylik to'lov (so'mda) | undan kichik so'm to'lov qabul qilinmaydi |
| — | Katalog rasm havolasi prefiksi | domen o'zgarsa shu qiymat yangilanadi |

**BT-15.2.** "Zararda ishlash" parametri **ehtiyotkorlik bilan**
ishlatiladi: u qoldiq yetmaganda ham amalga ruxsat beradi va manfiy
qoldiqqa olib kelishi mumkin.

---

## 16. Ma'lum cheklovlar va texnik qarz

Bu bo'lim ataylab hujjatda turibdi: yashirilgan cheklov — keyingi
xatoning manbai.

| # | Cheklov | Ta'siri | Holati |
|---|---|---|---|
| 1 | Qaytarilgan sarmoya alohida ustunga yig'ilmaydi | "qaytarilgan summa" hisoboti har doim nol | Ochiq |
| 2 | Hisobot metodlarida filial filtri yo'q | tarmoq raqamlari — alohida huquq talab qiladi | Yopildi (huquq tekshiruvi qo'shildi) |
| 3 | Fayl berish xizmati autentifikatsiyasiz | nomi topilgan har qanday fayl ochiladi | Ochiq — katalog rasmlari nginx'ga ko'chiriladi |
| 4 | Fayl qidirish har so'rovda butun papkani aylanadi | rasm ko'p bo'lsa sekinlashadi | Ochiq — yuqoridagi bilan birga hal bo'ladi |
| 5 | Operatsiya kodining "faol/nofaol" belgisi tekshirilmaydi | nofaol kodni API orqali chaqirish mumkin | Ochiq — ma'lumot tozalanmaguncha tuzatilmaydi |
| 6 | `04` (Блок icloud) holatidan bekor qilish va qaytarib olish yopiq | bloklangan qurilmani rasmiylashtirish uchun avval holatni qaytarish kerak | Ochiq — BT-6.15.2 |
| 7 | Katalog kaliti model kodidan yasaladi | model kodi tuzatilsa saytda yangi kartochka paydo bo'ladi | Qabul qilingan — formada ogohlantirish |

---

## 17. Qamrovdan tashqarida

Bu tizim quyidagilarni **qilmaydi**:

| Nima | Nega |
|---|---|
| Buxgalteriya hisoboti (1C va h.k.) | alohida tizim ishi |
| Soliq hisobotlari | fiskal maydonlar beriladi, hisobot emas |
| Ish haqi | kadr tizimi ishi |
| Mijozga onlayn kabinet | hozircha rejada yo'q |
| Onlayn to'lov qabul qilish | to'lov kassada qabul qilinadi, tizimga qayd etiladi |
| Skoring byurosi bilan integratsiya | 〈tasdiqlash kerak〉 |

---

## 18. Tasdiqlanishi kerak bo'lgan savollar

| # | Savol | Kimdan |
|---|---|---|
| 1 | `04` holatidan `07` (Изъятие) ga o'tish yo'li kerakmi? | biznes |
| 2 | Buxgalter roli qaysi amallarga ruxsat oladi? | rahbariyat |
| 3 | `PRFIX` operatsiyasi sarmoyaga tegadimi? | biznes |
| 4 | Qaytarilgan sarmoya alohida hisoblanishi kerakmi? | buxgalteriya |
| 5 | Skoring byurosi bilan integratsiya rejada bormi? | rahbariyat |
| 6 | O'lchov birligi kodlari soliq klassifikatoriga mosmi? | buxgalteriya |

---

## 19. Bog'liq hujjatlar

| Hujjat | Mavzu |
|---|---|
| `MONELLO_WEB_KATALOG_UZ.md` | katalog metodlari |
| `MONELLO_WEB_FRONT_ISHLAR_UZ.md` | front ekranlari |
| `MONELLO_WEB_MALUMOTNOMALAR_UZ.md` | ma'lumotnomalar formasi |
| `MONELLO_CHAT_UZ.md` | chat |
| `ABM_STORE_KATALOG_API_RU.md` | sayt jamoasiga API |
| `DOMEN_VA_HTTPS_UZ.md` | domen va HTTPS |

---

*Monello · Biznes talablari hujjati · 22.09.2026*
