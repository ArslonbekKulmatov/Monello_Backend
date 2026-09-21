# Ответ ABM Store — по шести уточнениям

> **Арслонбек, осталось заполнить одно место, отмеченное 〈…〉:**
> срок по `phys_filial_code` (п. 4). Остальное готово.

---

## RU

**Тема: шесть уточнений — пять закрыты, по МХИК нужен ваш ответ**

Спасибо за проверку доступа. Отвечаем по порядку.

**1. Справочник категорий — обновили, 28 кодов.**
У нас было 24; добавили недостающие четыре: `gadgets`, `accessories`,
`dyson-bu`, `gadgets-bu`. Лишних кодов у нас не было, так что расхождений
между списками больше нет.

`accessories` и `used` помечены как контейнеры **на уровне базы**: при
попытке положить товар в них API вернёт ошибку с подсказкой, какой раздел
выбрать. Одного примечания в письме было бы мало — на восьмистах позициях
кто-нибудь всё равно выбрал бы «Аксессуары».

**2. По одной позиции каждого вида — пришлём.**
Новый товар, б/у аппарат и аксессуар, с `model_code`. Согласны, что сверять
`model_code` с адресами карточек нужно до массового заполнения — см. п. 3,
там это критично.

**3. `id`: сделали ровно так — новые склеиваем, б/у нет.**

| Вид | Как строится `id` | Пример |
|---|---|---|
| Новый | `model_code`~`storage_gb`~`ram_gb`~`color_code` | `iphone-17-pro-max~256~x~silver` |
| Б/у | идентификатор складской строки | `104721` |

Разделитель `~`, потому что внутри `model_code` есть дефисы. Пустое поле
заменяется на `x`, иначе разные конфигурации получали бы одинаковый `id`.

> **Важное следствие.** `id` выводится из конфигурации, значит исправление
> опечатки в `model_code` меняет `id` — для вас это будет новая карточка.
> Поэтому п. 2 идёт первым: давайте сверим `model_code` на трёх позициях
> до того, как заполним восемьсот.

Если у двух строк одной конфигурации разные розничные цены, отдаём
**минимальную**: поднять объявленную цену нельзя, а минимальная — обещание,
которое всегда можно выполнить. Расхождение цен обычно ошибка, у нас есть
проверка, которая их находит.

**4. `quantity` — согласны, добавили общий остаток.**
Теперь в ответе рядом с `quantity` приходит `quantity_total` — сумма по всем
витринам. Разбивку оставили, она понадобится, когда заполним фактическое
местонахождение.

Срок по `phys_filial_code`: 〈укажите срок〉.

**5. Адреса.**

- **`erp.abmstore.uz` не открывается, потому что этого хоста не существует** —
  в спецификации он стоял как заполнитель в примерах, и это наша недоработка:
  выглядел как настоящий. Извините за потерянное время.
- **Боевой адрес сейчас — `http://37.140.216.159:9999`.** API и фотографии
  на одном хосте, фотографии по
  `http://37.140.216.159:9999/api/app/get-file?file=…`, без авторизации.
- **HTTPS — принято, но пока домена нет.** Сертификат на голый IP получить
  нельзя, поэтому переход упирается в домен; займёмся им.

**Что это значит для вас прямо сейчас.** Ваш сайт на `https`, наши
фотографии на `http` — браузер их заблокирует, карточки будут без картинок.
Это не настройка, а правило браузера, и обойти его с нашей стороны нельзя.
Пока домена нет, единственный рабочий вариант: **забирайте фотографию к себе
и отдавайте со своего https**. Заодно это снимет нагрузку с нашего сервера.

**Про токен.** Вы правы, по `http` он уходит открытым. До перехода на
`https` предлагаем ограничить доступ по IP — пришлите адрес вашего сервера,
и токен станет бесполезен для всех остальных. После перехода на `https`
выпустим новый токен, старый погасим: тот какое-то время ходил открытым.

**6. МХИК, единица измерения, ставка НДС — этих полей у нас нет.**

Проверили схему целиком: в учётной системе их нет ни в товаре, ни рядом.
Вы предположили, что мы их уже ведём для продаж в шоурумах — если фискальные
чеки там и выбиваются, то кассовым ПО, а не этой системой, и к нам эти
значения не попадают.

**Решили завести их у себя.** Три поля уже добавлены, заполнять их будут
через нашу админку вместе с остальной карточкой:

| Поле | Тип | Примечание |
|---|---|---|
| `mxik_code` | строка | МХИК, только цифры |
| `unit` | объект | `{code, name_ru, name_uz}` — единица измерения |
| `vat_rate` | число | Ставка НДС **в процентах**: `12` это 12% |

Обратите внимание на `vat_rate`: это проценты, не доля и не копейки.

Появятся в выдаче по мере заполнения — как и остальные поля, незаполненное
просто не приходит.

---

## UZ

**Mavzu: oltita aniqlik — beshtasi yopildi, MXIK bo'yicha javobingiz kerak**

Kirishni tekshirganingiz uchun rahmat. Tartib bo'yicha javob beramiz.

**1. Kategoriyalar ro'yxati — yangilandi, 28 ta kod.**
Bizda 24 ta edi; yetishmagan to'rttasi qo'shildi: `gadgets`, `accessories`,
`dyson-bu`, `gadgets-bu`. Bizda ortiqcha kod yo'q edi, ya'ni ro'yxatlar
endi to'liq mos.

`accessories` va `used` **baza darajasida** konteyner deb belgilandi: ularga
tovar qo'yishga urinilsa API xato qaytaradi va qaysi bo'limni tanlash
kerakligini aytadi. Xatda izoh bilan aytib qo'yish yetarli emas edi —
sakkiz yuz pozitsiyada kimdir baribir «Aksessuarlar» ni tanlardi.

**2. Har turdan bittadan pozitsiya — yuboramiz.**
Yangi tovar, ishlatilgan apparat va aksessuar, `model_code` bilan.
`model_code` ni kartochka manzillari bilan ommaviy to'ldirishdan oldin
solishtirish kerakligiga qo'shilamiz — 3-bandga qarang, u yerda bu juda
muhim.

**3. `id`: aynan shunday qildik — yangilari birlashadi, ishlatilganlari yo'q.**

| Turi | `id` qanday yasaladi | Misol |
|---|---|---|
| Yangi | `model_code`~`storage_gb`~`ram_gb`~`color_code` | `iphone-17-pro-max~256~x~silver` |
| Ishlatilgan | ombor qatorining identifikatori | `104721` |

Ajratgich `~`, chunki `model_code` ichida chiziqcha bor. Bo'sh maydon `x`
bilan almashtiriladi, aks holda turli konfiguratsiyalar bir xil `id` olardi.

> **Muhim oqibat.** `id` konfiguratsiyadan kelib chiqadi, ya'ni `model_code`
> dagi xatoni tuzatish `id` ni o'zgartiradi — siz uchun bu yangi kartochka
> bo'ladi. Shuning uchun 2-band birinchi turibdi: sakkiz yuztani
> to'ldirishdan oldin uchta pozitsiyada `model_code` ni solishtiraylik.

Bir konfiguratsiyaning ikki qatorida chakana narx har xil bo'lsa, **eng
pastini** beramiz: e'lon qilingan narxni ko'tarib bo'lmaydi, eng past narx
esa har doim bajarib bo'ladigan va'da. Narx farqi odatda xato, bizda uni
topadigan tekshiruv bor.

**4. `quantity` — qo'shilamiz, umumiy qoldiq qo'shildi.**
Endi javobda `quantity` yonida `quantity_total` keladi — barcha shourumlar
bo'yicha yig'indi. Taqsimotni qoldirdik, u haqiqiy joylashuv to'ldirilganda
kerak bo'ladi.

`phys_filial_code` bo'yicha muddat: 〈muddatni yozing〉.

**5. Manzillar.**

- **`erp.abmstore.uz` ochilmaydi, chunki bunday xost yo'q** — u
  spetsifikatsiyada misollar uchun o'rinbosar sifatida turgan edi, va bu
  bizning kamchiligimiz: haqiqiydek ko'rinibdi. Yo'qotilgan vaqt uchun uzr.
- **Hozirgi manzil — `http://37.140.216.159:9999`.** API ham, rasmlar ham
  shu xostda; rasmlar
  `http://37.140.216.159:9999/api/app/get-file?file=…` orqali,
  avtorizatsiyasiz.
- **HTTPS — qabul qilindi, lekin hozircha domen yo'q.** Yalang'och IP ga
  sertifikat olib bo'lmaydi, shuning uchun o'tish domenga bog'liq; shu
  bilan shug'ullanamiz.

**Bu siz uchun hozir nimani anglatadi.** Saytingiz `https`, rasmlarimiz
`http` — brauzer ularni bloklaydi va kartochkalar rasmsiz chiqadi. Bu
sozlama emas, brauzerning qoidasi, uni biz tomondan chetlab o'tib bo'lmaydi.
Domen olinmaguncha yagona ishlaydigan yo'l: **rasmni o'zingizga ko'chirib
olib, o'z https manzilingizdan bering**. Bu ayni paytda bizning serverimizga
yukni ham kamaytiradi.

**Token haqida.** Haqsiz, `http` orqali u ochiq ketadi. `https` ga
o'tgunimizcha IP bo'yicha cheklashni taklif qilamiz — serveringiz manzilini
yuboring, shunda token qolganlar uchun foydasiz bo'ladi. `https` ga
o'tgandan keyin yangi token chiqaramiz, eskisini bekor qilamiz: u bir muddat
ochiq yurgan.

**6. MXIK, o'lchov birligi, QQS stavkasi — bu maydonlar bizda yo'q.**

Sxemani to'liq tekshirdik: hisob tizimida ular na tovar kartochkasida, na
yonida bor. Siz ularni do'kondagi savdo uchun allaqachon yuritamiz deb
o'ylabsiz — agar u yerda fiskal chek chiqarilsa ham, buni kassa dasturi
qiladi, bu tizim emas, va o'sha qiymatlar bizga kelmaydi.

**O'zimizda ochishga qaror qildik.** Uchta maydon allaqachon qo'shildi,
ularni admin panelimiz orqali qolgan kartochka bilan birga to'ldiramiz:

| Maydon | Turi | Izoh |
|---|---|---|
| `mxik_code` | matn | MXIK, faqat raqam |
| `unit` | obyekt | `{code, name_ru, name_uz}` — o'lchov birligi |
| `vat_rate` | son | QQS stavkasi **foizda**: `12` bu 12% |

`vat_rate` ga e'tibor bering: bu foiz, ulush ham, tiyin ham emas.

To'ldirilgan sari javobda paydo bo'ladi — qolgan maydonlar kabi,
to'ldirilmagani umuman kelmaydi.

---

*Разработка учётной системы ABM Store · 21.09.2026*
