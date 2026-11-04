"""Tests for build.py. Run: python3 -m unittest discover -s design/build"""
import json
import tempfile
import unittest
from pathlib import Path

import build


def tokens_from(tree):
    return build.resolve(build.flatten(tree))


class Flatten(unittest.TestCase):
    def test_type_is_inherited_from_the_nearest_group(self):
        tokens = tokens_from({"color": {"$type": "color", "bg": {"$value": "#000000"}}})
        self.assertEqual(tokens[("color", "bg")]["type"], "color")

    def test_a_token_without_a_type_is_an_error(self):
        with self.assertRaises(build.TokenError):
            build.flatten({"x": {"y": {"$value": 1}}})


class Resolve(unittest.TestCase):
    def test_references_follow_chains(self):
        tokens = tokens_from({"color": {"$type": "color", "a": {"$value": "#111111"},
                                        "b": {"$value": "{color.a}"}, "c": {"$value": "{color.b}"}}})
        self.assertEqual(tokens[("color", "c")]["value"], "#111111")

    def test_a_missing_reference_is_an_error(self):
        with self.assertRaises(build.TokenError):
            tokens_from({"color": {"$type": "color", "a": {"$value": "{color.nope}"}}})

    def test_a_cycle_is_an_error(self):
        with self.assertRaises(build.TokenError):
            tokens_from({"color": {"$type": "color", "a": {"$value": "{color.b}"}, "b": {"$value": "{color.a}"}}})

    def test_a_reference_to_another_type_is_an_error(self):
        with self.assertRaises(build.TokenError):
            tokens_from({"color": {"$type": "color", "a": {"$value": "{space.4}"}},
                         "space": {"$type": "dimension", "4": {"$value": "4px"}}})


class Load(unittest.TestCase):
    def test_a_group_defined_in_two_files_is_an_error(self):
        with tempfile.TemporaryDirectory() as d:
            for name in ("a.json", "b.json"):
                Path(d, name).write_text(json.dumps({"size": {"$type": "dimension", name: {"$value": "1px"}}}))
            with self.assertRaises(build.TokenError):
                build.load(Path(d))


class Names(unittest.TestCase):
    def test_colors_drop_their_group_in_code(self):
        self.assertEqual(build.camel(("color", "text-muted")), "textMuted")
        self.assertEqual(build.camel(("color", "terminal", "bright-black")), "terminalBrightBlack")

    def test_qml_never_gets_a_signal_handler_name(self):
        self.assertEqual(build.qml_name(("color", "on-accent")), "textOnAccent")
        with self.assertRaises(build.TokenError):
            build.qml_name(("color", "on-surface"))

    def test_other_tokens_keep_their_group(self):
        self.assertEqual(build.camel(("space", "4")), "space4")
        self.assertEqual(build.camel(("duration", "popup-open")), "durationPopupOpen")


class RealTokens(unittest.TestCase):
    """The repo's own tokens: they build, and the code names don't collide."""

    def setUp(self):
        self.tokens = tokens_from(build.load())

    def test_code_names_are_unique(self):
        names = [build.camel(p) for p in self.tokens]
        self.assertEqual(len(names), len(set(names)))

    def test_python_color_helper(self):
        namespace = {}
        exec(build.python(self.tokens), namespace)
        self.assertEqual(namespace["color"]("accent"), namespace["TOKENS"]["color.accent"])
        self.assertEqual(namespace["color"]("terminal.cyan"), namespace["TOKENS"]["color.terminal.cyan"])

    def test_theme_has_the_tints(self):
        theme = build.qml(self.tokens)
        for name, _, _ in build.TINTS:
            self.assertRegex(theme, rf'readonly property color {name}: "#[0-9a-f]{{8}}"')

    def test_qml_module_lists_every_piece(self):
        with tempfile.TemporaryDirectory() as folder:
            (Path(folder) / "Key.qml").write_text("import QtQuick\nItem {}\n")
            files = build.qml_module(self.tokens, pieces=Path(folder))
        self.assertIn("Key 1.0 Key.qml", files["qml/Levves/qmldir"].splitlines())
        self.assertTrue(files["qml/Levves/Key.qml"].startswith("// Copied from design/qml/Key.qml"))
        self.assertIn("qml/Levves/dither-strip.svg", files)

    def test_dist_is_up_to_date(self):
        self.assertEqual(build.main(["--check"]), 0, "run python3 design/build/build.py")


class Hardcoded(unittest.TestCase):
    def scan(self, text, path="os/linux/x.qml"):
        import check_hardcoded
        return check_hardcoded.scan([path], ["e9a23b"], read=lambda f: text)

    def test_finds_hex_in_every_spelling(self):
        for text in ['color: "#e9a23b"', "Color(0xFFE9A23B)", "ON = 'e9a23b'", "--accent: #E9A23B;"]:
            self.assertTrue(self.scan(text), text)

    def test_ignores_other_colors_and_longer_hex(self):
        for text in ['color: "#e9a23c"', "#e9a23b80aa", "sha e9a23b1234"]:
            self.assertFalse(self.scan(text), text)

    def test_skips_the_design_folder(self):
        self.assertFalse(self.scan('"#e9a23b"', path="design/dist/tokens.css"))


if __name__ == "__main__":
    unittest.main()
