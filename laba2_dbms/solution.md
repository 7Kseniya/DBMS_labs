# АСУБД. Лабораторная работа №2 
[полный текст задания](./full_task.md)

## Этап 1. Инициализация кластера БД
#### подключаемся к серверу и узлу через ssh 
```bash
ssh -J s368231@helios.cs.ifmo.ru:2222 postgres0@pg180
```

    Директория кластера: `$HOME/ckf15`
    Кодировка: UTF8
    Локаль: английская
    Параметры инициализации задать через аргументы команды
    
#### создаем директорию кластера
```bash
mkdir -p $HOME/ckf15 || echo "Ошибка: не удалось создать каталог $HOME/ckf15";
# устанавливаем владельца каталога 
chown postgres0 $HOME/ckf15 
```
#### создаем директорию для WAL файлов
- Директория WAL файлов: `$HOME/roi68`

```bash
mkdir -p $HOME/roi68 || echo "Ошибка: не удалось создать каталог $HOME/roi68";
# устанавливаем владельца каталога 
chown postgres0 $HOME/roi68
```
#### инициализация сервера 
```bash 
initdb -D $HOME/ckf15 -E UTF8 --locale=en_US.UTF-8 --waldir=$HOME/roi68 || echo "Ошибка инициализации" ;
```
#### запуск сервера
```bash
pg_ctl -D $HOME/ckf15 -l $HOME/ckf15/postgres.log start
```
---

## Этап 2. Конфигурация и запуск сервера БД

#### настройка способов подключения 
    Unix-domain сокет в режиме `peer`
    сокет TCP/IP, принимать подключения к **любому** IP-адресу узла
    Номер порта: `9392`
    Способ аутентификации TCP/IP клиентов: **по паролю в открытом виде**
    Остальные способы подключений запретить.

#### настройка параметров со сценарием OLTP
с 500 транзакциями в секунду (TPS), размером транзакций 32КБ, и требованием высокой доступности данных

**OLTP (Online Transaction Processing)** — это тип системы, предназначенной для обработки транзакций в реальном времени. 
Основные характеристики OLTP-систем:

**Реальное время:** OLTP-системы обрабатывают транзакции в реальном времени, обеспечивая мгновенное обновление данных.
**Высокая производительность:** Эти системы оптимизированы для выполнения большого количества транзакций в единицу времени.
**Надежность:** OLTP-системы должны быть высоконадежными, так как ошибки в обработке транзакций могут привести к серьезным последствиям.
**Целостность данных:** Важно обеспечить целостность данных, чтобы транзакции были завершены корректно и без потерь.
**Масштабируемость:** OLTP-системы должны быть способны масштабироваться для обработки увеличивающегося объема транзакций.

---

**1. `max_connections`**
- **Описание:** Максимальное количество подключений к базе данных.
- **Значение:** `100`

**2. `shared_buffers`**
- **Описание:** Размер памяти, выделенной для буферов PostgreSQL
-  Обычно используется 25–40% от общей оперативной памяти сервера  
- **Значение:** `25% от RAM`  
  если сервер имеет 16 ГБ ОЗУ:  
  **`shared_buffers = 4GB`**

**3. `temp_buffers`**
- **Описание:** Буферы для временных таблиц, которые используются внутри транзакций
- Учитывая небольшой размер транзакций и высокую частоту, не стоит устанавливать большое значение.  
- **Значение:** `16MB`

**4. `work_mem`**
- **Описание:** Память для выполнения операций сортировки и хеширования. Настраивается для каждой сессии.
- **Значение:** `16MB`  

**5. `checkpoint_timeout`**
- **Описание:** Интервал времени между контрольными точками
- OLTP требует минимальных задержек, а частые контрольные точки обеспечивают меньшую потерю данных в случае сбоя. Однако слишком короткие интервалы увеличивают нагрузку на дисковую подсистему.  
- **Значение:** `5 minutes`

**6. `effective_cache_size`**
- **Описание:** Размер файловой системы, который PostgreSQL предполагает доступным для кэширования
- Устанавливается примерно как 50–75% от общей оперативной памяти. Это значение влияет на планировщик запросов.  
- **Значение:** `12GB` (для сервера с 16 ГБ RAM).

**7. `fsync`**
- **Описание:** Контролирует, записывает ли PostgreSQL изменения на диск при каждой транзакции
- Для обеспечения высокой доступности данных этот параметр **должен быть включён**
- **Значение:** `on`

**8. `commit_delay`**
- **Описание:** Задержка перед записью транзакции в WAL
- Для OLTP важна минимальная задержка.  
  **Значение:** `0`

---

**Резюме настроек**
```conf
max_connections = 100
shared_buffers = 4GB
temp_buffers = 16MB
work_mem = 4MB
checkpoint_timeout = 5min
effective_cache_size = 12GB
fsync = on
commit_delay = 0
```

---
```bash
# === Этап 2: Конфигурация сервера БД ===

echo "добавление изменений в конфигурацию..."
# Для локальных подключений по паролю
sed -i '' 's/^local[[:space:]]*all[[:space:]]*all[[:space:]]*trust$/local   all             all                                     peer/' $HOME/ckf15/pg_hba.conf
sed -i '' 's|^host[[:space:]]*all[[:space:]]*all[[:space:]]*127.0.0.1/32[[:space:]]*trust$|host    all             all             0.0.0.0/0               password|' $HOME/ckf15/pg_hba.conf
sed -i '' 's|^host[[:space:]]*all[[:space:]]*all[[:space:]]*::1/128[[:space:]]*trust$|host    all             all             ::/0                    password|' $HOME/ckf15/pg_hba.conf
# проверка внесенных изменений 
grep "^local" $HOME/ckf15/pg_hba.conf
grep "^host" $HOME/ckf15/pg_hba.conf

# addresses and port
echo "конфигурирование postgresql.conf..."
sed -i '' "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" $HOME/ckf15/postgresql.conf
sed -i '' "s/#port = 5432/port = 9392/g" $HOME/ckf15/postgresql.conf
grep "listen_addresses" $HOME/ckf15/postgresql.conf 
grep "port" $HOME/ckf15/postgresql.conf

# настройка параметров со сценарием OLTP
# sed -i '' "s/#max_connections = 100/max_connections = 100/" $HOME/ckf15/postgresql.conf
sed -i '' "s/#shared_buffers = 128MB/shared_buffers = 4GB/" $HOME/ckf15/postgresql.conf
sed -i '' "s/#temp_buffers = 8MB/temp_buffers = 16MB/" $HOME/ckf15/postgresql.conf
sed -i '' "s/#work_mem = 4MB/work_mem = 16MB/" $HOME/ckf15/postgresql.conf
sed -i '' "s/#checkpoint_timeout = 5min/checkpoint_timeout = 5min/" $HOME/ckf15/postgresql.conf
sed -i '' "s/#effective_cache_size = 4GB/effective_cache_size = 12GB/" $HOME/ckf15/postgresql.conf
sed -i '' "s/#fsync = on/fsync = on/" $HOME/ckf15/postgresql.conf
sed -i '' "s/#commit_delay = 0/commit_delay = 0/" $HOME/ckf15/postgresql.conf

# Логирование
sed -i '' "s/#log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'/log_filename = 'postgresql-%a.csv'/" $HOME/ckf15/postgresql.conf
sed -i '' "s/#log_statement = 'none'/log_statement = 'all'/" $HOME/ckf15/postgresql.conf
sed -i '' "s/#log_min_messages = warning/log_min_messages = info/" $HOME/ckf15/postgresql.conf
sed -i '' "s/#log_connections = off/log_connections = on/" $HOME/ckf15/postgresql.conf
sed -i '' "s/#log_disconnections = off/log_disconnections = on/" $HOME/ckf15/postgresql.conf
sed -i '' "s/#log_destination = 'stderr'/log_destination = 'csvlog'/" $HOME/ckf15/postgresql.conf
sed -i '' "s/#logging_collector = off/logging_collector = on/" $HOME/ckf15/postgresql.conf

echo "параметры успешно обновлены"

echo "Установка владельца для конфигов..."
chown postgres0 $HOME/ckf15/postgresql.conf || echo "Не удалось изменить владельца postgresql.conf"
chown postgres0 $HOME/ckf15/pg_hba.conf || echo "Не удалось изменить владельца pg_hba.conf"

# проверка конфигов 
ls -l $HOME/ckf15/postgresql.conf
ls -l $HOME/ckf15/pg_hba.conf

# перезапуск
echo "перезапуск сервера для применения изменений..."
pg_ctl -D $HOME/ckf15 restart || echo "Ошибка перезапуска сервера";
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
psql -h pg180 -p 9392 -d evilyellowsong -U evilyellowrole -c "
CREATE SCHEMA IF NOT EXISTS test_schema;
CREATE TABLE IF NOT EXISTS test_schema.test_table (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50),
    value INTEGER
);
INSERT INTO test_schema.test_table (name, value) VALUES
('test1', 1),
('test2', 2),
('test3', 3);
" || echo "Ошибка наполения базы";

echo "список табличных пространств и объектов: "
psql -p 9392 -d evilyellowsong -c "\db+"
psql -h pg180 -p 9392 -d evilyellowsong -U evilyellowrole -c "\dt+ test_schema.*"

psql -h pg180 -p 9392 -d evilyellowsong -U evilyellowrole

# завершение работы 
if [ $? -eq 0 ]; then
    echo "сервер настроен и готов к работе ура"
else
    echo "Ошибка подключения к базе данных"
fi
```

---


#### запросы 

```sql
SELECT * FROM pg_catalog.pg_tables WHERE tableowner = 'evilyellowrole';
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

объекты, созданные новым пользователем
```sql
SELECT
    relname, spcname AS tablespace
FROM
    pg_class LEFT JOIN pg_tablespace ON pg_tablespace.oid = reltablespace
WHERE
    relowner = (SELECT oid FROM pg_roles WHERE rolname = 'evilyellowrole');
```
