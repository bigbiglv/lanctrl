<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue';
import { listen } from '@tauri-apps/api/event';
import type { UnlistenFn } from '@tauri-apps/api/event';
import { invoke } from '@tauri-apps/api/core';

interface PairRequest {
  client_id: string;
  client_name: string;
}

const show = ref(false);
const currentRequest = ref<PairRequest | null>(null);
let unlisten: UnlistenFn | null = null;

onMounted(async () => {
  unlisten = await listen<PairRequest>('pair_request', (event) => {
    currentRequest.value = event.payload;
    show.value = true;
  });
});

onUnmounted(() => {
  if (unlisten) {
    unlisten();
  }
});

async function resolvePair(allowed: boolean) {
  if (!currentRequest.value) return;
  try {
    await invoke('resolve_pair_request', {
      clientId: currentRequest.value.client_id,
      allowed
    });
  } catch (e) {
    console.error('Failed to resolve pair request', e);
  } finally {
    show.value = false;
    currentRequest.value = null;
  }
}
</script>

<template>
  <div v-if="show" class="pair-dialog-overlay">
    <div class="pair-dialog">
      <div class="dialog-header">
        <div class="icon-warning">!</div>
        <h3>新设备配对请求</h3>
      </div>
      <p>有一台名为 <strong>{{ currentRequest?.client_name }}</strong> 的装置正在通过局域网请求获得当前电脑的控制权。您是否允许？</p>
      <div class="actions">
        <button class="btn-deny" @click="resolvePair(false)">立即拒绝</button>
        <button class="btn-allow" @click="resolvePair(true)">允许关联</button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.pair-dialog-overlay {
  position: fixed;
  top: 0; left: 0; right: 0; bottom: 0;
  background: rgba(0, 0, 0, 0.6);
  backdrop-filter: blur(4px);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 9999;
  animation: fadeIn 0.2s ease-out;
}

@keyframes fadeIn {
  from { opacity: 0; }
  to { opacity: 1; }
}

.pair-dialog {
  background: var(--bg-primary, #ffffff);
  border: 1px solid var(--border-color, #eaeaea);
  padding: 32px;
  border-radius: 16px;
  max-width: 400px;
  box-shadow: 0 12px 48px rgba(0, 0, 0, 0.15);
  animation: slideUp 0.3s cubic-bezier(0.16, 1, 0.3, 1);
}

@keyframes slideUp {
  from { transform: translateY(20px); opacity: 0; }
  to { transform: translateY(0); opacity: 1; }
}

.dialog-header {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-bottom: 16px;
}

.icon-warning {
  background: #fff3e0;
  color: #fb8c00;
  width: 32px;
  height: 32px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: bold;
  font-size: 18px;
}

.pair-dialog h3 {
  margin: 0;
  font-size: 18px;
  color: var(--text-primary, #333333);
}

.pair-dialog p {
  line-height: 1.6;
  color: var(--text-secondary, #666666);
  margin-bottom: 32px;
}

.actions {
  display: flex;
  gap: 16px;
  justify-content: flex-end;
}

button {
  padding: 10px 24px;
  border: none;
  border-radius: 8px;
  font-weight: 500;
  font-size: 14px;
  cursor: pointer;
  transition: all 0.2s ease;
}

.btn-deny { 
  background: #f5f5f5; 
  color: #666; 
}

.btn-deny:hover {
  background: #e0e0e0;
}

.btn-allow { 
  background: #4caf50; 
  color: white; 
  box-shadow: 0 4px 12px rgba(76, 175, 80, 0.3);
}

.btn-allow:hover {
  background: #43a047;
  transform: translateY(-1px);
}
</style>
