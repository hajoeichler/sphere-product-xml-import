#!/bin/bash

set -e

rm -rf lib

npm version minor
git checkout production
git merge master
grunt
git add -f lib/xmlimport.js
git commit -m "Add generated code for production environment."
git push origin production

git checkout master
npm version patch
git push origin master
