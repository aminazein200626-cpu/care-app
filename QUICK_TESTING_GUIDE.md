# CareApp - Quick Testing Guide 🚀

## الاختبار السريع للـ APIs

### 1️⃣ تشغيل الخادم

```bash
cd careapp-backend
npm install  # مرة واحدة فقط
npm run dev
```

✅ يجب أن ترى: `Server running on port 5001`

---

### 2️⃣ اختبار التسجيل (Postman أو cURL)

#### تسجيل عميل جديد
```bash
curl -X POST http://localhost:5001/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "fullName": "محمد علي",
    "email": "client@test.com",
    "password": "password123",
    "phoneNumber": "0123456789",
    "wilaya": "الجزائر"
  }'
```

**النتيجة المتوقعة:**
```json
{
  "success": true,
  "message": "تم التسجيل بنجاح",
  "token": "eyJhbGciOiJIUzI1...",
  "user": {
    "userId": "64a123...",
    "clientId": "64b456...",
    "fullName": "محمد علي"
  }
}
```

💾 **احفظ Token** - ستحتاجها للطلبات التالية

---

### 3️⃣ اختبار البحث

#### البحث عن مزودين
```bash
curl -X GET "http://localhost:5001/api/search/providers?wilaya=الجزائر&rating=4" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

#### البحث عن خدمات
```bash
curl -X GET "http://localhost:5001/api/search/services" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

---

### 4️⃣ اختبار إنشاء حجز

أولاً، احصل على معرّف مزود من نتائج البحث، ثم:

```bash
curl -X POST http://localhost:5001/api/bookings \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "providerId": "PROVIDER_ID_HERE",
    "serviceId": "SERVICE_ID_HERE",
    "date": "2024-02-20",
    "startTime": "10:00",
    "endTime": "12:00",
    "location": "الجزائر",
    "clientTasks": [
      {
        "taskName": "تنظيف المنزل",
        "status": "pending"
      }
    ]
  }'
```

---

### 5️⃣ اختبار الإشعارات

```bash
curl -X GET "http://localhost:5001/api/notifications?unread=true" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

---

## 🧪 سيناريو اختبار كامل (خطوة بخطوة)

### المرحلة 1: التحضير

```bash
# 1. تشغيل MongoDB
mongod

# 2. تشغيل الخادم
cd careapp-backend
npm run dev

# 3. فتح Postman أو Terminal جديد
```

### المرحلة 2: تسجيل عميل

```
POST /api/auth/register
Body:
{
  "fullName": "علي الجزائري",
  "email": "ali@test.com",
  "password": "test1234",
  "phoneNumber": "0670123456",
  "wilaya": "الجزائر"
}
```

💾 احفظ `token` و `userId`

### المرحلة 3: تسجيل مزود

```
POST /api/auth/register-provider  (من خلال الـ provider routes)
Body:
{
  "fullName": "تمريض احترافي",
  "email": "nurse@test.com",
  "password": "test1234",
  "phoneNumber": "0671234567",
  "wilaya": "الجزائر",
  "address": "الجزائر - القصبة",
  "hourlyRate": 1500,
  "yearsOfExperience": 5
}
```

💾 احفظ `token` و `providerId`

### المرحلة 4: إضافة توفرية للمزود

```
PUT /api/provider/availability (استخدم token المزود)
Body:
{
  "dateSlots": {
    "2024-02-20": [
      {
        "startTime": "10:00",
        "endTime": "12:00",
        "isBooked": false
      },
      {
        "startTime": "14:00",
        "endTime": "16:00",
        "isBooked": false
      }
    ]
  }
}
```

### المرحلة 5: البحث عن المزود (من العميل)

```
GET /api/search/providers?wilaya=الجزائر (استخدم token العميل)
```

✅ يجب أن تجد المزود في النتائج

### المرحلة 6: إنشاء حجز

```
POST /api/bookings (استخدم token العميل)
Body:
{
  "providerId": "PROVIDER_ID",
  "serviceId": "SERVICE_ID",
  "date": "2024-02-20",
  "startTime": "10:00",
  "endTime": "12:00",
  "location": "الجزائر",
  "clientTasks": [
    {
      "taskName": "تنظيف",
      "status": "pending"
    }
  ]
}
```

### المرحلة 7: عرض الحجوزات (للمزود)

```
GET /api/bookings?role=provider (استخدم token المزود)
```

✅ يجب أن ترى الحجز الجديد

### المرحلة 8: قبول الحجز (من المزود)

```
PUT /api/bookings/BOOKING_ID/respond (استخدم token المزود)
Body:
{
  "action": "accept"
}
```

### المرحلة 9: التحقق من الإشعارات (للعميل)

```
GET /api/notifications (استخدم token العميل)
```

✅ يجب أن ترى إشعار "تم قبول طلبك"

### المرحلة 10: تقييم الخدمة

```
POST /api/bookings/BOOKING_ID/rate (استخدم token العميل)
Body:
{
  "rating": 4.5,
  "feedback": "خدمة ممتازة جداً"
}
```

---

## ✅ قائمة التحقق

- [ ] الخادم يعمل بدون أخطاء
- [ ] التسجيل يعمل للعميل والمزود
- [ ] البحث يعيد نتائج صحيحة
- [ ] إنشاء الحجز يحفظ البيانات
- [ ] الإشعارات تصل في الوقت المناسب
- [ ] التقييم يحدّث متوسط التقييم
- [ ] Token يعمل للطلبات المحمية

---

## 🐛 استكشاف المشاكل

### المشكلة: "Connection refused"
```
✗ MongoDB غير مشغل
✓ الحل: اكتب `mongod` في terminal منفصل
```

### المشكلة: "Invalid token"
```
✗ Token انتهت صلاحيتها أو غير صحيح
✓ الحل: سجل دخول جديد واحصل على token جديد
```

### المشكلة: "Slot already booked"
```
✗ الموعد محجوز بالفعل
✓ الحل: اختر موعد مختلف
```

### المشكلة: "Provider not found"
```
✗ المزود غير موجود أو لم يسجل
✓ الحل: سجل مزود جديد أولاً
```

---

## 🔍 مثال كامل مع cURL

```bash
#!/bin/bash

BASE_URL="http://localhost:5001/api"

# 1. تسجيل عميل
echo "📝 تسجيل عميل جديد..."
CLIENT_RESPONSE=$(curl -s -X POST $BASE_URL/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "fullName": "عميل الاختبار",
    "email": "test'$(date +%s)'@test.com",
    "password": "test1234",
    "phoneNumber": "0670000000",
    "wilaya": "الجزائر"
  }')

CLIENT_TOKEN=$(echo $CLIENT_RESPONSE | jq -r '.token')
echo "✅ Token: $CLIENT_TOKEN"

# 2. البحث عن مزودين
echo "🔍 البحث عن مزودين..."
curl -s -X GET "$BASE_URL/search/providers?wilaya=الجزائر" \
  -H "Authorization: Bearer $CLIENT_TOKEN" | jq .

# 3. الحصول على الإشعارات
echo "🔔 الإشعارات..."
curl -s -X GET "$BASE_URL/notifications" \
  -H "Authorization: Bearer $CLIENT_TOKEN" | jq .
```

---

## 📱 اختبار Flutter

### 1. تشغيل التطبيق
```bash
cd careapp_mobile
flutter pub get
flutter run
```

### 2. اختبار البحث
- افتح تطبيق Flutter
- اذهب إلى البحث
- ستجد المزودين الذين أضفتهم عبر API

### 3. اختبار الحجز
- اختر مزود
- أنشئ حجز
- تحقق من الإشعارات

---

## 📊 النتائج المتوقعة

| الخطوة | النتيجة المتوقعة |
|-------|-------------------|
| التسجيل | ✅ token و user info |
| البحث | ✅ قائمة مزودين |
| الحجز | ✅ booking ID |
| القبول | ✅ status = Confirmed |
| الإشعار | ✅ message متاح |
| التقييم | ✅ rating محفوظ |

---

## 🎯 الخطوة التالية

بعد التحقق من كل شيء:
1. أضف المزيد من بيانات الاختبار
2. اختبر سيناريوهات معقدة
3. تحقق من الأداء
4. انتقل للإنتاج

**هل لديك أي مشاكل؟ اتصل بـ Support! 📞**

