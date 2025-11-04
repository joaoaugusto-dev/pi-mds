# Firebase Streaming - Documentação

## Visão Geral

Este projeto foi atualizado para usar **Streams** para comunicação em tempo real com o Firebase Realtime Database, tanto no código Dart quanto no ESP32.

## Mudanças Implementadas

### 1. Dart - FirebaseService

#### Novos Recursos

- **Streams Broadcast**: Múltiplos listeners podem se inscrever nos mesmos dados
- **Monitoramento em Tempo Real**: Atualizações automáticas sem polling manual
- **Gerenciamento de Recursos**: Métodos para iniciar/parar streams e liberar recursos

#### Streams Disponíveis

```dart
// Dados dos sensores
Stream<DadosSensores?> get streamSensores

// Estado do climatizador
Stream<EstadoClimatizador?> get streamClimatizador

// Comandos de iluminação
Stream<Map<String, dynamic>?> get streamComandosIluminacao

// Comandos do climatizador
Stream<Map<String, dynamic>?> get streamComandosClimatizador

// Última tag RFID lida
Stream<String?> get streamUltimaTag

// Solicitações de preferências
Stream<String?> get streamPreferenciasRequest
```

#### Como Usar

```dart
// Iniciar monitoramento
firebaseService.streamSensores.listen((dados) {
  if (dados != null) {
    print('Temperatura: ${dados.temperatura}°C');
  }
});

// Parar todos os streams
firebaseService.stopAllStreams();

// Liberar recursos quando não for mais necessário
firebaseService.dispose();
```

### 2. Dart - SistemaIotController

#### Método `startBackgroundSync()`

Agora usa Streams internamente ao invés de polling:

```dart
controller.startBackgroundSync(); // Inicia streams automáticos
// ... trabalhar com o sistema ...
controller.stopBackgroundSync(); // Para streams e libera recursos
controller.dispose(); // Limpeza final
```

#### Stream de Dados Completos

```dart
controller.streamDadosTempoReal().listen((resumo) {
  print('Sistema: ${resumo}');
});
```

### 3. ESP32 - Suporte a Server-Sent Events (SSE)

#### Novos Recursos

- **Streaming Firebase**: Conexão persistente com Firebase usando SSE
- **Fallback Inteligente**: Volta para polling se o stream falhar
- **Reconexão Automática**: Gerenciamento automático de desconexões
- **Keep-Alive**: Detecção de timeout e reconexão

#### Funções Adicionadas

```cpp
// Iniciar stream de um caminho
bool iniciarStreamFirebase(const String& path);

// Processar eventos recebidos
String processarStreamFirebase();

// Fechar stream
void fecharStreamFirebase();

// Processar comandos via stream
void processarComandoIluminacao(JsonObject cmd);
void processarComandoClimatizador(JsonObject cmd);
```

#### Como Funciona

1. **Inicialização**: Na função `verificarComandos()`, o ESP32 tenta iniciar um stream do caminho `/comandos`
2. **Processamento**: A cada loop, `processarStreamFirebase()` lê eventos do stream
3. **Fallback**: Se o stream falhar, o código volta para polling HTTP normal
4. **Reconexão**: A cada 30 segundos, tenta reconectar o stream se estiver inativo

## Benefícios

### Performance

- ✅ **Redução de Latência**: Atualizações instantâneas vs polling de 2-3 segundos
- ✅ **Menos Requisições HTTP**: Stream mantém uma conexão ao invés de múltiplas requisições
- ✅ **Economia de Banda**: Apenas dados alterados são transmitidos
- ✅ **Menos Carga no Firebase**: Redução significativa de leituras no banco

### Confiabilidade

- ✅ **Reconexão Automática**: Recuperação transparente de falhas de rede
- ✅ **Fallback Robusto**: Funciona mesmo sem suporte a streaming
- ✅ **Keep-Alive**: Detecção e correção de conexões inativas

### Escalabilidade

- ✅ **Múltiplos Listeners**: Vários componentes podem ouvir o mesmo stream
- ✅ **Gerenciamento de Recursos**: Controle fino sobre quando iniciar/parar streams
- ✅ **Eficiência Energética**: Menos processamento = menos consumo (importante para ESP32)

## Comparação: Antes vs Depois

### Antes (Polling)

```dart
// Polling manual a cada X segundos
while (true) {
  dados = await firebase.lerSensores();
  await Future.delayed(Duration(seconds: 2));
}
```

**Problemas:**
- Atraso fixo de 2 segundos
- Requisições mesmo sem mudanças
- Código mais complexo para gerenciar loops

### Depois (Streams)

```dart
// Stream automático
firebase.streamSensores.listen((dados) {
  // Processa imediatamente quando há mudança
});
```

**Vantagens:**
- Atualizações instantâneas
- Apenas quando há mudanças
- Código mais limpo e reativo

## Configuração

### Dart (pubspec.yaml)

Certifique-se de ter o pacote `http`:

```yaml
dependencies:
  http: ^1.1.0
```

### ESP32 (Arduino IDE)

Bibliotecas necessárias:
- WiFi (built-in)
- HTTPClient (built-in)
- ArduinoJson (^6.21.0)

## Testes

### Testar Streams no Dart

```dart
void main() async {
  final service = FirebaseService();
  
  // Testar stream de sensores
  service.streamSensores.listen(
    (dados) => print('✓ Sensores: $dados'),
    onError: (e) => print('✗ Erro: $e'),
  );
  
  await Future.delayed(Duration(minutes: 1));
  service.dispose();
}
```

### Testar Streaming no ESP32

1. Ativar debug: `#define DEBUG_SERIAL 1`
2. Monitorar Serial: 115200 baud
3. Procurar logs:
   - "✓ Stream Firebase iniciado com sucesso"
   - "📨 Evento recebido via stream..."

## Troubleshooting

### Stream não conecta (ESP32)

1. Verificar WiFi: `flags.wifiOk` deve ser `true`
2. Verificar URL Firebase: `FIREBASE_HOST`
3. Verificar firewall/proxy
4. Aumentar timeout: `streamHttpCliente->setTimeout(90000)`

### Alto uso de memória (ESP32)

- Reduzir buffer do ArduinoJson
- Aumentar intervalo de fallback polling
- Desabilitar debug verbose

### Dart Stream não recebe dados

1. Verificar se `startBackgroundSync()` foi chamado
2. Verificar conexão de rede
3. Verificar se Firebase está retornando dados
4. Adicionar listener de erros: `onError: (e) => print(e)`

## Migração de Código Antigo

### Se você tinha:

```dart
// Código antigo
await controller.processarDadosSensores();
await controller.processarEstadoClimatizador();
```

### Mude para:

```dart
// Código novo
controller.startBackgroundSync(); // Uma vez na inicialização
// Os streams processam automaticamente
```

## Observações Importantes

1. **Sempre chamar `dispose()`**: Libera recursos e fecha streams
2. **Stream é broadcast**: Múltiplos listeners são permitidos
3. **Fallback é automático**: Não precisa de código especial
4. **ESP32 tenta stream primeiro**: Mas funciona sem ele

## Suporte

Para problemas ou dúvidas:
- Verificar logs de debug
- Revisar esta documentação
- Checar configuração do Firebase

## Changelog

### v2.1 (Atual)
- ✅ Implementação de Streams no Dart
- ✅ Suporte a SSE no ESP32
- ✅ Fallback automático para polling
- ✅ Documentação completa

### v2.0 (Anterior)
- Integração básica com Firebase
- Polling manual
- Sem suporte a tempo real
