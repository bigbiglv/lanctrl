<script setup lang="ts">
import { ArrowUpRight, History, ShieldCheck } from 'lucide-vue-next'
import { Badge } from '../../components/ui/badge/index'
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from '../../components/ui/card/index'

const demoTimeline = [
  { title: '音量调整', result: '已完成', detail: '系统主音量已更新为 38%' },
  { title: '设备移除', result: '已确认', detail: '所选设备已从当前设备列表中移除' },
  { title: '重新启动', result: '已取消', detail: '本次操作未继续执行' },
]
</script>

<template>
  <section class="mx-auto flex w-full max-w-[1240px] flex-col gap-6">
    <section class="apple-section rounded-[2.5rem] px-8 py-10 lg:px-12">
      <Badge variant="outline" class="w-fit rounded-full">任务记录</Badge>
      <div class="mt-4 max-w-3xl space-y-4">
        <h2 class="font-[var(--font-display)] text-4xl font-semibold leading-[1.08] tracking-[-0.04em] lg:text-5xl">
          重要操作的结果与时间，会按顺序保留在这里。
        </h2>
        <p class="text-base leading-7 text-muted-foreground">
          通过任务记录，你可以快速回看最近的控制结果与处理状态。
        </p>
      </div>
    </section>

    <div class="grid gap-6 lg:grid-cols-[minmax(0,1.15fr)_360px]">
      <Card class="apple-section">
        <CardHeader class="gap-2">
          <CardTitle class="font-[var(--font-display)] text-3xl tracking-[-0.03em]">
            最近记录
          </CardTitle>
          <CardDescription>操作完成后，结果会出现在这里。</CardDescription>
        </CardHeader>
        <CardContent class="space-y-4">
          <article
            v-for="item in demoTimeline"
            :key="item.title"
            class="rounded-[1.5rem] border border-border/70 bg-background/70 p-5"
          >
            <div class="flex items-start justify-between gap-3">
              <div>
                <p class="text-lg font-semibold tracking-[-0.02em]">{{ item.title }}</p>
                <p class="mt-2 text-sm leading-6 text-muted-foreground">{{ item.detail }}</p>
              </div>
              <Badge variant="secondary">{{ item.result }}</Badge>
            </div>
          </article>
        </CardContent>
      </Card>

      <Card class="apple-section apple-inverse border-0">
        <CardHeader class="gap-3">
          <Badge class="w-fit rounded-full border-white/15 bg-white/10 text-white">记录说明</Badge>
          <CardTitle class="font-[var(--font-display)] text-2xl tracking-[-0.03em] text-white">
            关键结果清晰可查。
          </CardTitle>
          <CardDescription class="text-white/70">
            每条记录都会保留状态与结果，方便你快速回看。
          </CardDescription>
        </CardHeader>
        <CardContent class="space-y-4 text-sm leading-6 text-white/74">
          <div class="flex items-start gap-3">
            <History class="mt-0.5 size-4 text-white/80" />
            <p>近期操作会按时间顺序展示。</p>
          </div>
          <div class="flex items-start gap-3">
            <ShieldCheck class="mt-0.5 size-4 text-white/80" />
            <p>需要确认的操作会保留最终结果状态。</p>
          </div>
          <div class="flex items-start gap-3">
            <ArrowUpRight class="mt-0.5 size-4 text-white/80" />
            <p>常用信息会优先展示，方便快速定位。</p>
          </div>
        </CardContent>
      </Card>
    </div>
  </section>
</template>
