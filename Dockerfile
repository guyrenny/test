FROM 529726762838.dkr.ecr.eu-west-1.amazonaws.com/integrations-service:latest as base

WORKDIR /app
COPY . /app

CMD ["./sync_integration_definitions", "integrations"]
