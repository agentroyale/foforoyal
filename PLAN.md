# Phase 9: World Generation — Plano de Implementacao

## Resumo

16 arquivos novos, 7 GUT tests, 2 autoloads novos.
Mapa 4096x4096, chunks 256x256 (grid 16x16 = 256 chunks), LOD 3 niveis.

## Arquitetura

```
WorldGenerator (Node, Autoload)
  |-- TerrainGenerator       (gera heightmap + mesh por chunk)
  |-- BiomeMap               (temperature + moisture -> biome type)
  |-- ResourceSpawner        (spawn resource nodes por biome)
  |-- MonumentSpawner        (spawn estruturas pre-built)
  |-- WaterSystem            (rios + lagos)

ChunkManager (Node, Autoload)
  |-- Chunk lifecycle (load/unload por distancia)
  |-- LOD system (3 niveis: 0-256m full, 256-512m half, 512-1024m quarter)
```

## Arquivos a Criar

### Scripts (8) — `godot/scripts/world/`

| # | Arquivo | Base | Descricao |
|---|---------|------|-----------|
| 1 | `biome_data.gd` | Resource | BiomeType enum (GRASSLAND/FOREST/DESERT/ARCTIC), `get_biome_from_climate(temp, moisture)` static |
| 2 | `chunk_data.gd` | RefCounted | Container: heightmap (17x17), biome_grid (16x16), resource/monument positions, lod_level |
| 3 | `terrain_generator.gd` | RefCounted | ALL STATIC: `generate_heightmap()`, `build_terrain_mesh()`, `build_collision_shape()` |
| 4 | `water_system.gd` | RefCounted | ALL STATIC: `get_water_level()`, `is_underwater()`, `generate_river_path()`, `get_lake_positions()` |
| 5 | `resource_spawner.gd` | RefCounted | ALL STATIC: `generate_spawn_points()` deterministico por seed+biome |
| 6 | `monument_spawner.gd` | RefCounted | ALL STATIC: 8 monuments, min 512m apart, MonumentType enum |
| 7 | `world_generator.gd` | Node | Autoload, orquestra tudo, 3 FastNoiseLite (height/temp/moisture), `initialize(seed)` |
| 8 | `chunk_manager.gd` | Node | Autoload, load/unload chunks, LOD transitions, `update_chunks(player_pos)` |

### Shaders (2) — `godot/shaders/`

| # | Arquivo | Descricao |
|---|---------|-----------|
| 9 | `terrain.gdshader` | Biome color via vertex color, slope-based rock blending, noise detail. GL Compatibility |
| 10 | `water.gdshader` | Wave animation (sin), transparency, specular. GL Compatibility |

### Resources (4) — `godot/resources/biomes/`

| # | Arquivo | tree | rock | metal | sulfur |
|---|---------|------|------|-------|--------|
| 11 | `grassland.tres` | 0.3 | 0.2 | 0.05 | 0.03 |
| 12 | `forest.tres` | 0.6 | 0.15 | 0.08 | 0.02 |
| 13 | `desert.tres` | 0.05 | 0.35 | 0.1 | 0.08 |
| 14 | `arctic.tres` | 0.1 | 0.25 | 0.12 | 0.05 |

### Scenes (1) — `godot/scenes/world/`

| # | Arquivo | Descricao |
|---|---------|-----------|
| 15 | `water_plane.tscn` | MeshInstance3D + PlaneMesh 256x256 + water shader material |

### Tests (1) — `godot/tests/unit/`

| # | Arquivo | Tests |
|---|---------|-------|
| 16 | `test_world_generation.gd` | 7 tests (abaixo) |

## Os 7 GUT Tests

1. **`test_seed_determinism`** — Mesmo seed = mesma heightmap. Seed diferente = heightmap diferente
2. **`test_biome_classification`** — temp+moisture mapeia pra biome correto (arctic=frio, desert=quente+seco, forest=umido, grassland=moderado)
3. **`test_chunk_coordinate_mapping`** — world position → chunk grid coordinate (0,0 a 15,15), clamp nas bordas
4. **`test_resource_spawn_density_per_biome`** — Forest tem mais trees que desert; desert tem mais rocks que forest
5. **`test_lod_distance_thresholds`** — LOD 0 ate 256m, LOD 1 ate 512m, LOD 2 ate 1024m, -1 alem
6. **`test_monument_minimum_distance`** — 8 monuments, todos >= 512m de distancia entre si
7. **`test_water_level_detection`** — Terreno abaixo de 5.0 = underwater, acima = seco

## Ordem de Implementacao

### Step 1: Data Layer (sem dependencias)
- `biome_data.gd`
- `chunk_data.gd`

### Step 2: Core Generation (depende de Step 1)
- `terrain_generator.gd`
- `water_system.gd`

### Step 3: Spawners (depende de Steps 1-2)
- `resource_spawner.gd`
- `monument_spawner.gd`

### Step 4: Orchestration (depende de Steps 1-3)
- `world_generator.gd`
- `chunk_manager.gd`

### Step 5: Visuals (paralelo ao Step 4)
- `terrain.gdshader`
- `water.gdshader`
- `water_plane.tscn`

### Step 6: Resources
- 4 .tres biome files

### Step 7: Tests e Integracao
- `test_world_generation.gd`
- Registrar autoloads no `project.godot`

## Integracao com Sistemas Existentes

### ChunkStreamer (Phase 8)
- ChunkManager usa mesma constante STREAM_RADIUS=256 pra LOD 0
- ResourceNodes ja estao no group "network_synced", ChunkStreamer encontra automaticamente

### ResourceNode (Phase 4)
- Reusa cenas existentes (tree_node.tscn, rock_node.tscn, etc.) sem modificacao
- ResourceSpawner so determina posicoes, instancia a cena correta

### Multiplayer (Phase 8)
- Server define world_seed, envia pros clients
- Geracao e deterministica: mesmo seed = mesmo mundo (clients geram localmente)
- So estado de resource nodes (depleted/alive) precisa de sync

### Autoloads novos no project.godot
```
WorldGenerator="*res://scripts/world/world_generator.gd"
ChunkManager="*res://scripts/world/chunk_manager.gd"
```

## Decisoes Arquiteturais

1. **Static methods** pra TerrainGenerator, ResourceSpawner, MonumentSpawner, WaterSystem (consistente com ChunkStreamer, ServerValidation)
2. **Geracao deterministica** por seed — multiplayer nao precisa transferir dados massivos
3. **Heightmap 17x17 por chunk** (1 vertex a cada 16m) — performance excelente, detalhes via shader
4. **3 niveis LOD fixos** ao inves de continuous — simples de implementar e debugar
5. **Biome como grid discreto** (byte per 16x16 cell) — simplifica spawn logic, shader faz blending visual
6. **GL Compatibility shaders** — sem features Vulkan-only (projeto usa gl_compatibility)

## Contagem Final
- 7 novos GUT tests → total: 65 GUT + 3 Foundry = **68 tests**
