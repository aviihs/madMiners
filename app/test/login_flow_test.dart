import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mad_miners/app/app.dart';
import 'package:mad_miners/app/di.dart';
import 'package:mad_miners/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await configureDependencies();
  });

  testWidgets('typing a name and tapping Play Online never throws during build', (tester) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    await tester.pumpWidget(const MadMinersApp());
    await tester.pump(const Duration(seconds: 1));

    await tester.enterText(find.byType(EditableText).first, 'avihs');
    await tester.pump();
    // In widget tests HTTP returns 400, so sign-in fails -> error toast path.
    // Submit with the keyboard's OK/Done key (works even if the server dot is red).
    await tester.testTextInput.receiveAction(TextInputAction.done);
    for (var i = 0; i < 20; i++) {
      // Let the real (test) HTTP call complete, then build the result.
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);
    final state = BlocProvider.of<AuthCubit>(tester.element(find.byType(Scaffold).first)).state;
    expect(state, isA<AuthSignedOut>());
    expect((state as AuthSignedOut).error, isNotNull);

    // Offline path works too.
    await tester.tap(find.text('Practice Offline'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    expect(find.text('Start Digging'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });
}
