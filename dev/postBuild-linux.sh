if [ -f .git ]; then
	git rev-parse HEAD > export/release/linux/bin/manifest/hash.dat
fi
