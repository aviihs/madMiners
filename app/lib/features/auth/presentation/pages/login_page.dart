import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Scaffold;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mad_miners_core/mad_miners_core.dart';

import '../../../../app/di.dart';
import '../../../../app/theme.dart';
import '../../../../app/ui/ui.dart';
import '../../../../core/config/google_config.dart';
import '../../../../core/config/server_config.dart';
import '../../../store/presentation/widgets/avatar_preview.dart';
import '../../domain/usecases/auth_usecases.dart';
import '../cubit/auth_cubit.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.state});
  final AuthSignedOut state;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

enum _ServerStatus { checking, online, offline }

class _LoginPageState extends State<LoginPage> {
  final _name = TextEditingController();
  late final _server = TextEditingController(text: widget.state.serverUrl);
  final _checkServer = sl<CheckServer>();
  final _findServer = sl<FindServer>();
  var _status = _ServerStatus.checking;
  bool _searching = false;
  bool _editServer = false;
  bool _guestForm = false;
  String? _nameError;
  Timer? _debounce;

  /// The free server sleeps when idle; after a few seconds of "checking"
  /// tell the player it's waking up instead of leaving them guessing.
  bool _slow = false;
  Timer? _slowTimer;

  static const _dev = ServerConfig.canChangeServer;

  static final _validName = RegExp(r'^[A-Za-z0-9_ .\-]{3,16}$');

  @override
  void initState() {
    super.initState();
    _probe(autoFind: _dev);
    _server.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 600), _probe);
    });
  }

  @override
  void didUpdateWidget(LoginPage old) {
    super.didUpdateWidget(old);
    final err = widget.state.error;
    // didUpdateWidget runs during build: show the toast after this frame.
    if (err != null && err != old.state.error) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showToast(context, err, error: true);
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _slowTimer?.cancel();
    _name.dispose();
    _server.dispose();
    super.dispose();
  }

  Future<void> _probe({bool autoFind = false}) async {
    final url = _server.text;
    _checking();
    final ok = await _checkServer(url);
    if (!mounted || url != _server.text) return;
    _settled(ok ? _ServerStatus.online : _ServerStatus.offline);
    if (!ok && autoFind) await _autoFind();
  }

  void _checking() {
    _slowTimer?.cancel();
    _slowTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _status == _ServerStatus.checking) setState(() => _slow = true);
    });
    setState(() {
      _status = _ServerStatus.checking;
      _slow = false;
    });
  }

  void _settled(_ServerStatus status) {
    _slowTimer?.cancel();
    setState(() {
      _status = status;
      _slow = false;
    });
  }

  /// Looks for the server on localhost, the emulator host and the Wi-Fi.
  Future<void> _autoFind() async {
    if (_searching) return;
    setState(() => _searching = true);
    _checking();
    final found = await _findServer(_server.text);
    if (!mounted) return;
    setState(() => _searching = false);
    if (found == null) return _settled(_ServerStatus.offline);
    final changed = found != _server.text;
    _server.text = found;
    _debounce?.cancel();
    _settled(_ServerStatus.online);
    setState(() => _editServer = false);
    if (changed) showToast(context, 'Connected to ${found.replaceFirst('http://', '')}');
  }

  void _guest() {
    final ok = _validName.hasMatch(_name.text.trim());
    setState(() => _nameError = ok ? null : 'Use 3 to 16 letters or numbers');
    if (ok) context.read<AuthCubit>().signInAsGuest(_name.text, _server.text);
  }

  @override
  Widget build(BuildContext context) {
    final busy = widget.state.busy;
    final online = _status == _ServerStatus.online;
    final googleVisible = GoogleConfig.platformSupported;
    final form = <Widget>[
      if (!_guestForm) ...[
        if (googleVisible) ...[
          GameButton(
            label: 'Continue with Google',
            tone: ButtonTone.light,
            leading: const _GoogleMark(size: 22),
            fontSize: 17,
            loading: busy,
            onPressed: online ? () => context.read<AuthCubit>().signInWithGoogle(_server.text) : null,
          ),
          const SizedBox(height: 14),
        ],
        GameButton(
          label: 'Play as Guest',
          icon: CupertinoIcons.person_fill,
          onPressed: busy ? null : () => setState(() => _guestForm = true),
        ),
        const SizedBox(height: 14),
        GameButton(
          label: 'Practice Offline',
          icon: CupertinoIcons.game_controller_solid,
          tone: ButtonTone.dark,
          height: 52,
          fontSize: 17,
          onPressed: busy ? null : () => context.read<AuthCubit>().playOffline(_name.text.isEmpty ? 'Miner' : _name.text),
        ),
      ] else ...[
        Text('Pick a miner name', style: MMText.title.copyWith(fontSize: 22), textAlign: TextAlign.center),
        const SizedBox(height: 6),
        const Text('You can link Google later to keep your progress safe.', style: MMText.footnote, textAlign: TextAlign.center),
        const SizedBox(height: 18),
        AppTextField(
          controller: _name,
          placeholder: 'Username',
          icon: CupertinoIcons.person_fill,
          maxLength: 16,
          autofocus: true,
          onSubmitted: (_) => _guest(),
        ),
        if (_nameError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 6),
            child: Text(_nameError!, style: MMText.footnote.copyWith(color: MMColors.lava)),
          ),
        const SizedBox(height: 16),
        GameButton(label: 'Start Digging', loading: busy, onPressed: online ? _guest : null),
        const SizedBox(height: 10),
        CupertinoButton(
          onPressed: busy ? null : () => setState(() => _guestForm = false),
          child: const Text(
            'Back',
            style: TextStyle(fontFamily: MMFonts.body, fontWeight: FontWeight.w800, color: MMColors.muted),
          ),
        ),
      ],
      const SizedBox(height: 18),
      _serverRow(),
    ];
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: AppBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) {
              Widget formColumn(double maxWidth, EdgeInsets padding, List<Widget> children) => Center(
                child: SingleChildScrollView(
                  padding: padding,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
                  ),
                ),
              );
              if (box.maxWidth < box.maxHeight) {
                // Portrait (tablets mid-rotation, tests): stacked.
                return formColumn(400, const EdgeInsets.all(24), [const _Hero(), const SizedBox(height: 28), ...form]);
              }
              // Landscape: the miners on the left, the buttons on the right.
              return Row(
                children: [
                  Expanded(
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: _Hero(compact: box.maxHeight < 330),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: (box.maxWidth * 0.46).clamp(320, 420),
                    child: formColumn(380, const EdgeInsets.fromLTRB(8, 16, 24, 16), form),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _serverRow() => _dev ? _devServerRow() : _statusRow();

  /// Players: just the connection state, and a retry when it's down.
  Widget _statusRow() {
    final (color, label) = switch (_status) {
      _ServerStatus.checking => (MMColors.muted, _slow ? 'Waking up the server…' : 'Connecting…'),
      _ServerStatus.online => (MMColors.leaf, 'Servers online'),
      _ServerStatus.offline => (MMColors.lava, 'Can\'t reach the server'),
    };
    return GlassCard(
      radius: 16,
      padding: EdgeInsets.fromLTRB(14, 6, 6, 6),
      child: SizedBox(
        height: 38,
        child: Row(
          children: [
            _Dot(color: color, pulse: _status == _ServerStatus.checking),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: MMText.caption.copyWith(color: color == MMColors.muted ? MMColors.muted : color),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_status == _ServerStatus.checking)
              const Padding(padding: EdgeInsets.only(right: 10), child: CupertinoActivityIndicator(radius: 8)),
            if (_status == _ServerStatus.offline)
              SizedBox(
                width: 96,
                child: GameButton(label: 'Retry', tone: ButtonTone.dark, height: 34, fontSize: 14, onPressed: _probe),
              ),
          ],
        ),
      ),
    );
  }

  /// Developer builds: see and change which server the app talks to.
  Widget _devServerRow() {
    final (color, label) = switch (_status) {
      _ServerStatus.checking => (MMColors.muted, _searching ? 'Searching' : 'Checking'),
      _ServerStatus.online => (MMColors.leaf, 'Online'),
      _ServerStatus.offline => (MMColors.lava, 'Not found'),
    };
    return GlassCard(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      child: Column(
        children: [
          Row(
            children: [
              _Dot(color: color, pulse: _status == _ServerStatus.checking),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Server  ${_server.text.replaceFirst(RegExp('^https?://'), '')}',
                  style: MMText.caption.copyWith(color: MMColors.muted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(label.toUpperCase(), style: MMText.caption.copyWith(color: color, letterSpacing: 0.8)),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(32, 32),
                onPressed: () => setState(() => _editServer = !_editServer),
                child: Icon(
                  _editServer ? CupertinoIcons.checkmark_alt : CupertinoIcons.slider_horizontal_3,
                  size: 18,
                  color: MMColors.muted,
                ),
              ),
            ],
          ),
          if (_editServer)
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 4, 8, 8),
              child: AppTextField(
                controller: _server,
                placeholder: 'http://192.168.1.10:8080',
                keyboardType: TextInputType.url,
                autofocus: true,
              ),
            ),
          if (_status == _ServerStatus.offline && !_editServer)
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 2, 8, 10),
              child: Row(
                children: [
                  const Expanded(child: Text('Dev build: start the local server, or point to the live one.', style: MMText.caption)),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 110,
                    child: GameButton(label: 'Retry', tone: ButtonTone.dark, height: 38, fontSize: 14, onPressed: _autoFind),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({this.compact = false});

  /// Short landscape screens: drop the tagline.
  final bool compact;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        height: 190,
        width: 300,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [MMColors.gold.withValues(alpha: 0.28), MMColors.gold.withValues(alpha: 0)]),
              ),
            ),
            const Positioned(
              left: 0,
              bottom: 18,
              child: AvatarPreview(
                look: Look(character: 'char_maya', outfit: 'outfit_denim', helmet: 'helmet_white'),
                seed: 'a',
                size: 120,
              ),
            ),
            const Positioned(
              right: 0,
              bottom: 18,
              child: AvatarPreview(
                look: Look(character: 'char_bahadur', outfit: 'outfit_forest', helmet: 'helmet_cowboy', pickaxe: 'pick_ruby'),
                seed: 'b',
                size: 120,
              ),
            ),
            const Positioned(
              bottom: 6,
              child: AvatarPreview(look: Look.standard, seed: 'c', size: 150),
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      ShaderMask(
        shaderCallback: (r) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [MMColors.goldLight, MMColors.gold],
        ).createShader(r),
        child: const Text(
          'MAD MINERS',
          style: TextStyle(fontFamily: MMFonts.display, fontSize: 46, letterSpacing: 1.5, color: CupertinoColors.white, height: 1),
        ),
      ),
      if (!compact) ...[
        const SizedBox(height: 8),
        const Text('Dig deep. Dodge the lava.\nFind the treasure first.', textAlign: TextAlign.center, style: MMText.callout),
      ],
    ],
  );
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, this.pulse = false});
  final Color color;
  final bool pulse;

  @override
  Widget build(BuildContext context) => Container(
    width: 9,
    height: 9,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      boxShadow: [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: pulse ? 4 : 8)],
    ),
  );
}

/// Four-colour "G" mark drawn with arcs.
class _GoogleMark extends StatelessWidget {
  const _GoogleMark({this.size = 20});
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _GPainter());
}

class _GPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final r = s.width / 2;
    final c = Offset(r, r);
    final stroke = s.width * 0.2;
    final rect = Rect.fromCircle(center: c, radius: r - stroke / 2);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    void arc(Color color, double start, double sweep) {
      p.color = color;
      canvas.drawArc(rect, start, sweep, false, p);
    }

    arc(const Color(0xFFEA4335), -pi * 0.78, pi * 0.55);
    arc(const Color(0xFFFBBC05), -pi * 1.22, pi * 0.46);
    arc(const Color(0xFF34A853), pi * 0.25, pi * 0.55);
    arc(const Color(0xFF4285F4), -pi * 0.02, pi * 0.3);
    p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF4285F4);
    canvas.drawRect(Rect.fromLTWH(r, r - stroke / 2, r - stroke * 0.1, stroke), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
