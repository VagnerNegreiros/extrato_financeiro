# Fluxo — Extrato e Gestão Financeira

Aplicativo Flutter para consultar saldo, visualizar e filtrar transações de uma conta digital
que movimenta criptoativos em BRL, usando cotações reais da [CoinGecko](https://www.coingecko.com/en/api).

> Projeto em desenvolvimento. Arquitetura, decisões (ADRs) e mapeamento da API serão
> documentados em `docs/`.

## Pré-requisitos

| Ferramenta | Versão |
|------------|--------|
| Flutter    | **3.47.9** (stable) |
| Dart       | 3.13.7 |
| JDK        | 17+ |
| Android SDK | 36 |

## Configuração

A configuração é feita por `--dart-define-from-file`, com um arquivo **ignorado pelo Git**:

```bash
cp config/env.example.json config/dev.json
```

| Chave | Descrição |
|-------|-----------|
| `APP_FLAVOR` | `dev` (dados locais determinísticos, sem rede) ou `prod` (CoinGecko) |
| `COINGECKO_BASE_URL` | URL base da API; precisa ser HTTPS |
| `COINGECKO_API_KEY` | chave Demo da CoinGecko (obrigatória em `prod`) |
| `FAKE_FAILURE` | apenas `dev`: `none`, `network`, `rate_limit`, `server` |

## Executar

```bash
flutter pub get
dart run build_runner build
flutter run --dart-define-from-file=config/dev.json
```

## Qualidade

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test --coverage
```

## APK de release

```bash
flutter build apk --release --obfuscate --split-debug-info=build/symbols --dart-define-from-file=config/prod.json
```
