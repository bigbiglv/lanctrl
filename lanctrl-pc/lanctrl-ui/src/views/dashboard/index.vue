<script setup lang="ts">
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

    </section>
  </section>
</template>
