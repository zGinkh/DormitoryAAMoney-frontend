import { createRouter, createWebHistory } from 'vue-router'

const routes = [
  {
    path: '/',
    redirect: '/index',
  },
  {
    path: '/index',
    name: 'home',
    component: () => import('../views/HomeView.vue'),
    meta: { section: 'bill-entry' },
  },
  {
    path: '/result',
    name: 'result',
    component: () => import('../views/ResultView.vue'),
    meta: { section: 'bill-entry' },
  },
  {
    path: '/peoples',
    redirect: '/poeples',
  },
  {
    path: '/poeples',
    name: 'peopleManage',
    component: () => import('../views/PeopleManageView.vue'),
    meta: { section: 'people' },
  },
  {
    path: '/history',
    name: 'history',
    component: () => import('../views/HistoryView.vue'),
    meta: { section: 'history' },
  },
  {
    path: '/history/:id',
    name: 'historyDetail',
    component: () => import('../views/HistoryDetailView.vue'),
    meta: { section: 'history' },
  },
  {
    path: '/guide',
    name: 'guide',
    component: () => import('../views/UsageGuideView.vue'),
    meta: { section: 'guide' },
  },
  {
    path: '/:pathMatch(.*)*',
    redirect: '/index',
  },
]

const router = createRouter({
  history: createWebHistory(),
  routes,
})

export default router
