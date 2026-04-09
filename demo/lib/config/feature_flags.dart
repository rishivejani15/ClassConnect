class FeatureFlags {
  FeatureFlags._();

  static const bool ameEnabled = bool.fromEnvironment(
    'AME_ENABLED',
    defaultValue: false,
  );
}
