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
  Zap,
} from "lucide-vue-next";
import MorphIcon from "./MorphIcon.vue";
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

const syncIconPaths = [
  "M12 20.5c-.8 0-1.45-.65-1.45-1.45S11.2 17.6 12 17.6s1.45.65 1.45 1.45-.65 1.45-1.45 1.45Zm-4.18-4.02a1.1 1.1 0 0 1-.78-1.88 7.02 7.02 0 0 1 9.92 0 1.1 1.1 0 0 1-1.56 1.56 4.8 4.8 0 0 0-6.8 0 1.1 1.1 0 0 1-.78.32Zm-3.22-3.2a1.1 1.1 0 0 1-.78-1.88 11.58 11.58 0 0 1 16.36 0 1.1 1.1 0 0 1-1.56 1.56 9.36 9.36 0 0 0-13.24 0 1.1 1.1 0 0 1-.78.32Zm-3.18-3.18a1.1 1.1 0 0 1-.78-1.88 16.06 16.06 0 0 1 22.72 0 1.1 1.1 0 0 1-1.56 1.56 13.84 13.84 0 0 0-19.6 0 1.1 1.1 0 0 1-.78.32Z",
  "M12 21c-1.05 0-1.9-.85-1.9-1.9s.85-1.9 1.9-1.9 1.9.85 1.9 1.9S13.05 21 12 21Zm-6.4-2.32a1.15 1.15 0 0 1-.82-1.96L16.72 4.78a1.15 1.15 0 0 1 1.62 1.62L6.4 18.34a1.15 1.15 0 0 1-.8.34Zm2.1-4.5a1.15 1.15 0 0 1-.82-1.96 7.24 7.24 0 0 1 5.76-2.1l-2.22 2.22c-.7.2-1.35.58-1.9 1.13a1.15 1.15 0 0 1-.82.71Zm10.1.12c-.3 0-.6-.12-.82-.34a6.88 6.88 0 0 0-1.84-1.28l1.72-1.72c.62.34 1.2.76 1.76 1.26a1.15 1.15 0 0 1-.82 1.96v.12Zm-13.25-3.28a1.15 1.15 0 0 1-.82-1.96 11.7 11.7 0 0 1 12.18-2.72l-1.86 1.86a9.36 9.36 0 0 0-8.68 2.48 1.15 1.15 0 0 1-.82.34Zm16.2.1c-.3 0-.6-.12-.82-.34a9.5 9.5 0 0 0-1.26-1.08l1.64-1.64c.43.3.84.62 1.24.98a1.15 1.15 0 0 1-.8 1.98Z",
  "M12 20.6a1.5 1.5 0 1 1 0-3 1.5 1.5 0 0 1 0 3Zm-4.42-4.34a1.12 1.12 0 0 1-.8-1.9 7.38 7.38 0 0 1 10.44 0 1.12 1.12 0 0 1-1.58 1.58 5.14 5.14 0 0 0-7.28 0c-.22.22-.5.32-.78.32Zm-3.38-3.38a1.12 1.12 0 0 1-.8-1.9 12.18 12.18 0 0 1 17.2 0 1.12 1.12 0 0 1-1.58 1.58 9.94 9.94 0 0 0-14.04 0c-.22.22-.5.32-.78.32Zm16.7-6.08h-2.3V4.5a1.1 1.1 0 0 1 2.2 0v2.3h.1Zm0 4.8h-2.3V9.3h2.3v2.3Zm-4.8-4.8h-2.3V4.5a1.1 1.1 0 0 1 2.2 0v2.3h.1Zm0 4.8h-2.3V9.3h2.3v2.3Z",
];

const connectionStatusIndex = computed(() => {
  if (connectionStatus.value === "connected") {
    return 0;
  }
  if (connectionStatus.value === "offline") {
    return 1;
  }
  return 2;
});

const connectionAriaLabel = computed(() => {
  if (connectionStatus.value === "connected") {
    return `实时同步已连接，${connectionDetail.value}`;
  }
  if (connectionStatus.value === "offline") {
    return `实时同步已断开，${connectionDetail.value}`;
  }
  return `实时同步连接中，${connectionDetail.value}`;
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
      <div class="connection-card" :class="connectionStatus" :aria-label="connectionAriaLabel" aria-live="polite">
        <MorphIcon
          class="connection-icon"
          :class="connectionStatus"
          :paths="syncIconPaths"
          :active-index="connectionStatusIndex"
          size="1.2rem"
        />
        <button class="icon-button connection-refresh" type="button" aria-label="刷新状态" @click="refreshState()">
          <RefreshCw class="button-icon" />
        </button>
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
