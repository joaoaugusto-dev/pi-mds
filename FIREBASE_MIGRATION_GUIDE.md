# 🚀 Sistema IoT ESP32 + Firebase - Versão 2.0

## 📋 RESUMO DA MIGRAÇÃO

O sistema foi **completamente migrado** de HTTP local para **Firebase Realtime Database**, mantendo todas as funcionalidades originais do ESP32 e melhorando a integração com o sistema Dart.

## ⚡ PRINCIPAIS MUDANÇAS

### **ESP32 (hardware/esp32_main.ino)**
- ✅ **Firebase REST API** ao invés de HTTP local
- ✅ **Mesma funcionalidade completa** do código original
- ✅ **Estruturas de dados otimizadas** mantidas
- ✅ **Controle IR, sensores, relés, LCD** inalterados
- ✅ **Sistema de preferências** integrado ao Firebase
- ✅ **Automação inteligente** baseada em preferências

### **Sistema Dart**
- ✅ **Firebase Service** aprimorado
- ✅ **Novo DAO** para preferências por tag
- ✅ **Processamento automático** de preferências
- ✅ **Tabela MySQL** para cache local
- ✅ **Sincronização Firebase ↔ MySQL**

## 🔧 CONFIGURAÇÃO FIREBASE

### **Estrutura no Firebase Realtime Database:**
```json
{
  "sensores": {
    "temperatura": 25.5,
    "humidade": 60,
    "luminosidade": 75,
    "pessoas": 2,
    "tags": ["ABC123", "DEF456"],
    "timestamp": 1634567890,
    "climatizador": {
      "ligado": true,
      "velocidade": 2,
      "umidificando": false,
      "aleta_vertical": true,
      "aleta_horizontal": false
    }
  },
  "comandos": {
    "iluminacao": {
      "comando": "75",
      "timestamp": 1634567890
    },
    "climatizador": {
      "comando": "power_on",
      "timestamp": 1634567890
    }
  },
  "climatizador": {
    "ligado": true,
    "velocidade": 2,
    "origem": "ir"
  },
  "preferencias_por_tag": {
    "ABC123": {
      "tag": "ABC123",
      "nome_completo": "João Silva",
      "temperatura_preferida": 24.0,
      "luminosidade_preferida": 80
    }
  },
  "preferencias_grupo": {
    "temperatura_preferida": 24.5,
    "luminosidade_preferida": 75,
    "tags_encontradas": 2,
    "timestamp": 1634567890
  },
  "ultima_tag": "ABC123"
}
```

## 📊 FLUXO DE FUNCIONAMENTO

### **1. ESP32 → Firebase**
```
ESP32 lê tag NFC → Consulta preferências → Firebase processa → 
ESP32 recebe preferências → Aplica automação → Envia dados atualizados
```

### **2. Sistema Dart ↔ Firebase**
```
Dart monitora Firebase → Processa dados → Atualiza MySQL → 
Calcula preferências → Salva no Firebase → ESP32 consome
```

### **3. Comandos Manuais**
```
App/Dashboard → Firebase (/comandos) → ESP32 lê → Executa → 
Atualiza estado → Firebase (/climatizador) → Dashboard atualiza
```

## 🔌 CONFIGURAÇÃO DO ESP32

### **Parâmetros no código:**
```cpp
// WiFi
const char* ssid = "esp32";
const char* password = "123654123";

// Firebase
const char* FIREBASE_HOST = "projeto-pi-mds-default-rtdb.firebaseio.com";
const char* FIREBASE_AUTH = ""; // Deixar vazio ou adicionar token
```

### **Bibliotecas necessárias (Arduino IDE):**
- WiFi (ESP32)
- HTTPClient
- ArduinoJson
- MFRC522
- DHT sensor library
- LiquidCrystal I2C
- IRremote

## 🎮 COMANDOS DISPONÍVEIS

### **Iluminação** (Firebase: `/comandos/iluminacao`)
```json
{"comando": "0"}     // Desligar
{"comando": "25"}    // 25%
{"comando": "50"}    // 50%
{"comando": "75"}    // 75%
{"comando": "100"}   // 100%
{"comando": "auto"}  // Modo automático
```

### **Climatizador** (Firebase: `/comandos/climatizador`)
```json
{"comando": "power_on"}   // Ligar
{"comando": "power_off"}  // Desligar
{"comando": "velocidade"} // Alterar velocidade
{"comando": "umidificar"} // Toggle umidificador
{"comando": "timer"}      // Configurar timer
{"comando": "aleta_v"}    // Aleta vertical
{"comando": "aleta_h"}    // Aleta horizontal
{"comando": "auto"}       // Modo automático
```

## 🔄 COMO USAR

### **1. Compilar e Executar Sistema Dart:**
```bash
cd pi-mds
dart pub get
dart run bin/main.dart
```

### **2. Carregar código no ESP32:**
- Abrir `hardware/esp32_main.ino` no Arduino IDE
- Instalar bibliotecas necessárias
- Configurar WiFi (ssid/password)
- Verificar URL do Firebase
- Compilar e carregar no ESP32

### **3. Monitorar Sistema:**
- Sistema Dart mostra logs em tempo real
- ESP32 mostra debug no Serial Monitor
- Firebase Console para ver dados em tempo real

## 📈 CARACTERÍSTICAS TÉCNICAS

### **Intervalos Otimizados:**
- Sensores DHT: 5 segundos
- Envio dados: 5 segundos  
- Comandos Firebase: 3 segundos
- Controle climático: 5 segundos
- Verificação WiFi: 10 segundos

### **Automação Inteligente:**
- **Iluminação:** Baseada em LDR + preferências do grupo
- **Climatização:** Histerese inteligente (±2°C)
- **Preferências:** Média das preferências dos presentes
- **Persistência:** MySQL para histórico + Firebase para tempo real

### **Recursos de Segurança:**
- Debounce para comandos IR
- Timeout para requisições HTTP
- Reconexão automática WiFi
- Validação de dados sensores
- Estados de erro com feedback

## 🚨 TROUBLESHOOTING

### **ESP32 não conecta WiFi:**
- Verificar SSID e senha
- Conferir sinal WiFi
- Resetar ESP32

### **Firebase não responde:**
- Verificar URL do projeto
- Conferir regras de segurança do Firebase
- Validar conectividade internet

### **Sistema Dart com erro:**
- Verificar conexão MySQL
- Conferir credenciais do banco
- `dart pub get` para dependências

### **Sensores com erro:**
- Verificar fiação DHT22
- Confirmar pinos no código
- Testar sensores individualmente

## 📝 LOGS E MONITORAMENTO

### **ESP32 Serial Monitor:**
```
🚀 ESP32 IoT System v2.0 (Firebase) Iniciando...
✓ WiFi conectado: 192.168.1.100
✓ RFID iniciado
✓ IR iniciado
Tag NFC lida: ABC123
✓ Preferências recebidas: Temp=24.5°C, Lum=75%
✓ Iluminação automática LIGADA: 75%
```

### **Sistema Dart Console:**
```
🚀 Iniciando Sistema IoT Dashboard...
✓ Conexão MySQL estabelecida
📋 Processando preferências para tags: ABC123, DEF456
✓ Preferências do grupo salvas: Temp=24.5°C, Lum=75%
✓ Dados processados: Sensores: 25.1°C, 58.0%, 75lux, 2p
```

## 🎯 PRÓXIMOS PASSOS

1. **Testar sistema completo** ESP32 + Dart + Firebase
2. **Calibrar sensores** e ajustar limiares
3. **Configurar usuários** e suas preferências
4. **Implementar dashboard web** (opcional)
5. **Adicionar notificações** (opcional)

---

✅ **Sistema pronto para uso!** O ESP32 agora comunica completamente via Firebase, mantendo toda a funcionalidade original com melhor integração e escalabilidade.