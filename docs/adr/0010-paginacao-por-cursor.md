# ADR-0010 — Paginação por cursor (keyset)

**Status:** aceito

**Contexto.** O extrato tem scroll infinito e pode ser atualizado por uma sincronização enquanto
o usuário rola.

**Decisão.** Ordenação `occurred_at DESC, id DESC` com índice; a próxima página começa depois do
par (data, id) do último item. O cursor é opaco (base64url) e uma linha extra (`LIMIT n + 1`)
indica se há mais páginas. Após uma sincronização, o extrato recarrega a mesma quantidade de
linhas já exibidas, sem perder a posição.

**Consequências.** Páginas estáveis mesmo com inserções e empates de horário; custo
O(log n) por página. Não dá para pular direto para a "página 7".

**Alternativas descartadas.** `OFFSET/LIMIT` (pula ou repete linhas quando o conjunto muda e fica
mais lento no fim da lista); carregar tudo em memória (não escala).
