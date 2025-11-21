# 📐 Arquitetura MVC - Sistema IoT Dashboard

## 📋 Índice
1. [Visão Geral](#visão-geral)
2. [Diagrama de Arquitetura MVC](#diagrama-de-arquitetura-mvc)
3. [Camadas do Sistema](#camadas-do-sistema)
4. [Diagrama de Classes](#diagrama-de-classes)
5. [Diagrama de Fluxo de Dados](#diagrama-de-fluxo-de-dados)
6. [Diagrama de Componentes](#diagrama-de-componentes)
7. [Diagrama de Sequência](#diagrama-de-sequência)
8. [Estrutura de Pastas](#estrutura-de-pastas)

---

## 🎯 Visão Geral

O Sistema IoT Dashboard segue o padrão arquitetural **MVC (Model-View-Controller)** adaptado para aplicações Dart/Flutter com integração Firebase e MySQL.

### Características Principais:
- ✅ Separação clara de responsabilidades
- ✅ Comunicação em tempo real via Firebase Realtime Database
- ✅ Persistência de dados em MySQL
- ✅ Processamento assíncrono com Streams
- ✅ Arquitetura escalável e modular

---

## 🏗️ Diagrama de Arquitetura MVC

```
┌─────────────────────────────────────────────────────────────────┐
│                        SISTEMA IoT DASHBOARD                     │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                            VIEW LAYER                            │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │          MenuInterfaceSimple (UI)                        │   │
│  │  - Exibição de dados dos sensores                        │   │
│  │  - Interface de controle                                 │   │
│  │  - Visualização de logs                                  │   │
│  │  - Menu de navegação                                     │   │
│  └─────────────────────────────────────────────────────────┘   │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                       CONTROLLER LAYER                           │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │       SistemaIotController (Orquestrador)               │   │
│  │  - Gerencia fluxo de dados                              │   │
│  │  - Coordena services e DAOs                             │   │
│  │  - Processa lógica de negócio                           │   │
│  │  - Controla streams e eventos                           │   │
│  └─────────────────────────────────────────────────────────┘   │
└──────────────┬────────────────────────┬─────────────────────────┘
               │                        │
               ▼                        ▼
┌──────────────────────────┐  ┌────────────────────────────────────┐
│    SERVICE LAYER         │  │       DAO LAYER                    │
│  ┌─────────────────────┐ │  │  ┌──────────────────────────────┐ │
│  │ FirebaseService     │ │  │  │ FuncionarioDao               │ │
│  │ - Comunicação RT    │ │  │  │ - CRUD Funcionários          │ │
│  │ - Streams           │ │  │  ├──────────────────────────────┤ │
│  ├─────────────────────┤ │  │  │ HistoricoDao                 │ │
│  │ FuncionarioService  │ │  │  │ - CRUD Histórico             │ │
│  │ - Lógica Func.      │ │  │  ├──────────────────────────────┤ │
│  ├─────────────────────┤ │  │  │ LogDao                       │ │
│  │ LogService          │ │  │  │ - CRUD Logs                  │ │
│  │ - Registro eventos  │ │  │  ├──────────────────────────────┤ │
│  ├─────────────────────┤ │  │  │ PreferenciaTagDao            │ │
│  │ SaidaService        │ │  │  │ - CRUD Preferências          │ │
│  │ - Buffer dados      │ │  │  └──────────────────────────────┘ │
│  └─────────────────────┘ │  └────────────────────────────────────┘
└──────────┬───────────────┘           │
           │                           │
           ▼                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                         MODEL LAYER                              │
│  ┌─────────────────┐  ┌──────────────────┐  ┌────────────────┐ │
│  │ DadosSensores   │  │ EstadoClima-     │  │ Funcionario    │ │
│  │ - temperatura   │  │ tizador          │  │ - id           │ │
│  │ - humidade      │  │ - temperatura    │  │ - nome         │ │
│  │ - luminosidade  │  │ - modo           │  │ - tag_rfid     │ │
│  │ - pessoas       │  │ - velocidade     │  │ - grupo        │ │
│  │ - tags          │  │ - status         │  │ - ativo        │ │
│  └─────────────────┘  └──────────────────┘  └────────────────┘ │
│  ┌─────────────────┐  ┌──────────────────┐  ┌────────────────┐ │
│  │ LogEntry        │  │ Preferencias-    │  │                │ │
│  │ - tipo          │  │ Grupo            │  │                │ │
│  │ - mensagem      │  │ - tag_rfid       │  │                │ │
│  │ - timestamp     │  │ - preferencias   │  │                │ │
│  │ - contexto      │  │ - prioridade     │  │                │ │
│  └─────────────────┘  └──────────────────┘  └────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                      DATA SOURCES                                │
│  ┌─────────────────────┐           ┌──────────────────────────┐ │
│  │  Firebase RT DB     │           │  MySQL Database          │ │
│  │  - Dados sensores   │           │  - Funcionários          │ │
│  │  - Estado clima     │           │  - Histórico             │ │
│  │  - Comandos         │           │  - Logs                  │ │
│  │  - Preferências     │           │  - Preferências Tags     │ │
│  └─────────────────────┘           └──────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                      HARDWARE LAYER                              │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                      ESP32                               │   │
│  │  - Sensores (DHT22, LDR, HC-SR501, RFID)                │   │
│  │  - Atuadores (Relés, PWM)                                │   │
│  │  - Conexão WiFi                                          │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📦 Camadas do Sistema

### 1️⃣ **VIEW (Interface do Usuário)**

**Responsabilidade:** Apresentação e interação com usuário

**Componentes:**
- `MenuInterfaceSimple`: Interface de menu principal

**Funções:**
- Exibir dados dos sensores em tempo real
- Mostrar status do climatizador
- Apresentar logs do sistema
- Receber comandos do usuário
- Exibir estatísticas e histórico

---

### 2️⃣ **CONTROLLER (Controlador)**

**Responsabilidade:** Orquestração e lógica de negócio

**Componente Principal:**
- `SistemaIotController`

**Funções:**
```dart
// Gerenciamento de Streams
- iniciarMonitoramento()
- pararMonitoramento()
- processarDadosSensores()
- processarEstadoClimatizador()

// Comandos
- enviarComandoIluminacao(comando)
- enviarComandoClimatizador(config)
- solicitarPreferencias(tagRfid)

// Consultas
- obterHistorico(inicio, fim)
- obterEstatisticas()
- verificarPreferencias(tags)

// Background Processing
- iniciarProcessamentoBackground()
- salvarDadosPeriodicamente()
```

**Características:**
- ✅ Gerencia múltiplos streams (sensores, climatizador, comandos)
- ✅ Coordena comunicação entre View, Services e DAOs
- ✅ Implementa lógica de preferências de grupos
- ✅ Controla logging automático
- ✅ Processa dados assíncronos

---

### 3️⃣ **MODEL (Modelos de Dados)**

**Responsabilidade:** Representação dos dados

**Classes:**

#### `DadosSensores`
```dart
- temperatura: double
- humidade: double
- luminosidade: int
- ldr: int
- pessoas: int
- tags: List<String>
- timestamp: DateTime
- dadosValidos: bool
- iluminacaoArtificial: int
```

#### `EstadoClimatizador`
```dart
- temperatura: double
- temperaturaConfiguracao: double
- modo: String
- velocidade: int
- status: bool
- timestamp: DateTime
```

#### `Funcionario`
```dart
- id: int
- nome: String
- tag_rfid: String
- grupo: String
- ativo: bool
```

#### `LogEntry`
```dart
- tipo: String (INFO, WARNING, ERROR, COMMAND)
- mensagem: String
- timestamp: DateTime
- contexto: Map<String, dynamic>
```

#### `PreferenciasGrupo`
```dart
- tag_rfid: String
- temperaturaIdeal: double
- temperaturaMin: double
- temperaturaMax: double
- iluminacaoMinima: int
- prioridade: int
```

---

### 4️⃣ **SERVICE LAYER (Camada de Serviços)**

**Responsabilidade:** Lógica de negócio e comunicação externa

#### `FirebaseService`
```dart
- Comunicação Firebase Realtime Database
- Gerenciamento de streams em tempo real
- Polling de dados (sensores, climatizador, comandos)
- Publicação de comandos
- GET/PUT/POST/DELETE Firebase
```

#### `FuncionarioService`
```dart
- Gerenciamento de funcionários
- Validação de tags RFID
- Consulta de preferências por funcionário
- Agregação de preferências de grupo
```

#### `LogService`
```dart
- Registro centralizado de logs
- Diferentes níveis (INFO, WARNING, ERROR, COMMAND)
- Contexto adicional para debugging
- Persistência automática
```

#### `SaidaService`
```dart
- Buffer circular para saída de dados
- Controle de capacidade
- Formatação de mensagens
- Exibição formatada
```

---

### 5️⃣ **DAO LAYER (Data Access Objects)**

**Responsabilidade:** Acesso e persistência de dados no MySQL

#### `FuncionarioDao`
```dart
- inserir(funcionario)
- atualizar(funcionario)
- deletar(id)
- buscarPorId(id)
- buscarPorTag(tagRfid)
- listarTodos()
- listarAtivos()
```

#### `HistoricoDao`
```dart
- inserir(dadosSensores)
- buscarPorPeriodo(inicio, fim)
- buscarUltimos(limite)
- calcularMedias(inicio, fim)
- obterEstatisticas()
```

#### `LogDao`
```dart
- inserir(logEntry)
- buscarPorTipo(tipo)
- buscarPorPeriodo(inicio, fim)
- listarRecentes(limite)
- deletarAntigos(dataLimite)
```

#### `PreferenciaTagDao`
```dart
- inserir(preferencia)
- atualizar(preferencia)
- buscarPorTag(tagRfid)
- listarTodas()
- deletar(tagRfid)
```

---

## 🔄 Diagrama de Fluxo de Dados

```
┌──────────────┐
│   ESP32      │
│  (Hardware)  │
└──────┬───────┘
       │ WiFi
       ▼
┌──────────────────────────────────┐
│  Firebase Realtime Database      │
│  /sensores/dados                 │
│  /climatizador/estado            │
│  /comandos/iluminacao            │
│  /comandos/climatizador          │
└──────┬───────────────────────────┘
       │ HTTP Polling
       ▼
┌──────────────────────────────────┐
│    FirebaseService               │
│  - Stream Sensores               │
│  - Stream Climatizador           │
│  - Stream Comandos               │
└──────┬───────────────────────────┘
       │ Dart Streams
       ▼
┌──────────────────────────────────┐
│  SistemaIotController            │
│  ┌────────────────────────────┐  │
│  │ Processar Dados            │  │
│  │ Aplicar Preferências       │  │
│  │ Gerar Comandos             │  │
│  │ Registrar Logs             │  │
│  └────────────────────────────┘  │
└──┬──────────────────┬────────────┘
   │                  │
   │ DAO              │ Service
   ▼                  ▼
┌─────────────┐   ┌────────────────┐
│   MySQL     │   │  LogService    │
│   Database  │   │  SaidaService  │
│  - histórico│   │  Funcionario   │
│  - logs     │   │  Service       │
│  - func.    │   └────────────────┘
└─────────────┘
       │
       │ Query Results
       ▼
┌──────────────────────────────────┐
│    MenuInterfaceSimple (UI)      │
│  - Dashboard                     │
│  - Controles                     │
│  - Logs                          │
│  - Estatísticas                  │
└──────────────────────────────────┘
       │
       │ User Input
       ▼
   (Loop continua...)
```

---

## 🧩 Diagrama de Componentes

```
┌─────────────────────────────────────────────────────────────────┐
│                           bin/main.dart                          │
│                      (Entry Point / Bootstrap)                   │
└──────────────────────────┬──────────────────────────────────────┘
                           │
         ┌─────────────────┼─────────────────┐
         │                 │                 │
         ▼                 ▼                 ▼
    ┌────────┐      ┌──────────┐      ┌──────────┐
    │ Config │      │ Database │      │ Services │
    │        │      │          │      │          │
    └────────┘      └──────────┘      └──────────┘
         │                 │                 │
         └─────────────────┼─────────────────┘
                           │
                           ▼
              ┌────────────────────────┐
              │  SistemaIotController  │
              └────────────────────────┘
                           │
                           ▼
              ┌────────────────────────┐
              │  MenuInterfaceSimple   │
              └────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    DEPENDÊNCIAS DE COMPONENTES                   │
└─────────────────────────────────────────────────────────────────┘

SistemaIotController depende de:
    ├── FirebaseService
    ├── FuncionarioService
    ├── LogService
    └── HistoricoDao

FirebaseService depende de:
    ├── FirebaseConfig
    └── SaidaService (opcional)

FuncionarioService depende de:
    ├── FuncionarioDao
    └── PreferenciaTagDao

LogService depende de:
    └── LogDao

All DAOs dependem de:
    └── DatabaseConnection

DatabaseConnection depende de:
    └── DatabaseConfig

MenuInterfaceSimple depende de:
    ├── SistemaIotController
    └── SaidaService
```

---

## ⚡ Diagrama de Sequência - Processamento de Dados

```
┌────────┐  ┌─────────┐  ┌──────────┐  ┌──────────┐  ┌─────────┐  ┌──────┐
│ ESP32  │  │Firebase │  │ Firebase │  │ Sistema  │  │Historico│  │ View │
│        │  │   DB    │  │ Service  │  │IoTCtrl   │  │  Dao    │  │      │
└───┬────┘  └────┬────┘  └────┬─────┘  └────┬─────┘  └────┬────┘  └──┬───┘
    │            │             │             │             │          │
    │ PUT dados  │             │             │             │          │
    ├───────────>│             │             │             │          │
    │            │             │             │             │          │
    │            │  Polling    │             │             │          │
    │            │<────────────┤             │             │          │
    │            │             │             │             │          │
    │            │ Dados JSON  │             │             │          │
    │            ├────────────>│             │             │          │
    │            │             │             │             │          │
    │            │             │ Stream      │             │          │
    │            │             ├────────────>│             │          │
    │            │             │ Dados       │             │          │
    │            │             │ Sensores    │             │          │
    │            │             │             │             │          │
    │            │             │             │ Processar   │          │
    │            │             │             │ Preferências│          │
    │            │             │             │             │          │
    │            │             │             │ Salvar      │          │
    │            │             │             ├────────────>│          │
    │            │             │             │ Histórico   │          │
    │            │             │             │             │          │
    │            │             │             │ Gerar       │          │
    │            │             │             │ Comando     │          │
    │            │             │ PUT comando │             │          │
    │            │<────────────┼─────────────┤             │          │
    │            │             │             │             │          │
    │ GET        │             │             │             │          │
    │ comando    │             │             │             │          │
    │<───────────┤             │             │             │          │
    │            │             │             │             │          │
    │ Executar   │             │             │             │          │
    │ comando    │             │             │             │          │
    │            │             │             │             │          │
    │            │             │             │ Atualizar   │          │
    │            │             │             ├─────────────┼─────────>│
    │            │             │             │ Interface   │          │
    │            │             │             │             │          │
```

---

## 🗂️ Estrutura de Pastas Detalhada

```
pi-mds/
│
├── bin/                          # Ponto de entrada da aplicação
│   └── main.dart                 # Bootstrap e inicialização
│
├── lib/                          # Código fonte principal
│   │
│   ├── config/                   # Configurações
│   │   ├── database_config.dart  # Config MySQL
│   │   └── firebase_config.dart  # Config Firebase
│   │
│   ├── models/                   # MODEL - Entidades de dados
│   │   ├── dados_sensores.dart
│   │   ├── estado_climatizador.dart
│   │   ├── funcionario.dart
│   │   ├── log_entry.dart
│   │   └── preferencias_grupo.dart
│   │
│   ├── controllers/              # CONTROLLER - Lógica de negócio
│   │   └── sistema_iot_controller.dart
│   │
│   ├── ui/                       # VIEW - Interface do usuário
│   │   └── menu_interface_simple.dart
│   │
│   ├── services/                 # Camada de serviços
│   │   ├── firebase_service.dart
│   │   ├── funcionario_service.dart
│   │   ├── log_service.dart
│   │   └── saida_service.dart
│   │
│   ├── dao/                      # Data Access Objects
│   │   ├── funcionario_dao.dart
│   │   ├── historico_dao.dart
│   │   ├── log_dao.dart
│   │   └── preferencia_tag_dao.dart
│   │
│   ├── database/                 # Gerenciamento de banco de dados
│   │   └── database_connection.dart
│   │
│   └── utils/                    # Utilitários
│       └── console.dart
│
├── hardware/                     # Código do ESP32
│   └── esp32_main.ino
│
├── test/                         # Testes unitários
│
├── docs/                         # Documentação
│   └── ARQUITETURA_MVC.md       # Este arquivo
│
├── example/                      # Exemplos de uso
│   └── stream_examples.dart
│
├── Dump20251016/                # Backup do banco de dados
│
├── pubspec.yaml                 # Dependências do projeto
└── analysis_options.yaml        # Regras de análise de código
```

---

## 🔗 Fluxo de Comunicação MVC

### Fluxo 1: Leitura de Dados
```
ESP32 → Firebase → FirebaseService → Controller → View
                                    ↓
                                 HistoricoDao → MySQL
```

### Fluxo 2: Comando do Usuário
```
View → Controller → FirebaseService → Firebase → ESP32
                  ↓
               LogDao → MySQL
```

### Fluxo 3: Consulta de Histórico
```
View → Controller → HistoricoDao → MySQL → Controller → View
```

### Fluxo 4: Preferências de Funcionário
```
Tag RFID → ESP32 → Firebase → Controller → FuncionarioService
                                          ↓
                                    PreferenciaTagDao → MySQL
                                          ↓
                                    Aplicar Preferências
                                          ↓
                                    Enviar Comando → Firebase → ESP32
```

---

## 📊 Responsabilidades das Camadas

| Camada | Responsabilidade | Não deve fazer |
|--------|-----------------|----------------|
| **View** | - Apresentar dados<br>- Capturar entrada<br>- Formatação visual | - Lógica de negócio<br>- Acesso direto ao BD<br>- Processamento de dados |
| **Controller** | - Orquestrar fluxo<br>- Lógica de negócio<br>- Coordenar camadas | - Acesso direto ao BD<br>- Conhecer detalhes da View<br>- Formatação de UI |
| **Model** | - Representar dados<br>- Validação simples<br>- Serialização | - Lógica de negócio<br>- Acesso ao BD<br>- Conhecer outras camadas |
| **Service** | - Comunicação externa<br>- Lógica de aplicação<br>- Streams | - Acesso direto ao BD<br>- Detalhes de UI<br>- Lógica específica de View |
| **DAO** | - CRUD operations<br>- Queries SQL<br>- Transações | - Lógica de negócio<br>- Conhecer Services<br>- Processar regras |

---

## 🎨 Princípios de Design Aplicados

### SOLID
- ✅ **S**ingle Responsibility: Cada classe tem uma única responsabilidade
- ✅ **O**pen/Closed: Aberto para extensão, fechado para modificação
- ✅ **L**iskov Substitution: Interfaces bem definidas
- ✅ **I**nterface Segregation: Interfaces específicas
- ✅ **D**ependency Inversion: Depende de abstrações

### Padrões de Projeto
- ✅ **MVC**: Separação View-Controller-Model
- ✅ **DAO**: Data Access Object para persistência
- ✅ **Service Layer**: Lógica de negócio isolada
- ✅ **Observer**: Streams para comunicação assíncrona
- ✅ **Singleton**: Conexão de banco de dados

---

## 🚀 Fluxos de Execução Principais

### 1. Inicialização do Sistema
```dart
main() 
  → Configurar MySQL
  → Criar tabelas
  → Inicializar DAOs
  → Inicializar Services
  → Criar Controller
  → Iniciar monitoramento
  → Exibir Menu
```

### 2. Monitoramento em Tempo Real
```dart
Controller.iniciarMonitoramento()
  → FirebaseService.startSensoresPolling()
  → Receber dados via Stream
  → Processar preferências
  → Salvar histórico
  → Atualizar View
  → Loop contínuo
```

### 3. Aplicação de Preferências
```dart
Detectar tags RFID
  → Buscar funcionários (FuncionarioService)
  → Buscar preferências (PreferenciaTagDao)
  → Calcular configuração ótima
  → Enviar comando ao climatizador
  → Registrar log
```

---

## 📈 Escalabilidade e Manutenção

### Vantagens da Arquitetura
1. **Modularidade**: Fácil adicionar novos sensores/atuadores
2. **Testabilidade**: Cada camada pode ser testada isoladamente
3. **Manutenibilidade**: Mudanças localizadas em camadas específicas
4. **Reusabilidade**: Services e DAOs podem ser reutilizados
5. **Extensibilidade**: Novos controllers/views podem ser adicionados

### Pontos de Extensão
- Adicionar novos tipos de sensores (Model + Service)
- Criar novas interfaces (View)
- Implementar novos algoritmos (Controller)
- Adicionar novos bancos de dados (DAO)
- Integrar novos serviços externos (Service)

---

## 📝 Convenções de Código

### Nomenclatura
- **Classes**: PascalCase (ex: `SistemaIotController`)
- **Métodos**: camelCase (ex: `iniciarMonitoramento`)
- **Variáveis privadas**: _camelCase (ex: `_ultimaSensorData`)
- **Constantes**: UPPER_SNAKE_CASE (ex: `MAX_BUFFER_SIZE`)

### Organização de Imports
```dart
// 1. Dart SDK
import 'dart:async';
import 'dart:convert';

// 2. Packages externos
import 'package:http/http.dart' as http;

// 3. Imports internos
import '../models/dados_sensores.dart';
import '../services/firebase_service.dart';
```

---

## 🔐 Segurança e Boas Práticas

1. **Configurações sensíveis**: Separadas em arquivos de config
2. **Validação de dados**: Em múltiplas camadas
3. **Tratamento de erros**: Try-catch em operações críticas
4. **Logging**: Registro completo de operações
5. **Transações**: Para operações críticas no BD

---

## 📚 Dependências Principais

```yaml
dependencies:
  mysql1: ^0.20.0          # Conexão MySQL
  http: ^1.1.0             # Requisições HTTP
  intl: ^0.18.0            # Formatação de datas

dev_dependencies:
  lints: ^2.1.0            # Análise de código
  test: ^1.24.0            # Framework de testes
```

---

## 🎯 Conclusão

Esta arquitetura MVC proporciona:
- ✅ Separação clara de responsabilidades
- ✅ Código organizado e manutenível
- ✅ Escalabilidade horizontal e vertical
- ✅ Facilidade de testes
- ✅ Flexibilidade para mudanças futuras

O sistema está preparado para crescer e evoluir mantendo a qualidade e organização do código.

---

**Autor**: Sistema IoT Dashboard Team  
**Data**: Novembro 2025  
**Versão**: 1.0
