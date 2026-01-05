import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:intl/intl.dart';

// ===================== MAIN =====================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appState = AppState();
  await appState.loadSettings();
  runApp(
    ChangeNotifierProvider.value(
      value: appState,
      child: const GettifyApp(),
    ),
  );
}

class GettifyApp extends StatelessWidget {
  const GettifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorSchemeSeed: Colors.deepPurple,
            useMaterial3: appState.useMaterialYou,
            brightness: Brightness.light,
            fontFamily: appState.useSystemFont ? null : 'Roboto',
          ),
          darkTheme: ThemeData(
            colorSchemeSeed: Colors.deepPurple,
            useMaterial3: appState.useMaterialYou,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: appState.usePureBlackDarkTheme ? Colors.black : null,
          ),
          themeMode: appState.themeMode,
          home: const HomeScreen(),
        );
      },
    );
  }
}

// ===================== DATA MODELS =====================
class TrackedApp {
  final String id;
  final String name;
  final String author;
  final String iconUrl;
  final String currentVersion;
  final String latestVersion;
  final String sourceType;
  final DateTime lastChecked;
  final DateTime? lastUpdated;
  final bool hasUpdate;
  final String sourceUrl;
  final String? packageName;
  final bool isInstalled;

  TrackedApp({
    required this.id,
    required this.name,
    this.author = 'Unknown',
    required this.iconUrl,
    required this.currentVersion,
    required this.latestVersion,
    required this.sourceType,
    required this.lastChecked,
    this.lastUpdated,
    this.sourceUrl = '',
    this.packageName,
    this.isInstalled = true,
  }) : hasUpdate = currentVersion != latestVersion;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'author': author,
    'iconUrl': iconUrl,
    'currentVersion': currentVersion,
    'latestVersion': latestVersion,
    'sourceType': sourceType,
    'lastChecked': lastChecked.toIso8601String(),
    'lastUpdated': lastUpdated?.toIso8601String(),
    'sourceUrl': sourceUrl,
    'packageName': packageName,
    'isInstalled': isInstalled,
  };

  factory TrackedApp.fromJson(Map<String, dynamic> json) => TrackedApp(
    id: json['id'],
    name: json['name'],
    author: json['author'] ?? 'Unknown',
    iconUrl: json['iconUrl'],
    currentVersion: json['currentVersion'],
    latestVersion: json['latestVersion'],
    sourceType: json['sourceType'],
    lastChecked: DateTime.parse(json['lastChecked']),
    lastUpdated: json['lastUpdated'] != null ? DateTime.parse(json['lastUpdated']) : null,
    sourceUrl: json['sourceUrl'] ?? '',
    packageName: json['packageName'],
    isInstalled: json['isInstalled'] ?? true,
  );
}

// ===================== APP STATE =====================
class AppState extends ChangeNotifier {
  List<TrackedApp> _apps = [];
  SharedPreferences? _prefs;

  // Settings
  ThemeMode themeMode = ThemeMode.system;
  bool usePureBlackDarkTheme = false;
  bool useMaterialYou = true;
  bool useSystemFont = false;
  bool pinUpdatesToTop = true;
  int backgroundCheckInterval = 15;
  bool disableUpdatesOnMobileData = true;

  List<TrackedApp> get allApps {
    var apps = List<TrackedApp>.from(_apps);
    if (pinUpdatesToTop) {
      apps.sort((a, b) {
        if (a.hasUpdate && !b.hasUpdate) return -1;
        if (!a.hasUpdate && b.hasUpdate) return 1;
        return a.name.compareTo(b.name);
      });
    }
    return apps;
  }

  List<TrackedApp> get appsWithUpdates => _apps.where((app) => app.hasUpdate).toList();

  Future<void> loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    themeMode = ThemeMode.values[_prefs!.getInt('themeMode') ?? ThemeMode.system.index];
    usePureBlackDarkTheme = _prefs!.getBool('usePureBlackDarkTheme') ?? false;
    useMaterialYou = _prefs!.getBool('useMaterialYou') ?? true;
    useSystemFont = _prefs!.getBool('useSystemFont') ?? false;
    pinUpdatesToTop = _prefs!.getBool('pinUpdatesToTop') ?? true;
    backgroundCheckInterval = _prefs!.getInt('backgroundCheckInterval') ?? 15;
    disableUpdatesOnMobileData = _prefs!.getBool('disableUpdatesOnMobileData') ?? true;
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    themeMode = mode;
    _prefs?.setInt('themeMode', mode.index);
    notifyListeners();
  }

  void setUsePureBlackDarkTheme(bool value) {
    usePureBlackDarkTheme = value;
    _prefs?.setBool('usePureBlackDarkTheme', value);
    notifyListeners();
  }

  void setUseMaterialYou(bool value) {
    useMaterialYou = value;
    _prefs?.setBool('useMaterialYou', value);
    notifyListeners();
  }

  void setPinUpdatesToTop(bool value) {
    pinUpdatesToTop = value;
    _prefs?.setBool('pinUpdatesToTop', value);
    notifyListeners();
  }

  void setBackgroundCheckInterval(int value) {
    backgroundCheckInterval = value;
    _prefs?.setInt('backgroundCheckInterval', value);
    notifyListeners();
  }

  void setDisableUpdatesOnMobileData(bool value) {
    disableUpdatesOnMobileData = value;
    _prefs?.setBool('disableUpdatesOnMobileData', value);
    notifyListeners();
  }

  Future<void> addAppFromGitHub(String url) async {
    try {
      // Parse GitHub URL
      final uri = Uri.parse(url);
      final parts = uri.pathSegments;
      if (parts.length < 2) throw Exception('Invalid GitHub URL');

      final owner = parts[0];
      final repo = parts[1];

      // Fetch latest release
      final response = await http.get(
        Uri.parse('https://api.github.com/repos/$owner/$repo/releases/latest'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final app = TrackedApp(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: repo,
          author: owner,
          iconUrl: '📦',
          currentVersion: data['tag_name'],
          latestVersion: data['tag_name'],
          sourceType: 'GitHub',
          lastChecked: DateTime.now(),
          sourceUrl: url,
        );
        _apps.add(app);
        await _saveApps();
        notifyListeners();
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> exportApps() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/gettify_export.json');
    final json = jsonEncode(_apps.map((app) => app.toJson()).toList());
    await file.writeAsString(json);
  }

  Future<void> importApps() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/gettify_export.json');
    if (await file.exists()) {
      final jsonStr = await file.readAsString();
      final list = jsonDecode(jsonStr) as List;
      _apps = list.map((e) => TrackedApp.fromJson(e)).toList();
      await _saveApps();
      notifyListeners();
    }
  }

  Future<void> _saveApps() async {
    final json = jsonEncode(_apps.map((app) => app.toJson()).toList());
    await _prefs?.setString('apps', json);
  }

  void removeApp(String id) {
    _apps.removeWhere((app) => app.id == id);
    _saveApps();
    notifyListeners();
  }
}

// ===================== HOME SCREEN =====================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          AppsTab(),
          AddAppTab(),
          ImportExportTab(),
          SettingsTab(),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton.extended(
        onPressed: () => setState(() => _selectedIndex = 1),
        icon: const Icon(Icons.add),
        label: const Text('Add App'),
      )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.apps), label: 'Apps'),
          NavigationDestination(icon: Icon(Icons.add), label: 'Add app'),
          NavigationDestination(icon: Icon(Icons.import_export), label: 'Import/export'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

// ===================== APPS TAB =====================
class AppsTab extends StatelessWidget {
  const AppsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final apps = state.allApps;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Apps'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'refresh', child: Text('Check for updates')),
              const PopupMenuItem(value: 'sort', child: Text('Sort')),
            ],
          ),
        ],
      ),
      body: apps.isEmpty
          ? const Center(
        child: Text('No apps added.\nTap "Add app" to get started.', textAlign: TextAlign.center),
      )
          : ListView.builder(
        itemCount: apps.length,
        itemBuilder: (context, index) => AppListTile(app: apps[index]),
      ),
    );
  }
}

class AppListTile extends StatelessWidget {
  final TrackedApp app;

  const AppListTile({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd');

    return ListTile(
      leading: CircleAvatar(
        child: Text(app.iconUrl, style: const TextStyle(fontSize: 24)),
      ),
      title: Text(app.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('By ${app.author}'),
          const SizedBox(height: 4),
          Text(
            '${app.currentVersion} • ${dateFormat.format(app.lastChecked)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      trailing: app.hasUpdate
          ? Icon(Icons.arrow_downward, color: Theme.of(context).colorScheme.primary)
          : null,
      onTap: () => _showAppDetails(context),
      onLongPress: () => _showAppMenu(context),
    );
  }

  void _showAppDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => AppDetailsSheet(app: app),
    );
  }

  void _showAppMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Check for update'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Remove'),
              onTap: () {
                context.read<AppState>().removeApp(app.id);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class AppDetailsSheet extends StatelessWidget {
  final TrackedApp app;

  const AppDetailsSheet({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(app.name, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('By ${app.author}'),
          const SizedBox(height: 16),
          ListTile(
            title: const Text('Current version'),
            subtitle: Text(app.currentVersion),
          ),
          ListTile(
            title: const Text('Latest version'),
            subtitle: Text(app.latestVersion),
          ),
          ListTile(
            title: const Text('Source'),
            subtitle: Text(app.sourceType),
          ),
          const SizedBox(height: 16),
          if (app.hasUpdate)
            FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.download),
              label: const Text('Update'),
            ),
        ],
      ),
    );
  }
}

// ===================== ADD APP TAB =====================
class AddAppTab extends StatefulWidget {
  const AddAppTab({super.key});

  @override
  State<AddAppTab> createState() => _AddAppTabState();
}

class _AddAppTabState extends State<AddAppTab> {
  final _urlController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add app')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: 'App source URL *',
                hintText: 'https://github.com/owner/repo',
                border: const OutlineInputBorder(),
                errorText: _error,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _addApp,
                    child: _isLoading
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Text('Add'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () {},
                    child: const Text('Search'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {},
              child: const Text('Supported sources'),
            ),
            TextButton(
              onPressed: () {},
              child: const Text('Crowdsourced app configurations'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addApp() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await context.read<AppState>().addAppFromGitHub(_urlController.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('App added successfully')),
        );
        _urlController.clear();
      }
    } catch (e) {
      setState(() => _error = 'Failed to add app: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }
}

// ===================== IMPORT/EXPORT TAB =====================
class ImportExportTab extends StatelessWidget {
  const ImportExportTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import/export')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton(
              onPressed: () {},
              child: const Text('Pick export directory'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () async {
                await context.read<AppState>().exportApps();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Apps exported')),
                  );
                }
              },
              child: const Text('Gettify export'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () async {
                await context.read<AppState>().importApps();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Apps imported')),
                  );
                }
              },
              child: const Text('Gettify import'),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            const Text('Search source', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {},
              child: const Text('Import from URL list'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {},
              child: const Text('Import from URLs in file (like OPML)'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {},
              child: const Text('Import GitHub starred repositories'),
            ),
            const SizedBox(height: 24),
            const Text(
              'Imported apps may incorrectly show as "not installed". '
                  'To fix this, re-install them through Gettify. '
                  'This should not affect app data.\n\n'
                  'Only affects URL and third-party import methods.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}

// ===================== SETTINGS TAB =====================
class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const SettingsSection(title: 'Appearance'),
          SettingsDropdown(
            title: 'Theme',
            value: context.watch<AppState>().themeMode,
            items: const {
              ThemeMode.system: 'Follow system',
              ThemeMode.light: 'Light',
              ThemeMode.dark: 'Dark',
            },
            onChanged: (value) => context.read<AppState>().setThemeMode(value!),
          ),
          SettingsSwitch(
            title: 'Use pure black dark theme',
            value: context.watch<AppState>().usePureBlackDarkTheme,
            onChanged: (value) => context.read<AppState>().setUsePureBlackDarkTheme(value),
          ),
          SettingsSwitch(
            title: 'Use Material You',
            value: context.watch<AppState>().useMaterialYou,
            onChanged: (value) => context.read<AppState>().setUseMaterialYou(value),
          ),
          SettingsSwitch(
            title: 'Pin updates to top of apps view',
            value: context.watch<AppState>().pinUpdatesToTop,
            onChanged: (value) => context.read<AppState>().setPinUpdatesToTop(value),
          ),
          const Divider(),
          const SettingsSection(title: 'Updates'),
          SettingsSlider(
            title: 'Background update checking interval',
            subtitle: '${context.watch<AppState>().backgroundCheckInterval} minutes',
            value: context.watch<AppState>().backgroundCheckInterval.toDouble(),
            min: 15,
            max: 360,
            divisions: 23,
            onChanged: (value) => context.read<AppState>().setBackgroundCheckInterval(value.toInt()),
          ),
          SettingsSwitch(
            title: 'Disable background updates when not on Wi-Fi',
            value: context.watch<AppState>().disableUpdatesOnMobileData,
            onChanged: (value) => context.read<AppState>().setDisableUpdatesOnMobileData(value),
          ),
          const Divider(),
          const SettingsSection(title: 'About'),
          SettingsTile(
            title: 'Version',
            onTap: () => _showVersionInfo(context),
          ),
          SettingsTile(
            title: 'Source code',
            subtitle: 'View on GitHub',
            onTap: () => launchUrl(Uri.parse('https://github.com/expertmanofficial/gettify')),
          ),
          SettingsTile(
            title: 'Contact team',
            subtitle: 'On X',
            onTap: () => launchUrl(Uri.parse('https://x.com/imorisune')),
          ),
        ],
      ),
    );
  }

  Future<void> _showVersionInfo(BuildContext context) async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Version'),
          content: Text('${packageInfo.version} (${packageInfo.buildNumber})'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }
}

// ===================== SETTINGS WIDGETS =====================
class SettingsSection extends StatelessWidget {
  final String title;

  const SettingsSection({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class SettingsSwitch extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const SettingsSwitch({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      value: value,
      onChanged: onChanged,
    );
  }
}

class SettingsDropdown<T> extends StatelessWidget {
  final String title;
  final T value;
  final Map<T, String> items;
  final ValueChanged<T?> onChanged;

  const SettingsDropdown({
    super.key,
    required this.title,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: DropdownButton<T>(
        value: value,
        isExpanded: true,
        items: items.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
        onChanged: onChanged,
      ),
    );
  }
}

class SettingsSlider extends StatelessWidget {
  final String title;
  final String? subtitle;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  const SettingsSlider({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (subtitle != null) Text(subtitle!),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class SettingsTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const SettingsTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      onTap: onTap,
    );
  }
}