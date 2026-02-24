import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingAnswers {
  const OnboardingAnswers({
    this.slipFirst = const <String>{},
    this.expressionStyle = const <String>{},
    this.lookingBack = const <String>{},
    this.skippedSignUp = false,
    this.skippedPersonalization = false,
  });

  final Set<String> slipFirst;
  final Set<String> expressionStyle;
  final Set<String> lookingBack;
  final bool skippedSignUp;
  final bool skippedPersonalization;

  OnboardingAnswers copyWith({
    Set<String>? slipFirst,
    Set<String>? expressionStyle,
    Set<String>? lookingBack,
    bool? skippedSignUp,
    bool? skippedPersonalization,
  }) {
    return OnboardingAnswers(
      slipFirst: slipFirst ?? this.slipFirst,
      expressionStyle: expressionStyle ?? this.expressionStyle,
      lookingBack: lookingBack ?? this.lookingBack,
      skippedSignUp: skippedSignUp ?? this.skippedSignUp,
      skippedPersonalization:
          skippedPersonalization ?? this.skippedPersonalization,
    );
  }
}

final onboardingControllerProvider =
    StateNotifierProvider<OnboardingController, OnboardingAnswers>((ref) {
      return OnboardingController();
    });

class OnboardingController extends StateNotifier<OnboardingAnswers> {
  OnboardingController() : super(const OnboardingAnswers());

  static const _completedKey = 'onboarding_completed';
  static const _authSkippedKey = 'onboarding_auth_skipped';

  void setSlipFirst(Set<String> values) {
    state = state.copyWith(slipFirst: Set<String>.from(values));
  }

  void setExpressionStyle(Set<String> values) {
    state = state.copyWith(expressionStyle: Set<String>.from(values));
  }

  void setLookingBack(Set<String> values) {
    state = state.copyWith(lookingBack: Set<String>.from(values));
  }

  void clearSlipFirst() {
    state = state.copyWith(slipFirst: <String>{});
  }

  void clearExpressionStyle() {
    state = state.copyWith(expressionStyle: <String>{});
  }

  void clearLookingBack() {
    state = state.copyWith(lookingBack: <String>{});
  }

  void setSkippedSignUp(bool value) {
    state = state.copyWith(skippedSignUp: value);
  }

  void setSkippedPersonalization(bool value) {
    state = state.copyWith(skippedPersonalization: value);
  }

  static Future<bool> isCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_completedKey) ?? false;
  }

  static Future<void> markCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_completedKey, true);
  }

  static Future<bool> isAuthSkipped() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_authSkippedKey) ?? false;
  }

  static Future<void> setAuthSkipped(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_authSkippedKey, value);
  }
}
