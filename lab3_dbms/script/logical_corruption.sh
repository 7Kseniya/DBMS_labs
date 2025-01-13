#!/bin/bash

# === Этап 4: Логическое повреждение данных и восстановление ===

# Параметры
CURRENT_DATE=$(date "+%Y-%m-%d_%H-%M-%S")
BACKUP_DIR="$HOME/backups"
DUMP_FILE="logical_backup.sql"
PGDATA_DIR="$HOME/ckf15"
RESERVE_HOST="postgres0@pg186"
DB_NAME="evilyellowsong"
DB_USER="evilyellowrole"
LOG_FILE="$HOME/logical_recovery.log"

exec >> "$LOG_FILE" 2>&1
echo "[$CURRENT_DATE] === Начало логического повреждения данных и восстановления ==="

# Добавление данных
echo "Добавление данных..."
psql -U "$DB_USER" -d "$DB_NAME" -c "INSERT INTO test_schema.test_table (name, value) VALUES ('test4', 4), ('test5', 5), ('test6', 6);"
psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT * FROM test_schema.test_table;"

# Симуляция логического сбоя
echo "Симуляция логического сбоя: удаление каждой второй строки"
psql -U "$DB_USER" -d "$DB_NAME" -c "DELETE FROM test_schema.test_table WHERE id % 2 = 0;"
psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT * FROM test_schema.test_table;"

# Создание логического дампа
echo "Создание логического дампа..."
ssh "$RESERVE_HOST" 
pg_dump -U "$DB_USER" -d "$DB_NAME" -f "$BACKUP_DIR/$DUMP_FILE"
if [ $? -ne 0 ]; then
    echo "Ошибка создания логического дампа."
fi

# Копирование дампа на основной узел
echo "Копирование дампа на основной узел..."
scp "$RESERVE_HOST:$BACKUP_DIR/$DUMP_FILE" "$BACKUP_DIR/"
if [ $? -ne 0 ]; then
    echo "Ошибка копирования дампа на основной узел."
fi

# Восстановление из дампа
echo "Восстановление данных из логического дампа..."
pg_restore --clean -U "$DB_USER" -d "$DB_NAME" "$BACKUP_DIR/$DUMP_FILE"
if [ $? -ne 0 ]; then
    echo "Ошибка восстановления данных из логического дампа."
fi

# Проверка
echo "Проверка восстановленных данных..."
psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT * FROM test_schema.test_table;"
echo "[$CURRENT_DATE] === Восстановление завершено ==="
