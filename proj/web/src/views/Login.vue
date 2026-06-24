<template>
  <div class="login-page">
    <div class="glow-bg">
      <div class="glow-orb orb-1"></div>
      <div class="glow-orb orb-2"></div>
    </div>
    
    <div class="login-card">
      <div class="login-header">
        <div class="system-icon">
          <div class="logo-inner"></div>
        </div>
        <h1 class="system-title">精密工具智能化管理系统</h1>
        <p class="system-subtitle">库房端管理中枢 · 身份凭证鉴权</p>
      </div>

      <el-form :model="loginForm" :rules="rules" ref="loginFormRef" class="login-form">
        <el-form-item prop="username">
          <el-input 
            v-model="loginForm.username" 
            placeholder="库管员账号"
            :prefix-icon="User"
            class="custom-input"
            clearable
          />
        </el-form-item>
        <el-form-item prop="password">
          <el-input 
            v-model="loginForm.password" 
            type="password" 
            placeholder="登录密码"
            :prefix-icon="Lock"
            show-password
            class="custom-input"
            @keyup.enter="handleLogin"
          />
        </el-form-item>

        <el-button 
          type="primary" 
          :loading="loading" 
          class="login-button"
          @click="handleLogin"
        >
          登 录
        </el-button>
      </el-form>

      <div class="login-footer">
        <span>安全级别：高强度 JWT 强算法加密</span>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive } from 'vue'
import { useRouter } from 'vue-router'
import { User, Lock } from '@element-plus/icons-vue'
import { ElMessage } from 'element-plus'
import type { FormInstance } from 'element-plus'
import { api } from '../api'

const router = useRouter()
const loginFormRef = ref<FormInstance>()
const loading = ref(false)

const loginForm = reactive({
  username: '',
  password: ''
})

const rules = {
  username: [
    { required: true, message: '请输入库管员账号', trigger: 'blur' }
  ],
  password: [
    { required: true, message: '请输入登录密码', trigger: 'blur' }
  ]
}

const handleLogin = async () => {
  if (!loginFormRef.value) return
  
  await loginFormRef.value.validate(async (valid) => {
    if (valid) {
      loading.value = true
      try {
        const res = await api.login({
          username: loginForm.username.trim(),
          password: loginForm.password
        })
        
        // 保存 Token 和用户信息
        localStorage.setItem('access_token', res.access_token)
        localStorage.setItem('user', JSON.stringify(res.user))
        
        ElMessage({
          message: '登录成功，正在加载中枢台账',
          type: 'success',
          duration: 1500
        })
        
        // 延迟跳转，提供更好的过渡体验
        setTimeout(() => {
          router.push('/dashboard')
        }, 800)
      } catch (err: any) {
        // 请求失败会在 axios 拦截器中统一报错弹窗，此处只需取消 loading 态
        console.error('Login failed:', err)
      } finally {
        loading.value = false
      }
    }
  })
}
</script>

<style scoped>
.login-page {
  position: relative;
  width: 100vw;
  height: 100vh;
  display: flex;
  justify-content: center;
  align-items: center;
  background-color: #0b0f17;
  overflow: hidden;
}

/* 渐变流光背景 */
.glow-bg {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  z-index: 1;
}

.glow-orb {
  position: absolute;
  border-radius: 50%;
  filter: blur(100px);
  opacity: 0.3;
  mix-blend-mode: screen;
}

.orb-1 {
  top: -10%;
  left: -10%;
  width: 50vw;
  height: 50vw;
  background: radial-gradient(circle, #00f2fe 0%, transparent 70%);
  animation: floatOrb 12s infinite alternate;
}

.orb-2 {
  bottom: -10%;
  right: -10%;
  width: 50vw;
  height: 50vw;
  background: radial-gradient(circle, #4facfe 0%, transparent 70%);
  animation: floatOrb 15s infinite alternate-reverse;
}

@keyframes floatOrb {
  0% {
    transform: translate(0, 0) scale(1);
  }
  100% {
    transform: translate(5%, 10%) scale(1.1);
  }
}

/* 磨砂玻璃卡片 */
.login-card {
  position: relative;
  z-index: 10;
  width: 420px;
  background: rgba(22, 27, 34, 0.65);
  backdrop-filter: blur(20px);
  -webkit-backdrop-filter: blur(20px);
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 16px;
  padding: 40px;
  box-shadow: 0 20px 50px rgba(0, 0, 0, 0.5), 
              inset 0 0 20px rgba(255, 255, 255, 0.02);
  box-sizing: border-box;
}

.login-header {
  display: flex;
  flex-direction: column;
  align-items: center;
  margin-bottom: 35px;
}

.system-icon {
  width: 54px;
  height: 54px;
  background: linear-gradient(135deg, #00f2fe 0%, #4facfe 100%);
  border-radius: 12px;
  display: flex;
  justify-content: center;
  align-items: center;
  box-shadow: 0 0 20px rgba(0, 242, 254, 0.4);
  margin-bottom: 16px;
}

.logo-inner {
  width: 24px;
  height: 24px;
  background: #ffffff;
  border-radius: 50%;
  opacity: 0.9;
  position: relative;
}

.logo-inner::after {
  content: '';
  position: absolute;
  top: 4px;
  left: 4px;
  width: 8px;
  height: 8px;
  background: #0b0f17;
  border-radius: 50%;
}

.system-title {
  font-size: 20px;
  font-weight: 700;
  color: #ffffff;
  margin: 0 0 8px 0;
  letter-spacing: 1px;
}

.system-subtitle {
  font-size: 13px;
  color: #8b949e;
  margin: 0;
}

/* 自定义输入框样式 */
.custom-input :deep(.el-input__wrapper) {
  background-color: rgba(13, 17, 23, 0.6) !important;
  border: 1px solid rgba(255, 255, 255, 0.1);
  box-shadow: none !important;
  transition: all 0.3s;
  height: 44px;
  border-radius: 8px;
  padding: 0 14px;
}

.custom-input :deep(.el-input__wrapper.is-focus),
.custom-input :deep(.el-input__wrapper:hover) {
  border-color: #00f2fe !important;
  box-shadow: 0 0 10px rgba(0, 242, 254, 0.15) !important;
}

.custom-input :deep(.el-input__inner) {
  color: #f0f6fc !important;
  font-size: 14px;
}

.custom-input :deep(.el-input__inner::placeholder) {
  color: rgba(255, 255, 255, 0.3);
}

.custom-input :deep(.el-input__prefix-icon) {
  color: rgba(255, 255, 255, 0.5) !important;
  font-size: 16px;
}

/* 登录按钮 */
.login-button {
  width: 100%;
  height: 44px;
  background: linear-gradient(90deg, #00f2fe 0%, #4facfe 100%) !important;
  border: none !important;
  border-radius: 8px !important;
  color: #0d1117 !important;
  font-weight: 600 !important;
  font-size: 15px !important;
  letter-spacing: 4px;
  cursor: pointer;
  transition: all 0.3s;
  box-shadow: 0 4px 15px rgba(79, 172, 254, 0.3);
  margin-top: 10px;
}

.login-button:hover {
  opacity: 0.95;
  box-shadow: 0 4px 20px rgba(0, 242, 254, 0.5);
  transform: translateY(-1px);
}

.login-button:active {
  transform: translateY(0);
}

.login-footer {
  text-align: center;
  margin-top: 25px;
  font-size: 11px;
  color: rgba(255, 255, 255, 0.35);
}
</style>
