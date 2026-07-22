String? secondaryProfileName({
  required String primaryName,
  required String? displayName,
}) {
  final normalizedPrimary = primaryName.trim();
  final normalizedDisplay = (displayName ?? '').trim();

  if (normalizedDisplay.isEmpty) return null;
  if (normalizedDisplay == normalizedPrimary) return null;
  return normalizedDisplay;
}
