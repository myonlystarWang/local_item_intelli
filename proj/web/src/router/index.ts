import { createRouter, createWebHashHistory } from 'vue-router';
import Dashboard from '../views/Dashboard.vue';
import Lifecycle from '../views/Lifecycle.vue';
import Accessories from '../views/Accessories.vue';
import Dictionaries from '../views/Dictionaries.vue';

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
  },
  {
    path: '/accessories',
    name: 'Accessories',
    component: Accessories
  },
  {
    path: '/dictionaries',
    name: 'Dictionaries',
    component: Dictionaries
  }
];

const router = createRouter({
  history: createWebHashHistory(),
  routes
});

export default router;
