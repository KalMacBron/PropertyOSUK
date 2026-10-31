/// Maps authentication service failures to plain-English messages.
///
/// Raw messages from the authentication service are written for developers
/// and can change between releases, so the interface never shows them.
library;

const authBadCredentialsMessage =
    'Email or password not recognised. Check them and try again, '
    'or reset your password.';
const authEmailNotConfirmedMessage =
    'Confirm your email address using the link we sent, then sign in.';
const authRateLimitedMessage =
    'Too many attempts. Wait a few minutes and try again.';
const authSignInFallbackMessage = 'Unable to sign in. Try again.';
const authAccountExistsMessage =
    'An account already uses this email address. Sign in or reset your '
    'password instead.';
const authWeakPasswordMessage =
    'Choose a longer password that is harder to guess.';
const authLinkExpiredMessage =
    'This link has expired. Request a new email and use the newest link.';

/// Returns the message to show for an authentication failure.
///
/// [code] and [statusCode] come from the service's error. [message] is used
/// only to recognise older responses that carry no code. [fallback] is shown
/// when the failure is not one of the known cases.
String authErrorMessage({
  String? code,
  String? statusCode,
  String? message,
  String fallback = authSignInFallbackMessage,
}) {
  final normalisedCode = code?.toLowerCase();
  final normalisedMessage = message?.toLowerCase() ?? '';
  switch (normalisedCode) {
    case 'invalid_credentials':
      return authBadCredentialsMessage;
    case 'email_not_confirmed':
      return authEmailNotConfirmedMessage;
    case 'over_request_rate_limit':
    case 'over_email_send_rate_limit':
    case 'over_sms_send_rate_limit':
      return authRateLimitedMessage;
    case 'user_already_exists':
    case 'email_exists':
      return authAccountExistsMessage;
    case 'weak_password':
      return authWeakPasswordMessage;
    case 'otp_expired':
    case 'flow_state_expired':
      return authLinkExpiredMessage;
  }
  if (statusCode == '429' || normalisedMessage.contains('rate limit')) {
    return authRateLimitedMessage;
  }
  if (normalisedMessage.contains('invalid login credentials')) {
    return authBadCredentialsMessage;
  }
  if (normalisedMessage.contains('email not confirmed')) {
    return authEmailNotConfirmedMessage;
  }
  return fallback;
}
