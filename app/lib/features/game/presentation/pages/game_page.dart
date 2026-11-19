import 'package:flame/game.dart' show GameWidget;
import 'package:flutter/material.dart';
import 'package:mad_miners_core/mad_miners_core.dart';

import '../../../../app/di.dart';
import '../../domain/entities/game_target.dart';
import '../../domain/usecases/open_game_session.dart';
import '../controller/game_controller.dart';
import '../flame/mad_miners_game.dart';
import '../widgets/hud_overlay.dart';
import 'results_page.dart';

class GamePage extends StatefulWidget {
  const GamePage({super.key, required this.target});
  final GameTarget target;

  static Route<void> route(GameTarget target) =>
      MaterialPageRoute(builder: (_) => GamePage(target: target), fullscreenDialog: true);

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late final GameController _controller = GameController(sl<OpenGameSession>()(widget.target));
  late final MadMinersGame _game = MadMinersGame(_controller);
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _controller.result.addListener(_onResult);
    _controller.start();
  }

  void _onResult() {
    final r = _controller.result.value;
    if (r == null || _navigated || !mounted) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => ResultsPage(result: r, youId: _controller.youId)),
    );
  }

  Future<void> _confirmExit() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave the mine?'),
        content: const Text('Unsold ore is lost and this match won\'t count.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('STAY')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('LEAVE')),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _controller.result.removeListener(_onResult);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(child: GameWidget(game: _game, autofocus: true)),
            Positioned.fill(child: HudOverlay(controller: _controller, onExit: _confirmExit)),
          ],
        ),
      ),
    );
  }
}

/// Offline practice defaults: 1 human + 7 bots.
const offlinePracticeSettings = MatchSettings(durationSeconds: 300);
