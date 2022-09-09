if [ -f .git ]; then
	git rev-parse HEAD > export/release/mac/bin/manifest/hash.dat
fi
