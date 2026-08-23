/// Parameters extracted from a streamplayer:// deep link.
///
/// Expected format:
///   streamplayer://play?url=<encoded>&title=<encoded>&cookie=<encoded>&...
///
/// All fields are optional – the player screen gracefully handles missing ones.
class PlayerParams {
  /// The media URL (or any other query param) forwarded to the player endpoint.
  final Map<String, String> queryParams;

  /// Cookie value to be set on streamworld.vercel.app before loading the player.
  final String? cookie;

  /// Cookie name (defaults to "session")
  final String cookieName;

  const PlayerParams({
    required this.queryParams,
    this.cookie,
    this.cookieName = 'session',
  });

  factory PlayerParams.fromUri(Uri uri) {
    final params = Map<String, String>.from(uri.queryParameters);

    // Extract cookie-specific fields so they are not forwarded as URL params
    final cookie = params.remove('cookie');
    final cookieName = params.remove('cookie_name') ?? 'session';

    return PlayerParams(
      queryParams: params,
      cookie: cookie,
      cookieName: cookieName,
    );
  }

  /// Build the final player URL with query params appended.
  String buildPlayerUrl(String baseUrl) {
    if (queryParams.isEmpty) return baseUrl;
    final uri = Uri.parse(baseUrl);
    final merged = {...uri.queryParameters, ...queryParams};
    return uri.replace(queryParameters: merged).toString();
  }

  bool get hasParams => queryParams.isNotEmpty || cookie != null;
}
