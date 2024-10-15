DO
$BODY$
DECLARE
    /*обьявление переменных*/
    v_schema_name record;
    v_table_name record;
    v_attname record;
    v_column_info record;
    v_constraint record;
    v_max_legth int; /*максимальная длины типов данных*/
    v_column_num integer := 0; /*счетчик нумерации столбцов*/
    not_have_len bool = false; /*флаг наличия длины у типов данных*/
    result text;
    constraint_res text;
    number_of_failed_attempts int = 0;
    number_of_scheme int = 0;
    p_table_name text := '${p_table_name}'; /*имя таблицы*/
    p_schema_name text := '${p_schema_name}';/*название схемы*/
    p_user_name text := '${p_user_name}'; /*имя пользователя*/
    p_user_surname text := '${p_user_surname}';
    p_name text := '${p_name}';

BEGIN
    /*цикл по схемам, к которым у пользователя есть права доступа */
    FOR v_schema_name IN
        SELECT nspname, oid /*имя схемы, уникальный идентификатор схемы*/
        FROM pg_namespace /*системная таблица, содержащая инфу о схемах (пространствах имен) в бд*/
        WHERE has_schema_privilege(p_user_name, nspname, 'USAGE') /*проверка наличия у пользователя прав доступа к nspname*/
    LOOP
        /*проверка наличия таблицы*/
        number_of_scheme = number_of_scheme + 1; /*счетчик схем*/
        IF (SELECT relname /*имя схемы*/
            FROM pg_class /*содержит инфу о таблицах, индексах, представлениях и др обьектов бд*/
            WHERE relnamespace = v_schema_name.oid /*проверка идентификаторов*/
            AND relkind = 'r' AND relname = p_table_name) IS NULL THEN /*тип обьекта (r для таблиц) и проверка совпадения имени таблицы*/
                number_of_failed_attempts = number_of_failed_attempts + 1;
        ELSE
            /*цикл по таблицам в текущей схеме*/
            FOR v_table_name IN
                SELECT relname, oid
                FROM pg_class
                WHERE relnamespace = v_schema_name.oid
                AND relkind = 'r' AND relname = p_table_name
            LOOP
            -- v_schema_name.nspname
                RAISE NOTICE 'Пользователь: % % (%)', p_name, p_user_surname, p_user_name;
                RAISE NOTICE 'Таблица: %', v_table_name.relname;
                RAISE NOTICE 'No. Имя столбца   Атрибуты';
                RAISE NOTICE '--- ------------------   ------------------------------------------------------';
                /*цикл по атрибутам таблицы*/
                FOR v_attname IN (
                    SELECT attname, atttypid, atttypmod /*имя, идентификатор типа данных, модификатор типа данных*/
                    FROM  pg_attribute
                    WHERE attrelid = v_table_name.oid AND attnum > 0 /*идентификатор таблицы, к которой принадлежит столбец и проверка, что он пользовательский (системные отрицательные)*/
                )
                LOOP
                    /*получение инфы о типе данных*/
                    SELECT typname, typlen, typnotnull INTO v_column_info /*имя, длина, флаг возможности null*/
                    FROM pg_type /*сист таблица о типах данных*/
                    WHERE oid = v_attname.atttypid;
                    /*инициализация индексов и флага длины*/
                    v_column_num := v_column_num + 1;
                    not_have_len = false;
                    CASE
                        WHEN v_column_info.typname = 'varchar' THEN
                            v_max_legth = v_attname.atttypmod - 4; /*модификатор типа данных atttypmod содержит длину строки+4 (для хранения инфы о длине)*/
                        WHEN v_column_info.typname = 'text' OR v_column_info.typname = 'date' OR v_column_info.typname = 'int4' OR v_column_info.typname = 'float8' THEN
                            not_have_len = true;
                        WHEN v_column_info.typname = 'numeric' THEN
                            SELECT numeric_precision INTO v_max_legth FROM information_schema.columns
                            /*из information_schema.columns (представление, содержащее инфу о столбцах)
                              берем numeric_precision - точность числового типа*/
                            WHERE table_name = p_table_name AND column_name = v_attname.attname;
                        ELSE
                            v_max_legth = v_column_info.typlen; /*typlen если длина определена*/
                    END CASE;

                    IF not_have_len THEN
                        SELECT FORMAT('%-3s %-20s Type : %-10s', v_column_num, v_attname.attname, v_column_info.typname) INTO result;
                        RAISE NOTICE '%', result;
                    ELSE
                        SELECT FORMAT('%-3s %-20s Type : %s(%s)', v_column_num, v_attname.attname, v_column_info.typname, v_max_legth) INTO result;
                        RAISE NOTICE '%', result;

                    END IF;

                    /* Вывод информации о первичных ключах */
                    FOR v_constraint IN (
                        SELECT c.conname, a.attname
                        FROM pg_constraint c
                        JOIN pg_attribute a ON a.attnum = ANY(c.conkey) AND a.attrelid = c.conrelid
                        WHERE c.contype = 'p' AND a.attrelid = v_table_name.oid AND a.attname = v_attname.attname
                    )
                    LOOP
                        SELECT FORMAT('Constr: %s Primary Key %s(%s)', v_constraint.conname, p_table_name, v_constraint.attname) INTO constraint_res;
                        RAISE NOTICE '%', constraint_res;
                    END LOOP;

                    /* Вывод информации о уникальных ограничениях */
                    FOR v_constraint IN (
                        SELECT c.conname, a.attname
                        FROM pg_constraint c
                        JOIN pg_attribute a ON a.attnum = ANY(c.conkey) AND a.attrelid = c.conrelid
                        WHERE c.contype = 'u' AND a.attrelid = v_table_name.oid AND a.attname = v_attname.attname
                    )
                    LOOP
                        SELECT FORMAT('Constr: "%s" Unique %s(%s)', v_constraint.conname, p_table_name, v_constraint.attname) INTO constraint_res;
                        RAISE NOTICE '%', constraint_res;
                    END LOOP;

                    /* Вывод информации о внешних ключах */
                    FOR v_constraint IN (
                        SELECT c.conname, a.attname, conf.relname as conf_table, a2.attname as conf_column
                        FROM pg_constraint c
                        JOIN pg_attribute a ON a.attnum = ANY(c.conkey) AND a.attrelid = c.conrelid
                        JOIN pg_class conf ON conf.oid = c.confrelid
                        JOIN pg_attribute a2 ON a2.attnum = ANY(c.confkey) AND a2.attrelid = c.confrelid
                        WHERE c.contype = 'f' AND a.attrelid = v_table_name.oid AND a.attname = v_attname.attname
                    )
                    LOOP
                        SELECT FORMAT('Constr: %s Foreign Key %s(%s)', v_constraint.conname, p_table_name, v_constraint.attname, v_constraint.conf_table, v_constraint.conf_column) INTO constraint_res;
                        RAISE NOTICE '%', constraint_res;
                    END LOOP;

                    /* Вывод информации о проверках */
                    FOR v_constraint IN (
                        SELECT c.conname, pg_get_constraintdef(c.oid) as check_condition
                        FROM pg_constraint c
                        JOIN pg_attribute a ON a.attnum = ANY(c.conkey) AND a.attrelid = c.conrelid
                        WHERE c.contype = 'c' AND a.attrelid = v_table_name.oid AND a.attname = v_attname.attname
                    )
                    LOOP
                        SELECT FORMAT(' Constr : %s Check %s(%s)', v_constraint.conname, p_table_name, v_constraint.check_condition) INTO constraint_res;
                        RAISE NOTICE '%', constraint_res;
                    END LOOP;

                END LOOP;
            END LOOP;
    END IF;
    END LOOP;
    IF (number_of_failed_attempts = number_of_scheme) THEN
        RAISE NOTICE 'Current table is not found';
    END IF;
END;
$BODY$
LANGUAGE plpgsql;
