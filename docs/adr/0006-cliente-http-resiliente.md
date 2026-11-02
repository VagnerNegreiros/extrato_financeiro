# ADR-0006 — Cliente HTTP com rate limit, retentativa e deduplicação

**Status:** aceito

**Contexto.** O plano gratuito da CoinGecko limita requisições (~30/min) e responde 429; a rede
móvel é instável.

**Decisão.** Dio com interceptadores em ordem: rate limiter local (token bucket, 25/min) →
retentativa (só GET; 429/502/503/504 e falhas de conexão; até 3 vezes; 1 s·2ⁿ com jitter de
50–100%, teto de 16 s; `Retry-After` prevalece até 60 s) → log sem segredos. Sincronizações
simultâneas compartilham a mesma requisição; a cotação dos detalhes é cancelada ao sair da tela.

**Consequências.** O app evita o 429 em vez de só reagir a ele, e falhas transitórias não chegam
ao usuário. Toda a pilha é testada com um adapter HTTP roteirizado e `sleep` injetado.

**Alternativas descartadas.** `http` puro (cancelamento e interceptadores feitos à mão);
retentar POSTs (não são idempotentes); circuit breaker (complexidade sem ganho com 3 endpoints).
