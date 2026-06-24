class ApiConfig {
  static const String appVersion = '1.0.0';
  static const int schemaVersion = 2;
  static const String apiPrefix = '/api/v1';
  static const String defaultApiBaseUrl = 'http://192.168.120.107:8000/api/v1';

  static String normalizeBaseUrl(String rawUrl) {
    var url = rawUrl.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }

    if (url.endsWith('/sync')) {
      url = url.substring(0, url.length - '/sync'.length);
    }

    if (url.endsWith(apiPrefix)) {
      return url;
    }

    return '$url$apiPrefix';
  }

  static Uri endpoint(String rawBaseUrl, String path) {
    final baseUrl = normalizeBaseUrl(rawBaseUrl);
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$normalizedPath');
  }
}
