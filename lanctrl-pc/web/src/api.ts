import type {
  FeatureCommand,
  FeatureExecuteResponse,
  TaskCreateResponse,
  WebStateResponse,
} from "./types";

async function requestJson<T>(path: string, options: RequestInit = {}): Promise<T> {
  let response: Response;
  try {
    response = await fetch(path, {
      headers: { "Content-Type": "application/json" },
      ...options,
    });
  } catch {
    throw new Error("连接失败");
  }

  if (!response.ok) {
    throw new Error(`请求失败：${response.status}`);
  }

  try {
    return await response.json() as T;
  } catch {
    throw new Error("响应格式异常");
  }
}

export async function fetchState() {
  const payload = await requestJson<WebStateResponse>("/web/api/state");
  if (!payload.success) {
    throw new Error(payload.msg || "状态刷新失败");
  }
  return payload;
}

export function executeCommand(command: FeatureCommand) {
  return requestJson<FeatureExecuteResponse>("/web/api/features/execute", {
    method: "POST",
    body: JSON.stringify(command),
  });
}

export function createScheduledTask(command: FeatureCommand, delayMs: number) {
  const executeAtMs = Date.now() + delayMs;
  return requestJson<TaskCreateResponse>("/web/api/tasks/create", {
    method: "POST",
    body: JSON.stringify({ execute_at_ms: executeAtMs, ...command }),
  });
}

export function cancelScheduledTask(taskId: string) {
  return requestJson<TaskCreateResponse>("/web/api/tasks/cancel", {
    method: "POST",
    body: JSON.stringify({ task_id: taskId }),
  });
}
