echo "остановка сервера и очистка"
pg_ctl -D $HOME/ckf15 stop
rm -rf  $HOME/ckf15
rm -rf $HOME/roi68
rm -rf $HOME/het47