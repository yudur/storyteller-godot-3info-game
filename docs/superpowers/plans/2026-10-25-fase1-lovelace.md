# Fase 1 "As notas de Lovelace" Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tornar a fase "As notas de Lovelace" jogável: personagens/cenários puros arrastados para 4 quadros, poses e fundos escolhidos pelo contexto, dúvida em quadros incoerentes, sons e sequência de desfecho.

**Architecture:** Dados de assets em Resources (`poses`/`variants` como dicionários). Regras numa classe pura `LovelaceLogic` (`RefCounted`) referenciada por `StoryData.logic`, testada headless. `GameScreen` orquestra o tabuleiro: coleta `FrameContent` de cada `ComicFrame`, chama `evaluate`, aplica `FrameResult`, toca sons e dispara o desfecho.

**Tech Stack:** Godot 4.5, GDScript, GL Compatibility. Testes: scripts `extends SceneTree` rodados com `godot --headless`.

**Spec:** `docs/superpowers/specs/2026-10-25-fase1-lovelace-design.md`

## Global Constraints

- Godot 4.5; estilo do código existente: tabs, tipagem estática (`:=`, `-> void`), `class_name` em scripts reutilizáveis, `@onready` para nós.
- Pose/variante `"default"` é obrigatória em todo `CharacterData`/`SceneData`; chave ausente cai para `"default"`; se nem ela existir → textura `null` + `push_warning`.
- Ids: personagens `ada`, `charles`, `teapot`; cenários `office`, `kitchen`. Momentos: `"M1"`, `"M2"`, `"M3"`, `"M4"`.
- Poses: Ada `default, pen, pen_articles, pile, doubt, laughing`; Charles `default, clipboard, cup, scared_cup, laughing`; Bule `default`. Variantes: office `default, open_door, papers`; kitchen `default`.
- Lado (esquerda/direita) não importa para casar momento.
- Sons tocam só quando `(state, moment)` de um quadro muda.
- Texto de UI em português: "As notas de Lovelace", "Fase concluída", "Voltar ao menu", "?".
- Comando de teste (substituir `$GODOT` pelo executável do Godot 4.5 da máquina):
  `"$GODOT" --headless --path . --import` (uma vez após criar novas `class_name`/assets) e
  `"$GODOT" --headless --path . --script res://tests/<arquivo>.gd`. Saída esperada em sucesso: linha `ALL PASSED` e exit code 0.
- Não commitar as alterações pré-existentes do editor em `src/comic_frame/comic_frame.tscn` e `src/screen_manager/screen_manager.tscn` separadamente — elas entram junto com as tarefas que editam esses arquivos (são só uids/layout re-salvos pelo editor).

## Review Focus

1. Soltar de novo o mesmo item / reavaliar sem mudança → nenhum som repetido (pinado em Task 2: `FrameResult.same_outcome`).
2. Arrastar um personagem para fora de um quadro coerente → o quadro e os seguintes voltam a neutro/default (pinado em Task 2: caso "remoção cascateia").
3. Soltar um cenário num quadro que já tem personagens → reavalia com o novo cenário (Task 3, verificação manual passo 6).
4. Voltar ao menu durante o desfecho e reentrar → tabuleiro limpo, painel oculto, nenhum tween/timer pendente aplicando poses (Task 5, verificação manual).
5. Mesmo personagem nos dois lados → Dúvida, nunca momento (pinado em Task 2).

---

### Task 1: Esquema de Resources e dados da fase

**Files:**
- Modify: `core/resources/character_data.gd`, `core/resources/scene_data.gd`, `core/resources/story_data.gd`
- Delete: `core/resources/CorrectAnswerRow.gd`, `core/resources/correct_answer_data.gd` (+ `.uid`)
- Create: `assets/sprites/characters/teapot_placeholder.png` (PNG 512×512, bule simples ou retângulo com texto "Bule"; gerar com qualquer ferramenta, ex. script Python/PIL ou `Image` do Godot)
- Create: `data/characters/ada.tres`, `data/characters/charles.tres`, `data/characters/teapot.tres`, `data/scenes/office.tres`, `data/scenes/kitchen.tres`
- Modify: `src/comic_frame/comic_frame.gd` (uso mínimo dos novos campos para continuar compilando)
- Test: `tests/test_phase_data.gd`, `tests/test_utils.gd`

**Interfaces:**
- Produces:
  - `CharacterData`: `id: String`, `display_name: String`, `poses: Dictionary[String, Texture2D]`, `func get_pose(key: String) -> Texture2D` (fallback `default`, `push_warning` se nenhum).
  - `SceneData`: `id`, `display_name`, `variants: Dictionary[String, Texture2D]`, `func get_variant(key: String) -> Texture2D` (mesmo fallback).
  - `StoryData`: `id`, `title`, `number_of_frames: int`, `draggable_items: Array[Resource]`, `logic: Script`.
  - `TestUtils` (`tests/test_utils.gd`, `class_name TestUtils extends RefCounted`): `check(cond: bool, msg: String)`, `eq(a, b, msg: String)`, `finish(tree: SceneTree)` — imprime falhas, imprime `ALL PASSED` se nenhuma e chama `tree.quit(0|1)`.

- [ ] **Step 1: Escrever `tests/test_utils.gd` e `tests/test_phase_data.gd`**

`test_phase_data.gd` (`extends SceneTree`, lógica em `_initialize()`), asserções:
```gdscript
var ada: CharacterData = load("res://data/characters/ada.tres")
for k in ["default", "pen", "pen_articles", "pile", "doubt", "laughing"]:
	t.check(ada.poses.get(k) is Texture2D, "ada pose %s" % k)
var charles: CharacterData = load("res://data/characters/charles.tres")
for k in ["default", "clipboard", "cup", "scared_cup", "laughing"]:
	t.check(charles.poses.get(k) is Texture2D, "charles pose %s" % k)
t.check(load("res://data/characters/teapot.tres").poses.get("default") is Texture2D, "teapot default")
var office: SceneData = load("res://data/scenes/office.tres")
for k in ["default", "open_door", "papers"]:
	t.check(office.variants.get(k) is Texture2D, "office %s" % k)
t.check(load("res://data/scenes/kitchen.tres").variants.get("default") is Texture2D, "kitchen default")
t.eq(ada.get_pose("nao_existe"), ada.poses["default"], "fallback para default")
t.eq([ada.id, charles.id, office.id], ["ada", "charles", "office"], "ids")
```

- [ ] **Step 2: Rodar e ver falhar** — `"$GODOT" --headless --path . --script res://tests/test_phase_data.gd` → falha (recursos inexistentes).

- [ ] **Step 3: Implementar** — atualizar os três scripts de Resource; remover CorrectAnswer*; gerar a PNG do bule; criar os `.tres` com o mapa de arquivos da tabela "Dados da fase" da spec (`display_name`: "Ada Lovelace", "Charles Babbage", "Bule de chá", "Escritório", "Cozinha"). Em `comic_frame.gd`, trocar `scene.background` → `scene.get_variant("default")` e `character.sprite_normal` → `character.get_pose("default")` (o resto da reestruturação é Task 3). Rodar `--import` antes do teste.

- [ ] **Step 4: Rodar e ver passar** — mesmo comando → `ALL PASSED`.

- [ ] **Step 5: Commit**
```bash
git add core/resources tests assets/sprites/characters assets/sprites/scenes data/characters/ada.tres data/characters/charles.tres data/characters/teapot.tres data/scenes/office.tres data/scenes/kitchen.tres src/comic_frame/comic_frame.gd
git commit -m "feat: pose/variant dictionaries and phase 1 data resources"
```
(Inclui os sprites de personagens/cenários ainda não rastreados e seus `.import`.)

---

### Task 2: Lógica pura da fase (`LovelaceLogic`)

**Files:**
- Create: `core/story_logic/frame_content.gd`, `frame_result.gd`, `ending_data.gd`, `story_logic.gd`, `lovelace_logic.gd`
- Test: `tests/test_lovelace_logic.gd`

**Interfaces:**
- Consumes: `CharacterData`, `SceneData` (Task 1), `TestUtils`.
- Produces:
  - `class_name FrameContent extends RefCounted`: `scene: SceneData`, `left: CharacterData`, `right: CharacterData`; `func _init(scene: SceneData = null, left: CharacterData = null, right: CharacterData = null)`; `is_empty() -> bool`; `character_count() -> int`; `has_character(id: String) -> bool`.
  - `class_name FrameResult extends RefCounted`: `enum State { NEUTRAL, COHERENT, DOUBT }`; `state: State`, `moment: String`, `scene_variant: String`, `left_pose: String`, `right_pose: String`, `sounds: Array[AudioStream]`, `show_doubt_icon: bool` (= `state == DOUBT`); `func same_outcome(other: FrameResult) -> bool` (compara `state` e `moment`; `other == null` → false).
  - `class_name EndingData extends RefCounted`: `frame_index: int`, `scene_variant: String`, `left_pose: String`, `right_pose: String`, `sounds: Array[AudioStream]`.
  - `class_name StoryLogic extends RefCounted`: `evaluate(board: Array[FrameContent]) -> Array[FrameResult]`; `is_solved(board: Array[FrameContent]) -> bool`; `ending(board: Array[FrameContent]) -> EndingData`. Base: tudo NEUTRAL / false / null.
  - `class_name LovelaceLogic extends StoryLogic`.

- [ ] **Step 1: Escrever `tests/test_lovelace_logic.gd`**

Helpers locais: `office()`, `kitchen()`, `ada()`, `charles()`, `teapot()` carregando os `.tres`; `fc(scene, l, r) -> FrameContent`; `solution() -> Array[FrameContent]` = `[fc(office,ada,charles), fc(office,ada,charles), fc(kitchen,charles,teapot), fc(office,ada,charles)]`. Casos (cada um com `t.eq`/`t.check`):

1. Solução: momentos `["M1","M2","M3","M4"]`, todos `COHERENT`, `is_solved == true`.
2. Fundos/poses: M1 `default`/ada `pen`/charles `clipboard`; M2 `open_door`/`pen_articles`/`default`; M3 `default`/charles `cup`/teapot `default`; M4 `papers`/ada `pile`/charles `scared_cup`.
3. Lados invertidos em todos (`fc(office,charles,ada)` etc.): mesmos momentos; em M1 `left_pose == "clipboard"`, `right_pose == "pen"`; `is_solved == true`.
4. Neutro: `fc(office,null,null)` → NEUTRAL; `fc(office,ada,null)` → NEUTRAL; `fc(null,ada,charles)` → NEUTRAL; tabuleiro vazio → tudo NEUTRAL, sem sons.
5. Cascata: Q1 vazio + Q2 completo → Q2 NEUTRAL; Q1 só cenário + Q2 completo → Q2 NEUTRAL; Q1 `fc(office,ada,null)`, Q2 `fc(office,ada,charles)`, Q3 `fc(kitchen,charles,teapot)` → Q2 e Q3 NEUTRAL.
6. Remoção cascateia: solução avaliada, depois Q1.right = null e reavaliada → Q1..Q4 NEUTRAL.
7. Dúvida: `fc(kitchen,ada,charles)` no Q1 → DOUBT, ada `doubt`, charles `default`, `show_doubt_icon`, 1 som; Q1=M1 + Q2 `fc(kitchen,charles,teapot)` → Q2 DOUBT; Q1 M1, Q2 M2, Q3 `fc(office,ada,charles)` → Q3 DOUBT; Q1 `fc(office,ada,ada)` → DOUBT; `fc(kitchen,charles,teapot)` no Q1 → DOUBT (sem Ada → poses `default`/`default`).
8. Dúvida propaga: Q1 `fc(kitchen,ada,charles)` (DOUBT) + Q2 `fc(office,ada,charles)` → Q2 DOUBT.
9. Qualquer quadro trocado na solução (ex.: Q3 = `fc(office,ada,charles)`) → `is_solved == false`.
10. Sons: M4 tem 2 sons; M1..M3 têm 1; NEUTRAL tem 0.
11. `same_outcome`: dois `evaluate` da solução → `same_outcome` true par a par; resultado M1 vs DOUBT → false; vs `null` → false.
12. `ending(solution())`: `frame_index == 3`, `scene_variant == "papers"`, poses `laughing`/`laughing` (invertida também), 2 sons.

- [ ] **Step 2: Rodar e ver falhar** — `--import` e depois `--script res://tests/test_lovelace_logic.gd` → erro de classe inexistente.

- [ ] **Step 3: Implementar as classes.** `LovelaceLogic.evaluate` percorre `i` de 0 a `board.size()-1` mantendo `prev: FrameResult`:

```
if content.scene == null or content.character_count() < 2 or (i > 0 and prev.state == NEUTRAL):
	-> NEUTRAL (variant/poses "default")
elif office com ada+charles (ids distintos):
	i == 0 -> M1; prev.moment == "M1" -> M2; prev.moment == "M3" -> M4; senão DOUBT
elif kitchen com charles+teapot:
	prev != null and prev.moment == "M2" -> M3; senão DOUBT
else DOUBT
```
Poses atribuídas ao lado onde cada id está (tabela de poses por momento indexada por id). Sons via `preload` dos arquivos do "Mapa de áudio" da spec; dúvida usa `voiceofruthie-hmmmm-338158.mp3` se `has_character("ada")`, senão `freesound_community-hmms-various-1-7175.mp3`. `is_solved` = `board.size() == 4` e momentos de `evaluate` == `["M1","M2","M3","M4"]`. `ending` = índice 3, `papers`, `laughing` em ambos os lados, sons `woman_laughs` + `man-laughs-2`; retorna `null` se não resolvido.

- [ ] **Step 4: Rodar e ver passar** — `ALL PASSED`. Rodar também `test_phase_data.gd`.

- [ ] **Step 5: Commit**
```bash
git add core/story_logic tests/test_lovelace_logic.gd
git commit -m "feat: context-driven story logic for phase 1"
```

---

### Task 3: Tabuleiro ligado à lógica (ComicFrame + GameScreen + história)

**Files:**
- Modify: `src/comic_frame/comic_frame.gd`, `src/comic_frame/comic_frame.tscn`, `src/screens/game_screen/game_screen.gd`, `src/screens/game_screen/game_screen.tscn`
- Create: `data/stories/lovelace_notes.tres`
- Delete: `src/comic_frame/frame_story_logic.gd` (+ `.uid`), `data/characters/king.tres`, `data/characters/monster.tres`, `data/scenes/throne.tres`, `data/scenes/laboratorio.tres`, `data/stories/default_story.tres`, `assets/sprites/rei/`, `assets/sprites/character/`, `assets/sprites/scenes/laboratorio.png` (+ `.import`)
- Test: `tests/test_lovelace_logic.gd` (sem mudança; regressão) + verificação manual

**Interfaces:**
- Consumes: Task 1 Resources; Task 2 `FrameContent`, `FrameResult`, `StoryLogic`.
- Produces:
  - `ComicFrame`: `signal contents_changed`; `signal item_dropped`; `func get_content() -> FrameContent`; `func apply_result(result: FrameResult) -> void`; `func set_interactive(enabled: bool) -> void`; `func highlight() -> void` (pulso de escala/brilho ~0,4 s via `FrameAnimator`); `func apply_ending(ending: EndingData) -> void`.
  - `GameScreen`: `var logic: StoryLogic`; `var frames: Array[ComicFrame]`; `func _evaluate_board() -> void`; `var _last_results: Array[FrameResult]`.

- [ ] **Step 1: `ComicFrame`** — remover nó `FrameStoryLogic` e o `@onready` correspondente; remover a textura de preview do rei dos dois `CharacterTexture` no `.tscn`; adicionar nó `DoubtIcon` (`Label` "?" grande, `z_index` 15, canto superior direito, `mouse_filter = 2`, `visible = false`). Emitir `contents_changed` ao fim de `set_scene`, `add_character`, `clear_frame` (exceto na chamada de `_ready`) e dos três `_on_*_drag_finished`; emitir `item_dropped` em `_on_data_dropped`. `apply_result`: resolver texturas por `current_scene.get_variant(result.scene_variant)` e `character_*.get_pose(result.*_pose)`; atribuir só se diferente da atual (fade via `animator` quando muda); `DoubtIcon.visible = result.show_doubt_icon`. `set_interactive(false)` põe `mouse_filter = IGNORE` no fundo, sprites e `DropArea` (e restaura `STOP`/estado anterior com `true`).

- [ ] **Step 2: `GameScreen`** — em `load_story`: `logic = story.logic.new() if story.logic else null` (`push_warning` se nulo); guardar frames criados em `frames`, conectar `contents_changed` → `_evaluate_board`; `_last_results` resetado. `_evaluate_board`: montar `Array[FrameContent]` via `get_content()`, `results = logic.evaluate(board)`, `frames[i].apply_result(results[i])`; sons ficam para Task 4; desfecho para Task 5 (por ora `print("solved")` quando `logic.is_solved(board)`).

- [ ] **Step 3: História e limpeza** — criar `lovelace_notes.tres` (`id = "lovelace_notes"`, `title = "As notas de Lovelace"`, `number_of_frames = 4`, `draggable_items = [ada, charles, teapot, office, kitchen]`, `logic = lovelace_logic.gd`); apontar `game_screen.tscn` para ela; apagar os arquivos listados. `grep -r "king\|monster\|throne\|laboratorio\|default_story\|sprite_normal\|correct_answer\|FrameStoryLogic" src core data` → sem resultados.

- [ ] **Step 4: Testes de regressão** — `--import`, depois `test_phase_data.gd` e `test_lovelace_logic.gd` → `ALL PASSED`.

- [ ] **Step 5: Verificação manual (rodar o jogo, `"$GODOT" --path .`)**, virar para o jogo e conferir:
  1. Prateleira: Ada Lovelace, Charles Babbage, Bule de chá, Escritório, Cozinha; título "As notas de Lovelace".
  2. Montar a solução quadro a quadro: Q1 pena/prancheta; Q2 porta aberta, pena+artigos; Q3 xícara + bule; Q4 papéis, pilha, susto. Console: `solved`.
  3. Ada + Charles na Cozinha → "?" e Ada com dúvida.
  4. Arrastar Charles para fora do Q1 → Q1..Q4 voltam ao default sem "?".
  5. Lados trocados funcionam.
  6. Com Q1 coerente, soltar Cozinha no Q1 → Q1 vira dúvida (Review Focus 3).
  Sem erros no console.

- [ ] **Step 6: Commit**
```bash
git add -A src data assets/sprites core
git commit -m "feat: wire comic frames to phase logic and remove placeholders"
```

---

### Task 4: Áudio

**Files:**
- Create: `common/sound_player.gd`
- Modify: `project.godot` (autoload `SoundPlayer="*res://common/sound_player.gd"`), `src/screens/game_screen/game_screen.gd`, `src/screen_manager/screen_manager.gd`
- Test: verificação manual

**Interfaces:**
- Consumes: `FrameResult.sounds`, `FrameResult.same_outcome` (Task 2); `ComicFrame.item_dropped` (Task 3).
- Produces: autoload `SoundPlayer` com `func play(stream: AudioStream) -> void` e `func play_all(streams: Array[AudioStream]) -> void`; pool de 6 `AudioStreamPlayer` criados em `_ready`; usa o primeiro que não está tocando; se todos ocupados, reusa o índice 0. `null` ignorado.

- [ ] **Step 1: Implementar `SoundPlayer` e registrar o autoload.**
- [ ] **Step 2: `GameScreen._evaluate_board`** — para cada `i`, se `_last_results` vazio ou `not results[i].same_outcome(_last_results[i])` → `SoundPlayer.play_all(results[i].sounds)`; depois `_last_results = results`. Conectar `item_dropped` de cada frame → `SoundPlayer.play(preload(".../freesound_community-cartoon_boing-92413.mp3"))`.
- [ ] **Step 3: `ScreenManager`** — em `_play_scene_flip`: `direction > 0` → `soumages-book-opening-345808.mp3`; senão `oxidvideos-book-closing-466850.mp3`.
- [ ] **Step 4: Regressão** — os dois testes headless → `ALL PASSED`.
- [ ] **Step 5: Verificação manual** — boing a cada drop; som de papel/lápis/chá/surpresa+vidro ao formar M1..M4; tirar e recolocar o mesmo personagem em M1 toca M1 de novo (mudou de NEUTRAL para COHERENT), mas soltar um cenário igual por cima não repete; "hmmmm" com Ada em dúvida e "hmms" sem Ada; livro abrindo/fechando nas viradas.
- [ ] **Step 6: Commit**
```bash
git add common/sound_player.gd project.godot src assets/sounds
git commit -m "feat: sound effects for story moments, doubt and page flips"
```
(Inclui `assets/sounds/` e seus `.import`.)

---

### Task 5: Desfecho e volta ao menu

**Files:**
- Modify: `src/screens/game_screen/game_screen.gd`, `src/screens/game_screen/game_screen.tscn`, `src/screen_manager/screen_manager.gd`, `src/comic_frame/comic_frame.gd`, `src/draggable/draggable.gd`
- Test: verificação manual

**Interfaces:**
- Consumes: `StoryLogic.is_solved`, `StoryLogic.ending`, `EndingData` (Task 2); `ComicFrame.set_interactive`, `highlight`, `apply_ending` (Task 3); `SoundPlayer` (Task 4).
- Produces: `GameScreen`: `signal back_to_menu_requested`; `func _play_ending() -> void`; nó `CompletionPanel` (`PanelContainer` centralizado, `visible = false`, com `Label` "Fase concluída" e `Button` "Voltar ao menu", fonte `Aged_Ink_Press.ttf`). `DraggableItem`: `func set_interactive(enabled: bool) -> void`.

- [ ] **Step 1: `ComicFrame.apply_ending(ending)`** — aplica `ending.scene_variant` e poses resolvidas por lado, com fade; esconde `DoubtIcon`.
- [ ] **Step 2: `GameScreen._play_ending`** — chamada no lugar do `print("solved")`, protegida por `_ending_played` (bool). Sequência com um único `Tween` guardado em `_ending_tween`: desativar interação de frames e itens da prateleira; para `i` em 0..3: `frames[i].highlight()` + `camera-sound`, intervalo 0,6 s; então `frames[ending.frame_index].apply_ending(ending)` + `SoundPlayer.play_all(ending.sounds)`; aguardar 1,5 s; mostrar `CompletionPanel` + `bell-sound`. Botão → `back_to_menu_requested.emit()`.
- [ ] **Step 3: Reset** — `load_story` mata `_ending_tween`, zera `_ending_played`, esconde o painel, reativa interação.
- [ ] **Step 4: `ScreenManager`** — conectar `GameScreen.back_to_menu_requested` → `flip_page_back`; ao virar para o jogo (`direction > 0`), chamar `game_screen.load_story(game_screen.story)` antes da animação para o tabuleiro aparecer limpo.
- [ ] **Step 5: Regressão** — testes headless → `ALL PASSED`.
- [ ] **Step 6: Verificação manual** — resolver a fase: interação bloqueada; 4 destaques com som de câmera; Q4 vira Ada e Charles rindo no escritório com papéis + risadas; painel + sino; "Voltar ao menu" vira a página para trás; "Iniciar" de novo mostra tabuleiro vazio, painel oculto. Voltar ao menu (botão `FlipBackButton`) no meio da recapitulação e reentrar → nada mais é aplicado ao tabuleiro novo (Review Focus 4).
- [ ] **Step 7: Commit**
```bash
git add src
git commit -m "feat: phase ending sequence and return to menu"
```
