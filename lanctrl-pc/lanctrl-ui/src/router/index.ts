import { createRouter, createWebHistory } from 'vue-router'
import Layout from '../components/layout/index.vue'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    {
      path: '/',
      component: Layout,
      children: [
        {
          path: '',
          name: 'Dashboard',
          component: () => import('../views/DashboardView.vue'),
          meta: { title: '控制面板' }
        },
        {
          path: 'devices',
          name: 'Devices',
          component: () => import('../views/DevicesView.vue'),
          meta: { title: '授权设备' }
        },
        {
          path: 'tasks',
          name: 'Tasks',
          component: () => import('../views/TasksView.vue'),
          meta: { title: '定时任务' }
        },
        {
          path: 'share',
          name: 'Share',
          component: () => import('../views/ShareView.vue'),
          meta: { title: '共享目录' }
        },
        {
          path: 'logs',
          name: 'Logs',
          component: () => import('../views/LogsView.vue'),
          meta: { title: '日志审计' }
        },
        {
          path: 'settings',
          name: 'Settings',
          component: () => import('../views/SettingsView.vue'),
          meta: { title: '系统设置' }
        }
      ]
    }
  ]
})

export default router
