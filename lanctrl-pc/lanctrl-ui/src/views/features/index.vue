<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { invoke, isTauri } from '@tauri-apps/api/core'
import {
  Card,
  CardContent,
} from '../../components/ui/card/index'
import ActionCard from './components/ActionCard.vue'
import RangeCard from './components/RangeCard.vue'
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

const mockFeatureGroups: FeatureGroup[] = [
  {
    groupKey: 'power',
    title: '电源控制',
    description: '系统电源相关控制能力。',
    features: [
      {
        featureKey: 'shutdown',
        title: '安全关机',
        description: '关闭设备前保存当前工作内容。',
        mobileReady: true,
        control: {
          type: 'action',
          buttonText: '立即关机',
          tone: 'danger',
          confirmRequired: true,
        },
      },
      {
        featureKey: 'restart',
        title: '重新启动',
        description: '快速重启系统并恢复当前工作环境。',
        mobileReady: true,
        control: {
          type: 'action',
          buttonText: '立即重启',
          tone: 'primary',
          confirmRequired: true,
        },
      },
      {
        featureKey: 'test_notification',
        title: '测试提示',
        description: '弹出一条提示，用于验证即时执行和定时任务链路。',
        mobileReady: true,
        control: {
          type: 'action',
          buttonText: '测试提示',
          tone: 'primary',
          confirmRequired: false,
        },
      },
      {
        featureKey: 'volume',
        title: '主音量',
        description: '调整系统主输出音量。',
        mobileReady: true,
        control: {
          type: 'range',
          min: 0,
          max: 100,
          step: 1,
          unit: '%',
          actionText: '应用音量',
        },
      },
    ],
  },
]

const featureList = computed(() => groups.value.flatMap((group) => group.features))
const actionFeatures = computed(() =>
  featureList.value.filter((feature): feature is ActionFeatureDefinition => isActionFeature(feature)),
)
const volumeFeature = computed(() =>
  featureList.value.find((feature): feature is RangeFeatureDefinition => isRangeFeature(feature)),
)

const testPending = ref(false)
const testStopping = ref(false)
let testTimer: number | null = null

async function loadPageData() {
  if (!isTauri()) {
    groups.value = mockFeatureGroups
    currentVolume.value = 38
    loading.value = false
    feedback.value = '演示数据已就绪，可先体验常用控制项。'
    return
  }

  loading.value = true

  try {
    const [featureGroups, snapshot] = await Promise.all([
      invoke<FeatureGroup[]>('get_feature_groups'),
      invoke<FeatureSnapshot>('get_feature_snapshot'),
    ])

    groups.value = featureGroups
    currentVolume.value = snapshot.volumeLevel
  } catch (error) {
    feedback.value = `暂时无法载入控制项：${String(error)}`
  } finally {
    loading.value = false
  }
}

async function refreshSnapshot() {
  if (!isTauri()) {
    snapshotRefreshing.value = true
    window.setTimeout(() => {
      currentVolume.value = 42
      snapshotRefreshing.value = false
      feedback.value = '当前音量已刷新。'
    }, 400)
    return
  }

  snapshotRefreshing.value = true

  try {
    const snapshot = await invoke<FeatureSnapshot>('get_feature_snapshot')
    currentVolume.value = snapshot.volumeLevel
    feedback.value = `当前音量为 ${snapshot.volumeLevel}%`
  } catch (error) {
    feedback.value = `音量刷新失败：${String(error)}`
  } finally {
    snapshotRefreshing.value = false
  }
}

async function runCommand(feature: FeatureDefinition, command: FeatureCommand) {
  if (!isTauri()) {
    activeFeatureKey.value = feature.featureKey
    window.setTimeout(() => {
      activeFeatureKey.value = null
      feedback.value =
        command.feature === 'volume'
          ? `音量已设置为 ${currentVolume.value}%`
          : `${feature.title} 已执行`
    }, 500)
    return
  }

  activeFeatureKey.value = feature.featureKey

  try {
    const result = await invoke<FeatureExecutionResult>('execute_feature_command', { command })
    feedback.value = result.message

    if (typeof result.volumeLevel === 'number') {
      currentVolume.value = result.volumeLevel
    }
  } catch (error) {
    feedback.value = `${feature.title} 执行失败：${String(error)}`
  } finally {
    activeFeatureKey.value = null
  }
}

function buildActionCommand(feature: ActionFeatureDefinition): FeatureCommand {
  if (feature.featureKey === 'shutdown') {
    return { feature: 'shutdown' }
  }

  if (feature.featureKey === 'test_notification') {
    return { feature: 'test_notification' }
  }

  if (feature.featureKey === 'error_test') {
    return { feature: 'error_test' }
  }

  throw new Error(`未支持的操作指令：${feature.featureKey}`)
}

function handleTestAction() {
  testPending.value = true
  feedback.value = '控制演示进行中…'

  testTimer = window.setTimeout(() => {
    testPending.value = false
    feedback.value = '演示已完成。'
    testTimer = null
  }, 5000)
}

function handleCancelTestAction() {
  if (testTimer) {
    clearTimeout(testTimer)
    testTimer = null
  }

  testStopping.value = true
  feedback.value = '正在停止演示…'

  window.setTimeout(() => {
    testStopping.value = false
    testPending.value = false
    feedback.value = '演示已停止。'
  }, 1500)
}

async function handleAction(feature: ActionFeatureDefinition) {
  if (feature.featureKey === 'test-long-run') {
    handleTestAction()
    return
  }

  if (feature.control.confirmRequired) {
    const confirmed = window.confirm(`确认执行“${feature.title}”吗？`)
    if (!confirmed) {
      return
    }
  }

  try {
    await runCommand(feature, buildActionCommand(feature))
  } catch (error) {
    feedback.value = String(error instanceof Error ? error.message : error)
  }
}

function handleCancel(feature: ActionFeatureDefinition) {
  if (feature.featureKey === 'test-long-run') {
    handleCancelTestAction()
    return
  }

  feedback.value = `${feature.title} 当前不支持中途取消。`
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
  <section class="mx-auto flex w-full max-w-330 flex-col gap-6">
    <div
      v-if="feedback"
      class="rounded-[1.75rem] border border-border/70 bg-card/90 px-5 py-4 text-sm text-foreground"
    >
      {{ feedback }}
    </div>

    <div
      v-if="loading"
      class="rounded-[1.75rem] border border-dashed border-border/80 bg-muted/40 px-6 py-14 text-center text-sm text-muted-foreground"
    >
      正在载入控制项…
    </div>

    <template v-else>
      <section class="grid gap-6 xl:grid-cols-[minmax(0,1.2fr)_420px]">
        <Card class="apple-section">

          <CardContent class="grid gap-4 md:grid-cols-2">
            <ActionCard
              v-for="feature in actionFeatures"
              :key="feature.featureKey"
              :feature="feature"
              :pending="activeFeatureKey === feature.featureKey"
              @execute="handleAction"
              @cancel="handleCancel"
            />

            <template v-if="volumeFeature">

              <RangeCard
                :feature="volumeFeature"
                :value="currentVolume"
                :pending="activeFeatureKey === volumeFeature.featureKey"
                :refreshing="snapshotRefreshing"
                @update:value="currentVolume = $event"
                @apply="handleVolumeApply"
                @refresh="refreshSnapshot"
              />
            </template>
          </CardContent>
        </Card>


      </section>
    </template>
  </section>
</template>
