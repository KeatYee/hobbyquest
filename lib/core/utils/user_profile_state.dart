bool hasCompletedUserProfile(Map<String, dynamic>? data) {
  if (data == null) return false;

  final explicitState = data['isOnboardingComplete'];
  if (explicitState is bool) return explicitState;

  // Compatibility for profiles created before the completion flag existed.
  final activePlanId = data['activePlanId']?.toString().trim() ?? '';
  final nickname = data['nickname']?.toString().trim() ?? '';
  return activePlanId.isNotEmpty && nickname.isNotEmpty;
}
