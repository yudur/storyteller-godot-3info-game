# Fluxo de telas e progresso de capítulos — Design

Data: 2026-10-25
Continua: `docs/superpowers/specs/2026-10-25-fase1-lovelace-design.md`

## Objetivo

Colocar a `MenuScreen` (já escrita, ainda não ligada em nada) no fluxo do jogo,
que passa a ser **`StartScreen` → `MenuScreen` → `GameScreen`**, com um botão de
voltar no canto superior esquerdo de cada tela. O primeiro capítulo do menu é a
fase da Ada. O desfecho da fase 1 perde os áudios de risada e mantém só o sino.

Público: visitantes de feira (SNCT) que se revezam no mesmo jogo aberto. Daí a
regra de progresso: o visto de capítulo concluído vale por visitante, não pelo
dia inteiro.

Sucesso: o visitante atravessa as três telas nos dois sentidos sem travar nem
piscar; concluir a fase o devolve ao menu com o capítulo 1 marcado; voltar à
tela inicial apaga a marca para o próximo da fila.

## Decisões

1. **Viewports por papel, não por identidade** — os dois `SubViewport` deixam
   de ser "a inicial" e "o jogo" e passam a ser "quem sai" e "quem entra",
   alternando a cada virada.
2. **Lista ordenada e índice, sem pilha** — o fluxo é linear, então "tela
   anterior" é `_current_index - 1`.
3. **Telas estacionadas** — as três são instanciadas uma vez cada sob um nó
   `Screens`; quem não está em cena fica ali, na árvore mas fora de qualquer
   viewport, portanto sem renderizar.
4. **Botão dentro da tela** — cada tela desenha o seu botão e emite
   `back_requested`; só o `ScreenManager` sabe para onde se volta. A
   `StartScreen` não tem botão (não há tela anterior); quem quer sair usa o
   "Sair" que já existe nela.
5. **O visto é progresso, não seleção** — a linha do capítulo vira um `Button`
   com `icon`: clicar entra na fase, e a marca é só qual textura está no ícone.
6. **Progresso na `MenuScreen`**, em memória, zerado ao navegar **para** a tela
   inicial. Nada é gravado em disco.
7. **Capítulos declarados**, não varridos — `@export var stories` preenchido na
   cena, em vez de listar `data/stories/` por ordem alfabética.
8. **Desfecho sem risadas** — `EndingData.sounds` fica vazio na fase 1; as poses
   `laughing` continuam.

## Arquitetura

### `ScreenManager`

Invariante: **o viewport da frente contém a tela visível; o de trás contém a
tela que está entrando.** Quais dos dois são frente e trás alterna a cada
virada, e é isso que permite uma terceira tela sem um terceiro viewport.

```gdscript
enum Screen { START, MENU, GAME }

var _screens: Array[Control]          # [start_screen, menu_screen, game_screen]
var _current_index := Screen.START
var _front := 0                       # índice em _containers/_viewports/_meshes
var _back := 1
```

`_containers`, `_viewports` e `_meshes` são arrays de dois elementos montados
no `_ready`, na ordem em que já existem na cena (`ScreenViewportContainer` /
`PageFlipMesh` primeiro, `NextScreenViewportContainer` / `NextPageFlipMesh`
depois). O `setup()` das malhas continua amarrando cada malha à textura do seu
viewport uma única vez — o que alterna é qual par está no papel de saída.

`navigate_to(index: int) -> void`:

1. Ignora se `_is_flipping`, se `index == _current_index`, ou se `index` está
   fora de `[0, _screens.size())`.
2. `_flip_direction = 1.0 if index > _current_index else -1.0` — a direção só
   governa a **geometria** do giro, não mais quem sai e quem entra.
3. Se a tela que sai é a `GAME` → `game_screen.cancel_ending()`.
4. Se a tela que entra é a `GAME` e tem `story` → `game_screen.load_story(...)`.
5. Se a tela que entra é a `START` → `menu_screen.reset_progress()`.
6. Estaciona em `Screens` o que estiver no viewport de trás e move
   `_screens[index]` para ele. **Uma reparentação por navegação, antes da
   animação** — o viewport tem um frame inteiro para renderizar a tela nova
   antes de aparecer, então não há o flash de um frame que haveria se a
   reparentação acontecesse no fim.
7. `_viewports[_back].render_target_update_mode = UPDATE_ALWAYS`.
8. Roda a virada como hoje (`begin_flip`, tween de `0 → 1` em `flip_duration`).
   O `physical_page` (o papel físico, terceira malha) não entra nessa troca de
   papéis: ele só depende da direção, então continua sendo dirigido exatamente
   como hoje.
9. `_finish_flip`: troca `_front` e `_back`, `_current_index = index`, o novo
   viewport de trás volta a `UPDATE_DISABLED`, containers e malhas voltam ao
   estado de repouso.

Simplificações que caem fora junto:

- `_current_is_start: bool` → `_current_index: int`.
- `_apply_flip_progress` perde o `if` de direção: a malha da frente anda
  `progress` e a de trás anda `1.0 - progress` invertida, sempre.
- `_set_content_layers` passa a receber "a de saída está na frente?" em vez de
  deduzir pela direção.
- O container que entra recebe o fade `smoothstep(0.5, 0.85, progress)` em
  **toda** virada. Hoje a virada para trás não tem esse fade; passar a ter é
  mudança visual intencional, conferida rodando o jogo.
- `flip_page_next`, `flip_page_back` e os botões `FlipBackButton` /
  `FlipNextButton` ("Testar virada...") são removidos; `navigate_to` os
  substitui.
- O `get_node_or_null("StartScreen")` com `has_signal` vira referência tipada,
  porque a tela passa a ter `class_name StartScreen`.

### Telas

| Tela | Sinais que emite | Botão no canto superior esquerdo |
|---|---|---|
| `StartScreen` | `start_requested` | nenhum |
| `MenuScreen` | `phase_selected(story)`, `back_requested` | "< Voltar" |
| `GameScreen` | `story_completed(story)`, `back_requested` | "< Voltar" |

`start_requested` agora leva ao **menu**, não ao jogo. `StartScreen` ganha
`class_name StartScreen` e perde os stubs vazios de `_ready`/`_process`.

O botão é um `Button` com `assets/themes/button-theme.tres`, texto "< Voltar",
ancorado no topo à esquerda, dentro da árvore da própria tela — ou seja, ele
vira junto com a página, como parte do papel. Na `GameScreen` ele é irmão de
`Content` com `z_index` acima; se colidir com o `Title`, a margem superior de
`Content` sobe.

Na `GameScreen`, `back_to_menu_requested` é renomeado para `back_requested`, e o
fim do desfecho emite **dois** sinais em ordem: `story_completed(story)` e
depois `back_requested`. Assim "concluí o capítulo" e "estou saindo da tela"
são coisas distintas — o botão de voltar emite só o segundo, então sair no meio
da fase não marca nada como concluído.

### `MenuScreen`

```gdscript
@export var stories: Array[StoryData]
signal phase_selected(story: StoryData)
signal back_requested
func mark_completed(story: StoryData) -> void
func reset_progress() -> void
```

- `stories` é preenchido em `menu_screen.tscn` com `lovelace_notes.tres`: é
  assim que "o capítulo 1 é o da Ada" fica dito explicitamente, visível no
  editor. A varredura de `data/stories/` com `DirAccess` sai, junto com o seu
  tratamento de erro.
- Cada linha é um `Button` com `text = "Capítulo N"` (N é a posição em
  `stories` mais 1, então a ordem do array é a ordem dos capítulos),
  `tooltip_text = story.title` e `icon` = `chapter_checkbox_checked.svg` ou
  `chapter_checkbox_unchecked.svg` conforme o progresso. Mantém
  `icon_max_width`, `h_separation` e o tamanho de fonte que já estavam. Saem o
  `theme_type_variation`, o override de estilo de hover e o
  `_on_phase_toggled` com o laço que desmarcava as outras linhas — um `Button`
  não tem estado de marcação para desfazer.
- `pressed` → `phase_selected(stories[index])`.
- `_completed: Dictionary[String, bool]` indexado por `story.id`.
  `mark_completed` liga a chave e troca o ícone daquela linha;
  `reset_progress` limpa o dicionário e devolve todas ao ícone vazio.

### Fiação

| Origem | Ação no `ScreenManager` |
|---|---|
| `StartScreen.start_requested` | `navigate_to(Screen.MENU)` |
| `MenuScreen.phase_selected(story)` | `game_screen.story = story`; `navigate_to(Screen.GAME)` |
| `GameScreen.story_completed(story)` | `menu_screen.mark_completed(story)` |
| `back_requested` de qualquer tela | `navigate_to(_current_index - 1)` |

### Áudio

Em `core/story_logic/lovelace_logic.gd`: as constantes `SOUND_WOMAN_LAUGH` e
`SOUND_MAN_LAUGH` são removidas (não têm outro uso) e `ending()` passa a
`data.sounds.assign([])`. O campo `sounds` do `EndingData` permanece como
interface genérica para outras fases. O sino não é afetado: ele é
`SOUND_BELL` no `GameScreen`, fora do `EndingData`. Os dois `.mp3` de risada
ficam em `assets/sounds/` sem uso, sem serem apagados.

## Erros e casos-limite

- Navegar durante uma virada é ignorado (`_is_flipping`, guarda que já existe);
  cobre dois cliques rápidos num capítulo.
- Voltar durante a recapitulação do desfecho mata o `_ending_tween` e **não**
  emite `story_completed` — a fase não é marcada.
- `navigate_to` fora da faixa é ignorado. Como a `StartScreen` não tem botão,
  isso é guarda, não funcionalidade.
- `stories` vazio deixa o menu sem linhas e emite `push_warning`.
- Capítulo já marcado pode ser jogado de novo e continua marcado.
- Entrar no jogo sem `story` definida (não acontece pelo menu) cai no
  `push_warning` que o `GameScreen` já tem.

## Testes

Scripts `extends SceneTree` rodam com
`"$GODOT" --headless --path . --script res://tests/<arquivo>.gd`; os que
precisam de autoloads e de nós são cenas e rodam com
`"$GODOT" --headless --path . res://tests/<arquivo>.tscn`. Sucesso é a linha
`ALL PASSED` e saída 0.

Mexem:

- `tests/test_lovelace_logic.gd` — `ending.sounds.size()` de 2 para 0.
- `tests/test_ending.gd` — `played.size()` de 7 para 5; as duas asserções de
  que as risadas tocam viram asserções de que **não** tocam (o sino continua
  sendo o último som); as três conexões de `back_to_menu_requested` acompanham
  a renomeação.
- `tests/test_ending.gd::test_screen_manager_navigation` — reescrito para três
  telas: anda `START → MENU → GAME → voltar → voltar`, checa `_current_index` a
  cada passo e checa a invariante (a tela visível está num viewport, as outras
  duas estão estacionadas em `Screens`).

Nasce:

- `tests/test_menu.gd` + `tests/test_menu.tscn` — a lista sai do `stories`
  exportado; "Capítulo 1" com `tooltip_text` igual ao título; `pressed` emite
  `phase_selected` com a fase da Ada; `mark_completed` troca o ícone e
  `reset_progress` desfaz. E a cadeia inteira pelo `ScreenManager`: resolver a
  fase termina **no menu** com o capítulo 1 marcado, e navegar para a tela
  inicial apaga a marca.

Verificação manual (rodando o jogo): o fade novo da virada para trás, a
ausência de piscada ao entrar em cada tela, e o botão "< Voltar" não colidindo
com o título na `GameScreen`.

## Fora de escopo

Capítulo 2 e qualquer conteúdo de fase novo, progresso salvo em disco,
capítulos travados por pré-requisito, transição diferente da virada de página,
e apagar os `.mp3` de risada.
