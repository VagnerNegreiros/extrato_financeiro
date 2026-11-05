# Fluxo — Extrato e Gestão Financeira

Aplicativo Flutter para consultar o saldo, visualizar e filtrar as transações de uma conta digital
que movimenta criptoativos em BRL, usando cotações reais da [CoinGecko](https://www.coingecko.com/en/api).

- **Dashboard:** saldo disponível (com opção de ocultar, lembrada entre sessões; para revelar,
  o app pede biometria ou o bloqueio de tela do aparelho), entradas,
  saídas e resultado do período (7, 30, 90 dias ou personalizado), gráfico de barras e últimas
  transações.
- **Extrato:** agrupado por dia, filtros combinados (tipo, status, período), busca com debounce,
  scroll infinito por cursor; filtros e posição são mantidos ao abrir uma transação e voltar.
- **Detalhes:** todos os campos e metadados, cópia do identificador e cotação atual do ativo.
- **Resiliência:** cache local como fonte única de verdade, funcionamento offline com aviso de
  dados desatualizados, retentativa com backoff para 429/5xx e deduplicação de requisições.

## Documentação

| Documento | Conteúdo |
|-----------|----------|
| [docs/architecture.md](docs/architecture.md) | Camadas, fluxo de dados, estado, cache, erros, performance, trade-offs |
| [docs/api-mapping.md](docs/api-mapping.md) | Como as respostas da CoinGecko viram o extrato |
| [docs/security.md](docs/security.md) | Riscos mobile e mitigações |
| [docs/testing.md](docs/testing.md) | Estratégia de testes, cobertura e lacunas |
| [docs/adr/](docs/adr/) | Decisões técnicas (ADRs) |

## Pré-requisitos

| Ferramenta | Versão |
|------------|--------|
| Flutter | **3.47.9** (canal stable) |
| Dart | 3.13.7 |
| JDK | 17 ou superior |
| Android SDK | 36, com `cmdline-tools` e licenças aceitas (`flutter doctor --android-licenses`) |

## Configuração

As configurações vêm de um arquivo JSON **ignorado pelo Git**, passado com
`--dart-define-from-file`:

```bash
cp config/env.example.json config/dev.json
```

| Chave | Descrição |
|-------|-----------|
| `APP_FLAVOR` | `dev`: dados offline determinísticos, sem rede nem chave · `prod`: CoinGecko |
| `COINGECKO_BASE_URL` | URL base da API (precisa ser HTTPS) |
| `COINGECKO_API_KEY` | Chave **Demo** gratuita da CoinGecko, obrigatória em `prod` |
| `FAKE_FAILURE` | Só em `dev`: `none`, `network`, `rate_limit` ou `server` |

Para usar a API real, crie a chave Demo no painel da CoinGecko e um `config/prod.json` com
`APP_FLAVOR` = `prod` e a chave preenchida.

## Executar

```bash
flutter pub get
dart run build_runner build
flutter run --dart-define-from-file=config/dev.json
```

O código gerado (`*.freezed.dart`, `*.g.dart`) não é versionado: rode o `build_runner` depois de
clonar e sempre que alterar estados, entidades ou o schema do banco.

### Demonstrar cenários adversos (flavor `dev`)

1. Rode uma vez com `FAKE_FAILURE` = `none` para popular o cache.
2. Troque para `network` ou `rate_limit` e rode de novo: o app mostra os dados salvos com o aviso
   correspondente; puxe para atualizar para ver a mensagem de erro.
3. Em uma instalação limpa com `network`, aparece o estado "Sem conexão" com "Tentar novamente".

## Testes e qualidade

```bash
dart format --set-exit-if-changed lib test
flutter analyze --fatal-infos
flutter test --coverage
dart run tool/coverage.dart --min=70
```

- Mais de 300 testes unitários, de widget e de acessibilidade, todos determinísticos.
- O gate de cobertura mede domínio + ViewModels (hoje ~99%) e gera `coverage/lcov_gate.info`;
  para HTML: `genhtml coverage/lcov_gate.info -o coverage/html`.
- Teste de integração do fluxo principal (precisa de um emulador ou aparelho conectado):

```bash
flutter test integration_test --dart-define-from-file=config/env.example.json
```

## Gerar o APK de release

O APK pronto para instalar está no [GitHub Release](https://github.com/VagnerNegreiros/extrato_financeiro/releases/latest).
Para gerar localmente, sem precisar de chave de API:

```bash
flutter build apk --release --obfuscate --split-debug-info=build/symbols --extra-gen-snapshot-options=--strip --dart-define-from-file=config/dev.json
```

- Para usar a API real, troque por `config/prod.json` (veja [Configuração](#configuração)).
- Saída: `build/app/outputs/flutter-apk/app-release.apk` (universal). Para APKs menores por
  arquitetura, acrescente `--split-per-abi` (arm64 ≈ 20 MB; o universal tem ~58 MB porque leva
  as bibliotecas nativas de 3 arquiteturas sem compressão, para carregamento por `mmap`).
- Guarde `build/symbols` para decodificar stack traces com `flutter symbolize`.
- Assinatura: com `android/key.properties` (veja `android/key.properties.example`) usa a sua
  keystore; sem ele, usa a chave de debug, adequada só para QA interno.

## CI

O [GitHub Actions](.github/workflows/ci.yml) roda em cada push e pull request:

1. formatação, `flutter analyze --fatal-infos` e testes com cobertura;
2. gate de cobertura (≥ 70%) e relatório HTML como artefato;
3. teste de integração em emulador Android;
4. APK de release ofuscado e símbolos como artefatos. Com o segredo `COINGECKO_API_KEY`
   configurado, o APK usa a API real; sem ele, o flavor offline.

Tags `v*` (por exemplo `v1.0.0`) publicam o APK em um GitHub Release.

## Estrutura

```
lib/
├── app/        composição (DI), rotas, tema, coordenador de sincronização
├── core/       dinheiro, datas e fuso, Result/Failure, rede, logs, configuração
├── features/   ledger (domínio + dados) · dashboard · statement · transaction_details · preferences
└── shared/     componentes e textos comuns
test/           espelha lib/ + flows/ (fluxo principal) + helpers/
integration_test/
tool/coverage.dart
docs/
```
