@echo off
cd ..\UNITS
tpc GENTYPES.PAS
tpc MD5.PAS
cd ..\TESTS
tpc -U..\UNITS MD5DEMO.PAS
