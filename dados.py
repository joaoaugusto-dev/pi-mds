import csv
import random
import math
from datetime import datetime, timedelta

# === FUNCIONÁRIOS ===
funcionarios = [
    {"id": 1, "matricula": "25000019", "nome": "João Augusto", "sobrenome": "Freitas", "senha": "123", "temp_pref": 18, "lumi_pref": 25, "tag": "8E0F3503"},
    {"id": 2, "matricula": "25000795", "nome": "Kauan", "sobrenome": "Leander Leandrini", "senha": "123", "temp_pref": 30, "lumi_pref": 75, "tag": "6C227B1C"},
    {"id": 3, "matricula": "25001248", "nome": "Everson", "sobrenome": "Chagas Araújo", "senha": "123", "temp_pref": 22, "lumi_pref": 50, "tag": "AC71771C"},
    {"id": 4, "matricula": "25001227", "nome": "Isadora", "sobrenome": "Cabral dos Santos", "senha": "123", "temp_pref": 26, "lumi_pref": 100, "tag": "8CE3721C"},
]
todas_tags = [f["tag"] for f in funcionarios]

# === GERAR FUNCIONÁRIOS CSV ===
with open("funcionarios.csv", "w", newline="", encoding="utf-8") as f:
    writer = csv.writer(f)
    writer.writerow(["id", "matricula", "nome", "sobrenome", "senha", "temp_preferida", "lumi_preferida", "tag_nfc", "createdAt", "updatedAt"])
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    for func in funcionarios:
        writer.writerow([func["id"], func["matricula"], func["nome"], func["sobrenome"], func["senha"],
                         func["temp_pref"], func["lumi_pref"], func["tag"], now, now])

# === FUNÇÕES DE VARIAÇÃO ===
def gerar_temperatura(hora, minuto):
    base = 26 + 6 * math.sin(((hora * 60 + minuto) / 1440) * 2 * math.pi)
    var_ruido = random.uniform(-0.3, 0.3)
    return round(base + var_ruido, 1)

def gerar_umidade(temp):
    base = 75 - (temp - 20) * 1.8
    return round(max(40, min(85, base + random.uniform(-1.5, 1.5))), 1)

def gerar_ldr(hora):
    return random.randint(500, 900) if 6 <= hora < 18 else random.randint(100, 400)

def gerar_presencas(prev_tags):
    if random.random() < 0.85:
        return prev_tags
    pessoas = random.choices([0, 1, 2, 3, 4], weights=[50, 20, 15, 10, 5])[0]
    return random.sample(todas_tags, pessoas)

# === GERAÇÃO DE DADOS (3 anos em 1 arquivo) ===
inicio = datetime(2023, 1, 1, 0, 0, 0)
fim = datetime(2026, 1, 1, 0, 0, 0)

print("⏳ Gerando dados de 2023 a 2025... Isso pode levar alguns minutos.")
with open("leituras_3_anos.csv", "w", newline="", encoding="utf-8") as f:
    writer = csv.writer(f)
    writer.writerow([
        "id", "temperatura", "humidade", "ldr",
        "pessoas", "tags_qtd", "tags_presentes", "clima_ligado",
        "clima_umidificando", "clima_velocidade",
        "modo_manual_ilum", "modo_manual_clima", "timestamp"
    ])

    ts = inicio
    id_contador = 1
    tags_presentes = []

    while ts < fim:
        hora = ts.hour
        minuto = ts.minute

        temperatura = gerar_temperatura(hora, minuto)
        umidade = gerar_umidade(temperatura)
        ldr = gerar_ldr(hora)
        tags_presentes = gerar_presencas(tags_presentes)
        pessoas = len(tags_presentes)

        modo_manual_ilum = 1 if pessoas > 0 and random.random() < 0.01 else 0
        modo_manual_clima = 1 if pessoas > 0 and random.random() < 0.01 else 0

        if pessoas > 0:
            temps_pref = [f["temp_pref"] for f in funcionarios if f["tag"] in tags_presentes]
            temp_media_pref = sum(temps_pref) / len(temps_pref)
            diff = temperatura - temp_media_pref

            clima_ligado = 1 if diff > 0 else 0
            clima_umidificando = 1 if umidade < 55 else 0
            if umidade > 65:
                clima_umidificando = 0

            if diff >= 4.5:
                clima_vel = 3
            elif diff >= 3.0:
                clima_vel = 2
            elif diff > 0:
                clima_vel = 1
            else:
                clima_vel = 0
        else:
            clima_ligado = clima_umidificando = clima_vel = 0

        writer.writerow([
            id_contador, temperatura, umidade, ldr,
            pessoas, len(tags_presentes), tags_presentes,
            clima_ligado, clima_umidificando, clima_vel,
            modo_manual_ilum, modo_manual_clima,
            ts.strftime("%Y-%m-%d %H:%M:%S")
        ])

        id_contador += 1
        ts += timedelta(minutes=1)

print("✅ Arquivo único 'leituras_3_anos.csv' gerado com sucesso!")