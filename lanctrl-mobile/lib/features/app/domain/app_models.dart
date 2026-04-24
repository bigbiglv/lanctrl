enum AppSection { tasks, schedules, devices, relay }

enum FeatureTone { primary, danger }

enum ThemePreferenceMode { light, dark, system }

enum TaskOriginKind { pc, mobile }

class KnownDevice {
  const KnownDevice({
    required this.deviceId,
    required this.name,
    required this.ip,
    required this.port,
    this.lastSeenAt,
  });

  final String deviceId;
  final String name;
  final String ip;
  final int port;
  final int? lastSeenAt;

  factory KnownDevice.fromMap(Map<String, dynamic> map) {
    return KnownDevice(
      deviceId: map['deviceId'] as String? ?? '',
      name: map['name'] as String? ?? '未知设备',
      ip: map['ip'] as String? ?? '',
      port: (map['port'] as num?)?.toInt() ?? 3000,
      lastSeenAt: (map['lastSeenAt'] as num?)?.toInt(),
    );
  }
}

sealed class FeatureControl {
  const FeatureControl();
}

class ActionFeatureControl extends FeatureControl {
  const ActionFeatureControl({
    required this.buttonText,
    required this.tone,
    required this.confirmRequired,
  });

  final String buttonText;
  final FeatureTone tone;
  final bool confirmRequired;
}

class RangeFeatureControl extends FeatureControl {
  const RangeFeatureControl({
    required this.min,
    required this.max,
    required this.step,
    required this.unit,
    required this.actionText,
  });

  final int min;
  final int max;
  final int step;
  final String unit;
  final String actionText;
}

class FeatureDefinition {
  const FeatureDefinition({
    required this.featureKey,
    required this.title,
    required this.description,
    required this.mobileReady,
    required this.control,
  });

  final String featureKey;
  final String title;
  final String description;
  final bool mobileReady;
  final FeatureControl control;

  bool get isAction => control is ActionFeatureControl;
  bool get isRange => control is RangeFeatureControl;
}

class FeatureGroup {
  const FeatureGroup({
    required this.groupKey,
    required this.title,
    required this.description,
    required this.features,
  });

  final String groupKey;
  final String title;
  final String description;
  final List<FeatureDefinition> features;
}

class FeatureSnapshot {
  const FeatureSnapshot({required this.volumeLevel});

  final int volumeLevel;
}

class FeatureExecutionResult {
  const FeatureExecutionResult({
    required this.featureKey,
    required this.message,
    required this.volumeLevel,
  });

  final String featureKey;
  final String message;
  final int? volumeLevel;
}

class ScheduledTask {
  const ScheduledTask({
    required this.taskId,
    required this.title,
    required this.createdAtMs,
    required this.executeAtMs,
    required this.originKind,
    required this.originName,
    required this.feature,
    this.level,
    this.originClientId,
  });

  final String taskId;
  final String title;
  final int createdAtMs;
  final int executeAtMs;
  final TaskOriginKind originKind;
  final String originName;
  final String feature;
  final int? level;
  final String? originClientId;

  DateTime get executeAt => DateTime.fromMillisecondsSinceEpoch(executeAtMs);
}

class PendingCommandDraft {
  const PendingCommandDraft({required this.feature, this.level});

  final String feature;
  final int? level;
}
