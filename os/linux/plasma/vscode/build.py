#!/usr/bin/env python3
"""Theme VS Code as "Levves" from design/dist (design/DESIGN.md, direction D).

Writes the color theme (workbench, syntax, terminal) into a small extension,
packs it as a .vsix and installs it with `code --install-extension`. Pick it
with Preferences: Color Theme → Levves (picked for you when Leaves was).

Prints "changed" when the installed theme was replaced; VS Code windows that
are already open pick it up after Developer: Reload Window.
"""
import json
import sys
import re
import shutil
import subprocess
import tempfile
import zipfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
PUBLISHER = "levves"
NAME = "levves-theme"
VERSION = "1.0.0"
THEME_FILE = "themes/levves-color-theme.json"
OLD = "leaves.leaves-theme"  # the glass-era theme, replaced by this one
SETTINGS = Path.home() / ".config/Code/User/settings.json"
INSTALLED = Path.home() / f".vscode/extensions/{PUBLISHER}.{NAME}-{VERSION}"

DIST = HERE.parents[3] / "design/dist"
sys.path.insert(0, str(DIST))
from levves_tokens import TOKENS as LEVVES, color as palette  # noqa: E402  (TOKENS below is the syntax scopes)


def rgb(hex_color):
    h = hex_color.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def mix(a, b, t):
    """Blend hex color a toward b by t (0..1)."""
    return "#" + "".join(f"{round(x + (y - x) * t):02x}" for x, y in zip(rgb(a), rgb(b)))


def alpha(color, opacity):
    """Palette color (or hex) as #rrggbbaa."""
    return (color if color.startswith("#") else palette(color)) + f"{round(opacity * 255):02x}"


# --- Syntax ---------------------------------------------------------------
# Accent amber stays out of the code (DESIGN.md: one accented thing per view;
# here that's the cursor, focus and selection). Semantic and ANSI colors carry it.

SYNTAX = {
    "comment": mix(palette("text-faint"), palette("text-muted"), 0.3),
    "keyword": palette("terminal.magenta"),
    "function": palette("info"),
    "type": palette("terminal.cyan"),
    "string": palette("success"),
    "constant": palette("warning"),
    "tag": mix(palette("critical"), palette("text"), 0.2),
    "attribute": mix(palette("warning"), palette("text"), 0.35),
    "property": mix(palette("text"), palette("info"), 0.3),
    "punctuation": palette("text-muted"),
    "variable": palette("text"),
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
                  "punctuation.definition.heading"], palette("accent"), "bold"),
    ("Bold", ["markup.bold"], palette("text"), "bold"),
    ("Italic", ["markup.italic"], palette("text"), "italic"),
    ("Links", ["markup.underline.link", "string.other.link"], palette("info"), None),
    ("Quotes", ["markup.quote"], palette("text-muted"), "italic"),
    ("Lists", ["punctuation.definition.list", "beginning.punctuation.definition.list"],
     palette("terminal.magenta"), None),
    ("Inserted", ["markup.inserted"], palette("success"), None),
    ("Deleted", ["markup.deleted"], palette("critical"), None),
    ("Changed", ["markup.changed"], palette("info"), None),
    ("Invalid", ["invalid", "invalid.illegal"], palette("critical"), None),
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
    # D's window: chrome on `surface` with the black `edge` between parts and around popups,
    # headers and the status bar as dithered strips (flat dither-a: themes can't tile), fields
    # in wells, the editor and terminal on `bg`. Amber is the focused part's selection, the
    # primary key, the cursor and the focus ring; elsewhere a selection is `raised`
    bg, surface, raised, border = palette("bg"), palette("surface"), palette("raised"), palette("border")
    text, muted, faint = palette("text"), palette("text-muted"), palette("text-faint")
    accent, on_accent = palette("accent"), palette("on-accent")
    edge, well, strip = palette("edge"), palette("well"), palette("dither-a")
    hover = alpha("text", LEVVES["opacity.hover"])
    highlight = alpha("accent", LEVVES["opacity.selection"])
    selection = alpha("info", 0.28)  # selected text in the editor, apart from the amber cursor

    c = {
        # Base
        "foreground": text,
        "descriptionForeground": muted,
        "disabledForeground": faint,
        "errorForeground": palette("critical"),
        "icon.foreground": muted,
        "focusBorder": accent,  # the amber ring for focus, as on Plasma's keys
        "contrastBorder": "#00000000",
        "widget.border": edge,
        "widget.shadow": alpha("bg-deep", 0.6),
        "selection.background": selection,
        "textLink.foreground": palette("info"),
        "textLink.activeForeground": mix(palette("info"), "#ffffff", 0.25),
        "textCodeBlock.background": surface,
        "textBlockQuote.background": surface,
        "textBlockQuote.border": border,
        "textPreformat.foreground": SYNTAX["string"],
        "textSeparator.foreground": border,
        "sash.hoverBorder": muted,
        "progressBar.background": accent,
        "toolbar.hoverBackground": hover,
        "toolbar.activeBackground": alpha("text", 0.1),

        # Window chrome
        "titleBar.activeBackground": palette("title-bar"),
        "titleBar.activeForeground": text,
        "titleBar.inactiveBackground": palette("title-bar-inactive"),
        "titleBar.inactiveForeground": muted,
        "titleBar.border": edge,
        "commandCenter.background": well,  # a field
        "commandCenter.foreground": muted,
        "commandCenter.activeBackground": palette("well-pressed"),
        "commandCenter.border": palette("field-edge"),
        "commandCenter.inactiveBorder": palette("field-edge"),
        "menubar.selectionBackground": hover,
        "menu.background": surface,
        "menu.foreground": text,
        "menu.selectionBackground": highlight,
        "menu.selectionForeground": text,
        "menu.separatorBackground": border,
        "menu.border": edge,

        # Activity bar
        # Activity bar: flat keys, the current one held down
        "activityBar.background": surface,
        "activityBar.foreground": text,
        "activityBar.inactiveForeground": muted,
        "activityBar.activeBorder": palette("field-edge"),
        "activityBar.activeBackground": palette("well-pressed"),
        "activityBar.border": edge,
        "activityBarBadge.background": raised,
        "activityBarBadge.foreground": text,
        "activityBarTop.foreground": text,
        "activityBarTop.inactiveForeground": muted,
        "activityBarTop.activeBorder": palette("field-edge"),

        # Side bar
        "sideBar.background": bg,
        "sideBar.foreground": muted,
        "sideBar.border": edge,
        "sideBarTitle.background": surface,
        "sideBarTitle.foreground": muted,
        "sideBarSectionHeader.background": strip,  # caps labels on a strip, like a group box header
        "sideBarSectionHeader.foreground": muted,
        "sideBarSectionHeader.border": palette("row-line"),
        "sideBarStickyScroll.background": bg,
        "sideBarStickyScroll.shadow": alpha("bg-deep", 0.6),

        # Lists and trees
        "list.hoverBackground": hover,
        "list.hoverForeground": text,
        "list.activeSelectionBackground": highlight,
        "list.activeSelectionForeground": text,
        "list.activeSelectionIconForeground": text,
        "list.inactiveSelectionBackground": raised,
        "list.inactiveSelectionForeground": text,
        "list.focusBackground": highlight,
        "list.focusForeground": text,
        "list.focusOutline": "#00000000",
        "list.focusAndSelectionOutline": "#00000000",
        "list.inactiveFocusOutline": "#00000000",
        "list.highlightForeground": accent,
        "list.focusHighlightForeground": palette("accent-hover"),
        "list.dropBackground": hover,
        "list.errorForeground": palette("critical"),
        "list.warningForeground": palette("warning"),
        "list.invalidItemForeground": palette("critical"),
        "list.deemphasizedForeground": faint,
        "tree.indentGuidesStroke": palette("row-line"),
        "tree.inactiveIndentGuidesStroke": palette("row-line"),

        # Editor groups and tabs: folder tabs on the window's `surface`, the current one in the
        # editor's color, joining it
        "editorGroup.border": edge,
        "editorGroup.dropBackground": hover,
        "editorGroupHeader.tabsBackground": surface,
        "editorGroupHeader.tabsBorder": "#00000000",
        "editorGroupHeader.noTabsBackground": surface,
        "editorGroupHeader.border": edge,
        "tab.activeBackground": bg,
        "tab.activeForeground": text,
        "tab.activeBorderTop": "#00000000",
        "tab.activeBorder": bg,
        "tab.unfocusedActiveBorderTop": "#00000000",
        "tab.unfocusedActiveForeground": muted,
        "tab.inactiveBackground": surface,
        "tab.inactiveForeground": muted,
        "tab.unfocusedInactiveForeground": faint,
        "tab.hoverBackground": mix(surface, text, LEVVES["opacity.hover"]),
        "tab.hoverForeground": text,
        "tab.border": edge,
        "tab.lastPinnedBorder": border,
        "tab.activeModifiedBorder": muted,
        "tab.inactiveModifiedBorder": faint,
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
        "editor.findMatchBorder": palette("warning"),
        "editor.findMatchHighlightBackground": alpha("warning", 0.16),
        "editor.findRangeHighlightBackground": alpha("text", 0.04),
        "editor.rangeHighlightBackground": alpha("text", 0.05),
        "editor.hoverHighlightBackground": alpha("info", 0.12),
        "editor.linkedEditingBackground": alpha("info", 0.12),
        "editorLink.activeForeground": palette("info"),
        "editorWhitespace.foreground": alpha("text-faint", 0.5),
        "editorIndentGuide.background1": alpha("border", 0.8),
        "editorIndentGuide.activeBackground1": faint,
        "editorRuler.foreground": alpha("border", 0.8),
        "editorCodeLens.foreground": faint,
        "editorInlayHint.foreground": muted,
        "editorInlayHint.background": alpha("raised", 0.7),
        "editorBracketMatch.background": alpha("text", 0.1),
        "editorBracketMatch.border": alpha("text", 0.3),
        "editorBracketHighlight.foreground1": palette("warning"),
        "editorBracketHighlight.foreground2": palette("terminal.magenta"),
        "editorBracketHighlight.foreground3": palette("info"),
        "editorBracketHighlight.foreground4": palette("terminal.cyan"),
        "editorBracketHighlight.foreground5": palette("success"),
        "editorBracketHighlight.foreground6": mix(palette("critical"), palette("text"), 0.2),
        "editorBracketHighlight.unexpectedBracket.foreground": palette("critical"),
        "editorBracketPairGuide.activeBackground1": alpha("warning", 0.5),
        "editorBracketPairGuide.activeBackground2": alpha(palette("terminal.magenta"), 0.5),
        "editorBracketPairGuide.activeBackground3": alpha("info", 0.5),
        "editorUnnecessaryCode.opacity": "#00000088",
        "editorStickyScroll.background": bg,
        "editorStickyScroll.shadow": alpha("bg-deep", 0.6),
        "editorStickyScrollHover.background": surface,
        "editorOverviewRuler.border": "#00000000",
        "editorOverviewRuler.findMatchForeground": alpha("warning", 0.6),
        "editorOverviewRuler.selectionHighlightForeground": alpha("info", 0.5),
        "editorOverviewRuler.errorForeground": palette("critical"),
        "editorOverviewRuler.warningForeground": palette("warning"),
        "editorOverviewRuler.infoForeground": palette("info"),
        "editorOverviewRuler.addedForeground": alpha("success", 0.6),
        "editorOverviewRuler.modifiedForeground": alpha("info", 0.6),
        "editorOverviewRuler.deletedForeground": alpha("critical", 0.6),
        "editorError.foreground": palette("critical"),
        "editorWarning.foreground": palette("warning"),
        "editorInfo.foreground": palette("info"),
        "editorHint.foreground": muted,
        "problemsErrorIcon.foreground": palette("critical"),
        "problemsWarningIcon.foreground": palette("warning"),
        "problemsInfoIcon.foreground": palette("info"),
        "editorGutter.background": bg,
        "editorGutter.addedBackground": palette("success"),
        "editorGutter.modifiedBackground": palette("info"),
        "editorGutter.deletedBackground": palette("critical"),
        "editorGutter.foldingControlForeground": faint,

        # Editor widgets (find, suggest, hover, peek): popups are surface
        "editorWidget.background": surface,
        "editorWidget.foreground": text,
        "editorWidget.border": edge,
        "editorWidget.resizeBorder": muted,
        "editorSuggestWidget.background": surface,
        "editorSuggestWidget.border": edge,
        "editorSuggestWidget.foreground": text,
        "editorSuggestWidget.selectedBackground": highlight,
        "editorSuggestWidget.selectedForeground": text,
        "editorSuggestWidget.highlightForeground": accent,
        "editorSuggestWidget.focusHighlightForeground": palette("accent-hover"),
        "editorHoverWidget.background": surface,
        "editorHoverWidget.border": edge,
        "editorHoverWidget.statusBarBackground": strip,
        "editorGhostText.foreground": faint,
        "peekView.border": edge,
        "peekViewTitle.background": palette("title-bar"),
        "peekViewTitleLabel.foreground": text,
        "peekViewTitleDescription.foreground": muted,
        "peekViewEditor.background": well,
        "peekViewEditorGutter.background": well,
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
        # Fields in wells, buttons as keys
        "input.background": well,
        "input.foreground": text,
        "input.border": palette("field-edge"),
        "input.placeholderForeground": faint,
        "inputOption.activeBackground": highlight,
        "inputOption.activeBorder": "#00000000",
        "inputOption.activeForeground": text,
        "inputOption.hoverBackground": hover,
        "inputValidation.errorBackground": surface,
        "inputValidation.errorBorder": palette("critical"),
        "inputValidation.warningBackground": surface,
        "inputValidation.warningBorder": palette("warning"),
        "inputValidation.infoBackground": surface,
        "inputValidation.infoBorder": palette("info"),
        "dropdown.background": well,
        "dropdown.listBackground": surface,
        "dropdown.border": palette("field-edge"),
        "dropdown.foreground": text,
        "checkbox.background": well,
        "checkbox.border": palette("field-edge"),
        "checkbox.foreground": text,
        "checkbox.selectBackground": surface,
        "button.background": accent,
        "button.foreground": on_accent,
        "button.hoverBackground": palette("accent-hover"),
        "button.border": palette("key-edge"),
        "button.separator": alpha("on-accent", 0.3),
        "button.secondaryBackground": raised,
        "button.secondaryForeground": text,
        "button.secondaryHoverBackground": mix(raised, text, LEVVES["opacity.hover"]),
        "badge.background": raised,
        "badge.foreground": text,
        "scrollbar.shadow": alpha("bg-deep", 0.5),
        "scrollbarSlider.background": alpha("text", 0.1),
        "scrollbarSlider.hoverBackground": alpha("text", 0.16),
        "scrollbarSlider.activeBackground": alpha("text", 0.22),
        "keybindingLabel.background": raised,
        "keybindingLabel.foreground": text,
        "keybindingLabel.border": palette("key-edge"),
        "keybindingLabel.bottomBorder": palette("key-depth"),

        # Quick input (command palette)
        "quickInput.background": surface,
        "quickInput.foreground": text,
        "quickInputTitle.background": surface,
        "quickInputList.focusBackground": highlight,
        "quickInputList.focusForeground": text,
        "quickInputList.focusIconForeground": text,
        "pickerGroup.foreground": muted,
        "pickerGroup.border": palette("row-line"),

        # Panel and terminal
        "panel.background": bg,
        "panel.border": edge,
        "panelTitle.activeForeground": text,
        "panelTitle.activeBorder": muted,
        "panelTitle.inactiveForeground": muted,
        "panelSection.border": edge,
        "panelSectionHeader.background": strip,
        "panelInput.border": palette("field-edge"),
        "outputView.background": bg,
        "terminal.background": bg,
        "terminal.foreground": text,
        "terminal.border": edge,
        "terminal.selectionBackground": selection,
        "terminalCursor.foreground": accent,
        "terminalCursor.background": on_accent,
        "terminal.findMatchBackground": alpha("warning", 0.35),
        "terminal.findMatchHighlightBackground": alpha("warning", 0.16),
        "terminalCommandDecoration.defaultBackground": faint,
        "terminalCommandDecoration.successBackground": palette("success"),
        "terminalCommandDecoration.errorBackground": palette("critical"),
        "terminalOverviewRuler.cursorForeground": accent,

        # Status bar: a strip
        "statusBar.background": strip,
        "statusBar.foreground": muted,
        "statusBar.border": edge,
        "statusBar.focusBorder": accent,
        "statusBar.noFolderBackground": strip,
        "statusBar.noFolderForeground": muted,
        "statusBar.debuggingBackground": palette("accent-pressed"),
        "statusBar.debuggingForeground": on_accent,
        "statusBar.debuggingBorder": palette("accent-pressed"),
        "statusBarItem.hoverBackground": hover,
        "statusBarItem.hoverForeground": text,
        "statusBarItem.activeBackground": alpha("text", 0.1),
        "statusBarItem.remoteBackground": raised,
        "statusBarItem.remoteForeground": text,
        "statusBarItem.prominentBackground": raised,
        "statusBarItem.prominentHoverBackground": mix(raised, text, 0.08),
        "statusBarItem.errorBackground": palette("critical"),
        "statusBarItem.errorForeground": on_accent,
        "statusBarItem.warningBackground": palette("warning"),
        "statusBarItem.warningForeground": on_accent,
        "statusBarItem.focusBorder": accent,

        # Notifications
        "notifications.background": surface,
        "notifications.foreground": text,
        "notifications.border": border,
        "notificationCenterHeader.background": palette("title-bar"),
        "notificationCenter.border": edge,
        "notificationToast.border": edge,
        "notificationLink.foreground": palette("info"),
        "notificationsErrorIcon.foreground": palette("critical"),
        "notificationsWarningIcon.foreground": palette("warning"),
        "notificationsInfoIcon.foreground": palette("info"),

        # Git and SCM decorations
        "gitDecoration.addedResourceForeground": palette("success"),
        "gitDecoration.untrackedResourceForeground": palette("success"),
        "gitDecoration.modifiedResourceForeground": palette("info"),
        "gitDecoration.deletedResourceForeground": palette("critical"),
        "gitDecoration.renamedResourceForeground": palette("terminal.cyan"),
        "gitDecoration.conflictingResourceForeground": palette("warning"),
        "gitDecoration.ignoredResourceForeground": faint,
        "gitDecoration.submoduleResourceForeground": palette("terminal.magenta"),
        "gitDecoration.stageModifiedResourceForeground": palette("info"),
        "gitDecoration.stageDeletedResourceForeground": palette("critical"),
        "scmGraph.historyItemRefColor": palette("info"),
        "scmGraph.historyItemRemoteRefColor": palette("terminal.magenta"),
        "scmGraph.historyItemBaseRefColor": palette("warning"),
        "scmGraph.historyItemHoverDefaultLabelForeground": text,

        # Misc
        "welcomePage.tileBackground": surface,
        "welcomePage.tileHoverBackground": raised,
        "welcomePage.tileBorder": border,
        "walkThrough.embeddedEditorBackground": well,
        "settings.headerForeground": text,
        "settings.modifiedItemIndicator": accent,
        "settings.focusedRowBackground": alpha("text", 0.03),
        "settings.rowHoverBackground": alpha("text", 0.03),
        "settings.dropdownBackground": well,
        "settings.textInputBackground": well,
        "settings.numberInputBackground": well,
        "settings.checkboxBackground": well,
        "debugToolBar.background": surface,
        "debugToolBar.border": edge,
        "debugIcon.breakpointForeground": palette("critical"),
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
        "inlineChat.border": edge,
        "charts.foreground": text,
        "charts.lines": border,
        "charts.red": palette("critical"),
        "charts.yellow": palette("warning"),
        "charts.orange": accent,
        "charts.green": palette("success"),
        "charts.blue": palette("info"),
        "charts.purple": palette("terminal.magenta"),
    }

    # Terminal ANSI, as in the Konsole scheme (yakuake/build.py): bright is 25% toward white
    ansi = {"Black": palette("terminal.black"), "Red": palette("critical"), "Green": palette("success"),
            "Yellow": palette("warning"), "Blue": palette("info"), "Magenta": palette("terminal.magenta"),
            "Cyan": palette("terminal.cyan"), "White": palette("text")}
    for name, color in ansi.items():
        c[f"terminal.ansi{name}"] = color
        c[f"terminal.ansiBright{name}"] = palette("terminal.bright-black") if name == "Black" else mix(color, "#ffffff", 0.25)
    return c


def theme():
    return {
        "name": "Levves",
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
        "displayName": "Levves",
        "description": "Levves, direction D: dark, cool, one amber accent",
        "publisher": PUBLISHER,
        "version": VERSION,
        "engines": {"vscode": "^1.70.0"},
        "categories": ["Themes"],
        "contributes": {"themes": [{"label": "Levves", "uiTheme": "vs-dark", "path": f"./{THEME_FILE}"}]},
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
<DisplayName>Levves</DisplayName>
<Description xml:space="preserve">Levves, direction D: dark, cool, one amber accent</Description>
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
    listed = subprocess.run(["code", "--list-extensions"], capture_output=True, text=True).stdout.split()
    if OLD in listed:
        subprocess.run(["code", "--uninstall-extension", OLD], check=True, capture_output=True)
    # settings.json allows comments, so only the one value is swapped, as text
    if SETTINGS.exists():
        text = SETTINGS.read_text()
        swapped = re.sub(r'("workbench\.colorTheme"\s*:\s*)"Leaves"', r'\1"Levves"', text)
        if swapped != text:
            SETTINGS.write_text(swapped)
    print("changed")


if __name__ == "__main__":
    shutil.which("code") or exit("code not found")
    main()
