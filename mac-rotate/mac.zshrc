function mac-menu() {
    if [[ "$1" == "--help" ]]; then
        echo "Bypass Tool - Gerenciador Avançado de Identidade e Rede"
        echo "Uso: mac-menu"
        return 0
    fi

    # 1. Identificação Dinâmica da Interface Wireless
    local INTERFACE=$(ip link show | awk -F': ' '/^[0-9]+: wlan|wlp/ {print $2}')
    if [[ -z "$INTERFACE" ]]; then
        echo "❌ Nenhuma interface sem fio encontrada!"
        return 1
    fi

    local CURRENT_MAC=$(ip link show "$INTERFACE" | awk '/link\/ether/ {print $2}')
    local CURRENT_DNS=$(awk '/nameserver/ {print $2; exit}' /etc/resolv.conf 2>/dev/null)

    # 2. Interface Visual com FZF
    local HEADER_TEXT="IF: $INTERFACE | MAC: $CURRENT_MAC | DNS: ${CURRENT_DNS:-Padrão}"
    local choice=$(echo -e "⚡ [MAC] Aleatório (Forçar Novo IP DHCP)\n📱 [MAC] Celular (Perfil Conhecido)\n🏢 [MAC] Clonar Gateway\n🌐 [DNS] Cloudflare (1.1.1.1)\n🔒 [DNS] Quad9 (9.9.9.9)\n🚀 [TUNEL] Iniciar Túnel DNS (Iodine Bypass)\n🔍 [INFO] Scan de Portas de Saída (Achar Brechas)\n🔄 [DHCP] Forçar Renovação Completa" | fzf --header "$HEADER_TEXT" --height=15)
    
    [[ -z "$choice" ]] && return 0

    # 3. Execução das Ações de Evasão
    case "$choice" in
        "⚡ [MAC]"*)
            echo "Derrubando interface $INTERFACE..."
            sudo ip link set dev "$INTERFACE" down
            if [[ "$choice" == *"Aleatório"* ]]; then
                sudo macchanger -r "$INTERFACE"
            elif [[ "$choice" == *"Celular"* ]]; then
                sudo macchanger -m 68:87:1c:5f:0d:89 "$INTERFACE"
            elif [[ "$choice" == *"Clonar Gateway"* ]]; then
                local GW_IP=$(ip route | awk '/default/ {print $3; exit}')
                if [[ -n "$GW_IP" ]]; then
                    local GW_MAC=$(arp -an | grep "$GW_IP" | awk '{print $4}')
                    if [[ -n "$GW_MAC" && "$GW_MAC" != "<incomplete>" ]]; then
                        echo "Clonando MAC do Gateway ($GW_MAC)..."
                        sudo macchanger -m "$GW_MAC" "$INTERFACE"
                    else
                        echo "❌ MAC do Gateway não encontrado na tabela ARP."
                    fi
                else
                    echo "❌ Sem rota para o Gateway."
                fi
            fi
            sudo ip link set dev "$INTERFACE" up
            echo "Reativando interface e forçando DHCP..."
            sudo nmcli device disconnect "$INTERFACE" >/dev/null 2>&1
            sleep 1
            sudo nmcli device connect "$INTERFACE" >/dev/null 2>&1
            sleep 6
            ;;

        "🌐 [DNS] Cloudflare"*)
            echo -e "nameserver 1.1.1.1\nnameserver 1.0.0.1" | sudo tee /etc/resolv.conf > /dev/null
            echo "✅ DNS alterado para Cloudflare"
            ;;

        "🔒 [DNS] Quad9"*)
            echo -e "nameserver 9.9.9.9\nnameserver 149.112.112.112" | sudo tee /etc/resolv.conf > /dev/null
            echo "✅ DNS alterado para Quad9"
            ;;

        "🚀 [TUNEL] Iniciar Túnel DNS"*)
            echo "Instale o 'iodine' no Arch se não tiver (sudo pacman -S iodine)"
            echo -n "Digite o seu domínio de túnel iodine (ex: tunnel.seu-dominio.com): "
            read iod_domain
            echo "Iniciando túnel sobre consultas DNS (Aproveitando Porta 53 aberta)..."
            sudo iodine -f -P "sua_senha_do_servidor" 10.0.0.1 "$iod_domain"
            ;;

        "🔍 [INFO] Scan de Portas de Saída"*)
            echo -e "\n--- Escaneando Portas de Saída no Firewall ---"
            # Lista de portas canário para checar falhas de configuração no firewall administrativo
            local TEST_PORTS=(22 53 80 443 1194 5060 8080 8443)
            # IP público estável externo de testes
            local TEST_IP="1.1.1.1" 
            
            for port in "${TEST_PORTS[@]}"; do
                echo -n "Testando Saída TCP Porta $port: "
                if timeout 2 bash -c "cat < /dev/null > /dev/tcp/$TEST_IP/$port" >/dev/null 2>&1; then
                    echo "🔓 ABERTA! (Use para VPN ou Proxy)"
                else
                    echo "❌ Bloqueada"
                fi
            done
            echo "----------------------------------------------"
            return 0
            ;;

        "🔄 [DHCP]"*)
            sudo nmcli device reapply "$INTERFACE" >/dev/null 2>&1 || sudo nmcli networking off && sudo nmcli networking on
            sleep 6
            ;;
    esac

    # 4. Pipeline de Validação de Rede
    echo -e "\n--- Iniciando Validação de Rede ---"
    local GATEWAY=$(ip route | awk '/default/ {print $3; exit}')
    
    echo -n "[1/4] Rota Padrão (Gateway): "
    [[ -n "$GATEWAY" ]] && echo "OK ($GATEWAY)" || echo "FALHOU"

    echo -n "[2/4] Resolução de Nomes (Porta 53 UDP): "
    host archlinux.org > /dev/null 2>&1 && echo "OK" || echo "BLOQUEADO"

    echo -n "[3/4] Conectividade TCP Direta (Porta 443): "
    if timeout 3 bash -c "cat < /dev/null > /dev/tcp/1.1.1.1/443" >/dev/null 2>&1; then
        echo "OK (Internet Totalmente Aberta)"
    else
        echo "FALHOU (Porta 443 bloqueada/dropada pelo Firewall)"
    fi

    local USER_AGENT="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    echo -n "[4/4] Validação de Saída Web (HTTP/HTTPS): "
    local HTTP_DATA=$(curl -A "$USER_AGENT" -s -o /dev/null -w "%{http_code} %{url_effective}" --connect-timeout 4 https://archlinux.org)
    local HTTP_STATUS=$(echo "$HTTP_DATA" | awk '{print $1}')

    if [[ "$HTTP_STATUS" == "200" ]]; then
        echo "CONECTADO DIRETAMENTE"
    elif [[ "$HTTP_STATUS" == "000" ]]; then
        echo "BLOQUEIO TOTAL (Timeout ou Firewall Dropping)"
    else
        echo "STATUS INESPERADO ($HTTP_STATUS)"
    fi
    echo -e "-----------------------------------\n"
}
