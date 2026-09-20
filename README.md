# FastReport

**App nativa para macOS** que organiza fotos de trabalho **no Finder**. Não cria uma biblioteca própria: o disco é a fonte da verdade. O relatório em si não é gerado aqui — a app prepara pastas, nomes e ordem para o relatório futuro ser rápido.

[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-000000?logo=apple&logoColor=white)](https://github.com/RobertRuas/FastReport/releases/latest)
[![Swift 6](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)](https://www.swift.org)
[![Versão](https://img.shields.io/github/v/release/RobertRuas/FastReport?label=versão)](https://github.com/RobertRuas/FastReport/releases/latest)

**[Descarregar o FastReport](https://github.com/RobertRuas/FastReport/releases/latest/download/FastReport.zip)**

---

## Como instalar (importante)

O FastReport **não está na App Store**. É uma aplicação de terceiros, distribuída neste repositório. O macOS protege o computador contra software não verificado pela Apple, por isso a primeira abertura precisa destes passos.

1. **Descarrega** o ficheiro [FastReport.zip](https://github.com/RobertRuas/FastReport/releases/latest/download/FastReport.zip).
2. **Abre o zip** com um duplo clique. Aparece `FastReport.app`.
3. **Move a app para Aplicações:** arrasta `FastReport` para a pasta **Aplicações** (Finder → Aplicações). Não a deixes em Descargas nem no Ambiente de trabalho — as atualizações só funcionam a partir de Aplicações.
4. **Abre a app a partir de Aplicações** (duplo clique em FastReport).
5. Se o macOS disser que a app **não pode ser aberta** porque o programador não está identificado, ou porque a Apple não a verificou:
   1. Abre **Definições do Sistema**.
   2. Vai a **Privacidade e segurança**.
   3. Desce até à secção **Segurança**.
   4. Deves ver uma mensagem sobre o FastReport. Clica **Abrir mesmo assim**.
   5. Confirma **Abrir** na janela que aparece.
6. Se ainda não abrir: no Finder, pasta Aplicações, **clica com o botão direito** (ou Control-clique) em FastReport → **Abrir** → **Abrir**.

Depois disto, o FastReport abre normalmente. Nas **Definições** da app podes procurar atualizações quando houver uma versão nova.

Requisitos: **macOS 14** ou posterior, Apple Silicon ou Intel.

---

## Para que serve

No terreno (inspeções, obras, relatórios fotográficos) as fotos saem da câmara misturadas. Classificar isso à mão no Finder é lento e falha nos nomes.

O FastReport cria um **projeto** a partir de um **mapa** (hoje: inspeção T1–T24 + General + Trash), importa as fotos para `Inbox/`, converte para JPEG 1024 e deixa classificar **só com o teclado**. Os ficheiros ficam nas pastas certas, com nomes previsíveis (`Inspecao1_T10_1.jpeg`). Se mexeres no Finder, a app acompanha.

Não há nuvem, contas nem IA. O valor está no teclado, no Finder e em 300+ fotos sem a app “possuir” as tuas imagens.

## Fluxo

1. **Novo projeto** — escolhes o mapa, a pasta-mãe e o nome do dia. A pasta fica com `fastreport.json`.
2. **Abrir projeto** — escolhes uma pasta que já tenha `fastreport.json`.
3. **Importar** — arrastar fotos ou escolher ficheiros. Originais fora do projeto não são apagados.
4. **Triagem** — uma foto de cada vez. `1`–`24` + Enter para T1–T24, `0` para General, `⌘⌫` para lixo, `⌘Z` para desfazer, `R` para rodar.
5. **Revisão** — grelha por pasta, reordenar e recategorizar.
6. **Finder** — o relatório futuro lê estas pastas. A app já fez a parte chata.

Idiomas: **português** (padrão) e **inglês**, nas Definições, sem mudar nomes de pastas no disco.

## Desenvolvimento

```bash
brew install xcodegen
xcodegen generate
open FastReport.xcodeproj
```

O esquema `FastReport` corre testes e a app. Mapa do código: `INDEX.md`. Regras para agentes: `AGENTS.md` e `.cursor/rules/index-first.mdc`. A versão pública actual é `v1.0.0`.

## Licença

[MIT](LICENSE) © 2026 FastReport

---

# FastReport (English)

Native **macOS** app that sorts work photos **in Finder**. It does not keep its own library — disk is the source of truth. It does not write the report; it prepares folders and filenames so the report can be built later.

**[Download FastReport](https://github.com/RobertRuas/FastReport/releases/latest/download/FastReport.zip)**

This is a third-party app, not from the App Store. After downloading:

1. Unzip `FastReport.zip`.
2. Drag `FastReport.app` into **Applications**.
3. Open it from Applications.
4. If macOS blocks it, open **System Settings → Privacy & Security**, scroll to **Security**, then **Open Anyway** and confirm **Open**. You can also Control-click the app in Applications → **Open**.

Create a project from a map (inspection T1–T24 + General + Trash), import to `Inbox/`, convert to JPEG 1024, then classify with the keyboard. Files stay on disk with stable names. Portuguese and English UI; folder names on disk stay in English.
