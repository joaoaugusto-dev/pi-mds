// Inclusão das bibliotecas necessárias para o projeto.
// Cada uma delas adiciona funcionalidades específicas:
#include <WiFi.h>               // Para conectar o ESP32 à rede Wi-Fi.
#include <HTTPClient.h>         // Para fazer requisições HTTP (enviar e receber dados do servidor).
#include <SPI.h>                // Para comunicação com periféricos que usam o protocolo SPI (como o leitor RFID).
#include <MFRC522.h>            // Para interagir com o leitor RFID MFRC522 (ler tags).
#include <ArduinoJson.h>        // Para manipular dados no formato JSON (comum em APIs web).
#include <DHT.h>                // Para ler dados do sensor de temperatura e umidade DHT.
#include <LiquidCrystal_I2C.h>  // Para controlar o display LCD via interface I2C (usa menos fios).
#include <IRremote.hpp>         // Para enviar e receber sinais infravermelhos (controlar o climatizador).

// === PINOS E CONSTANTES ===
// Aqui definimos os "endereços" dos componentes conectados ao ESP32 e valores fixos.
#define BUZZER_PIN 12           // Pino digital conectado ao Buzzer (para feedback sonoro).
#define RELE_1 14               // Pino para o Relé 1 (controla uma parte da iluminação).
#define RELE_2 26               // Pino para o Relé 2.
#define RELE_3 27               // Pino para o Relé 3.
#define RELE_4 25               // Pino para o Relé 4.
#define SS_PIN 5                // Pino "Slave Select" para o leitor RFID (comunicação SPI).
#define RST_PIN 15              // Pino de Reset para o leitor RFID.
#define DHT_PIN 4               // Pino de dados do sensor de temperatura e umidade DHT22.
#define DHTTYPE DHT22           // Define o tipo do sensor DHT (DHT22 neste caso).
#define LDR_PIN 35              // Pino analógico conectado ao LDR (sensor de luminosidade).
#define IR_SEND_PIN 33          // Pino para enviar sinais infravermelhos (para o climatizador).
#define IR_RECEIVE_PIN 32       // Pino para receber sinais infravermelhos (do controle remoto).

// === COMANDOS IR OTIMIZADOS ===
// Códigos específicos para cada função do controle remoto do climatizador.
// Estes valores foram "capturados" do controle original.
#define IR_PROTOCOLO NEC          // Protocolo de comunicação IR usado pelo climatizador (NEC é comum).
#define IR_ENDERECO 0xFC00        // Endereço único do dispositivo climatizador na comunicação IR.
#define IR_POWER 0x85             // Código IR para ligar/desligar.
#define IR_UMIDIFICAR 0x87        // Código IR para a função umidificar.
#define IR_VELOCIDADE 0x84        // Código IR para alterar a velocidade.
#define IR_TIMER 0x86             // Código IR para configurar o timer.
#define IR_ALETA_VERTICAL 0x83    // Código IR para mover a aleta vertical.
#define IR_ALETA_HORIZONTAL 0x82  // Código IR para mover a aleta horizontal.

// === CONSTANTES DE CONTROLE IR ===
// Parâmetros para o envio e recebimento de IR, como tempos de espera para evitar leituras duplicadas.
#define DEBOUNCE_ENVIAR 300      // Tempo mínimo (ms) entre envios de comandos IR para evitar sobrecarga.
#define DEBOUNCE_RECEBER 500     // Tempo mínimo (ms) para processar um novo comando IR recebido.
#define JANELA_ECO 100           // Pequena janela (ms) após enviar um comando para ignorar o "eco" do próprio sinal.
#define TIMEOUT_CONFIRMACAO 500  // Tempo máximo (ms) para esperar uma confirmação (se aplicável).

// === DEBUG ATIVADO PARA DEPURAÇÃO ===
#define DEBUG_SERIAL 1  // Uma chave (1=ligado, 0=desligado) para imprimir mensagens de depuração no Serial Monitor.

// === OBJETOS GLOBAIS ===
// Criamos instâncias das classes das bibliotecas para usar seus recursos.
MFRC522 mfrc522(SS_PIN, RST_PIN);   // Objeto para controlar o leitor RFID, indicando os pinos SS e RST.
DHT dht(DHT_PIN, DHTTYPE);          // Objeto para o sensor DHT, indicando o pino e o tipo.
LiquidCrystal_I2C lcd(0x27, 16, 2); // Objeto para o display LCD (endereço I2C 0x27, 16 colunas, 2 linhas).

// === ESTRUTURAS OTIMIZADAS PARA MEMÓRIA ===
// "structs" são como caixinhas para agrupar variáveis relacionadas.
// Usar bitfields (ex: `: 1`) economiza memória, guardando booleanos em 1 bit.

// Guarda todas as leituras dos sensores em um lugar só. Facilita passar os dados.
struct DadosSensores {
  float temperatura = 0;      // Temperatura em Celsius.
  float humidade = 0;         // Umidade relativa do ar em %.
  int luminosidade = 0;       // Nível de iluminação artificial (0-100%).
  int valorLDR = 0;           // Leitura "crua" do LDR (quanto menor, mais escuro).
  bool dadosValidos = false;  // Indica se a última leitura dos sensores foi bem-sucedida.
} sensores;

// Guarda o estado atual do climatizador. Otimizado com bitfields.
struct {
  bool ligado : 1;            // O climatizador está ligado? (1 bit)
  bool umidificando : 1;      // Função umidificar está ativa? (1 bit)
  bool aletaV : 1;            // Aleta vertical está oscilando? (1 bit)
  bool aletaH : 1;            // Aleta horizontal está oscilando? (1 bit)
  uint8_t velocidade : 2;     // Velocidade (0-3, usa 2 bits).
  uint8_t ultimaVel : 2;      // Guarda a última velocidade usada (manual ou auto).
  uint8_t timer : 3;          // Configuração do timer (0-7, usa 3 bits).
  uint8_t reservado : 5;      // Bits reservados para futuras expansões.
  unsigned long ultimaAtualizacao; // Quando o estado do clima foi atualizado pela última vez.
} clima;

// Controla quem está na sala (tags RFID), total de pessoas e suas preferências.
struct {
  int total = 0;              // Número atual de pessoas na sala.
  String tags[10];            // Armazena os IDs das últimas 10 tags lidas.
  bool estado[10];            // Para cada tag no histórico, indica se a pessoa está presente (true) ou saiu (false).
  int count = 0;              // Número de tags distintas já registradas no histórico.
  float tempPref = 25.0;      // Temperatura preferida pelo grupo (média vinda do servidor).
  int lumPref = 50;           // Luminosidade preferida pelo grupo (média vinda do servidor).
  bool prefsAtualizadas = false; // As preferências do grupo atual já foram consultadas e aplicadas?
} pessoas;

// Conjunto de "bandeirinhas" (booleanos) para controlar o estado do sistema.
// Também usa bitfields para economizar memória.
struct {
  bool modoManualIlum : 1;    // Iluminação está em modo manual (controlada pelo app)?
  bool modoManualClima : 1;   // Climatizador está em modo manual (controlado pelo app ou IR)?
  bool ilumAtiva : 1;         // As luzes estão atualmente acesas (automaticamente)?
  bool monitorandoLDR : 1;    // O sistema deve considerar o LDR para ligar luzes?
  bool irPausa : 1;           // Pausa temporária no processamento IR (evitar loops). (Não parece ser usado ativamente)
  bool comandoIR : 1;         // Um comando IR foi recentemente processado? (Não parece ser usado ativamente)
  bool comandoApp : 1;        // Um comando do app foi recentemente processado? (Não parece ser usado ativamente)
  bool wifiOk : 1;            // A conexão Wi-Fi está ativa?
  bool erroSensor : 1;        // Houve erro na última leitura do sensor DHT?
  bool erroConexao : 1;       // Houve erro na última comunicação com o servidor?
  bool debug : 1;             // Modo de depuração especial ativo? (Não parece ser usado ativamente)
  bool atualizandoPref : 1;   // O sistema está no meio de uma consulta de preferências ao servidor?
} flags = { false, false, false, true, false, false, false, false, false, false, false, false }; // Valores iniciais

// === MÁQUINA DE ESTADOS IR ===
// Define os possíveis estados da lógica de envio IR. Ajuda a controlar o fluxo.
enum EstadoIR {
  IR_OCIOSO,                 // Aguardando um comando para enviar.
  IR_ENVIANDO,               // Enviando um comando IR no momento.
  IR_AGUARDANDO_CONFIRMACAO  // Enviou e está esperando uma "resposta" (eco ou outro sinal).
};

// === ESTRUTURA DE CONTROLE IR ===
// Gerencia o processo de envio de comandos IR.
struct {
  EstadoIR estado = IR_OCIOSO;     // Estado atual da máquina de estados IR.
  uint8_t comandoPendente = 0;     // Qual comando IR está sendo processado.
  unsigned long inicioEnvio = 0;   // Quando o envio do comando começou.
  bool comandoConfirmado = false;  // O comando enviado foi confirmado (pelo eco, por exemplo)?
} controleIR;

// === INTERVALOS OTIMIZADOS ===
// Define com que frequência certas tarefas devem ser executadas (em milissegundos).
// Evita rodar tudo o tempo todo, economizando processamento.
const unsigned long INTERVALO_DHT = 5000;         // Ler sensores a cada 5 segundos.
const unsigned long INTERVALO_DADOS = 5000;       // Enviar dados ao servidor a cada 5 segundos.
const unsigned long INTERVALO_MANUAL = 1500;      // (Não parece ser usado ativamente com este nome)
const unsigned long INTERVALO_LDR = 5000;         // Verificar luminosidade para controle automático a cada 5 segundos.
const unsigned long INTERVALO_CLIMA_AUTO = 5000;  // Verificar controle automático do clima a cada 5 segundos.
const unsigned long INTERVALO_COMANDOS = 3000;    // Verificar comandos do servidor a cada 3 segundos.
const unsigned long INTERVALO_DEBUG = 5000;       // Mostrar tela de debug a cada 5 segundos (se ativa).
const unsigned long INTERVALO_PREF_CHECK = 30000; // Verificar se precisa atualizar preferências a cada 30 segundos.

// Timestamps otimizados: um array para guardar os "últimos momentos" que cada tarefa rodou.
unsigned long tempos[8] = { 0 }; // Cada índice corresponde a uma tarefa (0=DHT, 1=Dados, etc.)

// Limiar do LDR: abaixo deste valor, considera-se "escuro" o suficiente para ligar as luzes.
#define LIMIAR_LDR_ESCURIDAO 400

// === CONFIGURAÇÃO DE REDE ===
const char* ssid = "esp32"; // Nome da rede Wi-Fi.
const char* password = "123654123"; // Senha da rede Wi-Fi.
const char* serverUrl = "http://192.168.31.43:3000/esp32/"; // Endereço base do servidor.

// === CARACTERES PERSONALIZADOS PARA LCD ===
// Define desenhos customizados para ícones no LCD. Cada array de 8 bytes forma um caractere 5x8 pixels.
uint8_t SIMBOLO_PESSOA[8] = { 0x0E, 0x0E, 0x04, 0x1F, 0x04, 0x0A, 0x0A, 0x00 }; // Ícone de Pessoa
uint8_t SIMBOLO_TEMP[8] = { 0x04, 0x0A, 0x0A, 0x0A, 0x0A, 0x11, 0x1F, 0x0E };   // Ícone de Termômetro
uint8_t SIMBOLO_HUM[8] = { 0x04, 0x04, 0x0A, 0x0A, 0x11, 0x11, 0x11, 0x0E };    // Ícone de Gota (Umidade)
uint8_t SIMBOLO_LUZ[8] = { 0x00, 0x0A, 0x0A, 0x1F, 0x1F, 0x0E, 0x04, 0x00 };    // Ícone de Lâmpada
uint8_t SIMBOLO_WIFI[8] = { 0x00, 0x0F, 0x11, 0x0E, 0x04, 0x00, 0x04, 0x00 };   // Ícone de WiFi
uint8_t SIMBOLO_AR[8] = { 0x00, 0x0E, 0x15, 0x15, 0x15, 0x0E, 0x00, 0x00 };     // Ícone de Climatizador/Ar
uint8_t SIMBOLO_OK[8] = { 0x00, 0x01, 0x02, 0x14, 0x08, 0x04, 0x02, 0x00 };     // Ícone de Check (OK)
uint8_t SIMBOLO_ERRO[8] = { 0x00, 0x11, 0x0A, 0x04, 0x04, 0x0A, 0x11, 0x00 };   // Ícone de X (Erro)

// Enum para os sons do buzzer: cria nomes amigáveis para diferentes tipos de sons.
enum SomBuzzer : uint8_t { // `: uint8_t` especifica que usará apenas 1 byte, economizando memória.
  SOM_NENHUM = 0,
  SOM_INICIAR,        // Som ao ligar o sistema.
  SOM_PESSOA_ENTROU,  // Som quando uma pessoa entra.
  SOM_PESSOA_SAIU,    // Som quando uma pessoa sai.
  SOM_COMANDO,        // Som para confirmar um comando (luz ligou, etc.).
  SOM_ALERTA,         // Som de alerta genérico.
  SOM_ERRO,           // Som para indicar um erro.
  SOM_CONECTADO,      // Som quando o Wi-Fi conecta.
  SOM_DESCONECTADO,   // Som quando o Wi-Fi desconecta.
  SOM_OK              // Som para indicar recuperação de um erro.
};

// === FUNÇÕES PARA DEBUG ===
// Funções auxiliares para ajudar a encontrar problemas durante o desenvolvimento.

// Imprime uma mensagem no Serial Monitor, mas apenas se DEBUG_SERIAL estiver ativado.
void debugPrint(const String& msg) {
#if DEBUG_SERIAL // Compila este bloco apenas se DEBUG_SERIAL for 1
  Serial.println(msg);
#endif
}

// Mostra um resumo completo do estado atual do sistema no Serial Monitor.
// Útil para acompanhar o que está acontecendo internamente.
void mostrarTelaDebug() {
#if DEBUG_SERIAL
  unsigned long agora = millis();
  static unsigned long ultimoDebug = 0; // Guarda quando foi a última vez que mostrou o debug.

  if (agora - ultimoDebug < INTERVALO_DEBUG) return; // Só mostra a cada X segundos.
  ultimoDebug = agora;

  // Imprime várias informações úteis:
  debugPrint("\n--- STATUS DO SISTEMA ---");
  debugPrint("Temperatura: " + String(sensores.temperatura) + "°C");
  debugPrint("Umidade: " + String(sensores.humidade) + "%");
  debugPrint("LDR valor: " + String(sensores.valorLDR));
  debugPrint("Luminosidade: " + String(sensores.luminosidade) + "%");
  debugPrint("Pessoas: " + String(pessoas.total) + " (Tags Hist: " + String(pessoas.count) + ")");
  debugPrint("Temp. Preferida: " + String(pessoas.tempPref) + "°C");
  debugPrint("Lum. Preferida: " + String(pessoas.lumPref) + "%");
  debugPrint("Prefs Atualizadas: " + String(pessoas.prefsAtualizadas ? "SIM" : "NAO"));
  debugPrint("Diff Temp: " + String(sensores.temperatura - pessoas.tempPref) + "°C");
  
  if (pessoas.total > 0) {
    debugPrint("--- TAGS PRESENTES ---");
    for (int i = 0; i < pessoas.count; i++) {
      if (pessoas.estado[i]) {
        debugPrint("Tag " + String(i) + ": " + pessoas.tags[i] + " (PRESENTE)");
      }
    }
    debugPrint("Última consulta prefs: " + String(millis() - tempos[5]) + "ms atrás"); // tempos[5] é para INTERVALO_PREF_CHECK
  }

  debugPrint("\n--- FLAGS ---");
  // Mostra o estado das "bandeirinhas" de controle.
  debugPrint("modoManualIlum: " + String(flags.modoManualIlum ? "SIM" : "NAO"));
  debugPrint("modoManualClima: " + String(flags.modoManualClima ? "SIM" : "NAO"));
  debugPrint("ilumAtiva: " + String(flags.ilumAtiva ? "SIM" : "NAO"));
  debugPrint("monitorandoLDR: " + String(flags.monitorandoLDR ? "SIM" : "NAO"));
  debugPrint("atualizandoPref: " + String(flags.atualizandoPref ? "SIM" : "NAO"));
  debugPrint("prefsAtualizadas: " + String(pessoas.prefsAtualizadas ? "SIM" : "NAO")); // Repetido, mas útil aqui.
  debugPrint("erroSensor: " + String(flags.erroSensor ? "SIM" : "NAO"));
  debugPrint("erroConexao: " + String(flags.erroConexao ? "SIM" : "NAO"));

  debugPrint("\n--- CLIMA ---");
  // Mostra o estado do climatizador.
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
// Funções para dar retorno ao usuário, seja por som ou pelo LCD.

// Faz o buzzer tocar diferentes "musiquinhas" curtas para eventos específicos.
void tocarSom(SomBuzzer tipo) {
  // Tabela de sons: {frequência base, duração, pausa, repetições}
  // Os valores são multiplicados para obter os valores reais.
  static const uint8_t SONS[][4] = {
    { 0, 0, 0, 0 },    // SOM_NENHUM - não faz nada
    { 20, 10, 5, 3 },  // SOM_INICIAR (ex: 2000Hz, 100ms, pausa 50ms, 3x)
    { 25, 5, 0, 1 },   // SOM_PESSOA_ENTROU
    { 15, 5, 0, 1 },   // SOM_PESSOA_SAIU
    { 30, 2, 2, 1 },   // SOM_COMANDO
    { 40, 3, 3, 3 },   // SOM_ALERTA
    { 10, 15, 5, 2 },  // SOM_ERRO
    { 35, 3, 2, 2 },   // SOM_CONECTADO
    { 15, 10, 5, 1 },  // SOM_DESCONECTADO
    { 45, 2, 1, 2 }    // SOM_OK
  };

  if (tipo == SOM_NENHUM) return; // Se for SOM_NENHUM, não faz nada.

  const uint8_t* som = SONS[tipo]; // Pega os parâmetros do som escolhido.
  int freq = som[0] * 100;         // Frequência em Hz.
  int duracao = som[1] * 10;       // Duração do som em ms.
  int pausa = som[2] * 10;         // Pausa entre repetições em ms.
  int repeticoes = som[3];         // Quantas vezes o som repete.

  for (int r = 0; r < repeticoes; r++) {
    int freqAtual = freq;
    if (tipo == SOM_INICIAR) { // Som especial de iniciar, aumenta a frequência a cada repetição.
      freqAtual += r * 200;
    }

    if (freqAtual > 0) { // Só tenta tocar se a frequência for válida.
      // Toca o som "manualmente" ligando e desligando o pino do buzzer.
      // Isso dá mais controle sobre a frequência do que a função `tone()`.
      int periodo = 1000000 / freqAtual; // Período da onda sonora em microssegundos.
      unsigned long inicio = millis();

      while (millis() - inicio < duracao) {
        digitalWrite(BUZZER_PIN, HIGH);
        delayMicroseconds(periodo / 2);
        digitalWrite(BUZZER_PIN, LOW);
        delayMicroseconds(periodo / 2);
      }
    }
    delay(pausa); // Pausa entre as repetições.
  }
}

// Mostra uma mensagem de erro específica no LCD.
void mostrarErroLCD(const char* erro, bool critico = false) {
  // `PROGMEM` guarda a string na memória flash, economizando RAM.
  static const char MSG_ERRO[] PROGMEM = "ERRO:";

  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.write(7); // Mostra o caractere customizado de ERRO (X).
  lcd.print(' ');
  lcd.print(MSG_ERRO); // Mostra "ERRO:"
  lcd.setCursor(0, 1);
  lcd.print(erro); // Mostra a mensagem de erro específica.

  if (critico) {
    tocarSom(SOM_ERRO); // Som de erro mais grave.
  } else {
    tocarSom(SOM_ALERTA); // Som de alerta.
  }
  delay(600); // Mostra a mensagem por um tempo.
  
  // Volta para a tela principal se houver pessoas.
  if (pessoas.total > 0) {
    atualizarLCD();
  }
}

// Uma pequena animação visual de transição no LCD.
void animacaoTransicao() {
  // Padrão para animação (não usado atualmente no código principal, mas pode ser útil).
  // static const uint8_t PADRAO[] = { 0, 1, 3, 7, 15, 14, 12, 8, 0 };

  for (int i = 0; i < 8; i++) { // Faz setas se moverem nas bordas do LCD.
    lcd.clear();
    lcd.setCursor(i, 0);
    lcd.print(">");
    lcd.setCursor(15 - i, 1);
    lcd.print("<");
    delay(30);
  }
  lcd.clear();
}

// Função principal para mostrar as informações mais importantes no LCD.
// É chamada frequentemente para manter o display atualizado.
void atualizarLCD() {
  // Se tem gente na sala, a luz de fundo do LCD fica acesa.
  if (pessoas.total > 0) {
    lcd.backlight();
  } else {
    // Se não tem ninguém, mostra "Sistema Inativo" e apaga a luz de fundo.
    lcd.setCursor(0, 0);
    lcd.print("Sistema Inativo");
    lcd.setCursor(0, 1);
    lcd.print("Passe o cartao");
    lcd.noBacklight(); // Apaga a luz de fundo para economizar energia.
    return; // Sai da função, não precisa mostrar mais nada.
  }

  // Otimização: só atualiza o LCD se algo mudou, para evitar "piscar".
  static uint32_t hashAnterior = 0;       // "Impressão digital" da tela anterior.
  static unsigned long ultimaAtualizacao = 0; // Quando foi a última atualização.
  unsigned long agora = millis();

  // Limita a frequência de atualização (ex: no máximo a cada 200ms).
  if (agora - ultimaAtualizacao < 200) return;

  // Cria um "hash" (um número único) com os dados atuais.
  // Se o hash for igual ao anterior, nada mudou, não precisa redesenhar.
  uint32_t hash = (uint32_t)(sensores.temperatura * 10) + 
                  (uint32_t)(sensores.humidade) * 1000 + 
                  sensores.luminosidade * 10000 + 
                  pessoas.total * 100000 + 
                  (clima.ligado ? 1000000 : 0) + 
                  (flags.wifiOk ? 2000000 : 0) + 
                  (flags.erroSensor ? 4000000 : 0) + 
                  (flags.modoManualIlum ? 8000000 : 0) + 
                  (flags.modoManualClima ? 16000000 : 0);

  if (hash == hashAnterior) return; // Nada mudou, sai.
  hashAnterior = hash;             // Guarda o novo hash.
  ultimaAtualizacao = agora;       // Marca o tempo da atualização.

  lcd.clear(); // Limpa o LCD para desenhar as novas informações.

  // Se algum modo manual (luz ou clima) estiver ativo, mostra uma tela diferente.
  if (flags.modoManualIlum || flags.modoManualClima) {
    lcd.setCursor(0, 0);
    lcd.write(1); // Ícone de termômetro.
    lcd.print(sensores.temperatura, 1); // Temperatura com 1 casa decimal.
    lcd.write(0xDF); // Símbolo de grau Celsius.
    lcd.print("C ");

    lcd.write(2); // Ícone de umidade.
    lcd.print(sensores.humidade, 0); // Umidade sem casas decimais.
    lcd.print("%");

    lcd.setCursor(0, 1);
    lcd.print("Manual Mode "); // Indica modo manual.
    lcd.write(0); // Ícone de pessoa.
    lcd.print(pessoas.total); // Número de pessoas.

    lcd.setCursor(15, 1); // Canto inferior direito.
    lcd.write(flags.wifiOk ? 4 : 7); // Ícone de WiFi (OK ou Erro).
  } else {
    // Tela padrão (modo automático).
    lcd.setCursor(0, 0);
    lcd.write(1); // Ícone de termômetro.
    lcd.print(sensores.temperatura, 1);
    lcd.write(0xDF);
    lcd.print("C ");

    lcd.write(2); // Ícone de umidade.
    lcd.print(sensores.humidade, 0);
    lcd.print("%");

    lcd.setCursor(0, 1);
    lcd.write(3); // Ícone de lâmpada.
    lcd.print(sensores.luminosidade); // Nível de iluminação artificial.
    lcd.print("% ");

    lcd.write(0); // Ícone de pessoa.
    lcd.print(pessoas.total);
    lcd.print(" ");

    lcd.write(5); // Ícone de climatizador.
    lcd.print(clima.ligado ? "L" : "-"); // "L" se ligado, "-" se desligado.

    lcd.setCursor(15, 1); // Canto inferior direito.
    lcd.write(flags.wifiOk ? 4 : 7); // Ícone de WiFi (OK ou Erro).
  }
}

// Mostra uma tela temporária no LCD com o estado atual do climatizador.
// Usado quando um comando IR é enviado ou recebido.
void atualizarTelaClimatizador() {
  static uint8_t estadoAnterior = 0; // Guarda o estado da tela anterior para saber se precisa atualizar.
  static unsigned long tempoExibicao = 0; // Controla por quanto tempo a tela fica visível.

  // Cria um "byte de estado" para comparar facilmente se algo mudou no climatizador.
  uint8_t estadoAtual = (clima.ligado << 0) | 
                        (clima.umidificando << 1) | 
                        (clima.velocidade << 2) | 
                        (clima.timer << 4) | 
                        (clima.aletaV << 7); // Inclui aletaV para diferenciação.

  if (estadoAtual != estadoAnterior) { // Só atualiza se o estado do clima mudou.
    estadoAnterior = estadoAtual;
    tempoExibicao = millis(); // Marca quando a tela começou a ser exibida.
    
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.write(5); // Ícone de climatizador.
    lcd.print(" Climatizador");

    lcd.setCursor(0, 1);
    if (!clima.ligado) {
      lcd.print("Desligado");
    } else {
      // Monta uma string compacta com o estado do climatizador.
      char buffer[17]; // Espaço para a string.
      uint8_t pos = 0; // Posição atual no buffer.

      buffer[pos++] = 'V'; // Velocidade
      buffer[pos++] = '0' + clima.velocidade; // Converte número para char.
      buffer[pos++] = ' ';

      if (clima.timer > 0) { // Se o timer estiver ativo.
        buffer[pos++] = 'T'; // Timer
        buffer[pos++] = '0' + clima.timer;
        buffer[pos++] = ' ';
      }

      if (clima.umidificando) { // Se estiver umidificando.
        buffer[pos++] = 'U';
        buffer[pos++] = 'M'; // Umidificar
        buffer[pos++] = ' ';
      }

      if (clima.aletaV || clima.aletaH) { // Se alguma aleta estiver ativa.
        buffer[pos++] = 'A'; // Aleta
        if (clima.aletaV) buffer[pos++] = 'V'; // Vertical
        if (clima.aletaH) buffer[pos++] = 'H'; // Horizontal
      }

      buffer[pos] = '\0'; // Finaliza a string.
      lcd.print(buffer); // Mostra no LCD.
    }
  }
  
  // Volta para a tela principal automaticamente após 1.5 segundos, sem bloquear o código.
  if (millis() - tempoExibicao > 1500) {
    atualizarLCD(); // Chama a função que desenha a tela principal.
  }
}

// === FUNÇÃO DE CONSULTA DE PREFERÊNCIAS OTIMIZADA ===
// Esta função é crucial! Envia as tags das pessoas presentes para o servidor
// e recebe de volta as preferências médias de temperatura e luminosidade para o grupo.
bool consultarPreferencias() {
  // Só executa se houver pessoas na sala, o Wi-Fi estiver OK e não estiver já atualizando.
  if (pessoas.total == 0 || !flags.wifiOk || flags.atualizandoPref) {
    debugPrint("consultarPreferencias: Condições não atendidas (Pessoas=" + String(pessoas.total) + 
               ", WiFi=" + String(flags.wifiOk) + ", Atualizando=" + String(flags.atualizandoPref) + ")");
    return false; // Não pode consultar agora.
  }

  flags.atualizandoPref = true; // Sinaliza que uma consulta está em andamento.

  StaticJsonDocument<256> doc; // Cria um documento JSON para enviar (tamanho máximo 256 bytes).
  JsonArray tagsArray = doc.createNestedArray("tags"); // Cria um array JSON chamado "tags".

  int tagsAtivas = 0;
  for (int i = 0; i < pessoas.count; i++) { // Percorre o histórico de tags.
    if (pessoas.estado[i]) { // Se a pessoa da tag[i] está presente.
      tagsArray.add(pessoas.tags[i]); // Adiciona o ID da tag ao array JSON.
      tagsAtivas++;
    }
  }

  if (tagsAtivas == 0) { // Se, por algum motivo, não houver tags ativas para enviar.
    flags.atualizandoPref = false;
    debugPrint("consultarPreferencias: Nenhuma tag ativa para consultar.");
    return false;
  }

  String jsonTags;
  serializeJson(doc, jsonTags); // Converte o documento JSON para uma String.
  debugPrint("Consultando preferências para " + String(tagsAtivas) + " tags");
  debugPrint("JSON enviado: " + jsonTags);

  HTTPClient http; // Objeto para fazer a requisição HTTP.
  String fullUrl = String(serverUrl) + "preferencias"; // URL completa do endpoint no servidor.
  http.begin(fullUrl); // Inicia a conexão.
  http.addHeader("Content-Type", "application/json"); // Informa que o corpo da requisição é JSON.
  http.setTimeout(5000); // Define um tempo máximo de espera pela resposta (5 segundos).
  
  int httpCode = http.POST(jsonTags); // Envia a requisição POST com o JSON das tags.
  bool sucesso = false; // Para rastrear se a consulta foi bem-sucedida.

  debugPrint("HTTP Code para preferencias: " + String(httpCode)); // Mostra o código de status HTTP.

  if (httpCode == HTTP_CODE_OK) { // Se o servidor respondeu com "OK" (200).
    String payload = http.getString(); // Pega a resposta do servidor.
    debugPrint("Resposta do servidor para preferencias: " + payload);

    StaticJsonDocument<256> respDoc; // Documento JSON para parsear a resposta.
    DeserializationError error = deserializeJson(respDoc, payload); // Tenta converter a String para JSON.

    if (!error) { // Se não houve erro ao parsear o JSON.
      // Aplica as preferências recebidas do servidor.
      if (respDoc.containsKey("temperatura")) { // Verifica se o servidor enviou "temperatura".
        float tempPref = respDoc["temperatura"];
        debugPrint("Temperatura preferida calculada pelo servidor: " + String(tempPref));

        // Validação básica da temperatura recebida.
        if (!isnan(tempPref) && tempPref >= 16.0 && tempPref <= 32.0) {
          pessoas.tempPref = tempPref;
          debugPrint("✓ Temperatura preferida aplicada: " + String(pessoas.tempPref) + "°C");
        } else {
          debugPrint("⚠ Temperatura inválida, usando padrão 25°C");
          pessoas.tempPref = 25.0; // Valor padrão se inválido.
        }
      } else {
        debugPrint("⚠ Temperatura não encontrada na resposta, usando padrão 25°C");
        pessoas.tempPref = 25.0;
      }

      if (respDoc.containsKey("luminosidade")) { // Verifica se o servidor enviou "luminosidade".
        int lumPref = respDoc["luminosidade"];
        debugPrint("Luminosidade preferida calculada pelo servidor: " + String(lumPref));

        // Validação básica da luminosidade (múltiplo de 25, entre 0 e 100).
        if (lumPref >= 0 && lumPref <= 100 && (lumPref % 25 == 0)) {
          pessoas.lumPref = lumPref;
          debugPrint("✓ Luminosidade preferida aplicada: " + String(pessoas.lumPref) + "%");
        } else {
          debugPrint("⚠ Luminosidade inválida (" + String(lumPref) + "), usando padrão 50%");
          pessoas.lumPref = 50; // Valor padrão se inválido.
        }
      } else {
        debugPrint("⚠ Luminosidade não encontrada na resposta, usando padrão 50%");
        pessoas.lumPref = 50;
      }

      sucesso = true; // A consulta e aplicação foram bem-sucedidas.
      pessoas.prefsAtualizadas = true; // Marca que as preferências estão atualizadas.
      
      debugPrint("=== PREFERÊNCIAS FINAIS APLICADAS ===");
      debugPrint("Temperatura: " + String(pessoas.tempPref) + "°C");
      debugPrint("Luminosidade: " + String(pessoas.lumPref) + "%");
      debugPrint("===================================");
    } else {
      debugPrint("Erro ao parsear JSON da resposta de preferencias: " + String(error.c_str()));
      mostrarErroLCD("Erro JSON Pref", false); // Mostra erro no LCD.
    }
  } else {
    debugPrint("Erro na requisição HTTP para preferencias: " + String(httpCode));
    mostrarErroLCD("Erro API Pref", false); // Mostra erro no LCD.
  }

  http.end(); // Finaliza a conexão HTTP.
  flags.atualizandoPref = false; // Libera para futuras consultas.
  return sucesso;
}

// === FUNÇÕES PRINCIPAIS ===
// O "coração" da lógica do sistema.

// Controla os relés para ligar/desligar as luzes em diferentes níveis (0%, 25%, 50%, 75%, 100%).
void configurarRele(int nivel) {
  static int nivelAnterior = -1; // Guarda o nível anterior para evitar reconfigurar sem necessidade.
  if (nivel == nivelAnterior) return; // Se o nível é o mesmo, não faz nada.

  nivel = (nivel / 25) * 25; // Garante que o nível seja múltiplo de 25.
  if (nivel > 100) nivel = 100; // Limita a 100%.

  // Tabela de estados dos relés para cada nível de luminosidade.
  // LOW = Relé LIGADO (passando corrente), HIGH = Relé DESLIGADO.
  const bool estados[5][4] = {
    { HIGH, HIGH, HIGH, HIGH },  // 0%   - Todos desligados
    { LOW,  HIGH, HIGH, HIGH },  // 25%  - R1 ligado
    { LOW,  LOW,  HIGH, HIGH },  // 50%  - R1, R2 ligados
    { LOW,  LOW,  LOW,  HIGH },  // 75%  - R1, R2, R3 ligados
    { LOW,  LOW,  LOW,  LOW }    // 100% - Todos ligados
  };

  int indice = nivel / 25; // Calcula o índice para a tabela (0 para 0%, 1 para 25%, etc.).
  if (indice >= 0 && indice <= 4) { // Se o índice é válido.
    digitalWrite(RELE_1, estados[indice][0]); // Configura cada relé.
    digitalWrite(RELE_2, estados[indice][1]);
    digitalWrite(RELE_3, estados[indice][2]);
    digitalWrite(RELE_4, estados[indice][3]);
    sensores.luminosidade = nivel; // Atualiza o nível de luminosidade atual do sistema.

    debugPrint("Rele configurado: " + String(nivel) + "% (indice " + String(indice) + ")");
    // Mostra o estado de cada relé para depuração.
    debugPrint("Estados dos relés: R1=" + String(estados[indice][0] == LOW ? "ON" : "OFF") + 
               ", R2=" + String(estados[indice][1] == LOW ? "ON" : "OFF") + 
               ", R3=" + String(estados[indice][2] == LOW ? "ON" : "OFF") + 
               ", R4=" + String(estados[indice][3] == LOW ? "ON" : "OFF"));

    // Toca um som de confirmação se a mudança for significativa e houver pessoas.
    if (pessoas.total > 0) {
      if ((nivel > 0 && nivelAnterior == 0) || (nivel == 0 && nivelAnterior > 0) || abs(nivel - nivelAnterior) >= 50) {
        tocarSom(SOM_COMANDO);
      }
    }
    nivelAnterior = nivel; // Guarda o nível atual para a próxima vez.
    
    if (pessoas.total > 0) { // Atualiza o LCD se houver pessoas.
      atualizarLCD();
    }
  }
}

// Lê os valores do sensor DHT (temperatura, umidade) e do LDR (luminosidade ambiente).
void lerSensores() {
  unsigned long agora = millis();
  // Só lê os sensores no intervalo definido (INTERVALO_DHT).
  if (agora - tempos[0] < INTERVALO_DHT) return; // tempos[0] é para o DHT.
  tempos[0] = agora; // Marca o tempo da leitura.

  float temp = dht.readTemperature(); // Lê temperatura.
  float hum = dht.readHumidity();     // Lê umidade.

  // Verifica se as leituras são válidas.
  if (!isnan(temp) && !isnan(hum) && temp >= -40 && temp <= 80 && hum >= 0 && hum <= 100) {
    if (flags.erroSensor) { // Se antes havia um erro de sensor.
      flags.erroSensor = false; // Limpa a flag de erro.
      tocarSom(SOM_OK);         // Som de recuperação.
      debugPrint("Sensores DHT recuperados.");
    }
    sensores.temperatura = temp; // Guarda os valores lidos.
    sensores.humidade = hum;
    sensores.dadosValidos = true; // Marca que os dados são válidos.
  } else { // Se a leitura falhou.
    if (!sensores.dadosValidos) { // Se os dados anteriores já não eram válidos (ex: na inicialização).
      // Usa valores padrão para não travar o sistema.
      sensores.temperatura = 25.0;
      sensores.humidade = 50.0;
      sensores.dadosValidos = true; // Considera válido para ter um fallback.
    }
    if (!flags.erroSensor) { // Se é a primeira vez que o erro ocorre.
      flags.erroSensor = true; // Liga a flag de erro.
      debugPrint("ERRO: Falha na leitura do DHT");
      mostrarErroLCD("Sensor DHT", false); // Mostra erro no LCD.
    }
  }

  // Leitura do LDR com um filtro de média simples para suavizar variações.
  static int ldrBuffer[3] = { 0 }; // Buffer para 3 leituras.
  static int bufferIndex = 0;      // Posição atual no buffer.

  ldrBuffer[bufferIndex] = analogRead(LDR_PIN); // Lê o valor analógico do LDR.
  bufferIndex = (bufferIndex + 1) % 3; // Avança o índice no buffer (circular).
  sensores.valorLDR = (ldrBuffer[0] + ldrBuffer[1] + ldrBuffer[2]) / 3; // Calcula a média.

  if (pessoas.total > 0) { // Atualiza o LCD se houver pessoas.
    atualizarLCD();
  }
}

// Uma função genérica para fazer requisições HTTP (GET ou POST) para o servidor.
bool enviarHTTP(const String& endpoint, const String& dados = "", bool isPost = false) {
  if (!flags.wifiOk) { // Só tenta enviar se o Wi-Fi estiver conectado.
    return false;
  }

  HTTPClient http; // Objeto para a requisição.
  String fullUrl = String(serverUrl) + endpoint; // Monta a URL completa.
  http.begin(fullUrl); // Inicia.
  http.setTimeout(5000); // Timeout de 5 segundos.

  bool sucesso = false;
  int httpCode = 0;

  if (isPost) { // Se for uma requisição POST (enviar dados).
    http.addHeader("Content-Type", "application/json"); // Cabeçalho para JSON.
    httpCode = http.POST(dados); // Envia os dados.
    // Considera sucesso se o código for 200 (OK) ou 204 (No Content - comum para POSTs que não retornam corpo).
    sucesso = (httpCode == HTTP_CODE_OK || httpCode == HTTP_CODE_NO_CONTENT);
  } else { // Se for GET (buscar dados).
    httpCode = http.GET();
    sucesso = (httpCode == HTTP_CODE_OK); // Sucesso apenas se for 200 (OK).
  }

  if (!sucesso) { // Se houve erro na comunicação.
    debugPrint("enviarHTTP: Erro (" + String(httpCode) + ") ao enviar para " + endpoint + " Dados: " + dados.substring(0, min(dados.length(), (unsigned int)100))); // Mostra o início dos dados.
    if (!flags.erroConexao) { // Se é o primeiro erro de conexão.
      flags.erroConexao = true; // Liga a flag.
      mostrarErroLCD("Falha Conexao", false); // Mostra no LCD.
    }
  } else { // Se a comunicação foi bem-sucedida.
    if (flags.erroConexao) { // Se antes havia um erro.
      flags.erroConexao = false; // Limpa a flag.
      tocarSom(SOM_OK);          // Som de recuperação.
    }
  }

  http.end(); // Finaliza a conexão.
  return sucesso; // Retorna true se deu certo, false se deu erro.
}

// Coleta os dados atuais dos sensores, estado do climatizador e pessoas, e envia para o servidor.
void enviarDados() {
  static bool forcarEnvio = false; // Flag para forçar envio (não usado diretamente aqui, mas no `enviarDadosImediato`).
  
  unsigned long agora = millis();
  // Só envia no intervalo definido (INTERVALO_DADOS).
  if (!forcarEnvio && agora - tempos[1] < INTERVALO_DADOS) return; // tempos[1] é para envio de dados.
  tempos[1] = agora; // Marca o tempo do envio.

  StaticJsonDocument<300> doc; // Documento JSON para os dados (tamanho máx 300 bytes).
  // Adiciona os dados dos sensores.
  doc["t"] = round(sensores.temperatura * 10) / 10.0; // Temperatura com 1 casa decimal.
  doc["h"] = round(sensores.humidade);              // Umidade arredondada.
  doc["l"] = sensores.luminosidade;                 // Nível de iluminação artificial.
  doc["p"] = pessoas.total;                         // Total de pessoas.

  // Adiciona dados do climatizador em um objeto JSON aninhado "c".
  JsonObject c = doc.createNestedObject("c");
  c["l"] = clima.ligado;
  c["u"] = clima.umidificando;
  c["v"] = clima.velocidade;
  c["uv"] = clima.ultimaVel; // Última velocidade.
  c["t"] = clima.timer;
  c["av"] = clima.aletaV;   // Aleta vertical.
  c["ah"] = clima.aletaH;   // Aleta horizontal.
  c["mmc"] = flags.modoManualClima; // Modo manual do clima.

  if (pessoas.count > 0) { // Se há tags no histórico.
    JsonArray tagsArray = doc.createNestedArray("tags"); // Cria array "tags".
    for (int i = 0; i < pessoas.count; i++) {
      if (pessoas.estado[i]) { // Adiciona apenas as tags das pessoas presentes.
        tagsArray.add(pessoas.tags[i]);
      }
    }
  }

  String dados;
  serializeJson(doc, dados); // Converte o JSON para String.
  debugPrint("Enviando dados ambiente: " + dados);

  bool sucesso = enviarHTTP("ambiente", dados, true); // Envia para o endpoint "ambiente" via POST.
  
  // Feedback especial se for o último envio antes de resetar o sistema (ninguém na sala).
  if (pessoas.total == 0 && forcarEnvio) { // 'forcarEnvio' aqui é conceitual, a lógica real está em `resetarSistema` e `enviarDadosImediato`.
    debugPrint("Envio final " + String(sucesso ? "BEM-SUCEDIDO" : "FALHOU"));
  }
  forcarEnvio = false; // Reseta a flag de forçar envio.
}

// Versão de `enviarDados` que envia imediatamente, sem esperar o intervalo.
// Útil em eventos críticos como a saída de uma pessoa, para registrar o estado final rapidamente.
void enviarDadosImediato() {
  // A lógica é idêntica a `enviarDados()`, mas sem a verificação de intervalo.
  StaticJsonDocument<300> doc;
  doc["t"] = round(sensores.temperatura * 10) / 10.0;
  doc["h"] = round(sensores.humidade);
  doc["l"] = sensores.luminosidade;
  doc["p"] = pessoas.total;

  JsonObject c = doc.createNestedObject("c");
  c["l"] = clima.ligado;
  c["u"] = clima.umidificando;
  c["v"] = clima.velocidade;
  c["uv"] = clima.ultimaVel;
  c["t"] = clima.timer;
  c["av"] = clima.aletaV;
  c["ah"] = clima.aletaH;
  c["mmc"] = flags.modoManualClima;

  if (pessoas.count > 0) {
    JsonArray tagsArray = doc.createNestedArray("tags");
    for (int i = 0; i < pessoas.count; i++) {
      if (pessoas.estado[i]) {
        tagsArray.add(pessoas.tags[i]);
      }
    }
  }
  String dados;
  serializeJson(doc, dados);
  debugPrint("ENVIO FORÇADO - dados ambiente: " + dados);
  bool sucesso = enviarHTTP("ambiente", dados, true);
  debugPrint("Resultado envio forçado: " + String(sucesso ? "SUCESSO" : "FALHA"));
}

// Verifica se uma nova tag RFID foi aproximada. Se sim, lê o ID da tag.
void processarNFC() {
  // `PICC_IsNewCardPresent()`: Há um cartão novo?
  // `PICC_ReadCardSerial()`: Conseguiu ler o número de série?
  if (!mfrc522.PICC_IsNewCardPresent() || !mfrc522.PICC_ReadCardSerial()) {
    return; // Se não, sai da função.
  }

  String tag = ""; // String para montar o ID da tag.
  for (byte i = 0; i < mfrc522.uid.size; i++) { // Percorre os bytes do ID.
    if (mfrc522.uid.uidByte[i] < 0x10) tag += "0"; // Adiciona um "0" à esquerda se for menor que 16 (ex: 0F em vez de F).
    tag += String(mfrc522.uid.uidByte[i], HEX); // Converte o byte para hexadecimal e adiciona à string.
  }
  tag.toUpperCase(); // Converte para maiúsculas para padronizar.

  debugPrint("Tag NFC lida: " + tag);
  gerenciarPresenca(tag); // Chama a função que trata a entrada/saída da pessoa.

  mfrc522.PICC_HaltA();      // Para a comunicação com a tag atual (importante para ler novas tags).
  mfrc522.PCD_StopCrypto1(); // Para a criptografia (se estiver ativa).
}

// Chamada após ler uma tag. Registra a entrada ou saída de uma pessoa,
// atualiza o total e busca novas preferências se necessário.
void gerenciarPresenca(const String& tag) {
  int indice = -1;    // Índice da tag no histórico (se já existir).
  bool entrando = false; // A pessoa está entrando ou apenas mudando de estado (já estava no histórico)?
  int totalAnterior = pessoas.total; // Guarda o total de pessoas antes desta tag.

  // Procura a tag no histórico.
  for (int i = 0; i < pessoas.count; i++) {
    if (pessoas.tags[i] == tag) {
      indice = i; // Achou a tag, guarda o índice.
      break;
    }
  }

  if (indice == -1) { // Se a tag é nova (não está no histórico).
    if (pessoas.count < 10) { // Se ainda há espaço no histórico (máximo 10).
      pessoas.tags[pessoas.count] = tag;       // Adiciona a tag.
      pessoas.estado[pessoas.count] = true;    // Marca como presente.
      pessoas.total++;                         // Incrementa o total de pessoas.
      pessoas.count++;                         // Incrementa o número de tags no histórico.
      entrando = true;                         // É uma nova entrada.

      if (pessoas.total == 1) { // Se é a primeira pessoa a entrar.
        // Reativa as automações e liga o backlight do LCD.
        flags.monitorandoLDR = true;
        flags.ilumAtiva = false;       // Força reavaliação da iluminação.
        flags.modoManualIlum = false;
        flags.modoManualClima = false;
        lcd.backlight();
        debugPrint("Primeira pessoa detectada. Automação reativada e backlight ligado.");
      }

      debugPrint("Nova pessoa detectada - Tag: " + tag + ", Total: " + String(pessoas.total));
      tocarSom(SOM_PESSOA_ENTROU); // Som de boas-vindas.

      // Mensagem no LCD.
      lcd.clear();
      lcd.setCursor(0, 0);
      lcd.write(0); // Ícone de pessoa.
      lcd.print(" Bem-vindo!");
      lcd.setCursor(0, 1);
      lcd.print("Pessoas: ");
      lcd.print(pessoas.total);
      delay(400); // Mostra por um tempo.

    } else { // Se o histórico está cheio.
      debugPrint("Limite de pessoas atingido (10). Ignorando nova tag: " + tag);
      tocarSom(SOM_ERRO);
      delay(200);
    }
  } else if (pessoas.estado[indice]) { // Se a tag já existe no histórico E a pessoa estava PRESENTE.
    // Isso significa que a pessoa está SAINDO.
    pessoas.estado[indice] = false; // Marca como "não presente".
    pessoas.total--;                // Decrementa o total de pessoas.

    debugPrint("Pessoa saindo - Tag: " + tag + ", Total: " + String(pessoas.total));
    tocarSom(SOM_PESSOA_SAIU); // Som de despedida.

    // Mensagem no LCD.
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.write(0); // Ícone de pessoa.
    lcd.print(" Ate logo!");
    lcd.setCursor(0, 1);
    lcd.print("Pessoas: ");
    lcd.print(pessoas.total);
    delay(400);

    // Envia dados IMEDIATAMENTE para o servidor registrar a saída.
    enviarDadosImediato();
    
    if (pessoas.total == 0) { // Se era a última pessoa.
      // Envia dados algumas vezes para garantir que o servidor recebeu o estado "0 pessoas".
      // Isso é importante para o servidor saber que a sala está vazia.
      debugPrint("ÚLTIMA PESSOA SAINDO - Enviando dados críticos múltiplas vezes");
      delay(1000); enviarDadosImediato();
      delay(1500); enviarDadosImediato();
      delay(2000);
      resetarSistema(); // Chama a função para desligar tudo.
      return; // Sai da função `gerenciarPresenca` para evitar mais processamento.
    }
  } else { // Se a tag já existe no histórico MAS a pessoa estava marcada como "NÃO PRESENTE".
    // Isso significa que uma pessoa que já esteve na sala antes está VOLTANDO.
    pessoas.estado[indice] = true; // Marca como presente novamente.
    pessoas.total++;               // Incrementa o total.
    entrando = true;               // Considera como uma "entrada" para fins de atualizar preferências.

    debugPrint("Pessoa voltando - Tag: " + tag + ", Total: " + String(pessoas.total));
    tocarSom(SOM_PESSOA_ENTROU); // Som de boas-vindas.

    // Mensagem no LCD.
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.write(0);
    lcd.print(" Bem-vindo!");
    lcd.setCursor(0, 1);
    lcd.print("Pessoas: ");
    lcd.print(pessoas.total);
    delay(500);
  }
  
  // Se o número de pessoas mudou OU alguém novo entrou, e há pessoas na sala,
  // e não está no meio de uma atualização de preferências:
  if ((totalAnterior != pessoas.total || entrando) && pessoas.total > 0 && !flags.atualizandoPref) {
    debugPrint("=== MUDANÇA DE GRUPO DETECTADA ===");
    debugPrint("Total anterior: " + String(totalAnterior) + " -> Atual: " + String(pessoas.total));
    debugPrint("Entrando (nova ou retornando): " + String(entrando ? "SIM" : "NAO"));
    pessoas.prefsAtualizadas = false; // Marca que as preferências precisam ser reconsultadas.
    
    debugPrint("Consultando preferências para o novo grupo...");
    if (consultarPreferencias()) { // Tenta buscar as preferências do novo grupo.
      debugPrint("Preferências atualizadas com sucesso após mudança de grupo.");
      // Se a iluminação automática estiver ativa e não em modo manual,
      // força uma reavaliação da iluminação com as novas preferências.
      if (flags.ilumAtiva && !flags.modoManualIlum) {
        int nivelDesejado = pessoas.lumPref;
        if (nivelDesejado == 0 && pessoas.lumPref == 0) nivelDesejado = 25; // Mínimo de segurança se pref for 0.
        
        if (sensores.luminosidade != nivelDesejado) {
          debugPrint("FORÇANDO ajuste de iluminação de " + String(sensores.luminosidade) + "% para " + String(nivelDesejado) + "% (nova preferência).");
          configurarRele(nivelDesejado); // Aplica o novo nível.
        }
      }
    }
  }

  atualizarLCD(); // Atualiza o display com as novas informações.
  enviarDados();  // Envia os dados atualizados para o servidor (no próximo ciclo de envio).
}

// Quando a última pessoa sai, esta função desliga tudo (luzes, climatizador)
// e limpa o estado para o próximo uso, deixando o sistema em "standby".
void resetarSistema() {
  // Mensagem no LCD indicando que está desativando.
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Desativando...");
  lcd.setCursor(0, 1);
  lcd.print("Sistema");
  tocarSom(SOM_ALERTA); // Som de alerta.
  delay(800);

  // Envia um último conjunto de dados para o servidor (já deve ter sido feito em gerenciarPresenca).
  // enviarDados(); // Pode ser redundante, mas garante.

  // Desliga o climatizador se estiver ligado.
  if (clima.ligado) {
    lcd.setCursor(0, 1);
    lcd.print("Desl. Clima...  "); // Atualiza só a segunda linha.
    enviarComandoIR(IR_POWER); // Envia comando de desligar.
    delay(500); // Espera o comando ser processado.
  }

  // Desliga a iluminação.
  lcd.setCursor(0, 1);
  lcd.print("Desl. Luzes... ");
  flags.modoManualIlum = false; // Reseta modos manuais.
  flags.modoManualClima = false;
  flags.ilumAtiva = false;      // Marca luzes como inativas.
  flags.monitorandoLDR = true;  // Prepara para monitorar LDR quando alguém entrar.
  configurarRele(0);           // Desliga todos os relés.
  flags.monitorandoLDR = true;
  delay(300);

  // Limpa completamente os dados das pessoas.
  for (int i = 0; i < pessoas.count; i++) {
    pessoas.tags[i] = "";
    pessoas.estado[i] = false;
  }
  pessoas.total = 0;
  pessoas.count = 0;
  pessoas.prefsAtualizadas = false; // Preferências não estão mais atualizadas.

  // Mensagem de conclusão.
  lcd.setCursor(0, 1);
  lcd.print("Concluido!     ");
  delay(1000);

  debugPrint("Sistema resetado completamente - Modo de espera");
  
  // Deixa o LCD em modo de espera (sem luz de fundo, mensagem "Sistema Inativo").
  lcd.noBacklight();
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Sistema Inativo");
  lcd.setCursor(0, 1);
  lcd.print("Passe o cartao");
  debugPrint("Backlight do LCD desligado - Sistema em standby.");
}

// Controla as luzes automaticamente.
// Se estiver escuro e houver pessoas (e não estiver em modo manual), liga as luzes no nível preferido.
// Se não houver pessoas, desliga as luzes.
void gerenciarIluminacao() {
  unsigned long agora = millis();
  if (agora - tempos[2] < INTERVALO_LDR) return;
  tempos[2] = agora;

  // Se não há pessoas, desligar luzes automaticamente
  if (pessoas.total == 0) {
    if (flags.ilumAtiva || sensores.luminosidade != 0) {
      debugPrint("Desligando luzes: Nenhuma pessoa presente (ou sistema reiniciando sem pessoas).");

      if (!(pessoas.total == 0 && flags.modoManualIlum == false && flags.ilumAtiva == false)) {
        lcd.clear();
        lcd.setCursor(0, 0);
        lcd.write(3);
        lcd.print(" Luz Auto Off");
        lcd.setCursor(0, 1);
        lcd.print("Nenhuma pessoa");
        tocarSom(SOM_COMANDO);
        delay(800);
      }

      configurarRele(0);
      flags.ilumAtiva = false;
      flags.modoManualIlum = false;
      if (!(pessoas.total == 0 && flags.modoManualIlum == false && flags.ilumAtiva == false)) {
        atualizarLCD();
      }
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

// Envia um comando infravermelho para o climatizador.
bool enviarComandoIR(uint8_t comando) {
  unsigned long agora = millis();

  // Debounce: Evita enviar comandos muito rapidamente.
  static unsigned long ultimoComandoIR = 0;
  if (agora - ultimoComandoIR < DEBOUNCE_ENVIAR) {
    debugPrint("Comando IR 0x" + String(comando, HEX) + " ignorado (debounce de envio).");
    return false; // Ignora o comando.
  }

  // Verifica se o sistema de IR não está ocupado enviando outro comando.
  if (controleIR.estado != IR_OCIOSO) {
    debugPrint("Comando IR 0x" + String(comando, HEX) + " ignorado (sistema IR ocupado: " + String(controleIR.estado) + ").");
    return false; // Ignora o comando.
  }

  debugPrint("Enviando comando IR: 0x" + String(comando, HEX)); // Ex: 0x85 para Power.

  // Configura a máquina de estados IR para o envio.
  controleIR.estado = IR_ENVIANDO;
  controleIR.comandoPendente = comando; // Guarda qual comando está sendo enviado.
  controleIR.inicioEnvio = agora;
  controleIR.comandoConfirmado = false; // Reseta a flag de confirmação.

  // Envia o comando 3 vezes para aumentar a chance de o climatizador receber.
  for (int i = 0; i < 3; i++) {
    IrSender.sendNEC(IR_ENDERECO, comando, 0); // Envia usando protocolo NEC. (0 = sem repetição da biblioteca)
    debugPrint("Sinal IR enviado (tentativa " + String(i + 1) + "): Endereco=0x" + String(IR_ENDERECO, HEX) + ", Comando=0x" + String(comando, HEX));
    delay(5); // Pequena pausa entre os envios.
  }

  controleIR.estado = IR_AGUARDANDO_CONFIRMACAO; // Muda o estado para esperar eco/confirmação.
  ultimoComandoIR = agora; // Marca o tempo do último envio.

  return true; // Comando foi enviado (ou pelo menos tentado).
}

// Atualiza o estado interno do climatizador (na struct `clima`) após um comando IR.
// Isso é importante para que o sistema "saiba" o que o climatizador está fazendo.
void atualizarEstadoClima(uint8_t comando) {
  bool estadoAnteriorLigado = clima.ligado; // Guarda se estava ligado antes do comando.

  switch (comando) { // Verifica qual comando foi.
    case IR_POWER:
      clima.ligado = !clima.ligado; // Inverte o estado (liga se estava desligado, desliga se estava ligado).
      if (clima.ligado) { // Se ligou agora.
        // Restaura a última velocidade usada ou define como 1 se não houver.
        clima.velocidade = clima.ultimaVel > 0 ? clima.ultimaVel : 1;
      } else { // Se desligou agora.
        // Reseta os outros estados.
        clima.velocidade = 0;
        clima.umidificando = false;
        clima.timer = 0;
        clima.aletaV = false;
        clima.aletaH = false;
      }
      debugPrint("Climatizador: Estado alterado para " + String(clima.ligado ? "LIGADO" : "DESLIGADO"));
      break;
    case IR_UMIDIFICAR:
      if (clima.ligado) { // Só funciona se estiver ligado.
        clima.umidificando = !clima.umidificando;
        debugPrint("Umidificação: " + String(clima.umidificando ? "LIGADA" : "DESLIGADA"));
      }
      break;
    case IR_VELOCIDADE:
      if (clima.ligado) {
        clima.velocidade = (clima.velocidade % 3) + 1; // Cicla entre 1, 2, 3.
        clima.ultimaVel = clima.velocidade; // Guarda como última velocidade manual.
        debugPrint("Velocidade alterada para: " + String(clima.velocidade));
      }
      break;
    case IR_TIMER:
      if (clima.ligado) {
        clima.timer = (clima.timer + 1) % 6; // Cicla entre 0 a 5 (representando horas ou modo).
        debugPrint("Timer alterado para: " + String(clima.timer));
      }
      break;
    case IR_ALETA_VERTICAL:
      if (clima.ligado) {
        clima.aletaV = !clima.aletaV;
        debugPrint("Aleta vertical: " + String(clima.aletaV ? "ATIVA" : "INATIVA"));
      }
      break;
    case IR_ALETA_HORIZONTAL:
      if (clima.ligado) {
        clima.aletaH = !clima.aletaH;
        debugPrint("Aleta horizontal: " + String(clima.aletaH ? "ATIVA" : "INATIVA"));
      }
      break;
  }

  // Se o estado de "ligado" mudou ou qualquer outro comando foi processado.
  if (estadoAnteriorLigado != clima.ligado || comando != 0) { // `comando != 0` garante atualização se não for power.
    clima.ultimaAtualizacao = millis(); // Marca o tempo da atualização.
  }
}

// Controla o climatizador automaticamente baseado na diferença entre a temperatura ambiente e a preferida.
void controleAutomaticoClima() {
  // Só funciona se houver pessoas e não estiver em modo manual.
  if (pessoas.total <= 0 || flags.modoManualClima) {
    if (pessoas.total == 0 && clima.ligado) { // Se não tem ninguém e o clima está ligado.
      debugPrint("Desligando climatizador automaticamente (sem pessoas).");
      enviarComandoIR(IR_POWER); // Desliga.
    }
    return; // Sai da função.
  }
  
  // Define temperatura alvo: se há preferências atualizadas, usa a média; senão usa 25°C padrão
  float tempAlvo = 25.0; // Temperatura confortável padrão
  String origemTemp = "padrão (25°C)";
  
  if (pessoas.prefsAtualizadas && pessoas.tempPref != 25.0) {
    tempAlvo = pessoas.tempPref;
    origemTemp = "média das preferências (" + String(pessoas.tempPref) + "°C)";
  }

  unsigned long agora = millis();
  // Só executa no intervalo definido (INTERVALO_CLIMA_AUTO).
  if (agora - tempos[3] < INTERVALO_CLIMA_AUTO) return; // tempos[3] é para o clima automático.
  tempos[3] = agora;

  float diff = sensores.temperatura - tempAlvo; // Diferença de temperatura.

  debugPrint("=== CONTROLE AUTOMÁTICO CLIMA ===");
  debugPrint("Temp Atual: " + String(sensores.temperatura) + "°C, Alvo: " + String(tempAlvo) + "°C (" + origemTemp + "), Diff: " + String(diff) + "°C");
  debugPrint("Clima Ligado: " + String(clima.ligado ? "SIM" : "NAO"));

  // Se está quente (diferença >= 2°C) E o climatizador está desligado:
  if (diff >= 2.0 && !clima.ligado) {
    // Mensagem no LCD.
    lcd.clear(); lcd.setCursor(0,0); lcd.write(5); lcd.print(" Auto Ligar");
    lcd.setCursor(0,1); lcd.print("Temp: +"); lcd.print(diff,1); lcd.print(" graus");
    tocarSom(SOM_COMANDO);
    debugPrint("LIGANDO climatizador automaticamente (temperatura alta).");
    delay(800);

    enviarComandoIR(IR_POWER); // Liga o climatizador.
    atualizarLCD(); // Atualiza o display principal.
    
    // Garante que a velocidade inicial seja 1 (a mais baixa).
    // O estado `clima.velocidade` pode ter sido atualizado por `atualizarEstadoClima` chamado implicitamente.
    // É preciso verificar o estado `clima.velocidade` *depois* do comando IR_POWER ter tido chance de ser processado e `atualizarEstadoClima` ter sido chamado.
    // Uma forma simples é esperar um pouco e, se a velocidade não for 1, enviar comandos de velocidade.
    // Esta parte pode ser complexa devido à natureza assíncrona do IR e atualizações de estado.
    // A lógica atual dentro de `atualizarEstadoClima` para IR_POWER já tenta definir `clima.velocidade` para `clima.ultimaVel` ou 1.
    // Se `clima.ultimaVel` for >1, pode ser necessário um ajuste aqui.
    // Por simplicidade, vamos assumir que IR_POWER já define uma velocidade inicial razoável.
    // Se for necessário forçar velocidade 1:
    // delay(500); // Espera para o estado do clima ser atualizado.
    // if (clima.ligado && clima.velocidade != 1) {
    //    debugPrint("Ajustando velocidade inicial para 1 (default automático).");
    //    // ... lógica para enviar IR_VELOCIDADE até chegar em 1 ...
    // }

  } else if (diff <= -0.5 && clima.ligado) { // Se está mais frio que o preferido E o climatizador está ligado:
    // Mensagem no LCD.
    lcd.clear(); lcd.setCursor(0,0); lcd.write(5); lcd.print(" Auto Deslig.");
    lcd.setCursor(0,1); lcd.print("Temp: "); lcd.print(diff,1); lcd.print(" graus");
    tocarSom(SOM_COMANDO);
    debugPrint("DESLIGANDO climatizador automaticamente (temperatura baixa).");
    delay(800);

    enviarComandoIR(IR_POWER); // Desliga.
    atualizarLCD();
  } else if (clima.ligado) { // Se está ligado e a temperatura está "OK" (nem muito quente, nem muito fria para desligar).
    // Ajusta a velocidade com base na diferença de temperatura.
    int velDesejada = 1; // Velocidade padrão.
    if (diff >= 4.5) velDesejada = 3;      // Muito quente -> velocidade máxima.
    else if (diff >= 3.0) velDesejada = 2; // Quente -> velocidade média.

    if (clima.velocidade != velDesejada) { // Se a velocidade atual é diferente da desejada.
      // Mensagem no LCD.
      lcd.clear(); lcd.setCursor(0,0); lcd.write(5); lcd.print(" Ajuste Auto");
      lcd.setCursor(0,1); lcd.print("Vel "); lcd.print(clima.velocidade); lcd.print(" -> "); lcd.print(velDesejada);
      tocarSom(SOM_COMANDO);
      debugPrint("Ajustando velocidade do climatizador: " + String(clima.velocidade) + " -> " + String(velDesejada));
      delay(800);

      // Envia comandos IR_VELOCIDADE até atingir a velocidade desejada.
      // Isso pode ser complexo porque cada comando IR_VELOCIDADE avança para a próxima.
      // É preciso saber quantos "toques" dar.
      int tentativas = 0;
      // Loop para tentar acertar a velocidade. `processarIRRecebido` dentro do loop ajuda a atualizar `clima.velocidade` mais rápido.
      while (clima.velocidade != velDesejada && tentativas < 3) { // Tenta no máximo 3 vezes (ou 3 "ciclos" de velocidade).
        if (enviarComandoIR(IR_VELOCIDADE)) { // Envia o comando de mudar velocidade.
          tentativas++;
          // Espera um pouco para o comando ser processado e o estado `clima` ser atualizado pela recepção IR (se houver).
          unsigned long t0 = millis();
          while (controleIR.estado != IR_OCIOSO && millis() - t0 < TIMEOUT_CONFIRMACAO + 200) {
            processarIRRecebido(); // Importante para atualizar o estado `clima` se o próprio ESP "ouvir" seu comando.
            delay(10);
          }
          // Se não houve recepção (eco), o `atualizarEstadoClima` chamado por `processarIRRecebido` (via timeout) deve ter atualizado.
          // Caso contrário, o estado `clima` pode não refletir a mudança imediatamente.
        } else {
          break; // Se não conseguiu enviar o comando IR, desiste.
        }
      }
      atualizarLCD();
    }
  }

  // Controle automático das aletas (direção do ar).
  if (clima.ligado && !flags.modoManualClima) { // Só se ligado e em modo automático.
    if (pessoas.total == 1) { // Se só tem uma pessoa.
      if (!clima.aletaV) { // Aleta vertical (oscilação cima/baixo) deve estar ativa.
        debugPrint("Controle Auto Aleta: Ativando aleta vertical (1 pessoa).");
        enviarComandoIR(IR_ALETA_VERTICAL); delay(300); // Espera entre comandos IR.
      }
      if (clima.aletaH) { // Aleta horizontal (oscilação dir/esq) deve estar INATIVA.
        debugPrint("Controle Auto Aleta: Desativando aleta horizontal (1 pessoa).");
        enviarComandoIR(IR_ALETA_HORIZONTAL); delay(300);
      }
    } else if (pessoas.total > 1) { // Se tem mais de uma pessoa.
      if (!clima.aletaV) { // Aleta vertical deve estar ativa.
        debugPrint("Controle Auto Aleta: Ativando aleta vertical (>1 pessoa).");
        enviarComandoIR(IR_ALETA_VERTICAL); delay(300);
      }
      if (!clima.aletaH) { // Aleta horizontal TAMBÉM deve estar ativa para espalhar o ar.
        debugPrint("Controle Auto Aleta: Ativando aleta horizontal (>1 pessoa).");
        enviarComandoIR(IR_ALETA_HORIZONTAL); delay(300);
      }
    }
  }
}

// Consulta o servidor periodicamente para ver se há comandos manuais vindos do aplicativo
// (ex: ligar luz específica, mudar modo do climatizador).
void verificarComandos() {
  unsigned long agora = millis();
  // Só executa no intervalo definido E se o Wi-Fi estiver OK.
  if (agora - tempos[4] < INTERVALO_COMANDOS || !flags.wifiOk) return; // tempos[4] é para verificar comandos.
  tempos[4] = agora;

  HTTPClient http; // Objeto para requisições.

  // 1. Verifica comandos para a ILUMINAÇÃO.
  String urlIlum = String(serverUrl) + "comando"; // Endpoint para comandos de iluminação.
  http.begin(urlIlum);
  int httpCodeIlum = http.GET(); // Faz uma requisição GET.

  if (httpCodeIlum == HTTP_CODE_OK) { // Se o servidor respondeu OK.
    String cmd = http.getString(); // Pega a resposta (comando).
    cmd.trim(); // Remove espaços em branco.

    if (cmd != "auto" && cmd.length() > 0 && pessoas.total > 0) { // Se o comando NÃO é "auto", tem algo e há pessoas.
      int nivel = cmd.toInt(); // Converte o comando para número (nível de iluminação).
      // Valida se o nível é 0, 25, 50, 75 ou 100.
      if (nivel >= 0 && nivel <= 100 && (nivel % 25 == 0)) {
        bool entrandoModoManual = !flags.modoManualIlum; // Estava em auto e vai para manual?
        bool nivelDiferente = (sensores.luminosidade != nivel); // O nível pedido é diferente do atual?
        
        // Qualquer comando numérico do app para iluminação ativa o modo manual.
        flags.modoManualIlum = true;
        flags.ilumAtiva = true; // Considera a iluminação ativa (mesmo que nível 0).

        if (entrandoModoManual) { // Se estava em modo automático antes.
          // Mensagem no LCD.
          lcd.clear(); lcd.setCursor(0,0); lcd.write(3); lcd.print(" Luz Manual ON");
          lcd.setCursor(0,1); lcd.print("Nivel: "); lcd.print(nivel); lcd.print("%");
          tocarSom(SOM_COMANDO); delay(800);
          debugPrint("Entrando no modo manual de iluminação via APP (Nível: " + String(nivel) + "%).");
        }
        
        if (nivelDiferente) { // Só configura o relé se o nível for diferente.
          debugPrint("Comando de iluminação APP: Mudar para " + String(nivel) + "% (anterior: " + String(sensores.luminosidade) + "%).");
          configurarRele(nivel); // Aplica o nível.
        } else {
          debugPrint("Comando de iluminação APP: Manter " + String(nivel) + "% (já no nível correto).");
        }
      }
    } else if (cmd == "auto" && flags.modoManualIlum) { // Se o comando é "auto" E estava em modo manual.
      flags.modoManualIlum = false; // Volta para o modo automático.
      debugPrint("Comando de iluminação APP: Saindo do modo manual para automático.");
      if (pessoas.total > 0) { // Se há pessoas.
        flags.monitorandoLDR = true; // Reativa monitoramento do LDR.
        flags.ilumAtiva = false;     // Força reavaliação da iluminação automática.
      } else {
        configurarRele(0); // Se não há pessoas, desliga tudo.
      }
      atualizarLCD();
    }
  } else {
    debugPrint("Erro ao verificar comando de iluminação do servidor: HTTP " + String(httpCodeIlum));
  }
  http.end(); // Finaliza a requisição de iluminação.

  // 2. Verifica comandos DIRETOS para o CLIMATIZADOR (ligar, mudar velocidade, etc.).
  String urlClimaCmd = String(serverUrl) + "climatizador/comando"; // Endpoint para comandos diretos do climatizador.
  http.begin(urlClimaCmd);
  int httpCodeClimaCmd = http.GET();

  if (httpCodeClimaCmd == HTTP_CODE_OK) {
    String cmd = http.getString();
    cmd.trim();

    if (cmd != "none" && cmd.length() > 0) { // Se recebeu algum comando (diferente de "none").
      if (!flags.modoManualClima) { // Se não estava em modo manual, entra agora.
        flags.modoManualClima = true;
        // Mensagem no LCD.
        lcd.clear(); lcd.setCursor(0,0); lcd.write(5); lcd.print(" Clima: Manual");
        lcd.setCursor(0,1); lcd.print("Control: APP");
        tocarSom(SOM_COMANDO); delay(800);
      }

      // Mostra qual comando foi recebido no LCD.
      lcd.clear(); lcd.setCursor(0,0); lcd.write(5); lcd.print(" Comando App");
      lcd.setCursor(0,1);
      if (cmd == "power") lcd.print("Power Toggle");
      else if (cmd == "velocidade") lcd.print("Velocidade");
      // ... (outros comandos)
      else lcd.print(cmd); // Mostra o comando bruto se não for um dos conhecidos.
      tocarSom(SOM_COMANDO); delay(800);

      debugPrint("Comando do APP para climatizador: " + cmd);

      // Envia o comando IR correspondente.
      if (cmd == "power") enviarComandoIR(IR_POWER);
      else if (cmd == "velocidade") enviarComandoIR(IR_VELOCIDADE);
      else if (cmd == "timer") enviarComandoIR(IR_TIMER);
      else if (cmd == "umidificar") enviarComandoIR(IR_UMIDIFICAR);
      else if (cmd == "aleta_vertical") enviarComandoIR(IR_ALETA_VERTICAL);
      else if (cmd == "aleta_horizontal") enviarComandoIR(IR_ALETA_HORIZONTAL);
      // Não chama `atualizarEstadoClima` aqui, pois `enviarComandoIR` já dispara uma lógica
      // que, através de `processarIRRecebido` (eco ou timeout), acaba chamando `atualizarEstadoClima`.
      atualizarLCD(); // Atualiza o display principal.
    }
  } else {
    debugPrint("Erro ao verificar comando direto do climatizador: HTTP " + String(httpCodeClimaCmd));
  }
  http.end();

  // 3. Verifica o ESTADO do modo manual do CLIMATIZADOR (se o app mudou para auto/manual).
  String urlClimaManual = String(serverUrl) + "climatizador/manual"; // Endpoint para estado do modo manual.
  http.begin(urlClimaManual);
  int httpCodeClimaManual = http.GET();

  if (httpCodeClimaManual == HTTP_CODE_OK) {
    String resposta = http.getString(); // Resposta JSON: {"modoManualClimatizador": true/false}
    StaticJsonDocument<64> doc; // JSON pequeno.
    DeserializationError error = deserializeJson(doc, resposta);

    if (!error) { // Se conseguiu parsear o JSON.
      if (doc.containsKey("modoManualClimatizador")) {
        bool modoManualServidor = doc["modoManualClimatizador"];

        if (modoManualServidor != flags.modoManualClima) { // Se o estado do servidor é diferente do local.
          flags.modoManualClima = modoManualServidor; // Sincroniza o estado local com o servidor.
          if (flags.modoManualClima) {
            // Mensagem no LCD.
            lcd.clear(); lcd.setCursor(0,0); lcd.write(5); lcd.print(" Clima: Manual");
            lcd.setCursor(0,1); lcd.print("Control: Sync"); // Indica que foi sincronizado.
            tocarSom(SOM_COMANDO); delay(800);
            debugPrint("Modo do climatizador alterado para MANUAL (sincronizado com servidor).");
          } else {
            debugPrint("Modo do climatizador alterado para AUTOMÁTICO (sincronizado com servidor).");
          }
          atualizarLCD();
        }
      } else {
        debugPrint("Chave 'modoManualClimatizador' não encontrada na resposta do servidor.");
      }
    } else {
      debugPrint("Erro ao parsear JSON para modo manual do climatizador: " + String(error.c_str()));
    }
  } else {
    debugPrint("Erro ao verificar modo manual do climatizador: HTTP " + String(httpCodeClimaManual));
  }
  http.end();
}

// Verifica se algum sinal IR foi recebido (do controle remoto original, por exemplo)
// e atualiza o estado do sistema.
void processarIRRecebido() {
  // Tenta decodificar um sinal IR.
  if (!IrReceiver.decode()) { // Se não há sinal IR para decodificar...
    // ... verifica se estávamos esperando uma confirmação de um comando enviado.
    unsigned long agora = millis();
    if (controleIR.estado == IR_AGUARDANDO_CONFIRMACAO && agora - controleIR.inicioEnvio > TIMEOUT_CONFIRMACAO) {
      // Se passou o tempo de timeout, assume que o comando foi (provavelmente) recebido pelo climatizador,
      // mesmo que não tenhamos "ouvido" o eco. Atualiza o estado interno.
      debugPrint("Timeout aguardando confirmação (eco) do comando IR: 0x" + String(controleIR.comandoPendente, HEX) + ". Atualizando estado local.");
      atualizarEstadoClima(controleIR.comandoPendente); // Atualiza o estado do `clima`.
      controleIR.estado = IR_OCIOSO; // Volta para o estado ocioso.
      atualizarTelaClimatizador(); // Mostra a tela do climatizador.
    }
    return; // Sai, pois não há sinal IR novo.
  }

  // Se chegou aqui, um sinal IR foi decodificado!
  unsigned long agora = millis();

  // Pega os dados do sinal IR: protocolo, endereço, comando.
  uint8_t protocolo = IrReceiver.decodedIRData.protocol;
  uint16_t endereco = IrReceiver.decodedIRData.address;
  uint8_t comando = IrReceiver.decodedIRData.command;

  debugPrint("Sinal IR detectado: Protocolo=" + String(protocolo) + 
             ", Endereço=0x" + String(endereco, HEX) + 
             ", Comando=0x" + String(comando, HEX));

  // Verifica se o protocolo e endereço são os esperados para o nosso climatizador.
  if (protocolo != IR_PROTOCOLO || endereco != IR_ENDERECO) {
    debugPrint("Comando IR ignorado (protocolo/endereço não corresponde ao climatizador).");
    IrReceiver.resume(); // Prepara para receber o próximo sinal.
    return;
  }

  // Lógica para ignorar "ecos" (o próprio ESP32 "ouvindo" o sinal que acabou de enviar).
  // Se estávamos ENVIANDO OU acabamos de enviar (dentro da JANELA_ECO).
  if (controleIR.estado == IR_ENVIANDO || (controleIR.estado == IR_AGUARDANDO_CONFIRMACAO && agora - controleIR.inicioEnvio < JANELA_ECO)) {
    debugPrint("Comando IR 0x" + String(comando, HEX) + " ignorado como ECO do próprio envio.");
    IrReceiver.resume();
    return;
  }

  // Debounce para sinais recebidos: evita processar o mesmo sinal várias vezes se ele for longo.
  static unsigned long ultimoIRRecebido = 0;
  if (agora - ultimoIRRecebido < DEBOUNCE_RECEBER) {
    debugPrint("Comando IR 0x" + String(comando, HEX) + " ignorado (debounce de recebimento).");
    IrReceiver.resume();
    return;
  }

  // Se estávamos aguardando confirmação E o comando recebido é o mesmo que enviamos:
  if (controleIR.estado == IR_AGUARDANDO_CONFIRMACAO && comando == controleIR.comandoPendente) {
    debugPrint("Comando IR 0x" + String(comando, HEX) + " CONFIRMADO (recebido após envio).");
    controleIR.comandoConfirmado = true; // Marca como confirmado.
    atualizarEstadoClima(comando); // Atualiza o estado interno.
    controleIR.estado = IR_OCIOSO; // Volta para ocioso.
    ultimoIRRecebido = agora; // Marca o tempo.
    atualizarTelaClimatizador(); // Mostra no LCD.
  } else { // Se é um comando "externo" (do controle remoto original, por exemplo).
    if (!flags.modoManualClima) { // Se não estava em modo manual, entra agora.
      flags.modoManualClima = true;
      // Mensagem no LCD.
      lcd.clear(); lcd.setCursor(0,0); lcd.write(5); lcd.print(" Clima: Manual");
      lcd.setCursor(0,1); lcd.print("Control: IR"); // Indica controle via IR.
      tocarSom(SOM_COMANDO); delay(600);
    }

    debugPrint("Comando IR EXTERNO recebido: 0x" + String(comando, HEX));

    // Mostra no LCD qual comando foi.
    lcd.clear(); lcd.setCursor(0,0); lcd.write(5); lcd.print(" Comando IR");
    lcd.setCursor(0,1);
    if (comando == IR_POWER) lcd.print("Power Toggle");
    else if (comando == IR_VELOCIDADE) lcd.print("Velocidade");
    // ... (outros comandos)
    else lcd.print("Cmd:0x" + String(comando, HEX));
    tocarSom(SOM_COMANDO); delay(600);
    
    atualizarEstadoClima(comando); // Atualiza o estado interno.
    ultimoIRRecebido = agora;      // Marca o tempo.
    
    if (pessoas.total > 0) { // Atualiza o display principal se houver pessoas.
      atualizarLCD();
    }
    // `atualizarTelaClimatizador` será chamado na próxima iteração do loop se necessário,
    // ou a tela do climatizador já foi mostrada acima.
  }

  IrReceiver.resume(); // Prepara para o próximo sinal.
}

// Verifica o status da conexão Wi-Fi e tenta reconectar se cair.
// Atualiza o ícone no LCD.
void monitorarWiFi() {
  static unsigned long ultimaVerif = 0; // Quando foi a última verificação.
  unsigned long agora = millis();

  // Verifica a cada 30 segundos.
  if (agora - ultimaVerif > 30000) {
    ultimaVerif = agora;
    bool estadoAtual = (WiFi.status() == WL_CONNECTED); // Pega o estado atual da conexão.

    if (estadoAtual != flags.wifiOk) { // Se o estado mudou (conectou ou desconectou).
      flags.wifiOk = estadoAtual; // Atualiza a flag global.

      if (flags.wifiOk) { // Se conectou.
        // Mensagem no LCD.
        lcd.clear(); lcd.setCursor(0,0); lcd.write(4); lcd.print(" WiFi Conectado!");
        lcd.setCursor(0,1); lcd.print(WiFi.localIP().toString()); // Mostra o IP.
        tocarSom(SOM_CONECTADO);
        debugPrint("WiFi RECONECTADO: " + WiFi.localIP().toString());

        // Se reconectou e há pessoas, tenta atualizar as preferências.
        if (pessoas.total > 0 && !flags.atualizandoPref) {
          pessoas.prefsAtualizadas = false; // Marca para reconsultar.
          consultarPreferencias();
        }
      } else { // Se desconectou.
        // Mensagem no LCD.
        lcd.clear(); lcd.setCursor(0,0); lcd.write(7); lcd.print(" WiFi Perdido");
        lcd.setCursor(0,1); lcd.print("Reconectando...");
        tocarSom(SOM_DESCONECTADO);
        debugPrint("WiFi DESCONECTADO - tentando reconectar...");
        // A biblioteca WiFi do ESP32 geralmente tenta reconectar automaticamente em background.
      }
      delay(1000); // Mostra a mensagem por 1 segundo.
      atualizarLCD(); // Atualiza o display principal.
    }
  }
}


// === FUNÇÃO DE CONFIGURAÇÃO (SETUP) ===
// Executada uma vez quando o ESP32 liga ou é resetado.
// Prepara tudo para o funcionamento do sistema.
void setup() {
  Serial.begin(115200); // Inicia a comunicação serial para debug (velocidade 115200 bps).
  debugPrint("\n=== SISTEMA INICIANDO ===");

  // Configura os pinos como SAÍDA (OUTPUT) ou ENTRADA (INPUT).
  pinMode(BUZZER_PIN, OUTPUT);
  pinMode(RELE_1, OUTPUT);
  pinMode(RELE_2, OUTPUT);
  pinMode(RELE_3, OUTPUT);
  pinMode(RELE_4, OUTPUT);
  pinMode(LDR_PIN, INPUT); // LDR é um sensor, então é entrada.

  // Garante que todos os relés comecem DESLIGADOS (nível ALTO para desligar).
  digitalWrite(RELE_1, HIGH);
  digitalWrite(RELE_2, HIGH);
  digitalWrite(RELE_3, HIGH);
  digitalWrite(RELE_4, HIGH);
  debugPrint("Pinos configurados. Relés inicializados como DESLIGADOS.");

  // Inicializa o display LCD.
  lcd.init();
  lcd.backlight(); // Acende a luz de fundo.
  // Carrega os caracteres customizados na memória do LCD.
  lcd.createChar(0, SIMBOLO_PESSOA);
  lcd.createChar(1, SIMBOLO_TEMP);
  lcd.createChar(2, SIMBOLO_HUM);
  lcd.createChar(3, SIMBOLO_LUZ);
  lcd.createChar(4, SIMBOLO_WIFI);
  lcd.createChar(5, SIMBOLO_AR);
  lcd.createChar(6, SIMBOLO_OK);
  lcd.createChar(7, SIMBOLO_ERRO);
  debugPrint("LCD inicializado e caracteres customizados carregados.");

  // Mensagem inicial no LCD.
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Smart Climate v3.0");
  lcd.setCursor(0, 1);
  lcd.print("Iniciando");
  for (int i = 0; i < 3; i++) { delay(200); lcd.print("."); } // Efeito "..."
  tocarSom(SOM_INICIAR); // Som de inicialização.

  testarReles(); // Rotina rápida para piscar os relés (teste visual/audível).
  configurarRele(0); // Garante que as luzes comecem apagadas.

  // Inicializa os módulos de comunicação e sensores.
  SPI.begin();             // Para o leitor RFID.
  mfrc522.PCD_Init();      // Inicializa o leitor RFID.
  dht.begin();             // Inicializa o sensor DHT.
  debugPrint("Módulos SPI (RFID) e DHT inicializados.");

  // Inicializa os módulos de envio e recebimento IR.
  // O segundo argumento de `IrSender.begin` (true) habilita o LED de feedback no pino de envio.
  // `ENABLE_LED_FEEDBACK` para `IrReceiver.begin` também usa o pino do receptor como feedback.
  IrSender.begin(IR_SEND_PIN, true, IR_SEND_PIN); 
  IrReceiver.begin(IR_RECEIVE_PIN, ENABLE_LED_FEEDBACK);
  debugPrint("Módulos de Envio e Recepção IR inicializados.");

  // Conecta ao Wi-Fi.
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Conectando WiFi");
  lcd.setCursor(0, 1);
  lcd.print(ssid); // Mostra o nome da rede.
  debugPrint("Tentando conectar ao WiFi: " + String(ssid));

  WiFi.begin(ssid, password); // Inicia a tentativa de conexão.
  int tentativas = 0;
  // Espera conectar por até 20 segundos (40 tentativas * 500ms).
  while (WiFi.status() != WL_CONNECTED && tentativas < 40) {
    delay(500);
    lcd.setCursor(15, 1); // Canto da tela.
    if (tentativas % 2 == 0) lcd.print("."); else lcd.print(" "); // Efeito de "loading".
    tentativas++;
  }

  flags.wifiOk = (WiFi.status() == WL_CONNECTED); // Atualiza a flag de status do Wi-Fi.

  if (flags.wifiOk) { // Se conectou com sucesso.
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.write(4); // Ícone de WiFi OK.
    lcd.print(" Conectado!");
    lcd.setCursor(0, 1);
    lcd.print(WiFi.localIP()); // Mostra o endereço IP do ESP32.
    tocarSom(SOM_CONECTADO);
    debugPrint("WiFi conectado! IP: " + WiFi.localIP().toString());
  } else { // Se não conseguiu conectar.
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.write(7); // Ícone de WiFi Erro.
    lcd.print(" Sem WiFi");
    lcd.setCursor(0, 1);
    lcd.print("Modo Offline");
    tocarSom(SOM_ERRO);
    debugPrint("Falha ao conectar ao WiFi. Operando em modo offline.");
  }

  // Força a primeira leitura dos sensores e o primeiro envio de dados
  // "enganando" os timers, fazendo parecer que já passou muito tempo desde a última vez.
  unsigned long agora = millis();
  for (int i = 0; i < 8; i++) {
    tempos[i] = agora - (INTERVALO_DADOS + 1000); // Coloca os timers no "passado".
  }
  lerSensores(); // Faz a primeira leitura.
  delay(1000);   // Pequena pausa.
  
  // Sistema inicia em modo de espera (standby), sem ninguém presente.
  lcd.noBacklight(); // Apaga a luz de fundo do LCD.
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Sistema Inativo");
  lcd.setCursor(0, 1);
  lcd.print("Passe o cartao");
  debugPrint("=== SISTEMA INICIALIZADO E PRONTO - MODO STANDBY ===");
}


// === FUNÇÃO PRINCIPAL (LOOP) ===
// Executada repetidamente em um ciclo infinito após o `setup()`.
// Aqui acontece toda a mágica e controle do sistema.
void loop() {
  // Tarefas de alta prioridade, executadas o mais rápido possível.
  processarIRRecebido(); // Verifica se há comandos IR do controle remoto.
  processarNFC();        // Verifica se há cartões RFID próximos.

  // Gerenciamento de tempo para tarefas menos urgentes.
  static unsigned long ultimoCicloRapido = 0;      // Para tarefas que rodam a cada ~100ms.
  static unsigned long ultimoCicloComunicacao = 0; // Para tarefas que rodam a cada ~1s.
  unsigned long agora = millis();                  // Tempo atual.

  // CICLO RÁPIDO (a cada ~100ms): Sensores e controle automático local.
  if (agora - ultimoCicloRapido > 100) {
    ultimoCicloRapido = agora;
    
    lerSensores();             // Lê temperatura, umidade, LDR.
    gerenciarIluminacao();     // Controla as luzes automaticamente.
    controleAutomaticoClima(); // Controla o climatizador automaticamente.
  }

  // CICLO DE COMUNICAÇÃO (a cada ~1000ms): Wi-Fi, servidor, debug.
  if (agora - ultimoCicloComunicacao > 1000) {
    ultimoCicloComunicacao = agora;

    monitorarWiFi();      // Verifica o status do Wi-Fi.
    verificarComandos();  // Busca comandos do servidor (app).

    // Verifica periodicamente se precisa atualizar as preferências (a cada INTERVALO_PREF_CHECK).
    if (agora - tempos[5] >= INTERVALO_PREF_CHECK) { // tempos[5] é para checar prefs.
      tempos[5] = agora;
      if (pessoas.total > 0) { // Só se houver pessoas.
        debugPrint("Verificação periódica de preferências (a cada " + String(INTERVALO_PREF_CHECK/1000) + "s)...");
        consultarPreferencias(); // Tenta buscar/atualizar.
      } else {
        pessoas.prefsAtualizadas = false; // Se não tem ninguém, reseta a flag.
      }
    }

    // Comandos de teste via Serial Monitor (só funcionam se não houver ninguém na sala).
    // Útil para testar funcionalidades específicas sem precisar do app ou RFID.
    if (pessoas.total == 0 && Serial.available() > 0) {
      String comando = Serial.readString();
      comando.trim(); // Remove espaços.
      comando.toLowerCase(); // Converte para minúsculas.
      
      if (comando == "testar_reles") {
        debugPrint("=== COMANDO MANUAL (SERIAL): TESTE DE RELÉS ===");
        testarReles();
      } else if (comando == "testar_niveis") {
        debugPrint("=== COMANDO MANUAL (SERIAL): TESTE DE NÍVEIS DE LUMINOSIDADE ===");
        testarNiveisLuminosidade();
      } else if (comando == "debug_preferencias") {
        debugPrint("=== COMANDO MANUAL (SERIAL): DEBUG PREFERÊNCIAS ===");
        // Mostra informações detalhadas sobre o estado das preferências e iluminação.
        // (código omitido para brevidade, mas está no original)
      } else if (comando.startsWith("rele_")) { // Ex: "rele_50" para 50%
        int nivel = comando.substring(5).toInt();
        if (nivel >= 0 && nivel <= 100 && (nivel % 25 == 0)) {
          debugPrint("=== COMANDO MANUAL (SERIAL): CONFIGURAR RELÉ PARA " + String(nivel) + "% ===");
          configurarRele(nivel);
        }
      }
    }

    enviarDados();       // Envia os dados dos sensores e estado para o servidor.
    mostrarTelaDebug();  // Mostra informações de debug no Serial Monitor (se ativo).
  }

  // Pequeno delay para não sobrecarregar o processador e permitir que outras tarefas do ESP32 rodem.
  delay(5);
}

// === FUNÇÕES DE TESTE ===
// Auxiliares para verificar componentes durante o desenvolvimento.

// Testa todos os relés, ligando e desligando cada um individualmente.
// Ajuda a verificar se a fiação e os relés estão funcionando.
void testarReles() {
  debugPrint("=== INICIANDO TESTE DOS RELÉS ===");
  int pinosRele[] = {RELE_1, RELE_2, RELE_3, RELE_4};
  
  for (int i = 0; i < 4; i++) {
    int pino = pinosRele[i];
    debugPrint("Testando Relé " + String(i + 1) + " (Pino " + String(pino) + ")");
    
    digitalWrite(pino, LOW);  // Liga o relé (LOW = ON).
    debugPrint("  Relé " + String(i + 1) + " LIGADO (nível BAIXO no pino).");
    delay(200); // Mantém ligado por um tempo.
    
    digitalWrite(pino, HIGH); // Desliga o relé (HIGH = OFF).
    debugPrint("  Relé " + String(i + 1) + " DESLIGADO (nível ALTO no pino).");
    delay(200); // Mantém desligado por um tempo.
  }
  debugPrint("=== TESTE DOS RELÉS CONCLUÍDO ===");
}

// Testa todos os níveis de luminosidade (0%, 25%, 50%, 75%, 100%).
// Ajuda a verificar se a lógica de `configurarRele` está correta.
void testarNiveisLuminosidade() {
  debugPrint("=== INICIANDO TESTE DOS NÍVEIS DE LUMINOSIDADE ===");
  const int niveis[] = {0, 25, 50, 75, 100, 75, 50, 25, 0}; // Ciclo completo.
  
  for (int i = 0; i < sizeof(niveis)/sizeof(niveis[0]); i++) {
    debugPrint("Configurando para nível: " + String(niveis[i]) + "%");
    configurarRele(niveis[i]); // Aplica o nível.
    delay(1000); // Mantém por 1 segundo.
  }
  // configurarRele(0); // Garante que termina desligado (já está no array).
  debugPrint("=== TESTE DE NÍVEIS DE LUMINOSIDADE CONCLUÍDO ===");
}