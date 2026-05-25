#!/bin/bash

OUTPUT="combinado.txt"
INCLUDE=()
EXCLUDE=()
IGNORE_HIDDEN=false
MINIMAL_MODE=false
LOGS=false
FORMAT="txt"
EXTENSIONS=""
LANGUAGE=""
MAX_SIZE=""
COMPRESS=false
DRY_RUN=false

EXCLUDE_DEFAULT=(
    ".git"
    "node_modules"
    "dist"
    "build"
    "target"
    ".venv"
    "__pycache__"
)

# -------------------------
# MAPA DE LINGUAGENS
# -------------------------
map_lang() {
    case "$1" in
        java) echo "java" ;;
        python) echo "py" ;;
        js|javascript) echo "js" ;;
        ts|typescript) echo "ts" ;;
        c) echo "c,h" ;;
        cpp|c++) echo "cpp,hpp,h" ;;
        go) echo "go" ;;
        rust) echo "rs" ;;
        bash|sh) echo "sh" ;;
        *) echo "" ;;
    esac
}

COPY_TO_CLIPBOARD=false

# -------------------------
# Clipboard e Entropia
# -------------------------
# Retorna uma pontuação de 0 a 100. Valores muito baixos indicam "minificação" (código ilegível)
calculate_entropy() {
    local file=$1
    local total=$(wc -c < "$file")
    [[ "$total" -eq 0 ]] && echo 0 && return
    local unique=$(tr -dc '[:print:]' < "$file" | fold -w1 | sort -u | wc -l)
    echo $(( (unique * 100) / total ))
}

# -------------------------
# HELP
# -------------------------
show_help() {
cat << EOF
Uso: $(basename "$0") [OPÇÕES]

Concatena arquivos ou gera estrutura do projeto.

OPÇÕES:

  -i, --include <path>     Incluir apenas caminhos específicos
  -e, --exclude <path>     Excluir caminhos específicos
  -nh, --no-hidden         Ignorar arquivos ocultos
  -n,  --dry-run           Simular Pocessamento(não gera arquivos)
  -m, --minimal            Modo leve (ignora diretórios pesados)
  -l, --logs               Mostrar arquivos sendo processados

  -j, --json               Saída em JSON
  -nj, --ndjson            Saída em NDJSON

  -T,  --tree              Estrutura em árvore (tree)
  -Td, --tree-dirs         Apenas diretórios
  -Tj, --tree-json         Árvore em JSON

  --ext <ext1,ext2>        Filtrar por extensões (ex: java,py,js)
  --lang <lang>            Filtrar por linguagem (java, python, js, etc)
  --max-size <size>        Limite de tamanho (ex: 100k, 2M, 1G)

  -c, --compress           Compactar saída (.xz)

  -h, --help               Mostrar ajuda

EXCLUSÕES PADRÃO DO -m:

$(for i in "${EXCLUDE_DEFAULT[@]}"; do echo "  - $i"; done)

EXEMPLOS:

  $0 -m
  $0 -m -nj -l
  $0 -T
  $0 -Td
  $0 -Tj -m
  $0 --lang java
  $0 --ext js,ts --max-size 200k
  $0 -m -nj -c

EOF
}

# -------------------------
# Estimar tokens (Regra: ~4 caracteres por token)
# -------------------------
estimate_tokens() {
    local char_count=$1
    echo $((char_count / 4))
}

# -------------------------
# JSON escape
# -------------------------
escape_json() {
    sed ':a;N;$!ba;s/\\/\\\\/g; s/"/\\"/g; s/\n/\\n/g'
}

# -------------------------
# Formatar tamanho com precisão total (Base 1000)
# -------------------------
format_size() {
    local bytes=$1
    awk -v b="$bytes" '
    BEGIN {
        split("B KB MB GB TB", units);
        i = 1;
        val = b;
        while (val >= 1000 && i < 5) {
            val /= 1000;
            i++;
        }
        # Formata com alta precisão decimal inicial
        res = sprintf("%.12f", val);
        # Remove os zeros sacrificáveis do final e o ponto se virar inteiro
        sub(/\.?0+$/, "", res);
        print res " " units[i];
    }'
}

# -------------------------
# Parse args
# -------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) show_help; exit 0 ;;
        -i|--include) INCLUDE+=("$2"); shift ;;
        -e|--exclude) EXCLUDE+=("$2"); shift ;;
        -nh|--no-hidden) IGNORE_HIDDEN=true ;;
        -m|--minimal) MINIMAL_MODE=true ;;
        -l|--logs) LOGS=true ;;
        -C|--copy) COPY_TO_CLIPBOARD=true ;;
        -j|--json) FORMAT="json"; OUTPUT="combinado.json" ;;
        -nj|--ndjson) FORMAT="ndjson"; OUTPUT="combinado.ndjson" ;;
        -T|--tree) FORMAT="tree"; OUTPUT="estrutura.txt" ;;
        -Td|--tree-dirs) FORMAT="tree_dirs"; OUTPUT="estrutura_dirs.txt" ;;
        -Tj|--tree-json) FORMAT="tree_json"; OUTPUT="estrutura.json" ;;
        --ext) EXTENSIONS="$2"; shift ;;
        --lang) LANGUAGE="$2"; shift ;;
        --max-size) MAX_SIZE="$2"; shift ;;
        -n|--dry-run) DRY_RUN=true ;;
        -c|--compress) COMPRESS=true ;;
        *) echo "Parâmetro desconhecido: $1"; exit 1 ;;
    esac
    shift
done

# -------------------------
# LANGUAGE → EXT
# -------------------------
if [[ -n "$LANGUAGE" ]]; then
    mapped=$(map_lang "$LANGUAGE")
    [[ -n "$mapped" ]] && EXTENSIONS="$mapped"
fi

# -------------------------
# Minimal mode
# -------------------------
if $MINIMAL_MODE; then
    EXCLUDE+=("${EXCLUDE_DEFAULT[@]}")
fi

# -------------------------
# TREE MODES
# -------------------------
if [[ "$FORMAT" == "tree" ]]; then
    $LOGS && echo "🌳 Gerando árvore..."

    TREE_CMD=(tree -a -h -p -D)
    $IGNORE_HIDDEN && TREE_CMD=(tree -h -p -D)

    if [[ ${#EXCLUDE[@]} -gt 0 ]]; then
        TREE_CMD+=( -I "$(IFS='|'; echo "${EXCLUDE[*]}")" )
    fi

    "${TREE_CMD[@]}" > "$OUTPUT"
    echo "✔ Estrutura em $OUTPUT"
    exit 0
fi

if [[ "$FORMAT" == "tree_dirs" ]]; then
    $LOGS && echo "🌳 Diretórios..."

    FIND_CMD=(find . -type d)

    $IGNORE_HIDDEN && FIND_CMD+=( ! -path "*/.*" )

    for path in "${EXCLUDE[@]}"; do
        FIND_CMD+=( ! -path "./$path*" )
    done

    "${FIND_CMD[@]}" | sed 's|^\./||' > "$OUTPUT"
    echo "✔ Diretórios em $OUTPUT"
    exit 0
fi

if [[ "$FORMAT" == "tree_json" ]]; then
    $LOGS && echo "🌳 JSON árvore..."

    echo '{ "files": [' > "$OUTPUT"
    FIRST=true

    while IFS= read -r -d '' f; do
        rel="${f#./}"

        if $IGNORE_HIDDEN && [[ "$rel" == .* ]]; then continue; fi

        for e in "${EXCLUDE[@]}"; do
            [[ "$rel" == "$e"* ]] && continue 2
        done

        [[ -d "$f" ]] && tipo="dir" || tipo="file"

        $FIRST || echo ',' >> "$OUTPUT"
        FIRST=false

        printf '{ "path":"%s","type":"%s" }' "$rel" "$tipo" >> "$OUTPUT"

    done < <(find . -print0)

    echo '] }' >> "$OUTPUT"
    echo "✔ JSON árvore em $OUTPUT"
    exit 0
fi

# -------------------------
# CONCAT MODES
# -------------------------
# Criar um arquivo temporário para montagem
TEMP_OUTPUT=$(mktemp)

[[ "$FORMAT" == "json" ]] && echo '{ "files": [' >> "$TEMP_OUTPUT"

FIND_CMD=(find . -type f ! -path "./.git/*" ! -name "$OUTPUT")
$IGNORE_HIDDEN && FIND_CMD+=( ! -path "*/.*" )
for path in "${EXCLUDE[@]}"; do
    FIND_CMD+=( ! -path "./$path/*" )
done

# Array para armazenar lista de arquivos processados para o sumário
PROCESSED_FILES=()
COUNT=0
TOTAL_LINES=0
FIRST=true

while IFS= read -r -d '' arquivo; do
    rel="${arquivo#./}"

    # --- FILTROS (Mantenha sua lógica original aqui) ---
    if [[ ${#INCLUDE[@]} -gt 0 ]]; then
        match=false
        for inc in "${INCLUDE[@]}"; do [[ "$rel" == "$inc"* ]] && match=true && break; done
        $match || continue
    fi

    if $DRY_RUN; then
        echo "🔍 [DRY-RUN] Incluído: $rel"
        ((COUNT++))
        continue
    fi

    # --- FILTRO DE ENTROPIA (Ignora minificados) ---
    if [[ "$FORMAT" == "txt" ]]; then
        score=$(calculate_entropy "$arquivo")
        if [[ "$score" -lt 5 ]]; then # Ajuste este threshold conforme necessário
            $LOGS && echo "⏭️ pulado (entropia baixa/minificado): $rel"
            continue
        fi
    fi
    if [[ -n "$EXTENSIONS" ]]; then
        match=false
        IFS=',' read -ra exts <<< "$EXTENSIONS"
        for ext in "${exts[@]}"; do [[ "$arquivo" == *.$ext ]] && match=true && break; done
        $match || continue
    fi

    if [[ -n "$MAX_SIZE" ]]; then
        if ! find "$arquivo" -size "-$MAX_SIZE" | grep -q .; then continue; fi
    fi

    if file --mime "$arquivo" | grep -q binary; then continue; fi

    # --- PROCESSAMENTO ---
    $LOGS && echo "📄 $rel"
    PROCESSED_FILES+=("$rel") # Adiciona ao sumário
    
    file_lines=$(wc -l < "$arquivo")
    TOTAL_LINES=$((TOTAL_LINES + file_lines))

    case "$FORMAT" in
        txt)
            {
                printf "===== %s =====\n" "$rel"
                cat "$arquivo"
                printf "\n"
            } >> "$TEMP_OUTPUT"
            ;;
        json)
            $FIRST || echo ',' >> "$TEMP_OUTPUT"
            FIRST=false
            printf '{ "path":"%s","content":"' "$rel" >> "$TEMP_OUTPUT"
            tr -d '\000' < "$arquivo" | escape_json >> "$TEMP_OUTPUT"
            printf '" }' >> "$TEMP_OUTPUT"
            ;;
        ndjson)
            printf '{"path":"%s","content":"' "$rel" >> "$TEMP_OUTPUT"
            tr -d '\000' < "$arquivo" | escape_json >> "$TEMP_OUTPUT"
            printf '"}\n' >> "$TEMP_OUTPUT"
            ;;
    esac
    ((COUNT++))
done < <("${FIND_CMD[@]}" -print0)

[[ "$FORMAT" == "json" ]] && echo '] }' >> "$TEMP_OUTPUT"

# --- ADICIONAR SUMÁRIO (APENAS PARA TXT) ---
if [[ "$FORMAT" == "txt" ]]; then
    FINAL_CONTENT=$(mktemp)
    echo "--- SUMÁRIO DE ARQUIVOS ($COUNT arquivos) ---" > "$FINAL_CONTENT"
    printf "%s\n" "${PROCESSED_FILES[@]}" >> "$FINAL_CONTENT"
    echo "-------------------------------------------" >> "$FINAL_CONTENT"
    cat "$TEMP_OUTPUT" >> "$FINAL_CONTENT"
    mv "$FINAL_CONTENT" "$OUTPUT"
    rm "$TEMP_OUTPUT"
else
    mv "$TEMP_OUTPUT" "$OUTPUT"
fi

echo "✔ $COUNT arquivos ($TOTAL_LINES linhas) → $OUTPUT"

# -------------------------
# COMPRESS & ESTATÍSTICAS
# -------------------------
CHAR_COUNT=$(wc -m < "$OUTPUT")
TOKENS=$(estimate_tokens "$CHAR_COUNT")

if $COMPRESS; then
    xz -9 "$OUTPUT"
    FINAL_OUTPUT="$OUTPUT.xz"
    echo "📦 Comprimido → $FINAL_OUTPUT"
else
    FINAL_OUTPUT="$OUTPUT"
fi

if [[ -f "$FINAL_OUTPUT" ]]; then
    TAMANHO_BYTES=$(wc -c < "$FINAL_OUTPUT")
    TAMANHO_FORMATADO=$(format_size "$TAMANHO_BYTES")
    echo "-----------------------------------"
    echo "⚖ Tamanho do arquivo: $TAMANHO_FORMATADO"
    echo "🧠 Estimativa de tokens: ~$TOKENS"
    echo "📊 Total processado: $COUNT arquivos ($TOTAL_LINES linhas)"
    echo "-----------------------------------"
fi

# Finalizar se for Dry Run
if $DRY_RUN; then
    echo "-----------------------------------"
    echo "🧪 Dry-run finalizado. Nenhum arquivo foi modificado."
    echo "📊 Total de arquivos que seriam processados: $COUNT"
    exit 0
fi

# -------------------------
# CLIPBOARD
# -------------------------
if $COPY_TO_CLIPBOARD; then
    if command -v xclip >/dev/null 2>&1; then
        cat "$OUTPUT" | xclip -selection clipboard
        echo "📋 Conteúdo copiado para o clipboard (xclip)."
    elif command -v pbcopy >/dev/null 2>&1; then
        cat "$OUTPUT" | pbcopy
        echo "📋 Conteúdo copiado para o clipboard (pbcopy)."
    else
        echo "⚠️ Erro: Comando de clipboard (xclip ou pbcopy) não encontrado."
    fi
fi
