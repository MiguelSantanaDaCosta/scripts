# 📦 concatenar

Ferramenta CLI em Bash para **concatenação inteligente de arquivos** e **análise estrutural de projetos**.

Ideal para:
- preparar código para IA (LLMs)
- auditoria de projetos
- debug rápido
- documentação automatizada

---

## 🚀 Funcionalidades

### 📄 Concatenação
- Junta múltiplos arquivos em um único output
- Suporte a:
  - TXT (padrão)
  - JSON
  - NDJSON (ideal para IA)

### 🎯 Filtros avançados
- `--include` → incluir caminhos específicos
- `--exclude` → excluir diretórios/arquivos
- `--no-hidden` → ignorar arquivos ocultos
- `--ext` → filtrar por extensão
- `--lang` → filtrar por linguagem (auto-mapeado)
- `--max-size` → evitar arquivos grandes

### 🌳 Estrutura do projeto
- `-T` → árvore completa (tipo `tree`)
- `-Td` → apenas diretórios
- `-Tj` → árvore em JSON

### ⚡ Otimização
- `-m` → modo leve (ignora diretórios pesados)
- `-c` → compressão automática (`.xz`)
- ignora arquivos binários automaticamente

---

## 📥 Instalação

```bash
git clone <repo>
cd concatenar
chmod +x concatenar

```
mv concatenar ~/.local/bin/
🧠 Uso básico
./concatenar

Gera:

combinado.txt
🔧 Exemplos
🔹 Concatenar projeto inteiro (modo leve)
./concatenar -m
🔹 Preparar código para IA (recomendado)
./concatenar -m -nh -nj --max-size 200k
🔹 Filtrar por linguagem
./concatenar --lang java
🔹 Filtrar múltiplas extensões
./concatenar --ext js,ts
🔹 Ignorar arquivos grandes
./concatenar --max-size 100k
🔹 Comprimir saída
./concatenar -m -c
🔹 Gerar árvore do projeto
./concatenar -T
🔹 Árvore só com diretórios
./concatenar -Td
🔹 Árvore em JSON
./concatenar -Tj
📚 Parâmetros
Flag	Descrição
-i, --include	Incluir caminhos específicos
-e, --exclude	Excluir caminhos
-nh, --no-hidden	Ignorar arquivos ocultos
-m, --minimal	Ignorar diretórios pesados
-l, --logs	Mostrar logs
-j, --json	Saída JSON
-nj, --ndjson	Saída NDJSON
--ext	Filtrar extensões
--lang	Filtrar linguagem
--max-size	Limite de tamanho
-c, --compress	Compactar saída
-T	Árvore completa
-Td	Apenas diretórios
-Tj	Árvore JSON
-h, --help	Ajuda
🧠 Linguagens suportadas
Linguagem	Extensões
Java	.java
Python	.py
JavaScript	.js
TypeScript	.ts
C	.c, .h
C++	.cpp, .hpp, .h
Go	.go
Rust	.rs
Bash	.sh
⚙️ Modo minimal (-m)

Ignora automaticamente:

.git
node_modules
dist
build
target
.venv
__pycache__
📦 Saídas
Formato	Arquivo
TXT	combinado.txt
JSON	combinado.json
NDJSON	combinado.ndjson
TREE	estrutura.txt
TREE JSON	estrutura.json
💡 Casos de uso
🤖 IA / LLM

Preparar código limpo e estruturado para análise:

./concatenar -m -nh -nj --max-size 200k
🔍 Auditoria de projeto
./concatenar -T
⚡ Debug rápido
./concatenar -l
🛠️ Roadmap
 paralelismo (xargs -P)
 suporte a .gitignore
 cache incremental
 exportação para embeddings
 plugin para Neovim
📄 Licença

MIT
