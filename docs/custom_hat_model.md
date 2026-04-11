## Jak dodać customowy model czapki (Blender → SMD → studiomdl → hats)

### 1) Przygotowanie w Blenderze (statyczny prop, bez armatury)
- Zaznacz **mesh** (bez armatury).
- Object Mode: `Alt+P` → Clear and Keep Transform (odłącz od armatury), usuń modyfikator Armature.
- Object Data → Vertex Groups: usuń wszystkie grupy.
- Materiał: jeden slot, nazwa **dd_c** (pasuje do VMT `dd_c.vmt`).
- Apply (Ctrl+A): Location, Rotation, Scale.
- Pivot/origin w (0,0,0): 3D Cursor na (0,0,0) → Object → Set Origin → Origin to 3D Cursor.
- Triangulacja: modyfikator Triangulate → Apply (lub triangulate w eksporcie).
- Jeśli model jest za mały/duży – skaluj w Blenderze (np. x100) przed Apply.

### 2) Eksport SMD (Blender Source Tools)
- Export Format: **SMD**.
- Type: **Static Prop** (bez armatury).
- Up Axis: **Z**.
- Export selected only: ON, Apply Modifiers: ON, Scale: 1.0.
- Ścieżka: `materials/models/hats/dildo/dd.smd` (lub inna docelowa).

### 3) Kompilacja QC (studiomdl)
Przykład QC (dostosuj `modelname` i nazwę SMD):
```
$modelname "models/hats/dildo_box/dildo_box.mdl"
$body "Body" "dd.smd"
$scale 1
$surfaceprop "rubber"
$staticprop
$sequence idle "dd.smd" fps 1
$cdmaterials "models/hats/dildo/"
```
Kompilacja (PowerShell):
```
& "B:\Program Files (x86)\Steam\steamapps\common\Left 4 Dead 2\bin\studiomdl.exe" `
   -game "B:\Program Files (x86)\Steam\steamapps\common\Left 4 Dead 2\left4dead2" `
   "B:\gitlab-github\Kether.pl-L4D2-Server\materials\models\hats\dildo\compile_dildo_box.qc"
```
Wynik kopiuje się do `left4dead2/models/...`; usuń ewentualny duplikat `models/models/...`, zostaw tylko `models/hats/<twoja_sciezka>/`.

### 4) Pliki do fastDL/serwera
- `models/hats/<twoja_sciezka>/<model>.mdl`
- `models/hats/<twoja_sciezka>/<model>.vvd`
- `models/hats/<twoja_sciezka>/<model>.dx90.vtx`
- Materiały: `materials/models/hats/dildo/dd_c.vmt`, `dd_diffuse.vtf`, `dd_normal.vtf` (i inne VMT/VTF jeśli używasz).

### 5) Hats + precache
- `addons/sourcemod/data/l4d_hats.cfg` → `"mod" "models/hats/<twoja_sciezka>/<model>.mdl"` plus `loc/ang/size`.
- `addons/sourcemod/translations/hatnames.phrases.txt` → dodaj ścieżkę, nazwa dla menu.
- `addons/sourcemod/scripting/l4d2_preload.sp` → PrecacheModel + AddFileToDownloadsTable dla mdl/vvd/vtx oraz VMT/VTF (przekompiluj do `plugins/l4d2_preload.smx`).

### 6) Czyszczenie cache przy testach
- Lokalnie usuń `left4dead2/downloads/models/...` jeśli zmieniasz ścieżkę/model (żeby nie ładował starego checksum).
- Po zmianach `changelevel` / restart serwera i klienta.

### 7) Debug
- `prop_dynamic_create models/hats/<twoja_sciezka>/<model>.mdl` (developer 1 pokazuje brakujące pliki).
- Unikaj podwójnego `models/models/...` w QC (używaj `models/...` w `$modelname`, resztę studiomdl doda sam).
