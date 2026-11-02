# ADR-0001 — MVVM em camadas, organizado por funcionalidade

**Status:** aceito

**Contexto.** O desafio pede MVVM com separação entre apresentação, domínio e dados, e uma base
pronta para crescer em equipe.

**Decisão.** Três camadas (apresentação → domínio ← dados) dentro de pastas por funcionalidade
(`features/ledger`, `dashboard`, `statement`, `transaction_details`, `preferences`). O domínio é
Dart puro; um teste de arquitetura impede imports proibidos.

**Consequências.** Cada pessoa trabalha numa pasta com pouco conflito; regras financeiras são
testáveis sem Flutter. Custo: mais arquivos que um app de uma camada só.

**Alternativas descartadas.** Pastas por camada (`lib/data`, `lib/domain`…), que espalham uma
funcionalidade pelo projeto; módulos/pacotes separados (melos), cedo demais para o tamanho atual
— é a evolução natural com mais times.
