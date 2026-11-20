import 'dart:async';

import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/audio.dart';
import 'app/di.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  unawaited(sl<GameAudio>().init());
  runApp(const MadMinersApp());
}
