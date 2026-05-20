# CareApp API Documentation

## Base URL
```
http://localhost:5001/api
```

---

## Authentication Routes (`/auth`)

### 1. تسجيل عميل جديد (Client Registration)
- **POST** `/auth/register`
- **Body:**
```json
{
  "fullName": "محمد علي",
  "email": "client@example.com",
  "password": "password123",
  "phoneNumber": "0123456789",
  "wilaya": "الجزائر",
  "address": "الجزائر - حيدرة"
}
```
- **Response:** Token + User Info

---

## Search Routes (`/search`)

### 2. البحث عن المزودين مع التصفية
- **GET** `/search/providers?wilaya=الجزائر&rating=4&sortBy=rating`
- **Query Parameters:**
  - `wilaya`: اسم الولاية
  - `municipality`: البلدية
  - `serviceId`: معرف الخدمة
  - `rating`: الحد الأدنى للتقييم
  - `hourlyRate`: السعر الأقصى للساعة
  - `sortBy`: `rating | price_low | price_high | experience`
  - `page`: رقم الصفحة
  - `limit`: عدد النتائج

### 3. البحث عن الخدمات
- **GET** `/search/services?search=تمريض&sortBy=rating`

### 4. تفاصيل المزود
- **GET** `/search/providers/{providerId}`

### 5. التوفرية
- **GET** `/search/providers/{providerId}/availability`

---

## Booking Routes

### 6. إنشاء حجز
- **POST** `/bookings`
- **Headers:** `Authorization: Bearer {token}`
- **Body:**
```json
{
  "providerId": "64a123...",
  "serviceId": "64b456...",
  "date": "2024-02-15",
  "startTime": "10:00",
  "endTime": "12:00",
  "dependentId": null,
  "location": "الجزائر - حيدرة",
  "notes": "ملاحظات إضافية",
  "clientTasks": [
    {
      "taskName": "تنظيف المنزل",
      "status": "pending"
    }
  ]
}
```

### 7. الحصول على الحجوزات
- **GET** `/bookings?status=Pending&role=client`

### 8. تفاصيل الحجز
- **GET** `/bookings/{bookingId}`

### 9. قبول/رفض الحجز (المزود)
- **PUT** `/bookings/{bookingId}/respond`
- **Body:**
```json
{
  "action": "accept",
  "reason": "سبب الرفض (اختياري)"
}
```

### 10. تحديث المهام
- **PUT** `/bookings/{bookingId}/tasks`
- **Body:**
```json
{
  "clientTasks": [
    {
      "taskName": "تنظيف غرفة النوم",
      "status": "completed"
    }
  ]
}
```

### 11. تحديث تقدم الخدمة
- **PUT** `/bookings/{bookingId}/progress`
- **Body:**
```json
{
  "trackingStage": "InProgress",
  "workSteps": [
    {
      "description": "تم البدء بالعمل",
      "time": "10:30"
    }
  ],
  "location": {
    "latitude": 36.7372,
    "longitude": 3.0868
  }
}
```

### 12. تقييم الخدمة
- **POST** `/bookings/{bookingId}/rate`
- **Body:**
```json
{
  "rating": 4.5,
  "feedback": "خدمة ممتازة جداً"
}
```

---

## Notification Routes

### 13. الحصول على الإشعارات
- **GET** `/notifications?unread=true&limit=20&page=1`

### 14. تحديد إشعار كمقروء
- **PUT** `/notifications/{notificationId}/read`

### 15. تحديد كل الإشعارات كمقروءة
- **PUT** `/notifications/mark-all-read`

### 16. حذف إشعار
- **DELETE** `/notifications/{notificationId}`

---

## Client Routes (`/client`)

### 17. الملف الشخصي
- **GET** `/client/profile`

### 18. تحديث الملف الشخصي
- **PUT** `/client/profile`

### 19. الإحصائيات
- **GET** `/client/stats`

### 20. المعالين
- **GET** `/client/dependents`

### 21. إضافة معال
- **POST** `/client/dependents`
- **Body:**
```json
{
  "fullName": "أحمد علي",
  "relationship": "child",
  "dateOfBirth": "2015-01-15",
  "nationalId": "12345678",
  "healthNotes": "ملاحظات طبية"
}
```

---

## Provider Routes (`/provider`)

### 22. الملف الشخصي
- **GET** `/provider/profile`

### 23. تحديث الملف الشخصي
- **PUT** `/provider/profile`

### 24. تحديث التوفرية
- **PUT** `/provider/availability`
- **Body:**
```json
{
  "dateSlots": {
    "2024-02-15": [
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

### 25. طلبات الحجز
- **GET** `/provider/bookings?status=Pending`

### 26. الإحصائيات
- **GET** `/provider/stats`

---

## Status Codes

| Code | Description |
|------|-------------|
| 200 | نجح |
| 201 | تم الإنشاء |
| 400 | خطأ في الطلب |
| 401 | غير مصرح |
| 404 | غير موجود |
| 500 | خطأ في الخادم |

---

## Response Format

### Success Response
```json
{
  "success": true,
  "message": "العملية نجحت",
  "data": {}
}
```

### Error Response
```json
{
  "success": false,
  "message": "وصف الخطأ"
}
```

---

## Frontend Implementation Example

### البحث عن مزودين (Flutter)
```dart
final response = await http.get(
  Uri.parse('http://localhost:5001/api/search/providers?wilaya=الجزائر&rating=4'),
  headers: {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json'
  },
);

if (response.statusCode == 200) {
  final data = jsonDecode(response.body);
  if (data['success']) {
    List providers = data['data'];
  }
}
```

---

## Database Schema

### Client Collection
```json
{
  "userId": ObjectId,
  "fullName": String,
  "email": String,
  "phoneNumber": String,
  "wilaya": String,
  "municipality": String,
  "address": String,
  "gender": "M|F",
  "dateOfBirth": Date,
  "profilePicture": String,
  "dependents": [ObjectId],
  "isActive": Boolean,
  "status": "active|inactive|blocked|pending",
  "createdAt": Date
}
```

### ServiceProvider Collection
```json
{
  "userId": ObjectId,
  "fullName": String,
  "email": String,
  "phoneNumber": String,
  "wilaya": String,
  "municipality": String,
  "address": String,
  "hourlyRate": Number,
  "yearsOfExperience": Number,
  "services": [ObjectId],
  "availability": Map,
  "status": "pending_verification|active|inactive",
  "averageRating": Number,
  "createdAt": Date
}
```

### Booking Collection
```json
{
  "clientId": ObjectId,
  "providerId": ObjectId,
  "serviceId": ObjectId,
  "date": Date,
  "startTime": String,
  "endTime": String,
  "location": String,
  "status": "Pending|Confirmed|In Progress|Completed|Cancelled",
  "totalPrice": Number,
  "clientTasks": [Object],
  "trackingStage": String,
  "rating": Number,
  "feedback": String,
  "createdAt": Date
}
```

---

## Error Handling

### في Flutter:
```dart
try {
  final response = await http.get(...);
  
  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    if (data['success']) {
      // استخدم البيانات
    } else {
      // خطأ من الخادم
      showError(data['message']);
    }
  } else {
    showError('خطأ: ${response.statusCode}');
  }
} catch (e) {
  showError('خطأ في الاتصال: $e');
}
```

---

## Notes

1. **التوفرية:** يتم تخزينها كـ Map بحيث يحتوي كل تاريخ على قائمة بالمواعيد المتاحة
2. **الأسعار:** يتم حسابها تلقائياً بناءً على معدل الساعة ومدة الخدمة
3. **التقييمات:** يتم تحديث متوسط التقييم تلقائياً عند إضافة تقييم جديد
4. **الإشعارات:** يتم إرسالها تلقائياً عند تغيير حالة الحجز

