#(10258)Como Começar: Criar e Gerenciar Recursos de Nuvem: laboratório com desafio

# Preparando o ambiente
gcloud auth list
gcloud config list project



# Tarefa 1: crie uma instância para o projeto jumphost
gcloud compute instances create nucleus-jumphost --machine-type f1-micro --zone us-east1-b
#debian-9-stretch-v20210217


# Tarefa 2: crie um cluster de serviço do Kubernetes
gcloud config set compute/zone us-east1-b

# 2.1: Crie um cluster (na região us-east1) para hospedar o serviço
gcloud container clusters create nucleus-webserver1
gcloud container clusters get-credentials nucleus-webserver1

# 2.2: Usar o contêiner do Docker "hello-app" ("gcr.io/google-samples/hello-app:2.0") 
# como marcador (a equipe substituirá o contêiner pelo trabalho dela)
kubectl create deployment hello-app --image=gcr.io/google-samples/hello-app:2.0

# 2.3: Expor o app na porta 8080
kubectl expose deployment hello-app --type=LoadBalancer --port 8080

kubectl get service # Rodar até o hello-app ter um EXTERNAL-IP


# Tarefa 3: configure um balanceador de carga HTTP
cat << EOF > startup.sh
#! /bin/bash
apt-get update
apt-get install -y nginx
service nginx start
sed -i -- 's/nginx/Google Cloud Platform - '"\$HOSTNAME"'/' /var/www/html/index.nginx-debian.html
EOF


# 3.1: Criar um modelo de instância
gcloud compute instance-templates create nginx-template \
--metadata-from-file startup-script=startup.sh


# 3.2: Criar um pool de destino
gcloud compute target-pools create nginx-pool
# Selecionar opção (n) SE a opção padrão não for us-east1
# Selecionar a região us-east1, o número pode variar, no meu caso é 19


# 3.3: Criar um grupo de instâncias gerenciadas
gcloud compute instance-groups managed create nginx-group \
--base-instance-name nginx \
--size 2 \
--template nginx-template \
--target-pool nginx-pool

gcloud compute instances list


# 3.4: Criar uma regra de firewall para permitir tráfego (80/tcp)
gcloud compute firewall-rules create www-firewall --allow tcp:80

gcloud compute forwarding-rules create nginx-lb \
--region us-east1 \
--ports=80 \
--target-pool nginx-pool

gcloud compute forwarding-rules list


# 3.5: Criar uma verificação de integridade
gcloud compute http-health-checks create http-basic-check

gcloud compute instance-groups managed \
set-named-ports nginx-group \
--named-ports http:80


# 3.6: Criar um serviço de back-end e conectar o grupo de instâncias gerenciadas
gcloud compute backend-services create nginx-backend \
--protocol HTTP --http-health-checks http-basic-check --global

gcloud compute backend-services add-backend nginx-backend \
--instance-group nginx-group \
--instance-group-zone us-east1-b \
--global


# 3.7: Criar um mapa de URL e direcionar o proxy HTTP para encaminhar solicitações ao mapa
gcloud compute url-maps create web-map \
--default-service nginx-backend

gcloud compute target-http-proxies create http-lb-proxy \
--url-map web-map

# 3.8: Criar uma regra de encaminhamento
gcloud compute forwarding-rules create http-content-rule \
--global \
--target-http-proxy http-lb-proxy \
--ports 80

gcloud compute forwarding-rules list