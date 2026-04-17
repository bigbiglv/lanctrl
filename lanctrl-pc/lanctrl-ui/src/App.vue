<script setup lang="ts">
import { ref } from 'vue'

const menuItems = [
  { id: 'dashboard', label: '控制面板', icon: '◱' },
  { id: 'devices', label: '授权设备', icon: '💻' },
  { id: 'tasks', label: '定时任务', icon: '⏱' },
  { id: 'share', label: '共享目录', icon: '📁' },
  { id: 'logs', label: '日志审计', icon: '📋' },
  { id: 'settings', label: '系统设置', icon: '⚙' },
]

const activeMenu = ref('dashboard')
</script>

<template>
  <div class="app-layout">
    <!-- 左侧边栏结构 -->
    <aside class="sidebar glass-panel fade-in">
      <div class="logo">
        <div class="logo-icon"></div>
        <h1>LanCtrl</h1>
        <span class="version">v1.0</span>
      </div>
      
      <nav class="nav-menu">
        <a 
          v-for="item in menuItems" 
          :key="item.id" 
          href="#"
          :class="['nav-item', { active: activeMenu === item.id }]"
          @click.prevent="activeMenu = item.id"
        >
          <span class="icon">{{ item.icon }}</span>
          <span class="label">{{ item.label }}</span>
        </a>
      </nav>
      
      <div class="sidebar-footer">
        <div class="status-indicator online">
          <span class="dot"></span>服务运行中
        </div>
      </div>
    </aside>

    <!-- 主体内容结构 -->
    <main class="main-content">
      <header class="top-bar glass-panel fade-in" style="animation-delay: 0.1s;">
        <div class="breadcrumb">
          <span>LanCtrl</span>
          <span class="separator">/</span>
          <span class="current">{{ menuItems.find(i => i.id === activeMenu)?.label }}</span>
        </div>
        <div class="user-actions">
          <button class="icon-btn">🔔</button>
        </div>
      </header>
      
      <div class="content-area">
        <div class="welcome-card glass-panel fade-in" style="animation-delay: 0.2s;">
          <h2>欢迎使用 LanCtrl PC 控制端</h2>
          <p>当前界面为初始化空壳UI框架，各功能模块将在后续迭代中接入。</p>
          
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
      </div>
    </main>
  </div>
</template>

<style scoped lang="scss">
/* Layout */
.app-layout {
  display: flex;
  width: 100%;
  height: 100%;
  padding: 1.5rem;
  gap: 1.5rem;
}

/* Sidebar */
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

/* Main Content */
.main-content {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
}

.top-bar {
  height: 64px;
  border-radius: var(--radius-lg);
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 1.5rem;

  .breadcrumb {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-weight: 500;
    color: var(--text-muted);

    .current {
      color: var(--text-main);
    }

    .separator {
      opacity: 0.5;
    }
  }

  .user-actions {
    .icon-btn {
      background: transparent;
      border: none;
      color: var(--text-main);
      font-size: 1.25rem;
      cursor: pointer;
      width: 40px;
      height: 40px;
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      transition: background var(--transition-fast);

      &:hover {
        background: color-mix(in srgb, var(--color-white) 10%, transparent);
      }
    }
  }
}

.content-area {
  flex: 1;
  border-radius: var(--radius-lg);
  overflow: hidden;
  position: relative;

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
}

@keyframes pulse {
  0% { transform: scale(0.95); box-shadow: 0 0 0 0 color-mix(in srgb, var(--color-success) 40%, transparent); }
  70% { transform: scale(1); box-shadow: 0 0 0 6px transparent; }
  100% { transform: scale(0.95); box-shadow: 0 0 0 0 transparent; }
}
</style>
