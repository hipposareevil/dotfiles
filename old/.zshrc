# Path to your oh-my-zsh installation.
export ZSH=$HOME/.oh-my-zsh

ZSH_THEME="kolo"

plugins=(git)

# User configuration

export PATH=".:/usr/local/homebrew/bin:/usr/local/bin:/usr/local/Cellar/ruby/2.0.0-p247/bin:/work/work/p4:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/X11/bin:/usr/local/git/bin:/usr/texbin:.:/usr/local/homebrew/bin:/usr/local/Cellar/ruby/2.0.0-p247/bin:/work/work/mydev/drm/src/buildtools/ant/bin/:/opt/local/bin"
# export MANPATH="/usr/local/man:$MANPATH"

source $ZSH/oh-my-zsh.sh

export ANT_HOME=/work/work/mydev/drm/src/buildtools/ant
export JAVA_HOME=`/usr/libexec/java_home`


export PATH=.:~/bin:~/bin/photo:~/bin/sync:/Users/sami/:/usr/local/homebrew/bin:/usr/local/bin:/usr/local/Cellar/ruby/2.0.0-p247/bin:$PATH:~/crypt:/Applications/MAMP/Library/bin:/opt/local/bin:/usr/local/git/bin:/Developer/usr/bin:/work/work/mydev/drm/src/buildtools/gradle/bin:$ANT_HOME/bin/:/opt/maven/bin
export CLASSPATH=$CLASSPATH:/java/photo/:.:/java/freemarker/lib/freemarker.jar
export EDITOR=emacs

export P4CLIENT=sam.jackson.work.macmac
export P4PASSWD=5Kermantle
export P4PORT=hoover.us.oracle.com:5999
export P4USER=sam.jackson
export P4USER_CTL=sam.jackson

# load common stuff
source ~/Dropbox/dotfiles/zshrc

# diff
export DIFF_VIEWER="/Applications/PyCharm CE.app/Contents/MacOS/pycharm"
# merge
export MERGE_VIEWER="/Applications/PyCharm CE.app/Contents/MacOS/pycharm"

