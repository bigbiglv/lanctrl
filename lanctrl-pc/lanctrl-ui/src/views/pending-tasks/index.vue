<script setup lang="ts">
import { BellRing, Clock3, Inbox } from 'lucide-vue-next'
import { Badge } from '../../components/ui/badge/index'
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from '../../components/ui/card/index'

const placeholderSteps = [
  '等待移动端确认的远程控制请求',
  '等待本机执行完成的系统级动作',
  '等待同步状态的音量与设备扫描任务',
]
</script>

<template>
  <section class="mx-auto flex w-full max-w-[1240px] flex-col gap-6">
    <section class="apple-section apple-inverse rounded-[2.5rem] border-0 px-8 py-10 lg:px-12">
      <Badge class="w-fit rounded-full border-white/15 bg-white/10 text-white">任务视图</Badge>
      <div class="mt-4 max-w-3xl space-y-4">
        <h2 class="font-[var(--font-display)] text-4xl font-semibold leading-[1.08] tracking-[-0.04em] text-white lg:text-5xl">
          待处理任务页已经预留好了结构，现在缺的是业务数据而不是视觉骨架。
        </h2>
        <p class="text-base leading-7 text-white/70">
          我保留了接下来最可能出现的三类任务类型，后续你只需要把真实数据源接进来，这一页就能直接承接。
        </p>
      </div>
    </section>

    <div class="grid gap-6 lg:grid-cols-[minmax(0,1.1fr)_360px]">
      <Card class="apple-section">
        <CardHeader class="gap-3">
          <Badge variant="outline" class="w-fit rounded-full">空态设计</Badge>
          <CardTitle class="font-[var(--font-display)] text-3xl tracking-[-0.03em]">
            先把任务语义定义清楚。
          </CardTitle>
          <CardDescription>
            页面空态不再只是“施工中”，而是直接告诉后续开发这里会承载什么类型的任务。
          </CardDescription>
        </CardHeader>
        <CardContent class="grid gap-4">
          <article
            v-for="step in placeholderSteps"
            :key="step"
            class="rounded-[1.5rem] border border-border/70 bg-background/70 p-5"
          >
            <div class="flex items-start gap-3">
              <Inbox class="mt-0.5 size-4 text-primary" />
              <p class="text-sm leading-6 text-foreground">{{ step }}</p>
            </div>
          </article>
        </CardContent>
      </Card>

      <Card class="apple-section">
        <CardHeader class="gap-2">
          <CardTitle class="font-[var(--font-display)] text-2xl tracking-[-0.03em]">
            建议数据结构
          </CardTitle>
          <CardDescription>先把列表模型约定好，接入会更顺。</CardDescription>
        </CardHeader>
        <CardContent class="space-y-4 text-sm text-muted-foreground">
          <div class="flex items-start gap-3">
            <Clock3 class="mt-0.5 size-4 text-primary" />
            <p>任务类型、触发源、优先级、当前状态。</p>
          </div>
          <div class="flex items-start gap-3">
            <BellRing class="mt-0.5 size-4 text-primary" />
            <p>是否需要二次确认，以及超时后的兜底动作。</p>
          </div>
        </CardContent>
      </Card>
    </div>
  </section>
</template>
