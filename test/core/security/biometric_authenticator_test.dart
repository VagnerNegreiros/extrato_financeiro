import 'package:extrato_financeiro/core/security/biometric_authenticator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mocktail/mocktail.dart';

class _MockLocalAuth extends Mock implements LocalAuthentication;

void main() {
  late _MockLocalAuth auth;
  late LocalAuthBiometricAuthenticator authenticator;

  setUp(() {
    auth = _MockLocalAuth();
    authenticator = LocalAuthBiometricAuthenticator(auth);
  });

  Future<BiometricResult> authenticate() =>
      authenticator.authenticate(reason: 'teste');

  test('devices without biometrics or lock screen are unavailable', () async {
    when(() => auth.isDeviceSupported()).thenAnswer((_) async => false);

    expect(await authenticate(), BiometricResult.unavailable);
    verifyNever(
      () => auth.authenticate(
        localizedReason: any(named: 'localizedReason'),
        persistAcrossBackgrounding: any(named: 'persistAcrossBackgrounding'),
      ),
    );
  });

  test('maps the prompt result', () async {
    when(() => auth.isDeviceSupported()).thenAnswer((_) async => true);
    when(
      () => auth.authenticate(
        localizedReason: 'teste',
        persistAcrossBackgrounding: true,
      ),
    ).thenAnswer((_) async => true);
    expect(await authenticate(), BiometricResult.authenticated);

    when(
      () => auth.authenticate(
        localizedReason: 'teste',
        persistAcrossBackgrounding: true,
      ),
    ).thenAnswer((_) async => false);
    expect(await authenticate(), BiometricResult.denied);
  });

  test('platform errors fail closed', () async {
    when(() => auth.isDeviceSupported()).thenThrow(Exception('plugin'));
    expect(await authenticate(), BiometricResult.denied);
  });
}
