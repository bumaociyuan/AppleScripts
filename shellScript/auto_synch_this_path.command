#chmod a+x auto_synch_this_path.command #if not allow you run this script by double clicking
cd `dirname $0`;git status;git add -A;git commit -m 'zx';git pull;git push