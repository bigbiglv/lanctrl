import { setConnection } from "./dom.js";
import { applyState } from "./render.js";
import { state } from "./state.js";

export function connectWebSocket() {
  window.clearTimeout(state.reconnectTimer);
  window.clearInterval(state.heartbeatTimer);
  setConnection("connecting", "正在建立实时通道");

  const protocol = window.location.protocol === "https:" ? "wss:" : "ws:";
  const socket = new WebSocket(`${protocol}//${window.location.host}/web/ws`);
  state.socket = socket;

  socket.addEventListener("open", () => {
    setConnection("connected", "任务状态会自动刷新");
    socket.send(JSON.stringify({ type: "request_state_sync" }));
    state.heartbeatTimer = window.setInterval(() => {
      if (socket.readyState === WebSocket.OPEN) {
        socket.send(JSON.stringify({ type: "heartbeat" }));
      }
    }, 15_000);
  });

  socket.addEventListener("message", (event) => {
    const payload = JSON.parse(event.data);
    if (payload.type === "state_sync") {
      applyState(payload);
    }
  });

  socket.addEventListener("close", () => {
    setConnection("offline", "3 秒后自动重连");
    window.clearInterval(state.heartbeatTimer);
    state.reconnectTimer = window.setTimeout(connectWebSocket, 3000);
  });

  socket.addEventListener("error", () => {
    setConnection("offline", "实时通道异常");
  });
}
