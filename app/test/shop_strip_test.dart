import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mad_miners/features/game/presentation/widgets/shop_panel.dart';
import 'package:mad_miners_core/mad_miners_core.dart';

void main() {
  testWidgets('phone shop strip fits between the joystick and the buttons', (tester) async {
    tester.view
      ..physicalSize = const Size(740, 360)
      ..devicePixelRatio = 1;
    final sim = GameSimulation(settings: const MatchSettings(), seed: 1)..addHuman('me', 'Me');
    final me = sim.takeSnapshot().players.firstWhere((p) => p.id == 'me');
    await tester.pumpWidget(
      CupertinoApp(
        home: Stack(
          children: [
            Positioned(
              left: 190,
              right: 220,
              bottom: 10,
              child: ShopPanel(me: me, onUpgrade: (_) {}, onBuyItem: (_) {}, strip: true),
            ),
          ],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(ShopPanel)).height, lessThan(100));
  });
}
