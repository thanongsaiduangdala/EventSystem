class SponserModel {
  final int id;
  final String name;
  final String logoPath;

  SponserModel({required this.id, required this.name, required this.logoPath});

  factory SponserModel.fromJson(Map<String, dynamic> json) {
    return SponserModel(
      id: json['SponserID'] as int,
      name: json['SponserName']?.toString() ?? '',
      logoPath: json['SponserLogoPath']?.toString() ?? '',
    );
  }
}

/// A link between an Event and a Sponsor (the `eventsponserinfo` join table).
class EventSponserModel {
  final int id;
  final int eventId;
  final int sponserId;

  EventSponserModel({
    required this.id,
    required this.eventId,
    required this.sponserId,
  });

  factory EventSponserModel.fromJson(Map<String, dynamic> json) {
    return EventSponserModel(
      id: json['EventSponserID'] as int,
      eventId: json['EventID'] as int,
      sponserId: json['SponserID'] as int,
    );
  }
}
