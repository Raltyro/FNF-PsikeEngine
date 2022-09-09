@echo off

cd ../
IF EXIST ".git" (
	git rev-parse HEAD > export/release/windows/bin/manifest/hash.dat
)

@echo on