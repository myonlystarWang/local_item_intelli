import axios from 'axios'
import { ElMessage } from 'element-plus'

const API_BASE = (import.meta.env.VITE_API_BASE_URL || 'http://127.0.0.1:8000/api/v1').replace(/\/$/, '')

// 请求拦截器
axios.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('access_token')
    if (token) {
      config.headers.Authorization = `Bearer ${token}`
    }
    return config
  },
  (error) => {
    return Promise.reject(error)
  }
)

// 响应拦截器
axios.interceptors.response.use(
  (response) => {
    return response
  },
  (error) => {
    const status = error.response?.status
    const detail = error.response?.data?.detail
    const msg = Array.isArray(detail) ? detail.map(d => d.msg).join(', ') : (detail || error.message || '网络连接失败，请检查网络')

    if (status === 401) {
      localStorage.removeItem('access_token')
      localStorage.removeItem('user')
      ElMessage({
        message: '登录已过期或未登录，请重新登录',
        type: 'error',
        duration: 3000
      })
      window.location.hash = '#/login'
    } else {
      ElMessage({
        message: msg,
        type: 'error',
        duration: 3000
      })
    }
    return Promise.reject(error)
  }
)

export interface AdminLoginRequest {
  username: string
  password: string
}

export interface AdminUserResponse {
  id: number
  username: string
  role: string
}

export interface TokenResponse {
  access_token: string
  token_type: string
  expires_in: number
  user: AdminUserResponse
}


export interface Tool {
  code: string
  name: string
  model: string
  status: string
  use_count: number
  lifespan_limit: number
  location: string
  operator: string
  last_update_time: string
  checkout_time?: string
  histories?: ToolHistory[]
}

export interface Accessory {
  barcode: string
  name: string
  spec: string
  unit: string
  safety_stock: number
  current_stock: number
}

export interface ToolHistory {
  id: number
  tool_code: string
  timestamp: string
  type: string
  detail: string
  operator: string
}

export interface SyncLog {
  id?: number
  terminal_uuid?: string
  type: string
  time: string
  text: string
  timestamp?: string
  source_time?: string
}

export interface DictionaryItem {
  id: number
  dict_type: 'wellbore' | 'operator' | 'team'
  dict_value: string
}

export interface AuthorizedDevice {
  uuid: string
  name: string
  is_active: boolean
  registered_at: string
  last_sync_at?: string
  remark?: string
}

export const MOCK_DATA = {
  wellbores: ["川科1井", "深地塔科1井", "威页23-4井", "大庆102井"],
  operators: ["张建国", "李志刚", "王超", "赵强"],
  teams: ["川庆钻探一队", "中原石油三队", "江汉作业五队"],
  tools: [
    { code: 'TL-MT-056-K', name: '电动坐封工具', model: 'E-Setter 3.0', status: '在库', use_count: 12, lifespan_limit: 30, location: '基地总库', operator: '系统初始化', last_update_time: '2026-06-18 10:00:00' },
    { code: 'TL-BG-112-B', name: '阿瓦隆桥塞', model: 'Avalon-Bridge 10', status: '在库', use_count: 28, lifespan_limit: 30, location: '基地总库', operator: '系统初始化', last_update_time: '2026-06-18 10:00:00' },
    { code: 'TL-MT-099-H', name: '电动坐封工具', model: 'E-Setter 2.0', status: '在库', use_count: 30, lifespan_limit: 30, location: '基地总库', operator: '系统初始化', last_update_time: '2026-06-18 10:00:00' },
    { code: 'TL-BG-203-A', name: '阿瓦隆桥塞', model: 'Avalon-Bridge 12', status: '离库', use_count: 15, lifespan_limit: 40, location: '川科1井', operator: '王超', last_update_time: '2026-06-18 11:30:00', checkout_time: '2026-06-18 10:15:30' }
  ] as Tool[],
  accessories: [
    { barcode: 'ACC-RING-001', name: '氟橡胶密封圈 O-Ring', spec: '120mm x 5mm', unit: '个', safety_stock: 20, current_stock: 45 },
    { barcode: 'ACC-BOLT-002', name: '高强防腐螺栓', spec: 'M16 x 80', unit: '套', safety_stock: 50, current_stock: 15 },
    { barcode: 'ACC-SEAL-003', name: '井下密封金属垫', spec: 'DN100', unit: '片', safety_stock: 10, current_stock: 25 }
  ] as Accessory[],
  histories: [
    { id: 1, tool_code: 'TL-BG-112-B', timestamp: '2026-06-18 14:20:00', type: '归库保养', detail: '[近场同步] 确认归库，级别: 二级保养。联动扣减配件: 氟橡胶密封圈 O-Ring x 2。累计寿命+1 (当前 28/30次)。', operator: '李志刚' },
    { id: 2, tool_code: 'TL-BG-203-A', timestamp: '2026-06-18 11:30:00', type: '领用出库', detail: '[近场同步] 领用出库至井场 [川科1井]，班组队号: [川庆钻探一队]，领用人: 王超', operator: '王超' },
    { id: 3, tool_code: 'TL-MT-056-K', timestamp: '2026-06-18 10:00:00', type: '建档入库', detail: '系统数据库建档完成，录入初始电子档案数据。', operator: '系统中枢' },
    { id: 4, tool_code: 'TL-BG-112-B', timestamp: '2026-06-18 10:00:00', type: '建档入库', detail: '系统数据库建档完成，录入初始电子档案数据。', operator: '系统中枢' },
    { id: 5, tool_code: 'TL-MT-099-H', timestamp: '2026-06-18 10:00:00', type: '建档入库', detail: '系统数据库建档完成，录入初始电子档案数据。', operator: '系统中枢' },
    { id: 6, tool_code: 'TL-BG-203-A', timestamp: '2026-06-18 10:00:00', type: '建档入库', detail: '系统数据库建档完成，录入初始电子档案数据。', operator: '系统中枢' }
  ] as ToolHistory[],
  syncLogs: [
    { type: 'success', time: '14:20:00', text: '工具 [TL-BG-112-B] 归库保养对齐成功。累计使用寿命刷新为 28次。' },
    { type: 'success', time: '11:30:00', text: '工具 [TL-BG-203-A] 领用出库对齐成功，去往 [川科1井]。' }
  ] as SyncLog[],
  dictionaryItems: [
    { id: 1, dict_type: 'wellbore', dict_value: '川科1井' },
    { id: 2, dict_type: 'wellbore', dict_value: '深地塔科1井' },
    { id: 3, dict_type: 'wellbore', dict_value: '威页23-4井' },
    { id: 4, dict_type: 'wellbore', dict_value: '大庆102井' },
    { id: 5, dict_type: 'operator', dict_value: '张建国' },
    { id: 6, dict_type: 'operator', dict_value: '李志刚' },
    { id: 7, dict_type: 'operator', dict_value: '王超' },
    { id: 8, dict_type: 'operator', dict_value: '赵强' },
    { id: 9, dict_type: 'team', dict_value: '川庆钻探一队' },
    { id: 10, dict_type: 'team', dict_value: '中原石油三队' },
    { id: 11, dict_type: 'team', dict_value: '江汉作业五队' }
  ] as DictionaryItem[]
}

const localState = { ...MOCK_DATA }

export const api = {
  async login(credentials: AdminLoginRequest) {
    const res = await axios.post(`${API_BASE}/auth/login`, credentials)
    return res.data as TokenResponse
  },

  async getDictionaries() {
    try {
      const res = await axios.get(`${API_BASE}/dictionaries`)
      localState.wellbores = res.data.wellbores
      localState.operators = res.data.operators
      localState.teams = res.data.teams
      return res.data
    } catch {
      console.warn("API Error: getDictionaries. Fallback to mock.")
      return { wellbores: localState.wellbores, operators: localState.operators, teams: localState.teams }
    }
  },

  async addWellbore(wellbore: string) {
    await axios.post(`${API_BASE}/dictionaries/wellbores`, { dict_type: 'wellbore', dict_value: wellbore })
  },

  async getDictionaryItems() {
    try {
      const res = await axios.get(`${API_BASE}/dictionaries/items`)
      localState.dictionaryItems = res.data
      localState.wellbores = res.data.filter((d: DictionaryItem) => d.dict_type === 'wellbore').map((d: DictionaryItem) => d.dict_value)
      localState.operators = res.data.filter((d: DictionaryItem) => d.dict_type === 'operator').map((d: DictionaryItem) => d.dict_value)
      localState.teams = res.data.filter((d: DictionaryItem) => d.dict_type === 'team').map((d: DictionaryItem) => d.dict_value)
      return res.data as DictionaryItem[]
    } catch {
      console.warn("API Error: getDictionaryItems. Fallback to mock.")
      return localState.dictionaryItems
    }
  },

  async createDictionaryItem(item: { dict_type: DictionaryItem['dict_type']; dict_value: string }) {
    const res = await axios.post(`${API_BASE}/dictionaries/items`, item)
    return res.data as DictionaryItem
  },

  async updateDictionaryItem(id: number, dictValue: string) {
    const res = await axios.put(`${API_BASE}/dictionaries/items/${id}`, { dict_value: dictValue })
    return res.data as DictionaryItem
  },

  async deleteDictionaryItem(id: number) {
    await axios.delete(`${API_BASE}/dictionaries/items/${id}`)
  },

  async getTools() {
    try {
      const res = await axios.get(`${API_BASE}/tools`)
      // 兼容后端返回的时间字段格式
      const formatted = res.data.map((t: any) => ({
        ...t,
        last_update_time: t.last_update_time ? new Date(t.last_update_time).toLocaleString() : '',
        checkout_time: t.checkout_time ? new Date(t.checkout_time).toLocaleString() : undefined
      }))
      localState.tools = formatted
      return formatted
    } catch {
      console.warn("API Error: getTools. Fallback to mock.")
      return localState.tools
    }
  },

  async createTool(tool: { code: string; name: string; model: string; lifespan_limit: number; location: string }) {
    const res = await axios.post(`${API_BASE}/tools`, tool)
    return res.data
  },

  async getAccessories() {
    try {
      const res = await axios.get(`${API_BASE}/accessories`)
      localState.accessories = res.data
      return res.data
    } catch {
      console.warn("API Error: getAccessories. Fallback to mock.")
      return localState.accessories
    }
  },

  async createAccessory(acc: { barcode: string; name: string; spec: string; unit: string; safety_stock: number; current_stock: number }) {
    const res = await axios.post(`${API_BASE}/accessories`, acc)
    return res.data
  },

  async adjustAccessoryStock(barcode: string, qty: number) {
    const res = await axios.post(`${API_BASE}/accessories/adjust`, { barcode, qty })
    return res.data
  },

  async getToolHistories(toolCode: string) {
    try {
      const res = await axios.get(`${API_BASE}/tools`)
      const tool = res.data.find((t: any) => t.code === toolCode)
      if (tool && tool.histories) {
        return tool.histories
          .slice()
          .sort((a: any, b: any) => new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime())
          .map((h: any) => ({
            ...h,
            timestamp: new Date(h.timestamp).toLocaleString()
          }))
      }
      return []
    } catch {
      console.warn("API Error: getToolHistories. Fallback to mock.")
      return localState.histories
        .filter(h => h.tool_code === toolCode)
        .sort((a, b) => new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime())
    }
  },

  async getSyncLogs() {
    try {
      const res = await axios.get(`${API_BASE}/sync-logs?limit=20`)
      const formatted = res.data.map((item: any) => ({
        id: item.id,
        terminal_uuid: item.terminal_uuid,
        type: item.type,
        text: item.text,
        timestamp: item.timestamp,
        source_time: item.source_time,
        time: item.source_time || (item.timestamp ? new Date(item.timestamp).toLocaleString() : '')
      }))
      localState.syncLogs = formatted
      return formatted
    } catch {
      console.warn("API Error: getSyncLogs. Fallback to mock.")
      return localState.syncLogs
    }
  },

  async getDevices() {
    const res = await axios.get(`${API_BASE}/devices`)
    return res.data as AuthorizedDevice[]
  },

  async createDevice(device: { uuid: string; name: string; remark?: string }) {
    const res = await axios.post(`${API_BASE}/devices`, device)
    return res.data as AuthorizedDevice
  },

  async updateDevice(uuid: string, updates: { name?: string; is_active?: boolean; remark?: string }) {
    const res = await axios.patch(`${API_BASE}/devices/${uuid}`, updates)
    return res.data as AuthorizedDevice
  },

  async deleteDevice(uuid: string) {
    const res = await axios.delete(`${API_BASE}/devices/${uuid}`)
    return res.data
  }
}
