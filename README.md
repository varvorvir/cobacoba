# Fast Hub (clean)

- No key, GUI muncul langsung saat load
- Tema hangat, minimalis
- 3 tombol: Start CP / Stop / Start To End
- Arsitektur **route plugin** (bisa ganti-ganti map)

## Eksekusi (executor)
```lua
-- opsional: pilih route dulu (default: "mainmap72")
-- _G.ROUTE = "mainmap72"
loadstring(game:HttpGet("https://raw.githubusercontent.com/varvorvir/cobacoba/main/Loader.lua"))()
```

## Struktur repo
```
Loader.lua
main.lua
routes/
  ├── mainmap72.lua   # route bawaan (copied from your old file)
  └── example.lua     # template module
```

## Menambah route baru
Buat file `routes/<nama>.lua` yang **return table**:
```lua
local M = {}
function M.start_cp() end
function M.stop() end
function M.start_to_end() end
return M
```

Pilih route:
- Sebelum load: `_G.ROUTE = "<nama>"`
- Saat jalan: `_G.FastHub_SetRoute("<nama>")`
```
