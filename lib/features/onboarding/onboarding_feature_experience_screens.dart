import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mind_buddy/features/brain_fog/brain_fog_repository.dart';
import 'package:mind_buddy/features/brain_fog/brain_fog_screen.dart';
import 'package:mind_buddy/features/bubbles/bubble_board_storage.dart';
import 'package:mind_buddy/features/gratitude/gratitude_bubble_screen.dart';
import 'package:mind_buddy/features/gratitude/gratitude_carousel_editor_screen.dart';
import 'package:mind_buddy/features/gratitude/gratitude_carousel_storage.dart';
import 'package:mind_buddy/features/onboarding/onboarding_experience_session.dart';

class OnboardingGratitudeExperienceScreen extends StatefulWidget {
  const OnboardingGratitudeExperienceScreen({super.key});

  @override
  State<OnboardingGratitudeExperienceScreen> createState() =>
      _OnboardingGratitudeExperienceScreenState();
}

class _OnboardingGratitudeExperienceScreenState
    extends State<OnboardingGratitudeExperienceScreen> {
  late final InMemoryBubbleBoardStorage _storage = InMemoryBubbleBoardStorage(
    onMutated: _markInteracted,
  );
  late final InMemoryGratitudeCarouselStorage _carouselStorage =
      InMemoryGratitudeCarouselStorage();
  bool _hasInteracted = false;
  bool _isHandingOff = false;

  void _markInteracted() {
    if (_hasInteracted || !mounted) return;
    setState(() => _hasInteracted = true);
  }

  Future<void> _goToAuth() async {
    if (_isHandingOff) return;
    _isHandingOff = true;
    OnboardingExperienceSession.markFeatureExperienceCompleted();
    if (!mounted) return;
    context.go('/auth');
  }

  Future<void> _handleBack() async {
    if (_hasInteracted) {
      await _goToAuth();
      return;
    }
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/onboarding/doorway');
  }

  Future<void> _openCarousel(List<String> seededBubbleTexts) async {
    _markInteracted();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => GratitudeCarouselEditorScreen(
          seededBubbleTexts: seededBubbleTexts,
          storage: _carouselStorage,
          onOpenHistory: _goToAuth,
        ),
      ),
    );
    if (!mounted) return;
    await _goToAuth();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _handleBack();
      },
      child: GratitudeBubbleScreen(
        storage: _storage,
        onBackPressed: () {
          _handleBack();
        },
        onOpenJournal: _goToAuth,
        onOpenCarousel: _openCarousel,
        onOpenHistory: () {
          _goToAuth();
        },
      ),
    );
  }
}

class OnboardingBrainFogExperienceScreen extends StatefulWidget {
  const OnboardingBrainFogExperienceScreen({super.key});

  @override
  State<OnboardingBrainFogExperienceScreen> createState() =>
      _OnboardingBrainFogExperienceScreenState();
}

class _OnboardingBrainFogExperienceScreenState
    extends State<OnboardingBrainFogExperienceScreen> {
  late final BrainFogRepository _repository = BrainFogRepository.memory(
    onMutated: _markInteracted,
  );
  bool _hasInteracted = false;
  bool _isHandingOff = false;

  void _markInteracted() {
    if (_hasInteracted || !mounted) return;
    setState(() => _hasInteracted = true);
  }

  Future<void> _goToAuth() async {
    if (_isHandingOff) return;
    _isHandingOff = true;
    OnboardingExperienceSession.markFeatureExperienceCompleted();
    if (!mounted) return;
    context.go('/auth');
  }

  Future<void> _handleBack() async {
    if (_hasInteracted) {
      await _goToAuth();
      return;
    }
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/onboarding/doorway');
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [brainFogRepositoryProvider.overrideWithValue(_repository)],
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          await _handleBack();
        },
        child: BrainFogScreen(
          guidesEnabled: false,
          onBackPressed: () {
            _handleBack();
          },
          onFigureOutRoute: (_) {
            _markInteracted();
            _goToAuth();
          },
        ),
      ),
    );
  }
}
