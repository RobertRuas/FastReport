# FastReport — Índice de código

Ler **só isto** para localizar ficheiros. Abrir apenas os da funcionalidade. Não vasculhar o repo.

Produto/roadmap (opcional, tarefas de produto): `PLANO.md`. Instalação e uso: `README.md`. Agentes: `AGENTS.md` e `.cursor/rules/index-first.mdc`.

Vocabulário: **Mapa**, **Projeto**, **Inbox**, **Slot**, **Triagem**, **Revisão**, **Entrega**. Disco = fonte da verdade. Metadata: `fastreport.json` (legado: `.fastreport.json`).

Se criares, moveres ou apagares código, atualiza esta tabela no mesmo trabalho.

---

## Arranque

| Recurso | Ficheiros |
|---|---|
| App, janela, menus, stores | `FastReport/App/FastReportApp.swift`, `FastReport/App/AppCommands.swift` |
| Versão marketing + build | `FastReport/App/AppVersion.swift` — valores em `project.yml` (`MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`) |
| String Catalog | `FastReport/App/StringCatalog.swift` |
| Plist / entitlements | `FastReport/Info.plist`, `FastReport/FastReport.entitlements`, `FastReport/FastReportDebug.entitlements` |
| XcodeGen | `project.yml` → `FastReport.xcodeproj/` |

---

## Casa e novo projeto

| Recurso | Ficheiros |
|---|---|
| Casa | `FastReport/Features/Home/HomeView.swift` |
| Recentes + bookmarks | `FastReport/Services/RecentProjectsStore.swift`, `FastReport/Services/BookmarkStore.swift` |
| Abrir pasta | `FastReport/Services/ProjectOpener.swift` |
| Seletor Finder | `FastReport/Services/FinderSupport.swift` (`DirectoryPicker`) |
| Assistente 3 passos | `FastReport/Features/ProjectWizard/ProjectWizardView.swift`, `ProjectWizardModel.swift` |
| Criar pasta + metadata | `FastReport/Services/ProjectCreator.swift`, `FastReport/Domain/ProjectCreateError.swift`, `ProjectFolderName.swift`, `ProjectSlug.swift`, `ProjectMetadata.swift` |

---

## Mapas (JSON)

| Recurso | Ficheiros |
|---|---|
| Modelo / slot / validação | `FastReport/Domain/OrganizationMap.swift`, `Slot.swift`, `MapValidator.swift`, `LocalizedCopy.swift` |
| Catálogo | `FastReport/Services/MapCatalog.swift`, `MapLibrary.swift` |
| Mapa 1 — Inspeção T24 | `FastReport/Resources/Maps/inspection-t24.json` |

Novo mapa = JSON em `FastReport/Resources/Maps/` + entrada no catálogo. Triagem/grelha/import não mudam.

---

## Workspace, import, Inbox, triagem, revisão

| Recurso | Ficheiros |
|---|---|
| Contentor, toolbar, atalhos | `FastReport/Features/Workspace/ProjectWorkspaceView.swift` (`ShortcutsSheet`) |
| Sessão | `FastReport/Services/ProjectSession.swift` |
| Scan / mover / undo / watcher | `FastReport/Services/ProjectScanner.swift`, `FileOrganizer.swift`, `FolderWatcher.swift` |
| Foto no disco, nomes, erros | `FastReport/Domain/DiskPhoto.swift`, `PhotoItem.swift`, `FileNameFormatter.swift`, `AppFailure.swift` |
| Finder (revelar / lixo) | `FastReport/Services/FinderSupport.swift` (`FinderReveal`, `FinderTrash`) |
| Import JPEG 1024 | `FastReport/Services/PhotoImporter.swift`, `ImagePipeline.swift`, `ImageSettingsStore.swift` |
| Inbox | `FastReport/Features/Inbox/InboxGridView.swift` |
| Miniaturas | `FastReport/Features/Workspace/ThumbnailView.swift`, `FastReport/Services/ThumbnailStore.swift`, `ThumbnailSizeStore.swift` |
| Triagem | `FastReport/Features/Triage/TriageView.swift`, `PhotoCropOverlay.swift`, `FastReport/Domain/PhotoCropGeometry.swift`, `ClassificationBuffer.swift` |
| Revisão + reordenar | `FastReport/Features/Review/ReviewGridView.swift`, `LiveReorderStrip.swift`, `FastReport/Domain/ReviewDisplaySlots.swift`, `LiveReorderLayout.swift` |

Import UI: wizard + workspace/Inbox — não há `Features/Import/`.

---

## Entrega (arrastar JPEGs para o relatório noutro programa)

Persistência: `fastreport-delivery.json` (inode + caminho relativo).

| Recurso | Ficheiros |
|---|---|
| Quadro + arrasto nativo | `FastReport/Features/Delivery/DeliveryBoardView.swift`, `ExternalFileDragOverlay.swift` |
| Marcações | `FastReport/Domain/DeliveryLedger.swift` |
| Macro (orbe, painel, cliques) | `MacroPadView.swift`, `MacroPadWindow.swift`, `DeliveryFloatingOrb.swift`, `MacroClickMarkers.swift` em `FastReport/Features/Delivery/` |
| Modelo / biblioteca | `FastReport/Domain/KeyboardMacro.swift`, `KeyLayout.swift`, `FastReport/Services/KeyboardMacroCenter.swift` (`Application Support/FastReport/macros.json`) |
| Ligar/desligar no projeto | `FastReport/Features/Home/HomeView.swift` |

---

## UI partilhada, definições, i18n, updates

| Recurso | Ficheiros |
|---|---|
| Status bar / botão ícone / hint | `FastReport/Features/Workspace/AppStatusBar.swift`, `IconActionButton.swift`, `HoverHint.swift` |
| Definições | `FastReport/Features/Settings/SettingsView.swift` |
| PT / EN | `FastReport/Services/AppLanguage.swift`, `AppLanguageStore.swift`, `FastReport/Resources/Localizable.xcstrings` |
| Sparkle + GitHub | `FastReport/Services/AppUpdateCenter.swift`, `UpdateChecker.swift`, `SparkleInstallError.swift`, `AppInstallLocation.swift`, `FastReport/Features/Updates/UpdateViews.swift` |
| Appcast / scripts | `packaging/appcast.xml`, `packaging/make_release.sh`, `packaging/resign_embedded_sparkle.sh`, `rebuild.sh` |
| CI / release | `.github/workflows/ci.yml`, `.github/workflows/release.yml` |
| Página de download | `docs/index.html` |
| Ícone | `FastReport/Resources/Assets.xcassets/` |

Feed Sparkle: `releases/latest/download/appcast.xml` (`FastReport/Info.plist`). Uma versão pública: etiqueta `v1.0.0`.

---

## Testes

| Recurso | Ficheiros |
|---|---|
| Fluxo | `FastReportTests/WorkflowTests.swift` |
| Domínio + definições + entrega + macros | `FastReportTests/DomainAndSettingsTests.swift` |
| Mapas / catálogo / criador | `FastReportTests/OrganizationMapTests.swift`, `MapCatalogTests.swift`, `ProjectCreatorTests.swift` |
| Fixtures | `FastReportTests/TestFixtures.swift`, `TestImageFactory.swift`, `FakeBookmarkStore.swift` |

---

## Árvore

```
FastReport/App/ Domain/ Features/ Services/ Resources/
  Features: Home ProjectWizard Inbox Triage Review Delivery Workspace Settings Updates
FastReportTests/
.cursor/rules/index-first.mdc
```

## Onde não está

- Sem `Features/Import/`, sem editor de mapas na UI, sem PDF/Word (Entrega só arrasta JPEGs).
- Protótipo Flutter (`~/PhotoOrganizer`) não está neste repo.
