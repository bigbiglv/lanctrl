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
  '等待设备确认的远程控制请求',
  '等待系统完成的关键操作',
  '等待同步结果的音量与设备扫描任务',
]
</script>

<template>
  <section class="mx-auto flex w-full max-w-[1240px] flex-col gap-6">
    <section class="apple-section apple-inverse rounded-[2.5rem] border-0 px-8 py-10 lg:px-12">
      <Badge class="w-fit rounded-full border-white/15 bg-white/10 text-white">待处理任务</Badge>
      <div class="mt-4 max-w-3xl space-y-4">
        <h2 class="font-[var(--font-display)] text-4xl font-semibold leading-[1.08] tracking-[-0.04em] text-white lg:text-5xl">
          所有等待中的操作，都会集中显示在这里。
        </h2>
        <p class="text-base leading-7 text-white/70">
          当设备确认、系统执行或状态同步仍在处理中时，你可以在这里快速查看当前进度。
        </p>
      </div>
    </section>

    <div class="grid gap-6 lg:grid-cols-[minmax(0,1.1fr)_360px]">
      <Card class="apple-section">
        <CardHeader class="gap-3">
          <Badge variant="outline" class="w-fit rounded-full">当前任务</Badge>
          <CardTitle class="font-[var(--font-display)] text-3xl tracking-[-0.03em]">
            待处理内容
          </CardTitle>
          <CardDescription>
            这里会显示仍需等待结果的关键操作。
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
            状态提示
          </CardTitle>
          <CardDescription>常见等待状态会在这里集中展示。</CardDescription>
        </CardHeader>
        <CardContent class="space-y-4 text-sm text-muted-foreground">
          <div class="flex items-start gap-3">
            <Clock3 class="mt-0.5 size-4 text-primary" />
            <p>等待执行、等待确认与等待同步会分别标记。</p>
          </div>
          <div class="flex items-start gap-3">
            <BellRing class="mt-0.5 size-4 text-primary" />
            <p>需要你再次确认的操作会有更明确的提醒。</p>
          </div>
        </CardContent>
      </Card>
    </div>
  </section>
</template>
