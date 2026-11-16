import 'package:web/web.dart' as web;

Uri apiUri(String path, {Map<String, String>? queryParameters}) =>
    Uri(path: path, queryParameters: queryParameters);

String? readLegacyValue(String key) => web.window.localStorage.getItem(key);

void writeLegacyValue(String key, String value) =>
    web.window.localStorage.setItem(key, value);

void removeLegacyValue(String key) => web.window.localStorage.removeItem(key);
