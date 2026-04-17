<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue'
import { invoke } from '@tauri-apps/api/core'
import { listen } from '@tauri-apps/api/event'
import type { PeripheralDevice } from './types'

const devices = ref<PeripheralDevice[]>([])
let unlistenDeviceChanged: (() => void) | null = null

onMounted(async () => {
  try {
    // 首次主动抓取数据
    devices.value = await invoke('get_peripheral_devices')
    
    // 注册基于 Rust 事件池的后台推送事件
    const unlisten = await listen<PeripheralDevice[]>('device-changed', (event) => {
      devices.value = event.payload
    })
    unlistenDeviceChanged = unlisten

    // 命令 Rust 驱动层开始监控硬件变更流 (休眠式)
    await invoke('start_device_watch')
  } catch (e) {
    console.error('Failed to coordinate with backend rust process:', e)
  }
})

onUnmounted(async () => {
  // 切出组件时，立即销毁监听和阻塞后端的事件池
  if (unlistenDeviceChanged) {
    unlistenDeviceChanged()
  }
  try {
    await invoke('stop_device_watch')
  } catch (e) {
    console.error('Failed to suspend rust watcher:', e)
  }
})

const getDeviceIcon = (classType: string | null | undefined) => {
  switch ((classType || '').toLowerCase()) {
    case 'keyboard': return '⌨️'
    case 'mouse': return '🖱️'
    case 'usb': return '🔌'
    default: return '🖥️'
  }
}
</script>

<template>
  <div class="dashboard-panel fade-in">
    <div class="header">
      <h2>外设概览</h2>
      <p>基于底层 PnP 驱动解耦推送的本机外设状态监控</p>
    </div>

    <div class="device-grid">
      <div v-for="dev in devices" :key="dev.id" class="device-card glass-panel">
        <div class="icon">{{ getDeviceIcon(dev.classType) }}</div>
        <div class="meta">
          <h3 :title="dev.name || '未知设备'">{{ dev.name || '未知设备' }}</h3>
          <div class="status-row">
            <span class="dot" :class="(dev.status || '').toLowerCase() == 'ok' ? 'ok' : 'error'"></span>
            <span class="status-text">{{ dev.status || 'Unknown' }}</span>
            <span class="badge">{{ dev.classType || 'Generic' }}</span>
          </div>
        </div>
      </div>
      
      <div v-if="devices.length === 0" class="empty-state">
        <p>未检测到外设或硬件层正在枚举加载中...</p>
      </div>
    </div>
  </div>
</template>

<style scoped lang="scss">
.dashboard-panel {
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
  height: 100%;
}

.header {
  h2 {
    font-size: 2rem;
    color: var(--text-main);
    margin-bottom: 0.5rem;
  }
  p {
    color: var(--text-muted);
  }
}

.device-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  gap: 1.25rem;
  overflow-y: auto;
  padding-bottom: 2rem;

  .device-card {
    display: flex;
    align-items: center;
    gap: 1rem;
    padding: 1.25rem;
    border-radius: var(--radius-lg);
    background: color-mix(in srgb, var(--color-white) 2%, transparent);
    border: 1px solid var(--border-color);
    transition: all var(--transition-normal);
    
    &:hover {
      background: color-mix(in srgb, var(--color-white) 5%, transparent);
      border-color: var(--color-primary);
      transform: translateY(-2px);
      box-shadow: 0 8px 24px color-mix(in srgb, var(--color-black) 5%, transparent);
    }

    .icon {
      font-size: 2.5rem;
      background: color-mix(in srgb, var(--color-white) 15%, transparent);
      padding: 0.75rem;
      border-radius: var(--radius-md);
    }

    .meta {
      flex: 1;
      overflow: hidden;

      h3 {
        font-size: 1.1rem;
        color: var(--text-main);
        white-space: nowrap;
        overflow: hidden;
        text-overflow: ellipsis;
        margin-bottom: 0.5rem;
      }

      .status-row {
        display: flex;
        align-items: center;
        gap: 0.5rem;
        font-size: 0.85rem;

        .dot {
          width: 8px;
          height: 8px;
          border-radius: 50%;
          &.ok {
            background: var(--color-success);
            box-shadow: 0 0 8px var(--color-success);
          }
          &.error {
            background: var(--color-danger);
            box-shadow: 0 0 8px var(--color-danger);
          }
        }

        .status-text {
          color: var(--text-muted);
        }

        .badge {
          margin-left: auto;
          background: color-mix(in srgb, var(--color-primary) 15%, transparent);
          color: var(--color-primary-dark);
          padding: 0.1rem 0.4rem;
          border-radius: var(--radius-sm);
          font-weight: 600;
          font-size: 0.75rem;
          text-transform: uppercase;
        }
      }
    }
  }

  .empty-state {
    grid-column: 1 / -1;
    text-align: center;
    padding: 3rem;
    color: var(--text-muted);
    border: 1px dashed var(--border-color);
    border-radius: var(--radius-lg);
  }
}

// 适配浅色模式修正一点高光
[data-theme="light"] {
  .device-card .badge {
    color: var(--color-primary);
  }
  .device-card .icon {
    background: color-mix(in srgb, var(--color-black) 2%, transparent);
  }
}
</style>
