<script setup lang="ts">
import { computed } from "vue";
import {
  Bell,
  CheckCircle2,
  Clock3,
  History,
  LoaderCircle,
  Moon,
  Play,
  Power,
  RefreshCw,
  RotateCcw,
  Square,
  Sun,
  Volume2,
  Wifi,
  WifiOff,
  Zap,
} from "lucide-vue-next";
import { useWebConsole } from "./useWebConsole";
import { useTheme } from "./useTheme";

const {
  activeFeatureKey,
  activeTab,
  actionFeatures,
  cancelTask,
  connectionDetail,
  connectionStatus,
  countdownText,
  formatDate,
  rangeFeatures,
  refreshState,
  runFeature,
  selectedFeatureKey,
  selectedFeatureNeedsVolume,
  statusLabels,
  submitTask,
  taskDelayMinutes,
  taskDelaySeconds,
  tasks,
  taskVolume,
  toast,
  visibleHistory,
  snapshot,
} = useWebConsole();
const { resolvedMode, toggleThemeMode } = useTheme();

const navItems = [
  { key: "actions", label: "操作", icon: Zap },
  { key: "schedules", label: "定时", icon: Clock3 },
  { key: "history", label: "历史", icon: History },
] as const;

const connectionText = computed(() => {
  if (connectionStatus.value === "connected") {
    return "实时同步中";
  }
  if (connectionStatus.value === "offline") {
    return "连接断开";
  }
  return "正在连接";
});

function iconForFeature(featureKey: string) {
  if (featureKey === "shutdown") {
    return Power;
  }
  if (featureKey === "restart") {
    return RotateCcw;
  }
  if (featureKey === "volume") {
    return Volume2;
  }
  return Bell;
}

function normalizeTaskTitle(title: string) {
  return title
    .replaceAll("瀹氭椂鍏虫満", "定时关机")
    .replaceAll("瀹氭椂閲嶅惎", "定时重启")
    .replaceAll("瀹氭椂娴嬭瘯鎻愮ず", "定时测试提示")
    .replaceAll("瀹氭椂闊抽噺璋冩暣鍒?", "定时音量调整到 ");
}
</script>

<template>
  <div class="app-shell">
    <header class="topbar">
      <div class="connection-card" aria-live="polite">
        <component :is="connectionStatus === 'connected' ? Wifi : WifiOff" class="connection-icon" :class="connectionStatus" />
        <div>
          <strong>{{ connectionText }}</strong>
          <span>{{ connectionDetail }}</span>
        </div>
      </div>

      <button class="icon-button nav-action" type="button" aria-label="切换主题" @click="toggleThemeMode">
        <component :is="resolvedMode === 'dark' ? Sun : Moon" class="button-icon" />
      </button>
    </header>

    <nav class="section-nav" aria-label="控制台导航">
      <div class="section-nav-inner">
        <button
          v-for="item in navItems"
          :key="item.key"
          class="nav-item"
          :class="{ active: activeTab === item.key }"
          type="button"
          @click="activeTab = item.key"
        >
          <component :is="item.icon" class="nav-icon" />
          {{ item.label }}
        </button>
      </div>
    </nav>

    <main class="workspace">
      <section v-show="activeTab === 'actions'" class="page">
        <div class="section-title">
          <div>
            <h2>即时操作</h2>
          </div>
          <button class="icon-button" type="button" aria-label="刷新状态" @click="refreshState()">
            <RefreshCw class="button-icon" />
          </button>
        </div>

        <div v-if="actionFeatures.length" class="action-grid">
          <article v-for="feature in actionFeatures" :key="feature.featureKey" class="control-card action-card">
            <div class="action-card-main">
              <div class="feature-icon" :class="{ danger: feature.control.type === 'action' && feature.control.tone === 'danger' }">
                <component :is="iconForFeature(feature.featureKey)" />
              </div>
              <div class="feature-title">{{ feature.title }}</div>
            </div>
            <button
              class="primary-button action-run-button"
              :class="{
                danger: feature.control.type === 'action' && feature.control.tone === 'danger',
                running: activeFeatureKey === feature.featureKey,
              }"
              type="button"
              :disabled="activeFeatureKey === feature.featureKey"
              :aria-label="activeFeatureKey === feature.featureKey ? '执行中' : '执行'"
              @click="runFeature(feature)"
            >
              <LoaderCircle v-if="activeFeatureKey === feature.featureKey" class="button-icon spin action-progress" />
              <Square v-if="activeFeatureKey === feature.featureKey" class="button-icon action-stop-icon" />
              <Play v-else class="button-icon" />
            </button>
          </article>
        </div>
        <div v-else class="empty-state">暂无功能</div>

        <article v-for="feature in rangeFeatures" :key="feature.featureKey" class="control-card volume-card">
          <div class="volume-head">
            <div>
              <div class="feature-title">{{ feature.title }}</div>
            </div>
            <div class="volume-value">{{ snapshot?.volumeLevel ?? taskVolume }}{{ feature.control.type === "range" ? feature.control.unit : "%" }}</div>
          </div>
          <input
            v-if="feature.control.type === 'range'"
            v-model.number="taskVolume"
            type="range"
            :min="feature.control.min"
            :max="feature.control.max"
            :step="feature.control.step"
            @change="runFeature(feature, taskVolume)"
          />
        </article>
      </section>

      <section v-show="activeTab === 'schedules'" class="page">
        <div class="section-title">
          <div>
            <h2>定时任务</h2>
          </div>
        </div>

        <form class="composer-panel" @submit.prevent="submitTask">
          <label>
            <span>任务类型</span>
            <select v-model="selectedFeatureKey">
              <option
                v-for="feature in [...actionFeatures, ...rangeFeatures]"
                :key="feature.featureKey"
                :value="feature.featureKey"
              >
                {{ feature.title }}
              </option>
            </select>
          </label>

          <label v-show="selectedFeatureNeedsVolume">
            <span>音量</span>
            <input v-model.number="taskVolume" type="number" min="0" max="100" step="1" />
          </label>

          <label>
            <span>分钟</span>
            <input v-model.number="taskDelayMinutes" type="number" min="0" max="1440" step="1" />
          </label>

          <label>
            <span>秒</span>
            <input v-model.number="taskDelaySeconds" type="number" min="0" max="59" step="1" />
          </label>

          <button class="primary-button confirm-button" type="submit">
            确认
          </button>
        </form>

        <div class="section-title compact">
          <div>
            <h3>待执行列表</h3>
            <p>{{ tasks.length ? `${tasks.length} 个任务等待执行` : "暂无任务" }}</p>
          </div>
        </div>

        <div v-if="tasks.length" class="list-stack">
          <article v-for="task in tasks" :key="task.taskId" class="list-row">
            <div class="list-row-main">
              <div class="list-row-title">{{ normalizeTaskTitle(task.title) }}</div>
              <div class="list-row-meta">
                {{ formatDate(task.executeAtMs) }} · {{ countdownText(task.executeAtMs) }}
              </div>
            </div>
            <div class="list-row-actions">
              <span class="status-badge queued">待执行</span>
              <button class="secondary-button" type="button" aria-label="停止任务" @click="cancelTask(task.taskId)">
                <Square class="button-icon" />
              </button>
            </div>
          </article>
        </div>
        <div v-else class="empty-state">暂无任务</div>
      </section>

      <section v-show="activeTab === 'history'" class="page">
        <div class="section-title">
          <div>
            <h2>任务历史</h2>
          </div>
        </div>

        <div v-if="visibleHistory.length" class="list-stack">
          <article v-for="entry in visibleHistory" :key="`${entry.taskId}-${entry.recordedAtMs}`" class="list-row">
            <span class="status-badge" :class="entry.status">
              <CheckCircle2 class="badge-icon" />
              {{ statusLabels[entry.status] ?? entry.status }}
            </span>
            <div class="list-row-main">
              <div class="list-row-title">{{ normalizeTaskTitle(entry.title) }}</div>
              <div class="list-row-meta">{{ formatDate(entry.recordedAtMs) }} · {{ entry.origin?.clientName ?? "未知来源" }}</div>
              <div v-if="entry.detail" class="list-row-meta">{{ entry.detail }}</div>
            </div>
          </article>
        </div>
        <div v-else class="empty-state">暂无记录</div>
      </section>
    </main>

    <div class="toast" :class="{ visible: toast }" role="status" aria-live="polite">
      {{ toast }}
    </div>
  </div>
</template>
