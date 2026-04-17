<script setup lang="ts">
import { useRoute } from 'vue-router'
import { computed, ref, onMounted } from 'vue'

const route = useRoute()
const pageTitle = computed(() => route.meta.title || 'LanCtrl')

const isDark = ref(false)

const toggleTheme = () => {
  isDark.value = !isDark.value
  document.documentElement.setAttribute('data-theme', isDark.value ? 'dark' : 'light')
}

onMounted(() => {
  // 读取当前设置的系统级别状态，如果没通过 JS 操作过默认读取 false (light)
  const theme = document.documentElement.getAttribute('data-theme')
  isDark.value = theme === 'dark'
})
</script>

<template>
  <header class="top-bar glass-panel fade-in" style="animation-delay: 0.1s;">
    <div class="breadcrumb">
      <span>LanCtrl</span>
      <span class="separator">/</span>
      <span class="current">{{ pageTitle }}</span>
    </div>
    <div class="user-actions">
      <button class="icon-btn theme-toggle" @click="toggleTheme" :title="isDark ? '切换到浅色模式' : '切换到深色模式'">
        {{ isDark ? '🌙' : '🌞' }}
      </button>
    </div>
  </header>
</template>

<style scoped lang="scss">
.top-bar {
  height: 64px;
  border-radius: var(--radius-lg);
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 1.5rem;

  .breadcrumb {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-weight: 500;
    color: var(--text-muted);

    .current {
      color: var(--text-main);
    }

    .separator {
      opacity: 0.5;
    }
  }

  .user-actions {
    .icon-btn {
      background: transparent;
      border: none;
      color: var(--text-main);
      font-size: 1.25rem;
      cursor: pointer;
      width: 40px;
      height: 40px;
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      transition: background var(--transition-fast);

      &:hover {
        background: color-mix(in srgb, var(--color-white) 10%, transparent);
      }
    }
  }
}
</style>
