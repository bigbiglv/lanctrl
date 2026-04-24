import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/storage_service.dart';
import '../../core/theme/app_theme.dart';
import '../device/data/auth_api.dart';
import '../device/data/discovery_service.dart';
import '../device/data/session_socket_service.dart';
import 'domain/app_models.dart';

class AppViewState {
  const AppViewState({
    required this.theme,
    required this.themeMode,
    required this.section,
    required this.knownDevices,
    required this.onlineStatus,
    required this.featureGroups,
    required this.scheduledTasks,
    this.snapshot,
    this.activeDeviceId,
    this.connectedDeviceId,
    this.activeFeatureKey,
    this.volumeDraft = 0,
    this.initialized = false,
    this.isProbing = false,
    this.isPairing = false,
    this.isConnecting = false,
    this.isRefreshingRemote = false,
    this.isCreatingTask = false,
  });

  final AppThemeDefinition theme;
  final ThemePreferenceMode themeMode;
  final AppSection section;
  final List<KnownDevice> knownDevices;
  final Map<String, bool> onlineStatus;
  final List<FeatureGroup> featureGroups;
  final List<ScheduledTask> scheduledTasks;
  final FeatureSnapshot? snapshot;
  final String? activeDeviceId;
  final String? connectedDeviceId;
  final String? activeFeatureKey;
  final int volumeDraft;
  final bool initialized;
  final bool isProbing;
  final bool isPairing;
  final bool isConnecting;
  final bool isRefreshingRemote;
  final bool isCreatingTask;

  KnownDevice? get activeDevice {
    if (activeDeviceId == null) {
      return null;
    }

    for (final device in knownDevices) {
      if (device.deviceId == activeDeviceId) {
        return device;
      }
    }
    return null;
  }

  bool get hasActiveSession {
    return activeDeviceId != null &&
        connectedDeviceId != null &&
        activeDeviceId == connectedDeviceId;
  }

  AppViewState copyWith({
    AppThemeDefinition? theme,
    ThemePreferenceMode? themeMode,
    AppSection? section,
    List<KnownDevice>? knownDevices,
    Map<String, bool>? onlineStatus,
    List<FeatureGroup>? featureGroups,
    List<ScheduledTask>? scheduledTasks,
    FeatureSnapshot? snapshot,
    bool replaceSnapshot = false,
    String? activeDeviceId,
    bool clearActiveDeviceId = false,
    String? connectedDeviceId,
    bool clearConnectedDeviceId = false,
    String? activeFeatureKey,
    bool clearActiveFeatureKey = false,
    int? volumeDraft,
    bool? initialized,
    bool? isProbing,
    bool? isPairing,
    bool? isConnecting,
    bool? isRefreshingRemote,
    bool? isCreatingTask,
  }) {
    return AppViewState(
      theme: theme ?? this.theme,
      themeMode: themeMode ?? this.themeMode,
      section: section ?? this.section,
      knownDevices: knownDevices ?? this.knownDevices,
      onlineStatus: onlineStatus ?? this.onlineStatus,
      featureGroups: featureGroups ?? this.featureGroups,
      scheduledTasks: scheduledTasks ?? this.scheduledTasks,
      snapshot: replaceSnapshot ? snapshot : (snapshot ?? this.snapshot),
      activeDeviceId:
          clearActiveDeviceId ? null : (activeDeviceId ?? this.activeDeviceId),
      connectedDeviceId: clearConnectedDeviceId
          ? null
          : (connectedDeviceId ?? this.connectedDeviceId),
      activeFeatureKey: clearActiveFeatureKey
          ? null
          : (activeFeatureKey ?? this.activeFeatureKey),
      volumeDraft: volumeDraft ?? this.volumeDraft,
      initialized: initialized ?? this.initialized,
      isProbing: isProbing ?? this.isProbing,
      isPairing: isPairing ?? this.isPairing,
      isConnecting: isConnecting ?? this.isConnecting,
      isRefreshingRemote: isRefreshingRemote ?? this.isRefreshingRemote,
      isCreatingTask: isCreatingTask ?? this.isCreatingTask,
    );
  }
}

class AppController extends Notifier<AppViewState> {
  StreamSubscription<List<LanDevice>>? _discoverySubscription;
  bool _bootstrapped = false;

  StorageService get _storage => ref.read(storageServiceProvider);
  AuthApi get _authApi => ref.read(authApiProvider);

  @override
  AppViewState build() {
    ref.onDispose(() {
      _discoverySubscription?.cancel();
      unawaited(ref.read(discoveryServiceProvider).stop());
      unawaited(SessionSocketService.instance.close());
    });

    final theme = themeFromStorage(_storage.themeId);
    final themeMode = themePreferenceModeFromStorage(_storage.themeMode);
    final knownDevices = _loadKnownDevices();

    if (!_bootstrapped) {
      _bootstrapped = true;
      Future<void>.microtask(initialize);
    }

    return AppViewState(
      theme: theme,
      themeMode: themeMode,
      section: AppSection.tasks,
      knownDevices: knownDevices,
      onlineStatus: const <String, bool>{},
      featureGroups: const <FeatureGroup>[],
      scheduledTasks: const <ScheduledTask>[],
      activeDeviceId: _storage.activeDeviceId,
      volumeDraft: 0,
    );
  }

  Future<void> initialize() async {
    final discoveryService = ref.read(discoveryServiceProvider);
    _discoverySubscription?.cancel();
    _discoverySubscription = discoveryService.devicesStream.listen(
      (devices) => _handleDiscoveredDevices(devices, autoConnectActive: true),
    );

    await discoveryService.start();
    state = state.copyWith(initialized: true);
  }

  void _handleDiscoveredDevices(
    List<LanDevice> discoveredDevices, {
    bool autoConnectActive = false,
  }) {
    final discoveredIds = discoveredDevices
        .map((device) => device.deviceId)
        .where((deviceId) => deviceId.isNotEmpty)
        .toSet();
    final refreshedDevices = _loadKnownDevices();
    final nextStatus = <String, bool>{
      for (final device in refreshedDevices)
        device.deviceId: discoveredIds.contains(device.deviceId),
    };

    KnownDevice? activeDevice;
    for (final device in refreshedDevices) {
      if (device.deviceId == state.activeDeviceId) {
        activeDevice = device;
        break;
      }
    }

    state = state.copyWith(
      knownDevices: refreshedDevices,
      onlineStatus: nextStatus,
      clearConnectedDeviceId: state.connectedDeviceId != null &&
          nextStatus[state.connectedDeviceId] != true,
      clearActiveDeviceId: state.activeDeviceId != null && activeDevice == null,
    );

    if (autoConnectActive &&
        activeDevice != null &&
        nextStatus[activeDevice.deviceId] == true &&
        !state.hasActiveSession) {
      unawaited(connectToDevice(activeDevice, silent: true));
    }
  }

  Future<void> probeDevices({bool autoConnectActive = false}) async {
    if (state.isProbing) {
      return;
    }

    state = state.copyWith(isProbing: true);

    final currentDevices = _loadKnownDevices();
    final nextStatus = <String, bool>{};

    for (final device in currentDevices) {
      if (device.ip.isEmpty || device.deviceId.isEmpty) {
        nextStatus[device.deviceId] = false;
        continue;
      }

      nextStatus[device.deviceId] = await _authApi.verifyDevice(device);
    }

    final refreshedDevices = _loadKnownDevices();
    final onlineIds = nextStatus.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toSet();
    KnownDevice? activeDevice;
    for (final device in refreshedDevices) {
      if (device.deviceId == state.activeDeviceId) {
        activeDevice = device;
        break;
      }
    }

    state = state.copyWith(
      knownDevices: refreshedDevices,
      onlineStatus: nextStatus,
      isProbing: false,
      clearConnectedDeviceId: state.connectedDeviceId != null &&
          !onlineIds.contains(state.connectedDeviceId),
      clearActiveDeviceId: state.activeDeviceId != null && activeDevice == null,
    );

    if (autoConnectActive &&
        activeDevice != null &&
        nextStatus[activeDevice.deviceId] == true &&
        !state.hasActiveSession) {
      await connectToDevice(activeDevice, silent: true);
    }
  }

  Future<String?> connectToDevice(
    KnownDevice device, {
    bool silent = false,
  }) async {
    if (state.isConnecting) {
      return null;
    }

    state = state.copyWith(isConnecting: true);

    final connected = await _authApi.connectDevice(device);
    if (!connected) {
      state = state.copyWith(isConnecting: false);
      return '连接失败，请确认电脑在线且已经授权';
    }

    final socketConnected = await SessionSocketService.instance.connect(
      device,
      _storage,
    );
    if (!socketConnected) {
      state = state.copyWith(isConnecting: false);
      return '会话通道建立失败，请稍后重试';
    }

    await _storage.setActiveDeviceId(device.deviceId);
    state = state.copyWith(
      activeDeviceId: device.deviceId,
      connectedDeviceId: device.deviceId,
      isConnecting: false,
      section: AppSection.tasks,
    );

    await refreshRemoteState();
    return silent ? null : '已连接到 ${device.name}';
  }

  Future<String?> disconnectActiveDevice() async {
    final device = state.activeDevice;
    if (device == null) {
      return null;
    }

    await SessionSocketService.instance.close();
    await _authApi.disconnectDevice(device);
    await clearLocalSession();
    return '连接已断开';
  }

  Future<void> clearLocalSession() async {
    await SessionSocketService.instance.close();
    await _storage.setActiveDeviceId(null);
    state = state.copyWith(
      clearActiveDeviceId: true,
      clearConnectedDeviceId: true,
      featureGroups: const <FeatureGroup>[],
      scheduledTasks: const <ScheduledTask>[],
      replaceSnapshot: true,
      snapshot: null,
      volumeDraft: 0,
    );
  }

  Future<String?> forgetDevice(KnownDevice device) async {
    if (state.activeDeviceId == device.deviceId) {
      await SessionSocketService.instance.close();
      await _authApi.disconnectDevice(device);
      await _storage.setActiveDeviceId(null);
    }

    await _storage.removeDevice(device.deviceId);
    final nextStatus = Map<String, bool>.from(state.onlineStatus)
      ..remove(device.deviceId);

    state = state.copyWith(
      knownDevices: _loadKnownDevices(),
      onlineStatus: nextStatus,
      clearActiveDeviceId: state.activeDeviceId == device.deviceId,
      clearConnectedDeviceId: state.connectedDeviceId == device.deviceId,
      featureGroups: state.activeDeviceId == device.deviceId
          ? const <FeatureGroup>[]
          : null,
      scheduledTasks: state.activeDeviceId == device.deviceId
          ? const <ScheduledTask>[]
          : null,
      replaceSnapshot: state.activeDeviceId == device.deviceId,
      snapshot: null,
      volumeDraft:
          state.activeDeviceId == device.deviceId ? 0 : state.volumeDraft,
    );
    return '已忘记 ${device.name}';
  }

  Future<String?> pairDiscoveredDevice(LanDevice device) async {
    state = state.copyWith(isPairing: true);
    final token = await _authApi.pairDevice(
      device.ip,
      device.port,
      device.name,
      device.deviceId,
    );
    state = state.copyWith(isPairing: false);

    if (token == null) {
      return '配对失败，请在电脑端确认请求';
    }

    state = state.copyWith(knownDevices: _loadKnownDevices());
    await probeDevices();
    return '配对成功，已加入受信任设备';
  }

  Future<String?> pairManualIp(String ip) async {
    state = state.copyWith(isPairing: true);
    final token = await _authApi.pairDevice(ip, 3000, '未知电脑', 'manual-$ip');
    state = state.copyWith(isPairing: false);

    if (token == null) {
      return '手动配对失败，请检查 IP 和电脑端状态';
    }

    state = state.copyWith(knownDevices: _loadKnownDevices());
    await probeDevices();
    return '配对成功';
  }

  Future<void> refreshRemoteState() async {
    final device = state.activeDevice;
    if (device == null || !state.hasActiveSession || state.isRefreshingRemote) {
      return;
    }

    state = state.copyWith(isRefreshingRemote: true);

    try {
      final catalog = await _authApi.fetchCatalog(device);
      final tasks = await _authApi.listTasks(device);
      state = state.copyWith(
        featureGroups: catalog.groups,
        snapshot: catalog.snapshot,
        volumeDraft: catalog.snapshot.volumeLevel,
        scheduledTasks: tasks,
        isRefreshingRemote: false,
      );
    } catch (_) {
      state = state.copyWith(isRefreshingRemote: false);
    }
  }

  Future<String?> executeFeature({
    required FeatureDefinition feature,
    int? level,
  }) async {
    final device = state.activeDevice;
    if (device == null) {
      return '当前没有已连接的设备';
    }

    state = state.copyWith(activeFeatureKey: feature.featureKey);

    try {
      final result = await _authApi.executeCommand(
        device,
        feature: feature.featureKey,
        level: level,
      );

      state = state.copyWith(
        clearActiveFeatureKey: true,
        snapshot: result.volumeLevel != null
            ? FeatureSnapshot(volumeLevel: result.volumeLevel!)
            : null,
        replaceSnapshot: result.volumeLevel != null,
        volumeDraft: result.volumeLevel ?? state.volumeDraft,
      );
      return result.message;
    } catch (error) {
      state = state.copyWith(clearActiveFeatureKey: true);
      return '$error';
    }
  }

  Future<String?> createTask({
    required PendingCommandDraft draft,
    required DateTime executeAt,
  }) async {
    final device = state.activeDevice;
    if (device == null) {
      return '当前没有已连接的设备';
    }

    state = state.copyWith(isCreatingTask: true);
    try {
      final task = await _authApi.createTask(
        device,
        feature: draft.feature,
        executeAt: executeAt,
        level: draft.level,
      );

      final tasks = List<ScheduledTask>.from(state.scheduledTasks)..add(task);
      tasks.sort(
        (left, right) => left.executeAtMs.compareTo(right.executeAtMs),
      );

      state = state.copyWith(scheduledTasks: tasks, isCreatingTask: false);
      return '${task.title} 已安排';
    } catch (error) {
      state = state.copyWith(isCreatingTask: false);
      return '$error';
    }
  }

  Future<String?> cancelTask(String taskId) async {
    final device = state.activeDevice;
    if (device == null) {
      return '当前没有已连接的设备';
    }

    try {
      await _authApi.cancelTask(device, taskId);
      final tasks = state.scheduledTasks
          .where((task) => task.taskId != taskId)
          .toList(growable: false);
      state = state.copyWith(scheduledTasks: tasks);
      return '定时任务已停止';
    } catch (error) {
      return '$error';
    }
  }

  void setSection(AppSection section) {
    state = state.copyWith(section: section);
  }

  void setVolumeDraft(int value) {
    state = state.copyWith(volumeDraft: value);
  }

  Future<void> setTheme(String themeId) async {
    final theme = themeFromStorage(themeId);
    await _storage.setThemeId(theme.id);
    state = state.copyWith(theme: theme);
  }

  Future<void> setThemeMode(ThemePreferenceMode mode) async {
    await _storage.setThemeMode(mode.name);
    state = state.copyWith(themeMode: mode);
  }

  List<KnownDevice> _loadKnownDevices() {
    return _storage
        .getAllKnownDevices()
        .map(KnownDevice.fromMap)
        .where((device) => device.deviceId.isNotEmpty)
        .toList(growable: false);
  }
}

final appControllerProvider = NotifierProvider<AppController, AppViewState>(
  AppController.new,
);
