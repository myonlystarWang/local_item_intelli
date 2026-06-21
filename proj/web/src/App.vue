<script setup lang="ts">
import { ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { Monitor, Document } from '@element-plus/icons-vue'

const route = useRoute()
const router = useRouter()
const activeMenu = ref('/dashboard')

// 监听路由改变高亮菜单
watch(
  () => route.path,
  (path) => {
    if (path === '/') {
      activeMenu.value = '/dashboard'
    } else {
      activeMenu.value = path
    }
  },
  { immediate: true }
)

const handleSelect = (key: string) => {
  router.push(key)
}
</script>

<template>
  <el-container class="app-container">
    <el-aside width="240px" class="aside-menu">
      <div class="logo-area">
        <div class="logo-icon"></div>
        <span class="logo-text">精密工具智能中枢</span>
      </div>
      
      <el-menu
        :default-active="activeMenu"
        class="el-menu-vertical"
        background-color="transparent"
        text-color="rgba(255, 255, 255, 0.7)"
        active-text-color="#409eff"
        @select="handleSelect"
      >
        <el-menu-item index="/dashboard">
          <el-icon><Monitor /></el-icon>
          <span>监控驾驶大盘</span>
        </el-menu-item>
        <el-menu-item index="/lifecycle">
          <el-icon><Document /></el-icon>
          <span>寿命生命周期档案</span>
        </el-menu-item>
      </el-menu>
      
      <div class="aside-footer">
        <el-tag size="small" type="success" effect="dark" round>局域网同步已就绪</el-tag>
      </div>
    </el-aside>
    
    <el-container>
      <el-header class="app-header">
        <div class="header-left">
          <h2>{{ route.path === '/lifecycle' ? '寿命生命周期档案' : '监控驾驶大盘' }}</h2>
        </div>
        <div class="header-right">
          <div class="system-time">
            <span class="pulse-dot"></span>
            局域网节点: <span class="ip-addr">127.0.0.1:8000</span>
          </div>
        </div>
      </el-header>
      
      <el-main class="app-main">
        <router-view v-slot="{ Component }">
          <transition name="fade-transform" mode="out-in">
            <component :is="Component" />
          </transition>
        </router-view>
      </el-main>
    </el-container>
  </el-container>
</template>

<style>
/* 全局基础重置与滚动条样式 */
body {
  margin: 0;
  font-family: 'Inter', -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
  background-color: #0d1117;
  color: #c9d1d9;
  overflow: hidden;
  height: 100vh;
}

/* 滚动条美化 */
::-webkit-scrollbar {
  width: 6px;
  height: 6px;
}
::-webkit-scrollbar-track {
  background: rgba(0, 0, 0, 0.1);
}
::-webkit-scrollbar-thumb {
  background: rgba(255, 255, 255, 0.15);
  border-radius: 3px;
}
::-webkit-scrollbar-thumb:hover {
  background: rgba(255, 255, 255, 0.3);
}

.app-container {
  height: 100vh;
  background-color: #0b0f17;
}

/* 侧边菜单样式 */
.aside-menu {
  background: linear-gradient(180deg, #161b22 0%, #0d1117 100%);
  border-right: 1px solid rgba(255, 255, 255, 0.05);
  display: flex;
  flex-direction: column;
  padding: 20px 0;
}

.logo-area {
  display: flex;
  align-items: center;
  padding: 0 24px;
  margin-bottom: 30px;
}

.logo-icon {
  width: 32px;
  height: 32px;
  background: linear-gradient(135deg, #00f2fe 0%, #4facfe 100%);
  border-radius: 8px;
  margin-right: 12px;
  box-shadow: 0 0 15px rgba(79, 172, 254, 0.5);
  position: relative;
}

.logo-icon::after {
  content: '';
  position: absolute;
  top: 8px;
  left: 8px;
  width: 16px;
  height: 16px;
  background: #ffffff;
  border-radius: 50%;
  opacity: 0.8;
}

.logo-text {
  font-size: 16px;
  font-weight: 700;
  letter-spacing: 0.5px;
  background: linear-gradient(to right, #ffffff, #8b949e);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
}

.el-menu-vertical {
  border-right: none !important;
  flex-grow: 1;
}

.el-menu-vertical .el-menu-item {
  height: 50px;
  line-height: 50px;
  margin: 4px 16px;
  border-radius: 8px;
  padding: 0 16px !important;
  transition: all 0.3s;
}

.el-menu-vertical .el-menu-item:hover {
  background-color: rgba(255, 255, 255, 0.05) !important;
  color: #ffffff !important;
}

.el-menu-vertical .el-menu-item.is-active {
  background: linear-gradient(90deg, rgba(64, 158, 255, 0.15) 0%, rgba(64, 158, 255, 0.02) 100%) !important;
  border-left: 3px solid #409eff;
  font-weight: bold;
  color: #ffffff !important;
}

.aside-footer {
  padding: 0 24px;
  text-align: center;
}

/* 顶部 Header 样式 */
.app-header {
  background-color: #161b22;
  border-bottom: 1px solid rgba(255, 255, 255, 0.05);
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 30px;
  height: 70px !important;
}

.header-left h2 {
  margin: 0;
  font-size: 20px;
  font-weight: 600;
  color: #f0f6fc;
}

.header-right {
  display: flex;
  align-items: center;
}

.system-time {
  font-size: 13px;
  color: #8b949e;
  background-color: rgba(255, 255, 255, 0.03);
  padding: 6px 14px;
  border-radius: 20px;
  border: 1px solid rgba(255, 255, 255, 0.05);
  display: flex;
  align-items: center;
}

.pulse-dot {
  width: 8px;
  height: 8px;
  background-color: #3fb950;
  border-radius: 50%;
  margin-right: 8px;
  box-shadow: 0 0 8px #3fb950;
  animation: pulse 2s infinite;
}

.ip-addr {
  color: #58a6ff;
  margin-left: 4px;
  font-family: monospace;
}

.app-main {
  background-color: #0d1117;
  padding: 30px;
  overflow-y: auto;
}

/* 页面切换动画 */
.fade-transform-enter-active,
.fade-transform-leave-active {
  transition: all 0.3s ease;
}

.fade-transform-enter-from {
  opacity: 0;
  transform: translateX(-15px);
}

.fade-transform-leave-to {
  opacity: 0;
  transform: translateX(15px);
}

@keyframes pulse {
  0% {
    transform: scale(0.95);
    box-shadow: 0 0 0 0 rgba(63, 185, 80, 0.7);
  }
  70% {
    transform: scale(1);
    box-shadow: 0 0 0 6px rgba(63, 185, 80, 0);
  }
  100% {
    transform: scale(0.95);
    box-shadow: 0 0 0 0 rgba(63, 185, 80, 0);
  }
}
</style>
