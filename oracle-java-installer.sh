#!/bin/bash
# Copyright (C) 2015 Amarpal Singh.
# All rights reserved.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
# OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
# IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
# NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
# THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

JVM=/usr/lib/jvm
BIN=/usr/bin
CURRENTDIRECTORY=$PWD
JAVATARBALL=$1
DEFAULTPRIORITY=1081

# Determine if valid java tarball
TEMPDIR=$(mktemp -d)
cp $JAVATARBALL $TEMPDIR
VALID=$(find $TEMPDIR -name 'jre*.tar.gz' -o -name 'jdk*.tar.gz' | wc -l)
if [[ $VALID -ne 1 ]]; then
  rm -rf $TEMPDIR
  unset JAVATARBALL TEMPDIR VALID
  exit 1
fi

# Prepare for installation
cd $TEMPDIR
JAVATARBALL=($(basename $JAVATARBALL))
temp=($(tar -tf $JAVATARBALL))
JAVAVERSION="$(cut -d '/' -f 1 <<< "$temp")"
unset temp

# Uninstall existing installation
uninstaller=$JVM/$JAVAVERSION/uninstall-$JAVAVERSION.sh
if [ -f $uninstaller ]; then
  $uninstaller
fi

# Extract the files
tar -xzvf $JAVATARBALL --directory $TEMPDIR

# Determine executable files to register (populate $files)
cd $TEMPDIR/$JAVAVERSION/bin
temp=($(find -type f -executable -exec file -i '{}' \; | grep 'x-executable; charset=binary'))
size=${#temp[@]}
files=$(for (( i=0; i<${size}; i+=3 ));
do
  echo ${temp[$i]:2:-1}
done)
unset size temp
cd ~/

# Install the files
if [ ! -d $JVM ]; then
  sudo mkdir $JVM
fi
sudo mv $TEMPDIR/$JAVAVERSION $JVM/$JAVAVERSION

# Create uninstaller script file
touch $uninstaller

# Determine priority
temp=$(sudo update-alternatives --display java)
if [ $? -eq 0 ]; then
  temp=($temp)
  size=${#temp[@]}
  re='^[0-9]+$'
  max=0
  priority=0
  for (( i=0; i<${size}; i++ ));
  do
  if [[ ${temp[$i]} =~ $re ]] ; then
     if ((${temp[$i]} > max)); then
       max=${temp[$i]}
       priority=${temp[$i]}
     fi
  fi
  done
  unset size temp re max
  priority=$((priority+1))
else
  priority=$DEFAULTPRIORITY
fi

# Register executable files and update uninstaller script
for file in $files; do
  # Register executable file
  sudo update-alternatives --install "$BIN/$file" "$file" "$JVM/$JAVAVERSION/bin/$file" $priority
  sudo chmod a+x $BIN/$file
  sudo update-alternatives --set $file $JVM/$JAVAVERSION/bin/$file
  # Update uninstaller script
  echo "sudo update-alternatives --remove \"$file\" \"$JVM/$JAVAVERSION/bin/$file\"" >> $uninstaller
done

# Finalize uninstaller script and mark as executable
echo "sudo rm -rf $JVM/$JAVAVERSION" >> $uninstaller
echo
sudo chmod +x $uninstaller
echo
echo "To uninstall $JAVAVERSION run $uninstaller"
unset file files files priority uninstaller JVM BIN JAVATARBALL JAVAVERSION DEFAULTPRIORITY

# Clean up
sudo rm -rf $TEMPDIR
unset TEMPDIR

cd $CURRENTDIRECTORY
unset CURRENTDIRECTORY
