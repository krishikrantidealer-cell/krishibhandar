const mongoose = require('/Users/krishikranti/office_work/backend_krishi/node_modules/mongoose');

const MONGO_URI = 'mongodb+srv://krishikrantidealer_db_user:KrishiKranti%402026@krishikranti.tyerpvc.mongodb.net/krishibhandar_db?appName=KrishiKranti';

async function removeFields() {
  console.log('Connecting to MongoDB krishibhandar_db...');
  const conn = await mongoose.createConnection(MONGO_URI, {
    maxPoolSize: 20,
    serverSelectionTimeoutMS: 15000
  }).asPromise();

  const col = conn.db.collection('customers');
  console.log('Connected.');

  console.log('Removing acceptsEmailMarketing, acceptsSmsMarketing, acceptsWhatsAppMarketing, taxExempt, and tags...');
  const result = await col.updateMany(
    {},
    {
      $unset: {
        acceptsEmailMarketing: '',
        acceptsSmsMarketing: '',
        acceptsWhatsAppMarketing: '',
        taxExempt: '',
        tags: ''
      }
    }
  );

  console.log(`Matched documents  : ${result.matchedCount}`);
  console.log(`Modified documents : ${result.modifiedCount}`);

  const sample = await col.findOne({ isprofilecompleted: true });
  console.log('\n--- Sample Cleaned Document ---');
  console.log(JSON.stringify(sample, null, 2));

  await conn.close();
  console.log('Done!');
}

removeFields().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
