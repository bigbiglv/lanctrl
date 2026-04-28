import { relaunch } from '@tauri-apps/plugin-process'
import { check, type Update } from '@tauri-apps/plugin-updater'
import { computed, ref } from 'vue'

const updateInfo = ref<Update | null>(null)
const checking = ref(false)
const installing = ref(false)

function isTauriRuntime() {
  return typeof window !== 'undefined' && '__TAURI_INTERNALS__' in window
}

async function checkForUpdate() {
  if (!isTauriRuntime() || checking.value || installing.value) {
    return
  }

  checking.value = true

  try {
    updateInfo.value = await check()
  } catch (error) {
    console.error('检查更新失败', error)
  } finally {
    checking.value = false
  }
}

async function installUpdate() {
  if (!updateInfo.value || installing.value) {
    return
  }

  installing.value = true

  try {
    await updateInfo.value.downloadAndInstall()
    await relaunch()
  } catch (error) {
    console.error('安装更新失败', error)
    installing.value = false
  }
}

export function useUpdater() {
  return {
    updateInfo,
    checking,
    installing,
    hasUpdate: computed(() => updateInfo.value !== null),
    checkForUpdate,
    installUpdate,
  }
}
