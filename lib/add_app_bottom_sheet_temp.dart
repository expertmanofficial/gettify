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
