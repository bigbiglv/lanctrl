<script setup lang="ts">
import { invoke, isTauri } from '@tauri-apps/api/core'
import { ArrowLeft, Check, Minimize2, MonitorCog, Moon, Palette, ShieldCheck, Sun } from 'lucide-vue-next'
import { gsap } from 'gsap'
import { computed, nextTick, onBeforeUnmount, onMounted, ref } from 'vue'
import { Button } from '../ui/button/index'
import { useTheme } from '../../composables/use-theme'

interface SourceRect {
  left: number
  top: number
  width: number
  height: number
}

interface CloseBehavior {
  closeToTrayOnClose: boolean
}

const props = defineProps<{
  sourceRect: SourceRect | null
}>()

const emit = defineEmits<{
  closed: []
}>()

const { mode, setThemeMode } = useTheme()

const overlayRef = ref<HTMLElement | null>(null)
const contentRef = ref<HTMLElement | null>(null)
const closing = ref(false)
const previousBodyOverflow = ref('')
const closeToTrayOnClose = ref(true)
const closeBehaviorPending = ref(false)

const modeOptions = computed(() => [
  {
    value: 'light' as const,
    label: '浅色',
    description: '适合明亮环境下的桌面控制',
    icon: Sun,
  },
  {
    value: 'dark' as const,
    label: '深色',
    description: '降低夜间操作时的屏幕亮度',
    icon: Moon,
  },
])

function getSourceRect(): SourceRect {
  if (props.sourceRect) {
    return props.sourceRect
  }

  return {
    left: window.innerWidth - 72,
    top: 32,
    width: 44,
    height: 44,
  }
}

function animateOpen() {
  const overlay = overlayRef.value
  const content = contentRef.value

  if (!overlay || !content) {
    return
  }

  const source = getSourceRect()

  gsap.set(overlay, {
    x: source.left,
    y: source.top,
    width: source.width,
    height: source.height,
    borderRadius: source.height / 2,
    opacity: 0.96,
  })

  gsap.set(content, {
    opacity: 0,
    y: 14,
    scale: 0.985,
  })

  gsap
    .timeline({ defaults: { ease: 'power3.out' } })
    .to(overlay, {
      x: 0,
      y: 0,
      width: window.innerWidth,
      height: window.innerHeight,
      borderRadius: 0,
      duration: 0.46,
      onComplete: () => {
        gsap.set(overlay, {
          width: '100vw',
          height: '100vh',
        })
      },
    })
    .to(
      content,
      {
        opacity: 1,
        y: 0,
        scale: 1,
        duration: 0.28,
      },
      '-=0.22',
    )
}

function closeSettings() {
  const overlay = overlayRef.value
  const content = contentRef.value

  if (!overlay || closing.value) {
    return
  }

  closing.value = true
  const source = getSourceRect()

  gsap
    .timeline({
      defaults: { ease: 'power3.inOut' },
      onComplete: () => emit('closed'),
    })
    .to(
      content,
      {
        opacity: 0,
        y: 10,
        scale: 0.99,
        duration: 0.16,
      },
      0,
    )
    .to(
      overlay,
      {
        x: source.left,
        y: source.top,
        width: source.width,
        height: source.height,
        borderRadius: source.height / 2,
        opacity: 0.92,
        duration: 0.38,
      },
      0.04,
    )
}

function syncOverlaySize() {
  const overlay = overlayRef.value

  if (!overlay || closing.value) {
    return
  }

  gsap.set(overlay, {
    width: '100vw',
    height: '100vh',
  })
}

function handleKeydown(event: KeyboardEvent) {
  if (event.key === 'Escape') {
    closeSettings()
  }
}

async function loadCloseBehavior() {
  if (!isTauri()) {
    return
  }

  const behavior = await invoke<CloseBehavior>('get_close_behavior')
  closeToTrayOnClose.value = behavior.closeToTrayOnClose
}

async function toggleCloseBehavior() {
  if (closeBehaviorPending.value) {
    return
  }

  const nextValue = !closeToTrayOnClose.value
  closeToTrayOnClose.value = nextValue

  if (!isTauri()) {
    return
  }

  closeBehaviorPending.value = true
  try {
    const behavior = await invoke<CloseBehavior>('set_close_to_tray_on_close', {
      enabled: nextValue,
    })
    closeToTrayOnClose.value = behavior.closeToTrayOnClose
  } catch {
    closeToTrayOnClose.value = !nextValue
  } finally {
    closeBehaviorPending.value = false
  }
}

onMounted(async () => {
  previousBodyOverflow.value = document.body.style.overflow
  document.body.style.overflow = 'hidden'
  window.addEventListener('keydown', handleKeydown)
  window.addEventListener('resize', syncOverlaySize)
  await loadCloseBehavior()
  await nextTick()
  animateOpen()
})

onBeforeUnmount(() => {
  document.body.style.overflow = previousBodyOverflow.value
  window.removeEventListener('keydown', handleKeydown)
  window.removeEventListener('resize', syncOverlaySize)
})
</script>

<template>
  <section ref="overlayRef" class="settings-overlay" aria-modal="true" role="dialog">
    <div ref="contentRef" class="settings-page">
      <header class="settings-header">
        <Button
          variant="ghost"
          size="icon"
          class="settings-back-button"
          aria-label="返回"
          @click="closeSettings"
        >
          <ArrowLeft class="size-5" />
        </Button>

        <div class="settings-title">
          <p>LanCtrl</p>
          <h2>设置</h2>
        </div>
      </header>

      <main class="settings-content">
        <section class="settings-hero">
          <div class="settings-hero-icon">
            <MonitorCog class="size-7" />
          </div>
          <div>
            <p class="settings-kicker">Desktop Preferences</p>
            <h3>桌面端偏好设置</h3>
            <p>
              管理当前电脑端的显示偏好与基础安全提示，保持控制台在不同使用环境下都清晰可读。
            </p>
          </div>
        </section>

        <section class="settings-grid">
          <article class="settings-panel settings-panel-wide">
            <div class="settings-panel-heading">
              <span class="settings-panel-icon">
                <Palette class="size-5" />
              </span>
              <div>
                <h4>外观模式</h4>
                <p>设置会立即保存到当前桌面端。</p>
              </div>
            </div>

            <div class="mode-options">
              <button
                v-for="option in modeOptions"
                :key="option.value"
                type="button"
                class="mode-option"
                :class="{ 'is-active': mode === option.value }"
                @click="setThemeMode(option.value)"
              >
                <span class="mode-option-icon">
                  <component :is="option.icon" class="size-5" />
                </span>
                <span class="mode-option-copy">
                  <strong>{{ option.label }}</strong>
                  <span>{{ option.description }}</span>
                </span>
                <Check v-if="mode === option.value" class="mode-option-check size-5" />
              </button>
            </div>
          </article>

          <article class="settings-panel">
            <div class="settings-panel-heading">
              <span class="settings-panel-icon">
                <ShieldCheck class="size-5" />
              </span>
              <div>
                <h4>连接安全</h4>
                <p>新的移动端配对请求会在桌面端弹出确认。</p>
              </div>
            </div>
          </article>

          <article class="settings-panel">
            <div class="settings-panel-heading">
              <span class="settings-panel-icon">
                <Minimize2 class="size-5" />
              </span>
              <div>
                <h4>关闭按钮行为</h4>
                <p>关闭主窗口时保留桌面端后台运行。</p>
              </div>
            </div>

            <button
              type="button"
              class="switch-setting"
              role="switch"
              :aria-checked="closeToTrayOnClose"
              :disabled="closeBehaviorPending"
              @click="toggleCloseBehavior"
            >
              <span class="switch-setting-copy">
                <strong>收起到右下角托盘</strong>
                <span>{{ closeToTrayOnClose ? '已启用' : '已关闭' }}</span>
              </span>
              <span class="switch-track" :class="{ 'is-active': closeToTrayOnClose }">
                <span class="switch-thumb"></span>
              </span>
            </button>
          </article>
        </section>
      </main>
    </div>
  </section>
</template>

<style scoped>
.settings-overlay {
  position: fixed;
  inset: 0 auto auto 0;
  z-index: 70;
  overflow: hidden;
  background:
    linear-gradient(
      135deg,
      color-mix(in oklab, var(--background) 98%, var(--primary) 2%),
      color-mix(in oklab, var(--card) 94%, var(--primary) 6%)
    );
  color: var(--foreground);
  box-shadow: 0 24px 70px rgba(15, 23, 42, 0.24);
  transform-origin: top left;
  will-change: transform, width, height, border-radius, opacity;
}

.settings-page {
  display: flex;
  width: 100vw;
  height: 100vh;
  min-width: 320px;
  flex-direction: column;
  overflow: hidden;
}

.settings-header {
  display: flex;
  align-items: center;
  gap: 1rem;
  min-height: 5rem;
  padding: 1.4rem 2rem;
  border-bottom: 1px solid color-mix(in oklab, var(--border) 76%, transparent);
  background: color-mix(in oklab, var(--card) 78%, transparent);
  backdrop-filter: saturate(180%) blur(20px);
}

.settings-back-button {
  border-radius: 999px;
  transition:
    background-color 180ms ease,
    color 180ms ease,
    transform 180ms ease;
}

.settings-back-button:hover {
  transform: translateX(-2px);
}

.settings-back-button:active {
  transform: translateX(-2px) scale(0.94);
}

.settings-title p {
  color: var(--muted-foreground);
  font-size: 0.72rem;
  letter-spacing: 0.16em;
  text-transform: uppercase;
}

.settings-title h2 {
  font-family: var(--font-display);
  font-size: 1.35rem;
  font-weight: 600;
}

.settings-content {
  flex: 1;
  overflow-y: auto;
  padding: 2rem;
}

.settings-hero {
  display: grid;
  grid-template-columns: auto minmax(0, 1fr);
  gap: 1.25rem;
  max-width: 1040px;
  margin: 0 auto 1.5rem;
  padding: 1.5rem;
  border: 1px solid color-mix(in oklab, var(--border) 70%, transparent);
  border-radius: 1.5rem;
  background: color-mix(in oklab, var(--card) 88%, transparent);
}

.settings-hero-icon,
.settings-panel-icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  border-radius: 999px;
  background: color-mix(in oklab, var(--primary) 14%, transparent);
  color: var(--primary);
}

.settings-hero-icon {
  width: 3.25rem;
  height: 3.25rem;
}

.settings-kicker {
  color: var(--muted-foreground);
  font-size: 0.75rem;
  letter-spacing: 0.18em;
  text-transform: uppercase;
}

.settings-hero h3 {
  margin-top: 0.2rem;
  font-family: var(--font-display);
  font-size: clamp(1.7rem, 4vw, 3rem);
  font-weight: 650;
  line-height: 1.08;
}

.settings-hero p:last-child {
  max-width: 46rem;
  margin-top: 0.65rem;
  color: var(--muted-foreground);
  line-height: 1.7;
}

.settings-grid {
  display: grid;
  grid-template-columns: minmax(0, 1.35fr) minmax(280px, 0.65fr);
  gap: 1rem;
  max-width: 1040px;
  margin: 0 auto;
}

.settings-panel {
  border: 1px solid color-mix(in oklab, var(--border) 70%, transparent);
  border-radius: 1.5rem;
  background: color-mix(in oklab, var(--card) 88%, transparent);
  padding: 1.25rem;
}

.settings-panel-heading {
  display: flex;
  align-items: flex-start;
  gap: 0.9rem;
}

.settings-panel-icon {
  width: 2.5rem;
  height: 2.5rem;
  flex-shrink: 0;
}

.settings-panel h4 {
  font-family: var(--font-display);
  font-size: 1.08rem;
  font-weight: 600;
}

.settings-panel p {
  margin-top: 0.25rem;
  color: var(--muted-foreground);
  font-size: 0.9rem;
  line-height: 1.6;
}

.mode-options {
  display: grid;
  gap: 0.75rem;
  margin-top: 1.2rem;
}

.mode-option {
  display: grid;
  grid-template-columns: auto minmax(0, 1fr) auto;
  align-items: center;
  gap: 0.85rem;
  width: 100%;
  min-height: 4.75rem;
  border: 1px solid color-mix(in oklab, var(--border) 82%, transparent);
  border-radius: 1rem;
  background: color-mix(in oklab, var(--background) 74%, transparent);
  padding: 0.9rem 1rem;
  text-align: left;
  transition:
    border-color 180ms ease,
    background-color 180ms ease,
    box-shadow 180ms ease,
    transform 180ms ease;
}

.mode-option:hover {
  border-color: color-mix(in oklab, var(--primary) 42%, var(--border));
  background: color-mix(in oklab, var(--primary) 7%, var(--background));
  transform: translateY(-1px);
}

.mode-option:active {
  transform: translateY(0) scale(0.99);
}

.mode-option.is-active {
  border-color: color-mix(in oklab, var(--primary) 58%, var(--border));
  background: color-mix(in oklab, var(--primary) 12%, var(--background));
  box-shadow: inset 0 0 0 1px color-mix(in oklab, var(--primary) 28%, transparent);
}

.mode-option-icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 2.4rem;
  height: 2.4rem;
  border-radius: 999px;
  background: color-mix(in oklab, var(--card) 82%, transparent);
  color: var(--foreground);
}

.mode-option-copy {
  display: grid;
  gap: 0.25rem;
  min-width: 0;
}

.mode-option-copy strong {
  font-size: 0.96rem;
}

.mode-option-copy span {
  color: var(--muted-foreground);
  font-size: 0.84rem;
  line-height: 1.45;
}

.mode-option-check {
  color: var(--primary);
}

.switch-setting {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto;
  align-items: center;
  gap: 1rem;
  width: 100%;
  min-height: 4.5rem;
  margin-top: 1.2rem;
  border: 1px solid color-mix(in oklab, var(--border) 82%, transparent);
  border-radius: 1rem;
  background: color-mix(in oklab, var(--background) 74%, transparent);
  padding: 0.9rem 1rem;
  text-align: left;
  transition:
    border-color 180ms ease,
    background-color 180ms ease,
    transform 180ms ease;
}

.switch-setting:hover {
  border-color: color-mix(in oklab, var(--primary) 42%, var(--border));
  background: color-mix(in oklab, var(--primary) 7%, var(--background));
  transform: translateY(-1px);
}

.switch-setting:disabled {
  cursor: wait;
  opacity: 0.72;
  transform: none;
}

.switch-setting-copy {
  display: grid;
  gap: 0.25rem;
  min-width: 0;
}

.switch-setting-copy strong {
  font-size: 0.96rem;
}

.switch-setting-copy span {
  color: var(--muted-foreground);
  font-size: 0.84rem;
}

.switch-track {
  position: relative;
  width: 2.9rem;
  height: 1.6rem;
  flex-shrink: 0;
  border-radius: 999px;
  background: color-mix(in oklab, var(--muted-foreground) 28%, transparent);
  transition: background-color 180ms ease;
}

.switch-track.is-active {
  background: color-mix(in oklab, var(--primary) 78%, var(--background));
}

.switch-thumb {
  position: absolute;
  top: 0.2rem;
  left: 0.2rem;
  width: 1.2rem;
  height: 1.2rem;
  border-radius: 999px;
  background: var(--background);
  box-shadow: 0 4px 10px rgba(15, 23, 42, 0.2);
  transition: transform 180ms ease;
}

.switch-track.is-active .switch-thumb {
  transform: translateX(1.3rem);
}

@media (max-width: 860px) {
  .settings-grid {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 720px) {
  .settings-header,
  .settings-content {
    padding-inline: 1rem;
  }

  .settings-hero {
    grid-template-columns: 1fr;
  }
}
</style>
