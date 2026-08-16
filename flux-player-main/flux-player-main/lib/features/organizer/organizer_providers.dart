import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'organizer_service.dart';

final organizerServiceProvider =
    Provider<OrganizerService>((ref) => OrganizerService());

final organizeModeProvider =
    StateProvider<OrganizeMode>((ref) => OrganizeMode.recentlyAdded);
