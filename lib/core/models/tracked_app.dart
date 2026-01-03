class TrackedApp {
  Map<String, dynamic> toJson() => {
    "id": id,
    "name": name,
    "packageName": packageName,
    "sourceUrl": sourceUrl,
    "sourceType": sourceType,
    "currentVersion": currentVersion,
    "latestVersion": latestVersion,
    "iconUrl": iconUrl,
    "author": author,
    "lastChecked": lastChecked.toIso8601String(),
    "apkRegex": apkRegex,
    "trackPreReleases": trackPreReleases,
  };
  
  factory TrackedApp.fromJson(Map<String, dynamic> json) => TrackedApp(
    id: json["id"],
    name: json["name"],
    packageName: json["packageName"],
    sourceUrl: json["sourceUrl"],
    sourceType: json["sourceType"],
    currentVersion: json["currentVersion"],
    latestVersion: json["latestVersion"],
    iconUrl: json["iconUrl"],
    author: json["author"],
    lastChecked: DateTime.parse(json["lastChecked"]),
    apkRegex: json["apkRegex"],
    trackPreReleases: json["trackPreReleases"],
  );
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
