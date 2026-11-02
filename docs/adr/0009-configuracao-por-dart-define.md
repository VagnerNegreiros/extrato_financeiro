# ADR-0009 — Configuração por `--dart-define-from-file`

**Status:** aceito

**Contexto.** Nenhuma chave pode ficar no código ou no Git; é preciso alternar entre dados reais e
offline.

**Decisão.** Um arquivo JSON ignorado pelo Git (`config/*.json`, com exemplo versionado em
`config/env.example.json`) é passado a `--dart-define-from-file`. `AppConfig` valida na
inicialização: HTTPS obrigatório, chave obrigatória em `prod`, valores conhecidos — e um build
mal configurado mostra uma tela de erro em vez de quebrar. `APP_FLAVOR` escolhe entre `dev`
(offline) e `prod` (CoinGecko) com um único `main.dart`.

**Consequências.** Sem arquivo `.env` empacotado como asset legível. Os valores ficam no binário,
o que é aceitável só para a chave Demo gratuita (ver [security.md](../security.md)).

**Alternativas descartadas.** `flutter_dotenv` (o `.env` vira asset no APK); `productFlavors`
com vários `main_*.dart` (duplicação sem ganho hoje — é uma evolução possível).
