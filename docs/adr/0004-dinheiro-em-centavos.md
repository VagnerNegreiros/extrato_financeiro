# ADR-0004 — Dinheiro em centavos inteiros

**Status:** aceito

**Contexto.** `double` não representa 0,1 exatamente; valores precisam ser exatos e coerentes em
todas as telas.

**Decisão.** `Money(int cents)` em todo o domínio, estado, banco e UI. `Decimal` aparece só na
fronteira (preço × quantidade da API), convertido com arredondamento *half-even*. A formatação
pt-BR é feita a partir do inteiro, sem `NumberFormat` (que exigiria `double`). Somas detectam
overflow de 64 bits em vez de dar a volta. O gráfico é o único lugar com `double`, apenas para a
altura das barras; todo texto vem de `Money`.

**Consequências.** Contas exatas, rápidas e fáceis de serializar. Exige cuidado na conversão de
entrada (testada com casos de empate e valores negativos).

**Alternativas descartadas.** `double` (impreciso); `Decimal` em tudo (mais lento e verboso, sem
ganho para valores em BRL).
