# Qo'mita a'zolari — "Hozirgi holat" moduli (frontchi uchun)

Ushbu hujjat qo'mita a'zolarining **hozirgi ishtirok holati** (absence reason) tushunchasi bilan bog'liq **barcha backend o'zgarishlar** va **API'lar**ni jamlaydi.

**Backend branch**: `claude/relaxed-hopper-didxog`
**SQL migration**: `src/main/resources/db/committee_member_absence.sql`

---

## Mundarija

1. [Muammo va yechim](#1-muammo-va-yechim)
2. [Umumiy qoidalar](#2-umumiy-qoidalar)
3. [API-lar ro'yxati](#3-api-lar-royxati)
4. [Spravochnik: holatlar ro'yxati](#4-spravochnik-holatlar-royxati)
5. [A'zolar ro'yxati (getMembersList)](#5-azolar-royxati-getmemberslist)
6. [A'zo add/edit/delete (member_ref_action)](#6-azo-addeditdelete-member_ref_action)
7. [Faqat holatni o'zgartirish (setMemberReason)](#7-faqat-holatni-ozgartirish-setmemberreason)
8. [Ovoz berish varaqasi (getVotes)](#8-ovoz-berish-varaqasi-getvotes)
9. [UI dizayn tavsiyalari](#9-ui-dizayn-tavsiyalari)
10. [Xatolar](#10-xatolar)

---

## 1. Muammo va yechim

**Muammo:**
- Rais xizmat safariga ketsa, uni **"Неактивный"** qilsa — u ro'yxatdan tushib qoladi
- **"Активный"** qoldirsa — u kutilyapti ("Кутилмоқда") va 2 ta rais bo'lib qoladi

**Yechim:**
- **"Активный/Неактивный"** — a'zolik amal qilishi (added_on ... expired_on)
- **"Ҳозирги ҳолати"** — yangi maydon, spravochnikdan tanlanadi:

| Kod | Nomi | Rang | Ma'no |
|---|---|:---:|---|
| `PARTICIPATES` | Иштирок этади | 🟢 success | Ovoz beradi (default) |
| `BUSINESS_TRIP` | Хизмат сафарида | 🔵 info | Ovoz bermaydi |
| `VACATION` | Таътилда | 🟡 warning | Ovoz bermaydi |
| `SICK_LEAVE` | Касаллик варақасида | 🔴 danger | Ovoz bermaydi |
| `OTHER` | Бошқа | ⚫ muted | Ovoz bermaydi |

**Effektlar:**
- Rais **safarda bo'lsa** — a'zolar ro'yxatida qoladi, lekin ovoz varaqasida **"Хизмат сафарида"** rangli badge ko'rinadi
- **Kvorum hisobida** faqat `PARTICIPATES` a'zolar hisobga olinadi
- `reason_to` o'tsa **avtomatik** `PARTICIPATES` ga qaytadi (view mantiq)

---

## 2. Umumiy qoidalar

### Base URL
```
http://185.74.7.37:81
```

### Auth
Har request'da:
```
Authorization: Bearer <JWT>
Content-Type: application/json
lang: ru
```

### Umumiy response formati
Universal RPC (`/api/app/request`) natijasi:
```json
{
  "success": true,
  "oper": true,
  "message": "...",
  "data": { ... }
}
```

---

## 3. API-lar ro'yxati

| Ish | Endpoint | Method / method |
|---|---|---|
| Spravochnik (holatlar) | `/api/app/execSelect` | view: `pi_s_committee_absence_reasons_v` |
| A'zolar ro'yxati | `/api/app/request` | `getMembersList` |
| A'zo add/edit/delete + holat | `/api/app/request` | `member_ref_action` |
| Faqat holat o'zgartirish (ixt.) | `/api/app/request` | `setMemberReason` |
| Ovoz berish varaqasi | `/api/app/request` | `getVotes` |
| Ovoz berish | `/api/app/request` | `member_action` (avvaldan bor) |

---

## 4. Spravochnik: holatlar ro'yxati

Dropdown va rangli badge'lar uchun kerak. **`/execSelect`** orqali view'dan olinadi:

**Request:**
```http
POST /api/app/execSelect
Content-Type: application/json
Authorization: Bearer <JWT>

{ "view": "pi_s_committee_absence_reasons_v" }
```

**Response:**
```json
{
  "success": true,
  "rows": [
    { "code": "PARTICIPATES",  "name_uz": "Иштирок этади",       "name_ru": "Участвует",         "color": "success", "order_by": 1, "is_active": "Y", "is_default": "Y" },
    { "code": "BUSINESS_TRIP", "name_uz": "Хизмат сафарида",     "name_ru": "В командировке",    "color": "info",    "order_by": 2, "is_active": "Y", "is_default": "N" },
    { "code": "VACATION",      "name_uz": "Таътилда",            "name_ru": "В отпуске",         "color": "warning", "order_by": 3, "is_active": "Y", "is_default": "N" },
    { "code": "SICK_LEAVE",    "name_uz": "Касаллик варақасида", "name_ru": "На больничном",     "color": "danger",  "order_by": 4, "is_active": "Y", "is_default": "N" },
    { "code": "OTHER",         "name_uz": "Бошқа",               "name_ru": "Другое",            "color": "muted",   "order_by": 5, "is_active": "Y", "is_default": "N" }
  ]
}
```

**JavaScript:**
```js
const resp = await fetch(`${BASE_URL}/api/app/execSelect`, {
  method: 'POST',
  headers: { 'Authorization': `Bearer ${jwt}`, 'Content-Type': 'application/json' },
  body: JSON.stringify({ view: 'pi_s_committee_absence_reasons_v' })
});
const { rows: reasons } = await resp.json();

// UI'da rangli badge uchun color → CSS mapping
const COLOR_MAP = {
  success: '#16a34a',  // Иштирок этади
  info:    '#2563eb',  // Хизмат сафарида
  warning: '#d97706',  // Таътилда
  danger:  '#dc2626',  // Касаллик
  muted:   '#64748b'   // Бошқа
};
```

Odatda **app boot vaqtida bir marta** yuklaymiz va cache'da saqlaymiz.

---

## 5. A'zolar ro'yxati (getMembersList)

**Request:**
```json
POST /api/app/request

{
  "method": "getMembersList",
  "params": { "only_active": 0 }
}
```
- `only_active: 0` — hammasi (default)
- `only_active: 1` — faqat Активный

**Response:**
```json
{
  "success": true,
  "members": [
    {
      "user_id": 101,
      "name": "А.А.Халилов",
      "position": "Суғурта Қўмитаси Раиси",
      "order_by": 1,
      "added_on": "01.11.2025",
      "expired_on": "12.09.2036",
      "is_active": "A",                    // A | P
      "votes_count": 3429,                 // umumiy ovoz soni
      "reason": "PARTICIPATES",            // effektiv reason (reason_to o'tsa PARTICIPATES)
      "reason_name": "Иштирок этади",
      "reason_color": "success",
      "reason_from": null,
      "reason_to":   null,
      "reason_note": null
    },
    {
      "user_id": 107,
      "name": "Х.Ж.Холбутаев",
      "position": "Суғурта Қўмитаси аъзоси",
      "order_by": 7,
      "added_on": "01.04.2026",
      "expired_on": "06.04.2036",
      "is_active": "A",
      "votes_count": 3471,
      "reason": "BUSINESS_TRIP",
      "reason_name": "Хизмат сафарида",
      "reason_color": "info",
      "reason_from": "15.09.2026",
      "reason_to":   "25.09.2026",
      "reason_note": "Toshkent, buyruq #384"
    }
  ]
}
```

**Muhim maydonlar:**
- `is_active`: `A` = Активный, `P` = Неактивный (sana o'tgan)
- `reason`: **effektiv** reason (agar `reason_to < bugun` bo'lsa avtomatik `PARTICIPATES` qaytadi)
- `reason_color`: darhol CSS/badge klass uchun (success/info/warning/danger/muted)
- `votes_count`: `pi_committee_member_votes` bo'yicha umumiy ovoz soni

---

## 6. A'zo add/edit/delete (member_ref_action)

**Bu — asosiy ish endpointi.** Add / Edit / Delete + hozirgi holat **bitta chaqiruv** bilan.

### 6.1. Qo'shish (Insert)

```json
POST /api/app/request

{
  "method": "member_ref_action",
  "params": {
    "action": "I",
    "user_id": 245,
    "name": "К.Қобилов",
    "position": "Суғурта Қўмитаси аъзоси",
    "order_by": 6,
    "added_on":   "01.04.2026",
    "expired_on": "06.04.2036",
    "reason": "PARTICIPATES"
  }
}
```

`reason` yuborilmasa — default `PARTICIPATES`.

### 6.2. O'zgartirish (Update) + holat

```json
{
  "method": "member_ref_action",
  "params": {
    "action": "U",
    "user_id": 107,
    "position": "Суғурта Қўмитаси аъзоси",
    "added_on":   "01.04.2026",
    "expired_on": "06.04.2036",
    "reason":      "BUSINESS_TRIP",
    "reason_from": "15.09.2026",
    "reason_to":   "25.09.2026",
    "reason_note": "Toshkent, buyruq #384"
  }
}
```

**Qoidalar:**
- `reason` yuborilmasa — hozirgi holat tegilmadi
- `reason = PARTICIPATES` — `reason_from`, `reason_to`, `reason_note` avtomatik tozalanadi
- Boshqa reason — `reason_from` majburiy emas (lekin tavsiya)

### 6.3. O'chirish (Delete)

```json
{
  "method": "member_ref_action",
  "params": { "action": "D", "user_id": 107 }
}
```

### 6.4. Response

```json
{
  "success": true,
  "oper": true,
  "data": {
    "message": "Данные успешно обновлены!"
  }
}
```

Xato:
```json
{
  "success": false,
  "message": "Этот пользователь уже является членом комитета!"
}
```

### 6.5. Frontend namuna (Save tugmasi)

```js
async function saveMember(row) {
  const payload = {
    method: 'member_ref_action',
    params: {
      action: row.user_id ? 'U' : 'I',
      user_id: row.user_id || newUserId,
      name: row.name,                       // I uchun majburiy
      position: row.position,
      added_on: row.added_on,               // dd.mm.yyyy
      expired_on: row.expired_on,
      reason: row.reason,
      reason_from: row.reason_from || null,
      reason_to:   row.reason_to   || null,
      reason_note: row.reason_note || null
    }
  };
  const r = await apiRequest(payload);
  if (!r.success) throw new Error(r.message);
  return r;
}
```

---

## 7. Faqat holatni o'zgartirish (setMemberReason)

**Ixtiyoriy** endpoint — a'zoning o'zi (admin bo'lmasa) faqat o'z holatini o'zgartirish uchun. Masalan "Bugun safarga ketяпman" degan tugma.

```json
POST /api/app/request

{
  "method": "setMemberReason",
  "params": {
    "user_id": 107,
    "reason": "BUSINESS_TRIP",
    "from": "17.09.2026",
    "to":   "25.09.2026",
    "note": "Toshkentga xizmat safari"
  }
}
```

**Qoidalar:**
- Admin (`role_id = 6`) — istalgan a'zoning holatini o'zgartira oladi
- Boshqalar — faqat o'z `user_id`si uchun

**Response:**
```json
{
  "success": true,
  "message": "Holat yangilandi: Хизмат сафарида",
  "reason": "BUSINESS_TRIP"
}
```

**Eslatma:** Agar admin panelida ishlasangiz — `setMemberReason` shart emas, `member_ref_action`da hammasi bor.

---

## 8. Ovoz berish varaqasi (getVotes)

**Request:**
```json
POST /api/app/request

{ "method": "getVotes", "params": { "id": 48281 } }
```
`id` — hodisa (Committee) ID.

**Response:**
```json
{
  "success": true,
  "votes": [
    {
      "committee_id": 48281,
      "user_id": 101,
      "user_name": "А.А.Халилов",
      "role": "Суғурта Қўмитаси Раиси",
      "vote": "Кутилмоқда",
      "vote_on": null,
      "comments": null,
      "reason": "PARTICIPATES",
      "reason_name": "Иштирок этади",
      "reason_color": "success",
      "is_voter": "Y"
    },
    {
      "committee_id": 48281,
      "user_id": 107,
      "user_name": "Х.Ж.Холбутаев",
      "role": "Суғурта Қўмитаси аъзоси",
      "vote": "Хизмат сафарида",
      "vote_on": null,
      "comments": "Toshkent, buyruq #384",
      "reason": "BUSINESS_TRIP",
      "reason_name": "Хизмат сафарида",
      "reason_color": "info",
      "is_voter": "N"
    }
  ]
}
```

**Muhim:**
- **`is_voter = "Y"`** — ovoz kutiladi. `vote` maydonida: `Кутилмоқда` / `Рози` / `Норози`
- **`is_voter = "N"`** — ovoz kutilmaydi. `vote` maydonida — sabab nomi (`Хизмат сафарида`)
- **`reason_color`** — rangli badge uchun
- **Kvorum** hisobida faqat `is_voter = "Y"` a'zolar

**Frontend kvorum hisobi:**
```js
const votes = response.votes;
const voters = votes.filter(v => v.is_voter === 'Y');
const voted  = voters.filter(v => v.vote !== 'Кутилмоқда').length;
const waiting = voters.length - voted;
const absent  = votes.length - voters.length;
```

### Ovoz berish (member_action)

Sizda avvaldan bor:
```json
{
  "method": "member_action",
  "params": {
    "action": "agree",       // agree | disagree | return
    "ids": [48281],           // committee id lar
    "comment": ""
  }
}
```
Response: `{ "success": true, "message": "Ваш голос принят!" }`

---

## 9. UI dizayn tavsiyalari

### A'zolar jadvali (Члены комитета)

**Yangi ustun**: **"Ҳозирги ҳолати"** — Статус va o'ng burchakdagi tugmalar orasida.

Har qatorda:
- Rangli **badge** — reason_color asosida
- Badge tagida (agar mavjud bo'lsa) — sana intervali `15.09.2026 — 25.09.2026`

**Edit modal**da yangi bo'lim:
1. **Ҳозирги ҳолати** dropdown (rangli nuqta bilan)
2. `PARTICIPATES` **emas** bo'lsa: `қачондан`, `қачонгача`, `Изоҳ`

### Ovoz berish varaqasi (Голосование)

**Yuqori burchakda kvorum:**
```
Овоз берувчилар: 5 · Ovoz berdi: 3 · Kutilmoqda: 2 · Yo'q: 2
```

Har qatorda:
- `is_voter = Y` va `vote = Кутилмоқда` → yashil "Рози" / qizil "Норози" tugmalar
- `is_voter = Y` va vote bor → rangli badge
- `is_voter = N` → sabab rangli badge (masalan 🔵 "Хизмат сафарида")

### Rangli badge CSS klasslar

Backend'dan kelayotgan `color` maydonini CSS klass'iga aylantiring:

```js
const COLOR_TO_CLASS = {
  success: 'badge-success',   // yashil
  info:    'badge-info',      // ko'k
  warning: 'badge-warning',   // sariq
  danger:  'badge-danger',    // qizil
  muted:   'badge-muted'      // kulrang
};
```

---

## 10. Xatolar

### Umumiy xatolar

| Xato matni | Sabab |
|---|---|
| `У вас нет доступа к этим действиям!` | Admin roli yo'q |
| `Этот пользователь уже является членом комитета!` | Insertда user_id takrorlangan |
| `Член комитета не найден: user_id = ...` | Update/Delete uchun a'zo yo'q |
| `Noto'g'ri holat kodi: ...` | reason spravochnikda yo'q |
| `"reason_from" formati noto'g'ri. Kerak: dd.mm.yyyy` | Sana formati |
| `"reason_from" "reason_to"dan katta bo'lishi mumkin emas` | Sana tekshiruvi |
| `Этот порядковый номер уже занят: order_by = ...` | order_by dublikat |

### JavaScript'da global interceptor

```js
async function apiRequest(payload) {
  const resp = await fetch(`${BASE_URL}/api/app/request`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${getJwt()}`,
      'Content-Type': 'application/json',
      'lang': 'ru'
    },
    body: JSON.stringify(payload)
  });

  if (resp.status === 403) {
    logout();
    throw new Error('Sessiya tugadi');
  }

  const json = await resp.json();
  if (!json.success && json.message?.includes('JWT')) {
    logout();
    throw new Error('Sessiya tugadi');
  }
  if (!json.success) {
    throw new Error(json.message || 'Xato');
  }
  return json;
}
```

---

## Xulosa — 4 asosiy chaqiruv

Frontchi shu 4 tasini bilsa yetadi:

1. **App boot** — spravochnikni yuklab olish (bir marta):
   ```
   POST /api/app/execSelect  { "view": "pi_s_committee_absence_reasons_v" }
   ```

2. **Jadval yuklash**:
   ```
   POST /api/app/request  { "method": "getMembersList", "params": {} }
   ```

3. **A'zo qo'shish/o'zgartirish/o'chirish (holat bilan)**:
   ```
   POST /api/app/request  { "method": "member_ref_action",
                            "params": { "action": "I|U|D", ... } }
   ```

4. **Ovoz varaqasi**:
   ```
   POST /api/app/request  { "method": "getVotes", "params": {"id": <hodisa_id>} }
   ```

Yakuniy prototip: `scratchpad/committee-panel-all-in-one.html`.
