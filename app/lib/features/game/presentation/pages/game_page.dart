import 'package:flame/game.dart' show GameWidget;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Scaffold;
import 'package:mad_miners_core/mad_miners_core.dart';

import '../../../../app/audio.dart';
import '../../../../app/di.dart';
import '../../../../app/settings.dart';
import '../../../../app/theme.dart';
import '../../../../app/ui/ui.dart';
import '../../domain/entities/game_target.dart';
import '../../domain/usecases/open_game_session.dart';
import '../controller/game_controller.dart';
import '../flame/mad_miners_game.dart';
import '../widgets/hud_overlay.dart';
import 'results_view.dart';

/// Pops with `true` when the player taps "Play Again".
class GamePage extends StatefulWidget {
  const GamePage({super.key, required this.target});
  final GameTarget target;

  static Route<bool> route(GameTarget target) => CupertinoPageRoute<bool>(builder: (_) => GamePage(target: target), fullscreenDialog: true);

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late final GameController _controller = GameController(sl<OpenGameSession>()(widget.target), audio: sl<GameAudio>());
  late final MadMinersGame _game = MadMinersGame(_controller, highQuality: sl<GameSettings>().highGraphics.value);

  @override
  void initState() {
    super.initState();
    _controller.start();
    sl<GameAudio>().music(on: true);
  }

  Future<void> _confirmExit() async {
    final leave = await showConfirm(
      context,
      title: 'Leave the match?',
      message: 'Your progress in this match will be lost.',
      confirm: 'Leave',
      destructive: true,
    );
    if (leave && mounted) Navigator.of(context).pop(false);
  }

  @override
  void dispose() {
    sl<GameAudio>().music(on: false);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MatchResult?>(
      valueListenable: _controller.result,
      builder: (context, result, _) => PopScope(
        canPop: result != null,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _confirmExit();
        },
        child: Scaffold(
          backgroundColor: MMColors.bg,
          body: Stack(
            children: [
              Positioned.fill(child: GameWidget(game: _game, autofocus: true)),
              if (result == null)
                Positioned.fill(
                  child: HudOverlay(controller: _controller, onExit: _confirmExit),
                )
              else
                Positioned.fill(
                  child: ResultsView(
                    result: result,
                    youId: _controller.youId,
                    onLobby: () => Navigator.of(context).pop(false),
                    onPlayAgain: () => Navigator.of(context).pop(true),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
