# Fluxo de telas e progresso de capítulos Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Pôr a `MenuScreen` no fluxo do jogo (`StartScreen` → `MenuScreen` → `GameScreen`), com botão de voltar em cada tela, capítulo 1 ligado à fase da Ada, progresso de capítulo por visitante, e desfecho da fase 1 sem os áudios de risada.

**Architecture:** Os dois `SubViewport` do `ScreenManager` deixam de ter identidade fixa ("a inicial" e "o jogo") e passam a ter papel ("quem sai" e "quem entra"), alternando a cada virada. As três telas são instanciadas uma vez cada sob um nó `Screens` e reparentadas para o viewport de trás antes de cada animação. A navegação é um índice numa lista ordenada, sem pilha, porque o fluxo é linear. O progresso de capítulos mora na própria `MenuScreen`, em memória.

**Tech Stack:** Godot 4.5, GDScript, GL Compatibility. Testes: scripts `extends SceneTree` e cenas de teste `extends Node` rodados com `godot --headless`.

**Spec:** `docs/superpowers/specs/2026-10-25-fluxo-de-telas-design.md`

## Global Constraints

- Godot 4.5; estilo do código existente: tabs, tipagem estática (`:=`, `-> void`), `class_name` em scripts reutilizáveis, `@onready` para nós.
- Texto de UI em português, exato: `"Capítulo %d"`, `"< Voltar"`. Os textos já existentes (`"Jogar"`, `"Sair"`, `"As notas de Lovelace"`) não mudam.
- Ícones de capítulo: `res://assets/themes/chapter_checkbox_checked.svg` e `res://assets/themes/chapter_checkbox_unchecked.svg` (ainda não rastreados no git; entram no commit da Task 2).
- Tema dos botões: `res://assets/themes/button-theme.tres`.
- Nomes de sinais finais: `StartScreen.start_requested`, `MenuScreen.phase_selected(story)`, `MenuScreen.back_requested`, `GameScreen.back_requested`, `GameScreen.story_completed(story)`. `GameScreen.back_to_menu_requested` deixa de existir (Task 3).
- Comandos de teste (substituir `$GODOT` pelo executável do Godot 4.5 da máquina):
  - script: `"$GODOT" --headless --path . --script res://tests/<arquivo>.gd`
  - cena (precisa de autoloads e de nós): `"$GODOT" --headless --path . res://tests/<arquivo>.tscn`
  - `"$GODOT" --headless --path . --import` uma vez após criar `class_name` ou assets novos.
  - Sucesso: linha `ALL PASSED` e exit code 0.
- O `src/screens/menu_screen/`, os dois SVGs de ícone e a linha `.claude/` do `.gitignore` já estão no diretório de trabalho sem estar commitados. Entram junto da tarefa que os toca (Task 2), não em commit separado.
- Toda tarefa termina com o repositório verde: nenhuma tarefa deixa um sinal desconectado ou um teste quebrado para a seguinte consertar.

## Review Focus

1. **Voltar no meio do desfecho** — apertar "< Voltar" durante a recapitulação não deve marcar o capítulo como concluído nem tocar o sino (pinado na Task 5).
2. **Ida e volta repetida entre as três telas** — depois de várias navegações, cada tela deve estar em exatamente um lugar: a visível num viewport, as outras duas estacionadas em `Screens`; nenhuma duplicada, nenhuma perdida (pinado na Task 4).
3. **Navegar durante uma virada** — dois cliques rápidos num capítulo, ou voltar enquanto a página gira, devem produzir uma única virada (pinado na Task 4).
4. **Reentrar na fase depois de sair sem concluir** — o tabuleiro aparece limpo e nenhum tween pendente do desfecho anterior aplica poses nele (pinado na Task 5).
5. **`stories` vazio** — o menu fica sem linhas, emite `push_warning` e navegar para ele não quebra (pinado na Task 2).

---

### Task 1: Desfecho sem risadas

**Files:**
- Modify: `core/story_logic/lovelace_logic.gd:14-15` (constantes), `:44` (sons do desfecho)
- Test: `tests/test_lovelace_logic.gd:151`, `tests/test_ending.gd:70-72`

**Interfaces:**
- Produces: `LovelaceLogic.ending(board)` devolve `EndingData` com `sounds` vazio. `frame_index`, `scene_variant` e as poses `laughing` não mudam.

- [ ] **Step 1: Ajustar as asserções dos dois testes**

Em `tests/test_lovelace_logic.gd`, no `test_ending()`:
```gdscript
t.eq(ending.sounds.size(), 0, "ending has no sounds")
```

Em `tests/test_ending.gd`, no `test_ending_sequence()`, as duas asserções de risada invertem e o total cai:
```gdscript
t.check(not played.has("freesound_community-woman_laughs-37559.mp3"), "no woman laugh")
t.check(not played.has("floraphonic-man-laughs-2-190296.mp3"), "no man laugh")
t.eq(played.size(), 5, "only camera clicks and the bell play")
```
A asserção `played.back() == BELL` ("bell plays last") continua como está.

- [ ] **Step 2: Rodar e ver falhar**

Run: `"$GODOT" --headless --path . --script res://tests/test_lovelace_logic.gd` e `"$GODOT" --headless --path . res://tests/test_ending.tscn`
Expected: FAIL em `ending has no sounds` (recebe 2) e em `only camera clicks and the bell play` (recebe 7).

- [ ] **Step 3: Implementar**

Em `core/story_logic/lovelace_logic.gd`: remover as constantes `SOUND_WOMAN_LAUGH` e `SOUND_MAN_LAUGH` e trocar a atribuição em `ending()` por `data.sounds.assign([])`. Nada mais no arquivo muda — as poses `laughing` ficam.

- [ ] **Step 4: Rodar e ver passar**

Run: os dois comandos do Step 2
Expected: `ALL PASSED` nos dois.

- [ ] **Step 5: Commit**

```bash
git add core/story_logic/lovelace_logic.gd tests/test_lovelace_logic.gd tests/test_ending.gd
git commit -m "feat: keep only the bell in the phase 1 ending"
```

---

### Task 2: `MenuScreen` autônoma — capítulos declarados, linhas clicáveis, progresso

**Files:**
- Modify: `src/screens/menu_screen/menu_screen.gd`, `src/screens/menu_screen/menu_screen.tscn`
- Create: `tests/test_menu.gd`, `tests/test_menu.tscn`

**Interfaces:**
- Consumes: `StoryData` (`id`, `title`); `data/stories/lovelace_notes.tres`.
- Produces:
  ```gdscript
  class_name MenuScreen extends Control
  signal phase_selected(story: StoryData)
  signal back_requested
  @export var stories: Array[StoryData]
  func mark_completed(story: StoryData) -> void
  func reset_progress() -> void
  ```
  Interno: `_completed: Dictionary[String, bool]` indexado por `story.id`; `_buttons: Array[Button]` na mesma ordem de `stories`.

- [ ] **Step 1: Escrever `tests/test_menu.tscn` e `tests/test_menu.gd`**

`test_menu.tscn` é um `Node` com o script, igual a `tests/test_ending.tscn`. `test_menu.gd` (`extends Node`, `t := TestUtils.new()`, `_run` chamado por `_ready` com `call_deferred`, fecha com `t.finish(get_tree())`) instancia a cena do menu com um helper `new_menu(stories: Array[StoryData]) -> MenuScreen` que atribui `stories` **antes** do `add_child`. Casos:

```gdscript
func test_chapter_list() -> void   # menu com [lovelace]
	t.eq(buttons.size(), 1, "one chapter row")
	t.eq(buttons[0].text, "Capítulo 1", "chapter label")
	t.eq(buttons[0].tooltip_text, "As notas de Lovelace", "tooltip is the title")
	t.eq(buttons[0].icon, UNCHECKED, "starts unchecked")

func test_pressing_a_chapter_selects_it() -> void
	# conecta phase_selected numa lista, buttons[0].pressed.emit()
	t.eq(selected, [lovelace], "pressing emits the story")

func test_progress_marks_and_resets() -> void
	menu.mark_completed(lovelace)
	t.eq(buttons[0].icon, CHECKED, "completed chapter is checked")
	menu.mark_completed(lovelace)
	t.eq(buttons.size(), 1, "marking twice keeps one row")
	t.eq(buttons[0].icon, CHECKED, "marking twice stays checked")
	menu.reset_progress()
	t.eq(buttons[0].icon, UNCHECKED, "reset clears the mark")

func test_empty_stories() -> void   # Review Focus 5; menu com []
	t.eq(buttons.size(), 0, "no rows without stories")

func test_back_button() -> void
	# conecta back_requested num contador, menu.get_node("BackButton").pressed.emit()
	t.eq(backs, 1, "back button requests going back")
```
`UNCHECKED` e `CHECKED` são as duas texturas de `assets/themes/`. `buttons` sai dos filhos de `$RightPanel/PhaseScroll/PhaseCenter/PhaseList`.

- [ ] **Step 2: Rodar e ver falhar**

Run: `"$GODOT" --headless --path . --import` e depois `"$GODOT" --headless --path . res://tests/test_menu.tscn`
Expected: FAIL — `stories` não existe e as linhas são `CheckBox`, não `Button` com `icon`.

- [ ] **Step 3: Reescrever `menu_screen.gd`**

Trocar `@export_dir var stories_directory` e todo o `_load_stories()` (com o `DirAccess`) por `@export var stories: Array[StoryData]`; `push_warning` se vier vazio. Em `_create_phase_list()`, cada linha passa a ser um `Button` com `text = "Capítulo %d" % [index + 1]`, `tooltip_text = story.title`, `icon` resolvido pelo progresso, e `pressed` ligado a emitir `phase_selected(story)`. Mantém `custom_minimum_size`, `size_flags_horizontal`, o tamanho de fonte 42, `icon_max_width` 44 e `h_separation` 14; saem `theme_type_variation`, `add_theme_stylebox_override("hover", ...)`, `_create_hover_style()` e `_on_phase_toggled()` inteiro. Guardar as linhas em `_buttons` para `mark_completed`/`reset_progress` trocarem só o `icon`.

- [ ] **Step 4: Botão de voltar em `menu_screen.tscn`**

Adicionar um `Button` chamado `BackButton`, filho direto da raiz, âncora no topo à esquerda (`offset_left = 16`, `offset_top = 12`), `theme = button-theme.tres`, `text = "< Voltar"`, ligado a emitir `back_requested`. No mesmo arquivo, preencher `stories` com `data/stories/lovelace_notes.tres` — é isso que liga o capítulo 1 à fase da Ada.

- [ ] **Step 5: Rodar e ver passar**

Run: `"$GODOT" --headless --path . res://tests/test_menu.tscn`
Expected: `ALL PASSED`.

- [ ] **Step 6: Commit**

```bash
git add src/screens/menu_screen tests/test_menu.gd tests/test_menu.tscn assets/themes/chapter_checkbox_checked.svg assets/themes/chapter_checkbox_checked.svg.import assets/themes/chapter_checkbox_unchecked.svg assets/themes/chapter_checkbox_unchecked.svg.import .gitignore
git commit -m "feat: chapter menu with declared stories and progress marks"
```
(Primeiro commit do `menu_screen/` e dos ícones, que até aqui não estavam rastreados.)

---

### Task 3: `GameScreen` — `back_requested`, `story_completed` e botão de voltar

**Files:**
- Modify: `src/screens/game_screen/game_screen.gd`, `src/screens/game_screen/game_screen.tscn`, `src/screen_manager/screen_manager.gd:34` (uma linha, para o sinal renomeado continuar conectado)
- Test: `tests/test_ending.gd`

**Interfaces:**
- Consumes: `StoryLogic.ending`, `SoundPlayer` (já existentes).
- Produces:
  ```gdscript
  signal back_requested                      # substitui back_to_menu_requested
  signal story_completed(story: StoryData)
  ```
  Ao fim do desfecho, `story_completed(story)` é emitido **antes** de `back_requested`. O botão de voltar emite só `back_requested`.

- [ ] **Step 1: Ajustar `tests/test_ending.gd`**

As três conexões de `back_to_menu_requested` (linhas 57, 95 e a do teste de navegação) passam a `back_requested`. No `test_ending_sequence()`, registrar a ordem dos dois sinais numa lista e, depois do `await wait(1.0)`:
```gdscript
t.eq(events, ["completed:lovelace_notes", "back"], "completion is announced before leaving")
```
E um teste novo, para o botão:
```gdscript
func test_back_button_does_not_complete() -> void
	# game.get_node("BackButton").pressed.emit() num tabuleiro não resolvido
	t.eq(events, ["back"], "leaving by button completes nothing")
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `"$GODOT" --headless --path . res://tests/test_ending.tscn`
Expected: FAIL — `back_requested` e `story_completed` não existem.

- [ ] **Step 3: Implementar**

Em `game_screen.gd`: renomear o sinal e declarar `story_completed(story: StoryData)`; no fim da cadeia de `_ending_tween` em `_play_ending`, inserir um `tween_callback` que emite `story_completed` com `story` imediatamente antes do que emite `back_requested`. Em `game_screen.tscn`, adicionar o `BackButton` com os mesmos atributos da Task 2 Step 4, irmão de `Content` e com `z_index` acima dele, ligado a emitir `back_requested`. Em `screen_manager.gd:34`, trocar `game_screen.back_to_menu_requested.connect(...)` pelo nome novo — correção mínima; a Task 4 reescreve essa linha de todo jeito.

- [ ] **Step 4: Rodar e ver passar**

Run: `"$GODOT" --headless --path . res://tests/test_ending.tscn`
Expected: `ALL PASSED`.

- [ ] **Step 5: Commit**

```bash
git add src/screens/game_screen src/screen_manager/screen_manager.gd tests/test_ending.gd
git commit -m "feat: split leaving the game screen from completing the story"
```

---

### Task 4: Virada por papel no `ScreenManager` (refactor, sem tela nova)

Esta tarefa troca a máquina de navegação **sem** mudar o comportamento visível: continuam duas telas, inicial e jogo. A tela do menu entra na Task 5. O teste de navegação que já existe é o que prova que nada regrediu.

**Files:**
- Modify: `src/screen_manager/screen_manager.gd`, `src/screen_manager/screen_manager.tscn`, `src/screens/start_screen/start_screen.gd`
- Test: `tests/test_ending.gd::test_screen_manager_navigation`

**Interfaces:**
- Consumes: `GameScreen.back_requested`, `GameScreen.cancel_ending`, `GameScreen.load_story` (Task 3 e existentes); `StartScreen.start_requested`.
- Produces:
  ```gdscript
  func navigate_to(index: int) -> void
  var _current_index: int
  ```
  Os índices seguem a ordem dos filhos do nó `Screens`: nesta tarefa `0` = inicial e `1` = jogo. A Task 5 insere o menu em `1`, empurra o jogo para `2` e dá nome a eles com `enum Screen { START, MENU, GAME }`. `flip_page_next` e `flip_page_back` deixam de existir.
  `StartScreen` ganha `class_name StartScreen`.

- [ ] **Step 1: Ajustar `test_screen_manager_navigation` e cobrir o Review Focus**

Trocar `manager.flip_page_next()` por `manager.navigate_to(1)` e as duas asserções de `_current_is_start` por `_current_index`:
```gdscript
t.eq(manager._current_index, 1, "game page is showing")
t.eq(manager._current_index, 0, "finishing the ending flips back")
```
E dois testes novos no mesmo arquivo:
```gdscript
func test_navigating_during_a_flip_is_ignored() -> void   # Review Focus 3
	manager.navigate_to(1)
	manager.navigate_to(1)        # durante a virada
	manager.navigate_to(0)        # durante a virada
	await wait(manager.flip_duration + 0.3)
	t.eq(manager._current_index, 1, "only the first navigation runs")

func test_round_trips_keep_one_parent_per_screen() -> void   # Review Focus 2
	# navegar 1 → 0 → 1 → 0, esperando cada virada; depois, para cada índice i:
	var parent := manager._screens[i].get_parent()
	if i == manager._current_index:
		t.check(parent is SubViewport, "the visible screen sits in a viewport")
	else:
		t.eq(parent.name, &"Screens", "parked screens live in Screens")

func test_navigating_out_of_range_is_ignored() -> void
	manager.navigate_to(-1)
	manager.navigate_to(manager._screens.size())
	await wait(manager.flip_duration + 0.3)
	t.eq(manager._current_index, 0, "out of range does nothing")
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `"$GODOT" --headless --path . res://tests/test_ending.tscn`
Expected: FAIL — `navigate_to` e `_current_index` não existem.

- [ ] **Step 3: Reestruturar `screen_manager.tscn`**

Adicionar um nó `Screens` (tipo `Node`) filho da raiz e mover para dentro dele as instâncias `StartScreen` e `GameScreen`, que hoje estão dentro de `ScreenViewport` e `NextScreenViewport`. Remover os nós `FlipBackButton` e `FlipNextButton`.

- [ ] **Step 4: Reescrever a navegação em `screen_manager.gd`**

Campos novos: `_containers`, `_viewports` e `_meshes` como arrays de dois elementos montados no `_ready` na ordem em que os nós existem na cena (`ScreenViewportContainer`/`PageFlipMesh` primeiro, `NextScreenViewportContainer`/`NextPageFlipMesh` depois); `_screens: Array[Control]` a partir dos filhos de `Screens`; `_current_index := 0`; `_front := 0`; `_back := 1`. Saem `_current_is_start`, `flip_page_next`, `flip_page_back`, `_play_flip` e `_on_start_requested`, e com eles as conexões dos dois botões removidos. O `get_node_or_null("StartScreen")` com `has_signal` vira `@onready var start_screen: StartScreen = $Screens/StartScreen` com conexão direta a `navigate_to(1)`; `game_screen` passa a `$Screens/GameScreen`.

Dois helpers de montagem: `_mount(screen: Control, slot: int) -> void` (tira a tela do pai atual e a põe em `_viewports[slot]`) e `_park(screen: Control) -> void` (devolve a tela ao nó `Screens`). O `_ready` monta `_screens[0]` no viewport da frente antes do `setup()` das malhas.

`navigate_to(index)` segue os nove passos da seção "ScreenManager" da spec. Atenção aos pontos onde o refactor muda a forma do código:

- `_apply_flip_progress` perde o `if` de direção: `_meshes[_front]` anda `progress` com `_flip_direction` e `_meshes[_back]` anda `1.0 - progress` com `-_flip_direction`, sempre. O `physical_page` continua dirigido como hoje.
- `_set_content_layers(outgoing_on_top: bool)` recebe o booleano em vez de deduzir pela direção: a malha da frente fica em `z_index` 17 e a de trás em 14 quando verdadeiro, invertido quando falso.
- O container de trás recebe `visible = progress >= 0.5` e `modulate.a = smoothstep(0.5, 0.85, progress)` em **toda** virada (hoje só na ida).
- `_finish_flip` troca `_front` e `_back`, grava `_current_index`, devolve o novo viewport de trás a `UPDATE_DISABLED` e estaciona a tela que saiu.

A conexão de `back_requested` precisa ler `_current_index` na hora do clique, não na hora de conectar: use uma lambda, não `bind`.

Em `start_screen.gd`: adicionar `class_name StartScreen` e apagar os stubs vazios `_ready()` e `_process()`.

- [ ] **Step 5: Rodar e ver passar**

Run: `"$GODOT" --headless --path . --import` e depois `"$GODOT" --headless --path . res://tests/test_ending.tscn`
Expected: `ALL PASSED`.

- [ ] **Step 6: Commit**

```bash
git add src/screen_manager src/screens/start_screen tests/test_ending.gd
git commit -m "refactor: drive page flips by role instead of fixed screens"
```

---

### Task 5: A `MenuScreen` no fluxo e o progresso ligado

**Files:**
- Modify: `src/screen_manager/screen_manager.gd`, `src/screen_manager/screen_manager.tscn`
- Test: `tests/test_menu.gd`, `tests/test_ending.gd::test_screen_manager_navigation`

**Interfaces:**
- Consumes: `MenuScreen.phase_selected`, `MenuScreen.back_requested`, `MenuScreen.mark_completed`, `MenuScreen.reset_progress` (Task 2); `GameScreen.story_completed`, `GameScreen.back_requested` (Task 3); `navigate_to` (Task 4).
- Produces: `enum Screen { START, MENU, GAME }` no `ScreenManager`, substituindo os índices crus da Task 4.

- [ ] **Step 1: Escrever os testes da cadeia completa**

Em `tests/test_ending.gd::test_screen_manager_navigation`, estender o percurso para três telas: `navigate_to(Screen.MENU)`, depois `Screen.GAME`, depois voltar duas vezes, checando `_current_index` a cada passo e mantendo as asserções de parentesco da Task 4 (agora com três telas, duas estacionadas).

Em `tests/test_menu.gd`, a integração pelo `ScreenManager`. O arquivo precisa de três coisas que hoje só existem em `test_ending.gd` e que devem ser escritas aqui também: um helper `new_manager() -> ScreenManager` no mesmo padrão da instanciação em `test_screen_manager_navigation` (com `recap_interval` e `ending_hold` curtos), o tap em `SoundPlayer.played` que alimenta a lista `played`, e a constante `BELL` com o nome do arquivo do sino. Os helpers `solve(game)` e `fill(frame, ...)` também são necessários — copie-os de `test_ending.gd` ou mova os dois para `tests/support/test_utils.gd` se preferir não duplicar.
```gdscript
func test_completing_a_chapter_returns_to_the_menu_marked() -> void
	# menu → capítulo 1 → resolver a fase → esperar o desfecho
	t.eq(manager._current_index, ScreenManager.Screen.MENU, "ending lands on the menu")
	t.eq(chapter_button.icon, CHECKED, "chapter 1 is marked")

func test_returning_to_the_start_screen_clears_progress() -> void
	t.eq(chapter_button.icon, UNCHECKED, "progress is per visitor")

func test_leaving_mid_ending_completes_nothing() -> void   # Review Focus 1
	# resolver a fase e, antes do fim da recapitulação, emitir back_requested
	t.eq(chapter_button.icon, UNCHECKED, "chapter is not marked")
	t.eq(played.count(BELL), 0, "no bell after leaving")

func test_reentering_a_phase_starts_clean() -> void   # Review Focus 4
	# entrar na fase, preencher um quadro, voltar ao menu, entrar de novo
	t.check(game.frames[0].get_content().is_empty(), "board is clean on reentry")
	t.check(game.frames[3].sprite_left.texture == null, "no pending ending applies poses")
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `"$GODOT" --headless --path . res://tests/test_menu.tscn`
Expected: FAIL — o `ScreenManager` não tem `Screen.MENU` nem a tela do menu.

- [ ] **Step 3: Inserir a tela e ligar os sinais**

Em `screen_manager.tscn`, instanciar `menu_screen.tscn` sob `Screens`, **entre** `StartScreen` e `GameScreen` — a ordem dos filhos é a ordem dos índices.

Em `screen_manager.gd`: declarar `enum Screen { START, MENU, GAME }` e trocar os índices crus da Task 4 por ele; `@onready var menu_screen: MenuScreen = $Screens/MenuScreen`; `start_requested` passa a levar a `Screen.MENU`. Conectar, conforme a tabela "Fiação" da spec: `menu_screen.phase_selected` → atribui `game_screen.story` e navega para `Screen.GAME`; `menu_screen.back_requested` e `game_screen.back_requested` → `navigate_to(_current_index - 1)`; `game_screen.story_completed` → `menu_screen.mark_completed`.

Em `navigate_to`, precisar as duas condições que hoje olham só a direção: `cancel_ending()` quando a tela que **sai** é `Screen.GAME`, `load_story()` quando a tela que **entra** é `Screen.GAME` e tem `story`, e `reset_progress()` quando a tela que entra é `Screen.START`.

- [ ] **Step 4: Rodar e ver passar**

Run: `"$GODOT" --headless --path . res://tests/test_menu.tscn`, `res://tests/test_ending.tscn` e `--script res://tests/test_lovelace_logic.gd`
Expected: `ALL PASSED` nos três.

- [ ] **Step 5: Verificação manual** (`"$GODOT" --path .`)

1. "Jogar" leva ao **menu**, não ao jogo; o menu mostra "Capítulo 1" com o ícone vazio e o tooltip "As notas de Lovelace".
2. Clicar no capítulo entra na fase da Ada, com o tabuleiro limpo.
3. "< Voltar" aparece no canto superior esquerdo do menu e do jogo, **não** na tela inicial, e não colide com o título "As notas de Lovelace" (se colidir, subir a margem superior de `Content` em `game_screen.tscn`).
4. Resolver a fase: recapitulação com som de câmera, Q4 com Ada e Charles rindo **em silêncio**, sino, e volta ao menu com o capítulo 1 marcado.
5. Voltar ao menu e à tela inicial: a marca do capítulo 1 desaparece.
6. Nenhuma piscada de um frame ao entrar em cada tela; a virada para trás agora tem o mesmo fade da virada para frente (mudança intencional).
7. Sem erros no console.

- [ ] **Step 6: Commit**

```bash
git add src/screen_manager tests/test_menu.gd tests/test_ending.gd
git commit -m "feat: route the chapter menu between the start and game screens"
```
