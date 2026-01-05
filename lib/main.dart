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
            colorSchemeSeed: appState.useMaterialYou ? appState.themeColor : Colors.deepPurple,
            useMaterial3: appState.useMaterialYou,
            brightness: Brightness.light,
            fontFamily: appState.useSystemFont ? null : 'Roboto',
          ),
          darkTheme: ThemeData(
            colorSchemeSeed: appState.useMaterialYou ? appState.themeColor : Colors.deepPurple,
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
    id: json['id'] as String,
    name: json['name'] as String,
    author: json['author'] as String? ?? 'Unknown',
    iconUrl: json['iconUrl'] as String,
    currentVersion: json['currentVersion'] as String,
    latestVersion: json['latestVersion'] as String,
    sourceType: json['sourceType'] as String,
    lastChecked: DateTime.parse(json['lastChecked'] as String),
    lastUpdated: json['lastUpdated'] != null ? DateTime.parse(json['lastUpdated'] as String) : null,
    sourceUrl: json['sourceUrl'] as String? ?? '',
    packageName: json['packageName'] as String?,
    isInstalled: json['isInstalled'] as bool? ?? true,
  );
}

// ===================== APP STATE =====================
class AppState extends ChangeNotifier {
  List<TrackedApp> _apps = [];
  SharedPreferences? _prefs;

  // General
  bool removeUninstalled = false;
  bool allowParallelDownloads = false;
  bool shareWithAppVerifier = false;

  // Installation
  bool useShizuku = false;
  bool setPlayAsSource = false;

  // Source-specific
  String githubToken = '';
  String gitlabToken = '';
  String ghProxyInstance = '';

  // Appearance
  ThemeMode themeMode = ThemeMode.system;
  bool usePureBlackDarkTheme = false;
  bool useMaterialYou = true;
  Color themeColor = Colors.deepPurple;
  String appSortBy = 'Name/author';
  String appSortOrder = 'Ascending';
  String language = 'Follow system';
  bool useSystemFont = false;
  bool showSourceInAppView = false;
  bool pinUpdatesToTop = true;
  bool moveNonInstalledToBottom = false;
  bool groupByCategory = false;
  bool dontShowTrackOnlyWarnings = false;
  bool dontShowApkOriginWarnings = false;
  bool disablePageAnimations = false;
  bool reversePageAnimations = false;
  bool highlightTouchTargets = false;
  List<String> categories = [];

  // Updates
  int backgroundCheckInterval = 15;
  bool useForegroundService = false;
  bool enableBackgroundUpdates = true;
  bool disableUpdatesOnMobileData = true;
  bool disableUpdatesIfNotCharging = false;
  bool checkOnStartup = false;
  bool checkOnAppDetailOpen = false;
  bool onlyCheckInstalled = false;

  List<TrackedApp> get allApps {
    var apps = List<TrackedApp>.from(_apps);
    if (pinUpdatesToTop) {
      apps.sort((a, b) {
        if (a.hasUpdate && !b.hasUpdate) return -1;
        if (!a.hasUpdate && b.hasUpdate) return 1;
        return a.name.compareTo(b.name);
      });
    }
    if (moveNonInstalledToBottom) {
      apps.sort((a, b) {
        if (a.isInstalled && !b.isInstalled) return -1;
        if (!a.isInstalled && b.isInstalled) return 1;
        return 0;
      });
    }
    return apps;
  }

  List<TrackedApp> get appsWithUpdates => _apps.where((app) => app.hasUpdate).toList();

  Future<void> loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    removeUninstalled = _prefs!.getBool('removeUninstalled') ?? false;
    allowParallelDownloads = _prefs!.getBool('allowParallelDownloads') ?? false;
    shareWithAppVerifier = _prefs!.getBool('shareWithAppVerifier') ?? false;
    useShizuku = _prefs!.getBool('useShizuku') ?? false;
    setPlayAsSource = _prefs!.getBool('setPlayAsSource') ?? false;
    githubToken = _prefs!.getString('githubToken') ?? '';
    gitlabToken = _prefs!.getString('gitlabToken') ?? '';
    ghProxyInstance = _prefs!.getString('ghProxyInstance') ?? '';
    themeMode = ThemeMode.values[_prefs!.getInt('themeMode') ?? ThemeMode.system.index];
    usePureBlackDarkTheme = _prefs!.getBool('usePureBlackDarkTheme') ?? false;
    useMaterialYou = _prefs!.getBool('useMaterialYou') ?? true;
    final colorValue = _prefs!.getInt('themeColor') ?? Colors.deepPurple.value;
    themeColor = Color(colorValue);
    useSystemFont = _prefs!.getBool('useSystemFont') ?? false;
    showSourceInAppView = _prefs!.getBool('showSourceInAppView') ?? false;
    pinUpdatesToTop = _prefs!.getBool('pinUpdatesToTop') ?? true;
    moveNonInstalledToBottom = _prefs!.getBool('moveNonInstalledToBottom') ?? false;
    groupByCategory = _prefs!.getBool('groupByCategory') ?? false;
    dontShowTrackOnlyWarnings = _prefs!.getBool('dontShowTrackOnlyWarnings') ?? false;
    dontShowApkOriginWarnings = _prefs!.getBool('dontShowApkOriginWarnings') ?? false;
    disablePageAnimations = _prefs!.getBool('disablePageAnimations') ?? false;
    reversePageAnimations = _prefs!.getBool('reversePageAnimations') ?? false;
    highlightTouchTargets = _prefs!.getBool('highlightTouchTargets') ?? false;
    backgroundCheckInterval = _prefs!.getInt('backgroundCheckInterval') ?? 15;
    useForegroundService = _prefs!.getBool('useForegroundService') ?? false;
    enableBackgroundUpdates = _prefs!.getBool('enableBackgroundUpdates') ?? true;
    disableUpdatesOnMobileData = _prefs!.getBool('disableUpdatesOnMobileData') ?? true;
    disableUpdatesIfNotCharging = _prefs!.getBool('disableUpdatesIfNotCharging') ?? false;
    checkOnStartup = _prefs!.getBool('checkOnStartup') ?? false;
    checkOnAppDetailOpen = _prefs!.getBool('checkOnAppDetailOpen') ?? false;
    onlyCheckInstalled = _prefs!.getBool('onlyCheckInstalled') ?? false;

    final appsJson = _prefs!.getString('apps');
    if (appsJson != null) {
      final list = jsonDecode(appsJson) as List<dynamic>;
      _apps = list.map((e) => TrackedApp.fromJson(e as Map<String, dynamic>)).toList();
    }
    notifyListeners();
  }

  void _saveSetting(String key, dynamic value) {
    if (value is bool) {
      _prefs?.setBool(key, value);
    } else if (value is int) {
      _prefs?.setInt(key, value);
    } else if (value is String) {
      _prefs?.setString(key, value);
    }
  }

  void setRemoveUninstalled(bool v) {
    removeUninstalled = v;
    _saveSetting('removeUninstalled', v);
    notifyListeners();
  }

  void setAllowParallelDownloads(bool v) {
    allowParallelDownloads = v;
    _saveSetting('allowParallelDownloads', v);
    notifyListeners();
  }

  void setShareWithAppVerifier(bool v) {
    shareWithAppVerifier = v;
    _saveSetting('shareWithAppVerifier', v);
    notifyListeners();
  }

  void setUseShizuku(bool v) {
    useShizuku = v;
    _saveSetting('useShizuku', v);
    notifyListeners();
  }

  void setSetPlayAsSource(bool v) {
    setPlayAsSource = v;
    _saveSetting('setPlayAsSource', v);
    notifyListeners();
  }

  void setGithubToken(String v) {
    githubToken = v;
    _saveSetting('githubToken', v);
    notifyListeners();
  }

  void setGitlabToken(String v) {
    gitlabToken = v;
    _saveSetting('gitlabToken', v);
    notifyListeners();
  }

  void setGhProxyInstance(String v) {
    ghProxyInstance = v;
    _saveSetting('ghProxyInstance', v);
    notifyListeners();
  }

  void setThemeMode(ThemeMode v) {
    themeMode = v;
    _saveSetting('themeMode', v.index);
    notifyListeners();
  }

  void setUsePureBlackDarkTheme(bool v) {
    usePureBlackDarkTheme = v;
    _saveSetting('usePureBlackDarkTheme', v);
    notifyListeners();
  }

  void setUseMaterialYou(bool v) {
    useMaterialYou = v;
    _saveSetting('useMaterialYou', v);
    notifyListeners();
  }

  void setThemeColor(Color v) {
    themeColor = v;
    _saveSetting('themeColor', v.value);
    notifyListeners();
  }

  void setUseSystemFont(bool v) {
    useSystemFont = v;
    _saveSetting('useSystemFont', v);
    notifyListeners();
  }

  void setShowSourceInAppView(bool v) {
    showSourceInAppView = v;
    _saveSetting('showSourceInAppView', v);
    notifyListeners();
  }

  void setPinUpdatesToTop(bool v) {
    pinUpdatesToTop = v;
    _saveSetting('pinUpdatesToTop', v);
    notifyListeners();
  }

  void setMoveNonInstalledToBottom(bool v) {
    moveNonInstalledToBottom = v;
    _saveSetting('moveNonInstalledToBottom', v);
    notifyListeners();
  }

  void setGroupByCategory(bool v) {
    groupByCategory = v;
    _saveSetting('groupByCategory', v);
    notifyListeners();
  }

  void setDontShowTrackOnlyWarnings(bool v) {
    dontShowTrackOnlyWarnings = v;
    _saveSetting('dontShowTrackOnlyWarnings', v);
    notifyListeners();
  }

  void setDontShowApkOriginWarnings(bool v) {
    dontShowApkOriginWarnings = v;
    _saveSetting('dontShowApkOriginWarnings', v);
    notifyListeners();
  }

  void setDisablePageAnimations(bool v) {
    disablePageAnimations = v;
    _saveSetting('disablePageAnimations', v);
    notifyListeners();
  }

  void setReversePageAnimations(bool v) {
    reversePageAnimations = v;
    _saveSetting('reversePageAnimations', v);
    notifyListeners();
  }

  void setHighlightTouchTargets(bool v) {
    highlightTouchTargets = v;
    _saveSetting('highlightTouchTargets', v);
    notifyListeners();
  }

  void setBackgroundCheckInterval(int v) {
    backgroundCheckInterval = v;
    _saveSetting('backgroundCheckInterval', v);
    notifyListeners();
  }

  void setUseForegroundService(bool v) {
    useForegroundService = v;
    _saveSetting('useForegroundService', v);
    notifyListeners();
  }

  void setEnableBackgroundUpdates(bool v) {
    enableBackgroundUpdates = v;
    _saveSetting('enableBackgroundUpdates', v);
    notifyListeners();
  }

  void setDisableUpdatesOnMobileData(bool v) {
    disableUpdatesOnMobileData = v;
    _saveSetting('disableUpdatesOnMobileData', v);
    notifyListeners();
  }

  void setDisableUpdatesIfNotCharging(bool v) {
    disableUpdatesIfNotCharging = v;
    _saveSetting('disableUpdatesIfNotCharging', v);
    notifyListeners();
  }

  void setCheckOnStartup(bool v) {
    checkOnStartup = v;
    _saveSetting('checkOnStartup', v);
    notifyListeners();
  }

  void setCheckOnAppDetailOpen(bool v) {
    checkOnAppDetailOpen = v;
    _saveSetting('checkOnAppDetailOpen', v);
    notifyListeners();
  }

  void setOnlyCheckInstalled(bool v) {
    onlyCheckInstalled = v;
    _saveSetting('onlyCheckInstalled', v);
    notifyListeners();
  }

  Future<void> addAppFromSource(String url, String sourceType) async {
    try {
      if (sourceType == 'GitHub') {
        final uri = Uri.parse(url);
        final parts = uri.pathSegments;
        if (parts.length < 2) throw Exception('Invalid GitHub URL');

        final owner = parts[0];
        final repo = parts[1];

        final response = await http.get(
          Uri.parse('https://api.github.com/repos/$owner/$repo/releases/latest'),
          headers: githubToken.isNotEmpty ? {'Authorization': 'token $githubToken'} : {},
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final app = TrackedApp(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: repo,
            author: owner,
            iconUrl: '📦',
            currentVersion: data['tag_name'] as String,
            latestVersion: data['tag_name'] as String,
            sourceType: 'GitHub',
            lastChecked: DateTime.now(),
            sourceUrl: url,
          );
          _apps.add(app);
          await _saveApps();
          notifyListeners();
        }
      }
      // Add other source implementations here
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
      final list = jsonDecode(jsonStr) as List<dynamic>;
      _apps = list.map((e) => TrackedApp.fromJson(e as Map<String, dynamic>)).toList();
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
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          PopupMenuButton<String>(
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'refresh', child: Text('Check for updates')),
              const PopupMenuItem(value: 'sort', child: Text('Sort')),
            ],
          ),
        ],
      ),
      body: apps.isEmpty
          ? const Center(
        child: Text(
          'No apps added.\nTap "Add app" to get started.',
          textAlign: TextAlign.center,
        ),
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
    return ListTile(
      leading: CircleAvatar(child: Text(app.iconUrl, style: const TextStyle(fontSize: 24))),
      title: Text(app.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('By ${app.author}'),
          Text(
            '${app.currentVersion} • ${DateFormat('yyyy-MM-dd').format(app.lastChecked)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      trailing: app.hasUpdate ? Icon(Icons.arrow_downward, color: Theme.of(context).colorScheme.primary) : null,
      onTap: () => showModalBottomSheet(context: context, builder: (_) => AppDetailsSheet(app: app)),
      onLongPress: () => showModalBottomSheet(
        context: context,
        builder: (_) => SafeArea(
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
          ListTile(title: const Text('Current version'), subtitle: Text(app.currentVersion)),
          ListTile(title: const Text('Latest version'), subtitle: Text(app.latestVersion)),
          ListTile(title: const Text('Source'), subtitle: Text(app.sourceType)),
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
  final _searchController = TextEditingController();
  final String _selectedSource = 'GitHub';
  bool _isLoading = false;
  String? _error;

  final List<String> _supportedSources = [
    'GitHub (searchable)',
    'GitLab (searchable)',
    'Forgejo (Codeberg) (searchable)',
    'F-Droid official (searchable)',
    'F-Droid third-party repo (searchable)',
    'IzzyOnDroid',
    'SourceHut',
    'APKPure',
    'Aptoide',
    'Uptodown',
    'Huawei AppGallery',
    'Tencent App Store',
    'CoolApk',
    'LiteAPKs',
    'vivo App Store (CN) (searchable)',
    'Jenkins',
    'APKMirror (track-only)',
    'RuStore',
    'Farsroid',
    'Telegram App',
    'NeutronCode',
    'Direct APK link',
    'HTML',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add app')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    decoration: InputDecoration(
                      labelText: 'App source URL *',
                      hintText: 'https://github.com/owner/repo',
                      border: const OutlineInputBorder(),
                      errorText: _error,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _isLoading ? null : _addApp,
                  child: _isLoading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Search (some sources only)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: () {}, child: const Text('Search')),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Supported sources'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _supportedSources.map((s) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(s),
                      )).toList(),
                    ),
                  ),
                  actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Okay'))],
                ),
              ),
              child: const Text('Supported sources'),
            ),
            TextButton(
              onPressed: () => launchUrl(Uri.parse('https://apps.obtainium.imranr.dev/')),
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
      await context.read<AppState>().addAppFromSource(_urlController.text, _selectedSource);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('App added successfully')));
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
    _searchController.dispose();
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
            OutlinedButton(onPressed: () {}, child: const Text('Pick export directory')),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () async {
                await context.read<AppState>().exportApps();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Apps exported')));
                }
              },
              child: const Text('Gettify export'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () async {
                await context.read<AppState>().importApps();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Apps imported')));
                }
              },
              child: const Text('Gettify import'),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            const Text('Search source', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: () {}, child: const Text('Import from URL list')),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: () {}, child: const Text('Import from URLs in file (like OPML)')),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: () {}, child: const Text('Import GitHub starred repositories')),
            const SizedBox(height: 24),
            const Text(
              'Imported apps may incorrectly show as "not installed". To fix this, re-install them through Gettify. This should not affect app data.\n\nOnly affects URL and third-party import methods.',
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
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // General
          const SettingsHeader('General'),
          SettingsSwitch('Automatically remove externally uninstalled apps', state.removeUninstalled, state.setRemoveUninstalled),
          SettingsSwitch('Allow parallel downloads', state.allowParallelDownloads, state.setAllowParallelDownloads),
          SettingsSwitch('Share new apps with AppVerifier (if available)', state.shareWithAppVerifier, state.setShareWithAppVerifier, subtitle: 'About'),

          // Installation
          const Divider(),
          const SettingsHeader('Installation'),
          SettingsSwitch('Use Shizuku or Sui to install', state.useShizuku, state.setUseShizuku),
          SettingsSwitch('Set Google Play as the installation source (if Shizuku is used)', state.setPlayAsSource, state.setSetPlayAsSource),

          // Source-specific
          const Divider(),
          const SettingsHeader('Source-specific'),
          SettingsTextField('GitHub personal access token (increases rate limit)', state.githubToken, state.setGithubToken, subtitle: 'About'),
          SettingsTextField('gh-proxy.org', state.ghProxyInstance, state.setGhProxyInstance,
              hint: '\'sky22333/hubproxy\' instance for GitHub requests', subtitle: 'About'),
          SettingsTextField('GitLab personal access token', state.gitlabToken, state.setGitlabToken, subtitle: 'About'),

          // Appearance
          const Divider(),
          const SettingsHeader('Appearance'),
          SettingsDropdown(
            'Theme',
            ['Follow system', 'Light', 'Dark'],
            state.themeMode == ThemeMode.system ? 'Follow system' : state.themeMode == ThemeMode.light ? 'Light' : 'Dark',
                (v) => state.setThemeMode(v == 'Follow system' ? ThemeMode.system : v == 'Light' ? ThemeMode.light : ThemeMode.dark),
          ),
          SettingsSwitch('Use pure black dark theme', state.usePureBlackDarkTheme, state.setUsePureBlackDarkTheme),
          SettingsSwitch('Use Material You', state.useMaterialYou, state.setUseMaterialYou),
          if (state.useMaterialYou) ColorPickerTile(state.themeColor, state.setThemeColor),
          SettingsDropdown('App sort by', ['Name/author', 'Last updated'], state.appSortBy, (v) {}),
          SettingsDropdown('App sort order', ['Ascending', 'Descending'], state.appSortOrder, (v) {}),
          SettingsDropdown('Language', ['Follow system', 'English', 'Spanish', 'French'], state.language, (v) {}),
          SettingsSwitch('Use the system font', state.useSystemFont, state.setUseSystemFont),
          SettingsSwitch('Show source webpage in app view', state.showSourceInAppView, state.setShowSourceInAppView),
          SettingsSwitch('Pin updates to top of apps view', state.pinUpdatesToTop, state.setPinUpdatesToTop),
          SettingsSwitch('Move non-installed apps to bottom of apps view', state.moveNonInstalledToBottom, state.setMoveNonInstalledToBottom),
          SettingsSwitch('Group by category', state.groupByCategory, state.setGroupByCategory),
          SettingsSwitch('Don\'t show \'track-only\' warnings', state.dontShowTrackOnlyWarnings, state.setDontShowTrackOnlyWarnings),
          SettingsSwitch('Don\'t show APK origin warnings', state.dontShowApkOriginWarnings, state.setDontShowApkOriginWarnings),
          SettingsSwitch('Disable page transition animations', state.disablePageAnimations, state.setDisablePageAnimations),
          SettingsSwitch('Reverse page transition animations', state.reversePageAnimations, state.setReversePageAnimations),
          SettingsSwitch('Highlight less obvious touch targets', state.highlightTouchTargets, state.setHighlightTouchTargets),

          // Updates
          const Divider(),
          const SettingsHeader('Updates'),
          SettingsSlider(
            'Background update checking interval: ${state.backgroundCheckInterval} minutes',
            state.backgroundCheckInterval.toDouble(),
            15,
            360,
            23,
                (v) => state.setBackgroundCheckInterval(v.toInt()),
          ),
          SettingsSwitch('Use a foreground service for update checking (more reliable, consumes more power)',
              state.useForegroundService, state.setUseForegroundService),
          SettingsSwitch('Enable background updates', state.enableBackgroundUpdates, state.setEnableBackgroundUpdates,
              subtitle: 'Background updates may not be possible for all apps. The success of a background install can only be determined when Obtainium is opened.'),
          SettingsSwitch('Disable background updates when not on Wi-Fi', state.disableUpdatesOnMobileData, state.setDisableUpdatesOnMobileData),
          SettingsSwitch('Disable background updates when not charging', state.disableUpdatesIfNotCharging, state.setDisableUpdatesIfNotCharging),
          SettingsSwitch('Check for updates on startup', state.checkOnStartup, state.setCheckOnStartup),
          SettingsSwitch('Check for updates on opening an app detail page', state.checkOnAppDetailOpen, state.setCheckOnAppDetailOpen),
          SettingsSwitch('Only check installed and track-only apps for updates', state.onlyCheckInstalled, state.setOnlyCheckInstalled),

          // About
          const Divider(),
          const SettingsHeader('About'),
          SettingsTile('Version', onTap: () => _showVersionInfo(context)),
          SettingsTile('Source code', subtitle: 'View on GitHub', onTap: () => launchUrl(Uri.parse('https://github.com/expertmanofficial/gettify'))),
          SettingsTile('Contact team (imorisune)', subtitle: 'On X', onTap: () => launchUrl(Uri.parse('https://x.com/imorisune'))),
          SettingsTile('Contact team (ExpertPlus_)', subtitle: 'On X', onTap: () => launchUrl(Uri.parse('https://x.com/ExpertPlus_'))),
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
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
    }
  }
}

// ===================== SETTINGS WIDGETS =====================
class SettingsHeader extends StatelessWidget {
  final String title;
  const SettingsHeader(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class SettingsSwitch extends StatelessWidget {
  final String title;
  final bool value;
  final Function(bool) onChanged;
  final String? subtitle;

  const SettingsSwitch(this.title, this.value, this.onChanged, {this.subtitle, super.key});

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

class SettingsDropdown extends StatelessWidget {
  final String title;
  final List<String> items;
  final String value;
  final Function(String) onChanged;

  const SettingsDropdown(this.title, this.items, this.value, this.onChanged, {super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: DropdownButton<String>(
        value: value,
        isExpanded: true,
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: (v) => onChanged(v!),
      ),
    );
  }
}

class SettingsSlider extends StatelessWidget {
  final String title;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final Function(double) onChanged;

  const SettingsSlider(this.title, this.value, this.min, this.max, this.divisions, this.onChanged, {super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: Slider(
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        onChanged: onChanged,
      ),
    );
  }
}

class SettingsTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const SettingsTile(this.title, {this.subtitle, required this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      onTap: onTap,
    );
  }
}

class SettingsTextField extends StatelessWidget {
  final String title;
  final String value;
  final Function(String) onChanged;
  final String? hint;
  final String? subtitle;

  const SettingsTextField(this.title, this.value, this.onChanged, {this.hint, this.subtitle, super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hint != null) Text(hint!, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 8),
          TextField(
            controller: TextEditingController(text: value)..selection = TextSelection.collapsed(offset: value.length),
            onChanged: onChanged,
            decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () {},
              child: Text(
                subtitle!,
                style: TextStyle(color: Theme.of(context).colorScheme.primary, decoration: TextDecoration.underline),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ColorPickerTile extends StatelessWidget {
  final Color currentColor;
  final Function(Color) onColorChanged;

  const ColorPickerTile(this.currentColor, this.onColorChanged, {super.key});

  final Map<String, List<Color>> colorVariants = const {
    'Red': [Color(0xFFFFCDD2), Color(0xFFF44336), Color(0xFFD32F2F), Color(0xFFB71C1C), Color(0xFFFF5252)],
    'Pink': [Color(0xFFF8BBD0), Color(0xFFE91E63), Color(0xFFC2185B), Color(0xFF880E4F), Color(0xFFFF4081)],
    'Purple': [Color(0xFFE1BEE7), Color(0xFF9C27B0), Color(0xFF7B1FA2), Color(0xFF4A148C), Color(0xFFE040FB)],
    'Deep Purple': [Color(0xFFD1C4E9), Color(0xFF673AB7), Color(0xFF512DA8), Color(0xFF311B92), Color(0xFF7C4DFF)],
    'Indigo': [Color(0xFFC5CAE9), Color(0xFF3F51B5), Color(0xFF303F9F), Color(0xFF1A237E), Color(0xFF536DFE)],
    'Blue': [Color(0xFFBBDEFB), Color(0xFF2196F3), Color(0xFF1976D2), Color(0xFF0D47A1), Color(0xFF448AFF)],
    'Light Blue': [Color(0xFFB3E5FC), Color(0xFF03A9F4), Color(0xFF0288D1), Color(0xFF01579B), Color(0xFF40C4FF)],
    'Cyan': [Color(0xFFB2EBF2), Color(0xFF00BCD4), Color(0xFF0097A7), Color(0xFF006064), Color(0xFF18FFFF)],
    'Teal': [Color(0xFFB2DFDB), Color(0xFF009688), Color(0xFF00796B), Color(0xFF004D40), Color(0xFF64FFDA)],
    'Green': [Color(0xFFC8E6C9), Color(0xFF4CAF50), Color(0xFF388E3C), Color(0xFF1B5E20), Color(0xFF69F0AE)],
    'Light Green': [Color(0xFFDCEDC8), Color(0xFF8BC34A), Color(0xFF689F38), Color(0xFF33691E), Color(0xFFB2FF59)],
    'Lime': [Color(0xFFF0F4C3), Color(0xFFCDDC39), Color(0xFFAFB42B), Color(0xFF827717), Color(0xFFEEFF41)],
    'Yellow': [Color(0xFFFFF9C4), Color(0xFFFFEB3B), Color(0xFFFBC02D), Color(0xFFF57F17), Color(0xFFFFFF00)],
    'Amber': [Color(0xFFFFECB3), Color(0xFFFFC107), Color(0xFFFFA000), Color(0xFFFF6F00), Color(0xFFFFD740)],
    'Orange': [Color(0xFFFFE0B2), Color(0xFFFF9800), Color(0xFFF57C00), Color(0xFFE65100), Color(0xFFFFAB40)],
    'Deep Orange': [Color(0xFFFFCCBC), Color(0xFFFF5722), Color(0xFFE64A19), Color(0xFFBF360C), Color(0xFFFF6E40)],
    'Brown': [Color(0xFFD7CCC8), Color(0xFF795548), Color(0xFF5D4037), Color(0xFF3E2723), Color(0xFFA1887F)],
    'Grey': [Color(0xFFF5F5F5), Color(0xFF9E9E9E), Color(0xFF616161), Color(0xFF212121), Color(0xFFBDBDBD)],
    'Blue Grey': [Color(0xFFCFD8DC), Color(0xFF607D8B), Color(0xFF455A64), Color(0xFF263238), Color(0xFF90A4AE)],
  };

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: const Text('Theme color'),
      subtitle: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ...colorVariants.entries.map((entry) {
            return PopupMenuButton<Color>(
              child: CircleAvatar(backgroundColor: entry.value[1], radius: 16),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: entry.value[0],
                  child: Row(
                    children: [
                      CircleAvatar(backgroundColor: entry.value[0], radius: 12),
                      const SizedBox(width: 8),
                      Text('Light ${entry.key}'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: entry.value[1],
                  child: Row(
                    children: [
                      CircleAvatar(backgroundColor: entry.value[1], radius: 12),
                      const SizedBox(width: 8),
                      Text('Normal ${entry.key}'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: entry.value[2],
                  child: Row(
                    children: [
                      CircleAvatar(backgroundColor: entry.value[2], radius: 12),
                      const SizedBox(width: 8),
                      Text('Dark ${entry.key}'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: entry.value[3],
                  child: Row(
                    children: [
                      CircleAvatar(backgroundColor: entry.value[3], radius: 12),
                      const SizedBox(width: 8),
                      Text('Pure Dark ${entry.key}'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: entry.value[4],
                  child: Row(
                    children: [
                      CircleAvatar(backgroundColor: entry.value[4], radius: 12),
                      const SizedBox(width: 8),
                      Text('Special ${entry.key}'),
                    ],
                  ),
                ),
              ],
              onSelected: onColorChanged,
            );
          }).toList(),
          ElevatedButton(
            onPressed: () {}, // Custom color picker logic can be added later
            child: const Text('Custom'),
          ),
        ],
      ),
    );
  }
}