Uri apiUri(String path, {Map<String, String>? queryParameters}) =>
    Uri.https('tempo-tempo.cozmo-city.com', path, queryParameters);

String? readLegacyValue(String key) => null;

void writeLegacyValue(String key, String value) {}

void removeLegacyValue(String key) {}
