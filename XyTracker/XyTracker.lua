-- 定义插件的一些常量和全局变量
local XyInProgress, XyTracker_Options, XyOnlyMode, NewDKP, NowNotification, IsLeader, Xys, NoXyList
XY_BUTTON_HEIGHT = 25;
Xy_SortOptions = { ["method"] = "", ["itemway"] = "" };
UnitPopupButtons["GET_XY"] = { text = "查询许愿", dist = 0 };
UnitPopupButtons["ADD_DKP"] = { text = "增加分数", dist = 0 };
UnitPopupButtons["Minus_DKP"] = { text = "扣除分数", dist = 0 };
NewDKP = false
NowNotification = 1

function autoMode_OnClick(self)
    if self:GetChecked() then
        XyOnlyMode = 1
    else
        XyOnlyMode = 0
    end
end
-- 通告许愿信息
function notificationXY(frame)
    local self = frame or XyTrackerFrame
    if NowNotification == 1 then
        SendChatMessage("受系统发言间隔限制，本插件一次最多通报8名成员许愿信息，如列表不完整请再次点击通告按钮", "RAID", self.language, nil)
    end
    local totalMembers = getn(XyArray)
    local name, xy, DKP, EndNowNotification
    EndNowNotification = NowNotification + 7
    if totalMembers then
        for i = NowNotification, EndNowNotification do
            name = XyArray[i]["name"]
            xy = XyArray[i]["xy"]
            DKP = XyArray[i]["dkp"]
            if xy == "" or xy == nil then
                xy = "无"
            end
            SendChatMessage("许愿通报:玩家" .. i .. "【" .. name .. "】许愿道具【" .. xy .. "】,剩余DKP【" .. DKP .. "】分", "RAID", self.language, nil)
            if i == totalMembers then
                NowNotification = 1
                break
            else
                NowNotification = EndNowNotification
            end
        end
        if NowNotification > 1 then
            NowNotification = NowNotification + 1
        else
            SendChatMessage("通知：玩家许愿列表已通报完毕，请再次点击通告按钮", "RAID", self.language, nil)
        end
    end
end
-- 调用默认DKP
function printDefaultDKP()
    getglobal("allDKPFrameTXT"):SetText(DefaultDKP);
end
-- 更新默认DKP
function NEWDefaultDKP()
    DefaultDKP = getglobal("allDKPFrameTXT"):GetNumber();
    NewDKP = true
    XyTracker_OnRefreshButtonClick()
    XyTracker_UpdateList() -- 更新DKP列表
    SendChatMessage("通知：当前默认DKP为每人" .. DefaultDKP .. "分，分数已初始化", "RAID", this.language, nil)
    SendChatMessage("通知：当前默认DKP为每人" .. DefaultDKP .. "分，分数已初始化", "RAID", this.language, nil)
    SendChatMessage("通知：当前默认DKP为每人" .. DefaultDKP .. "分，分数已初始化", "RAID", this.language, nil)
end
-- 检查列表中是否包含指定元素
function contain(v, l)
    if not l then
        return false
    end
    local n = getn(l)
    if n > 0 then
        for i = 1, n do
            local lv = l[i]
            if v == lv then
                return true
            end
        end
    end
    return false
end
-- 插件加载时的初始化函数
function XyTracker_OnLoad(self)
    -- 在单位弹出菜单中我们不再直接修改 UnitPopupMenus（会造成 taint）
    -- 如需启用右键菜单，请参见方案 B（有风险）并在明确接受风险后再启用。
    if not self then return end

    -- 命令行指令
    SlashCmdList["XYTRACKER"] = XyTracker_OnSlashCommand
    SLASH_XYTRACKER1 = "/xyt"
    SLASH_XYTRACKER2 = "/xytrack"

    -- 注册事件监听（保持原有事件）
    self:RegisterEvent("CHAT_MSG_SYSTEM")
    self:RegisterEvent("CHAT_MSG_PARTY")
    self:RegisterEvent("CHAT_MSG_RAID")
    self:RegisterEvent("CHAT_MSG_RAID_LEADER")
    self:RegisterEvent("CHAT_MSG_RAID_WARNING")
    self:RegisterEvent("CHAT_MSG_ADDON")
    self:RegisterEvent("CHAT_MSG_WHISPER")
    self:RegisterForDrag("LeftButton")

    -- 设置界面样式（保持尽可能兼容）
    if TOOLTIP_DEFAULT_BACKGROUND_COLOR and RED_FONT_COLOR then
        if self.SetBackdropColor then
            self:SetBackdropColor(TOOLTIP_DEFAULT_BACKGROUND_COLOR.r, TOOLTIP_DEFAULT_BACKGROUND_COLOR.g, TOOLTIP_DEFAULT_BACKGROUND_COLOR.b)
            self:SetBackdropBorderColor(RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b)
        end
    end

    if XyButtonFrame then
        XyButtonFrame:Hide()
    end

    -- 注意：不要覆盖 UnitPopup_OnClick 或直接往 UnitPopupMenus 插入元素（1.14 上常导致 taint）
    -- 如果你之前的代码里有 ori_unitpopup1 = UnitPopup_OnClick; UnitPopup_OnClick = ple_unitpopup1
    -- 请删除或注释掉那两行，以避免 UI 受保护路径被污染。

    -- 初始化变量（确保所有变量正确初始化）
    if XyArray == nil then
        XyArray = {}
    end
    XyInProgress = false

    if NoXyList == nil then
        NoXyList = ""
    end

    Xys = 0  -- 初始化许愿计数

    -- 处理自动模式按钮（仅在界面存在时设置）
    local autoModeButtons = _G["autoModeButtons"]
    if XyOnlyMode == nil then
        XyOnlyMode = 0
    end
    if autoModeButtons and autoModeButtons.SetChecked then
        autoModeButtons:SetChecked(XyOnlyMode)
    end

    -- 初次更新列表（如果你不是“发起方/临时领袖”，UpdateList 在很多地方依赖 IsLeader）
    XyTracker_UpdateList()

    -- 尝试安全地发送同步请求（仅当在团队并且 API 存在）
    if IsInRaid() and type(SendAddonMessage) == "function" then
        -- 这只是通知：一旦某人发起了开始同步（XY_START），会触发真正的同步
        -- 不必在加载时强行插入 UnitPopup
        SendAddonMessage("XY_SYNC_NEW", "", "RAID")
    end

    -- 提示（仅用于调试/确认）
    -- XyTracker_Print("XyTracker 已加载（安全模式：未修改 UnitPopup），使用 /xyt 查看命令帮助。")
end

-- 替换后的单位弹出窗口点击处理函数
function ple_unitpopup1()
    local dropdownFrame = getglobal(UIDROPDOWNMENU_INIT_MENU);
    local button = this.value;
    local unit = dropdownFrame.unit;
    local name = dropdownFrame.name;
    local server = dropdownFrame.server;
    -- 处理“查询许愿”和“修改分数”按钮的点击事件
    if (button == "GET_XY") then
        XyQuery(name);
    elseif button == "ADD_DKP" then
        local info = getXyInfo(name)
        if info then
            getglobal("XyAddMember"):SetText(name);
            getglobal("XyAddDkpFramePoint"):SetText("");
            XyAddDkpFrame:Show();
        end
    elseif button == "Minus_DKP" then
        local info = getXyInfo(name)
        if info then
            getglobal("XyMinusMember"):SetText(name);
            getglobal("XyMinusDkpFramePoint"):SetText("");
            XyMinusDkpFrame:Show();
        end
    else
        -- 对于其他按钮，调用原始处理函数
        return ori_unitpopup1();
    end
    -- 播放音效
    PlaySound("UChatScrollButton");
end

-- 获取指定名字的许愿信息
function getXyInfo(name)
    local n = #XyArray
    if n > 0 then
        for i = 1, n do
            local info = XyArray[i]
            if info["name"] == name then
                return info
            end
        end
    end
    return nil
end

-- 更新许愿者列表
function XyTracker_UpdateList()
    NoXyList = ""
    Xys = 0
    local totalMembers = GetNumGroupMembers()
    if totalMembers and IsLeader then
        for i = 1, totalMembers do
            local name, rank, subgroup, level, class, fileName, zone, online
            if IsInRaid() then
                name, rank, subgroup, level, class, fileName, zone, online = GetRaidRosterInfo(i)
            else
                name, rank, subgroup, level, class, fileName, zone, online = GetPartyMemberInfo(i)
            end
            local info = getXyInfo(name);
            if info then
                if NewDKP then
                    info["dkp"] = DefaultDKP
                end
                if info["xy"] and info["xy"] ~= "---未许愿---" then
                    Xys = Xys + 1
                else
                    NoXyList = NoXyList .. name .. " "
                end
            else
                info = {}
                info["name"] = name
                info["class"] = class
                info["xy"] = "---未许愿---"
                info["dkp"] = DefaultDKP
                table.insert(XyArray, info)
                NoXyList = NoXyList .. name .. " "
            end
        end
        NewDKP = false
    end
    XyTrackerFrameStatusText:SetText(XyTracker_If(Xys == 0, "当前无人许愿", string.format("%d当前许愿人数", Xys)))
    FauxScrollFrame_Update(XyListScrollFrame, totalMembers, 15, 25);
    if getn(XyArray) > 0 then
        local offset = FauxScrollFrame_GetOffset(XyListScrollFrame);
        for i = 1, 15 do
            k = offset + i;
            if k > getn(XyArray) then
                getglobal("XyFrameListButton" .. i):Hide();
            else
                v = XyArray[k]
                getglobal("XyFrameListButton" .. i .. "Name"):SetText(v["name"]);
                getglobal("XyFrameListButton" .. i .. "Class"):SetText(v["class"]);
                getglobal("XyFrameListButton" .. i .. "Xy"):SetText(v["xy"]);
                getglobal("XyFrameListButton" .. i .. "DKP"):SetText(v["dkp"]);
                if IsLeader then
                    getglobal("XyFrameListButton" .. i .. "AddDkp"):Show();
                    getglobal("XyFrameListButton" .. i .. "MinusDkp"):Show();
                else
                    getglobal("XyFrameListButton" .. i .. "AddDkp"):Hide();
                    getglobal("XyFrameListButton" .. i .. "MinusDkp"):Hide();
                end
                getglobal("XyFrameListButton" .. i):Show();
            end
        end
    else
        for i = 1, 15 do
            getglobal("XyFrameListButton" .. i):Hide();
        end
    end
end

function XyTracker_Print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(msg)
    end
end

function XyTracker_If(expr, a, b)
    if expr then
        return a
    else
        return b
    end
end
function XyTracker_OnSlashCommand(msg)
    local cmd, rest = msg:match("^(%S*)%s*(.-)$")
    cmd = cmd and cmd:lower() or ""
    if cmd == "" then
        -- 无参数 -> 切换窗口（与原先行为一致）
        if XyTrackerFrame and XyTrackerFrame:IsVisible() then
            XyTracker_HideXyWindow()
        else
            XyTracker_ShowXyWindow()
        end
        return
    end

    if cmd == "query" and rest and rest ~= "" then
        XyQuery(rest)
        return
    end

    if (cmd == "adddkp" or cmd == "add") and rest and rest ~= "" then
        local name, pts = rest:match("^(%S+)%s+(%-?%d+)$")
        if name and pts then
            -- 设置框并调用加分函数
            getglobal("XyAddMember"):SetText(name)
            getglobal("XyAddDkpFramePoint"):SetText(pts)
            XyAddDkp()
        else
            XyTracker_Print("用法: /xyt adddkp 玩家名 分数")
        end
        return
    end

    if (cmd == "minusdkp" or cmd == "minus") and rest and rest ~= "" then
        local name, pts = rest:match("^(%S+)%s+(%-?%d+)$")
        if name and pts then
            getglobal("XyMinusMember"):SetText(name)
            getglobal("XyMinusDkpFramePoint"):SetText(pts)
            XyMinusDkp()
        else
            XyTracker_Print("用法: /xyt minusdkp 玩家名 分数")
        end
        return
    end

    -- 其他参数保持原有行为：切换界面
    if XyTrackerFrame and XyTrackerFrame:IsVisible() then
        XyTracker_HideXyWindow()
    else
        XyTracker_ShowXyWindow()
    end
end

function XyTracker_ShowXyWindow()
    if DefaultDKP == nil then
        DefaultDKP = 4
    end
    ShowUIPanel(XyTrackerFrame)
    XyTracker_OnRefreshButtonClick()
end

function XyTracker_HideXyWindow()
    HideUIPanel(XyTrackerFrame)
end

function XyButton_UpdatePosition()
    XyButtonFrame:SetPoint(
            "TOPLEFT",
            "Minimap",
            "TOPLEFT",
            54 - (78 * cos(200)),
            (78 * sin(200)) - 55
    );
end

function XyTracker_OnEvent(event, ...)
    local args = {...}  -- 接收所有事件参数
    
    -- 1. 处理团队/团队领袖消息（许愿信息）
    if event == "CHAT_MSG_RAID" or event == "CHAT_MSG_RAID_LEADER" then
        if XyInProgress then
            local msg = args[1]  -- 消息内容
            local sender = args[2]  -- 发送者
            XyTracker_OnSystemMessage(msg, sender)
        end
    end

    
    -- 2. 处理密语查询
    if event == "CHAT_MSG_WHISPER" then
        local msg = args[1]
        local sender = args[2]
        if msg == "cxxy" then
            XyQuery(sender)
        end
    end
    
    -- 3. 处理插件同步消息
    if event == "CHAT_MSG_ADDON" then
        local prefix = args[1]  -- 消息前缀
        local msg = args[2]     -- 消息内容
        local sender = args[4]  -- 发送者
        
        -- 处理开始许愿同步
        if prefix == "XY_START" and not IsLeader then
            DisableLeaderOperation()
        end
        
        -- 处理同步请求
        if prefix == "XY_SYNC_NEW" and IsLeader then
            syncXy()  -- 调用前面修改的syncXy函数
        end
        
        -- 处理同步数据接收
        if prefix == "XY_SYNC" and not IsLeader then
            receiveXySync(msg)
        end
    end
    
    -- 4. 处理系统消息（重点：加入团队时的同步请求）
    if event == "CHAT_MSG_SYSTEM" then
        local msg = args[1]  -- 系统消息内容
        
        -- 当玩家加入团队时，发送同步请求
        if msg == "你加入了一个团队。" then
            -- 双重检查：确保在团队中，且SendAddonMessage函数存在
            if IsInRaid() and type(SendAddonMessage) == "function" then
                SendAddonMessage("XY_SYNC_NEW", "", "RAID")
            else
                XyTracker_Print("加入团队，但同步功能不可用")
            end
        end
        
        -- 当玩家离开团队时，重置状态
        if msg == "你已经离开了这个团队" then
            IsLeader = false
            EnableLeaderOperation()
        end
    end
end

function receiveXySync(msg)
    DisableLeaderOperation()
    --获取同步开始
    for n, x in string.gfind(msg, "n=(.+),x=(.+)") do
        Xys = x
        XyArray = {}
        XyTracker_UpdateList()
        return
    end
    for p, c, x, s in string.gfind(msg, "p=(.+),c=(.+),x=(.+),s=(.+)") do
        local info = {}
        info["name"] = p
        info["class"] = c
        if x == "---未许愿---" then
            info["xy"] = ""
        else
            info["xy"] = x
        end
        info["dkp"] = s
        table.insert(XyArray, info)
        XyTracker_UpdateList()
    end
end

function syncXy()
    -- 检查是否在团队中
    if not IsInRaid() then
        XyTracker_Print("无法同步：不在团队中")
        return
    end
    
    -- 检查SendAddonMessage函数是否存在
    if type(SendAddonMessage) ~= "function" then
        --XyTracker_Print("同步功能不可用：API不存在")
        return
    end
    
    local n = #XyArray
    local msg = ""
    
    if n > 0 then
        msg = "n=" .. n .. ",x=" .. Xys
        -- 发送同步消息，指定团队频道
        SendAddonMessage("XY_SYNC", msg, "RAID")
        XyTracker_Print("已同步许愿数据到团队")
    else
        XyTracker_Print("没有数据可同步")
    end
end

function DisableLeaderOperation()
    XyInProgress = false
    getglobal("XyTrackerFrameStartButton"):Hide();
    getglobal("XyTrackerFrameStopButton"):Hide();
    getglobal("XyTrackerFrameResetButton"):Hide();
    getglobal("XyTrackerFrameAnnounceButton"):Hide();
    getglobal("XyTrackerFrameExportButton"):Hide();
    getglobal("XyTrackerFrameChuShiHua_DKP"):Hide();
    -- getglobal("XyTrackerFrameBroadcastXY"):Hide();
end

function EnableLeaderOperation()
    XyInProgress = false
    getglobal("XyTrackerFrameStartButton"):Show();
    --getglobal("XyTrackerFrameStopButton"):Show();
    getglobal("XyTrackerFrameResetButton"):Show();
    getglobal("XyTrackerFrameAnnounceButton"):Show();
    getglobal("XyTrackerFrameExportButton"):Show();
    getglobal("XyTrackerFrameChuShiHua_DKP"):Show();
    -- getglobal("XyTrackerFrameBroadcastXY"):Show();
end

function XyQuery(player, dkpnumber)
    local n = getn(XyArray)
    for i = 1, n do
        local name = XyArray[i]["name"]
        local xy = XyArray[i]["xy"]
        if not xy then
            xy = ""
        end
        if player == name then
            if dkpnumber and dkpnumber ~= 0 then
                if dkpnumber > 0 then
                    SendChatMessage(player .. " 增加[" .. dkpnumber .. "]分,当前剩余分数：[" .. XyArray[i]["dkp"] .. "]", "RAID", this.language, nil);
                else
                    SendChatMessage(player .. " 扣除[" .. 0 - dkpnumber .. "]分,当前剩余分数：[" .. XyArray[i]["dkp"] .. "]", "RAID", this.language, nil);
                end
            else
                SendChatMessage(player .. " 许愿[" .. xy .. "],当前剩余分数：[" .. XyArray[i]["dkp"] .. "]", "RAID", this.language, nil);
            end
        end
    end
end

-- 处理系统消息，更新许愿信息
function XyTracker_OnSystemMessage(msg, sender)
    local values = {}
    for word in string.gmatch(msg, "%S+") do
        table.insert(values, word)
    end
    local val1 = values[1]
    if string.lower(val1) == "xy" and #values > 1 then
        local Xy = values[2]
        XyTracker_OnXy(sender, Xy)
        XyTracker_UpdateList()
        syncXy()
    elseif string.lower(val1) == "txy" and #values > 2 then
        local player = values[2]
        local Xy = values[3]
        XyTracker_OnXy(player, Xy)
        XyTracker_UpdateList()
        syncXy()
    elseif XyOnlyMode == 0 then
        local pos = string.find(msg, "|Hitem:")
        if pos and pos > 0 then
            XyTracker_OnXy(sender, msg)
            XyTracker_UpdateList()
            syncXy()
        end
    end
end

function XyTracker_OnXy(name, Xy)
    local info = getXyInfo(name)
    if not info then
        info = {name = name, class = "未知", dkp = DefaultDKP or 0}
        table.insert(XyArray, info)
    end
    info["xy"] = Xy
    XyTracker_ShowXyWindow()
end


function XyTracker_OnStartButtonClick()
    -- 兼容性：使用 GetNumGroupMembers（1.14 推荐），回退到 GetNumRaidMembers if needed
    local total = 0
    if type(GetNumGroupMembers) == "function" then
        total = GetNumGroupMembers()
    elseif type(GetNumRaidMembers) == "function" then
        total = GetNumRaidMembers()
    end

    -- 如果团队人数>1 就允许发起（与原版行为一致）
    if total and total > 1 then
        -- 在插件内部把自己标记为发起者（原版直接设 IsLeader = true）
        IsLeader = true

        if XyOnlyMode == 1 then
            SendChatMessage("开始许愿，仅允许在团队频道输入【XY 许愿装备】可以被记录", "RAID", GetDefaultLanguage and GetDefaultLanguage("player") or "", nil);
            SendChatMessage("此插件基于乌龟服XyTracker修改，原作者无道暴君，二次开发作者Everlook Asia服务器KO工会：角色Pagee、Kbftmgl、Pagff、Fara，使用前请先阅读#Readme.md", "RAID", GetDefaultLanguage and GetDefaultLanguage("player") or "", nil);
        else
            SendChatMessage("开始许愿，在团队频道输入【XY 许愿装备】或者直接贴装备链接可以被记录", "RAID", GetDefaultLanguage and GetDefaultLanguage("player") or "", nil);
            SendChatMessage("此插件基于乌龟服XyTracker修改，原作者无道暴君，二次开发作者Everlook Asia服务器KO工会：角色Pagee、Kbftmgl、Pagff、Fara，使用前请先阅读#Readme.md", "RAID", GetDefaultLanguage and GetDefaultLanguage("player") or "", nil);
        end

        XyInProgress = true
        XyArray = {}  -- 清初始数据，跟原版一致
        Xys = 0
        XyTracker_ShowXyWindow()
        -- 同步到团员端（仅当 API 可用）
        if type(SendAddonMessage) == "function" then
            SendAddonMessage("XY_START", "", "RAID")
        end
        XyTracker_Print("许愿已开始，等待团队成员发送许愿信息")
    else
        XyTracker_Print("团队人数不足，无法开始许愿")
    end
end

function XyTracker_OnStopButtonClick()
    SendChatMessage("许愿结束，后续许愿无效", "RAID", GetDefaultLanguage("player"), nil)
    XyInProgress = false
end

function XyTracker_OnClearButtonClick()
    -- 清空现有记录
    XyArray = {}
    -- 仅在团队中时重新添加成员
    if IsInRaid() then
        local totalMembers = GetNumGroupMembers()
        if totalMembers > 0 then
            for i = 1, totalMembers do
                -- 使用新版API GetGroupRosterInfo
                local name, rank, subgroup, level, class, fileName, zone, online
                if IsInRaid() then
                    name, rank, subgroup, level, class, fileName, zone, online = GetRaidRosterInfo(i)
                else
                    name, rank, subgroup, level, class, fileName, zone, online = GetPartyMemberInfo(i)
                end
                if name and online then
                    table.insert(XyArray, {name = name, xy = "未许愿", class = class, dkp = DefaultDKP or 0})
                end
            end
        end
    end
    XyTracker_UpdateList()
    XyTracker_Print("许愿记录已清空")
end

function XyTracker_OnRefreshButtonClick()
    -- 先确认在团队中且是领袖
    if IsInRaid() and IsLeader then
        -- 获取团队成员总数
        local totalMembers = GetNumGroupMembers()
        if totalMembers > 0 then
            --XyTracker_Print("正在刷新团队成员列表...")
            -- 遍历所有团队成员
            for i = 1, totalMembers do
                -- 使用新版API GetGroupRosterInfo获取成员信息
                local name, rank, subgroup, level, class, fileName, zone, online
                if IsInRaid() then
                    name, rank, subgroup, level, class, fileName, zone, online = GetRaidRosterInfo(i)
                else
                    name, rank, subgroup, level, class, fileName, zone, online = GetPartyMemberInfo(i)
                end
                if name and online then  -- 确保成员存在且在线
                    local found = false
                    -- 检查是否已在列表中
                    for j = 1, #XyArray do
                        if XyArray[j].name == name then
                            found = true
                            break
                        end
                    end
                    -- 不在列表中则添加
                    if not found then
                        table.insert(XyArray, {name = name, xy = "未许愿", class = class, dkp = DefaultDKP or 0})
                    end
                end
            end
            XyTracker_UpdateList()
            --XyTracker_Print("团队成员列表已刷新")
        else
            XyTracker_Print("团队中没有成员")
        end
    else
        XyTracker_Print("只有团队领袖才能刷新列表")
    end
end


function XyTracker_OnAnnounceButtonClick()
    -- 构造未许愿名单（兼容各种可能的占位表示）
    local missing = {}
    local n = #XyArray
    if n and n > 0 then
        for i = 1, n do
            local info = XyArray[i]
            local xy = info and info.xy
            if not xy or xy == "" or xy == "---未许愿---" or xy == "未许愿" then
                table.insert(missing, info.name or "未知")
            end
        end
    end

    if #missing > 0 then
        -- 使用中文逗号拼接名字（不会出错，因为 table.concat 按项连接）
        SendChatMessage("未许愿成员: " .. table.concat(missing, "，"), "RAID")
    else
        SendChatMessage("所有团队成员都已完成许愿", "RAID")
    end
end

function XyTracker_OnExportButtonClick()
    -- 保存当前排序设置
    local originalMethod = Xy_SortOptions.method
    local originalItemway = Xy_SortOptions.itemway
    
    -- 设置按职业排序（升序）
    Xy_SortOptions.method = "class"
    Xy_SortOptions.itemway = "asc"
    
    -- 调试：检查 XyArray 数据
    local n = #XyArray
    --XyTracker_Print("导出许愿：XyArray 长度 = " .. n)
    for i = 1, n do
        local class = XyArray[i]["class"] or "未知"
        local name = XyArray[i]["name"] or "未知"
        --XyTracker_Print("条目 " .. i .. ": 职业=" .. class .. ", 名字=" .. name)
    end
    
    -- 按职业排序
    Xy_SortDkp()
    
    -- 生成导出内容
    local csvText = ""
    for i = 1, n do
        local xy = XyArray[i]["xy"] or ""
        local class = XyArray[i]["class"] or "未知"
        local name = XyArray[i]["name"] or "未知"
        local dkp = XyArray[i]["dkp"] or 0
        csvText = csvText .. class .. "-" .. name .. "-" .. xy .. "-当前剩余:[" .. dkp .. "]分" .. "\n"
    end
    
    -- 恢复原有排序设置
    Xy_SortOptions.method = originalMethod
    Xy_SortOptions.itemway = originalItemway
    Xy_SortDkp()
    
    -- 设置导出框内容
    local frame = getglobal("XyExportFrame")
    local editBox = getglobal("XyExportEdit")
    
    -- 调试：检查框架和编辑框
    if not frame then
        XyTracker_Print("错误：XyExportFrame 不存在")
        return
    end
    if not editBox then
        XyTracker_Print("错误：XyExportEdit 不存在")
        return
    end
    
    editBox:SetText(csvText)
    
    -- 检查 SetBackdrop 是否可用
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 8,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        frame:SetBackdropColor(0, 0, 0, 1.0)
        frame:SetBackdropBorderColor(1, 1, 1, 1.0)
        --XyTracker_Print("XyExportFrame: Backdrop set in OnExportButtonClick")
        local r, g, b, a = frame:GetBackdropColor()
        --XyTracker_Print("XyExportFrame: Backdrop color (" .. (r or "nil") .. ", " .. (g or "nil") .. ", " .. (b or "nil") .. ", " .. (a or "nil") .. ")")
    else
        XyTracker_Print("警告：SetBackdrop 方法不可用，跳过背景设置")
    end
    
    -- 调试：检查框架类型
    local frameType = frame:GetObjectType()
    --XyTracker_Print("XyExportFrame 类型: " .. (frameType or "未知"))
    
    frame:Show()
end

function Xy_FixZero(num)
    if (num < 10) then
        return "0" .. num;
    else
        return num;
    end
end

function Xy_Date()
    local t = date("*t");

    return strsub(t.year, 3) .. "-" .. Xy_FixZero(t.month) .. "-" .. Xy_FixZero(t.day) .. " " .. Xy_FixZero(t.hour) .. ":" .. Xy_FixZero(t.min) .. ":" .. Xy_FixZero(t.sec);
end

function XyAddDkp()
    player = getglobal("XyAddMember"):GetText(); -- 获取玩家姓名
    dkppoint = getglobal("XyAddDkpFramePoint"):GetNumber(); -- 获取要家增的DKP点数
    if dkppoint == nil then
        dkppoint = 0
    end
    local info = getXyInfo(player) -- 获取玩家信息
    if info then
        info["dkp"] = info["dkp"] + dkppoint -- 更新DKP点数
        XyTracker_UpdateList() -- 更新DKP列表
        XyQuery(player, dkppoint);
    end
    syncXy()
end

-- 为指定玩家扣除DKP点数
function XyMinusDkp()
    player = getglobal("XyMinusMember"):GetText(); -- 获取玩家姓名
    dkppoint = getglobal("XyMinusDkpFramePoint"):GetNumber(); -- 获取要扣除的DKP点数
    if dkppoint == nil then
        dkppoint = 0
    end
    local info = getXyInfo(player) -- 获取玩家信息
    if info then
        info["dkp"] = info["dkp"] - dkppoint -- 更新DKP点数
        XyTracker_UpdateList() -- 更新DKP列表
        XyQuery(player, 0 - dkppoint);
    end
    syncXy()
end
-- 设置DKP排序选项
function XySortOptions(method)

    if (Xy_SortOptions.method and Xy_SortOptions.method == method) then
        if (Xy_SortOptions.itemway and Xy_SortOptions.itemway == "asc") then
            Xy_SortOptions.itemway = "desc";
        else
            Xy_SortOptions.itemway = "asc";
        end
    else
        Xy_SortOptions.method = method;
        Xy_SortOptions.itemway = "asc";
    end
    Xy_SortDkp();
    XyTracker_UpdateList();
end

function Xy_SortDkp()
    table.sort(XyArray, Xy_CompareDkps);
end

function Xy_CompareDkps(a1, a2)
    local method, way = Xy_SortOptions["method"], Xy_SortOptions["itemway"];
    local c1, c2 = a1[method] or "", a2[method] or "";
    if (way == "asc") then
        return c1 < c2;
    else
        return c1 > c2;
    end
end