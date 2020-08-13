#!/bin/sh

echo ""
echo "===================================================="
echo ""
echo "            /!\\ Do NOT hit on ctrl-c /!\\"
echo " (this would kill ungracefuly the minecraft server)"
echo ""
echo " Use ctrl-q to leave paper-spigot terminal instead"
echo ""
echo "                        :)"
echo ""
echo "===================================================="
echo ""
echo "$ docker attach minecraft --detach-keys=ctrl-q"
echo "> "

docker attach minecraft --detach-keys=ctrl-q
