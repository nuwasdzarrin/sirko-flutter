# Sumber lingkungan Maestro (Git Bash). Dipakai oleh run_all.sh & hier.sh.
export JAVA_HOME="${JAVA_HOME:-/c/Program Files/Android/Android Studio/jbr}"
export MAESTRO_CLI_NO_ANALYTICS=1
export MAESTRO_CLI_ANALYSIS_NOTIFICATION_DISABLED=true
export PATH="/c/maestro/bin:$LOCALAPPDATA/Android/Sdk/platform-tools:$JAVA_HOME/bin:$PATH"
export DEVICE="${DEVICE:-emulator-5554}"
