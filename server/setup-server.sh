#!/bin/bash
# GB Messenger - Полный скрипт развёртывания
# Для закрытого мессенджера (семья/родственники)
# Запускать на сервере под root

set -e

echo "======================================"
echo "GB Messenger - Установка на сервер"
echo "======================================"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Получить IP сервера
SERVER_IP=$(curl -s ifconfig.me)
echo -e "${GREEN}IP сервера: $SERVER_IP${NC}"

# 1. Обновление системы
echo -e "\n${YELLOW}[1/7] Обновление системы...${NC}"
apt update && apt upgrade -y
apt install -y curl git nano ufw

# 2. Установка Docker
echo -e "\n${YELLOW}[2/7] Установка Docker...${NC}"
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
    echo -e "${GREEN}Docker установлен${NC}"
else
    echo -e "${GREEN}Docker уже установлен${NC}"
fi

# 3. Установка Docker Compose
echo -e "\n${YELLOW}[3/7] Установка Docker Compose...${NC}"
if ! docker compose version &> /dev/null; then
    apt install -y docker-compose-plugin
    echo -e "${GREEN}Docker Compose установлен${NC}"
else
    echo -e "${GREEN}Docker Compose уже установлен${NC}"
fi

# 4. Настройка файрвола
echo -e "\n${YELLOW}[4/7] Настройка файрвола...${NC}"
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 3000/tcp
ufw allow 9000/tcp
ufw --force enable
echo -e "${GREEN}Файрвол настроен${NC}"

# 5. Клонирование репозитория
echo -e "\n${YELLOW}[5/7] Клонирование репозитория...${NC}"
cd /opt
if [ -d "GB_Messenger" ]; then
    cd GB_Messenger
    git pull
else
    git clone https://github.com/gig077882-cmyk/GB_Messenger.git
    cd GB_Messenger
fi
echo -e "${GREEN}Репозиторий обновлён${NC}"

# 6. Настройка окружения
echo -e "\n${YELLOW}[6/7] Настройка окружения...${NC}"
cd server

# Генерация секретов
generate_secret() {
    openssl rand -hex 32
}

POSTGRES_PASSWORD=$(generate_secret)
REDIS_PASSWORD=$(generate_secret)
JWT_ACCESS_SECRET=$(generate_secret)
JWT_REFRESH_SECRET=$(generate_secret)
ENCRYPTION_KEY=$(generate_secret)
MINIO_SECRET=$(openssl rand -hex 16)

# Создание .env
cat > .env << EOF
NODE_ENV=production
PORT=3000
CORS_ORIGINS=*
SERVER_IP=$SERVER_IP

POSTGRES_PASSWORD=$POSTGRES_PASSWORD
REDIS_PASSWORD=$REDIS_PASSWORD

MINIO_ACCESS_KEY=minioadmin
MINIO_SECRET_KEY=$MINIO_SECRET

JWT_ACCESS_SECRET=$JWT_ACCESS_SECRET
JWT_REFRESH_SECRET=$JWT_REFRESH_SECRET
JWT_ACCESS_TTL=15m
JWT_REFRESH_TTL=30d

ENCRYPTION_KEY=$ENCRYPTION_KEY
EOF

echo -e "${GREEN}Секреты сгенерированы и сохранены в .env${NC}"

# 7. Запуск сервисов
echo -e "\n${YELLOW}[7/7] Запуск сервисов...${NC}"
docker compose build --no-cache
docker compose up -d

# Ожидание запуска
echo "Ожидание запуска сервисов..."
sleep 20

# Проверка статуса
echo -e "\n${GREEN}======================================${NC}"
echo -e "${GREEN}Установка завершена!${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo "Сервисы:"
docker compose ps
echo ""
echo "Доступ к мессенджеру:"
echo "  API:    http://$SERVER_IP:3000/api"
echo "  MinIO:  http://$SERVER_IP:9000"
echo ""
echo "Настройка мобильного приложения:"
echo "  API_BASE=http://$SERVER_IP:3000/api"
echo ""
echo "Полезные команды:"
echo "  Логи:       docker compose logs -f"
echo "  Остановить:  docker compose down"
echo "  Перезапуск:  docker compose restart"
echo ""
echo -e "${YELLOW}Сохраните IP: $SERVER_IP${NC}"
