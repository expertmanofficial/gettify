
abstract class SourceProvider {
  final String sourceType;
  final String sourceUrl;
  final String apkRegex;
  final bool trackPreReleases;

  SourceProvider({
    required this.sourceType,
    required this.sourceUrl,
    this.apkRegex = r'.*\.apk$',
    this.trackPreReleases = false,
  });

  Future<Map<String, dynamic>> fetchLatestRelease();

  Future<String> getLatestVersion() async {
    final release = await fetchLatestRelease();
    return release['version'] as String;
  }

  Future<String> getLatestApkUrl() async {
    final release = await fetchLatestRelease();
    final assets = release['assets'] as List<dynamic>;
    for (var asset in assets) {
      if (RegExp(apkRegex).hasMatch(asset['name'] as String)) {
        return asset['url'] as String;
      }
    }
    throw Exception('No matching APK found');
  }

  Future<String> getIconUrl() async => 'https://via.placeholder.com/128';
}
