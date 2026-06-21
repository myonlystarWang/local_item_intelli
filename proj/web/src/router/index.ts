import { createRouter, createWebHashHistory } from 'vue-router';
import Dashboard from '../views/Dashboard.vue';
import Lifecycle from '../views/Lifecycle.vue';

const routes = [
  {
    path: '/',
    redirect: '/dashboard'
  },
  {
    path: '/dashboard',
    name: 'Dashboard',
    component: Dashboard
  },
  {
    path: '/lifecycle',
    name: 'Lifecycle',
    component: Lifecycle
  }
];

const router = createRouter({
  history: createWebHashHistory(),
  routes
});

export default router;
