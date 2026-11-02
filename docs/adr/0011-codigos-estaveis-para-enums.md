# ADR-0011 — Códigos explícitos para enums persistidos

**Status:** aceito

**Contexto.** O release é gerado com `--obfuscate`, que renomeia identificadores; o próprio
Flutter avisa que `Enum.toString` passa a devolver nomes ofuscados. O banco guardava status,
direção e categoria pelo nome do enum, e a configuração era lida comparando com o nome.

**Decisão.** Conversores explícitos (`EnumCodeConverter`) gravam códigos fixos (`crypto_buy`,
`completed`…) e a configuração usa mapas de código → valor. Um código desconhecido no banco vira
falha de cache, não um crash.

**Consequências.** Renomear um valor no código não quebra dados já gravados, e o build ofuscado
lê o mesmo banco que o debug. Custo: um mapa por enum persistido.

**Alternativas descartadas.** `textEnum`/`Enum.name` (dependem do nome do identificador);
`intEnum` (quebra silenciosamente se a ordem dos valores mudar).
