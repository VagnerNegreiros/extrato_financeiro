# ADR-0002 — Riverpod 3 para estado e injeção de dependência

**Status:** aceito

**Contexto.** ViewModels precisam de estado imutável, dependências substituíveis em teste e
reação a eventos globais (sincronização) sem perder o estado local (filtros, páginas).

**Decisão.** `Notifier` do Riverpod como ViewModel, com estado `freezed`; os próprios providers
são a injeção de dependência, compostos em `app/providers.dart`.

**Consequências.** Uma única ferramenta para DI e estado; `ProviderContainer.test` e
`overrideWithValue` deixam os testes simples; `autoDispose` libera a tela de detalhes (e cancela a
requisição de cotação) ao sair; não depende de `BuildContext`.

**Alternativas descartadas.**
- **Bloc/Cubit:** ótimo, mas eventos e classes extras para pouco ganho aqui, e ainda exigiria um
  container de DI (get_it).
- **Provider + ChangeNotifier:** estado mutável por padrão e notificação manual.
- **GetX:** acoplamento global e pouca testabilidade.
