import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../device/data/discovery_service.dart';
import '../app_controller.dart';
import '../domain/app_models.dart';
import 'global_notice.dart';

class LanCtrlRootPage extends ConsumerStatefulWidget {
  const LanCtrlRootPage({
    super.key,
    required this.disconnectStreams,
    required this.taskChangedStreams,
  });

  final List<Stream<void>> disconnectStreams;
  final List<Stream<void>> taskChangedStreams;

  @override
  ConsumerState<LanCtrlRootPage> createState() => _LanCtrlRootPageState();
}

class _LanCtrlRootPageState extends ConsumerState<LanCtrlRootPage> {
  final List<StreamSubscription<void>> _disconnectSubscriptions =
      <StreamSubscription<void>>[];
  final List<StreamSubscription<void>> _taskChangedSubscriptions =
      <StreamSubscription<void>>[];
  final _noticeKey = GlobalKey<GlobalNoticeHostState>();

  @override
  void initState() {
    super.initState();
    for (final stream in widget.disconnectStreams) {
      _disconnectSubscriptions.add(stream.listen((_) async {
      await ref.read(appControllerProvider.notifier).clearLocalSession();
      if (!mounted) {
        return;
      }
      _showMessage('电脑端已主动断开连接');
      }));
    }
    for (final stream in widget.taskChangedStreams) {
      _taskChangedSubscriptions.add(stream.listen((_) {
        unawaited(ref.read(appControllerProvider.notifier).refreshRemoteState());
      }));
    }
  }

  @override
  void dispose() {
    for (final subscription in _disconnectSubscriptions) {
      subscription.cancel();
    }
    for (final subscription in _taskChangedSubscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    final palette = paletteOf(context);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    palette.heroGradient.first,
                    Theme.of(context).scaffoldBackgroundColor,
                    palette.heroGradient.last.withValues(alpha: 0.72),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -110,
            right: -40,
            child: _GlowOrb(color: palette.heroGlow, size: 280),
          ),
          Positioned(
            bottom: -160,
            left: -60,
            child: _GlowOrb(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.18),
              size: 320,
            ),
          ),
          SafeArea(
            child: AnimatedSwitcher(
              duration: 420.ms,
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.04),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: !state.initialized
                  ? const _BootingView()
                  : state.hasActiveSession
                  ? _AppShell(
                      key: const ValueKey('shell'),
                      onMessage: _showMessage,
                    )
                  : _ConnectOnboarding(
                      key: const ValueKey('connect'),
                      onMessage: _showMessage,
              ),
            ),
          ),
          GlobalNoticeHost(key: _noticeKey),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    _noticeKey.currentState?.show(message);
  }
}

class _BootingView extends StatelessWidget {
  const _BootingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child:
          _GlassPanel(
                width: 280,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 30,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 34,
                      height: 34,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      '正在准备移动控制台',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '加载设备、会话与主题配置',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              )
              .animate()
              .fadeIn(duration: 320.ms)
              .scale(begin: const Offset(0.96, 0.96), end: const Offset(1, 1)),
    );
  }
}

class _ConnectOnboarding extends ConsumerWidget {
  const _ConnectOnboarding({super.key, required this.onMessage});

  final ValueChanged<String> onMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);
    final palette = paletteOf(context);

    return RefreshIndicator(
      onRefresh: controller.probeDevices,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          _HeroPanel(
            badge: '连接优先',
            title: '先选中一台电脑，再进入完整控制态。',
            description: '设备连接成功后，你会直接进入任务、定时任务和设备管理的完整操作界面。',
            primaryLabel: state.isProbing ? '扫描中…' : '发现设备',
            onPrimaryPressed: state.isPairing
                ? null
                : () => _showDiscoverySheet(context, ref, onMessage),
            secondaryLabel: '手动输入 IP',
            onSecondaryPressed: state.isPairing
                ? null
                : () => _showManualIpDialog(context, ref),
          ),
          const SizedBox(height: 18),
          _SectionTitle(
            title: '配对设备',
            subtitle: '已配对设备会保存在本地，可直接连接或遗忘。',
            trailing: IconButton(
              onPressed: state.isProbing ? null : controller.probeDevices,
              icon: AnimatedRotation(
                turns: state.isProbing ? 0.25 : 0,
                duration: 500.ms,
                child: const Icon(CupertinoIcons.arrow_clockwise),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (state.knownDevices.isEmpty)
            _EmptyPanel(
              icon: CupertinoIcons.dot_radiowaves_left_right,
              title: '还没有受信任的电脑',
              description: '先扫描局域网设备或手动输入 IP 发起配对。',
            )
          else
            ...state.knownDevices.map((device) {
              final isOnline = state.onlineStatus[device.deviceId] ?? false;
              final isBusy =
                  state.isConnecting && state.activeDeviceId == device.deviceId;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _GlassPanel(
                  child: Row(
                    children: [
                      _StatusDot(active: isOnline),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              device.name,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${device.ip}:${device.port} · ${isOnline ? '在线' : '离线'}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      _ActionCapsuleButton(
                        label: isBusy ? '连接中' : '连接',
                        icon: isBusy
                            ? CupertinoIcons.arrow_2_circlepath
                            : CupertinoIcons.link,
                        accent: palette.heroGlow,
                        onPressed: !isOnline || state.isConnecting
                            ? null
                            : () async {
                                final message = await controller
                                    .connectToDevice(device);
                                if (message != null) {
                                  onMessage(message);
                                }
                              },
                      ),
                      IconButton(
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: const Text('忘记这台设备？'),
                                content: Text('会移除 ${device.name} 的本地凭证与保存记录。'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('取消'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('忘记'),
                                  ),
                                ],
                              );
                            },
                          );

                          if (confirmed != true) {
                            return;
                          }

                          final message = await controller.forgetDevice(device);
                          if (message != null) {
                            onMessage(message);
                          }
                        },
                        icon: const Icon(CupertinoIcons.trash),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Future<void> _showManualIpDialog(BuildContext context, WidgetRef ref) async {
    final ipController = TextEditingController();
    final controller = ref.read(appControllerProvider.notifier);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('手动输入电脑 IP'),
          content: TextField(
            controller: ipController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'IP 地址',
              hintText: '例如 192.168.1.100',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('发起配对'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final ip = ipController.text.trim();
    if (ip.isEmpty) {
      onMessage('请输入有效的 IP 地址');
      return;
    }

    final message = await controller.pairManualIp(ip);
    if (message != null) {
      onMessage(message);
    }
  }

  Future<void> _showDiscoverySheet(
    BuildContext context,
    WidgetRef ref,
    ValueChanged<String> onMessage,
  ) async {
    final discoveryService = ref.read(discoveryServiceProvider);
    final controller = ref.read(appControllerProvider.notifier);
    unawaited(discoveryService.start());

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: StreamBuilder<List<LanDevice>>(
            stream: discoveryService.devicesStream,
            builder: (context, snapshot) {
              final devices = snapshot.data ?? const <LanDevice>[];
              final knownIds = ref
                  .watch(appControllerProvider)
                  .knownDevices
                  .map((device) => device.deviceId)
                  .toSet();
              final discovered = devices
                  .where((device) => !knownIds.contains(device.deviceId))
                  .toList(growable: false);

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '局域网发现',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '新发现的电脑会出现在这里，点击即可发起配对。',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (discovered.isEmpty)
                    const _EmptyPanel(
                      icon: CupertinoIcons.dot_radiowaves_left_right,
                      title: '正在搜索设备',
                      description: '确保电脑端已打开并且手机与电脑在同一局域网。',
                    )
                  else
                    ...discovered.map((device) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _GlassPanel(
                          child: Row(
                            children: [
                              const Icon(CupertinoIcons.desktopcomputer),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      device.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${device.ip}:${device.port}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              FilledButton.tonal(
                                onPressed: () async {
                                  Navigator.pop(context);
                                  final message = await controller
                                      .pairDiscoveredDevice(device);
                                  if (message != null) {
                                    onMessage(message);
                                  }
                                },
                                child: const Text('配对'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              );
            },
          ),
        );
      },
    );

    // Keep discovery alive globally; the device list is event-driven by mDNS.
  }
}

class _AppShell extends ConsumerWidget {
  const _AppShell({super.key, required this.onMessage});

  final ValueChanged<String> onMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);
    final activeDevice = state.activeDevice!;

    final pages = <AppSection, Widget>{
      AppSection.tasks: _TasksPage(onMessage: onMessage),
      AppSection.schedules: _SchedulesPage(onMessage: onMessage),
      AppSection.devices: _DevicesPage(onMessage: onMessage),
      AppSection.relay: const _RelayPage(),
    };

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 112),
          child: Column(
            children: [
              _GlassPanel(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activeDevice.name,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${activeDevice.ip}:${activeDevice.port}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: state.isRefreshingRemote
                          ? null
                          : () async {
                              await controller.refreshRemoteState();
                              onMessage('已刷新设备状态');
                            },
                      icon: AnimatedRotation(
                        turns: state.isRefreshingRemote ? 0.20 : 0,
                        duration: 500.ms,
                        child: const Icon(CupertinoIcons.arrow_clockwise),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: AnimatedSwitcher(
                  duration: 420.ms,
                  switchInCurve: Curves.easeOutQuart,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.03, 0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey(state.section),
                    child: pages[state.section]!,
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 18,
          child: Center(
            child: _DockNavigation(
              section: state.section,
              pendingTaskCount: state.scheduledTasks.length,
              onSelected: controller.setSection,
            ),
          ),
        ),
      ],
    );
  }
}

class _TasksPage extends ConsumerWidget {
  const _TasksPage({required this.onMessage});

  final ValueChanged<String> onMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);
    final featureList = state.featureGroups
        .expand((group) => group.features)
        .toList();
    FeatureDefinition? volumeFeature;
    for (final feature in featureList) {
      if (feature.isRange) {
        volumeFeature = feature;
        break;
      }
    }
    final actionFeatures = featureList
        .where((feature) => feature.isAction)
        .toList();
    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        const _SectionTitle(title: '即时操作'),
        const SizedBox(height: 12),
        if (actionFeatures.isEmpty)
          const _EmptyPanel(
            icon: CupertinoIcons.sparkles,
            title: '功能目录暂不可用',
            description: '稍后刷新一次，或检查电脑端是否仍处于连接状态。',
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: actionFeatures
                .map((feature) {
                  final control = feature.control as ActionFeatureControl;
                  return SizedBox(
                    width: (MediaQuery.sizeOf(context).width - 52) / 2,
                    child: _ActionCard(
                      feature: feature,
                      pending: state.activeFeatureKey == feature.featureKey,
                      tone: control.tone,
                      onPressed: () async {
                        if (control.confirmRequired) {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: Text('确认执行 ${feature.title}？'),
                                content: Text(feature.description),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('取消'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('执行'),
                                  ),
                                ],
                              );
                            },
                          );

                          if (confirmed != true) {
                            return;
                          }
                        }

                        final message = await controller.executeFeature(
                          feature: feature,
                        );
                        if (message != null) {
                          onMessage(message);
                        }
                      },
                    ),
                  );
                })
                .toList(growable: false),
          ),
        const SizedBox(height: 18),
        if (volumeFeature != null) ...[
          const _SectionTitle(title: '音量调节'),
          const SizedBox(height: 12),
          _GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '主音量',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${state.volumeDraft}%',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Slider(
                  value: state.volumeDraft.toDouble(),
                  onChanged: (value) =>
                      controller.setVolumeDraft(value.round()),
                  min: 0,
                  max: 100,
                ),
                const SizedBox(height: 8),
                _ActionCapsuleButton(
                  label: state.activeFeatureKey == volumeFeature.featureKey
                      ? '应用中'
                      : '应用到电脑',
                  icon: state.activeFeatureKey == volumeFeature.featureKey
                      ? CupertinoIcons.equal_circle
                      : CupertinoIcons.speaker_2_fill,
                  onPressed: () async {
                    final message = await controller.executeFeature(
                      feature: volumeFeature!,
                      level: state.volumeDraft,
                    );
                    if (message != null) {
                      onMessage(message);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],
      ],
    );
  }
}

class _SchedulesPage extends ConsumerWidget {
  const _SchedulesPage({required this.onMessage});

  final ValueChanged<String> onMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);
    final actionFeatures = state.featureGroups
        .expand((group) => group.features)
        .where((feature) => feature.isAction)
        .toList(growable: false);

    final presets = <({String label, int minutes, PendingCommandDraft draft})>[
      (
        label: '5 分钟后关机',
        minutes: 5,
        draft: const PendingCommandDraft(feature: 'shutdown'),
      ),
      (
        label: '10 分钟后重启',
        minutes: 10,
        draft: const PendingCommandDraft(feature: 'restart'),
      ),
      (
        label: '30 分钟后关机',
        minutes: 30,
        draft: const PendingCommandDraft(feature: 'shutdown'),
      ),
      if (actionFeatures.any((feature) => feature.featureKey == 'test_notification'))
        (
          label: '1 分钟后测试提示',
          minutes: 1,
          draft: const PendingCommandDraft(feature: 'test_notification'),
        ),
    ];

    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        const _SectionTitle(title: '定时任务'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _ActionCapsuleButton(
              label: state.isCreatingTask ? '创建中…' : '添加任务',
              icon: CupertinoIcons.plus,
              onPressed: () => _showTaskComposer(context, ref, onMessage),
            ),
            _ActionCapsuleButton(
              label: '刷新任务',
              icon: CupertinoIcons.arrow_clockwise,
              isSecondary: true,
              onPressed: () async {
                await controller.refreshRemoteState();
                onMessage('定时任务已刷新');
              },
            ),
          ],
        ),
        const SizedBox(height: 18),
        const _SectionTitle(title: '快捷预设'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: presets
              .map((preset) {
                return _PresetChip(
                  label: preset.label,
                  onTap: () async {
                    final message = await controller.createTask(
                      draft: preset.draft,
                      executeAt: DateTime.now().add(
                        Duration(minutes: preset.minutes),
                      ),
                    );
                    if (message != null) {
                      onMessage(message);
                    }
                  },
                );
              })
              .toList(growable: false),
        ),
        const SizedBox(height: 18),
        const _SectionTitle(title: '待执行列表'),
        const SizedBox(height: 12),
        if (state.scheduledTasks.isEmpty)
          const _EmptyPanel(
            icon: CupertinoIcons.tray,
            title: '队列里还是空的',
            description: '添加一个 5 分钟后关机之类的任务后，这里会实时出现。',
          )
        else
          ...state.scheduledTasks.map((task) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _GlassPanel(
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.clock_fill),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.title,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${DateFormat('MM-dd HH:mm').format(task.executeAt)} · ${_countdownText(task.executeAt)}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.tonal(
                      onPressed: () async {
                        final message = await controller.cancelTask(
                          task.taskId,
                        );
                        if (message != null) {
                          onMessage(message);
                        }
                      },
                      child: const Text('停止'),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  String _countdownText(DateTime executeAt) {
    final diff = executeAt.difference(DateTime.now());
    if (diff.isNegative) {
      return '即将执行';
    }
    if (diff.inHours >= 1) {
      return '${diff.inHours} 小时后';
    }
    if (diff.inMinutes >= 1) {
      return '${diff.inMinutes} 分钟后';
    }
    return '${diff.inSeconds.clamp(1, 59)} 秒后';
  }

  Future<void> _showTaskComposer(
    BuildContext context,
    WidgetRef ref,
    ValueChanged<String> onMessage,
  ) async {
    final controller = ref.read(appControllerProvider.notifier);
    final actionFeatures = ref
        .read(appControllerProvider)
        .featureGroups
        .expand((group) => group.features)
        .where((feature) => feature.isAction)
        .toList(growable: false);
    if (actionFeatures.isEmpty) {
      onMessage('当前没有可安排的指令');
      return;
    }

    String feature = actionFeatures.first.featureKey;
    int minutes = 5;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '添加定时任务',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '先选命令，再选执行时间。',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: actionFeatures
                        .map((item) {
                          return _SelectableChip(
                            label: item.title,
                            selected: feature == item.featureKey,
                            onTap: () =>
                                setState(() => feature = item.featureKey),
                          );
                        })
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '延后时间',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [5, 10, 15, 30, 60]
                        .map((value) {
                          return _SelectableChip(
                            label: '$value 分钟',
                            selected: minutes == value,
                            onTap: () => setState(() => minutes = value),
                          );
                        })
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        final message = await controller.createTask(
                          draft: PendingCommandDraft(feature: feature),
                          executeAt: DateTime.now().add(
                            Duration(minutes: minutes),
                          ),
                        );
                        if (message != null) {
                          onMessage(message);
                        }
                      },
                      child: const Text('确认添加'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _DevicesPage extends ConsumerWidget {
  const _DevicesPage({required this.onMessage});

  final ValueChanged<String> onMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);

    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        const _SectionTitle(title: '设备与主题'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _ActionCapsuleButton(
              label: '重新扫描',
              icon: CupertinoIcons.arrow_clockwise,
              onPressed: () async {
                await controller.probeDevices();
                onMessage('设备状态已刷新');
              },
            ),
            _ActionCapsuleButton(
              label: '断开连接',
              icon: CupertinoIcons.xmark_circle,
              isSecondary: true,
              onPressed: () async {
                final message = await controller.disconnectActiveDevice();
                if (message != null) {
                  onMessage(message);
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 18),
        const _SectionTitle(title: '已配对设备'),
        const SizedBox(height: 12),
        ...state.knownDevices.map((device) {
          final isOnline = state.onlineStatus[device.deviceId] ?? false;
          final isCurrent = state.activeDeviceId == device.deviceId;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _GlassPanel(
              child: Row(
                children: [
                  _StatusDot(active: isOnline),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                device.name,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            if (isCurrent)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '当前设备',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${device.ip}:${device.port} · ${isOnline ? '在线' : '离线'}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: !isOnline
                        ? null
                        : () async {
                            final message = await controller.connectToDevice(
                              device,
                            );
                            if (message != null) {
                              onMessage(message);
                            }
                          },
                    child: Text(isCurrent ? '重连' : '连接'),
                  ),
                  IconButton(
                    onPressed: () async {
                      final message = await controller.forgetDevice(device);
                      if (message != null) {
                        onMessage(message);
                      }
                    },
                    icon: const Icon(CupertinoIcons.trash),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        const _SectionTitle(title: '主题外观'),
        const SizedBox(height: 12),
        _GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: themeRegistry.values
                    .map((theme) {
                      final selected = state.theme.id == theme.id;
                      return _SelectableChip(
                        label: theme.name,
                        selected: selected,
                        onTap: () => controller.setTheme(theme.id),
                      );
                    })
                    .toList(growable: false),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: ThemePreferenceMode.values
                    .map((mode) {
                      final label = switch (mode) {
                        ThemePreferenceMode.light => '浅色',
                        ThemePreferenceMode.dark => '深色',
                        ThemePreferenceMode.system => '跟随系统',
                      };
                      return _SelectableChip(
                        label: label,
                        selected: state.themeMode == mode,
                        onTap: () => controller.setThemeMode(mode),
                      );
                    })
                    .toList(growable: false),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RelayPage extends StatefulWidget {
  const _RelayPage();

  @override
  State<_RelayPage> createState() => _RelayPageState();
}

class _RelayPageState extends State<_RelayPage> {
  int _modeIndex = 0;

  @override
  Widget build(BuildContext context) {
    final modes = const ['文本', '文件', '图片'];

    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        const _SectionTitle(title: '传输中心'),
        const SizedBox(height: 12),
        _GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: List.generate(modes.length, (index) {
                  return _SelectableChip(
                    label: modes[index],
                    selected: _modeIndex == index,
                    onTap: () => setState(() => _modeIndex = index),
                  );
                }),
              ),
              const SizedBox(height: 18),
              if (_modeIndex == 0)
                TextField(
                  minLines: 5,
                  maxLines: 7,
                  decoration: const InputDecoration(
                    hintText: '输入文字',
                    border: OutlineInputBorder(),
                  ),
                )
              else
                _EmptyPanel(
                  icon: _modeIndex == 1
                      ? CupertinoIcons.doc
                      : CupertinoIcons.photo,
                  title: _modeIndex == 1 ? '文件发送' : '图片发送',
                  description: '暂不可用',
                ),
              const SizedBox(height: 16),
              const _ActionCapsuleButton(
                label: '暂不可用',
                icon: CupertinoIcons.paperplane,
                onPressed: null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.badge,
    required this.title,
    required this.description,
    required this.primaryLabel,
    this.secondaryLabel,
    this.onPrimaryPressed,
    this.onSecondaryPressed,
  });

  final String badge;
  final String title;
  final String description;
  final String primaryLabel;
  final String? secondaryLabel;
  final VoidCallback? onPrimaryPressed;
  final VoidCallback? onSecondaryPressed;

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette.heroGradient,
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              badge,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -1.1,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              height: 1.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ActionCapsuleButton(
                label: primaryLabel,
                icon: CupertinoIcons.sparkles,
                onPressed: onPrimaryPressed,
              ),
              if (secondaryLabel != null)
                _ActionCapsuleButton(
                  label: secondaryLabel!,
                  icon: CupertinoIcons.arrow_up_right,
                  isSecondary: true,
                  onPressed: onSecondaryPressed,
                ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 320.ms).moveY(begin: 12, end: 0);
  }
}

class _DockNavigation extends StatelessWidget {
  const _DockNavigation({
    required this.section,
    required this.pendingTaskCount,
    required this.onSelected,
  });

  final AppSection section;
  final int pendingTaskCount;
  final ValueChanged<AppSection> onSelected;

  @override
  Widget build(BuildContext context) {
    final items = <({AppSection section, IconData icon, String label})>[
      (
        section: AppSection.tasks,
        icon: CupertinoIcons.square_grid_2x2_fill,
        label: '任务',
      ),
      (
        section: AppSection.schedules,
        icon: CupertinoIcons.clock_fill,
        label: '定时',
      ),
      (
        section: AppSection.devices,
        icon: CupertinoIcons.desktopcomputer,
        label: '设备',
      ),
      (
        section: AppSection.relay,
        icon: CupertinoIcons.paperplane_fill,
        label: '传输',
      ),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: glassBlur(24),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: paletteOf(context).glassFill,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: paletteOf(context).glassStroke),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: items
                .map((item) {
                  final selected = item.section == section;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => onSelected(item.section),
                        child: AnimatedContainer(
                        duration: 260.ms,
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.16)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                AnimatedScale(
                                  duration: 220.ms,
                                  scale: selected ? 1.08 : 1,
                                  child: Icon(item.icon, size: 18),
                                ),
                                if (item.section == AppSection.schedules &&
                                    pendingTaskCount > 0)
                                  Positioned(
                                    top: -6,
                                    right: -8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        pendingTaskCount > 9
                                            ? '9+'
                                            : '$pendingTaskCount',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            AnimatedSize(
                              duration: 220.ms,
                              curve: Curves.easeOutCubic,
                              child: selected
                                  ? Padding(
                                      padding: const EdgeInsets.only(left: 8),
                                      child: Text(
                                        item.label,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                })
                .toList(growable: false),
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.feature,
    required this.pending,
    required this.tone,
    required this.onPressed,
  });

  final FeatureDefinition feature;
  final bool pending;
  final FeatureTone tone;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final accent = tone == FeatureTone.danger
        ? const Color(0xFFFF6C76)
        : Theme.of(context).colorScheme.primary;

    return _GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: AnimatedSwitcher(
              duration: 220.ms,
              transitionBuilder: (child, animation) {
                return ScaleTransition(scale: animation, child: child);
              },
              child: Icon(
                pending
                    ? CupertinoIcons.arrow_2_circlepath
                    : switch (feature.featureKey) {
                        'shutdown' => CupertinoIcons.power,
                        'restart' =>
                          CupertinoIcons.arrow_clockwise_circle_fill,
                        'test_notification' => CupertinoIcons.bell_fill,
                        _ => CupertinoIcons.play_circle_fill,
                      },
                key: ValueKey(pending),
                color: accent,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            feature.title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            feature.description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              height: 1.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          _ActionCapsuleButton(
            label: pending
                ? '执行中'
                : (feature.control as ActionFeatureControl).buttonText,
            icon: pending
                ? CupertinoIcons.stop_circle
                : CupertinoIcons.arrow_up_right,
            accent: accent,
            onPressed: pending ? null : onPressed,
          ),
        ],
      ),
    );
  }
}

class _ActionCapsuleButton extends StatelessWidget {
  const _ActionCapsuleButton({
    required this.label,
    required this.icon,
    this.onPressed,
    this.isSecondary = false,
    this.accent,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isSecondary;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? Theme.of(context).colorScheme.primary;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onPressed,
      child: AnimatedContainer(
        duration: 220.ms,
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: onPressed == null
              ? Theme.of(context).colorScheme.surfaceContainerHighest
              : isSecondary
              ? Colors.transparent
              : color,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSecondary
                ? Theme.of(context).colorScheme.outline.withValues(alpha: 0.22)
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: 220.ms,
              transitionBuilder: (child, animation) {
                return RotationTransition(
                  turns: Tween<double>(begin: 0.86, end: 1).animate(animation),
                  child: ScaleTransition(scale: animation, child: child),
                );
              },
              child: Icon(
                icon,
                key: ValueKey(icon),
                size: 18,
                color: onPressed == null
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : isSecondary
                    ? Theme.of(context).colorScheme.onSurface
                    : Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: onPressed == null
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : isSecondary
                    ? Theme.of(context).colorScheme.onSurface
                    : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.width,
  });

  final Widget child;
  final EdgeInsets padding;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: glassBlur(18),
        child: Container(
          width: width,
          padding: padding,
          decoration: BoxDecoration(
            color: palette.glassFill,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: palette.glassStroke),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        trailing ?? const SizedBox.shrink(),
      ],
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: Column(
        children: [
          Icon(icon, size: 34, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 14),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.12),
          ),
        ),
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _SelectableChip extends StatelessWidget {
  const _SelectableChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: 220.ms,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.14)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.18)
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.14),
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: selected ? Theme.of(context).colorScheme.primary : null,
          ),
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: active ? const Color(0xFF4CD964) : Colors.grey,
        shape: BoxShape.circle,
        boxShadow: active
            ? [
                BoxShadow(
                  color: const Color(0xFF4CD964).withValues(alpha: 0.40),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}
