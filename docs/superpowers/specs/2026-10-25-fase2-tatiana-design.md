# Fase 2 — "Tatiana Sampaio ajuda um cadeirante" — Design

Data: 2026-10-25
Fonte: `level_design.txt` (fase 2) e a arte em `assets/sprites/`
Continua: `docs/superpowers/specs/2026-10-25-fase1-lovelace-design.md`

## Objetivo

Implementar a segunda fase jogável: um cadeirante chega ao hospital, Tatiana
Sampaio lê seus exames, analisa a proteína polilaminina no laboratório, aplica
a proteína nele, e ele volta a andar. Três quadros, o mesmo verbo da fase 1 —
arrastar peças puras e deixar o contexto escolher as poses.

Público: o mesmo visitante de feira (SNCT), sem tutorial. Por isso a fase 2 não
inventa regra nova: quem aprendeu a fase 1 joga esta sem reaprender nada.

Sucesso: os três quadros montados como M1→M2→M3 disparam o desfecho em que o
cadeirante fica de pé; quadros incoerentes mostram dúvida; a fase aparece como
"Capítulo 2" no menu.

## Adaptações do level design

O texto original pede coisas que o tabuleiro não expressa — um quadro comporta
um cenário e **duas** peças, e o `level_design.txt` pede quatro em dois cards.
A arte que já existe também discorda do texto em um ponto. As adaptações, com
o porquê:

1. **Objetos viram peças só onde fazem falta.** No Card 2 a lâmina é
   arrastável (como o Bule de chá já é na fase 1). Nos Cards 1 e 3 os objetos —
   exames, injeção — vivem **dentro das poses**, que é como a caneta da Ada já
   funciona. O texto diz "na cena normal ela não está lendo": isso é exatamente
   o contexto escolhendo a pose.
2. **O microscópio fica no cenário, não é peça.** `scenario_phase2_lab.png` já
   desenha o microscópio sobre a bancada. Se ele também fosse sprite de slot,
   apareceriam dois. As peças do Card 2 passam a ser Tatiana e a lâmina, e é a
   pose dela que muda para "olhando no microscópio" — que é precisamente o que
   `Tatiana usando microscópio.png`, deixada na raiz, mostra.
3. **O desafio do balcão sai.** O texto pede o microscópio e a lâmina na ordem
   certa no balcão. Na fase 1 o lado **nunca** importa, e um "?" não ensina
   para que lado trocar — o visitante ficaria com as peças certas no quadro
   certo e nenhuma pista, em trinta segundos de interação. O desafio do Card 2
   passa a ser perceber que o laboratório pede a Tatiana e a lâmina.
4. **O Card 3 acontece no hospital.** O texto não dá cenário; o contexto (ele
   lê a pesquisa, ela aplica a injeção) pede o mesmo hospital do Card 1.
5. **`Tatiana aplicando injeção no cadeirante.png` fica fora dos slots.** É um
   sprite com os dois personagens, e o motor desenha um por lado. Fica como
   arte de referência do desfecho.
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
4. **A fase 2 não usa variantes de cenário.** Os dois cenários têm só
   `default`; a história inteira é contada pelas poses. A fase 1 usava variantes
   porque a porta do escritório abria; aqui nada no cenário muda.
5. **A dúvida não troca sprite nenhum.** As peças ficam com a imagem normal e
   quem avisa é o "?" no canto do quadro, que o `ComicFrame` já desenha. A fase
   1 é a exceção: a Ada tem uma cara de dúvida desenhada à mão e a mantém.
6. **A arte que falta entra como placeholder gerado**, substituível por arquivo
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

Peças da prateleira:

| Id | Tipo | Nome |
|---|---|---|
| `patient` | `CharacterData` | Cadeirante |
| `tatiana` | `CharacterData` | Tatiana Sampaio |
| `slide` | `CharacterData` | Lâmina |
| `hospital` | `SceneData` | Hospital |
| `lab` | `SceneData` | Laboratório |

A lâmina é `CharacterData` porque ocupa slot e precisa contar para "quadro
completo" — exatamente como o Bule de chá.

Momentos:

| Momento | Condição | Poses |
|---|---|---|
| M1 Diagnóstico | Hospital + Cadeirante + Tatiana, em `index == 0` | `patient` `default`, `tatiana` `exams` |
| M2 Análise | Laboratório + Tatiana + Lâmina, anterior M1 | `tatiana` `microscope`, `slide` `default` |
| M3 Tratamento | Hospital + Cadeirante + Tatiana, anterior M2 | `patient` `hopeful`, `tatiana` `syringe` |

A variante de cenário dos três é `default` (ver Decisão 4).

`_match_moment`:

```
if scene == "hospital" and tem patient e tatiana:
	index == 0              -> "M1"
	previous_moment == "M2" -> "M3"
elif scene == "lab" and tem tatiana e slide:
	previous_moment == "M1" -> "M2"
senão -> ""
```

`_solution()` é `["M1", "M2", "M3"]`.

`_doubt` não é sobrescrito: a fase herda o da base, que deixa todas as peças em
`default`. Num quadro em dúvida ninguém troca de sprite e o "?" do canto do
quadro é o aviso inteiro.

**Desfecho.** `frame_index = 2`, `scene_variant = "default"`, sem sons. Ao
contrário da fase 1, as duas poses são **diferentes**, e `ComicFrame.apply_ending`
aplica `left_pose` a quem estiver à esquerda. Por isso `ending(board)` inspeciona
o último quadro: o lado que tem `patient` recebe `cured`, o lado que tem
`tatiana` recebe `happy`. Devolve `null` se a fase não estiver resolvida.

## Dados

Recursos novos em `data/`:

| Recurso | Chaves |
|---|---|
| `characters/patient.tres` | `default`, `hopeful`, `cured` |
| `characters/tatiana.tres` | `default`, `exams`, `microscope`, `syringe`, `happy` |
| `characters/slide.tres` | `default` |
| `scenes/hospital.tres` | `default` |
| `scenes/lab.tres` | `default` |
| `stories/tatiana_protein.tres` | "Tatiana Sampaio ajuda um cadeirante", 3 quadros, as cinco peças, `logic = tatiana_logic.gd` |

A fase entra no array `stories` de `src/screens/menu_screen/menu_screen.tscn`
**depois** da fase 1, e vira "Capítulo 2" pela ordem do array.

### Arte

Os nomes de arquivo seguem o padrão que o projeto já usa para personagens:
português, com espaços e acentos (`Ada Lovelace com Caneta de pena.png`).
**Nada é renomeado.**

Oito das doze imagens já existem:

| Pose | Arquivo |
|---|---|
| `patient` `default` (serve também para o M1: ele já está cabisbaixo) | `Cadeirante default.png` |
| `patient` `cured` | `Cadeirante curado .png` |
| `tatiana` `default` | `Tatiane Sampaio Default.png` |
| `tatiana` `exams` | `Tatiana Sampaio com exame.png` |
| `tatiana` `syringe` | `Tatiana Sampaio com seringa.png` |
| `tatiana` `happy` (desfecho; ela está sorrindo) | `Tatiana Sampaio com seringa e exames.png` |
| `hospital` `default` | `scenario_phase2_hospital.png` |
| `lab` `default` | `scenario_phase2_lab.png` |

Faltam **três**, que entram como placeholder gerado (PNG com o nome da peça
escrito, no modelo do `teapot_placeholder.png`): `patient` `hopeful`,
`tatiana` `microscope` e `slide` `default`. Trocar qualquer
um depois é substituir o arquivo — nenhuma linha de código muda.

`Tatiana usando microscópio.png`, na raiz, é um quadro montado e serve de
referência visual para a pose `tatiana` `microscope`. Não é usada pelo jogo.
`Tatiana aplicando injeção no cadeirante.png` também não.

## Erros e casos-limite

- Pose ou variante inexistente cai para `default` — comportamento que
  `CharacterData.get_pose` e `SceneData.get_variant` já têm.
- Hospital + Cadeirante + Tatiana no card 2 (depois do M1) não casa momento
  nenhum: M3 exige anterior M2. Resultado: dúvida.
- Laboratório + Tatiana + Lâmina no card 1 não casa: M2 exige anterior M1.
  Resultado: dúvida.
- Laboratório só com a Tatiana conta como quadro incompleto, logo neutro, e os
  quadros seguintes cascateiam para neutro como na fase 1.
- Mesma peça nos dois lados (duas Tatianas) não forma par: dúvida.
- Trocar de capítulo recria o tabuleiro: a fase 1 tem 4 quadros e a fase 2 tem
  3, então `load_story` precisa entregar a contagem certa e a prateleira certa.
- Com dois capítulos no menu, concluir o capítulo 1 deve marcar o capítulo 1.
  É o que torna real a guarda de `_on_phase_selected` no `ScreenManager`, até
  aqui exercitada só por um teste sintético.

## Testes

Comandos no `README.md`; a suíte roda com `GODOT=... sh tests/run_all.sh`.

- **A extração não ganha teste novo.** Ela é coberta por
  `tests/test_lovelace_logic.gd`, que não muda. Esse é o motivo de extrair
  agora e não depois.
- `tests/test_tatiana_logic.gd` (novo) cobre só a tabela da fase 2: os três
  momentos com suas poses; `is_solved` na solução; lados invertidos dando os
  mesmos momentos; laboratório sem a lâmina ficando neutro e cascateando;
  hospital no card 2 e laboratório no card 1 dando dúvida, com as peças
  mantendo o sprite normal e só o "?" avisando; e o `ending` pondo `cured` e
  `happy` em cada lado certo, **inclusive com as peças invertidas**.
- `tests/test_phase_data.gd` ganha as asserções dos seis recursos novos.
- `tests/test_menu.gd` passa a esperar **dois** capítulos: "Capítulo 2" existe
  com o título da fase 2, trocar de capítulo recria o tabuleiro com 3 quadros,
  e concluir o capítulo 1 marca o capítulo 1 e não o 2.

Verificação manual, rodando o jogo: a fase abre pelo menu, as três montagens
trocam as poses, e o desfecho põe o cadeirante de pé.

## Fora de escopo

Fases 3+, momentos declarados em Resources editáveis no inspetor, sons por
momento (removidos do jogo), a arte definitiva das 4 imagens em placeholder,
renomear arquivos de arte, e qualquer mudança no modelo de quadro (cenário +
duas peças continua como está).
