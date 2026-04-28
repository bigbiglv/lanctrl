import { computed, onMounted, onUnmounted, ref } from "vue";
import { cancelScheduledTask, createScheduledTask, executeCommand, fetchState } from "./api";
import type {
  ConnectionStatus,
  FeatureCommand,
  FeatureExecuteResponse,
  FeatureDefinition,
  FeatureGroup,
  FeatureSnapshot,
  ScheduledTask,
  TaskHistoryEntry,
  WebStateResponse,
} from "./types";

const statusLabels: Record<string, string> = {
  queued: "已排队",
  cancelled: "已停止",
  executed: "已完成",
  failed: "失败",
  manual_executed: "手动完成",
  manual_failed: "手动失败",
};

export function useWebConsole() {
  const groups = ref<FeatureGroup[]>([]);
  const snapshot = ref<FeatureSnapshot | null>(null);
  const tasks = ref<ScheduledTask[]>([]);
  const history = ref<TaskHistoryEntry[]>([]);
  const activeTab = ref<"actions" | "schedules" | "history">("actions");
  const activeFeatureKey = ref("");
  const selectedFeatureKey = ref("");
  const taskVolume = ref(50);
  const taskDelayMinutes = ref(5);
  const taskDelaySeconds = ref(0);
  const toast = ref("");
  const connectionStatus = ref<ConnectionStatus>("connecting");
  const connectionDetail = ref("等待 WebSocket 状态同步");
  const now = ref(Date.now());

  let toastTimer = 0;
  let reconnectTimer = 0;
  let heartbeatTimer = 0;
  let clockTimer = 0;
  let socket: WebSocket | null = null;
  const pendingCommands = new Map<string, {
    resolve: (payload: FeatureExecuteResponse) => void;
    reject: (error: Error) => void;
    timer: number;
  }>();

  const allFeatures = computed(() => groups.value.flatMap((group) => group.features));
  const actionFeatures = computed(() => allFeatures.value.filter((feature) => feature.control.type === "action"));
  const rangeFeatures = computed(() => allFeatures.value.filter((feature) => feature.control.type === "range"));
  const selectedFeature = computed(() => {
    return allFeatures.value.find((feature) => feature.featureKey === selectedFeatureKey.value) ?? allFeatures.value[0];
  });
  const selectedFeatureNeedsVolume = computed(() => selectedFeature.value?.control.type === "range");
  const visibleHistory = computed(() => history.value.slice(0, 80));

  function applyState(payload: WebStateResponse) {
    groups.value = payload.groups ?? [];
    snapshot.value = payload.snapshot ?? null;
    tasks.value = payload.tasks ?? [];
    history.value = payload.history ?? [];

    if (!selectedFeatureKey.value || !allFeatures.value.some((feature) => feature.featureKey === selectedFeatureKey.value)) {
      selectedFeatureKey.value = allFeatures.value[0]?.featureKey ?? "";
    }

    if (typeof snapshot.value?.volumeLevel === "number") {
      taskVolume.value = snapshot.value.volumeLevel;
    }
  }

  function showToast(message: string) {
    toast.value = message;
    window.clearTimeout(toastTimer);
    toastTimer = window.setTimeout(() => {
      toast.value = "";
    }, 2600);
  }

  function setConnection(status: ConnectionStatus, detail: string) {
    connectionStatus.value = status;
    connectionDetail.value = detail;
  }

  function commandForFeature(feature: FeatureDefinition, level?: number): FeatureCommand {
    if (feature.featureKey === "volume") {
      return { feature: "volume", level: Number(level ?? snapshot.value?.volumeLevel ?? 0) };
    }

    return { feature: feature.featureKey };
  }

  async function refreshState(silent = false) {
    applyState(await fetchState());
    if (!silent) {
      showToast("状态已刷新");
    }
  }

  function sendFeatureCommand(command: FeatureCommand) {
    if (socket?.readyState !== WebSocket.OPEN) {
      return executeCommand(command);
    }

    const requestId = crypto.randomUUID();
    return new Promise<FeatureExecuteResponse>((resolve, reject) => {
      const timer = window.setTimeout(() => {
        pendingCommands.delete(requestId);
        reject(new Error("WebSocket 执行超时"));
      }, 8000);

      pendingCommands.set(requestId, { resolve, reject, timer });
      socket?.send(JSON.stringify({
        type: "execute_feature",
        request_id: requestId,
        ...command,
      }));
    });
  }

  async function runFeature(feature: FeatureDefinition, level?: number) {
    if (feature.control.type === "action" && feature.control.confirmRequired) {
      const confirmed = window.confirm(`确认执行“${feature.title}”？\n${feature.description}`);
      if (!confirmed) {
        return;
      }
    }

    activeFeatureKey.value = feature.featureKey;
    try {
      const payload = await sendFeatureCommand(commandForFeature(feature, level));
      if (!payload.success) {
        throw new Error(payload.msg || "执行失败");
      }
      if (typeof payload.result?.volumeLevel === "number") {
        snapshot.value = { volumeLevel: payload.result.volumeLevel };
      }
      showToast(payload.msg || "执行成功");
    } catch (error) {
      showToast(String(error instanceof Error ? error.message : error));
    } finally {
      activeFeatureKey.value = "";
    }
  }

  async function submitTask() {
    if (!selectedFeature.value) {
      showToast("请选择任务类型");
      return;
    }

    try {
      const minutes = Number.isFinite(taskDelayMinutes.value) ? Math.max(0, taskDelayMinutes.value) : 0;
      const seconds = Number.isFinite(taskDelaySeconds.value) ? Math.max(0, Math.min(59, taskDelaySeconds.value)) : 0;
      const delayMs = Math.max(1, minutes * 60 + seconds) * 1000;
      const command = selectedFeature.value.control.type === "range"
        ? commandForFeature(selectedFeature.value, taskVolume.value)
        : commandForFeature(selectedFeature.value);
      const payload = await createScheduledTask(command, delayMs);
      if (!payload.success) {
        throw new Error(payload.msg || "创建任务失败");
      }
      showToast(payload.msg || "定时任务已创建");
    } catch (error) {
      showToast(String(error instanceof Error ? error.message : error));
    }
  }

  async function cancelTask(taskId: string) {
    try {
      const payload = await cancelScheduledTask(taskId);
      if (!payload.success) {
        throw new Error(payload.msg || "停止任务失败");
      }
      showToast(payload.msg || "定时任务已停止");
    } catch (error) {
      showToast(String(error instanceof Error ? error.message : error));
    }
  }

  function connectWebSocket() {
    window.clearTimeout(reconnectTimer);
    window.clearInterval(heartbeatTimer);
    setConnection("connecting", "正在建立实时通道");

    const protocol = window.location.protocol === "https:" ? "wss:" : "ws:";
    socket = new WebSocket(`${protocol}//${window.location.host}/web/ws`);

    socket.addEventListener("open", () => {
      setConnection("connected", "任务状态会自动刷新");
      socket?.send(JSON.stringify({ type: "request_state_sync" }));
      heartbeatTimer = window.setInterval(() => {
        if (socket?.readyState === WebSocket.OPEN) {
          socket.send(JSON.stringify({ type: "heartbeat" }));
        }
      }, 15_000);
    });

    socket.addEventListener("message", (event) => {
      const payload = JSON.parse(event.data);
      if (payload.type === "state_sync") {
        applyState(payload as WebStateResponse);
      }
      if (payload.type === "feature_result") {
        const pending = pendingCommands.get(payload.request_id);
        if (!pending) {
          return;
        }
        window.clearTimeout(pending.timer);
        pendingCommands.delete(payload.request_id);
        pending.resolve({
          success: payload.success,
          msg: payload.msg,
          result: payload.result ?? null,
        });
      }
    });

    socket.addEventListener("close", () => {
      setConnection("offline", "3 秒后自动重连");
      window.clearInterval(heartbeatTimer);
      pendingCommands.forEach((pending) => {
        window.clearTimeout(pending.timer);
        pending.reject(new Error("WebSocket 已断开"));
      });
      pendingCommands.clear();
      reconnectTimer = window.setTimeout(connectWebSocket, 3000);
    });

    socket.addEventListener("error", () => {
      setConnection("offline", "实时通道异常");
    });
  }

  function formatDate(ms: number) {
    return new Intl.DateTimeFormat("zh-CN", {
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
    }).format(new Date(ms));
  }

  function countdownText(ms: number) {
    const diff = ms - now.value;
    if (diff <= 0) {
      return "即将执行";
    }

    const seconds = Math.max(1, Math.floor(diff / 1000));
    const minutes = Math.floor(seconds / 60);
    const hours = Math.floor(minutes / 60);
    if (hours >= 1) {
      return `${hours} 小时后`;
    }
    if (minutes >= 1) {
      return `${minutes} 分钟后`;
    }
    return `${Math.min(seconds, 59)} 秒后`;
  }

  onMounted(() => {
    clockTimer = window.setInterval(() => {
      now.value = Date.now();
    }, 1000);
    refreshState(true).catch((error) => {
      console.debug("Web console initial state sync failed:", error);
    });
    connectWebSocket();
  });

  onUnmounted(() => {
    socket?.close();
    window.clearTimeout(toastTimer);
    window.clearTimeout(reconnectTimer);
    window.clearInterval(heartbeatTimer);
    window.clearInterval(clockTimer);
  });

  return {
    activeFeatureKey,
    activeTab,
    actionFeatures,
    cancelTask,
    connectionDetail,
    connectionStatus,
    countdownText,
    formatDate,
    groups,
    rangeFeatures,
    refreshState,
    runFeature,
    selectedFeature,
    selectedFeatureKey,
    selectedFeatureNeedsVolume,
    showToast,
    snapshot,
    statusLabels,
    submitTask,
    taskDelayMinutes,
    taskDelaySeconds,
    tasks,
    taskVolume,
    toast,
    visibleHistory,
  };
}
