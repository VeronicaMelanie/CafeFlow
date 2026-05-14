import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';

class DistributionScreen extends StatelessWidget {
  const DistributionScreen({Key? key}) : super(key: key);

  final String apkDownloadUrl = 'https://drive.google.com/uc?export=download&id=11UprwM3gdsQmaRUZQ84GHZoG3mMRa8iW';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _buildQRCard(),
                  const SizedBox(height: 32),
                  _buildInstructionSection(context),
                  const SizedBox(height: 40),
                  _buildPrimaryCTA(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 60, bottom: 24, left: 16, right: 24),
      decoration: const BoxDecoration(
        gradient: AppColors.pinkGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          const Text(
            'App Distribution',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildQRCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: AppColors.shadowColor, blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          const Text('Scan to Download', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          const Text('Scan this code with your mobile camera', style: TextStyle(color: AppColors.textLight, fontSize: 12)),
          const SizedBox(height: 24),
          QrImageView(
            data: apkDownloadUrl,
            version: QrVersions.auto,
            size: 220.0,
            eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppColors.primaryPink),
            dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: AppColors.textDark),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionSection(BuildContext context) {
    return Column(
      children: [
        _buildInfoExpansionTile(
          'Android Guide',
          Icons.android,
          AppColors.softGreen,
          [
            '1. Scan QR and download APK.',
            '2. Open file and tap "Install".',
            '3. Allow "Unknown Sources" if asked.',
            '4. Follow prompts to finish.',
          ],
        ),
        const SizedBox(height: 16),
        _buildInfoExpansionTile(
          'iOS Guide',
          Icons.apple,
          AppColors.softBlue,
          [
            '1. Use TestFlight or Ad-Hoc link.',
            '2. Trust developer in Settings.',
            '3. VPN & Device Management.',
          ],
        ),
      ],
    );
  }

  Widget _buildInfoExpansionTile(String title, IconData icon, Color color, List<String> steps) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.3), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: AppColors.textDark.withOpacity(0.7), size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: steps.map((s) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(s, style: const TextStyle(fontSize: 13, color: AppColors.textLight)),
              )).toList(),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildPrimaryCTA() {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        gradient: AppColors.pinkGradient,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: AppColors.primaryPink.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: ElevatedButton.icon(
        onPressed: () => _launchUrl(apkDownloadUrl),
        icon: const Icon(Icons.download, color: Colors.white),
        label: const Text('Download APK Directly', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    if (!await launchUrl(Uri.parse(url))) {
      throw Exception('Could not launch $url');
    }
  }
}
