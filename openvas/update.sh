docker compose down
rm /var/lib/docker/volumes/root_openvas_log_data_vol/_data/openvas.log
docker compose pull
docker compose up -d
docker image prune -f
