<script setup lang="ts">
import { Music, Pause, Play, RefreshCw, SkipBack, SkipForward } from 'lucide-vue-next'
import { Button } from '../../../components/ui/button/index'
import type { MediaPlayerAction, MediaPlayerFeatureDefinition } from '../types'

interface Props {
  feature: MediaPlayerFeatureDefinition
  pendingKey: string | null
  refreshing: boolean
}

interface Emits {
  execute: [feature: MediaPlayerFeatureDefinition, action: MediaPlayerAction]
  refresh: []
}

const { feature, pendingKey, refreshing } = defineProps<Props>()
const emit = defineEmits<Emits>()

function iconName(featureKey: string, label: string) {
  if (featureKey.endsWith('_previous')) return SkipBack
  if (featureKey.endsWith('_next')) return SkipForward
  if (featureKey.endsWith('_play_pause') && label === '播放') return Play
  if (featureKey.endsWith('_play_pause')) return Pause
  return Play
}
</script>

<template>
  <article class="rounded-[1.75rem] border border-border/70 bg-background/70 p-6 md:col-span-2">
    <div class="flex flex-col gap-5">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <div class="flex items-center gap-3">
          <div class="flex size-11 items-center justify-center rounded-full bg-primary text-primary-foreground">
            <Music class="size-5" />
          </div>
          <h3 class="text-xl font-semibold text-foreground">
            {{ feature.title }}
          </h3>
        </div>

        <Button
          variant="outline"
          size="icon"
          class="rounded-full"
          :disabled="refreshing"
          @click="emit('refresh')"
        >
          <RefreshCw class="size-4" :class="{ 'animate-spin': refreshing }" />
        </Button>
      </div>

      <div class="grid grid-cols-3 gap-3">
        <Button
          v-for="action in feature.control.actions"
          :key="action.featureKey"
          variant="outline"
          class="h-12 rounded-full"
          :disabled="pendingKey === action.featureKey"
          @click="emit('execute', feature, action)"
        >
          <component :is="iconName(action.featureKey, action.label)" class="size-4" />
          <span>{{ pendingKey === action.featureKey ? '执行中' : action.label }}</span>
        </Button>
      </div>
    </div>
  </article>
</template>
