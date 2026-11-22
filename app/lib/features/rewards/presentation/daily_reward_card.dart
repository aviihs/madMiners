import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/audio.dart';
import '../../../app/di.dart';
import '../../../app/theme.dart';
import '../../../app/ui/ui.dart';
import '../../../core/network/api_exception.dart';
import 'package:mad_miners_core/mad_miners_core.dart';

import '../../auth/presentation/cubit/auth_cubit.dart';
import '../data/rewards_remote_data_source.dart';

/// Lobby card for the daily login reward: a 7-day streak track and a Claim
/// button. Hides itself if the server can't be reached.
class DailyRewardCard extends StatefulWidget {
  const DailyRewardCard({super.key, required this.token});
  final String token;

  @override
  State<DailyRewardCard> createState() => _DailyRewardCardState();
}

class _DailyRewardCardState extends State<DailyRewardCard> {
  DailyRewardStatus? _status;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await sl<RewardsRemoteDataSource>().status(widget.token);
      if (mounted) setState(() => _status = s);
    } catch (_) {
      // Offline or old server: just don't show the card.
    }
  }

  Future<void> _claim() async {
    setState(() => _busy = true);
    try {
      final (s, profile) = await sl<RewardsRemoteDataSource>().claim(widget.token);
      if (!mounted) return;
      context.read<AuthCubit>().profileUpdated(profile);
      sl<GameAudio>()
        ..play(s.gems > 0 ? Sfx.gem : Sfx.coin)
        ..buzz(Haptic.medium);
      showToast(context, s.gems > 0 ? 'Day ${s.streak}: +${s.coins} coins and +${s.gems} gems!' : 'Day ${s.streak}: +${s.coins} coins!');
      setState(() => _status = s);
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message, error: true);
      await _load();
    } catch (_) {
      if (mounted) showToast(context, 'Could not reach the server.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _status;
    if (s == null) return const SizedBox.shrink();
    final today = (s.streak - 1) % 7 + 1;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GlassCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        gradient: const LinearGradient(colors: [Color(0xFF3B2580), Color(0xFF2A1D45)]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const IconTile(CupertinoIcons.gift_fill, color: MMColors.gold, size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Daily reward', style: MMText.headline),
                      Text(s.available ? 'Day $today is ready to claim' : 'Claimed today. Come back tomorrow!', style: MMText.caption),
                    ],
                  ),
                ),
                if (s.available)
                  GameButton(label: 'Claim', height: 38, fontSize: 15, loading: _busy, onPressed: _claim)
                else
                  const Icon(CupertinoIcons.checkmark_seal_fill, color: MMColors.leaf),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (var d = 1; d <= 7; d++)
                  Expanded(
                    child: _DayPip(day: d, done: d < today || (d == today && !s.available), current: d == today && s.available),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DayPip extends StatelessWidget {
  const _DayPip({required this.day, required this.done, required this.current});
  final int day;
  final bool done;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final r = dailyReward(day);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: done ? MMColors.leaf.withValues(alpha: 0.18) : (current ? MMColors.gold.withValues(alpha: 0.22) : MMColors.glass),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: current ? MMColors.gold : MMColors.hairline, width: current ? 1.5 : 1),
      ),
      child: Column(
        children: [
          Text('D$day', style: MMText.caption.copyWith(fontSize: 10)),
          const SizedBox(height: 2),
          if (r.gems > 0) const GemIcon(size: 14) else const CoinIcon(size: 14),
          Text('${r.gems > 0 ? r.gems : r.coins}', style: MMText.number.copyWith(fontSize: 11, color: MMColors.text)),
        ],
      ),
    );
  }
}
