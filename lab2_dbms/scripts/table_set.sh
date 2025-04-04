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
# $ - код возврата последней выполенной команды 
if [ $? -eq 0 ]; then
    echo "сервер настроен и готов к работе ура"
else
    echo "Ошибка подключения к базе данных"
fi
