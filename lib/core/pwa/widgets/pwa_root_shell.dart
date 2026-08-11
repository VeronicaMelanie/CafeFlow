import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../pwa_detector.dart';
import '../pwa_install_service.dart';
import 'pwa_install_tutorial.dart';
import 'pwa_offline_banner.dart';

/// Wraps the app on web: install tutorial overlay, splash hide, scroll behavior.
class PwaRootShell extends StatefulWidget {
  const PwaRootShell({super.key, required this.child});

  final Widget child;

  @override
  State<PwaRootShell> createState() => _PwaRootShellState();
}

class _PwaRootShellState extends State<PwaRootShell> {
  bool _showInstallTutorial = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        pwaHideNativeSplash();
        _maybeShowInstallTutorial();
      });
    }
  }

  Future<void> _maybeShowInstallTutorial() async {
    final show = await PwaInstallService().shouldShowInstallTutorial();
    if (mounted && show) {
      setState(() => _showInstallTutorial = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return widget.child;

    return PwaOfflineBanner(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ScrollConfiguration(
            behavior: const _IosFriendlyScrollBehavior(),
            child: widget.child,
          ),
          if (_showInstallTutorial)
            PwaInstallTutorial(
              onDismiss: () => setState(() => _showInstallTutorial = false),
            ),
        ],
      ),
    );
  }
}

class _IosFriendlyScrollBehavior extends ScrollBehavior {
  const _IosFriendlyScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    );
  }
}
