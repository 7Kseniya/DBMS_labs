# АСУБД. Лабораторная работа №2 
[полный текст задания](./full_task.md)

## Этап 1. Инициализация кластера БД
подлключаемся к серверу и узлу через ssh 
```bash
ssh -J s368231@helios.cs.ifmo.ru:2222 postgres0@pg180
```

    Директория кластера: `$HOME/ckf15`
    Кодировка: UTF8
    Локаль: английская
    Параметры инициализации задать через аргументы команды
    
создаем директорию кластера и инициализируем базу данных 
```bash
mkdir -p $HOME/ckf15
chown postgres0 $HOME/ckf15
initdb -D $HOME/ckf15 -E UTF8 --locale=en_US.UTF-8 || echo "Ошибка инициализации";
```

создаем директорию для WAL файлов
```bash
mkdir -p $HOME/roi68 
chown postgres0 $HOME/roi68
```

запускаем сервер
```bash
pg_ctl -D $HOME/ckf15 -l $HOME/ckf15/server.log start
```

## Этап 2. Конфигурация и запуск сервера БД

### настройка способов подключения 
    Unix-domain сокет в режиме `peer`
    сокет TCP/IP, принимать подключения к **любому** IP-адресу узла
    Номер порта: `9392`
    Способ аутентификации TCP/IP клиентов: **по паролю в открытом виде**
    Остальные способы подключений запретить.

настройка параметров со сценарием OLTP
```bash
# === Этап 2: Конфигурация сервера БД ===
ls -l $HOME/ckf15/postgresql.conf
ls -l $HOME/ckf15/pg_hba.conf

echo "конфигурирование postgresql.conf..."
sed -i '' "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" $HOME/ckf15/postgresql.conf
sed -i '' "s/#port = 5432/port = 9392/g" $HOME/ckf15/postgresql.conf
grep "listen_addresses" $HOME/ckf15/postgresql.conf 
grep "port" $HOME/ckf15/postgresql.conf

# Для локальных подключений по паролю
sed -i '' 's/^local[[:space:]]*all[[:space:]]*all[[:space:]]*trust$/local   all             all                                     peer/' $HOME/ckf15/pg_hba.conf
grep "^local" $HOME/ckf15/pg_hba.conf

# разрешаем для любого айпишника
sed -i '' 's|^host[[:space:]]*all[[:space:]]*all[[:space:]]*127.0.0.1/32[[:space:]]*trust$|host    all             all             0.0.0.0/0               password|' $HOME/ckf15/pg_hba.conf
sed -i '' 's|^host[[:space:]]*all[[:space:]]*all[[:space:]]*::1/128[[:space:]]*trust$|host    all             all             ::/0                    password|' $HOME/ckf15/pg_hba.conf
grep "^host" $HOME/ckf15/pg_hba.conf

# настройка параметров со сценарием OLTP
sed -i '' "s/#max_connections = 100/max_connections = 500/" $HOME/ckf15/postgresql.conf
sed -i '' "s/#shared_buffers = 128MB/shared_buffers = 2GB/" $HOME/ckf15/postgresql.conf
sed -i '' "s/#temp_buffers = 8MB/temp_buffers = 32MB/" $HOME/ckf15/postgresql.conf
sed -i '' "s/#work_mem = 4MB/work_mem = 16MB/" $HOME/ckf15/postgresql.conf
sed -i '' "s/#checkpoint_timeout = 5min/checkpoint_timeout = 1min/" $HOME/ckf15/postgresql.conf
sed -i '' "s/#effective_cache_size = 4GB/effective_cache_size = 6GB/" $HOME/ckf15/postgresql.conf
sed -i '' "s/#fsync = on/fsync = on/" $HOME/ckf15/postgresql.conf
sed -i '' "s/#commit_delay = 0/commit_delay = 1000/" $HOME/ckf15/postgresql.conf

# Настройка WAL файлов
sed -i '' "s|#log_directory = 'log'|log_directory = '$HOME/roi68'|" $HOME/ckf15/postgresql.conf
sed -i '' "s/#log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'/log_filename = 'postgresql-%a.csv'/" $HOME/ckf15/postgresql.conf
sed -i '' "s/#wal_level = minimal/wal_level = replica/" $HOME/ckf15/postgresql.conf

# Логирование
sed -i '' "s/#log_statement = 'none'/log_statement = 'all'/" $HOME/ckf15/postgresql.conf
sed -i '' "s/#log_min_messages = warning/log_min_messages = info/" $HOME/ckf15/postgresql.conf
sed -i '' "s/#log_connections = off/log_connections = on/" $HOME/ckf15/postgresql.conf
sed -i '' "s/#log_disconnections = off/log_disconnections = on/" $HOME/ckf15/postgresql.conf
sed -i '' "s/#log_destination = 'stderr'/log_destination = 'csvlog'/" $HOME/ckf15/postgresql.conf
sed -i '' "s/#logging_collector = off/logging_collector = on/" $HOME/ckf15/postgresql.conf

# перезапуск
echo "перезапуск сервера для применения изменений..."
pg_ctl -D $HOME/ckf15 -l $HOME/ckf15/postgres.log restart || echo "Ошибка перезапуска сервера!";

```

```bash

```

## Этап 3. Дополнительные табличные пространства и наполнение базы
```bash
# === Этап 3: Табличные пространства и база данных ===
echo "cоздание табличного пространства template1 в '$HOME/het47'..."
mkdir -p $HOME/het47
psql -p 9392 -d postgres -c "CREATE TABLESPACE het47 LOCATION '$HOME/het47';" || echo "Ошибка создания табличного пространства";

echo "пересоздание шаблона template1 в табличном пространстве het47"
psql -p 9392 -d postgres -c "CREATE DATABASE template2 WITH TEMPLATE template1 OWNER postgres0 TABLESPACE het47;" || echo "Ошибка пересоздания шаблона";

echo "создание базы данных 'evilyellowsong'..."
psql -p 9392 -d postgres -c "CREATE DATABASE evilyellowsong TEMPLATE template2;" || echo "Ошибка создания базы данных";

echo "создание новой 'evilyellowrole'... with password 'evil_pass'"
psql -p 9392 -d postgres -c "CREATE ROLE evilyellowrole WITH LOGIN PASSWORD 'evil_pass';" || echo "Ошибка создания роли";
psql -p 9392 -d postgres -c "GRANT CONNECT ON DATABASE evilyellowsong TO evilyellowrole;"
psql -p 9392 -d postgres -c "GRANT ALL PRIVILEGES ON DATABASE evilyellowsong TO evilyellowrole;"

echo "наполнение базы 'evilyellowsong' тестовыми данными..."
psql -p 9392 -d postgres -U evilyellowrole -d evilyellowsong -c "
CREATE TABLE IF NOT EXISTS test_table (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50),
    value INTEGER
);
INSERT INTO test_table (name, value) VALUES
('test1', 1),
('test2', 2),
('test3', 3);
" || echo "Ошибка наполения базы";

echo "список табличных пространств и объектов: "
psql -p 9392 -d postgres -c "\db+"
psql -p 9392 -d postgres -d evilyellowsong -c "\dt+"

psql -h pg180 -p 9392 -d postgres -U evilyellowrole 

# завершение работы 
echo "сервер настроен и готов к работе ура"
```
выводит все объекты в табличных пространствах
```sql
SELECT
    spcname AS tablespace,
    relname
FROM
    pg_class
    JOIN pg_tablespace ON pg_tablespace.oid = reltablespace;
```
выводит список всех табличных пространств в кластере PostgreSQL, содержащиеся в них объекты и базы данных, которые используют эти табличные пространства
```sql
WITH db_tablespaces AS (
    SELECT t.spcname, d.datname
    FROM pg_tablespace t
    JOIN pg_database d ON d.dattablespace = t.oid
)
SELECT 
    t.spcname AS Tablespace, 
    COALESCE(string_agg(DISTINCT c.relname, E'\n'), 'No objects') AS bjects
FROM 
    pg_tablespace t
LEFT JOIN 
    pg_class c ON c.reltablespace = t.oid OR (c.reltablespace = 0 AND t.spcname = 'pg_default')
LEFT JOIN 
    db_tablespaces db ON t.spcname = db.spcname
GROUP BY 
    t.spcname
ORDER BY 
    t.spcname;
```
sed снести 
подложить конфиг