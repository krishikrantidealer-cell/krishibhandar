import 'package:shared_preferences/shared_preferences.dart';

enum PrefKey {
  lang,
  cart,
  checkoutId,
  userAccessToken,
  userAccessTokenExp,
}

class Pref {
  static SharedPreferences? _prefs;

  static Future<SharedPreferences> _preferences() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  static Future<void> ensureInitialized() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static Future<String?> getPref(PrefKey key) async {
    return (await _preferences()).getString(key.name);
  }

  static Future<bool> removePrefKey(PrefKey key) async {
    return (await _preferences()).remove(key.name);
  }

  static Future<bool> setPref(
      {required PrefKey key, required String value}) async {
    return (await _preferences()).setString(key.name, value);
  }

  static Future<bool> cleanPref() async {
    return (await _preferences()).clear();
  }
}
