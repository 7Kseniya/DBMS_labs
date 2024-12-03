# check OLTP scenario params 
echo "checking postgres.log params"

grep "max_connections" $HOME/ckf15/postgresql.conf
grep "shared_buffers" $HOME/ckf15/postgresql.conf
grep "temp_buffers" $HOME/ckf15/postgresql.conf
grep "work_mem" $HOME/ckf15/postgresql.conf
grep "checkpoint_timeout" $HOME/ckf15/postgresql.conf
grep "effective_cache_size" $HOME/ckf15/postgresql.conf
grep "fsync" $HOME/ckf15/postgresql.conf
grep "commit_delay" $HOME/ckf15/postgresql.conf

# WAL file params checking 
grep "log_directory" $HOME/ckf15/postgresql.conf
grep "log_filename" $HOME/ckf15/postgresql.conf
grep "wal_level" $HOME/ckf15/postgresql.conf

# log params checking
grep "log_statement" $HOME/ckf15/postgresql.conf
grep "log_min_messages" $HOME/ckf15/postgresql.conf
grep "log_connections" $HOME/ckf15/postgresql.conf
grep "log_disconnections" $HOME/ckf15/postgresql.conf
grep "log_destination" $HOME/ckf15/postgresql.conf
grep "logging_collector" $HOME/ckf15/postgresql.conf

pg_isready -h localhost -p 9392