#!/bin/bash

# лабораторная работа №2 - вариант 348392

# подключение к узлу через ssh
# echo "подключение к узлу pg180..."
# ssh -J $PROXY $USER@$NODE
# ssh -J s368231@helios.cs.ifmo.ru:2222 postgres0@pg180 || echo "Ошибка подключения"
# === Этап 1: Инициализация кластера БД ===
# создание директории для кластера и инициализация 
echo "инициализация кластера в $HOME/ckf15..."
mkdir -p $HOME/ckf15
# устанавливаем владельца каталога 
chown postgres0 $HOME/ckf15
# создание директории для WAL файлов 
echo "создание директории $HOME/roi68 для WAL файлов"
mkdir -p $HOME/roi68 
# устанавливаем владельца каталога 
chown postgres0 $HOME/roi68

initdb -D $HOME/ckf15 -E UTF8 --locale=en_US.UTF-8 --waldir=$HOME/roi68 || echo "Ошибка инициализации" ;

# === Запуск сервера ===
# pg_ctl -D /var/db/postgres0/ckf15 -l файл_журнала start
echo "запуск сервера postgres..."
pg_ctl -D $HOME/ckf15 -l $HOME/ckf15/postgres.log start



