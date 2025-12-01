# terminal colors and styles

esc='\x1b'
reset="${esc}[0m"
bold="${esc}[1m"
underline="${esc}[4m"

black="${esc}[0;30m"
red="${esc}[0;31m"
green="${esc}[0;32m"
yellow="${esc}[0;33m"
blue="${esc}[0;34m"
magenta="${esc}[0;35m"
cyan="${esc}[0;36m"
white="${esc}[0;37m"

bright_black="${esc}[0;90m"
bright_red="${esc}[0;91m"
bright_green="${esc}[0;92m"
bright_yellow="${esc}[0;93m"
bright_blue="${esc}[0;94m"
bright_magenta="${esc}[0;95m"
bright_cyan="${esc}[0;96m"
bright_white="${esc}[0;97m"

bold_black="${esc}[1;30m"
bold_red="${esc}[1;31m"
bold_green="${esc}[1;32m"
bold_yellow="${esc}[1;33m"
bold_blue="${esc}[1;34m"
bold_magenta="${esc}[1;35m"
bold_cyan="${esc}[1;36m"
bold_white="${esc}[1;37m"

bold_bright_black="${esc}[1;90m"
bold_bright_red="${esc}[1;91m"
bold_bright_green="${esc}[1;92m"
bold_bright_yellow="${esc}[1;93m"
bold_bright_blue="${esc}[1;94m"
bold_bright_magenta="${esc}[1;95m"
bold_bright_cyan="${esc}[1;96m"
bold_bright_white="${esc}[1;97m"

highlight() {
  echo -e "${bold}$@${reset}"
}

info() {
  echo -e "${bold_green}$@${reset}"
}

warning() {
  echo -e "${bold_yellow}$@${reset}"
}

error() {
  echo -e "${bold_red}$@${reset}"
}

prompt() {
  echo -e "${bold_green}$@${reset}"
}

print_item() {
  echo -e "${cyan}$@${reset}"
}

print_option() {
  echo -e "${bold_magenta}$@${reset}"
}

print_result() {
  echo -e "${yellow}$@${reset}"
}

provide 'styles'
