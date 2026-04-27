export const elements = {
  actionGrid: document.querySelector("#actionGrid"),
  volumePanel: document.querySelector("#volumePanel"),
  taskFeature: document.querySelector("#taskFeature"),
  taskVolumeField: document.querySelector("#taskVolumeField"),
  taskVolume: document.querySelector("#taskVolume"),
  taskDelay: document.querySelector("#taskDelay"),
  taskForm: document.querySelector("#taskForm"),
  presetList: document.querySelector("#presetList"),
  taskList: document.querySelector("#taskList"),
  taskCountText: document.querySelector("#taskCountText"),
  historyList: document.querySelector("#historyList"),
  toast: document.querySelector("#toast"),
  connectionDot: document.querySelector("#connectionDot"),
  connectionText: document.querySelector("#connectionText"),
  connectionDetail: document.querySelector("#connectionDetail"),
  refreshStateButton: document.querySelector("#refreshStateButton"),
};

export function showToast(message) {
  elements.toast.textContent = message;
  elements.toast.classList.add("visible");
  window.clearTimeout(showToast.timer);
  showToast.timer = window.setTimeout(() => {
    elements.toast.classList.remove("visible");
  }, 2600);
}

export function setConnection(status, detail) {
  elements.connectionDot.classList.toggle("connected", status === "connected");
  elements.connectionDot.classList.toggle("offline", status === "offline");
  elements.connectionText.textContent = status === "connected" ? "实时同步中" : status === "offline" ? "连接断开" : "正在连接";
  elements.connectionDetail.textContent = detail;
}
