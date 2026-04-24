<script setup lang="ts">
import { ArrowUpRight, Power, SlidersHorizontal, Sparkles } from 'lucide-vue-next'
import { computed, onMounted, ref } from 'vue'
import { invoke, isTauri } from '@tauri-apps/api/core'
import { Badge } from '../../components/ui/badge/index'
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
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

const testFeature: ActionFeatureDefinition = {
  featureKey: 'test-long-run',
  title: '控制演示',
  description: '演示按钮状态切换与操作反馈效果。',
  mobileReady: true,
  control: {
    type: 'action',
    buttonText: '开始演示',
    tone: 'primary',
    confirmRequired: false,
  },
}

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

  return { feature: 'restart' }
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

  await runCommand(feature, buildActionCommand(feature))
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
  <section class="mx-auto flex w-full max-w-[1320px] flex-col gap-6">
    <section class="apple-section apple-inverse rounded-[2.5rem] border-0 px-8 py-10 lg:px-12">
      <div class="grid gap-8 lg:grid-cols-[minmax(0,1.2fr)_360px]">
        <div class="space-y-5">
          <Badge class="w-fit rounded-full border-white/15 bg-white/10 text-white">功能中心</Badge>
          <div class="space-y-4">
            <h2 class="font-[var(--font-display)] text-4xl font-semibold leading-[1.06] tracking-[-0.04em] text-white lg:text-6xl">
              常用控制集中在这里，操作更直接。
            </h2>
            <p class="max-w-2xl text-base leading-7 text-white/72">
              无论是系统电源还是主音量，都可以在同一个入口里快速完成，减少来回切换。
            </p>
          </div>
          <div class="flex flex-wrap gap-3">
            <router-link
              to="/connected-devices"
              class="hero-pill border-transparent bg-white text-black hover:bg-white/90"
            >
              查看设备
            </router-link>
            <button
              type="button"
              class="hero-pill border-white/25 bg-white/5 text-white hover:bg-white/12"
              @click="refreshSnapshot"
            >
              刷新当前音量
            </button>
          </div>
        </div>

        <Card class="border-white/10 bg-white/6 text-white shadow-none">
          <CardHeader class="gap-3">
            <Badge class="w-fit rounded-full border-white/15 bg-white/10 text-white">
              最新反馈
            </Badge>
            <CardTitle class="font-[var(--font-display)] text-2xl tracking-[-0.03em] text-white">
              当前状态
            </CardTitle>
          </CardHeader>
          <CardContent class="space-y-4 text-sm leading-6 text-white/74">
            <p>{{ feedback || '选择任意控制项后，结果会显示在这里。' }}</p>
            <div class="flex items-start gap-3">
              <ArrowUpRight class="mt-0.5 size-4 text-white/80" />
              <p>重要操作会立即给出状态反馈，方便确认当前结果。</p>
            </div>
          </CardContent>
        </Card>
      </div>
    </section>

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
      <section class="grid gap-6 xl:grid-cols-[minmax(0,1.25fr)_360px]">
        <Card class="apple-section">
          <CardHeader class="gap-3">
            <Badge variant="outline" class="w-fit rounded-full">操作演示</Badge>
            <div class="space-y-2">
              <CardTitle class="font-[var(--font-display)] text-3xl tracking-[-0.03em]">
                状态演示
              </CardTitle>
              <CardDescription>
                先体验按钮反馈与状态切换，再执行真实控制项。
              </CardDescription>
            </div>
          </CardHeader>
          <CardContent>
            <ActionCard
              :feature="testFeature"
              :pending="testPending"
              :stopping="testStopping"
              @execute="handleAction"
              @cancel="handleCancel"
            />
          </CardContent>
        </Card>

        <Card class="apple-section">
          <CardHeader class="gap-3">
            <Badge variant="secondary" class="w-fit rounded-full">使用说明</Badge>
            <CardTitle class="font-[var(--font-display)] text-2xl tracking-[-0.03em]">
              操作更集中，反馈更明确。
            </CardTitle>
          </CardHeader>
          <CardContent class="space-y-4 text-sm leading-6 text-muted-foreground">
            <div class="flex items-start gap-3">
              <Power class="mt-0.5 size-4 text-primary" />
              <p>高风险操作会要求确认，避免误触。</p>
            </div>
            <div class="flex items-start gap-3">
              <SlidersHorizontal class="mt-0.5 size-4 text-primary" />
              <p>滑杆调整适合连续控制，动作按钮适合即时执行。</p>
            </div>
            <div class="flex items-start gap-3">
              <Sparkles class="mt-0.5 size-4 text-primary" />
              <p>每次操作完成后，都会在页面内给出结果提示。</p>
            </div>
          </CardContent>
        </Card>
      </section>

      <section class="grid gap-6 xl:grid-cols-[minmax(0,1.2fr)_420px]">
        <Card class="apple-section">
          <CardHeader class="gap-3">
            <Badge variant="outline" class="w-fit rounded-full">电源控制</Badge>
            <div class="space-y-2">
              <CardTitle class="font-[var(--font-display)] text-3xl tracking-[-0.03em]">
                即时操作
              </CardTitle>
              <CardDescription>
                重要控制项集中展示，方便快速执行。
              </CardDescription>
            </div>
          </CardHeader>
          <CardContent class="grid gap-4 md:grid-cols-2">
            <ActionCard
              v-for="feature in actionFeatures"
              :key="feature.featureKey"
              :feature="feature"
              :pending="activeFeatureKey === feature.featureKey"
              @execute="handleAction"
              @cancel="handleCancel"
            />
          </CardContent>
        </Card>

        <Card v-if="volumeFeature" class="apple-section">
          <CardHeader class="gap-3">
            <Badge variant="secondary" class="w-fit rounded-full">音量控制</Badge>
            <CardTitle class="font-[var(--font-display)] text-3xl tracking-[-0.03em]">
              主音量
            </CardTitle>
            <CardDescription>
              调整系统主输出音量，并可随时刷新当前状态。
            </CardDescription>
          </CardHeader>
          <CardContent>
            <RangeCard
              :feature="volumeFeature"
              :value="currentVolume"
              :pending="activeFeatureKey === volumeFeature.featureKey"
              :refreshing="snapshotRefreshing"
              @update:value="currentVolume = $event"
              @apply="handleVolumeApply"
              @refresh="refreshSnapshot"
            />
          </CardContent>
        </Card>
      </section>
    </template>
  </section>
</template>
