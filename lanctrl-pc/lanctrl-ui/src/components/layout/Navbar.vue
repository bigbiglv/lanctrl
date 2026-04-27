<script setup lang="ts">
import { mdiMoonWaningCrescent, mdiWeatherSunny } from '@mdi/js'
import { Clock3, House, PanelsTopLeft, Settings, Smartphone, Sparkles } from 'lucide-vue-next'
import { computed, ref, type ComponentPublicInstance } from 'vue'
import { useRoute } from 'vue-router'
import MorphIcon from '../common/MorphIcon.vue'
import { Button } from '../ui/button/index'
import SettingsOverlay from '../settings/SettingsOverlay.vue'
import { useTheme } from '@/lib/theme.ts'

defineOptions({ name: 'Navbar' })

const route = useRoute()
const { mode, toggleThemeMode } = useTheme()
const settingsButtonRef = ref<HTMLElement | ComponentPublicInstance | null>(null)
const settingsVisible = ref(false)
const settingsSourceRect = ref<DOMRect | null>(null)

const navigationItems = [
  { path: '/', label: '控制台', icon: House },
  { path: '/pending-tasks', label: '任务', icon: Clock3 },
  { path: '/task-history', label: '任务记录', icon: PanelsTopLeft },
  { path: '/connected-devices', label: '设备', icon: Smartphone },
  { path: '/features', label: '功能', icon: Sparkles },
] as const

const themeIconPaths = [mdiMoonWaningCrescent, mdiWeatherSunny]
const themeIconIndex = computed(() => (mode.value === 'dark' ? 1 : 0))

function isNavigationItemActive(path: string) {
  return route.path === path
}

function resolveElement(target: HTMLElement | ComponentPublicInstance | null) {
  if (target instanceof HTMLElement) {
    return target
  }

  return target?.$el instanceof HTMLElement ? target.$el : null
}

function openSettings() {
  const buttonElement = resolveElement(settingsButtonRef.value)
  settingsSourceRect.value = buttonElement?.getBoundingClientRect() ?? null
  settingsVisible.value = true
}

function handleSettingsClosed() {
  settingsVisible.value = false
}
</script>

<template>
  <header class="sticky top-6 z-20">
    <div class="flex items-center justify-between gap-3 md:gap-6 border border-(--app-nav-border) rounded-3xl md:rounded-4xl bg-(--app-nav) backdrop-saturate-[1.8] backdrop-blur-[20px] shadow-[var(--app-shadow)] p-3 md:py-4 md:px-5">
      <nav class="flex items-center justify-end md:justify-center gap-1 md:gap-2 min-w-0 flex-nowrap overflow-hidden">
        <router-link
          v-for="item in navigationItems"
          :key="item.path"
          :to="item.path"
          class="inline-flex items-center justify-center md:justify-start gap-2 h-10 w-10 md:w-auto md:h-auto md:px-3 lg:px-[0.95rem] md:py-[0.7rem] rounded-full text-[0.92rem] whitespace-nowrap transition-all duration-150"
          :class="isNavigationItemActive(item.path)
            ? 'bg-[color-mix(in_oklab,var(--primary)_16%,transparent)] text-(--app-nav-foreground)'
            : 'text-(--app-nav-muted) hover:bg-[color-mix(in_oklab,var(--primary)_10%,transparent)] hover:text-(--app-nav-foreground) hover:-translate-y-px'"
        >
          <component :is="item.icon" class="w-[0.95rem] h-[0.95rem]" />
          <span class="hidden md:inline">{{ item.label }}</span>
        </router-link>
      </nav>

      <div class="flex items-center justify-end gap-3 min-w-0">
        <Button
          ref="settingsButtonRef"
          variant="outline"
          size="icon"
          class="rounded-full bg-[color-mix(in_oklab,var(--card)_88%,transparent)] transition-all duration-200 hover:border-[color-mix(in_oklab,var(--primary)_42%,var(--app-nav-border))] hover:bg-[color-mix(in_oklab,var(--primary)_11%,var(--card))] hover:shadow-[0_10px_24px_rgba(15,23,42,0.12)] hover:text-[var(--app-nav-foreground)] hover:-translate-y-[1px] hover:scale-[1.04] active:translate-y-0 active:scale-[0.92] [&_svg]:transition-transform [&_svg]:duration-200 hover:[&_svg]:rotate-[24deg]"
          aria-label="打开设置"
          @click="openSettings"
        >
          <Settings class="size-4" />
        </Button>

        <Button
          variant="outline"
          size="icon"
          class="rounded-full bg-[color-mix(in_oklab,var(--card)_88%,transparent)] transition-all duration-200 hover:border-[color-mix(in_oklab,var(--primary)_42%,var(--app-nav-border))] hover:bg-[color-mix(in_oklab,var(--primary)_11%,var(--card))] hover:shadow-[0_10px_24px_rgba(15,23,42,0.12)] hover:text-[var(--app-nav-foreground)] hover:-translate-y-[1px] hover:scale-[1.04] active:translate-y-0 active:scale-[0.92]"
          aria-label="切换深色模式"
          @click="toggleThemeMode"
        >
          <MorphIcon :paths="themeIconPaths" :active-index="themeIconIndex" size="1rem" />
        </Button>
      </div>
    </div>

    <SettingsOverlay
      v-if="settingsVisible"
      :source-rect="settingsSourceRect"
      @closed="handleSettingsClosed"
    />
  </header>
</template>
