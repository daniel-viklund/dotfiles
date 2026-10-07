vim.pack.add({
  "https://github.com/saghen/blink.lib",
  "https://github.com/saghen/blink.cmp",
})

local cmp = require("blink.cmp")

-- Share the Rust development toolchain; Windows uses GCC instead of MSVC.
local previous_toolchain = vim.env.RUSTUP_TOOLCHAIN
vim.env.RUSTUP_TOOLCHAIN = vim.fn.has("win32") == 1 and "stable-x86_64-pc-windows-gnu" or "stable"
local ok, err = cmp.build():pwait(600000)
vim.env.RUSTUP_TOOLCHAIN = previous_toolchain
assert(ok, err)

cmp.setup({ fuzzy = { implementation = "rust" } })
