./build.sh
git add -u .
git commit -m 'build'
git checkout gh-pages
git merge master
git add .
git commit -m 'build'
git push origin gh-pages
git checkout master
