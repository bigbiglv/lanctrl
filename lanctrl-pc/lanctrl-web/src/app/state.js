export const state = {
  groups: [],
  snapshot: null,
  tasks: [],
  history: [],
  activeFeatureKey: null,
  socket: null,
  reconnectTimer: 0,
  heartbeatTimer: 0,
};

export const statusLabels = {
  queued: "已排队",
  cancelled: "已停止",
  executed: "已完成",
  failed: "失败",
  manual_executed: "手动完成",
  manual_failed: "手动失败",
};

export function actionFeatures() {
  return state.groups.flatMap((group) => group.features).filter((feature) => feature.control.type === "action");
}

export function rangeFeatures() {
  return state.groups.flatMap((group) => group.features).filter((feature) => feature.control.type === "range");
}

export function commandForFeature(feature, level) {
  if (feature.featureKey === "volume") {
    return { feature: "volume", level };
  }

  return { feature: feature.featureKey };
}
