import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("About"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _AboutAppCard(),
            const SizedBox(height: 14),
            _AboutSectionCard(
              title: "Developer's Identity",
              children: [
                _AboutActionRow(
                  icon: Icons.language_rounded,
                  title: 'Portfolio',
                  subtitle: 'arabiislam.odoo.com',
                  onTap: () => _open('https://arabiislam.odoo.com'),
                ),
                const _AboutDivider(),
                _AboutActionRow(
                  icon: Icons.code_rounded,
                  title: 'GitHub',
                  subtitle: '@arabiislam46ar',
                  onTap: () => _open('https://github.com/arabiislam46ar'),
                ),
                const _AboutDivider(),
                _AboutActionRow(
                  icon: Icons.camera_alt_rounded,
                  title: 'Instagram',
                  subtitle: '@arabiislam46ar',
                  onTap: () => _open('https://instagram.com/arabiislam46ar'),
                ),
                const _AboutDivider(),
                _AboutActionRow(
                  icon: Icons.facebook_rounded,
                  title: 'Facebook',
                  subtitle: '@arabiislam46ar',
                  onTap: () => _open('https://facebook.com/arabiislam46ar'),
                ),
                const _AboutDivider(),
                _AboutActionRow(
                  icon: Icons.send_rounded,
                  title: 'Telegram',
                  // Matches the handle used in NexMusic-Android's About screen.
                  subtitle: '@arabiislam46r',
                  onTap: () => _open('https://t.me/arabiislam46r'),
                ),
                const _AboutDivider(),
                _AboutActionRow(
                  icon: Icons.forum_rounded,
                  title: 'Discord',
                  subtitle: 'arabiislam46ar',
                  // No public @username profile link on Discord (needs a
                  // numeric user ID for a direct link), same as Android.
                  onTap: null,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _AboutSectionCard(
              title: 'App',
              children: [
                _AboutActionRow(
                  icon: Icons.code_rounded,
                  title: 'GitHub',
                  subtitle: 'nexerisltd/NexMusic-Desktop',
                  onTap: () =>
                      _open('https://github.com/nexerisltd/NexMusic-Desktop'),
                ),
                const _AboutDivider(),
                _AboutActionRow(
                  icon: Icons.forum_rounded,
                  title: 'Discord',
                  subtitle: 'discord.gg/P44QdHPtKg',
                  onTap: () => _open('https://discord.gg/P44QdHPtKg'),
                ),
                const _AboutDivider(),
                _AboutActionRow(
                  icon: Icons.send_rounded,
                  title: 'Telegram',
                  subtitle: 't.me/nexappog',
                  onTap: () => _open('https://t.me/nexappog'),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _AboutAppCard extends StatelessWidget {
  const _AboutAppCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: Image.asset(
                'icons/nexmusic_nobg.png',
                width: 100,
                height: 100,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'NexMusic',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Developed by Arabi x ARX',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Version 5.2.89',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutSectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _AboutSectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 4),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _AboutActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _AboutActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: onTap,
      enabled: onTap != null,
    );
  }
}

class _AboutDivider extends StatelessWidget {
  const _AboutDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, indent: 56, endIndent: 16);
  }
}
