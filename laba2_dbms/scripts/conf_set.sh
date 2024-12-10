# === Этап 2: Конфигурация сервера БД ===

echo "добавление изменений в конфигурацию..."
# Для локальных подключений по паролю
sed -i '' 's/^local[[:space:]]*all[[:space:]]*all[[:space:]]*trust$/local   all             all                                     peer/' $HOME/ckf15/pg_hba.conf
sed -i '' 's|^host[[:space:]]*all[[:space:]]*all[[:space:]]*127.0.0.1/32[[:space:]]*trust$|host    all             all             0.0.0.0/0               password|' $HOME/ckf15/pg_hba.conf
sed -i '' 's|^host[[:space:]]*all[[:space:]]*all[[:space:]]*::1/128[[:space:]]*trust$|host    all             all             ::/0                    password|' $HOME/ckf15/pg_hba.conf
# проверка внесенных изменений 
grep "^local" $HOME/ckf15/pg_hba.conf
grep "^host" $HOME/ckf15/pg_hba.conf

# настройка параметров со сценарием OLTP
echo "конфигурирование postgresql.conf..."

sed -i '' "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" $HOME/ckf15/postgresql.conf
sed -i '' "s/#port = 5432/port = 9392/g" $HOME/ckf15/postgresql.conf
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

echo "параметры успешно обновлены"

grep "listen_addresses" $HOME/ckf15/postgresql.conf 
grep "port" $HOME/ckf15/postgresql.conf

# установка владельца для файлов 
chown postgres0 $HOME/ckf15/postgresql.conf
chown postgres0 $HOME/ckf15/pg_hba.conf 

# проверка конфигов 
ls -l $HOME/ckf15/postgresql.conf
ls -l $HOME/ckf15/pg_hba.conf

# перезапуск
echo "перезапуск сервера для применения изменений..."
pg_ctl -D $HOME/ckf15 restart || echo "Ошибка перезапуска сервера";

