<script setup lang="ts">
import { ArrowUpRight, Link2, RefreshCw, Smartphone, Unplug } from 'lucide-vue-next'
import { computed, onMounted, onUnmounted, ref } from 'vue'
import { invoke, isTauri } from '@tauri-apps/api/core'
import { listen } from '@tauri-apps/api/event'
import type { UnlistenFn } from '@tauri-apps/api/event'
import { Badge } from '../../components/ui/badge/index'
import { Button } from '../../components/ui/button/index'
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from '../../components/ui/card/index'

interface ClientInfo {
  client_id: string
  client_name: string
  last_seen_at: number
  last_ip: string | null
  is_online: boolean
  is_connected: boolean
}

const clients = ref<ClientInfo[]>([])
const loading = ref(true)

const mockClients: ClientInfo[] = [
  {
    client_id: 'mobile-alpha',
    client_name: 'iPhone 16 Pro',
    last_seen_at: Date.now() - 1000 * 60 * 6,
    last_ip: '192.168.31.18',
    is_online: true,
    is_connected: true,
  },
  {
    client_id: 'mobile-beta',
    client_name: 'iPad mini',
    last_seen_at: Date.now() - 1000 * 60 * 42,
    last_ip: '192.168.31.29',
    is_online: true,
    is_connected: false,
  },
  {
    client_id: 'mobile-gamma',
    client_name: 'Android Phone',
    last_seen_at: Date.now() - 1000 * 60 * 180,
    last_ip: null,
    is_online: false,
    is_connected: false,
  },
]

let unlistenConnected: UnlistenFn | null = null
let unlistenDisconnected: UnlistenFn | null = null

const onlineCount = computed(() => clients.value.filter((client) => client.is_online).length)
const connectedCount = computed(() => clients.value.filter((client) => client.is_connected).length)

async function fetchClients() {
  if (!isTauri()) {
    loading.value = true
    clients.value = mockClients
    loading.value = false
    return
  }

  try {
    loading.value = true
    const rawClients = await invoke<ClientInfo[]>('get_clients_with_status')

    const checkPromises = rawClients.map(async (client) => {
      let isOnline = false

      if (client.last_ip) {
        try {
          isOnline = await invoke<boolean>('ping_mobile_device', { ip: client.last_ip })
        } catch {
          isOnline = false
        }
      }

      return { ...client, is_online: isOnline }
    })

    clients.value = await Promise.all(checkPromises)
  } catch (error) {
    console.error('Failed to get paired clients:', error)
  } finally {
    loading.value = false
  }
}

async function forgetDevice(client: ClientInfo) {
  const confirmed = window.confirm(
    `确认忘记设备“${client.client_name}”吗？忘记后该设备需要重新发起配对。`,
  )

  if (!confirmed) {
    return
  }

  if (!isTauri()) {
    clients.value = clients.value.filter((item) => item.client_id !== client.client_id)
    return
  }

  try {
    if (client.is_connected && client.last_ip) {
      await invoke('notify_mobile_disconnect', { ip: client.last_ip }).catch(() => undefined)
    }

    await invoke('remove_paired_client', { clientId: client.client_id })
    await fetchClients()
  } catch (error) {
    console.error('Failed to remove client:', error)
  }
}

function formatLastSeen(timestamp: number) {
  if (!timestamp) {
    return '暂无记录'
  }

  return new Intl.DateTimeFormat('zh-CN', {
    hour: '2-digit',
    minute: '2-digit',
    month: 'short',
    day: 'numeric',
  }).format(timestamp)
}

onMounted(async () => {
  await fetchClients()

  if (!isTauri()) {
    return
  }

  unlistenConnected = await listen<{ client_id: string; client_name: string }>(
    'device_connected',
    (event) => {
      const target = clients.value.find((client) => client.client_id === event.payload.client_id)

      if (target) {
        target.is_connected = true
        target.is_online = true
      }
    },
  )

  unlistenDisconnected = await listen<{ client_id: string; client_name: string }>(
    'device_disconnected',
    (event) => {
      const target = clients.value.find((client) => client.client_id === event.payload.client_id)

      if (target) {
        target.is_connected = false
      }
    },
  )
})

onUnmounted(() => {
  unlistenConnected?.()
  unlistenDisconnected?.()
})
</script>

<template>
  <section class="mx-auto flex w-full max-w-[1320px] flex-col gap-6">
    <section class="apple-section rounded-[2.5rem] px-8 py-10 lg:px-12">
      <div class="flex flex-col gap-8 lg:flex-row lg:items-end lg:justify-between">
        <div class="max-w-3xl space-y-4">
          <Badge variant="outline" class="w-fit rounded-full">设备管理</Badge>
          <h2 class="font-[var(--font-display)] text-4xl font-semibold leading-[1.08] tracking-[-0.04em] lg:text-5xl">
            哪些设备已受信、哪些设备在线、哪些设备正在占用控制权，一眼看清。
          </h2>
          <p class="text-base leading-7 text-muted-foreground">
            这一页不再追求“管理后台”的堆砌感，而是像产品页一样，把最关键的状态压缩成更高密度的信息卡片。
          </p>
        </div>

        <Button variant="outline" class="w-fit rounded-full" @click="fetchClients">
          <RefreshCw class="size-4" />
          重新检测
        </Button>
      </div>
    </section>

    <div class="grid gap-6 xl:grid-cols-[minmax(0,1.35fr)_340px]">
      <Card class="apple-section">
        <CardHeader class="gap-3">
          <div class="flex flex-wrap items-center gap-3">
            <Badge class="rounded-full">{{ clients.length }} 台受信设备</Badge>
            <Badge variant="secondary" class="rounded-full">{{ onlineCount }} 台在线</Badge>
            <Badge variant="outline" class="rounded-full">{{ connectedCount }} 台已连接</Badge>
          </div>
          <div class="space-y-2">
            <CardTitle class="font-[var(--font-display)] text-3xl tracking-[-0.03em]">
              设备列表
            </CardTitle>
            <CardDescription>
              每张卡片只保留设备身份、网络状态与最近活跃时间。
            </CardDescription>
          </div>
        </CardHeader>

        <CardContent class="grid gap-4">
          <div
            v-if="loading"
            class="rounded-[1.5rem] border border-dashed border-border/80 bg-muted/50 px-6 py-14 text-center text-sm text-muted-foreground"
          >
            正在刷新设备在线状态，请稍候。
          </div>

          <article
            v-for="client in clients"
            v-else
            :key="client.client_id"
            class="rounded-[1.75rem] border border-border/70 bg-background/70 p-5"
          >
            <div class="flex flex-col gap-5 lg:flex-row lg:items-start lg:justify-between">
              <div class="flex items-start gap-4">
                <div
                  class="flex size-12 items-center justify-center rounded-full border border-border/70 bg-accent/60"
                >
                  <Smartphone class="size-5 text-primary" />
                </div>

                <div class="space-y-3">
                  <div class="space-y-1">
                    <div class="flex flex-wrap items-center gap-2">
                      <h3 class="text-lg font-semibold tracking-[-0.02em] text-foreground">
                        {{ client.client_name }}
                      </h3>
                      <Badge v-if="client.is_connected" class="rounded-full">已连接</Badge>
                      <Badge v-else-if="client.is_online" variant="secondary" class="rounded-full">
                        在线
                      </Badge>
                      <Badge v-else variant="outline" class="rounded-full">离线</Badge>
                    </div>
                    <p class="text-sm text-muted-foreground">
                      设备 ID：{{ client.client_id }}
                    </p>
                  </div>

                  <div class="grid gap-2 text-sm text-muted-foreground md:grid-cols-2">
                    <p>最近活跃：{{ formatLastSeen(client.last_seen_at) }}</p>
                    <p>最近 IP：{{ client.last_ip || '未知' }}</p>
                  </div>
                </div>
              </div>

              <div class="flex shrink-0 items-center gap-2">
                <Button
                  variant="outline"
                  class="rounded-full"
                  size="sm"
                  @click="forgetDevice(client)"
                >
                  <Unplug class="size-4" />
                  忘记设备
                </Button>
              </div>
            </div>
          </article>

          <div
            v-if="!loading && clients.length === 0"
            class="rounded-[1.5rem] border border-dashed border-border/80 bg-muted/50 px-6 py-14 text-center text-sm text-muted-foreground"
          >
            当前还没有受信任的移动端设备，可以先从手机端发起配对。
          </div>
        </CardContent>
      </Card>

      <div class="flex flex-col gap-6">
        <Card class="apple-section apple-inverse border-0">
          <CardHeader class="gap-3">
            <Badge class="w-fit rounded-full border-white/15 bg-white/10 text-white">同步关系</Badge>
            <CardTitle class="font-[var(--font-display)] text-2xl tracking-[-0.03em] text-white">
              当前连接并不等于永久受信。
            </CardTitle>
            <CardDescription class="text-white/70">
              “在线”表示网络层可达，“已连接”表示当前会话正在使用控制能力。
            </CardDescription>
          </CardHeader>
          <CardContent class="space-y-4 text-sm leading-6 text-white/74">
            <div class="flex items-start gap-3">
              <Link2 class="mt-0.5 size-4 text-white/80" />
              <p>受信关系长期保存，连接关系按当前会话实时变化。</p>
            </div>
            <div class="flex items-start gap-3">
              <ArrowUpRight class="mt-0.5 size-4 text-white/80" />
              <p>忘记设备时会先尝试通知移动端断开，然后再删除配对记录。</p>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  </section>
</template>
