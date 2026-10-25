# Fase 2 "Tatiana Sampaio ajuda um cadeirante" Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tornar jogável a segunda fase — hospital, laboratório, tratamento — como "Capítulo 2" no menu, extraindo antes a gramática de avaliação que as duas fases compartilham.

**Architecture:** A cascata de neutros, a dúvida e o casamento de momentos saem da `LovelaceLogic` para uma base `MomentLogic`; cada fase passa a declarar só a sua tabela de momentos e as suas regras de casamento. A fase 2 é uma subclasse nova mais seis Resources e quatro placeholders de arte; o motor de quadros não muda.

**Tech Stack:** Godot 4.5, GDScript. Testes headless (`extends SceneTree` com `--script`, ou cenas `.tscn` quando precisam de autoloads). Placeholders gerados com Python + PIL (11.3.0 disponível na máquina).

**Spec:** `docs/superpowers/specs/2026-10-25-fase2-tatiana-design.md`

## Global Constraints

- Godot 4.5; estilo do código existente: tabs, tipagem estática (`:=`, `-> void`), `class_name` em scripts reutilizáveis.
- Ids em inglês, nomes de exibição em português: `patient` "Cadeirante", `tatiana` "Tatiana Sampaio", `slide` "Lâmina", `hospital` "Hospital", `lab` "Laboratório".
- Momentos: `"M1"`, `"M2"`, `"M3"`. Poses: `patient` `default, hopeful, cured`; `tatiana` `default, exams, microscope, syringe, doubt, happy`; `slide` `default`. Cenários só com `default`.
- A chave `"default"` é obrigatória em todo dicionário de poses e variantes.
- Lado (esquerda/direita) não importa para casar momento, em nenhum card.
- A fase 2 não toca `FrameContent`, `FrameResult`, `ComicFrame` nem `GameScreen`.
- **Nada de arte é renomeado.** O projeto nomeia sprites de personagem em português, com espaços e acentos (`Ada Lovelace com Caneta de pena.png`).
- Sem sons: os sons por momento foram removidos do jogo no commit `1179482`.
- Comando da suíte: `GODOT=/caminho/do/godot sh tests/run_all.sh`. Sucesso é `ALL PASSED` em cada arquivo e saída 0.
- **Confira a contagem de checks, não só o exit code.** `TestUtils.finish` sai 0 quando um erro de script aborta o corpo de um teste, então um arquivo pode "passar" com menos asserções do que deveria.
- `src/screen_manager/screen_manager.tscn` tem uma alteração não commitada (o editor reagrupou as três telas sob o nó `Screens`; a ordem relativa não mudou). **Não faz parte deste plano** — deixe como está.
- Os quatro PNGs não rastreados em `assets/sprites/characters/` e o `level_design.txt` da raiz entram no commit da Task 2.

## Review Focus

1. **Trocar de capítulo recria o tabuleiro** — a fase 1 tem 4 quadros e a fase 2 tem 3; entrar na fase 2 depois da fase 1 deve mostrar 3 quadros e a prateleira nova, não sobras da anterior (pinado na Task 4).
2. **Concluir o capítulo 1 marca o capítulo 1** — com dois capítulos, marcar o errado deixa de ser hipótese (pinado na Task 4).
3. **Laboratório só com a Tatiana** — quadro incompleto fica neutro e cascateia, não vira dúvida (pinado na Task 3).
4. **Mesma peça nos dois lados** — duas Tatianas não formam par e nunca casam momento (pinado na Task 3).
5. **Chave de pose ausente cai para `default`** — um `.tres` a que falte uma chave não pode devolver textura nula (pinado na Task 2).

---

### Task 1: Extrair a gramática para `MomentLogic`

Refactor puro: nenhum comportamento muda e nenhum teste novo nasce. O ciclo
aqui é **verde → refatorar → verde**, e a prova de que nada foi perdido é a
contagem de checks da fase 1 continuar exatamente igual.

**Files:**
- Create: `core/story_logic/moment_logic.gd`
- Modify: `core/story_logic/lovelace_logic.gd`
- Test: `tests/test_lovelace_logic.gd` (**não muda** — é a rede)

**Interfaces:**
- Consumes: `FrameContent`, `FrameResult`, `EndingData`, `StoryLogic`.
- Produces:
  ```gdscript
  class_name MomentLogic extends StoryLogic
  func evaluate(board: Array[FrameContent]) -> Array[FrameResult]
  func is_solved(board: Array[FrameContent]) -> bool
  func _solution() -> Array                 # virtual; base devolve []
  func _moments() -> Dictionary             # virtual; base devolve {}
  func _match_moment(content: FrameContent, index: int, previous_moment: String) -> String   # virtual; base devolve ""
  func _evaluate_frame(content: FrameContent, index: int, previous: FrameResult) -> FrameResult
  func _coherent(content: FrameContent, moment: String) -> FrameResult
  func _doubt(content: FrameContent) -> FrameResult        # padrão: tudo "default"
  func _has_pair(content: FrameContent, first_id: String, second_id: String) -> bool
  ```
  `LovelaceLogic extends MomentLogic` mantém `class_name LovelaceLogic` e o
  comportamento atual.

- [ ] **Step 1: Baseline verde**

Run: `GODOT=... sh tests/run_all.sh`
Expected: 7 arquivos, todos `ALL PASSED`; anote `test_lovelace_logic` → **50 checks**.

- [ ] **Step 2: Criar `core/story_logic/moment_logic.gd`**

Mova para lá, sem reescrever, os corpos atuais de `evaluate`, `is_solved`,
`_evaluate_frame`, `_coherent` e `_has_pair` de `lovelace_logic.gd`. Troque as
referências a `SOLUTION` por `_solution()` e a `MOMENTS` por `_moments()`.
`_evaluate_frame` passa `previous.moment if previous else ""` para
`_match_moment`. O `_doubt` da base põe `"default"` nos dois lados.

- [ ] **Step 3: Encolher `core/story_logic/lovelace_logic.gd`**

`extends MomentLogic`. Ficam: as constantes `SOLUTION` e `MOMENTS` como estão
hoje, os dois virtuais devolvendo-as, o `_match_moment` atual com a assinatura
nova, o `_doubt` da Ada e o `ending` — nada mais.

- [ ] **Step 4: Rodar e ver passar com a mesma contagem**

Run: `GODOT=... sh tests/run_all.sh`
Expected: 7 arquivos `ALL PASSED`, e `test_lovelace_logic` com **50 checks**, o mesmo número do Step 1. Um número menor significa teste abortado por erro de script, não sucesso.

- [ ] **Step 5: Commit**

```bash
git add core/story_logic/moment_logic.gd core/story_logic/lovelace_logic.gd
git commit -m "refactor: extract the shared moment grammar from phase 1"
```

---

### Task 2: Arte e dados da fase 2

**Files:**
- Create: `assets/sprites/characters/Cadeirante esperançoso.png`, `Tatiana Sampaio no microscópio.png`, `Tatiana Sampaio com dúvida.png`, `Lâmina da proteína.png` (placeholders)
- Create: `data/characters/patient.tres`, `tatiana.tres`, `slide.tres`; `data/scenes/hospital.tres`, `lab.tres`
- Test: `tests/test_phase_data.gd`

**Interfaces:**
- Consumes: `CharacterData` (`id`, `display_name`, `faces_right`, `poses`, `get_pose`), `SceneData` (`id`, `display_name`, `variants`, `get_variant`).
- Produces: os cinco `.tres` acima, com as chaves da seção "Dados" da spec.

- [ ] **Step 1: Escrever as asserções em `tests/test_phase_data.gd`**

No mesmo estilo das que já existem para a fase 1:

```gdscript
var patient: CharacterData = load("res://data/characters/patient.tres")
for key in ["default", "hopeful", "cured"]:
	t.check(patient.poses.get(key) is Texture2D, "patient pose %s" % key)
var tatiana: CharacterData = load("res://data/characters/tatiana.tres")
for key in ["default", "exams", "microscope", "syringe", "doubt", "happy"]:
	t.check(tatiana.poses.get(key) is Texture2D, "tatiana pose %s" % key)
t.check(load("res://data/characters/slide.tres").poses.get("default") is Texture2D, "slide default")
t.check(load("res://data/scenes/hospital.tres").variants.get("default") is Texture2D, "hospital default")
t.check(load("res://data/scenes/lab.tres").variants.get("default") is Texture2D, "lab default")
t.eq([patient.id, tatiana.id], ["patient", "tatiana"], "phase 2 ids")
t.eq(tatiana.get_pose("nao_existe"), tatiana.poses["default"], "phase 2 pose fallback")   # Review Focus 5
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `GODOT=... --headless --path . --script res://tests/test_phase_data.gd`
Expected: FAIL — os recursos não existem.

- [ ] **Step 3: Gerar os quatro placeholders**

PNG 512×512 com o nome da peça escrito, no espírito do `teapot_placeholder.png`.
Python + PIL está disponível. Um arquivo por pose faltante, com os nomes
exatos listados em **Files**.

- [ ] **Step 4: Criar os cinco `.tres`**

Mapeamento de arquivo por chave, conforme a tabela "Arte" da spec — oito das
imagens já existem no repositório e não devem ser recriadas nem renomeadas:

| Recurso | Chave → arquivo |
|---|---|
| `patient.tres` | `default` → `Cadeirante default.png`; `hopeful` → placeholder; `cured` → `Cadeirante curado .png` |
| `tatiana.tres` | `default` → `Tatiane Sampaio Default.png`; `exams` → `Tatiana Sampaio com exame.png`; `microscope` → placeholder; `syringe` → `Tatiana Sampaio com seringa.png`; `doubt` → placeholder; `happy` → `Tatiana Sampaio com seringa e exames.png` |
| `slide.tres` | `default` → placeholder |
| `hospital.tres` | `default` → `scenario_phase2_hospital.png` |
| `lab.tres` | `default` → `scenario_phase2_lab.png` |

`display_name`: "Cadeirante", "Tatiana Sampaio", "Lâmina", "Hospital",
"Laboratório". Ajuste `faces_right` em `patient` e `tatiana` de forma que, nos
quadros, os dois fiquem virados para o centro.

Atenção a dois nomes de arquivo: `Cadeirante curado .png` tem um **espaço antes
do ponto**, e o sprite neutro da Tatiana é `Tatiane Sampaio Default.png`, com
"Tatiane". Os dois são assim no disco; copie exatamente, não "conserte".

- [ ] **Step 5: Rodar e ver passar**

Run: `GODOT=... --headless --path . --import` e depois a suíte completa
Expected: `test_phase_data` `ALL PASSED` com contagem maior que a atual (22); os outros seis arquivos inalterados.

- [ ] **Step 6: Commit**

```bash
git add assets/sprites/characters data/characters data/scenes tests/test_phase_data.gd level_design.txt
git commit -m "feat: phase 2 characters, scenes and placeholder art"
```
(Inclui os quatro PNGs que você já tinha desenhado e ainda não estavam rastreados, e o `level_design.txt` que originou a spec.)

---

### Task 3: As regras da fase 2 (`TatianaLogic`)

**Files:**
- Create: `core/story_logic/tatiana_logic.gd`, `data/stories/tatiana_protein.tres`
- Test: `tests/test_tatiana_logic.gd`

**Interfaces:**
- Consumes: `MomentLogic` (Task 1); os `.tres` da Task 2; `TestUtils`.
- Produces: `class_name TatianaLogic extends MomentLogic` e a fase
  `tatiana_protein.tres` (`id = "tatiana_protein"`, título
  "Tatiana Sampaio ajuda um cadeirante", `number_of_frames = 3`,
  `draggable_items = [patient, tatiana, slide, hospital, lab]`,
  `logic = tatiana_logic.gd`).

- [ ] **Step 1: Escrever `tests/test_tatiana_logic.gd`**

`extends SceneTree`, no molde de `test_lovelace_logic.gd`. Helpers locais que
carregam os `.tres` e um `fc(scene, left, right) -> FrameContent`;
`solution()` = `[fc(hospital, patient, tatiana), fc(lab, tatiana, slide), fc(hospital, patient, tatiana)]`.
Casos:

1. Solução: momentos `["M1","M2","M3"]`, todos `COHERENT`, `is_solved == true`.
2. Poses: M1 `patient` `default` / `tatiana` `exams`; M2 `tatiana` `microscope` / `slide` `default`; M3 `patient` `hopeful` / `tatiana` `syringe`.
3. Lados invertidos nos três quadros: mesmos momentos, `is_solved == true`, e as poses trocam de lado junto.
4. Dúvida: `fc(hospital, patient, tatiana)` no índice 1 depois do M1 → DOUBT com `tatiana` em `doubt`; `fc(lab, tatiana, slide)` no índice 0 → DOUBT.
5. **Review Focus 3** — `fc(lab, tatiana, null)` → NEUTRAL; com ele no índice 1, o quadro 2 também fica NEUTRAL.
6. **Review Focus 4** — `fc(hospital, tatiana, tatiana)` → DOUBT, nunca M1.
7. `ending(solution())`: `frame_index == 2`, `scene_variant == "default"`, zero sons, `left_pose == "cured"` e `right_pose == "happy"`; com o último quadro invertido (`fc(hospital, tatiana, patient)`), `left_pose == "happy"` e `right_pose == "cured"`.
8. `ending` de um tabuleiro não resolvido → `null`.

- [ ] **Step 2: Rodar e ver falhar**

Run: `GODOT=... --headless --path . --script res://tests/test_tatiana_logic.gd`
Expected: FAIL — a classe não existe.

- [ ] **Step 3: Implementar `TatianaLogic` e criar a fase**

As constantes `SOLUTION` e `MOMENTS`, os dois virtuais, o `_match_moment` da
seção "As regras da fase 2" da spec, o `_doubt` que dá `doubt` a `tatiana`, e o
`ending` que resolve as poses pelo id de cada lado. Depois crie
`data/stories/tatiana_protein.tres`.

- [ ] **Step 4: Rodar e ver passar**

Run: `--import` e depois a suíte completa
Expected: `test_tatiana_logic` `ALL PASSED`; os outros arquivos com a contagem inalterada.

- [ ] **Step 5: Commit**

```bash
git add core/story_logic/tatiana_logic.gd data/stories/tatiana_protein.tres tests/test_tatiana_logic.gd
git commit -m "feat: phase 2 story logic"
```

---

### Task 4: Capítulo 2 no menu

**Files:**
- Modify: `src/screens/menu_screen/menu_screen.tscn`
- Test: `tests/test_menu.gd`

**Interfaces:**
- Consumes: `tatiana_protein.tres` (Task 3); `MenuScreen.stories`, `ScreenManager.Screen`, `ScreenManager.navigate_to` (já existentes).
- Produces: nenhuma interface nova — a fase 2 passa a ser `stories[1]`.

- [ ] **Step 1: Estender `tests/test_menu.gd`**

Ajuste os testes que hoje esperam uma linha só e acrescente:

```gdscript
func test_two_chapters() -> void
	t.eq(rows(menu).size(), 2, "two chapter rows")
	t.eq(rows(menu)[1].text, "Capítulo 2", "second chapter label")
	t.eq(rows(menu)[1].tooltip_text, "Tatiana Sampaio ajuda um cadeirante", "second tooltip")

func test_switching_chapters_rebuilds_the_board() -> void   # Review Focus 1
	# entrar no capítulo 1, voltar ao menu, entrar no capítulo 2
	t.eq(manager.game_screen.frames.size(), 3, "phase 2 has three frames")
	t.eq(manager.game_screen.story.id, "tatiana_protein", "phase 2 story is loaded")
	t.eq(manager.game_screen.shelf.get_child_count(), 5, "phase 2 shelf has five pieces")

func test_completing_chapter_one_marks_chapter_one() -> void   # Review Focus 2
	# resolver a fase 1 pelo gerenciador e esperar o desfecho
	t.eq(chapter_button(manager, 0).icon, CHECKED, "chapter 1 is marked")
	t.eq(chapter_button(manager, 1).icon, UNCHECKED, "chapter 2 is not marked")
```

O helper `chapter_button(manager)` passa a receber o índice da linha.

- [ ] **Step 2: Rodar e ver falhar**

Run: `GODOT=... --headless --path . res://tests/test_menu.tscn`
Expected: FAIL — só existe um capítulo.

- [ ] **Step 3: Acrescentar a fase ao menu**

Em `src/screens/menu_screen/menu_screen.tscn`, acrescente
`tatiana_protein.tres` ao array `stories`, **depois** de `lovelace_notes.tres`.
A ordem do array é a ordem dos capítulos.

- [ ] **Step 4: Rodar e ver passar**

Run: a suíte completa
Expected: 8 arquivos `ALL PASSED`; `test_menu` com contagem maior que 28.

- [ ] **Step 5: Verificação manual** (`godot --path .`)

1. "Jogar" leva ao menu, que mostra "Capítulo 1" e "Capítulo 2" com os tooltips certos.
2. Capítulo 2 abre com **3** quadros e a prateleira de cinco peças.
3. Hospital + Cadeirante + Tatiana no quadro 1: ela aparece lendo os exames.
4. Laboratório + Tatiana + Lâmina no quadro 2: ela aparece no microscópio.
5. Hospital + Cadeirante + Tatiana no quadro 3: ela com a seringa, ele esperançoso.
6. O desfecho põe o cadeirante de pé e volta ao menu com o Capítulo 2 marcado.
7. Voltar à tela inicial apaga as marcas; entrar no capítulo 1 mostra 4 quadros de novo.
8. Sem erros no console.

- [ ] **Step 6: Commit**

```bash
git add src/screens/menu_screen/menu_screen.tscn tests/test_menu.gd
git commit -m "feat: add phase 2 as the second chapter"
```
