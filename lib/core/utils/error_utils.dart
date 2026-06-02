import 'package:dio/dio.dart';

/// Extracts a clean, user-facing error message from any exception.
///
/// DioException stores our clean message in [DioException.error] (set by
/// _ErrorInterceptor). Calling toString() on the raw exception gives the
/// verbose "DioException [bad response]: null\nError: ..." text instead.
String parseError(Object? e) {
  if (e == null) return 'Erreur inconnue';

  if (e is DioException) {
    // _ErrorInterceptor sets error: cleanMessage — prefer that.
    final clean = e.error?.toString();
    if (clean != null && clean.isNotEmpty) return clean;
    // Fall back to the server's message field if present.
    final data = e.response?.data;
    if (data is Map) {
      final msg = data['message'];
      if (msg is String && msg.isNotEmpty) return msg;
      if (msg is List && msg.isNotEmpty) return msg.join(', ');
    }
    return e.message ?? 'Erreur serveur';
  }

  // Strip "Exception: " prefix that Dart adds for throw Exception('...')
  final s = e.toString();
  if (s.startsWith('Exception: ')) return s.substring(11);
  return s;
}
