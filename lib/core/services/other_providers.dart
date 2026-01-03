import 'source_provider.dart';

class GitLabProvider extends SourceProvider {
  GitLabProvider({required super.sourceUrl, super.apkRegex, super.trackPreReleases})
      : super(sourceType: 'GitLab');

  @override
  Future<Map<String, dynamic>> fetchLatestRelease() async {
    throw UnimplementedError('GitLab not implemented yet');
  }
}

class FDroidProvider extends SourceProvider {
  FDroidProvider({required super.sourceUrl, super.apkRegex, super.trackPreReleases})
      : super(sourceType: 'F-Droid');

  @override
  Future<Map<String, dynamic>> fetchLatestRelease() async {
    throw UnimplementedError('F-Droid not implemented yet');
  }
}

// Add more placeholders: IzzyOnDroidProvider, APKMirrorProvider, HTMLProvider, etc.
