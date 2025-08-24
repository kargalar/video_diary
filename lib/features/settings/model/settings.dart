class SettingsModel {
  final String? storageDirectory; // absolute path selected by user
  final int reminderHour; // 0-23
  final int reminderMinute; // 0-59

  const SettingsModel({required this.storageDirectory, required this.reminderHour, required this.reminderMinute});

  SettingsModel copyWith({String? storageDirectory, int? reminderHour, int? reminderMinute}) {
    return SettingsModel(storageDirectory: storageDirectory ?? this.storageDirectory, reminderHour: reminderHour ?? this.reminderHour, reminderMinute: reminderMinute ?? this.reminderMinute);
  }

  Map<String, dynamic> toJson() => {'storageDirectory': storageDirectory, 'reminderHour': reminderHour, 'reminderMinute': reminderMinute};

  factory SettingsModel.fromJson(Map<String, dynamic> json) => SettingsModel(storageDirectory: json['storageDirectory'] as String?, reminderHour: (json['reminderHour'] as num?)?.toInt() ?? 20, reminderMinute: (json['reminderMinute'] as num?)?.toInt() ?? 0);

  static const def = SettingsModel(storageDirectory: null, reminderHour: 20, reminderMinute: 0);
}
