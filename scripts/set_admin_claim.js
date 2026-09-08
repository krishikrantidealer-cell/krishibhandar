/**
 * Local script to set admin custom claims on a Firebase user.
 *
 * Usage:
 * 1. Download service-account.json from Firebase Console.
 * 2. Place it in the root or scripts directory.
 * 3. Update the constants below.
 * 4. Run: node scripts/set_admin_claim.js
 */

const { initializeApp, cert } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const path = require('path');
const fs = require('fs');

// --- UPDATE THESE ---
const SERVICE_ACCOUNT_PATH = path.join(__dirname, '..', 'service-account.json');
const TARGET_UID = 'RxOfzsd8cEYZHakYNTu4g9gAf393'; // Get this from Firebase Console -> Auth
// --------------------

if (!fs.existsSync(SERVICE_ACCOUNT_PATH)) {
    console.error('Error: service-account.json not found at ' + SERVICE_ACCOUNT_PATH);
    process.exit(1);
}

const serviceAccount = require(SERVICE_ACCOUNT_PATH);

initializeApp({
  credential: cert(serviceAccount)
});

const auth = getAuth();

async function setAdminClaim(uid) {
    try {
        await auth.setCustomUserClaims(uid, { admin: true });
        console.log(`Successfully set admin claim for user: ${uid}`);

        // Verify
        const user = await auth.getUser(uid);
        console.log('User custom claims:', user.customClaims);

        process.exit(0);
    } catch (error) {
        console.error('Error setting custom claims:', error);
        process.exit(1);
    }
}

if (TARGET_UID === 'YOUR_ADMIN_UID_HERE') {
    console.warn('Please update TARGET_UID in the script with the actual UID from Firebase Console.');
    process.exit(1);
}

setAdminClaim(TARGET_UID);
