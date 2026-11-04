import 'dart:io';

import 'package:financeflow/src/api/finance_api.dart';
import 'package:financeflow/src/screens/auth_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory cookieDirectory;
  late FinanceApi api;

  setUp(() {
    cookieDirectory = Directory.systemTemp.createTempSync('financeflow-test-');
    api = FinanceApi.create(cookieDirectory: cookieDirectory.path);
  });

  tearDown(() => cookieDirectory.deleteSync(recursive: true));

  testWidgets('shows the sign-in screen', (tester) async {
    await tester
        .pumpWidget(MaterialApp(home: AuthScreen(api: api, onSignedIn: () {})));

    expect(find.text('FinanceFlow'), findsOneWidget);
    expect(find.text('Good to see you again.'), findsOneWidget);
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });

  testWidgets('switches to account creation', (tester) async {
    await tester
        .pumpWidget(MaterialApp(home: AuthScreen(api: api, onSignedIn: () {})));
    await tester
        .ensureVisible(find.text('New to FinanceFlow? Create an account'));
    await tester.tap(find.text('New to FinanceFlow? Create an account'));
    await tester.pumpAndSettle();

    expect(find.text('Create your private finance workspace.'), findsOneWidget);
    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
  });

  testWidgets(
      'switches to sign in if account creation succeeds but auto sign-in fails',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home:
            AuthScreen(api: _SignupAutoLoginFailureApi(), onSignedIn: () {})));
    await tester
        .ensureVisible(find.text('New to FinanceFlow? Create an account'));
    await tester.tap(find.text('New to FinanceFlow? Create an account'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Test Person');
    await tester.enterText(
        find.byType(TextFormField).at(1), 'mobile@example.test');
    await tester.enterText(
        find.byType(TextFormField).at(2), 'Correct-Horse-1!');
    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(
        find.text(
            'Your account was created. Sign in with the same email and password.'),
        findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Create account'), findsNothing);
    expect(
        (tester
                .widget<TextFormField>(find.byType(TextFormField).at(0))
                .controller)
            ?.text,
        'mobile@example.test');
  });

  testWidgets('opens the password reset flow from sign in', (tester) async {
    await tester
        .pumpWidget(MaterialApp(home: AuthScreen(api: api, onSignedIn: () {})));
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();

    expect(find.text('Reset your password'), findsOneWidget);
    expect(find.text('Send reset link'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Reset your password'), findsNothing);
  });
}

class _SignupAutoLoginFailureApi implements AuthApi {
  @override
  Future<void> register(
      {required String name,
      required String email,
      required String password}) async {}

  @override
  Future<void> login(String email, String password) async {
    throw const FinanceApiException('Email or password is incorrect.');
  }

  @override
  Future<void> requestPasswordReset(String email) async {}
}
