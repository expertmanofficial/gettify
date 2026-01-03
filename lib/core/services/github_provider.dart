import 'source_provider.dart';

class GitHubProvider extends SourceProvider {
  GitHubProvider({
    required super.sourceUrl,
    super.apkRegex,
    super.trackPreReleases,
  }) : super(sourceType: 'GitHub');

  @override
  Future<Map<String, dynamic>> fetchLatestRelease() async {
    final uri = Uri.parse(sourceUrl);
    final parts = uri.pathSegments;
    final owner = parts[0];
    final repo = parts[1];

    String url = 'https://api.github.com/repos/$owner/$repo/releases/latest';
    if (trackPreReleases) {
      url = 'https://api.github.com/repos/$owner/$repo/releases';
    }

    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('GitHub API error: ${response.statusCode}');
    }

    dynamic data = json.decode(response.body);
    if (data is List) {
      // For pre-releases: take first (newest)
      data = data.firstWhere((r) => !r['prerelease'] || trackPreReleases, orElse: () => data.first);
    }

    return {
      'version': data['tag_name'] as String,
      'assets': (data['assets'] as List).map((a) => {
        'name': a['name'] as String,
        'url': a['browser_download_url'] as String,
      }).toList(),
    };
  }
}
