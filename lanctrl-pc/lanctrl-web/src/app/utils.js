export function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

export function formatDate(ms) {
  return new Intl.DateTimeFormat("zh-CN", {
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
  }).format(new Date(ms));
}

export function countdownText(ms) {
  const diff = ms - Date.now();
  if (diff <= 0) {
    return "即将执行";
  }

  const seconds = Math.max(1, Math.floor(diff / 1000));
  const minutes = Math.floor(seconds / 60);
  const hours = Math.floor(minutes / 60);
  if (hours >= 1) {
    return `${hours} 小时后`;
  }
  if (minutes >= 1) {
    return `${minutes} 分钟后`;
  }
  return `${Math.min(seconds, 59)} 秒后`;
}
