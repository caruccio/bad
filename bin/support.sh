mesg()
{
    echo -e "\e[33;1m${@}\e[m"
}

function title()
{
    echo
    mesg "### $1"
    mesg $(echo "### $1" | tr "### $1" -)
    echo
}

