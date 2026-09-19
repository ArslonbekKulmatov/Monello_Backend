# Nazorat paneli — front prototip

`Ipt_Dashboard` paketining to'rtta endpointi ustiga qurilgan bir faylli maket.
Build ham, npm ham, backend ham kerak emas: `index.html` ni brauzerda ochsangiz
bo'ldi.

    prototype/dashboard/index.html

## Nima ko'rsatadi

| Bo'lim | Endpoint | Metod |
|---|---|---|
| Qarzdorlik, yosh guruhlari bo'yicha | `GET /api/report/debt` | `reportDebt` |
| Kechikkan sdelkalar reyestri | `GET /api/report/overdue` | `reportOverdue` |
| Sdelkalar dinamikasi | `GET /api/report/trades` | `reportTrades` |
| Mijozlar bazasi | `GET /api/report/clients` | `reportClients` |

Har bo'limning uchta ko'rinishi bor: **Grafik**, **Jadval** va **JSON**. JSON —
API xuddi shu chaqiruvga qaytargan javobning o'zi, shuning uchun maketni
spetsifikatsiya bilan yonma-yon tekshirish mumkin.

## Ikki rejim

**Demo ma'lumot** (sukut bo'yicha) — baza hali ishga tushmagan bo'lsa ham maket
to'liq ko'rinadi. Raqamlar o'zaro bog'langan: `graph_amount − paid_amount =
total_debt`, u esa yosh guruhlari yig'indisiga teng, reyestr qatorlari ham
o'sha summani beradi. Mijoz ismlari o'ylab topilgan.

**Jonli API** — API manzili va tokenni kiritasiz, panel to'rtta `GET` so'rov
yuboradi. Token qamrovi `report` bo'lishi shart; katalog tokeni 401 oladi.

Jonli rejim faqat sahifa **o'z serveringizdan** ochilganda ishlaydi. Backendda
CORS `*` ga ochiq (`config/RestConfig.java`), lekin qattiq CSP qo'yilgan joydan
(masalan, hujjat ko'rish xizmatlaridan) brauzer so'rovni baribir to'sadi.

## Ishga tushirishdan oldin

Token brauzerda turishi — faqat sinov uchun. Panel ishga tushganda so'rovni
**panelning o'z backendi** qilsin, token serverda qolsin: bu sahifadagi token
konsoldan ham, kengaytmalardan ham ko'rinadi.

Bir narsani bazada tekshirish kerak: `Get_Debt` javobidagi `rate_usd`
(`ipt_util.Get_Rate('840')`) so'mda keladimi yoki tiyinda. Prototip uni qanday
kelsa shunday ko'rsatadi; tiyinda bo'lsa formatlashni 100 ga bo'lish kerak.

## Nimasi to'g'rilangan bo'lishi kerak

Prototip — maket, mahsulot emas. Jamoaga topshirishdan oldin:

- filiallar ro'yxati kodda qotib turibdi (`FILIALS`) — `ipt_s_filials` dan olinsin
- kechikkanlar reyestrida sahifalash bor, saralash yo'q
- davr filtri `debt` ga ta'sir qilmaydi: `Get_Debt` davr berilmasa oxirgi
  snapshot kunini qaytaradi, panel ham shunday qilyapti
- eksport (Excel/CSV) yo'q
