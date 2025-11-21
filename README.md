# 🏢 Sistema IoT Dashboard - Controle Inteligente de Ambiente

[![Dart](https://img.shields.io/badge/Dart-%5E3.9.1-blue.svg)](https://dart.dev/)
[![MySQL](https://img.shields.io/badge/MySQL-8.0-orange.svg)](https://www.mysql.com/)
[![Firebase](https://img.shields.io/badge/Firebase-Realtime%20DB-yellow.svg)](https://firebase.google.com/)
[![ESP32](https://img.shields.io/badge/Hardware-ESP32-green.svg)](https://www.espressif.com/)

Dashboard de console inteligente para controle automatizado de iluminação e climatização através de sensores IoT ESP32, com gerenciamento de preferências personalizadas por funcionário via RFID.

---

## 📋 Índice

- [Sobre o Projeto](#-sobre-o-projeto)
- [Features Principais](#-features-principais)
- [Arquitetura](#-arquitetura)
- [Tecnologias](#-tecnologias)
- [Estrutura do Projeto](#-estrutura-do-projeto)
- [Pré-requisitos](#-pré-requisitos)
- [Instalação](#-instalação)
- [Configuração](#-configuração)
- [Uso](#-uso)
- [Hardware](#-hardware)
- [Documentação](#-documentação)

---

## 🎯 Sobre o Projeto

O **Sistema IoT Dashboard** é uma solução completa de automação predial que integra hardware ESP32 com sensores ambientais, leitores RFID e controle de dispositivos (iluminação e climatização) através de uma arquitetura MVC robusta em Dart.

### Principais Objetivos

- ✅ **Automação Inteligente**: Controle automático baseado em preferências personalizadas
- ✅ **Eficiência Energética**: Otimização do consumo através de sensores ambientais
- ✅ **Personalização**: Sistema de preferências individuais por funcionário
- ✅ **Monitoramento Real-Time**: Visualização em tempo real de dados dos sensores
- ✅ **Histórico Completo**: Registro detalhado de todas as operações e eventos

---

## ⭐ Features Principais

### 🌡️ Monitoramento Ambiental
- **Temperatura e Umidade**: Leitura em tempo real via sensor DHT22
- **Luminosidade**: Medição precisa com sensor LDR
- **Presença**: Detecção de pessoas no ambiente
- **Dashboard em Console**: Interface interativa com atualização automática

### 👥 Gerenciamento de Funcionários
- **Cadastro Completo**: Nome, tag RFID, grupo e preferências
- **CRUD Completo**: Criar, ler, atualizar e excluir funcionários
- **Tags RFID**: Identificação automática de funcionários
- **Grupos de Preferências**: Organização por equipes/departamentos
- **Preferências Personalizadas**: Temperatura e luminosidade individuais

### 💡 Controle de Iluminação
- **Modo Automático**: Ajuste baseado em luminosidade ambiente e preferências
- **Controle Manual**: 5 níveis (0%, 25%, 50%, 75%, 100%)
- **Sistema PWM**: Controle preciso através de 4 relés
- **Sincronização Real-Time**: Comandos via Firebase
- **Histórico de Comandos**: Registro de todas as alterações

### ❄️ Controle de Climatização
- **Controle IR**: Envio de comandos infravermelhos para ar-condicionado
- **Estados Completos**: Power, velocidade, timer, umidificação
- **Aletas Direcionais**: Controle vertical e horizontal
- **Modo Automático**: Ajuste baseado em temperatura e preferências
- **Sincronização Bidirecional**: Firebase para ESP32 e vice-versa

### 🔄 Processamento de Preferências
- **Detecção de Grupo**: Identificação automática de funcionários presentes
- **Cálculo de Médias**: Preferências médias quando múltiplas pessoas presentes
- **Sistema de Prioridade**: Resolução de conflitos entre preferências
- **Preferências em Tempo Real**: Aplicação imediata ao detectar mudanças
- **Cache Inteligente**: Evita processamento redundante

### 📊 Sistema de Logs
- **6 Níveis de Log**: INFO, WARNING, ERROR, SUCCESS, DEBUG, SYSTEM
- **Contexto Rico**: Informações detalhadas sobre cada evento
- **Persistência MySQL**: Armazenamento permanente de todos os logs
- **Filtragem Avançada**: Busca por tipo, período, palavras-chave
- **Estatísticas**: Análise de padrões e frequência de eventos

### 💾 Histórico de Dados
- **Registro Completo**: Todos os dados dos sensores ao longo do tempo
- **Análise Temporal**: Visualização de tendências e padrões
- **Correlação de Eventos**: Relacionamento entre sensores e comandos
- **Exportação**: Dados estruturados para análise externa

### 🔥 Firebase Realtime Database
- **Comunicação Bidirecional**: Dashboard ↔ ESP32 em tempo real
- **Streams Assíncronos**: Atualizações instantâneas sem polling
- **Múltiplos Endpoints**:
  - `/sensores`: Dados dos sensores
  - `/climatizador`: Estado do ar-condicionado
  - `/comandos/iluminacao`: Controles de luz
  - `/comandos/climatizador`: Controles de clima
  - `/preferencias`: Solicitações e respostas de preferências
  - `/ultima_tag`: Tag RFID mais recente detectada

### 🗄️ MySQL Database
- **4 Tabelas Principais**:
  - `funcionarios`: Cadastro completo de funcionários
  - `dados_historicos`: Histórico de sensores
  - `logs`: Sistema de registro de eventos
  - `preferencias_tags`: Preferências individuais personalizadas
- **Integridade Referencial**: Chaves estrangeiras e constraints
- **Índices Otimizados**: Performance em consultas complexas
- **Backup Automático**: Scripts SQL de restauração

### 🎮 Interface Interativa
- **Menu Console Simples**: Navegação intuitiva via teclado
- **Dashboard Principal**: Visão geral do sistema em tempo real
- **Gestão de Funcionários**: CRUD completo com interface amigável
- **Visualização de Logs**: Filtros e busca avançada
- **Controles Manuais**: Override de automações quando necessário
- **Modo Background**: Processamento contínuo com interface responsiva
- **Buffer de Saída**: Sistema de mensagens com capacidade configurável

### 🔧 Sistema de Background Tasks
- **Polling Otimizado**: Intervalos inteligentes para cada serviço
- **Processamento Assíncrono**: Streams e Futures para operações não-bloqueantes
- **Auto-Recovery**: Reconexão automática em caso de falhas
- **Gerenciamento de Recursos**: Cleanup adequado de conexões e streams

---

## 🏗️ Arquitetura

O sistema segue o padrão **MVC (Model-View-Controller)** adaptado para IoT:

```
┌─────────────────────────────────────────────────────────┐
│                   USUÁRIO/DASHBOARD                      │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│               VIEW (UI/Interface)                        │
│  • MenuInterfaceSimple - Interface de Console           │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│          CONTROLLER (Orquestração)                       │
│  • SistemaIotController - Coordena todo o fluxo         │
└────────────────────┬────────────────────────────────────┘
                     │
         ┌───────────┴───────────┐
         ▼                       ▼
┌──────────────────┐    ┌──────────────────┐
│    SERVICES      │    │      DAOs        │
│  • Firebase      │    │  • Funcionario   │
│  • Funcionario   │    │  • Historico     │
│  • Log           │    │  • Log           │
│  • Saida         │    │  • PreferenciaTag│
└────────┬─────────┘    └────────┬─────────┘
         │                       │
         ▼                       ▼
┌──────────────────┐    ┌──────────────────┐
│  Firebase RT DB  │    │   MySQL 8.0      │
└──────────────────┘    └──────────────────┘
         ▲                       ▲
         │                       │
         └───────────┬───────────┘
                     │
                     ▼
         ┌───────────────────────┐
         │      ESP32 + IoT      │
         │  • DHT22 (Temp/Umid) │
         │  • LDR (Luz)         │
         │  • RFID RC522        │
         │  • IR (Controle)     │
         │  • Relés (4x)        │
         └───────────────────────┘
```

### Camadas do Sistema

1. **VIEW (Apresentação)**
   - Interface de usuário em console
   - Exibição de dados e menus
   - Captura de entrada do usuário

2. **CONTROLLER (Lógica de Negócio)**
   - Orquestração de fluxos
   - Processamento de regras de negócio
   - Gerenciamento de streams e eventos

3. **SERVICE (Serviços)**
   - Comunicação com Firebase
   - Lógica de funcionários e preferências
   - Sistema de logs
   - Buffer de saída

4. **DAO (Acesso a Dados)**
   - Operações CRUD no MySQL
   - Queries otimizadas
   - Gerenciamento de transações

5. **MODEL (Entidades)**
   - Estruturas de dados
   - Validações
   - Serialização/Desserialização

---

## 🛠️ Tecnologias

### Backend (Dart)
- **Dart SDK**: ^3.9.1
- **http**: ^1.1.0 - Requisições HTTP
- **mysql1**: ^0.20.0 - Driver MySQL
- **intl**: ^0.19.0 - Internacionalização
- **crypto**: ^3.0.3 - Criptografia
- **dotenv**: ^4.2.0 - Variáveis de ambiente
- **collection**: ^1.18.0 - Utilidades de coleções

### Database
- **MySQL**: 8.0 - Persistência de dados
- **Firebase Realtime Database** - Comunicação real-time

### Hardware
- **ESP32** - Microcontrolador principal
- **DHT22** - Sensor de temperatura e umidade
- **LDR** - Sensor de luminosidade
- **MFRC522** - Leitor RFID
- **IR LED** - Transmissor infravermelho
- **Relés** - 4 canais para controle de iluminação
- **LCD I2C** - Display 16x2
- **Buzzer** - Feedback sonoro

### Bibliotecas Arduino/C++
- WiFi.h - Conectividade
- HTTPClient.h - Requisições HTTP
- ArduinoJson.h - Parse JSON
- MFRC522.h - RFID
- DHT.h - Sensor de temperatura
- LiquidCrystal_I2C.h - Display LCD
- IRremote.hpp - Infravermelho

---

## 📁 Estrutura do Projeto

```
pi-mds/
├── 📂 bin/                      # Ponto de entrada
│   └── main.dart                # Inicialização do sistema
│
├── 📂 lib/                      # Código fonte principal
│   ├── 📂 config/               # Configurações
│   │   ├── database_config.dart # Config MySQL
│   │   └── firebase_config.dart # Config Firebase
│   │
│   ├── 📂 controllers/          # CONTROLLER Layer
│   │   └── sistema_iot_controller.dart
│   │
│   ├── 📂 services/             # SERVICE Layer
│   │   ├── firebase_service.dart
│   │   ├── funcionario_service.dart
│   │   ├── log_service.dart
│   │   └── saida_service.dart
│   │
│   ├── 📂 dao/                  # DAO Layer
│   │   ├── funcionario_dao.dart
│   │   ├── historico_dao.dart
│   │   ├── log_dao.dart
│   │   └── preferencia_tag_dao.dart
│   │
│   ├── 📂 models/               # MODEL Layer
│   │   ├── dados_sensores.dart
│   │   ├── estado_climatizador.dart
│   │   ├── funcionario.dart
│   │   ├── log_entry.dart
│   │   └── preferencias_grupo.dart
│   │
│   ├── 📂 ui/                   # VIEW Layer
│   │   └── menu_interface_simple.dart
│   │
│   ├── 📂 database/             # Database utilities
│   │   └── database_connection.dart
│   │
│   └── 📂 utils/                # Utilitários
│       └── console.dart
│
├── 📂 docs/                     # Documentação completa
│   ├── ARQUITETURA_MVC.md       # Detalhes da arquitetura
│   ├── GUIA_RAPIDO.md          # Guia rápido visual
│   ├── PLANEJAMENTO_RESUMO.md  # Planejamento do projeto
│   ├── DIAGRAMAS_ASCII.md      # Diagramas em ASCII
│   ├── DIAGRAMAS_MERMAID.md    # Diagramas em Mermaid
│   └── *.puml                   # Diagramas PlantUML
│
├── 📂 hardware/                 # Código ESP32
│   └── esp32_main.ino           # Firmware ESP32 (2600+ linhas)
│
├── 📂 Dump20251016/            # Backup MySQL
│   ├── pi_iot_system_dados_historicos.sql
│   ├── pi_iot_system_funcionarios.sql
│   ├── pi_iot_system_logs.sql
│   └── pi_iot_system_routines.sql
│
├── 📂 test/                     # Testes unitários
│
├── pubspec.yaml                 # Dependências Dart
├── analysis_options.yaml        # Linter Dart
└── README.md                    # Este arquivo
```

---

## 📋 Pré-requisitos

### Software
- **Dart SDK** ≥ 3.9.1
- **MySQL** 8.0 ou superior
- **Firebase Account** (Realtime Database habilitado)
- **Arduino IDE** ou **PlatformIO** (para ESP32)
- **Git** (opcional)

### Hardware (para sistema completo)
- **ESP32** (qualquer modelo com WiFi)
- **DHT22** (sensor temperatura/umidade)
- **LDR** (sensor de luz)
- **MFRC522** (leitor RFID)
- **IR LED** (transmissor infravermelho)
- **4x Relés** (5V)
- **LCD I2C 16x2**
- **Buzzer**
- **Tags RFID** (13.56MHz)
- Fonte de alimentação 5V
- Jumpers e protoboard

---

## 🚀 Instalação

### 1. Clone o Repositório

```powershell
git clone https://github.com/joaoaugusto-dev/pi-mds.git
cd pi-mds
```

### 2. Instale as Dependências Dart

```powershell
dart pub get
```

### 3. Configure o MySQL

Crie o banco de dados:

```sql
CREATE DATABASE pi_iot_system CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

Importe os dumps (opcional, para dados de exemplo):

```powershell
mysql -u root -p pi_iot_system < Dump20251016/pi_iot_system_funcionarios.sql
mysql -u root -p pi_iot_system < Dump20251016/pi_iot_system_logs.sql
mysql -u root -p pi_iot_system < Dump20251016/pi_iot_system_dados_historicos.sql
```

### 4. Configure o Firebase

1. Crie um projeto no [Firebase Console](https://console.firebase.google.com/)
2. Habilite o **Realtime Database**
3. Configure as regras de segurança (para desenvolvimento):

```json
{
  "rules": {
    ".read": true,
    ".write": true
  }
}
```

4. Obtenha a URL do database e o token de autenticação (se usar)

### 5. Configure as Variáveis de Ambiente

Edite os arquivos de configuração:

**`lib/config/database_config.dart`**:
```dart
class DatabaseConfig {
  final String host;
  final int port;
  final String user;
  final String password;
  final String database;

  const DatabaseConfig({
    required this.host,
    required this.port,
    required this.user,
    required this.password,
    required this.database,
  });

  static const DatabaseConfig defaultConfig = DatabaseConfig(
    host: 'localhost',
    port: 3306,
    user: 'seu_usuario',
    password: 'sua_senha',
    database: 'pi_iot_system',
  );
}
```

**`lib/config/firebase_config.dart`**:
```dart
class FirebaseConfig {
  static const String baseUrl = 
    'https://seu-projeto.firebaseio.com';
  static const String authToken = 'seu_token'; // ou '' se não usar
  
  // Paths
  static const String sensoresPath = '/sensores';
  static const String climatizadorPath = '/climatizador';
  static const String comandosPath = '/comandos';
  // ... outros paths
}
```

### 6. Configure o ESP32 (Opcional)

Edite `hardware/esp32_main.ino`:

```cpp
// WiFi
const char* ssid = "SUA_REDE";
const char* password = "SUA_SENHA";

// Firebase
const char* FIREBASE_HOST = "seu-projeto.firebaseio.com";
const char* FIREBASE_AUTH = ""; // ou seu token
```

Faça o upload para o ESP32 via Arduino IDE.

---

## ⚙️ Configuração

### Estrutura do MySQL

As tabelas são criadas automaticamente na primeira execução, mas você pode criá-las manualmente:

```sql
-- Funcionários
CREATE TABLE funcionarios (
  id INT AUTO_INCREMENT PRIMARY KEY,
  nome VARCHAR(100) NOT NULL,
  tag_rfid VARCHAR(50) UNIQUE NOT NULL,
  grupo VARCHAR(50),
  ativo BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Dados Históricos
CREATE TABLE dados_historicos (
  id INT AUTO_INCREMENT PRIMARY KEY,
  temperatura FLOAT,
  humidade FLOAT,
  luminosidade INT,
  pessoas_detectadas INT,
  timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_timestamp (timestamp)
);

-- Logs
CREATE TABLE logs (
  id INT AUTO_INCREMENT PRIMARY KEY,
  tipo VARCHAR(20) NOT NULL,
  mensagem TEXT NOT NULL,
  contexto TEXT,
  timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_tipo (tipo),
  INDEX idx_timestamp (timestamp)
);

-- Preferências por Tag
CREATE TABLE preferencias_tags (
  id INT AUTO_INCREMENT PRIMARY KEY,
  tag_rfid VARCHAR(50) NOT NULL,
  temperatura_preferida FLOAT,
  luminosidade_preferida INT,
  prioridade INT DEFAULT 1,
  ativo BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (tag_rfid) REFERENCES funcionarios(tag_rfid) ON DELETE CASCADE,
  UNIQUE KEY unique_tag_ativa (tag_rfid, ativo)
);
```

### Estrutura do Firebase

O Firebase Realtime Database terá a seguinte estrutura:

```json
{
  "sensores": {
    "temperatura": 25.5,
    "humidade": 60.0,
    "luminosidade": 75,
    "valorLDR": 512,
    "pessoas": 2,
    "tags": ["TAG123", "TAG456"],
    "timestamp": 1700000000000
  },
  "climatizador": {
    "ligado": true,
    "temperatura": 23.0,
    "velocidade": 2,
    "modo": "auto",
    "umidificando": false,
    "aletaVertical": true,
    "aletaHorizontal": false,
    "timer": 0,
    "timestamp": 1700000000000
  },
  "comandos": {
    "iluminacao": {
      "comando": "auto",
      "timestamp": 1700000000000,
      "origem": "app"
    },
    "climatizador": {
      "acao": "power",
      "timestamp": 1700000000000,
      "origem": "app"
    }
  },
  "preferencias": {
    "request": {
      "tags": ["TAG123", "TAG456"],
      "timestamp": 1700000000000
    },
    "response": {
      "temperatura_preferida": 23.0,
      "luminosidade_preferida": 75,
      "tags_presentes": ["TAG123", "TAG456"],
      "funcionarios_presentes": [...],
      "tags_desconhecidas": []
    }
  },
  "ultima_tag": "TAG123"
}
```

---

## 💻 Uso

### Executar o Dashboard

```powershell
dart run bin/main.dart
```

### Menu Principal

Ao iniciar, você verá o menu interativo:

```
╔══════════════════════════════════════════════════╗
║       SISTEMA IoT DASHBOARD - Menu Principal      ║
╚══════════════════════════════════════════════════╝

[1] 📊 Dashboard (Monitoramento Tempo Real)
[2] 👥 Gestão de Funcionários
[3] 💡 Controle de Iluminação
[4] ❄️  Controle de Climatização
[5] 📜 Visualizar Logs
[6] 📈 Histórico de Dados
[7] ⚙️  Configurações
[0] 🚪 Sair

Escolha uma opção:
```

### Dashboard em Tempo Real

Opção [1] exibe o dashboard com atualização automática:

```
╔════════════════════════════════════════════════════════╗
║            DASHBOARD - Sistema IoT                     ║
╠════════════════════════════════════════════════════════╣
║  🌡️  Temperatura: 25.5°C                               ║
║  💧 Umidade: 60.0%                                     ║
║  💡 Luminosidade: 75% (LDR: 512)                       ║
║  👥 Pessoas: 2                                         ║
║  🏷️  Tags: TAG123, TAG456                              ║
╠════════════════════════════════════════════════════════╣
║            Climatizador                                ║
║  Status: ✅ Ligado                                     ║
║  Temp: 23.0°C | Vel: 2 | Modo: auto                  ║
║  Umid: Não | Aletas: V:Sim H:Não                     ║
╠════════════════════════════════════════════════════════╣
║            Iluminação                                  ║
║  Comando Atual: auto                                   ║
╚════════════════════════════════════════════════════════╝

[B] Background ON/OFF | [Q] Voltar
```

### Gestão de Funcionários

Opção [2] permite:
- **Cadastrar** novo funcionário
- **Listar** todos os funcionários
- **Buscar** por nome ou tag
- **Atualizar** dados
- **Desativar/Ativar** funcionário
- **Excluir** funcionário

### Controles Manuais

**Iluminação** (Opção [3]):
- `auto` - Modo automático
- `0` - Desligado
- `25` - 25%
- `50` - 50%
- `75` - 75%
- `100` - 100%

**Climatização** (Opção [4]):
- Power ON/OFF
- Ajustar velocidade (1-3)
- Ligar/desligar umidificação
- Controlar aletas
- Configurar timer

### Logs e Histórico

**Logs** (Opção [5]):
- Visualizar por tipo (INFO, WARNING, ERROR, etc.)
- Filtrar por período
- Buscar por palavra-chave
- Estatísticas de eventos

**Histórico** (Opção [6]):
- Dados dos sensores ao longo do tempo
- Análise de tendências
- Exportação de dados

---

## 🔌 Hardware

### Esquema de Conexões ESP32

#### DHT22 (Temperatura/Umidade)
- VCC → 3.3V
- GND → GND
- DATA → GPIO 4

#### LDR (Luminosidade)
- Um terminal → 3.3V
- Outro terminal → GPIO 35 + Resistor 10kΩ para GND

#### MFRC522 (RFID)
- SDA → GPIO 5
- SCK → GPIO 18
- MOSI → GPIO 23
- MISO → GPIO 19
- RST → GPIO 15
- 3.3V → 3.3V
- GND → GND

#### IR LED (Transmissor)
- Anodo (+) → GPIO 33 via resistor 220Ω
- Catodo (-) → GND

#### IR Receiver (Receptor)
- VCC → 3.3V
- GND → GND
- DATA → GPIO 32

#### Relés (4 canais)
- VCC → 5V
- GND → GND
- IN1 → GPIO 14
- IN2 → GPIO 26
- IN3 → GPIO 27
- IN4 → GPIO 25

#### LCD I2C 16x2
- VCC → 5V
- GND → GND
- SDA → GPIO 21
- SCL → GPIO 22

#### Buzzer
- Positivo → GPIO 12
- Negativo → GND

### Pinout Resumido

| Periférico | GPIO | Função |
|------------|------|--------|
| DHT22 | 4 | Dados temp/umidade |
| LDR | 35 (ADC) | Leitura analógica luz |
| RFID SDA | 5 | Chip Select |
| RFID RST | 15 | Reset |
| IR TX | 33 | Transmissor IR |
| IR RX | 32 | Receptor IR |
| Relé 1 | 14 | Iluminação 25% |
| Relé 2 | 26 | Iluminação 50% |
| Relé 3 | 27 | Iluminação 75% |
| Relé 4 | 25 | Iluminação 100% |
| Buzzer | 12 | Feedback sonoro |
| LCD SDA | 21 | I2C Data |
| LCD SCL | 22 | I2C Clock |

---

## 📚 Documentação

### Documentação Completa

O projeto possui documentação extensa em `docs/`:

- **[ARQUITETURA_MVC.md](docs/ARQUITETURA_MVC.md)**: Detalhes completos da arquitetura MVC
- **[GUIA_RAPIDO.md](docs/GUIA_RAPIDO.md)**: Guia visual de referência rápida
- **[PLANEJAMENTO_RESUMO.md](docs/PLANEJAMENTO_RESUMO.md)**: Planejamento e roadmap do projeto
- **[DIAGRAMAS_ASCII.md](docs/DIAGRAMAS_ASCII.md)**: Diagramas em formato ASCII
- **[DIAGRAMAS_MERMAID.md](docs/DIAGRAMAS_MERMAID.md)**: Diagramas em formato Mermaid
- **Diagramas PlantUML** (.puml): Diagramas de classes, sequência e componentes

### Diagramas Disponíveis

- Diagrama de Classes
- Diagrama de Sequência
- Fluxo de Dados dos Sensores
- Arquitetura do Sistema
- Diagrama de Componentes

### API Reference

#### SistemaIotController

```dart
// Iniciar monitoramento em background
await controller.iniciarMonitoramentoBackground();

// Parar monitoramento
await controller.pararMonitoramentoBackground();

// Enviar comando de iluminação
await controller.enviarComandoIluminacao('auto');
await controller.enviarComandoIluminacao(75);

// Enviar comando de climatização
await controller.enviarComandoClimatizador('power');
await controller.enviarComandoClimatizador('velocidade');

// Processar preferências
PreferenciasGrupo? prefs = 
  await controller.processarSolicitacaoPreferencias(['TAG123']);
```

#### FirebaseService

```dart
// Ler dados dos sensores
DadosSensores? sensores = await firebaseService.lerSensores();

// Ler estado do climatizador
EstadoClimatizador? clima = await firebaseService.lerClimatizador();

// Enviar comando
await firebaseService.enviarComandoIluminacao('auto');
await firebaseService.enviarComandoClimatizador('power');

// Streams
Stream<DadosSensores?> sensoresStream = 
  firebaseService.sensoresStream;
```

#### FuncionarioService

```dart
// Cadastrar funcionário
await funcionarioService.cadastrarFuncionario(
  nome: 'João Silva',
  tagRfid: 'TAG123',
  grupo: 'TI',
);

// Listar todos
List<Funcionario> todos = 
  await funcionarioService.listarTodosFuncionarios();

// Buscar por tag
Funcionario? func = 
  await funcionarioService.buscarPorTag('TAG123');

// Atualizar
await funcionarioService.atualizarFuncionario(id, funcionario);

// Desativar
await funcionarioService.desativarFuncionario(id);
```

---

## 🔒 Segurança

### Recomendações de Produção

1. **Firebase**:
   - Configure regras de segurança adequadas
   - Use autenticação com token
   - Limite acesso por IP se possível

2. **MySQL**:
   - Use usuário com privilégios limitados
   - Configure bind-address adequadamente
   - Use SSL/TLS para conexões remotas

3. **Credenciais**:
   - Nunca commite credenciais no Git
   - Use variáveis de ambiente (.env)
   - Rotacione senhas periodicamente

4. **Rede**:
   - Use HTTPS quando possível
   - Configure firewall adequadamente
   - Isole rede IoT da rede principal

---

## 🤝 Contribuindo

Contribuições são bem-vindas! Para contribuir:

1. Fork o projeto
2. Crie uma branch para sua feature (`git checkout -b feature/AmazingFeature`)
3. Commit suas mudanças (`git commit -m 'Add some AmazingFeature'`)
4. Push para a branch (`git push origin feature/AmazingFeature`)
5. Abra um Pull Request

---

## 📝 Licença

Este projeto foi desenvolvido para fins educacionais como parte do Projeto Integrador.

---

## 👥 Autores

- **João Augusto** - [@joaoaugusto-dev](https://github.com/joaoaugusto-dev)

---

## 🙏 Agradecimentos

- Equipe do curso de Desenvolvimento de Sistemas
- Comunidade Dart/Flutter
- Espressif (ESP32)
- Firebase Team
- Todos os contribuidores de bibliotecas open-source utilizadas

---

## 📞 Suporte

Para suporte, abra uma [issue](https://github.com/joaoaugusto-dev/pi-mds/issues) no GitHub.

---

## 🗺️ Roadmap

### Versão 2.0 (Planejado)
- [ ] Interface Web com Flutter Web
- [ ] Aplicativo móvel (Android/iOS)
- [ ] Suporte a múltiplos ESP32
- [ ] Dashboard de análise avançada
- [ ] Exportação de relatórios PDF
- [ ] Integração com assistentes de voz
- [ ] API REST completa
- [ ] Sistema de notificações push
- [ ] Modo offline com sincronização

### Versão 2.1 (Futuro)
- [ ] Machine Learning para predição de preferências
- [ ] Integração com sensores adicionais (CO2, partículas)
- [ ] Controle de persianas automáticas
- [ ] Sistema de economia de energia
- [ ] Relatórios de sustentabilidade

---

<div align="center">

**[⬆ Voltar ao topo](#-sistema-iot-dashboard---controle-inteligente-de-ambiente)**

Made with ❤️ and Dart

</div>
