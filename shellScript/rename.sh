#! /bin/bash
cd `dirname $0`
files=$(find . -name *markdown)

echo $files

for file in { $files }
do
	echo $file
	fileWithoutUnderbar=${file%markdown}
	echo $fileWithoutUnderbar'md'
	mv $file $fileWithoutUnderbar'md'
done