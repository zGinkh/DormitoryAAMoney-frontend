import { createRouter, createWebHistory } from 'vue-router'

const routes = [
  {
    path: '/',
    redirect: '/poeples',
  },
  {
    path: '/index',
    name: 'home',
    component: () => import('../views/HomeView.vue'),
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
    path: '/:pathMatch(.*)*',
    redirect: '/poeples',
  },
]

const router = createRouter({
  history: createWebHistory(),
  routes,
})

export default router
