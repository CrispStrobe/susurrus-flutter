import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// About / legal info screen — mirrors the layout used by our sibling
/// CrispSorter app: service provider, contact, disclaimer, then the
/// auto-aggregated open-source license list Flutter collects from every
/// pub dep via `LicenseRegistry`.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  static const _email = 'postmaster@crispstro.be';
  static const _phone = '+49 176 6421 8601';

  static const _disclaimer =
      'This software is provided "as is", without warranty of any kind, '
      'express or implied, including but not limited to the warranties of '
      'merchantability, fitness for a particular purpose and '
      'noninfringement. In no event shall the authors be liable for any '
      'claim, damages or other liability arising from, out of or in '
      'connection with the software or its use.';

  static const _privacy =
      'Susurrus processes all audio locally on your device. No audio data, '
      'transcripts, or recordings are sent to any server. Model downloads '
      'fetch GGUF weights directly from HuggingFace over HTTPS; nothing else '
      'leaves the device.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('About Susurrus')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _AppHeader(),
          const SizedBox(height: 12),
          _SectionCard(
            icon: Icons.business,
            label: 'Service Provider',
            child: const Text(_providerJoin),
          ),
          _SectionCard(
            icon: Icons.alternate_email,
            label: 'Contact',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () => _open('mailto:$_email'),
                  child: Text('Email: $_email',
                      style: const TextStyle(
                          color: Colors.blue,
                          decoration: TextDecoration.underline)),
                ),
                const SizedBox(height: 4),
                InkWell(
                  onTap: () => _open('tel:${_phone.replaceAll(' ', '')}'),
                  child: Text('Phone: $_phone',
                      style: const TextStyle(
                          color: Colors.blue,
                          decoration: TextDecoration.underline)),
                ),
              ],
            ),
          ),
          _SectionCard(
            icon: Icons.privacy_tip_outlined,
            label: 'Privacy',
            child: const Text(_privacy),
          ),
          _SectionCard(
            icon: Icons.gavel,
            label: 'Disclaimer',
            child: const Text(_disclaimer),
          ),
          _SectionCard(
            icon: Icons.copyright,
            label: 'License',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Susurrus is free software, licensed under the '
                  'GNU Affero General Public License v3.0 (AGPL-3.0). '
                  'You may redistribute and modify it under the terms of that '
                  'license. In particular, if you run a modified version of '
                  'Susurrus as a network service, you must make your source '
                  'code available to its users.',
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => _open('https://www.gnu.org/licenses/agpl-3.0.html'),
                  child: const Text(
                    'https://www.gnu.org/licenses/agpl-3.0.html',
                    style: TextStyle(
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            icon: const Icon(Icons.description_outlined),
            label: const Text('Open-source licenses'),
            onPressed: () async {
              final info = await PackageInfo.fromPlatform();
              if (!context.mounted) return;
              showLicensePage(
                context: context,
                applicationName: 'Susurrus',
                applicationVersion: '${info.version}+${info.buildNumber}',
                applicationLegalese:
                    '© ${DateTime.now().year} Christian Ströbele — AGPL-3.0',
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // Joined at compile time for the provider card.
  static const _providerJoin =
      'Christian Ströbele\nNikolausstr. 5\n70190 Stuttgart\nDeutschland / Germany';

  static Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}

class _AppHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snap) {
        final v = snap.hasData
            ? '${snap.data!.version} (${snap.data!.buildNumber})'
            : '…';
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.graphic_eq,
                    size: 28,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Susurrus',
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 4),
                      Text('Version $v',
                          style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 4),
                      Text(
                        'On-device speech recognition via ggml / CrispASR',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.label,
    required this.child,
  });

  final IconData icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
