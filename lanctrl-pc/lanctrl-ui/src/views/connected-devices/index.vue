<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue'
import { invoke } from '@tauri-apps/api/core'
import { listen } from '@tauri-apps/api/event'
import type { UnlistenFn } from '@tauri-apps/api/event'

interface ClientInfo {
  client_id: string
  client_name: string
  last_seen_at: number
  last_ip: string | null
  is_online: boolean
  is_connected: boolean
}

const clients = ref<ClientInfo[]>([])
const loading = ref(true)

async function fetchClients() {
  try {
    loading.value = true
    const rawClients = await invoke<ClientInfo[]>('get_clients_with_status')

    // 并发 Ping 检测在线状态
    const checkPromises = rawClients.map(async (client) => {
      let isOnline = false
      if (client.last_ip) {
        try {
          isOnline = await invoke<boolean>('ping_mobile_device', { ip: client.last_ip })
        } catch {
          // ignore
        }
      }
      return { ...client, is_online: isOnline }
    })

    clients.value = await Promise.all(checkPromises)
  } catch (error) {
    console.error('Failed to get paired clients:', error)
  } finally {
    loading.value = false
  }
}


async function forgetDevice(client: ClientInfo) {
  if (!confirm('确定要忘记该设备吗？忘记后该设备将无法控制本机，若要恢复需要重新在手机端发起配对。')) return
  try {
    if (client.is_connected && client.last_ip) {
      await invoke('notify_mobile_disconnect', { ip: client.last_ip }).catch(() => {})
    }
    await invoke('remove_paired_client', { clientId: client.client_id })
    await fetchClients()
  } catch (error) {
    console.error('Failed to remove client:', error)
  }
}

let unlistenConnected: UnlistenFn
let unlistenDisconnected: UnlistenFn

onMounted(async () => {
  fetchClients()

  unlistenConnected = await listen<any>('device_connected', (e) => {
    alert(`设备 [${e.payload.client_name}] 已连接并取得控制权`)
    const target = clients.value.find(c => c.client_id === e.payload.client_id)
    if (target) {
      target.is_connected = true
      target.is_online = true
    }
  })

  unlistenDisconnected = await listen<any>('device_disconnected', (e) => {
    const target = clients.value.find(c => c.client_id === e.payload.client_id)
    if (target && target.is_connected) {
      alert(`设备 [${e.payload.client_name}] 已断开连接`)
      target.is_connected = false
    }
  })
})

onUnmounted(() => {
  if (unlistenConnected) unlistenConnected()
  if (unlistenDisconnected) unlistenDisconnected()
})
</script>

<template>
  <div class="glass-panel fade-in list-container">
    <div class="header">
      <h2>设备管理</h2>
      <button class="btn-refresh" @click="fetchClients">
        <span class="refresh-icon">⟳</span> 探测刷新
      </button>
    </div>

    <div v-if="loading" class="empty-state">
      <div class="loading-spinner"></div>
      <span style="margin-left: 12px">正在探测设备在线状态...</span>
    </div>
    <div v-else-if="clients.length === 0" class="empty-state">
      <p style="color: var(--text-muted);">当前暂无受信任的控制设备。请在手机端发送配对请求。</p>
    </div>
    <div v-else class="client-list">
      <div
        v-for="c in clients"
        :key="c.client_id"
        class="client-card"
        :class="{ 'card-online': c.is_online }"
      >
        <div class="client-left">
          <div class="status-dot" :class="c.is_online ? 'dot-online' : 'dot-offline'"></div>
          <div class="client-icon" :class="{ 'icon-online': c.is_online }">📱</div>
          <div class="details">
            <h3>
              {{ c.client_name }}
              <span v-if="c.is_connected" class="tag-connected">已连接控制</span>
              <span v-else-if="c.is_online" class="tag-online">在线</span>
              <span v-else class="tag-offline">离线</span>
            </h3>
            <span class="id-badge">ID: {{ c.client_id.substring(0, 8) }}... · IP: {{ c.last_ip || '未知' }}</span>
          </div>
        </div>
        <div class="client-actions">
          <button class="btn-forget" @click="forgetDevice(c)">忘记设备</button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.list-container {
  padding: 2rem;
  border-radius: var(--radius-lg);
  height: 100%;
  display: flex;
  flex-direction: column;
}
.header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 24px;
}
.header h2 {
  margin: 0;
}
.btn-refresh {
  background: var(--bg-secondary);
  border: 1px solid var(--border-color);
  padding: 6px 14px;
  border-radius: 8px;
  cursor: pointer;
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 13px;
  transition: all 0.2s;
}
.btn-refresh:hover {
  background: var(--bg-hover);
}
.refresh-icon {
  font-size: 16px;
}
.empty-state {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  border: 2px dashed var(--border-color);
  border-radius: 12px;
  background: rgba(0,0,0,0.02);
}
.loading-spinner {
  width: 20px;
  height: 20px;
  border: 2px solid var(--border-color);
  border-top-color: var(--text-primary);
  border-radius: 50%;
  animation: spin 0.6s linear infinite;
}
@keyframes spin {
  to { transform: rotate(360deg); }
}
.client-list {
  display: flex;
  flex-direction: column;
  gap: 12px;
  overflow-y: auto;
}
.client-card {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 16px 20px;
  border: 1px solid var(--border-color);
  border-radius: 12px;
  background: var(--bg-primary);
  transition: all 0.25s ease;
}
.card-online {
  border-color: rgba(76, 175, 80, 0.35);
  background: linear-gradient(135deg, rgba(76, 175, 80, 0.04), transparent);
}
.client-card:hover {
  transform: translateY(-1px);
  box-shadow: 0 4px 12px rgba(0,0,0,0.05);
}
.client-left {
  display: flex;
  align-items: center;
  gap: 12px;
}
.status-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  flex-shrink: 0;
}
.dot-online {
  background: #4CAF50;
  box-shadow: 0 0 8px rgba(76, 175, 80, 0.5);
}
.dot-offline {
  background: #bdbdbd;
}
.client-icon {
  font-size: 22px;
  background: #e3f2fd;
  width: 44px;
  height: 44px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 10px;
}
.icon-online {
  background: #e8f5e9;
}
.details h3 {
  margin: 0 0 4px 0;
  font-size: 15px;
  display: flex;
  align-items: center;
  gap: 8px;
}
.id-badge {
  font-size: 12px;
  color: var(--text-muted);
}
.tag-connected {
  font-size: 11px;
  padding: 2px 8px;
  border-radius: 10px;
  background: #4CAF50;
  color: #fff;
  font-weight: 500;
}
.tag-online {
  font-size: 11px;
  padding: 2px 8px;
  border-radius: 10px;
  background: #e8f5e9;
  color: #4CAF50;
  font-weight: 500;
}
.tag-offline {
  font-size: 11px;
  padding: 2px 8px;
  border-radius: 10px;
  background: #f5f5f5;
  color: #9e9e9e;
  font-weight: 500;
}
.client-actions {
  display: flex;
  gap: 8px;
  flex-shrink: 0;
}
.btn-connect {
  background: #e8f5e9;
  color: #2e7d32;
  border: 1px solid rgba(76, 175, 80, 0.3);
  padding: 6px 16px;
  border-radius: 8px;
  cursor: pointer;
  font-size: 13px;
  font-weight: 500;
  transition: all 0.2s;
}
.btn-connect:hover {
  background: #c8e6c9;
}
.btn-disconnect {
  background: #fff3e0;
  color: #e65100;
  border-color: rgba(230, 81, 0, 0.3);
}
.btn-disconnect:hover {
  background: #ffe0b2;
}
.btn-forget {
  background: transparent;
  color: var(--text-muted);
  border: 1px solid var(--border-color);
  padding: 6px 12px;
  border-radius: 8px;
  cursor: pointer;
  font-size: 13px;
  transition: all 0.2s;
}
.btn-forget:hover {
  background: #ffebee;
  color: #d32f2f;
  border-color: rgba(211, 47, 47, 0.3);
}
</style>
