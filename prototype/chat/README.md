# Chat formasi — front prototip

    prototype/chat/index.html

Bitta fayl, build kerak emas.

## Ikki rejim

**Demo** — model chaqirilmaydi. Savol kalit so'zlar bo'yicha yo'naltiriladi
va tayyor ma'lumot ko'rsatiladi. Maqsad mexanizmni ko'rsatish: qaysi tool
chaqirilgani va u nima qaytargani. Raqamlar nazorat paneli prototipidagi
bilan bir xil.

Sinab ko'rish uchun: filiallar, sotuvlar, qarzdorlar, "Azizovning
rassrochkasi bormi", "52017 sdelka bo'yicha grafik". Shuningdek
"telefon raqamini ber" va "to'lovni kiritib yubor" deb ham ko'ring — rad
javobi qanday ko'rinishini ko'rasiz.

**Jonli** — Monello manzili va JWT so'raladi, `POST /api/chat` ga boradi.
Har savol pul turadi.

## Asosiy detal

Har javob ostida **qaysi tool ishlatilgani** yorliq bo'lib turadi. Bosilsa
o'sha tool qaytargan JSON ochiladi.

Bu bezak emas. Xodim raqam qayerdan kelganini tekshira olmasa, chatga
ishonib bo'lmaydi — ayniqsa qarzdorlik raqamlariga.

## Qilinmagan

- oqim (streaming) yo'q — javob to'liq tayyor bo'lgandan keyin chiqadi
- suhbat saqlanmaydi, sahifa yangilansa yo'qoladi
- jonli rejimda tool natijasi ko'rsatilmaydi: backend hozir faqat tool
  nomini qaytaradi. Natija ham kerak bo'lsa `SChat.ask` javobiga qo'shiladi
