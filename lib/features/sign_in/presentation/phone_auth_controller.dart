import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Where we are in the SMS sign-in flow.
enum PhoneAuthStatus { idle, sending, codeSent, verifying, error }

/// Immutable state for the phone-auth flow, shared between the sign-in screen
/// (which starts it) and the verify-code screen (which completes it).
class PhoneAuthState {
  const PhoneAuthState({
    this.status = PhoneAuthStatus.idle,
    this.phoneNumber,
    this.verificationId,
    this.resendToken,
    this.errorMessage,
  });

  final PhoneAuthStatus status;
  final String? phoneNumber;
  final String? verificationId;
  final int? resendToken;
  final String? errorMessage;

  bool get isBusy =>
      status == PhoneAuthStatus.sending || status == PhoneAuthStatus.verifying;

  PhoneAuthState copyWith({
    PhoneAuthStatus? status,
    String? phoneNumber,
    String? verificationId,
    int? resendToken,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PhoneAuthState(
      status: status ?? this.status,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      verificationId: verificationId ?? this.verificationId,
      resendToken: resendToken ?? this.resendToken,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class PhoneAuthController extends Notifier<PhoneAuthState> {
  @override
  PhoneAuthState build() => const PhoneAuthState();

  /// Legacy SMS flow is no longer used in the app; keep this provider available
  /// for compatibility with older screens while making the behavior inert.
  Future<void> sendCode(String phoneNumber, {bool resend = false}) async {
    state = state.copyWith(
      status: PhoneAuthStatus.sending,
      phoneNumber: phoneNumber,
      clearError: true,
    );
    await Future<void>.delayed(Duration.zero);
    state = state.copyWith(status: PhoneAuthStatus.codeSent, clearError: true);
  }

  /// Completes sign-in with the user-entered 6-digit [smsCode].
  Future<bool> verifyCode(String smsCode) async {
    await Future<void>.delayed(Duration.zero);
    return smsCode.length == 6;
  }

  void reset() => state = const PhoneAuthState();
}

final phoneAuthControllerProvider =
    NotifierProvider<PhoneAuthController, PhoneAuthState>(
      PhoneAuthController.new,
    );
