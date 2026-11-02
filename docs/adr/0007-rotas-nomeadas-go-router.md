# ADR-0007 — Rotas nomeadas planas com go_router

**Status:** aceito

**Contexto.** Os detalhes precisam ser abertos por rota nomeada, e voltar ao extrato deve manter
filtros e posição.

**Decisão.** Três rotas de primeiro nível (`dashboard` `/`, `statement` `/extrato`,
`transactionDetails` `/transacao/:id`) abertas com `pushNamed`. O ViewModel do extrato vive
durante a sessão e guarda filtros, páginas e posição de rolagem; um link direto para um ID
inexistente mostra "não encontrada" e volta ao dashboard.

**Consequências.** O botão voltar sempre leva à tela de origem (dashboard ou extrato), e deep
links funcionam. Rotas aninhadas foram evitadas porque construiriam o extrato atrás de detalhes
abertos a partir do dashboard.

**Alternativas descartadas.** Navigator 1.0 com `onGenerateRoute` (sem deep link declarativo);
rotas aninhadas (pilha de navegação errada para este fluxo).
