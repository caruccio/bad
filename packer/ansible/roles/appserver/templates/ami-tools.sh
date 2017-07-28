if [ -e /usr/local/bin/ec2-ami-tools-version ]; then
    for dir in $(rpm -qil ec2-ami-tools | grep ec2/amitools/version.rb); do
        RUBYLIB="${RUBYLIB:+$RUBYLIB:}${dir%/ec2/amitools/version.rb}"
    done

    export RUBYLIB
fi
