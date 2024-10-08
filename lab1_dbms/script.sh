#!/bin/bash

read -p "Enter table name: " full_table_name
read -p "Enter user name: " p_user_name
read -p "Enter name: " p_name
read -p "Enter surname: " p_user_surname

IFS='.' read -r -a table_parts <<< "$full_table_name"
p_table_name="${table_parts[-1]}"
p_schema_name="${table_parts[-2]}"
p_database_name="${table_parts[-3]}"

# charset deserialization
p_table_name=$(echo "$p_table_name" | tr '[:lower:]' '[:upper:]' | iconv -f $(locale charmap) -t UTF-8)
p_schema_name=$(echo "$p_schema_name" | iconv -f $(locale charmap) -t UTF-8)
p_database_name=$(echo "$p_database_name" | iconv -f $(locale charmap) -t UTF-8)
p_user_name=$(echo "$p_user_name" | iconv -f $(locale charmap) -t UTF-8)
p_name=$(echo "$p_name" | iconv -f $(locale charmap) -t UTF-8)
p_user_surname=$(echo "$p_user_surname" | iconv -f $(locale charmap) -t UTF-8)

ACCESS_CHECK=$(psql -h pg -d "$p_database_name" -c "SELECT 1 FROM pg_namespace WHERE nspname = 'public';" 2>&1)

if [[ $ACCESS_CHECK == *"ERROR"* ]]; then
  echo "DB access error"
  exit 1
fi

sed -e "s/\${p_table_name}/$p_table_name/g" \
    -e "s/\${p_user_name}/$p_user_name/g" \
    -e "s/\${p_schema_name}/$p_schema_name/g" \
    -e "s/\${p_user_surname}/$p_user_surname/g" \
    -e "s/\${p_name}/$p_name/g" task.sql > temp_task.sql

psql -h pg -d "$p_database_name" -f temp_task.sql | sed 's|.*NOTICE:  ||g'
rm temp_task.sql
