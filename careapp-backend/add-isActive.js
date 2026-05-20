const { MongoClient } = require('mongodb');

async function addIsActive() {
  const uri = 'mongodb://localhost:27017';
  const client = new MongoClient(uri);
  
  try {
    await client.connect();
    const db = client.db('careapp');
    
    const result = await db.collection('users').updateMany(
      {},
      { $set: { isActive: true } }
    );
    
    console.log(`✅ Updated ${result.modifiedCount} users with isActive: true`);
  } catch (error) {
    console.error('Error:', error);
  } finally {
    await client.close();
  }
}

addIsActive();