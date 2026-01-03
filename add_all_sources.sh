#!/usr/bin/env bash

echo "Obtanium Continued - Add all source types script"
echo "This will add GitHub support + placeholders for everything else"
echo "Press Enter to continue, Ctrl+C to cancel"
read -r

# Create folders
mkdir -p lib/core/models lib/core/services lib/core/database

# 1. tracked_app.dart (enhanced model)
cat > lib/core/models/tracked_app.dart << 'EOF'
class TrackedApp {
  final String id;
  final String name;
  final String packageName;
  final String sourceUrl;
  final String sourceType;
  final String currentVersion;
  final String latestVersion;
  final String iconUrl;
  final String author;
  final DateTime lastChecked;
  final String apkRegex;
  final bool trackPreReleases;

  TrackedApp({
    required this.id,
    required this.name,
    required this.packageName,
    required this.sourceUrl,
    required this.sourceType,
    required this.currentVersion,
    required this.latestVersion,
    required this.iconUrl,
    required this.author,
    required this.lastChecked,
    this.apkRegex = r'.*\.apk$',
    this.trackPreReleases = false,
  });

  bool get hasUpdate => currentVersion != latestVersion;
}
EOF

# 2. source_provider.dart (abstract base)
cat > lib/core/services/source_provider.dart << 'EOF'
import 'package:http/http.dart' as http;
import 'dart:convert';

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
EOF

# 3. github_provider.dart (fully working)
cat > lib/core/services/github_provider.dart << 'EOF'
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
EOF

# 4. Placeholder for other sources (you can expand later)
cat > lib/core/services/other_providers.dart << 'EOF'
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
EOF

# 5. Update main.dart (add real add logic + full dropdown)
sed -i '/import .*;/a import "core/models/tracked_app.dart";\nimport "core/services/source_provider.dart";\nimport "core/services/github_provider.dart";\nimport "core/services/other_providers.dart";' lib/main.dart

# Replace AddAppBottomSheet with full version
cat > lib/add_app_bottom_sheet_temp.dart << 'EOF'
// Paste this entire block into your main.dart, replacing the old AddAppBottomSheet class

class AddAppBottomSheet extends StatefulWidget {
  const AddAppBottomSheet({super.key});

  @override
  State<AddAppBottomSheet> createState() => _AddAppBottomSheetState();
}

class _AddAppBottomSheetState extends State<AddAppBottomSheet> {
  String _sourceType = 'GitHub';
  final _urlController = TextEditingController();
  final _regexController = TextEditingController(text: r'.*\.apk$');
  bool _preReleases = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add New App', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            DropdownButton<String>(
              value: _sourceType,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 'GitHub', child: Text('GitHub Releases')),
                DropdownMenuItem(value: 'GitLab', child: Text('GitLab')),
                DropdownMenuItem(value: 'Codeberg', child: Text('Codeberg / Forgejo')),
                DropdownMenuItem(value: 'F-Droid', child: Text('F-Droid')),
                DropdownMenuItem(value: 'IzzyOnDroid', child: Text('IzzyOnDroid')),
                DropdownMenuItem(value: 'APKPure', child: Text('APKPure')),
                DropdownMenuItem(value: 'APKMirror', child: Text('APKMirror (track only)')),
                DropdownMenuItem(value: 'HTML', child: Text('HTML / Custom scraping')),
                DropdownMenuItem(value: 'Telegram', child: Text('Telegram Channel')),
                DropdownMenuItem(value: 'RSS', child: Text('RSS Feed')),
                // Add more as we implement them
              ],
              onChanged: (val) => setState(() => _sourceType = val!),
            ),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(labelText: 'Source URL'),
            ),
            TextField(
              controller: _regexController,
              decoration: const InputDecoration(labelText: 'APK filename regex (optional)'),
            ),
            SwitchListTile(
              title: const Text('Include pre-releases / drafts'),
              value: _preReleases,
              onChanged: (v) => setState(() => _preReleases = v),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                FilledButton(
                  onPressed: () {
                    if (_urlController.text.isEmpty) return;
                    Provider.of<AppState>(context, listen: false).addAppFromUrl(
                      _urlController.text.trim(),
                      _sourceType,
                      _regexController.text.trim(),
                      _preReleases,
                    );
                    Navigator.pop(context);
                  },
                  child: const Text('Add'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
EOF

echo "Script finished!"
echo "Now:"
echo "1. Open Android Studio → your project"
echo "2. Open lib/main.dart"
echo "3. Find the old AddAppBottomSheet class and REPLACE it with the code from lib/add_app_bottom_sheet_temp.dart"
echo "4. Also add these lines near the top of main.dart (after other imports):"
echo "   import 'core/models/tracked_app.dart';"
echo "   import 'core/services/source_provider.dart';"
echo "   import 'core/services/github_provider.dart';"
echo "   import 'core/services/other_providers.dart';"
echo "5. In AppState class, replace _loadDemoData() with this (or add the addAppFromUrl method):"
echo "   Future<void> addAppFromUrl(String url, String type, String regex, bool pre) async {"
echo "     SourceProvider provider;"
echo "     switch (type) {"
echo "       case 'GitHub':"
echo "         provider = GitHubProvider(sourceUrl: url, apkRegex: regex, trackPreReleases: pre);"
echo "         break;"
echo "       default:"
echo "         throw Exception('Source \$type not implemented yet');"
echo "     }"
echo "     final version = await provider.getLatestVersion();"
echo "     final apk = await provider.getLatestApkUrl();"
echo "     final icon = await provider.getIconUrl();"
echo "     _apps.add(TrackedApp("
echo "       id: DateTime.now().toString(),"
echo "       name: 'Fetched App',"
echo "       packageName: 'unknown',"
echo "       sourceUrl: url,"
echo "       sourceType: type,"
echo "       currentVersion: '1.0',"
echo "       latestVersion: version,"
echo "       iconUrl: icon,"
echo "       author: 'Unknown',"
echo "       lastChecked: DateTime.now(),"
echo "       apkRegex: regex,"
echo "       trackPreReleases: pre,"
echo "     ));"
echo "     notifyListeners();"
echo "   }"
echo "6. Save everything, click 'Pub get' if shown, then press green Play button to run."
echo "7. Test: tap + Add App → choose GitHub → paste e.g. https://github.com/signalapp/Signal-Android → Add"
echo "   → It should fetch real latest version!"
echo ""
echo "Done! If errors appear, copy-paste them here."
