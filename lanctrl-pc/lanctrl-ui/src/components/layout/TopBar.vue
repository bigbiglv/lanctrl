<script setup lang="ts">
import { mdiMoonWaningCrescent, mdiWeatherSunny } from '@mdi/js'
import { Clock3, House, PanelsTopLeft, Settings, Smartphone, Sparkles } from 'lucide-vue-next'
import { computed, ref, type ComponentPublicInstance } from 'vue'
import { useRoute } from 'vue-router'
import MorphIcon from '../common/MorphIcon.vue'
import { Button } from '../ui/button/index'
import SettingsOverlay from '../settings/SettingsOverlay.vue'
import { useTheme } from '../../composables/use-theme'

const route = useRoute()
const { mode, toggleThemeMode } = useTheme()
const settingsButtonRef = ref<HTMLElement | ComponentPublicInstance | null>(null)
const settingsVisible = ref(false)
const settingsSourceRect = ref<DOMRect | null>(null)

const navigationItems = [
  { path: '/', label: '控制台', icon: House },
  { path: '/pending-tasks', label: '待处理任务', icon: Clock3 },
  { path: '/task-history', label: '任务记录', icon: PanelsTopLeft },
  { path: '/connected-devices', label: '设备管理', icon: Smartphone },
  { path: '/features', label: '功能中心', icon: Sparkles },
] as const

const currentTitle = computed(() => String(route.meta.title ?? 'LanCtrl'))
const currentDescription = computed(() =>
  String(route.meta.description ?? '集中查看设备状态、控制能力与常用操作。'),
)

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
  <header class="nav-shell">
    <div class="nav-inner">
      <div class="brand-block">
        <router-link to="/" class="brand-mark">
          <span class="brand-grid"></span>
          <span class="brand-wordmark">LanCtrl</span>
        </router-link>

        <div class="brand-copy">
          <p class="brand-kicker">Desktop Control Suite</p>
          <h1>{{ currentTitle }}</h1>
          <p>{{ currentDescription }}</p>
        </div>
      </div>

      <nav class="nav-links">
        <router-link
          v-for="item in navigationItems"
          :key="item.path"
          :to="item.path"
          class="nav-link"
          :class="{ 'is-active': isNavigationItemActive(item.path) }"
        >
          <component :is="item.icon" class="nav-link-icon" />
          <span>{{ item.label }}</span>
        </router-link>
      </nav>

      <div class="nav-actions">
        <Button
          ref="settingsButtonRef"
          variant="outline"
          size="icon"
          class="nav-icon-button settings-button"
          aria-label="打开设置"
          @click="openSettings"
        >
          <Settings class="size-4" />
        </Button>

        <Button
          variant="outline"
          size="icon"
          class="nav-icon-button theme-button"
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

<style scoped>
.nav-shell {
  position: sticky;
  top: 0;
  z-index: 20;
  padding: 1.5rem 2rem 0;
}

.nav-inner {
  display: grid;
  grid-template-columns: minmax(260px, 1.15fr) minmax(0, 1.4fr) auto;
  align-items: center;
  gap: 1.5rem;
  border: 1px solid var(--app-nav-border);
  border-radius: 2rem;
  background: var(--app-nav);
  backdrop-filter: saturate(180%) blur(20px);
  -webkit-backdrop-filter: saturate(180%) blur(20px);
  box-shadow: var(--app-shadow);
  padding: 1rem 1.25rem;
}

.brand-block {
  display: flex;
  align-items: center;
  gap: 1rem;
  min-width: 0;
}

.brand-mark {
  display: inline-flex;
  align-items: center;
  gap: 0.75rem;
  min-width: fit-content;
}

.brand-grid {
  position: relative;
  display: inline-flex;
  width: 2.75rem;
  height: 2.75rem;
  border-radius: 999px;
  background: color-mix(in oklab, var(--primary) 82%, var(--background));
  box-shadow: inset 0 0 0 1px color-mix(in oklab, var(--primary) 44%, var(--background));
}

.brand-grid::before,
.brand-grid::after {
  content: '';
  position: absolute;
  inset: 0.6rem;
  border-radius: 999px;
  border: 1px solid rgba(255, 255, 255, 0.55);
}

.brand-grid::after {
  inset: 1.05rem;
}

.brand-wordmark {
  font-family: var(--font-display);
  font-size: 1.05rem;
  font-weight: 600;
  letter-spacing: -0.02em;
}

.brand-copy {
  min-width: 0;
}

.brand-kicker {
  color: var(--app-nav-muted);
  font-size: 0.7rem;
  letter-spacing: 0.18em;
  text-transform: uppercase;
}

.brand-copy h1 {
  font-family: var(--font-display);
  font-size: 1rem;
  font-weight: 600;
  letter-spacing: -0.02em;
}

.brand-copy p {
  color: var(--app-nav-muted);
  font-size: 0.82rem;
  line-height: 1.5;
  max-width: 34rem;
}

.nav-links {
  display: flex;
  justify-content: center;
  gap: 0.5rem;
  min-width: 0;
  flex-wrap: nowrap;
  overflow: hidden;
}

.nav-link {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.7rem 0.95rem;
  border-radius: 999px;
  color: var(--app-nav-muted);
  font-size: 0.92rem;
  white-space: nowrap;
  transition:
    background-color 160ms ease,
    color 160ms ease,
    transform 160ms ease;
}

.nav-link:hover {
  background: color-mix(in oklab, var(--primary) 10%, transparent);
  color: var(--app-nav-foreground);
  transform: translateY(-1px);
}

.nav-link.is-active {
  background: color-mix(in oklab, var(--primary) 16%, transparent);
  color: var(--app-nav-foreground);
}

.nav-link-icon {
  width: 0.95rem;
  height: 0.95rem;
}

.nav-actions {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 0.75rem;
  min-width: 0;
}

.status-badge {
  border-radius: 999px;
  padding-inline: 0.9rem;
  color: var(--app-nav-foreground);
  background: color-mix(in oklab, var(--card) 86%, transparent);
}

.status-dot {
  display: inline-flex;
  width: 0.45rem;
  height: 0.45rem;
  margin-inline: 0.25rem 0.1rem;
  border-radius: 999px;
  background: var(--app-success);
}

.nav-icon-button {
  border-radius: 999px;
  background: color-mix(in oklab, var(--card) 88%, transparent);
  transition:
    background-color 180ms ease,
    border-color 180ms ease,
    box-shadow 180ms ease,
    color 180ms ease,
    transform 180ms ease;
}

.nav-icon-button:hover {
  border-color: color-mix(in oklab, var(--primary) 42%, var(--app-nav-border));
  background: color-mix(in oklab, var(--primary) 11%, var(--card));
  box-shadow: 0 10px 24px rgba(15, 23, 42, 0.12);
  color: var(--app-nav-foreground);
  transform: translateY(-1px) scale(1.04);
}

.nav-icon-button:active {
  transform: translateY(0) scale(0.92);
}

.settings-button :deep(svg) {
  transition: transform 220ms ease;
}

.settings-button:hover :deep(svg) {
  transform: rotate(24deg);
}

@media (max-width: 1280px) {
  .nav-inner {
    grid-template-columns: minmax(180px, auto) minmax(0, 1fr) auto;
    gap: 0.9rem;
  }
}

@media (max-width: 1080px) {
  .brand-copy {
    display: none;
  }

  .nav-link {
    padding-inline: 0.75rem;
  }
}

@media (max-width: 920px) {
  .nav-inner {
    grid-template-columns: auto minmax(0, 1fr) auto;
  }

  .status-badge {
    display: none;
  }
}

@media (max-width: 720px) {
  .nav-shell {
    padding: 1rem 1rem 0;
  }

  .nav-inner {
    border-radius: 1.5rem;
    padding: 0.75rem;
  }

  .nav-links {
    justify-content: flex-end;
    gap: 0.25rem;
  }

  .nav-link {
    justify-content: center;
    width: 2.5rem;
    height: 2.5rem;
    padding: 0;
  }

  .nav-link span {
    display: none;
  }
}

@media (max-width: 520px) {
  .brand-wordmark {
    display: none;
  }
}
</style>
