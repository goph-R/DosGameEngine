@echo off
cd ..\UNITS
tpc GENTYPES.PAS
cd ..\TESTS
tpc -U..\UNITS ENCTEST.PAS
