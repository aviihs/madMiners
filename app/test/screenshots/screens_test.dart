// Renders key screens to PNG for visual review:
//   flutter test test/screenshots --dart-define=SHOTS=/some/dir --dart-define=FONTS=/path
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mad_miners/app/boot/loading_screen.dart';
import 'package:mad_miners/app/di.dart';
import 'package:mad_miners/app/theme.dart';
import 'package:mad_miners/features/auth/domain/entities/session.dart';
import 'package:mad_miners/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:mad_miners/features/auth/presentation/pages/login_page.dart';
import 'package:mad_miners/features/game/data/datasources/local_game_session.dart';
import 'package:mad_miners/features/game/domain/entities/game_target.dart';
import 'package:mad_miners/features/game/presentation/pages/game_page.dart';
import 'package:mad_miners/features/auth/domain/entities/player_profile.dart';
import 'package:mad_miners/features/lobby/presentation/pages/lobby_page.dart';
import 'package:mad_miners/features/profile/presentation/pages/profile_page.dart';
import 'package:mad_miners/features/store/presentation/pages/store_page.dart';
import 'package:mad_miners_core/mad_miners_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

const shots = String.fromEnvironment('SHOTS');
const fonts = String.fromEnvironment('FONTS');
const cupertinoIcons = String.fromEnvironment('CI_FONT');

/// Match screenshots: logical size and pixel ratio. Defaults to a small
/// phone; `--dart-define=HD=true` renders 1920x1080 (16:9, Play Store ready).
const hd = bool.fromEnvironment('HD');
const gameSize = hd ? Size(800, 450) : Size(844, 390);
const menuSize = Size(740, 360);
const gameDpr = hd ? 2.4 : 1.0;
double _snapRatio = 1;

Future<void> _loadFont(String family, String path) async {
  final f = File(path);
  if (!f.existsSync()) return;
  final loader = FontLoader(family)..addFont(Future.value(ByteData.view(f.readAsBytesSync().buffer)));
  await loader.load();
}

Future<void> _snap(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot')));
  final bytes = await tester.runAsync(() async {
    final img = await boundary.toImage(pixelRatio: _snapRatio);
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
    for (final fam in [
      'Roboto',
      '.SF Pro Text',
      '.SF Pro Display',
      'CupertinoSystemText',
      'CupertinoSystemDisplay',
      '.SF UI Text',
      '.SF UI Display',
    ]) {
      await _loadFont(fam, '$fonts/Roboto-Regular.ttf');
      await _loadFont(fam, '$fonts/Roboto-Medium.ttf');
      await _loadFont(fam, '$fonts/Roboto-Bold.ttf');
    }
    await _loadFont('MaterialIcons', '$fonts/MaterialIcons-Regular.otf');
    await _loadFont('Lilita', 'assets/fonts/LilitaOne-Regular.ttf');
    for (final w in ['Medium', 'SemiBold', 'Bold', 'ExtraBold', 'Black']) {
      await _loadFont('Nunito', 'assets/fonts/Nunito-$w.ttf');
    }
    await _loadFont('packages/cupertino_icons/CupertinoIcons', cupertinoIcons);
  });

  testWidgets('screens', skip: shots.isEmpty, (tester) async {
    LocalGameSession.runOnMainThread = true; // fake clock: keep the sim on this thread
    final cubit = sl<AuthCubit>();

    // The whole app is landscape. A small phone (740x360) shows overflows first.
    tester.view
      ..physicalSize = menuSize
      ..devicePixelRatio = 1;

    final progress = ValueNotifier<double>(0.64);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('shot'),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: LoadingScreen(progress: progress, showArt: true),
        ),
      ),
    );
    await tester.runAsync(() async {
      for (final a in LoadingArt.all) {
        await precacheImage(a, tester.element(find.byType(LoadingScreen)));
      }
    });
    await tester.pump(const Duration(seconds: 1));
    await _snap(tester, '0_loading');
    await tester.pumpWidget(_host(const LoginPage(state: AuthSignedOut(serverUrl: 'http://localhost:8080')), cubit));
    await tester.pump(const Duration(seconds: 4));
    await _snap(tester, '1_login');

    const me = PlayerProfile(
      id: 'u1',
      username: 'Shiva',
      level: 7,
      xp: 900,
      wallet: 1820,
      gems: 75,
      wins: 12,
      bestScore: 1430,
      bestDepth: 84,
      gamesPlayed: 41,
      oresMined: 388,
      totalCoins: 9640,
      providers: ['guest'],
      owned: {'outfit_forest', 'helmet_viking', 'char_bahadur'},
      look: Look(character: 'char_bahadur', outfit: 'outfit_forest', helmet: 'helmet_viking'),
    );
    await tester.pumpWidget(
      _host(
        LobbyPage(
          session: const Session(profile: me, token: 't', serverUrl: 'http://x'),
        ),
        cubit,
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump(const Duration(milliseconds: 500));
    await _snap(tester, '2_lobby');
    await tester.pumpWidget(_host(LobbyPage(session: Session.offline('Shiva')), cubit));
    await tester.pump(const Duration(milliseconds: 500));
    await _snap(tester, '2a_lobby_offline');
    await tester.tap(find.text('Custom practice'));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await _snap(tester, '2d_create_sheet');
    Navigator.of(tester.element(find.text('Practice Match'))).pop();
    await tester.pump(const Duration(seconds: 1));

    cubit
      ..playOffline('Shiva')
      ..profileUpdated(me);
    await tester.pumpWidget(_host(const StorePage(token: 't'), cubit));
    await tester.pump(const Duration(milliseconds: 600));
    await _snap(tester, '2b_locker');
    await tester.pumpWidget(_host(const ProfilePage(token: 't'), cubit));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump(const Duration(milliseconds: 600));
    await _snap(tester, '2c_profile');

    // Phone landscape, in a match.
    tester.view
      ..physicalSize = gameSize * gameDpr
      ..devicePixelRatio = gameDpr;
    _snapRatio = gameDpr;
    await tester.pumpWidget(
      _host(
        const GamePage(
          target: OfflineTarget(
            playerName: 'Shiva',
            settings: MatchSettings(mapId: MapId.lavaMine),
          ),
        ),
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
