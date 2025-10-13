// =====================================================
// ESP32 IoT System with Firebase Integration
// Autor: Sistema PI-MDS
// Versão: 2.0 (Firebase)
// =====================================================

// === BIBLIOTECAS ===
#include <WiFi.h>
#include <HTTPClient.h>
#include <SPI.h>
#include <MFRC522.h>
#include <ArduinoJson.h>
#include <DHT.h>
#include <LiquidCrystal_I2C.h>
#include <IRremote.hpp>

// === CONFIGURAÇÕES DE REDE ===
const char* ssid = "João Augusto";
const char* password = "131103r7";

// === FIREBASE CONFIGURATION ===
const char* FIREBASE_HOST = "projeto-pi-mds-default-rtdb.firebaseio.com";
const char* FIREBASE_AUTH = ""; // Deixar vazio se não usar autenticação

// === PINOS E CONSTANTES ===
#define BUZZER_PIN 12
#define RELE_1 14
#define RELE_2 26
#define RELE_3 27
#define RELE_4 25
#define SS_PIN 5
#define RST_PIN 15
#define DHT_PIN 4
#define DHTTYPE DHT22
#define LDR_PIN 35
#define IR_SEND_PIN 33
#define IR_RECEIVE_PIN 32

// === COMANDOS IR ===
#define IR_PROTOCOLO NEC
#define IR_ENDERECO 0xFC00
#define IR_POWER 0x85
#define IR_UMIDIFICAR 0x87
#define IR_VELOCIDADE 0x84
#define IR_TIMER 0x86
#define IR_ALETA_VERTICAL 0x83
#define IR_ALETA_HORIZONTAL 0x82

// === CONSTANTES DE CONTROLE ===
#define DEBOUNCE_ENVIAR 300
#define DEBOUNCE_RECEBER 500
#define JANELA_ECO 100
#define TIMEOUT_CONFIRMACAO 500
#define DEBUG_SERIAL 1
#define LIMIAR_LDR_ESCURIDAO 400

// === INTERVALOS OTIMIZADOS ===
const unsigned long INTERVALO_DHT = 5000;
const unsigned long INTERVALO_DADOS = 5000;
const unsigned long INTERVALO_LDR = 5000;
const unsigned long INTERVALO_CLIMA_AUTO = 5000;
const unsigned long INTERVALO_COMANDOS = 3000;
const unsigned long MODO_CADASTRO_TIMEOUT = 60000; // 60 segundos
const unsigned long INTERVALO_DEBUG = 5000;
const unsigned long INTERVALO_PREF_CHECK = 30000;

// === OBJETOS GLOBAIS ===
MFRC522 mfrc522(SS_PIN, RST_PIN);
DHT dht(DHT_PIN, DHTTYPE);
LiquidCrystal_I2C lcd(0x27, 16, 2);

// === ESTRUTURAS DE DADOS ===
struct DadosSensores {
  float temperatura = 0;
  float humidade = 0;
  int luminosidade = 0;
  int valorLDR = 0;
  bool dadosValidos = false;
} sensores;

struct {
  bool ligado : 1;
  bool umidificando : 1;
  bool aletaV : 1;
  bool aletaH : 1;
  uint8_t velocidade : 2;
  uint8_t ultimaVel : 2;
  uint8_t timer : 3;
  uint8_t reservado : 5;
  unsigned long ultimaAtualizacao;
} clima;

struct {
  int total = 0;
  String tags[10];
  bool estado[10];
  int count = 0;
  float tempPref = 25.0;
  int lumPref = 50;
  bool prefsAtualizadas = false;
} pessoas;

struct {
  bool modoManualIlum : 1;
  bool modoManualClima : 1;
  bool ilumAtiva : 1;
  bool monitorandoLDR : 1;
  bool irPausa : 1;
  bool comandoIR : 1;
  bool comandoApp : 1;
  bool wifiOk : 1;
  bool erroSensor : 1;
  bool erroConexao : 1;
  bool modoCadastro : 1;
  bool debug : 1;
  bool atualizandoPref : 1;
} flags = { false, false, false, true, false, false, false, false, false, false, false, false, false };

// === MÁQUINA DE ESTADOS IR ===
enum EstadoIR {
  IR_OCIOSO,
  IR_ENVIANDO,
  IR_AGUARDANDO_CONFIRMACAO
};

struct {
  EstadoIR estado = IR_OCIOSO;
  uint8_t comandoPendente = 0;
  unsigned long inicioEnvio = 0;
  bool comandoConfirmado = false;
} controleIR;

// === CONTROLE DE TEMPO ===
unsigned long tempos[8] = { 0 };
unsigned long cadastroInicio = 0;

// === CARACTERES PERSONALIZADOS PARA LCD ===
uint8_t SIMBOLO_PESSOA[8] = { 0x0E, 0x0E, 0x04, 0x1F, 0x04, 0x0A, 0x0A, 0x00 };
uint8_t SIMBOLO_TEMP[8] = { 0x04, 0x0A, 0x0A, 0x0A, 0x0A, 0x11, 0x1F, 0x0E };
uint8_t SIMBOLO_HUM[8] = { 0x04, 0x04, 0x0A, 0x0A, 0x11, 0x11, 0x11, 0x0E };
uint8_t SIMBOLO_LUZ[8] = { 0x00, 0x0A, 0x0A, 0x1F, 0x1F, 0x0E, 0x04, 0x00 };
uint8_t SIMBOLO_WIFI[8] = { 0x00, 0x0F, 0x11, 0x0E, 0x04, 0x00, 0x04, 0x00 };
uint8_t SIMBOLO_AR[8] = { 0x00, 0x0E, 0x15, 0x15, 0x15, 0x0E, 0x00, 0x00 };
uint8_t SIMBOLO_OK[8] = { 0x00, 0x01, 0x02, 0x14, 0x08, 0x04, 0x02, 0x00 };
uint8_t SIMBOLO_ERRO[8] = { 0x00, 0x11, 0x0A, 0x04, 0x04, 0x0A, 0x11, 0x00 };

// === ENUMS PARA SONS ===
enum SomBuzzer : uint8_t {
  SOM_NENHUM = 0,
  SOM_INICIAR,
  SOM_PESSOA_ENTROU,
  SOM_PESSOA_SAIU,
  SOM_COMANDO,
  SOM_ALERTA,
  SOM_ERRO,
  SOM_CONECTADO,
  SOM_DESCONECTADO,
  SOM_OK
};

// === FUNÇÕES FIREBASE ===

String buildFirebaseUrl(const String& path) {
  String url = "https://";
  url += FIREBASE_HOST;
  url += path;
  url += ".json";
  if (strlen(FIREBASE_AUTH) > 0) {
    url += "?auth=";
    url += FIREBASE_AUTH;
  }
  return url;
}

bool enviarDadosFirebase(const String& path, const String& dados, bool isPatch = false) {
  if (!flags.wifiOk) return false;
  
  HTTPClient http;
  String url = buildFirebaseUrl(path);
  http.begin(url);
  http.addHeader("Content-Type", "application/json");
  http.setTimeout(5000);
  
  int httpCode;
  if (isPatch) {
    httpCode = http.PATCH(dados);
  } else {
    httpCode = http.PUT(dados);
  }
  
  bool sucesso = (httpCode == HTTP_CODE_OK);
  
  if (!sucesso) {
    debugPrint("Erro Firebase PUT/PATCH " + path + ": " + String(httpCode));
    flags.erroConexao = true;
  } else {
    flags.erroConexao = false;
  }
  
  http.end();
  return sucesso;
}

String lerDadosFirebase(const String& path) {
  if (!flags.wifiOk) return "";
  
  HTTPClient http;
  String url = buildFirebaseUrl(path);
  http.begin(url);
  http.setTimeout(5000);
  
  int httpCode = http.GET();
  String response = "";
  
  if (httpCode == HTTP_CODE_OK) {
    response = http.getString();
    flags.erroConexao = false;
  } else {
    debugPrint("Erro Firebase GET " + path + ": " + String(httpCode));
    flags.erroConexao = true;
  }
  
  http.end();
  return response;
}

bool deletarDadosFirebase(const String& path) {
  if (!flags.wifiOk) return false;
  
  HTTPClient http;
  String url = buildFirebaseUrl(path);
  http.begin(url);
  http.setTimeout(5000);
  
  int httpCode = http.sendRequest("DELETE");
  bool sucesso = (httpCode == HTTP_CODE_OK);
  
  if (!sucesso) {
    debugPrint("Erro Firebase DELETE " + path + ": " + String(httpCode));
  }
  
  http.end();
  return sucesso;
}

// === FUNÇÕES PARA DEBUG ===
void debugPrint(const String& msg) {
#if DEBUG_SERIAL
  Serial.println(msg);
#endif
}

void mostrarTelaDebug() {
#if DEBUG_SERIAL
  unsigned long agora = millis();
  static unsigned long ultimoDebug = 0;

  if (agora - ultimoDebug < INTERVALO_DEBUG) return;
  ultimoDebug = agora;

  debugPrint("\n--- STATUS DO SISTEMA ---");
  debugPrint("Temperatura: " + String(sensores.temperatura) + "°C");
  debugPrint("Umidade: " + String(sensores.humidade) + "%");
  debugPrint("LDR valor: " + String(sensores.valorLDR));
  debugPrint("Luminosidade: " + String(sensores.luminosidade) + "%");
  debugPrint("Pessoas: " + String(pessoas.total) + " (Tags Hist: " + String(pessoas.count) + ")");
  debugPrint("Temp. Preferida: " + String(pessoas.tempPref) + "°C");
  debugPrint("Lum. Preferida: " + String(pessoas.lumPref) + "%");
  debugPrint("Prefs Atualizadas: " + String(pessoas.prefsAtualizadas ? "SIM" : "NAO"));
  
  if (pessoas.total > 0) {
    debugPrint("Tags ativas:");
    for (int i = 0; i < pessoas.count; i++) {
      if (pessoas.estado[i]) {
        debugPrint("  - " + pessoas.tags[i]);
      }
    }
  }

  debugPrint("\n--- FLAGS ---");
  debugPrint("modoManualIlum: " + String(flags.modoManualIlum ? "SIM" : "NAO"));
  debugPrint("modoManualClima: " + String(flags.modoManualClima ? "SIM" : "NAO"));
  debugPrint("ilumAtiva: " + String(flags.ilumAtiva ? "SIM" : "NAO"));
  debugPrint("monitorandoLDR: " + String(flags.monitorandoLDR ? "SIM" : "NAO"));
  debugPrint("atualizandoPref: " + String(flags.atualizandoPref ? "SIM" : "NAO"));
  debugPrint("erroSensor: " + String(flags.erroSensor ? "SIM" : "NAO"));
  debugPrint("erroConexao: " + String(flags.erroConexao ? "SIM" : "NAO"));

  debugPrint("\n--- CLIMA ---");
  debugPrint("Ligado: " + String(clima.ligado ? "SIM" : "NAO"));
  debugPrint("Velocidade: " + String(clima.velocidade));
  debugPrint("Umidificando: " + String(clima.umidificando ? "SIM" : "NAO"));
  debugPrint("Aleta V: " + String(clima.aletaV ? "SIM" : "NAO"));
  debugPrint("Aleta H: " + String(clima.aletaH ? "SIM" : "NAO"));
  debugPrint("Timer: " + String(clima.timer));

  debugPrint("\n--- SISTEMA ---");
  debugPrint("WiFi: " + String(flags.wifiOk ? "Conectado" : "Desconectado"));
  debugPrint("-------------------------\n");
#endif
}

// === FUNÇÕES PARA FEEDBACK ===
void tocarSom(SomBuzzer tipo) {
  static const uint8_t SONS[][4] = {
    { 0, 0, 0, 0 },    // SOM_NENHUM
    { 20, 10, 5, 3 },  // SOM_INICIAR
    { 25, 5, 0, 1 },   // SOM_PESSOA_ENTROU
    { 15, 5, 0, 1 },   // SOM_PESSOA_SAIU
    { 30, 2, 2, 1 },   // SOM_COMANDO
    { 40, 3, 3, 3 },   // SOM_ALERTA
    { 10, 15, 5, 2 },  // SOM_ERRO
    { 35, 3, 2, 2 },   // SOM_CONECTADO
    { 15, 10, 5, 1 },  // SOM_DESCONECTADO
    { 45, 2, 1, 2 }    // SOM_OK
  };

  if (tipo == SOM_NENHUM) return;

  const uint8_t* som = SONS[tipo];
  int freq = som[0] * 100;
  int duracao = som[1] * 10;
  int pausa = som[2] * 10;
  int repeticoes = som[3];

  for (int r = 0; r < repeticoes; r++) {
    if (r > 0) delay(pausa);
    
    if (freq > 0 && duracao > 0) {
      tone(BUZZER_PIN, freq, duracao);
      delay(duracao);
      noTone(BUZZER_PIN);
    }
  }
}

void mostrarErroLCD(const char* erro, bool critico = false) {
  static const char MSG_ERRO[] PROGMEM = "ERRO:";

  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.write(7); // Símbolo de erro
  lcd.print(' ');
  lcd.print(MSG_ERRO);
  lcd.setCursor(0, 1);
  lcd.print(erro);

  if (critico) {
    tocarSom(SOM_ERRO);
  } else {
    tocarSom(SOM_ALERTA);
  }
  delay(600);
  
  if (pessoas.total > 0) {
    atualizarLCD();
  }
}

void animacaoTransicao() {
  for (int i = 0; i < 8; i++) {
    lcd.clear();
    lcd.setCursor(i, 0);
    lcd.write(6); // Símbolo OK
    delay(50);
  }
  lcd.clear();
}

void atualizarLCD() {
  if (pessoas.total > 0) {
    lcd.backlight();
  } else {
    lcd.noBacklight();
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("Sistema Standby");
    lcd.setCursor(0, 1);
    lcd.print("Aproxime o cartao");
    return;
  }

  static uint32_t hashAnterior = 0;
  static unsigned long ultimaAtualizacao = 0;
  unsigned long agora = millis();

  if (agora - ultimaAtualizacao < 200) return;

  uint32_t hash = (uint32_t)(sensores.temperatura * 10) + 
                  (uint32_t)(sensores.humidade) * 1000 + 
                  sensores.luminosidade * 10000 + 
                  pessoas.total * 100000 + 
                  (clima.ligado ? 1000000 : 0) + 
                  (flags.wifiOk ? 2000000 : 0) + 
                  (flags.erroSensor ? 4000000 : 0) + 
                  (flags.modoManualIlum ? 8000000 : 0) + 
                  (flags.modoManualClima ? 16000000 : 0);

  if (hash == hashAnterior) return;
  hashAnterior = hash;
  ultimaAtualizacao = agora;

  lcd.clear();

  if (flags.modoManualIlum || flags.modoManualClima) {
    lcd.setCursor(0, 0);
    lcd.print("MANUAL ");
    if (flags.modoManualIlum) lcd.print("L");
    if (flags.modoManualClima) lcd.print("C");
    
    lcd.setCursor(8, 0);
    lcd.write(0); // Pessoa
    lcd.print(pessoas.total);
    
    if (!flags.wifiOk) {
      lcd.setCursor(13, 0);
      lcd.write(7); // Erro WiFi
    } else {
      lcd.setCursor(13, 0);
      lcd.write(4); // WiFi OK
    }

    lcd.setCursor(0, 1);
    lcd.write(1); // Temperatura
    lcd.print(sensores.temperatura, 1);
    lcd.write(223); // Grau
    lcd.print("C ");
    
    lcd.write(3); // Luz
    lcd.print(sensores.luminosidade);
    lcd.print("%");
  } else {
    // Tela principal
    lcd.setCursor(0, 0);
    lcd.write(0); // Pessoa
    lcd.print(pessoas.total);
    lcd.print(" ");
    
    lcd.write(1); // Temperatura
    lcd.print(sensores.temperatura, 1);
    lcd.write(223); // Grau
    
    if (clima.ligado) {
      lcd.setCursor(10, 0);
      lcd.write(5); // Ar condicionado
      lcd.print("V");
      lcd.print(clima.velocidade);
    }
    
    if (!flags.wifiOk) {
      lcd.setCursor(15, 0);
      lcd.write(7); // Erro
    } else {
      lcd.setCursor(15, 0);
      lcd.write(4); // WiFi
    }

    lcd.setCursor(0, 1);
    lcd.write(2); // Umidade
    lcd.print(sensores.humidade, 0);
    lcd.print("% ");
    
    lcd.write(3); // Luz
    lcd.print(sensores.luminosidade);
    lcd.print("%");
    
    if (flags.erroSensor) {
      lcd.setCursor(15, 1);
      lcd.write(7); // Erro sensor
    }
  }
}

void atualizarTelaClimatizador() {
  static uint8_t estadoAnterior = 0;
  static unsigned long tempoExibicao = 0;

  uint8_t estadoAtual = (clima.ligado << 0) | 
                        (clima.umidificando << 1) | 
                        (clima.velocidade << 2) | 
                        (clima.timer << 4) | 
                        (clima.aletaV << 7);

  if (estadoAtual != estadoAnterior) {
    estadoAnterior = estadoAtual;
    tempoExibicao = millis();

    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.write(5); // Ícone climatizador
    lcd.print(" CLIMATIZADOR");

    lcd.setCursor(0, 1);
    if (clima.ligado) {
      lcd.print("ON V");
      lcd.print(clima.velocidade);
      
      if (clima.umidificando) {
        lcd.print(" UM");
      }
      
      if (clima.timer > 0) {
        lcd.print(" T");
        lcd.print(clima.timer);
        lcd.print("h");
      }
      
      if (clima.aletaV) {
        lcd.setCursor(14, 1);
        lcd.print("AV");
      }
      
      if (clima.aletaH) {
        lcd.setCursor(14, 0);
        lcd.print("AH");
      }
    } else {
      lcd.print("DESLIGADO");
    }
  }
  
  if (millis() - tempoExibicao > 1500) {
    atualizarLCD();
  }
}

// === FUNÇÃO DE CONSULTA DE PREFERÊNCIAS FIREBASE ===
bool consultarPreferencias() {
  if (pessoas.total == 0 || !flags.wifiOk || flags.atualizandoPref) {
    return false;
  }

  flags.atualizandoPref = true;

  StaticJsonDocument<256> doc;
  JsonArray tagsArray = doc.createNestedArray("tags");

  int tagsAtivas = 0;
  for (int i = 0; i < pessoas.count; i++) {
    if (pessoas.estado[i]) {
      tagsArray.add(pessoas.tags[i]);
      tagsAtivas++;
    }
  }

  if (tagsAtivas == 0) {
    flags.atualizandoPref = false;
    return false;
  }

  String jsonTags;
  serializeJson(doc, jsonTags);
  debugPrint("Consultando preferências Firebase para " + String(tagsAtivas) + " tags");
  debugPrint("JSON enviado: " + jsonTags);

  // Enviar tags para o sistema Dart processar via Firebase
  bool sucesso = enviarDadosFirebase("/preferencias_request", jsonTags, false);
  
  if (sucesso) {
    // Aguardar um pouco e ler as preferências calculadas
    delay(1000);
    
    String response = lerDadosFirebase("/preferencias_grupo");
    
    if (response.length() > 0 && response != "null") {
      StaticJsonDocument<200> respDoc;
      DeserializationError error = deserializeJson(respDoc, response);
      
      if (!error) {
        pessoas.tempPref = respDoc["temperatura_preferida"] | 25.0;
        pessoas.lumPref = respDoc["luminosidade_preferida"] | 50;
        pessoas.prefsAtualizadas = true;
        
        debugPrint("✓ Preferências recebidas: Temp=" + String(pessoas.tempPref) + "°C, Lum=" + String(pessoas.lumPref) + "%");
        
        // Limpar a requisição processada
        deletarDadosFirebase("/preferencias_request");
        
        flags.atualizandoPref = false;
        return true;
      }
    }
  }

  debugPrint("✗ Falha ao consultar preferências");
  flags.atualizandoPref = false;
  return false;
}

// === FUNÇÕES PRINCIPAIS ===

void configurarRele(int nivel) {
  static int nivelAnterior = -1;
  if (nivel == nivelAnterior) return;

  nivel = (nivel / 25) * 25;
  if (nivel > 100) nivel = 100;

  const bool estados[5][4] = {
    { HIGH, HIGH, HIGH, HIGH },  // 0%
    { LOW,  HIGH, HIGH, HIGH },  // 25%
    { LOW,  LOW,  HIGH, HIGH },  // 50%
    { LOW,  LOW,  LOW,  HIGH },  // 75%  
    { LOW,  LOW,  LOW,  LOW }    // 100%
  };

  int indice = nivel / 25;
  if (indice >= 0 && indice <= 4) {
    digitalWrite(RELE_1, estados[indice][0]);
    digitalWrite(RELE_2, estados[indice][1]);
    digitalWrite(RELE_3, estados[indice][2]);
    digitalWrite(RELE_4, estados[indice][3]);
    
    sensores.luminosidade = nivel;
    nivelAnterior = nivel;
    
    debugPrint("Relés configurados para " + String(nivel) + "%");
    
    if (nivel > 0) {
      flags.ilumAtiva = true;
      tocarSom(SOM_COMANDO);
    } else {
      flags.ilumAtiva = false;
    }
  }
}

void lerSensores() {
  unsigned long agora = millis();
  if (agora - tempos[0] < INTERVALO_DHT) return;
  tempos[0] = agora;

  float temp = dht.readTemperature();
  float hum = dht.readHumidity();

  if (!isnan(temp) && !isnan(hum) && temp >= -40 && temp <= 80 && hum >= 0 && hum <= 100) {
    sensores.temperatura = temp;
    sensores.humidade = hum;
    sensores.dadosValidos = true;
    flags.erroSensor = false;
  } else {
    flags.erroSensor = true;
    sensores.dadosValidos = false;
    
    if (flags.debug) {
      debugPrint("✗ Erro na leitura DHT: T=" + String(temp) + ", H=" + String(hum));
    }
  }

  // Leitura do LDR com filtro de média
  static int ldrBuffer[3] = { 0 };
  static int bufferIndex = 0;

  ldrBuffer[bufferIndex] = analogRead(LDR_PIN);
  bufferIndex = (bufferIndex + 1) % 3;
  sensores.valorLDR = (ldrBuffer[0] + ldrBuffer[1] + ldrBuffer[2]) / 3;

  if (pessoas.total > 0) {
    // Normalizar LDR para porcentagem (inverso: quanto menor o valor, mais escuro)
    // sensores.luminosidade será controlado pelos relés, este é ambiente
  }
}

void enviarDados() {
  static bool forcarEnvio = false;
  
  unsigned long agora = millis();
  if (!forcarEnvio && agora - tempos[1] < INTERVALO_DADOS) return;
  tempos[1] = agora;

  StaticJsonDocument<400> doc;
  doc["temperatura"] = round(sensores.temperatura * 10) / 10.0;
  doc["humidade"] = round(sensores.humidade);
  doc["luminosidade"] = sensores.luminosidade;
  doc["pessoas"] = pessoas.total;
  doc["timestamp"] = millis(); // Timestamp local
  doc["dados_validos"] = sensores.dadosValidos;

  // Adicionar array de tags
  JsonArray tagsArray = doc.createNestedArray("tags");
  for (int i = 0; i < pessoas.count; i++) {
    if (pessoas.estado[i]) {
      tagsArray.add(pessoas.tags[i]);
    }
  }

  // Estado do climatizador
  JsonObject c = doc.createNestedObject("climatizador");
  c["ligado"] = clima.ligado;
  c["umidificando"] = clima.umidificando;
  c["velocidade"] = clima.velocidade;
  c["ultima_velocidade"] = clima.ultimaVel;
  c["timer"] = clima.timer;
  c["aleta_vertical"] = clima.aletaV;
  c["aleta_horizontal"] = clima.aletaH;
  c["modo_manual_clima"] = flags.modoManualClima;
  c["ultima_atualizacao"] = clima.ultimaAtualizacao;

  // Estados do sistema
  doc["modo_manual_ilum"] = flags.modoManualIlum;
  doc["valor_ldr"] = sensores.valorLDR;

  String dados;
  serializeJson(doc, dados);
  debugPrint("Enviando dados Firebase: " + dados);

  bool sucesso = enviarDadosFirebase("/sensores", dados, false);
  
  if (pessoas.total == 0 && forcarEnvio) {
    debugPrint("✓ Dados finais enviados antes do reset");
  }
  forcarEnvio = false;
}

void enviarDadosImediato() {
  // Mesma lógica de enviarDados(), mas sem verificação de intervalo
  StaticJsonDocument<400> doc;
  doc["temperatura"] = round(sensores.temperatura * 10) / 10.0;
  doc["humidade"] = round(sensores.humidade);
  doc["luminosidade"] = sensores.luminosidade;
  doc["pessoas"] = pessoas.total;
  doc["timestamp"] = millis();
  doc["dados_validos"] = sensores.dadosValidos;

  JsonArray tagsArray = doc.createNestedArray("tags");
  for (int i = 0; i < pessoas.count; i++) {
    if (pessoas.estado[i]) {
      tagsArray.add(pessoas.tags[i]);
    }
  }

  JsonObject c = doc.createNestedObject("climatizador");
  c["ligado"] = clima.ligado;
  c["umidificando"] = clima.umidificando;
  c["velocidade"] = clima.velocidade;
  c["ultima_velocidade"] = clima.ultimaVel;
  c["timer"] = clima.timer;
  c["aleta_vertical"] = clima.aletaV;
  c["aleta_horizontal"] = clima.aletaH;
  c["modo_manual_clima"] = flags.modoManualClima;

  doc["modo_manual_ilum"] = flags.modoManualIlum;
  doc["valor_ldr"] = sensores.valorLDR;

  String dados;
  serializeJson(doc, dados);
  debugPrint("ENVIO FORÇADO Firebase: " + dados);
  
  bool sucesso = enviarDadosFirebase("/sensores", dados, false);
  debugPrint("Resultado envio forçado: " + String(sucesso ? "SUCESSO" : "FALHA"));
}

void processarNFC() {
  if (!mfrc522.PICC_IsNewCardPresent() || !mfrc522.PICC_ReadCardSerial()) {
    return;
  }

  String tag = "";
  for (byte i = 0; i < mfrc522.uid.size; i++) {
    if (mfrc522.uid.uidByte[i] < 0x10) tag += "0";
    tag += String(mfrc522.uid.uidByte[i], HEX);
  }
  tag.toUpperCase();

  debugPrint("Tag NFC lida: " + tag);
  // Se estiver em modo cadastro, não alterar presença: apenas publicar a tag
  if (flags.modoCadastro) {
    debugPrint("Modo cadastro ativo - publicando tag para registro: " + tag);
    enviarDadosFirebase("/ultima_tag", "\"" + tag + "\"", false);
    // Opcional: manter modoCadastro ativo até que o app solicite desativação
  } else {
    gerenciarPresenca(tag);
  }

  mfrc522.PICC_HaltA();
  mfrc522.PCD_StopCrypto1();
}

void gerenciarPresenca(const String& tag) {
  int indice = -1;
  bool entrando = false;
  int totalAnterior = pessoas.total;

  // Procurar tag no histórico
  for (int i = 0; i < pessoas.count; i++) {
    if (pessoas.tags[i] == tag) {
      indice = i;
      break;
    }
  }

  if (indice == -1) {
    // Tag nova - adicionar ao histórico
    if (pessoas.count < 10) {
      indice = pessoas.count;
      pessoas.tags[indice] = tag;
      pessoas.estado[indice] = true;
      pessoas.count++;
      pessoas.total++;
      entrando = true;
      
      debugPrint("✓ Nova pessoa entrou: " + tag + " (Total: " + String(pessoas.total) + ")");
      tocarSom(SOM_PESSOA_ENTROU);
    } else {
      debugPrint("✗ Limite máximo de tags atingido!");
      tocarSom(SOM_ERRO);
      return;
    }
  } else {
    // Tag conhecida - alternar estado
    if (pessoas.estado[indice]) {
      pessoas.estado[indice] = false;
      pessoas.total--;
      debugPrint("✓ Pessoa saiu: " + tag + " (Total: " + String(pessoas.total) + ")");
      tocarSom(SOM_PESSOA_SAIU);
    } else {
      pessoas.estado[indice] = true;
      pessoas.total++;
      entrando = true;
      debugPrint("✓ Pessoa retornou: " + tag + " (Total: " + String(pessoas.total) + ")");
      tocarSom(SOM_PESSOA_ENTROU);
    }
  }

  // Se mudou o número de pessoas OU alguém entrou, e há pessoas presentes
  if ((totalAnterior != pessoas.total || entrando) && pessoas.total > 0 && !flags.atualizandoPref) {
    pessoas.prefsAtualizadas = false;
    
    delay(500); // Pequeno delay para estabilizar
    
    // Consultar preferências
    if (consultarPreferencias()) {
      debugPrint("✓ Preferências atualizadas para o grupo atual");
    }
    
    // Se era a primeira pessoa a entrar, inicializar automação
    if (totalAnterior == 0) {
      flags.monitorandoLDR = true;
      debugPrint("✓ Sistema ativado - iniciando automação");
    }
  }

  // Se última pessoa saiu
  if (pessoas.total == 0 && totalAnterior > 0) {
    enviarDadosImediato(); // Enviar dados finais
    delay(1000);
    resetarSistema();
  }

  atualizarLCD();
  enviarDados();
}

void resetarSistema() {
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Desativando...");
  lcd.setCursor(0, 1);
  lcd.print("Sistema");
  tocarSom(SOM_ALERTA);
  delay(800);

  // Desligar climatizador se estiver ligado
  if (clima.ligado) {
    enviarComandoIR(IR_POWER);
    delay(500);
  }

  // Desligar iluminação
  lcd.setCursor(0, 1);
  lcd.print("Desl. Luzes... ");
  flags.modoManualIlum = false;
  flags.modoManualClima = false;
  flags.ilumAtiva = false;
  flags.monitorandoLDR = true;
  configurarRele(0);
  delay(300);

  // Limpar dados das pessoas
  for (int i = 0; i < pessoas.count; i++) {
    pessoas.tags[i] = "";
    pessoas.estado[i] = false;
  }
  pessoas.total = 0;
  pessoas.count = 0;
  pessoas.tempPref = 25.0;
  pessoas.lumPref = 50;
  pessoas.prefsAtualizadas = false;

  // Reset flags
  flags.modoManualIlum = false;
  flags.modoManualClima = false;
  flags.atualizandoPref = false;

  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Sistema em");
  lcd.setCursor(0, 1);
  lcd.print("Standby");
  delay(1000);

  debugPrint("✓ Sistema resetado - Standby");
}

void gerenciarIluminacao() {
  unsigned long agora = millis();
  if (agora - tempos[2] < INTERVALO_LDR) return;
  tempos[2] = agora;

  if (flags.modoManualIlum || pessoas.total == 0) return;

  if (!flags.monitorandoLDR) return;

  bool escuro = sensores.valorLDR < LIMIAR_LDR_ESCURIDAO;
  bool deveLigar = escuro && pessoas.total > 0;
  bool deveManter = flags.ilumAtiva && pessoas.total > 0;
  bool deveDesligar = !deveManter && pessoas.total == 0;

  if (deveLigar && !flags.ilumAtiva) {
    int nivelDesejado = pessoas.prefsAtualizadas ? pessoas.lumPref : 75;
    configurarRele(nivelDesejado);
    debugPrint("✓ Iluminação automática LIGADA: " + String(nivelDesejado) + "% (LDR: " + String(sensores.valorLDR) + ")");
  }
  else if (deveDesligar && flags.ilumAtiva) {
    configurarRele(0);
    debugPrint("✓ Iluminação automática DESLIGADA");
  }
  else if (flags.ilumAtiva && pessoas.prefsAtualizadas) {
    // Ajustar nível baseado nas preferências
    int nivelAtual = sensores.luminosidade;
    int nivelDesejado = pessoas.lumPref;
    
    if (abs(nivelAtual - nivelDesejado) >= 25) { // Diferença mínima de 25% para ajustar
      configurarRele(nivelDesejado);
      debugPrint("✓ Iluminação ajustada para preferências: " + String(nivelDesejado) + "%");
    }
  }
}

bool enviarComandoIR(uint8_t comando) {
  if (controleIR.estado != IR_OCIOSO) {
    debugPrint("⏳ IR ocupado, comando ignorado: " + String(comando, HEX));
    return false;
  }

  controleIR.estado = IR_ENVIANDO;
  controleIR.comandoPendente = comando;
  controleIR.inicioEnvio = millis();
  controleIR.comandoConfirmado = false;

  // Desabilitar receptor temporariamente
  IrReceiver.stop();
  delay(JANELA_ECO);

  // Enviar comando IR
  IrSender.sendNEC(IR_ENDERECO, comando, 2);
  
  debugPrint("IR enviado: " + String(comando, HEX));
  
  // Reabilitar receptor
  delay(JANELA_ECO);
  IrReceiver.start();

  // Atualizar estado interno
  atualizarEstadoClima(comando);
  atualizarTelaClimatizador();

  controleIR.estado = IR_OCIOSO;
  tocarSom(SOM_COMANDO);
  return true;
}

void atualizarEstadoClima(uint8_t comando) {
  clima.ultimaAtualizacao = millis();

  switch (comando) {
    case IR_POWER:
      if (clima.ligado) {
        clima.ligado = false;
        clima.velocidade = 0;
        debugPrint("Climatizador DESLIGADO");
      } else {
        clima.ligado = true;
        clima.velocidade = clima.ultimaVel > 0 ? clima.ultimaVel : 1;
        debugPrint("Climatizador LIGADO (vel: " + String(clima.velocidade) + ")");
      }
      break;
      
    case IR_UMIDIFICAR:
      clima.umidificando = !clima.umidificando;
      debugPrint("Umidificador: " + String(clima.umidificando ? "LIGADO" : "DESLIGADO"));
      break;
      
    case IR_VELOCIDADE:
      if (clima.ligado) {
        clima.ultimaVel = clima.velocidade;
        clima.velocidade = (clima.velocidade % 3) + 1;
        debugPrint("Velocidade alterada para: " + String(clima.velocidade));
      }
      break;
      
    case IR_TIMER:
      clima.timer = (clima.timer + 1) % 8; // 0-7 horas
      debugPrint("Timer configurado: " + String(clima.timer) + "h");
      break;
      
    case IR_ALETA_VERTICAL:
      clima.aletaV = !clima.aletaV;
      debugPrint("Aleta vertical: " + String(clima.aletaV ? "ATIVA" : "INATIVA"));
      break;
      
    case IR_ALETA_HORIZONTAL:
      clima.aletaH = !clima.aletaH;
      debugPrint("Aleta horizontal: " + String(clima.aletaH ? "ATIVA" : "INATIVA"));
      break;
  }
  
  // Enviar estado atualizado para Firebase
  StaticJsonDocument<200> doc;
  doc["ligado"] = clima.ligado;
  doc["umidificando"] = clima.umidificando;
  doc["velocidade"] = clima.velocidade;
  doc["ultima_velocidade"] = clima.ultimaVel;
  doc["timer"] = clima.timer;
  doc["aleta_vertical"] = clima.aletaV;
  doc["aleta_horizontal"] = clima.aletaH;
  doc["ultima_atualizacao"] = clima.ultimaAtualizacao;
  doc["origem"] = "ir";

  String estadoJson;
  serializeJson(doc, estadoJson);
  enviarDadosFirebase("/climatizador", estadoJson, false);
}

void controleAutomaticoClima() {
  unsigned long agora = millis();
  if (agora - tempos[3] < INTERVALO_CLIMA_AUTO) return;
  tempos[3] = agora;

  if (flags.modoManualClima || pessoas.total == 0 || !pessoas.prefsAtualizadas) {
    return;
  }

  if (!sensores.dadosValidos) return;

  float tempAtual = sensores.temperatura;
  float tempDesejada = pessoas.tempPref;
  float diferenca = tempAtual - tempDesejada;

  // Histerese para evitar liga/desliga constante
  static bool ultimoEstadoDesejado = false;
  bool estadoDesejado = false;

  if (diferenca > 2.5) {
    estadoDesejado = true; // Ligar para resfriar
  } else if (diferenca < 1.5) {
    estadoDesejado = false; // Pode desligar
  } else {
    estadoDesejado = ultimoEstadoDesejado; // Manter estado atual
  }

  // Só atuar se houve mudança no estado desejado
  if (estadoDesejado != ultimoEstadoDesejado) {
    if (estadoDesejado && !clima.ligado) {
      debugPrint("🔥 Automação clima: LIGANDO (Atual: " + String(tempAtual, 1) + "°C, Desejada: " + String(tempDesejada, 1) + "°C)");
      enviarComandoIR(IR_POWER);
      delay(1000);
      
      // Ajustar velocidade baseada na diferença
      if (diferenca > 4.0) {
        enviarComandoIR(IR_VELOCIDADE); // Vel 2
        delay(500);
        enviarComandoIR(IR_VELOCIDADE); // Vel 3
      } else if (diferenca > 3.0) {
        enviarComandoIR(IR_VELOCIDADE); // Vel 2
      }
      // Senão fica na velocidade 1 (padrão)
      
    } else if (!estadoDesejado && clima.ligado) {
      debugPrint("❄️ Automação clima: DESLIGANDO (Atual: " + String(tempAtual, 1) + "°C, Desejada: " + String(tempDesejada, 1) + "°C)");
      enviarComandoIR(IR_POWER);
    }
    
    ultimoEstadoDesejado = estadoDesejado;
  }
}

void verificarComandos() {
  unsigned long agora = millis();
  if (agora - tempos[4] < INTERVALO_COMANDOS) return;
  tempos[4] = agora;

  if (!flags.wifiOk) return;

  // Verificar comandos de iluminação
  String cmdIlum = lerDadosFirebase("/comandos/iluminacao");
  if (cmdIlum.length() > 0 && cmdIlum != "null") {
    // Parse do comando
    StaticJsonDocument<100> doc;
    DeserializationError error = deserializeJson(doc, cmdIlum);
    
    if (!error) {
      String comando = doc["comando"];
      
      if (comando == "auto") {
        flags.modoManualIlum = false;
        debugPrint("🔄 Iluminação: modo automático ativado");
        tocarSom(SOM_OK);
        
        // Aplicar automação imediatamente
        gerenciarIluminacao();
        
      } else {
        int nivel = comando.toInt();
        if (nivel >= 0 && nivel <= 100) {
          flags.modoManualIlum = true;
          configurarRele(nivel);
          debugPrint("💡 Iluminação manual: " + String(nivel) + "%");
          tocarSom(SOM_COMANDO);
        }
      }
      
      // Limpar comando processado
      deletarDadosFirebase("/comandos/iluminacao");
    }
  }

  // Verificar comandos do climatizador
  String cmdClima = lerDadosFirebase("/comandos/climatizador");
  if (cmdClima.length() > 0 && cmdClima != "null") {
    StaticJsonDocument<100> doc;
    DeserializationError error = deserializeJson(doc, cmdClima);
    
    if (!error) {
      String comando = doc["comando"];
      
      if (comando == "auto") {
        flags.modoManualClima = false;
        debugPrint("🔄 Climatizador: modo automático ativado");
        tocarSom(SOM_OK);
        
      } else if (comando == "power_on" || comando == "power") {
        flags.modoManualClima = true;
        if (!clima.ligado) {
          enviarComandoIR(IR_POWER);
        }
        
      } else if (comando == "power_off") {
        flags.modoManualClima = true;
        if (clima.ligado) {
          enviarComandoIR(IR_POWER);
        }
        
      } else if (comando == "velocidade") {
        flags.modoManualClima = true;
        enviarComandoIR(IR_VELOCIDADE);
        
      } else if (comando == "umidificar") {
        flags.modoManualClima = true;
        enviarComandoIR(IR_UMIDIFICAR);
        
      } else if (comando == "timer") {
        flags.modoManualClima = true;
        enviarComandoIR(IR_TIMER);
        
      } else if (comando == "aleta_v") {
        flags.modoManualClima = true;
        enviarComandoIR(IR_ALETA_VERTICAL);
        
      } else if (comando == "aleta_h") {
        flags.modoManualClima = true;
        enviarComandoIR(IR_ALETA_HORIZONTAL);
      }
      
      // Limpar comando processado
      deletarDadosFirebase("/comandos/climatizador");
    }
  }

  // Verificar modo de cadastro (para que o app possa ativar/desativar o registro de novas tags)
  String modoCad = lerDadosFirebase("/modo_cadastro");
  if (modoCad.length() > 0 && modoCad != "null") {
    // Espera-se que o app escreva true ou false (boolean/json)
    if (modoCad.indexOf("true") >= 0) {
      flags.modoCadastro = true;
      cadastroInicio = millis();
      debugPrint("🔐 Modo cadastro ATIVADO via Firebase");
      tocarSom(SOM_OK);
    } else if (modoCad.indexOf("false") >= 0) {
      flags.modoCadastro = false;
      debugPrint("🔓 Modo cadastro DESATIVADO via Firebase");
      tocarSom(SOM_OK);
    }
    // Limpar o indicador
    deletarDadosFirebase("/modo_cadastro");
  }
}

void processarIRRecebido() {
  if (IrReceiver.decode()) {
    if (IrReceiver.decodedIRData.protocol == NEC && 
        IrReceiver.decodedIRData.address == IR_ENDERECO) {
      
      uint8_t comando = IrReceiver.decodedIRData.command;
      
      unsigned long agora = millis();
      static unsigned long ultimoComandoIR = 0;
      
      // Debounce para evitar leituras múltiplas
      if (agora - ultimoComandoIR > DEBOUNCE_RECEBER) {
        ultimoComandoIR = agora;
        
        debugPrint("IR recebido do controle: " + String(comando, HEX));
        
        // Atualizar estado e exibir
        atualizarEstadoClima(comando);
        atualizarTelaClimatizador();
        
        // Forçar modo manual do climatizador quando usar controle físico
        flags.modoManualClima = true;
        tocarSom(SOM_COMANDO);
      }
    }
    
    IrReceiver.resume();
  }
}

void monitorarWiFi() {
  static unsigned long ultimaVerificacao = 0;
  unsigned long agora = millis();
  
  if (agora - ultimaVerificacao < 10000) return; // Verificar a cada 10s
  ultimaVerificacao = agora;

  if (WiFi.status() != WL_CONNECTED) {
    if (flags.wifiOk) {
      flags.wifiOk = false;
      debugPrint("✗ WiFi desconectado");
      tocarSom(SOM_DESCONECTADO);
      
      // Tentar reconectar
      WiFi.begin(ssid, password);
      debugPrint("Tentando reconectar WiFi...");
    }
  } else {
    if (!flags.wifiOk) {
      flags.wifiOk = true;
      debugPrint("✓ WiFi reconectado: " + WiFi.localIP().toString());
      tocarSom(SOM_CONECTADO);
    }
  }
}

// === FUNÇÃO DE CONFIGURAÇÃO (SETUP) ===
void setup() {
  Serial.begin(115200);
  debugPrint("\n🚀 ESP32 IoT System v2.0 (Firebase) Iniciando...");

  // Configurar pinos
  pinMode(BUZZER_PIN, OUTPUT);
  pinMode(RELE_1, OUTPUT);
  pinMode(RELE_2, OUTPUT);
  pinMode(RELE_3, OUTPUT);
  pinMode(RELE_4, OUTPUT);
  pinMode(LDR_PIN, INPUT);

  // Estado inicial dos relés (desligados)
  digitalWrite(RELE_1, HIGH);
  digitalWrite(RELE_2, HIGH);
  digitalWrite(RELE_3, HIGH);
  digitalWrite(RELE_4, HIGH);

  // Inicializar LCD
  lcd.init();
  lcd.backlight();
  lcd.clear();
  
  // Criar caracteres personalizados
  lcd.createChar(0, SIMBOLO_PESSOA);
  lcd.createChar(1, SIMBOLO_TEMP);
  lcd.createChar(2, SIMBOLO_HUM);
  lcd.createChar(3, SIMBOLO_LUZ);
  lcd.createChar(4, SIMBOLO_WIFI);
  lcd.createChar(5, SIMBOLO_AR);
  lcd.createChar(6, SIMBOLO_OK);
  lcd.createChar(7, SIMBOLO_ERRO);

  lcd.setCursor(0, 0);
  lcd.print("ESP32 IoT v2.0");
  lcd.setCursor(0, 1);
  lcd.print("Firebase Ready");

  tocarSom(SOM_INICIAR);

  // Inicializar sensores
  debugPrint("Inicializando sensores...");
  dht.begin();
  
  // Inicializar SPI e RFID
  SPI.begin();
  mfrc522.PCD_Init();
  debugPrint("✓ RFID iniciado");

  // Inicializar IR
  IrSender.begin(IR_SEND_PIN);
  IrReceiver.begin(IR_RECEIVE_PIN);
  debugPrint("✓ IR iniciado");

  // Conectar WiFi
  debugPrint("Conectando WiFi...");
  lcd.setCursor(0, 1);
  lcd.print("Conectando WiFi");
  
  WiFi.begin(ssid, password);
  int tentativas = 0;
  while (WiFi.status() != WL_CONNECTED && tentativas < 20) {
    delay(500);
    debugPrint(".");
    tentativas++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    flags.wifiOk = true;
    debugPrint("\n✓ WiFi conectado: " + WiFi.localIP().toString());
    
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("WiFi Conectado");
    lcd.setCursor(0, 1);
    lcd.print(WiFi.localIP());
    tocarSom(SOM_CONECTADO);
    delay(2000);
  } else {
    flags.wifiOk = false;
    debugPrint("✗ Falha na conexão WiFi");
    
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("WiFi Falhou");
    lcd.setCursor(0, 1);
    lcd.print("Modo Offline");
    tocarSom(SOM_ERRO);
    delay(2000);
  }

  // Inicialização completa
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Sistema Pronto");
  lcd.setCursor(0, 1);
  lcd.print("Aproxime cartao");
  
  debugPrint("✓ Sistema ESP32 iniciado com sucesso!");
  debugPrint("✓ Firebase: " + String(FIREBASE_HOST));
  debugPrint("✓ WiFi: " + String(flags.wifiOk ? "Conectado" : "Desconectado"));
  debugPrint("===========================================\n");
  
  delay(1000);
  lcd.noBacklight(); // Iniciar com luz de fundo desligada
}

// === FUNÇÃO PRINCIPAL (LOOP) ===
void loop() {
  static unsigned long ultimoLoop = 0;
  unsigned long agora = millis();
  
  // Controle de frequência do loop principal
  if (agora - ultimoLoop < 50) { // 20 Hz
    delay(10);
    return;
  }
  ultimoLoop = agora;

  // Monitorar WiFi
  monitorarWiFi();

  // Se o modo cadastro estiver ativo, verificar timeout automático
  if (flags.modoCadastro) {
    if (agora - cadastroInicio > MODO_CADASTRO_TIMEOUT) {
      flags.modoCadastro = false;
      debugPrint("⏱️ Modo cadastro expirou -> DESATIVADO");
      tocarSom(SOM_ALERTA);
    }
  }

  // Ler sensores
  lerSensores();

  // Processar NFC
  processarNFC();

  // Processar IR recebido
  processarIRRecebido();

  // Gerenciar iluminação automática
  gerenciarIluminacao();

  // Controle automático do climatizador
  controleAutomaticoClima();

  // Verificar comandos do Firebase
  verificarComandos();

  // Enviar dados para Firebase
  enviarDados();

  // Atualizar display
  atualizarLCD();

  // Debug (se ativado)
  if (flags.debug) {
    mostrarTelaDebug();
  }

  // Watchdog simples
  yield();
}

// === FUNÇÕES DE TESTE (OPCIONAL) ===
void testarReles() {
  debugPrint("=== TESTE DOS RELÉS ===");
  const int reles[] = {RELE_1, RELE_2, RELE_3, RELE_4};
  
  for (int i = 0; i < 4; i++) {
    debugPrint("Testando Relé " + String(i+1));
    digitalWrite(reles[i], LOW);  // Ligar
    delay(500);
    digitalWrite(reles[i], HIGH); // Desligar
    delay(500);
  }
  debugPrint("=== TESTE CONCLUÍDO ===");
}

void testarNiveisLuminosidade() {
  debugPrint("=== TESTE NÍVEIS DE LUMINOSIDADE ===");
  for (int nivel = 0; nivel <= 100; nivel += 25) {
    debugPrint("Configurando " + String(nivel) + "%");
    configurarRele(nivel);
    delay(2000);
  }
  configurarRele(0); // Desligar
  debugPrint("=== TESTE CONCLUÍDO ===");
}