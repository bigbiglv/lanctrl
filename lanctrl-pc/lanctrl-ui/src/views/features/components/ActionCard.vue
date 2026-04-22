<script setup lang="ts">
import { computed, ref } from 'vue'
import { mdiLoading, mdiPlay, mdiStop } from '@mdi/js'
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

const toneClass = computed(() => (feature.control.tone === 'danger' ? 'danger' : 'primary'))

/**
 * 状态定义:
 * 0: 等待执行 (Play)
 * 1: 执行中 / 终止中 (Loading/Spinner)
 * 2: 终止执行 (Stop)
 */
const iconIndex = computed(() => {
  if (stopping) return 1
  if (!pending) return 0
  return isHovered.value ? 2 : 1
})

const buttonText = computed(() => {
  if (stopping) return '终止中...'
  if (!pending) return feature.control.buttonText
  return isHovered.value ? '终止执行' : '执行中...'
})

// SVG paths from @mdi/js
const iconPaths = [
  mdiPlay, // Play
  mdiLoading, // Loading
  mdiStop, // Stop
]

const handleClick = () => {
  if (stopping) return
  if (pending) {
    emit('cancel', feature)
  } else {
    emit('execute', feature)
  }
}
</script>

<template>
  <article class="feature-card glass-panel">
    <div class="card-header">
      <div>
        <h3>{{ feature.title }}</h3>
        <p>{{ feature.description }}</p>
      </div>
    </div>

    <div class="card-footer">
      <button
        class="action-button"
        :class="[toneClass, { 'is-pending': pending, 'is-stopping': stopping }]"
        :disabled="stopping"
        @click="handleClick"
        @mouseenter="isHovered = true"
        @mouseleave="isHovered = false"
      >
        <MorphIcon
          :paths="iconPaths"
          :active-index="iconIndex"
          size="1.2rem"
          class="button-icon"
          :class="{ 'spin-animation': iconIndex === 1 }"
        />
        <span>{{ buttonText }}</span>
      </button>
    </div>
  </article>
</template>

<style scoped lang="scss">
.feature-card {
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  gap: 1.5rem;
  padding: 1.5rem;
  min-height: 220px;
  border: 1px solid var(--border-color);
}

.card-header {
  display: flex;
  justify-content: space-between;
  gap: 1rem;

  h3 {
    font-size: 1.25rem;
    margin-bottom: 0.5rem;
    color: var(--text-main);
  }

  p {
    color: var(--text-muted);
    line-height: 1.6;
  }
}

.card-footer {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 1rem;
}

.action-button {
  min-width: 140px;
  border: none;
  border-radius: var(--radius-md);
  padding: 0.8rem 1.2rem;
  color: var(--color-white);
  font-weight: 700;
  cursor: pointer;
  transition: all var(--transition-fast);
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.6rem;

  .button-icon {
    &.spin-animation {
      animation: spin 2s linear infinite;
    }
  }

  &.primary {
    background: var(--color-action-idle);
  }

  &.danger {
    background: var(--color-action-terminate);
  }

  &.is-pending {
    background: linear-gradient(
      270deg,
      var(--color-action-running-1),
      var(--color-action-running-2),
      var(--color-action-running-1)
    );
    background-size: 200% 100%;
    animation: gradient-shift 3s ease infinite;

    &:not(:hover) {
      opacity: 0.9;
      cursor: wait;
    }

    &:hover {
      background: var(--color-action-terminate);
      background-size: 100% 100%;
      animation: none;
    }
  }

  &.is-stopping {
    cursor: wait;
    background: linear-gradient(
      270deg,
      var(--color-action-stopping-1),
      var(--color-action-stopping-2),
      var(--color-action-stopping-1)
    );
    background-size: 200% 100%;
    animation: gradient-shift 2s linear infinite;
  }

  &:hover:not(.is-pending):not(.is-stopping) {
    transform: translateY(-1px);
    box-shadow: 0 8px 20px color-mix(in srgb, var(--color-black) 12%, transparent);
    filter: brightness(1.1);
  }
}

@keyframes spin {
  from {
    transform: rotate(0deg);
  }
  to {
    transform: rotate(360deg);
  }
}

@keyframes gradient-shift {
  0% {
    background-position: 0% 50%;
  }
  50% {
    background-position: 100% 50%;
  }
  100% {
    background-position: 0% 50%;
  }
}
</style>

