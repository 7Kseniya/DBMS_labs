# Лабораторная работа №3 по АСУБД
[полный текст задания](./full_task.md)

## Этап 1. Резервное копирование 

генерируем ssh-key на основном узле для выполнения копирования без запроса пароля
```bash
    ssh-keygen -t rsa -b 4096 -C "postgres0@pg180"
    ssh-copy-id -i $HOME/.ssh/id_rsa.pub postgres0@pg186
```

проверка доступа к резервному узлу без пароля
```
[postgres0@pg180 ~]$ ssh postgres0@pg186
Last login: Wed Jan  8 21:25:36 2025 from 192.168.11.180
[postgres0@pg186 ~]$ 
```

добавим параметр в `$HOME/ckf15/postgres.conf` для хранения WAL-файлов в составе полной копии
```bash
    sed -i '' "s/#wal_level =.*/wal_level = replica/" $HOME/ckf15/postgresql.conf
```

```
[postgres0@pg180 ~]$ grep "wal_level" $HOME/ckf15/postgresql.conf
wal_level = replica
```

создаем раль на резервном узле: 
```bash 
psql -h localhost -U postgres -d postgres -c "CREATE ROLE evilyellowrole WITH LOGIN PASSWORD 'evil_pass';"
psql -h localhost -U postgres -d postgres -c "GRANT CONNECT ON DATABASE evilyellowsong TO evilyellowrole;"
psql -h localhost -U postgres -d postgres -c "GRANT ALL PRIVILEGES ON DATABASE evilyellowsong TO evilyellowrole;"
```
**создание директории для резервных копий **

на основном узле `pg180`:
```bash 
    mkdir -p $HOME/backups
```

на резервном узле `pg186`:
```bash 
    mkdir -p $HOME/backups
```
перезапускаем сервер 
```bash 
    pg_ctl -D $HOME/ckf15 restart
```
создание [скрипта](./script/pg180/backup.sh) `backup.sh` для резервного копирования 

```bash 
#!/bin/bash

# === Этап 1: Резервное копирование ===

# Параметры
CURRENT_DATE=$(date "+%Y-%m-%d_%H:%M:%S")
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
pg_basebackup -D "$BACKUP_DIR" -F tar -z -P -p 9392

# Копируем резервную копию на резервный узел
echo "Копирование на резервный узел"
scp "$BACKUP_DIR"/*.tar.gz "$RESERVE_HOST":"$RESERVE_DIR"
if [ $? -ne 0 ]; then
    echo "Ошибка копирования на резервный узел $RESERVE_HOST"
fi

# Удаляем резервные копии старше 7 дней на основном узле
echo "Удаление старых копий на основном узле"
find "$RESERVE_DIR" -type d -mtime +7 -exec rm -rf {} \;
if [ $? -ne 0 ]; then
    echo "$(date): Ошибка при удалении старых копий на основном узле"
fi

# Удаляем резервные копии старше 30 дней на резервном узле
echo "Удаление старых копий на резервном узле"
ssh "$RESERVE_HOST" "find \"$RESERVE_DIR\"/ -type d -mtime +30 -exec rm -rf {} \;"
if [ $? -ne 0 ]; then
    echo "Ошибка при удалении старых копий на резервном узле"
fi

echo "$(date): Резервное копирование завершено успешно"

```

делаем скрипт исполняемым и запускаем 
```bash 
    chmod +x scripts/pg180/backup.sh
    bash scripts/pg180/backup.sh
```

результат выполнения скрипта из `backup.sh`

```bash
cat $HOME/backup.log
```

```
Запуск pg_basebackup
ожидание контрольной точки
10412/38803 КБ (26%), табличное пространство 0/2
15257/38803 КБ (39%), табличное пространство 0/2
15257/38803 КБ (39%), табличное пространство 1/2
37918/38803 КБ (97%), табличное пространство 1/2
38816/38816 КБ (100%), табличное пространство 1/2
38816/38816 КБ (100%), табличное пространство 2/2
Копирование на резервный узел
Удаление старых копий на основном узле
Удаление старых копий на резервном узле
среда,  8 января 2025 г. 23:01:49 (MSK): Резервное копирование завершено успешно
```

добавляем задачу в планировщик `cron`

```bash
crontab -e 
```
добавляем строку для выполнения задачи дважды в сутки 
```
0 0 * * * $HOME/scripts/pg180/baskup.sh >> $HOME/backup.log 2>&1
0 12 * * * $HOME/scripts/pg180/baskup.sh >> $HOME/backup.log 2>&1
```

#### подсчет объема резервных копий 

**исходные данные **
- Средний объем новых данных в БД за сутки: `700МБ`.
- Средний объем измененных данных за сутки: `800МБ`.
- Частота полного резервного копирования: 2 раза в сутки 
- срок храниения 
  - основной узел: 7 дней 
  - резервный узел: 30 дней 

расчет для основного узла 
1. объем одной копии = 700МБ + 800МБ = 1500МБ ~ 1.5ГБ
2. количество копий за сутки = 2 
3. объем резервных копий за неделю = 1500 * 2 * 7 = 21000МБ ~ 21ГБ

расчет для резервного узла 
1. количество копий за месяц = 2 * 30 = 60 
2. объем резервных копий за месяц = 1500 * 60 = 90000МБ ~ 88ГБ
   
> расчеты не учитывают сжатия 

## Этап 2. Потеря основного узла 
добавим таблицу в БД на основном узле 
```sql
CREATE TABLE test_table (id SERIAL PRIMARY KEY, data TEXT);
INSERT INTO test_table (data) VALUES ('test data');
```
выполняем резервное копирование на основном узле 
```bash
bash $HOME/scripts/pg180/backup.sh >> $HOME/backup.log 2>&1
```

создаем [скрипт](./script/pg186/restore.sh) `restore.sh` на резервном узле для восстановления БД

```bash

```

копируем файлы .conf с основного узла и папку с табличными пространствами 
```bash
scp postgres0@pg180:$HOME/ckf15/postgresql.conf $HOME/ckf15/
scp postgres0@pg180:$HOME/ckf15/pg_hba.conf $HOME/ckf15/
scp postgres0@pg180:$HOME/ckf15/pg_ident.conf $HOME/ckf15/

scp -r postgres0@pg180:$HOME/het47/ $HOME/

```

применим изменения 
```bash 
pg_ctl -D $HOME/ckf15 restart 
```

симулируем сбой, удалив директорию с табличным пространством 
```bash
    rm -rf $HOME/het47
```

#### проверка работоспособности
