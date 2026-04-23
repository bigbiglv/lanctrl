<script setup lang="ts">
import { Cpu, ExternalLink, Power, RadioTower, Sparkles, Volume2 } from 'lucide-vue-next'
import { computed, onMounted, onUnmounted, ref } from 'vue'
import { invoke, isTauri } from '@tauri-apps/api/core'
import { listen } from '@tauri-apps/api/event'
import { Badge } from '../../components/ui/badge/index'
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from '../../components/ui/card/index'
import type { PeripheralDevice } from './types'

const devices = ref<PeripheralDevice[]>([])
let unlistenDeviceChanged: (() => void) | null = null

const mockDevices: PeripheralDevice[] = [
  { id: 'kb-01', classType: 'keyboard', name: 'MX Mechanical', status: 'ok' },
  { id: 'mouse-01', classType: 'mouse', name: 'MX Master 3S', status: 'ok' },
  { id: 'usb-01', classType: 'usb', name: 'USB-C Dock', status: 'warning' },
  { id: 'audio-01', classType: 'usb', name: 'Studio DAC', status: 'ok' },
]

const summaryCards = computed(() => {
  const total = devices.value.length
  const healthy = devices.value.filter((device) => device.status?.toLowerCase() === 'ok').length
  const attention = total - healthy

  return [
    {
      label: '已识别外设',
      value: `${total}`,
      caption: '正在与底层硬件监听结果保持同步。',
      icon: Cpu,
    },
    {
      label: '状态稳定',
      value: `${healthy}`,
      caption: '当前可继续联动执行，不需要额外干预。',
      icon: RadioTower,
    },
    {
      label: '需要关注',
      value: `${attention}`,
      caption: '建议前往设备管理页做进一步确认。',
      icon: Sparkles,
    },
  ]
})

const featuredDevices = computed(() => devices.value.slice(0, 6))

function getDeviceLabel(classType: string | null | undefined) {
  switch ((classType || '').toLowerCase()) {
    case 'keyboard':
      return '键盘'
    case 'mouse':
      return '鼠标'
    case 'usb':
      return 'USB'
    default:
      return '通用设备'
  }
}

function getStatusVariant(status: string | null | undefined) {
  return status?.toLowerCase() === 'ok' ? 'default' : 'secondary'
}

onMounted(async () => {
  if (!isTauri()) {
    devices.value = mockDevices
    return
  }

  try {
    devices.value = await invoke<PeripheralDevice[]>('get_peripheral_devices')
    unlistenDeviceChanged = await listen<PeripheralDevice[]>('device-changed', (event) => {
      devices.value = event.payload
    })
    await invoke('start_device_watch')
  } catch (error) {
    console.error('Failed to load peripheral devices:', error)
  }
})

onUnmounted(async () => {
  if (!isTauri()) {
    return
  }

  unlistenDeviceChanged?.()

  try {
    await invoke('stop_device_watch')
  } catch (error) {
    console.error('Failed to stop device watch:', error)
  }
})
</script>

<template>
  <section class="mx-auto flex w-full max-w-[1440px] flex-col gap-6">
    <section class="apple-section apple-inverse overflow-hidden rounded-[2.5rem] border-0">
      <div class="grid gap-8 px-8 py-10 lg:grid-cols-[minmax(0,1.2fr)_380px] lg:px-12 lg:py-14">
        <div class="space-y-6">
          <Badge class="rounded-full border-white/20 bg-white/10 px-3 py-1 text-white">
            默认主题 · {{ featuredDevices.length }} 台设备已接入总览
          </Badge>

          <div class="space-y-4">
            <h2 class="max-w-3xl font-[var(--font-display)] text-4xl font-semibold leading-[1.06] tracking-[-0.04em] text-white lg:text-6xl">
              把设备状态、系统动作和移动端联动，统一收束到一块桌面总控屏里。
            </h2>
            <p class="max-w-2xl text-base leading-7 text-white/72 lg:text-lg">
              视觉上参考 Apple 的节奏与留白，但主题色保留项目自身的克制紫色。后续新增主题时，只需要在
              <code>src/themes</code>
              下补充新的主题目录，就能继续扩展整套浅色与深色模式。
            </p>
          </div>

          <div class="flex flex-wrap gap-3">
            <router-link
              to="/features"
              class="hero-pill border-transparent bg-white text-black hover:bg-white/90"
            >
              打开功能中心
            </router-link>
            <router-link
              to="/connected-devices"
              class="hero-pill border-white/25 bg-white/5 text-white hover:bg-white/12"
            >
              查看设备管理
            </router-link>
          </div>
        </div>

        <div class="grid gap-3">
          <div
            v-for="card in summaryCards"
            :key="card.label"
            class="rounded-[1.75rem] border border-white/10 bg-white/6 p-5 text-white"
          >
            <div class="mb-4 flex items-center justify-between text-white/72">
              <span class="text-sm">{{ card.label }}</span>
              <component :is="card.icon" class="size-4" />
            </div>
            <div class="text-4xl font-semibold tracking-[-0.04em]">{{ card.value }}</div>
            <p class="mt-3 text-sm leading-6 text-white/65">{{ card.caption }}</p>
          </div>
        </div>
      </div>
    </section>

    <section class="grid gap-6 xl:grid-cols-[minmax(0,1.35fr)_420px]">
      <Card class="apple-section border-border/70 bg-card/95">
        <CardHeader class="gap-3">
          <Badge variant="outline" class="w-fit rounded-full">外设状态</Badge>
          <div class="space-y-2">
            <CardTitle class="font-[var(--font-display)] text-3xl tracking-[-0.03em]">
              当前被识别到的设备
            </CardTitle>
            <CardDescription class="max-w-2xl text-sm leading-6">
              只保留最有判断价值的信息：设备类别、设备名称和当前状态，不再堆砌过重的装饰性面板。
            </CardDescription>
          </div>
        </CardHeader>
        <CardContent class="grid gap-4 md:grid-cols-2">
          <article
            v-for="device in featuredDevices"
            :key="device.id"
            class="rounded-[1.5rem] border border-border/70 bg-background/70 p-5 transition-transform duration-200 hover:-translate-y-0.5"
          >
            <div class="mb-4 flex items-start justify-between gap-3">
              <div>
                <p class="text-xs uppercase tracking-[0.18em] text-muted-foreground">
                  {{ getDeviceLabel(device.classType) }}
                </p>
                <h3 class="mt-2 text-lg font-semibold tracking-[-0.02em] text-foreground">
                  {{ device.name || '未命名设备' }}
                </h3>
              </div>
              <Badge :variant="getStatusVariant(device.status)">
                {{ device.status?.toLowerCase() === 'ok' ? '稳定' : '待检查' }}
              </Badge>
            </div>
            <p class="text-sm leading-6 text-muted-foreground">
              设备 ID：{{ device.id.slice(0, 12) }}{{ device.id.length > 12 ? '…' : '' }}
            </p>
          </article>

          <div
            v-if="featuredDevices.length === 0"
            class="col-span-full rounded-[1.5rem] border border-dashed border-border/80 bg-muted/40 px-6 py-12 text-center text-sm text-muted-foreground"
          >
            当前还没有拿到外设数据，可能是硬件监听尚未返回结果。
          </div>
        </CardContent>
      </Card>

      <div class="flex flex-col gap-6">
        <Card class="apple-section apple-inverse border-0">
          <CardHeader class="gap-3">
            <Badge class="w-fit rounded-full border-white/15 bg-white/10 text-white">
              推荐方向
            </Badge>
            <CardTitle class="font-[var(--font-display)] text-3xl tracking-[-0.03em] text-white">
              先做好主题基座，再放大功能模块。
            </CardTitle>
            <CardDescription class="text-white/70">
              现在的结构已经适合继续加新主题包、组件包，以及不同风格的页面变体。
            </CardDescription>
          </CardHeader>
          <CardContent class="space-y-4 text-sm leading-6 text-white/74">
            <div class="flex items-start gap-3">
              <Power class="mt-0.5 size-4 text-white/80" />
              <p>电源与音量等高风险动作统一收口到功能中心，避免分散在各个页面里。</p>
            </div>
            <div class="flex items-start gap-3">
              <Volume2 class="mt-0.5 size-4 text-white/80" />
              <p>深浅色不再是简单反色，所有层级颜色都按主题单独调校。</p>
            </div>
            <div class="flex items-start gap-3">
              <ExternalLink class="mt-0.5 size-4 text-white/80" />
              <p>新增主题时只要沿用默认主题的 token 结构，不用再改页面组件。</p>
            </div>
          </CardContent>
        </Card>

        <Card class="apple-section">
          <CardHeader class="gap-2">
            <CardTitle class="font-[var(--font-display)] text-2xl tracking-[-0.03em]">
              快速入口
            </CardTitle>
            <CardDescription>把高频切换的工作流压缩成更短的路径。</CardDescription>
          </CardHeader>
          <CardContent class="flex flex-col gap-3">
            <router-link
              to="/features"
              class="flex items-center justify-between rounded-full border border-border px-4 py-3 text-sm transition-colors hover:bg-accent"
            >
              <span>进入功能中心</span>
              <Sparkles class="size-4 text-primary" />
            </router-link>
            <router-link
              to="/connected-devices"
              class="flex items-center justify-between rounded-full border border-border px-4 py-3 text-sm transition-colors hover:bg-accent"
            >
              <span>管理受信设备</span>
              <Cpu class="size-4 text-primary" />
            </router-link>
          </CardContent>
        </Card>
      </div>
    </section>
  </section>
</template>
