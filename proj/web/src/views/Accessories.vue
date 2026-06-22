<template>
  <div class="accessories-container">
    <div class="panel-card">
      <div class="table-header-section">
        <div>
          <h3>配件库存台账</h3>
          <p>易损件独立库存、安全水位与补货管理</p>
        </div>
        <button class="primary-btn" @click="showCreate = true">新建配件</button>
      </div>

      <div class="summary-grid">
        <div class="summary-item">
          <span class="summary-label">配件种类</span>
          <span class="summary-value">{{ accessories.length }}</span>
        </div>
        <div class="summary-item">
          <span class="summary-label">低库存预警</span>
          <span class="summary-value danger">{{ lowStockCount }}</span>
        </div>
        <div class="summary-item">
          <span class="summary-label">库存总量</span>
          <span class="summary-value">{{ totalStock }}</span>
        </div>
      </div>

      <table class="custom-table">
        <thead>
          <tr>
            <th>配件条码</th>
            <th>配件名称</th>
            <th>规格型号</th>
            <th>当前库存</th>
            <th>安全水位</th>
            <th>状态</th>
            <th>操作</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="item in accessories" :key="item.barcode">
            <td class="code-col">{{ item.barcode }}</td>
            <td>{{ item.name }}</td>
            <td>{{ item.spec }}</td>
            <td>{{ item.current_stock }} {{ item.unit }}</td>
            <td>{{ item.safety_stock }} {{ item.unit }}</td>
            <td>
              <span class="badge" :class="item.current_stock < item.safety_stock ? 'badge-alert' : 'badge-ok'">
                {{ item.current_stock < item.safety_stock ? '低库存' : '正常' }}
              </span>
            </td>
            <td>
              <button class="ghost-btn" @click="openAdjust(item)">补货</button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <div class="modal-overlay" v-if="showCreate">
      <div class="modal-card form-card">
        <h4>配件手动建档</h4>
        <div class="form-item">
          <label>唯一识别条码</label>
          <input v-model="newAccessory.barcode" placeholder="如 ACC-RING-006" />
        </div>
        <div class="form-item">
          <label>配件名称</label>
          <input v-model="newAccessory.name" placeholder="如 氟橡胶密封圈" />
        </div>
        <div class="form-item">
          <label>规格型号</label>
          <input v-model="newAccessory.spec" placeholder="如 120mm x 5mm" />
        </div>
        <div class="form-row">
          <div class="form-item">
            <label>单位</label>
            <input v-model="newAccessory.unit" placeholder="个" />
          </div>
          <div class="form-item">
            <label>安全水位</label>
            <input type="number" v-model="newAccessory.safety_stock" />
          </div>
          <div class="form-item">
            <label>初始库存</label>
            <input type="number" v-model="newAccessory.current_stock" />
          </div>
        </div>
        <div class="modal-actions">
          <button class="primary-btn" @click="submitCreate">确认保存</button>
          <button class="ghost-btn" @click="showCreate = false">取消</button>
        </div>
      </div>
    </div>

    <div class="modal-overlay" v-if="adjustTarget">
      <div class="modal-card form-card">
        <h4>库存补货</h4>
        <div class="target-line">{{ adjustTarget.name }} · {{ adjustTarget.barcode }}</div>
        <div class="form-item">
          <label>追加数量</label>
          <input type="number" v-model="adjustQty" />
        </div>
        <div class="modal-actions">
          <button class="primary-btn" @click="submitAdjust">确认补货</button>
          <button class="ghost-btn" @click="adjustTarget = null">取消</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script lang="ts">
import { computed, defineComponent, onMounted, ref } from 'vue';
import { api } from '../api';
import type { Accessory } from '../api';

export default defineComponent({
  name: 'Accessories',
  setup() {
    const accessories = ref<Accessory[]>([]);
    const showCreate = ref(false);
    const adjustTarget = ref<Accessory | null>(null);
    const adjustQty = ref(1);
    const newAccessory = ref({
      barcode: '',
      name: '',
      spec: '',
      unit: '个',
      safety_stock: 20,
      current_stock: 0
    });

    const lowStockCount = computed(() => accessories.value.filter(item => item.current_stock < item.safety_stock).length);
    const totalStock = computed(() => accessories.value.reduce((sum, item) => sum + item.current_stock, 0));

    const fetchData = async () => {
      accessories.value = await api.getAccessories();
    };

    const submitCreate = async () => {
      if (!newAccessory.value.barcode.trim() || !newAccessory.value.name.trim()) {
        alert('条码和配件名称不能为空');
        return;
      }

      await api.createAccessory({
        barcode: newAccessory.value.barcode.trim(),
        name: newAccessory.value.name.trim(),
        spec: newAccessory.value.spec.trim() || '通用型',
        unit: newAccessory.value.unit.trim() || '个',
        safety_stock: Number(newAccessory.value.safety_stock) || 0,
        current_stock: Number(newAccessory.value.current_stock) || 0
      });
      showCreate.value = false;
      newAccessory.value = { barcode: '', name: '', spec: '', unit: '个', safety_stock: 20, current_stock: 0 };
      await fetchData();
    };

    const openAdjust = (item: Accessory) => {
      adjustTarget.value = item;
      adjustQty.value = 1;
    };

    const submitAdjust = async () => {
      if (!adjustTarget.value) return;
      const qty = Number(adjustQty.value);
      if (!Number.isFinite(qty) || qty <= 0) {
        alert('补货数量必须大于 0');
        return;
      }

      await api.adjustAccessoryStock(adjustTarget.value.barcode, qty);
      adjustTarget.value = null;
      await fetchData();
    };

    onMounted(fetchData);

    return {
      accessories,
      showCreate,
      adjustTarget,
      adjustQty,
      newAccessory,
      lowStockCount,
      totalStock,
      submitCreate,
      openAdjust,
      submitAdjust
    };
  }
});
</script>

<style scoped>
.accessories-container {
  display: flex;
  flex-direction: column;
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
  font-size: 15px;
  color: rgba(255,255,255,0.92);
}

.table-header-section p {
  margin: 4px 0 0;
  font-size: 11px;
  color: rgba(255,255,255,0.45);
}

.summary-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(140px, 1fr));
  gap: 12px;
  margin-bottom: 16px;
}

.summary-item {
  background: #182030;
  border: 1px solid rgba(255,255,255,0.05);
  border-radius: 8px;
  padding: 12px;
}

.summary-label {
  display: block;
  color: rgba(255,255,255,0.45);
  font-size: 11px;
}

.summary-value {
  display: block;
  color: #38bdf8;
  font-size: 24px;
  font-weight: 700;
  margin-top: 4px;
}

.summary-value.danger {
  color: #ef4444;
}

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

.code-col {
  font-weight: 700;
}

.badge {
  font-size: 10px;
  padding: 2px 7px;
  border-radius: 4px;
  font-weight: 700;
}

.badge-ok {
  background: rgba(16, 185, 129, 0.1);
  color: #10b981;
}

.badge-alert {
  background: rgba(239, 68, 68, 0.1);
  color: #ef4444;
}

.primary-btn,
.ghost-btn {
  font-size: 12px;
  padding: 7px 12px;
  border-radius: 4px;
  cursor: pointer;
}

.primary-btn {
  background: #102a43;
  border: 1px solid #0088cc;
  color: #fff;
}

.ghost-btn {
  background: rgba(255,255,255,0.03);
  border: 1px solid rgba(255,255,255,0.1);
  color: rgba(255,255,255,0.85);
}

.modal-overlay {
  position: fixed;
  inset: 0;
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
  width: 420px;
  display: flex;
  flex-direction: column;
  gap: 14px;
}

.modal-card h4 {
  margin: 0;
  font-size: 16px;
  color: #d4af37;
}

.form-row {
  display: grid;
  grid-template-columns: 1fr 1fr 1fr;
  gap: 10px;
}

.form-card input {
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

.form-item label,
.target-line {
  font-size: 11px;
  color: rgba(255,255,255,0.6);
}

.modal-actions {
  display: flex;
  gap: 10px;
}
</style>
