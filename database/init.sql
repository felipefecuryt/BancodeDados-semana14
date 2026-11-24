-- =====================================================================
-- Sistema de Gestão para Clínica Médica
-- Script inicial de criação — PostgreSQL
-- Entregável da Semana 14 — Escopo Inicial e Decisão Tecnológica
-- =====================================================================
-- Execução:
--   psql -U postgres -f database/init.sql
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Criação do banco de dados
-- ---------------------------------------------------------------------
-- Executar esta linha conectado ao banco "postgres".
-- CREATE DATABASE não pode rodar dentro de um bloco transacional.

CREATE DATABASE clinica_medica
    WITH ENCODING 'UTF8'
         TEMPLATE template0;
-- Observação: o collation fica o padrão do cluster. Para forçar o locale
-- brasileiro, acrescente LC_COLLATE 'pt_BR.UTF-8' e LC_CTYPE 'pt_BR.UTF-8'
-- (exige o locale instalado no servidor).

\connect clinica_medica

-- ---------------------------------------------------------------------
-- 2. Tipos enumerados
-- ---------------------------------------------------------------------
-- Restringe os valores possíveis no próprio banco, em vez de confiar
-- apenas na validação da aplicação.

CREATE TYPE situacao_consulta AS ENUM (
    'agendada',
    'confirmada',
    'realizada',
    'cancelada',
    'falta'
);

CREATE TYPE forma_pagamento AS ENUM (
    'dinheiro',
    'cartao_credito',
    'cartao_debito',
    'pix',
    'convenio'
);

-- ---------------------------------------------------------------------
-- 3. Tabela principal: pacientes
-- ---------------------------------------------------------------------

CREATE TABLE pacientes (
    paciente_id     BIGSERIAL    PRIMARY KEY,
    nome            VARCHAR(120) NOT NULL,
    cpf             CHAR(11)     NOT NULL UNIQUE,
    data_nascimento DATE         NOT NULL,
    telefone        VARCHAR(20)  NOT NULL,
    email           VARCHAR(120),
    criado_em       TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Regra de negócio (BÔNUS): CPF deve conter exatamente 11 dígitos.
    CONSTRAINT ck_pacientes_cpf_digitos
        CHECK (cpf ~ '^[0-9]{11}$'),

    -- Regra de negócio (BÔNUS): data de nascimento não pode ser futura.
    CONSTRAINT ck_pacientes_nascimento_passado
        CHECK (data_nascimento <= CURRENT_DATE),

    -- Regra de negócio (BÔNUS): nome não pode ser vazio ou só espaços.
    CONSTRAINT ck_pacientes_nome_preenchido
        CHECK (length(trim(nome)) >= 3),

    -- Regra de negócio (BÔNUS): formato mínimo de e-mail, quando informado.
    CONSTRAINT ck_pacientes_email_formato
        CHECK (email IS NULL OR email ~ '^[^@[:space:]]+@[^@[:space:]]+\.[a-zA-Z]{2,}$')
);

COMMENT ON TABLE  pacientes IS 'Pessoas atendidas pela clínica (RF01).';
COMMENT ON COLUMN pacientes.cpf IS 'Somente dígitos, sem pontuação. Identificador único do paciente.';

-- ---------------------------------------------------------------------
-- 4. Tabela: medicos
-- ---------------------------------------------------------------------

CREATE TABLE medicos (
    medico_id     BIGSERIAL    PRIMARY KEY,
    nome          VARCHAR(120) NOT NULL,
    crm           VARCHAR(15)  NOT NULL,
    uf_crm        CHAR(2)      NOT NULL,
    especialidade VARCHAR(60)  NOT NULL,
    ativo         BOOLEAN      NOT NULL DEFAULT TRUE,
    criado_em     TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Regra de negócio: o CRM é único dentro de cada UF (RF02).
    CONSTRAINT uq_medicos_crm_uf UNIQUE (crm, uf_crm),

    CONSTRAINT ck_medicos_uf_valida
        CHECK (uf_crm ~ '^[A-Z]{2}$'),

    CONSTRAINT ck_medicos_crm_digitos
        CHECK (crm ~ '^[0-9]+$')
);

COMMENT ON TABLE medicos IS 'Profissionais que realizam os atendimentos (RF02).';

-- ---------------------------------------------------------------------
-- 5. Tabela: consultas (entidade central)
-- ---------------------------------------------------------------------

CREATE TABLE consultas (
    consulta_id BIGSERIAL         PRIMARY KEY,
    paciente_id BIGINT            NOT NULL,
    medico_id   BIGINT            NOT NULL,
    data_hora   TIMESTAMPTZ       NOT NULL,
    situacao    situacao_consulta NOT NULL DEFAULT 'agendada',
    observacoes TEXT,
    criado_em   TIMESTAMPTZ       NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Paciente com histórico não pode ser removido (auditoria clínica).
    CONSTRAINT fk_consultas_paciente
        FOREIGN KEY (paciente_id) REFERENCES pacientes (paciente_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,

    CONSTRAINT fk_consultas_medico
        FOREIGN KEY (medico_id) REFERENCES medicos (medico_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,

    -- Regra de negócio: o agendamento não pode ficar mais de um ano à frente.
    CONSTRAINT ck_consultas_horizonte
        CHECK (data_hora < CURRENT_TIMESTAMP + INTERVAL '1 year')
);

COMMENT ON TABLE consultas IS 'Agendamento que liga paciente e médico em data e hora (RF03, RF04).';

-- Regra de negócio (BÔNUS / RF03): um médico não pode ter dois agendamentos
-- ATIVOS no mesmo horário. O índice é parcial para que um horário cancelado
-- ou com falta do paciente possa ser reaproveitado.
CREATE UNIQUE INDEX uq_medico_horario
    ON consultas (medico_id, data_hora)
    WHERE situacao IN ('agendada', 'confirmada', 'realizada');

-- Índice de apoio ao histórico do paciente (RF07, RNF02).
CREATE INDEX ix_consultas_paciente_data
    ON consultas (paciente_id, data_hora DESC);

-- Índice de apoio à agenda do médico por período.
CREATE INDEX ix_consultas_medico_data
    ON consultas (medico_id, data_hora);

-- ---------------------------------------------------------------------
-- 6. Tabela: pagamentos
-- ---------------------------------------------------------------------

CREATE TABLE pagamentos (
    pagamento_id BIGSERIAL       PRIMARY KEY,
    consulta_id  BIGINT          NOT NULL,
    valor        NUMERIC(10,2)   NOT NULL,
    forma        forma_pagamento NOT NULL,
    pago_em      TIMESTAMPTZ     NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Relacionamento 1:1 — uma consulta gera no máximo um pagamento.
    CONSTRAINT uq_pagamentos_consulta UNIQUE (consulta_id),

    -- Não existe pagamento sem consulta vinculada (RNF01).
    CONSTRAINT fk_pagamentos_consulta
        FOREIGN KEY (consulta_id) REFERENCES consultas (consulta_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,

    -- Regra de negócio (BÔNUS): o valor pago não pode ser negativo nem zero.
    CONSTRAINT ck_pagamentos_valor_positivo
        CHECK (valor > 0)
);

COMMENT ON TABLE pagamentos IS 'Registro financeiro da consulta realizada (RF05).';

-- ---------------------------------------------------------------------
-- 7. Verificação rápida
-- ---------------------------------------------------------------------

-- \dt
-- \d pacientes
