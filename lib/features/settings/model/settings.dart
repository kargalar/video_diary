class SettingsModel {
  final String? storageDirectory; // absolute path selected by user
  final int reminderHour; // 0-23
  final int reminderMinute; // 0-59
  final bool reminderEnabled; // whether daily reminder is enabled
  final bool landscape; // preferred orientation for recording

  const SettingsModel({required this.storageDirectory, required this.reminderHour, required this.reminderMinute, required this.reminderEnabled, required this.landscape});

  SettingsModel copyWith({String? storageDirectory, int? reminderHour, int? reminderMinute, bool? reminderEnabled, bool? landscape}) {
    return SettingsModel(storageDirectory: storageDirectory ?? this.storageDirectory, reminderHour: reminderHour ?? this.reminderHour, reminderMinute: reminderMinute ?? this.reminderMinute, reminderEnabled: reminderEnabled ?? this.reminderEnabled, landscape: landscape ?? this.landscape);
  }

  Map<String, dynamic> toJson() => {'storageDirectory': storageDirectory, 'reminderHour': reminderHour, 'reminderMinute': reminderMinute, 'reminderEnabled': reminderEnabled, 'landscape': landscape};

  factory SettingsModel.fromJson(Map<String, dynamic> json) => SettingsModel(
    storageDirectory: json['storageDirectory'] as String?,
    reminderHour: (json['reminderHour'] as num?)?.toInt() ?? 20,
    reminderMinute: (json['reminderMinute'] as num?)?.toInt() ?? 0,
    reminderEnabled: json['reminderEnabled'] as bool? ?? false,
    landscape: json['landscape'] as bool? ?? false,
  );

  static const def = SettingsModel(storageDirectory: null, reminderHour: 20, reminderMinute: 0, reminderEnabled: false, landscape: false);
}
