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
      label: '已连接设备',
      value: `${total}`,
      caption: '常用外设状态一目了然。',
      icon: Cpu,
    },
    {
      label: '运行正常',
      value: `${healthy}`,
      caption: '当前可继续使用，无需额外处理。',
      icon: RadioTower,
    },
    {
      label: '需要关注',
      value: `${attention}`,
      caption: '建议前往设备管理查看详情。',
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
            总览 · {{ featuredDevices.length }} 台设备在线展示
          </Badge>

          <div class="space-y-4">
            <h2 class="max-w-3xl font-[var(--font-display)] text-4xl font-semibold leading-[1.06] tracking-[-0.04em] text-white lg:text-6xl">
              把常用控制、设备状态与系统操作，集中到同一个桌面入口。
            </h2>
            <p class="max-w-2xl text-base leading-7 text-white/72 lg:text-lg">
              在开始操作前，先快速查看当前设备情况、核心控制项与最近需要关注的状态，让常用操作保持清晰顺手。
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
          <Badge variant="outline" class="w-fit rounded-full">设备概览</Badge>
          <div class="space-y-2">
            <CardTitle class="font-[var(--font-display)] text-3xl tracking-[-0.03em]">
              当前设备
            </CardTitle>
            <CardDescription class="max-w-2xl text-sm leading-6">
              快速查看已识别的外设与当前状态，便于在操作前确认连接情况。
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
                {{ device.status?.toLowerCase() === 'ok' ? '正常' : '待检查' }}
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
            暂未检测到可展示的设备信息。
          </div>
        </CardContent>
      </Card>

      <div class="flex flex-col gap-6">
        <Card class="apple-section apple-inverse border-0">
          <CardHeader class="gap-3">
            <Badge class="w-fit rounded-full border-white/15 bg-white/10 text-white">
              常用入口
            </Badge>
            <CardTitle class="font-[var(--font-display)] text-3xl tracking-[-0.03em] text-white">
              常用操作放在更近的位置。
            </CardTitle>
            <CardDescription class="text-white/70">
              将高频控制项收纳到统一入口，减少页面来回切换。
            </CardDescription>
          </CardHeader>
          <CardContent class="space-y-4 text-sm leading-6 text-white/74">
            <div class="flex items-start gap-3">
              <Power class="mt-0.5 size-4 text-white/80" />
              <p>电源相关操作集中管理，重要动作更清晰。</p>
            </div>
            <div class="flex items-start gap-3">
              <Volume2 class="mt-0.5 size-4 text-white/80" />
              <p>音量调整与状态同步可以直接在功能中心完成。</p>
            </div>
            <div class="flex items-start gap-3">
              <ExternalLink class="mt-0.5 size-4 text-white/80" />
              <p>设备管理页提供更完整的连接信息与操作入口。</p>
            </div>
          </CardContent>
        </Card>

        <Card class="apple-section">
          <CardHeader class="gap-2">
            <CardTitle class="font-[var(--font-display)] text-2xl tracking-[-0.03em]">
              快速入口
            </CardTitle>
            <CardDescription>从这里直接进入常用页面。</CardDescription>
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
              <span>管理设备</span>
              <Cpu class="size-4 text-primary" />
            </router-link>
          </CardContent>
        </Card>
      </div>
    </section>
  </section>
</template>
