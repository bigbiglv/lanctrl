export async function requestJson(path, options = {}) {
  const response = await fetch(path, {
    headers: { "Content-Type": "application/json" },
    ...options,
  });
  if (!response.ok) {
    throw new Error(`请求失败：${response.status}`);
  }
  return response.json();
}

export async function fetchState() {
  const payload = await requestJson("/web/api/state");
  if (!payload.success) {
    throw new Error(payload.msg || "状态刷新失败");
  }
  return payload;
}

export async function executeCommand(command) {
  return requestJson("/web/api/features/execute", {
    method: "POST",
    body: JSON.stringify(command),
  });
}

export async function createScheduledTask(command, delayMinutes) {
  const executeAtMs = Date.now() + Number(delayMinutes) * 60 * 1000;
  return requestJson("/web/api/tasks/create", {
    method: "POST",
    body: JSON.stringify({ execute_at_ms: executeAtMs, ...command }),
  });
}

export async function cancelScheduledTask(taskId) {
  return requestJson("/web/api/tasks/cancel", {
    method: "POST",
    body: JSON.stringify({ task_id: taskId }),
  });
}
