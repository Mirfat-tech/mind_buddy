import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import 'package:mind_buddy/features/settings/settings_repository.dart';
import 'package:mind_buddy/services/startup_user_data_service.dart';

enum GuideAlign { top, bottom, left, right }

class GuideStep {
  const GuideStep({
    required this.key,
    required this.title,
    required this.body,
    this.align = GuideAlign.bottom,
  });

  final GlobalKey key;
  final String title;
  final String body;
  final GuideAlign align;
}

class GuideManager {
  GuideManager._();

  static const String _keepInstructionsVisibleKey = 'keepInstructionsVisible';
  static const String _guideStateField = 'guideState';
  static const String _shownPagesField = 'shownPages';
  static const String _dismissedStepsField = 'dismissedSteps';
  static const String _localGuideStatePrefix = 'localGuideState';
  static final Set<String> _activePages = <String>{};
  static TutorialCoachMark? _activeGuide;
  static String? _activeGuidePageId;
  static bool _isSkipDismissing = false;

  static Future<void> setKeepInstructionsVisible(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keepInstructionsVisibleKey, value);
  }

  static Future<bool> keepInstructionsVisible() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keepInstructionsVisibleKey) ?? false;
  }

  static Future<void> showGuideIfNeeded({
    required BuildContext context,
    required String pageId,
    required List<GuideStep> steps,
    bool force = false,
    bool requireAllTargetsVisible = false,
    bool debugLogs = false,
  }) async {
    if (steps.isEmpty) return;
    if (_activePages.contains(pageId)) return;
    if (_activeGuidePageId != null && _activeGuidePageId != pageId) {
      dismissActiveGuide();
    }

    final prefs = await SharedPreferences.getInstance();
    final guideState = await _loadGuideState(prefs);
    final shown = guideState.shownPages.contains(pageId);
    final keepVisible = prefs.getBool(_keepInstructionsVisibleKey) ?? false;

    // keepInstructionsVisible overrides prior "seen" state on every open.
    final shouldShow = keepVisible || force || !shown;
    if (!shouldShow) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future<void>.delayed(const Duration(milliseconds: 16), () {
          if (!context.mounted) return;
          final indexedSteps = <({int index, GuideStep step})>[
            for (var i = 0; i < steps.length; i++) (index: i, step: steps[i]),
          ];
          final visibleSteps = indexedSteps
              .where((entry) => entry.step.key.currentContext != null)
              .toList();
          final validSteps = <({int index, GuideStep step})>[];
          for (final entry in visibleSteps) {
            if (!keepVisible) {
              final dismissed = guideState.dismissedSteps.contains(
                _dismissedStepId(pageId, _stepId(entry.index, entry.step)),
              );
              if (dismissed) {
                continue;
              }
            }
            validSteps.add(entry);
          }
          if (validSteps.isEmpty) return;
          if (requireAllTargetsVisible &&
              validSteps.length < indexedSteps.length) {
            return;
          }
          _activePages.add(pageId);
          _activeGuidePageId = pageId;
          _isSkipDismissing = false;
          var closed = false;
          var currentStepIndex = -1;
          var overlayTapLocked = false;

          Future<void> markClosedAndSeen() async {
            if (closed) return;
            closed = true;
            _activePages.remove(pageId);
            if (_activeGuidePageId == pageId) {
              _activeGuidePageId = null;
              _activeGuide = null;
            }
            // Keep-visible mode must continue to auto-show on later visits.
            if (!keepVisible) {
              await _persistShown(pageId, prefs: prefs);
            }
          }

          final targets = <TargetFocus>[
            for (var i = 0; i < validSteps.length; i++)
              TargetFocus(
                identify:
                    '${pageId}_${validSteps[i].index}_${validSteps[i].step.title}',
                keyTarget: validSteps[i].step.key,
                shape: ShapeLightFocus.RRect,
                radius: 14,
                // Taps anywhere (overlay + spotlight) advance one step.
                enableOverlayTab: true,
                enableTargetTab: true,
                contents: [_buildClampedContent(context, validSteps[i].step)],
              ),
          ];
          final targetIndexById = <String, int>{
            for (var i = 0; i < targets.length; i++) targets[i].identify: i,
          };

          final guide = TutorialCoachMark(
            targets: targets,
            colorShadow: Colors.black,
            opacityShadow: 0.35,
            focusAnimationDuration: const Duration(milliseconds: 280),
            unFocusAnimationDuration: const Duration(milliseconds: 280),
            pulseEnable: false,
            imageFilter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
            hideSkip: false,
            showSkipInLastTarget: true,
            textSkip: 'SKIP',
            skipWidget: Container(
              margin: const EdgeInsets.only(top: 10, right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'SKIP',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            beforeFocus: (target) {
              final nextIndex = targetIndexById[target.identify] ?? -1;
              if (debugLogs) {
                debugPrint(
                  '[Guide][$pageId] focus index $currentStepIndex -> $nextIndex, '
                  'title="${target.identify}"',
                );
              }
              currentStepIndex = nextIndex;
            },
            onClickOverlay: (target) {
              if (overlayTapLocked) {
                if (debugLogs) {
                  debugPrint(
                    '[Guide][$pageId] overlay tap ignored (transition lock) at index=$currentStepIndex',
                  );
                }
                return;
              }
              overlayTapLocked = true;
              final before = currentStepIndex;
              final next = (before < 0 ? 0 : before + 1).clamp(
                0,
                targets.length - 1,
              );
              if (debugLogs) {
                debugPrint(
                  '[Guide][$pageId] overlay tap advance request: index $before -> $next '
                  '(target="${target.identify}")',
                );
              }
              Future<void>.delayed(const Duration(milliseconds: 250), () {
                overlayTapLocked = false;
              });
            },
            onFinish: () async {
              if (debugLogs) {
                debugPrint(
                  '[Guide][$pageId] finish at index=$currentStepIndex',
                );
              }
              await markClosedAndSeen();
            },
            onSkip: () {
              if (_isSkipDismissing) {
                if (debugLogs) {
                  debugPrint(
                    '[Guide][$pageId] skip ignored (dismiss already in progress)',
                  );
                }
                return false;
              }
              _isSkipDismissing = true;
              if (debugLogs) {
                debugPrint('[Guide][$pageId] skip at index=$currentStepIndex');
              }
              unawaited(
                _dismissCurrentInstruction(
                  prefs: prefs,
                  pageId: pageId,
                  keepVisible: keepVisible,
                  validSteps: validSteps,
                  currentStepIndex: currentStepIndex,
                  markClosedAndSeen: markClosedAndSeen,
                ).whenComplete(() => _isSkipDismissing = false),
              );
              return true;
            },
          );
          _activeGuide = guide;
          guide.show(context: context);
        });
      });
    });
  }

  static void dismissActiveGuide() {
    _activeGuide?.removeOverlayEntry();
    _activeGuide = null;
    _activePages.clear();
    _activeGuidePageId = null;
  }

  static void dismissActiveGuideForPage(String pageId) {
    if (_activeGuidePageId == pageId) {
      dismissActiveGuide();
    }
  }

  static Future<void> _dismissCurrentInstruction({
    required SharedPreferences prefs,
    required String pageId,
    required bool keepVisible,
    required List<({int index, GuideStep step})> validSteps,
    required int currentStepIndex,
    required Future<void> Function() markClosedAndSeen,
  }) async {
    if (!keepVisible &&
        currentStepIndex >= 0 &&
        currentStepIndex < validSteps.length) {
      final current = validSteps[currentStepIndex];
      await _persistDismissedStep(
        pageId,
        _stepId(current.index, current.step),
        prefs: prefs,
      );
    }
    await markClosedAndSeen();
  }

  static String _dismissedStepId(String pageId, String stepId) =>
      '$pageId::$stepId';

  static String? _currentUserId() =>
      Supabase.instance.client.auth.currentUser?.id;

  static String _localGuideStateKey(String? userId) {
    if (userId == null || userId.isEmpty) return _localGuideStatePrefix;
    return '$_localGuideStatePrefix'
        '_$userId';
  }

  static Future<_GuideState> _loadGuideState(SharedPreferences prefs) async {
    final userId = _currentUserId();
    final cachedRemote = StartupUserDataService.instance
        .peekCachedForCurrentUser();
    final remoteState = _parseRemoteGuideState(cachedRemote?.settingsRow);
    final localState = _loadLocalGuideState(prefs, userId);
    final merged = _GuideState(
      shownPages: {...remoteState.shownPages, ...localState.shownPages},
      dismissedSteps: {
        ...remoteState.dismissedSteps,
        ...localState.dismissedSteps,
      },
    );

    if (merged != localState) {
      await _saveLocalGuideState(prefs, userId, merged);
    }

    return merged;
  }

  static _GuideState _parseRemoteGuideState(Map<String, dynamic>? settingsRow) {
    final rawSettings = settingsRow?['settings'];
    if (rawSettings is! Map) return const _GuideState.empty();
    final settings = Map<String, dynamic>.from(rawSettings);
    final rawGuideState = settings[_guideStateField];
    if (rawGuideState is! Map) return const _GuideState.empty();
    final guideState = Map<String, dynamic>.from(rawGuideState);
    final shownPagesRaw = guideState[_shownPagesField];
    final dismissedStepsRaw = guideState[_dismissedStepsField];
    return _GuideState(
      shownPages: shownPagesRaw is List
          ? shownPagesRaw.map((e) => e.toString()).toSet()
          : const <String>{},
      dismissedSteps: dismissedStepsRaw is List
          ? dismissedStepsRaw.map((e) => e.toString()).toSet()
          : const <String>{},
    );
  }

  static Future<void> _persistShown(
    String pageId, {
    required SharedPreferences prefs,
  }) async {
    final userId = _currentUserId();
    final current = _loadLocalGuideState(prefs, userId);
    await _saveLocalGuideState(
      prefs,
      userId,
      current.copyWith(shownPages: {...current.shownPages, pageId}),
    );
    await _persistRemote(
      update: (state) =>
          state.copyWith(shownPages: {...state.shownPages, pageId}),
    );
  }

  static Future<void> _persistDismissedStep(
    String pageId,
    String stepId, {
    required SharedPreferences prefs,
  }) async {
    final userId = _currentUserId();
    final dismissedStep = _dismissedStepId(pageId, stepId);
    final current = _loadLocalGuideState(prefs, userId);
    await _saveLocalGuideState(
      prefs,
      userId,
      current.copyWith(
        dismissedSteps: {...current.dismissedSteps, dismissedStep},
      ),
    );
    await _persistRemote(
      update: (state) => state.copyWith(
        dismissedSteps: {...state.dismissedSteps, dismissedStep},
      ),
    );
  }

  static _GuideState _loadLocalGuideState(
    SharedPreferences prefs,
    String? userId,
  ) {
    final raw = prefs.getString(_localGuideStateKey(userId));
    if (raw == null || raw.isEmpty) return const _GuideState.empty();
    try {
      final decoded = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final shownRaw = decoded[_shownPagesField];
      final dismissedRaw = decoded[_dismissedStepsField];
      return _GuideState(
        shownPages: shownRaw is List
            ? shownRaw.map((e) => e.toString()).toSet()
            : const <String>{},
        dismissedSteps: dismissedRaw is List
            ? dismissedRaw.map((e) => e.toString()).toSet()
            : const <String>{},
      );
    } catch (_) {
      return const _GuideState.empty();
    }
  }

  static Future<void> _saveLocalGuideState(
    SharedPreferences prefs,
    String? userId,
    _GuideState state,
  ) async {
    await prefs.setString(
      _localGuideStateKey(userId),
      jsonEncode(<String, dynamic>{
        _shownPagesField: state.shownPages.toList()..sort(),
        _dismissedStepsField: state.dismissedSteps.toList()..sort(),
      }),
    );
  }

  static Future<void> _persistRemote({
    required _GuideState Function(_GuideState state) update,
  }) async {
    final repository = SettingsRepository.activeInstance;
    if (repository == null) return;

    try {
      final settings =
          await repository.loadCached() ?? await repository.initialize();
      final currentState = _GuideState(
        shownPages:
            ((settings.guideState[_shownPagesField] as List?) ?? const [])
                .map((entry) => entry.toString())
                .toSet(),
        dismissedSteps:
            ((settings.guideState[_dismissedStepsField] as List?) ?? const [])
                .map((entry) => entry.toString())
                .toSet(),
      );
      final nextState = update(currentState);
      await repository.updateGuideState(<String, dynamic>{
        _shownPagesField: nextState.shownPages.toList()..sort(),
        _dismissedStepsField: nextState.dismissedSteps.toList()..sort(),
      });
    } catch (_) {
      // Guidance persistence should never block navigation.
    }
  }

  static String _stepId(int index, GuideStep step) {
    final normalized = step.title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (normalized.isNotEmpty) {
      return normalized;
    }
    return 'step_$index';
  }

  static GuideAlign _resolvedAlign(BuildContext context, GuideStep step) {
    final align = step.align;
    if (align == GuideAlign.left || align == GuideAlign.right) {
      return GuideAlign.bottom;
    }
    final keyContext = step.key.currentContext;
    if (keyContext == null) return align;
    final box = keyContext.findRenderObject();
    if (box is! RenderBox) return align;
    final media = MediaQuery.of(context);
    final size = media.size;
    final safeTop = media.padding.top + 12;
    final safeBottom = size.height - media.padding.bottom - 12;
    final targetRect = box.localToGlobal(Offset.zero) & box.size;
    const tooltipEstimatedHeight = 170.0;
    final hasSpaceAbove = targetRect.top - tooltipEstimatedHeight > safeTop;
    final hasSpaceBelow =
        targetRect.bottom + tooltipEstimatedHeight < safeBottom;

    if (align == GuideAlign.top && !hasSpaceAbove && hasSpaceBelow) {
      return GuideAlign.bottom;
    }
    if (align == GuideAlign.bottom && !hasSpaceBelow && hasSpaceAbove) {
      return GuideAlign.top;
    }
    if (!hasSpaceBelow && hasSpaceAbove) return GuideAlign.top;
    if (!hasSpaceAbove && hasSpaceBelow) return GuideAlign.bottom;
    return align;
  }

  static TargetContent _buildClampedContent(
    BuildContext context,
    GuideStep step,
  ) {
    final keyContext = step.key.currentContext;
    final box = keyContext?.findRenderObject();
    final tooltip = _GuideTooltip(title: step.title, body: step.body);
    if (keyContext == null || box is! RenderBox || !box.hasSize) {
      return TargetContent(
        align: _toContentAlign(_resolvedAlign(context, step)),
        child: tooltip,
      );
    }

    final media = MediaQuery.of(context);
    final screen = media.size;
    const horizontalPadding = 16.0;
    const verticalPadding = 16.0;
    const tooltipGap = 12.0;
    final tooltipEstimatedWidth = (screen.width - (horizontalPadding * 2))
        .clamp(220.0, 320.0);
    final tooltipEstimatedHeight = _estimateTooltipHeight(
      context: context,
      title: step.title,
      body: step.body,
      maxWidth: tooltipEstimatedWidth,
    );
    const safeLeft = horizontalPadding;
    final safeRight = screen.width - horizontalPadding;
    final safeTop = media.padding.top + verticalPadding;
    final safeBottom = screen.height - media.padding.bottom - verticalPadding;

    final rect = box.localToGlobal(Offset.zero) & box.size;
    var left = rect.center.dx - (tooltipEstimatedWidth / 2);
    left = left.clamp(safeLeft, safeRight - tooltipEstimatedWidth);

    final align = _resolvedAlign(context, step);
    final spaceAbove = rect.top - safeTop - tooltipGap;
    final spaceBelow = safeBottom - rect.bottom - tooltipGap;
    final canPlaceAbove = spaceAbove >= tooltipEstimatedHeight;
    final canPlaceBelow = spaceBelow >= tooltipEstimatedHeight;
    final preferAbove = align == GuideAlign.top;
    double top;
    if (preferAbove && canPlaceAbove) {
      top = rect.top - tooltipEstimatedHeight - tooltipGap;
    } else if (!preferAbove && canPlaceBelow) {
      top = rect.bottom + tooltipGap;
    } else if (canPlaceBelow) {
      top = rect.bottom + tooltipGap;
    } else if (canPlaceAbove) {
      top = rect.top - tooltipEstimatedHeight - tooltipGap;
    } else {
      final visibleHeight = safeBottom - safeTop;
      top = safeTop + ((visibleHeight - tooltipEstimatedHeight) / 2);
    }
    top = top.clamp(safeTop, safeBottom - tooltipEstimatedHeight);

    return TargetContent(
      align: ContentAlign.custom,
      customPosition: CustomTargetContentPosition(top: top, left: left),
      child: tooltip,
    );
  }

  static double _estimateTooltipHeight({
    required BuildContext context,
    required String title,
    required String body,
    required double maxWidth,
  }) {
    final textScale = MediaQuery.of(context).textScaler;
    final titleStyle =
        Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700) ??
        const TextStyle(fontSize: 14, fontWeight: FontWeight.w700);
    final bodyStyle =
        Theme.of(context).textTheme.bodySmall ??
        const TextStyle(fontSize: 12, height: 1.2);
    const horizontalPadding = 14.0 * 2;
    const verticalPadding = 12.0 * 2;
    final textMaxWidth = math.max(120.0, maxWidth - horizontalPadding);
    final titlePainter = TextPainter(
      text: TextSpan(text: title, style: titleStyle),
      textDirection: TextDirection.ltr,
      textScaler: textScale,
      maxLines: 2,
    )..layout(maxWidth: textMaxWidth);
    final bodyPainter = TextPainter(
      text: TextSpan(text: body, style: bodyStyle),
      textDirection: TextDirection.ltr,
      textScaler: textScale,
      maxLines: 2,
    )..layout(maxWidth: textMaxWidth);
    return verticalPadding + titlePainter.height + 4 + bodyPainter.height;
  }

  static ContentAlign _toContentAlign(GuideAlign align) {
    switch (align) {
      case GuideAlign.top:
        return ContentAlign.top;
      case GuideAlign.left:
        return ContentAlign.left;
      case GuideAlign.right:
        return ContentAlign.right;
      case GuideAlign.bottom:
        return ContentAlign.bottom;
    }
  }
}

class _GuideTooltip extends StatelessWidget {
  const _GuideTooltip({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxWidth = MediaQuery.of(context).size.width - 24;
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth.clamp(220.0, 320.0)),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 2,
            softWrap: true,
            overflow: TextOverflow.fade,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            maxLines: 2,
            softWrap: true,
            overflow: TextOverflow.fade,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _GuideState {
  const _GuideState({required this.shownPages, required this.dismissedSteps});

  const _GuideState.empty()
    : shownPages = const <String>{},
      dismissedSteps = const <String>{};

  final Set<String> shownPages;
  final Set<String> dismissedSteps;

  _GuideState copyWith({Set<String>? shownPages, Set<String>? dismissedSteps}) {
    return _GuideState(
      shownPages: shownPages ?? this.shownPages,
      dismissedSteps: dismissedSteps ?? this.dismissedSteps,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is _GuideState &&
        setEquals(other.shownPages, shownPages) &&
        setEquals(other.dismissedSteps, dismissedSteps);
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(shownPages.toList()..sort()),
    Object.hashAll(dismissedSteps.toList()..sort()),
  );
}
