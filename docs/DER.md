# Diagrama Entidade-Relacionamento — PostgreSQL

Parte relacional do modelo híbrido: agendamento e faturamento.

```mermaid
erDiagram
    PACIENTES ||--o{ CONSULTAS : "agenda"
    MEDICOS   ||--o{ CONSULTAS : "realiza"
    CONSULTAS ||--o| PAGAMENTOS : "gera"

    PACIENTES {
        bigint   paciente_id      PK
        varchar  nome
        char     cpf              UK "11 dígitos"
        date     data_nascimento  "não pode ser futura"
        varchar  telefone
        varchar  email
        timestamp criado_em
    }

    MEDICOS {
        bigint   medico_id     PK
        varchar  nome
        varchar  crm           UK "único por UF"
        char     uf_crm        UK
        varchar  especialidade
        boolean  ativo
        timestamp criado_em
    }

    CONSULTAS {
        bigint    consulta_id  PK
        bigint    paciente_id  FK
        bigint    medico_id    FK
        timestamp data_hora    "único por médico quando ativa"
        enum      situacao     "agendada|confirmada|realizada|cancelada|falta"
        text      observacoes
        timestamp criado_em
    }

    PAGAMENTOS {
        bigint    pagamento_id PK
        bigint    consulta_id  FK,UK "1:1 com consulta"
        numeric   valor            "maior que zero"
        enum      forma_pagamento  "dinheiro|cartao_credito|cartao_debito|pix|convenio"
        timestamp pago_em
    }
```

## Ligação com a parte NoSQL

A entidade **Registro Clínico** não aparece neste DER porque é persistida no MongoDB.
A ligação entre os dois bancos é feita por referência:

```
PostgreSQL: consultas.consulta_id  ──────►  MongoDB: registros_clinicos.consulta_id
```

O PostgreSQL permanece a fonte da verdade sobre pacientes, médicos e consultas. O
documento clínico guarda os identificadores, mas não pode ser validado por chave
estrangeira — essa consistência é responsabilidade da aplicação, e é o custo assumido
da arquitetura híbrida.

## Decisões de modelagem

| Decisão | Motivo |
| --- | --- |
| `situacao` como tipo `ENUM` e não `varchar` livre | Impede valores inválidos no próprio banco e documenta o ciclo de vida da consulta. |
| Pagamento em tabela separada, e não coluna em `consultas` | Uma consulta agendada ou cancelada não tem pagamento; manter colunas de valor nulas em `consultas` misturaria dois ciclos de vida distintos. |
| `valor` como `NUMERIC(10,2)` e não `FLOAT` | Valor financeiro exige precisão exata; ponto flutuante acumula erro de arredondamento. |
| Índice único **parcial** em (`medico_id`, `data_hora`) | O bloqueio de horário vale apenas para consultas ativas: um horário cancelado deve poder ser reaproveitado. |
| `ON DELETE RESTRICT` em `consultas` | Paciente com histórico não pode ser apagado — exigência de registro clínico e de auditoria. |
