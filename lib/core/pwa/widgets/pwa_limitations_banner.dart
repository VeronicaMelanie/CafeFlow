import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_shadows.dart';
import '../pwa_detector.dart';

/// Explains iOS PWA limitations (push, background) with dismiss option.
class PwaLimitationsBanner extends StatefulWidget {
  const PwaLimitationsBanner({super.key});

  @override
  State<PwaLimitationsBanner> createState() => _PwaLimitationsBannerState();
}

class _PwaLimitationsBannerState extends State<PwaLimitationsBanner> {
  bool _expanded = false;
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || _dismissed) return const SizedBox.shrink();
    if (!pwaIsIosDevice()) return const SizedBox.shrink();

    final l10n = L10n.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: AnimatedContainer(
        duration: AppMotion.normal,
        curve: AppMotion.easeOut,
        decoration: BoxDecoration(
          color: AppColors.softBlue.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: AppColors.softBlue.withValues(alpha: 0.5),
            width: 0.5,
          ),
          boxShadow: AppShadows.xs,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md + 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                        color: AppColors.textDark.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          l10n.pick(
                            'Notes about the iPhone app',
                            'Note despre aplicația iPhone',
                          ),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: AppColors.textLight.withValues(alpha: 0.8),
                        ),
                        onPressed: () => setState(() => _dismissed = true),
                      ),
                    ],
                  ),
                  if (_expanded) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _limitationRow(
                      l10n.pick('Push notifications', 'Notificări push'),
                      pwaIsStandalone()
                          ? l10n.pick(
                              'Limited on iOS PWA. Open the app for schedule updates.',
                              'Limitate pe iOS PWA. Deschide aplicația pentru actualizări de program.',
                            )
                          : l10n.pick(
                              'Install on the home screen; iOS web push support is limited.',
                              'Instalează pe ecranul de pornire; suportul iOS pentru web push este limitat.',
                            ),
                    ),
                    _limitationRow(
                      l10n.pick('Background updates', 'Actualizări în fundal'),
                      l10n.pick(
                        'The app updates when you open it. Keep the Safari PWA on the home screen.',
                        'Aplicația se actualizează când o deschizi. Păstrează PWA-ul Safari pe ecranul de pornire.',
                      ),
                    ),
                    _limitationRow(
                      l10n.pick('Storage', 'Stocare'),
                      l10n.pick(
                        'The schedule is saved locally; sign in again if the cache is cleared.',
                        'Programul este salvat local; autentifică-te din nou dacă cache-ul este șters.',
                      ),
                    ),
                  ] else
                    Text(
                      l10n.pick(
                        'Tap for info about iOS install and notifications',
                        'Apasă pentru info despre instalare și notificări iOS',
                      ),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textLight,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _limitationRow(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          ),
          Text(
            body,
            style: const TextStyle(fontSize: 11, color: AppColors.textLight),
          ),
        ],
      ),
    );
  }
}
