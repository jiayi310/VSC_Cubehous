import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'common/my_color.dart';
import 'faq.dart';

class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('About Us', style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Logo + app info ───────────────────────
            Container(
              padding: const EdgeInsets.symmetric(vertical: 28),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1E2F4A), Color(0xFF5B8FD4)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Image.asset(
                    'assests/images/logo.png',
                    height: 72,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.inventory_2_outlined,
                      size: 64,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Cubehous',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Version 1.0.0',
                    style: TextStyle(fontSize: 13, color: Colors.white60),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '© 2024 Presoft (M) Sdn. Bhd.',
                    style: TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Terms note ───────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primary.withValues(alpha: 0.15)),
              ),
              child: Text(
                'All rights reserved. The usage of this app indicates that you agree to be bound by our Terms and Conditions.',
                textAlign: TextAlign.justify,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 28),

            // ── Contact & Support ────────────────────
            _SectionHeader(title: 'Contact & Support', icon: Icons.support_agent),
            const SizedBox(height: 12),

            // Call support
            _ContactTile(
              icon: Icons.phone_outlined,
              label: 'Support Line',
              value: '+603 8068 2556',
              onTap: () => _launch(Uri(scheme: 'tel', path: '+60380682556')),
            ),
            const SizedBox(height: 10),

            // Email support
            _ContactTile(
              icon: Icons.email_outlined,
              label: 'Support Email',
              value: 'support@presoft.com.my',
              onTap: () => _launch(Uri(
                scheme: 'mailto',
                path: 'support@presoft.com.my',
                query: 'subject=Cubehous App Support',
              )),
            ),
            const SizedBox(height: 10),

            // Website
            _ContactTile(
              icon: Icons.language_outlined,
              label: 'Website',
              value: 'www.cubehous.com',
              isLink: true,
              onTap: () => _launch(Uri.parse('https://cubehous.com')),
            ),
            const SizedBox(height: 28),

            // ── FAQ ──────────────────────────────────
            _SectionHeader(title: 'Help & FAQ', icon: Icons.help_outline),
            const SizedBox(height: 12),

            _NavigationTile(
              icon: Icons.quiz_outlined,
              title: 'Frequently Asked Questions',
              subtitle: 'Find answers to common questions',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FaqPage()),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _launch(Uri uri) async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

// ─────────────────────────────────────────────
// Section header
// ─────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        Icon(icon, size: 18, color: primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: primary,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Contact tile
// ─────────────────────────────────────────────

class _ContactTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final bool isLink;

  const _ContactTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.isLink = false,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = Theme.of(context).cardTheme.color ??
        Theme.of(context).colorScheme.surface;
    final primary = Theme.of(context).colorScheme.primary;

    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(14),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primary.withValues(alpha: 0.10),
                ),
                child: Icon(icon, size: 20, color: primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isLink ? Colors.blue.shade600 : null,
                        decoration:
                            isLink ? TextDecoration.underline : null,
                        decorationColor: Colors.blue.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  size: 20,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.3)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Navigation tile (e.g. FAQ)
// ─────────────────────────────────────────────

class _NavigationTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _NavigationTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = Theme.of(context).cardTheme.color ??
        Theme.of(context).colorScheme.surface;

    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(14),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Mycolor.secondary.withValues(alpha: 0.12),
                ),
                child: Icon(icon, size: 20, color: Mycolor.secondary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.3)),
            ],
          ),
        ),
      ),
    );
  }
}
