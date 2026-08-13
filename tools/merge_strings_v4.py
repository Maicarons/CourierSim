#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""merge_strings_v4.py — 追加 v0.6 新键（暂停菜单/确认弹窗/成就），中英同步。"""
import json

PATH = r"G:\GitHub\CourierSim\src\i18n\strings.json"

NEW = {
    "zh_CN": {
        "pause.title": "游戏菜单",
        "pause.hint": "按 ESC 继续",
        "pause.resume": "继续游戏",
        "pause.save": "保存进度",
        "menu.menu": "主菜单",
        "dlg.cancel": "取消",
        "dlg.confirm": "确认",
        "confirm.quit_title": "返回主菜单？",
        "confirm.quit_msg": "未保存的进度将丢失。确定要离开吗？",
        "toast.ach": "🏅 成就解锁：%s",
        "ach.unlocked": "已解锁",
        "ach.locked": "未解锁",
        "ach.progress": "已解锁 %d / %d 项成就",
        "set.tab.achievements": "成就",
        "set.achievements.title": "成就",
        "set.saves.delete_confirm_title": "删除存档？",
        "set.saves.delete_confirm_msg": "存档「%s」将被永久删除，且无法恢复。",
    },
    "en_US": {
        "pause.title": "Game Menu",
        "pause.hint": "Press ESC to continue",
        "pause.resume": "Resume",
        "pause.save": "Save Game",
        "menu.menu": "Main Menu",
        "dlg.cancel": "Cancel",
        "dlg.confirm": "Confirm",
        "confirm.quit_title": "Return to main menu?",
        "confirm.quit_msg": "Unsaved progress will be lost. Leave anyway?",
        "toast.ach": "🏅 Achievement unlocked: %s",
        "ach.unlocked": "Unlocked",
        "ach.locked": "Locked",
        "ach.progress": "Unlocked %d / %d achievements",
        "set.tab.achievements": "Achievements",
        "set.achievements.title": "Achievements",
        "set.saves.delete_confirm_title": "Delete save?",
        "set.saves.delete_confirm_msg": "Save \"%s\" will be permanently deleted and cannot be restored.",
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
    text = json.dumps(data, ensure_ascii=False, indent=2) + "\n"
    with open(PATH, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    print("merged %d new keys" % added)


if __name__ == "__main__":
    main()