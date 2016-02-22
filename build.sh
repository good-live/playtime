#Vars
FOLDER_SCRIPTING=addons/sourcemod/scripting
FOLDER_PLUGINS=addons/sourcemod/plugins

#download
apt-get update -yqq
apt-get install gcc-multilib -yqq

mkdir downloads
cd downloads

wget wget -q "http://www.sourcemod.net/latest.php?version=$1&os=linux" -O sourcemod.tar.gz
tar -xzf sourcemod.tar.gz

git clone https://Yeradon:$USER_PASSWORD@gitlab.com/Yeradon/sm-dependencies.git -q

#copy files

##compiler
cp $FOLDER_SCRIPTING/spcomp ../$FOLDER_SCRIPTING
chmod +rx ../$FOLDER_SCRIPTING/spcomp
cp $FOLDER_SCRIPTING/compile.sh ../$FOLDER_SCRIPTING

##includes
cp -r $FOLDER_SCRIPTING/include/* ../$FOLDER_SCRIPTING/include
cp -r sm-dependencies/* ../$FOLDER_SCRIPTING/include

cd ../

rm -r downloads

#compile
cd addons/sourcemod/scripting
./compile.sh