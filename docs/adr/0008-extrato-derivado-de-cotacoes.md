# ADR-0008 — Extrato derivado de cotações reais

**Status:** aceito

**Contexto.** A API indicada (CoinGecko) não tem saldo nem extrato; usar só um mock deixaria a
integração real de fora.

**Decisão.** Cotações diárias reais em BRL alimentam um gerador determinístico de extrato (camada
anti-corrupção `LedgerFactory`): PRNG próprio por dia, início fixo gravado no cache, IDs estáveis,
status que dependem só da idade. Um flavor `dev` gera JSON no mesmo formato da API, sem rede.
Detalhes em [api-mapping.md](../api-mapping.md).

**Consequências.** Rede, limites e payloads reais são exercitados; o passado não muda entre
sincronizações; o saldo nunca fica negativo. Limitação: os dados financeiros são simulados.

**Alternativas descartadas.** json-server/mock puro (sem integração real); usar `Random(seed)` do
Dart (sequência não garantida entre versões do SDK); janela deslizante de 90 dias sem início fixo
(mudaria transações antigas a cada dia).
