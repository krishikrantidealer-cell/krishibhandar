/**
 * DEVELOPMENT ONLY - DATA-ONLY FCM TEST SENDER
 *
 * Instructions:
 * 1. Download service-account.json from Firebase Console.
 * 2. Place it in this 'dev_fcm_tester' directory.
 * 3. Run: npm install
 * 4. Run: node send_data_only.js
 */

const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

const serviceAccountPath = path.join(__dirname, 'service-account.json');

if (!fs.existsSync(serviceAccountPath)) {
    console.error('----------------------------------------------------------------');
    console.error('ERROR: service-account.json NOT FOUND');
    console.error('Please download it from Firebase Console -> Project Settings -> Service Accounts');
    console.error('And place it at: ' + serviceAccountPath);
    console.error('----------------------------------------------------------------');
    process.exit(1);
}

const serviceAccount = require(serviceAccountPath);

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const topic = 'all_users';

const message = {
    topic: topic,
    data: {
        title: 'TEST DATA ONLY IMAGE',
        body: 'TEST DATA ONLY NOTIFICATION',
        image: 'https://cdn.shopify.com/s/files/1/0627/9204/0601/files/notification_2.png?v=1782217684'
    },
    android: {
        priority: 'high'
    }
};

console.log('[FCM-SENDER] DATA_ONLY = true');
console.log('[FCM-SENDER] topic = ' + topic);
console.log('[FCM-SENDER] image = present');
console.log('[FCM-SENDER] priority = high');

admin.messaging().send(message)
    .then((response) => {
        console.log('[FCM-SENDER] sent = true');
        console.log('[FCM-SENDER] message_id = ' + response);
        process.exit(0);
    })
    .catch((error) => {
        console.error('[FCM-SENDER] sent = false');
        console.error('[FCM-SENDER] error = ' + error);
        process.exit(1);
    });
