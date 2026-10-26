# Fase 1 — "As notas de Lovelace" — Design

Data: 2026-10-25
Fonte: `level_design.txt`

## Objetivo

Implementar a primeira fase jogável do Storyteller SNCT: o jogador arrasta
**personagens e cenários "puros"** para 4 quadros e o jogo escolhe **poses e
variações de cenário pelo contexto** (quadro atual + quadros anteriores). Ao
montar a história certa, uma sequência de desfecho celebra a conclusão.

Público: visitantes de feira (SNCT), sem tutorial. O jogo precisa guiar com
reações visuais e sonoras.

Sucesso: os 4 quadros montados como M1→M2→M3→M4 disparam o desfecho; quadros
incoerentes mostram dúvida; quadros incompletos não punem o jogador.

## Decisões de jogo

1. **Contexto escolhe a pose** — prateleira só tem Ada, Charles, Bule,
   Escritório e Cozinha. Sem cartas de pose prontas.
2. **Avaliação ao vivo com dicas** — sem botão "conferir"; quadros reagem a
   cada mudança; incoerências mostram dúvida.
3. **Bule de chá é personagem arrastável** — usa textura placeholder até a arte
   ficar pronta.
4. **Escritório é um card único** — fundo muda por contexto
   (`default` / `open_door` / `papers`).
5. **Desfecho** — recapitulação quadro a quadro, Q4 se transforma em risadas,
   aviso "Fase concluída" com botão "Voltar ao menu".
6. **Lado não importa** — Ada/Charles podem estar à esquerda ou à direita; a pose
   é aplicada ao slot onde o personagem está.

## Regras (`LovelaceLogic`)

Momentos da história:

| Momento | Condição | Fundo | Poses | Som |
|---|---|---|---|---|
| M1 Entrega | Escritório + Ada + Charles, no Q1 | `default` | Ada `pen`, Charles `clipboard` | papel |
| M2 Saída | Escritório + Ada + Charles, quadro anterior é M1 | `open_door` | Ada `pen_articles`, Charles `default` | lápis |
| M3 Chá | Cozinha + Charles + Bule, quadro anterior é M2 | `default` | Charles `cup`, Bule `default` | chá |
| M4 Susto | Escritório + Ada + Charles, quadro anterior é M3 | `papers` | Ada `pile`, Charles `scared_cup` | surpresa + vidro |

Avaliação de cada quadro `i` (em ordem, 0..3):

1. **Neutro** se o quadro não tem cenário, tem menos de 2 personagens, ou
   (`i > 0` e o quadro `i-1` é Neutro — vazio ou incompleto). Isso cascateia:
   quadros depois de um incompleto ficam neutros até ele ser preenchido.
   Resultado: fundo `default`, poses `default`, `state = NEUTRAL`, sem som.
2. Senão, se casa com um momento considerando o momento do quadro anterior
   → **Coerente** com as poses/fundo/som do momento:
   - Escritório + Ada + Charles: `i == 0` → M1; anterior M1 → M2;
     anterior M3 → M4.
   - Cozinha + Charles + Bule: anterior M2 → M3.
3. Senão → **Dúvida**: fundo `default`; Ada usa `doubt` (se presente); demais
   personagens usam `default`; som `hmmmm` se Ada está no quadro, senão `hmms`;
   ícone "?" sobre o quadro.

O momento "anterior" é sempre o do quadro imediatamente anterior
(`i - 1`). Um quadro neutro ou em dúvida não fornece momento, então o quadro
seguinte, se completo, fica em Dúvida (ex.: Escritório + Ada + Charles depois
de uma Cozinha incoerente; Escritório após M2, que pularia a cozinha). A
exceção é o anterior Neutro, que deixa o quadro Neutro pela regra 1.

**Solução:** `is_solved(board)` ⇔ os momentos dos quadros 0..3 são exatamente
`[M1, M2, M3, M4]`.

**Som de momento** toca somente quando o estado/momento de um quadro **muda**
(não a cada reavaliação). O mesmo vale para o som de dúvida.

## Arquitetura

### Dados (Resources)

- `CharacterData`: `id`, `display_name`,
  `poses: Dictionary[String, Texture2D]` (`"default"` obrigatório).
  Remove `sprite_normal`, `sprite_shocked`, `sprite_sad`.
- `SceneData`: `id`, `display_name`,
  `variants: Dictionary[String, Texture2D]` (`"default"` obrigatório).
  Remove `background`.
- `StoryData`: `id`, `title`, `number_of_frames`, `draggable_items`,
  `logic: Script`. Remove `correct_answers`.
- Removidos: `CorrectAnswerRow`, `CorrectAnswerData`.

Dados da fase (`data/`):

| Recurso | Chave → arquivo |
|---|---|
| `characters/ada.tres` | `default` → Ada Lovelace default; `pen` → Ada Lovelace com Caneta de pena; `pen_articles` → Ada com Caneta e Artigos; `pile` → Ada Lovelace com os artigos dos lados; `doubt` → Ada Lovelace com dúvida; `laughing` → Ada rindo |
| `characters/charles.tres` | `default` → Charles Default; `clipboard` → Charles com Prancheta de artigos; `cup` → Charles com xícara; `scared_cup` → Charles Assustado com a xícara; `laughing` → Charles Rindo |
| `characters/teapot.tres` | `default` → placeholder (`assets/sprites/characters/teapot_placeholder.png`) |
| `scenes/office.tres` | `default` → scenario_phase1_office; `open_door` → scenario_phase1_officeopendoor; `papers` → scenario_phase1_officewithpapers |
| `scenes/kitchen.tres` | `default` → scenario_phase1_kitchen |
| `stories/lovelace_notes.tres` | título "As notas de Lovelace", 4 quadros, itens [Ada, Charles, Bule, Escritório, Cozinha], `logic = lovelace_logic.gd` |

O placeholder do bule é uma PNG simples gerada (silhueta/retângulo com
"Bule"), substituível depois sem mudar código.

### Lógica (classes puras, `RefCounted`, em `core/story_logic/`)

- `FrameContent`: `scene: SceneData`, `left: CharacterData`,
  `right: CharacterData`; `is_empty()`, `has_character(id)`,
  `character_count()`.
- `FrameResult`: `state` (`NEUTRAL` / `COHERENT` / `DOUBT`), `moment: String`
  (`""` se não coerente), `scene_variant: String`, `left_pose: String`,
  `right_pose: String`, `sounds: Array[AudioStream]`.
- `EndingData`: `frame_index: int`, `scene_variant`, `left_pose`,
  `right_pose` — resolvidos pelo id do personagem em cada lado —,
  `sounds: Array[AudioStream]`.
- `StoryLogic` (base): `evaluate(board: Array[FrameContent]) ->
  Array[FrameResult]`, `is_solved(board) -> bool`,
  `ending(board) -> EndingData`.
- `LovelaceLogic extends StoryLogic`: regras acima; sons por `preload`.

### Nós

- `ComicFrame`
  - Mantém drag & drop atual (entrada/remoção de cenário e personagens).
  - Novo sinal `contents_changed`, emitido após qualquer entrada/remoção.
  - `get_content() -> FrameContent`.
  - `apply_result(result: FrameResult)`: resolve textura em
    `current_scene.variants` / `character.poses` (fallback `default`); só
    troca (com fade) se a textura mudou; mostra/oculta o ícone "?"
    (`DoubtIcon`, novo nó).
  - `set_interactive(enabled)`: desliga drag/drop durante o desfecho.
  - `highlight()`: pulso de destaque usado na recapitulação.
  - `FrameStoryLogic` é removido (nó e script).
- `GameScreen`
  - Instancia a lógica a partir de `story.logic`.
  - Conecta `contents_changed` de cada quadro → `_evaluate_board()`:
    coleta conteúdos, chama `evaluate`, aplica resultados, toca sons de
    quadros cujo `(state, moment)` mudou, e chama `_play_ending()` se
    `is_solved`.
  - `_play_ending()`: bloqueia interação (quadros e prateleira),
    destaca quadros 0..3 com `camera-sound` a cada ~0,6 s, aplica o
    `EndingData` no quadro final (risadas), mostra painel
    "Fase concluída" + `bell-sound` + botão "Voltar ao menu".
  - Sinal `back_to_menu_requested`; `load_story()` reinicia o tabuleiro e
    esconde o painel.
- `ScreenManager`
  - Conecta `back_to_menu_requested` → virada para trás.
  - Recarrega a história ao virar para o jogo.
  - Sons `book-opening` (ida) e `book-closing` (volta).
- `DraggableItem`: label continua; nenhum outro ajuste necessário.
- `SoundPlayer` (autoload novo, `common/sound_player.gd`): pool de
  `AudioStreamPlayer` (ex.: 6), `play(stream)` usa o primeiro livre.
  Drop de item no quadro toca `cartoon_boing`.

### Mapa de áudio (`assets/sounds/`)

| Evento | Arquivo |
|---|---|
| Item solto no quadro | `freesound_community-cartoon_boing-92413.mp3` |
| M1 | `floraphonic-rustling-bushes-dried-leaves-6-230205.mp3` |
| M2 | `u_xg7ssi08yr-writing-with-pencil-371358.mp3` |
| M3 | `freesound_community-pouring-tea-70635.mp3` |
| M4 | `universfield-male-surprise-reaction-242637.mp3` + `vidro-quebrando.mp3` |
| Dúvida c/ Ada | `voiceofruthie-hmmmm-338158.mp3` |
| Dúvida s/ Ada | `freesound_community-hmms-various-1-7175.mp3` |
| Recapitulação | `alex_jauk-camera-sound-236021.mp3` |
| Risadas | `freesound_community-woman_laughs-37559.mp3` + `floraphonic-man-laughs-2-190296.mp3` |
| Fase concluída | `soundreality-bell-sound-effect-613873.mp3` |
| Virar página → jogo | `soumages-book-opening-345808.mp3` |
| Virar página → menu | `oxidvideos-book-closing-466850.mp3` |

### Limpeza

Remover: `data/characters/king.tres`, `data/characters/monster.tres`,
`data/scenes/throne.tres`, `data/scenes/laboratorio.tres`,
`data/stories/default_story.tres`, `assets/sprites/rei/`,
`assets/sprites/character/king/`, `assets/sprites/scenes/laboratorio.png`,
`core/resources/CorrectAnswerRow.gd`, `core/resources/correct_answer_data.gd`,
`src/comic_frame/frame_story_logic.gd`. `GameScreen` passa a usar
`lovelace_notes.tres`.

## Erros e casos-limite

- Pose/variante inexistente no dicionário → usa `default`; se nem `default`
  existir, textura `null` (e `push_warning`).
- `story.logic` nulo → `GameScreen` não avalia (quadros ficam neutros) e emite
  `push_warning`.
- Reavaliações durante o desfecho são ignoradas (interação bloqueada).
- Dois personagens iguais no mesmo quadro (ex.: Ada nos dois lados) → não casa
  momento → Dúvida.

## Testes

`tests/test_lovelace_logic.gd` (`extends SceneTree`), rodado com
`godot --headless --script res://tests/test_lovelace_logic.gd`; sai com código
≠ 0 em falha. Casos:

1. Solução completa → resultados M1..M4, `is_solved == true`.
2. Lados invertidos em todos os quadros → mesmos momentos.
3. Quadro só com cenário / um personagem → NEUTRAL.
4. Q2 completo com Q1 vazio → Q2 NEUTRAL; com Q1 só com cenário → Q2
   NEUTRAL; Q3 completo com Q1 incompleto e Q2 completo → Q3 NEUTRAL.
5. Ada + Charles na Cozinha → DOUBT.
6. Cozinha + Charles + Bule no Q2 com Q1 = M1 → DOUBT.
7. Escritório + Ada + Charles após M2 → DOUBT.
8. Qualquer quadro errado na solução → `is_solved == false`.
9. Fundos/poses por momento (ex.: M2 → `open_door`, Ada `pen_articles`).

Visual/áudio (fades, recapitulação, painel, sons, virada de página):
verificação manual rodando o jogo.

## Fora de escopo

Fases 2+, seleção de fases, salvar progresso, arte final do bule,
localização, regras em Resources editáveis.
