<template>
  <div class="devices-container">
    <div class="panel-card">
      <div class="table-header-section">
        <div>
          <h3>终端设备授权</h3>
          <p>仅被授权且启用状态的手持终端 UUID 可以执行局域网握手同步</p>
        </div>
        <button class="primary-btn" @click="showCreate = true">授权新终端</button>
      </div>

      <div class="summary-grid">
        <div class="summary-item">
          <span class="summary-label">已授权终端</span>
          <span class="summary-value">{{ devices.length }}</span>
        </div>
        <div class="summary-item">
          <span class="summary-label">当前启用中</span>
          <span class="summary-value success">{{ activeCount }}</span>
        </div>
        <div class="summary-item">
          <span class="summary-label">已禁用/软删除</span>
          <span class="summary-value danger">{{ inactiveCount }}</span>
        </div>
      </div>

      <table class="custom-table">
        <thead>
          <tr>
            <th>终端唯一 UUID (UUID)</th>
            <th>终端设备名称</th>
            <th>启用状态</th>
            <th>登记时间</th>
            <th>最近同步时间</th>
            <th>备注说明</th>
            <th>操作</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="item in devices" :key="item.uuid">
            <td class="code-col monospace">{{ item.uuid }}</td>
            <td class="name-col">{{ item.name }}</td>
            <td>
              <el-switch
                v-model="item.is_active"
                active-color="#10b981"
                inactive-color="#ef4444"
                @change="handleStatusChange(item)"
              />
            </td>
            <td class="time-col">{{ formatDate(item.registered_at) }}</td>
            <td class="time-col">
              <span :class="item.last_sync_at ? 'sync-active' : 'sync-never'">
                {{ item.last_sync_at ? formatDate(item.last_sync_at) : '从未同步' }}
              </span>
            </td>
            <td class="remark-col">{{ item.remark || '—' }}</td>
            <td>
              <button 
                class="danger-btn" 
                :disabled="!item.is_active"
                @click="confirmDisable(item)"
              >
                禁用/删除
              </button>
            </td>
          </tr>
          <tr v-if="devices.length === 0">
            <td colspan="7" class="empty-row">暂无授权的终端设备记录</td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- 授权新增终端弹窗 -->
    <div class="modal-overlay" v-if="showCreate">
      <div class="modal-card form-card">
        <h4>授权新终端设备</h4>
        <div class="form-item">
          <label>唯一识别 UUID <span class="required">*</span></label>
          <input v-model="newDevice.uuid" placeholder="如 terminal-handheld-001" />
        </div>
        <div class="form-item">
          <label>设备名称 <span class="required">*</span></label>
          <input v-model="newDevice.name" placeholder="如 库房1号PDA手持端" />
        </div>
        <div class="form-item">
          <label>备注说明</label>
          <input v-model="newDevice.remark" placeholder="如 现场测试领用" />
        </div>
        <div class="modal-actions">
          <button class="primary-btn" @click="submitCreate">确认保存</button>
          <button class="ghost-btn" @click="closeCreate">取消</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script lang="ts">
import { computed, defineComponent, onMounted, ref } from 'vue';
import { api } from '../api';
import type { AuthorizedDevice } from '../api';
import { ElMessageBox, ElMessage } from 'element-plus';

export default defineComponent({
  name: 'Devices',
  setup() {
    const devices = ref<AuthorizedDevice[]>([]);
    const showCreate = ref(false);
    const newDevice = ref({
      uuid: '',
      name: '',
      remark: ''
    });

    const activeCount = computed(() => devices.value.filter(d => d.is_active).length);
    const inactiveCount = computed(() => devices.value.filter(d => !d.is_active).length);

    const fetchData = async () => {
      try {
        devices.value = await api.getDevices();
      } catch (err) {
        console.error('Failed to load devices:', err);
      }
    };

    const submitCreate = async () => {
      if (!newDevice.value.uuid.trim() || !newDevice.value.name.trim()) {
        ElMessage.warning('UUID 和设备名称不能为空');
        return;
      }

      try {
        await api.createDevice({
          uuid: newDevice.value.uuid.trim(),
          name: newDevice.value.name.trim(),
          remark: newDevice.value.remark.trim() || undefined
        });
        ElMessage.success('设备授权登记成功！');
        closeCreate();
        await fetchData();
      } catch (err) {
        console.error('Failed to register device:', err);
      }
    };

    const closeCreate = () => {
      showCreate.value = false;
      newDevice.value = { uuid: '', name: '', remark: '' };
    };

    const handleStatusChange = async (item: AuthorizedDevice) => {
      try {
        await api.updateDevice(item.uuid, { is_active: item.is_active });
        ElMessage.success(`设备 [${item.name}] 已${item.is_active ? '启用' : '禁用'}`);
        await fetchData();
      } catch (err) {
        // 请求失败回滚 Switch 状态
        item.is_active = !item.is_active;
        console.error('Failed to update status:', err);
      }
    };

    const confirmDisable = (item: AuthorizedDevice) => {
      ElMessageBox.confirm(
        `确定要禁用并删除终端设备 [${item.name}] 的授权吗？该终端将无法再与本库房中枢同步。`,
        '警告',
        {
          confirmButtonText: '确定禁用',
          cancelButtonText: '取消',
          type: 'warning'
        }
      ).then(async () => {
        try {
          await api.deleteDevice(item.uuid);
          ElMessage.success(`设备 [${item.name}] 授权已成功禁用`);
          await fetchData();
        } catch (err) {
          console.error('Failed to disable device:', err);
        }
      }).catch(() => {});
    };

    const formatDate = (dateStr: string) => {
      if (!dateStr) return '—';
      try {
        return new Date(dateStr).toLocaleString();
      } catch {
        return dateStr;
      }
    };

    onMounted(fetchData);

    return {
      devices,
      showCreate,
      newDevice,
      activeCount,
      inactiveCount,
      submitCreate,
      closeCreate,
      handleStatusChange,
      confirmDisable,
      formatDate
    };
  }
});
</script>

<style scoped>
.devices-container {
  display: flex;
  flex-direction: column;
}

.panel-card {
  background: #121824;
  border: 1px solid rgba(255, 255, 255, 0.06);
  border-radius: 10px;
  padding: 20px;
  box-sizing: border-box;
}

.table-header-section {
  display: flex;
  justify-content: space-between;
  align-items: center;
  border-bottom: 1px solid rgba(255, 255, 255, 0.06);
  padding-bottom: 12px;
  margin-bottom: 16px;
}

.table-header-section h3 {
  margin: 0;
  font-size: 15px;
  color: rgba(255, 255, 255, 0.92);
}

.table-header-section p {
  margin: 4px 0 0;
  font-size: 11px;
  color: rgba(255, 255, 255, 0.45);
}

.summary-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(140px, 1fr));
  gap: 12px;
  margin-bottom: 16px;
}

.summary-item {
  background: #182030;
  border: 1px solid rgba(255, 255, 255, 0.05);
  border-radius: 8px;
  padding: 12px;
}

.summary-label {
  display: block;
  color: rgba(255, 255, 255, 0.45);
  font-size: 11px;
}

.summary-value {
  display: block;
  font-size: 20px;
  font-weight: 700;
  margin-top: 4px;
  color: #ffffff;
}

.summary-value.success {
  color: #10b981;
}

.summary-value.danger {
  color: #ef4444;
}

/* 自定义数据表格 */
.custom-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 12px;
  text-align: left;
}

.custom-table th {
  padding: 10px 8px;
  color: rgba(255, 255, 255, 0.5);
  border-bottom: 1px solid rgba(255, 255, 255, 0.06);
  font-weight: 600;
}

.custom-table td {
  padding: 12px 8px;
  color: rgba(255, 255, 255, 0.8);
  border-bottom: 1px solid rgba(255, 255, 255, 0.02);
  vertical-align: middle;
}

.custom-table tbody tr {
  transition: background 0.15s;
}

.custom-table tbody tr:hover {
  background: rgba(255, 255, 255, 0.02);
}

.code-col {
  font-weight: 600;
}

.monospace {
  font-family: monospace;
  color: #58a6ff;
  background-color: rgba(88, 166, 255, 0.07);
  padding: 2px 6px;
  border-radius: 4px;
}

.sync-active {
  color: #10b981;
}

.sync-never {
  color: rgba(255, 255, 255, 0.35);
  font-style: italic;
}

.empty-row {
  text-align: center;
  padding: 30px !important;
  color: rgba(255, 255, 255, 0.3);
  font-style: italic;
}

/* 按钮样式 */
.primary-btn {
  background: #102a43;
  border: 1px solid #0088cc;
  color: #fff;
  font-size: 11px;
  padding: 6px 12px;
  border-radius: 4px;
  cursor: pointer;
  font-weight: bold;
  transition: all 0.2s;
}

.primary-btn:hover {
  background: #183e60;
  border-color: #00a2f3;
}

.ghost-btn {
  background: rgba(255, 255, 255, 0.03);
  border: 1px solid rgba(255, 255, 255, 0.15);
  color: rgba(255, 255, 255, 0.85);
  font-size: 11px;
  padding: 6px 12px;
  border-radius: 4px;
  cursor: pointer;
  transition: all 0.2s;
}

.ghost-btn:hover {
  background: rgba(255, 255, 255, 0.08);
  border-color: rgba(255, 255, 255, 0.25);
  color: #fff;
}

.danger-btn {
  background: rgba(239, 68, 68, 0.08);
  border: 1px solid rgba(239, 68, 68, 0.4);
  color: #ef4444;
  font-size: 11px;
  padding: 4px 10px;
  border-radius: 4px;
  cursor: pointer;
  transition: all 0.2s;
}

.danger-btn:hover:not(:disabled) {
  background: rgba(239, 68, 68, 0.2);
  border-color: rgba(239, 68, 68, 0.6);
  color: #ff6b6b;
}

.danger-btn:disabled {
  opacity: 0.4;
  cursor: not-allowed;
}

/* 模态浮层弹窗 */
.modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  width: 100vw;
  height: 100vh;
  background: rgba(0, 0, 0, 0.7);
  backdrop-filter: blur(4px);
  display: flex;
  justify-content: center;
  align-items: center;
  z-index: 999;
}

.modal-card {
  background: #182030;
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 12px;
  padding: 24px;
  width: 400px;
  box-shadow: 0 15px 40px rgba(0, 0, 0, 0.5);
  box-sizing: border-box;
}

.modal-card h4 {
  margin: 0 0 20px 0;
  font-size: 14px;
  color: #ffffff;
  border-bottom: 1px solid rgba(255, 255, 255, 0.06);
  padding-bottom: 10px;
}

.form-item {
  display: flex;
  flex-direction: column;
  margin-bottom: 16px;
}

.form-item label {
  font-size: 11px;
  color: rgba(255, 255, 255, 0.5);
  margin-bottom: 6px;
}

.form-item label .required {
  color: #ef4444;
  margin-left: 2px;
}

.form-item input {
  background: #0f131a;
  border: 1px solid rgba(255, 255, 255, 0.1);
  border-radius: 6px;
  padding: 10px 12px;
  font-size: 13px;
  color: #ffffff;
  outline: none;
  transition: all 0.2s;
}

.form-item input:focus {
  border-color: #58a6ff;
  box-shadow: 0 0 8px rgba(88, 166, 255, 0.2);
}

.modal-actions {
  display: flex;
  justify-content: flex-end;
  gap: 10px;
  margin-top: 24px;
}
</style>
