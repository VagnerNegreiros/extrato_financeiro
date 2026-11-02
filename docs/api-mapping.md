# Integração com a CoinGecko e mapeamento para o domínio

## Por que um extrato "derivado"

A API indicada no desafio é de **mercado de criptomoedas**: não existe um endpoint de saldo ou
de extrato. Em vez de ignorá-la e usar só um mock, o app usa **cotações reais em BRL** e deriva,
de forma determinística, o extrato de uma conta que deposita, saca e negocia BTC, ETH e SOL.
Assim a integração exercita latência, payloads e limites reais (inclusive o 429 do plano gratuito),
e o domínio financeiro continua coerente e testável.

O código desse mapeamento fica todo em uma camada anti-corrupção:
[`LedgerFactory`](../lib/features/ledger/data/ledger/ledger_factory.dart).

## Endpoints

| Uso | Endpoint | Quando |
|-----|----------|--------|
| Extrato | `GET /coins/{id}/market_chart?vs_currency=brl&days=N&interval=daily` | 1× por ativo a cada sincronização (3 requisições) |
| Cotação atual | `GET /simple/price?ids={id}&vs_currencies=brl&include_24hr_change=true` | Tela de detalhes; cache de 60 s; cancelada ao sair da tela |

Autenticação pelo header `x-cg-demo-api-key`. Base URL obrigatoriamente HTTPS (validado em
[`AppConfig`](../lib/core/config/app_config.dart)).

## Do JSON ao domínio

```json
{ "prices": [[1793059200000, 430086.1803941016], ...] }
```

1. **Parsing defensivo** ([`market_dtos.dart`](../lib/features/ledger/data/dtos/market_dtos.dart)):
   cada número vira `Decimal` imediatamente (sem contas em `double`); pontos malformados
   (preço ≤ 0, timestamp implausível, tipo errado) são descartados e contados; o payload só é
   rejeitado se o formato estiver errado ou se mais da metade dos pontos for inválida.
2. **Preço do dia:** o primeiro ponto de cada dia UTC (00:00Z). O último ponto da API é a cotação
   parcial do momento e é ignorado.
3. **Geração determinística:**
   - um gerador pseudoaleatório **por dia** (mulberry32 com semente derivada da data), de modo que
     um dia nunca depende de quantos dias foram pedidos;
   - **início fixo:** o primeiro dia é gravado na primeira sincronização (hoje − 89 dias); as
     seguintes geram a partir dele, então transações passadas não mudam;
   - IDs estáveis e legíveis: `TX-20261030-03` (dia + sequência).

| Evento | Direção | Regra |
|--------|---------|-------|
| Saldo inicial | entrada | primeiro dia, R$ 20.000,00, sempre concluído |
| Depósito Pix · Salário | entrada | todo dia 5, R$ 3.000–6.000 |
| Pix recebido | entrada | 10% dos dias, R$ 100–1.500 |
| Saque Pix | saída | 5% dos dias, R$ 100–1.000 |
| Compra de {ativo} | saída | 30% por ativo/dia, R$ 50–2.000 → quantidade com 8 casas |
| Venda de {ativo} | entrada | 20% por ativo/dia, 10–60% da posição |
| Tarifa de corretagem | saída | 0,5% de cada compra/venda (mínimo R$ 0,01), logo após a operação |

- Valor = `quantidade × preço` em `Decimal`, convertido para centavos com *half-even*.
- **Saldo nunca negativo:** saídas só são geradas se cobertas por entradas com pelo menos 2 dias
  que certamente serão liquidadas (verificado por teste em 89 dias, de 7 em 7 horas).

## Status

Cada transação tem um sorteio fixo; o status depende dele e da idade (relógio injetado):

| Sorteio | Até 1 dia | Mais de 1 dia |
|---------|-----------|---------------|
| < 0,60 | pendente | concluída |
| 0,60–0,92 | concluída | concluída |
| 0,92–0,96 | concluída | estornada |
| ≥ 0,96 | falha | falha |

Pendentes liquidam com o tempo sem mudar de ID — a sincronização seguinte atualiza o status.

## Erros, limites e retentativas

| Situação | Tratamento | O que o usuário vê |
|----------|------------|--------------------|
| Sem rede / DNS | 3 retentativas com backoff | Banner "Você está offline" sobre o cache, ou "Sem conexão" |
| Timeout | 3 retentativas | "A conexão está lenta" |
| HTTP 429 | Respeita `Retry-After` (até 60 s) ou backoff exponencial com jitter; rate limiter local de 25 req/min | "Muitas requisições. Aguarde N segundos" |
| 502/503/504 | Backoff exponencial (1 s, 2 s, 4 s ±50%) | "Serviço indisponível" |
| 401/403 | Sem retentativa | "Configuração inválida" |
| JSON inválido | Sem retentativa | "Dados inesperados" |

Só requisições GET são repetidas automaticamente.

## Modo offline de desenvolvimento

Com `APP_FLAVOR=dev`, o [`FakeMarketDataSource`](../lib/features/ledger/data/datasources/fake_market_data_source.dart)
gera JSON no mesmo formato da API (preços sintéticos e determinísticos) e passa pelo mesmo parser.
`FAKE_FAILURE=network|rate_limit|server` simula cenários adversos para demonstração e testes.
