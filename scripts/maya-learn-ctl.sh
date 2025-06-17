#!/bin/bash

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root"
    exit 1
fi

SERVICE_NAME="maya-learn.service"

case "$1" in
    start)
        systemctl start $SERVICE_NAME
        systemctl status $SERVICE_NAME
        ;;
    stop)
        systemctl stop $SERVICE_NAME
        ;;
    restart)
        systemctl restart $SERVICE_NAME
        systemctl status $SERVICE_NAME
        ;;
    status)
        systemctl status $SERVICE_NAME
        ;;
    enable)
        systemctl enable $SERVICE_NAME
        echo "Service enabled to start on boot"
        ;;
    disable)
        systemctl disable $SERVICE_NAME
        echo "Service disabled from starting on boot"
        ;;
    logs)
        journalctl -u $SERVICE_NAME -f
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|enable|disable|logs}"
        exit 1
        ;;
esac

exit 0
