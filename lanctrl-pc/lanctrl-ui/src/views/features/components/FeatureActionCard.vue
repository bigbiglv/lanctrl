<script setup lang="ts">
import type { ActionFeatureDefinition } from '../types'

const props = defineProps<{
  feature: ActionFeatureDefinition
  pending: boolean
}>()

const emit = defineEmits<{
  execute: [feature: ActionFeatureDefinition]
}>()

const toneClass = props.feature.control.tone === 'danger' ? 'danger' : 'primary'
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
        :class="toneClass"
        :disabled="pending"
        @click="emit('execute', feature)"
      >
        {{ pending ? '执行中...' : feature.control.buttonText }}
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

.card-footer {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
}

.hint {
  color: var(--text-muted);
  font-size: 0.9rem;
}

.action-button {
  min-width: 132px;
  border: none;
  border-radius: var(--radius-md);
  padding: 0.8rem 1.1rem;
  color: var(--color-white);
  font-weight: 700;
  cursor: pointer;
  transition: all var(--transition-fast);

  &:disabled {
    cursor: wait;
    opacity: 0.7;
  }

  &.primary {
    background: linear-gradient(135deg, var(--color-primary), var(--color-primary-dark));
  }

  &.danger {
    background: linear-gradient(
      135deg,
      var(--color-danger),
      color-mix(in srgb, var(--color-danger) 70%, var(--color-black))
    );
  }

  &:hover:not(:disabled) {
    transform: translateY(-1px);
    box-shadow: 0 8px 20px color-mix(in srgb, var(--color-black) 12%, transparent);
  }
}
</style>
