#!/bin/sh
# The clock's Gmail accounts: Akonadi's Google resources, one per account.
#   accounts.sh list            one "id<TAB>name" line per account (the name is
#                               the address once signed in)
#   accounts.sh add             a new account; opens Google's sign-in dialog
#   accounts.sh signin <id>     the sign-in dialog again (e.g. it was cancelled)
#   accounts.sh remove <id>     forget the account and its synced data
akonadi() {
    method=$1
    shift
    qdbus-qt6 org.freedesktop.Akonadi.Control /AgentManager "org.freedesktop.Akonadi.AgentManager.$method" "$@"
}
# Akonadi's settings dialog for the resource (Google's sign-in); configuring
# over D-Bus isn't supported anymore. Returns once the dialog is closed
signin() {
    akonadiagentconfigdialog "$1" >/dev/null 2>&1
}
case "$1" in
list)
    for id in $(akonadi agentInstances); do
        if [ "$(akonadi agentInstanceType "$id")" = akonadi_google_resource ]; then
            printf '%s\t%s\n' "$id" "$(akonadi agentInstanceName "$id")"
        fi
    done
    ;;
add) signin "$(akonadi createAgentInstance akonadi_google_resource)" ;;
signin) signin "$2" ;;
remove) akonadi removeAgentInstance "$2" ;;
*)
    echo "usage: $0 list | add | signin <id> | remove <id>" >&2
    exit 2
    ;;
esac
