// Renders key screens to PNG for visual review:
//   flutter test test/screenshots --dart-define=SHOTS=/some/dir --dart-define=FONTS=/path
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mad_miners/app/di.dart';
import 'package:mad_miners/app/theme.dart';
import 'package:mad_miners/features/auth/domain/entities/session.dart';
import 'package:mad_miners/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:mad_miners/features/auth/presentation/pages/login_page.dart';
import 'package:mad_miners/features/game/domain/entities/game_target.dart';
import 'package:mad_miners/features/game/presentation/pages/game_page.dart';
import 'package:mad_miners/features/auth/domain/entities/player_profile.dart';
import 'package:mad_miners/features/lobby/presentation/pages/lobby_page.dart';
import 'package:mad_miners/features/store/presentation/pages/store_page.dart';
import 'package:mad_miners_core/mad_miners_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

const shots = String.fromEnvironment('SHOTS');
const fonts = String.fromEnvironment('FONTS');
const cupertinoIcons = String.fromEnvironment('CI_FONT');

Future<void> _loadFont(String family, String path) async {
  final f = File(path);
  if (!f.existsSync()) return;
  final loader = FontLoader(family)..addFont(Future.value(ByteData.view(f.readAsBytesSync().buffer)));
  await loader.load();
}

Future<void> _snap(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot')));
  final bytes = await tester.runAsync(() async {
    final img = await boundary.toImage(pixelRatio: 1);
    return (await img.toByteData(format: ui.ImageByteFormat.png))!;
  });
  File('$shots/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
}

Widget _host(Widget child, AuthCubit cubit) => BlocProvider.value(
  value: cubit,
  child: RepaintBoundary(
    key: const ValueKey('shot'),
    child: MaterialApp(debugShowCheckedModeBanner: false, theme: buildTheme(), home: child),
  ),
);

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await configureDependencies();
    for (final fam in ['Roboto', '.SF Pro Text', '.SF Pro Display', 'CupertinoSystemText', 'CupertinoSystemDisplay', '.SF UI Text', '.SF UI Display']) {
      await _loadFont(fam, '$fonts/Roboto-Regular.ttf');
      await _loadFont(fam, '$fonts/Roboto-Medium.ttf');
      await _loadFont(fam, '$fonts/Roboto-Bold.ttf');
    }
    await _loadFont('MaterialIcons', '$fonts/MaterialIcons-Regular.otf');
    await _loadFont('packages/cupertino_icons/CupertinoIcons', cupertinoIcons);
  });

  testWidgets('screens', skip: shots.isEmpty, (tester) async {
    final cubit = sl<AuthCubit>();

    // Phone portrait.
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    await tester.pumpWidget(_host(const LoginPage(state: AuthSignedOut(serverUrl: 'http://localhost:8080')), cubit));
    await tester.pump(const Duration(seconds: 4));
    await _snap(tester, '1_login');

    await tester.pumpWidget(_host(LobbyPage(session: Session.offline('Shiva')), cubit));
    await tester.pump(const Duration(milliseconds: 500));
    await _snap(tester, '2_lobby_offline');

    cubit
      ..playOffline('Shiva')
      ..profileUpdated(const PlayerProfile(
        id: 'u1',
        username: 'Shiva',
        wallet: 820,
        gems: 75,
        owned: {'outfit_forest', 'helmet_viking'},
        look: Look(outfit: 'outfit_forest', helmet: 'helmet_viking', pickaxe: 'pick_wood'),
      ));
    await tester.pumpWidget(_host(const StorePage(token: 't'), cubit));
    await tester.pump(const Duration(milliseconds: 600));
    await _snap(tester, '2b_locker');

    // Phone landscape, in a match.
    tester.view.physicalSize = const Size(844, 390);
    await tester.pumpWidget(
      _host(
        const GamePage(target: OfflineTarget(playerName: 'Shiva', settings: MatchSettings(mapId: MapId.lavaMine))),
        cubit,
      ),
    );
    for (var i = 0; i < 60 * 3; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await _snap(tester, '3_game_lobby');
    for (var i = 0; i < 60 * 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await _snap(tester, '4_game_start');
    // Hold S + Space to dig straight down.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    for (var i = 0; i < 60 * 25; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await _snap(tester, '5_game_deep');
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  });
}
