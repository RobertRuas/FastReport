# FastReport — Plano de alinhamento com o padrão Apple

Documento de **execução**. Não altera comportamento de domínio (disco, mapas, import, triagem, undo). Só chrome da janela, menus, controlos, ícones SF Symbols e apresentação.

Produto: `PLANO.md`. Código: `INDEX.md`. Referência de design: [Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars), [The menu bar](https://developer.apple.com/design/human-interface-guidelines/the-menu-bar), [Icons](https://developer.apple.com/design/human-interface-guidelines/icons), [SF Symbols](https://developer.apple.com/sf-symbols/), [Settings](https://developer.apple.com/design/human-interface-guidelines/settings), [Going full screen](https://developer.apple.com/design/human-interface-guidelines/going-full-screen).

Alvo de sistema: **macOS 14+** (`project.yml`). Usar só APIs de 14/15. Aspeto Liquid Glass no macOS 26 vem do sistema se usarmos `.toolbar` nativo — não desenhar materiais à mão.

---

## 1. Princípio: não quebrar

Regra de ouro: **a mesma função da sessão, outro sítio na UI**.

| Pode mudar | Não pode mudar nesta iniciativa |
|---|---|
| Onde o botão vive (toolbar de janela vs `HStack`) | `ProjectSession`, `FileOrganizer`, import, watcher |
| Estilo do botão (`Button` nativo vs `IconActionButton`) | Nomes de pastas, JSON, bookmarks |
| Menus `.commands` a chamar os **mesmos** métodos | Atalhos de triagem (`1–24`+Enter, `R`, `F`, `C`, `S`, ⌘⌫, ⌘Z) |
| Símbolo SF Symbol | Contratos de teste de domínio / workflow |
| Folhas: `sheet` / `confirmationDialog` / Sparkle | Lógica de macro, ledger de entrega |

Ordem segura em **todas** as fases: (1) adicionar o equivalente nativo ao lado, (2) ligar à mesma ação, (3) só depois remover o chrome antigo. Nunca apagar `IconActionButton` enquanto ainda houver um call site.

Critério de “não partiu”: criar projeto, importar, classificar com teclado, undo, entrega, Definições, procurar updates — iguais a hoje.

---

## 2. Estado atual (inventário)

### 2.1 Janela e menus

`FastReportApp.swift`: um `WindowGroup` + `Settings { }`. Quase sem menus. Ajuda está **anulada** (`CommandGroup(replacing: .help) { EmptyView() }`). Só existe Procurar atualizações (`⌘U`).

Isto contradiz o próprio `PLANO.md` §5: *Menu nativo: FastReport, Projeto, Foto, Ver, Janela, Ajuda*.

### 2.2 Casa

`HomeView`: `NavigationStack` + `.toolbar` (updates + engrenagem) **e** título grande no corpo — título duplicado. Cartão custom, recentes em tabela caseira, `IconActionButton` + `HoverHint`. Status bar em baixo.

### 2.3 Workspace

`ProjectWorkspaceView.workspaceHeader`: **não é toolbar de janela**. É um `HStack` com caixinhas. Título do projeto no conteúdo, não na title bar. Definições e updates na mesma faixa.

### 2.4 Assistente

`ProjectWizardView`: sheet com header/footer desenhados. Cancelar / Continuar / Criar / Concluído são `IconActionButton`, não `cancellationAction` / `confirmationAction`. Escolher pasta e revelar no Finder são ícones sem rótulo de botão nativo.

### 2.5 Inbox / revisão / entrega

Drop zone e grelhas razoáveis. Botões de canto nas miniaturas (rodar/lixo) são overlay — padrão Photos, pode ficar. Limpar lixeira já usa `confirmationDialog`. Tamanho de miniatura está na status bar com botões custom.

### 2.6 Triagem

Overlay a preto com barra própria. Teclado correcto. Erros em cápsula vermelha em vez de `alert`. Ações **não** estão no menu Foto.

### 2.7 Definições

`Settings` scene + `Form` grouped: isto já é o sítio certo no Mac. Os botões internos ainda são `IconActionButton`. Engrenagem na toolbar da janela principal é extra (estilo iOS).

### 2.8 Updates

Overlay escurecido + cartão (`UpdateOverlayHost`) em vez da janela Sparkle / `.sheet` da janela. Botão de toolbar com ícone **e** texto `filled`.

### 2.9 Macro

Orbe flutuante + painel. Utilidade real, mas chrome **não** é padrão Mac (seria `NSPanel` utilitário ou inspector). Fora da toolbar; tratar à parte, no fim.

### 2.10 Peças partilhadas

- `IconActionButton` — chrome iOS-like (bezel, fill, badge).
- `HoverHint` — tooltip custom; na toolbar o padrão é `.help()`.
- `AppStatusBar` — barra de estado de janela; **manter** (não é toolbar).

---

## 3. Alvo: o que “100% alinhado” é nesta app

1. **Toolbar do sistema** na moldura da janela (`.toolbar` + `navigationTitle`). Itens sem bezel, SF Symbols sem círculo à volta, `.help()`, overflow automático.
2. **Barra de menus completa**; cada item da toolbar existe também no menu.
3. **Definições só** em FastReport → Definições (`⌘,`). Sem engrenagem na toolbar.
4. **Um** botão principal por contexto (`.primaryAction` ou `.borderedProminent` no conteúdo).
5. Folhas e assistentes com **Cancelar / Continuar** nativos (texto, não só ícone).
6. Triagem = modo imersivo: toolbar da janela **escondida**; ações no menu Foto.
7. Updates: Sparkle / sheet da janela, não overlay a tapar a app.
8. Ícones: só SF Symbols oficiais, **o mesmo símbolo para a mesma ação** em toolbar, menu, status e hints.

Não entra no “100%” desta ronda (fase opcional depois):

- Personalizar toolbar (`.toolbar(id:)`).
- Document-based `DocumentGroup` (a app é pasta + bookmark, não documento único).
- Redesenhar o orbe da macro (fase 8).
- Recriar badge de Inbox e hint de 3 segundos na toolbar nativa — **abdicam-se**; o número vai para o título acessível / status / menu.

---

## 4. Arquitetura de UI (sem mexer nos serviços)

Hoje a sessão vive em `HomeView` e a workspace substitui o conteúdo. Manter isso.

Mudança de estrutura:

```
WindowGroup
  HomeView
    NavigationStack          ← sempre, casa e projeto
      conteúdo
        .navigationTitle
        .toolbar             ← muda com session == nil vs projeto vs triagem
      AppStatusBar           ← casa; workspace já tem a sua
    .commands { … }          ← aqui, não só em FastReportApp: vê a sessão
```

`FocusedValues` só se os comandos no `App` precisarem da sessão. Preferência mais segura: **`.commands` no `HomeView`**, métodos já existentes (`openPickedProject`, `session?.pickAndImport`, etc.).

`workspaceHeader` desaparece. `Divider` debaixo dele desaparece. O conteúdo começa abaixo da toolbar do sistema.

Na triagem: `.toolbar(.hidden, for: .windowToolbar)` (ou equivalente 14) + overlay `TriageView` como hoje.

---

## 5. Barra de menus (mapa completo)

Implementar o que `PLANO.md` §5 já pedia. Atalhos de uma tecla da triagem (`R`, `F`, `C`, `S`) **não** vão para o menu como atalho global (roubariam a escrita). No menu Foto usam-se equivalentes com ⌘ quando a HIG o pede (`⌘R` rodar, `⌘Z` desfazer). O `onKeyPress` da triagem **mantém-se**.

### FastReport (app)

| Item | Estado | Notas |
|---|---|---|
| Acerca | sistema | Não anular |
| Definições… `⌘,` | já via `Settings` | Tirar engrenagem da toolbar |
| Procurar atualizações… `⌘U` | já existe | Manter |
| Sair | sistema | |

### Ficheiro

| Item | Ação actual | Activo quando |
|---|---|---|
| Novo projeto… `⌘N` | `isWizardPresented = true` | Casa (e workspace: fecha? **não** — só casa, ou abre sheet por cima; preferir só casa + desactivar no projeto) |
| Abrir pasta… `⌘O` | `openPickedProject()` | Casa |
| Fechar projeto `⌘W` | `closeProject()` | Projeto aberto; **não** substituir Fechar janela do sistema — usar “Fechar projeto” no menu Ficheiro **depois** de Fechar, ou `CommandGroup(after: .newItem)` e deixar `⌘W` para a janela. Preferir **sem** roubar `⌘W`: item “Fechar projeto” sem atalho, ou `⇧⌘W`. |
| Importar fotos… | `session.pickAndImport` | Projeto, não triagem |
| Mostrar no Finder | `FinderReveal.reveal` | Recente seleccionado **ou** projeto aberto |

### Editar

| Item | Ação | Activo quando |
|---|---|---|
| Desfazer `⌘Z` | `session.undoLast` | Pilha não vazia (workspace e triagem) |

Não implementar Recortar/Copiar/Colar custom. Deixar o grupo de sistema para campos de texto (assistente, Definições).

### Visualização

| Item | Ação | Activo quando |
|---|---|---|
| Modo entrega | `toggleDelivery` | Revisão ou já em entrega |
| Iniciar triagem | `startTriage` | `pendingCount > 0` |
| Inverter Inbox | `flipPending` | `pendingCount > 0` |
| Miniaturas maiores / menores / automáticas | `ThumbnailSizeStore` | Revisão ou entrega |

### Foto (só com projeto; na triagem os enabled mudam)

| Item | Ação | Atalho menu |
|---|---|---|
| Rodar | `rotateCurrent` / `rotate` | `⌘R` |
| Espelhar | `flipCurrent` | — (tecla `F` só na triagem) |
| Recortar | `beginCrop` | — (tecla `C` só na triagem) |
| Mover para o Lixo | `trashCurrent` | `⌘⌫` |
| Mostrar no Finder | `revealCurrent` | |

### Janela

Deixar o grupo de sistema (minimizar, zoom, ciclo). Fullscreen nativo.

### Ajuda

**Deixar de anular** `.help`. Item “Atalhos de teclado…” abre o `ShortcutsSheet` actual. Opcional: “Notas de versão” → URL GitHub (já há link nas Definições).

---

## 6. Toolbars por ecrã

### 6.1 Casa

- `navigationTitle`: **Projetos** (chave nova ou reutilizar `home.title` **só** na janela).
- Corpo: **um** título grande **ou** o da janela, não os dois. Preferir título na janela + subtítulo no corpo (sem repetir “FastReport” / `home.title`).
- Toolbar trailing: nada no dia-a-dia. Se houver update, **só ícone** `arrow.down.app` (sem texto, sem `filled` custom).
- Sem `SettingsGearButton`.
- Ação principal no cartão: Novo projeto = `Button` `.borderedProminent` com `Label` + `plus`. Abrir = `.bordered` com `folder`.

### 6.2 Workspace (Inbox / revisão / entrega)

| Placement | Itens | Símbolo |
|---|---|---|
| `.navigation` | Voltar à casa | `chevron.backward` |
| Título | Nome do projeto | — |
| Grupo centro | Importar; Finder; Entrega (toggle); Inverter (se Inbox > 0) | ver tabela §8 |
| `.primaryAction` | Iniciar triagem (se Inbox > 0) | `play.fill` |

Sem: casa `house`, teclado, updates, definições, badges, bezels.

Entrega activa: o item Entrega fica no estado **on** do `Toggle` da toolbar, não com fill accent nosso.

Atalhos de teclado: menu Ajuda, não ícone permanente.

### 6.3 Triagem

Toolbar de janela **hidden**. Barra preta interna **mantém-se** (modo imersivo, como o Photos). Trocar `.hoverHint` por `.help` nos botões; símbolos da tabela §8; fechar = `xmark` (HIG: close padrão). Erro: `alert` ou banner discreto, não cápsula solta se for fácil; se o `alert` roubar o foco do teclado, manter overlay mas com `.regularMaterial` e texto do sistema — **não** quebrar `onKeyPress`.

### 6.4 Assistente (sheet)

`NavigationStack` dentro da sheet:

- Título = passo (`wizard.step.map`, etc.).
- `.cancellationAction`: Cancelar (texto).
- `.confirmationAction`: Continuar / Criar / OK (texto).
- Voltar: `.navigation` ou botão Anterior no trailing oposto, texto “Anterior”, não só `chevron.left`.
- Escolher pasta: `Button` com `Label("…", systemImage: "folder.badge.plus")`.
- Passo sucesso: `checkmark.circle.fill` pode ficar (símbolo de sistema).

Tamanho da sheet pode manter-se (560×500).

### 6.5 Definições

Manter `Settings { Form grouped }` (app pequena; TabView é opcional). Trocar `IconActionButton` por `Button` nativo com título. Pedir acessibilidade da macro: `Button` padrão, não cadeado filled.

Opcional (fase 7): `TabView` com ícones de sistema — Idioma `globe`, Imagem `photo`, Macro `command`, Atualizações `arrow.down.app`, Acerca `info.circle`.

### 6.6 Updates

Tirar o dimmer full-window. Usar `.sheet` a partir da janela, ou a UI Sparkle. `UpdateToolbarButton`: ícone só, aparece só com update. Progresso: `ProgressView` nativo no sheet / nas Definições (já há cartão nas Definições — pode ser a superfície principal).

### 6.7 Status bar

Manter `AppStatusBar`. Ícones alinhados à tabela §8. Controlos de miniatura: `Stepper` ou botões `.borderless` com `minus` / `plus`, e texto “Automático” como `Button` sem caixinha custom. Material `.bar` já está correcto.

---

## 7. Folhas, diálogos e erros

| Hoje | Alvo |
|---|---|
| `confirmationDialog` remover recente / limpar lixo | Manter (padrão Mac) |
| `alert` genérico | Manter; botão OK `role: .cancel` está bem |
| Wizard sheet custom chrome | Sheet + navigation toolbar nativa |
| Shortcuts sheet VStack | Manter conteúdo; título `.navigationTitle`; botão Fechar padrão |
| Update overlay | Sheet |
| Macro orbe | Fase 8 |

Não introduzir `NSAlert` AppKit onde o SwiftUI já faz o mesmo.

---

## 8. Ícones oficiais (uma acção = um SF Symbol)

Peso: **Regular** na toolbar nativa (o sistema gere). Deixar de forçar `.semibold` 14 pt nas barras.

| Acção | Hoje | Oficial / estável | Onde |
|---|---|---|---|
| Voltar à casa | `house` | `chevron.backward` | Toolbar workspace |
| Casa (status) | `house` | `house` **ou** `square.grid.2x2` | Só status, não navegação |
| Novo projeto | `plus` | `plus` | Cartão, menu Ficheiro |
| Abrir pasta | `folder` | `folder` | Cartão, menu |
| Escolher pasta (wizard / mover para Aplicações) | `folder.badge.plus` | `folder.badge.plus` | Formulário |
| Importar / escolher fotos | `photo.badge.plus` | `photo.badge.plus` | Toolbar, Inbox, menu |
| Drop import | `square.and.arrow.down` | `square.and.arrow.down` | Inbox, status |
| Mostrar no Finder | `arrow.up.right.square` / `folder` (triagem) | **`folder`** em todo o lado (Finder) | Unificar; `arrow.up.right.square` = “abrir fora”, aceitável no Finder mas hoje há **dois** símbolos para a mesma acção |
| Entrega | `doc.text.image` | `doc.text.image` | Toolbar, status, banner |
| Inverter Inbox | `arrow.left.and.right.righttriangle.left.righttriangle.right` | **`arrow.up.arrow.down`** ou `rectangle.2.swap` (virar/trocar). O símbolo actual também é **Espelhar** na triagem — **conflito**. Separar: flip foto = `flip.horizontal` (se existir no set 14) ou manter o righttriangle **só** para espelhar; inverter Inbox = `arrow.up.arrow.down` |
| Iniciar triagem | `play.fill` | `play.fill` | `.primaryAction` |
| Atalhos | `keyboard` | `questionmark.circle` no menu Ajuda; **fora** da toolbar |
| Definições | `gearshape` | `gearshape` **só** se algum dia houver ícone; no Mac não vai à toolbar |
| Update disponível | `arrow.down.app.fill` | `arrow.down.app` (sem fill forçado; o sistema escolhe) | Toolbar opcional |
| Update em curso | `arrow.triangle.2.circlepath` | `arrow.triangle.2.circlepath` | |
| Procurar updates (Definições) | `arrow.clockwise` | `arrow.clockwise` | |
| Cancelar | `xmark` | Texto **Cancelar**; ícone `xmark` só em close de overlay (triagem) |
| Continuar | `chevron.right` | Texto **Continuar** |
| Anterior | `chevron.left` | Texto **Anterior** |
| Criar | `plus` | Texto **Criar** |
| Concluído / OK | `checkmark` | Texto **OK** / **Concluído** |
| Retry | `arrow.clockwise` | `arrow.clockwise` | Casa, mapas |
| Mapas OK | `checkmark.circle` | `checkmark.circle` | |
| Aviso | `exclamationmark.triangle.fill` | `exclamationmark.triangle` (fill só se for status crítico) | |
| Foto em falta (thumb) | `photo` | `photo` | |
| Rodar | `rotate.right` | `rotate.right` | Miniatura, triagem, menu Foto |
| Recortar | `crop` | `crop` | Triagem |
| Lixo | `trash` | `trash` | Sempre vermelho só no *role* destructive, não no ícone da toolbar de triagem (Photos também usa `trash` claro no fundo preto) |
| Desfazer | `arrow.uturn.backward` | `arrow.uturn.backward` | |
| Miniaturas − / + | `minus` / `plus` | `minus` / `plus` | Status |
| Colocada (entrega) | `checkmark.circle.fill` | `checkmark.circle.fill` | Badge na thumb — OK |
| Macro | `command` / `command.square.fill` | `command` (orbe); gravar `record.circle`; parar `stop.fill`; reproduzir `play.fill` | Painel |
| Fechar sheet update | `xmark.circle.fill` | `xmark.circle` + `.foregroundStyle(.secondary)` — padrão de dismiss | |
| Relógio recentes | `clock` | `clock` | Status casa |
| Versão | `number` | omitir ícone ou `info.circle` | Status |
| Mapa (status) | `map` | `map` | |
| Inbox (status) | `tray` | `tray` | |
| Revisão (status) | `square.grid.2x2` | `square.grid.2x2` | |
| Organizar (cartão) | `square.grid.2x2` | `square.grid.2x2` | |
| Selecção wizard | `circle` / `checkmark.circle.fill` | Manter (padrão de lista seleccionável) | |

Regra: **proibido** símbolo com círculo à volta só para “parecer botão” (`plus.circle.fill` como chrome). `checkmark.circle.fill` em *estado* (seleccionado, colocado) está correcto.

---

## 9. Botões e hints no conteúdo

Onde **não** é toolbar de janela (cartão, linha de recentes, footer do wizard até migrar, Definições, canto da miniatura):

- Preferir `Button` + `Label` + estilo `.bordered` / `.borderedProminent` / `.plain` (linhas).
- Recentes: `NSTableView` SwiftUI `Table` **ou** `List` nativo em vez da tabela desenhada — fase 6, não bloquear a toolbar.
- Miniaturas: overlays pretos pequenos podem **ficar** (Photos faz o mesmo). Símbolos da tabela. `.help` em vez de `HoverHint` se o painel custom cobrir thumbs.

`HoverHint` com texto longo: ir migrando para `.help` (tooltip nativo). Remover `HoverHint.swift` só quando zero call sites.

`IconActionButton`: remover no fim, quando a pesquisa no projecto não tiver usos.

---

## 10. Fases (ordem para não partir)

Cada fase é um PR / commit lógico, app compilável e usável no fim.

### Fase 0 — Inventário e strings (sem UX visível)

- Chaves de menu (Novo, Abrir, Fechar projeto, Importar, menus Foto/Ver/Ajuda).
- Não apagar chaves antigas de hints até os call sites mudarem.
- Critério: catálogo PT/EN actualizado; zero mudança visual.

### Fase 1 — Menus (só adicionar)

- Restaurar Ajuda.
- `.commands` em `HomeView` com enabled/disabled segundo `session` / `mode`.
- **Não** tirar botões antigos.
- Critério: todas as acções da workspace disparam pelo menu; teclado da triagem intacto; `⌘Z` no menu Editar desfaz o mesmo que o botão.

### Fase 2 — Toolbar nativa da workspace

- `NavigationStack` a envolver casa **e** projeto (ou toolbar no contentor comum).
- `navigationTitle` = nome do projeto.
- Itens §6.2; `onClose` no `chevron.backward`.
- Apagar `workspaceHeader` + `Divider`.
- Tirar `SettingsGearButton` e `UpdateToolbarButton` **desta** barra (update: ícone só se `showsToolbarUpdateIcon`).
- Critério: Inbox/revisão/entrega iguais; import/Finder/entrega/triagem/inverter funcionam; janela estreita → overflow do sistema.

### Fase 3 — Casa

- Título de janela único; sem engrenagem.
- Botões do cartão nativos.
- Critério: wizard, abrir, recentes, retry de mapas iguais.

### Fase 4 — Triagem imersiva

- Esconder toolbar da janela.
- `.help` na barra preta; símbolos unificados (Finder = `folder`; flip ≠ inverter Inbox).
- Menus Foto activos.
- Critério: classificar 20 fotos só com teclado; Esc sai; crop/rodar/lixo iguais.

### Fase 5 — Assistente

- Toolbar de sheet Cancelar / Continuar / Criar / Concluído **com texto**.
- Critério: os 3 passos + criar pasta no Finder iguais aos testes `ProjectCreatorTests` / wizard manual.

### Fase 6 — Conteúdo (Inbox, revisão, status, recentes)

- Inbox: “Escolher” `.borderedProminent`, não `IconActionButton`.
- Limpar lixo: `Button(role: .destructive)` nativo (dialog já existe).
- `ThumbnailSizeControls` nativos.
- Recentes: `List`/`Table` se couber sem mudar bookmarks.
- Critério: drop, thumbs, reorder, empty trash.

### Fase 7 — Definições e updates

- Botões nativos no `Form`.
- Sheet de update em vez de overlay a bloquear.
- Critério: idioma, qualidade, check Sparkle, mover para Aplicações.

### Fase 8 — Macro (opcional, isolado)

- Manter função; chrome → `NSPanel` / janela utilitária com fecho nativo, **ou** deixar orbe se for risco alto.
- Não misturar com as fases 1–7.

### Fase 9 — Limpeza

- Apagar `IconActionButton` / `HoverHint` / `SettingsGearButton` se órfãos.
- Actualizar `INDEX.md` e `PLANO.md` §4.1 (barra: Definições → menu da app) e §4.5 (barra da triagem).
- Critério: `WorkflowTests` e testes de domínio verdes.

**Fora de âmbito até o resto estável:** `.toolbar(id:)` personalizável.

---

## 11. Ficheiros por fase

| Fase | Ficheiros (só estes + strings) |
|---|---|
| 0 | `Localizable.xcstrings` |
| 1 | `HomeView.swift`, opcionalmente `FastReportApp.swift` (deixar de anular Ajuda) |
| 2 | `ProjectWorkspaceView.swift`, `HomeView.swift`, `UpdateViews.swift` |
| 3 | `HomeView.swift`, `UpdateViews.swift` |
| 4 | `TriageView.swift`, `ProjectWorkspaceView.swift` |
| 5 | `ProjectWizardView.swift` |
| 6 | `InboxGridView.swift`, `ReviewGridView.swift`, `AppStatusBar.swift` |
| 7 | `SettingsView.swift`, `UpdateViews.swift` |
| 8 | `DeliveryFloatingOrb.swift`, `MacroPadWindow.swift`, `MacroPadView.swift` |
| 9 | `IconActionButton.swift`, `HoverHint.swift`, `INDEX.md`, `PLANO.md` |

Não tocar em `Domain/`, `Services/` (excepto se um `FocusedValue` precisar de um wrapper fino — preferir não).

---

## 12. Testes e verificação

- Correr `FastReportTests` após cada fase. UI não tem testes de captura; o risco é regressão de *enabled* (botão desactivo) e de foco na triagem.
- Verificação manual mínima por fase: casa → novo projeto → import → triagem 5 fotos → undo → revisão → entrega → Definições → `⌘U`.
- Confirmar **View → Hide Toolbar** (se o sistema oferecer): os menus ainda fazem import/triagem.
- Claro e escuro do sistema.
- Janela no `minWidth` 720: overflow, não sobreposição.

Não há browser; a verificação é a app Mac.

---

## 13. Decisões explícitas (para não reabrir)

1. **Não** personalizar toolbar nesta iniciativa.
2. **Não** document-based.
3. **Não** recriar badge nem hint de 3 s na toolbar.
4. Fechar projeto **não** rouba `⌘W` à janela.
5. Teclas `R` `F` `C` `S` ficam só no `onKeyPress` da triagem.
6. Status bar de baixo fica.
7. Overlays nas miniaturas ficam.
8. Macro orbe não bloqueia 1–7.
9. Definições: Form único chega; TabView é extra da fase 7.
10. Um SF Symbol por acção; Finder deixa de ter dois ícones.

---

## 14. Relação com o plano de produto

`PLANO.md` já pedia HIG, menus nativos e SF Symbols. Este ficheiro é a **lista de trabalho** para cumprir isso no código actual, sem reescrever o produto.

Quando uma fase fechar, actualizar a frase em `PLANO.md` §4.1 (“Barra: Definições”) para “Definições no menu da app”.
