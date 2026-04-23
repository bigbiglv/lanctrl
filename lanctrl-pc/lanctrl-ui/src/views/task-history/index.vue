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
  { title: '音量调整', result: '已完成', detail: '桌面端触发，将系统音量同步到 38%' },
  { title: '设备移除', result: '已确认', detail: '受信设备被手动移除，并通知移动端断开连接' },
  { title: '电源控制', result: '已拒绝', detail: '用户取消了本次敏感动作，不写入执行层' },
]
</script>

<template>
  <section class="mx-auto flex w-full max-w-[1240px] flex-col gap-6">
    <section class="apple-section rounded-[2.5rem] px-8 py-10 lg:px-12">
      <Badge variant="outline" class="w-fit rounded-full">历史追踪</Badge>
      <div class="mt-4 max-w-3xl space-y-4">
        <h2 class="font-[var(--font-display)] text-4xl font-semibold leading-[1.08] tracking-[-0.04em] lg:text-5xl">
          任务记录页应该像一条清晰的时间线，而不是一张密密麻麻的日志表。
        </h2>
        <p class="text-base leading-7 text-muted-foreground">
          这里先放入一组演示数据，目的是把后续真正的历史流设计出来：每条记录至少包含动作、结果、来源和一句解释。
        </p>
      </div>
    </section>

    <div class="grid gap-6 lg:grid-cols-[minmax(0,1.15fr)_360px]">
      <Card class="apple-section">
        <CardHeader class="gap-2">
          <CardTitle class="font-[var(--font-display)] text-3xl tracking-[-0.03em]">
            演示时间线
          </CardTitle>
          <CardDescription>真实数据接入后，这一列直接替换为后端回执流。</CardDescription>
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
          <Badge class="w-fit rounded-full border-white/15 bg-white/10 text-white">设计提示</Badge>
          <CardTitle class="font-[var(--font-display)] text-2xl tracking-[-0.03em] text-white">
            历史记录页最重要的是“可信”。
          </CardTitle>
          <CardDescription class="text-white/70">
            记录页不是炫技场，而是操作可信度的证明材料。
          </CardDescription>
        </CardHeader>
        <CardContent class="space-y-4 text-sm leading-6 text-white/74">
          <div class="flex items-start gap-3">
            <History class="mt-0.5 size-4 text-white/80" />
            <p>每条记录都需要明确动作和结果，避免只留模糊描述。</p>
          </div>
          <div class="flex items-start gap-3">
            <ShieldCheck class="mt-0.5 size-4 text-white/80" />
            <p>敏感动作必须保留确认链路与失败原因，便于审计与回滚。</p>
          </div>
          <div class="flex items-start gap-3">
            <ArrowUpRight class="mt-0.5 size-4 text-white/80" />
            <p>如果未来增加筛选器，优先做时间、来源和结果三种过滤维度。</p>
          </div>
        </CardContent>
      </Card>
    </div>
  </section>
</template>
