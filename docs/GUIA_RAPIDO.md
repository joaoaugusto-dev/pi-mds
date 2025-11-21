# 🚀 Guia Rápido Visual - Sistema IoT Dashboard

Guia visual de uma página para referência rápida do sistema.

---

## 📊 Visão Geral em 1 Minuto

| Aspecto | Detalhes |
|---------|----------|
| **Padrão** | MVC (Model-View-Controller) |
| **Linguagem** | Dart ≥ 3.0.0 |
| **Database** | MySQL 8.0 + Firebase Realtime DB |
| **Hardware** | ESP32 + Sensores IoT |
| **Camadas** | 5 (View, Controller, Service, DAO, Model) |

---

## 🎨 Arquitetura Visual Simplificada

```
  👤 USUÁRIO
      ↕
  📱 VIEW (Interface)
      ↕
  🎮 CONTROLLER (Lógica)
      ↕
  🔧 SERVICES (Regras)
      ↕
  💾 DAOs (Persistência)
      ↕
  🗄️ DATABASES
```

---

## 📁 Estrutura de Pastas (Simplificada)

```
pi-mds/
├── 📂 bin/           → Ponto de entrada (main.dart)
├── 📂 lib/
│   ├── 📂 ui/        → VIEW
│   ├── 📂 controllers/ → CONTROLLER
│   ├── 📂 services/  → SERVICES
│   ├── 📂 dao/       → DAOs
│   └── 📂 models/    → MODELS
├── 📂 docs/          → Documentação completa
└── 📂 hardware/      → Código ESP32
```

---

## 🔄 Fluxo de Dados Simplificado

```
ESP32 → Firebase → Service → Controller → View
                      ↓
                    MySQL
```

---

## 📦 Componentes Principais

### 🎮 Controller
- **SistemaIotController**: Cérebro do sistema

### 👁️ View
- **MenuInterfaceSimple**: Interface do usuário

### 🔧 Services (4)
1. **FirebaseService**: Comunicação RT
2. **FuncionarioService**: Gestão de funcionários
3. **LogService**: Sistema de logs
4. **SaidaService**: Buffer de saída

### 💾 DAOs (4)
1. **FuncionarioDao**
2. **HistoricoDao**
3. **LogDao**
4. **PreferenciaTagDao**

### 📊 Models (5)
1. **DadosSensores**
2. **EstadoClimatizador**
3. **Funcionario**
4. **LogEntry**
5. **PreferenciasGrupo**

---

## 🗃️ Bancos de Dados

### MySQL (Persistência)
- ✅ funcionarios
- ✅ dados_historicos
- ✅ logs
- ✅ preferencias_tags

### Firebase (Tempo Real)
- ✅ /sensores/dados
- ✅ /climatizador/estado
- ✅ /comandos/*

---

## 🔑 Conceitos-Chave

| Conceito | Descrição |
|----------|-----------|
| **MVC** | Separação View-Controller-Model |
| **DAO** | Data Access Object (acesso BD) |
| **Service** | Lógica de negócio isolada |
| **Stream** | Comunicação assíncrona |
| **Polling** | Consulta periódica (5s) |

---

## ⚡ 3 Fluxos Principais

### 1️⃣ Leitura de Sensores
```
ESP32 → Firebase → Service → Controller → MySQL + UI
```

### 2️⃣ Preferências
```
RFID → Service → DAO → MySQL → Calcular → Firebase → ESP32
```

### 3️⃣ Comando Manual
```
UI → Controller → Service → Firebase → ESP32
```

---

## 📚 Documentação Disponível

| Arquivo | Propósito |
|---------|-----------|
| **PLANEJAMENTO_RESUMO.md** | ⭐ Resumo executivo |
| **ARQUITETURA_MVC.md** | 📐 Arquitetura completa |
| **DIAGRAMAS_MERMAID.md** | 📊 Diagramas interativos |
| **DIAGRAMAS_ASCII.md** | 🔠 Diagramas texto |
| ***.puml** | 🖼️ Diagramas PlantUML |

---

## 🎯 Responsabilidades por Camada

```
VIEW        → Exibir dados e capturar entrada
CONTROLLER  → Orquestrar e processar lógica
SERVICE     → Regras de negócio e comunicação
DAO         → CRUD no banco de dados
MODEL       → Representar entidades
```

---

## 🔧 Comandos Úteis

```bash
# Executar
dart run bin/main.dart

# Testar
dart test

# Analisar
dart analyze

# Formatar
dart format .
```

---

## ✅ Checklist Rápido

### Desenvolvimento
- [ ] Entendeu arquitetura MVC
- [ ] Conhece os 5 Models
- [ ] Sabe onde está cada camada
- [ ] Compreende o fluxo de dados

### Implementação
- [ ] MySQL configurado
- [ ] Firebase configurado
- [ ] Dependencies instaladas
- [ ] ESP32 programado

---

## 📊 Métricas do Sistema

| Métrica | Valor |
|---------|-------|
| Polling Interval | 5 segundos |
| Controllers | 1 |
| Services | 4 |
| DAOs | 4 |
| Models | 5 |
| Databases | 2 (MySQL + Firebase) |
| Camadas | 5 |

---

## 🎨 Código de Cores (Diagramas)

- 🟢 Verde: DAOs / Database
- 🔵 Azul: Controller
- 🟣 Roxo: View
- 🟡 Amarelo: Model
- 🔶 Laranja: Services
- 🔴 Vermelho: Hardware

---

## 🔗 Dependências Principais

```yaml
mysql1: ^0.20.0    # MySQL
http: ^1.1.0       # HTTP Client
intl: ^0.18.0      # Formatação
```

---

## 📞 Troubleshooting Rápido

| Problema | Solução |
|----------|---------|
| Erro MySQL | Verificar DatabaseConfig |
| Erro Firebase | Verificar FirebaseConfig |
| Sem dados | Verificar ESP32 WiFi |
| Erro Stream | Reiniciar polling |

---

## 🎯 Princípios SOLID

- ✅ **S**ingle Responsibility
- ✅ **O**pen/Closed
- ✅ **L**iskov Substitution
- ✅ **I**nterface Segregation
- ✅ **D**ependency Inversion

---

## 📈 Próximos Passos

1. ⏳ Implementar testes
2. ⏳ Criar interface gráfica
3. ⏳ Sistema de notificações
4. ⏳ Dashboard analítico

---

## 🎓 Para Aprender Mais

1. Leia **PLANEJAMENTO_RESUMO.md**
2. Estude **ARQUITETURA_MVC.md**
3. Veja **DIAGRAMAS_MERMAID.md**
4. Explore código em `lib/`

---

## 💡 Dicas Importantes

- 📖 Comece pela documentação
- 🎯 Entenda o MVC primeiro
- 🔄 Siga o fluxo de dados
- 🧩 Uma camada por vez
- ✅ Teste cada componente

---

## 🏆 Boas Práticas

✅ Nomenclatura consistente  
✅ Comentários adequados  
✅ Separação de responsabilidades  
✅ Tratamento de erros  
✅ Logging completo  

---

## 📊 Stack Tecnológico

```
┌─────────────────┐
│   Dart/Flutter  │ Linguagem
├─────────────────┤
│   MySQL 8.0     │ Persistência
├─────────────────┤
│   Firebase      │ Real-time
├─────────────────┤
│   ESP32         │ Hardware IoT
├─────────────────┤
│   Sensores      │ DHT22, LDR, etc
└─────────────────┘
```

---

## 🎯 Onde Encontrar

| O que você precisa | Onde está |
|-------------------|-----------|
| Entry Point | `bin/main.dart` |
| Controller | `lib/controllers/` |
| View | `lib/ui/` |
| Services | `lib/services/` |
| DAOs | `lib/dao/` |
| Models | `lib/models/` |
| Configs | `lib/config/` |
| Docs | `docs/` |

---

## 🔄 Ciclo de Vida

```
Iniciar → Config → DAOs → Services →
→ Controller → Menu → Loop infinito
```

---

## 📱 Interface do Usuário

```
┌─────────────────────────┐
│  MENU PRINCIPAL         │
├─────────────────────────┤
│ 1. Dashboard            │
│ 2. Controle Clima       │
│ 3. Controle Iluminação  │
│ 4. Histórico            │
│ 5. Funcionários         │
│ 6. Logs                 │
│ 7. Sair                 │
└─────────────────────────┘
```

---

## 🎨 Padrões Utilizados

- 🏗️ MVC
- 🗃️ DAO
- 🔧 Service Layer
- 👀 Observer (Streams)
- 🔄 Singleton (DB Connection)

---

## ⚙️ Configurações Importantes

```dart
// Firebase
baseUrl: "https://pi-iot-system.firebaseio.com"

// MySQL
host: "localhost"
port: 3306
database: "pi_iot_system"

// Polling
interval: 5 segundos
```

---

## 📊 Estatísticas

- 📄 Linhas de código: ~5000+
- 📁 Arquivos Dart: 20+
- 📚 Documentos: 7
- 📊 Diagramas: 15+
- ⏱️ Tempo leitura docs: ~1h30min

---

## 🚀 Início Rápido (3 passos)

```bash
# 1. Clonar
git clone [repo]

# 2. Configurar
# Edite configs em lib/config/

# 3. Executar
dart run bin/main.dart
```

---

## 🎯 Objetivos do Sistema

1. ✅ Monitorar ambiente em tempo real
2. ✅ Controlar climatização automaticamente
3. ✅ Aplicar preferências por grupo
4. ✅ Registrar histórico completo
5. ✅ Interface amigável

---

## 📖 Glossário Rápido

| Termo | Significado |
|-------|-------------|
| **MVC** | Model-View-Controller |
| **DAO** | Data Access Object |
| **CRUD** | Create, Read, Update, Delete |
| **RT** | Real-time (Tempo Real) |
| **RFID** | Radio-Frequency Identification |
| **IoT** | Internet of Things |

---

## 🎓 Nível de Conhecimento

### Básico ✅
- Entender MVC
- Conhecer estrutura
- Saber executar

### Intermediário ⚡
- Modificar código
- Adicionar features
- Debugar problemas

### Avançado 🚀
- Otimizar performance
- Refatorar arquitetura
- Implementar novos padrões

---

## 📌 Links Úteis

- 📚 Docs completas: `docs/`
- 🎯 Resumo: `PLANEJAMENTO_RESUMO.md`
- 📐 Arquitetura: `ARQUITETURA_MVC.md`
- 📊 Diagramas: `DIAGRAMAS_MERMAID.md`

---

## ✨ Recursos Destacados

⭐ Arquitetura MVC profissional  
⭐ Documentação completa  
⭐ 15+ diagramas  
⭐ Código organizado  
⭐ Boas práticas  

---

**Este é um guia de referência rápida de 1 página.**  
**Para informações detalhadas, consulte a documentação completa em `docs/`**

---

**Versão**: 1.0  
**Data**: Novembro 2025  
**Status**: ✅ Completo

---

🚀 **Desenvolvido com ❤️ para Sistema IoT Dashboard**
