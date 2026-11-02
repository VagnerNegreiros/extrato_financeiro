# ADR-0003 — Erros tipados com `Result` e `sealed class`

**Status:** aceito

**Contexto.** Nenhuma exceção pode chegar crua à interface, e cada falha precisa de uma mensagem
e uma ação próprias (tentar novamente, aguardar N segundos…).

**Decisão.** Datasources lançam exceções tipadas; repositórios as convertem em uma hierarquia
`sealed` de `Failure` e devolvem `Result<T>` (`Success`/`Err`). A UI usa `switch` exaustivo e
`describeFailure` para os textos.

**Consequências.** O compilador obriga a tratar todos os casos; um tipo novo de falha quebra o
build até ser tratado. Pouco código extra por usar recursos nativos do Dart 3.

**Alternativas descartadas.** `Either` de `fpdart`/`dartz` (dependência e vocabulário funcional
desnecessários); exceções com `try/catch` na UI (fácil de esquecer um caso).
