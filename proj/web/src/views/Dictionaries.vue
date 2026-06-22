<template>
  <div class="dict-container">
    <div class="panel-card">
      <div class="table-header-section">
        <div>
          <h3>基础数据维护</h3>
          <p>井号、操作人员、作业大队统一维护后随近场同步下发至手持端</p>
        </div>
      </div>

      <div class="dict-grid">
        <section class="dict-section" v-for="group in groups" :key="group.type">
          <div class="section-head">
            <div>
              <h4>{{ group.title }}</h4>
              <span>{{ group.desc }}</span>
            </div>
          </div>

          <div class="add-row">
            <input v-model="drafts[group.type]" :placeholder="group.placeholder" @keyup.enter="submitCreate(group.type)" />
            <button class="primary-btn" @click="submitCreate(group.type)">新增</button>
          </div>

          <div class="dict-list">
            <div class="dict-item" v-for="item in groupedItems[group.type]" :key="item.id">
              <input
                v-if="editingId === item.id"
                v-model="editingValue"
                class="inline-input"
                @keyup.enter="submitUpdate(item.id)"
              />
              <span v-else>{{ item.dict_value }}</span>
              <div class="row-actions">
                <button v-if="editingId === item.id" class="ghost-btn" @click="submitUpdate(item.id)">保存</button>
                <button v-if="editingId === item.id" class="ghost-btn" @click="cancelEdit">取消</button>
                <button v-if="editingId !== item.id" class="ghost-btn" @click="startEdit(item)">编辑</button>
                <button v-if="editingId !== item.id" class="danger-btn" @click="submitDelete(item.id)">删除</button>
              </div>
            </div>
            <div class="empty-state" v-if="groupedItems[group.type].length === 0">暂无数据</div>
          </div>
        </section>
      </div>
    </div>
  </div>
</template>

<script lang="ts">
import { computed, defineComponent, onMounted, ref } from 'vue';
import { api } from '../api';
import type { DictionaryItem } from '../api';

type DictType = DictionaryItem['dict_type'];

export default defineComponent({
  name: 'Dictionaries',
  setup() {
    const items = ref<DictionaryItem[]>([]);
    const editingId = ref<number | null>(null);
    const editingValue = ref('');
    const drafts = ref<Record<DictType, string>>({
      wellbore: '',
      operator: '',
      team: ''
    });

    const groups: { type: DictType; title: string; desc: string; placeholder: string }[] = [
      { type: 'wellbore', title: '目标井号', desc: '出库和地点变更使用', placeholder: '如 川科2井' },
      { type: 'operator', title: '操作人员', desc: '移动端身份确认使用', placeholder: '如 陈志强' },
      { type: 'team', title: '作业大队', desc: '操作日志追溯使用', placeholder: '如 川庆钻探二队' }
    ];

    const groupedItems = computed<Record<DictType, DictionaryItem[]>>(() => ({
      wellbore: items.value.filter(item => item.dict_type === 'wellbore'),
      operator: items.value.filter(item => item.dict_type === 'operator'),
      team: items.value.filter(item => item.dict_type === 'team')
    }));

    const fetchData = async () => {
      items.value = await api.getDictionaryItems();
    };

    const submitCreate = async (type: DictType) => {
      const value = drafts.value[type].trim();
      if (!value) return;
      await api.createDictionaryItem({ dict_type: type, dict_value: value });
      drafts.value[type] = '';
      await fetchData();
    };

    const startEdit = (item: DictionaryItem) => {
      editingId.value = item.id;
      editingValue.value = item.dict_value;
    };

    const cancelEdit = () => {
      editingId.value = null;
      editingValue.value = '';
    };

    const submitUpdate = async (id: number) => {
      const value = editingValue.value.trim();
      if (!value) return;
      await api.updateDictionaryItem(id, value);
      cancelEdit();
      await fetchData();
    };

    const submitDelete = async (id: number) => {
      const confirmed = window.confirm('确认删除该字典项？已同步到手持端的旧数据将在下次对齐时被覆盖。');
      if (!confirmed) return;
      await api.deleteDictionaryItem(id);
      await fetchData();
    };

    onMounted(fetchData);

    return {
      groups,
      groupedItems,
      drafts,
      editingId,
      editingValue,
      submitCreate,
      startEdit,
      cancelEdit,
      submitUpdate,
      submitDelete
    };
  }
});
</script>

<style scoped>
.dict-container {
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

.dict-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(220px, 1fr));
  gap: 16px;
}

.dict-section {
  background: #182030;
  border: 1px solid rgba(255,255,255,0.05);
  border-radius: 8px;
  padding: 14px;
}

.section-head {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 12px;
}

.section-head h4 {
  margin: 0;
  font-size: 14px;
  color: rgba(255,255,255,0.9);
}

.section-head span {
  display: block;
  margin-top: 3px;
  font-size: 10px;
  color: rgba(255,255,255,0.42);
}

.add-row {
  display: grid;
  grid-template-columns: 1fr auto;
  gap: 8px;
  margin-bottom: 12px;
}

input {
  width: 100%;
  background: rgba(255, 255, 255, 0.04);
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 6px;
  padding: 8px;
  color: #fff;
  font-size: 12px;
  box-sizing: border-box;
}

.dict-list {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.dict-item {
  display: grid;
  grid-template-columns: 1fr auto;
  gap: 8px;
  align-items: center;
  min-height: 34px;
  border-bottom: 1px solid rgba(255,255,255,0.04);
  padding-bottom: 8px;
}

.dict-item span {
  color: rgba(255,255,255,0.82);
  font-size: 12px;
}

.row-actions {
  display: flex;
  gap: 6px;
}

.primary-btn,
.ghost-btn,
.danger-btn {
  font-size: 11px;
  padding: 6px 10px;
  border-radius: 4px;
  cursor: pointer;
  white-space: nowrap;
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

.danger-btn {
  background: rgba(239, 68, 68, 0.08);
  border: 1px solid rgba(239, 68, 68, 0.25);
  color: #fca5a5;
}

.inline-input {
  min-width: 0;
}

.empty-state {
  color: rgba(255,255,255,0.32);
  font-size: 12px;
  padding: 12px 0;
  text-align: center;
}
</style>
