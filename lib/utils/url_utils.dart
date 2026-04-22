// ignore_for_file: avoid_print

/// URL normalization helpers used by settings screens and discovery.
///
/// These fixes make the app tolerant of common user inputs like:
/// - "192.168.1.10:5601"
/// - "localhost:5601"
/// - "http://192.168.1.10:5601/" (trailing slash)
class UrlUtils {
  static String normalizeHttpBaseUrl(String input) {
    var s = input.trim();
    if (s.isEmpty) return s;

    // Leave placeholders alone so UI validation can catch them.
    // (Go side will also reject "[IP]" if it reaches it.)

    if (s.startsWith('//')) {
      s = 'http:$s';
    }

    final hasScheme = s.contains('://');
    if (!hasScheme) {
      s = 'http://$s';
    }

    Uri? uri;
    try {
      uri = Uri.parse(s);
    } catch (_) {
      return s; // let validators show the error
    }

    // Remove trailing slash in path.
    var path = uri.path;
    if (path.endsWith('/') && path.length > 1) {
      path = path.substring(0, path.length - 1);
    } else if (path == '/') {
      path = '';
    }

    uri = uri.replace(path: path, query: '', fragment: '');
    var out = uri.toString();
    while (out.endsWith('/')) {
      out = out.substring(0, out.length - 1);
    }
    return out;
  }

  /// Normalize STUN/TURN input.
  /// If the user already typed "stun:" or "turn:", keep it.
  /// Otherwise, treat as host:port and prefix with "stun:".
  static String normalizeIceServer(String input) {
    final s = input.trim();
    if (s.isEmpty) return s;
    final lower = s.toLowerCase();
    if (lower.startsWith('stun:') || lower.startsWith('turn:') || lower.startsWith('turns:')) {
      return s;
    }
    return 'stun:$s';
  }
}
