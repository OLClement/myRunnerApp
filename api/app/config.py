from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    database_url: str
    strava_client_id: str = ""
    strava_client_secret: str = ""
    strava_redirect_uri: str = "http://localhost:8000/auth/strava/callback"

    jwt_secret: str = "dev-secret-change-me"
    jwt_access_ttl_min: int = 120
    jwt_refresh_ttl_days: int = 30

    groq_api_key: str = ""

    @property
    def sqlalchemy_database_url(self) -> str:
        # Supabase/Render fournissent parfois "postgres://", SQLAlchemy veut "postgresql://"
        if self.database_url.startswith("postgres://"):
            return self.database_url.replace("postgres://", "postgresql://", 1)
        return self.database_url


settings = Settings()
