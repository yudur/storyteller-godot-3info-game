# Fase 2 — "Tatiana Sampaio ajuda um cadeirante" — Design

Data: 2026-10-25
Fonte: `level_design.txt` (fase 2) e os sprites em `assets/sprites/characters/`
Continua: `docs/superpowers/specs/2026-10-25-fase1-lovelace-design.md`

## Objetivo

Implementar a segunda fase jogável: um cadeirante chega ao hospital, Tatiana
Sampaio lê seus exames, analisa a proteína polilaminina no laboratório, aplica
a proteína nele, e ele volta a andar. Três quadros, o mesmo verbo da fase 1 —
arrastar peças puras e deixar o contexto escolher poses e variações de cenário.

Público: o mesmo visitante de feira (SNCT), sem tutorial. Por isso a fase 2 não
inventa regra nova: quem aprendeu a fase 1 joga esta sem reaprender nada.

Sucesso: os três quadros montados como M1→M2→M3 disparam o desfecho em que o
cadeirante fica de pé; quadros incoerentes mostram dúvida; a fase aparece como
"Capítulo 2" no menu.

## Adaptações do level design

O texto original pede coisas que o tabuleiro não expressa. Um quadro comporta
um cenário e **duas** peças, e o `level_design.txt` pede quatro em dois cards.
As adaptações, com o porquê:

1. **Objetos viram peças só onde há desafio.** No Card 2 o microscópio e a
   lâmina são arrastáveis (como o Bule de chá já é na fase 1). Nos Cards 1 e 3
   os objetos — exames, injeção — vivem **dentro das poses**, que é como a
   caneta da Ada já funciona. O texto diz "na cena normal ela não está lendo":
   isso é exatamente o contexto escolhendo a pose.
2. **No Card 2, Tatiana faz parte do cenário.** Como os dois slots ficam com o
   microscópio e a lâmina, ela não cabe como peça nesse quadro. O laboratório
   tem duas variantes e é a postura dela que muda.
3. **"Ordem certa" vira "os dois instrumentos presentes".** O texto pede o
   microscópio e a lâmina na ordem certa no balcão. Na fase 1 o lado **nunca**
   importa, e um "?" não ensina para que lado trocar — o visitante ficaria com
   as duas peças certas no quadro certo e nenhuma pista, em trinta segundos de
   interação. O desafio do card passa a ser perceber que o laboratório pede os
   dois instrumentos.
4. **O Card 3 acontece no hospital.** O texto não dá cenário; o contexto (ele
   lê a pesquisa, ela aplica a injeção) pede o mesmo hospital do Card 1.
5. **`Tatiana aplicando injeção no cadeirante.png` fica fora dos slots.** É um
   sprite com os dois personagens, e o motor desenha um por lado. Fica guardado
   como arte de referência do desfecho.
6. **Três quadros não são adaptação:** `StoryData.number_of_frames` já é
   configurável por fase.
7. **Sem mapa de áudio.** Os sons por momento foram removidos do jogo no commit
   `1179482`; hoje só tocam os cliques de câmera da recapitulação e o sino.

## Decisões

1. **A gramática de avaliação é extraída, não copiada** — as duas fases passam
   a compartilhar uma base e a declarar só a sua tabela de momentos.
2. **Cards 1 e 3 têm as mesmas peças no mesmo cenário**, distinguidos apenas
   pelo momento anterior — o mesmo recurso que a fase 1 usa três vezes com
   Escritório + Ada + Charles.
3. **Lado não importa em lugar nenhum**, como na fase 1.
4. **Tatiana é quem mostra dúvida.** No Card 2 não há personagem com cara para
   fazer, então aparece só o "?" — igual à cozinha sem a Ada.
5. **A arte que falta entra como placeholder gerado**, substituível por arquivo
   sem mudar código, como foi feito com o Bule de chá.

## Arquitetura

### A gramática compartilhada (`MomentLogic`)

Nasce `core/story_logic/moment_logic.gd`, `MomentLogic extends StoryLogic`, com
o que hoje está na `LovelaceLogic` e não é da Ada:

- `evaluate(board)` — percorre os quadros mantendo o resultado anterior.
- `is_solved(board)` — tamanho do tabuleiro e momentos iguais a `_solution()`.
- `_evaluate_frame(content, index, previous)` — neutro se o quadro não tem
  cenário, tem menos de duas peças, ou o anterior é neutro; senão tenta casar
  um momento; senão dúvida.
- `_coherent(content, moment)` — lê `_moments()` e aplica variante e poses por
  id de peça, com `default` para quem não estiver na tabela.
- `_doubt(content)` — padrão: todas as peças em `default`, só o "?" aparece.
- `_has_pair(content, first_id, second_id)`.

Cada fase implementa:

```gdscript
func _solution() -> Array                                        # ["M1", ...]
func _moments() -> Dictionary                                    # momento -> {variant, poses}
func _match_moment(content, index, previous_moment: String) -> String
func ending(board: Array[FrameContent]) -> EndingData
```

e sobrescreve `_doubt` quando alguma peça tem cara de dúvida.

Duas mudanças de forma, ambas deliberadas:

- **`const` vira método.** O GDScript resolve constante no escopo léxico de
  quem escreve a linha, então um `is_solved` na base que citasse `SOLUTION`
  pegaria a da base, nunca a da subclasse. As constantes continuam `const`
  dentro de cada fase; `_solution()` e `_moments()` só as expõem.
- **`_match_moment` recebe `previous_moment: String`**, não o `FrameResult`
  inteiro. Hoje a primeira coisa que ele faz é extrair o `.moment` de dentro.

`LovelaceLogic` encolhe para `_solution`, `_moments`, `_match_moment`, `_doubt`
(a Ada) e `ending`, **sem mudança de comportamento**. Os 50 checks de
`tests/test_lovelace_logic.gd` cobrem exatamente a cascata que está sendo
movida e não mudam: são eles a rede da extração.

### As regras da fase 2 (`TatianaLogic`)

`core/story_logic/tatiana_logic.gd`, `TatianaLogic extends MomentLogic`.

Peças da prateleira, com id e nome de exibição:

| Id | Tipo | Nome |
|---|---|---|
| `patient` | `CharacterData` | Cadeirante |
| `tatiana` | `CharacterData` | Tatiana Sampaio |
| `microscope` | `CharacterData` | Microscópio |
| `slide` | `CharacterData` | Lâmina |
| `hospital` | `SceneData` | Hospital |
| `lab` | `SceneData` | Laboratório |

Microscópio e lâmina são `CharacterData` porque ocupam slot e precisam contar
para "quadro completo" — exatamente como o Bule de chá.

Momentos:

| Momento | Condição | Variante | Poses |
|---|---|---|---|
| M1 Diagnóstico | Hospital + Cadeirante + Tatiana, em `index == 0` | `default` | `patient` `default`, `tatiana` `exams` |
| M2 Análise | Laboratório + Microscópio + Lâmina, anterior M1 | `observing` | ambos `default` |
| M3 Tratamento | Hospital + Cadeirante + Tatiana, anterior M2 | `default` | `patient` `hopeful`, `tatiana` `syringe` |

`_match_moment`:

```
if scene == "hospital" and tem patient e tatiana:
	index == 0            -> "M1"
	previous_moment == "M2" -> "M3"
elif scene == "lab" and tem microscope e slide:
	previous_moment == "M1" -> "M2"
senão -> ""
```

`_solution()` é `["M1", "M2", "M3"]`.

`_doubt` dá a pose `doubt` a `tatiana` quando ela está no quadro; as demais
peças ficam em `default`.

**Desfecho.** `frame_index = 2`, `scene_variant = "default"`, sem sons. Ao
contrário da fase 1, as duas poses são **diferentes**, e `ComicFrame.apply_ending`
aplica `left_pose` a quem estiver à esquerda. Por isso `ending(board)` inspeciona
o último quadro: o lado que tem `patient` recebe `cured`, o lado que tem
`tatiana` recebe `happy`. Devolve `null` se a fase não estiver resolvida.

### O laboratório

`lab/default` é o laboratório com Tatiana sentada e o balcão vazio.
`lab/observing` é o mesmo laboratório com ela debruçada no microscópio. O
microscópio e a lâmina são desenhados nos slots, sobre o balcão, nos **dois**
estados — assim o fundo nunca desenha um microscópio que já está no slot, e não
aparecem dois.

## Dados

Recursos novos em `data/`:

| Recurso | Chaves |
|---|---|
| `characters/patient.tres` | `default`, `hopeful`, `cured` |
| `characters/tatiana.tres` | `default`, `exams`, `syringe`, `doubt`, `happy` |
| `characters/microscope.tres` | `default` |
| `characters/slide.tres` | `default` |
| `scenes/hospital.tres` | `default` |
| `scenes/lab.tres` | `default`, `observing` |
| `stories/tatiana_protein.tres` | "Tatiana Sampaio ajuda um cadeirante", 3 quadros, as seis peças, `logic = tatiana_logic.gd` |

A fase entra no array `stories` de `src/screens/menu_screen/menu_screen.tscn`
**depois** da fase 1, e vira "Capítulo 2" pela ordem do array.

### Arte

Três dos quatro PNGs desenhados entram direto, renomeados para o padrão do
projeto (minúsculas, sem acento nem espaço — um deles hoje é
`Cadeirante curado .png`, com espaço antes do ponto, que quebra em caminho
`res://` cedo ou tarde):

| Pose | Arquivo de origem |
|---|---|
| `patient` `default` (serve também para o M1: ele já está cabisbaixo) | `Cadeirante default.png` |
| `patient` `cured` | `Cadeirante curado .png` |
| `tatiana` `syringe`, e `happy` no desfecho | `Tatiana Sampaio com seringa e exames.png` |

`Tatiana aplicando injeção no cadeirante.png` não é usada nos slots.

Entram como placeholder gerado, com o nome da peça escrito na imagem:
`tatiana` `default`, `exams` e `doubt`; `patient` `hopeful`; `microscope`
`default`; `slide` `default`; `hospital` `default`; `lab` `default` e
`observing`. São 9 arquivos, e trocar qualquer um depois não mexe em código.
`Tatiana usando microscópio.png`, na raiz, é a referência visual do
`lab/observing`.

## Erros e casos-limite

- Pose ou variante inexistente cai para `default` — comportamento que
  `CharacterData.get_pose` e `SceneData.get_variant` já têm.
- Hospital + Cadeirante + Tatiana no card 2 (depois do M1) não casa momento
  nenhum: M3 exige anterior M2. Resultado: dúvida.
- Laboratório + Microscópio + Lâmina no card 1 não casa: M2 exige anterior M1.
  Resultado: dúvida.
- Laboratório com só um instrumento conta como quadro incompleto, logo neutro,
  e os quadros seguintes cascateiam para neutro como na fase 1.
- Mesma peça nos dois lados (dois microscópios) não forma par: dúvida.
- Com dois capítulos no menu, concluir o capítulo 1 deve marcar o capítulo 1.
  É o que torna real a guarda de `_on_phase_selected` no `ScreenManager`, até
  aqui exercitada só por um teste sintético.

## Testes

Comandos no `README.md`; a suíte roda com `GODOT=... sh tests/run_all.sh`.

- **A extração não ganha teste novo.** Ela é coberta por
  `tests/test_lovelace_logic.gd`, que não muda. Esse é o motivo de extrair
  agora e não depois.
- `tests/test_tatiana_logic.gd` (novo) cobre só a tabela da fase 2: os três
  momentos com suas variantes e poses; `is_solved` na solução; lados invertidos
  dando os mesmos momentos; laboratório sem a lâmina ficando neutro e
  cascateando; hospital no card 2 e laboratório no card 1 dando dúvida;
  `tatiana` recebendo a pose `doubt` e o microscópio não; e o `ending` pondo
  `cured` e `happy` em cada lado certo, **inclusive com as peças invertidas**.
- `tests/test_phase_data.gd` ganha as asserções dos sete recursos novos.
- `tests/test_menu.gd` passa a esperar **dois** capítulos: "Capítulo 2" existe
  com o título da fase 2, e concluir o capítulo 1 marca o capítulo 1 e não o 2.

Verificação manual, rodando o jogo: a fase abre pelo menu, as três montagens
trocam poses e a variante do laboratório, e o desfecho põe o cadeirante de pé.

## Fora de escopo

Fases 3+, momentos declarados em Resources editáveis no inspetor, sons por
momento (removidos do jogo), a arte definitiva das 8 imagens em placeholder, e
qualquer mudança no modelo de quadro (cenário + duas peças continua como está).
