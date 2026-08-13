#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
merge_strings.py — 向 src/i18n/strings.json 注入新增的 UI 键（中英），
保留已有键不变；写回 UTF-8 + LF。
"""
import json
import os

PATH = r"G:\GitHub\CourierSim\src\i18n\strings.json"

# 新增键 — 中英同步
NEW = {
    "zh_CN": {
        # 主菜单新增
        "menu.new_game": "开始新游戏",
        "menu.continue": "继续游戏",
        "menu.settings": "设置",
        "menu.about": "关于",
        "menu.quit": "退出",
        "menu.cancel": "取消",
        "menu.hint_v2": "🚚 在这个像素世界里，建设你的快递王国。地图点击城市可直接建仓/建站；每个图标悬停查看说明；F2 设置 · F1 关于。",

        # 顶栏 / Tab 提示
        "tip.new_game": "开始一场新的快递生涯",
        "tip.continue": "读取上次的存档",
        "tip.settings": "调整音频、显示、语言与存档",
        "tip.about": "关于本作与开源许可",
        "tip.quit": "退出游戏",
        "tip.cancel": "返回上一级",
        "tip.save": "立即保存当前进度",
        "tip.menu": "回到主菜单",
        "tip.lang": "切换语言",
        "tip.speed_pause": "暂停 / 继续游戏时间",
        "tip.speed_x": "时间速度：%dx",
        "tip.tab_map": "地图 — 查看区域城市与运营",
        "tip.tab_orders": "订单 — 待分配与在途订单",
        "tip.tab_vehicles": "车辆 — 购置、查看状态",
        "tip.tab_hubs": "中转仓库 — 升级吞吐能力",
        "tip.tab_stations": "末端站点 — 提升覆盖与满意度",
        "tip.tab_marketing": "市场宣传 — 投放预算提升知名度",
        "tip.tab_tech": "科技 — 解锁永久增益",
        "tip.tab_staff": "员工 — 招聘提供增益",
        "tip.tab_finance": "财务 — 资金流水与利润",
        "tip.tab_region": "区域 — 解锁其他城市群",
        "tip.city_build_hub": "在这座城市建立中转仓库（¥%d）",
        "tip.city_upgrade_hub": "升级中转仓库（¥%d）",
        "tip.city_build_station": "在这座城市建立末端站点（¥%d）",
        "tip.city_promote": "提升站点宣传等级（¥%d）",
        "tip.close": "关闭",
        "tip.back": "返回",

        # 选项卡分组
        "tab.group.ops": "运营",
        "tab.group.fac": "设施",
        "tab.group.dev": "发展",
        "tab.group.mng": "管理",

        # 目标追踪
        "obj.hud": "当前目标",

        # 对白
        "dlg.continue": "继续 ▸",

        # 教程
        "tut.speaker.narrator": "快递王国",
        "tut.speaker.ceo": "金社长",
        "tut.intro": "你接手了一家小型快递公司。\n总部在首尔，旗下有一辆面包车等着你指挥。\n我们的目标：从这一辆面包车开始，把生意做到全韩国！",
        "tut.after_vehicle": "干得漂亮！第一辆车已经上路了。\n它会自动接单 — 订单送达后会有收入。\n打开地图看看订单的流动吧。",
        "tut.after_delivery": "第一单完成！有了第一笔现金流。\n现在我们需要拓展网络 — 在大客户城市建立末端站点吧。",
        "tut.after_hub": "中转仓库建好了。这会让你的网络更加稳定。\n下一步：建设末端站点，订单需求才会跟着上来。",
        "tut.after_station": "站点建成！当地需求开始流入。\n记得可以在站点继续提升宣传等级，覆盖更广。",
        "tut.after_staff": "好员工能让一切运转得更快 — 司机增加运力，分拣员提升吞吐。\n但要注意：员工要发工资的。",
        "tut.after_tech": "科技树让你获得永久增益：油费降低、速度提升、需求上涨。\n按自己的玩法节奏去研究吧。",
        "tut.after_share": "市占率突破 10%！业务正在起飞。\n竞争对手也在变强，记得持续升级网络与科技。",
        "tut.after_share25": "市占率 25% — 你已经是这个城市群的主要承运商之一。\n接下来，是自由发挥的时间 — 解锁新区域、试不同车型、建立你的快递帝国！",
        "tut.obj.buy_vehicle": "购置第一辆车（车辆页签）",
        "tut.obj.first_delivery": "完成首单配送",
        "tut.obj.build_hub": "建设中转仓库",
        "tut.obj.build_station": "建设末端站点",
        "tut.obj.hire_staff": "招聘第一位员工",
        "tut.obj.unlock_tech": "解锁第一项科技",
        "tut.obj.share10": "市占率达到 10%",
        "tut.obj.share25": "市占率达到 25%（自由经营）",
        "tut.obj.free": "自由经营 — 继续扩张你的快递王国！",

        # 设置
        "set.title": "设置",
        "set.tab.audio": "音频",
        "set.tab.display": "显示",
        "set.tab.language": "语言",
        "set.tab.saves": "存档",
        "set.audio.title": "音频",
        "set.audio.vol_tip": "拖动调整音量（0–100%）",
        "set.display.title": "显示",
        "set.display.fullscreen_on": "全屏模式：开（点击切换）",
        "set.display.fullscreen_off": "全屏模式：关（点击切换）",
        "set.display.note": "提示：分辨率按显示器自动适配；窗口可在边缘拖拽缩放。",
        "set.display.fullscreen_tip": "切换全屏 / 窗口模式",
        "set.language.title": "语言",
        "set.saves.title": "存档管理",
        "set.saves.refresh": "刷新列表",
        "set.saves.save_now": "立即保存",
        "set.saves.load": "读取",
        "set.saves.delete": "删除",
        "set.saves.empty": "还没有存档。开始一场新游戏后会自动保存。",

        # 关于
        "about.title": "关于 CourierSim",
        "about.desc": "CourierSim 快递王国 是一款 2D 像素卡通任天堂风格的快递公司模拟经营游戏。\n首发韩国，未来将扩展海南、越南、马来西亚。",
        "about.tech": "技术栈",
        "about.tech_text": "· Godot 4.7 引擎\n· GDScript\n· 真实地理数据（Natural Earth + OSM / Geofabrik）\n· ComfyUI（Ernie Image Turbo + BiRefNet）批量生成像素素材\n· AGPL-3.0 开源协议",
        "about.data": "数据来源",
        "about.data_text": "· 城市经纬度：Natural Earth 50m、Geofabrik、Overpass（ODbL）\n· 海岸线 / 陆地：Natural Earth 1:50m（Public Domain）\n· 距离 / 时间：球面 Haversine 兜底，未来可接 OSRM",
        "about.assets": "图标资源",
        "about.assets_text": "· ComfyUI 工作流生成（任天堂 8-bit 风）\n· 参考：Kenney CC0、game-icons.net CC BY 3.0",
        "about.license": "许可",
        "about.license_text": "本项目以 AGPL-3.0 协议开源。源码可自由使用、修改、再发布，但衍生作品也必须以 AGPL-3.0 发布并保留署名。详见 LICENSE 文件。",
        "about.thanks": "致谢",
        "about.thanks_text": "感谢 Godot 引擎团队、Natural Earth 数据集维护者、OpenStreetMap 社区、ComfyUI 工作流模板作者，以及所有开源贡献者。",
    },
    "en_US": {
        "menu.new_game": "New Game",
        "menu.continue": "Continue",
        "menu.settings": "Settings",
        "menu.about": "About",
        "menu.quit": "Quit",
        "menu.cancel": "Cancel",
        "menu.hint_v2": "🚚 Build your courier empire in a pixel world. Click a city on the map to build a hub or station. Hover any icon for its tooltip. F2 Settings · F1 About.",

        "tip.new_game": "Start a new courier career",
        "tip.continue": "Load the most recent save",
        "tip.settings": "Audio, display, language and saves",
        "tip.about": "About this game and open-source licence",
        "tip.quit": "Quit the game",
        "tip.cancel": "Go back one step",
        "tip.save": "Save the game right now",
        "tip.menu": "Return to main menu",
        "tip.lang": "Switch language",
        "tip.speed_pause": "Pause / resume game time",
        "tip.speed_x": "Time speed: %dx",
        "tip.tab_map": "Map — view cities and ops",
        "tip.tab_orders": "Orders — pending and in-transit",
        "tip.tab_vehicles": "Vehicles — buy and check status",
        "tip.tab_hubs": "Hubs — upgrade throughput",
        "tip.tab_stations": "Stations — coverage and satisfaction",
        "tip.tab_marketing": "Marketing — spend to raise awareness",
        "tip.tab_tech": "Tech — unlock permanent bonuses",
        "tip.tab_staff": "Staff — hire for bonuses",
        "tip.tab_finance": "Finance — cash flow & profit",
        "tip.tab_region": "Region — unlock other city groups",
        "tip.city_build_hub": "Build a hub in this city ($%d)",
        "tip.city_upgrade_hub": "Upgrade this hub ($%d)",
        "tip.city_build_station": "Build a station in this city ($%d)",
        "tip.city_promote": "Upgrade station marketing ($%d)",
        "tip.close": "Close",
        "tip.back": "Back",

        "tab.group.ops": "Ops",
        "tab.group.fac": "Fac.",
        "tab.group.dev": "Grow",
        "tab.group.mng": "Mgmt",

        "obj.hud": "Objective",

        "dlg.continue": "Continue ▸",

        "tut.speaker.narrator": "Courier Kingdom",
        "tut.speaker.ceo": "Boss Kim",
        "tut.intro": "You've inherited a small courier firm.\nHQ is in Seoul, with one van ready to roll.\nOur goal: from a single van to nationwide dominance!",
        "tut.after_vehicle": "Nice! Your first vehicle is on the road.\nIt auto-picks orders — every delivery brings cash.\nOpen the map and watch the flow.",
        "tut.after_delivery": "First delivery done! Now you have working cash flow.\nNext: build stations in your busiest cities.",
        "tut.after_hub": "Hub built. Your network is more stable now.\nNext: build end stations so demand keeps rising.",
        "tut.after_station": "Station up. Local demand is rolling in.\nYou can keep promoting the station to widen its coverage.",
        "tut.after_staff": "Good staff makes everything faster — drivers boost capacity, sorters lift throughput.\nRemember: they get paid every day.",
        "tut.after_tech": "Tech gives you permanent bonuses: cheaper fuel, faster speed, higher demand.\nResearch at your own pace.",
        "tut.after_share": "10% market share unlocked! Business is taking off.\nCompetitors will get stronger too — keep upgrading.",
        "tut.after_share25": "25% share — you're one of the major carriers here.\nNow it's free play: unlock more regions, try new vehicles, build your empire!",
        "tut.obj.buy_vehicle": "Buy your first vehicle (Vehicles tab)",
        "tut.obj.first_delivery": "Complete the first delivery",
        "tut.obj.build_hub": "Build a hub",
        "tut.obj.build_station": "Build an end station",
        "tut.obj.hire_staff": "Hire your first staff",
        "tut.obj.unlock_tech": "Unlock your first tech",
        "tut.obj.share10": "Reach 10% market share",
        "tut.obj.share25": "Reach 25% share (free play)",
        "tut.obj.free": "Free play — keep growing your empire!",

        "set.title": "Settings",
        "set.tab.audio": "Audio",
        "set.tab.display": "Display",
        "set.tab.language": "Language",
        "set.tab.saves": "Saves",
        "set.audio.title": "Audio",
        "set.audio.vol_tip": "Drag to change volume (0–100%)",
        "set.display.title": "Display",
        "set.display.fullscreen_on": "Fullscreen: ON (click to switch)",
        "set.display.fullscreen_off": "Fullscreen: OFF (click to switch)",
        "set.display.note": "Tip: resolution follows the display. Window can be resized from the edges.",
        "set.display.fullscreen_tip": "Toggle fullscreen / windowed",
        "set.language.title": "Language",
        "set.saves.title": "Save Management",
        "set.saves.refresh": "Refresh",
        "set.saves.save_now": "Save Now",
        "set.saves.load": "Load",
        "set.saves.delete": "Delete",
        "set.saves.empty": "No saves yet. They will be created automatically when you play.",

        "about.title": "About CourierSim",
        "about.desc": "CourierSim is a 2D pixel-art, Nintendo-styled courier business sim.\nIt launches in South Korea, with Hainan, Vietnam and Malaysia planned.",
        "about.tech": "Tech Stack",
        "about.tech_text": "· Godot 4.7\n· GDScript\n· Real geography (Natural Earth + OSM / Geofabrik)\n· ComfyUI (Ernie Image Turbo + BiRefNet) for pixel assets\n· AGPL-3.0",
        "about.data": "Data Sources",
        "about.data_text": "· City coordinates: Natural Earth 50m, Geofabrik, Overpass (ODbL)\n· Coastlines / land: Natural Earth 1:50m (Public Domain)\n· Distance / time: spherical Haversine; OSRM as future upgrade",
        "about.assets": "Icon Assets",
        "about.assets_text": "· Generated by ComfyUI (Nintendo 8-bit style)\n· References: Kenney CC0, game-icons.net CC BY 3.0",
        "about.license": "License",
        "about.license_text": "This project is open source under AGPL-3.0. You may use, modify and redistribute it freely, but derivatives must also be AGPL-3.0 and retain attribution. See the LICENSE file.",
        "about.thanks": "Thanks",
        "about.thanks_text": "Thanks to the Godot team, the Natural Earth maintainers, the OpenStreetMap community, the ComfyUI workflow authors and every open-source contributor.",
    },
}


def main():
    with open(PATH, "r", encoding="utf-8") as f:
        data = json.load(f)
    added = 0
    for locale in NEW:
        table = data.setdefault(locale, {})
        for k, v in NEW[locale].items():
            if k not in table:
                table[k] = v
                added += 1
    # 写回 UTF-8 + LF
    text = json.dumps(data, ensure_ascii=False, indent=2) + "\n"
    with open(PATH, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    print(f"merged {added} new keys; file: {PATH}")


if __name__ == "__main__":
    main()