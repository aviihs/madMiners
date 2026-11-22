import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mad_miners/app/app.dart';
import 'package:mad_miners/app/boot/app_root.dart';
import 'package:mad_miners/app/boot/loading_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('loading screen runs the boot and hands over to the app', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view
      ..physicalSize = const Size(740, 360)
      ..devicePixelRatio = 1;
    await tester.pumpWidget(const AppRoot());
    expect(find.byType(LoadingScreen), findsOneWidget);

    // Boot does real async work (asset decoding, prefs): give it real time.
    for (var i = 0; i < 40 && find.byType(LoadingScreen).evaluate().isNotEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);
    expect(find.byType(MadMinersApp), findsOneWidget);
    expect(find.byType(LoadingScreen), findsNothing);
    expect(find.text('PLAY AS GUEST'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
