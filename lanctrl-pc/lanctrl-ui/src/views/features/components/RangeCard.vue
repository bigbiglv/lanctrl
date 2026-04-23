<script setup lang="ts">
import { computed } from 'vue'
import { RefreshCw, Volume2 } from 'lucide-vue-next'
import { Badge } from '../../../components/ui/badge/index'
import { Button } from '../../../components/ui/button/index'
import type { RangeFeatureDefinition } from '../types'

interface Props {
  feature: RangeFeatureDefinition
  value: number
  pending: boolean
  refreshing: boolean
}

interface Emits {
  'update:value': [value: number]
  apply: [feature: RangeFeatureDefinition]
  refresh: []
}

const { feature, value, pending, refreshing } = defineProps<Props>()
const emit = defineEmits<Emits>()

const displayValue = computed(() => `${value}${feature.control.unit}`)
</script>

<template>
  <article class="rounded-[1.75rem] border border-border/70 bg-background/70 p-6">
    <div class="flex flex-col gap-6">
      <div class="flex flex-wrap items-start justify-between gap-3">
        <div class="space-y-2">
          <Badge variant="secondary" class="w-fit rounded-full">范围控制</Badge>
          <h3 class="text-2xl font-semibold tracking-[-0.03em] text-foreground">
            {{ feature.title }}
          </h3>
          <p class="text-sm leading-6 text-muted-foreground">{{ feature.description }}</p>
        </div>
        <div class="flex items-center gap-2 rounded-full border border-border/70 bg-muted/40 px-4 py-2">
          <Volume2 class="size-4 text-primary" />
          <span class="text-sm font-medium">{{ displayValue }}</span>
        </div>
      </div>

      <div class="space-y-4">
        <input
          class="range-input"
          type="range"
          :min="feature.control.min"
          :max="feature.control.max"
          :step="feature.control.step"
          :value="value"
          :disabled="pending"
          @input="emit('update:value', Number(($event.target as HTMLInputElement).value))"
        >
        <div class="flex justify-between text-sm text-muted-foreground">
          <span>{{ feature.control.min }}{{ feature.control.unit }}</span>
          <span>{{ feature.control.max }}{{ feature.control.unit }}</span>
        </div>
      </div>

      <div class="flex flex-wrap items-center justify-between gap-3">
        <p class="text-xs uppercase tracking-[0.16em] text-muted-foreground">
          当前滑块值会被直接发送到执行层
        </p>

        <div class="flex flex-wrap gap-3">
          <Button variant="outline" class="rounded-full" :disabled="refreshing || pending" @click="emit('refresh')">
            <RefreshCw class="size-4" :class="{ 'animate-spin': refreshing }" />
            {{ refreshing ? '同步中…' : '同步当前音量' }}
          </Button>

          <Button class="rounded-full" :disabled="pending" @click="emit('apply', feature)">
            {{ pending ? '应用中…' : feature.control.actionText }}
          </Button>
        </div>
      </div>
    </div>
  </article>
</template>

<style scoped>
.range-input {
  width: 100%;
  accent-color: currentColor;
}
</style>
