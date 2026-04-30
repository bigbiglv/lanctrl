import { relaunch } from '@tauri-apps/plugin-process'
import { check, type DownloadEvent, type Update } from '@tauri-apps/plugin-updater'
import { computed, ref } from 'vue'
import { showAppNotice } from './useNotice'

const updateInfo = ref<Update | null>(null)
const checking = ref(false)
const downloading = ref(false)
const installing = ref(false)
const downloadedBytes = ref(0)
const totalBytes = ref<number | null>(null)

interface CheckForUpdateOptions {
  notify?: boolean
}

function isTauriRuntime() {
  return typeof window !== 'undefined' && '__TAURI_INTERNALS__' in window
}

function shouldCheckForUpdate() {
  // Tauri dev 模式也能调用 updater，需要显式跳过，避免开发版提示线上更新。
  return isTauriRuntime() && !import.meta.env.DEV
}

function formatUpdateError(error: unknown) {
  return error instanceof Error ? error.message : String(error)
}

function handleDownloadEvent(event: DownloadEvent) {
  if (event.event === 'Started') {
    downloadedBytes.value = 0
    totalBytes.value = event.data.contentLength ?? null
    return
  }

  if (event.event === 'Progress') {
    downloadedBytes.value += event.data.chunkLength
    return
  }

  downloading.value = false
}

async function checkForUpdate(options: CheckForUpdateOptions = {}) {
  if (!shouldCheckForUpdate()) {
    if (options.notify) {
      showAppNotice({
        title: '检查更新',
        message: '开发模式不会检查线上更新',
        tone: 'warning',
      })
    }
    return
  }

  if (checking.value || installing.value) {
    return
  }

  checking.value = true

  try {
    updateInfo.value = await check()

    if (options.notify) {
      showAppNotice(
        updateInfo.value
          ? {
              title: '发现新版本',
              message: `可更新到 ${updateInfo.value.version}`,
            }
          : {
              title: '检查完成',
              message: '当前已是最新版本',
            },
      )
    }
  } catch (error) {
    console.error('检查更新失败', error)
    if (options.notify) {
      showAppNotice({
        title: '检查失败',
        message: formatUpdateError(error),
        tone: 'warning',
      })
    }
  } finally {
    checking.value = false
  }
}

async function installUpdate() {
  if (!updateInfo.value || installing.value) {
    return
  }

  installing.value = true
  downloading.value = true
  downloadedBytes.value = 0
  totalBytes.value = null

  showAppNotice({
    title: '开始更新',
    message: `正在下载 ${updateInfo.value.version}`,
  })

  try {
    await updateInfo.value.downloadAndInstall(handleDownloadEvent)

    showAppNotice({
      title: '更新完成',
      message: '即将重启应用完成安装',
    })

    await relaunch()
  } catch (error) {
    console.error('安装更新失败', error)
    showAppNotice({
      title: '更新失败',
      message: formatUpdateError(error),
      tone: 'warning',
    })
  } finally {
    downloading.value = false
    installing.value = false
  }
}

export function useUpdater() {
  const downloadProgress = computed(() => {
    if (!totalBytes.value) {
      return null
    }

    return Math.min(100, Math.round((downloadedBytes.value / totalBytes.value) * 100))
  })

  return {
    updateInfo,
    checking,
    downloading,
    installing,
    downloadedBytes,
    totalBytes,
    downloadProgress,
    hasUpdate: computed(() => updateInfo.value !== null),
    checkForUpdate,
    installUpdate,
  }
}
