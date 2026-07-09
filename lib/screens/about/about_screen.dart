import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// One line of the version history's feature list — see [_features].
class _Feature {
  const _Feature(this.title, this.description);

  final String title;
  final String description;
}

/// Every feature shipping in the current build, in the same order (and
/// wording, condensed) as the README's Features section — keep the two in
/// sync when a feature is added, changed, or removed.
const _currentFeatures = [
  _Feature(
    'Dashboard',
    'At-a-glance stock levels, low-stock alerts, and recent activity.',
  ),
  _Feature(
    'Point of Sale',
    'Build a cart, apply discounts, checkout, and hold sales to resume later.',
  ),
  _Feature(
    'Products & Categories',
    'Full CRUD with photos, barcodes, and category-based organization. '
        'Searchable and filterable by category, with a tap-to-zoom photo '
        'viewer.',
  ),
  _Feature(
    'Stock In / Stock Out',
    'Record inventory movements with full history per product.',
  ),
  _Feature(
    'Barcode Scanning',
    'Use the camera to look up products or ring them up at checkout.',
  ),
  _Feature(
    'Reports',
    'Sales reports and receipts over a chosen date range, plus an Inventory '
        'Stock report by category — all exportable to Excel.',
  ),
  _Feature(
    'Backup & Restore',
    'Export the database and product photos to a zip file, with an optional '
        'auto backup schedule.',
  ),
  _Feature('App Lock', 'Optional 6-digit PIN gate on launch, hashed at rest.'),
];

/// App info screen: branding, a short description, and a version history
/// listing what shipped in each version (currently just the one).
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snapshot) {
          final info = snapshot.data;
          final version = info == null ? '—' : info.version;

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: Column(
                  children: [
                    Image.asset('assets/branding/splash_icon.png', height: 120),
                    const SizedBox(height: 16),
                    Text('SimpliPos', style: textTheme.headlineSmall),
                    const SizedBox(height: 4),
                    if (info != null)
                      Text(
                        'Version ${info.version} (${info.buildNumber})',
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'SimpliPos is a fully offline inventory and point-of-sale app '
                'for small shops. Everything — products, stock, sales, and '
                'reports — lives in a local database on the device, so it '
                'works with no internet connection and no backend to run.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              Text('Version History', style: textTheme.titleMedium),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'v$version',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (final feature in _currentFeatures)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                size: 18,
                                color: scheme.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      feature.title,
                                      style: textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      feature.description,
                                      style: textTheme.bodySmall?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  'Developed by: chadokx04:)',
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
