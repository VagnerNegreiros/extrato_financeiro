# ADR-0005 — Cache Drift (SQLite) como fonte única de verdade

**Status:** aceito

**Contexto.** O app precisa funcionar sem rede, filtrar, buscar e paginar, e mostrar os mesmos
valores em todas as telas.

**Decisão.** Offline-first: todas as telas leem do SQLite via Drift. A rede só alimenta o cache;
cada sincronização substitui o extrato em uma transação. O estado da sincronização é um stream
que as telas observam.

**Consequências.** Filtros, busca e paginação em SQL com índice; leitura instantânea ao abrir;
consistência garantida por ter uma única fonte. Custo: geração de código e um schema a migrar.

**Alternativas descartadas.** Hive/Isar (consultas compostas e paginação mais limitadas);
cache em memória (perde tudo ao fechar o app); JSON em `shared_preferences` (sem consultas e
reescrita completa a cada mudança).
