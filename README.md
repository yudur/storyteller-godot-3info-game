# Storyteller SNCT — 3 Info

Um jogo de montar história em quadrinhos, feito para visitantes de feira de
ciências (SNCT). O jogador arrasta personagens e cenários para quatro quadros
e **o jogo descobre o resto**: que pose cada personagem faz e como o cenário
aparece saem do contexto, não de uma escolha do jogador.

Feito em Godot 4.5 / GDScript.

## A ideia central

A prateleira só tem peças "puras" — *Ada*, *Charles*, *Bule de chá*,
*Escritório*, *Cozinha*. Não existe carta de "Ada com uma caneta" nem
"Escritório com a porta aberta".

Quem decide isso é o **contexto**: o que está no quadro e o que estava no
quadro anterior. Escritório + Ada + Charles no primeiro quadro é a entrega dos
artigos, então Ada ganha a caneta de pena e Charles a prancheta. Os mesmos três
no quadro seguinte são a saída, então a porta do escritório aparece aberta e
Ada já está com os artigos na mão. A mesma peça, em outro lugar da história,
vira outra imagem.

Como o público é de feira e não há tutorial, o jogo responde a cada mudança sem
botão de "conferir":

| Estado | Quando | O que o jogador vê |
|---|---|---|
| **Neutro** | quadro vazio, incompleto, ou depois de um incompleto | poses e fundos padrão, nenhum som |
| **Coerente** | o quadro casa com um momento da história | as poses do momento, o fundo certo e um som |
| **Dúvida** | o quadro está completo mas não faz sentido ali | um "?" sobre o quadro e Ada com cara de dúvida |

Quadro incompleto não pune: ele e os seguintes só ficam neutros, esperando.

## Fase 1 — "As notas de Lovelace"

Ada Lovelace entrega a Charles Babbage os artigos que traduziu e anotou. A
história certa é esta sequência:

| | Momento | O que precisa estar no quadro |
|---|---|---|
| 1 | **Entrega** | Escritório + Ada + Charles |
| 2 | **Saída** | Escritório + Ada + Charles, depois da Entrega |
| 3 | **Chá** | Cozinha + Charles + Bule, depois da Saída |
| 4 | **Susto** | Escritório + Ada + Charles, depois do Chá |

Lado não importa: Ada pode estar à esquerda ou à direita, a pose vai para o
lado onde ela estiver. Montados os quatro na ordem, um desfecho recapitula a
história quadro por quadro, o último vira Ada e Charles rindo, toca um sino e o
jogo volta ao menu com o capítulo marcado como concluído.

As marcas de capítulo valem **por visitante**: voltar à tela inicial as apaga,
para o próximo da fila encontrar o menu limpo. Nada é gravado em disco.

## Como rodar

Precisa do executável do Godot 4.5 (testado com 4.5.1).

```sh
godot --path .
```

A cena principal é `src/screen_manager/screen_manager.tscn`. O fluxo é
**tela inicial → menu de capítulos → jogo**, e cada transição é uma virada de
página de verdade, feita com shader sobre dois `SubViewport`.

## Executáveis

As builds não ficam no repositório. Elas são geradas sob demanda por dois
workflows do GitHub Actions, um por plataforma:

| Workflow | Preset usado | Artifact |
|---|---|---|
| **Build Windows** | `Windows Desktop` | `storyweavers-windows` |
| **Build Linux** | `Linux` | `storyweavers-linux` |

Para gerar: aba **Actions** → escolha o workflow → **Run workflow** → branch
`master`. Quando terminar, o `.zip` aparece anexado àquela execução, em
*Artifacts*.

São manuais de propósito (`workflow_dispatch`). Cada execução baixa o engine e
os export templates da release oficial do Godot — cerca de 1,4 GB — e isso não
se justifica a cada commit.

Cada zip traz **um arquivo só**: o `.pck` vai embutido no executável
(`binary_format/embed_pck=true`), então não existe mais o par `.exe` + `.pck`
que parava de funcionar se alguém copiasse só um dos dois.

> **No Linux, refaça o `chmod +x`.** O workflow marca o binário como
> executável, mas o zip de artifact do GitHub perde a permissão no download.

O workflow faz, nessa ordem: baixa o Godot 4.5 headless e os templates, roda
`--headless --import` para gerar o cache de import, e então
`--headless --export-release "<preset>"`. O passo de import não é opcional: o
`.godot/` não é versionado, e sem o cache dele o export não resolve as
referências `uid://` — a cena principal do projeto é uma delas.

### O que não desfazer no `export_presets.cfg`

Três ajustes existem para o CI funcionar, e o editor do Godot pode reverter
sem avisar se você mexer nos presets pela interface:

- **Os dois presets têm nomes diferentes** (`Windows Desktop` e `Linux`). O
  CLI seleciona preset *por nome*; enquanto ambos se chamavam `Storyweavers`,
  não havia como exportar um sem o outro.
- **`application/modify_resources=false`**, no preset do Windows. A `true`, o
  Godot exige o `rcedit` para escrever ícone e versão dentro do `.exe`, e ele
  não existe ao exportar a partir do Linux. Todos os campos que o `rcedit`
  escreveria estão vazios, então nada se perde.
- **`export_path` aponta para `build/`**, que está no `.gitignore`.

Para exportar na sua máquina, os mesmos presets servem — *Projeto → Exportar*
no editor, ou `godot --headless --export-release "Linux"`.

## Testes

Todos os testes rodam headless, sem interface:

```sh
GODOT=/caminho/para/godot sh tests/run_all.sh
```

São 7 arquivos e ~190 asserções, em cerca de um minuto e meio. Sucesso é
`ALL PASSED` em cada um e código de saída 0.

Dois formatos, pela razão explicada no topo do runner: testes que exercitam
só lógica pura herdam de `SceneTree` e rodam com `--script`; os que precisam
de nós e dos autoloads do projeto são cenas `.tscn` e rodam como cena.

> **Atenção ao contar asserções.** `TestUtils.finish` sai com 0 quando um erro
> de script aborta o corpo de um teste, então um arquivo pode "passar" com
> menos checks do que deveria. Confira o número de checks, não só o exit code.

## Estrutura

```
core/resources/     dados como Resources (CharacterData, SceneData, StoryData)
core/story_logic/   as regras, em classes puras (RefCounted), sem nós
src/comic_frame/    o quadro: arrastar, soltar, trocar textura, animar
src/draggable/      as peças da prateleira
src/screens/        tela inicial, menu de capítulos, tela de jogo
src/screen_manager/ navegação e a virada de página
common/             autoloads: SignalBus (drag) e SoundPlayer (pool de áudio)
data/               as fases e seus personagens/cenários, em .tres
assets/             sprites, sons, fontes, shaders, temas
.github/workflows/  os dois workflows de export (Windows e Linux)
tests/              testes headless + run_all.sh
docs/superpowers/   especificações de design e planos de implementação
```

A separação que importa: **as regras não conhecem nós**. `StoryLogic` recebe um
`Array[FrameContent]` e devolve um `Array[FrameResult]` — que pose, que fundo,
que som, que estado. Quem traduz isso em texturas e tweens é o `ComicFrame`, e
quem orquestra o tabuleiro é a `GameScreen`. Por isso as regras de uma fase são
testáveis sem abrir uma janela.

### Modelo de dados

- `CharacterData` — `id`, `display_name`, `poses: Dictionary[String, Texture2D]`
  e `faces_right` (para o personagem ser espelhado e olhar para o centro do
  quadro).
- `SceneData` — `id`, `display_name`, `variants: Dictionary[String, Texture2D]`.
- `StoryData` — `id`, `title`, `number_of_frames`, `draggable_items` e `logic`,
  o script de regras da fase.

A chave `"default"` é obrigatória em todo dicionário de poses e variantes: uma
chave que não existe cai para ela.

## Adicionar um capítulo

1. Crie os `.tres` dos personagens e cenários novos em `data/`, com os
   dicionários de poses e variantes.
2. Escreva as regras como uma subclasse de `MomentLogic` em `core/story_logic/`,
   declarando `_solution()` (a sequência de momentos), `_moments()` (a tabela de
   pose e variante por momento), `_match_moment()` e `ending()`. A cascata de
   quadros neutros e a regra de dúvida já vêm da base — **não as reescreva**;
   sobrescreva só o `_doubt()` se alguma peça tiver cara de dúvida.
3. Crie o `.tres` da fase em `data/stories/`, apontando `logic` para esse
   script e listando as peças em `draggable_items`.
4. Acrescente a fase ao array `stories` em
   `src/screens/menu_screen/menu_screen.tscn` — **a ordem do array é a ordem
   dos capítulos no menu**.
5. Teste as regras headless, no modelo de `tests/test_lovelace_logic.gd`, antes
   de abrir o jogo.

## Documentação de design

As decisões de cada etapa estão escritas, com o porquê, em
`docs/superpowers/specs/`, e os planos de implementação correspondentes em
`docs/superpowers/plans/`. Vale ler antes de mexer nas regras de uma fase ou na
navegação entre telas.
