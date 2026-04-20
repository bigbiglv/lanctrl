<script setup lang="ts">
import { computed } from 'vue'
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
  <article class="feature-card glass-panel">
    <div class="card-header">
      <div>
        <h3>{{ feature.title }}</h3>
        <p>{{ feature.description }}</p>
      </div>
    </div>

    <div class="range-body">
      <div class="range-value">{{ displayValue }}</div>
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
      <div class="range-meta">
        <span>{{ feature.control.min }}{{ feature.control.unit }}</span>
        <span>{{ feature.control.max }}{{ feature.control.unit }}</span>
      </div>
    </div>

    <div class="card-footer">
      <button class="ghost-button" :disabled="refreshing || pending" @click="emit('refresh')">
        {{ refreshing ? '同步中...' : '同步当前音量' }}
      </button>
      <button class="action-button" :disabled="pending" @click="emit('apply', feature)">
        {{ pending ? '应用中...' : feature.control.actionText }}
      </button>
    </div>
  </article>
</template>

<style scoped lang="scss">
.feature-card {
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
  padding: 1.5rem;
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

.capability-tag {
  flex-shrink: 0;
  align-self: flex-start;
  padding: 0.35rem 0.75rem;
  border-radius: var(--radius-pill);
  background: color-mix(in srgb, var(--color-info) 14%, transparent);
  color: var(--color-info);
  font-size: 0.8rem;
  font-weight: 600;
}

.range-body {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.range-value {
  font-size: 2.5rem;
  font-weight: 800;
  color: var(--text-main);
}

.range-input {
  width: 100%;
  accent-color: var(--color-primary);
}

.range-meta {
  display: flex;
  justify-content: space-between;
  color: var(--text-muted);
  font-size: 0.9rem;
}

.card-footer {
  display: flex;
  justify-content: flex-end;
  gap: 0.75rem;
}

.ghost-button,
.action-button {
  border-radius: var(--radius-md);
  padding: 0.8rem 1rem;
  font-weight: 700;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.ghost-button {
  border: 1px solid var(--border-color);
  background: transparent;
  color: var(--text-main);
}

.action-button {
  border: none;
  background: linear-gradient(135deg, var(--color-primary), var(--color-primary-dark));
  color: var(--color-white);
}

.ghost-button:disabled,
.action-button:disabled {
  cursor: wait;
  opacity: 0.7;
}
</style>
