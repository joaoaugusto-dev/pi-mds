# 📊 Documentação MySQL - Sistema IoT PI-MDS

## 📑 Índice
1. [Visão Geral](#visão-geral)
2. [Configuração do Banco de Dados](#configuração-do-banco-de-dados)
3. [Estrutura das Tabelas](#estrutura-das-tabelas)
4. [Operações CRUD](#operações-crud)
5. [DAOs (Data Access Objects)](#daos-data-access-objects)
6. [Importação de Dados](#importação-de-dados)
7. [Exemplos Práticos](#exemplos-práticos)

---

## 🎯 Visão Geral

Este projeto utiliza **MySQL** como banco de dados principal para armazenar informações sobre:
- 👥 **Funcionários** e suas preferências
- 📝 **Logs** de entrada/saída
- 📈 **Dados históricos** dos sensores IoT
- 🏷️ **Tags NFC** para controle de acesso

O projeto usa o pacote **mysql1** (versão ^0.20.0) para comunicação com o MySQL através do Dart.

---

## ⚙️ Configuração do Banco de Dados

### Arquivo: `lib/config/database_config.dart`

```dart
class DatabaseConfig {
  final String host;       // Endereço do servidor MySQL
  final int port;          // Porta (padrão: 3306)
  final String user;       // Usuário do banco
  final String? password;  // Senha (opcional)
  final String dbName;     // Nome do banco de dados
}
```

### Configuração Padrão
```dart
DatabaseConfig.defaultConfig:
  - host: 'localhost'
  - port: 3306
  - user: 'root'
  - password: null
  - dbName: 'pi_iot_system'
```

### Arquivo: `lib/database/database_connection.dart`

Esta classe gerencia a conexão com o MySQL:

#### Métodos Principais:

1. **`connect()`** - Estabelece conexão com o banco
   ```dart
   Future<bool> connect() async
   ```
   - Retorna `true` se conectado com sucesso
   - Testa a conexão com `SELECT 1`
   - Exibe mensagens de sucesso/erro

2. **`close()`** - Encerra a conexão
   ```dart
   Future<void> close() async
   ```

3. **`createTables()`** - Cria todas as tabelas necessárias
   ```dart
   Future<void> createTables() async
   ```
   - Cria tabelas se não existirem (`IF NOT EXISTS`)
   - Adiciona colunas faltantes automaticamente
   - Cria índices para otimização

---

## 📊 Estrutura das Tabelas

### 1️⃣ Tabela: `funcionarios`

Armazena dados dos funcionários e suas preferências.

```sql
CREATE TABLE funcionarios (
  id INT AUTO_INCREMENT PRIMARY KEY,
  matricula INT UNIQUE NOT NULL,
  nome VARCHAR(100) NOT NULL,
  sobrenome VARCHAR(100) NOT NULL,
  senha VARCHAR(100) NOT NULL,
  temp_preferida FLOAT DEFAULT 24.0,
  lumi_preferida INT DEFAULT 75,
  tag_nfc VARCHAR(50) UNIQUE,
  createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
)
```

**Campos:**
| Campo | Tipo | Descrição |
|-------|------|-----------|
| `id` | INT | ID único (auto-incremento) |
| `matricula` | INT | Matrícula única do funcionário |
| `nome` | VARCHAR(100) | Primeiro nome |
| `sobrenome` | VARCHAR(100) | Sobrenome |
| `senha` | VARCHAR(100) | Senha de acesso |
| `temp_preferida` | FLOAT | Temperatura preferida (padrão: 24°C) |
| `lumi_preferida` | INT | Luminosidade preferida (padrão: 75%) |
| `tag_nfc` | VARCHAR(50) | Tag NFC única |
| `createdAt` | TIMESTAMP | Data de criação |
| `updatedAt` | TIMESTAMP | Data da última atualização |

**Constraints:**
- ✅ `matricula` deve ser única
- ✅ `tag_nfc` deve ser única
- ✅ `matricula` e `nome/sobrenome` são obrigatórios

---

### 2️⃣ Tabela: `logs`

Registra entradas e saídas dos funcionários.

```sql
CREATE TABLE logs (
  id INT AUTO_INCREMENT PRIMARY KEY,
  funcionario_id INT,
  matricula VARCHAR(20),
  nome_completo VARCHAR(150),
  tipo ENUM('entrada', 'saida') NOT NULL,
  tag_nfc VARCHAR(50),
  hash_controle VARCHAR(64),
  createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_funcionario_id (funcionario_id),
  INDEX idx_matricula (matricula),
  INDEX idx_createdAt (createdAt)
)
```

**Campos:**
| Campo | Tipo | Descrição |
|-------|------|-----------|
| `id` | INT | ID único (auto-incremento) |
| `funcionario_id` | INT | Referência ao funcionário |
| `matricula` | VARCHAR(20) | Matrícula do funcionário |
| `nome_completo` | VARCHAR(150) | Nome completo |
| `tipo` | ENUM | 'entrada' ou 'saida' |
| `tag_nfc` | VARCHAR(50) | Tag NFC usada |
| `hash_controle` | VARCHAR(64) | Hash MD5 para evitar duplicatas |
| `createdAt` | TIMESTAMP | Data/hora do registro |
| `updatedAt` | TIMESTAMP | Última atualização |

**Índices para Performance:**
- 📌 `idx_funcionario_id` - Busca rápida por funcionário
- 📌 `idx_matricula` - Busca rápida por matrícula
- 📌 `idx_createdAt` - Ordenação por data
- 📌 `idx_hash_controle` - Índice único para evitar duplicatas

---

### 3️⃣ Tabela: `dados_historicos`

Armazena dados históricos dos sensores IoT.

```sql
CREATE TABLE dados_historicos (
  id INT AUTO_INCREMENT PRIMARY KEY,
  temperatura FLOAT,
  humidade FLOAT,
  ldr INT,
  iluminacao_artificial INT DEFAULT 0,
  pessoas INT DEFAULT 0,
  tags_presentes JSON,
  clima_ligado BOOLEAN DEFAULT FALSE,
  clima_umidificando BOOLEAN DEFAULT FALSE,
  clima_velocidade INT DEFAULT 0,
  timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)
```

**Campos:**
| Campo | Tipo | Descrição |
|-------|------|-----------|
| `id` | INT | ID único (auto-incremento) |
| `temperatura` | FLOAT | Temperatura em °C |
| `humidade` | FLOAT | Umidade em % |
| `ldr` | INT | Valor do sensor de luz (LDR) |
| `iluminacao_artificial` | INT | Nível de iluminação artificial |
| `pessoas` | INT | Quantidade de pessoas detectadas |
| `tags_presentes` | JSON | Array de tags NFC presentes |
| `clima_ligado` | BOOLEAN | Climatizador ligado/desligado |
| `clima_umidificando` | BOOLEAN | Modo umidificação |
| `clima_velocidade` | INT | Velocidade do climatizador |
| `timestamp` | TIMESTAMP | Data/hora do registro |

**Características:**
- 💾 Armazena dados em intervalos regulares
- 📊 Permite análise histórica e cálculo de médias
- 🔍 Suporta filtros por período de tempo

---

## 🔧 Operações CRUD

### Conexão Básica

```dart
// 1. Criar configuração
final config = DatabaseConfig.defaultConfig;

// 2. Criar conexão
final db = DatabaseConnection(config);

// 3. Conectar
await db.connect();

// 4. Criar tabelas (primeira vez)
await db.createTables();

// 5. Usar o banco...

// 6. Fechar conexão
await db.close();
```

---

## 📦 DAOs (Data Access Objects)

Os DAOs encapsulam as operações de banco de dados para cada entidade.

### 1️⃣ FuncionarioDao

**Localização:** `lib/dao/funcionario_dao.dart`

#### Métodos Disponíveis:

##### ➕ Inserir Funcionário
```dart
Future<bool> inserirFuncionario(Funcionario funcionario)
```
**Uso:**
```dart
final dao = FuncionarioDao(db);
final func = Funcionario(
  matricula: 25000019,
  nome: 'João',
  sobrenome: 'Silva',
  senha: '123',
  tempPreferida: 22.0,
  lumiPreferida: 80,
  tagNfc: '8E0F3503',
);
await dao.inserirFuncionario(func);
```

##### 📋 Listar Todos os Funcionários
```dart
Future<List<Funcionario>> listarFuncionarios()
```
**Uso:**
```dart
final funcionarios = await dao.listarFuncionarios();
for (var func in funcionarios) {
  print('${func.nomeCompleto} - ${func.matricula}');
}
```

##### 🔍 Buscar por Matrícula
```dart
Future<Funcionario?> buscarPorMatricula(int matricula)
```
**Uso:**
```dart
final func = await dao.buscarPorMatricula(25000019);
if (func != null) {
  print('Encontrado: ${func.nomeCompleto}');
}
```

##### 🏷️ Buscar por Tag NFC
```dart
Future<Funcionario?> buscarPorTag(String tagNfc)
```
**Uso:**
```dart
final func = await dao.buscarPorTag('8E0F3503');
if (func != null) {
  print('Tag pertence a: ${func.nomeCompleto}');
}
```

##### 🏷️📋 Buscar Múltiplos por Tags
```dart
Future<List<Funcionario>> buscarPorTags(List<String> tags)
```
**Uso:**
```dart
final tags = ['8E0F3503', '6C227B1C'];
final funcionarios = await dao.buscarPorTags(tags);
```

##### ✏️ Atualizar Funcionário
```dart
Future<bool> atualizarFuncionario(Funcionario funcionario)
```
**Uso:**
```dart
func.tempPreferida = 24.0;
await dao.atualizarFuncionario(func);
```

##### ❌ Deletar Funcionário
```dart
Future<bool> deletarFuncionario(int id)
```
**Uso:**
```dart
await dao.deletarFuncionario(1);
```

##### 🔐 Autenticar Funcionário
```dart
Future<Funcionario?> autenticar(int matricula, String senha)
```
**Uso:**
```dart
final func = await dao.autenticar(25000019, '123');
if (func != null) {
  print('Login bem-sucedido!');
}
```

---

### 2️⃣ LogDao

**Localização:** `lib/dao/log_dao.dart`

#### Métodos Disponíveis:

##### ➕ Inserir Log
```dart
Future<void> inserirLog(LogEntry log)
```
**Uso:**
```dart
final dao = LogDao(db);
final log = LogEntry(
  funcionarioId: 1,
  matricula: '25000019',
  nomeCompleto: 'João Silva',
  tipo: 'entrada',
  tagNfc: '8E0F3503',
);
await dao.inserirLog(log);
```

**Características:**
- ✅ Cria hash MD5 para evitar duplicatas
- ✅ Fallback automático se coluna hash não existir
- ✅ Ignora logs duplicados silenciosamente

##### 📋 Listar Logs
```dart
Future<List<LogEntry>> listarLogs({int limit = 100})
```
**Uso:**
```dart
final logs = await dao.listarLogs(limit: 50);
for (var log in logs) {
  print('${log.tipo}: ${log.nomeCompleto} em ${log.createdAt}');
}
```

##### 📅 Buscar Logs por Período
```dart
Future<List<LogEntry>> buscarLogsPorPeriodo(DateTime inicio, DateTime fim)
```
**Uso:**
```dart
final inicio = DateTime(2025, 11, 1);
final fim = DateTime(2025, 11, 4);
final logs = await dao.buscarLogsPorPeriodo(inicio, fim);
```

##### 👤 Buscar Logs de um Funcionário
```dart
Future<List<LogEntry>> buscarLogsPorFuncionario(int funcionarioId)
```
**Uso:**
```dart
final logs = await dao.buscarLogsPorFuncionario(1);
```

##### 🔍 Buscar Último Log de um Funcionário
```dart
Future<LogEntry?> buscarUltimoLogFuncionario(int funcionarioId)
```
**Uso:**
```dart
final ultimoLog = await dao.buscarUltimoLogFuncionario(1);
if (ultimoLog != null) {
  print('Última ação: ${ultimoLog.tipo}');
}
```

##### 🏷️ Buscar Logs por Tag NFC
```dart
Future<List<LogEntry>> buscarLogsPorTag(String tagNfc)
```

##### 📊 Contar Logs
```dart
Future<int> contarLogs({DateTime? inicio, DateTime? fim})
```

---

### 3️⃣ HistoricoDao

**Localização:** `lib/dao/historico_dao.dart`

#### Métodos Disponíveis:

##### ➕ Salvar Dados Históricos
```dart
Future<void> salvarDadosHistoricos(
  DadosSensores dados, {
  bool? climaLigado,
  bool? climaUmidificando,
  int? climaVelocidade,
  int? iluminacaoArtificial,
})
```
**Uso:**
```dart
final dao = HistoricoDao(db);
final dados = DadosSensores(
  temperatura: 25.5,
  humidade: 60.0,
  ldr: 500,
  pessoas: 3,
  tags: ['8E0F3503', '6C227B1C'],
);
await dao.salvarDadosHistoricos(
  dados,
  climaLigado: true,
  climaVelocidade: 2,
);
```

**Características:**
- ✅ Converte lista de tags para JSON automaticamente
- ✅ Aceita parâmetros opcionais de estado do climatizador

##### 📊 Buscar Histórico
```dart
Future<List<Map<String, dynamic>>> buscarHistorico({
  DateTime? inicio,
  DateTime? fim,
  int limit = 1000,
})
```
**Uso:**
```dart
final historico = await dao.buscarHistorico(
  inicio: DateTime(2025, 11, 1),
  fim: DateTime(2025, 11, 4),
  limit: 500,
);
```

##### 📈 Calcular Médias Históricas
```dart
Future<Map<String, double>> calcularMediasHistoricas({
  DateTime? inicio,
  DateTime? fim,
})
```
**Uso:**
```dart
final medias = await dao.calcularMediasHistoricas(
  inicio: DateTime(2025, 11, 1),
  fim: DateTime(2025, 11, 4),
);
print('Temperatura média: ${medias['temperatura']}°C');
print('Umidade média: ${medias['humidade']}%');
```

**Retorna:**
```dart
{
  'temperatura': 24.5,
  'humidade': 55.0,
  'ldr': 450.0,
  'pessoas': 2.5,
  'iluminacao_artificial': 60.0
}
```

##### 🔢 Contar Registros
```dart
Future<int> contarRegistros({DateTime? inicio, DateTime? fim})
```

##### 🔥 Buscar Últimos Dados
```dart
Future<Map<String, dynamic>?> buscarUltimosDados()
```

---

## 📥 Importação de Dados

### Arquivos SQL de Dump

O projeto inclui arquivos SQL na pasta `Dump20251016/`:

1. **`pi_iot_system_funcionarios.sql`** - Dados dos funcionários
2. **`pi_iot_system_logs.sql`** - Logs de entrada/saída
3. **`pi_iot_system_dados_historicos.sql`** - Dados históricos dos sensores
4. **`pi_iot_system_routines.sql`** - Rotinas e procedures

### Como Importar os Dados

#### Opção 1: Via MySQL Workbench
1. Abra o MySQL Workbench
2. Conecte ao servidor MySQL
3. Vá em `Server` → `Data Import`
4. Selecione `Import from Self-Contained File`
5. Escolha o arquivo `.sql`
6. Clique em `Start Import`

#### Opção 2: Via Linha de Comando
```bash
# Windows PowerShell
mysql -u root -p pi_iot_system < "Dump20251016\pi_iot_system_funcionarios.sql"
mysql -u root -p pi_iot_system < "Dump20251016\pi_iot_system_logs.sql"
mysql -u root -p pi_iot_system < "Dump20251016\pi_iot_system_dados_historicos.sql"
```

#### Opção 3: Via Código Dart
```bash
# O projeto cria as tabelas automaticamente
dart run bin/main.dart
# As tabelas serão criadas na primeira execução
```

### Dados de Exemplo Incluídos

Os dumps incluem dados de 4 funcionários:

| Matrícula | Nome | Tag NFC | Temp. Pref. | Lumi. Pref. |
|-----------|------|---------|-------------|-------------|
| 25000019 | João Augusto Freitas | 8E0F3503 | 18°C | 25% |
| 25000795 | Kauan Leander Leandrini | 6C227B1C | 30°C | 75% |
| 25001248 | Everson Chagas Araújo | AC71771C | 22°C | 50% |
| 25001227 | Isadora Cabral dos Santos | 8CE3721C | 26°C | 100% |

---

## 💡 Exemplos Práticos

### Exemplo 1: Sistema Completo de Autenticação

```dart
import 'package:pi_mds/config/database_config.dart';
import 'package:pi_mds/database/database_connection.dart';
import 'package:pi_mds/dao/funcionario_dao.dart';
import 'package:pi_mds/dao/log_dao.dart';

Future<void> main() async {
  // Configurar banco
  final config = DatabaseConfig.defaultConfig;
  final db = DatabaseConnection(config);
  
  // Conectar
  if (!await db.connect()) {
    print('Erro ao conectar!');
    return;
  }
  
  // Criar tabelas
  await db.createTables();
  
  // DAOs
  final funcDao = FuncionarioDao(db);
  final logDao = LogDao(db);
  
  // Autenticar usuário
  final func = await funcDao.autenticar(25000019, '123');
  
  if (func != null) {
    print('✓ Login bem-sucedido: ${func.nomeCompleto}');
    
    // Registrar entrada
    final log = LogEntry(
      funcionarioId: func.id,
      matricula: func.matricula.toString(),
      nomeCompleto: func.nomeCompleto,
      tipo: 'entrada',
      tagNfc: func.tagNfc,
    );
    await logDao.inserirLog(log);
    
    print('Preferências:');
    print('- Temperatura: ${func.tempPreferida}°C');
    print('- Luminosidade: ${func.lumiPreferida}%');
  } else {
    print('✗ Credenciais inválidas');
  }
  
  // Fechar conexão
  await db.close();
}
```

### Exemplo 2: Registrar Dados de Sensores

```dart
import 'package:pi_mds/dao/historico_dao.dart';
import 'package:pi_mds/models/dados_sensores.dart';

Future<void> registrarSensores() async {
  final dao = HistoricoDao(db);
  
  // Dados lidos dos sensores ESP32
  final dados = DadosSensores(
    temperatura: 25.5,
    humidade: 60.0,
    ldr: 500,
    pessoas: 3,
    tags: ['8E0F3503', '6C227B1C', 'AC71771C'],
  );
  
  // Salvar no banco
  await dao.salvarDadosHistoricos(
    dados,
    climaLigado: true,
    climaUmidificando: false,
    climaVelocidade: 2,
    iluminacaoArtificial: 75,
  );
  
  print('✓ Dados salvos no histórico');
}
```

### Exemplo 3: Relatório de Presença

```dart
Future<void> relatorioPresenca() async {
  final logDao = LogDao(db);
  
  final inicio = DateTime(2025, 11, 1);
  final fim = DateTime(2025, 11, 4);
  
  final logs = await logDao.buscarLogsPorPeriodo(inicio, fim);
  
  print('\n📊 RELATÓRIO DE PRESENÇA');
  print('Período: ${inicio.day}/${inicio.month} a ${fim.day}/${fim.month}');
  print('─' * 50);
  
  for (var log in logs) {
    final hora = log.createdAt?.toString().substring(11, 16) ?? '';
    final emoji = log.tipo == 'entrada' ? '🟢' : '🔴';
    print('$emoji $hora - ${log.tipo.toUpperCase()} - ${log.nomeCompleto}');
  }
}
```

### Exemplo 4: Análise de Temperatura Média

```dart
Future<void> analisarTemperatura() async {
  final dao = HistoricoDao(db);
  
  final medias = await dao.calcularMediasHistoricas(
    inicio: DateTime.now().subtract(Duration(days: 7)),
    fim: DateTime.now(),
  );
  
  print('\n🌡️ ANÁLISE DE TEMPERATURA (7 dias)');
  print('─' * 50);
  print('Temperatura média: ${medias['temperatura']?.toStringAsFixed(1)}°C');
  print('Umidade média: ${medias['humidade']?.toStringAsFixed(1)}%');
  print('Luminosidade média: ${medias['ldr']?.toStringAsFixed(0)}');
  print('Ocupação média: ${medias['pessoas']?.toStringAsFixed(1)} pessoas');
}
```

### Exemplo 5: Busca por Tag NFC

```dart
Future<void> identificarTag(String tagNfc) async {
  final funcDao = FuncionarioDao(db);
  final logDao = LogDao(db);
  
  // Buscar funcionário pela tag
  final func = await funcDao.buscarPorTag(tagNfc);
  
  if (func != null) {
    print('🏷️ Tag identificada!');
    print('Funcionário: ${func.nomeCompleto}');
    print('Matrícula: ${func.matricula}');
    
    // Verificar último log
    final ultimoLog = await logDao.buscarUltimoLogFuncionario(func.id!);
    
    if (ultimoLog != null) {
      final tipo = ultimoLog.tipo == 'entrada' ? 'saida' : 'entrada';
      
      // Registrar novo log
      final novoLog = LogEntry(
        funcionarioId: func.id,
        matricula: func.matricula.toString(),
        nomeCompleto: func.nomeCompleto,
        tipo: tipo,
        tagNfc: tagNfc,
      );
      await logDao.inserirLog(novoLog);
      
      print('✓ Registrado: $tipo');
    }
  } else {
    print('❌ Tag não cadastrada: $tagNfc');
  }
}
```

---

## 🔒 Segurança e Boas Práticas

### ✅ Prevenção de SQL Injection
O projeto usa **prepared statements** (queries parametrizadas):

```dart
// ✅ CORRETO - Seguro contra SQL Injection
await conn.query(
  'SELECT * FROM funcionarios WHERE matricula = ?',
  [matricula],
);

// ❌ ERRADO - Vulnerável a SQL Injection
await conn.query(
  'SELECT * FROM funcionarios WHERE matricula = $matricula',
);
```

### ✅ Controle de Duplicatas
- Hash MD5 nos logs para evitar registros duplicados
- Constraints UNIQUE em matrícula e tag_nfc
- Validação antes de inserção

### ✅ Índices para Performance
- Índices em campos de busca frequente
- Otimização de queries com WHERE e JOIN

### ✅ Timestamps Automáticos
- `createdAt` registra data de criação
- `updatedAt` atualiza automaticamente

---

## 🚀 Comandos Úteis

### Verificar Tabelas
```sql
SHOW TABLES;
```

### Descrever Estrutura
```sql
DESCRIBE funcionarios;
DESCRIBE logs;
DESCRIBE dados_historicos;
```

### Limpar Dados
```sql
TRUNCATE TABLE logs;
TRUNCATE TABLE dados_historicos;
```

### Backup do Banco
```bash
# PowerShell
mysqldump -u root -p pi_iot_system > backup_$(Get-Date -Format 'yyyyMMdd').sql
```

### Restaurar Backup
```bash
mysql -u root -p pi_iot_system < backup_20251104.sql
```

---

## 📚 Dependências

### pubspec.yaml
```yaml
dependencies:
  mysql1: ^0.20.0  # Cliente MySQL para Dart
  intl: ^0.19.0    # Formatação de datas
  crypto: ^3.0.3   # Hash MD5 para controle de duplicatas
```

### Instalação
```bash
dart pub get
```

---

## 🐛 Troubleshooting

### Erro: "Access denied for user"
**Solução:** Verifique usuário e senha no `database_config.dart`

### Erro: "Unknown database"
**Solução:** Crie o banco manualmente:
```sql
CREATE DATABASE pi_iot_system;
```

### Erro: "Can't connect to MySQL server"
**Solução:** 
1. Verifique se o MySQL está rodando
2. Confirme host e porta corretos
3. Verifique firewall

### Tabelas não criadas
**Solução:** Execute `await db.createTables()` após conectar

---

## 📞 Suporte

Para mais informações sobre o projeto:
- 📂 Estrutura: Veja `analysis_options.yaml`
- 🔥 Firebase: Veja `FIREBASE_STREAMING.md`
- 📡 Streaming: Veja `CHANGELOG_STREAMING.md`

---

**Documentação criada em:** Novembro de 2025  
**Versão do Projeto:** 1.0.0  
**Banco de Dados:** MySQL 8.0+  
**Linguagem:** Dart ^3.9.1
