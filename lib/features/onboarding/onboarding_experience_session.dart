class OnboardingExperienceSession {
  OnboardingExperienceSession._();

  static bool _featureExperienceCompleted = false;

  static void markFeatureExperienceCompleted() {
    _featureExperienceCompleted = true;
  }

  static bool consumeFeatureExperienceCompleted() {
    final completed = _featureExperienceCompleted;
    _featureExperienceCompleted = false;
    return completed;
  }
}
