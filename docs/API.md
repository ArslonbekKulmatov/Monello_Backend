# Monello Backend — Frontend API hujjati

Bu hujjat frontend tomonidan chaqirilishi mumkin bo'lgan endpointlarni to'liq yig'ib beradi: request/response format, autentifikatsiya, xatolar, misollar.

> **Base URL** (production): `http://185.74.7.37:81`

## Mundarija

1. [Umumiy konvensiyalar](#1-umumiy-konvensiyalar)
2. [Autentifikatsiya (`/api/auth/*`)](#2-autentifikatsiya-apiauth)
3. [Universal RPC (`/api/app/request*`)](#3-universal-rpc-apiapprequest)
4. [Grid (`/api/app/grid*`)](#4-grid-apiappgrid)
5. [View select (`/api/app/execSelect`)](#5-view-select-apiappexecselect)
6. [Fayl operatsiyalari](#6-fayl-operatsiyalari)
7. [HTTP proxy](#7-http-proxy)
8. [Reinsurance import (`/api/app/reinsurance/import`)](#8-reinsurance-import-apiappreinsuranceimport)
9. [Boshqa modullar](#9-boshqa-modullar)
10. [Xatolar](#10-xatolar)

---

## 1. Umumiy konvensiyalar

### 1.1. Base URL

| Muhit | URL |
|---|---|
| Prod | `http://185.74.7.37:81` |
| Dev | (siznikini kiriting) |

### 1.2. Autentifikatsiya

Barcha endpointlar (`/api/auth/signin` va `/api/app/health` dan tashqari) **JWT Bearer token** talab qiladi:

```
Authorization: Bearer <JWT>
```

Yoki `/api/auth/signin` va `/api/app/request/v2` **HTTP Basic** ni ham qabul qiladi:

```
Authorization: Basic base64(login:password)
```

Til uchun (`ru`, `uz`, `en`):

```
lang: ru
```

### 1.3. Umumiy response formati

**Muvaffaqiyat:**

```json
{
  "success": true,
  "oper": true,
  "message": "successSave",
  "data": { ... }
}
```

**Xato:**

```json
{
  "success": false,
  "message": "Login xatosi",
  "error": { "code": 999, "message": "..." }
}
```

- `success` — HTTP 200 doim, xato mantiqiyroq — bu maydondan tekshiring
- `oper` — PL/SQL procedura operatsiyasining natijasi (`true` = amalga oshdi)
- `message` — i18n key yoki matn
- `data` — kontekstga bog'liq javob obyekti
- `error.code = 403` — JWT muddati o'tgan (qayta login qiling)
- `error.code = 999` — umumiy xato

### 1.4. Til

Har request'da headerda `lang` yuboring:
- `ru` — russkiy (default)
- `uz` — o'zbekcha
- `en` — inglizcha

---

## 2. Autentifikatsiya (`/api/auth/*`)

### 2.1. `POST /api/auth/signin` — kirish

**Request** (JSON):

```json
{ "login": "user1", "password": "pass" }
```

Yoki **Basic auth** header bilan (body bo'sh):

```
Authorization: Basic dXNlcjE6cGFzcw==
```

**Response — success:**

```json
{
  "token": "eyJhbGciOi...",
  "expiresIn": "86400000",
  "id": 123,
  "login": "user1",
  "firstName": "Arslonbek",
  "lastName": "Kulmatov",
  "patronymicName": "…",
  "firstLogon": false,
  "roles": ["ROLE_ADMIN"]
}
```

**Response — xato:**

```json
{ "success": false, "message": "login.error" }
```

**Foydalanish:** Tokenni `localStorage`ga saqlang, keyingi so'rovlarda `Authorization: Bearer <token>` bilan yuboring.

---

### 2.2. `POST /api/auth/signup` — ro'yxatdan o'tish

**Request:**

```json
{
  "method": "userReg",
  "login": "newuser",
  "password": "Secret123",
  "firstName": "Ali",
  "lastName": "Valiyev",
  "patronymicName": "Salimovich"
}
```

**Response:**

```json
{
  "success": true,
  "userId": 456,
  "jwt": "eyJ...",
  "expiresIn": "86400000",
  "firstName": "Ali",
  "lastName": "Valiyev",
  "patronymicName": "Salimovich"
}
```

---

### 2.3. `POST /api/auth/register` — foydalanuvchi qo'shish (admin)

**Request:**

```json
{
  "method": "add_user",
  "module_id": 10,
  "login": "employee1",
  "password": "TempPass",
  "state": "A",
  "emp_id": 12345
}
```

**Response:**

```json
{ "success": true, "message": "successSave" }
```

---

### 2.4. `POST /api/auth/updatePassword` — parolni tiklash

**Request:**

```json
{
  "method": "forgotPassword",
  "phoneNum": "+998901234567",
  "password": "NewPass123",
  "login": "user1"
}
```

---

### 2.5. `POST /api/auth/confirmCode` — kod tasdiqlash

**Send** (SMS yuborish):

```json
{ "method": "sendConfirmCode", "phoneNum": "+998901234567" }
```

**Check** (kod tekshirish):

```json
{ "method": "checkConfirmCode", "phoneNum": "+998901234567", "code": "1234" }
```

**Response:**

```json
{ "success": true, "oper": true, "message": "code.valid", "data": { ... } }
```

---

### 2.6. `POST /api/auth/updateLoginPassword` — login+parolni o'zgartirish

**Request:**

```json
{ "user_id": 123, "login": "new_login", "password": "NewPass456" }
```

**Response:**

```json
{ "success": true, "message": "Successfully updated." }
```

---

### 2.7. `POST /api/auth/signout` — chiqish

Body kerak emas. Response bo'sh (`200 OK`). Frontend'da tokenni o'chirib qo'ying.

---

## 3. Universal RPC (`/api/app/request*`)

**Bu — asosiy endpoint.** Deyarli barcha biznes-operatsiyalar shu orqali ketadi. Frontend `method` nomini yuboradi, backend uni `CORE_METHODS` jadvalida topib, mos PL/SQL procedurani chaqiradi.

### 3.1. `POST /api/app/request`

**Request:**

```json
{
  "method": "getCoverInfo",
  "params": {
    "cover_id": 48281
  }
}
```

**Response — success:**

```json
{
  "success": true,
  "oper": true,
  "message": "",
  "data": {
    "cover_id": 48281,
    "case_number": "43931",
    "applicant": "TENGE BANK ATB",
    ...
  }
}
```

**Response — xato:**

```json
{
  "success": false,
  "message": "This method is not active."
}
```

**Response — JWT eskirgan:**

```json
{
  "success": false,
  "message": "JWT token has been expired"
}
```
→ Frontend'da yangi login sahifasiga yo'naltiring.

**Foydalanish namunasi (fetch):**

```js
async function apiCall(method, params = {}) {
  const resp = await fetch(`${BASE_URL}/api/app/request`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${jwt}`,
      'Content-Type': 'application/json',
      'lang': 'ru'
    },
    body: JSON.stringify({ method, params })
  });
  const json = await resp.json();
  if (!json.success) throw new Error(json.message);
  return json.data;
}

// misol:
const data = await apiCall('getCoverInfo', { cover_id: 48281 });
```

---

### 3.2. `POST /api/app/request/v2` — yangi versiya

Bir xil `/request` bilan, farqi:
- Response strukturasi biroz boshqa (obyekt ancha yassilangan)
- HTTP Basic auth ni ham qabul qiladi (JWT'siz)
- `error` obyekti bilan xato qaytaradi

**Response — success:**

```json
{
  "success": true,
  "oper": true,
  "cover_id": 48281,
  "applicant": "...",
  ...
}
```

**Response — xato:**

```json
{
  "success": true,
  "error": { "code": 999, "message": "Contract not found." }
}
```

---

### 3.3. `POST /api/app/wtrequest` — session'siz request

`Set_User_Session` ni chaqirmaydi — foydalanuvchi konteksti kerak bo'lmaganda ishlatiladi (masalan, ochiq referenslar).

---

### 3.4. `GET /api/app/health` — sog'lomlik tekshiruvi

Response — `200 OK`:

```json
{ "status": "UP", "db": "UP" }
```

Yoki `503 Service Unavailable`:

```json
{ "status": "DOWN", "db": "DOWN", "error": "connection timeout" }
```

Auth kerak emas.

---

## 4. Grid (`/api/app/grid*`)

Screenshotdagi asosiy jadval — barcha jadvallar shular orqali yuklanadi.

### 4.1. `POST /api/app/grid` — eski grid

**Request:**

```json
{
  "grid_id": 42,
  "page": 1,
  "size": 100,
  "filters": { "case_number": "43931" }
}
```

**Response:**

```json
{
  "success": true,
  "total": 10094,
  "page": 1,
  "size": 100,
  "columns": [
    { "code": "case_number", "label": "№ дело" },
    ...
  ],
  "rows": [ { ... }, { ... } ]
}
```

---

### 4.2. `POST /api/app/grid/new` — yangi grid (session scope bilan)

Filter va sortirovka session'da saqlanadi. Foydalanuvchi ilovaga qaytganda oldingi holat tiklanadi.

**Request:** grid_id + params.

---

### 4.3. `POST /api/app/grid/get_filter` — filter olish

Ma'lum bir ustun uchun mumkin filter qiymatlarini qaytaradi (dropdown uchun).

**Request:**

```json
{ "grid_id": 42, "column": "state" }
```

---

### 4.4. `POST /api/app/grid/remove_session` — session tozalash

Sortirovka/filterlarni tiklaydi.

```json
{ "grid_id": 42 }
```

---

### 4.5. `POST /api/app/grid/to_excel` — Excel export

**Request:** Grid parametri (yuqoridagilar bilan bir xil).

**Response:** binary `application/octet-stream`, Content-Disposition header bilan.

```js
const resp = await fetch(`${BASE_URL}/api/app/grid/to_excel`, {
  method: 'POST',
  headers: { 'Authorization': `Bearer ${jwt}`, 'Content-Type': 'application/json' },
  body: JSON.stringify({ grid_id: 42 })
});
const blob = await resp.blob();
const url = URL.createObjectURL(blob);
const a = document.createElement('a');
a.href = url;
a.download = 'export.xlsx';
a.click();
```

---

## 5. View select (`/api/app/execSelect`)

Oracle view'ni to'g'ridan-to'g'ri o'qish.

**Request:**

```json
{
  "view": "pi_covers_v2_v",
  "wh": "id = 48281"
}
```

**Response:**

```json
{ "success": true, "rows": [ { ... } ] }
```

> ⚠️ `wh` foydalanuvchi kiritmasin — bu SQL injection xavfi. Faqat backendcha tayyor query'lar uchun ishlating.

---

## 6. Fayl operatsiyalari

### 6.1. `POST /api/app/requestFile` — fayl bilan RPC

`multipart/form-data`:

```
params  = JSON string ({ "method": "uploadDocument", "params": {...} })
file    = binary
```

**Response:**

```json
{
  "success": true,
  "oper": true,
  "message": "successSave",
  "data": { "file_name": "abc123.pdf" }
}
```

**Foydalanish:**

```js
const fd = new FormData();
fd.append('params', JSON.stringify({ method: 'uploadDoc', params: { cover_id: 48281 } }));
fd.append('file', fileInput.files[0]);

await fetch(`${BASE_URL}/api/app/requestFile`, {
  method: 'POST',
  headers: { 'Authorization': `Bearer ${jwt}` },  // Content-Type qo'shmang!
  body: fd
});
```

### 6.2. `GET /api/app/get-file?file=abc123.pdf` — fayl yuklab olish

Response — `inline` (browser'da ochiladi):

```
Content-Type: application/pdf
Content-Disposition: inline; filename="abc123.pdf"
```

Faqat `/opt/monello71/files/` ichidagi fayllarga kirish beriladi.

---

## 7. HTTP proxy

Backend proxy sifatida tashqi API'larga so'rov jo'natadi.

### 7.1. `POST /api/app/send-http-request`

**Request:**

```json
{
  "url": "https://api.example.com/endpoint",
  "body": "{\"key\":\"value\"}",
  "token": "Bearer abc123",
  "method_type": "POST",
  "is_proxy": true,
  "proxy_ip": "192.168.1.201",
  "proxy_port": 8080
}
```

**Response:**

```json
{ "success": true, "data": { ... } }
```

### 7.2. `POST /api/app/get-http-request` — GET so'rov

### 7.3. `POST /api/app/send-form-data-request` — multipart forma yuborish

Fayl `/opt/monello71/files/` dan olinadi.

### 7.4. `POST /api/app/get-http-token`

Autentifikatsiya tokenini olish.

---

## 8. Reinsurance import (`/api/app/reinsurance/import`)

**YANGI ENDPOINT** — Qayta sug'urta batch importi (Excel qatorlar + PDF fayllar).

### 8.1. `POST /api/app/reinsurance/import`

**Multipart/form-data:**

| Field | Turi | Izoh |
|---|---|---|
| `data` | string | JSON — `{"rows":[{...},...]}` yoki tekis `[{...}]` massiv |
| `documents` | file[] | Bir yoki bir necha PDF, nomi `<reinsuranceContractUuid>.pdf` |

**Excel ustunlari (25 ta):**

| Ustun | Majburiy | Tavsif |
|---|:---:|---|
| `reinsuranceContractUuid` | ✅ | UUID formatida, mos PDF fayli bo'lishi shart |
| `currencyId` | | Valyuta ID (2 = USD) |
| `exchangeRate` | | Ayirboshlash kursi |
| `totalDamageSum` | ✅ | Umumiy zarar summasi (UZS) |
| `totalDamageInForeignCurrency` | | Umumiy zarar valyutada |
| `totalSharePaymentSum` | ✅ | Ulush to'lovi summasi (UZS) |
| `totalSharePaymentInForeignCurrency` | | Ulush to'lovi valyutada |
| `claimUuid` | | Da'vo UUID (bor bo'lsa alternative payload) |
| `contractNumber` | | Shartnoma raqami |
| `claimNumber` | | Da'vo raqami |
| `claimDate` | | Da'vo sanasi |
| `decisionDate` | | Qaror sanasi |
| `paymentDate` | | To'lov sanasi |
| `paymentAmountSum` | | To'lov summasi |
| `paymentAmountInForeignCurrency` | | To'lov valyutada |
| `insuranceCompensationSum` | | Kompensatsiya summasi |
| `insuranceCompensationInForeignCurrency` | | Kompensatsiya valyutada |
| `sharePaymentSum` | | Ulush to'lovi (qator) |
| `sharePaymentInForeignCurrency` | | Ulush to'lovi valyutada |
| `eventDateTime` | | Hodisa sanasi (`YYYY-MM-DD`) |
| `regionId` | | Region kodi |
| `countryId` | | Mamlakat kodi |
| `districtId` | | Tuman kodi |
| `place` | | Joy nomi |
| `eventInfo` | | Qo'shimcha ma'lumot |

**Namunali `data` payload:**

```json
{
  "rows": [
    {
      "reinsuranceContractUuid": "061ff2c8-adb5-4d6d-b08e-26193a53808b",
      "currencyId": "2",
      "exchangeRate": "12021.32",
      "totalDamageSum": "8581593.59",
      "totalDamageInForeignCurrency": "710.07",
      "totalSharePaymentSum": "1865638.45",
      "totalSharePaymentInForeignCurrency": "157.09",
      "claimUuid": "a2fd15eb-bc61-48d7-b73a-d7df4f747d0f",
      "insuranceCompensationSum": "1484392.59",
      "insuranceCompensationInForeignCurrency": "123.48",
      "sharePaymentSum": "1865638.45",
      "sharePaymentInForeignCurrency": "157.09"
    }
  ]
}
```

**Response:**

```json
{
  "success": true,
  "batchId": "8f2a3c1d-4b5e-6a7f-8d9c-1e2f3a4b5c6d",
  "totalRows": 3,
  "insertedRows": 3,
  "invalidRows": 1,
  "invalid": [
    {
      "rowNumber": 2,
      "reinsuranceContractUuid": "bad-uuid",
      "message": "reinsuranceContractUuid is not a valid UUID"
    }
  ],
  "sendResult": {
    "batchId": "8f2a...",
    "sent": 2,
    "failed": 0,
    "rows": [
      { "id": 10001, "uuid_row": "061ff2c8-...", "sent": true, "claimUuid": "a1b2..." },
      { "id": 10002, "uuid_row": "79c4eb3b-...", "sent": true, "claimUuid": "c3d4..." }
    ]
  },
  "fileResult": {
    "batchId": "8f2a...",
    "sent": 2,
    "failed": 0,
    "rows": [
      { "id": 10001, "fileName": "061ff2c8-....pdf", "sent": true },
      { "id": 10002, "fileName": "79c4eb3b-....pdf", "sent": true }
    ]
  }
}
```

**Response — xato:**

```json
{ "success": false, "error": "data (JSON) is required." }
```

**Validation qoidalari:**

1. `reinsuranceContractUuid` bo'sh emas va UUID formatida
2. Mos `<uuid>.pdf` fayli `documents[]` da bor
3. `totalDamageSum`, `totalSharePaymentSum` bo'sh emas
4. Har bir invalid qator ham `PI_FOND_REINSURANCES` ga `error_msg` bilan insert qilinadi (audit), lekin Fond'ga yuborilmaydi

**JavaScript to'liq namuna:**

```js
async function importReinsurance(rows, pdfFiles) {
  const fd = new FormData();
  fd.append('data', JSON.stringify({ rows }));
  for (const [uuid, file] of pdfFiles) {
    fd.append('documents', file, uuid + '.pdf');
  }

  const resp = await fetch(`${BASE_URL}/api/app/reinsurance/import`, {
    method: 'POST',
    headers: { 'Authorization': `Bearer ${jwt}` },  // Content-Type yo'q
    body: fd
  });

  const result = await resp.json();

  if (!result.success) {
    throw new Error(result.error);
  }

  console.log(`Batch ${result.batchId}: ${result.sendResult.sent}/${result.totalRows} sent`);

  // Xato qatorlarni ko'rsatish
  if (result.invalidRows > 0) {
    for (const err of result.invalid) {
      console.warn(`Row ${err.rowNumber}: ${err.message}`);
    }
  }

  return result;
}
```

**Upload progress bar:**

```js
const xhr = new XMLHttpRequest();
xhr.open('POST', `${BASE_URL}/api/app/reinsurance/import`);
xhr.setRequestHeader('Authorization', `Bearer ${jwt}`);

xhr.upload.onprogress = (e) => {
  if (e.lengthComputable) {
    const pct = Math.round((e.loaded / e.total) * 100);
    console.log(`Uploaded ${pct}%`);
  }
};

xhr.onload = () => {
  const result = JSON.parse(xhr.responseText);
  // ...
};

xhr.send(fd);
```

---

## 8b. Fond batch import (Ariza / Qaror / To'lov)

Sug'urta hodisasi hujjatlari (Ariza → Qaror → To'lov) uchun Excel'dan bulk import. Reinsurance bilan bir xil pattern.

**Ish oqimi:**
```
1. Ariza (Claim)    → POST /api/app/fond/claim/import    → claim UUID
2. Qaror (Decision) → POST /api/app/fond/decision/import → decision UUID
   - decisionId=2 (rad etildi) → tugadi
   - decisionId=1 (to'lov qaror) → 3-qadam
3. To'lov (Payout)  → POST /api/app/fond/payout/import   → payout UUID
```

### 8b.1. `POST /api/app/fond/claim/import` — Ariza

**Request body** (JSON):

```json
{
  "rows": [
    {
      "polisUuid": "65fcaf24-84b3-47e3-b796-ee3a9da23f88",
      "regionId": "10",
      "areaTypeId": "1",
      "claimNumber": "95287",
      "claimDate": "2026-09-14",
      "insuranceCompensationSum": "77183500.23",
      "applicant.organization.regionId": "23",
      "applicant.organization.inn": "306053809",
      "applicant.organization.name": "ESHMURATOV ISLOMJON OK",
      "damageType": "4",
      "damage[].claimedDamage": "77183500.23",
      "damage[].organization.inn": "306053809",
      "damage[].appraiserInn": "204735191",
      "damage[].appraiserReportNumber": "382MK/26",
      "damage[].appraiserReportDate": "2026-09-10",
      "insuranceOrgId": "1064"
    }
  ]
}
```

**Ustunlar** — Excel header dot-notation'i (yoki lower_snake_case). 160 ta ustun (asosiy `PI_FOND_CLAIMS` jadval strukturasi). Foydalanuvchi faqat kerakli ustunlarni yuboradi — qolganlari NULL.

**damageType**:
- `1` = life damage
- `2` = health damage
- `3` = vehicle damage
- `4` = other property damage

**Response:**

```json
{
  "success": true,
  "batchId": "8f2a...",
  "totalRows": 1,
  "insertedRows": 1,
  "invalidRows": 0,
  "invalid": [],
  "sendResult": {
    "batchId": "8f2a...",
    "sent": 1,
    "failed": 0,
    "rows": [
      { "id": 371, "claimNumber": "95287", "sent": true, "claimUuid": "25b0d599-aa2d-4394-b7fb-d5d2ef26e5a5" }
    ]
  }
}
```

### 8b.2. `POST /api/app/fond/decision/import` — Qaror

**Request:**

```json
{
  "rows": [
    {
      "claimUuid": "25b0d599-aa2d-4394-b7fb-d5d2ef26e5a5",
      "decision.decisionId": 1,
      "decision.reasonForPayment": "6832",
      "decisionDate": "2026-09-14"
    },
    {
      "claimUuid": "abc-....",
      "decision.decisionId": 2,
      "decision.rejectionReason": "Полис хат/срок...",
      "decisionDate": "2026-09-14"
    }
  ]
}
```

`decisionId = 1` — to'lov, `decisionId = 2` — otkaz (rad etilgan, keyingi qadam yo'q).

**Response:**

```json
{
  "success": true, "batchId": "...", "totalRows": 2, "insertedRows": 2, "invalidRows": 0,
  "sendResult": {
    "sent": 2, "failed": 0,
    "rows": [
      { "id": 221, "claim_uuid": "...", "sent": true, "decisionUuid": "54b549a2-..." },
      { "id": 222, "claim_uuid": "...", "sent": true, "decisionUuid": "77c1e2f3-..." }
    ]
  }
}
```

### 8b.3. `POST /api/app/fond/payout/import` — To'lov

**Faqat `decisionId = 1` bo'lgan (otkaz emas) qarorlar uchun.**

**Request:**

```json
{
  "rows": [
    {
      "decisionUuid": "54b549a2-d6fb-4f22-a348-00bc0191e008",
      "payoutSum": "77183500.23",
      "payoutDate": "2026-09-14",
      "paymentOrderNumber": "14619",
      "recipient": "ESHMURATOV ISLOMJON OK",
      "inheritanceDocumentNumberAndDate": null,
      "type": "OTHER"
    }
  ]
}
```

**`type`**: `LIFE` / `HEALTH` / `OTHER` — PL/SQL bu asosda `lifePayouts` / `healthPayouts` / `otherPropertyPayouts` payload'ni yasaydi.

**Response:**

```json
{
  "success": true, "batchId": "...", "totalRows": 1, "insertedRows": 1,
  "sendResult": {
    "sent": 1,
    "rows": [
      { "id": 182, "decisionUuid": "54b549a2-...", "sent": true, "payoutUuid": "9a8b7c-..." }
    ]
  }
}
```

### 8b.4. Frontend integratsiyasi

```js
// 1. Ariza yuborish
const claim = await api('/api/app/fond/claim/import', {
  method: 'POST',
  body: JSON.stringify({ rows: excelRows })
});
const claimUuids = claim.sendResult.rows
  .filter(r => r.sent)
  .map(r => ({ [r.claimNumber]: r.claimUuid }));

// 2. Qaror yuborish (Excel'ga claim UUIDlarni to'ldiring)
const decision = await api('/api/app/fond/decision/import', {
  method: 'POST',
  body: JSON.stringify({ rows: decisionRows })
});

// 3. To'lov faqat decisionId=1 bo'lganlar uchun
const payoutRows = decisionRows.filter(r => r["decision.decisionId"] === 1);
const payout = await api('/api/app/fond/payout/import', {
  method: 'POST',
  body: JSON.stringify({ rows: payoutRows })
});
```

---

## 9. Boshqa modullar

### 9.1. User

`GET /api/user/list` — foydalanuvchilar ro'yxati
`POST /api/user/saveRoles` — rollarni saqlash

### 9.2. Document

`POST /api/document/generate-document` — hujjat generatsiyasi (Word template'dan)

### 9.3. Ekey (E-imzo)

- `POST /api/ekey/signature/CBRUGetCmsUserIdList` — CBRU orqali user ID
- `POST /api/ekey/signature/verifyCms` — CMS tekshirish
- `POST /api/ekey/signature/GetCmsContent` — CMS'dan kontent

### 9.4. PI (Payment Insurance)

Barcha CRUD `POST /api/app/request` orqali `method` bilan chaqiriladi.

### 9.5. Telegram / LNM / AL / Webhook

Alohida controller'lar. Detallar backend'da (`pi/controllers/`, `lnm/controllers/`, `telegram/controllers/`, `webhook/controllers/`).

---

## 10. Xatolar

### 10.1. HTTP status kodlari

| Kod | Ma'no |
|---|---|
| `200 OK` | Muvaffaqiyat (yoki business error — `success: false` maydonini tekshiring) |
| `400 Bad Request` | Payload xato (masalan, `data` bo'sh) |
| `403 Forbidden` | JWT eskirgan yoki noto'g'ri |
| `500 Internal Server Error` | Server tomonda xato |
| `503 Service Unavailable` | DB ishlamayapti (`health` endpointidan) |

### 10.2. Business error konvensiyasi

Response 200 kelsa ham `success: false` bo'lishi mumkin:

```json
{ "success": false, "message": "Method is not active." }
```

Frontend'da doim `success` maydonini birinchi tekshiring.

### 10.3. JWT muddati o'tgan

```json
{ "success": false, "message": "JWT token has been expired" }
```

Frontend'da:
1. Tokenni `localStorage` dan o'chirib tashlang
2. Login sahifasiga yo'naltiring
3. Yoki refresh token orqali yangilang (agar bor bo'lsa)

### 10.4. Yaxshi patternlar

**Global interceptor** — barcha so'rovlarda xatoni bir joyda ushlab qolish:

```js
async function api(path, options = {}) {
  const resp = await fetch(BASE_URL + path, {
    ...options,
    headers: {
      'Authorization': `Bearer ${getJwt()}`,
      'lang': getLang(),
      ...(options.headers || {})
    }
  });

  if (resp.status === 403) {
    logout();
    throw new Error('Session expired');
  }

  const json = await resp.json();
  if (!json.success && json.message?.includes('JWT')) {
    logout();
    throw new Error('Session expired');
  }
  if (!json.success) {
    throw new Error(json.message || json.error?.message || 'Unknown error');
  }
  return json;
}
```

---

## Qo'shimcha

- **Backend repositoriya:** https://github.com/ArslonbekKulmatov/Monello_Backend
- **Yangi endpointlar** — `com.example.asaka.<module>.controllers.C*` — barcha `@RequestMapping` annotatsiyalari orqali ochilgan
- **PL/SQL protseduralari** — `CORE_METHODS` jadvalidan `method` nomi orqali topiladi

Savollar bo'lsa: Arslonbek Kulmatov.
