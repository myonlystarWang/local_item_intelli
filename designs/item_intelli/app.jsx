const { useState, useEffect } = React;

function App() {
  // ─────────────────────────────────────────────────────────────
  // 共享状态与数据库底座
  // ─────────────────────────────────────────────────────────────
  
  // 网络环境
  const [isOnline, setIsOnline] = useState(true); 
  const [syncing, setSyncing] = useState(false);
  
  // Web 数据库 (Server 集中节点)
  const [webTools, setWebTools] = useState(window.INITIAL_TOOLS);
  const [webAccessories, setWebAccessories] = useState(window.INITIAL_ACCESSORIES);
  const [dicts, setDicts] = useState(window.INITIAL_DICTS);
  const [syncReport, setSyncReport] = useState([]);
  
  // 移动端本地存储 (SQLite 离线数据)
  const [localTools, setLocalTools] = useState(window.INITIAL_TOOLS);
  const [localAccessories, setLocalAccessories] = useState(window.INITIAL_ACCESSORIES);
  const [localDicts, setLocalDicts] = useState(window.INITIAL_DICTS);
  const [localLogs, setLocalLogs] = useState([]); // 离线待同步记录
  
  // 物理模拟控制器
  const [simulatedScanCode, setSimulatedScanCode] = useState('TL-MT-056-K');
  
  // App UI 路由状态
  const [activeAppScreen, setActiveAppScreen] = useState('home'); // home, detail, maintenance, sync
  const [selectedAppToolCode, setSelectedAppToolCode] = useState(null);
  
  // Web UI 路由状态
  const [activeWebPage, setActiveWebPage] = useState('dashboard'); // dashboard, lifecycle
  const [selectedWebToolCode, setSelectedWebToolCode] = useState('TL-MT-056-K');
  
  // Web 端控制弹窗
  const [showCreateToolModal, setShowCreateToolModal] = useState(false);
  const [showImportModal, setShowImportModal] = useState(false);
  const [showAddAccModal, setShowAddAccModal] = useState(false);
  const [showAddDictModal, setShowAddDictModal] = useState(false);
  
  // 模拟 Excel 导出弹窗
  const [exportModal, setExportModal] = useState({ show: false, type: '', data: null });

  // Web 表单数据
  const [newTool, setNewTool] = useState({ code: '', name: '电动坐封工具', model: '', lifespanLimit: 30, location: '基地总库' });
  const [addAcc, setAddAcc] = useState({ barcode: 'ACC-RING-001', qty: 10 });
  const [newWellbore, setNewWellbore] = useState('');
  const [importingFile, setImportingFile] = useState(null); // 模拟上传的文件名
  const [importingProgress, setImportingProgress] = useState(0);

  // App 业务表单数据
  const [appForm, setAppForm] = useState({
    operator: '张建国',
    team: '川庆钻探一队',
    wellbore: '川科1井',
    returnDays: 30
  });

  // App 维保核销数据
  const [tempConsumables, setTempConsumables] = useState([]);
  const [selectedAccessoryBarcode, setSelectedAccessoryBarcode] = useState('ACC-RING-001');
  const [accessoryQty, setAccessoryQty] = useState(1);
  const [maintenanceLevel, setMaintenanceLevel] = useState('一级保养');

  // 本地离线SQLite自动对齐
  useEffect(() => {
    if (isOnline && localLogs.length === 0) {
      setLocalTools(webTools);
      setLocalAccessories(webAccessories);
      setLocalDicts(dicts);
    }
  }, [isOnline, webTools, webAccessories, dicts]);

  // ─────────────────────────────────────────────────────────────
  // 移动端 App 业务逻辑
  // ─────────────────────────────────────────────────────────────
  
  const handleTriggerScan = (code) => {
    setSimulatedScanCode(code);
    setSelectedAppToolCode(code);
    setActiveAppScreen('detail');
  };

  // 领用出库
  const handleAppCheckOut = () => {
    const target = localTools.find(t => t.code === selectedAppToolCode);
    if (!target) return;
    
    if (target.useCount >= target.lifespanLimit) {
      alert("【拦截】寿命次数已达到阈值限制，边缘状态机强行封锁，严禁领用出库！");
      return;
    }
    if (target.status !== '在库') {
      alert("【拦截】出库前置状态必须为 [在库]，当前状态为: " + target.status);
      return;
    }

    const timestamp = new Date().toLocaleString();
    const updated = localTools.map(t => {
      if (t.code === selectedAppToolCode) {
        return {
          ...t,
          status: '离库',
          location: appForm.wellbore,
          operator: appForm.operator,
          lastUpdateTime: timestamp,
          checkoutTime: timestamp,
          history: [
            { time: timestamp, type: '领用出库', detail: `现场领用出库，去往 [${appForm.wellbore}]，责任人: ${appForm.operator}`, operator: appForm.operator },
            ...t.history
          ]
        };
      }
      return t;
    });

    setLocalTools(updated);
    
    const newLog = {
      timestamp: Date.now(),
      timeStr: timestamp,
      type: 'CHECKOUT',
      toolCode: selectedAppToolCode,
      operator: appForm.operator,
      detail: {
        wellbore: appForm.wellbore,
        team: appForm.team,
        returnDays: appForm.returnDays
      }
    };
    setLocalLogs([...localLogs, newLog]);
    
    if (isOnline) {
      triggerInstantSync([...localLogs, newLog]);
    } else {
      setActiveAppScreen('home');
    }
  };

  // 地点变更
  const handleAppChangeLocation = (wellbore) => {
    const timestamp = new Date().toLocaleString();
    const updated = localTools.map(t => {
      if (t.code === selectedAppToolCode) {
        return {
          ...t,
          location: wellbore,
          lastUpdateTime: timestamp,
          history: [
            { time: timestamp, type: '工况变更', detail: `变更作业井号为 [${wellbore}]`, operator: appForm.operator },
            ...t.history
          ]
        };
      }
      return t;
    });

    setLocalTools(updated);
    
    const newLog = {
      timestamp: Date.now(),
      timeStr: timestamp,
      type: 'CHANGE_LOC',
      toolCode: selectedAppToolCode,
      operator: appForm.operator,
      detail: { wellbore }
    };
    setLocalLogs([...localLogs, newLog]);

    if (isOnline) {
      triggerInstantSync([...localLogs, newLog]);
    } else {
      setActiveAppScreen('home');
    }
  };

  // 配件消耗添加
  const handleAddConsumable = () => {
    const acc = localAccessories.find(a => a.barcode === selectedAccessoryBarcode);
    if (!acc) return;
    if (acc.currentStock < accessoryQty) {
      alert("【本地库存不足】手持终端离线缓存的可用配件库存不足！");
      return;
    }
    
    setLocalAccessories(localAccessories.map(a => {
      if (a.barcode === selectedAccessoryBarcode) {
        return { ...a, currentStock: a.currentStock - accessoryQty };
      }
      return a;
    }));

    const existIdx = tempConsumables.findIndex(t => t.barcode === selectedAccessoryBarcode);
    if (existIdx > -1) {
      const updated = [...tempConsumables];
      updated[existIdx].qty += accessoryQty;
      setTempConsumables(updated);
    } else {
      setTempConsumables([...tempConsumables, { barcode: selectedAccessoryBarcode, name: acc.name, qty: accessoryQty }]);
    }
  };

  // 归库保养提交
  const handleAppSubmitMaintenance = () => {
    const target = localTools.find(t => t.code === selectedAppToolCode);
    if (!target) return;

    const timestamp = new Date().toLocaleString();
    const updated = localTools.map(t => {
      if (t.code === selectedAppToolCode) {
        const nextCount = t.useCount + 1;
        const details = `${maintenanceLevel}已完成。核销消耗配件：${tempConsumables.map(c => `${c.name} x ${c.qty}`).join(', ') || '无'}。累计使用寿命+1 (当前 ${nextCount} 次)。`;
        return {
          ...t,
          status: '在库',
          useCount: nextCount,
          location: '基地总库',
          lastUpdateTime: timestamp,
          checkoutTime: null,
          history: [
            { time: timestamp, type: '归库保养', detail: details, operator: appForm.operator },
            ...t.history
          ]
        };
      }
      return t;
    });

    setLocalTools(updated);

    const newLog = {
      timestamp: Date.now(),
      timeStr: timestamp,
      type: 'MAINTAIN',
      toolCode: selectedAppToolCode,
      operator: appForm.operator,
      detail: {
        level: maintenanceLevel,
        consumables: tempConsumables
      }
    };

    setLocalLogs([...localLogs, newLog]);
    setTempConsumables([]);
    
    if (isOnline) {
      triggerInstantSync([...localLogs, newLog]);
    } else {
      setActiveAppScreen('home');
    }
  };

  // ─────────────────────────────────────────────────────────────
  // 同步解析引擎与冲突对齐 (时间戳优先)
  // ─────────────────────────────────────────────────────────────
  
  const triggerInstantSync = (logsToSync) => {
    setSyncing(true);
    setTimeout(() => {
      processSyncLogs(logsToSync);
      setSyncing(false);
      setActiveAppScreen('home');
    }, 600);
  };

  const handleManualSync = () => {
    if (!isOnline) {
      alert("同步失败：未连入局域网 Wi-Fi，无法与库房中枢握手！");
      return;
    }
    
    setSyncing(true);
    setTimeout(() => {
      processSyncLogs(localLogs);
      setSyncing(false);
      setLocalLogs([]);
    }, 1200);
  };

  const processSyncLogs = (logs) => {
    if (logs.length === 0) {
      setSyncReport([{ type: 'info', text: '无本地离线操作日志需要同步。双端数据已对齐。', time: new Date().toLocaleTimeString() }]);
      return;
    }

    const sortedLogs = [...logs].sort((a, b) => a.timestamp - b.timestamp);
    
    let currentWebTools = [...webTools];
    let currentWebAccessories = [...webAccessories];
    let reports = [];

    sortedLogs.forEach(log => {
      const toolCode = log.toolCode;
      const dbTool = currentWebTools.find(t => t.code === toolCode);
      
      if (!dbTool) {
        reports.push({ type: 'error', text: `未找到工具编码 [${toolCode}]，日志同步已忽略。`, time: log.timeStr });
        return;
      }

      if (log.type === 'CHECKOUT') {
        if (dbTool.status !== '在库') {
          reports.push({
            type: 'conflict',
            text: `【冲突拦截】工具 [${toolCode}] 离线出库日志同步遭拒。终端于 ${log.timeStr} 登记领用，但全局总账中该资产当前已处于 [${dbTool.status}] 状态。重复出库操作已被强行丢弃。`,
            time: log.timeStr
          });
          return;
        }
        if (dbTool.useCount >= dbTool.lifespanLimit) {
          reports.push({
            type: 'conflict',
            text: `【寿命限制】工具 [${toolCode}] 同步失败：检测到该工具累计使用次数已满，无法完成同步。`,
            time: log.timeStr
          });
          return;
        }

        currentWebTools = currentWebTools.map(t => {
          if (t.code === toolCode) {
            return {
              ...t,
              status: '离库',
              location: log.detail.wellbore,
              operator: log.operator,
              lastUpdateTime: log.timeStr,
              checkoutTime: log.timeStr,
              history: [
                { time: log.timeStr, type: '领用出库', detail: `[同步确认] 出库去往 [${log.detail.wellbore}]，责任人: ${log.operator}`, operator: log.operator },
                ...t.history
              ]
            };
          }
          return t;
        });
        reports.push({ type: 'success', text: `工具 [${toolCode}] 出库至 [${log.detail.wellbore}] 同步对齐成功。`, time: log.timeStr });

      } else if (log.type === 'CHANGE_LOC') {
        currentWebTools = currentWebTools.map(t => {
          if (t.code === toolCode) {
            return {
              ...t,
              location: log.detail.wellbore,
              lastUpdateTime: log.timeStr,
              history: [
                { time: log.timeStr, type: '工况变更', detail: `[同步确认] 确认工况变更至井号 [${log.detail.wellbore}]`, operator: log.operator },
                ...t.history
              ]
            };
          }
          return t;
        });
        reports.push({ type: 'success', text: `工具 [${toolCode}] 工况地点变更至 [${log.detail.wellbore}]。`, time: log.timeStr });

      } else if (log.type === 'MAINTAIN') {
        let consumableFail = false;
        log.detail.consumables.forEach(item => {
          const globalAcc = currentWebAccessories.find(a => a.barcode === item.barcode);
          if (!globalAcc || globalAcc.currentStock < item.qty) {
            consumableFail = true;
          }
        });

        if (consumableFail) {
          reports.push({
            type: 'error',
            text: `【配件库存不足】工具 [${toolCode}] 归库保养同步失败：零配件全局安全储备不足，核销被强行终止！`,
            time: log.timeStr
          });
          return;
        }

        log.detail.consumables.forEach(item => {
          currentWebAccessories = currentWebAccessories.map(a => {
            if (a.barcode === item.barcode) {
              return { ...a, currentStock: a.currentStock - item.qty };
            }
            return a;
          });
        });

        currentWebTools = currentWebTools.map(t => {
          if (t.code === toolCode) {
            const nextCount = t.useCount + 1;
            const desc = `[同步确认] 维保确认归库，级别: ${log.detail.level}。核销配件: ${log.detail.consumables.map(c => `${c.name} x ${c.qty}`).join(', ') || '无'}。寿命+1 (${nextCount}/${t.lifespanLimit})`;
            return {
              ...t,
              status: '在库',
              useCount: nextCount,
              location: '基地总库',
              checkoutTime: null,
              lastUpdateTime: log.timeStr,
              history: [
                { time: log.timeStr, type: '归库保养', detail: desc, operator: log.operator },
                ...t.history
              ]
            };
          }
          return t;
        });

        reports.push({ type: 'success', text: `工具 [${toolCode}] 维保数据核对无误，全局寿命计数更新为 ${dbTool.useCount + 1}。`, time: log.timeStr });
      }
    });

    setWebTools(currentWebTools);
    setWebAccessories(currentWebAccessories);
    setLocalTools(currentWebTools);
    setLocalAccessories(currentWebAccessories);
    setLocalDicts(dicts); 
    setSyncReport(reports);
  };

  // 模拟并发冲突日志生成 (终端 A 与 B 离线同设备领用冲突)
  const handleSimulateConflict = () => {
    setIsOnline(false);
    
    const timestampA = new Date(Date.now() - 5000).toLocaleString();
    const logA = {
      timestamp: Date.now() - 5000,
      timeStr: timestampA,
      type: 'CHECKOUT',
      toolCode: 'TL-MT-056-K',
      operator: '张建国',
      detail: { wellbore: '川科1井', team: '川庆钻探一队', returnDays: 30 }
    };

    const timestampB = new Date().toLocaleString();
    const logB = {
      timestamp: Date.now(),
      timeStr: timestampB,
      type: 'CHECKOUT',
      toolCode: 'TL-MT-056-K',
      operator: '李志刚',
      detail: { wellbore: '深地塔科1井', team: '中原石油三队', returnDays: 15 }
    };

    setLocalTools(localTools.map(t => {
      if (t.code === 'TL-MT-056-K') {
        return { ...t, status: '离库', location: '川科1井', lastUpdateTime: timestampA };
      }
      return t;
    }));

    setLocalLogs([...localLogs, logA, logB]);
    alert("【冲突数据已生成】已成功模拟手持终端 A 和 B 离线时同时领用工具 TL-MT-056-K。\n\n请开启左侧“网络开关”并点击“一键数据同步”，查看冲突解析结果！");
  };

  // ─────────────────────────────────────────────────────────────
  // Web 管理端录入、补货、字典与导入
  // ─────────────────────────────────────────────────────────────

  // 单一资产手动建档入库
  const handleCreateTool = () => {
    if (!newTool.code || !newTool.model) {
      alert("请填写完整的资产唯一编码和规格型号！");
      return;
    }
    if (webTools.some(t => t.code === newTool.code)) {
      alert("该资产唯一编码在系统数据库中已存在！");
      return;
    }

    const timestamp = new Date().toLocaleString();
    const created = {
      ...newTool,
      status: '在库',
      useCount: 0,
      operator: '库管员',
      lastUpdateTime: timestamp,
      checkoutTime: null,
      history: [
        { time: timestamp, type: '建档入库', detail: `库管员通过管理端完成资产手动建档，设定寿命上限为 ${newTool.lifespanLimit} 次`, operator: '库管员' }
      ]
    };

    const updatedTools = [...webTools, created];
    setWebTools(updatedTools);
    setShowCreateToolModal(false);
    setNewTool({ code: '', name: '电动坐封工具', model: '', lifespanLimit: 30, location: '基地总库' });
    
    if (isOnline) {
      setLocalTools(updatedTools);
    }
  };

  // 模拟批量 Excel 文件上传与数据合流 (批量录入场景)
  const handleTriggerBatchImport = () => {
    if (!importingFile) {
      alert("请先选择或拖拽 Excel 文件导入！");
      return;
    }
    
    // 模拟一个进度条效果
    setImportingProgress(10);
    const interval = setInterval(() => {
      setImportingProgress(p => {
        if (p >= 100) {
          clearInterval(interval);
          completeBatchImport();
          return 100;
        }
        return p + 30;
      });
    }, 200);
  };

  const completeBatchImport = () => {
    const timestamp = new Date().toLocaleString();
    const batchImportedTools = [
      {
        code: 'TL-MT-088-W',
        name: '电动坐封工具',
        model: 'E-Setter 3.0',
        status: '在库',
        useCount: 0,
        lifespanLimit: 30,
        location: '基地总库',
        operator: 'Excel批量导入',
        lastUpdateTime: timestamp,
        checkoutTime: null,
        history: [{ time: timestamp, type: '批量建档', detail: '通过 Excel 资产总表批量导入建档成功', operator: '库管员' }]
      },
      {
        code: 'TL-BG-301-C',
        name: '阿瓦隆桥塞',
        model: 'Avalon-Bridge 12',
        status: '在库',
        useCount: 0,
        lifespanLimit: 40,
        location: '基地总库',
        operator: 'Excel批量导入',
        lastUpdateTime: timestamp,
        checkoutTime: null,
        history: [{ time: timestamp, type: '批量建档', detail: '通过 Excel 资产总表批量导入建档成功', operator: '库管员' }]
      }
    ];

    const updated = [...webTools, ...batchImportedTools];
    setWebTools(updated);
    
    alert(`【导入成功】成功解析文件 [${importingFile}]。批量新增了 2 套工具：\n- TL-MT-088-W (电动坐封工具)\n- TL-BG-301-C (阿瓦隆桥塞)\n系统账目已同步更新。`);
    
    setShowImportModal(false);
    setImportingFile(null);
    setImportingProgress(0);

    if (isOnline) {
      setLocalTools(updated);
    }
  };

  // 配件补货
  const handleAddAccessoryStock = () => {
    const updated = webAccessories.map(a => {
      if (a.barcode === addAcc.barcode) {
        return { ...a, currentStock: a.currentStock + parseInt(addAcc.qty) };
      }
      return a;
    });

    setWebAccessories(updated);
    setShowAddAccModal(false);

    if (isOnline) {
      setLocalAccessories(updated);
    }
  };

  // 新增井号字典下发
  const handleAddWellbore = () => {
    if (!newWellbore.trim()) return;
    if (dicts.wellbores.includes(newWellbore)) {
      alert("该井号已存在！");
      return;
    }

    const updatedDicts = {
      ...dicts,
      wellbores: [...dicts.wellbores, newWellbore]
    };
    
    setDicts(updatedDicts);
    setShowAddDictModal(false);
    setNewWellbore('');
    
    if (isOnline) {
      setLocalDicts(updatedDicts);
    }
  };

  // 报表模拟导出格式构建
  const handleExportData = (type) => {
    let data = [];
    if (type === 'assets') {
      data = webTools.map(t => ({
        '工具唯一编码': t.code,
        '工具名称': t.name,
        '规格型号': t.model,
        '当前运行状态': t.status,
        '已用次数/寿命上限': `${t.useCount} / ${t.lifespanLimit}`,
        '当前位置': t.location,
        '最近操作人': t.operator,
        '最后更新时间': t.lastUpdateTime
      }));
    } else if (type === 'accessories') {
      data = webAccessories.map(a => ({
        '零配件条码': a.barcode,
        '配件名称': a.name,
        '规格型号': a.spec,
        '当前库存量': `${a.currentStock} ${a.unit}`,
        '安全警戒水位': `${a.safetyStock} ${a.unit}`,
        '水位警告': a.currentStock < a.safetyStock ? '⚠️ 严重不足' : '正常'
      }));
    } else {
      webTools.forEach(t => {
        t.history.forEach(h => {
          data.push({
            '工具编码': t.code,
            '历史变更时间': h.time,
            '操作类型': h.type,
            '操作人': h.operator,
            '履历记录明细': h.detail
          });
        });
      });
      data.sort((a,b) => b['历史变更时间'].localeCompare(a['历史变更时间']));
    }

    setExportModal({ show: true, type, data });
  };

  // ─────────────────────────────────────────────────────────────
  // 渲染计算
  // ─────────────────────────────────────────────────────────────
  
  const isToolOverdue = (tool) => {
    if (tool.status !== '离库' || !tool.checkoutTime) return false;
    return tool.code === 'TL-BG-203-A'; // 仅以第一版假数据作为预警展示
  };

  const kpiTotalTools = webTools.length;
  const kpiInStore = webTools.filter(t => t.status === '在库').length;
  const kpiOutStore = webTools.filter(t => t.status === '离库').length;
  const kpiAlerts = webTools.filter(t => (t.lifespanLimit - t.useCount) <= 3 || isToolOverdue(t)).length;
  const kpiLocked = webTools.filter(t => t.useCount >= t.lifespanLimit).length;

  return (
    <div className="prototype-container">
      {/* 顶部纯净标题栏 */}
      <header className="proto-header">
        <h1>精密工具智能化管理系统 <span>双端交互式原型</span></h1>
        
        <div className="version-tag">
          <span>局域网 Wi-Fi 通信:</span>
          {isOnline ? (
            <span className="mode-badge mode-online">联网对齐</span>
          ) : (
            <span className="mode-badge mode-offline">断网离线</span>
          )}
        </div>
      </header>

      <div className="main-layout">
        
        {/* 左侧：物理世界模拟器 */}
        <aside className="simulation-panel">
          <div className="sim-section">
            <h3>1. 网络信道环境</h3>
            <button className={`sim-btn ${isOnline ? 'active' : ''}`} onClick={() => setIsOnline(true)}>
              🌐 局域网连通状态 (在线)
            </button>
            <button className={`sim-btn ${!isOnline ? 'active' : ''}`} onClick={() => setIsOnline(false)}>
              🔌 野外井口断网 (离线)
            </button>
          </div>

          <div className="sim-section">
            <h3>2. 模拟物理打标扫码</h3>
            <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>
              点击下方已刻码设备模拟手持终端摄像头对准识别：
            </div>
            {localTools.map(t => (
              <button 
                key={t.code} 
                className="sim-btn"
                onClick={() => handleTriggerScan(t.code)}
                style={{ fontSize: '11px', padding: '6px 10px' }}
              >
                🛠️ [{t.code}] {t.name}
              </button>
            ))}
            
            {/* 模拟扫描一个未在Web管理端建档的新编码，验证拦截 */}
            <button 
              className="sim-btn"
              onClick={() => handleTriggerScan('TL-MT-999-NEW')}
              style={{ fontSize: '11px', padding: '6px 10px', borderColor: 'var(--status-err)' }}
            >
              ⚠️ [TL-MT-999-NEW] 未建档码
            </button>

            <button 
              className="sim-btn"
              onClick={() => handleTriggerScan('ACC-RING-001')}
              style={{ fontSize: '11px', padding: '6px 10px', borderColor: '#22c55e' }}
            >
              ⚙️ [ACC-RING-001] 配件氟橡胶圈
            </button>
          </div>

          <div className="sim-section">
            <h3>3. 并发冲突同步演示</h3>
            <button 
              className="sim-btn" 
              onClick={handleSimulateConflict}
              style={{ borderColor: 'var(--accent-gold)' }}
            >
              ⚡ 模拟双终端离线冲突
            </button>
          </div>
        </aside>

        {/* 右侧双端展示 */}
        <main className="devices-arena">
          
          {/* ==================== 1. 移动端 App (手持端) ==================== */}
          <div className="device-column">
            <div className="device-label">
              <span style={{ backgroundColor: 'var(--accent-blue)' }}></span>
              手持作业 App (Flutter Material 3)
            </div>
            
            <AndroidDevice dark={true} title={null}>
              <div className="android-screen-wrapper">
                
                {/* App 首页 */}
                {activeAppScreen === 'home' && (
                  <div style={{ padding: '20px', display: 'flex', flexDirection: 'column', gap: '20px', flex: 1 }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderBottom: '1px solid rgba(255,255,255,0.08)', paddingBottom: '12px' }}>
                      <div>
                        <div style={{ fontSize: '16px', fontWeight: 'bold', letterSpacing: '0.5px' }}>精密工具智能化管理</div>
                        <div style={{ fontSize: '10px', color: 'var(--text-secondary)' }}>现场终端工作台 (离线状态机)</div>
                      </div>
                    </div>

                    {/* 智能扫描大卡片 */}
                    <div 
                      onClick={() => handleTriggerScan(simulatedScanCode)}
                      style={{ 
                        background: 'linear-gradient(135deg, #102a43 0%, #1e3c72 100%)',
                        border: '1px solid rgba(255,255,255,0.1)',
                        borderRadius: '16px', padding: '36px 16px', textAlign: 'center', cursor: 'pointer'
                      }}
                      className="pulsate"
                    >
                      <div style={{ fontSize: '36px', marginBottom: '8px' }}>📷</div>
                      <div style={{ fontSize: '18px', fontWeight: 'bold' }}>智能离线扫描</div>
                      <div style={{ fontSize: '11px', color: 'var(--text-secondary)', marginTop: '4px' }}>自动补光、微距优化与防错校验</div>
                    </div>

                    {/* 一键同步大卡片 */}
                    <div 
                      onClick={() => setActiveAppScreen('sync')}
                      style={{ 
                        background: '#131722', border: '1px solid var(--border-color)',
                        borderRadius: '16px', padding: '24px 16px', textAlign: 'center', cursor: 'pointer',
                        position: 'relative'
                      }}
                    >
                      {localLogs.length > 0 && (
                        <span style={{ position: 'absolute', right: '15px', top: '15px', background: 'var(--status-err)', color: '#fff', fontSize: '10px', fontWeight: '700', borderRadius: '50%', width: '20px', height: '20px', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                          {localLogs.length}
                        </span>
                      )}
                      <div style={{ fontSize: '28px', marginBottom: '4px' }}>🔄</div>
                      <div style={{ fontSize: '15px', fontWeight: 'bold' }}>近场对齐同步</div>
                      <div style={{ fontSize: '10px', color: 'var(--text-secondary)', marginTop: '2px' }}>待同步离线日志: {localLogs.length} 条</div>
                    </div>

                    {/* 底部运行概要 */}
                    <div style={{ background: '#121824', borderRadius: '12px', padding: '12px', border: '1px solid var(--border-color)', marginTop: 'auto' }}>
                      <div style={{ fontSize: '10px', color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.5px', marginBottom: '6px', fontWeight: 'bold' }}>同步运行配置</div>
                      <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '12px' }}>
                        <span>同步井号数: {localDicts.wellbores.length} 口</span>
                        <span>下发作业队: {localDicts.teams.length} 个</span>
                      </div>
                    </div>
                  </div>
                )}

                {/* App 详情页 */}
                {activeAppScreen === 'detail' && (() => {
                  const isAccessory = selectedAppToolCode.startsWith('ACC-');
                  if (isAccessory) {
                    const acc = localAccessories.find(a => a.barcode === selectedAppToolCode);
                    return (
                      <div style={{ padding: '20px', display: 'flex', flexDirection: 'column', gap: '16px', flex: 1 }}>
                        <div onClick={() => setActiveAppScreen('home')} style={{ color: 'var(--accent-blue)', cursor: 'pointer', fontSize: '13px' }}>← 返回主页</div>
                        <div style={{ display: 'flex', gap: '12px', alignItems: 'center' }}>
                          <div style={{ fontSize: '32px' }}>⚙️</div>
                          <div>
                            <div style={{ fontSize: '18px', fontWeight: 'bold' }}>{acc?.name}</div>
                            <div style={{ fontSize: '12px', color: 'var(--text-secondary)' }}>配件条码: {acc?.barcode}</div>
                          </div>
                        </div>
                        <div style={{ background: '#131722', borderRadius: '12px', padding: '16px', display: 'flex', flexDirection: 'column', gap: '8px', fontSize: '13px' }}>
                          <div>规格型号: {acc?.spec}</div>
                          <div>当前本地库存: <b>{acc?.currentStock} {acc?.unit}</b></div>
                        </div>
                      </div>
                    );
                  }

                  const tool = localTools.find(t => t.code === selectedAppToolCode);
                  
                  // 针对未登记刻码进行强制拦截 (不再允许App建档，PRD场景一致性改造)
                  if (!tool) {
                    return (
                      <div style={{ padding: '20px', display: 'flex', flexDirection: 'column', gap: '16px', flex: 1 }}>
                        <div onClick={() => setActiveAppScreen('home')} style={{ color: 'var(--accent-blue)', cursor: 'pointer', fontSize: '13px' }}>← 返回主页</div>
                        
                        <div style={{ textAlign: 'center', padding: '30px 10px', display: 'flex', flexDirection: 'column', gap: '16px' }}>
                          <div style={{ fontSize: '48px' }}>🚫</div>
                          <div style={{ fontSize: '18px', fontWeight: 'bold', color: 'var(--status-err)' }}>未登记精密资产！</div>
                          <div style={{ fontSize: '12px', color: 'var(--text-secondary)', lineHeight: '1.6', background: 'rgba(239, 68, 68, 0.08)', padding: '12px', borderRadius: '8px', border: '1px solid rgba(239, 68, 68, 0.2)' }}>
                            物理标识 <b>{selectedAppToolCode}</b> 未在库房管理中枢建档登记。<br/><br/>
                            为规避井下安全及账实混乱隐患，边缘状态机已实施<b>流转拦截</b>，禁止现场出库及变更操作。请联系库管员建档。
                          </div>
                        </div>
                      </div>
                    );
                  }

                  const isLimitReached = tool.useCount >= tool.lifespanLimit;
                  
                  return (
                    <div style={{ padding: '20px', display: 'flex', flexDirection: 'column', gap: '12px', flex: 1, overflowY: 'auto' }}>
                      <div onClick={() => setActiveAppScreen('home')} style={{ color: 'var(--accent-blue)', cursor: 'pointer', fontSize: '13px' }}>← 返回主页</div>
                      
                      <div style={{ display: 'flex', gap: '12px', alignItems: 'center' }}>
                        <div style={{ width: 40, height: 40, borderRadius: '8px', background: 'var(--primary-light)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '20px' }}>🛠️</div>
                        <div>
                          <div style={{ fontSize: '16px', fontWeight: 'bold' }}>{tool.name}</div>
                          <div style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>编码: {tool.code}</div>
                        </div>
                      </div>

                      <div style={{ background: '#131722', padding: '10px 14px', borderRadius: '8px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', fontSize: '12px' }}>
                        <span style={{ color: 'var(--text-secondary)' }}>工具当前状态</span>
                        <span className={`badge ${tool.status === '在库' ? 'badge-in' : 'badge-out'}`}>{tool.status}</span>
                      </div>

                      {isLimitReached && (
                        <div style={{ background: 'rgba(239, 68, 68, 0.12)', border: '1px solid var(--status-err)', borderRadius: '6px', padding: '8px', color: '#fca5a5', fontSize: '11px', lineHeight: '1.4' }}>
                          ⚠️ <b>边缘状态机拦截</b>：该工具已达预定寿命上限 ({tool.useCount}/{tool.lifespanLimit}次)。本地状态机已实施强行阻断，禁止领用下井。
                        </div>
                      )}

                      <div style={{ background: '#131722', borderRadius: '8px', padding: '12px', display: 'flex', flexDirection: 'column', gap: '6px', fontSize: '12px' }}>
                        <div>规格型号: {tool.model}</div>
                        <div style={{ color: isLimitReached ? 'var(--status-err)' : '#fff' }}>累计已使用寿命: {tool.useCount} / {tool.lifespanLimit} 次</div>
                        <div>当前存放地: {tool.location}</div>
                      </div>

                      <div style={{ borderTop: '1px solid rgba(255,255,255,0.08)', paddingTop: '10px', marginTop: '4px' }}>
                        {tool.status === '在库' && !isLimitReached && (
                          <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                            <div style={{ fontSize: '13px', fontWeight: 'bold', color: 'var(--accent-gold)' }}>🚀 领用出库表单</div>
                            
                            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '8px' }}>
                              <div>
                                <label style={{ fontSize: '10px', color: 'var(--text-secondary)' }}>领用责任人</label>
                                <select className="custom-input" value={appForm.operator} onChange={e => setAppForm({...appForm, operator: e.target.value})}>
                                  {localDicts.operators.map(o => <option key={o} value={o}>{o}</option>)}
                                </select>
                              </div>
                              <div>
                                <label style={{ fontSize: '10px', color: 'var(--text-secondary)' }}>作业队</label>
                                <select className="custom-input" value={appForm.team} onChange={e => setAppForm({...appForm, team: e.target.value})}>
                                  {localDicts.teams.map(t => <option key={t} value={t}>{t}</option>)}
                                </select>
                              </div>
                            </div>
                            
                            <div>
                              <label style={{ fontSize: '10px', color: 'var(--text-secondary)' }}>目标作业井号</label>
                              <select className="custom-input" value={appForm.wellbore} onChange={e => setAppForm({...appForm, wellbore: e.target.value})}>
                                {localDicts.wellbores.map(w => <option key={w} value={w}>{w}</option>)}
                              </select>
                            </div>

                            <button onClick={handleAppCheckOut} style={{ background: 'linear-gradient(90deg, #10b981, #059669)', border: 'none', color: '#fff', padding: '10px', borderRadius: '6px', fontWeight: 'bold', cursor: 'pointer', marginTop: '4px' }}>
                              确认领用出库 (离线本地暂存)
                            </button>
                          </div>
                        )}

                        {tool.status === '离库' && (
                          <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
                            <div style={{ background: 'rgba(255,255,255,0.02)', padding: '10px', borderRadius: '6px', border: '1px solid var(--border-color)' }}>
                              <div style={{ fontSize: '12px', fontWeight: 'bold', color: 'var(--accent-blue)', marginBottom: '6px' }}>📍 地点调拨变更</div>
                              <div style={{ display: 'flex', gap: '6px' }}>
                                <select className="custom-input" style={{ flex: 1 }} value={appForm.wellbore} onChange={e => setAppForm({...appForm, wellbore: e.target.value})}>
                                  {localDicts.wellbores.map(w => <option key={w} value={w}>{w}</option>)}
                                </select>
                                <button onClick={() => handleAppChangeLocation(appForm.wellbore)} style={{ background: 'var(--primary-light)', border: 'none', color: '#fff', padding: '0 10px', borderRadius: '6px', cursor: 'pointer', fontSize: '11px' }}>
                                  变更地点
                                </button>
                              </div>
                            </div>

                            <button 
                              onClick={() => {
                                setTempConsumables([]);
                                setActiveAppScreen('maintenance');
                              }}
                              style={{ background: 'linear-gradient(90deg, var(--accent-gold), #b89225)', border: 'none', color: '#000', padding: '10px', borderRadius: '6px', fontWeight: 'bold', cursor: 'pointer' }}
                            >
                              进入归库保养与配件核销
                            </button>
                          </div>
                        )}
                      </div>
                    </div>
                  );
                })()}

                {/* App 维保归库配件核销 */}
                {activeAppScreen === 'maintenance' && (
                  <div style={{ padding: '20px', display: 'flex', flexDirection: 'column', gap: '12px', flex: 1, overflowY: 'auto' }}>
                    <div onClick={() => setActiveAppScreen('detail')} style={{ color: 'var(--accent-blue)', cursor: 'pointer', fontSize: '13px' }}>← 返回详情页</div>
                    
                    <div style={{ fontSize: '14px', fontWeight: 'bold', color: 'var(--accent-gold)' }}>🔧 离线归库保养核销</div>

                    <div>
                      <label style={{ fontSize: '10px', color: 'var(--text-secondary)' }}>保养级别配置</label>
                      <div style={{ display: 'flex', gap: '6px', marginTop: '4px' }}>
                        {['一级保养', '二级保养', '大修'].map(lvl => (
                          <button key={lvl} onClick={() => setMaintenanceLevel(lvl)} style={{ flex: 1, background: maintenanceLevel === lvl ? 'var(--primary)' : 'rgba(255,255,255,0.02)', border: `1px solid ${maintenanceLevel === lvl ? 'var(--accent-blue)' : 'var(--border-color)'}`, color: '#fff', padding: '6px', borderRadius: '6px', fontSize: '11px', cursor: 'pointer' }}>
                            {lvl}
                          </button>
                        ))}
                      </div>
                    </div>

                    <div style={{ background: '#131722', padding: '10px', borderRadius: '8px', border: '1px solid var(--border-color)', fontSize: '12px' }}>
                      <div style={{ fontWeight: 'bold', color: 'var(--text-secondary)', marginBottom: '6px' }}>📦 添加维保消耗配件</div>
                      <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                        <select className="custom-input" value={selectedAccessoryBarcode} onChange={e => setSelectedAccessoryBarcode(e.target.value)}>
                          {localAccessories.map(a => (
                            <option key={a.barcode} value={a.barcode}>{a.name} ({a.currentStock} {a.unit}可用)</option>
                          ))}
                        </select>
                        <div style={{ display: 'flex', gap: '6px' }}>
                          <input type="number" className="custom-input" style={{ width: '60px' }} value={accessoryQty} onChange={e => setAccessoryQty(parseInt(e.target.value) || 1)} min="1" />
                          <button onClick={handleAddConsumable} style={{ flex: 1, background: 'var(--primary-light)', border: 'none', color: '#fff', borderRadius: '6px', cursor: 'pointer' }}>
                            ➕ 配件确认扣减
                          </button>
                        </div>
                      </div>
                    </div>

                    <div>
                      <div style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>已记入本次核销配件：</div>
                      {tempConsumables.length === 0 ? (
                        <div style={{ fontSize: '11px', color: 'var(--text-muted)', fontStyle: 'italic' }}>无零配件扣减记录。</div>
                      ) : (
                        <div style={{ display: 'flex', flexDirection: 'column', gap: '4px', marginTop: '4px' }}>
                          {tempConsumables.map(c => (
                            <div key={c.barcode} style={{ display: 'flex', justifyContent: 'space-between', background: 'rgba(255,255,255,0.02)', padding: '6px 10px', borderRadius: '6px', fontSize: '12px' }}>
                              <span>{c.name}</span>
                              <span style={{ fontWeight: 'bold', color: 'var(--accent-gold)' }}>x {c.qty}</span>
                            </div>
                          ))}
                        </div>
                      )}
                    </div>

                    <button onClick={handleAppSubmitMaintenance} style={{ background: 'linear-gradient(90deg, #10b981, #059669)', border: 'none', color: '#fff', padding: '10px', borderRadius: '6px', fontWeight: 'bold', cursor: 'pointer', marginTop: 'auto' }}>
                      确认保养归库 (寿命次数+1)
                    </button>
                  </div>
                )}

                {/* App 同步控制台 */}
                {activeAppScreen === 'sync' && (
                  <div style={{ padding: '20px', display: 'flex', flexDirection: 'column', gap: '14px', flex: 1 }}>
                    <div onClick={() => setActiveAppScreen('home')} style={{ color: 'var(--accent-blue)', cursor: 'pointer', fontSize: '13px' }}>← 返回主页</div>
                    
                    <div style={{ textAlign: 'center', padding: '16px 0' }}>
                      <div style={{ fontSize: '40px' }} className={syncing ? 'spin' : ''}>🔄</div>
                      <div style={{ fontSize: '16px', fontWeight: 'bold', marginTop: '6px' }}>局域网近场对齐</div>
                      <div style={{ fontSize: '11px', color: 'var(--text-secondary)', marginTop: '2px' }}>
                        使用信道端口: <span style={{ color: 'var(--accent-gold)' }}>PORT-4311</span>
                      </div>
                    </div>

                    <div style={{ background: '#131722', borderRadius: '8px', padding: '12px', border: '1px solid var(--border-color)', fontSize: '12px' }}>
                      <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                        <span>本地离线数据待合并:</span>
                        <span style={{ fontWeight: 'bold', color: 'var(--status-err)' }}>{localLogs.length} 条</span>
                      </div>
                    </div>

                    {localLogs.length > 0 && (
                      <div style={{ flex: 1, overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: '6px' }}>
                        {localLogs.map((l, i) => (
                          <div key={i} style={{ background: 'rgba(255,255,255,0.02)', padding: '8px', borderRadius: '6px', fontSize: '11px', borderLeft: '3px solid var(--accent-blue)' }}>
                            <div style={{ display: 'flex', justifyContent: 'space-between', fontWeight: '500' }}>
                              <span>{l.type === 'CHECKOUT' ? '领用出库' : l.type === 'MAINTAIN' ? '维保核销' : '地点变更'}</span>
                              <span>{l.timeStr.split(' ')[1]}</span>
                            </div>
                            <div style={{ color: 'var(--text-secondary)' }}>工具: {l.toolCode} | 操作人: {l.operator}</div>
                          </div>
                        ))}
                      </div>
                    )}

                    <button
                      onClick={handleManualSync}
                      style={{ background: 'linear-gradient(90deg, var(--accent-blue), #006699)', border: 'none', color: '#fff', padding: '12px', borderRadius: '6px', fontWeight: 'bold', cursor: 'pointer', marginTop: 'auto' }}
                    >
                      {syncing ? '正在连接库房服务器握手...' : '⚡ 启动近场一键同步'}
                    </button>
                  </div>
                )}

              </div>
            </AndroidDevice>
          </div>

          {/* ==================== 2. Web 管理端中枢 ==================== */}
          <div className="device-column" style={{ width: '100%' }}>
            <div className="device-label">
              <span style={{ backgroundColor: 'var(--accent-gold)' }}></span>
              库房管理控制中枢 (Web 局域网系统)
            </div>
            
            <ChromeWindow width="100%" height={740} url="http://192.168.1.100/main/console" tabs={[{ title: '智能工具管理中枢' }]}>
              <div className="web-screen-wrapper">
                
                {/* 侧边导航栏 (已清理，无审计一键导出栏目) */}
                <div style={{ width: '190px', background: '#111b27', borderRight: '1px solid rgba(255,255,255,0.05)', display: 'flex', flexDirection: 'column', gap: '4px', padding: '14px 10px', boxSizing: 'border-box' }}>
                  <div style={{ display: 'flex', gap: '8px', alignItems: 'center', paddingBottom: '12px', borderBottom: '1px solid rgba(255,255,255,0.06)', marginBottom: '12px' }}>
                    <div style={{ width: 28, height: 28, borderRadius: '6px', background: 'linear-gradient(135deg, var(--accent-gold), #8f701c)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '16px' }}>🏢</div>
                    <div>
                      <div style={{ fontSize: '12px', fontWeight: 'bold' }}>总库管理中枢</div>
                      <div style={{ fontSize: '9px', color: 'var(--text-muted)' }}>系统角色: 库管员</div>
                    </div>
                  </div>

                  <button onClick={() => setActiveWebPage('dashboard')} style={{ background: activeWebPage === 'dashboard' ? 'rgba(255,255,255,0.06)' : 'transparent', border: 'none', color: activeWebPage === 'dashboard' ? '#fff' : 'var(--text-secondary)', padding: '10px 14px', borderRadius: '6px', textAlign: 'left', cursor: 'pointer', fontSize: '13px', fontWeight: activeWebPage === 'dashboard' ? 'bold' : 'normal' }}>
                    📊 智能驾驶舱
                  </button>

                  <button onClick={() => setActiveWebPage('lifecycle')} style={{ background: activeWebPage === 'lifecycle' ? 'rgba(255,255,255,0.06)' : 'transparent', border: 'none', color: activeWebPage === 'lifecycle' ? '#fff' : 'var(--text-secondary)', padding: '10px 14px', borderRadius: '6px', textAlign: 'left', cursor: 'pointer', fontSize: '13px', fontWeight: activeWebPage === 'lifecycle' ? 'bold' : 'normal' }}>
                    📋 资产生命周期档案
                  </button>
                </div>

                {/* Web 主工作区 */}
                <div style={{ flex: 1, padding: '20px', display: 'flex', flexDirection: 'column', gap: '20px', background: '#0b0f19', overflowY: 'auto', boxSizing: 'border-box' }}>
                  
                  {/* Web Dashboard */}
                  {activeWebPage === 'dashboard' && (
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
                      
                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                        <div>
                          <div style={{ fontSize: '18px', fontWeight: 'bold' }}>精密工具智能化库房监控大屏</div>
                          <div style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>实时监控资产总账、安全水位及近场握手校验日志</div>
                        </div>
                      </div>

                      {/* KPI 看板 */}
                      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(5, 1fr)', gap: '10px' }}>
                        {[
                          { name: '资产底座总数', val: kpiTotalTools, desc: '一物一档案', color: '#fff' },
                          { name: '在库空闲待命', val: kpiInStore, desc: '可用工具', color: 'var(--status-in)' },
                          { name: '现场作业工具', val: kpiOutStore, desc: '已离库', color: 'var(--status-out)' },
                          { name: '寿命/异常报警', val: kpiAlerts, desc: '需强保养', color: 'var(--status-err)' },
                          { name: '强行锁死设备', val: kpiLocked, desc: '禁止流转', color: '#c084fc' }
                        ].map((k, i) => (
                          <div key={i} style={{ background: '#121824', padding: '12px', borderRadius: '8px', border: '1px solid var(--border-color)' }}>
                            <div style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>{k.name}</div>
                            <div style={{ fontSize: '24px', fontWeight: 'bold', color: k.color, margin: '2px 0' }}>{k.val}</div>
                            <div style={{ fontSize: '9px', color: 'var(--text-muted)' }}>{k.desc}</div>
                          </div>
                        ))}
                      </div>

                      <div style={{ display: 'grid', gridTemplateColumns: '1fr 320px', gap: '20px' }}>
                        
                        {/* 左侧：资产列表卡片 (美观的纯展示监控) */}
                        <div style={{ background: '#121824', padding: '16px', borderRadius: '10px', border: '1px solid var(--border-color)' }}>
                          <div style={{ fontSize: '13px', fontWeight: 'bold', marginBottom: '16px', borderLeft: '2.5px solid var(--accent-gold)', paddingLeft: '8px' }}>
                            🛠️ 资产在线监控图谱
                          </div>

                          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: '12px' }}>
                            {webTools.map(t => {
                              const isOverdue = isToolOverdue(t);
                              const isMax = t.useCount >= t.lifespanLimit;
                              const isNear = (t.lifespanLimit - t.useCount) <= 3;
                              
                              let statusColor = 'var(--status-in)';
                              if (isOverdue || isMax) statusColor = 'var(--status-err)';
                              else if (isNear) statusColor = 'var(--status-out)';

                              return (
                                <div key={t.code} style={{ background: '#182030', padding: '12px', borderRadius: '8px', border: `1px solid ${isOverdue ? 'var(--status-err)' : 'var(--border-color)'}` }}>
                                  <div style={{ display: 'flex', justifycontent: 'space-between', fontSize: '11px', alignItems: 'center', marginBottom: '4px' }}>
                                    <span style={{ fontWeight: 'bold' }}>{t.code}</span>
                                    <span className={`badge ${t.status === '在库' ? 'badge-in' : 'badge-out'}`} style={{ fontSize: '9px' }}>{t.status}</span>
                                  </div>
                                  <div style={{ fontSize: '13px', color: '#fff', fontWeight: '500' }}>{t.name}</div>
                                  <div style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>规格: {t.model}</div>
                                  
                                  {isOverdue && (
                                    <div style={{ color: 'var(--status-err)', fontSize: '10px', fontWeight: 'bold', marginTop: '2px' }}>⚠️ 离库归还超期警告</div>
                                  )}

                                  <div style={{ marginTop: '8px' }}>
                                    <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '10px', color: 'var(--text-secondary)', marginBottom: '3px' }}>
                                      <span>使用寿命</span>
                                      <span style={{ color: statusColor }}>{t.useCount}/{t.lifespanLimit} 次</span>
                                    </div>
                                    <div style={{ height: '4px', background: 'rgba(255,255,255,0.06)', borderRadius: '10px', overflow: 'hidden' }}>
                                      <div style={{ height: '100%', width: `${Math.min((t.useCount / t.lifespanLimit) * 100, 100)}%`, backgroundColor: statusColor }} />
                                    </div>
                                  </div>
                                </div>
                              );
                            })}
                          </div>
                        </div>

                        {/* 右侧：配件储备 与 近场握手校验日志 (极度纯净) */}
                        <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
                          
                          {/* 配件警戒水位监控 */}
                          <div style={{ background: '#121824', padding: '16px', borderRadius: '10px', border: '1px solid var(--border-color)' }}>
                            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '12px' }}>
                              <span style={{ fontSize: '13px', fontWeight: 'bold', color: 'var(--text-secondary)' }}>📦 耗材安全水位</span>
                              <button onClick={() => setShowAddAccModal(true)} style={{ background: 'rgba(255,255,255,0.04)', border: '1px solid var(--border-color)', color: '#fff', fontSize: '10px', padding: '3px 8px', borderRadius: '4px', cursor: 'pointer' }}>
                                ⚙️ 配件补库入库
                              </button>
                            </div>
                            <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                              {webAccessories.map(a => {
                                const isLow = a.currentStock < a.safetyStock;
                                return (
                                  <div key={a.barcode} style={{ display: 'flex', justifyContent: 'space-between', fontSize: '11px', background: '#182030', padding: '8px 10px', borderRadius: '4px' }}>
                                    <span>{a.name}</span>
                                    <span style={{ fontWeight: 'bold', color: isLow ? 'var(--status-err)' : 'var(--status-in)' }}>
                                      {a.currentStock} {a.unit}
                                    </span>
                                  </div>
                                );
                              })}
                            </div>
                          </div>

                          {/* 同步校验报告 */}
                          <div style={{ background: '#121824', padding: '16px', borderRadius: '10px', border: '1px solid var(--border-color)', flex: 1, display: 'flex', flexDirection: 'column' }}>
                            <div style={{ fontSize: '13px', fontWeight: 'bold', color: 'var(--text-secondary)', marginBottom: '8px' }}>🔄 局域网同步校验日志</div>
                            
                            <div style={{ flex: 1, overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: '8px', maxHeight: '160px' }}>
                              {syncReport.length === 0 ? (
                                <div style={{ fontSize: '11px', color: 'var(--text-muted)', textAlign: 'center', padding: '20px 0' }}>
                                  暂无新近场同步日志报告。<br/>请在左侧面板模拟同步操作。
                                </div>
                              ) : (
                                syncReport.map((rep, idx) => {
                                  let color = '#fff';
                                  let bg = 'rgba(255,255,255,0.02)';
                                  if (rep.type === 'success') { bg = 'rgba(16, 185, 129, 0.08)'; color = '#34d399'; }
                                  if (rep.type === 'conflict' || rep.type === 'error') { bg = 'rgba(239, 68, 68, 0.08)'; color = '#fca5a5'; }
                                  
                                  return (
                                    <div key={idx} style={{ background: bg, padding: '8px', borderRadius: '6px', border: '1px solid var(--border-color)', fontSize: '11px' }}>
                                      <div style={{ display: 'flex', justifyContent: 'space-between', color: 'var(--text-muted)', marginBottom: '2px' }}>
                                        <span>{rep.type === 'success' ? '✅ 对齐成功' : '⚠️ 冲突校验'}</span>
                                        <span>{rep.time}</span>
                                      </div>
                                      <div style={{ color }}>{rep.text}</div>
                                    </div>
                                  );
                                })
                              )}
                            </div>
                          </div>

                        </div>

                      </div>
                    </div>
                  )}

                  {/* Web 生命周期档案页 */}
                  {activeWebPage === 'lifecycle' && (
                    <div style={{ display: 'flex', gap: '20px', flex: 1 }}>
                      
                      {/* 左侧列表 */}
                      <div style={{ flex: 1, background: '#121824', padding: '16px', borderRadius: '10px', border: '1px solid var(--border-color)', display: 'flex', flexDirection: 'column' }}>
                        
                        {/* 优雅整理的右上角按钮组 (包含导入、录入、导出) */}
                        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '14px', borderBottom: '1px solid rgba(255,255,255,0.05)', paddingBottom: '10px' }}>
                          <span style={{ fontSize: '15px', fontWeight: 'bold' }}>精密资产数据总账</span>
                          
                          <div style={{ display: 'flex', gap: '8px' }}>
                            <button onClick={() => setShowImportModal(true)} style={{ background: 'rgba(255,255,255,0.04)', border: '1px solid var(--border-color)', color: '#fff', fontSize: '11px', padding: '6px 12px', borderRadius: '4px', cursor: 'pointer', transition: 'var(--transition-smooth)' }}>
                              📊 Excel 批量导入
                            </button>
                            <button onClick={() => setShowCreateToolModal(true)} style={{ background: 'var(--primary-light)', border: '1px solid var(--accent-blue)', color: '#fff', fontSize: '11px', padding: '6px 12px', borderRadius: '4px', cursor: 'pointer' }}>
                              ➕ 手动建档入库
                            </button>
                            <button onClick={() => setShowAddDictModal(true)} style={{ background: 'rgba(255,255,255,0.04)', border: '1px solid var(--border-color)', color: '#fff', fontSize: '11px', padding: '6px 12px', borderRadius: '4px', cursor: 'pointer' }}>
                              井号字典增补
                            </button>
                            <div style={{ position: 'relative', display: 'inline-block' }}>
                              <select 
                                onChange={(e) => {
                                  if (e.target.value) {
                                    handleExportData(e.target.value);
                                    e.target.value = ''; // 重置
                                  }
                                }}
                                style={{ background: 'var(--accent-gold)', border: 'none', color: '#000', fontSize: '11px', padding: '6.5px 12px', borderRadius: '4px', fontWeight: 'bold', cursor: 'pointer' }}
                              >
                                <option value="">📥 导出审计报表...</option>
                                <option value="assets">工具资产总表 (.xlsx)</option>
                                <option value="accessories">配件安全库存台账 (.xlsx)</option>
                                <option value="logs">全生命周期履历审计 (.xlsx)</option>
                              </select>
                            </div>
                          </div>
                        </div>

                        <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left', fontSize: '12px' }}>
                          <thead>
                            <tr style={{ borderBottom: '1px solid rgba(255,255,255,0.06)', color: 'var(--text-secondary)' }}>
                              <th style={{ padding: '8px' }}>唯一编码</th>
                              <th style={{ padding: '8px' }}>设备名称</th>
                              <th style={{ padding: '8px' }}>规格型号</th>
                              <th style={{ padding: '8px' }}>状态</th>
                              <th style={{ padding: '8px' }}>寿命次数</th>
                              <th style={{ padding: '8px' }}>物理位置</th>
                            </tr>
                          </thead>
                          <tbody>
                            {webTools.map(t => (
                              <tr 
                                key={t.code} 
                                onClick={() => setSelectedWebToolCode(t.code)}
                                style={{ borderBottom: '1px solid rgba(255,255,255,0.02)', cursor: 'pointer', background: selectedWebToolCode === t.code ? 'rgba(255,255,255,0.03)' : 'transparent' }}
                              >
                                <td style={{ padding: '10px 8px', fontWeight: 'bold' }}>{t.code}</td>
                                <td style={{ padding: '10px 8px' }}>{t.name}</td>
                                <td style={{ padding: '10px 8px' }}>{t.model}</td>
                                <td style={{ padding: '10px 8px' }}>
                                  <span className={`badge ${t.status === '在库' ? 'badge-in' : 'badge-out'}`}>{t.status}</span>
                                </td>
                                <td style={{ padding: '10px 8px' }}>{t.useCount} / {t.lifespanLimit} 次</td>
                                <td style={{ padding: '10px 8px' }}>{t.location}</td>
                              </tr>
                            ))}
                          </tbody>
                        </table>
                      </div>

                      {/* 履历详情抽屉 */}
                      {selectedWebToolCode && (() => {
                        const tool = webTools.find(t => t.code === selectedWebToolCode);
                        return (
                          <div style={{ width: '330px', background: '#121824', padding: '16px', borderRadius: '10px', border: '1px solid var(--border-color)', display: 'flex', flexDirection: 'column' }}>
                            <div style={{ borderBottom: '1px solid rgba(255,255,255,0.06)', paddingBottom: '10px', marginBottom: '12px' }}>
                              <div style={{ fontSize: '10px', color: 'var(--accent-gold)' }}>一物一码·生命履历轴</div>
                              <div style={{ fontSize: '16px', fontWeight: 'bold', marginTop: '2px' }}>{tool?.name}</div>
                              <div style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>ID: {tool?.code} | 规格: {tool?.model}</div>
                            </div>

                            <div style={{ flex: 1, overflowY: 'auto' }}>
                              {tool?.history.map((h, i) => (
                                <div key={i} style={{ position: 'relative', paddingLeft: '16px', borderLeft: '2px solid var(--primary-light)', paddingBottom: '14px', fontSize: '12px' }}>
                                  <div style={{ position: 'absolute', left: '-5px', top: '4px', width: '8px', height: '8px', borderRadius: '50%', background: i === 0 ? 'var(--accent-gold)' : 'var(--primary-light)' }} />
                                  <div style={{ fontSize: '10px', color: 'var(--text-muted)' }}>{h.time}</div>
                                  <div style={{ fontWeight: 'bold', color: i === 0 ? '#fff' : 'var(--text-secondary)' }}>{h.type} <span style={{ fontSize: '10px', fontWeight: 'normal', color: 'var(--text-muted)' }}>({h.operator})</span></div>
                                  <div style={{ color: 'var(--text-secondary)', marginTop: '2px', lineHeight: '1.4' }}>{h.detail}</div>
                                </div>
                              ))}
                            </div>
                          </div>
                        );
                      })()}
                    </div>
                  )}

                </div>
              </div>
            </ChromeWindow>
          </div>

        </main>
      </div>

      {/* ==================== 弹窗组件区 (样式深度美化) ==================== */}
      
      {/* 1. 资产手动建档弹窗 */}
      {showCreateToolModal && (
        <div style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, background: 'rgba(0,0,0,0.75)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000 }}>
          <div style={{ background: '#131722', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '12px', padding: '24px', width: '350px', display: 'flex', flexDirection: 'column', gap: '14px' }}>
            <div style={{ fontSize: '16px', fontWeight: 'bold', color: 'var(--accent-gold)' }}>🚀 新购精密工具手动建档</div>
            <div>
              <label style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>唯一识别编码 (物理浅表打标码)</label>
              <input type="text" className="custom-input" placeholder="如 TL-MT-088-A" value={newTool.code} onChange={e => setNewTool({...newTool, code: e.target.value})} />
            </div>
            <div>
              <label style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>设备名称</label>
              <select className="custom-input" value={newTool.name} onChange={e => setNewTool({...newTool, name: e.target.value})}>
                <option value="电动坐封工具">电动坐封工具</option>
                <option value="阿瓦隆桥塞">阿瓦隆桥塞</option>
              </select>
            </div>
            <div>
              <label style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>规格型号描述</label>
              <input type="text" className="custom-input" placeholder="如 E-Setter 3.0" value={newTool.model} onChange={e => setNewTool({...newTool, model: e.target.value})} />
            </div>
            <div>
              <label style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>初始设定寿命上限 (下井次数上限)</label>
              <input type="number" className="custom-input" value={newTool.lifespanLimit} onChange={e => setNewTool({...newTool, lifespanLimit: parseInt(e.target.value) || 30})} />
            </div>

            <div style={{ display: 'flex', gap: '10px', marginTop: '10px' }}>
              <button onClick={handleCreateTool} style={{ flex: 1, background: 'linear-gradient(90deg, var(--accent-blue), #006699)', color: '#fff', border: 'none', padding: '10px', borderRadius: '6px', cursor: 'pointer', fontWeight: 'bold' }}>
                确认入库建档
              </button>
              <button onClick={() => setShowCreateToolModal(false)} style={{ background: 'transparent', border: '1px solid var(--border-color)', color: '#fff', padding: '10px 14px', borderRadius: '6px', cursor: 'pointer' }}>
                取消
              </button>
            </div>
          </div>
        </div>
      )}

      {/* 2. Excel 批量导入模拟弹窗 */}
      {showImportModal && (
        <div style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, background: 'rgba(0,0,0,0.75)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000 }}>
          <div style={{ background: '#131722', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '12px', padding: '24px', width: '380px', display: 'flex', flexDirection: 'column', gap: '16px' }}>
            <div style={{ fontSize: '16px', fontWeight: 'bold', color: 'var(--accent-gold)' }}>📊 Excel 批量数据建档导入</div>
            
            <div 
              style={{ 
                border: '2px dashed rgba(255,255,255,0.15)', borderRadius: '8px', padding: '30px 20px', 
                textAlign: 'center', cursor: 'pointer', background: 'rgba(255,255,255,0.01)',
                transition: 'var(--transition-smooth)'
              }}
              onClick={() => setImportingFile('precision_tools_batch_2026.xlsx')}
            >
              {importingFile ? (
                <div>
                  <div style={{ fontSize: '32px', marginBottom: '8px' }}>📄</div>
                  <div style={{ fontSize: '13px', color: '#fff', fontWeight: '500' }}>{importingFile}</div>
                  <div style={{ fontSize: '11px', color: 'var(--status-in)', marginTop: '4px' }}>文件已就绪，准备合流解析</div>
                </div>
              ) : (
                <div>
                  <div style={{ fontSize: '32px', marginBottom: '8px' }}>📤</div>
                  <div style={{ fontSize: '13px', color: 'var(--text-secondary)' }}>点击模拟选择 <b>精密工具总账.xlsx</b> 文件</div>
                  <div style={{ fontSize: '10px', color: 'var(--text-muted)', marginTop: '4px' }}>文件将通过局域网直接录入服务器数据库</div>
                </div>
              )}
            </div>

            {importingProgress > 0 && (
              <div>
                <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '10px', color: 'var(--text-secondary)', marginBottom: '4px' }}>
                  <span>解析合并进度：</span>
                  <span>{importingProgress}%</span>
                </div>
                <div style={{ height: '5px', background: 'rgba(255,255,255,0.08)', borderRadius: '4px', overflow: 'hidden' }}>
                  <div style={{ height: '100%', width: `${importingProgress}%`, background: 'var(--accent-blue)' }} />
                </div>
              </div>
            )}

            <div style={{ display: 'flex', gap: '10px' }}>
              <button 
                onClick={handleTriggerBatchImport} 
                style={{ flex: 1, background: 'linear-gradient(90deg, #10b981, #059669)', color: '#fff', border: 'none', padding: '10px', borderRadius: '6px', fontWeight: 'bold', cursor: 'pointer' }}
              >
                确认开始导入
              </button>
              <button 
                onClick={() => { setShowImportModal(false); setImportingFile(null); setImportingProgress(0); }} 
                style={{ background: 'transparent', border: '1px solid var(--border-color)', color: '#fff', padding: '10px 14px', borderRadius: '6px', cursor: 'pointer' }}
              >
                关闭
              </button>
            </div>
          </div>
        </div>
      )}

      {/* 3. 配件入库补货 */}
      {showAddAccModal && (
        <div style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, background: 'rgba(0,0,0,0.7)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000 }}>
          <div style={{ background: '#131722', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '12px', padding: '24px', width: '320px', display: 'flex', flexDirection: 'column', gap: '14px' }}>
            <div style={{ fontSize: '16px', fontWeight: 'bold', color: 'var(--accent-gold)' }}>📦 配件水位补仓入库</div>
            <div>
              <label style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>配件类目</label>
              <select className="custom-input" value={addAcc.barcode} onChange={e => setAddAcc({...addAcc, barcode: e.target.value})}>
                {webAccessories.map(a => (
                  <option key={a.barcode} value={a.barcode}>{a.name} ({a.spec})</option>
                ))}
              </select>
            </div>
            <div>
              <label style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>补给入库数量</label>
              <input type="number" className="custom-input" value={addAcc.qty} onChange={e => setAddAcc({...addAcc, qty: parseInt(e.target.value) || 1})} min="1" />
            </div>

            <div style={{ display: 'flex', gap: '10px', marginTop: '10px' }}>
              <button onClick={handleAddAccessoryStock} style={{ flex: 1, background: 'linear-gradient(90deg, #10b981, #059669)', color: '#fff', border: 'none', padding: '10px', borderRadius: '6px', cursor: 'pointer', fontWeight: 'bold' }}>
                确认入库调整
              </button>
              <button onClick={() => setShowAddAccModal(false)} style={{ background: 'transparent', border: '1px solid var(--border-color)', color: '#fff', padding: '10px 14px', borderRadius: '6px', cursor: 'pointer' }}>
                取消
              </button>
            </div>
          </div>
        </div>
      )}

      {/* 4. 新增井号字典 */}
      {showAddDictModal && (
        <div style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, background: 'rgba(0,0,0,0.7)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000 }}>
          <div style={{ background: '#131722', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '12px', padding: '24px', width: '320px', display: 'flex', flexDirection: 'column', gap: '14px' }}>
            <div style={{ fontSize: '16px', fontWeight: 'bold', color: 'var(--accent-gold)' }}>📍 全局字典 - 新增井号</div>
            <div>
              <label style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>作业井号代码</label>
              <input type="text" className="custom-input" placeholder="如 深地塔科2井" value={newWellbore} onChange={e => setNewWellbore(e.target.value)} />
              <div style={{ fontSize: '10px', color: 'var(--text-muted)', marginTop: '6px', lineHeight: '1.4' }}>
                * 录入全局字典后，会在终端连入局域网 Wi-Fi 同步握手时下发到离线端。
              </div>
            </div>

            <div style={{ display: 'flex', gap: '10px', marginTop: '10px' }}>
              <button onClick={handleAddWellbore} style={{ flex: 1, background: 'linear-gradient(90deg, var(--accent-blue), #006699)', color: '#fff', border: 'none', padding: '10px', borderRadius: '6px', cursor: 'pointer', fontWeight: 'bold' }}>
                录入参数库
              </button>
              <button onClick={() => setShowAddDictModal(false)} style={{ background: 'transparent', border: '1px solid var(--border-color)', color: '#fff', padding: '10px 14px', borderRadius: '6px', cursor: 'pointer' }}>
                取消
              </button>
            </div>
          </div>
        </div>
      )}

      {/* 5. 模拟 Excel 导出弹窗 */}
      {exportModal.show && (
        <div style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, background: 'rgba(0,0,0,0.85)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000 }}>
          <div style={{ background: '#131722', border: '1px solid rgba(255,255,255,0.15)', borderRadius: '12px', padding: '24px', width: '780px', display: 'flex', flexDirection: 'column', gap: '14px', maxHeight: '80%', overflowY: 'auto' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', borderBottom: '1px solid rgba(255,255,255,0.1)', paddingBottom: '10px' }}>
              <span style={{ fontSize: '16px', fontWeight: 'bold', color: '#10b981', display: 'flex', alignItems: 'center', gap: '6px' }}>
                📊 Microsoft Excel 报表成果预览 (.xlsx)
              </span>
              <button onClick={() => setExportModal({ show: false, type: '', data: null })} style={{ background: 'transparent', border: 'none', color: '#fff', cursor: 'pointer', fontSize: '16px' }}>✕</button>
            </div>

            <div style={{ fontSize: '12px', color: 'var(--text-secondary)' }}>
              文件生成时间: {new Date().toLocaleString()} | 数据节点数: {exportModal.data.length} 条。
            </div>

            <div style={{ overflowX: 'auto', background: '#0c0f16', border: '1px solid var(--border-color)', borderRadius: '8px' }}>
              <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '11px', textAlign: 'left' }}>
                <thead>
                  <tr style={{ background: '#1b2130', color: '#fff' }}>
                    {Object.keys(exportModal.data[0] || {}).map(k => (
                      <th key={k} style={{ padding: '10px 8px', borderRight: '1px solid rgba(255,255,255,0.05)' }}>{k}</th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {exportModal.data.map((row, rIdx) => (
                    <tr key={rIdx} style={{ borderBottom: '1px solid rgba(255,255,255,0.03)', background: rIdx % 2 === 0 ? 'transparent' : 'rgba(255,255,255,0.01)' }}>
                      {Object.values(row).map((val, cIdx) => (
                        <td key={cIdx} style={{ padding: '10px 8px', borderRight: '1px solid rgba(255,255,255,0.03)' }}>{val}</td>
                      ))}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>

            <div style={{ display: 'flex', gap: '10px', justifyContent: 'flex-end', marginTop: '10px' }}>
              <button onClick={() => { alert("模拟 Excel 报表已下载保存至本地临时 downloads 文件夹中。"); setExportModal({ show: false, type: '', data: null }); }} style={{ background: '#10b981', color: '#fff', border: 'none', padding: '10px 20px', borderRadius: '6px', cursor: 'pointer', fontWeight: 'bold' }}>
                ⬇️ 下载本张数据表
              </button>
              <button onClick={() => setExportModal({ show: false, type: '', data: null })} style={{ background: 'transparent', border: '1px solid var(--border-color)', color: '#fff', padding: '10px 20px', borderRadius: '6px', cursor: 'pointer' }}>
                关闭预览
              </button>
            </div>
          </div>
        </div>
      )}

    </div>
  );
}

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(<App />);
