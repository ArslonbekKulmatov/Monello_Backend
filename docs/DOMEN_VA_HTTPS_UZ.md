# Monello'ni domenga ko'chirish — tavsiya va ketma-ketlik

**Hozir:**

| | Manzil |
|---|---|
| Front | `http://37.140.216.159:4201/auth/login` |
| Backend | `http://37.140.216.159:9999/api/` |

**Bor:** `abmstore.uz` domeni.

---

## 1. Qisqa javob

**Ikkita subdomen oling, bitta emas:**

| Subdomen | Nima turadi | Kim ishlatadi |
|---|---|---|
| `monello.abmstore.uz` | ERP front + uning to'liq API'si | **xodimlar** |
| `monello-api.abmstore.uz` | faqat katalog/hisobot API va rasmlar | **ABM Store sayti** |

Ikkalasi ham o'sha bitta serverga (`37.140.216.159`) ketadi, oldida nginx
turadi. Port raqamlari (`4201`, `9999`) tashqariga umuman chiqmaydi.

### Nega ikkita?

`/api/app/request` — bu **butun ERP**. Mijozlar, sdelkalar, to'lovlar,
hujjatlar — hammasi shu bitta yo'ldan o'tadi. U JWT bilan himoyalangan,
lekin sayt jamoasiga beriladigan spetsifikatsiyada turadigan manzil bilan
bir xil bo'lishi shart emas.

Ikkiga ajratsangiz:

- Saytga beriladigan manzilda **faqat** `/api/catalog/` va `/api/report/`
  ochiq bo'ladi. Qolgani o'sha subdomenda umuman yo'q — 404.
- Keyinchalik `monello.` ni IP bo'yicha cheklash yoki VPN orqasiga olish
  mumkin, sayt esa ishlayveradi.
- Sayt API'sini boshqa serverga ko'chirsangiz, sayt jamoasining
  sozlamasi o'zgarmaydi.

Qo'shimcha xarajat yo'q: bitta nginx, bitta sertifikat buyrug'i, ikkita
`server` bloki.

### Agar soddaroq yo'l kerak bo'lsa

Bitta subdomen ham ishlaydi: `monello.abmstore.uz`, front `/` da, API
`/api/` da. Lekin u holda ERP ning butun yuzasi sayt jamoasi biladigan
manzilda ochiq turadi. Boshidan ikkiga ajratish keyin ajratishdan arzon.

### Nomlar — tanlangan

`monello-api.` generik `api.` dan yaxshiroq: `api.abmstore.uz` keyinchalik
do'konning o'z API'si uchun kerak bo'lib qolishi mumkin, u holda ikkitasi
bir nomga da'vogar bo'lardi.

`erp.abmstore.uz` ishlatilmaydi: u avvalgi spetsifikatsiyada o'rinbosar
sifatida turgan va sayt jamoasi uni sinab ko'rib chalkashgan edi. O'sha
nomni endi haqiqiy qilib qo'yish yana chalkashtiradi.

---

## 2. DNS

Domen panelida ikkita `A` yozuv:

| Nomi | Turi | Qiymati | TTL |
|---|---|---|---|
| `monello` | A | `37.140.216.159` | 300 |
| `monello-api` | A | `37.140.216.159` | 300 |

TTL ni boshida 300 (5 daqiqa) qo'ying — xato bo'lsa tez tuzatasiz.
Hammasi ishlagach 3600 ga ko'taring.

Tekshirish:

```bash
dig +short monello.abmstore.uz
dig +short monello-api.abmstore.uz
```

Ikkalasi ham `37.140.216.159` qaytarishi kerak. DNS tarqalishi
odatda 5–30 daqiqa.

> **Cloudflare ishlatilsa:** boshida "proxy" (to'q sariq bulut) ni
> **o'chiring** — sertifikat olishda xalaqit qiladi. Hammasi ishlagach
> yoqsangiz bo'ladi.

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

    # Rasm yuklash 10 MB gacha — zapas bilan
    client_max_body_size 12m;

    access_log /var/log/nginx/monello.access.log;
    error_log  /var/log/nginx/monello.error.log;

    # --- Front ---
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

    # --- Backend ---
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
}
```

### 3.3 `monello-api.abmstore.uz` — sayt uchun

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

    access_log /var/log/nginx/api.access.log;
    error_log  /var/log/nginx/api.error.log;

    # --- Katalog rasmlari: to'g'ridan-to'g'ri diskdan ---
    # Java umuman ishtirok etmaydi. Sababi 5-bo'limda.
    location /files/catalog/ {
        alias /opt/monello71/files/catalog/;
        try_files $uri =404;
        autoindex off;

        # Fayl nomi har yuklashda yangi, shuning uchun uzoq kesh xavfsiz
        expires 30d;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    # --- Sayt oladigan API ---
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

    # Qolgan hamma narsa yo'q
    location / {
        return 404;
    }
}
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

API manzili endi **nisbiy** bo'lsin: `/api/...`, to'liq host bilan emas.
Front va backend bir xil subdomenda turgani uchun bu ishlaydi va
kelajakda host o'zgarsa front tegilmaydi.

Angular `environment.prod.ts`:

```ts
export const environment = {
  production: true,
  apiUrl: '/api'
};
```

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

### 6.3 Spring

`application.properties` ga:

```properties
# nginx orqasida turganda haqiqiy IP va sxemani ko'rish uchun
server.forward-headers-strategy=framework

# sessiya cookie'si faqat HTTPS orqali ketsin
server.servlet.session.cookie.secure=true
server.servlet.session.cookie.http-only=true
```

Birinchisisiz loglarda hamma so'rov `127.0.0.1` dan kelgandek ko'rinadi.

### 6.4 Sayt jamoasiga yangi manzil

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
| 6 | Front `apiUrl` ni `/api` ga o'tkazish | front | login ishlaydi |
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

# Sayt subdomenida ERP yopiqligi
curl -i https://monello-api.abmstore.uz/api/app/request   # 404 kutiladi

# Rasm nginx'dan kelyaptimi
curl -I https://monello-api.abmstore.uz/files/catalog/<fayl-nomi>.jpg
#   Server: nginx bo'lsin, Cache-Control: public, immutable bo'lsin
```

Brauzerda: front ochilsin, login ishlasin, katalog rasmi ko'rinsin,
konsolda "mixed content" ogohlantirishi bo'lmasin.

> **Aralash kontent.** Sayt `https` da bo'lib, rasm havolasi `http`
> bo'lsa brauzer rasmni **bloklaydi**. 5-qadam shuning uchun majburiy,
> ixtiyoriy emas.

---

*Monello backend · 21.09.2026*
