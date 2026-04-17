<script setup lang="ts">

const menuItems = [
  { path: '/', label: '控制台', icon: '◱' },
  { path: '/pending-tasks', label: '待处理任务', icon: '⏱' },
  { path: '/task-history', label: '任务记录', icon: '📋' },
  { path: '/connected-devices', label: '已连接设备', icon: '💻' },
]
</script>

<template>
  <aside class="sidebar glass-panel fade-in">
    <div class="logo">
      <div class="logo-icon"></div>
      <h1>LanCtrl</h1>
      <span class="version">v1.0</span>
    </div>
    
    <nav class="nav-menu">
      <router-link
        v-for="item in menuItems" 
        :key="item.path" 
        :to="item.path"
        class="nav-item"
        exact-active-class="active"
      >
        <span class="icon">{{ item.icon }}</span>
        <span class="label">{{ item.label }}</span>
      </router-link>
    </nav>
    
    <div class="sidebar-footer">
      <div class="status-indicator online">
        <span class="dot"></span>服务运行中
      </div>
    </div>
  </aside>
</template>

<style scoped lang="scss">
.sidebar {
  width: 260px;
  border-radius: var(--radius-xl);
  display: flex;
  flex-direction: column;
  padding: 1.5rem;
  position: relative;
  overflow: hidden;

  &::before {
    content: '';
    position: absolute;
    top: 0; left: 0; right: 0; height: 100px;
    background: radial-gradient(circle at top left, color-mix(in srgb, var(--color-primary) 15%, transparent), transparent);
    pointer-events: none;
  }
}

.logo {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  margin-bottom: 2.5rem;

  .logo-icon {
    width: 32px;
    height: 32px;
    border-radius: 8px;
    background: linear-gradient(135deg, var(--color-primary), var(--color-primary-dark));
    box-shadow: 0 4px 12px color-mix(in srgb, var(--color-primary) 40%, transparent);
  }

  h1 {
    font-size: 1.25rem;
    font-weight: 700;
    letter-spacing: -0.5px;
  }

  .version {
    font-size: 0.7rem;
    padding: 0.2rem 0.4rem;
    border-radius: 4px;
    background: color-mix(in srgb, var(--color-white) 10%, transparent);
    margin-left: auto;
  }
}

.nav-menu {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  flex: 1;

  .nav-item {
    display: flex;
    align-items: center;
    gap: 1rem;
    padding: 0.875rem 1rem;
    border-radius: var(--radius-md);
    color: var(--text-muted);
    text-decoration: none;
    font-weight: 500;
    transition: all var(--transition-normal);
    position: relative;
    overflow: hidden;

    &::before {
      content: '';
      position: absolute;
      left: 0; top: 0; bottom: 0; width: 4px;
      background: var(--color-primary);
      transform: scaleY(0);
      transition: transform var(--transition-fast);
      border-radius: 0 var(--radius-sm) var(--radius-sm) 0;
    }

    &:hover {
      color: var(--text-main);
      background: var(--panel-hover-bg);
      transform: translateX(4px);

      .icon {
        transform: scale(1.1);
        color: var(--color-primary-light);
      }
    }

    &.active {
      color: var(--text-main);
      background: linear-gradient(90deg, color-mix(in srgb, var(--color-primary) 10%, transparent) 0%, transparent 100%);

      &::before {
        transform: scaleY(1);
      }

      .icon {
        transform: scale(1.1);
        color: var(--color-primary-light);
      }
    }

    .icon {
      font-size: 1.25rem;
      opacity: 0.8;
      transition: transform var(--transition-fast);
    }
  }
}

.sidebar-footer {
  margin-top: auto;
  padding-top: 1.5rem;
  border-top: 1px solid var(--border-color);

  .status-indicator {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-size: 0.875rem;
    color: var(--text-muted);

    .dot {
      width: 8px;
      height: 8px;
      border-radius: 50%;
      background: var(--color-success);
      box-shadow: 0 0 12px var(--color-success);
      animation: pulse 2s infinite;
    }
  }
}

@keyframes pulse {
  0% { transform: scale(0.95); box-shadow: 0 0 0 0 color-mix(in srgb, var(--color-success) 40%, transparent); }
  70% { transform: scale(1); box-shadow: 0 0 0 6px transparent; }
  100% { transform: scale(0.95); box-shadow: 0 0 0 0 transparent; }
}
</style>
