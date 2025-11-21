# 📚 Documentação do Sistema IoT Dashboard

Bem-vindo à documentação completa do Sistema IoT Dashboard com arquitetura MVC.

---

## 📑 Índice de Documentos

### 🎯 Documentação Principal

#### 1. [**GUIA_RAPIDO.md**](GUIA_RAPIDO.md) ⚡ **REFERÊNCIA RÁPIDA**
   - Visão geral em 1 página
   - Guia visual simplificado
   - Comandos úteis
   - Troubleshooting rápido
   - Perfeito para consulta rápida

#### 2. [**PLANEJAMENTO_RESUMO.md**](PLANEJAMENTO_RESUMO.md) ⭐ **COMECE AQUI**
   - Resumo executivo do projeto
   - Visão geral da arquitetura
   - Guia de implementação
   - Checklist de qualidade
   - Próximos passos

#### 3. [**ARQUITETURA_MVC.md**](ARQUITETURA_MVC.md)
   - Arquitetura detalhada do sistema
   - Descrição de todas as camadas (Model, View, Controller)
   - Responsabilidades de cada componente
   - Fluxos de execução
   - Padrões de projeto utilizados
   - Boas práticas e convenções

#### 4. [**DIAGRAMAS_MERMAID.md**](DIAGRAMAS_MERMAID.md)
   - Diagramas interativos em formato Mermaid
   - Visualização automática no GitHub/GitLab
   - Inclui:
     - Diagrama de Componentes
     - Diagrama de Fluxo de Dados
     - Diagrama de Classes
     - Diagramas de Sequência
     - Diagrama de Estados
     - Diagrama ER
     - Diagrama de Deployment

---

#### 5. [**DIAGRAMAS_ASCII.md**](DIAGRAMAS_ASCII.md)
   - Diagramas em formato texto
   - Visualização em qualquer editor
   - Referência rápida offline
   - Ideal para impressão

---

### 📊 Diagramas PlantUML

#### 6. [**arquitetura_sistema.puml**](arquitetura_sistema.puml)
   - Arquitetura geral do sistema
   - Visão de componentes
   - Relacionamentos entre camadas

#### 7. [**diagrama_classes.puml**](diagrama_classes.puml)
   - Diagrama de classes detalhado
   - Todos os métodos e atributos
   - Relacionamentos entre classes

#### 8. [**fluxo_dados_sensores.puml**](fluxo_dados_sensores.puml)
   - Diagrama de sequência
   - Fluxo completo de dados
   - Processamento de preferências

---

### 📄 Documentação Técnica Adicional

#### 9. [**FIREBASE_STREAMING.md**](../FIREBASE_STREAMING.md)
   - Implementação de streaming Firebase
   - Configuração de polling
   - Gerenciamento de streams

#### 10. [**MYSQL_DOCUMENTATION.md**](../MYSQL_DOCUMENTATION.md)
   - Estrutura do banco de dados
   - Schemas e relacionamentos
   - Operações CRUD

#### 11. [**CHANGELOG_STREAMING.md**](../CHANGELOG_STREAMING.md)
   - Histórico de mudanças
   - Versões e atualizações

---

## 🎯 Como Usar Esta Documentação

### Para Iniciantes
1. Veja **GUIA_RAPIDO.md** para visão geral em 1 página
2. Leia **PLANEJAMENTO_RESUMO.md** para entender o projeto
3. Estude **ARQUITETURA_MVC.md** para compreender a estrutura
4. Visualize os diagramas em **DIAGRAMAS_MERMAID.md**

### Para Desenvolvedores
1. Consulte **ARQUITETURA_MVC.md** para entender responsabilidades
2. Use **diagrama_classes.puml** como referência de implementação
3. Veja **fluxo_dados_sensores.puml** para entender fluxos

### Para Arquitetos
1. Analise **arquitetura_sistema.puml** para visão geral
2. Revise todos os diagramas de **DIAGRAMAS_MERMAID.md**
3. Consulte **ARQUITETURA_MVC.md** para decisões arquiteturais

---

## 🏗️ Estrutura Arquitetural

```
Sistema IoT Dashboard (MVC)
│
├── VIEW (Interface)
│   └── MenuInterfaceSimple
│
├── CONTROLLER (Orquestração)
│   └── SistemaIotController
│
├── SERVICES (Lógica de Negócio)
│   ├── FirebaseService
│   ├── FuncionarioService
│   ├── LogService
│   └── SaidaService
│
├── DAOs (Acesso a Dados)
│   ├── FuncionarioDao
│   ├── HistoricoDao
│   ├── LogDao
│   └── PreferenciaTagDao
│
└── MODELS (Entidades)
    ├── DadosSensores
    ├── EstadoClimatizador
    ├── Funcionario
    ├── LogEntry
    └── PreferenciasGrupo
```

---

## 📊 Visualizando os Diagramas

### Mermaid (GitHub/GitLab)
Os diagramas em `DIAGRAMAS_MERMAID.md` são renderizados automaticamente:
- ✅ GitHub
- ✅ GitLab
- ✅ VS Code (com extensão Mermaid Preview)

### PlantUML
Os arquivos `.puml` podem ser visualizados com:

#### VS Code
```bash
# Instalar extensão
code --install-extension jebbs.plantuml
```

#### Linha de Comando
```bash
# Gerar imagens PNG
plantuml -tpng docs/*.puml

# Gerar imagens SVG
plantuml -tsvg docs/*.puml
```

#### Online
- [PlantUML Web Server](http://www.plantuml.com/plantuml/)
- [PlantText](https://www.planttext.com/)

---

## 🔍 Visão Rápida do Sistema

### Fluxo de Dados Principal

```
ESP32 → Firebase → FirebaseService → Controller → 
→ Processar → MySQL + Atualizar UI
```

### Tecnologias Utilizadas

- **Linguagem**: Dart ≥ 3.0.0
- **Banco de Dados**: MySQL 8.0
- **Cloud**: Firebase Realtime Database
- **Hardware**: ESP32 com sensores IoT
- **Padrão**: MVC + Service Layer + DAO

---

## 📋 Documentos por Categoria

### 📐 Arquitetura
- ARQUITETURA_MVC.md
- arquitetura_sistema.puml
- diagrama_classes.puml

### 📊 Diagramas
- DIAGRAMAS_MERMAID.md
- fluxo_dados_sensores.puml

### 🚀 Implementação
- PLANEJAMENTO_RESUMO.md
- FIREBASE_STREAMING.md
- MYSQL_DOCUMENTATION.md

### 📝 Histórico
- CHANGELOG_STREAMING.md

---

## ✨ Recursos Principais

### ✅ Completo
- Arquitetura MVC bem definida
- Documentação detalhada
- Múltiplos formatos de diagramas
- Exemplos de código
- Boas práticas documentadas

### ✅ Visual
- 15+ diagramas profissionais
- Diagramas interativos (Mermaid)
- Diagramas para impressão (PlantUML)
- Esquemas coloridos e organizados

### ✅ Prático
- Guias de implementação
- Checklists de qualidade
- Comandos úteis
- Troubleshooting

---

## 🎓 Recursos de Aprendizado

### Para Estudantes
1. **Conceitos de MVC**: Veja ARQUITETURA_MVC.md
2. **Padrões de Projeto**: Services, DAOs, Observer
3. **Boas Práticas**: SOLID, Clean Code, DRY

### Para Desenvolvedores
1. **Implementação Real**: Código-fonte em `lib/`
2. **Exemplos**: `example/stream_examples.dart`
3. **Testes**: `test/` (em desenvolvimento)

---

## 📞 Suporte

### Documentação
- Todos os documentos estão na pasta `docs/`
- README.md na raiz do projeto
- Comentários inline no código

### Troubleshooting
Consulte seção "Manutenção e Suporte" em:
- PLANEJAMENTO_RESUMO.md

---

## 🔄 Atualizações

### Última Atualização
- **Data**: Novembro 2025
- **Versão**: 1.0
- **Status**: ✅ Documentação Completa

### Próximas Atualizações
- Diagramas de testes
- Guia de deployment
- API REST documentation
- Manual do usuário final

---

## 📈 Estatísticas da Documentação

| Item | Quantidade |
|------|-----------|
| Documentos Markdown | 8 |
| Diagramas PlantUML | 3 |
| Diagramas Mermaid | 10+ |
| Páginas Total | ~120+ |
| Diagramas Visuais | 20+ |

---

## 🎯 Mapa de Navegação Rápida

```
Consulta rápida (1 página)?
→ GUIA_RAPIDO.md

Precisa entender o projeto?
→ PLANEJAMENTO_RESUMO.md

Quer ver a arquitetura?
→ ARQUITETURA_MVC.md

Prefere diagramas visuais?
→ DIAGRAMAS_MERMAID.md

Diagramas em texto simples?
→ DIAGRAMAS_ASCII.md

Vai implementar código?
→ diagrama_classes.puml + ARQUITETURA_MVC.md

Quer entender os fluxos?
→ fluxo_dados_sensores.puml + DIAGRAMAS_MERMAID.md

Precisa de referência técnica?
→ FIREBASE_STREAMING.md + MYSQL_DOCUMENTATION.md
```

---

## 📦 Estrutura de Arquivos

```
docs/
├── README.md                      ← Você está aqui
├── GUIA_RAPIDO.md                 ← Referência rápida!
├── PLANEJAMENTO_RESUMO.md         ← Comece aqui!
├── ARQUITETURA_MVC.md             ← Arquitetura completa
├── DIAGRAMAS_MERMAID.md           ← Diagramas interativos
├── DIAGRAMAS_ASCII.md             ← Diagramas texto
├── arquitetura_sistema.puml       ← Diagrama de componentes
├── diagrama_classes.puml          ← Diagrama de classes
└── fluxo_dados_sensores.puml      ← Diagrama de sequência
```

---

## 🌟 Destaques

### 💎 Qualidade
- Documentação profissional
- Diagramas padronizados
- Organização clara
- Fácil navegação

### 🎨 Visual
- Cores consistentes
- Layouts organizados
- Múltiplos formatos
- Renderização automática

### 📚 Completo
- Todos os aspectos cobertos
- Exemplos práticos
- Referências externas
- Guias passo a passo

---

## 🚀 Início Rápido

```bash
# 1. Clone o repositório
git clone [repository-url]

# 2. Navegue até a documentação
cd pi-mds/docs

# 3. Abra o resumo executivo
# Recomendado: Abrir no VS Code ou GitHub para renderização
code PLANEJAMENTO_RESUMO.md

# 4. Visualize os diagramas Mermaid
# Abra DIAGRAMAS_MERMAID.md no GitHub ou VS Code

# 5. Gere imagens dos diagramas PlantUML (opcional)
plantuml -tpng *.puml
```

---

## 📖 Leitura Recomendada

### Sequência Sugerida
1. ⚡ GUIA_RAPIDO.md (5 min) - **Visão geral rápida**
2. 📄 PLANEJAMENTO_RESUMO.md (15 min)
3. 📐 ARQUITETURA_MVC.md (30 min)
4. 📊 DIAGRAMAS_MERMAID.md (20 min)
5. 🔠 DIAGRAMAS_ASCII.md (10 min)
6. 🔍 Diagramas PlantUML (10 min)
7. 💻 Código-fonte em `lib/` (variável)

**Tempo total estimado**: ~1h35min para compreensão completa

---

## ✅ Verificação de Compreensão

Após ler a documentação, você deve ser capaz de:

- [ ] Explicar a arquitetura MVC do sistema
- [ ] Identificar responsabilidades de cada camada
- [ ] Entender o fluxo de dados do ESP32 até a UI
- [ ] Localizar onde implementar novas features
- [ ] Compreender como as preferências são aplicadas
- [ ] Explicar a comunicação Firebase ↔ Sistema ↔ MySQL

---

**Desenvolvido com ❤️ para o Sistema IoT Dashboard**

---

## 📬 Contribuindo

Para melhorias na documentação:
1. Leia a documentação existente
2. Identifique gaps ou melhorias
3. Mantenha o padrão de formatação
4. Atualize o índice se necessário
5. Sincronize diagramas com código

---

**Última atualização**: Novembro 2025  
**Versão da Documentação**: 1.0  
**Status**: ✅ Completo e Revisado
