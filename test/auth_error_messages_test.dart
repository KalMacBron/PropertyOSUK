import 'package:flutter_test/flutter_test.dart';
import 'package:property_os/features/auth/domain/auth_error_messages.dart';

void main() {
  test('maps bad credentials to a plain message', () {
    expect(
      authErrorMessage(
        code: 'invalid_credentials',
        statusCode: '400',
        message: 'Invalid login credentials',
      ),
      'Email or password not recognised. Check them and try again, '
      'or reset your password.',
    );
    expect(
      authErrorMessage(message: 'Invalid login credentials'),
      authBadCredentialsMessage,
    );
  });

  test('maps unconfirmed email and rate limits', () {
    expect(
      authErrorMessage(code: 'email_not_confirmed'),
      'Confirm your email address using the link we sent, then sign in.',
    );
    expect(
      authErrorMessage(code: 'over_request_rate_limit'),
      'Too many attempts. Wait a few minutes and try again.',
    );
    expect(authErrorMessage(statusCode: '429'), authRateLimitedMessage);
    expect(
      authErrorMessage(message: 'Email rate limit exceeded'),
      authRateLimitedMessage,
    );
  });

  test('never shows the raw service message for unknown failures', () {
    const raw = 'AuthRetryableFetchException: database error 500';
    expect(
      authErrorMessage(code: 'unexpected_failure', message: raw),
      'Unable to sign in. Try again.',
    );
    expect(
      authErrorMessage(message: raw, fallback: 'Unable to send. Try again.'),
      'Unable to send. Try again.',
    );
  });

  test('maps signup failures', () {
    expect(authErrorMessage(code: 'user_already_exists'),
        authAccountExistsMessage);
    expect(authErrorMessage(code: 'weak_password'), authWeakPasswordMessage);
  });
}
