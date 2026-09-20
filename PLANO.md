# FastReport — Plano de produto e desenvolvimento

Aplicação **exclusiva para Mac** para triagem e organização de fotos de trabalho **no Finder**. A app **não guarda um banco de fotos**: o disco é a fonte da verdade. O relatório em si **não** é gerado aqui — só a estrutura de pastas e nomes que torna o relatório futuro rápido.

Idioma deste documento: português. App: **português (padrão)** e **inglês**.

---

## 1. Decisão de stack (a mais recomendada)

### Escolha: Swift + SwiftUI nativo (macOS)

| Camada | Tecnologia | Porquê |
|---|---|---|
| UI | SwiftUI + AppKit pontual | Visual nativo, teclado, menus, fullscreen, drag-and-drop de ficheiros |
| Linguagem | Swift 6 | Simples, seguro, sustentável |
| Ficheiros | `FileManager` + security-scoped bookmarks | A app trabalha em pastas que o utilizador escolhe |
| Imagens | ImageIO / Core Graphics | HEIC/JPEG/PNG → JPEG 1024, orientação correta, miniaturas rápidas |
| Sincronizar com o Finder | FSEvents | Se o utilizador mexer no Finder, a app atualiza |
| i18n | String Catalog (`.xcstrings`) | PT + EN de forma nativa |
| Atualizações | Sparkle 2 + GitHub Releases | Padrão de apps Mac distribuídas fora da App Store |
| CI | GitHub Actions | Build, notarização, release, appcast |

**Não usar** Electron, Tauri ou Flutter neste produto. São válidos para apps multiplataforma; aqui o valor está em teclado, Finder, desempenho com 300+ fotos e aspeto Mac. Já existe um protótipo Flutter em `~/PhotoOrganizer` — **não o continuamos**. FastReport nasce nativo.

**Requisitos mínimos:** macOS 14+, Apple Silicon e Intel (universal). Xcode atual.

**Distribuição:** GitHub Releases + Sparkle (assinatura Developer ID + notarização). App Store fica para uma fase futura, se fizer sentido. Isso terá que ser totalmente gratuito sem nenhum custo.

**Sandbox:** ativado. Pastas só via seletor nativo + bookmark, para reabrir projetos sem pedir de novo.

---

## 2. Conceitos (vocabulário estável)

Usar estes nomes no código, na UI e neste plano. Evita “fluxo / mapa / projeto” misturados.

| Termo | O que é |
|---|---|
| **Mapa** | Receita reutilizável (JSON no bundle da app). Define pastas, atalhos, quantas fotos se espera, padrão de nome. O programador adiciona mapas novos sem reescrever a lógica. |
| **Projeto** | Uma pasta no disco criada a partir de um mapa (ex.: `Inspeção X`). É a unidade de trabalho do dia. |
| **Inbox** | Pasta `Inbox` dentro do projeto. Fotos ainda não classificadas. Na UI: “Sem categoria”. |
| **Slot** | Destino do mapa: `T1`…`T24`, `General`, `Trash`. |
| **Triagem** | Ecrã de uma foto de cada vez, teclado primeiro. |
| **Revisão** | Grelha depois da triagem, uma linha por slot, reordenar e recategorizar. |

O disco **é** o estado. Um ficheiro pequeno `.fastreport.json` na raiz do projeto só guarda: id do mapa, nome apresentado, data de criação, versão do esquema. As fotos não entram na app; só são movidas, convertidas e renomeadas nas pastas do projeto.

---

## 3. Mapa — modelo melhorado

A ideia T1–T24 + General + Trash está certa. O que muda: o mapa deixa de ser código hardcoded e passa a ser **dados versionados**. Trabalho X, Y e Z são só mapas diferentes.

### 3.1 Regras de um mapa

- IDs e **nomes de pasta em inglês estável** (`Inbox`, `T1`, `General`, `Trash`). A UI traduz; o Finder fica previsível se o idioma da app mudar.
- Cada slot tem: `id`, pasta, atalho, `expectedCount` (opcional), se é lixo, se aceita quantidade livre.
- Padrão de ficheiro configurável, ex.: `{project}_{slot}_{index}.jpeg` → `Inspecao1_T10_1.jpeg`.
- Validação **suave**: T1–T24 “devem” ter 7 fotos. Ter 5 ou 9 é permitido; a UI mostra um aviso discreto, não bloqueia.
- `index` é a ordem **dentro daquele slot**, recalculada ao mover ou ao arrastar.

### 3.2 Mapa 1 — Inspeção T24 (primeiro a implementar)

```
{projeto}/
  .fastreport.json
  Inbox/          ← importação e ainda por classificar
  General/        ← atalho 0 + Enter
  Trash/          ← ⌘⌫  (não apaga do disco)
  T1/ … T24/      ← número 1–24 + Enter; esperado: 7 fotos
```

Nomes após classificar: `{slugDoProjeto}_{slot}_{indice}.jpeg`.

`slugDoProjeto` vem do nome que o utilizador deu, normalizado (sem espaços/acentos no ficheiro, ex. `Inspecao1`).

### 3.3 Atalho numérico (a parte mais importante da UX)

Não usar uma tecla só para T1…T9: T10 e T24 ficam impossíveis.

**Buffer + Enter:**

1. Utilizador escreve `1` `0`.
2. Canto superior esquerdo mostra pré-visualização `T10`.
3. **Enter** move a foto, renomeia, avança para a seguinte.
4. `0` + Enter → `General`.
5. Escape limpa o buffer.
6. ⌘⌫ → `Trash` e avança.
7. Setas ← → navegam na Inbox (ou no slot, em revisão).
8. **⌘Z** desfaz o último movimento (obrigatório neste tipo de app).

Números 25+ ou vazios: feedback curto, não move.

### 3.4 Mapas futuros (escala)

Cada mapa novo = um JSON em `Maps/` + entrada no catálogo. Exemplos possíveis mais tarde:

Deve ter uma instrução tecnica de como deve ser criado novos mapas.

- Inspeção com outro número de T’s e outra contagem.
- Mapa só com `Antes` / `Depois` / `Detalhe` / `General`.
- Mapa por zona da obra.

A triagem, a grelha e o import **não mudam** — só o mapa.

---

## 4. Fluxo do utilizador (aperfeiçoado)

### 4.1 Casa

Janela única, limpa:

- Cartão **Organizar fotos** (primeiro recurso; outros recursos no futuro).
- Lista **Projetos recentes** (reabre a pasta via bookmark).
- Barra: Definições.

### 4.2 Novo projeto (assistente curto, 3 passos)

1. **Mapa** — grelha de mapas disponíveis (só um no início).
2. **Onde guardar** — painel nativo do macOS; em seguida o **nome do projeto** (cria `{destino}/{nome}/` com a estrutura do mapa).
3. **Importar** — zona grande para arrastar (ou “Escolher ficheiros”). HEIC, JPEG, PNG, etc.

Não perguntar coisas a mais. Avançar / Voltar claros.

### 4.3 Importação

- Ecrã de progresso em tempo real (miniaturas a aparecer, contador).
- Cada foto: **convertida para JPEG**, lado maior **1024 px**, qualidade alta (~0.90), orientação EXIF aplicada.
- Resultado **movido** para `Inbox/` (não fica cópia na app).
- Originais: o gesto “arrastar para a app” trata-se como **entregar ao projeto**. Conversão substitui o ficheiro **dentro do projeto**. Se o utilizador arrastar de uma pasta de câmara, **copiar → converter na Inbox** (não destruir o rolo original). Se já estiver a importar de uma pasta temporária, pode mover. Regra: **nunca apagar originais fora do projeto**.
- No fim: estatística curta — total, já JPEG, convertidas, falhas (se houver). Sem EXIF, GPS, histogramas.
- Deve ser possivel adiconar mais fotos depois (durante o processo)

### 4.4 Inbox (antes da triagem)

Grelha **discreta**, não 300 miniaturas enormes:

- ~5–7 colunas, miniaturas pequenas, scroll.
- Contador `0 / 300` (classificadas / total excluindo Trash, ou `Inbox restante` — ver métrica abaixo).
- Botão principal: **Iniciar triagem**.
- Secundário: Revelar no Finder.

**Métrica:** `classificadas / (todas − Trash)`. Exemplo: `160/300`. Também mostrar `140 na Inbox` se ainda houver fila. Um número, não um dashboard.

### 4.5 Triagem (ecrã principal)

- Janela própria, **redimensionável**; opção fullscreen (controlo nativo).
- Foto em **contain** (imagem toda visível, fundo escuro). “Preencher e cortar” seria mau para inspeção. Toggle opcional “preencher” para ecrãs muito largos.
- Barra superior fina, ícones só:
  - pasta/slot atual
  - buffer (`T10`)
  - `160/300`
  - rodar 90°
  - lixo
  - mostrar no Finder
  - desfazer
- Clique na foto não deve abrir menus pesados.
- Ao classificar ou deitar fora: **avança já** para a seguinte (sem diálogo).
- Fim da Inbox: volta à grelha em modo **Revisão**.

### 4.6 Revisão (depois de classificar)

Grelha **por linhas**:

1. General  
2. T1 … T24 (só slots com fotos, ou todos os T com placeholder vazio — **mostrar todos os T**, vazios com um traço, para se ver o que falta)  
3. Inbox se ainda restar alguma  
4. Trash colapsado no fundo

Clicar numa miniatura abre triagem **só daquele slot**. Recategorizar com o mesmo buffer + Enter tira a foto da linha e põe na outra; a grelha atualiza.

**Reordenar:** arrastar miniatura na linha, animação de spring curta, índices no nome (`_1`, `_2`, …) atualizam em cadeia. Sem overlays de “a copiar…”.

Aviso discreto no slot: `5/7` ou `9/7` se `expectedCount` não bater.

### 4.7 Retomar

Abrir um projeto recente = ler a pasta. Se a Inbox tiver fotos, oferece **Continuar triagem**. Se estiver vazia, abre **Revisão**. O Finder continua a poder ser usado em paralelo; a app reflete mudanças.

---

## 5. Teclado e controlos (conjunto fechado v1)

| Ação | Atalho |
|---|---|
| Ir para slot T*n* | dígitos `1`–`24` + **Enter** |
| General | `0` + Enter (também `G` + Enter) |
| Limpar buffer | Escape |
| Lixo | ⌘⌫ |
| Anterior / seguinte | ← → |
| Rodar 90° à direita | `R` (⌘R no menu) |
| Desfazer | ⌘Z |
| Fullscreen | o atalho padrão do macOS |
| Sair da triagem | Escape (se buffer vazio) |

Menu nativo: FastReport, Projeto, Foto, Ver, Janela, Ajuda (folha de atalhos). Ícones SF Symbols, o mesmo peso em todo o lado.

---

## 6. Design

- Seguir **Human Interface Guidelines** de macOS: barra de ferramentas nativa, tipografia SF, materiais (sidebar / background), espaçamento 8 pt.
- Uma hierarquia: **um** botão principal por ecrã.
- Pouco texto. Estado com números e ícones, não parágrafos.
- Formulários do assistente: labels em cima, campos largos, erro por baixo do campo.
- Claro/escuro do sistema.
- Sem cores a mais: um acento; vermelho só no lixo; âmbar só no “contagem ≠ esperada”.
- Animações curtas (200–300 ms). Arrastar na grelha deve parecer o Photos da Apple, não um site.

---

## 7. Arquitetura (para crescer sem reescrever)

```
FastReport/
  App/                 ciclo de vida, menus, Sparkle
  Domain/              Project, Map, Slot, PhotoItem (sem UI)
  Maps/                JSON dos mapas + MapCatalog
  Services/
    ProjectStore       criar/abrir, bookmarks, .fastreport.json
    FileOrganizer      mover, renomear, numerar, undo
    ImagePipeline      decode, resize 1024, JPEG, thumbnails
    FolderWatcher      FSEvents
    Localization       idioma da app (override do sistema)
  Features/
    Home
    ProjectWizard
    Import
    InboxGrid
    Triage
    ReviewGrid
    Settings
```

Regras:

- UI não fala com o disco diretamente; só com serviços.
- Mapas são dados. Nova inspeção = JSON novo.
- Undo = pilha de operações de ficheiro (origem, destino, nome antigo/novo).
- Miniaturas em cache de memória + pasta `Inbox/.thumbnails` **não**: cache no `Caches/` da app, chave = path + mtime, para não poluir o Finder.
- Importação em background; UI sempre responsiva.

---

## 8. Definições

Ecrã único, grupos curtos:

1. **Idioma** — Português / English (muda a UI na hora; pastas no disco não mudam).
2. **Imagem** — lado máximo (padrão 1024), qualidade JPEG (padrão Alta). Poucas opções.
3. **Atualizações** — versão atual (`1.0.0 (build 12)`), “Procurar atualizações…”, “Instalar automaticamente” (Sparkle).
4. **Sobre** — nome, copyright, link do repositório.

Mostrar **versão de marketing + build**, não só “Release”. Ex.: `FastReport 1.0.0 (12)` e, se houver update, `1.1.0 disponível`.

---

## 9. Atualizações (GitHub + Sparkle)

1. Código no GitHub (privado ou público).
2. Tag `v1.0.0` gera Release com o `.dmg` (ou `.zip`) **assinado e notarizado**.
3. Ficheiro `appcast.xml` (Sparkle) na Release ou `gh-pages`.
4. A app consulta o appcast ao abrir (e nas Definições).
5. Diálogo nativo Sparkle: o que mudou, descarregar, reiniciar.

GitHub Actions: test → archive → notarize → upload Release → atualizar appcast.

Enquanto não houver certificado Developer ID, a Fase 8 fica com Sparkle **preparado** mas o check pode ser manual; não bloquear as fases de UX.

---

## 10. O que entra extra (vale a pena no v1 ou v1.1)

**v1 (fazer):**

- Undo.
- Copiar originais de fora do projeto (não destruir o cartão/câmara).
- Folha de atalhos.
- Validação 7 fotos por T (aviso).
- Abrir projeto recente.
- “Mostrar no Finder”.
- Ignorar ficheiros que não são imagem no drop.

**v1.1 (logo a seguir, se faltar tempo):**

- Saltar foto (`S`) — fica na Inbox, vai à próxima.
- Zoom na triagem (scroll / trackpad).
- Duplicados óbvios (mesmo hash após JPEG) — aviso, não automático.
- Exportar lista de contagens (txt/csv) para o relatório futuro — ainda não é o relatório, só um resumo.

**Não fazer no início:** nuvem, contas, IA, GPS no mapa, editor tipo Photoshop, partilha social, iPhone companion.

---

## 11. Etapas de desenvolvimento

Cada etapa termina com algo **utilizável no Mac**. Só avançar quando essa etapa estiver estável. Testar com um conjunto real (~300 fotos) a partir da etapa 4.

### Etapa 0 — Fundação

- Projeto Xcode `FastReport`, bundle id estável (ex. `dev.robert.FastReport`).
- SwiftUI App, menu bar mínimo, janela única.
- String Catalog PT (padrão) + EN.
- Definições: idioma a funcionar de ponta a ponta (mesmo que o resto da app ainda seja placeholder).
- Estrutura de pastas da arquitetura, `Map` Codable, um JSON vazio do Mapa 1.
- **Critério:** abrir a app, mudar para English e voltar a Português.

### Etapa 1 — Mapas e criação de projeto

- Catálogo de mapas; UI do passo 1 e 2 do assistente.
- Criar pasta do projeto + subpastas do mapa + `.fastreport.json`.
- Bookmark da pasta.
- **Critério:** escolher mapa, pasta e nome; o Finder mostra a estrutura correta.

### Etapa 2 — Importação e Inbox

- Drop + seletor de ficheiros.
- Pipeline JPEG 1024; progresso; copiar/mover para `Inbox/`.
- Estatística final simples.
- Grelha Inbox com miniaturas (cache).
- **Critério:** largar 50 fotos (incluindo HEIC se possível) e vê-las na Inbox e no Finder, já em JPEG 1024.

### Etapa 3 — Triagem por teclado

- Ecrã de triagem (contain, barra, `n/total`).
- Buffer numérico + Enter, `0`, ⌘⌫, setas, avanço automático.
- Mover + renomear com índice.
- **Critério:** classificar 30 fotos só com o teclado, nomes `Projeto_T10_1.jpeg` corretos no Finder.

### Etapa 4 — Undo, rotação, watcher

- ⌘Z restaura pasta e nome.
- Rodar grava o JPEG.
- FSEvents: apagar/mover no Finder reflete na app.
- **Critério:** classificar, desfazer, rodar, mexer uma foto no Finder, a app não fica dessincronizada.

### Etapa 5 — Revisão por linhas

- Grelha por slot; clique abre triagem daquele slot; recategorizar.
- Badges `n/esperado`.
- Transição Inbox vazia → revisão.
- **Critério:** projeto completo mostra 24 linhas T + General; recategorizar uma foto atualiza linha e nome.

### Etapa 6 — Reordenar por arrastar

- Drag na linha, animação, renumeração em cadeia.
- **Critério:** trocar a 3.ª com a 1.ª em T10; ficheiros passam a `_1`, `_2`, `_3` sem falhas.

### Etapa 7 — Casa, recentes, polimento UX

- Projetos recentes, continuar triagem vs revisão.
- Folha de atalhos, estados vazios, erros de importação.
- Passagem de design (HIG, ícones, espaçamentos, claro/escuro).
- **Critério:** um dia de trabalho simulado, da casa até à revisão, sem cantos por acabar.

### Etapa 8 — Sparkle + GitHub

- Repo, Actions, assinatura quando disponível, appcast.
- Definições: versão, procurar atualizações, diálogo Sparkle.
- **Critério:** Release `v0.1.0` (ou `v1.0.0`) instalada atualiza para a seguinte.

### Etapa 9 — Endurecer

- Testes do `FileOrganizer` e do mapa (não da UI toda).
- 300+ fotos, nomes estranhos, ficheiros bloqueados, disco cheio.
- Notarização / Gatekeeper.
- **Critério:** sessão longa sem perder ficheiros nem índices.

---

## 12. Ordem de trabalho na prática

```
0  Fundação (app + i18n + mapa dados)
1  Criar projeto no disco
2  Importar / converter / Inbox
3  Triagem teclado          ← primeiro “wow”
4  Undo + rodar + Finder
5  Revisão por linhas
6  Drag para ordenar
7  Casa + polimento
8  Updates GitHub
9  Endurecer
```

A etapa 3 é o coração do produto. Tudo o que não servir a classificar 300 fotos em poucos minutos fica para depois.

---

## 13. Riscos e como tratar

| Risco | Mitigação |
|---|---|
| Apagar originais da câmara | Importação de fora do projeto = **cópia** + converter na Inbox |
| T1 vs T10 no teclado | Só confirma com Enter |
| App e Finder ao mesmo tempo | FSEvents + operações atómicas (move, depois rename) |
| iCloud Drive na pasta do projeto | File coordination; evitar projetos em pastas que ainda estão a descarregar |
| Sandbox a bloquear ficheiros | Bookmarks; se falhar, pedir de novo a pasta |
| Sparkle sem certificado | Desenvolver 0–7 na mesma; 8 assim que houver Developer ID |

---

## 14. Fora de âmbito (v1)

- Gerar PDF/Word do relatório.
- Conta, sync, web.
- Editar mapas na UI (no v1 os mapas vêm no bundle; editor de mapas é v2).
- Windows/iOS.

---

## 15. Definição de pronto (v1)

Um utilizador chega com ~300 fotos, cria um projeto com o Mapa Inspeção T24, importa, classifica com teclado, vê a grelha por T, corrige duas fotos, reordena uma linha, e no Finder a estrutura e os nomes estão certos para montar o relatório noutro programa. A app está em PT ou EN, mostra a versão, e (com certificado) atualiza a partir do GitHub.

---

## 16. Próximo passo imediato

Começar a **Etapa 0**: projeto Xcode, i18n, Definições de idioma, esqueleto do Mapa 1 em JSON — ainda sem importar fotos.
