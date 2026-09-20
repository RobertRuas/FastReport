# FastReport — Índice de código

Mapa **funcionalidade → ficheiros**. Ler isto primeiro; só abrir os ficheiros da funcionalidade pedida. Não vasculhar o repositório inteiro.

Produto e decisões: `PLANO.md`. Alinhamento HIG / menus / ícones: `PLANO-PADRAO-APPLE.md`. Stack e instalação: `README.md`.

Vocabulário estável: **Mapa**, **Projeto**, **Inbox**, **Slot**, **Triagem**, **Revisão**. Disco = fonte da verdade.

---

## Como usar (agentes)

1. Localizar a funcionalidade na tabela abaixo.
2. Abrir só esses ficheiros (e o teste associado, se for correção).
3. Atualizar **esta tabela** se criares, moveres ou apagares ficheiros.

---

## Arranque e ciclo de vida

| Recurso | Ficheiros |
|---|---|
| Entrada da app, janela, menu Ajuda/Updates, injeção de stores | `FastReport/App/FastReportApp.swift` |
| Versão marketing + build | `FastReport/App/AppVersion.swift` |
| Acesso ao String Catalog | `FastReport/App/StringCatalog.swift` |
| Info.plist, entitlements | `FastReport/Info.plist`, `FastReport/FastReport.entitlements`, `FastReport/FastReportDebug.entitlements` |
| XcodeGen / projeto | `project.yml`, `FastReport.xcodeproj/` |
| Bundle id, sandbox, Sparkle no target | `project.yml` |

---

## Casa

Ecrã inicial: novo projeto, abrir pasta, recentes.

| Recurso | Ficheiros |
|---|---|
| UI da casa | `FastReport/Features/Home/HomeView.swift` |
| Lista de projetos recentes + bookmarks | `FastReport/Services/RecentProjectsStore.swift` |
| Abrir pasta existente (lê `.fastreport.json`) | `FastReport/Services/ProjectOpener.swift` |
| Bookmarks security-scoped | `FastReport/Services/BookmarkStore.swift` |
| Seletor de pasta nativo | `FastReport/Services/FinderSupport.swift` (`DirectoryPicker`) |

---

## Assistente de novo projeto

| Recurso | Ficheiros |
|---|---|
| UI dos 3 passos (mapa, pasta/nome, import) | `FastReport/Features/ProjectWizard/ProjectWizardView.swift` |
| Estado do assistente | `FastReport/Features/ProjectWizard/ProjectWizardModel.swift` |
| Criar pasta + subpastas + metadata | `FastReport/Services/ProjectCreator.swift` |
| Erros de criação / `CreatedProject` | `FastReport/Domain/ProjectCreateError.swift` |
| Nome da pasta no Finder | `FastReport/Domain/ProjectFolderName.swift` |
| Slug nos nomes de ficheiro | `FastReport/Domain/ProjectSlug.swift` |
| `.fastreport.json` | `FastReport/Domain/ProjectMetadata.swift` |

Testes: `FastReportTests/ProjectCreatorTests.swift`

---

## Mapas (receitas JSON)

| Recurso | Ficheiros |
|---|---|
| Modelo `OrganizationMap` | `FastReport/Domain/OrganizationMap.swift` |
| Slot (Inbox, T1…, General, Trash) | `FastReport/Domain/Slot.swift` |
| Validação do JSON | `FastReport/Domain/MapValidator.swift` |
| Carregar JSON do bundle | `FastReport/Services/MapCatalog.swift` |
| Catálogo em memória (environment) | `FastReport/Services/MapLibrary.swift` |
| Mapa 1 — Inspeção T24 | `FastReport/Resources/Maps/inspection-t24.json` |
| Textos localizáveis dentro do mapa | `FastReport/Domain/LocalizedCopy.swift` |

Testes: `FastReportTests/OrganizationMapTests.swift`, `FastReportTests/MapCatalogTests.swift`

Novo mapa = JSON em `FastReport/Resources/Maps/` + entrada no catálogo. A triagem/grelha/import **não** mudam.

---

## Área de trabalho do projeto (orquestração)

Sessão aberta: fotos no disco, import, triagem, undo, watcher.

| Recurso | Ficheiros |
|---|---|
| UI contentor (Inbox vs triagem, atalhos, folhas) | `FastReport/Features/Workspace/ProjectWorkspaceView.swift` |
| Estado da sessão (`ProjectSession`, `WorkspaceMode`) | `FastReport/Services/ProjectSession.swift` |
| Inventário de fotos nas pastas | `FastReport/Services/ProjectScanner.swift` |
| Mover / renomear / undo / limpar lixeira | `FastReport/Services/FileOrganizer.swift` |
| Foto no disco, undo, stats, erros de pasta | `FastReport/Domain/DiskPhoto.swift` |
| Item de foto (domínio) | `FastReport/Domain/PhotoItem.swift` |
| Padrão de nome `{projeto}_{slot}_{índice}.jpeg` | `FastReport/Domain/FileNameFormatter.swift` |
| FSEvents (Finder mexe → app atualiza) | `FastReport/Services/FolderWatcher.swift` |
| Revelar no Finder / enviar para o Lixo | `FastReport/Services/FinderSupport.swift` (`FinderReveal`, `FinderTrash`) |
| Erros mostrados na UI | `FastReport/Domain/AppFailure.swift` |

---

## Importação de fotos

| Recurso | Ficheiros |
|---|---|
| Drop / escolher ficheiros, copiar vs mover | `FastReport/Services/PhotoImporter.swift` |
| HEIC/JPEG/PNG → JPEG, resize, EXIF | `FastReport/Services/ImagePipeline.swift` |
| Qualidade / lado máximo (persistido) | `FastReport/Services/ImageSettingsStore.swift` |
| Contadores `ImportStats` | `FastReport/Domain/DiskPhoto.swift` |

A UI de import está no assistente e na workspace (`ProjectWizardView`, `ProjectWorkspaceView` / `InboxGridView`), não num Feature `Import/` separado.

---

## Inbox (grelha “sem categoria”)

| Recurso | Ficheiros |
|---|---|
| Grelha Inbox, iniciar triagem | `FastReport/Features/Inbox/InboxGridView.swift` |
| Miniatura | `FastReport/Features/Workspace/ThumbnailView.swift` (rodar / lixo no canto, ao pairar) |
| Cache de miniaturas | `FastReport/Services/ThumbnailStore.swift` |
| Tamanho das miniaturas (persistido) | `FastReport/Services/ThumbnailSizeStore.swift` |

---

## Triagem (teclado, uma foto de cada vez)

| Recurso | Ficheiros |
|---|---|
| Ecrã de triagem | `FastReport/Features/Triage/TriageView.swift` |
| Recorte / reenquadramento | `FastReport/Features/Triage/PhotoCropOverlay.swift`, `FastReport/Domain/PhotoCropGeometry.swift` |
| Buffer numérico + Enter (`T10`, `0` = General) | `FastReport/Domain/ClassificationBuffer.swift` |
| Folha de atalhos | `FastReport/Features/Workspace/ProjectWorkspaceView.swift` (`ShortcutsSheet`) |

Ações: classificar, lixo, setas, rodar, espelhar, cortar, undo — lógica em `ProjectSession` + `FileOrganizer`. Inverter todas as da Inbox: barra da workspace, ao lado de iniciar triagem.

---

## Revisão (grelha por slot + reordenar)

| Recurso | Ficheiros |
|---|---|
| Grelha por linhas (General, T1…T24, Inbox, Trash; limpar lixeira com confirmação) | `FastReport/Features/Review/ReviewGridView.swift` |
| Ordem / partições dos slots na grelha | `FastReport/Domain/ReviewDisplaySlots.swift` |
| Arrastar para reordenar na linha | `FastReport/Features/Review/LiveReorderStrip.swift` |
| Layout do drag | `FastReport/Domain/LiveReorderLayout.swift` |
| Controlos de tamanho de miniatura | `FastReport/Features/Review/ReviewGridView.swift` (`ThumbnailSizeControls`) |

---

## Entrega (arrastar fotos para o relatório)

Modo na workspace: pastas com miniaturas; arrastar para Word/Pages/Finder como no Finder. Fotos já colocadas ficam esbatidas. Persistência: `fastreport-delivery.json` na pasta do projeto (inode + caminho relativo).

| Recurso | Ficheiros |
|---|---|
| Ecrã de entrega | `FastReport/Features/Delivery/DeliveryBoardView.swift` |
| Arrasto nativo para outras apps | `FastReport/Features/Delivery/ExternalFileDragOverlay.swift` |
| Marcações colocadas | `FastReport/Domain/DeliveryLedger.swift` |
| Modo `.delivery`, marcar/desmarcar | `FastReport/Services/ProjectSession.swift` |
| Ícone na barra (`doc.text.image`) | `FastReport/Features/Workspace/ProjectWorkspaceView.swift` |
| Painel de macro (ícone na app; caixa de edição flutuante) | `FastReport/Features/Delivery/MacroPadView.swift`, `FastReport/Features/Delivery/MacroPadWindow.swift`, `FastReport/Features/Delivery/DeliveryFloatingOrb.swift`, `FastReport/Features/Delivery/MacroClickMarkers.swift` |
| Modelo da sequência (teclas, rato, globais vs projeto) | `FastReport/Domain/KeyboardMacro.swift`, `FastReport/Domain/KeyLayout.swift` |
| Biblioteca `Application Support/FastReport/macros.json` (cliques: posição exacta do ecrã) | `FastReport/Services/KeyboardMacroCenter.swift` |
| Ligar/desligar projeto e apagar macros da pasta | `FastReport/Features/Home/HomeView.swift` |

Testes: `FastReportTests/DomainAndSettingsTests.swift` (`DeliveryLedgerTests`, `ReviewDisplaySlotsTests`, `KeyboardMacroTests`)

---

## Peças de UI partilhadas

| Recurso | Ficheiros |
|---|---|
| Barra de estado | `FastReport/Features/Workspace/AppStatusBar.swift` |
| Botão só ícone | `FastReport/Features/Workspace/IconActionButton.swift` |
| Hint ao pairar | `FastReport/Features/Workspace/HoverHint.swift` |

---

## Definições e idioma

| Recurso | Ficheiros |
|---|---|
| Definições (idioma, imagem, macro, updates, sobre) | `FastReport/Features/Settings/SettingsView.swift` |
| PT / EN | `FastReport/Services/AppLanguage.swift`, `FastReport/Services/AppLanguageStore.swift` |
| Strings da UI | `FastReport/Resources/Localizable.xcstrings` |

---

## Atualizações (Sparkle + GitHub)

| Recurso | Ficheiros |
|---|---|
| Centro de updates (environment) | `FastReport/Services/AppUpdateCenter.swift` |
| Consulta GitHub Releases | `FastReport/Services/UpdateChecker.swift` |
| Overlay / botões / progresso | `FastReport/Features/Updates/UpdateViews.swift` |
| Erro se a app não está em Aplicações | `FastReport/Services/SparkleInstallError.swift` |
| Detetar pasta Aplicações / mover | `FastReport/Services/AppInstallLocation.swift` |
| Appcast | `packaging/appcast.xml` |
| Relançar Debug (mata, build, copia para Descargas, abre) | `rebuild.sh` |
| Script de release | `packaging/make_release.sh` |
| Reassinar Sparkle no build | `packaging/resign_embedded_sparkle.sh` |
| CI / release | `.github/workflows/ci.yml`, `.github/workflows/release.yml` |
| Página de download | `docs/index.html` |

---

## Recursos visuais

| Recurso | Ficheiros |
|---|---|
| Ícone e acento | `FastReport/Resources/Assets.xcassets/` |

---

## Testes

| Recurso | Ficheiros |
|---|---|
| Fluxo (criar, import, classificar, undo) | `FastReportTests/WorkflowTests.swift` |
| Domínio + definições | `FastReportTests/DomainAndSettingsTests.swift` |
| Mapas / catálogo / criador | `FastReportTests/OrganizationMapTests.swift`, `MapCatalogTests.swift`, `ProjectCreatorTests.swift` |
| Fixtures e imagens de teste | `FastReportTests/TestFixtures.swift`, `TestImageFactory.swift` |
| Bookmark falso | `FastReportTests/FakeBookmarkStore.swift` |

---

## Árvore rápida (só código da app)

```
FastReport/
  App/           ciclo de vida
  Domain/        modelos e regras (sem UI)
    Features/      ecrãs SwiftUI
    Home/ ProjectWizard/ Inbox/ Triage/ Review/ Delivery/ Workspace/ Settings/ Updates/
  Services/      disco, import, sessão, i18n, updates
  Resources/     Maps/*.json, Localizable.xcstrings, Assets
FastReportTests/
```

---

## Onde **não** está

- Não há pasta `Features/Import/` — import vive nos serviços + wizard/workspace.
- Não há editor de mapas na UI (v2 no plano).
- Não há geração de relatório PDF/Word — a **Entrega** só arrasta as JPEGs já no disco para o documento noutro programa.
- Protótipo Flutter antigo (`~/PhotoOrganizer`) **não** faz parte deste repo.
