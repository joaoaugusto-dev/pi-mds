# 🔧 Guia de Compilação ESP32

## 📚 Bibliotecas Necessárias (Arduino IDE)

### **Instalação via Library Manager:**

1. **WiFi** - Já incluída no ESP32 Core
2. **HTTPClient** - Já incluída no ESP32 Core  
3. **SPI** - Já incluída no Arduino Core
4. **ArduinoJson** - Pesquisar "ArduinoJson" por Benoit Blanchon
5. **MFRC522** - Pesquisar "MFRC522" por GithubCommunity
6. **DHT sensor library** - Pesquisar "DHT" por Adafruit
7. **LiquidCrystal I2C** - Pesquisar "LiquidCrystal I2C" por Frank de Brabander
8. **IRremote** - Pesquisar "IRremote" por shirriff

### **Versões Testadas:**
- ArduinoJson: 7.0.4+
- MFRC522: 1.4.10+
- DHT sensor library: 1.4.4+
- LiquidCrystal I2C: 1.1.2+
- IRremote: 4.2.0+

## ⚙️ Configuração Arduino IDE

### **1. Adicionar ESP32:**
- File → Preferences → Additional Board Manager URLs
- Adicionar: `https://dl.espressif.com/dl/package_esp32_index.json`
- Tools → Board → Boards Manager → Pesquisar "ESP32" → Instalar

### **2. Selecionar Placa:**
- Tools → Board → ESP32 Arduino → **ESP32 Dev Module**

### **3. Configurações da Placa:**
```
Board: ESP32 Dev Module
Upload Speed: 921600
CPU Frequency: 240MHz (WiFi/BT)
Flash Frequency: 80MHz
Flash Mode: QIO
Flash Size: 4MB (32Mb)
Partition Scheme: Default 4MB with spiffs
Core Debug Level: None
PSRAM: Disabled
```

## 📡 Configuração de Rede

### **No código `esp32_main.ino`:**
```cpp
// Linha ~11-12
const char* ssid = "SEU_WIFI_AQUI";
const char* password = "SUA_SENHA_AQUI";

// Linha ~15-16
const char* FIREBASE_HOST = "projeto-pi-mds-default-rtdb.firebaseio.com";
const char* FIREBASE_AUTH = ""; // Deixar vazio por enquanto
```

## 🔌 Conexões Físicas

### **Pinos ESP32:**
```
Componente          | Pino ESP32
--------------------|------------
Buzzer              | GPIO 12
Relé 1              | GPIO 14
Relé 2              | GPIO 26
Relé 3              | GPIO 27
Relé 4              | GPIO 25
RFID - SS           | GPIO 5
RFID - RST          | GPIO 15
RFID - SDA          | GPIO 23
RFID - SCK          | GPIO 18
RFID - MOSI         | GPIO 23
RFID - MISO         | GPIO 19
DHT22 - Data        | GPIO 4
LDR                 | GPIO 35 (ADC)
IR Send             | GPIO 33
IR Receive          | GPIO 32
LCD - SDA           | GPIO 21 (I2C)
LCD - SCL           | GPIO 22 (I2C)
```

### **Alimentação:**
- ESP32: 5V/3.3V
- Relés: 5V (usar módulo com optoacopladores)
- DHT22: 3.3V-5V
- LCD: 5V (I2C module)
- RFID: 3.3V

## 🚀 Processo de Compilação

### **1. Preparação:**
```bash
# Baixar código
git clone https://github.com/seu-repo/pi-mds.git
cd pi-mds/hardware/
```

### **2. Arduino IDE:**
- Abrir `esp32_main.ino`
- Verificar todas as bibliotecas instaladas
- Configurar WiFi e Firebase
- Tools → Port → Selecionar porta COM do ESP32

### **3. Compilar:**
- Sketch → Verify/Compile
- Aguardar compilação sem erros

### **4. Upload:**
- Conectar ESP32 via USB
- Pressionar botão BOOT (se necessário)
- Sketch → Upload
- Aguardar upload 100%

## 📺 Monitoramento

### **Serial Monitor:**
- Tools → Serial Monitor
- Baud Rate: **115200**
- Ver logs do sistema em tempo real

### **Exemplo de saída esperada:**
```
🚀 ESP32 IoT System v2.0 (Firebase) Iniciando...
✓ RFID iniciado
✓ IR iniciado
Conectando WiFi...
✓ WiFi conectado: 192.168.1.100
✓ Sistema ESP32 iniciado com sucesso!
✓ Firebase: projeto-pi-mds-default-rtdb.firebaseio.com
✓ WiFi: Conectado
===========================================

--- STATUS DO SISTEMA ---
Temperatura: 25.1°C
Umidade: 58.0%
Pessoas: 0 (Tags Hist: 0)
WiFi: Conectado
```

## 🐛 Resolução de Problemas

### **Erro de Compilação:**
```
Solução:
1. Verificar todas as bibliotecas instaladas
2. Atualizar ESP32 Core (Tools → Board → Boards Manager)
3. Limpar cache: File → Preferences → Delete cache
4. Reiniciar Arduino IDE
```

### **Erro de Upload:**
```
Solução:
1. Verificar porta COM selecionada
2. Pressionar e segurar botão BOOT durante upload
3. Verificar cabo USB (deve ser cabo de dados)
4. Tentar velocidade menor: 115200
```

### **WiFi não conecta:**
```
Solução:
1. Verificar SSID e senha corretos
2. Testar com hotspot do celular
3. Verificar se rede é 2.4GHz (não 5GHz)
4. Aproximar ESP32 do roteador
```

### **Firebase não responde:**
```
Solução:
1. Verificar URL do Firebase correto
2. Testar conectividade: ping firebase.google.com
3. Verificar regras do Firebase Database
4. Aguardar alguns minutos após primeira execução
```

## ✅ Checklist Final

- [ ] ✅ Arduino IDE configurado com ESP32
- [ ] ✅ Todas as bibliotecas instaladas
- [ ] ✅ Código compilou sem erros
- [ ] ✅ WiFi configurado corretamente
- [ ] ✅ Firebase URL configurado
- [ ] ✅ Hardware conectado conforme pinout
- [ ] ✅ Upload realizado com sucesso
- [ ] ✅ Serial Monitor mostra logs
- [ ] ✅ Sistema Dart rodando em paralelo
- [ ] ✅ Firebase Console mostra dados

## 🎯 Primeiro Teste

### **Após upload bem-sucedido:**
1. **Verificar Serial Monitor** - deve mostrar inicialização
2. **Aproximar tag RFID** - deve detectar e enviar para Firebase
3. **Verificar Firebase Console** - deve aparecer dados em `/sensores`
4. **Sistema Dart** - deve processar e mostrar logs
5. **Testar comando manual** - via Firebase Console ou app

---

🎉 **ESP32 pronto para uso com Firebase!** 

O sistema agora está completamente integrado e pronto para controlar iluminação e climatização de forma inteligente baseada em preferências dos usuários.