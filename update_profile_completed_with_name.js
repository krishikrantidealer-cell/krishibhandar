const mongoose = require('/Users/krishikranti/office_work/backend_krishi/node_modules/mongoose');

const MONGO_URI = 'mongodb+srv://krishikrantidealer_db_user:KrishiKranti%402026@krishikranti.tyerpvc.mongodb.net/krishibhandar_db?appName=KrishiKranti';

async function updateProfileStatusWithName() {
  console.log('Connecting to MongoDB krishibhandar_db...');
  const conn = await mongoose.createConnection(MONGO_URI, {
    maxPoolSize: 20,
    serverSelectionTimeoutMS: 15000
  }).asPromise();

  const col = conn.db.collection('customers');
  console.log('Connected.');

  console.log('Updating isprofilecompleted with Name requirement...');

  // 1. Any customer with isprofilecompleted = true but missing a valid name -> set isprofilecompleted = false
  // A name is considered missing if firstName is empty or only dots/spaces AND lastName is empty or only dots/spaces
  const customers = await col.find({ isprofilecompleted: true }).toArray();
  console.log(`Found ${customers.length} customers currently marked as isprofilecompleted = true.`);

  let invalidatedCount = 0;
  let bulkOps = [];

  for (const c of customers) {
    const fn = (c.firstName || '').trim();
    const ln = (c.lastName || '').trim();
    const fullName = [fn, ln].join(' ').replace(/[\.\s]+/g, ' ').trim();

    if (fullName.length === 0) {
      invalidatedCount++;
      bulkOps.push({
        updateOne: {
          filter: { _id: c._id },
          update: { $set: { isprofilecompleted: false } }
        }
      });
    }
  }

  if (bulkOps.length > 0) {
    const res = await col.bulkWrite(bulkOps, { ordered: false });
    console.log(`Updated ${res.modifiedCount} records to isprofilecompleted = false due to missing name.`);
  } else {
    console.log('No records needed invalidation.');
  }

  const finalCompleted = await col.countDocuments({ isprofilecompleted: true });
  const finalIncomplete = await col.countDocuments({ isprofilecompleted: false });

  console.log('\n========================================');
  console.log(`Total customers with Name + Phone + Address (isprofilecompleted = true) : ${finalCompleted}`);
  console.log(`Total customers missing Name, Phone, or Address (isprofilecompleted = false): ${finalIncomplete}`);
  console.log('========================================\n');

  // Show a sample completed record
  const sample = await col.findOne({ isprofilecompleted: true });
  console.log('Sample verified document:');
  console.log(JSON.stringify(sample, null, 2));

  await conn.close();
  console.log('Done!');
}

updateProfileStatusWithName().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
