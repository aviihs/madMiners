import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Scaffold;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di.dart';
import '../../../../app/theme.dart';
import '../../../../app/ui/ui.dart';
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
  bool _searching = false;
  var _status = _ServerStatus.checking;
  bool _editServer = false;
  String? _nameError;
  Timer? _debounce;

  static final _validName = RegExp(r'^[A-Za-z0-9_ .\-]{3,16}$');

  @override
  void initState() {
    super.initState();
    _probe(autoFind: true);
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

  Future<void> _probe({bool autoFind = false}) async {
    final url = _server.text;
    if (_status != _ServerStatus.checking) setState(() => _status = _ServerStatus.checking);
    final ok = await _checkServer(url);
    if (!mounted || url != _server.text) return;
    setState(() => _status = ok ? _ServerStatus.online : _ServerStatus.offline);
    if (!ok && autoFind) await _autoFind();
  }

  /// Looks for the server on localhost, the emulator host and the Wi‑Fi.
  Future<void> _autoFind() async {
    if (_searching) return;
    setState(() {
      _searching = true;
      _status = _ServerStatus.checking;
    });
    final found = await _findServer(_server.text);
    if (!mounted) return;
    setState(() => _searching = false);
    if (found == null) {
      setState(() => _status = _ServerStatus.offline);
      return;
    }
    final changed = found != _server.text;
    _debounce?.cancel();
    _server.text = found; // listener re-probes; cancel that below
    _debounce?.cancel();
    setState(() {
      _status = _ServerStatus.online;
      _editServer = false;
    });
    if (changed) showToast(context, 'Found the game server at ${found.replaceFirst('http://', '')}');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _name.dispose();
    _server.dispose();
    super.dispose();
  }

  bool _validate() {
    final ok = _validName.hasMatch(_name.text.trim());
    setState(() => _nameError = ok ? null : 'Use 3–16 letters or numbers');
    return ok;
  }

  void _online() {
    if (_validate()) context.read<AuthCubit>().signInAsGuest(_name.text, _server.text);
  }

  void _offline() => context.read<AuthCubit>().playOffline(_name.text);

  @override
  Widget build(BuildContext context) {
    final busy = widget.state.busy;
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: AppLogo()),
                    const SizedBox(height: 22),
                    const Text('Mad Miners', textAlign: TextAlign.center, style: MMText.largeTitle),
                    const SizedBox(height: 6),
                    const Text(
                      'Dig deep. Dodge the lava.\nFind the treasure before anyone else.',
                      textAlign: TextAlign.center,
                      style: MMText.callout,
                    ),
                    const SizedBox(height: 36),
                    AppTextField(
                      controller: _name,
                      placeholder: 'Choose a username',
                      icon: CupertinoIcons.person_fill,
                      maxLength: 16,
                      onSubmitted: (_) => _online(),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      child: _nameError == null
                          ? const SizedBox(width: double.infinity)
                          : Padding(
                              padding: const EdgeInsets.only(top: 8, left: 4),
                              child: Text(_nameError!, style: MMText.footnote.copyWith(color: MMColors.health)),
                            ),
                    ),
                    const SizedBox(height: 12),
                    _serverRow(),
                    const SizedBox(height: 28),
                    PrimaryButton(
                      label: 'Play Online',
                      icon: CupertinoIcons.globe,
                      loading: busy,
                      onPressed: _status == _ServerStatus.offline ? null : _online,
                    ),
                    const SizedBox(height: 12),
                    SecondaryButton(label: 'Practice Offline', icon: CupertinoIcons.game_controller, onPressed: busy ? null : _offline),
                    const SizedBox(height: 20),
                    const Text('8–12 miners per match', textAlign: TextAlign.center, style: MMText.caption),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _serverRow() {
    final (color, label) = switch (_status) {
      _ServerStatus.checking => (MMColors.muted, _searching ? 'Searching…' : 'Checking…'),
      _ServerStatus.online => (MMColors.stamina, 'Online'),
      _ServerStatus.offline => (MMColors.health, 'Unreachable'),
    };
    return GlassCard(
      radius: 14,
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      child: Column(
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _server.text.replaceFirst(RegExp('^https?://'), ''),
                  style: MMText.footnote.copyWith(color: MMColors.text),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(label, style: MMText.footnote.copyWith(color: color)),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(32, 32),
                onPressed: () => setState(() => _editServer = !_editServer),
                child: Icon(_editServer ? CupertinoIcons.checkmark_alt : CupertinoIcons.pencil, size: 18),
              ),
            ],
          ),
          if (_editServer)
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 4, 8, 8),
              child: AppTextField(controller: _server, placeholder: 'http://192.168.1.10:8080', keyboardType: TextInputType.url, autofocus: true),
            ),
          if (_status == _ServerStatus.offline && !_editServer)
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Server not found. Start it on your computer (dart run bin/server.dart) and keep this device on the same Wi‑Fi.',
                    style: MMText.caption,
                  ),
                  const SizedBox(height: 8),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: const Size(0, 32),
                    color: MMColors.glassStrong,
                    borderRadius: BorderRadius.circular(99),
                    onPressed: _autoFind,
                    child: const Text('Search again', style: TextStyle(fontSize: 14, color: MMColors.amber, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
