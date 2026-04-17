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
          component: () => import('../views/dashboard/index.vue'),
          meta: { title: '控制台' }
        },
        {
          path: 'pending-tasks',
          name: 'PendingTasks',
          component: () => import('../views/pending-tasks/index.vue'),
          meta: { title: '待处理任务' }
        },
        {
          path: 'task-history',
          name: 'TaskHistory',
          component: () => import('../views/task-history/index.vue'),
          meta: { title: '任务记录' }
        },
        {
          path: 'connected-devices',
          name: 'ConnectedDevices',
          component: () => import('../views/connected-devices/index.vue'),
          meta: { title: '已连接设备' }
        }
      ]
    }
  ]
})

export default router
