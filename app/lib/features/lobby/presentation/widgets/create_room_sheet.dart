import 'package:flutter/material.dart';
import 'package:mad_miners_core/mad_miners_core.dart';

import '../../domain/entities/room.dart';

/// Room setup: map, mode, capacity (8–12), privacy. Bots fill empty seats.
class CreateRoomSheet extends StatefulWidget {
  const CreateRoomSheet({super.key, this.offline = false});
  final bool offline;

  @override
  State<CreateRoomSheet> createState() => _CreateRoomSheetState();
}

class _CreateRoomSheetState extends State<CreateRoomSheet> {
  MapId _map = MapId.starterMine;
  GameMode _mode = GameMode.competition;
  double _max = 12;
  bool _private = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.offline ? 'Practice match' : 'Create room', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            const Text('Mine'),
            const SizedBox(height: 6),
            SegmentedButton<MapId>(
              segments: [for (final m in MapId.values) ButtonSegment(value: m, label: Text(m.def.name, style: const TextStyle(fontSize: 12)))],
              selected: {_map},
              onSelectionChanged: (s) => setState(() => _map = s.first),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(_map.def.description, style: const TextStyle(fontSize: 12, color: Colors.white54)),
            ),
            const SizedBox(height: 14),
            const Text('Mode'),
            const SizedBox(height: 6),
            SegmentedButton<GameMode>(
              segments: [for (final m in GameMode.values) ButtonSegment(value: m, label: Text(m.label.split(' ').last, style: const TextStyle(fontSize: 12)))],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(_mode.description, style: const TextStyle(fontSize: 12, color: Colors.white54)),
            ),
            if (!widget.offline) ...[
              const SizedBox(height: 14),
              Text('Max miners: ${_max.round()}  (bots fill up to ${Balance.minPlayers})'),
              Slider(value: _max, min: 8, max: 12, divisions: 4, label: '${_max.round()}', onChanged: (v) => setState(() => _max = v)),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Private (invite by code)'),
                value: _private,
                onChanged: (v) => setState(() => _private = v),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(
                  context,
                  CreateRoomParams(mapId: _map, mode: _mode, maxPlayers: _max.round(), isPrivate: _private),
                ),
                child: Text(widget.offline ? 'START PRACTICE' : 'CREATE & ENTER'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
