#!/bin/bash

# === Этап 2: Потеря основного узла ===

# Параметры
CURRENT_DATE=$(date "+%Y-%m-%d_%H-%M-%S")
RESERVE_HOST="postgres0@pg186"
RESERVE_DIR="$HOME/backups"
RESTORE_DIR="$HOME/ckf15"

# Логирование
LOG_FILE="$HOME/restore.log"
exec >> "$LOG_FILE" 2>&1

echo "[$CURRENT_DATE] Начало восстановления."
LATEST_BACKUP=$(ssh "$RESERVE_HOST" "ls -t $RESERVE_DIR/*.tar.gz | head -n 1")
if [ -z "$LATEST_BACKUP" ]; then
    echo "Ошибка: Нет доступных резервных копий."
fi

# Остановка PostgreSQL
echo "Остановка PostgreSQL..."
pg_ctl -D "$HOME/ckf15" stop -m fast
if [ $? -ne 0 ]; then
    echo "Ошибка: Не удалось остановить PostgreSQL"
fi

# Создание директории для восстановления
mkdir -p "$RESTORE_DIR"
if [ $? -ne 0 ]; then
    echo "Ошибка: Не удалось создать директорию $RESTORE_DIR"
fi

# Копирование последнего бэкапа с резервного сервера
scp "$RESERVE_HOST:$RESERVE_DIR/$LATEST_BACKUP" "$RESTORE_DIR"
if [ $? -ne 0 ]; then
    echo "Ошибка: Не удалось скопировать бэкап с резервного сервера"
fi

# Распаковка архива
echo "Распаковка архива..."
tar -xzf "$RESTORE_DIR/$(basename $LATEST_BACKUP)" -C "$RESTORE_DIR" || echo "Ошибка распаковки" 


# Восстановление базы данных
echo "[$CURRENT_DATE] Восстановление базы данных..."
pg_ctl -D "$RESTORE_DIR" start
if [ $? -ne 0 ]; then
    echo "Ошибка: Не удалось запустить PostgreSQL"
fi

# Проверка
psql -h pg180 -p 9392 -d evilyellowsong -U evilyellowrole
echo "[$CURRENT_DATE] Восстановление завершено"
