# O Dashboard Morreu. Longa Vida ao Genie: como o Analytics está mudando em 2025

**Por Marcela Monteiro Montenegro Gallo**
*Arquiteta de Dados e AI | 9x AWS Certified | 2x Databricks Certified*
*Ingram Micro Cloud — Databricks Partner*

*Data de publicação: março de 2026*

---

## Introdução

Deixa eu te contar uma história que se repetiu dezenas de vezes na minha carreira.

Eu estava numa reunião de alinhamento com o time de BI. Acabávamos de entregar um dashboard novo, semanas de trabalho, dados validados, visual impecável. O diretor comercial abriu, olhou por uns 30 segundos, e mandou uma mensagem no WhatsApp:

*"Marcela, mas e se eu quiser ver só as lojas do nordeste com ticket acima de R$ 500 nos últimos 45 dias?"*

Novo ticket. Nova semana. Novo dashboard.

Repeti esse ciclo por anos. E não era falta de competência do time, nem falta de vontade do negócio. Era uma limitação estrutural do modelo: o dashboard responde às perguntas que você sabia que ia fazer quando o construiu. O negócio se move mais rápido do que isso.

Quando comecei a trabalhar com Databricks de verdade, percebi que esse problema tinha solução. E a solução não é construir dashboards mais rápido. É mudar o modelo completamente.

O Databricks Genie é essa mudança. E neste artigo vou mostrar como construir uma arquitetura completa, da geração de dados até a visualização no celular com o Databricks One Mobile, usando Genie para análise em linguagem natural, com toda a infraestrutura provisionada via Terraform.

---

## Por que o modelo de dashboard está quebrando

O problema não é técnico. É de velocidade e autonomia.

Trabalhei anos construindo dashboards. Aprendi a fazer bem. Aprendi a fazer rápido. E mesmo assim, a fila de solicitações nunca diminuía. Porque cada dashboard novo gerava três perguntas novas que o dashboard não respondia.

O executivo não quer um painel. Ele quer uma resposta. E quer agora, no celular, enquanto está no aeroporto esperando o voo.

O Databricks One Mobile, combinado com o Genie, entrega exatamente isso: o usuário abre o app no celular, digita a pergunta em português, e recebe a resposta com gráfico em segundos. Sem abrir o laptop. Sem esperar o time de dados. Sem ticket.

---

## A Arquitetura: do dado bruto ao celular

```
Geração de Dados (Python/Databricks)
        ↓
Delta Lake — Modelo Medallion
  Bronze → Silver → Gold
        ↓
Unity Catalog (Governança + Lineage)
        ↓
Databricks SQL Warehouse
        ↓
AI/BI Dashboard (visualização tradicional)
        +
Genie Space (linguagem natural)
        ↓
Databricks One Mobile (iOS / Android)
```

A arquitetura tem quatro camadas:

**Dados:** Delta Lake com modelo Medallion. Bronze recebe os dados brutos, Silver limpa e valida, Gold agrega para consumo.

**Governança:** Unity Catalog centraliza metadados, controle de acesso e lineage. O Genie usa o catálogo para entender o contexto dos dados.

**Processamento:** Databricks SQL Warehouse executa as queries, tanto para dashboards quanto para as perguntas do Genie.

**Consumo:** AI/BI Dashboard para visualizações fixas e Genie Space para análise conversacional, ambos acessíveis via **Databricks One Mobile**, o app oficial do Databricks para iOS e Android.

---

## Passo a Passo: do zero ao celular

### Passo 1: Provisionar a infraestrutura com Terraform

O Terraform disponível junto a este artigo provisiona todo o ambiente Databricks necessário: workspace, Unity Catalog, SQL Warehouse, schemas e permissões. Execute:

```bash
cd terraform/
terraform init
terraform plan -var="databricks_host=https://SEU-WORKSPACE.azuredatabricks.net" \
               -var="databricks_token=SEU-TOKEN"
terraform apply
```

Em menos de 5 minutos você tem o ambiente completo provisionado.

### Passo 2: Gerar a massa de dados

Execute o notebook `01_gerar_dados.py` no Databricks. Ele cria 3 anos de dados sintéticos de vendas de uma rede de varejo com 500 lojas, 50 mil produtos e 2 milhões de transações por mês.

```python
# Resultado esperado:
# Bronze: 72 milhões de transações
# Silver: 71.2 milhões (após limpeza)
# Gold: tabelas agregadas por loja, produto, período e região
```

### Passo 3: Criar o AI/BI Dashboard

No Databricks UI: **SQL → Dashboards → Create Dashboard**

Conecte ao SQL Warehouse provisionado pelo Terraform e crie as visualizações principais:
- Vendas por região (mapa)
- Evolução mensal de receita (linha)
- Top 10 produtos (barras)
- Ticket médio por segmento (KPI cards)

### Passo 4: Configurar o Genie Space

No Databricks UI: **AI/BI → Genie → New Space**

1. Selecione as tabelas Gold como fonte de dados
2. Adicione instruções de contexto de negócio
3. Defina exemplos de perguntas e respostas esperadas
4. Publique o Space

### Passo 5: Acessar pelo Databricks One Mobile

Baixe o **Databricks One** na App Store (iOS) ou Google Play (Android). É o app oficial do Databricks, gratuito.

Faça login com as credenciais do seu workspace. O Genie Space aparece diretamente no app. Faça sua primeira pergunta:

*"Qual foi a loja com maior crescimento de vendas no último trimestre comparado ao mesmo período do ano anterior?"*

O Genie consulta os dados, gera o SQL, executa e retorna o resultado com visualização em segundos, direto na tela do celular. Sem laptop. Sem VPN. Sem esperar o time de dados.

---

## O que muda com o Genie

### Antes: ciclo de BI tradicional

```
Usuário pede análise → Ticket no backlog → Analista desenvolve (3-5 dias)
→ Review → Deploy → Usuário recebe → Pede ajuste → Ciclo recomeça
```

### Depois: Genie

```
Usuário faz pergunta → Genie responde em segundos
```

A diferença não é só de velocidade. É de autonomia. O usuário de negócio deixa de depender do time de dados para análises exploratórias. O time de dados deixa de ser um gargalo e passa a ser um habilitador, focando em qualidade de dados, governança e casos de uso estratégicos.

---

## Configurando o Genie para resultados melhores

O Genie funciona melhor quando você investe tempo na configuração do contexto. Três práticas que fazem diferença:

**1. Instruções de negócio claras**

```
Você é um assistente de analytics para uma rede de varejo.
- "Receita" sempre se refere ao valor líquido após devoluções
- "Período atual" significa os últimos 30 dias
- Quando perguntarem sobre "crescimento", compare sempre com o mesmo período do ano anterior
- Lojas com menos de 6 meses de operação são consideradas "novas" e devem ser sinalizadas
```

**2. Exemplos de perguntas e respostas**

Adicione 10-15 pares de pergunta/resposta esperada. O Genie usa esses exemplos para calibrar o comportamento e gerar SQL mais preciso.

**3. Trusted Assets**

Marque as queries SQL mais importantes como Trusted Assets. O Genie prioriza essas queries como base para responder perguntas similares, garantindo consistência com as métricas oficiais do negócio.

---

## Governança: quem pode perguntar o quê

O Genie respeita as permissões do Unity Catalog. Se um usuário não tem acesso a uma tabela, o Genie não vai usar essa tabela para responder perguntas desse usuário, mesmo que a pergunta seja relevante.

Isso significa que você pode ter um único Genie Space com múltiplos perfis de acesso:
- Gerente regional vê apenas dados da sua região
- Analista financeiro vê dados de receita mas não de RH
- Executivo vê tudo

Configure via Unity Catalog e o Genie herda automaticamente.

---

## Métricas de adoção: como medir o sucesso

Após implantar o Genie, monitore:

- **Perguntas por dia:** indica adoção pelos usuários de negócio
- **Taxa de satisfação:** o Genie tem thumbs up/down em cada resposta
- **Queries sem resposta:** perguntas que o Genie não conseguiu responder indicam gaps no contexto ou nos dados
- **Redução de tickets de BI:** o indicador mais importante de ROI

Em projetos que implementei, a redução de tickets de BI foi de 40-60% nos primeiros 3 meses após a implantação do Genie.

---

## Conclusão

O analytics está mudando. Não de forma gradual, mas de forma estrutural.

Passei anos no ciclo de tickets de BI. Aprendi muito nesse ciclo. Mas hoje, como Arquiteta de Dados e AI, sei que o papel do time de dados não é ser um gargalo de relatórios. É ser um habilitador de decisões.

O Databricks Genie com One Mobile é a materialização disso. O executivo faz a pergunta no celular. O Genie responde. O time de dados foca em qualidade, governança e casos de uso estratégicos.

O dashboard não vai desaparecer. Ele vai continuar sendo a camada de visualização para métricas fixas e relatórios executivos. Mas a análise exploratória, as perguntas ad-hoc, a investigação de anomalias, tudo isso vai migrar para interfaces conversacionais.

A empresa que entender isso primeiro vai ter uma vantagem competitiva real.

O Terraform e os notebooks deste artigo estão disponíveis no GitHub. Em menos de uma hora você tem o ambiente completo rodando, da geração de dados até o Genie respondendo perguntas no seu celular.

---

> Você ainda está preso no ciclo de tickets de BI? Me conta nos comentários qual foi a última vez que um executivo pediu "só mais um filtro" no dashboard. E compartilha esse artigo com alguém do seu time que precisa ver isso.

---

*Marcela Monteiro Montenegro Gallo é Arquiteta de Dados e AI na Ingram Micro Cloud, 9x AWS Certified e 2x Databricks Certified. Referência em arquitetura de dados moderna, Delta Lake e GenAI aplicada a dados.*
*LinkedIn: [linkedin.com/in/marcelagallo](https://linkedin.com/in/marcelagallo)*
*Instagram: [@mammgallo](https://instagram.com/mammgallo/)*
