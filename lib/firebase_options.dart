import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web - '
        'you can reconfigure this by running the FlutterFire CLI again.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC-dSHnLAesJH-604nRPIubeSFMNC75K40',
    appId: '1:522708852035:android:c51db5bd2e010a8bf123f6',
    messagingSenderId: '522708852035',
    projectId: 'ebs-kisan-sewa',
    storageBucket: 'ebs-kisan-sewa.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyC-dSHnLAesJH-604nRPIubeSFMNC75K40',
    appId: '1:522708852035:ios:c51db5bd2e010a8bf123f6', // Placeholder for iOS, usually different
    messagingSenderId: '522708852035',
    projectId: 'ebs-kisan-sewa',
    storageBucket: 'ebs-kisan-sewa.firebasestorage.app',
    iosBundleId: 'com.snss.ebs.kisanSewaKendra',
  );
}
