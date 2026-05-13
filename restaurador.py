#!/usr/bin/env python3
"""
Viegp-Restore: Reconstrutor Universal de Projetos
------------------------------------------------
Desenvolvido para restaurar estruturas de arquivos a partir de arquivos 
concatenados (.txt, .json, .ndjson). Ideal para recuperação de dotfiles,
backups de código e integração com contextos de LLMs.

Uso: python3 viegp-restore.py <arquivo_fonte> <diretorio_destino>
"""

import os
import re
import sys
import json
import argparse

def restore_from_txt(content, target_dir):
    """
    Restaura a partir do padrão de separadores: ===== caminho/do/arquivo =====
    Utiliza Regex para identificar os blocos de arquivos e seus respectivos nomes.
    """
    # Divide o conteúdo baseando-se no padrão de cabeçalho. 
    # O re.split retorna uma lista onde os índices ímpares são os caminhos dos arquivos.
    files = re.split(r"===== (.*?) =====", content)
    
    for i in range(1, len(files), 2):
        filename = files[i].strip()  # Caminho relativo extraído do cabeçalho
        body = files[i+1].strip()    # Conteúdo do arquivo logo após o cabeçalho
        save_file(target_dir, filename, body)

def restore_from_json(content, target_dir):
    """
    Lida com arquivos .json estruturados como dicionários {path: content} 
    ou listas de objetos [{'path': '...', 'content': '...'}].
    """
    data = json.loads(content)
    if isinstance(data, list):
        for item in data:
            # Busca chaves comuns usadas por exportadores de contexto
            path = item.get('path') or item.get('name')
            body = item.get('content') or item.get('code')
            save_file(target_dir, path, body)
    elif isinstance(data, dict):
        for path, body in data.items():
            save_file(target_dir, path, body)

def restore_from_ndjson(source_path, target_dir):
    """
    Lê arquivos .ndjson (Newline Delimited JSON), processando linha por linha
    para economizar memória em arquivos muito grandes.
    """
    with open(source_path, 'r', encoding='utf-8') as f:
        for line in f:
            if line.strip():
                item = json.loads(line)
                save_file(target_dir, item.get('path'), item.get('content'))

def save_file(target_dir, filename, body):
    """
    Cria a subestrutura de pastas necessária e grava o arquivo final.
    """
    if not filename or body is None:
        return
        
    # Define o caminho absoluto final no sistema
    path = os.path.join(target_dir, filename)
    
    # Cria as pastas pai (ex: nvim/lua/plugins/) se não existirem
    os.makedirs(os.path.dirname(path), exist_ok=True)
    
    with open(path, "w", encoding="utf-8") as f:
        f.write(body)
    print(f"✅ Restaurado: {filename}")

def main():
    # Configuração da interface de linha de comando
    parser = argparse.ArgumentParser(
        description="Viegp-Restore: Reconstrutor de diretórios a partir de arquivos de contexto."
    )
    parser.add_argument("source", help="Caminho para o arquivo fonte (.txt, .json, .ndjson)")
    parser.add_argument("target", help="Diretório onde o projeto será reconstruído")
    
    args = parser.parse_args()
    
    # Expande caminhos como '~/' para o diretório home do usuário
    source = os.path.expanduser(args.source)
    target = os.path.expanduser(args.target)

    if not os.path.exists(source):
        print(f"❌ Erro: O arquivo '{source}' não foi encontrado.")
        sys.exit(1)

    # Detecta o tipo de arquivo pela extensão
    ext = os.path.splitext(source)[1].lower()

    print(f"🚀 Iniciando restauração em: {target}")

    if ext == ".ndjson":
        restore_from_ndjson(source, target)
    else:
        with open(source, "r", encoding="utf-8") as f:
            content = f.read()
        
        if ext == ".json":
            restore_from_json(content, target)
        else:
            # Caso padrão: assume formato .txt com separadores '====='
            restore_from_txt(content, target)

    print(f"\n✨ Processo concluído. Verifique o diretório: {target}")

if __name__ == "__main__":
    main()
