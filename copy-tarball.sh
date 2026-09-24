docker create --name libmaude-tmp libmaude
docker cp libmaude-tmp:/libmaude.tar.xz ./libmaude.tar.xz
docker rm libmaude-tmp
ls -lh libmaude.tar.xz