#!/bin/bash

# === Этап 3: Симуляция повреждения данных и восстановление ===

# Параметры
CURRENT_DATE=$(date "+%Y-%m-%d_%H-%M-%S")
BACKUP_DIR="$HOME/backups"
NEW_TBS_DIR="$HOME/new_het47"
PGDATA="$HOME/ckf15"
RESTORE_DIR="$HOME/restore"
RESERVE_HOST="postgres0@pg186"
LOG_FILE="$HOME/physical_recovery.log"

exec >> "$LOG_FILE" 2>&1
echo "[$CURRENT_DATE] === Начало симуляции повреждения данных и восстановления ==="

# === Симуляция сбоя ===
echo "Симуляция сбоя: удаление данных таблицы test_schema.test_table"
TABLE_DIR=$(psql -d evilyellowsong -U evilyellowrole -t -c "SELECT pg_relation_filepath('test_schema.test_table');" | xargs)
if [-n "$TABLE_DIR" ]; then
    rm -rf "$PGDATA/$TABLE_DIR"
    if [ $? -ne 0 ]; then
        echo "Ошибка: Не удалось удалить директорию таблицы."
    fi
else
    echo "Ошибка: Не удалось получить путь к данным таблицы test_schema.test_table"
fi
# === Проверка работы после сбоя ===
echo "Проверка работоспособности"
pg_ctl -D "$PGDATA" restart
psql -U evilyellowrole -d evilyellowsong -c "SELECT * FROM test_schema.test_table;"

# === Восстановление из резервной копии ===
echo "Восстановление из резервной копии"
LATEST_BACKUP=$(ssh "$RESERVE_HOST" "ls -t $BACKUP_DIR/*.tar.gz | head -n 1")
if [ -z "$LATEST_BACKUP" ]; then
    echo "Ошибка: Нет доступных резервных копий."
fi

# Остановка PostgreSQL
pg_ctl -D "$PGDATA" stop -m fast

# Создание директории для восстановления
mkdir -p "$NEW_TBS_DIR"
chown postgres0:postgres0 "$NEW_TBS_DIR"

# Копирование и распаковка бэкапа
mkdir -p "$RESTORE_DIR"
scp "$RESERVE_HOST:$BACKUP_DIR/$(basename $LATEST_BACKUP)" "$RESTORE_DIR"
tar -xzf "$RESTORE_DIR/$(basename $LATEST_BACKUP)" -C "$PGDATA"
# Корректировка табличного пространства
echo "Корректировка табличного пространства"
psql -U postgres0 -d postgres -c "DROP TABLESPACE het47;"
psql -U postgres0 -d postgres -c "CREATE TABLESPACE het47 LOCATION '$NEW_TBS_DIR';"

# Запуск PostgreSQL
echo "Запуск PostgreSQL..."
pg_ctl -D "$PGDATA" start


# Проверка
psql -U evilyellowrole -d evilyellowsong -c "SELECT * FROM test_schema.test_table;"
