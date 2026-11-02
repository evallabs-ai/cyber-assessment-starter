FROM python:3.12-slim@sha256:aa943ce411423c7582288f18707ff66eddcbaeb510502d747a72aeb34f30d159
RUN useradd --create-home agent && mkdir -p /logs/artifacts && chown agent /logs/artifacts
WORKDIR /home/agent
