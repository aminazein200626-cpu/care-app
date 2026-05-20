const { MongoClient } = require('mongodb');

async function fixUsers() {
  const uri = 'mongodb://localhost:27017';
  const client = new MongoClient(uri);
  
  try {
    await client.connect();
    const db = client.db('careapp');
    
    // تفعيل جميع الحسابات في accounts
    await db.collection('accounts').updateMany(
      {},
      { $set: { status: 'active' } }
    );
    console.log('✅ Accounts activated');
    
    // تفعيل جميع المستخدمين في users وإضافة username مؤقت
    await db.collection('users').updateMany(
      {},
      { $set: { isActive: true } }
    );
    console.log('✅ Users activated');
    
    // إضافة username لكل من ليس لديه username
    const users = await db.collection('users').find({ username: { $exists: false } }).toArray();
    for (const user of users) {
      const username = user.email ? user.email.split('@')[0] : `user_${user._id}`;
      await db.collection('users').updateOne(
        { _id: user._id },
        { $set: { username: username } }
      );
      console.log(`Username set for: ${user.email} -> ${username}`);
    }
    
    console.log('🎉 All fixed!');
  } catch (error) {
    console.error('Error:', error);
  } finally {
    await client.close();
  }
}

fixUsers();