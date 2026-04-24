<script setup lang="ts">
import { CheckCircle2, CircleSlash2, History, LaptopMinimal, Smartphone, TriangleAlert } from 'lucide-vue-next'
import { onMounted, onUnmounted, ref } from 'vue'
import { invoke, isTauri } from '@tauri-apps/api/core'
import { listen } from '@tauri-apps/api/event'
import type { UnlistenFn } from '@tauri-apps/api/event'
import { Badge } from '../../components/ui/badge/index'
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from '../../components/ui/card/index'

interface TaskOrigin {
  kind: 'pc' | 'mobile'
  clientId?: string | null
  clientName: string
}

interface TaskHistoryEntry {
  entryId: string
  taskId?: string | null
  title: string
  origin: TaskOrigin
  status: 'queued' | 'cancelled' | 'executed' | 'failed' | 'manual_executed' | 'manual_failed'
  recordedAtMs: number
  detail: string
}

const history = ref<TaskHistoryEntry[]>([])
const loading = ref(true)

let unlistenHistoryChanged: UnlistenFn | null = null

async function fetchHistory() {
  if (!isTauri()) {
    history.value = []
    loading.value = false
    return
  }

  try {
    loading.value = true
    history.value = await invoke<TaskHistoryEntry[]>('get_task_history_entries')
  } catch (error) {
    console.error('Failed to load task history:', error)
  } finally {
    loading.value = false
  }
}

function formatTime(timestamp: number) {
  return new Intl.DateTimeFormat('zh-CN', {
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  }).format(timestamp)
}

function sourceLabel(origin: TaskOrigin) {
  return origin.kind === 'pc' ? 'PC 本机' : origin.clientName
}

function sourceIcon(origin: TaskOrigin) {
  return origin.kind === 'pc' ? LaptopMinimal : Smartphone
}

function statusMeta(status: TaskHistoryEntry['status']) {
  switch (status) {
    case 'queued':
      return { label: '已入队', icon: History, tone: 'secondary' as const }
    case 'cancelled':
      return { label: '已取消', icon: CircleSlash2, tone: 'outline' as const }
    case 'executed':
    case 'manual_executed':
      return { label: '执行成功', icon: CheckCircle2, tone: 'default' as const }
    case 'failed':
    case 'manual_failed':
      return { label: '执行失败', icon: TriangleAlert, tone: 'destructive' as const }
  }
}

onMounted(async () => {
  await fetchHistory()

  if (!isTauri())
    return

  unlistenHistoryChanged = await listen('task_history_changed', () => void fetchHistory())
})

onUnmounted(() => {
  unlistenHistoryChanged?.()
})
</script>

<template>
  <section class="mx-auto flex w-full max-w-[1240px] flex-col gap-6">
    <section class="apple-section rounded-[2.5rem] px-8 py-10 lg:px-12">
      <Badge variant="outline" class="w-fit rounded-full">任务记录</Badge>
      <div class="mt-4 max-w-3xl space-y-4">
        <h2 class="font-[var(--font-display)] text-4xl font-semibold leading-[1.08] tracking-[-0.04em] lg:text-5xl">
          任务记录不仅保留结果，还会保留任务来源，方便区分是 PC 自己操作，还是哪台移动端发起的。
        </h2>
        <p class="text-base leading-7 text-muted-foreground">
          这里会记录入队、取消、执行成功和执行失败。即时操作也会以 PC 本机来源进入记录。
        </p>
      </div>
    </section>

    <div class="grid gap-6 lg:grid-cols-[minmax(0,1.15fr)_360px]">
      <Card class="apple-section">
        <CardHeader class="gap-2">
          <CardTitle class="font-[var(--font-display)] text-3xl tracking-[-0.03em]">
            最近记录
          </CardTitle>
          <CardDescription>每一条记录都包含来源、状态、记录时间和结果说明。</CardDescription>
        </CardHeader>
        <CardContent class="space-y-4">
          <div
            v-if="loading"
            class="rounded-[1.5rem] border border-dashed border-border/80 bg-muted/50 px-6 py-14 text-center text-sm text-muted-foreground"
          >
            正在读取任务记录…
          </div>

          <article
            v-for="item in history"
            v-else
            :key="item.entryId"
            class="rounded-[1.5rem] border border-border/70 bg-background/70 p-5"
          >
            <div class="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
              <div class="space-y-3">
                <div class="flex flex-wrap items-center gap-2">
                  <h3 class="text-lg font-semibold tracking-[-0.02em]">{{ item.title }}</h3>
                  <Badge :variant="statusMeta(item.status).tone">
                    {{ statusMeta(item.status).label }}
                  </Badge>
                </div>
                <p class="text-sm leading-6 text-muted-foreground">
                  {{ item.detail }}
                </p>
                <div class="grid gap-2 text-sm text-muted-foreground md:grid-cols-2">
                  <p>记录时间：{{ formatTime(item.recordedAtMs) }}</p>
                  <p>任务 ID：{{ item.taskId || '即时操作' }}</p>
                </div>
              </div>

              <div class="flex items-center gap-2 rounded-full border border-border/70 px-3 py-2 text-sm text-muted-foreground">
                <component :is="sourceIcon(item.origin)" class="size-4 text-primary" />
                <span>来源：{{ sourceLabel(item.origin) }}</span>
              </div>
            </div>
          </article>

          <div
            v-if="!loading && history.length === 0"
            class="rounded-[1.5rem] border border-dashed border-border/80 bg-muted/50 px-6 py-14 text-center text-sm text-muted-foreground"
          >
            还没有任何任务记录。
          </div>
        </CardContent>
      </Card>

      <Card class="apple-section apple-inverse border-0">
        <CardHeader class="gap-3">
          <Badge class="w-fit rounded-full border-white/15 bg-white/10 text-white">记录说明</Badge>
          <CardTitle class="font-[var(--font-display)] text-2xl tracking-[-0.03em] text-white">
            记录来源和结果是拆开的
          </CardTitle>
          <CardDescription class="text-white/70">
            来源看“谁发起”，状态看“后来发生了什么”，避免把创建者和执行结果混在一起。
          </CardDescription>
        </CardHeader>
        <CardContent class="space-y-4 text-sm leading-6 text-white/74">
          <div class="flex items-start gap-3">
            <Smartphone class="mt-0.5 size-4 text-white/80" />
            <p>移动端发起的任务会记录到具体设备名，便于回溯是谁下发了这条控制。</p>
          </div>
          <div class="flex items-start gap-3">
            <LaptopMinimal class="mt-0.5 size-4 text-white/80" />
            <p>PC 本机直接执行的即时操作也会进入记录，来源显示为 PC 本机。</p>
          </div>
          <div class="flex items-start gap-3">
            <TriangleAlert class="mt-0.5 size-4 text-white/80" />
            <p>执行失败会保留错误信息，后续排查不需要靠口头复现。</p>
          </div>
        </CardContent>
      </Card>
    </div>
  </section>
</template>
