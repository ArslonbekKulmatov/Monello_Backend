# Monello'ni domenga ko'chirish — tavsiya va ketma-ketlik

**Hozir:**

| | Manzil |
|---|---|
| Front | `http://37.140.216.159:4201/auth/login` |
| Backend | `http://37.140.216.159:9999/api/` |

**Bor:** `abmstore.uz` domeni.

---

## 1. Qisqa javob

**Ikkita subdomen: biri front, biri butun backend.**

| Subdomen | Nima turadi | Port | Kim ishlatadi |
|---|---|---|---|
| `monello.abmstore.uz` | faqat front | 4201 | xodimlar |
| `monello-api.abmstore.uz` | **butun Monello backend API** + katalog rasmlari | 9999 | xodimlar va ABM Store sayti |

Ikkalasi ham o'sha bitta serverga (`37.140.216.159`) ketadi, oldida nginx
turadi. Port raqamlari tashqariga umuman chiqmaydi.

Bu — tanlangan variant: vazifalar bo'yicha toza bo'linish. Front bir
joyda, API bir joyda; ikkalasini keyinchalik boshqa serverga ajratish
ham oson.

### Nimaga e'tibor berish kerak

Butun API bitta manzilda turgani uchun sayt jamoasi biladigan hostda
`/api/app/request` ham ochiq bo'ladi — bu butun ERP kiradigan yo'l.
Uni ushlab turadigan narsalar:

| To'siq | Nimani ushlaydi |
|---|---|
| `/api/app/request` — JWT majburiy | tizimga kirmagan hech kim o'tmaydi |
| `/api/catalog/`, `/api/report/` — token **qamrovi** | katalog tokeni hisobotga kira olmaydi, aksincha ham |
| `Ipt_Dashboard.Check_Access` | hisobotni faqat `report` tokeni ko'radi |
| Metodlar ichidagi `Check_For_Seller` | katalog va chat metodlari uchun rol sharti |

Ya'ni chegara **tokenning qamrovi** bo'ladi, host emas. U allaqachon
qurilgan va ishlaydi.

Keyinchalik kerak bo'lsa `/api/app/` ni nginx'da IP bo'yicha cheklash
bir necha qator ish — 3.4-bo'limda tayyor turibdi, hozir o'chirilgan.

### Nomlar

`monello-api.` generik `api.` dan yaxshiroq: `api.abmstore.uz`
keyinchalik do'konning o'z API'si uchun kerak bo'lib qolishi mumkin.

`erp.abmstore.uz` ishlatilmaydi: u avvalgi spetsifikatsiyada o'rinbosar
sifatida turgan va sayt jamoasi uni sinab ko'rib chalkashgan edi.

---

## 2. DNS — subdomen qanday yaratiladi

### 2.0 Asosiy narsa

**Subdomen sotib olinmaydi.** U — DNS jadvalidagi bitta qator, xolos.
`abmstore.uz` sizda bo'lgani uchun uning istalgan subdomenini
yaratishingiz mumkin: pulsiz, chegarasiz, bir necha daqiqada.

Ya'ni qilinadigan ish: domen panelidagi DNS bo'limiga kirib, ikkita
yozuv qo'shish.

### 2.1 Avval: DNS qayerda boshqarilishini toping

Bu eng ko'p vaqt oladigan qadam, chunki uch xil joyda bo'lishi mumkin:

| Qayerda | Qanday tushunasiz |
|---|---|
| **Registrator** (domen sotib olingan joy) | `abmstore.uz` ni uzaytirish xatlari qaysi kompaniyadan kelsa — o'sha |
| **Hosting provayder** | sayt qayerda joylashgan bo'lsa, DNS ham ko'pincha o'sha yerda |
| **Cloudflare** yoki shunga o'xshash xizmat | saytni tezlashtirish/himoya uchun ulangan bo'lsa |

Aniq javobni NS yozuvi beradi:

```bash
dig NS abmstore.uz +short
```

Yoki brauzerda: `https://www.whatsmydns.net/#NS/abmstore.uz`

Chiqqan nom (masalan `ns1.ahost.uz` yoki `xxx.ns.cloudflare.com`) —
DNS aynan o'sha yerda boshqariladi. Panelga kirish ma'lumotlari ham
o'sha kompaniyaniki.

> Registrator va DNS boshqaruvchi **har xil** bo'lishi mumkin. Domen
> bir joyda sotib olinib, NS boshqa joyga yo'naltirilgan bo'lsa,
> yozuvlarni NS ko'rsatgan joyda qo'shasiz — registratorda emas.

### 2.2 Ikkita yozuv qo'shish

Panelda "DNS", "DNS записи", "DNS Management", "Zone Editor" yoki
"DNS Records" nomli bo'lim bo'ladi. "Add record" / "Добавить запись"
tugmasi.

**Birinchi yozuv — front:**

| Maydon | Nima yoziladi |
|---|---|
| Type / Тип | `A` |
| Name / Host / Имя | `monello` |
| Value / Points to / Значение | `37.140.216.159` |
| TTL | `300` |

**Ikkinchi yozuv — API:**

| Maydon | Nima yoziladi |
|---|---|
| Type | `A` |
| Name / Host | `monello-api` |
| Value / Points to | `37.140.216.159` |
| TTL | `300` |

Saqlaysiz. Tamom — subdomen yaratildi.

### 2.3 Eng ko'p uchraydigan xato: to'liq nom yozish

Ko'pchilik panelda **faqat chap qismi** yoziladi:

| To'g'ri | Noto'g'ri | Natija |
|---|---|---|
| `monello` | `monello.abmstore.uz` | `monello.abmstore.uz.abmstore.uz` bo'lib ketadi |

Panel domen nomini o'zi qo'shadi. Agar panel to'liq nomni talab qilsa
(zona fayli ko'rinishidagi eski panellarda), u holda **oxiriga nuqta**
qo'yiladi: `monello.abmstore.uz.`

Qaysi ko'rinish kerakligini bilish oson: mavjud yozuvlarga qarang.
Asosiy sayt `@` yoki `abmstore.uz` deb turgan bo'lsa — qaysi uslub
ekani ko'rinadi.

### 2.4 Boshqa savollar

**`A` yozuvmi yoki `CNAME`?** Bu yerda `A`. `A` — nomni **IP manzilga**
bog'laydi, `CNAME` esa **boshqa nomga**. Bizda IP bor, shuning uchun `A`.

**`www` kerakmi?** Yo'q. `www.monello.abmstore.uz` hech kimga kerak
emas.

**Wildcard (`*`) qo'ysam bo'ladimi?** Texnik jihatdan ha, lekin qo'ymang:
u holda `xyz.abmstore.uz` ham serverga tushadi va nginx'da ushlanmagan
so'rovlar paydo bo'ladi. Ikkita aniq yozuv aniqroq.

**Asosiy saytga ta'sir qiladimi?** Yo'q. `abmstore.uz` va
`www.abmstore.uz` yozuvlariga **tegmaysiz**. Subdomen — butunlay
alohida qator.

### 2.5 Tekshirish

Yozuvlar qo'shilgach:

```bash
dig +short monello.abmstore.uz
dig +short monello-api.abmstore.uz
```

Ikkalasi ham `37.140.216.159` qaytarishi kerak.

`dig` bo'lmasa (Windows): `nslookup monello.abmstore.uz`

Yoki brauzerda: `https://www.whatsmydns.net/#A/monello.abmstore.uz` —
dunyo bo'ylab qayerda tarqalganini ko'rsatadi.

**Tarqalish vaqti** odatda 5–30 daqiqa. TTL 300 qo'yilgani uchun xato
bo'lsa tuzatish ham 5 daqiqada ishlaydi. Hammasi ishlagach TTL ni 3600
ga ko'tarsangiz bo'ladi.

> Agar 30 daqiqadan keyin ham chiqmasa: yozuv saqlanganini tekshiring
> (ba'zi panellarda alohida "Apply changes" tugmasi bor), nomda
> ortiqcha `.abmstore.uz` yo'qligini ko'ring, va boshqa tarmoqdan
> (telefon internetidan) sinab ko'ring — kompyuteringiz eski javobni
> keshlab qolgan bo'lishi mumkin.

### 2.6 Cloudflare ishlatilsa

Yozuv qo'shishda yonida bulut belgisi bo'ladi:

| Holat | Ma'nosi |
|---|---|
| Kulrang bulut — **DNS only** | trafik to'g'ridan-to'g'ri serveringizga ketadi |
| To'q sariq bulut — **Proxied** | trafik Cloudflare orqali o'tadi |

**Boshida kulrang qiling.** To'q sariq bo'lsa certbot sertifikat
ololmaydi (HTTP-01 tekshiruvi serveringizga yetib bormaydi) va
serverda haqiqiy IP o'rniga Cloudflare IP'si ko'rinadi.

Hammasi ishlab, sertifikat olingach yoqsangiz bo'ladi — lekin u holda
Cloudflare'da SSL rejimi **Full (strict)** bo'lishi kerak.

---

## 3. Nginx

O'rnatish (Ubuntu/Debian):

```bash
sudo apt update
sudo apt install nginx
```

### 3.1 Umumiy blok

`/etc/nginx/conf.d/00-common.conf`:

```nginx
# WebSocket uchun (Angular dev-server va kelajakdagi ehtiyojlar)
map $http_upgrade $connection_upgrade {
    default upgrade;
    ''      close;
}

# Katalog API uchun oddiy chegara: bir IP dan sekundiga 10 so'rov
limit_req_zone $binary_remote_addr zone=api_zone:10m rate=10r/s;
```

### 3.2 `monello.abmstore.uz` — xodimlar uchun

`/etc/nginx/sites-available/monello.abmstore.uz`:

```nginx
server {
    listen 80;
    server_name monello.abmstore.uz;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    http2 on;
    server_name monello.abmstore.uz;

    ssl_certificate     /etc/letsencrypt/live/monello.abmstore.uz/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/monello.abmstore.uz/privkey.pem;

    access_log /var/log/nginx/monello.access.log;
    error_log  /var/log/nginx/monello.error.log;

    # Bu yerda faqat front. API monello-api.abmstore.uz da.
    location / {
        proxy_pass http://127.0.0.1:4201;
        proxy_http_version 1.1;
        proxy_set_header Upgrade    $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### 3.3 `monello-api.abmstore.uz` — butun backend

`/etc/nginx/sites-available/monello-api.abmstore.uz`:

```nginx
server {
    listen 80;
    server_name monello-api.abmstore.uz;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    http2 on;
    server_name monello-api.abmstore.uz;

    ssl_certificate     /etc/letsencrypt/live/monello-api.abmstore.uz/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/monello-api.abmstore.uz/privkey.pem;

    # Rasm yuklash 10 MB gacha — zapas bilan
    client_max_body_size 12m;

    access_log /var/log/nginx/monello-api.access.log;
    error_log  /var/log/nginx/monello-api.error.log;

    # --- Katalog rasmlari: to'g'ridan-to'g'ri diskdan ---
    # Java umuman ishtirok etmaydi. Sababi 7-bo'limda.
    # Bu blok /api/ dan YUQORIDA turishi kerak emas — yo'llari
    # kesishmaydi, lekin tartib o'qishga qulay.
    location /files/catalog/ {
        alias /opt/monello71/files/catalog/;
        try_files $uri =404;
        autoindex off;

        # Fayl nomi har yuklashda yangi, shuning uchun uzoq kesh xavfsiz
        expires 30d;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    # --- Sayt oladigan yo'llar: chegara bilan ---
    # Ular tashqi tarmoqdan keladi, shuning uchun sekundiga 10 so'rov.
    # Xodimlar yo'llariga bu chegara qo'yilmaydi.
    location /api/catalog/ {
        limit_req zone=api_zone burst=20 nodelay;
        proxy_pass http://127.0.0.1:9999/api/catalog/;
        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /api/report/ {
        limit_req zone=api_zone burst=20 nodelay;
        proxy_pass http://127.0.0.1:9999/api/report/;
        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # --- Qolgan butun API ---
    location /api/ {
        proxy_pass http://127.0.0.1:9999/api/;
        proxy_http_version 1.1;
        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Chat javobi uzoq kelishi mumkin
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
    }

    # API dan boshqa narsa bu yerda yo'q
    location / {
        return 404;
    }
}
```

### 3.4 Keyinroq: `/api/app/` ni IP bo'yicha cheklash

Hozir kerak emas, lekin kerak bo'lsa tayyor. Ofis IP manzili doimiy
bo'lsa, ERP yo'lini faqat o'sha manzilga ochish mumkin — sayt oladigan
`/api/catalog/` va `/api/report/` tegilmaydi:

```nginx
    location /api/app/ {
        allow 213.xxx.xxx.0/24;   # ofis
        allow 37.140.216.159;     # serverning o'zi
        deny  all;

        proxy_pass http://127.0.0.1:9999/api/app/;
        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 300s;
    }
```

Nginx aniqroq `location` ni tanlaydi, shuning uchun bu blok yuqoridagi
`/api/` dan ustun bo'ladi. Xodimlar uydan ishlasa bu to'siq halaqit
beradi — shuning uchun hozir qo'yilmadi.
```

Yoqish:

```bash
sudo ln -s /etc/nginx/sites-available/monello.abmstore.uz /etc/nginx/sites-enabled/
sudo ln -s /etc/nginx/sites-available/monello-api.abmstore.uz /etc/nginx/sites-enabled/
sudo nginx -t          # sintaksis tekshiruvi
sudo systemctl reload nginx
```

> Sertifikat hali yo'q bo'lgani uchun birinchi `nginx -t` xato beradi.
> Shuning uchun 4-bo'limni bajaring — certbot bloklarni o'zi to'ldiradi.

---

## 4. HTTPS — Let's Encrypt

```bash
sudo apt install certbot python3-certbot-nginx

sudo certbot --nginx \
  -d monello.abmstore.uz \
  -d monello-api.abmstore.uz \
  --agree-tos -m <sizning-pochtangiz> --redirect
```

Certbot DNS ni tekshiradi, sertifikat oladi va nginx konfiguratsiyasiga
`ssl_certificate` yo'llarini o'zi yozadi.

**Shartlar:**

- 80 va 443 portlar tashqaridan ochiq bo'lishi kerak (HTTP-01 tekshiruvi
  80 orqali ketadi)
- DNS allaqachon tarqalgan bo'lishi kerak

Avtomatik yangilanish o'zi sozlanadi. Tekshirish:

```bash
sudo certbot renew --dry-run
systemctl list-timers | grep certbot
```

Sertifikat 90 kun amal qiladi, 30 kun qolganda o'zi yangilanadi.

---

## 5. Port va xavfsizlik

Domen ishlagach, portlarni **tashqaridan yoping**:

```bash
sudo ufw allow 22
sudo ufw allow 80
sudo ufw allow 443
sudo ufw enable
```

`4201` va `9999` endi faqat `127.0.0.1` dan kerak. Agar ilovalar
`0.0.0.0` da tinglayotgan bo'lsa, ularni `127.0.0.1` ga bog'lang —
u holda ufw bo'lmasa ham tashqaridan kirib bo'lmaydi.

Spring uchun:

```properties
server.address=127.0.0.1
```

Angular dev-server uchun `--host 127.0.0.1`.

> **Eski manzil ishlab turmasin.** `http://37.140.216.159:9999` ochiq
> qolsa, HTTPS ga o'tishning ma'nosi yarmiga tushadi: kimdir eski
> manzilni ishlatsa trafik yana ochiq ketadi.

---

## 6. Ilova tomonida nima o'zgaradi

### 6.1 Baza — bitta qator

```sql
update core_properties
   set param_value = 'https://monello-api.abmstore.uz/files/catalog/'
 where param_name = 'catalog_file_url';
commit;
```

Diqqat: manzil **`/files/catalog/`** ga o'zgaradi, avvalgi
`/api/app/get-file?file=` emas. Sababi 7-bo'limda. Oxiridagi `/` shart —
fayl nomi shunchaki qo'shib yoziladi.

Tekshirish:

```sql
select Core_Util.Get_Properties('catalog_file_url') from dual;
```

Keyin brauzerda bitta rasmni ochib ko'ring.

### 6.2 Front

Front va API **turli subdomenda** turgani uchun API manzili to'liq
yozilishi kerak — nisbiy `/api` ishlamaydi.

Angular `environment.prod.ts`:

```ts
export const environment = {
  production: true,
  apiUrl: 'https://monello-api.abmstore.uz/api'
};
```

Manzil bitta joyda turgani muhim: keyin host o'zgarsa shu bitta qator
tuzatiladi. Xizmatlar ichida `http://37.140.216.159:9999` qotirib
yozilgan joy qolmasin — qidirib chiqing.

> **Alohida masala:** `4201` porti `ng serve` ga o'xshaydi. Agar
> shunday bo'lsa, ishlab chiqarish uchun `ng build --configuration
> production` qilib, natijani nginx'dan static qilib bering —
> dev-server ishlab chiqarishga mo'ljallanmagan (optimizatsiya yo'q,
> bitta oqim, xotira sarfi katta). U holda `location /` bloki bunday
> bo'ladi:
>
> ```nginx
> root /var/www/monello;
> index index.html;
> location / { try_files $uri $uri/ /index.html; }
> ```

### 6.3 CORS — tekshirildi, ishlaydi

Front `monello.abmstore.uz` dan `monello-api.abmstore.uz` ga murojaat
qiladi. Bu **boshqa origin**, ya'ni brauzer CORS qoidalarini qo'llaydi.

Kodni ko'rib chiqdim, qo'shimcha sozlash kerak emas:

| Nima | Holati |
|---|---|
| Kontrollerlarda `@CrossOrigin(origins = "*", maxAge = 3600)` | `CApp`, `CAuth`, `CUser`, `CDocument`, `CChat` — hammasida bor |
| Autentifikatsiya | `Authorization: Bearer <JWT>` sarlavhasida |
| Cookie bilan sessiya | ishlatilmaydi |

**Cookie emas, sarlavha bo'lgani muhim.** `Access-Control-Allow-Origin: *`
bo'lganda brauzer cookie yubormaydi — agar tizim sessiya cookie'siga
tayangan bo'lsa, frontni boshqa subdomenga ko'chirish login'ni buzardi.
Bu yerda JWT sarlavhada ketadi, shuning uchun muammo yo'q.

Bitta o'zgarish seziladi: endi har bir so'rovdan oldin brauzer `OPTIONS`
(preflight) yuboradi — `Authorization` sarlavhasi shuni talab qiladi.
`maxAge = 3600` tufayli javob bir soat keshlanadi, ya'ni qo'shimcha
so'rov soatiga bir marta. Nginx `OPTIONS` ni o'zi o'tkazib yuboradi,
alohida sozlash shart emas.

> `WebConfig.java` dagi global CORS sozlamasi **o'chirilgan**
> (`//@Configuration`). Uni yoqmang — kontrollerlardagi annotatsiyalar
> bilan ikki marta sozlash bir-biriga xalaqit berishi mumkin.

### 6.4 Spring

`application.properties` ga:

```properties
# nginx orqasida turganda haqiqiy IP va sxemani ko'rish uchun
server.forward-headers-strategy=framework

# sessiya cookie'si faqat HTTPS orqali ketsin
server.servlet.session.cookie.secure=true
server.servlet.session.cookie.http-only=true
```

Birinchisisiz loglarda hamma so'rov `127.0.0.1` dan kelgandek ko'rinadi.

### 6.5 Sayt jamoasiga yangi manzil

Ularga beriladigan bazaviy manzil:

```
https://monello-api.abmstore.uz/api/catalog/
```

> **Manzilni DNS ishlagandan KEYIN bering.** Spetsifikatsiyada hali
> ochilmaydigan host turishi bir marta bo'lgan: sayt jamoasi
> `erp.abmstore.uz` ni sinab ko'rib, mavjud emasligini aytgan edi.
> Shuning uchun `ABM_STORE_KATALOG_API_RU.md` hozircha ishlaydigan IP
> bilan qoldirildi — 4-qadam bajarilib, `curl` javob bergach ayting,
> men yangilab beraman.

---

## 7. Domenga chiqishdan oldin ko'rib chiqish kerak bo'lgan ikkita narsa

Bular hozir ham bor, lekin manzil ommaviy bo'lganda jiddiylashadi.

### 7.1 `get-file` autentifikatsiyasiz va butun papkani qidiradi

`GET /api/app/get-file?file=<nom>` hech qanday token so'ramaydi va
`/opt/monello71/files/` **butun daraxtini** qidirib, nomi mos kelgan
birinchi faylni qaytaradi.

Katalog rasmlari uchun bu to'g'ri — sayt ularni tokensiz ko'rsatishi
kerak. Lekin o'sha papkada shartnoma, pasport nusxasi yoki boshqa
hujjatlar bo'lsa, ular ham **nomi topilsa** ochiladi.

Yo'l o'tish (`../`) ishlamaydi — kod fayl nomini aynan solishtiradi,
ya'ni bu tomondan xavf yo'q. Masala faqat nomi taxmin qilinadigan
fayllarda.

**Shuning uchun** yuqoridagi nginx konfiguratsiyasida katalog rasmlari
`/files/catalog/` dan beriladi: o'sha bitta papka ochiq bo'ladi, qolgani
emas. `/api/app/` esa `monello-api.abmstore.uz` da umuman yo'q.

Tekshirib ko'ring, o'sha papkada nima borligini:

```bash
ls /opt/monello71/files/
```

Ichida `catalog/` dan boshqa narsa bo'lsa — nima ekanini ko'ring.

### 7.2 Har bir rasm so'rovida butun papka aylanib chiqiladi

`get-file` `Files.find(root, Integer.MAX_VALUE, ...)` bilan ishlaydi:
har bir so'rovda butun `/opt/monello71/files/` daraxti aylanib
chiqiladi. Bitta katalog sahifasida 20–30 ta rasm bo'lsa — 20–30 marta
to'liq aylanish.

Fayllar ko'paygan sari sekinlashadi. Sayt ochilgach bu sezilarli
bo'ladi.

Yuqoridagi nginx yechimi buni ham hal qiladi: rasmni nginx to'g'ridan
diskdan beradi, kesh sarlavhalari bilan. Java umuman qatnashmaydi.

---

## 8. Ketma-ketlik

| # | Qadam | Kim | Tekshiruv |
|---|---|---|---|
| 1 | DNS: ikkita A yozuv | domen paneli | `dig +short monello.abmstore.uz` |
| 2 | Nginx o'rnatish va konfiguratsiya | server | `sudo nginx -t` |
| 3 | 80/443 portlarni ochish | server | tashqaridan `curl -I http://monello.abmstore.uz` |
| 4 | Certbot bilan sertifikat | server | `sudo certbot renew --dry-run` |
| 5 | `catalog_file_url` ni yangilash | baza | brauzerda rasm ochiladi |
| 6 | Front `apiUrl` ni to'liq manzilga o'tkazish | front | login ishlaydi, konsolda CORS xatosi yo'q |
| 7 | Spring `forward-headers-strategy` | backend | logda haqiqiy IP |
| 8 | `4201` va `9999` ni yopish | server | tashqaridan ochilmasligi |
| 9 | Sayt jamoasiga yangi manzil | biz | ularning sinovi |

**5-qadamgacha eski manzil ishlab turaveradi**, ya'ni to'xtatish
kerak emas. Faqat 8-qadamda uziladi — uni hamma narsa tekshirilgandan
keyin qiling.

---

## 9. Tekshirish ro'yxati

Domen ishga tushgach:

```bash
# Sertifikat va sxema
curl -I https://monello.abmstore.uz
curl -I https://monello-api.abmstore.uz/api/catalog/products   # 401 kutiladi (tokensiz)

# HTTP dan HTTPS ga yo'naltirish
curl -I http://monello.abmstore.uz            # 301 kutiladi

# ERP yo'li ochiq, lekin JWT so'raydi
curl -i -X POST https://monello-api.abmstore.uz/api/app/request \
     -H 'Content-Type: application/json' -d '{"method":"test"}'
#   401/403 kutiladi — 200 kelsa TO'XTANG va ayting

# API subdomenida front yo'qligi
curl -I https://monello-api.abmstore.uz/            # 404 kutiladi

# Rasm nginx'dan kelyaptimi
curl -I https://monello-api.abmstore.uz/files/catalog/<fayl-nomi>.jpg
#   Server: nginx bo'lsin, Cache-Control: public, immutable bo'lsin
```

Brauzerda: front ochilsin, login ishlasin, katalog rasmi ko'rinsin,
konsolda "mixed content" va **CORS** ogohlantirishi bo'lmasin.

> CORS xatosi chiqsa, brauzer konsolida u aniq yoziladi: "blocked by
> CORS policy". U holda 6.3-bo'limga qarang — kontrollerda
> `@CrossOrigin` yo'q bo'lishi mumkin.

> **Aralash kontent.** Sayt `https` da bo'lib, rasm havolasi `http`
> bo'lsa brauzer rasmni **bloklaydi**. 5-qadam shuning uchun majburiy,
> ixtiyoriy emas.

---

*Monello backend · 21.09.2026*
