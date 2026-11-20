import 'package:tinda360/features/chat/presentation/chat_notifier.dart';
import 'package:tinda360/features/chat/presentation/clarification_reply.dart';

Map<String, Object?> chatMessageToJson(ChatMessage message) =>
    <String, Object?>{
      'id': message.id,
      'role': message.role.name,
      'text': message.text,
      'source': message.source,
      'created_at_ms': message.createdAt.millisecondsSinceEpoch,
      'clarified_query': ?message.clarifiedQuery,
      if (message.options.isNotEmpty)
        'options': <Map<String, String>>[
          for (final option in message.options)
            <String, String>{'tool': option.toolName, 'label': option.label},
        ],
    };

List<ClarificationOption> _optionsFromJson(Object? rawOptions) {
  if (rawOptions is! List) return const <ClarificationOption>[];
  return <ClarificationOption>[
    for (final rawOption in rawOptions)
      if (rawOption case {
        'tool': final String toolName,
        'label': final String label,
      })
        ClarificationOption(toolName: toolName, label: label),
  ];
}

ChatMessage? chatMessageFromJson(Map<String, Object?> json) {
  final id = json['id'];
  final role = json['role'];
  final text = json['text'];
  final createdAtMs = json['created_at_ms'];
  if (id is! String || text is! String || createdAtMs is! int) return null;
  final parsedRole = ChatRole.values.where((value) => value.name == role);
  if (parsedRole.isEmpty) return null;
  final source = json['source'];
  final clarifiedQuery = json['clarified_query'];
  return ChatMessage(
    id: id,
    role: parsedRole.first,
    text: text,
    source: source is String ? source : null,
    createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtMs),
    options: _optionsFromJson(json['options']),
    clarifiedQuery: clarifiedQuery is String ? clarifiedQuery : null,
  );
}
