import { createRouter, createWebHashHistory } from 'vue-router';
import Dashboard from '../views/Dashboard.vue';
import Lifecycle from '../views/Lifecycle.vue';
import Accessories from '../views/Accessories.vue';
import Dictionaries from '../views/Dictionaries.vue';
import Login from '../views/Login.vue';
import Devices from '../views/Devices.vue';

const routes = [
  {
    path: '/',
    redirect: '/dashboard'
  },
  {
    path: '/login',
    name: 'Login',
    component: Login,
    meta: { plainLayout: true }
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
  },
  {
    path: '/devices',
    name: 'Devices',
    component: Devices
  }
];

const router = createRouter({
  history: createWebHashHistory(),
  routes
});

router.beforeEach((to, _from, next) => {
  const token = localStorage.getItem('access_token');
  if (to.path !== '/login' && !token) {
    next('/login');
  } else if (to.path === '/login' && token) {
    next('/dashboard');
  } else {
    next();
  }
});

export default router;
