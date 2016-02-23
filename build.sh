#Vars
FOLDER_SCRIPTING=addons/sourcemod/scripting
FOLDER_PLUGINS=addons/sourcemod/plugins
GIT_DEPENDENCIES=https://gitlab.com/good_live/sm-includes.git
PLUGIN_TAG=pt

COUNT="$(git rev-list --count HEAD)"
HASH="$(git log --pretty=format:%h -n 1)"
FILE=$PLUGIN_TAG-$CI_BUILD_REF_NAME-$1-$COUNT-$HASH.zip

#download
apt-get update -yqq
apt-get install gcc-multilib -yqq

mkdir downloads
cd downloads

wget -q "http://www.sourcemod.net/latest.php?version=$1&os=linux" -O sourcemod.tar.gz
tar -xzf sourcemod.tar.gz

git clone $GIT_DEPENDENCIES -q

#copy files

##compiler
cp $FOLDER_SCRIPTING/spcomp ../$FOLDER_SCRIPTING
chmod +rx ../$FOLDER_SCRIPTING/spcomp
cp $FOLDER_SCRIPTING/compile.sh ../$FOLDER_SCRIPTING

##includes
cp -r $FOLDER_SCRIPTING/include/* ../$FOLDER_SCRIPTING/include
cp -r sm-includes/* ../$FOLDER_SCRIPTING/include

cd ../

rm -r downloads

#compile
cd addons/sourcemod/scripting
./compile.sh

cd ../../../

#zip build
mkdir $FOLDER_PLUGINS
cp -rv $DER_SCRIPTING/compiled/* $FOLDER_PLUGINS
rm -r $FOLDER_SCRIPTING/compiled

zip -9rq $FILE addons

#upload
lftp -c "open -u $FTP_USER,$FTP_PASS $FTP_HOST; put -O $PLUGIN_TAG/downloads/$CI_BUILD_REF_NAME/ $FILE",