<script setup lang="ts">
import {
  Clock3,
  House,
  MoonStar,
  PanelsTopLeft,
  Smartphone,
  Sparkles,
  SunMedium,
} from 'lucide-vue-next'
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import { Badge } from '../ui/badge/index'
import { Button } from '../ui/button/index'
import { useTheme } from '../../composables/use-theme'

const route = useRoute()
const { mode, themeId, toggleThemeMode } = useTheme()

const navigationItems = [
  { path: '/', label: '控制台', icon: House },
  { path: '/pending-tasks', label: '待处理任务', icon: Clock3 },
  { path: '/task-history', label: '任务记录', icon: PanelsTopLeft },
  { path: '/connected-devices', label: '设备管理', icon: Smartphone },
  { path: '/features', label: '功能中心', icon: Sparkles },
] as const

const currentTitle = computed(() => String(route.meta.title ?? 'LanCtrl'))
const currentDescription = computed(() =>
  String(
    route.meta.description ??
      '围绕局域网控制、设备联动与自动化执行，建立一套更清晰的桌面控制中枢。',
  ),
)
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
          active-class="is-active"
        >
          <component :is="item.icon" class="nav-link-icon" />
          <span>{{ item.label }}</span>
        </router-link>
      </nav>

      <div class="nav-actions">
        <Badge variant="outline" class="status-badge">
          {{ themeId === 'default' ? '默认主题' : themeId }}
          <span class="status-dot"></span>
          {{ mode === 'dark' ? '深色' : '浅色' }}
        </Badge>

        <Button variant="outline" size="icon" class="theme-button" @click="toggleThemeMode">
          <SunMedium v-if="mode === 'dark'" class="size-4" />
          <MoonStar v-else class="size-4" />
        </Button>
      </div>
    </div>
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
  background: color-mix(in oklab, var(--primary) 78%, white);
  box-shadow: inset 0 0 0 1px color-mix(in oklab, var(--primary) 36%, white);
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
  flex-wrap: wrap;
}

.nav-link {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.7rem 0.95rem;
  border-radius: 999px;
  color: var(--app-nav-muted);
  font-size: 0.92rem;
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

.theme-button {
  border-radius: 999px;
  background: color-mix(in oklab, var(--card) 88%, transparent);
}

@media (max-width: 1280px) {
  .nav-inner {
    grid-template-columns: 1fr;
    align-items: stretch;
  }

  .nav-links {
    justify-content: flex-start;
  }

  .nav-actions {
    justify-content: space-between;
  }
}

@media (max-width: 720px) {
  .nav-shell {
    padding-inline: 1rem;
  }

  .brand-block {
    flex-direction: column;
    align-items: flex-start;
  }

  .nav-links {
    gap: 0.35rem;
  }

  .nav-link {
    width: calc(50% - 0.2rem);
    justify-content: center;
  }
}
</style>
