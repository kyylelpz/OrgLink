import 'package:flutter/foundation.dart';
import '../../../../core/utils/live_query.dart';
import '../../data/models/event_registration.dart';
import '../../data/models/participant_identity.dart';
import '../../data/repositories/event_repository.dart';

class ParticipantsViewModel extends ChangeNotifier {
  ParticipantsViewModel(
    EventRepository repository,
    String organizationId,
    String eventId,
  ) {
    registrations = LiveQuery(
      () => repository.participants(organizationId, eventId),
    );
    identities = LiveQuery(
      () => repository.participantIdentities(organizationId, eventId),
    );
    registrations.addListener(notifyListeners);
    identities.addListener(_namesChanged);
  }
  late final LiveQuery<List<EventRegistration>> registrations;
  late final LiveQuery<List<ParticipantIdentity>> identities;
  Map<String, String> _names = {};
  void _namesChanged() {
    _names = {
      for (final identity in identities.value ?? <ParticipantIdentity>[])
        if (identity.fullName.trim().isNotEmpty)
          identity.uid: identity.fullName.trim(),
    };
    notifyListeners();
  }

  String nameFor(String uid) => _names[uid] ?? 'Unknown Participant';
  @override
  void dispose() {
    registrations.dispose();
    identities.dispose();
    super.dispose();
  }
}
