# Estratégia de testes

```
            ▲  Integração (dispositivo/emulador): fluxo principal
           ▲▲▲  Widget: telas com a pilha real offline + acessibilidade
        ▲▲▲▲▲▲▲  Unitários: domínio, ViewModels, repositórios, rede, parsing
```

Todos são **determinísticos**: relógio fixo (`FixedClock`), fuso fixo (`OffsetLocalCalendar`,
UTC−3), banco SQLite em memória, mercado fake sem latência, `sleep` injetado nas retentativas e
`fake_async` no debounce. Nenhum teste depende de rede, do fuso da máquina ou da hora atual.

| Camada | O que cobre | Onde |
|--------|-------------|------|
| Domínio | Cada regra numerada (RN-xx): saldo, totais, virada de dia por fuso e horário de verão, half-even, 100 mil transações, overflow, filtros, validação de período | `test/core`, `test/features/ledger/domain` |
| Rede | 429 com `Retry-After`, backoff, esgotamento, erros permanentes, cancelamento, rate limiter, deduplicação, logs sem chave — pela pilha Dio real com adapter roteirizado | `test/core/network`, `test/features/ledger/data/datasources` |
| Parsing | Fixture real da CoinGecko e payloads corrompidos | `test/features/ledger/data/dtos` |
| Extrato derivado | Determinismo, IDs estáveis, saldo nunca negativo, passado imutável, status que evoluem | `test/features/ledger/data/ledger` |
| Cache | Paginação keyset com empates, filtros SQL ≡ regra em memória, LIKE escapado, códigos de enum estáveis | `test/features/ledger/data/local` |
| Repositórios | TTL, deduplicação de sync, falha que preserva o cache, stream de estado | `test/features/ledger/data/repositories` |
| ViewModels | Latest-wins, debounce, paginação concorrente, recarga após sync, cancelamento ao sair | `test/features/*/…_view_model_test.dart` |
| Widgets | Carregando, vazio, vazio com filtros, erro, offline, ocultar saldo, copiar ID | `test/features/*/…_view_test.dart` |
| Acessibilidade | Área de toque, rótulos, contraste (claro/escuro), fonte 200% em 360 dp | `test/accessibility_test.dart` |
| Fluxo principal | Dashboard → extrato filtrado → detalhes → volta preservando estado → reinício | `test/flows`, `integration_test/` |

## Cobertura

```bash
flutter test --coverage
dart run tool/coverage.dart --min=70
```

O gate mede **domínio + ViewModels** (exigência do desafio): hoje ~99%. O CI publica o relatório
HTML como artefato.

## O que ficou sem cobertura (e por quê)

- **iOS em dispositivo:** fora do escopo de entrega (APK Android).
- **Migrações de banco:** só existe a versão 1 do schema; o primeiro `onUpgrade` virá com testes
  gerados por `drift_dev schema dump`.
- **Golden tests:** renderização difere entre Windows/Linux; adiados para rodar só no CI Linux.
- **Sincronização contra a API real:** não roda no CI (quota e instabilidade). O parsing usa uma
  resposta real da CoinGecko como fixture e a rede é testada com a pilha Dio e um adapter
  roteirizado, mas o fluxo completo com uma chave real (flavor `prod`) ainda não foi executado.
- **Plugins nativos reais:** `PluginConnectivityService`, `AppDatabase.open` (banco em disco),
  `shared_preferences` e `local_auth` não têm teste automatizado no aparelho. Nos testes, inclusive
  no de integração, são substituídos por conectividade fixa, banco em memória, preferências de
  teste e biometria falsa. `LocalAuthBiometricAuthenticator` tem teste unitário com o plugin
  simulado. Esses caminhos dependem de verificação manual em um aparelho.
- **APK de release:** o CI gera o build ofuscado, mas nenhum teste automatizado o executa. O teste
  de integração roda em modo debug, então o efeito de `--obfuscate` e do R8 em tempo de execução
  também depende de verificação manual.
