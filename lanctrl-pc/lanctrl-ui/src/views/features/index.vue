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
        description: '向执行层发起安全关机请求。',
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
        description: '重新启动当前桌面环境。',
        mobileReady: true,
        control: {
          type: 'action',
          buttonText: '立即重启',
          tone: 'primary',
          confirmRequired: true,
        },
      },
      {
        featureKey: 'volume',
        title: '主音量',
        description: '控制系统级主输出音量。',
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
  title: '交互状态演示',
  description: '模拟一个持续 5 秒的动作，验证“执行中”和“终止中”的按钮状态切换。',
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
    feedback.value = '当前处于浏览器预览模式，功能数据已切换为本地 mock。'
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
    feedback.value = `加载功能页失败：${String(error)}`
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
      feedback.value = '浏览器预览模式下，音量已模拟同步为 42%。'
    }, 400)
    return
  }

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
  if (!isTauri()) {
    activeFeatureKey.value = feature.featureKey
    window.setTimeout(() => {
      activeFeatureKey.value = null
      feedback.value =
        command.feature === 'volume'
          ? `浏览器预览模式：已模拟设置音量为 ${currentVolume.value}%`
          : `浏览器预览模式：已模拟执行 ${feature.title}`
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

  return { feature: 'restart' }
}

function handleTestAction() {
  testPending.value = true
  feedback.value = '演示任务已开始，预计持续 5 秒。'

  testTimer = window.setTimeout(() => {
    testPending.value = false
    feedback.value = '演示任务执行完成。'
    testTimer = null
  }, 5000)
}

function handleCancelTestAction() {
  if (testTimer) {
    clearTimeout(testTimer)
    testTimer = null
  }

  testStopping.value = true
  feedback.value = '正在请求终止任务…'

  window.setTimeout(() => {
    testStopping.value = false
    testPending.value = false
    feedback.value = '演示任务已成功终止。'
  }, 1500)
}

async function handleAction(feature: ActionFeatureDefinition) {
  if (feature.featureKey === 'test-long-run') {
    handleTestAction()
    return
  }

  if (feature.control.confirmRequired) {
    const confirmed = window.confirm(`确认执行“${feature.title}”吗？该操作会立即生效。`)
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

  feedback.value = `操作“${feature.title}”当前不支持中途终止。`
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
              电源、音量与未来扩展动作，都放进统一的控制语言里。
            </h2>
            <p class="max-w-2xl text-base leading-7 text-white/72">
              样式上收敛成更安静、更可复用的模块，行为上保留清晰的状态反馈，方便后续继续增加新的控制能力和新的主题包。
            </p>
          </div>
          <div class="flex flex-wrap gap-3">
            <router-link
              to="/connected-devices"
              class="hero-pill border-transparent bg-white text-black hover:bg-white/90"
            >
              前往设备管理
            </router-link>
            <button
              type="button"
              class="hero-pill border-white/25 bg-white/5 text-white hover:bg-white/12"
              @click="refreshSnapshot"
            >
              同步当前音量
            </button>
          </div>
        </div>

        <Card class="border-white/10 bg-white/6 text-white shadow-none">
          <CardHeader class="gap-3">
            <Badge class="w-fit rounded-full border-white/15 bg-white/10 text-white">
              当前反馈
            </Badge>
            <CardTitle class="font-[var(--font-display)] text-2xl tracking-[-0.03em] text-white">
              最近一次执行回执
            </CardTitle>
          </CardHeader>
          <CardContent class="space-y-4 text-sm leading-6 text-white/74">
            <p>{{ feedback || '尚未执行任何动作。点击下方任意控制项后，回执会出现在这里。' }}</p>
            <div class="flex items-start gap-3">
              <ArrowUpRight class="mt-0.5 size-4 text-white/80" />
              <p>所有动作反馈都以 Rust 执行层结果为准，避免前端自行猜测状态。</p>
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
      正在加载功能定义与快照信息…
    </div>

    <template v-else>
      <section class="grid gap-6 xl:grid-cols-[minmax(0,1.25fr)_360px]">
        <Card class="apple-section">
          <CardHeader class="gap-3">
            <Badge variant="outline" class="w-fit rounded-full">动作测试</Badge>
            <div class="space-y-2">
              <CardTitle class="font-[var(--font-display)] text-3xl tracking-[-0.03em]">
                状态过渡演示
              </CardTitle>
              <CardDescription>
                先把最复杂的按钮状态跑顺，再把真实业务动作接进去，后面加任何动作卡片都会更稳。
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
            <Badge variant="secondary" class="w-fit rounded-full">设计原则</Badge>
            <CardTitle class="font-[var(--font-display)] text-2xl tracking-[-0.03em]">
              功能页不做管理台拼贴。
            </CardTitle>
          </CardHeader>
          <CardContent class="space-y-4 text-sm leading-6 text-muted-foreground">
            <div class="flex items-start gap-3">
              <Power class="mt-0.5 size-4 text-primary" />
              <p>危险动作用更明确的层级和二次确认，不与常规动作混在一起。</p>
            </div>
            <div class="flex items-start gap-3">
              <SlidersHorizontal class="mt-0.5 size-4 text-primary" />
              <p>范围型能力独立成一类卡片，避免和即时动作使用同一交互模式。</p>
            </div>
            <div class="flex items-start gap-3">
              <Sparkles class="mt-0.5 size-4 text-primary" />
              <p>新增能力时只需要补数据模型和卡片，不需要重做整页结构。</p>
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
                即时动作
              </CardTitle>
              <CardDescription>
                将关机、重启等高风险动作从视觉上做出更明确的风险区分。
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
            <Badge variant="secondary" class="w-fit rounded-full">范围控制</Badge>
            <CardTitle class="font-[var(--font-display)] text-3xl tracking-[-0.03em]">
              音量
            </CardTitle>
            <CardDescription>
              深浅色模式下都只保留一条主滑杆，不再做杂乱的装饰性控制条。
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
