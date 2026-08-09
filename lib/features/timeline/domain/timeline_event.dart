class TimelineEvent {
  const TimelineEvent({
    required this.id,
    required this.title,
    required this.eventType,
    required this.occurredAt,
    this.description,
  });

  factory TimelineEvent.fromJson(Map<String, dynamic> json) => TimelineEvent(
        id: json['id'] as String,
        title: json['title'] as String,
        eventType: json['event_type'] as String,
        occurredAt: DateTime.parse(json['occurred_at'] as String),
        description: json['description'] as String?,
      );

  final String id;
  final String title;
  final String eventType;
  final DateTime occurredAt;
  final String? description;
}
