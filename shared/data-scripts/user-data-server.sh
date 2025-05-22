#!/bin/bash

# Redirecionar logs
exec > >(sudo tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

### Variáveis Globais ###
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


# ----------------------------
# Metodos auxiliares
#-----------------------------
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

# ----------------------------
# 1 - pegar o ip da instância
#-----------------------------
get_instance_ip() {
    TOKEN=$(curl -X PUT "http://instance-data/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
    IP_ADDRESS=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://instance-data/latest/meta-data/local-ipv4)
    echo "$IP_ADDRESS"
}

# ----------------------------
# 2 - instalar dependências
#-----------------------------
install_dependencies() {
    log "Instalando dependências..."
    retry "sudo apt-get update"
    retry "sudo apt install -y awscli unzip tree redis-tools jq curl tmux apt-transport-https ca-certificates gnupg2 software-properties-common wget tar"
    sudo apt-get clean
    sudo ufw disable || log "ufw não instalado"
}
# ----------------------------
# 3 - instalar ferramentas Hashicorp
#-----------------------------
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

# ----------------------------
# 4 - instalar o node_exporter
#-----------------------------
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

# ----------------------------
# 5 - instalar o promtail
#-----------------------------
install_promtail() {
    log "Instalando Promtail..."
    retry "wget https://github.com/grafana/loki/releases/download/v2.8.2/promtail-linux-amd64.zip"
    unzip promtail-linux-amd64.zip
    sudo mv promtail-linux-amd64 /usr/local/bin/promtail
    sudo chmod +x /usr/local/bin/promtail
    sudo mkdir -p "$PROMTAIL_DIR"
    sudo chmod 755 "$PROMTAIL_DIR"

    IP_ADDRESS=$(get_instance_ip)
    sudo sed -i "s/HOSTNAME/$IP_ADDRESS/g" "$CONFIGDIR/promtail.yaml"
    sudo cp "$CONFIGDIR/promtail.yaml" "$PROMTAIL_DIR"
    sudo cp "$CONFIGDIR/promtail.service" /etc/systemd/system/promtail.service

    sudo systemctl daemon-reload
    retry "sudo systemctl enable promtail"
    retry "sudo systemctl start promtail"
}

# ----------------------------
# 66 - instalar o docker
#-----------------------------
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

# ----------------------------
# 7 - configurar o nomad
#-----------------------------
configure_nomad(){
  log "Configurando o nomad"
  sudo mkdir -p "$NOMAD_CONFIG_DIR" "$NOMAD_DIR"
  sudo chmod 755 "$NOMAD_CONFIG_DIR" "$NOMAD_DIR"
  sudo sed -i "s/CONSUL_TOKEN/$NOMAD_TOKEN/g" "$CONFIGDIR/nomad.hcl"
  sed -i "s/SERVER_COUNT/$SERVER_COUNT/g" "$CONFIGDIR/nomad.hcl"
  sed -i "s/RETRY_JOIN/$RETRY_JOIN/g" "$CONFIGDIR/nomad.hcl"
  sed -i "s/IP_ADDRESS/$IP_ADDRESS/g" "$CONFIGDIR/nomad.hcl"
  sudo cp "$CONFIGDIR/nomad.hcl" "$NOMAD_CONFIG_DIR"
  sudo cp "$CONFIGDIR/nomad.service" /etc/systemd/system/nomad.service

  sudo systemctl enable nomad.service
  sudo systemctl start nomad.service
  export NOMAD_ADDR=http://127.0.0.1:4646
}

# ----------------------------
# 8 - configurar o consul
#-----------------------------
configure_consul(){
  log "Configurando o consul"
  sudo mkdir -p "$CONSUL_CONFIG_DIR" "$CONSUL_DIR"
  sudo chmod 755 "$CONSUL_CONFIG_DIR" "$CONSUL_DIR"
  sed -i "s/SERVER_COUNT/$SERVER_COUNT/g" "$CONFIGDIR/consul.hcl"
  sed -i "s/RETRY_JOIN/$RETRY_JOIN/g" "$CONFIGDIR/consul.hcl"
  sed -i "s/IP_ADDRESS/$IP_ADDRESS/g" "$CONFIGDIR/consul.hcl"
  sed -i "s/CONSUL_TOKEN/$CONSUL_TOKEN/g" "$CONFIGDIR/consul.hcl"
  sudo cp "$CONFIGDIR/consul.hcl" "$CONSUL_CONFIG_DIR"
  sudo cp "$CONFIGDIR/consul.service" /etc/systemd/system/consul.service
  sudo cp "$CONFIGDIR/promtail-consul.json" /etc/consul.d/promtail.json
  sudo cp "$CONFIGDIR/consul-exporter.json" /etc/consul.d/node-exporter.json

  sudo systemctl enable consul.service
  sudo systemctl start consul.service
  export CONSUL_ADDR=http://127.0.0.1:8500
}

# ----------------------------
# 9 - configurar o vault
#-----------------------------
configure_vault(){
  log "Configurando o vault"
  sudo mkdir -p "$VAULT_CONFIG_DIR" "$VAULT_DIR"
  sudo chmod 755 "$VAULT_CONFIG_DIR" "$VAULT_DIR"
  sed -i "s/RETRY_JOIN/$RETRY_JOIN/g" "$CONFIGDIR/vault.hcl"
  sed -i "s/IP_ADDRESS/$IP_ADDRESS/g" "$CONFIGDIR/vault.hcl"
  sed -i "s/VAULT_TOKEN/$VAULT_TOKEN/g" "$CONFIGDIR/vault.hcl"
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

# ----------------------------
# 10 - configurar o network
#-----------------------------
configure_network(){
  # Adicionar IP ao /etc/hosts
  echo "127.0.0.1 $(hostname)" | sudo tee --append /etc/hosts
  echo "export NOMAD_ADDR=http://$IP_ADDRESS:4646" | sudo tee --append "$HOME_DIR/.bashrc"
  echo "export CONSUL_ADDR=http://$IP_ADDRESS:8500" | sudo tee --append "$HOME_DIR/.bashrc"
  echo "export VAULT_ADDR=http://$IP_ADDRESS:8200" | sudo tee --append "$HOME_DIR/.bashrc"
}

# ----------------------------
# 11 - configurar o bootstrap do consul
#-----------------------------
setup_consul_bootstrap(){
  log "Aguardando Consul iniciar..."
  until curl -s http://127.0.0.1:8500/v1/status/leader | grep -q '"'; do
    log "Consul ainda não está pronto..."
    sleep 5
  done

  log "Bootstrap do ACL Consul..."
  BOOTSTRAP_OUTPUT=$(consul acl bootstrap -format=json || true)

  if echo "$BOOTSTRAP_OUTPUT" | grep -q 'SecretID'; then
      MGMT_TOKEN=$(echo "$BOOTSTRAP_OUTPUT" | jq -r '.SecretID')
      export CONSUL_HTTP_TOKEN=$MGMT_TOKEN
      echo "$MGMT_TOKEN" > consul-mgmt-token.txt
      log "Bootstrap do ACL concluído. Token salvo."
  else
      log "Consul ACL já bootstrapped ou ocorreu erro. Verifique logs."
      export CONSUL_HTTP_TOKEN=$(cat consul-mgmt-token.txt 2>/dev/null)
  fi
}

# ----------------------------
# 12 - configurar as politicas do consul
#-----------------------------
setup_policies_consul() {
    log "Criando as políticas do Consul..."

    retry "consul acl policy create -name 'nomad-policy' -rules @$CONSULPOLICYDIR/nomad-policy.hcl"
    retry "consul acl token create -description 'Token do Nomad' -policy-name 'nomad-policy' -secret $NOMAD_TOKEN"

    retry "consul acl policy create -name 'admin-policy' -rules @$CONSULPOLICYDIR/admin-policy.hcl"
    retry "consul acl token create -description 'Token de admin' -policy-name 'admin-policy' -secret $CONSUL_TOKEN"

    retry "consul acl policy create -name 'vault-policy' -rules @$CONSULPOLICYDIR/vault-policy.hcl"
    retry "consul acl token create -description 'Token de acesso do vault' -policy-name 'vault-policy' -secret $VAULT_TOKEN"
}

# ----------------------------
# 13 - init e unseal do vault
#-----------------------------
setup_vault() {
  log "Inicializando e deselando Vault..."
  retry "curl -s $VAULT_ADDR/v1/sys/seal-status"

  if ! vault status | grep -q 'Initialized.*true'; then
    INIT_OUTPUT=$(vault operator init -format=json)
    for i in {0..2}; do
      echo "$INIT_OUTPUT" | jq -r ".unseal_keys_b64[$i]" > "vault-unseal-key-$((i+1)).txt"
    done
    echo "$INIT_OUTPUT" | jq -r '.root_token' > vault-root-token.txt
  fi

  export VAULT_TOKEN=$(cat vault-root-token.txt)
  for i in {1..3}; do
    vault operator unseal "$(cat vault-unseal-key-$i.txt)"
  done

  if ! vault status | grep -q "Leader true"; then
    echo "Este nó não é o líder do cluster Vault. Redirecionando para o líder..."
    LEADER_ADDR=$(curl -s http://127.0.0.1:8200/v1/sys/leader | jq -r '.leader_address')
    export VAULT_ADDR=$LEADER_ADDR
    echo "Conectado ao líder do Vault: $LEADER_ADDR"
  fi  
}


# ----------------------------
# 14 - configurar as politicas do vault
# ----------------------------
setup_policies_vault(){
    log "Configurando as politicas do vault"
    vault policy write nomad-server $VAULTPOLICYDIR/nomad-server-policy.hcl
    vault write /auth/token/roles/nomad-cluster @$VAULTPOLICYDIR/nomad-cluster-role.json
    vault policy write prometheus-metrics $VAULTPOLICYDIR/prometheus-metrics-policy.hcl
    vault policy write boundary-kms-policy $VAULTPOLICYDIR/boundary-kms-policy.hcl
    vault policy write boundary-worker-policy $VAULTPOLICYDIR/boundary-worker-policy.hcl
}

# ----------------------------
# 15 - CONFIGURAR TRANSIT ENGINE
# ----------------------------
setup_transit_engine() {
  log "Habilitando engine Transit e criando chave..."
  vault secrets enable transit || true
  vault write -f transit/keys/boundary-root
  vault write -f transit/keys/boundary-worker-auth

  vault policy write boundary-kms-policy boundary-kms-policy.hcl
  BOUNDARY_TOKEN=$(vault token create -policy="boundary-kms-policy" -ttl=8862h -format=json | jq -r .auth.client_token)
  echo $BOUNDARY_TOKEN > boundary_token.txt
  export BOUNDARY_TOKEN=$(cat boundary_token.txt)
}

# ----------------------------
# 16 - CONFIGURAR AUTH METHOD VAULT
#-----------------------------
setup_auth_method() {
  log "Configurando método de autenticação do Vault..."
  vault auth enable aws
  vault write auth/aws/config/client \
    region="us-east-1"
  vault write auth/aws/role/boundary-worker-role \
    auth_type=ec2 \
    bound_iam_instance_profile_arn="arn:aws:iam::590183856996:instance-profile/LabInstanceProfile" \
    policies="boundary-worker-policy"
}

# ----------------------------
# 17 - CONFIGURAR AUTH METHOD VAULT
#-----------------------------
handle_vault_leader() {
  log "Verificando se este nó é o líder do Vault..."
  if ! vault status | grep -q "Leader true"; then
    log "Este nó não é o líder. Redirecionando para o líder..."
    LEADER_ADDR=$(curl -s http://127.0.0.1:8200/v1/sys/leader | jq -r '.leader_address')
    export VAULT_ADDR=$LEADER_ADDR
    log "Conectado ao líder do Vault: $LEADER_ADDR"

    log "Gerando token para Nomad..."
    VAULT_TOKEN=$(vault token create -policy nomad-server -format=json | jq -r '.auth.client_token')
    echo "$VAULT_TOKEN" > nomad-vault-token.txt

    log "Gravando tokens no Consul KV..."
    consul kv put creds/vault/vault-token "$VAULT_TOKEN"
    retry "consul kv put creds/vault/root-token $(cat vault-root-token.txt)"
    retry "consul kv put creds/vault/unseal-key-1 $(cat vault-unseal-key-1.txt)"
    retry "consul kv put creds/vault/unseal-key-2 $(cat vault-unseal-key-2.txt)"
    retry "consul kv put creds/vault/unseal-key-3 $(cat vault-unseal-key-3.txt)"

  else
    log "Este nó já é o líder. Utilizando tokens locais..."
    VAULT_TOKEN=$(cat vault-root-token.txt)
  fi

  export VAULT_TOKEN
  sudo sed -i "s/VAULT_TOKEN/$VAULT_TOKEN/g" "$NOMAD_CONFIG_DIR/nomad.hcl"
}

# ----------------------------
# 18 - CONFIGURAR DNS
#-----------------------------
configure_dns() {
  log "Configurando DNS para resolver Consul..."

  CONFIG_DIR="/etc/systemd/resolved.conf.d"
  CONFIG_FILE="$CONFIG_DIR/consul.conf"

  sudo mkdir -p "$CONFIG_DIR"

  sudo bash -c "cat > $CONFIG_FILE <<EOF
[Resolve]
DNS=127.0.0.1:8600
DNSSEC=false
Domains=~consul
EOF
"

  sudo systemctl restart systemd-resolved
  resolvectl status | grep -A 5 "DNS Servers" || echo "Verificação DNS falhou"
}

# ----------------------------
# 19 - FINALIZAR CONFIGURAÇÃO
#-----------------------------
finalize_configuration() {
  log "Finalizando configuração dos serviços..."

  for svc in consul nomad promtail; do
    retry "sudo systemctl restart $svc"
  done

  log "Verificando status dos serviços:"
  for svc in consul nomad; do
    sudo systemctl status $svc --no-pager || echo "Erro ao iniciar $svc"
  done

  log "Configuração completa."
}

### MAIN ###
main() {
  log "Iniciando configuração..."

  IP_ADDRESS=$(get_instance_ip)
  install_dependencies

  install_tool "nomad" "$NOMAD_VERSION"
  install_tool "consul" "$CONSUL_VERSION"
  install_tool "vault" "$VAULT_VERSION"

  install_node_exporter
  install_promtail
  install_docker

  configure_nomad
  configure_consul
  configure_vault
  configure_network

  setup_consul_bootstrap
  setup_policies_consul
  setup_vault
  setup_policies_vault
  setup_transit_engine
  setup_auth_method
  handle_vault_leader
  configure_dns
  finalize_configuration

  sudo systemctl restart consul
  sudo systemctl restart nomad
  sudo systemctl restart promtail
}

main
