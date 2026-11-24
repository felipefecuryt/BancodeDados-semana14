# Projeto Final de Banco de Dados — Sistema de Gestão para Clínica Médica

Entregável da Semana 14 — Escopo Inicial e Decisão Tecnológica de Projeto.

Este repositório contém a documentação do escopo inicial, a modelagem das entidades
principais, a justificativa da decisão tecnológica e os scripts iniciais de criação
do banco de dados.

---

## Sumário

- [1. Formação e Definição do Escopo](#1-formação-e-definição-do-escopo)
- [2. Entidades e Decisão Tecnológica](#2-entidades-e-decisão-tecnológica)
- [3. Diagramas e Scripts](#3-diagramas-e-scripts)
- [4. Reflexão](#4-reflexão)
- [5. Estrutura do Repositório](#5-estrutura-do-repositório)
- [6. Como Executar os Scripts](#6-como-executar-os-scripts)

---

## 1. Formação e Definição do Escopo

### 1.1 Integrantes

| Integrante | GitHub | Responsabilidades |
| --- | --- | --- |
| Felipe Fecury | [@felipefecuryt](https://github.com/felipefecuryt) | Levantamento de requisitos, modelagem de dados, decisão tecnológica e scripts de criação |

> Entrega individual.

### 1.2 Tema do Projeto

**Sistema de Gestão para Clínica Médica.**

O sistema atende uma clínica de médio porte com múltiplas especialidades. O escopo
desta primeira etapa cobre dois domínios: **agendamento de consultas** e **registro
clínico (prontuário)**, incluindo o faturamento ligado às consultas realizadas.

**Fora do escopo neste momento** (para evitar *scope creep*): controle de estoque de
medicamentos, folha de pagamento, integração com planos de saúde via TISS,
telemedicina e emissão de notas fiscais. Esses módulos podem ser incorporados em
etapas posteriores, mas não fazem parte da modelagem inicial.

### 1.3 Requisitos Funcionais

| ID | Requisito |
| --- | --- |
| RF01 | O sistema deve cadastrar pacientes com dados pessoais e de contato (nome, CPF, data de nascimento, telefone e e-mail), garantindo que o CPF seja único. |
| RF02 | O sistema deve cadastrar médicos com nome, CRM, UF do CRM e especialidade, garantindo que o par CRM + UF seja único. |
| RF03 | O sistema deve permitir agendar uma consulta vinculando um paciente a um médico em uma data e hora específicas, impedindo que o mesmo médico tenha duas consultas ativas no mesmo horário. |
| RF04 | O sistema deve permitir alterar a situação de uma consulta ao longo do seu ciclo de vida (agendada, confirmada, realizada, cancelada ou falta do paciente). |
| RF05 | O sistema deve registrar o pagamento de uma consulta realizada, armazenando valor, forma de pagamento e data, e não deve aceitar valores negativos. |
| RF06 | O sistema deve registrar a evolução clínica da consulta (queixa, anamnese, exame físico, hipóteses diagnósticas, prescrição e pedidos de exame), permitindo que cada especialidade registre campos próprios. |
| RF07 | O sistema deve consultar o histórico completo de um paciente, listando consultas anteriores em ordem cronológica junto com os respectivos registros clínicos. |

### 1.4 Requisitos Não Funcionais

| ID | Requisito |
| --- | --- |
| RNF01 | **Consistência transacional:** os dados de agendamento e de pagamento devem ser altamente consistentes. Uma consulta e seu pagamento precisam ser gravados de forma atômica (ACID), sem a possibilidade de existir um pagamento sem consulta vinculada ou dois agendamentos conflitantes para o mesmo médico. |
| RNF02 | **Desempenho de leitura:** a consulta ao histórico clínico de um paciente deve responder em até 2 segundos para um volume de até 500.000 registros clínicos, mesmo com documentos de estruturas distintas entre especialidades. |
| RNF03 | **Sigilo e rastreabilidade:** os dados clínicos são dados pessoais sensíveis (LGPD, Art. 5º, II). O acesso deve ser restrito por perfil de usuário e toda alteração em registro clínico deve ser auditável, preservando a versão anterior em vez de sobrescrevê-la. |
| RNF04 | **Flexibilidade de esquema:** a inclusão de uma nova especialidade, com campos clínicos próprios, não deve exigir alteração na estrutura das tabelas já existentes nem migração de dados históricos. |

---

## 2. Entidades e Decisão Tecnológica

### 2.1 Entidades Principais

| Entidade | Descrição | Onde é persistida |
| --- | --- | --- |
| **Paciente** | Pessoa atendida pela clínica. Guarda identificação, contato e data de nascimento. Possui estrutura estável e identificador único (CPF). | PostgreSQL |
| **Médico** | Profissional que realiza o atendimento. Identificado pelo CRM e UF, com uma especialidade principal. | PostgreSQL |
| **Consulta** | Agendamento que liga um paciente a um médico em uma data e hora. É a entidade central do sistema e controla o ciclo de vida do atendimento. | PostgreSQL |
| **Pagamento** | Registro financeiro de uma consulta realizada, com valor, forma de pagamento e data de recebimento. | PostgreSQL |
| **Registro Clínico (Prontuário)** | Evolução clínica produzida durante a consulta. O conteúdo varia conforme a especialidade: um cardiologista registra pressão arterial e ECG, um ortopedista registra amplitude de movimento e exames de imagem. | MongoDB |

### 2.2 Relacionamentos

| Relacionamento | Cardinalidade | Regra |
| --- | --- | --- |
| Paciente → Consulta | 1:N | Um paciente pode ter várias consultas; cada consulta pertence a exatamente um paciente. |
| Médico → Consulta | 1:N | Um médico realiza várias consultas; cada consulta tem exatamente um médico responsável. |
| Consulta → Pagamento | 1:1 | Cada consulta realizada gera no máximo um pagamento; um pagamento nunca existe sem consulta. |
| Consulta → Registro Clínico | 1:1 | Cada consulta realizada gera um registro clínico, armazenado no MongoDB e referenciado pelo `consulta_id`. |

O par (`medico_id`, `data_hora`) é restringido por índice único parcial, de forma que
o mesmo médico não possa ter dois agendamentos ativos no mesmo horário — a regra do
RF03 fica garantida pelo banco, e não apenas pela aplicação.

### 2.3 Decisão Tecnológica

**Modelo escolhido: Híbrido — PostgreSQL + MongoDB.**

| Domínio | SGBD | Motivo |
| --- | --- | --- |
| Agendamento e faturamento (Paciente, Médico, Consulta, Pagamento) | PostgreSQL | Estrutura estável, forte integridade referencial e necessidade de transações atômicas. |
| Registro clínico (Prontuário) | MongoDB | Estrutura variável por especialidade, leitura sempre pelo documento inteiro e versionamento do conteúdo clínico. |

### 2.4 Justificativa

Escolhemos uma arquitetura híbrida porque os dois domínios do sistema têm requisitos
de acesso aos dados opostos. O núcleo de agendamento e faturamento exige integridade
ACID obrigatória: marcar uma consulta e registrar seu pagamento precisa ser uma
operação atômica, e não pode existir pagamento órfão nem duplo agendamento para o
mesmo médico no mesmo horário (RNF01). Esses dados têm estrutura fixa, são
consultados por filtros relacionais (consultas de um médico em um período, pacientes
inadimplentes) e se beneficiam de chaves estrangeiras, índices únicos e `CHECK
constraints` — exatamente o que o PostgreSQL oferece de forma nativa. Modelar esse
núcleo em um banco de documentos exigiria reimplementar na aplicação garantias que o
PostgreSQL entrega de graça.

O prontuário, por outro lado, é heterogêneo por natureza. Uma evolução de cardiologia
registra pressão arterial, frequência cardíaca e laudo de ECG; uma de ortopedia
registra amplitude de movimento e exames de imagem; uma de psiquiatria registra
escalas de avaliação. Em um modelo puramente relacional, isso levaria a dezenas de
tabelas de atributos esparsos ou a um padrão EAV (entidade-atributo-valor), difícil de
consultar e de manter — e cada nova especialidade exigiria migração de esquema,
violando o RNF04. No MongoDB, cada registro clínico é um documento autocontido, com os
campos que aquela especialidade realmente usa, lido sempre por inteiro e pela chave
`consulta_id` ou `paciente_id` — o padrão de acesso que o RNF02 exige. O versionamento
exigido pelo RNF03 também fica mais simples: cada alteração grava um novo documento
com `versao` incrementada, preservando o histórico sem sobrescrever o original.

A integração entre os dois bancos é feita por referência: o documento do MongoDB
guarda os identificadores `consulta_id`, `paciente_id` e `medico_id` gerados no
PostgreSQL, que permanece a fonte da verdade sobre quem é paciente, quem é médico e
quais consultas existem. O custo dessa escolha é real e assumido: dois bancos para
operar e monitorar, e a consistência entre eles passa a ser responsabilidade da
aplicação. Aceitamos esse custo porque a alternativa — forçar um único SGBD nos dois
domínios — sacrificaria integridade financeira ou flexibilidade clínica, e ambas são
requisitos explícitos deste sistema.

---

## 3. Diagramas e Scripts

| Artefato | Arquivo |
| --- | --- |
| Diagrama Entidade-Relacionamento (parte relacional) | [`docs/DER.md`](docs/DER.md) |
| Diagrama de Documentos / Embedding (parte NoSQL) | [`docs/modelo-documentos.md`](docs/modelo-documentos.md) |
| Script de criação — PostgreSQL | [`database/init.sql`](database/init.sql) |
| Script de criação — MongoDB | [`database/init.js`](database/init.js) |

### Bônus — Regras de negócio garantidas pelo banco

| Regra | Implementação |
| --- | --- |
| Valor de pagamento não pode ser negativo nem zero | `CHECK (valor > 0)` na tabela `pagamentos` |
| Data de nascimento não pode estar no futuro | `CHECK (data_nascimento <= CURRENT_DATE)` na tabela `pacientes` |
| CPF deve ter 11 dígitos numéricos | `CHECK (cpf ~ '^[0-9]{11}$')` na tabela `pacientes` |
| Situação da consulta restrita a valores válidos | Tipo `ENUM situacao_consulta` no PostgreSQL |
| Médico sem dois agendamentos ativos no mesmo horário | Índice único parcial `uq_medico_horario` |
| Registro clínico sempre vinculado a uma consulta e com queixa preenchida | `$jsonSchema` com `required` na coleção `registros_clinicos` |

---

## 4. Reflexão

**Por que a escolha do SGBD deve ser feita com base nos requisitos de acesso aos dados
e não na preferência da equipe?**

Porque o SGBD é uma consequência do problema, não uma opinião sobre tecnologia. O que
determina a escolha é como os dados serão escritos e lidos: qual o volume, quais
consultas serão frequentes, quão estável é a estrutura dos registros, se as escritas
precisam ser atômicas e quais garantias de consistência o negócio exige. Um banco
relacional é excelente quando os dados têm estrutura previsível e as operações
precisam ser transacionais; um banco de documentos é melhor quando o formato varia e a
leitura acontece sempre pelo registro inteiro. Escolher por preferência — "uso
PostgreSQL porque é o que eu sei" ou "uso MongoDB porque é mais moderno" — significa
decidir antes de entender o problema, e o banco passa a ditar o modelo de dados em vez
de servi-lo. Neste projeto, foi o levantamento dos requisitos que mostrou que havia
dois padrões de acesso distintos: sem essa análise, a arquitetura híbrida nunca seria
considerada, e um dos dois domínios ficaria mal atendido.

**Qual o impacto de uma escolha errada no início do projeto?**

O impacto cresce com o tempo e raramente aparece no começo, quando o volume de dados é
pequeno e tudo parece funcionar. Os efeitos típicos são:

- **Gargalos de desempenho.** Um padrão de acesso que não combina com o modelo gera
  consultas caras. Montar um prontuário inteiro a partir de um modelo EAV exige dezenas
  de *joins* ou uma tabela com centenas de colunas nulas; já filtrar consultas por
  período e médico em um banco de documentos sem o índice adequado leva a varredura de
  coleção. Em ambos os casos, o problema só aparece em produção, com dados reais.
- **Dificuldade de modelagem e retrabalho.** Cada nova exigência que não cabe no modelo
  escolhido vira solução improvisada: colunas genéricas `campo1`, `campo2`, JSON
  gravado como texto, duplicação de dados entre tabelas. O modelo perde legibilidade e
  o custo de cada nova funcionalidade aumenta.
- **Perda de garantias de integridade.** Se o núcleo financeiro ficar em um banco sem
  transações multi-documento bem definidas, garantias como "não existe pagamento sem
  consulta" passam a depender do código da aplicação. Qualquer falha de rede no meio de
  uma operação deixa dados inconsistentes, e inconsistência em dado financeiro é
  prejuízo e problema de auditoria.
- **Custos desnecessários de infraestrutura.** Falta de desempenho por modelo
  inadequado costuma ser compensada com mais máquina — réplicas de leitura, cache,
  instâncias maiores — tratando o sintoma e pagando mensalmente por um erro de
  modelagem.
- **Custo de migração.** Trocar de SGBD com o sistema em produção significa migrar
  dados históricos, reescrever a camada de acesso, revalidar todas as consultas e
  conviver com os dois bancos durante a transição. É um dos trabalhos mais caros e
  arriscados de um projeto — e tudo isso é evitável com algumas horas de análise de
  requisitos no início.

---

## 5. Estrutura do Repositório

```
.
├── README.md                      # Escopo, requisitos, decisão tecnológica e reflexão
├── docs/
│   ├── DER.md                     # Diagrama Entidade-Relacionamento (PostgreSQL)
│   └── modelo-documentos.md       # Diagrama de documentos / embedding (MongoDB)
├── database/
│   ├── init.sql                   # Criação do banco relacional e das tabelas
│   └── init.js                    # Criação da coleção de registros clínicos
└── src/
    └── README.md                  # Reservado para o código da aplicação
```

## 6. Como Executar os Scripts

**PostgreSQL**

```bash
psql -U postgres -f database/init.sql
```

**MongoDB**

```bash
mongosh < database/init.js
```

> O script do PostgreSQL foi executado e testado no PostgreSQL 16, incluindo os testes
> negativos das regras de negócio (valor de pagamento negativo, data de nascimento
> futura, CPF inválido, conflito de agenda do médico, pagamento sem consulta e exclusão
> de paciente com histórico) — todas as violações foram barradas pelo banco. As regras
> do `$jsonSchema` do MongoDB foram validadas com documentos de cardiologia e de
> ortopedia, confirmando que especialidades com estruturas diferentes convivem na mesma
> coleção e que os campos obrigatórios são exigidos.
