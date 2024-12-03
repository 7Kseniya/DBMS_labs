echo "очистка и остановка"
rm -rf  $HOME/ckf15
rm -rf $HOME/roi68
rm -rf $HOME/het47

pg_ctl -D $HOME/ckf15 restart


