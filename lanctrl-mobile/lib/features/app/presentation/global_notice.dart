import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class GlobalNoticeHost extends StatefulWidget {
  const GlobalNoticeHost({super.key});

  @override
  GlobalNoticeHostState createState() => GlobalNoticeHostState();
}

class GlobalNoticeHostState extends State<GlobalNoticeHost> {
  static const _dismissDistance = 72.0;
  static const _hideDelay = Duration(seconds: 4);

  Timer? _hideTimer;
  String? _message;
  bool _visible = false;
  bool _pointerDown = false;
  Offset _dragOffset = Offset.zero;
  Offset _dismissOffset = Offset.zero;
  Duration _animationDuration = 260.ms;

  void show(String message) {
    _hideTimer?.cancel();
    setState(() {
      _message = message;
      _visible = false;
      _dragOffset = Offset.zero;
      _dismissOffset = const Offset(0, -56);
      _animationDuration = 260.ms;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _message != message) {
        return;
      }
      setState(() {
        _visible = true;
        _dismissOffset = Offset.zero;
      });
      _scheduleHide();
    });
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (_pointerDown || !_visible) {
      return;
    }

    _hideTimer = Timer(_hideDelay, dismiss);
  }

  void dismiss() {
    if (!_visible) {
      return;
    }

    setState(() {
      _visible = false;
      _pointerDown = false;
      _dragOffset = Offset.zero;
      _dismissOffset = const Offset(0, -92);
      _animationDuration = 240.ms;
    });

    Future<void>.delayed(_animationDuration, () {
      if (!mounted || _visible) {
        return;
      }
      setState(() {
        _message = null;
        _dismissOffset = Offset.zero;
      });
    });
  }

  void _dismissBySwipe(Offset direction) {
    final normalized = direction.distance == 0
        ? const Offset(0, -1)
        : direction / direction.distance;

    _hideTimer?.cancel();
    setState(() {
      _pointerDown = false;
      _visible = false;
      _dragOffset = Offset.zero;
      _dismissOffset = Offset(
        normalized.dx * 320,
        normalized.dy * 140,
      );
      _animationDuration = 180.ms;
    });

    Future<void>.delayed(_animationDuration, () {
      if (!mounted || _visible) {
        return;
      }
      setState(() {
        _message = null;
        _dismissOffset = Offset.zero;
      });
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_message == null) {
      return const SizedBox.shrink();
    }

    final offset = _dragOffset + _dismissOffset;
    final opacity = _visible
        ? (1 - (offset.distance / 220)).clamp(0.0, 1.0)
        : 0.0;

    return IgnorePointer(
      ignoring: !_visible && _message == null,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Align(
            alignment: Alignment.topCenter,
            child: AnimatedOpacity(
              duration: _animationDuration,
              curve: Curves.easeOutCubic,
              opacity: opacity,
              child: AnimatedContainer(
                duration: _animationDuration,
                curve: Curves.easeOutCubic,
                transform: Matrix4.translationValues(offset.dx, offset.dy, 0),
                constraints: const BoxConstraints(maxWidth: 520),
                child: GestureDetector(
                  onTapDown: (_) {
                    _hideTimer?.cancel();
                    setState(() => _pointerDown = true);
                  },
                  onTapUp: (_) {
                    setState(() => _pointerDown = false);
                    _scheduleHide();
                  },
                  onTapCancel: () {
                    setState(() => _pointerDown = false);
                    _scheduleHide();
                  },
                  onPanStart: (_) {
                    _hideTimer?.cancel();
                    setState(() => _pointerDown = true);
                  },
                  onPanUpdate: (details) {
                    setState(() {
                      _dragOffset += details.delta;
                    });
                  },
                  onPanEnd: (details) {
                    final velocity = details.velocity.pixelsPerSecond;
                    final shouldDismiss =
                        _dragOffset.distance >= _dismissDistance ||
                        velocity.distance >= 900;

                    if (shouldDismiss) {
                      final direction = velocity.distance >= 900
                          ? velocity
                          : _dragOffset;
                      _dismissBySwipe(direction);
                      return;
                    }

                    setState(() {
                      _pointerDown = false;
                      _dragOffset = Offset.zero;
                    });
                    _scheduleHide();
                  },
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.22),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 28,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.notifications_active_outlined,
                              size: 18,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _message!,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    height: 1.45,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.swipe_outlined,
                            size: 18,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
