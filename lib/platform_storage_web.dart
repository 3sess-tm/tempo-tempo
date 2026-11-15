import 'package:web/web.dart' as web;

String? readLegacyValue(String key) => web.window.localStorage.getItem(key);

void writeLegacyValue(String key, String value) =>
    web.window.localStorage.setItem(key, value);

void removeLegacyValue(String key) => web.window.localStorage.removeItem(key);
