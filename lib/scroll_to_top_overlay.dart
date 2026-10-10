import 'package:flutter/material.dart';

import 'app_design_system.dart';

class ScrollToTopNavigatorObserver extends NavigatorObserver {
  ScrollToTopNavigatorObserver({required this.onNavigationChanged});

  final VoidCallback onNavigationChanged;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _resetAfterFrame();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _resetAfterFrame();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _resetAfterFrame();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _resetAfterFrame();
  }

  void _resetAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) => onNavigationChanged());
  }
}

class ScrollToTopOverlayController {
  _ScrollToTopOverlayState? _state;

  void reset() => _state?.reset();
}

class ScrollToTopOverlay extends StatefulWidget {
  const ScrollToTopOverlay({
    super.key,
    required this.child,
    this.controller,
  });

  final Widget child;
  final ScrollToTopOverlayController? controller;

  @override
  State<ScrollToTopOverlay> createState() => _ScrollToTopOverlayState();
}

class _ScrollToTopOverlayState extends State<ScrollToTopOverlay> {
  static const _visibilityThreshold = 240.0;
  ScrollPosition? _scrollPosition;
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
  }

  @override
  void didUpdateWidget(covariant ScrollToTopOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (oldWidget.controller?._state == this) {
        oldWidget.controller?._state = null;
      }
      widget.controller?._state = this;
    }
  }

  @override
  void dispose() {
    if (widget.controller?._state == this) {
      widget.controller?._state = null;
    }
    super.dispose();
  }

  void reset() {
    if (!mounted) return;
    setState(() {
      _scrollPosition = null;
      _isVisible = false;
    });
  }

  bool _handleScroll(ScrollNotification notification) {
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }

    final scrollContext = notification.context;
    final scrollable = scrollContext == null
        ? null
        : Scrollable.maybeOf(scrollContext);
    final position = scrollable?.position;
    final canScroll = notification.metrics.maxScrollExtent > 0;
    final shouldShow =
        canScroll && notification.metrics.pixels > _visibilityThreshold;
    if (_scrollPosition != position || _isVisible != shouldShow) {
      setState(() {
        _scrollPosition = position;
        _isVisible = shouldShow;
      });
    }
    return false;
  }

  Future<void> _scrollToTop() async {
    final position = _scrollPosition;
    if (position == null || !position.hasContentDimensions) {
      reset();
      return;
    }
    await position.animateTo(
      0,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      NotificationListener<ScrollNotification>(
        onNotification: _handleScroll,
        child: widget.child,
      ),
      Positioned(
        right: 16,
        bottom: 88,
        child: IgnorePointer(
          ignoring: !_isVisible,
          child: AnimatedOpacity(
            opacity: _isVisible ? 1 : 0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            child: AnimatedScale(
              scale: _isVisible ? 1 : 0.85,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              child: Semantics(
                button: true,
                label: 'Scroll to top',
                child: FloatingActionButton.small(
                  key: const ValueKey('scroll-to-top-button'),
                  heroTag: 'app-scroll-to-top',
                  onPressed: _scrollToTop,
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.onAccent,
                  child: const Icon(Icons.keyboard_arrow_up_rounded),
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}
