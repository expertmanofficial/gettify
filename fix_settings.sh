#!/usr/bin/env bash

echo "Fixing Settings + adding GitHub placeholders"
echo "Press Enter to start"
read -r

sed -i '/dependencies:/a \  shared_preferences: ^2.3.2\n  path_provider: ^2.1.5' pubspec.yaml

flutter pub get

sed -i '/import .*;/a import "package:shared_preferences/shared_preferences.dart";' lib/main.dart

sed -i '/class AppState extends ChangeNotifier {/a \
  int _checkInterval = 6;\
  bool _wifiOnly = false;\
  \
  int get checkInterval => _checkInterval;\
  bool get wifiOnly => _wifiOnly;\
  \
  Future<void> loadSettings() async {\
    final prefs = await SharedPreferences.getInstance();\
    _checkInterval = prefs.getInt("checkInterval") ?? 6;\
    _wifiOnly = prefs.getBool("wifiOnly") ?? false;\
    notifyListeners();\
  }\
  \
  Future<void> setCheckInterval(int hours) async {\
    _checkInterval = hours;\
    final prefs = await SharedPreferences.getInstance();\
    prefs.setInt("checkInterval", hours);\
    notifyListeners();\
  }\
  \
  Future<void> setWifiOnly(bool val) async {\
    _wifiOnly = val;\
    final prefs = await SharedPreferences.getInstance();\
    prefs.setBool("wifiOnly", val);\
    notifyListeners();\
  }' lib/main.dart

sed -i '/AppState() {/a \  loadSettings();' lib/main.dart

cat > lib/settings_tab_temp.dart << 'EOF'
class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        return CustomScrollView(
          slivers: [
            const SliverAppBar.large(title: Text('Settings')),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          title: const Text('Check interval'),
                          trailing: Text('\${state.checkInterval} hours'),
                          onTap: () => showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Check every...'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [1, 6, 12, 24, 48].map((h) => RadioListTile<int>(
                                  title: Text('\$h hours'),
                                  value: h,
                                  groupValue: state.checkInterval,
                                  onChanged: (val) {
                                    state.setCheckInterval(val!);
                                    Navigator.pop(context);
                                  },
                                )).toList(),
                              ),
                            ),
                          ),
                        ),
                        SwitchListTile(
                          title: const Text('Check only on WiFi'),
                          subtitle: const Text('Avoid mobile data usage'),
                          value: state.wifiOnly,
                          onChanged: state.setWifiOnly,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.download),
                          title: const Text('Export apps'),
                          onTap: () async {
                            final dir = await getApplicationDocumentsDirectory();
                            final file = File('\${dir.path}/obtanium_apps.json');
                            await file.writeAsString(json.encode(state._apps.map((a) => a.toJson()).toList()));
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Exported!')));
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.upload),
                          title: const Text('Import apps'),
                          onTap: () async {
                            final dir = await getApplicationDocumentsDirectory();
                            final file = File('\${dir.path}/obtanium_apps.json');
                            if (await file.exists()) {
                              final jsonStr = await file.readAsString();
                              final list = json.decode(jsonStr) as List;
                              state._apps = list.map((j) => TrackedApp.fromJson(j)).toList();
                              state.notifyListeners();
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Imported!')));
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No export file found')));
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.code),
                          title: const Text('Source code'),
                          onTap: () async {
                            await launchUrl(Uri.parse('https://github.com/your_username/obtanium_continued'));
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.contact_mail),
                          title: const Text('Contact the team'),
                          onTap: () async {
                            await launchUrl(Uri.parse('https://x.com/imorisune'));
                          },
                        ),
                      ],
                    ),
                  ),
                ]),
              ),
            ],
          ),
        );
      },
    );
  }
}
EOF

sed -i '/class SettingsTab extends StatelessWidget {/,/}/d' lib/main.dart
cat lib/settings_tab_temp.dart >> lib/main.dart
rm lib/settings_tab_temp.dart

sed -i '/class TrackedApp {/a \
  Map<String, dynamic> toJson() => {\
    "id": id,\
    "name": name,\
    "packageName": packageName,\
    "sourceUrl": sourceUrl,\
    "sourceType": sourceType,\
    "currentVersion": currentVersion,\
    "latestVersion": latestVersion,\
    "iconUrl": iconUrl,\
    "author": author,\
    "lastChecked": lastChecked.toIso8601String(),\
    "apkRegex": apkRegex,\
    "trackPreReleases": trackPreReleases,\
  };\
  \
  factory TrackedApp.fromJson(Map<String, dynamic> json) => TrackedApp(\
    id: json["id"],\
    name: json["name"],\
    packageName: json["packageName"],\
    sourceUrl: json["sourceUrl"],\
    sourceType: json["sourceType"],\
    currentVersion: json["currentVersion"],\
    latestVersion: json["latestVersion"],\
    iconUrl: json["iconUrl"],\
    author: json["author"],\
    lastChecked: DateTime.parse(json["lastChecked"]),\
    apkRegex: json["apkRegex"],\
    trackPreReleases: json["trackPreReleases"],\
  );' lib/core/models/tracked_app.dart

sed -i '/import .*;/a import "package:path_provider/path_provider.dart";\nimport "dart:io";\nimport "dart:convert";\nimport "package:url_launcher/url_launcher.dart";' lib/main.dart

echo "Done! Now:"
echo "1. Restart Android Studio (File → Exit, then reopen project)"
echo "2. Run the app (green Play button)"
echo "3. Test Settings tab:"
echo "   - Tap 'Check interval' → choose time → it saves"
echo "   - Toggle 'Check only on WiFi' → it saves"
echo "   - Export → creates JSON file"
echo "   - Import → loads if file exists"
echo "   - 'Source code' → opens GitHub (edit URL in code)"
echo "   - 'Contact the team' → opens @imorisune on X"
echo ""
echo "If errors appear when running, copy-paste them here."
