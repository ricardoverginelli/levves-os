#!/usr/bin/env python3
"""Theme VS Code as "Leaves" from design/dist/palette.json.

Writes the color theme (workbench, syntax, terminal) into a small extension,
packs it as a .vsix and installs it with `code --install-extension`. Pick it
with Preferences: Color Theme → Leaves.

Prints "changed" when the installed theme was replaced; VS Code windows that
are already open pick it up after Developer: Reload Window.
"""
import json
import shutil
import subprocess
import tempfile
import zipfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
PUBLISHER = "leaves"
NAME = "leaves-theme"
VERSION = "1.0.0"
THEME_FILE = "themes/leaves-color-theme.json"
INSTALLED = Path.home() / f".vscode/extensions/{PUBLISHER}.{NAME}-{VERSION}"

p = json.loads((HERE.parents[3] / "design/dist/palette.json").read_text())
t = p["terminal"]


def rgb(hex_color):
    h = hex_color.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def mix(a, b, t):
    """Blend hex color a toward b by t (0..1)."""
    return "#" + "".join(f"{round(x + (y - x) * t):02x}" for x, y in zip(rgb(a), rgb(b)))


def alpha(color, opacity):
    """Palette color (or hex) as #rrggbbaa."""
    return p.get(color, color) + f"{round(opacity * 255):02x}"


# --- Syntax ---------------------------------------------------------------
# Accent amber stays out of the code (DESIGN.md: one accented thing per view;
# here that's the cursor, focus and selection). Semantic and ANSI colors carry it.

SYNTAX = {
    "comment": mix(p["text-faint"], p["text-muted"], 0.3),
    "keyword": t["magenta"],
    "function": p["info"],
    "type": t["cyan"],
    "string": p["success"],
    "constant": p["warning"],
    "tag": mix(p["critical"], p["text"], 0.2),
    "attribute": mix(p["warning"], p["text"], 0.35),
    "property": mix(p["text"], p["info"], 0.3),
    "punctuation": p["text-muted"],
    "variable": p["text"],
}

TOKENS = [
    ("Comments", ["comment", "punctuation.definition.comment"], "comment", "italic"),
    ("Keywords", ["keyword", "storage", "storage.type", "storage.modifier",
                  "keyword.control", "keyword.operator.new", "keyword.operator.expression",
                  "keyword.operator.logical.python", "variable.language.this",
                  "variable.language.self", "variable.language.super"], "keyword", None),
    ("Operators and punctuation", ["keyword.operator", "punctuation", "meta.brace",
                                   "punctuation.definition.tag"], "punctuation", None),
    ("Functions", ["entity.name.function", "support.function", "meta.function-call",
                   "variable.function"], "function", None),
    ("Types", ["entity.name.type", "entity.name.class", "entity.other.inherited-class",
               "support.type", "support.class", "entity.name.namespace", "storage.type.cs",
               "entity.name.type.module"], "type", None),
    ("Strings", ["string", "string.template", "markup.inline.raw",
                 "punctuation.definition.string"], "string", None),
    ("Escapes and regex", ["constant.character.escape", "string.regexp",
                           "punctuation.definition.template-expression",
                           "punctuation.section.embedded"], "type", None),
    ("Constants", ["constant", "constant.numeric", "constant.language",
                   "support.constant", "variable.other.constant", "variable.other.enummember",
                   "entity.name.constant"], "constant", None),
    ("Variables", ["variable", "variable.other", "meta.definition.variable"], "variable", None),
    ("Parameters", ["variable.parameter"], "variable", "italic"),
    ("Properties", ["variable.other.property", "variable.other.object.property",
                    "support.variable.property", "meta.object-literal.key",
                    "support.type.property-name", "entity.name.tag.yaml",
                    "entity.name.tag.toml", "support.type.property-name.json"], "property", None),
    ("Tags", ["entity.name.tag", "meta.tag.sgml"], "tag", None),
    ("Components", ["support.class.component", "entity.name.tag.tsx",
                    "entity.name.tag.jsx"], "type", None),
    ("Attributes", ["entity.other.attribute-name", "entity.other.attribute-name.class.css",
                    "entity.other.attribute-name.id.css"], "attribute", None),
    ("Decorators", ["meta.decorator", "entity.name.function.decorator",
                    "punctuation.decorator"], "attribute", None),
    ("CSS values", ["support.constant.property-value", "keyword.other.unit",
                    "constant.other.color"], "constant", None),
    ("Imports", ["keyword.control.import", "keyword.control.export",
                 "keyword.control.from"], "keyword", "italic"),
]

MARKUP = [
    ("Headings", ["markup.heading", "markup.heading entity.name",
                  "punctuation.definition.heading"], p["accent"], "bold"),
    ("Bold", ["markup.bold"], p["text"], "bold"),
    ("Italic", ["markup.italic"], p["text"], "italic"),
    ("Links", ["markup.underline.link", "string.other.link"], p["info"], None),
    ("Quotes", ["markup.quote"], p["text-muted"], "italic"),
    ("Lists", ["punctuation.definition.list", "beginning.punctuation.definition.list"],
     t["magenta"], None),
    ("Inserted", ["markup.inserted"], p["success"], None),
    ("Deleted", ["markup.deleted"], p["critical"], None),
    ("Changed", ["markup.changed"], p["info"], None),
    ("Invalid", ["invalid", "invalid.illegal"], p["critical"], None),
]


def token_colors():
    rules = []
    for name, scopes, role, style in TOKENS:
        rules.append((name, scopes, SYNTAX[role], style))
    rules += MARKUP
    out = []
    for name, scopes, color, style in rules:
        settings = {"foreground": color}
        if style:
            settings["fontStyle"] = style
        out.append({"name": name, "scope": scopes, "settings": settings})
    return out


SEMANTIC = {
    "keyword": SYNTAX["keyword"],
    "function": SYNTAX["function"],
    "method": SYNTAX["function"],
    "class": SYNTAX["type"],
    "interface": SYNTAX["type"],
    "struct": SYNTAX["type"],
    "enum": SYNTAX["type"],
    "type": SYNTAX["type"],
    "typeParameter": SYNTAX["type"],
    "namespace": SYNTAX["type"],
    "enumMember": SYNTAX["constant"],
    "variable": SYNTAX["variable"],
    "variable.readonly.defaultLibrary": SYNTAX["constant"],
    "parameter": {"foreground": SYNTAX["variable"], "italic": True},
    "property": SYNTAX["property"],
    "decorator": SYNTAX["attribute"],
    "macro": SYNTAX["attribute"],
    "string": SYNTAX["string"],
    "number": SYNTAX["constant"],
    "regexp": SYNTAX["type"],
    "comment": {"foreground": SYNTAX["comment"], "italic": True},
}


# --- Workbench ------------------------------------------------------------

def workbench():
    bg, deep, surface, raised, border = p["bg"], p["bg-deep"], p["surface"], p["raised"], p["border"]
    text, muted, faint = p["text"], p["text-muted"], p["text-faint"]
    accent, on_accent = p["accent"], p["on-accent"]
    hover = alpha("text", 0.06)        # DESIGN.md: neutral hover
    highlight = alpha("accent", 0.18)  # DESIGN.md: keyboard highlight in lists
    selection = alpha("info", 0.28)

    c = {
        # Base
        "foreground": text,
        "descriptionForeground": muted,
        "disabledForeground": faint,
        "errorForeground": p["critical"],
        "icon.foreground": muted,
        "focusBorder": alpha("text", 0.25),  # focus rings stay neutral
        "contrastBorder": "#00000000",
        "widget.border": border,
        "widget.shadow": alpha("bg-deep", 0.6),
        "selection.background": selection,
        "textLink.foreground": p["info"],
        "textLink.activeForeground": mix(p["info"], "#ffffff", 0.25),
        "textCodeBlock.background": surface,
        "textBlockQuote.background": surface,
        "textBlockQuote.border": border,
        "textPreformat.foreground": SYNTAX["string"],
        "textSeparator.foreground": border,
        "sash.hoverBorder": alpha("accent", 0.6),
        "progressBar.background": accent,
        "toolbar.hoverBackground": hover,
        "toolbar.activeBackground": alpha("text", 0.1),

        # Window chrome
        "titleBar.activeBackground": bg,
        "titleBar.activeForeground": muted,
        "titleBar.inactiveBackground": bg,
        "titleBar.inactiveForeground": faint,
        "titleBar.border": border,
        "commandCenter.background": surface,
        "commandCenter.foreground": muted,
        "commandCenter.activeBackground": raised,
        "commandCenter.border": border,
        "commandCenter.inactiveBorder": border,
        "menubar.selectionBackground": hover,
        "menu.background": surface,
        "menu.foreground": text,
        "menu.selectionBackground": highlight,
        "menu.selectionForeground": text,
        "menu.separatorBackground": border,
        "menu.border": border,

        # Activity bar
        "activityBar.background": bg,
        "activityBar.foreground": text,
        "activityBar.inactiveForeground": faint,
        "activityBar.activeBorder": accent,
        "activityBar.activeBackground": "#00000000",
        "activityBar.border": border,
        "activityBarBadge.background": accent,
        "activityBarBadge.foreground": on_accent,
        "activityBarTop.foreground": text,
        "activityBarTop.inactiveForeground": faint,
        "activityBarTop.activeBorder": accent,

        # Side bar
        "sideBar.background": bg,
        "sideBar.foreground": muted,
        "sideBar.border": border,
        "sideBarTitle.foreground": muted,
        "sideBarSectionHeader.background": bg,
        "sideBarSectionHeader.foreground": muted,
        "sideBarSectionHeader.border": border,
        "sideBarStickyScroll.background": bg,
        "sideBarStickyScroll.shadow": alpha("bg-deep", 0.6),

        # Lists and trees
        "list.hoverBackground": hover,
        "list.hoverForeground": text,
        "list.activeSelectionBackground": highlight,
        "list.activeSelectionForeground": text,
        "list.activeSelectionIconForeground": text,
        "list.inactiveSelectionBackground": alpha("text", 0.08),
        "list.inactiveSelectionForeground": text,
        "list.focusBackground": highlight,
        "list.focusForeground": text,
        "list.focusOutline": "#00000000",
        "list.focusAndSelectionOutline": "#00000000",
        "list.inactiveFocusOutline": "#00000000",
        "list.highlightForeground": accent,
        "list.focusHighlightForeground": p["accent-hover"],
        "list.dropBackground": alpha("accent", 0.12),
        "list.errorForeground": p["critical"],
        "list.warningForeground": p["warning"],
        "list.invalidItemForeground": p["critical"],
        "list.deemphasizedForeground": faint,
        "tree.indentGuidesStroke": border,
        "tree.inactiveIndentGuidesStroke": alpha("border", 0.6),

        # Editor groups and tabs (selected tab: accent line on top, like Yakuake's)
        "editorGroup.border": border,
        "editorGroup.dropBackground": alpha("accent", 0.08),
        "editorGroupHeader.tabsBackground": bg,
        "editorGroupHeader.tabsBorder": border,
        "editorGroupHeader.noTabsBackground": bg,
        "editorGroupHeader.border": border,
        "tab.activeBackground": bg,
        "tab.activeForeground": text,
        "tab.activeBorderTop": accent,
        "tab.activeBorder": bg,
        "tab.unfocusedActiveBorderTop": border,
        "tab.unfocusedActiveForeground": muted,
        "tab.inactiveBackground": deep,
        "tab.inactiveForeground": faint,
        "tab.unfocusedInactiveForeground": faint,
        "tab.hoverBackground": surface,
        "tab.hoverForeground": text,
        "tab.border": border,
        "tab.lastPinnedBorder": border,
        "tab.activeModifiedBorder": accent,
        "tab.inactiveModifiedBorder": alpha("accent", 0.5),
        "breadcrumb.foreground": faint,
        "breadcrumb.focusForeground": text,
        "breadcrumb.activeSelectionForeground": text,
        "breadcrumb.background": bg,
        "breadcrumbPicker.background": surface,

        # Editor
        "editor.background": bg,
        "editor.foreground": text,
        "editorCursor.foreground": accent,
        "editorCursor.background": on_accent,
        "editorLineNumber.foreground": alpha("text-faint", 0.7),
        "editorLineNumber.activeForeground": muted,
        "editor.lineHighlightBackground": alpha("text", 0.035),
        "editor.lineHighlightBorder": "#00000000",
        "editor.selectionBackground": selection,
        "editor.inactiveSelectionBackground": alpha("info", 0.15),
        "editor.selectionHighlightBackground": alpha("info", 0.14),
        "editor.wordHighlightBackground": alpha("text", 0.08),
        "editor.wordHighlightStrongBackground": alpha("text", 0.12),
        "editor.findMatchBackground": alpha("warning", 0.35),
        "editor.findMatchBorder": p["warning"],
        "editor.findMatchHighlightBackground": alpha("warning", 0.16),
        "editor.findRangeHighlightBackground": alpha("text", 0.04),
        "editor.rangeHighlightBackground": alpha("text", 0.05),
        "editor.hoverHighlightBackground": alpha("info", 0.12),
        "editor.linkedEditingBackground": alpha("info", 0.12),
        "editorLink.activeForeground": p["info"],
        "editorWhitespace.foreground": alpha("text-faint", 0.5),
        "editorIndentGuide.background1": alpha("border", 0.8),
        "editorIndentGuide.activeBackground1": faint,
        "editorRuler.foreground": alpha("border", 0.8),
        "editorCodeLens.foreground": faint,
        "editorInlayHint.foreground": muted,
        "editorInlayHint.background": alpha("raised", 0.7),
        "editorBracketMatch.background": alpha("text", 0.1),
        "editorBracketMatch.border": alpha("text", 0.3),
        "editorBracketHighlight.foreground1": p["warning"],
        "editorBracketHighlight.foreground2": t["magenta"],
        "editorBracketHighlight.foreground3": p["info"],
        "editorBracketHighlight.foreground4": t["cyan"],
        "editorBracketHighlight.foreground5": p["success"],
        "editorBracketHighlight.foreground6": mix(p["critical"], p["text"], 0.2),
        "editorBracketHighlight.unexpectedBracket.foreground": p["critical"],
        "editorBracketPairGuide.activeBackground1": alpha("warning", 0.5),
        "editorBracketPairGuide.activeBackground2": alpha(t["magenta"], 0.5),
        "editorBracketPairGuide.activeBackground3": alpha("info", 0.5),
        "editorUnnecessaryCode.opacity": "#00000088",
        "editorStickyScroll.background": bg,
        "editorStickyScroll.shadow": alpha("bg-deep", 0.6),
        "editorStickyScrollHover.background": surface,
        "editorOverviewRuler.border": "#00000000",
        "editorOverviewRuler.findMatchForeground": alpha("warning", 0.6),
        "editorOverviewRuler.selectionHighlightForeground": alpha("info", 0.5),
        "editorOverviewRuler.errorForeground": p["critical"],
        "editorOverviewRuler.warningForeground": p["warning"],
        "editorOverviewRuler.infoForeground": p["info"],
        "editorOverviewRuler.addedForeground": alpha("success", 0.6),
        "editorOverviewRuler.modifiedForeground": alpha("info", 0.6),
        "editorOverviewRuler.deletedForeground": alpha("critical", 0.6),
        "editorError.foreground": p["critical"],
        "editorWarning.foreground": p["warning"],
        "editorInfo.foreground": p["info"],
        "editorHint.foreground": muted,
        "problemsErrorIcon.foreground": p["critical"],
        "problemsWarningIcon.foreground": p["warning"],
        "problemsInfoIcon.foreground": p["info"],
        "editorGutter.background": bg,
        "editorGutter.addedBackground": p["success"],
        "editorGutter.modifiedBackground": p["info"],
        "editorGutter.deletedBackground": p["critical"],
        "editorGutter.foldingControlForeground": faint,

        # Editor widgets (find, suggest, hover, peek): popups are surface
        "editorWidget.background": surface,
        "editorWidget.foreground": text,
        "editorWidget.border": border,
        "editorWidget.resizeBorder": alpha("accent", 0.6),
        "editorSuggestWidget.background": surface,
        "editorSuggestWidget.border": border,
        "editorSuggestWidget.foreground": text,
        "editorSuggestWidget.selectedBackground": highlight,
        "editorSuggestWidget.selectedForeground": text,
        "editorSuggestWidget.highlightForeground": accent,
        "editorSuggestWidget.focusHighlightForeground": p["accent-hover"],
        "editorHoverWidget.background": surface,
        "editorHoverWidget.border": border,
        "editorHoverWidget.statusBarBackground": raised,
        "editorGhostText.foreground": faint,
        "peekView.border": border,
        "peekViewTitle.background": surface,
        "peekViewTitleLabel.foreground": text,
        "peekViewTitleDescription.foreground": muted,
        "peekViewEditor.background": deep,
        "peekViewEditorGutter.background": deep,
        "peekViewEditor.matchHighlightBackground": alpha("warning", 0.25),
        "peekViewResult.background": surface,
        "peekViewResult.selectionBackground": highlight,
        "peekViewResult.selectionForeground": text,
        "peekViewResult.matchHighlightBackground": alpha("warning", 0.25),
        "peekViewResult.lineForeground": muted,
        "peekViewResult.fileForeground": text,

        # Diff
        "diffEditor.insertedTextBackground": alpha("success", 0.16),
        "diffEditor.removedTextBackground": alpha("critical", 0.16),
        "diffEditor.insertedLineBackground": alpha("success", 0.08),
        "diffEditor.removedLineBackground": alpha("critical", 0.08),
        "diffEditor.diagonalFill": alpha("border", 0.6),
        "diffEditorGutter.insertedLineBackground": alpha("success", 0.12),
        "diffEditorGutter.removedLineBackground": alpha("critical", 0.12),
        "merge.currentHeaderBackground": alpha("success", 0.3),
        "merge.currentContentBackground": alpha("success", 0.1),
        "merge.incomingHeaderBackground": alpha("info", 0.3),
        "merge.incomingContentBackground": alpha("info", 0.1),

        # Inputs and buttons
        "input.background": raised,
        "input.foreground": text,
        "input.border": "#00000000",
        "input.placeholderForeground": faint,
        "inputOption.activeBackground": highlight,
        "inputOption.activeBorder": "#00000000",
        "inputOption.activeForeground": text,
        "inputOption.hoverBackground": hover,
        "inputValidation.errorBackground": surface,
        "inputValidation.errorBorder": p["critical"],
        "inputValidation.warningBackground": surface,
        "inputValidation.warningBorder": p["warning"],
        "inputValidation.infoBackground": surface,
        "inputValidation.infoBorder": p["info"],
        "dropdown.background": raised,
        "dropdown.listBackground": surface,
        "dropdown.border": "#00000000",
        "dropdown.foreground": text,
        "checkbox.background": raised,
        "checkbox.border": border,
        "checkbox.foreground": accent,
        "checkbox.selectBackground": surface,
        "button.background": accent,
        "button.foreground": on_accent,
        "button.hoverBackground": p["accent-hover"],
        "button.border": "#00000000",
        "button.separator": alpha("on-accent", 0.3),
        "button.secondaryBackground": raised,
        "button.secondaryForeground": text,
        "button.secondaryHoverBackground": mix(raised, text, 0.08),
        "badge.background": raised,
        "badge.foreground": text,
        "scrollbar.shadow": alpha("bg-deep", 0.5),
        "scrollbarSlider.background": alpha("text", 0.1),
        "scrollbarSlider.hoverBackground": alpha("text", 0.16),
        "scrollbarSlider.activeBackground": alpha("text", 0.22),
        "keybindingLabel.background": raised,
        "keybindingLabel.foreground": text,
        "keybindingLabel.border": border,
        "keybindingLabel.bottomBorder": border,

        # Quick input (command palette)
        "quickInput.background": surface,
        "quickInput.foreground": text,
        "quickInputTitle.background": surface,
        "quickInputList.focusBackground": highlight,
        "quickInputList.focusForeground": text,
        "quickInputList.focusIconForeground": text,
        "pickerGroup.foreground": muted,
        "pickerGroup.border": border,

        # Panel and terminal
        "panel.background": bg,
        "panel.border": border,
        "panelTitle.activeForeground": text,
        "panelTitle.activeBorder": accent,
        "panelTitle.inactiveForeground": faint,
        "panelSection.border": border,
        "panelSectionHeader.background": bg,
        "panelInput.border": "#00000000",
        "outputView.background": bg,
        "terminal.background": bg,
        "terminal.foreground": text,
        "terminal.border": border,
        "terminal.selectionBackground": selection,
        "terminalCursor.foreground": accent,
        "terminalCursor.background": on_accent,
        "terminal.findMatchBackground": alpha("warning", 0.35),
        "terminal.findMatchHighlightBackground": alpha("warning", 0.16),
        "terminalCommandDecoration.defaultBackground": faint,
        "terminalCommandDecoration.successBackground": p["success"],
        "terminalCommandDecoration.errorBackground": p["critical"],
        "terminalOverviewRuler.cursorForeground": accent,

        # Status bar: quiet, like the top bar
        "statusBar.background": bg,
        "statusBar.foreground": muted,
        "statusBar.border": border,
        "statusBar.focusBorder": alpha("text", 0.25),
        "statusBar.noFolderBackground": bg,
        "statusBar.noFolderForeground": muted,
        "statusBar.debuggingBackground": p["accent-pressed"],
        "statusBar.debuggingForeground": on_accent,
        "statusBar.debuggingBorder": p["accent-pressed"],
        "statusBarItem.hoverBackground": hover,
        "statusBarItem.hoverForeground": text,
        "statusBarItem.activeBackground": alpha("text", 0.1),
        "statusBarItem.remoteBackground": bg,
        "statusBarItem.remoteForeground": accent,
        "statusBarItem.prominentBackground": raised,
        "statusBarItem.prominentHoverBackground": mix(raised, text, 0.08),
        "statusBarItem.errorBackground": p["critical"],
        "statusBarItem.errorForeground": on_accent,
        "statusBarItem.warningBackground": p["warning"],
        "statusBarItem.warningForeground": on_accent,
        "statusBarItem.focusBorder": alpha("text", 0.25),

        # Notifications
        "notifications.background": surface,
        "notifications.foreground": text,
        "notifications.border": border,
        "notificationCenterHeader.background": surface,
        "notificationCenter.border": border,
        "notificationToast.border": border,
        "notificationLink.foreground": p["info"],
        "notificationsErrorIcon.foreground": p["critical"],
        "notificationsWarningIcon.foreground": p["warning"],
        "notificationsInfoIcon.foreground": p["info"],

        # Git and SCM decorations
        "gitDecoration.addedResourceForeground": p["success"],
        "gitDecoration.untrackedResourceForeground": p["success"],
        "gitDecoration.modifiedResourceForeground": p["info"],
        "gitDecoration.deletedResourceForeground": p["critical"],
        "gitDecoration.renamedResourceForeground": t["cyan"],
        "gitDecoration.conflictingResourceForeground": p["warning"],
        "gitDecoration.ignoredResourceForeground": faint,
        "gitDecoration.submoduleResourceForeground": t["magenta"],
        "gitDecoration.stageModifiedResourceForeground": p["info"],
        "gitDecoration.stageDeletedResourceForeground": p["critical"],
        "scmGraph.historyItemRefColor": p["info"],
        "scmGraph.historyItemRemoteRefColor": t["magenta"],
        "scmGraph.historyItemBaseRefColor": p["warning"],
        "scmGraph.historyItemHoverDefaultLabelForeground": text,

        # Misc
        "welcomePage.tileBackground": surface,
        "welcomePage.tileHoverBackground": raised,
        "welcomePage.tileBorder": border,
        "walkThrough.embeddedEditorBackground": deep,
        "settings.headerForeground": text,
        "settings.modifiedItemIndicator": accent,
        "settings.focusedRowBackground": alpha("text", 0.03),
        "settings.rowHoverBackground": alpha("text", 0.03),
        "settings.dropdownBackground": raised,
        "settings.textInputBackground": raised,
        "settings.numberInputBackground": raised,
        "settings.checkboxBackground": raised,
        "debugToolBar.background": surface,
        "debugToolBar.border": border,
        "debugIcon.breakpointForeground": p["critical"],
        "editor.stackFrameHighlightBackground": alpha("warning", 0.14),
        "editor.focusedStackFrameHighlightBackground": alpha("success", 0.14),
        "minimap.background": bg,
        "minimap.findMatchHighlight": alpha("warning", 0.6),
        "minimap.selectionHighlight": alpha("info", 0.5),
        "minimapSlider.background": alpha("text", 0.06),
        "minimapSlider.hoverBackground": alpha("text", 0.1),
        "minimapSlider.activeBackground": alpha("text", 0.14),
        "chat.requestBackground": surface,
        "chat.requestBorder": border,
        "chat.slashCommandBackground": raised,
        "chat.slashCommandForeground": accent,
        "inlineChat.background": surface,
        "inlineChat.border": border,
        "charts.foreground": text,
        "charts.lines": border,
        "charts.red": p["critical"],
        "charts.yellow": p["warning"],
        "charts.orange": accent,
        "charts.green": p["success"],
        "charts.blue": p["info"],
        "charts.purple": t["magenta"],
    }

    # Terminal ANSI, as in the Konsole scheme (yakuake/build.py): bright is 25% toward white
    ansi = {"Black": t["black"], "Red": p["critical"], "Green": p["success"],
            "Yellow": p["warning"], "Blue": p["info"], "Magenta": t["magenta"],
            "Cyan": t["cyan"], "White": p["text"]}
    for name, color in ansi.items():
        c[f"terminal.ansi{name}"] = color
        c[f"terminal.ansiBright{name}"] = t["bright-black"] if name == "Black" else mix(color, "#ffffff", 0.25)
    return c


def theme():
    return {
        "name": "Leaves",
        "type": "dark",
        "semanticHighlighting": True,
        "colors": workbench(),
        "tokenColors": token_colors(),
        "semanticTokenColors": SEMANTIC,
    }


# --- Package --------------------------------------------------------------

def package_json():
    return {
        "name": NAME,
        "displayName": "Leaves",
        "description": "Dark, cool theme from the Leaves Plasma palette",
        "publisher": PUBLISHER,
        "version": VERSION,
        "engines": {"vscode": "^1.70.0"},
        "categories": ["Themes"],
        "contributes": {"themes": [{"label": "Leaves", "uiTheme": "vs-dark", "path": f"./{THEME_FILE}"}]},
    }


CONTENT_TYPES = """<?xml version="1.0" encoding="utf-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension=".json" ContentType="application/json"/>
<Default Extension=".vsixmanifest" ContentType="text/xml"/>
</Types>
"""

MANIFEST = f"""<?xml version="1.0" encoding="utf-8"?>
<PackageManifest Version="2.0.0" xmlns="http://schemas.microsoft.com/developer/vsx-schema/2011">
<Metadata>
<Identity Language="en-US" Id="{NAME}" Version="{VERSION}" Publisher="{PUBLISHER}"/>
<DisplayName>Leaves</DisplayName>
<Description xml:space="preserve">Dark, cool theme from the Leaves Plasma palette</Description>
<Categories>Themes</Categories>
<Properties><Property Id="Microsoft.VisualStudio.Code.Engine" Value="^1.70.0"/></Properties>
</Metadata>
<Installation><InstallationTarget Id="Microsoft.VisualStudio.Code"/></Installation>
<Dependencies/>
<Assets><Asset Type="Microsoft.VisualStudio.Code.Manifest" Path="extension/package.json" Addressable="true"/></Assets>
</PackageManifest>
"""


def dump(data):
    return json.dumps(data, indent=2) + "\n"


def main():
    files = {"package.json": dump(package_json()), THEME_FILE: dump(theme())}
    def installed(name):
        # VS Code reformats package.json and adds __metadata on install
        path = INSTALLED / name
        data = json.loads(path.read_text()) if path.exists() else None
        if isinstance(data, dict):
            data.pop("__metadata", None)
        return data

    if all(installed(name) == json.loads(text) for name, text in files.items()):
        return

    with tempfile.TemporaryDirectory() as tmp:
        vsix = Path(tmp) / f"{NAME}-{VERSION}.vsix"
        with zipfile.ZipFile(vsix, "w", zipfile.ZIP_DEFLATED) as z:
            z.writestr("[Content_Types].xml", CONTENT_TYPES)
            z.writestr("extension.vsixmanifest", MANIFEST)
            for name, text in files.items():
                z.writestr(f"extension/{name}", text)
        subprocess.run(["code", "--install-extension", str(vsix), "--force"],
                       check=True, capture_output=True)
    print("changed")


if __name__ == "__main__":
    shutil.which("code") or exit("code not found")
    main()
