
cd `dirname $0`

files=$(find . -name *_)

# echo $files

for file in { $files }
do
	echo $file
	
	fileWithoutUnderbar=${file%_}

	mv $file $fileWithoutUnderbar
done
