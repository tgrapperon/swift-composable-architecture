#!/bin/sh

echo "Clean up temporary files"
rm -rf /Internal/tmp
rm -rf /Internal/Frameworks/*
rm -rf /Internal/LocalTCA/Sources/*
rm -rf /Internal/ReferenceTCA/Sources/*
echo "Done!"

