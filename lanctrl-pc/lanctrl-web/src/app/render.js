import { cancelScheduledTask, createScheduledTask, executeCommand } from "./api.js";
import { elements, showToast } from "./dom.js";
import { actionFeatures, commandForFeature, rangeFeatures, state, statusLabels } from "./state.js";
import { countdownText, escapeHtml, formatDate } from "./utils.js";

export function applyState(payload) {
  state.groups = payload.groups ?? [];
  state.snapshot = payload.snapshot ?? null;
  state.tasks = payload.tasks ?? [];
  state.history = payload.history ?? [];
  render();
}

async function executeFeature(feature, command) {
  if (feature.control.confirmRequired) {
    const confirmed = window.confirm(`确认执行“${feature.title}”？\n${feature.description}`);
    if (!confirmed) {
      return;
    }
  }

  state.activeFeatureKey = feature.featureKey;
  renderActions();

  try {
    const payload = await executeCommand(command);
    if (!payload.success) {
      throw new Error(payload.msg || "执行失败");
    }
    if (payload.result?.volumeLevel !== null && payload.result?.volumeLevel !== undefined) {
      state.snapshot = { volumeLevel: payload.result.volumeLevel };
    }
    showToast(payload.msg || "执行成功");
  } catch (error) {
    showToast(String(error.message || error));
  } finally {
    state.activeFeatureKey = null;
    renderActions();
  }
}

async function createTask(command, delayMinutes) {
  const payload = await createScheduledTask(command, delayMinutes);
  if (!payload.success) {
    throw new Error(payload.msg || "创建任务失败");
  }
  showToast(payload.msg || "定时任务已创建");
}

async function cancelTask(taskId) {
  const payload = await cancelScheduledTask(taskId);
  if (!payload.success) {
    throw new Error(payload.msg || "停止任务失败");
  }
  showToast(payload.msg || "定时任务已停止");
}

export function renderActions() {
  const actions = actionFeatures();
  if (actions.length === 0) {
    elements.actionGrid.innerHTML = `<div class="empty-state">功能目录暂不可用，请稍后刷新。</div>`;
  } else {
    elements.actionGrid.innerHTML = actions.map((feature) => {
      const danger = feature.control.tone === "danger";
      const pending = state.activeFeatureKey === feature.featureKey;
      return `
        <article class="glass-card">
          <div class="feature-icon ${danger ? "danger" : ""}">${danger ? "⏻" : "●"}</div>
          <div class="feature-title">${escapeHtml(feature.title)}</div>
          <p class="feature-desc">${escapeHtml(feature.description)}</p>
          <button
            class="${danger ? "danger-button" : "primary-button"}"
            type="button"
            data-action-feature="${escapeHtml(feature.featureKey)}"
            ${pending ? "disabled" : ""}
          >
            ${pending ? "执行中" : escapeHtml(feature.control.buttonText)}
          </button>
        </article>
      `;
    }).join("");
  }

  const volumeFeature = rangeFeatures()[0];
  if (!volumeFeature) {
    elements.volumePanel.innerHTML = "";
    return;
  }

  const currentVolume = state.snapshot?.volumeLevel ?? 0;
  elements.volumePanel.innerHTML = `
    <article class="glass-card volume-card">
      <div class="volume-head">
        <div>
          <div class="feature-title">${escapeHtml(volumeFeature.title)}</div>
          <p class="feature-desc">${escapeHtml(volumeFeature.description)}</p>
        </div>
        <div id="volumeValue" class="volume-value">${currentVolume}%</div>
      </div>
      <input id="volumeRange" type="range" min="${volumeFeature.control.min}" max="${volumeFeature.control.max}" step="${volumeFeature.control.step}" value="${currentVolume}" />
      <button class="primary-button" type="button" id="applyVolumeButton">${escapeHtml(volumeFeature.control.actionText)}</button>
    </article>
  `;

  document.querySelectorAll("[data-action-feature]").forEach((button) => {
    button.addEventListener("click", () => {
      const feature = actions.find((item) => item.featureKey === button.dataset.actionFeature);
      if (feature) {
        executeFeature(feature, commandForFeature(feature));
      }
    });
  });

  const range = document.querySelector("#volumeRange");
  const value = document.querySelector("#volumeValue");
  const apply = document.querySelector("#applyVolumeButton");
  range?.addEventListener("input", () => {
    value.textContent = `${range.value}%`;
  });
  apply?.addEventListener("click", () => {
    executeFeature(volumeFeature, commandForFeature(volumeFeature, Number(range.value)));
  });
}

export function renderTaskComposer() {
  const features = state.groups.flatMap((group) => group.features);
  const schedulable = features.filter((feature) => feature.control.type === "action" || feature.control.type === "range");
  const selected = elements.taskFeature.value || schedulable[0]?.featureKey || "";

  elements.taskFeature.innerHTML = schedulable.map((feature) => (
    `<option value="${escapeHtml(feature.featureKey)}" ${feature.featureKey === selected ? "selected" : ""}>${escapeHtml(feature.title)}</option>`
  )).join("");

  const selectedFeature = schedulable.find((feature) => feature.featureKey === elements.taskFeature.value);
  elements.taskVolumeField.classList.toggle("hidden", selectedFeature?.control.type !== "range");

  const presets = [
    { label: "5 分钟后关机", minutes: 5, feature: "shutdown" },
    { label: "10 分钟后重启", minutes: 10, feature: "restart" },
    { label: "30 分钟后关机", minutes: 30, feature: "shutdown" },
    { label: "1 分钟后测试提示", minutes: 1, feature: "test_notification" },
  ].filter((preset) => features.some((feature) => feature.featureKey === preset.feature));

  elements.presetList.innerHTML = presets.map((preset) => (
    `<button class="preset-chip" type="button" data-preset-feature="${preset.feature}" data-preset-minutes="${preset.minutes}">${preset.label}</button>`
  )).join("");

  document.querySelectorAll("[data-preset-feature]").forEach((button) => {
    button.addEventListener("click", async () => {
      try {
        await createTask({ feature: button.dataset.presetFeature }, Number(button.dataset.presetMinutes));
      } catch (error) {
        showToast(String(error.message || error));
      }
    });
  });
}

export function renderTasks() {
  elements.taskCountText.textContent = state.tasks.length ? `${state.tasks.length} 个任务等待执行` : "暂无任务";
  if (state.tasks.length === 0) {
    elements.taskList.innerHTML = `<div class="empty-state">队列里还没有任务，添加后会在这里实时出现。</div>`;
    return;
  }

  elements.taskList.innerHTML = state.tasks.map((task) => `
    <article class="list-row">
      <span class="status-badge queued">待执行</span>
      <div class="list-row-main">
        <div class="list-row-title">${escapeHtml(task.title)}</div>
        <div class="list-row-meta">${formatDate(task.executeAtMs)} · ${countdownText(task.executeAtMs)} · ${escapeHtml(task.origin?.clientName ?? "Web 控制台")}</div>
      </div>
      <button class="secondary-button" type="button" data-cancel-task="${escapeHtml(task.taskId)}">停止</button>
    </article>
  `).join("");

  document.querySelectorAll("[data-cancel-task]").forEach((button) => {
    button.addEventListener("click", async () => {
      try {
        await cancelTask(button.dataset.cancelTask);
      } catch (error) {
        showToast(String(error.message || error));
      }
    });
  });
}

export function renderHistory() {
  if (state.history.length === 0) {
    elements.historyList.innerHTML = `<div class="empty-state">还没有执行记录。</div>`;
    return;
  }

  elements.historyList.innerHTML = state.history.slice(0, 80).map((entry) => {
    const status = entry.status ?? "queued";
    return `
      <article class="list-row">
        <span class="status-badge ${escapeHtml(status)}">${statusLabels[status] ?? status}</span>
        <div class="list-row-main">
          <div class="list-row-title">${escapeHtml(entry.title)}</div>
          <div class="list-row-meta">${formatDate(entry.recordedAtMs)} · ${escapeHtml(entry.origin?.clientName ?? "未知来源")}</div>
          <div class="list-row-meta">${escapeHtml(entry.detail ?? "")}</div>
        </div>
      </article>
    `;
  }).join("");
}

export function render() {
  renderActions();
  renderTaskComposer();
  renderTasks();
  renderHistory();
}
