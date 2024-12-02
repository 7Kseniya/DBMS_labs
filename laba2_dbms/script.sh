#!/bin/bash

# лабораторная работа №2 - вариант 348392

# === Параметры подключения ===
NODE="pg180"
USER="postgres0"
PASSWORD="2zjDzmt0"
PORT=9392
CLUSTER_DIR="$HOME/ckf15"
WAL_DIR="$HOME/roi68"
TEMPLATE_DIR="$HOME/het47"
DB_NAME="evilyellowsong"
ROLE_NAME="evilyellowrole"
PROXY="s368231@helios.cs.ifmo.ru:2222"

# подключение к узлу через ssh
echo "подключение к узлу $NODE..."
ssh -J $PROXY $USER@$NODE << EOF

# === Этап 1: Инициализация кластера БД ===
# создание директории для кластера и инициализация 
echo "инициализация кластера в $CLUSTER_DIR..."
mkdir -p $CLUSTER_DIR
initdb -D $CLUSTER_DIR -E UTF8 --locale=en_US.UTF-8 

# создание директории для WAL файлов 
mkdir -p $WAL_DIR 

# === Этап 2: Конфигурация сервера БД ===
POSTGRESQL_CONF="$CLUSTER_DIR/postgresql.conf"
PG_HBA_CONF="$CLUSTER_DIR/pg_hba.conf"

echo "конфигурирование postgresql.conf..."
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" $POSTGRESQL_CONF
sed -i "s/#port = 5432/port = $PORT/g" $POSTGRESQL_CONF

# настройка параметров OLTP
cat << CONFIG >> $POSTGRESQL_CONF
listen_addresses = '*'
port = $PORT
max_connections = 200
shared_buffers = 256MB
temp_buffers = 8MB
work_mem = 4MB
checkpoint_timeout = 5min
effective_cache_size = 512MB
fsync = on
commit_delay = 0
wal_level = replica
log_destination = 'csvlog'
logging_collector = on
log_directory = '$WAL_DIR'
log_filename = 'postgresql-%a.log'
log_statement = 'all'
log_min_messages = INFO
log_connections = on
log_disconnections = on
CONFIG

# настройка pg_hba.conf
echo "настройка pg_hba.conf..."
cat << HBA >> $PG_HBA_CONF
# Peer-аутентификация
local   all             all                                     peer
# TCP/IP по паролю
host    all             all             0.0.0.0/0               password
host    all             all             ::/0                    password
HBA

# === Запуск сервера ===
echo "запуск сервера postgres..."
pg_ctl -D $CLUSTER_DIR -l $CLUSTER_DIR/server.log start

# === Этап 3: Табличные пространства и база данных ===
echo "cоздание табличного пространства template1 в $TEMPLATE_DIR..."
mkdir -p $TEMPLATE_DIR
psql -c "CREATE TABLESPACE template_space LOCATION '$TEMPLATE_DIR';"

echo "Перенос template1 в новое табличное пространство..."
psql -c "UPDATE pg_database SET dattablespace = (SELECT oid FROM pg_tablespace WHERE spcname = 'template_space') WHERE datname = 'template1';"

echo "создание базы данных $DB_NAME..."
psql -c "CREATE DATABASE $DB_NAME TABLESPACE template_space;"

echo "создание новой $ROLE_NAME..."
psql -c "CREATE ROLE $ROLE_NAME WITH LOGIN PASSWORD '$PASSWORD';"
psql -c "GRANT CONNECT ON DATABASE $DB_NAME TO $ROLE_NAME;"
psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $ROLE_NAME;"

echo "наполнение базы $DB_NAME тестовыми данными..."
psql -U $ROLE_NAME -d $DB_NAME -c "
CREATE TABLE test_table (
    id SERIAL PRIMARY KEY,
    data TEXT 
);
INSERT INTO test_table (data) VALUES
('test data 1'),
(test data 2),
(test data 3);
"

echo "список табличных пространств и имен: "
psql -c "\db+"
psql -c "\dt+"

# завершение работы 
echo "сервер настроен и готов к работе ура бл"
EOF