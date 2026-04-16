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
