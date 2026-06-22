<template>
  <div class="lifecycle-container">
    <div class="lifecycle-main-grid">
      <!-- 1. 精密资产表格主台账 -->
      <div class="panel-card table-panel">
        <div class="table-header-section">
          <h3>📋 精密工具数据台账主表</h3>
          
          <!-- 动作按钮组 (批量导入、手动建档、报表导出) -->
          <div class="action-btn-group">
            <button class="ghost-btn" @click="showImport = true">
              📊 Excel 批量导入
            </button>
            <button class="primary-btn" @click="showCreate = true">
              ➕ 资产建档入库
            </button>
            <button class="primary-btn" @click="showCreateAccessory = true">
              ➕ 配件新规建档
            </button>
            <button class="ghost-btn" @click="showDict = true">
              井号字典增补
            </button>
            
            <div class="export-dropdown-wrapper">
              <button class="export-btn" @click="toggleExportMenu">
                📥 导出审计报表 <i class="chevron-icon">▼</i>
              </button>
              <div class="dropdown-menu" v-if="exportMenuVisible">
                <div class="menu-item" @click="triggerExport('assets')">工具资产总表 (.xlsx)</div>
                <div class="menu-item" @click="triggerExport('accessories')">配件库存台账 (.xlsx)</div>
                <div class="menu-item" @click="triggerExport('logs')">履历审计日志 (.xlsx)</div>
              </div>
            </div>
          </div>
        </div>

        <table class="custom-table">
          <thead>
            <tr>
              <th>唯一识别码</th>
              <th>设备名称</th>
              <th>规格型号</th>
              <th>当前状态</th>
              <th>已用/上限</th>
              <th>存放位置</th>
            </tr>
          </thead>
          <tbody>
            <tr 
              v-for="t in tools" 
              :key="t.code" 
              :class="{ 'row-selected': selectedCode === t.code }"
              @click="selectedCode = t.code"
            >
              <td class="code-col">{{ t.code }}</td>
              <td>{{ t.name }}</td>
              <td>{{ t.model }}</td>
              <td>
                <span class="badge" :class="t.status === '在库' ? 'badge-in' : 'badge-out'">
                  {{ t.status }}
                </span>
              </td>
              <td>{{ t.use_count }} / {{ t.lifespan_limit }} 次</td>
              <td>{{ t.location }}</td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- 2. 右侧全生命周期时间轴履历 -->
      <div class="panel-card history-panel" v-if="selectedTool">
        <div class="history-header">
          <div class="drawer-label">一物一档 · 生命周期履历追溯</div>
          <h4>{{ selectedTool.name }}</h4>
          <div class="tool-sub-desc">识别码: {{ selectedTool.code }} | 型号: {{ selectedTool.model }}</div>
        </div>

        <div class="history-metrics">
          <div class="metric-box">
            <span class="metric-label">寿命已下井数</span>
            <span class="metric-val" :style="{ color: selectedTool.use_count >= selectedTool.lifespan_limit ? '#ef4444' : '#fff' }">
              {{ selectedTool.use_count }} / {{ selectedTool.lifespan_limit }} 次
            </span>
          </div>
          <div class="metric-box">
            <span class="metric-label">最近责任人</span>
            <span class="metric-val">{{ selectedTool.operator || '无' }}</span>
          </div>
        </div>

        <!-- 履历时间轴 (Timeline) -->
        <div class="timeline-area">
          <div class="timeline-item" v-for="(h, idx) in selectedToolHistories" :key="h.id || idx">
            <div class="node-bullet" :class="{ 'node-active': idx === 0 }" />
            <div class="node-time">{{ h.timestamp }}</div>
            <div class="node-title">
              {{ h.type }} 
              <span class="node-op">({{ h.operator }})</span>
            </div>
            <div class="node-detail">{{ h.detail }}</div>
          </div>
          <div class="no-history" v-if="selectedToolHistories.length === 0">
            暂无该精密工具流转历史记录。
          </div>
        </div>
      </div>
    </div>

    <!-- Excel 批量导入弹窗 -->
    <div class="modal-overlay" v-if="showImport">
      <div class="modal-card">
        <h4>📊 Excel 批量数据建档导入</h4>
        <div class="drop-zone" @click="mockSelectFile">
          <span class="drop-icon">📄</span>
          <span class="drop-text" v-if="!importedFile">点击模拟选择 <b>精密工具总账.xlsx</b> 文件</span>
          <span class="drop-text file-ready" v-else>{{ importedFile }} (已就绪)</span>
        </div>
        <div class="progress-bar-wrapper" v-if="importProgress > 0">
          <div class="progress-label">解析进度: {{ importProgress }}%</div>
          <div class="progress-track">
            <div class="progress-thumb" :style="{ width: importProgress + '%' }" />
          </div>
        </div>
        <div class="modal-actions">
          <button class="primary-btn" @click="triggerBatchImport">开始导入</button>
          <button class="ghost-btn" @click="closeImport">取消</button>
        </div>
      </div>
    </div>

    <!-- 手动建档入库弹窗 -->
    <div class="modal-overlay" v-if="showCreate">
      <div class="modal-card form-card">
        <h4>🚀 精密工具手动新购建档</h4>
        <div class="form-item">
          <label>唯一识别编码 (物理浅表打标刻码)</label>
          <input type="text" v-model="newTool.code" placeholder="如 TL-MT-088-A" />
        </div>
        <div class="form-item">
          <label>设备名称</label>
          <input type="text" v-model="newTool.name" list="preset-tool-names" placeholder="选择或手动输入工具名称，如：阿瓦隆桥塞" />
          <datalist id="preset-tool-names">
            <option v-for="name in existingToolNames" :key="name" :value="name" />
          </datalist>
        </div>
        <div class="form-item">
          <label>规格型号描述</label>
          <input type="text" v-model="newTool.model" placeholder="如 E-Setter 3.0" />
        </div>
        <div class="form-item">
          <label>初始寿命极限次数</label>
          <input type="number" v-model="newTool.lifespanLimit" />
        </div>
        <div class="modal-actions">
          <button class="primary-btn" @click="submitManualCreate">确认保存</button>
          <button class="ghost-btn" @click="showCreate = false">取消</button>
        </div>
      </div>
    </div>

    <!-- 零配件手动新购建档弹窗 -->
    <div class="modal-overlay" v-if="showCreateAccessory">
      <div class="modal-card form-card">
        <h4>🚀 零配件手动新购建档</h4>
        <div class="form-item">
          <label>唯一识别条码 (三防粘贴标签)</label>
          <input type="text" v-model="newAccessory.barcode" placeholder="如 ACC-SEAL-004" />
        </div>
        <div class="form-item">
          <label>配件名称</label>
          <input type="text" v-model="newAccessory.name" list="preset-accessory-names" placeholder="选择或手动输入配件名称，如：氟橡胶密封垫" />
          <datalist id="preset-accessory-names">
            <option v-for="name in existingAccessoryNames" :key="name" :value="name" />
          </datalist>
        </div>
        <div class="form-item">
          <label>规格型号描述</label>
          <input type="text" v-model="newAccessory.spec" placeholder="如 DN120" />
        </div>
        <div class="form-item">
          <label>计量单位</label>
          <input type="text" v-model="newAccessory.unit" placeholder="个" />
        </div>
        <div class="form-item">
          <label>安全水位预警阈值</label>
          <input type="number" v-model="newAccessory.safetyStock" />
        </div>
        <div class="form-item">
          <label>初始当前在库量</label>
          <input type="number" v-model="newAccessory.currentStock" />
        </div>
        <div class="modal-actions">
          <button class="primary-btn" @click="submitManualCreateAccessory">确认保存</button>
          <button class="ghost-btn" @click="showCreateAccessory = false">取消</button>
        </div>
      </div>
    </div>

    <!-- 井号字典增补弹窗 -->
    <div class="modal-overlay" v-if="showDict">
      <div class="modal-card form-card">
        <h4>🌐 目标作业井号字典增补</h4>
        <div class="form-item">
          <label>新增井号名称</label>
          <input type="text" v-model="newWellbore" placeholder="如 川科2井" @keyup.enter="submitAddWellbore" />
        </div>
        <div class="modal-actions">
          <button class="primary-btn" @click="submitAddWellbore">确认保存</button>
          <button class="ghost-btn" @click="showDict = false">取消</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script lang="ts">
import { defineComponent, ref, computed, onMounted, watch } from 'vue';
import { api } from '../api';
import type { Tool, ToolHistory, Accessory } from '../api';

export default defineComponent({
  name: 'Lifecycle',
  setup() {
    const selectedCode = ref('');
    const exportMenuVisible = ref(false);
    
    // 弹窗状态
    const showImport = ref(false);
    const showCreate = ref(false);
    const showCreateAccessory = ref(false);
    const showDict = ref(false);
    const importedFile = ref('');
    const importProgress = ref(0);

    const newTool = ref({
      code: '',
      name: '电动坐封工具',
      model: '',
      lifespanLimit: 30
    });

    const newAccessory = ref({
      barcode: '',
      name: '',
      spec: '',
      unit: '个',
      safetyStock: 20,
      currentStock: 10
    });

    const newWellbore = ref('');

    const tools = ref<Tool[]>([]);
    const accessories = ref<Accessory[]>([]);
    const selectedToolHistories = ref<ToolHistory[]>([]);

    const fetchData = async () => {
      const allTools = await api.getTools();
      const allAccs = await api.getAccessories();
      tools.value = allTools;
      accessories.value = allAccs;
      if (allTools.length > 0 && !selectedCode.value) {
        selectedCode.value = allTools[0].code;
      } else if (selectedCode.value) {
        fetchHistories(selectedCode.value);
      }
    };

    const fetchHistories = async (code: string) => {
      if (!code) return;
      selectedToolHistories.value = await api.getToolHistories(code);
    };

    watch(selectedCode, (newVal) => {
      fetchHistories(newVal);
    });

    const selectedTool = computed(() => {
      return tools.value.find(t => t.code === selectedCode.value);
    });

    const existingToolNames = computed(() => {
      const names = tools.value.map(t => t.name);
      const defaults = ['电动坐封工具', '阿瓦隆桥塞'];
      return Array.from(new Set([...defaults, ...names]));
    });

    const existingAccessoryNames = computed(() => {
      const names = accessories.value.map(a => a.name);
      const defaults = ['氟橡胶密封圈 O-Ring', '高强防腐螺栓', '井下密封金属垫'];
      return Array.from(new Set([...defaults, ...names]));
    });

    const toggleExportMenu = () => {
      exportMenuVisible.value = !exportMenuVisible.value;
    };

    const triggerExport = (type: string) => {
      exportMenuVisible.value = false;
      alert(`【报表导出】成功触发 ${type} 报表导出模拟，Excel 文件已准备下载。`);
    };

    const mockSelectFile = () => {
      importedFile.value = 'precision_tools_batch_2026.xlsx';
    };

    const triggerBatchImport = () => {
      if (!importedFile.value) {
        alert('请先选择导入的文件！');
        return;
      }
      importProgress.value = 10;
      const interval = setInterval(async () => {
        if (importProgress.value >= 100) {
          clearInterval(interval);
          const code = 'TL-MT-' + Math.floor(Math.random() * 900 + 100) + '-W';
          await api.createTool({
            code,
            name: '电动坐封工具',
            model: 'E-Setter 3.0',
            lifespan_limit: 30,
            location: '基地总库'
          });
          alert('批量导入对齐完成！');
          closeImport();
          fetchData();
        } else {
          importProgress.value += 30;
        }
      }, 200);
    };

    const closeImport = () => {
      showImport.value = false;
      importedFile.value = '';
      importProgress.value = 0;
    };

    const submitManualCreate = async () => {
      if (!newTool.value.code) {
        alert('物理识别刻码不能为空！');
        return;
      }
      const createdCode = newTool.value.code;
      await api.createTool({
        code: createdCode,
        name: newTool.value.name,
        model: newTool.value.model || '通用型',
        lifespan_limit: newTool.value.lifespanLimit,
        location: '基地总库'
      });
      showCreate.value = false;
      newTool.value = { code: '', name: '电动坐封工具', model: '', lifespanLimit: 30 };
      await fetchData();
      selectedCode.value = createdCode;
    };

    const submitAddWellbore = async () => {
      if (!newWellbore.value.trim()) return;
      await api.addWellbore(newWellbore.value.trim());
      alert(`新增目标井号 [${newWellbore.value.trim()}] 成功！已更新至字典，近场同步时将下发给手持终端。`);
      newWellbore.value = '';
      showDict.value = false;
    };

    const submitManualCreateAccessory = async () => {
      if (!newAccessory.value.barcode || !newAccessory.value.name) {
        alert('条码及配件名称不能为空！');
        return;
      }
      await api.createAccessory({
        barcode: newAccessory.value.barcode,
        name: newAccessory.value.name,
        spec: newAccessory.value.spec || '通用型',
        unit: newAccessory.value.unit || '个',
        safety_stock: newAccessory.value.safetyStock,
        current_stock: newAccessory.value.currentStock
      });
      showCreateAccessory.value = false;
      newAccessory.value = { barcode: '', name: '', spec: '', unit: '个', safetyStock: 20, currentStock: 10 };
      alert('配件手动建档成功！');
      await fetchData();
    };

    onMounted(() => {
      fetchData();
    });

    return {
      selectedCode,
      exportMenuVisible,
      showImport,
      showCreate,
      showCreateAccessory,
      showDict,
      importedFile,
      importProgress,
      newTool,
      newAccessory,
      newWellbore,
      tools,
      accessories,
      selectedTool,
      selectedToolHistories,
      existingToolNames,
      existingAccessoryNames,
      toggleExportMenu,
      triggerExport,
      mockSelectFile,
      triggerBatchImport,
      closeImport,
      submitManualCreate,
      submitManualCreateAccessory,
      submitAddWellbore
    };
  }
});
</script>

<style scoped>
.lifecycle-container {
  display: flex;
  flex-direction: column;
  height: 100%;
}

.lifecycle-main-grid {
  display: grid;
  grid-template-columns: 1fr 340px;
  gap: 20px;
  align-items: start;
}

.panel-card {
  background: #121824;
  border: 1px solid rgba(255,255,255,0.06);
  border-radius: 10px;
  padding: 20px;
  box-sizing: border-box;
}

.table-header-section {
  display: flex;
  justify-content: space-between;
  align-items: center;
  border-bottom: 1px solid rgba(255,255,255,0.06);
  padding-bottom: 12px;
  margin-bottom: 16px;
}

.table-header-section h3 {
  margin: 0;
  font-size: 14px;
  font-weight: 600;
  color: rgba(255,255,255,0.9);
}

/* 按钮组 */
.action-btn-group {
  display: flex;
  gap: 8px;
}

.ghost-btn {
  background: rgba(255,255,255,0.03);
  border: 1px solid rgba(255,255,255,0.1);
  color: rgba(255,255,255,0.85);
  font-size: 11px;
  padding: 6px 12px;
  border-radius: 4px;
  cursor: pointer;
  transition: all 0.2s;
}
.ghost-btn:hover {
  background: rgba(255,255,255,0.06);
}

.primary-btn {
  background: #102a43;
  border: 1px solid #0088cc;
  color: #fff;
  font-size: 11px;
  padding: 6px 12px;
  border-radius: 4px;
  cursor: pointer;
}

.export-dropdown-wrapper {
  position: relative;
}

.export-btn {
  background: #d4af37;
  border: none;
  color: #000;
  font-size: 11px;
  padding: 6.5px 12px;
  border-radius: 4px;
  font-weight: bold;
  cursor: pointer;
  display: flex;
  align-items: center;
  gap: 4px;
}

.dropdown-menu {
  position: absolute;
  top: 100%;
  right: 0;
  margin-top: 4px;
  background: #1e2433;
  border: 1px solid rgba(255,255,255,0.1);
  border-radius: 4px;
  box-shadow: 0 4px 12px rgba(0,0,0,0.3);
  z-index: 100;
  min-width: 150px;
}

.menu-item {
  font-size: 11px;
  padding: 8px 12px;
  color: rgba(255,255,255,0.8);
  cursor: pointer;
}
.menu-item:hover {
  background: rgba(255,255,255,0.05);
  color: #fff;
}

/* 自定义表格 */
.custom-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 12px;
  text-align: left;
}

.custom-table th {
  padding: 10px 8px;
  color: rgba(255,255,255,0.5);
  border-bottom: 1px solid rgba(255,255,255,0.06);
}

.custom-table td {
  padding: 12px 8px;
  color: rgba(255,255,255,0.8);
  border-bottom: 1px solid rgba(255,255,255,0.02);
}

.custom-table tbody tr {
  cursor: pointer;
  transition: background 0.15s;
}
.custom-table tbody tr:hover {
  background: rgba(255,255,255,0.02);
}

.custom-table tbody tr.row-selected {
  background: rgba(255,255,255,0.04);
}

.code-col {
  font-weight: bold;
}

.badge {
  font-size: 9px;
  padding: 2px 6px;
  border-radius: 4px;
  font-weight: bold;
}
.badge-in { background: rgba(16, 185, 129, 0.1); color: #10b981; }
.badge-out { background: rgba(245, 158, 11, 0.1); color: #f59e0b; }

/* 履历详情面板 */
.history-header {
  border-bottom: 1px solid rgba(255,255,255,0.06);
  padding-bottom: 12px;
  margin-bottom: 16px;
}

.drawer-label {
  font-size: 10px;
  color: #d4af37;
  font-weight: bold;
}

.history-header h4 {
  margin: 4px 0 0 0;
  font-size: 16px;
  font-weight: 600;
  color: #fff;
}

.tool-sub-desc {
  font-size: 11px;
  color: rgba(255,255,255,0.4);
  margin-top: 2px;
}

.history-metrics {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 10px;
  margin-bottom: 20px;
}

.metric-box {
  background: #182030;
  border-radius: 6px;
  padding: 10px;
  display: flex;
  flex-direction: column;
}

.metric-label {
  font-size: 10px;
  color: rgba(255,255,255,0.5);
}

.metric-val {
  font-size: 14px;
  font-weight: bold;
  margin-top: 2px;
}

/* 时间轴 */
.timeline-area {
  display: flex;
  flex-direction: column;
}

.timeline-item {
  position: relative;
  padding-left: 16px;
  border-left: 2px solid #102a43;
  padding-bottom: 16px;
}

.node-bullet {
  position: absolute;
  left: -5px;
  top: 4px;
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: #102a43;
}

.node-bullet.node-active {
  background: #d4af37;
  box-shadow: 0 0 8px #d4af37;
}

.node-time {
  font-size: 10px;
  color: rgba(255,255,255,0.3);
}

.node-title {
  font-size: 12px;
  font-weight: bold;
  color: rgba(255,255,255,0.85);
  margin-top: 2px;
}

.node-op {
  font-size: 9px;
  font-weight: normal;
  color: rgba(255,255,255,0.4);
}

.node-detail {
  font-size: 11px;
  color: rgba(255,255,255,0.5);
  margin-top: 2px;
  line-height: 1.4;
}

/* 弹窗样式 */
.modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0,0,0,0.7);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
}

.modal-card {
  background: #131722;
  border: 1px solid rgba(255,255,255,0.1);
  border-radius: 12px;
  padding: 24px;
  width: 350px;
  display: flex;
  flex-direction: column;
  gap: 14px;
}

.modal-card h4 {
  margin: 0;
  font-size: 16px;
  color: #d4af37;
}

.drop-zone {
  border: 2px dashed rgba(255,255,255,0.15);
  border-radius: 8px;
  padding: 30px 10px;
  text-align: center;
  cursor: pointer;
  background: rgba(255,255,255,0.01);
}

.drop-icon {
  font-size: 32px;
  display: block;
  margin-bottom: 8px;
}

.drop-text {
  font-size: 12px;
  color: rgba(255,255,255,0.6);
}

.file-ready {
  color: #10b981;
}

.modal-actions {
  display: flex;
  gap: 10px;
}

/* 表单弹框 */
.form-card input, .form-card select {
  width: 100%;
  background: rgba(255, 255, 255, 0.04);
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 6px;
  padding: 8px;
  color: #fff;
  font-size: 12px;
  box-sizing: border-box;
  margin-top: 4px;
}

/* 去除 Chrome/Edge 等浏览器下 datalist 关联输入框右侧的原生下拉小三角 */
.form-card input::-webkit-calendar-picker-indicator {
  display: none !important;
}

.form-item label {
  font-size: 11px;
  color: rgba(255,255,255,0.6);
}
</style>
