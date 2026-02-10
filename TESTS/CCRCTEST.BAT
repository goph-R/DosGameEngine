@echo off
cd ..\UNITS
tpc GENTYPES.PAS
tpc CRC32.PAS
cd ..\TESTS
tpc -U..\UNITS CRCTEST.PAS
