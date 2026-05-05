# Al-Mohaffez Web — Deployment & Usage Guide

> **Hosting:** Hostinger (shared or VPS)  
> **Domains:** `app.mohafezy.com` → web app · `mohafezy.com` → marketing site  
> **Stack:** Flutter Web + Firebase backend (Firestore, Auth, Functions)

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Build the Web App](#2-build-the-web-app)
3. [Hostinger Setup](#3-hostinger-setup)
4. [Deploy the Web App (app.mohafezy.com)](#4-deploy-the-web-app)
5. [Deploy the Marketing Site (mohafezy.com)](#5-deploy-the-marketing-site)
6. [Firebase Configuration](#6-firebase-configuration)
7. [Using the App — Admin](#7-using-the-app--admin)
8. [Using the App — Teacher (محفظ)](#8-using-the-app--teacher-محفظ)
9. [Using the App — Student (طالب)](#9-using-the-app--student-طالب)
10. [Updating the App](#10-updating-the-app)
11. [Troubleshooting](#11-troubleshooting)

---

## 1. Prerequisites

Install these once on your development machine:

| Tool | Version | Install |
|---|---|---|
| Flutter | 3.24+ (stable) | https://flutter.dev/docs/get-started/install |
| Dart | included with Flutter | — |
| Git | any | https://git-scm.com |
| FTP client | any | FileZilla (free) recommended |

Verify Flutter is ready:
```bash
flutter doctor
# Must show: [✓] Chrome, [✓] Flutter, no errors
```

---

## 2. Build the Web App

Run from the **repo root** on your Windows machine:

```bash
# Step 1 — get dependencies
cd packages/mohaffez_web
flutter pub get

# Step 2 — build release
flutter build web --release --web-renderer canvaskit

# Output folder:
#   packages/mohaffez_web/build/web/
```

The `build/web/` folder contains everything that gets uploaded to Hostinger. It is a static site — no server-side code.

> **Note on SENTRY_DSN:** If you have a Sentry account for error tracking, add it to the build command:
> ```bash
> flutter build web --release --web-renderer canvaskit --dart-define=SENTRY_DSN=https://your-key@sentry.io/123
> ```
> If you skip it, error tracking is simply disabled — the app works normally.

---

## 3. Hostinger Setup

### 3.1 Create subdomains

In **Hostinger → Domains → Subdomains**, create:

| Subdomain | Points to |
|---|---|
| `app.mohafezy.com` | `/public_html/app` (new folder) |
| `www.mohafezy.com` | `/public_html` |

### 3.2 Enable HTTPS

In **Hostinger → SSL → Let's Encrypt**, install a free SSL certificate for:
- `mohafezy.com`
- `www.mohafezy.com`
- `app.mohafezy.com`

This is required — Firebase Phone OTP (SMS login) only works on HTTPS.

### 3.3 Create the `.htaccess` file for SPA routing

Flutter Web uses client-side routing. Without this file, refreshing any page (e.g. `/s/sessions`) returns a 404.

In **Hostinger File Manager**, navigate to `/public_html/app/` and create a file named `.htaccess` with this content:

```apache
Options -MultiViews
RewriteEngine On
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule ^ index.html [QSA,L]
```

This redirects all unknown paths to `index.html` so Flutter's router handles them.

---

## 4. Deploy the Web App

### 4.1 Via FileZilla (FTP)

1. Open FileZilla → **File → Site Manager → New Site**
2. Enter your Hostinger FTP credentials (found in **Hostinger → Hosting → FTP Accounts**)
3. Connect
4. On the **right panel** (remote), navigate to `/public_html/app/`
5. On the **left panel** (local), navigate to `packages/mohaffez_web/build/web/`
6. Select **all files** in the local panel → drag to remote panel
7. Wait for upload to complete (typically 2–5 minutes on first deploy)

### 4.2 Via Hostinger File Manager (alternative)

1. In Hostinger, go to **File Manager → public_html → app**
2. Click **Upload → Upload Folder**
3. Select the entire `packages/mohaffez_web/build/web/` folder
4. Alternatively: zip the `web/` folder locally, upload the zip, then extract it in File Manager

### 4.3 Verify deployment

Open `https://app.mohafezy.com` in Chrome. You should see the teal login screen asking for a phone number.

---

## 5. Deploy the Marketing Site

1. In FileZilla, navigate to `/public_html/` (root, not the `app/` subfolder)
2. Upload all files from `marketing_site/` in the repo
3. Verify at `https://mohafezy.com`

The marketing site is plain HTML — no build step needed.

---

## 6. Firebase Configuration

These steps are done **once** in the Firebase Console at https://console.firebase.google.com

### 6.1 Add authorized domain (critical — SMS OTP won't work without this)

1. Firebase Console → **Authentication → Settings → Authorized domains**
2. Click **Add domain**
3. Add: `app.mohafezy.com`
4. Also add: `mohafezy.com`

### 6.2 Verify Firebase project details

The app is already wired to project **`mohaffez-ba2ec`**. No changes needed in code unless you switch projects.

### 6.3 Firebase Functions (backend)

The Cloud Functions are already deployed separately. To redeploy them if needed:
```bash
# from repo root
firebase deploy --only functions
```

---

## 7. Using the App — Admin

**Login:** Use an account with role `admin` in Firestore (`users/{uid}/role = "admin"`).

Navigate to `https://app.mohafezy.com` → enter your phone number → enter the SMS code.

### Admin pages

| Page | Path | Purpose |
|---|---|---|
| لوحة الإدارة | `/admin` | Overview: total users, pending verifications, promo codes, system status |
| المستخدمون | `/admin/users` | View all users (students + teachers). Filter by role. |
| طلبات التحقق | `/admin/approvals` | Review teacher credential documents. Approve or reject. |
| الجلسات | `/admin/sessions` | Platform-wide session stats (detailed reports coming in next update) |
| المدفوعات | `/admin/payments` | Monitor failed payment operations and system payment health |
| أكواد الخصم | `/admin/promos` | View all promo codes, their usage counts, active/inactive status |
| إعدادات النظام | `/admin/config` | Toggle maintenance mode, view app version settings, commission rates, session types |
| التقارير | `/admin/reports` | User distribution charts, pending verifications count, total user stats |

### Key admin tasks

**Approve a new teacher:**
1. Go to **طلبات التحقق** (`/admin/approvals`)
2. Find the teacher's card → click **قبول** to approve or **رفض** to reject
3. The teacher's status updates in Firestore immediately

**Toggle maintenance mode:**
1. Go to **إعدادات النظام** (`/admin/config`)
2. Toggle the **تفعيل وضع الصيانة** switch
3. *(Note: the switch UI is currently read-only display — write support is in the next update)*

**Create a promo code:**
1. Go to **أكواد الخصم** (`/admin/promos`)
2. Click **إضافة كود** *(write flow coming in next update)*

---

## 8. Using the App — Teacher (محفظ)

**Login:** Phone number of a Firestore user with `role = "mohaffez"`.

### Teacher pages

| Page | Path | Purpose |
|---|---|---|
| الرئيسية | `/t` | Dashboard: upcoming sessions, pending requests, student count, completed sessions |
| طلابي | `/t/students` | All students taught. Shows session count, hifz assignment, last session date, rating. |
| الجدول | `/t/schedule` | Schedule view (calendar coming in next update) |
| الجلسات | `/t/sessions` | Switch between upcoming sessions and pending requests. Accept/reject requests. |
| التسعير | `/t/pricing` | Manage pricing plans. View plans, delete plans. |
| الشهادات | `/t/certificates` | Students who completed hifz assignments. Print certificate button. |
| الأرباح | `/t/earnings` | Completed session count, earnings summary (detailed breakdown in next update) |
| ملفي الشخصي | `/t/profile` | Edit name and bio. View rating, review count, follower count. |

### Key teacher tasks

**Accept a session request:**
1. Go to **الجلسات** (`/t/sessions`)
2. Click **الطلبات المعلقة** tab
3. Click **قبول** next to the student's request

**Update profile:**
1. Go to **ملفي الشخصي** (`/t/profile`)
2. Edit name or bio → click **حفظ التغييرات**

---

## 9. Using the App — Student (طالب)

**Login:** Phone number of a Firestore user with `role = "student"`.

### Student pages

| Page | Path | Purpose |
|---|---|---|
| الرئيسية | `/s` | Dashboard: active subscription, upcoming sessions, pending requests summary |
| البحث عن محفظ | `/s/teachers` | Browse nearby teachers with ratings and specializations |
| جلساتي | `/s/sessions` | View all sessions: upcoming and history |
| مهامي | `/s/assignments` | View memorized surahs assigned by teacher |
| اشتراكاتي | `/s/subscriptions` | View subscription plans: sessions used/remaining, expiry, teacher name |
| مكافآتي | `/s/rewards` | View memorized surahs count and completed sessions total |
| ملفي الشخصي | `/s/profile` | Edit name. View phone number (read-only). |

### Key student tasks

**Find and book a teacher:**
1. Go to **البحث عن محفظ** (`/s/teachers`)
2. Browse teachers — see rating, specialization
3. Click **حجز جلسة** *(booking flow opens via the mobile app; web booking in next update)*

**Check subscription status:**
1. Go to **اشتراكاتي** (`/s/subscriptions`)
2. See remaining sessions, expiry date, teacher name

---

## 10. Updating the App

Every time you push a code change:

```bash
# 1. Pull latest code
git pull

# 2. Get updated dependencies
cd packages/mohaffez_web
flutter pub get

# 3. Rebuild
flutter build web --release --web-renderer canvaskit

# 4. Re-upload build/web/ to Hostinger /public_html/app/
#    (overwrite all files — FTP "overwrite if newer")
```

> **Important:** After uploading, do a hard refresh in Chrome (`Ctrl+Shift+R`) to clear the Flutter service worker cache. Users may need to do the same if they see an old version.

---

## 11. Troubleshooting

### Page shows 404 on refresh
**Cause:** Missing `.htaccess` file.  
**Fix:** Re-add the `.htaccess` file from [Section 3.3](#33-create-the-htaccess-file-for-spa-routing).

### SMS OTP doesn't arrive / reCAPTCHA error
**Cause:** Domain not authorized in Firebase Auth.  
**Fix:** Firebase Console → Authentication → Authorized domains → add `app.mohafezy.com`.

### App shows blank white screen
**Cause:** Usually a JavaScript error on load.  
**Fix:** Open Chrome DevTools (`F12`) → Console tab → check the error message. Most common causes:
- Firestore rules blocking reads
- `firebase_options.dart` has wrong project config (should not happen — already set to `mohaffez-ba2ec`)

### App loads but data doesn't appear
**Cause:** Firestore security rules blocking web origin.  
**Fix:** Check `firestore.rules` — ensure rules don't restrict by `request.auth.token.firebase.sign_in_provider` in a way that blocks web OTP logins.

### "Maintenance mode" screen appears for all users
**Cause:** `maintenanceMode: true` in Firestore `systemConfig` document.  
**Fix:** Firebase Console → Firestore → `systemConfig` → set `maintenanceMode` to `false`.

### FTP upload is very slow
**Tip:** Zip the entire `build/web/` folder locally, upload the single zip file via Hostinger File Manager, then use File Manager's built-in **Extract** feature. Much faster than FTP for many small files.

---

## Quick Reference

```
Repo root:          e:\Imam\Mohaffez_app\
Web app source:     packages/mohaffez_web/
Web build output:   packages/mohaffez_web/build/web/
Marketing site:     marketing_site/

Firebase project:   mohaffez-ba2ec
Web app URL:        https://app.mohafezy.com
Marketing URL:      https://mohafezy.com

Hostinger paths:
  Web app   →  /public_html/app/
  Marketing →  /public_html/
```
