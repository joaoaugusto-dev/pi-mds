# 📊 Diagramas Mermaid - Sistema IoT Dashboard

Este documento contém diagramas em formato Mermaid que podem ser visualizados em plataformas compatíveis (GitHub, GitLab, VS Code com extensão Mermaid).

---

## 🏗️ Diagrama de Arquitetura de Componentes

```mermaid
graph TB
    subgraph "Hardware Layer"
        ESP32[ESP32 IoT Device]
        SENSORS[Sensores: DHT22, LDR, HC-SR501, RFID]
        ACTUATORS[Atuadores: Relés, PWM]
    end

    subgraph "Data Layer"
        FIREBASE[(Firebase Realtime DB)]
        MYSQL[(MySQL Database)]
    end

    subgraph "Service Layer"
        FS[FirebaseService]
        FUNCS[FuncionarioService]
        LS[LogService]
        SS[SaidaService]
    end

    subgraph "DAO Layer"
        FDAO[FuncionarioDao]
        HDAO[HistoricoDao]
        LDAO[LogDao]
        PDAO[PreferenciaTagDao]
    end

    subgraph "Controller Layer"
        CTRL[SistemaIotController]
    end

    subgraph "View Layer"
        UI[MenuInterfaceSimple]
    end

    subgraph "Model Layer"
        M1[DadosSensores]
        M2[EstadoClimatizador]
        M3[Funcionario]
        M4[LogEntry]
        M5[PreferenciasGrupo]
    end

    ESP32 --> SENSORS
    ESP32 --> ACTUATORS
    ESP32 <-->|WiFi| FIREBASE
    
    FIREBASE <-->|HTTP| FS
    
    FS --> CTRL
    FUNCS --> CTRL
    LS --> CTRL
    SS --> CTRL
    
    FDAO --> FUNCS
    PDAO --> FUNCS
    LDAO --> LS
    HDAO --> CTRL
    
    FDAO --> MYSQL
    HDAO --> MYSQL
    LDAO --> MYSQL
    PDAO --> MYSQL
    
    CTRL --> UI
    
    M1 -.->|usa| CTRL
    M2 -.->|usa| CTRL
    M3 -.->|usa| FUNCS
    M4 -.->|usa| LS
    M5 -.->|usa| FUNCS

    style ESP32 fill:#ff6b6b
    style FIREBASE fill:#ffd93d
    style MYSQL fill:#6bcf7f
    style CTRL fill:#4ecdc4
    style UI fill:#95e1d3
```

---

## 🔄 Diagrama de Fluxo de Dados (Data Flow)

```mermaid
flowchart LR
    subgraph Hardware
        H[ESP32]
    end

    subgraph Firebase
        FDB[(Firebase RT DB)]
    end

    subgraph Services
        FS[FirebaseService<br/>Streams]
    end

    subgraph Controller
        C[SistemaIotController<br/>Processing]
    end

    subgraph Storage
        M[(MySQL)]
    end

    subgraph Interface
        UI[Menu Interface]
    end

    H -->|PUT Dados| FDB
    FDB -->|Polling| FS
    FS -->|Stream| C
    C -->|Save| M
    C -->|Update| UI
    UI -->|Commands| C
    C -->|PUT| FDB
    FDB -->|GET| H
    M -->|Query| C

    style H fill:#ff6b6b
    style FDB fill:#ffd93d
    style FS fill:#a8dadc
    style C fill:#4ecdc4
    style M fill:#6bcf7f
    style UI fill:#95e1d3
```

---

## 📋 Diagrama de Classes (Simplificado)

```mermaid
classDiagram
    class SistemaIotController {
        -FirebaseService firebaseService
        -FuncionarioService funcionarioService
        -LogService logService
        -HistoricoDao historicoDao
        -DadosSensores ultimaSensorData
        -EstadoClimatizador ultimoEstadoClima
        +iniciarMonitoramento()
        +pararMonitoramento()
        +enviarComandoIluminacao()
        +enviarComandoClimatizador()
        +obterHistorico()
    }

    class FirebaseService {
        -String baseUrl
        -String authToken
        -Stream sensoresController
        -Stream climatizadorController
        +startSensoresPolling()
        +startClimatizadorPolling()
        +putComandoIluminacao()
        +putComandoClimatizador()
        +getSensoresData()
    }

    class FuncionarioService {
        -FuncionarioDao funcionarioDao
        -PreferenciaTagDao preferenciaDao
        +buscarPorTags()
        +obterPreferencias()
        +calcularPreferenciaOtima()
    }

    class DadosSensores {
        +double temperatura
        +double humidade
        +int luminosidade
        +int pessoas
        +List~String~ tags
        +DateTime timestamp
    }

    class EstadoClimatizador {
        +double temperatura
        +String modo
        +int velocidade
        +bool status
    }

    class Funcionario {
        +int id
        +String nome
        +String tag_rfid
        +String grupo
        +bool ativo
    }

    class HistoricoDao {
        +inserir()
        +buscarPorPeriodo()
        +calcularMedias()
    }

    class FuncionarioDao {
        +inserir()
        +buscarPorTag()
        +listarTodos()
    }

    SistemaIotController --> FirebaseService
    SistemaIotController --> FuncionarioService
    SistemaIotController --> HistoricoDao
    SistemaIotController ..> DadosSensores
    SistemaIotController ..> EstadoClimatizador
    FuncionarioService --> FuncionarioDao
    FuncionarioService ..> Funcionario
```

---

## ⚡ Diagrama de Sequência - Processamento de Sensores

```mermaid
sequenceDiagram
    participant E as ESP32
    participant F as Firebase
    participant FS as FirebaseService
    participant C as Controller
    participant D as HistoricoDao
    participant UI as Interface

    E->>F: PUT /sensores/dados
    Note over E,F: Dados: temp, umid, lux, tags

    loop Polling (5s)
        FS->>F: GET /sensores/dados
        F-->>FS: JSON Data
    end

    FS->>C: Stream~DadosSensores~
    
    activate C
    C->>C: Processar Preferências
    C->>C: Validar Dados
    
    C->>D: Salvar Histórico
    D-->>C: OK
    
    C->>UI: Atualizar Dashboard
    deactivate C

    Note over C: Se necessário enviar comando
    C->>FS: PUT Comando
    FS->>F: PUT /comandos/climatizador
    F->>E: ESP32 lê comando
```

---

## 🎯 Diagrama de Sequência - Aplicação de Preferências

```mermaid
sequenceDiagram
    participant E as ESP32
    participant F as Firebase
    participant C as Controller
    participant FuncS as FuncionarioService
    participant FuncD as FuncionarioDao
    participant PrefD as PreferenciaTagDao

    E->>F: PUT tags: [TAG123, TAG456]
    F->>C: Stream atualização tags
    
    C->>FuncS: buscarPorTags([TAG123, TAG456])
    
    FuncS->>FuncD: buscarPorTag(TAG123)
    FuncD-->>FuncS: Funcionario A
    
    FuncS->>FuncD: buscarPorTag(TAG456)
    FuncD-->>FuncS: Funcionario B
    
    FuncS->>PrefD: buscarPorTag(TAG123)
    PrefD-->>FuncS: Preferencias A
    
    FuncS->>PrefD: buscarPorTag(TAG456)
    PrefD-->>FuncS: Preferencias B
    
    FuncS->>FuncS: calcularPreferenciaOtima()
    FuncS-->>C: Configuração Ideal
    
    C->>F: PUT /comandos/climatizador
    Note over C,F: temp: 23°C, modo: auto
    
    F->>E: ESP32 aplica configuração
```

---

## 🗄️ Diagrama de Entidade-Relacionamento (ER)

```mermaid
erDiagram
    FUNCIONARIOS ||--o{ PREFERENCIAS_TAGS : tem
    FUNCIONARIOS {
        int id PK
        string nome
        string tag_rfid UK
        string grupo
        boolean ativo
        datetime created_at
    }

    PREFERENCIAS_TAGS {
        string tag_rfid PK,FK
        double temperatura_ideal
        double temperatura_min
        double temperatura_max
        int iluminacao_minima
        int prioridade
    }

    DADOS_HISTORICOS {
        int id PK
        double temperatura
        double humidade
        int luminosidade
        int ldr
        int pessoas
        json tags
        datetime timestamp
        int iluminacao_artificial
    }

    LOGS {
        int id PK
        string tipo
        text mensagem
        datetime timestamp
        json contexto
    }

    ROUTINES {
        int id PK
        string nome
        string tipo
        time hora_inicio
        time hora_fim
        json configuracao
        boolean ativo
    }
```

---

## 🔀 Diagrama de Estados - Climatizador

```mermaid
stateDiagram-v2
    [*] --> Desligado
    
    Desligado --> Manual : Comando Manual
    Desligado --> Auto : Modo Auto
    
    Auto --> Aquecendo : Temp < Ideal
    Auto --> Resfriando : Temp > Ideal
    Auto --> Standby : Temp = Ideal
    
    Manual --> Aquecendo : Temp Alvo Maior
    Manual --> Resfriando : Temp Alvo Menor
    Manual --> Ventilando : Apenas Ventilar
    
    Aquecendo --> Standby : Temp Alcançada
    Resfriando --> Standby : Temp Alcançada
    Ventilando --> Standby : Comando Stop
    
    Standby --> Auto : Verificar Preferências
    Standby --> Desligado : Sem Pessoas
    
    Auto --> Desligado : Timeout/Sem Pessoas
    Manual --> Desligado : Comando Desligar
```

---

## 🔄 Diagrama de Atividades - Monitoramento

```mermaid
flowchart TD
    Start([Iniciar Sistema]) --> InitDB[Inicializar MySQL]
    InitDB --> InitServices[Inicializar Services]
    InitServices --> InitController[Criar Controller]
    InitController --> StartMon[Iniciar Monitoramento]
    
    StartMon --> PollSensores{Polling Sensores<br/>a cada 5s}
    PollSensores --> RecebeDados[Recebe Dados]
    RecebeDados --> ValidaDados{Dados Válidos?}
    
    ValidaDados -->|Não| LogErro[Registrar Erro]
    LogErro --> PollSensores
    
    ValidaDados -->|Sim| ProcTags{Tem Tags?}
    
    ProcTags -->|Sim| BuscaPref[Buscar Preferências]
    BuscaPref --> CalcPref[Calcular Config Ótima]
    CalcPref --> EnviaCmd[Enviar Comando]
    EnviaCmd --> SalvaHist[Salvar Histórico]
    
    ProcTags -->|Não| SalvaHist
    
    SalvaHist --> AtualizaUI[Atualizar Interface]
    AtualizaUI --> VerificaBG{Background<br/>Running?}
    
    VerificaBG -->|Sim| PollSensores
    VerificaBG -->|Não| End([Fim])
    
    style Start fill:#95e1d3
    style End fill:#ff6b6b
    style ValidaDados fill:#ffd93d
    style ProcTags fill:#ffd93d
    style VerificaBG fill:#ffd93d
```

---

## 📦 Diagrama de Deployment

```mermaid
graph TB
    subgraph "Cliente / Servidor Local"
        subgraph "Aplicação Dart"
            APP[main.dart]
            CTRL[Controllers]
            SVC[Services]
            DAO[DAOs]
        end
        
        MYSQL_LOCAL[(MySQL<br/>Local)]
    end

    subgraph "Cloud - Firebase"
        FIREBASE_RT[(Firebase<br/>Realtime DB)]
    end

    subgraph "Ambiente Físico"
        ESP32_1[ESP32 - Sala A]
        ESP32_2[ESP32 - Sala B]
        
        SENSORS_1[Sensores Sala A]
        SENSORS_2[Sensores Sala B]
        
        HVAC_1[HVAC Sala A]
        HVAC_2[HVAC Sala B]
    end

    APP --> CTRL
    CTRL --> SVC
    SVC --> DAO
    DAO <-->|SQL| MYSQL_LOCAL
    SVC <-->|HTTPS| FIREBASE_RT
    
    ESP32_1 --> SENSORS_1
    ESP32_1 --> HVAC_1
    ESP32_1 <-->|WiFi| FIREBASE_RT
    
    ESP32_2 --> SENSORS_2
    ESP32_2 --> HVAC_2
    ESP32_2 <-->|WiFi| FIREBASE_RT

    style APP fill:#4ecdc4
    style MYSQL_LOCAL fill:#6bcf7f
    style FIREBASE_RT fill:#ffd93d
    style ESP32_1 fill:#ff6b6b
    style ESP32_2 fill:#ff6b6b
```

---

## 🎨 Diagrama de Pacotes

```mermaid
graph LR
    subgraph "pi-mds"
        subgraph "bin"
            MAIN[main.dart]
        end

        subgraph "lib"
            subgraph "config"
                DBCONF[database_config]
                FBCONF[firebase_config]
            end

            subgraph "models"
                M1[dados_sensores]
                M2[estado_climatizador]
                M3[funcionario]
                M4[log_entry]
                M5[preferencias_grupo]
            end

            subgraph "controllers"
                CTRL[sistema_iot_controller]
            end

            subgraph "services"
                FS[firebase_service]
                FUNCS[funcionario_service]
                LS[log_service]
                SS[saida_service]
            end

            subgraph "dao"
                FDAO[funcionario_dao]
                HDAO[historico_dao]
                LDAO[log_dao]
                PDAO[preferencia_tag_dao]
            end

            subgraph "database"
                DBCONN[database_connection]
            end

            subgraph "ui"
                UI[menu_interface_simple]
            end

            subgraph "utils"
                UTILS[console]
            end
        end

        subgraph "hardware"
            ESP[esp32_main.ino]
        end
    end

    MAIN --> CTRL
    MAIN --> UI
    
    CTRL --> FS
    CTRL --> FUNCS
    CTRL --> LS
    
    FS --> FBCONF
    FS --> SS
    
    FUNCS --> FDAO
    FUNCS --> PDAO
    
    LS --> LDAO
    
    CTRL --> HDAO
    
    FDAO --> DBCONN
    HDAO --> DBCONN
    LDAO --> DBCONN
    PDAO --> DBCONN
    
    DBCONN --> DBCONF
    
    UI --> UTILS

    style MAIN fill:#4ecdc4
    style CTRL fill:#95e1d3
    style models fill:#ffd93d
    style services fill:#a8dadc
    style dao fill:#6bcf7f
```

---

## 📊 Diagrama de Casos de Uso

```mermaid
graph TB
    subgraph "Sistema IoT Dashboard"
        UC1[Monitorar Sensores]
        UC2[Controlar Climatizador]
        UC3[Gerenciar Iluminação]
        UC4[Aplicar Preferências]
        UC5[Visualizar Histórico]
        UC6[Gerenciar Funcionários]
        UC7[Consultar Logs]
        UC8[Configurar Sistema]
    end

    ADMIN((Administrador))
    USER((Funcionário))
    ESP32((ESP32))

    ADMIN --> UC1
    ADMIN --> UC2
    ADMIN --> UC3
    ADMIN --> UC5
    ADMIN --> UC6
    ADMIN --> UC7
    ADMIN --> UC8

    USER --> UC4
    USER -.-> UC1

    ESP32 --> UC1
    ESP32 -.-> UC2
    ESP32 -.-> UC3

    UC4 --> UC2
    UC4 --> UC3

    style ADMIN fill:#4ecdc4
    style USER fill:#95e1d3
    style ESP32 fill:#ff6b6b
```

---

## 🔧 Diagrama de Comunicação - MVC

```mermaid
graph LR
    subgraph "MVC Pattern"
        V[View<br/>MenuInterface]
        C[Controller<br/>SistemaIotController]
        M[Model<br/>Entities]
    end

    subgraph "Supporting Layers"
        S[Services]
        D[DAOs]
        DB[(Database)]
    end

    V -->|User Action| C
    C -->|Update View| V
    C -->|Read/Write| M
    M -.->|Notify| V
    
    C --> S
    S --> D
    D <--> DB

    style V fill:#95e1d3
    style C fill:#4ecdc4
    style M fill:#ffd93d
    style S fill:#a8dadc
    style D fill:#6bcf7f
    style DB fill:#6bcf7f
```

---

## 📈 Diagrama de Tempo - Ciclo Completo

```mermaid
sequenceDiagram
    autonumber
    participant ESP as ESP32
    participant FB as Firebase
    participant SYS as Sistema
    participant DB as MySQL
    participant UI as Interface

    Note over ESP,UI: Ciclo de 5 segundos

    ESP->>FB: Enviar dados sensores
    SYS->>FB: Polling (GET)
    FB-->>SYS: Dados JSON
    
    SYS->>SYS: Validar dados
    SYS->>SYS: Processar preferências
    
    par Salvar e Atualizar
        SYS->>DB: Inserir histórico
        and
        SYS->>UI: Atualizar display
    end
    
    alt Comando necessário
        SYS->>FB: PUT comando
        FB->>ESP: ESP lê comando
        ESP->>ESP: Executar ação
    end
    
    Note over ESP,UI: Aguardar próximo ciclo
```

---

**Nota**: Estes diagramas podem ser visualizados em:
- GitHub/GitLab (renderização automática)
- VS Code com extensão Mermaid
- Plataformas online como Mermaid Live Editor
- Ferramentas de documentação compatíveis

Para melhor visualização, recomenda-se usar fundo claro e zoom apropriado.
