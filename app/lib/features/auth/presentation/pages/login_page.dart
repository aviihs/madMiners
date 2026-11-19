import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme.dart';
import '../cubit/auth_cubit.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.state});
  final AuthSignedOut state;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _name = TextEditingController();
  late final _server = TextEditingController(text: widget.state.serverUrl);
  final _form = GlobalKey<FormState>();

  @override
  void dispose() {
    _name.dispose();
    _server.dispose();
    super.dispose();
  }

  String? _validateName(String? v) {
    final s = v?.trim() ?? '';
    if (!RegExp(r'^[A-Za-z0-9_ \-]{3,16}$').hasMatch(s)) return '3–16 letters, numbers, _ or -';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final busy = widget.state.busy;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.hardware, size: 64, color: MMColors.amber),
                  const SizedBox(height: 8),
                  Text(
                    'MAD MINERS',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                      color: MMColors.amber,
                    ),
                  ),
                  const Text('Multiplayer mining · 8–12 miners per room', textAlign: TextAlign.center, style: TextStyle(color: MMColors.muted)),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Miner name', prefixIcon: Icon(Icons.person)),
                    validator: _validateName,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _online(),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _server,
                    decoration: const InputDecoration(labelText: 'Server', prefixIcon: Icon(Icons.dns)),
                  ),
                  if (widget.state.error != null) ...[
                    const SizedBox(height: 12),
                    Text(widget.state.error!, style: const TextStyle(color: MMColors.health)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: busy ? null : _online,
                    icon: busy
                        ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.public),
                    label: const Text('PLAY ONLINE'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                    onPressed: busy ? null : () => context.read<AuthCubit>().playOffline(_name.text),
                    icon: const Icon(Icons.smart_toy_outlined),
                    label: const Text('PRACTICE OFFLINE VS BOTS'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _online() {
    if (_form.currentState?.validate() ?? false) {
      context.read<AuthCubit>().signInAsGuest(_name.text, _server.text);
    }
  }
}
