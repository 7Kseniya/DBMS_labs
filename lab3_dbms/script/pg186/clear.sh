#!/bin/sh 

pg_ctl -D $HOME/ckf15 stop || echo "Ошибка остановки сервера"

echo "Удаление каталогов..."
rm -rf $HOME/ckf15/
rm -rf $HOME/roi68/
rm -rf $HOME/het47/