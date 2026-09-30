"""Re-exports js_library from aspect_rules_js.

Generated BUILD files load this label instead of the upstream one, so an
upstream label change only requires updating this file.
"""

load("@aspect_rules_js//js:defs.bzl", _js_library = "js_library")

js_library = _js_library
