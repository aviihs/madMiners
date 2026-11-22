import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Scaffold;

import '../../../../app/audio.dart';
import '../../../../app/di.dart';
import '../../../../app/settings.dart';
import '../../../../app/theme.dart';
import '../../../../app/ui/ui.dart';

/// Sound, vibration and touch-control preferences (saved on this device).
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final st = sl<GameSettings>();
    final audio = sl<GameAudio>();
    return Scaffold(
      body: AppBackground(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            const CupertinoSliverNavigationBar(
              largeTitle: Text('Settings'),
              previousPageTitle: 'Lobby',
              backgroundColor: Color(0xE6120E1F),
              border: null,
            ),
            SliverSafeArea(
              top: false,
              sliver: SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                sliver: SliverList.list(
                  children: [
                    const SectionHeader('Sound'),
                    _Card(
                      children: [
                        _Toggle(icon: CupertinoIcons.music_note_2, color: MMColors.violet, label: 'Music', value: st.music),
                        _Toggle(
                          icon: CupertinoIcons.speaker_2_fill,
                          color: MMColors.sky,
                          label: 'Sound effects',
                          value: st.sfx,
                          onChanged: (v) {
                            if (v) audio.play(Sfx.coin);
                          },
                        ),
                        _Toggle(
                          icon: CupertinoIcons.waveform,
                          color: MMColors.leaf,
                          label: 'Vibration',
                          value: st.vibration,
                          onChanged: (v) {
                            if (v) audio.buzz(Haptic.medium);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const SectionHeader('Graphics'),
                    _Card(
                      children: [
                        _Toggle(
                          icon: CupertinoIcons.sparkles,
                          color: MMColors.violet,
                          label: 'High quality graphics',
                          value: st.highGraphics,
                        ),
                        const Padding(
                          padding: EdgeInsets.fromLTRB(14, 0, 14, 12),
                          child: Text(
                            'More lights, particles and frosted-glass menus. Turn off if the game feels slow on your phone.',
                            style: MMText.caption,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const SectionHeader('Touch controls'),
                    _Card(
                      children: [
                        ValueListenableBuilder<double>(
                          valueListenable: st.controlScale,
                          builder: (context, v, _) => Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const IconTile(CupertinoIcons.hand_draw_fill, color: MMColors.gold, size: 30),
                                    const SizedBox(width: 12),
                                    const Expanded(child: Text('Button size', style: MMText.headline)),
                                    Text('${(v * 100).round()}%', style: MMText.number.copyWith(color: MMColors.gold, fontSize: 16)),
                                  ],
                                ),
                                CupertinoSlider(
                                  value: v,
                                  min: GameSettings.minScale,
                                  max: GameSettings.maxScale,
                                  divisions: 12,
                                  activeColor: MMColors.gold,
                                  onChanged: (x) => st.controlScale.value = x,
                                ),
                              ],
                            ),
                          ),
                        ),
                        _Toggle(
                          icon: CupertinoIcons.arrow_right_arrow_left,
                          color: MMColors.lava,
                          label: 'Left-handed (buttons on the left)',
                          value: st.leftHanded,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const SectionHeader('Keyboard'),
                    const _Card(
                      children: [
                        Padding(
                          padding: EdgeInsets.all(14),
                          child: Text(
                            'A / D  run      W  jump · climb a shaft      S  aim down\n'
                            'Shift  jetpack      Space  dig      B  bomb      N  dynamite',
                            style: MMText.footnote,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => GlassCard(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Column(children: children),
  );
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.icon, required this.color, required this.label, required this.value, this.onChanged});
  final IconData icon;
  final Color color;
  final String label;
  final ValueNotifier<bool> value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: value,
    builder: (context, v, _) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          IconTile(icon, color: color, size: 30),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: MMText.headline)),
          CupertinoSwitch(
            value: v,
            activeTrackColor: MMColors.leaf,
            onChanged: (x) {
              value.value = x;
              onChanged?.call(x);
            },
          ),
        ],
      ),
    ),
  );
}
