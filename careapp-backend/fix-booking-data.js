const mongoose = require('mongoose');
const Booking = require('./models/Booking');  // ✅ المسار الصحيح

async function fixBookings() {
  try {
    // تأكد من تغيير رابط قاعدة البيانات إذا لزم الأمر
    await mongoose.connect('mongodb://localhost:27017/careapp');
    console.log('✅ Connected to MongoDB');

    const bookings = await Booking.find({});
    let modifiedCount = 0;

    for (let booking of bookings) {
      let modified = false;

      // دالة لتصحيح الحقول التي يجب أن تكون مصفوفة
      const fixArray = (field) => {
        if (Array.isArray(field)) return field;
        if (typeof field === 'string') {
          try {
            const parsed = JSON.parse(field);
            return Array.isArray(parsed) ? parsed : [];
          } catch(e) {
            return [];
          }
        }
        return [];
      };

      // دالة لتصحيح الحقول التي يجب أن تكون كائن
      const fixObject = (field) => {
        if (field && typeof field === 'object' && !Array.isArray(field)) return field;
        if (typeof field === 'string') {
          try {
            const parsed = JSON.parse(field);
            return (parsed && typeof parsed === 'object') ? parsed : {};
          } catch(e) {
            return {};
          }
        }
        return {};
      };

      const newWorkSteps = fixArray(booking.workSteps);
      const newAttachments = fixArray(booking.attachments);
      const newClientTasks = fixArray(booking.clientTasks);
      const newStageTimes = fixObject(booking.stageTimes);

      if (JSON.stringify(booking.workSteps) !== JSON.stringify(newWorkSteps)) {
        booking.workSteps = newWorkSteps;
        modified = true;
      }
      if (JSON.stringify(booking.attachments) !== JSON.stringify(newAttachments)) {
        booking.attachments = newAttachments;
        modified = true;
      }
      if (JSON.stringify(booking.clientTasks) !== JSON.stringify(newClientTasks)) {
        booking.clientTasks = newClientTasks;
        modified = true;
      }
      if (JSON.stringify(booking.stageTimes) !== JSON.stringify(newStageTimes)) {
        booking.stageTimes = newStageTimes;
        modified = true;
      }

      if (modified) {
        await booking.save();
        modifiedCount++;
        console.log(`✅ Fixed booking ${booking._id}`);
      }
    }

    console.log(`🎉 Done. Fixed ${modifiedCount} bookings.`);
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

fixBookings();