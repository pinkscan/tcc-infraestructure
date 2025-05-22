#!/bin/bash
exec > >(sudo tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

CONFIGDIR="/ops/shared/config"
CONSULPOLICYDIR="/ops/shared/policies/consul"
VAULTPOLICYDIR="/ops/shared/policies/vault"
HOME_DIR="/home/ubuntu"
PROMTAIL_DIR="/etc/promtail.d"

NOMAD_VERSION=${nomad_version}
NOMAD_CONFIG_DIR="/etc/nomad.d"
NOMAD_DIR="/opt/nomad"

CONSUL_VERSION="1.21.0"
CONSUL_CONFIG_DIR="/etc/consul.d"
CONSUL_DIR="/opt/consul"

VAULT_VERSION="1.19.0"
VAULT_CONFIG_DIR="/etc/vault.d"
VAULT_DIR="/opt/vault"

NODE_EXPORTER_VERSION="1.6.1"
USER="node_exporter"

RETRY_JOIN="${retry_join}"
SERVER_COUNT=${server_count}
NOMAD_TOKEN=${nomad_token_id}
CONSUL_TOKEN=${consul_token_id}
VAULT_TOKEN=${vault_token_id}

TOKEN=$(curl -X PUT "http://instance-data/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
IP_ADDRESS=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://instance-data/latest/meta-data/local-ipv4)

### Funções de Utilitários ###
log() {
    echo -e "\n- $1\n"
}

retry() {
    local cmd="$1"
    local retries=5
    local count=0
    until eval "$cmd"; do
        ((count++))
        if [ $count -ge $retries ]; then
            echo "Falhou após $retries tentativas: $cmd"
            return 1
        fi
        sleep 5
    done
    return 0
}


install_dependencies() {
    log "Instalando dependências..."
    sudo apt-get update
    sudo apt-get install -y awscli unzip jq curl software-properties-common apt-transport-https ca-certificates gnupg2 wget tar
}

install_tool() {
    local tool=$1
    local version=$2
    local download_url="https://releases.hashicorp.com/$${tool}/$${version}/$${tool}_$${version}_linux_amd64.zip"
    local config_dir="/etc/${tool}.d"
    local bin_dir="/opt/${tool}"

    log "Instalando $tool versão $version..."
    retry "curl -L \"$download_url\" -o \"${tool}.zip\""
    sudo unzip -o "${tool}.zip" -d /usr/local/bin
    sudo chmod 0755 /usr/local/bin/$tool
}

install_node_exporter() {
    log "Instalando Node Exporter..."
    retry "wget -q \"https://github.com/prometheus/node_exporter/releases/download/v$${NODE_EXPORTER_VERSION}/node_exporter-$${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz\" -O /tmp/node_exporter.tar.gz"
    sudo tar -xzf /tmp/node_exporter.tar.gz -C /tmp
    sudo mv /tmp/node_exporter-$${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter /usr/local/bin/
    sudo useradd --no-create-home --shell /usr/sbin/nologin $USER || true
    sudo chown $USER:$USER /usr/local/bin/node_exporter

    sudo cp "$CONFIGDIR/node_exporter.service" /etc/systemd/system/node_exporter.service

    sudo systemctl daemon-reload
    retry "sudo systemctl enable node_exporter"
    retry "sudo systemctl start node_exporter"
}


install_promtail() {
    log "Instalando Promtail..."
    wget https://github.com/grafana/loki/releases/download/v2.8.2/promtail-linux-amd64.zip
    unzip promtail-linux-amd64.zip
    sudo mv promtail-linux-amd64 /usr/local/bin/promtail
    sudo chmod +x /usr/local/bin/promtail
    sudo mkdir -p "$PROMTAIL_DIR"
    sudo chmod 755 "$PROMTAIL_DIR"

    sudo sed -i "s/HOSTNAME/$IP_ADDRESS/g" "$CONFIGDIR/promtail.yaml"
    sudo cp "$CONFIGDIR/promtail.yaml" "$PROMTAIL_DIR"
    sudo cp "$CONFIGDIR/promtail.service" /etc/systemd/system/promtail.service


    sudo systemctl daemon-reload
    sudo systemctl enable promtail
    sudo systemctl start promtail
}

configure_nomad() {
    log "Configurando Nomad..."
    sudo mkdir -p "$NOMAD_CONFIG_DIR" "$NOMAD_DIR"
    sudo chmod 755 "$NOMAD_CONFIG_DIR" "$NOMAD_DIR"
    sudo sed -i "s/CONSUL_TOKEN/$NOMAD_TOKEN/g" "$CONFIGDIR/nomad_client.hcl"
    sed -i "s/SERVER_COUNT/$SERVER_COUNT/g" "$CONFIGDIR/nomad_client.hcl"
    sed -i "s/RETRY_JOIN/$RETRY_JOIN/g" "$CONFIGDIR/nomad_client.hcl"
    sed -i "s/IP_ADDRESS/$IP_ADDRESS/g" "$CONFIGDIR/nomad_client.hcl"
    sudo cp "$CONFIGDIR/nomad_client.hcl" "$NOMAD_CONFIG_DIR"
    sudo cp "$CONFIGDIR/nomad.service" /etc/systemd/system/nomad.service

    sudo systemctl enable nomad.service
    sudo systemctl start nomad.service
}

configure_consul(){
    log "Configurando Consul..."
    sudo mkdir -p "$CONSUL_CONFIG_DIR" "$CONSUL_DIR"
    sudo chmod 755 "$CONSUL_CONFIG_DIR" "$CONSUL_DIR"
    sed -i "s/RETRY_JOIN/$RETRY_JOIN/g" "$CONFIGDIR/consul_client.hcl"
    sed -i "s/IP_ADDRESS/$IP_ADDRESS/g" "$CONFIGDIR/consul_client.hcl"
    sed -i "s/CONSUL_TOKEN/$CONSUL_TOKEN/g" "$CONFIGDIR/consul_client.hcl"
    sudo cp "$CONFIGDIR/consul_client.hcl" "$CONSUL_CONFIG_DIR"
    sudo cp "$CONFIGDIR/consul.service" /etc/systemd/system/consul.service
    sudo cp "$CONFIGDIR/promtail-consul.json" /etc/consul.d/promtail.json
    sudo cp "$CONFIGDIR/consul-exporter.json" /etc/consul.d/node-exporter.json

    sudo systemctl enable consul.service
    sudo systemctl start consul.service
}

configure_vault() {
    log "Configurando Vault..."
    sudo mkdir -p "$VAULT_CONFIG_DIR" "$VAULT_DIR"
    sudo chmod 755 "$VAULT_CONFIG_DIR" "$VAULT_DIR"
    sed -i "s/IP_ADDRESS/$IP_ADDRESS/g" "$CONFIGDIR/vault.hcl"
    sed -i "s/VAULT_TOKEN/$VAULT_TOKEN/g" "$CONFIGDIR/vault.hcl"
    sed -i "s/RETRY_JOIN/$RETRY_JOIN/g" "$CONFIGDIR/vault.hcl"

    sudo cp "$CONFIGDIR/vault.hcl" "$VAULT_CONFIG_DIR"
    sudo cp "$CONFIGDIR/vault.service" /etc/systemd/system/vault.service

    sudo groupadd vault

    sudo useradd -r -g vault -d $VAULT_DIR -s /bin/false vault

    sudo mkdir -p /opt/vault/logs
    sudo chown vault:vault /opt/vault/logs
    sudo chmod 750 /opt/vault/logs

    sudo chown -R vault:vault $VAULT_DIR
    sudo chown -R vault:vault $VAULT_CONFIG_DIR

    sudo systemctl enable vault.service
    sudo systemctl start vault.service
    export VAULT_ADDR=http://127.0.0.1:8200
}

install_docker(){
  log "Instalando Docker de forma segura..."

  retry "sudo apt-get update"
  retry "sudo apt-get install -y ca-certificates curl gnupg lsb-release"

  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

  sudo chmod a+r /etc/apt/keyrings/docker.gpg

  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  retry "sudo apt-get update"
  retry "sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"

  retry "sudo systemctl enable docker"
  retry "sudo systemctl start docker"
}

prepare_monitoring_directories() {
    for dir in /opt/grafana /opt/loki /opt/prometheus; do
        sudo mkdir -p $dir
        sudo chown -R 472:472 $dir
        sudo chmod -R 777 $dir
    done
    sudo mkdir -p /opt/jupyter
    sudo chown -R 1000:100 /opt/jupyter   
    sudo chmod -R 775 /opt/jupyter        

}

configure_dns() {
    log "Configurando DNS para resolver Consul..."
    local CONFIG_DIR="/etc/systemd/resolved.conf.d"
    local CONFIG_FILE="$CONFIG_DIR/consul.conf"

    sudo mkdir -p "$CONFIG_DIR"
    sudo tee "$CONFIG_FILE" > /dev/null <<EOF
[Resolve]
DNS=127.0.0.1:8600
DNSSEC=false
Domains=~consul
EOF

    sudo systemctl restart systemd-resolved
    resolvectl status | grep -A 5 "DNS Servers" || echo "Verificação DNS falhou"
}

unseal_vault(){
    log "Tentando desselar o Vault automaticamente..."
    sleep 15
    export CONSUL_HTTP_TOKEN="$CONSUL_TOKEN"
    export CONSUL_HTTP_ADDR=http://127.0.0.1:8500

    export VAULT_ADDR=http://127.0.0.1:8200
    export VAULT_TOKEN=$(consul kv get creds/vault/root-token)

    # Recupera as chaves do Consul
    UNSEAL_KEY_1=$(consul kv get creds/vault/unseal-key-1)
    UNSEAL_KEY_2=$(consul kv get creds/vault/unseal-key-2)
    UNSEAL_KEY_3=$(consul kv get creds/vault/unseal-key-3)

    # Verifica o status do Vault
    if vault status | grep -q 'sealed.*true'; then
        log "Vault está selado. Iniciando processo de desselamento..."
        vault operator unseal "$UNSEAL_KEY_1"
        vault operator unseal "$UNSEAL_KEY_2"
        vault operator unseal "$UNSEAL_KEY_3"
    else
        log "Vault já está desselado."
    fi

}

wait_nomad_leader() {
    log "Aguardando Nomad encontrar um líder..."
    for i in {1..9}; do
        sleep 2
        LEADER=$(nomad operator raft list-peers | grep leader || true)
        if [ -n "$LEADER" ]; then
            echo "Líder encontrado: $LEADER"
            break
        fi
    done
}

finalize_environment() {
  echo "127.0.0.1 $(hostname)" | sudo tee --append /etc/hosts
  echo "export NOMAD_ADDR=http://$IP_ADDRESS:4646" | sudo tee --append "$HOME_DIR/.bashrc"
  echo "export CONSUL_HTTP_ADDR=http://$IP_ADDRESS:8500" | sudo tee --append "$HOME_DIR/.bashrc"
  echo "export VAULT_ADDR=http://$IP_ADDRESS:8200" | sudo tee --append "$HOME_DIR/.bashrc"
  log "Configuração completa! Nomad, Docker, Vault e Prometheus stack configurados com sucesso."
}

main() {
    install_dependencies
    install_tool "nomad" "$NOMAD_VERSION"
    install_tool "consul" "$CONSUL_VERSION"
    install_tool "vault" "$VAULT_VERSION"

    install_node_exporter
    install_promtail
    install_docker

    configure_consul
    configure_nomad
    configure_vault

    prepare_monitoring_directories
    configure_dns
    unseal_vault
    wait_nomad_leader
    finalize_environment
}

main
