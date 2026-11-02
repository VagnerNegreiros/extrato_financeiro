# Segurança

Riscos considerados (referência: OWASP MASVS) e o que foi feito.

| Risco | Mitigação aplicada | Planejado para produção |
|-------|--------------------|-------------------------|
| Segredos no código | Chave só via `--dart-define-from-file` com arquivo ignorado pelo Git; exemplo versionado em `config/env.example.json` | Chave em um proxy backend (o app não carrega segredo nenhum) |
| Segredo extraível do binário | Chave Demo gratuita de baixo risco; documentado | Proxy backend + App Check/Play Integrity |
| Tráfego em texto claro | `AppConfig` rejeita URL sem HTTPS; `network_security_config.xml` bloqueia cleartext e confia só nas CAs do sistema; `usesCleartextTraffic=false` | Certificate pinning (avaliado: exige plano de rotação de certificado do provedor) |
| Dados financeiros em backup | `allowBackup=false` e `data_extraction_rules.xml` excluem banco e preferências de backup e transferência | Criptografar o banco (SQLCipher, chave no Keystore) |
| Logs vazando dados | `AppLogger` só registra em debug e mascara a chave da API e valores em R$; o log HTTP omite query string; `Transaction.toString` não inclui valor nem descrição; R8 remove `Log.v/d` nativos | Observabilidade com scrubbing (Sentry `beforeSend`) |
| Entrada do usuário | Busca: trim, 2–50 caracteres, `%` e `_` escapados no `LIKE`; período personalizado validado (RN-18); ID do ativo validado contra *path injection* | — |
| Respostas maliciosas ou corrompidas | Parsing defensivo, sem `dynamic` solto, invariantes na entidade `Transaction` | Testes de contrato com o backend |
| Engenharia reversa | `--obfuscate --split-debug-info` (Dart) + R8 `minify`/`shrinkResources` (Java/Kotlin); enums persistidos com códigos explícitos (nomes ofuscados não quebram o banco) | Root/jailbreak detection, FLAG_SECURE nas telas de saldo |
| Dados sensíveis em armazenamento | Nada sensível é salvo: só o cache do extrato simulado e a preferência de ocultar saldo | `flutter_secure_storage` para tokens quando houver login |

## Build de release

```bash
flutter build apk --release --obfuscate --split-debug-info=build/symbols \
  --extra-gen-snapshot-options=--strip --dart-define-from-file=config/prod.json
```

Os símbolos de `build/symbols` devem ser guardados (artefato do CI) para `flutter symbolize`.
Sem `android/key.properties`, o release é assinado com a chave de debug — aceitável para QA
interno, nunca para publicação (ver `android/key.properties.example`).
