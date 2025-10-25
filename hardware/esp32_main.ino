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
const unsigned long INTERVALO_PREF_CHECK = 30000; // Verificar preferências a cada 30s

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
  bool ligado : 1;           // Estado atual: ligado/desligado
  bool umidificando : 1;     // PRESERVADO ao desligar - aparelho físico mantém
  bool aletaV : 1;           // PRESERVADO ao desligar - aparelho físico mantém
  bool aletaH : 1;           // PRESERVADO ao desligar - aparelho físico mantém
  uint8_t velocidade : 2;    // 0=desligado, 1-3=velocidades (ciclo: 1→2→3→1)
  uint8_t ultimaVel : 2;     // PRESERVADO ao desligar - para restaurar ao ligar
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
unsigned long ultimaVerificacaoPrefs = 0;

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

  // CORREÇÃO: Mostrar indicador MANUAL apenas se realmente está em modo manual
  // E não mostrar se acabou de resetar as flags
  bool mostrarManual = false;
  if (flags.modoManualIlum && sensores.luminosidade > 0) mostrarManual = true;
  if (flags.modoManualClima && clima.ligado) mostrarManual = true;

  if (mostrarManual) {
    lcd.setCursor(0, 0);
    lcd.print("MANUAL ");
    if (flags.modoManualIlum && sensores.luminosidade > 0) lcd.print("L");
    if (flags.modoManualClima && clima.ligado) lcd.print("C");
    
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
    // Tela principal - modo automático
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
    debugPrint("consultarPreferencias: Condições não atendidas (Pessoas=" + String(pessoas.total) + 
               ", WiFi=" + String(flags.wifiOk) + ", Atualizando=" + String(flags.atualizandoPref) + ")");
    return false;
  }

  flags.atualizandoPref = true;

  // Montar lista de tags ativas e um hash simples para validação
  StaticJsonDocument<512> doc;
  JsonArray tagsArray = doc.createNestedArray("tags");

  int tagsAtivas = 0;
  String tagsConcat = "";
  for (int i = 0; i < pessoas.count; i++) {
    if (pessoas.estado[i]) {
      tagsArray.add(pessoas.tags[i]);
      if (tagsConcat.length() > 0) tagsConcat += ",";
      tagsConcat += pessoas.tags[i];
      tagsAtivas++;
    }
  }

  if (tagsAtivas == 0) {
    flags.atualizandoPref = false;
    debugPrint("consultarPreferencias: Nenhuma tag ativa para consultar.");
    return false;
  }

  String jsonTags;
  serializeJson(doc, jsonTags);
  debugPrint("Consultando preferências Firebase para " + String(tagsAtivas) + " tags");
  debugPrint("JSON enviado: " + jsonTags);

  // Enviar tags para o sistema Dart processar via Firebase
  bool sucesso = enviarDadosFirebase("/preferencias_request", jsonTags, false);

  if (sucesso) {
    // Aguardar processamento: usar polling para evitar ler antes do backend escrever
    const int maxAttempts = 20; // aumentar janela para evitar race com backend (≈ 6s)
    const int waitMs = 300;
    String response = "";
    int attempt = 0;
    while (attempt < maxAttempts) {
      delay(waitMs);
      response = lerDadosFirebase("/preferencias_grupo");
      debugPrint("Tentativa " + String(attempt+1) + "/" + String(maxAttempts) + " - resposta bruta: " + (response.length() ? response : "<vazia>"));
      if (response.length() > 0 && response != "null") {
        // Tentar desserializar e validar que a resposta corresponde à requisição
        StaticJsonDocument<1024> respDoc; // aumentar buffer para arrays maiores
        DeserializationError error = deserializeJson(respDoc, response);
        if (!error) {
          // Verificar presença de tags no payload retornado
          bool tagsCoincidem = false;
          if (respDoc.containsKey("tags_presentes") || respDoc.containsKey("tags")) {
            JsonArray respTags = respDoc.containsKey("tags_presentes") ? respDoc["tags_presentes"].as<JsonArray>() : respDoc["tags"].as<JsonArray>();
            // Verificar que todas as tags solicitadas estão presentes na resposta (ordem indep.)
            bool allFound = true;
            JsonArray reqTags = doc["tags"].as<JsonArray>();
            for (JsonVariant req : reqTags) {
              String reqTag = String((const char*)req.as<const char*>());
              bool found = false;
              for (JsonVariant rv : respTags) {
                String rtag = String((const char*)rv.as<const char*>());
                if (rtag == reqTag) { found = true; break; }
              }
              if (!found) { allFound = false; break; }
            }

            String respConcat = "";
            for (JsonVariant v : respTags) {
              if (respConcat.length() > 0) respConcat += ",";
              respConcat += String((const char*)v.as<const char*>());
            }
            debugPrint("Tags recebidas no response: " + respConcat + " | esperadas: " + tagsConcat);
            tagsCoincidem = allFound;
          }

          // Se não houver tags no response, aceitar (compatibilidade), mas preferir respostas que contenham as tags solicitadas
          if (!respDoc.containsKey("tags_presentes") && !respDoc.containsKey("tags")) {
            debugPrint("Resposta de preferências não contém lista de tags (compatibilidade ativa). Aceitando resposta.");
            tagsCoincidem = true;
          }

          if (!tagsCoincidem) {
            debugPrint("Resposta de preferencias nao corresponde às tags solicitadas. Continuando polling...");
            attempt++;
            continue;
          }

          // Aplicar preferências com validação
          if (respDoc.containsKey("temperatura_preferida")) {
            float tempPref = respDoc["temperatura_preferida"];
            debugPrint("Temperatura preferida calculada pelo servidor: " + String(tempPref));

            if (!isnan(tempPref) && tempPref >= 16.0 && tempPref <= 32.0) {
              pessoas.tempPref = tempPref;
              debugPrint("✓ Temperatura preferida aplicada: " + String(pessoas.tempPref) + "°C");
            } else {
              debugPrint("⚠ Temperatura inválida, usando padrão 25°C");
              pessoas.tempPref = 25.0;
            }
          } else {
            debugPrint("⚠ Temperatura não encontrada na resposta, usando padrão 25°C");
            pessoas.tempPref = 25.0;
          }

          if (respDoc.containsKey("luminosidade_preferida")) {
            int lumPref = respDoc["luminosidade_preferida"];
            debugPrint("Luminosidade preferida calculada pelo servidor: " + String(lumPref));

            if (lumPref >= 0 && lumPref <= 100 && (lumPref % 25 == 0)) {
              pessoas.lumPref = lumPref;
              debugPrint("✓ Luminosidade preferida aplicada: " + String(pessoas.lumPref) + "%");
            } else {
              debugPrint("⚠ Luminosidade inválida (" + String(lumPref) + "), usando padrão 50%");
              pessoas.lumPref = 50;
            }
          } else {
            debugPrint("⚠ Luminosidade não encontrada na resposta, usando padrão 50%");
            pessoas.lumPref = 50;
          }

          pessoas.prefsAtualizadas = true;
          
          debugPrint("=== PREFERÊNCIAS FINAIS APLICADAS ===");
          debugPrint("Temperatura: " + String(pessoas.tempPref) + "°C");
          debugPrint("Luminosidade: " + String(pessoas.lumPref) + "%");
          debugPrint("===================================");

          // Limpar a requisição processada
          deletarDadosFirebase("/preferencias_request");

          flags.atualizandoPref = false;
          return true;
        } else {
          debugPrint("Erro ao parsear JSON da resposta de preferencias: " + String(error.c_str()));
        }
      }

      attempt++;
    }
    debugPrint("Tempo excedido aguardando preferencias do servidor (tentativas esgotadas).");
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
  doc["luminosidade"] = sensores.luminosidade != 0 ? sensores.luminosidade : 0;
  doc["ldr"] = sensores.valorLDR != 0 ? sensores.valorLDR : 0;
  doc["pessoas"] = pessoas.total != 0 ? pessoas.total : 0;
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
  doc["valor_ldr"] = sensores.valorLDR != 0 ? sensores.valorLDR : 0;

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
  doc["luminosidade"] = sensores.luminosidade != 0 ? sensores.luminosidade : 0;
  doc["ldr"] = sensores.valorLDR != 0 ? sensores.valorLDR : 0;
  doc["pessoas"] = pessoas.total != 0 ? pessoas.total : 0;
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
  doc["valor_ldr"] = sensores.valorLDR != 0 ? sensores.valorLDR : 0;

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
  // Feedback sonoro imediato ao ler a tag
  tocarSom(SOM_OK);
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
      pessoas.tags[pessoas.count] = tag;
      pessoas.estado[pessoas.count] = true;
      pessoas.count++;
      pessoas.total++;
      entrando = true;
      
      if (pessoas.total == 1) {
        // CORREÇÃO: Reativa APENAS as automações necessárias, sem forçar modo manual
        flags.monitorandoLDR = true;
        flags.ilumAtiva = false;
        // NÃO resetar flags de modo manual aqui - elas devem ser resetadas apenas no resetarSistema
        // Isso evita que o sistema alterne entre manual/auto indevidamente
        lcd.backlight();
        debugPrint("Primeira pessoa detectada. Monitoramento ativado e backlight ligado.");
      }

      debugPrint("Nova pessoa detectada - Tag: " + tag + ", Total: " + String(pessoas.total));
      tocarSom(SOM_PESSOA_ENTROU);

      lcd.clear();
      lcd.setCursor(0, 0);
      lcd.write(0);
      lcd.print(" Bem-vindo!");
      lcd.setCursor(0, 1);
      lcd.print("Pessoas: ");
      lcd.print(pessoas.total);
      delay(400);
    } else {
      debugPrint("Limite de pessoas atingido (10). Ignorando nova tag: " + tag);
      tocarSom(SOM_ERRO);
      delay(200);
    }
  } else if (pessoas.estado[indice]) {
    // Tag conhecida e pessoa estava PRESENTE - está SAINDO
    pessoas.estado[indice] = false;
    pessoas.total--;

    debugPrint("Pessoa saindo - Tag: " + tag + ", Total: " + String(pessoas.total));
    tocarSom(SOM_PESSOA_SAIU);

    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.write(0);
    lcd.print(" Ate logo!");
    lcd.setCursor(0, 1);
    lcd.print("Pessoas: ");
    lcd.print(pessoas.total);
    delay(400);

    // Envia dados IMEDIATAMENTE para o servidor registrar a saída
    enviarDadosImediato();
    
    if (pessoas.total == 0) {
      // Envia dados algumas vezes para garantir
      debugPrint("ÚLTIMA PESSOA SAINDO - Enviando dados críticos múltiplas vezes");
      delay(1000); enviarDadosImediato();
      delay(1500); enviarDadosImediato();
      delay(2000);
      resetarSistema();
      return;
    }
    
    // Marcar que preferências precisam ser atualizadas (grupo mudou)
    pessoas.prefsAtualizadas = false;
    debugPrint("Grupo mudou (saida) - marcando prefsAtualizadas=false e solicitando recalc.");
    
    // CORREÇÃO: Ao recalcular preferências após saída, NÃO resetar flags de modo manual
    // Isso permite que o usuário continue em modo manual mesmo após mudanças no grupo
    if (!flags.atualizandoPref && flags.wifiOk) {
      debugPrint("Consultando preferências após saída...");
      // pequena espera para estabilizar escrita no Firebase
      delay(150);
      if (consultarPreferencias()) {
        debugPrint("Preferências atualizadas com sucesso após saída.");
        
        // NOVO: Se não estiver em modo manual, aplicar as novas preferências
        if (!flags.modoManualClima && clima.ligado) {
          float tempAlvo = pessoas.tempPref;
          float diff = sensores.temperatura - tempAlvo;
          int velDesejada = 1;
          if (diff >= 4.5) velDesejada = 3;
          else if (diff >= 3.0) velDesejada = 2;
          
          if (diff <= -0.5) {
            debugPrint("Desligando clima após saída (temp adequada)");
            enviarComandoIR(IR_POWER);
          } else if (clima.velocidade != velDesejada) {
            debugPrint("Ajustando velocidade após saída: " + String(velDesejada));
            int tentativas = 0;
            while (clima.velocidade != velDesejada && tentativas < 3) {
              if (enviarComandoIR(IR_VELOCIDADE)) tentativas++;
              else break;
              delay(700);
            }
          }
        }
        
        if (!flags.modoManualIlum && flags.ilumAtiva) {
          int nivelDesejado = pessoas.lumPref;
          if (nivelDesejado == 0) nivelDesejado = 25;
          if (sensores.luminosidade != nivelDesejado) {
            debugPrint("Ajustando iluminação após saída: " + String(nivelDesejado) + "%");
            configurarRele(nivelDesejado);
          }
        }
        
        atualizarLCD();
      } else {
        debugPrint("Falha ao atualizar preferências imediatamente após saída. Será tentado novamente pelo fluxo normal.");
      }
    } else {
      debugPrint("Atualização de preferências já em andamento ou sem WiFi; aguardando conclusão.");
    }
  } else {
    // Tag conhecida MAS pessoa estava marcada como "NÃO PRESENTE" - está VOLTANDO
    pessoas.estado[indice] = true;
    pessoas.total++;
    entrando = true;

    debugPrint("Pessoa voltando - Tag: " + tag + ", Total: " + String(pessoas.total));
    tocarSom(SOM_PESSOA_ENTROU);

    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.write(0);
    lcd.print(" Bem-vindo!");
    lcd.setCursor(0, 1);
    lcd.print("Pessoas: ");
    lcd.print(pessoas.total);
    delay(500);
    
    // Se é a primeira pessoa voltando e climatizador estava desligado mas tinha velocidade salva
    if (pessoas.total == 1 && !clima.ligado && clima.ultimaVel > 0 && !flags.modoManualClima) {
      debugPrint("Restaurando climatizador com TODAS as configurações preservadas:");
      debugPrint("  Velocidade: " + String(clima.ultimaVel));
      debugPrint("  Umidificação: " + String(clima.umidificando ? "LIGADA" : "DESLIGADA"));
      debugPrint("  Aleta Vertical: " + String(clima.aletaV ? "ATIVA" : "INATIVA"));
      debugPrint("  Aleta Horizontal: " + String(clima.aletaH ? "ATIVA" : "INATIVA"));
      
      lcd.clear();
      lcd.setCursor(0, 0);
      lcd.write(5); // Símbolo AR
      lcd.print(" Restaurando");
      lcd.setCursor(0, 1);
      lcd.print("Vel:");
      lcd.print(clima.ultimaVel);
      if (clima.umidificando) lcd.print(" U");
      if (clima.aletaV) lcd.print(" V");
      if (clima.aletaH) lcd.print(" H");
      delay(600);
      
      // Ligar o climatizador (aparelho físico já tem todas as configurações)
      enviarComandoIR(IR_POWER);
      delay(1000);
      
      // Verificar se a velocidade está correta
      if (clima.ligado && clima.velocidade != clima.ultimaVel) {
        debugPrint("Ajustando para velocidade salva: " + String(clima.velocidade) + " -> " + String(clima.ultimaVel));
        int tentativas = 0;
        int velAlvo = clima.ultimaVel;
        while (clima.velocidade != velAlvo && tentativas < 3) {
          if (enviarComandoIR(IR_VELOCIDADE)) tentativas++;
          else break;
          delay(700);
        }
      }
      atualizarLCD();
    }
  }
  
  // Se mudou o número de pessoas OU alguém entrou, e há pessoas presentes
  if ((totalAnterior != pessoas.total || entrando) && pessoas.total > 0 && !flags.atualizandoPref) {
    debugPrint("=== MUDANÇA DE GRUPO DETECTADA ===");
    debugPrint("Total anterior: " + String(totalAnterior) + " -> Atual: " + String(pessoas.total));
    debugPrint("Entrando (nova ou retornando): " + String(entrando ? "SIM" : "NAO"));
    pessoas.prefsAtualizadas = false;
    
    debugPrint("Consultando preferências para o novo grupo...");
    if (consultarPreferencias()) {
      debugPrint("Preferências atualizadas com sucesso após mudança de grupo.");
      // Se a iluminação automática estiver ativa e não em modo manual,
      // força uma reavaliação da iluminação com as novas preferências
      if (flags.ilumAtiva && !flags.modoManualIlum) {
        int nivelDesejado = pessoas.lumPref;
        if (nivelDesejado == 0 && pessoas.lumPref == 0) nivelDesejado = 25;
        
        if (sensores.luminosidade != nivelDesejado) {
          debugPrint("FORÇANDO ajuste de iluminação de " + String(sensores.luminosidade) + "% para " + String(nivelDesejado) + "% (nova preferência).");
          configurarRele(nivelDesejado);
        }
      }

      // --- NOVO: tentar ajustar climatizador imediatamente com base nas preferências ---
      if (!flags.modoManualClima && pessoas.prefsAtualizadas) {
        float tempAlvo = pessoas.tempPref;
        float diff = sensores.temperatura - tempAlvo;

        // calcular velocidade desejada
        int velDesejada = 1;
        if (diff >= 4.5) velDesejada = 3;
        else if (diff >= 3.0) velDesejada = 2;

        // Se estiver quente e climatizador desligado -> ligar e ajustar velocidade
        if (diff >= 2.0 && !clima.ligado) {
          debugPrint("Auto: ligando climatizador apos atualizar preferencias. Diff=" + String(diff));
          enviarComandoIR(IR_POWER);
          // Alguns controles físicos demoram para estabilizar; aumentar espera
          delay(1500);

          if (clima.ligado && clima.velocidade != velDesejada) {
            debugPrint("Tentando ajustar velocidade apos ligar: atual=" + String(clima.velocidade) + " desejada=" + String(velDesejada));
            int tentativas = 0;
            while (clima.velocidade != velDesejada && tentativas < 5) {
              if (enviarComandoIR(IR_VELOCIDADE)) {
                tentativas++;
                unsigned long t0 = millis();
                while (controleIR.estado != IR_OCIOSO && millis() - t0 < TIMEOUT_CONFIRMACAO + 200) {
                  processarIRRecebido();
                  delay(10);
                }
              } else {
                break;
              }
            }
            atualizarLCD();
          }

        } else if (clima.ligado && clima.velocidade != velDesejada) {
          // Se já ligado, ajustar velocidade conforme nova preferência
          debugPrint("Auto: ajustando velocidade apos atualizar preferencias: " + String(clima.velocidade) + " -> " + String(velDesejada));
          int tentativas = 0;
          while (clima.velocidade != velDesejada && tentativas < 5) {
            if (enviarComandoIR(IR_VELOCIDADE)) {
              tentativas++;
              unsigned long t0 = millis();
              while (controleIR.estado != IR_OCIOSO && millis() - t0 < TIMEOUT_CONFIRMACAO + 200) {
                processarIRRecebido();
                delay(10);
              }
            } else {
              break;
            }
          }
          atualizarLCD();
        }
      }
    }
  }

  atualizarLCD();
  enviarDados();
}

void resetarSistema() {
  debugPrint("=== INICIANDO RESET DO SISTEMA ===");
  
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Desativando...");
  lcd.setCursor(0, 1);
  lcd.print("Sistema");
  tocarSom(SOM_ALERTA);
  delay(800);

  // Desligar climatizador se estiver ligado
  if (clima.ligado) {
    debugPrint("Desligando climatizador...");
    enviarComandoIR(IR_POWER);
    delay(1000);
  }

  // Desligar iluminação
  lcd.setCursor(0, 1);
  lcd.print("Desl. Luzes... ");
  debugPrint("Desligando iluminação...");
  configurarRele(0);
  delay(300);

  // Reset COMPLETO de todas as flags
  flags.modoManualIlum = false;
  flags.modoManualClima = false;
  flags.ilumAtiva = false;
  flags.monitorandoLDR = true;
  flags.atualizandoPref = false;
  flags.comandoIR = false;
  flags.comandoApp = false;

  // Limpar estado do climatizador no software
  // IMPORTANTE: ultimaVel, umidificando, aletaV, aletaH são MANTIDAS
  // O aparelho físico preserva TODAS as configurações quando desligado
  clima.ligado = false;
  clima.velocidade = 0;
  // clima.ultimaVel PRESERVADA - para restaurar quando alguém voltar
  // clima.umidificando PRESERVADA - aparelho físico mantém
  // clima.aletaV PRESERVADA - aparelho físico mantém
  // clima.aletaH PRESERVADA - aparelho físico mantém
  clima.timer = 0; // Timer é resetado
  clima.ultimaAtualizacao = 0;
  
  debugPrint("Climatizador resetado (configurações preservadas: vel=" + String(clima.ultimaVel) + 
             ", umid=" + String(clima.umidificando) + ", aV=" + String(clima.aletaV) + 
             ", aH=" + String(clima.aletaH) + ")");

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

  // Reset dos tempos de verificação
  ultimaVerificacaoPrefs = 0;
  for (int i = 0; i < 8; i++) {
    tempos[i] = 0;
  }

  // Enviar estado final para o Firebase
  debugPrint("Enviando estado final para Firebase...");
  enviarDadosImediato();
  delay(500);

  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Sistema em");
  lcd.setCursor(0, 1);
  lcd.print("Standby");
  delay(1000);

  debugPrint("✓ Sistema COMPLETAMENTE resetado - Standby");
  debugPrint("=== RESET CONCLUÍDO ===\n");
}

void gerenciarIluminacao() {
  unsigned long agora = millis();
  if (agora - tempos[2] < INTERVALO_LDR) return;
  tempos[2] = agora;

  // Se não há pessoas, desligar luzes automaticamente
  if (pessoas.total == 0) {
    if (flags.ilumAtiva || sensores.luminosidade != 0) {
      debugPrint("Desligando luzes: Nenhuma pessoa presente.");

      lcd.clear();
      lcd.setCursor(0, 0);
      lcd.write(3);
      lcd.print(" Luz Auto Off");
      lcd.setCursor(0, 1);
      lcd.print("Nenhuma pessoa");
      tocarSom(SOM_COMANDO);
      delay(800);

      configurarRele(0);
      flags.ilumAtiva = false;
      flags.modoManualIlum = false;
      atualizarLCD();
    }
    return;
  }

  // Se está em modo manual, NÃO fazer nada automaticamente
  if (flags.modoManualIlum) {
    debugPrint("Modo manual ativo - ignorando controle automático de iluminação");
    return;
  }

  // Verificar se as preferências foram atualizadas antes de ligar
  if (!pessoas.prefsAtualizadas && pessoas.total > 0) {
    debugPrint("Aguardando atualização das preferências antes de gerenciar iluminação...");
    return;
  }

  // Verifica se o LDR deve ser monitorado (apenas uma vez por "sessão" de pessoas)
  if (flags.monitorandoLDR) {
    if (sensores.valorLDR < LIMIAR_LDR_ESCURIDAO) { // Se está escuro
      int nivel = pessoas.lumPref;

      if (nivel == 0) {
        nivel = 25;
        debugPrint("⚠ Preferência é 0% - aplicando 25% mínimo para segurança");
      }

      debugPrint("=== LIGANDO LUZES AUTOMÁTICO (primeira vez na sessão) ===");
      debugPrint("LDR: " + String(sensores.valorLDR) + " < " + String(LIMIAR_LDR_ESCURIDAO));
      debugPrint("Preferência recebida: " + String(pessoas.lumPref) + "%");
      debugPrint("Nível aplicado: " + String(nivel) + "%");
      debugPrint("Prefs atualizadas: " + String(pessoas.prefsAtualizadas ? "SIM" : "NAO"));

      lcd.clear();
      lcd.setCursor(0, 0);
      lcd.write(3);
      lcd.print(" Luz Auto ON ");
      lcd.print(nivel);
      lcd.print("%");
      lcd.setCursor(0, 1);
      lcd.print("Pref: ");
      lcd.print(pessoas.lumPref);
      lcd.print("% LDR:");
      lcd.print(sensores.valorLDR);
      tocarSom(SOM_COMANDO);
      delay(800);

      configurarRele(nivel);
      flags.ilumAtiva = true;
      flags.monitorandoLDR = false; // Desativa permanentemente até resetar sistema
      debugPrint("Monitoramento do LDR desativado permanentemente até reset do sistema.");
      atualizarLCD();
    } else {
      // Se está claro na primeira verificação, mantém luzes apagadas mas ainda monitora
      debugPrint("LDR indica ambiente claro (" + String(sensores.valorLDR) + " >= " + String(LIMIAR_LDR_ESCURIDAO) + ") - mantendo luzes apagadas");
      if (sensores.luminosidade != 0) {
        configurarRele(0);
        atualizarLCD();
      }
    }
  } else {
    // Uma vez que o LDR foi verificado inicialmente, só ajusta conforme preferências
    // NÃO monitora mais o LDR até resetar o sistema
    int nivelDesejado = pessoas.lumPref;
    if (nivelDesejado == 0) nivelDesejado = 25;

    if (sensores.luminosidade != nivelDesejado && pessoas.prefsAtualizadas) {
      debugPrint("AJUSTANDO nível de " + String(sensores.luminosidade) + "% para " + String(nivelDesejado) + "% (nova preferência)");
      
      lcd.clear();
      lcd.setCursor(0, 0);
      lcd.write(3);
      lcd.print(" Ajuste Auto");
      lcd.setCursor(0, 1);
      lcd.print(sensores.luminosidade);
      lcd.print("% -> ");
      lcd.print(nivelDesejado);
      lcd.print("%");
      tocarSom(SOM_COMANDO);
      delay(800);
      
      configurarRele(nivelDesejado);
      atualizarLCD();
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
        // Ao desligar: salvar velocidade e manter TODAS as configurações
        // O aparelho físico mantém: velocidade, umidificação, aletas V/H
        clima.ultimaVel = clima.velocidade;
        clima.ligado = false;
        clima.velocidade = 0;
        // NOTA: umidificando, aletaV, aletaH NÃO são alteradas - o aparelho físico as mantém!
        debugPrint("Climatizador DESLIGADO (configurações preservadas: vel=" + String(clima.ultimaVel) + 
                   ", umid=" + String(clima.umidificando) + ", aV=" + String(clima.aletaV) + 
                   ", aH=" + String(clima.aletaH) + ")");
      } else {
        // Ao ligar: restaurar velocidade (as outras configurações já estão no aparelho)
        clima.ligado = true;
        clima.velocidade = clima.ultimaVel > 0 ? clima.ultimaVel : 1;
        debugPrint("Climatizador LIGADO (restaurando vel=" + String(clima.velocidade) + 
                   ", umid=" + String(clima.umidificando) + ", aV=" + String(clima.aletaV) + 
                   ", aH=" + String(clima.aletaH) + ")");
      }
      break;
      
    case IR_UMIDIFICAR:
      // Só pode alternar umidificação se o climatizador estiver ligado
      if (clima.ligado) {
        clima.umidificando = !clima.umidificando;
        debugPrint("Umidificador: " + String(clima.umidificando ? "LIGADO" : "DESLIGADO"));
      } else {
        debugPrint("⚠ Umidificador não pode ser alterado com climatizador desligado");
      }
      break;
      
    case IR_VELOCIDADE:
      if (clima.ligado) {
        // Salvar velocidade antes de alterar
        clima.ultimaVel = clima.velocidade;
        // Ciclo de velocidades: 1 → 2 → 3 → 1
        clima.velocidade = (clima.velocidade % 3) + 1;
        debugPrint("Velocidade alterada: " + String(clima.ultimaVel) + " -> " + String(clima.velocidade));
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
  // Só funciona se houver pessoas e não estiver em modo manual
  if (pessoas.total <= 0 || flags.modoManualClima) {
    if (pessoas.total == 0 && clima.ligado) {
      debugPrint("Desligando climatizador automaticamente (sem pessoas).");
      enviarComandoIR(IR_POWER);
    }
    return;
  }
  
  // Define temperatura alvo: se há preferências atualizadas, usa a média; senão usa 25°C padrão
  float tempAlvo = 25.0;
  String origemTemp = "padrão (25°C)";
  
  if (pessoas.prefsAtualizadas && pessoas.tempPref != 25.0) {
    tempAlvo = pessoas.tempPref;
    origemTemp = "média das preferências (" + String(pessoas.tempPref) + "°C)";
  }

  unsigned long agora = millis();
  if (agora - tempos[3] < INTERVALO_CLIMA_AUTO) return;
  tempos[3] = agora;

  float diff = sensores.temperatura - tempAlvo;

  debugPrint("=== CONTROLE AUTOMÁTICO CLIMA ===");
  debugPrint("Temp Atual: " + String(sensores.temperatura) + "°C, Alvo: " + String(tempAlvo) + "°C (" + origemTemp + "), Diff: " + String(diff) + "°C");
  debugPrint("Clima Ligado: " + String(clima.ligado ? "SIM" : "NAO"));

  // calcular velDesejada desde o início (usado tanto ao ligar quanto ao ajustar)
  int velDesejada = 1;
  if (diff >= 4.5) velDesejada = 3;
  else if (diff >= 3.0) velDesejada = 2;

  // Se está quente (diferença >= 2°C) E o climatizador está desligado:
  if (diff >= 2.0 && !clima.ligado) {
    lcd.clear(); lcd.setCursor(0,0); lcd.write(5); lcd.print(" Auto Ligar");
    lcd.setCursor(0,1); lcd.print("Temp: +"); lcd.print(diff,1); lcd.print(" graus");
    tocarSom(SOM_COMANDO);
    debugPrint("LIGANDO climatizador automaticamente (temperatura alta).");
    delay(800);

  enviarComandoIR(IR_POWER);
  // Aguardar estabilização do equipamento físico
  delay(1500);
  atualizarLCD();

    // Após ligar automaticamente, tentar ajustar a velocidade imediatamente
    if (clima.ligado && clima.velocidade != velDesejada) {
      debugPrint("Tentando ajustar velocidade imediatamente apos ligar: atual=" + String(clima.velocidade) + " desejada=" + String(velDesejada));
  int tentativas = 0;
  while (clima.velocidade != velDesejada && tentativas < 5) {
        if (enviarComandoIR(IR_VELOCIDADE)) {
          tentativas++;
          unsigned long t0 = millis();
          while (controleIR.estado != IR_OCIOSO && millis() - t0 < TIMEOUT_CONFIRMACAO + 200) {
            processarIRRecebido();
            delay(10);
          }
        } else {
          break;
        }
      }
      atualizarLCD();
    }

  } else if (diff <= -0.5 && clima.ligado) {
    lcd.clear(); lcd.setCursor(0,0); lcd.write(5); lcd.print(" Auto Deslig.");
    lcd.setCursor(0,1); lcd.print("Temp: "); lcd.print(diff,1); lcd.print(" graus");
    tocarSom(SOM_COMANDO);
    debugPrint("DESLIGANDO climatizador automaticamente (temperatura baixa).");
    delay(800);

    enviarComandoIR(IR_POWER);
    atualizarLCD();
  } else if (clima.ligado) {
    // Ajusta a velocidade com base na diferença de temperatura (usa velDesejada calculada acima)
    if (clima.velocidade != velDesejada) {
      lcd.clear(); lcd.setCursor(0,0); lcd.write(5); lcd.print(" Ajuste Auto");
      lcd.setCursor(0,1); lcd.print("Vel "); lcd.print(clima.velocidade); lcd.print(" -> "); lcd.print(velDesejada);
      tocarSom(SOM_COMANDO);
      debugPrint("Ajustando velocidade do climatizador: " + String(clima.velocidade) + " -> " + String(velDesejada));
      delay(800);

  int tentativas = 0;
  while (clima.velocidade != velDesejada && tentativas < 5) {
        if (enviarComandoIR(IR_VELOCIDADE)) {
          tentativas++;
          unsigned long t0 = millis();
          while (controleIR.estado != IR_OCIOSO && millis() - t0 < TIMEOUT_CONFIRMACAO + 200) {
            processarIRRecebido();
            delay(10);
          }
        } else {
          break;
        }
      }
      atualizarLCD();
    }
  }

  // Controle automático das aletas
  if (clima.ligado && !flags.modoManualClima) {
    if (pessoas.total == 1) {
      if (!clima.aletaV) {
        debugPrint("Controle Auto Aleta: Ativando aleta vertical (1 pessoa).");
        enviarComandoIR(IR_ALETA_VERTICAL); delay(300);
      }
      if (clima.aletaH) {
        debugPrint("Controle Auto Aleta: Desativando aleta horizontal (1 pessoa).");
        enviarComandoIR(IR_ALETA_HORIZONTAL); delay(300);
      }
    } else if (pessoas.total > 1) {
      if (!clima.aletaV) {
        debugPrint("Controle Auto Aleta: Ativando aleta vertical (>1 pessoa).");
        enviarComandoIR(IR_ALETA_VERTICAL); delay(300);
      }
      if (!clima.aletaH) {
        debugPrint("Controle Auto Aleta: Ativando aleta horizontal (>1 pessoa).");
        enviarComandoIR(IR_ALETA_HORIZONTAL); delay(300);
      }
    }
  }

  // Controle automático do umidificador (histerese: ligar <55%, desligar >65%)
  // Só aplicar se: houver pessoas, leitura válida, climatizador LIGADO e não estiver em modo manual
  if (pessoas.total > 0 && sensores.dadosValidos && clima.ligado && !flags.modoManualClima) {
    // Ligar umidificador se umidade estiver abaixo do limiar de acionamento
    if (sensores.humidade < 55.0 && !clima.umidificando) {
      debugPrint("Auto Umidificador: Humidade " + String(sensores.humidade) + "% < 55% -> LIGAR");
      lcd.clear(); lcd.setCursor(0,0); lcd.write(2); lcd.print(" Auto Umidificar");
      lcd.setCursor(0,1); lcd.print("H: "); lcd.print(sensores.humidade,1); lcd.print("%");
      tocarSom(SOM_COMANDO);
      delay(400);
      enviarComandoIR(IR_UMIDIFICAR);
      delay(500);
      atualizarLCD();
    }

    // Desligar umidificador se umidade estiver acima do limiar de desligamento
    if (sensores.humidade > 65.0 && clima.umidificando) {
      debugPrint("Auto Umidificador: Humidade " + String(sensores.humidade) + "% > 65% -> DESLIGAR");
      lcd.clear(); lcd.setCursor(0,0); lcd.write(2); lcd.print(" Auto Umidificar");
      lcd.setCursor(0,1); lcd.print("H: "); lcd.print(sensores.humidade,1); lcd.print("%");
      tocarSom(SOM_COMANDO);
      delay(400);
      enviarComandoIR(IR_UMIDIFICAR);
      delay(500);
      atualizarLCD();
    }
  } else if (pessoas.total == 0 && clima.umidificando) {
    // Se não há pessoas e o umidificador está ligado, desligar
    debugPrint("Desligando umidificador: sem pessoas no ambiente");
    enviarComandoIR(IR_UMIDIFICAR);
    delay(500);
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
    StaticJsonDocument<200> doc;
    DeserializationError error = deserializeJson(doc, cmdClima);
    
    if (!error) {
      String comando = doc["comando"];
      
      if (comando == "auto") {
        flags.modoManualClima = false;
        debugPrint("🔄 Climatizador: modo automático ativado");
        tocarSom(SOM_OK);
        // Aplicar automação imediatamente
        controleAutomaticoClima();
        
      } else if (comando == "power_on" || comando == "power") {
        flags.modoManualClima = true;
        if (!clima.ligado) {
          enviarComandoIR(IR_POWER);
          debugPrint("💨 Climatizador ligado via comando manual");
          
          // Aguardar estabilização após ligar
          delay(1500);
          
          // Se há velocidade especificada no comando, tentar ajustar
          if (doc.containsKey("velocidade")) {
            int velDesejada = doc["velocidade"];
            if (velDesejada >= 1 && velDesejada <= 3 && clima.ligado) {
              debugPrint("Ajustando para velocidade " + String(velDesejada) + " após ligar");
              int tentativas = 0;
              while (clima.velocidade != velDesejada && tentativas < 5) {
                if (enviarComandoIR(IR_VELOCIDADE)) {
                  tentativas++;
                  unsigned long t0 = millis();
                  while (controleIR.estado != IR_OCIOSO && millis() - t0 < TIMEOUT_CONFIRMACAO + 200) {
                    processarIRRecebido();
                    delay(10);
                  }
                } else {
                  break;
                }
              }
              atualizarLCD();
            }
          }
        }
        
      } else if (comando == "power_off") {
        flags.modoManualClima = true;
        if (clima.ligado) {
          enviarComandoIR(IR_POWER);
          debugPrint("💤 Climatizador desligado via comando manual");
        }
        
      } else if (comando == "velocidade") {
        flags.modoManualClima = true;
        if (clima.ligado) {
          // Verificar se há velocidade específica solicitada
          if (doc.containsKey("velocidade")) {
            int velDesejada = doc["velocidade"];
            if (velDesejada >= 1 && velDesejada <= 3) {
              debugPrint("⚙️ Ajustando para velocidade " + String(velDesejada) + " (atual: " + String(clima.velocidade) + ")");
              
              lcd.clear();
              lcd.setCursor(0, 0);
              lcd.write(5);
              lcd.print(" Manual Vel");
              lcd.setCursor(0, 1);
              lcd.print("Vel ");
              lcd.print(clima.velocidade);
              lcd.print(" -> ");
              lcd.print(velDesejada);
              tocarSom(SOM_COMANDO);
              delay(600);
              
              // Calcular quantos comandos são necessários (como no automático)
              int tentativas = 0;
              while (clima.velocidade != velDesejada && tentativas < 5) {
                if (enviarComandoIR(IR_VELOCIDADE)) {
                  tentativas++;
                  // Aguardar processamento do comando IR
                  unsigned long t0 = millis();
                  while (controleIR.estado != IR_OCIOSO && millis() - t0 < TIMEOUT_CONFIRMACAO + 200) {
                    processarIRRecebido();
                    delay(10);
                  }
                  delay(300); // Pausa extra para estabilidade
                } else {
                  break;
                }
              }
              
              atualizarLCD();
              debugPrint("✓ Velocidade ajustada para " + String(clima.velocidade));
            } else {
              debugPrint("⚠ Velocidade inválida: " + String(velDesejada) + " (deve ser 1-3)");
            }
          } else {
            // Se não especificou velocidade, apenas incrementa uma vez
            enviarComandoIR(IR_VELOCIDADE);
            debugPrint("⚙️ Velocidade incrementada via comando manual");
          }
        } else {
          debugPrint("⚠ Velocidade não pode ser alterada com climatizador desligado");
        }
        
      } else if (comando == "umidificar") {
        flags.modoManualClima = true;
        if (clima.ligado) {
          enviarComandoIR(IR_UMIDIFICAR);
          debugPrint("💧 Umidificação alterada via comando manual");
        } else {
          debugPrint("⚠ Umidificação não pode ser alterada com climatizador desligado");
        }
        
      } else if (comando == "timer") {
        flags.modoManualClima = true;
        if (clima.ligado) {
          enviarComandoIR(IR_TIMER);
          debugPrint("⏲️ Timer alterado via comando manual");
        } else {
          debugPrint("⚠ Timer não pode ser alterado com climatizador desligado");
        }
        
      } else if (comando == "aleta_v") {
        flags.modoManualClima = true;
        if (clima.ligado) {
          enviarComandoIR(IR_ALETA_VERTICAL);
          debugPrint("🔼 Aleta vertical alterada via comando manual");
        } else {
          debugPrint("⚠ Aleta vertical não pode ser alterada com climatizador desligado");
        }
        
      } else if (comando == "aleta_h") {
        flags.modoManualClima = true;
        if (clima.ligado) {
          enviarComandoIR(IR_ALETA_HORIZONTAL);
          debugPrint("↔️ Aleta horizontal alterada via comando manual");
        } else {
          debugPrint("⚠ Aleta horizontal não pode ser alterada com climatizador desligado");
        }
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

  // CORREÇÃO: Remover sincronização automática que causava modo manual indesejado
  // A sincronização agora acontece APENAS via comandos explícitos, não por leitura passiva do /climatizador
  // Isso evita que mudanças no Firebase (do servidor Dart) ativem modo manual acidentalmente
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
        
        // Verificar se é comando válido no contexto atual
        bool comandoPermitido = true;
        
        // Comandos de umidificação, velocidade, timer e aletas só funcionam com clima ligado
        if (!clima.ligado && (comando == IR_UMIDIFICAR || comando == IR_VELOCIDADE || 
            comando == IR_TIMER || comando == IR_ALETA_VERTICAL || comando == IR_ALETA_HORIZONTAL)) {
          comandoPermitido = false;
          debugPrint("⚠ Comando IR ignorado - climatizador desligado");
        }
        
        // Só ativa modo manual se houver pessoas presentes
        if (pessoas.total == 0 && comando != IR_POWER) {
          comandoPermitido = false;
          debugPrint("⚠ Comando IR ignorado - sem pessoas no ambiente");
        }
        
        if (comandoPermitido) {
          // Atualizar estado e exibir
          atualizarEstadoClima(comando);
          atualizarTelaClimatizador();
          
          if (pessoas.total > 0) {
            flags.modoManualClima = true;
            debugPrint("✓ Modo manual clima ATIVADO (controle físico)");
            tocarSom(SOM_COMANDO);
          }
        }
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

// === VERIFICAÇÃO PERIÓDICA DE PREFERÊNCIAS ===
void verificarAtualizacaoPreferencias() {
  unsigned long agora = millis();
  
  // Só verificar se houver pessoas, WiFi OK e não estiver em modo manual
  if (pessoas.total == 0 || !flags.wifiOk || flags.modoManualClima || flags.atualizandoPref) {
    return;
  }
  
  // Verificar a cada INTERVALO_PREF_CHECK (30 segundos)
  if (agora - ultimaVerificacaoPrefs < INTERVALO_PREF_CHECK) {
    return;
  }
  
  ultimaVerificacaoPrefs = agora;
  
  debugPrint("⏰ Verificação periódica de preferências iniciada...");
  
  // Forçar reconsulta de preferências para aplicar mudanças do banco de dados
  if (consultarPreferencias()) {
    debugPrint("✓ Preferências atualizadas com sucesso (verificação periódica)");
    
    // Se não estiver em modo manual, aplicar ajustes imediatamente
    if (!flags.modoManualIlum && pessoas.total > 0 && flags.ilumAtiva) {
      int nivelDesejado = pessoas.lumPref;
      if (nivelDesejado == 0) nivelDesejado = 25;
      
      if (sensores.luminosidade != nivelDesejado) {
        debugPrint("🔆 Ajustando iluminação para nova preferência: " + String(nivelDesejado) + "%");
        configurarRele(nivelDesejado);
        atualizarLCD();
      }
    }
    
    // Aplicar ajustes ao climatizador se necessário
    if (!flags.modoManualClima && pessoas.total > 0) {
      float tempAlvo = pessoas.tempPref;
      float diff = sensores.temperatura - tempAlvo;
      
      // Calcular velocidade desejada
      int velDesejada = 1;
      if (diff >= 4.5) velDesejada = 3;
      else if (diff >= 3.0) velDesejada = 2;
      
      // Se precisa ligar/desligar
      if (diff >= 2.0 && !clima.ligado) {
        debugPrint("❄️ Ligando climatizador após atualização de preferência");
        enviarComandoIR(IR_POWER);
        delay(1500);
        
        // Ajustar velocidade se necessário
        if (clima.ligado && clima.velocidade != velDesejada) {
          int tentativas = 0;
          while (clima.velocidade != velDesejada && tentativas < 5) {
            if (enviarComandoIR(IR_VELOCIDADE)) {
              tentativas++;
              delay(800);
            } else {
              break;
            }
          }
        }
        atualizarLCD();
      } else if (diff <= -0.5 && clima.ligado) {
        debugPrint("🔥 Desligando climatizador após atualização de preferência");
        enviarComandoIR(IR_POWER);
        atualizarLCD();
      } else if (clima.ligado && clima.velocidade != velDesejada) {
        debugPrint("⚙️ Ajustando velocidade para nova preferência: " + String(velDesejada));
        int tentativas = 0;
        while (clima.velocidade != velDesejada && tentativas < 5) {
          if (enviarComandoIR(IR_VELOCIDADE)) {
            tentativas++;
            delay(800);
          } else {
            break;
          }
        }
        atualizarLCD();
      }
    }
  } else {
    debugPrint("⚠ Falha na verificação periódica de preferências");
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

  // Carregar último estado do climatizador do Firebase
  if (flags.wifiOk) {
    debugPrint("Carregando estado do climatizador do Firebase...");
    String estadoJson = lerDadosFirebase("/climatizador");
    if (estadoJson.length() > 0 && estadoJson != "null") {
      StaticJsonDocument<200> doc;
      DeserializationError error = deserializeJson(doc, estadoJson);
      if (!error) {
        // Restaurar TODAS as configurações preservadas pelo aparelho físico
        if (doc.containsKey("ultima_velocidade")) {
          clima.ultimaVel = doc["ultima_velocidade"];
        }
        if (doc.containsKey("umidificando")) {
          clima.umidificando = doc["umidificando"];
        }
        if (doc.containsKey("aleta_vertical")) {
          clima.aletaV = doc["aleta_vertical"];
        }
        if (doc.containsKey("aleta_horizontal")) {
          clima.aletaH = doc["aleta_horizontal"];
        }
        debugPrint("✓ Configurações restauradas do Firebase:");
        debugPrint("  - Velocidade: " + String(clima.ultimaVel));
        debugPrint("  - Umidificação: " + String(clima.umidificando ? "ON" : "OFF"));
        debugPrint("  - Aleta V: " + String(clima.aletaV ? "ON" : "OFF"));
        debugPrint("  - Aleta H: " + String(clima.aletaH ? "ON" : "OFF"));
      }
    }
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
  debugPrint("✓ Configurações do Climatizador Preservadas:");
  debugPrint("  - Velocidade: " + String(clima.ultimaVel));
  debugPrint("  - Umidificação: " + String(clima.umidificando ? "ON" : "OFF"));
  debugPrint("  - Aleta V: " + String(clima.aletaV ? "ON" : "OFF"));
  debugPrint("  - Aleta H: " + String(clima.aletaH ? "ON" : "OFF"));
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

  // NOVO: Verificar se há necessidade de atualizar preferências periodicamente
  verificarAtualizacaoPreferencias();

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