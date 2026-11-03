"""Copy to ~/.keyhac/local.py (outside Git); loaded again on config reload.

PLATFORM is supplied by config.py: "mac" or "windows".
Known names below select the corresponding app on either platform.
"""

APPS = {
    "H": "Bitwarden",
    "J": "Firefox",
    "K": "WezTerm",
    "L": "Discord",
    "R": "Davinci Resolve",
}

# Set a value to False to disable a launcher (the unbound-key alert remains).
# For another app, use its name on macOS, or an explicit target on Windows:
# if PLATFORM == "windows":
#     APPS["B"] = {"app": "brave", "launch": r"C:\path\to\brave.exe"}
