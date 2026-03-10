import 'package:flutter/material.dart';
import 'common/my_color.dart';

class FaqPage extends StatelessWidget {
  const FaqPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FAQ', style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: const [
          _FaqSection(title: 'General', items: _generalFaqs),
          SizedBox(height: 16),
          _FaqSection(title: 'Features & Usage', items: _featuresFaqs),
          SizedBox(height: 16),
          _FaqSection(title: 'Account & Access', items: _accountFaqs),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// FAQ Section
// ─────────────────────────────────────────────

class _FaqSection extends StatelessWidget {
  final String title;
  final List<_FaqItem> items;

  const _FaqSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final cardColor = Theme.of(context).cardTheme.color ??
        Theme.of(context).colorScheme.surface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: Mycolor.secondary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
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
          ),
        ),
        // FAQ items card
        Material(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          elevation: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Column(
              children: [
                for (int i = 0; i < items.length; i++) ...[
                  _FaqTile(item: items[i]),
                  if (i < items.length - 1)
                    Divider(height: 1, indent: 16, endIndent: 16),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// FAQ Expandable Tile
// ─────────────────────────────────────────────

class _FaqTile extends StatefulWidget {
  final _FaqItem item;
  const _FaqTile({required this.item});

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    widget.item.question,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.keyboard_arrow_down,
                      size: 20, color: primary),
                ),
              ],
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  widget.item.answer,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                  ),
                ),
              ),
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Data model & content
// ─────────────────────────────────────────────

class _FaqItem {
  final String question;
  final String answer;
  const _FaqItem(this.question, this.answer);
}

const _generalFaqs = [
  _FaqItem(
    'What is Cubehous?',
    'Cubehous is a cloud-based platform designed to streamline sales processes and warehouse management. It offers comprehensive tools for inventory tracking, order management, sales analytics, and more to help businesses operate more efficiently.',
  ),
  _FaqItem(
    'How do I access Cubehous?',
    'Cubehous can be accessed via a web browser on your computer or by downloading the Cubehous app from the Apple App Store for iOS devices and the Google Play Store for Android devices.',
  ),
  _FaqItem(
    'How do I create an account on Cubehous?',
    'To create an account, visit the Cubehous website (www.cubehous.com) or open the app and click on the "Sign Up" button. Follow the prompts to enter your business details, email address, and create a password.',
  ),
  _FaqItem(
    'How does Cubehous ensure the security of my data?',
    'Cubehous uses advanced security measures, including encryption and secure data centers, to protect your data. We comply with industry standards and regulations to ensure your information is safe. For more details, please refer to our Privacy Policy.',
  ),
];

const _featuresFaqs = [
  _FaqItem(
    'Which kind of business needs this solution?',
    'Any kind of business that needs to manage stock in a warehouse in an organised and efficient way, and also wants to manage stock take, stock received, and issue sales bills in mobility.',
  ),
  _FaqItem(
    'Does this app integrate with other software or applications?',
    'Yes, Cubehous supports integration with popular accounting software like Autocount.',
  ),
  _FaqItem(
    'Can I use Cubehous on multiple devices?',
    'Yes, Cubehous is designed to work seamlessly across multiple devices. You can log in from your smartphone, tablet, or computer and access your data in real-time.',
  ),
];

const _accountFaqs = [
  _FaqItem(
    'What should I do if I forget my password?',
    'On the login page, click "Forgot Password" and enter your registered email address. You will receive an email with instructions to reset your password.',
  ),
  _FaqItem(
    'How do I contact support?',
    'You can reach our support team by calling +603 8068 2556 or emailing support@presoft.com.my. Our support hours are Monday to Friday, 9am to 6pm (MYT).',
  ),
];
