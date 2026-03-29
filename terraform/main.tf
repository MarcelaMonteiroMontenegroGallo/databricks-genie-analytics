terraform {
  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.38"
    }
  }
}

provider "databricks" {
  host  = var.databricks_host
  token = var.databricks_token
}

# ─────────────────────────────────────────────
# VARIÁVEIS
# ─────────────────────────────────────────────

variable "databricks_host" {
  description = "URL do workspace Databricks (ex: https://xxx.azuredatabricks.net)"
  type        = string
}

variable "databricks_token" {
  description = "Token de acesso pessoal do Databricks"
  type        = string
  sensitive   = true
}

variable "catalog_name" {
  description = "Nome do catalog no Unity Catalog"
  type        = string
  default     = "analytics_demo"
}

variable "schema_name" {
  description = "Nome do schema principal"
  type        = string
  default     = "vendas"
}

variable "warehouse_size" {
  description = "Tamanho do SQL Warehouse"
  type        = string
  default     = "Small"
}

# ─────────────────────────────────────────────
# SQL WAREHOUSE
# ─────────────────────────────────────────────

resource "databricks_sql_endpoint" "analytics" {
  name             = "analytics-genie-warehouse"
  cluster_size     = var.warehouse_size
  max_num_clusters = 3
  auto_stop_mins   = 30

  tags {
    custom_tags {
      key   = "project"
      value = "genie-analytics"
    }
  }
}

# ─────────────────────────────────────────────
# UNITY CATALOG — CATALOG E SCHEMAS
# ─────────────────────────────────────────────

resource "databricks_catalog" "analytics" {
  name    = var.catalog_name
  comment = "Catalog para demo de analytics com Genie"

  properties = {
    purpose = "analytics-demo"
  }
}

resource "databricks_schema" "bronze" {
  catalog_name = databricks_catalog.analytics.name
  name         = "bronze"
  comment      = "Dados brutos — camada Raw"
}

resource "databricks_schema" "silver" {
  catalog_name = databricks_catalog.analytics.name
  name         = "silver"
  comment      = "Dados limpos e validados — camada Trusted"
}

resource "databricks_schema" "gold" {
  catalog_name = databricks_catalog.analytics.name
  name         = "gold"
  comment      = "Dados agregados para consumo — camada Refined"
}

# ─────────────────────────────────────────────
# PERMISSÕES NO CATALOG
# ─────────────────────────────────────────────

resource "databricks_grants" "catalog_usage" {
  catalog = databricks_catalog.analytics.name

  grant {
    principal  = "account users"
    privileges = ["USE_CATALOG"]
  }
}

resource "databricks_grants" "gold_select" {
  schema = "${databricks_catalog.analytics.name}.${databricks_schema.gold.name}"

  grant {
    principal  = "account users"
    privileges = ["USE_SCHEMA", "SELECT"]
  }
}

# ─────────────────────────────────────────────
# NOTEBOOK: GERAÇÃO DE DADOS
# ─────────────────────────────────────────────

resource "databricks_notebook" "gerar_dados" {
  path     = "/Shared/genie-analytics/01_gerar_dados"
  language = "PYTHON"
  content_base64 = base64encode(<<-EOT
# Databricks notebook source
# MAGIC %md
# MAGIC # 01 — Geração de Dados Sintéticos
# MAGIC Cria massa de dados de vendas para demo do Genie

# COMMAND ----------
from pyspark.sql import functions as F
from pyspark.sql.types import *
import random

CATALOG = "${var.catalog_name}"
spark.sql(f"USE CATALOG {CATALOG}")

# COMMAND ----------
# MAGIC %md ## Bronze: Transações brutas

# COMMAND ----------
spark.sql(f"""
CREATE TABLE IF NOT EXISTS {CATALOG}.bronze.transacoes_raw (
  transacao_id  BIGINT,
  loja_id       INT,
  produto_id    INT,
  quantidade    INT,
  valor_bruto   DECIMAL(18,2),
  desconto      DECIMAL(18,2),
  data_venda    DATE,
  hora_venda    TIMESTAMP,
  canal         STRING,
  status        STRING,
  regiao        STRING,
  _ingestion_ts TIMESTAMP
)
USING DELTA
TBLPROPERTIES ('delta.enableChangeDataFeed' = 'true')
""")

# Gera 6 meses de dados
df = spark.range(0, 5_000_000).select(
    F.col("id").alias("transacao_id"),
    (F.rand() * 500 + 1).cast("int").alias("loja_id"),
    (F.rand() * 5000 + 1).cast("int").alias("produto_id"),
    (F.rand() * 10 + 1).cast("int").alias("quantidade"),
    (F.rand() * 2000 + 10).cast("decimal(18,2)").alias("valor_bruto"),
    (F.rand() * 200).cast("decimal(18,2)").alias("desconto"),
    F.date_add(F.lit("2024-01-01"), (F.rand() * 180).cast("int")).alias("data_venda"),
    F.current_timestamp().alias("hora_venda"),
    F.element_at(F.array(F.lit("loja"), F.lit("app"), F.lit("web"), F.lit("telefone")),
                 (F.rand() * 4 + 1).cast("int")).alias("canal"),
    F.element_at(F.array(F.lit("aprovada"), F.lit("aprovada"), F.lit("aprovada"), F.lit("cancelada")),
                 (F.rand() * 4 + 1).cast("int")).alias("status"),
    F.element_at(F.array(F.lit("sudeste"), F.lit("sul"), F.lit("nordeste"), F.lit("norte"), F.lit("centro-oeste")),
                 (F.rand() * 5 + 1).cast("int")).alias("regiao"),
    F.current_timestamp().alias("_ingestion_ts")
)

df.write.format("delta").mode("overwrite").saveAsTable(f"{CATALOG}.bronze.transacoes_raw")
print(f"Bronze: {df.count():,} transações geradas")

# COMMAND ----------
# MAGIC %md ## Silver: Dados limpos

# COMMAND ----------
spark.sql(f"""
CREATE OR REPLACE TABLE {CATALOG}.silver.transacoes AS
SELECT
    transacao_id,
    loja_id,
    produto_id,
    quantidade,
    valor_bruto,
    desconto,
    ROUND(valor_bruto - desconto, 2)  AS valor_liquido,
    data_venda,
    YEAR(data_venda)                  AS ano,
    MONTH(data_venda)                 AS mes,
    QUARTER(data_venda)               AS trimestre,
    canal,
    status,
    regiao,
    current_timestamp()               AS _processed_ts
FROM {CATALOG}.bronze.transacoes_raw
WHERE status = 'aprovada'
  AND valor_bruto > 0
  AND quantidade > 0
""")

cnt = spark.table(f"{CATALOG}.silver.transacoes").count()
print(f"Silver: {cnt:,} transações aprovadas")

# COMMAND ----------
# MAGIC %md ## Gold: Agregações para consumo

# COMMAND ----------
# Vendas por loja e período
spark.sql(f"""
CREATE OR REPLACE TABLE {CATALOG}.gold.vendas_por_loja_mes AS
SELECT
    loja_id,
    regiao,
    ano,
    mes,
    COUNT(*)                          AS qtd_transacoes,
    SUM(quantidade)                   AS qtd_itens,
    SUM(valor_liquido)                AS receita_liquida,
    AVG(valor_liquido)                AS ticket_medio,
    SUM(desconto)                     AS total_descontos,
    COUNT(DISTINCT produto_id)        AS produtos_distintos,
    COUNT(DISTINCT canal)             AS canais_utilizados
FROM {CATALOG}.silver.transacoes
GROUP BY loja_id, regiao, ano, mes
""")

# Vendas por produto
spark.sql(f"""
CREATE OR REPLACE TABLE {CATALOG}.gold.vendas_por_produto AS
SELECT
    produto_id,
    COUNT(*)                          AS qtd_vendas,
    SUM(quantidade)                   AS qtd_total_itens,
    SUM(valor_liquido)                AS receita_total,
    AVG(valor_liquido)                AS ticket_medio,
    COUNT(DISTINCT loja_id)           AS lojas_que_venderam
FROM {CATALOG}.silver.transacoes
GROUP BY produto_id
ORDER BY receita_total DESC
""")

# KPIs executivos
spark.sql(f"""
CREATE OR REPLACE TABLE {CATALOG}.gold.kpis_executivos AS
SELECT
    ano,
    mes,
    regiao,
    SUM(receita_liquida)              AS receita_total,
    SUM(qtd_transacoes)               AS total_transacoes,
    AVG(ticket_medio)                 AS ticket_medio_geral,
    COUNT(DISTINCT loja_id)           AS lojas_ativas,
    SUM(total_descontos)              AS total_descontos
FROM {CATALOG}.gold.vendas_por_loja_mes
GROUP BY ano, mes, regiao
""")

print("Gold: 3 tabelas criadas — vendas_por_loja_mes, vendas_por_produto, kpis_executivos")
print("Dados prontos para o Genie!")
EOT
  )
}

# ─────────────────────────────────────────────
# NOTEBOOK: CONFIGURAÇÃO DO GENIE
# ─────────────────────────────────────────────

resource "databricks_notebook" "config_genie" {
  path     = "/Shared/genie-analytics/02_config_genie"
  language = "PYTHON"
  content_base64 = base64encode(<<-EOT
# Databricks notebook source
# MAGIC %md
# MAGIC # 02 — Configuração do Genie Space
# MAGIC
# MAGIC Após rodar este notebook, acesse:
# MAGIC **AI/BI → Genie → New Space**
# MAGIC
# MAGIC Use as instruções abaixo para configurar o contexto.

# COMMAND ----------
# MAGIC %md
# MAGIC ## Instruções de contexto para o Genie
# MAGIC
# MAGIC Cole o texto abaixo no campo "Instructions" do Genie Space:
# MAGIC
# MAGIC ```
# MAGIC Você é um assistente de analytics para uma rede de varejo com 500 lojas no Brasil.
# MAGIC
# MAGIC DEFINIÇÕES IMPORTANTES:
# MAGIC - "Receita" sempre se refere ao valor_liquido (após descontos)
# MAGIC - "Período atual" = últimos 30 dias
# MAGIC - "Crescimento" = comparação com mesmo período do ano anterior
# MAGIC - "Lojas novas" = menos de 6 meses de operação
# MAGIC - Regiões: sudeste, sul, nordeste, norte, centro-oeste
# MAGIC
# MAGIC TABELAS DISPONÍVEIS:
# MAGIC - gold.kpis_executivos: KPIs por região e período (use para visão geral)
# MAGIC - gold.vendas_por_loja_mes: detalhamento por loja (use para análise de loja específica)
# MAGIC - gold.vendas_por_produto: ranking de produtos (use para análise de produto)
# MAGIC
# MAGIC COMPORTAMENTO:
# MAGIC - Sempre mostre os números com formatação brasileira (R$ e pontos nos milhares)
# MAGIC - Quando comparar períodos, sempre calcule a variação percentual
# MAGIC - Se a pergunta for ambígua, pergunte antes de responder
# MAGIC ```

# COMMAND ----------
# MAGIC %md
# MAGIC ## Exemplos de perguntas para adicionar ao Genie
# MAGIC
# MAGIC Adicione esses pares no campo "Sample Questions":
# MAGIC
# MAGIC 1. "Qual foi a receita total do último mês?"
# MAGIC 2. "Quais são as 5 regiões com maior crescimento de vendas?"
# MAGIC 3. "Qual loja teve o maior ticket médio em 2024?"
# MAGIC 4. "Como estão as vendas por canal (loja, app, web)?"
# MAGIC 5. "Qual produto gerou mais receita no trimestre?"
# MAGIC 6. "Compare a receita do sudeste com o nordeste nos últimos 3 meses"
# MAGIC 7. "Quantas lojas venderam acima de R$ 100 mil no mês passado?"

# COMMAND ----------
CATALOG = "${var.catalog_name}"

# Verifica se as tabelas Gold estão prontas
tables = spark.sql(f"SHOW TABLES IN {CATALOG}.gold").collect()
print("Tabelas disponíveis para o Genie:")
for t in tables:
    cnt = spark.table(f"{CATALOG}.gold.{t.tableName}").count()
    print(f"  {CATALOG}.gold.{t.tableName}: {cnt:,} linhas")

print("\nPróximo passo: configure o Genie Space no UI do Databricks")
print("AI/BI → Genie → New Space → selecione as tabelas gold.*")
EOT
  )
}

# ─────────────────────────────────────────────
# OUTPUTS
# ─────────────────────────────────────────────

output "warehouse_id" {
  description = "ID do SQL Warehouse"
  value       = databricks_sql_endpoint.analytics.id
}

output "warehouse_jdbc" {
  description = "JDBC URL do SQL Warehouse"
  value       = databricks_sql_endpoint.analytics.jdbc_url
}

output "catalog_name" {
  description = "Nome do catalog criado"
  value       = databricks_catalog.analytics.name
}

output "notebook_gerar_dados" {
  description = "Path do notebook de geração de dados"
  value       = databricks_notebook.gerar_dados.path
}

output "notebook_config_genie" {
  description = "Path do notebook de configuração do Genie"
  value       = databricks_notebook.config_genie.path
}

output "next_steps" {
  description = "Próximos passos após o terraform apply"
  value       = <<-EOT
    1. Execute o notebook: ${databricks_notebook.gerar_dados.path}
    2. Leia as instruções em: ${databricks_notebook.config_genie.path}
    3. Acesse: AI/BI → Genie → New Space
    4. Selecione as tabelas: ${var.catalog_name}.gold.*
    5. Cole as instruções de contexto do notebook 02
    6. Publique e acesse pelo celular!
  EOT
}
