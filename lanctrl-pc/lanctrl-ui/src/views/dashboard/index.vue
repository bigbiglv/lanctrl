<script setup lang="ts">
import { CircleHelp, Gamepad2, Keyboard, Mouse, Usb } from 'lucide-vue-next'
import { computed, onMounted, onUnmounted, ref } from 'vue'
import { invoke, isTauri } from '@tauri-apps/api/core'
import { listen } from '@tauri-apps/api/event'
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
} from '../../components/ui/card/index'
import type { PeripheralDevice } from './types'

const devices = ref<PeripheralDevice[]>([])
let unlistenDeviceChanged: (() => void) | null = null

const mockDevices: PeripheralDevice[] = [
  { id: 'kb-01', classType: 'keyboard', name: 'MX Mechanical', status: 'ok' },
  { id: 'mouse-01', classType: 'mouse', name: 'MX Master 3S', status: 'ok' },
  { id: 'gamepad-01', classType: 'hidclass', name: 'Xbox Wireless Controller', status: 'ok' },
  { id: 'usb-01', classType: 'usb', name: 'USB-C Dock', status: 'warning' },
  { id: 'audio-01', classType: 'media', name: 'Studio DAC', status: 'ok' },
]

type DeviceCategory = 'keyboard' | 'mouse' | 'controller' | 'usb' | 'other'

const categoryOrder: Record<DeviceCategory, number> = {
  keyboard: 0,
  mouse: 1,
  controller: 2,
  usb: 3,
  other: 4,
}

const categoryMeta = {
  keyboard: { label: '键盘', icon: Keyboard },
  mouse: { label: '鼠标', icon: Mouse },
  controller: { label: '控制器', icon: Gamepad2 },
  usb: { label: 'USB', icon: Usb },
  other: { label: '其他', icon: CircleHelp },
} satisfies Record<DeviceCategory, { label: string, icon: unknown }>

const visibleDevices = computed(() =>
  [...devices.value].sort((left, right) => {
    const leftCategory = getDeviceCategory(left)
    const rightCategory = getDeviceCategory(right)
    if (leftCategory !== rightCategory) {
      return categoryOrder[leftCategory] - categoryOrder[rightCategory]
    }

    return (left.name || '').localeCompare(right.name || '', 'zh-CN')
  }),
)

function getDeviceCategory(device: PeripheralDevice): DeviceCategory {
  const classType = (device.classType || '').toLowerCase()
  const name = (device.name || '').toLowerCase()
  const id = (device.id || '').toLowerCase()
  const fingerprint = `${classType} ${name} ${id}`

  switch (classType) {
    case 'keyboard':
      return 'keyboard'
    case 'mouse':
      return 'mouse'
    case 'usb':
      return 'usb'
    default:
      break
  }

  // HID 设备里控制器、键盘、鼠标都很常见，需要结合名称和实例 ID 再分类。
  if (/(gamepad|controller|joystick|xbox|dualshock|dualsense|手柄|控制器)/i.test(fingerprint)) {
    return 'controller'
  }
  if (/(keyboard|键盘)/i.test(fingerprint)) {
    return 'keyboard'
  }
  if (/(mouse|mice|鼠标)/i.test(fingerprint)) {
    return 'mouse'
  }
  if (classType === 'hidclass' || id.startsWith('hid\\')) {
    return 'other'
  }
  if (id.startsWith('usb\\') || fingerprint.includes('usb')) {
    return 'usb'
  }

  return 'other'
}

function getDeviceMeta(device: PeripheralDevice) {
  return categoryMeta[getDeviceCategory(device)]
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
  <section class="flex w-full flex-col gap-6">

      <Card class="apple-section border-border/70 bg-card/95">
        <CardHeader class="gap-3">
          <div class="space-y-2">
            <CardTitle class="font-(--font-display) text-3xl tracking-[-0.03em]">
              外设
            </CardTitle>

          </div>
        </CardHeader>
        <CardContent class="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
          <article
            v-for="device in visibleDevices"
            :key="device.id"
            class="rounded-[1.5rem] border border-border/70 bg-background/70 p-5 transition-transform duration-200 hover:-translate-y-0.5"
          >
            <div class="flex flex-col gap-5">
              <div class="flex size-16 items-center justify-center rounded-[1.25rem] border border-border/70 bg-accent/60 text-primary">
                <component :is="getDeviceMeta(device).icon" class="size-9" />
              </div>

              <div class="space-y-2">
                <p class="text-xs uppercase tracking-[0.18em] text-muted-foreground">
                  {{ getDeviceMeta(device).label }}
                </p>
                <h3 class="text-lg font-semibold tracking-[-0.02em] text-foreground">
                  {{ device.name || '未命名设备' }}
                </h3>
                <p class="text-sm leading-6 text-muted-foreground">
                  设备 ID：{{ device.id.slice(0, 12) }}{{ device.id.length > 12 ? '…' : '' }}
                </p>
              </div>
            </div>
          </article>

          <div
            v-if="visibleDevices.length === 0"
            class="col-span-full rounded-[1.5rem] border border-dashed border-border/80 bg-muted/40 px-6 py-12 text-center text-sm text-muted-foreground"
          >
            暂未检测到可展示的设备信息。
          </div>
        </CardContent>
      </Card>

  </section>
</template>
