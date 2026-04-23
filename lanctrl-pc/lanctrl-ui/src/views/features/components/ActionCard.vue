<script setup lang="ts">
import { computed, ref } from 'vue'
import { mdiLoading, mdiPlay, mdiStop } from '@mdi/js'
import { Badge } from '../../../components/ui/badge/index'
import { Button } from '../../../components/ui/button/index'
import MorphIcon from '../../../components/common/MorphIcon.vue'
import type { ActionFeatureDefinition } from '../types'

interface Props {
  feature: ActionFeatureDefinition
  pending: boolean
  stopping?: boolean
}

interface Emits {
  execute: [feature: ActionFeatureDefinition]
  cancel: [feature: ActionFeatureDefinition]
}

const { feature, pending, stopping = false } = defineProps<Props>()
const emit = defineEmits<Emits>()

const isHovered = ref(false)

const iconPaths = [mdiPlay, mdiLoading, mdiStop]

const iconIndex = computed(() => {
  if (stopping) return 1
  if (!pending) return 0
  return isHovered.value ? 2 : 1
})

const buttonText = computed(() => {
  if (stopping) return '正在终止…'
  if (!pending) return feature.control.buttonText
  return isHovered.value ? '终止执行' : '执行中…'
})

const badgeVariant = computed(() => (feature.control.tone === 'danger' ? 'destructive' : 'secondary'))
const buttonVariant = computed(() =>
  pending || stopping ? 'secondary' : feature.control.tone === 'danger' ? 'destructive' : 'default',
)

function handleClick() {
  if (stopping) {
    return
  }

  if (pending) {
    emit('cancel', feature)
    return
  }

  emit('execute', feature)
}
</script>

<template>
  <article class="rounded-[1.75rem] border border-border/70 bg-background/70 p-6">
    <div class="flex h-full flex-col gap-6">
      <div class="space-y-4">
        <div class="flex items-start justify-between gap-3">
          <Badge :variant="badgeVariant" class="rounded-full">
            {{ feature.control.tone === 'danger' ? '高风险动作' : '即时动作' }}
          </Badge>
          <Badge v-if="feature.mobileReady" variant="outline" class="rounded-full">移动端可复用</Badge>
        </div>

        <div class="space-y-2">
          <h3 class="text-2xl font-semibold tracking-[-0.03em] text-foreground">
            {{ feature.title }}
          </h3>
          <p class="text-sm leading-6 text-muted-foreground">{{ feature.description }}</p>
        </div>
      </div>

      <div class="mt-auto flex items-center justify-between gap-4">
        <p class="text-xs uppercase tracking-[0.16em] text-muted-foreground">
          {{ pending ? 'Action in progress' : 'Ready to execute' }}
        </p>

        <Button
          :variant="buttonVariant"
          class="min-w-[164px] rounded-full"
          :class="{
            'feature-action-button': true,
            'is-pending': pending,
          }"
          :disabled="stopping"
          @click="handleClick"
          @mouseenter="isHovered = true"
          @mouseleave="isHovered = false"
        >
          <MorphIcon
            :paths="iconPaths"
            :active-index="iconIndex"
            size="1.1rem"
            class="feature-action-icon"
            :class="{ 'animate-spin': iconIndex === 1 }"
          />
          <span>{{ buttonText }}</span>
        </Button>
      </div>
    </div>
  </article>
</template>

<style scoped>
.feature-action-button.is-pending {
  background: color-mix(in oklab, var(--primary) 18%, var(--secondary));
  color: var(--foreground);
}

.feature-action-icon {
  display: inline-flex;
}
</style>
