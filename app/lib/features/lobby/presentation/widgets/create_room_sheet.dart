import 'package:flutter/cupertino.dart';
import 'package:mad_miners_core/mad_miners_core.dart';

import '../../../../app/theme.dart';
import '../../../../app/ui/ui.dart';
import '../../domain/entities/room.dart';
import 'room_visuals.dart';

/// Room setup: mine, mode, capacity (8–12), privacy. Empty seats are filled
/// automatically so the room is always lively.
class CreateRoomSheet extends StatefulWidget {
  const CreateRoomSheet({super.key, this.offline = false});
  final bool offline;

  @override
  State<CreateRoomSheet> createState() => _CreateRoomSheetState();
}

class _CreateRoomSheetState extends State<CreateRoomSheet> {
  MapId _map = MapId.starterMine;
  GameMode _mode = GameMode.treasureHunt;
  int _max = 12;
  bool _private = true;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.offline ? 'Practice Match' : 'Create Room', style: MMText.title, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(
            widget.offline ? 'You vs 7 miners, on this device.' : 'Invite friends with a code. Empty seats fill up automatically.',
            style: MMText.footnote,
            textAlign: TextAlign.center,
          ),
          const SectionHeader('Mine'),
          for (final m in MapId.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _MapOption(map: m, selected: m == _map, onTap: () => setState(() => _map = m)),
            ),
          const SectionHeader('Mode'),
          CupertinoSlidingSegmentedControl<GameMode>(
            groupValue: _mode,
            thumbColor: MMColors.surfaceHi,
            backgroundColor: MMColors.glass,
            children: {
              for (final m in GameMode.values)
                m: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(m.label, style: MMText.headline.copyWith(fontSize: 15))),
            },
            onValueChanged: (v) => setState(() => _mode = v ?? _mode),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(4, 8, 4, 0), child: Text(_mode.description, style: MMText.caption)),
          if (!widget.offline) ...[
            const SectionHeader('Players'),
            CupertinoSlidingSegmentedControl<int>(
              groupValue: _max,
              thumbColor: MMColors.surfaceHi,
              backgroundColor: MMColors.glass,
              children: {
                for (var n = 8; n <= 12; n++)
                  n: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('$n', style: MMText.headline.copyWith(fontSize: 15))),
              },
              onValueChanged: (v) => setState(() => _max = v ?? _max),
            ),
            const SizedBox(height: 16),
            GroupedList(
              children: [
                ListRow(
                  leading: const IconTile(CupertinoIcons.lock_fill, color: MMColors.blue, size: 30),
                  title: 'Private room',
                  subtitle: 'Only people with the code can join',
                  trailing: CupertinoSwitch(value: _private, activeTrackColor: MMColors.amber, onChanged: (v) => setState(() => _private = v)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          PrimaryButton(
            label: widget.offline ? 'Start Practice' : 'Create & Enter',
            onPressed: () => Navigator.pop(context, CreateRoomParams(mapId: _map, mode: _mode, maxPlayers: _max, isPrivate: _private)),
          ),
        ],
      ),
    );
  }
}

class _MapOption extends StatelessWidget {
  const _MapOption({required this.map, required this.selected, required this.onTap});
  final MapId map;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => PressableScale(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: selected ? MMColors.amber.withValues(alpha: 0.12) : MMColors.glass,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: selected ? MMColors.amber : MMColors.hairline, width: selected ? 1.5 : 0.5),
      ),
      child: Row(
        children: [
          MapThumb(map),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(map.def.name, style: MMText.headline),
                const SizedBox(height: 2),
                Text(map.def.description, style: MMText.caption, maxLines: 2),
              ],
            ),
          ),
          Text('${map.def.height - MapGenerator.surfaceRows}m', style: MMText.footnote),
          const SizedBox(width: 8),
          Icon(
            selected ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,
            color: selected ? MMColors.amber : MMColors.faint,
            size: 22,
          ),
        ],
      ),
    ),
  );
}
