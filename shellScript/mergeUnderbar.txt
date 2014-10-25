
#cd /Users/niko/work/handday/crmZztx/crmZztx/pages
cd /Users/niko/study/demos/shellTest/Archive

files=$(find . -name *_)

echo $files

for file in { $files }
do
	echo $file
	fileWithoutUnderbar=${file%_}
	mv $file $fileWithoutUnderbar
done
