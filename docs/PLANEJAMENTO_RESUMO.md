# 📊 Planejamento Arquitetural - Sistema IoT Dashboard
## Resumo Executivo e Guia de Implementação

---

## 🎯 Objetivo do Documento

Este documento apresenta o planejamento estruturado da arquitetura MVC (Model-View-Controller) do Sistema IoT Dashboard, incluindo diagramas, especificações técnicas e diretrizes de implementação.

---

## 📁 Estrutura da Documentação

O planejamento está organizado nos seguintes documentos:

### 1. **ARQUITETURA_MVC.md** (Documento Principal)
   - Visão geral da arquitetura
   - Descrição detalhada de cada camada
   - Responsabilidades e componentes
   - Fluxos de execução
   - Boas práticas e convenções

### 2. **DIAGRAMAS_MERMAID.md** (Diagramas Interativos)
   - Diagrama de Componentes
   - Diagrama de Fluxo de Dados
   - Diagrama de Classes
   - Diagramas de Sequência
   - Diagrama de Estados
   - Diagrama de Deployment
   - Diagrama ER (Entidade-Relacionamento)

### 3. **Arquivos PlantUML** (Diagramas Profissionais)
   - `arquitetura_sistema.puml` - Arquitetura geral
   - `diagrama_classes.puml` - Classes detalhadas
   - `fluxo_dados_sensores.puml` - Sequência de operações

---

## 🏗️ Visão Geral da Arquitetura

```
┌─────────────────────────────────────────┐
│         ESP32 (Hardware)                │
│   Sensores + Atuadores + WiFi           │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│      Firebase Realtime Database         │
│    (Comunicação em Tempo Real)          │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│       Sistema Dart (MVC)                │
│  ┌─────────────────────────────────┐   │
│  │  VIEW - MenuInterfaceSimple     │   │
│  └──────────────┬──────────────────┘   │
│                 │                       │
│  ┌──────────────▼──────────────────┐   │
│  │  CONTROLLER - SistemaIotCtrl    │   │
│  └──────────────┬──────────────────┘   │
│                 │                       │
│  ┌──────────────▼──────────────────┐   │
│  │  SERVICES + DAOs                │   │
│  └──────────────┬──────────────────┘   │
│                 │                       │
│  ┌──────────────▼──────────────────┐   │
│  │  MODELS (Entidades)             │   │
│  └─────────────────────────────────┘   │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│         MySQL Database                  │
│  (Persistência de Dados)                │
└─────────────────────────────────────────┘
```

---

## 📋 Componentes Principais

### 🎮 **CONTROLLER**
- **SistemaIotController**: Orquestrador central do sistema
  - Gerencia streams de dados em tempo real
  - Processa lógica de negócio
  - Coordena Services e DAOs
  - Implementa preferências de grupos

### 👁️ **VIEW**
- **MenuInterfaceSimple**: Interface de usuário
  - Dashboard em tempo real
  - Controles de climatização e iluminação
  - Visualização de histórico e logs
  - Menu de gerenciamento

### 📦 **MODEL**
- **DadosSensores**: Dados dos sensores IoT
- **EstadoClimatizador**: Estado do sistema HVAC
- **Funcionario**: Cadastro de funcionários
- **LogEntry**: Registros do sistema
- **PreferenciasGrupo**: Preferências por grupo

### 🔧 **SERVICES**
- **FirebaseService**: Comunicação Firebase em tempo real
- **FuncionarioService**: Lógica de funcionários e preferências
- **LogService**: Sistema de logging centralizado
- **SaidaService**: Buffer de saída formatada

### 💾 **DAOs**
- **FuncionarioDao**: CRUD de funcionários
- **HistoricoDao**: CRUD de dados históricos
- **LogDao**: CRUD de logs
- **PreferenciaTagDao**: CRUD de preferências

---

## 🔄 Fluxos Principais

### 1️⃣ Monitoramento em Tempo Real
```
ESP32 → Firebase → FirebaseService (Stream) → Controller →
→ Processar → Salvar MySQL → Atualizar View
```

### 2️⃣ Aplicação de Preferências
```
RFID Tags → Controller → FuncionarioService → 
→ Buscar Preferências → Calcular Config Ótima →
→ Enviar Comando → Firebase → ESP32
```

### 3️⃣ Comandos Manuais
```
View → Controller → FirebaseService → Firebase → 
→ ESP32 + Log no MySQL
```

---

## 📊 Estrutura de Dados

### Banco de Dados MySQL

#### Tabela: funcionarios
```sql
- id (PK, AUTO_INCREMENT)
- nome (VARCHAR)
- tag_rfid (VARCHAR, UNIQUE)
- grupo (VARCHAR)
- ativo (BOOLEAN)
- created_at (TIMESTAMP)
```

#### Tabela: dados_historicos
```sql
- id (PK, AUTO_INCREMENT)
- temperatura (DOUBLE)
- humidade (DOUBLE)
- luminosidade (INT)
- ldr (INT)
- pessoas (INT)
- tags (JSON)
- timestamp (TIMESTAMP)
- iluminacao_artificial (INT)
```

#### Tabela: logs
```sql
- id (PK, AUTO_INCREMENT)
- tipo (VARCHAR)
- mensagem (TEXT)
- timestamp (TIMESTAMP)
- contexto (JSON)
```

#### Tabela: preferencias_tags
```sql
- tag_rfid (PK, FK)
- temperatura_ideal (DOUBLE)
- temperatura_min (DOUBLE)
- temperatura_max (DOUBLE)
- iluminacao_minima (INT)
- prioridade (INT)
```

### Firebase Realtime Database

```
/sensores
  /dados
    - temperatura
    - humidade
    - luminosidade
    - ldr
    - pessoas
    - tags
    - timestamp
    - iluminacao_artificial

/climatizador
  /estado
    - temperatura
    - temperatura_configuracao
    - modo
    - velocidade
    - status
    - timestamp

/comandos
  /iluminacao
    - comando
    - timestamp
  
  /climatizador
    - temperatura
    - modo
    - velocidade
    - timestamp

/preferencias
  /request
    - tag_rfid
    - timestamp
```

---

## 🎨 Padrões de Projeto Utilizados

### 1. **MVC (Model-View-Controller)**
- Separação clara entre apresentação, lógica e dados
- Facilita manutenção e testes
- Permite evolução independente de cada camada

### 2. **DAO (Data Access Object)**
- Abstração de acesso a dados
- Isolamento da lógica SQL
- Facilita mudanças de banco de dados

### 3. **Service Layer**
- Encapsula lógica de negócio
- Reutilização de código
- Abstração de serviços externos

### 4. **Observer (Streams)**
- Comunicação assíncrona
- Desacoplamento de componentes
- Reatividade em tempo real

### 5. **Singleton**
- Conexão única com banco de dados
- Gerenciamento centralizado de recursos

---

## 🚀 Guia de Implementação

### Fase 1: Setup Inicial
1. ✅ Configurar MySQL
2. ✅ Configurar Firebase
3. ✅ Criar estrutura de pastas
4. ✅ Configurar dependências (pubspec.yaml)

### Fase 2: Camada Model
1. ✅ Implementar classes de modelo
2. ✅ Adicionar validações
3. ✅ Implementar serialização JSON

### Fase 3: Camada DAO
1. ✅ Implementar DatabaseConnection
2. ✅ Criar DAOs para cada entidade
3. ✅ Implementar operações CRUD

### Fase 4: Camada Service
1. ✅ Implementar FirebaseService
2. ✅ Implementar FuncionarioService
3. ✅ Implementar LogService
4. ✅ Configurar streams

### Fase 5: Camada Controller
1. ✅ Implementar SistemaIotController
2. ✅ Integrar services e DAOs
3. ✅ Implementar lógica de negócio
4. ✅ Configurar processamento em background

### Fase 6: Camada View
1. ✅ Implementar MenuInterfaceSimple
2. ✅ Criar dashboard
3. ✅ Implementar controles
4. ✅ Adicionar visualizações

### Fase 7: Hardware
1. ✅ Programar ESP32
2. ✅ Integrar sensores
3. ✅ Configurar atuadores
4. ✅ Testar comunicação Firebase

### Fase 8: Testes e Deploy
1. ⏳ Testes unitários
2. ⏳ Testes de integração
3. ⏳ Testes de sistema
4. ⏳ Deploy e monitoramento

---

## 📈 Métricas de Qualidade

### Cobertura de Código
- Meta: > 80% de cobertura
- Focar em: Controllers, Services, DAOs

### Performance
- Tempo de resposta < 200ms
- Polling interval: 5 segundos
- Buffer de saída: 500 linhas

### Disponibilidade
- Reconexão automática
- Tratamento de erros robusto
- Logging completo

---

## 🔧 Ferramentas de Desenvolvimento

### Essenciais
- **Dart SDK**: ≥ 3.0.0
- **MySQL**: ≥ 8.0
- **Firebase**: Realtime Database
- **VS Code**: Editor recomendado

### Extensões Recomendadas
- Dart
- Flutter
- MySQL
- PlantUML
- Mermaid Preview

### Bibliotecas Principais
```yaml
mysql1: ^0.20.0
http: ^1.1.0
intl: ^0.18.0
```

---

## 📊 Visualização de Diagramas

### Mermaid (GitHub/GitLab)
Os diagramas em `DIAGRAMAS_MERMAID.md` são renderizados automaticamente no GitHub e GitLab.

### PlantUML (Ferramentas Externas)
Os arquivos `.puml` podem ser visualizados com:
- **VS Code**: Extensão PlantUML
- **IntelliJ IDEA**: Plugin PlantUML
- **Online**: [PlantUML Online Server](http://www.plantuml.com/plantuml/)

### Gerando Imagens
```bash
# Usando PlantUML CLI
plantuml docs/arquitetura_sistema.puml
plantuml docs/diagrama_classes.puml
plantuml docs/fluxo_dados_sensores.puml
```

---

## 🎓 Princípios de Design

### SOLID
- ✅ **Single Responsibility**: Uma classe, uma responsabilidade
- ✅ **Open/Closed**: Aberto para extensão, fechado para modificação
- ✅ **Liskov Substitution**: Substituibilidade de tipos
- ✅ **Interface Segregation**: Interfaces específicas
- ✅ **Dependency Inversion**: Depender de abstrações

### Clean Code
- Nomes descritivos
- Funções pequenas e focadas
- Comentários apenas quando necessário
- Formatação consistente
- Tratamento de erros adequado

### DRY (Don't Repeat Yourself)
- Reutilização de código
- Abstração de lógica comum
- Centralização de configurações

---

## 🔐 Segurança

### Dados Sensíveis
- Credenciais em arquivos de configuração
- Nunca commitar senhas no Git
- Usar variáveis de ambiente quando possível

### Validação
- Validar todos os inputs do usuário
- Sanitizar dados antes de inserir no BD
- Verificar tipos de dados

### Logging
- Não logar informações sensíveis
- Registrar todas as operações críticas
- Manter logs por período definido

---

## 📞 Manutenção e Suporte

### Documentação
- ✅ Arquitetura detalhada
- ✅ Diagramas atualizados
- ✅ Comentários no código
- ⏳ Manual do usuário

### Versionamento
- Git para controle de versão
- Branches: main, develop, feature/*
- Commits semânticos

### Troubleshooting
- Verificar logs do sistema
- Validar conexões (MySQL, Firebase)
- Monitorar uso de memória
- Verificar status dos sensores

---

## 🎯 Próximos Passos

### Curto Prazo
1. Implementar testes unitários
2. Adicionar validações adicionais
3. Melhorar tratamento de erros
4. Documentar APIs

### Médio Prazo
1. Interface gráfica web/mobile
2. Sistema de notificações
3. Relatórios automáticos
4. Dashboard analítico

### Longo Prazo
1. Machine Learning para predições
2. Múltiplos ambientes
3. Integração com outros sistemas
4. API REST pública

---

## 📚 Referências

### Documentação Oficial
- [Dart Language Tour](https://dart.dev/guides/language/language-tour)
- [MySQL Documentation](https://dev.mysql.com/doc/)
- [Firebase Documentation](https://firebase.google.com/docs)

### Padrões de Projeto
- Gang of Four - Design Patterns
- Martin Fowler - Patterns of Enterprise Application Architecture
- Clean Architecture - Robert C. Martin

### Boas Práticas
- [Effective Dart](https://dart.dev/guides/language/effective-dart)
- [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style)

---

## ✅ Checklist de Qualidade

### Código
- [ ] Segue convenções de nomenclatura
- [ ] Possui comentários adequados
- [ ] Sem código duplicado
- [ ] Tratamento de erros implementado
- [ ] Validações de entrada

### Arquitetura
- [ ] Separação clara de responsabilidades
- [ ] Baixo acoplamento
- [ ] Alta coesão
- [ ] Facilmente testável
- [ ] Extensível

### Documentação
- [ ] README atualizado
- [ ] Diagramas sincronizados com código
- [ ] Comentários de código
- [ ] Exemplos de uso
- [ ] Guia de troubleshooting

### Testes
- [ ] Testes unitários
- [ ] Testes de integração
- [ ] Cobertura > 80%
- [ ] Testes passando
- [ ] CI/CD configurado

---

## 📝 Conclusão

Este planejamento arquitetural fornece uma base sólida para o desenvolvimento e manutenção do Sistema IoT Dashboard. A arquitetura MVC escolhida oferece:

- ✅ **Organização**: Código estruturado e fácil de navegar
- ✅ **Manutenibilidade**: Mudanças localizadas e impacto reduzido
- ✅ **Escalabilidade**: Fácil adicionar novos recursos
- ✅ **Testabilidade**: Componentes isolados e testáveis
- ✅ **Documentação**: Completa e atualizada

O sistema está preparado para evoluir e crescer mantendo a qualidade e a organização do código.

---

**Versão do Documento**: 1.0  
**Data**: Novembro 2025  
**Status**: ✅ Completo

---

## 📎 Anexos

### Arquivos de Documentação
1. `ARQUITETURA_MVC.md` - Documentação completa da arquitetura
2. `DIAGRAMAS_MERMAID.md` - Diagramas em formato Mermaid
3. `arquitetura_sistema.puml` - Diagrama PlantUML de componentes
4. `diagrama_classes.puml` - Diagrama PlantUML de classes
5. `fluxo_dados_sensores.puml` - Diagrama PlantUML de sequência
6. `PLANEJAMENTO_RESUMO.md` - Este documento

### Comandos Úteis

```bash
# Executar aplicação
dart run bin/main.dart

# Executar testes
dart test

# Análise de código
dart analyze

# Formatar código
dart format .

# Gerar documentação
dart doc

# Visualizar diagramas PlantUML
plantuml -tpng docs/*.puml
```

---

**Desenvolvido com ❤️ para Sistema IoT Dashboard**
