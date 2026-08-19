import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/widgets/admin_guard.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/pwa/pwa_config.dart';
import '../../../core/pwa/pwa_install_service.dart';

class DistributionScreen extends StatefulWidget {
  const DistributionScreen({super.key});

  @override
  State<DistributionScreen> createState() => _DistributionScreenState();
}

class _DistributionScreenState extends State<DistributionScreen>
    with SingleTickerProviderStateMixin {
  static const String apkDownloadUrl =
      'https://drive.google.com/uc?export=download&id=11UprwM3gdsQmaRUZQ84GHZoG3mMRa8iW';

  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return AdminGuard(
      child: Scaffold(
        backgroundColor: AppColors.offWhite,
        body: Column(
          children: [
            ScreenHeader(
              title: l10n.pick('Share the app', 'Distribuie aplicația'),
              topPadding: MediaQuery.paddingOf(context).top + 12,
              onBack: () => Navigator.pop(context),
            ),
            TabBar(
              controller: _tabController,
              labelColor: AppColors.primaryPink,
              unselectedLabelColor: AppColors.textLight,
              indicatorColor: AppColors.primaryPink,
              tabs: const [
                Tab(text: 'iPhone (PWA)', icon: Icon(Icons.phone_iphone, size: 20)),
                Tab(text: 'Android (APK)', icon: Icon(Icons.android, size: 20)),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildIosPwaTab(context),
                  _buildAndroidTab(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIosPwaTab(BuildContext context) {
    final pwaUrl = PwaConfig.installLandingUrl;
    final l10n = L10n.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        children: [
          _buildQRCard(
            title: l10n.pick(
              'Scan to install on iPhone',
              'Scanează ca să instalezi pe iPhone',
            ),
            subtitle: l10n.pick(
              'Open Safari → install tutorial → Add to Home Screen. No App Store.',
              'Deschide Safari → tutorial de instalare → Adaugă pe ecranul principal. Fără App Store.',
            ),
            data: pwaUrl,
            accent: AppColors.softBlue,
          ),
          const SizedBox(height: AppSpacing.xl),
          _buildInfoExpansionTile(
            l10n.pick('iPhone install steps', 'Pași de instalare pe iPhone'),
            Icons.phone_iphone,
            AppColors.softBlue,
            [
              l10n.pick(
                '1. The employee scans the QR with the Camera app.',
                '1. Angajatul scanează QR-ul cu aplicația Cameră.',
              ),
              l10n.pick(
                '2. Safari opens CafeFlow with the install instructions.',
                '2. Safari deschide CafeFlow cu instrucțiunile de instalare.',
              ),
              l10n.pick(
                '3. Tap Share → Add to Home Screen.',
                '3. Atinge Partajează → Adaugă pe ecranul principal.',
              ),
              l10n.pick(
                '4. Open CafeFlow from the new home-screen icon.',
                '4. Deschide CafeFlow de pe noua iconiță de pe ecran.',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildUrlRow(
            context,
            pwaUrl,
            l10n.pick('PWA install link', 'Link instalare PWA'),
          ),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton.icon(
            onPressed: () async {
              await PwaInstallService().resetInstallTutorial();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      l10n.pick(
                        'Install tutorial reset — it will show again on the next visit.',
                        'Tutorialul de instalare a fost resetat — apare din nou la următoarea vizită.',
                      ),
                    ),
                  ),
                );
              }
            },
            icon: const Icon(Icons.refresh),
            label: Text(
              l10n.pick(
                'Reset install tutorial (test)',
                'Resetează tutorialul de instalare (test)',
              ),
            ),
          ),
          if (kIsWeb) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.pick(
                'Update PwaConfig.hostingUrl after you publish to Firebase Hosting.',
                'Actualizează PwaConfig.hostingUrl după ce publici pe Firebase Hosting.',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.textLight),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAndroidTab(BuildContext context) {
    final l10n = L10n.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        children: [
          _buildQRCard(
            title: l10n.pick(
              'Scan to download the APK',
              'Scanează ca să descarci APK-ul',
            ),
            subtitle: l10n.pick(
              'Scan with your phone camera',
              'Scanează cu camera telefonului',
            ),
            data: apkDownloadUrl,
            accent: AppColors.softGreen,
          ),
          const SizedBox(height: AppSpacing.xl),
          _buildInfoExpansionTile(
            l10n.pick('Android guide', 'Ghid Android'),
            Icons.android,
            AppColors.softGreen,
            [
              l10n.pick(
                '1. Scan the QR and download the APK.',
                '1. Scanează QR-ul și descarcă APK-ul.',
              ),
              l10n.pick(
                '2. Open the file and tap Install.',
                '2. Deschide fișierul și atinge Instalează.',
              ),
              l10n.pick(
                '3. Allow unknown sources if asked.',
                '3. Permite surse necunoscute dacă ți se cere.',
              ),
              l10n.pick(
                '4. Follow the steps to the end.',
                '4. Urmează pașii până la final.',
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildPrimaryCTA(
            label: l10n.pick('Download APK directly', 'Descarcă APK-ul direct'),
            onPressed: () => _launchUrl(apkDownloadUrl),
          ),
        ],
      ),
    );
  }

  Widget _buildQRCard({
    required String title,
    required String subtitle,
    required String data,
    required Color accent,
  }) {
    return AppSurface(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textLight, fontSize: 12),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            ),
            child: QrImageView(
              data: data,
              version: QrVersions.auto,
              size: 220,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: AppColors.primaryPink,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUrlRow(BuildContext context, String url, String label) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.borderLight.withValues(alpha: 0.6)),
        boxShadow: AppShadows.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  url,
                  style: const TextStyle(fontSize: 12, color: AppColors.textDark),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 20),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: url));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    L10n.of(context).pick('Link copied', 'Link copiat'),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInfoExpansionTile(
    String title,
    IconData icon,
    Color color,
    List<String> steps,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.borderLight.withValues(alpha: 0.6)),
        boxShadow: AppShadows.sm,
      ),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.textDark.withValues(alpha: 0.7), size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: steps
                  .map(
                    (s) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        s,
                        style: const TextStyle(fontSize: 13, color: AppColors.textLight),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryCTA({
    required String label,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: AppColors.pinkGradient,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        boxShadow: AppShadows.coloredGlow(AppColors.primaryPink),
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.download, color: Colors.white),
        label: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final l10n = L10n.of(context);
    if (!await launchUrl(Uri.parse(url))) {
      throw Exception(
        '${l10n.pick('Could not open', 'Nu s-a putut deschide')} $url',
      );
    }
  }
}
