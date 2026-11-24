// =====================================================================
// Sistema de Gestão para Clínica Médica
// Script inicial de criação — MongoDB
// Entregável da Semana 14 — Escopo Inicial e Decisão Tecnológica
// =====================================================================
// Execução:
//   mongosh < database/init.js
// =====================================================================

// ---------------------------------------------------------------------
// 1. Criação / seleção do banco de dados
// ---------------------------------------------------------------------
db = db.getSiblingDB("clinica_medica");

// ---------------------------------------------------------------------
// 2. Coleção principal: registros_clinicos
// ---------------------------------------------------------------------
// Guarda a evolução clínica de cada consulta. O campo
// "dados_especialidade" tem esquema livre de propósito: é o que permite
// que cardiologia, ortopedia e psiquiatria convivam na mesma coleção
// sem alteração de estrutura (RNF04).
//
// BÔNUS — Schema Validation: garante os campos essenciais do prontuário
// no próprio banco, sem travar os campos que precisam variar.
//
// Atenção ao inserir: no mongosh, um literal numérico como 1042 é gravado
// como "double". Como os identificadores são validados como int/long, as
// inserções devem usar NumberInt(1042) ou NumberLong(1042) — caso contrário
// o documento é rejeitado pelo validador. Ver docs/modelo-documentos.md.

db.createCollection("registros_clinicos", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      title: "Registro clínico de uma consulta",
      required: [
        "consulta_id",
        "paciente_id",
        "medico_id",
        "especialidade",
        "versao",
        "criado_em",
        "queixa_principal"
      ],
      properties: {
        consulta_id: {
          bsonType: ["int", "long"],
          minimum: 1,
          description: "Referência a consultas.consulta_id no PostgreSQL. Obrigatório."
        },
        paciente_id: {
          bsonType: ["int", "long"],
          minimum: 1,
          description: "Referência a pacientes.paciente_id no PostgreSQL. Obrigatório."
        },
        medico_id: {
          bsonType: ["int", "long"],
          minimum: 1,
          description: "Referência a medicos.medico_id no PostgreSQL. Obrigatório."
        },
        especialidade: {
          bsonType: "string",
          minLength: 3,
          description: "Especialidade que produziu o registro."
        },
        versao: {
          bsonType: "int",
          minimum: 1,
          description: "Versão do registro. Correções criam nova versão (RNF03)."
        },
        criado_em: {
          bsonType: "date",
          description: "Data e hora do registro."
        },
        criado_por: {
          bsonType: "string",
          description: "Identificação do autor do registro, para auditoria."
        },
        queixa_principal: {
          bsonType: "string",
          minLength: 5,
          description: "Queixa relatada pelo paciente. Não pode ficar vazia."
        },
        anamnese: {
          bsonType: "string"
        },
        sinais_vitais: {
          bsonType: "object",
          properties: {
            pressao_sistolica:   { bsonType: "int", minimum: 40,  maximum: 300 },
            pressao_diastolica:  { bsonType: "int", minimum: 20,  maximum: 200 },
            frequencia_cardiaca: { bsonType: "int", minimum: 20,  maximum: 250 },
            saturacao_o2:        { bsonType: "int", minimum: 50,  maximum: 100 },
            // Regra de negócio: peso não pode ser negativo nem zero.
            // Atenção: o $jsonSchema do MongoDB segue o JSON Schema draft 4,
            // em que "exclusiveMinimum" é um booleano que modifica "minimum".
            peso_kg:             { bsonType: "double", minimum: 0, exclusiveMinimum: true, maximum: 400 }
          }
        },
        dados_especialidade: {
          bsonType: "object",
          description: "Campos específicos da especialidade. Esquema livre de propósito."
        },
        diagnosticos: {
          bsonType: "array",
          items: {
            bsonType: "object",
            required: ["cid10", "descricao"],
            properties: {
              cid10:     { bsonType: "string", pattern: "^[A-Z][0-9]{2}(\\.[0-9])?$" },
              descricao: { bsonType: "string" },
              tipo:      { enum: ["hipotese", "confirmado", "descartado"] }
            }
          }
        },
        prescricoes: {
          bsonType: "array",
          items: {
            bsonType: "object",
            required: ["medicamento", "posologia"],
            properties: {
              medicamento:   { bsonType: "string" },
              dosagem:       { bsonType: "string" },
              posologia:     { bsonType: "string" },
              duracao_dias:  { bsonType: "int", minimum: 1 }
            }
          }
        },
        exames_solicitados: {
          bsonType: "array",
          items: {
            bsonType: "object",
            required: ["nome"],
            properties: {
              nome:       { bsonType: "string" },
              prioridade: { enum: ["rotina", "urgente", "emergencia"] }
            }
          }
        }
      }
    }
  },
  // Documento fora do schema é rejeitado, e não apenas registrado em log.
  validationLevel: "strict",
  validationAction: "error"
});

// ---------------------------------------------------------------------
// 3. Índices
// ---------------------------------------------------------------------

// Versão vigente do registro de uma consulta.
db.registros_clinicos.createIndex(
  { consulta_id: 1, versao: -1 },
  { name: "ix_consulta_versao", unique: true }
);

// Histórico clínico do paciente em ordem cronológica (RF07, RNF02).
db.registros_clinicos.createIndex(
  { paciente_id: 1, criado_em: -1 },
  { name: "ix_paciente_data" }
);

// Relatórios por especialidade.
db.registros_clinicos.createIndex(
  { especialidade: 1 },
  { name: "ix_especialidade" }
);

// ---------------------------------------------------------------------
// 4. Verificação rápida
// ---------------------------------------------------------------------
print("Coleções criadas: " + db.getCollectionNames().join(", "));
printjson(db.registros_clinicos.getIndexes().map(function (i) { return i.name; }));
