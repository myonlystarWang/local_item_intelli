from datetime import datetime
from sqlalchemy.orm import Session
import models, schemas

def parse_time(time_str: str) -> datetime:
    """解析日期时间字符串为 datetime 对象，带有容错处理。"""
    for fmt in ("%Y-%m-%d %H:%M:%S", "%Y/%m/%d %H:%M:%S", "%Y-%m-%d %I:%M:%S %p"):
        try:
            return datetime.strptime(time_str, fmt)
        except ValueError:
            continue
    return datetime.now()

def process_offline_sync(db: Session, sync_data: schemas.SyncRequest) -> schemas.SyncResponse:
    """
    近场对齐同步合并核心算法：
    1. 时间戳优先：将所有离线日志包按照客户端日志发生的时间戳排序，由早到晚逐步“重演”。
    2. 状态锁校验：对每一步重演，校验该工具在全局总账的即时状态是否满足前置拦截条件，冲突时予以忽略并报告。
    """
    sorted_logs = sorted(sync_data.logs, key=lambda x: x.timestamp)
    report = []

    if not sorted_logs:
        report.append(schemas.SyncLogResult(
            type="success",
            text=f"终端 [{sync_data.terminal_uuid}] 完成近场握手，无待上传离线操作日志。",
            time=datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        ))
    
    for log in sorted_logs:
        tool_code = log.tool_code
        db_tool = db.query(models.Tool).filter(models.Tool.code == tool_code).first()
        
        # 1. 拦截未知未建档工具
        if not db_tool:
            report.append(schemas.SyncLogResult(
                type="error",
                text=f"未找到精密工具编码 [{tool_code}]，该条离线流转日志已忽略。",
                time=log.time_str
            ))
            continue
            
        log_time = parse_time(log.time_str)

        # 2. 领用出库逻辑 (CHECKOUT)
        if log.type == "CHECKOUT":
            # 前置状态锁校验
            if db_tool.status != "在库":
                report.append(schemas.SyncLogResult(
                    type="conflict",
                    text=f"【冲突拦截】工具 [{tool_code}] 同步遭拒。手持端离线登记领用，但全局总账中该设备已被其他终端领用，当前状态为 [{db_tool.status}]。操作已忽略。",
                    time=log.time_str
                ))
                continue
                
            # 寿命上限自检硬拦截
            if db_tool.use_count >= db_tool.lifespan_limit:
                report.append(schemas.SyncLogResult(
                    type="conflict",
                    text=f"【寿命硬限制】工具 [{tool_code}] 同步失败：累计使用次数 ({db_tool.use_count}) 已达核定上限 ({db_tool.lifespan_limit})，系统锁定禁止出库下井。",
                    time=log.time_str
                ))
                continue

            # 更新总账
            db_tool.status = "离库"
            db_tool.location = log.detail.wellbore or "野外井口"
            db_tool.operator = log.operator
            db_tool.checkout_time = log_time
            db_tool.last_update_time = log_time
            
            # 追加生命履历
            history_entry = models.ToolHistory(
                tool_code=tool_code,
                timestamp=log_time,
                type="领用出库",
                detail=f"[近场同步] 领用出库至井场 [{log.detail.wellbore}]，班组队号: [{log.detail.team}]，领用人: {log.operator}",
                operator=log.operator
            )
            db.add(history_entry)
            
            report.append(schemas.SyncLogResult(
                type="success",
                text=f"工具 [{tool_code}] 领用出库对齐成功，去往 [{log.detail.wellbore}]。",
                time=log.time_str
            ))

        # 3. 工况地点变更 (CHANGE_LOC)
        elif log.type == "CHANGE_LOC":
            if db_tool.status not in ("离库", "地点变更"):
                report.append(schemas.SyncLogResult(
                    type="conflict",
                    text=f"【状态锁拦截】工具 [{tool_code}] 当前状态为 [{db_tool.status}]，不允许执行井场地点变更。该条离线日志已忽略。",
                    time=log.time_str
                ))
                continue

            db_tool.status = "地点变更"
            db_tool.location = log.detail.wellbore or "未知井号"
            db_tool.operator = log.operator
            db_tool.last_update_time = log_time
            
            history_entry = models.ToolHistory(
                tool_code=tool_code,
                timestamp=log_time,
                type="工况变更",
                detail=f"[近场同步] 现场调拨更新地点至井号 [{log.detail.wellbore}]，班组队号: [{log.detail.team or '未记录'}]",
                operator=log.operator
            )
            db.add(history_entry)
            
            report.append(schemas.SyncLogResult(
                type="success",
                text=f"工具 [{tool_code}] 位置调拨变更至 [{log.detail.wellbore}] 成功。",
                time=log.time_str
            ))

        # 4. 维保归库配件核销 (MAINTAIN)
        elif log.type == "MAINTAIN":
            if db_tool.status not in ("离库", "地点变更"):
                report.append(schemas.SyncLogResult(
                    type="conflict",
                    text=f"【状态锁拦截】工具 [{tool_code}] 当前状态为 [{db_tool.status}]，不允许直接执行归库保养。该条离线日志已忽略。",
                    time=log.time_str
                ))
                continue

            consumables = log.detail.consumables or []
            
            # 库存校验
            stock_insufficient = False
            insufficient_items = []
            
            for item in consumables:
                db_acc = db.query(models.Accessory).filter(models.Accessory.barcode == item.barcode).first()
                if not db_acc or db_acc.current_stock < item.qty:
                    stock_insufficient = True
                    insufficient_items.append(item.name if db_acc else item.barcode)
            
            if stock_insufficient:
                report.append(schemas.SyncLogResult(
                    type="error",
                    text=f"【配件短缺】工具 [{tool_code}] 维保失败。全局仓库零配件 [{', '.join(insufficient_items)}] 当前余量严重不足，自动扣减已被取消。",
                    time=log.time_str
                ))
                continue

            # 扣减全局零配件安全库存
            for item in consumables:
                db_acc = db.query(models.Accessory).filter(models.Accessory.barcode == item.barcode).first()
                db_acc.current_stock -= item.qty
            
            # 精密工具状态流转回在库，使用寿命累计+1
            db_tool.status = "在库"
            db_tool.use_count += 1
            db_tool.location = "基地总库"
            db_tool.operator = log.operator
            db_tool.checkout_time = None
            db_tool.last_update_time = log_time
            
            consumable_details = ", ".join([f"{c.name} x {c.qty}" for c in consumables]) if consumables else "无配件消耗"
            history_entry = models.ToolHistory(
                tool_code=tool_code,
                timestamp=log_time,
                type="归库保养",
                detail=f"[近场同步] 确认归库，级别: {log.detail.level or '常规保养'}。联动扣减配件: {consumable_details}。累计寿命+1 (当前 {db_tool.use_count}/{db_tool.lifespan_limit}次)。",
                operator=log.operator
            )
            db.add(history_entry)
            
            report.append(schemas.SyncLogResult(
                type="success",
                text=f"工具 [{tool_code}] 归库保养对齐成功。累计使用寿命刷新为 {db_tool.use_count}次。",
                time=log.time_str
            ))
            
    for item in report:
        db.add(models.SyncLog(
            terminal_uuid=sync_data.terminal_uuid,
            timestamp=parse_time(item.time),
            type=item.type,
            text=item.text,
            source_time=item.time
        ))

    db.commit()
    
    # 获取全量数据进行返回，供 App 覆盖本地 SQLite，保证双端绝对一致
    all_tools = db.query(models.Tool).all()
    all_acc = db.query(models.Accessory).all()
    updated_dicts = {
        "wellbores": [r.dict_value for r in db.query(models.Dictionary).filter_by(dict_type="wellbore").all()],
        "operators": [r.dict_value for r in db.query(models.Dictionary).filter_by(dict_type="operator").all()],
        "teams": [r.dict_value for r in db.query(models.Dictionary).filter_by(dict_type="team").all()],
    }
    
    return schemas.SyncResponse(
        status="success",
        report=report,
        updated_tools=all_tools,
        updated_accessories=all_acc,
        updated_dicts=updated_dicts
    )
