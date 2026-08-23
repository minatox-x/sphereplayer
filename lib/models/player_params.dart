/// Parameters extracted from a  streamplayer://  deep link.
///
/// Protocol format:
///   streamplayer://play?bid=ABC&sid=XYZ&title=Foo&slug=bar&cookie=TOKEN&cookie_name=session
///
/// Rules:
///  - "cookie"       → extracted, NOT forwarded to player URL
///  - "cookie_name"  → extracted, NOT forwarded to player URL  (default: "session")
///  - everything else → forwarded verbatim as query params to /player2
///
/// Example result for:
///   streamplayer://play?bid=6779&sid=69d6&title=Electrostatics&slug=physics&cookie=abc
///
/// buildPlayerUrl("https://streamworld.vercel.app/player2") →
///   https://streamworld.vercel.app/player2?bid=6779&sid=69d6&title=Electrostatics&slug=physics
///
/// cookie → "abc", cookieName → "session"
class PlayerParams {
  /// All query params that will be forwarded to the player endpoint.
  final Map<String, String> queryParams;

  /// Cookie value to set on streamworld.vercel.app  (null = no cookie)
  final String? cookie;

  /// Cookie name  (default: "session")
  final String cookieName;

  const PlayerParams({
    required this.queryParams,
    this.cookie,
    this.cookieName = 'session',
  });

  // ── Parsing ────────────────────────────────────────────────────────────────

  factory PlayerParams.fromUri(Uri uri) {
    // Clone so we can remove internal-only keys without mutating the Uri
    final params = Map<String, String>.from(uri.queryParameters);

    final cookie     = params.remove('cookie');
    final cookieName = params.remove('cookie_name') ?? 'session';

    return PlayerParams(
      queryParams: params,
      cookie:      cookie,
      cookieName:  cookieName,
    );
  }

  // ── URL builder ────────────────────────────────────────────────────────────

  /// Appends [queryParams] to [baseUrl], merging with any params already
  /// present in the base URL.  Our params take precedence on collision.
  String buildPlayerUrl(String baseUrl) {
    if (queryParams.isEmpty) return baseUrl;

    final base   = Uri.parse(baseUrl);
    final merged = <String, String>{...base.queryParameters, ...queryParams};

    return base.replace(queryParameters: merged).toString();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  bool get hasCookie => cookie != null && cookie!.isNotEmpty;
  bool get hasParams  => queryParams.isNotEmpty || hasCookie;

  @override
  String toString() =>
      'PlayerParams(params=$queryParams, cookie=${hasCookie ? "[set]" : "none"})';
}
