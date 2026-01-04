// IMPORTANT: Make sure your pubspec.yaml has these packages, then run 'flutter pub get'
//
// dependencies:
//   flutter:
//     sdk: flutter
//   provider: ^6.1.2
//   http: ^1.2.1
//   path_provider: ^2.1.3
//   url_launcher: ^6.3.0

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

// ===================== MAIN & APP SETUP =====================

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => AppState(),
      child: const MainApp(),
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorSchemeSeed: Colors.blue,
            useMaterial3: true,
            brightness: Brightness.light,
          ),
          darkTheme: ThemeData(
            colorSchemeSeed: Colors.blue,
            useMaterial3: true,
            brightness: Brightness.dark,
          ),
          themeMode: appState.themeMode,
          home: const HomeScreen(),
        );
      },
    );
  }
}

// ===================== DATA MODELS & STATE =====================

class TrackedApp {
  final String id;
  final String name;
  final String author;
  final String iconUrl;
  final String currentVersion;
  final String latestVersion;
  final String sourceType;
  final DateTime lastChecked;
  final bool hasUpdate;
  final String sourceUrl;
  final String? packageName;
  final String? apkRegex;
  final bool? trackPreReleases;

  TrackedApp({
    required this.id,
    required this.name,
    this.author = 'Unknown Author',
    required this.iconUrl,
    required this.currentVersion,
    required this.latestVersion,
    required this.sourceType,
    required this.lastChecked,
    this.sourceUrl = '',
    this.packageName,
    this.apkRegex,
    this.trackPreReleases,
  }) : hasUpdate = currentVersion != latestVersion;

  factory TrackedApp.fromJson(Map<String, dynamic> json) {
    return TrackedApp(
      id: json['id'] as String,
      name: json['name'] as String,
      author: json['author'] as String,
      iconUrl: json['iconUrl'] as String,
      currentVersion: json['currentVersion'] as String,
      latestVersion: json['latestVersion'] as String,
      sourceType: json['sourceType'] as String,
      lastChecked: DateTime.parse(json['lastChecked'] as String),
      sourceUrl: json['sourceUrl'] as String? ?? '',
      packageName: json['packageName'] as String?,
      apkRegex: json['apkRegex'] as String?,
      trackPreReleases: json['trackPreReleases'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'author': author,
      'iconUrl': iconUrl,
      'currentVersion': currentVersion,
      'latestVersion': latestVersion,
      'sourceType': sourceType,
      'lastChecked': lastChecked.toIso8601String(),
      'sourceUrl': sourceUrl,
      'packageName': packageName,
      'apkRegex': apkRegex,
      'trackPreReleases': trackPreReleases,
    };
  }
}

class AppState extends ChangeNotifier {
  List<TrackedApp> _apps = _demoApps;
  int checkInterval = 6;
  bool wifiOnly = true;
  ThemeMode themeMode = ThemeMode.system;

  List<TrackedApp> get allApps => _apps;

  List<TrackedApp> get appsWithUpdates =>
      _apps.where((app) => app.hasUpdate).toList();

  void setThemeMode(ThemeMode mode) {
    themeMode = mode;
    notifyListeners();
  }

  void setCheckInterval(int hours) {
    checkInterval = hours;
    notifyListeners();
  }

  void setWifiOnly(bool value) {
    wifiOnly = value;
    notifyListeners();
  }

  void importApps(List<TrackedApp> importedApps) {
    _apps = importedApps;
    notifyListeners();
  }

  Future<void> addAppFromUrl(String url, String type, String regex,
      bool pre) async {
    try {
      SourceProvider provider;
      switch (type) {
        case 'GitHub':
          provider = GitHubProvider(
              sourceUrl: url, apkRegex: regex, trackPreReleases: pre);
          break;
        default:
          debugPrint('Source $type not implemented yet');
          return;
      }
      final version = await provider.getLatestVersion();
      final icon = await provider.getIconUrl();
      final name = await provider.getAppName();

      _apps.add(TrackedApp(
        id: DateTime.now().toString(),
        name: name,
        packageName: 'unknown',
        sourceUrl: url,
        sourceType: type,
        currentVersion: '1.0',
        latestVersion: version,
        iconUrl: icon,
        author: 'Unknown',
        lastChecked: DateTime.now(),
        apkRegex: regex,
        trackPreReleases: pre,
      ));
      notifyListeners();
    } catch (e) {
      debugPrint("Error adding app: $e");
    }
  }
}

// ===================== SOURCE PROVIDER ABSTRACTION =====================

abstract class SourceProvider {
  Future<String> getLatestVersion();

  Future<String> getLatestApkUrl();

  Future<String> getIconUrl();

  Future<String> getAppName();
}

class GitHubProvider implements SourceProvider {
  final String sourceUrl;
  final String apkRegex;
  final bool trackPreReleases;

  GitHubProvider({required this.sourceUrl,
    required this.apkRegex,
    required this.trackPreReleases});

  String _getRepoPath() {
    final uri = Uri.parse(sourceUrl);
    if (uri.host != 'github.com') {
      throw Exception('Invalid GitHub URL: $sourceUrl');
    }
    if (uri.pathSegments.length >= 2) {
      return '${uri.pathSegments[0]}/${uri.pathSegments[1]}';
    }
    throw Exception('Invalid GitHub URL path: $sourceUrl');
  }

  Future<Map<String, dynamic>> _fetchLatestReleaseData() async {
    final repoPath = _getRepoPath();
    final releasesUrl =
    Uri.parse('https://api.github.com/repos/$repoPath/releases');
    final response = await http.get(releasesUrl);

    if (response.statusCode == 200) {
      final releases = jsonDecode(response.body) as List;
      if (releases.isEmpty) {
        throw Exception('No releases found for $repoPath');
      }

      final filteredReleases = trackPreReleases
          ? releases
          : releases.where((r) => r['prerelease'] == false).toList();
      if (filteredReleases.isEmpty) {
        throw Exception('No stable releases found for $repoPath');
      }
      return filteredReleases.first as Map<String, dynamic>;
    } else {
      throw Exception(
          'Failed to load releases for $repoPath: ${response.statusCode}');
    }
  }

  @override
  Future<String> getLatestVersion() async {
    final release = await _fetchLatestReleaseData();
    return release['tag_name'] as String;
  }

  @override
  Future<String> getLatestApkUrl() async {
    final release = await _fetchLatestReleaseData();
    final assets = release['assets'] as List;
    final regex = RegExp(apkRegex);

    final apkAsset = assets.firstWhere(
            (asset) => regex.hasMatch(asset['name'] as String),
        orElse: () =>
        throw Exception(
            'No APK found matching regex in the latest release'));

    return apkAsset['browser_download_url'] as String;
  }

  @override
  Future<String> getIconUrl() async {
    try {
      final repoPath = _getRepoPath();
      final repoUrl = Uri.parse('https://api.github.com/repos/$repoPath');
      final response = await http.get(repoUrl);
      if (response.statusCode == 200) {
        final repoData = jsonDecode(response.body) as Map<String, dynamic>;
        return repoData['owner']['avatar_url'] as String;
      }
    } catch (e) {
      debugPrint("Could not fetch repo icon: $e");
    }
    return '📦';
  }

  @override
  Future<String> getAppName() async {
    final repoPath = _getRepoPath();
    return repoPath
        .split('/')
        .last;
  }
}

// ===================== HOME SCREEN & NAVIGATION =====================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static final List<Widget> _widgetOptions = <Widget>[
    const AllAppsTab(),
    const UpdatesTab(),
    const SettingsTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton.extended(
        onPressed: () =>
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (context) => const AddAppBottomSheet(),
            ),
        icon: const Icon(Icons.add),
        label: const Text('Add App'),
      )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.apps_outlined),
            selectedIcon: Icon(Icons.apps),
            label: 'All Apps',
          ),
          NavigationDestination(
            icon: Icon(Icons.system_update_outlined),
            selectedIcon: Icon(Icons.system_update),
            label: 'Updates',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

// ===================== TABS =====================

class AllAppsTab extends StatelessWidget {
  const AllAppsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final apps = context
        .watch<AppState>()
        .allApps;
    return CustomScrollView(
      slivers: [
        const SliverAppBar.large(title: Text('All Apps')),
        if (apps.isEmpty)
          const SliverFillRemaining(
            child: EmptyState(
              icon: Icons.add_circle_outline,
              title: 'No apps added',
              subtitle: 'Tap the "Add App" button to start',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            sliver: SliverList.builder(
              itemCount: apps.length,
              itemBuilder: (context, index) =>
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AppCard(app: apps[index]),
                  ),
            ),
          ),
      ],
    );
  }
}

class UpdatesTab extends StatelessWidget {
  const UpdatesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final updates = context
        .watch<AppState>()
        .appsWithUpdates;
    return CustomScrollView(
      slivers: [
        const SliverAppBar.large(title: Text('Updates')),
        if (updates.isEmpty)
          const SliverFillRemaining(
            child: EmptyState(
              icon: Icons.check_circle_outline,
              title: 'All apps up to date',
              subtitle: "You're running the latest versions",
            ),
          )
        else
          ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.system_update),
                  label: Text('Update All (${updates.length})'),
                  style:
                  FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList.builder(
                itemCount: updates.length,
                itemBuilder: (context, index) =>
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AppCard(app: updates[index]),
                    ),
              ),
            ),
          ],
      ],
    );
  }
}

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

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
                      leading: const Icon(Icons.dark_mode_outlined),
                      title: const Text('Theme'),
                      trailing: Text(state.themeMode
                          .toString()
                          .split('.')
                          .last),
                      onTap: () =>
                          showDialog(
                            context: context,
                            builder: (_) =>
                                AlertDialog(
                                  title: const Text('Theme'),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: ThemeMode.values
                                        .map((t) =>
                                        RadioListTile<ThemeMode>(
                                          title: Text(t
                                              .toString()
                                              .split('.')
                                              .last),
                                          value: t,
                                          groupValue: state.themeMode,
                                          onChanged: (val) {
                                            if (val != null) {
                                              context
                                                  .read<AppState>()
                                                  .setThemeMode(val);
                                              Navigator.pop(context);
                                            }
                                          },
                                        ))
                                        .toList(),
                                  ),
                                ),
                          ),
                    ),
                    ListTile(
                      title: const Text('Check interval'),
                      trailing: Text('${state.checkInterval} hours'),
                      onTap: () =>
                          showDialog(
                            context: context,
                            builder: (_) =>
                                AlertDialog(
                                  title: const Text('Check every...'),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [1, 6, 12, 24, 48]
                                        .map((h) =>
                                        RadioListTile<int>(
                                          title: Text('$h hours'),
                                          value: h,
                                          groupValue: state.checkInterval,
                                          onChanged: (val) {
                                            if (val != null) {
                                              context
                                                  .read<AppState>()
                                                  .setCheckInterval(val);
                                              Navigator.pop(context);
                                            }
                                          },
                                        ))
                                        .toList(),
                                  ),
                                ),
                          ),
                    ),
                    SwitchListTile(
                      title: const Text('Check only on WiFi'),
                      subtitle: const Text('Avoid mobile data usage'),
                      value: state.wifiOnly,
                      onChanged: (value) =>
                          context.read<AppState>().setWifiOnly(value),
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
                        final messenger = ScaffoldMessenger.of(context);
                        final appState = context.read<AppState>();
                        try {
                          final dir =
                          await getApplicationDocumentsDirectory();
                          // FIX: Changed file name
                          final file = File('${dir.path}/Gettify_apps.json');
                          final jsonString = json.encode(
                              appState.allApps.map((a) => a.toJson()).toList());
                          await file.writeAsString(jsonString);

                          messenger.showSnackBar(SnackBar(
                              content: Text('Exported to ${file.path}')));
                        } catch (e) {
                          messenger.showSnackBar(
                              SnackBar(content: Text('Export failed: $e')));
                        }
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.upload),
                      title: const Text('Import apps'),
                      onTap: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final appState = context.read<AppState>();
                        try {
                          final dir = await getApplicationDocumentsDirectory();
                          // FIX: Changed file name
                          final file = File('${dir.path}/Gettify_apps.json');
                          if (await file.exists()) {
                            final jsonStr = await file.readAsString();
                            final list =
                            json.decode(jsonStr) as List<dynamic>;
                            final importedApps = list
                                .map((j) =>
                                TrackedApp.fromJson(
                                    j as Map<String, dynamic>))
                                .toList();
                            appState.importApps(importedApps);

                            messenger.showSnackBar(
                                const SnackBar(content: Text('Imported!')));
                          } else {
                            messenger.showSnackBar(const SnackBar(
                                content: Text('No export file found')));
                          }
                        } catch (e) {
                          messenger.showSnackBar(
                              SnackBar(content: Text('Import failed: $e')));
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
                    const ListTile(
                      leading: Icon(Icons.info_outline),
                      title: Text('Version'),
                      subtitle: Text('1.0.0'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.code),
                      title: const Text('Source code'),
                      onTap: () =>
                          launchUrl(
                            // FIX: Corrected URL
                              Uri.parse(
                                  'https://github.com/expertmanofficial/gettify'),
                              mode: LaunchMode.externalApplication),
                    ),
                    ListTile(
                      leading: const Icon(Icons.contact_mail),
                      title: const Text('Contact the team'),
                      onTap: () =>
                          launchUrl(
                              Uri.parse('https://x.com/imorisune'),
                              mode: LaunchMode.externalApplication),
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

// ===================== OTHER WIDGETS =====================

class AppDetailsScreen extends StatelessWidget {
  final TrackedApp app;

  const AppDetailsScreen({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNetworkIcon = app.iconUrl.startsWith('http');
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(title: Text(app.name)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  SizedBox(
                    width: 96,
                    height: 96,
                    child: isNetworkIcon
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.network(
                        app.iconUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) =>
                        const Icon(Icons.broken_image, size: 48),
                      ),
                    )
                        : Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Text(app.iconUrl,
                            style: const TextStyle(fontSize: 48)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(app.name,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(app.author,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 24),
                  if (app.hasUpdate)
                    FilledButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.system_update),
                      label: Text('Update to ${app.latestVersion}'),
                      style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 16)),
                    ),
                  const SizedBox(height: 32),
                  _InfoCard(
                      title: 'Current Version',
                      value: app.currentVersion,
                      icon: Icons.check_circle),
                  const SizedBox(height: 12),
                  _InfoCard(
                      title: 'Latest Version',
                      value: app.latestVersion,
                      icon: Icons.new_releases),
                  const SizedBox(height: 12),
                  _InfoCard(
                      title: 'Source',
                      value: app.sourceType,
                      icon: Icons.cloud),
                  const SizedBox(height: 12),
                  _InfoCard(
                      title: 'Last Checked',
                      value: _formatTime(app.lastChecked),
                      icon: Icons.schedule),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _InfoCard(
      {required this.title, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Text(value, style: theme.textTheme.titleMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppCard extends StatelessWidget {
  final TrackedApp app;

  const AppCard({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    final isNetworkIcon = app.iconUrl.startsWith('http');
    return Card(
      child: ListTile(
        onTap: () =>
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => AppDetailsScreen(app: app))),
        leading: SizedBox(
          width: 48,
          height: 48,
          child: isNetworkIcon
              ? ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              app.iconUrl,
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) => const Icon(Icons.broken_image),
            ),
          )
              : Container(
            decoration: BoxDecoration(
              color: Theme
                  .of(context)
                  .colorScheme
                  .primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
                child: Text(app.iconUrl,
                    style: const TextStyle(fontSize: 24))),
          ),
        ),
        title: Text(app.name),
        subtitle: Text('v${app.currentVersion}'),
        trailing: app.hasUpdate
            ? FilledButton(onPressed: () {}, child: const Text('Update'))
            : const SizedBox.shrink(),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const EmptyState({super.key,
    required this.icon,
    required this.title,
    required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: color.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
              title, style: theme.textTheme.titleLarge?.copyWith(color: color)),
          const SizedBox(height: 8),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: color.withOpacity(0.7))),
        ],
      ),
    );
  }
}

class AddAppBottomSheet extends StatefulWidget {
  const AddAppBottomSheet({super.key});

  @override
  State<AddAppBottomSheet> createState() => _AddAppBottomSheetState();
}

class _AddAppBottomSheetState extends State<AddAppBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  String _sourceType = 'GitHub';
  final _urlController = TextEditingController();
  final _regexController = TextEditingController(text: r'.*\.apk$');
  bool _preReleases = false;
  bool _isAdding = false;

  @override
  void dispose() {
    _urlController.dispose();
    _regexController.dispose();
    super.dispose();
  }

  Future<void> _addApp() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _isAdding = true);

    final appState = context.read<AppState>();
    final navigator = Navigator.of(context);

    await appState.addAppFromUrl(
      _urlController.text.trim(),
      _sourceType,
      _regexController.text.trim(),
      _preReleases,
    );

    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: MediaQuery
          .of(context)
          .viewInsets,
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add New App', style: Theme
                  .of(context)
                  .textTheme
                  .headlineSmall),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                value: _sourceType,
                isExpanded: true,
                decoration: const InputDecoration(
                    border: OutlineInputBorder(), labelText: 'Source Type'),
                items: const [
                  DropdownMenuItem(
                      value: 'GitHub', child: Text('GitHub Releases')),
                  DropdownMenuItem(value: 'GitLab', child: Text('GitLab')),
                  DropdownMenuItem(
                      value: 'Codeberg', child: Text('Codeberg / Forgejo')),
                  DropdownMenuItem(value: 'F-Droid', child: Text('F-Droid')),
                  DropdownMenuItem(
                      value: 'IzzyOnDroid', child: Text('IzzyOnDroid')),
                  DropdownMenuItem(value: 'APKPure', child: Text('APKPure')),
                  DropdownMenuItem(
                      value: 'APKMirror',
                      child: Text('APKMirror (track only)')),
                  DropdownMenuItem(
                      value: 'HTML', child: Text('HTML / Custom scraping')),
                ],
                onChanged: (val) => setState(() => _sourceType = val!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _urlController,
                decoration: const InputDecoration(
                    labelText: 'Source URL', border: OutlineInputBorder()),
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (value) {
                  if (value == null || value
                      .trim()
                      .isEmpty) {
                    return 'URL cannot be empty';
                  }
                  if (!value.startsWith('http://') &&
                      !value.startsWith('https://')) {
                    return 'Please enter a valid URL';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _regexController,
                decoration: const InputDecoration(
                    labelText: 'APK filename regex (optional)',
                    border: OutlineInputBorder()),
              ),
              SwitchListTile(
                title: const Text('Include pre-releases'),
                value: _preReleases,
                onChanged: (v) => setState(() => _preReleases = v),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 24),
              if (_isAdding)
                const Center(child: CircularProgressIndicator())
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel')),
                    const SizedBox(width: 8),
                    FilledButton(onPressed: _addApp, child: const Text('Add')),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===================== DEMO DATA =====================

final List<TrackedApp> _demoApps = [
  TrackedApp(
    id: 'signal',
    name: 'Signal',
    author: 'Signal Foundation',
    iconUrl: '🔒',
    currentVersion: '6.40.1',
    latestVersion: '6.41.0',
    sourceType: 'Website',
    lastChecked: DateTime.now().subtract(const Duration(hours: 2)),
  ),
  TrackedApp(
    id: 'bitwarden',
    name: 'Bitwarden',
    author: '8bit Solutions LLC',
    iconUrl: '🛡️',
    currentVersion: '2023.10.0',
    latestVersion: '2023.10.0',
    sourceType: 'GitHub',
    lastChecked: DateTime.now().subtract(const Duration(minutes: 45)),
  ),
  TrackedApp(
    id: 'revanced',
    name: 'ReVanced Manager',
    author: 'ReVanced Team',
    iconUrl: '🚀',
    currentVersion: '1.9.0',
    latestVersion: '1.9.5',
    sourceType: 'GitHub',
    lastChecked: DateTime.now().subtract(const Duration(days: 1)),
  ),
  TrackedApp(
    id: 'vlc',
    name: 'VLC for Android',
    author: 'VideoLAN',
    iconUrl: '🚦',
    currentVersion: '3.5.3',
    latestVersion: '3.5.3',
    sourceType: 'Website',
    lastChecked: DateTime.now().subtract(const Duration(hours: 12)),
  ),
];