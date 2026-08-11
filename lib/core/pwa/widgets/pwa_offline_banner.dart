import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../pwa_detector.dart';

/// Shows reconnect status when the device goes offline (web PWA focus).
class PwaOfflineBanner extends StatefulWidget {
  const PwaOfflineBanner({super.key, required this.child});

  final Widget child;

  @override
  State<PwaOfflineBanner> createState() => _PwaOfflineBannerState();
}

class _PwaOfflineBannerState extends State<PwaOfflineBanner> {
  bool _offline = false;
  bool _wasOffline = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) return;
    _offline = !pwaIsOnline();
    Connectivity().onConnectivityChanged.listen(_onConnectivity);
  }

  void _onConnectivity(List<ConnectivityResult> results) {
    final offline = results.every((r) => r == ConnectivityResult.none);
    if (mounted) {
      setState(() {
        _wasOffline = _offline && !offline;
        _offline = offline;
      });
      if (_wasOffline) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Back online — schedules will refresh.'),
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return widget.child;

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: _offline ? 40 : 0,
          child: _offline
              ? Material(
                  color: AppColors.textDark,
                  child: SafeArea(
                    bottom: false,
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.wifi_off_rounded,
                            size: 16,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Offline — showing cached schedule',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.95),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        Expanded(child: widget.child),
      ],
    );
  }
}
