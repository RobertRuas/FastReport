# FastReport

**App nativa para macOS** que organiza fotos de trabalho **no Finder**. Não cria uma biblioteca própria: o disco é a fonte da verdade. O relatório em si não é gerado aqui — a app prepara pastas, nomes e ordem para o relatório futuro ser rápido.

[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-000000?logo=apple&logoColor=white)](https://github.com/RobertRuas/FastReport/releases/latest)
[![Swift 6](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)](https://www.swift.org)
[![Última versão](https://img.shields.io/github/v/release/RobertRuas/FastReport?label=versão)](https://github.com/RobertRuas/FastReport/releases/latest)

**[Descarregar a última versão](https://github.com/RobertRuas/FastReport/releases/latest/download/FastReport.zip)** · [Notas de lançamento](https://github.com/RobertRuas/FastReport/releases/latest) · [Página do produto](https://robertruas.github.io/FastReport/)

---

## Para que serve

No terreno (inspeções, obras, relatórios fotográficos) as fotos saem da câmara misturadas. Classificar isso à mão no Finder é lento e falha nos nomes.

O FastReport cria um **projeto** a partir de um **mapa** (hoje: inspeção T1–T24 + General + Trash), importa as fotos para `Inbox/`, converte para JPEG 1024 e deixa classificar **só com o teclado**. Os ficheiros ficam nas pastas certas, com nomes previsíveis (`Inspecao1_T10_1.jpeg`). Se mexeres no Finder, a app acompanha.

Não há nuvem, contas nem IA. O valor está no teclado, no Finder e em 300+ fotos sem a app “possuir” as tuas imagens.

## Fluxo

1. **Novo projeto** — escolhes o mapa, a pasta-mãe e o nome do dia.
2. **Importar** — arrastar fotos ou escolher ficheiros. Originais fora do projeto não são apagados.
3. **Triagem** — uma foto de cada vez. `1`–`24` + Enter para T1–T24, `0` para General, `⌘⌫` para lixo, `⌘Z` para desfazer, `R` para rodar.
4. **Revisão** — grelha por pasta, reordenar e recategorizar.
5. **Finder** — o relatório futuro lê estas pastas. A app já fez a parte chata.

Idiomas: **português** (padrão) e **inglês**, nas Definições, sem mudar nomes de pastas no disco.

## Requisitos

- macOS 14 ou posterior
- Apple Silicon ou Intel
- Distribuição fora da App Store (GitHub Releases + atualizações Sparkle)

Na primeira abertura noutro Mac, o sistema pode avisar que o programador não está identificado. Clica com o botão direito na app → **Abrir**. Depois **copia o FastReport para a pasta Aplicações** e abre-o de lá — as atualizações só funcionam nessa localização. As versões seguintes aparecem em **Definições → Procurar atualizações…** e só instalam quando confirmas.

## Desenvolvimento

```bash
brew install xcodegen
xcodegen generate
open FastReport.xcodeproj
```

O esquema `FastReport` corre testes e a app. Releases `vX.Y.Z` no GitHub disparam o empacotamento, o `appcast.xml` do Sparkle e o zip.

## Licença

[MIT](LICENSE) © 2026 FastReport

---

# FastReport (English)

Native **macOS** app that sorts work photos **in Finder**. It does not keep its own library — disk is the source of truth. It does not write the report; it prepares folders and filenames so the report can be built later.

**[Download latest](https://github.com/RobertRuas/FastReport/releases/latest/download/FastReport.zip)**

Create a project from a map (inspection T1–T24 + General + Trash), import to `Inbox/`, convert to JPEG 1024, then classify with the keyboard. Files stay on disk with stable names. Portuguese and English UI; folder names on disk stay in English.
