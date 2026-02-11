#!/bin/bash

# Cores
VERDE='\033[0;32m'
VERMELHO='\033[0;31m'
AMARELO='\033[1;33m'
AZUL='\033[0;34m'
CINZA='\033[0;90m'
SEM_COR='\033[0m'

echo -e "${AZUL}===============================================${SEM_COR}"
echo -e "${AZUL}   RAIO-X AVANÇADO (INFRA + SEGURANÇA)         ${SEM_COR}"
echo -e "${AZUL}===============================================${SEM_COR}"

# --- FUNÇÕES AUXILIARES ---
check_status() {
    if systemctl is-active --quiet "$1"; then
        echo -e "${VERDE}ATIVO/RODANDO${SEM_COR}"
    else
        echo -e "${VERMELHO}PARADO/INATIVO${SEM_COR}"
    fi
}

check_install() {
    if command -v "$1" &> /dev/null || dpkg -s "$1" &> /dev/null; then
        echo -e "${VERDE}INSTALADO${SEM_COR}"
        return 0
    else
        echo -e "${VERMELHO}NÃO INSTALADO${SEM_COR}"
        return 1
    fi
}

# 1. Hardware e OS (Resumido)
echo -e "\n${AMARELO}[1] SISTEMA E RECURSOS:${SEM_COR}"
echo "   OS: $(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)"
echo "   Kernel: $(uname -r)"
echo "   Uptime: $(uptime -p)"
MEM_USADA=$(free -m | awk '/Mem:/ { printf("%.0f%%", $3/$2*100) }')
DISK_USADO=$(df -h / | awk '/\// {print $5}')
echo "   Memória Usada: $MEM_USADA"
echo "   Disco Usado: $DISK_USADO"

# 2. Servidores Web
echo -e "\n${AMARELO}[2] SERVIDORES WEB:${SEM_COR}"
echo -n "   Nginx: "
check_install nginx && echo -n "      Status: " && check_status nginx
echo -n "   Apache2: "
check_install apache2 && echo -n "      Status: " && check_status apache2

# 3. Verificação de Segurança (O CORAÇÃO DA ATUALIZAÇÃO)
echo -e "\n${AMARELO}[3] AUDITORIA DE SEGURANÇA:${SEM_COR}"

# 3.1 Firewall UFW
echo -e "   ${CINZA}--- Firewall (UFW) ---${SEM_COR}"
if command -v ufw &> /dev/null; then
    UFW_STATE=$(sudo ufw status | head -n 1)
    if [[ $UFW_STATE == *"active"* ]]; then
        echo -e "   Status UFW: ${VERDE}ATIVO E PROTEGENDO${SEM_COR}"
        echo "   Regras Atuais (Resumo):"
        sudo ufw status numbered | head -n 5 | sed 's/^/      /'
    else
        echo -e "   Status UFW: ${VERMELHO}INATIVO (PERIGO)${SEM_COR}"
    fi
else
    echo -e "   UFW: ${VERMELHO}NÃO INSTALADO${SEM_COR}"
fi

# 3.2 Fail2Ban
echo -e "\n   ${CINZA}--- Prevenção de Intrusão (Fail2Ban) ---${SEM_COR}"
echo -n "   Instalação: "
if check_install fail2ban; then
    echo -n "   Serviço: "
    check_status fail2ban
    # Verifica quantas "jails" (prisões) estão ativas
    JAILS=$(fail2ban-client status 2>/dev/null | grep "Jail list" | cut -d: -f2)
    echo "   Proteções Ativas (Jails):$JAILS"
else
    echo -e "   ${AMARELO}RECOMENDAÇÃO:${SEM_COR} Instale o fail2ban (apt install fail2ban)"
fi

# 3.3 Atualizações Automáticas
echo -e "\n   ${CINZA}--- Updates Automáticos ---${SEM_COR}"
if dpkg -s unattended-upgrades &> /dev/null; then
    echo -e "   Pacote: ${VERDE}INSTALADO${SEM_COR}"
    # Verifica se está configurado para rodar
    if [ -f /etc/apt/apt.conf.d/20auto-upgrades ]; then
        CONFIG=$(cat /etc/apt/apt.conf.d/20auto-upgrades)
        if [[ $CONFIG == *"1"* ]]; then
            echo -e "   Configuração: ${VERDE}ATIVADO${SEM_COR}"
        else
            echo -e "   Configuração: ${VERMELHO}DESATIVADO${SEM_COR}"
        fi
    else
        echo -e "   Configuração: ${AMARELO}ARQUIVO NÃO ENCONTRADO${SEM_COR}"
    fi
else
    echo -e "   Pacote: ${VERMELHO}NÃO INSTALADO${SEM_COR}"
fi

# 3.4 Hardening do SSH
echo -e "\n   ${CINZA}--- Configuração do SSH (/etc/ssh/sshd_config) ---${SEM_COR}"
if [ -r /etc/ssh/sshd_config ]; then
    SSH_PORT=$(grep "^Port " /etc/ssh/sshd_config | awk '{print $2}')
    ROOT_LOGIN=$(grep "^PermitRootLogin" /etc/ssh/sshd_config | awk '{print $2}')
    PASS_AUTH=$(grep "^PasswordAuthentication" /etc/ssh/sshd_config | awk '{print $2}')
    
    [ -z "$SSH_PORT" ] && SSH_PORT="22 (Padrão)"
    [ -z "$ROOT_LOGIN" ] && ROOT_LOGIN="Não definido (Padrão)"
    [ -z "$PASS_AUTH" ] && PASS_AUTH="Não definido (Padrão 'yes')"

    echo "   Porta SSH: $SSH_PORT"
    
    echo -n "   Login Root Direto: $ROOT_LOGIN "
    if [[ "$ROOT_LOGIN" == "no" ]]; then echo -e "(${VERDE}SEGURO${SEM_COR})"; else echo -e "(${AMARELO}ATENÇÃO${SEM_COR})"; fi
    
    echo -n "   Login por Senha: $PASS_AUTH "
    if [[ "$PASS_AUTH" == "no" ]]; then echo -e "(${VERDE}SEGURO - Chave SSH${SEM_COR})"; else echo -e "(${AMARELO}MENOS SEGURO${SEM_COR})"; fi
else
    echo "   Não foi possível ler o arquivo de configuração do SSH."
fi

# 4. Portas em Aberto
echo -e "\n${AMARELO}[4] PORTAS OUVINDO (SERVIÇOS EXPOSTOS):${SEM_COR}"
# Usa ss para listar portas TCP ouvindo (listening) e numéricas
ss -tuln | awk 'NR>1 {print $1, $5}' | column -t | sed 's/^/   /'

echo -e "\n${AZUL}===============================================${SEM_COR}"
