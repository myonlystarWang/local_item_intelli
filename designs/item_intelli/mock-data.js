// 模拟角色配置
const MOCK_ROLES = {
  admin: '库管员 (管理端)',
  operator: '作业人员 (移动端App)'
};

// 模拟已授权终端设备列表 (UUID)
const INITIAL_TERMINALS = [
  { uuid: 'DEV-8812-XYZ', name: '防爆终端 A (井下二队)', status: '已启用', lastSyncTime: '2026-06-17 14:20:00' },
  { uuid: 'DEV-9900-ABC', name: '防爆终端 B (钻井五队)', status: '已禁用', lastSyncTime: '2026-06-16 11:00:00' }
];

// 模拟可同步的基础字典参数
const INITIAL_DICTS = {
  operators: ['张建国', '李志刚', '王超', '赵强'],
  teams: ['川庆钻探一队', '中原石油三队', '江汉作业五队'],
  wellbores: ['川科1井', '深地塔科1井', '威页23-4井', '大庆102井']
};

// 模拟精密工具全局数据库
const INITIAL_TOOLS = [
  {
    code: 'TL-MT-056-K',
    name: '电动坐封工具',
    model: 'E-Setter 3.0',
    status: '在库', // 在库, 离库, 地点变更, 报废
    useCount: 12,
    lifespanLimit: 30,
    location: '基地总库',
    operator: '系统初始化',
    lastUpdateTime: '2026-06-15 08:30:00',
    checkoutTime: null, // 出库时间，用来做超期预警
    history: [
      { time: '2026-06-01 09:00:00', type: '建档入库', detail: '新购入库建档，设定寿命阈值 30 次', operator: '张建国' },
      { time: '2026-06-05 10:00:00', type: '领用出库', detail: '领用出库，去往 [威页23-4井]', operator: '张建国' },
      { time: '2026-06-10 16:30:00', type: '归库保养', detail: '一级保养完成，更换密封圈 x 2，使用寿命+1 (当前12次)', operator: '李志刚' }
    ]
  },
  {
    code: 'TL-BG-112-B',
    name: '阿瓦隆桥塞',
    model: 'Avalon-Bridge 10',
    status: '在库',
    useCount: 28, // 剩余 2 次，寿命临期
    lifespanLimit: 30,
    location: '基地总库',
    operator: '系统初始化',
    lastUpdateTime: '2026-06-17 14:20:00',
    checkoutTime: null,
    history: [
      { time: '2025-11-12 10:00:00', type: '建档入库', detail: '初始化建档，设定寿命阈值 30 次', operator: '王超' },
      { time: '2026-06-17 14:20:00', type: '归库保养', detail: '二级保养完成，使用寿命累计已达 28 次', operator: '赵强' }
    ]
  },
  {
    code: 'TL-MT-099-H',
    name: '电动坐封工具',
    model: 'E-Setter 2.0',
    status: '在库',
    useCount: 30, // 达到阈值，寿命超期拦截
    lifespanLimit: 30,
    location: '基地总库',
    operator: '系统初始化',
    lastUpdateTime: '2026-06-16 11:00:00',
    checkoutTime: null,
    history: [
      { time: '2025-08-20 09:30:00', type: '建档入库', detail: '初始化建档，设定寿命阈值 30 次', operator: '张建国' },
      { time: '2026-06-16 11:00:00', type: '归库保养', detail: '使用寿命累计达 30 次，进入待报废强制拦截状态', operator: '李志刚' }
    ]
  },
  {
    code: 'TL-BG-203-A',
    name: '阿瓦隆桥塞',
    model: 'Avalon-Bridge 12',
    status: '离库',
    useCount: 15,
    lifespanLimit: 40,
    location: '川科1井',
    operator: '王超',
    lastUpdateTime: '2026-06-14 09:15:00',
    checkoutTime: '2026-05-10 09:00:00', // 假定出库了很久，已触发超期警告
    history: [
      { time: '2026-05-10 09:00:00', type: '建档入库', detail: '建档入库，寿命批复上限 40 次', operator: '王超' },
      { time: '2026-06-14 09:15:00', type: '领用出库', detail: '出库领用，去往 [川科1井]，默认归还周期 30 天', operator: '王超' }
    ]
  }
];

// 模拟配件全局数据库
const INITIAL_ACCESSORIES = [
  {
    barcode: 'ACC-RING-001',
    name: '氟橡胶密封圈 O-Ring',
    spec: '120mm x 5mm',
    unit: '个',
    safetyStock: 20,
    currentStock: 45
  },
  {
    barcode: 'ACC-BOLT-002',
    name: '高强防腐螺栓',
    spec: 'M16 x 80',
    unit: '套',
    safetyStock: 50,
    currentStock: 15 // 低于安全库存
  },
  {
    barcode: 'ACC-SEAL-003',
    name: '井下密封金属垫',
    spec: 'DN100',
    unit: '片',
    safetyStock: 10,
    currentStock: 25
  }
];

// 挂载至 window
window.MOCK_ROLES = MOCK_ROLES;
window.INITIAL_TERMINALS = INITIAL_TERMINALS;
window.INITIAL_DICTS = INITIAL_DICTS;
window.INITIAL_TOOLS = INITIAL_TOOLS;
window.INITIAL_ACCESSORIES = INITIAL_ACCESSORIES;
