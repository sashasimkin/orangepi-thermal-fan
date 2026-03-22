FROM alpine:latest

# Install required dependencies
# bash for script execution
# libgpiod for gpioset
# procps for pkill
RUN apk add --no-cache \
    bash \
    libgpiod \
    procps

# Copy our fan control script
COPY fan-control.sh /usr/local/bin/fan-control.sh

# Ensure script is executable
RUN chmod +x /usr/local/bin/fan-control.sh

# Run the fan control script
CMD ["/usr/local/bin/fan-control.sh"]
