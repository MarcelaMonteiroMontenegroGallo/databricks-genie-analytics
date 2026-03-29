##O analytics saiu do dashboard. Agora cabe no seu celular (Genie + Databricks)
**Por Marcela Monteiro Montenegro Gallo**
*Arquiteta de Dados e AI | 9x AWS Certified | 2x Databricks Certified*
*Ingram Micro Cloud — Databricks Partner*

*Data de publicação: março de 2026*

---

## Introdução

Por anos, o ciclo era sempre o mesmo. O analista de negócio pede um dashboard. O time de dados passa uma semana construindo. O dashboard vai para o ar. Três meses depois, o executivo quer uma visão diferente. Novo ticket. Nova semana. Novo dashboard.

Esse modelo está chegando ao fim.

Não porque dashboards deixaram de ter valor. Mas porque a expectativa mudou. O usuário de negócio hoje quer fazer uma pergunta e receber uma resposta, não navegar por 15 filtros em um painel estático. Quer acessar do celular, em linguagem natural, sem depender do time de dados para cada nova análise.

O Databricks Genie é a resposta para essa mudança. E neste artigo vou mostrar como construir uma arquitetura completa, da geração de dados até a visualização no celular, usando Databricks, Delta Lake e Genie, com toda a infraestrutura provisionada via Terraform.

---

## Por que o modelo de dashboard está quebrando

O problema não é técnico. É de velocidade e autonomia.

Um dashboard bem construído responde às perguntas que você sabia que ia fazer quando o construiu. Mas o negócio se move mais rápido do que o ciclo de desenvolvimento de BI. Quando o CFO pergunta "qual foi o impacto da campanha de março nas regiões onde temos menos de 3 lojas?", essa pergunta não estava no backlog quando o dashboard foi criado.

O resultado é o gargalo que todo time de dados conhece: fila de solicitações de BI, analistas sobrecarregados, usuários frustrados esperando semanas por uma análise que deveria levar minutos.

O Genie resolve isso de uma forma elegante: você descreve os dados uma vez, define o contexto de negócio, e qualquer usuário pode fazer perguntas em linguagem natural e receber respostas com gráficos, tabelas e insights, direto no celular.

---

## A Arquitetura: do dado bruto ao celular

```
Geração de Dados (Python)
        ↓
Delta Lake — Modelo Medallion
  Bronze → Silver → Gold
        ↓
Unity Catalog (Governança)
        ↓
Databricks SQL Warehouse
        ↓
AI/BI Dashboard (visualização tradicional)
        +
Genie Space (linguagem natural)
        ↓
Mobile (app Databricks ou browser)
```

A arquitetura tem quatro camadas:

**Dados:** Delta Lake com modelo Medallion. Bronze recebe os dados brutos, Silver limpa e valida, Gold agrega para consumo.

**Governança:** Unity Catalog centraliza metadados, controle de acesso e lineage. O Genie usa o catálogo para entender o contexto dos dados.

**Processamento:** Databricks SQL Warehouse executa as queries, tanto para dashboards quanto para as perguntas do Genie.

**Consumo:** AI/BI Dashboard para visualizações fixas e Genie Space para análise conversacional, ambos acessíveis via mobile.

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

### Passo 5: Acessar pelo celular

Baixe o app Databricks no iOS ou Android, ou acesse via browser mobile. O Genie Space funciona perfeitamente em telas pequenas. Faça sua primeira pergunta:

*"Qual foi a loja com maior crescimento de vendas no último trimestre comparado ao mesmo período do ano anterior?"*

O Genie consulta os dados, gera o SQL, executa e retorna o resultado com visualização em segundos.

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

O dashboard não vai desaparecer. Ele vai continuar sendo a camada de visualização para métricas fixas e relatórios executivos. Mas a análise exploratória, as perguntas ad-hoc, a investigação de anomalias, tudo isso vai migrar para interfaces conversacionais como o Genie.

A empresa que entender isso primeiro vai ter uma vantagem competitiva real: usuários de negócio mais autônomos, time de dados mais estratégico, e decisões mais rápidas.

O Terraform e os notebooks deste artigo estão disponíveis no GitHub. Em menos de uma hora você tem o ambiente completo rodando, da geração de dados até o Genie respondendo perguntas no seu celular.

---

> Se esse artigo foi útil, compartilha com alguém do seu time que ainda está preso no ciclo de tickets de BI. E me conta nos comentários: qual foi a primeira pergunta que você fez para o Genie?

---

*Marcela Monteiro Montenegro Gallo é Arquiteta de Dados e AI na Ingram Micro Cloud, 9x AWS Certified e 2x Databricks Certified.*
*LinkedIn: [linkedin.com/in/marcelagallo](https://linkedin.com/in/marcelagallo)*
*Instagram: [@mammgallo](https://instagram.com/mammgallo/)*
