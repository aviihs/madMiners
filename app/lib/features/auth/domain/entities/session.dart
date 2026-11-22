import 'package:equatable/equatable.dart';

import 'player_profile.dart';

/// Who is playing. Offline sessions play locally against bots only.
class Session extends Equatable {
  const Session({required this.profile, this.token, this.serverUrl});

  Session.offline(String name) : profile = PlayerProfile(id: 'local-player', username: name), token = null, serverUrl = null;

  final PlayerProfile profile;
  final String? token;
  final String? serverUrl;

  bool get isOnline => token != null;

  Session copyWith({PlayerProfile? profile}) => Session(profile: profile ?? this.profile, token: token, serverUrl: serverUrl);

  @override
  List<Object?> get props => [profile, token, serverUrl];
}
