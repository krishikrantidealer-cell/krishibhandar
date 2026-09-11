const fs = require('fs');
const path = require('path');
const mongoose = require('/Users/krishikranti/office_work/backend_krishi/node_modules/mongoose');
const csv = require('/Users/krishikranti/office_work/backend_krishi/node_modules/csv-parser');

const MONGO_URI = 'mongodb+srv://krishikrantidealer_db_user:KrishiKranti%402026@krishikranti.tyerpvc.mongodb.net/krishibhandar_db?appName=KrishiKranti';
const CSV_FILE = path.join(__dirname, 'customers_export.csv');

async function importCustomers() {
  console.log('Connecting to MongoDB krishibhandar_db...');
  const conn = await mongoose.createConnection(MONGO_URI, {
    maxPoolSize: 20,
    serverSelectionTimeoutMS: 15000
  }).asPromise();

  const col = conn.db.collection('customers');
  console.log('Connected successfully to database:', conn.name);

  const batchSize = 1000;
  let ops = [];
  let processed = 0;
  let completedProfileCount = 0;
  let totalUpserted = 0;
  let totalModified = 0;

  const stream = fs.createReadStream(CSV_FILE).pipe(csv());

  for await (const row of stream) {
    const customerId = (row['Customer ID'] || '').replace(/^'/, '').trim();
    if (!customerId) continue;

    const firstName = (row['First Name'] || '').trim();
    const lastName = (row['Last Name'] || '').trim();
    const email = (row['Email'] || '').trim();
    const rawPhone = (row['Phone'] || '').replace(/^'/, '').trim();
    const rawAddrPhone = (row['Default Address Phone'] || '').replace(/^'/, '').trim();
    const phone = rawPhone || rawAddrPhone;

    const company = (row['Default Address Company'] || '').trim();
    const address1 = (row['Default Address Address1'] || '').trim();
    const address2 = (row['Default Address Address2'] || '').trim();
    const city = (row['Default Address City'] || '').trim();
    const province = (row['Default Address Province Code'] || '').trim();
    const country = (row['Default Address Country Code'] || 'IN').trim();
    const zip = (row['Default Address Zip'] || '').trim();
    const defaultAddrPhone = rawAddrPhone || rawPhone;

    const cleanName = [firstName, lastName].join(' ').replace(/[\.\s]+/g, ' ').trim();
    const hasName = Boolean(cleanName.length > 0);
    const hasPhone = Boolean(phone && phone.length >= 6);
    const hasAddress = Boolean(address1 || city || zip);
    const isProfileCompleted = Boolean(hasName && hasPhone && hasAddress);

    if (isProfileCompleted) {
      completedProfileCount++;
    }

    const defaultAddress = {
      company,
      address1,
      address2,
      city,
      province,
      country,
      zip,
      phone: defaultAddrPhone
    };

    const doc = {
      _id: customerId,
      firstName,
      lastName,
      email,
      phone,
      totalSpent: parseFloat(row['Total Spent']) || 0.0,
      totalOrders: parseInt(row['Total Orders'], 10) || 0,
      defaultAddress,
      note: (row['Note'] || '').trim(),
      isprofilecompleted: isProfileCompleted,
      status: 'active',
      role: 'customer',
      importedAt: new Date()
    };

    if (hasAddress) {
      doc.addresses = [{
        name: [firstName, lastName].filter(Boolean).join(' ').trim() || 'Default Address',
        street: address1,
        address1,
        address2,
        city,
        province,
        country: country || 'India',
        zip,
        phone: defaultAddrPhone,
        isDefault: true
      }];
    } else {
      doc.addresses = [];
    }

    ops.push({
      updateOne: {
        filter: { _id: customerId },
        update: {
          $set: doc,
          $setOnInsert: { createdAt: new Date() }
        },
        upsert: true
      }
    });

    processed++;

    if (ops.length >= batchSize) {
      const res = await col.bulkWrite(ops, { ordered: false });
      totalUpserted += res.upsertedCount;
      totalModified += res.modifiedCount;
      console.log(`Processed ${processed} / 44881 customers... (upserted: ${totalUpserted}, updated: ${totalModified})`);
      ops = [];
    }
  }

  if (ops.length > 0) {
    const res = await col.bulkWrite(ops, { ordered: false });
    totalUpserted += res.upsertedCount;
    totalModified += res.modifiedCount;
    ops = [];
  }

  console.log('\n========================================');
  console.log('Customer Import Finished Successfully!');
  console.log(`Total CSV records processed : ${processed}`);
  console.log(`New documents inserted      : ${totalUpserted}`);
  console.log(`Existing documents updated  : ${totalModified}`);
  console.log(`isprofilecompleted = true   : ${completedProfileCount}`);
  console.log(`isprofilecompleted = false  : ${processed - completedProfileCount}`);
  console.log('========================================\n');

  console.log('Ensuring indexes...');
  await col.createIndex({ isprofilecompleted: 1 });
  await col.createIndex({ isProfileCompleted: 1 });
  await col.createIndex({ phone: 1 });
  await col.createIndex({ email: 1 });
  console.log('Indexes created successfully.');

  await conn.close();
}

importCustomers().catch(err => {
  console.error('Import error:', err);
  process.exit(1);
});
