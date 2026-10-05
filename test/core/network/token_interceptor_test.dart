import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/features/auth/data/interceptors/token_interceptor.dart';

void main() {
  group('TokenInterceptor.shouldOverrideHostForOnionRelay', () {
    test('does not override Host in Flutter Web', () {
      expect(
        TokenInterceptor.shouldOverrideHostForOnionRelay(
          isWeb: true,
          baseUrl: 'http://127.0.0.1:43123',
          onionBaseUrl: 'http://abc123.onion',
        ),
        isFalse,
      );
    });

    test('overrides Host only for local relay to onion on non-web clients', () {
      expect(
        TokenInterceptor.shouldOverrideHostForOnionRelay(
          isWeb: false,
          baseUrl: 'http://127.0.0.1:43123',
          onionBaseUrl: 'http://abc123.onion',
        ),
        isTrue,
      );
    });

    test('keeps direct non-local API requests untouched', () {
      expect(
        TokenInterceptor.shouldOverrideHostForOnionRelay(
          isWeb: false,
          baseUrl: 'https://api.kerosene.example',
          onionBaseUrl: 'http://abc123.onion',
        ),
        isFalse,
      );
    });
  });

  group('TokenInterceptor.isKfeTransactionStepUpPath', () {
    test('matches active KFE transaction paths', () {
      expect(
        TokenInterceptor.isKfeTransactionStepUpPath('/kfe/transactions'),
        isTrue,
      );
      expect(
        TokenInterceptor.isKfeTransactionStepUpPath(
          '/api/admin/kfe/transactions/review',
        ),
        isTrue,
      );
    });

    test('does not match legacy generic transaction paths', () {
      expect(
        TokenInterceptor.isKfeTransactionStepUpPath('/transactions/123'),
        isFalse,
      );
      expect(
        TokenInterceptor.isKfeTransactionStepUpPath(
          '/transactions/visualization/blockchain',
        ),
        isFalse,
      );
    });
  });

  group('TokenInterceptor.requiresSessionCredential', () {
    test('requires local session credentials for private KFE routes', () {
      expect(
        TokenInterceptor.requiresSessionCredential('/kfe/dashboard'),
        isTrue,
      );
      expect(
        TokenInterceptor.requiresSessionCredential('/kfe/payment-requests'),
        isTrue,
      );
      expect(
        TokenInterceptor.requiresSessionCredential('/api/economy/btc-price'),
        isFalse,
      );
    });
  });

  group('TokenInterceptor.isPublicAuthPath', () {
    test('keeps PoW challenge free of stale bearer credentials', () {
      expect(
        TokenInterceptor.isPublicAuthPath('/auth/pow/challenge'),
        isTrue,
      );
      expect(
        TokenInterceptor.isPublicAuthPath(
          'http://127.0.0.1:43123/auth/pow/challenge',
        ),
        isTrue,
      );
      expect(
        TokenInterceptor.isPublicAuthPath('/kfe/dashboard'),
        isFalse,
      );
    });
  });

  group('TokenInterceptor.shouldInvalidateSessionForError', () {
    test('keeps session while KFE authentication dependency is unavailable',
        () {
      expect(
        TokenInterceptor.shouldInvalidateSessionForError(
          statusCode: 503,
          path: '/kfe/dashboard',
          errorCode: 'SYS_500',
          responseDataText:
              '{"success":false,"message":"Authentication temporarily unavailable","errorCode":"SYS_500"}',
          requestHadAuthorizationHeader: true,
        ),
        isFalse,
      );
      expect(
        TokenInterceptor.shouldInvalidateSessionForError(
          statusCode: 401,
          path: '/kfe/dashboard',
          errorCode: 'INVALID_SESSION',
          responseDataText:
              '{"success":false,"message":"invalid session","errorCode":"INVALID_SESSION"}',
          requestHadAuthorizationHeader: true,
        ),
        isTrue,
      );
    });

    test('keeps session for KFE transaction authorization failures', () {
      expect(
        TokenInterceptor.shouldInvalidateSessionForError(
          statusCode: 401,
          path: '/kfe/transactions',
          errorCode: 'AUTH_023',
          responseDataText: 'PIN do aplicativo obrigatorio',
          requestHadAuthorizationHeader: true,
        ),
        isFalse,
      );
      expect(
        TokenInterceptor.shouldInvalidateSessionForError(
          statusCode: 403,
          path: '/kfe/transactions/review',
          errorCode: 'AUTH_019',
          responseDataText: 'PIN invalido',
          requestHadAuthorizationHeader: true,
        ),
        isFalse,
      );
      expect(
        TokenInterceptor.shouldInvalidateSessionForError(
          statusCode: 428,
          path: '/kfe/transactions/authorize',
          errorCode: 'AUTH_012',
          responseDataText: 'PASSKEY_CHALLENGE_REQUIRED:abc123',
          requestHadAuthorizationHeader: true,
        ),
        isFalse,
      );
    });

    test('does not invalidate the session when the request had no token', () {
      expect(
        TokenInterceptor.shouldInvalidateSessionForError(
          statusCode: 401,
          path: '/kfe/dashboard',
          errorCode: 'AUTH_013',
          responseDataText: 'Authentication is required',
          requestHadAuthorizationHeader: false,
        ),
        isFalse,
      );
    });

    test('invalidates confirmed session failures outside transaction step-up',
        () {
      expect(
        TokenInterceptor.shouldInvalidateSessionForError(
          statusCode: 401,
          path: '/me',
          errorCode: 'AUTH_013',
          responseDataText: 'Session expired',
          requestHadAuthorizationHeader: true,
        ),
        isTrue,
      );
      expect(
        TokenInterceptor.shouldInvalidateSessionForError(
          statusCode: 403,
          path: '/kfe/dashboard',
          errorCode: 'ERR_AUTH_REVOKED',
          responseDataText: 'JWT rejected',
          requestHadAuthorizationHeader: true,
        ),
        isTrue,
      );
    });

    test('does not log out on wrong app entry PIN (AUTH_019 / 401)', () {
      expect(
        TokenInterceptor.shouldInvalidateSessionForError(
          statusCode: 401,
          path: '/auth/security/app-pin/verify',
          errorCode: 'AUTH_019',
          responseDataText: 'PIN numerico incorreto.',
          requestHadAuthorizationHeader: true,
        ),
        isFalse,
      );
      expect(
        TokenInterceptor.shouldInvalidateSessionForError(
          statusCode: 400,
          path: '/auth/security/app-pin/verify',
          errorCode: 'AUTH_019',
          responseDataText: 'PIN numerico incorreto.',
          requestHadAuthorizationHeader: true,
        ),
        isFalse,
      );
      expect(
        TokenInterceptor.shouldInvalidateSessionForError(
          statusCode: 429,
          path: '/auth/security/app-pin/verify',
          errorCode: 'AUTH_020',
          responseDataText: 'PIN temporariamente bloqueado',
          requestHadAuthorizationHeader: true,
        ),
        isFalse,
      );
      // Code alone must also protect non-verify app-pin routes
      expect(
        TokenInterceptor.shouldInvalidateSessionForError(
          statusCode: 401,
          path: '/auth/security/app-pin',
          errorCode: 'AUTH_019',
          responseDataText: 'PIN atual incorreto.',
          requestHadAuthorizationHeader: true,
        ),
        isFalse,
      );
    });
  });
}
