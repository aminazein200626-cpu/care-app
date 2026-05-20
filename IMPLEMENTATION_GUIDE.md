# CareApp - نظام الرعاية الصحية المتكامل
## دليل التطبيق الشامل

---

## المحتويات
1. [البنية العامة](#البنية-العامة)
2. [تدفق المستخدم الأساسي](#تدفق-المستخدم-الأساسي)
3. [الميزات الرئيسية](#الميزات-الرئيسية)
4. [دليل التطوير](#دليل-التطوير)
5. [الاختبار](#الاختبار)

---

## البنية العامة

### Frontend
- **Flutter**: تطبيق موبايل للعملاء والمزودين
  - `lib/presentation/client/` - واجهات العملاء
  - `lib/presentation/provider/` - واجهات المزودين
  - `lib/services/` - خدمات التواصل مع API

### Backend
- **Node.js + Express**: خادم الـ API
  - `routes/` - المسارات والـ endpoints
  - `controllers/` - منطق الأعمال
  - `models/` - نماذج MongoDB

### Database
- **MongoDB**: قاعدة البيانات
  - Collections: User, Client, ServiceProvider, Booking, Dependent, Service, Notification

### Admin
- **React**: لوحة التحكم (قادم قريباً)

---

## تدفق المستخدم الأساسي

### 1. العميل (Client)

#### التسجيل
```
العميل ينقر على "تسجيل جديد"
  ↓
يملأ البيانات الأساسية (الاسم، البريد، الهاتف، الولاية)
  ↓
يتم إنشاء حساب العميل في MongoDB
  ↓
يستقبل JWT Token
  ↓
ينتقل إلى الصفحة الرئيسية
```

#### البحث والحجز
```
العميل ينتقل إلى "البحث عن خدمة"
  ↓
يختار الولاية والخدمة والسعر
  ↓
يظهر قائمة المزودين المتاحين
  ↓
ينقر على مزود ويرى التفاصيل والتقييمات
  ↓
يختار تاريخ ووقت متاح
  ↓
يضيف المهام المطلوبة والملفات
  ↓
يتم إنشاء الحجز → إشعار يصل للمزود
```

#### المهام والمتابعة
```
العميل يضيف المهام التي يريد من المزود تنفيذها
  ↓
المزود يقبل الحجز ويبدأ العمل
  ↓
العميل يتابع التقدم في الوقت الفعلي
  ↓
بعد الانتهاء: العميل يقيم الخدمة
```

---

### 2. المزود (Provider)

#### التسجيل
```
المزود ينقر على "تسجيل مزود"
  ↓
يملأ البيانات:
  - المعلومات الشخصية
  - التخصص والخبرة
  - السعر في الساعة
  - أنواع الخدمات
  ↓
يرفع الوثائق والشهادات
  ↓
ينتظر موافقة الإدارة
```

#### إدارة التوفرية
```
المزود يفتح تقويم التوفرية
  ↓
يضيف الأيام والمواعيد المتاحة
  ↓
يختار لكل موعد (من الساعة فلان إلى الساعة علان)
  ↓
النظام يحفظ التوفرية في قاعدة البيانات
```

#### قبول الطلبات
```
العميل يطلب حجز
  ↓
المزود يستقبل إشعار
  ↓
يرى تفاصيل الطلب والمهام المطلوبة
  ↓
يقبل أو يرفض الحجز
  ↓
إشعار يصل للعميل
```

#### تنفيذ الخدمة
```
المزود يبدأ الخدمة
  ↓
يحدّث حالة الخدمة (قيد الطريق، وصل، بدأ العمل، إلخ)
  ↓
يرفع الملفات والصور
  ↓
يكمل الخدمة
  ↓
العميل يقيم الخدمة
```

---

## الميزات الرئيسية

### 1. البحث والتصفية 🔍
- البحث عن المزودين حسب:
  - الولاية والبلدية
  - نوع الخدمة
  - التقييم (4.5 ⭐ فما فوق)
  - السعر
  - الخبرة

### 2. نظام الحجز 📅
- إنشاء حجز بسهولة
- اختيار تاريخ ووقت متاح
- إضافة المعالين والملفات
- تحديد المهام المطلوبة

### 3. المهام والعمل 📝
- العميل يحدد المهام المطلوبة
- المزود ينفذ ويحدّث الحالة
- نظام متابعة تفصيلي

### 4. الإشعارات 🔔
- إشعار فوري عند طلب حجز
- إشعار عند قبول/رفض الحجز
- إشعارات التحديثات أثناء الخدمة

### 5. التقييمات والمراجعات ⭐
- العميل يقيم الخدمة (0-5)
- يكتب ملاحظاته
- تأثير التقييم على تصنيف المزود

### 6. المعالين 👨‍👩‍👧
- إضافة معالين (أطفال، والدين، إلخ)
- حفظ المعلومات الطبية
- رفع الملفات الطبية

---

## دليل التطوير

### Backend (Node.js)

#### 1. البيئة والإعدادات
```bash
cd careapp-backend
npm install
npm run dev  # تشغيل مع nodemon
```

#### 2. متغيرات البيئة (.env)
```
MONGODB_URI=mongodb://localhost:27017/careapp
JWT_SECRET=your_secret_key
PORT=5001
NODE_ENV=development
```

#### 3. مثال: إضافة API جديد

**1. إنشاء Model** (إن لم يكن موجوداً)
```javascript
// models/NewModel.js
const mongoose = require('mongoose');

const newSchema = new mongoose.Schema({
  name: String,
  createdAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model('NewModel', newSchema);
```

**2. إنشاء Controller**
```javascript
// controllers/newController.js
const NewModel = require('../models/NewModel');

exports.getAll = async (req, res) => {
  try {
    const items = await NewModel.find();
    res.json({ success: true, data: items });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};
```

**3. إنشاء Routes**
```javascript
// routes/newRoutes.js
const express = require('express');
const router = express.Router();
const { authMiddleware } = require('../middleware/auth');
const newController = require('../controllers/newController');

router.get('/new', authMiddleware, newController.getAll);

module.exports = router;
```

**4. إضافة في server.js**
```javascript
const newRoutes = require('./routes/newRoutes');
app.use('/api', newRoutes);
```

---

### Flutter (Client)

#### 1. الاستقبال من API
```dart
import 'package:http/http.dart' as http;
import 'dart:convert';

class MyService {
  static Future<List> searchProviders() async {
    final response = await http.get(
      Uri.parse('http://localhost:5001/api/search/providers'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success']) {
        return data['data'];
      }
    }
    throw Exception('Failed');
  }
}
```

#### 2. عرض البيانات مع FutureBuilder
```dart
FutureBuilder(
  future: MyService.searchProviders(),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return CircularProgressIndicator();
    }
    if (snapshot.hasError) {
      return Text('Error: ${snapshot.error}');
    }
    final providers = snapshot.data ?? [];
    return ListView.builder(
      itemCount: providers.length,
      itemBuilder: (context, index) {
        return ProviderCard(provider: providers[index]);
      },
    );
  },
)
```

---

## الاختبار

### 1. اختبار الـ API مع Postman

#### إنشاء حجز:
```
POST: http://localhost:5001/api/bookings
Headers:
  - Authorization: Bearer <token>
  - Content-Type: application/json

Body:
{
  "providerId": "64a123...",
  "serviceId": "64b456...",
  "date": "2024-02-20",
  "startTime": "10:00",
  "endTime": "12:00",
  "location": "الجزائر",
  "clientTasks": [
    {"taskName": "تنظيف", "status": "pending"}
  ]
}
```

#### البحث عن مزودين:
```
GET: http://localhost:5001/api/search/providers?wilaya=الجزائر&rating=4
```

### 2. اختبار الـ Flutter

#### التشغيل:
```bash
cd careapp_mobile
flutter pub get
flutter run
```

#### التصحيح (Debug):
```bash
flutter run -v  # verbose mode
```

---

## استكشاف الأخطاء

### خطأ: "Connection refused"
```
✗ الخادم غير مشغل
✓ الحل: npm run dev في مجلد backend
```

### خطأ: "Invalid token"
```
✗ Token انتهت صلاحيته أو غير صحيح
✓ الحل: تسجيل الدخول مجدداً وحفظ Token جديد
```

### خطأ: "Slot already booked"
```
✗ الموعد محجوز بالفعل
✓ الحل: اختيار موعد آخر متاح
```

---

## نصائح للتطوير السريع

### 1. استخدام ApiService
```dart
final apiService = ApiService();
final providers = await apiService.searchProviders(
  wilaya: 'الجزائر',
  rating: 4,
);
```

### 2. معالجة الأخطاء
```dart
try {
  final data = await apiService.createBooking(...);
  if (data['success']) {
    // نجح
  }
} catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Error: $e'))
  );
}
```

### 3. حفظ البيانات
```dart
final prefs = await SharedPreferences.getInstance();
prefs.setString('token', token);
prefs.setString('userId', userId);
```

---

## الملفات المهمة

### Backend
- `server.js` - الملف الرئيسي
- `models/` - جميع النماذج
- `routes/` - جميع المسارات
- `controllers/` - منطق الأعمال
- `middleware/auth.js` - التحقق من الـ Token

### Frontend
- `lib/services/api_service.dart` - خدمة API
- `lib/presentation/client/` - واجهات العميل
- `lib/presentation/provider/` - واجهات المزود
- `lib/core/api_config.dart` - إعدادات API

---

## التحديثات القادمة

- [ ] إضافة React Admin Panel
- [ ] تطبيق iOS متخصص
- [ ] نظام الدفع المتكامل
- [ ] الخرائط والملاحة
- [ ] مكالمات الفيديو
- [ ] المزيد من التحليلات

---

## للمساعدة والدعم

- 📧 البريد: support@careapp.com
- 💬 Slack: #careapp-support
- 📱 الهاتف: 0XXX-XXX-XXXX

