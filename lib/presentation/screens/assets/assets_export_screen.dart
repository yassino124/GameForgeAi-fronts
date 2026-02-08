import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';

class AssetsExportScreen extends StatelessWidget {
  final String url;

  const AssetsExportScreen({
    super.key,
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        centerTitle: true,
        title: const Text('Export ready'),
      ),
      body: Padding(
        padding: AppSpacing.paddingLarge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Unity ZIP is ready.',
              style: AppTypography.h3.copyWith(color: cs.onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              'Download it, unzip, and copy the Assets/ folder into your Unity project.',
              style: AppTypography.body2.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(AppBorderRadius.large),
                border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
              ),
              child: Text(url, style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant)),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final uri = Uri.parse(url);
                  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
                  if (!ok) {
                    await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
                  }
                },
                icon: const Icon(Icons.download),
                label: const Text('Download ZIP'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
