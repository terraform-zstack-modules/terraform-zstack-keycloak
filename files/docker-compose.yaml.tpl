version: '3.8'
services:
  postgres:
    image: postgres:15
    container_name: postgres
    environment:
      POSTGRES_DB: keycloak
      POSTGRES_USER: keycloak
      POSTGRES_PASSWORD: keycloak
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U keycloak"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - keycloak-network

  keycloak:
    image: keycloak-zsthemev2.1:21.1.1
    depends_on:
      postgres:
        condition: service_healthy
    command: start --hostname-strict=false --spi-theme-welcome-theme=zstack-theme
    environment:
      KC_DB: postgres
      KC_DB_URL_HOST: postgres
      KC_DB_URL_PORT: 5432
      KC_DB_URL_DATABASE: keycloak
      KC_DB_USERNAME: keycloak
      KC_DB_PASSWORD: keycloak
      KC_DB_SCHEMA: public
      KEYCLOAK_ADMIN: ${admin_username}
      KEYCLOAK_ADMIN_PASSWORD: ${admin_password}
      KC_HTTP_ENABLED: true
    ports:
      - "8080:8080"
    networks:
      - keycloak-network

networks:
  keycloak-network:
    driver: bridge

volumes:
  postgres_data:
