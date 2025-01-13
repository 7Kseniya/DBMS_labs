#!/bin/bash

# === Этап 1: Резервное копирование ===

# Параметры
CURRENT_DATE=$(date "+%Y-%m-%d_%H-%M-%S")
BACKUP_DIR="$HOME/backups/$CURRENT_DATE"
RESERVE_HOST="postgres0@pg186"
RESERVE_DIR="$HOME/backups"

# Логирование
LOG_FILE="$HOME/backup.log"
exec >> "$LOG_FILE" 2>&1

echo "===================="
echo "$(date): Начало резервного копирования"

# Создание директории для резервных копий
mkdir -p "$BACKUP_DIR"
if [ $? -ne 0 ]; then
    echo "Ошибка: Не удалось создать директорию $BACKUP_DIR"
fi

# Выполнение резервного копирования
echo "Запуск pg_basebackup"
pg_basebackup -D "$BACKUP_DIR" -p 9392 -F tar -z -P -X stream -U evilyellowrole
if [ $? -ne 0 ]; then
    echo "Ошибка при выполнении pg_basebackup"
fi

# Копируем резервную копию на резервный узел
echo "Копирование на резервный узел"
scp -C "$BACKUP_DIR"/*.tar.gz "$RESERVE_HOST":"$RESERVE_DIR"
if [ $? -ne 0 ]; then
    echo "Ошибка копирования на резервный узел $RESERVE_HOST"
fi

# Удаляем резервные копии старше 7 дней на основном узле
echo "Удаление старых копий на основном узле"
find "$RESERVE_DIR" -type f -mtime +7 -exec rm -rf {} \;
if [ $? -ne 0 ]; then
    echo "$(date): Ошибка при удалении старых копий на основном узле"
fi

# Удаляем резервные копии старше 30 дней на резервном узле
echo "Удаление старых копий на резервном узле"
ssh "$RESERVE_HOST" "find \"$RESERVE_DIR\"/ -type f -mtime +30 -exec rm -rf {} \;"
if [ $? -ne 0 ]; then
    echo "Ошибка при удалении старых копий на резервном узле"
fi

echo "$(date): Резервное копирование завершено успешно"
