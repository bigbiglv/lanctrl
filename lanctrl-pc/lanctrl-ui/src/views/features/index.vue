<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { invoke } from '@tauri-apps/api/core'
import FeatureActionCard from './components/FeatureActionCard.vue'
import FeatureRangeCard from './components/FeatureRangeCard.vue'
import type {
  ActionFeatureDefinition,
  FeatureCommand,
  FeatureDefinition,
  FeatureExecutionResult,
  FeatureGroup,
  FeatureSnapshot,
  RangeFeatureDefinition,
} from './types'
import { isActionFeature, isRangeFeature } from './types'

const groups = ref<FeatureGroup[]>([])
const currentVolume = ref(0)
const loading = ref(true)
const snapshotRefreshing = ref(false)
const feedback = ref('')
const activeFeatureKey = ref<string | null>(null)

const featureList = computed(() => groups.value.flatMap((group) => group.features))
const actionFeatures = computed(() =>
  featureList.value.filter((feature): feature is ActionFeatureDefinition => isActionFeature(feature)),
)
const volumeFeature = computed(() =>
  featureList.value.find((feature): feature is RangeFeatureDefinition => isRangeFeature(feature)),
)

async function loadPageData() {
  loading.value = true

  try {
    const [featureGroups, snapshot] = await Promise.all([
      invoke<FeatureGroup[]>('get_feature_groups'),
      invoke<FeatureSnapshot>('get_feature_snapshot'),
    ])

    groups.value = featureGroups
    currentVolume.value = snapshot.volumeLevel
  } catch (error) {
    feedback.value = `加载功能页失败：${String(error)}`
  } finally {
    loading.value = false
  }
}

async function refreshSnapshot() {
  snapshotRefreshing.value = true

  try {
    const snapshot = await invoke<FeatureSnapshot>('get_feature_snapshot')
    currentVolume.value = snapshot.volumeLevel
    feedback.value = `当前系统音量已同步为 ${snapshot.volumeLevel}%`
  } catch (error) {
    feedback.value = `同步音量失败：${String(error)}`
  } finally {
    snapshotRefreshing.value = false
  }
}

async function runCommand(feature: FeatureDefinition, command: FeatureCommand) {
  activeFeatureKey.value = feature.featureKey

  try {
    const result = await invoke<FeatureExecutionResult>('execute_feature_command', { command })
    feedback.value = result.message

    if (typeof result.volumeLevel === 'number') {
      currentVolume.value = result.volumeLevel
    }
  } catch (error) {
    feedback.value = `${feature.title}执行失败：${String(error)}`
  } finally {
    activeFeatureKey.value = null
  }
}

function buildActionCommand(feature: ActionFeatureDefinition): FeatureCommand {
  if (feature.featureKey === 'shutdown') {
    return { feature: 'shutdown' }
  }

  return { feature: 'restart' }
}

async function handleAction(feature: ActionFeatureDefinition) {
  if (feature.control.confirmRequired) {
    const confirmed = window.confirm(`确认执行“${feature.title}”吗？该操作会立即生效。`)
    if (!confirmed) {
      return
    }
  }

  await runCommand(feature, buildActionCommand(feature))
}

async function handleVolumeApply(feature: RangeFeatureDefinition) {
  await runCommand(feature, {
    feature: 'volume',
    level: currentVolume.value,
  })
}

onMounted(loadPageData)
</script>

<template>
  <section class="feature-page fade-in">
    <header class="page-header">
      <div>
        <h2>功能中心</h2>
        <p>PC 页面、Rust 执行层，以及移动端远程指令统一复用同一套功能模型。</p>
      </div>
      <div class="api-info glass-panel">
        <span>移动端接口</span>
        <strong>/features/catalog · /features/execute</strong>
      </div>
    </header>

    <div v-if="feedback" class="feedback-banner glass-panel">
      {{ feedback }}
    </div>

    <div v-if="loading" class="loading-panel glass-panel">
      正在加载功能定义...
    </div>

    <template v-else>
      <section class="group-section">
        <div class="group-head">
          <h3>电源控制</h3>
          <p>关机与重启属于危险操作，页面与移动端都应该走显式确认流程。</p>
        </div>

        <div class="action-grid">
          <FeatureActionCard
            v-for="feature in actionFeatures"
            :key="feature.featureKey"
            :feature="feature"
            :pending="activeFeatureKey === feature.featureKey"
            @execute="handleAction"
          />
        </div>
      </section>

      <section v-if="volumeFeature" class="group-section">
        <div class="group-head">
          <h3>音频控制</h3>
          <p>音量使用 0 到 100 的绝对值，后续移动端可以直接复用同一个参数约定。</p>
        </div>

        <FeatureRangeCard
          :feature="volumeFeature"
          :value="currentVolume"
          :pending="activeFeatureKey === volumeFeature.featureKey"
          :refreshing="snapshotRefreshing"
          @update:value="currentVolume = $event"
          @apply="handleVolumeApply"
          @refresh="refreshSnapshot"
        />
      </section>
    </template>
  </section>
</template>

<style scoped lang="scss">
.feature-page {
  height: 100%;
  overflow-y: auto;
  padding: 2rem;
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
}

.page-header {
  display: flex;
  justify-content: space-between;
  gap: 1.5rem;
  align-items: flex-start;

  h2 {
    font-size: 2rem;
    color: var(--text-main);
    margin-bottom: 0.5rem;
  }

  p {
    color: var(--text-muted);
    line-height: 1.7;
    max-width: 720px;
  }
}

.api-info {
  padding: 1rem 1.25rem;
  border: 1px solid var(--border-color);
  display: flex;
  flex-direction: column;
  gap: 0.4rem;
  min-width: 250px;

  span {
    color: var(--text-muted);
    font-size: 0.9rem;
  }

  strong {
    color: var(--text-main);
    font-size: 1rem;
  }
}

.feedback-banner,
.loading-panel {
  padding: 1rem 1.25rem;
  border: 1px solid var(--border-color);
  color: var(--text-main);
}

.group-section {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.group-head {
  display: flex;
  flex-direction: column;
  gap: 0.35rem;

  h3 {
    color: var(--text-main);
    font-size: 1.25rem;
  }

  p {
    color: var(--text-muted);
  }
}

.action-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
  gap: 1rem;
}

@media (max-width: 960px) {
  .page-header {
    flex-direction: column;
  }

  .api-info {
    width: 100%;
    min-width: unset;
  }
}
</style>
