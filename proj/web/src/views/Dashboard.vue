<template>
  <div class="dashboard-container">
    <div class="header-section">
      <div class="title-area">
        <h2>精密工具智能化库房监控大盘</h2>
        <p class="subtitle">局域网集中校验节点 · 全局资产水位与生命周期监控</p>
      </div>
      <div class="time-badge">
        <span>系统时间: {{ currentTime }}</span>
      </div>
    </div>

    <!-- 1. KPI 看板 -->
    <div class="kpi-grid">
      <div class="kpi-card" v-for="k in kpis" :key="k.name" :style="{ borderLeftColor: k.color }">
        <div class="kpi-label">{{ k.name }}</div>
        <div class="kpi-value" :style="{ color: k.color }">{{ k.value }}</div>
        <div class="kpi-desc">{{ k.desc }}</div>
      </div>
    </div>

    <!-- 2. 中间主面板 -->
    <div class="main-content-grid">
      <!-- 左侧：精密资产动态监控网格 -->
      <div class="panel-card tools-panel">
        <div class="panel-header">
          <h3>🛠️ 在线精密工具监控网格</h3>
        </div>
        <div class="tools-grid">
          <div class="tool-card" v-for="t in tools" :key="t.code" :class="{ 'overdue-card': isOverdue(t) }">
            <div class="card-head">
              <span class="tool-code">{{ t.code }}</span>
              <span class="status-badge" :class="t.status === '在库' ? 'badge-in' : 'badge-out'">
                {{ t.status }}
              </span>
            </div>
            <div class="tool-name">{{ t.name }} ({{ t.model }})</div>
            <div class="tool-loc">位置: {{ t.location }}</div>
            
            <div class="lifespan-sec">
              <div class="life-label">
                <span>寿命使用次数</span>
                <span :style="{ color: getLifeColor(t) }">{{ t.use_count }} / {{ t.lifespan_limit }} 次</span>
              </div>
              <div class="progress-bar-bg">
                <div class="progress-fill" :style="{ width: getLifePct(t) + '%', backgroundColor: getLifeColor(t) }" />
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- 右侧：配件储备 与 局域网同步日志 -->
      <div class="right-column-panel">
        <!-- 配件水位 -->
        <div class="panel-card accessories-panel">
          <div class="panel-header">
            <h3>📦 耗材安全水位监控</h3>
          </div>
          <div class="acc-list">
            <div class="acc-item" v-for="a in accessories" :key="a.barcode" :class="{ 'low-stock-item': a.current_stock < a.safety_stock }">
              <div class="acc-info">
                <div class="acc-name">{{ a.name }}</div>
                <div class="acc-spec">规格: {{ a.spec }}</div>
              </div>
              <div class="acc-stock" :style="{ color: a.current_stock < a.safety_stock ? '#ef4444' : '#10b981' }">
                {{ a.current_stock }} {{ a.unit }}
              </div>
            </div>
          </div>
        </div>

        <!-- 同步校验日志 -->
        <div class="panel-card sync-panel">
          <div class="panel-header">
            <h3>🔄 局域网同步校验日志</h3>
          </div>
          <div class="sync-logs">
            <div class="sync-log-item" v-for="(log, idx) in syncLogs" :key="idx" :class="log.type">
              <div class="log-head">
                <span class="log-tag">{{ log.type === 'success' ? '✅ 对齐成功' : '⚠️ 冲突校验' }}</span>
                <span class="log-time">{{ log.time }}</span>
              </div>
              <div class="log-text">{{ log.text }}</div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script lang="ts">
import { defineComponent, ref, onMounted, onUnmounted } from 'vue';
import { api, Tool, Accessory, SyncLog } from '../api';

export default defineComponent({
  name: 'Dashboard',
  setup() {
    const currentTime = ref(new Date().toLocaleString());
    
    const kpis = ref([
      { name: '资产底座总数', value: 0, desc: '一物一档案', color: '#38bdf8' },
      { name: '基地在库待命', value: 0, desc: '状态机空闲', color: '#10b981' },
      { name: '现场作业工具', value: 0, desc: '已离库流转', color: '#f59e0b' },
      { name: '寿命/异常报警', value: 0, desc: '达到寿命上限或超期', color: '#ef4444' },
      { name: '配件水位预警', value: 0, desc: '低于安全库存量', color: '#c084fc' }
    ]);

    const tools = ref<Tool[]>([]);
    const accessories = ref<Accessory[]>([]);
    const syncLogs = ref<SyncLog[]>([]);

    let timer: any = null;
    let timeTimer: any = null;

    const fetchData = async () => {
      tools.value = await api.getTools();
      accessories.value = await api.getAccessories();
      syncLogs.value = api.getMockSyncLogs();
      updateKPIs();
    };

    const updateKPIs = () => {
      const total = tools.value.length;
      const inStock = tools.value.filter(t => t.status === '在库').length;
      const outStock = tools.value.filter(t => t.status === '离库').length;
      const alertTools = tools.value.filter(t => t.use_count >= t.lifespan_limit || isOverdue(t)).length;
      const lowStockAccs = accessories.value.filter(a => a.current_stock < a.safety_stock).length;

      kpis.value[0].value = total;
      kpis.value[1].value = inStock;
      kpis.value[2].value = outStock;
      kpis.value[3].value = alertTools;
      kpis.value[4].value = lowStockAccs;
    };

    const isOverdue = (t: Tool) => {
      // 如果离库且领用时间超过 30 天则算超期（当前写死 30 天）
      if (t.status === '离库' && t.checkout_time) {
        const checkTime = new Date(t.checkout_time).getTime();
        const now = new Date().getTime();
        const diffDays = (now - checkTime) / (1000 * 60 * 60 * 24);
        return diffDays > 30;
      }
      return false;
    };

    const getLifePct = (t: Tool) => {
      if (t.lifespan_limit <= 0) return 100;
      return Math.min(100, Math.round((t.use_count / t.lifespan_limit) * 100));
    };

    const getLifeColor = (t: Tool) => {
      const pct = getLifePct(t);
      if (pct >= 100) return '#ef4444';
      if (pct >= 80) return '#f59e0b';
      return '#10b981';
    };

    onMounted(() => {
      fetchData();
      timer = setInterval(fetchData, 5000);
      timeTimer = setInterval(() => {
        currentTime.value = new Date().toLocaleString();
      }, 1000);
    });

    onUnmounted(() => {
      if (timer) clearInterval(timer);
      if (timeTimer) clearInterval(timeTimer);
    });

    return {
      currentTime,
      kpis,
      tools,
      accessories,
      syncLogs,
      isOverdue,
      getLifePct,
      getLifeColor
    };
  }
});
</script>

<style scoped>
.dashboard-container {
  display: flex;
  flex-direction: column;
  gap: 20px;
}

.header-section {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.title-area h2 {
  margin: 0;
  font-size: 20px;
  font-weight: 600;
  color: rgba(255,255,255,0.95);
}

.subtitle {
  margin: 4px 0 0;
  font-size: 12px;
  color: rgba(255,255,255,0.5);
}

.time-badge {
  font-size: 12px;
  color: rgba(255,255,255,0.6);
  background: rgba(255,255,255,0.03);
  padding: 6px 12px;
  border-radius: 6px;
  border: 1px solid rgba(255,255,255,0.06);
}

/* KPI 看板 */
.kpi-grid {
  display: grid;
  grid-template-columns: repeat(5, 1fr);
  gap: 15px;
}

.kpi-card {
  background: #121824;
  border: 1px solid rgba(255,255,255,0.06);
  border-left: 3px solid;
  border-radius: 8px;
  padding: 16px;
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.kpi-label {
  font-size: 11px;
  color: rgba(255,255,255,0.5);
}

.kpi-value {
  font-size: 28px;
  font-weight: 700;
}

.kpi-desc {
  font-size: 9px;
  color: rgba(255,255,255,0.3);
}

/* 布局网格 */
.main-content-grid {
  display: grid;
  grid-template-columns: 1fr 320px;
  gap: 20px;
}

.panel-card {
  background: #121824;
  border: 1px solid rgba(255,255,255,0.06);
  border-radius: 10px;
  padding: 20px;
  box-sizing: border-box;
}

.panel-header h3 {
  margin: 0 0 16px 0;
  font-size: 14px;
  font-weight: 600;
  color: rgba(255,255,255,0.85);
}

/* 工具网格 */
.tools-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 12px;
}

.tool-card {
  background: #182030;
  border: 1px solid rgba(255,255,255,0.06);
  border-radius: 8px;
  padding: 12px;
}

.overdue-card {
  border-color: rgba(239, 68, 68, 0.4);
}

.card-head {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.tool-code {
  font-size: 11px;
  font-weight: 700;
  color: rgba(255,255,255,0.5);
}

.status-badge {
  font-size: 9px;
  padding: 2px 6px;
  border-radius: 4px;
  font-weight: bold;
}

.badge-in { background: rgba(16, 185, 129, 0.1); color: #10b981; }
.badge-out { background: rgba(245, 158, 11, 0.1); color: #f59e0b; }

.tool-name {
  font-size: 13px;
  font-weight: 500;
  color: #fff;
  margin-top: 6px;
}

.tool-loc {
  font-size: 11px;
  color: rgba(255,255,255,0.4);
  margin-top: 2px;
}

.lifespan-sec {
  margin-top: 12px;
}

.life-label {
  display: flex;
  justify-content: space-between;
  font-size: 10px;
  margin-bottom: 4px;
  color: rgba(255,255,255,0.5);
}

.progress-bar-bg {
  height: 4px;
  background: rgba(255,255,255,0.06);
  border-radius: 2px;
  overflow: hidden;
}

.progress-fill {
  height: 100%;
  border-radius: 2px;
}

/* 右侧栏目 */
.right-column-panel {
  display: flex;
  flex-direction: column;
  gap: 20px;
}

.acc-list {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.acc-item {
  background: #182030;
  border-radius: 6px;
  padding: 8px 12px;
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.low-stock-item {
  border: 1px solid rgba(239, 68, 68, 0.2);
  background: rgba(239, 68, 68, 0.02);
}

.acc-name {
  font-size: 12px;
  font-weight: 500;
  color: #fff;
}

.acc-spec {
  font-size: 10px;
  color: rgba(255,255,255,0.4);
}

.acc-stock {
  font-size: 13px;
  font-weight: 700;
}

/* 同步日志 */
.sync-logs {
  display: flex;
  flex-direction: column;
  gap: 8px;
  max-height: 200px;
  overflow-y: auto;
}

.sync-log-item {
  background: rgba(255,255,255,0.01);
  border: 1px solid rgba(255,255,255,0.04);
  border-radius: 6px;
  padding: 8px;
  font-size: 11px;
}

.log-head {
  display: flex;
  justify-content: space-between;
  color: rgba(255,255,255,0.4);
  margin-bottom: 2px;
}

.log-tag {
  font-weight: bold;
}

.success .log-tag { color: #10b981; }

.log-text {
  color: rgba(255,255,255,0.7);
  line-height: 1.4;
}
</style>
