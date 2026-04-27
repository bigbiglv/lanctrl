import { fetchState } from "./app/api.js";
import { elements, showToast } from "./app/dom.js";
import { connectWebSocket } from "./app/realtime.js";
import { applyState, renderTaskComposer, renderTasks } from "./app/render.js";
import { initRouter } from "./app/router.js";
import { commandForFeature, state } from "./app/state.js";

async function refreshState() {
  applyState(await fetchState());
}

function bindEvents() {
  elements.refreshStateButton.addEventListener("click", async () => {
    try {
      await refreshState();
      showToast("状态已刷新");
    } catch (error) {
      showToast(String(error.message || error));
    }
  });

  elements.taskFeature.addEventListener("change", renderTaskComposer);
  elements.taskForm.addEventListener("submit", async (event) => {
    event.preventDefault();
    const features = state.groups.flatMap((group) => group.features);
    const feature = features.find((item) => item.featureKey === elements.taskFeature.value);
    if (!feature) {
      showToast("请选择任务类型");
      return;
    }

    const command = feature.control.type === "range"
      ? commandForFeature(feature, Number(elements.taskVolume.value))
      : commandForFeature(feature);

    try {
      const { createScheduledTask } = await import("./app/api.js");
      const payload = await createScheduledTask(command, Number(elements.taskDelay.value));
      if (!payload.success) {
        throw new Error(payload.msg || "创建任务失败");
      }
      showToast(payload.msg || "定时任务已创建");
    } catch (error) {
      showToast(String(error.message || error));
    }
  });

  window.setInterval(renderTasks, 1000);
}

initRouter();
bindEvents();
refreshState().catch((error) => showToast(String(error.message || error)));
connectWebSocket();
