<script setup lang="ts">
</script>

<template>
  <div class="welcome-card glass-panel fade-in">
    <h2>欢迎使用 LanCtrl PC 控制端</h2>
    <p>当前主体组件已经被成功通过 vue-router 加载。各个模块随后将分别接入各自真正的功能界面。</p>
    
    <div class="placeholder-grid">
      <div class="placeholder-box" style="--delay: 1">
        <div class="placeholder-content">系统概览</div>
      </div>
      <div class="placeholder-box" style="--delay: 2">
        <div class="placeholder-content">快捷操作</div>
      </div>
      <div class="placeholder-box" style="--delay: 3">
        <div class="placeholder-content">近期活动</div>
      </div>
    </div>
  </div>
</template>

<style scoped lang="scss">
.welcome-card {
  border-radius: var(--radius-lg);
  padding: 3rem;
  height: 100%;
  display: flex;
  flex-direction: column;
  position: relative;
  overflow: hidden;

  &::after {
    content: '';
    position: absolute;
    top: -50%; right: -50%;
    width: 100%; height: 100%;
    background: radial-gradient(circle, color-mix(in srgb, var(--color-primary-light) 10%, transparent) 0%, transparent 60%);
    pointer-events: none;
  }

  h2 {
    font-size: 2.5rem;
    margin-bottom: 1rem;
    background: linear-gradient(to right, var(--color-white), var(--color-primary-light));
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
  }

  p {
    color: var(--text-muted);
    font-size: 1.1rem;
    max-width: 600px;
    line-height: 1.6;
    margin-bottom: 3rem;
  }

  .placeholder-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
    gap: 1.5rem;

    .placeholder-box {
      height: 160px;
      border-radius: var(--radius-lg);
      background: color-mix(in srgb, var(--color-white) 2%, transparent);
      border: 1px dashed var(--border-color);
      opacity: 0;
      display: flex;
      align-items: center;
      justify-content: center;
      color: var(--text-muted);
      font-weight: 500;
      font-size: 1.1rem;
      transition: all var(--transition-normal);
      animation: slideUp 0.6s var(--transition-normal) forwards;
      animation-delay: calc(var(--delay) * 0.1s + 0.3s);

      &:hover {
        background: color-mix(in srgb, var(--color-white) 4%, transparent);
        border-color: color-mix(in srgb, var(--color-white) 30%, transparent);
        color: var(--text-main);
        transform: translateY(-4px) !important;
        box-shadow: 0 8px 24px color-mix(in srgb, var(--color-black) 20%, transparent);
      }
    }
  }
}
</style>
