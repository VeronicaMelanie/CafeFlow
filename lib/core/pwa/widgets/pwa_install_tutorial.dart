import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../l10n/l10n.dart';
import '../pwa_install_service.dart';

/// Step-by-step guide for installing CafeFlow on iPhone via Safari.
class PwaInstallTutorial extends StatefulWidget {
  const PwaInstallTutorial({
    super.key,
    required this.onDismiss,
  });

  final VoidCallback onDismiss;

  @override
  State<PwaInstallTutorial> createState() => _PwaInstallTutorialState();
}

class _PwaInstallTutorialState extends State<PwaInstallTutorial>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _dontShowAgain = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Material(
      color: Colors.black54,
      child: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: CurvedAnimation(parent: _controller, curve: Curves.easeOut),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.92, end: 1).animate(
                CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
              ),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                constraints: const BoxConstraints(maxWidth: 400),
                decoration: BoxDecoration(
                  color: AppColors.pureWhite,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadowColor,
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeader(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                      child: Column(
                        children: [
                          _InstallStep(
                            step: 1,
                            icon: Icons.ios_share_rounded,
                            title: l10n.pick(
                              'Tap Share in Safari',
                              'Apasă Share în Safari',
                            ),
                            subtitle: l10n.pick(
                              'Use the share icon at the bottom of the screen.',
                              'Folosește pictograma de partajare din partea de jos a ecranului.',
                            ),
                            delay: 0,
                            controller: _controller,
                          ),
                          const SizedBox(height: 16),
                          _InstallStep(
                            step: 2,
                            icon: Icons.add_box_outlined,
                            title: l10n.pick(
                              'Add to Home Screen',
                              'Adaugă pe ecranul de pornire',
                            ),
                            subtitle: l10n.pick(
                              'Scroll the menu and tap “Add to Home Screen”.',
                              'Derulează meniul și apasă „Adaugă pe ecranul de pornire”.',
                            ),
                            delay: 0.15,
                            controller: _controller,
                          ),
                          const SizedBox(height: 16),
                          _InstallStep(
                            step: 3,
                            icon: Icons.apps_rounded,
                            title: l10n.pick(
                              'Open from the home screen',
                              'Deschide de pe ecranul de pornire',
                            ),
                            subtitle: l10n.pick(
                              'Open CafeFlow like a native app — full screen, no browser bar.',
                              'Deschide CafeFlow ca o aplicație nativă — pe tot ecranul, fără bara browserului.',
                            ),
                            delay: 0.3,
                            controller: _controller,
                          ),
                        ],
                      ),
                    ),
                    _buildFooter(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final l10n = L10n.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.phone_iphone, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.pick(
              'Install CafeFlow on iPhone',
              'Instalează CafeFlow pe iPhone',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.pick(
              'No App Store needed — private install for the team.',
              'Nu e nevoie de App Store — instalare privată pentru echipă.',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    final l10n = L10n.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                height: 24,
                width: 24,
                child: Checkbox(
                  value: _dontShowAgain,
                  activeColor: AppColors.primaryPink,
                  onChanged: (v) => setState(() => _dontShowAgain = v ?? false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.pick("Don't show again", 'Nu mai afișa'),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textLight,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                if (_dontShowAgain) {
                  await PwaInstallService().dismissInstallTutorial();
                }
                widget.onDismiss();
              },
              child: Text(l10n.pick('Got it', 'Am înțeles')),
            ),
          ),
          TextButton(
            onPressed: () async {
              await PwaInstallService().dismissInstallTutorial();
              widget.onDismiss();
            },
            child: Text(
              l10n.pick('Continue in browser', 'Continuă în browser'),
              style: const TextStyle(color: AppColors.textLight),
            ),
          ),
        ],
      ),
    );
  }
}

class _InstallStep extends StatelessWidget {
  const _InstallStep({
    required this.step,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.delay,
    required this.controller,
  });

  final int step;
  final IconData icon;
  final String title;
  final String subtitle;
  final double delay;
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    final anim = CurvedAnimation(
      parent: controller,
      curve: Interval(delay, 0.6 + delay, curve: Curves.easeOut),
    );
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
            .animate(anim),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.softPink,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: AppColors.primaryPink, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$step. $title',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textLight,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
